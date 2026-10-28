import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../catalog_models.dart';
import '../marketplace_controller.dart';
import '../marketplace_filters.dart';
import '../marketplace_models.dart';
import '../marketplace_navigation.dart';
import '../categories_screen.dart';
import '../marketplace_styles.dart';

/// Opens a bottom sheet that keeps the screen's controller and hand-overs: a
/// sheet is built under the navigator, not under the screen, so the scope and
/// the provider are handed in again.
Future<T?> showMartSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool scrollControlled = true,
  bool useSafeArea = true,
}) {
  final market = context.read<MarketplaceController>();
  final nav = MarketplaceScope.navigationOf(context);
  final links = MarketplaceScope.linksOf(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: scrollControlled,
    showDragHandle: true,
    useSafeArea: useSafeArea,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (sheet) => ChangeNotifierProvider<MarketplaceController>.value(
      value: market,
      child: MarketplaceScope(
        navigation: nav,
        links: links,
        child: Builder(builder: builder),
      ),
    ),
  );
}

// ---- Sort and rating --------------------------------------------------------------------

/// The order of the list: "Sort Top rated".
Future<void> pickSort(BuildContext context) async {
  final market = context.read<MarketplaceController>();
  final choice = await showMartSheet<SupplierSort>(
    context,
    scrollControlled: false,
    builder: (sheet) => _ChoiceSheet<SupplierSort>(
      title: 'Sort suppliers',
      choices: [for (final s in SupplierSort.values) (s, s.label)],
      current: market.filters.sort,
      keyPrefix: 'sort',
    ),
  );
  if (choice != null) await market.setSort(choice);
}

/// The lowest rating to show: "By ratings".
Future<void> pickRating(BuildContext context) async {
  final market = context.read<MarketplaceController>();
  final current = market.filters.minRating;
  final choice = await showMartSheet<double>(
    context,
    scrollControlled: false,
    builder: (sheet) => _ChoiceSheet<double>(
      title: 'Minimum rating',
      choices: [(0, 'Any rating'), for (final r in ratingSteps) (r, ratingStepLabel(r))],
      current: current ?? 0,
      keyPrefix: 'rating',
    ),
  );
  if (choice != null) await market.setMinRating(choice == 0 ? null : choice);
}

class _ChoiceSheet<T> extends StatelessWidget {
  const _ChoiceSheet({required this.title, required this.choices, required this.current, required this.keyPrefix});

  final String title;
  final List<(T, String)> choices;
  final T current;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Text(title, style: MartText.sheetTitle),
          ),
          for (final (value, label) in choices)
            ListTile(
              key: ValueKey('$keyPrefix-$label'),
              dense: true,
              title: Text(label, style: MartText.sheetRow),
              trailing: value == current ? const Icon(LucideIcons.check, size: 18, color: AppColors.primary) : null,
              onTap: () => Navigator.pop(context, value),
            ),
        ],
      ),
    );
  }
}

// ---- Filters -----------------------------------------------------------------------------

/// The Filters sheet: category, city, trust level, size and registrations, and
/// the member's saved suppliers.
Future<void> showMarketFilters(BuildContext context) async {
  final market = context.read<MarketplaceController>();
  final result = await showMartSheet<MarketplaceFilters>(
    context,
    builder: (sheet) => MarketFiltersSheet(initial: market.filters),
  );
  if (result != null) await market.setFilters(result);
}

class MarketFiltersSheet extends StatefulWidget {
  const MarketFiltersSheet({super.key, required this.initial});

  final MarketplaceFilters initial;

  @override
  State<MarketFiltersSheet> createState() => _MarketFiltersSheetState();
}

class _MarketFiltersSheetState extends State<MarketFiltersSheet> {
  late var _filters = widget.initial;
  final _categorySearch = TextEditingController();
  final _expanded = <String>{};

  @override
  void initState() {
    super.initState();
    final market = context.read<MarketplaceController>();
    market.loadCities();
    market.loadCategories();
  }

  @override
  void dispose() {
    _categorySearch.dispose();
    super.dispose();
  }

  void _toggle(Set<String> set, String value, void Function(Set<String>) apply) {
    final next = {...set};
    next.contains(value) ? next.remove(value) : next.add(value);
    setState(() => apply(next));
  }

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketplaceController>();
    final cities = market.cities;
    final level = _filters.minLevel;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
            child: Row(
              children: [
                Expanded(child: Text('Filters', style: MartText.sheetTitle)),
                TextButton(
                  key: const ValueKey('filters-clear'),
                  onPressed: () => setState(() => _filters = _filters.clearedSheet()),
                  child: Text('Clear all', style: MartText.sheetLink),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              children: [
                _Section('Trust level'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(
                      label: 'Any level',
                      selected: level == null,
                      onTap: () => setState(() => _filters = _filters.copyWith(clearLevel: true)),
                    ),
                    for (final l in SupplierLevel.values.where((l) => l.isVerified))
                      _Pill(
                        label: l == SupplierLevel.verified ? 'Verified' : '${l.label} & up',
                        selected: level == l,
                        onTap: () => setState(() => _filters = _filters.copyWith(minLevel: l)),
                      ),
                  ],
                ),
                _Section(
                  'Category',
                  trailing: TextButton(
                    key: const ValueKey('browse-categories'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 28),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => showCategories(context),
                    child: Text('Browse all', style: MartText.sheetLink),
                  ),
                ),
                _CategoryPicker(
                  tree: market.tree,
                  search: _categorySearch,
                  selected: _filters.categories,
                  expanded: _expanded,
                  onToggle: (key) =>
                      _toggle(_filters.categories, key, (s) => _filters = _filters.copyWith(categories: s)),
                  onExpand: (key) =>
                      setState(() => _expanded.contains(key) ? _expanded.remove(key) : _expanded.add(key)),
                  onSearch: () => setState(() {}),
                ),
                _Section('City'),
                if (cities == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (cities.isEmpty)
                  Text('No cities to pick from yet.', style: MartText.sheetRowMuted)
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final city in cities)
                        _Pill(
                          label: city,
                          selected: _filters.city == city,
                          onTap: () => setState(
                            () => _filters = _filters.city == city
                                ? _filters.copyWith(clearCity: true)
                                : _filters.copyWith(city: city),
                          ),
                        ),
                    ],
                  ),
                _Section('Company size'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final size in companySizes)
                      _Pill(
                        label: '$size employees',
                        selected: _filters.sizes.contains(size),
                        onTap: () => _toggle(_filters.sizes, size, (s) => _filters = _filters.copyWith(sizes: s)),
                      ),
                  ],
                ),
                _Section('Registrations'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(
                      label: 'GST registered',
                      selected: _filters.gst,
                      onTap: () => setState(() => _filters = _filters.copyWith(gst: !_filters.gst)),
                    ),
                    _Pill(
                      label: 'MSME / Udyam',
                      selected: _filters.msme,
                      onTap: () => setState(() => _filters = _filters.copyWith(msme: !_filters.msme)),
                    ),
                  ],
                ),
                _Section('Saved'),
                _Pill(
                  label: 'Only my saved suppliers',
                  selected: _filters.savedOnly,
                  onTap: () => setState(() => _filters = _filters.copyWith(savedOnly: !_filters.savedOnly)),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  key: const ValueKey('filters-apply'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context, _filters),
                  child: Text('Show suppliers', style: MartText.sheetButton),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: trailing == null ? 18 : 10, bottom: trailing == null ? 10 : 2),
    child: Row(
      children: [
        Expanded(child: Text(title, style: MartText.sheetSection)),
        ?trailing,
      ],
    ),
  );
}

/// A choice in a filter: white with a hairline, or blue when it is on.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(side: BorderSide(color: selected ? AppColors.primary : AppColors.outlineVariant));
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primary : Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            child: Text(
              label,
              style: MartText.sheetRow.copyWith(color: selected ? Colors.white : AppColors.onSurface, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}

/// The category tree: top-level categories to pick or open, then their
/// sub-categories. The API reads a picked category as itself and everything
/// under it.
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.tree,
    required this.search,
    required this.selected,
    required this.expanded,
    required this.onToggle,
    required this.onExpand,
    required this.onSearch,
  });

  final List<CategoryNode>? tree;
  final TextEditingController search;
  final Set<String> selected;
  final Set<String> expanded;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onExpand;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final nodes = tree;
    if (nodes == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (nodes.isEmpty) return Text('No categories to pick from yet.', style: MartText.sheetRowMuted);
    final query = search.text.trim().toLowerCase();
    final rows = <Widget>[];
    for (final top in nodes) {
      final kids = [
        for (final c in top.children)
          if (query.isEmpty || c.name.toLowerCase().contains(query)) c,
      ];
      final topHit = query.isEmpty || top.name.toLowerCase().contains(query);
      if (!topHit && kids.isEmpty) continue;
      final open = query.isNotEmpty || expanded.contains(top.key);
      rows.add(
        _CategoryRow(
          node: top,
          selected: selected.contains(top.key),
          indent: 0,
          trailing: top.children.isEmpty
              ? null
              : IconButton(
                  key: ValueKey('open-${top.key}'),
                  visualDensity: VisualDensity.compact,
                  tooltip: open ? 'Hide ${top.name} sub-categories' : 'Show ${top.name} sub-categories',
                  icon: Icon(
                    open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 18,
                    color: AppColors.outline,
                  ),
                  onPressed: () => onExpand(top.key),
                ),
          onTap: () => onToggle(top.key),
        ),
      );
      if (open) {
        for (final child in kids) {
          rows.add(
            _CategoryRow(
              node: child,
              selected: selected.contains(child.key),
              indent: 22,
              onTap: () => onToggle(child.key),
            ),
          );
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 38,
          child: TextField(
            key: const ValueKey('category-search'),
            controller: search,
            onChanged: (_) => onSearch(),
            style: MartText.sheetRow,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search categories',
              hintStyle: MartText.sheetRowMuted.copyWith(fontSize: 14),
              prefixIcon: const Icon(LucideIcons.search, size: 16, color: AppColors.outline),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(19),
                borderSide: const BorderSide(color: AppColors.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(19),
                borderSide: const BorderSide(color: AppColors.outlineVariant),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('No category matches.', style: MartText.sheetRowMuted),
          )
        else
          ...rows,
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.node,
    required this.selected,
    required this.indent,
    required this.onTap,
    this.trailing,
  });

  final CategoryNode node;
  final bool selected;
  final double indent;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: selected,
      child: InkWell(
        key: ValueKey('category-${node.key}'),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.only(left: indent),
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.outline,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(node.name, style: MartText.sheetRow, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if ((node.count ?? 0) > 0) Text('${node.count}', style: MartText.sheetRowMuted),
                trailing ?? const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
