// The exam flow's screens, each control proved: the brief and what it takes to open a paper, the exam window
// (answers, flags, palette, overview, the clock, a failed send, leaving, rotation, the app in the background),
// the result and its review, My attempts, and My certificates. The API itself is exercised in
// test/live/learning_exam_live_test.dart.
import 'dart:async';
import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/learning_exam/brief_controller.dart';
import 'package:icr_mobile/features/learning_exam/brief_screen.dart';
import 'package:icr_mobile/features/learning_exam/certificate_marks.dart';
import 'package:icr_mobile/features/learning_exam/certificate_pdf.dart';
import 'package:icr_mobile/features/learning_exam/certificate_view.dart';
import 'package:icr_mobile/features/learning_exam/certificates_screen.dart';
import 'package:icr_mobile/features/learning_exam/exam_controller.dart';
import 'package:icr_mobile/features/learning_exam/exam_models.dart';
import 'package:icr_mobile/features/learning_exam/exam_progress_store.dart';
import 'package:icr_mobile/features/learning_exam/exam_screen.dart';
import 'package:icr_mobile/features/learning_exam/exam_services.dart';
import 'package:icr_mobile/features/learning_exam/exam_sheets.dart';
import 'package:icr_mobile/features/learning_exam/exam_widgets.dart';
import 'package:icr_mobile/features/learning_exam/my_attempts_screen.dart';
import 'package:icr_mobile/features/learning_exam/open_paper.dart';
import 'package:icr_mobile/features/learning_exam/result_screen.dart';
import 'package:icr_mobile/features/learning_exam/review_answers_screen.dart';

import 'helpers/fonts.dart';
import 'helpers/layout_audit.dart';
import 'learning_exam_fakes.dart';

/// A widget test with the semantics tree on, as a screen reader sees the screen.
void semanticTest(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await body(tester);
    } finally {
      handle.dispose();
    }
  });
}

void main() {
  setUpAll(loadAppFonts);

  late FakeClock clock;
  late FakeExam repo;
  late MemoryExamProgressStore store;
  final opened = <Uri>[];
  final shared = <String>[];

  setUp(() {
    clock = FakeClock();
    repo = FakeExam(sittingValue: sampleSitting());
    store = MemoryExamProgressStore();
    opened.clear();
    shared.clear();
    ExamServices.progress = store;
    ExamServices.now = clock.call;
    ExamServices.openUrl = (context, uri) async => opened.add(uri);
    ExamServices.openExternal = (context, uri) async => opened.add(uri);
    ExamServices.share = (text, {subject}) async => shared.add(text);
  });

  tearDown(ExamServices.reset);

  /// A phone, 390 by 844 dp.
  void phone(WidgetTester tester, {Size size = const Size(390, 844)}) {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = Size(size.width * 2, size.height * 2);
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await settle(tester);
  }

  Widget app(Widget home) => MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(), home: home);

  ExamController controllerFor(PaperSitting sitting, {ExamSnapshot? resume}) =>
      ExamController(sitting: sitting, repository: repo, store: store, userId: 'u1', now: clock.call, resume: resume);

  Future<ExamController> pumpExam(
    WidgetTester tester, {
    PaperSitting? sitting,
    ExamSnapshot? resume,
    String? firstName = 'Bharat',
    VoidCallback? onRetake,
    VoidCallback? onFlowEnd,
  }) async {
    phone(tester);
    final c = controllerFor(sitting ?? sampleSitting(), resume: resume);
    await tester.pumpWidget(
      app(ExamScreen(controller: c, firstName: firstName, onRetake: onRetake, onFlowEnd: onFlowEnd)),
    );
    await tester.pump();
    return c;
  }

  /// Whether the option reads as chosen to a screen reader (its letter is the one in its text: "Option B1" is B).
  bool optionChecked(WidgetTester tester, String text) {
    final node = tester.getSemantics(find.bySemanticsLabel('Option ${text[7]}. $text'));
    return node.getSemanticsData().flagsCollection.isChecked == CheckedState.isTrue;
  }

  /// What a screen reader says about number [n] of the exam's strip: "Go to question 3, answered, current".
  String stripLabel(WidgetTester tester, int n) => tester.getSemantics(find.byKey(ValueKey('strip-$n'))).label;

  /// Number [n] in the palette sheet (the strip behind it draws some of the same digits).
  Finder paletteNumber(int n) => find.descendant(of: find.byType(PaletteSheet), matching: find.text('$n'));

  /// Taps number [n] of the exam's strip.
  Future<void> goToQuestion(WidgetTester tester, int n) async {
    await tester.tap(find.byKey(ValueKey('strip-$n')));
    await settle(tester);
  }

  /// Scrolls the first scrollable until [target] is on screen.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(target, 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(target);
    await tester.pump();
  }

  /// A page with a button that pushes [child], so that closing it can be seen.
  Widget launched(Widget child) => app(
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => child)),
            child: const Text('start'),
          ),
        ),
      ),
    ),
  );

  // --- the brief ------------------------------------------------------------------------------------------

  group('the brief', () {
    /// A button that opens the brief page and records what it hands back. The phone is tall enough for the whole
    /// page (the design's frame is 912 dp), so every row is built; [size] says otherwise.
    Future<List<ExamStart?>> openBrief(
      WidgetTester tester,
      BriefController brief, {
      Size size = const Size(390, 1000),
    }) async {
      phone(tester, size: size);
      final results = <ExamStart?>[];
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () async => results.add(await showBriefPage(context, brief)),
                  child: const Text('open brief'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open brief'));
      await settle(tester);
      return results;
    }

    BriefController briefFor({String slug = 'cp-foundation', FakeExam? repository}) => BriefController(
      repository: repository ?? repo,
      ref: PaperRef(slug: slug, title: 'Foundation'),
      store: store,
      userId: 'u1',
      now: clock.call,
    );

    PaperInfo mockSet({int questions = 1, int minutes = 30, int? attemptLimit}) => samplePaper(
      slug: 'bemp-1',
      title: 'Set 1',
      kind: PaperKind.mock,
      certificate: false,
      minutes: minutes,
      questions: questions,
      attemptLimit: attemptLimit,
    );

    /// The right-hand edge of a table value.
    double rightOf(WidgetTester tester, String value) => tester.getTopRight(find.text(value)).dx;

    semanticTest('an open mock set, as the design draws it: the name, five lines, the details, Take test and Back', (
      tester,
    ) async {
      repo.sittingValue = sampleSitting(paper: mockSet(), questions: 1);
      final results = await openBrief(tester, briefFor(slug: 'bemp-1'));

      expect(find.text('ASHRAE BEMP Set 1'), findsOneWidget, reason: 'the subject and the set, no dash');
      expect(find.text('Before you start'), findsOneWidget);
      for (final line in [
        'The timer starts as soon as you begin and keeps running if you leave the page.',
        'Your answers are saved automatically — you can resume an interrupted attempt.',
        'You can move freely between questions and mark any for review.',
        'The paper submits itself when time runs out. Unanswered questions count as wrong.',
        'Attempts are unlimited. This paper is practice only; no certificate is issued.',
      ]) {
        expect(find.text(line), findsOneWidget, reason: line);
      }
      expect(find.text('Mock Exam details'), findsOneWidget);
      for (final label in [
        'Number of questions',
        'Total marks',
        'Duration',
        'Passing percentage',
        'Attempts allowed',
        'Attempts used',
        'Certificate',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('1'), findsNWidgets(2), reason: 'one question, one mark');
      expect(find.text('30 minutes'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget);
      expect(find.text('Unlimited'), findsOneWidget);
      expect(find.text('0'), findsOneWidget, reason: 'no attempts used');
      expect(find.text('Not issued'), findsOneWidget);
      expect(find.text('My attempts'), findsNothing, reason: 'nothing to list yet');
      expect(find.text('Take test'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      // The old sheet's words are gone.
      expect(find.text('Test parameters'), findsNothing);
      expect(find.text('Timed'), findsNothing);

      // Two columns: every value ends where the others do, and every label starts where the others do.
      expect(rightOf(tester, '30 minutes'), closeTo(rightOf(tester, 'Unlimited'), 0.5));
      expect(rightOf(tester, '30 minutes'), closeTo(rightOf(tester, 'Not issued'), 0.5));
      expect(
        tester.getTopLeft(find.text('Duration')).dx,
        closeTo(tester.getTopLeft(find.text('Attempts allowed')).dx, 0.5),
      );

      await tester.tap(find.text('Take test'));
      await settle(tester);
      expect(results, hasLength(1));
      expect(results.single!.sitting.questions, hasLength(1));
      expect(results.single!.resume, isNull);
      expect(find.text('Take test'), findsNothing, reason: 'the page closed');
    });

    semanticTest('a level paper is named for its programme and level, and says what a pass earns', (tester) async {
      repo.sittingValue = sampleSitting(paper: samplePaper(minutes: 45, questions: 5, pass: 75));
      await openBrief(tester, briefFor());
      expect(find.text('Capital Planning Foundation'), findsOneWidget);
      expect(find.text('Assessment details'), findsOneWidget);
      expect(find.text('Mock Exam details'), findsNothing);
      expect(find.text('45 minutes'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('Attempts are unlimited. A pass of 75% or more earns a certificate.'), findsOneWidget);
      expect(find.text('On a qualifying pass'), findsOneWidget, reason: 'the Certificate row, none held yet');
    });

    semanticTest('a limit on attempts is said in the last line and in the table', (tester) async {
      repo.sittingValue = sampleSitting(paper: samplePaper(attemptLimit: 3));
      repo.attemptsValue = [sampleAttempt()];
      await openBrief(tester, briefFor());
      expect(find.text('This paper allows 3 attempts. A pass of 70% or more earns a certificate.'), findsOneWidget);
      expect(find.text('3'), findsOneWidget, reason: 'attempts allowed');
      expect(find.text('1'), findsOneWidget, reason: 'attempts used');
      expect(find.text('Take test'), findsOneWidget);
    });

    semanticTest('two quick taps on Take test start one sitting and do not close the screen under the page', (
      tester,
    ) async {
      final results = await openBrief(tester, briefFor());
      await tester.tap(find.text('Take test'));
      await tester.tap(find.text('Take test'));
      await settle(tester);
      expect(results, hasLength(1));
      expect(find.text('open brief'), findsOneWidget, reason: 'the page that opened the brief is still there');
    });

    semanticTest('a paper\'s own instructions take the place of the five lines', (tester) async {
      repo.sittingValue = sampleSitting(paper: samplePaper(instructions: 'Bring a calculator. No notes.'));
      await openBrief(tester, briefFor());
      expect(find.text('Bring a calculator. No notes.'), findsOneWidget);
      expect(find.text('You can move freely between questions and mark any for review.'), findsNothing);
    });

    semanticTest('the first screen of a phone holds the name, the lines, the whole table and the buttons', (
      tester,
    ) async {
      repo.sittingValue = sampleSitting(paper: mockSet(), questions: 1);
      await openBrief(tester, briefFor(slug: 'bemp-1'), size: const Size(390, 844));
      // Everything above the bar is on the first screen with no scrolling, the last row of the table included.
      final bar = tester.getTopLeft(find.text('Take test')).dy;
      expect(tester.getBottomLeft(find.text('Certificate')).dy, lessThan(bar));
      expect(tester.getTopLeft(find.text('ASHRAE BEMP Set 1')).dy, lessThan(ExamTitleBar.height + 24));
      expect(layoutProblems().where((p) => p.startsWith('clipped')), isEmpty);
    });

    semanticTest('a title bar stays pinned at the top while the sections scroll under it', (tester) async {
      repo.attemptsValue = [for (var i = 1; i <= 4; i++) sampleAttempt(id: 'a$i', attempt: i)];
      await openBrief(tester, briefFor(slug: 'bemp-1'), size: const Size(390, 700));
      final bar = find.byType(ExamTitleBar);
      expect(bar, findsOneWidget);
      expect(find.descendant(of: bar, matching: find.text('Assess Your Knowledge')), findsOneWidget);
      final top = tester.getTopLeft(bar).dy;
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(bar).dy, top, reason: 'pinned: the owner saw the page scroll up to the status bar');
      expect(
        tester.getTopLeft(find.text('My attempts')).dy,
        greaterThanOrEqualTo(top + ExamTitleBar.height),
        reason: 'the sections scroll under the bar, never over it',
      );
    });

    semanticTest("a sitting left open for days reads as the paper's time, not the days", (tester) async {
      // Owner, 3 Nov 2026: "10088m 38s" on a 50-minute paper — the API timed a week-old sitting to its submit.
      repo.attemptsValue = [
        sampleAttempt(id: 'a1', timeTakenMs: const Duration(minutes: 10088, seconds: 38).inMilliseconds),
      ];
      await openBrief(tester, briefFor());
      expect(find.textContaining('10088m'), findsNothing);
      expect(find.text('30m 00s'), findsOneWidget, reason: "the sample paper's 30 minutes");
    });

    semanticTest('the sections are parted by hairlines, not boxed in outlined cards', (tester) async {
      repo.attemptsValue = [sampleAttempt(id: 'a1')];
      await openBrief(tester, briefFor());
      final outlined = tester
          .widgetList<Container>(find.descendant(of: find.byType(ListView).first, matching: find.byType(Container)))
          // An outline has sides; a hairline (a Divider) is a bottom edge alone.
          .where((c) {
            final border = c.decoration is BoxDecoration ? (c.decoration! as BoxDecoration).border : null;
            return border is Border && border.left != BorderSide.none;
          });
      expect(outlined, isEmpty, reason: "the owner's rule of 3 Nov 2026: no borders, a thin line is enough");
      expect(find.byType(Divider), findsWidgets);
    });

    group('My attempts', () {
      setUp(() {
        repo.attemptsValue = [
          sampleAttempt(id: 'a2', attempt: 2, percentage: 60),
          sampleAttempt(id: 'a1', percentage: 90),
        ];
      });

      semanticTest('lists the sittings as the design does: number, when, a document, Score, Result and Duration', (
        tester,
      ) async {
        await openBrief(tester, briefFor());
        expect(find.text('My attempts'), findsOneWidget);
        expect(find.text('2 attempts recorded'), findsOneWidget);
        expect(find.text('#2'), findsOneWidget);
        expect(find.text('#1'), findsOneWidget);
        expect(find.text('20 Oct 2026, 09:12'), findsNWidgets(2));
        expect(find.text('Score'), findsNWidgets(2));
        expect(find.text('Result'), findsNWidgets(2));
        expect(find.text('Duration'), findsNWidgets(3), reason: 'two columns and the table row');
        expect(find.text('12m 04s'), findsNWidgets(2));
        expect(find.textContaining('10088m'), findsNothing);
        expect(find.text('Attempts used'), findsOneWidget);
        expect(find.text('2'), findsOneWidget, reason: 'attempts used');
        // The list is as the API gave it, newest first.
        expect(
          tester.getTopLeft(find.bySemanticsLabel('Open attempt 2')).dy,
          lessThan(tester.getTopLeft(find.bySemanticsLabel('Open attempt 1')).dy),
        );
        Color colourOf(String text) => tester.widget<Text>(find.text(text)).style!.color!;
        expect(colourOf('60%'), const Color(0xFFBA1A1A), reason: 'below the pass mark');
        expect(colourOf('90%'), const Color(0xFF006C49), reason: 'passed');
      });

      semanticTest('one sitting reads "1 attempt recorded"', (tester) async {
        repo.attemptsValue = [sampleAttempt()];
        await openBrief(tester, briefFor());
        expect(find.text('1 attempt recorded'), findsOneWidget);
      });

      semanticTest('the document opens that sitting\'s result, and back returns to the brief', (tester) async {
        repo.results['a2'] = AttemptResult(
          attempt: sampleAttempt(id: 'a2', attempt: 2, percentage: 60),
          review: sampleReview(5, right: 3),
        );
        await openBrief(tester, briefFor());
        await tester.tap(find.bySemanticsLabel('Open attempt 2'));
        await settle(tester);
        expect(repo.calls, contains('attempt a2'));
        expect(find.text('Test Results'), findsOneWidget);
        expect(find.bySemanticsLabel('Attempt Count 2'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Back').first);
        await settle(tester);
        expect(find.text('Test Results'), findsNothing);
        expect(find.text('Take test'), findsOneWidget, reason: 'back on the brief');
      });

      semanticTest('Retake test on an old result closes it, and the brief starts the paper once', (tester) async {
        repo.results['a1'] = AttemptResult(attempt: sampleAttempt(percentage: 90), review: sampleReview(5, right: 5));
        final results = await openBrief(tester, briefFor());
        await tester.tap(find.bySemanticsLabel('Open attempt 1'));
        await settle(tester);
        await tester.tap(find.text('Retake test'));
        await settle(tester);
        expect(results, hasLength(1));
        expect(results.single!.sitting.questions, hasLength(5));
        expect(find.byType(ResultScreen), findsNothing);
        expect(find.text('Take test'), findsNothing, reason: 'the brief went with it');
      });

      semanticTest('a result that will not load says why', (tester) async {
        await openBrief(tester, briefFor());
        await tester.tap(find.bySemanticsLabel('Open attempt 1'));
        await settle(tester);
        expect(find.text("Couldn't open this result"), findsOneWidget);
      });
    });

    semanticTest('a held certificate shows in the table, and its notice opens it', (tester) async {
      repo.attemptsValue = [sampleAttempt(percentage: 90)];
      repo.certificatesValue = [sampleCertificate()];
      await openBrief(tester, briefFor());
      expect(find.text('Issued'), findsOneWidget);
      expect(find.text('You already hold this certificate: ICR-CP-2026-AB12CD34.'), findsOneWidget);
      expect(find.text('Take test'), findsOneWidget, reason: 'it is Take test, not Retake: the sittings are listed');

      await tester.ensureVisible(find.text('View certificate'));
      await tester.tap(find.text('View certificate'));
      await settle(tester);
      expect(find.text('Certificate of Knowledge Assessment'), findsOneWidget);
      expect(find.text('ICR-CP-2026-AB12CD34'), findsWidgets);
    });

    semanticTest('all the attempts used: a warning, and Take test is off', (tester) async {
      repo.sittingValue = sampleSitting(paper: samplePaper(attemptLimit: 1));
      repo.attemptsValue = [sampleAttempt()];
      final results = await openBrief(tester, briefFor());
      expect(find.text('You have used all 1 attempts for this paper.'), findsOneWidget);
      await tester.tap(find.text('Take test'));
      await settle(tester);
      expect(results, isEmpty, reason: 'the button does nothing');
    });

    semanticTest('a paper with no questions says so and cannot be started', (tester) async {
      repo.sittingValue = PaperSitting(paper: samplePaper(), questions: const []);
      final results = await openBrief(tester, briefFor());
      expect(find.text('This paper has no questions yet. Check back soon.'), findsOneWidget);
      await tester.tap(find.text('Take test'));
      await settle(tester);
      expect(results, isEmpty);
    });

    semanticTest('an unfinished sitting is resumed with its time left, answers and all', (tester) async {
      final first = controllerFor(repo.sittingValue!)..start();
      first.select(2);
      await first.flushed();
      first.dispose();
      clock.advance(const Duration(minutes: 12));

      final results = await openBrief(tester, briefFor());
      expect(find.textContaining('You have a sitting in progress, with 18:00 left'), findsOneWidget);
      expect(find.text('Resume · 18:00 left'), findsOneWidget);
      await tester.tap(find.text('Resume · 18:00 left'));
      await settle(tester);
      expect(results.single!.resume, isNotNull);
      expect(results.single!.resume!.answers['q1'], [2]);
    });

    semanticTest('discarding an unfinished sitting starts the paper fresh, after a confirmation', (tester) async {
      final first = controllerFor(repo.sittingValue!)..start();
      first.select(2);
      await first.flushed();
      first.dispose();
      final results = await openBrief(tester, briefFor());

      await tester.ensureVisible(find.text('Discard it and start over'));
      await tester.tap(find.text('Discard it and start over'));
      await settle(tester);
      expect(find.text('Start over?'), findsOneWidget);
      await tester.tap(find.text('Keep it'));
      await settle(tester);
      expect(find.text('Resume · 30:00 left'), findsOneWidget, reason: 'Keep it changes nothing');

      await tester.tap(find.text('Discard it and start over'));
      await settle(tester);
      await tester.tap(find.text('Discard'));
      await settle(tester);
      expect(find.text('Take test'), findsOneWidget);
      expect(await store.load('u1', 'cp-foundation'), isNull);
      await tester.tap(find.text('Take test'));
      await settle(tester);
      expect(results.single!.resume, isNull);
    });

    semanticTest('a sitting whose time ran out while away offers to submit its answers', (tester) async {
      final first = controllerFor(repo.sittingValue!)..start();
      first.select(1);
      await first.flushed();
      first.dispose();
      clock.advance(const Duration(minutes: 50));
      final results = await openBrief(tester, briefFor());
      expect(find.textContaining('Time ran out on your last sitting'), findsOneWidget);
      await tester.tap(find.text('Submit my saved answers'));
      await settle(tester);
      expect(results.single!.resume!.answers['q1'], [1]);
    });

    semanticTest('a paper that will not load says why, and Try again loads it', (tester) async {
      repo.sittingError = ApiError("Can't reach ICR right now. Check your connection and try again.");
      await openBrief(tester, briefFor());
      expect(find.text("Couldn't open this paper"), findsOneWidget);
      expect(find.textContaining("Can't reach ICR"), findsOneWidget);
      expect(find.text('Back'), findsOneWidget, reason: 'Back is there while it does not load');
      expect(find.text('Take test'), findsNothing);
      repo.sittingError = null;
      await tapText(tester, 'Try again');
      expect(find.text('Take test'), findsOneWidget);
    });

    semanticTest('Back closes the page and hands back nothing', (tester) async {
      final results = await openBrief(tester, briefFor());
      await tester.tap(find.text('Back'));
      await settle(tester);
      expect(results, [null]);
      expect(find.text('Take test'), findsNothing);
    });

    group('a paper the member has not opened', () {
      setUp(() {
        repo.lock = const PaperLock(
          message:
              'Assess your knowledge courses are not included in your plan. Redeem ICR credits for this level (you have 180), or buy it.',
          reason: 'COURSES',
          credits: 180,
        );
        repo.infoValue = samplePaper(priceAmount: 49900);
        repo.quoteValue = PaperQuote.fromJson(_quote);
      });

      semanticTest('shows the API\'s sentence and the ways in, and the way in is where Take test would be', (
        tester,
      ) async {
        await openBrief(tester, briefFor());
        expect(find.text('This assessment level is locked'), findsOneWidget);
        expect(find.textContaining('are not included in your plan'), findsWidgets);
        expect(find.text('Redeem ICR credits'), findsOneWidget);
        expect(find.textContaining('It takes 4 ICR credits'), findsOneWidget);
        expect(find.textContaining('You have 180'), findsOneWidget);
        expect(find.text('Buy this level'), findsOneWidget);
        expect(find.text('₹374.25'), findsOneWidget);
        expect(find.text('₹499'), findsOneWidget);
        expect(find.text('25% off'), findsOneWidget);
        expect(find.text('Open with my plan'), findsNothing, reason: 'the plan has no place left');
        expect(find.text('Take test'), findsNothing);
        expect(find.text('Back'), findsOneWidget);
        // The credits are the first way open, so they are the filled button; paying has its own, in the card.
        expect(find.text('Redeem 4 credits'), findsOneWidget);
        expect(find.text('Pay now'), findsOneWidget);
        final bar = tester.getTopLeft(find.text('Redeem 4 credits')).dy;
        expect(tester.getTopLeft(find.text('Pay now')).dy, lessThan(bar));
        // The page under it is still the design's: the lines and the table.
        expect(find.text('Before you start'), findsOneWidget);
        expect(find.text('Assessment details'), findsOneWidget);
      });

      semanticTest('Redeem asks first; Cancel changes nothing; Redeem spends the credits and opens the paper', (
        tester,
      ) async {
        await openBrief(tester, briefFor());
        await tester.tap(find.text('Redeem 4 credits'));
        await settle(tester);
        expect(find.text('Redeem 4 credits?'), findsOneWidget);
        expect(find.textContaining('You will have 176 ICR credits left.'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await settle(tester);
        expect(repo.calls.where((c) => c.startsWith('redeem')), isEmpty);

        await tester.tap(find.text('Redeem 4 credits'));
        await settle(tester);
        await tester.tap(find.text('Redeem'));
        await settle(tester);
        expect(repo.calls, contains('redeem cp-foundation'));
        expect(find.text('Take test'), findsOneWidget, reason: 'the paper is open now');
        expect(find.text('This assessment level is locked'), findsNothing);
      });

      semanticTest('too few credits: Redeem is off and says how many are missing; paying is the way in', (
        tester,
      ) async {
        repo.lock = const PaperLock(message: 'Locked.', reason: 'COURSES', credits: 1);
        await openBrief(tester, briefFor());
        expect(find.textContaining('You need 3 more.'), findsOneWidget);
        await tester.ensureVisible(find.text('Redeem 4 credits'));
        await tester.tap(find.text('Redeem 4 credits'), warnIfMissed: false);
        await settle(tester);
        expect(find.text('Redeem 4 credits?'), findsNothing);
        expect(find.text('Pay now'), findsOneWidget, reason: 'the first way that is open');
        final bar = tester.getTopLeft(find.text('Pay now')).dy;
        expect(tester.getTopLeft(find.text('Redeem 4 credits')).dy, lessThan(bar));
      });

      semanticTest('a refused redemption shows the API\'s sentence and leaves the paper locked', (tester) async {
        repo.redeemError = ApiError(
          'This level takes 4 ICR credits, and you have 2.',
          statusCode: 403,
          code: 'NO_CREDIT_LEFT',
        );
        await openBrief(tester, briefFor());
        await tester.tap(find.text('Redeem 4 credits'));
        await settle(tester);
        await tester.tap(find.text('Redeem'));
        await settle(tester);
        expect(find.text('This level takes 4 ICR credits, and you have 2.'), findsOneWidget);
        expect(find.text('This assessment level is locked'), findsOneWidget);
      });

      semanticTest("Pay now runs the paper's checkout in the app, then the brief reads again, open", (tester) async {
        await openBrief(tester, briefFor());
        await tester.ensureVisible(find.text('Pay now'));
        await tester.tap(find.text('Pay now'));
        await settle(tester);
        expect(repo.calls, contains('checkout cp-foundation'));
        expect(opened, isEmpty, reason: 'nothing leaves the app');
        expect(find.text('Take test'), findsOneWidget, reason: 'paid at once (test mode): the paper is open now');
        expect(find.text('Payment received. Capital Planning – Foundation is open.'), findsOneWidget);
      });

      semanticTest('payment that is not available cannot be started', (tester) async {
        repo.quoteValue = PaperQuote.fromJson({..._quote, 'payable': false});
        await openBrief(tester, briefFor());
        await tester.ensureVisible(find.text('Payment is not available'));
        await tester.tap(find.text('Payment is not available'), warnIfMissed: false);
        await settle(tester);
        expect(opened, isEmpty);
      });

      semanticTest('with no way in, Take test stays and is off, under the sentence that says why', (tester) async {
        repo.quoteValue = null;
        await openBrief(tester, briefFor());
        expect(find.textContaining('are not included in your plan'), findsWidgets);
        expect(find.text('Take test'), findsOneWidget);
        expect(find.text('Redeem ICR credits'), findsNothing);
        await tester.tap(find.text('Take test'));
        await settle(tester);
        expect(find.text('This assessment level is locked'), findsOneWidget, reason: 'nothing happened');
      });

      semanticTest('the plan\'s upgrade is a link to its page on the website', (tester) async {
        repo.lock = const PaperLock(
          message: 'Locked.',
          reason: 'COURSES',
          credits: 180,
          plan: 'Pro Max',
          pricingSlug: 'professional',
        );
        await openBrief(tester, briefFor());
        await tester.ensureVisible(find.text('See the Pro Max plan'));
        await tester.tap(find.text('See the Pro Max plan'));
        await settle(tester);
        expect(opened.single.toString(), 'https://icr.test/pricing/professional');
      });

      semanticTest('Back closes the page', (tester) async {
        final results = await openBrief(tester, briefFor());
        await tester.tap(find.text('Back'));
        await settle(tester);
        expect(results, [null]);
        expect(find.text('This assessment level is locked'), findsNothing);
      });

      semanticTest('a place left on the plan opens the whole course, after a confirmation', (tester) async {
        repo.lock = const PaperLock(
          message:
              'Your plan includes 2 courses, and 1 is still free. Open this course with your plan to start its levels.',
          reason: 'PICK',
          opensTarget: 'COURSE',
          opensId: 'course-cp',
          placesLeft: 1,
          credits: 180,
        );
        await openBrief(tester, briefFor());
        expect(find.text('Your plan includes a course'), findsOneWidget);
        // The plan is the way that costs nothing, so it is the button in Take test's place; the credits keep theirs.
        expect(find.text('Open with my plan'), findsOneWidget);
        expect(find.text('Redeem 4 credits'), findsOneWidget);
        await tester.tap(find.text('Open with my plan'));
        await settle(tester);
        expect(find.text('Open it with your plan?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await settle(tester);
        expect(repo.calls.where((c) => c.startsWith('open ')), isEmpty);

        await tester.tap(find.text('Open with my plan'));
        await settle(tester);
        await tester.tap(find.text('Open it'));
        await settle(tester);
        expect(repo.calls, contains('open COURSE course-cp'));
        expect(find.text('Take test'), findsOneWidget);
      });

      semanticTest('a locked mock set says set, not level', (tester) async {
        repo.infoValue = samplePaper(slug: 'bemp-1', title: 'Set 1', kind: PaperKind.mock, certificate: false);
        await openBrief(tester, briefFor(slug: 'bemp-1'));
        expect(find.text('This mock set is locked'), findsOneWidget);
        expect(find.text('Buy this set'), findsOneWidget);
        expect(find.text('Mock Exam details'), findsOneWidget);
      });
    });
  });

  // --- the exam window ------------------------------------------------------------------------------------

  group('the exam window', () {
    semanticTest('shows what it is, the clock, the number strip, the question, and its options', (tester) async {
      await pumpExam(tester, sitting: sampleSitting(paper: samplePaper(minutes: 30), questions: 5));
      expect(find.text('Capital Planning Foundation'), findsOneWidget, reason: "the title is the paper's name and set");
      expect(find.text('Time Left: 30:00'), findsOneWidget);
      expect(find.text('Question 1'), findsOneWidget);
      expect(find.text('Question number 1: what is right?'), findsOneWidget);
      expect(find.text('Answer'), findsOneWidget);
      expect(find.text('Option A1'), findsOneWidget);
      expect(find.text('Option B1'), findsOneWidget);
      // Five questions: all five numbers, the first one open, and no ellipsis.
      expect(stripLabel(tester, 1), 'Go to question 1, not answered, current');
      expect(stripLabel(tester, 5), 'Go to question 5, not answered');
      expect(find.text('…'), findsNothing);
      expect(find.bySemanticsLabel('Question palette'), findsOneWidget);
      for (final b in ['Finish', 'Review', 'Next']) {
        expect(find.text(b), findsOneWidget);
      }
      for (final gone in ['Skip', 'Submit & Next', 'Submit']) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
    });

    semanticTest('a mock set is titled by its subject and set; its questions carry no difficulty and no level', (
      tester,
    ) async {
      final mock = samplePaper(slug: 'bemp-1', title: 'Set 1', kind: PaperKind.mock, certificate: false);
      await pumpExam(
        tester,
        sitting: sampleSitting(paper: mock, difficulty: 'EASY'),
      );
      expect(find.text('ASHRAE BEMP Set 1'), findsOneWidget);
      expect(find.text('Mock Test'), findsNothing);
      // Owner, 3 Nov 2026: "that EASY tag is not required" — a mock set has no level to show in its place.
      expect(find.text('EASY'), findsNothing);
      expect(find.byKey(const ValueKey('question-level')), findsNothing);
      await tapText(tester, 'Next');
      expect(find.text('EASY'), findsNothing);
    });

    semanticTest("an assessment's question shows the paper's level where the difficulty was", (tester) async {
      await pumpExam(tester, sitting: sampleSitting(difficulty: 'HARD'));
      final chip = find.byKey(const ValueKey('question-level'));
      expect(chip, findsOneWidget);
      expect(find.descendant(of: chip, matching: find.text('Foundation')), findsOneWidget);
      for (final d in ['EASY', 'MEDIUM', 'HARD']) {
        expect(find.text(d), findsNothing);
      }
      await tapText(tester, 'Next');
      expect(chip, findsOneWidget, reason: 'every question of the paper is at its level');
    });

    semanticTest('the question and its options sit between hairlines, not in outlined boxes', (tester) async {
      await pumpExam(tester);
      final tiles = find.byType(OptionTile);
      expect(tiles, findsNWidgets(4));
      for (final tile in tiles.evaluate()) {
        expect(tester.getSize(find.byWidget(tile.widget)).height, greaterThanOrEqualTo(48), reason: 'a finger');
      }
      final shaped = tester
          .widgetList<Material>(find.descendant(of: tiles, matching: find.byType(Material)))
          .where((m) => m.shape is OutlinedBorder && (m.shape! as OutlinedBorder).side != BorderSide.none);
      expect(shaped, isEmpty, reason: "the owner's rule of 3 Nov 2026: no borders, a thin line is enough");
      expect(find.byType(Divider), findsWidgets);
    });

    semanticTest('the strip shows the numbers around the open question, then an ellipsis and the last one', (
      tester,
    ) async {
      final c = await pumpExam(tester, sitting: sampleSitting(questions: 30, difficulty: 'HARD'));
      expect(find.text('HARD'), findsNothing, reason: 'the level stands where the difficulty was');
      // First question: 1 2 3 4 ... 30.
      for (final n in [1, 2, 3, 4, 30]) {
        expect(find.byKey(ValueKey('strip-$n')), findsOneWidget, reason: 'number $n');
      }
      expect(find.byKey(const ValueKey('strip-5')), findsNothing);
      expect(find.text('…'), findsOneWidget);

      c.goTo(6);
      await tester.pump();
      // Question 7: 5 6 7 8 ... 30, as the design draws it.
      for (final n in [5, 6, 7, 8, 30]) {
        expect(find.byKey(ValueKey('strip-$n')), findsOneWidget, reason: 'number $n');
      }
      expect(find.byKey(const ValueKey('strip-4')), findsNothing);
      expect(find.byKey(const ValueKey('strip-9')), findsNothing);
      expect(stripLabel(tester, 7), 'Go to question 7, not answered, current');
      expect(find.text('Question 7'), findsOneWidget);

      await goToQuestion(tester, 8);
      expect(c.current, 7);
      c.goTo(28);
      await tester.pump();
      // Next to last: 27 28 29 30 with nothing between.
      for (final n in [27, 28, 29, 30]) {
        expect(find.byKey(ValueKey('strip-$n')), findsOneWidget, reason: 'number $n');
      }
      expect(find.text('…'), findsNothing);
      c.goTo(29);
      await tester.pump();
      expect(find.byKey(const ValueKey('strip-27')), findsOneWidget);
      expect(find.byKey(const ValueKey('strip-30')), findsOneWidget);
    });

    semanticTest('the strip marks answered, open and flagged questions', (tester) async {
      final c = await pumpExam(tester, sitting: sampleSitting(questions: 6));
      c.select(1);
      c.goTo(1);
      c.toggleFlag();
      c.goTo(2);
      await tester.pump();
      expect(stripLabel(tester, 1), 'Go to question 1, answered');
      expect(stripLabel(tester, 2), 'Go to question 2, not answered, flagged');
      expect(stripLabel(tester, 3), 'Go to question 3, not answered, current');
    });

    semanticTest('tapping an option selects it, and tapping another moves the choice', (tester) async {
      final c = await pumpExam(tester);
      await tester.tap(find.text('Option B1'));
      await tester.pump();
      expect(c.picked('q1'), [1]);
      expect(stripLabel(tester, 1), 'Go to question 1, answered, current');
      expect(optionChecked(tester, 'Option B1'), isTrue);
      expect(optionChecked(tester, 'Option C1'), isFalse);
      await tester.tap(find.text('Option C1'));
      await tester.pump();
      expect(c.picked('q1'), [2]);
      expect(optionChecked(tester, 'Option B1'), isFalse);
      expect(optionChecked(tester, 'Option C1'), isTrue);
      expect(stripLabel(tester, 1), 'Go to question 1, answered, current');
    });

    semanticTest('a multiple-choice question says so and ticks any number of options', (tester) async {
      final c = await pumpExam(tester, sitting: sampleSitting(multipleAt: 0));
      expect(find.text('Select all that apply.'), findsOneWidget);
      await tester.tap(find.text('Option A1'));
      await tester.tap(find.text('Option C1'));
      await tester.pump();
      expect(c.picked('q1'), [0, 2]);
      expect(optionChecked(tester, 'Option A1'), isTrue);
      expect(optionChecked(tester, 'Option C1'), isTrue);
      await tester.tap(find.text('Option A1'));
      await tester.pump();
      expect(c.picked('q1'), [2]);
      expect(optionChecked(tester, 'Option A1'), isFalse);
    });

    semanticTest('Next moves on, a number goes back, and on the last question Next opens the overview', (tester) async {
      final c = await pumpExam(tester, sitting: sampleSitting(questions: 3));
      await tapText(tester, 'Next');
      expect(find.text('Question 2'), findsOneWidget);
      expect(find.text('Question number 2: what is right?'), findsOneWidget);
      await goToQuestion(tester, 1);
      expect(find.text('Question 1'), findsOneWidget, reason: 'a number in the strip goes back');
      await tapText(tester, 'Next');
      expect(find.text('Question 2'), findsOneWidget);
      await tapText(tester, 'Next');
      expect(find.text('Question 3'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget, reason: 'still Next on the last question');
      expect(c.current, 2);
      expect(find.text('Assessment overview'), findsNothing);
      await tapText(tester, 'Next');
      expect(find.text('Assessment overview'), findsOneWidget);
      expect(c.current, 2, reason: 'it did not run past the end');
      expect(repo.submitted, isEmpty, reason: 'the overview asks before anything is sent');
    });

    semanticTest('Next keeps the answer given and leaves the next question as it was', (tester) async {
      final c = await pumpExam(tester);
      await tester.tap(find.text('Option C1'));
      await tapText(tester, 'Next');
      await tapText(tester, 'Next');
      expect(c.current, 2);
      expect(c.picked('q1'), [2]);
      expect(c.picked('q2'), isEmpty);
      expect(stripLabel(tester, 1), 'Go to question 1, answered');
      expect(stripLabel(tester, 2), 'Go to question 2, not answered');
    });

    semanticTest('the bar is Finish at the left, Review and Next at the right, as the design has them', (tester) async {
      await pumpExam(tester);
      final finish = tester.getRect(find.text('Finish'));
      final review = tester.getRect(find.text('Review'));
      final next = tester.getRect(find.text('Next'));
      expect(finish.left, lessThan(60));
      expect(review.left, greaterThan(200));
      expect(next.left, greaterThan(review.right));
      expect(next.right, greaterThan(350));
      expect(find.byType(ExamScreen), findsOneWidget);
      // Finish is red and Next is the app's blue.
      Color fillOf(String label) {
        final material = tester.widget<Material>(
          find.ancestor(of: find.text(label), matching: find.byType(Material)).first,
        );
        return material.color!;
      }

      expect(fillOf('Finish'), const Color(0xFFDC2626));
      expect(fillOf('Next'), const Color(0xFF004B83));
    });

    semanticTest('an answer is still there after going away and coming back', (tester) async {
      await pumpExam(tester);
      await tester.tap(find.text('Option D1'));
      await tester.pump();
      await tapText(tester, 'Next');
      await goToQuestion(tester, 1);
      expect(optionChecked(tester, 'Option D1'), isTrue);
    });

    semanticTest('Review flags the question, the strip and the button show it, and a second tap takes it off', (
      tester,
    ) async {
      final c = await pumpExam(tester);
      expect(find.bySemanticsLabel('Flag for review'), findsOneWidget);
      await tapText(tester, 'Review');
      expect(c.isFlagged(0), isTrue);
      expect(stripLabel(tester, 1), 'Go to question 1, not answered, flagged, current');
      expect(find.bySemanticsLabel('Unflag'), findsOneWidget);
      expect(find.bySemanticsLabel('Flag for review'), findsNothing);
      await tapText(tester, 'Review');
      expect(c.isFlagged(0), isFalse);
      expect(stripLabel(tester, 1), 'Go to question 1, not answered, current');
      expect(find.bySemanticsLabel('Flag for review'), findsOneWidget);
    });

    semanticTest('Clear is off until there is an answer, then takes it away', (tester) async {
      final c = await pumpExam(tester);
      await tester.tap(find.text('Clear'), warnIfMissed: false);
      await tester.pump();
      expect(c.picked('q1'), isEmpty);
      await tester.tap(find.text('Option A1'));
      await tester.pump();
      await tapText(tester, 'Clear');
      expect(c.picked('q1'), isEmpty);
      expect(optionChecked(tester, 'Option A1'), isFalse);
      expect(stripLabel(tester, 1), 'Go to question 1, not answered, current');
    });

    semanticTest('the palette shows every question by state, and a tap goes there', (tester) async {
      final c = await pumpExam(tester, sitting: sampleSitting(questions: 6));
      await tester.tap(find.text('Option B1'));
      await tapText(tester, 'Next');
      await tapText(tester, 'Review');
      await tapText(tester, 'Next');
      await tester.tap(find.text('Option A3'));
      await tapText(tester, 'Review');

      await tester.tap(find.bySemanticsLabel('Question palette'));
      await settle(tester);
      expect(find.text('Question palette'), findsOneWidget);
      expect(find.bySemanticsLabel('Question 1, answered'), findsOneWidget);
      expect(find.bySemanticsLabel('Question 2, flagged for review'), findsOneWidget);
      expect(find.bySemanticsLabel('Question 3, answered and flagged, current'), findsOneWidget);
      expect(find.bySemanticsLabel('Question 4, not visited'), findsOneWidget);
      // The legend counts the same.
      for (final row in ['Answered', 'Not answered', 'Flagged for review', 'Answered and flagged', 'Not visited']) {
        expect(find.text(row), findsOneWidget);
      }
      expect(c.counts.byMark[QuestionMark.notVisited], 3);

      await tester.tap(paletteNumber(5));
      await settle(tester);
      expect(find.text('Question palette'), findsNothing, reason: 'the sheet closes on a jump');
      expect(find.text('Question 5'), findsOneWidget);
      expect(find.text('Question number 5: what is right?'), findsOneWidget);
    });

    semanticTest('Review & submit in the palette opens the overview', (tester) async {
      await pumpExam(tester);
      await tester.tap(find.bySemanticsLabel('Question palette'));
      await settle(tester);
      await tapText(tester, 'Review & submit');
      expect(find.text('Assessment overview'), findsOneWidget);
      expect(find.text('Question palette'), findsNothing);
    });

    semanticTest('the overview counts answered, skipped and flagged, and a number goes back to that question', (
      tester,
    ) async {
      await pumpExam(tester, sitting: sampleSitting(questions: 6));
      await tester.tap(find.text('Option B1'));
      await tapText(tester, 'Next');
      await tester.tap(find.text('Option B2'));
      await tapText(tester, 'Review');

      await tapText(tester, 'Finish');
      expect(find.text('Assessment overview'), findsOneWidget);
      expect(find.text('CAPITAL PLANNING – FOUNDATION'), findsOneWidget);
      expect(find.text('2 answered, 4 skipped, 1 flagged'), findsOneWidget);
      expect(find.text('4 questions have no answer. Tap a number to go back to one.'), findsOneWidget);
      expect(find.text('1 question is still flagged for review.'), findsOneWidget);
      expect(find.textContaining('left'), findsWidgets);

      await tester.ensureVisible(find.bySemanticsLabel('Question 5, not answered. Go to it.'));
      await tester.tap(find.bySemanticsLabel('Question 5, not answered. Go to it.'));
      await settle(tester);
      expect(find.text('Assessment overview'), findsNothing);
      expect(find.text('Question 5'), findsOneWidget);
    });

    semanticTest('Back to test closes the overview and sends nothing', (tester) async {
      await pumpExam(tester);
      await tapText(tester, 'Finish');
      await tester.ensureVisible(find.text('Back to test'));
      await tapText(tester, 'Back to test');
      expect(find.text('Assessment overview'), findsNothing);
      expect(find.text('Question 1'), findsOneWidget);
      expect(repo.submitted, isEmpty);
    });

    semanticTest('Submit test sends the answers and shows the result', (tester) async {
      repo.defaultResult = sampleResult(percentage: 80);
      final c = await pumpExam(tester, sitting: sampleSitting(questions: 5));
      await tester.tap(find.text('Option B1'));
      await tester.pump();
      await tapText(tester, 'Finish');
      await tester.ensureVisible(find.text('Submit test'));
      await tester.tap(find.text('Submit test'));
      await settle(tester);

      expect(repo.submitted, hasLength(1));
      expect(repo.submitted.single, hasLength(5), reason: 'every question goes, answered or not');
      expect(repo.submitted.single.first.selected, [1]);
      expect(c.phase, ExamPhase.done);
      expect(find.text('Test Results'), findsOneWidget);
      expect(find.text('Well done, Bharat'), findsOneWidget);
      expect(find.text('ExamScreen'), findsNothing);
      expect(find.byType(ExamScreen), findsNothing, reason: 'the exam is replaced, so Back cannot return to it');
      expect(await store.load('u1', 'cp-foundation'), isNull);
    });

    semanticTest('two quick taps on Submit test send one sitting and leave the exam to the result', (tester) async {
      await pumpExam(tester);
      await tester.tap(find.text('Option B1'));
      await tester.pump();
      await tapText(tester, 'Finish');
      await tester.ensureVisible(find.text('Submit test'));
      await tester.tap(find.text('Submit test'));
      await tester.tap(find.text('Submit test'));
      await settle(tester);
      expect(repo.submitted, hasLength(1));
      expect(find.text('Test Results'), findsOneWidget);
    });

    semanticTest('two quick taps on a palette number go to that question once and leave the exam open', (tester) async {
      final c = await pumpExam(tester, sitting: sampleSitting(questions: 6));
      await tester.tap(find.bySemanticsLabel('Question palette'));
      await settle(tester);
      await tester.tap(paletteNumber(4));
      await tester.tap(paletteNumber(4));
      await settle(tester);
      expect(find.byType(ExamScreen), findsOneWidget);
      expect(c.current, 3);
    });

    semanticTest('the clock turns red under five minutes and shows the time left', (tester) async {
      final c = await pumpExam(tester, sitting: sampleSitting(paper: samplePaper(minutes: 6)));
      Finder pill() => find.text('Time Left: ${clockText(c)}');
      Color clockColor() => tester.widget<Text>(pill()).style!.color!;
      Color pillFill() =>
          (tester.widget<Container>(find.ancestor(of: pill(), matching: find.byType(Container)).first).decoration
                  as BoxDecoration)
              .color!;
      // Red on a red tint while there is time; solid red with white words in the last five minutes.
      expect(clockColor(), const Color(0xFFBA1A1A));
      expect(pillFill(), const Color(0xFFFFECEB));
      clock.advance(const Duration(seconds: 61));
      c.tick();
      await tester.pump();
      expect(find.text('Time Left: 04:59'), findsOneWidget);
      expect(clockColor(), Colors.white);
      expect(pillFill(), const Color(0xFFBA1A1A));
    });

    semanticTest('at zero the answers are sent for the candidate and the result shows', (tester) async {
      repo.defaultResult = sampleResult(percentage: 40);
      final c = await pumpExam(tester, sitting: sampleSitting(paper: samplePaper(minutes: 1)));
      await tester.tap(find.text('Option C1'));
      await tester.pump();
      clock.advance(const Duration(seconds: 59));
      await tester.pump(const Duration(seconds: 59));
      expect(find.text('Time Left: 00:01'), findsOneWidget);
      expect(repo.submitted, isEmpty);

      final gate = Completer<AttemptResult>();
      repo.onSubmit = (_, _, _) => gate.future;
      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text("Time's up"), findsOneWidget);
      expect(find.text('Submitting what you have answered…'), findsOneWidget);
      expect(repo.submitted.single.first.selected, [2]);
      gate.complete(sampleResult(percentage: 40));
      await settle(tester);
      expect(c.autoSubmitted, isTrue);
      expect(find.text('Test Results'), findsOneWidget);
      expect(find.text('Not quite there yet, Bharat'), findsOneWidget);
    });

    semanticTest('the clock running out under an open overview closes it and sends', (tester) async {
      await pumpExam(tester, sitting: sampleSitting(paper: samplePaper(minutes: 1)));
      await tapText(tester, 'Finish');
      expect(find.text('Assessment overview'), findsOneWidget);
      clock.advance(const Duration(minutes: 2));
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      expect(find.text('Assessment overview'), findsNothing);
      expect(repo.submitted, hasLength(1));
      expect(find.text('Test Results'), findsOneWidget);
    });

    semanticTest('a send that fails keeps the answers and offers to try again, which sends them', (tester) async {
      var tries = 0;
      repo.onSubmit = (_, _, _) async {
        tries++;
        if (tries == 1) throw ApiError("Can't reach ICR right now. Check your connection and try again.");
        return sampleResult();
      };
      final c = await pumpExam(tester);
      await tester.tap(find.text('Option B1'));
      await tester.pump();
      await tapText(tester, 'Finish');
      await tester.ensureVisible(find.text('Submit test'));
      await tester.tap(find.text('Submit test'));
      await settle(tester);

      expect(find.text("Your answers didn't go"), findsOneWidget);
      expect(find.textContaining("Can't reach ICR"), findsOneWidget);
      expect(find.text('They are safe on this phone. Try again when you are ready.'), findsOneWidget);
      expect(c.picked('q1'), [1]);
      expect(await store.load('u1', 'cp-foundation'), isNotNull);

      // Two quick taps before the screen has redrawn: one send.
      await tester.tap(find.text('Try again'));
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(tries, 2, reason: 'a second tap on a busy button sends nothing more');
      expect(find.text('Test Results'), findsOneWidget);
    });

    semanticTest('after a failed send with time left, Back to the test returns to the paper with the answers', (
      tester,
    ) async {
      repo.onSubmit = (_, _, _) async => throw ApiError('offline');
      final c = await pumpExam(tester);
      await tester.tap(find.text('Option B1'));
      await tester.pump();
      await tapText(tester, 'Finish');
      await tester.ensureVisible(find.text('Submit test'));
      await tester.tap(find.text('Submit test'));
      await settle(tester);
      await tapText(tester, 'Back to the test');
      expect(find.text("Your answers didn't go"), findsNothing);
      expect(c.phase, ExamPhase.running);
      expect(optionChecked(tester, 'Option B1'), isTrue);
      await tester.tap(find.text('Option C1'));
      await tester.pump();
      expect(c.picked('q1'), [2]);
    });

    semanticTest('a refusal that cannot be undone has only Close, which gives the sitting up', (tester) async {
      repo.onSubmit = (_, _, _) async =>
          throw ApiError('You have used all 3 attempts for this paper.', statusCode: 403);
      phone(tester);
      final c = controllerFor(sampleSitting());
      await tester.pumpWidget(launched(ExamScreen(controller: c)));
      await tester.tap(find.text('start'));
      await settle(tester);
      await tester.tap(find.text('Option B1'));
      await tester.pump();
      await tapText(tester, 'Finish');
      await tester.ensureVisible(find.text('Submit test'));
      await tester.tap(find.text('Submit test'));
      await settle(tester);

      expect(find.text('You have used all 3 attempts for this paper.'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      expect(find.text('The API turned this sitting down, so there is nothing to retry.'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await settle(tester);
      expect(find.byType(ExamScreen), findsNothing);
      expect(await store.load('u1', 'cp-foundation'), isNull, reason: 'nothing left to resume');
    });

    semanticTest('leaving asks first; Keep going stays; Leave closes with the sitting kept to resume', (tester) async {
      phone(tester);
      final c = controllerFor(sampleSitting());
      var ended = 0;
      await tester.pumpWidget(launched(ExamScreen(controller: c, onFlowEnd: () => ended++)));
      await tester.tap(find.text('start'));
      await settle(tester);
      await tester.tap(find.text('Option B1'));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Leave the exam'));
      await settle(tester);
      expect(find.text('Leave the exam?'), findsOneWidget);
      await tester.tap(find.text('Keep going'));
      await settle(tester);
      expect(find.byType(ExamScreen), findsOneWidget);
      expect(ended, 0);

      // The phone's own back gesture asks the same.
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('Leave the exam?'), findsOneWidget);
      await tester.tap(find.text('Leave'));
      await settle(tester);
      expect(find.byType(ExamScreen), findsNothing);
      expect(ended, 1);
      final kept = await store.load('u1', 'cp-foundation');
      expect(kept!.answers['q1'], [1], reason: 'the sitting is kept, to resume from the paper');
    });

    semanticTest('a rotation keeps the question, the answers and the clock', (tester) async {
      final c = await pumpExam(tester, sitting: sampleSitting(paper: samplePaper(minutes: 30)));
      await tester.tap(find.text('Option C1'));
      await tapText(tester, 'Next');
      await tester.tap(find.text('Option A2'));
      await tester.pump();
      clock.advance(const Duration(minutes: 3));
      c.tick();
      await tester.pump();

      tester.view.physicalSize = const Size(844 * 2, 390 * 2);
      await tester.pump();
      await tester.pump();
      expect(find.text('Question 2'), findsOneWidget);
      expect(find.text('Time Left: 27:00'), findsOneWidget);
      expect(stripLabel(tester, 1), 'Go to question 1, answered');
      expect(stripLabel(tester, 2), 'Go to question 2, answered, current');
      await scrollTo(tester, find.text('Option A2'));
      expect(optionChecked(tester, 'Option A2'), isTrue);
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      await tester.pump();
      await goToQuestion(tester, 1);
      expect(optionChecked(tester, 'Option C1'), isTrue);
    });

    semanticTest('a whole new screen on a saved sitting (the app was killed) finds everything where it was', (
      tester,
    ) async {
      final first = controllerFor(sampleSitting())..start();
      first.select(2);
      first.goTo(1);
      first.toggleFlag();
      first.goTo(3);
      first.select(1);
      await first.flushed();
      first.dispose();
      clock.advance(const Duration(minutes: 9));

      final saved = (await store.load('u1', 'cp-foundation'))!;
      await pumpExam(tester, sitting: saved.sitting, resume: saved);
      expect(find.text('Question 4'), findsOneWidget);
      expect(optionChecked(tester, 'Option B4'), isTrue);
      expect(find.text('Time Left: 21:00'), findsOneWidget);
      expect(stripLabel(tester, 4), 'Go to question 4, answered, current');
      expect(stripLabel(tester, 3), 'Go to question 3, not answered');
      await goToQuestion(tester, 2);
      expect(find.text('Question 2'), findsOneWidget);
      expect(stripLabel(tester, 2), 'Go to question 2, not answered, flagged, current');
      expect(find.bySemanticsLabel('Unflag'), findsOneWidget, reason: 'the flag on question 2 came back too');
    });

    semanticTest('a screen opened on a sitting whose time ran out sends its answers at once', (tester) async {
      final first = controllerFor(sampleSitting(paper: samplePaper(minutes: 10)))..start();
      first.select(3);
      await first.flushed();
      first.dispose();
      final saved = (await store.load('u1', 'cp-foundation'))!;
      clock.advance(const Duration(minutes: 40));
      await pumpExam(tester, sitting: saved.sitting, resume: saved);
      await settle(tester);
      expect(repo.submitted, hasLength(1));
      expect(repo.submitted.single.first.selected, [3]);
      expect(find.text('Test Results'), findsOneWidget);
      expect(await store.load('u1', 'cp-foundation'), isNull);
    });

    semanticTest('the app going to the background and coming back recomputes the clock', (tester) async {
      final c = await pumpExam(tester, sitting: sampleSitting(paper: samplePaper(minutes: 30)));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      clock.advance(const Duration(minutes: 11));
      await tester.pump(const Duration(seconds: 3));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(c.remaining.value, const Duration(minutes: 19));
      expect(find.text('Time Left: 19:00'), findsOneWidget);
      expect(repo.submitted, isEmpty);
    });

    semanticTest('the app coming back after the time ran out sends the answers', (tester) async {
      await pumpExam(tester, sitting: sampleSitting(paper: samplePaper(minutes: 10)));
      await tester.tap(find.text('Option B1'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      clock.advance(const Duration(minutes: 30));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      expect(repo.submitted, hasLength(1));
      expect(repo.submitted.single.first.selected, [1]);
      expect(find.text('Test Results'), findsOneWidget);
    });

    semanticTest('options can be read by a screen reader: letter, text, and whether it is chosen', (tester) async {
      await pumpExam(tester, sitting: sampleSitting(multipleAt: 0));
      await tester.tap(find.text('Option B1'));
      await tester.pump();
      expect(find.bySemanticsLabel('Option B. Option B1'), findsOneWidget);
      final node = tester.getSemantics(find.bySemanticsLabel('Option B. Option B1'));
      expect(node.getSemanticsData().flagsCollection.isChecked, CheckedState.isTrue);
      expect(find.bySemanticsLabel(RegExp('^Time remaining 30 minutes')), findsOneWidget);
    });
  });

  // --- the result -----------------------------------------------------------------------------------------

  group('the result', () {
    Future<void> pumpResult(
      WidgetTester tester,
      AttemptResult result, {
      bool certifying = true,
      String? firstName = 'Bharat',
      VoidCallback? onRetake,
      String? suffix,
      Map<String, int>? questionMarks,
      Size size = const Size(390, 844),
    }) async {
      phone(tester, size: size);
      await tester.pumpWidget(const SizedBox.shrink()); // a fresh page, not the last one with its result still pushed
      await tester.pumpWidget(
        launched(
          ResultScreen(
            result: result,
            paperName: 'Capital Planning – Foundation',
            certificateEnabled: certifying,
            firstName: firstName,
            onRetake: onRetake,
            eyebrowSuffix: suffix,
            questionMarks: questionMarks,
          ),
        ),
      );
      await tester.tap(find.text('start'));
      await settle(tester);
    }

    semanticTest('a pass on a certifying paper: the headline, the tiles, and the certificate', (tester) async {
      await pumpResult(tester, sampleResult(percentage: 90, withCertificate: true), suffix: ' · 18 Oct 2026');
      expect(find.text('Test Results'), findsOneWidget);
      expect(find.text('TEST ANALYSIS — FOUNDATION · 18 OCT 2026'), findsOneWidget);
      expect(find.text('Summative'), findsOneWidget, reason: 'a certifying paper is not a formative one');
      expect(find.text('Outstanding result, Bharat'), findsOneWidget);
      expect(
        find.textContaining('You passed Capital Planning – Foundation with 90%, against a pass mark of 70%.'),
        findsOneWidget,
      );
      expect(find.text('Certificate issued: ICR-CP-2026-AB12CD34, on attempt 2.'), findsOneWidget);
      // The six tiles: score, percentage, correct, wrong, unanswered, time taken.
      for (final tile in [
        '5 / 5 Score',
        '90% Percentage',
        '5 Correct',
        '0 Wrong',
        '0 Unanswered',
        '12m 04s Time taken',
      ]) {
        expect(find.bySemanticsLabel(tile), findsOneWidget, reason: tile);
      }
      expect(find.bySemanticsLabel('Attempt Count 1'), findsOneWidget);
      expect(find.text('Attempt Count'), findsOneWidget);
    });

    semanticTest('the tiles count what went wrong too, and the headline of a miss is red', (tester) async {
      await pumpResult(tester, sampleResult(percentage: 40));
      expect(find.bySemanticsLabel('2 / 5 Score'), findsOneWidget);
      expect(find.bySemanticsLabel('40% Percentage'), findsOneWidget);
      expect(find.bySemanticsLabel('2 Correct'), findsOneWidget);
      expect(find.bySemanticsLabel('3 Wrong'), findsOneWidget);
      final headline = tester.widget<Text>(find.text('Not quite there yet, Bharat'));
      expect(headline.style!.color, const Color(0xFFBA1A1A));
    });

    semanticTest('Passed with under 85% reads Well done', (tester) async {
      await pumpResult(tester, sampleResult(percentage: 80));
      expect(find.text('Well done, Bharat'), findsOneWidget);
    });

    semanticTest('a miss on a certifying paper says how far it was from the pass mark', (tester) async {
      await pumpResult(tester, sampleResult(percentage: 40));
      expect(find.text('Not quite there yet, Bharat'), findsOneWidget);
      expect(
        find.text('You scored 40%, and the pass mark is 70%. Review the answers, then try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('Certificate issued'), findsNothing);
    });

    semanticTest('a practice paper says what was scored, in red or green, and that no certificate is issued', (
      tester,
    ) async {
      await pumpResult(tester, sampleResult(percentage: 60), certifying: false);
      expect(find.text('You scored 60%'), findsOneWidget);
      expect(find.text('Formative'), findsOneWidget);
      expect(find.text('Practice paper — no certificate is issued.'), findsOneWidget);
      Color? percentColour() {
        final span = tester.widget<Text>(find.text('You scored 60%')).textSpan! as TextSpan;
        return (span.children!.last as TextSpan).style!.color;
      }

      expect(percentColour(), const Color(0xFFBA1A1A));
    });

    semanticTest('a practice paper above the pass mark is green', (tester) async {
      await pumpResult(tester, sampleResult(percentage: 90), certifying: false);
      final span = tester.widget<Text>(find.text('You scored 90%')).textSpan! as TextSpan;
      expect((span.children!.last as TextSpan).style!.color, const Color(0xFF006C49));
    });

    semanticTest('without a name the headline is bare', (tester) async {
      await pumpResult(tester, sampleResult(percentage: 90), firstName: null);
      expect(find.text('Outstanding result'), findsOneWidget);
    });

    semanticTest('the tag names the set of a mock paper', (tester) async {
      final mock = samplePaper(slug: 'bemp-1', title: 'Set 1', kind: PaperKind.mock, certificate: false);
      await pumpResult(tester, sampleResult(percentage: 60, paper: mock), certifying: false);
      expect(find.text('TEST ANALYSIS — SET 1'), findsOneWidget);
    });

    semanticTest('it is one compact page: nothing of the review or the attempts is on it', (tester) async {
      await pumpResult(tester, sampleResult(percentage: 40, total: 5), onRetake: () {}, certifying: false);
      for (final gone in [
        'Question Review & Explanations',
        'My attempts',
        'By topic',
        'Previous',
        'Back',
        'Retake Test',
      ]) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      // All of it is on the first screen: nothing to scroll.
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
      expect(scroll.position.maxScrollExtent, 0);
      expect(tester.getBottomLeft(find.text('Review answers')).dy, lessThan(742), reason: 'the design is 742 tall');
      expect(layoutProblems().where((p) => p.startsWith('clipped')), isEmpty);
    });

    semanticTest('Retake test and Review answers sit side by side, and Review answers opens its own screen', (
      tester,
    ) async {
      await pumpResult(tester, sampleResult(percentage: 40, total: 5), onRetake: () {});
      final retake = tester.getRect(find.text('Retake test'));
      final review = tester.getRect(find.text('Review answers'));
      expect((retake.center.dy - review.center.dy).abs(), lessThan(1), reason: 'one row');
      expect(retake.center.dx, lessThan(review.center.dx));
      await tester.tap(find.text('Review answers'));
      await settle(tester);
      expect(find.byType(ReviewAnswersScreen), findsOneWidget);
      expect(find.text('Review Answers'), findsOneWidget);
      expect(find.text('Question Review & Explanations'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Back').first);
      await settle(tester);
      expect(find.byType(ReviewAnswersScreen), findsNothing);
      expect(find.text('Test Results'), findsOneWidget, reason: 'back on the result');
    });

    semanticTest('View certificate opens the certificate', (tester) async {
      await pumpResult(tester, sampleResult(percentage: 90, withCertificate: true));
      await tester.tap(find.text('View certificate'));
      await settle(tester);
      expect(find.text('Certificate of Knowledge Assessment'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });

    semanticTest('Retake test closes the result and starts the paper again; the back arrow just closes', (
      tester,
    ) async {
      var retaken = 0;
      await pumpResult(tester, sampleResult(percentage: 40), onRetake: () => retaken++);
      await tester.tap(find.text('Retake test'));
      await settle(tester);
      expect(retaken, 1);
      expect(find.byType(ResultScreen), findsNothing);

      await pumpResult(tester, sampleResult(percentage: 40), onRetake: () => retaken++);
      await tester.tap(find.bySemanticsLabel('Back').first);
      await settle(tester);
      expect(retaken, 1);
      expect(find.byType(ResultScreen), findsNothing);
    });

    semanticTest('two quick taps on Retake test start the paper once and do not close the page under the result', (
      tester,
    ) async {
      var retaken = 0;
      await pumpResult(tester, sampleResult(percentage: 40), onRetake: () => retaken++);
      await tester.tap(find.text('Retake test'));
      await tester.tap(find.text('Retake test'));
      await settle(tester);
      expect(retaken, 1);
      expect(find.text('start'), findsOneWidget, reason: 'the page that opened the result is still there');
    });

    semanticTest('with nothing to retake there is only Review answers, across the page', (tester) async {
      await pumpResult(tester, sampleResult(percentage: 40));
      expect(find.text('Retake test'), findsNothing);
      expect(find.text('Review answers'), findsOneWidget);
      expect(tester.getSize(find.byType(ExamButton)).width, greaterThan(300));
    });

    semanticTest('a result with nothing to review has no Review answers', (tester) async {
      final r = sampleResult(percentage: 40);
      await pumpResult(
        tester,
        AttemptResult(attempt: r.attempt, review: const []),
        onRetake: () {},
      );
      expect(find.text('Review answers'), findsNothing);
      expect(find.text('Retake test'), findsOneWidget);
    });

    group('at 360 dp', () {
      semanticTest('the result does not overflow, and nothing is cut off', (tester) async {
        await pumpResult(
          tester,
          sampleResult(percentage: 90, total: 5, withCertificate: true),
          onRetake: () {},
          size: const Size(360, 780),
          suffix: ' · 18 Oct 2026',
        );
        expect(tester.takeException(), isNull);
        expect(layoutProblems().where((p) => p.startsWith('clipped')), isEmpty);
      });
    });
  });

  // --- Review Answers -------------------------------------------------------------------------------------

  group('Review Answers', () {
    Future<void> pumpReview(
      WidgetTester tester,
      AttemptResult result, {
      Map<String, int>? questionMarks,
      Size size = const Size(390, 927),
    }) async {
      phone(tester, size: size);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(launched(ReviewAnswersScreen(result: result, questionMarks: questionMarks)));
      await tester.tap(find.text('start'));
      await settle(tester);
    }

    /// The filter chip for [label] ("Incorrect (1)").
    Finder chip(String label) => find.text(label);

    /// Number [n] of the review's strip.
    Finder reviewNumber(int n) => find.byKey(ValueKey('review-q-$n'));

    /// Taps the strip's number [n].
    Future<void> openQuestion(WidgetTester tester, int n) async {
      await tester.ensureVisible(reviewNumber(n));
      await tester.tap(reviewNumber(n));
      await settle(tester);
    }

    semanticTest('every question is worked through: the key, the pick, the mark and the explanation', (tester) async {
      await pumpReview(tester, sampleResult(percentage: 40, total: 5));
      expect(find.text('Review Answers'), findsOneWidget);
      expect(find.text('Question Review & Explanations'), findsOneWidget);
      // sampleResult(40%) is 2 right (q1, q2), q3 wrong (picked C), q4 and q5 skipped; it opens on the first.
      expect(find.text('Question 1'), findsOneWidget);
      expect(find.text('Question number 1: what is right?'), findsOneWidget);
      expect(find.text('1 / 1 Mark'), findsOneWidget);
      expect(find.text('Your Answer (Correct)'), findsOneWidget);

      await openQuestion(tester, 3);
      expect(find.text('Question 3'), findsOneWidget);
      expect(find.text('Question number 3: what is right?'), findsOneWidget);
      expect(find.text('Question number 1: what is right?'), findsNothing, reason: 'one question at a time');
      expect(find.text('0 / 1 Mark'), findsOneWidget);
      expect(find.text('Incorrect'), findsWidgets);
      expect(find.text('Correct Answer'), findsOneWidget, reason: 'B, the key, which was not picked');
      expect(find.text('Your Answer (Incorrect)'), findsOneWidget, reason: 'C, which was');
      expect(find.text('Rationale'), findsOneWidget);
      expect(find.text('Detailed Explanation & Rationale'), findsNothing, reason: 'owner, 3 Nov 2026');
      expect(find.text('Because B is the answer to number 3.'), findsOneWidget);
      expect(find.text('Core Topic: Budgeting'), findsOneWidget);
      expect(find.bySemanticsLabel('Option C. Option C3. Your Answer (Incorrect).'), findsOneWidget);
      expect(find.bySemanticsLabel('Option B. Option B3. Correct Answer.'), findsOneWidget);
      // The options carry their letters with a full stop, as the design has them.
      expect(find.text('A.'), findsOneWidget);
      expect(find.text('D.'), findsOneWidget);

      // Question 4 was left blank and has no explanation: no panel, no topic.
      await openQuestion(tester, 4);
      expect(find.text('Unanswered'), findsWidgets);
      expect(find.text('Rationale'), findsNothing);
      expect(find.textContaining('Core Topic'), findsNothing);
      expect(find.text('Correct Answer'), findsOneWidget);
      expect(find.text('Your Answer (Incorrect)'), findsNothing);
    });

    semanticTest('the strip numbers each question by how it went, and the one on show is marked', (tester) async {
      await pumpReview(tester, sampleResult(percentage: 40, total: 5));
      String label(int n) => tester.getSemantics(reviewNumber(n)).label;
      expect(label(1), 'Question 1, correct, on show');
      expect(label(2), 'Question 2, correct');
      expect(label(3), 'Question 3, incorrect');
      expect(label(4), 'Question 4, unanswered');
      await openQuestion(tester, 3);
      expect(label(3), 'Question 3, incorrect, on show');
      expect(label(1), 'Question 1, correct');
    });

    semanticTest('the pager sits in the card under the explanation, walks the questions and is off at both ends', (
      tester,
    ) async {
      await pumpReview(tester, sampleResult(percentage: 40, total: 5));
      expect(find.text('Question 1 of 5'), findsOneWidget);
      final explanation = tester.getBottomLeft(find.text('Because B is the answer to number 1.')).dy;
      expect(tester.getTopLeft(find.text('Question 1 of 5')).dy, greaterThan(explanation), reason: 'under it');
      await tester.tap(find.text('Previous'), warnIfMissed: false);
      await settle(tester);
      expect(find.text('Question 1 of 5'), findsOneWidget, reason: 'Previous is off on the first');

      await tester.tap(find.text('Next'));
      await settle(tester);
      expect(find.text('Question 2 of 5'), findsOneWidget);
      expect(find.text('Question number 2: what is right?'), findsOneWidget);
      await tester.tap(find.text('Previous'));
      await settle(tester);
      expect(find.text('Question 1 of 5'), findsOneWidget);

      for (var i = 0; i < 4; i++) {
        await tester.ensureVisible(find.text('Next'));
        await tester.tap(find.text('Next'));
        await settle(tester);
      }
      expect(find.text('Question 5 of 5'), findsOneWidget);
      expect(find.text('Question number 5: what is right?'), findsOneWidget);
      await tester.tap(find.text('Next'), warnIfMissed: false);
      await settle(tester);
      expect(find.text('Question 5 of 5'), findsOneWidget, reason: 'Next is off on the last');
    });

    semanticTest('Next shows the next question from its top, not from where the last one was scrolled to', (
      tester,
    ) async {
      await pumpReview(tester, sampleResult(percentage: 40, total: 5), size: const Size(390, 520));
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('Next'));
      await tester.pump();
      expect(scroll.position.pixels, greaterThan(0), reason: 'the pager is below the first screen of a short phone');
      await tester.tap(find.text('Next'));
      await settle(tester);
      expect(find.text('Question 2 of 5'), findsOneWidget);
      expect(scroll.position.pixels, 0);
    });

    semanticTest('the filters narrow the review to incorrect, unanswered or correct questions', (tester) async {
      await pumpReview(tester, sampleResult(percentage: 40, total: 5));
      expect(chip('All (5)'), findsOneWidget);
      expect(chip('Incorrect (1)'), findsOneWidget);
      expect(chip('Unanswered (2)'), findsOneWidget);
      expect(chip('Correct (2)'), findsOneWidget);

      await tester.tap(chip('Incorrect (1)'));
      await settle(tester);
      expect(find.text('Question number 3: what is right?'), findsOneWidget);
      expect(find.text('Question number 1: what is right?'), findsNothing);
      expect(find.text('Question 3'), findsOneWidget, reason: 'it keeps its own number');
      expect(find.text('Question 3 of 5'), findsOneWidget);
      expect(reviewNumber(3), findsOneWidget);
      expect(reviewNumber(1), findsNothing, reason: 'the strip is the filtered questions');
      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'), warnIfMissed: false);
      await settle(tester);
      expect(find.text('Question number 3: what is right?'), findsOneWidget, reason: 'the only one: no way on');

      await tester.tap(chip('Unanswered (2)'));
      await settle(tester);
      expect(find.text('Question number 4: what is right?'), findsOneWidget);
      expect(find.text('Question number 3: what is right?'), findsNothing);
      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await settle(tester);
      expect(find.text('Question number 5: what is right?'), findsOneWidget);

      await tester.tap(chip('Correct (2)'));
      await settle(tester);
      expect(find.text('Question number 1: what is right?'), findsOneWidget);

      await tester.tap(chip('All (5)'));
      await settle(tester);
      expect(reviewNumber(5), findsOneWidget);
      expect(reviewNumber(1), findsOneWidget);
      expect(find.text('Question number 1: what is right?'), findsOneWidget, reason: 'it stays where it was');
    });

    semanticTest('a filter nothing falls under says so, and Unanswered is offered only when something is', (
      tester,
    ) async {
      await pumpReview(tester, sampleResult(percentage: 100, total: 5));
      expect(chip('Correct (5)'), findsOneWidget);
      expect(chip('Incorrect (0)'), findsOneWidget, reason: 'drawn with its zero, as the design does');
      expect(find.textContaining('Unanswered ('), findsNothing);
      await tester.tap(chip('Incorrect (0)'));
      await settle(tester);
      expect(find.text('Nothing here.'), findsOneWidget);
      await tester.tap(chip('All (5)'));
      await settle(tester);
      expect(find.text('Nothing here.'), findsNothing);
    });

    semanticTest('four chips fit on one line of a phone', (tester) async {
      await pumpReview(tester, sampleResult(percentage: 40, total: 5));
      final tops = {
        for (final l in ['All (5)', 'Incorrect (1)', 'Unanswered (2)', 'Correct (2)']) tester.getTopLeft(chip(l)).dy,
      };
      expect(tops, hasLength(1), reason: 'one row');
    });

    semanticTest('questions removed from the bank since the sitting are counted, not hidden', (tester) async {
      final r = sampleResult(percentage: 80, total: 5);
      final fewer = AttemptResult(attempt: r.attempt, review: r.review.take(3).toList());
      await pumpReview(tester, fewer);
      expect(find.textContaining('2 questions from this sitting have since been removed'), findsOneWidget);
    });

    semanticTest('what a question was worth: from the review, from the sitting, or one a question when all are', (
      tester,
    ) async {
      // maxScore equals the number of questions here, so every question is one mark.
      await pumpReview(tester, sampleResult(percentage: 40, total: 5));
      expect(find.text('1 / 1 Mark'), findsOneWidget);

      // The sitting just taken knows each question's marks.
      await pumpReview(
        tester,
        sampleResult(percentage: 40, total: 5),
        questionMarks: {'q1': 2, 'q2': 1, 'q3': 3, 'q4': 1, 'q5': 1},
      );
      expect(find.text('2 / 2 Marks'), findsOneWidget);
      await openQuestion(tester, 3);
      expect(find.text('0 / 3 Marks'), findsOneWidget);

      // A review that says what it was worth wins.
      final base = sampleResult(percentage: 40, total: 5);
      final weighted = AttemptResult(
        attempt: base.attempt,
        review: [
          for (final r in base.review)
            ReviewItem(
              id: r.id,
              prompt: r.prompt,
              options: r.options,
              correctIndexes: r.correctIndexes,
              selected: r.selected,
              explanation: r.explanation,
              category: r.category,
              marks: 4,
            ),
        ],
      );
      await pumpReview(tester, weighted);
      expect(find.text('4 / 4 Marks'), findsOneWidget);
    });

    semanticTest('a paper with marks that differ and a review that does not say shows no mark line', (tester) async {
      final a = sampleAttempt(percentage: 40);
      final heavy = Attempt(
        id: a.id,
        paperId: a.paperId,
        attempt: a.attempt,
        startedAt: a.startedAt,
        submittedAt: a.submittedAt,
        timeTakenMs: a.timeTakenMs,
        totalQuestions: 5,
        correct: 2,
        wrong: 3,
        unanswered: 0,
        score: 4,
        maxScore: 8,
        percentage: 50,
        passPercentage: 70,
        passed: false,
        paper: a.paper,
      );
      await pumpReview(tester, AttemptResult(attempt: heavy, review: sampleReview(5, right: 2)));
      expect(find.textContaining(' Mark'), findsNothing, reason: 'it is not made up');
    });

    semanticTest('the back arrow closes the review', (tester) async {
      await pumpReview(tester, sampleResult(percentage: 40));
      await tester.tap(find.bySemanticsLabel('Back').first);
      await settle(tester);
      expect(find.byType(ReviewAnswersScreen), findsNothing);
      expect(find.text('start'), findsOneWidget);
    });

    semanticTest('a review with nothing in it says so', (tester) async {
      final r = sampleResult(percentage: 40);
      await pumpReview(tester, AttemptResult(attempt: r.attempt, review: const []));
      expect(find.text('Nothing here.'), findsOneWidget);
    });

    group('at 360 dp', () {
      semanticTest('the review does not overflow, and nothing is cut off', (tester) async {
        await pumpReview(tester, sampleResult(percentage: 40, total: 12), size: const Size(360, 780));
        expect(tester.takeException(), isNull);
        expect(layoutProblems().where((p) => p.startsWith('clipped')), isEmpty);
        await openQuestion(tester, 3);
        expect(tester.takeException(), isNull);
      });
    });
  });

  // --- the certificate ------------------------------------------------------------------------------------

  group('a certificate', () {
    Future<void> pumpDetail(WidgetTester tester, ExamCertificate c) async {
      phone(tester);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showCertificateSheet(context, c, holder: 'Bharat Buyer'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
    }

    semanticTest('is drawn with its holder, credential, level, dates and number, and its facts below', (tester) async {
      await pumpDetail(tester, sampleCertificate(provider: 'Leoron Institute'));
      expect(find.text('CERTIFICATE'), findsOneWidget);
      expect(find.text('OF KNOWLEDGE ASSESSMENT'), findsOneWidget);
      expect(find.text('Bharat Buyer'), findsOneWidget);
      expect(find.text('For successfully completing :'), findsOneWidget);
      expect(find.text('FOUNDATION LEVEL'), findsOneWidget);
      expect(find.text('5 August 2026'), findsWidgets);
      expect(find.text('12-AUG-2026'), findsOneWidget);
      expect(find.text('LEORON INSTITUTE'), findsOneWidget);
      expect(find.text('VINAY KUMAR SHETTY'), findsOneWidget);
      expect(find.text('90% against a 70% pass standard'), findsOneWidget);
      expect(
        find.text(
          'Issued once, on attempt #2. Later attempts update your history but never reissue or restate this certificate.',
        ),
        findsOneWidget,
      );
    });

    semanticTest('Share hands the verification link to the share sheet', (tester) async {
      await pumpDetail(tester, sampleCertificate());
      await tester.ensureVisible(find.text('Share'));
      await tester.tap(find.text('Share'));
      await settle(tester);
      expect(shared.single, contains('Capital Planning'));
      expect(shared.single, contains('/learning/verify?id=ICR-CP-2026-AB12CD34'));
    });

    semanticTest('Copy number puts the credential number on the clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pumpDetail(tester, sampleCertificate());
      await tester.ensureVisible(find.text('Copy number'));
      await tester.tap(find.text('Copy number'));
      await settle(tester);
      expect(copied, 'ICR-CP-2026-AB12CD34');
      expect(find.text('Number copied'), findsOneWidget);
    });

    semanticTest('the register and LinkedIn open on the website', (tester) async {
      await pumpDetail(tester, sampleCertificate());
      expect(find.text('Download PDF on the website'), findsNothing, reason: 'the PDF is the app\'s own now');
      for (final label in ['Check it in the register', 'Add to LinkedIn']) {
        await tester.ensureVisible(find.text(label));
        await tester.pump();
        await tester.tap(find.text(label));
        await settle(tester);
      }
      expect(opened[0].toString(), endsWith('/learning/verify?id=ICR-CP-2026-AB12CD34'));
      expect(opened[1].host, 'www.linkedin.com');
      expect(opened[1].queryParameters['name'], 'Capital Planning');
      expect(opened[1].queryParameters['certId'], 'ICR-CP-2026-AB12CD34');
      expect(opened[1].queryParameters['issueYear'], '2026');
      expect(opened[1].queryParameters['issueMonth'], '8');
      expect(opened[1].queryParameters['certUrl'], contains('/learning/verify?id=ICR-CP-2026-AB12CD34'));
    });

    group('Download PDF', () {
      final saved = <({String name, Uint8List bytes})>[];

      setUp(() {
        saved.clear();
        CertificatePdfServices.fetch = (url) async => null;
        CertificatePdfServices.renderName = (holder, size) async => null;
        CertificatePdfServices.save = (name, bytes) async {
          saved.add((name: name, bytes: bytes));
          return Uri.file('/storage/emulated/0/Download/$name');
        };
      });

      tearDown(CertificatePdfServices.reset);

      /// The marks are read from the bundle and decoded by the engine, which is real work outside the test's
      /// clock: wait for it a moment at a time, letting the widget run in between.
      Future<void> untilDone(WidgetTester tester, bool Function() done) async {
        for (var i = 0; i < 400 && !done(); i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
          await tester.pump();
        }
        await settle(tester);
      }

      Future<void> tapDownload(WidgetTester tester) async {
        await tester.ensureVisible(find.text('Download PDF'));
        await tester.pump();
        await tester.tap(find.text('Download PDF'));
        await tester.pump();
      }

      semanticTest('builds the PDF in the app and saves it, with no trip to the website', (tester) async {
        await pumpDetail(tester, sampleCertificate());
        await tapDownload(tester);
        await untilDone(tester, () => saved.isNotEmpty);

        expect(saved, hasLength(1));
        expect(saved.single.name, 'ICR-CP-2026-AB12CD34.pdf');
        final head = String.fromCharCodes(saved.single.bytes.take(8));
        expect(head, '%PDF-1.4');
        final pdf = String.fromCharCodes(saved.single.bytes);
        expect(pdf, endsWith('%%EOF'));
        expect(pdf, contains('(Bharat Buyer) Tj'), reason: 'made out to the holder the sheet shows');
        expect(pdf, contains('(Capital Planning) Tj'));
        expect(pdf, contains('(ICR-CP-2026-AB12CD34) Tj'));
        expect(pdf, contains('(5 August 2026) Tj'));
        expect(pdf, contains('(12-AUG-2026) Tj'));
        expect(pdf, contains('/Subtype /Image'), reason: 'the bundled marks are embedded');
        expect(opened, isEmpty, reason: 'nothing opened on the website');
        expect(find.text('Saved ICR-CP-2026-AB12CD34.pdf'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'the button is free again');
      });

      semanticTest('says nothing when the person closes the save sheet', (tester) async {
        CertificatePdfServices.marks = (c, holder) async => const CertificateMarks();
        CertificatePdfServices.save = (name, bytes) async => null;
        await pumpDetail(tester, sampleCertificate());
        await tapDownload(tester);
        await settle(tester);
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Download PDF'), findsOneWidget);
      });

      semanticTest('says so when the PDF cannot be made, and the button works again', (tester) async {
        CertificatePdfServices.marks = (c, holder) async => const CertificateMarks();
        var tries = 0;
        CertificatePdfServices.save = (name, bytes) async {
          tries++;
          if (tries == 1) throw StateError('disk full');
          return Uri.file('/storage/emulated/0/Download/$name');
        };
        await pumpDetail(tester, sampleCertificate());
        await tapDownload(tester);
        await settle(tester);
        expect(find.text("Couldn't make the PDF. Try again."), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        await tapDownload(tester);
        await settle(tester);
        expect(tries, 2);
        expect(find.text('Saved ICR-CP-2026-AB12CD34.pdf'), findsOneWidget);
      });

      semanticTest('waits while the PDF is being made: a spinner, and a second tap does nothing', (tester) async {
        CertificatePdfServices.marks = (c, holder) async => const CertificateMarks();
        final gate = Completer<Uri?>();
        var calls = 0;
        CertificatePdfServices.save = (name, bytes) {
          calls++;
          return gate.future;
        };
        await pumpDetail(tester, sampleCertificate());
        await tapDownload(tester);
        await settle(tester);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.tap(find.text('Download PDF'), warnIfMissed: false);
        await settle(tester);
        expect(calls, 1);

        gate.complete(Uri.file('/storage/emulated/0/Download/x.pdf'));
        await settle(tester);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Saved ICR-CP-2026-AB12CD34.pdf'), findsOneWidget);
      });

      semanticTest('a card in the list offers no download (the quick actions only)', (tester) async {
        phone(tester);
        await tester.pumpWidget(
          app(Scaffold(body: CertificateActions(certificate: sampleCertificate(), compact: true))),
        );
        expect(find.text('Share'), findsOneWidget);
        expect(find.text('Copy number'), findsOneWidget);
        expect(find.text('Download PDF'), findsNothing);
      });
    });

    test('the verification link is the register\'s page for the number', () {
      expect(verifyUri('ICR-CP-2026-AB12CD34').path, '/learning/verify');
      expect(verifyUri('ICR-CP-2026-AB12CD34').queryParameters['id'], 'ICR-CP-2026-AB12CD34');
    });
  });

  // --- My attempts ----------------------------------------------------------------------------------------

  group('My attempts', () {
    Future<void> pumpAttempts(WidgetTester tester, {VoidCallback? onBack}) async {
      phone(tester);
      await tester.pumpWidget(app(MyAttemptsScreen(onBack: onBack ?? () {}, repository: repo)));
      await tester.pump();
      await settle(tester);
    }

    setUp(() {
      final mock = samplePaper(slug: 'bemp-1', title: 'Set 1', kind: PaperKind.mock, certificate: false);
      repo.unread = 2;
      repo.attemptsValue = [
        sampleAttempt(id: 'a3', attempt: 3, percentage: 90),
        sampleAttempt(id: 'm1', percentage: 60, paper: mock),
        sampleAttempt(id: 'a1', percentage: 40),
      ];
      repo.results['a3'] = sampleResult(percentage: 90, withCertificate: true);
      repo.results['m1'] = sampleResult(percentage: 60, paper: mock);
    });

    semanticTest('lists the sittings newest first with score, correct, time and a pass or fail mark', (tester) async {
      await pumpAttempts(tester);
      expect(find.text('My attempts'), findsOneWidget);
      expect(find.text('3'), findsOneWidget, reason: 'attempts');
      expect(find.text('1'), findsOneWidget, reason: 'passed');
      expect(find.text('90%'), findsWidgets);
      expect(find.text('Capital Planning – Foundation'), findsNWidgets(2));
      expect(find.text('ASHRAE BEMP – Set 1'), findsOneWidget);
      expect(find.text('Attempt #3 · 20 Oct 2026, 09:12'), findsOneWidget);
      expect(find.text('Pass'), findsOneWidget);
      expect(find.text('Fail'), findsOneWidget);
      expect(find.text('Below pass mark'), findsOneWidget, reason: 'a mock set is not failed');
      expect(find.text('12m 04s'), findsWidgets);
    });

    semanticTest('the filters narrow the list to assessments or mock exams', (tester) async {
      await pumpAttempts(tester);
      await tester.tap(find.text('Mock exams'));
      await settle(tester);
      expect(find.text('ASHRAE BEMP – Set 1'), findsOneWidget);
      expect(find.text('Capital Planning – Foundation'), findsNothing);
      await tester.tap(find.text('Assessments'));
      await settle(tester);
      expect(find.text('ASHRAE BEMP – Set 1'), findsNothing);
      expect(find.text('Capital Planning – Foundation'), findsNWidgets(2));
      await tester.tap(find.text('All'));
      await settle(tester);
      expect(find.text('ASHRAE BEMP – Set 1'), findsOneWidget);
    });

    semanticTest('a filter with nothing in it says so and Show all brings the list back', (tester) async {
      repo.attemptsValue = [sampleAttempt()];
      await pumpAttempts(tester);
      await tester.tap(find.text('Mock exams'));
      await settle(tester);
      expect(find.text('Nothing under this filter'), findsOneWidget);
      await tester.tap(find.text('Show all'));
      await settle(tester);
      expect(find.text('Capital Planning – Foundation'), findsOneWidget);
    });

    semanticTest('a sitting opens its result again, with the key and the explanations', (tester) async {
      await pumpAttempts(tester);
      await tester.tap(find.text('Attempt #3 · 20 Oct 2026, 09:12'));
      await settle(tester);
      expect(find.text('Test Results'), findsOneWidget);
      expect(find.text('TEST ANALYSIS — FOUNDATION · 20 OCT 2026'), findsOneWidget);
      expect(find.text('Outstanding result'), findsOneWidget);
      expect(find.text('Certificate issued: ICR-CP-2026-AB12CD34, on attempt 2.'), findsOneWidget);
      expect(find.text('Question Review & Explanations'), findsNothing, reason: 'that is its own screen now');
      await tester.tap(find.text('Review answers'));
      await settle(tester);
      expect(find.text('Question Review & Explanations'), findsOneWidget);
      expect(repo.calls, contains('attempt a3'));
    });

    semanticTest('Retake on an old result opens that paper brief', (tester) async {
      await pumpAttempts(tester);
      await tester.tap(find.text('ASHRAE BEMP – Set 1'));
      await settle(tester);
      await tester.tap(find.text('Retake test'));
      await settle(tester);
      expect(find.text('Assessment details'), findsOneWidget);
      expect(repo.calls, contains('sitting bemp-1'));
    });

    semanticTest('a result that will not load says why, and Try again loads it', (tester) async {
      repo.results.remove('m1');
      await pumpAttempts(tester);
      await tester.tap(find.text('ASHRAE BEMP – Set 1'));
      await settle(tester);
      expect(find.text("Couldn't open this result"), findsOneWidget);
      expect(find.text('Attempt not found'), findsOneWidget);
      repo.results['m1'] = sampleResult(
        percentage: 60,
        paper: samplePaper(slug: 'bemp-1', title: 'Set 1', kind: PaperKind.mock, certificate: false),
      );
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(
        find.text('You scored 60%'),
        findsOneWidget,
        reason: 'a mock set does not certify, so it is scored, not passed',
      );
      await tester.tap(find.text('Review answers'));
      await settle(tester);
      expect(find.text('Question Review & Explanations'), findsOneWidget);
    });

    semanticTest('no sittings yet: an empty state, and its button goes back', (tester) async {
      repo.attemptsValue = [];
      var back = 0;
      await pumpAttempts(tester, onBack: () => back++);
      expect(find.text('No attempts yet'), findsOneWidget);
      await tester.tap(find.text('Back to Learning'));
      await tester.pump();
      expect(back, 1);
    });

    semanticTest('a history that will not load shows the API\'s sentence and Try again', (tester) async {
      repo.attemptsError = ApiError("Can't reach ICR right now. Check your connection and try again.");
      await pumpAttempts(tester);
      expect(find.text("Couldn't load your attempts"), findsOneWidget);
      repo.attemptsError = null;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('Capital Planning – Foundation'), findsNWidgets(2));
    });

    semanticTest('pulling down reads the history again', (tester) async {
      await pumpAttempts(tester);
      final before = repo.calls.where((c) => c == 'attempts all').length;
      await tester.fling(find.byType(CustomScrollView), const Offset(0, 400), 1000);
      await settle(tester);
      expect(repo.calls.where((c) => c == 'attempts all').length, before + 1);
    });

    semanticTest('the back arrow goes back', (tester) async {
      var back = 0;
      await pumpAttempts(tester, onBack: () => back++);
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pump();
      expect(back, 1);
    });
  });

  // --- My certificates ------------------------------------------------------------------------------------

  group('My certificates', () {
    Future<void> pumpCerts(WidgetTester tester, {VoidCallback? onBack}) async {
      phone(tester);
      await tester.pumpWidget(app(CertificatesScreen(onBack: onBack ?? () {}, repository: repo)));
      await tester.pump();
      await settle(tester);
    }

    setUp(() {
      repo.certificatesValue = [
        sampleCertificate(),
        sampleCertificate(id: 'c2', number: 'ICR-X-2026-ZZ99', provider: 'Leoron Institute'),
      ];
    });

    semanticTest('each credential is a card: title, who awarded it, when, and its number', (tester) async {
      await pumpCerts(tester);
      expect(find.text('My certificates'), findsOneWidget);
      expect(find.text('Capital Planning'), findsWidgets);
      expect(find.text('ICR'), findsWidgets);
      expect(find.text('Leoron Institute'), findsWidgets);
      expect(find.text('12 Aug 2026'), findsWidgets);
      expect(find.text('ICR-CP-2026-AB12CD34'), findsOneWidget);
      expect(find.text('2'), findsOneWidget, reason: 'earned');
      expect(find.text('90%'), findsOneWidget, reason: 'best score');
      expect(find.text('Verified'), findsWidgets);
    });

    semanticTest('View certificate opens the certificate itself', (tester) async {
      await pumpCerts(tester);
      await tester.tap(find.text('View certificate').first);
      await settle(tester);
      expect(find.text('Certificate of Knowledge Assessment'), findsOneWidget);
      expect(find.text('CERTIFICATE'), findsOneWidget);
    });

    semanticTest('a card\'s Share and Copy number work from the list', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pumpCerts(tester);
      await tester.tap(find.text('Share').first);
      await settle(tester);
      expect(shared.single, contains('verify?id=ICR-CP-2026-AB12CD34'));
      await tester.tap(find.text('Copy number').first);
      await settle(tester);
      expect(copied, 'ICR-CP-2026-AB12CD34');
    });

    semanticTest('with more than one awarding body the list can be narrowed to one', (tester) async {
      await pumpCerts(tester);
      expect(find.text('All certificates'), findsOneWidget);
      await tester.tap(find.text('Leoron Institute').first);
      await settle(tester);
      expect(find.text('ICR-X-2026-ZZ99'), findsOneWidget);
      expect(find.text('ICR-CP-2026-AB12CD34'), findsNothing);
      await tester.tap(find.text('All certificates'));
      await settle(tester);
      expect(find.text('ICR-CP-2026-AB12CD34'), findsOneWidget);
    });

    semanticTest('with one awarding body there is nothing to filter by', (tester) async {
      repo.certificatesValue = [sampleCertificate()];
      await pumpCerts(tester);
      expect(find.text('All certificates'), findsNothing);
    });

    group('the register', () {
      Future<void> openRegister(WidgetTester tester) async {
        await pumpCerts(tester);
        await scrollTo(tester, find.text('Check a certificate number'));
        await tester.tap(find.text('Check a certificate number'));
        await settle(tester);
      }

      semanticTest('opens from the certificates list, with Verify off until there is a number', (tester) async {
        await openRegister(tester);
        expect(find.text('CERTIFICATE VERIFICATION'), findsOneWidget);
        expect(find.text('Certificate number'), findsOneWidget);
        await tester.tap(find.text('Verify'), warnIfMissed: false);
        await settle(tester);
        expect(repo.calls.where((c) => c.startsWith('verify')), isEmpty);
      });

      semanticTest('a number that is on the register says what it certifies and whose it is', (tester) async {
        repo.register['ICR-CP-2026-AB12CD34'] = ExamCertificate(
          id: 'c',
          certificateId: 'ICR-CP-2026-AB12CD34',
          title: 'Capital Planning',
          level: 'FOUNDATION',
          issuedAt: DateTime(2026, 8, 12),
          percentage: 90,
          passPercentage: 70,
          holder: 'Bharat Buyer',
        );
        await openRegister(tester);
        await tester.enterText(find.byType(TextField), 'icr-cp-2026-ab12cd34');
        await tester.pump();
        await tester.tap(find.text('Verify'));
        await settle(tester);
        expect(repo.calls, contains('verify icr-cp-2026-ab12cd34'));
        expect(find.text('Certificate verified'), findsOneWidget);
        expect(find.text('Genuine'), findsOneWidget);
        expect(find.text('Bharat Buyer'), findsOneWidget);
        expect(find.text('Institute for Corporate Real Estate'), findsOneWidget);
        expect(find.text('Foundation'), findsOneWidget);
        expect(find.text('90% against a 70% pass standard'), findsOneWidget);
        expect(find.text('12 August 2026'), findsOneWidget);
      });

      semanticTest('a number that is not on it says so', (tester) async {
        await openRegister(tester);
        await tester.enterText(find.byType(TextField), 'ICR-NOPE-1');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await settle(tester);
        expect(find.text('No certificate was found with that number. Check the number and try again.'), findsOneWidget);
        expect(find.text('Certificate verified'), findsNothing);
      });

      semanticTest('a failed look-up shows the API sentence, and Try again looks again', (tester) async {
        repo.verifyError = ApiError("Can't reach ICR right now. Check your connection and try again.");
        await openRegister(tester);
        await tester.enterText(find.byType(TextField), 'ICR-X-1');
        await tester.pump();
        await tester.tap(find.text('Verify'));
        await settle(tester);
        expect(find.textContaining("Can't reach ICR"), findsOneWidget);
        repo.verifyError = null;
        await tester.tap(find.text('Try again'));
        await settle(tester);
        expect(find.textContaining('No certificate was found'), findsOneWidget);
        expect(repo.calls.where((c) => c.startsWith('verify')), hasLength(2));
      });

      semanticTest('the sheet is the register: nothing sends the member to the website for it', (tester) async {
        await openRegister(tester);
        expect(find.text('Open the register on the website'), findsNothing);
        expect(opened, isEmpty);
      });
    });

    semanticTest('none yet: an empty state that explains how one is earned, and goes back', (tester) async {
      repo.certificatesValue = [];
      var back = 0;
      await pumpCerts(tester, onBack: () => back++);
      expect(find.text('No certificates yet'), findsOneWidget);
      await tester.tap(find.text('Back to Learning'));
      await tester.pump();
      expect(back, 1);
    });

    semanticTest('certificates that will not load show the API\'s sentence and Try again', (tester) async {
      repo.certificatesError = ApiError('Something went wrong (503). Try again.');
      await pumpCerts(tester);
      expect(find.text("Couldn't load your certificates"), findsOneWidget);
      repo.certificatesError = null;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('ICR-CP-2026-AB12CD34'), findsOneWidget);
    });
  });

  // --- a small phone, long words ----------------------------------------------------------------------------

  group('a 320 dp phone with long names', () {
    const small = Size(320, 568);
    const long = 'A very long name for a programme of the kind a partner institute might well publish on the platform';

    PaperSitting longSitting() => PaperSitting(
      paper: samplePaper(minutes: 90, courseTitle: long),
      questions: [
        for (var i = 0; i < 12; i++)
          ServedQuestion(
            id: 'q${i + 1}',
            prompt:
                'Question ${i + 1}: which of the following statements about whole-life costing, capital planning and the governance of major projects is the most accurate in a large portfolio?',
            options: [
              for (var o = 0; o < 4; o++)
                'Option ${'ABCD'[o]}: a deliberately long answer that runs over several lines on a narrow phone, with a few more words to be sure',
            ],
            type: i == 1 ? QuestionType.multiple : QuestionType.single,
            category: 'A topic with a rather long name indeed',
          ),
      ],
    );

    semanticTest('the exam window, its bars, the palette and the overview do not overflow', (tester) async {
      phone(tester, size: small);
      final c = controllerFor(longSitting());
      await tester.pumpWidget(app(ExamScreen(controller: c, firstName: 'Bharat')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.textContaining('Option A: a deliberately'));
      await tester.pump();
      expect(find.text('Review'), findsOneWidget, reason: 'all three buttons fit on a narrow phone, words and all');
      expect(find.bySemanticsLabel('Flag for review'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Flag for review'));
      await settle(tester);
      expect(find.bySemanticsLabel('Unflag'), findsOneWidget);
      await tapText(tester, 'Next');
      expect(tester.takeException(), isNull);
      await tester.tap(find.bySemanticsLabel('Question palette'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Question palette'), findsOneWidget);
      await tapText(tester, 'Review & submit');
      expect(tester.takeException(), isNull);
      expect(find.text('Assessment overview'), findsOneWidget);
    });

    semanticTest('the failure overlay fits', (tester) async {
      repo.onSubmit = (_, _, _) async =>
          throw ApiError('A long sentence about the connection that could not be made. ' * 3);
      phone(tester, size: small);
      final c = controllerFor(longSitting());
      await tester.pumpWidget(app(ExamScreen(controller: c)));
      await tester.pump();
      await c.submit();
      await settle(tester);
      expect(find.text("Your answers didn't go"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    semanticTest('the brief, open and locked, does not overflow', (tester) async {
      repo.sittingValue = longSitting();
      repo.attemptsValue = [sampleAttempt(percentage: 80)];
      repo.certificatesValue = [sampleCertificate()];
      phone(tester, size: small);
      final brief = BriefController(
        repository: repo,
        ref: const PaperRef(slug: 'cp-foundation', title: 'Foundation'),
        store: store,
        userId: 'u1',
        now: clock.call,
      );
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Builder(
              builder: (context) =>
                  TextButton(onPressed: () => showBriefPage(context, brief), child: const Text('open')),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Take test'), findsOneWidget);
      await scrollTo(tester, find.text('My attempts'));
      expect(tester.takeException(), isNull);
      expect(layoutProblems().where((p) => p.startsWith('clipped')), isEmpty);
    });

    semanticTest('the locked brief, with credits and a price, does not overflow', (tester) async {
      repo.lock = const PaperLock(
        message:
            'Assess your knowledge courses are not included in your plan. Redeem ICR credits for this level (you have 180), or buy it, or invite colleagues to ICR to earn more credits.',
        reason: 'COURSES',
        credits: 180,
        plan: 'A Premium Professional Plus Plan',
      );
      repo.infoValue = samplePaper(courseTitle: long, priceAmount: 49900);
      repo.quoteValue = PaperQuote.fromJson(_quote);
      phone(tester, size: small);
      final brief = BriefController(
        repository: repo,
        ref: const PaperRef(slug: 'cp-foundation', title: 'Foundation'),
        store: store,
        userId: 'u1',
        now: clock.call,
      );
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Builder(
              builder: (context) =>
                  TextButton(onPressed: () => showBriefPage(context, brief), child: const Text('open')),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
      expect(find.text('Redeem 4 credits'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(layoutProblems().where((p) => p.startsWith('clipped')), isEmpty);
    });

    semanticTest('the result, with its certificate, and its review do not overflow', (tester) async {
      phone(tester, size: small);
      final r = sampleResult(percentage: 90, withCertificate: true);
      await tester.pumpWidget(
        app(
          ResultScreen(
            result: r,
            paperName: long,
            certificateEnabled: true,
            firstName: 'Bharat Subramaniam-Venkataraghavan',
            onRetake: () {},
          ),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(layoutProblems().where((p) => p.startsWith('clipped')), isEmpty);
      await tester.ensureVisible(find.text('Review answers'));
      await tester.tap(find.text('Review answers'));
      await settle(tester);
      expect(find.byType(ReviewAnswersScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(layoutProblems().where((p) => p.startsWith('clipped')), isEmpty);
    });

    semanticTest('My attempts and My certificates do not overflow', (tester) async {
      phone(tester, size: small);
      final paper = samplePaper(courseTitle: long);
      repo.attemptsValue = [sampleAttempt(paper: paper, percentage: 55)];
      await tester.pumpWidget(app(MyAttemptsScreen(onBack: () {}, repository: repo)));
      await settle(tester);
      expect(tester.takeException(), isNull);
      repo.certificatesValue = [
        sampleCertificate(provider: long),
        sampleCertificate(id: 'c2', number: 'ICR-A-VERY-LONG-NUMBER-2026-ABCDEFGH', provider: 'Another'),
      ];
      await tester.pumpWidget(
        app(CertificatesScreen(onBack: () {}, repository: repo, holder: 'Bharat Subramaniam-Venkataraghavan')),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('a 360 dp phone', () {
    const size = Size(360, 780);

    semanticTest('the brief, open and locked, fits: the lines, the table, the attempts and the bar', (tester) async {
      Future<void> open() async {
        phone(tester, size: size);
        final brief = BriefController(
          repository: repo,
          ref: const PaperRef(slug: 'cp-foundation', title: 'Foundation'),
          store: store,
          userId: 'u1',
          now: clock.call,
        );
        await tester.pumpWidget(
          app(
            Scaffold(
              body: Builder(
                builder: (context) =>
                    TextButton(onPressed: () => showBriefPage(context, brief), child: const Text('open')),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await settle(tester);
      }

      repo.attemptsValue = [sampleAttempt(id: 'a2', attempt: 2, percentage: 60), sampleAttempt(percentage: 90)];
      repo.certificatesValue = [sampleCertificate()];
      await open();
      expect(tester.takeException(), isNull);
      expect(find.text('Take test'), findsOneWidget);
      expect(layoutProblems().where((p) => p.startsWith('clipped')), isEmpty);
      await scrollTo(tester, find.text('2 attempts recorded'));
      expect(tester.takeException(), isNull);
      expect(layoutProblems().where((p) => p.startsWith('clipped')), isEmpty);

      repo.lock = const PaperLock(message: 'Locked.', reason: 'COURSES', credits: 180, plan: 'Pro Max');
      repo.infoValue = samplePaper(priceAmount: 49900);
      repo.quoteValue = PaperQuote.fromJson(_quote);
      await tester.pumpWidget(const SizedBox.shrink());
      await open();
      expect(find.text('Redeem 4 credits'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(layoutProblems().where((p) => p.startsWith('clipped')), isEmpty);
    });

    semanticTest('the exam window fits: the pill, the strip, the question and all three buttons', (tester) async {
      phone(tester, size: size);
      final c = controllerFor(sampleSitting(questions: 30, difficulty: 'MEDIUM'));
      await tester.pumpWidget(app(ExamScreen(controller: c, firstName: 'Bharat')));
      await tester.pump();
      c.goTo(6);
      c.select(1);
      c.toggleFlag();
      await tester.pump();
      expect(tester.takeException(), isNull);
      for (final b in ['Finish', 'Review', 'Next']) {
        expect(find.text(b), findsOneWidget, reason: b);
      }
      expect(find.text('Time Left: 30:00'), findsOneWidget);
      expect(layoutProblems().where((p) => p.startsWith('clipped')), isEmpty);

      c.goTo(29);
      await tester.pump();
      expect(find.text('Next'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(layoutProblems().where((p) => p.startsWith('clipped')), isEmpty);
    });
  });

  // --- the whole way through ------------------------------------------------------------------------------

  group('openPaper', () {
    semanticTest('brief, exam, result and Retake, end to end', (tester) async {
      phone(tester);
      repo.sittingValue = sampleSitting(questions: 2);
      repo.defaultResult = sampleResult(percentage: 50, total: 2);
      var ended = 0;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () async {
                    await openPaper(
                      context,
                      const PaperRef(slug: 'cp-foundation', title: 'Foundation'),
                      repository: repo,
                    );
                    ended++;
                  },
                  child: const Text('sit'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('sit'));
      await settle(tester);
      expect(find.text('Take test'), findsOneWidget);

      await tester.tap(find.text('Take test'));
      await settle(tester);
      expect(find.byType(ExamScreen), findsOneWidget);
      expect(find.text('Capital Planning Foundation'), findsOneWidget);
      expect(find.text('Question 1'), findsOneWidget);
      await tester.tap(find.text('Option B1'));
      await tapText(tester, 'Next');
      await tester.tap(find.text('Option A2'));
      await tester.pump();
      await tapText(tester, 'Next');
      await tester.ensureVisible(find.text('Submit test'));
      await tester.tap(find.text('Submit test'));
      await settle(tester);
      expect(find.text('Test Results'), findsOneWidget);
      expect(repo.submitted.single.map((a) => a.selected), [
        [1],
        [0],
      ]);
      expect(ended, 0, reason: 'the flow is still open');

      await tester.tap(find.text('Retake test'));
      await settle(tester);
      expect(find.text('Retake test'), findsNothing);
      // The result closed and the brief opened again: the retake is the same flow, so the page behind is not told
      // yet (it would read its attempts too early and miss the sitting to come).
      expect(find.text('Assessment details'), findsOneWidget);
      expect(find.text('Take test'), findsOneWidget);
      expect(ended, 0, reason: 'a retake continues the flow');

      await tester.tap(find.text('Back'));
      await settle(tester);
      expect(find.text('Take test'), findsNothing);
      expect(ended, 1, reason: 'openPaper completes when the whole flow, retake included, is closed');
    });

    semanticTest('closing the brief completes openPaper without an exam', (tester) async {
      phone(tester);
      var ended = 0;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () async {
                    await openPaper(
                      context,
                      const PaperRef(slug: 'cp-foundation', title: 'Foundation'),
                      repository: repo,
                    );
                    ended++;
                  },
                  child: const Text('sit'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('sit'));
      await settle(tester);
      await tester.tap(find.text('Back'));
      await settle(tester);
      expect(ended, 1);
      expect(find.byType(ExamScreen), findsNothing);
    });
  });
}

/// The clock text the exam shows for the controller's time left.
String clockText(ExamController c) {
  final d = c.remaining.value;
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

const _quote = {
  'listPaisa': 49900,
  'discountBps': 2500,
  'discountPaisa': 12475,
  'salePaisa': 37425,
  'taxBps': 1800,
  'taxPaisa': 6737,
  'totalPaisa': 44162,
  'payable': true,
  'alreadyOpen': false,
  'credits': 4,
  'rupeesPerCredit': 100,
};
