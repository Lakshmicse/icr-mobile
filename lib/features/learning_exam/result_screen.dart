import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/title_bar.dart';
import 'certificate_view.dart';
import 'exam_format.dart';
import 'exam_models.dart';
import 'exam_styles.dart';
import 'exam_widgets.dart';
import '../notifications/notifications_bell.dart';
import '../notifications/notifications_screen.dart';

/// The result of a sitting, straight after it or reopened from the history: the score and whether it
/// passed, the breakdown, and every question worked through with the right answer and the explanation.
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.result,
    required this.paperName,
    required this.certificateEnabled,
    this.firstName,
    this.onRetake,
    this.eyebrowSuffix,
    this.onClosed,
  });

  final AttemptResult result;

  /// "Capital Planning – Foundation".
  final String paperName;

  /// The paper certifies: its result speaks of passing rather than just scoring.
  final bool certificateEnabled;
  final String? firstName;

  /// Sit the paper again. The result closes first. Null hides the button.
  final VoidCallback? onRetake;

  /// Appended to the eyebrow: " · 18 Oct 2026" on a reopened sitting.
  final String? eyebrowSuffix;

  /// Called when the screen goes away.
  final VoidCallback? onClosed;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

enum _Filter { all, incorrect, skipped, correct }

class _ResultScreenState extends State<ResultScreen> {
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    widget.onClosed?.call();
    super.dispose();
  }

  AttemptResult get result => widget.result;
  Attempt get attempt => result.attempt;

  Color get _tone => (!widget.certificateEnabled || attempt.passed) ? const Color(0xFF14497A) : AppColors.error;

  String get _headline {
    final pct = attempt.percentage;
    final String base;
    if (!widget.certificateEnabled) {
      base = 'You scored $pct%';
    } else if (!attempt.passed) {
      base = 'Not quite there yet';
    } else {
      base = pct >= 85 ? 'Outstanding result' : 'Well done';
    }
    final name = widget.firstName?.trim();
    return (name == null || name.isEmpty || !widget.certificateEnabled) ? base : '$base, $name';
  }

  String get _blurb {
    final pct = attempt.percentage;
    final pass = attempt.passPercentage;
    if (!widget.certificateEnabled) {
      return 'A practice paper: your score is yours alone, and the answers below are there to learn from. Pass mark $pass%.';
    }
    return attempt.passed
        ? 'You passed ${widget.paperName} with $pct%, against a pass mark of $pass%.'
        : 'You scored $pct%, and the pass mark is $pass%. Work through the answers below, then try again.';
  }

  List<ReviewItem> get _shown => [
    for (final r in result.review)
      if (_filter == _Filter.all ||
          (_filter == _Filter.incorrect && r.outcome == ReviewOutcome.incorrect) ||
          (_filter == _Filter.skipped && r.outcome == ReviewOutcome.skipped) ||
          (_filter == _Filter.correct && r.outcome == ReviewOutcome.correct))
        r,
  ];

  int _count(ReviewOutcome o) => result.review.where((r) => r.outcome == o).length;

  @override
  Widget build(BuildContext context) {
    final cert = result.certificate;
    final shown = _shown;
    final index = {for (final (i, r) in result.review.indexed) r.id: i};
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TitleBar(
              title: 'Your result',
              onBack: () => popOnce(context),
              unread: bellUnread(context),
              onBell: () => openNotifications(context),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _Hero(
                          eyebrow: '${widget.paperName}${widget.eyebrowSuffix ?? ''}'.toUpperCase(),
                          headline: _headline,
                          blurb: _blurb,
                          attempt: attempt,
                          certifying: widget.certificateEnabled,
                          tone: _tone,
                        ),
                        if (cert != null) ...[
                          const SizedBox(height: 12),
                          Notice(
                            tone: NoticeTone.success,
                            text: 'Certificate issued: ${cert.certificateId}, on attempt ${cert.attempt}.',
                            action: 'View certificate',
                            onAction: () => showCertificateSheet(context, cert),
                          ),
                        ],
                        if (result.missing > 0) ...[
                          const SizedBox(height: 12),
                          Notice(
                            text: result.missing == 1
                                ? '1 question from this sitting has since been removed from the bank, so it is not shown below. Your score still counts it.'
                                : '${result.missing} questions from this sitting have since been removed from the bank, so they are not shown below. Your score still counts them.',
                          ),
                        ],
                        const SizedBox(height: 16),
                        _Breakdown(attempt: attempt),
                        if (_topics().length > 1) ...[const SizedBox(height: 16), _Topics(rows: _topics())],
                        if (result.review.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Semantics(header: true, child: Text('Review your answers', style: ExamText.heading)),
                          const SizedBox(height: 12),
                          _Filters(
                            current: _filter,
                            counts: {
                              _Filter.all: result.review.length,
                              _Filter.incorrect: _count(ReviewOutcome.incorrect),
                              _Filter.skipped: _count(ReviewOutcome.skipped),
                              _Filter.correct: _count(ReviewOutcome.correct),
                            },
                            onSelect: (f) => setState(() => _filter = f),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ]),
                    ),
                  ),
                  if (shown.isEmpty && result.review.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Nothing here.', textAlign: TextAlign.center, style: ExamText.body),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.separated(
                        itemCount: shown.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => ReviewCard(
                          item: shown[i],
                          number: (index[shown[i].id] ?? i) + 1,
                          total: result.review.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                ],
              ),
            ),
            _Bar(
              certificate: cert,
              onRetake: widget.onRetake == null
                  ? null
                  : () {
                      if (popOnce(context)) widget.onRetake!();
                    },
              onBack: () => popOnce(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Score by topic, from the category each reviewed question is filed under.
  List<_TopicRow> _topics() {
    final byTopic = <String, List<ReviewItem>>{};
    for (final r in result.review) {
      final c = r.category;
      if (c != null) byTopic.putIfAbsent(c, () => []).add(r);
    }
    return [
      for (final e in byTopic.entries)
        _TopicRow(e.key, e.value.where((r) => r.outcome == ReviewOutcome.correct).length, e.value.length),
    ]..sort((a, b) => a.fraction.compareTo(b.fraction));
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.eyebrow,
    required this.headline,
    required this.blurb,
    required this.attempt,
    required this.certifying,
    required this.tone,
  });

  final String eyebrow;
  final String headline;
  final String blurb;
  final Attempt attempt;
  final bool certifying;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ExamColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.clipboardCheck, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(eyebrow, maxLines: 2, overflow: TextOverflow.ellipsis, style: ExamText.eyebrow),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Semantics(
            header: true,
            child: Text(headline, style: ExamText.heroTitle.copyWith(fontSize: 26, height: 1.15)),
          ),
          const SizedBox(height: 8),
          Text(blurb, style: ExamText.body),
          const SizedBox(height: 18),
          Center(
            child: ScoreDial(percent: attempt.percentage, color: tone),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoPill(icon: LucideIcons.target, label: 'Accuracy ${attempt.percentage}%'),
              InfoPill(icon: LucideIcons.timer, label: 'Time taken ${takenLabel(attempt.timeTaken)}'),
              InfoPill(
                icon: LucideIcons.trendingUp,
                label: '${attempt.correct} of ${attempt.totalQuestions} correct',
                color: attempt.correct == attempt.totalQuestions ? AppColors.tertiary : AppColors.primary,
              ),
              if (attempt.passed)
                const InfoPill(icon: LucideIcons.badgeCheck, label: 'Passed', color: AppColors.tertiary)
              else
                InfoPill(
                  icon: certifying ? LucideIcons.circleX : LucideIcons.flag,
                  label: certifying
                      ? 'Not passed · ${attempt.passPercentage}% to pass'
                      : 'Below the ${attempt.passPercentage}% pass mark',
                  color: certifying ? AppColors.error : AppColors.amber800,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Correct, incorrect and skipped as a ring and three rows.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.attempt});

  final Attempt attempt;

  @override
  Widget build(BuildContext context) {
    return ExamCard(
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: CustomPaint(
              painter: _RingPainter(correct: attempt.correct, wrong: attempt.wrong, skipped: attempt.unanswered),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              children: [
                _Tally(color: AppColors.success, label: 'Correct', value: attempt.correct),
                const SizedBox(height: 8),
                _Tally(color: AppColors.error, label: 'Incorrect', value: attempt.wrong),
                const SizedBox(height: 8),
                _Tally(color: AppColors.slate300, label: 'Skipped', value: attempt.unanswered),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally({required this.color, required this.label, required this.value});

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: ExamText.bodyStrong)),
        Text('$value', style: AppText.workSans(15, FontWeight.w800, AppColors.onSurface)),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.correct, required this.wrong, required this.skipped});

  final int correct;
  final int wrong;
  final int skipped;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final total = correct + wrong + skipped;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.slate100;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, base);
    if (total == 0) return;
    var start = -math.pi / 2;
    for (final (value, color) in [
      (correct, AppColors.success),
      (wrong, AppColors.error),
      (skipped, AppColors.slate300),
    ]) {
      if (value == 0) continue;
      final sweep = value / total * math.pi * 2;
      canvas.drawArc(
        arcRect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.correct != correct || old.wrong != wrong || old.skipped != skipped;
}

class _TopicRow {
  _TopicRow(this.name, this.correct, this.total);

  final String name;
  final int correct;
  final int total;

  double get fraction => total == 0 ? 0 : correct / total;
}

/// How the sitting went on each topic, weakest first.
class _Topics extends StatelessWidget {
  const _Topics({required this.rows});

  final List<_TopicRow> rows;

  @override
  Widget build(BuildContext context) {
    return ExamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('By topic', style: ExamText.subheading),
          const SizedBox(height: 12),
          for (final (i, r) in rows.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(r.name, style: ExamText.body.copyWith(color: AppColors.onSurface)),
                ),
                Text('${r.correct}/${r.total}', style: ExamText.bodyStrong),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: r.fraction,
                minHeight: 6,
                backgroundColor: AppColors.slate100,
                color: r.fraction >= 0.7
                    ? AppColors.success
                    : (r.fraction >= 0.4 ? AppColors.amber500 : AppColors.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.current, required this.counts, required this.onSelect});

  final _Filter current;
  final Map<_Filter, int> counts;
  final ValueChanged<_Filter> onSelect;

  static const _labels = {
    _Filter.all: 'All',
    _Filter.incorrect: 'Incorrect',
    _Filter.skipped: 'Skipped',
    _Filter.correct: 'Correct',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final f in _Filter.values)
          if (f == _Filter.all || (counts[f] ?? 0) > 0)
            Semantics(
              button: true,
              selected: f == current,
              label: '${_labels[f]}, ${counts[f]} questions',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(f),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: f == current ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: f == current ? AppColors.primary : AppColors.outlineVariant),
                  ),
                  child: Text(
                    '${_labels[f]} ${counts[f]}',
                    style: AppText.workSans(13, FontWeight.w600, f == current ? Colors.white : AppColors.onSurface),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

/// One question worked through: how it turned out, every option marked, the explanation.
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.item, required this.number, required this.total});

  final ReviewItem item;
  final int number;
  final int total;

  @override
  Widget build(BuildContext context) {
    final correct = {...item.correctIndexes};
    final picked = {...item.selected};
    return ExamCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.category == null
                      ? 'QUESTION $number OF $total'
                      : 'QUESTION $number OF $total · ${item.category!.toUpperCase()}',
                  style: ExamText.eyebrow.copyWith(height: 1.5),
                ),
              ),
              const SizedBox(width: 8),
              _OutcomePill(outcome: item.outcome),
            ],
          ),
          const SizedBox(height: 10),
          Text(item.prompt, style: ExamText.question.copyWith(fontSize: 16, height: 1.45)),
          const SizedBox(height: 14),
          for (final (i, option) in item.options.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            _ReviewOption(index: i, text: option, isCorrect: correct.contains(i), isPicked: picked.contains(i)),
          ],
          if (item.explanation != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ExamColors.cardBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(LucideIcons.lightbulb, size: 16, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rationale', style: ExamText.subheading),
                        const SizedBox(height: 3),
                        Text(item.explanation!, style: ExamText.body),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OutcomePill extends StatelessWidget {
  const _OutcomePill({required this.outcome});

  final ReviewOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final (String label, IconData icon, Color color) = switch (outcome) {
      ReviewOutcome.correct => ('Correct', LucideIcons.check, AppColors.success),
      ReviewOutcome.incorrect => ('Incorrect', LucideIcons.x, AppColors.error),
      ReviewOutcome.skipped => ('Skipped', LucideIcons.minus, AppColors.slate500),
    };
    return InfoPill(label: label, icon: icon, color: color, fill: color.withValues(alpha: 0.08));
  }
}

/// An option in the review: tinted green when it is right, red when it was picked and is not,
/// with "Correct answer" and "Your answer" marks.
class _ReviewOption extends StatelessWidget {
  const _ReviewOption({required this.index, required this.text, required this.isCorrect, required this.isPicked});

  final int index;
  final String text;
  final bool isCorrect;
  final bool isPicked;

  @override
  Widget build(BuildContext context) {
    final Color? tone = isCorrect ? AppColors.success : (isPicked ? AppColors.error : null);
    final marks = [if (isCorrect) 'Correct answer', if (isPicked) 'Your answer'];
    return Semantics(
      container: true,
      label: 'Option ${optionLetter(index)}. $text.${marks.isEmpty ? '' : ' ${marks.join('. ')}.'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCorrect ? ExamColors.correctFill : (isPicked ? ExamColors.wrongFill : AppColors.slate50),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tone?.withValues(alpha: 0.5) ?? ExamColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tone ?? Colors.transparent,
                    shape: BoxShape.circle,
                    border: tone == null ? Border.all(color: AppColors.slate300) : null,
                  ),
                  child: Text(
                    optionLetter(index),
                    style: AppText.workSans(12.5, FontWeight.w800, tone == null ? AppColors.slate600 : Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      text,
                      style: AppText.plexSans(
                        14,
                        tone == null ? FontWeight.w400 : FontWeight.w600,
                        AppColors.onSurface,
                        lineHeight: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (marks.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 38),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (isCorrect)
                      const _Mark(label: 'Correct answer', icon: LucideIcons.check, color: AppColors.success),
                    if (isPicked)
                      _Mark(
                        label: 'Your answer',
                        icon: isCorrect ? LucideIcons.check : LucideIcons.x,
                        color: isCorrect ? AppColors.success : AppColors.error,
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

class _Mark extends StatelessWidget {
  const _Mark({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppText.plexSans(12, FontWeight.w700, color, lineHeight: 16)),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.certificate, required this.onRetake, required this.onBack});

  final ExamCertificate? certificate;
  final VoidCallback? onRetake;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final cert = certificate;
    return BottomActionBar(
      children: [
        if (cert != null) ...[
          if (onRetake != null)
            Expanded(
              child: ExamButton(label: 'Retake', icon: LucideIcons.rotateCcw, quiet: true, onPressed: onRetake),
            ),
          Expanded(
            flex: onRetake == null ? 1 : 2,
            child: ExamButton(
              label: 'View certificate',
              icon: LucideIcons.award,
              onPressed: () => showCertificateSheet(context, cert),
            ),
          ),
        ] else ...[
          Expanded(
            child: ExamButton(label: 'Back', quiet: true, onPressed: onBack),
          ),
          if (onRetake != null)
            Expanded(
              flex: 2,
              child: ExamButton(label: 'Retake test', icon: LucideIcons.rotateCcw, onPressed: onRetake),
            ),
        ],
      ],
    );
  }
}
