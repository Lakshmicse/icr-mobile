import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../assess_format.dart';
import '../assess_styles.dart';

/// What a programme with no sentence of its own says about its topics, as the design words it.
const defaultAreasBlurb = 'Standard domain syllabus evaluated across all credential tiers and professional tracks.';

/// "Knowledge areas covered": a heading with the topic count in a mint pill, a line about them, and the topics as
/// chips — each a dot and a label, tinted in the design's families (blue, green, blue…, six to a family).
///
/// The topics are the programme's own (`knowledgeAreas`); this is not drawn for a programme that has none. The
/// first [foldedRows] rows show and the rest unfold on "View more", so a programme with forty topics, or with long
/// ones (the live API's "Facilities Asset Management Cycle" takes a row to itself), does not push its levels off
/// the screen. (A count would not do: the owner's rule of 30 Oct 2026 is that the levels stay in the first view,
/// and a row holds one long topic or three short.)
class KnowledgeAreas extends StatelessWidget {
  const KnowledgeAreas({
    super.key,
    required this.areas,
    required this.blurb,
    required this.showAll,
    required this.onToggle,
  });

  /// How many rows of topics show before "View more" (owner, 3 Nov 2026: "show for two lines and give view more
  /// option" — eight rows of the live API's long topics still pushed the levels under the fold).
  static const foldedRows = 2;

  /// The gap between chips and between rows.
  static const spacing = 6.0;

  /// A chip's width beyond its label: the dot and the paddings around it (see [TopicChip]).
  static const chipChrome = 9.0 + 7 + 5 + 11;

  /// Topics to a tint before the next family begins.
  static const family = 6;

  final List<String> areas;

  /// The programme's own summary, else [defaultAreasBlurb].
  final String blurb;
  final bool showAll;
  final VoidCallback onToggle;

  /// How many of [areas] the first [foldedRows] rows hold at [width], packed as a [Wrap] packs them (a chip joins
  /// the row while it fits after the gap; one wider than the row is cut to it, as [TopicChip] cuts its label).
  static int fitting(List<String> areas, double width, TextScaler scaler) {
    var rows = 1;
    var x = 0.0;
    var count = 0;
    for (final area in areas) {
      final painter = TextPainter(
        text: TextSpan(text: area, style: AssessText.topicChip),
        maxLines: 1,
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      final w = math.min(painter.width + chipChrome, width);
      if (x > 0 && x + spacing + w > width) {
        rows++;
        if (rows > foldedRows) break;
        x = w;
      } else {
        x = x == 0 ? w : x + spacing + w;
      }
      count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('knowledge-areas'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Knowledge areas covered', style: AssessText.section)),
              const SizedBox(width: 8),
              Container(
                key: const ValueKey('areas-count'),
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.successBadge, borderRadius: BorderRadius.circular(14)),
                child: Text(plural(areas.length, 'Topic'), style: AssessText.topicCount),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(blurb, style: AssessText.areasBlurb, maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 15),
          LayoutBuilder(
            builder: (context, constraints) {
              final fit = showAll
                  ? areas.length
                  : fitting(areas, constraints.maxWidth, MediaQuery.textScalerOf(context));
              final shown = fit < areas.length ? areas.take(fit).toList() : areas;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [for (final (i, area) in shown.indexed) TopicChip(label: area, tint: (i ~/ family) % 3)],
                  ),
                  if (showAll || shown.length < areas.length) ...[
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: onToggle,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 40),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            showAll ? 'View less' : 'View more',
                            key: const ValueKey('areas-toggle'),
                            style: AssessText.noteLink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One topic: a dot and a label in a rounded tile, 32 dp tall. [tint] picks the family: 0 and 2 are the two blues,
/// 1 the green.
class TopicChip extends StatelessWidget {
  const TopicChip({super.key, required this.label, required this.tint});

  final String label;
  final int tint;

  @override
  Widget build(BuildContext context) {
    final (fill, ink, dot) = switch (tint) {
      1 => (AssessColors.topicGreen, AssessColors.topicGreenInk, AssessColors.topicGreenDot),
      2 => (AssessColors.topicBlueDeep, AssessColors.setAction, AppColors.primary),
      _ => (AssessColors.topicBlue, AppColors.onSurface, AppColors.primary),
    };
    // A topic longer than the screen is cut with an ellipsis rather than wrapped (a Wrap gives its children the
    // line's width as their most), so every chip stays 32 dp tall.
    return Container(
      height: 32,
      padding: const EdgeInsets.fromLTRB(9, 0, 11, 0),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: AssessText.topicChip.copyWith(color: ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
