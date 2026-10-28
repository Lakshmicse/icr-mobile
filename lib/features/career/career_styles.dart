import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// Type and shapes for the career screens, in the Jobs screens' language
/// (Work Sans for names and headings, IBM Plex Sans for the rest).
class CareerText {
  CareerText._();

  static final companyName = AppText.workSans(15, FontWeight.w700, AppColors.slate900, lineHeight: 20);
  static final companyMeta = AppText.plexSans(11, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 15);
  static final bigNumber = AppText.workSans(28, FontWeight.w700, AppColors.slate900, lineHeight: 32);
  static final heading = AppText.workSans(12, FontWeight.w700, AppColors.slate900, lineHeight: 17);
  static final cardTitle = AppText.workSans(12.5, FontWeight.w700, AppColors.slate900, lineHeight: 17);
  static final body = AppText.plexSans(11.5, FontWeight.w500, AppColors.onSurfaceVariant, lineHeight: 17);
  static final bodyStrong = AppText.plexSans(11.5, FontWeight.w600, AppColors.onSurface, lineHeight: 17);
  static final label = AppText.plexSans(9.5, FontWeight.w700, AppColors.outline, lineHeight: 13, spacing: 0.3);
  static final meta = AppText.plexSans(10, FontWeight.w500, AppColors.outline, lineHeight: 14);
  static final metaStrong = AppText.plexSans(10, FontWeight.w600, AppColors.onSurfaceVariant, lineHeight: 14);
  static final pill = AppText.plexSans(9, FontWeight.w700, AppColors.successInk, lineHeight: 12);
  static final money = AppText.workSans(16, FontWeight.w700, AppColors.slate900, lineHeight: 22);
  static final link = AppText.plexSans(11, FontWeight.w600, AppColors.primary, lineHeight: 15);
  static final tabLabel = AppText.plexSans(11, FontWeight.w600, AppColors.onSurface, lineHeight: 15);
}

/// A white card with a hairline border, as the Jobs sheet's blocks.
BoxDecoration cardDecoration({Color color = Colors.white}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: AppColors.outlineVariant),
);

/// Stars filled to [value] (halves drawn), 1 to 5.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.value, this.size = 14});

  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            value >= i - 0.25
                ? Icons.star_rounded
                : value >= i - 0.75
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded,
            size: size,
            color: AppColors.amber500,
          ),
      ],
    );
  }
}

/// Five stars to tap; tapping the star already chosen clears it.
class StarPicker extends StatelessWidget {
  const StarPicker({super.key, required this.value, required this.onChanged, this.size = 28, this.keyPrefix = 'star'});

  final int value;
  final ValueChanged<int> onChanged;
  final double size;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Semantics(
            button: true,
            selected: value == i,
            label: '$i star${i == 1 ? '' : 's'}',
            child: InkResponse(
              key: ValueKey('$keyPrefix-$i'),
              radius: size * 0.7,
              onTap: () => onChanged(value == i ? 0 : i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Icon(
                  i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: size,
                  color: i <= value ? AppColors.amber500 : AppColors.slate300,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
