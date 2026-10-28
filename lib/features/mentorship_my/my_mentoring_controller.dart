import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'loader.dart';
import 'mentoring_models.dart';
import 'mentoring_repository.dart';
import 'purchases_controller.dart';
import 'mentoring_clock.dart';

/// The tabs of "My mentoring", in the order the website lists them.
enum MyTab {
  mentoring('Mentoring'),
  requests('Requests'),
  calendar('Calendar'),
  purchases('Purchases'),
  goals('Goals'),
  saved('Saved'),
  certificates('Certificates'),
  reports('Reports');

  const MyTab(this.label);
  final String label;

  /// The website's `?tab=` word for this tab (`active` is Mentoring).
  String get key => this == mentoring ? 'active' : name;

  static MyTab? fromKey(String? key) {
    if (key == null) return null;
    for (final t in values) {
      if (t.key == key || t.name == key) return t;
    }
    return null;
  }
}

/// What "My mentoring" holds: the member's pairings, requests, calendar, goals,
/// saved mentors, certificates and reports. The first screenful (summary,
/// pairings, requests, what is next) loads on [start]; each other tab loads the
/// first time it is opened ([ensureTab]) and again on pull-to-refresh.
/// An action answers the API's refusal as a sentence, or null when it went
/// through, and reloads what it changed.
class MyMentoringController extends ChangeNotifier {
  MyMentoringController(this.repository, {DateTime? now}) : _month = _firstOfMonth(now ?? mentoringNow()) {
    summary = Loader(repository.summary, _notify);
    pairings = Loader(repository.pairings, _notify);
    sent = Loader(repository.requestsSent, _notify);
    received = Loader(repository.requestsReceived, _notify);
    upcoming = Loader(repository.upcomingSessions, _notify);
    quota = Loader(repository.quota, _notify);
    calendar = Loader(() => repository.calendar(_month, _nextMonth(_month)), _notify);
    intent = Loader(repository.menteeIntent, _notify);
    goals = Loader(repository.goalsAcross, _notify);
    saved = Loader(repository.savedMentors, _notify);
    certificates = Loader(repository.certificates, _notify);
    concerns = Loader(repository.concerns, _notify);
    focusOptions = Loader(repository.focusOptions, _notify);
    book = PurchasesBook(repository, _notify);
  }

  final MentoringRepository repository;

  late final Loader<MentoringSummary> summary;
  late final Loader<List<Pairing>> pairings;
  late final Loader<List<MentoringRequest>> sent;
  late final Loader<List<MentoringRequest>> received;
  late final Loader<List<PairingSession>> upcoming;
  late final Loader<MentoringQuota> quota;
  late final Loader<List<CalendarItem>> calendar;
  late final Loader<MenteeIntent?> intent;
  late final Loader<List<PairingGoal>> goals;
  late final Loader<List<SavedMentor>> saved;
  late final Loader<List<MentoringCertificate>> certificates;
  late final Loader<List<MentoringConcern>> concerns;
  late final Loader<List<String>> focusOptions;

  /// What the member bought or asked for (the Purchases tab).
  late final PurchasesBook book;

  DateTime _month;
  bool _started = false;
  bool _disposed = false;

  bool get started => _started;

  /// The first day of the month the calendar shows.
  DateTime get month => _month;

  /// Loads the first screenful. Safe to call once; [refresh] reads it again.
  Future<void> start() {
    if (_started) return Future.value();
    _started = true;
    return refresh();
  }

  Future<void> refresh() =>
      Future.wait([summary.load(), pairings.load(), sent.load(), received.load(), upcoming.load(), quota.load()]);

  /// Loads what [tab] shows, the first time it is opened.
  Future<void> ensureTab(MyTab tab) => switch (tab) {
    MyTab.mentoring || MyTab.requests => Future.value(),
    MyTab.purchases => book.ensure(),
    MyTab.calendar => calendar.ensure(),
    MyTab.goals => Future.wait([intent.ensure(), goals.ensure(), focusOptions.ensure()]),
    MyTab.saved => saved.ensure(),
    MyTab.certificates => certificates.ensure(),
    MyTab.reports => concerns.ensure(),
  };

  /// Reads [tab] again (pull-to-refresh).
  Future<void> refreshTab(MyTab tab) => switch (tab) {
    MyTab.mentoring || MyTab.requests => refresh(),
    MyTab.purchases => book.reload(),
    MyTab.calendar => calendar.load(),
    MyTab.goals => Future.wait([intent.load(), goals.load()]),
    MyTab.saved => saved.load(),
    MyTab.certificates => certificates.load(),
    MyTab.reports => concerns.load(),
  };

  // --- derived ----------------------------------------------------------------

  bool get isMentor => summary.data?.isMentor ?? false;

  /// The website's `useMentoringSides`: a listed (or paused) mentor, or one with pairings or requests to answer.
  bool get actsAsMentor {
    final d = summary.data;
    if (d == null) return false;
    return d.approvedMentor || d.activeAsMentor > 0 || d.pendingIncoming > 0;
  }

  /// Everyone who is not only a mentor: a member with nothing yet gets the mentee view.
  bool get actsAsMentee {
    final d = summary.data;
    if (d == null) return true;
    return d.activeAsMentee > 0 || d.pendingOutgoing > 0 || !actsAsMentor;
  }

  /// Live pairings (active or paused), newest first.
  List<Pairing> get livePairings => [
    for (final p in pairings.data ?? const <Pairing>[])
      if (p.status.live) p,
  ];

  /// Finished or ended pairings.
  List<Pairing> get finishedPairings => [
    for (final p in pairings.data ?? const <Pairing>[])
      if (!p.status.live) p,
  ];

  /// The next open session in [mentorshipId], from "what is next".
  PairingSession? nextSessionOf(String mentorshipId) {
    final now = mentoringNow();
    final rows = [
      for (final s in upcoming.data ?? const <PairingSession>[])
        if (s.mentorshipId == mentorshipId && s.upcoming(now)) s,
    ]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return rows.firstOrNull;
  }

  /// Requests the caller sent that nobody answered yet.
  List<MentoringRequest> get pendingSent => [
    for (final r in sent.data ?? const <MentoringRequest>[])
      if (r.status == RequestStatus.pending) r,
  ];

  /// Requests waiting on the caller as a mentor.
  List<MentoringRequest> get pendingReceived => [
    for (final r in received.data ?? const <MentoringRequest>[])
      if (r.status == RequestStatus.pending) r,
  ];

  // --- calendar ---------------------------------------------------------------

  Future<void> goToMonth(DateTime day) {
    _month = _firstOfMonth(day);
    calendar.reset();
    _notify();
    return calendar.load();
  }

  Future<void> nextMonth() => goToMonth(_nextMonth(_month));
  Future<void> previousMonth() => goToMonth(DateTime(_month.year, _month.month - 1));

  // --- actions ----------------------------------------------------------------

  Future<String?> withdrawRequest(MentoringRequest r) => _act(() async {
    await repository.withdrawRequest(r.id);
    await Future.wait([sent.load(), summary.load(), quota.load()]);
  });

  /// A mentor answers a request: [accept] pairs them, otherwise it is declined with [note].
  Future<String?> respond(MentoringRequest r, {required bool accept, String? note, String? cadence}) => _act(() async {
    await repository.respondToRequest(r.id, accept: accept, note: note, cadence: cadence);
    await Future.wait([received.load(), summary.load(), if (accept) pairings.load()]);
  });

  Future<String?> saveIntent(MenteeIntent value) => _act(() async {
    await repository.saveMenteeIntent(value);
    await intent.load();
  });

  Future<String?> unsave(SavedMentor m) => _act(() async {
    await repository.unsaveMentor(m.mentorProfileId);
    saved.data = [
      for (final s in saved.data ?? const <SavedMentor>[])
        if (s.mentorProfileId != m.mentorProfileId) s,
    ];
    _notify();
  });

  Future<String?> _act(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month);
  static DateTime _nextMonth(DateTime d) => DateTime(d.year, d.month + 1);
}
