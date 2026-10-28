import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../assess_format.dart';
import '../assess_models.dart';
import '../assess_styles.dart';
import '../group_controller.dart';
import 'status_pill.dart';

/// What a paper card's buttons do; the screen owns them (a sheet to confirm, a call, the website).
class PaperActions {
  const PaperActions({
    required this.onStart,
    required this.onRedeem,
    required this.onOpenWithPlan,
    required this.onBuy,
    required this.onSeePlans,
  });

  /// Open the exam (the brief, the questions, the result).
  final VoidCallback onStart;

  /// Spend ICR credits to open this paper for good.
  final VoidCallback onRedeem;

  /// Open the whole course or exam with a plan place.
  final VoidCallback onOpenWithPlan;

  /// The website's page for this paper, where a payment is made.
  final VoidCallback onBuy;

  /// The plans that open more.
  final VoidCallback onSeePlans;
}

/// One assessment level or one mock set, as a card of its own: who it is, the three numbers a candidate decides
/// on (questions, time, pass mark), how the member did, what opening it takes if it is closed to them, and the
/// button that does the next thing: Start / Retake, Open with my plan, Redeem credits, or pay on the website.
///
/// The website's `LevelCard` and `SetCard`, drawn for a phone: one card to a row, buttons 48 dp tall.
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.entry,
    required this.index,
    required this.actions,
    this.heldCredits,
    this.canPlan = true,
  });

  final PaperEntry entry;

  /// Position in the group, for a set's number.
  final int index;
  final PaperActions actions;

  /// The member's ICR credits; null when their unlocks are not known.
  final int? heldCredits;

  /// "See plans" has somewhere to lead (a mock exam's page offers none when no plan opens more of them).
  final bool canPlan;

  AssessPaper get paper => entry.paper;
  bool get isMock => paper.kind == PaperKind.mock;
  RungLook get look => isMock
      ? const RungLook(main: AppColors.primary, ink: AppColors.primary, wash: AppColors.chipEmphasis, tagline: '')
      : AssessColors.rung(paper.level);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('paper-${paper.id}'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AssessColors.panelBorder),
        boxShadow: const [BoxShadow(color: Color(0x120B1F3A), blurRadius: 14, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          isMock ? _SetHeader(entry: entry, index: index) : _LevelHeader(entry: entry, look: look),
          const SizedBox(height: 14),
          _StatStrip(paper: paper),
          if (entry.progress.started) ...[const SizedBox(height: 12), _ProgressBlock(entry: entry)],
          if (!entry.progress.started && paper.attemptLimit != null) ...[
            const SizedBox(height: 10),
            Text('Up to ${paper.attemptLimit} attempts', style: AssessText.progressNote),
          ],
          const SizedBox(height: 12),
          _AccessPanel(entry: entry, look: look, canPlan: canPlan),
          const SizedBox(height: 12),
          _Actions(entry: entry, look: look, actions: actions, heldCredits: heldCredits, canPlan: canPlan),
        ],
      ),
    );
  }
}

/// A level's head: the round badge in its colour, the rung's name and tagline, and what the member holds.
class _LevelHeader extends StatelessWidget {
  const _LevelHeader({required this.entry, required this.look});

  final PaperEntry entry;
  final RungLook look;

  static IconData iconFor(String? level) => switch (level) {
    'INTERMEDIATE' => LucideIcons.star,
    'ADVANCED' => LucideIcons.chartColumn,
    _ => LucideIcons.graduationCap,
  };

  @override
  Widget build(BuildContext context) {
    final paper = entry.paper;
    final name = (paper.levelName ?? paper.title).toUpperCase();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: look.wash, shape: BoxShape.circle),
          child: Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: look.main,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
              ),
              child: Icon(iconFor(paper.level), color: Colors.white, size: 22),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AssessText.rungName.copyWith(color: look.main), maxLines: 2),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.only(bottom: 3),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: look.ink, width: 2)),
                ),
                child: Text(
                  paper.level == null ? 'Assessment' : look.tagline,
                  style: AssessText.tagline.copyWith(color: look.ink),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (entry.certified)
              const StatusPill(label: 'CERTIFIED', tone: PillTone.solidSuccess, icon: LucideIcons.award),
            if (entry.certified && entry.progress.started) const SizedBox(height: 4),
            if (entry.progress.started && !entry.certified)
              StatusPill(label: attemptsLabel(entry.progress.attempts).toUpperCase()),
          ],
        ),
      ],
    );
  }
}

/// A set's head: "SET 01", what the member holds, the set's name and a line about it.
class _SetHeader extends StatelessWidget {
  const _SetHeader({required this.entry, required this.index});

  final PaperEntry entry;
  final int index;

  @override
  Widget build(BuildContext context) {
    final paper = entry.paper;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(setNumber(index), style: AssessText.setLabel),
            const SizedBox(width: 8),
            if (!entry.isOpen) const StatusPill(label: 'Locked', icon: LucideIcons.lock, height: 20),
            const Spacer(),
            if (entry.progress.started)
              StatusPill(
                label: attemptsLabel(entry.progress.attempts),
                tone: PillTone.success,
                icon: LucideIcons.circleCheck,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(paper.title, style: AssessText.setTitle),
        const SizedBox(height: 4),
        Text(
          paper.description ?? 'Practice paper under exam conditions.',
          style: AssessText.setBody,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// The three numbers a candidate decides on.
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.paper});

  final AssessPaper paper;

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(value, style: AssessText.statValue, maxLines: 1),
          const SizedBox(height: 2),
          Text(label, style: AssessText.statLabel, maxLines: 1),
        ],
      ),
    );
    const divider = SizedBox(height: 30, child: VerticalDivider(width: 1, color: AssessColors.panelBorder));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: AssessColors.statStrip, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          stat('${paper.questions}', 'Questions'),
          divider,
          stat(durationLabel(paper.durationMinutes), 'Duration'),
          divider,
          stat('${paper.passPercentage}%', 'To pass'),
        ],
      ),
    );
  }
}

/// How the member did: their best score against the pass mark, and how many attempts they have used.
class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.entry});

  final PaperEntry entry;

  @override
  Widget build(BuildContext context) {
    final progress = entry.progress;
    final paper = entry.paper;
    final score = progress.bestScore != null && progress.maxScore != null && progress.maxScore! > 0
        ? ' (${progress.bestScore}/${progress.maxScore})'
        : '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AssessColors.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Best score ${progress.bestPercent}%$score', style: AssessText.progressTitle)),
              progress.passed
                  ? const StatusPill(label: 'Passed', tone: PillTone.success, icon: LucideIcons.check)
                  : const StatusPill(label: 'Not passed yet', tone: PillTone.warn),
            ],
          ),
          const SizedBox(height: 10),
          ScoreBar(percent: progress.bestPercent, passMark: paper.passPercentage, passed: progress.passed),
          const SizedBox(height: 8),
          Text(
            entry.attemptsUsedUp
                ? 'All ${paper.attemptLimit} attempts used'
                : attemptsUsedLabel(progress.attempts, paper.attemptLimit),
            style: AssessText.progressNote,
          ),
        ],
      ),
    );
  }
}

/// A thin bar filled to the best percentage, with a tick at the pass mark.
class ScoreBar extends StatelessWidget {
  const ScoreBar({super.key, required this.percent, required this.passMark, required this.passed});

  final int percent;
  final int passMark;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final fill = passed ? AppColors.successInk : AppColors.amber500;
    return Semantics(
      label: 'Best score $percent percent, $passMark percent to pass',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth;
            return SizedBox(
              height: 10,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 2,
                    height: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 2,
                    height: 6,
                    width: width * (percent.clamp(0, 100) / 100),
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  Positioned(
                    left: width * (passMark.clamp(0, 100) / 100) - 1,
                    top: 0,
                    height: 10,
                    width: 2,
                    child: const ColoredBox(color: AppColors.slate600),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// What the paper takes to open, as the member stands: nothing (it is theirs), a free place of the plan, or a
/// price and ICR credits.
class _AccessPanel extends StatelessWidget {
  const _AccessPanel({required this.entry, required this.look, required this.canPlan});

  final PaperEntry entry;
  final RungLook look;
  final bool canPlan;

  @override
  Widget build(BuildContext context) {
    switch (entry.access) {
      case PaperAccess.open:
        return _Panel(
          tint: AssessColors.successWash,
          border: look.main.withValues(alpha: 0.35),
          child: Row(
            children: [
              Icon(LucideIcons.circleCheck, size: 22, color: look.main),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Unlocked', style: AssessText.panelTitle.copyWith(color: look.main)),
                    Text(entry.redeemed ? 'Opened with ICR credits' : 'Ready to start', style: AssessText.panelNote),
                  ],
                ),
              ),
            ],
          ),
        );
      case PaperAccess.planPlace:
        return _Panel(
          child: Row(
            children: [
              Icon(LucideIcons.lockOpen, size: 22, color: look.main),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Included in your plan', style: AssessText.panelTitle),
                    Text(
                      entry.paper.kind == PaperKind.mock
                          ? 'Open this mock exam with your plan to start its sets.'
                          : 'Open this course with your plan to start its levels.',
                      style: AssessText.panelNote,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      case PaperAccess.closed:
        final quote = entry.quote;
        if (quote == null) {
          return _Panel(
            child: Row(
              children: [
                const Icon(LucideIcons.lock, size: 22, color: AppColors.slate500),
                const SizedBox(width: 10),
                Expanded(child: Text('Locked. Opens with ICR credits or a purchase.', style: AssessText.panelNote)),
              ],
            ),
          );
        }
        return _PricePanel(quote: quote, look: look);
    }
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.tint, this.border});

  final Widget child;
  final Color? tint;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tint ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border ?? AssessColors.panelBorder),
      ),
      child: child,
    );
  }
}

/// The price after the discount, its list price struck through, what it saves, and the ICR credits that open it.
class _PricePanel extends StatelessWidget {
  const _PricePanel({required this.quote, required this.look});

  final PaperQuote quote;
  final RungLook look;

  @override
  Widget build(BuildContext context) {
    final credits = quote.credits;
    if (!quote.priced) {
      // No price: the credits alone, and what they are worth.
      return _Panel(
        child: Column(
          children: [
            Text(
              credits == null ? 'Locked' : creditsLabel(credits),
              style: AssessText.panelBig.copyWith(color: look.main),
            ),
            if (credits != null)
              Text('Worth ${rupees(quote.creditsWorthRupees! * 100)}', style: AssessText.panelNote)
            else
              Text('Not on sale right now.', style: AssessText.panelNote),
          ],
        ),
      );
    }
    return _Panel(
      border: quote.discounted ? const Color(0x590E8A55) : null,
      child: Column(
        children: [
          if (quote.discounted)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(rupees(quote.listPaisa, quote.currency), style: AssessText.strike),
                const SizedBox(width: 8),
                _OffBadge('${quote.discountBps ~/ 100}% OFF'),
              ],
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(rupees(quote.salePaisa, quote.currency), style: AssessText.panelBig.copyWith(color: look.main)),
              const SizedBox(width: 6),
              Text('+ GST', style: AssessText.panelNote),
            ],
          ),
          if (quote.discounted) Text('You save ${rupees(quote.discountPaisa, quote.currency)}', style: AssessText.save),
          if (quote.memberDiscount && quote.memberPlan != null)
            Text('${quote.memberPlan} member price', style: AssessText.panelNote),
          if (credits != null) ...[
            const SizedBox(height: 2),
            Text('or ${creditsLabel(credits)}', style: AssessText.panelNote),
          ],
        ],
      ),
    );
  }
}

class _OffBadge extends StatelessWidget {
  const _OffBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: AssessColors.ribbon, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: AssessText.coverPill),
    );
  }
}

/// The buttons under a card, by what the paper takes.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.entry,
    required this.look,
    required this.actions,
    required this.heldCredits,
    required this.canPlan,
  });

  final PaperEntry entry;
  final RungLook look;
  final PaperActions actions;
  final int? heldCredits;
  final bool canPlan;

  @override
  Widget build(BuildContext context) {
    final paper = entry.paper;
    final isMock = paper.kind == PaperKind.mock;
    switch (entry.access) {
      case PaperAccess.open:
        if (entry.attemptsUsedUp) {
          return ActionButton(label: 'No attempts left', color: look.main, onPressed: null);
        }
        final again = entry.progress.started;
        return ActionButton(
          label: isMock ? (again ? 'Retake test' : 'Start test') : (again ? 'Retake assessment' : 'Start Assessment'),
          color: look.main,
          icon: again ? LucideIcons.refreshCw : LucideIcons.arrowRight,
          filled: !again,
          onPressed: actions.onStart,
        );
      case PaperAccess.planPlace:
        return ActionButton(
          label: 'Open with my plan',
          color: look.main,
          icon: LucideIcons.lockOpen,
          onPressed: actions.onOpenWithPlan,
        );
      case PaperAccess.closed:
        final quote = entry.quote;
        final credits = entry.credits;
        final held = heldCredits ?? 0;
        final enough = credits != null && held >= credits;
        final priced = entry.priced;
        final children = <Widget>[];
        if (priced) {
          children.add(
            ActionButton(
              label: 'Pay on the website',
              color: look.main,
              icon: LucideIcons.externalLink,
              onPressed: quote!.payable ? actions.onBuy : null,
            ),
          );
          if (!quote.payable) {
            children.add(const SizedBox(height: 6));
            children.add(
              Text(
                'Online payment is not available right now.',
                style: AssessText.buttonNote,
                textAlign: TextAlign.center,
              ),
            );
          }
        }
        if (credits != null) {
          if (children.isNotEmpty) children.add(const SizedBox(height: 8));
          children.add(
            ActionButton(
              label: entry.busy ? 'Redeeming…' : 'Redeem ${creditsLabel(credits)}',
              color: look.main,
              icon: LucideIcons.coins,
              filled: !priced,
              loading: entry.busy,
              onPressed: enough && !entry.busy ? actions.onRedeem : null,
            ),
          );
          children.add(const SizedBox(height: 6));
          children.add(
            Text(
              enough ? 'You have ${creditsShort(held)}' : 'Needs $credits; you have $held',
              style: AssessText.buttonNote.copyWith(color: enough ? AppColors.onSurfaceVariant : AppColors.amber800),
              textAlign: TextAlign.center,
            ),
          );
        }
        if (!priced && credits == null) {
          children.add(
            ActionButton(
              label: 'See plans',
              color: look.main,
              icon: LucideIcons.externalLink,
              filled: false,
              onPressed: canPlan ? actions.onSeePlans : null,
            ),
          );
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }
  }
}

/// A 48 dp button: filled in the card's colour, or outlined in it; a spinner while it works.
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon,
    this.filled = true,
    this.loading = false,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final ink = filled ? Colors.white : color;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: filled ? BorderSide.none : BorderSide(color: enabled ? color : color.withValues(alpha: 0.35)),
    );
    return Opacity(
      opacity: enabled || loading ? 1 : 0.55,
      child: Material(
        color: filled ? color : Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onPressed,
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ink))
                else if (icon != null)
                  Icon(icon, size: 18, color: ink),
                if (loading || icon != null) const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: (filled ? AssessText.button : AssessText.buttonOutline).copyWith(color: ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

/// A rung with no paper published yet: the card stays on the page, greyed.
class ComingSoonLevelCard extends StatelessWidget {
  const ComingSoonLevelCard({super.key, required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final look = AssessColors.rung(level);
    return Opacity(
      opacity: 0.6,
      child: Container(
        key: ValueKey('coming-soon-$level'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AssessColors.panelBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: look.wash, shape: BoxShape.circle),
                  child: Icon(_LevelHeader.iconFor(level), color: look.main, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    (assessLevelLabel(level) ?? level).toUpperCase(),
                    style: AssessText.rungName.copyWith(color: look.main),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const ActionButton(label: 'Coming soon', color: AppColors.slate400, onPressed: null),
          ],
        ),
      ),
    );
  }
}
