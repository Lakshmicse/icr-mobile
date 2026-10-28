import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

enum ChipTone {
  /// Light grey fill, no border.
  filled,

  /// White with a hairline border.
  outlined,

  /// Primary blue with white text: the chip that is on.
  primary,

  /// A tinted fill with its own text colour (the green "Profile Match").
  tinted,
}

/// The pill chips of the section screens: an optional glyph, the label, and
/// an optional trailing piece (a count, a caret, a tick).
class IcrChip extends StatelessWidget {
  const IcrChip({
    super.key,
    required this.label,
    this.tone = ChipTone.filled,
    this.icon,
    this.iconSize = 14,
    this.iconColor,
    this.leading,
    this.trailing,
    this.onTap,
    this.height = 25,
    this.padding = const EdgeInsets.only(left: 10, right: 12),
    this.gap = 6,
    this.trailingGap = 8,
    this.textStyle,
    this.fill,
    this.border,
  });

  final String label;
  final ChipTone tone;
  final IconData? icon;
  final double iconSize;
  final Color? iconColor;

  /// Instead of [icon].
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double height;
  final EdgeInsets padding;
  final double gap;
  final double trailingGap;
  final TextStyle? textStyle;

  /// For [ChipTone.tinted].
  final Color? fill;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      ChipTone.filled => AppColors.surfaceContainer,
      ChipTone.outlined => Colors.white,
      ChipTone.primary => AppColors.primary,
      ChipTone.tinted => fill ?? AppColors.surfaceContainer,
    };
    final side = switch (tone) {
      ChipTone.outlined => const BorderSide(color: AppColors.outlineVariant),
      ChipTone.tinted when border != null => BorderSide(color: border!),
      _ => BorderSide.none,
    };
    final style = (textStyle ?? AppText.chipLabel).copyWith(color: tone == ChipTone.primary ? Colors.white : null);
    final glyphColor = iconColor ?? style.color ?? AppColors.onSurface;
    final shape = StadiumBorder(side: side);
    return Semantics(
      button: onTap != null,
      selected: tone == ChipTone.primary,
      child: Material(
        color: color,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: padding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[leading!, SizedBox(width: gap)],
                  if (icon != null) ...[Icon(icon, size: iconSize, color: glyphColor), SizedBox(width: gap)],
                  // A label wider than the chip's room gives way to an ellipsis rather than overflow.
                  Flexible(child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (trailing != null) ...[SizedBox(width: trailingGap), trailing!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A count in a small circle ("3" beside My jobs).
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key, this.size = 18});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: Text('$count', style: AppText.badgeCount),
    );
  }
}

/// A short word in a primary pill ("2 new").
class PillBadge extends StatelessWidget {
  const PillBadge(this.label, {super.key, this.color = AppColors.primary, this.textColor = Colors.white});

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: AppText.badgeCount.copyWith(color: textColor)),
    );
  }
}

/// Chips in a row that scrolls sideways, inset like the screens' margins.
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.children, this.height = 25, this.gap = 5, this.padding = 10});

  final List<Widget> children;
  final double height;
  final double gap;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: padding),
        itemCount: children.length,
        separatorBuilder: (_, _) => SizedBox(width: gap),
        itemBuilder: (context, i) => children[i],
      ),
    );
  }
}
