/// The Certificate of Knowledge Assessment as a PDF, built in the app and saved on the phone.
///
/// A port of the website's `certificatePdf.ts`, which builds the file by hand in the browser: the same A4
/// landscape page (842 by 595 pt), the same base-14 fonts (so nothing is embedded and the text stays selectable),
/// the same vector QR code and the same absolute geometry, so what the app saves is the document the website
/// downloads. Positions are points from the bottom-left, PDF's own origin.
///
/// This file is pure Dart: the pictures it places (the marks, the engrossed name) arrive already decoded as
/// [RasterImage]s, made by `certificate_marks.dart`, which is the part that needs the Flutter engine.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart' show ZLibEncoder;

import '../../core/config.dart';
import 'exam_format.dart';
import 'exam_models.dart';
import 'qr_code.dart';

/// The public page that proves a certificate: anyone can check the number there.
Uri verifyUri(String certificateId) =>
    AppConfig.sitePage('/learning/verify?id=${Uri.encodeQueryComponent(certificateId)}');

/// The signatory every assessment certificate carries (the website's constant).
const certificateSignatory = (
  name: 'VINAY KUMAR SHETTY',
  title: 'DIRECTOR, PROFESSIONAL DEVELOPMENT',
  organisation: 'INSTITUTE FOR CORPORATE REAL ESTATE',
);

/// The engrossed name's size: 127.94 px on the website's 1920 px design, which is 56 pt on an 842 pt page.
const certificateNamePt = 0.046 * _pageW;

/// How many times over the name is rendered, so its strokes stay smooth in print.
const certificateNameOversample = 4;

/// The certificate's display serif, the website's since 2 Nov 2026 (Playfair Display, bundled at 600).
const certificateNameFont = 'Playfair Display';

/// A picture to place on the page: [width] by [height] pixels of 8-bit RGB, row by row from the top, with no
/// alpha (a mark is composited onto the colour it sits on before it gets here).
class RasterImage {
  const RasterImage({required this.rgb, required this.width, required this.height});

  final Uint8List rgb;
  final int width;
  final int height;
}

/// The pictures on a certificate. Every one is optional: a mark that did not load is left out, or drawn as its
/// fallback, and the certificate is still issued.
class CertificateMarks {
  const CertificateMarks({this.icrLogo, this.seal, this.partner, this.signature, this.providerLogo, this.name});

  final RasterImage? icrLogo;
  final RasterImage? seal;
  final RasterImage? partner;
  final RasterImage? signature;

  /// The awarding body's logo, when the credential is theirs rather than ICR's.
  final RasterImage? providerLogo;

  /// The holder's name, set in the gold script and rasterised.
  final RasterImage? name;
}

// --- fonts and text ------------------------------------------------------------------------------------

/// The four base-14 faces the page uses, with the resource name each goes by in the page.
enum PdfFont {
  regular('Helvetica', 'F1'),
  bold('Helvetica-Bold', 'F2'),
  nameItalic('Times-BoldItalic', 'F3'),
  mono('Courier-Bold', 'F4');

  const PdfFont(this.baseName, this.resource);

  final String baseName;
  final String resource;
}

/// Helvetica's advance widths per 1000 em, for the ASCII characters 32 to 126 (index 0 is the space).
const helveticaWidths = <int>[
  278, 278, 355, 556, 556, 889, 667, 191, 333, 333, 389, 584, 278, 333, 278, 278, // space to /
  556, 556, 556, 556, 556, 556, 556, 556, 556, 556, // 0 to 9
  278, 278, 584, 584, 584, 556, 1015, // : to @
  667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556, 833, 722, 778, 667, 778, 722, 667, 611, 722, 667,
  944, 667, 667, 611, // A to Z
  278, 278, 278, 469, 556, 333, // [ to `
  556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556, 556, 556, 333, 500, 278, 556, 500,
  722, 500, 500, 500, // a to z
  334, 260, 334, 584, // { to ~
];

/// Helvetica-Bold's advance widths per 1000 em, for the ASCII characters 32 to 126.
const helveticaBoldWidths = <int>[
  278, 333, 474, 556, 556, 889, 722, 238, 333, 333, 389, 584, 278, 333, 278, 278, // space to /
  556, 556, 556, 556, 556, 556, 556, 556, 556, 556, // 0 to 9
  333, 333, 584, 584, 584, 611, 975, // : to @
  722, 722, 722, 722, 667, 611, 778, 722, 278, 556, 722, 611, 833, 722, 778, 667, 778, 722, 667, 611, 722, 667,
  944, 667, 667, 611, // A to Z
  333, 278, 333, 584, 556, 333, // [ to `
  556, 611, 556, 611, 556, 333, 611, 611, 278, 278, 556, 278, 889, 611, 611, 611, 611, 389, 556, 333, 611, 556,
  778, 556, 556, 500, // a to z
  389, 280, 389, 584, // { to ~
];

/// Base-14 fonts are Latin-1: fold the typography we author into that range and drop what cannot be encoded.
String toLatin1(String input) {
  final folded = input
      .replaceAll(RegExp('[‘’‛]'), "'")
      .replaceAll(RegExp('[“”]'), '"')
      .replaceAll(RegExp('[–—]'), '-')
      .replaceAll('…', '...')
      .replaceAll(' ', ' ');
  final out = StringBuffer();
  for (final unit in folded.codeUnits) {
    if (unit >= 0x20 && unit <= 0xFF) out.writeCharCode(unit);
  }
  return out.toString();
}

/// Escapes the three characters a PDF string literal reserves.
String escapePdf(String s) => s.replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');

/// Width of [text] in points, with letter tracking: the font's advance widths (per 1000 em) at [size], and
/// [tracking] between each pair of letters. A character outside ASCII counts as an average one.
double textWidth(String text, PdfFont font, double size, [double tracking = 0]) {
  var units = 0;
  for (final unit in text.codeUnits) {
    switch (font) {
      case PdfFont.regular:
        units += unit >= 32 && unit <= 126 ? helveticaWidths[unit - 32] : 556;
      case PdfFont.bold || PdfFont.nameItalic:
        units += unit >= 32 && unit <= 126 ? helveticaBoldWidths[unit - 32] : 611;
      case PdfFont.mono:
        units += 600;
    }
  }
  return units / 1000 * size + math.max(0, text.length - 1) * tracking;
}

/// Greedy wrap to a width: the credential's title is the only long line.
List<String> wrapText(String content, PdfFont font, double size, double maxWidth) {
  final words = toLatin1(content).split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final lines = <String>[];
  var current = '';
  for (final word in words) {
    final next = current.isNotEmpty ? '$current $word' : word;
    if (current.isNotEmpty && textWidth(next, font, size) > maxWidth) {
      lines.add(current);
      current = word;
    } else {
      current = next;
    }
  }
  if (current.isNotEmpty) lines.add(current);
  return lines.isEmpty ? [''] : lines;
}

// --- the design's palette, as PDF device RGB -----------------------------------------------------------

const _navy = [0.071, 0.251, 0.431]; // #12406E
const _azure = [0.106, 0.498, 0.843]; // #1B7FD7
const _gold = [0.749, 0.608, 0.247]; // #BF9B3F
const _ink = [0.102, 0.102, 0.102]; // #1A1A1A
const _slate = [0.29, 0.345, 0.4]; // #4A5866
const _muted = [0.478, 0.529, 0.58]; // #7A8794
const _rule = [0.725, 0.776, 0.831]; // #B9C6D4
const _sigRule = [0.549, 0.604, 0.667]; // #8C9AAA

/// The tint behind the marks panel (#F2F6FA). Flat, and every picture on that panel is composited onto this
/// exact colour: a PDF image carries no alpha here, so a mark flattened onto white would print in a white box.
const _cardTint = [0.949, 0.965, 0.98];

// --- drawing operators ---------------------------------------------------------------------------------

class _Ops {
  final List<String> out = [];
}

/// A number as JavaScript prints it: 2 not 2.0.
String _n(num v) {
  if (v is int) return '$v';
  if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
  return v.toString();
}

/// `toFixed(2)`.
String _f(double v) => v.toStringAsFixed(2);

void _color(_Ops ops, List<double> rgb, {bool stroke = false}) {
  ops.out.add('${_n(rgb[0])} ${_n(rgb[1])} ${_n(rgb[2])} ${stroke ? 'RG' : 'rg'}');
}

void _text(_Ops ops, String content, double x, double y, PdfFont font, double size, [double tracking = 0]) {
  final safe = escapePdf(toLatin1(content));
  ops.out.add('BT');
  ops.out.add('/${font.resource} ${_n(size)} Tf');
  if (tracking != 0) ops.out.add('${_n(tracking)} Tc');
  ops.out.add('1 0 0 1 ${_f(x)} ${_f(y)} Tm');
  ops.out.add('($safe) Tj');
  ops.out.add('ET');
  if (tracking != 0) ops.out.add('0 Tc');
}

/// Centres [content] on [cx] rather than on the page.
void _centeredOn(_Ops ops, String content, double cx, double y, PdfFont font, double size, [double tracking = 0]) {
  final w = textWidth(toLatin1(content), font, size, tracking);
  _text(ops, content, cx - w / 2, y, font, size, tracking);
}

void _fillRect(_Ops ops, double x, double y, double w, double h) {
  ops.out.add('${_f(x)} ${_f(y)} ${_f(w)} ${_f(h)} re f');
}

/// A filled rectangle with rounded corners, from four Bezier arcs.
void _fillRoundRect(_Ops ops, double x, double y, double w, double h, double r) {
  final k = 0.5523 * r;
  final x1 = x + w;
  final y1 = y + h;
  ops.out.add('${_f(x + r)} ${_f(y)} m');
  ops.out.add('${_f(x1 - r)} ${_f(y)} l');
  ops.out.add('${_f(x1 - r + k)} ${_f(y)} ${_f(x1)} ${_f(y + r - k)} ${_f(x1)} ${_f(y + r)} c');
  ops.out.add('${_f(x1)} ${_f(y1 - r)} l');
  ops.out.add('${_f(x1)} ${_f(y1 - r + k)} ${_f(x1 - r + k)} ${_f(y1)} ${_f(x1 - r)} ${_f(y1)} c');
  ops.out.add('${_f(x + r)} ${_f(y1)} l');
  ops.out.add('${_f(x + r - k)} ${_f(y1)} ${_f(x)} ${_f(y1 - r + k)} ${_f(x)} ${_f(y1 - r)} c');
  ops.out.add('${_f(x)} ${_f(y + r)} l');
  ops.out.add('${_f(x)} ${_f(y + r - k)} ${_f(x + r - k)} ${_f(y)} ${_f(x + r)} ${_f(y)} c');
  ops.out.add('f');
}

/// A stroked circle from four Bezier arcs: PDF has no circle operator.
void _strokeCircle(_Ops ops, double cx, double cy, double r, double lineWidth) {
  final k = 0.5523 * r;
  ops.out.add('${_n(lineWidth)} w');
  ops.out.add('${_f(cx + r)} ${_f(cy)} m');
  ops.out.add('${_f(cx + r)} ${_f(cy + k)} ${_f(cx + k)} ${_f(cy + r)} ${_f(cx)} ${_f(cy + r)} c');
  ops.out.add('${_f(cx - k)} ${_f(cy + r)} ${_f(cx - r)} ${_f(cy + k)} ${_f(cx - r)} ${_f(cy)} c');
  ops.out.add('${_f(cx - r)} ${_f(cy - k)} ${_f(cx - k)} ${_f(cy - r)} ${_f(cx)} ${_f(cy - r)} c');
  ops.out.add('${_f(cx + k)} ${_f(cy - r)} ${_f(cx + r)} ${_f(cy - k)} ${_f(cx + r)} ${_f(cy)} c');
  ops.out.add('S');
}

void _line(_Ops ops, double x1, double y1, double x2, double y2, double lineWidth) {
  ops.out.add('${_n(lineWidth)} w');
  ops.out.add('${_f(x1)} ${_f(y1)} m ${_f(x2)} ${_f(y2)} l S');
}

/// A filled polygon from points: the two frame wedges, the stars.
void _fillPolygon(_Ops ops, List<(double, double)> points) {
  for (var i = 0; i < points.length; i++) {
    ops.out.add('${_f(points[i].$1)} ${_f(points[i].$2)} ${i == 0 ? 'm' : 'l'}');
  }
  ops.out.add('f');
}

/// The verification QR, drawn as vector squares.
///
/// Modules are drawn a hair larger than their cell so neighbouring dark modules meet instead of leaving a
/// hairline of white between them; a renderer that rounds each square on its own turns those hairlines into a
/// visible grid, and a printed grid is what makes a code fail to scan. Vector rather than a bitmap, so the code
/// stays exact at any zoom and at any printer resolution.
void _drawQr(_Ops ops, List<List<bool>> modules, double x, double y, double size) {
  final count = modules.length;
  final cell = size / count;
  const overdraw = 0.06;
  for (var row = 0; row < count; row++) {
    for (var col = 0; col < count; col++) {
      if (!modules[row][col]) continue;
      // PDF space has y increasing upward; the matrix reads top-down.
      _fillRect(ops, x + col * cell, y + size - (row + 1) * cell, cell + overdraw, cell + overdraw);
    }
  }
}

/// Three filled five-pointed stars in a row, [w] wide.
void _drawStars(_Ops ops, double x, double y, double w) {
  final r = w / 8;
  for (var i = 0; i < 3; i++) {
    final cx = x + r + i * (w / 3);
    final pts = <(double, double)>[];
    for (var k = 0; k < 10; k++) {
      final radius = k.isEven ? r : r * 0.42;
      final angle = (math.pi / 5) * k - math.pi / 2;
      pts.add((cx + radius * math.cos(angle), y + radius * math.sin(angle)));
    }
    _fillPolygon(ops, pts);
  }
}

/// A picture that is going into the file, with the name the page's resources give it.
class _Placed {
  const _Placed(this.image, this.res);

  final RasterImage image;
  final String res;
}

/// Places a picture so it fits inside [maxW] by [maxH], centred on [cx], keeping its aspect.
void _drawImage(_Ops ops, _Placed placed, double cx, double yBottom, double maxW, double maxH) {
  final ratio = placed.image.width / placed.image.height;
  var w = maxW;
  var h = w / ratio;
  if (h > maxH) {
    h = maxH;
    w = h * ratio;
  }
  ops.out.add('q');
  ops.out.add('${_f(w)} 0 0 ${_f(h)} ${_f(cx - w / 2)} ${_f(yBottom)} cm');
  ops.out.add('/${placed.res} Do');
  ops.out.add('Q');
}

class _PlacedMarks {
  const _PlacedMarks({this.icrLogo, this.seal, this.partner, this.signature, this.providerLogo, this.name});

  final _Placed? icrLogo;
  final _Placed? seal;
  final _Placed? partner;
  final _Placed? signature;
  final _Placed? providerLogo;
  final _Placed? name;
}

// --- layout, transcribed from the approved design -------------------------------------------------------

const _pageW = 842.0; // A4 landscape, points
const _pageH = 595.0;

/// The border (the website's redesign of 2 Nov 2026): bars across the top and bottom, and a leg down the left from
/// the top corner and up the right from the bottom one, each ending in a slant — the same 1.5 / 15 / 16.4
/// percentages the screen certificate uses, against the width: the bars' thickness, and each leg's length on the
/// side facing the sheet and at the page's edge.
const _border = 0.015 * _pageW;
const _legInner = 0.15 * _pageW;
const _legOuter = 0.164 * _pageW;
const _cardX = 24.0;
const _cardW = 307.0;
const _cardY = 86.0;
const _cardH = 487.0;
const _cardCx = _cardX + _cardW / 2;

/// The centre line every line of the attestation is set on.
const _rightCx = 586.0;

String _buildContent(
  ExamCertificate cert,
  String holder,
  String cleared,
  String issued,
  _PlacedMarks marks,
  List<List<bool>>? qr,
) {
  final ops = _Ops();

  // Bars across the top and bottom; a leg down from the top-left corner and up from the bottom-right.
  _color(ops, _azure);
  _fillRect(ops, 0, _pageH - _border, _pageW, _border);
  _fillRect(ops, 0, 0, _pageW, _border);
  _fillPolygon(ops, [(0, _pageH), (_border, _pageH), (_border, _pageH - _legInner), (0, _pageH - _legOuter)]);
  _fillPolygon(ops, [(_pageW, 0), (_pageW - _border, 0), (_pageW - _border, _legInner), (_pageW, _legOuter)]);

  // --- the marks panel
  _color(ops, _cardTint);
  _fillRoundRect(ops, _cardX, _cardY, _cardW, _cardH, 10);

  if (marks.icrLogo != null) {
    _drawImage(ops, marks.icrLogo!, _cardCx, 474, 200, 72);
  } else {
    _color(ops, _navy);
    _centeredOn(ops, 'ICR', _cardCx, 500, PdfFont.bold, 34, 2);
    _color(ops, _slate);
    _centeredOn(ops, 'INSTITUTE FOR CORPORATE REAL ESTATE', _cardCx, 484, PdfFont.regular, 8, 1);
  }

  if (marks.seal != null) {
    _drawImage(ops, marks.seal!, _cardCx, 210, 182, 182);
  } else {
    // The emblem is the visual centre of this panel; without a file the panel is a hole, so ICR's own drawn
    // seal stands in its place.
    _color(ops, _rule, stroke: true);
    _strokeCircle(ops, _cardCx, 301, 86, 1.5);
    _strokeCircle(ops, _cardCx, 301, 78, 5);
    _strokeCircle(ops, _cardCx, 301, 58, 1.5);
    _color(ops, _rule);
    _centeredOn(ops, 'ICR', _cardCx, 289, PdfFont.bold, 32, 2);
  }

  // The knowledge partner, and the awarding institute when the credential is theirs rather than ICR's. Stacked
  // upward from the bottom of the panel, so a certificate with no partner simply has more air.
  var markY = 108.0;
  _color(ops, _slate);
  _centeredOn(ops, 'KNOWLEDGE PARTNER', _cardCx, markY, PdfFont.bold, 7, 1.2);
  markY += 12;
  if (marks.partner != null) {
    _drawImage(ops, marks.partner!, _cardCx, markY, 145, 26);
    markY += 30;
  }
  final providerName = cert.providerName;
  if (providerName != null && providerName.isNotEmpty) {
    markY += 8;
    _color(ops, _slate);
    _centeredOn(ops, 'AWARDING BODY', _cardCx, markY, PdfFont.bold, 7, 1.2);
    markY += 12;
    _centeredOn(ops, providerName.toUpperCase(), _cardCx, markY, PdfFont.bold, 7, 1.2);
    markY += 12;
    if (marks.providerLogo != null) _drawImage(ops, marks.providerLogo!, _cardCx, markY, 110, 24);
  }

  // The scope note, under the panel.
  _color(ops, _navy);
  const disclaimer = [
    '* This certificate is issued upon successful completion of the',
    'knowledge assessment & does not constitute a professional',
    'license or statutory certification unless specifically stated.',
  ];
  for (var i = 0; i < disclaimer.length; i++) {
    _text(ops, disclaimer[i], _cardX, 62 - i * 12, PdfFont.regular, 8.5);
  }

  // --- the attestation
  _color(ops, _navy);
  _centeredOn(ops, 'CERTIFICATE', _rightCx, 507, PdfFont.bold, 42, 5);

  _color(ops, _ink);
  _centeredOn(ops, 'OF KNOWLEDGE ASSESSMENT', _rightCx, 477, PdfFont.bold, 15, 2.8);

  _color(ops, _rule, stroke: true);
  _line(ops, _rightCx - 192, 466, _rightCx + 192, 466, 0.8);

  _color(ops, _ink);
  _centeredOn(ops, 'This is to certify that', _rightCx, 435, PdfFont.regular, 15);

  // The holder's name, at the size it was rendered and shrunk only to fit the column, centred on the gap between
  // the lines above and below it. Falls back to Times-BoldItalic in gold if it could not be rasterised: still
  // clearly a name set apart, which is what the line is for.
  if (marks.name != null) {
    final name = marks.name!;
    final w = math.min(380.0, name.image.width / certificateNameOversample);
    final h = w * name.image.height / name.image.width;
    _drawImage(ops, name, _rightCx, 377 - h / 2, w, h);
  } else {
    _color(ops, _gold);
    final nameSize = holder.length > 26 ? 34.0 : 42.0;
    _centeredOn(ops, holder, _rightCx, 367, PdfFont.nameItalic, nameSize);
  }

  _color(ops, _ink);
  _centeredOn(ops, 'For successfully completing :', _rightCx, 321, PdfFont.regular, 15);

  // The credential, wrapped to the column rather than the page.
  final titleLines = wrapText(cert.title, PdfFont.bold, 20, 380);
  final shown = titleLines.take(2).toList();
  for (var i = 0; i < shown.length; i++) {
    _centeredOn(ops, shown[i], _rightCx, 283 - i * 26, PdfFont.bold, 20);
  }
  final afterTitle = 283 - (math.min(titleLines.length, 2) - 1) * 26.0;

  // The level, with the three gold stars either side.
  final levelName = certificateLevelLabel(cert.level);
  final level = levelName != null ? '${levelName.toUpperCase()} LEVEL' : cert.level;
  if (level != null && level.isNotEmpty) {
    final levelY = afterTitle - 36;
    final levelW = textWidth(level, PdfFont.bold, 19, 1.5);
    _color(ops, _azure);
    _centeredOn(ops, level, _rightCx, levelY, PdfFont.bold, 19, 1.5);
    _color(ops, _gold);
    _drawStars(ops, _rightCx - levelW / 2 - 58, levelY + 5, 48);
    _drawStars(ops, _rightCx + levelW / 2 + 10, levelY + 5, 48);

    _drawClearedLine(ops, _rightCx, levelY - 38, cleared);
  } else {
    _drawClearedLine(ops, _rightCx, afterTitle - 40, cleared);
  }

  // --- the footer: signature, code, number
  const sigCx = 470.0;
  if (marks.signature != null) _drawImage(ops, marks.signature!, sigCx, 89, 165, 34);
  _color(ops, _sigRule, stroke: true);
  _line(ops, 386, 86, 554, 86, 0.8);
  _color(ops, _ink);
  _centeredOn(ops, certificateSignatory.name, sigCx, 68, PdfFont.bold, 15, 0.4);
  _color(ops, _slate);
  _centeredOn(ops, certificateSignatory.title, sigCx, 53, PdfFont.regular, 8.5, 0.3);
  _color(ops, _muted);
  _centeredOn(ops, certificateSignatory.organisation, sigCx, 40, PdfFont.regular, 8.5, 0.3);

  // The QR encodes this certificate's own verification address, so every issued certificate carries a different
  // code without anything having to store one: the number is the uniqueness, and the code a second way to read it.
  const qrSize = 62.0;
  const qrX = 588.0;
  const qrY = 66.0;
  _color(ops, _ink);
  if (qr != null) _drawQr(ops, qr, qrX, qrY, qrSize);
  _color(ops, _slate);
  _centeredOn(ops, 'Scan to authenticate', qrX + qrSize / 2, 52, PdfFont.regular, 8);
  _centeredOn(ops, 'the certificate', qrX + qrSize / 2, 42, PdfFont.regular, 8);

  const metaX = 660.0;
  _color(ops, _slate);
  _text(ops, 'Issued Date:', metaX, 110, PdfFont.regular, 10);
  _color(ops, _ink);
  _text(ops, issued, metaX, 95, PdfFont.bold, 11);
  _color(ops, _slate);
  _text(ops, 'CERTIFICATE NO. :', metaX, 69, PdfFont.regular, 10);
  _color(ops, _ink);
  // The number sits in the last column, which the website's numbers just fit; a longer one (a long certification
  // code) is set a little smaller rather than run off the sheet.
  const numberRoom = _pageW - _border - 8 - metaX;
  final numberW = textWidth(toLatin1(cert.certificateId), PdfFont.bold, 11);
  final numberSize = numberW > numberRoom ? (11 * numberRoom / numberW * 10).floorToDouble() / 10 : 11.0;
  _text(ops, cert.certificateId, metaX, 54, PdfFont.bold, numberSize);

  return ops.out.join('\n');
}

/// The cleared-on line, whose date is bold where the sentence is not.
void _drawClearedLine(_Ops ops, double cx, double y, String cleared) {
  const lead = 'The assessment was successfully cleared on : ';
  final leadW = textWidth(lead, PdfFont.regular, 13);
  final dateW = textWidth(cleared, PdfFont.bold, 13);
  final x = cx - (leadW + dateW) / 2;
  _color(ops, _ink);
  _text(ops, lead, x, y, PdfFont.regular, 13);
  _text(ops, cleared, x + leadW, y, PdfFont.bold, 13);
}

// --- the file ------------------------------------------------------------------------------------------

/// Assembles the file as bytes (the cross-reference table is byte offsets, and the pictures are binary).
///
/// Object numbers: 1 catalogue, 2 pages, 3 the page, 4 its content, 5 to 8 the fonts, 9 on the pictures.
Uint8List _buildPdf(String content, List<_Placed> images) {
  final contentBytes = latin1.encode(content);
  final xobject = images.isEmpty
      ? ''
      : '/XObject << ${[for (var i = 0; i < images.length; i++) '/${images[i].res} ${9 + i} 0 R'].join(' ')} >> ';

  Uint8List plain(String s) => Uint8List.fromList(latin1.encode(s));
  Uint8List stream(String head, List<int> body) {
    final out = BytesBuilder(copy: false)
      ..add(latin1.encode('$head\nstream\n'))
      ..add(body)
      ..add(latin1.encode('\nendstream'));
    return out.takeBytes();
  }

  final objects = <Uint8List>[
    plain('<< /Type /Catalog /Pages 2 0 R >>'),
    plain('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
    plain(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${_n(_pageW)} ${_n(_pageH)}] '
      '/Resources << /Font << /F1 5 0 R /F2 6 0 R /F3 7 0 R /F4 8 0 R >> $xobject>> '
      '/Contents 4 0 R >>',
    ),
    stream('<< /Length ${contentBytes.length} >>', contentBytes),
    for (final font in PdfFont.values)
      plain('<< /Type /Font /Subtype /Type1 /BaseFont /${font.baseName} /Encoding /WinAnsiEncoding >>'),
  ];
  for (final placed in images) {
    final im = placed.image;
    final packed = const ZLibEncoder().encodeBytes(im.rgb);
    objects.add(
      stream(
        '<< /Type /XObject /Subtype /Image /Width ${im.width} /Height ${im.height} '
        '/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode /Length ${packed.length} >>',
        packed,
      ),
    );
  }

  final pdf = BytesBuilder(copy: false)..add(latin1.encode('%PDF-1.4\n'));
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(pdf.length);
    pdf
      ..add(latin1.encode('${i + 1} 0 obj\n'))
      ..add(objects[i])
      ..add(latin1.encode('\nendobj\n'));
  }
  final xrefStart = pdf.length;
  final xref = StringBuffer('xref\n0 ${objects.length + 1}\n')..write('0000000000 65535 f \n');
  for (final o in offsets) {
    xref.write('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  xref.write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xrefStart\n%%EOF');
  pdf.add(latin1.encode(xref.toString()));
  return pdf.takeBytes();
}

/// Builds the certificate: [c] made out to [holder], with whichever [marks] loaded. The result is a complete
/// PDF, ready to save.
Future<Uint8List> buildCertificatePdf(ExamCertificate c, String holder, {required CertificateMarks marks}) async {
  final cleared = longDayLabel(c.clearedAt ?? c.issuedAt);
  final issued = stampLabel(c.issuedAt);

  // Resource names go only to the marks that are there, so the page's /XObject dictionary never names an
  // object that is not written.
  final images = <_Placed>[];
  _Placed? register(RasterImage? image) {
    if (image == null) return null;
    final placed = _Placed(image, 'Im${images.length + 1}');
    images.add(placed);
    return placed;
  }

  final placed = _PlacedMarks(
    icrLogo: register(marks.icrLogo),
    seal: register(marks.seal),
    partner: register(marks.partner),
    signature: register(marks.signature),
    providerLogo: register(marks.providerLogo),
    name: register(marks.name),
  );

  // A number too long for the encoder's versions leaves the code out rather than the whole document.
  List<List<bool>>? qr;
  try {
    qr = QrCode.encode(verifyUri(c.certificateId).toString()).modules;
  } on ArgumentError {
    qr = null;
  }

  return _buildPdf(_buildContent(c, holder, cleared, issued, placed, qr), images);
}

/// The level as a certificate prints it: the website's `LEARNING_LEVEL_LABELS` ("Intermediate"), where the
/// assessment pages say "Professional" for the same level (`assessmentLevelLabel`). A certificate saved from the
/// app and one printed by the website for the same credential must read the same.
String? certificateLevelLabel(String? level) => switch (level) {
  'FOUNDATION' => 'Foundation',
  'INTERMEDIATE' => 'Intermediate',
  'ADVANCED' => 'Advanced',
  'LEADERSHIP' => 'Leadership',
  'SPECIALIST' => 'Specialist',
  _ => null,
};
