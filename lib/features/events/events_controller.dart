import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'event_format.dart';
import 'event_models.dart';
import 'events_repository.dart';

/// A chip under the search: "All Events", "Upcoming (24)", a kind.
class EventChip {
  const EventChip({required this.label, required this.selected, required this.select});

  final String label;
  final bool selected;
  final VoidCallback select;
}

/// The Events tab's state: the board at rest or the results of a search, the
/// chip, track and filter it is narrowed by, and the member's places and
/// bookmarks (applied at once, rolled back if the API refuses).
class EventsController extends ChangeNotifier {
  EventsController(this.repository);

  final EventsRepository repository;

  EventsOverview? _overview;
  EventQuery _query = const EventQuery();
  bool _soonOnly = false;
  EventTrack? _track;
  List<EventSummary> _results = const [];
  bool _loading = false;
  bool _started = false;
  bool _disposed = false;
  String? _error;
  int _unread = 0;
  int _generation = 0;

  /// Bookmarks live on the device: the API has no saved-events list.
  final Set<String> _saved = {};

  /// The cards' second lines read from the programmes, by event id; the ids
  /// already asked after are kept so a refresh does not ask again.
  final Map<String, String> _speakers = {};
  final Set<String> _speakersAsked = {};
  Future<void>? _speakerWork;

  bool get started => _started;
  bool get loading => _loading;
  String? get error => _error;
  int get unread => _unread;
  EventQuery get query => _query;
  EventsOverview? get overview => _overview;
  EventSummary? get spotlight => _overview?.spotlight;
  MySchedule? get schedule => _overview?.schedule;
  CpdProgress? get cpd => _overview?.cpd;
  List<EventTrack> get tracks => _overview?.tracks ?? const [];
  int get readyCount => _overview?.readyCount ?? 0;
  String get hostBlurb => _overview?.hostBlurb ?? '';

  /// The category tile the agenda is narrowed to, if any.
  EventTrack? get track => _track;

  /// Completes when the cards' speaker lines read so far have been drawn.
  Future<void> get speakersSettled => _speakerWork ?? Future<void>.value();

  /// A search, the past window or a format narrows the board to one list.
  bool get narrowed => _query.narrows;

  /// Anything to clear: a search or filter, a kind chip, "Upcoming", a track.
  bool get filtered => narrowed || _query.kind != null || _soonOnly || _track != null;

  static const _soon = Duration(days: 30);

  bool _inTrack(EventSummary e) {
    final t = _track;
    if (t == null) return true;
    return t.council != null ? trackOf(e) == t.council : e.kind == t.kind;
  }

  /// The cards under "Upcoming Agenda". The spotlight has its own card above
  /// and is not repeated here.
  List<EventSummary> get agenda {
    if (narrowed) return _results.where(_inTrack).toList();
    final events = _overview?.events ?? const [];
    final cutoff = eventsNow().add(_soon);
    return events
        .where((e) => _query.kind == null || e.kind == _query.kind)
        .where((e) => !_soonOnly || e.startsAt.isBefore(cutoff))
        .where(_inTrack)
        .toList();
  }

  String get agendaTitle {
    if (_query.search.isNotEmpty) return 'Events matching "${_query.search}"';
    if (_query.when == EventWhen.past) return 'Past Events';
    if (_track != null) return '${_track!.label} Events';
    return 'Upcoming Agenda';
  }

  /// The chips: every kind the board has events of, in the design's order.
  List<EventChip> get chips {
    final counts = <EventKind, int>{};
    for (final e in _overview?.events ?? const <EventSummary>[]) {
      counts[e.kind] = (counts[e.kind] ?? 0) + 1;
    }
    return [
      EventChip(label: 'All Events', selected: !_soonOnly && _query.kind == null && _track == null, select: selectAll),
      EventChip(label: 'Upcoming (${_overview?.upcomingCount ?? 0})', selected: _soonOnly, select: selectSoon),
      for (final kind in _chipOrder)
        if ((counts[kind] ?? 0) > 0 || _query.kind == kind)
          EventChip(label: kind.plural, selected: _query.kind == kind, select: () => selectKind(kind)),
    ];
  }

  static const _chipOrder = [
    EventKind.conference,
    EventKind.webinar,
    EventKind.roundtable,
    EventKind.workshop,
    EventKind.masterclass,
    EventKind.chapterMeet,
  ];

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> start() async {
    _started = true;
    await Future.wait([_load(notify: false), _loadUnread()]);
  }

  Future<void> refresh() => _load(notify: true);

  /// [notify] is false for the first load: `start()` runs from `initState`,
  /// before the first build reads `loading`, and a notification there lands in
  /// the middle of a build (a provider made with its screen asserts on it).
  Future<void> _load({required bool notify}) async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    if (notify) _notify();
    try {
      if (narrowed) {
        final rows = await repository.search(_query);
        if (generation != _generation) return;
        _results = rows.map(_decorate).toList();
        _askSpeakers(_results);
      } else {
        final overview = await repository.overview();
        if (generation != _generation) return;
        _overview = overview.copyWith(
          events: overview.events.map(_decorate).toList(),
          spotlight: overview.spotlight == null ? null : _decorate(overview.spotlight!),
        );
        _askSpeakers(_overview!.events);
      }
    } catch (e) {
      if (generation != _generation) return;
      _error = ApiError.from(e).message;
    } finally {
      if (generation == _generation) {
        _loading = false;
        _notify();
      }
    }
  }

  Future<void> setSearch(String text) async {
    if (text.trim() == _query.search) return;
    _query = _query.copyWith(search: text.trim());
    await refresh();
  }

  /// The filter sheet's choice of window and format.
  Future<void> setQuery(EventQuery query) async {
    _query = query;
    await refresh();
  }

  Future<void> clearFilters() => setQuery(EventQuery(search: _query.search));

  /// Back to the board at rest: no search, window, format, chip or track.
  Future<void> clearAll() {
    _soonOnly = false;
    _track = null;
    return setQuery(const EventQuery());
  }

  void selectAll() {
    _soonOnly = false;
    _track = null;
    _query = _query.copyWith(clearKind: true);
    _afterChip();
  }

  void selectSoon() {
    _soonOnly = true;
    _query = _query.copyWith(clearKind: true);
    _afterChip();
  }

  void selectKind(EventKind kind) {
    _soonOnly = false;
    _query = _query.copyWith(kind: kind);
    _afterChip();
  }

  void _afterChip() {
    _notify();
    if (narrowed) refresh();
  }

  /// A tile narrows the agenda to its track (a second tap lifts it); the
  /// demo's categories have nothing to match and do nothing.
  void selectTrack(EventTrack track) {
    if (!track.filters) return;
    if (track.kind != null && track.council == null) {
      selectKind(track.kind!);
      return;
    }
    _track = _track?.key == track.key ? null : track;
    _notify();
  }

  Future<void> _loadUnread() async {
    try {
      _unread = await repository.unreadNotifications();
      _notify();
    } catch (_) {}
  }

  // --- the cards' speaker lines -------------------------------------------------

  /// Asks the programmes of the first cards for their speakers, once per
  /// event, after the board is drawn; the line appears when it arrives.
  void _askSpeakers(List<EventSummary> shown) {
    final fresh = shown
        .where((e) => e.line == null && e.speakerLine == null && !_speakersAsked.contains(e.id))
        .take(12)
        .toList();
    if (fresh.isEmpty) return;
    _speakersAsked.addAll(fresh.map((e) => e.id));
    _speakerWork = (_speakerWork ?? Future<void>.value()).then((_) => _fetchSpeakers(fresh));
  }

  Future<void> _fetchSpeakers(List<EventSummary> events) async {
    try {
      final found = await repository.speakers(events);
      if (_disposed || found.isEmpty) return;
      _speakers.addAll(found);
      final overview = _overview;
      if (overview != null) {
        _overview = overview.copyWith(
          events: overview.events.map(_decorate).toList(),
          spotlight: overview.spotlight == null ? null : _decorate(overview.spotlight!),
        );
      }
      _results = _results.map(_decorate).toList();
      _notify();
    } catch (_) {
      // A card without its speaker keeps the venue line.
    }
  }

  // --- the member's places and bookmarks ------------------------------------------

  /// Bookmarks the event on this device; never fails.
  void toggleSave(EventSummary event) {
    final saved = !event.saved;
    saved ? _saved.add(event.id) : _saved.remove(event.id);
    _apply(event.id, (e) => e.copyWith(saved: saved));
  }

  /// Takes a place at the event; a sentence when the API refuses. The place
  /// is drawn at once and taken back if the API says no.
  Future<String?> register(EventSummary event) async {
    final before = event.rsvp;
    _apply(event.id, (e) => e.copyWith(rsvp: RsvpState.going, going: e.going + 1));
    try {
      final state = await repository.rsvp(event);
      if (state != RsvpState.going) _apply(event.id, (e) => e.copyWith(rsvp: state, going: e.going - 1));
      _refreshSchedule();
      return null;
    } catch (e) {
      _apply(event.id, (x) => x.copyWith(rsvp: before, going: x.going - 1));
      return ApiError.from(e).message;
    }
  }

  /// Gives the place back; a sentence when the API refuses (a paid seat).
  Future<String?> cancel(EventSummary event) async {
    final before = event.rsvp;
    final wasGoing = before == RsvpState.going;
    _apply(event.id, (e) => e.copyWith(rsvp: RsvpState.cancelled, going: wasGoing ? e.going - 1 : e.going));
    try {
      await repository.cancel(event);
      _refreshSchedule();
      return null;
    } catch (e) {
      _apply(event.id, (x) => x.copyWith(rsvp: before, going: wasGoing ? x.going + 1 : x.going));
      return ApiError.from(e).message;
    }
  }

  /// The sheet changed an event (registered, cancelled, saved): keep the board
  /// in step.
  void update(EventSummary event) {
    event.saved ? _saved.add(event.id) : _saved.remove(event.id);
    _apply(event.id, (_) => event.copyWith());
    _refreshSchedule();
  }

  EventSummary? find(String id) {
    for (final e in [...agenda, ?spotlight]) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// "My Schedule (N)" follows the member's places as they change.
  void _refreshSchedule() {
    final overview = _overview;
    if (overview == null || _disposed) return;
    final known = [...overview.events, ?overview.spotlight];
    final schedule = repository.schedule(known);
    _overview = overview.copyWith(schedule: schedule, clearSchedule: schedule == null);
    _notify();
  }

  EventSummary _decorate(EventSummary e) {
    final saved = e.saved || _saved.contains(e.id);
    final speaker = e.speakerLine ?? _speakers[e.id];
    if (saved == e.saved && speaker == e.speakerLine) return e;
    return e.copyWith(saved: saved, speakerLine: speaker);
  }

  void _apply(String id, EventSummary Function(EventSummary) change) {
    EventSummary swap(EventSummary e) => e.id == id ? change(e) : e;
    _results = _results.map(swap).toList();
    final overview = _overview;
    if (overview != null) {
      _overview = overview.copyWith(
        events: overview.events.map(swap).toList(),
        spotlight: overview.spotlight == null ? null : swap(overview.spotlight!),
      );
    }
    _notify();
  }
}
