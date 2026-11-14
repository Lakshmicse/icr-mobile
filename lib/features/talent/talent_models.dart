/// What the talent search draws and sends: the website's `CandidateFilters`, the contact-free candidate card
/// (`CandidateCardDto`), the quick view's detail, the hiring team's private notes and tags, saved searches, the
/// sourcing paywall (`TalentAccess`) and who is looking (`TalentViewer`). The live source fills them from
/// `GET /talent`, `/talent/match`, `/talent/:id`, `/talent/:id/notes|tags`, `/talent/searches` and `/talent/access`.
library;

import 'talent_labels.dart';

/// Who is sourcing: their role, the company they act for, and how many companies they belong to when acting as
/// themselves — the website's `RequireRole` and `lacksCompany`, read through the app's `/auth/me` and
/// `/me/companies` as the job composer does.
class TalentViewer {
  const TalentViewer({required this.role, this.companyId, this.companiesHeld = 0});

  final String role;
  final String? companyId;
  final int companiesHeld;

  /// `RECRUITER_TIER`: the roles the website's `/talent` admits.
  static const hiringRoles = {'SUPER_ADMIN', 'COMPANY_ADMIN', 'BRANCH_ADMIN', 'RECRUITER'};

  bool get hiringRole => hiringRoles.contains(role);
  bool get hasCompany => companyId != null && companyId!.isNotEmpty;

  /// Searching needs a hiring role; the role rides with a company, so only ICR staff reach it with none.
  bool get canSearch => hiringRole && (hasCompany || role == 'SUPER_ADMIN');
}

/// The sourcing paywall (`GET /talent/access`): contact and messages need a verified company AND a plan;
/// [resultCap] is how far into a search an unverified company (or a small plan) may read.
class TalentAccess {
  const TalentAccess({
    this.tier = 'FREE',
    this.verified = true,
    this.canRevealContact = true,
    this.canMessage = true,
    this.resultCap,
  });

  final String tier;
  final bool verified;
  final bool canRevealContact;
  final bool canMessage;
  final int? resultCap;

  factory TalentAccess.fromJson(Map<String, dynamic> json) => TalentAccess(
    tier: '${json['tier'] ?? 'FREE'}',
    verified: json['verified'] == true,
    canRevealContact: json['canRevealContact'] == true,
    canMessage: json['canMessage'] == true,
    resultCap: (json['resultCap'] as num?)?.toInt(),
  );
}

/// How a candidate wants their next role to be (`NextRoleDto`), as a recruiter sees it — never a salary.
class NextRole {
  const NextRole({
    required this.status,
    this.visibility = 'RECRUITERS',
    this.roles = const [],
    this.locations = const [],
    this.workModes = const [],
    this.employmentTypes = const [],
    this.industries = const [],
    this.functions = const [],
    this.shift,
    this.willingToRelocate = false,
    this.canStartDays,
    this.lastWorkingDay,
  });

  /// `READY_NOW` or `OPEN_TO_OFFERS`.
  final String status;

  /// `RECRUITERS` or `EVERYONE`: the ring on the photo shows only for EVERYONE.
  final String visibility;
  final List<String> roles;
  final List<String> locations;
  final List<String> workModes;
  final List<String> employmentTypes;
  final List<String> industries;
  final List<String> functions;
  final String? shift;
  final bool willingToRelocate;

  /// The notice period in days; 0 is immediately.
  final int? canStartDays;

  /// Serving notice: the last working day (`YYYY-MM-DD`), which wins over [canStartDays].
  final String? lastWorkingDay;

  bool get shownToEveryone => visibility == 'EVERYONE';

  /// The chip's tooltip: how keen, what they want and when they can start, as the website's `NextRoleChip`.
  String get summary {
    final start = lastWorkingDay != null
        ? 'Serving notice, free from ${dayKeyLabel(lastWorkingDay!)}'
        : canStartDays != null
        ? 'Can start: ${noticePeriodLabels['$canStartDays'] ?? ''}'
        : null;
    return [nextRoleStatusLabels[status] ?? '', ...roles, ...locations, ?start].where((s) => s.isNotEmpty).join(' · ');
  }

  factory NextRole.fromJson(Map<String, dynamic> json) => NextRole(
    status: '${json['status'] ?? 'OPEN_TO_OFFERS'}',
    visibility: '${json['visibility'] ?? 'RECRUITERS'}',
    roles: _strings(json['roles']),
    locations: _strings(json['locations']),
    workModes: _strings(json['workModes']),
    employmentTypes: _strings(json['employmentTypes']),
    industries: _strings(json['industries']),
    functions: _strings(json['functions']),
    shift: _text(json['shift']),
    willingToRelocate: json['willingToRelocate'] == true,
    canStartDays: (json['canStartDays'] as num?)?.toInt(),
    lastWorkingDay: _text(json['lastWorkingDay']),
  );
}

/// One of a match's signals ("Skills match", "2 of 9 required skills…").
class MatchSignal {
  const MatchSignal({required this.key, required this.label, required this.score, required this.detail});

  final String key;
  final String label;
  final double score;
  final String detail;

  factory MatchSignal.fromJson(Map<String, dynamic> json) => MatchSignal(
    key: '${json['key'] ?? ''}',
    label: '${json['label'] ?? ''}',
    score: (json['score'] as num?)?.toDouble() ?? 0,
    detail: '${json['detail'] ?? ''}',
  );
}

/// A candidate as the directory lists them (`CandidateCardDto`): contact-free; email and phone come only through
/// the paywall. A match (`CandidateMatchDto`) carries [matchScore] and [signals] too.
class Candidate {
  const Candidate({
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.resumeId = '',
    this.avatarUrl,
    this.seekerTier = 'FREE',
    this.profilePublic = false,
    this.profileSlug,
    this.featured = false,
    this.headline,
    this.skills = const [],
    this.experienceYears,
    this.currentLocation,
    this.currentCompany,
    this.noticePeriodDays,
    this.expectedSalary,
    this.lastWorkingDay,
    this.nextRole,
    this.updatedAt,
    this.matchScore,
    this.signals = const [],
  });

  final String userId;
  final String resumeId;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String seekerTier;

  /// The name opens the member's profile only when it is public.
  final bool profilePublic;
  final String? profileSlug;

  /// Decided by the API from the candidate's own plan.
  final bool featured;
  final String? headline;
  final List<String> skills;
  final int? experienceYears;
  final String? currentLocation;
  final String? currentCompany;
  final int? noticePeriodDays;

  /// Yearly INR, only while the candidate shows it to recruiters.
  final num? expectedSalary;

  /// Serving notice: free from this day (`YYYY-MM-DD`); wins over [noticePeriodDays].
  final String? lastWorkingDay;

  /// Null when not looking, or when they work at the viewer's own company.
  final NextRole? nextRole;
  final DateTime? updatedAt;

  /// Match to a job only: 0–100.
  final int? matchScore;
  final List<MatchSignal> signals;

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final both = '$f$l'.toUpperCase();
    return both.isEmpty ? '?' : both;
  }

  /// The card's facts, in the website's order: years, where, employer, what they expect, when they are free.
  List<String> get cardFacts => [
    if (experienceYears != null) '$experienceYears yrs',
    ?currentLocation,
    ?currentCompany,
    if (expectedSalary != null) 'Expects ${rupees(expectedSalary!)} a year',
    ?availability(card: true),
  ];

  /// "Serving notice · free 15 Dec 2026", "Immediate" or "30d notice"; the quick view's wording when not [card].
  String? availability({required bool card}) {
    if (lastWorkingDay != null) {
      return card
          ? 'Serving notice · free ${dayKeyLabel(lastWorkingDay!)}'
          : 'Serving notice · free from ${dayKeyLabel(lastWorkingDay!)}';
    }
    final days = noticePeriodDays;
    if (days == null) return null;
    if (card) return days == 0 ? 'Immediate' : '${days}d notice';
    return '${days}d notice';
  }

  factory Candidate.fromJson(Map<String, dynamic> json) => Candidate(
    userId: '${json['userId'] ?? json['id'] ?? ''}',
    resumeId: '${json['resumeId'] ?? ''}',
    firstName: '${json['firstName'] ?? ''}',
    lastName: '${json['lastName'] ?? ''}',
    avatarUrl: _text(json['avatarUrl']),
    seekerTier: '${json['seekerTier'] ?? 'FREE'}',
    profilePublic: json['profilePublic'] == true,
    profileSlug: _text(json['profileSlug']),
    featured: json['featured'] == true,
    headline: _text(json['headline']),
    skills: _strings(json['skills']),
    experienceYears: (json['experienceYears'] as num?)?.toInt(),
    currentLocation: _text(json['currentLocation']),
    currentCompany: _text(json['currentCompany']),
    noticePeriodDays: (json['noticePeriodDays'] as num?)?.toInt(),
    expectedSalary: json['expectedSalary'] as num?,
    lastWorkingDay: _text(json['lastWorkingDay']),
    nextRole: json['nextRole'] is Map ? NextRole.fromJson((json['nextRole'] as Map).cast<String, dynamic>()) : null,
    updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}'),
    matchScore: (json['matchScore'] as num?)?.round(),
    signals: [
      for (final s in json['signals'] is List ? json['signals'] as List : const [])
        if (s is Map) MatchSignal.fromJson(s.cast<String, dynamic>()),
    ],
  );
}

/// The quick view's extra (`CandidateDetailDto`): the résumé's summary and title.
class CandidateDetail {
  const CandidateDetail({required this.card, this.summary, this.title});

  final Candidate card;
  final String? summary;
  final String? title;

  factory CandidateDetail.fromJson(Map<String, dynamic> json) =>
      CandidateDetail(card: Candidate.fromJson(json), summary: _text(json['summary']), title: _text(json['title']));
}

/// What the paywall reveals (`GET /talent/:id/contact`).
class CandidateContact {
  const CandidateContact({required this.email, this.phone});

  final String email;
  final String? phone;

  factory CandidateContact.fromJson(Map<String, dynamic> json) =>
      CandidateContact(email: '${json['email'] ?? ''}', phone: _text(json['phone']));
}

/// A note the hiring team keeps on a candidate (`CandidateNoteDto`) — the candidate never sees it.
class CandidateNote {
  const CandidateNote({required this.id, required this.body, required this.createdAt, this.authorName});

  final String id;
  final String body;
  final DateTime createdAt;
  final String? authorName;

  factory CandidateNote.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    final name = author is Map ? '${author['firstName'] ?? ''} ${author['lastName'] ?? ''}'.trim() : '';
    return CandidateNote(
      id: '${json['id'] ?? ''}',
      body: '${json['body'] ?? ''}',
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0),
      authorName: name.isEmpty ? null : name,
    );
  }
}

/// One page of candidates (`{ data, meta }`). [total] is the reachable total: an unverified company's search
/// reports at most its cap, so the count never promises what cannot be paged to.
class CandidatePage {
  const CandidatePage({required this.rows, required this.page, required this.totalPages, required this.total});

  final List<Candidate> rows;
  final int page;
  final int totalPages;
  final int total;

  bool get hasMore => page < totalPages;

  factory CandidatePage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'];
    final rows = json['data'];
    return CandidatePage(
      rows: [
        for (final r in rows is List ? rows : const [])
          if (r is Map) Candidate.fromJson(r.cast<String, dynamic>()),
      ],
      page: meta is Map ? (meta['page'] as num?)?.toInt() ?? 1 : 1,
      totalPages: meta is Map ? (meta['totalPages'] as num?)?.toInt() ?? 1 : 1,
      total: meta is Map ? (meta['total'] as num?)?.toInt() ?? 0 : 0,
    );
  }
}

/// A search the recruiter saved (`SavedTalentSearchDto`). [newMatchCount] is "new to you": candidates whose
/// profile changed since the search last ran.
class SavedSearch {
  const SavedSearch({
    required this.id,
    required this.name,
    required this.criteria,
    this.alertsEnabled = false,
    this.lastMatchCount = 0,
    this.newMatchCount = 0,
  });

  final String id;
  final String name;
  final TalentFilters criteria;
  final bool alertsEnabled;
  final int lastMatchCount;
  final int newMatchCount;

  SavedSearch copyWith({String? name, TalentFilters? criteria, bool? alertsEnabled, int? newMatchCount}) => SavedSearch(
    id: id,
    name: name ?? this.name,
    criteria: criteria ?? this.criteria,
    alertsEnabled: alertsEnabled ?? this.alertsEnabled,
    lastMatchCount: lastMatchCount,
    newMatchCount: newMatchCount ?? this.newMatchCount,
  );

  factory SavedSearch.fromJson(Map<String, dynamic> json) => SavedSearch(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    criteria: json['criteria'] is Map
        ? TalentFilters.fromJson((json['criteria'] as Map).cast<String, dynamic>())
        : const TalentFilters(),
    alertsEnabled: json['alertsEnabled'] == true,
    lastMatchCount: (json['lastMatchCount'] as num?)?.toInt() ?? 0,
    newMatchCount: (json['newMatchCount'] as num?)?.toInt() ?? 0,
  );
}

/// What `POST /talent/parse` made of a plain-English brief: the filters it read, which facets it filled, and
/// whether a model was needed.
class ParsedQuery {
  const ParsedQuery({required this.filters, required this.matched, this.usedAi = false});

  final TalentFilters filters;
  final List<String> matched;
  final bool usedAi;

  /// The website's "Read as …" line.
  String get sentence => usedAi
      ? 'Read as ${matched.join(', ')}. Adjust anything in the filters.'
      : 'Read as ${matched.join(', ')}. Matched locally without AI. Adjust anything in the filters.';

  factory ParsedQuery.fromJson(Map<String, dynamic> json) => ParsedQuery(
    filters: TalentFilters.fromJson(json),
    matched: _strings(json['matched']),
    usedAi: json['usedAi'] == true,
  );
}

/// One of the company's jobs, for "Match to a job", "Invite to apply" and the exclusions' scope.
class JobOption {
  const JobOption({required this.id, required this.title});

  final String id;
  final String title;
}

/// Result ordering (`CandidateQueryDto.sort`), with the website's words.
enum TalentSort {
  recent('recent', 'Recently Updated'),
  experience('experience', 'Most Experienced'),
  notice('notice', 'Soonest Available');

  const TalentSort(this.api, this.label);
  final String api;
  final String label;

  static TalentSort fromApi(Object? v) => values.firstWhere((s) => s.api == '$v', orElse: () => recent);
}

/// One chip of what is filtering the list, with the key that removes it.
class FilterChipLabel {
  const FilterChipLabel(this.key, this.label);

  final String key;
  final String label;
}

const _keep = Object();

/// The full facet set, one for one with the website's `CandidateFilters` (`CandidateQueryDto`): every field is
/// something the candidate filled in on their résumé. Immutable; [copyWith] takes `null` to clear a field.
class TalentFilters {
  const TalentFilters({
    this.q,
    this.skills = const [],
    this.city,
    this.currentCompany,
    this.titles = const [],
    this.locations = const [],
    this.minYears,
    this.maxYears,
    this.seniority,
    this.noticePeriodMaxDays,
    this.expectedSalaryMax,
    this.maxDesiredSalary,
    this.desiredWorkMode,
    this.employmentTypes = const [],
    this.industries = const [],
    this.functions = const [],
    this.shift,
    this.willingToRelocate = false,
    this.nextRole = false,
    this.updatedWithinDays,
    this.hideViewed = false,
    this.hidePastApplicants = false,
    this.jobId,
    this.sort = TalentSort.recent,
  });

  // Core.
  final String? q;
  final List<String> skills;
  final String? city;
  final String? currentCompany;
  final List<String> titles;
  final List<String> locations;

  // Experience.
  final int? minYears;
  final int? maxYears;
  final String? seniority;

  // Availability and pay.
  final int? noticePeriodMaxDays;

  /// Their expected salary is at most this. Filters only — no figure comes back.
  final num? expectedSalaryMax;

  /// The older name for [expectedSalaryMax], still in saved searches.
  final num? maxDesiredSalary;

  // What they want.
  final String? desiredWorkMode;
  final List<String> employmentTypes;

  /// `JOB_INDUSTRIES` keys.
  final List<String> industries;

  /// `JOB_FUNCTIONS` keys.
  final List<String> functions;
  final String? shift;
  final bool willingToRelocate;
  final bool nextRole;

  // Recency and recruiting activity.
  final int? updatedWithinDays;
  final bool hideViewed;
  final bool hidePastApplicants;

  /// Narrows "hide past applicants" to one job and hides its invitees.
  final String? jobId;
  final TalentSort sort;

  TalentFilters copyWith({
    Object? q = _keep,
    Object? skills = _keep,
    Object? city = _keep,
    Object? currentCompany = _keep,
    Object? titles = _keep,
    Object? locations = _keep,
    Object? minYears = _keep,
    Object? maxYears = _keep,
    Object? seniority = _keep,
    Object? noticePeriodMaxDays = _keep,
    Object? expectedSalaryMax = _keep,
    Object? maxDesiredSalary = _keep,
    Object? desiredWorkMode = _keep,
    Object? employmentTypes = _keep,
    Object? industries = _keep,
    Object? functions = _keep,
    Object? shift = _keep,
    bool? willingToRelocate,
    bool? nextRole,
    Object? updatedWithinDays = _keep,
    bool? hideViewed,
    bool? hidePastApplicants,
    Object? jobId = _keep,
    TalentSort? sort,
  }) {
    T pick<T>(Object? next, T current) => identical(next, _keep) ? current : next as T;
    List<String> list(Object? next, List<String> current) =>
        identical(next, _keep) ? current : (next as List<String>?) ?? const [];
    return TalentFilters(
      q: pick(q, this.q),
      skills: list(skills, this.skills),
      city: pick(city, this.city),
      currentCompany: pick(currentCompany, this.currentCompany),
      titles: list(titles, this.titles),
      locations: list(locations, this.locations),
      minYears: pick(minYears, this.minYears),
      maxYears: pick(maxYears, this.maxYears),
      seniority: pick(seniority, this.seniority),
      noticePeriodMaxDays: pick(noticePeriodMaxDays, this.noticePeriodMaxDays),
      expectedSalaryMax: pick(expectedSalaryMax, this.expectedSalaryMax),
      maxDesiredSalary: pick(maxDesiredSalary, this.maxDesiredSalary),
      desiredWorkMode: pick(desiredWorkMode, this.desiredWorkMode),
      employmentTypes: list(employmentTypes, this.employmentTypes),
      industries: list(industries, this.industries),
      functions: list(functions, this.functions),
      shift: pick(shift, this.shift),
      willingToRelocate: willingToRelocate ?? this.willingToRelocate,
      nextRole: nextRole ?? this.nextRole,
      updatedWithinDays: pick(updatedWithinDays, this.updatedWithinDays),
      hideViewed: hideViewed ?? this.hideViewed,
      hidePastApplicants: hidePastApplicants ?? this.hidePastApplicants,
      jobId: pick(jobId, this.jobId),
      sort: sort ?? this.sort,
    );
  }

  /// How many facets are set — neither paging nor sorting nor the job scope (the website's `countActiveFilters`).
  int get count => [
    q != null && q!.isNotEmpty,
    skills.isNotEmpty,
    city != null && city!.isNotEmpty,
    currentCompany != null && currentCompany!.isNotEmpty,
    titles.isNotEmpty,
    locations.isNotEmpty,
    minYears != null,
    maxYears != null,
    seniority != null,
    noticePeriodMaxDays != null,
    expectedSalaryMax != null,
    maxDesiredSalary != null,
    desiredWorkMode != null,
    employmentTypes.isNotEmpty,
    industries.isNotEmpty,
    functions.isNotEmpty,
    shift != null,
    willingToRelocate,
    nextRole,
    updatedWithinDays != null,
    hideViewed,
    hidePastApplicants,
  ].where((on) => on).length;

  /// The query string for `GET /talent`: only what is set (an empty string would filter to nothing), lists
  /// comma-joined, as the website's `toCandidateParams`.
  Map<String, Object> toQuery({int? page, int? limit, bool paging = true, bool sorting = true}) {
    final p = <String, Object>{};
    void put(String k, Object? v) {
      if (v == null || v == false) return;
      if (v is String && v.isEmpty) return;
      if (v is List) {
        if (v.isEmpty) return;
        p[k] = v.join(',');
        return;
      }
      p[k] = v;
    }

    if (paging) {
      put('page', page);
      put('limit', limit);
    }
    put('q', q);
    put('skills', skills);
    put('city', city);
    put('currentCompany', currentCompany);
    put('titles', titles);
    put('locations', locations);
    put('minYears', minYears);
    put('maxYears', maxYears);
    put('seniority', seniority);
    put('noticePeriodMaxDays', noticePeriodMaxDays);
    put('expectedSalaryMax', expectedSalaryMax);
    put('maxDesiredSalary', maxDesiredSalary);
    put('desiredWorkMode', desiredWorkMode);
    put('employmentTypes', employmentTypes);
    put('industries', industries);
    put('functions', functions);
    put('shift', shift);
    put('willingToRelocate', willingToRelocate);
    put('nextRole', nextRole);
    put('updatedWithinDays', updatedWithinDays);
    put('hideViewed', hideViewed);
    put('hidePastApplicants', hidePastApplicants);
    put('jobId', jobId);
    if (sorting) put('sort', sort.api);
    return p;
  }

  /// The criteria a saved search stores: the facets as set, lists kept as lists.
  Map<String, Object> toJson() {
    final p = <String, Object>{};
    void put(String k, Object? v) {
      if (v == null || v == false) return;
      if (v is String && v.isEmpty) return;
      if (v is List && v.isEmpty) return;
      p[k] = v;
    }

    put('q', q);
    put('skills', skills);
    put('city', city);
    put('currentCompany', currentCompany);
    put('titles', titles);
    put('locations', locations);
    put('minYears', minYears);
    put('maxYears', maxYears);
    put('seniority', seniority);
    put('noticePeriodMaxDays', noticePeriodMaxDays);
    put('expectedSalaryMax', expectedSalaryMax);
    put('maxDesiredSalary', maxDesiredSalary);
    put('desiredWorkMode', desiredWorkMode);
    put('employmentTypes', employmentTypes);
    put('industries', industries);
    put('functions', functions);
    put('shift', shift);
    put('willingToRelocate', willingToRelocate);
    put('nextRole', nextRole);
    put('updatedWithinDays', updatedWithinDays);
    put('hideViewed', hideViewed);
    put('hidePastApplicants', hidePastApplicants);
    put('jobId', jobId);
    put('sort', sort.api);
    return p;
  }

  /// A saved search's criteria or a parsed brief, read leniently: lists may arrive comma-joined, numbers as text.
  factory TalentFilters.fromJson(Map<String, dynamic> json) => TalentFilters(
    q: _text(json['q']),
    skills: _strings(json['skills']),
    city: _text(json['city']),
    currentCompany: _text(json['currentCompany']),
    titles: _strings(json['titles']),
    locations: _strings(json['locations']),
    minYears: _int(json['minYears']),
    maxYears: _int(json['maxYears']),
    seniority: _text(json['seniority']),
    noticePeriodMaxDays: _int(json['noticePeriodMaxDays']),
    expectedSalaryMax: _num(json['expectedSalaryMax']),
    maxDesiredSalary: _num(json['maxDesiredSalary']),
    desiredWorkMode: _text(json['desiredWorkMode']),
    employmentTypes: _strings(json['employmentTypes']),
    industries: _strings(json['industries']),
    functions: _strings(json['functions']),
    shift: _text(json['shift']),
    willingToRelocate: _bool(json['willingToRelocate']),
    nextRole: _bool(json['nextRole']),
    updatedWithinDays: _int(json['updatedWithinDays']),
    hideViewed: _bool(json['hideViewed']),
    hidePastApplicants: _bool(json['hidePastApplicants']),
    jobId: _text(json['jobId']),
    sort: TalentSort.fromApi(json['sort']),
  );

  /// Summary chips for whatever is filtering the list, in the website's words (`activeChips`).
  List<FilterChipLabel> chips(TalentMasters masters) {
    final out = <FilterChipLabel>[];
    void push(String key, String label) => out.add(FilterChipLabel(key, label));
    if (q != null && q!.isNotEmpty) push('q', '“$q”');
    for (final t in titles) {
      push('title:$t', t);
    }
    for (final s in skills) {
      push('skill:$s', s);
    }
    for (final l in locations) {
      push('loc:$l', l);
    }
    if (city != null && city!.isNotEmpty) push('city', city!);
    if (currentCompany != null && currentCompany!.isNotEmpty) push('co', 'at $currentCompany');
    if (seniority != null) push('sen', seniorityLabels[seniority] ?? seniority!);
    if (minYears != null) push('miny', '$minYears+ yrs');
    if (maxYears != null) push('maxy', '≤ $maxYears yrs');
    if (noticePeriodMaxDays != null) {
      push('notice', noticePeriodMaxDays == 0 ? 'Immediate Joiners' : '≤ ${noticePeriodMaxDays}d notice');
    }
    if (expectedSalaryMax != null) push('sal', '≤ ₹${lakh(expectedSalaryMax!)}L expected');
    if (maxDesiredSalary != null) push('dsal', 'min ≤ ₹${lakh(maxDesiredSalary!)}L');
    if (desiredWorkMode != null) push('wm', workModeLabels[desiredWorkMode] ?? desiredWorkMode!);
    if (willingToRelocate) push('reloc', 'Open to Relocating');
    for (final k in employmentTypes) {
      push('type:$k', employmentTypeLabels[k] ?? k);
    }
    for (final k in industries) {
      push('ind:$k', masters.industryLabel(k));
    }
    for (final k in functions) {
      push('fn:$k', masters.functionLabel(k));
    }
    if (shift != null) push('shift', shiftLabels[shift] ?? shift!);
    if (updatedWithinDays != null) push('upd', 'Updated ≤ ${updatedWithinDays}d');
    if (nextRole) push('nr', 'Ready for Next Role');
    if (hideViewed) push('hv', 'Hiding Viewed');
    if (hidePastApplicants) push('hpa', 'Hiding Past Applicants');
    return out;
  }

  /// These filters without the chip [key] names (the website's `dropChip`).
  TalentFilters dropChip(String key) {
    final colon = key.indexOf(':');
    final kind = colon < 0 ? key : key.substring(0, colon);
    final val = colon < 0 ? '' : key.substring(colon + 1);
    List<String> without(List<String> list) => [
      for (final x in list)
        if (x != val) x,
    ];
    return switch (kind) {
      'title' => copyWith(titles: without(titles)),
      'skill' => copyWith(skills: without(skills)),
      'loc' => copyWith(locations: without(locations)),
      'q' => copyWith(q: null),
      'city' => copyWith(city: null),
      'co' => copyWith(currentCompany: null),
      'sen' => copyWith(seniority: null),
      'miny' => copyWith(minYears: null),
      'maxy' => copyWith(maxYears: null),
      'notice' => copyWith(noticePeriodMaxDays: null),
      'sal' => copyWith(expectedSalaryMax: null),
      'dsal' => copyWith(maxDesiredSalary: null),
      'wm' => copyWith(desiredWorkMode: null),
      'reloc' => copyWith(willingToRelocate: false),
      'type' => copyWith(employmentTypes: without(employmentTypes)),
      'ind' => copyWith(industries: without(industries)),
      'fn' => copyWith(functions: without(functions)),
      'shift' => copyWith(shift: null),
      'upd' => copyWith(updatedWithinDays: null),
      'nr' => copyWith(nextRole: false),
      'hv' => copyWith(hideViewed: false),
      'hpa' => copyWith(hidePastApplicants: false),
      _ => this,
    };
  }
}

String? _text(Object? v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

List<String> _strings(Object? v) {
  if (v is List) return [for (final x in v) '$x'.trim()].where((s) => s.isNotEmpty).toList();
  if (v is String) return v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  return const [];
}

int? _int(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

num? _num(Object? v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v.trim());
  return null;
}

bool _bool(Object? v) => v == true || v == 'true';
