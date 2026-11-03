import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../study_controller.dart';
import '../study_format.dart';
import '../study_styles.dart';

/// The end of a pass: the numbers, the cards still to learn and the way on.
///
/// Laid out to be one view on a phone (the check, the title, three tiles, two buttons and two links come to about
/// 440 dp); on a shorter screen it scrolls rather than clip.
class StudySummary extends StatelessWidget {
  const StudySummary({super.key, required this.controller, required this.onBack});

  final DeckStudyController controller;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final rest = c.toReview.length;
    final everyCard = c.total;
    final knowAll = rest == 0;
    return SingleChildScrollView(
      key: const ValueKey('study-summary'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(color: StudyColors.greenFill, shape: BoxShape.circle),
                  child: const Icon(Symbols.check_circle, fill: 1, size: 38, color: StudyColors.greenInk),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                c.isStarredSession ? 'Starred cards done' : 'Deck complete',
                textAlign: TextAlign.center,
                style: StudyText.summaryTitle,
              ),
              const SizedBox(height: 4),
              Text(
                knowAll ? 'You know all ${cardsLabel(everyCard)}.' : 'You went through ${cardsLabel(everyCard)}.',
                key: const ValueKey('study-summary-lead'),
                textAlign: TextAlign.center,
                style: StudyText.summaryLead,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      key: const ValueKey('study-stat-known'),
                      value: c.knownCount,
                      label: 'Got it',
                      fill: StudyColors.greenFill,
                      ink: StudyColors.greenInk,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(
                      key: const ValueKey('study-stat-learning'),
                      value: c.learningCount,
                      label: 'Still learning',
                      fill: StudyColors.amberFill,
                      ink: StudyColors.amberInk,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(
                      key: const ValueKey('study-stat-unmarked'),
                      value: c.unmarkedCount,
                      label: 'Not marked',
                      fill: AppColors.slate100,
                      ink: AppColors.slate600,
                    ),
                  ),
                ],
              ),
              if (c.starredOnShow > 0) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Symbols.star, fill: 1, size: 18, color: StudyColors.star),
                    const SizedBox(width: 6),
                    Text(
                      '${c.starredOnShow} starred for another pass',
                      key: const ValueKey('study-summary-starred'),
                      style: StudyText.summaryLead,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: FilledButton(
                  key: const ValueKey('study-summary-rest'),
                  onPressed: knowAll ? c.studyAgain : c.studyTheRest,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    knowAll
                        ? 'Study them again'
                        : (rest == 1 ? 'Study the 1 you have not got' : 'Study the $rest you have not got'),
                    style: AppText.button.copyWith(fontSize: 16),
                  ),
                ),
              ),
              if (!knowAll) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    key: const ValueKey('study-summary-again'),
                    onPressed: c.studyAgain,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onSurface,
                      side: const BorderSide(color: StudyColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Start over', style: AppText.button.copyWith(fontSize: 16, color: AppColors.onSurface)),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    key: const ValueKey('study-summary-last'),
                    onPressed: c.previous,
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    child: Text('Back to the last card', style: AppText.link.copyWith(fontSize: 14)),
                  ),
                  TextButton(
                    key: const ValueKey('study-summary-back'),
                    onPressed: onBack,
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    child: Text('All decks', style: AppText.link.copyWith(fontSize: 14)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({super.key, required this.value, required this.label, required this.fill, required this.ink});

  final int value;
  final String label;
  final Color fill;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text('$value', style: StudyText.statValue.copyWith(color: ink)),
            const SizedBox(height: 2),
            Text(label, style: StudyText.statLabel.copyWith(color: ink)),
          ],
        ),
      ),
    );
  }
}
