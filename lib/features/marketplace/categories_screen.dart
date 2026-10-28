import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/title_bar.dart';
import 'catalog_board_controller.dart';
import 'catalog_models.dart';
import 'marketplace_controller.dart';
import 'marketplace_navigation.dart';
import 'marketplace_styles.dart';
import 'widgets/catalog_board.dart';
import 'widgets/mart_search_field.dart';
import 'widgets/supplier_parts.dart';

/// Opens the category browser: every top category with its blurb and how many
/// verified suppliers are filed under it, then a category's sub-categories and
/// its products and services. Picking a category shows its suppliers on the
/// Marketplace.
Future<void> showCategories(BuildContext context) => _push(context, const CategoriesScreen());

/// A category's page.
Future<void> showCategoryPage(BuildContext context, CategoryNode node) => _push(context, CategoryPage(node: node));

/// The marketplace's products or services on one board, with search.
Future<void> showCatalogBoard(BuildContext context, CatalogKind kind) => _push(context, CatalogBoardScreen(kind: kind));

Future<void> _push(BuildContext context, Widget page) {
  final market = context.read<MarketplaceController>();
  final nav = MarketplaceScope.navigationOf(context);
  final links = MarketplaceScope.linksOf(context);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MarketplaceScope(
        navigation: nav,
        links: links,
        child: ChangeNotifierProvider<MarketplaceController>.value(value: market, child: page),
      ),
    ),
  );
}

/// Shows the suppliers filed under [key] on the Marketplace: sets the filter and goes back to the tab.
Future<void> showSuppliersOf(BuildContext context, String key) async {
  final market = context.read<MarketplaceController>();
  final navigator = Navigator.of(context);
  navigator.popUntil((route) => route.isFirst);
  await market.setFilters(market.filters.copyWith(categories: {key}, savedOnly: false));
}

// ---- The top categories --------------------------------------------------------------------

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    context.read<MarketplaceController>().loadCategories();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketplaceController>();
    final nav = MarketplaceScope.navigationOf(context);
    final links = MarketplaceScope.linksOf(context);
    final tree = market.tree;
    final q = _query.trim().toLowerCase();
    final shown = tree == null
        ? const <CategoryNode>[]
        : [
            for (final top in tree)
              if (q.isEmpty ||
                  top.name.toLowerCase().contains(q) ||
                  top.children.any((c) => c.name.toLowerCase().contains(q)))
                top,
          ];
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TitleBar(
              title: 'Categories',
              onBack: () => Navigator.maybePop(context),
              unread: market.unread,
              onBell: () => nav.notifications(context, links),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: MartSearchField(
                controller: _search,
                hint: 'Search categories',
                onSubmitted: (v) => setState(() => _query = v),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: tree == null
                  ? const PartSpinner()
                  : ListView(
                      key: const ValueKey('categories-list'),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        if (q.isEmpty)
                          Row(
                            children: [
                              Expanded(
                                child: _QuickCard(
                                  icon: LucideIcons.package,
                                  label: 'All products',
                                  onTap: () => showCatalogBoard(context, CatalogKind.products),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _QuickCard(
                                  icon: LucideIcons.wrench,
                                  label: 'All services',
                                  onTap: () => showCatalogBoard(context, CatalogKind.services),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 10),
                        if (shown.isEmpty)
                          const EmptyPart(title: 'No category matches', body: 'Try other words.')
                        else
                          for (final top in shown) _TopCard(node: top, onTap: () => showCategoryPage(context, top)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: MartColors.cardBorder, width: 1.5),
    );
    return Material(
      color: Colors.white,
      shape: shape,
      child: InkWell(
        key: ValueKey('quick-$label'),
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: MartText.serviceName)),
              const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopCard extends StatelessWidget {
  const _TopCard({required this.node, required this.onTap});

  final CategoryNode node;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: MartColors.cardBorder, width: 1.5),
    );
    final suppliers = node.count ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: shape,
        child: InkWell(
          key: ValueKey('category-card-${node.key}'),
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.layoutGrid, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(node.name, style: MartText.serviceName),
                      if ((node.blurb ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(node.blurb!, style: MartText.sheetRowMuted, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (suppliers > 0) '$suppliers ${suppliers == 1 ? 'supplier' : 'suppliers'}',
                          if (node.children.isNotEmpty) '${node.children.length} sub-categories',
                        ].join(' • '),
                        style: AppText.small.copyWith(fontSize: 12, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Icon(LucideIcons.chevronRight, size: 16, color: AppColors.outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- One category --------------------------------------------------------------------------

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key, required this.node});

  final CategoryNode node;

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  late final CatalogBoardController _products;
  late final CatalogBoardController _services;
  CatalogKind _kind = CatalogKind.products;

  @override
  void initState() {
    super.initState();
    final repo = context.read<MarketplaceController>().repository;
    _products = CatalogBoardController(
      repository: repo,
      kind: CatalogKind.products,
      categoryKey: widget.node.key,
      categorySlug: widget.node.slug,
    );
    _services = CatalogBoardController(
      repository: repo,
      kind: CatalogKind.services,
      categoryKey: widget.node.key,
      categorySlug: widget.node.slug,
    );
    _products.start();
  }

  @override
  void dispose() {
    _products.dispose();
    _services.dispose();
    super.dispose();
  }

  void _pick(CatalogKind kind) {
    setState(() => _kind = kind);
    final board = kind == CatalogKind.products ? _products : _services;
    if (!board.started) board.start();
  }

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketplaceController>();
    final nav = MarketplaceScope.navigationOf(context);
    final links = MarketplaceScope.linksOf(context);
    final node = widget.node;
    final suppliers = node.count ?? 0;
    final board = _kind == CatalogKind.products ? _products : _services;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TitleBar(
              title: node.name,
              onBack: () => Navigator.maybePop(context),
              unread: market.unread,
              onBell: () => nav.notifications(context, links),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('category-page'),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if ((node.blurb ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Text(node.blurb!, style: MartText.body.copyWith(fontSize: 13)),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: SizedBox(
                      height: 44,
                      child: FilledButton.icon(
                        key: const ValueKey('show-suppliers'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => showSuppliersOf(context, node.key),
                        icon: const Icon(LucideIcons.store, size: 16),
                        label: Text(
                          suppliers > 0
                              ? 'Show $suppliers ${suppliers == 1 ? 'supplier' : 'suppliers'}'
                              : 'Show suppliers',
                          style: MartText.sheetButton,
                        ),
                      ),
                    ),
                  ),
                  if (node.children.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                      child: Text('Sub-categories', style: MartText.heading),
                    ),
                    for (final child in node.children)
                      InkWell(
                        key: ValueKey('sub-${child.key}'),
                        onTap: () => showSuppliersOf(context, child.key),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: MartColors.rule, width: 1)),
                            ),
                            child: SizedBox(
                              height: 44,
                              child: Row(
                                children: [
                                  Expanded(child: Text(child.name, style: MartText.sheetRow)),
                                  if ((child.count ?? 0) > 0) Text('${child.count}', style: MartText.sheetRowMuted),
                                  const SizedBox(width: 8),
                                  const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.outline),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Row(
                      children: [
                        for (final kind in CatalogKind.values) ...[
                          if (kind != CatalogKind.products) const SizedBox(width: 8),
                          _KindPill(
                            key: ValueKey('kind-${kind.name}'),
                            label: kind.label,
                            on: _kind == kind,
                            onTap: () => _pick(kind),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ChangeNotifierProvider<CatalogBoardController>.value(
                    key: ValueKey('board-${_kind.name}'),
                    value: board,
                    child: CatalogBoardList(
                      emptyTitle: 'No ${_kind.label.toLowerCase()} in ${node.name} yet',
                      emptyBody: 'Suppliers add what they sell as they join.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindPill extends StatelessWidget {
  const _KindPill({super.key, required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(side: BorderSide(color: on ? AppColors.primary : MartColors.cardBorder, width: 1.5));
    return Semantics(
      button: true,
      selected: on,
      child: Material(
        color: on ? AppColors.primary : Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            child: Text(label, style: MartText.groupChip.copyWith(color: on ? Colors.white : null, fontSize: 13)),
          ),
        ),
      ),
    );
  }
}

// ---- A board of every product or service -------------------------------------------------------

class CatalogBoardScreen extends StatefulWidget {
  const CatalogBoardScreen({super.key, required this.kind});

  final CatalogKind kind;

  @override
  State<CatalogBoardScreen> createState() => _CatalogBoardScreenState();
}

class _CatalogBoardScreenState extends State<CatalogBoardScreen> {
  late final CatalogBoardController _board;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _board = CatalogBoardController(repository: context.read<MarketplaceController>().repository, kind: widget.kind)
      ..start();
  }

  @override
  void dispose() {
    _board.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketplaceController>();
    final nav = MarketplaceScope.navigationOf(context);
    final links = MarketplaceScope.linksOf(context);
    return ChangeNotifierProvider<CatalogBoardController>.value(
      value: _board,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              TitleBar(
                title: widget.kind.label,
                onBack: () => Navigator.maybePop(context),
                unread: market.unread,
                onBell: () => nav.notifications(context, links),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: MartSearchField(
                  controller: _search,
                  hint: 'Search ${widget.kind.label.toLowerCase()}',
                  onSubmitted: _board.setSearch,
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _board.refresh,
                  child: ListView(
                    key: const ValueKey('board-list'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      Consumer<CatalogBoardController>(
                        builder: (context, board, _) => board.total > 0
                            ? Padding(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                                child: Text(
                                  '${board.total} ${board.kind.label.toLowerCase()}',
                                  style: MartText.sheetRowMuted,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      CatalogBoardList(emptyTitle: 'No ${widget.kind.label.toLowerCase()} listed yet'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
