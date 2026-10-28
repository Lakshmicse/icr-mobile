import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'catalog_models.dart';
import 'marketplace_repository.dart';

/// What a catalogue board lists.
enum CatalogKind {
  products('Products'),
  services('Services');

  const CatalogKind(this.label);

  final String label;
}

/// A catalogue board's state: the products (or services) of the marketplace,
/// narrowed by words and by a category, a page at a time (`GET /products`,
/// `GET /services`).
///
/// A category narrows a product by its slug (`categorySlug`, the API reads the
/// category and the ones under it) and a service by its taxonomy key (`category`).
class CatalogBoardController extends ChangeNotifier {
  CatalogBoardController({required this.repository, required this.kind, this.categoryKey, this.categorySlug});

  final MarketplaceRepository repository;
  final CatalogKind kind;
  final String? categoryKey;
  final String? categorySlug;

  String _search = '';
  List<Object> _items = const [];
  int _total = 0;
  int _page = 1;
  bool _hasMore = false;
  bool _loading = false;
  bool _loadingMore = false;
  bool _started = false;
  String? _error;
  int _generation = 0;
  bool _disposed = false;

  String get search => _search;

  /// [CatalogProduct]s or [CatalogService]s, by [kind].
  List<Object> get items => _items;
  int get total => _total;
  bool get hasMore => _hasMore;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get started => _started;
  String? get error => _error;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<({List<Object> rows, int total, bool more})> _read(int page) async {
    switch (kind) {
      case CatalogKind.products:
        final r = await repository.products(categorySlug: categorySlug, search: _search, page: page);
        return (rows: List<Object>.of(r.items), total: r.total, more: r.hasMore);
      case CatalogKind.services:
        final r = await repository.services(category: categoryKey, search: _search, page: page);
        return (rows: List<Object>.of(r.items), total: r.total, more: r.hasMore);
    }
  }

  Future<void> start() async {
    _started = true;
    await refresh();
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    _notify();
    try {
      final page = await _read(1);
      if (generation != _generation) return;
      _items = page.rows;
      _total = page.total;
      _hasMore = page.more;
      _page = 1;
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

  Future<void> setSearch(String words) async {
    final text = words.trim();
    if (text == _search) return;
    _search = text;
    await refresh();
  }

  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    _loadingMore = true;
    _notify();
    final generation = _generation;
    try {
      final next = _page + 1;
      final page = await _read(next);
      if (generation != _generation) return;
      final have = {for (final i in _items) _idOf(i)};
      _items = [..._items, ...page.rows.where((i) => !have.contains(_idOf(i)))];
      _total = page.total;
      _hasMore = page.more;
      _page = next;
    } catch (_) {
      // The next "Load more" tries again.
    } finally {
      _loadingMore = false;
      _notify();
    }
  }

  static String _idOf(Object item) => item is CatalogProduct ? item.id : (item as CatalogService).id;
}
