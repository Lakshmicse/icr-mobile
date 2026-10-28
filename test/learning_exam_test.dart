// The exam flow's logic: what the API sends and receives, the exam's clock and answers, sending them, and the
// brief's reading of what a member may do. Screens are in learning_exam_screen_test.dart; the API itself in
// test/live/learning_exam_live_test.dart.
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/learning_exam/attempts_controller.dart';
import 'package:icr_mobile/features/learning_exam/brief_controller.dart';
import 'package:icr_mobile/features/learning_exam/certificates_controller.dart';
import 'package:icr_mobile/features/learning_exam/demo_exam_repository.dart';
import 'package:icr_mobile/features/learning_exam/exam_controller.dart';
import 'package:icr_mobile/features/learning_exam/exam_format.dart';
import 'package:icr_mobile/features/learning_exam/exam_models.dart';
import 'package:icr_mobile/features/learning_exam/exam_progress_store.dart';
import 'package:icr_mobile/features/learning_exam/exam_repository.dart';
import 'package:icr_mobile/features/learning_exam/qr_code.dart';

import 'learning_exam_fakes.dart';

Map<String, dynamic> _map(Object o) => o as Map<String, dynamic>;

void main() {
  group('what the API sends', () {
    test('the recorded sitting of Capital Planning - Foundation reads as the API sent it', () {
      final s = PaperSitting.fromJson(_map(recorded('sitting_cp_foundation')));
      expect(s.questions, hasLength(10));
      expect(s.paper.slug, 'capital-planning-foundation');
      expect(s.paper.kind, PaperKind.assessment);
      expect(s.paper.durationMinutes, 50);
      expect(s.paper.passPercentage, 70);
      expect(s.paper.questionCount, 10);
      expect(s.paper.totalMarks, 10);
      expect(s.paper.attemptLimit, isNull);
      expect(s.paper.certificateEnabled, isTrue);
      expect(s.paper.name, 'Capital Planning – Foundation');
      expect(s.paper.levelLabel, 'Foundation');
      expect(s.paper.sitePath, '/learning/assessment/cp/capital-planning-foundation');
      expect(s.questions.first.options, hasLength(4));
      expect(s.questions.first.category, 'Capital planning basics');
      expect(s.questions.every((q) => !q.multiple), isTrue);
    });

    test('a mock set carries its subject, no level, and its two multiple-choice questions', () {
      final s = PaperSitting.fromJson(_map(recorded('sitting_bemp')));
      expect(s.paper.kind, PaperKind.mock);
      expect(s.paper.isMock, isTrue);
      expect(s.paper.name, 'ASHRAE BEMP – Set 1');
      expect(s.paper.levelLabel, isNull);
      expect(s.paper.certificateEnabled, isFalse);
      expect(s.paper.sitePath, '/learning/mock-tests/ashrae-bemp/ashrae-bemp-set-1');
      expect(s.questions.where((q) => q.multiple), hasLength(2));
      expect(s.questions[2].multiple, isTrue);
    });

    test('the middle rung of an assessment reads Professional, as on the website', () {
      expect(assessmentLevelLabel('INTERMEDIATE'), 'Professional');
      expect(assessmentLevelLabel('FOUNDATION'), 'Foundation');
      expect(assessmentLevelLabel(null), isNull);
    });

    test('the list entry of a paper reads its served questions from servedQuestions', () {
      final rows = (recorded('papers_list') as List).cast<Map<String, dynamic>>();
      final p = PaperInfo.fromJson(rows.firstWhere((r) => r['slug'] == 'aee-cem-set-1'));
      expect(p.questionCount, 10);
      expect(p.priceAmount, 29900);
      expect(p.topicSlug, 'aee-cem');
    });

    test('the refusal of a paper tells what would open it and what the member holds', () {
      final lock = PaperLock.fromJson(_map(recorded('locked_procurement')));
      expect(lock.code, 'PAPER_LOCKED');
      expect(lock.reason, 'COURSES');
      expect(lock.credits, 180);
      expect(lock.opensTarget, 'COURSE');
      expect(lock.planCanOpen, isFalse, reason: 'the plan has no place left');
      expect(lock.message, contains('Redeem ICR credits'));
      expect(lock.pricingSlug, 'professional');

      final pick = PaperLock.fromJson({
        'message': 'Your plan includes 2 mock exams, and 1 is still free.',
        'reason': 'PICK',
        'opens': {'target': 'MOCK_EXAM', 'id': 't1'},
        'placesLeft': 1,
        'remaining': 5,
      });
      expect(pick.planCanOpen, isTrue);
      expect(pick.placesLeft, 1);
    });

    test('a quote reads the price, the credits and whether it is already open', () {
      final q = PaperQuote.fromJson(_map(recorded('quote_procurement')));
      expect(q.priced, isTrue);
      expect(q.listPaisa, 49900);
      expect(q.salePaisa, 37425);
      expect(q.totalPaisa, 44162);
      expect(q.discountBps, 2500);
      expect(q.credits, 4);
      expect(q.payable, isTrue);
      expect(q.alreadyOpen, isFalse);
    });

    test('the recorded result of the sitting that passed has its certificate and a review of ten', () {
      final r = AttemptResult.fromJson(_map(recorded('result_cp3')));
      expect(r.attempt.percentage, 90);
      expect(r.attempt.passed, isTrue);
      expect(r.attempt.attempt, 3);
      expect(r.attempt.paper!.certificateEnabled, isTrue);
      expect(r.attempt.paper!.name, 'Capital Planning – Foundation');
      expect(r.certificate!.certificateId, 'ICR-CP-2026-DSGNLF01');
      expect(r.certificate!.levelLabel, 'Foundation');
      expect(r.review, hasLength(10));
      expect(r.missing, 0);
      expect(r.review.where((q) => q.outcome == ReviewOutcome.correct), hasLength(9));
      expect(r.review.where((q) => q.outcome == ReviewOutcome.incorrect), hasLength(1));
      expect(r.review.first.explanation, isNotNull);
    });

    test('a sitting with a skipped question reviews it as skipped', () {
      final r = AttemptResult.fromJson(_map(recorded('result_cp1')));
      expect(r.attempt.passed, isFalse);
      expect(r.certificate, isNull);
      final by = <ReviewOutcome, int>{};
      for (final q in r.review) {
        by[q.outcome] = (by[q.outcome] ?? 0) + 1;
      }
      expect(by[ReviewOutcome.correct], r.attempt.correct);
      expect(by[ReviewOutcome.incorrect], r.attempt.wrong);
      expect(by[ReviewOutcome.skipped], r.attempt.unanswered);
    });

    test('a multiple-choice answer is right only when every right option, and no other, is picked, in any order', () {
      ReviewItem item(List<int> picked) => ReviewItem(
        id: 'q',
        prompt: 'p',
        options: const ['a', 'b', 'c', 'd'],
        correctIndexes: const [0, 1, 3],
        selected: picked,
      );
      expect(item([3, 0, 1]).outcome, ReviewOutcome.correct);
      expect(item([0, 1]).outcome, ReviewOutcome.incorrect);
      expect(item([0, 1, 2, 3]).outcome, ReviewOutcome.incorrect);
      expect(item([]).outcome, ReviewOutcome.skipped);
    });

    test('the history lists the member\'s sittings newest first, each with its paper', () {
      final rows = (recorded('attempts_bharat') as List).cast<Map<String, dynamic>>().map(Attempt.fromJson).toList();
      expect(rows, hasLength(4));
      expect(rows.first.paper!.slug, 'capital-planning-foundation');
      expect(rows.first.attempt, 3);
      expect(rows.first.timeTaken, greaterThan(const Duration(minutes: 20)));
      expect(rows.where((a) => a.passed), hasLength(1));
      final adv = rows.firstWhere((a) => a.paper!.slug == 'capital-planning-advanced');
      expect(adv.passed, isFalse);
      expect(adv.paper!.ref.slug, 'capital-planning-advanced');
      expect(adv.paper!.ref.courseCode, 'CP');
    });

    test('a certificate from the register names its holder', () {
      final c = ExamCertificate.fromJson(_map(recorded('certificate_public')));
      expect(c.holder, 'Bharat Buyer');
      expect(c.awardedBy, 'ICR');
      expect(c.clearedAt, isNotNull);
      final mine = ExamCertificate.fromJson(_map((recorded('certificates_bharat') as List).first));
      expect(mine.holder, isNull);
      expect(mine.paperSlug, 'capital-planning-foundation');
    });

    test('a snapshot that does not read back is nothing, not a crash', () {
      expect(ExamSnapshot.tryParse('not json'), isNull);
      expect(ExamSnapshot.tryParse('{"v":2}'), isNull);
      expect(
        ExamSnapshot.tryParse('{"v":1,"sitting":{},"startedAt":1}'),
        isNull,
        reason: 'a sitting with no questions',
      );
    });
  });

  group('words and numbers', () {
    test('the clock reads minutes and seconds, and hours when there are any', () {
      expect(clockLabel(const Duration(minutes: 9, seconds: 5)), '09:05');
      expect(clockLabel(Duration.zero), '00:00');
      expect(clockLabel(const Duration(hours: 1, minutes: 30)), '1:30:00');
      expect(clockLabel(const Duration(seconds: -4)), '00:00');
      expect(clockSpoken(const Duration(minutes: 12, seconds: 4)), '12 minutes 4 seconds');
      expect(clockSpoken(const Duration(seconds: 1)), '1 second');
    });

    test('a sitting\'s length reads like the website\'s', () {
      expect(takenLabel(const Duration(minutes: 12, seconds: 4)), '12m 04s');
      expect(takenLabel(const Duration(milliseconds: 1277000)), '21m 17s');
    });

    test('dates, money and letters', () {
      final d = DateTime(2026, 8, 5, 9, 7);
      expect(dayLabel(d), '5 Aug 2026');
      expect(dateTimeLabel(d), '5 Aug 2026, 09:07');
      expect(longDayLabel(d), '5 August 2026');
      expect(stampLabel(DateTime(2026, 8, 12)), '12-AUG-2026');
      expect(rupees(49900), '₹499');
      expect(rupees(37425), '₹374.25');
      expect(rupees(118000000), '₹11,80,000');
      expect(plural(1, 'attempt'), '1 attempt');
      expect(plural(3, 'attempt'), '3 attempts');
      expect(optionLetter(0), 'A');
      expect(optionLetter(3), 'D');
      expect(optionLetters([3, 0]), 'A, D');
    });
  });

  group('the answers', () {
    late FakeClock clock;
    late FakeExam repo;
    late MemoryExamProgressStore store;
    final made = <ExamController>[];

    ExamController make({PaperSitting? sitting, ExamSnapshot? resume, int minutes = 30, int? multipleAt}) {
      final s =
          sitting ??
          sampleSitting(
            paper: samplePaper(minutes: minutes),
            multipleAt: multipleAt,
          );
      final c = ExamController(
        sitting: s,
        repository: repo,
        store: store,
        userId: 'u1',
        now: clock.call,
        resume: resume,
        tickEvery: const Duration(hours: 1),
      );
      made.add(c);
      return c;
    }

    setUp(() {
      clock = FakeClock();
      repo = FakeExam();
      store = MemoryExamProgressStore();
    });

    tearDown(() {
      for (final c in made) {
        c.dispose();
      }
      made.clear();
    });

    test('a single-choice question takes the one option tapped, and tapping another moves it', () {
      final c = make()..start();
      c.select(1);
      expect(c.picked('q1'), [1]);
      c.select(3);
      expect(c.picked('q1'), [3]);
      c.select(3);
      expect(c.picked('q1'), [3], reason: 'tapping the chosen option again keeps it; Clear takes it off');
    });

    test('a multiple-choice question toggles each option and keeps them in order', () {
      final c = make(multipleAt: 0)..start();
      c.select(2);
      c.select(0);
      expect(c.picked('q1'), [0, 2]);
      c.select(2);
      expect(c.picked('q1'), [0]);
      c.select(0);
      expect(c.picked('q1'), isEmpty);
      expect(c.isAnswered(0), isFalse);
    });

    test('an option that does not exist is ignored', () {
      final c = make()..start();
      c.select(9);
      c.select(-1);
      expect(c.picked('q1'), isEmpty);
    });

    test('Clear takes the response off, and flagging toggles', () {
      final c = make()..start();
      c.select(1);
      c.clearAnswer();
      expect(c.picked('q1'), isEmpty);
      expect(c.isFlagged(0), isFalse);
      c.toggleFlag();
      expect(c.isFlagged(0), isTrue);
      c.toggleFlag();
      expect(c.isFlagged(0), isFalse);
    });

    test('moving through the paper marks questions seen, and the palette tells the five states apart', () {
      final c = make(sitting: sampleSitting(questions: 6))..start();
      // 1: answered. 2: seen, not answered. 3: flagged only. 4: answered and flagged. 5: never opened.
      c.select(0);
      c.goTo(1);
      c.goTo(2);
      c.toggleFlag();
      c.goTo(3);
      c.select(2);
      c.toggleFlag();
      expect(c.markOf(0), QuestionMark.answered);
      expect(c.markOf(1), QuestionMark.notAnswered);
      expect(c.markOf(2), QuestionMark.flagged);
      expect(c.markOf(3), QuestionMark.answeredFlagged);
      expect(c.markOf(4), QuestionMark.notVisited);
      expect(c.markOf(5), QuestionMark.notVisited);
      final n = c.counts;
      expect(n.total, 6);
      expect(n.answered, 2);
      expect(n.skipped, 4);
      expect(n.flagged, 2);
      expect(n.notVisited, 2);
      expect(n.byMark[QuestionMark.answered], 1);
    });

    test('previous and next stop at the ends', () {
      final c = make(sitting: sampleSitting(questions: 3))..start();
      c.previous();
      expect(c.current, 0);
      c.next();
      c.next();
      c.next();
      expect(c.current, 2);
      c.goTo(7);
      expect(c.current, 2);
    });

    test('the payload has every served question, answered or not, with its options in order', () {
      final c = make(sitting: sampleSitting(questions: 4, multipleAt: 1))..start();
      c.select(2);
      c.goTo(1);
      c.select(3);
      c.select(0);
      final p = c.payload;
      expect(p.map((a) => a.questionId), ['q1', 'q2', 'q3', 'q4']);
      expect(p[0].selected, [2]);
      expect(p[1].selected, [0, 3]);
      expect(p[2].selected, isEmpty);
      expect(p[3].toJson(), {'questionId': 'q4', 'selected': <int>[]});
    });

    test('the answers are kept to the store as they change, and read back into a new sitting', () async {
      final a = make(sitting: sampleSitting(questions: 4, multipleAt: 1))..start();
      a.select(1);
      a.goTo(1);
      a.select(0);
      a.select(2);
      a.toggleFlag();
      a.goTo(3);
      await a.flushed();

      final saved = await store.load('u1', 'cp-foundation');
      expect(saved, isNotNull);
      expect(saved!.currentIndex, 3);
      expect(saved.answers['q1'], [1]);
      expect(saved.answers['q2'], [0, 2]);
      expect(saved.flagged, ['q2']);
      expect(saved.startedAt, clock.now);

      clock.advance(const Duration(minutes: 7));
      final b = make(sitting: saved.sitting, resume: saved);
      expect(b.resumed, isTrue);
      expect(b.current, 3);
      expect(b.picked('q2'), [0, 2]);
      expect(b.isFlagged(1), isTrue);
      expect(b.markOf(2), QuestionMark.notVisited, reason: 'question 3 was skipped over, never opened');
      expect(b.startedAt, a.startedAt, reason: 'the clock keeps the original start');
      expect(b.remaining.value, const Duration(minutes: 23));
    });

    test('a snapshot survives being written as text and read back', () async {
      final a = make(multipleAt: 2)..start();
      a.goTo(2);
      a.select(1);
      a.select(3);
      await a.flushed();
      expect(await store.load('u1', 'cp-foundation'), isNotNull);
      final again = ExamSnapshot.tryParse(jsonEncode(a.snapshot().toJson()));
      expect(again, isNotNull);
      expect(again!.sitting.questions[2].multiple, isTrue);
      expect(again.answers['q3'], [1, 3]);
      expect(again.sitting.paper.durationMinutes, 30);
    });

    test('a failing store does not stop the exam', () async {
      final c = ExamController(
        sitting: sampleSitting(),
        repository: repo,
        store: _BrokenStore(),
        userId: 'u1',
        now: clock.call,
        tickEvery: const Duration(hours: 1),
      );
      made.add(c);
      c.start();
      c.select(1);
      await c.flushed();
      expect(c.picked('q1'), [1]);
    });

    test('Leave and discard forgets the saved sitting', () async {
      final c = make()..start();
      c.select(1);
      await c.flushed();
      expect(await store.load('u1', 'cp-foundation'), isNotNull);
      await c.discard();
      expect(await store.load('u1', 'cp-foundation'), isNull);
    });

    test('nothing is writable once the answers are on their way', () async {
      final gate = Completer<AttemptResult>();
      repo.onSubmit = (_, _, _) => gate.future;
      final c = make()..start();
      c.select(1);
      final sent = c.submit();
      expect(c.phase, ExamPhase.submitting);
      c.select(2);
      c.toggleFlag();
      c.goTo(2);
      c.clearAnswer();
      expect(c.picked('q1'), [1]);
      expect(c.isFlagged(0), isFalse);
      expect(c.current, 0);
      gate.complete(sampleResult());
      await sent;
      c.select(3);
      expect(c.picked('q1'), [1]);
    });
  });

  group('sending the answers', () {
    late FakeClock clock;
    late FakeExam repo;
    late MemoryExamProgressStore store;
    final made = <ExamController>[];

    ExamController make({int minutes = 30}) {
      final c = ExamController(
        sitting: sampleSitting(paper: samplePaper(minutes: minutes)),
        repository: repo,
        store: store,
        userId: 'u1',
        now: clock.call,
        tickEvery: const Duration(hours: 1),
      );
      made.add(c);
      return c;
    }

    setUp(() {
      clock = FakeClock();
      repo = FakeExam();
      store = MemoryExamProgressStore();
    });

    tearDown(() {
      for (final c in made) {
        c.dispose();
      }
      made.clear();
    });

    test('Submit sends the sitting, takes the result, and forgets the saved sitting', () async {
      final c = make()..start();
      c.select(1);
      await c.flushed();
      expect(await store.load('u1', 'cp-foundation'), isNotNull);

      final ok = await c.submit();
      expect(ok, isTrue);
      expect(c.phase, ExamPhase.done);
      expect(c.result!.attempt.percentage, 80);
      expect(repo.submitted, hasLength(1));
      expect(repo.submittedStarts.single, c.startedAt);
      expect(repo.submitted.single.first.selected, [1]);
      expect(await store.load('u1', 'cp-foundation'), isNull, reason: 'a sent sitting is not kept');
      expect(c.autoSubmitted, isFalse);
    });

    test('pressing Submit twice sends one sitting', () async {
      final gate = Completer<AttemptResult>();
      repo.onSubmit = (_, _, _) => gate.future;
      final c = make()..start();
      final first = c.submit();
      final second = c.submit();
      await Future<void>.delayed(Duration.zero);
      gate.complete(sampleResult());
      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(repo.submitted, hasLength(1));
      expect(await c.submit(), isTrue, reason: 'after it is done, Submit is a no-op');
      expect(repo.submitted, hasLength(1));
    });

    test('a failed send keeps the answers and the saved sitting, and the next try sends them', () async {
      var tries = 0;
      repo.onSubmit = (_, _, _) async {
        tries++;
        if (tries == 1) throw ApiError("Can't reach ICR right now. Check your connection and try again.");
        return sampleResult();
      };
      final c = make()..start();
      c.select(2);
      c.goTo(1);
      c.select(0);
      await c.flushed();

      expect(await c.submit(), isFalse);
      expect(c.phase, ExamPhase.failed);
      expect(c.error, contains("Can't reach ICR"));
      expect(c.retryable, isTrue);
      expect(c.picked('q1'), [2]);
      expect(c.picked('q2'), [0]);
      expect(await store.load('u1', 'cp-foundation'), isNotNull);

      expect(await c.submit(), isTrue);
      expect(c.phase, ExamPhase.done);
      expect(tries, 2);
      expect(repo.submitted.last.first.selected, [2], reason: 'the retry carries the same answers');
      expect(c.error, isNull);
    });

    test('a retry first looks for the sitting that may have landed, and does not send it twice', () async {
      repo.onSubmit = (_, _, _) async => throw ApiError("Can't reach ICR right now.");
      final c = make()..start();
      c.select(1);
      expect(await c.submit(), isFalse);
      expect(repo.submitted, hasLength(1));

      // The first request had reached the server after all: the sitting is in the history, with our start time.
      final landed = sampleAttempt(id: 'landed', startedAt: c.startedAt);
      repo.attemptsValue = [landed];
      repo.results['landed'] = sampleResult(percentage: 100);
      expect(await c.submit(), isTrue);
      expect(repo.submitted, hasLength(1), reason: 'no second attempt is created');
      expect(repo.calls, contains('attempt landed'));
      expect(c.result!.attempt.percentage, 100);
    });

    test('a refusal that cannot be undone is not offered a retry', () async {
      repo.onSubmit = (_, _, _) async =>
          throw ApiError('You have used all 3 attempts for this paper.', statusCode: 403);
      final c = make()..start();
      expect(await c.submit(), isFalse);
      expect(c.error, contains('used all 3 attempts'));
      expect(c.retryable, isFalse);
    });

    test('a server error can be tried again', () async {
      repo.onSubmit = (_, _, _) async => throw ApiError('Something went wrong (503).', statusCode: 503);
      final c = make()..start();
      await c.submit();
      expect(c.retryable, isTrue);
    });

    test('after a failed send with time left, the candidate can go back to the paper', () async {
      repo.onSubmit = (_, _, _) async => throw ApiError('offline');
      final c = make()..start();
      await c.submit();
      expect(c.phase, ExamPhase.failed);
      expect(c.reopen(), isTrue);
      expect(c.phase, ExamPhase.running);
      c.select(3);
      expect(c.picked('q1'), [3]);
    });

    testWidgets('the clock counts down by the wall clock and submits what is answered at zero, once', (tester) async {
      final c = make(minutes: 2)..start();
      c.select(1);
      c.goTo(1);
      c.select(2);
      expect(c.remaining.value, const Duration(minutes: 2));

      clock.advance(const Duration(seconds: 30));
      c.tick();
      expect(c.remaining.value, const Duration(seconds: 90));
      expect(repo.submitted, isEmpty);

      clock.advance(const Duration(seconds: 89));
      c.tick();
      expect(c.remaining.value, const Duration(seconds: 1));
      expect(c.phase, ExamPhase.running);
      expect(c.lowTime, isTrue);

      clock.advance(const Duration(seconds: 1));
      c.tick();
      await tester.pump();
      expect(c.remaining.value, Duration.zero);
      expect(c.phase, ExamPhase.done);
      expect(c.autoSubmitted, isTrue);
      expect(repo.submitted, hasLength(1));
      expect(repo.submitted.single[0].selected, [1]);
      expect(repo.submitted.single[1].selected, [2]);

      c.tick();
      clock.advance(const Duration(minutes: 5));
      c.tick();
      expect(repo.submitted, hasLength(1), reason: 'it was sent once, however many ticks follow');
    });

    testWidgets('the periodic timer drives the same countdown', (tester) async {
      final c = ExamController(
        sitting: sampleSitting(paper: samplePaper(minutes: 1)),
        repository: repo,
        store: store,
        userId: 'u1',
        now: clock.call,
      );
      made.add(c);
      c.start();
      c.select(0);
      for (var i = 0; i < 59; i++) {
        clock.advance(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
      expect(c.remaining.value, const Duration(seconds: 1));
      expect(repo.submitted, isEmpty);
      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(c.phase, ExamPhase.done);
      expect(repo.submitted, hasLength(1));
    });

    testWidgets('time spent in the background is still spent: coming back recomputes the clock', (tester) async {
      final c = make(minutes: 30)..start();
      c.select(1);
      // No tick fires while the app is backgrounded; the wall clock moves on regardless.
      clock.advance(const Duration(minutes: 12));
      expect(c.remaining.value, const Duration(minutes: 30), reason: 'stale until the app is back');
      c.tick();
      expect(c.remaining.value, const Duration(minutes: 18));
      expect(c.phase, ExamPhase.running);

      clock.advance(const Duration(minutes: 40));
      c.tick();
      await tester.pump();
      expect(c.phase, ExamPhase.done, reason: 'the time ran out while away: what was answered is sent');
      expect(c.autoSubmitted, isTrue);
      expect(repo.submitted.single.first.selected, [1]);
    });

    testWidgets('a sitting picked up after its time ran out is sent at once', (tester) async {
      final first = make(minutes: 10)..start();
      first.select(2);
      await first.flushed();
      first.dispose();
      final saved = (await store.load('u1', 'cp-foundation'))!;
      clock.advance(const Duration(minutes: 25));
      final c = ExamController(
        sitting: saved.sitting,
        repository: repo,
        store: store,
        userId: 'u1',
        now: clock.call,
        resume: saved,
        tickEvery: const Duration(hours: 1),
      );
      made.add(c);
      expect(c.remaining.value, Duration.zero);
      c.start();
      await tester.pump();
      expect(c.phase, ExamPhase.done);
      expect(repo.submitted.single.first.selected, [2]);
    });

    testWidgets('a send that fails at zero stays failed; it does not loop, and Try again sends it', (tester) async {
      var tries = 0;
      repo.onSubmit = (_, _, _) async {
        tries++;
        if (tries == 1) throw ApiError('offline');
        return sampleResult();
      };
      final c = make(minutes: 1)..start();
      c.select(1);
      clock.advance(const Duration(minutes: 1));
      c.tick();
      await tester.pump();
      expect(c.phase, ExamPhase.failed);
      expect(c.timeUp, isTrue);
      expect(c.reopen(), isFalse, reason: 'no time left to go back to');
      c.tick();
      c.tick();
      await tester.pump();
      expect(tries, 1, reason: 'ticks do not resend a failed send');
      expect(await c.submit(auto: true), isTrue);
      expect(tries, 2);
      expect(c.picked('q1'), [1]);
    });
  });

  group('the brief', () {
    late FakeClock clock;
    late FakeExam repo;
    late MemoryExamProgressStore store;

    BriefController brief({String slug = 'cp-foundation'}) => BriefController(
      repository: repo,
      ref: PaperRef(slug: slug, title: 'Foundation'),
      store: store,
      userId: 'u1',
      now: clock.call,
    );

    setUp(() {
      clock = FakeClock();
      repo = FakeExam(sittingValue: sampleSitting());
      store = MemoryExamProgressStore();
    });

    test('an open paper is ready, with a first sitting still to take', () async {
      final b = brief();
      expect(b.status, BriefStatus.loading);
      await b.load();
      expect(b.status, BriefStatus.ready);
      expect(b.paper!.slug, 'cp-foundation');
      expect(b.attemptsUsed, 0);
      expect(b.best, isNull);
      expect(b.exhausted, isFalse);
      expect(b.canStart, isTrue);
      expect(b.begin()!.sitting.questions, hasLength(5));
      expect(b.resume(), isNull);
    });

    test('the record shows the best score, the attempts used, and the certificate held', () async {
      repo.attemptsValue = [sampleAttempt(id: 'a2', attempt: 2, percentage: 60), sampleAttempt(percentage: 90)];
      repo.certificatesValue = [sampleCertificate()];
      final b = brief();
      await b.load();
      expect(b.attemptsUsed, 2);
      expect(b.best, 90);
      expect(b.certificate!.certificateId, 'ICR-CP-2026-AB12CD34');
      expect(repo.calls, containsAll(['attempts paper-cp-foundation', 'certificates']));
    });

    test('a certificate for another paper is not this paper\'s', () async {
      repo.certificatesValue = [
        ExamCertificate(
          id: 'c',
          certificateId: 'ICR-X-1',
          title: 'Other',
          paperId: 'someone-else',
          issuedAt: DateTime(2026),
        ),
      ];
      final b = brief();
      await b.load();
      expect(b.certificate, isNull);
    });

    test('all the attempts used closes the paper; a failed history read does not', () async {
      repo.sittingValue = sampleSitting(paper: samplePaper(attemptLimit: 2));
      repo.attemptsValue = [sampleAttempt(id: 'a1'), sampleAttempt(id: 'a2', attempt: 2)];
      final b = brief();
      await b.load();
      expect(b.exhausted, isTrue);
      expect(b.canStart, isFalse);
      expect(b.begin(), isNull);

      repo.attemptsError = ApiError('boom');
      repo.certificatesError = ApiError('boom');
      final again = brief();
      await again.load();
      expect(again.status, BriefStatus.ready, reason: 'the record is a nicety, the paper is not');
      expect(again.attemptsUsed, 0);
    });

    test('a paper with no questions cannot be started', () async {
      repo.sittingValue = const PaperSitting(
        paper: PaperInfo(id: 'p', slug: 'cp-foundation', title: 'F', kind: PaperKind.mock),
        questions: [],
      );
      final b = brief();
      await b.load();
      expect(b.noQuestions, isTrue);
      expect(b.canStart, isFalse);
    });

    test('a sitting left unfinished is offered to resume, with the time it has left', () async {
      final c = ExamController(
        sitting: repo.sittingValue!,
        repository: repo,
        store: store,
        userId: 'u1',
        now: clock.call,
        tickEvery: const Duration(hours: 1),
      )..start();
      c.select(1);
      await c.flushed();
      c.dispose();
      clock.advance(const Duration(minutes: 10));

      final b = brief();
      await b.load();
      expect(b.saved, isNotNull);
      expect(b.savedExpired, isFalse);
      expect(b.savedLeft, const Duration(minutes: 20));
      final start = b.resume()!;
      expect(start.resume, isNotNull);
      expect(start.sitting.questions, hasLength(5));

      clock.advance(const Duration(minutes: 25));
      expect(b.savedExpired, isTrue);
      expect(b.savedLeft, Duration.zero);

      await b.discardSaved();
      expect(b.saved, isNull);
      expect(await store.load('u1', 'cp-foundation'), isNull);
    });

    test('exhausted attempts still let a saved sitting be sent', () async {
      repo.sittingValue = sampleSitting(paper: samplePaper(attemptLimit: 1));
      repo.attemptsValue = [sampleAttempt()];
      final c = ExamController(
        sitting: repo.sittingValue!,
        repository: repo,
        store: store,
        userId: 'u1',
        now: clock.call,
        tickEvery: const Duration(hours: 1),
      )..start();
      await c.flushed();
      c.dispose();
      final b = brief();
      await b.load();
      expect(b.exhausted, isTrue);
      expect(b.canStart, isTrue);
    });

    test('a closed paper loads its parameters, its price and what the member holds instead', () async {
      repo.lock = const PaperLock(message: 'Not in your plan.', reason: 'COURSES', credits: 180);
      repo.infoValue = samplePaper(priceAmount: 49900);
      repo.quoteValue = PaperQuote.fromJson(_map(recorded('quote_procurement')));
      final b = brief();
      await b.load();
      expect(b.status, BriefStatus.locked);
      expect(b.lock!.credits, 180);
      expect(b.paper!.slug, 'cp-foundation');
      expect(b.quote!.credits, 4);
      expect(b.canStart, isFalse);
      expect(b.begin(), isNull);
      expect(repo.calls, containsAll(['sitting cp-foundation', 'info cp-foundation', 'quote cp-foundation']));
    });

    test('redeeming credits opens the paper: the brief loads again, ready', () async {
      repo.lock = const PaperLock(message: 'Locked.', credits: 180);
      repo.infoValue = samplePaper();
      repo.quoteValue = PaperQuote.fromJson(_map(recorded('quote_procurement')));
      final b = brief();
      await b.load();
      expect(b.status, BriefStatus.locked);
      expect(await b.redeem(), isTrue);
      expect(repo.calls, contains('redeem cp-foundation'));
      expect(b.status, BriefStatus.ready);
      expect(b.working, isFalse);
      expect(b.actionError, isNull);
    });

    test('a refused redemption says why, and the brief shows what the member holds now', () async {
      repo.lock = const PaperLock(message: 'Locked.', credits: 2);
      repo.infoValue = samplePaper();
      repo.quoteValue = PaperQuote.fromJson(_map(recorded('quote_procurement')));
      repo.redeemError = ApiError(
        'This level takes 4 ICR credits, and you have 2.',
        statusCode: 403,
        code: 'NO_CREDIT_LEFT',
      );
      final b = brief();
      await b.load();
      expect(await b.redeem(), isFalse);
      expect(b.status, BriefStatus.locked);
      expect(b.actionError, contains('takes 4 ICR credits'));
      expect(b.working, isFalse);
    });

    test('opening with the plan works only when the plan has a place for it', () async {
      repo.lock = const PaperLock(
        message: 'Your plan includes 2 mock exams.',
        reason: 'PICK',
        opensTarget: 'MOCK_EXAM',
        opensId: 't1',
        placesLeft: 1,
      );
      repo.infoValue = samplePaper(kind: PaperKind.mock);
      repo.quoteValue = PaperQuote.fromJson(_map(recorded('quote_procurement')));
      final b = brief();
      await b.load();
      expect(await b.openWithPlan(), isTrue);
      expect(repo.calls, contains('open MOCK_EXAM t1'));
      expect(b.status, BriefStatus.ready);

      repo.lock = const PaperLock(message: 'Used up.', reason: 'MOCKS');
      final closed = brief();
      await closed.load();
      expect(await closed.openWithPlan(), isFalse);
      expect(repo.calls.where((c) => c.startsWith('open ')), hasLength(1), reason: 'no call is made');
    });

    test('a paper that will not load fails with the API\'s sentence, and loads again', () async {
      repo.sittingError = ApiError('Paper not found', statusCode: 404);
      final b = brief();
      await b.load();
      expect(b.status, BriefStatus.failed);
      expect(b.error, 'Paper not found');
      repo.sittingError = null;
      await b.load();
      expect(b.status, BriefStatus.ready);
      expect(b.error, isNull);
    });
  });

  group('the history and the certificates', () {
    test('the history can be narrowed to assessments or mock exams, and counts what passed', () async {
      final repo = FakeExam()
        ..unread = 3
        ..attemptsValue = [
          sampleAttempt(id: 'a', percentage: 90),
          sampleAttempt(
            id: 'b',
            percentage: 40,
            paper: samplePaper(slug: 'bemp-1', kind: PaperKind.mock),
          ),
          sampleAttempt(id: 'c', percentage: 60),
        ];
      final c = AttemptsController(repo);
      expect(c.loading, isTrue);
      await c.start();
      expect(c.loading, isFalse);
      expect(c.all, hasLength(3));
      expect(c.passed, 1);
      expect(c.best, 90);
      expect(c.unread, 3);
      c.setFilter(AttemptsFilter.mocks);
      expect(c.shown.map((a) => a.id), ['b']);
      c.setFilter(AttemptsFilter.assessments);
      expect(c.shown.map((a) => a.id), ['a', 'c']);
      c.setFilter(AttemptsFilter.all);
      expect(c.shown, hasLength(3));
    });

    test('a failed history read says so and loads again', () async {
      final repo = FakeExam()..attemptsError = ApiError("Can't reach ICR right now.");
      final c = AttemptsController(repo);
      await c.start();
      expect(c.error, contains("Can't reach ICR"));
      expect(c.all, isEmpty);
      repo.attemptsError = null;
      repo.attemptsValue = [sampleAttempt()];
      await c.refresh();
      expect(c.error, isNull);
      expect(c.all, hasLength(1));
    });

    test('certificates are narrowed by who awarded them, ICR being one', () async {
      final repo = FakeExam()
        ..certificatesValue = [
          sampleCertificate(id: '1', number: 'ICR-A-1'),
          sampleCertificate(id: '2', number: 'ICR-B-2', provider: 'Leoron Institute'),
          sampleCertificate(id: '3', number: 'ICR-C-3'),
        ];
      final c = CertificatesController(repo);
      await c.start();
      expect(c.all, hasLength(3));
      expect(c.bodies, ['ICR', 'Leoron Institute']);
      expect(c.best, 90);
      c.setBody('Leoron Institute');
      expect(c.shown.map((x) => x.certificateId), ['ICR-B-2']);
      c.setBody(null);
      expect(c.shown, hasLength(3));
      c.setBody('ICR');
      expect(c.shown, hasLength(2));
    });

    test('a failed certificates read says so', () async {
      final repo = FakeExam()..certificatesError = ApiError('boom');
      final c = CertificatesController(repo);
      await c.start();
      expect(c.error, 'boom');
      expect(c.all, isEmpty);
    });
  });

  group('the API source', () {
    test('a paper is asked for by its slug and read with its questions', () async {
      final api = RoutedApi({
        'GET /learning/papers/capital-planning-foundation': (_) => recorded('sitting_cp_foundation'),
      });
      final s = await apiRepo(api).sitting('capital-planning-foundation');
      expect(s.questions, hasLength(10));
      expect(api.calls, ['GET /learning/papers/capital-planning-foundation']);
    });

    test('a paper the member has not opened is a lock carrying what would open it', () async {
      final api = RoutedApi({
        'GET /learning/papers/procurement-management-foundation': (_) => (403, recorded('locked_procurement')),
      });
      await expectLater(
        apiRepo(api).sitting('procurement-management-foundation'),
        throwsA(
          isA<PaperLockedException>()
              .having((e) => e.lock.credits, 'credits', 180)
              .having((e) => e.lock.reason, 'reason', 'COURSES')
              .having((e) => e.lock.opensId, 'opens', 'cmv6luak60015myt8tcdd09kx'),
        ),
      );
    });

    test('any other refusal is the API\'s sentence', () async {
      final api = RoutedApi({
        'GET /learning/papers/nope': (_) => (404, {'statusCode': 404, 'message': 'Paper not found'}),
      });
      await expectLater(
        apiRepo(api).sitting('nope'),
        throwsA(
          isA<ApiError>()
              .having((e) => e.message, 'message', 'Paper not found')
              .having((e) => e.statusCode, 'status', 404),
        ),
      );
    });

    test('the parameters of a closed paper come from the public list, by kind and slug', () async {
      final api = RoutedApi({'GET /learning/papers': (_) => recorded('papers_list')});
      final repo = apiRepo(api);
      final p = await repo.info(const PaperRef(slug: 'aee-cem-set-1', title: 'Set 1', isMock: true));
      expect(p.priceAmount, 29900);
      expect(api.queries.single, {'kind': 'MOCK'});
      await expectLater(repo.info(const PaperRef(slug: 'missing', title: 'x')), throwsA(isA<ApiError>()));
      expect(api.queries.sublist(1), [
        {'kind': 'ASSESSMENT'},
        isEmpty,
      ], reason: 'a miss on the kind is tried once more on the whole list');
      // A landing that says assessment for a mock set still finds it.
      final wrongKind = await repo.info(const PaperRef(slug: 'aee-cem-set-1', title: 'Set 1'));
      expect(wrongKind.isMock, isTrue);
    });

    test('quote, redeem and opening with the plan', () async {
      final api = RoutedApi({
        'GET /learning/papers/p/quote': (_) => recorded('quote_procurement'),
        'POST /learning/papers/p/redeem': (_) => {'unlocked': true, 'spent': 4, 'credits': 176},
        'POST /learning/me/opens': (_) => {'opened': true, 'via': 'PLAN'},
      });
      final repo = apiRepo(api);
      expect((await repo.quote('p')).credits, 4);
      final r = await repo.redeem('p');
      expect((r.spent, r.credits), (4, 176));
      await repo.openWithPlan(target: 'COURSE', targetId: 'c1');
      expect(api.bodies.last, {'target': 'COURSE', 'targetId': 'c1'});
    });

    test('a refused redemption carries the API\'s code', () async {
      final api = RoutedApi({
        'POST /learning/papers/p/redeem': (_) => (
          403,
          {'statusCode': 403, 'code': 'NO_CREDIT_LEFT', 'message': 'This level takes 4 ICR credits, and you have 2.'},
        ),
      });
      await expectLater(
        apiRepo(api).redeem('p'),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'code', 'NO_CREDIT_LEFT')
              .having((e) => e.message, 'm', contains('4 ICR')),
        ),
      );
    });

    test('the answers go as the DTO wants them: the start in epoch ms, every question with its picks', () async {
      final api = RoutedApi({'POST /learning/papers/cp/attempts': (_) => recorded('result_cp3')});
      final start = DateTime.utc(2026, 10, 23, 8, 30, 15, 250);
      final r = await apiRepo(api).submit(
        'cp',
        startedAt: start,
        answers: const [
          SubmittedAnswer('q1', [1]),
          SubmittedAnswer('q2', []),
          SubmittedAnswer('q3', [0, 2]),
        ],
      );
      expect(r.attempt.percentage, 90);
      expect(api.bodies.single, {
        'startedAt': start.millisecondsSinceEpoch,
        'answers': [
          {
            'questionId': 'q1',
            'selected': [1],
          },
          {'questionId': 'q2', 'selected': <int>[]},
          {
            'questionId': 'q3',
            'selected': [0, 2],
          },
        ],
      });
      expect((api.bodies.single as Map)['startedAt'], isA<int>());
    });

    test('a refused submit is the API\'s sentence', () async {
      final api = RoutedApi({
        'POST /learning/papers/cp/attempts': (_) =>
            (403, {'statusCode': 403, 'message': 'You have used all 3 attempts for this paper.'}),
      });
      await expectLater(
        apiRepo(api).submit('cp', startedAt: DateTime.now(), answers: const []),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 403)),
      );
    });

    test('the history, one sitting with its review, and the certificates', () async {
      final api = RoutedApi({
        'GET /learning/me/attempts': (_) => recorded('attempts_bharat'),
        'GET /learning/me/attempts/a1': (_) => recorded('result_cp3'),
        'GET /learning/me/certificates': (_) => recorded('certificates_bharat'),
        'GET /notifications/unread-count': (_) => {'unread': 4},
      });
      final repo = apiRepo(api);
      expect(await repo.attempts(), hasLength(4));
      expect(api.queries.last, isEmpty);
      await repo.attempts(paperId: 'p1');
      expect(api.queries.last, {'paperId': 'p1'});
      expect((await repo.attempt('a1')).review, hasLength(10));
      expect((await repo.certificates()).single.certificateId, 'ICR-CP-2026-DSGNLF01');
      expect(await repo.unreadNotifications(), 4);
    });

    test('a certificate number is looked up in the public register, trimmed; an unknown one is null', () async {
      final api = RoutedApi({
        'GET /learning/certificates/ICR-CP-2026-DSGNLF01': (_) => recorded('certificate_public'),
        'GET /learning/certificates/ICR-NOPE': (_) => (404, {'statusCode': 404, 'message': 'Certificate not found'}),
        'GET /learning/certificates/ICR-BOOM': (_) => (503, {'statusCode': 503, 'message': 'Try later'}),
      });
      final repo = apiRepo(api);
      final c = await repo.verifyCertificate('  ICR-CP-2026-DSGNLF01 ');
      expect(c!.holder, 'Bharat Buyer');
      expect(c.certificateId, 'ICR-CP-2026-DSGNLF01');
      expect(await repo.verifyCertificate('ICR-NOPE'), isNull);
      await expectLater(
        repo.verifyCertificate('ICR-BOOM'),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 503)),
      );
    });

    test('the bell count is zero when it cannot be read', () async {
      expect(await apiRepo(RoutedApi({})).unreadNotifications(), 0);
    });

    test('a connection that fails is the offline sentence', () async {
      final client = apiRepo(RoutedApi({}));
      client.api.dio.httpClientAdapter = _Offline();
      await expectLater(client.sitting('x'), throwsA(isA<ApiError>().having((e) => e.isOffline, 'offline', isTrue)));
    });
  });

  group('the certificate QR code', () {
    test('is module for module the code the website draws for the same text, from one module to version 10', () {
      final cases = (recorded('qr_website') as List).cast<Map<String, dynamic>>();
      expect(cases.map((c) => c['version']).toSet(), containsAll([1, 2, 4, 6, 8, 10]));
      for (final c in cases) {
        final code = QrCode.encode(c['text'] as String);
        final rows = (c['rows'] as List).cast<String>();
        expect(code.version, c['version'], reason: 'version of ${c['text']}');
        expect(code.size, c['size']);
        final mine = [for (final r in code.modules) r.map((d) => d ? '1' : '0').join()];
        expect(mine, rows, reason: 'the modules of "${c['text']}"');
      }
    });

    test('a text that does not fit version 10 is refused, and the longest that fits is not', () {
      expect(QrCode.encode('x' * 213).version, 10);
      expect(() => QrCode.encode('x' * 214), throwsArgumentError);
    });

    test('a verification link of a certificate makes a 33 by 33 code', () {
      expect(QrCode.encode('https://icr.org.in/learning/verify?id=ICR-CP-2026-DSGNLF01').size, 33);
    });
  });

  group('the sample content', () {
    test('the demo paper can be sat from end to end and keeps its history', () async {
      final repo = DemoExamRepository();
      final s = await repo.sitting('anything');
      expect(s.questions, hasLength(5));
      expect(s.questions.where((q) => q.multiple), hasLength(1));
      const key = {
        'demo-q0': [0],
        'demo-q1': [1],
        'demo-q2': [0, 1, 3],
        'demo-q3': [1],
        'demo-q4': [0],
      };
      final answers = [for (final q in s.questions) SubmittedAnswer(q.id, key[q.id]!)];
      final r = await repo.submit(
        'demo-paper',
        startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
        answers: answers,
      );
      expect(r.attempt.percentage, 100);
      expect(r.attempt.passed, isTrue);
      expect(r.certificate, isNotNull);
      expect(r.review, hasLength(5));
      expect((await DemoExamRepository().attempts()).first.id, r.attempt.id);
      expect((await DemoExamRepository().attempt(r.attempt.id)).attempt.id, r.attempt.id);
      expect((await DemoExamRepository().certificates()), hasLength(1));
      expect(
        (await DemoExamRepository().verifyCertificate(' icr-fmb-2026-demo0001 '))!.title,
        'Facility Management Basics',
      );
      expect(await DemoExamRepository().verifyCertificate('ICR-X'), isNull);
    });
  });
}

class _BrokenStore implements ExamProgressStore {
  @override
  Future<ExamSnapshot?> load(String userId, String slug) async => throw StateError('keystore is gone');
  @override
  Future<void> save(ExamSnapshot snapshot) async => throw StateError('keystore is gone');
  @override
  Future<void> clear(String userId, String slug) async => throw StateError('keystore is gone');
}

class _Offline implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException.connectionError(requestOptions: options, reason: 'no network');
  }

  @override
  void close({bool force = false}) {}
}
