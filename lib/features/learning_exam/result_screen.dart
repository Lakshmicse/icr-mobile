import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import 'certificate_view.dart';
import 'exam_format.dart';
import 'exam_models.dart';
import 'exam_styles.dart';
import 'exam_widgets.dart';
import 'review_answers_screen.dart';

/// The result of a sitting, straight after it or reopened from the brief or the history: the score and whether
/// it passed, the six figures, which sitting this was, and the two ways on: Retake test, and Review answers
/// (its own screen). One compact page; the member's other sittings are on the brief.
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
    this.setName,
    this.questionMarks,
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

  /// The rung or set the paper is ("Foundation", "Set 1"): the part of [paperName] after its dash, when the
  /// result does not carry the paper.
  final String? setName;

  /// What each question was worth, by question id, when the sitting is fresh (a review does not carry it).
  final Map<String, int>? questionMarks;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void dispose() {
    widget.onClosed?.call();
    super.dispose();
  }

  AttemptResult get result => widget.result;
  Attempt get attempt => result.attempt;

  /// "Foundation" or "Set 1": the paper's own title, else what follows the dash in its name.
  String? get _setName {
    final given = widget.setName?.trim();
    if (given != null && given.isNotEmpty) return given;
    final own = attempt.paper?.title.trim();
    if (own != null && own.isNotEmpty) return own;
    final at = widget.paperName.lastIndexOf(' – ');
    return at < 0 ? null : widget.paperName.substring(at + 3).trim();
  }

  String get _tag {
    final set = _setName;
    final named = set == null || set.isEmpty ? '' : ' — ${set.toUpperCase()}';
    final suffix = widget.eyebrowSuffix?.toUpperCase() ?? '';
    return 'TEST ANALYSIS$named$suffix';
  }

  String get _certifiedHeadline {
    final pct = attempt.percentage;
    final String base;
    if (!attempt.passed) {
      base = 'Not quite there yet';
    } else {
      base = pct >= 85 ? 'Outstanding result' : 'Well done';
    }
    final name = widget.firstName?.trim();
    return (name == null || name.isEmpty) ? base : '$base, $name';
  }

  String get _blurb {
    final pct = attempt.percentage;
    final pass = attempt.passPercentage;
    if (!widget.certificateEnabled) return 'Practice paper — no certificate is issued.';
    return attempt.passed
        ? 'You passed ${widget.paperName} with $pct%, against a pass mark of $pass%.'
        : 'You scored $pct%, and the pass mark is $pass%. Review the answers, then try again.';
  }

  void _review() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewAnswersScreen(result: result, questionMarks: widget.questionMarks),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cert = result.certificate;
    final VoidCallback? retake = widget.onRetake == null
        ? null
        : () {
            if (popOnce(context)) widget.onRetake!();
          };
    final canReview = result.review.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ExamTitleBar(title: 'Test Results', onBack: () => popOnce(context)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Chips(tag: _tag, kind: widget.certificateEnabled ? 'Summative' : 'Formative'),
                    const SizedBox(height: 12),
                    _Headline(
                      certifying: widget.certificateEnabled,
                      passed: attempt.passed,
                      percentage: attempt.percentage,
                      certifiedText: _certifiedHeadline,
                    ),
                    const SizedBox(height: 11),
                    Text(_blurb, style: ExamText.resultSubline),
                    if (cert != null) ...[
                      const SizedBox(height: 10),
                      Notice(
                        tone: NoticeTone.success,
                        text: 'Certificate issued: ${cert.certificateId}, on attempt ${cert.attempt}.',
                        action: 'View certificate',
                        onAction: () => showCertificateSheet(context, cert),
                      ),
                    ],
                    const SizedBox(height: 9),
                    _Tiles(attempt: attempt),
                    const SizedBox(height: 9),
                    _AttemptCount(number: attempt.attempt),
                    if (retake != null || canReview) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (retake != null)
                            Expanded(
                              flex: 173,
                              child: ExamButton(
                                label: 'Retake test',
                                icon: LucideIcons.rotateCcw,
                                color: ExamColors.action,
                                height: 45,
                                radius: 8,
                                onPressed: retake,
                              ),
                            ),
                          if (retake != null && canReview) const SizedBox(width: 27),
                          if (canReview)
                            Expanded(
                              flex: 166,
                              child: ExamButton(
                                label: 'Review answers',
                                icon: LucideIcons.clipboardCheck,
                                quiet: true,
                                color: ExamColors.ink,
                                borderColor: ExamColors.hairline,
                                height: 45,
                                radius: 8,
                                onPressed: _review,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small rounded label.
class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.fill, required this.style, this.height = 20});

  final String text;
  final Color fill;
  final TextStyle style;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(10)),
      child: Center(
        widthFactor: 1,
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
      ),
    );
  }
}

/// "TEST ANALYSIS — SET 1" and the kind of paper.
class _Chips extends StatelessWidget {
  const _Chips({required this.tag, required this.kind});

  final String tag;
  final String kind;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Tag(text: tag, fill: ExamColors.greyTint, style: ExamText.tag),
        _Tag(
          text: kind,
          fill: ExamColors.hairline,
          style: ExamText.tag.copyWith(color: ExamColors.greyInk),
        ),
      ],
    );
  }
}

/// "You scored 0%", the percentage in red (green when passed); a certifying paper keeps its own headline.
class _Headline extends StatelessWidget {
  const _Headline({
    required this.certifying,
    required this.passed,
    required this.percentage,
    required this.certifiedText,
  });

  final bool certifying;
  final bool passed;
  final int percentage;
  final String certifiedText;

  @override
  Widget build(BuildContext context) {
    final tone = passed ? ExamColors.right : ExamColors.wrong;
    return Semantics(
      header: true,
      child: certifying
          ? Text(certifiedText, style: ExamText.resultHeadline.copyWith(color: passed ? ExamColors.ink : tone))
          : Text.rich(
              TextSpan(
                style: ExamText.resultHeadline,
                children: [
                  const TextSpan(text: 'You scored '),
                  TextSpan(
                    text: '$percentage%',
                    style: TextStyle(color: tone),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Score, percentage, correct, wrong, unanswered and time taken: three tiles to a row.
class _Tiles extends StatelessWidget {
  const _Tiles({required this.attempt});

  final Attempt attempt;

  @override
  Widget build(BuildContext context) {
    final a = attempt;
    final tiles = [
      _Tile(value: '${a.score} / ${a.maxScore}', label: 'Score', color: ExamColors.ink),
      _Tile(value: '${a.percentage}%', label: 'Percentage', color: ExamColors.ink),
      _Tile(value: '${a.correct}', label: 'Correct', color: ExamColors.right),
      _Tile(value: '${a.wrong}', label: 'Wrong', color: ExamColors.wrong),
      _Tile(value: '${a.unanswered}', label: 'Unanswered', color: ExamColors.ink),
      _Tile(value: takenLabel(a.timeTaken), label: 'Time taken', color: ExamColors.ink),
    ];
    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 6),
          Row(
            children: [
              for (var col = 0; col < 3; col++) ...[
                if (col > 0) const SizedBox(width: 8),
                Expanded(child: tiles[row * 3 + col]),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$value $label',
      excludeSemantics: true,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(8)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: ExamText.tileValue.copyWith(color: color)),
            ),
            const SizedBox(height: 8),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: ExamText.tileLabel),
          ],
        ),
      ),
    );
  }
}

/// Which sitting this is.
class _AttemptCount extends StatelessWidget {
  const _AttemptCount({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Attempt Count $number',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            const Icon(LucideIcons.history, size: 16, color: ExamColors.action),
            const SizedBox(width: 10),
            Expanded(child: Text('Attempt Count', style: ExamText.cardTitle)),
            _Tag(
              text: '#$number',
              fill: ExamColors.paleBlue,
              height: 28,
              style: ExamText.tag.copyWith(color: ExamColors.ink, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
