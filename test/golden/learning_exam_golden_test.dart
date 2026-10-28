@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/learning_exam/brief_controller.dart';
import 'package:icr_mobile/features/learning_exam/brief_sheet.dart';
import 'package:icr_mobile/features/learning_exam/certificate_view.dart';
import 'package:icr_mobile/features/learning_exam/certificates_screen.dart';
import 'package:icr_mobile/features/learning_exam/exam_controller.dart';
import 'package:icr_mobile/features/learning_exam/exam_models.dart';
import 'package:icr_mobile/features/learning_exam/exam_progress_store.dart';
import 'package:icr_mobile/features/learning_exam/exam_screen.dart';
import 'package:icr_mobile/features/learning_exam/exam_services.dart';
import 'package:icr_mobile/features/learning_exam/exam_sheets.dart';
import 'package:icr_mobile/features/learning_exam/my_attempts_screen.dart';
import 'package:icr_mobile/features/learning_exam/result_screen.dart';
import 'package:icr_mobile/features/learning_exam/verify_sheet.dart';

import '../helpers/fonts.dart';
import '../learning_exam_fakes.dart';

/// The exam flow's screens at the phone's frame (390 x 844), drawn from the API's own recorded answers
/// (`test/fixtures/learning_exam/`: Capital Planning - Foundation and ASHRAE BEMP - Set 1, Bharat Buyer's
/// history and certificate), and exported at 2x to build/screens/.
void main() {
  setUpAll(loadAppFonts);

  late FakeClock clock;
  late FakeExam repo;
  late MemoryExamProgressStore store;
  final boundary = GlobalKey();

  setUp(() {
    clock = FakeClock(DateTime(2026, 10, 23, 12));
    store = MemoryExamProgressStore();
    ExamServices.progress = store;
    ExamServices.now = clock.call;
    final cp = PaperSitting.fromJson(recorded('sitting_cp_foundation') as Map<String, dynamic>);
    repo = FakeExam(sittingValue: cp);
  });

  tearDown(ExamServices.reset);

  // flutter_test draws every shadow as a hard-edged offset shape (debugDisableShadows), which hides the soft ones
  // of the title bar and the pinned bars. Each test draws with real blur, and puts the flag back before it ends.
  void shadowed(String name, Future<void> Function(WidgetTester tester) body) {
    testWidgets(name, (tester) async {
      debugDisableShadows = false;
      try {
        await body(tester);
      } finally {
        debugDisableShadows = true;
      }
    });
  }

  void phone(WidgetTester tester, {double height = 844}) {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = Size(780, height * 2);
    addTearDown(tester.view.reset);
  }

  Widget app(Widget home) => RepaintBoundary(
    key: boundary,
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(), home: home),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  /// A widget test cannot wait on an asset image: decode every image on screen first.
  Future<void> precacheAll(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pump();
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    final render = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundary));
    await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/screens').createSync(recursive: true);
      File('build/screens/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    await expectLater(find.byKey(boundary), matchesGoldenFile('goldens/$name.png'));
  }

  /// A button that opens the brief.
  Future<void> openBrief(WidgetTester tester, BriefController brief) async {
    phone(tester);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(onPressed: () => showBriefSheet(context, brief), child: const Text('open brief')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open brief'));
    await settle(tester);
  }

  BriefController briefFor(String slug) => BriefController(
    repository: repo,
    ref: PaperRef(slug: slug, title: 'Foundation'),
    store: store,
    userId: 'u1',
    now: clock.call,
  );

  shadowed('the brief of an open paper', (tester) async {
    await openBrief(tester, briefFor('capital-planning-foundation'));
    await shoot(tester, 'exam_brief');
  });

  shadowed('the brief of a paper the member has sat, with a certificate held', (tester) async {
    repo.attemptsValue = [
      for (final r in (recorded('attempts_bharat') as List).cast<Map<String, dynamic>>()) Attempt.fromJson(r),
    ].where((a) => a.paper!.slug == 'capital-planning-foundation').toList();
    repo.certificatesValue = [
      for (final r in (recorded('certificates_bharat') as List).cast<Map<String, dynamic>>())
        ExamCertificate.fromJson(r),
    ];
    await openBrief(tester, briefFor('capital-planning-foundation'));
    await shoot(tester, 'exam_brief_record');
  });

  shadowed('the brief of a paper the member has not opened', (tester) async {
    repo.lock = PaperLock.fromJson(recorded('locked_procurement') as Map<String, dynamic>);
    repo.infoValue = PaperInfo.fromJson(
      (recorded('papers_list') as List).cast<Map<String, dynamic>>().firstWhere(
        (r) => r['slug'] == 'procurement-management-foundation',
      ),
    );
    repo.quoteValue = PaperQuote.fromJson(recorded('quote_procurement') as Map<String, dynamic>);
    await openBrief(tester, briefFor('procurement-management-foundation'));
    await shoot(tester, 'exam_brief_locked');
  });

  Future<ExamController> pumpExam(WidgetTester tester, PaperSitting sitting, {ExamSnapshot? resume}) async {
    phone(tester);
    final c = ExamController(
      sitting: sitting,
      repository: repo,
      store: store,
      userId: 'u1',
      now: clock.call,
      resume: resume,
    );
    await tester.pumpWidget(app(ExamScreen(controller: c, firstName: 'Bharat')));
    await tester.pump();
    return c;
  }

  shadowed('the exam window on a single-choice question, answered', (tester) async {
    final c = await pumpExam(tester, repo.sittingValue!);
    c.select(1);
    c.goTo(1);
    c.select(0);
    clock.advance(const Duration(minutes: 7, seconds: 18));
    c.tick();
    await tester.pump();
    await shoot(tester, 'exam_question');
  });

  shadowed('the exam window on a multiple-choice question, flagged, with the clock low', (tester) async {
    final sitting = PaperSitting.fromJson(recorded('sitting_bemp') as Map<String, dynamic>);
    final c = await pumpExam(tester, sitting);
    c.select(0);
    c.goTo(1);
    c.select(0);
    c.goTo(2);
    c.select(0);
    c.select(1);
    c.select(3);
    c.toggleFlag();
    clock.advance(const Duration(minutes: 26, seconds: 41));
    c.tick();
    await tester.pump();
    await shoot(tester, 'exam_question_multiple');
  });

  shadowed('the question palette', (tester) async {
    final c = await pumpExam(tester, repo.sittingValue!);
    c.select(1);
    c.goTo(1);
    c.goTo(2);
    c.toggleFlag();
    c.goTo(3);
    c.select(2);
    c.toggleFlag();
    c.goTo(4);
    c.goTo(5);
    c.select(0);
    showExamSheet<void>(
      tester.element(find.byType(ExamScreen)),
      (sheet) => PaletteSheet(controller: c, onJump: (_) {}, onReview: () {}),
    );
    await settle(tester);
    await shoot(tester, 'exam_palette');
  });

  shadowed('the submit overview', (tester) async {
    final c = await pumpExam(tester, repo.sittingValue!);
    c.select(1);
    c.goTo(1);
    c.select(0);
    c.goTo(2);
    c.toggleFlag();
    c.goTo(3);
    c.select(2);
    c.goTo(4);
    c.select(1);
    c.toggleFlag();
    clock.advance(const Duration(minutes: 11));
    c.tick();
    showExamSheet<void>(
      tester.element(find.byType(ExamScreen)),
      (sheet) => OverviewSheet(controller: c, onJump: (_) {}, onSubmit: () {}),
    );
    await settle(tester);
    await shoot(tester, 'exam_overview');
  });

  shadowed('a send that failed', (tester) async {
    repo.onSubmit = (_, _, _) async =>
        throw ApiError("Can't reach ICR right now. Check your connection and try again.");
    final c = await pumpExam(tester, repo.sittingValue!);
    c.select(1);
    await c.submit();
    await settle(tester);
    await shoot(tester, 'exam_send_failed');
  });

  Future<void> pumpResult(WidgetTester tester, AttemptResult result, {String? suffix}) async {
    phone(tester);
    await tester.pumpWidget(
      app(
        ResultScreen(
          result: result,
          paperName: 'Capital Planning – Foundation',
          certificateEnabled: true,
          firstName: 'Bharat',
          onRetake: () {},
          eyebrowSuffix: suffix,
        ),
      ),
    );
    await settle(tester);
  }

  shadowed('the result of a sitting that passed, with its certificate', (tester) async {
    await pumpResult(
      tester,
      AttemptResult.fromJson(recorded('result_cp3') as Map<String, dynamic>),
      suffix: ' · 22 Oct 2026',
    );
    await shoot(tester, 'exam_result_pass');
  });

  shadowed('the result of a sitting that missed, reviewed', (tester) async {
    await pumpResult(tester, AttemptResult.fromJson(recorded('result_cp1') as Map<String, dynamic>));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -820));
    await settle(tester);
    await shoot(tester, 'exam_result_review');
  });

  shadowed('My attempts', (tester) async {
    phone(tester);
    repo.unread = 1;
    repo.attemptsValue = [
      for (final r in (recorded('attempts_bharat') as List).cast<Map<String, dynamic>>()) Attempt.fromJson(r),
    ];
    await tester.pumpWidget(app(MyAttemptsScreen(onBack: () {}, repository: repo)));
    await settle(tester);
    await shoot(tester, 'exam_attempts');
  });

  shadowed('My certificates', (tester) async {
    phone(tester, height: 1000);
    repo.unread = 1;
    repo.certificatesValue = [
      for (final r in (recorded('certificates_bharat') as List).cast<Map<String, dynamic>>())
        ExamCertificate.fromJson(r),
    ];
    await tester.pumpWidget(app(CertificatesScreen(onBack: () {}, repository: repo, holder: 'Bharat Buyer')));
    await settle(tester);
    await shoot(tester, 'exam_certificates');
  });

  shadowed('a certificate', (tester) async {
    phone(tester);
    final cert = ExamCertificate.fromJson((recorded('certificates_bharat') as List).first as Map<String, dynamic>);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showCertificateSheet(context, cert, holder: 'Bharat Buyer'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    await precacheAll(tester);
    await shoot(tester, 'exam_certificate');
  });

  shadowed('the register, with a number that checks out', (tester) async {
    phone(tester);
    repo.register['ICR-CP-2026-DSGNLF01'] = ExamCertificate.fromJson(
      recorded('certificate_public') as Map<String, dynamic>,
    );
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showVerifySheet(context, repo, initial: 'ICR-CP-2026-DSGNLF01'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    await tester.tap(find.text('Verify'));
    await settle(tester);
    await shoot(tester, 'exam_register');
  });
}
