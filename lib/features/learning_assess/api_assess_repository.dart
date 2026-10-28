import 'package:dio/dio.dart' show Options;

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/config.dart';
import 'assess_models.dart';
import 'assess_repository.dart';

/// The Assess and Mock Exams screens from the API: programmes
/// (`GET /learning/courses?kind=ASSESSMENT` and `/learning/papers`), their detail
/// (`/learning/courses/:code`), mock subjects (`/learning/topics`), what the member
/// holds (`/me/paper-unlocks`, `/me/attempts`, `/me/certificates`), the quotes, and the
/// two things a member does here with no payment: spending ICR credits and opening a
/// course with a plan place.
class ApiAssessRepository implements AssessRepository {
  ApiAssessRepository({required this.api});

  final ApiClient api;

  // --- the catalogue ---------------------------------------------------------

  @override
  Future<List<PaperGroup>> groups(PaperKind kind) async {
    if (kind == PaperKind.mock) {
      final rows = await _list('/learning/topics');
      return [
        for (final t in rows)
          if ((t['papers'] as List? ?? const []).isNotEmpty) _topic(t),
      ];
    }
    final results = await Future.wait([
      _list('/learning/courses', {'kind': 'ASSESSMENT'}),
      _list('/learning/papers', {'kind': 'ASSESSMENT'}),
    ]);
    final byCourse = <String, List<AssessPaper>>{};
    for (final p in results[1]) {
      final paper = _paper(p);
      final course = paper.courseId;
      if (course != null) (byCourse[course] ??= []).add(paper);
    }
    return [
      for (final c in results[0])
        if ((byCourse[c['id']] ?? const []).isNotEmpty) _programme(c, byCourse[c['id']]!),
    ];
  }

  @override
  Future<PaperGroup> group(PaperKind kind, String key) async {
    if (kind == PaperKind.mock) return _topic(await _get('/learning/topics/${Uri.encodeComponent(key)}'));
    final json = await _get('/learning/courses/${Uri.encodeComponent(key)}');
    final papers = [
      for (final p in (json['papers'] as List? ?? const []).cast<Map<String, dynamic>>())
        if (p['kind'] == 'ASSESSMENT') _paper(p),
    ];
    return _programme(json, papers);
  }

  PaperGroup _programme(Map<String, dynamic> json, List<AssessPaper> papers) {
    final provider = json['provider'] as Map<String, dynamic>?;
    return PaperGroup(
      kind: PaperKind.assessment,
      id: json['id'] as String,
      key: json['code'] as String? ?? json['slug'] as String? ?? json['id'] as String,
      title: json['title'] as String? ?? '',
      summary: _text(json['summary']),
      cover:
          _picture(json['imageUrl'] as String?) ??
          papers.map((p) => p.cover).firstWhere((c) => c != null, orElse: () => null),
      knowledgeAreas: _strings(json['knowledgeAreas']),
      papers: papers,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      partner: provider == null ? null : (provider['name'] as String? ?? 'A partner institute'),
    );
  }

  PaperGroup _topic(Map<String, dynamic> json) {
    return PaperGroup(
      kind: PaperKind.mock,
      id: json['id'] as String,
      key: json['slug'] as String? ?? json['id'] as String,
      title: json['title'] as String? ?? '',
      summary: _text(json['description']),
      cover: _picture(json['imageUrl'] as String?),
      papers: [
        for (final p in (json['papers'] as List? ?? const []).cast<Map<String, dynamic>>())
          _paper(p, kind: PaperKind.mock, topicId: json['id'] as String?),
      ],
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  AssessPaper _paper(Map<String, dynamic> json, {PaperKind? kind, String? topicId}) {
    final served =
        (json['servedQuestions'] as num?) ?? (json['questionCount'] as num?) ?? (json['availableQuestions'] as num?);
    return AssessPaper(
      id: json['id'] as String,
      slug: json['slug'] as String? ?? json['id'] as String,
      title: json['title'] as String? ?? '',
      kind: kind ?? PaperKind.fromApi(json['kind'] as String?),
      subtitle: _text(json['subtitle']),
      description: _text(json['description']),
      level: _text(json['level']),
      free: json['access'] != 'PAID',
      priceAmount: (json['priceAmount'] as num?)?.toInt(),
      priceCurrency: json['priceCurrency'] as String? ?? 'INR',
      creditCost: (json['creditCost'] as num?)?.toInt(),
      questions: served?.toInt() ?? 0,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      passPercentage: (json['passPercentage'] as num?)?.toInt() ?? 0,
      attemptLimit: (json['attemptLimit'] as num?)?.toInt(),
      certificateEnabled: json['certificateEnabled'] == true,
      courseId: json['courseId'] as String?,
      topicId: json['topicId'] as String? ?? topicId,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      cover: _picture(json['imageUrl'] as String?),
    );
  }

  // --- the member ------------------------------------------------------------

  @override
  Future<MemberLearning> member(PaperKind kind) async {
    final results = await Future.wait<Object?>([
      _quietGet('/learning/me/paper-unlocks'),
      _quietList('/learning/me/attempts', {'kind': kind.api}),
      _quietList('/learning/me/certificates'),
    ]);
    final unlocks = results[0] as Map<String, dynamic>?;
    final attempts = results[1] as List<Map<String, dynamic>>;
    final certificates = results[2] as List<Map<String, dynamic>>;

    final progress = <String, PaperProgress>{};
    for (final a in attempts) {
      final paperId = a['paperId'] as String?;
      if (paperId == null) continue;
      progress[paperId] = (progress[paperId] ?? PaperProgress.none).withAttempt(
        percent: (a['percentage'] as num?)?.toInt() ?? 0,
        score: (a['score'] as num?)?.toInt(),
        maxScore: (a['maxScore'] as num?)?.toInt(),
        passed: a['passed'] == true,
        at: DateTime.tryParse(a['submittedAt'] as String? ?? ''),
      );
    }
    return MemberLearning(
      access: unlocks == null ? null : _access(unlocks),
      progress: progress,
      certified: {
        for (final c in certificates)
          if (c['paperId'] is String) c['paperId'] as String,
      },
    );
  }

  MemberAccess _access(Map<String, dynamic> json) {
    final plan = json['plan'] as Map<String, dynamic>? ?? const {};
    final courses = plan['assessmentCourses'] as Map<String, dynamic>? ?? const {};
    final mocks = plan['mockExams'] as Map<String, dynamic>? ?? const {};
    return MemberAccess(
      allOpen: json['allOpen'] == true,
      paperIds: _strings(json['paperIds']).toSet(),
      creditPaperIds: _strings(json['creditPaperIds']).toSet(),
      unlockedCourseIds: _strings(json['unlockedCourseIds']).toSet(),
      icrCredits: (json['icrCredits'] as num?)?.toInt() ?? 0,
      rupeesPerCredit: (json['rupeesPerCredit'] as num?)?.toInt() ?? 100,
      courses: PlanPlaces(limit: (courses['limit'] as num?)?.toInt(), opened: _strings(courses['openedCourseIds'])),
      mocks: PlanPlaces(limit: (mocks['limit'] as num?)?.toInt(), opened: _strings(mocks['openedTopicIds'])),
      upgradePlan: _text(plan['upgradePlan']),
      mockUpgradePlan: _text(plan['mockUpgradePlan']),
    );
  }

  // --- quotes ----------------------------------------------------------------

  @override
  Future<PaperQuote> quote(AssessPaper paper) async {
    final j = await _get('/learning/papers/${Uri.encodeComponent(paper.slug)}/quote');
    int n(String key) => (j[key] as num?)?.toInt() ?? 0;
    return PaperQuote(
      paperId: j['paperId'] as String? ?? paper.id,
      listPaisa: n('listPaisa'),
      discountBps: n('discountBps'),
      discountPaisa: n('discountPaisa'),
      salePaisa: n('salePaisa'),
      taxBps: n('taxBps'),
      taxPaisa: n('taxPaisa'),
      totalPaisa: n('totalPaisa'),
      currency: j['currency'] as String? ?? 'INR',
      payable: j['payable'] == true,
      alreadyOpen: j['alreadyOpen'] == true,
      memberDiscount: j['memberDiscount'] == true,
      memberPlan: _text(j['memberPlan']),
      credits: (j['credits'] as num?)?.toInt(),
      rupeesPerCredit: (j['rupeesPerCredit'] as num?)?.toInt() ?? 100,
    );
  }

  static String _bundlePath(PaperKind kind, String key) => kind == PaperKind.mock
      ? '/learning/mock-bundles/${Uri.encodeComponent(key)}'
      : '/learning/assessment-bundles/${Uri.encodeComponent(key)}';

  @override
  Future<BundleQuote> bundleQuote(String key, {PaperKind kind = PaperKind.assessment}) async {
    final j = await _get('${_bundlePath(kind, key)}/quote');
    int n(String name) => (j[name] as num?)?.toInt() ?? 0;
    return BundleQuote(
      courseCode: j['courseCode'] as String? ?? key,
      kind: kind,
      offered: j['offered'] == true,
      payable: j['payable'] == true,
      programmeTitle: j['programmeTitle'] as String? ?? '',
      levels: [
        for (final l in (j['levels'] as List? ?? const []).cast<Map<String, dynamic>>())
          l['title'] as String? ?? assessLevelLabel(l['level'] as String?) ?? '',
      ],
      separateSalePaisa: n('separateSalePaisa'),
      salePaisa: n('salePaisa'),
      savePaisa: n('savePaisa'),
      discountBps: n('discountBps'),
      currency: j['currency'] as String? ?? 'INR',
      offerEndsOn: _text(j['offerEndsOn']),
      // The credit bundle: absent from an API that has not got it yet.
      credits: (j['credits'] as num?)?.toInt(),
      separateCredits: (j['separateCredits'] as num?)?.toInt(),
      creditsSaved: n('creditsSaved'),
      creditsOffered: j['creditsOffered'] == true,
      creditLevels: [
        for (final l in (j['creditLevels'] as List? ?? const []).cast<Map<String, dynamic>>())
          BundleLevel(
            paperId: l['paperId'] as String? ?? '',
            title: l['title'] as String? ?? assessLevelLabel(l['level'] as String?) ?? '',
            level: _text(l['level']),
            credits: (l['credits'] as num?)?.toInt(),
          ),
      ],
    );
  }

  @override
  Future<RedeemBundleResult> redeemBundle(PaperKind kind, String key) async {
    final res = await _send('POST', '${_bundlePath(kind, key)}/redeem');
    final j = res is Map<String, dynamic> ? res : const <String, dynamic>{};
    return RedeemBundleResult(
      spent: (j['spent'] as num?)?.toInt() ?? 0,
      credits: (j['credits'] as num?)?.toInt() ?? 0,
      paperIds: _strings(j['paperIds']),
      unlockedCourseIds: _strings(j['unlockedCourseIds']),
    );
  }

  @override
  Future<AssessmentPricing> pricing() async {
    final j = await _get('/learning/assessment-pricing');
    return AssessmentPricing(
      discountPercent: (j['discountPercent'] as num?)?.toInt() ?? 0,
      bundleDiscountPercent: (j['bundleDiscountPercent'] as num?)?.toInt() ?? 0,
    );
  }

  // --- what the member does here ---------------------------------------------

  @override
  Future<RedeemResult> redeem(AssessPaper paper) async {
    final res = await _send('POST', '/learning/papers/${Uri.encodeComponent(paper.slug)}/redeem');
    final j = res is Map<String, dynamic> ? res : const <String, dynamic>{};
    return RedeemResult(
      unlocked: j['unlocked'] != false,
      spent: (j['spent'] as num?)?.toInt() ?? 0,
      credits: (j['credits'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> openWithPlan(PaperKind kind, String targetId) async {
    await _send('POST', '/learning/me/opens', {
      'target': kind == PaperKind.mock ? 'MOCK_EXAM' : 'COURSE',
      'targetId': targetId,
    });
  }

  @override
  Future<int> unreadNotifications() async {
    final res = await _get('/notifications/unread-count');
    return (res['unread'] as num?)?.toInt() ?? 0;
  }

  // --- links -----------------------------------------------------------------

  @override
  Uri paperLink(PaperGroup group, AssessPaper paper) => AppConfig.sitePage(
    group.kind == PaperKind.mock
        ? '/learning/mock-tests/${group.key}/${paper.slug}'
        : '/learning/assessment/${group.key.toLowerCase()}/${paper.slug}',
  );

  @override
  Uri groupLink(PaperGroup group) => AppConfig.sitePage(
    group.kind == PaperKind.mock
        ? '/learning/mock-tests/${group.key}'
        : '/learning/assessment/${group.key.toLowerCase()}',
  );

  @override
  Uri plansLink() => AppConfig.sitePage('/pricing/professional');

  @override
  Uri partnerLink() => AppConfig.sitePage('/learning/professional-development');

  // --- mapping helpers -------------------------------------------------------

  static String? _text(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  static List<String> _strings(Object? v) =>
      (v as List? ?? const []).map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();

  FeedPicture? _picture(String? path) {
    final url = AppConfig.absoluteUrl(path, apiBase: api.dio.options.baseUrl);
    return url == null ? null : FeedPicture.network(url);
  }

  // --- transport -------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _list(String path, [Map<String, dynamic>? query]) async {
    try {
      final res = await api.dio.get<dynamic>(path, queryParameters: query);
      final data = res.data;
      final rows = data is List ? data : (data is Map ? data['data'] as List? : null);
      return (rows ?? const []).cast<Map<String, dynamic>>();
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? query]) async {
    try {
      final res = await api.dio.get<Map<String, dynamic>>(path, queryParameters: query);
      return res.data ?? const {};
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  /// A read the screen can do without: null (or empty) when it fails.
  Future<Map<String, dynamic>?> _quietGet(String path) async {
    try {
      return await _get(path);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _quietList(String path, [Map<String, dynamic>? query]) async {
    try {
      return await _list(path, query);
    } catch (_) {
      return const [];
    }
  }

  Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body]) async {
    try {
      final res = await api.dio.request<dynamic>(
        path,
        data: body,
        options: Options(method: method),
      );
      return res.data;
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}
