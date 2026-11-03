import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import '../chapters/chapter_controller.dart' show SectionState;
import 'council_models.dart';
import 'councils_repository.dart';

export '../chapters/chapter_controller.dart' show SectionState;

/// A council's own page: the council with the member's seat (taken and given back at once, rolled back if the API
/// refuses), the five figures, and the sections that load on their own (events, updates, knowledge, the roster), so
/// one that fails leaves the rest of the page standing. The chapter's page is the twin of this one.
class CouncilController extends ChangeNotifier {
  CouncilController({required this.repository, required this.idOrSlug, this.onChanged, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final CouncilPageRepository repository;
  final DateTime Function() _clock;

  /// The page's clock, for the times a row reads against "now".
  DateTime get now => _clock();

  /// The slug (or id) the page was opened with.
  final String idOrSlug;

  /// Tells the board when the member's seat changes.
  final ValueChanged<Council>? onChanged;

  CouncilDetail? _detail;
  bool _started = false;
  bool _loading = false;
  bool _busy = false;
  bool _disposed = false;
  String? _error;
  int _unread = 0;

  SectionState<CouncilPerson> _members = const SectionState();
  MemberFilter _memberFilter = MemberFilter.all;
  String _memberSearch = '';
  int _memberPage = 1;
  int _memberTotal = 0;
  bool _membersHasNext = false;
  bool _membersMore = false;

  SectionState<CouncilEvent> _events = const SectionState();
  bool _pastEvents = false;
  SectionState<CouncilUpdate> _updates = const SectionState();
  SectionState<CouncilResource> _resources = const SectionState();

  bool get started => _started;
  bool get loading => _loading;
  String? get error => _error;
  int get unread => _unread;
  CouncilDetail? get detail => _detail;
  Council? get council => _detail?.council;

  /// A join or leave in flight.
  bool get busy => _busy;

  SectionState<CouncilPerson> get members => _members;
  MemberFilter get memberFilter => _memberFilter;
  String get memberSearch => _memberSearch;
  int get memberTotal => _memberTotal;
  bool get membersHasNext => _membersHasNext;
  bool get membersLoadingMore => _membersMore;

  SectionState<CouncilEvent> get events => _events;
  bool get pastEvents => _pastEvents;
  SectionState<CouncilUpdate> get updates => _updates;
  SectionState<CouncilResource> get resources => _resources;

  /// The council and every section have answered (or failed): the page has the height it will keep, so a page
  /// opened on a section (`?tab=`) can scroll to it.
  bool get settled {
    if (_detail == null) return false;
    return [_members.loading, _events.loading, _updates.loading, _resources.loading].every((l) => !l) &&
        [_members, _events, _updates, _resources].every((s) => s.loaded || s.error != null);
  }

  Future<void> start() async {
    _started = true;
    await _load(notify: false);
  }

  Future<void> refresh() => _load(notify: true);

  /// The council first (the page needs it), then its sections side by side. [notify] is false for the first
  /// load, which runs from `initState`.
  Future<void> _load({required bool notify}) async {
    _loading = true;
    _error = null;
    if (notify) _notify();
    try {
      _detail = await repository.detail(_detail?.council.slug ?? idOrSlug);
    } catch (e) {
      _error = ApiError.from(e).message;
    } finally {
      _loading = false;
      _notify();
    }
    if (_detail == null) return;
    await Future.wait([_loadMembers(), loadEvents(), _loadUpdates(), _loadResources(), _loadUnread()]);
  }

  Future<void> _loadUnread() async {
    try {
      _unread = await repository.unreadNotifications();
      _notify();
    } catch (_) {}
  }

  // --- members -------------------------------------------------------------

  Future<void> _loadMembers() async {
    final slug = council?.slug;
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
    final slug = council?.slug;
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

  // --- events, updates, knowledge --------------------------------------------

  /// The Upcoming / Past tabs of the Events section.
  Future<void> loadEvents({bool? past}) async {
    final slug = council?.slug;
    if (slug == null) return;
    if (past != null) _pastEvents = past;
    final wanted = _pastEvents;
    _events = SectionState(loading: true, items: _events.items, loaded: _events.loaded);
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

  Future<void> _loadUpdates() async {
    final slug = council?.slug;
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
    final slug = council?.slug;
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

  // --- the member's seat -------------------------------------------------------

  /// Takes a seat; a sentence when the API refuses.
  Future<String?> join() async {
    final d = _detail;
    if (d == null || d.council.joined || _busy) return null;
    _busy = true;
    _set(d.council.copyWith(membership: CouncilRole.member), 1);
    try {
      final role = await repository.join(d.council);
      _set(_detail!.council.copyWith(membership: role), 0);
      return null;
    } catch (e) {
      _set(d.council, -1);
      return ApiError.from(e).message;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Gives the seat back; a sentence when the API refuses.
  Future<String?> leave() async {
    final d = _detail;
    if (d == null || !d.council.joined || _busy) return null;
    _busy = true;
    _set(d.council.copyWith(clearMembership: true), -1);
    try {
      await repository.leave(d.council);
      return null;
    } catch (e) {
      _set(d.council, 1);
      return ApiError.from(e).message;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _set(Council c, int memberDelta) {
    final d = _detail;
    if (d == null) return;
    _detail = d.copyWith(council: c, stats: memberDelta == 0 ? d.stats : d.stats.withMembers(memberDelta));
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
