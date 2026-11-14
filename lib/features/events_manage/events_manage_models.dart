/// What the staff Events console draws: the rows of `GET /events/admin`, one event's programme (guest list, talk
/// proposals, sponsorship packages and requests), its tickets, and the companies asking to host events. The shapes
/// are the website's (`frontend/src/features/association/api.ts`), read once here so no screen touches JSON.
library;

import '../events/event_models.dart' show EventKind;

String _s(Object? v) => v is String ? v : (v == null ? '' : '$v');
String? _sn(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
int _i(Object? v) => v is num ? v.round() : (int.tryParse('$v') ?? 0);
int? _in(Object? v) => v == null ? null : (v is num ? v.round() : int.tryParse('$v'));
DateTime? _d(Object? v) => v is String && v.isNotEmpty ? DateTime.tryParse(v)?.toUtc() : null;
Map<String, dynamic> _m(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};

String _person(Map<String, dynamic> user) =>
    [_s(user['firstName']).trim(), _s(user['lastName']).trim()].where((p) => p.isNotEmpty).join(' ');

/// A chapter, a council or a company an event belongs to: its id and name.
class OrgRef {
  const OrgRef({required this.id, required this.name});

  final String id;
  final String name;

  static OrgRef? from(Object? json) {
    final m = _m(json);
    final id = _s(m['id']);
    return id.isEmpty ? null : OrgRef(id: id, name: _s(m['name']));
  }

  @override
  bool operator ==(Object other) => other is OrgRef && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// One row of the staff list (`AdminEventRow`): the public event plus whether it is listed, who is going and who
/// waits.
class ManagedEvent {
  const ManagedEvent({
    required this.id,
    required this.title,
    required this.kind,
    required this.startsAt,
    this.slug,
    this.description,
    this.location,
    this.coverUrl,
    this.capacity,
    this.pricePaisa = 0,
    this.endsAt,
    this.going = 0,
    this.waitlisted = 0,
    this.published = true,
    this.inviteOnly = false,
    this.callForSpeakersUntil,
    this.chapter,
    this.council,
    this.hostCompany,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? slug;

  /// `EventKind` as the API spells it (`CHAPTER_MEET`).
  final String kind;

  /// The description's stored HTML.
  final String? description;
  final String? location;
  final String? coverUrl;
  final int? capacity;
  final int pricePaisa;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int going;
  final int waitlisted;
  final bool published;
  final bool inviteOnly;
  final DateTime? callForSpeakersUntil;
  final OrgRef? chapter;
  final OrgRef? council;

  /// The partner company hosting it; null is an ICR event.
  final OrgRef? hostCompany;
  final DateTime? createdAt;

  bool get priced => pricePaisa > 0;
  String get kindLabel => EventKind.fromApi(kind).label;

  /// Who hosts it, as the list's second line names them.
  String? get host => hostCompany?.name ?? chapter?.name ?? council?.name;

  bool hasEnded(DateTime now) => (endsAt ?? startsAt).isBefore(now);
  bool hasStarted(DateTime now) => !startsAt.isAfter(now);

  /// [published] defaults to true for a row read from the public `GET /events/:slug`, which only finds listed events.
  factory ManagedEvent.fromJson(Map<String, dynamic> j) => ManagedEvent(
    id: _s(j['id']),
    title: _s(j['title']),
    slug: _sn(j['slug']),
    kind: _s(j['kind']).isEmpty ? 'CHAPTER_MEET' : _s(j['kind']),
    description: _sn(j['description']),
    location: _sn(j['location']),
    coverUrl: _sn(j['coverUrl']),
    capacity: _in(j['capacity']),
    pricePaisa: _in(j['priceAmount']) ?? 0,
    startsAt: _d(j['startsAt']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    endsAt: _d(j['endsAt']),
    going: _in(j['going']) ?? _i(j['attendeeCount']),
    waitlisted: _i(j['waitlisted']),
    published: j['published'] != false,
    inviteOnly: j['inviteOnly'] == true,
    callForSpeakersUntil: _d(j['callForSpeakersUntil']),
    chapter: OrgRef.from(j['chapter']),
    council: OrgRef.from(j['council']),
    hostCompany: OrgRef.from(j['hostCompany']),
    createdAt: _d(j['createdAt']),
  );
}

/// One page of a `{ data, meta }` list.
class Paged<T> {
  const Paged(this.rows, this.total);

  final List<T> rows;
  final int total;
}

/// What the staff list is asked for (`EventQueryDto`): the search box and the three filters.
class EventsQuery {
  const EventsQuery({this.search = '', this.when, this.kind, this.host, this.page = 1, this.limit = 20});

  final String search;

  /// `upcoming`, `past`, or null for every date.
  final String? when;

  /// An `EventKind` key, or null for every type.
  final String? kind;

  /// `icr`, `partner`, or null for every host.
  final String? host;
  final int page;
  final int limit;

  Map<String, Object?> toQuery() => {
    'page': page,
    'limit': limit,
    if (search.trim().isNotEmpty) 'search': search.trim(),
    'when': ?when,
    'kind': ?kind,
    'host': ?host,
  };
}

/// A member on an event's guest list.
class EventInvite {
  const EventInvite({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.source = 'MANUAL',
    this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final String email;

  /// `MANUAL`, or `TIER:GOLD` for a tier sweep.
  final String source;
  final DateTime? createdAt;

  /// "Invited individually" / "Gold tier invite".
  String get sourceLabel {
    if (source.startsWith('TIER:')) return '${tierLabel(source.substring(5))} tier invite';
    return 'Invited individually';
  }

  factory EventInvite.fromJson(Map<String, dynamic> j) {
    final user = _m(j['user']);
    return EventInvite(
      id: _s(j['id']),
      userId: _s(user['id']),
      name: _person(user),
      email: _s(user['email']),
      source: _s(j['source']).isEmpty ? 'MANUAL' : _s(j['source']),
      createdAt: _d(j['createdAt']),
    );
  }
}

/// A talk a member offered for an event.
class EventProposal {
  const EventProposal({
    required this.id,
    required this.title,
    required this.abstract,
    required this.status,
    required this.speaker,
    required this.email,
    this.bio,
    this.reviewNote,
  });

  final String id;
  final String title;
  final String abstract;
  final String? bio;

  /// `PENDING`, `ACCEPTED` or `DECLINED`.
  final String status;
  final String? reviewNote;
  final String speaker;
  final String email;

  bool get pending => status == 'PENDING';

  factory EventProposal.fromJson(Map<String, dynamic> j) {
    final user = _m(j['user']);
    return EventProposal(
      id: _s(j['id']),
      title: _s(j['title']),
      abstract: _s(j['abstract']),
      bio: _sn(j['bio']),
      status: _s(j['status']),
      reviewNote: _sn(j['reviewNote']),
      speaker: _person(user),
      email: _s(user['email']),
    );
  }
}

/// A sponsorship package an event offers.
class SponsorPackage {
  const SponsorPackage({
    required this.id,
    required this.name,
    required this.pricePaisa,
    this.benefits = const [],
    this.slots,
    this.taken = 0,
  });

  final String id;
  final String name;
  final int pricePaisa;
  final List<String> benefits;

  /// How many sponsors it takes; null for no cap.
  final int? slots;
  final int taken;

  factory SponsorPackage.fromJson(Map<String, dynamic> j) => SponsorPackage(
    id: _s(j['id']),
    name: _s(j['name']),
    pricePaisa: _i(j['priceAmount']),
    benefits: [for (final b in j['benefits'] is List ? j['benefits'] as List : const []) '$b'],
    slots: _in(j['slots']),
    taken: _i(j['taken']),
  );
}

/// A company asking for one of an event's packages.
class SponsorshipRequest {
  const SponsorshipRequest({
    required this.id,
    required this.status,
    required this.company,
    required this.package,
    required this.contact,
    required this.email,
    this.note,
    this.decisionNote,
  });

  final String id;

  /// `REQUESTED`, `CONFIRMED` or `DECLINED`.
  final String status;
  final String company;
  final String package;
  final String contact;
  final String email;
  final String? note;
  final String? decisionNote;

  bool get open => status == 'REQUESTED';

  factory SponsorshipRequest.fromJson(Map<String, dynamic> j) {
    final user = _m(j['user']);
    return SponsorshipRequest(
      id: _s(j['id']),
      status: _s(j['status']),
      company: _s(_m(j['company'])['name']),
      package: _s(_m(j['package'])['name']),
      contact: _person(user),
      email: _s(user['email']),
      note: _sn(j['note']),
      decisionNote: _sn(j['decisionNote']),
    );
  }
}

/// One event's programme as staff read it: the website's `useAdminEventProgramme`.
class EventProgramme {
  const EventProgramme({
    this.invites = const [],
    this.proposals = const [],
    this.sponsorships = const [],
    this.packages = const [],
  });

  final List<EventInvite> invites;
  final List<EventProposal> proposals;
  final List<SponsorshipRequest> sponsorships;
  final List<SponsorPackage> packages;

  int get toReview => proposals.where((p) => p.pending).length;
  int get toDecide => sponsorships.where((s) => s.open).length;
}

/// A ticket sold for an event.
class TicketRow {
  const TicketRow({
    required this.id,
    required this.status,
    required this.totalPaisa,
    required this.userId,
    required this.name,
    required this.firstName,
    required this.email,
    this.couponCode,
    this.refundRef,
    this.paidAt,
  });

  final String id;

  /// `PAID`, `CANCELLED` or `REFUNDED` (a ticket still at the gateway is never listed).
  final String status;
  final int totalPaisa;
  final String userId;
  final String name;
  final String firstName;
  final String email;
  final String? couponCode;
  final String? refundRef;
  final DateTime? paidAt;

  /// The website offers Refund on a paid ticket that cost something.
  bool get refundable => status == 'PAID' && totalPaisa > 0;

  factory TicketRow.fromJson(Map<String, dynamic> j) {
    final user = _m(j['user']);
    return TicketRow(
      id: _s(j['id']),
      status: _s(j['status']),
      totalPaisa: _i(j['totalPaisa']),
      userId: _s(user['id']),
      name: _person(user),
      firstName: _s(user['firstName']).trim(),
      email: _s(user['email']),
      couponCode: _sn(j['couponCode']),
      refundRef: _sn(j['refundRef']),
      paidAt: _d(j['paidAt']),
    );
  }
}

/// What `POST /events/tickets/:id/refund` answered: carried out, or waiting for a second approver (the approval
/// engine, above the finance limit).
sealed class RefundOutcome {
  const RefundOutcome();

  /// The website's `isApprovalPending(res)`: `{ approvalRequired: true, approval }` means nothing was recorded yet.
  factory RefundOutcome.fromJson(Object? data) {
    final m = _m(data);
    if (m['approvalRequired'] == true) {
      final approval = _m(m['approval']);
      return RefundPending(approvalId: _s(approval['id']), amountPaisa: _i(approval['amountPaisa']));
    }
    return RefundDone(refundRef: _sn(m['refundRef']));
  }
}

class RefundDone extends RefundOutcome {
  const RefundDone({this.refundRef});

  final String? refundRef;
}

class RefundPending extends RefundOutcome {
  const RefundPending({required this.approvalId, required this.amountPaisa});

  final String approvalId;
  final int amountPaisa;
}

/// `POST /events/:id/invites`: how many were newly asked, and the addresses that are not members.
class InviteResult {
  const InviteResult({required this.invited, this.unknown = const []});

  final int invited;
  final List<String> unknown;

  factory InviteResult.fromJson(Map<String, dynamic> j) => InviteResult(
    invited: _i(j['invited']),
    unknown: [for (final e in j['unknown'] is List ? j['unknown'] as List : const []) '$e'],
  );
}

/// `POST /events/:id/invites/by-tier`: new invites, out of the members the tier reaches.
class TierInviteResult {
  const TierInviteResult({required this.invited, required this.considered});

  final int invited;
  final int considered;

  factory TierInviteResult.fromJson(Map<String, dynamic> j) =>
      TierInviteResult(invited: _i(j['invited']), considered: _i(j['considered']));
}

/// `POST /events/:id/attendance`: how many of the named members held a place and are now marked present, and the
/// CPD hours each was credited.
class AttendanceResult {
  const AttendanceResult({required this.marked, this.hoursEach});

  final int marked;
  final double? hoursEach;

  factory AttendanceResult.fromJson(Map<String, dynamic> j) => AttendanceResult(
    marked: _i(j['marked']),
    hoursEach: j['hoursEach'] is num ? (j['hoursEach'] as num).toDouble() : null,
  );
}

/// A company's request to host events on ICR (`EventHostApplicationDto`).
class HostApplication {
  const HostApplication({
    required this.id,
    required this.status,
    required this.company,
    required this.about,
    required this.contactName,
    required this.contactEmail,
    required this.appliedBy,
    required this.createdAt,
    this.eventKinds = const [],
    this.frequency,
    this.website,
    this.contactPhone,
    this.reviewNote,
    this.reviewedAt,
    this.hostedEventCount,
  });

  final String id;

  /// `PENDING`, `APPROVED`, `REJECTED` or `REVOKED`.
  final String status;
  final String company;
  final String about;
  final List<String> eventKinds;
  final String? frequency;
  final String? website;
  final String contactName;
  final String contactEmail;
  final String? contactPhone;
  final String appliedBy;
  final DateTime createdAt;
  final String? reviewNote;
  final DateTime? reviewedAt;
  final int? hostedEventCount;

  /// "Conference, Webinar" — or null when the company named none.
  String? get kindsLabel => eventKinds.isEmpty ? null : eventKinds.map((k) => EventKind.fromApi(k).label).join(', ');

  factory HostApplication.fromJson(Map<String, dynamic> j) => HostApplication(
    id: _s(j['id']),
    status: _s(j['status']),
    company: _s(_m(j['company'])['name']),
    about: _s(j['about']),
    eventKinds: [for (final k in j['eventKinds'] is List ? j['eventKinds'] as List : const []) '$k'],
    frequency: _sn(j['frequency']),
    website: _sn(j['website']),
    contactName: _s(j['contactName']),
    contactEmail: _s(j['contactEmail']),
    contactPhone: _sn(j['contactPhone']),
    appliedBy: _s(_m(j['appliedBy'])['name']),
    createdAt: _d(j['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    reviewNote: _sn(j['reviewNote']),
    reviewedAt: _d(j['reviewedAt']),
    hostedEventCount: _in(j['hostedEventCount']),
  );
}

// --- the words the shared package gives each status ----------------------------------------------------------------

/// `EVENT_PROPOSAL_STATUS_LABELS`.
String proposalStatusLabel(String status) => switch (status) {
  'PENDING' => 'Under Review',
  'ACCEPTED' => 'Accepted',
  'DECLINED' => 'Declined',
  _ => status,
};

/// `EVENT_SPONSORSHIP_STATUS_LABELS`.
String sponsorshipStatusLabel(String status) => switch (status) {
  'REQUESTED' => 'Requested',
  'CONFIRMED' => 'Confirmed',
  'DECLINED' => 'Declined',
  _ => status,
};

/// `EVENT_TICKET_STATUS_LABELS`.
String ticketStatusLabel(String status) => switch (status) {
  'PENDING_PAYMENT' => 'Awaiting Payment',
  'PAID' => 'Paid',
  'CANCELLED' => 'Cancelled',
  'REFUNDED' => 'Refunded',
  _ => status,
};

/// The Event partners console's own words for a request's standing.
String hostStatusLabel(String status) => switch (status) {
  'PENDING' => 'Waiting',
  'APPROVED' => 'Approved',
  'REJECTED' => 'Rejected',
  'REVOKED' => 'Revoked',
  _ => status,
};

/// The tiers a sweep may start from (`MembershipTier` less FREE), lowest first.
const inviteTiers = ['SILVER', 'GOLD', 'ENTERPRISE'];

String tierLabel(String tier) => switch (tier) {
  'FREE' => 'Free',
  'SILVER' => 'Silver',
  'GOLD' => 'Gold',
  'ENTERPRISE' => 'Enterprise',
  _ => tier,
};
