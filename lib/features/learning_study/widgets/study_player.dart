import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../study_styles.dart';

/// The player bar under the card (flashcards-study.png): play (auto-advance through the pass, pausing on a tap),
/// shuffle, previous in an outlined circle, next in a filled one, and "Card 14 of 48" over a thin progress bar.
///
/// A rounded 46 dp bar with a hairline. Its four controls share equal slots (52 dp on a 390 dp phone, narrower
/// on a small one), each tappable over the whole slot; on the narrowest phones the count drops the word "Card".
class StudyPlayer extends StatelessWidget {
  const StudyPlayer({
    super.key,
    required this.playing,
    required this.shuffled,
    required this.canShuffle,
    required this.atFirst,
    required this.atLast,
    required this.position,
    required this.total,
    required this.progress,
    required this.onPlay,
    required this.onShuffle,
    required this.onPrevious,
    required this.onNext,
  });

  static const height = 46.0;

  final bool playing;
  final bool shuffled;
  final bool canShuffle;
  final bool atFirst;
  final bool atLast;
  final int position;
  final int total;
  final double progress;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StudyColors.rule),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final slot = box.maxWidth >= 340
              ? 52.0
              : box.maxWidth >= 320
              ? 44.0
              : 38.0;
          final compact = box.maxWidth < 300;
          // The circles keep a gap between them when the slots are narrow.
          final round = slot < 44 ? 32.0 : 36.0;
          // What the count may take: the rest of the bar less the progress bar's least (16 dp) and the gaps.
          final room = (box.maxWidth - (2 + 4 * slot + 8 + 8 + 12) - 16).clamp(0.0, double.infinity);
          return Row(
            children: [
              const SizedBox(width: 2),
              _Slot(
                width: slot,
                widgetKey: const ValueKey('study-play'),
                label: playing ? 'Pause' : 'Play the cards',
                onTap: onPlay,
                child: Icon(
                  playing ? Symbols.pause : Symbols.play_arrow,
                  fill: 1,
                  size: playing ? 22 : 21,
                  color: playing ? AppColors.primary : StudyColors.playerInk,
                ),
              ),
              _Slot(
                width: slot,
                widgetKey: const ValueKey('study-shuffle'),
                label: shuffled ? 'Restore the original order' : 'Shuffle the deck',
                selected: shuffled,
                onTap: canShuffle ? onShuffle : null,
                child: Icon(
                  LucideIcons.shuffle,
                  size: 17,
                  color: shuffled
                      ? AppColors.primary
                      : canShuffle
                      ? StudyColors.playerInk
                      : AppColors.slate300,
                ),
              ),
              _Slot(
                width: slot,
                widgetKey: const ValueKey('study-previous'),
                label: 'Previous card',
                onTap: atFirst ? null : onPrevious,
                child: _Round(
                  size: round,
                  fill: AppColors.slate100,
                  border: StudyColors.prevBorder,
                  icon: LucideIcons.chevronLeft,
                  ink: atFirst ? AppColors.slate300 : StudyColors.prevInk,
                ),
              ),
              _Slot(
                width: slot,
                widgetKey: const ValueKey('study-next'),
                label: atLast ? 'Finish' : 'Next card',
                onTap: onNext,
                child: _Round(
                  size: round,
                  fill: AppColors.primary,
                  icon: atLast ? LucideIcons.check : LucideIcons.chevronRight,
                  ink: Colors.white,
                  lifted: true,
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: room),
                child: Semantics(
                  label: 'Card $position of $total',
                  excludeSemantics: true,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (!compact) TextSpan(text: 'Card ', style: StudyText.cardWord),
                        TextSpan(text: '$position', style: StudyText.cardNumber),
                        TextSpan(text: ' of $total', style: StudyText.cardTotal),
                      ],
                    ),
                    key: const ValueKey('study-position'),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    key: const ValueKey('study-progress'),
                    value: progress,
                    minHeight: 6,
                    backgroundColor: StudyColors.rule,
                    valueColor: const AlwaysStoppedAnimation(StudyColors.progressFill),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          );
        },
      ),
    );
  }
}

/// One control's slot: the whole of it takes the tap.
class _Slot extends StatelessWidget {
  const _Slot({
    required this.width,
    required this.widgetKey,
    required this.label,
    required this.onTap,
    required this.child,
    this.selected,
  });

  final double width;
  final Key widgetKey;
  final String label;
  final VoidCallback? onTap;
  final Widget child;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      toggled: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        key: widgetKey,
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: width,
          height: StudyPlayer.height - 2,
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Previous's outlined circle and Next's filled one: 36 dp, 32 on the narrowest phones.
class _Round extends StatelessWidget {
  const _Round({
    required this.size,
    required this.fill,
    required this.icon,
    required this.ink,
    this.border,
    this.lifted = false,
  });

  final double size;
  final Color fill;
  final Color? border;
  final IconData icon;
  final Color ink;
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: border == null ? null : Border.all(color: border!),
        boxShadow: lifted ? const [BoxShadow(color: Color(0x401D63A3), blurRadius: 6, offset: Offset(0, 2))] : null,
      ),
      child: Icon(icon, size: 20, color: ink),
    );
  }
}

/// "Still learning" and "Got it": the member's own marks, kept for the session, with the tally under them.
class StudyVerdict extends StatelessWidget {
  const StudyVerdict({
    super.key,
    required this.known,
    required this.learning,
    required this.knownCount,
    required this.learningCount,
    required this.onKnown,
    required this.onLearning,
  });

  static const buttonHeight = 44.0;

  /// The card showing is marked got it / still learning.
  final bool known;
  final bool learning;
  final int knownCount;
  final int learningCount;
  final VoidCallback onKnown;
  final VoidCallback onLearning;

  /// The tally's line, reserved even when it is empty so the card does not change height at the first mark.
  static const tallyHeight = 18.0;

  @override
  Widget build(BuildContext context) {
    final marked = knownCount + learningCount > 0;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _VerdictButton(
                key: const ValueKey('study-still-learning'),
                label: 'Still learning',
                icon: Symbols.replay,
                selected: learning,
                fill: StudyColors.amberFill,
                ink: StudyColors.amberInk,
                onPressed: onLearning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _VerdictButton(
                key: const ValueKey('study-got-it'),
                label: 'Got it',
                icon: Symbols.check,
                selected: known,
                fill: StudyColors.greenFill,
                ink: StudyColors.greenInk,
                onPressed: onKnown,
              ),
            ),
          ],
        ),
        SizedBox(
          height: tallyHeight,
          child: marked
              ? Center(
                  child: Text(
                    'Got it $knownCount · Still learning $learningCount',
                    key: const ValueKey('study-tally'),
                    style: StudyText.tally,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

class _VerdictButton extends StatelessWidget {
  const _VerdictButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.fill,
    required this.ink,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color fill;
  final Color ink;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: selected ? fill : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? ink : StudyColors.border, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onTap: onPressed,
          child: SizedBox(
            height: StudyVerdict.buttonHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, weight: 600, color: ink),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: StudyText.verdict.copyWith(color: ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
