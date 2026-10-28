import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../catalog_board_controller.dart';
import '../catalog_models.dart';
import '../marketplace_navigation.dart';
import '../marketplace_styles.dart';
import 'supplier_catalog_tab.dart';
import 'supplier_parts.dart';

/// The rows of a catalogue board (products or services) with their states: a
/// spinner while the first page loads, the API's sentence and Try again, an empty
/// note, and "Load more" under the last row. The caller scrolls it.
class CatalogBoardList extends StatelessWidget {
  const CatalogBoardList({super.key, this.emptyTitle = 'Nothing matches', this.emptyBody});

  final String emptyTitle;
  final String? emptyBody;

  @override
  Widget build(BuildContext context) {
    final board = context.watch<CatalogBoardController>();
    if (board.loading && board.items.isEmpty) return const PartSpinner();
    if (board.error != null && board.items.isEmpty) {
      return InlineNotice(message: board.error!, onRetry: board.refresh);
    }
    if (board.items.isEmpty) {
      return EmptyPart(
        title: board.search.isEmpty ? emptyTitle : 'No ${board.kind.label.toLowerCase()} match "${board.search}"',
        body: board.search.isEmpty ? emptyBody : 'Try other words.',
      );
    }
    final nav = MarketplaceScope.navigationOf(context);
    final links = MarketplaceScope.linksOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in board.items)
          if (item is CatalogProduct)
            BoardRow(
              key: ValueKey('board-product-${item.id}'),
              image: ProductImage(product: item, size: 56),
              title: item.name,
              line: item.priceLabel,
              by: item.supplierName,
              verified: item.supplierLevel != null && item.supplierLevel != 'REGISTERED',
              onTap: () => nav.openProduct(context, links, item.id, seed: item),
            )
          else if (item is CatalogService)
            BoardRow(
              key: ValueKey('board-service-${item.id}'),
              image: ServiceImage(service: item, size: 56),
              title: item.name,
              line: item.rateLabel ?? 'Price on request',
              by: item.supplierName,
              verified: item.supplierLevel != null && item.supplierLevel != 'REGISTERED',
              onTap: () => nav.openService(context, links, item.id, seed: item),
            ),
        if (board.hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: board.loadingMore
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                  : TextButton(
                      key: const ValueKey('board-more'),
                      onPressed: board.loadMore,
                      child: Text(
                        'Load more ${board.kind.label.toLowerCase()}',
                        style: MartText.loadMore.copyWith(fontSize: 14),
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}

/// One product or service on a board: its photo, name, price, and who sells it.
class BoardRow extends StatelessWidget {
  const BoardRow({
    super.key,
    required this.image,
    required this.title,
    required this.onTap,
    this.line,
    this.by,
    this.verified = false,
  });

  final Widget image;
  final String title;
  final String? line;
  final String? by;
  final bool verified;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: MartColors.rule, width: 1)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                image,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: MartText.serviceName, maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (line != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          line!,
                          style: MartText.factValue.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (by != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                by!,
                                style: MartText.sheetRowMuted,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (verified) ...[
                              const SizedBox(width: 4),
                              const Icon(LucideIcons.badgeCheck, size: 12, color: AppColors.primary),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
