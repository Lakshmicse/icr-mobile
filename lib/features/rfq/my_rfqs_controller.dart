import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'rfq_models.dart';
import 'rfq_repository.dart';

/// "My RFQ's": the buyer's requirements by view, with search, type and sort,
/// the counts on the tabs and what is waiting on the buyer. Row moves
/// (publish, close, cancel, delete a draft) are applied at once and rolled
/// back with the API's sentence when it refuses.
class MyRfqsController extends ChangeNotifier {
  MyRfqsController(this.repository);

  final RfqRepository repository;

  RequirementsSummary? _summary;
  List<Requirement> _rows = const [];
  MyView _view = MyView.all;
  String _search = '';
  RfqKind? _kind;
  MySort _sort = MySort.updated;
  int _page = 1;
  bool _hasMore = false;
  int _total = 0;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  bool _forbidden = false;
  Poster? _poster;
  int _unread = 0;
  bool _started = false;
  int _generation = 0;
  final Set<String> _busy = {};

  RequirementsSummary? get summary => _summary;
  List<Requirement> get rows => _rows;
  MyView get view => _view;
  String get search => _search;
  RfqKind? get kind => _kind;
  MySort get sort => _sort;
  bool get hasMore => _hasMore;
  int get total => _total;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  String? get error => _error;

  /// The API refused the list itself: the account's role does not post requirements.
  bool get forbidden => _forbidden;

  /// Who was refused (read once, only when the list is): lets the screen say whether a company is the fix.
  Poster? get poster => _poster;
  int get unread => _unread;
  bool get started => _started;
  bool isBusy(String id) => _busy.contains(id);

  /// A search, a type or "posted by" narrows the list (the empty state says so).
  bool get narrowed => _search.isNotEmpty || _kind != null;

  /// Nothing posted at all, in any status: the first-requirement card.
  bool get nothingAtAll => _summary != null && _summary!.count(MyView.all) == 0 && !narrowed;

  int count(MyView v) => _summary?.count(v) ?? 0;

  Future<void> start() async {
    _started = true;
    await Future.wait([_load(notify: false), _loadUnread()]);
  }

  Future<void> refresh() => _load(notify: true);

  /// [notify] is false for the first load, which runs from `initState`.
  Future<void> _load({required bool notify}) async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    if (notify) notifyListeners();
    try {
      final results = await Future.wait([
        repository.summary(),
        repository.mine(view: _view, search: _search, kind: _kind, sort: _sort),
      ]);
      if (generation != _generation) return;
      _summary = results[0] as RequirementsSummary;
      final page = results[1] as RequirementPage;
      _rows = page.rows;
      _hasMore = page.hasMore;
      _total = page.total;
      _page = 1;
      _forbidden = false;
    } catch (e) {
      if (generation != _generation) return;
      final error = ApiError.from(e);
      _error = error.message;
      _forbidden = error.statusCode == 403;
      if (_forbidden) {
        try {
          _poster = await repository.me();
        } catch (_) {
          // The generic notice stands.
        }
      }
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadUnread() async {
    try {
      _unread = await repository.unreadNotifications();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setView(MyView view) async {
    if (view == _view) return;
    _view = view;
    await refresh();
  }

  Future<void> setSearch(String query) async {
    if (query.trim() == _search) return;
    _search = query.trim();
    await refresh();
  }

  Future<void> setKind(RfqKind? kind) async {
    if (kind == _kind) return;
    _kind = kind;
    await refresh();
  }

  Future<void> setSort(MySort sort) async {
    if (sort == _sort) return;
    _sort = sort;
    await refresh();
  }

  Future<void> clearFilters() async {
    _search = '';
    _kind = null;
    await refresh();
  }

  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final page = await repository.mine(view: _view, search: _search, kind: _kind, sort: _sort, page: _page + 1);
      _rows = [..._rows, ...page.rows.where((r) => !_rows.any((x) => x.id == r.id))];
      _hasMore = page.hasMore;
      _page++;
    } catch (_) {
      // The next scroll tries again.
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  /// Publishes, closes or cancels a row; the row changes at once and goes back
  /// if the API refuses. Returns the API's sentence on a refusal.
  Future<String?> act(Requirement r, RfqAction action) async {
    if (_busy.contains(r.id)) return null;
    final to = switch (action) {
      RfqAction.publish => RfqStatus.published,
      RfqAction.close => RfqStatus.closed,
      RfqAction.cancel => RfqStatus.cancelled,
    };
    _busy.add(r.id);
    _replace(r.id, (x) => x.copyWith(status: to));
    try {
      await repository.act(r.id, action);
      _busy.remove(r.id);
      // The tabs' counts and the row's stage follow from the API.
      await _reloadQuietly();
      return null;
    } catch (e) {
      _busy.remove(r.id);
      _replace(r.id, (_) => r);
      return ApiError.from(e).message;
    }
  }

  /// Deletes a draft: it leaves the list at once and comes back if refused.
  Future<String?> deleteDraft(Requirement r) async {
    if (r.status != RfqStatus.draft || _busy.contains(r.id)) return null;
    final before = _rows;
    _busy.add(r.id);
    _rows = [
      for (final x in _rows)
        if (x.id != r.id) x,
    ];
    notifyListeners();
    try {
      await repository.deleteDraft(r.id);
      _busy.remove(r.id);
      await _reloadQuietly();
      return null;
    } catch (e) {
      _busy.remove(r.id);
      _rows = before;
      notifyListeners();
      return ApiError.from(e).message;
    }
  }

  /// Reads the counts and the page again without the loading state.
  Future<void> _reloadQuietly() async {
    try {
      final results = await Future.wait([
        repository.summary(),
        repository.mine(view: _view, search: _search, kind: _kind, sort: _sort),
      ]);
      _summary = results[0] as RequirementsSummary;
      final page = results[1] as RequirementPage;
      _rows = page.rows;
      _hasMore = page.hasMore;
      _total = page.total;
      _page = 1;
    } catch (_) {
      // What is on screen stays; pull to refresh reads it again.
    }
    notifyListeners();
  }

  void _replace(String id, Requirement Function(Requirement) change) {
    _rows = [for (final x in _rows) x.id == id ? change(x) : x];
    notifyListeners();
  }
}
