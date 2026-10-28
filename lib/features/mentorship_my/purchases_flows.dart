import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import 'mentoring_clock.dart';
import 'mentoring_format.dart';
import 'mentoring_links.dart';
import 'mentoring_models.dart';
import 'purchases_controller.dart';
import 'widgets/forms.dart';
import 'widgets/kit.dart';

/// The API's limits on what a buyer writes about a purchase.
const minCancelReason = 5;
const minDeclineTimeNote = 5;
const maxNote = 500;
const minReportNote = 10;
const maxMoveNote = 300;
const minReviewComment = 10;

/// The price as checkout will charge it, spelled out: the list price struck
/// through when something came off, a session credit offered (and ticked) when
/// the plan holds one, and the member discount named with its plan.
class QuoteBlock extends StatelessWidget {
  const QuoteBlock({super.key, required this.quote, this.onCredit, this.creditCoversOnly = false});

  final PriceQuote quote;

  /// Called when the credit tick changes; null hides the tick.
  final ValueChanged<bool>? onCredit;

  /// The credit is offered only when it pays the whole price (accepting a time never leaves a part to pay).
  final bool creditCoversOnly;

  @override
  Widget build(BuildContext context) {
    final q = quote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              q.free ? 'Free' : (q.chargedPaisa == 0 ? '₹0' : inr(q.chargedPaisa)),
              key: const ValueKey('quote-charged'),
              style: MentoringText.hero,
            ),
            if (q.discounted) ...[
              const SizedBox(width: 8),
              Text(
                inr(q.listPaisa),
                key: const ValueKey('quote-list'),
                style: MentoringText.body.copyWith(decoration: TextDecoration.lineThrough),
              ),
            ],
          ],
        ),
        if (q.canCredit && onCredit != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: InkWell(
              key: const ValueKey('quote-credit'),
              onTap: () => onCredit!(!q.useCredit),
              child: Row(
                children: [
                  Checkbox(value: q.useCredit, onChanged: (v) => onCredit!(v ?? false)),
                  Expanded(
                    child: Text(
                      'Use a session credit from ${q.credits!.planName ?? 'your plan'} '
                      '(${q.credits!.remaining} left, up to ${inr(q.credits!.capPaisa)})',
                      style: MentoringText.body,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (q.creditPaisa > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              q.chargedPaisa == 0
                  ? 'The credit covers the whole session.'
                  : 'The credit pays ${inr(q.creditPaisa)}; you pay ${inr(q.chargedPaisa)}.',
              key: const ValueKey('quote-credit-note'),
              style: MentoringText.meta.copyWith(color: MentoringColors.mintInk),
            ),
          ),
        if (q.bps > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${_pct(q.bps)} member discount from ${q.planName ?? 'your plan'}.',
              key: const ValueKey('quote-discount'),
              style: MentoringText.meta.copyWith(color: MentoringColors.mintInk),
            ),
          ),
      ],
    );
  }
}

String _pct(int bps) {
  final v = bps / 100;
  return '${v == v.roundToDouble() ? v.round() : v}%';
}

/// Says where a payment went: done in the app, or continuing on the website's payment page.
Future<void> finishPayment(BuildContext context, MentorshipLinks links, PaymentOutcome outcome) async {
  if (outcome.completed) {
    showMessage(context, outcome.message ?? 'Done.');
    return;
  }
  if (outcome.sitePath != null) await links.openSite(context, outcome.sitePath!);
}

// ---------------------------------------------------------------------------
// Accept the time the mentor set
// ---------------------------------------------------------------------------

/// The mentor set a time: the mentee takes it (booked on both calendars) or sends it back. A paid session is
/// paid for after; a session credit that covers the whole price may be spent here instead.
Future<bool> showAcceptTimeSheet(BuildContext context, PurchasesBook book, ServicePurchase p) async {
  final discounts = await book.quoteInputs();
  if (!context.mounted) return false;
  return showFormSheet(context, (_) => _AcceptTimeForm(book: book, purchase: p, discounts: discounts));
}

class _AcceptTimeForm extends StatefulWidget {
  const _AcceptTimeForm({required this.book, required this.purchase, required this.discounts});

  final PurchasesBook book;
  final ServicePurchase purchase;
  final MemberDiscounts? discounts;

  @override
  State<_AcceptTimeForm> createState() => _AcceptTimeFormState();
}

class _AcceptTimeFormState extends State<_AcceptTimeForm> {
  bool _useCredit = true;
  String? _problem;
  bool _busy = false;

  Future<void> _submit(bool credit) async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    final refusal = await widget.book.acceptTime(widget.purchase, useCredit: credit);
    if (!mounted) return;
    if (refusal != null) {
      setState(() {
        _busy = false;
        _problem = refusal;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.purchase;
    final req = p.request!;
    final quote = PriceQuote.session(req.listPricePaisa, widget.discounts, useCredit: _useCredit);
    // A credit that pays only part leaves money to pay: that choice is made when paying.
    final covers = quote.canCredit && quote.credits!.capPaisa >= req.listPricePaisa;
    final credit = covers && _useCredit;
    return MentoringForm(
      title: 'Accept the time ${p.mentor?.firstName ?? 'the mentor'} set?',
      subtitle: 'It is booked on both calendars at once.',
      submitLabel: 'Accept and confirm',
      busy: _busy,
      problem: _problem,
      onSubmit: () => _submit(credit),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.primary, width: 4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(req.scheduledAt == null ? '' : whenLabel(req.scheduledAt!), style: MentoringText.hero),
              Text(
                '${p.title} · ${minutesLabel(req.durationMin ?? 30)}${req.mode == null ? '' : ' · ${modeLabel(req.mode!)}'}',
                style: MentoringText.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (req.listPricePaisa > 0)
          QuoteBlock(
            quote: covers ? quote : PriceQuote.session(req.listPricePaisa, widget.discounts, useCredit: false),
            onCredit: covers ? (v) => setState(() => _useCredit = v) : null,
          ),
        const SizedBox(height: 8),
        Text(
          credit
              ? 'A session credit pays for it, so there is nothing to pay.'
              : req.listPricePaisa == 0
              ? 'It is free: nothing to pay.'
              : 'You pay ${inr(PriceQuote.session(req.listPricePaisa, widget.discounts, useCredit: false).chargedPaisa)} after, to confirm it.',
          key: const ValueKey('accept-note'),
          style: MentoringText.body,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pay for a session
// ---------------------------------------------------------------------------

/// Pays for an accepted session. The quote shown is the one checkout charges (member discount, or a session
/// credit that replaces it); a real PayU payment continues on the website's payment page.
Future<bool> showPaySessionSheet(
  BuildContext context,
  PurchasesBook book,
  ServicePurchase p,
  MentorshipLinks links,
) async {
  final discounts = await book.quoteInputs();
  if (!context.mounted) return false;
  return showFormSheet(context, (_) => _PayForm(book: book, purchase: p, discounts: discounts, links: links));
}

class _PayForm extends StatefulWidget {
  const _PayForm({required this.book, required this.purchase, required this.discounts, required this.links});

  final PurchasesBook book;
  final ServicePurchase purchase;
  final MemberDiscounts? discounts;
  final MentorshipLinks links;

  @override
  State<_PayForm> createState() => _PayFormState();
}

class _PayFormState extends State<_PayForm> {
  bool _useCredit = true;
  String? _problem;
  bool _busy = false;
  bool? _live;

  @override
  void initState() {
    super.initState();
    widget.book.repository.paymentsLive().then((v) {
      if (mounted) setState(() => _live = v);
    });
  }

  Future<void> _pay(PriceQuote quote) async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final outcome = await widget.book.payPurchase(widget.purchase, quote);
      if (!mounted) return;
      Navigator.pop(context, true);
      await finishPayment(context, widget.links, outcome);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = ApiError.from(e).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.purchase;
    final req = p.request;
    final list = p.duePaisa;
    final quote = PriceQuote.session(list, widget.discounts, useCredit: _useCredit);
    final onSite = quote.chargedPaisa > 0 && _live == true;
    final at = p.booking?.scheduledAt ?? req?.scheduledAt;
    final confirmed = p.status == PurchaseStatus.confirmed;
    return MentoringForm(
      title: confirmed ? 'Pay for your session' : 'Pay to confirm',
      subtitle: p.mentor == null ? null : 'With ${p.mentor!.name}',
      submitLabel: quote.chargedPaisa == 0
          ? (confirmed ? 'Pay with a session credit' : 'Book with a session credit')
          : (onSite ? 'Pay ${inr(quote.chargedPaisa)} on the website' : 'Pay ${inr(quote.chargedPaisa)}'),
      busy: _busy,
      problem: _problem,
      onSubmit: () => _pay(quote),
      children: [
        Text(p.title, style: MentoringText.cardTitle),
        const SizedBox(height: 6),
        QuoteBlock(quote: quote, onCredit: (v) => setState(() => _useCredit = v)),
        const SizedBox(height: 10),
        if (at != null) MetaLine(icon: LucideIcons.calendarClock, text: whenLabel(at)),
        if (req != null)
          MetaLine(
            icon: LucideIcons.clock,
            text: '${minutesLabel(req.durationMin ?? 30)}${req.mode == null ? '' : ' · ${modeLabel(req.mode!)}'}',
          ),
        if (req?.payBy != null && !confirmed)
          MetaLine(icon: LucideIcons.hourglass, text: 'Pay by ${whenLabel(req!.payBy!)}'),
        if (onSite)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'The payment itself is made on ICR\'s secure PayU page on the website: the button opens it.',
              key: ValueKey('pay-handoff'),
              style: _meta,
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  static const _meta = TextStyle(fontFamily: 'Roboto', fontSize: 12, color: AppColors.outline, height: 1.4);
}

/// Pays for a programme the mentor accepted, showing the API's own quote: list price, what the member's plan
/// took off, the tax, and the total.
Future<bool> showPayTermSheet(BuildContext context, PurchasesBook book, PlanTerm t, MentorshipLinks links) =>
    showFormSheet(context, (_) => _PayTermForm(book: book, term: t, links: links));

class _PayTermForm extends StatefulWidget {
  const _PayTermForm({required this.book, required this.term, required this.links});

  final PurchasesBook book;
  final PlanTerm term;
  final MentorshipLinks links;

  @override
  State<_PayTermForm> createState() => _PayTermFormState();
}

class _PayTermFormState extends State<_PayTermForm> {
  String? _problem;
  bool _busy = false;
  bool? _live;

  @override
  void initState() {
    super.initState();
    widget.book.repository.paymentsLive().then((v) {
      if (mounted) setState(() => _live = v);
    });
  }

  Future<void> _pay() async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final outcome = await widget.book.payTerm(widget.term);
      if (!mounted) return;
      Navigator.pop(context, true);
      await finishPayment(context, widget.links, outcome);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = ApiError.from(e).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.term;
    final onSite = t.totalPaisa > 0 && _live == true;
    Widget line(String label, String value, {bool strong = false, Key? key}) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: strong ? MentoringText.bodyStrong : MentoringText.body)),
          Text(value, key: key, style: strong ? MentoringText.bodyStrong : MentoringText.body),
        ],
      ),
    );
    return MentoringForm(
      title: t.programme ? 'Pay for your programme' : 'Pay for your plan',
      subtitle: '${t.title}${t.counterpart == null ? '' : ' with ${t.counterpart!.name}'}',
      submitLabel: t.totalPaisa == 0
          ? 'Start it'
          : (onSite ? 'Pay ${inr(t.totalPaisa)} on the website' : 'Pay ${inr(t.totalPaisa)}'),
      busy: _busy,
      problem: _problem,
      onSubmit: _pay,
      children: [
        line('Price', inr(t.pricePaisa == 0 ? t.totalPaisa : t.pricePaisa), key: const ValueKey('term-price')),
        if (t.discountPaisa > 0)
          line('Member discount', '−${inr(t.discountPaisa)}', key: const ValueKey('term-discount')),
        if (t.taxPaisa > 0) line('Tax', inr(t.taxPaisa), key: const ValueKey('term-tax')),
        const Divider(),
        line('Total', t.totalPaisa == 0 ? 'Free' : inr(t.totalPaisa), strong: true, key: const ValueKey('term-total')),
        if (t.sessionsAllowance > 0)
          MetaLine(icon: LucideIcons.calendarCheck, text: '${countLabel(t.sessionsAllowance, 'session')} included'),
        if (onSite)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'The payment itself is made on ICR\'s secure PayU page on the website: the button opens it.',
              key: ValueKey('pay-handoff'),
              style: TextStyle(fontFamily: 'Roboto', fontSize: 12, color: AppColors.outline, height: 1.4),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Smaller asks
// ---------------------------------------------------------------------------

/// The time the mentor set does not suit: say when would, and the request goes back to them. Nothing is charged.
Future<bool> showAskAnotherTimeSheet(BuildContext context, PurchasesBook book, ServicePurchase p) {
  final name = p.mentor?.firstName ?? 'your mentor';
  final at = p.request?.scheduledAt;
  return showTextSheet(
    context,
    title: 'Ask $name for another time',
    subtitle: '${at == null ? '' : '${whenLabel(at)} does not suit. '}Say which times would, and $name sets another.',
    label: 'Which times would work for you?',
    hint: 'Weekday evenings after 7 pm',
    submitLabel: 'Send to $name',
    minLength: minDeclineTimeNote,
    maxLength: maxNote,
    onSend: (note) => book.declineTime(p, note),
  );
}

/// Cancel a booked session, with a reason the other person reads (at least five characters).
Future<bool> showCancelBookingSheet(BuildContext context, PurchasesBook book, ServicePurchase p) => showTextSheet(
  context,
  title: p.status == PurchaseStatus.confirmed ? 'Cancel this unpaid session?' : 'Cancel this session?',
  subtitle: 'The other person is told, with your reason. Whether you are refunded follows ICR\'s cancellation rules.',
  label: 'Reason',
  hint: 'Something came up at work',
  submitLabel: 'Cancel session',
  minLength: minCancelReason,
  maxLength: maxNote,
  danger: true,
  onSend: (reason) => book.cancel(p, reason),
);

/// Report a problem with a purchase: it lands in ICR's queue and the seller reads it.
Future<bool> showReportIssueSheet(BuildContext context, PurchasesBook book, ServicePurchase p) => showTextSheet(
  context,
  title: 'Report a problem',
  subtitle: 'ICR looks into it, and ${p.mentor?.firstName ?? 'the seller'} is asked to reply.',
  label: 'What went wrong',
  hint: 'The file would not open',
  submitLabel: 'Send report',
  minLength: minReportNote,
  maxLength: 2000,
  lines: 4,
  onSend: (note) => book.reportIssue(p, note),
);

/// Rate a finished session or a guide (a comment, when given, is at least ten characters).
Future<bool> showReviewPurchaseSheet(BuildContext context, PurchasesBook book, ServicePurchase p) => showReviewSheet(
  context,
  title: 'Review ${p.title}',
  subtitle: 'Shown on ${p.mentor?.firstName ?? 'the mentor'}\'s profile.',
  flagLabel: 'Hide my name on the review',
  flagDefault: false,
  minComment: minReviewComment,
  onSend: (rating, comment, hide) => book.review(p, rating: rating, comment: comment, anonymous: hide),
);

/// Asks to move a booked call: pick a new time from the mentor's free hours (or any time), add a note. The
/// other person accepts or keeps the booked time. Length and mode stay what was bought.
Future<bool> showProposeMoveSheet(BuildContext context, PurchasesBook book, ServicePurchase p) =>
    showFormSheet(context, (_) => _ProposeMoveForm(book: book, purchase: p));

class _ProposeMoveForm extends StatefulWidget {
  const _ProposeMoveForm({required this.book, required this.purchase});

  final PurchasesBook book;
  final ServicePurchase purchase;

  @override
  State<_ProposeMoveForm> createState() => _ProposeMoveFormState();
}

class _ProposeMoveFormState extends State<_ProposeMoveForm> {
  final _note = TextEditingController();
  DateTime? _at;
  late final Future<List<Slot>> _slots = widget.purchase.mentorProfileId == null
      ? Future.value(const <Slot>[])
      : widget.book.repository
            .slots(widget.purchase.mentorProfileId!, durationMin: widget.purchase.booking?.durationMin ?? 60)
            .catchError((_) => const <Slot>[]);
  String? _problem;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final at = _at;
    if (at == null) {
      setState(() => _problem = 'Pick a new time first.');
      return;
    }
    if (!at.isAfter(mentoringNow())) {
      setState(() => _problem = 'Pick a time in the future.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final refusal = await widget.book.proposeMove(widget.purchase, at, _note.text);
    if (!mounted) return;
    if (refusal != null) {
      setState(() {
        _busy = false;
        _problem = refusal;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.purchase;
    return MentoringForm(
      title: 'Ask to move this call',
      subtitle:
          '${p.booking == null ? '' : 'Now ${whenLabel(p.booking!.scheduledAt)}. '}${p.mentor?.firstName ?? 'The mentor'} accepts or keeps the booked time.',
      submitLabel: 'Ask to move',
      busy: _busy,
      problem: _problem,
      onSubmit: _submit,
      children: [
        FutureBuilder<List<Slot>>(
          future: _slots,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              );
            }
            final slots = snap.data ?? const <Slot>[];
            final own = _at != null && !slots.any((s) => s.at.isAtSameMomentAs(_at!));
            return FieldBlock(
              label: slots.isEmpty ? 'New time' : 'Free times in their hours',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (slots.isNotEmpty)
                    SlotPicker(slots: slots, selected: _at, onSelect: (at) => setState(() => _at = at)),
                  const SizedBox(height: 8),
                  QuietButton(
                    label: own ? whenLabel(_at!) : (slots.isEmpty ? 'Pick a day and time' : 'Another time'),
                    icon: LucideIcons.calendarClock,
                    onPressed: () async {
                      final at = await pickDateTime(context, initial: _at);
                      if (at != null && mounted) setState(() => _at = at);
                    },
                  ),
                ],
              ),
            );
          },
        ),
        FieldBlock(
          label: 'A note (optional)',
          child: TextField(
            key: const ValueKey('move-note'),
            controller: _note,
            minLines: 2,
            maxLines: 3,
            maxLength: maxMoveNote,
            style: MentoringText.formInput,
            decoration: fieldDecoration('That day clashes with a site audit'),
          ),
        ),
      ],
    );
  }
}

/// Answers a move the mentor proposed: accept it, or keep the booked time (a reason is optional).
Future<bool> showKeepTimeSheet(BuildContext context, PurchasesBook book, ServicePurchase p) => showTextSheet(
  context,
  title: 'Keep the booked time?',
  subtitle: '${p.mentor?.firstName ?? 'The mentor'} is told, with your reason if you give one.',
  label: 'A note back (optional)',
  hint: 'That day does not work for me',
  submitLabel: 'Keep the booked time',
  maxLength: maxMoveNote,
  optional: true,
  onSend: (reason) => book.answerMove(p, accept: false, reason: reason),
);
