import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'events_manage_models.dart';
import 'events_manage_repository.dart';

String _message(Object e) => ApiError.from(e).message;

/// A controller that may be told to notify after its screen has gone.
abstract class _Safe extends ChangeNotifier {
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}

/// The Events tab: the staff list with its search and three filters, all asked of the API (`GET /events/admin`
/// filters, counts and pages), a page at a time.
class ManageEventsController extends _Safe {
  ManageEventsController(this.repository);

  final EventsManageRepository repository;

  static const pageSize = 20;

  List<ManagedEvent> rows = const [];
  int total = 0;

  /// Matches across every date, type and host while a filter narrows the list (the website's suggestions), less
  /// the ones already listed.
  List<ManagedEvent> otherMatches = const [];

  bool loading = true;
  bool loaded = false;
  bool loadingMore = false;
  String? error;

  String search = '';

  /// `upcoming`, `past` or null (All).
  String? when;
  String? kind;

  /// `icr`, `partner` or null (All hosts).
  String? host;

  int _page = 1;
  int _generation = 0;

  bool get filtered => search.trim().isNotEmpty || kind != null || when != null || host != null;
  bool get hasMore => rows.length < total;

  EventsQuery _query(int page) =>
      EventsQuery(search: search, when: when, kind: kind, host: host, page: page, limit: pageSize);

  /// Called from `initState`: nothing is notified before the first answer.
  void start() {
    _load();
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    final gen = ++_generation;
    loading = true;
    error = null;
    try {
      final narrowed = when != null || kind != null || host != null;
      final wide = search.trim().length >= 2 && narrowed;
      final results = await Future.wait([
        repository.events(_query(1)),
        if (wide) repository.events(EventsQuery(search: search, limit: 6)),
      ]);
      if (gen != _generation) return;
      rows = results[0].rows;
      total = results[0].total;
      final listed = {for (final r in rows) r.id};
      otherMatches = wide
          ? [
              for (final r in results[1].rows)
                if (!listed.contains(r.id)) r,
            ]
          : const [];
      _page = 1;
      loaded = true;
    } catch (e) {
      if (gen != _generation) return;
      error = _message(e);
    }
    loading = false;
    _notify();
  }

  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return;
    final gen = _generation;
    loadingMore = true;
    _notify();
    try {
      final next = await repository.events(_query(_page + 1));
      if (gen != _generation) return;
      final seen = {for (final r in rows) r.id};
      rows = [
        ...rows,
        for (final r in next.rows)
          if (!seen.contains(r.id)) r,
      ];
      total = next.total;
      _page += 1;
      // A page that adds nothing ends the list, whatever the count said.
      if (next.rows.isEmpty) total = rows.length;
    } catch (e) {
      if (gen != _generation) return;
      error = _message(e);
    }
    loadingMore = false;
    _notify();
  }

  void _changed() {
    loading = true;
    _notify();
    _load();
  }

  void setSearch(String value) {
    if (value.trim() == search.trim()) return;
    search = value;
    _changed();
  }

  void setWhen(String? value) {
    if (value == when) return;
    when = value;
    _changed();
  }

  void setKind(String? value) {
    if (value == kind) return;
    kind = value;
    _changed();
  }

  void setHost(String? value) {
    if (value == host) return;
    host = value;
    _changed();
  }

  void clearFilters() {
    search = '';
    when = null;
    kind = null;
    host = null;
    _changed();
  }

  /// `POST /events`; the new id, or the API's refusal.
  Future<({String? id, String? refusal})> create(Map<String, Object?> body) async {
    try {
      final id = await repository.createEvent(body);
      await _load();
      return (id: id, refusal: null);
    } catch (e) {
      return (id: null, refusal: _message(e));
    }
  }
}

/// The Event partners tab: companies asking to host events, by standing, with the number that waits.
class HostRequestsController extends _Safe {
  HostRequestsController(this.repository, {this.focusId}) : status = focusId == null ? 'PENDING' : null;

  final EventsManageRepository repository;

  /// A notification's request: the tab opens on All so the list holds it whatever its standing.
  final String? focusId;

  static const pageSize = 20;

  /// How many pages are read looking for [focusId] before giving up.
  static const _focusPages = 5;

  List<HostApplication> rows = const [];
  int total = 0;
  int pending = 0;

  bool loading = true;
  bool loaded = false;
  bool loadingMore = false;
  String? error;

  /// `PENDING`, `APPROVED`, `REJECTED`, `REVOKED`, or null (All).
  String? status;
  String search = '';

  int _page = 1;
  int _generation = 0;
  bool _focusSought = false;

  bool get hasMore => rows.length < total;
  HostApplication? get focused => focusId == null ? null : rows.where((r) => r.id == focusId).firstOrNull;

  void start() {
    _load();
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    final gen = ++_generation;
    loading = true;
    error = null;
    try {
      final results = await Future.wait<Object>([
        repository.hostApplications(status: status, search: search, limit: pageSize),
        repository.pendingHostApplications().catchError((Object _) => pending),
      ]);
      if (gen != _generation) return;
      var page = results[0] as Paged<HostApplication>;
      var list = page.rows;
      var at = 1;
      // The request a notification named may sit past the first page.
      if (focusId != null && !_focusSought && status == null && search.trim().isEmpty) {
        while (!list.any((r) => r.id == focusId) && list.length < page.total && at < _focusPages) {
          at += 1;
          page = await repository.hostApplications(page: at, limit: pageSize);
          if (gen != _generation) return;
          if (page.rows.isEmpty) break;
          list = [...list, ...page.rows];
        }
        _focusSought = true;
      }
      rows = list;
      total = page.total;
      pending = results[1] as int;
      _page = at;
      loaded = true;
    } catch (e) {
      if (gen != _generation) return;
      error = _message(e);
    }
    loading = false;
    _notify();
  }

  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return;
    final gen = _generation;
    loadingMore = true;
    _notify();
    try {
      final next = await repository.hostApplications(status: status, search: search, page: _page + 1, limit: pageSize);
      if (gen != _generation) return;
      final seen = {for (final r in rows) r.id};
      rows = [
        ...rows,
        for (final r in next.rows)
          if (!seen.contains(r.id)) r,
      ];
      total = next.rows.isEmpty ? rows.length : next.total;
      _page += 1;
    } catch (e) {
      if (gen != _generation) return;
      error = _message(e);
    }
    loadingMore = false;
    _notify();
  }

  void setStatus(String? value) {
    if (value == status) return;
    status = value;
    loading = true;
    _notify();
    _load();
  }

  void setSearch(String value) {
    if (value.trim() == search.trim()) return;
    search = value;
    loading = true;
    _notify();
    _load();
  }

  /// Approve, reject or revoke; the API's refusal, or null once the list is read again.
  Future<String?> decide(HostApplication request, String action, {String? note}) async {
    try {
      await repository.decideHostApplication(request.id, action, note: note);
    } catch (e) {
      return _message(e);
    }
    await _load();
    return null;
  }
}

/// One event's manage page: the event itself, its programme (guest list, speakers, sponsors) and its tickets, and
/// every write the website's dialogs make. A write answers with the API's refusal, or null once what it changed
/// has been read again.
class ManageEventController extends _Safe {
  ManageEventController(this.repository, {required this.eventId, ManagedEvent? initial}) : event = initial;

  final EventsManageRepository repository;
  final String eventId;

  ManagedEvent? event;
  bool loading = true;
  String? error;

  /// The event was removed (here or elsewhere): the page has nothing to show.
  bool gone = false;

  EventProgramme? programme;
  bool programmeLoading = true;
  String? programmeError;

  List<TicketRow> tickets = const [];
  int ticketsTotal = 0;
  bool ticketsLoading = true;
  bool ticketsLoadingMore = false;
  String? ticketsError;
  int _ticketsPage = 1;

  /// The last invite's result sentence, shown above the guest list.
  String? inviteNotice;

  /// A refund that waits for a second approver (the website's `ApprovalSentNotice`).
  RefundPending? refundPending;

  /// The last attendance run's result sentence.
  String? attendanceNotice;

  /// Rows a write is on its way for.
  final Set<String> busy = {};

  List<OrgRef>? _chapters;
  List<OrgRef>? _councils;

  bool get hasMoreTickets => tickets.length < ticketsTotal;

  void start() {
    _loadAll();
  }

  Future<void> refresh() => _loadAll();

  Future<void> _loadAll() async {
    await Future.wait([_loadEvent(), _loadProgramme(), _loadTickets()]);
  }

  Future<void> _loadEvent() async {
    loading = true;
    error = null;
    try {
      final found = await repository.event(eventId);
      if (found == null) {
        gone = event == null;
        // A row handed in by the list stays on screen if the lookup cannot find it again.
        if (gone) error = 'Event not found';
      } else {
        event = found;
        gone = false;
      }
    } catch (e) {
      error = _message(e);
    }
    loading = false;
    _notify();
  }

  Future<void> _loadProgramme() async {
    programmeLoading = true;
    programmeError = null;
    try {
      programme = await repository.programme(eventId);
    } catch (e) {
      programmeError = _message(e);
    }
    programmeLoading = false;
    _notify();
  }

  Future<void> _loadTickets() async {
    ticketsLoading = true;
    ticketsError = null;
    try {
      final page = await repository.tickets(eventId);
      tickets = page.rows;
      ticketsTotal = page.total;
      _ticketsPage = 1;
    } catch (e) {
      ticketsError = _message(e);
    }
    ticketsLoading = false;
    _notify();
  }

  Future<void> loadMoreTickets() async {
    if (ticketsLoadingMore || !hasMoreTickets) return;
    ticketsLoadingMore = true;
    _notify();
    try {
      final next = await repository.tickets(eventId, page: _ticketsPage + 1);
      final seen = {for (final t in tickets) t.id};
      tickets = [
        ...tickets,
        for (final t in next.rows)
          if (!seen.contains(t.id)) t,
      ];
      ticketsTotal = next.rows.isEmpty ? tickets.length : next.total;
      _ticketsPage += 1;
    } catch (e) {
      ticketsError = _message(e);
    }
    ticketsLoadingMore = false;
    _notify();
  }

  Future<String?> _write(Future<void> Function() call, {String? busyId, Future<void> Function()? then}) async {
    if (busyId != null) {
      busy.add(busyId);
      _notify();
    }
    try {
      await call();
    } catch (e) {
      if (busyId != null) busy.remove(busyId);
      _notify();
      return _message(e);
    }
    await (then ?? _loadProgramme)();
    if (busyId != null) busy.remove(busyId);
    _notify();
    return null;
  }

  // --- the event ---------------------------------------------------------------------------------------------------

  /// The host pickers' lists, read once; a read that fails leaves the picker with the event's own host.
  Future<List<OrgRef>> chapters() async =>
      _chapters ??= await repository.chapters().catchError((Object _) => <OrgRef>[]);

  Future<List<OrgRef>> councils() async =>
      _councils ??= await repository.councils().catchError((Object _) => <OrgRef>[]);

  Future<List<String>> addresses(String query, {String? session}) =>
      repository.addresses(query, session: session).catchError((Object _) => <String>[]);

  Future<String?> save(Map<String, Object?> body) =>
      _write(() => repository.updateEvent(eventId, body), then: _loadEvent);

  Future<String?> delete() async {
    try {
      await repository.deleteEvent(eventId);
      return null;
    } catch (e) {
      return _message(e);
    }
  }

  // --- the guest list ----------------------------------------------------------------------------------------------

  /// Invites by email; the result, or the refusal.
  Future<({InviteResult? result, String? refusal})> invite(List<String> emails) async {
    try {
      final result = await repository.invite(eventId, emails: emails);
      await _loadProgramme();
      return (result: result, refusal: null);
    } catch (e) {
      return (result: null, refusal: _message(e));
    }
  }

  Future<({TierInviteResult? result, String? refusal})> inviteByTier(String tier) async {
    try {
      final result = await repository.inviteByTier(eventId, tier);
      await _loadProgramme();
      return (result: result, refusal: null);
    } catch (e) {
      return (result: null, refusal: _message(e));
    }
  }

  void setInviteNotice(String? text) {
    inviteNotice = text;
    _notify();
  }

  Future<String?> removeInvite(EventInvite invite) =>
      _write(() => repository.removeInvite(eventId, invite.userId), busyId: invite.id);

  // --- speakers and sponsors ---------------------------------------------------------------------------------------

  Future<String?> decideProposal(EventProposal proposal, String status, {String? note}) =>
      _write(() => repository.decideProposal(proposal.id, status: status, note: note));

  Future<String?> savePackage(SponsorPackage? existing, Map<String, Object?> body) => _write(
    () => existing == null ? repository.createPackage(eventId, body) : repository.updatePackage(existing.id, body),
  );

  Future<String?> removePackage(SponsorPackage package) =>
      _write(() => repository.deletePackage(package.id), busyId: package.id);

  Future<String?> decideSponsorship(SponsorshipRequest request, String status, {String? note}) =>
      _write(() => repository.decideSponsorship(request.id, status: status, note: note));

  // --- tickets and attendance --------------------------------------------------------------------------------------

  /// Records a refund: done at once (the lists are read again), or sent for approval (nothing recorded yet).
  Future<({RefundOutcome? outcome, String? refusal})> refund(TicketRow ticket, {String? refundRef}) async {
    try {
      final outcome = await repository.refundTicket(ticket.id, refundRef: refundRef);
      refundPending = outcome is RefundPending ? outcome : null;
      await Future.wait([_loadTickets(), _loadEvent()]);
      return (outcome: outcome, refusal: null);
    } catch (e) {
      return (outcome: null, refusal: _message(e));
    }
  }

  /// The people the console can name for attendance: paid ticket holders and the guest list, each once. The API
  /// lists no RSVPs to staff, so a member who took a free place uninvited is not here.
  List<({String userId, String name, String email})> get attendanceCandidates {
    final seen = <String>{};
    return [
      for (final t in tickets)
        if (t.status == 'PAID' && t.userId.isNotEmpty && seen.add(t.userId))
          (userId: t.userId, name: t.name, email: t.email),
      for (final i in programme?.invites ?? const <EventInvite>[])
        if (i.userId.isNotEmpty && seen.add(i.userId)) (userId: i.userId, name: i.name, email: i.email),
    ];
  }

  Future<({AttendanceResult? result, String? refusal})> markAttendance(List<String> userIds) async {
    try {
      final result = await repository.markAttendance(eventId, userIds);
      await _loadEvent();
      return (result: result, refusal: null);
    } catch (e) {
      return (result: null, refusal: _message(e));
    }
  }

  void setAttendanceNotice(String? text) {
    attendanceNotice = text;
    _notify();
  }
}
