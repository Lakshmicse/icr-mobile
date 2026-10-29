import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/library/library_models.dart';
import 'package:icr_mobile/features/library/pdf_engine.dart';
import 'package:icr_mobile/features/library/preview_runner.dart';
import 'package:icr_mobile/features/library/screen_security.dart';
import 'package:icr_mobile/features/library/widgets/data_grid.dart';
import 'package:icr_mobile/features/library/widgets/document_viewer_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'helpers/community_fakes.dart';
import 'helpers/office_fixtures.dart';

Uint8List seed(String name) => File('tool/seed/assets/library/$name').readAsBytesSync();

/// The viewer on a file, reading Office files in place, over a navigator so a ZIP entry can open on top.
Future<void> _pump(
  WidgetTester tester,
  Uint8List bytes,
  String name,
  PreviewKind kind, {
  PdfEngine? pdf,
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  // A fresh screen each time, as the app always pushes one, so no state carries over from the last file.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: DocumentViewerScreen(
        file: DocumentBytes(bytes: bytes, fileName: name, mimeType: ''),
        kind: kind,
        pdf: pdf ?? FakePdfEngine(),
        runner: runHere,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the viewer takes nothing out of the app', () {
    testWidgets('it has no download, share or save control for any kind of file', (tester) async {
      final cases = <(Uint8List, String, PreviewKind)>[
        (seed('fm-handover-checklist.pdf'), 'a.pdf', PreviewKind.pdf),
        (seed('energy-dashboard.png'), 'a.png', PreviewKind.image),
        (seed('visitor-management-policy.txt'), 'a.txt', PreviewKind.text),
        (seed('ppm-calendar.csv'), 'a.csv', PreviewKind.table),
        (seed('incident-report-template.docx'), 'a.docx', PreviewKind.word),
        (seed('ppm-schedule.xlsx'), 'a.xlsx', PreviewKind.sheets),
        (seed('gcc-workplace-briefing.pptx'), 'a.pptx', PreviewKind.slides),
        (seed('contractor-induction-pack.zip'), 'a.zip', PreviewKind.archive),
      ];
      for (final (bytes, name, kind) in cases) {
        await _pump(tester, bytes, name, kind);
        expect(find.byType(DocumentViewerScreen), findsOneWidget, reason: name);
        for (final icon in [LucideIcons.download, LucideIcons.share2, LucideIcons.externalLink, LucideIcons.save]) {
          expect(find.byIcon(icon), findsNothing, reason: '$name has no ${icon.codePoint}');
        }
        for (final tip in ['Download', 'Share', 'Save', 'Open in']) {
          expect(find.byTooltip(tip), findsNothing, reason: '$name: $tip');
        }
        // There is nothing in the bar but the title (and Back, once there is a screen to go back to).
        expect(tester.widget<AppBar>(find.byType(AppBar)).actions, anyOf(isNull, isEmpty), reason: name);
      }
    });

    testWidgets('it keeps the window out of screenshots while it is open and lets go when it closes', (tester) async {
      final platform = FakeScreenSecurity();
      ScreenSecurity.platform = platform;
      addTearDown(() => ScreenSecurity.platform = const MethodChannelScreenSecurity());
      await _pump(tester, seed('visitor-management-policy.txt'), 'a.txt', PreviewKind.text);
      expect(ScreenSecurity.holds, 1);
      expect(platform.requests, [true]);
      await tester.pumpWidget(const SizedBox());
      expect(ScreenSecurity.holds, 0);
      expect(platform.requests, [true, false]);
    });
  });

  group('screen protection', () {
    test('is counted: on with the first screen, off only when the last one leaves', () {
      final platform = FakeScreenSecurity();
      ScreenSecurity.platform = platform;
      addTearDown(() => ScreenSecurity.platform = const MethodChannelScreenSecurity());
      ScreenSecurity.hold();
      ScreenSecurity.hold();
      ScreenSecurity.hold();
      expect(platform.requests, [true]);
      ScreenSecurity.release();
      ScreenSecurity.release();
      expect(platform.requests, [true]);
      ScreenSecurity.release();
      expect(platform.requests, [true, false]);
      ScreenSecurity.release(); // an extra release changes nothing
      expect(ScreenSecurity.holds, 0);
      expect(platform.requests, [true, false]);
    });
  });

  group('PDF', () {
    testWidgets('draws every page, says which one you are on, and lets the document go on closing', (tester) async {
      final pdf = FakePdfEngine(pages: 5);
      await _pump(tester, seed('fm-handover-checklist.pdf'), 'fm.pdf', PreviewKind.pdf, pdf: pdf);
      expect(find.text('fm.pdf'), findsOneWidget);
      expect(find.text('Page 1 of 5'), findsOneWidget);
      expect(pdf.opened.single.take(5), '%PDF-'.codeUnits);
      expect(pdf.rendered.map((r) => r.$1), contains(0));
      // Only the pages near the screen are drawn.
      expect(pdf.rendered.map((r) => r.$1).toSet().length, lessThan(5));

      await tester.drag(find.byType(ListView).first, const Offset(0, -1500));
      await tester.pumpAndSettle();
      final page = find.textContaining('Page ').evaluate().map((e) => (e.widget as Text).data).first!;
      expect(page, isNot('Page 1 of 5'));
      expect(pdf.rendered.map((r) => r.$1), contains(4));

      await tester.pumpWidget(const SizedBox());
      expect(pdf.closed, 1);
    });

    testWidgets('zoom in draws sharper pages that scroll sideways; zoom out comes back', (tester) async {
      final pdf = FakePdfEngine(pages: 2);
      await _pump(tester, seed('fm-handover-checklist.pdf'), 'fm.pdf', PreviewKind.pdf, pdf: pdf);
      final fit = pdf.rendered.first.$2;
      expect(find.byTooltip('Zoom out'), findsOneWidget);
      var out = tester.widget<IconButton>(find.widgetWithIcon(IconButton, LucideIcons.zoomOut));
      expect(out.onPressed, isNull, reason: 'already as small as it goes');

      pdf.rendered.clear();
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pumpAndSettle();
      expect(pdf.rendered.first.$2, greaterThan(fit * 1.4), reason: 'drawn again at 1.5 times the width');
      expect(find.byType(SingleChildScrollView), findsWidgets, reason: 'wider than the screen, so it scrolls sideways');

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byTooltip('Zoom in'), warnIfMissed: false);
        await tester.pumpAndSettle();
      }
      final inBtn = tester.widget<IconButton>(find.widgetWithIcon(IconButton, LucideIcons.zoomIn));
      expect(inBtn.onPressed, isNull, reason: 'at the largest');
      expect(pdf.rendered.map((r) => r.$2).reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(2600));

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byTooltip('Zoom out'), warnIfMissed: false);
        await tester.pumpAndSettle();
      }
      out = tester.widget<IconButton>(find.widgetWithIcon(IconButton, LucideIcons.zoomOut));
      expect(out.onPressed, isNull);
    });

    testWidgets('a PDF that cannot be opened says why, in words, and offers nothing else', (tester) async {
      await _pump(
        tester,
        Uint8List(10),
        'locked.pdf',
        PreviewKind.pdf,
        pdf: FakePdfEngine(failure: const PdfProblem("This PDF is password protected, so it can't be previewed.")),
      );
      expect(find.text("This PDF is password protected, so it can't be previewed."), findsOneWidget);
      expect(find.textContaining('Page '), findsNothing);
    });

    testWidgets('a PDF with no pages says so', (tester) async {
      await _pump(tester, Uint8List(10), 'none.pdf', PreviewKind.pdf, pdf: FakePdfEngine(pages: 0));
      expect(find.text('This PDF has no pages.'), findsOneWidget);
    });

    testWidgets('closing the viewer before the PDF has opened still lets it go', (tester) async {
      final pdf = FakePdfEngine();
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentViewerScreen(
            file: DocumentBytes(bytes: Uint8List(4), fileName: 'x.pdf', mimeType: ''),
            kind: PreviewKind.pdf,
            pdf: pdf,
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(pdf.closed, pdf.opened.length);
    });

    group('the real engine and the phone’s side of the channel', () {
      const channel = MethodChannel('org.icr.icr_mobile/pdf');
      final calls = <MethodCall>[];

      void phone(Future<Object?> Function(MethodCall call) handler) {
        calls.clear();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) {
          calls.add(call);
          return handler(call);
        });
        addTearDown(
          () =>
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
        );
      }

      test('open, render and close are the three calls, with the sizes and ids the phone gives', () async {
        phone((call) async {
          switch (call.method) {
            case 'open':
              return {
                'id': 'doc-1',
                'sizes': [
                  [595, 842],
                  [842, 595],
                ],
              };
            case 'render':
              return fakePagePng;
          }
          return null;
        });
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          final doc = await const PlatformPdfEngine().open(Uint8List.fromList([1, 2, 3]));
          expect(doc.pageCount, 2);
          expect(doc.pageSizes[1], const Size(842, 595));
          expect(calls.single.method, 'open');
          expect((calls.single.arguments as Map)['bytes'], [1, 2, 3]);
          expect(await doc.render(1, 900), fakePagePng);
          expect(calls.last.arguments, {'id': 'doc-1', 'page': 1, 'width': 900});
          await doc.close();
          await doc.close();
          expect(calls.where((c) => c.method == 'close'), hasLength(1), reason: 'closing twice is one call');
          expect(calls.last.arguments, {'id': 'doc-1'});
          await expectLater(doc.render(0, 100), throwsA(isA<PdfProblem>()));
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      test('a password-protected PDF and a damaged one are told apart, in words', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          phone((call) async => throw PlatformException(code: 'password'));
          await expectLater(
            const PlatformPdfEngine().open(Uint8List(2)),
            throwsA(isA<PdfProblem>().having((e) => e.message, 'message', contains('password protected'))),
          );
          phone((call) async => throw PlatformException(code: 'unreadable'));
          await expectLater(
            const PlatformPdfEngine().open(Uint8List(2)),
            throwsA(isA<PdfProblem>().having((e) => e.message, 'message', contains('damaged'))),
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      test('a page that fails to draw is a sentence for that page', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          phone((call) async {
            if (call.method == 'open') {
              return {
                'id': 'd',
                'sizes': [
                  [100, 100],
                ],
              };
            }
            throw PlatformException(code: 'unreadable');
          });
          final doc = await const PlatformPdfEngine().open(Uint8List(2));
          await expectLater(doc.render(0, 50), throwsA(isA<PdfProblem>()));
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      test('other platforms have no renderer wired and say so without asking the phone', () async {
        phone((call) async => null);
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          await expectLater(const PlatformPdfEngine().open(Uint8List(2)), throwsA(isA<PdfProblem>()));
          expect(calls, isEmpty);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    });

    group('screen protection on the phone’s side of the channel', () {
      const channel = MethodChannel('org.icr.icr_mobile/secure_screen');

      void mock(Future<Object?> Function(MethodCall call) handler) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, handler);
        addTearDown(
          () =>
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
        );
      }

      test('asks the phone for the flag on Android, and never on other platforms', () async {
        final calls = <MethodCall>[];
        mock((call) async {
          calls.add(call);
          return null;
        });
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          await const MethodChannelScreenSecurity().setSecure(true);
          await const MethodChannelScreenSecurity().setSecure(false);
          expect(calls.map((c) => (c.method, (c.arguments as Map)['on'])), [('setSecure', true), ('setSecure', false)]);
          calls.clear();
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          await const MethodChannelScreenSecurity().setSecure(true);
          expect(calls, isEmpty);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      test('a refusal from the window is swallowed', () async {
        mock((call) async => throw PlatformException(code: 'no'));
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          await const MethodChannelScreenSecurity().setSecure(true);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    });
  });

  group('images, text and CSV', () {
    testWidgets('an image is drawn and can be zoomed', (tester) async {
      await _pump(tester, seed('energy-dashboard.png'), 'energy.png', PreviewKind.image);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('a damaged image says so', (tester) async {
      await _pump(tester, Uint8List.fromList([1, 2, 3, 4]), 'bad.png', PreviewKind.image);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(find.text("This image can't be shown."), findsOneWidget);
    });

    testWidgets('a text file is shown line by line; an empty one says so', (tester) async {
      await _pump(tester, seed('visitor-management-policy.txt'), 'policy.txt', PreviewKind.text);
      expect(find.byType(Text), findsWidgets);
      expect(find.textContaining('visitor', findRichText: true, skipOffstage: false), findsWidgets);
      await _pump(tester, Uint8List.fromList('   \n\n'.codeUnits), 'blank.txt', PreviewKind.text);
      expect(find.text('This file is empty.'), findsOneWidget);
    });

    testWidgets('a long text file stops at the limit and says so', (tester) async {
      final lines = List.generate(20500, (i) => 'line $i').join('\n');
      await _pump(tester, Uint8List.fromList(lines.codeUnits), 'long.txt', PreviewKind.text);
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();
      expect(find.text('The rest of this file is not shown.'), findsOneWidget);
    });

    testWidgets('a CSV is a grid with its header row, and a long cell opens in full on tap', (tester) async {
      const long = 'A very long note about the plant room that cannot fit in one narrow column of the grid at all';
      final csv = 'Asset,Task,Note\nChiller,Tube clean,"$long"\nAHU,Filter,ok\n';
      await _pump(tester, Uint8List.fromList(csv.codeUnits), 'ppm.csv', PreviewKind.table);
      expect(find.byType(DataGrid), findsOneWidget);
      expect(find.text('Asset'), findsOneWidget);
      expect(find.text('Chiller'), findsOneWidget);
      expect(find.text('2'), findsOneWidget, reason: 'the row number gutter starts under the header');
      await tester.tap(find.byWidgetPredicate((w) => w is Text && w.data == long));
      await tester.pumpAndSettle();
      expect(find.text(long), findsNWidgets(2), reason: 'once in the cell, once in full in the sheet');
    });

    testWidgets('an empty CSV says so', (tester) async {
      await _pump(tester, Uint8List(0), 'e.csv', PreviewKind.table);
      expect(find.text('This file is empty.'), findsOneWidget);
    });
  });

  group('Word, Excel, PowerPoint and ZIP', () {
    testWidgets('a Word document: title, headings, bullets and a table', (tester) async {
      await _pump(tester, seed('incident-report-template.docx'), 'incident.docx', PreviewKind.word);
      expect(find.text('Incident Report Template'), findsOneWidget);
      expect(find.text('What happened'), findsOneWidget);
      expect(find.text('•'), findsWidgets);
      expect(find.text('Date, time and exact location'), findsOneWidget);

      await _pump(tester, seed('service-contract-review-checklist.docx'), 'check.docx', PreviewKind.word);
      await tester.dragUntilVisible(find.text('Scope schedule agreed'), find.byType(ListView), const Offset(0, -400));
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Scope schedule agreed'), findsOneWidget);
    });

    testWidgets('a workbook: its sheets as tabs over a grid; an empty sheet says so', (tester) async {
      final xlsx = buildXlsx({
        'Plan':
            '<row r="1"><c r="A1" t="inlineStr"><is><t>Asset</t></is></c><c r="B1" t="inlineStr"><is><t>Due</t></is></c></row>'
            '<row r="2"><c r="A2" t="inlineStr"><is><t>Chiller 1</t></is></c><c r="B2"><v>7</v></c></row>',
        'Blank': '',
      });
      await _pump(tester, xlsx, 'book.xlsx', PreviewKind.sheets);
      expect(find.widgetWithText(ChoiceChip, 'Plan'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Blank'), findsOneWidget);
      expect(find.text('Chiller 1'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Blank'));
      await tester.pumpAndSettle();
      expect(find.text('This sheet is empty.'), findsOneWidget);
      expect(find.text('Chiller 1'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Plan'));
      await tester.pumpAndSettle();
      expect(find.text('Chiller 1'), findsOneWidget);
    });

    testWidgets('a single-sheet workbook has no tabs', (tester) async {
      await _pump(tester, seed('lease-audit-template.xlsx'), 'lease.xlsx', PreviewKind.sheets);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('Base rent'), findsOneWidget);
    });

    testWidgets('a presentation: one card per slide with its title and lines', (tester) async {
      await _pump(tester, seed('gcc-workplace-briefing.pptx'), 'deck.pptx', PreviewKind.slides);
      expect(find.text('Slide 1 of 4'), findsOneWidget);
      expect(find.text('GCC Workplace Leadership: Quarterly Briefing'), findsOneWidget);
      await tester.dragUntilVisible(find.text('Slide 4 of 4'), find.byType(ListView), const Offset(0, -300));
      expect(find.text('Slide 4 of 4'), findsOneWidget);
    });

    testWidgets('a slide with no text says so', (tester) async {
      final deck = buildPptx(['<p:pic/>']);
      await _pump(tester, deck, 'pics.pptx', PreviewKind.slides);
      expect(find.text('No text on this slide. Pictures and shapes are not previewed.'), findsOneWidget);
    });

    testWidgets('the older formats open the same way: .doc, .xls and .ppt', (tester) async {
      await _pump(tester, buildDoc([('Site visit report\r', false)]), 'old.doc', PreviewKind.word);
      expect(find.text('Site visit report'), findsOneWidget);
      await _pump(
        tester,
        buildXls({
          'S': [const XlsCell.text(0, 0, 'Legacy cell')],
        }),
        'old.xls',
        PreviewKind.sheets,
      );
      expect(find.text('Legacy cell'), findsOneWidget);
      await _pump(
        tester,
        buildPpt(const [
          PptSlide(list: [(0, 'Legacy title', false)]),
        ]),
        'old.ppt',
        PreviewKind.slides,
      );
      expect(find.text('Legacy title'), findsOneWidget);
    });

    testWidgets('a ZIP lists its files; a text file opens in the viewer on top, and Back returns to the list', (
      tester,
    ) async {
      await _pump(tester, seed('contractor-induction-pack.zip'), 'pack.zip', PreviewKind.archive);
      expect(find.text('README.txt'), findsOneWidget);
      expect(find.text('induction-reference.pdf'), findsOneWidget);
      await tester.tap(find.text('README.txt'));
      await tester.pumpAndSettle();
      expect(
        find.byType(DocumentViewerScreen, skipOffstage: false),
        findsNWidgets(2),
        reason: 'the list stays underneath',
      );
      expect(ScreenSecurity.holds, 2, reason: 'and so does the screenshot protection');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(DocumentViewerScreen), findsOneWidget);
      expect(find.text('README.txt'), findsOneWidget);
    });

    testWidgets('a PDF inside a ZIP opens through the PDF viewer', (tester) async {
      final pdf = FakePdfEngine(pages: 2);
      await _pump(tester, seed('contractor-induction-pack.zip'), 'pack.zip', PreviewKind.archive, pdf: pdf);
      await tester.tap(find.text('induction-reference.pdf'));
      await tester.pumpAndSettle();
      expect(pdf.opened.single.take(5), '%PDF-'.codeUnits);
      expect(find.text('Page 1 of 2'), findsOneWidget);
    });

    testWidgets('a file inside a ZIP that has no viewer says so and stays put', (tester) async {
      final zip = buildZip({'plan.dwg': 'x', 'notes.txt': 'hello'});
      await _pump(tester, zip, 'odd.zip', PreviewKind.archive);
      await tester.tap(find.text('plan.dwg'));
      await tester.pumpAndSettle();
      expect(find.text("plan.dwg can't be previewed in the app."), findsOneWidget);
      expect(find.byType(DocumentViewerScreen), findsOneWidget);
    });

    testWidgets('a ZIP inside a ZIP opens, one level at a time', (tester) async {
      final inner = buildZip({'deep.txt': 'down here'});
      final zip = buildZipBytes({'inner.zip': inner});
      await _pump(tester, zip, 'outer.zip', PreviewKind.archive);
      await tester.tap(find.text('inner.zip'));
      await tester.pumpAndSettle();
      expect(find.text('deep.txt'), findsOneWidget);
      await tester.tap(find.text('deep.txt'));
      await tester.pumpAndSettle();
      expect(find.text('down here'), findsOneWidget);
    });

    testWidgets('a damaged file says it can’t be previewed instead of failing', (tester) async {
      final bad = Uint8List.fromList(seed('incident-report-template.docx').sublist(0, 400));
      await _pump(tester, bad, 'bad.docx', PreviewKind.word);
      expect(find.textContaining('damaged'), findsOneWidget);
      await _pump(tester, Uint8List.fromList(List.generate(300, (i) => i % 256)), 'junk.xlsx', PreviewKind.sheets);
      expect(find.textContaining('format the app can read'), findsOneWidget);
    });

    testWidgets('a file with no reader says so', (tester) async {
      await _pump(tester, Uint8List(4), 'plan.dwg', PreviewKind.none);
      expect(find.text("This kind of file can't be previewed in the app."), findsOneWidget);
    });
  });
}
