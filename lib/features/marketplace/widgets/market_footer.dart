import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../marketplace_controller.dart';
import '../marketplace_models.dart';
import '../marketplace_styles.dart';

/// Under the grid: "Showing 10 of 180+ verified enterprise suppliers", a bar
/// that fills as more are shown, and "Load more suppliers".
class MarketFooter extends StatelessWidget {
  const MarketFooter({super.key});

  /// The bar never shows less than this much, so it always reads as a bar.
  static const minFill = 0.14;

  /// What the footer calls the suppliers it is counting.
  static String noun(MarketplaceController market) {
    final f = market.filters;
    if (f.savedOnly) return 'saved suppliers';
    return f.verifiedOnly ? 'verified enterprise suppliers' : 'enterprise suppliers';
  }

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketplaceController>();
    final shown = market.suppliers.length;
    final total = market.total < shown ? shown : market.total;
    final fill = total == 0 ? 0.0 : (shown / total).clamp(minFill, 1.0);
    return Column(
      children: [
        const SizedBox(height: 18),
        Text(
          'Showing $shown of ${roughTotal(total)} ${noun(market)}',
          key: const ValueKey('showing'),
          style: MartText.showing,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 240,
          height: 6.5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3.25),
            child: Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: AppColors.outlineVariant)),
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: fill,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(3.25)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (market.hasMore)
          SizedBox(
            height: 44,
            child: market.loadingMore
                ? const Center(
                    child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
                  )
                : TextButton(
                    key: const ValueKey('load-more'),
                    onPressed: market.loadMore,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Load more suppliers', style: MartText.loadMore),
                        const SizedBox(width: 3.5),
                        const Icon(LucideIcons.chevronDown, size: 14, color: AppColors.primary),
                      ],
                    ),
                  ),
          ),
        const SizedBox(height: 28),
      ],
    );
  }
}
