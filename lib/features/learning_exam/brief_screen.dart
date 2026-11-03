import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import '../payments/checkout_start.dart';
import 'attempt_result_loader.dart';
import 'brief_controller.dart';
import 'certificate_view.dart';
import 'exam_format.dart';
import 'exam_models.dart';
import 'exam_services.dart';
import 'exam_styles.dart';
import 'exam_widgets.dart';

/// Opens the brief of a paper as a page over the screen that asked: what it is, what it takes to open, what the
/// member has done with it, and the button that starts it. Completes with the sitting to open the exam on, or
/// null when the page was closed.
Future<ExamStart?> showBriefPage(BuildContext context, BriefController controller) {
  controller.load();
  return Navigator.of(context).push<ExamStart>(
    MaterialPageRoute<ExamStart>(
      builder: (_) => ChangeNotifierProvider.value(value: controller, child: const BriefScreen()),
    ),
  );
}

/// The brief, drawn as the owner's design (30 Oct 2026): the paper's name and set; "Before you start"; the
/// paper's details as a two-column table; "My attempts"; and Take test with Back under it. On a paper the member
/// cannot open yet, the ways to open it come first, and the button in Take test's place is the way in.
///
/// The title bar stays pinned over the scrolling sections (owner, 3 Nov 2026: with none, the page scrolled up to
/// the status bar and nothing said where you were), and the sections are parted by hairlines, never boxed (the
/// owner's rule of the same day: "no border is required, a thin line break is enough").
class BriefScreen extends StatelessWidget {
  const BriefScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brief = context.watch<BriefController>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ExamTitleBar(
              title: (brief.paper?.isMock ?? brief.ref.isMock) ? 'Mock Exam' : 'Assess Your Knowledge',
              onBack: () => popOnce(context),
            ),
            Expanded(child: _Body(brief: brief)),
            _Bar(brief: brief),
          ],
        ),
      ),
    );
  }
}

/// The thin line between two sections, or two rows of one.
class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => const Divider(height: 1, thickness: 1, color: ExamColors.line);
}

class _Body extends StatelessWidget {
  const _Body({required this.brief});

  final BriefController brief;

  @override
  Widget build(BuildContext context) {
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
    final notices = _notices(context, brief);
    final attempts = brief.attempts;
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11),
          child: Semantics(
            header: true,
            child: Text(paper.heading, maxLines: 2, overflow: TextOverflow.ellipsis, style: ExamText.briefTitle),
          ),
        ),
        const SizedBox(height: 7),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Column(
            children: [
              for (final n in notices) ...[n, const SizedBox(height: 8)],
              if (brief.status == BriefStatus.locked) ...[_Access(brief: brief), const _Rule()],
              _Before(paper: paper),
              const _Rule(),
              _Details(brief: brief, paper: paper),
            ],
          ),
        ),
        if (attempts.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.symmetric(horizontal: 9), child: _Rule()),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(header: true, child: Text('My attempts', style: ExamText.briefHeading)),
                ),
                Text(
                  '${attempts.length} ${attempts.length == 1 ? 'attempt' : 'attempts'} recorded',
                  style: ExamText.attemptsCount,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: _Attempts(
              brief: brief,
              attempts: attempts,
              limit: Duration(minutes: paper.durationMinutes),
            ),
          ),
        ],
      ],
    );
  }
}

/// One of the brief's sections: open on the white page, no edge or shadow; a [_Rule] parts it from the next.
class _Card extends StatelessWidget {
  const _Card({required this.padding, required this.child});

  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(padding: padding, child: child),
    );
  }
}

// --- the design's sections ---------------------------------------------------------------------------------

/// "Before you start": five lines, each with a small clock badge; the paper's own instructions take their place
/// when it has some.
class _Before extends StatelessWidget {
  const _Before({required this.paper});

  final PaperInfo paper;

  /// The last line says how many attempts there are and whether the paper certifies.
  String get _attempts {
    final limit = paper.attemptLimit;
    final tries = limit == null ? 'Attempts are unlimited.' : 'This paper allows ${plural(limit, 'attempt')}.';
    final cert = paper.certificateEnabled
        ? 'A pass of ${paper.passPercentage}% or more earns a certificate.'
        : 'This paper is practice only; no certificate is issued.';
    return '$tries $cert';
  }

  @override
  Widget build(BuildContext context) {
    final lines = paper.instructions != null
        ? [paper.instructions!]
        : [
            'The timer starts as soon as you begin and keeps running if you leave the page.',
            'Your answers are saved automatically — you can resume an interrupted attempt.',
            'You can move freely between questions and mark any for review.',
            'The paper submits itself when time runs out. Unanswered questions count as wrong.',
            _attempts,
          ];
    return _Card(
      padding: const EdgeInsets.fromLTRB(9, 12, 9, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text('Before you start', style: ExamText.briefHeading)),
          const SizedBox(height: 12),
          for (final (i, line) in lines.indexed) ...[if (i > 0) const SizedBox(height: 8), _Line(text: line)],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: ExamColors.greyTint, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Symbols.timer, size: 20, fill: 1, color: ExamColors.action),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: ExamText.briefLine)),
        ],
      ),
    );
  }
}

/// "Mock Exam details" or "Assessment details": what the paper is, in two columns.
class _Details extends StatelessWidget {
  const _Details({required this.brief, required this.paper});

  final BriefController brief;
  final PaperInfo paper;

  String get _certificate {
    if (brief.certificate != null) return 'Issued';
    return paper.certificateEnabled ? 'On a qualifying pass' : 'Not issued';
  }

  @override
  Widget build(BuildContext context) {
    final limit = paper.attemptLimit;
    final rows = [
      ('Number of questions', '${paper.questionCount}'),
      ('Total marks', '${paper.totalMarks}'),
      ('Duration', plural(paper.durationMinutes, 'minute')),
      ('Passing percentage', '${paper.passPercentage}%'),
      ('Attempts allowed', limit == null ? 'Unlimited' : '$limit'),
      ('Attempts used', '${brief.attemptsUsed}'),
      ('Certificate', _certificate),
    ];
    return _Card(
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(paper.isMock ? 'Mock Exam details' : 'Assessment details', style: ExamText.briefHeading),
          ),
          const SizedBox(height: 8),
          for (final (label, value) in rows)
            SizedBox(
              height: 42,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: Row(
                  children: [
                    Expanded(flex: 11, child: Text(label, style: ExamText.detailLabel)),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 9,
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(value, maxLines: 1, style: ExamText.detailValue),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "My attempts": a row per sitting (its number, when, a document that opens its result) over its Score, Result
/// and Duration.
class _Attempts extends StatelessWidget {
  const _Attempts({required this.brief, required this.attempts, required this.limit});

  final BriefController brief;
  final List<Attempt> attempts;

  /// The paper's time: no sitting's answers ran longer, whatever the record says (see [takenLabel]).
  final Duration limit;

  /// A sitting's result, opened over the brief. Retaking from it closes it and starts the paper.
  void _open(BuildContext context, Attempt a) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AttemptResultLoader(
            attempt: a,
            repository: brief.repository,
            onRetake: () {
              if (!context.mounted) return;
              final start = _start(brief);
              if (start != null) popOnce(context, start);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.fromLTRB(9, 0, 9, 9),
      child: Column(
        children: [
          for (final (i, a) in attempts.indexed) ...[
            if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: _Rule()),
            _AttemptBlock(attempt: a, limit: limit, onOpen: () => _open(context, a)),
          ],
        ],
      ),
    );
  }
}

class _AttemptBlock extends StatelessWidget {
  const _AttemptBlock({required this.attempt, required this.limit, required this.onOpen});

  final Attempt attempt;
  final Duration limit;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final a = attempt;
    final tone = a.passed ? ExamColors.right : ExamColors.wrong;
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: Row(
            children: [
              SizedBox(width: 34, child: Text('#${a.attempt}', style: ExamText.attemptNumber)),
              Expanded(
                child: Text(
                  dateTimeLabel(a.submittedAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ExamText.attemptDate,
                ),
              ),
              Semantics(
                button: true,
                label: 'Open attempt ${a.attempt}',
                excludeSemantics: true,
                child: InkResponse(
                  onTap: onOpen,
                  radius: 24,
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Icon(LucideIcons.fileText, size: 18, color: ExamColors.action),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            _Figure(label: 'Score', value: '${a.score} / ${a.maxScore}'),
            _Figure(label: 'Result', value: '${a.percentage}%', color: tone),
            _Figure(
              label: 'Duration',
              value: takenLabel(a.timeTaken, limit: limit),
            ),
          ],
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
        children: [
          Text(label, style: ExamText.figureLabel),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ExamText.figureValue.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// --- what the member already has with this paper -------------------------------------------------------------

/// A certificate held, a sitting left half done, the attempts used up, no questions: each said once, above the
/// sections, and only when it is so.
List<Widget> _notices(BuildContext context, BriefController brief) {
  final cert = brief.certificate;
  final paper = brief.paper!;
  return [
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
    if (brief.exhausted && brief.saved == null)
      Notice(tone: NoticeTone.warning, text: 'You have used all ${paper.attemptLimit} attempts for this paper.'),
    if (brief.noQuestions)
      const Notice(tone: NoticeTone.warning, text: 'This paper has no questions yet. Check back soon.'),
  ];
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

// --- when the paper is closed to the member ------------------------------------------------------------------

/// One way to open a locked paper, as the card lists it and the button in Take test's place does it.
class _Unlock {
  const _Unlock({
    required this.title,
    required this.body,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.note,
    this.price,
  });

  final String title;
  final String body;

  /// The button's words: "Open with my plan", "Redeem 4 credits", "Pay on the website".
  final String label;
  final IconData icon;

  /// Null when the way is shut for now (too few credits, payment not available).
  final VoidCallback? onPressed;

  /// A line under the body in amber: what is missing.
  final String? note;

  /// The price under the body, for buying.
  final PaperQuote? price;
}

/// The ways in that this member has, plan first, then credits, then paying.
List<_Unlock> _unlocks(BuildContext context, BriefController brief) {
  final lock = brief.lock!;
  final paper = brief.paper!;
  final quote = brief.quote;
  final mock = paper.isMock;
  final redeemable = quote != null && quote.credits != null && !quote.alreadyOpen;
  final buyable = quote != null && quote.priced && !quote.alreadyOpen;
  return [
    if (lock.planCanOpen)
      _Unlock(
        title: mock ? 'Your plan includes a mock exam' : 'Your plan includes a course',
        body:
            'Opening it with your plan uses ${lock.placesLeft == 1 ? 'your last place' : 'one of your free places'} and costs nothing.',
        label: 'Open with my plan',
        icon: LucideIcons.lockOpen,
        onPressed: () => _confirmOpenWithPlan(context, brief, mock: mock),
      ),
    if (redeemable)
      _Unlock(
        title: 'Redeem ICR credits',
        body:
            'It takes ${plural(quote.credits!, 'ICR credit')} (worth ${rupees(quote.credits! * quote.rupeesPerCredit * 100)}) and opens it for good. You have ${lock.credits}.',
        label: 'Redeem ${plural(quote.credits!, 'credit')}',
        icon: LucideIcons.coins,
        onPressed: lock.credits >= quote.credits! ? () => _confirmRedeem(context, brief, quote, lock) : null,
        note: lock.credits < quote.credits!
            ? 'You need ${quote.credits! - lock.credits} more. Inviting colleagues to ICR earns credits.'
            : null,
      ),
    if (buyable)
      _Unlock(
        title: mock ? 'Buy this set' : 'Buy this level',
        body: quote.taxPaisa > 0
            ? 'GST (${percentOfBps(quote.taxBps)}) ${rupees(quote.taxPaisa)}, total ${rupees(quote.totalPaisa)}.'
            : 'Total ${rupees(quote.totalPaisa)}.',
        label: quote.payable ? 'Pay now' : 'Payment is not available',
        icon: LucideIcons.creditCard,
        onPressed: quote.payable ? () => _buyPaper(context, brief) : null,
        price: quote,
      ),
  ];
}

/// The way the button in Take test's place takes: the first that is open, else the first there is.
_Unlock? _primaryUnlock(List<_Unlock> options) =>
    options.where((o) => o.onPressed != null).firstOrNull ?? options.firstOrNull;

/// The card above the sections on a paper the member cannot open: why, and each way in. The primary way is the
/// button at the bottom; the others have their own button here.
class _Access extends StatelessWidget {
  const _Access({required this.brief});

  final BriefController brief;

  @override
  Widget build(BuildContext context) {
    final lock = brief.lock!;
    final mock = brief.paper!.isMock;
    final options = _unlocks(context, brief);
    final primary = _primaryUnlock(options);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(9, 12, 9, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: ExamColors.action.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.lock, size: 18, color: ExamColors.action),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mock ? 'This mock set is locked' : 'This assessment level is locked',
                      style: ExamText.briefHeading,
                    ),
                    const SizedBox(height: 2),
                    Text(lock.message, style: ExamText.briefLine),
                  ],
                ),
              ),
            ],
          ),
          for (final o in options) ...[
            const SizedBox(height: 10),
            const _Rule(),
            _UnlockRow(option: o, withButton: o != primary, busy: brief.working),
          ],
          if (brief.actionError != null) ...[
            const SizedBox(height: 10),
            Notice(tone: NoticeTone.error, text: brief.actionError!),
          ],
          if (lock.plan != null) ...[
            const SizedBox(height: 4),
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

class _UnlockRow extends StatelessWidget {
  const _UnlockRow({required this.option, required this.withButton, required this.busy});

  final _Unlock option;
  final bool withButton;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final price = option.price;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(option.title, style: ExamText.cardTitle),
          const SizedBox(height: 2),
          if (price != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (price.discountPaisa > 0) ...[
                  Text(
                    rupees(price.listPaisa),
                    style: ExamText.detailLabel.copyWith(
                      color: AppColors.slate400,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(rupees(price.salePaisa), style: ExamText.briefTitle),
                if (price.discountPaisa > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${percentOfBps(price.discountBps)} off',
                    style: ExamText.at(13, FontWeight.w700, AppColors.successInk, line: 18),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
          ],
          Text(option.body, style: ExamText.briefLine),
          if (option.note != null) ...[
            const SizedBox(height: 4),
            Text(option.note!, style: ExamText.briefLine.copyWith(color: AppColors.amber800)),
          ],
          if (withButton) ...[
            const SizedBox(height: 10),
            ExamButton(
              label: option.label,
              icon: option.icon,
              color: ExamColors.action,
              height: 40,
              radius: 6,
              busy: busy,
              onPressed: option.onPressed,
            ),
          ],
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

/// Buys the paper in the app: the checkout, the gateway in the app's own payment view, then the brief read again
/// (owner's call, 2 Nov 2026 — it used to open the paper's page on the website in the phone's browser).
Future<void> _buyPaper(BuildContext context, BriefController brief) async {
  final paper = brief.paper!;
  CheckoutStart start;
  try {
    start = await brief.repository.checkout(brief.ref.slug);
  } catch (e) {
    if (context.mounted) showMessage(context, ApiError.from(e).message);
    return;
  }
  if (!context.mounted) return;
  final outcome = await runCheckout(context, start, title: 'Pay for ${paper.name}');
  if (!context.mounted) return;
  await brief.load();
  if (context.mounted) showMessage(context, paymentMessage(outcome, what: paper.name));
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

// --- the bar --------------------------------------------------------------------------------------------------

/// The sitting the button starts: the unfinished one picked up, else a fresh one; null when none may start.
ExamStart? _start(BriefController brief) {
  if (!brief.canStart) return null;
  return brief.saved != null ? brief.resume() : brief.begin();
}

/// Take test (or what stands in its place) and Back, as the design lays them: a filled button, then a text one.
class _Bar extends StatelessWidget {
  const _Bar({required this.brief});

  final BriefController brief;

  @override
  Widget build(BuildContext context) {
    final String? label;
    final VoidCallback? onTap;
    var busy = false;
    switch (brief.status) {
      case BriefStatus.loading:
      case BriefStatus.failed:
        label = null;
        onTap = null;
      case BriefStatus.locked:
        final options = _unlocks(context, brief);
        final primary = _primaryUnlock(options);
        label = primary?.label ?? 'Take test';
        onTap = primary?.onPressed;
        busy = brief.working;
      case BriefStatus.ready:
        label = brief.saved != null && brief.savedExpired
            ? 'Submit my saved answers'
            : brief.saved != null
            ? 'Resume · ${clockLabel(brief.savedLeft)} left'
            : 'Take test';
        onTap = brief.canStart
            ? () {
                final start = _start(brief);
                if (start != null) popOnce(context, start);
              }
            : null;
    }
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 15),
          child: Row(
            children: [
              if (label != null) ...[
                Expanded(
                  flex: 207,
                  child: _TakeTest(label: label, busy: busy, onTap: onTap),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(flex: 102, child: _Back(onTap: () => popOnce(context))),
              if (label != null) const Spacer(flex: 35),
            ],
          ),
        ),
      ),
    );
  }
}

/// The filled button: 41 dp tall, radius 6, the one word or two.
class _TakeTest extends StatelessWidget {
  const _TakeTest({required this.label, required this.busy, required this.onTap});

  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(6));
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: enabled ? ExamColors.action : ExamColors.action.withValues(alpha: 0.45),
        shape: shape,
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: shape,
          child: SizedBox(
            height: 41,
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(label, maxLines: 1, softWrap: false, style: ExamText.barButton),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Back extends StatelessWidget {
  const _Back({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 41,
          child: Center(
            child: Text('Back', style: ExamText.barButton.copyWith(color: ExamColors.action)),
          ),
        ),
      ),
    );
  }
}
