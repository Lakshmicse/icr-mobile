import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/title_bar.dart';
import 'catalog_item_controller.dart';
import 'catalog_models.dart';
import 'marketplace_controller.dart';
import 'marketplace_links.dart';
import 'marketplace_models.dart';
import 'marketplace_navigation.dart';
import 'marketplace_styles.dart';
import 'supplier_sheet.dart';
import 'widgets/supplier_card.dart';
import 'widgets/supplier_parts.dart';

/// Opens a service's page over the Marketplace: what it is, what it costs, how
/// fast, who sells it, and Request a quote. [seed] (the row that was tapped)
/// gives the page its name at once.
Future<void> showServicePage(BuildContext context, String id, {CatalogService? seed}) {
  final market = context.read<MarketplaceController>();
  final repo = market.repository;
  final controller = CatalogItemController<CatalogService>(
    read: () => repo.service(id),
    supplierFor: (s) => repo.supplierOfCompany(s.companyId),
    seed: seed,
  )..load();
  return _push(context, controller, (c) => ServicePage(controller: c));
}

/// Opens a product's page: photo, price per unit, stock, the supplier's terms,
/// who sells it, and Request a quote.
Future<void> showProductPage(BuildContext context, String id, {CatalogProduct? seed}) {
  final market = context.read<MarketplaceController>();
  final repo = market.repository;
  final controller = CatalogItemController<CatalogProduct>(
    read: () => repo.product(id),
    supplierFor: (p) async =>
        p.supplierVendorId != null ? repo.supplier(p.supplierVendorId!) : repo.supplierOfCompany(p.companyId),
    seed: seed,
  )..load();
  return _push(context, controller, (c) => ProductPage(controller: c));
}

Future<void> _push<T>(
  BuildContext context,
  CatalogItemController<T> controller,
  Widget Function(CatalogItemController<T>) page,
) async {
  final market = context.read<MarketplaceController>();
  final nav = MarketplaceScope.navigationOf(context);
  final links = MarketplaceScope.linksOf(context);
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MarketplaceScope(
        navigation: nav,
        links: links,
        child: ChangeNotifierProvider<MarketplaceController>.value(value: market, child: page(controller)),
      ),
    ),
  );
  controller.dispose();
}

// ---- The service ---------------------------------------------------------------------------

class ServicePage extends StatelessWidget {
  const ServicePage({super.key, required this.controller});

  final CatalogItemController<CatalogService> controller;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: Consumer<CatalogItemController<CatalogService>>(
        builder: (context, c, _) {
          final service = c.item;
          final market = context.watch<MarketplaceController>();
          final nav = MarketplaceScope.navigationOf(context);
          final links = MarketplaceScope.linksOf(context);
          return ItemPageFrame(
            title: 'Service',
            error: service == null ? c.error : null,
            loading: service == null && c.loading,
            onRetry: c.load,
            bottom: service == null
                ? null
                : ItemBar(
                    label: 'Request a quote',
                    sublabel: service.bookable ? service.rateLabel : null,
                    onPressed: () {
                      final supplier = c.supplier;
                      if (supplier == null) {
                        links.openSite(context, '/quote');
                      } else {
                        nav.requestQuote(context, links, supplier, service: service);
                      }
                    },
                    onShare: () => links.share(
                      text:
                          '${service.name}${service.supplierName == null ? '' : ' by ${service.supplierName}'} on ICR Supplier Mart\n'
                          '${c.supplier == null ? AppConfig.sitePage('/services') : supplierPageUri(c.supplier!)}',
                      subject: service.name,
                    ),
                  ),
            children: service == null
                ? const []
                : [
                    ItemHero(imageUrl: service.imageUrl, imageAsset: service.imageAsset, initial: service.name),
                    ItemHeading(
                      title: service.name,
                      chips: [
                        if (service.subcategory != null || service.category != null)
                          market.categoryName(service.subcategory ?? service.category!),
                      ],
                    ),
                    ItemFacts(
                      rows: [
                        ('Price', service.rateLabel ?? 'On request, ask for a quote'),
                        if (service.turnaround != null) ('Turnaround', service.turnaround!),
                        if (service.category != null && service.subcategory != null)
                          ('Category', market.categoryName(service.category!)),
                      ],
                    ),
                    SoldBy(supplier: c.supplier, fallbackName: service.supplierName, loading: c.loadingSupplier),
                    if ((service.description ?? '').isNotEmpty)
                      ItemAbout(title: 'About this service', text: service.description!),
                  ],
          );
        },
      ),
    );
  }
}

// ---- The product ---------------------------------------------------------------------------

class ProductPage extends StatelessWidget {
  const ProductPage({super.key, required this.controller});

  final CatalogItemController<CatalogProduct> controller;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: Consumer<CatalogItemController<CatalogProduct>>(
        builder: (context, c, _) {
          final product = c.item;
          final nav = MarketplaceScope.navigationOf(context);
          final links = MarketplaceScope.linksOf(context);
          return ItemPageFrame(
            title: 'Product',
            error: product == null ? c.error : null,
            loading: product == null && c.loading,
            onRetry: c.load,
            bottom: product == null
                ? null
                : ItemBar(
                    label: 'Request a quote',
                    sublabel: product.priceLabel,
                    onPressed: () {
                      final supplier = c.supplier;
                      if (supplier == null) {
                        links.openSite(context, '/quote');
                      } else {
                        nav.requestQuote(context, links, supplier, product: product);
                      }
                    },
                    onShare: () => links.share(
                      text:
                          '${product.name} on ICR Supplier Mart\n${AppConfig.sitePage('/products/${Uri.encodeComponent(product.id)}')}',
                      subject: product.name,
                    ),
                  ),
            children: product == null
                ? const []
                : [
                    ItemHero(imageUrl: product.imageUrl, imageAsset: product.imageAsset, initial: product.name),
                    ItemHeading(
                      title: product.name,
                      chips: [if (product.categoryName != null) product.categoryName!],
                      trailing: product.stock == null ? null : _StockChip(stock: product.stock!),
                    ),
                    if (product.priceLabel != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                        child: Text(
                          product.priceLabel!,
                          key: const ValueKey('product-price'),
                          style: MartText.itemPrice,
                        ),
                      ),
                    if (product.terms.isNotEmpty) ItemTerms(terms: product.terms),
                    SoldBy(supplier: c.supplier, fallbackName: product.supplierName, loading: c.loadingSupplier),
                    if ((product.description ?? '').isNotEmpty)
                      ItemAbout(title: 'About this product', text: product.description!),
                  ],
          );
        },
      ),
    );
  }
}

class _StockChip extends StatelessWidget {
  const _StockChip({required this.stock});

  final ProductStock stock;

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = switch (stock) {
      ProductStock.inStock => (AppColors.successTint, AppColors.successInk),
      ProductStock.madeToOrder => (AppColors.amber100, AppColors.amber800),
      ProductStock.outOfStock => (AppColors.errorContainer, AppColors.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(10)),
      child: Text(stock.label, style: MartText.groupChip.copyWith(color: ink, fontSize: 12)),
    );
  }
}

// ---- The parts a product or service page shares -----------------------------------------------

/// A page of one product or service: the title bar, what it holds, and the bar
/// pinned at the foot.
class ItemPageFrame extends StatelessWidget {
  const ItemPageFrame({
    super.key,
    required this.title,
    required this.children,
    this.bottom,
    this.error,
    this.loading = false,
    this.onRetry,
  });

  final String title;
  final List<Widget> children;
  final Widget? bottom;
  final String? error;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final nav = MarketplaceScope.navigationOf(context);
    final links = MarketplaceScope.linksOf(context);
    final market = context.watch<MarketplaceController>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TitleBar(
              title: title,
              onBack: () => Navigator.maybePop(context),
              unread: market.unread,
              onBell: () => nav.notifications(context, links),
            ),
            Expanded(
              child: loading
                  ? const PartSpinner()
                  : error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("Couldn't load this page", style: MartText.heading),
                            const SizedBox(height: 6),
                            Text(error!, textAlign: TextAlign.center, style: MartText.body),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              key: const ValueKey('retry'),
                              onPressed: onRetry,
                              child: Text('Try again', style: MartText.sheetLink),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(padding: EdgeInsets.zero, children: [...children, const SizedBox(height: 24)]),
            ),
            ?bottom,
          ],
        ),
      ),
    );
  }
}

/// The photo across the top, or a plain tile with the first letter when there is none.
class ItemHero extends StatelessWidget {
  const ItemHero({super.key, this.imageUrl, this.imageAsset, required this.initial});

  final String? imageUrl;
  final String? imageAsset;
  final String initial;

  @override
  Widget build(BuildContext context) {
    final hasPicture = imageUrl != null || imageAsset != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: AspectRatio(
        aspectRatio: hasPicture ? 16 / 10 : 16 / 6,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: hasPicture
              ? (imageAsset != null
                    ? Image.asset(imageAsset!, fit: BoxFit.cover, filterQuality: FilterQuality.high)
                    : Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _tile()))
              : _tile(),
        ),
      ),
    );
  }

  Widget _tile() => ColoredBox(
    color: AppColors.surfaceContainer,
    child: Center(
      child: Text(
        initial.trim().isEmpty ? '?' : initial.trim().substring(0, 1).toUpperCase(),
        style: MartText.name.copyWith(fontSize: 40, color: AppColors.outline),
      ),
    ),
  );
}

class ItemHeading extends StatelessWidget {
  const ItemHeading({super.key, required this.title, this.chips = const [], this.trailing});

  final String title;
  final List<String> chips;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(title, key: const ValueKey('item-title'), style: MartText.itemTitle),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Padding(padding: const EdgeInsets.only(top: 4), child: trailing),
              ],
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in chips)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(c, style: MartText.groupChip),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A label and what it says, one to a line, in a bordered card.
class ItemFacts extends StatelessWidget {
  const ItemFacts({super.key, required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: MartColors.cardBorder, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) const Hairline(indent: 14, endIndent: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 92, child: Text(row.$1, style: MartText.factLabel)),
                  Expanded(child: Text(row.$2, style: MartText.factValue)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The supplier's own terms, a tick each, only for what is stated.
class ItemTerms extends StatelessWidget {
  const ItemTerms({super.key, required this.terms});

  final List<String> terms;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Supplier terms', style: MartText.heading),
          const SizedBox(height: 8),
          for (final t in terms)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(LucideIcons.circleCheck, size: 15, color: AppColors.tertiary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t, style: MartText.factValue)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ItemAbout extends StatelessWidget {
  const ItemAbout({super.key, required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: MartText.heading),
          const SizedBox(height: 6),
          Text(text, key: const ValueKey('item-about'), style: MartText.body.copyWith(fontSize: 13, height: 1.55)),
        ],
      ),
    );
  }
}

/// "Sold by": the supplier's logo, name, rating and tier; a tap opens its profile.
class SoldBy extends StatelessWidget {
  const SoldBy({super.key, required this.supplier, this.fallbackName, this.loading = false});

  final Supplier? supplier;
  final String? fallbackName;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final s = supplier;
    final name = s?.name ?? fallbackName;
    if (name == null) return const SizedBox.shrink();
    final detail = s == null
        ? (loading ? 'Reading the supplier...' : null)
        : [
            if (s.ratingCount > 0) '★ ${s.ratingLabel} (${s.ratingCount})',
            ?s.level.tier,
            if (s.city != null) s.city!,
          ].join(' • ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: MartColors.cardBorder, width: 1.5),
        ),
        child: InkWell(
          key: const ValueKey('sold-by'),
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onTap: s == null ? null : () => showSupplierSheet(context, s),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: s == null
                      ? Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            name.substring(0, 1).toUpperCase(),
                            style: MartText.name.copyWith(color: AppColors.outline),
                          ),
                        )
                      : SupplierMark(supplier: s, maxWidth: 44, height: 44),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sold by', style: MartText.sheetRowMuted),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: MartText.serviceName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (s != null && s.level.isVerified) ...[
                            const SizedBox(width: 5),
                            const Icon(LucideIcons.badgeCheck, size: 14, color: AppColors.primary),
                          ],
                        ],
                      ),
                      if (detail != null && detail.isNotEmpty)
                        Text(detail, style: MartText.sheetRowMuted, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (s != null) const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The bar pinned under a product or service: the price it names, "Request a quote" and share.
class ItemBar extends StatelessWidget {
  const ItemBar({super.key, required this.label, required this.onPressed, required this.onShare, this.sublabel});

  final String label;
  final String? sublabel;
  final VoidCallback onPressed;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MartColors.barFill,
        border: Border(top: BorderSide(color: MartColors.cardBorder, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    key: const ValueKey('item-quote'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: onPressed,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.zap, size: 14),
                        const SizedBox(width: 8),
                        Text(label, style: MartText.rfqButton),
                        if (sublabel != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '• $sublabel',
                              overflow: TextOverflow.ellipsis,
                              style: MartText.rfqButton.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('item-share'),
                tooltip: 'Share',
                onPressed: onShare,
                icon: const Icon(LucideIcons.share2, size: 20, color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
