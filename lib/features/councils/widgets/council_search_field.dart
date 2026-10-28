import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../councils_styles.dart';

/// The Councils design's search box: 35 dp, a stadium with a light border,
/// the search glyph, the hint, and the filter glyph at the right. A copy of
/// `IcrSearchField` sized to this design (its hint is 12 dp; this one is
/// 10.5, with a 14 dp glyph).
class CouncilSearchField extends StatelessWidget {
  const CouncilSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onFilters,
    this.hint = 'Search councils by name, topic, or leader...',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilters;
  final String hint;

  static const height = 35.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: CouncilsColors.cardBorder),
      ),
      child: Row(
        children: [
          const SizedBox(width: 13),
          const Icon(LucideIcons.search, size: 15, color: AppColors.slate400),
          const SizedBox(width: 9),
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => TextField(
                controller: controller,
                style: CouncilsText.searchInput,
                textInputAction: TextInputAction.search,
                onChanged: onChanged,
                onSubmitted: onChanged,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: CouncilsText.searchHint,
                  hintMaxLines: 1,
                  suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          padding: EdgeInsets.zero,
                          iconSize: 14,
                          onPressed: () {
                            controller.clear();
                            onChanged('');
                          },
                          icon: const Icon(LucideIcons.x, color: AppColors.outline),
                        ),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Sort councils',
            child: InkResponse(
              onTap: onFilters,
              radius: 18,
              child: const SizedBox(
                width: 30,
                height: 30,
                child: Icon(LucideIcons.slidersHorizontal, size: 14, color: AppColors.slate400),
              ),
            ),
          ),
          const SizedBox(width: 2),
        ],
      ),
    );
  }
}
