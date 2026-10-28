/// The exam flow against the LOCAL portal API, signed in as the seeded personas. Needs `tool/seed/learning-flows.ts`
/// (real questions on Capital Planning - Foundation and ASHRAE BEMP - Set 1, Bharat Buyer's history and
/// certificate, and the Exam Persona). Run with the API up: `flutter test test/live/learning_exam_live_test.dart`.
///
/// What a test writes, and why it stays:
///  * An attempt cannot be deleted through the API. Each run of this file sits the papers below a few times:
///    Pooja Professional sits three mock sets (`aee-cmvp-set-1`, `aee-certified-energy-auditor-set-1`,
///    `ashrae-bemp-set-1`: unlimited attempts, one sitting each, plus one that is deliberately sent twice to
///    prove the retry makes no second attempt), and the Exam Persona sits Procurement Management - Foundation
///    twice. Running `tool/seed/learning-flows.ts` again resets the Exam Persona (her redeemed paper, her
///    attempts and her certificate), so her test runs from the start every time; Pooja's attempts only add up.
///  * Redeeming ICR credits cannot be undone either, which is why it is done as the Exam Persona, a throwaway
///    account made for this; redeeming a paper that is already open spends nothing, so a second run still passes.
///  * Bharat Buyer's tests only read.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/learning_exam/api_exam_repository.dart';
import 'package:icr_mobile/features/learning_exam/attempts_controller.dart';
import 'package:icr_mobile/features/learning_exam/brief_controller.dart';
import 'package:icr_mobile/features/learning_exam/certificates_controller.dart';
import 'package:icr_mobile/features/learning_exam/exam_controller.dart';
import 'package:icr_mobile/features/learning_exam/exam_models.dart';
import 'package:icr_mobile/features/learning_exam/exam_progress_store.dart';
import 'package:icr_mobile/features/learning_exam/exam_repository.dart';

import 'live.dart';

/// The throwaway account `tool/seed/learning-flows.ts` makes, with a plan that opens nothing and the signup credits.
const examPersona = LivePerson('exam.sitter@learning-flows.icr.test', 'Exam@12345', 'Exam Persona');

const _cpFoundation = 'capital-planning-foundation';
const _procurement = 'procurement-management-foundation';

Future<ApiExamRepository> _repo([LivePerson who = bharat]) async => ApiExamRepository(api: await liveClient(who));

/// Whether the seed is in: Bharat's seeded sittings are there.
Future<bool> _seeded() async {
  final rows = await (await _repo()).attempts();
  return rows.any((a) => a.id.startsWith('design-lf-'));
}

ExamController _examOn(ExamRepository repo, PaperSitting sitting, String userId) => ExamController(
  sitting: sitting,
  repository: repo,
  store: MemoryExamProgressStore(),
  userId: userId,
  tickEvery: const Duration(hours: 1),
);

/// A repository that sends the answers to the real API and then loses the reply, once: the sitting is
/// recorded and the app is told it failed.
class _LosesTheFirstReply implements ExamRepository {
  _LosesTheFirstReply(this.inner);

  final ExamRepository inner;
  int sent = 0;

  @override
  Future<AttemptResult> submit(
    String slug, {
    required DateTime startedAt,
    required List<SubmittedAnswer> answers,
  }) async {
    final result = await inner.submit(slug, startedAt: startedAt, answers: answers);
    sent++;
    if (sent == 1) throw ApiError("Can't reach ICR right now. Check your connection and try again.");
    return result;
  }

  @override
  Future<PaperSitting> sitting(String slug) => inner.sitting(slug);
  @override
  Future<PaperInfo> info(PaperRef ref) => inner.info(ref);
  @override
  Future<PaperQuote> quote(String slug) => inner.quote(slug);
  @override
  Future<RedeemResult> redeem(String slug) => inner.redeem(slug);
  @override
  Future<void> openWithPlan({required String target, required String targetId}) =>
      inner.openWithPlan(target: target, targetId: targetId);
  @override
  Future<List<Attempt>> attempts({String? paperId}) => inner.attempts(paperId: paperId);
  @override
  Future<AttemptResult> attempt(String id) => inner.attempt(id);
  @override
  Future<List<ExamCertificate>> certificates() => inner.certificates();
  @override
  Future<ExamCertificate?> verifyCertificate(String certificateId) => inner.verifyCertificate(certificateId);
  @override
  Future<int> unreadNotifications() => inner.unreadNotifications();
  @override
  Uri sitePage(String path) => inner.sitePage(path);
}

void main() {
  // --- reading: Bharat Buyer, the emulator's person ---------------------------------------------------------

  group('Bharat Buyer reads his own record', () {
    liveTest('a paper he holds is served with its questions and without the answer key', () async {
      final api = await liveClient();
      final repo = ApiExamRepository(api: api);
      final s = await repo.sitting(_cpFoundation);
      expect(s.paper.slug, _cpFoundation);
      expect(s.paper.kind, PaperKind.assessment);
      expect(s.paper.certificateEnabled, isTrue);
      expect(s.paper.durationMinutes, greaterThan(0));
      expect(s.questions, hasLength(s.paper.questionCount));
      expect(s.questions.every((q) => q.options.length >= 2), isTrue);

      // The key stays on the server until a sitting is sent.
      final raw = await api.dio.get<Map<String, dynamic>>('/learning/papers/$_cpFoundation');
      final first = (raw.data!['questions'] as List).first as Map<String, dynamic>;
      expect(first.containsKey('correctIndexes'), isFalse);
      expect(first.containsKey('explanation'), isFalse);
    });

    liveTest('the brief of that paper is ready, with his record, his certificate and the way to start', () async {
      if (!await _seeded()) return markTestSkipped('run tool/seed/learning-flows.ts first');
      final brief = BriefController(
        repository: await _repo(),
        ref: const PaperRef(slug: _cpFoundation, title: 'Foundation', courseCode: 'CP'),
        store: MemoryExamProgressStore(),
        userId: 'live-bharat',
      );
      await brief.load();
      expect(brief.status, BriefStatus.ready);
      expect(brief.attemptsUsed, greaterThanOrEqualTo(3));
      expect(brief.best, greaterThanOrEqualTo(90));
      expect(brief.certificate?.certificateId, 'ICR-CP-2026-DSGNLF01');
      expect(brief.exhausted, isFalse);
      expect(brief.canStart, isTrue);
      expect(brief.begin()!.sitting.questions, isNotEmpty);
    });

    liveTest('his history lists the seeded sittings newest first, each with its paper', () async {
      if (!await _seeded()) return markTestSkipped('run tool/seed/learning-flows.ts first');
      final repo = await _repo();
      final rows = await repo.attempts();
      final mine = rows.where((a) => a.id.startsWith('design-lf-')).toList();
      expect(mine.length, 4);
      final times = rows.map((a) => a.submittedAt!).toList();
      expect([...times]..sort((a, b) => b.compareTo(a)), times, reason: 'newest first');
      final foundation = mine.where((a) => a.paper!.slug == _cpFoundation).toList();
      expect(foundation.map((a) => a.percentage).toSet(), {40, 60, 90});
      expect(foundation.where((a) => a.passed), hasLength(1));
      expect(mine.firstWhere((a) => a.paper!.slug == 'capital-planning-advanced').passed, isFalse);

      final onlyThisPaper = await repo.attempts(paperId: foundation.first.paperId);
      expect(onlyThisPaper.every((a) => a.paperId == foundation.first.paperId), isTrue);
    });

    liveTest('a past sitting comes back with the key, the explanation and the certificate it earned', () async {
      if (!await _seeded()) return markTestSkipped('run tool/seed/learning-flows.ts first');
      final repo = await _repo();
      final passed = (await repo.attempts()).firstWhere((a) => a.id == 'design-lf-att-$_cpFoundation-3');
      final r = await repo.attempt(passed.id);
      expect(r.attempt.percentage, 90);
      expect(r.attempt.passed, isTrue);
      expect(r.review, hasLength(10));
      expect(r.missing, 0);
      expect(r.review.where((q) => q.outcome == ReviewOutcome.correct), hasLength(9));
      expect(r.review.every((q) => q.explanation != null && q.category != null), isTrue);
      expect(r.certificate!.certificateId, 'ICR-CP-2026-DSGNLF01');
      expect(r.attempt.paper!.certificateEnabled, isTrue);

      final missed = await repo.attempt('design-lf-att-$_cpFoundation-1');
      expect(missed.certificate, isNull, reason: 'a later pass does not move the certificate onto an earlier sitting');
      expect(missed.review.where((q) => q.outcome == ReviewOutcome.skipped), hasLength(1));
    });

    liveTest('another person\'s sitting is not found', () async {
      if (!await _seeded()) return markTestSkipped('run tool/seed/learning-flows.ts first');
      final poojasRepo = await _repo(pooja);
      await expectLater(
        poojasRepo.attempt('design-lf-att-$_cpFoundation-3'),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 404)),
      );
    });

    liveTest('his certificates carry the seeded one, and anyone can check its number', () async {
      if (!await _seeded()) return markTestSkipped('run tool/seed/learning-flows.ts first');
      final repo = await _repo();
      final mine = await repo.certificates();
      final c = mine.firstWhere((c) => c.certificateId == 'ICR-CP-2026-DSGNLF01');
      expect(c.title, 'Capital Planning');
      expect(c.levelLabel, 'Foundation');
      expect(c.percentage, 90);
      expect(c.attempt, 3);
      expect(c.paperSlug, _cpFoundation);

      // The register is public: no sign-in, and the number may be typed in lower case with spaces round it.
      final anonymous = ApiExamRepository(api: liveAnonymous());
      final verified = (await anonymous.verifyCertificate('  icr-cp-2026-dsgnlf01 '))!;
      expect(verified.holder, 'Bharat Buyer');
      expect(verified.certificateId, c.certificateId);
      expect(verified.title, 'Capital Planning');
      expect(verified.passPercentage, 70);
      expect(await anonymous.verifyCertificate('ICR-NOPE-0000'), isNull);
    });

    liveTest('My attempts and My certificates read the same through their controllers', () async {
      if (!await _seeded()) return markTestSkipped('run tool/seed/learning-flows.ts first');
      final repo = await _repo();
      final attempts = AttemptsController(repo);
      await attempts.start();
      expect(attempts.error, isNull);
      expect(attempts.all.length, greaterThanOrEqualTo(4));
      expect(attempts.passed, greaterThanOrEqualTo(1));
      expect(attempts.best, greaterThanOrEqualTo(90));
      attempts.setFilter(AttemptsFilter.mocks);
      expect(attempts.shown.every((a) => a.paper!.kind == PaperKind.mock), isTrue);
      attempts.setFilter(AttemptsFilter.assessments);
      expect(attempts.shown.length, greaterThanOrEqualTo(4));
      attempts.dispose();

      final certs = CertificatesController(repo);
      await certs.start();
      expect(certs.error, isNull);
      expect(certs.all.map((c) => c.certificateId), contains('ICR-CP-2026-DSGNLF01'));
      expect(certs.bodies, contains('ICR'));
      certs.dispose();
    });
  });

  // --- what a paper takes to open: Pooja Professional ---------------------------------------------------------

  group('a paper Pooja Professional has not opened', () {
    liveTest('is refused with what would open it, and the brief offers credits and a price', () async {
      final repo = await _repo(pooja);
      await expectLater(
        repo.sitting(_procurement),
        throwsA(
          isA<PaperLockedException>()
              .having((e) => e.lock.code, 'code', 'PAPER_LOCKED')
              .having((e) => e.lock.credits, 'credits', greaterThan(0))
              .having((e) => e.lock.opensTarget, 'target', 'COURSE'),
        ),
      );
      final brief = BriefController(
        repository: repo,
        ref: const PaperRef(slug: _procurement, title: 'Foundation', courseCode: 'PM'),
        store: MemoryExamProgressStore(),
        userId: 'live-pooja',
      );
      await brief.load();
      expect(brief.status, BriefStatus.locked);
      expect(brief.paper!.slug, _procurement);
      expect(brief.paper!.questionCount, greaterThan(0));
      expect(brief.quote!.priced, isTrue);
      expect(brief.quote!.credits, isNotNull);
      expect(brief.quote!.alreadyOpen, isFalse);
      expect(brief.canStart, isFalse);
    });

    liveTest("opening a course that does not exist is refused with the API's sentence", () async {
      final repo = await _repo(pooja);
      await expectLater(
        repo.openWithPlan(target: 'COURSE', targetId: 'no-such-course'),
        throwsA(
          isA<ApiError>()
              .having((e) => e.statusCode, 'status', 404)
              .having((e) => e.message, 'message', 'Course not found'),
        ),
      );
    });
  });

  // --- sitting a paper for real: Pooja Professional ------------------------------------------------------------

  group('Pooja Professional sits a paper', () {
    liveTest('answers go as the API wants them, are scored, and read back through her history', () async {
      final repo = await _repo(pooja);
      const slug = 'aee-cmvp-set-1';
      final sitting = await repo.sitting(slug);
      expect(sitting.paper.isMock, isTrue);
      final before = (await repo.attempts(paperId: sitting.paper.id)).length;

      final exam = _examOn(repo, sitting, 'live-pooja')..start();
      for (var i = 0; i < sitting.questions.length; i++) {
        exam.goTo(i);
        if (i.isEven) exam.select(0); // half of them answered, the other half skipped
      }
      exam.toggleFlag(); // a flag is the app's own, it never reaches the API
      final sent = DateTime.now();
      expect(await exam.submit(), isTrue);

      final r = exam.result!;
      final total = sitting.questions.length;
      expect(r.attempt.totalQuestions, total);
      expect(r.attempt.correct + r.attempt.wrong + r.attempt.unanswered, total);
      expect(r.attempt.unanswered, total ~/ 2, reason: 'the odd-numbered questions were left');
      expect(r.attempt.attempt, before + 1);
      expect(r.attempt.passPercentage, sitting.paper.passPercentage);
      expect(r.attempt.passed, r.attempt.percentage >= sitting.paper.passPercentage);
      expect(r.review, hasLength(total));
      expect(
        r.attempt.startedAt!.millisecondsSinceEpoch,
        exam.startedAt.millisecondsSinceEpoch,
        reason: 'the start is the sitting\'s own',
      );
      expect(r.attempt.submittedAt!.difference(sent).inSeconds.abs(), lessThan(30));
      for (final q in r.review) {
        final answered = sitting.questions.indexWhere((s) => s.id == q.id).isEven;
        expect(q.selected, answered ? [0] : isEmpty);
        expect(q.correctIndexes, isNotEmpty);
      }

      // It is in her history, and opens again as the same result.
      final history = await repo.attempts(paperId: sitting.paper.id);
      expect(history, hasLength(before + 1));
      final again = await repo.attempt(r.attempt.id);
      expect(again.attempt.percentage, r.attempt.percentage);
      expect(again.review.map((q) => q.id), r.review.map((q) => q.id));
      expect(again.review.map((q) => q.selected.join(',')), r.review.map((q) => q.selected.join(',')));
      exam.dispose();
    });

    liveTest('a multiple-choice question is right only when every right option is picked', () async {
      if (!await _seeded()) {
        return markTestSkipped(
          'run tool/seed/learning-flows.ts first (it gives this set its multiple-choice questions)',
        );
      }
      final repo = await _repo(pooja);
      final sitting = await repo.sitting('ashrae-bemp-set-1');
      final multiple = [
        for (final (i, q) in sitting.questions.indexed)
          if (q.multiple) i,
      ];
      expect(multiple, hasLength(2));

      final exam = _examOn(repo, sitting, 'live-pooja-multi')..start();
      exam.goTo(multiple[0]);
      for (final o in [3, 0, 1]) {
        exam.select(o); // picked out of order on purpose: the app sends them sorted
      }
      exam.goTo(multiple[1]);
      exam.select(0);
      exam.select(1); // right options 0, 1 and 3: two of the three is wrong
      expect(exam.picked(sitting.questions[multiple[0]].id), [0, 1, 3]);
      expect(await exam.submit(), isTrue);

      final byId = {for (final q in exam.result!.review) q.id: q};
      expect(byId[sitting.questions[multiple[0]].id]!.outcome, ReviewOutcome.correct);
      expect(byId[sitting.questions[multiple[0]].id]!.correctIndexes, [0, 1, 3]);
      expect(byId[sitting.questions[multiple[1]].id]!.outcome, ReviewOutcome.incorrect);
      expect(exam.result!.attempt.correct, 1);
      expect(exam.result!.attempt.wrong, 1);
      expect(exam.result!.attempt.unanswered, 8);
      expect(exam.result!.attempt.percentage, 10);
      exam.dispose();
    });

    liveTest('pressing Submit twice makes one attempt', () async {
      final repo = await _repo(pooja);
      const slug = 'aee-certified-energy-auditor-set-1';
      final sitting = await repo.sitting(slug);
      final before = (await repo.attempts(paperId: sitting.paper.id)).length;
      final exam = _examOn(repo, sitting, 'live-pooja-twice')..start();
      exam.select(1);
      final results = await Future.wait([exam.submit(), exam.submit(), exam.submit()]);
      expect(results, [true, true, true]);
      expect((await repo.attempts(paperId: sitting.paper.id)), hasLength(before + 1));
      exam.dispose();
    });

    liveTest('a reply that never arrived is not sent twice: the retry finds the sitting that landed', () async {
      final real = await _repo(pooja);
      final lossy = _LosesTheFirstReply(real);
      const slug = 'ashrae-bemp-set-1';
      final sitting = await real.sitting(slug);
      final before = (await real.attempts(paperId: sitting.paper.id)).length;

      final exam = _examOn(lossy, sitting, 'live-pooja-lossy')..start();
      exam.select(2);
      expect(await exam.submit(), isFalse, reason: 'the reply was lost');
      expect(exam.phase, ExamPhase.failed);
      expect(exam.retryable, isTrue);
      expect(exam.picked(sitting.questions.first.id), [2], reason: 'the answers are kept');
      expect((await real.attempts(paperId: sitting.paper.id)), hasLength(before + 1), reason: 'it did land');

      expect(await exam.submit(), isTrue);
      expect(lossy.sent, 1, reason: 'the retry sent nothing');
      expect((await real.attempts(paperId: sitting.paper.id)), hasLength(before + 1), reason: 'no second attempt');
      expect(exam.result!.attempt.startedAt!.millisecondsSinceEpoch, exam.startedAt.millisecondsSinceEpoch);
      expect(exam.result!.review.first.selected, [2]);
      exam.dispose();
    });
  });

  // --- opening a paper and earning a certificate: the Exam Persona ---------------------------------------------

  group('the Exam Persona opens a paper with credits, and earns its certificate', () {
    liveTest('redeem, fail on a blank sitting, pass on the key, and hold the certificate', () async {
      if (!await _seeded()) return markTestSkipped('run tool/seed/learning-flows.ts first (it makes the Exam Persona)');
      final repo = await _repo(examPersona);

      // Locked until credits are spent (a second run finds it open already, and redeeming it again spends nothing).
      final brief = BriefController(
        repository: repo,
        ref: const PaperRef(slug: _procurement, title: 'Foundation', courseCode: 'PM'),
        store: MemoryExamProgressStore(),
        userId: 'live-exam-persona',
      );
      await brief.load();
      if (brief.status == BriefStatus.locked) {
        final credits = brief.lock!.credits;
        final cost = brief.quote!.credits!;
        expect(
          credits,
          greaterThanOrEqualTo(cost),
          reason: 'the signup credits cover one paper (re-run the seed to reset her)',
        );
        expect(await brief.redeem(), isTrue, reason: brief.actionError);
        expect(brief.status, BriefStatus.ready);
        final after = (await repo.sitting(_procurement)); // opens now
        expect(after.questions, isNotEmpty);
        // The credits are spent, once.
        final left = await (await liveClient(examPersona)).dio.get<Map<String, dynamic>>('/learning/me/paper-unlocks');
        expect(left.data!['icrCredits'], credits - cost);
      } else {
        expect(brief.status, BriefStatus.ready, reason: 'opened on an earlier run');
      }
      expect((await repo.redeem(_procurement)).spent, 0, reason: 'redeeming an open paper spends nothing');

      final sitting = await repo.sitting(_procurement);
      expect(sitting.paper.certificateEnabled, isTrue);

      // A blank sitting fails and shows the key.
      final blank = _examOn(repo, sitting, 'live-exam-persona')..start();
      expect(await blank.submit(), isTrue);
      expect(blank.result!.attempt.passed, isFalse);
      expect(blank.result!.attempt.percentage, 0);
      expect(blank.result!.attempt.unanswered, sitting.questions.length);
      expect(blank.result!.certificate, isNull);
      final key = {for (final q in blank.result!.review) q.id: q.correctIndexes};
      expect(key.values.every((k) => k.isNotEmpty), isTrue);
      blank.dispose();

      // Then the key, answered from the app's own controls.
      final exam = _examOn(repo, await repo.sitting(_procurement), 'live-exam-persona')..start();
      for (var i = 0; i < exam.total; i++) {
        exam.goTo(i);
        for (final o in key[exam.question.id]!) {
          exam.select(o);
        }
      }
      expect(exam.counts.answered, exam.total);
      expect(await exam.submit(), isTrue);
      final r = exam.result!;
      expect(r.attempt.percentage, 100);
      expect(r.attempt.passed, isTrue);
      expect(r.certificate, isNotNull);
      expect(r.certificate!.certificateId, startsWith('ICR-'));
      exam.dispose();

      // It is in her certificates, and the register knows the holder.
      final mine = await repo.certificates();
      final cert = mine.firstWhere((c) => c.certificateId == r.certificate!.certificateId);
      expect(cert.title, 'Procurement Management');
      expect(cert.percentage, greaterThanOrEqualTo(70));
      final verified = await liveAnonymous().dio.get<Map<String, dynamic>>(
        '/learning/certificates/${cert.certificateId}',
      );
      expect(ExamCertificate.fromJson(verified.data!).holder, 'Exam Persona');

      // The sitting that earned the certificate opens again with it; a later sitting does not claim it.
      final history = await repo.attempts(paperId: sitting.paper.id);
      expect(history.length, greaterThanOrEqualTo(2));
      final reopened = await repo.attempt(r.attempt.id);
      if (r.certificate!.attempt == r.attempt.attempt) {
        expect(reopened.certificate?.certificateId, cert.certificateId, reason: 'this sitting earned it');
      } else {
        // A later pass gets the certificate already held back in its result, but never claims it as its own.
        expect(reopened.certificate, isNull);
        expect(r.certificate!.certificateId, cert.certificateId);
      }
    });

    liveTest('opening a course with a plan she does not have is refused with the API\'s sentence', () async {
      if (!await _seeded()) return markTestSkipped('run tool/seed/learning-flows.ts first (it makes the Exam Persona)');
      final repo = await _repo(examPersona);
      await expectLater(
        repo.openWithPlan(target: 'COURSE', targetId: 'cmv6luak60015myt8tcdd09kx'),
        throwsA(
          isA<ApiError>()
              .having((e) => e.statusCode, 'status', 403)
              .having((e) => e.code, 'code', 'NO_PLAN_PLACE_LEFT')
              .having((e) => e.message, 'message', contains('no course left to open')),
        ),
      );
    });

    liveTest('a paper that costs more credits than she holds is refused, and the refusal says by how much', () async {
      if (!await _seeded()) return markTestSkipped('run tool/seed/learning-flows.ts first (it makes the Exam Persona)');
      final repo = await _repo(examPersona);
      // A priced level of a programme she has not opened, dear enough at its credit value to be out of reach once
      // the first paper has been redeemed: if she can still afford it, the refusal is not reachable and the test says so.
      const dear = 'contract-management-professional';
      final quote = await repo.quote(dear);
      final held =
          (await (await liveClient(
                examPersona,
              )).dio.get<Map<String, dynamic>>('/learning/me/paper-unlocks')).data!['icrCredits']
              as int;
      if (quote.alreadyOpen || quote.credits == null || quote.credits! <= held) {
        return markTestSkipped('she can afford it (${quote.credits} credits against $held)');
      }
      await expectLater(
        repo.redeem(dear),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'code', 'NO_CREDIT_LEFT')
              .having((e) => e.message, 'message', contains('ICR credits')),
        ),
      );
    });
  });
}
