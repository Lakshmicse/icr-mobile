import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../learning_styles.dart';

/// The bar pinned under the course sheet: the brochure glyph and the short
/// "add to cart". 50.6 dp, as the design draws it — lower than the kit's
/// `BottomActionBar` (72 dp with 48 dp controls), so the feature keeps its own.
/// The button is 123 × 35 dp with 8 dp above it and 15.5 dp to its right; the
/// glyph centres at 223 dp from the left.
class CourseBottomBar extends StatelessWidget {
  const CourseBottomBar({
    super.key,
    required this.label,
    required this.onAction,
    required this.onBrochure,
    this.icon = Symbols.shopping_bag,
    this.enabled = true,
    this.held = false,
  });

  static const height = 50.6;
  static const buttonWidth = 123.0;
  static const buttonHeight = 35.0;

  final String label;
  final IconData icon;
  final bool enabled;

  /// The member already holds a place: the button is drawn solid, as done.
  final bool held;
  final VoidCallback onAction;
  final VoidCallback onBrochure;

  @override
  Widget build(BuildContext context) {
    final color = enabled || held ? AppColors.primary : AppColors.primary.withValues(alpha: 0.5);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        // Fitted to the design: about 5 % black at the bar's edge, fading out over 11 dp above it.
        boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 16)],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.only(top: 8.3),
            child: Align(
              alignment: Alignment.topCenter,
              child: Row(
                children: [
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: 'Download brochure',
                    child: InkResponse(
                      onTap: onBrochure,
                      radius: 22,
                      child: const SizedBox(
                        width: 36,
                        height: buttonHeight,
                        child: Icon(Symbols.download, size: 18, weight: 700, color: AppColors.onSurface),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10.8),
                  Material(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: enabled || held ? onAction : null,
                      borderRadius: BorderRadius.circular(8),
                      // 123 × 35 dp for "add to cart"; a longer word ("enrolment closed") widens it.
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: buttonWidth,
                          minHeight: buttonHeight,
                          maxHeight: buttonHeight,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 16, weight: 600, color: Colors.white),
                            const SizedBox(width: 5.6),
                            Text(label, style: LearningText.barButton),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15.5),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
