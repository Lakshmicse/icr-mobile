// The certificate PDF the app builds and saves itself: the file is well formed (header, objects at the offsets the
// cross-reference table gives, trailer), carries the certificate's words as selectable text, and places a picture
// only when one is given. Pure Dart: no Flutter engine is needed to build it.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/learning_exam/certificate_pdf.dart';
import 'package:icr_mobile/features/learning_exam/exam_models.dart';
import 'package:icr_mobile/features/learning_exam/qr_code.dart';

ExamCertificate certificate({String? level = 'FOUNDATION', String title = 'Communication', String? provider}) =>
    ExamCertificate(
      id: 'c1',
      certificateId: 'ICR-COMMUNICAT-2026-01AZRIE7',
      title: title,
      level: level,
      providerName: provider,
      issuedAt: DateTime(2026, 10, 22),
      clearedAt: DateTime(2026, 10, 22),
      percentage: 76,
      passPercentage: 70,
    );

/// The file as text, one character a byte: what the cross-reference offsets count in.
String asText(Uint8List bytes) => latin1.decode(bytes);

/// The offsets in the cross-reference table, parsed the way a reader would: from `startxref`.
({int xrefAt, List<int> offsets}) crossReference(String pdf) {
  final start = RegExp(r'startxref\n(\d+)\n%%EOF$').firstMatch(pdf);
  expect(start, isNotNull, reason: 'the file ends with startxref and %%EOF');
  final xrefAt = int.parse(start!.group(1)!);
  expect(pdf.substring(xrefAt, xrefAt + 4), 'xref');
  final table = RegExp(r'xref\n0 (\d+)\n').firstMatch(pdf.substring(xrefAt))!;
  final count = int.parse(table.group(1)!);
  var at = xrefAt + table.end;
  final offsets = <int>[];
  for (var i = 0; i < count; i++) {
    final entry = pdf.substring(at, at + 20);
    expect(entry, matches(RegExp(r'^\d{10} \d{5} [nf] \n$')), reason: 'every entry is exactly 20 bytes');
    offsets.add(int.parse(entry.substring(0, 10)));
    at += 20;
  }
  expect(offsets.first, 0, reason: 'entry 0 is the free list head');
  return (xrefAt: xrefAt, offsets: offsets);
}

/// The credential's lines (20 pt bold): their y and their text.
List<RegExpMatch> titleLines(String pdf) =>
    RegExp(r'/F2 20 Tf\n1 0 0 1 [\d.]+ ([\d.]+) Tm\n\((.*)\) Tj').allMatches(pdf).toList();

void main() {
  group('the PDF file', () {
    test('has the header, the trailer, and every object where the cross-reference table says', () async {
      final pdf = asText(await buildCertificatePdf(certificate(), 'Bharat Buyer', marks: const CertificateMarks()));
      expect(pdf, startsWith('%PDF-1.4'));
      expect(pdf, endsWith('%%EOF'));

      final xref = crossReference(pdf);
      // Catalogue, pages, page, content and the four fonts; no picture was given.
      expect(xref.offsets.length, 9, reason: 'the free entry and eight objects');
      for (var n = 1; n < xref.offsets.length; n++) {
        expect(pdf.substring(xref.offsets[n]), startsWith('$n 0 obj\n'), reason: 'object $n');
      }
      expect(pdf, contains('trailer\n<< /Size 9 /Root 1 0 R >>'));
      expect(pdf, contains('/MediaBox [0 0 842 595]'));
    });

    test('declares the four base-14 fonts and no picture when none was given', () async {
      final pdf = asText(await buildCertificatePdf(certificate(), 'Bharat Buyer', marks: const CertificateMarks()));
      for (final font in ['Helvetica', 'Helvetica-Bold', 'Times-BoldItalic', 'Courier-Bold']) {
        expect(pdf, contains('/BaseFont /$font /Encoding /WinAnsiEncoding'));
      }
      expect(pdf, contains('/F1 5 0 R /F2 6 0 R /F3 7 0 R /F4 8 0 R'));
      expect(pdf, isNot(contains('/Subtype /Image')));
      expect(pdf, isNot(contains('/XObject')));
    });

    test('says what the certificate says, as text a reader can select', () async {
      final pdf = asText(await buildCertificatePdf(certificate(), 'Bharat Buyer', marks: const CertificateMarks()));
      for (final shown in [
        'CERTIFICATE',
        'OF KNOWLEDGE ASSESSMENT',
        'This is to certify that',
        'For successfully completing :',
        'Communication',
        'FOUNDATION LEVEL',
        'The assessment was successfully cleared on : ',
        '22 October 2026',
        '22-OCT-2026',
        'ICR-COMMUNICAT-2026-01AZRIE7',
        'Issued Date:',
        'CERTIFICATE NO. :',
        'VINAY KUMAR SHETTY',
        'DIRECTOR, PROFESSIONAL DEVELOPMENT',
        'INSTITUTE FOR CORPORATE REAL ESTATE',
        'Scan to authenticate',
        'the certificate',
        'KNOWLEDGE PARTNER',
      ]) {
        expect(pdf, contains('($shown) Tj'), reason: shown);
      }
    });

    test('sets the stand-ins when a mark is missing: the ICR wordmark, the drawn seal, the name in Times', () async {
      final pdf = asText(await buildCertificatePdf(certificate(), 'Bharat Buyer', marks: const CertificateMarks()));
      expect(pdf, contains('(INSTITUTE FOR CORPORATE REAL ESTATE) Tj'));
      expect(pdf, contains('/F2 34 Tf'));
      expect(pdf, contains('/F2 32 Tf'), reason: 'the drawn seal carries a 32 pt ICR');
      expect(pdf, contains('(Bharat Buyer) Tj'));
      expect(pdf, contains('/F3 42 Tf'), reason: 'the fallback name is Times-BoldItalic, 42 pt');
      expect(pdf, contains(' c\n'), reason: 'the seal is drawn from arcs');
    });

    test('a long name is set smaller, and a long title wraps to two lines', () async {
      final longName = 'Alexandria Montgomery-Featherstonehaugh';
      final title = 'Facilities Management Professional Practice and Strategic Assets';
      final pdf = asText(
        await buildCertificatePdf(certificate(title: title), longName, marks: const CertificateMarks()),
      );
      expect(pdf, contains('/F3 34 Tf'));
      final lines = titleLines(pdf);
      expect(lines.map((m) => m.group(2)), ['Facilities Management Professional', 'Practice and Strategic Assets']);
      expect(double.parse(lines[0].group(1)!) - double.parse(lines[1].group(1)!), 26);
    });

    test('a title of three lines keeps two, as the website does', () async {
      final title = 'Facilities Management Professional Practice and Strategic Asset Stewardship';
      final pdf = asText(await buildCertificatePdf(certificate(title: title), 'x', marks: const CertificateMarks()));
      expect(titleLines(pdf).map((m) => m.group(2)), [
        'Facilities Management Professional',
        'Practice and Strategic Asset',
      ]);
      expect(pdf, isNot(contains('(Stewardship) Tj')));
    });

    test('sets a long certificate number smaller so it stays on the sheet', () async {
      Future<(double, String)> numberLine(String number) async {
        final c = ExamCertificate(
          id: 'c1',
          certificateId: number,
          title: 'Communication',
          issuedAt: DateTime(2026, 10, 22),
        );
        final pdf = asText(await buildCertificatePdf(c, 'Bharat Buyer', marks: const CertificateMarks()));
        final m = RegExp(
          '/F2 ([\\d.]+) Tf\\n1 0 0 1 660.00 54.00 Tm\\n\\(${RegExp.escape(number)}\\) Tj',
        ).firstMatch(pdf)!;
        return (double.parse(m.group(1)!), number);
      }

      final usual = await numberLine('ICR-CCREA-2026-8ZQ4R1KD');
      expect(usual.$1, 11, reason: 'the website\'s numbers are set at 11 pt');
      final long = await numberLine('ICR-COMMUNICAT-2026-01AZRIE7');
      expect(long.$1, lessThan(11));
      expect(660 + textWidth(long.$2, PdfFont.bold, long.$1), lessThanOrEqualTo(842 - 10), reason: 'inside the frame');
    });

    test('a credential with no level has no level line', () async {
      final pdf = asText(
        await buildCertificatePdf(certificate(level: null), 'Bharat Buyer', marks: const CertificateMarks()),
      );
      expect(pdf, isNot(contains('LEVEL) Tj')));
      expect(pdf, contains('(22 October 2026) Tj'));
    });

    test('names the awarding body when it is not ICR', () async {
      final pdf = asText(
        await buildCertificatePdf(
          certificate(provider: 'Leoron Institute'),
          'Bharat Buyer',
          marks: const CertificateMarks(),
        ),
      );
      expect(pdf, contains('(AWARDING BODY) Tj'));
      expect(pdf, contains('(LEORON INSTITUTE) Tj'));
      expect(
        asText(await buildCertificatePdf(certificate(), 'x', marks: const CertificateMarks())),
        isNot(contains('AWARDING BODY')),
      );
    });

    test('draws the verification QR code as vector squares', () async {
      final pdf = asText(await buildCertificatePdf(certificate(), 'Bharat Buyer', marks: const CertificateMarks()));
      // One filled square a dark module, each a hair over a cell; the code is 62 pt across.
      final code = QrCode.encode(verifyUri('ICR-COMMUNICAT-2026-01AZRIE7').toString());
      final dark = code.modules.expand((row) => row).where((on) => on).length;
      final squares = RegExp(r'^[\d.]+ [\d.]+ ([\d.]+) \1 re f$', multiLine: true).allMatches(pdf).toList();
      expect(squares.length, dark, reason: 'a square for every dark module, and nothing else of that shape');
      final cell = (62 / code.size + 0.06).toStringAsFixed(2);
      expect(squares.every((m) => m.group(1) == cell), isTrue);
    });

    test('embeds a picture as a compressed RGB image object whose length is its stream', () async {
      // 2 by 2 pixels: red, green / blue, white.
      final rgb = Uint8List.fromList([255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 255]);
      final bytes = await buildCertificatePdf(
        certificate(),
        'Bharat Buyer',
        marks: CertificateMarks(seal: RasterImage(rgb: rgb, width: 2, height: 2)),
      );
      final pdf = asText(bytes);
      expect(RegExp('/Subtype /Image').allMatches(pdf).length, 1);
      expect(pdf, contains('/Width 2 /Height 2 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode'));
      expect(pdf, contains('/XObject << /Im1 9 0 R >>'));
      expect(pdf, contains('/Im1 Do'));
      // The seal's drawn stand-in (the 32 pt ICR) is gone: the picture takes its place.
      expect(pdf, isNot(contains('/F2 32 Tf')));

      final xref = crossReference(pdf);
      expect(xref.offsets.length, 10);
      expect(pdf.substring(xref.offsets[9]), startsWith('9 0 obj\n<< /Type /XObject /Subtype /Image'));

      final at = xref.offsets[9];
      final length = int.parse(RegExp(r'/Length (\d+) >>').firstMatch(pdf.substring(at))!.group(1)!);
      final streamStart = pdf.indexOf('stream\n', at) + 'stream\n'.length;
      expect(pdf.substring(streamStart + length, streamStart + length + '\nendstream'.length), '\nendstream');
      // A zlib stream: the header byte 0x78, and it holds the four pixels.
      expect(bytes[streamStart], 0x78);
    });

    test('numbers the pictures in the order they are placed, only for those that are there', () async {
      final px = RasterImage(rgb: Uint8List.fromList([0, 0, 0]), width: 1, height: 1);
      final pdf = asText(
        await buildCertificatePdf(
          certificate(),
          'Bharat Buyer',
          marks: CertificateMarks(signature: px, name: px),
        ),
      );
      expect(pdf, contains('/XObject << /Im1 9 0 R /Im2 10 0 R >>'));
      expect(RegExp('/Subtype /Image').allMatches(pdf).length, 2);
      final xref = crossReference(pdf);
      expect(xref.offsets.length, 11);
      for (var n = 1; n < xref.offsets.length; n++) {
        expect(pdf.substring(xref.offsets[n]), startsWith('$n 0 obj\n'), reason: 'object $n');
      }
      // The name is the last picture placed, in the 380 by 72 box; the signature the 150 by 34 one.
      expect(pdf, contains('/Im1 Do'));
      expect(pdf, contains('/Im2 Do'));
    });
  });

  group('the text helpers', () {
    test('toLatin1 folds the typography and drops what Latin-1 cannot carry', () {
      expect(toLatin1('It’s “fine” – really…'), 'It\'s "fine" - really...');
      expect(toLatin1('a b'), 'a b');
      expect(toLatin1('café'), 'café', reason: 'Latin-1 stays');
      expect(toLatin1('आर a\nb'), ' ab', reason: 'Devanagari and control characters go');
    });

    test('escapePdf escapes the backslash and both brackets', () {
      expect(escapePdf(r'a(b)c\d'), r'a\(b\)c\\d');
    });

    test('a bracket in a name is escaped in the file', () async {
      final pdf = asText(await buildCertificatePdf(certificate(), 'A (B) C', marks: const CertificateMarks()));
      expect(pdf, contains(r'(A \(B\) C) Tj'));
    });

    test('the width tables hold ASCII 32 to 126', () {
      expect(helveticaWidths.length, 95);
      expect(helveticaBoldWidths.length, 95);
      expect(helveticaWidths[' '.codeUnitAt(0) - 32], 278);
      expect(helveticaWidths['W'.codeUnitAt(0) - 32], 944);
      expect(helveticaBoldWidths['a'.codeUnitAt(0) - 32], 556);
      expect(helveticaBoldWidths['~'.codeUnitAt(0) - 32], 584);
    });

    test('textWidth is the sum of the advances, plus tracking between letters', () {
      expect(textWidth('ICR', PdfFont.bold, 34), (278 + 722 + 722) / 1000 * 34);
      expect(textWidth('ICR', PdfFont.bold, 34, 2), (278 + 722 + 722) / 1000 * 34 + 2 * 2);
      expect(textWidth('ICR', PdfFont.regular, 10), (278 + 722 + 722) / 1000 * 10);
      expect(textWidth('', PdfFont.bold, 34, 2), 0, reason: 'no letters, no tracking');
      expect(textWidth('I', PdfFont.bold, 34, 2), 278 / 1000 * 34, reason: 'one letter has nothing to track against');
    });

    test('a character outside ASCII counts as an average one', () {
      expect(textWidth('é', PdfFont.regular, 10), 556 / 1000 * 10);
      expect(textWidth('é', PdfFont.bold, 10), 611 / 1000 * 10);
    });

    test('wrapText breaks on a word at the column width', () {
      expect(wrapText('Communication', PdfFont.bold, 20, 380), ['Communication']);
      final lines = wrapText(
        'Facilities Management Professional Practice and Strategic Asset Stewardship',
        PdfFont.bold,
        20,
        380,
      );
      expect(lines.length, greaterThan(1));
      for (final line in lines) {
        expect(textWidth(line, PdfFont.bold, 20), lessThanOrEqualTo(380));
      }
      expect(wrapText('   ', PdfFont.bold, 20, 380), ['']);
    });
  });
}
