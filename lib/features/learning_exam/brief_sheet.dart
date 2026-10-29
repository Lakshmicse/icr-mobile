import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/detail_sheet.dart';
import 'brief_controller.dart';
import 'certificate_view.dart';
import 'exam_format.dart';
import 'exam_models.dart';
import 'exam_services.dart';
import 'exam_styles.dart';
import 'exam_widgets.dart';

/// Opens the brief of a paper over the screen that asked: what it is, what it
/// takes to open, the member's record on it, and the button that starts it.
/// Completes with the sitting to open the exam on, or null when the sheet was closed.
Future<ExamStart?> showBriefSheet(BuildContext context, BriefController controller) {
  controller.load();
  return showDetailSheet<ExamStart>(
    context,
    topInset: 48,
    body: (_) => ChangeNotifierProvider.value(value: controller, child: const BriefBody()),
    bottomBar: (_) => ChangeNotifierProvider.value(value: controller, child: const BriefBar()),
  );
}

/// The scrolling part of the brief.
class BriefBody extends StatelessWidget {
  const BriefBody({super.key});

  @override
  Widget build(BuildContext context) {
    final brief = context.watch<BriefController>();
    switch (brief.status) {
      case BriefStatus.loading:
        return const ExamSpinner();
      case BriefStatus.failed:
        return SingleChildScrollView(
          child: ScreenNotice(
            icon: LucideIcons.fileQuestion,
            title: "Couldn't open this paper",
            body: brief.error ?? 'Something went wrong. Try again.',
            action: 'Try again',
            onAction: brief.load,
          ),
        );
      case BriefStatus.ready:
      case BriefStatus.locked:
        return _Content(brief: brief);
    }
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.brief});

  final BriefController brief;

  @override
  Widget build(BuildContext context) {
    final paper = brief.paper!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _Hero(
          paper: paper,
          unlocked: brief.status == BriefStatus.ready && (paper.priceAmount != null || paper.creditCost != null),
        ),
        const SizedBox(height: 20),
        if (brief.status == BriefStatus.locked) ...[_AccessPanel(brief: brief), const SizedBox(height: 20)],
        _Standing(brief: brief),
        _Parameters(paper: paper, used: brief.attemptsUsed),
        const SizedBox(height: 20),
        Text('Before you start', style: ExamText.heading),
        const SizedBox(height: 10),
        if (paper.instructions != null)
          ExamCard(child: Text(paper.instructions!, style: ExamText.body))
        else
          const _Features(),
      ],
    );
  }
}

/// The cover, the name, and what passing earns.
class _Hero extends StatelessWidget {
  const _Hero({required this.paper, this.unlocked = false});

  final PaperInfo paper;

  /// A priced paper the member holds (bought, redeemed with credits, or opened with the plan).
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    // A level paper is named for its rung alone ("Foundation"); the brief confirms the subject back
    // and puts the rung in the eyebrow. A mock set is named for itself ("AEE CBCP – Set 1").
    final level = paper.levelLabel;
    final heading = paper.kind == PaperKind.assessment && paper.courseTitle != null ? paper.courseTitle! : paper.name;
    final eyebrow = level != null ? '$level level'.toUpperCase() : (paper.subtitle ?? 'Mock exam').toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Cover(url: paper.imageUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(eyebrow, style: ExamText.eyebrow),
                  const SizedBox(height: 4),
                  Semantics(header: true, child: Text(heading, style: ExamText.heroTitle)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            InfoPill(
              icon: paper.isMock ? LucideIcons.clipboardCheck : LucideIcons.award,
              label: paper.isMock ? 'Mock exam' : 'Assessment',
            ),
            if (unlocked)
              const InfoPill(icon: LucideIcons.lockOpen, label: 'Unlocked for you', color: AppColors.tertiary),
            if (paper.certificateEnabled)
              const InfoPill(
                icon: LucideIcons.badgeCheck,
                label: 'Certificate on a qualifying pass',
                color: AppColors.tertiary,
              ),
          ],
        ),
        if (paper.description != null) ...[const SizedBox(height: 12), Text(paper.description!, style: ExamText.body)],
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final plate = Container(
      color: AppColors.chipEmphasis,
      alignment: Alignment.center,
      child: const Icon(LucideIcons.fileQuestion, size: 28, color: AppColors.primary),
    );
    final src = AppConfig.absoluteUrl(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 64,
        height: 64,
        child: src == null
            ? plate
            : CachedNetworkImage(
                imageUrl: src,
                fit: BoxFit.cover,
                placeholder: (_, _) => plate,
                errorWidget: (_, _, _) => plate,
              ),
      ),
    );
  }
}

/// Questions and minutes in tiles, and the rest as rows.
class _Parameters extends StatelessWidget {
  const _Parameters({required this.paper, required this.used});

  final PaperInfo paper;
  final int used;

  @override
  Widget build(BuildContext context) {
    final limit = paper.attemptLimit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.chartNoAxesColumn, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Test parameters', style: ExamText.heading),
          ],
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatTile(value: '${paper.questionCount}', label: 'Questions', icon: LucideIcons.fileQuestion),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  value: '${paper.durationMinutes}',
                  unit: 'min',
                  label: 'Duration',
                  icon: LucideIcons.timer,
                  color: AppColors.amber500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        _ParamRow(icon: LucideIcons.trophy, label: 'Total marks', value: '${paper.totalMarks}'),
        const _Rule(),
        _ParamRow(icon: LucideIcons.flag, label: 'Passing criterion', chip: '${paper.passPercentage}%'),
        const _Rule(),
        _ParamRow(
          icon: LucideIcons.rotateCcw,
          label: 'Attempts allowed',
          value: limit == null ? 'Unlimited' : '$limit${used > 0 ? ' · $used used' : ''}',
        ),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => const Divider(height: 1, thickness: 1, color: AppColors.slate100);
}

class _ParamRow extends StatelessWidget {
  const _ParamRow({required this.icon, required this.label, this.value, this.chip});

  final IconData icon;
  final String label;
  final String? value;
  final String? chip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.slate500),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: ExamText.body.copyWith(color: AppColors.onSurface)),
          ),
          if (chip != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(chip!, style: AppText.workSans(13, FontWeight.w800, AppColors.primary)),
            )
          else
            Text(value ?? '', style: ExamText.bodyStrong),
        ],
      ),
    );
  }
}

/// The default "before you start", when the paper carries no instructions of its own.
class _Features extends StatelessWidget {
  const _Features();

  static const _items = [
    (
      LucideIcons.timer,
      'Timed',
      'The clock starts when you tap Start and keeps running if you leave. At zero your answers are submitted for you.',
    ),
    (
      LucideIcons.save,
      'Saved as you go',
      'Your answers are kept on this phone, so you can pick up where you left off until time runs out.',
    ),
    (
      LucideIcons.listChecks,
      'Move freely',
      'Jump to any question from the palette, flag the ones to revisit, and change an answer until you submit.',
    ),
    (
      LucideIcons.send,
      'Scored when you submit',
      'Your score, the right answers and the explanations appear straight after you submit.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, item) in _items.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          ExamCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: AppColors.chipEmphasis, borderRadius: BorderRadius.circular(10)),
                  child: Icon(item.$1, size: 19, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.$2, style: ExamText.subheading),
                      const SizedBox(height: 3),
                      Text(item.$3, style: ExamText.body),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// What the member already has with this paper: a certificate, a best score,
/// the attempts used, a sitting left half done.
class _Standing extends StatelessWidget {
  const _Standing({required this.brief});

  final BriefController brief;

  @override
  Widget build(BuildContext context) {
    final cert = brief.certificate;
    final best = brief.best;
    final paper = brief.paper!;
    final notices = <Widget>[
      if (brief.status == BriefStatus.ready && brief.saved != null)
        Notice(
          tone: brief.savedExpired ? NoticeTone.warning : NoticeTone.info,
          text: brief.savedExpired
              ? 'Time ran out on your last sitting while you were away. Your saved answers will be submitted as they are.'
              : 'You have a sitting in progress, with ${clockLabel(brief.savedLeft)} left. Resume it to pick up where you stopped.',
          action: 'Discard it and start over',
          onAction: () => _confirmDiscard(context, brief),
        ),
      if (cert != null)
        Notice(
          tone: NoticeTone.success,
          text: 'You already hold this certificate: ${cert.certificateId}.',
          action: 'View certificate',
          onAction: () => showCertificateSheet(context, cert),
        ),
      if (best != null) Notice(text: 'Your best so far is $best% over ${plural(brief.attemptsUsed, 'attempt')}.'),
      if (brief.exhausted && brief.saved == null)
        Notice(tone: NoticeTone.warning, text: 'You have used all ${paper.attemptLimit} attempts for this paper.'),
      if (brief.noQuestions)
        const Notice(tone: NoticeTone.warning, text: 'This paper has no questions yet. Check back soon.'),
    ];
    if (notices.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final (i, n) in notices.indexed) ...[if (i > 0) const SizedBox(height: 10), n],
        const SizedBox(height: 20),
      ],
    );
  }
}

Future<void> _confirmDiscard(BuildContext context, BriefController brief) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text('Start over?', style: ExamText.heading),
      content: Text('Your answers so far will be discarded and the clock will start again.', style: ExamText.body),
      actions: [
        TextButton(
          onPressed: () => popOnce(ctx, false),
          child: Text('Keep it', style: ExamText.link),
        ),
        TextButton(
          onPressed: () => popOnce(ctx, true),
          child: Text('Discard', style: ExamText.link.copyWith(color: AppColors.error)),
        ),
      ],
    ),
  );
  if (yes == true) await brief.discardSaved();
}

// --- when the paper is closed to the member ------------------------------------------------------

class _AccessPanel extends StatelessWidget {
  const _AccessPanel({required this.brief});

  final BriefController brief;

  @override
  Widget build(BuildContext context) {
    final lock = brief.lock!;
    final paper = brief.paper!;
    final quote = brief.quote;
    final mock = paper.isMock;
    final redeemable = quote != null && quote.credits != null && !quote.alreadyOpen;
    final buyable = quote != null && quote.priced && !quote.alreadyOpen;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.lock, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mock ? 'This mock set is locked' : 'This assessment level is locked', style: ExamText.heading),
                    const SizedBox(height: 4),
                    Text(lock.message, style: ExamText.body),
                  ],
                ),
              ),
            ],
          ),
          if (lock.planCanOpen) ...[
            const SizedBox(height: 14),
            _Option(
              title: mock ? 'Your plan includes a mock exam' : 'Your plan includes a course',
              body:
                  'Opening it with your plan uses ${lock.placesLeft == 1 ? 'your last place' : 'one of your free places'} and costs nothing.',
              child: ExamButton(
                label: 'Open with my plan',
                icon: LucideIcons.lockOpen,
                busy: brief.working,
                onPressed: () => _confirmOpenWithPlan(context, brief, mock: mock),
              ),
            ),
          ],
          if (redeemable) ...[
            const SizedBox(height: 14),
            _Option(
              title: 'Redeem ICR credits',
              body:
                  'It takes ${plural(quote.credits!, 'ICR credit')} (worth ${rupees(quote.credits! * quote.rupeesPerCredit * 100)}) and opens it for good. You have ${lock.credits}.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ExamButton(
                    label: 'Redeem ${plural(quote.credits!, 'credit')}',
                    icon: LucideIcons.coins,
                    busy: brief.working,
                    onPressed: lock.credits >= quote.credits!
                        ? () => _confirmRedeem(context, brief, quote, lock)
                        : null,
                  ),
                  if (lock.credits < quote.credits!) ...[
                    const SizedBox(height: 6),
                    Text(
                      'You need ${quote.credits! - lock.credits} more. Inviting colleagues to ICR earns credits.',
                      style: ExamText.small.copyWith(color: AppColors.amber800),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (buyable) ...[const SizedBox(height: 14), _BuyOption(brief: brief, quote: quote)],
          if (brief.actionError != null) ...[
            const SizedBox(height: 14),
            Notice(tone: NoticeTone.error, text: brief.actionError!),
          ],
          if (lock.plan != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ExamServices.openUrl(context, brief.repository.sitePage('/pricing/${lock.pricingSlug}')),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text('See the ${lock.plan} plan', style: ExamText.link),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.title, required this.body, required this.child});

  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ExamColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ExamText.subheading),
          const SizedBox(height: 4),
          Text(body, style: ExamText.body),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _BuyOption extends StatelessWidget {
  const _BuyOption({required this.brief, required this.quote});

  final BriefController brief;
  final PaperQuote quote;

  @override
  Widget build(BuildContext context) {
    final paper = brief.paper!;
    return _Option(
      title: paper.isMock ? 'Buy this set' : 'Buy this level',
      body: quote.taxPaisa > 0
          ? 'GST (${percentOfBps(quote.taxBps)}) ${rupees(quote.taxPaisa)}, total ${rupees(quote.totalPaisa)}.'
          : 'Total ${rupees(quote.totalPaisa)}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (quote.discountPaisa > 0) ...[
                Text(
                  rupees(quote.listPaisa),
                  style: AppText.plexSans(
                    14,
                    FontWeight.w500,
                    AppColors.slate400,
                  ).copyWith(decoration: TextDecoration.lineThrough),
                ),
                const SizedBox(width: 8),
              ],
              Text(rupees(quote.salePaisa), style: AppText.workSans(22, FontWeight.w800, AppColors.onSurface)),
              if (quote.discountPaisa > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '${percentOfBps(quote.discountBps)} off',
                  style: AppText.plexSans(12, FontWeight.w700, AppColors.successInk),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          ExamButton(
            label: quote.payable ? 'Pay on the website' : 'Payment is not available',
            icon: LucideIcons.externalLink,
            onPressed: quote.payable
                ? () => ExamServices.openExternal(context, brief.repository.sitePage(paper.sitePath))
                : null,
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmOpenWithPlan(BuildContext context, BriefController brief, {required bool mock}) async {
  final lock = brief.lock!;
  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text('Open it with your plan?', style: ExamText.heading),
      content: Text(
        mock
            ? 'This opens every set of this mock exam and takes one of your plan\'s places${lock.placesLeft == null ? '' : ' (${lock.placesLeft} left)'}.'
            : 'This opens every level of this course and takes one of your plan\'s places${lock.placesLeft == null ? '' : ' (${lock.placesLeft} left)'}.',
        style: ExamText.body,
      ),
      actions: [
        TextButton(
          onPressed: () => popOnce(ctx, false),
          child: Text('Cancel', style: ExamText.link),
        ),
        TextButton(
          onPressed: () => popOnce(ctx, true),
          child: Text('Open it', style: ExamText.link),
        ),
      ],
    ),
  );
  if (yes == true) await brief.openWithPlan();
}

Future<void> _confirmRedeem(BuildContext context, BriefController brief, PaperQuote quote, PaperLock lock) async {
  final paper = brief.paper!;
  final credits = quote.credits!;
  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text('Redeem ${plural(credits, 'credit')}?', style: ExamText.heading),
      content: Text(
        'This opens ${paper.name} for good. You will have ${lock.credits - credits} ICR credits left.',
        style: ExamText.body,
      ),
      actions: [
        TextButton(
          onPressed: () => popOnce(ctx, false),
          child: Text('Cancel', style: ExamText.link),
        ),
        TextButton(
          onPressed: () => popOnce(ctx, true),
          child: Text('Redeem', style: ExamText.link),
        ),
      ],
    ),
  );
  if (yes == true) await brief.redeem();
}

/// The button under the brief: start, retake, pick the sitting up, or send what a
/// lapsed sitting held.
class BriefBar extends StatelessWidget {
  const BriefBar({super.key});

  @override
  Widget build(BuildContext context) {
    final brief = context.watch<BriefController>();
    if (brief.status == BriefStatus.loading || brief.status == BriefStatus.failed) return const SizedBox.shrink();
    if (brief.status == BriefStatus.locked) {
      return BottomActionBar(
        children: [
          Expanded(
            child: ExamButton(label: 'Back', quiet: true, onPressed: () => popOnce(context)),
          ),
        ],
      );
    }
    final String label;
    final IconData icon;
    final ExamStart? Function() make;
    if (brief.saved != null && brief.savedExpired) {
      label = 'Submit my saved answers';
      icon = LucideIcons.send;
      make = brief.resume;
    } else if (brief.saved != null) {
      label = 'Resume · ${clockLabel(brief.savedLeft)} left';
      icon = LucideIcons.play;
      make = brief.resume;
    } else {
      label = brief.attemptsUsed > 0 ? 'Retake test' : 'Take test';
      icon = brief.attemptsUsed > 0 ? LucideIcons.rotateCcw : LucideIcons.play;
      make = brief.begin;
    }
    return BottomActionBar(
      children: [
        Expanded(
          child: ExamButton(
            label: label,
            icon: icon,
            onPressed: brief.canStart
                ? () {
                    final start = make();
                    if (start != null) popOnce(context, start);
                  }
                : null,
          ),
        ),
      ],
    );
  }
}
