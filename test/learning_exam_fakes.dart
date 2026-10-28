/// Stand-ins for the exam flow's tests: a clock the test moves, a repository that answers from the test, a
/// small world (a paper, its questions, a result, a certificate), and the API's recorded answers.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/features/learning_exam/api_exam_repository.dart';
import 'package:icr_mobile/features/learning_exam/exam_models.dart';
import 'package:icr_mobile/features/learning_exam/exam_repository.dart';

/// A recorded answer of the local API (`test/fixtures/learning_exam/`).
Object recorded(String name) => jsonDecode(File('test/fixtures/learning_exam/$name.json').readAsStringSync()) as Object;

/// A clock the test moves by hand.
class FakeClock {
  FakeClock([DateTime? start]) : now = start ?? DateTime(2026, 10, 23, 12);

  DateTime now;

  DateTime call() => now;

  void advance(Duration d) => now = now.add(d);
}

class NoTokens extends TokenStore {
  @override
  Future<String?> accessToken() async => 'token';
  @override
  Future<String?> refreshToken() async => null;
}

/// Answers each route from a table and records what was asked.
class RoutedApi implements HttpClientAdapter {
  RoutedApi(this.routes);

  /// `"GET /learning/papers/x"` to a function of the request returning the body (a `(status, json)` pair for another status).
  final Map<String, Object Function(RequestOptions options)> routes;
  final List<String> calls = [];
  final List<Object?> bodies = [];
  final List<Map<String, dynamic>> queries = [];

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    calls.add(key);
    bodies.add(options.data);
    queries.add(options.queryParameters);
    final handler = routes[key];
    if (handler == null) return ResponseBody.fromString('{"message":"Not found"}', 404, headers: _json);
    final result = handler(options);
    if (result is (int, Object)) return ResponseBody.fromString(jsonEncode(result.$2), result.$1, headers: _json);
    return ResponseBody.fromString(jsonEncode(result), 200, headers: _json);
  }

  @override
  void close({bool force = false}) {}
}

ApiExamRepository apiRepo(RoutedApi api) {
  final client = ApiClient(tokens: NoTokens(), baseUrl: 'http://api.test/api/v1');
  client.dio.httpClientAdapter = api;
  return ApiExamRepository(api: client);
}

// --- a small world -----------------------------------------------------------------------------------------

PaperInfo samplePaper({
  String slug = 'cp-foundation',
  String title = 'Foundation',
  PaperKind kind = PaperKind.assessment,
  int minutes = 30,
  int questions = 5,
  int pass = 70,
  int? attemptLimit,
  bool certificate = true,
  String? instructions,
  String? description,
  int? priceAmount,
  String? courseTitle,
}) => PaperInfo(
  id: 'paper-$slug',
  slug: slug,
  title: title,
  kind: kind,
  level: kind == PaperKind.assessment ? 'FOUNDATION' : null,
  durationMinutes: minutes,
  passPercentage: pass,
  questionCount: questions,
  totalMarks: questions,
  attemptLimit: attemptLimit,
  certificateEnabled: certificate,
  instructions: instructions,
  description: description,
  priceAmount: priceAmount,
  courseId: kind == PaperKind.assessment ? 'course-cp' : null,
  courseCode: kind == PaperKind.assessment ? 'CP' : null,
  courseTitle: kind == PaperKind.assessment ? (courseTitle ?? 'Capital Planning') : null,
  topicId: kind == PaperKind.mock ? 'topic-bemp' : null,
  topicSlug: kind == PaperKind.mock ? 'ashrae-bemp' : null,
  topicTitle: kind == PaperKind.mock ? 'ASHRAE BEMP' : null,
);

/// [n] questions of four options; the third is multiple-choice when [multipleAt] says so.
List<ServedQuestion> sampleQuestions(int n, {int? multipleAt}) => [
  for (var i = 0; i < n; i++)
    ServedQuestion(
      id: 'q${i + 1}',
      prompt: 'Question number ${i + 1}: what is right?',
      options: ['Option A${i + 1}', 'Option B${i + 1}', 'Option C${i + 1}', 'Option D${i + 1}'],
      type: i == multipleAt ? QuestionType.multiple : QuestionType.single,
      category: i.isEven ? 'Budgeting' : 'Governance',
    ),
];

PaperSitting sampleSitting({PaperInfo? paper, int questions = 5, int? multipleAt}) {
  final p = paper ?? samplePaper(questions: questions);
  return PaperSitting(
    paper: p,
    questions: sampleQuestions(questions, multipleAt: multipleAt),
  );
}

Attempt sampleAttempt({
  String id = 'att-1',
  int attempt = 1,
  int percentage = 80,
  int total = 5,
  int pass = 70,
  DateTime? startedAt,
  PaperInfo? paper,
}) {
  final p = paper ?? samplePaper();
  final correct = (total * percentage / 100).round();
  return Attempt(
    id: id,
    paperId: p.id,
    attempt: attempt,
    startedAt: startedAt ?? DateTime(2026, 10, 20, 9),
    submittedAt: DateTime(2026, 10, 20, 9, 12, 4),
    timeTakenMs: 724000,
    totalQuestions: total,
    correct: correct,
    wrong: total - correct,
    unanswered: 0,
    score: correct,
    maxScore: total,
    percentage: percentage,
    passPercentage: pass,
    passed: percentage >= pass,
    paper: AttemptPaper(
      id: p.id,
      slug: p.slug,
      title: p.title,
      kind: p.kind,
      level: p.level,
      certificateEnabled: p.certificateEnabled,
      topicSlug: p.topicSlug,
      topicTitle: p.topicTitle,
      courseCode: p.courseCode,
      courseTitle: p.courseTitle,
    ),
  );
}

ExamCertificate sampleCertificate({String id = 'cert-1', String number = 'ICR-CP-2026-AB12CD34', String? provider}) =>
    ExamCertificate(
      id: id,
      certificateId: number,
      title: 'Capital Planning',
      paperId: 'paper-cp-foundation',
      certificationCode: 'CP',
      level: 'FOUNDATION',
      providerName: provider,
      issuedAt: DateTime(2026, 8, 12),
      clearedAt: DateTime(2026, 8, 5),
      attempt: 2,
      percentage: 90,
      passPercentage: 70,
      paperSlug: 'cp-foundation',
      paperTitle: 'Foundation',
    );

/// A review of [n] questions: the first [right] answered right, the next one wrong, the next skipped.
List<ReviewItem> sampleReview(int n, {int right = 2}) => [
  for (var i = 0; i < n; i++)
    ReviewItem(
      id: 'q${i + 1}',
      prompt: 'Question number ${i + 1}: what is right?',
      options: ['Option A${i + 1}', 'Option B${i + 1}', 'Option C${i + 1}', 'Option D${i + 1}'],
      correctIndexes: const [1],
      selected: i < right ? const [1] : (i == right ? const [2] : const []),
      explanation: i.isEven ? 'Because B is the answer to number ${i + 1}.' : null,
      category: i.isEven ? 'Budgeting' : 'Governance',
    ),
];

AttemptResult sampleResult({
  int percentage = 80,
  int total = 5,
  bool withCertificate = false,
  int pass = 70,
  PaperInfo? paper,
}) {
  final a = sampleAttempt(percentage: percentage, total: total, pass: pass, paper: paper);
  return AttemptResult(
    attempt: a,
    review: sampleReview(total, right: a.correct),
    certificate: withCertificate ? sampleCertificate() : null,
  );
}

/// A repository whose answers the test sets, and that records its calls.
class FakeExam implements ExamRepository {
  FakeExam({this.sittingValue, this.lock, this.sittingError, this.infoValue});

  PaperSitting? sittingValue;
  PaperLock? lock;
  Object? sittingError;
  PaperInfo? infoValue;
  PaperQuote? quoteValue;
  List<Attempt> attemptsValue = [];
  final Map<String, AttemptResult> results = {};
  List<ExamCertificate> certificatesValue = [];
  Object? attemptsError;
  Object? certificatesError;
  Object? redeemError;
  Object? openError;
  int unread = 0;

  /// Decides what a submit does; the default scores nothing and returns [defaultResult].
  Future<AttemptResult> Function(String slug, DateTime startedAt, List<SubmittedAnswer> answers)? onSubmit;
  AttemptResult? defaultResult;

  final List<String> calls = [];
  final List<List<SubmittedAnswer>> submitted = [];
  final List<DateTime> submittedStarts = [];

  @override
  Future<PaperSitting> sitting(String slug) async {
    calls.add('sitting $slug');
    if (sittingError != null) throw sittingError!;
    if (lock != null) throw PaperLockedException(lock!);
    return sittingValue!;
  }

  @override
  Future<PaperInfo> info(PaperRef ref) async {
    calls.add('info ${ref.slug}');
    return infoValue ?? sittingValue!.paper;
  }

  @override
  Future<PaperQuote> quote(String slug) async {
    calls.add('quote $slug');
    return quoteValue ?? (throw ApiError('no quote'));
  }

  @override
  Future<RedeemResult> redeem(String slug) async {
    calls.add('redeem $slug');
    if (redeemError != null) throw redeemError!;
    lock = null;
    return const RedeemResult(spent: 4, credits: 176);
  }

  @override
  Future<void> openWithPlan({required String target, required String targetId}) async {
    calls.add('open $target $targetId');
    if (openError != null) throw openError!;
    lock = null;
  }

  @override
  Future<List<Attempt>> attempts({String? paperId}) async {
    calls.add('attempts ${paperId ?? 'all'}');
    if (attemptsError != null) throw attemptsError!;
    return List.of(attemptsValue);
  }

  @override
  Future<AttemptResult> attempt(String id) async {
    calls.add('attempt $id');
    return results[id] ?? (throw ApiError('Attempt not found', statusCode: 404));
  }

  @override
  Future<AttemptResult> submit(
    String slug, {
    required DateTime startedAt,
    required List<SubmittedAnswer> answers,
  }) async {
    calls.add('submit $slug');
    submitted.add(answers);
    submittedStarts.add(startedAt);
    final handler = onSubmit;
    if (handler != null) return handler(slug, startedAt, answers);
    return defaultResult ?? sampleResult();
  }

  @override
  Future<List<ExamCertificate>> certificates() async {
    calls.add('certificates');
    if (certificatesError != null) throw certificatesError!;
    return List.of(certificatesValue);
  }

  /// The certificates the register knows, by number.
  final Map<String, ExamCertificate> register = {};
  Object? verifyError;

  @override
  Future<ExamCertificate?> verifyCertificate(String certificateId) async {
    calls.add('verify $certificateId');
    if (verifyError != null) throw verifyError!;
    return register[certificateId.trim().toUpperCase()];
  }

  @override
  Future<int> unreadNotifications() async => unread;

  @override
  Uri sitePage(String path) => Uri.parse('https://icr.test$path');
}
