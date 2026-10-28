import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/detail_sheet.dart';
import 'exam_controller.dart';
import 'exam_format.dart';
import 'exam_styles.dart';
import 'exam_widgets.dart';

/// How a palette mark is drawn: fill, edge and the number's ink.
({Color fill, Color edge, Color ink}) markStyle(QuestionMark mark) => switch (mark) {
  QuestionMark.notVisited => (fill: Colors.white, edge: AppColors.slate300, ink: AppColors.slate600),
  QuestionMark.notAnswered => (fill: ExamColors.notAnswered, edge: ExamColors.notAnswered, ink: Colors.white),
  QuestionMark.answered => (fill: ExamColors.answered, edge: ExamColors.answered, ink: Colors.white),
  QuestionMark.flagged => (fill: ExamColors.flagged, edge: ExamColors.flagged, ink: Colors.white),
  QuestionMark.answeredFlagged => (
    fill: ExamColors.answeredFlagged,
    edge: ExamColors.answeredFlagged,
    ink: ExamColors.answeredFlaggedInk,
  ),
};

String markWords(QuestionMark mark) => switch (mark) {
  QuestionMark.notVisited => 'Not visited',
  QuestionMark.notAnswered => 'Not answered',
  QuestionMark.answered => 'Answered',
  QuestionMark.flagged => 'Flagged for review',
  QuestionMark.answeredFlagged => 'Answered and flagged',
};

/// Opens a sheet over the exam; the sheet is given the controller because a route does not inherit the
/// screen's providers.
Future<T?> showExamSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: builder,
  );
}

/// The question palette: every question as a numbered cell in its colour, a legend with the counts, and the
/// way to the submit overview.
class PaletteSheet extends StatelessWidget {
  const PaletteSheet({super.key, required this.controller, required this.onJump, required this.onReview});

  final ExamController controller;
  final ValueChanged<int> onJump;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final counts = controller.counts;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(top: 10, height: 26, rule: false),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text('Question palette', style: ExamText.heading),
                  const SizedBox(height: 4),
                  Text('Tap a number to go to that question.', style: ExamText.small),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.15,
                    ),
                    itemCount: controller.total,
                    itemBuilder: (context, i) => PaletteCell(
                      index: i,
                      mark: controller.markOf(i),
                      current: i == controller.current,
                      onTap: () => onJump(i),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, thickness: 1, color: AppColors.slate100),
                  const SizedBox(height: 12),
                  for (final mark in QuestionMark.values) ...[
                    _LegendRow(mark: mark, count: counts.byMark[mark] ?? 0),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                  ExamButton(label: 'Review & submit', icon: LucideIcons.listChecks, onPressed: onReview),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One numbered cell of the palette, 44 dp tall.
class PaletteCell extends StatelessWidget {
  const PaletteCell({super.key, required this.index, required this.mark, required this.current, required this.onTap});

  final int index;
  final QuestionMark mark;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = markStyle(mark);
    return Semantics(
      button: true,
      selected: current,
      label: 'Question ${index + 1}, ${markWords(mark).toLowerCase()}${current ? ', current' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: s.fill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: s.edge, width: 1.5),
            boxShadow: current ? const [BoxShadow(color: AppColors.primary, spreadRadius: 2)] : null,
          ),
          alignment: Alignment.center,
          child: Text('${index + 1}', style: AppText.workSans(14, FontWeight.w700, s.ink)),
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.mark, required this.count});

  final QuestionMark mark;
  final int count;

  @override
  Widget build(BuildContext context) {
    final s = markStyle(mark);
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: s.fill,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: s.edge, width: 1.5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(markWords(mark), style: ExamText.body)),
        Text('$count', style: ExamText.bodyStrong),
      ],
    );
  }
}

/// The gate before the answers go: what has been answered, what has not, what is
/// flagged, and a number to go back to for each question.
class OverviewSheet extends StatelessWidget {
  const OverviewSheet({super.key, required this.controller, required this.onJump, required this.onSubmit});

  final ExamController controller;
  final ValueChanged<int> onJump;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final counts = controller.counts;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(top: 10, height: 26, rule: false),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text(
                    controller.paper.name.toUpperCase(),
                    style: ExamText.eyebrow,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text('Assessment overview', style: ExamText.heroTitle.copyWith(fontSize: 22)),
                  const SizedBox(height: 4),
                  Text('Review your progress before the final submission.', style: ExamText.body),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(value: '${counts.answered}', label: 'Answered', color: ExamColors.answered),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatTile(value: '${counts.skipped}', label: 'Skipped', color: AppColors.slate600),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatTile(value: '${counts.flagged}', label: 'Flagged', color: ExamColors.flagged),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${counts.answered} answered, ${counts.skipped} skipped, ${counts.flagged} flagged',
                    style: ExamText.small,
                    semanticsLabel:
                        '${counts.answered} answered, ${counts.skipped} skipped, ${counts.flagged} flagged.',
                  ),
                  if (counts.skipped > 0) ...[
                    const SizedBox(height: 10),
                    Notice(
                      tone: NoticeTone.warning,
                      text: counts.skipped == 1
                          ? '1 question has no answer. Tap its number to go back to it.'
                          : '${counts.skipped} questions have no answer. Tap a number to go back to one.',
                    ),
                  ],
                  if (counts.flagged > 0) ...[
                    const SizedBox(height: 10),
                    Notice(
                      text: counts.flagged == 1
                          ? '1 question is still flagged for review.'
                          : '${counts.flagged} questions are still flagged for review.',
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('Question status', style: ExamText.subheading),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.15,
                    ),
                    itemCount: controller.total,
                    itemBuilder: (context, i) => _OverviewCell(
                      index: i,
                      answered: controller.isAnswered(i),
                      flagged: controller.isFlagged(i),
                      onTap: () => onJump(i),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<Duration>(
                    valueListenable: controller.remaining,
                    builder: (context, left, _) => Row(
                      children: [
                        const Icon(LucideIcons.timer, size: 16, color: AppColors.slate500),
                        const SizedBox(width: 6),
                        Text('${clockLabel(left)} left', style: ExamText.small),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ExamButton(label: 'Back to test', quiet: true, onPressed: () => popOnce(context)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ExamButton(label: 'Submit test', icon: LucideIcons.send, onPressed: onSubmit),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OverviewCell extends StatelessWidget {
  const _OverviewCell({required this.index, required this.answered, required this.flagged, required this.onTap});

  final int index;
  final bool answered;
  final bool flagged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Question ${index + 1}, ${answered ? 'answered' : 'not answered'}${flagged ? ', flagged' : ''}. Go to it.',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: answered ? AppColors.primary.withValues(alpha: 0.16) : AppColors.slate100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${index + 1}',
                  style: AppText.workSans(14, FontWeight.w700, answered ? const Color(0xFF14497A) : AppColors.slate600),
                ),
              ),
            ),
            if (flagged)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: ExamColors.flagged, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
