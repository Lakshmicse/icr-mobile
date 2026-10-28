/// What the career screens draw: a candidate's own applications (with their
/// interviews, offers and timeline), job invitations from employers, saved
/// searches and a company's reviews, salaries and interviews. The live source
/// fills them from `GET /applications/mine`, `/applications/:id`,
/// `/job-invites/mine`, `/jobs/alerts` and `/companies/:id/*`.
library;

import '../jobs/job_models.dart';

export '../jobs/job_models.dart';
export 'insights_models.dart';

/// INTERVIEW mode: in person, video or phone.
enum InterviewMode {
  inPerson('In person'),
  video('Video call'),
  phone('Phone call');

  const InterviewMode(this.label);
  final String label;

  static InterviewMode fromApi(String? v) => switch (v) {
    'IN_PERSON' => inPerson,
    'PHONE' => phone,
    _ => video,
  };

  String get api => switch (this) {
    inPerson => 'IN_PERSON',
    video => 'VIDEO',
    phone => 'PHONE',
  };
}

/// One interview round, as the candidate (or the hiring team) reads it.
class CareerInterview {
  const CareerInterview({
    required this.id,
    required this.round,
    required this.scheduledAt,
    this.title,
    this.mode = InterviewMode.video,
    this.durationMins = 60,
    this.meetingLink,
    this.location,
    this.mapLink,
    this.status = 'SCHEDULED',
    this.interviewers = const [],
  });

  factory CareerInterview.fromJson(Map<String, dynamic> json) => CareerInterview(
    id: json['id'].toString(),
    round: (json['round'] as num?)?.toInt() ?? 1,
    title: (json['title'] as String?)?.trim().isEmpty == true ? null : json['title'] as String?,
    scheduledAt: DateTime.tryParse(json['scheduledAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    mode: InterviewMode.fromApi(json['mode'] as String?),
    durationMins: (json['durationMins'] as num?)?.toInt() ?? 60,
    meetingLink: json['meetingLink'] as String?,
    location: json['location'] as String?,
    mapLink: json['mapLink'] as String?,
    status: json['status'] as String? ?? 'SCHEDULED',
    interviewers: [
      for (final p in (json['interviewers'] as List? ?? const []).whereType<Map>())
        '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim(),
    ],
  );

  final String id;
  final int round;
  final String? title;
  final DateTime scheduledAt;
  final InterviewMode mode;
  final int durationMins;
  final String? meetingLink;
  final String? location;
  final String? mapLink;

  /// SCHEDULED, RESCHEDULED, COMPLETED, CANCELLED or NO_SHOW.
  final String status;

  /// The panel, by name (the hiring team's view only).
  final List<String> interviewers;

  /// "Round 2" when the recruiter gave it no title.
  String get name => title ?? 'Round $round';

  /// Still on: the candidate can turn up to it.
  bool get live => status == 'SCHEDULED' || status == 'RESCHEDULED';

  String get statusLabel => switch (status) {
    'SCHEDULED' => 'Scheduled',
    'RESCHEDULED' => 'Rescheduled',
    'COMPLETED' => 'Completed',
    'CANCELLED' => 'Cancelled',
    'NO_SHOW' => 'No-show',
    _ => status,
  };

  /// The recruiter's map link, else a search for the address (as the website's).
  Uri? get mapUrl {
    if (mode != InterviewMode.inPerson) return null;
    final link = mapLink?.trim();
    if (link != null && link.isNotEmpty) return Uri.tryParse(link);
    final address = location?.trim();
    if (address == null || address.isEmpty) return null;
    return Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeQueryComponent(address)}');
  }

  Uri? get joinUrl {
    final link = meetingLink?.trim();
    return mode == InterviewMode.video && link != null && link.isNotEmpty ? Uri.tryParse(link) : null;
  }
}

/// An offer the employer sent.
class CareerOffer {
  const CareerOffer({
    required this.id,
    required this.status,
    required this.salaryAmount,
    this.currency = 'INR',
    this.period = 'YEARLY',
    this.jobTitle,
    this.joiningDate,
    this.expiresAt,
    this.notes,
    this.sentAt,
    this.respondedAt,
  });

  factory CareerOffer.fromJson(Map<String, dynamic> json) => CareerOffer(
    id: json['id'].toString(),
    status: json['status'] as String? ?? 'SENT',
    salaryAmount: num.tryParse('${json['salaryAmount'] ?? 0}') ?? 0,
    currency: json['salaryCurrency'] as String? ?? 'INR',
    period: json['salaryPeriod'] as String? ?? 'YEARLY',
    jobTitle: json['jobTitle'] as String?,
    joiningDate: _date(json['joiningDate']),
    expiresAt: _date(json['expiresAt']),
    notes: json['notes'] as String?,
    sentAt: _date(json['sentAt']),
    respondedAt: _date(json['respondedAt']),
  );

  final String id;

  /// SENT (waiting on the candidate), ACCEPTED or DECLINED.
  final String status;
  final num salaryAmount;
  final String currency;
  final String period;
  final String? jobTitle;
  final DateTime? joiningDate;
  final DateTime? expiresAt;
  final String? notes;
  final DateTime? sentAt;
  final DateTime? respondedAt;

  bool get open => status == 'SENT';
}

/// One line of the candidate's timeline.
class CareerEvent {
  const CareerEvent({required this.type, required this.at, this.fromStage, this.toStage, this.note, this.actor});

  factory CareerEvent.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map?;
    return CareerEvent(
      type: json['type'] as String? ?? 'NOTE',
      at: _date(json['createdAt']) ?? DateTime.now(),
      fromStage: json['fromStage'] as String?,
      toStage: json['toStage'] as String?,
      note: json['note'] as String?,
      actor: actor == null ? null : '${actor['firstName'] ?? ''} ${actor['lastName'] ?? ''}'.trim(),
    );
  }

  /// STAGE_CHANGE, VIEWED, NOTE, RATING, INTERVIEW_SCHEDULED, OFFER_SENT, WITHDRAWN…
  final String type;
  final DateTime at;
  final String? fromStage;
  final String? toStage;
  final String? note;

  /// Who did it (the hiring team's timeline names them).
  final String? actor;
}

/// A screening answer the candidate sent.
class SentAnswer {
  const SentAnswer({required this.prompt, required this.answer, this.type = ScreeningType.text});

  final String prompt;
  final String answer;
  final ScreeningType type;

  /// The answer as words: "Yes", "4 / 5", "15+ years".
  String get display => switch (type) {
    ScreeningType.yesNo => answer == 'true' ? 'Yes' : (answer == 'false' ? 'No' : answer),
    ScreeningType.years => answer == '0' ? 'Less than a year' : '$answer ${answer == '1' ? 'year' : 'years'}',
    ScreeningType.multiSelect => answer.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).join(', '),
    _ => answer,
  };
}

/// One check of the match breakdown.
class MatchSignal {
  const MatchSignal({required this.label, required this.score, this.detail});

  final String label;

  /// 0–1.
  final double score;
  final String? detail;
}

/// One of the candidate's applications.
class CareerApplication {
  const CareerApplication({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.stage,
    required this.createdAt,
    this.companyId,
    this.companyName,
    this.companyLogo,
    this.city,
    this.jobStatus = 'OPEN',
    this.viewedAt,
    this.withdrawnAt,
    this.resumeTitle,
    this.coverNote,
    this.linkedinUrl,
    this.expectedSalary,
    this.matchScore,
    this.events = const [],
    this.offers = const [],
    this.interviews = const [],
    this.answers = const [],
    this.signals,
    this.signalsLocked = false,
    this.visibilityLocked = false,
    this.applicantId,
  });

  final String id;
  final String jobId;
  final String jobTitle;
  final String? companyId;
  final String? companyName;
  final FeedPicture? companyLogo;
  final String? city;

  /// The job's own status: an application to a CLOSED or PAUSED job waits on nothing.
  final String jobStatus;

  /// APPLIED, SCREENING, INTERVIEW, OFFER, HIRED, REJECTED or WITHDRAWN.
  final String stage;
  final DateTime createdAt;
  final DateTime? viewedAt;
  final DateTime? withdrawnAt;
  final String? resumeTitle;
  final String? coverNote;
  final String? linkedinUrl;
  final num? expectedSalary;
  final int? matchScore;
  final List<CareerEvent> events;

  /// Newest first; only the ones sent.
  final List<CareerOffer> offers;

  /// The rounds still on, soonest first (the list); every round (the detail).
  final List<CareerInterview> interviews;
  final List<SentAnswer> answers;

  /// The match breakdown; null when the plan leaves it out ([signalsLocked]).
  final List<MatchSignal>? signals;
  final bool signalsLocked;

  /// The plan hides the viewed receipt and the timeline.
  final bool visibilityLocked;

  /// Who applied (the detail endpoint answers staff and the team too).
  final String? applicantId;

  CareerOffer? get latestOffer => offers.isEmpty ? null : offers.first;

  /// A [Job] for the job sheet, from what the application carries.
  Job get job => Job(
    id: jobId,
    title: jobTitle,
    company: JobCompany(id: companyId ?? '', name: companyName ?? 'A company on ICR', logo: companyLogo),
    city: city,
    applied: stage != 'WITHDRAWN',
    status: jobStatus,
  );

  CareerApplication copyWith({String? stage, List<CareerOffer>? offers, DateTime? withdrawnAt}) => CareerApplication(
    id: id,
    jobId: jobId,
    jobTitle: jobTitle,
    stage: stage ?? this.stage,
    createdAt: createdAt,
    companyId: companyId,
    companyName: companyName,
    companyLogo: companyLogo,
    city: city,
    jobStatus: jobStatus,
    viewedAt: viewedAt,
    withdrawnAt: withdrawnAt ?? this.withdrawnAt,
    resumeTitle: resumeTitle,
    coverNote: coverNote,
    linkedinUrl: linkedinUrl,
    expectedSalary: expectedSalary,
    matchScore: matchScore,
    events: events,
    offers: offers ?? this.offers,
    interviews: interviews,
    answers: answers,
    signals: signals,
    signalsLocked: signalsLocked,
    visibilityLocked: visibilityLocked,
    applicantId: applicantId,
  );
}

/// An employer's invitation to apply.
class JobInvite {
  const JobInvite({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.status,
    required this.createdAt,
    this.companyName,
    this.city,
    this.workMode,
    this.message,
    this.invitedBy,
  });

  final String id;
  final String jobId;
  final String jobTitle;

  /// SENT or VIEWED (the list leaves out the declined and the applied).
  final String status;
  final DateTime createdAt;
  final String? companyName;
  final String? city;
  final WorkMode? workMode;
  final String? message;

  /// "Priya Sharma".
  final String? invitedBy;

  Job get job => Job(
    id: jobId,
    title: jobTitle,
    company: JobCompany(id: '', name: companyName ?? 'A company on ICR'),
    city: city,
    workMode: workMode,
  );

  JobInvite copyWith({String? status}) => JobInvite(
    id: id,
    jobId: jobId,
    jobTitle: jobTitle,
    status: status ?? this.status,
    createdAt: createdAt,
    companyName: companyName,
    city: city,
    workMode: workMode,
    message: message,
    invitedBy: invitedBy,
  );
}

/// How strong the member's résumé is and what would lift it (`GET /users/me/resume/insights`).
class ResumeInsights {
  const ResumeInsights({this.score, this.missing = const []});

  /// 0-100; null when there is no résumé.
  final int? score;
  final List<String> missing;
}

/// How visible the member was to recruiters in the last 30 days (`GET /users/me/profile-performance`).
class ProfilePerformance {
  const ProfilePerformance({
    this.searchAppearances30d = 0,
    this.profileViews30d = 0,
    this.invites = 0,
    this.applicationsViewed = 0,
  });

  final int searchAppearances30d;
  final int profileViews30d;
  final int invites;
  final int applicationsViewed;

  /// Invitations plus applications a recruiter opened: "recruiter actions".
  int get recruiterActions => invites + applicationsViewed;
}

/// A saved search and its alert.
class JobAlert {
  const JobAlert({
    required this.id,
    required this.name,
    this.criteria = const {},
    this.alertsEnabled = true,
    this.frequency = 'DAILY',
    this.newMatches = 0,
  });

  final String id;
  final String name;

  /// The board's query, as `GET /jobs` names it (`search`, `city`, `workMode`…).
  final Map<String, String> criteria;
  final bool alertsEnabled;

  /// DAILY or WEEKLY.
  final String frequency;
  final int newMatches;

  JobAlert copyWith({bool? alertsEnabled, String? frequency, int? newMatches}) => JobAlert(
    id: id,
    name: name,
    criteria: criteria,
    alertsEnabled: alertsEnabled ?? this.alertsEnabled,
    frequency: frequency ?? this.frequency,
    newMatches: newMatches ?? this.newMatches,
  );
}

/// A company's rating across its approved reviews.
class RatingSummary {
  const RatingSummary({this.count = 0, this.average, this.distribution = const {}, this.subRatings = const {}});

  final int count;
  final double? average;

  /// Stars (1–5) to how many reviews gave them.
  final Map<int, int> distribution;

  /// "Work-life balance" to its average, where there is one.
  final Map<String, double> subRatings;
}

class EmployerReview {
  const EmployerReview({
    required this.id,
    required this.rating,
    required this.createdAt,
    this.title,
    this.pros,
    this.cons,
    this.advice,
    this.jobTitle,
    this.employmentStatus,
    this.verifiedEmployee = false,
    this.status,
    this.subRatings = const {},
  });

  final String id;
  final int rating;
  final DateTime createdAt;
  final String? title;
  final String? pros;
  final String? cons;
  final String? advice;
  final String? jobTitle;

  /// The author's own review only (`GET /companies/:id/reviews/mine`): PENDING
  /// (in moderation), APPROVED or REJECTED. A public review has none.
  final String? status;

  /// Keys of [reviewSubRatings] to their stars, where the author gave one.
  final Map<String, int> subRatings;

  /// CURRENT or FORMER.
  final String? employmentStatus;
  final bool verifiedEmployee;
}

/// One role's pay at a company: percentiles a year, from at least the API's minimum of reports.
class SalaryRole {
  const SalaryRole({
    required this.jobTitle,
    required this.count,
    required this.p25,
    required this.median,
    required this.p75,
    this.avgExperience,
  });

  final String jobTitle;
  final int count;
  final double p25;
  final double median;
  final double p75;
  final double? avgExperience;
}

class SalaryInsights {
  const SalaryInsights({this.roles = const [], this.minSample = 5, this.totalReports = 0});

  final List<SalaryRole> roles;

  /// No role has [minSample] reports yet, so none is shown.
  bool get insufficient => roles.isEmpty;

  /// Fewer reports than this and a role is withheld.
  final int minSample;
  final int totalReports;
}

class InterviewReview {
  const InterviewReview({
    required this.id,
    required this.createdAt,
    this.jobTitle,
    this.difficulty,
    this.experienceRating,
    this.outcome,
    this.process,
    this.questions,
    this.durationDays,
  });

  final String id;
  final DateTime createdAt;
  final String? jobTitle;

  /// 1 (easy) to 5 (very hard).
  final int? difficulty;

  /// 1 (negative) to 5 (positive).
  final int? experienceRating;

  /// OFFER_ACCEPTED, OFFER_DECLINED, NO_OFFER or IN_PROGRESS.
  final String? outcome;

  String? get outcomeLabel => switch (outcome) {
    'OFFER_ACCEPTED' => 'Got an offer and accepted',
    'OFFER_DECLINED' => 'Got an offer and declined',
    'NO_OFFER' => 'No offer',
    'IN_PROGRESS' => 'Still in progress',
    null || '' => null,
    _ => outcome,
  };

  String? get experienceLabel => switch (experienceRating) {
    null => null,
    >= 4 => 'Positive experience',
    3 => 'Neutral experience',
    _ => 'Negative experience',
  };

  String? get difficultyLabel => switch (difficulty) {
    null => null,
    1 => 'Easy',
    2 => 'Fairly easy',
    3 => 'Average difficulty',
    4 => 'Hard',
    _ => 'Very hard',
  };
  final String? process;
  final String? questions;
  final int? durationDays;
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
