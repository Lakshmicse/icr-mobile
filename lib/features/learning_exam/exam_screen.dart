import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import 'exam_controller.dart';
import 'exam_format.dart';
import 'exam_sheets.dart';
import 'exam_styles.dart';
import 'exam_widgets.dart';
import 'result_screen.dart';

/// The exam window: one question at a time under a running clock, with a number strip, a palette, flags, and
/// a submit overview. It has no tab bar and no way out but submitting or leaving (which asks first).
///
/// The screen draws the [ExamController] and holds nothing of its own, so a rebuild, a rotation or the app
/// going to the background cannot lose an answer: they are in the controller, which keeps them to the store.
class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key, required this.controller, this.firstName, this.onRetake, this.onFlowEnd});

  final ExamController controller;

  /// Called once the member has left the whole flow (the exam, or the result it handed over to).
  final VoidCallback? onFlowEnd;

  /// For the result's greeting.
  final String? firstName;

  /// What "Retake" does on the result, after the result closes.
  final VoidCallback? onRetake;

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> with WidgetsBindingObserver {
  ExamController get c => widget.controller;
  bool _left = false;
  bool _handedOver = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_onChange);
    c.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(_onChange);
    c.dispose();
    if (!_handedOver) widget.onFlowEnd?.call();
    super.dispose();
  }

  /// Coming back from the background: the clock is the wall clock, so recompute it at once rather than
  /// waiting for the next tick (and send the answers if the time ran out meanwhile).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) c.tick();
  }

  void _onChange() {
    if (!mounted || _left) return;
    if (c.phase == ExamPhase.submitting && c.autoSubmitted) {
      // The clock ran out under an open sheet or dialog: close them so the message shows.
      Navigator.of(context).popUntil((r) => r is! PopupRoute);
    }
    if (c.phase == ExamPhase.done && c.result != null) {
      _left = true;
      _handedOver = true;
      final result = c.result!;
      final paper = c.paper;
      final repository = c.repository;
      final marks = {for (final q in c.questions) q.id: q.marks};
      final navigator = Navigator.of(context);
      navigator.popUntil((r) => r is! PopupRoute);
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(
            result: result,
            paperName: paper.name,
            certificateEnabled: paper.certificateEnabled,
            firstName: widget.firstName,
            onRetake: widget.onRetake,
            onClosed: widget.onFlowEnd,
            setName: paper.title,
            repository: repository,
            questionMarks: marks,
          ),
        ),
      );
    }
  }

  Future<void> _leave() async {
    if (c.phase == ExamPhase.submitting) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('Leave the exam?', style: ExamText.heading),
        content: Text(
          'Your answers are saved on this phone and the clock keeps running. You can resume from the paper until time runs out; after that your answers are submitted as they are.',
          style: ExamText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => popOnce(ctx, false),
            child: Text('Keep going', style: ExamText.link),
          ),
          TextButton(
            onPressed: () => popOnce(ctx, true),
            child: Text('Leave', style: ExamText.link.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      _left = true;
      popOnce(context);
    }
  }

  void _openPalette() {
    showExamSheet<void>(
      context,
      (sheet) => PaletteSheet(
        controller: c,
        onJump: (i) {
          if (popOnce(sheet)) c.goTo(i);
        },
        onReview: () {
          if (popOnce(sheet)) _openOverview();
        },
      ),
    );
  }

  void _openOverview() {
    showExamSheet<void>(
      context,
      (sheet) => OverviewSheet(
        controller: c,
        onJump: (i) {
          if (popOnce(sheet)) c.goTo(i);
        },
        onSubmit: () {
          if (popOnce(sheet)) c.submit();
        },
      ),
    );
  }

  /// Leaves for good after a refusal that cannot be undone: nothing to resume.
  Future<void> _giveUp() async {
    await c.discard();
    if (mounted) {
      _left = true;
      popOnce(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) => Stack(
              children: [
                Column(
                  children: [
                    ExamTitleBar(
                      title: c.paper.isMock ? 'Mock Test' : 'Assessment',
                      style: ExamText.examTitle,
                      backLabel: 'Leave the exam',
                      onBack: _leave,
                    ),
                    Expanded(
                      child: _QuestionPane(controller: c, onPalette: _openPalette),
                    ),
                    _ActionBar(controller: c, onFinish: _openOverview),
                  ],
                ),
                if (c.phase == ExamPhase.submitting || c.phase == ExamPhase.failed)
                  Positioned.fill(
                    child: _SendOverlay(
                      controller: c,
                      onGiveUp: _giveUp,
                      onLeave: () {
                        _left = true;
                        popOnce(context);
                      },
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

/// The countdown, in a pill under the bar: "Time Left: 14:32". Red on a tint; solid red in the last five
/// minutes.
class ClockChip extends StatelessWidget {
  const ClockChip({super.key, required this.controller});

  final ExamController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: controller.remaining,
      builder: (context, left, _) {
        final low = left < const Duration(minutes: 5);
        final fill = low ? ExamColors.red : ExamColors.redTint;
        final ink = low ? Colors.white : ExamColors.red;
        return Semantics(
          label: 'Time remaining ${clockSpoken(left)}',
          excludeSemantics: true,
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.alarmClock, size: 16, color: ink),
                const SizedBox(width: 6),
                Text(
                  'Time Left: ${clockLabel(left)}',
                  style: ExamText.timeLeft.copyWith(color: ink, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The clock, then the strip, the open question and its options.
class _QuestionPane extends StatelessWidget {
  const _QuestionPane({required this.controller, required this.onPalette});

  final ExamController controller;
  final VoidCallback onPalette;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final q = c.question;
    final picked = c.picked(q.id);
    final difficulty = q.difficultyLabel;
    final canClear = c.editable && picked.isNotEmpty;
    return Column(
      children: [
        if (c.paper.durationMinutes > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ClockChip(controller: c),
          ),
        Expanded(
          child: ListView(
            key: ValueKey('question-${c.current}'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              _Strip(controller: c, onPalette: onPalette),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ExamColors.hairline),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 3))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Question ${c.current + 1}', style: ExamText.examQuestionNumber),
                        if (difficulty != null) _DifficultyChip(label: difficulty),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Semantics(header: true, child: Text(q.prompt, style: ExamText.examPrompt)),
                    if (q.multiple) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Select all that apply.',
                        style: ExamText.small.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Semantics(header: true, child: Text('Answer', style: ExamText.sectionTitle)),
                  ),
                  _ClearButton(onTap: canClear ? c.clearAnswer : null),
                ],
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < q.options.length; i++) ...[
                OptionTile(
                  index: i,
                  text: q.options[i],
                  selected: picked.contains(i),
                  multiple: q.multiple,
                  enabled: c.editable,
                  onTap: () => c.select(i),
                ),
                if (i < q.options.length - 1) const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// EASY, MEDIUM or HARD: an outlined, spaced-out label beside the question number.
class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Difficulty $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ExamColors.hairline),
        ),
        child: Text(label.toUpperCase(), style: ExamText.difficulty),
      ),
    );
  }
}

/// Takes the answer to the open question away; off until there is one.
class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink = onTap == null ? AppColors.slate300 : AppColors.primary;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: 'Clear',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.eraser, size: 16, color: ink),
                const SizedBox(width: 6),
                Text('Clear', style: ExamText.link.copyWith(color: ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The numbers around the open question, "…" and the last number, and the palette button at the far right.
class _Strip extends StatelessWidget {
  const _Strip({required this.controller, required this.onPalette});

  final ExamController controller;
  final VoidCallback onPalette;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final total = c.total;
    // Four numbers with the open one second or third among them, then "…" and the last number.
    final hi = math.min(total - 1, math.max(0, c.current - 2) + 3);
    final lo = math.max(0, hi - 3);
    final window = [for (var i = lo; i <= hi; i++) i];
    final more = hi < total - 1;
    final ellipsis = hi < total - 2;
    return LayoutBuilder(
      builder: (context, box) {
        final items = window.length + (more ? 1 : 0) + 1;
        double size = 44;
        double space = 8;
        double need() => items * size + (ellipsis ? 24 : 0) + items * space;
        if (need() > box.maxWidth) {
          size = 40;
          space = 6;
        }
        if (need() > box.maxWidth) {
          size = 36;
          space = 4;
        }
        Widget cell(int i) => _NumberCell(
          index: i,
          size: size,
          answered: c.isAnswered(i),
          flagged: c.isFlagged(i),
          current: i == c.current,
          onTap: () => c.goTo(i),
        );
        return Row(
          children: [
            for (final i in window) ...[cell(i), SizedBox(width: space)],
            if (ellipsis) ...[
              ExcludeSemantics(
                child: SizedBox(
                  width: 24,
                  child: Text('…', textAlign: TextAlign.center, style: ExamText.stripNumber),
                ),
              ),
              SizedBox(width: space),
            ],
            if (more) cell(total - 1),
            const Spacer(),
            Semantics(
              button: true,
              label: 'Question palette',
              excludeSemantics: true,
              child: Material(
                color: ExamColors.greyTint,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: onPalette,
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: const Icon(LucideIcons.layoutGrid, size: 20, color: ExamColors.ink),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One number of the strip: green when answered, deep navy when open, grey when not answered, outlined in amber
/// when flagged for review.
class _NumberCell extends StatelessWidget {
  const _NumberCell({
    required this.index,
    required this.size,
    required this.answered,
    required this.flagged,
    required this.current,
    required this.onTap,
  });

  final int index;
  final double size;
  final bool answered;
  final bool flagged;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (Color fill, Color ink) = current
        ? (ExamColors.current, Colors.white)
        : answered
        ? (ExamColors.stripAnswered, Colors.white)
        : (ExamColors.stripBlank, ExamColors.stripBlankInk);
    return Semantics(
      button: true,
      selected: current,
      label:
          'Go to question ${index + 1}, ${answered ? 'answered' : 'not answered'}${flagged ? ', flagged' : ''}${current ? ', current' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('strip-${index + 1}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(8),
            border: flagged ? Border.all(color: ExamColors.answeredFlagged, width: 2) : null,
          ),
          child: Text('${index + 1}', style: ExamText.stripNumber.copyWith(color: ink)),
        ),
      ),
    );
  }
}

/// One answer option: a radio (a tick box on a multiple-choice question) and the text. The whole card is the
/// target; the chosen one wears a primary border and a pale blue fill.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.index,
    required this.text,
    required this.selected,
    required this.multiple,
    required this.onTap,
    this.enabled = true,
  });

  final int index;
  final String text;
  final bool selected;
  final bool multiple;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: selected ? AppColors.primary : ExamColors.hairline, width: selected ? 2 : 1),
    );
    return Semantics(
      container: true,
      checked: selected,
      inMutuallyExclusiveGroup: !multiple,
      enabled: enabled,
      onTap: enabled ? onTap : null,
      label: 'Option ${optionLetter(index)}. $text',
      excludeSemantics: true,
      child: Material(
        color: selected ? ExamColors.chosenFill : Colors.white,
        shape: shape,
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: shape,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Marker(selected: selected, multiple: multiple),
                const SizedBox(width: 14),
                Expanded(child: Text(text, style: ExamText.examOption)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 24 dp radio, or the square tick box of a multiple-choice question.
class _Marker extends StatelessWidget {
  const _Marker({required this.selected, required this.multiple});

  final bool selected;
  final bool multiple;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.white,
        shape: multiple ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: multiple ? BorderRadius.circular(6) : null,
        border: Border.all(color: selected ? AppColors.primary : AppColors.slate400, width: 2),
      ),
      child: !selected
          ? null
          : multiple
          ? const Icon(LucideIcons.check, size: 16, color: Colors.white)
          : Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
    );
  }
}

/// Finish, and Review, Skip, Submit & Next.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.controller, required this.onFinish});

  final ExamController controller;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final flagged = c.isFlagged(c.current);
    final last = c.current == c.total - 1;
    final editable = c.editable;
    final width = MediaQuery.sizeOf(context).width;
    // Four buttons across: Review keeps only its bookmark where the words would not fit.
    final iconOnly = width < 340;
    final space = iconOnly ? 4.0 : 6.0;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: _BarButton(label: 'Finish', fill: ExamColors.finish, ink: Colors.white, onTap: onFinish),
              ),
              SizedBox(width: space),
              Expanded(
                flex: iconOnly ? 4 : 7,
                child: _BarButton(
                  label: 'Review',
                  spoken: flagged ? 'Unflag' : 'Flag for review',
                  icon: flagged ? Symbols.bookmark : LucideIcons.bookmark,
                  filledIcon: flagged,
                  iconOnly: iconOnly,
                  fill: flagged ? AppColors.amber50 : Colors.white,
                  edge: flagged ? ExamColors.answeredFlagged : ExamColors.hairline,
                  ink: flagged ? AppColors.amber800 : ExamColors.ink,
                  onTap: editable ? c.toggleFlag : null,
                ),
              ),
              SizedBox(width: space),
              Expanded(
                flex: 4,
                child: _BarButton(
                  label: 'Skip',
                  fill: Colors.white,
                  edge: ExamColors.hairline,
                  ink: ExamColors.ink,
                  onTap: last ? null : c.next,
                ),
              ),
              SizedBox(width: space),
              Expanded(
                flex: 9,
                child: _BarButton(
                  label: last ? 'Submit' : 'Submit & Next',
                  fill: AppColors.primary,
                  ink: Colors.white,
                  onTap: last ? onFinish : c.next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the exam bar's buttons: 56 dp, radius 8, filled or outlined, with a glyph if it has one.
class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.label,
    required this.fill,
    required this.ink,
    required this.onTap,
    this.edge,
    this.icon,
    this.filledIcon = false,
    this.iconOnly = false,
    this.spoken,
  });

  final String label;

  /// What a screen reader says when it differs from the words (the Review button flags and unflags).
  final String? spoken;
  final Color fill;
  final Color? edge;
  final Color ink;
  final IconData? icon;

  /// A Material Symbols glyph drawn solid, for a flagged question.
  final bool filledIcon;
  final bool iconOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: edge == null ? BorderSide.none : BorderSide(color: enabled ? edge! : AppColors.slate200),
    );
    final colour = enabled ? ink : AppColors.slate400;
    return Semantics(
      button: true,
      enabled: enabled,
      label: spoken ?? label,
      excludeSemantics: true,
      child: Material(
        color: enabled || edge != null ? fill : fill.withValues(alpha: 0.45),
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) Icon(icon, size: 18, color: colour, fill: filledIcon ? 1 : 0),
                      if (icon != null && !iconOnly) const SizedBox(width: 6),
                      if (!iconOnly)
                        Text(label, maxLines: 1, softWrap: false, style: ExamText.barButton.copyWith(color: colour)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Over the whole exam while the answers go, and when they could not: nothing underneath can be touched.
class _SendOverlay extends StatelessWidget {
  const _SendOverlay({required this.controller, required this.onGiveUp, required this.onLeave});

  final ExamController controller;
  final VoidCallback onGiveUp;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final failed = c.phase == ExamPhase.failed;
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!failed) ...[
                const SizedBox(width: 34, height: 34, child: CircularProgressIndicator(strokeWidth: 3)),
                const SizedBox(height: 18),
                Text(
                  c.autoSubmitted ? "Time's up" : 'Submitting your answers',
                  textAlign: TextAlign.center,
                  style: ExamText.heroTitle.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  c.autoSubmitted ? 'Submitting what you have answered…' : 'Marking your paper…',
                  textAlign: TextAlign.center,
                  style: ExamText.body,
                ),
              ] else ...[
                const Icon(LucideIcons.circleAlert, size: 38, color: AppColors.error),
                const SizedBox(height: 14),
                Text(
                  "Your answers didn't go",
                  textAlign: TextAlign.center,
                  style: ExamText.heroTitle.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 8),
                Text(c.error ?? 'Something went wrong.', textAlign: TextAlign.center, style: ExamText.body),
                const SizedBox(height: 6),
                Text(
                  c.retryable
                      ? 'They are safe on this phone. Try again when you are ready.'
                      : 'The API turned this sitting down, so there is nothing to retry.',
                  textAlign: TextAlign.center,
                  style: ExamText.small,
                ),
                const SizedBox(height: 22),
                if (c.retryable) ...[
                  ExamButton(
                    label: 'Try again',
                    icon: LucideIcons.refreshCw,
                    onPressed: () => c.submit(auto: c.autoSubmitted),
                  ),
                  const SizedBox(height: 10),
                  if (!c.timeUp) ...[
                    ExamButton(label: 'Back to the test', quiet: true, onPressed: c.reopen),
                    const SizedBox(height: 10),
                  ],
                  ExamButton(label: 'Leave for now', quiet: true, color: AppColors.slate600, onPressed: onLeave),
                ] else
                  ExamButton(label: 'Close', quiet: true, onPressed: onGiveUp),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
