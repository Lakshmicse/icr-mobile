/// What the Projects screens read and send (`/projects/*`): a company's sourcing projects — talent pools that live
/// outside any single job, where recruiters shortlist people before they apply (the website's `/manage/projects`).
library;

import '../../core/auth/session_user.dart';

String? _str(Object? v) {
  if (v == null) return null;
  final t = '$v'.trim();
  return t.isEmpty ? null : t;
}

List<String> _strings(Object? v) => [
  for (final s in (v is List ? v : const []))
    if (s is String && s.trim().isNotEmpty) s.trim(),
];

Map<String, dynamic> _map(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

int? _int(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

// --- the shared enums, with their words ----------------------------------------------------------------------------

/// `ProjectVisibility`, in the website's select order.
const projectVisibilities = ['PRIVATE', 'TEAM'];

/// `PROJECT_VISIBILITY_LABELS`.
String projectVisibilityLabel(String v) => switch (v) {
  'PRIVATE' => 'Private (Only Me)',
  'TEAM' => 'Team (Anyone with Recruiter Access)',
  _ => v,
};

/// `SourcingStage`: the four board stages, then Archived.
const sourcingStages = ['SOURCED', 'CONTACTED', 'REPLIED', 'SHORTLISTED', 'ARCHIVED'];

/// `SOURCING_BOARD_STAGES`: the columns of the website's board (Archived is listed under them).
const sourcingBoardStages = ['SOURCED', 'CONTACTED', 'REPLIED', 'SHORTLISTED'];

/// `SOURCING_STAGE_LABELS`.
String sourcingStageLabel(String s) => switch (s) {
  'SOURCED' => 'Sourced',
  'CONTACTED' => 'Contacted',
  'REPLIED' => 'Replied',
  'SHORTLISTED' => 'Shortlisted',
  'ARCHIVED' => 'Archived',
  _ => s,
};

/// The next stage on the board, or null at the end (and for Archived).
String? nextSourcingStage(String s) {
  final i = sourcingBoardStages.indexOf(s);
  return i >= 0 && i < sourcingBoardStages.length - 1 ? sourcingBoardStages[i + 1] : null;
}

/// `SENIORITY_LABELS`.
String seniorityLabel(String s) => switch (s) {
  'INTERN' => 'Intern',
  'JUNIOR' => 'Junior',
  'MID' => 'Mid-Level',
  'SENIOR' => 'Senior',
  'LEAD' => 'Lead',
  'DIRECTOR' => 'Director',
  'EXECUTIVE' => 'Executive',
  _ => s,
};

/// `WORK_MODE_LABELS`.
String workModeLabel(String s) => switch (s) {
  'ONSITE' => 'On-Site',
  'REMOTE' => 'Remote',
  'HYBRID' => 'Hybrid',
  _ => s,
};

/// `APPLICATION_STAGE` as the website's "Applied to {job} · {stage}" chip prints it (lower case).
String applicationStageWord(String s) => switch (s) {
  'APPLIED' => 'applied',
  'SCREENING' => 'screening',
  'INTERVIEW' => 'interview',
  'OFFER' => 'offer',
  'HIRED' => 'hired',
  'REJECTED' => 'rejected',
  'WITHDRAWN' => 'withdrawn',
  _ => s,
};

// --- who is looking --------------------------------------------------------------------------------------------------

/// Who opened the page, and so what it shows: the website gates `/manage/projects` on `RECRUITER_TIER` and, for anyone
/// but ICR staff, on a company to act for (`lacksCompany`).
class ProjectsViewer {
  const ProjectsViewer({required this.id, required this.role, this.companyId});

  factory ProjectsViewer.of(SessionUser user) =>
      ProjectsViewer(id: user.id, role: user.role, companyId: user.companyId);

  /// Nobody signed in (a screen shown on its own).
  static const none = ProjectsViewer(id: '', role: '');

  final String id;
  final String role;
  final String? companyId;

  /// `RECRUITER_TIER`: the roles that run hiring.
  static const recruiterTier = {'SUPER_ADMIN', 'COMPANY_ADMIN', 'BRANCH_ADMIN', 'RECRUITER'};

  bool get isStaff => role == 'SUPER_ADMIN';

  /// Projects belong to a company; ICR staff see every company's.
  bool get hasCompany => isStaff || (companyId != null && companyId!.isNotEmpty);

  /// The page is the hiring team's.
  bool get reachesPage => recruiterTier.contains(role);
}

// --- a project ---------------------------------------------------------------------------------------------------------

/// A sourcing project (`ProjectDto`), with its candidate counts as the list and the page read them.
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.visibility,
    this.description,
    this.companyId,
    this.branchId,
    this.createdById,
    this.createdByName,
    this.jobId,
    this.jobTitle,
    this.titles = const [],
    this.skills = const [],
    this.locations = const [],
    this.seniority,
    this.workMode,
    this.employmentType,
    this.minYears,
    this.stageCounts = const {},
    this.candidateCount = 0,
    this.archivedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final String? companyId;
  final String? branchId;
  final String? createdById;
  final String? createdByName;

  /// `PRIVATE` or `TEAM`.
  final String visibility;

  /// The job this project sources for, when tied to one.
  final String? jobId;
  final String? jobTitle;

  // The ideal candidate.
  final List<String> titles;
  final List<String> skills;
  final List<String> locations;
  final String? seniority;
  final String? workMode;
  final String? employmentType;
  final int? minYears;

  /// Candidates per sourcing stage (Archived included).
  final Map<String, int> stageCounts;
  final int candidateCount;
  final DateTime? archivedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get archived => archivedAt != null;
  bool get private => visibility == 'PRIVATE';

  /// The website's page subtitle: the description, else "Sourcing for {job}", else "Sourcing project".
  String get subtitle => description ?? (jobTitle != null ? 'Sourcing for $jobTitle' : 'Sourcing project');

  /// The criteria chips the website's page draws: each title, skill and location, the years, the seniority and
  /// work mode.
  List<String> get criteria => [
    for (final t in titles) 'Title: $t',
    for (final s in skills) 'Skill: $s',
    for (final l in locations) 'Location: $l',
    if (minYears != null) '$minYears+ yrs',
    if (seniority != null) seniorityLabel(seniority!),
    if (workMode != null) workModeLabel(workMode!),
  ];

  Project copyWith({
    String? name,
    String? description,
    bool clearDescription = false,
    String? visibility,
    String? jobId,
    String? jobTitle,
    bool clearJob = false,
    List<String>? titles,
    List<String>? skills,
    List<String>? locations,
    int? minYears,
    bool clearMinYears = false,
    Map<String, int>? stageCounts,
    int? candidateCount,
    DateTime? archivedAt,
    bool clearArchived = false,
  }) => Project(
    id: id,
    name: name ?? this.name,
    description: clearDescription ? null : (description ?? this.description),
    companyId: companyId,
    branchId: branchId,
    createdById: createdById,
    createdByName: createdByName,
    visibility: visibility ?? this.visibility,
    jobId: clearJob ? null : (jobId ?? this.jobId),
    jobTitle: clearJob ? null : (jobTitle ?? this.jobTitle),
    titles: titles ?? this.titles,
    skills: skills ?? this.skills,
    locations: locations ?? this.locations,
    seniority: seniority,
    workMode: workMode,
    employmentType: employmentType,
    minYears: clearMinYears ? null : (minYears ?? this.minYears),
    stageCounts: stageCounts ?? this.stageCounts,
    candidateCount: candidateCount ?? this.candidateCount,
    archivedAt: clearArchived ? null : (archivedAt ?? this.archivedAt),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  factory Project.fromJson(Map<String, dynamic> json) {
    final job = _map(json['job']);
    final by = _map(json['createdBy']);
    final byName = '${by['firstName'] ?? ''} ${by['lastName'] ?? ''}'.trim();
    final counts = _map(json['stageCounts']);
    return Project(
      id: '${json['id']}',
      name: '${json['name'] ?? ''}',
      description: _str(json['description']),
      companyId: _str(json['companyId']),
      branchId: _str(json['branchId']),
      createdById: _str(json['createdById']),
      createdByName: byName.isEmpty ? null : byName,
      visibility: '${json['visibility'] ?? 'TEAM'}',
      jobId: _str(json['jobId']) ?? _str(job['id']),
      jobTitle: _str(job['title']),
      titles: _strings(json['titles']),
      skills: _strings(json['skills']),
      locations: _strings(json['locations']),
      seniority: _str(json['seniority']),
      workMode: _str(json['workMode']),
      employmentType: _str(json['employmentType']),
      minYears: _int(json['minYears']),
      stageCounts: {for (final e in counts.entries) e.key: ?_int(e.value)},
      candidateCount: _int(json['candidateCount']) ?? 0,
      archivedAt: _date(json['archivedAt']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }
}

/// One page of the list, newest change first (`GET /projects`).
class ProjectsPage {
  const ProjectsPage({required this.rows, required this.page, required this.totalPages});

  final List<Project> rows;
  final int page;
  final int totalPages;

  bool get hasMore => page < totalPages;

  factory ProjectsPage.fromJson(Map<String, dynamic> json) {
    final meta = _map(json['meta']);
    final rows = json['data'];
    return ProjectsPage(
      rows: [
        for (final r in rows is List ? rows : const [])
          if (r is Map) Project.fromJson(r.cast<String, dynamic>()),
      ],
      page: _int(meta['page']) ?? 1,
      totalPages: _int(meta['totalPages']) ?? 1,
    );
  }
}

// --- the people in it --------------------------------------------------------------------------------------------------

/// A candidate saved into a project (`ProjectCandidateDto`): contact-free, like every talent projection.
class ProjectCandidate {
  const ProjectCandidate({
    required this.id,
    required this.projectId,
    required this.candidateId,
    required this.stage,
    this.firstName = '',
    this.lastName = '',
    this.avatarUrl,
    this.headline,
    this.skills = const [],
    this.experienceYears,
    this.currentLocation,
    this.currentCompany,
    this.noticePeriodDays,
    this.note,
    this.tags = const [],
    this.applicationId,
    this.applicationStage,
    this.applicationJobId,
    this.applicationJobTitle,
    this.addedFromPipeline = false,
    this.createdAt,
  });

  final String id;
  final String projectId;
  final String candidateId;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String? headline;
  final List<String> skills;
  final int? experienceYears;
  final String? currentLocation;
  final String? currentCompany;
  final int? noticePeriodDays;

  /// One of [sourcingStages].
  final String stage;
  final String? note;

  /// The company's tags on this person.
  final List<String> tags;

  /// The application the row points at (to the project's job, else the one they were added from), only when the
  /// reader may open that job.
  final String? applicationId;
  final String? applicationStage;
  final String? applicationJobId;
  final String? applicationJobTitle;
  final bool addedFromPipeline;
  final DateTime? createdAt;

  String get name => '$firstName $lastName'.trim();

  String get initials => _initials(firstName, lastName);

  /// The website's grey line: company · location · "5 yrs" · "30d notice" (or "Immediate").
  String get meta => [
    ?currentCompany,
    ?currentLocation,
    if (experienceYears != null) '$experienceYears yrs',
    if (noticePeriodDays != null) noticePeriodDays == 0 ? 'Immediate' : '${noticePeriodDays}d notice',
  ].join(' · ');

  /// "Applied to {job} · {stage}", when the row points at an application the reader may open.
  String? get appliedChip => applicationId != null && applicationJobId != null && applicationStage != null
      ? 'Applied to ${applicationJobTitle ?? ''} · ${applicationStageWord(applicationStage!)}'
      : null;

  ProjectCandidate copyWith({String? stage}) => ProjectCandidate(
    id: id,
    projectId: projectId,
    candidateId: candidateId,
    stage: stage ?? this.stage,
    firstName: firstName,
    lastName: lastName,
    avatarUrl: avatarUrl,
    headline: headline,
    skills: skills,
    experienceYears: experienceYears,
    currentLocation: currentLocation,
    currentCompany: currentCompany,
    noticePeriodDays: noticePeriodDays,
    note: note,
    tags: tags,
    applicationId: applicationId,
    applicationStage: applicationStage,
    applicationJobId: applicationJobId,
    applicationJobTitle: applicationJobTitle,
    addedFromPipeline: addedFromPipeline,
    createdAt: createdAt,
  );

  factory ProjectCandidate.fromJson(Map<String, dynamic> json) => ProjectCandidate(
    id: '${json['id']}',
    projectId: '${json['projectId'] ?? ''}',
    candidateId: '${json['candidateId'] ?? ''}',
    stage: '${json['stage'] ?? 'SOURCED'}',
    firstName: '${json['firstName'] ?? ''}',
    lastName: '${json['lastName'] ?? ''}',
    avatarUrl: _str(json['avatarUrl']),
    headline: _str(json['headline']),
    skills: _strings(json['skills']),
    experienceYears: _int(json['experienceYears']),
    currentLocation: _str(json['currentLocation']),
    currentCompany: _str(json['currentCompany']),
    noticePeriodDays: _int(json['noticePeriodDays']),
    note: _str(json['note']),
    tags: _strings(json['tags']),
    applicationId: _str(json['applicationId']),
    applicationStage: _str(json['applicationStage']),
    applicationJobId: _str(json['applicationJobId']),
    applicationJobTitle: _str(json['applicationJobTitle']),
    addedFromPipeline: json['addedFromPipeline'] == true,
    createdAt: _date(json['createdAt']),
  );
}

/// Someone the project's criteria match who is not saved yet (`GET /projects/:id/matches`, a `CandidateCardDto`):
/// rule-based filters, not an AI ranking.
class CandidateMatch {
  const CandidateMatch({
    required this.userId,
    this.firstName = '',
    this.lastName = '',
    this.avatarUrl,
    this.headline,
    this.currentCompany,
    this.currentLocation,
    this.experienceYears,
    this.skills = const [],
  });

  final String userId;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String? headline;
  final String? currentCompany;
  final String? currentLocation;
  final int? experienceYears;
  final List<String> skills;

  String get name => '$firstName $lastName'.trim();

  String get initials => _initials(firstName, lastName);

  /// The website's grey line under the name: headline · company · location.
  String get meta => [?headline, ?currentCompany, ?currentLocation].join(' · ');

  factory CandidateMatch.fromJson(Map<String, dynamic> json) => CandidateMatch(
    userId: '${json['userId'] ?? json['id'] ?? ''}',
    firstName: '${json['firstName'] ?? ''}',
    lastName: '${json['lastName'] ?? ''}',
    avatarUrl: _str(json['avatarUrl']),
    headline: _str(json['headline']),
    currentCompany: _str(json['currentCompany']),
    currentLocation: _str(json['currentLocation']),
    experienceYears: _int(json['experienceYears']),
    skills: _strings(json['skills']),
  );
}

/// A job of the company the form offers under "Sourcing for a job" (`GET /jobs/company`).
class ProjectJobOption {
  const ProjectJobOption({required this.id, required this.title});

  final String id;
  final String title;

  factory ProjectJobOption.fromJson(Map<String, dynamic> json) =>
      ProjectJobOption(id: '${json['id']}', title: '${json['title'] ?? ''}');
}

// --- what the form sends ----------------------------------------------------------------------------------------------

/// The create dialog's fields (`CreateProjectDto`), as the website sends them: the name trimmed, blank optional
/// fields left out, the comma-separated lists split.
class ProjectDraft {
  const ProjectDraft({
    required this.name,
    this.description = '',
    this.visibility = 'TEAM',
    this.jobId,
    this.titles = const [],
    this.skills = const [],
    this.locations = const [],
    this.minYears,
  });

  final String name;
  final String description;
  final String visibility;
  final String? jobId;
  final List<String> titles;
  final List<String> skills;
  final List<String> locations;
  final int? minYears;

  /// "Facility Manager, Transactions" → the two titles (the website's `csv`).
  static List<String> csv(String v) => [
    for (final s in v.split(','))
      if (s.trim().isNotEmpty) s.trim(),
  ];

  /// The body of `POST /projects`.
  Map<String, Object?> toJson() => {
    'name': name.trim(),
    if (description.trim().isNotEmpty) 'description': description.trim(),
    'visibility': visibility,
    if (jobId != null && jobId!.isNotEmpty) 'jobId': jobId,
    'titles': titles,
    'skills': skills,
    'locations': locations,
    if (minYears != null) 'minYears': minYears,
  };

  /// Only what differs from [from]: the body of `PATCH /projects/:id` for an edit. A cleared optional field goes as
  /// null, so the API clears it.
  Map<String, Object?> changesFrom(Project from) {
    final body = <String, Object?>{};
    if (name.trim() != from.name) body['name'] = name.trim();
    final d = description.trim();
    if (d != (from.description ?? '')) body['description'] = d.isEmpty ? null : d;
    if (visibility != from.visibility) body['visibility'] = visibility;
    final j = jobId == null || jobId!.isEmpty ? null : jobId;
    if (j != from.jobId) body['jobId'] = j;
    if (!_sameList(titles, from.titles)) body['titles'] = titles;
    if (!_sameList(skills, from.skills)) body['skills'] = skills;
    if (!_sameList(locations, from.locations)) body['locations'] = locations;
    if (minYears != from.minYears) body['minYears'] = minYears;
    return body;
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

String _initials(String first, String last) {
  final a = first.isNotEmpty ? first[0] : '';
  final b = last.isNotEmpty ? last[0] : '';
  final both = '$a$b'.toUpperCase();
  return both.isEmpty ? '?' : both;
}
