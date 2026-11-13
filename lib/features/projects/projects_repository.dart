import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import 'project_models.dart';

/// A company's sourcing projects: what the website's `/manage/projects` list and project page read and change.
abstract class ProjectsRepository {
  /// `GET /projects?search=&mine=&includeArchived=&page=`, by last change.
  Future<ProjectsPage> list({String? search, bool mine = false, bool includeArchived = false, int page = 1});

  /// `POST /projects`: the new project as stored.
  Future<Project> create(ProjectDraft draft);

  /// `GET /projects/:id`, with its candidate counts.
  Future<Project> project(String id);

  /// `PATCH /projects/:id` with [changes] (`UpdateProjectDto`: any field of the form, or `archived`). The row as stored.
  Future<Project> update(String id, Map<String, Object?> changes);

  /// `DELETE /projects/:id` (a soft delete on the API).
  Future<void> remove(String id);

  /// `GET /projects/:id/candidates?limit=100`: the roster, the website's page size.
  Future<List<ProjectCandidate>> candidates(String projectId);

  /// `PATCH /projects/:id/candidates/:candidateId { stage }`.
  Future<void> moveCandidate(String projectId, String candidateId, String stage);

  /// `DELETE /projects/:id/candidates/:candidateId`.
  Future<void> removeCandidate(String projectId, String candidateId);

  /// `GET /projects/:id/matches?limit=`: people the criteria match who are not saved yet.
  Future<List<CandidateMatch>> matches(String projectId, {int limit = 12});

  /// `POST /projects/:id/candidates { candidateId }`: saves a match into the project.
  Future<void> addCandidate(String projectId, String candidateId);

  /// `GET /jobs/company?limit=50`: the jobs the form offers under "Sourcing for a job".
  Future<List<ProjectJobOption>> companyJobs();
}

class ApiProjectsRepository implements ProjectsRepository {
  ApiProjectsRepository({required this.api});

  final ApiClient api;

  Future<T> _call<T>(Future<T> Function(Dio dio) body) async {
    try {
      return await body(api.dio);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  static Map<String, dynamic> _json(Object? data) => data is Map ? data.cast<String, dynamic>() : const {};

  static List<Map<String, dynamic>> _rows(Object? data) {
    final rows = data is Map ? data['data'] : data;
    return [
      for (final r in rows is List ? rows : const [])
        if (r is Map) r.cast<String, dynamic>(),
    ];
  }

  @override
  Future<ProjectsPage> list({String? search, bool mine = false, bool includeArchived = false, int page = 1}) =>
      _call((dio) async {
        final res = await dio.get<dynamic>(
          '/projects',
          queryParameters: {
            'page': page,
            'limit': 20,
            if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
            if (mine) 'mine': true,
            if (includeArchived) 'includeArchived': true,
          },
        );
        return ProjectsPage.fromJson(_json(res.data));
      });

  @override
  Future<Project> create(ProjectDraft draft) => _call((dio) async {
    final res = await dio.post<dynamic>('/projects', data: draft.toJson());
    return Project.fromJson(_json(res.data));
  });

  @override
  Future<Project> project(String id) => _call((dio) async {
    final res = await dio.get<dynamic>('/projects/${Uri.encodeComponent(id)}');
    return Project.fromJson(_json(res.data));
  });

  @override
  Future<Project> update(String id, Map<String, Object?> changes) => _call((dio) async {
    final res = await dio.patch<dynamic>('/projects/${Uri.encodeComponent(id)}', data: changes);
    return Project.fromJson(_json(res.data));
  });

  @override
  Future<void> remove(String id) => _call((dio) => dio.delete<dynamic>('/projects/${Uri.encodeComponent(id)}'));

  @override
  Future<List<ProjectCandidate>> candidates(String projectId) => _call((dio) async {
    final res = await dio.get<dynamic>(
      '/projects/${Uri.encodeComponent(projectId)}/candidates',
      queryParameters: {'limit': 100},
    );
    return [for (final r in _rows(res.data)) ProjectCandidate.fromJson(r)];
  });

  @override
  Future<void> moveCandidate(String projectId, String candidateId, String stage) => _call(
    (dio) => dio.patch<dynamic>(
      '/projects/${Uri.encodeComponent(projectId)}/candidates/${Uri.encodeComponent(candidateId)}',
      data: {'stage': stage},
    ),
  );

  @override
  Future<void> removeCandidate(String projectId, String candidateId) => _call(
    (dio) => dio.delete<dynamic>(
      '/projects/${Uri.encodeComponent(projectId)}/candidates/${Uri.encodeComponent(candidateId)}',
    ),
  );

  @override
  Future<List<CandidateMatch>> matches(String projectId, {int limit = 12}) => _call((dio) async {
    final res = await dio.get<dynamic>(
      '/projects/${Uri.encodeComponent(projectId)}/matches',
      queryParameters: {'limit': limit},
    );
    return [for (final r in _rows(res.data)) CandidateMatch.fromJson(r)];
  });

  @override
  Future<void> addCandidate(String projectId, String candidateId) => _call(
    (dio) =>
        dio.post<dynamic>('/projects/${Uri.encodeComponent(projectId)}/candidates', data: {'candidateId': candidateId}),
  );

  @override
  Future<List<ProjectJobOption>> companyJobs() => _call((dio) async {
    final res = await dio.get<dynamic>('/jobs/company', queryParameters: {'limit': 50});
    return [
      for (final r in _rows(res.data))
        if (r['id'] != null) ProjectJobOption.fromJson(r),
    ];
  });
}

/// Sample projects for the demo and for tests, kept in memory and changed in place. Every write is logged in [sent].
class DemoProjectsRepository implements ProjectsRepository {
  DemoProjectsRepository({
    List<Project>? rows,
    Map<String, List<ProjectCandidate>>? candidates,
    Map<String, List<CandidateMatch>>? matches,
    List<ProjectJobOption>? jobs,
    this.delay = Duration.zero,
    this.failList = false,
    this.failWrites,
  }) : rows = rows ?? sample(),
       rosters = candidates ?? sampleCandidates(),
       pools = matches ?? sampleMatches(),
       jobs = jobs ?? sampleJobs();

  final List<Project> rows;
  final Map<String, List<ProjectCandidate>> rosters;
  final Map<String, List<CandidateMatch>> pools;
  final List<ProjectJobOption> jobs;
  final Duration delay;
  final bool failList;

  /// Every write is refused with this sentence (tests).
  final String? failWrites;

  /// Every change sent, in order (tests): `{'op': 'create', 'body': …}`, `{'op': 'update', 'id': …, 'body': …}`,
  /// `{'op': 'delete', 'id': …}`, `{'op': 'moveCandidate', …}`, `{'op': 'removeCandidate', …}`,
  /// `{'op': 'addCandidate', …}`.
  final sent = <Map<String, Object?>>[];

  int _next = 100;

  static const _me = 'u-asha';

  static List<Project> sample() => [
    Project(
      id: 'proj-1',
      name: 'Regional FM Managers — West',
      description: 'A bench of facility managers for the Mumbai and Pune portfolios before the Q1 openings.',
      companyId: 'co-1',
      createdById: _me,
      createdByName: 'Asha Rao',
      visibility: 'TEAM',
      jobId: 'job-1',
      jobTitle: 'Senior Facility Manager',
      titles: const ['Facility Manager', 'Transactions'],
      skills: const ['FM', 'Lease admin'],
      locations: const ['Mumbai', 'Pune'],
      minYears: 5,
      seniority: 'SENIOR',
      workMode: 'ONSITE',
      stageCounts: const {'SOURCED': 2, 'CONTACTED': 1, 'SHORTLISTED': 1, 'ARCHIVED': 1},
      candidateCount: 5,
      createdAt: DateTime(2026, 10, 20, 9, 30),
      updatedAt: DateTime(2026, 11, 10, 16, 5),
    ),
    Project(
      id: 'proj-2',
      name: 'Workplace tech leads',
      companyId: 'co-1',
      createdById: _me,
      createdByName: 'Asha Rao',
      visibility: 'PRIVATE',
      titles: const ['Workplace Technology Lead'],
      skills: const ['IoT', 'BMS'],
      locations: const ['Bengaluru'],
      createdAt: DateTime(2026, 11, 2, 11),
      updatedAt: DateTime(2026, 11, 8, 12, 40),
    ),
    Project(
      id: 'proj-3',
      name: 'Housekeeping supervisors 2025',
      description: 'Filled in October.',
      companyId: 'co-1',
      createdById: 'u-hema',
      createdByName: 'Hema Iyer',
      visibility: 'TEAM',
      skills: const ['Soft services'],
      locations: const ['Chennai'],
      stageCounts: const {'SHORTLISTED': 3},
      candidateCount: 3,
      archivedAt: DateTime(2026, 10, 30, 18),
      createdAt: DateTime(2025, 9, 1),
      updatedAt: DateTime(2026, 10, 30, 18),
    ),
  ];

  static Map<String, List<ProjectCandidate>> sampleCandidates() => {
    'proj-1': [
      ProjectCandidate(
        id: 'pc-1',
        projectId: 'proj-1',
        candidateId: 'u-ravi',
        stage: 'SOURCED',
        firstName: 'Ravi',
        lastName: 'Kumar',
        headline: 'Facility Manager · 20-acre tech park',
        currentCompany: 'Prestige Estates',
        currentLocation: 'Pune',
        experienceYears: 7,
        noticePeriodDays: 30,
        note: 'Ran the Hinjewadi campus; strong on vendor SLAs.',
        tags: const ['Ex-landlord side'],
        createdAt: DateTime(2026, 11, 9, 10),
      ),
      ProjectCandidate(
        id: 'pc-2',
        projectId: 'proj-1',
        candidateId: 'u-meera',
        stage: 'SOURCED',
        firstName: 'Meera',
        lastName: 'Shah',
        headline: 'Assistant FM, soft services',
        currentCompany: 'JLL',
        currentLocation: 'Mumbai',
        experienceYears: 5,
        noticePeriodDays: 0,
        applicationId: 'app-1',
        applicationStage: 'SCREENING',
        applicationJobId: 'job-1',
        applicationJobTitle: 'Senior Facility Manager',
        addedFromPipeline: true,
        createdAt: DateTime(2026, 11, 8, 15),
      ),
      ProjectCandidate(
        id: 'pc-3',
        projectId: 'proj-1',
        candidateId: 'u-arjun',
        stage: 'CONTACTED',
        firstName: 'Arjun',
        lastName: 'Nair',
        headline: 'Regional FM lead, West',
        currentCompany: 'CBRE',
        currentLocation: 'Mumbai',
        experienceYears: 11,
        noticePeriodDays: 60,
        createdAt: DateTime(2026, 11, 5, 9),
      ),
      ProjectCandidate(
        id: 'pc-4',
        projectId: 'proj-1',
        candidateId: 'u-divya',
        stage: 'SHORTLISTED',
        firstName: 'Divya',
        lastName: 'Menon',
        headline: 'Facility Manager, transactions and leases',
        currentCompany: 'Colliers',
        currentLocation: 'Pune',
        experienceYears: 8,
        createdAt: DateTime(2026, 11, 1, 9),
      ),
      ProjectCandidate(
        id: 'pc-5',
        projectId: 'proj-1',
        candidateId: 'u-sanjay',
        stage: 'ARCHIVED',
        firstName: 'Sanjay',
        lastName: 'Patil',
        headline: 'Site engineer',
        currentLocation: 'Nashik',
        experienceYears: 3,
        note: 'Too junior for this bench.',
        createdAt: DateTime(2026, 10, 25, 9),
      ),
    ],
    'proj-2': const [],
    'proj-3': [
      for (final (i, n) in const [('Latha', 'Krishnan'), ('Suresh', 'Babu'), ('Anitha', 'R')].indexed)
        ProjectCandidate(
          id: 'pc-3$i',
          projectId: 'proj-3',
          candidateId: 'u-hk$i',
          stage: 'SHORTLISTED',
          firstName: n.$1,
          lastName: n.$2,
          headline: 'Housekeeping supervisor',
          currentLocation: 'Chennai',
          experienceYears: 4 + i,
        ),
    ],
  };

  static Map<String, List<CandidateMatch>> sampleMatches() => {
    'proj-1': const [
      CandidateMatch(
        userId: 'u-kavya',
        firstName: 'Kavya',
        lastName: 'Reddy',
        headline: 'Facility Manager',
        currentCompany: 'Embassy Services',
        currentLocation: 'Pune',
        experienceYears: 6,
        skills: ['FM', 'Lease admin', 'Budgeting'],
      ),
      CandidateMatch(
        userId: 'u-nikhil',
        firstName: 'Nikhil',
        lastName: 'Joshi',
        headline: 'Transactions manager, corporate real estate',
        currentCompany: 'Knight Frank',
        currentLocation: 'Mumbai',
        experienceYears: 9,
        skills: ['Lease admin', 'Transactions'],
      ),
    ],
    'proj-2': const [],
    'proj-3': const [],
  };

  static List<ProjectJobOption> sampleJobs() => const [
    ProjectJobOption(id: 'job-1', title: 'Senior Facility Manager'),
    ProjectJobOption(id: 'job-2', title: 'Workplace Experience Lead'),
  ];

  Future<void> _wait() => delay > Duration.zero ? Future<void>.delayed(delay) : Future<void>.value();

  void _refuseWrites() {
    if (failWrites != null) throw ApiError(failWrites!, statusCode: 400);
  }

  Project _find(String id) {
    final i = rows.indexWhere((p) => p.id == id);
    if (i < 0) throw ApiError('Project not found.', statusCode: 404);
    return rows[i];
  }

  void _put(Project p) {
    final i = rows.indexWhere((r) => r.id == p.id);
    if (i >= 0) rows[i] = p;
  }

  /// The project with its counts recomputed from its roster, as the API's `findOne` does.
  Project _counted(Project p) {
    final roster = rosters[p.id] ?? const [];
    final counts = <String, int>{};
    for (final c in roster) {
      counts[c.stage] = (counts[c.stage] ?? 0) + 1;
    }
    return p.copyWith(stageCounts: counts, candidateCount: roster.length);
  }

  @override
  Future<ProjectsPage> list({String? search, bool mine = false, bool includeArchived = false, int page = 1}) async {
    await _wait();
    if (failList) throw ApiError('Unable to load projects.');
    final q = (search ?? '').trim().toLowerCase();
    final shown = [
      for (final p in rows)
        if ((includeArchived || !p.archived) &&
            (!mine || p.createdById == _me) &&
            (q.isEmpty || p.name.toLowerCase().contains(q)))
          _counted(p),
    ]..sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
    return ProjectsPage(rows: shown, page: 1, totalPages: 1);
  }

  @override
  Future<Project> create(ProjectDraft draft) async {
    await _wait();
    _refuseWrites();
    sent.add({'op': 'create', 'body': draft.toJson()});
    final now = DateTime.now();
    final job = jobs.where((j) => j.id == draft.jobId).firstOrNull;
    final p = Project(
      id: 'proj-${_next++}',
      name: draft.name.trim(),
      description: draft.description.trim().isEmpty ? null : draft.description.trim(),
      companyId: 'co-1',
      createdById: _me,
      createdByName: 'Asha Rao',
      visibility: draft.visibility,
      jobId: job?.id,
      jobTitle: job?.title,
      titles: draft.titles,
      skills: draft.skills,
      locations: draft.locations,
      minYears: draft.minYears,
      createdAt: now,
      updatedAt: now,
    );
    rows.insert(0, p);
    rosters[p.id] = [];
    pools[p.id] = [];
    return p;
  }

  @override
  Future<Project> project(String id) async {
    await _wait();
    return _counted(_find(id));
  }

  @override
  Future<Project> update(String id, Map<String, Object?> changes) async {
    await _wait();
    _refuseWrites();
    sent.add({'op': 'update', 'id': id, 'body': changes});
    var p = _find(id);
    if (changes.containsKey('archived')) {
      p = changes['archived'] == true ? p.copyWith(archivedAt: DateTime.now()) : p.copyWith(clearArchived: true);
    }
    if (changes.containsKey('name')) p = p.copyWith(name: '${changes['name']}');
    if (changes.containsKey('description')) {
      final d = changes['description'];
      p = d == null ? p.copyWith(clearDescription: true) : p.copyWith(description: '$d');
    }
    if (changes.containsKey('visibility')) p = p.copyWith(visibility: '${changes['visibility']}');
    if (changes.containsKey('jobId')) {
      final j = changes['jobId'];
      final job = jobs.where((x) => x.id == j).firstOrNull;
      p = job == null ? p.copyWith(clearJob: true) : p.copyWith(jobId: job.id, jobTitle: job.title);
    }
    if (changes.containsKey('titles')) p = p.copyWith(titles: _list(changes['titles']));
    if (changes.containsKey('skills')) p = p.copyWith(skills: _list(changes['skills']));
    if (changes.containsKey('locations')) p = p.copyWith(locations: _list(changes['locations']));
    if (changes.containsKey('minYears')) {
      final m = changes['minYears'];
      p = m == null ? p.copyWith(clearMinYears: true) : p.copyWith(minYears: m is num ? m.toInt() : null);
    }
    _put(p);
    return _counted(p);
  }

  static List<String> _list(Object? v) => [
    for (final s in (v is List ? v : const []))
      if (s is String) s,
  ];

  @override
  Future<void> remove(String id) async {
    await _wait();
    _refuseWrites();
    sent.add({'op': 'delete', 'id': id});
    _find(id);
    rows.removeWhere((p) => p.id == id);
  }

  @override
  Future<List<ProjectCandidate>> candidates(String projectId) async {
    await _wait();
    _find(projectId);
    return List.of(rosters[projectId] ?? const []);
  }

  @override
  Future<void> moveCandidate(String projectId, String candidateId, String stage) async {
    await _wait();
    _refuseWrites();
    sent.add({'op': 'moveCandidate', 'projectId': projectId, 'candidateId': candidateId, 'stage': stage});
    final roster = rosters[projectId] ?? [];
    final i = roster.indexWhere((c) => c.candidateId == candidateId);
    if (i < 0) throw ApiError('That candidate is not in this project.', statusCode: 404);
    roster[i] = roster[i].copyWith(stage: stage);
  }

  @override
  Future<void> removeCandidate(String projectId, String candidateId) async {
    await _wait();
    _refuseWrites();
    sent.add({'op': 'removeCandidate', 'projectId': projectId, 'candidateId': candidateId});
    rosters[projectId]?.removeWhere((c) => c.candidateId == candidateId);
  }

  @override
  Future<List<CandidateMatch>> matches(String projectId, {int limit = 12}) async {
    await _wait();
    _find(projectId);
    final saved = {for (final c in rosters[projectId] ?? const <ProjectCandidate>[]) c.candidateId};
    return [
      for (final m in pools[projectId] ?? const <CandidateMatch>[])
        if (!saved.contains(m.userId)) m,
    ].take(limit).toList();
  }

  @override
  Future<void> addCandidate(String projectId, String candidateId) async {
    await _wait();
    _refuseWrites();
    sent.add({'op': 'addCandidate', 'projectId': projectId, 'candidateId': candidateId});
    final roster = rosters.putIfAbsent(projectId, () => []);
    if (roster.any((c) => c.candidateId == candidateId)) return;
    final m = (pools[projectId] ?? const <CandidateMatch>[]).where((x) => x.userId == candidateId).firstOrNull;
    roster.add(
      ProjectCandidate(
        id: 'pc-${_next++}',
        projectId: projectId,
        candidateId: candidateId,
        stage: 'SOURCED',
        firstName: m?.firstName ?? '',
        lastName: m?.lastName ?? '',
        avatarUrl: m?.avatarUrl,
        headline: m?.headline,
        currentCompany: m?.currentCompany,
        currentLocation: m?.currentLocation,
        experienceYears: m?.experienceYears,
        skills: m?.skills ?? const [],
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<List<ProjectJobOption>> companyJobs() async {
    await _wait();
    return List.of(jobs);
  }
}
