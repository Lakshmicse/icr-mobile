/// What the employer screens draw and send: the company's jobs, the composer's draft,
/// and a job's applicants with everything the hiring team does to them. The live source
/// fills them from `GET /jobs/company`, `GET /jobs/:id`, `GET /jobs/:id/applications` and
/// `GET /applications/:id`.
library;

import '../../../core/config.dart';
import '../job_models.dart';
import 'job_rules.dart';

/// A listed job title (`GET /job-titles`): the words, and the function a posting under it is tagged with.
class JobTitleOption {
  const JobTitleOption(this.name, [this.jobFunction]);

  final String name;

  /// A `JOB_FUNCTION` key, or null.
  final String? jobFunction;
}

/// Two titles are the same title when they read the same (`jobTitleKey`).
String jobTitleKey(String name) => name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// The roles that post and run a company's jobs (`RECRUITER_TIER`).
const hiringRoles = {'SUPER_ADMIN', 'COMPANY_ADMIN', 'BRANCH_ADMIN', 'RECRUITER'};

/// Whether the signed-in person may post jobs and run applicants for a company.
bool canHireWithRole(String? role) => role != null && hiringRoles.contains(role);

/// Who is signed in and what they may do as an employer.
class HiringAccess {
  const HiringAccess({
    required this.userId,
    required this.role,
    this.companyId,
    this.canPublish = true,
    this.publishNote,
  });

  final String userId;
  final String role;
  final String? companyId;

  /// The company is verified (`GET /employer-verification/gate`): publishing a job is allowed.
  final bool canPublish;

  /// What the employer gate says when it does not (the reviewer's note, or the usual sentence).
  final String? publishNote;

  /// The person has a company they act for and a role that posts for it.
  bool get canManage => canHireWithRole(role) && (companyId != null || role == 'SUPER_ADMIN');
}

/// The statuses of a posting (`JobStatus`).
enum PostingStatus {
  open('OPEN', 'Open'),
  draft('DRAFT', 'Draft'),
  inReview('IN_REVIEW', 'In review'),
  paused('PAUSED', 'Paused'),
  closed('CLOSED', 'Closed');

  const PostingStatus(this.api, this.label);
  final String api;
  final String label;

  static PostingStatus fromApi(String? v) => values.firstWhere((s) => s.api == v, orElse: () => draft);
}

/// How many applicants a posting holds at each stage, and how many nobody has opened.
class PipelineCounts {
  const PipelineCounts({this.stages = const {}, this.unviewed = 0});

  factory PipelineCounts.fromJson(Map<String, dynamic>? json) {
    final raw = (json?['stages'] as Map?) ?? const {};
    return PipelineCounts(
      stages: {for (final e in raw.entries) '${e.key}': (e.value as num).toInt()},
      unviewed: (json?['unviewed'] as num?)?.toInt() ?? 0,
    );
  }

  final Map<String, int> stages;
  final int unviewed;

  int count(String stage) => stages[stage] ?? 0;

  /// Applicants still applying: withdrawn ones left out.
  int get total => stages.entries.where((e) => e.key != 'WITHDRAWN').fold(0, (n, e) => n + e.value);
}

/// One of the company's postings on the list.
class PostedJob {
  const PostedJob({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    this.city,
    this.cities = const [],
    this.workMode,
    this.employmentType,
    this.publishedAt,
    this.applyDeadline,
    this.openings,
    this.viewCount,
    this.pipeline = const PipelineCounts(),
    this.screeningQuestions = 0,
    this.promotedUntil,
    this.reviewNote,
    this.reviewedAt,
    this.postedBy,
    this.salaryMin,
    this.salaryMax,
    this.salaryPeriod = 'YEARLY',
  });

  factory PostedJob.fromJson(Map<String, dynamic> json) {
    DateTime? date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
    final poster = json['postedBy'] as Map?;
    final cities = [for (final c in (json['cities'] as List? ?? const [])) c.toString()];
    return PostedJob(
      id: json['id'].toString(),
      title: json['title'] as String? ?? '',
      status: PostingStatus.fromApi(json['status'] as String?),
      createdAt: date(json['createdAt']) ?? DateTime.now(),
      city: json['city'] as String?,
      cities: cities,
      workMode: WorkMode.fromApi(json['workMode'] as String?),
      employmentType: EmploymentType.fromApi(json['employmentType'] as String?),
      publishedAt: date(json['publishedAt']),
      applyDeadline: date(json['applyDeadline']),
      openings: (json['openings'] as num?)?.toInt(),
      viewCount: (json['viewCount'] as num?)?.toInt(),
      pipeline: PipelineCounts.fromJson(json['pipeline'] as Map<String, dynamic>?),
      screeningQuestions: (((json['_count'] as Map?)?['screeningQuestions']) as num?)?.toInt() ?? 0,
      promotedUntil: date(json['promotedUntil']),
      reviewNote: json['reviewNote'] as String?,
      reviewedAt: date(json['reviewedAt']),
      postedBy: poster == null ? null : '${poster['firstName'] ?? ''} ${poster['lastName'] ?? ''}'.trim(),
      salaryMin: num.tryParse('${json['salaryMin'] ?? ''}'),
      salaryMax: num.tryParse('${json['salaryMax'] ?? ''}'),
      salaryPeriod: json['salaryPeriod'] as String? ?? 'YEARLY',
    );
  }

  final String id;
  final String title;
  final PostingStatus status;
  final DateTime createdAt;
  final String? city;
  final List<String> cities;
  final WorkMode? workMode;
  final EmploymentType? employmentType;
  final DateTime? publishedAt;
  final DateTime? applyDeadline;
  final int? openings;
  final int? viewCount;
  final PipelineCounts pipeline;
  final int screeningQuestions;
  final DateTime? promotedUntil;
  final String? reviewNote;
  final DateTime? reviewedAt;
  final String? postedBy;
  final num? salaryMin;
  final num? salaryMax;
  final String salaryPeriod;

  /// "Mumbai, Pune".
  String get place => cities.isNotEmpty ? cities.join(', ') : (city ?? '');

  /// A draft ICR's review sent back: the reviewer's note stays on it.
  bool get returned => status == PostingStatus.draft && (reviewNote ?? '').isNotEmpty && reviewedAt != null;

  bool get promoted => promotedUntil != null;

  PostedJob copyWith({PostingStatus? status}) => PostedJob(
    id: id,
    title: title,
    status: status ?? this.status,
    createdAt: createdAt,
    city: city,
    cities: cities,
    workMode: workMode,
    employmentType: employmentType,
    publishedAt: publishedAt,
    applyDeadline: applyDeadline,
    openings: openings,
    viewCount: viewCount,
    pipeline: pipeline,
    screeningQuestions: screeningQuestions,
    promotedUntil: promotedUntil,
    reviewNote: reviewNote,
    reviewedAt: reviewedAt,
    postedBy: postedBy,
    salaryMin: salaryMin,
    salaryMax: salaryMax,
    salaryPeriod: salaryPeriod,
  );
}

/// One page of the company's postings with the count per status.
class PostedJobsPage {
  const PostedJobsPage({required this.jobs, required this.hasMore, this.total = 0, this.statusCounts = const {}});

  final List<PostedJob> jobs;
  final bool hasMore;
  final int total;
  final Map<PostingStatus, int> statusCounts;

  int get all => statusCounts.values.fold(0, (a, b) => a + b);
}

/// The figures across every posting (`GET /jobs/company/overview`).
class HiringOverview {
  const HiringOverview({
    this.open = 0,
    this.closingSoon = 0,
    this.unviewed = 0,
    this.interviewing = 0,
    this.interviewingJobs = 0,
    this.hired = 0,
    this.attention = const [],
  });

  factory HiringOverview.fromJson(Map<String, dynamic> json) => HiringOverview(
    open: (json['open'] as num?)?.toInt() ?? 0,
    closingSoon: (json['closingSoon'] as num?)?.toInt() ?? 0,
    unviewed: (json['unviewed'] as num?)?.toInt() ?? 0,
    interviewing: (json['interviewing'] as num?)?.toInt() ?? 0,
    interviewingJobs: (json['interviewingJobs'] as num?)?.toInt() ?? 0,
    hired: (json['hired'] as num?)?.toInt() ?? 0,
    attention: [
      for (final a in (json['attention'] as List? ?? const []).whereType<Map>())
        AttentionItem(
          kind: a['kind'] as String? ?? '',
          jobId: '${a['jobId']}',
          title: a['title'] as String? ?? '',
          days: (a['days'] as num?)?.toInt(),
        ),
    ],
  );

  final int open;
  final int closingSoon;
  final int unviewed;
  final int interviewing;
  final int interviewingJobs;
  final int hired;
  final List<AttentionItem> attention;
}

/// A posting that needs doing something to (`noApplicants`, `closing`, ...).
class AttentionItem {
  const AttentionItem({required this.kind, required this.jobId, required this.title, this.days});

  final String kind;
  final String jobId;
  final String title;
  final int? days;

  String get words => switch (kind) {
    'noApplicants' => 'No applicants yet${days == null ? '' : ' after $days days'}. Promote it or refresh the posting.',
    'closing' => 'Closes ${days == null ? 'soon' : (days == 0 ? 'today' : 'in $days days')}.',
    _ => 'Needs a look.',
  };
}

/// A question the job asks with an application, as the composer edits it.
class ScreeningDraft {
  const ScreeningDraft({
    this.id,
    this.type = 'YES_NO',
    this.prompt = '',
    this.options = const [],
    this.scaleMax,
    this.idealAnswer,
    this.mustHave = false,
  });

  factory ScreeningDraft.fromJson(Map<String, dynamic> json) => ScreeningDraft(
    id: json['id']?.toString(),
    type: json['type'] as String? ?? 'TEXT',
    prompt: json['prompt'] as String? ?? '',
    options: [for (final o in (json['options'] as List? ?? const [])) o.toString()],
    scaleMax: (json['scaleMax'] as num?)?.toInt(),
    idealAnswer: json['idealAnswer'] as String?,
    mustHave: json['mustHave'] == true,
  );

  final String? id;
  final String type;
  final String prompt;
  final List<String> options;
  final int? scaleMax;
  final String? idealAnswer;
  final bool mustHave;

  static const types = [
    ('YES_NO', 'Yes or no'),
    ('YEARS', 'Years of experience'),
    ('NUMERIC', 'A number'),
    ('SINGLE_SELECT', 'Pick one'),
    ('MULTI_SELECT', 'Pick several'),
    ('RATING', 'A rating'),
    ('DATE', 'A date'),
    ('TEXT', 'Free text'),
  ];

  bool get hasOptions => type == 'SINGLE_SELECT' || type == 'MULTI_SELECT';

  ScreeningDraft copyWith({
    String? type,
    String? prompt,
    List<String>? options,
    int? scaleMax,
    String? idealAnswer,
    bool? mustHave,
    bool clearIdeal = false,
  }) => ScreeningDraft(
    id: id,
    type: type ?? this.type,
    prompt: prompt ?? this.prompt,
    options: options ?? this.options,
    scaleMax: scaleMax ?? this.scaleMax,
    idealAnswer: clearIdeal ? null : (idealAnswer ?? this.idealAnswer),
    mustHave: mustHave ?? this.mustHave,
  );

  /// Why the question cannot be saved, in the API's terms (`ScreeningQuestionInput`).
  String? get problem {
    final p = prompt.trim();
    if (p.length < JobLimits.screeningPromptMin) {
      return 'Write each question in at least ${JobLimits.screeningPromptMin} characters.';
    }
    if (p.length > JobLimits.screeningPromptMax) {
      return 'Keep each question under ${JobLimits.screeningPromptMax} characters.';
    }
    if (hasOptions) {
      final clean = [
        for (final o in options)
          if (o.trim().isNotEmpty) o.trim(),
      ];
      if (clean.length < 2) return 'Give "$p" at least two options.';
      if (clean.length > JobLimits.screeningOptionsMax) return 'Keep to ${JobLimits.screeningOptionsMax} options.';
      if (clean.any((o) => o.length > JobLimits.screeningOptionMax)) {
        return 'Keep each option under ${JobLimits.screeningOptionMax} characters.';
      }
      if (clean.map((o) => o.toLowerCase()).toSet().length != clean.length) return 'Each option must be different.';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': ?id,
    'type': type,
    'prompt': prompt.trim(),
    if (hasOptions)
      'options': [
        for (final o in options)
          if (o.trim().isNotEmpty) o.trim(),
      ],
    if (type == 'RATING') 'scaleMax': scaleMax == 10 ? 10 : 5,
    if (idealAnswer != null && idealAnswer!.trim().isNotEmpty) 'idealAnswer': idealAnswer!.trim(),
    'mustHave': mustHave,
  };
}

/// The composer's state: everything the form edits about one posting.
class JobDraft {
  const JobDraft({
    this.id,
    this.title = '',
    this.description = '',
    this.department = '',
    this.seniority,
    this.employmentType = 'FULL_TIME',
    this.workMode = 'ONSITE',
    this.country = 'India',
    this.state = '',
    this.cities = const [],
    this.cityOpenings = const {},
    this.skills = const [],
    this.preferredSkills = const [],
    this.experienceMin,
    this.experienceMax,
    this.salaryMin,
    this.salaryMax,
    this.salaryCurrency = 'INR',
    this.salaryPeriod = 'YEARLY',
    this.salaryVisible = true,
    this.negotiable = false,
    this.openings = 1,
    this.externalApply = false,
    this.applyUrl = '',
    this.applyDeadline,
    this.requireResume = false,
    this.showHiringContact = true,
    this.status = PostingStatus.draft,
    this.screening = const [],
    this.jobFunctions = const [],
  });

  /// Reads a posting as `GET /jobs/:id` gives it to its own team.
  factory JobDraft.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? v) => [for (final e in (v as List? ?? const [])) e.toString()];
    final cities = strings(json['cities']);
    final city = json['city'] as String?;
    final rows = (json['cityOpenings'] as List? ?? const []).whereType<Map>();
    return JobDraft(
      id: json['id']?.toString(),
      title: json['title'] as String? ?? '',
      description: htmlToDescription(json['description'] as String?),
      department: json['department'] as String? ?? '',
      seniority: json['seniority'] as String?,
      employmentType: json['employmentType'] as String? ?? 'FULL_TIME',
      workMode: json['workMode'] as String? ?? 'ONSITE',
      country: json['country'] as String? ?? 'India',
      state: json['state'] as String? ?? '',
      cities: cities.isNotEmpty ? cities : [?city],
      cityOpenings: {for (final r in rows) '${r['city']}': (r['openings'] as num).toInt()},
      skills: strings(json['skills']),
      preferredSkills: strings(json['preferredSkills']),
      experienceMin: (json['experienceMin'] as num?)?.toInt(),
      experienceMax: (json['experienceMax'] as num?)?.toInt(),
      salaryMin: num.tryParse('${json['salaryMin'] ?? ''}'),
      salaryMax: num.tryParse('${json['salaryMax'] ?? ''}'),
      salaryCurrency: json['salaryCurrency'] as String? ?? 'INR',
      salaryPeriod: json['salaryPeriod'] as String? ?? 'YEARLY',
      salaryVisible: json['salaryVisible'] != false,
      negotiable: json['negotiable'] == true,
      openings: (json['openings'] as num?)?.toInt() ?? 1,
      externalApply: json['applyMethod'] == 'EXTERNAL_URL',
      applyUrl: json['applyUrl'] as String? ?? '',
      applyDeadline: json['applyDeadline'] is String
          ? DateTime.tryParse(json['applyDeadline'] as String)?.toLocal()
          : null,
      requireResume: json['requireResume'] == true,
      showHiringContact: json['showHiringContact'] != false,
      status: PostingStatus.fromApi(json['status'] as String?),
      jobFunctions: strings(json['jobFunctions']),
    );
  }

  final String? id;
  final String title;

  /// The description in the composer's text form ([descriptionToHtml] makes the stored HTML).
  final String description;
  final String department;
  final String? seniority;
  final String employmentType;
  final String workMode;
  final String country;
  final String state;
  final List<String> cities;
  final Map<String, int> cityOpenings;
  final List<String> skills;
  final List<String> preferredSkills;
  final int? experienceMin;
  final int? experienceMax;
  final num? salaryMin;
  final num? salaryMax;
  final String salaryCurrency;
  final String salaryPeriod;
  final bool salaryVisible;
  final bool negotiable;
  final int openings;
  final bool externalApply;
  final String applyUrl;
  final DateTime? applyDeadline;
  final bool requireResume;
  final bool showHiringContact;
  final PostingStatus status;
  final List<ScreeningDraft> screening;

  /// The function of a listed title (the board's function filter and job alerts read it). The composer is the
  /// only writer: it follows the title, so it is empty for a title typed freely.
  final List<String> jobFunctions;

  bool get isNew => id == null;

  /// With several cities the total is the sum of the cities' seats.
  int get totalOpenings => cities.where((c) => c.trim().isNotEmpty).length >= 2
      ? cities.fold(0, (n, c) => n + (cityOpenings[c] ?? 0))
      : openings;

  JobFacts get facts => JobFacts(
    title: title,
    description: descriptionToHtml(description),
    skills: skills,
    preferredSkills: preferredSkills,
    country: country,
    salaryMin: salaryMin,
    salaryMax: salaryMax,
    experienceMin: experienceMin,
    experienceMax: experienceMax,
    cities: cities,
    cityOpenings: cityOpenings,
    externalApply: externalApply,
    applyUrl: applyUrl,
    // A multi-city posting's total is derived; only a single-city one types it.
    openings: cities.where((c) => c.trim().isNotEmpty).length >= 2 ? null : openings,
  );

  /// Everything between this posting and going live.
  List<JobBlocker> get blockers => jobPublishBlockers(facts);

  /// What a draft may not even be saved with: the limits the DTO checks on every save.
  String? get saveProblem {
    if (title.trim().isEmpty) return 'Give the posting a title to save it.';
    if (title.trim().length > JobLimits.titleMax) return 'Keep the title under ${JobLimits.titleMax} characters.';
    if (descriptionToHtml(description).length > JobLimits.descriptionHtmlMax) {
      return 'The description is too long to save.';
    }
    if (skills.length > JobLimits.skillsMax || preferredSkills.length > JobLimits.skillsMax) {
      return 'List at most ${JobLimits.skillsMax} skills.';
    }
    if (cities.length > JobLimits.citiesMax) return 'List at most ${JobLimits.citiesMax} cities.';
    for (final v in [salaryMin, salaryMax]) {
      if (v != null && (v < 0 || v > JobLimits.salaryMax)) return 'Enter a salary up to ${JobLimits.salaryMax}.';
    }
    for (final v in [experienceMin, experienceMax]) {
      if (v != null && (v < 0 || v > JobLimits.experienceMax)) {
        return 'Experience is whole years from 0 to ${JobLimits.experienceMax}.';
      }
    }
    // The API checks both ranges on every save (a salary of zero is "not set"), not only when going live.
    if ((salaryMin ?? 0) > 0 && (salaryMax ?? 0) > 0 && salaryMin! > salaryMax!) {
      return 'Maximum salary must be at least the minimum.';
    }
    if (experienceMin != null && experienceMax != null && experienceMin! > experienceMax!) {
      return 'Minimum experience cannot exceed the maximum.';
    }
    if (externalApply && applyUrl.trim().isNotEmpty && !isApplyUrl(applyUrl)) {
      return 'The apply link must be a full URL including https://';
    }
    return null;
  }

  JobDraft copyWith({
    String? title,
    String? description,
    String? department,
    String? seniority,
    bool clearSeniority = false,
    String? employmentType,
    String? workMode,
    String? country,
    String? state,
    List<String>? cities,
    Map<String, int>? cityOpenings,
    List<String>? skills,
    List<String>? preferredSkills,
    int? experienceMin,
    bool clearExperienceMin = false,
    int? experienceMax,
    bool clearExperienceMax = false,
    num? salaryMin,
    bool clearSalaryMin = false,
    num? salaryMax,
    bool clearSalaryMax = false,
    String? salaryCurrency,
    String? salaryPeriod,
    bool? salaryVisible,
    bool? negotiable,
    int? openings,
    bool? externalApply,
    String? applyUrl,
    DateTime? applyDeadline,
    bool clearDeadline = false,
    bool? requireResume,
    bool? showHiringContact,
    PostingStatus? status,
    List<ScreeningDraft>? screening,
    List<String>? jobFunctions,
  }) => JobDraft(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    department: department ?? this.department,
    seniority: clearSeniority ? null : (seniority ?? this.seniority),
    employmentType: employmentType ?? this.employmentType,
    workMode: workMode ?? this.workMode,
    country: country ?? this.country,
    state: state ?? this.state,
    cities: cities ?? this.cities,
    cityOpenings: cityOpenings ?? this.cityOpenings,
    skills: skills ?? this.skills,
    preferredSkills: preferredSkills ?? this.preferredSkills,
    experienceMin: clearExperienceMin ? null : (experienceMin ?? this.experienceMin),
    experienceMax: clearExperienceMax ? null : (experienceMax ?? this.experienceMax),
    salaryMin: clearSalaryMin ? null : (salaryMin ?? this.salaryMin),
    salaryMax: clearSalaryMax ? null : (salaryMax ?? this.salaryMax),
    salaryCurrency: salaryCurrency ?? this.salaryCurrency,
    salaryPeriod: salaryPeriod ?? this.salaryPeriod,
    salaryVisible: salaryVisible ?? this.salaryVisible,
    negotiable: negotiable ?? this.negotiable,
    openings: openings ?? this.openings,
    externalApply: externalApply ?? this.externalApply,
    applyUrl: applyUrl ?? this.applyUrl,
    applyDeadline: clearDeadline ? null : (applyDeadline ?? this.applyDeadline),
    requireResume: requireResume ?? this.requireResume,
    showHiringContact: showHiringContact ?? this.showHiringContact,
    status: status ?? this.status,
    screening: screening ?? this.screening,
    jobFunctions: jobFunctions ?? this.jobFunctions,
  );

  /// The body of `POST /jobs` / `PATCH /jobs/:id` (`CreateJobDto`). [status] is the move being made;
  /// null leaves the posting's status alone on an edit.
  Map<String, dynamic> toJson({PostingStatus? status}) {
    final list = [
      for (final c in cities)
        if (c.trim().isNotEmpty) c.trim(),
    ];
    final multi = list.length >= 2;
    final html = descriptionToHtml(description);
    return {
      'title': title.trim(),
      'description': htmlToPlainText(html).isEmpty ? null : html,
      'department': department.trim().isEmpty ? null : department.trim(),
      'seniority': ?seniority,
      'employmentType': employmentType,
      'workMode': workMode,
      'country': country,
      'state': state.trim().isEmpty ? null : state.trim(),
      'cities': list,
      'skills': [
        for (final s in skills)
          if (s.trim().isNotEmpty) s.trim(),
      ],
      'preferredSkills': [
        for (final s in preferredSkills)
          if (s.trim().isNotEmpty) s.trim(),
      ],
      'experienceMin': experienceMin,
      'experienceMax': experienceMax,
      'salaryMin': (salaryMin ?? 0) > 0 ? salaryMin : null,
      'salaryMax': (salaryMax ?? 0) > 0 ? salaryMax : null,
      'salaryCurrency': salaryCurrency,
      'salaryPeriod': salaryPeriod,
      'salaryVisible': salaryVisible,
      'negotiable': negotiable,
      'showHiringContact': showHiringContact,
      'requireResume': requireResume,
      'applyMethod': externalApply ? 'EXTERNAL_URL' : 'ON_PLATFORM',
      'applyUrl': externalApply ? (applyUrl.trim().isEmpty ? null : applyUrl.trim()) : null,
      'applyDeadline': applyDeadline?.toUtc().toIso8601String(),
      // Seats not counted yet are still one opening to a draft (the API wants at least 1; the checklist asks for the counts).
      'openings': multi ? (totalOpenings < 1 ? 1 : totalOpenings) : openings,
      'cityOpenings': multi
          ? [
              for (final c in list)
                if ((cityOpenings[c] ?? 0) >= 1) {'city': c, 'openings': cityOpenings[c]},
            ]
          : <Map<String, Object>>[],
      'status': (status ?? this.status).api,
      'jobFunctions': jobFunctions,
    };
  }
}

/// A person on the company's team who can sit on an interview panel.
class TeamMember {
  const TeamMember({required this.id, required this.name, required this.role});

  final String id;
  final String name;
  final String role;
}

/// An applicant on a job's pipeline.
class Applicant {
  const Applicant({
    required this.id,
    required this.jobId,
    required this.userId,
    required this.name,
    required this.stage,
    required this.appliedAt,
    this.email,
    this.photoUrl,
    this.headline,
    this.currentCompany,
    this.experienceYears,
    this.skills = const [],
    this.location,
    this.viewedAt,
    this.rating,
    this.matchScore,
    this.coverNote,
    this.expectedSalary,
    this.linkedinUrl,
    this.resumeTitle,
    this.resumeFileUrl,
    this.source,
    this.nextInterviewAt,
    this.offerStatus,
    this.qualificationsMet,
    this.qualificationsTotal,
    this.noticePeriodDays,
    this.profilePublic = false,
  });

  factory Applicant.fromJson(Map<String, dynamic> json, {String? apiBase}) {
    DateTime? date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
    final person = (json['applicant'] as Map?) ?? const {};
    final resume = (json['resume'] as Map?) ?? const {};
    final next = json['nextInterview'] as Map?;
    final offer = json['latestOffer'] as Map?;
    final qual = json['qualification'] as Map?;
    return Applicant(
      id: json['id'].toString(),
      jobId: '${json['jobId']}',
      userId: '${json['applicantId'] ?? person['id']}',
      name: '${person['firstName'] ?? ''} ${person['lastName'] ?? ''}'.trim(),
      stage: json['stage'] as String? ?? 'APPLIED',
      appliedAt: date(json['createdAt']) ?? DateTime.now(),
      email: person['email'] as String?,
      photoUrl: AppConfig.absoluteUrl(person['avatarUrl'] as String?, apiBase: apiBase),
      headline: resume['headline'] as String?,
      currentCompany: json['currentCompany'] as String? ?? resume['currentCompany'] as String?,
      experienceYears: (resume['experienceYears'] as num?)?.toDouble() ?? (json['experienceYears'] as num?)?.toDouble(),
      skills: [for (final s in (resume['skills'] as List? ?? const [])) s.toString()],
      location: resume['currentLocation'] as String?,
      viewedAt: date(json['viewedAt']),
      rating: (json['rating'] as num?)?.toInt(),
      matchScore: (json['matchScore'] as num?)?.round(),
      coverNote: json['coverNote'] as String?,
      expectedSalary: num.tryParse('${json['expectedSalary'] ?? ''}'),
      linkedinUrl: json['linkedinUrl'] as String?,
      resumeTitle: resume['title'] as String?,
      resumeFileUrl: AppConfig.absoluteUrl((json['resumeFileUrl'] ?? resume['fileUrl']) as String?, apiBase: apiBase),
      source: json['source'] as String?,
      nextInterviewAt: date(next?['scheduledAt']),
      offerStatus: offer?['status'] as String?,
      qualificationsMet: (qual?['met'] as num?)?.toInt() ?? (json['qualificationsMet'] as num?)?.toInt(),
      qualificationsTotal: (qual?['total'] as num?)?.toInt() ?? (json['qualificationsTotal'] as num?)?.toInt(),
      noticePeriodDays: (resume['noticePeriodDays'] as num?)?.toInt(),
      profilePublic: person['profilePublic'] == true,
    );
  }

  final String id;
  final String jobId;
  final String userId;
  final String name;

  /// APPLIED, SCREENING, INTERVIEW, OFFER, HIRED, REJECTED or WITHDRAWN.
  final String stage;
  final DateTime appliedAt;
  final String? email;
  final String? photoUrl;
  final String? headline;
  final String? currentCompany;
  final double? experienceYears;
  final List<String> skills;
  final String? location;
  final DateTime? viewedAt;
  final int? rating;
  final int? matchScore;
  final String? coverNote;
  final num? expectedSalary;
  final String? linkedinUrl;
  final String? resumeTitle;
  final String? resumeFileUrl;
  final String? source;
  final DateTime? nextInterviewAt;
  final String? offerStatus;
  final int? qualificationsMet;
  final int? qualificationsTotal;
  final int? noticePeriodDays;
  final bool profilePublic;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return '${parts.first[0]}${parts.length > 1 ? parts.last[0] : ''}'.toUpperCase();
  }

  bool get viewed => viewedAt != null;

  Applicant copyWith({
    String? stage,
    int? rating,
    DateTime? viewedAt,
    String? offerStatus,
    DateTime? nextInterviewAt,
  }) => Applicant(
    id: id,
    jobId: jobId,
    userId: userId,
    name: name,
    stage: stage ?? this.stage,
    appliedAt: appliedAt,
    email: email,
    photoUrl: photoUrl,
    headline: headline,
    currentCompany: currentCompany,
    experienceYears: experienceYears,
    skills: skills,
    location: location,
    viewedAt: viewedAt ?? this.viewedAt,
    rating: rating ?? this.rating,
    matchScore: matchScore,
    coverNote: coverNote,
    expectedSalary: expectedSalary,
    linkedinUrl: linkedinUrl,
    resumeTitle: resumeTitle,
    resumeFileUrl: resumeFileUrl,
    source: source,
    nextInterviewAt: nextInterviewAt ?? this.nextInterviewAt,
    offerStatus: offerStatus ?? this.offerStatus,
    qualificationsMet: qualificationsMet,
    qualificationsTotal: qualificationsTotal,
    noticePeriodDays: noticePeriodDays,
    profilePublic: profilePublic,
  );
}

/// A job's applicants, with how many sit at each stage.
class ApplicantsPage {
  const ApplicantsPage({required this.applicants, this.stageCounts = const {}});

  final List<Applicant> applicants;
  final Map<String, int> stageCounts;
}

/// One interview round as the hiring team reads it.
class TeamInterview {
  const TeamInterview({
    required this.id,
    required this.round,
    required this.scheduledAt,
    required this.mode,
    required this.status,
    this.title,
    this.durationMins = 60,
    this.meetingLink,
    this.location,
    this.mapLink,
    this.notes,
    this.panel = const [],
    this.feedback = const [],
  });

  factory TeamInterview.fromJson(Map<String, dynamic> json) => TeamInterview(
    id: json['id'].toString(),
    round: (json['round'] as num?)?.toInt() ?? 1,
    scheduledAt: DateTime.tryParse(json['scheduledAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    mode: json['mode'] as String? ?? 'VIDEO',
    status: json['status'] as String? ?? 'SCHEDULED',
    title: json['title'] as String?,
    durationMins: (json['durationMins'] as num?)?.toInt() ?? 60,
    meetingLink: json['meetingLink'] as String?,
    location: json['location'] as String?,
    mapLink: json['mapLink'] as String?,
    notes: json['notes'] as String?,
    panel: [
      for (final p in (json['interviewers'] as List? ?? const []).whereType<Map>())
        TeamMember(id: '${p['id']}', name: '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim(), role: ''),
    ],
    feedback: [
      for (final f in (json['feedback'] as List? ?? const []).whereType<Map>())
        InterviewFeedbackRow(
          interviewer: () {
            final i = f['interviewer'] as Map?;
            return i == null ? 'A panelist' : '${i['firstName'] ?? ''} ${i['lastName'] ?? ''}'.trim();
          }(),
          rating: (f['overallRating'] as num?)?.toInt() ?? 0,
          recommendation: f['recommendation'] as String? ?? '',
          strengths: f['strengths'] as String?,
          concerns: f['concerns'] as String?,
        ),
    ],
  );

  final String id;
  final int round;
  final DateTime scheduledAt;

  /// VIDEO, IN_PERSON or PHONE.
  final String mode;

  /// SCHEDULED, RESCHEDULED, COMPLETED, CANCELLED or NO_SHOW.
  final String status;
  final String? title;
  final int durationMins;
  final String? meetingLink;
  final String? location;
  final String? mapLink;
  final String? notes;
  final List<TeamMember> panel;
  final List<InterviewFeedbackRow> feedback;

  String get name => (title ?? '').trim().isEmpty ? 'Round $round' : title!;

  bool get live => status == 'SCHEDULED' || status == 'RESCHEDULED';

  String get modeLabel => switch (mode) {
    'IN_PERSON' => 'In person',
    'PHONE' => 'Phone call',
    _ => 'Video call',
  };
}

/// A panelist's scorecard.
class InterviewFeedbackRow {
  const InterviewFeedbackRow({
    required this.interviewer,
    required this.rating,
    required this.recommendation,
    this.strengths,
    this.concerns,
  });

  final String interviewer;
  final int rating;
  final String recommendation;
  final String? strengths;
  final String? concerns;

  String get recommendationLabel => switch (recommendation) {
    'STRONG_YES' => 'Strong yes',
    'YES' => 'Yes',
    'NO' => 'No',
    'STRONG_NO' => 'Strong no',
    _ => recommendation,
  };
}

/// An offer as the hiring team reads it.
class TeamOffer {
  const TeamOffer({
    required this.id,
    required this.status,
    required this.amount,
    this.currency = 'INR',
    this.period = 'YEARLY',
    this.jobTitle,
    this.joiningDate,
    this.expiresAt,
    this.notes,
    this.candidateNote,
    this.sentAt,
  });

  factory TeamOffer.fromJson(Map<String, dynamic> json) {
    DateTime? date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
    return TeamOffer(
      id: json['id'].toString(),
      status: json['status'] as String? ?? 'DRAFT',
      amount: num.tryParse('${json['salaryAmount'] ?? 0}') ?? 0,
      currency: json['salaryCurrency'] as String? ?? 'INR',
      period: json['salaryPeriod'] as String? ?? 'YEARLY',
      jobTitle: json['jobTitle'] as String?,
      joiningDate: date(json['joiningDate']),
      expiresAt: date(json['expiresAt']),
      notes: json['notes'] as String?,
      candidateNote: json['candidateNote'] as String?,
      sentAt: date(json['sentAt']),
    );
  }

  final String id;

  /// DRAFT, SENT, ACCEPTED, DECLINED, WITHDRAWN or EXPIRED.
  final String status;
  final num amount;
  final String currency;
  final String period;
  final String? jobTitle;
  final DateTime? joiningDate;
  final DateTime? expiresAt;
  final String? notes;
  final String? candidateNote;
  final DateTime? sentAt;
}

/// A line of an applicant's activity (stage moves, notes, ratings, interviews, offers).
class ActivityEvent {
  const ActivityEvent({
    required this.type,
    required this.at,
    this.fromStage,
    this.toStage,
    this.note,
    this.rating,
    this.actor,
  });

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map?;
    return ActivityEvent(
      type: json['type'] as String? ?? 'NOTE',
      at: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      fromStage: json['fromStage'] as String?,
      toStage: json['toStage'] as String?,
      note: json['note'] as String?,
      rating: (json['rating'] as num?)?.toInt(),
      actor: actor == null ? null : '${actor['firstName'] ?? ''} ${actor['lastName'] ?? ''}'.trim(),
    );
  }

  final String type;
  final DateTime at;
  final String? fromStage;
  final String? toStage;
  final String? note;
  final int? rating;
  final String? actor;
}

/// A screening answer with whether it met the hiring team's bar.
class GradedAnswer {
  const GradedAnswer({
    required this.prompt,
    required this.answer,
    required this.type,
    this.meetsIdeal,
    this.mustHave = false,
  });

  final String prompt;
  final String answer;
  final String type;
  final bool? meetsIdeal;
  final bool mustHave;

  /// "Yes", "9 years", "A, B".
  String get display => switch (type) {
    'YES_NO' => answer == 'true' ? 'Yes' : (answer == 'false' ? 'No' : answer),
    'YEARS' => answer == '0' ? 'Less than a year' : '$answer ${answer == '1' ? 'year' : 'years'}',
    'MULTI_SELECT' => answer.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).join(', '),
    _ => answer,
  };
}

/// One applicant read whole: the pipeline row plus the team's view of the application.
class ApplicantDetail {
  const ApplicantDetail({
    required this.applicant,
    this.jobTitle,
    this.answers = const [],
    this.interviews = const [],
    this.offers = const [],
    this.events = const [],
    this.aiSummary,
  });

  final Applicant applicant;
  final String? jobTitle;
  final List<GradedAnswer> answers;
  final List<TeamInterview> interviews;
  final List<TeamOffer> offers;
  final List<ActivityEvent> events;
  final String? aiSummary;

  TeamOffer? get latestOffer => offers.isEmpty ? null : offers.first;

  ApplicantDetail copyWith({
    Applicant? applicant,
    List<TeamInterview>? interviews,
    List<TeamOffer>? offers,
    List<ActivityEvent>? events,
  }) => ApplicantDetail(
    applicant: applicant ?? this.applicant,
    jobTitle: jobTitle,
    answers: answers,
    interviews: interviews ?? this.interviews,
    offers: offers ?? this.offers,
    events: events ?? this.events,
    aiSummary: aiSummary,
  );
}

/// What "Schedule interview" sends (`CreateInterviewDto`), and its client-side rules.
class InterviewDraft {
  const InterviewDraft({
    required this.scheduledAt,
    this.title = '',
    this.mode = 'VIDEO',
    this.durationMins = 60,
    this.meetingLink = '',
    this.location = '',
    this.mapLink = '',
    this.notes = '',
    this.interviewerIds = const [],
  });

  final DateTime? scheduledAt;
  final String title;
  final String mode;
  final int durationMins;
  final String meetingLink;
  final String location;
  final String mapLink;
  final String notes;
  final List<String> interviewerIds;

  /// Why it cannot be booked, in the API's terms.
  String? problem(DateTime now) {
    final at = scheduledAt;
    if (at == null) return 'Pick a date and time.';
    if (!at.isAfter(now)) return 'Pick a time in the future.';
    if (durationMins < 5) return 'An interview is at least 5 minutes.';
    if (mode == 'IN_PERSON' && location.trim().isEmpty) return 'Give the address for an in-person interview.';
    if (mode == 'VIDEO' && meetingLink.trim().isNotEmpty && !isApplyUrl(meetingLink)) {
      return 'The meeting link must be a full URL starting with https://';
    }
    if (mapLink.trim().isNotEmpty && !isApplyUrl(mapLink)) {
      return 'The map link must be a full URL starting with https://';
    }
    if (notes.trim().length > JobLimits.interviewNotesMax) {
      return 'Keep the notes under ${JobLimits.interviewNotesMax} characters.';
    }
    if (interviewerIds.isEmpty) return 'Choose at least one person for the panel.';
    return null;
  }

  Map<String, dynamic> toJson() => {
    if (title.trim().isNotEmpty) 'title': title.trim(),
    'scheduledAt': scheduledAt!.toUtc().toIso8601String(),
    'durationMins': durationMins,
    'mode': mode,
    if (location.trim().isNotEmpty) 'location': location.trim(),
    if (meetingLink.trim().isNotEmpty) 'meetingLink': meetingLink.trim(),
    if (mapLink.trim().isNotEmpty) 'mapLink': mapLink.trim(),
    if (notes.trim().isNotEmpty) 'notes': notes.trim(),
    'interviewerIds': interviewerIds,
  };
}

/// What "Make an offer" sends (`CreateOfferDto`).
class OfferDraft {
  const OfferDraft({
    required this.amount,
    this.currency = 'INR',
    this.period = 'YEARLY',
    this.jobTitle = '',
    this.joiningDate,
    this.expiresAt,
    this.notes = '',
  });

  final num? amount;
  final String currency;
  final String period;
  final String jobTitle;
  final DateTime? joiningDate;
  final DateTime? expiresAt;
  final String notes;

  String? problem(DateTime now) {
    if (amount == null || amount! <= 0) return 'Enter the salary you are offering.';
    if (amount! > JobLimits.salaryMax) return 'Enter an amount up to ${JobLimits.salaryMax}.';
    if (expiresAt != null && !expiresAt!.isAfter(now)) return 'The reply-by date must be in the future.';
    return null;
  }

  Map<String, dynamic> toJson() => {
    'salaryAmount': amount,
    'salaryCurrency': currency,
    'salaryPeriod': period,
    if (jobTitle.trim().isNotEmpty) 'jobTitle': jobTitle.trim(),
    if (joiningDate != null) 'joiningDate': joiningDate!.toUtc().toIso8601String(),
    if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
    if (notes.trim().isNotEmpty) 'notes': notes.trim(),
  };
}
