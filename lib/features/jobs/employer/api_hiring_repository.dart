import 'package:dio/dio.dart' show Options;

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import 'hiring_models.dart';
import 'hiring_repository.dart';

/// The employer screens from the API, signed in as a member of the hiring team.
class ApiHiringRepository implements HiringRepository {
  ApiHiringRepository({required this.api, this.pageSize = 20});

  final ApiClient api;

  /// How many postings a page of the company's list holds.
  final int pageSize;

  List<JobTitleOption>? _titles;

  static const _sorts = {
    'recent': {'sortBy': 'createdAt', 'sortDir': 'desc'},
    'closing': {'sortBy': 'applyDeadline', 'sortDir': 'asc'},
    'applicants': {'sortBy': 'applicants', 'sortDir': 'desc'},
    'title': {'sortBy': 'title', 'sortDir': 'asc'},
  };

  @override
  Future<HiringAccess> access() async {
    final me = await _map('GET', '/auth/me');
    final user = (me['user'] as Map<String, dynamic>?) ?? me;
    var canPublish = true;
    String? note;
    // The gate is the hiring team's business: nobody else is asked.
    if (canHireWithRole(user['role'] as String?)) {
      try {
        final gate = await _map('GET', '/employer-verification/gate');
        canPublish = gate['canPublishJobs'] != false;
        note = gate['decisionNote'] as String?;
      } catch (_) {
        // The API decides on publish regardless.
      }
    }
    return HiringAccess(
      userId: '${user['id']}',
      role: user['role'] as String? ?? 'PROFESSIONAL',
      companyId: user['companyId'] as String?,
      canPublish: canPublish,
      publishNote: note,
    );
  }

  @override
  Future<PostedJobsPage> jobs({
    PostingStatus? status,
    String? search,
    bool mine = false,
    String sort = 'recent',
    int page = 1,
  }) async {
    final res = await _map('GET', '/jobs/company', null, {
      'page': page,
      'limit': pageSize,
      'status': ?status?.api,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (mine) 'mine': true,
      ...?_sorts[sort],
    });
    final counts = (res['statusCounts'] as Map?) ?? const {};
    return PostedJobsPage(
      jobs: [for (final row in _maps(res['data'])) PostedJob.fromJson(row)],
      hasMore: (res['meta'] as Map?)?['hasNext'] == true,
      total: (((res['meta'] as Map?)?['total']) as num?)?.toInt() ?? 0,
      statusCounts: {
        for (final s in PostingStatus.values)
          if (counts[s.api] is num) s: (counts[s.api] as num).toInt(),
      },
    );
  }

  @override
  Future<HiringOverview> overview() async => HiringOverview.fromJson(await _map('GET', '/jobs/company/overview'));

  @override
  Future<JobDraft> job(String id) async {
    final draft = JobDraft.fromJson(await _map('GET', '/jobs/$id'));
    List<ScreeningDraft> questions;
    try {
      questions = await screeningQuestions(id);
    } catch (_) {
      questions = const [];
    }
    return draft.copyWith(screening: questions);
  }

  @override
  Future<String> createJob(JobDraft draft, PostingStatus status) async {
    final res = await _map('POST', '/jobs', draft.toJson(status: status));
    return '${res['id']}';
  }

  @override
  Future<void> updateJob(String id, JobDraft draft, {PostingStatus? status}) async {
    // A save that moves nothing sends the posting's own status back, which the API treats as no change.
    await _send('PATCH', '/jobs/$id', draft.toJson(status: status));
  }

  @override
  Future<void> setStatus(String id, PostingStatus status) async {
    await _send('PATCH', '/jobs/$id', {'status': status.api});
  }

  @override
  Future<void> submitForReview(String id) async {
    await _send('POST', '/jobs/$id/submit-review');
  }

  @override
  Future<void> deleteJob(String id) async {
    await _send('DELETE', '/jobs/$id');
  }

  @override
  Future<List<JobTitleOption>> jobTitles() async {
    final cached = _titles;
    if (cached != null) return cached;
    final res = await _send('GET', '/job-titles');
    return _titles = [
      for (final t in (res as List? ?? const []).whereType<Map>())
        if (t['active'] != false) JobTitleOption('${t['name']}', t['jobFunction'] as String?),
    ];
  }

  @override
  Future<List<String>> skillSuggestions(String query) async {
    if (query.trim().length < 2) return const [];
    final res = await _send('GET', '/jobs/skill-suggestions', null, {'q': query.trim()});
    return [for (final s in (res as List? ?? const [])) s.toString()];
  }

  @override
  Future<List<ScreeningDraft>> screeningQuestions(String jobId) async {
    final res = await _send('GET', '/jobs/$jobId/screening-questions');
    return [
      for (final q in (res as List? ?? const []).whereType<Map>())
        ScreeningDraft.fromJson(Map<String, dynamic>.from(q)),
    ];
  }

  @override
  Future<void> setScreeningQuestions(String jobId, List<ScreeningDraft> questions) async {
    await _send('PUT', '/jobs/$jobId/screening-questions', {
      'questions': [for (final q in questions) q.toJson()],
    });
  }

  @override
  Future<ApplicantsPage> applicants(
    String jobId, {
    String? stage,
    String sort = 'recent',
    int? minRating,
    bool qualifiedOnly = false,
  }) async {
    final res = await _map('GET', '/jobs/$jobId/applications', null, {
      'limit': 100,
      'stage': ?stage,
      'sort': sort,
      'minRating': ?minRating,
      if (qualifiedOnly) 'qualifiedOnly': true,
    });
    final counts = (res['stageCounts'] as Map?) ?? const {};
    return ApplicantsPage(
      applicants: [for (final row in _maps(res['data'])) Applicant.fromJson(row, apiBase: api.dio.options.baseUrl)],
      stageCounts: {for (final e in counts.entries) '${e.key}': (e.value as num).toInt()},
    );
  }

  @override
  Future<ApplicantDetail> applicant(String applicationId) async {
    final results = await Future.wait([
      _map('GET', '/applications/$applicationId'),
      _send('GET', '/applications/$applicationId/events'),
    ]);
    final json = results[0] as Map<String, dynamic>;
    final events = results[1];
    final job = json['job'] as Map?;
    return ApplicantDetail(
      applicant: Applicant.fromJson(json, apiBase: api.dio.options.baseUrl),
      jobTitle: job?['title'] as String?,
      aiSummary: json['aiSummary'] as String?,
      answers: [
        for (final a in _maps(json['answers']))
          GradedAnswer(
            prompt: a['prompt'] as String? ?? '',
            answer: '${a['answer'] ?? ''}',
            type: a['type'] as String? ?? 'TEXT',
            meetsIdeal: a['graded'] == true ? a['meetsIdeal'] == true : null,
            mustHave: a['mustHave'] == true,
          ),
      ],
      interviews: [for (final i in _maps(json['interviews'])) TeamInterview.fromJson(i)]
        ..sort((a, b) => a.round.compareTo(b.round)),
      offers: [for (final o in _maps(json['offers'])) TeamOffer.fromJson(o)],
      events: [for (final e in _maps(events)) ActivityEvent.fromJson(e)]..sort((a, b) => b.at.compareTo(a.at)),
    );
  }

  @override
  Future<void> moveStage(String applicationId, String stage, {String? note}) async {
    await _send('PATCH', '/applications/$applicationId/stage', {
      'stage': stage,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  @override
  Future<void> addNote(String applicationId, {String? note, int? rating}) async {
    await _send('POST', '/applications/$applicationId/notes', {
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'rating': ?rating,
    });
  }

  @override
  Future<TeamInterview> scheduleInterview(String applicationId, InterviewDraft draft) async =>
      TeamInterview.fromJson(await _map('POST', '/applications/$applicationId/interviews', draft.toJson()));

  @override
  Future<TeamInterview> updateInterview(String interviewId, {InterviewDraft? draft, String? status}) async =>
      TeamInterview.fromJson(await _map('PATCH', '/interviews/$interviewId', {...?draft?.toJson(), 'status': ?status}));

  @override
  Future<TeamOffer> makeOffer(String applicationId, OfferDraft draft, {bool send = true}) async {
    final made = TeamOffer.fromJson(await _map('POST', '/applications/$applicationId/offers', draft.toJson()));
    if (!send) return made;
    return TeamOffer.fromJson(await _map('POST', '/offers/${made.id}/send'));
  }

  @override
  Future<TeamOffer> updateOffer(String offerId, OfferDraft draft) async =>
      TeamOffer.fromJson(await _map('PATCH', '/offers/$offerId', draft.toJson()));

  @override
  Future<TeamOffer> sendOffer(String offerId) async => TeamOffer.fromJson(await _map('POST', '/offers/$offerId/send'));

  @override
  Future<String?> messageApplicant(String applicationId) async {
    final res = await _map('POST', '/applications/$applicationId/conversation');
    return res['id'] as String?;
  }

  @override
  Future<List<TeamMember>> teamMembers() async {
    final res = await _send('GET', '/team/members');
    return [
      for (final m in (res as List? ?? const []).whereType<Map>())
        if (m['isActive'] != false)
          TeamMember(
            id: '${m['id']}',
            name: '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'.trim(),
            role: m['role'] as String? ?? '',
          ),
    ];
  }

  @override
  Future<int> unreadNotifications() async {
    final res = await _map('GET', '/notifications/unread-count');
    return (res['unread'] as num?)?.toInt() ?? 0;
  }

  // --- transport ------------------------------------------------------------------

  static List<Map<String, dynamic>> _maps(Object? v) =>
      (v as List? ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

  Future<Map<String, dynamic>> _map(
    String method,
    String path, [
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  ]) async {
    final res = await _send(method, path, body, query);
    return res is Map ? Map<String, dynamic>.from(res) : const {};
  }

  Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body, Map<String, dynamic>? query]) async {
    try {
      final res = await api.dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method),
      );
      return res.data;
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}
