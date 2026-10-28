import 'package:flutter/foundation.dart';

import '../../../core/api/api_error.dart';
import 'saved_models.dart';
import 'saved_repository.dart';

/// Where one kind's list stands.
enum SavedStatus {
  /// Nothing has answered yet.
  loading,
  loaded,

  /// The read failed; [SavedSection.error] says why and there is a Try again.
  failed,

  /// The API refuses this kind to the account (a 403), so the chip is not drawn.
  unavailable,
}

/// One kind's bookmarks. A section fails on its own: one kind erroring never
/// blanks the others.
class SavedSection {
  SavedStatus status = SavedStatus.loading;
  List<SavedItem> items = const [];

  /// The member's count for the kind, as the API reports it (the chip's number).
  int total = 0;
  bool hasNext = false;
  bool loadingMore = false;

  /// Why the read failed ([SavedStatus.failed]).
  String? error;

  /// Why "Show more" failed; the rows already read stay.
  String? moreError;

  /// A read that replaces the rows is running (pull to refresh); they stay on screen meanwhile.
  bool refreshing = false;

  int _generation = 0;

  bool get isEmpty => status == SavedStatus.loaded && items.isEmpty && !hasNext;
}

/// What an un-save did, for the snackbar.
class SavedRemoval {
  const SavedRemoval({required this.item, required this.index, this.error});

  final SavedItem item;

  /// Where the row stood, so Undo puts it back there.
  final int index;

  /// The API's sentence when it refused; the row is back in place already.
  final String? error;

  bool get ok => error == null;
}

/// The Saved items screen's state: the five kinds of bookmark, the chip the
/// member is on, and the optimistic un-save with its Undo.
class SavedController extends ChangeNotifier {
  SavedController(this.repository, {SavedKind initial = SavedKind.jobs}) : _selected = initial;

  final SavedRepository repository;
  final Map<SavedKind, SavedSection> _sections = {for (final k in SavedKind.values) k: SavedSection()};
  final Set<String> _busy = {};
  SavedKind _selected;
  bool _started = false;
  bool _disposed = false;

  bool get started => _started;
  SavedKind get selected => _selected;
  SavedSection section(SavedKind kind) => _sections[kind]!;
  SavedSection get current => section(_selected);

  /// The chips to draw: every kind the account may hold.
  List<SavedKind> get kinds => [
    for (final k in SavedKind.values)
      if (section(k).status != SavedStatus.unavailable) k,
  ];

  /// Every kind failed with a refusal: there is nothing to save here.
  bool get nothingAvailable => kinds.isEmpty;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Reads every kind at once, so each chip has its count.
  Future<void> start() {
    _started = true;
    return Future.wait([for (final k in SavedKind.values) load(k)]);
  }

  void select(SavedKind kind) {
    if (_selected == kind || section(kind).status == SavedStatus.unavailable) return;
    _selected = kind;
    _notify();
  }

  /// The first read of [kind], or its Try again.
  Future<void> load(SavedKind kind) async {
    final s = section(kind);
    final generation = ++s._generation;
    s
      ..status = SavedStatus.loading
      ..error = null
      ..moreError = null
      ..loadingMore = false;
    _notify();
    try {
      final page = await repository.load(kind);
      if (generation != s._generation) return;
      _fill(s, page);
    } on ApiError catch (e) {
      if (generation != s._generation) return;
      _fail(kind, s, e);
    } catch (e) {
      if (generation != s._generation) return;
      _fail(kind, s, ApiError.from(e));
    }
    _notify();
  }

  void _fill(SavedSection s, SavedPage page) {
    s
      ..status = SavedStatus.loaded
      ..items = page.items
      ..total = page.total
      ..hasNext = page.hasNext
      ..error = null
      ..moreError = null;
  }

  void _fail(SavedKind kind, SavedSection s, ApiError e) {
    if (e.statusCode == 403) {
      s.status = SavedStatus.unavailable;
      if (_selected == kind) {
        final rest = kinds;
        if (rest.isNotEmpty) _selected = rest.first;
      }
    } else {
      s
        ..status = SavedStatus.failed
        ..error = e.message;
    }
  }

  /// Reads [kind] again for a pull to refresh. The rows stay while it runs;
  /// when it fails and there are rows, they stay and the sentence is returned.
  Future<String?> refresh(SavedKind kind) async {
    final s = section(kind);
    if (s.status == SavedStatus.failed || s.status == SavedStatus.loading) {
      await load(kind);
      return null;
    }
    final generation = ++s._generation;
    s
      ..refreshing = true
      ..loadingMore = false;
    _notify();
    String? message;
    try {
      final page = await repository.load(kind);
      if (generation != s._generation) return null;
      _fill(s, page);
    } catch (e) {
      if (generation != s._generation) return null;
      final error = ApiError.from(e);
      if (error.statusCode == 403) {
        _fail(kind, s, error);
      } else {
        message = error.message;
      }
    }
    s.refreshing = false;
    _notify();
    return message;
  }

  /// "Show more": the rows after the ones held. The page asked for is the one
  /// the next row falls on, and rows already held are dropped from the answer, so
  /// an un-save in between (which moves every later row up one place) never
  /// makes a row skip.
  Future<void> loadMore(SavedKind kind) async {
    final s = section(kind);
    if (s.loadingMore || !s.hasNext || s.status != SavedStatus.loaded) return;
    final generation = s._generation;
    s
      ..loadingMore = true
      ..moreError = null;
    _notify();
    try {
      final page = await repository.load(kind, page: s.items.length ~/ SavedRepository.pageSize + 1);
      if (generation != s._generation) return;
      final held = {for (final i in s.items) i.id};
      final fresh = [
        for (final i in page.items)
          if (!held.contains(i.id)) i,
      ];
      s
        ..items = [...s.items, ...fresh]
        ..total = page.total
        // An answer with nothing new in it is the end, whatever it claims.
        ..hasNext = fresh.isNotEmpty && page.hasNext;
    } catch (e) {
      if (generation != s._generation) return;
      s.moreError = ApiError.from(e).message;
    }
    s.loadingMore = false;
    _notify();
  }

  String _key(SavedItem item) => '${item.kind.name}:${item.id}';

  bool isBusy(SavedItem item) => _busy.contains(_key(item));

  /// Takes the bookmark off [item]: the row leaves at once and comes back, with
  /// the API's sentence, if the API refuses. Null when this item is already
  /// being changed.
  Future<SavedRemoval?> unsave(SavedItem item) async {
    final s = section(item.kind);
    final index = s.items.indexWhere((i) => i.id == item.id);
    if (index < 0 || !_busy.add(_key(item))) return null;
    s.items = [...s.items]..removeAt(index);
    s.total = s.total > 0 ? s.total - 1 : 0;
    _notify();
    try {
      await repository.unsave(item);
    } catch (e) {
      _busy.remove(_key(item));
      _insert(s, item, index);
      _notify();
      return SavedRemoval(item: item, index: index, error: ApiError.from(e).message);
    }
    _busy.remove(_key(item));
    // Every row of a page gone while more follow: read the next page, so the list
    // is never "empty" with bookmarks still to show.
    if (s.items.isEmpty && s.hasNext) {
      _notify();
      await loadMore(item.kind);
    }
    _notify();
    return SavedRemoval(item: item, index: index);
  }

  /// Undo: saves [item] again and puts the row back where it stood. Returns the
  /// API's sentence when it refuses (a job that closed since cannot be saved).
  Future<String?> restore(SavedItem item, int index) async {
    final s = section(item.kind);
    if (!_busy.add(_key(item))) return null;
    try {
      await repository.save(item);
    } catch (e) {
      _busy.remove(_key(item));
      return ApiError.from(e).message;
    }
    _busy.remove(_key(item));
    if (!s.items.any((i) => i.id == item.id)) {
      _insert(s, item, index);
      _notify();
    }
    return null;
  }

  void _insert(SavedSection s, SavedItem item, int index) {
    if (s.items.any((i) => i.id == item.id)) return;
    s.items = [...s.items]..insert(index.clamp(0, s.items.length), item);
    s.total = s.total + 1;
  }
}
