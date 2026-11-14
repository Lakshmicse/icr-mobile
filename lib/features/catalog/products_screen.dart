import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show openSitePage, showMessage;
import '../account/widgets/account_kit.dart';
import '../site/site_kit.dart';
import 'catalog_controller.dart';
import 'catalog_models.dart';
import 'catalog_parts.dart';
import 'catalog_photo_picker.dart';
import 'catalog_repository.dart';
import 'catalog_scaffold.dart';
import 'catalog_words.dart';
import 'product_sheet.dart';

/// The website's `/manage/products` ("My Products"): the products the company sells, on its supplier listing and
/// the marketplace product grid. The figures its tiles carry, the plan's listing places, the "Worth finishing"
/// counts, search, the completeness filter, the sorts and the category chips; one row per product (photo, name,
/// category, price, status, listing strength) opening the editor, with Edit · View as buyer · Duplicate · Delete in
/// its menu; Select for deleting several at once; the website's empty state with its three steps.
///
/// Above it all, while the company has no supplier listing, the website's notice with "Start selling". Someone
/// acting for no company sees the website's `NoCompany` instead; a role that does not manage the catalogue is told.
/// Rows the whole width, hairlines between, nothing boxed. [repository], [viewer] and [photoPicker] are seams for
/// tests.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({
    super.key,
    required this.onBack,
    this.repository,
    this.viewer,
    this.photoPicker,
    this.onCreateCompany,
  });

  final VoidCallback onBack;
  final CatalogRepository? repository;

  /// Who is looking; read from the signed-in session when null.
  final CatalogViewer? viewer;

  /// Where the editor gets a photo from; the phone's chooser when null.
  final CatalogPhotoPicker? photoPicker;

  /// "Create a company", offered to someone acting for no company. Hidden without it.
  final VoidCallback? onCreateCompany;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late final ProductsController _controller;
  late final CatalogPhotoPicker _picker = widget.photoPicker ?? const SystemCatalogPhotoPicker();
  final _search = TextEditingController();
  bool _selectMode = false;
  final Set<String> _selected = {};
  String? _startError;

  @override
  void initState() {
    super.initState();
    _controller = ProductsController(
      repository: widget.repository ?? catalogRepositoryOf(context),
      viewer: widget.viewer ?? catalogViewerOf(context),
    )..start();
  }

  @override
  void dispose() {
    _controller.dispose();
    _search.dispose();
    super.dispose();
  }

  // --- what the buttons do -----------------------------------------------------------------------------------------

  Future<void> _edit(ProductItem? editing) async {
    final saved = await showProductSheet(
      context,
      editing: editing,
      tops: _controller.categories,
      picker: _picker,
      upload: _controller.repository.uploadPhoto,
      send: (draft, {required categoryChanged}) =>
          _controller.save(draft, editing: editing, categoryChanged: categoryChanged),
    );
    if (saved && mounted) {
      showMessage(context, editing == null ? CatalogWords.productPublished : CatalogWords.productUpdated);
    }
  }

  Future<void> _menu(ProductItem p) async {
    final picked = await showRowMenu<String>(
      context,
      title: p.name,
      actions: const [
        RowAction(value: 'edit', label: CatalogWords.edit, icon: Symbols.edit, key: Key('row.edit')),
        RowAction(value: 'buyer', label: CatalogWords.viewAsBuyer, icon: Symbols.open_in_new, key: Key('row.buyer')),
        RowAction(
          value: 'duplicate',
          label: CatalogWords.duplicate,
          icon: Symbols.content_copy,
          key: Key('row.duplicate'),
        ),
        RowAction(
          value: 'delete',
          label: CatalogWords.delete,
          icon: Symbols.delete,
          danger: true,
          key: Key('row.delete'),
        ),
      ],
    );
    if (picked == null || !mounted) return;
    switch (picked) {
      case 'edit':
        await _edit(p);
      case 'buyer':
        await openSitePage(context, '/products/${p.id}');
      case 'duplicate':
        final refusal = await _controller.duplicate(p);
        if (mounted) showMessage(context, refusal ?? CatalogWords.productDuplicated);
      case 'delete':
        await _delete([p.id]);
    }
  }

  Future<void> _delete(List<String> ids) async {
    final one = ids.length == 1 ? _controller.rows.where((p) => p.id == ids.first).firstOrNull : null;
    final ok = await confirmCatalogDelete(
      context,
      title: ids.length == 1
          ? CatalogWords.deleteOne(one?.name.isNotEmpty == true ? one!.name : CatalogWords.thisProduct)
          : CatalogWords.deleteMany(ids.length),
      body: ids.length == 1 ? CatalogWords.deleteOneBody : CatalogWords.deleteManyBody,
    );
    if (!ok || !mounted) return;
    if (ids.length == 1 && one != null) {
      final refusal = await _controller.delete(one);
      if (!mounted) return;
      _selected.remove(one.id);
      showMessage(context, refusal ?? CatalogWords.productDeleted);
      return;
    }
    final failed = await _controller.deleteMany(ids);
    if (!mounted) return;
    setState(() {
      _selected.removeWhere((id) => !_controller.rows.any((p) => p.id == id));
      if (failed == 0) _selectMode = false;
    });
    showMessage(
      context,
      failed > 0 ? CatalogWords.someNotDeleted(failed, ids.length) : CatalogWords.productsDeleted(ids.length),
    );
  }

  Future<void> _startSelling() async {
    setState(() => _startError = null);
    final refusal = await _controller.startSelling();
    if (mounted) setState(() => _startError = refusal);
  }

  void _toggleSelectMode() => setState(() {
    _selectMode = !_selectMode;
    _selected.clear();
  });

  void _toggle(String id) => setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));

  Future<void> _pickFilter() async {
    final picked = await showAccountPicker<ProductFilter>(
      context,
      title: 'Show',
      items: ProductFilter.values,
      labelOf: productFilterLabel,
      selected: _controller.filter,
    );
    if (picked != null) _controller.setFilter(picked == _controller.filter ? ProductFilter.all : picked);
  }

  Future<void> _pickSort() async {
    final picked = await showAccountPicker<CatalogSort>(
      context,
      title: 'Sort By',
      items: CatalogSort.values,
      labelOf: catalogSortLabel,
      selected: _controller.sort,
    );
    if (picked != null) _controller.setSort(picked);
  }

  // --- the page ----------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return CatalogScaffold<ProductItem>(
      title: CatalogWords.productsTitle,
      onBack: widget.onBack,
      controller: _controller,
      couldNotLoad: CatalogWords.couldNotLoadProducts,
      onCreateCompany: widget.onCreateCompany,
      bulkBar: _selectMode && _selected.isNotEmpty
          ? ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => BulkBar(
                count: _selected.length,
                busy: _controller.busyIds.isNotEmpty,
                onDelete: () => _delete([..._selected]),
                onClear: () => setState(_selected.clear),
              ),
            )
          : null,
      children: _children,
    );
  }

  List<Widget> _children(BuildContext context) {
    final c = _controller;
    final shown = c.shown;
    final empty = c.rows.isEmpty;
    final chips = c.categoryChips;
    return [
      if (c.actionError != null) CatalogErrorBanner(message: c.actionError!, onClose: c.dismissError),
      if (!c.hasListing) NoListingNotice(busy: c.startingToSell, onStart: _startSelling, error: _startError),
      CatalogHead(
        subtitle: CatalogWords.productsSubtitle,
        addLabel: CatalogWords.addProduct,
        onAdd: c.saving ? null : () => _edit(null),
        stats: empty ? null : _stats(c),
        below: [
          if (c.listingLimit != null)
            ListingPlacesLine(
              used: c.placesUsed,
              limit: c.listingLimit!,
              products: c.rows.length,
              services: c.otherCount,
              onSeePlans: () => openSitePage(context, '/pricing/supplier'),
            ),
          if (!empty && (c.withoutPhoto > 0 || c.withoutPrice > 0 || c.withoutCategory > 0)) _todo(c),
        ],
      ),
      if (empty) ...[
        catalogRule,
        _EmptyProducts(onAdd: () => _edit(null)),
      ] else ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CatalogSearchField(hint: CatalogWords.searchProducts, controller: _search, onChanged: c.setSearch),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CatalogChip(
                    key: const Key('catalog.filter'),
                    label: productFilterLabel(c.filter),
                    icon: Symbols.filter_list,
                    on: c.filter != ProductFilter.all,
                    caret: true,
                    onTap: _pickFilter,
                  ),
                  CatalogChip(
                    key: const Key('catalog.sort'),
                    label: catalogSortLabel(c.sort),
                    icon: Symbols.sort,
                    caret: true,
                    onTap: _pickSort,
                  ),
                  CatalogChip(
                    key: const Key('catalog.select'),
                    label: _selectMode ? CatalogWords.done : CatalogWords.select,
                    on: _selectMode,
                    onTap: _toggleSelectMode,
                  ),
                ],
              ),
              if (chips.length > 1) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    CatalogChip(
                      label: CatalogWords.allChip(c.rows.length),
                      on: c.activeCategory.isEmpty,
                      onTap: () => c.setCategory(''),
                    ),
                    for (final (key, name, count) in chips)
                      CatalogChip(
                        key: Key('catalog.category.${key.isEmpty ? 'none' : key}'),
                        label: '$name ($count)',
                        on: c.activeCategory == key && key.isNotEmpty,
                        onTap: () => c.setCategory(key),
                      ),
                  ],
                ),
              ],
              if (_selectMode && shown.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('catalog.selectAll'),
                    onPressed: () => setState(() {
                      if (_selected.length == shown.length) {
                        _selected.clear();
                      } else {
                        _selected
                          ..clear()
                          ..addAll(shown.map((p) => p.id));
                      }
                    }),
                    child: Text(
                      _selected.length == shown.length
                          ? CatalogWords.clearSelection
                          : CatalogWords.selectAll(shown.length),
                      style: SiteText.link,
                    ),
                  ),
                ),
            ],
          ),
        ),
        catalogRule,
        if (shown.isEmpty)
          NothingMatches(
            text: CatalogWords.noProductsMatch,
            onClear: () {
              _search.clear();
              c.clearFilters();
            },
          )
        else
          for (final p in shown) ...[
            ProductRow(
              key: Key('product.${p.id}'),
              product: p,
              selectable: _selectMode,
              selected: _selected.contains(p.id),
              busy: c.busyIds.contains(p.id),
              onTap: () => _selectMode ? _toggle(p.id) : _edit(p),
              onMenu: () => _menu(p),
            ),
            catalogRule,
          ],
      ],
    ];
  }

  /// The website's four tiles, in one line.
  String _stats(ProductsController c) => [
    CatalogWords.products(c.rows.length),
    CatalogWords.categories(c.categoryCount),
    CatalogWords.withAPhoto(c.withPhoto, c.rows.length),
    '${CatalogWords.listingStrength(c.strength)} ${CatalogWords.averageAcrossProducts}',
  ].join(' · ');

  /// "Worth finishing:" and the website's three counts, each a chip that narrows the list to those rows.
  Widget _todo(ProductsController c) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        key: const Key('catalog.todo'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Icon(Symbols.tips_and_updates, size: 16, color: AppColors.amber500),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(CatalogWords.worthFinishing, style: SiteText.strong),
                if (c.withoutPhoto > 0)
                  CatalogChip(
                    key: const Key('catalog.todo.noPhoto'),
                    label: CatalogWords.withoutPhoto(c.withoutPhoto),
                    on: c.filter == ProductFilter.noPhoto,
                    onTap: () => c.setFilter(ProductFilter.noPhoto),
                  ),
                if (c.withoutPrice > 0)
                  CatalogChip(
                    key: const Key('catalog.todo.noPrice'),
                    label: CatalogWords.withoutPrice(c.withoutPrice),
                    on: c.filter == ProductFilter.noPrice,
                    onTap: () => c.setFilter(ProductFilter.noPrice),
                  ),
                if (c.withoutCategory > 0)
                  CatalogChip(
                    key: const Key('catalog.todo.noCategory'),
                    label: CatalogWords.withoutCategory(c.withoutCategory),
                    on: c.filter == ProductFilter.noCategory,
                    onTap: () => c.setFilter(ProductFilter.noCategory),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One product, as the website's card: the photo (or a category glyph), the name, its category, the price (or
/// "Price on request"), a line of the description, its status chip and the listing strength.
class ProductRow extends StatelessWidget {
  const ProductRow({
    super.key,
    required this.product,
    required this.onTap,
    required this.onMenu,
    this.selectable = false,
    this.selected = false,
    this.busy = false,
  });

  final ProductItem product;
  final VoidCallback onTap;
  final VoidCallback onMenu;
  final bool selectable;
  final bool selected;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final price = p.priceLabel;
    final missing = p.missing;
    return CatalogRowFrame(
      leading: CatalogThumb(url: p.imageUrl, asset: p.imageAsset, icon: Symbols.inventory_2),
      onTap: onTap,
      onMenu: onMenu,
      menuLabel: CatalogWords.productActions,
      selectable: selectable,
      selected: selected,
      busy: busy,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.name, style: SiteText.strong, maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(p.category?.name ?? CatalogWords.noCategory, style: SiteText.meta),
          const SizedBox(height: 4),
          Text(
            price ?? CatalogWords.priceOnRequest,
            key: Key('product.price.${p.id}'),
            style: price != null ? SiteText.strong.copyWith(color: AppColors.primary) : SiteText.secondary,
          ),
          const SizedBox(height: 4),
          Text(
            (p.description ?? '').trim().isEmpty ? CatalogWords.noProductDescription : p.description!,
            style: SiteText.meta,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          CatalogStatusChip(key: Key('product.status.${p.id}'), status: p.status),
          const SizedBox(height: 8),
          StrengthBar(
            score: p.score,
            missing: missing.isEmpty ? '' : CatalogWords.addMissing(missing.map(productSignalLabel).join(', ')),
          ),
        ],
      ),
    );
  }
}

/// The website's `EmptyProducts`: what a product listing needs, in three steps, and the first add.
class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts({required this.onAdd});

  final VoidCallback onAdd;

  static const _steps = [
    (CatalogWords.stepPhotoTitle, CatalogWords.stepPhotoBody),
    (CatalogWords.stepCategoryTitle, CatalogWords.stepCategoryBody),
    (CatalogWords.stepPriceTitle, CatalogWords.stepPriceBody),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('catalog.empty'),
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Symbols.inventory_2, size: 40, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(CatalogWords.noProductsYet, style: SiteText.heading, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(CatalogWords.addWhatYouSell, style: SiteText.secondary, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          for (final (i, step) in _steps.indexed) ...[
            if (i > 0) catalogRule,
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i + 1}', style: SiteText.strong.copyWith(color: AppColors.primary)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.$1, style: SiteText.strong),
                        Text(step.$2, style: SiteText.meta),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          AccountButton(
            key: const Key('catalog.addFirst'),
            label: CatalogWords.addFirstProduct,
            icon: Symbols.add,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
