import 'dart:typed_data';

/// The partner institute's Learning console, as the website's `/admin/learning/courses`, `/batches` and
/// `/enrolments` read it for a partner: the course, batch and enrolment rows (`GET /learning/admin/...`), the
/// console's context (`GET /learning/admin/me`), the institute's team, and the drafts the two sheets send.

String? _text(Object? v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

int? _int(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v');

List<String> _strings(Object? v) => [
  for (final s in v is List ? v : const [])
    if (s != null) '$s',
];

/// Who the console is being drawn for (`GET /learning/admin/me`, `LearningConsoleContext`): the institute, its
/// standing on ICR, whether ICR reviews its courses before they go live, and whether the viewer may publish.
class ConsoleContext {
  const ConsoleContext({
    required this.isPartner,
    this.providerId,
    this.providerName,
    this.partnerStatus,
    this.capabilities = const [],
    this.courseReviewRequired = false,
    this.canPublish = true,
  });

  final bool isPartner;
  final String? providerId;
  final String? providerName;

  /// `ACTIVE`, `SUSPENDED`, `ENDED`…; null when the API sent no partner state (ICR staff).
  final String? partnerStatus;

  /// What the institute's agreement covers (`LearningPartnerCapability`).
  final List<String> capabilities;

  /// ICR reviews this institute's courses: a course goes live through "Submit for review", never Publish.
  final bool courseReviewRequired;
  final bool canPublish;

  /// The capability each console area needs before a partner may change anything in it (the website's
  /// `LEARNING_AREA_CAPABILITY`).
  static const areaCapability = <String, String>{
    'courses': 'COURSE_LISTING',
    'publish': 'COURSE_LISTING',
    'materials': 'MATERIALS',
    'batches': 'BATCHES',
    'attendance': 'BATCHES',
    'enrolments': 'ENROLMENT',
    'assessments': 'ASSESSMENTS',
    'certificates': 'CERTIFICATES',
  };

  /// Whether the institute may change [area] (`partnerMayChange`): nothing while it is suspended or its agreement
  /// has ended, and only the areas the agreement covers. Always true with no partner state.
  bool mayChange(String area) {
    if (!isPartner || partnerStatus == null) return true;
    if (partnerStatus != 'ACTIVE') return false;
    final needed = areaCapability[area];
    return needed == null || capabilities.contains(needed);
  }

  factory ConsoleContext.fromJson(Map<String, dynamic> json) {
    final provider = json['provider'];
    final partner = json['partner'];
    return ConsoleContext(
      isPartner: json['isPartner'] == true,
      providerId: provider is Map ? _text(provider['id']) : null,
      providerName: provider is Map ? _text(provider['name']) : null,
      partnerStatus: partner is Map ? _text(partner['status']) : null,
      capabilities: partner is Map ? _strings(partner['capabilities']) : const [],
      courseReviewRequired: partner is Map && partner['courseReviewRequired'] == true,
      canPublish: json['canPublish'] != false,
    );
  }
}

/// A trainer named on a batch, with their answer (`BatchTrainerPlace`): `INVITED`, `ACCEPTED` or `DECLINED`.
class TrainerPlace {
  const TrainerPlace({required this.trainerId, required this.name, required this.status});

  final String trainerId;
  final String name;
  final String status;

  factory TrainerPlace.fromJson(Map<String, dynamic> json) => TrainerPlace(
    trainerId: '${json['trainerId'] ?? ''}',
    name: '${json['name'] ?? ''}',
    status: '${json['status'] ?? 'INVITED'}',
  );
}

/// One scheduled run of a course (`Batch`, from `GET /learning/admin/batches`, or inside a course's `batches`).
class ConsoleBatch {
  const ConsoleBatch({
    required this.id,
    required this.courseId,
    required this.code,
    required this.status,
    required this.mode,
    required this.startsAt,
    this.title,
    this.endsAt,
    this.enrollmentClosesAt,
    this.durationLabel,
    this.durationWeeks,
    this.durationHours,
    this.schedule,
    this.classDays = const [],
    this.classStartTime,
    this.classEndTime,
    this.timezone,
    this.location,
    this.meetingUrl,
    this.instructor,
    this.instructorTitle,
    this.maxSeats,
    this.reservedSeats = 0,
    this.waitlistEnabled = true,
    this.seatsTaken = 0,
    this.seatsCapacity,
    this.full = false,
    this.priceAmount,
    this.discountPercent = 0,
    this.discountEndsOn,
    this.notes,
    this.trainerPlaces = const [],
    this.enrolmentSpecialistId,
    this.enrolmentSpecialistName,
    this.courseCode,
    this.courseTitle,
    this.json = const {},
  });

  final String id;
  final String courseId;

  /// The run's name; null when it is called by its start month (then [code]).
  final String? title;

  /// Generated reference (`DFF1-202703`).
  final String code;

  /// `SCHEDULED`, `OPEN`, `RUNNING`, `COMPLETED` or `CANCELLED` as stored; the list shows [shownStatus].
  final String status;

  /// `VIRTUAL`, `IN_PERSON`, `ONLINE` or `HYBRID`.
  final String mode;
  final DateTime startsAt;
  final DateTime? endsAt;
  final DateTime? enrollmentClosesAt;
  final String? durationLabel;
  final int? durationWeeks;
  final int? durationHours;

  /// "Sat & Sun, 10:00–13:00", written by the API from the three fields below.
  final String? schedule;
  final List<int> classDays;
  final String? classStartTime;
  final String? classEndTime;
  final String? timezone;
  final String? location;
  final String? meetingUrl;
  final String? instructor;
  final String? instructorTitle;
  final int? maxSeats;
  final int reservedSeats;
  final bool waitlistEnabled;
  final int seatsTaken;
  final int? seatsCapacity;
  final bool full;

  /// Paise; null falls back to the course's price.
  final int? priceAmount;
  final int discountPercent;

  /// `YYYY-MM-DD`, the offer's last day; null runs it until removed.
  final String? discountEndsOn;
  final String? notes;
  final List<TrainerPlace> trainerPlaces;
  final String? enrolmentSpecialistId;
  final String? enrolmentSpecialistName;
  final String? courseCode;
  final String? courseTitle;

  /// The row as the API sent it, for the fields the sheet carries through unchanged.
  final Map<String, dynamic> json;

  String get name => title ?? code;

  factory ConsoleBatch.fromJson(Map<String, dynamic> json) {
    final course = json['course'];
    final specialist = json['enrolmentSpecialist'];
    return ConsoleBatch(
      id: '${json['id']}',
      courseId: '${json['courseId'] ?? (course is Map ? course['id'] : '') ?? ''}',
      title: _text(json['title']),
      code: '${json['code'] ?? ''}',
      status: '${json['status'] ?? 'OPEN'}',
      mode: '${json['mode'] ?? 'VIRTUAL'}',
      startsAt: _date(json['startsAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      endsAt: _date(json['endsAt']),
      enrollmentClosesAt: _date(json['enrollmentClosesAt']),
      durationLabel: _text(json['durationLabel']),
      durationWeeks: _int(json['durationWeeks']),
      durationHours: _int(json['durationHours']),
      schedule: _text(json['schedule']),
      classDays: [
        for (final d in json['classDays'] is List ? json['classDays'] as List : const [])
          if (_int(d) != null) _int(d)!,
      ],
      classStartTime: _text(json['classStartTime']),
      classEndTime: _text(json['classEndTime']),
      timezone: _text(json['timezone']),
      location: _text(json['location']),
      meetingUrl: _text(json['meetingUrl']),
      instructor: _text(json['instructor']),
      instructorTitle: _text(json['instructorTitle']),
      maxSeats: _int(json['maxSeats']),
      reservedSeats: _int(json['reservedSeats']) ?? 0,
      waitlistEnabled: json['waitlistEnabled'] != false,
      seatsTaken: _int(json['seatsTaken']) ?? 0,
      seatsCapacity: _int(json['seatsCapacity']) ?? _int(json['maxSeats']),
      full: json['full'] == true,
      priceAmount: _int(json['priceAmount']),
      discountPercent: _int(json['discountPercent']) ?? 0,
      discountEndsOn: _text(json['discountEndsOn']),
      notes: _text(json['notes']),
      trainerPlaces: [
        for (final p in json['trainerPlaces'] is List ? json['trainerPlaces'] as List : const [])
          if (p is Map) TrainerPlace.fromJson(p.cast<String, dynamic>()),
      ],
      enrolmentSpecialistId: _text(json['enrolmentSpecialistId']),
      enrolmentSpecialistName: specialist is Map ? _text(specialist['name']) : null,
      courseCode: course is Map ? _text(course['code']) : null,
      courseTitle: course is Map ? _text(course['title']) : null,
      json: json,
    );
  }
}

/// A taught course of the institute (`Course`, kind `DEVELOPMENT`, from `GET /learning/admin/courses`).
class ConsoleCourse {
  const ConsoleCourse({
    required this.id,
    required this.code,
    required this.title,
    required this.status,
    this.kind = 'DEVELOPMENT',
    this.providerId,
    this.summary,
    this.description,
    this.access = 'FREE',
    this.priceAmount,
    this.deliveryMode,
    this.durationLabel,
    this.cpdCredits = 0,
    this.imageUrl,
    this.brochureUrl,
    this.category,
    this.subcategory,
    this.learningOutcomes = const [],
    this.audience = const [],
    this.reviewNote,
    this.batches = const [],
    this.json = const {},
  });

  final String id;
  final String code;
  final String title;

  /// `DRAFT`, `PENDING_REVIEW`, `REJECTED`, `PUBLISHED` or `ARCHIVED`.
  final String status;
  final String kind;
  final String? providerId;
  final String? summary;
  final String? description;

  /// `FREE` or `PAID`.
  final String access;
  final int? priceAmount;
  final String? deliveryMode;
  final String? durationLabel;
  final int cpdCredits;
  final String? imageUrl;
  final String? brochureUrl;
  final String? category;
  final String? subcategory;
  final List<String> learningOutcomes;
  final List<String> audience;

  /// ICR's reviewer's note, when the course was sent back.
  final String? reviewNote;

  /// Every run, past and cancelled included (the admin list).
  final List<ConsoleBatch> batches;

  /// The row as the API sent it, for the fields the sheet carries through unchanged.
  final Map<String, dynamic> json;

  bool get published => status == 'PUBLISHED';
  bool get pendingReview => status == 'PENDING_REVIEW';
  bool get paid => access == 'PAID';

  /// A batch still going ahead — scheduled, open or running — which a partner's course needs before it can be
  /// published (`hasActiveBatch`).
  bool get hasActiveBatch => batches.any((b) => activeBatchStatuses.contains(b.status));

  /// The soonest batch still ahead of [now]; the admin list includes past runs.
  DateTime? nextBatchStart(DateTime now) {
    final ahead = [
      for (final b in batches)
        if (!b.startsAt.isBefore(now)) b.startsAt,
    ]..sort();
    return ahead.isEmpty ? null : ahead.first;
  }

  factory ConsoleCourse.fromJson(Map<String, dynamic> json) => ConsoleCourse(
    id: '${json['id']}',
    kind: '${json['kind'] ?? 'DEVELOPMENT'}',
    providerId: _text(json['providerId']) ?? (json['provider'] is Map ? _text((json['provider'] as Map)['id']) : null),
    code: '${json['code'] ?? ''}',
    title: '${json['title'] ?? ''}',
    status: '${json['status'] ?? 'DRAFT'}',
    summary: _text(json['summary']),
    description: _text(json['description']),
    access: '${json['access'] ?? 'FREE'}',
    priceAmount: _int(json['priceAmount']),
    deliveryMode: _text(json['deliveryMode']),
    durationLabel: _text(json['durationLabel']),
    cpdCredits: _int(json['cpdCredits']) ?? 0,
    imageUrl: _text(json['imageUrl']),
    brochureUrl: _text(json['brochureUrl']),
    category: _text(json['category']),
    subcategory: _text(json['subcategory']),
    learningOutcomes: _strings(json['learningOutcomes']),
    audience: _strings(json['audience']),
    reviewNote: _text(json['reviewNote']),
    batches: [
      for (final b in json['batches'] is List ? json['batches'] as List : const [])
        if (b is Map) ConsoleBatch.fromJson(b.cast<String, dynamic>()),
    ],
    json: json,
  );
}

/// A member of the institute's team (`Trainer`): a trainer or an enrolment specialist, with whether an ICR
/// account is linked (a trainer is asked onto a batch through it).
class FacultyMember {
  const FacultyMember({
    required this.id,
    required this.name,
    required this.role,
    this.title,
    this.active = true,
    this.hasUser = false,
  });

  final String id;
  final String name;

  /// `TRAINER` or `ENROLMENT_SPECIALIST`.
  final String role;
  final String? title;
  final bool active;
  final bool hasUser;

  String get label => '$name${title != null ? ' — $title' : ''}${active ? '' : ' (retired)'}';

  factory FacultyMember.fromJson(Map<String, dynamic> json) => FacultyMember(
    id: '${json['id']}',
    name: '${json['name'] ?? ''}',
    role: '${json['role'] ?? 'TRAINER'}',
    title: _text(json['title']),
    active: json['active'] != false,
    hasUser: json['user'] is Map,
  );
}

/// One enrolment, as the console lists it (`AdminEnrollment`).
class ConsoleEnrolment {
  const ConsoleEnrolment({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    this.batchId,
    this.batchTitle,
    this.batchMode,
    this.batchStartsAt,
    this.note,
    this.decidedAt,
  });

  final String id;

  /// `PENDING`, `CONFIRMED`, `WAITLISTED`, `CANCELLED` or `COMPLETED`.
  final String status;
  final DateTime createdAt;
  final String firstName;
  final String lastName;
  final String email;
  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String? batchId;
  final String? batchTitle;
  final String? batchMode;

  /// The batch's start, else the cohort date at the moment of enrolling.
  final DateTime? batchStartsAt;
  final String? note;
  final DateTime? decidedAt;

  String get name => '$firstName $lastName'.trim();

  ConsoleEnrolment copyWith({String? status, DateTime? decidedAt}) => ConsoleEnrolment(
    id: id,
    status: status ?? this.status,
    createdAt: createdAt,
    firstName: firstName,
    lastName: lastName,
    email: email,
    courseId: courseId,
    courseCode: courseCode,
    courseTitle: courseTitle,
    batchId: batchId,
    batchTitle: batchTitle,
    batchMode: batchMode,
    batchStartsAt: batchStartsAt,
    note: note,
    decidedAt: decidedAt ?? this.decidedAt,
  );

  factory ConsoleEnrolment.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map ? (json['user'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final course = json['course'] is Map ? (json['course'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final batch = json['batch'] is Map ? (json['batch'] as Map).cast<String, dynamic>() : null;
    return ConsoleEnrolment(
      id: '${json['id']}',
      status: '${json['status'] ?? 'PENDING'}',
      createdAt: _date(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      firstName: '${user['firstName'] ?? ''}',
      lastName: '${user['lastName'] ?? ''}',
      email: '${user['email'] ?? ''}',
      courseId: '${course['id'] ?? json['courseId'] ?? ''}',
      courseCode: '${course['code'] ?? ''}',
      courseTitle: '${course['title'] ?? ''}',
      batchId: _text(json['batchId']),
      batchTitle: batch == null ? null : _text(batch['title']),
      batchMode: batch == null ? null : _text(batch['mode']),
      batchStartsAt: (batch == null ? null : _date(batch['startsAt'])) ?? _date(json['batchStartsAt']),
      note: _text(json['note']),
      decidedAt: _date(json['decidedAt']),
    );
  }
}

/// One page of enrolments, newest first.
class EnrolmentsPage {
  const EnrolmentsPage({required this.rows, required this.page, required this.totalPages, required this.total});

  final List<ConsoleEnrolment> rows;
  final int page;
  final int totalPages;
  final int total;

  bool get hasMore => page < totalPages;

  factory EnrolmentsPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] is Map ? (json['meta'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final rows = json['data'];
    return EnrolmentsPage(
      rows: [
        for (final r in rows is List ? rows : const [])
          if (r is Map) ConsoleEnrolment.fromJson(r.cast<String, dynamic>()),
      ],
      page: _int(meta['page']) ?? 1,
      totalPages: _int(meta['totalPages']) ?? 1,
      total: _int(meta['total']) ?? 0,
    );
  }
}

/// A platform category a course is filed under (`GET /categories/tree?kind=SERVICE&depth=2`): a level-1 node
/// and its level-2 children. The catalogue's Category filter narrows by it.
class CourseCategory {
  const CourseCategory({required this.key, required this.name, this.children = const []});

  final String key;
  final String name;
  final List<CourseCategory> children;

  factory CourseCategory.fromJson(Map<String, dynamic> json) => CourseCategory(
    key: '${json['key'] ?? ''}',
    name: '${json['name'] ?? ''}',
    children: [
      for (final c in json['children'] is List ? json['children'] as List : const [])
        if (c is Map && c['active'] != false && c['key'] != null) CourseCategory.fromJson(c.cast<String, dynamic>()),
    ],
  );
}

/// A file picked on the phone for `POST /uploads`.
class UploadFile {
  const UploadFile({required this.name, required this.bytes, required this.mimeType});

  final String name;
  final Uint8List bytes;
  final String mimeType;

  int get size => bytes.length;
}

// --- drafts ---------------------------------------------------------------------------------------------------------

/// What the course sheet sends (`CourseInput`, a partner's taught course): the website's fields, with everything
/// else the course already carries sent back unchanged on an edit, as `fromCourse` does.
class CourseDraft {
  CourseDraft({
    this.title = '',
    this.summary = '',
    this.category,
    this.subcategory,
    this.imageUrl,
    this.brochureUrl,
    this.description = '',
    List<String>? learningOutcomes,
    List<String>? audience,
    this.access = 'FREE',
    Map<String, dynamic>? carried,
  }) : learningOutcomes = learningOutcomes ?? [],
       audience = audience ?? [],
       carried = carried ?? {};

  factory CourseDraft.fromCourse(ConsoleCourse c) => CourseDraft(
    title: c.title,
    summary: c.summary ?? '',
    category: c.category,
    subcategory: c.subcategory,
    imageUrl: c.imageUrl,
    brochureUrl: c.brochureUrl,
    description: c.description ?? '',
    learningOutcomes: [...c.learningOutcomes],
    audience: [...c.audience],
    access: c.access,
    carried: {
      for (final key in _carriedCourseFields)
        if (c.json[key] != null) key: c.json[key],
    },
  );

  /// The fields `fromCourse` sends that the sheet does not ask for.
  static const _carriedCourseFields = [
    'code',
    'level',
    'status',
    'enrollmentOpen',
    'batchStartsAt',
    'batchEndsAt',
    'enrollmentClosesAt',
    'durationLabel',
    'durationWeeks',
    'durationHours',
    'cpdCredits',
    'maxSeats',
    'reservedSeats',
    'waitlistEnabled',
    'deliveryMode',
    'language',
    'location',
    'instructor',
    'competencies',
    'prerequisites',
    'knowledgeAreas',
    'formats',
    'domains',
    'sortOrder',
  ];

  String title;
  String summary;
  String? category;
  String? subcategory;
  String? imageUrl;
  String? brochureUrl;
  String description;
  List<String> learningOutcomes;
  List<String> audience;
  String access;

  /// An existing course's other fields, sent back as they were.
  final Map<String, dynamic> carried;

  /// Whether the sheet's Save is allowed: a name and a category, as the website's button.
  bool get complete => title.trim().isNotEmpty && (category ?? '').isNotEmpty;

  /// The body: a new course is `blank()` plus what was typed; an edit is `fromCourse` with the changes.
  Map<String, Object?> toJson({required bool create, bool publish = false}) {
    final outcomes = [
      for (final s in learningOutcomes)
        if (s.trim().isNotEmpty) s.trim(),
    ];
    final who = [
      for (final s in audience)
        if (s.trim().isNotEmpty) s.trim(),
    ];
    return {
      if (create) ...{
        'kind': 'DEVELOPMENT',
        'code': '',
        'providerId': null,
        'level': 'FOUNDATION',
        'status': 'DRAFT',
        'enrollmentOpen': true,
        'waitlistEnabled': true,
        'reservedSeats': 0,
        'cpdCredits': 0,
        'language': 'English',
        'competencies': const <String>[],
        'prerequisites': const <String>[],
        'knowledgeAreas': const <String>[],
        'sortOrder': 0,
      } else
        ...carried,
      'title': title.trim(),
      'summary': summary.trim(),
      'category': (category ?? '').isEmpty ? null : category,
      'subcategory': (subcategory ?? '').isEmpty ? null : subcategory,
      // A cover or brochure taken off an existing course is cleared; the website leaves the field out, which
      // keeps the old file.
      if (imageUrl != null) 'imageUrl': imageUrl else if (!create) 'imageUrl': null,
      if (brochureUrl != null) 'brochureUrl': brochureUrl else if (!create) 'brochureUrl': null,
      'description': description.trim(),
      'learningOutcomes': outcomes,
      'audience': who,
      'access': access,
      if (publish) 'status': 'PUBLISHED',
    };
  }
}

/// What the batch sheet sends (`BatchInput`): the website's fields. Days are stored at their UTC midnight
/// (`YYYY-MM-DDT00:00:00.000Z`) so they name the same calendar day everywhere.
class BatchDraft {
  BatchDraft({
    this.title = '',
    this.startsAt,
    this.endsAt,
    this.enrollmentClosesAt,
    this.mode = 'VIRTUAL',
    this.cancelled = false,
    Set<int>? classDays,
    this.classStartTime,
    this.classEndTime,
    this.timezone = defaultTimezone,
    this.location = '',
    List<String>? trainerIds,
    this.enrolmentSpecialistId,
    this.maxSeats,
    this.priceAmount,
    this.discountPercent = 0,
    this.discountEndsOn,
    Map<String, dynamic>? carried,
    this.hadEnrollmentClosesAt = false,
    this.hadMaxSeats = false,
  }) : classDays = classDays ?? {...batchWeekdays},
       trainerIds = trainerIds ?? [],
       carried = carried ?? {};

  /// A new batch: every weekday ticked (unticking the days off is quicker), the course's venue.
  factory BatchDraft.blank(ConsoleCourse course) => BatchDraft(location: _text(course.json['location']) ?? '');

  factory BatchDraft.fromBatch(ConsoleBatch b) => BatchDraft(
    title: b.title ?? '',
    startsAt: b.startsAt.toUtc().toIso8601String(),
    endsAt: b.endsAt?.toUtc().toIso8601String(),
    enrollmentClosesAt: b.enrollmentClosesAt,
    mode: b.mode,
    cancelled: b.status == 'CANCELLED',
    classDays: {...b.classDays},
    classStartTime: b.classStartTime,
    classEndTime: b.classEndTime,
    timezone: b.timezone ?? '',
    location: b.location ?? '',
    trainerIds: [for (final p in b.trainerPlaces) p.trainerId],
    enrolmentSpecialistId: b.enrolmentSpecialistId,
    maxSeats: b.maxSeats,
    priceAmount: b.priceAmount,
    discountPercent: b.discountPercent,
    discountEndsOn: b.discountEndsOn,
    hadEnrollmentClosesAt: b.enrollmentClosesAt != null,
    hadMaxSeats: b.maxSeats != null,
    carried: {
      for (final key in _carriedBatchFields)
        if (b.json[key] != null) key: b.json[key],
    },
  );

  /// The fields `fromBatch` sends that the sheet does not ask for.
  static const _carriedBatchFields = [
    'instructor',
    'instructorEmail',
    'instructorTitle',
    'instructorPhotoUrl',
    'meetingUrl',
    'reservedSeats',
    'waitlistEnabled',
    'priceCurrency',
    'notes',
    'sortOrder',
  ];

  static const defaultTimezone = 'Asia/Kolkata';

  /// Monday first, the way a timetable reads (`BATCH_WEEKDAYS`; 0 is Sunday).
  static const batchWeekdays = [1, 2, 3, 4, 5, 6, 0];

  String title;

  /// ISO, the day's UTC midnight.
  String? startsAt;
  String? endsAt;
  DateTime? enrollmentClosesAt;
  String mode;

  /// Any status but Cancelled tells the API "not cancelled"; it sets the real one from the dates.
  bool cancelled;
  Set<int> classDays;
  String? classStartTime;
  String? classEndTime;
  String timezone;
  String location;
  List<String> trainerIds;
  String? enrolmentSpecialistId;
  int? maxSeats;

  /// Paise.
  int? priceAmount;
  int discountPercent;
  String? discountEndsOn;
  final Map<String, dynamic> carried;
  final bool hadEnrollmentClosesAt;
  final bool hadMaxSeats;

  bool get inPerson => mode == 'IN_PERSON' || mode == 'HYBRID';

  Map<String, Object?> toJson({required bool create, required bool instituteCourse, required List<int> pickedDays}) {
    return {
      if (create) ...{'waitlistEnabled': true, 'reservedSeats': 0, 'sortOrder': 0} else ...carried,
      // The website sends the name as typed; blank on a new batch lets the API name it after the start month.
      if (title.trim().isNotEmpty || !create) 'title': title.trim(),
      'startsAt': startsAt,
      'endsAt': endsAt,
      if (enrollmentClosesAt != null)
        'enrollmentClosesAt': enrollmentClosesAt!.toUtc().toIso8601String()
      else if (!create && hadEnrollmentClosesAt)
        'enrollmentClosesAt': null,
      'mode': mode,
      if (!create) 'status': cancelled ? 'CANCELLED' : 'OPEN',
      'classDays': pickedDays,
      'classStartTime': classStartTime,
      'classEndTime': classEndTime,
      'timezone': timezone,
      if (location.trim().isNotEmpty) 'location': location.trim(),
      if (instituteCourse) ...{'trainerIds': trainerIds, 'enrolmentSpecialistId': enrolmentSpecialistId},
      if (maxSeats != null) 'maxSeats': maxSeats else if (!create && hadMaxSeats) 'maxSeats': null,
      if (priceAmount != null) 'priceAmount': priceAmount,
      'discountPercent': discountPercent,
      'discountEndsOn': discountPercent > 0 ? discountEndsOn : null,
    };
  }
}

// --- words --------------------------------------------------------------------------------------------------------

/// Batch statuses still going ahead (`ACTIVE_BATCH_STATUSES`).
const activeBatchStatuses = ['SCHEDULED', 'OPEN', 'RUNNING'];

/// The course status chip's words, as the console shows them: Live for a published course, "With ICR for review"
/// while it waits, else `LEARNING_COURSE_STATUS_LABELS`.
String courseStatusLabel(String status) => switch (status) {
  'PUBLISHED' => 'Live',
  'PENDING_REVIEW' => 'With ICR for review',
  'DRAFT' => 'Draft',
  'REJECTED' => 'Changes requested',
  'ARCHIVED' => 'Archived',
  _ => status,
};

/// `LEARNING_BATCH_STATUS_LABELS`.
String batchStatusLabel(String status) => switch (status) {
  'SCHEDULED' => 'Scheduled',
  'OPEN' => 'Open for enrolment',
  'RUNNING' => 'Running',
  'COMPLETED' => 'Completed',
  'CANCELLED' => 'Cancelled',
  _ => status,
};

/// `LEARNING_DELIVERY_MODE_LABELS`.
String deliveryModeLabel(String mode) => switch (mode) {
  'VIRTUAL' => 'Virtual (live online)',
  'ONLINE' => 'Online (self-paced)',
  'IN_PERSON' => 'In person',
  'HYBRID' => 'Hybrid',
  _ => mode,
};

/// The modes a new batch may be scheduled in: taught in a room, or taught live online. An older batch keeps its
/// retired mode in the list, marked.
const schedulableModes = ['VIRTUAL', 'IN_PERSON'];

/// `LEARNING_ENROLLMENT_STATUS_LABELS`, in the website's filter order.
const enrolmentStatuses = ['PENDING', 'CONFIRMED', 'WAITLISTED', 'CANCELLED', 'COMPLETED'];

String enrolmentStatusLabel(String status) => switch (status) {
  'PENDING' => 'Pending',
  'CONFIRMED' => 'Confirmed',
  'WAITLISTED' => 'Waitlisted',
  'CANCELLED' => 'Cancelled',
  'COMPLETED' => 'Completed',
  _ => status,
};

/// A trainer's answer to being named on a batch.
String trainerAnswerLabel(String status) => switch (status) {
  'ACCEPTED' => 'Accepted',
  'DECLINED' => 'Declined',
  _ => 'Waiting for their answer',
};

/// `BATCH_WEEKDAY_SHORT`.
const weekdayShort = <int, String>{0: 'Sun', 1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat'};
