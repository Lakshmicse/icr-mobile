/// What the Jobs screens draw. The live source fills it from `GET /jobs`,
/// `GET /jobs/recommended` and `GET /jobs/:id`; the demo source holds the
/// designs' sample content.
library;

import '../feed/feed_models.dart' show FeedPicture;
import 'screening.dart';

export '../feed/feed_models.dart' show FeedPicture;
export 'screening.dart' show ScreeningQuestion, ScreeningType;

enum WorkMode {
  onsite('On-site'),
  remote('Remote'),
  hybrid('Hybrid');

  const WorkMode(this.label);
  final String label;

  static WorkMode? fromApi(String? v) => switch (v) {
    'ONSITE' => onsite,
    'REMOTE' => remote,
    'HYBRID' => hybrid,
    _ => null,
  };
}

enum EmploymentType {
  fullTime('Full-time'),
  partTime('Part-time'),
  contract('Contract'),
  internship('Internship'),
  temporary('Temporary'),
  freelance('Freelance'),
  volunteer('Volunteer'),
  other('Other');

  const EmploymentType(this.label);
  final String label;

  static EmploymentType? fromApi(String? v) => switch (v) {
    'FULL_TIME' => fullTime,
    'PART_TIME' => partTime,
    'CONTRACT' => contract,
    'INTERNSHIP' => internship,
    'TEMPORARY' => temporary,
    'FREELANCE' => freelance,
    'VOLUNTEER' => volunteer,
    'OTHER' => other,
    _ => null,
  };
}

class JobCompany {
  const JobCompany({
    required this.id,
    required this.name,
    this.logo,
    this.city,
    this.verified = false,
    this.tagline,
    this.kind,
    this.size,
    this.description,
    this.website,
    this.openJobs,
    this.cover,
    this.legalName,
  });

  final String id;
  final String name;
  final FeedPicture? logo;

  /// A photo for the "About the company" row (the company's first gallery photo).
  final FeedPicture? cover;

  /// "Global Infra Solutions Ltd.", when it differs from the brand. The API
  /// keeps it private to the company and ICR staff, so a live company has none.
  final String? legalName;
  final String? city;

  /// Verified or better on ICR's ladder.
  final bool verified;

  /// The line under the company's name. The API has no tagline: it is the
  /// company's industry ("Commercial Real Estate Services"), or the first
  /// sentence of its description when that is short.
  final String? tagline;

  /// "Real Estate": what kind of company it is.
  final String? kind;

  /// "8,400+ employees".
  final String? size;
  final String? description;
  final String? website;
  final int? openJobs;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return '${parts.first[0]}${parts.length > 1 ? parts.last[0] : ''}'.toUpperCase();
  }

  JobCompany merge(JobCompany? more) => more == null
      ? this
      : JobCompany(
          id: id,
          name: name,
          logo: logo ?? more.logo,
          city: city ?? more.city,
          verified: verified || more.verified,
          tagline: tagline ?? more.tagline,
          kind: kind ?? more.kind,
          size: size ?? more.size,
          description: description ?? more.description,
          website: website ?? more.website,
          openJobs: openJobs ?? more.openJobs,
          cover: cover ?? more.cover,
          legalName: legalName ?? more.legalName,
        );
}

/// The person a job names as its contact.
class JobContact {
  const JobContact({
    required this.name,
    required this.role,
    this.designation,
    this.photo,
    this.memberId,
    this.degree,
    this.activity,
  });

  final String name;

  /// "Job poster" or "Recruiter".
  final String role;
  final String? designation;
  final FeedPicture? photo;
  final String? memberId;

  /// "2nd": only the demo knows a connection degree.
  final String? degree;

  /// "Active today": likewise.
  final String? activity;
}

class Job {
  const Job({
    required this.id,
    required this.title,
    required this.company,
    this.city,
    this.state,
    this.country,
    this.workMode,
    this.employmentType,
    this.salaryMin,
    this.salaryMax,
    this.salaryPeriod = 'YEARLY',
    this.salaryVisible = true,
    this.postedAt,
    this.promoted = false,
    this.easyApply = true,
    this.applyUrl,
    this.skills = const [],
    this.preferredSkills = const [],
    this.matchScore,
    this.saved = false,
    this.applied = false,
    this.descriptionHtml,
    this.qualifications = const [],
    this.experienceMin,
    this.experienceMax,
    this.openings,
    this.applyDeadline,
    this.requireResume = false,
    this.screening = const [],
    this.contact,
    this.department,
    this.category,
    this.highlight,
    this.statusLine,
    this.applicants,
    this.views,
    this.educationQualifications = const [],
    this.preferredQualifications = const [],
    this.status = 'OPEN',
    this.genderPreference = 'ANY',
    this.diversityCategories = const [],
    this.diversityOnly = false,
  });

  final String id;
  final String title;
  final JobCompany company;
  final String? city;
  final String? state;
  final String? country;
  final WorkMode? workMode;
  final EmploymentType? employmentType;

  /// Whole rupees.
  final double? salaryMin;
  final double? salaryMax;

  /// YEARLY, MONTHLY or HOURLY.
  final String salaryPeriod;
  final bool salaryVisible;
  final DateTime? postedAt;
  final bool promoted;

  /// Applications are taken on ICR (as opposed to the employer's own site).
  final bool easyApply;
  final String? applyUrl;
  final List<String> skills;
  final List<String> preferredSkills;

  /// 0–100, from the recommendation feed or the match preview.
  final int? matchScore;
  final bool saved;
  final bool applied;

  // Detail only.
  final String? descriptionHtml;
  final List<String> qualifications;
  final int? experienceMin;
  final int? experienceMax;
  final int? openings;
  final DateTime? applyDeadline;
  final bool requireResume;

  /// The questions the employer asks with an application (`GET /jobs/:id`).
  final List<ScreeningQuestion> screening;
  final JobContact? contact;
  final String? department;

  /// The job's category label ("Integrated Facility Management").
  final String? category;

  /// The blue line under the title; the design's "Commercial Grade-A Towers •
  /// 2.4M+ sq.ft.". Live jobs build it from the category and department.
  final String? highlight;

  /// The green status ("Actively reviewing applicants").
  final String? statusLine;

  /// How many people applied. The API tells only the job's own team (a
  /// candidate's read has no count), so it is null for a candidate.
  final int? applicants;

  /// How many times the job was opened; the job's team only, like [applicants].
  final int? views;

  /// Degrees the job accepts (`Job.educationQualifications`, taxonomy keys such
  /// as `UG_BTECH_MECHANICAL`); a candidate needs any one of them.
  final List<String> educationQualifications;

  /// Credentials the employer would like ("RICS or IFMA Facility Management Charter").
  final List<String> preferredQualifications;

  /// OPEN, PAUSED, CLOSED…: a saved job may have stopped taking applications.
  final String status;

  /// ANY, MALE, FEMALE or OTHER: a gender-specific posting accepts only that gender.
  final String genderPreference;

  /// The groups the posting is opened to (`JobDiversityCategory`).
  final List<String> diversityCategories;

  /// Applications are accepted only from someone who declares one of [diversityCategories].
  final bool diversityOnly;

  /// How many questions the employer asks.
  int get screeningQuestions => screening.length;

  bool get isOpen => status == 'OPEN';

  /// "Mumbai, India".
  String? get place {
    final parts = [?city, if (country != null && country != 'India') country else if (city != null) 'India'];
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// "Bengaluru, Karnataka".
  String? get cityState {
    final parts = [?city, ?state];
    return parts.isEmpty ? null : parts.join(', ');
  }

  bool get externalApply => !easyApply && applyUrl != null;

  Job copyWith({bool? saved, bool? applied, int? matchScore, JobCompany? company, String? status}) => Job(
    id: id,
    title: title,
    company: company ?? this.company,
    city: city,
    state: state,
    country: country,
    workMode: workMode,
    employmentType: employmentType,
    salaryMin: salaryMin,
    salaryMax: salaryMax,
    salaryPeriod: salaryPeriod,
    salaryVisible: salaryVisible,
    postedAt: postedAt,
    promoted: promoted,
    easyApply: easyApply,
    applyUrl: applyUrl,
    skills: skills,
    preferredSkills: preferredSkills,
    matchScore: matchScore ?? this.matchScore,
    saved: saved ?? this.saved,
    applied: applied ?? this.applied,
    descriptionHtml: descriptionHtml,
    qualifications: qualifications,
    experienceMin: experienceMin,
    experienceMax: experienceMax,
    openings: openings,
    applyDeadline: applyDeadline,
    requireResume: requireResume,
    screening: screening,
    contact: contact,
    department: department,
    category: category,
    highlight: highlight,
    statusLine: statusLine,
    applicants: applicants,
    views: views,
    educationQualifications: educationQualifications,
    preferredQualifications: preferredQualifications,
    status: status ?? this.status,
    genderPreference: genderPreference,
    diversityCategories: diversityCategories,
    diversityOnly: diversityOnly,
  );
}

/// One line of "Your profile matches N of M requirements".
class MatchCheck {
  const MatchCheck({required this.label, this.detail, required this.met});

  final String label;
  final String? detail;
  final bool met;
}

class JobMatch {
  const JobMatch({this.score, this.checks = const [], this.locked = false, this.summary});

  /// 0–100 when the API scored the job for this member.
  final int? score;
  final List<MatchCheck> checks;

  /// The AI match preview needs Career Pro (or its scorer is down); the checks
  /// then come from comparing the job's requirements with the member's profile.
  final bool locked;

  /// The heading, when the source words it itself (the demo).
  final String? summary;

  int get met => checks.where((c) => c.met).length;
}

/// Who else works at the company, for "Nikhil M. and 4 others from ICR work
/// at this organization".
class CompanyPeople {
  const CompanyPeople({required this.names, required this.total, this.note, this.photos = const []});

  /// Short names, "Nikhil M.".
  final List<String> names;
  final int total;

  /// A sentence to show instead of the computed one.
  final String? note;

  /// Their photos, in step with [names]; null where a person has none (the
  /// strip then draws their initials).
  final List<FeedPicture?> photos;

  String? get text => note ?? sentence;

  /// The "+4" after the faces: everyone beside the first person named.
  int get others => total > 1 ? total - 1 : 0;

  List<String> get initials => names.take(2).map(initialsOf).toList();

  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return '${parts.first[0]}${parts.length > 1 ? parts.last[0] : ''}'.toUpperCase();
  }

  String? get sentence {
    if (names.isEmpty) return null;
    return others <= 0
        ? '${names.first} from ICR works at this organization.'
        : '${names.first} and $others other${others == 1 ? '' : 's'} from ICR work at this organization.';
  }
}

/// The bar under the chips: the search the board is scoped to.
class JobContext {
  const JobContext({required this.label, this.place, this.alertId, this.criteria = const {}});

  /// "Facilities & Real Estate".
  final String label;

  /// "Bengaluru, IN".
  final String? place;

  /// The saved search it came from, when it did.
  final String? alertId;

  /// What the saved search filters on, as the board's query names it
  /// (`city: "Bengaluru,Mumbai"`, `country: "India"`). While the scope is on,
  /// each entry counts in "Filters (n)" and narrows a search typed over it.
  final Map<String, String> criteria;
}

class JobFilters {
  const JobFilters({
    this.search = '',
    this.easyApply = true,
    this.postedWithinDays,
    this.workModes = const {},
    this.employmentTypes = const {},
    this.city,
  });

  final String search;
  final bool easyApply;
  final int? postedWithinDays;
  final Set<WorkMode> workModes;
  final Set<EmploymentType> employmentTypes;
  final String? city;

  bool get hasCity => city != null && city!.isNotEmpty;

  /// How many filters are in force: each one the "Filters (n)" chip counts
  /// (Easy Apply, the date, every work mode and type picked, the city).
  int get count =>
      (easyApply ? 1 : 0) +
      (postedWithinDays == null ? 0 : 1) +
      workModes.length +
      employmentTypes.length +
      (hasCity ? 1 : 0);

  /// Anything that turns the board into one list of results. Easy Apply does
  /// not: it is on by default and trims the sections where they stand.
  bool get narrows =>
      search.isNotEmpty || postedWithinDays != null || workModes.isNotEmpty || employmentTypes.isNotEmpty || hasCity;

  JobFilters copyWith({
    String? search,
    bool? easyApply,
    int? postedWithinDays,
    bool clearPosted = false,
    Set<WorkMode>? workModes,
    Set<EmploymentType>? employmentTypes,
    String? city,
    bool clearCity = false,
  }) => JobFilters(
    search: search ?? this.search,
    easyApply: easyApply ?? this.easyApply,
    postedWithinDays: clearPosted ? null : postedWithinDays ?? this.postedWithinDays,
    workModes: workModes ?? this.workModes,
    employmentTypes: employmentTypes ?? this.employmentTypes,
    city: clearCity ? null : city ?? this.city,
  );
}

class JobPage {
  const JobPage({required this.jobs, required this.hasMore});

  final List<Job> jobs;
  final bool hasMore;
}

/// A titled run of jobs on the board.
class JobSection {
  const JobSection({required this.key, required this.title, required this.jobs, this.hasMore = false});

  final String key;
  final String title;
  final List<Job> jobs;
  final bool hasMore;

  JobSection copyWith({List<Job>? jobs, bool? hasMore}) =>
      JobSection(key: key, title: title, jobs: jobs ?? this.jobs, hasMore: hasMore ?? this.hasMore);
}

/// Everything the Jobs tab shows at rest.
class JobsOverview {
  const JobsOverview({required this.sections, this.myJobs = 0, this.newAlerts = 0, this.alert});

  final List<JobSection> sections;

  /// Applications still open, for "My jobs".
  final int myJobs;

  /// New matches across the member's job alerts.
  final int newAlerts;

  /// The member's first saved search: the board's scope bar and its third
  /// section. Null when the member has none.
  final JobContext? alert;

  JobsOverview copyWith({List<JobSection>? sections, int? newAlerts}) => JobsOverview(
    sections: sections ?? this.sections,
    myJobs: myJobs,
    newAlerts: newAlerts ?? this.newAlerts,
    alert: alert,
  );
}

/// One of the member's applications, as "My jobs" lists it.
class JobApplication {
  const JobApplication({required this.id, required this.job, required this.stage, this.appliedAt});

  final String id;

  /// Only what the applications list carries of the job: title, company, city.
  final Job job;

  /// APPLIED, SCREENING, INTERVIEW, OFFER, HIRED, REJECTED or WITHDRAWN.
  final String stage;
  final DateTime? appliedAt;

  bool get open => stage != 'WITHDRAWN';

  /// "In screening", as the member reads it.
  String get stageLabel => switch (stage) {
    'APPLIED' => 'Applied',
    'SCREENING' => 'In screening',
    'INTERVIEW' => 'Interview',
    'OFFER' => 'Offer made',
    'HIRED' => 'Hired',
    'REJECTED' => 'Not selected',
    'WITHDRAWN' => 'Withdrawn',
    _ => stage,
  };
}

/// What the "My jobs" chip opens: the applications and the saved jobs.
class MyJobs {
  const MyJobs({this.applications = const [], this.saved = const []});

  final List<JobApplication> applications;
  final List<Job> saved;
}

/// One of the member's résumés, for the apply form's choice (`GET /users/me/resumes`).
class ResumeChoice {
  const ResumeChoice({required this.id, required this.title, this.isDefault = false, this.hasFile = false});

  final String id;
  final String title;
  final bool isDefault;

  /// An uploaded PDF rides with it (else it is the ICR résumé built from the profile).
  final bool hasFile;
}

/// The member's application allowance and paid capabilities (`GET /applications/quota`).
class SeekerQuota {
  const SeekerQuota({
    this.used = 0,
    this.limit,
    this.canApply = true,
    this.tier,
    this.applicationVisibility = true,
    this.aiInsights = false,
  });

  /// Applications sent this month.
  final int used;

  /// The month's allowance; null is unlimited.
  final int? limit;
  final bool canApply;
  final String? tier;

  /// The plan shows viewed receipts and the timeline.
  final bool applicationVisibility;

  /// The plan shows the match breakdown.
  final bool aiInsights;

  int? get left => limit == null ? null : (limit! - used).clamp(0, limit!);
}

/// What the apply form sends with `POST /jobs/:id/apply`.
class ApplyRequest {
  const ApplyRequest({this.phone, this.coverNote, this.resumeId, this.expectedSalary, this.answers = const {}});

  final String? phone;
  final String? coverNote;
  final String? resumeId;

  /// Whole rupees a year.
  final num? expectedSalary;

  /// Screening answers by question id.
  final Map<String, String> answers;
}
