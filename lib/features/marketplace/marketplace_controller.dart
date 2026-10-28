import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'catalog_models.dart';
import 'marketplace_filters.dart';
import 'marketplace_models.dart';
import 'marketplace_repository.dart';

/// The Marketplace tab's state: the supplier list for the search and filters,
/// the bookmarks (applied at once, rolled back if the API refuses) and the
/// numbers on the quick chips.
class MarketplaceController extends ChangeNotifier {
  MarketplaceController(this.repository, {MarketplaceFilters initial = const MarketplaceFilters()})
    : _filters = initial;

  final MarketplaceRepository repository;

  /// Where "My RFQ's" and "Alerts" read their numbers, when the app has a
  /// source of its own (the requirements screens'); else the repository's.
  Future<MarketplaceCounts> Function()? _countsSource;
  Future<MarketplaceCounts> Function()? get countsSource => _countsSource;

  /// Replaces the repository's chip counts with [source] (`null` puts them back).
  void useCounts(Future<MarketplaceCounts> Function()? source) => _countsSource = source;

  MarketplaceFilters _filters;
  List<Supplier> _suppliers = const [];
  int _total = 0;
  int _page = 1;
  bool _hasMore = false;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  bool _started = false;
  int _generation = 0;

  Set<String> _saved = const {};
  MarketplaceCounts _counts = const MarketplaceCounts();
  int _unread = 0;
  SearchExtras _extras = SearchExtras.none;

  // What the search box suggests while it has focus.
  final List<String> _recent = [];
  List<Supplier> _suggestedSuppliers = const [];
  String _suggestedFor = '';
  int _suggestGeneration = 0;

  List<CategoryNode>? _tree;
  Future<List<CategoryNode>>? _treeLoad;
  final Map<String, String> _names = {};
  List<String>? _cities;

  bool get started => _started;
  MarketplaceFilters get filters => _filters;
  List<Supplier> get suppliers => _suppliers;
  int get total => _total;
  bool get hasMore => _hasMore;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  String? get error => _error;
  Set<String> get savedIds => _saved;
  MarketplaceCounts get counts => _counts;
  int get unread => _unread;

  /// Services and requirements the search words also match.
  SearchExtras get extras => _extras;

  /// The searches made this session, newest first (at most six).
  List<String> get recentSearches => List.unmodifiable(_recent);

  /// The suppliers whose names match what is being typed ([suggestedFor]).
  List<Supplier> get suggestedSuppliers => _suggestedSuppliers;
  String get suggestedFor => _suggestedFor;

  /// The category tree, once it has loaded.
  List<CategoryNode>? get tree => _tree;

  /// The cities suppliers are in, once they have loaded.
  List<String>? get cities => _cities;

  bool isSaved(String id) => _saved.contains(id);

  /// What the list is narrowed by, for "No suppliers match".
  bool get narrowed => _filters.narrows;

  // ---- Loading ---------------------------------------------------------------------------

  Future<void> start() async {
    _started = true;
    await Future.wait([_loadList(notify: false), _loadSide(), loadCategories()]);
  }

  Future<void> refresh() async {
    await Future.wait([_loadList(notify: true), _loadSide()]);
  }

  Future<void> _loadList({required bool notify}) async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    if (notify) notifyListeners();
    try {
      final page = _filters.savedOnly ? await repository.savedSuppliers() : await repository.suppliers(_filters);
      if (generation != _generation) return;
      _suppliers = page.suppliers;
      _total = page.total;
      _hasMore = page.hasMore;
      _page = 1;
    } catch (e) {
      if (generation != _generation) return;
      _error = ApiError.from(e).message;
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
    unawaited(_loadExtras(generation));
  }

  Future<void> _loadExtras(int generation) async {
    final query = _filters.search;
    if (query.isEmpty || _filters.savedOnly) {
      if (_extras.isEmpty) return;
      _extras = SearchExtras.none;
      notifyListeners();
      return;
    }
    try {
      final extras = await repository.searchExtras(query);
      if (generation != _generation) return;
      _extras = extras;
      notifyListeners();
    } catch (_) {
      // The suppliers are the answer; the extras are a courtesy.
    }
  }

  Future<void> _loadSide() async {
    await Future.wait([
      repository.savedIds().then((ids) => _saved = ids).catchError((_) => _saved),
      (_countsSource?.call() ?? repository.counts()).then((c) => _counts = c).catchError((_) => _counts),
      repository.unreadNotifications().then((n) => _unread = n).catchError((_) => _unread),
    ]);
    notifyListeners();
  }

  /// Reads which suppliers the member has bookmarked: all a profile opened from
  /// outside the Marketplace needs of the list's state.
  Future<void> loadSavedIds() async {
    try {
      _saved = await repository.savedIds();
    } catch (_) {
      // The bookmark simply starts unmarked.
    }
    notifyListeners();
  }

  /// "Load more suppliers".
  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    _loadingMore = true;
    notifyListeners();
    final generation = _generation;
    try {
      final next = _page + 1;
      final page = _filters.savedOnly
          ? await repository.savedSuppliers(page: next)
          : await repository.suppliers(_filters, page: next);
      if (generation != _generation) return;
      final have = {for (final s in _suppliers) s.id};
      _suppliers = [..._suppliers, ...page.suppliers.where((s) => !have.contains(s.id))];
      _total = page.total;
      _hasMore = page.hasMore;
      _page = next;
    } catch (_) {
      // The next "Load more suppliers" tries again.
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  // ---- Search and filters --------------------------------------------------------------------

  Future<void> setSearch(String query) async {
    final text = query.trim();
    if (text == _filters.search) return;
    _filters = _filters.copyWith(search: text);
    await _loadList(notify: true);
  }

  Future<void> setFilters(MarketplaceFilters filters) async {
    if (filters == _filters) return;
    _filters = filters;
    await _loadList(notify: true);
  }

  Future<void> setSort(SupplierSort sort) => setFilters(_filters.copyWith(sort: sort));

  Future<void> setMinRating(double? rating) =>
      setFilters(rating == null ? _filters.copyWith(clearRating: true) : _filters.copyWith(minRating: rating));

  /// "Verified only": the trust ladder from Verified up, or every supplier.
  Future<void> toggleVerifiedOnly() => setFilters(
    _filters.verifiedOnly ? _filters.copyWith(clearLevel: true) : _filters.copyWith(minLevel: SupplierLevel.verified),
  );

  /// Clears what the Filters sheet set, the search and the rating; the order
  /// and "Verified only" stay.
  Future<void> clearFilters() => setFilters(
    MarketplaceFilters(sort: _filters.sort, minLevel: _filters.verifiedOnly ? SupplierLevel.verified : null),
  );

  // ---- Suggestions while typing ----------------------------------------------------------------

  /// Remembers a search the member made, newest first.
  void rememberSearch(String query) {
    final text = query.trim();
    if (text.isEmpty) return;
    _recent
      ..remove(text)
      ..insert(0, text);
    if (_recent.length > 6) _recent.removeRange(6, _recent.length);
    notifyListeners();
  }

  /// Reads the suppliers whose name (or headline, or category) matches [query]: the
  /// live matches the website's search box offers once two characters are typed.
  /// An answer for words that are no longer in the box is dropped.
  Future<void> suggest(String query) async {
    final text = query.trim();
    final generation = ++_suggestGeneration;
    if (text.length < 2) {
      if (_suggestedSuppliers.isNotEmpty || _suggestedFor.isNotEmpty) {
        _suggestedSuppliers = const [];
        _suggestedFor = '';
        notifyListeners();
      }
      return;
    }
    try {
      final page = await repository.suppliers(MarketplaceFilters(search: text, minLevel: _filters.minLevel));
      if (generation != _suggestGeneration) return;
      _suggestedSuppliers = page.suppliers.take(5).toList();
      _suggestedFor = text;
      notifyListeners();
    } catch (_) {
      // A suggestion is a courtesy: the search itself says what went wrong.
    }
  }

  /// The categories (top level and below) whose name has [query] in it, at most four.
  List<({CategoryNode node, String? parent})> suggestedCategories(String query) {
    final q = query.trim().toLowerCase();
    final tree = _tree;
    if (q.length < 2 || tree == null) return const [];
    final out = <({CategoryNode node, String? parent})>[];
    for (final top in tree) {
      if (top.name.toLowerCase().contains(q)) out.add((node: top, parent: null));
      for (final child in top.children) {
        if (child.name.toLowerCase().contains(q)) out.add((node: child, parent: top.name));
      }
    }
    return out.take(4).toList();
  }

  // ---- Lookups the sheets need -------------------------------------------------------------------

  Future<List<CategoryNode>> loadCategories() async {
    final cached = _tree;
    if (cached != null) return cached;
    return _treeLoad ??= () async {
      try {
        final tree = await repository.categories();
        void index(List<CategoryNode> nodes) {
          for (final n in nodes) {
            _names[n.key] = n.name;
            index(n.children);
          }
        }

        index(tree);
        _tree = tree;
        notifyListeners();
        return tree;
      } catch (_) {
        return const <CategoryNode>[];
      } finally {
        _treeLoad = null;
      }
    }();
  }

  Future<List<String>> loadCities() async {
    final cached = _cities;
    if (cached != null && cached.isNotEmpty) return cached;
    try {
      final cities = await repository.cities();
      _cities = cities;
      notifyListeners();
      return cities;
    } catch (_) {
      // The sheet says there is nothing to pick from; opening it again tries again.
      _cities = const [];
      notifyListeners();
      return const [];
    }
  }

  /// A taxonomy key as people read it: its name from the tree, else the key
  /// set in sentence case.
  String categoryName(String key) => _names[key] ?? prettyKey(key);

  // ---- Bookmarks -------------------------------------------------------------------------------------

  /// Bookmarks the supplier, or takes the bookmark back; a sentence when the
  /// API refuses.
  Future<String?> toggleSave(String id) async {
    final saved = !_saved.contains(id);
    _setSavedLocally(id, saved);
    notifyListeners();
    try {
      await repository.setSaved(id, saved);
      return null;
    } catch (e) {
      _setSavedLocally(id, !saved);
      notifyListeners();
      return ApiError.from(e).message;
    }
  }

  /// The profile sheet saved or unsaved a supplier: keep the list in step.
  void markSaved(String id, bool saved) {
    _setSavedLocally(id, saved);
    notifyListeners();
  }

  void _setSavedLocally(String id, bool saved) {
    _saved = saved ? {..._saved, id} : ({..._saved}..remove(id));
    if (!saved && _filters.savedOnly) {
      final before = _suppliers.length;
      _suppliers = _suppliers.where((s) => s.id != id).toList();
      if (_suppliers.length != before && _total > 0) _total -= 1;
    }
  }

  /// The profile read the full listing: the card keeps the rating it shows.
  void updateSupplier(Supplier supplier) {
    final i = _suppliers.indexWhere((s) => s.id == supplier.id);
    if (i < 0) return;
    _suppliers = [..._suppliers]..[i] = supplier.copyWith(brandColor: _suppliers[i].brandColor);
    notifyListeners();
  }
}

/// "PEST_CONTROL" as "Pest control".
String prettyKey(String key) {
  final words = key.toLowerCase().split('_').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return key;
  final text = words.join(' ');
  return '${text[0].toUpperCase()}${text.substring(1)}';
}
