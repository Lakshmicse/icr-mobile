import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/chips.dart';
import '../account/widgets/account_kit.dart';
import '../site/site_kit.dart';
import 'catalog_models.dart';
import 'catalog_words.dart';

/// The pieces My Products and My Services share, in the app's look: white, hairlines between rows, grey text, the
/// primary blue for what can be pressed.

// --- notes in place of the list ---------------------------------------------------------------------------------------

/// A calm full-page note: the page has no company to show, or is not this person's (the team page's).
class CatalogNote extends StatelessWidget {
  const CatalogNote({super.key, required this.icon, required this.title, required this.text, this.action});

  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      children: [
        Icon(icon, size: 40, color: AppColors.slate400),
        const SizedBox(height: 14),
        Text(title, style: SiteText.heading, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(text, style: SiteText.secondary, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 18), Center(child: action)],
      ],
    );
  }
}

/// The website's `NoCompany`: the catalogue belongs to a company, and this account acts for none.
class NoCompanyNote extends StatelessWidget {
  const NoCompanyNote({super.key, this.onCreateCompany});

  final VoidCallback? onCreateCompany;

  @override
  Widget build(BuildContext context) => CatalogNote(
    key: const Key('catalog.noCompany'),
    icon: Symbols.business,
    title: CatalogWords.noCompanyTitle,
    text: CatalogWords.noCompanyBody,
    action: onCreateCompany == null
        ? null
        : AccountButton(
            key: const Key('catalog.createCompany'),
            label: CatalogWords.createACompany,
            icon: Symbols.add,
            expand: false,
            onPressed: onCreateCompany,
          ),
  );
}

/// The website's `SupplierListingNotice` as a notice above a catalogue that still works: the company does not sell
/// yet, and "Start selling" creates its listing in place.
class NoListingNotice extends StatelessWidget {
  const NoListingNotice({super.key, required this.busy, required this.onStart, this.error});

  final bool busy;
  final VoidCallback onStart;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('catalog.noListing'),
      color: SiteColors.blueTint,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Symbols.storefront, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(CatalogWords.noListing, style: SiteText.body)),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: AccountButton(
              key: const Key('catalog.startSelling'),
              label: busy ? CatalogWords.starting : CatalogWords.startSelling,
              icon: Symbols.storefront,
              busy: busy,
              expand: false,
              height: 38,
              onPressed: onStart,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(error!, key: const Key('catalog.startSelling.error'), style: AccountText.error),
          ],
        ],
      ),
    );
  }
}

/// What the last row action was refused with, above the list.
class CatalogErrorBanner extends StatelessWidget {
  const CatalogErrorBanner({super.key, required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('catalog.error'),
      color: const Color(0xFFFFF1F2),
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: AccountText.error.copyWith(fontSize: 14))),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.slate500),
          ),
        ],
      ),
    );
  }
}

// --- the head of the list -----------------------------------------------------------------------------------------

/// The page's subtitle, the add button and the figures the website's tiles carry, as one compact block.
class CatalogHead extends StatelessWidget {
  const CatalogHead({
    super.key,
    required this.subtitle,
    required this.addLabel,
    required this.onAdd,
    required this.stats,
    this.below = const [],
  });

  final String subtitle;
  final String addLabel;
  final VoidCallback? onAdd;

  /// "3 products · 2 categories · …"; nothing while the list is empty.
  final String? stats;
  final List<Widget> below;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, style: SiteText.secondary),
          const SizedBox(height: 12),
          AccountButton(
            key: const Key('catalog.add'),
            label: addLabel,
            icon: Symbols.add,
            height: 40,
            onPressed: onAdd,
          ),
          if (stats != null) ...[
            const SizedBox(height: 12),
            Text(stats!, key: const Key('catalog.stats'), style: SiteText.meta),
          ],
          ...below,
        ],
      ),
    );
  }
}

/// "4 of 10 listing places used", with what the figure counts and the way out when it is full.
class ListingPlacesLine extends StatelessWidget {
  const ListingPlacesLine({
    super.key,
    required this.used,
    required this.limit,
    required this.products,
    required this.services,
    required this.onSeePlans,
  });

  final int used;
  final int limit;
  final int products;
  final int services;
  final VoidCallback onSeePlans;

  @override
  Widget build(BuildContext context) {
    final full = used >= limit;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        key: const Key('catalog.places'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(CatalogWords.placesUsed(used, limit), style: SiteText.strong),
          const SizedBox(height: 4),
          Text(
            '${CatalogWords.placesCounted(products, services)}${full ? CatalogWords.placesFull : ''}',
            style: SiteText.meta,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (used / (limit < 1 ? 1 : limit)).clamp(0, 1).toDouble(),
              minHeight: 6,
              backgroundColor: AppColors.slate100,
              color: full ? AppColors.amber500 : AppColors.primary,
            ),
          ),
          if (full)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('catalog.seePlans'),
                onPressed: onSeePlans,
                child: Text(CatalogWords.seePlans, style: SiteText.link),
              ),
            ),
        ],
      ),
    );
  }
}

/// A chip that filters or sorts, as the enquiries page draws them: primary when on, outlined otherwise.
class CatalogChip extends StatelessWidget {
  const CatalogChip({
    super.key,
    required this.label,
    required this.onTap,
    this.on = false,
    this.icon,
    this.caret = false,
  });

  final String label;
  final bool on;
  final IconData? icon;
  final bool caret;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IcrChip(
      label: label,
      tone: on ? ChipTone.primary : ChipTone.outlined,
      icon: icon,
      iconSize: 15,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      textStyle: AppText.workSans(13, FontWeight.w600, AppColors.onSurface, lineHeight: 18),
      trailing: caret ? Icon(Icons.expand_more, size: 16, color: on ? Colors.white : AppColors.onSurface) : null,
      onTap: onTap,
    );
  }
}

/// The website's search box over the list: a hairline field with its clear.
class CatalogSearchField extends StatelessWidget {
  const CatalogSearchField({super.key, required this.hint, required this.controller, required this.onChanged});

  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => TextField(
        key: const Key('catalog.search'),
        controller: controller,
        onChanged: onChanged,
        style: SiteText.body,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: SiteText.secondary,
          isDense: true,
          prefixIcon: const Icon(Symbols.search, size: 20, color: AppColors.slate500),
          prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  key: const Key('catalog.search.clear'),
                  tooltip: 'Clear search',
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.slate500),
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: const UnderlineInputBorder(borderSide: BorderSide(color: SiteColors.hairline)),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: SiteColors.hairline)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
        ),
      ),
    );
  }
}

/// The bar that floats while a selection is open: the count, Delete and the clear.
class BulkBar extends StatelessWidget {
  const BulkBar({super.key, required this.count, required this.busy, required this.onDelete, required this.onClear});

  final int count;
  final bool busy;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('catalog.bulk'),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: SiteColors.hairline)),
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(child: Text(CatalogWords.selected(count), style: SiteText.strong)),
              TextButton.icon(
                key: const Key('catalog.bulk.delete'),
                onPressed: busy || count == 0 ? null : onDelete,
                style: TextButton.styleFrom(foregroundColor: AppColors.rose600),
                icon: const Icon(Symbols.delete, size: 18),
                label: Text(CatalogWords.delete),
              ),
              IconButton(
                key: const Key('catalog.bulk.clear'),
                tooltip: CatalogWords.clearSelection,
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.slate500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- rows ------------------------------------------------------------------------------------------------------------

/// The row's status chip, coloured as the website's: green once complete, amber for a gap, plain for "on request".
class CatalogStatusChip extends StatelessWidget {
  const CatalogStatusChip({super.key, required this.status, this.onTap});

  final CatalogStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = switch (status.tone) {
      CatalogStatusTone.success => (AppColors.successTint, AppColors.successInk),
      CatalogStatusTone.warning => (AppColors.amber50, AppColors.amber800),
      CatalogStatusTone.plain => (Colors.white, AppColors.onSurfaceVariant),
    };
    return IcrChip(
      label: status.label,
      tone: status.tone == CatalogStatusTone.plain ? ChipTone.outlined : ChipTone.tinted,
      fill: fill,
      height: 24,
      icon: onTap != null && status.tone != CatalogStatusTone.success ? Icons.add_rounded : null,
      iconSize: 14,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      textStyle: AppText.plexSans(12, FontWeight.w600, ink, lineHeight: 16),
      onTap: onTap,
    );
  }
}

/// "Listing strength 67%" over a thin bar — the website's card foot.
class StrengthBar extends StatelessWidget {
  const StrengthBar({
    super.key,
    required this.score,
    this.missing = '',
    this.label = CatalogWords.listingStrengthLabel,
  });

  final int score;

  /// What the score is called on the page ("Listing Quality" on My Services).
  final String label;

  /// "Add: Photo, Price" for the gaps; the website shows it as the figure's tooltip.
  final String missing;

  @override
  Widget build(BuildContext context) {
    final color = score == 100
        ? AppColors.success
        : score >= 60
        ? AppColors.primary
        : AppColors.amber500;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: SiteText.meta)),
            Text(
              '$score%',
              style: SiteText.meta.copyWith(fontWeight: FontWeight.w700, color: SiteColors.ink),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 5,
            backgroundColor: AppColors.slate100,
            color: color,
          ),
        ),
        if (missing.isNotEmpty) ...[const SizedBox(height: 4), Text(missing, style: SiteText.meta)],
      ],
    );
  }
}

/// The square a row leads with: the product's photo (or a bundled sample), else a glyph on grey.
class CatalogThumb extends StatelessWidget {
  const CatalogThumb({super.key, this.url, this.asset, this.initial, this.icon, this.size = 56});

  final String? url;
  final String? asset;

  /// A service's first letter on the blue tint.
  final String? initial;

  /// A product with no photo shows this glyph.
  final IconData? icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: initial != null ? SiteColors.blueTint : AppColors.surfaceContainer,
      alignment: Alignment.center,
      child: initial != null
          ? Text(initial!, style: AppText.workSans(size * 0.4, FontWeight.w700, AppColors.primary))
          : Icon(icon ?? Symbols.inventory_2, size: size * 0.42, color: AppColors.slate400),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: AccountImage(source: asset != null ? 'asset:$asset' : url, fallback: fallback),
      ),
    );
  }
}

/// A row's own menu: the website's card menu, in a sheet.
Future<T?> showRowMenu<T>(BuildContext context, {required String title, required List<RowAction<T>> actions}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title, style: SiteText.subheading, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          for (final a in actions)
            ListTile(
              key: a.key,
              leading: Icon(a.icon, size: 20, color: a.danger ? AppColors.rose600 : AppColors.onSurfaceVariant),
              title: Text(a.label, style: a.danger ? SiteText.body.copyWith(color: AppColors.rose600) : SiteText.body),
              onTap: () => Navigator.of(sheet).pop(a.value),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class RowAction<T> {
  const RowAction({required this.value, required this.label, required this.icon, this.danger = false, this.key});

  final T value;
  final String label;
  final IconData icon;
  final bool danger;
  final Key? key;
}

/// Asks before a delete, with the website's words. True when confirmed.
Future<bool> confirmCatalogDelete(BuildContext context, {required String title, required String body}) =>
    confirmAction(context, title: title, message: body, confirm: CatalogWords.delete);

/// The frame of a row: a leading piece, its words, the menu button, hairline underneath (the list draws it).
class CatalogRowFrame extends StatelessWidget {
  const CatalogRowFrame({
    super.key,
    required this.leading,
    required this.body,
    required this.onTap,
    required this.onMenu,
    required this.menuLabel,
    this.selectable = false,
    this.selected = false,
    this.busy = false,
  });

  final Widget leading;
  final Widget body;
  final VoidCallback onTap;
  final VoidCallback onMenu;
  final String menuLabel;
  final bool selectable;
  final bool selected;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? SiteColors.blueTint : Colors.white,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectable)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Checkbox(
                    value: selected,
                    onChanged: busy ? null : (_) => onTap(),
                    visualDensity: VisualDensity.compact,
                  ),
                )
              else
                leading,
              const SizedBox(width: 12),
              Expanded(child: body),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (!selectable)
                IconButton(
                  tooltip: menuLabel,
                  onPressed: onMenu,
                  icon: const Icon(Symbols.more_vert, size: 22, color: AppColors.onSurfaceVariant),
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// A heading with its glyph inside an editor, over a hint when there is one (the slide-over's `Section`).
class SheetSection extends StatelessWidget {
  const SheetSection({super.key, required this.icon, required this.title, this.hint, required this.children});

  final IconData icon;
  final String title;
  final String? hint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: AccountText.cardTitle)),
            ],
          ),
          if (hint != null) ...[const SizedBox(height: 4), Text(hint!, style: AccountText.meta)],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

/// The hairline between an editor's sections.
class SheetRule extends StatelessWidget {
  const SheetRule({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: 16),
    child: Divider(height: 1, thickness: 1, color: SiteColors.hairline),
  );
}

/// Quick picks under a free-text field: the common units, the common pricing models. Stored as typed.
class SuggestionChips extends StatelessWidget {
  const SuggestionChips({super.key, required this.options, required this.value, required this.onPick});

  final List<String> options;
  final String value;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final o in options)
            IcrChip(
              key: Key('suggest.$o'),
              label: o,
              tone: value.trim() == o ? ChipTone.primary : ChipTone.filled,
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              textStyle: AppText.plexSans(12, FontWeight.w600, AppColors.onSurface, lineHeight: 16),
              onTap: () => onPick(o),
            ),
        ],
      ),
    );
  }
}

/// The two-level category pair the editors ask for (the website's `CategoryCascadeSelect`): a category, then a
/// sub-category from under it. [required] marks the category; [onClear] lets a product drop its category.
class CategoryCascadeField extends StatelessWidget {
  const CategoryCascadeField({
    super.key,
    required this.tops,
    required this.category,
    required this.subcategory,
    required this.onChanged,
    this.required = false,
    this.clearable = false,
    this.error,
    this.helper,
    this.categoryLabel = CatalogWords.category,
  });

  final List<CatalogCategory> tops;
  final String category;
  final String subcategory;
  final void Function(String category, String subcategory) onChanged;
  final bool required;
  final bool clearable;
  final String? error;
  final String? helper;
  final String categoryLabel;

  CatalogCategory? get _top {
    for (final t in tops) {
      if (t.key == category) return t;
    }
    return null;
  }

  Future<void> _pickCategory(BuildContext context) async {
    final picked = await showAccountPicker<CatalogCategory>(
      context,
      title: categoryLabel,
      items: tops,
      labelOf: (c) => c.name,
      searchable: tops.length > 8,
      selected: _top,
    );
    if (picked == null) return;
    onChanged(picked.key, picked.key == category ? subcategory : '');
  }

  Future<void> _pickSub(BuildContext context) async {
    final top = _top;
    if (top == null) return;
    final children = top.children;
    final picked = await showAccountPicker<CatalogCategory>(
      context,
      title: CatalogWords.subCategory,
      items: children,
      labelOf: (c) => c.name,
      searchable: children.length > 8,
      selected: children.where((c) => c.key == subcategory).firstOrNull,
    );
    if (picked == null) return;
    onChanged(category, picked.key);
  }

  @override
  Widget build(BuildContext context) {
    final top = _top;
    final sub = top?.children.where((c) => c.key == subcategory).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccountSelectField(
          key: const Key('catalog.category'),
          label: categoryLabel,
          hint: CatalogWords.pickACategory,
          value: top?.name ?? (category.isEmpty ? null : prettyKey(category)),
          required: required,
          error: error,
          onTap: () => _pickCategory(context),
          onClear: clearable && category.isNotEmpty ? () => onChanged('', '') : null,
        ),
        AccountSelectField(
          key: const Key('catalog.subcategory'),
          label: CatalogWords.subCategory,
          hint: top == null ? CatalogWords.pickACategoryFirst : CatalogWords.pickASubCategory,
          value: sub?.name ?? (subcategory.isEmpty ? null : prettyKey(subcategory)),
          helper: helper,
          onTap: top == null || top.children.isEmpty ? null : () => _pickSub(context),
          onClear: subcategory.isNotEmpty ? () => onChanged(category, '') : null,
        ),
      ],
    );
  }
}
