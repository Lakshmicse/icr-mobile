import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../site/site_kit.dart';
import '../company_words.dart';
import '../supplier_checklist.dart';

/// The pieces the company workspace's cards share, in the owner's language: white, the sections parted by hairlines,
/// full-width rows, dark and light grey text, blue only for what can be pressed.

class CompanyText {
  CompanyText._();

  static final eyebrow = AppText.plexSans(11, FontWeight.w700, AppColors.primary, lineHeight: 16, spacing: 0.5);
  static final score = AppText.plexSans(18, FontWeight.w600, SiteColors.ink, lineHeight: 24);
  static final figure = AppText.plexSans(22, FontWeight.w600, SiteColors.ink, lineHeight: 28);
  static final tab = AppText.plexSans(14, FontWeight.w600, SiteColors.secondary, lineHeight: 20);
  static final tabOn = AppText.plexSans(14, FontWeight.w600, AppColors.primary, lineHeight: 20);
  static final label = AppText.plexSans(12, FontWeight.w500, SiteColors.secondary, lineHeight: 16);
  static final overline = AppText.plexSans(11, FontWeight.w700, SiteColors.secondary, lineHeight: 16, spacing: 0.5);
}

const hairline = Divider(height: 1, thickness: 1, color: SiteColors.hairline);

/// The 36 dp rounded square with the card's glyph, as the website's icon tile.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(color: SiteColors.blueTint, borderRadius: BorderRadius.circular(10)),
    child: Icon(icon, size: 20, color: AppColors.primary),
  );
}

/// A section the width of the page: the glyph, its title and caption, then its rows, and a hairline under it all.
class CompanySection extends StatelessWidget {
  const CompanySection({
    super.key,
    required this.title,
    required this.children,
    this.caption,
    this.icon,
    this.trailing,
    this.titleKey,
  });

  final String title;
  final String? caption;
  final IconData? icon;
  final Widget? trailing;
  final List<Widget> children;

  /// A key on the title, for a test or a scroll.
  final Key? titleKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[IconTile(icon!), const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, key: titleKey, style: SiteText.subheading),
                    if (caption != null) ...[const SizedBox(height: 2), Text(caption!, style: SiteText.meta)],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
        ...children,
        const SizedBox(height: 4),
        hairline,
        const SizedBox(height: 6),
      ],
    );
  }
}

/// One row of a section, a hairline above it.
class CompanyRow extends StatelessWidget {
  const CompanyRow({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
    this.rule = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final bool rule;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rule) const Divider(height: 1, thickness: 1, color: SiteColors.hairline, indent: 16),
        onTap == null ? body : InkWell(onTap: onTap, child: body),
      ],
    );
  }
}

/// A fact as the read-only details show it: the label over the value, a lock beside a value a verified company may no
/// longer change, and "Not added yet" for a blank.
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, this.value, this.locked = false, this.caption});

  final String label;
  final String? value;
  final bool locked;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final v = value;
    return CompanyRow(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: CompanyText.label),
                const SizedBox(height: 2),
                Text(
                  v == null || v.isEmpty ? CompanyWords.notSet : v,
                  style: v == null || v.isEmpty ? SiteText.secondary : SiteText.body,
                ),
                if (caption != null) ...[const SizedBox(height: 2), Text(caption!, style: SiteText.meta)],
              ],
            ),
          ),
          if (locked)
            const Padding(
              padding: EdgeInsets.only(left: 8, top: 14),
              child: Icon(Symbols.lock, size: 16, color: AppColors.slate400),
            ),
        ],
      ),
    );
  }
}

/// A short status label, by tone.
enum StatusTone { success, warning, error, info, neutral }

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, required this.tone, this.icon, this.filled = false});

  final String label;
  final StatusTone tone;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = switch (tone) {
      StatusTone.success => (AppColors.emerald50, AppColors.emerald700),
      StatusTone.warning => (AppColors.amber50, AppColors.amber800),
      StatusTone.error => (const Color(0xFFFFE4E6), const Color(0xFFBE123C)),
      StatusTone.info => (AppColors.chipEmphasis, AppColors.primary),
      StatusTone.neutral => (AppColors.slate100, AppColors.slate700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? fill : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: filled ? fill : ink.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: ink), const SizedBox(width: 4)],
          Text(label, style: AppText.plexSans(12, FontWeight.w600, ink, lineHeight: 16)),
        ],
      ),
    );
  }
}

/// A tinted strip with a glyph and a sentence (an alert).
class NoticeStrip extends StatelessWidget {
  const NoticeStrip({super.key, required this.text, this.tone = StatusTone.info, this.action, this.textKey});

  final String text;
  final StatusTone tone;
  final Widget? action;
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final (fill, ink, icon) = switch (tone) {
      StatusTone.success => (AppColors.emerald50, AppColors.emerald700, Symbols.check_circle),
      StatusTone.warning => (AppColors.amber50, AppColors.amber800, Symbols.warning),
      StatusTone.error => (const Color(0xFFFFF1F2), const Color(0xFFBE123C), Symbols.error),
      _ => (SiteColors.blueTint, AppColors.primary, Symbols.info),
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: ink),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, key: textKey, style: SiteText.body),
          ),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}

/// A text-only button in the brand blue, as the website's small buttons.
class LinkButton extends StatelessWidget {
  const LinkButton(this.label, {super.key, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null ? AppColors.slate400 : AppColors.primary;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: 6)],
          Text(label, style: SiteText.link.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// The page's tabs: text with an underline under the open one, a hairline under the row (LinkedIn's company page).
class CompanyTabs extends StatelessWidget {
  const CompanyTabs({super.key, required this.labels, required this.selected, required this.onSelect});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final (i, label) in labels.indexed)
                Semantics(
                  button: true,
                  selected: i == selected,
                  child: InkWell(
                    key: ValueKey('company-tab-$i'),
                    onTap: () => onSelect(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: i == selected ? AppColors.primary : Colors.transparent, width: 2),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(label, style: i == selected ? CompanyText.tabOn : CompanyText.tab),
                    ),
                  ),
                ),
            ],
          ),
        ),
        hairline,
      ],
    );
  }
}

/// The five rungs as a bar: the ones reached in green, the names under them.
class LevelLadder extends StatelessWidget {
  const LevelLadder({super.key, required this.level});

  final String? level;

  @override
  Widget build(BuildContext context) {
    final rank = levelRank(level);
    return Row(
      children: [
        for (final (i, l) in verificationLevels.indexed) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: i < rank ? AppColors.success : AppColors.slate100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  levelLabel(l),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.plexSans(
                    10,
                    i == rank - 1 ? FontWeight.w600 : FontWeight.w400,
                    i == rank - 1 ? SiteColors.ink : SiteColors.secondary,
                    lineHeight: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The supplier trust mark: a glyph and the level's name, coloured by level, with the caption from Verified up.
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level, this.caption = false, this.small = false});

  final String? level;
  final bool caption;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final l = level ?? 'REGISTERED';
    final (color, icon) = switch (l) {
      'VERIFIED' => (AppColors.primary, Symbols.verified),
      'CERTIFIED' => (const Color(0xFF0E7490), Symbols.workspace_premium),
      'PREFERRED' => (AppColors.emerald700, Symbols.star),
      'ELITE' => (AppColors.amber800, Symbols.military_tech),
      _ => (AppColors.inkMuted, Symbols.how_to_reg),
    };
    final pill = Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 7 : 9, vertical: small ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: small ? 13 : 16, color: color),
          const SizedBox(width: 4),
          Text(levelLabel(l), style: AppText.plexSans(small ? 11 : 12.5, FontWeight.w700, color, lineHeight: 16)),
        ],
      ),
    );
    if (!caption || levelRank(l) < 2) return pill;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pill,
        const SizedBox(width: 8),
        Text(CompanyWords.badgeCaption, style: SiteText.meta.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// "18 Oct 2026" from a date; '' from none.
String dayOf(DateTime? d) {
  if (d == null) return '';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final l = d.toLocal();
  return '${l.day} ${months[l.month - 1]} ${l.year}';
}

/// A website as people read it: no scheme, no trailing slash.
String bareHost(String url) =>
    url.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '').replaceFirst(RegExp(r'/$'), '');
