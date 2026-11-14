import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../assess_format.dart';
import '../assess_models.dart';
import '../assess_styles.dart';
import '../group_controller.dart';
import 'paper_actions.dart';
import 'status_pill.dart';

export 'action_button.dart';
export 'paper_actions.dart';

/// One assessment level or one mock set, as a row of the programme's or the exam's list (owner, 3 Nov 2026: "the
/// standard production design of high-level apps", every block in one view, no borders — a thin line between rows
/// is enough; the page draws those).
///
/// A tinted glyph (a level's) or number (a set's), the name with where it stands (Open, Locked, Passed…), one line
/// of what it is (questions, time, pass mark), how the member did once they have sat it, and one strip of what to
/// do next: **Start** while it is open, **Open with my plan** while a plan place is free, or — closed — the price
/// and the ICR credits beside **Pay now** and **Redeem**. Keyed `paper-<id>`.
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

  bool get _isMock => entry.paper.kind == PaperKind.mock;

  /// The row's colour: a level's own (Foundation blue, Advanced green, Professional navy), a set's blue.
  Color get _color => _isMock ? AssessColors.setAction : AssessColors.levelCard(entry.paper.level).accent;

  @override
  Widget build(BuildContext context) {
    final paper = entry.paper;
    final title = _isMock ? paper.title : (paper.levelName ?? paper.title);
    final progress = _progressLine();
    final description = paper.description?.trim();
    return Padding(
      key: ValueKey('paper-${paper.id}'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Leading(isMock: _isMock, index: index, level: paper.level, color: _color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            key: ValueKey('level-name-${paper.id}'),
                            style: AssessText.panelTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _status(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(_metaLine(), style: AssessText.sectionHint, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (_isMock && description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(description, style: AssessText.sectionHint, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    if (progress != null) ...[
                      const SizedBox(height: 4),
                      Text(progress, key: ValueKey('progress-${paper.id}'), style: AssessText.progressNote),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _actionStrip(),
        ],
      ),
    );
  }

  /// "Build your basics · 50 questions · 50 min · 70% to pass", and "Up to 3 attempts" before a first sitting.
  String _metaLine() {
    final paper = entry.paper;
    final parts = <String>[
      if (!_isMock && paper.level != null) _sentenceCase(AssessColors.rung(paper.level).tagline),
      if (paper.questions > 0) plural(paper.questions, 'question'),
      if (paper.durationMinutes > 0) durationLabel(paper.durationMinutes),
      if (paper.passPercentage > 0) '${paper.passPercentage}% to pass',
      if (!entry.progress.started && paper.attemptLimit != null) 'Up to ${paper.attemptLimit} attempts',
    ];
    if (parts.isNotEmpty) return parts.join(' · ');
    return _isMock ? 'Practice paper under exam conditions.' : 'Assessment';
  }

  /// How the member did, on one line: "Best score 62% (31/50) · Not passed yet · 1 of 3 attempts used". Null before
  /// a sitting.
  String? _progressLine() {
    final progress = entry.progress;
    if (!progress.started) return null;
    final paper = entry.paper;
    final score = progress.bestScore != null && progress.maxScore != null && progress.maxScore! > 0
        ? ' (${progress.bestScore}/${progress.maxScore})'
        : '';
    return [
      'Best score ${progress.bestPercent}%$score',
      progress.passed ? (entry.certified ? 'Passed · Certified' : 'Passed') : 'Not passed yet',
      entry.attemptsUsedUp
          ? 'All ${paper.attemptLimit} attempts used'
          : attemptsUsedLabel(progress.attempts, paper.attemptLimit),
    ].join(' · ');
  }

  static String _sentenceCase(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  Widget _status() => switch (entry.access) {
    PaperAccess.open when entry.progress.passed => const StatusPill(label: 'Passed', tone: PillTone.success),
    PaperAccess.open => const StatusPill(label: 'Open', tone: PillTone.success, icon: LucideIcons.lockOpen),
    PaperAccess.planPlace => const StatusPill(label: 'In Your Plan', tone: PillTone.info),
    PaperAccess.closed => const StatusPill(label: 'Locked', icon: LucideIcons.lock),
  };

  /// What to do next, in one strip under the row: a button, or the price beside the ways to pay it. Once the
  /// member holds the paper's certificate, **Certificate** leads the strip (it opens the certificate in the app, with
  /// its PDF) and the retake beside it shortens to **Retake**.
  Widget _actionStrip() {
    final paper = entry.paper;
    final share = actions.onShare == null ? null : _ShareGlyph(onTap: actions.onShare!, label: 'Share ${paper.title}');
    Widget withShare(Widget child) => share == null
        ? child
        : Row(
            children: [
              Expanded(child: child),
              const SizedBox(width: 4),
              share,
            ],
          );
    final certificate = entry.certificate == null || actions.onViewCertificate == null
        ? null
        : RowButton(
            key: ValueKey('certificate-${paper.id}'),
            label: 'Certificate',
            color: _color,
            icon: LucideIcons.award,
            onPressed: actions.onViewCertificate,
          );

    switch (entry.access) {
      case PaperAccess.open:
        final again = entry.progress.started;
        final next = entry.attemptsUsedUp
            ? RowButton(label: 'No Attempts Left', color: _color, onPressed: null)
            : RowButton(
                label: certificate != null
                    ? 'Retake'
                    : _isMock
                    ? (again ? 'Retake Test' : 'Start Test')
                    : (again ? 'Retake Assessment' : 'Start Assessment'),
                color: _color,
                tonal: again,
                icon: again ? LucideIcons.refreshCw : null,
                trailingIcon: again ? null : LucideIcons.arrowRight,
                onPressed: actions.onStart,
              );
        if (certificate == null) return withShare(next);
        return withShare(
          Row(
            children: [
              Expanded(child: certificate),
              const SizedBox(width: 8),
              Expanded(child: next),
            ],
          ),
        );
      case PaperAccess.planPlace:
        return _withCertificate(
          certificate,
          withShare(
            RowButton(
              label: 'Open with My Plan',
              color: _color,
              icon: LucideIcons.lockOpen,
              onPressed: actions.onOpenWithPlan,
            ),
          ),
        );
      case PaperAccess.closed:
        return _withCertificate(certificate, _closedStrip(share));
    }
  }

  /// A certificate earned on a paper that has since closed (a plan place that lapsed) stays the member's: its button
  /// sits above the ways to open the paper again.
  static Widget _withCertificate(Widget? certificate, Widget strip) => certificate == null
      ? strip
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [certificate, const SizedBox(height: 8), strip],
        );

  /// A closed paper: what opening it costs on the left, the buttons on the right — under it, side by side, on a
  /// phone too narrow for both on one line.
  Widget _closedStrip(Widget? share) {
    final quote = entry.quote;
    final credits = entry.credits;
    final held = heldCredits ?? 0;
    final enough = credits != null && held >= credits;
    final priced = entry.priced;
    final buttons = <Widget>[
      if (priced) RowButton(label: 'Pay Now', color: _color, onPressed: quote!.payable ? actions.onBuy : null),
      if (credits != null)
        RowButton(
          label: entry.busy ? 'Redeeming…' : (priced ? 'Redeem' : 'Redeem ${creditsLabelTitle(credits)}'),
          color: _color,
          tonal: priced,
          loading: entry.busy,
          onPressed: enough && !entry.busy ? actions.onRedeem : null,
        ),
      if (!priced && credits == null && canPlan)
        RowButton(label: 'See Plans', color: _color, tonal: true, onPressed: actions.onSeePlans),
    ];
    final price = PriceLine(quote: quote, color: _color);
    final unpayable = priced && !quote!.payable
        ? Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Online payment is not available right now.', style: AssessText.progressNote),
          )
        : null;
    return LayoutBuilder(
      builder: (context, box) {
        final trailing = [...buttons, ?share];
        // A price and two buttons need about 320 dp; under that the buttons go under the price, side by side.
        if (box.maxWidth >= 320 || buttons.length < 2) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: price),
                  if (trailing.isNotEmpty) const SizedBox(width: 8),
                  ..._spaced(trailing),
                ],
              ),
              ?unpayable,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            price,
            const SizedBox(height: 8),
            Row(children: _spaced([for (final b in buttons) Expanded(child: b), ?share])),
            ?unpayable,
          ],
        );
      },
    );
  }

  static List<Widget> _spaced(List<Widget> items) => [
    for (final (i, w) in items.indexed) ...[if (i > 0) const SizedBox(width: 8), w],
  ];
}

/// The row's mark: a level's glyph on its tint, or a set's number ("01").
class _Leading extends StatelessWidget {
  const _Leading({required this.isMock, required this.index, required this.level, required this.color});

  final bool isMock;
  final int index;
  final String? level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isMock ? AssessColors.setTag : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: isMock
            ? Text(
                (index + 1).toString().padLeft(2, '0'),
                style: AssessText.cardTitle.copyWith(color: AssessColors.setTagInk),
              )
            : Icon(AssessColors.levelCard(level).icon, size: 22, color: color, fill: 1),
      ),
    );
  }
}

/// What a closed paper costs, on two short lines: the price + GST (its list price struck through when discounted),
/// then the ICR credits that open it instead — or the credits alone and what they are worth; or, while the quote
/// has not arrived, that it is locked.
class PriceLine extends StatelessWidget {
  const PriceLine({super.key, required this.quote, required this.color});

  final PaperQuote? quote;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final quote = this.quote;
    if (quote == null) return Text('Opens with ICR credits or a purchase.', style: AssessText.progressNote);
    final credits = quote.credits;
    final big = AssessText.priceBig.copyWith(color: color);
    if (!quote.priced) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (credits == null)
            Text('Not on sale right now.', style: AssessText.progressTitle)
          else ...[
            Text(creditsLabel(credits), style: big),
            Text('Worth ${rupees(quote.creditsWorthRupees! * 100)}', style: AssessText.progressNote),
          ],
        ],
      );
    }
    final second = <InlineSpan>[
      if (quote.discounted) ...[
        TextSpan(text: rupees(quote.listPaisa, quote.currency), style: AssessText.strikeSmall),
        TextSpan(text: '  ${quote.discountBps ~/ 100}% off  ', style: AssessText.saveSmall),
      ],
      if (quote.memberDiscount && quote.memberPlan != null) TextSpan(text: '${quote.memberPlan} member price  '),
      if (credits != null) TextSpan(text: 'or ${creditsLabel(credits)}'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: rupees(quote.salePaisa, quote.currency), style: big),
              TextSpan(text: ' + GST', style: AssessText.progressNote),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (second.isNotEmpty) Text.rich(TextSpan(style: AssessText.progressNote, children: second), maxLines: 2),
      ],
    );
  }
}

/// A list row's button, at least 40 dp tall: filled in the row's colour, or tonal (its colour on a pale wash) for
/// the second way — never outlined (owner, 3 Nov 2026: no borders).
class RowButton extends StatelessWidget {
  const RowButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.tonal = false,
    this.loading = false,
    this.icon,
    this.trailingIcon,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool tonal;
  final bool loading;
  final IconData? icon;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final ink = tonal ? color : Colors.white;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    final lead = loading
        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ink))
        : icon == null
        ? null
        : Icon(icon, size: 16, color: ink);
    return Opacity(
      opacity: enabled || loading ? 1 : 0.45,
      child: Material(
        color: tonal ? color.withValues(alpha: 0.10) : color,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (lead != null) ...[lead, const SizedBox(width: 6)],
                  Flexible(
                    child: Text(
                      label,
                      style: AssessText.button.copyWith(color: ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (trailingIcon != null) ...[const SizedBox(width: 6), Icon(trailingIcon, size: 16, color: ink)],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The share glyph at the end of a set's strip: 40 dp, no frame.
class _ShareGlyph extends StatelessWidget {
  const _ShareGlyph({required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Symbols.share, size: 22, color: AppColors.onSurfaceVariant),
        ),
      ),
    );
  }
}
