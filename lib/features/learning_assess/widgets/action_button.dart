import 'package:flutter/material.dart';

import '../assess_styles.dart';

/// A button of the Assess screens: filled in the card's colour, or outlined in it; a spinner while it works.
///
/// Two sizes. The default is 48 dp tall with a 14 sp label (the sheets' buttons, the plan card's). [compact] is
/// the card's own button on the designs of 29 Oct 2026 (a level card 127 dp wide, a set card): at least [height]
/// tall, a label of [labelStyle] that wraps to a second line rather than being cut, and no room for an icon unless
/// one is asked for.
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.filled = true,
    this.loading = false,
    this.compact = false,
    this.height = 40,
    this.radius,
    this.labelStyle,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// A glyph after the label ("Start Test →").
  final IconData? trailingIcon;
  final bool filled;
  final bool loading;
  final bool compact;

  /// The compact button's least height.
  final double height;
  final double? radius;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final ink = filled ? Colors.white : color;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius ?? (compact ? 8 : 12)),
      side: filled ? BorderSide.none : BorderSide(color: enabled ? color : color.withValues(alpha: 0.35)),
    );
    final base = labelStyle ?? (filled ? AssessText.button : AssessText.buttonOutline);
    final text = Text(
      label,
      style: base.copyWith(color: ink),
      maxLines: compact ? 2 : 1,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
    );
    final lead = loading
        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ink))
        : icon != null
        ? Icon(icon, size: compact ? 16 : 18, color: ink)
        : null;
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (lead != null) ...[lead, SizedBox(width: compact ? 6 : 8)],
        Flexible(child: text),
        if (trailingIcon != null) ...[const SizedBox(width: 6), Icon(trailingIcon, size: 16, color: ink)],
      ],
    );
    return Opacity(
      opacity: enabled || loading ? 1 : 0.55,
      child: Material(
        color: filled ? color : Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onPressed,
          child: compact
              ? ConstrainedBox(
                  constraints: BoxConstraints(minHeight: height),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Center(child: row),
                  ),
                )
              : SizedBox(height: 48, child: row),
        ),
      ),
    );
  }
}
