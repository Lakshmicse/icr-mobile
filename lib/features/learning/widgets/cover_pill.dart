import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../learning_styles.dart';

/// The pill over a cover's top or bottom left ("PREMIUM CERTIFICATION"): frosted
/// glass over the blurred picture with a lighter hairline.
///
/// On the course sheet it is the design's own, white at 20 %: 25.8 dp tall with
/// 12.4 dp each side of the words and 3 dp corners. [compact] is the catalogue
/// card's: 20 dp tall in smaller type, tinted navy so it reads over a light cover,
/// and it gives way to its ellipsis rather than overflow a narrow card.
class CoverPill extends StatelessWidget {
  const CoverPill(this.text, {super.key, this.compact = false});

  /// Where the sheet's pill sits: 12.4 dp in from the cover's left edge and 15.2
  /// dp above the bottom of its 160 dp frame.
  static const left = 12.4;
  static const bottom = 15.2;
  static const height = 25.8;
  static const compactHeight = 20.0;

  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(compact ? 4 : 3);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Container(
          height: compact ? compactHeight : height,
          padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 11.4),
          decoration: BoxDecoration(
            color: compact ? LearningColors.pillCardFill : LearningColors.pillFill,
            border: Border.all(color: LearningColors.pillBorder),
            borderRadius: radius,
          ),
          // widthFactor: 1 keeps the pill as wide as its words even where it is given a tight width.
          child: Center(
            widthFactor: 1,
            child: Text(
              text,
              style: compact ? LearningText.cardBadge : LearningText.badge,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
