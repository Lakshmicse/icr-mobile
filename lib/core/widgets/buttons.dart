import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// The wide blue button (Easy Apply, Book Trial, Add to cart).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.height = 48,
    this.radius = 12,
    this.color = AppColors.primary,
    this.textStyle,
    this.iconSize = 16,
    this.gap = 8,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;
  final double radius;
  final Color color;
  final TextStyle? textStyle;
  final double iconSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final style = textStyle ?? AppText.primaryButton;
    final enabled = onPressed != null;
    return Material(
      color: enabled ? color : color.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: iconSize, color: style.color), SizedBox(width: gap)],
              Text(label, style: style),
            ],
          ),
        ),
      ),
    );
  }
}

/// The light grey square with one glyph beside a primary button.
class SoftIconButton extends StatelessWidget {
  const SoftIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
    this.size = 48,
    this.iconSize = 22,
    this.radius = 12,
    this.color = AppColors.surfaceContainer,
    this.iconColor = AppColors.onSurface,
    this.selected = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? label;
  final double size;
  final double iconSize;
  final double radius;
  final Color color;
  final Color iconColor;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      selected: selected,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: iconSize, color: iconColor),
          ),
        ),
      ),
    );
  }
}

/// A white outlined pill button ("Message", "Book Now").
class OutlinePillButton extends StatelessWidget {
  const OutlinePillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 26,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.textStyle,
    this.borderColor = const Color(0xFFE9EAEB),
  });

  final String label;
  final VoidCallback onPressed;
  final double height;
  final EdgeInsets padding;
  final TextStyle? textStyle;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(side: BorderSide(color: borderColor));
    return Material(
      color: Colors.white,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onPressed,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: padding,
            child: Center(widthFactor: 1, child: Text(label, style: textStyle ?? AppText.outlineButton)),
          ),
        ),
      ),
    );
  }
}

/// The bar pinned under a detail page: white, a soft shadow above, 12 dp of
/// padding around 48 dp controls, plus the system inset.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.children, this.gap = 12});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              for (final (i, child) in children.indexed) ...[if (i > 0) SizedBox(width: gap), child],
            ],
          ),
        ),
      ),
    );
  }
}
