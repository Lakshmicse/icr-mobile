/// What the mentoring screens draw once a member has found a mentor: their
/// pairings, requests, bookings, group seats, programmes, goals and
/// certificates. Filled from the API by `MentoringRepository`.
library;

import 'dart:typed_data';

import '../feed/feed_models.dart' show FeedPicture;
import 'mentoring_clock.dart';

export '../feed/feed_models.dart' show FeedPicture;

DateTime? parseDate(Object? v) => v is String ? DateTime.tryParse(v) : null;
int asInt(Object? v, [int fallback = 0]) => (v as num?)?.toInt() ?? fallback;
List<String> asStrings(Object? v) => (v as List? ?? const []).map((e) => e.toString()).toList();
List<Map<String, dynamic>> asMaps(Object? v) => (v as List? ?? const []).whereType<Map<String, dynamic>>().toList();

/// Somebody on the other side of a pairing, a request or a booking.
class Person {
  const Person({required this.id, required this.firstName, required this.lastName, this.photo, this.subline});

  final String id;
  final String firstName;
  final String lastName;
  final FeedPicture? photo;

  /// Their headline, role or company, whichever the API sent.
  final String? subline;

  String get name => '$firstName $lastName'.trim().isEmpty ? 'An ICR member' : '$firstName $lastName'.trim();

  String get initials {
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return '${parts.first[0]}${parts.length > 1 ? parts.last[0] : ''}'.toUpperCase();
  }
}

/// `MentorshipStatus`.
enum PairingStatus {
  active('Active'),
  paused('Paused'),
  completed('Completed'),
  endedEarly('Ended');

  const PairingStatus(this.label);
  final String label;

  static PairingStatus fromApi(String? v) => switch (v) {
    'PAUSED' => paused,
    'COMPLETED' => completed,
    'ENDED_EARLY' => endedEarly,
    _ => active,
  };

  bool get live => this == active || this == paused;
}

/// An accepted pairing (`MentorshipDto`), from either side.
class Pairing {
  const Pairing({
    required this.id,
    required this.status,
    required this.viewerIsMentor,
    required this.mentor,
    required this.mentorProfileId,
    required this.mentee,
    required this.startedAt,
    this.cadence,
    this.completedAt,
    this.endedReason,
    this.sessionsCount = 0,
    this.totalMinutes = 0,
    this.conversationId,
    this.counterpartPhone,
    this.careerStage,
  });

  final String id;
  final PairingStatus status;
  final bool viewerIsMentor;
  final Person mentor;
  final String mentorProfileId;
  final Person mentee;
  final DateTime startedAt;
  final String? cadence;
  final DateTime? completedAt;
  final String? endedReason;
  final int sessionsCount;
  final int totalMinutes;
  final String? conversationId;
  final String? counterpartPhone;
  final String? careerStage;

  /// The other person: the mentee for a mentor, the mentor for a mentee.
  Person get counterpart => viewerIsMentor ? mentee : mentor;

  Pairing copyWith({PairingStatus? status, String? endedReason, String? conversationId}) => Pairing(
    id: id,
    status: status ?? this.status,
    viewerIsMentor: viewerIsMentor,
    mentor: mentor,
    mentorProfileId: mentorProfileId,
    mentee: mentee,
    startedAt: startedAt,
    cadence: cadence,
    completedAt: completedAt,
    endedReason: endedReason ?? this.endedReason,
    sessionsCount: sessionsCount,
    totalMinutes: totalMinutes,
    conversationId: conversationId ?? this.conversationId,
    counterpartPhone: counterpartPhone,
    careerStage: careerStage,
  );
}

/// `MentorshipRequestStatus`.
enum RequestStatus {
  pending('Awaiting reply'),
  accepted('Accepted'),
  declined('Declined'),
  withdrawn('Withdrawn'),
  expired('Expired');

  const RequestStatus(this.label);
  final String label;

  static RequestStatus fromApi(String? v) => switch (v) {
    'ACCEPTED' => accepted,
    'DECLINED' => declined,
    'WITHDRAWN' => withdrawn,
    'EXPIRED' => expired,
    _ => pending,
  };
}

/// A free mentoring request (`MentorshipRequestDto`), sent or received.
class MentoringRequest {
  const MentoringRequest({
    required this.id,
    required this.status,
    required this.message,
    required this.createdAt,
    required this.mentor,
    required this.mentorProfileId,
    required this.mentee,
    this.focusAreas = const [],
    this.responseNote,
    this.expiresAt,
    this.matchScore,
    this.careerStage,
    this.signals = const [],
    this.respondedAt,
  });

  final String id;
  final RequestStatus status;
  final String message;
  final DateTime createdAt;
  final Person mentor;
  final String mentorProfileId;
  final Person mentee;
  final List<String> focusAreas;
  final String? responseNote;
  final DateTime? expiresAt;
  final int? matchScore;
  final String? careerStage;

  /// Why this request reached the mentor ("Same city", "Wants your domain"), a mentor's view only.
  final List<String> signals;
  final DateTime? respondedAt;
}

/// `MentorshipSessionStatus`.
enum SessionStatus {
  requested('Awaiting the mentor'),
  scheduled('Scheduled'),
  completed('Held'),
  cancelled('Cancelled'),
  noShow('No-show');

  const SessionStatus(this.label);
  final String label;

  static SessionStatus fromApi(String? v) => switch (v) {
    'REQUESTED' => requested,
    'COMPLETED' => completed,
    'CANCELLED' => cancelled,
    'NO_SHOW' => noShow,
    _ => scheduled,
  };

  bool get open => this == requested || this == scheduled;
}

/// One meeting in a pairing (`MentorshipSessionDto`).
class PairingSession {
  const PairingSession({
    required this.id,
    required this.mentorshipId,
    required this.scheduledAt,
    required this.durationMin,
    required this.mode,
    required this.status,
    this.agenda,
    this.meetingLink,
    this.cancelReason,
    this.createdById,
    this.notes,
    this.summary,
    this.recordingUrl,
    this.counterpart,
    this.viewerIsMentor,
  });

  final String id;
  final String mentorshipId;
  final DateTime scheduledAt;
  final int durationMin;
  final String mode;
  final SessionStatus status;
  final String? agenda;
  final String? meetingLink;
  final String? cancelReason;
  final String? createdById;
  final String? notes;
  final String? summary;
  final String? recordingUrl;
  final Person? counterpart;
  final bool? viewerIsMentor;

  bool upcoming(DateTime now) => status.open && scheduledAt.add(Duration(minutes: durationMin)).isAfter(now);
}

/// `MentorshipGoalStatus`.
enum GoalStatus {
  open('Open'),
  achieved('Achieved'),
  dropped('Dropped');

  const GoalStatus(this.label);
  final String label;

  static GoalStatus fromApi(String? v) => switch (v) {
    'ACHIEVED' => achieved,
    'DROPPED' => dropped,
    _ => open,
  };

  String get api => name.toUpperCase();
}

class PairingGoal {
  const PairingGoal({
    required this.id,
    required this.mentorshipId,
    required this.title,
    required this.status,
    this.progress = 0,
    this.detail,
    this.targetDate,
    this.createdByName,
    this.counterpartName,
  });

  final String id;
  final String mentorshipId;
  final String title;
  final GoalStatus status;
  final int progress;
  final String? detail;
  final DateTime? targetDate;
  final String? createdByName;

  /// On the cross-pairing list: who the goal is shared with.
  final String? counterpartName;
}

/// `MentorshipTaskStatus`.
enum TaskStatus {
  open('Open'),
  done('Done'),
  dropped('Dropped');

  const TaskStatus(this.label);
  final String label;

  static TaskStatus fromApi(String? v) => switch (v) {
    'DONE' => done,
    'DROPPED' => dropped,
    _ => open,
  };

  String get api => name.toUpperCase();
}

class PairingTask {
  const PairingTask({
    required this.id,
    required this.title,
    required this.status,
    this.detail,
    this.dueAt,
    this.isMine = false,
    this.overdue = false,
  });

  final String id;
  final String title;
  final TaskStatus status;
  final String? detail;
  final DateTime? dueAt;
  final bool isMine;
  final bool overdue;
}

/// The viewer's own rating of a finished pairing.
class PairingFeedback {
  const PairingFeedback({required this.rating, this.comment, this.wouldRecommend, this.createdAt});

  final int rating;
  final String? comment;
  final bool? wouldRecommend;
  final DateTime? createdAt;
}

/// `MentorshipConcernCategory`, worded as the website's report dialog.
enum ConcernCategory {
  conduct('CONDUCT', 'Conduct', 'Behaviour that broke the code of conduct.'),
  safety('SAFETY', 'Safety', 'Someone may be at risk. ICR treats it as urgent.'),
  unresponsive('UNRESPONSIVE', 'Not responding', 'The other person has gone quiet.'),
  boundary('BOUNDARY', 'Boundaries', 'Contact outside what you agreed, or asks that made you uneasy.'),
  other('OTHER', 'Something else', 'Anything else ICR should know.');

  const ConcernCategory(this.api, this.label, this.hint);
  final String api;
  final String label;
  final String hint;

  static ConcernCategory fromApi(String? v) => values.firstWhere((c) => c.api == v, orElse: () => other);
}

/// `ServicePurchaseStatus`.
enum PurchaseStatus {
  pendingPayment('PENDING_PAYMENT', 'Payment pending'),
  paid('PAID', 'Booked'),
  fulfilled('FULFILLED', 'Delivered'),
  expired('EXPIRED', 'Expired'),
  refundDue('REFUND_DUE', 'Refund due'),
  refunded('REFUNDED', 'Refunded'),
  cancelled('CANCELLED', 'Cancelled'),
  requested('REQUESTED', 'Requested'),
  accepted('ACCEPTED', 'Time proposed'),
  declined('DECLINED', 'Declined'),
  confirmed('CONFIRMED', 'Payment due');

  const PurchaseStatus(this.api, this.label);
  final String api;
  final String label;

  static PurchaseStatus fromApi(String? v) => values.firstWhere((s) => s.api == v, orElse: () => paid);

  /// Still needs someone's hands.
  bool get open => switch (this) {
    requested || accepted || pendingPayment || confirmed || paid => true,
    _ => false,
  };
}

/// `MentorServiceType`.
enum ServiceType {
  oneOnOne('ONE_ON_ONE', '1:1 session'),
  query('QUERY', 'Written consultation'),
  resource('RESOURCE', 'Resource'),
  groupSession('GROUP_SESSION', 'Group session');

  const ServiceType(this.api, this.label);
  final String api;
  final String label;

  static ServiceType fromApi(String? v) => values.firstWhere((s) => s.api == v, orElse: () => oneOnOne);
}

class PurchaseBooking {
  const PurchaseBooking({
    required this.id,
    required this.scheduledAt,
    required this.durationMin,
    required this.mode,
    required this.status,
    this.meetingLink,
    this.proposedAt,
    this.proposedBy,
    this.proposedNote,
    this.rescheduleCount = 0,
  });

  final String id;
  final DateTime scheduledAt;
  final int durationMin;
  final String mode;

  /// `SCHEDULED`, `COMPLETED`, `CANCELLED`, `NO_SHOW`.
  final String status;
  final String? meetingLink;

  /// A move one side proposed, waiting on the other.
  final DateTime? proposedAt;

  /// `BUYER` or `MENTOR`.
  final String? proposedBy;
  final String? proposedNote;
  final int rescheduleCount;

  bool get scheduled => status == 'SCHEDULED';
}

/// A 1:1 session asked for rather than booked.
class PurchaseRequest {
  const PurchaseRequest({
    required this.topic,
    this.preferredTimes,
    this.mode,
    this.durationMin,
    this.scheduledAt,
    this.declineReason,
    this.payBy,
    this.listPricePaisa = 0,
    this.timeDeclineCount = 0,
    this.timeDeclineNote,
  });

  final String topic;
  final String? preferredTimes;
  final String? mode;
  final int? durationMin;

  /// The time the mentor set once they accepted.
  final DateTime? scheduledAt;
  final String? declineReason;
  final DateTime? payBy;
  final int listPricePaisa;
  final int timeDeclineCount;
  final String? timeDeclineNote;
}

/// A purchase or a session request (`ServicePurchaseDto`), from either side.
class ServicePurchase {
  const ServicePurchase({
    required this.id,
    required this.type,
    required this.title,
    required this.pricePaisa,
    required this.status,
    required this.createdAt,
    this.serviceId,
    this.sellerSide = false,
    this.mentor,
    this.mentorProfileId,
    this.buyer,
    this.paidAt,
    this.cancelReason,
    this.booking,
    this.request,
    this.groupSessionId,
    this.groupSessionTitle,
    this.groupSessionAt,
    this.downloadUrl,
    this.fileName,
    this.hasReview = false,
    this.conversationId,
    this.netPaisa,
  });

  final String id;
  final ServiceType type;
  final String title;
  final int pricePaisa;
  final PurchaseStatus status;
  final DateTime createdAt;
  final String? serviceId;

  /// The caller sold it (the mentor's desk), rather than bought it.
  final bool sellerSide;
  final Person? mentor;
  final String? mentorProfileId;
  final Person? buyer;
  final DateTime? paidAt;
  final String? cancelReason;
  final PurchaseBooking? booking;
  final PurchaseRequest? request;
  final String? groupSessionId;
  final String? groupSessionTitle;
  final DateTime? groupSessionAt;
  final String? downloadUrl;
  final String? fileName;
  final bool hasReview;
  final String? conversationId;
  final int? netPaisa;

  /// A 1:1 session asked for and not booked yet.
  PurchaseRequest? get openRequest => type == ServiceType.oneOnOne && booking == null ? request : null;

  /// What the session costs before any discount: the request's list price, else the price.
  int get duePaisa => request?.listPricePaisa ?? pricePaisa;
}

/// A group session (`GroupSessionCardDto` / `GroupSessionDetailDto`).
class GroupSession {
  const GroupSession({
    required this.id,
    required this.title,
    required this.scheduledAt,
    required this.durationMin,
    required this.mode,
    required this.status,
    required this.host,
    this.summary,
    this.cover,
    this.occurrenceCount = 1,
    this.location,
    this.capacity,
    this.seatsTaken = 0,
    this.seatsLeft,
    this.waitlistCount = 0,
    this.myStatus,
    this.pricePaisa,
    this.programName,
    this.competencies = const [],
    this.agendaHtml,
    this.meetingLink,
    this.isHost = false,
    this.canRegister = false,
    this.seatForSale = false,
    this.blockedReason,
    this.conversationId,
    this.cancelReason,
    this.attendeeCount,
    this.occurrences = const [],
    this.attendees = const [],
    this.rosterScope,
    this.rosterHiddenCount = 0,
    this.timezone,
    this.myPurchaseId,
    this.myPurchaseStatus,
    this.myPurchaseHasReview = false,
  });

  final String id;
  final String title;
  final DateTime scheduledAt;
  final int durationMin;
  final String mode;

  /// `MentorshipGroupSessionStatus`: DRAFT, SCHEDULED, COMPLETED, CANCELLED.
  final String status;
  final Person host;
  final String? summary;
  final FeedPicture? cover;
  final int occurrenceCount;
  final String? location;
  final int? capacity;
  final int seatsTaken;
  final int? seatsLeft;
  final int waitlistCount;

  /// The viewer's registration: REGISTERED, WAITLISTED, ATTENDED, NO_SHOW, CANCELLED.
  final String? myStatus;
  final int? pricePaisa;
  final String? programName;
  final List<String> competencies;

  // Detail only.
  final String? agendaHtml;
  final String? meetingLink;
  final bool isHost;
  final bool canRegister;
  final bool seatForSale;
  final String? blockedReason;
  final String? conversationId;
  final String? cancelReason;
  final int? attendeeCount;

  /// Every day of the session (a series has several).
  final List<GroupOccurrence> occurrences;

  /// Who the caller may see on the roster: their peers, or nobody (`rosterScope` `peer` or `none`).
  final List<GroupAttendee> attendees;
  final String? rosterScope;
  final int rosterHiddenCount;
  final String? timezone;

  /// The seat the caller paid for (a paid session's seat is a purchase), and where it stands.
  final String? myPurchaseId;
  final String? myPurchaseStatus;
  final bool myPurchaseHasReview;

  bool get paid => (pricePaisa ?? 0) > 0;
  bool get full => capacity != null && (seatsLeft ?? 0) == 0;
  bool get upcoming => status == 'SCHEDULED';
  bool get holdsSeat => myStatus == 'REGISTERED' || myStatus == 'WAITLISTED' || myStatus == 'ATTENDED';
}

/// `MentorshipProgramRole`.
enum ProgrammeRole {
  mentee('MENTEE', 'Mentee'),
  mentor('MENTOR', 'Mentor');

  const ProgrammeRole(this.api, this.label);
  final String api;
  final String label;

  static ProgrammeRole fromApi(String? v) => v == 'MENTOR' ? mentor : mentee;
}

/// One application to a programme (`ProgramEnrolmentDto`).
class ProgrammeEnrolment {
  const ProgrammeEnrolment({
    required this.id,
    required this.programId,
    required this.role,
    required this.status,
    this.createdAt,
    this.decisionNote,
    this.programme,
  });

  final String id;
  final String programId;
  final ProgrammeRole role;

  /// APPLIED, ACCEPTED, MATCHED, WITHDRAWN, REJECTED.
  final String status;
  final DateTime? createdAt;
  final String? decisionNote;
  final Programme? programme;

  bool get live => status != 'WITHDRAWN' && status != 'REJECTED';

  String get statusLabel => switch (status) {
    'APPLIED' => 'Applied',
    'ACCEPTED' => 'Accepted',
    'MATCHED' => 'Matched',
    'WITHDRAWN' => 'Withdrawn',
    'REJECTED' => 'Not selected',
    _ => status,
  };
}

/// A cohort programme (`MentorshipProgramCardDto` / detail).
class Programme {
  const Programme({
    required this.id,
    required this.slug,
    required this.name,
    required this.status,
    required this.organiser,
    this.summary,
    this.cover,
    this.applicationsCloseAt,
    this.startsAt,
    this.endsAt,
    this.menteeCapacity,
    this.mentorCapacity,
    this.focusAreas = const [],
    this.competencies = const [],
    this.enrolmentCount = 0,
    this.detailHtml,
    this.menteesTaken,
    this.mentorsTaken,
    this.myEnrolments = const [],
  });

  final String id;
  final String slug;
  final String name;

  /// DRAFT, OPEN, RUNNING, COMPLETED, CANCELLED.
  final String status;
  final Person organiser;
  final String? summary;
  final FeedPicture? cover;
  final DateTime? applicationsCloseAt;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int? menteeCapacity;
  final int? mentorCapacity;
  final List<String> focusAreas;
  final List<String> competencies;
  final int enrolmentCount;
  final String? detailHtml;
  final int? menteesTaken;
  final int? mentorsTaken;
  final List<ProgrammeEnrolment> myEnrolments;

  bool get open => status == 'OPEN' && (applicationsCloseAt == null || applicationsCloseAt!.isAfter(mentoringNow()));

  String get statusLabel => switch (status) {
    'OPEN' => 'Applications open',
    'RUNNING' => 'Under way',
    'COMPLETED' => 'Completed',
    'CANCELLED' => 'Cancelled',
    _ => 'Draft',
  };

  /// The viewer's live application on [role], if any.
  ProgrammeEnrolment? enrolmentAs(ProgrammeRole role) =>
      myEnrolments.where((e) => e.role == role && e.live).firstOrNull;
}

/// A mentoring certificate (`MentorshipCertificateDto`).
class MentoringCertificate {
  const MentoringCertificate({
    required this.id,
    required this.certificateId,
    required this.title,
    required this.issuedAt,
    this.kind,
    this.counterpartName,
    this.programName,
    this.sessionsCount = 0,
    this.hours = 0,
    this.mentorshipId,
    this.goalsAchieved = 0,
  });

  final String? mentorshipId;
  final int goalsAchieved;
  final String id;
  final String certificateId;
  final String title;
  final DateTime issuedAt;
  final String? kind;
  final String? counterpartName;
  final String? programName;
  final int sessionsCount;
  final double hours;
}

/// A programme or ongoing plan term (`MentorPlanSubscriptionDto`), either side.
class PlanTerm {
  const PlanTerm({
    required this.id,
    required this.planId,
    required this.title,
    required this.status,
    required this.kind,
    required this.totalPaisa,
    required this.createdAt,
    this.pricePaisa = 0,
    this.discountPaisa = 0,
    this.taxPaisa = 0,
    this.counterpart,
    this.mentorshipId,
    this.sessionsAllowance = 0,
    this.sessionsUsed = 0,
    this.declineReason,
    this.billingPeriodMonths = 1,
    this.periodEnd,
    this.steps = const [],
    this.cancelAtPeriodEnd = false,
    this.cancelReason,
  });

  final String id;
  final String planId;
  final String title;

  /// PENDING_MENTOR, PENDING_PAYMENT, ACTIVE, COMPLETED, EXPIRED, DECLINED, CANCELLED, REFUNDED.
  final String status;

  /// CURRICULUM (a programme) or RECURRING (an ongoing plan).
  final String kind;
  final int totalPaisa;
  final DateTime createdAt;

  /// The quote the API worked out when it was asked for: the list price, what the member's plan took off,
  /// the tax, and the total to pay.
  final int pricePaisa;
  final int discountPaisa;
  final int taxPaisa;
  final Person? counterpart;
  final String? mentorshipId;
  final int sessionsAllowance;
  final int sessionsUsed;
  final String? declineReason;
  final int billingPeriodMonths;

  /// When the paid term ends (an ongoing plan: the next renewal is a new purchase).
  final DateTime? periodEnd;

  /// A programme's syllabus with its progress; empty for an ongoing plan.
  final List<PlanStep> steps;
  final bool cancelAtPeriodEnd;
  final String? cancelReason;

  bool get programme => kind == 'CURRICULUM';
  int get sessionsLeft => (sessionsAllowance - sessionsUsed).clamp(0, 1 << 20);

  String get statusLabel => switch (status) {
    'PENDING_MENTOR' => 'Awaiting the mentor',
    'PENDING_PAYMENT' => 'Accepted, payment due',
    'ACTIVE' => 'Active',
    'COMPLETED' => 'Completed',
    'EXPIRED' => 'Expired',
    'DECLINED' => 'Declined',
    'CANCELLED' => 'Cancelled',
    'REFUNDED' => 'Refunded',
    _ => status,
  };

  bool get open => status == 'PENDING_MENTOR' || status == 'PENDING_PAYMENT' || status == 'ACTIVE';
}

/// One step of a programme's syllabus, snapshotted with the buyer's progress.
class PlanStep {
  const PlanStep({
    required this.position,
    required this.title,
    this.id = '',
    this.outline,
    this.durationMin,
    this.done = false,
    this.booked = false,
    this.isNext = false,
  });

  final String id;
  final int position;
  final String title;
  final String? outline;
  final int? durationMin;

  /// Its session was held.
  final bool done;

  /// A session is booked against it.
  final bool booked;

  /// The lowest step with no session against it yet.
  final bool isNext;
}

/// A mentor the member saved (`GET /mentorship/mentors/saved`).
class SavedMentor {
  const SavedMentor({
    required this.mentorProfileId,
    required this.person,
    this.headline,
    this.rating = 0,
    this.ratingCount = 0,
    this.openSlots = 0,
    this.city,
  });

  final String mentorProfileId;
  final Person person;
  final String? headline;
  final double rating;
  final int ratingCount;
  final int openSlots;
  final String? city;
}

/// A concern the member raised, and where it got to (`MentorshipConcernDto`).
class MentoringConcern {
  const MentoringConcern({
    required this.id,
    required this.category,
    required this.detail,
    required this.status,
    required this.createdAt,
    this.urgent = false,
    this.outcomeNote,
    this.handledAt,
    this.mentorshipId,
    this.groupSessionId,
  });

  final String id;
  final ConcernCategory category;
  final String detail;
  final bool urgent;

  /// OPEN, REVIEWING, ACTIONED, DISMISSED.
  final String status;
  final String? outcomeNote;
  final DateTime createdAt;
  final DateTime? handledAt;
  final String? mentorshipId;
  final String? groupSessionId;

  String get statusLabel => switch (status) {
    'OPEN' => 'Received',
    'REVIEWING' => 'ICR is looking into it',
    'ACTIONED' => 'Acted on',
    'DISMISSED' => 'Closed, no action',
    _ => status,
  };

  bool get closed => status == 'ACTIONED' || status == 'DISMISSED';
}

/// What kind of thing a calendar row is.
enum CalendarKind { session, booking, group }

/// One entry of the member's calendar: a pairing's session, a paid call or a group session.
class CalendarItem {
  const CalendarItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.at,
    required this.durationMin,
    required this.status,
    this.mentorshipId,
    this.purchaseId,
    this.counterpartName,
    this.meetingLink,
    this.mode,
  });

  final CalendarKind kind;
  final String id;
  final String title;
  final DateTime at;
  final int durationMin;

  /// The source's own status word (SCHEDULED, REQUESTED, COMPLETED, CANCELLED ...).
  final String status;
  final String? mentorshipId;
  final String? purchaseId;
  final String? counterpartName;
  final String? meetingLink;
  final String? mode;

  bool get open => status == 'SCHEDULED' || status == 'REQUESTED' || status == 'CONFIRMED' || status == 'PAID';
}

/// What the member may do now, and the quota behind a disabled button (`GET /mentorship/mentees/me/access`).
class MentoringQuota {
  const MentoringQuota({
    this.pending = 0,
    this.pendingLimit,
    this.active = 0,
    this.activeLimit,
    this.canRequest = true,
    this.tier,
  });

  final int pending;
  final int? pendingLimit;
  final int active;
  final int? activeLimit;
  final bool canRequest;
  final String? tier;
}

/// `CareerStage`.
const careerStages = <String, String>{
  'STUDENT': 'Student',
  'GRADUATE': 'Graduate',
  'EARLY_CAREER': 'Early career',
  'MID_CAREER': 'Mid career',
  'SENIOR': 'Senior',
  'LEADERSHIP': 'Leadership',
};

/// `MentorshipCadence`.
const cadences = <String, String>{
  'WEEKLY': 'Weekly',
  'FORTNIGHTLY': 'Fortnightly',
  'MONTHLY': 'Monthly',
  'ADHOC': 'As needed',
};

/// `MentorshipMode`.
const meetingModes = <String, String>{
  'VIDEO': 'Video call',
  'PHONE': 'Phone',
  'IN_PERSON': 'In person',
  'CHAT': 'Chat',
};

/// What the member wants out of mentoring (`MenteeProfileDto`): mentors read
/// it before they answer, and a request needs it first.
class MenteeIntent {
  const MenteeIntent({
    required this.careerStage,
    this.focusAreas = const [],
    this.goalSummary,
    this.preferredModes = const [],
    this.cadence,
    this.timezone = 'Asia/Kolkata',
    this.discoverable = true,
  });

  final String careerStage;
  final List<String> focusAreas;
  final String? goalSummary;
  final List<String> preferredModes;
  final String? cadence;
  final String timezone;
  final bool discoverable;

  Map<String, dynamic> toJson() => {
    'careerStage': careerStage,
    'focusAreas': focusAreas,
    if (goalSummary != null) 'goalSummary': goalSummary,
    'preferredModes': preferredModes,
    if (cadence != null) 'cadence': cadence,
    'timezone': timezone,
    'discoverable': discoverable,
  };
}

/// Where the member stands in mentoring (`GET /mentorship/summary`).
class MentoringSummary {
  const MentoringSummary({
    this.isMentor = false,
    this.mentorStatus,
    this.pendingIncoming = 0,
    this.pendingOutgoing = 0,
    this.activeAsMentor = 0,
    this.activeAsMentee = 0,
    this.menteesHelped = 0,
  });

  final bool isMentor;
  final int activeAsMentor;
  final int activeAsMentee;
  final int menteesHelped;

  /// DRAFT, PENDING, APPROVED, PAUSED, REJECTED; null with no mentor profile.
  final String? mentorStatus;
  final int pendingIncoming;
  final int pendingOutgoing;

  bool get approvedMentor => mentorStatus == 'APPROVED' || mentorStatus == 'PAUSED';
}

/// A bookable start, from `GET /mentorship/mentors/:id/slots` or a request's
/// suggested times.
class Slot {
  const Slot(this.at, {this.preferred = false});

  final DateTime at;

  /// The mentee's own pick ranked it first.
  final bool preferred;
}

/// What a checkout or a payment answered: done here, or continued on the website.
class PaymentOutcome {
  const PaymentOutcome({required this.completed, this.sitePath, this.message, this.mentorshipId});

  /// The pairing a paid programme started, when the API says.
  final String? mentorshipId;

  /// The API completed it itself (₹0, a session credit, or a simulated gateway).
  final bool completed;

  /// Where the website continues it (a real PayU payment).
  final String? sitePath;
  final String? message;
}

/// A session credit the member's plan carries (`GET /mentor-services/member-discounts`).
class SessionCredits {
  const SessionCredits({
    required this.perPeriod,
    required this.remaining,
    required this.capPaisa,
    this.planName,
    this.resetsAt,
  });

  final int perPeriod;
  final int remaining;

  /// The most one credit pays toward a session.
  final int capPaisa;
  final String? planName;
  final DateTime? resetsAt;
}

/// What the member's plans take off mentor sessions and plans, and the credits
/// they hold. The API funds it and applies it again at checkout.
class MemberDiscounts {
  const MemberDiscounts({this.servicesBps = 0, this.servicesPlan, this.plansBps = 0, this.plansPlan, this.credits});

  final int servicesBps;
  final String? servicesPlan;
  final int plansBps;
  final String? plansPlan;
  final SessionCredits? credits;
}

/// What checkout will charge for a list price, worked out the way the website
/// and the API do: a session credit (1:1 sessions only) takes the place of the
/// member discount, never both.
class PriceQuote {
  const PriceQuote._({
    required this.listPaisa,
    required this.chargedPaisa,
    required this.creditPaisa,
    required this.bps,
    required this.canCredit,
    required this.useCredit,
    this.planName,
    this.credits,
  });

  final int listPaisa;
  final int chargedPaisa;

  /// How much of the price a session credit pays (0 when none is used).
  final int creditPaisa;

  /// The member discount applied, in basis points (0 when a credit is used).
  final int bps;
  final bool canCredit;
  final bool useCredit;
  final String? planName;
  final SessionCredits? credits;

  bool get free => listPaisa == 0;
  bool get discounted => bps > 0 || creditPaisa > 0;

  static int memberPrice(int listPaisa, int bps) => listPaisa - (listPaisa * bps / 10000).round();

  /// A 1:1 session: a credit is used unless [useCredit] says not.
  factory PriceQuote.session(int listPaisa, MemberDiscounts? d, {bool useCredit = true}) {
    final credits = d?.credits;
    final free = listPaisa == 0;
    final canCredit = !free && credits != null && credits.remaining > 0;
    final credit = canCredit && useCredit ? (listPaisa < credits.capPaisa ? listPaisa : credits.capPaisa) : 0;
    final bps = free || credit > 0 ? 0 : (d?.servicesBps ?? 0);
    return PriceQuote._(
      listPaisa: listPaisa,
      chargedPaisa: credit > 0 ? listPaisa - credit : memberPrice(listPaisa, bps),
      creditPaisa: credit,
      bps: bps,
      canCredit: canCredit,
      useCredit: useCredit,
      planName: bps > 0 ? d?.servicesPlan : credits?.planName,
      credits: credits,
    );
  }

  /// A resource or a group seat: the member discount, no credit.
  factory PriceQuote.service(int listPaisa, MemberDiscounts? d) {
    final bps = listPaisa == 0 ? 0 : (d?.servicesBps ?? 0);
    return PriceQuote._(
      listPaisa: listPaisa,
      chargedPaisa: memberPrice(listPaisa, bps),
      creditPaisa: 0,
      bps: bps,
      canCredit: false,
      useCredit: false,
      planName: bps > 0 ? d?.servicesPlan : null,
    );
  }

  /// A programme or an ongoing plan: the plans discount.
  factory PriceQuote.plan(int listPaisa, MemberDiscounts? d) {
    final bps = listPaisa == 0 ? 0 : (d?.plansBps ?? 0);
    return PriceQuote._(
      listPaisa: listPaisa,
      chargedPaisa: memberPrice(listPaisa, bps),
      creditPaisa: 0,
      bps: bps,
      canCredit: false,
      useCredit: false,
      planName: bps > 0 ? d?.plansPlan : null,
    );
  }
}

/// One entry of a pairing's timeline (`MentorshipEventDto`): what happened and,
/// for a note, what was written. A note kept private shows only to its author.
class TimelineEntry {
  const TimelineEntry({
    required this.id,
    required this.type,
    required this.createdAt,
    this.note,
    this.shared = true,
    this.actorName,
  });

  final String id;
  final String type;
  final DateTime createdAt;
  final String? note;
  final bool shared;
  final String? actorName;

  /// The website's wording for the event type (`MENTORSHIP_EVENT_LABELS`, the timeline's own words).
  String get label => timelineLabels[type] ?? type;
}

const timelineLabels = <String, String>{
  'REQUESTED': 'Request sent',
  'ACCEPTED': 'Request accepted',
  'DECLINED': 'Request declined',
  'WITHDRAWN': 'Request withdrawn',
  'STARTED': 'Mentorship started',
  'PAUSED': 'Paused',
  'RESUMED': 'Resumed',
  'COMPLETED': 'Completed',
  'ENDED_EARLY': 'Ended early',
  'NOTE_ADDED': 'Note',
  'GOAL_ADDED': 'Goal added',
  'GOAL_ACHIEVED': 'Goal achieved',
  'GOAL_PROGRESS': 'Goal progress',
  'SESSION_REQUESTED': 'Session requested',
  'SESSION_SCHEDULED': 'Session scheduled',
  'SESSION_COMPLETED': 'Session completed',
  'SESSION_RESCHEDULED': 'Session moved',
  'SESSION_CANCELLED': 'Session cancelled',
  'CERTIFICATE_ISSUED': 'Certificate issued',
};

/// `ResourceKind`, worded as the website words it.
const resourceKinds = <String, String>{
  'PRESENTATION': 'Presentation',
  'WHITEPAPER': 'Whitepaper',
  'RECORDING': 'Recording',
  'TEMPLATE': 'Template',
  'OTHER': 'Resource',
};

/// Something a pair shares inside a mentorship (`MentorshipResourceDto`): a link or an uploaded file.
class SharedResource {
  const SharedResource({
    required this.id,
    required this.title,
    required this.kind,
    required this.addedByName,
    required this.createdAt,
    this.note,
    this.url,
    this.fileName,
    this.fileSize,
    this.canRemove = false,
  });

  final String id;
  final String title;
  final String kind;
  final String addedByName;
  final DateTime createdAt;
  final String? note;

  /// An external link, or `/uploads/...` for a stored file.
  final String? url;
  final String? fileName;
  final int? fileSize;
  final bool canRemove;

  bool get isUpload => fileName != null || (url?.startsWith('/uploads/') ?? false);
  String get kindLabel => resourceKinds[kind] ?? 'Resource';
}

/// What a session's notes call for: the notes, the pair's own recording link,
/// and the summary the API wrote when asked.
class SessionRecord {
  const SessionRecord({this.notes, this.recordingUrl, this.summary, this.unavailable = false});

  final String? notes;
  final String? recordingUrl;
  final String? summary;

  /// The summary was asked for and the site has no model switched on.
  final bool unavailable;
}

/// One day of a group session (`GroupOccurrenceDto`).
class GroupOccurrence {
  const GroupOccurrence({
    required this.id,
    required this.seq,
    required this.scheduledAt,
    required this.durationMin,
    required this.status,
    this.title,
  });

  final String id;
  final int seq;
  final DateTime scheduledAt;
  final int durationMin;

  /// SCHEDULED, COMPLETED, CANCELLED.
  final String status;
  final String? title;
}

/// One person on a group session's roster.
class GroupAttendee {
  const GroupAttendee({required this.id, required this.person, required this.status});

  final String id;
  final Person person;

  /// REGISTERED, WAITLISTED, ATTENDED, NO_SHOW, CANCELLED.
  final String status;
}

/// A page of a list the API pages (`{ data, meta.hasNext }`).
class PageOf<T> {
  const PageOf(this.items, {this.hasNext = false, this.total = 0});

  final List<T> items;
  final bool hasNext;
  final int total;
}

/// The viewer's own rating of a group session.
class GroupFeedback {
  const GroupFeedback({required this.rating, this.comment, this.anonymous = false});

  final int rating;
  final String? comment;
  final bool anonymous;
}

/// A file the person chose to share: its bytes, its name and the type the API will store it as.
class PickedShare {
  const PickedShare({required this.bytes, required this.name, this.mimeType});

  final Uint8List bytes;
  final String name;
  final String? mimeType;
}
