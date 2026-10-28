/// What the become-a-mentor screens draw: the caller's mentor profile and where
/// it stands, the gates in front of a listing (code of conduct, training,
/// evidence), and the person behind it (photo, role, years, languages, work
/// history). Filled from the API by `BecomeMentorRepository`.
library;

import '../mentorship_my/mentoring_clock.dart';

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
int _int(Object? v, [int fallback = 0]) => (v as num?)?.toInt() ?? fallback;
List<String> _strings(Object? v) => (v as List? ?? const []).map((e) => e.toString()).toList();
String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

/// `MentorProfileStatus`, worded as the website words it (`MENTOR_PROFILE_STATUS_LABELS`).
enum MentorStatus {
  draft('DRAFT', 'Draft'),
  pending('PENDING', 'Awaiting review'),
  approved('APPROVED', 'Listed'),
  paused('PAUSED', 'Paused'),
  rejected('REJECTED', 'Not approved');

  const MentorStatus(this.api, this.label);
  final String api;
  final String label;

  static MentorStatus fromApi(String? v) => values.firstWhere((s) => s.api == v, orElse: () => draft);

  /// What `submitMine` accepts from.
  bool get canSubmit => this == draft || this == rejected;

  /// On the directory (or hidden by ICR for a while).
  bool get listed => this == approved || this == paused;
}

/// `MentorAudience`: who a mentor is happy to hear from.
enum MentorAudience {
  earlyCareer('EARLY_CAREER', 'Early career', 'Studying, or under two years in'),
  workingProfessional('WORKING_PROFESSIONAL', 'Working professional', 'Established in an FM or CRE role'),
  careerSwitcher('CAREER_SWITCHER', 'Career switcher', 'Coming from another discipline or sector'),
  peopleLeader('PEOPLE_LEADER', 'People leader', 'Already leading a team or a portfolio'),
  returner('RETURNER', 'Returning after a break', 'Coming back after time away');

  const MentorAudience(this.api, this.label, this.note);
  final String api;
  final String label;
  final String note;

  static MentorAudience? fromApi(String? v) => values.where((a) => a.api == v).firstOrNull;
}

/// `MentorshipCadence`.
const mentorCadences = <String, String>{
  'WEEKLY': 'Weekly',
  'FORTNIGHTLY': 'Every two weeks',
  'MONTHLY': 'Monthly',
  'ADHOC': 'As needed',
};

/// `MentorshipMode`.
const mentorModes = <String, String>{
  'VIDEO': 'Video call',
  'PHONE': 'Phone',
  'IN_PERSON': 'In person',
  'CHAT': 'Chat / async',
};

/// The 24 competency domains every ICR certification is mapped to: the labels a mentor's
/// "areas of expertise" are stored as (the directory filters on them).
const competencyDomains = <String>[
  'Corporate Real Estate',
  'Facility Management',
  'Workplace Strategy',
  'Workplace Experience',
  'Real Estate Finance',
  'Portfolio Management',
  'Property & Asset Management',
  'Building Operations',
  'Engineering & Maintenance',
  'Capital Projects',
  'Sustainability & ESG',
  'Energy Management',
  'Health, Safety & Risk',
  'Smart Buildings & IoT',
  'AI & Digital Transformation',
  'Data Analytics & Business Intelligence',
  'Procurement & Contract Management',
  'Vendor Management',
  'Customer Experience',
  'Leadership & Strategic Management',
  'Communication & Stakeholder Management',
  'Innovation & Design Thinking',
  'Governance, Ethics & Compliance',
  'Business Continuity & Resilience',
];

/// Languages offered in the pickers (`SPOKEN_LANGUAGES`); free text is accepted too.
const spokenLanguages = <String>[
  'English',
  'Hindi',
  'Bengali',
  'Marathi',
  'Telugu',
  'Tamil',
  'Gujarati',
  'Kannada',
  'Malayalam',
  'Punjabi',
  'Odia',
  'Urdu',
  'Assamese',
  'Konkani',
];

/// One weekly window, in the profile's timezone (`weekday` 0 = Sunday), minutes from midnight.
class AvailabilityBlock {
  const AvailabilityBlock({required this.weekday, required this.startMin, required this.endMin});

  final int weekday;
  final int startMin;
  final int endMin;

  Map<String, dynamic> toJson() => {'weekday': weekday, 'startMin': startMin, 'endMin': endMin};

  @override
  bool operator ==(Object other) =>
      other is AvailabilityBlock && other.weekday == weekday && other.startMin == startMin && other.endMin == endMin;

  @override
  int get hashCode => Object.hash(weekday, startMin, endMin);
}

/// The caller's own mentor profile (`MyMentorProfileDto`).
class MyMentorProfile {
  const MyMentorProfile({
    required this.id,
    required this.status,
    this.bioHtml,
    this.competencies = const [],
    this.expertiseKeys = const [],
    this.certifications = const [],
    this.topics = const [],
    this.targetRoles = const [],
    this.targetAudiences = const [],
    this.preferredModes = const [],
    this.cadence,
    this.capacity = 2,
    this.openSlots = 0,
    this.timezone = 'Asia/Kolkata',
    this.availabilityNote,
    this.availability = const [],
    this.reviewNote,
    this.discoverable = true,
    this.meetingLink,
    this.headline,
  });

  final String id;
  final MentorStatus status;
  final String? bioHtml;
  final List<String> competencies;
  final List<String> expertiseKeys;
  final List<String> certifications;
  final List<String> topics;
  final List<String> targetRoles;
  final List<String> targetAudiences;
  final List<String> preferredModes;
  final String? cadence;
  final int capacity;
  final int openSlots;
  final String timezone;
  final String? availabilityNote;
  final List<AvailabilityBlock> availability;

  /// The reviewer's words when ICR asked for changes, shown verbatim.
  final String? reviewNote;

  /// "Accepting new requests".
  final bool discoverable;
  final String? meetingLink;
  final String? headline;

  factory MyMentorProfile.fromJson(Map<String, dynamic> j) => MyMentorProfile(
    id: j['id'] as String? ?? '',
    status: MentorStatus.fromApi(j['status'] as String?),
    bioHtml: j['bioHtml'] as String?,
    competencies: _strings(j['competencies']),
    expertiseKeys: _strings(j['expertiseKeys']),
    certifications: _strings(j['certifications']),
    topics: _strings(j['topics']),
    targetRoles: _strings(j['targetRoles']),
    targetAudiences: _strings(j['targetAudiences']),
    preferredModes: _strings(j['preferredModes']),
    cadence: j['cadence'] as String?,
    capacity: _int(j['capacity'], 2),
    openSlots: _int(j['openSlots']),
    timezone: j['timezone'] as String? ?? 'Asia/Kolkata',
    availabilityNote: _text(j['availabilityNote']),
    availability: [
      for (final b in (j['availabilityBlocks'] as List? ?? const []).whereType<Map<String, dynamic>>())
        AvailabilityBlock(weekday: _int(b['weekday']), startMin: _int(b['startMin']), endMin: _int(b['endMin'])),
    ],
    reviewNote: _text(j['reviewNote']),
    discoverable: j['discoverable'] != false,
    meetingLink: _text(j['meetingLink']),
    headline: _text(j['headline']),
  );
}

/// One required training module (`MentorTrainingStatusDto.required[]`).
class TrainingCourse {
  const TrainingCourse({
    required this.courseId,
    required this.code,
    required this.title,
    required this.status,
    required this.completed,
    this.slug,
    this.durationLabel,
  });

  final String courseId;
  final String code;
  final String title;
  final String? slug;
  final String? durationLabel;

  /// An enrolment status (PENDING, CONFIRMED, COMPLETED ...) or `NOT_ENROLLED`.
  final String status;
  final bool completed;

  bool get notEnrolled => status == 'NOT_ENROLLED';

  /// "Not started", "Enrolment confirmed", "Complete".
  String get statusLabel => completed
      ? 'Complete'
      : switch (status.toLowerCase()) {
          'not_enrolled' => 'Not started',
          'pending' => 'Enrolment pending',
          'confirmed' => 'Enrolment confirmed',
          'waitlisted' => 'Enrolment waitlisted',
          'cancelled' => 'Enrolment cancelled',
          'completed' => 'Enrolment completed',
          final other => 'Enrolment $other',
        };
}

/// Where the caller stands on the required training (`GET /mentorship/mentors/me/training`).
class TrainingStatus {
  const TrainingStatus({
    this.required = const [],
    this.completedCount = 0,
    this.requiredCount = 0,
    this.allComplete = true,
  });

  final List<TrainingCourse> required;
  final int completedCount;
  final int requiredCount;
  final bool allComplete;

  factory TrainingStatus.fromJson(Map<String, dynamic> j) => TrainingStatus(
    required: [
      for (final c in (j['required'] as List? ?? const []).whereType<Map<String, dynamic>>())
        TrainingCourse(
          courseId: c['courseId'] as String? ?? '',
          code: c['code'] as String? ?? '',
          title: c['title'] as String? ?? '',
          slug: c['slug'] as String?,
          durationLabel: _text(c['durationLabel']),
          status: c['status'] as String? ?? 'NOT_ENROLLED',
          completed: c['completed'] == true,
        ),
    ],
    completedCount: _int(j['completedCount']),
    requiredCount: _int(j['requiredCount']),
    allComplete: j['allComplete'] != false,
  );
}

/// The four-gate checklist (`GET /mentorship/mentors/me/readiness`).
class MentorReadiness {
  const MentorReadiness({
    this.profileComplete = false,
    this.conductAccepted = false,
    this.conductVersion,
    this.trainingComplete = true,
    this.training = const TrainingStatus(),
    this.documentsUploaded = 0,
    this.documentsVerified = 0,
    this.canSubmit = false,
    this.blockers = const [],
    this.approvalExpiresAt,
    this.renewalDue = false,
  });

  final bool profileComplete;
  final bool conductAccepted;
  final String? conductVersion;
  final bool trainingComplete;
  final TrainingStatus training;
  final int documentsUploaded;
  final int documentsVerified;
  final bool canSubmit;

  /// Why submitting is blocked, in the API's words.
  final List<String> blockers;
  final DateTime? approvalExpiresAt;
  final bool renewalDue;

  factory MentorReadiness.fromJson(Map<String, dynamic> j) => MentorReadiness(
    profileComplete: j['profileComplete'] == true,
    conductAccepted: j['conductAccepted'] == true,
    conductVersion: j['conductVersion'] as String?,
    trainingComplete: j['trainingComplete'] != false,
    training: TrainingStatus.fromJson(j['training'] as Map<String, dynamic>? ?? const {}),
    documentsUploaded: _int(j['documentsUploaded']),
    documentsVerified: _int(j['documentsVerified']),
    canSubmit: j['canSubmit'] == true,
    blockers: _strings(j['blockers']),
    approvalExpiresAt: _date(j['approvalExpiresAt']),
    renewalDue: j['renewalDue'] == true,
  );
}

/// One clause of the code of conduct.
class ConductClause {
  const ConductClause({required this.key, required this.title, required this.body});

  final String key;
  final String title;
  final String body;
}

/// The code of conduct as the API serves it (`GET /mentorship/code-of-conduct`).
class CodeOfConduct {
  const CodeOfConduct({required this.version, required this.clauses});

  final String version;
  final List<ConductClause> clauses;

  factory CodeOfConduct.fromJson(Map<String, dynamic> j) => CodeOfConduct(
    version: j['version'] as String? ?? '',
    clauses: [
      for (final c in (j['clauses'] as List? ?? const []).whereType<Map<String, dynamic>>())
        ConductClause(
          key: c['key'] as String? ?? '',
          title: c['title'] as String? ?? '',
          body: c['body'] as String? ?? '',
        ),
    ],
  );
}

/// `MentorDocumentKind` a mentor may attach (a photo ID is no longer collected).
const mentorDocumentKinds = <String, String>{
  'CERTIFICATION': 'Certificate',
  'EMPLOYMENT_PROOF': 'Proof of employment',
  'REFERENCE_LETTER': 'Reference',
  'BACKGROUND_CHECK': 'Background check',
  'OTHER': 'Other',
};

/// A document the mentor attached as evidence (`MentorDocumentDto`).
class MentorDocument {
  const MentorDocument({
    required this.id,
    required this.kind,
    required this.status,
    required this.createdAt,
    this.label,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.reviewNote,
  });

  final String id;
  final String kind;

  /// PENDING, VERIFIED, REJECTED.
  final String status;
  final DateTime createdAt;
  final String? label;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final String? reviewNote;

  String get kindLabel => mentorDocumentKinds[kind] ?? (kind == 'ID_PROOF' ? 'Photo ID' : 'Document');
  String get statusLabel => switch (status) {
    'VERIFIED' => 'Verified',
    'REJECTED' => 'Not accepted',
    _ => 'Awaiting review',
  };

  /// Only a document nobody has reviewed yet can be taken back.
  bool get removable => status == 'PENDING';

  factory MentorDocument.fromJson(Map<String, dynamic> j) => MentorDocument(
    id: j['id'] as String? ?? '',
    kind: j['kind'] as String? ?? 'OTHER',
    status: j['status'] as String? ?? 'PENDING',
    createdAt: _date(j['createdAt']) ?? mentoringNow(),
    label: _text(j['label']),
    fileUrl: _text(j['fileUrl']),
    fileName: _text(j['fileName']),
    fileSize: (j['fileSize'] as num?)?.toInt(),
    reviewNote: _text(j['reviewNote']),
  );
}

/// The person behind the profile, from `GET /users/me/profile`.
class PersonProfile {
  const PersonProfile({
    this.firstName = '',
    this.lastName = '',
    this.avatarUrl,
    this.designation,
    this.yearsExperience,
    this.languages = const [],
  });

  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String? designation;
  final int? yearsExperience;
  final List<String> languages;

  String get name => '$firstName $lastName'.trim();

  factory PersonProfile.fromJson(Map<String, dynamic> j) {
    final u = j['user'] as Map<String, dynamic>? ?? const {};
    return PersonProfile(
      firstName: u['firstName'] as String? ?? '',
      lastName: u['lastName'] as String? ?? '',
      avatarUrl: _text(u['avatarUrl']),
      designation: _text(u['designation']),
      yearsExperience: (u['yearsExperience'] as num?)?.toInt(),
      languages: _strings(u['languages']),
    );
  }
}

/// One role of the career history (`ExperienceDto`). The list is saved whole, so a row keeps every field it
/// came with (the linked company, the employment type, the industries) when another row changes.
class ExperienceRow {
  const ExperienceRow({
    required this.title,
    required this.organisation,
    required this.startYear,
    this.id,
    this.companyId,
    this.employmentType,
    this.city,
    this.industryKeys = const [],
    this.startMonth,
    this.endYear,
    this.endMonth,
    this.isCurrent = false,
    this.description,
  });

  final String? id;
  final String title;
  final String organisation;
  final String? companyId;
  final String? employmentType;
  final String? city;
  final List<String> industryKeys;
  final int startYear;
  final int? startMonth;
  final int? endYear;
  final int? endMonth;
  final bool isCurrent;
  final String? description;

  factory ExperienceRow.fromJson(Map<String, dynamic> j) {
    final company = j['company'];
    return ExperienceRow(
      id: j['id'] as String?,
      title: j['title'] as String? ?? '',
      organisation: j['organisation'] as String? ?? '',
      companyId: company is Map ? company['id'] as String? : null,
      employmentType: j['employmentType'] as String?,
      city: _text(j['city']),
      industryKeys: _strings(j['industryKeys']),
      startYear: _int(j['startYear'], mentoringNow().year),
      startMonth: (j['startMonth'] as num?)?.toInt(),
      endYear: (j['endYear'] as num?)?.toInt(),
      endMonth: (j['endMonth'] as num?)?.toInt(),
      isCurrent: j['isCurrent'] == true,
      description: _text(j['description']),
    );
  }

  /// A row as `PUT /profile/experience` takes it (empty strings stripped, as the website's editor does).
  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'organisation': organisation.trim(),
    if (companyId != null && companyId!.isNotEmpty) 'companyId': companyId,
    if (employmentType != null && employmentType!.isNotEmpty) 'employmentType': employmentType,
    if (city != null && city!.trim().isNotEmpty) 'city': city!.trim(),
    'industryKeys': industryKeys,
    'startYear': startYear,
    'startMonth': ?startMonth,
    if (!isCurrent && endYear != null) 'endYear': endYear,
    if (!isCurrent && endMonth != null) 'endMonth': endMonth,
    'isCurrent': isCurrent,
    if (description != null && description!.trim().isNotEmpty) 'description': description!.trim(),
  };

  /// "Mar 2021 - Present".
  String get span {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    String at(int? m, int y) => m == null ? '$y' : '${months[m.clamp(1, 12) - 1]} $y';
    final from = at(startMonth, startYear);
    final to = isCurrent || endYear == null ? 'Present' : at(endMonth, endYear!);
    return '$from - $to';
  }
}

/// A credential the member holds that has a short code a mentor card can show (`GET /credentials/me`).
class HeldCredential {
  const HeldCredential({required this.code, required this.label, required this.verified});

  final String code;
  final String label;
  final bool verified;
}

/// A picture or scan chosen on the phone (a seam, so a test can hand one in).
class PickedFile {
  const PickedFile({required this.bytes, required this.name, this.mimeType});

  final List<int> bytes;
  final String name;
  final String? mimeType;
}
