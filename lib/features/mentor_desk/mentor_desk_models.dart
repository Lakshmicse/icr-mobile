/// What the mentor's desk draws: the dashboard, the profile's settings, the
/// weekly hours, what was sold and what is owed, earnings and reviews.
/// Filled from the API by `MentorDeskRepository`.
library;

import '../mentorship_my/mentoring_models.dart';

/// `MentorProfileStatus`.
enum DeskStatus {
  draft('DRAFT', 'Draft'),
  pending('PENDING', 'In review'),
  approved('APPROVED', 'Approved'),
  paused('PAUSED', 'Paused'),
  rejected('REJECTED', 'Not approved');

  const DeskStatus(this.api, this.label);
  final String api;
  final String label;

  static DeskStatus? fromApi(String? v) {
    for (final s in values) {
      if (s.api == v) return s;
    }
    return null;
  }
}

/// The mentor profile as the dashboard summarises it.
class DeskProfile {
  const DeskProfile({
    required this.id,
    required this.status,
    this.headline = '',
    this.discoverable = true,
    this.reviewNote,
    this.rating = 0,
    this.ratingCount = 0,
    this.menteesHelped = 0,
  });

  final String id;
  final DeskStatus status;
  final String headline;
  final bool discoverable;

  /// What the reviewer wrote when they did not approve it.
  final String? reviewNote;
  final double rating;
  final int ratingCount;
  final int menteesHelped;
}

/// `GET /mentorship/mentors/me/dashboard`.
class DeskDashboard {
  const DeskDashboard({
    required this.hasProfile,
    this.profile,
    this.completenessScore = 0,
    this.missing = const [],
    this.capacityTotal = 0,
    this.capacityActive = 0,
    this.capacityOpen = 0,
    this.requestsPending = 0,
    this.answeredThisMonth = 0,
    this.acceptedThisMonth = 0,
    this.acceptRatePct = 0,
    this.menteesActive = 0,
    this.menteesCompleted = 0,
    this.isListed = false,
    this.recentActivity = const [],
  });

  final bool hasProfile;
  final DeskProfile? profile;
  final int completenessScore;
  final List<String> missing;
  final int capacityTotal;
  final int capacityActive;
  final int capacityOpen;
  final int requestsPending;
  final int answeredThisMonth;
  final int acceptedThisMonth;
  final int acceptRatePct;
  final int menteesActive;
  final int menteesCompleted;

  /// Approved, switched on and with room: found in the directory right now.
  final bool isListed;
  final List<TimelineEntry> recentActivity;

  /// The desk is for mentors whose profile ICR approved (or who paused it).
  bool get usable => hasProfile && (profile?.status == DeskStatus.approved || profile?.status == DeskStatus.paused);
}

/// One weekly window the mentor takes calls in, in their own timezone.
class WeeklyBlock {
  const WeeklyBlock({required this.weekday, required this.startMin, required this.endMin});

  /// 0 = Sunday ... 6 = Saturday.
  final int weekday;
  final int startMin;
  final int endMin;

  Map<String, dynamic> toJson() => {'weekday': weekday, 'startMin': startMin, 'endMin': endMin};

  @override
  bool operator ==(Object other) =>
      other is WeeklyBlock && other.weekday == weekday && other.startMin == startMin && other.endMin == endMin;

  @override
  int get hashCode => Object.hash(weekday, startMin, endMin);

  String get span => '${hm(startMin)} to ${hm(endMin)}';
}

const weekdayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

/// "18:00" from minutes after midnight.
String hm(int min) => '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';

/// What the mentor edits about themselves (`GET /mentorship/mentors/me`).
class DeskSettings {
  const DeskSettings({
    required this.id,
    required this.status,
    this.bioHtml = '',
    this.preferredModes = const [],
    this.cadence,
    this.capacity = 2,
    this.timezone = 'Asia/Kolkata',
    this.availabilityNote = '',
    this.meetingLink = '',
    this.discoverable = true,
    this.openSlots = 0,
    this.blocks = const [],
  });

  final String id;
  final DeskStatus? status;
  final String bioHtml;
  final List<String> preferredModes;
  final String? cadence;
  final int capacity;
  final String timezone;
  final String availabilityNote;
  final String meetingLink;
  final bool discoverable;
  final int openSlots;
  final List<WeeklyBlock> blocks;
}

/// A sold one-to-one call, session request, resource or seat, with the fields only the seller reads.
class SoldRow {
  const SoldRow({
    required this.purchase,
    this.timeDeclinedAt,
    this.issueReportedAt,
    this.issueNote,
    this.issueRespondedAt,
    this.issueResponseNote,
    this.issueResolvedAt,
  });

  final ServicePurchase purchase;

  /// The buyer sent the set time back, asking for another.
  final DateTime? timeDeclinedAt;
  final DateTime? issueReportedAt;
  final String? issueNote;
  final DateTime? issueRespondedAt;
  final String? issueResponseNote;
  final DateTime? issueResolvedAt;

  String get id => purchase.id;
  bool get openIssue => issueReportedAt != null && issueResolvedAt == null;

  /// A single 1:1 session asked for, waiting on the mentor to accept and set a time.
  bool get sessionRequest =>
      purchase.type == ServiceType.oneOnOne && purchase.request != null && purchase.status == PurchaseStatus.requested;

  /// A time the mentor set, waiting on the mentee (to accept it or to pay).
  bool get timeHeld =>
      purchase.type == ServiceType.oneOnOne &&
      purchase.booking == null &&
      purchase.request != null &&
      (purchase.status == PurchaseStatus.accepted || purchase.status == PurchaseStatus.pendingPayment);

  /// A call that is booked (and still ahead or just over).
  bool get bookedCall => purchase.type == ServiceType.oneOnOne && (purchase.booking?.scheduled ?? false);

  /// The mentee asked to move the booked call.
  bool get moveAskedByBuyer =>
      bookedCall && purchase.booking!.proposedBy == 'BUYER' && purchase.booking!.proposedAt != null;

  /// The mentor asked to move it and waits for the mentee.
  bool get moveAskedByMentor =>
      bookedCall && purchase.booking!.proposedBy == 'MENTOR' && purchase.booking!.proposedAt != null;
}

/// `GET /mentor-services/purchases/:id/suggested-times`: free times to offer, the mentee's quick picks ranked first.
class SuggestedTimes {
  const SuggestedTimes({this.timezone = 'Asia/Kolkata', this.hasWeeklyHours = false, this.suggestions = const []});

  final String timezone;
  final bool hasWeeklyHours;
  final List<Slot> suggestions;
}

/// One line of the earnings ledger.
class EarningEntry {
  const EarningEntry({
    required this.id,
    required this.kind,
    required this.amountPaisa,
    required this.createdAt,
    this.purchaseId,
    this.subscriptionId,
    this.settledAt,
    this.settlementRef,
  });

  final String id;
  final String kind;
  final int amountPaisa;
  final DateTime createdAt;
  final String? purchaseId;
  final String? subscriptionId;
  final DateTime? settledAt;
  final String? settlementRef;

  bool get settled => settledAt != null;
}

/// `GET /mentor-services/mine/earnings`: ICR pays out; the app only reads.
class Earnings {
  const Earnings({this.unsettledPaisa = 0, this.settledPaisa = 0, this.entries = const []});

  final int unsettledPaisa;
  final int settledPaisa;
  final List<EarningEntry> entries;
}

/// A rating a mentee left about a mentorship (anonymous: the API sends no author).
class MenteeFeedback {
  const MenteeFeedback({required this.id, required this.rating, required this.createdAt, this.comment});

  final String id;
  final int rating;
  final DateTime createdAt;
  final String? comment;
}

/// A review a buyer left about a service.
class ServiceReviewRow {
  const ServiceReviewRow({
    required this.id,
    required this.rating,
    required this.serviceTitle,
    required this.createdAt,
    this.comment,
    this.authorName,
  });

  final String id;
  final int rating;
  final String serviceTitle;
  final DateTime createdAt;
  final String? comment;
  final String? authorName;
}
