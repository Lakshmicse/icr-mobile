import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../study_styles.dart';

/// "Categories" and the deck's category chips (flashcards-study.png): a wrap over the whole width, the lit chip
/// filled with the primary blue and the others soft grey, 24 dp tall with 6 dp between them. A tap lights one and
/// the pass is over its cards; "All" is the whole deck again.
///
/// Every chip sits in a [StudyCategories.rowHeight] row (29 dp, the design's pitch), so the tappable area is the
/// chip and the 2.5 dp above and below it. A deck with many categories shows [maxRows] rows and scrolls the rest
/// inside its own box, so the card is never pushed off a short screen.
class StudyCategories extends StatelessWidget {
  const StudyCategories({
    super.key,
    required this.names,
    required this.selected,
    required this.onSelect,
    required this.maxRows,
  });

  /// One chip's row: the 24 dp chip and 2.5 dp of tappable margin on each side.
  static const rowHeight = 29.0;

  final List<String> names;

  /// The lit category; null lights "All".
  final String? selected;

  /// A category's name, or null for "All".
  final ValueChanged<String?> onSelect;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Categories', style: StudyText.categories),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxRows * rowHeight),
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                key: const ValueKey('study-categories'),
                physics: const ClampingScrollPhysics(),
                child: Wrap(
                  spacing: 6,
                  children: [
                    StudyChip(
                      key: const ValueKey('study-chip-all'),
                      label: 'All',
                      lit: selected == null,
                      maxWidth: box.maxWidth,
                      onTap: () => onSelect(null),
                    ),
                    for (final name in names)
                      StudyChip(
                        key: ValueKey('study-chip-$name'),
                        label: name,
                        lit: selected == name,
                        maxWidth: box.maxWidth,
                        onTap: () => onSelect(name),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, thickness: 1, color: StudyColors.rule),
        ],
      ),
    );
  }
}

/// One category chip.
class StudyChip extends StatelessWidget {
  const StudyChip({super.key, required this.label, required this.lit, required this.onTap, required this.maxWidth});

  final String label;
  final bool lit;
  final VoidCallback onTap;

  /// The row's width: a name longer than that gives way to an ellipsis.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: lit,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: lit ? AppColors.primary : StudyColors.chipFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(
                height: 24,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StudyText.chip.copyWith(color: lit ? Colors.white : StudyColors.chipInk),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
