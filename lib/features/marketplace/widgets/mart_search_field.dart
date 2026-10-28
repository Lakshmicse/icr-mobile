import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../marketplace_styles.dart';

/// The Marketplace's search box: the shared pill, but set a size larger than
/// the Jobs one, as the design draws it (14 dp hint, a solid search glyph).
class MartSearchField extends StatelessWidget {
  const MartSearchField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.onChanged,
    this.focusNode,
    this.hint = 'Search suppliers, services, RFQs...',
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  /// Called as the words change (a list that narrows while typing).
  final ValueChanged<String>? onChanged;

  /// Lets the screen see when the box has focus (it offers suggestions then).
  final FocusNode? focusNode;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Row(
        children: [
          const SizedBox(width: 6.7),
          const Icon(Icons.search, size: 18.2, color: AppColors.outline),
          const SizedBox(width: 5.6),
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => TextField(
                key: const ValueKey('market-search'),
                controller: controller,
                focusNode: focusNode,
                style: MartText.searchInput,
                textAlignVertical: TextAlignVertical.center,
                textInputAction: TextInputAction.search,
                onSubmitted: onSubmitted,
                onChanged: onChanged,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: MartText.searchHint,
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
                            onChanged?.call('');
                            onSubmitted('');
                          },
                          icon: const Icon(LucideIcons.x, color: AppColors.outline),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}
