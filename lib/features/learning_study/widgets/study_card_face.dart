import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/links.dart';
import '../study_models.dart';
import '../study_styles.dart';

/// One face of a flash card: the question, or the answer with its example and source link.
///
/// The card's frame (white, a slate edge, a soft shadow, 16 dp corners) is the Learning grid's; along the foot a
/// strip says what a tap does. The star sits at the top right of both faces: it belongs to the card, not to the
/// face, and takes its own tap, so it never flips the card.
class StudyCardFace extends StatelessWidget {
  const StudyCardFace({
    super.key,
    required this.card,
    required this.back,
    required this.starred,
    required this.onStar,
    this.caption,
  });

  final StudyCard card;

  /// The answer side.
  final bool back;
  final bool starred;
  final VoidCallback onStar;

  /// Over the question: where it comes from ("Strategy & Fundamentals"); the answer is labelled "Answer".
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final label = back ? 'ANSWER' : (caption == null || caption!.isEmpty ? 'QUESTION' : caption!.toUpperCase());
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StudyColors.border),
        boxShadow: const [BoxShadow(color: StudyColors.shadow, blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  const SizedBox(width: 18),
                  if (back)
                    const _Tag(label: 'ANSWER', fill: StudyColors.greenFill, ink: StudyColors.greenInk)
                  else
                    Expanded(
                      child: Text(label, style: StudyText.faceLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  if (back) const Spacer(),
                  StarButton(starred: starred, onPressed: onStar),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: back ? _Answer(card: card) : _Question(card: card),
              ),
            ),
            if (!back && card.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  children: [
                    for (final t in card.tags)
                      _Tag(label: t, fill: AppColors.surfaceContainer, ink: AppColors.onSurfaceVariant),
                  ],
                ),
              )
            else
              const SizedBox(height: 12),
            Container(
              height: 44,
              alignment: Alignment.center,
              color: back ? StudyColors.backBand : StudyColors.frontBand,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.rotateCw, size: 15, color: back ? Colors.white : AppColors.slate600),
                  const SizedBox(width: 8),
                  Text(
                    back ? 'Tap to flip back' : 'Tap to see the answer',
                    style: back ? StudyText.bandOnBlue : StudyText.band,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.card});

  final StudyCard card;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: Center(
              child: Text(card.front, textAlign: TextAlign.center, style: StudyText.front),
            ),
          ),
        ),
      ),
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({required this.card});

  final StudyCard card;

  @override
  Widget build(BuildContext context) {
    final example = card.example;
    final link = card.resourceUrl;
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        // The card has a fixed height for the turn, so a long answer scrolls inside it rather than being cut off.
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Text(card.back, textAlign: TextAlign.center, style: StudyText.back),
                ),
                if (example != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: StudyColors.formulaPlate,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: StudyColors.formulaPlateBorder),
                    ),
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('EXAMPLE', style: StudyText.faceLabel),
                          const SizedBox(height: 4),
                          Text(example, style: StudyText.example),
                        ],
                      ),
                    ),
                  ),
                ],
                if (link != null) ...[
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: () => openUrl(context, Uri.parse(link)),
                    icon: const Icon(LucideIcons.fileText, size: 16),
                    label: Text(card.resourceLabel ?? 'Open resource'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.fill, required this.ink});

  final String label;
  final Color fill;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(11)),
      child: Center(
        widthFactor: 1,
        child: Text(label, style: StudyText.faceTag.copyWith(color: ink)),
      ),
    );
  }
}

/// The star over a flash card: amber and filled when starred, a grey outline when not. 48 dp to tap.
class StarButton extends StatelessWidget {
  const StarButton({super.key, required this.starred, required this.onPressed});

  final bool starred;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: starred,
      label: starred ? 'Remove star' : 'Star this card',
      excludeSemantics: true,
      onTap: onPressed,
      child: InkResponse(
        key: const ValueKey('study-star'),
        onTap: onPressed,
        radius: 26,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            Symbols.star,
            fill: starred ? 1 : 0,
            weight: starred ? 600 : 500,
            size: 26,
            color: starred ? StudyColors.star : AppColors.slate400,
          ),
        ),
      ),
    );
  }
}
