import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import '../mentorship_my/loader.dart';
import '../mentorship_my/mentoring_clock.dart';
import '../mentorship_my/mentoring_models.dart';
import '../mentorship_my/my_mentoring_controller.dart';
import 'mentor_desk_models.dart';
import 'mentor_desk_repository.dart';

/// The desk's tabs, in the order the strip draws them.
enum DeskTab {
  overview('Overview'),
  requests('Requests'),
  mentees('Mentees'),
  calendar('Calendar'),
  work('Work'),
  offerings('Offerings'),
  hours('Hours'),
  earnings('Earnings'),
  reviews('Reviews'),
  settings('Settings');

  const DeskTab(this.label);
  final String label;

  static DeskTab? fromKey(String? key) {
    if (key == null) return null;
    for (final t in values) {
      if (t.name == key) return t;
    }
    return null;
  }
}

/// What the desk shows before any tab: still reading, no mentor profile, a
/// profile that is not live yet, or the desk itself.
enum DeskGate { loading, failed, noProfile, notLive, ready }

/// The mentor's desk: the dashboard, what is asked of them (free requests, session requests,
/// programme requests), their mentees, the calendar, paid work, hours, settings, earnings and reviews.
/// A load fills one tab the first time it opens ([ensureTab]) and again on pull-to-refresh.
/// An action answers the API's refusal as a sentence, or null when it went through, and reloads
/// what it changed.
class MentorDeskController extends ChangeNotifier {
  MentorDeskController(this.repository, {this.nowFn}) {
    mentoring = MyMentoringController(repository.mentoring)..addListener(_notify);
    dashboard = Loader(repository.dashboard, _notify);
    settings = Loader(repository.settings, _notify);
    roster = Loader(repository.roster, _notify);
    sold = Loader(repository.sold, _notify);
    soldAll = Loader(() => repository.sold(open: false), _notify);
    terms = Loader(repository.soldTerms, _notify);
    earnings = Loader(repository.earnings, _notify);
    feedback = Loader(() => repository.menteeFeedback(dashboard.data?.profile?.id ?? ''), _notify);
    serviceReviews = Loader(_loadServiceReviews, _notify);
  }

  final MentorDeskRepository repository;

  /// A seam for tests; the module's clock by default.
  final DateTime Function()? nowFn;

  /// The member-side controller the desk borrows for what it shares with "My mentoring": the free
  /// requests, the pairings, what is next and the calendar.
  late final MyMentoringController mentoring;

  late final Loader<DeskDashboard> dashboard;
  late final Loader<DeskSettings> settings;
  late final Loader<List<Pairing>> roster;
  late final Loader<List<SoldRow>> sold;
  late final Loader<List<SoldRow>> soldAll;
  late final Loader<List<PlanTerm>> terms;
  late final Loader<Earnings> earnings;
  late final Loader<List<MenteeFeedback>> feedback;
  late final Loader<List<ServiceReviewRow>> serviceReviews;

  bool _started = false;
  bool _disposed = false;

  DateTime get now => (nowFn ?? mentoringNow)();

  /// Reads the dashboard (which says whether there is a profile at all), then what the first tabs need.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await dashboard.load();
    if (gate == DeskGate.ready) await refreshCore();
  }

  /// What the overview and the Requests and Work tabs read.
  Future<void> refreshCore() =>
      Future.wait([dashboard.load(), mentoring.received.load(), mentoring.upcoming.load(), sold.load(), terms.load()]);

  Future<void> refresh() async {
    await dashboard.load();
    if (gate == DeskGate.ready) await refreshCore();
  }

  DeskGate get gate {
    if (!dashboard.loaded) return dashboard.error != null ? DeskGate.failed : DeskGate.loading;
    final d = dashboard.data!;
    if (!d.hasProfile) return DeskGate.noProfile;
    return d.usable ? DeskGate.ready : DeskGate.notLive;
  }

  DeskProfile? get profile => dashboard.data?.profile;

  Future<void> ensureTab(DeskTab tab) => switch (tab) {
    DeskTab.overview || DeskTab.requests || DeskTab.work || DeskTab.offerings => Future.value(),
    DeskTab.mentees => Future.wait([roster.ensure(), mentoring.pairings.ensure(), mentoring.upcoming.ensure()]),
    DeskTab.calendar => mentoring.calendar.ensure(),
    DeskTab.hours || DeskTab.settings => settings.ensure(),
    DeskTab.earnings => Future.wait([earnings.ensure(), soldAll.ensure(), terms.ensure()]),
    DeskTab.reviews => Future.wait([feedback.ensure(), serviceReviews.ensure()]),
  };

  Future<void> refreshTab(DeskTab tab) => switch (tab) {
    DeskTab.overview || DeskTab.requests || DeskTab.work => refresh(),
    DeskTab.offerings => dashboard.load(),
    DeskTab.mentees => Future.wait([roster.load(), mentoring.pairings.load(), mentoring.upcoming.load()]),
    DeskTab.calendar => mentoring.calendar.load(),
    DeskTab.hours || DeskTab.settings => settings.load(),
    DeskTab.earnings => Future.wait([earnings.load(), soldAll.load(), terms.load()]),
    DeskTab.reviews => Future.wait([feedback.load(), serviceReviews.load()]),
  };

  Future<List<ServiceReviewRow>> _loadServiceReviews() async {
    final services = await repository.serviceTitles();
    final lists = await Future.wait([for (final s in services) repository.serviceReviews(s.id, s.title)]);
    return [for (final l in lists) ...l]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // --- what is asked of the mentor ---------------------------------------------------------

  /// Free mentoring requests nobody has answered.
  List<MentoringRequest> get freeRequests => mentoring.pendingReceived;

  /// Single 1:1 sessions asked for, waiting on the mentor to accept and set a time.
  List<SoldRow> get sessionRequests => [
    for (final r in sold.data ?? const <SoldRow>[])
      if (r.sessionRequest) r,
  ];

  /// Times the mentor set that the mentee has not accepted or paid for.
  List<SoldRow> get heldTimes => [
    for (final r in sold.data ?? const <SoldRow>[])
      if (r.timeHeld) r,
  ];

  /// Programme and plan requests waiting on the mentor.
  List<PlanTerm> get programmeRequests => [
    for (final t in terms.data ?? const <PlanTerm>[])
      if (t.status == 'PENDING_MENTOR') t,
  ];

  /// Accepted programmes the buyer has not paid for yet.
  List<PlanTerm> get unpaidTerms => [
    for (final t in terms.data ?? const <PlanTerm>[])
      if (t.status == 'PENDING_PAYMENT') t,
  ];

  /// Programmes and plans that are running.
  List<PlanTerm> get activeTerms => [
    for (final t in terms.data ?? const <PlanTerm>[])
      if (t.status == 'ACTIVE') t,
  ];

  /// Everything on the Requests tab that waits on the mentor: the badge.
  int get requestCount => freeRequests.length + sessionRequests.length + programmeRequests.length;

  // --- paid work ---------------------------------------------------------------------------

  List<SoldRow> get _rows => sold.data ?? const <SoldRow>[];

  static DateTime _end(SoldRow r) =>
      r.purchase.booking!.scheduledAt.add(Duration(minutes: r.purchase.booking!.durationMin));

  /// Problems buyers reported that the mentor has not resolved.
  List<SoldRow> get issues => [
    for (final r in _rows)
      if (r.openIssue) r,
  ];

  /// Booked calls whose hour has gone by and nobody closed.
  List<SoldRow> get endedCalls => [
    for (final r in _rows)
      if (r.bookedCall && !_end(r).isAfter(now)) r,
  ]..sort((a, b) => _end(a).compareTo(_end(b)));

  /// Mentees who asked to move a booked call.
  List<SoldRow> get moveRequests => [
    for (final r in _rows)
      if (r.moveAskedByBuyer && _end(r).isAfter(now)) r,
  ];

  /// Booked calls still ahead (a move the mentee asked for is in [moveRequests], one the mentor asked for in [waiting]).
  List<SoldRow> get upcomingCalls => ([
    for (final r in _rows)
      if (r.bookedCall && _end(r).isAfter(now) && !r.moveAskedByBuyer && !r.moveAskedByMentor) r,
  ]..sort((a, b) => a.purchase.booking!.scheduledAt.compareTo(b.purchase.booking!.scheduledAt)));

  /// The mentor's own part is done: a move they proposed, a time they set, a payment due.
  List<SoldRow> get waiting => [
    for (final r in _rows)
      if (r.moveAskedByMentor || r.timeHeld || r.purchase.status == PurchaseStatus.confirmed) r,
  ];

  /// What needs the mentor's hands on the Work tab: the badge.
  int get workCount => issues.length + endedCalls.length + moveRequests.length;

  // --- actions -------------------------------------------------------------------------------

  Future<String?> _act(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  /// Accepts a session request and sets the time.
  Future<String?> acceptSession(SoldRow r, DateTime at) => _act(() async {
    await repository.acceptSessionRequest(r.id, at);
    await Future.wait([sold.load(), mentoring.calendar.loaded ? mentoring.calendar.load() : Future.value()]);
  });

  Future<String?> declineSession(SoldRow r, String reason) => _act(() async {
    await repository.declineSessionRequest(r.id, reason);
    await sold.load();
  });

  Future<String?> withdrawHeld(SoldRow r) => _act(() async {
    await repository.withdrawHeldTime(r.id);
    await sold.load();
  });

  Future<String?> decideTerm(PlanTerm t, {required bool accept, String? reason}) => _act(() async {
    await repository.decidePlanRequest(t.id, accept: accept, reason: reason);
    await terms.load();
  });

  Future<String?> completeCall(SoldRow r) => _act(() async {
    await repository.completeCall(r.id);
    await Future.wait([sold.load(), earnings.loaded ? earnings.load() : Future.value()]);
  });

  Future<String?> cancelCall(SoldRow r, String reason) => _act(() async {
    await repository.cancelCall(r.id, reason);
    await sold.load();
  });

  Future<String?> setCallLink(SoldRow r, String? link) => _act(() async {
    await repository.setCallLink(r.id, link);
    await sold.load();
  });

  Future<String?> proposeMove(SoldRow r, DateTime at, {String? note}) => _act(() async {
    await repository.proposeMove(r.id, at, note: note);
    await sold.load();
  });

  Future<String?> answerMove(SoldRow r, {required bool accept, String? reason}) => _act(() async {
    await repository.answerMove(r.id, accept: accept, reason: reason);
    await sold.load();
  });

  Future<String?> respondIssue(SoldRow r, String note) => _act(() async {
    await repository.respondIssue(r.id, note);
    await sold.load();
  });

  /// Lists or hides the profile in the directory. Optimistic: the switch moves at once and goes back on a refusal.
  Future<String?> setVisibility(bool discoverable) async {
    final before = dashboard.data;
    final profile = before?.profile;
    if (before != null && profile != null) {
      dashboard.data = DeskDashboard(
        hasProfile: before.hasProfile,
        profile: DeskProfile(
          id: profile.id,
          status: profile.status,
          headline: profile.headline,
          discoverable: discoverable,
          reviewNote: profile.reviewNote,
          rating: profile.rating,
          ratingCount: profile.ratingCount,
          menteesHelped: profile.menteesHelped,
        ),
        completenessScore: before.completenessScore,
        missing: before.missing,
        capacityTotal: before.capacityTotal,
        capacityActive: before.capacityActive,
        capacityOpen: before.capacityOpen,
        requestsPending: before.requestsPending,
        answeredThisMonth: before.answeredThisMonth,
        acceptedThisMonth: before.acceptedThisMonth,
        acceptRatePct: before.acceptRatePct,
        menteesActive: before.menteesActive,
        menteesCompleted: before.menteesCompleted,
        isListed: before.isListed,
        recentActivity: before.recentActivity,
      );
      _notify();
    }
    try {
      await repository.setVisibility(discoverable);
      await Future.wait([dashboard.load(), settings.loaded ? settings.load() : Future.value()]);
      return null;
    } catch (e) {
      dashboard.data = before;
      _notify();
      return ApiError.from(e).message;
    }
  }

  Future<String?> saveSettings(Map<String, dynamic> changes) => _act(() async {
    await repository.saveSettings(changes);
    await Future.wait([settings.load(), dashboard.load()]);
  });

  Future<String?> saveHours(List<WeeklyBlock> blocks) => _act(() async {
    await repository.saveHours(blocks);
    await settings.load();
  });

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    mentoring.removeListener(_notify);
    mentoring.dispose();
    super.dispose();
  }
}
