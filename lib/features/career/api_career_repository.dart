import 'package:dio/dio.dart' show Options;

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/config.dart';
import '../jobs/api_jobs_repository.dart';
import '../jobs/jobs_repository.dart';
import 'career_models.dart';
import 'career_repository.dart';

/// The career screens from the API, signed in as the member.
class ApiCareerRepository implements CareerRepository {
  ApiCareerRepository({required this.api, ApiJobsRepository? jobs, this.pageSize = insightsPageSize})
    : _jobs = jobs ?? ApiJobsRepository(api: api);

  final ApiClient api;
  final ApiJobsRepository _jobs;

  /// How many rows a page of a company's reviews, interviews, people or jobs holds
  /// (a test makes it small to page through a short list).
  final int pageSize;

  @override
  JobsRepository get jobs => _jobs;

  /// How many hidden jobs the Hidden jobs screen reads one by one.
  static const hiddenMax = 30;

  @override
  Future<List<CareerApplication>> applications() async {
    final res = await _send('GET', '/applications/mine');
    return [for (final row in _maps(res)) application_(row)];
  }

  @override
  Future<CareerApplication> application(String id) async => application_(await _map('GET', '/applications/$id'));

  @override
  Future<CareerApplication> withdraw(String id) async => application_(await _map('POST', '/applications/$id/withdraw'));

  @override
  Future<void> respondToOffer(String offerId, {required bool accept, String? note}) async {
    await _send('POST', '/offers/$offerId/respond', {
      'accept': accept,
      if (note != null && note.trim().isNotEmpty) 'candidateNote': note.trim(),
    });
  }

  @override
  Future<String?> messageHiringTeam(String jobId, {String? message}) async {
    final res = await _map('POST', '/messaging/conversations/job', {
      'jobId': jobId,
      if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
    });
    return res['id'] as String?;
  }

  @override
  Future<List<JobInvite>> invites() async {
    final res = await _send('GET', '/job-invites/mine');
    return [
      for (final row in _maps(res))
        () {
          final job = row['job'] as Map<String, dynamic>? ?? const {};
          final by = row['invitedBy'] as Map<String, dynamic>?;
          return JobInvite(
            id: row['id'].toString(),
            jobId: (job['id'] ?? row['jobId']).toString(),
            jobTitle: job['title'] as String? ?? 'A job on ICR',
            status: row['status'] as String? ?? 'SENT',
            createdAt: _date(row['createdAt']) ?? DateTime.now(),
            companyName: (job['company'] as Map?)?['name'] as String?,
            city: job['city'] as String?,
            workMode: WorkMode.fromApi(job['workMode'] as String?),
            message: row['message'] as String?,
            invitedBy: by == null ? null : '${by['firstName'] ?? ''} ${by['lastName'] ?? ''}'.trim(),
          );
        }(),
    ];
  }

  @override
  Future<void> respondToInvite(String id, {required bool decline}) async {
    await _send('PATCH', '/job-invites/$id', {'status': decline ? 'DECLINED' : 'VIEWED'});
  }

  @override
  Future<bool?> discoverable() async {
    final res = await _map('GET', '/users/me/profile');
    final resume = res['resume'] as Map<String, dynamic>?;
    if (resume == null) return null;
    return resume['discoverable'] != false;
  }

  @override
  Future<void> setDiscoverable(bool on) async {
    await _send('PATCH', '/users/me/resume', {'discoverable': on});
  }

  @override
  Future<List<JobAlert>> alerts() async => [for (final row in _maps(await _send('GET', '/jobs/alerts'))) alert(row)];

  @override
  Future<JobAlert> createAlert({
    required String name,
    required Map<String, String> criteria,
    bool alertsEnabled = true,
    String frequency = 'DAILY',
  }) async => alert(
    await _map('POST', '/jobs/alerts', {
      'name': name.trim(),
      'criteria': criteria,
      'alertsEnabled': alertsEnabled,
      'frequency': frequency,
    }),
  );

  @override
  Future<JobAlert> updateAlert(
    String id, {
    String? name,
    Map<String, String>? criteria,
    bool? alertsEnabled,
    String? frequency,
  }) async => alert(
    await _map('PATCH', '/jobs/alerts/$id', {
      if (name != null) 'name': name.trim(),
      'criteria': ?criteria,
      'alertsEnabled': ?alertsEnabled,
      'frequency': ?frequency,
    }),
  );

  @override
  Future<void> deleteAlert(String id) async {
    await _send('DELETE', '/jobs/alerts/$id');
  }

  @override
  Future<JobPage> runAlert(String id, {int page = 1}) async {
    await _jobs.loadFlags();
    return _page('/jobs/alerts/$id/run', {'page': page, 'limit': 20});
  }

  @override
  Future<JobPage> savedJobs({int page = 1}) async {
    final res = await _page('/jobs/saved', {'page': page, 'limit': 30});
    return JobPage(jobs: [for (final j in res.jobs) j.copyWith(saved: true)], hasMore: res.hasMore);
  }

  @override
  Future<List<Job>> hiddenJobs() async {
    final actions = await _map('GET', '/jobs/actions');
    final ids = (actions['hiddenIds'] as List? ?? const []).map((e) => e.toString()).take(hiddenMax).toList();
    final jobs = await Future.wait(
      ids.map((id) async {
        try {
          return _jobs.job(await _map('GET', '/jobs/$id'));
        } on ApiError catch (e) {
          // A job that closed since is a 404 to someone outside its team: it still
          // counts as hidden, with nothing to show but that it is gone.
          if (e.statusCode == 404) {
            return Job(
              id: id,
              title: 'A job that is no longer open',
              company: const JobCompany(id: '', name: 'Closed'),
              status: 'CLOSED',
            );
          }
          rethrow;
        }
      }),
    );
    return jobs;
  }

  @override
  Future<SeekerQuota?> quota() => _jobs.quota();

  @override
  Future<({int saved, int hidden})> shelfCounts() async {
    final actions = await _map('GET', '/jobs/actions');
    return (
      saved: (actions['savedIds'] as List? ?? const []).length,
      hidden: (actions['hiddenIds'] as List? ?? const []).length,
    );
  }

  @override
  Future<ResumeInsights?> resumeInsights() async {
    final res = await _map('GET', '/users/me/resume/insights');
    if (res.isEmpty) return null;
    return ResumeInsights(
      score: (res['score'] as num?)?.round(),
      missing: [for (final m in (res['missing'] as List? ?? const [])) m.toString()],
    );
  }

  @override
  Future<ProfilePerformance?> profilePerformance() async {
    final res = await _map('GET', '/users/me/profile-performance');
    if (res.isEmpty) return null;
    int n(String k) => (res[k] as num?)?.toInt() ?? 0;
    return ProfilePerformance(
      searchAppearances30d: n('searchAppearances30d'),
      profileViews30d: n('profileViews30d'),
      invites: n('invites'),
      applicationsViewed: n('applicationsViewed'),
    );
  }

  @override
  Future<int> unreadNotifications() => _jobs.unreadNotifications();

  @override
  Future<JobCompany?> company(String companyId) async {
    final res = await _map('GET', '/companies/$companyId');
    return res.isEmpty ? null : _jobs.companyDetail(res);
  }

  @override
  Future<RatingSummary> ratingSummary(String companyId) async {
    final res = await _map('GET', '/companies/$companyId/rating-summary');
    final dist = res['distribution'] as Map? ?? const {};
    final subs = res['subRatings'] as Map? ?? const {};
    return RatingSummary(
      count: (res['count'] as num?)?.toInt() ?? 0,
      average: (res['average'] as num?)?.toDouble(),
      distribution: {for (final e in dist.entries) int.parse('${e.key}'): (e.value as num).toInt()},
      subRatings: {
        for (final e in reviewSubRatings.entries)
          if (subs[e.key] is num) e.value: (subs[e.key] as num).toDouble(),
      },
    );
  }

  @override
  Future<InsightPage<EmployerReview>> reviews(String companyId, {int page = 1}) async {
    final res = await _map('GET', '/companies/$companyId/reviews', null, {'page': page, 'limit': pageSize});
    return InsightPage(
      items: [for (final r in _maps(res['data'])) review(r)],
      hasMore: _hasNext(res),
      total: _total(res),
    );
  }

  @override
  Future<EmployerReview?> myReview(String companyId) async {
    final res = await _send('GET', '/companies/$companyId/reviews/mine');
    // Nest answers a missing row with an empty body.
    return res is Map ? review(Map<String, dynamic>.from(res)) : null;
  }

  @override
  Future<void> submitReview(String companyId, ReviewDraft draft) async {
    await _send('POST', '/companies/$companyId/reviews', draft.toJson());
  }

  @override
  Future<SalaryInsights> salaries(String companyId) async {
    final res = await _map('GET', '/companies/$companyId/salaries');
    return SalaryInsights(
      minSample: (res['minSample'] as num?)?.toInt() ?? 5,
      totalReports: (res['totalReports'] as num?)?.toInt() ?? 0,
      roles: [
        for (final r in _maps(res['roles']))
          SalaryRole(
            jobTitle: r['jobTitle'] as String? ?? '',
            count: (r['count'] as num?)?.toInt() ?? 0,
            p25: (r['p25'] as num?)?.toDouble() ?? 0,
            median: (r['median'] as num?)?.toDouble() ?? 0,
            p75: (r['p75'] as num?)?.toDouble() ?? 0,
            avgExperience: (r['avgExperience'] as num?)?.toDouble(),
          ),
      ],
    );
  }

  @override
  Future<void> submitSalary(String companyId, SalaryDraft draft) async {
    await _send('POST', '/companies/$companyId/salaries', draft.toJson());
  }

  @override
  Future<InsightPage<InterviewReview>> interviewReviews(String companyId, {int page = 1}) async {
    final res = await _map('GET', '/companies/$companyId/interview-reviews', null, {'page': page, 'limit': pageSize});
    final avg = res['averages'] as Map? ?? const {};
    return InsightPage(
      items: [
        for (final r in _maps(res['data']))
          InterviewReview(
            id: r['id'].toString(),
            createdAt: _date(r['createdAt']) ?? DateTime.now(),
            jobTitle: r['jobTitle'] as String?,
            difficulty: (r['difficulty'] as num?)?.toInt(),
            experienceRating: (r['experienceRating'] as num?)?.toInt(),
            outcome: r['outcome'] as String?,
            process: r['processDescription'] as String?,
            questions: r['questionsAsked'] as String?,
            durationDays: (r['durationDays'] as num?)?.toInt(),
          ),
      ],
      hasMore: _hasNext(res),
      total: _total(res),
      averages: {
        if (avg['difficulty'] is num) 'difficulty': (avg['difficulty'] as num).toDouble(),
        if (avg['experience'] is num) 'experience': (avg['experience'] as num).toDouble(),
      },
    );
  }

  @override
  Future<void> submitInterviewReview(String companyId, InterviewReviewDraft draft) async {
    await _send('POST', '/companies/$companyId/interview-reviews', draft.toJson());
  }

  @override
  Future<InsightPage<CompanyPerson>> people(String companyId, {int page = 1}) async {
    final res = await _map('GET', '/companies/$companyId/people', null, {'page': page, 'limit': pageSize});
    return InsightPage(
      items: [
        for (final r in _maps(res['data']))
          CompanyPerson(
            id: r['id'].toString(),
            name: '${r['firstName'] ?? ''} ${r['lastName'] ?? ''}'.trim(),
            headline: r['headline'] as String?,
            photo: _picture(r['avatarUrl'] as String?),
          ),
      ],
      hasMore: _hasNext(res),
      total: _total(res),
    );
  }

  @override
  Future<JobPage> companyJobs(String companyId, {int page = 1}) async {
    await _jobs.loadFlags();
    return _page('/jobs', {'companyId': companyId, 'page': page, 'limit': pageSize});
  }

  /// The default page size of a company's reviews, interviews, people and jobs.
  static const insightsPageSize = 10;

  static bool _hasNext(Map<String, dynamic> res) => (res['meta'] as Map?)?['hasNext'] == true;

  static int? _total(Map<String, dynamic> res) => ((res['meta'] as Map?)?['total'] as num?)?.toInt();

  /// One review as the API's public select (or the author's own row) gives it.
  EmployerReview review(Map<String, dynamic> r) => EmployerReview(
    id: r['id'].toString(),
    rating: (r['overallRating'] as num?)?.toInt() ?? 0,
    createdAt: _date(r['createdAt']) ?? DateTime.now(),
    title: r['title'] as String?,
    pros: r['pros'] as String?,
    cons: r['cons'] as String?,
    advice: r['advice'] as String?,
    jobTitle: r['jobTitle'] as String?,
    employmentStatus: r['employmentStatus'] as String?,
    verifiedEmployee: r['isVerifiedEmployee'] == true,
    status: r['status'] as String?,
    subRatings: {
      for (final e in const {
        'workLife': 'ratingWorkLife',
        'compensation': 'ratingCompensation',
        'culture': 'ratingCulture',
        'management': 'ratingManagement',
        'growth': 'ratingGrowth',
      }.entries)
        if (r[e.value] is num) e.key: (r[e.value] as num).toInt(),
    },
  );

  // --- mapping -------------------------------------------------------------

  JobAlert alert(Map<String, dynamic> row) {
    final raw = row['criteria'] as Map? ?? const {};
    return JobAlert(
      id: row['id'].toString(),
      name: row['name'] as String? ?? 'Saved search',
      criteria: {
        for (final e in raw.entries)
          if (e.value != null && '${e.value}'.trim().isNotEmpty)
            '${e.key}': e.value is List ? (e.value as List).join(',') : '${e.value}',
      },
      alertsEnabled: row['alertsEnabled'] != false,
      frequency: row['frequency'] as String? ?? 'DAILY',
      newMatches: (row['newMatchCount'] as num?)?.toInt() ?? 0,
    );
  }

  // ignore: non_constant_identifier_names
  CareerApplication application_(Map<String, dynamic> json) {
    final job = json['job'] as Map<String, dynamic>? ?? const {};
    final company = job['company'] as Map<String, dynamic>? ?? const {};
    final signalsRaw = json['signals'];
    return CareerApplication(
      id: json['id'].toString(),
      jobId: (json['jobId'] ?? job['id']).toString(),
      jobTitle: job['title'] as String? ?? 'A job on ICR',
      companyId: job['companyId'] as String?,
      companyName: company['name'] as String?,
      companyLogo: _picture(company['logoUrl'] as String?),
      city: job['city'] as String?,
      jobStatus: job['status'] as String? ?? 'OPEN',
      stage: json['stage'] as String? ?? 'APPLIED',
      createdAt: _date(json['createdAt']) ?? DateTime.now(),
      viewedAt: _date(json['viewedAt']),
      withdrawnAt: _date(json['withdrawnAt']),
      resumeTitle: (json['resume'] as Map?)?['title'] as String?,
      coverNote: json['coverNote'] as String?,
      linkedinUrl: json['linkedinUrl'] as String?,
      expectedSalary: num.tryParse('${json['expectedSalary'] ?? ''}'),
      matchScore: (json['matchScore'] as num?)?.round(),
      events: [for (final e in _maps(json['events'])) CareerEvent.fromJson(e)],
      offers: [for (final o in _maps(json['offers'])) CareerOffer.fromJson(o)],
      interviews: [for (final i in _maps(json['interviews'])) CareerInterview.fromJson(i)]
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt)),
      answers: [
        for (final a in _maps(json['answers']))
          SentAnswer(
            prompt: a['prompt'] as String? ?? '',
            answer: '${a['answer'] ?? ''}',
            type: ScreeningType.fromApi(a['type'] as String?),
          ),
      ],
      signals: signalsRaw is List
          ? [
              for (final s in signalsRaw.whereType<Map>())
                MatchSignal(
                  label: s['label'] as String? ?? '${s['key']}',
                  score: (s['score'] as num?)?.toDouble() ?? 0,
                  detail: s['detail'] as String?,
                ),
            ]
          : null,
      signalsLocked: json['signalsLocked'] == true,
      visibilityLocked: json['visibilityLocked'] == true,
      applicantId: json['applicantId'] as String?,
    );
  }

  static List<Map<String, dynamic>> _maps(Object? v) =>
      (v as List? ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

  static DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

  FeedPicture? _picture(String? path) {
    final url = AppConfig.absoluteUrl(path, apiBase: api.dio.options.baseUrl);
    return url == null ? null : FeedPicture.network(url);
  }

  // --- transport -------------------------------------------------------------

  Future<JobPage> _page(String path, Map<String, dynamic> query) async {
    final res = await _map('GET', path, null, query);
    final meta = res['meta'] as Map<String, dynamic>? ?? const {};
    return JobPage(jobs: [for (final row in _maps(res['data'])) _jobs.job(row)], hasMore: meta['hasNext'] == true);
  }

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
