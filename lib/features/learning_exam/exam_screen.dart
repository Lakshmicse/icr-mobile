import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import 'exam_controller.dart';
import 'exam_format.dart';
import 'exam_sheets.dart';
import 'exam_styles.dart';
import 'exam_widgets.dart';
import 'result_screen.dart';

/// The exam window: one question at a time under a running clock, with a palette, flags, and a submit
/// overview. It has no tab bar and no way out but submitting or leaving (which asks first).
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
                    _ExamBar(controller: c, onLeave: _leave, onPalette: _openPalette),
                    LinearProgressIndicator(
                      value: (c.current + 1) / c.total,
                      minHeight: 3,
                      backgroundColor: AppColors.slate100,
                      color: AppColors.primary,
                    ),
                    Expanded(child: _QuestionPane(controller: c)),
                    _ActionBar(controller: c, onReview: _openOverview),
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

/// Leave, the paper's name and where you are, the clock, the palette.
class _ExamBar extends StatelessWidget {
  const _ExamBar({required this.controller, required this.onLeave, required this.onPalette});

  final ExamController controller;
  final VoidCallback onLeave;
  final VoidCallback onPalette;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final answered = c.counts.answered;
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Leave the exam',
            excludeSemantics: true,
            child: InkResponse(
              onTap: onLeave,
              radius: 26,
              child: const SizedBox(
                width: 46,
                height: 56,
                child: Icon(LucideIcons.x, size: 22, color: AppColors.slate600),
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.paper.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.workSans(14, FontWeight.w700, AppColors.onSurface, lineHeight: 18),
                ),
                Text(
                  'Question ${c.current + 1} of ${c.total} · $answered answered',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.plexSans(12, FontWeight.w500, AppColors.inkMuted, lineHeight: 16),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ClockChip(controller: c),
          Semantics(
            button: true,
            label: 'Question palette',
            excludeSemantics: true,
            child: InkResponse(
              onTap: onPalette,
              radius: 26,
              child: const SizedBox(
                width: 46,
                height: 56,
                child: Icon(LucideIcons.layoutGrid, size: 22, color: AppColors.slate600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The countdown. Turns red in the last five minutes.
class ClockChip extends StatelessWidget {
  const ClockChip({super.key, required this.controller});

  final ExamController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: controller.remaining,
      builder: (context, left, _) {
        final low = left < const Duration(minutes: 5);
        final ink = low ? AppColors.error : AppColors.primary;
        return Semantics(
          label: 'Time remaining ${clockSpoken(left)}',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: ink.withValues(alpha: low ? 0.1 : 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.timer, size: 16, color: ink),
                const SizedBox(width: 5),
                Text(
                  clockLabel(left),
                  style: ExamText.clock.copyWith(color: ink, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The open question and its options.
class _QuestionPane extends StatelessWidget {
  const _QuestionPane({required this.controller});

  final ExamController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final q = c.question;
    final picked = c.picked(q.id);
    return ListView(
      key: ValueKey('question-${c.current}'),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      children: [
        Row(
          children: [
            Text('QUESTION ${c.current + 1}', style: ExamText.eyebrow),
            if (q.category != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '· ${q.category!.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ExamText.eyebrow.copyWith(color: AppColors.slate500),
                ),
              ),
            ],
            const Spacer(),
            if (c.isFlagged(c.current))
              const InfoPill(label: 'Flagged', icon: LucideIcons.flag, color: ExamColors.flagged),
          ],
        ),
        const SizedBox(height: 10),
        Semantics(header: true, child: Text(q.prompt, style: ExamText.question)),
        if (q.multiple) ...[
          const SizedBox(height: 10),
          Text(
            'Select all that apply.',
            style: ExamText.small.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
          ),
        ],
        const SizedBox(height: 18),
        for (var i = 0; i < q.options.length; i++) ...[
          OptionTile(
            index: i,
            text: q.options[i],
            selected: picked.contains(i),
            multiple: q.multiple,
            enabled: c.editable,
            onTap: () => c.select(i),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// One answer option: its letter, the text, and a radio or tick that fills when chosen. The whole row is the target.
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
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: selected ? AppColors.primary : ExamColors.cardBorder, width: selected ? 1.5 : 1),
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
        color: selected ? ExamColors.optionSelectedFill : Colors.white,
        shape: shape,
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Marker(letter: optionLetter(index), selected: selected, multiple: multiple),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(text, style: ExamText.option),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.letter, required this.selected, required this.multiple});

  final String letter;
  final bool selected;
  final bool multiple;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.white,
        shape: multiple ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: multiple ? BorderRadius.circular(8) : null,
        border: Border.all(color: selected ? AppColors.primary : AppColors.slate300, width: 1.5),
      ),
      child: selected && multiple
          ? const Icon(LucideIcons.check, size: 16, color: Colors.white)
          : Text(letter, style: ExamText.optionLetter.copyWith(color: selected ? Colors.white : AppColors.slate600)),
    );
  }
}

/// Flag, clear, submit; and the way through the paper.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.controller, required this.onReview});

  final ExamController controller;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final flagged = c.isFlagged(c.current);
    final last = c.current == c.total - 1;
    final editable = c.editable;
    // "Flag for review" is shortened where three words would not fit beside Clear and Submit.
    final narrow = MediaQuery.sizeOf(context).width < 360;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _QuietAction(
                    icon: flagged ? LucideIcons.flag : LucideIcons.flagTriangleRight,
                    label: flagged ? 'Unflag' : (narrow ? 'Flag' : 'Flag for review'),
                    spoken: flagged ? 'Unflag' : 'Flag for review',
                    color: flagged ? ExamColors.flagged : AppColors.slate600,
                    onTap: editable ? c.toggleFlag : null,
                  ),
                  _QuietAction(
                    icon: LucideIcons.eraser,
                    label: 'Clear',
                    color: AppColors.slate600,
                    onTap: editable && c.picked(c.question.id).isNotEmpty ? c.clearAnswer : null,
                  ),
                  const Spacer(),
                  _QuietAction(icon: LucideIcons.send, label: 'Submit', color: AppColors.primary, onTap: onReview),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ExamButton(
                      label: 'Previous',
                      icon: LucideIcons.chevronLeft,
                      quiet: true,
                      color: AppColors.slate700,
                      onPressed: c.current == 0 ? null : c.previous,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: last
                        ? ExamButton(label: 'Review & submit', icon: LucideIcons.listChecks, onPressed: onReview)
                        : ExamButton(label: 'Next', icon: LucideIcons.chevronRight, onPressed: c.next),
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

class _QuietAction extends StatelessWidget {
  const _QuietAction({required this.icon, required this.label, required this.color, required this.onTap, this.spoken});

  final IconData icon;
  final String label;

  /// What a screen reader says when the shown label is shortened for a narrow phone.
  final String? spoken;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink = onTap == null ? AppColors.slate300 : color;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: spoken ?? label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: ink),
                const SizedBox(width: 6),
                Text(label, style: AppText.workSans(13, FontWeight.w600, ink, lineHeight: 18)),
              ],
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
