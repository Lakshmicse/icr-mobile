import 'package:flutter/material.dart';

import '../hub_styles.dart';

/// "Assess Your Knowledge ........ View More": a section's heading as the
/// Learning hub design draws it — a 20 dp line (Work Sans 15.6) 16 dp in on
/// the left with "View More" ending 27.75 dp from the right — in a 36 dp row,
/// so the action is a tap target a thumb can hit. The export's heading line
/// sits 12 dp (cap top) under the row's top and its content starts at the
/// row's foot, so nothing goes between a row and what it heads.
class HubSectionHeading extends StatelessWidget {
  const HubSectionHeading({super.key, required this.title, this.action = 'View More', this.onAction});

  static const height = 36.0;

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final hasAction = action != null && onAction != null;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: Text(title, style: HubText.section, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (hasAction)
            Semantics(
              button: true,
              label: '$action, $title',
              excludeSemantics: true,
              onTap: onAction,
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: height,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    // The export sets "View More" 2 dp above the heading's own baseline.
                    child: Center(
                      // Moved, not padded: the line keeps its whole box at any text size.
                      child: Transform.translate(
                        offset: const Offset(0, -2),
                        child: Text(action!, style: HubText.viewMore),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          SizedBox(width: hasAction ? 21.75 : 27.75),
        ],
      ),
    );
  }
}

/// The 1 dp rule between the design's sections.
class HubRule extends StatelessWidget {
  const HubRule({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: HubColors.rule,
    child: SizedBox(height: 1, width: double.infinity),
  );
}
