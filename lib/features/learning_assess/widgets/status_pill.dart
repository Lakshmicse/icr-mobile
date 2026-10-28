import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../assess_styles.dart';

enum PillTone { success, solidSuccess, info, neutral, warn }

/// A small rounded word on a card's foot or header ("Passed 2/3", "Locked", "CERTIFIED").
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.tone = PillTone.neutral, this.icon, this.height = 22});

  final String label;
  final PillTone tone;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = switch (tone) {
      PillTone.success => (AppColors.successTint, AppColors.successInk),
      PillTone.solidSuccess => (AppColors.successInk, Colors.white),
      PillTone.info => (AppColors.chipEmphasis, AppColors.primary),
      PillTone.warn => (AppColors.amber100, AppColors.amber800),
      PillTone.neutral => (AppColors.slate100, AppColors.slate600),
    };
    return Container(
      height: height,
      padding: EdgeInsets.only(left: icon == null ? 8 : 6, right: 8),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(height / 2)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: ink), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              style: AssessText.cardPill.copyWith(color: ink),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
