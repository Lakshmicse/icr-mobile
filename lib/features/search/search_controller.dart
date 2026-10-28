import 'dart:async';

import 'package:flutter/foundation.dart';

import 'feature_catalogue.dart';
import 'recent_searches.dart';
import 'search_models.dart';

/// The global search: one query fanned out over every [SearchSource] in
/// parallel, each answering (or failing) on its own, plus the app's own
/// features matched by keyword.
///
/// What it holds for the screen: the text, the chip chosen ([scope], null for
/// All), a [SearchGroup] per source, and the recent searches. What it spends:
/// at most one request per source per query. A burst of typing waits
/// [debounce] after the last key, an answer for an older query is dropped, and
/// switching chips reads nothing the query already has. The API allows 120
/// requests a minute per address, so below [minChars] nothing is asked.
class GlobalSearchController extends ChangeNotifier {
  GlobalSearchController({
    required List<SearchSource> sources,
    Set<String>? availableFeatures,
    RecentSearches? recents,
    this.debounce = const Duration(milliseconds: 300),
    this.minChars = 2,
    this.allLimit = 4,
  }) : _sources = {for (final s in sources) s.kind: s},
       _available = availableFeatures,
       recents = recents ?? RecentSearches(MemoryRecentStore()),
       _groups = {for (final s in sources) s.kind: SearchGroup(s.kind)};

  /// How long typing must pause before the sources are asked.
  final Duration debounce;

  /// The fewest characters that reach the API (features match from one).
  final int minChars;

  /// How many hits a group shows on the All chip before "See all".
  final int allLimit;

  final RecentSearches recents;
  final Map<SearchKind, SearchSource> _sources;
  final Set<String>? _available;
  final Map<SearchKind, SearchGroup> _groups;

  String _query = '';
  SearchKind? _scope;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;

  String get query => _query;
  String get trimmed => _query.trim();

  /// The chip chosen; null is All.
  SearchKind? get scope => _scope;

  bool get isIdle => trimmed.isEmpty;

  /// Long enough to ask the API.
  bool get asks => trimmed.length >= minChars;

  Iterable<SearchKind> get kinds => _sources.keys;

  /// The chips that have something to show: every source, and the app's
  /// features when the query is about one.
  List<SearchKind> get chips => [
    for (final k in SearchKind.chips)
      if (k == SearchKind.feature ? _hasFeatures : _sources.containsKey(k)) k,
  ];

  bool get _hasFeatures => _available == null || _available.isNotEmpty;

  /// The features the query is about, best first.
  List<FeatureMatch> get featureMatches =>
      trimmed.isEmpty ? const [] : matchFeatures(trimmed, available: _available, limit: 8);

  /// Offered before anything is typed.
  List<AppFeature> get suggestions => suggestedFeatures(available: _available);

  SearchGroup groupOf(SearchKind kind) => _groups[kind] ?? SearchGroup(kind);

  bool get anyLoading => _groups.values.any((g) => g.status == GroupStatus.loading);

  /// Every source that was asked for this query failed, and there is nothing
  /// else to show: the connection is down, not the query empty.
  bool get offline =>
      asks &&
      !anyLoading &&
      _askedKinds.isNotEmpty &&
      _askedKinds.every((k) => groupOf(k).status == GroupStatus.failed) &&
      featureMatches.isEmpty;

  /// Nothing found anywhere for a query long enough to ask.
  bool get noResults => asks && !anyLoading && !offline && !hasResults;

  bool get hasResults =>
      featureMatches.isNotEmpty || _groups.values.any((g) => g.query == trimmed && g.hits.isNotEmpty);

  /// The sources the chosen chip needs: all of them on All, one on a kind, none
  /// on the app's own features (those are matched on the device).
  Iterable<SearchKind> get _askedKinds {
    final scope = _scope;
    if (scope == null) return _sources.keys;
    return _sources.containsKey(scope) ? [scope] : const <SearchKind>[];
  }

  /// The groups the All chip lists, in the order they are drawn: the app's own
  /// features lead when one is named by the query (a "jobs" or "plans" search
  /// wants the page before the people who mention it), then people, jobs and
  /// the rest. A group is listed while it has hits or is still loading; a failed
  /// or empty one is left out.
  List<SearchKind> get allOrder {
    final features = featureMatches;
    final featureFirst = features.isNotEmpty && features.first.strong;
    final order = <SearchKind>[
      if (featureFirst && features.isNotEmpty) SearchKind.feature,
      SearchKind.person,
      SearchKind.job,
      SearchKind.mentor,
      SearchKind.course,
      SearchKind.supplier,
      SearchKind.event,
      SearchKind.discussion,
      SearchKind.document,
      if (!featureFirst && features.isNotEmpty) SearchKind.feature,
    ];
    return [
      for (final k in order)
        if (k == SearchKind.feature || _showsInAll(k)) k,
    ];
  }

  /// A group stays listed with its last hits while the next answer loads, so the
  /// page does not blank between keystrokes.
  bool _showsInAll(SearchKind k) {
    final g = _groups[k];
    if (g == null) return false;
    return g.status == GroupStatus.loading || g.hits.isNotEmpty;
  }

  /// The text changed. Waits for a pause, then asks.
  void setQuery(String text) {
    if (text == _query) return;
    _query = text;
    _timer?.cancel();
    _generation++;
    if (!asks) {
      _clearGroups();
      _notify();
      return;
    }
    _notify();
    _timer = Timer(debounce, _run);
  }

  // `_generation` counts queries, not requests: an answer is kept while it still
  // belongs to the text on screen, so a chip tap never strands a source mid-way.

  /// The person pressed the keyboard's search key: ask now and remember it.
  void submit() {
    _timer?.cancel();
    if (!asks) return;
    unawaited(recents.add(trimmed).then((_) => _notify()));
    if (_needsFetch().isNotEmpty) _run();
  }

  /// A chip tapped; null is All. Reads only what the query has not.
  void setScope(SearchKind? kind) {
    if (_scope == kind) return;
    _scope = kind;
    _notify();
    if (asks && _timer?.isActive != true) _run();
  }

  /// "Show more" on one group: the next page of the same source.
  Future<void> more(SearchKind kind) async {
    final source = _sources[kind];
    final g = _groups[kind];
    if (source == null || g == null || !g.hasMore || g.loadingMore || g.query != trimmed) return;
    final gen = _generation;
    final q = trimmed;
    _groups[kind] = g.copyWith(loadingMore: true);
    _notify();
    try {
      final page = await source.search(q, page: g.page + 1);
      if (gen != _generation) return;
      final seen = {for (final h in g.hits) h.key};
      _groups[kind] = g.copyWith(
        hits: [...g.hits, ...page.hits.where((h) => !seen.contains(h.key))],
        hasMore: page.hasMore,
        page: g.page + 1,
        loadingMore: false,
      );
    } catch (_) {
      if (gen != _generation) return;
      _groups[kind] = g.copyWith(loadingMore: false);
    }
    _notify();
  }

  /// Asks the failed sources again.
  void retry() {
    if (!asks) return;
    for (final k in _askedKinds) {
      final g = _groups[k];
      if (g != null && g.status == GroupStatus.failed) _groups[k] = g.copyWith(status: GroupStatus.idle, query: '');
    }
    _run();
  }

  Future<void> loadRecents() async {
    await recents.load();
    _notify();
  }

  Future<void> removeRecent(String query) async {
    await recents.remove(query);
    _notify();
  }

  Future<void> clearRecents() async {
    await recents.clear();
    _notify();
  }

  /// A hit was opened: the query that found it is worth keeping.
  void opened() {
    if (asks) unawaited(recents.add(trimmed).then((_) => _notify()));
  }

  // --- the work ---------------------------------------------------------

  /// The sources the query still has to ask: those on screen under the chosen
  /// chip that have not answered it.
  List<SearchKind> _needsFetch() => [
    for (final k in _askedKinds)
      if (_groups[k]!.query != trimmed || _groups[k]!.status == GroupStatus.idle) k,
  ];

  void _run() {
    if (!asks) return;
    final q = trimmed;
    final gen = _generation;
    for (final kind in _needsFetch()) {
      final source = _sources[kind]!;
      _groups[kind] = SearchGroup(kind, status: GroupStatus.loading, query: q, hits: _groups[kind]!.hits);
      source.search(q).then(
        (page) {
          if (gen != _generation) return;
          _groups[kind] = SearchGroup(
            kind,
            status: GroupStatus.done,
            hits: page.hits,
            hasMore: page.hasMore,
            page: 1,
            query: q,
          );
          _notify();
        },
        onError: (Object _) {
          if (gen != _generation) return;
          _groups[kind] = SearchGroup(kind, status: GroupStatus.failed, query: q);
          _notify();
        },
      );
    }
    _notify();
  }

  void _clearGroups() {
    for (final k in _groups.keys.toList()) {
      _groups[k] = SearchGroup(k);
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
