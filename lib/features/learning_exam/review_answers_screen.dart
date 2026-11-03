import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import 'exam_format.dart';
import 'exam_models.dart';
import 'exam_styles.dart';
import 'exam_widgets.dart';

enum _Filter { all, incorrect, unanswered, correct }

/// Review Answers, pushed from the result: every question of the sitting worked through, one at a time, with the
/// right answer, what the member picked and the explanation. Filter chips (All, Incorrect, Correct, and
/// Unanswered when there is one), a number strip coloured by outcome, and Previous / Next through the questions
/// the filter lets through.
class ReviewAnswersScreen extends StatefulWidget {
  const ReviewAnswersScreen({super.key, required this.result, this.questionMarks});

  final AttemptResult result;

  /// What each question was worth, by question id, when the sitting is fresh (a review does not carry it).
  final Map<String, int>? questionMarks;

  @override
  State<ReviewAnswersScreen> createState() => _ReviewAnswersScreenState();
}

class _ReviewAnswersScreenState extends State<ReviewAnswersScreen> {
  _Filter _filter = _Filter.all;

  /// The question on show, as an index into [AttemptResult.review].
  int _current = 0;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  AttemptResult get result => widget.result;
  Attempt get attempt => result.attempt;

  bool _matches(_Filter f, ReviewItem r) => switch (f) {
    _Filter.all => true,
    _Filter.incorrect => r.outcome == ReviewOutcome.incorrect,
    _Filter.unanswered => r.outcome == ReviewOutcome.skipped,
    _Filter.correct => r.outcome == ReviewOutcome.correct,
  };

  /// The questions the filter lets through, as indexes into the review.
  List<int> get _indexes => [
    for (final (i, r) in result.review.indexed)
      if (_matches(_filter, r)) i,
  ];

  int _count(_Filter f) => result.review.where((r) => _matches(f, r)).length;

  /// The question on show: the one chosen if the filter lets it through, else the first that it does.
  int get _shownIndex {
    final shown = _indexes;
    return shown.isEmpty || shown.contains(_current) ? _current : shown.first;
  }

  void _toTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _select(_Filter f) {
    setState(() {
      _filter = f;
      final shown = _indexes;
      if (shown.isNotEmpty && !shown.contains(_current)) _current = shown.first;
    });
    _toTop();
  }

  void _step(int by) {
    final shown = _indexes;
    final at = shown.indexOf(_shownIndex);
    final to = at + by;
    if (at < 0 || to < 0 || to >= shown.length) return;
    setState(() => _current = shown[to]);
    _toTop();
  }

  /// What the question was worth: the review says, else the sitting just taken, else one mark when the whole
  /// paper is worth one per question; null when it cannot be told.
  int? _marksOf(ReviewItem r) =>
      r.marks ?? widget.questionMarks?[r.id] ?? (attempt.maxScore == attempt.totalQuestions ? 1 : null);

  @override
  Widget build(BuildContext context) {
    final shown = _indexes;
    final index = _shownIndex;
    final position = shown.indexOf(index);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ExamTitleBar(title: 'Review Answers', onBack: () => popOnce(context)),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(0, 18, 0, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Semantics(
                      header: true,
                      child: Text('Question Review & Explanations', style: ExamText.sectionTitle),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _Filters(
                      current: _filter,
                      counts: {for (final f in _Filter.values) f: _count(f)},
                      onSelect: _select,
                    ),
                  ),
                  const SizedBox(height: 9),
                  if (shown.isNotEmpty)
                    _Strip(
                      numbers: shown,
                      review: result.review,
                      current: index,
                      onTap: (i) => setState(() => _current = i),
                    ),
                  const SizedBox(height: 10),
                  if (result.missing > 0) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Notice(
                        text: result.missing == 1
                            ? '1 question from this sitting has since been removed from the bank, so it is not shown here. Your score still counts it.'
                            : '${result.missing} questions from this sitting have since been removed from the bank, so they are not shown here. Your score still counts them.',
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: result.review.isEmpty || shown.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(child: Text('Nothing here.', style: ExamText.body)),
                          )
                        : ReviewCard(
                            item: result.review[index],
                            number: index + 1,
                            marks: _marksOf(result.review[index]),
                            footer: _Pager(
                              number: index + 1,
                              total: result.review.length,
                              onPrevious: position > 0 ? () => _step(-1) : null,
                              onNext: position < shown.length - 1 ? () => _step(1) : null,
                            ),
                          ),
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

/// All, Incorrect, Correct, and Unanswered when there are any: each in its own colour, filled when chosen.
class _Filters extends StatelessWidget {
  const _Filters({required this.current, required this.counts, required this.onSelect});

  final _Filter current;
  final Map<_Filter, int> counts;
  final ValueChanged<_Filter> onSelect;

  static const _labels = {
    _Filter.all: 'All',
    _Filter.incorrect: 'Incorrect',
    _Filter.unanswered: 'Unanswered',
    _Filter.correct: 'Correct',
  };

  /// Fill and ink for the chip, chosen or not.
  static (Color, Color) _colours(_Filter f, bool on) => switch (f) {
    _Filter.all => on ? (ExamColors.action, Colors.white) : (ExamColors.paleBlue, ExamColors.greyInk),
    _Filter.incorrect => on ? (ExamColors.wrong, Colors.white) : (ExamColors.wrongChip, ExamColors.wrongChipInk),
    _Filter.correct => on ? (ExamColors.action, Colors.white) : (ExamColors.paleBlue, ExamColors.greyInk),
    _Filter.unanswered => on ? (ExamColors.greyInk, Colors.white) : (ExamColors.greyTint, ExamColors.greyInk),
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final f in const [_Filter.all, _Filter.incorrect, _Filter.unanswered, _Filter.correct])
          if (f != _Filter.unanswered || (counts[f] ?? 0) > 0)
            Builder(
              builder: (context) {
                final on = f == current;
                final (fill, ink) = _colours(f, on);
                return Semantics(
                  button: true,
                  selected: on,
                  label: '${_labels[f]}, ${counts[f]} questions',
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(f),
                    child: Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(999)),
                      child: Center(
                        widthFactor: 1,
                        child: Text('${_labels[f]} (${counts[f]})', style: ExamText.filterChip.copyWith(color: ink)),
                      ),
                    ),
                  ),
                );
              },
            ),
      ],
    );
  }
}

/// Every question of the filter as a numbered square, scrolling sideways; the one on show is filled.
class _Strip extends StatefulWidget {
  const _Strip({required this.numbers, required this.review, required this.current, required this.onTap});

  /// The questions shown, as indexes into [review].
  final List<int> numbers;
  final List<ReviewItem> review;
  final int current;
  final ValueChanged<int> onTap;

  @override
  State<_Strip> createState() => _StripState();
}

class _StripState extends State<_Strip> {
  static const cell = 36.0;
  static const gap = 8.0;
  static const edge = 12.0;
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(animate: false));
  }

  @override
  void didUpdateWidget(_Strip old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current) WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Brings the question on show into the strip, to the middle of it, when it is not already in full view (a
  /// strip that fits, or a question near the start, is left where it is).
  void _reveal({bool animate = true}) {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    final at = widget.numbers.indexOf(widget.current);
    if (at < 0) return;
    final left = edge + at * (cell + gap);
    final inView = left - position.pixels >= edge && left + cell - position.pixels <= position.viewportDimension - edge;
    if (inView) return;
    final target = (left - (position.viewportDimension - cell) / 2).clamp(0.0, position.maxScrollExtent);
    if (animate) {
      unawaited(_controller.animateTo(target, duration: const Duration(milliseconds: 200), curve: Curves.easeOut));
    } else {
      _controller.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cell + 4,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: edge, vertical: 2),
        itemCount: widget.numbers.length,
        separatorBuilder: (_, _) => const SizedBox(width: gap),
        itemBuilder: (context, i) {
          final index = widget.numbers[i];
          return _StripCell(
            number: index + 1,
            outcome: widget.review[index].outcome,
            current: index == widget.current,
            onTap: () => widget.onTap(index),
          );
        },
      ),
    );
  }
}

class _StripCell extends StatelessWidget {
  const _StripCell({required this.number, required this.outcome, required this.current, required this.onTap});

  final int number;
  final ReviewOutcome outcome;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The square's fill says how the question went; no outline (the owner's rule of 3 Nov 2026).
    final (Color fill, Color ink) = current
        ? (ExamColors.action, Colors.white)
        : switch (outcome) {
            ReviewOutcome.correct => (ExamColors.rightTint, ExamColors.right),
            ReviewOutcome.incorrect => (ExamColors.wrongChip, ExamColors.wrong),
            ReviewOutcome.skipped => (ExamColors.paleBlue, ExamColors.greyMuted),
          };
    final words = switch (outcome) {
      ReviewOutcome.correct => 'correct',
      ReviewOutcome.incorrect => 'incorrect',
      ReviewOutcome.skipped => 'unanswered',
    };
    return Semantics(
      button: true,
      selected: current,
      label: 'Question $number, $words${current ? ', on show' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('review-q-$number'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: _StripState.cell,
          height: _StripState.cell,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(10),
            // The question on show wears a pale ring just outside its square.
            boxShadow: current ? const [BoxShadow(color: ExamColors.ring, spreadRadius: 2)] : null,
          ),
          child: Text('$number', style: ExamText.reviewNumber.copyWith(color: ink)),
        ),
      ),
    );
  }
}

/// One question worked through: how it turned out, the prompt, every option marked, the rationale, and [footer]
/// (the pager). Open on the page with hairlines between its parts and between the options — no outlined card or
/// boxes (the owner's rule of 3 Nov 2026: "no border is required, a thin line break is enough"); an option's tint
/// alone says it is the right one or a wrong pick.
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.item, required this.number, this.marks, this.footer});

  final ReviewItem item;
  final int number;

  /// What the question was worth; null leaves the mark line off.
  final int? marks;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final correct = {...item.correctIndexes};
    final picked = {...item.selected};
    final earned = item.outcome == ReviewOutcome.correct ? marks : 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Pill(text: 'Question $number', fill: ExamColors.paleBlue, style: ExamText.reviewTag),
                      _OutcomePill(outcome: item.outcome),
                    ],
                  ),
                ),
                if (marks != null) ...[
                  const SizedBox(width: 8),
                  Text('$earned / $marks ${marks == 1 ? 'Mark' : 'Marks'}', style: ExamText.reviewMarks),
                ],
              ],
            ),
          ),
          const SizedBox(height: 9),
          const Divider(height: 1, thickness: 1, color: ExamColors.line),
          const SizedBox(height: 13),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Text(item.prompt, style: ExamText.reviewQuestion),
          ),
          const SizedBox(height: 11),
          const Divider(height: 1, thickness: 1, color: ExamColors.line),
          for (final (i, option) in item.options.indexed) ...[
            _ReviewOption(index: i, text: option, isCorrect: correct.contains(i), isPicked: picked.contains(i)),
            const Divider(height: 1, thickness: 1, color: ExamColors.line),
          ],
          if (item.explanation != null) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // "Rationale" alone (owner, 3 Nov 2026; it read "Detailed Explanation & Rationale").
                  Text('Rationale', style: ExamText.rationaleTitle),
                  const SizedBox(height: 4),
                  Text(item.explanation!, style: ExamText.rationale),
                  if (item.category != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: ExamColors.greyTint, borderRadius: BorderRadius.circular(999)),
                      child: Text('Core Topic: ${item.category}', style: ExamText.topicPill),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: 13),
            const Divider(height: 1, thickness: 1, color: ExamColors.line),
            const SizedBox(height: 13),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// A small rounded label, 20 dp tall.
class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.fill, required this.style});

  final String text;
  final Color fill;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(10)),
      child: Center(widthFactor: 1, child: Text(text, style: style)),
    );
  }
}

class _OutcomePill extends StatelessWidget {
  const _OutcomePill({required this.outcome});

  final ReviewOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final (String label, IconData? icon, Color ink, Color fill) = switch (outcome) {
      ReviewOutcome.correct => ('Correct', LucideIcons.check, ExamColors.right, ExamColors.rightTint),
      ReviewOutcome.incorrect => ('Incorrect', LucideIcons.x, ExamColors.wrongChipInk, ExamColors.wrongChip),
      ReviewOutcome.skipped => ('Unanswered', null, ExamColors.greyInk, ExamColors.greyTint),
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 12, color: ink), const SizedBox(width: 3)],
            Text(label, style: ExamText.reviewOutcome.copyWith(color: ink)),
          ],
        ),
      ),
    );
  }
}

/// An option in the review: green when it is right, red when it was picked and is not, each with a line saying
/// so.
class _ReviewOption extends StatelessWidget {
  const _ReviewOption({required this.index, required this.text, required this.isCorrect, required this.isPicked});

  final int index;
  final String text;
  final bool isCorrect;
  final bool isPicked;

  @override
  Widget build(BuildContext context) {
    final wrongPick = isPicked && !isCorrect;
    final Color? tone = isCorrect ? ExamColors.right : (wrongPick ? ExamColors.wrong : null);
    final String? mark = isCorrect
        ? (isPicked ? 'Your Answer (Correct)' : 'Correct Answer')
        : (wrongPick ? 'Your Answer (Incorrect)' : null);
    return Semantics(
      container: true,
      label: 'Option ${optionLetter(index)}. $text.${mark == null ? '' : ' $mark.'}',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        color: isCorrect ? ExamColors.rightTint : (wrongPick ? ExamColors.wrongChip : null),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: Text('${optionLetter(index)}.', style: ExamText.reviewLetter.copyWith(color: tone)),
                ),
                Expanded(
                  child: Text(
                    text,
                    style: tone == null
                        ? ExamText.reviewOption
                        : ExamText.reviewOption.copyWith(color: tone, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            if (mark != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Row(
                  children: [
                    Icon(isCorrect ? LucideIcons.circleCheck : LucideIcons.circleX, size: 16, color: tone),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(mark, style: ExamText.reviewMark.copyWith(color: tone)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Previous and Next through the questions on show, with where you are between them.
class _Pager extends StatelessWidget {
  const _Pager({required this.number, required this.total, required this.onPrevious, required this.onNext});

  final int number;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PagerButton(label: 'Previous', icon: LucideIcons.arrowLeft, leading: true, onTap: onPrevious),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('Question $number of $total', textAlign: TextAlign.center, style: ExamText.pagerLabel),
          ),
        ),
        _PagerButton(label: 'Next', icon: LucideIcons.arrowRight, leading: false, filled: true, onTap: onNext),
      ],
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.label,
    required this.icon,
    required this.leading,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;

  /// The arrow comes before the words.
  final bool leading;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final ink = filled ? Colors.white : (enabled ? ExamColors.ink : AppColors.slate400);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final glyph = Icon(icon, size: 16, color: ink);
    final words = Text(label, style: ExamText.barButton.copyWith(color: ink));
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: filled ? (enabled ? ExamColors.action : ExamColors.action.withValues(alpha: 0.4)) : ExamColors.greyTint,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: leading ? [glyph, const SizedBox(width: 6), words] : [words, const SizedBox(width: 6), glyph],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
