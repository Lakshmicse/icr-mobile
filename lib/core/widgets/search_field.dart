import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// The pill search box the section screens share: 30 dp tall, a hairline
/// border, the search glyph, then the hint.
class IcrSearchField extends StatelessWidget {
  const IcrSearchField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.hint = 'Search jobs, courses, partners...',
    this.height = 30,
    this.trailing,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final String hint;
  final double height;

  /// Drawn at the right end, inside the border (a filter glyph, say).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Row(
        children: [
          const SizedBox(width: 7),
          const Icon(LucideIcons.search, size: 17.5, color: AppColors.outline),
          const SizedBox(width: 6),
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => TextField(
                controller: controller,
                style: AppText.searchInputSmall,
                // With text, the clear button makes the field taller than a line of
                // text; without this the text rides at the top instead of the middle.
                textAlignVertical: TextAlignVertical.center,
                textInputAction: TextInputAction.search,
                onSubmitted: onSubmitted,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: AppText.searchHintSmall,
                  hintMaxLines: 1,
                  suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          onPressed: () {
                            controller.clear();
                            onSubmitted('');
                          },
                          icon: const Icon(LucideIcons.x, color: AppColors.outline),
                        ),
                ),
              ),
            ),
          ),
          ?trailing,
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}
