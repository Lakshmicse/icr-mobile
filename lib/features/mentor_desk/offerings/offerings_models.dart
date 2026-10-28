/// What the Offerings panel draws, in the shapes the API answers with:
/// `GET /mentor-services/mine`, `GET /mentor-plans/mine`,
/// `GET /mentorship/group-sessions?mine=true` and a session's detail (with its roster).
library;

import '../../mentorship_my/mentoring_models.dart' show asInt, asMaps, asStrings, parseDate;

/// `MentorServiceType`.
enum ServiceKind {
  oneOnOne('ONE_ON_ONE', '1:1 session'),
  resource('RESOURCE', 'Resource'),
  groupSeat('GROUP_SESSION', 'Group seat'),
  query('QUERY', 'Written consultation');

  const ServiceKind(this.api, this.label);
  final String api;
  final String label;

  static ServiceKind fromApi(String? v) => values.firstWhere((k) => k.api == v, orElse: () => oneOnOne);

  /// The API refuses to list or switch back on a retired type (`RETIRED_MENTOR_SERVICE_TYPES`).
  bool get retired => this == query;
}

/// The seller gates, as the API reports them (`MyMentorServicesDto`), word for word.
class StorefrontGates {
  const StorefrontGates({
    required this.optedIn,
    required this.termsCurrentVersion,
    required this.suspended,
    required this.live,
    this.termsAcceptedVersion,
    this.blockedReason,
  });

  final bool optedIn;
  final String? termsAcceptedVersion;
  final String termsCurrentVersion;
  final bool suspended;
  final bool live;

  /// The API's own sentence for what is missing: "Accept the seller terms to open your storefront."
  final String? blockedReason;

  bool get termsCurrent => termsAcceptedVersion == termsCurrentVersion;

  /// The Accept button shows when the API says the seller terms are the one thing missing (its gates check
  /// suspension and approval first, so this sentence means both are fine).
  bool get termsAreTheBlocker => !live && blockedReason == _acceptTerms;

  static const _acceptTerms = 'Accept the seller terms to open your storefront.';
}

/// One service a mentor lists (`MentorServiceDto`).
class OfferedService {
  const OfferedService({
    required this.id,
    required this.kind,
    required this.title,
    required this.pricePaisa,
    required this.active,
    this.blurb,
    this.coverUrl,
    this.durationMin,
    this.seats,
    this.compareAtPaisa,
    this.slaHours,
    this.fileName,
    this.fileSize,
    this.sortOrder = 0,
    this.salesCount = 0,
    this.rating = 0,
    this.ratingCount = 0,
    this.isBestSeller = false,
  });

  factory OfferedService.fromJson(Map<String, dynamic> j) => OfferedService(
    id: j['id'] as String,
    kind: ServiceKind.fromApi(j['type'] as String?),
    title: j['title'] as String? ?? '',
    pricePaisa: asInt(j['pricePaisa']),
    active: j['active'] == true,
    blurb: _text(j['blurb']),
    coverUrl: _text(j['coverUrl']),
    durationMin: (j['durationMin'] as num?)?.toInt(),
    seats: (j['seats'] as num?)?.toInt(),
    compareAtPaisa: (j['compareAtPaisa'] as num?)?.toInt(),
    slaHours: (j['slaHours'] as num?)?.toInt(),
    fileName: _text(j['fileName']),
    fileSize: (j['fileSize'] as num?)?.toInt(),
    sortOrder: asInt(j['sortOrder']),
    salesCount: asInt(j['salesCount']),
    rating: (j['rating'] as num?)?.toDouble() ?? 0,
    ratingCount: asInt(j['ratingCount']),
    isBestSeller: j['isBestSeller'] == true,
  );

  final String id;
  final ServiceKind kind;
  final String title;
  final int pricePaisa;
  final bool active;
  final String? blurb;
  final String? coverUrl;
  final int? durationMin;
  final int? seats;
  final int? compareAtPaisa;
  final int? slaHours;
  final String? fileName;
  final int? fileSize;
  final int sortOrder;
  final int salesCount;
  final double rating;
  final int ratingCount;
  final bool isBestSeller;

  bool get free => pricePaisa == 0;

  /// Why it cannot be live right now, in the API's words (null when nothing stops it).
  String? get blocker {
    if (kind.retired) return 'Written consultations are no longer sold.';
    if (kind == ServiceKind.resource && fileName == null) return 'Upload the file before publishing a resource.';
    return null;
  }

  /// The body of `PATCH /mentor-services/mine/:id`, which takes the whole shape: this row with [patch] laid over it.
  Map<String, Object?> body({bool? active}) => {
    'type': kind.api,
    'title': title,
    'blurb': ?blurb,
    'pricePaisa': pricePaisa,
    'compareAtPaisa': compareAtPaisa,
    'durationMin': ?durationMin,
    'seats': ?seats,
    'slaHours': ?slaHours,
    'active': active ?? this.active,
  };
}

/// One syllabus step of a programme (`MentorPlanDto.modules`).
class PlanStepInfo {
  const PlanStepInfo({required this.position, required this.title, this.outline, this.durationMin});

  final int position;
  final String title;
  final String? outline;
  final int? durationMin;
}

/// An ongoing plan or a programme a mentor lists (`MentorPlanDto`).
class OfferedPlan {
  const OfferedPlan({
    required this.id,
    required this.title,
    required this.programme,
    required this.pricePaisa,
    required this.active,
    this.blurb,
    this.coverUrl,
    this.compareAtPaisa,
    this.billingPeriodMonths = 1,
    this.sessionsPerMonth = 0,
    this.sessionDurationMin,
    this.totalSessions,
    this.accessMonths,
    this.inclusions = const [],
    this.steps = const [],
    this.subscribersCount = 0,
    this.sortOrder = 0,
  });

  factory OfferedPlan.fromJson(Map<String, dynamic> j) => OfferedPlan(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    programme: j['kind'] == 'CURRICULUM',
    pricePaisa: asInt(j['pricePaisa']),
    active: j['active'] == true,
    blurb: _text(j['blurb']),
    coverUrl: _text(j['coverUrl']),
    compareAtPaisa: (j['compareAtPaisa'] as num?)?.toInt(),
    billingPeriodMonths: asInt(j['billingPeriodMonths'], 1),
    sessionsPerMonth: asInt(j['sessionsPerMonth']),
    sessionDurationMin: (j['sessionDurationMin'] as num?)?.toInt(),
    totalSessions: (j['totalSessions'] as num?)?.toInt(),
    accessMonths: (j['accessMonths'] as num?)?.toInt(),
    inclusions: asStrings(j['inclusions']),
    steps: [
      for (final m in asMaps(j['modules']))
        PlanStepInfo(
          position: asInt(m['position']),
          title: m['title'] as String? ?? '',
          outline: _text(m['outline']),
          durationMin: (m['durationMin'] as num?)?.toInt(),
        ),
    ],
    subscribersCount: asInt(j['subscribersCount']),
    sortOrder: asInt(j['sortOrder']),
  );

  final String id;
  final String title;
  final bool programme;
  final int pricePaisa;
  final bool active;
  final String? blurb;
  final String? coverUrl;
  final int? compareAtPaisa;
  final int billingPeriodMonths;
  final int sessionsPerMonth;
  final int? sessionDurationMin;
  final int? totalSessions;
  final int? accessMonths;
  final List<String> inclusions;
  final List<PlanStepInfo> steps;
  final int subscribersCount;
  final int sortOrder;

  bool get free => pricePaisa == 0;
}

/// One day of a group session (`GroupSessionOccurrenceDto`).
class SessionDay {
  const SessionDay({
    required this.id,
    required this.seq,
    required this.at,
    required this.durationMin,
    required this.status,
    this.title,
  });

  final String id;
  final int seq;
  final DateTime at;
  final int durationMin;

  /// SCHEDULED, COMPLETED or CANCELLED.
  final String status;
  final String? title;

  bool get scheduled => status == 'SCHEDULED';
}

/// Someone on a group session's roster (the host sees the question too).
class RosterPerson {
  const RosterPerson({required this.id, required this.userId, required this.name, required this.status, this.question});

  final String id;
  final String userId;
  final String name;

  /// REGISTERED, WAITLISTED, ATTENDED, NO_SHOW, CANCELLED.
  final String status;
  final String? question;

  bool get holdsSeat => status == 'REGISTERED' || status == 'ATTENDED';

  String get statusLabel => switch (status) {
    'REGISTERED' => 'Registered',
    'WAITLISTED' => 'Waitlisted',
    'ATTENDED' => 'Attended',
    'NO_SHOW' => 'No-show',
    'CANCELLED' => 'Withdrew',
    _ => status,
  };
}

/// A group session the caller hosts (`GroupSessionCardDto` / `GroupSessionDetailDto`).
class HostedSession {
  const HostedSession({
    required this.id,
    required this.title,
    required this.status,
    required this.mode,
    required this.at,
    required this.durationMin,
    this.summary,
    this.days = const [],
    this.capacity,
    this.seatsTaken = 0,
    this.seatsLeft,
    this.waitlistCount = 0,
    this.pricePaisa,
    this.location,
    this.locationLat,
    this.locationLng,
    this.meetingLink,
    this.agendaHtml,
    this.coverUrl,
    this.timezone,
    this.focusAreas = const [],
    this.competencies = const [],
    this.cancelReason,
    this.roster,
  });

  factory HostedSession.fromJson(Map<String, dynamic> j) {
    final attendees = j['attendees'];
    return HostedSession(
      id: j['id'] as String,
      title: j['title'] as String? ?? '',
      status: j['status'] as String? ?? 'DRAFT',
      mode: j['mode'] as String? ?? 'VIDEO',
      at: parseDate(j['scheduledAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      durationMin: asInt(j['durationMin'], 60),
      summary: _text(j['summary']),
      days: [
        for (final o in asMaps(j['occurrences']))
          SessionDay(
            id: o['id'] as String? ?? '',
            seq: asInt(o['seq']),
            at: parseDate(o['scheduledAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
            durationMin: asInt(o['durationMin'], 60),
            status: o['status'] as String? ?? 'SCHEDULED',
            title: _text(o['title']),
          ),
      ],
      capacity: (j['capacity'] as num?)?.toInt(),
      seatsTaken: asInt(j['seatsTaken']),
      seatsLeft: (j['seatsLeft'] as num?)?.toInt(),
      waitlistCount: asInt(j['waitlistCount']),
      pricePaisa: (j['pricePaisa'] as num?)?.toInt(),
      location: _text(j['location']),
      locationLat: (j['locationLat'] as num?)?.toDouble(),
      locationLng: (j['locationLng'] as num?)?.toDouble(),
      meetingLink: _text(j['meetingLink']),
      agendaHtml: _text(j['agendaHtml']),
      coverUrl: _text(j['coverUrl']),
      timezone: _text(j['timezone']),
      focusAreas: asStrings(j['focusAreas']),
      competencies: asStrings(j['competencies']),
      cancelReason: _text(j['cancelReason']),
      roster: attendees is List
          ? [
              for (final a in asMaps(attendees))
                RosterPerson(
                  id: a['id'] as String? ?? '',
                  userId: (a['user'] as Map?)?['id'] as String? ?? '',
                  name: switch (a['user']) {
                    final Map<String, dynamic> u => '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim(),
                    _ => 'An ICR member',
                  },
                  status: a['status'] as String? ?? 'REGISTERED',
                  question: _text(a['question']),
                ),
            ]
          : null,
    );
  }

  final String id;
  final String title;

  /// DRAFT, SCHEDULED, COMPLETED or CANCELLED (`MentorshipGroupSessionStatus`).
  final String status;
  final String mode;
  final DateTime at;
  final int durationMin;
  final String? summary;
  final List<SessionDay> days;
  final int? capacity;
  final int seatsTaken;
  final int? seatsLeft;
  final int waitlistCount;
  final int? pricePaisa;
  final String? location;
  final double? locationLat;
  final double? locationLng;
  final String? meetingLink;
  final String? agendaHtml;
  final String? coverUrl;
  final String? timezone;
  final List<String> focusAreas;
  final List<String> competencies;
  final String? cancelReason;

  /// The roster, only on a detail read.
  final List<RosterPerson>? roster;

  bool get draft => status == 'DRAFT';
  bool get scheduled => status == 'SCHEDULED';
  bool get completed => status == 'COMPLETED';
  bool get cancelled => status == 'CANCELLED';
  bool get closed => completed || cancelled;
  bool get paid => pricePaisa != null;
  bool get inPerson => mode == 'IN_PERSON';

  /// The days still ahead of the series (those not closed or cancelled).
  List<SessionDay> get openDays => [
    for (final d in days)
      if (d.scheduled) d,
  ];

  /// A day has started and the series is not closed: attendance can be recorded.
  bool startedBy(DateTime now) => scheduled && openDays.any((d) => !d.at.isAfter(now));

  String get statusLabel => switch (status) {
    'DRAFT' => 'Draft',
    'SCHEDULED' => 'Open for registration',
    'COMPLETED' => 'Held',
    'CANCELLED' => 'Cancelled',
    _ => status,
  };
}

String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
