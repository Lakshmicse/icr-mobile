/// The pictures on the certificate PDF, read and decoded: the part of the download that needs the Flutter engine
/// (image codecs, the text engine), kept apart from `certificate_pdf.dart`, which is pure Dart.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/config.dart';
import 'certificate_pdf.dart';
import 'exam_models.dart';
import 'exam_styles.dart';

/// The colour the panel's marks sit on in the PDF (the website's CARD_TINT): a mark flattened onto white would
/// print in a white box.
const certificateCardTint = ui.Color(0xFFF2F6FA);

/// The seams the certificate download goes through, so a test can stand in for the network, the text engine and
/// the phone's file saver.
class CertificatePdfServices {
  CertificatePdfServices._();

  /// The bytes at [url] (an awarding body's logo), or null when there are none.
  static Future<Uint8List?> Function(String url) fetch = _fetch;

  /// The holder's name set in gold in the certificate's display serif and rasterised, at [sizePt] on the page.
  static Future<RasterImage?> Function(String holder, double sizePt) renderName = renderEngrossedName;

  /// Every picture the certificate carries, each optional.
  static Future<CertificateMarks> Function(ExamCertificate c, String holder) marks = loadCertificateMarks;

  /// Saves the file where the person chooses (the system "Save as" sheet); the saved location, or null when they
  /// cancel.
  static Future<Uri?> Function(String fileName, Uint8List bytes) save = _save;

  static Future<Uint8List?> _fetch(String url) async {
    final dio = Dio(
      BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 10)),
    );
    try {
      final res = await dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
      final data = res.data;
      return data == null ? null : Uint8List.fromList(data);
    } finally {
      dio.close();
    }
  }

  static Future<Uri?> _save(String fileName, Uint8List bytes) => FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    mimeType: 'application/pdf',
    dialogTitle: 'Save Certificate',
  );

  /// Back to the real ones (a test's tear-down).
  static void reset() {
    fetch = _fetch;
    renderName = renderEngrossedName;
    marks = loadCertificateMarks;
    save = _save;
  }
}

/// Flattens straight-from-the-engine RGBA (premultiplied, as `ImageByteFormat.rawRgba` is) onto [background]:
/// each pixel is its own colour over the background it lets through, `out = a*src + (1-a)*bg` with the
/// premultiplied colour already holding `a*src`.
Uint8List _flatten(ByteData data, int width, int height, ui.Color background) {
  final argb = background.toARGB32();
  final bgR = (argb >> 16) & 0xFF;
  final bgG = (argb >> 8) & 0xFF;
  final bgB = argb & 0xFF;
  final src = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  final pixels = width * height;
  final rgb = Uint8List(pixels * 3);
  for (var i = 0, o = 0; i < pixels * 4; i += 4, o += 3) {
    final back = 255 - src[i + 3];
    rgb[o] = math.min(255, src[i] + (back * bgR + 127) ~/ 255);
    rgb[o + 1] = math.min(255, src[i + 1] + (back * bgG + 127) ~/ 255);
    rgb[o + 2] = math.min(255, src[i + 2] + (back * bgB + 127) ~/ 255);
  }
  return rgb;
}

/// Decodes an encoded picture (PNG, JPEG, WebP) to RGB, scaled down to [maxWidth] pixels across when it is wider
/// (keeping its shape), and composited onto [background]. Null when it cannot be decoded.
Future<RasterImage?> rasterFromPng(Uint8List png, {required ui.Color background, int maxWidth = 600}) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(png);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    codec = await descriptor.instantiateCodec(targetWidth: descriptor.width > maxWidth ? maxWidth : null);
    image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null || image.width < 1 || image.height < 1) return null;
    return RasterImage(
      rgb: _flatten(data, image.width, image.height, background),
      width: image.width,
      height: image.height,
    );
  } catch (_) {
    return null;
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

/// The widest the name's picture is drawn: more than enough for the 380 pt it prints in, and under the texture
/// size a phone's graphics chip will make.
const _nameMaxPx = 3000.0;

/// The holder's name set in Roboto bold italic, in the certificate's gold, on white, at four times its printed
/// size so the strokes stay smooth in print. (The website sets it in a script webfont; the app has none, so the
/// text engine's own face stands in for it, as on the app's screen certificate.)
Future<RasterImage?> renderEngrossedName(String holder, double sizePt) async {
  ui.Paragraph? paragraph;
  ui.Picture? picture;
  ui.Image? image;
  try {
    const oversample = certificateNameOversample;
    var px = sizePt * oversample;

    ui.Paragraph set(double size) {
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(textDirection: ui.TextDirection.ltr, maxLines: 1))
        ..pushStyle(
          ui.TextStyle(
            color: ExamColors.gold,
            fontSize: size,
            fontFamily: certificateNameFont,
            fontWeight: ui.FontWeight.w600,
            textBaseline: ui.TextBaseline.alphabetic,
          ),
        )
        ..addText(holder);
      return builder.build()..layout(const ui.ParagraphConstraints(width: double.infinity));
    }

    paragraph = set(px);
    // Script faces overshoot their em box in both directions; pad generously rather than clip a tail.
    var w = (paragraph.maxIntrinsicWidth + px * 0.3).ceil();
    if (w > _nameMaxPx) {
      paragraph.dispose();
      px *= _nameMaxPx / w;
      paragraph = set(px);
      w = (paragraph.maxIntrinsicWidth + px * 0.3).ceil();
    }
    final h = (px * 1.25).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    canvas.drawParagraph(paragraph, ui.Offset(px * 0.15, h * 0.78 - paragraph.alphabeticBaseline));
    picture = recorder.endRecording();
    image = await picture.toImage(w, h);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    return RasterImage(rgb: _flatten(data, w, h, const ui.Color(0xFFFFFFFF)), width: w, height: h);
  } catch (_) {
    return null;
  } finally {
    image?.dispose();
    picture?.dispose();
    paragraph?.dispose();
  }
}

/// A mark that will not load is dropped: the certificate is still issued and still verifiable, and a download
/// that fails outright helps nobody.
Future<RasterImage?> _optional(Future<RasterImage?> Function() load) async {
  try {
    return await load();
  } catch (_) {
    return null;
  }
}

Future<RasterImage?> _bundled(String path, ui.Color background) => _optional(() async {
  final data = await rootBundle.load(path);
  return rasterFromPng(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), background: background);
});

/// Reads every picture the certificate carries, in parallel: ICR's logo, the seal, the knowledge partner and the
/// signature from the app's bundle, the awarding body's logo from the network, and the holder's name set in the
/// text engine. Each is optional; one that fails is null, never an exception.
Future<CertificateMarks> loadCertificateMarks(ExamCertificate c, String holder) async {
  const white = ui.Color(0xFFFFFFFF);
  final logoUrl = c.providerLogoUrl == null ? null : AppConfig.absoluteUrl(c.providerLogoUrl);
  final results = await Future.wait<RasterImage?>([
    _bundled('assets/images/brand/icr-logo.png', certificateCardTint),
    _bundled('assets/images/demo/learning/cert_seal.png', certificateCardTint),
    _bundled('assets/images/demo/learning/cert_partner.png', certificateCardTint),
    _bundled('assets/images/demo/learning/cert_signature.png', white),
    if (logoUrl != null)
      _optional(() async {
        final bytes = await CertificatePdfServices.fetch(logoUrl);
        return bytes == null ? null : rasterFromPng(bytes, background: certificateCardTint);
      })
    else
      Future<RasterImage?>.value(null),
    _optional(
      () =>
          CertificatePdfServices.renderName(holder, holder.length > 26 ? certificateNamePt * 0.78 : certificateNamePt),
    ),
  ]);
  return CertificateMarks(
    icrLogo: results[0],
    seal: results[1],
    partner: results[2],
    signature: results[3],
    providerLogo: results[4],
    name: results[5],
  );
}
