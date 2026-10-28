import 'dart:async';

import '../../core/config.dart';
import 'exam_models.dart';
import 'exam_repository.dart';

/// A little sample content for the design-review build (`--dart-define=FEED_SOURCE=demo`): one paper of five
/// questions that opens whatever paper is asked for, a score kept in memory, and one certificate.
class DemoExamRepository implements ExamRepository {
  DemoExamRepository();

  static const _questions = [
    (
      'Which document sets out how a facility is to be operated and maintained day to day?',
      ['An operations and maintenance manual', 'A lease agreement', 'A marketing brochure', 'A tax return'],
      [0],
      'The O&M manual is the working reference for running the building.',
      'Operations',
    ),
    (
      'A planned maintenance schedule is mainly meant to:',
      [
        'Replace the need for inspections',
        'Prevent failures before they happen',
        'Reduce the number of tenants',
        'Raise the rent',
      ],
      [1],
      'Planned work finds wear early, which is cheaper than repairing a breakdown.',
      'Maintenance',
    ),
    (
      'Which of these are common facility KPIs? Select all that apply.',
      [
        'Planned-to-reactive work ratio',
        'Tenant satisfaction',
        'Number of logo variants',
        'Energy use per square metre',
      ],
      [0, 1, 3],
      'Ratios of planned work, satisfaction and energy intensity all describe how well a facility performs.',
      'Performance',
    ),
    (
      'Capital planning looks at spending over:',
      ['One day', 'The asset\'s life', 'One meeting', 'The last invoice'],
      [1],
      'Capital plans balance what assets will need across their whole life.',
      'Planning',
    ),
    (
      'A service level agreement states:',
      ['What is promised and how it is measured', 'Only the price', 'The supplier\'s holiday list', 'Nothing binding'],
      [0],
      'An SLA makes a service measurable, so both sides can tell whether it was delivered.',
      'Contracts',
    ),
  ];

  // Shared by every instance: the screens each build their own repository, and the history must carry across.
  static final List<Attempt> _attempts = [];
  static final List<ExamCertificate> _certificates = [];
  static final Map<String, AttemptResult> _results = {};

  static const _paper = PaperInfo(
    id: 'demo-paper',
    slug: 'demo-paper',
    title: 'Foundation',
    kind: PaperKind.assessment,
    level: 'FOUNDATION',
    description: 'A short sample paper on the basics of facility management.',
    durationMinutes: 10,
    passPercentage: 60,
    questionCount: 5,
    totalMarks: 5,
    certificateEnabled: true,
    courseCode: 'FMB',
    courseTitle: 'Facility Management Basics',
  );

  @override
  Future<PaperSitting> sitting(String slug) async => PaperSitting(
    paper: _paper,
    questions: [
      for (final (i, q) in _questions.indexed)
        ServedQuestion(
          id: 'demo-q$i',
          prompt: q.$1,
          options: q.$2,
          type: q.$3.length > 1 ? QuestionType.multiple : QuestionType.single,
          category: q.$5,
        ),
    ],
  );

  @override
  Future<PaperInfo> info(PaperRef ref) async => _paper;

  @override
  Future<PaperQuote> quote(String slug) async =>
      const PaperQuote(listPaisa: 0, salePaisa: 0, taxPaisa: 0, totalPaisa: 0, alreadyOpen: true, credits: 3);

  @override
  Future<RedeemResult> redeem(String slug) async => const RedeemResult(spent: 0, credits: 100);

  @override
  Future<void> openWithPlan({required String target, required String targetId}) async {}

  @override
  Future<List<Attempt>> attempts({String? paperId}) async => List.of(_attempts.reversed);

  @override
  Future<AttemptResult> attempt(String id) async => _results[id]!;

  @override
  Future<AttemptResult> submit(
    String slug, {
    required DateTime startedAt,
    required List<SubmittedAnswer> answers,
  }) async {
    var correct = 0;
    var wrong = 0;
    var skipped = 0;
    final review = <ReviewItem>[];
    for (final (i, q) in _questions.indexed) {
      final given = answers.where((a) => a.questionId == 'demo-q$i').firstOrNull?.selected ?? const <int>[];
      final item = ReviewItem(
        id: 'demo-q$i',
        prompt: q.$1,
        options: q.$2,
        correctIndexes: q.$3,
        selected: given,
        explanation: q.$4,
        category: q.$5,
      );
      switch (item.outcome) {
        case ReviewOutcome.correct:
          correct++;
        case ReviewOutcome.incorrect:
          wrong++;
        case ReviewOutcome.skipped:
          skipped++;
      }
      review.add(item);
    }
    final pct = (correct * 100 / _questions.length).round();
    final now = DateTime.now();
    final n = _attempts.length + 1;
    final attempt = Attempt(
      id: 'demo-attempt-$n',
      paperId: _paper.id,
      attempt: n,
      startedAt: startedAt,
      submittedAt: now,
      timeTakenMs: now.difference(startedAt).inMilliseconds,
      totalQuestions: _questions.length,
      correct: correct,
      wrong: wrong,
      unanswered: skipped,
      score: correct,
      maxScore: _questions.length,
      percentage: pct,
      passPercentage: _paper.passPercentage,
      passed: pct >= _paper.passPercentage,
      paper: const AttemptPaper(
        id: 'demo-paper',
        slug: 'demo-paper',
        title: 'Foundation',
        kind: PaperKind.assessment,
        level: 'FOUNDATION',
        certificateEnabled: true,
        courseCode: 'FMB',
        courseTitle: 'Facility Management Basics',
      ),
    );
    ExamCertificate? cert;
    if (attempt.passed) {
      cert =
          _certificates.firstOrNull ??
          ExamCertificate(
            id: 'demo-cert',
            certificateId: 'ICR-FMB-2026-DEMO0001',
            title: 'Facility Management Basics',
            paperId: _paper.id,
            level: 'FOUNDATION',
            issuedAt: now,
            clearedAt: now,
            attempt: n,
            percentage: pct,
            passPercentage: _paper.passPercentage,
            paperSlug: 'demo-paper',
            paperTitle: 'Foundation',
          );
      if (_certificates.isEmpty) _certificates.add(cert);
    }
    _attempts.add(attempt);
    return _results[attempt.id] = AttemptResult(attempt: attempt, review: review, certificate: cert);
  }

  @override
  Future<List<ExamCertificate>> certificates() async => List.of(_certificates);

  @override
  Future<ExamCertificate?> verifyCertificate(String certificateId) async {
    final wanted = certificateId.trim().toUpperCase();
    return _certificates.where((c) => c.certificateId == wanted).firstOrNull;
  }

  @override
  Future<int> unreadNotifications() async => 1;

  @override
  Uri sitePage(String path) => AppConfig.sitePage(path);
}
