import 'dart:math' as math;

import 'package:dio/dio.dart' show Options;

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/config.dart';
import 'job_format.dart';
import 'job_models.dart';
import 'job_requirements.dart';
import 'jobs_repository.dart';

/// The `GET /jobs` query for a search over the board: the saved search's own
/// filters (the board's scope), then what the member typed or picked, which
/// wins where the two name the same thing.
Map<String, dynamic> jobsQuery(JobFilters filters, {JobContext? scope, int page = 1, int limit = 20}) {
  final query = <String, dynamic>{};
  scope?.criteria.forEach((key, value) {
    if (key == 'city' && filters.hasCity) return;
    query[key] = value;
  });
  query['page'] = page;
  query['limit'] = limit;
  if (filters.search.isNotEmpty) query['search'] = filters.search;
  if (filters.postedWithinDays != null) query['postedWithinDays'] = filters.postedWithinDays;
  if (filters.workModes.isNotEmpty) query['workMode'] = filters.workModes.map((m) => m.name.toUpperCase()).join(',');
  if (filters.employmentTypes.isNotEmpty) {
    query['employmentType'] = filters.employmentTypes.map(_employmentKey).join(',');
  }
  if (filters.hasCity) query['city'] = filters.city;
  return query;
}

String _employmentKey(EmploymentType t) => switch (t) {
  EmploymentType.fullTime => 'FULL_TIME',
  EmploymentType.partTime => 'PART_TIME',
  _ => t.name.toUpperCase(),
};

/// The Jobs screens from the API: the board (`GET /jobs`), the member's
/// recommendations (`GET /jobs/recommended`), a job (`GET /jobs/:id`) and
/// the member's own bookmarks, applications and alerts.
class ApiJobsRepository implements JobsRepository {
  /// [pageSize] is how many jobs a page of `GET /jobs` holds (20; a test makes
  /// it small to page through a short list).
  ApiJobsRepository({required this.api, this.pageSize = 20});

  final ApiClient api;
  final int pageSize;

  Set<String>? _savedIds;
  Set<String>? _appliedIds;
  int _openApplications = 0;

  /// The saved search of the last overview, for paging its section.
  JobContext? _alert;

  /// How many jobs a recommended section holds before "View More", and the most
  /// the API will give (`limit` is capped at 24).
  static const _recommendedPage = 12;
  static const _recommendedMax = 24;

  @override
  Future<JobsOverview> overview({bool scoped = true}) async {
    await _flags(force: true);
    final results = await Future.wait([
      _recommended('foryou', _recommendedPage),
      _recommended('preferences', _recommendedPage),
      _alerts(),
    ]);
    final recommended = results[0] as _Recommended;
    final preferred = results[1] as _Recommended;
    final alerts = results[2] as _Alerts;
    _alert = alerts.context;
    final sections = <JobSection>[
      if (recommended.jobs.isNotEmpty)
        JobSection(
          key: 'foryou',
          title: 'Recommended Jobs for You',
          jobs: recommended.jobs,
          hasMore: recommended.hasMore,
        ),
      if (preferred.jobs.isNotEmpty)
        JobSection(
          key: 'preferences',
          title: 'Matching your preferences',
          jobs: preferred.jobs,
          hasMore: preferred.hasMore,
        ),
    ];
    // The saved search's results are read from the board (`GET /jobs` with its
    // filters), not run (`/run`), so opening the board never counts the
    // search's new matches as seen: tapping Alerts does.
    final scope = scoped ? alerts.context : null;
    JobPage? page;
    if (scope != null) {
      try {
        page = await _page('/jobs', {...scope.criteria, 'page': 1, 'limit': pageSize});
      } catch (_) {
        // Filters the board does not take: fall back to the latest jobs.
      }
    }
    if (page != null) {
      sections.add(JobSection(key: 'alert', title: scope!.label, jobs: page.jobs, hasMore: page.hasMore));
    } else {
      final latest = await _page('/jobs', {'page': 1, 'limit': pageSize});
      sections.add(JobSection(key: 'latest', title: 'Latest jobs', jobs: latest.jobs, hasMore: latest.hasMore));
    }
    return JobsOverview(
      sections: sections,
      myJobs: _openApplications,
      newAlerts: alerts.newMatches,
      alert: alerts.context,
    );
  }

  @override
  Future<JobPage> latest({int page = 1}) => _page('/jobs', {'page': page, 'limit': pageSize});

  @override
  Future<JobPage> more(JobSection section, int page) => switch (section.key) {
    'latest' => latest(page: page),
    'alert' => _page('/jobs', {...?_alert?.criteria, 'page': page, 'limit': pageSize}),
    'foryou' || 'preferences' => _recommendedMore(section.key, page),
    _ => Future.value(const JobPage(jobs: [], hasMore: false)),
  };

  Future<JobPage> _recommendedMore(String mode, int page) async {
    final limit = math.min(_recommendedMax, _recommendedPage * page);
    final all = await _recommended(mode, limit);
    return JobPage(jobs: all.jobs.skip(_recommendedPage * (page - 1)).toList(), hasMore: all.hasMore);
  }

  @override
  Future<JobPage> runAlert(JobContext alert) {
    return _page('/jobs/alerts/${alert.alertId}/run', {'page': 1, 'limit': pageSize});
  }

  @override
  Future<int> newAlertMatches() async => (await _alerts()).newMatches;

  @override
  Future<JobPage> search(JobFilters filters, {int page = 1, JobContext? scope}) async {
    await _flags();
    return _page('/jobs', jobsQuery(filters, scope: scope, page: page, limit: pageSize));
  }

  @override
  Future<MyJobs> myJobs() async {
    await _flags(force: true);
    final res = await _send('GET', '/applications/mine');
    final rows = (res as List? ?? const []).cast<Map<String, dynamic>>();
    final saved = await _page('/jobs/saved', {'page': 1, 'limit': 50});
    return MyJobs(
      applications: [for (final row in rows) _application(row)].where((a) => a.open).toList(),
      saved: [for (final job in saved.jobs) job.copyWith(saved: true)],
    );
  }

  @override
  Future<Job> detail(String id) async {
    await _flags();
    final json = await _get('/jobs/$id');
    var job = _job(json);
    try {
      final company = await _get('/companies/${job.company.id}');
      job = job.copyWith(company: job.company.merge(_companyDetail(company)));
    } catch (_) {
      // The job's own company block is enough.
    }
    return job;
  }

  @override
  Future<JobMatch?> match(Job job) async {
    try {
      final res = await _get('/jobs/${job.id}/match-preview');
      final signals = (res['signals'] as List? ?? const []).cast<Map<String, dynamic>>();
      if (signals.isNotEmpty) {
        return JobMatch(
          score: (res['matchScore'] as num?)?.toInt() ?? job.matchScore,
          checks: [
            for (final s in signals)
              MatchCheck(
                label: s['label'] as String? ?? s['key'] as String? ?? '',
                detail: s['detail'] as String?,
                met: ((s['score'] as num?)?.toDouble() ?? 0) >= 0.5,
              ),
          ],
        );
      }
    } on ApiError catch (e) {
      // 403 is "not on Career Pro" and 404 a job the scorer does not know. The
      // scorer being down (a 500) is no reason to lose the card either: the
      // comparison below stands in. Only a lapsed session is rethrown.
      if (e.statusCode == 401) rethrow;
    }
    // Without Career Pro, or without the scorer: what the job asks for, held
    // against what the member's profile says.
    final checks = requirementChecks(job, await _memberFacts());
    if (checks.isEmpty) return job.matchScore == null ? null : JobMatch(score: job.matchScore, locked: true);
    return JobMatch(score: job.matchScore, locked: true, checks: checks);
  }

  /// What the member's profile says: years, skills (`GET /users/me/profile`),
  /// education (`GET /profile/education`) and credentials (`GET /credentials/me`).
  /// A part that cannot be read counts as empty.
  Future<MemberFacts> _memberFacts() async {
    Future<dynamic> read(String path) async {
      try {
        return await _send('GET', path);
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([read('/users/me/profile'), read('/profile/education'), read('/credentials/me')]);
    final profile = results[0] is Map ? Map<String, dynamic>.from(results[0] as Map) : const <String, dynamic>{};
    final resume = profile['resume'] as Map<String, dynamic>?;
    final education = results[1] is List ? results[1] as List : const [];
    final credentials = results[2] is Map ? (results[2] as Map)['credentials'] : null;
    return MemberFacts(
      years: _num(resume?['yearsExperience']),
      skills: {for (final s in resume?['skills'] as List? ?? const []) s.toString().trim().toLowerCase()},
      education: [
        for (final e in education.whereType<Map>())
          EducationEntry(
            degree: e['degree'] as String?,
            field: e['fieldOfStudy'] as String?,
            institution: e['institution'] as String?,
          ),
      ],
      credentials: [
        for (final c in (credentials is List ? credentials : const []).whereType<Map>())
          [c['name'], c['title'], c['issuer']].whereType<String>().join(' '),
      ],
    );
  }

  @override
  Future<CompanyPeople?> peopleAt(JobCompany company) async {
    try {
      final res = await _get('/companies/${company.id}/people', {'page': 1, 'limit': 5});
      final rows = (res['data'] as List? ?? const []).cast<Map<String, dynamic>>();
      final total = ((res['meta'] as Map<String, dynamic>?)?['total'] as num?)?.toInt() ?? rows.length;
      if (rows.isEmpty) return null;
      return CompanyPeople(
        names: [for (final r in rows) _shortName(r['firstName'] as String?, r['lastName'] as String?)],
        photos: [for (final r in rows) _picture(r['avatarUrl'] as String?)],
        total: total,
      );
    } catch (_) {
      return null;
    }
  }

  /// "Nikhil M.".
  static String _shortName(String? first, String? last) {
    final initial = last != null && last.trim().isNotEmpty ? ' ${last.trim()[0]}.' : '';
    return '${first ?? ''}$initial'.trim();
  }

  @override
  Future<void> setSaved(Job job, bool saved) async {
    await _send(saved ? 'POST' : 'DELETE', '/jobs/${job.id}/save');
    (_savedIds ??= {}).toggle(job.id, saved);
  }

  @override
  Future<bool> hasPhone() async {
    final me = await _get('/auth/me');
    final user = (me['user'] as Map<String, dynamic>?) ?? me;
    final phone = user['phone'] as String?;
    return phone != null && phone.trim().isNotEmpty;
  }

  @override
  Future<void> apply(
    Job job, {
    String? phone,
    String? coverNote,
    String? resumeId,
    num? expectedSalary,
    Map<String, String>? answers,
    String? linkedinUrl,
    List<String>? diversityIdentities,
    String? gender,
  }) async {
    await _send(
      'POST',
      '/jobs/${job.id}/apply',
      applyBody(
        phone: phone,
        coverNote: coverNote,
        resumeId: resumeId,
        expectedSalary: expectedSalary,
        answers: answers,
        linkedinUrl: linkedinUrl,
        diversityIdentities: diversityIdentities,
        gender: gender,
      ),
    );
    (_appliedIds ??= {}).add(job.id);
    _openApplications++;
  }

  /// The body of `POST /jobs/:id/apply` (`ApplyDto`): blanks left out, text
  /// trimmed, the answers only when the job asks questions.
  static Map<String, dynamic> applyBody({
    String? phone,
    String? coverNote,
    String? resumeId,
    num? expectedSalary,
    Map<String, String>? answers,
    String? linkedinUrl,
    List<String>? diversityIdentities,
    String? gender,
  }) => {
    if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
    if (coverNote != null && coverNote.trim().isNotEmpty) 'coverNote': coverNote.trim(),
    if (resumeId != null && resumeId.isNotEmpty) 'resumeId': resumeId,
    'expectedSalary': ?expectedSalary,
    if (answers != null && answers.isNotEmpty) 'answers': {for (final e in answers.entries) e.key: e.value.trim()},
    if (linkedinUrl != null && linkedinUrl.trim().isNotEmpty) 'linkedinUrl': linkedinUrl.trim(),
    if (diversityIdentities != null && diversityIdentities.isNotEmpty) 'diversityIdentities': diversityIdentities,
    if (gender != null && gender.isNotEmpty) 'gender': gender,
  };

  @override
  Future<List<ResumeChoice>> resumes() async {
    final res = await _send('GET', '/users/me/resumes');
    final rows = (res as List? ?? const []).whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList();
    final list = [
      for (final r in rows)
        ResumeChoice(
          id: r['id'].toString(),
          title: (r['title'] as String?)?.trim().isNotEmpty == true ? r['title'] as String : 'Résumé',
          isDefault: r['isDefault'] == true,
          hasFile: (r['fileUrl'] as String?)?.isNotEmpty == true,
        ),
    ];
    list.sort((a, b) => (b.isDefault ? 1 : 0) - (a.isDefault ? 1 : 0));
    return list;
  }

  @override
  Future<SeekerQuota?> quota() async {
    final res = await _get('/applications/quota');
    if (res.isEmpty) return null;
    final caps = res['capabilities'] as Map<String, dynamic>? ?? const {};
    return SeekerQuota(
      used: (res['applicationsUsed'] as num?)?.toInt() ?? 0,
      limit: (res['applicationLimit'] as num?)?.toInt(),
      canApply: res['canApply'] != false,
      tier: res['tier'] as String?,
      applicationVisibility: caps['applicationVisibility'] == true,
      aiInsights: caps['aiInsights'] == true,
    );
  }

  @override
  Future<void> setHidden(Job job, bool hidden) async {
    await _send(hidden ? 'POST' : 'DELETE', '/jobs/${job.id}/hide');
  }

  @override
  Future<String?> messageContact(Job job, {String? message}) async {
    final res = await _send('POST', '/messaging/conversations/job', {
      'jobId': job.id,
      if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
    });
    return (res as Map<String, dynamic>?)?['id'] as String?;
  }

  @override
  Future<int> unreadNotifications() async {
    final res = await _get('/notifications/unread-count');
    return (res['unread'] as num?)?.toInt() ?? 0;
  }

  @override
  Uri link(Job job) => AppConfig.sitePage('/jobs/${job.id}');

  // --- mapping -------------------------------------------------------------

  Job job(Map<String, dynamic> json) => _job(json);

  /// A company as `GET /companies/:id` gives it (the careers header reads it).
  JobCompany companyDetail(Map<String, dynamic> json) => _companyDetail(json);

  Job _job(Map<String, dynamic> json) {
    final company = _company(json['company'] as Map<String, dynamic>? ?? const {});
    final contactJson = json['hiringContact'] as Map<String, dynamic>?;
    final applyMethod = json['applyMethod'] as String?;
    final applyUrl = json['applyUrl'] as String?;
    final category = _pretty(json['category'] as String?);
    final department = (json['department'] as String?)?.trim();
    final highlight = [?category, if (department != null && department.isNotEmpty) department].join(' • ');
    return Job(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      company: company,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      workMode: WorkMode.fromApi(json['workMode'] as String?),
      employmentType: EmploymentType.fromApi(json['employmentType'] as String?),
      salaryMin: _num(json['salaryMin']),
      salaryMax: _num(json['salaryMax']),
      salaryPeriod: json['salaryPeriod'] as String? ?? 'YEARLY',
      salaryVisible: json['salaryVisible'] != false,
      postedAt: _date(json['publishedAt'] ?? json['createdAt']),
      promoted: json['promoted'] == true,
      easyApply: applyMethod != 'EXTERNAL_URL' || applyUrl == null || applyUrl.isEmpty,
      applyUrl: applyUrl,
      skills: _strings(json['skills']),
      preferredSkills: _strings(json['preferredSkills']),
      matchScore: (json['matchScore'] as num?)?.toInt(),
      saved: _savedIds?.contains(json['id']) ?? false,
      applied: _appliedIds?.contains(json['id']) ?? false,
      descriptionHtml: json['description'] as String?,
      qualifications: _strings(json['qualifications']),
      educationQualifications: _strings(json['educationQualifications']),
      preferredQualifications: _strings(json['preferredQualifications']),
      experienceMin: (json['experienceMin'] as num?)?.toInt(),
      experienceMax: (json['experienceMax'] as num?)?.toInt(),
      openings: (json['openings'] as num?)?.toInt(),
      applyDeadline: _date(json['applyDeadline']),
      requireResume: json['requireResume'] == true,
      screening: [
        for (final q in (json['screeningQuestions'] as List? ?? const []).whereType<Map>())
          ScreeningQuestion.fromJson(Map<String, dynamic>.from(q)),
      ],
      status: json['status'] as String? ?? 'OPEN',
      genderPreference: json['genderPreference'] as String? ?? 'ANY',
      diversityCategories: _strings(json['diversityCategories']),
      diversityOnly: json['diversityOnly'] == true,
      // The API gives these to the job's own team only; a candidate's read has neither.
      applicants: ((json['_count'] as Map<String, dynamic>?)?['applications'] as num?)?.toInt(),
      views: (json['viewCount'] as num?)?.toInt(),
      contact: contactJson == null
          ? null
          : JobContact(
              name: contactJson['name'] as String? ?? 'Hiring team',
              role: contactJson['role'] == 'RECRUITER' ? 'Recruiter' : 'Job poster',
              designation: contactJson['designation'] as String?,
              photo: _picture(contactJson['avatarUrl'] as String?),
              memberId: contactJson['memberId'] as String?,
            ),
      department: department,
      category: category,
      highlight: highlight.isEmpty ? null : highlight,
    );
  }

  JobApplication _application(Map<String, dynamic> json) {
    final job = json['job'] as Map<String, dynamic>? ?? const {};
    final company = job['company'] as Map<String, dynamic>? ?? const {};
    final id = (job['id'] ?? json['jobId']).toString();
    return JobApplication(
      id: json['id'] as String,
      stage: json['stage'] as String? ?? 'APPLIED',
      appliedAt: _date(json['createdAt']),
      job: Job(
        id: id,
        title: job['title'] as String? ?? 'A job on ICR',
        company: JobCompany(
          id: (job['companyId'] ?? '').toString(),
          name: company['name'] as String? ?? 'A company on ICR',
          logo: _picture(company['logoUrl'] as String?),
        ),
        city: job['city'] as String?,
        saved: _savedIds?.contains(id) ?? false,
        applied: true,
      ),
    );
  }

  JobCompany _company(Map<String, dynamic> json) => JobCompany(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'A company on ICR',
    logo: _picture(json['logoUrl'] as String?),
    city: json['city'] as String? ?? json['hqCity'] as String?,
    verified: _verified(json['verificationLevel'] as String?),
    kind: companyKindLabel(json['type'] as String?),
    size: companySizeLabel(json['size'] as String?),
    description: json['description'] as String?,
    website: json['website'] as String?,
    openJobs: (json['openJobs'] as num?)?.toInt(),
  );

  /// `GET /companies/:id`: what the job's own company block leaves out. The
  /// API has no tagline, so the line under the name is the company's industry,
  /// or the first sentence of its description when that is short; the first
  /// photo of its gallery is the tile in "About the company". The legal name is
  /// private to the company and ICR staff, so it is not here.
  JobCompany _companyDetail(Map<String, dynamic> json) {
    final base = _company(json);
    final gallery = _strings(json['gallery']);
    return JobCompany(
      id: base.id,
      name: base.name,
      logo: base.logo,
      city: base.city,
      verified: base.verified,
      tagline:
          json['tagline'] as String? ??
          companyIndustryLabel(json['industry'] as String?) ??
          shortFirstSentence(base.description),
      kind: base.kind,
      size: base.size,
      description: base.description,
      website: base.website,
      openJobs: base.openJobs,
      cover: gallery.isEmpty ? null : _picture(gallery.first),
      legalName: json['legalName'] as String?,
    );
  }

  static bool _verified(String? level) => level != null && level != 'REGISTERED';

  static double? _num(Object? v) => switch (v) {
    num n => n.toDouble(),
    String s => double.tryParse(s),
    _ => null,
  };

  static DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

  static List<String> _strings(Object? v) => (v as List? ?? const []).map((e) => e.toString()).toList();

  FeedPicture? _picture(String? path) {
    final url = AppConfig.absoluteUrl(path, apiBase: api.dio.options.baseUrl);
    return url == null ? null : FeedPicture.network(url);
  }

  /// "FACILITY_MANAGEMENT" → "Facility management".
  static String? _pretty(String? key) {
    if (key == null || key.isEmpty) return null;
    final words = key.toLowerCase().split('_');
    return words.first[0].toUpperCase() +
        words.first.substring(1) +
        (words.length > 1 ? ' ${words.skip(1).join(' ')}' : '');
  }

  // --- the member's own state ----------------------------------------------

  /// Reads what the member bookmarked and applied to, so a list built outside the board marks its rows.
  Future<void> loadFlags() => _flags();

  Future<void> _flags({bool force = false}) async {
    if (!force && _savedIds != null && _appliedIds != null) return;
    try {
      final actions = await _get('/jobs/actions');
      _savedIds = _strings(actions['savedIds']).toSet();
    } catch (_) {
      _savedIds ??= {};
    }
    try {
      final res = await api.dio.get<dynamic>('/applications/mine');
      final rows = (res.data as List? ?? const []).cast<Map<String, dynamic>>();
      final open = rows.where((a) => a['stage'] != 'WITHDRAWN').toList();
      _appliedIds = open.map((a) => (a['jobId'] ?? (a['job'] as Map<String, dynamic>?)?['id']).toString()).toSet();
      _openApplications = open.length;
    } catch (_) {
      _appliedIds ??= {};
    }
  }

  Future<_Alerts> _alerts() async {
    try {
      final res = await api.dio.get<dynamic>('/jobs/alerts');
      final rows = (res.data as List? ?? const []).cast<Map<String, dynamic>>();
      final fresh = rows.fold<int>(0, (n, a) => n + ((a['newMatchCount'] as num?)?.toInt() ?? 0));
      if (rows.isEmpty) return _Alerts(fresh, null);
      final first = rows.first;
      final criteria = _criteriaOf(first['criteria'] as Map<String, dynamic>? ?? const {});
      final city = criteria['city']?.split(',').first.trim();
      final country = criteria['country'];
      final place = city == null || city.isEmpty
          ? null
          : '$city, ${country == null || country == 'India' ? 'IN' : country}';
      return _Alerts(
        fresh,
        JobContext(
          label: first['name'] as String? ?? 'Saved search',
          place: place,
          alertId: first['id'] as String?,
          criteria: criteria,
        ),
      );
    } catch (_) {
      return const _Alerts(0, null);
    }
  }

  /// A saved search's filters as the board's query names them, empty ones and
  /// paging left out.
  static Map<String, String> _criteriaOf(Map<String, dynamic> raw) {
    const skip = {'page', 'limit', 'sortBy', 'sortDir', 'mine', 'postedById', 'status'};
    final out = <String, String>{};
    raw.forEach((key, value) {
      if (skip.contains(key)) return;
      final text = value is List ? value.join(',') : value?.toString();
      if (text != null && text.trim().isNotEmpty) out[key] = text.trim();
    });
    return out;
  }

  // --- transport -------------------------------------------------------------

  Future<_Recommended> _recommended(String mode, int limit) async {
    try {
      final res = await _get('/jobs/recommended', {'mode': mode, 'limit': limit});
      final rows = (res['data'] as List? ?? const []).cast<Map<String, dynamic>>();
      final total = ((res['meta'] as Map<String, dynamic>?)?['total'] as num?)?.toInt() ?? rows.length;
      // The for-you feed is the top `limit` and says no more; preferences count theirs.
      final more = limit < _recommendedMax && (mode == 'foryou' ? rows.length >= limit : total > rows.length);
      return _Recommended(rows.map(_job).toList(), more);
    } catch (_) {
      return const _Recommended([], false);
    }
  }

  Future<JobPage> _page(String path, Map<String, dynamic> query) async {
    final res = await _get(path, query);
    final rows = (res['data'] as List? ?? const []).cast<Map<String, dynamic>>();
    final meta = res['meta'] as Map<String, dynamic>? ?? const {};
    return JobPage(jobs: rows.map(_job).toList(), hasMore: meta['hasNext'] == true);
  }

  Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? query]) async {
    try {
      final res = await api.dio.get<Map<String, dynamic>>(path, queryParameters: query);
      return res.data ?? const {};
    } catch (e) {
      throw ApiError.from(e);
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

class _Alerts {
  const _Alerts(this.newMatches, this.context);

  final int newMatches;
  final JobContext? context;
}

class _Recommended {
  const _Recommended(this.jobs, this.hasMore);

  final List<Job> jobs;
  final bool hasMore;
}

extension on Set<String> {
  void toggle(String id, bool on) => on ? add(id) : remove(id);
}
