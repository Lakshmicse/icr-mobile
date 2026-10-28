import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/chips.dart';
import '../marketplace_controller.dart';
import '../marketplace_filters.dart';
import '../marketplace_navigation.dart';
import '../marketplace_styles.dart';
import 'mart_search_field.dart';
import 'market_sheets.dart';

/// Under the title bar: the search, the member's quick chips (Post RFQ, My
/// RFQ's, Alerts) and the filter chips (Filters, Sort, By ratings, Verified
/// only), as the Marketplace design lays them out.
class MarketToolbar extends StatelessWidget {
  const MarketToolbar({
    super.key,
    required this.searchController,
    required this.onSearch,
    this.focusNode,
    this.onChanged,
  });

  final TextEditingController searchController;

  /// The words were submitted (the keyboard's search key, or the cross).
  final ValueChanged<String> onSearch;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketplaceController>();
    final filters = market.filters;
    final nav = MarketplaceScope.navigationOf(context);
    final links = MarketplaceScope.linksOf(context);
    final counts = market.counts;
    final rated = filters.minRating != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: MartSearchField(
            controller: searchController,
            focusNode: focusNode,
            onChanged: onChanged,
            onSubmitted: onSearch,
          ),
        ),
        const SizedBox(height: 5),
        ChipRow(
          children: [
            IcrChip(
              label: 'Post RFQ',
              tone: ChipTone.outlined,
              icon: LucideIcons.circlePlus,
              iconSize: 14.4,
              padding: const EdgeInsets.only(left: 11.4, right: 10.75),
              gap: 6,
              textStyle: MartText.quickChip,
              onTap: () => nav.postRfq(context, links),
            ),
            IcrChip(
              label: 'My RFQ’s',
              tone: ChipTone.outlined,
              icon: LucideIcons.bookmark,
              iconSize: 11.5,
              padding: const EdgeInsets.only(left: 11.2, right: 11.75),
              gap: 4.5,
              textStyle: MartText.quickChip,
              trailing: counts.myRfqs > 0 ? _CountCircle(counts.myRfqs) : null,
              trailingGap: 7.25,
              onTap: () => nav.myRfqs(context, links),
            ),
            IcrChip(
              label: 'Alerts',
              tone: ChipTone.outlined,
              icon: LucideIcons.bellRing,
              iconSize: 12.5,
              padding: const EdgeInsets.only(left: 11.8, right: 12),
              gap: 5.5,
              textStyle: MartText.quickChip,
              trailing: counts.newAlerts > 0 ? _NewPill('${counts.newAlerts} new') : null,
              trailingGap: 8.25,
              onTap: () => nav.alerts(context, links),
            ),
          ],
        ),
        const SizedBox(height: 9),
        _ShadowChips(
          children: [
            IcrChip(
              label: filters.sheetCount > 0 ? 'Filters (${filters.sheetCount})' : 'Filters',
              tone: ChipTone.outlined,
              icon: LucideIcons.slidersHorizontal,
              iconSize: 10.2,
              padding: const EdgeInsets.only(left: 11.6, right: 12.5),
              gap: 3.5,
              textStyle: MartText.filterChip,
              onTap: () => showMarketFilters(context),
            ),
            IcrChip(
              label: 'Sort ${filters.sort.label}',
              tone: ChipTone.outlined,
              padding: const EdgeInsets.only(left: 12.5, right: 9),
              trailing: const Icon(Icons.arrow_drop_down, size: 13, color: AppColors.outline),
              trailingGap: 1,
              textStyle: MartText.filterChip,
              onTap: () => pickSort(context),
            ),
            IcrChip(
              label: rated ? ratingStepLabel(filters.minRating!) : 'By ratings',
              tone: rated ? ChipTone.primary : ChipTone.outlined,
              padding: const EdgeInsets.only(left: 13, right: 9),
              trailing: Icon(Icons.arrow_drop_down, size: 13, color: rated ? Colors.white : AppColors.outline),
              trailingGap: 1,
              textStyle: MartText.filterChip,
              onTap: () => pickRating(context),
            ),
            IcrChip(
              label: 'Verified only',
              tone: ChipTone.outlined,
              icon: LucideIcons.badgeCheck,
              iconSize: 15.5,
              iconColor: filters.verifiedOnly ? AppColors.tertiary : AppColors.outline,
              padding: const EdgeInsets.only(left: 11, right: 12),
              gap: 4.5,
              textStyle: MartText.filterChip.copyWith(
                color: filters.verifiedOnly ? AppColors.onSurface : AppColors.outline,
              ),
              onTap: market.toggleVerifiedOnly,
            ),
          ],
        ),
        // 22 dp from the chips to the first card; the row above already holds 3 dp of shadow room.
        const SizedBox(height: 19),
      ],
    );
  }
}

/// The count after "My RFQ's": a pale circle with the number in blue.
class _CountCircle extends StatelessWidget {
  const _CountCircle(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16.5,
      height: 16.5,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
      child: Text('$count', style: MartText.chipCount),
    );
  }
}

/// "2 new" after Alerts: a blue pill.
class _NewPill extends StatelessWidget {
  const _NewPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 6.75),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: MartText.chipPill),
    );
  }
}

/// `0 1px 2px rgba(0,0,0,.05)`: the soft shadow under the design's filter chips.
const _softShadow = BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1));

/// The row of filter chips: sideways scrolling like [ChipRow], with room under
/// the chips for their shadow (a list would clip it), and 5 dp between them.
class _ShadowChips extends StatelessWidget {
  const _ShadowChips({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 25 + 3,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Align(
          alignment: Alignment.topLeft,
          child: Row(
            children: [
              for (final (i, chip) in children.indexed) ...[
                if (i > 0) const SizedBox(width: 5),
                DecoratedBox(
                  decoration: const ShapeDecoration(shape: StadiumBorder(), shadows: [_softShadow]),
                  child: chip,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
