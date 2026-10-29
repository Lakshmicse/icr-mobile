import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/buttons.dart';
import 'certificate_view.dart';
import 'exam_format.dart';
import 'exam_models.dart';
import 'exam_repository.dart';
import 'exam_styles.dart';
import 'exam_widgets.dart';
import 'my_attempts_screen.dart';

/// The result of a sitting, straight after it or reopened from the history: the score and whether it
/// passed, the breakdown, every question worked through with the right answer and the explanation, and the
/// member's other sittings of the same paper.
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
    this.repository,
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

  /// Where the member's other sittings of this paper are read from. Without it "My attempts" lists only the
  /// sitting on show.
  final ExamRepository? repository;

  /// What each question was worth, by question id, when the sitting is fresh (a review does not carry it).
  final Map<String, int>? questionMarks;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

enum _Filter { all, incorrect, unanswered, correct }

class _ResultScreenState extends State<ResultScreen> {
  _Filter _filter = _Filter.all;

  /// The question on show, as an index into [AttemptResult.review].
  int _current = 0;
  List<Attempt>? _history;
  final _scroll = ScrollController();
  final _reviewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    unawaited(_loadHistory());
  }

  @override
  void dispose() {
    _scroll.dispose();
    widget.onClosed?.call();
    super.dispose();
  }

  AttemptResult get result => widget.result;
  Attempt get attempt => result.attempt;

  Future<void> _loadHistory() async {
    final repo = widget.repository;
    if (repo == null) return;
    try {
      final rows = await repo.attempts(paperId: attempt.paperId.isEmpty ? null : attempt.paperId);
      if (mounted) setState(() => _history = rows);
    } catch (_) {
      // The sitting on show is listed regardless.
    }
  }

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
        : 'You scored $pct%, and the pass mark is $pass%. Work through the answers below, then try again.';
  }

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

  void _select(_Filter f) {
    setState(() {
      _filter = f;
      final shown = _indexes;
      if (shown.isNotEmpty && !shown.contains(_current)) _current = shown.first;
    });
  }

  void _step(int by) {
    final shown = _indexes;
    final at = shown.indexOf(_current);
    final to = at + by;
    if (at < 0 || to < 0 || to >= shown.length) return;
    setState(() => _current = shown[to]);
  }

  /// What the question was worth: the review says, else the sitting just taken, else one mark when the whole
  /// paper is worth one per question; null when it cannot be told.
  int? _marksOf(ReviewItem r) =>
      r.marks ?? widget.questionMarks?[r.id] ?? (attempt.maxScore == attempt.totalQuestions ? 1 : null);

  void _toReview() {
    final context = _reviewKey.currentContext;
    if (context == null) return;
    unawaited(Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 300), curve: Curves.easeOut));
  }

  void _toTop() {
    if (_scroll.hasClients) {
      unawaited(_scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cert = result.certificate;
    final VoidCallback? retake = widget.onRetake == null
        ? null
        : () {
            if (popOnce(context)) widget.onRetake!();
          };
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ExamTitleBar(title: 'Test Results', onBack: () => popOnce(context)),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Chips(tag: _tag, kind: widget.certificateEnabled ? 'Summative' : 'Formative'),
                          const SizedBox(height: 14),
                          _Headline(
                            certifying: widget.certificateEnabled,
                            passed: attempt.passed,
                            percentage: attempt.percentage,
                            certifiedText: _certifiedHeadline,
                          ),
                          const SizedBox(height: 6),
                          Text(_blurb, style: ExamText.resultSubline),
                          const SizedBox(height: 8),
                          _PassMark(attempt: attempt, certifying: widget.certificateEnabled),
                          if (cert != null) ...[
                            const SizedBox(height: 14),
                            Notice(
                              tone: NoticeTone.success,
                              text: 'Certificate issued: ${cert.certificateId}, on attempt ${cert.attempt}.',
                              action: 'View certificate',
                              onAction: () => showCertificateSheet(context, cert),
                            ),
                          ],
                          if (result.missing > 0) ...[
                            const SizedBox(height: 14),
                            Notice(
                              text: result.missing == 1
                                  ? '1 question from this sitting has since been removed from the bank, so it is not shown below. Your score still counts it.'
                                  : '${result.missing} questions from this sitting have since been removed from the bank, so they are not shown below. Your score still counts them.',
                            ),
                          ],
                          const SizedBox(height: 18),
                          _Tiles(attempt: attempt),
                          const SizedBox(height: 12),
                          _AttemptCount(number: attempt.attempt),
                          if (retake != null || result.review.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (retake != null)
                                  Expanded(
                                    child: ExamButton(
                                      label: 'Retake test',
                                      icon: LucideIcons.rotateCcw,
                                      radius: 10,
                                      onPressed: retake,
                                    ),
                                  ),
                                if (retake != null && result.review.isNotEmpty) const SizedBox(width: 12),
                                if (result.review.isNotEmpty)
                                  Expanded(
                                    child: ExamButton(
                                      label: 'Review answers',
                                      icon: LucideIcons.clipboardCheck,
                                      quiet: true,
                                      color: ExamColors.ink,
                                      borderColor: ExamColors.hairline,
                                      radius: 10,
                                      onPressed: _toReview,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          if (_topics().length > 1) ...[const SizedBox(height: 16), _Topics(rows: _topics())],
                          if (result.review.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Padding(
                              key: _reviewKey,
                              padding: const EdgeInsets.only(top: 12),
                              child: Semantics(
                                header: true,
                                child: Text('Question Review & Explanations', style: ExamText.sectionTitle),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Filters(
                              current: _filter,
                              counts: {for (final f in _Filter.values) f: _count(f)},
                              onSelect: _select,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                    // The strip runs to the edges of the screen; the rest keeps its 16 dp margins.
                    if (_indexes.isNotEmpty)
                      _Strip(
                        numbers: _indexes,
                        review: result.review,
                        current: _shownIndex,
                        onTap: (i) => setState(() => _current = i),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ..._review(),
                          const SizedBox(height: 24),
                          _Attempts(
                            current: attempt,
                            history: _history,
                            onThis: () => cert == null ? _toTop() : showCertificateSheet(context, cert),
                            onOther: (a) => _openAttempt(context, a),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _Bar(certificate: cert, onRetake: retake, onBack: () => popOnce(context)),
          ],
        ),
      ),
    );
  }

  /// The question on show: the one chosen if the filter lets it through, else the first that it does.
  int get _shownIndex {
    final shown = _indexes;
    return shown.isEmpty || shown.contains(_current) ? _current : shown.first;
  }

  /// The question on show and the pager.
  List<Widget> _review() {
    final shown = _indexes;
    if (result.review.isEmpty) return const [];
    if (shown.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text('Nothing here.', style: ExamText.body)),
        ),
      ];
    }
    final index = _shownIndex;
    final position = shown.indexOf(index);
    final item = result.review[index];
    return [
      const SizedBox(height: 14),
      ReviewCard(item: item, number: index + 1, marks: _marksOf(item)),
      const SizedBox(height: 14),
      _Pager(
        number: index + 1,
        total: result.review.length,
        onPrevious: position > 0 ? () => _step(-1) : null,
        onNext: position < shown.length - 1 ? () => _step(1) : null,
      ),
    ];
  }

  /// Another sitting of the paper, opened as a result of its own.
  void _openAttempt(BuildContext context, Attempt a) {
    final repo = widget.repository;
    if (repo == null) return;
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AttemptResultLoader(
            attempt: a,
            repository: repo,
            // Retaking from an older sitting closes this result as well, then starts the paper again.
            onRetake: widget.onRetake == null
                ? null
                : () {
                    if (mounted && popOnce(context)) widget.onRetake!();
                  },
          ),
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

/// A small rounded label.
class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.fill, required this.style});

  final String text;
  final Color fill;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(999)),
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
        _Tag(text: tag, fill: ExamColors.blueTint, style: ExamText.tag),
        _Tag(
          text: kind,
          fill: ExamColors.greyTint,
          style: ExamText.tag.copyWith(color: ExamColors.greyInk, letterSpacing: 0),
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
    final tone = passed ? ExamColors.green : ExamColors.red;
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

/// Whether the pass mark was met, in a line under the headline.
class _PassMark extends StatelessWidget {
  const _PassMark({required this.attempt, required this.certifying});

  final Attempt attempt;
  final bool certifying;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label, Color color) = attempt.passed
        ? (LucideIcons.badgeCheck, 'Passed', ExamColors.green)
        : certifying
        ? (LucideIcons.circleX, 'Not passed · ${attempt.passPercentage}% to pass', ExamColors.red)
        : (LucideIcons.flag, 'Below the ${attempt.passPercentage}% pass mark', AppColors.amber800);
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label, style: ExamText.cardTitle.copyWith(color: color, fontSize: 14)),
        ),
      ],
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
      _Tile(value: '${a.correct}', label: 'Correct', color: ExamColors.green),
      _Tile(value: '${a.wrong}', label: 'Wrong', color: ExamColors.red),
      _Tile(value: '${a.unanswered}', label: 'Unanswered', color: ExamColors.greyMuted),
      _Tile(value: takenLabel(a.timeTaken), label: 'Time taken', color: ExamColors.ink),
    ];
    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var col = 0; col < 3; col++) ...[
                  if (col > 0) const SizedBox(width: 8),
                  Expanded(child: tiles[row * 3 + col]),
                ],
              ],
            ),
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ExamColors.hairline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: ExamText.tileValue.copyWith(color: color)),
            ),
            const SizedBox(height: 2),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ExamColors.hairline),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.history, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text('Attempt Count', style: ExamText.cardTitle)),
            _Tag(
              text: '#$number',
              fill: ExamColors.blueTint,
              style: ExamText.tag.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0),
            ),
          ],
        ),
      ),
    );
  }
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
      radius: 10,
      borderColor: ExamColors.hairline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('By topic', style: ExamText.cardTitle),
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
    _Filter.all => on ? (AppColors.primary, Colors.white) : (ExamColors.greyTint, ExamColors.ink),
    _Filter.incorrect => on ? (ExamColors.red, Colors.white) : (ExamColors.redTint, ExamColors.red),
    _Filter.correct => on ? (AppColors.primary, Colors.white) : (ExamColors.blueTint, AppColors.primary),
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
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(999)),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          '${_labels[f]} (${counts[f]})',
                          style: ExamText.tag.copyWith(color: ink, letterSpacing: 0),
                        ),
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
  static const cell = 40.0;
  static const gap = 8.0;
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

  /// Brings the question on show to the middle of the strip.
  void _reveal({bool animate = true}) {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    final at = widget.numbers.indexOf(widget.current);
    if (at < 0) return;
    final target = (16 + at * (cell + gap) - (position.viewportDimension - cell) / 2).clamp(
      0.0,
      position.maxScrollExtent,
    );
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
    final (Color fill, Color? edge, Color ink) = current
        ? (ExamColors.current, null, Colors.white)
        : switch (outcome) {
            ReviewOutcome.correct => (Colors.white, ExamColors.green, ExamColors.green),
            ReviewOutcome.incorrect => (Colors.white, ExamColors.red, ExamColors.red),
            ReviewOutcome.skipped => (ExamColors.stripBlank, null, ExamColors.stripBlankInk),
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
            borderRadius: BorderRadius.circular(8),
            border: edge == null ? null : Border.all(color: edge, width: 2),
          ),
          child: Text('$number', style: ExamText.stripNumber.copyWith(color: ink)),
        ),
      ),
    );
  }
}

/// One question worked through: how it turned out, every option marked, the explanation.
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.item, required this.number, this.marks});

  final ReviewItem item;
  final int number;

  /// What the question was worth; null leaves the mark line off.
  final int? marks;

  @override
  Widget build(BuildContext context) {
    final correct = {...item.correctIndexes};
    final picked = {...item.selected};
    final earned = item.outcome == ReviewOutcome.correct ? marks : 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ExamColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Tag(
                      text: 'Question $number',
                      fill: ExamColors.blueTint,
                      style: ExamText.tag.copyWith(letterSpacing: 0),
                    ),
                    _OutcomePill(outcome: item.outcome),
                  ],
                ),
              ),
              if (marks != null) ...[
                const SizedBox(width: 8),
                Text('$earned / $marks ${marks == 1 ? 'Mark' : 'Marks'}', style: ExamText.pagerLabel),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(item.prompt, style: ExamText.reviewQuestion),
          const SizedBox(height: 14),
          for (final (i, option) in item.options.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            _ReviewOption(index: i, text: option, isCorrect: correct.contains(i), isPicked: picked.contains(i)),
          ],
          if (item.explanation != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: ExamColors.greyTint, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Detailed Explanation & Rationale', style: ExamText.rationaleTitle),
                  const SizedBox(height: 6),
                  Text(item.explanation!, style: ExamText.rationale),
                  if (item.category != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                      child: Text('Core Topic: ${item.category}', style: ExamText.topicPill),
                    ),
                  ],
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
    final (String label, IconData? icon, Color ink, Color fill) = switch (outcome) {
      ReviewOutcome.correct => ('Correct', LucideIcons.check, ExamColors.green, ExamColors.greenTint),
      ReviewOutcome.incorrect => ('Incorrect', LucideIcons.x, ExamColors.red, ExamColors.redTint),
      ReviewOutcome.skipped => ('Unanswered', null, ExamColors.greyInk, ExamColors.greyTint),
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: ink), const SizedBox(width: 4)],
            Text(label, style: ExamText.tag.copyWith(color: ink, letterSpacing: 0)),
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
    final Color? tone = isCorrect ? ExamColors.green : (wrongPick ? ExamColors.red : null);
    final String? mark = isCorrect
        ? (isPicked ? 'Your Answer (Correct)' : 'Correct Answer')
        : (wrongPick ? 'Your Answer (Incorrect)' : null);
    return Semantics(
      container: true,
      label: 'Option ${optionLetter(index)}. $text.${mark == null ? '' : ' $mark.'}',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCorrect ? ExamColors.greenTint : (wrongPick ? ExamColors.redTint : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tone ?? ExamColors.hairline, width: tone == null ? 1 : 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: Text(optionLetter(index), style: ExamText.reviewLetter.copyWith(color: tone)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: ExamText.reviewOption.copyWith(color: tone == null ? ExamColors.greyInk : ExamColors.ink),
                  ),
                ),
              ],
            ),
            if (mark != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 30),
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
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: filled ? BorderSide.none : const BorderSide(color: ExamColors.hairline),
    );
    final glyph = Icon(icon, size: 16, color: ink);
    final words = Text(label, style: ExamText.buttonQuiet.copyWith(color: ink));
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: filled ? (enabled ? AppColors.primary : AppColors.primary.withValues(alpha: 0.4)) : Colors.white,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
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

/// The member's sittings of this paper, newest first, each with its score, result and time.
class _Attempts extends StatelessWidget {
  const _Attempts({required this.current, required this.history, required this.onThis, required this.onOther});

  final Attempt current;
  final List<Attempt>? history;

  /// Open the sitting on show (its certificate, else back to the top of this page).
  final VoidCallback onThis;
  final ValueChanged<Attempt> onOther;

  List<Attempt> get _rows {
    final rows = <Attempt>[
      for (final a in history ?? const <Attempt>[])
        if (current.paperId.isEmpty || a.paperId == current.paperId) a,
    ];
    if (!rows.any((a) => a.id == current.id)) rows.add(current);
    rows.sort((a, b) => b.attempt.compareTo(a.attempt));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Semantics(header: true, child: Text('My attempts', style: ExamText.sectionTitle)),
            ),
            const SizedBox(width: 8),
            Text('${rows.length} ${rows.length == 1 ? 'attempt' : 'attempts'} recorded', style: ExamText.pagerLabel),
          ],
        ),
        const SizedBox(height: 12),
        for (final (i, a) in rows.indexed) ...[
          if (i > 0) const SizedBox(height: 16),
          _AttemptRow(attempt: a, onOpen: a.id == current.id ? onThis : () => onOther(a)),
        ],
      ],
    );
  }
}

class _AttemptRow extends StatelessWidget {
  const _AttemptRow({required this.attempt, required this.onOpen});

  final Attempt attempt;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final a = attempt;
    final when = dateTimeLabel(a.submittedAt);
    final tone = a.passed ? ExamColors.green : ExamColors.red;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('#${a.attempt}', style: ExamText.attemptNumber),
            const SizedBox(width: 10),
            Expanded(child: Text(when, style: ExamText.attemptDate)),
            Semantics(
              button: true,
              label: 'Open attempt ${a.attempt}',
              excludeSemantics: true,
              child: InkResponse(
                onTap: onOpen,
                radius: 24,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Icon(LucideIcons.fileText, size: 22, color: AppColors.primary),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ExamColors.hairline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Figure(label: 'Score', value: '${a.score} / ${a.maxScore}'),
              _Figure(label: 'Result', value: '${a.percentage}%', color: tone),
              _Figure(label: 'Duration', value: takenLabel(a.timeTaken)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ExamText.tileLabel),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ExamText.summaryValue.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Pinned under the page: the certificate (when there is one) or the way back, and Retake Test.
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
        Expanded(
          child: cert != null
              ? ExamButton(
                  label: 'View certificate',
                  icon: LucideIcons.award,
                  quiet: true,
                  color: ExamColors.ink,
                  borderColor: ExamColors.hairline,
                  radius: 10,
                  onPressed: () => showCertificateSheet(context, cert),
                )
              : ExamButton(
                  label: 'Back',
                  icon: LucideIcons.arrowLeft,
                  quiet: true,
                  color: ExamColors.ink,
                  borderColor: ExamColors.hairline,
                  radius: 10,
                  onPressed: onBack,
                ),
        ),
        if (onRetake != null)
          Expanded(
            child: ExamButton(label: 'Retake Test', icon: LucideIcons.rotateCcw, radius: 10, onPressed: onRetake),
          ),
      ],
    );
  }
}
