import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'chapter_models.dart';
import 'chapters_repository.dart';

/// One section of a chapter's page that loads on its own (members, events,
/// updates, resources): a failure there leaves the rest of the page standing.
class SectionState<T> {
  const SectionState({this.items = const [], this.loading = false, this.error, this.loaded = false});

  final List<T> items;
  final bool loading;
  final String? error;
  final bool loaded;

  SectionState<T> busy() => SectionState(items: items, loading: true, loaded: loaded);
  SectionState<T> done(List<T> items) => SectionState(items: items, loaded: true);
  SectionState<T> failed(String error) => SectionState(items: items, error: error, loaded: loaded);
}

/// A chapter's page: the chapter, the member's place in it (taken and given
/// back at once, rolled back if the API refuses), and its sections.
class ChapterController extends ChangeNotifier {
  ChapterController({required this.repository, required this.idOrSlug, this.onChanged, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ChaptersRepository repository;
  final DateTime Function() _clock;

  /// The page's clock, for "Event ended" on a meetup that is over.
  DateTime get now => _clock();

  /// The slug (or id) the page was opened with.
  final String idOrSlug;

  /// Tells the board when the member's place changes.
  final ValueChanged<ChapterSummary>? onChanged;

  ChapterDetail? _detail;
  bool _started = false;
  bool _loading = false;
  bool _busy = false;
  bool _disposed = false;
  String? _error;
  int _unread = 0;

  SectionState<ChapterPerson> _members = const SectionState();
  MemberFilter _memberFilter = MemberFilter.all;
  String _memberSearch = '';
  int _memberPage = 1;
  int _memberTotal = 0;
  bool _membersHasNext = false;
  bool _membersMore = false;

  SectionState<ChapterEvent> _events = const SectionState();
  bool _pastEvents = false;
  final Set<String> _eventBusy = {};
  SectionState<ChapterUpdate> _updates = const SectionState();
  SectionState<ChapterResource> _resources = const SectionState();
  List<ChapterSummary> _nearby = const [];

  bool get started => _started;
  bool get loading => _loading;
  String? get error => _error;
  int get unread => _unread;
  ChapterDetail? get detail => _detail;
  ChapterSummary? get chapter => _detail?.chapter;

  /// A join or leave in flight.
  bool get busy => _busy;

  SectionState<ChapterPerson> get members => _members;
  MemberFilter get memberFilter => _memberFilter;
  String get memberSearch => _memberSearch;
  int get memberTotal => _memberTotal;
  bool get membersHasNext => _membersHasNext;
  bool get membersLoadingMore => _membersMore;

  SectionState<ChapterEvent> get events => _events;
  bool get pastEvents => _pastEvents;

  /// An RSVP (or its cancel) for [event] is on its way to the API.
  bool isEventBusy(ChapterEvent event) => _eventBusy.contains(event.id);
  SectionState<ChapterUpdate> get updates => _updates;
  SectionState<ChapterResource> get resources => _resources;
  List<ChapterSummary> get nearby => _nearby;

  Future<void> start() async {
    _started = true;
    await _load(notify: false);
  }

  Future<void> refresh() => _load(notify: true);

  /// The chapter first (the page needs it), then its sections side by side.
  /// [notify] is false for the first load, which runs from `initState`.
  Future<void> _load({required bool notify}) async {
    _loading = true;
    _error = null;
    if (notify) _notify();
    try {
      _detail = await repository.detail(_detail?.chapter.slug ?? idOrSlug);
    } catch (e) {
      _error = ApiError.from(e).message;
    } finally {
      _loading = false;
      _notify();
    }
    final d = _detail;
    if (d == null) return;
    await Future.wait([
      _loadMembers(),
      loadEvents(),
      _loadUpdates(),
      _loadResources(),
      _loadNearby(d.chapter),
      _loadUnread(),
    ]);
  }

  Future<void> _loadUnread() async {
    try {
      _unread = await repository.unreadNotifications();
      _notify();
    } catch (_) {}
  }

  // --- members -------------------------------------------------------------

  Future<void> _loadMembers() async {
    final slug = chapter?.slug;
    if (slug == null) return;
    _members = _members.busy();
    _notify();
    final filter = _memberFilter;
    final search = _memberSearch;
    try {
      final page = await repository.members(slug, search: search, filter: filter);
      if (filter != _memberFilter || search != _memberSearch) return; // a newer read is on its way
      _members = _members.done(page.members);
      _memberPage = page.page;
      _memberTotal = page.total;
      _membersHasNext = page.hasNext;
    } catch (e) {
      _members = _members.failed(ApiError.from(e).message);
    }
    _notify();
  }

  Future<void> retryMembers() => _loadMembers();

  void setMemberFilter(MemberFilter filter) {
    if (filter == _memberFilter) return;
    _memberFilter = filter;
    _loadMembers();
  }

  void setMemberSearch(String query) {
    if (query.trim() == _memberSearch) return;
    _memberSearch = query.trim();
    _loadMembers();
  }

  /// "Show more members".
  Future<void> moreMembers() async {
    final slug = chapter?.slug;
    if (slug == null || !_membersHasNext || _membersMore) return;
    _membersMore = true;
    _notify();
    try {
      final page = await repository.members(slug, page: _memberPage + 1, search: _memberSearch, filter: _memberFilter);
      _members = _members.done([..._members.items, ...page.members]);
      _memberPage = page.page;
      _membersHasNext = page.hasNext;
    } catch (e) {
      _members = _members.failed(ApiError.from(e).message);
    } finally {
      _membersMore = false;
      _notify();
    }
  }

  // --- events, updates, resources ---------------------------------------------

  /// The Upcoming / Past tabs of "Events & meetups".
  Future<void> loadEvents({bool? past}) async {
    final slug = chapter?.slug;
    if (slug == null) return;
    if (past != null) _pastEvents = past;
    final wanted = _pastEvents;
    _events = SectionState(loading: true, items: _events.items);
    _notify();
    try {
      final rows = await repository.events(slug, past: wanted);
      if (wanted != _pastEvents) return;
      _events = _events.done(rows);
    } catch (e) {
      _events = _events.failed(ApiError.from(e).message);
    }
    _notify();
  }

  /// Takes a place at [event] through the events API; the status it gave (GOING, or WAITLISTED when
  /// the event is full) shows at once and is corrected by the answer. Returns a sentence when the
  /// API refuses (an invite-only event, a ticketed one) and puts the row back as it was.
  Future<String?> rsvp(ChapterEvent event) async {
    if (event.holding || _eventBusy.contains(event.id)) return null;
    _eventBusy.add(event.id);
    _setEvent(event.id, (e) => e.withStatus(e.full ? 'WAITLISTED' : 'GOING', moveCount: true));
    try {
      final status = await repository.rsvp(event);
      _setEvent(event.id, (e) => e.withStatus(status, moveCount: true));
      return null;
    } catch (e) {
      _setEvent(event.id, (_) => event);
      return ApiError.from(e).message;
    } finally {
      _eventBusy.remove(event.id);
      _notify();
    }
  }

  /// Gives the place at [event] back; a sentence when the API refuses (a paid ticket is given up
  /// through ICR) and the place comes back.
  Future<String?> cancelRsvp(ChapterEvent event) async {
    if (!event.holding || _eventBusy.contains(event.id)) return null;
    _eventBusy.add(event.id);
    _setEvent(event.id, (e) => e.withStatus(null, moveCount: true));
    try {
      await repository.cancelRsvp(event);
      return null;
    } catch (e) {
      _setEvent(event.id, (_) => event);
      return ApiError.from(e).message;
    } finally {
      _eventBusy.remove(event.id);
      _notify();
    }
  }

  void _setEvent(String id, ChapterEvent Function(ChapterEvent) change) {
    _events = SectionState(
      items: [for (final e in _events.items) e.id == id ? change(e) : e],
      loaded: _events.loaded,
      loading: _events.loading,
      error: _events.error,
    );
    final d = _detail;
    if (d != null) {
      _detail = d.copyWith(upcomingEvents: [for (final e in d.upcomingEvents) e.id == id ? change(e) : e]);
    }
    _notify();
  }

  Future<void> _loadUpdates() async {
    final slug = chapter?.slug;
    if (slug == null) return;
    _updates = _updates.busy();
    try {
      _updates = _updates.done(await repository.updates(slug));
    } catch (e) {
      _updates = _updates.failed(ApiError.from(e).message);
    }
    _notify();
  }

  Future<void> retryUpdates() => _loadUpdates();

  Future<void> _loadResources() async {
    final slug = chapter?.slug;
    if (slug == null) return;
    _resources = _resources.busy();
    try {
      _resources = _resources.done(await repository.resources(slug));
    } catch (e) {
      _resources = _resources.failed(ApiError.from(e).message);
    }
    _notify();
  }

  Future<void> retryResources() => _loadResources();

  Future<void> _loadNearby(ChapterSummary c) async {
    try {
      _nearby = await repository.nearby(c);
      _notify();
    } catch (_) {
      // The sidebar's "Other chapters" is a nicety; the page stands without it.
    }
  }

  // --- the member's place ------------------------------------------------------

  /// Takes a place; a sentence when the API refuses.
  Future<String?> join() async {
    final d = _detail;
    if (d == null || d.chapter.joined || _busy) return null;
    _busy = true;
    _set(d.chapter.copyWith(role: ChapterRole.member, memberCount: d.chapter.memberCount + 1), 1);
    try {
      final role = await repository.join(d.chapter);
      _set(_detail!.chapter.copyWith(role: role), 0);
      return null;
    } catch (e) {
      _set(d.chapter, -1);
      return ApiError.from(e).message;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Gives the place back; a sentence when the API refuses.
  Future<String?> leave() async {
    final d = _detail;
    if (d == null || !d.chapter.joined || _busy) return null;
    _busy = true;
    _set(d.chapter.copyWith(clearRole: true, memberCount: d.chapter.memberCount - 1), -1);
    try {
      await repository.leave(d.chapter);
      return null;
    } catch (e) {
      _set(d.chapter, 1);
      return ApiError.from(e).message;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _set(ChapterSummary c, int memberDelta) {
    final d = _detail;
    if (d == null) return;
    _detail = d.copyWith(chapter: c, stats: d.stats.withMembers(memberDelta));
    onChanged?.call(c);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
