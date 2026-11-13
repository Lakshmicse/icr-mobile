import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import 'talent_labels.dart';
import 'talent_models.dart';

/// The employer's talent search: what the website's `/talent` page reads and changes, as the API serves it to a
/// hiring role (`RECRUITER_TIER`). Every refusal arrives as an [ApiError] carrying the API's own sentence — the
/// plan's ("Boolean search comes with Silver."), the company check's ("Verify your company to…"), a role's.
abstract class TalentRepository {
  /// Who is looking: `GET /auth/me`, and `GET /me/companies` for the number of companies when acting as themselves.
  Future<TalentViewer> viewer();

  /// `GET /talent/access`: the sourcing paywall.
  Future<TalentAccess> access();

  /// `GET /talent?…`: the faceted directory, contact-free.
  Future<CandidatePage> search(TalentFilters filters, {int page = 1, int limit = 12});

  /// `GET /talent/match?jobId=…`: candidates ranked against one of the company's jobs, narrowed by the same facets.
  Future<List<Candidate>> match(String jobId, TalentFilters filters, {int limit = 20});

  /// `GET /talent/:id`.
  Future<CandidateDetail> detail(String userId);

  /// `GET /talent/:id/contact` — spends the company's contact allowance.
  Future<CandidateContact> revealContact(String userId);

  /// `POST /talent/:id/message`: the first message; returns the conversation's id when the API names one.
  Future<String?> message(String userId, String message, {String? jobTitle});

  /// `POST /job-invites`.
  Future<void> invite({required String jobId, required String candidateId});

  /// `GET /talent/:id/notes`.
  Future<List<CandidateNote>> notes(String userId);

  /// `POST /talent/:id/notes`.
  Future<CandidateNote> addNote(String userId, String body);

  /// `GET /talent/:id/tags`.
  Future<List<String>> tags(String userId);

  /// `POST /talent/:id/tags`; the whole list as it now stands.
  Future<List<String>> addTag(String userId, String label);

  /// `DELETE /talent/:id/tags/:label`; the whole list as it now stands.
  Future<List<String>> removeTag(String userId, String label);

  /// `GET /talent/searches`.
  Future<List<SavedSearch>> savedSearches();

  /// `POST /talent/searches`.
  Future<SavedSearch> saveSearch(String name, TalentFilters criteria, {bool alertsEnabled = true});

  /// `PATCH /talent/searches/:id`.
  Future<SavedSearch> updateSearch(String id, {String? name, TalentFilters? criteria, bool? alertsEnabled});

  /// `DELETE /talent/searches/:id`.
  Future<void> deleteSearch(String id);

  /// `POST /talent/parse`: a plain-English brief as filters.
  Future<ParsedQuery> parse(String text);

  /// `GET /jobs/company`: the company's jobs, for matching, inviting and the exclusions' scope.
  Future<List<JobOption>> companyJobs();

  /// `GET /masters`: the industries and job functions the pickers offer.
  Future<TalentMasters> masters();
}

class ApiTalentRepository implements TalentRepository {
  ApiTalentRepository({required this.api});

  final ApiClient api;

  Future<T> _call<T>(Future<T> Function(Dio dio) body) async {
    try {
      return await body(api.dio);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  static Map<String, dynamic> _map(Object? data) => data is Map ? data.cast<String, dynamic>() : const {};

  static String _enc(String s) => Uri.encodeComponent(s);

  @override
  Future<TalentViewer> viewer() => _call((dio) async {
    final me = _map((await dio.get<dynamic>('/auth/me')).data);
    final user = me['user'] is Map ? _map(me['user']) : me;
    final role = '${user['role'] ?? 'PROFESSIONAL'}';
    final companyId = user['companyId'] as String?;
    var held = 0;
    // Acting as themselves: whether there is a company to switch to, or only one to create.
    if (companyId == null && role != 'SUPER_ADMIN') {
      try {
        final mine = _map((await dio.get<dynamic>('/me/companies')).data);
        held = (mine['companies'] as List?)?.length ?? 0;
      } catch (_) {
        // Told nothing: the way on is to create one.
      }
    }
    return TalentViewer(role: role, companyId: companyId, companiesHeld: held);
  });

  @override
  Future<TalentAccess> access() =>
      _call((dio) async => TalentAccess.fromJson(_map((await dio.get<dynamic>('/talent/access')).data)));

  @override
  Future<CandidatePage> search(TalentFilters filters, {int page = 1, int limit = 12}) => _call((dio) async {
    final res = await dio.get<dynamic>(
      '/talent',
      queryParameters: filters.toQuery(page: page, limit: limit),
    );
    return CandidatePage.fromJson(_map(res.data));
  });

  @override
  Future<List<Candidate>> match(String jobId, TalentFilters filters, {int limit = 20}) => _call((dio) async {
    // Paging and sorting are Browse's and the job is the match's own, so neither travels (the website's
    // `useCandidateMatch`).
    final params = filters.copyWith(jobId: null).toQuery(paging: false, sorting: false)
      ..['jobId'] = jobId
      ..['limit'] = limit;
    final res = await dio.get<dynamic>('/talent/match', queryParameters: params);
    final data = res.data;
    return [
      for (final r in data is List ? data : const [])
        if (r is Map) Candidate.fromJson(r.cast<String, dynamic>()),
    ];
  });

  @override
  Future<CandidateDetail> detail(String userId) =>
      _call((dio) async => CandidateDetail.fromJson(_map((await dio.get<dynamic>('/talent/${_enc(userId)}')).data)));

  @override
  Future<CandidateContact> revealContact(String userId) => _call(
    (dio) async => CandidateContact.fromJson(_map((await dio.get<dynamic>('/talent/${_enc(userId)}/contact')).data)),
  );

  @override
  Future<String?> message(String userId, String message, {String? jobTitle}) => _call((dio) async {
    final res = await dio.post<dynamic>(
      '/talent/${_enc(userId)}/message',
      data: {'message': message, 'jobTitle': ?jobTitle},
    );
    final id = _map(res.data)['id'];
    return id == null ? null : '$id';
  });

  @override
  Future<void> invite({required String jobId, required String candidateId}) =>
      _call((dio) => dio.post<dynamic>('/job-invites', data: {'jobId': jobId, 'candidateId': candidateId}));

  @override
  Future<List<CandidateNote>> notes(String userId) => _call((dio) async {
    final data = (await dio.get<dynamic>('/talent/${_enc(userId)}/notes')).data;
    return [
      for (final n in data is List ? data : const [])
        if (n is Map) CandidateNote.fromJson(n.cast<String, dynamic>()),
    ];
  });

  @override
  Future<CandidateNote> addNote(String userId, String body) => _call((dio) async {
    final res = await dio.post<dynamic>('/talent/${_enc(userId)}/notes', data: {'body': body});
    return CandidateNote.fromJson(_map(res.data));
  });

  static List<String> _labels(Object? data) => [for (final t in data is List ? data : const []) '$t'];

  @override
  Future<List<String>> tags(String userId) =>
      _call((dio) async => _labels((await dio.get<dynamic>('/talent/${_enc(userId)}/tags')).data));

  @override
  Future<List<String>> addTag(String userId, String label) => _call(
    (dio) async => _labels((await dio.post<dynamic>('/talent/${_enc(userId)}/tags', data: {'label': label})).data),
  );

  @override
  Future<List<String>> removeTag(String userId, String label) =>
      _call((dio) async => _labels((await dio.delete<dynamic>('/talent/${_enc(userId)}/tags/${_enc(label)}')).data));

  @override
  Future<List<SavedSearch>> savedSearches() => _call((dio) async {
    final data = (await dio.get<dynamic>('/talent/searches')).data;
    return [
      for (final s in data is List ? data : const [])
        if (s is Map) SavedSearch.fromJson(s.cast<String, dynamic>()),
    ];
  });

  @override
  Future<SavedSearch> saveSearch(String name, TalentFilters criteria, {bool alertsEnabled = true}) =>
      _call((dio) async {
        final res = await dio.post<dynamic>(
          '/talent/searches',
          data: {'name': name, 'criteria': criteria.toJson(), 'alertsEnabled': alertsEnabled},
        );
        return SavedSearch.fromJson(_map(res.data));
      });

  @override
  Future<SavedSearch> updateSearch(String id, {String? name, TalentFilters? criteria, bool? alertsEnabled}) =>
      _call((dio) async {
        final res = await dio.patch<dynamic>(
          '/talent/searches/${_enc(id)}',
          data: {'name': ?name, 'criteria': ?criteria?.toJson(), 'alertsEnabled': ?alertsEnabled},
        );
        return SavedSearch.fromJson(_map(res.data));
      });

  @override
  Future<void> deleteSearch(String id) => _call((dio) => dio.delete<dynamic>('/talent/searches/${_enc(id)}'));

  @override
  Future<ParsedQuery> parse(String text) => _call(
    (dio) async => ParsedQuery.fromJson(_map((await dio.post<dynamic>('/talent/parse', data: {'text': text})).data)),
  );

  @override
  Future<List<JobOption>> companyJobs() => _call((dio) async {
    final res = await dio.get<dynamic>('/jobs/company', queryParameters: {'limit': 50});
    final rows = _map(res.data)['data'];
    return [
      for (final j in rows is List ? rows : const [])
        if (j is Map && j['id'] != null) JobOption(id: '${j['id']}', title: '${j['title'] ?? ''}'),
    ];
  });

  @override
  Future<TalentMasters> masters() =>
      _call((dio) async => TalentMasters.fromJson(_map((await dio.get<dynamic>('/masters')).data)));
}

/// The sample talent pool for the demo and for tests, kept in memory and changed in place. Every write is logged
/// in [sent]; [refuseSearch] makes every search fail with that sentence (an API refusal), [access] sets the
/// paywall (its `resultCap` caps a search as the API does), [viewer] sets who is looking.
class DemoTalentRepository implements TalentRepository {
  DemoTalentRepository({
    List<Candidate>? candidates,
    this.viewer_ = const TalentViewer(role: 'COMPANY_ADMIN', companyId: 'company-1', companiesHeld: 1),
    this.access_ = const TalentAccess(tier: 'GOLD'),
    List<SavedSearch>? saved,
    List<JobOption>? jobs,
    this.refuseSearch,
    this.delay = Duration.zero,
    this.now,
  }) : candidates = candidates ?? sample(),
       saved = saved ?? [],
       jobs = jobs ?? sampleJobs();

  final List<Candidate> candidates;
  final TalentViewer viewer_;
  final TalentAccess access_;
  final List<SavedSearch> saved;
  final List<JobOption> jobs;

  /// The API's refusal every search answers with, when set.
  final String? refuseSearch;
  final Duration delay;
  final DateTime? now;

  /// Every change sent, in order (tests).
  final sent = <Map<String, Object?>>[];

  final _notes = <String, List<CandidateNote>>{};
  final _tags = <String, List<String>>{};
  int _ids = 0;

  /// The jobs the sample company posts, with the skills a match is scored on.
  static List<JobOption> sampleJobs() => const [
    JobOption(id: 'job-1', title: 'Senior Facility Manager — Mumbai'),
    JobOption(id: 'job-2', title: 'Lease Administrator'),
  ];

  static const _jobSkills = {
    'job-1': ['Facility Management', 'Vendor Management', 'HVAC', 'Budgeting', 'Statutory Compliance'],
    'job-2': ['Lease Administration', 'Abstracting', 'Yardi'],
  };

  static List<Candidate> sample() => [
    const Candidate(
      userId: 'cand-priya',
      firstName: 'Priya',
      lastName: 'Sharma',
      profilePublic: true,
      profileSlug: 'priya-sharma',
      featured: true,
      seekerTier: 'GOLD',
      headline: 'Senior Facility Manager · Integrated FM',
      skills: [
        'Facility Management',
        'Vendor Management',
        'HVAC',
        'Budgeting',
        'Statutory Compliance',
        'Soft Services',
      ],
      experienceYears: 9,
      currentLocation: 'Mumbai',
      currentCompany: 'JLL',
      noticePeriodDays: 30,
      expectedSalary: 1800000,
      nextRole: NextRole(
        status: 'READY_NOW',
        visibility: 'EVERYONE',
        roles: ['Head of Facilities'],
        locations: ['Mumbai', 'Pune'],
        workModes: ['HYBRID'],
        employmentTypes: ['FULL_TIME'],
        industries: ['CORPORATE_OCCUPIER'],
        functions: ['FACILITIES_OPS'],
        shift: 'DAY',
        willingToRelocate: true,
        canStartDays: 30,
      ),
    ),
    const Candidate(
      userId: 'cand-arjun',
      firstName: 'Arjun',
      lastName: 'Mehta',
      profilePublic: true,
      headline: 'Lease Administrator',
      skills: ['Lease Administration', 'Abstracting', 'Yardi'],
      experienceYears: 5,
      currentLocation: 'Bengaluru',
      currentCompany: 'CBRE',
      noticePeriodDays: 60,
    ),
    const Candidate(
      userId: 'cand-meera',
      firstName: 'Meera',
      lastName: 'Rao',
      profilePublic: true,
      headline: 'Facility Supervisor',
      skills: ['Housekeeping', 'Vendor Management'],
      experienceYears: 4,
      currentLocation: 'Bengaluru',
    ),
    const Candidate(
      userId: 'cand-rohan',
      firstName: 'Rohan',
      lastName: 'Das',
      headline: 'Transactions Analyst',
      skills: ['Transactions', 'Financial Modelling', 'Market Research'],
      experienceYears: 3,
      currentLocation: 'Pune',
      currentCompany: 'Knight Frank',
      noticePeriodDays: 0,
      nextRole: NextRole(
        status: 'OPEN_TO_OFFERS',
        roles: ['Senior Analyst'],
        locations: ['Pune'],
        workModes: ['ONSITE', 'HYBRID'],
        employmentTypes: ['FULL_TIME', 'CONTRACT'],
        functions: ['TRANSACTIONS'],
        canStartDays: 0,
      ),
    ),
    const Candidate(
      userId: 'cand-kavya',
      firstName: 'Kavya',
      lastName: 'Nair',
      profilePublic: true,
      headline: 'MEP Engineer',
      skills: ['HVAC', 'MEP', 'Electrical', 'Fire Safety', 'BMS', 'Energy Audits'],
      experienceYears: 7,
      currentLocation: 'Hyderabad',
      currentCompany: 'Sodexo',
      noticePeriodDays: 30,
      lastWorkingDay: '2026-12-15',
    ),
    const Candidate(
      userId: 'cand-sanjay',
      firstName: 'Sanjay',
      lastName: 'Iyer',
      profilePublic: true,
      headline: 'Workplace Experience Lead',
      skills: ['Workplace Experience', 'Change Management'],
      experienceYears: 12,
      currentLocation: 'Chennai',
      currentCompany: 'Accenture',
      noticePeriodDays: 90,
      expectedSalary: 3200000,
    ),
  ];

  Future<void> _wait() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  @override
  Future<TalentViewer> viewer() async {
    await _wait();
    return viewer_;
  }

  @override
  Future<TalentAccess> access() async {
    await _wait();
    return access_;
  }

  static bool _has(String? hay, String needle) => (hay ?? '').toLowerCase().contains(needle.toLowerCase());

  static bool _anyOf(Iterable<String> have, List<String> wanted) =>
      wanted.isEmpty || wanted.any((w) => have.any((h) => h.toLowerCase().contains(w.toLowerCase())));

  /// The API's `SENIORITY_YEAR_BANDS`, near enough for a sample.
  static (int, int?) _band(String seniority) => switch (seniority) {
    'INTERN' => (0, 1),
    'JUNIOR' => (1, 3),
    'MID' => (3, 6),
    'SENIOR' => (6, 10),
    'LEAD' => (10, 15),
    'DIRECTOR' => (15, 20),
    _ => (20, null),
  };

  bool _matches(Candidate c, TalentFilters f) {
    final q = f.q?.trim();
    if (q != null && q.isNotEmpty) {
      // Plain words must all appear; the boolean operators and quoting the API compiles are skipped here.
      final words = q
          .split(RegExp(r'\s+'))
          .map((w) => w.replaceAll(RegExp(r'["()]'), ''))
          .where((w) => w.isNotEmpty && !const {'AND', 'OR', 'NOT'}.contains(w));
      final text = [c.fullName, ?c.headline, ...c.skills, ?c.currentCompany].join(' ').toLowerCase();
      // A plural reads as its singular ("managers" finds a Facility Manager), as the API's text search does.
      bool found(String w) {
        final lower = w.toLowerCase();
        final stem = lower.length > 3 && lower.endsWith('s') ? lower.substring(0, lower.length - 1) : lower;
        return text.contains(stem);
      }

      if (!words.every(found)) return false;
    }
    if (!_anyOf(c.skills, f.skills)) return false;
    if (!_anyOf([?c.headline, ...?c.nextRole?.roles], f.titles)) return false;
    if (!_anyOf([?c.currentLocation, ...?c.nextRole?.locations], f.locations)) return false;
    if (f.city != null && !_has(c.currentLocation, f.city!)) return false;
    if (f.currentCompany != null && !_has(c.currentCompany, f.currentCompany!)) return false;
    final years = c.experienceYears;
    if (f.minYears != null && (years == null || years < f.minYears!)) return false;
    if (f.maxYears != null && (years == null || years > f.maxYears!)) return false;
    if (f.seniority != null) {
      final (lo, hi) = _band(f.seniority!);
      if (years == null || years < lo || (hi != null && years >= hi)) return false;
    }
    if (f.noticePeriodMaxDays != null && (c.noticePeriodDays == null || c.noticePeriodDays! > f.noticePeriodMaxDays!)) {
      return false;
    }
    final ceiling = [?f.expectedSalaryMax, ?f.maxDesiredSalary];
    if (ceiling.isNotEmpty && (c.expectedSalary == null || ceiling.any((x) => c.expectedSalary! > x))) return false;
    final wants = c.nextRole;
    if (f.desiredWorkMode != null && !(wants?.workModes.contains(f.desiredWorkMode) ?? false)) return false;
    if (f.employmentTypes.isNotEmpty && !(wants?.employmentTypes.any(f.employmentTypes.contains) ?? false)) {
      return false;
    }
    if (f.industries.isNotEmpty && !(wants?.industries.any(f.industries.contains) ?? false)) return false;
    if (f.functions.isNotEmpty && !(wants?.functions.any(f.functions.contains) ?? false)) return false;
    if (f.shift != null && wants?.shift != f.shift && wants?.shift != 'FLEXIBLE') return false;
    if (f.willingToRelocate && !(wants?.willingToRelocate ?? false)) return false;
    if (f.nextRole && wants == null) return false;
    if (f.updatedWithinDays != null) {
      final at = c.updatedAt;
      final since = (now ?? DateTime.now()).subtract(Duration(days: f.updatedWithinDays!));
      if (at == null || at.isBefore(since)) return false;
    }
    return true;
  }

  List<Candidate> _filtered(TalentFilters f) {
    final rows = candidates.where((c) => _matches(c, f)).toList();
    switch (f.sort) {
      case TalentSort.experience:
        rows.sort((a, b) => (b.experienceYears ?? -1).compareTo(a.experienceYears ?? -1));
      case TalentSort.notice:
        // Soonest first; unknown last.
        rows.sort((a, b) => (a.noticePeriodDays ?? 1 << 20).compareTo(b.noticePeriodDays ?? 1 << 20));
      case TalentSort.recent:
        break;
    }
    return rows;
  }

  @override
  Future<CandidatePage> search(TalentFilters filters, {int page = 1, int limit = 12}) async {
    await _wait();
    if (refuseSearch != null) throw ApiError(refuseSearch!, statusCode: 403);
    final all = _filtered(filters);
    // An unverified company gets a taste of the database, not the database: the API caps how far it reads and
    // reports the reachable total.
    final cap = access_.resultCap;
    final reachable = cap == null ? all : all.take(cap).toList();
    final start = ((page - 1) * limit).clamp(0, reachable.length);
    final rows = reachable.skip(start).take(limit).toList();
    final totalPages = reachable.isEmpty ? 1 : (reachable.length / limit).ceil();
    return CandidatePage(rows: rows, page: page, totalPages: totalPages, total: reachable.length);
  }

  @override
  Future<List<Candidate>> match(String jobId, TalentFilters filters, {int limit = 20}) async {
    await _wait();
    if (refuseSearch != null) throw ApiError(refuseSearch!, statusCode: 403);
    final required = _jobSkills[jobId] ?? const <String>[];
    final out = <Candidate>[];
    for (final c in _filtered(filters.copyWith(sort: TalentSort.recent))) {
      final have = required.where((s) => c.skills.any((x) => x.toLowerCase() == s.toLowerCase())).toList();
      if (required.isNotEmpty && have.isEmpty) continue;
      final overlap = required.isEmpty ? 1.0 : have.length / required.length;
      out.add(
        Candidate(
          userId: c.userId,
          resumeId: c.resumeId,
          firstName: c.firstName,
          lastName: c.lastName,
          avatarUrl: c.avatarUrl,
          seekerTier: c.seekerTier,
          profilePublic: c.profilePublic,
          profileSlug: c.profileSlug,
          featured: c.featured,
          headline: c.headline,
          skills: c.skills,
          experienceYears: c.experienceYears,
          currentLocation: c.currentLocation,
          currentCompany: c.currentCompany,
          noticePeriodDays: c.noticePeriodDays,
          expectedSalary: c.expectedSalary,
          lastWorkingDay: c.lastWorkingDay,
          nextRole: c.nextRole,
          updatedAt: c.updatedAt,
          matchScore: (overlap * 100).round(),
          signals: [
            MatchSignal(
              key: 'skillsOverlap',
              label: 'Skills match',
              score: overlap,
              detail: '${have.length} of ${required.length} required skills: ${have.join(', ').toLowerCase()}',
            ),
          ],
        ),
      );
    }
    out.sort((a, b) => (b.matchScore ?? 0).compareTo(a.matchScore ?? 0));
    return out.take(limit).toList();
  }

  Candidate _find(String userId) => candidates.firstWhere(
    (c) => c.userId == userId,
    orElse: () => throw ApiError('Candidate not found or not discoverable.', statusCode: 404),
  );

  @override
  Future<CandidateDetail> detail(String userId) async {
    await _wait();
    final c = _find(userId);
    return CandidateDetail(
      card: c,
      title: c.headline,
      summary: c.userId == 'cand-priya'
          ? 'Nine years running integrated facilities for corporate occupiers across Mumbai and Pune: vendor '
                'consolidation, statutory audits, and a 14% cut in energy spend over two years.'
          : null,
    );
  }

  @override
  Future<CandidateContact> revealContact(String userId) async {
    await _wait();
    if (!access_.canRevealContact) {
      throw ApiError(
        access_.verified
            ? 'Your plan does not include candidate contact details.'
            : 'Verify your company to reveal candidate contact details.',
        statusCode: 403,
      );
    }
    final c = _find(userId);
    sent.add({'op': 'contact', 'id': userId});
    return CandidateContact(
      email: '${c.firstName.toLowerCase()}.${c.lastName.toLowerCase()}@example.com',
      phone: '+91 98450 ${(10000 + c.userId.hashCode % 90000).toString().padLeft(5, '0')}',
    );
  }

  @override
  Future<String?> message(String userId, String message, {String? jobTitle}) async {
    await _wait();
    if (!access_.canMessage) {
      throw ApiError(
        access_.verified
            ? 'Your plan does not include messaging candidates.'
            : 'Verify your company to message candidates.',
        statusCode: 403,
      );
    }
    _find(userId);
    sent.add({'op': 'message', 'id': userId, 'message': message, 'jobTitle': ?jobTitle});
    return 'conv-${++_ids}';
  }

  @override
  Future<void> invite({required String jobId, required String candidateId}) async {
    await _wait();
    if (!access_.verified) throw ApiError('Verify your company to invite candidates to apply.', statusCode: 403);
    _find(candidateId);
    sent.add({'op': 'invite', 'jobId': jobId, 'candidateId': candidateId});
  }

  @override
  Future<List<CandidateNote>> notes(String userId) async {
    await _wait();
    return List.unmodifiable(_notes[userId] ?? const []);
  }

  @override
  Future<CandidateNote> addNote(String userId, String body) async {
    await _wait();
    _find(userId);
    final note = CandidateNote(
      id: 'note-${++_ids}',
      body: body,
      createdAt: now ?? DateTime.now(),
      authorName: 'Chetan CompanyAdmin',
    );
    (_notes[userId] ??= []).insert(0, note);
    sent.add({'op': 'note.add', 'id': userId, 'body': body});
    return note;
  }

  @override
  Future<List<String>> tags(String userId) async {
    await _wait();
    return List.unmodifiable(_tags[userId] ?? const []);
  }

  @override
  Future<List<String>> addTag(String userId, String label) async {
    await _wait();
    _find(userId);
    final list = _tags[userId] ??= [];
    if (!list.contains(label)) list.add(label);
    sent.add({'op': 'tag.add', 'id': userId, 'label': label});
    return List.unmodifiable(list);
  }

  @override
  Future<List<String>> removeTag(String userId, String label) async {
    await _wait();
    final list = _tags[userId] ??= [];
    list.remove(label);
    sent.add({'op': 'tag.remove', 'id': userId, 'label': label});
    return List.unmodifiable(list);
  }

  @override
  Future<List<SavedSearch>> savedSearches() async {
    await _wait();
    return List.unmodifiable(saved);
  }

  @override
  Future<SavedSearch> saveSearch(String name, TalentFilters criteria, {bool alertsEnabled = true}) async {
    await _wait();
    final s = SavedSearch(
      id: 'search-${++_ids}',
      name: name,
      criteria: criteria,
      alertsEnabled: alertsEnabled,
      lastMatchCount: _filtered(criteria).length,
    );
    saved.add(s);
    sent.add({'op': 'search.save', 'name': name, 'criteria': criteria.toJson(), 'alertsEnabled': alertsEnabled});
    return s;
  }

  @override
  Future<SavedSearch> updateSearch(String id, {String? name, TalentFilters? criteria, bool? alertsEnabled}) async {
    await _wait();
    final i = saved.indexWhere((s) => s.id == id);
    if (i < 0) throw ApiError('Saved search not found', statusCode: 404);
    final next = saved[i].copyWith(name: name, criteria: criteria, alertsEnabled: alertsEnabled);
    saved[i] = next;
    sent.add({
      'op': 'search.update',
      'id': id,
      'name': ?name,
      'criteria': ?criteria?.toJson(),
      'alertsEnabled': ?alertsEnabled,
    });
    return next;
  }

  @override
  Future<void> deleteSearch(String id) async {
    await _wait();
    saved.removeWhere((s) => s.id == id);
    sent.add({'op': 'search.delete', 'id': id});
  }

  /// The website's rules-first parser, in miniature: years, a notice period, a seniority word, `in <city>`, and
  /// the rest as keywords.
  @override
  Future<ParsedQuery> parse(String text) async {
    await _wait();
    final matched = <String>[];
    var rest = text.trim();
    int? minYears;
    int? notice;
    String? seniority;
    final locations = <String>[];
    final years = RegExp(r'(\d+)\s*\+?\s*(?:years?|yrs?)', caseSensitive: false).firstMatch(rest);
    if (years != null) {
      minYears = int.parse(years.group(1)!);
      matched.add('experience');
      rest = rest.replaceFirst(years.group(0)!, '');
    }
    final days = RegExp(r'(\d+)\s*[- ]?day', caseSensitive: false).firstMatch(rest);
    if (days != null) {
      notice = int.parse(days.group(1)!);
      matched.add('notice period');
      rest = rest.replaceFirst(RegExp(r'\d+\s*[- ]?day\s*notice', caseSensitive: false), '');
    } else if (RegExp(r'immediate', caseSensitive: false).hasMatch(rest)) {
      notice = 0;
      matched.add('notice period');
      rest = rest.replaceFirst(RegExp(r'immediate\s*joiners?', caseSensitive: false), '');
    }
    for (final (word, level) in const [('senior', 'SENIOR'), ('junior', 'JUNIOR'), ('lead', 'LEAD')]) {
      if (RegExp('\\b$word\\b', caseSensitive: false).hasMatch(rest)) {
        seniority = level;
        matched.add('seniority');
        break;
      }
    }
    final place = RegExp(r'\bin\s+([A-Z][a-zA-Z]+)').firstMatch(rest);
    if (place != null) {
      locations.add(place.group(1)!);
      matched.add('location');
      rest = rest.replaceFirst(place.group(0)!, '');
    }
    final keywords = rest.replaceAll(RegExp(r'[,;]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final q = keywords.replaceAll(RegExp(r'\s*(with|and|under|at)\s*$', caseSensitive: false), '').trim();
    if (RegExp(r'\w').hasMatch(q)) matched.add('keywords');
    return ParsedQuery(
      filters: TalentFilters(
        q: q.isEmpty ? null : q,
        minYears: minYears,
        noticePeriodMaxDays: notice,
        seniority: seniority,
        locations: locations,
      ),
      matched: matched,
    );
  }

  @override
  Future<List<JobOption>> companyJobs() async {
    await _wait();
    return List.unmodifiable(jobs);
  }

  @override
  Future<TalentMasters> masters() async {
    await _wait();
    return const TalentMasters();
  }
}
