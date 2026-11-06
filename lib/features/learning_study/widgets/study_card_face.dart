import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/links.dart';
import '../study_models.dart';
import '../study_styles.dart';

/// One face of a flash card (flashcards-study.png): a white card with soft corners, the star at the top right, the
/// question at the left and, along the foot under a dashed rule, what a tap does with a Flip Card pill. The back
/// is the same card with the answer, its worked example and source link in place of the question.
///
/// The card has no speaker: nothing in the app can read text aloud yet, and a glyph that does nothing is a dead
/// control. The star belongs to the card, not to the face, and takes its own tap, so it never flips it.
class StudyCardFace extends StatelessWidget {
  const StudyCardFace({
    super.key,
    required this.card,
    required this.back,
    required this.starred,
    required this.onStar,
    required this.onFlip,
    this.caption,
  });

  final StudyCard card;

  /// The answer side.
  final bool back;
  final bool starred;
  final VoidCallback onStar;

  /// The Flip Card pill's tap (a tap anywhere else on the card flips it too, through the card).
  final VoidCallback onFlip;

  /// Over the question: where it comes from ("Strategy & Fundamentals"); the answer is labelled "Answer".
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final label = caption == null || caption!.isEmpty ? null : caption!.toUpperCase();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: StudyColors.shadow, blurRadius: 14, offset: Offset(0, 3))],
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
                  if (back) ...[
                    const _Tag(label: 'ANSWER', fill: StudyColors.greenFill, ink: StudyColors.greenInk),
                    const Spacer(),
                  ] else if (label != null)
                    Expanded(
                      child: Text(label, style: StudyText.faceLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
                    )
                  else
                    const Spacer(),
                  StarButton(starred: starred, onPressed: onStar),
                  const SizedBox(width: 6),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: back ? _Answer(card: card) : _Question(card: card),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 1, child: CustomPaint(painter: _DashedRule())),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const _Dot(),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          back ? 'Tap card to see the question again' : 'Tap card to reveal standard explanation',
                          style: StudyText.footerHint,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FlipPill(onTap: onFlip),
                    ],
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

/// The question at the left, vertically in the middle of the room the card has; a long one scrolls.
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
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.front, style: StudyText.question),
                  if (card.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in card.tags)
                          _Tag(label: t, fill: AppColors.surfaceContainer, ink: AppColors.onSurfaceVariant),
                      ],
                    ),
                  ],
                ],
              ),
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
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(child: Text(card.back, style: StudyText.answer)),
                if (example != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: StudyColors.formulaPlate, borderRadius: BorderRadius.circular(10)),
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
                  const SizedBox(height: 8),
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

/// The blue dot before the footer's hint.
class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 6,
    height: 6,
    child: DecoratedBox(
      decoration: BoxDecoration(color: StudyColors.dot, shape: BoxShape.circle),
    ),
  );
}

/// "Flip Card": the footer's pill, a tinted rectangle with the turn glyph and the words in the primary blue.
class _FlipPill extends StatelessWidget {
  const _FlipPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Flip card',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        key: const ValueKey('study-flip-pill'),
        color: StudyColors.flipFill,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.refreshCw, size: 12, color: AppColors.primary),
                const SizedBox(width: 5),
                Text('Flip Card', style: StudyText.flipPill),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A 1 dp rule of 3 dp dashes with 2 dp between, the footer's.
class _DashedRule extends CustomPainter {
  const _DashedRule();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = StudyColors.dash
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 5) {
      canvas.drawLine(Offset(x, 0.5), Offset((x + 3).clamp(0, size.width), 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedRule old) => false;
}

/// The star over a flash card: amber with a darker edge when starred, a grey outline when not. 48 dp to tap.
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
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (starred) const Icon(Symbols.star, fill: 1, size: 17, color: StudyColors.cardStar),
              Icon(
                Symbols.star,
                fill: 0,
                weight: starred ? 500 : 400,
                size: 17,
                color: starred ? StudyColors.cardStarEdge : AppColors.slate400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
