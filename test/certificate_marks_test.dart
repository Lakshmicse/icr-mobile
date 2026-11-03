// The pictures on the certificate PDF, decoded by the real Flutter engine: a mark is flattened onto the colour it
// sits on, scaled down when it is wide, and one that cannot load is left out rather than failing the download.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/learning_exam/certificate_marks.dart';
import 'package:icr_mobile/features/learning_exam/certificate_pdf.dart';
import 'package:icr_mobile/features/learning_exam/exam_models.dart';

import 'helpers/fonts.dart';

/// A PNG [w] by [h] drawn by [paint].
Future<Uint8List> png(int w, int h, void Function(ui.Canvas canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  image.dispose();
  picture.dispose();
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

List<int> pixel(RasterImage image, int x, int y) {
  final at = (y * image.width + x) * 3;
  return [image.rgb[at], image.rgb[at + 1], image.rgb[at + 2]];
}

ExamCertificate certificate({String? logo}) => ExamCertificate(
  id: 'c1',
  certificateId: 'ICR-COMMUNICAT-2026-01AZRIE7',
  title: 'Communication',
  level: 'FOUNDATION',
  providerName: logo == null ? null : 'Leoron Institute',
  providerLogoUrl: logo,
  issuedAt: DateTime(2026, 10, 22),
  clearedAt: DateTime(2026, 10, 22),
);

void main() {
  setUpAll(loadAppFonts);
  tearDown(CertificatePdfServices.reset);

  const tint = ui.Color(0xFFF2F6FA);

  testWidgets('a transparent mark takes the colour it sits on, a solid one keeps its own', (tester) async {
    await tester.runAsync(() async {
      // Left pixel clear, middle pixel solid red, right pixel half black.
      final bytes = await png(3, 1, (canvas) {
        canvas.drawRect(const ui.Rect.fromLTWH(1, 0, 1, 1), ui.Paint()..color = const ui.Color(0xFFFF0000));
        canvas.drawRect(const ui.Rect.fromLTWH(2, 0, 1, 1), ui.Paint()..color = const ui.Color(0x80000000));
      });
      final raster = (await rasterFromPng(bytes, background: tint))!;
      expect([raster.width, raster.height], [3, 1]);
      expect(raster.rgb.length, 9);
      expect(pixel(raster, 0, 0), [0xF2, 0xF6, 0xFA], reason: 'clear: the panel shows through');
      expect(pixel(raster, 1, 0), [255, 0, 0], reason: 'solid: untouched');
      final half = pixel(raster, 2, 0);
      expect(half[0], closeTo(0xF2 * 0.5, 3), reason: 'half black over the tint: half the tint');
      expect(half[1], closeTo(0xF6 * 0.5, 3));
      expect(half[2], closeTo(0xFA * 0.5, 3));
    });
  });

  testWidgets('a wide picture is scaled down to the width asked, keeping its shape', (tester) async {
    await tester.runAsync(() async {
      final bytes = await png(1200, 300, (canvas) {
        canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 1200, 300), ui.Paint()..color = const ui.Color(0xFF12406E));
      });
      final scaled = (await rasterFromPng(bytes, background: tint))!;
      expect([scaled.width, scaled.height], [600, 150]);
      final narrow = (await rasterFromPng(bytes, background: tint, maxWidth: 1200))!;
      expect([narrow.width, narrow.height], [1200, 300], reason: 'not wider than the limit: left alone');
      expect(pixel(scaled, 300, 75), [0x12, 0x40, 0x6E]);
    });
  });

  testWidgets('bytes that are not a picture give null, not an exception', (tester) async {
    await tester.runAsync(() async {
      expect(await rasterFromPng(Uint8List.fromList([1, 2, 3, 4]), background: tint), isNull);
      expect(await rasterFromPng(Uint8List(0), background: tint), isNull);
    });
  });

  testWidgets('the name is rendered in gold on white at four times its printed size', (tester) async {
    await tester.runAsync(() async {
      final name = (await renderEngrossedName('Bharat Buyer', certificateNamePt))!;
      expect(name.height, (certificateNamePt * 4 * 1.25).ceil());
      expect(name.width, greaterThan(name.height * 3), reason: 'a name is a wide, short picture');
      expect(name.rgb.length, name.width * name.height * 3);
      expect(pixel(name, 0, 0), [255, 255, 255], reason: 'white ground');
      final gold = <List<int>>[];
      for (var i = 0; i < name.rgb.length; i += 3) {
        if (name.rgb[i] < 200 && name.rgb[i + 2] < 140) gold.add([name.rgb[i], name.rgb[i + 1], name.rgb[i + 2]]);
      }
      expect(gold, isNotEmpty, reason: 'the letters are drawn in the gold');
      expect(gold.first[0], greaterThan(150));
    });
  });

  testWidgets('a very long name is kept to a picture the graphics chip will take', (tester) async {
    await tester.runAsync(() async {
      final name = (await renderEngrossedName('Alexandria ' * 12, certificateNamePt * 0.78))!;
      expect(name.width, lessThanOrEqualTo(3100));
      expect(name.height, lessThan(300));
    });
  });

  testWidgets('every mark loads: the four bundled ones, the awarding body\'s logo and the name', (tester) async {
    await tester.runAsync(() async {
      final fetched = <String>[];
      final logo = await png(40, 20, (canvas) {
        canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 40, 20), ui.Paint()..color = const ui.Color(0xFF1B7FD7));
      });
      CertificatePdfServices.fetch = (url) async {
        fetched.add(url);
        return logo;
      };
      final c = certificate(logo: '/uploads/providers/leoron.png');
      final marks = await loadCertificateMarks(c, 'Bharat Buyer');
      expect(marks.icrLogo, isNotNull);
      expect(marks.seal, isNotNull);
      expect(marks.partner, isNotNull);
      expect(marks.signature, isNotNull);
      expect(marks.providerLogo, isNotNull);
      expect(marks.name, isNotNull);
      expect(marks.icrLogo!.width, lessThanOrEqualTo(600));
      expect(fetched.single, endsWith('/uploads/providers/leoron.png'));
      expect(fetched.single, startsWith('http'), reason: 'an upload path is made absolute first');
      expect([marks.providerLogo!.width, marks.providerLogo!.height], [40, 20]);

      // And they all go into the file: six pictures, each a compressed RGB image.
      final pdf = String.fromCharCodes(await buildCertificatePdf(c, 'Bharat Buyer', marks: marks));
      expect(RegExp('/Subtype /Image').allMatches(pdf).length, 6);
      expect(pdf, contains('/XObject << /Im1 9 0 R /Im2 10 0 R /Im3 11 0 R /Im4 12 0 R /Im5 13 0 R /Im6 14 0 R >>'));
    });
  });

  testWidgets('a mark that will not load is left out; the rest still do', (tester) async {
    await tester.runAsync(() async {
      CertificatePdfServices.fetch = (url) async => throw StateError('offline');
      CertificatePdfServices.renderName = (holder, size) async => throw StateError('no text engine');
      final marks = await loadCertificateMarks(certificate(logo: 'https://example.org/logo.png'), 'Bharat Buyer');
      expect(marks.providerLogo, isNull);
      expect(marks.name, isNull);
      expect(marks.seal, isNotNull);
      expect(marks.signature, isNotNull);

      CertificatePdfServices.fetch = (url) async => Uint8List.fromList([0, 1, 2]);
      final junk = await loadCertificateMarks(certificate(logo: 'https://example.org/logo.png'), 'Bharat Buyer');
      expect(junk.providerLogo, isNull, reason: 'bytes that are not a picture');
    });
  });

  testWidgets('a certificate with no awarding body fetches nothing, and a long name is set smaller', (tester) async {
    await tester.runAsync(() async {
      var fetched = 0;
      final sizes = <double>[];
      CertificatePdfServices.fetch = (url) async {
        fetched++;
        return null;
      };
      CertificatePdfServices.renderName = (holder, size) async {
        sizes.add(size);
        return null;
      };
      await loadCertificateMarks(certificate(), 'Bharat Buyer');
      await loadCertificateMarks(certificate(), 'Alexandria Montgomery-Featherstonehaugh');
      expect(fetched, 0);
      expect(sizes[0], certificateNamePt);
      expect(sizes[1], closeTo(certificateNamePt * 0.78, 1e-9));
    });
  });
}
