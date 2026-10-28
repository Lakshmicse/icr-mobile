import 'package:flutter/material.dart';

import 'recent_searches.dart';
import 'search_controller.dart';
import 'search_models.dart';
import 'search_styles.dart';
import 'search_widgets.dart';

/// Opens a record a search found (a job, a mentor, a discussion...), over the
/// screen that opened the search, the way that screen would open it.
typedef SearchOpener = Future<void> Function(BuildContext context, SearchHit hit);

/// Opens one of the app's own places by its catalogue id.
typedef FeatureOpener = Future<void> Function(BuildContext context);

/// What the app wires into the search once, because the search does not import
/// the features it opens (`lib/app_search.dart` builds it; `lib/app.dart` sets
/// [current]).
class SearchEnvironment {
  const SearchEnvironment({required this.sources, required this.openers, required this.features, this.recents});

  /// The sources to ask, built for the context the search was opened from (the
  /// shell's, so the providers the repositories read are in reach).
  final List<SearchSource> Function(BuildContext context) sources;

  /// A record's opener per kind.
  final Map<SearchKind, SearchOpener> openers;

  /// The features the app can open, by catalogue id. A feature with no entry is
  /// never offered.
  final Map<String, FeatureOpener> features;

  /// Where the recent searches are kept; in memory when null.
  final RecentStore Function(BuildContext context)? recents;

  /// The app's, set once the signed-in app is built.
  static SearchEnvironment? current;
}

/// Opens the global search over [context]'s screen. [query] is typed in already
/// (a tag tapped on a post, a chip's words).
Future<void> openGlobalSearch(BuildContext context, {String? query}) {
  final env = SearchEnvironment.current;
  if (env == null) return Future.value();
  final controller = GlobalSearchController(
    sources: env.sources(context),
    availableFeatures: env.features.keys.toSet(),
    recents: RecentSearches(env.recents?.call(context) ?? MemoryRecentStore()),
  );
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => SearchScreen(
        controller: controller,
        ownsController: true,
        initialQuery: query,
        onOpenHit: (hit) async {
          final open = env.openers[hit.kind];
          if (open != null && context.mounted) await open(context, hit);
        },
        onOpenFeature: (id) async {
          final open = env.features[id];
          if (open != null && context.mounted) await open(context);
        },
      ),
    ),
  );
}

/// The search page: a back arrow and a field, a chip per kind of result, and
/// below them either the recent searches (nothing typed yet) or what the query
/// found, grouped by kind.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.controller,
    required this.onOpenHit,
    required this.onOpenFeature,
    this.initialQuery,
    this.ownsController = false,
    this.onBack,
  });

  final GlobalSearchController controller;
  final Future<void> Function(SearchHit hit) onOpenHit;
  final Future<void> Function(String featureId) onOpenFeature;
  final String? initialQuery;

  /// The screen disposes the controller (the one [openGlobalSearch] makes).
  final bool ownsController;
  final VoidCallback? onBack;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _text = TextEditingController(text: widget.initialQuery ?? '');
  final _focus = FocusNode();
  final _scroll = ScrollController();

  GlobalSearchController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.loadRecents();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) _c.setQuery(widget.initialQuery!);
    _scroll.addListener(_nearEnd);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _text.dispose();
    _focus.dispose();
    if (widget.ownsController) _c.dispose();
    super.dispose();
  }

  /// On a single chip, the next page when the list is nearly out.
  void _nearEnd() {
    final scope = _c.scope;
    if (scope == null || !_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 400) _c.more(scope);
  }

  void _type(String text) => _c.setQuery(text);

  void _useRecent(String q) {
    _text.value = TextEditingValue(text: q, selection: TextSelection.collapsed(offset: q.length));
    _c.setQuery(q);
    _c.submit();
  }

  void _clear() {
    _text.clear();
    _c.setQuery('');
    _focus.requestFocus();
  }

  Future<void> _open(SearchHit hit) async {
    _focus.unfocus();
    if (hit.kind == SearchKind.feature) {
      await widget.onOpenFeature(hit.id);
    } else {
      _c.opened();
      await widget.onOpenHit(hit);
    }
  }

  Future<void> _openFeature(String id) {
    _focus.unfocus();
    return widget.onOpenFeature(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _c,
          builder: (context, _) => Column(
            children: [
              _SearchField(
                controller: _text,
                focus: _focus,
                onChanged: _type,
                onSubmit: () {
                  _c.submit();
                  _focus.unfocus();
                },
                onClear: _clear,
                onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
                showClear: _c.query.isNotEmpty,
              ),
              if (!_c.isIdle) _ChipRow(controller: _c),
              SizedBox(
                height: 2,
                child: _c.anyLoading
                    ? const LinearProgressIndicator(minHeight: 2, color: SearchLook.blue, backgroundColor: Colors.transparent)
                    : const Divider(height: 1, thickness: 1, color: SearchLook.hairline),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_c.isIdle) return _Idle(controller: _c, onRecent: _useRecent, onFeature: _openFeature);
    if (_c.offline) return _Offline(onRetry: _c.retry);
    if (_c.noResults) return _NoResults(query: _c.trimmed, onFeature: _openFeature, controller: _c);

    final scope = _c.scope;
    return scope == null ? _allList() : _scopedList(scope);
  }

  // --- the All chip ------------------------------------------------------

  Widget _allList() {
    final order = _c.allOrder;
    final children = <Widget>[];
    for (final kind in order) {
      final hits = _hitsOf(kind);
      if (hits.isEmpty) continue;
      final shown = hits.take(_c.allLimit).toList();
      final more = kind == SearchKind.feature ? hits.length > _c.allLimit : (hits.length > _c.allLimit || _c.groupOf(kind).hasMore);
      if (children.isNotEmpty) children.add(const GroupRule());
      children.add(GroupHeader(kind));
      for (final h in shown) {
        children.add(HitRow(key: ValueKey(h.key), hit: h, onTap: () => _open(h)));
      }
      if (more) children.add(SeeAllRow(kind: kind, onTap: () => _c.setScope(kind)));
    }
    if (children.isEmpty) {
      // Asked, nothing back yet.
      return const SingleChildScrollView(child: SkeletonRows(count: 5));
    }
    return ListView(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 24),
      children: children,
    );
  }

  // --- one chip -----------------------------------------------------------

  Widget _scopedList(SearchKind kind) {
    final hits = _hitsOf(kind);
    final g = _c.groupOf(kind);
    if (hits.isEmpty) {
      if (g.status == GroupStatus.failed) return _Offline(onRetry: _c.retry);
      if (g.status == GroupStatus.loading || g.status == GroupStatus.idle) {
        return const SingleChildScrollView(child: SkeletonRows(count: 5));
      }
      return _NoneOfKind(kind: kind, query: _c.trimmed, onAll: () => _c.setScope(null));
    }
    return ListView(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final h in hits) HitRow(key: ValueKey(h.key), hit: h, onTap: () => _open(h), showKind: false),
        if (g.loadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
          )
        else if (g.hasMore)
          SeeAllRowMore(onTap: () => _c.more(kind)),
      ],
    );
  }

  List<SearchHit> _hitsOf(SearchKind kind) {
    if (kind == SearchKind.feature) {
      return [
        for (final m in _c.featureMatches)
          featureHit(m.feature.id, m.feature.title, m.feature.subtitle, m.feature.icon),
      ];
    }
    return _c.groupOf(kind).hits;
  }
}

/// "Show more" at the foot of a single chip's list.
class SeeAllRowMore extends StatelessWidget {
  const SeeAllRowMore({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 48),
      alignment: Alignment.center,
      child: Text('Show more results', style: SearchStyles.link),
    ),
  );
}

// --- the field and the chips -----------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focus,
    required this.onChanged,
    required this.onSubmit,
    required this.onClear,
    required this.onBack,
    required this.showClear,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onClear;
  final VoidCallback onBack;
  final bool showClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            key: const Key('search.back'),
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: SearchLook.ink),
          ),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(color: SearchLook.fieldFill, borderRadius: BorderRadius.circular(4)),
              child: TextField(
                key: const Key('search.field'),
                controller: controller,
                focusNode: focus,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: onChanged,
                onSubmitted: (_) => onSubmit(),
                style: SearchStyles.input,
                cursorColor: SearchLook.blue,
                decoration: InputDecoration(
                  hintText: 'Search ICR',
                  hintStyle: SearchStyles.hint,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  suffixIcon: showClear
                      ? IconButton(
                          key: const Key('search.clear'),
                          tooltip: 'Clear',
                          onPressed: onClear,
                          icon: const Icon(Icons.close, size: 20, color: SearchLook.soft),
                        )
                      : null,
                  suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.controller});

  final GlobalSearchController controller;

  @override
  Widget build(BuildContext context) {
    final chips = controller.chips;
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: chips.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == 0) {
            return KindChip(
              key: const Key('search.chip.all'),
              label: 'All',
              selected: controller.scope == null,
              onTap: () => controller.setScope(null),
            );
          }
          final kind = chips[i - 1];
          return KindChip(
            key: Key('search.chip.${kind.name}'),
            label: kind == SearchKind.feature ? 'App' : kind.plural,
            selected: controller.scope == kind,
            onTap: () => controller.setScope(kind),
          );
        },
      ),
    );
  }
}

// --- before and without results --------------------------------------------

/// Nothing typed: the recent searches, then places to go.
class _Idle extends StatelessWidget {
  const _Idle({required this.controller, required this.onRecent, required this.onFeature});

  final GlobalSearchController controller;
  final ValueChanged<String> onRecent;
  final Future<void> Function(String id) onFeature;

  @override
  Widget build(BuildContext context) {
    final recents = controller.recents.items;
    final suggestions = controller.suggestions;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (recents.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(SearchLook.pad, 12, 4, 0),
            child: Row(
              children: [
                Expanded(child: Text('Recent searches', style: SearchStyles.heading)),
                TextButton(
                  key: const Key('search.recent.clear'),
                  onPressed: controller.clearRecents,
                  child: Text('Clear all', style: SearchStyles.link),
                ),
              ],
            ),
          ),
          for (final q in recents)
            InkWell(
              key: Key('search.recent.$q'),
              onTap: () => onRecent(q),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.only(left: SearchLook.pad),
                  child: Row(
                    children: [
                      const Icon(Icons.history, size: 22, color: SearchLook.soft),
                      const SizedBox(width: 16),
                      Expanded(child: Text(q, maxLines: 1, overflow: TextOverflow.ellipsis, style: SearchStyles.recent)),
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: () => controller.removeRecent(q),
                        icon: const Icon(Icons.close, size: 18, color: SearchLook.soft),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          const GroupRule(),
        ],
        if (suggestions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(SearchLook.pad, 16, SearchLook.pad, 4),
            child: Text('Suggested for you', style: SearchStyles.heading),
          ),
          for (final f in suggestions)
            HitRow(
              key: Key('search.suggested.${f.id}'),
              hit: featureHit(f.id, f.title, f.subtitle, f.icon),
              showKind: false,
              onTap: () => onFeature(f.id),
            ),
        ],
      ],
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query, required this.onFeature, required this.controller});

  final String query;
  final Future<void> Function(String id) onFeature;
  final GlobalSearchController controller;

  @override
  Widget build(BuildContext context) {
    final suggestions = controller.suggestions;
    return ListView(
      padding: const EdgeInsets.all(SearchLook.pad),
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.search_off, size: 40, color: SearchLook.soft),
        const SizedBox(height: 12),
        Text('No results for “$query”', textAlign: TextAlign.center, style: SearchStyles.emptyTitle),
        const SizedBox(height: 8),
        Text(
          'Check the spelling or try fewer words. You can also go straight to a place in ICR:',
          textAlign: TextAlign.center,
          style: SearchStyles.emptyBody,
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [for (final f in suggestions) KindChip(label: f.title, selected: false, onTap: () => onFeature(f.id))],
        ),
      ],
    );
  }
}

class _NoneOfKind extends StatelessWidget {
  const _NoneOfKind({required this.kind, required this.query, required this.onAll});

  final SearchKind kind;
  final String query;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(kind.icon, size: 40, color: SearchLook.soft),
          const SizedBox(height: 12),
          Text('No ${kind.plural.toLowerCase()} for “$query”', textAlign: TextAlign.center, style: SearchStyles.emptyTitle),
          const SizedBox(height: 4),
          TextButton(onPressed: onAll, child: Text('Search everything', style: SearchStyles.link)),
        ],
      ),
    ),
  );
}

class _Offline extends StatelessWidget {
  const _Offline({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40, color: SearchLook.soft),
          const SizedBox(height: 12),
          Text("Can't reach ICR", style: SearchStyles.emptyTitle),
          const SizedBox(height: 4),
          Text('Check your connection and try again.', textAlign: TextAlign.center, style: SearchStyles.emptyBody),
          const SizedBox(height: 8),
          TextButton(key: const Key('search.retry'), onPressed: onRetry, child: Text('Try again', style: SearchStyles.link)),
        ],
      ),
    ),
  );
}
