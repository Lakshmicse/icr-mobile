import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'council_format.dart';
import 'council_models.dart';
import 'councils_repository.dart';

/// The website's size bands for a council: large (more than ten members),
/// medium (three to ten) and small.
int sizeBand(int members) => members > 10 ? 2 : (members >= 3 ? 1 : 0);

/// The Councils screen's state: the overview, the search, the category and
/// sort the directory is narrowed by, and the member's seats (joined at
/// once, rolled back if the API refuses).
class CouncilsController extends ChangeNotifier {
  CouncilsController(this.repository);

  final CouncilsRepository repository;

  CouncilsOverview? _overview;
  String _search = '';
  String? _segment;
  CouncilSort _sort = CouncilSort.recommended;
  bool _loading = false;
  String? _error;
  int _unread = 0;
  int _generation = 0;
  bool _started = false;
  final Set<String> _busy = {};

  bool get started => _started;
  bool get loading => _loading;
  String? get error => _error;
  int get unread => _unread;
  String get search => _search;

  /// The category chip that is on; null is "All Categories".
  String? get segment => _segment;
  CouncilSort get sort => _sort;
  CouncilsOverview? get overview => _overview;
  CouncilStats? get stats => _overview?.stats;
  List<Council> get joined => _overview?.joined ?? const [];
  List<Roundtable> get roundtables => _overview?.roundtables ?? const [];
  List<ChapterSummit> get chapters => _overview?.chapters ?? const [];

  /// A join or leave in flight for the council.
  bool isBusy(Council council) => _busy.contains(council.id);

  /// The category chips: each council's category (its first segment), in the
  /// order the directory first meets them, so the chips follow the cards.
  List<String> get categories {
    final seen = <String>{};
    final out = <String>[];
    final all = _overview?.councils ?? const <Council>[];
    for (final c in _ordered(all, CouncilSort.recommended)) {
      final category = c.category;
      if (category != null && seen.add(category)) out.add(category);
    }
    return out;
  }

  /// The directory narrowed by the search and the category, in the chosen
  /// order. Sorts are stable: ties keep the API's order (by name).
  List<Council> get councils {
    final all = _overview?.councils ?? const <Council>[];
    final q = _search.trim().toLowerCase();
    final out = all.where((c) {
      if (_segment != null && c.category != _segment) return false;
      if (q.isEmpty) return true;
      final hay = '${c.name} ${c.focus ?? ''} ${c.description ?? ''} ${c.segments.join(' ')} ${c.chair?.name ?? ''}';
      return hay.toLowerCase().contains(q);
    }).toList();
    return _ordered(out, _sort);
  }

  /// [list] in the order [sort] asks for. "Recommended" is the website's
  /// (councils sharing a segment with the member's own come first) followed by
  /// what the card itself prints: the larger communities, then the soonest
  /// session, then the most members.
  List<Council> _ordered(List<Council> list, CouncilSort sort) {
    final all = _overview?.councils ?? const <Council>[];
    final held = <String, int>{};
    for (final j in all.where((j) => j.joined)) {
      for (final s in j.segments.toSet()) {
        held[s] = (held[s] ?? 0) + 1;
      }
    }
    // The segments of the member's *other* councils: a seat does not lift its own council.
    int recommend(Council c) {
      final own = c.joined ? 1 : 0;
      return c.segments.toSet().where((s) => (held[s] ?? 0) - own > 0).length;
    }

    int activity(Council c) => c.upcomingEventCount * 10 + c.memberCount;
    final rank = switch (sort) {
      CouncilSort.members => (Council a, Council b) => b.memberCount - a.memberCount,
      CouncilSort.active => (Council a, Council b) => activity(b) - activity(a),
      CouncilSort.newest => (Council a, Council b) => (b.createdAt ?? DateTime(0)).compareTo(
        a.createdAt ?? DateTime(0),
      ),
      CouncilSort.az => (Council a, Council b) => a.name.compareTo(b.name),
      CouncilSort.recommended => (Council a, Council b) {
        var r = recommend(b) - recommend(a);
        if (r != 0) return r;
        r = sizeBand(b.memberCount) - sizeBand(a.memberCount);
        if (r != 0) return r;
        r = compareNextEvent(a.nextEventAt, b.nextEventAt);
        return r != 0 ? r : b.memberCount - a.memberCount;
      },
    };
    final order = {for (final (i, c) in all.indexed) c.id: i};
    final sorted = [...list];
    sorted.sort((a, b) {
      final r = rank(a, b);
      return r != 0 ? r : (order[a.id] ?? 0) - (order[b.id] ?? 0);
    });
    return sorted;
  }

  bool get narrowed => _search.trim().isNotEmpty || _segment != null;

  Future<void> start() async {
    _started = true;
    await Future.wait([_load(notify: false), _loadUnread()]);
  }

  /// Pull-to-refresh: reads everything again, the bell's count included.
  Future<void> refresh() => Future.wait([_load(notify: true), _loadUnread()]);

  /// [notify] is false for the first load: `start()` runs from `initState`,
  /// before the first build reads `loading`, and a notification there lands in
  /// the middle of a build (a provider made with its screen asserts on it).
  Future<void> _load({required bool notify}) async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    if (notify) notifyListeners();
    try {
      final overview = await repository.overview();
      if (generation != _generation) return;
      _overview = overview;
    } catch (e) {
      if (generation != _generation) return;
      _error = ApiError.from(e).message;
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  void setSearch(String query) {
    if (query.trim() == _search) return;
    _search = query.trim();
    notifyListeners();
  }

  void setSegment(String? segment) {
    _segment = segment;
    notifyListeners();
  }

  void setSort(CouncilSort sort) {
    _sort = sort;
    notifyListeners();
  }

  void clearFilters() {
    _search = '';
    _segment = null;
    notifyListeners();
  }

  /// Takes a seat in the council; a sentence when the API refuses.
  Future<String?> join(Council council) async {
    if (council.joined || _busy.contains(council.id)) return null;
    _busy.add(council.id);
    _apply(council.id, (c) => c.copyWith(membership: CouncilRole.member), addToJoined: true);
    try {
      final role = await repository.join(council);
      _apply(council.id, (c) => c.copyWith(membership: role));
      return null;
    } catch (e) {
      _apply(council.id, (c) => c.copyWith(clearMembership: true), removeFromJoined: true);
      return ApiError.from(e).message;
    } finally {
      _busy.remove(council.id);
      notifyListeners();
    }
  }

  /// Gives the seat up; a sentence when the API refuses.
  Future<String?> leave(Council council) async {
    if (!council.joined || _busy.contains(council.id)) return null;
    final role = council.membership!;
    _busy.add(council.id);
    _apply(council.id, (c) => c.copyWith(clearMembership: true), removeFromJoined: true);
    try {
      await repository.leave(council);
      return null;
    } catch (e) {
      _apply(council.id, (c) => c.copyWith(membership: role), addToJoined: true);
      return ApiError.from(e).message;
    } finally {
      _busy.remove(council.id);
      notifyListeners();
    }
  }

  Council? find(String id) {
    for (final c in _overview?.councils ?? const <Council>[]) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _loadUnread() async {
    try {
      _unread = await repository.unreadNotifications();
      notifyListeners();
    } catch (_) {}
  }

  void _apply(String id, Council Function(Council) change, {bool addToJoined = false, bool removeFromJoined = false}) {
    final overview = _overview;
    if (overview == null) return;
    Council swap(Council c) => c.id == id ? change(c) : c;
    final councils = overview.councils.map(swap).toList();
    var joined = overview.joined.map(swap).toList();
    if (removeFromJoined) joined = joined.where((c) => c.id != id).toList();
    if (addToJoined && !joined.any((c) => c.id == id)) {
      final council = councils.where((c) => c.id == id).firstOrNull;
      if (council != null) joined = sortJoined([...joined, council]);
    }
    _overview = overview.copyWith(councils: councils, joined: joined);
    notifyListeners();
  }
}
