import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'library_models.dart';
import 'library_repository.dart';

/// The Digital Library list's state: the documents the query narrows to, a page at a time, the filter
/// chips' facets (categories and formats in use), the tiles' numbers, and the member's own uploads.
/// The query's parts are the API's parameters, so every change reads the first page again (a stale
/// answer is dropped by a generation count).
class LibraryController extends ChangeNotifier {
  LibraryController(this.repository, {LibraryQuery initial = const LibraryQuery()}) : _query = initial;

  final LibraryRepository repository;

  LibraryQuery _query;
  List<LibraryDocument> _documents = const [];
  int _total = 0;
  bool _hasNext = false;
  bool _started = false;
  bool _loading = false;
  bool _loadingMore = false;
  bool _disposed = false;
  String? _error;
  String? _moreError;
  int _generation = 0;
  int _unread = 0;

  List<String> _categories = const [];
  List<FileTypeFacet> _fileTypes = const [];
  int? _libraryTotal;
  int _mine = 0;
  LibraryViewer? _viewer;

  LibraryQuery get query => _query;
  bool get started => _started;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  String? get error => _error;

  /// A "Show more" that failed (the documents already read stay).
  String? get moreError => _moreError;
  int get unread => _unread;

  /// The documents read so far for the query.
  List<LibraryDocument> get documents => _documents;

  /// How many documents match the query (the API's `meta.total`).
  int get total => _total;
  bool get hasNext => _hasNext;
  List<String> get categories => _categories;
  List<FileTypeFacet> get fileTypes => _fileTypes;

  /// The whole library's size, read while no filter is on (null until it has been).
  int? get libraryTotal => _libraryTotal;

  /// How many documents the member shared.
  int get myUploads => _mine;
  LibraryViewer? get viewer => _viewer;

  bool get filtered => _query.filtered;

  /// The kind chip the search currently equals, if any.
  LibraryKind? get activeKind {
    final s = _query.search.trim().toLowerCase();
    for (final k in libraryKinds) {
      if (k.term.toLowerCase() == s) return k;
    }
    return null;
  }

  Future<void> start() async {
    _started = true;
    await Future.wait([_load(notify: false), _loadFacets(), _loadUnread()]);
  }

  /// Pull to refresh: the list, the facets and the bell again.
  Future<void> refresh() => Future.wait([_load(notify: true), _loadFacets(), _loadUnread()]);

  Future<void> _load({required bool notify}) async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    _moreError = null;
    if (notify) _notify();
    try {
      final page = await repository.documents(_query.copyWith(page: 1));
      if (generation != _generation) return;
      _documents = page.documents;
      _total = page.total;
      _hasNext = page.hasNext;
      _query = _query.copyWith(page: 1);
      if (!_query.filtered) _libraryTotal = page.total;
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

  /// Categories, formats, the member's own count and who they are. The chips are a nicety: a failure
  /// leaves the old ones.
  Future<void> _loadFacets() async {
    await Future.wait([
      () async {
        try {
          _categories = await repository.categories();
        } catch (_) {}
      }(),
      () async {
        try {
          _fileTypes = await repository.fileTypes();
        } catch (_) {}
      }(),
      () async {
        try {
          _mine = await repository.myUploadCount();
        } catch (_) {}
      }(),
      () async {
        try {
          _viewer = await repository.viewer();
        } catch (_) {}
      }(),
    ]);
    _notify();
  }

  Future<void> _loadUnread() async {
    try {
      _unread = await repository.unreadNotifications();
      _notify();
    } catch (_) {}
  }

  // --- the query ------------------------------------------------------------

  void _change(LibraryQuery next) {
    _query = next;
    _load(notify: true);
  }

  void setSearch(String text) {
    final t = text.trim();
    if (t == _query.search) return;
    _change(_query.copyWith(search: t, page: 1));
  }

  void setCategory(String? category) {
    if (category == _query.category) return;
    _change(
      category == null ? _query.copyWith(clearCategory: true, page: 1) : _query.copyWith(category: category, page: 1),
    );
  }

  void setFileType(LibraryFileType? type) {
    if (type == _query.fileType) return;
    _change(type == null ? _query.copyWith(clearFileType: true, page: 1) : _query.copyWith(fileType: type, page: 1));
  }

  void setMine(bool mine) {
    if (mine == _query.mine) return;
    _change(_query.copyWith(mine: mine, page: 1));
  }

  void setSort(LibrarySort sort) {
    if (sort == _query.sort) return;
    _change(_query.copyWith(sort: sort, page: 1));
  }

  /// A kind chip: types its word into the search; the same chip again takes it out.
  void toggleKind(LibraryKind kind) {
    if (activeKind == kind) return setSearch('');
    setSearch(kind.term);
  }

  void clearFilters() {
    _change(LibraryQuery(sort: _query.sort, limit: _query.limit));
  }

  /// "Show more documents": the next page appended.
  Future<void> loadMore() async {
    if (!_hasNext || _loadingMore || _loading) return;
    _loadingMore = true;
    _moreError = null;
    _notify();
    final generation = _generation;
    try {
      final page = await repository.documents(_query.copyWith(page: _query.page + 1));
      if (generation != _generation) return;
      final seen = {for (final d in _documents) d.id};
      _documents = [
        ..._documents,
        for (final d in page.documents)
          if (!seen.contains(d.id)) d,
      ];
      _total = page.total;
      _hasNext = page.hasNext;
      _query = _query.copyWith(page: page.page);
    } catch (e) {
      if (generation != _generation) return;
      _moreError = ApiError.from(e).message;
    } finally {
      _loadingMore = false;
      _notify();
    }
  }

  // --- changes made on a document's page ---------------------------------------

  /// A document's page changed it (a view, a download, a file added or dropped): the list follows.
  void documentChanged(LibraryDocument changed) {
    _documents = [for (final d in _documents) d.id == changed.id ? changed : d];
    _notify();
  }

  /// A document was deleted on its page.
  void documentRemoved(String id) {
    final had = _documents.any((d) => d.id == id);
    _documents = [
      for (final d in _documents)
        if (d.id != id) d,
    ];
    if (had) _total = (_total - 1).clamp(0, 1 << 30);
    if (_libraryTotal != null) _libraryTotal = (_libraryTotal! - 1).clamp(0, 1 << 30);
    _mine = (_mine - 1).clamp(0, 1 << 30);
    _notify();
  }

  /// A document was shared: the list and the facets are read again (it may open a new category or format).
  Future<void> documentAdded() => Future.wait([_load(notify: true), _loadFacets()]);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
