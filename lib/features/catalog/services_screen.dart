import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show openSitePage, showMessage;
import '../../core/widgets/chips.dart';
import '../account/widgets/account_kit.dart';
import '../marketplace/catalog_models.dart' show formatRupees;
import '../site/site_kit.dart';
import 'catalog_controller.dart';
import 'catalog_models.dart';
import 'catalog_parts.dart';
import 'catalog_repository.dart';
import 'catalog_scaffold.dart';
import 'catalog_words.dart';
import 'service_sheet.dart';

/// The website's `/manage/services` ("My Services"): the services the company offers, and how complete each
/// listing is. The figures its tiles carry, the plan's listing places, search, the status filter, the sorts and the
/// category chips; one row per service (its initial, the name, its category, a line of the description, the price,
/// the turnaround, its status chip — an "Add …" chip opens the editor on that field — and the listing strength),
/// with Edit · Duplicate · Delete in its menu; Select for deleting several at once; the website's empty state.
///
/// Above it all, while the company has no supplier listing, the website's notice with "Start selling". Someone
/// acting for no company sees the website's `NoCompany` instead; a role that does not manage the catalogue is told.
/// Rows the whole width, hairlines between, nothing boxed. [repository] and [viewer] are seams for tests.
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key, required this.onBack, this.repository, this.viewer, this.onCreateCompany});

  final VoidCallback onBack;
  final CatalogRepository? repository;

  /// Who is looking; read from the signed-in session when null.
  final CatalogViewer? viewer;

  /// "Create a company", offered to someone acting for no company. Hidden without it.
  final VoidCallback? onCreateCompany;

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  late final ServicesController _controller;
  final _search = TextEditingController();
  bool _selectMode = false;
  final Set<String> _selected = {};
  String? _startError;

  @override
  void initState() {
    super.initState();
    _controller = ServicesController(
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

  Future<void> _edit(ServiceItem? editing, {ServiceSignal? focus}) async {
    final saved = await showServiceSheet(
      context,
      editing: editing,
      tops: _controller.categories,
      focus: focus,
      send: (draft) => _controller.save(draft, editing: editing),
    );
    if (saved && mounted) {
      showMessage(context, editing == null ? CatalogWords.servicePublished : CatalogWords.serviceUpdated);
    }
  }

  Future<void> _menu(ServiceItem s) async {
    final picked = await showRowMenu<String>(
      context,
      title: s.name,
      actions: const [
        RowAction(value: 'edit', label: CatalogWords.edit, icon: Symbols.edit, key: Key('row.edit')),
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
        await _edit(s);
      case 'duplicate':
        final refusal = await _controller.duplicate(s);
        if (mounted) showMessage(context, refusal ?? CatalogWords.serviceDuplicated);
      case 'delete':
        await _delete([s.id]);
    }
  }

  Future<void> _delete(List<String> ids) async {
    final one = ids.length == 1 ? _controller.rows.where((s) => s.id == ids.first).firstOrNull : null;
    final ok = await confirmCatalogDelete(
      context,
      title: ids.length == 1
          ? CatalogWords.deleteOne(one?.name.isNotEmpty == true ? one!.name : CatalogWords.thisService)
          : CatalogWords.deleteManyServices(ids.length),
      body: ids.length == 1 ? CatalogWords.deleteOneBody : CatalogWords.deleteManyBody,
    );
    if (!ok || !mounted) return;
    if (ids.length == 1 && one != null) {
      final refusal = await _controller.delete(one);
      if (!mounted) return;
      _selected.remove(one.id);
      showMessage(context, refusal ?? CatalogWords.serviceDeleted);
      return;
    }
    final failed = await _controller.deleteMany(ids);
    if (!mounted) return;
    setState(() {
      _selected.removeWhere((id) => !_controller.rows.any((s) => s.id == id));
      if (failed == 0) _selectMode = false;
    });
    showMessage(context, failed > 0 ? CatalogWords.someServicesNotDeleted : CatalogWords.servicesDeleted(ids.length));
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

  Future<void> _pickStatus() async {
    final picked = await showAccountPicker<ServiceHealth>(
      context,
      title: 'Status',
      items: ServiceHealth.values,
      labelOf: serviceHealthLabel,
      selected: _controller.status,
    );
    if (picked != null) _controller.setStatus(picked);
  }

  Future<void> _pickSort() async {
    final picked = await showAccountPicker<CatalogSort>(
      context,
      title: 'Sort By',
      items: CatalogSort.values,
      labelOf: _sortLabel,
      selected: _controller.sort,
    );
    if (picked != null) _controller.setSort(picked);
  }

  // --- the page ----------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return CatalogScaffold<ServiceItem>(
      title: CatalogWords.servicesTitle,
      onBack: widget.onBack,
      controller: _controller,
      couldNotLoad: CatalogWords.couldNotLoadServices,
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
        subtitle: CatalogWords.servicesSubtitle,
        addLabel: CatalogWords.addService,
        onAdd: c.saving ? null : () => _edit(null),
        stats: empty ? null : _stats(c),
        below: [
          if (c.listingLimit != null)
            ListingPlacesLine(
              used: c.placesUsed,
              limit: c.listingLimit!,
              products: c.otherCount,
              services: c.rows.length,
              onSeePlans: () => openSitePage(context, '/pricing/supplier'),
            ),
        ],
      ),
      if (empty) ...[
        catalogRule,
        _EmptyServices(onAdd: () => _edit(null)),
      ] else ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CatalogSearchField(hint: CatalogWords.searchServices, controller: _search, onChanged: c.setSearch),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CatalogChip(
                    key: const Key('catalog.filter'),
                    label: serviceHealthLabel(c.status),
                    icon: Symbols.filter_list,
                    on: c.status != ServiceHealth.all,
                    caret: true,
                    onTap: _pickStatus,
                  ),
                  CatalogChip(
                    key: const Key('catalog.sort'),
                    label: _sortLabel(c.sort),
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
              if (chips.isNotEmpty) ...[
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
                          ..addAll(shown.map((s) => s.id));
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
            text: CatalogWords.noServicesMatch,
            onClear: () {
              _search.clear();
              c.clearFilters();
            },
          )
        else
          for (final s in shown) ...[
            ServiceRow(
              key: Key('service.${s.id}'),
              service: s,
              categoryLabel: s.categoryKey == null ? CatalogWords.uncategorized : c.labelOf(s.categoryKey),
              selectable: _selectMode,
              selected: _selected.contains(s.id),
              busy: c.busyIds.contains(s.id),
              onTap: () => _selectMode ? _toggle(s.id) : _edit(s),
              onFix: (signal) => _edit(s, focus: signal),
              onMenu: () => _menu(s),
            ),
            catalogRule,
          ],
      ],
    ];
  }

  /// The website's tiles, in one line under the owner's labels: services listed, service categories, the average
  /// starting price, the listing quality, how many state a turnaround, and the best-completed listing. (Profile
  /// views and quote requests are "Soon" on the website, with no figure behind them, so they are not shown.)
  String _stats(ServicesController c) => [
    CatalogWords.servicesListed(c.rows.length),
    CatalogWords.serviceCategories(c.categoryCount),
    if (c.averagePrice != null) CatalogWords.averageStartingPrice(formatRupees(c.averagePrice!.toDouble())),
    CatalogWords.listingQuality(c.strength),
    CatalogWords.withTurnaround(c.withTurnaround, c.rows.length),
    if (c.bestCompleted case final best? when best.name.trim().isNotEmpty) CatalogWords.bestCompletedListing(best.name),
  ].join(' · ');

  /// The sorts, with the owner's "Recently Added" for the newest first.
  static String _sortLabel(CatalogSort s) => s == CatalogSort.recent ? CatalogWords.recentlyAdded : catalogSortLabel(s);
}

/// One service, as the website's card: its initial on a tint, the name and category, a line of the description,
/// the price (or "No price set") and turnaround as chips, the status chip (its gap, opening the editor there) and
/// the listing strength.
class ServiceRow extends StatelessWidget {
  const ServiceRow({
    super.key,
    required this.service,
    required this.categoryLabel,
    required this.onTap,
    required this.onFix,
    required this.onMenu,
    this.selectable = false,
    this.selected = false,
    this.busy = false,
  });

  final ServiceItem service;
  final String categoryLabel;
  final VoidCallback onTap;

  /// Opens the editor on a missing field.
  final ValueChanged<ServiceSignal> onFix;
  final VoidCallback onMenu;
  final bool selectable;
  final bool selected;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final s = service;
    final price = s.priceLabel;
    final missing = s.missing;
    return CatalogRowFrame(
      leading: CatalogThumb(initial: s.name.trim().isEmpty ? '?' : s.name.trim().substring(0, 1).toUpperCase()),
      onTap: onTap,
      onMenu: onMenu,
      menuLabel: CatalogWords.serviceActions,
      selectable: selectable,
      selected: selected,
      busy: busy,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.name, style: SiteText.strong, maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(categoryLabel, key: Key('service.category.${s.id}'), style: SiteText.meta),
          const SizedBox(height: 4),
          Text(
            (s.description ?? '').trim().isEmpty ? CatalogWords.noServiceDescription : s.description!,
            style: SiteText.meta,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              IcrChip(
                key: Key('service.price.${s.id}'),
                label: price ?? CatalogWords.noPriceSet,
                tone: ChipTone.outlined,
                icon: price != null ? Symbols.sell : null,
                iconSize: 13,
                iconColor: AppColors.primary,
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: SiteText.meta.copyWith(
                  fontWeight: price != null ? FontWeight.w700 : FontWeight.w400,
                  color: price != null ? AppColors.primary : SiteColors.secondary,
                ),
              ),
              if ((s.turnaroundTime ?? '').trim().isNotEmpty)
                IcrChip(
                  label: s.turnaroundTime!.trim(),
                  tone: ChipTone.outlined,
                  icon: Icons.schedule_outlined,
                  iconSize: 13,
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: SiteText.meta.copyWith(color: SiteColors.ink),
                ),
              CatalogStatusChip(
                key: Key('service.status.${s.id}'),
                status: s.status,
                onTap: missing.isEmpty || busy ? null : () => onFix(missing.first),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StrengthBar(
            score: s.score,
            label: CatalogWords.listingQualityLabel,
            missing: missing.isEmpty ? '' : CatalogWords.addMissing(missing.map(serviceSignalLabel).join(', ')),
          ),
        ],
      ),
    );
  }
}

/// The website's `EmptyServices`.
class _EmptyServices extends StatelessWidget {
  const _EmptyServices({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('catalog.empty'),
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Symbols.design_services, size: 40, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(CatalogWords.noServicesYet, style: SiteText.heading, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(CatalogWords.createFirstService, style: SiteText.secondary, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          AccountButton(
            key: const Key('catalog.addFirst'),
            label: CatalogWords.addFirstService,
            icon: Symbols.add,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
