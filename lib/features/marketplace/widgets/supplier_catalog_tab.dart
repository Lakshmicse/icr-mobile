import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../catalog_models.dart';
import '../marketplace_controller.dart';
import '../marketplace_navigation.dart';
import '../marketplace_styles.dart';
import '../supplier_controller.dart';
import 'clamped_text.dart';
import 'supplier_parts.dart';

/// "Products & services": the supplier's own services (photo, name, two lines,
/// how fast, and Get Quote or Book Service) and the products it sells, with
/// chips to narrow them to one kind.
class SupplierCatalogTab extends StatefulWidget {
  const SupplierCatalogTab({super.key});

  @override
  State<SupplierCatalogTab> createState() => _SupplierCatalogTabState();
}

class _SupplierCatalogTabState extends State<SupplierCatalogTab> {
  /// `null` is "All"; else a group key (`products`, or a service group's name).
  String? _group;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SupplierController>();
    final market = context.watch<MarketplaceController>();
    final services = c.services;
    final products = c.products;
    final loading = services.loading || products.loading || (!services.loaded && services.error == null);
    final failed = services.error ?? products.error;
    if (loading && !services.loaded && !products.loaded) return const PartSpinner();
    final serviceRows = services.value ?? const <CatalogService>[];
    final productRows = products.value ?? const <CatalogProduct>[];
    final total = serviceRows.length + productRows.length;
    if (total == 0) {
      if (failed != null) return InlineNotice(message: failed, onRetry: () => c.reload(SupplierTab.catalog));
      return const EmptyPart(
        title: 'Nothing listed yet',
        body: 'This supplier has not added products or services. Request a quote and tell them what you need.',
      );
    }
    // The chips: a service's group is its sub-category, else its category, by the name people read.
    String groupOf(CatalogService s) => s.group ?? market.categoryName(s.subcategory ?? s.category ?? 'OTHER');
    final groups = <String>[];
    for (final s in serviceRows) {
      final g = groupOf(s);
      if (!groups.contains(g)) groups.add(g);
    }
    final hasProducts = productRows.isNotEmpty;
    final chips = [if (hasProducts && serviceRows.isNotEmpty) 'Products', ...groups];
    final selected = chips.contains(_group) ? _group : null;
    final shownServices = [
      for (final s in serviceRows)
        if (selected == null || selected == groupOf(s)) s,
    ];
    final shownProducts = selected == null || selected == 'Products' ? productRows : const <CatalogProduct>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (chips.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 9.5, 0, 0),
            child: SizedBox(
              height: 24.25,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _GroupChip(label: 'All ($total)', on: selected == null, onTap: () => setState(() => _group = null)),
                  for (final g in chips) ...[
                    const SizedBox(width: 6),
                    _GroupChip(label: g, on: selected == g, onTap: () => setState(() => _group = g)),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 13),
        if (failed != null) InlineNotice(message: failed, onRetry: () => c.reload(SupplierTab.catalog)),
        for (final s in shownProducts) _ProductRow(key: ValueKey('product-${s.id}'), product: s),
        for (final s in shownServices) _ServiceRow(key: ValueKey('service-${s.id}'), service: s),
      ],
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({required this.label, required this.on, required this.onTap});

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
          child: Container(
            height: 24.25,
            padding: const EdgeInsets.symmetric(horizontal: 13.9),
            alignment: Alignment.center,
            child: Text(label, style: MartText.groupChip.copyWith(color: on ? Colors.white : null)),
          ),
        ),
      ),
    );
  }
}

/// A service of the supplier: 64 dp photo, name, two lines, then how fast and the button.
class _ServiceRow extends StatelessWidget {
  const _ServiceRow({super.key, required this.service});

  final CatalogService service;

  @override
  Widget build(BuildContext context) {
    final c = context.read<SupplierController>();
    final nav = MarketplaceScope.navigationOf(context);
    final links = MarketplaceScope.linksOf(context);
    return CatalogRow(
      image: ServiceImage(service: service),
      title: service.name,
      body: service.description,
      meta: service.turnaround ?? service.rateLabel,
      action: service.action,
      onOpen: () => nav.openService(context, links, service.id, seed: service),
      onAction: () => nav.requestQuote(context, links, c.supplier, service: service),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({super.key, required this.product});

  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    final c = context.read<SupplierController>();
    final nav = MarketplaceScope.navigationOf(context);
    final links = MarketplaceScope.linksOf(context);
    return CatalogRow(
      image: ProductImage(product: product),
      title: product.name,
      body: product.description,
      meta: [?product.priceLabel, ?product.stock?.label].join(' • '),
      action: 'Get Quote',
      onOpen: () => nav.openProduct(context, links, product.id, seed: product),
      onAction: () => nav.requestQuote(context, links, c.supplier, product: product),
    );
  }
}

/// The row of the Products & services tab, as the design draws a service: inset
/// 20 dp, a rule under it.
class CatalogRow extends StatelessWidget {
  const CatalogRow({
    super.key,
    required this.image,
    required this.title,
    required this.onOpen,
    required this.onAction,
    required this.action,
    this.body,
    this.meta,
  });

  final Widget image;
  final String title;
  final String? body;
  final String? meta;
  final String action;
  final VoidCallback onOpen;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: MartColors.rule, width: 1)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10.75, 14, 4.25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: onOpen,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    image,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(title, style: MartText.serviceName, maxLines: 2, overflow: TextOverflow.ellipsis),
                          if ((body ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4.5),
                            // The design keeps the description to about two thirds of the row.
                            FractionallySizedBox(
                              widthFactor: 0.68,
                              alignment: Alignment.centerLeft,
                              child: ClampedText(body!, style: MartText.serviceBody),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                height: 24,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        meta ?? '',
                        style: MartText.serviceMeta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _PillButton(label: action, onTap: onAction),
                  ],
                ),
              ),
              const SizedBox(height: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(side: BorderSide(color: MartColors.cardBorder, width: 1.5));
    return Material(
      color: Colors.white,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 11.5),
          alignment: Alignment.center,
          child: Text(label, style: MartText.serviceButton),
        ),
      ),
    );
  }
}

/// A service's photo: the design's own in demo content, the API's when it has
/// one, else a tile with the service's first letter.
class ServiceImage extends StatelessWidget {
  const ServiceImage({super.key, required this.service, this.size = 64});

  final CatalogService service;
  final double size;

  @override
  Widget build(BuildContext context) => _Photo(
    asset: service.imageAsset,
    url: service.imageUrl,
    initial: service.name.isEmpty ? '?' : service.name.substring(0, 1).toUpperCase(),
    size: size,
  );
}

class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.product, this.size = 64});

  final CatalogProduct product;
  final double size;

  @override
  Widget build(BuildContext context) => _Photo(
    asset: product.imageAsset,
    url: product.imageUrl,
    initial: product.name.isEmpty ? '?' : product.name.substring(0, 1).toUpperCase(),
    size: size,
  );
}

class _Photo extends StatelessWidget {
  const _Photo({required this.asset, required this.url, required this.initial, required this.size});

  final String? asset;
  final String? url;
  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget tile() => Container(
      color: AppColors.surfaceContainer,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: MartText.name.copyWith(color: AppColors.outline, fontSize: size * 0.38),
      ),
    );
    Widget child;
    if (asset != null) {
      child = Image.asset(asset!, width: size, height: size, fit: BoxFit.cover, filterQuality: FilterQuality.high);
    } else if (url != null) {
      child = Image(
        image: CachedNetworkImageProvider(url!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => tile(),
      );
    } else {
      child = tile();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}
