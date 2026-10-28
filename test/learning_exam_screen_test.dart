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
import 'package:icr_mobile/features/learning_exam/brief_sheet.dart';
import 'package:icr_mobile/features/learning_exam/certificate_view.dart';
import 'package:icr_mobile/features/learning_exam/certificates_screen.dart';
import 'package:icr_mobile/features/learning_exam/exam_controller.dart';
import 'package:icr_mobile/features/learning_exam/exam_models.dart';
import 'package:icr_mobile/features/learning_exam/exam_progress_store.dart';
import 'package:icr_mobile/features/learning_exam/exam_screen.dart';
import 'package:icr_mobile/features/learning_exam/exam_services.dart';
import 'package:icr_mobile/features/learning_exam/my_attempts_screen.dart';
import 'package:icr_mobile/features/learning_exam/open_paper.dart';
import 'package:icr_mobile/features/learning_exam/result_screen.dart';

import 'helpers/fonts.dart';
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
    /// A button that opens the brief and records what the sheet hands back.
    Future<List<ExamStart?>> openBrief(WidgetTester tester, BriefController brief) async {
      phone(tester);
      final results = <ExamStart?>[];
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () async => results.add(await showBriefSheet(context, brief)),
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

    semanticTest('an open paper: what it is, the numbers, the default instructions, and Take test', (tester) async {
      repo.sittingValue = sampleSitting(
        paper: samplePaper(minutes: 45, questions: 5, pass: 70, description: 'A short paper.'),
      );
      final results = await openBrief(tester, briefFor());

      expect(find.text('Capital Planning'), findsOneWidget, reason: 'the programme is the heading');
      expect(find.text('FOUNDATION LEVEL'), findsOneWidget);
      expect(find.text('Assessment'), findsOneWidget);
      expect(find.text('Certificate on a qualifying pass'), findsOneWidget);
      expect(find.text('A short paper.'), findsOneWidget);
      expect(find.text('Test parameters'), findsOneWidget);
      expect(find.text('QUESTIONS'), findsOneWidget);
      expect(find.text('DURATION'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text('Passing criterion'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget);
      expect(find.text('Unlimited'), findsOneWidget);
      expect(find.text('Timed'), findsOneWidget, reason: 'the default instructions');
      expect(find.text('Take test'), findsOneWidget);

      await tester.tap(find.text('Take test'));
      await settle(tester);
      expect(results, hasLength(1));
      expect(results.single!.sitting.questions, hasLength(5));
      expect(results.single!.resume, isNull);
      expect(find.text('Take test'), findsNothing, reason: 'the sheet closed');
    });

    semanticTest('two quick taps on Take test start one sitting and do not close the screen under the sheet', (
      tester,
    ) async {
      final results = await openBrief(tester, briefFor());
      await tester.tap(find.text('Take test'));
      await tester.tap(find.text('Take test'));
      await settle(tester);
      expect(results, hasLength(1));
      expect(find.text('open brief'), findsOneWidget, reason: 'the page that opened the brief is still there');
    });

    semanticTest('a priced paper the member now holds says it is unlocked', (tester) async {
      repo.sittingValue = sampleSitting(paper: samplePaper(priceAmount: 49900));
      await openBrief(tester, briefFor());
      expect(find.text('Unlocked for you'), findsOneWidget);
      expect(find.text('Take test'), findsOneWidget);
    });

    semanticTest('a free paper carries no such pill', (tester) async {
      await openBrief(tester, briefFor());
      expect(find.text('Unlocked for you'), findsNothing);
    });

    semanticTest('a paper\'s own instructions take the place of the defaults', (tester) async {
      repo.sittingValue = sampleSitting(paper: samplePaper(instructions: 'Bring a calculator. No notes.'));
      await openBrief(tester, briefFor());
      expect(find.text('Bring a calculator. No notes.'), findsOneWidget);
      expect(find.text('Timed'), findsNothing);
    });

    semanticTest('a mock set is headed by its own name and says it is a mock exam', (tester) async {
      repo.sittingValue = sampleSitting(
        paper: samplePaper(slug: 'bemp-1', title: 'Set 1', kind: PaperKind.mock, certificate: false),
      );
      await openBrief(tester, briefFor(slug: 'bemp-1'));
      expect(find.text('ASHRAE BEMP – Set 1'), findsOneWidget);
      expect(find.text('Mock exam'), findsWidgets);
      expect(find.text('Certificate on a qualifying pass'), findsNothing);
    });

    semanticTest('a member who has sat it sees the best score and Retake test; a held certificate opens', (
      tester,
    ) async {
      repo.attemptsValue = [sampleAttempt(id: 'a2', attempt: 2, percentage: 60), sampleAttempt(percentage: 90)];
      repo.certificatesValue = [sampleCertificate()];
      await openBrief(tester, briefFor());
      expect(find.text('Your best so far is 90% over 2 attempts.'), findsOneWidget);
      expect(find.text('Retake test'), findsOneWidget);
      expect(find.text('You already hold this certificate: ICR-CP-2026-AB12CD34.'), findsOneWidget);

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
      expect(find.text('1 · 1 used'), findsOneWidget);
      await tester.tap(find.text('Retake test'));
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
      repo.sittingError = null;
      await tapText(tester, 'Try again');
      expect(find.text('Take test'), findsOneWidget);
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

      semanticTest('shows the API\'s sentence, the three ways in, and no Start', (tester) async {
        await openBrief(tester, briefFor());
        expect(find.text('This assessment level is locked'), findsOneWidget);
        expect(find.textContaining('are not included in your plan'), findsWidgets);
        expect(find.text('Redeem ICR credits'), findsOneWidget);
        expect(find.textContaining('It takes 4 ICR credits'), findsOneWidget);
        expect(find.textContaining('You have 180'), findsOneWidget);
        expect(find.text('Redeem 4 credits'), findsOneWidget);
        expect(find.text('Buy this level'), findsOneWidget);
        expect(find.text('₹374.25'), findsOneWidget);
        expect(find.text('₹499'), findsOneWidget);
        expect(find.text('25% off'), findsOneWidget);
        expect(find.text('Open with my plan'), findsNothing, reason: 'the plan has no place left');
        expect(find.text('Take test'), findsNothing);
        expect(find.text('Back'), findsOneWidget);
      });

      semanticTest('Redeem asks first; Cancel changes nothing; Redeem spends the credits and opens the paper', (
        tester,
      ) async {
        await openBrief(tester, briefFor());
        await tester.ensureVisible(find.text('Redeem 4 credits'));
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

      semanticTest('too few credits: Redeem is off and says how many are missing', (tester) async {
        repo.lock = const PaperLock(message: 'Locked.', reason: 'COURSES', credits: 1);
        await openBrief(tester, briefFor());
        expect(find.textContaining('You need 3 more.'), findsOneWidget);
        await tester.ensureVisible(find.text('Redeem 4 credits'));
        await tester.tap(find.text('Redeem 4 credits'), warnIfMissed: false);
        await settle(tester);
        expect(find.text('Redeem 4 credits?'), findsNothing);
      });

      semanticTest('a refused redemption shows the API\'s sentence and leaves the paper locked', (tester) async {
        repo.redeemError = ApiError(
          'This level takes 4 ICR credits, and you have 2.',
          statusCode: 403,
          code: 'NO_CREDIT_LEFT',
        );
        await openBrief(tester, briefFor());
        await tester.ensureVisible(find.text('Redeem 4 credits'));
        await tester.tap(find.text('Redeem 4 credits'));
        await settle(tester);
        await tester.tap(find.text('Redeem'));
        await settle(tester);
        expect(find.text('This level takes 4 ICR credits, and you have 2.'), findsOneWidget);
        expect(find.text('This assessment level is locked'), findsOneWidget);
      });

      semanticTest('Pay on the website opens the paper\'s page there; payment unavailable is off', (tester) async {
        await openBrief(tester, briefFor());
        await tester.ensureVisible(find.text('Pay on the website'));
        await tester.tap(find.text('Pay on the website'));
        await settle(tester);
        expect(opened.single.toString(), 'https://icr.test/learning/assessment/cp/cp-foundation');
      });

      semanticTest('payment that is not available cannot be started', (tester) async {
        repo.quoteValue = PaperQuote.fromJson({..._quote, 'payable': false});
        await openBrief(tester, briefFor());
        await tester.ensureVisible(find.text('Payment is not available'));
        await tester.tap(find.text('Payment is not available'), warnIfMissed: false);
        await settle(tester);
        expect(opened, isEmpty);
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

      semanticTest('Back closes the sheet', (tester) async {
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
        await tester.ensureVisible(find.text('Open with my plan'));
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
      });
    });
  });

  // --- the exam window ------------------------------------------------------------------------------------

  group('the exam window', () {
    semanticTest('shows the paper, the question, its options by letter, the clock and where you are', (tester) async {
      await pumpExam(tester, sitting: sampleSitting(paper: samplePaper(minutes: 30), questions: 5));
      expect(find.text('Capital Planning – Foundation'), findsOneWidget);
      expect(find.text('Question 1 of 5 · 0 answered'), findsOneWidget);
      expect(find.text('30:00'), findsOneWidget);
      expect(find.text('QUESTION 1'), findsOneWidget);
      expect(find.text('Question number 1: what is right?'), findsOneWidget);
      for (final l in ['A', 'B', 'C', 'D']) {
        expect(find.text(l), findsOneWidget);
      }
      expect(find.text('Option B1'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(bar.value, closeTo(1 / 5, 1e-9));
    });

    semanticTest('tapping an option selects it, and tapping another moves the choice', (tester) async {
      final c = await pumpExam(tester);
      await tester.tap(find.text('Option B1'));
      await tester.pump();
      expect(c.picked('q1'), [1]);
      expect(find.text('Question 1 of 5 · 1 answered'), findsOneWidget);
      expect(optionChecked(tester, 'Option B1'), isTrue);
      expect(optionChecked(tester, 'Option C1'), isFalse);
      await tester.tap(find.text('Option C1'));
      await tester.pump();
      expect(c.picked('q1'), [2]);
      expect(optionChecked(tester, 'Option B1'), isFalse);
      expect(optionChecked(tester, 'Option C1'), isTrue);
      expect(find.text('Question 1 of 5 · 1 answered'), findsOneWidget);
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

    semanticTest(
      'Next and Previous move through the paper and stop at the ends; the last question offers the overview',
      (tester) async {
        await pumpExam(tester, sitting: sampleSitting(questions: 3));
        final previous = find.text('Previous');
        await tester.tap(previous, warnIfMissed: false);
        await tester.pump();
        expect(find.text('QUESTION 1'), findsOneWidget, reason: 'Previous is off on the first question');

        await tapText(tester, 'Next');
        expect(find.text('QUESTION 2'), findsOneWidget);
        expect(find.text('Question number 2: what is right?'), findsOneWidget);
        await tapText(tester, 'Previous');
        expect(find.text('QUESTION 1'), findsOneWidget);
        await tapText(tester, 'Next');
        await tapText(tester, 'Next');
        expect(find.text('QUESTION 3'), findsOneWidget);
        expect(find.text('Next'), findsNothing);
        expect(find.text('Review & submit'), findsOneWidget);
        await tapText(tester, 'Review & submit');
        expect(find.text('Assessment overview'), findsOneWidget);
      },
    );

    semanticTest('an answer is still there after going away and coming back', (tester) async {
      await pumpExam(tester);
      await tester.tap(find.text('Option D1'));
      await tester.pump();
      await tapText(tester, 'Next');
      await tapText(tester, 'Previous');
      expect(optionChecked(tester, 'Option D1'), isTrue);
    });

    semanticTest('Flag for review flags the question, shows a flag, and Unflag takes it off', (tester) async {
      final c = await pumpExam(tester);
      expect(find.text('Flag for review'), findsOneWidget);
      await tapText(tester, 'Flag for review');
      expect(c.isFlagged(0), isTrue);
      expect(find.text('Flagged'), findsOneWidget);
      expect(find.text('Unflag'), findsOneWidget);
      await tapText(tester, 'Unflag');
      expect(c.isFlagged(0), isFalse);
      expect(find.text('Flagged'), findsNothing);
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
      expect(find.text('Question 1 of 5 · 0 answered'), findsOneWidget);
    });

    semanticTest('the palette shows every question by state, and a tap goes there', (tester) async {
      final c = await pumpExam(tester, sitting: sampleSitting(questions: 6));
      await tester.tap(find.text('Option B1'));
      await tapText(tester, 'Next');
      await tapText(tester, 'Flag for review');
      await tapText(tester, 'Next');
      await tester.tap(find.text('Option A3'));
      await tapText(tester, 'Flag for review');

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

      await tester.tap(find.text('5'));
      await settle(tester);
      expect(find.text('Question palette'), findsNothing, reason: 'the sheet closes on a jump');
      expect(find.text('QUESTION 5'), findsOneWidget);
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
      await tapText(tester, 'Flag for review');

      await tapText(tester, 'Submit');
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
      expect(find.text('QUESTION 5'), findsOneWidget);
    });

    semanticTest('Back to test closes the overview and sends nothing', (tester) async {
      await pumpExam(tester);
      await tapText(tester, 'Submit');
      await tester.ensureVisible(find.text('Back to test'));
      await tapText(tester, 'Back to test');
      expect(find.text('Assessment overview'), findsNothing);
      expect(find.text('QUESTION 1'), findsOneWidget);
      expect(repo.submitted, isEmpty);
    });

    semanticTest('Submit test sends the answers and shows the result', (tester) async {
      repo.defaultResult = sampleResult(percentage: 80);
      final c = await pumpExam(tester, sitting: sampleSitting(questions: 5));
      await tester.tap(find.text('Option B1'));
      await tester.pump();
      await tapText(tester, 'Submit');
      await tester.ensureVisible(find.text('Submit test'));
      await tester.tap(find.text('Submit test'));
      await settle(tester);

      expect(repo.submitted, hasLength(1));
      expect(repo.submitted.single, hasLength(5), reason: 'every question goes, answered or not');
      expect(repo.submitted.single.first.selected, [1]);
      expect(c.phase, ExamPhase.done);
      expect(find.text('Your result'), findsOneWidget);
      expect(find.text('Well done, Bharat'), findsOneWidget);
      expect(find.text('ExamScreen'), findsNothing);
      expect(find.byType(ExamScreen), findsNothing, reason: 'the exam is replaced, so Back cannot return to it');
      expect(await store.load('u1', 'cp-foundation'), isNull);
    });

    semanticTest('two quick taps on Submit test send one sitting and leave the exam to the result', (tester) async {
      await pumpExam(tester);
      await tester.tap(find.text('Option B1'));
      await tester.pump();
      await tapText(tester, 'Submit');
      await tester.ensureVisible(find.text('Submit test'));
      await tester.tap(find.text('Submit test'));
      await tester.tap(find.text('Submit test'));
      await settle(tester);
      expect(repo.submitted, hasLength(1));
      expect(find.text('Your result'), findsOneWidget);
    });

    semanticTest('two quick taps on a palette number go to that question once and leave the exam open', (tester) async {
      final c = await pumpExam(tester, sitting: sampleSitting(questions: 6));
      await tester.tap(find.bySemanticsLabel('Question palette'));
      await settle(tester);
      await tester.tap(find.text('4'));
      await tester.tap(find.text('4'));
      await settle(tester);
      expect(find.byType(ExamScreen), findsOneWidget);
      expect(c.current, 3);
    });

    semanticTest('the clock turns red under five minutes and shows the time left', (tester) async {
      final c = await pumpExam(tester, sitting: sampleSitting(paper: samplePaper(minutes: 6)));
      Color clockColor() => tester.widget<Text>(find.text(clockText(c))).style!.color!;
      expect(clockColor(), isNot(const Color(0xFFBA1A1A)));
      clock.advance(const Duration(seconds: 61));
      c.tick();
      await tester.pump();
      expect(find.text('04:59'), findsOneWidget);
      expect(clockColor(), const Color(0xFFBA1A1A));
    });

    semanticTest('at zero the answers are sent for the candidate and the result shows', (tester) async {
      repo.defaultResult = sampleResult(percentage: 40);
      final c = await pumpExam(tester, sitting: sampleSitting(paper: samplePaper(minutes: 1)));
      await tester.tap(find.text('Option C1'));
      await tester.pump();
      clock.advance(const Duration(seconds: 59));
      await tester.pump(const Duration(seconds: 59));
      expect(find.text('00:01'), findsOneWidget);
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
      expect(find.text('Your result'), findsOneWidget);
      expect(find.text('Not quite there yet, Bharat'), findsOneWidget);
    });

    semanticTest('the clock running out under an open overview closes it and sends', (tester) async {
      await pumpExam(tester, sitting: sampleSitting(paper: samplePaper(minutes: 1)));
      await tapText(tester, 'Submit');
      expect(find.text('Assessment overview'), findsOneWidget);
      clock.advance(const Duration(minutes: 2));
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      expect(find.text('Assessment overview'), findsNothing);
      expect(repo.submitted, hasLength(1));
      expect(find.text('Your result'), findsOneWidget);
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
      await tapText(tester, 'Submit');
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
      expect(find.text('Your result'), findsOneWidget);
    });

    semanticTest('after a failed send with time left, Back to the test returns to the paper with the answers', (
      tester,
    ) async {
      repo.onSubmit = (_, _, _) async => throw ApiError('offline');
      final c = await pumpExam(tester);
      await tester.tap(find.text('Option B1'));
      await tester.pump();
      await tapText(tester, 'Submit');
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
      await tapText(tester, 'Submit');
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
      expect(find.text('QUESTION 2'), findsOneWidget);
      expect(optionChecked(tester, 'Option A2'), isTrue);
      expect(find.text('27:00'), findsOneWidget);
      expect(find.text('Question 2 of 5 · 2 answered'), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      await tester.pump();
      await tapText(tester, 'Previous');
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
      expect(find.text('QUESTION 4'), findsOneWidget);
      expect(optionChecked(tester, 'Option B4'), isTrue);
      expect(find.text('21:00'), findsOneWidget);
      expect(find.text('Question 4 of 5 · 2 answered'), findsOneWidget);
      await tapText(tester, 'Previous');
      await tapText(tester, 'Previous');
      expect(find.text('QUESTION 2'), findsOneWidget);
      expect(find.text('Flagged'), findsOneWidget, reason: 'the flag on question 2 came back too');
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
      expect(find.text('Your result'), findsOneWidget);
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
      expect(find.text('19:00'), findsOneWidget);
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
      expect(find.text('Your result'), findsOneWidget);
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
    }) async {
      phone(tester);
      await tester.pumpWidget(
        launched(
          ResultScreen(
            result: result,
            paperName: 'Capital Planning – Foundation',
            certificateEnabled: certifying,
            firstName: firstName,
            onRetake: onRetake,
            eyebrowSuffix: suffix,
          ),
        ),
      );
      await tester.tap(find.text('start'));
      await settle(tester);
    }

    semanticTest('a pass on a certifying paper: the score, the chips, the certificate, and the breakdown', (
      tester,
    ) async {
      await pumpResult(tester, sampleResult(percentage: 90, withCertificate: true), suffix: ' · 18 Oct 2026');
      expect(find.text('Outstanding result, Bharat'), findsOneWidget);
      expect(find.text('CAPITAL PLANNING – FOUNDATION · 18 OCT 2026'), findsOneWidget);
      expect(
        find.textContaining('You passed Capital Planning – Foundation with 90%, against a pass mark of 70%.'),
        findsOneWidget,
      );
      expect(find.text('90'), findsOneWidget);
      expect(find.text('Accuracy 90%'), findsOneWidget);
      expect(find.textContaining('Time taken 12m 04s'), findsOneWidget);
      expect(find.text('5 of 5 correct'), findsOneWidget);
      expect(find.text('Passed'), findsOneWidget);
      expect(find.text('Certificate issued: ICR-CP-2026-AB12CD34, on attempt 2.'), findsOneWidget);
      expect(find.text('Correct'), findsWidgets);
      expect(find.text('Incorrect'), findsWidgets);
    });

    semanticTest('Passed with under 85% reads Well done', (tester) async {
      await pumpResult(tester, sampleResult(percentage: 80));
      expect(find.text('Well done, Bharat'), findsOneWidget);
    });

    semanticTest('a miss on a certifying paper says how far it was from the pass mark', (tester) async {
      await pumpResult(tester, sampleResult(percentage: 40));
      expect(find.text('Not quite there yet, Bharat'), findsOneWidget);
      expect(find.text('Not passed · 70% to pass'), findsOneWidget);
      expect(find.textContaining('the pass mark is 70%'), findsOneWidget);
      expect(find.textContaining('Certificate issued'), findsNothing);
    });

    semanticTest('a practice paper just says what was scored, and the pass mark in neutral words', (tester) async {
      await pumpResult(tester, sampleResult(percentage: 60), certifying: false);
      expect(find.text('You scored 60%'), findsOneWidget);
      expect(find.text('Below the 70% pass mark'), findsOneWidget);
      expect(find.textContaining('A practice paper'), findsOneWidget);
    });

    semanticTest('a practice paper above the pass mark still says Passed', (tester) async {
      await pumpResult(tester, sampleResult(percentage: 90), certifying: false);
      expect(find.text('Passed'), findsOneWidget);
    });

    semanticTest('without a name the headline is bare', (tester) async {
      await pumpResult(tester, sampleResult(percentage: 90), firstName: null);
      expect(find.text('Outstanding result'), findsOneWidget);
    });

    semanticTest('every question is worked through: the key, the pick, and the explanation', (tester) async {
      await pumpResult(tester, sampleResult(percentage: 40, total: 5));
      await scrollTo(tester, find.text('Review your answers'));
      expect(find.text('Review your answers'), findsOneWidget);
      // sampleResult(40%) is 2 right (q1, q2), q3 wrong (picked C), q4 and q5 skipped.
      expect(find.text('QUESTION 1 OF 5 · BUDGETING'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Question number 3: what is right?'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Question number 3: what is right?'), findsOneWidget);
      expect(find.text('Because B is the answer to number 3.'), findsOneWidget);
      expect(find.text('Rationale'), findsWidgets);
      expect(find.text('Correct answer'), findsWidgets);
      expect(find.text('Your answer'), findsWidgets);
    });

    semanticTest('the filters narrow the review to incorrect, skipped or correct questions', (tester) async {
      await pumpResult(tester, sampleResult(percentage: 40, total: 5));
      await scrollTo(tester, find.text('All 5'));
      expect(find.text('All 5'), findsOneWidget);
      expect(find.text('Incorrect 1'), findsOneWidget);
      expect(find.text('Skipped 2'), findsOneWidget);
      expect(find.text('Correct 2'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Incorrect 1'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Incorrect 1'));
      await settle(tester);
      expect(find.text('Question number 3: what is right?'), findsOneWidget);
      expect(find.text('Question number 1: what is right?'), findsNothing);
      expect(find.text('QUESTION 3 OF 5 · BUDGETING'), findsOneWidget, reason: 'it keeps its own number');

      await tester.tap(find.text('Skipped 2'));
      await settle(tester);
      expect(find.text('Question number 4: what is right?'), findsOneWidget);
      expect(find.text('Question number 3: what is right?'), findsNothing);

      await tester.tap(find.text('All 5'));
      await settle(tester);
      expect(find.text('Question number 1: what is right?'), findsOneWidget);
    });

    semanticTest('a result by topic appears when the questions carry topics', (tester) async {
      await pumpResult(tester, sampleResult(percentage: 40, total: 5));
      expect(find.text('By topic'), findsOneWidget);
      expect(find.text('Budgeting'), findsOneWidget);
      expect(find.text('Governance'), findsOneWidget);
    });

    semanticTest('questions removed from the bank since the sitting are counted, not hidden', (tester) async {
      final r = sampleResult(percentage: 80, total: 5);
      final fewer = AttemptResult(attempt: r.attempt, review: r.review.take(3).toList());
      await pumpResult(tester, fewer);
      expect(find.textContaining('2 questions from this sitting have since been removed'), findsOneWidget);
    });

    semanticTest('View certificate opens the certificate', (tester) async {
      await pumpResult(tester, sampleResult(percentage: 90, withCertificate: true));
      await tester.tap(find.text('View certificate').last);
      await settle(tester);
      expect(find.text('Certificate of Knowledge Assessment'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });

    semanticTest('Retake closes the result and starts the paper again; Back just closes', (tester) async {
      var retaken = 0;
      await pumpResult(tester, sampleResult(percentage: 40), onRetake: () => retaken++);
      await tester.tap(find.text('Retake test'));
      await settle(tester);
      expect(retaken, 1);
      expect(find.byType(ResultScreen), findsNothing);

      await pumpResult(tester, sampleResult(percentage: 40), onRetake: () => retaken++);
      await tester.tap(find.text('Back'));
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

    semanticTest('with nothing to retake there is only Back', (tester) async {
      await pumpResult(tester, sampleResult(percentage: 40));
      expect(find.text('Retake test'), findsNothing);
      expect(find.text('Back'), findsOneWidget);
    });

    semanticTest('with a certificate the bar offers Retake beside View certificate', (tester) async {
      var retaken = 0;
      await pumpResult(tester, sampleResult(percentage: 90, withCertificate: true), onRetake: () => retaken++);
      await tester.tap(find.text('Retake'));
      await settle(tester);
      expect(retaken, 1);
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

    semanticTest('the PDF stays on the website; the register and LinkedIn open there too', (tester) async {
      await pumpDetail(tester, sampleCertificate());
      for (final label in ['Download PDF on the website', 'Check it in the register', 'Add to LinkedIn']) {
        await tester.ensureVisible(find.text(label));
        await tester.pump();
        await tester.tap(find.text(label));
        await settle(tester);
      }
      expect(opened[0].toString(), endsWith('/learning/certificates/cp-foundation'));
      expect(opened[1].toString(), endsWith('/learning/verify?id=ICR-CP-2026-AB12CD34'));
      expect(opened[2].host, 'www.linkedin.com');
      expect(opened[2].queryParameters['name'], 'Capital Planning');
      expect(opened[2].queryParameters['certId'], 'ICR-CP-2026-AB12CD34');
      expect(opened[2].queryParameters['issueYear'], '2026');
      expect(opened[2].queryParameters['issueMonth'], '8');
      expect(opened[2].queryParameters['certUrl'], contains('/learning/verify?id=ICR-CP-2026-AB12CD34'));
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
      expect(find.text('Your result'), findsOneWidget);
      expect(find.text('CAPITAL PLANNING – FOUNDATION · 20 OCT 2026'), findsOneWidget);
      expect(find.text('Outstanding result'), findsOneWidget);
      expect(find.text('Certificate issued: ICR-CP-2026-AB12CD34, on attempt 2.'), findsOneWidget);
      await scrollTo(tester, find.text('Review your answers'));
      expect(find.text('Review your answers'), findsOneWidget);
      expect(repo.calls, contains('attempt a3'));
    });

    semanticTest('Retake on an old result opens that paper brief', (tester) async {
      await pumpAttempts(tester);
      await tester.tap(find.text('ASHRAE BEMP – Set 1'));
      await settle(tester);
      await tester.tap(find.text('Retake test'));
      await settle(tester);
      expect(find.text('Test parameters'), findsOneWidget);
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
      await scrollTo(tester, find.text('Review your answers'));
      expect(find.text('Review your answers'), findsOneWidget);
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

      semanticTest('the website register is one tap away', (tester) async {
        await openRegister(tester);
        await tester.ensureVisible(find.text('Open the register on the website'));
        await tester.tap(find.text('Open the register on the website'));
        await settle(tester);
        expect(opened.single.toString(), endsWith('/learning/verify'));
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
      expect(find.text('Flag'), findsOneWidget, reason: 'the shortened label on a narrow phone');
      await tapText(tester, 'Flag');
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
                  TextButton(onPressed: () => showBriefSheet(context, brief), child: const Text('open')),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Retake test'), findsOneWidget);
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
                  TextButton(onPressed: () => showBriefSheet(context, brief), child: const Text('open')),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
      expect(find.text('Redeem 4 credits'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    semanticTest('the result, with its review and certificate, does not overflow', (tester) async {
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
      await scrollTo(tester, find.text('Review your answers'));
      expect(tester.takeException(), isNull);
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
      expect(find.text('Question 1 of 2 · 0 answered'), findsOneWidget);
      await tester.tap(find.text('Option B1'));
      await tapText(tester, 'Next');
      await tester.tap(find.text('Option A2'));
      await tester.pump();
      await tapText(tester, 'Review & submit');
      await tester.ensureVisible(find.text('Submit test'));
      await tester.tap(find.text('Submit test'));
      await settle(tester);
      expect(find.text('Your result'), findsOneWidget);
      expect(repo.submitted.single.map((a) => a.selected), [
        [1],
        [0],
      ]);
      expect(ended, 0, reason: 'the flow is still open');

      await tester.tap(find.text('Retake test'));
      await settle(tester);
      expect(find.text('Retake test'), findsNothing);
      // The result closed and the brief opened again.
      expect(find.text('Test parameters'), findsOneWidget);
      expect(find.text('Take test'), findsOneWidget);
      expect(ended, 1, reason: 'openPaper completes when the flow is closed');
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
      await tester.tapAt(const Offset(10, 10));
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
