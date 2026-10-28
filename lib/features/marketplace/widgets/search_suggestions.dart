import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../catalog_models.dart';
import '../marketplace_controller.dart';
import '../marketplace_models.dart';
import '../marketplace_styles.dart';
import 'supplier_card.dart';

/// What the search box offers while it has focus: with nothing typed, the searches
/// made this session and a few worth trying; with two characters or more, searching
/// for the words, the suppliers whose name matches (a tap opens the profile) and the
/// categories that match (a tap filters to it), as the website's search box groups them.
class SearchSuggestions extends StatelessWidget {
  const SearchSuggestions({
    super.key,
    required this.query,
    required this.onSearch,
    required this.onSupplier,
    required this.onCategory,
  });

  /// The words in the box.
  final String query;

  /// A search to run: a suggestion's words.
  final ValueChanged<String> onSearch;
  final ValueChanged<Supplier> onSupplier;
  final ValueChanged<CategoryNode> onCategory;

  /// Searches worth trying, typed into a search over the English listings.
  static const examples = ['Housekeeping in Bangalore', 'Fire safety companies', 'Facility management Mumbai'];

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketplaceController>();
    final q = query.trim();
    final children = <Widget>[];
    if (q.length < 2) {
      if (market.recentSearches.isNotEmpty) {
        children.add(const _Heading('Recent searches'));
        for (final r in market.recentSearches) {
          children.add(_Row(key: ValueKey('recent-$r'), icon: LucideIcons.history, title: r, onTap: () => onSearch(r)));
        }
      }
      children.add(const _Heading('Try searching'));
      for (final e in examples) {
        children.add(_Row(key: ValueKey('try-$e'), icon: LucideIcons.trendingUp, title: e, onTap: () => onSearch(e)));
      }
    } else {
      children.add(
        _Row(
          key: const ValueKey('search-for'),
          icon: LucideIcons.search,
          title: 'Search for "$q"',
          onTap: () => onSearch(q),
        ),
      );
      final suppliers = market.suggestedFor == q ? market.suggestedSuppliers : const <Supplier>[];
      if (suppliers.isNotEmpty) {
        children.add(const _Heading('Suppliers'));
        for (final s in suppliers) {
          children.add(
            _Row(
              key: ValueKey('suggest-supplier-${s.id}'),
              leading: SizedBox(width: 30, height: 30, child: SupplierMark(supplier: s, maxWidth: 30, height: 30)),
              title: s.name,
              subtitle: s.headline,
              verified: s.level.isVerified,
              onTap: () => onSupplier(s),
            ),
          );
        }
      }
      final categories = market.suggestedCategories(q);
      if (categories.isNotEmpty) {
        children.add(const _Heading('Categories'));
        for (final c in categories) {
          children.add(
            _Row(
              key: ValueKey('suggest-category-${c.node.key}'),
              icon: LucideIcons.layoutGrid,
              title: c.node.name,
              subtitle: c.parent == null ? null : 'in ${c.parent}',
              onTap: () => onCategory(c.node),
            ),
          );
        }
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(text, style: MartText.sheetSection),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.verified = false,
    required this.onTap,
  });

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final bool verified;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            leading ?? SizedBox(width: 30, height: 30, child: Icon(icon, size: 17, color: AppColors.outline)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(title, style: MartText.sheetRow, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (verified) ...[
                        const SizedBox(width: 4),
                        const Icon(LucideIcons.badgeCheck, size: 13, color: AppColors.primary),
                      ],
                    ],
                  ),
                  if ((subtitle ?? '').isNotEmpty)
                    Text(subtitle!, style: MartText.sheetRowMuted, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(LucideIcons.arrowUpLeft, size: 15, color: AppColors.outline),
          ],
        ),
      ),
    );
  }
}
