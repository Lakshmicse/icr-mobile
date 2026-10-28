import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import 'mentoring_format.dart';
import 'mentoring_links.dart';
import 'mentoring_models.dart';
import 'my_mentoring_controller.dart';
import 'purchases_controller.dart';
import 'purchases_flows.dart';
import 'widgets/blocks.dart';
import 'widgets/kit.dart';

/// Where a purchase belongs on the tab.
enum PurchaseBucket { needs, active, past }

/// A mentor proposed a new time for a booked call and waits for the member.
bool movePendingOnMe(ServicePurchase p) {
  final b = p.booking;
  return b != null && b.scheduled && b.proposedAt != null && b.proposedBy == 'MENTOR';
}

/// The member proposed a new time and waits for the mentor.
bool movePendingOnThem(ServicePurchase p) {
  final b = p.booking;
  return b != null && b.scheduled && b.proposedAt != null && b.proposedBy != 'MENTOR';
}

PurchaseBucket bucketOf(ServicePurchase p) {
  switch (p.status) {
    case PurchaseStatus.accepted:
    case PurchaseStatus.pendingPayment:
    case PurchaseStatus.confirmed:
      return PurchaseBucket.needs;
    case PurchaseStatus.requested:
      return PurchaseBucket.active;
    case PurchaseStatus.paid:
      if (movePendingOnMe(p)) return PurchaseBucket.needs;
      final b = p.booking;
      if (b != null && !b.scheduled) return PurchaseBucket.past;
      return PurchaseBucket.active;
    case PurchaseStatus.fulfilled:
      // A session held without a review yet still wants the member's hands once.
      return !p.hasReview && p.type == ServiceType.oneOnOne ? PurchaseBucket.needs : PurchaseBucket.past;
    default:
      return PurchaseBucket.past;
  }
}

PurchaseBucket termBucket(PlanTerm t) => switch (t.status) {
  'PENDING_PAYMENT' => PurchaseBucket.needs,
  'PENDING_MENTOR' || 'ACTIVE' => PurchaseBucket.active,
  _ => PurchaseBucket.past,
};

Future<void> _report(BuildContext context, Future<String?> Function() action, {String? done}) async {
  final refusal = await action();
  if (!context.mounted) return;
  if (refusal != null) {
    showMessage(context, refusal);
  } else if (done != null) {
    showMessage(context, done);
  }
}

/// What the member bought or asked for, grouped by whether it needs them: 1:1 sessions and guides, programmes
/// and plans, group seats and cohort places. Every payment shows the API's quote first; a real PayU payment
/// continues on the website's payment page.
class PurchasesTab extends StatefulWidget {
  const PurchasesTab({
    super.key,
    required this.controller,
    required this.links,
    this.onOpenGroup,
    this.onOpenPairing,
    this.onOpenProgramme,
    this.onBrowseGroups,
    this.onBrowseProgrammes,
  });

  final MyMentoringController controller;
  final MentorshipLinks links;
  final ValueChanged<String>? onOpenGroup;
  final ValueChanged<String>? onOpenPairing;
  final ValueChanged<String>? onOpenProgramme;
  final VoidCallback? onBrowseGroups;
  final VoidCallback? onBrowseProgrammes;

  @override
  State<PurchasesTab> createState() => _PurchasesTabState();
}

class _PurchasesTabState extends State<PurchasesTab> {
  bool _past = false;

  PurchasesBook get book => widget.controller.book;

  @override
  Widget build(BuildContext context) {
    final purchases = book.purchases.data ?? const <ServicePurchase>[];
    final terms = book.terms.data ?? const <PlanTerm>[];
    final seats = book.seats.data ?? const <GroupSession>[];
    final enrolments = book.enrolments.data ?? const <ProgrammeEnrolment>[];

    List<Widget> cards(PurchaseBucket bucket) => [
      for (final t in terms)
        if (termBucket(t) == bucket)
          _TermCard(book: book, links: widget.links, term: t, onOpenPairing: widget.onOpenPairing),
      for (final p in purchases)
        if (bucketOf(p) == bucket)
          PurchaseCard(book: book, links: widget.links, purchase: p, onOpenGroup: widget.onOpenGroup),
      if (bucket == PurchaseBucket.active) ...[
        for (final e in enrolments)
          if (e.live) _EnrolmentCard(book: book, enrolment: e, onOpenProgramme: widget.onOpenProgramme),
        for (final s in seats) _SeatCard(book: book, session: s, onOpenGroup: widget.onOpenGroup),
      ],
      if (bucket == PurchaseBucket.past)
        for (final e in enrolments)
          if (!e.live) _EnrolmentCard(book: book, enrolment: e, onOpenProgramme: widget.onOpenProgramme),
    ];

    final needs = cards(PurchaseBucket.needs);
    final active = cards(PurchaseBucket.active);
    final past = cards(PurchaseBucket.past);

    final children = <Widget>[
      if (book.loaded && needs.isEmpty && active.isEmpty && past.isEmpty)
        EmptyNote(
          icon: LucideIcons.shoppingBag,
          title: 'Nothing bought yet',
          body:
              'Sessions, guides, programmes and plans you ask for or buy from a mentor show up here, with group sessions and cohorts.',
          action: 'Browse mentors',
          onAction: () => widget.links.directory(context),
        ),
      if (needs.isNotEmpty) ...[const GroupLabel('Needs you', top: 0), ...needs],
      if (active.isNotEmpty) ...[GroupLabel('Active', top: needs.isEmpty ? 0 : 12), ...active],
      if (past.isNotEmpty) ...[
        InkWell(
          key: const ValueKey('toggle-past-purchases'),
          onTap: () => setState(() => _past = !_past),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(_past ? 'Hide past' : 'Past (${past.length})', style: MentoringText.buttonQuiet),
          ),
        ),
        if (_past) ...past,
      ],
      if (widget.onBrowseGroups != null || widget.onBrowseProgrammes != null)
        ActionWrap(
          top: 12,
          children: [
            if (widget.onBrowseGroups != null)
              QuietButton(label: 'Group sessions', icon: LucideIcons.users, onPressed: widget.onBrowseGroups),
            if (widget.onBrowseProgrammes != null)
              QuietButton(label: 'Programmes', icon: LucideIcons.layers, onPressed: widget.onBrowseProgrammes),
          ],
        ),
    ];
    return LoadedList(
      loading: book.loading,
      error: book.error,
      errorTitle: "Couldn't load your purchases",
      onRefresh: book.reload,
      children: book.loading || book.error != null ? const [] : children,
    );
  }
}

// ---------------------------------------------------------------------------
// A 1:1 session, a guide, a group seat bought
// ---------------------------------------------------------------------------

class PurchaseCard extends StatelessWidget {
  const PurchaseCard({super.key, required this.book, required this.links, required this.purchase, this.onOpenGroup});

  final PurchasesBook book;
  final MentorshipLinks links;
  final ServicePurchase purchase;
  final ValueChanged<String>? onOpenGroup;

  @override
  Widget build(BuildContext context) {
    final p = purchase;
    final mentor = p.mentor?.firstName ?? 'the mentor';
    final req = p.request;
    final b = p.booking;
    final link = meetingUri(b?.meetingLink);
    final accepted = p.status == PurchaseStatus.accepted;
    final pendingPayment = p.status == PurchaseStatus.pendingPayment;
    final confirmed = p.status == PurchaseStatus.confirmed;
    final paid = p.status == PurchaseStatus.paid || p.status == PurchaseStatus.fulfilled;
    final due = p.duePaisa;
    return Container(
      key: ValueKey('purchase-${p.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bucketOf(p) == PurchaseBucket.needs ? AppColors.amber500 : AppColors.cardRule),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(p.title, style: MentoringText.cardTitle)),
              StatusPill(p.status.label, tone: _tone(p.status)),
            ],
          ),
          MetaLine(icon: LucideIcons.user, text: '${p.type.label}${p.mentor == null ? '' : ' with ${p.mentor!.name}'}'),
          MetaLine(
            icon: LucideIcons.indianRupee,
            text: due == 0 && p.pricePaisa == 0 ? 'Free' : inr(p.pricePaisa == 0 ? due : p.pricePaisa),
          ),
          // What was asked, until it is booked.
          if (req != null && b == null && p.type == ServiceType.oneOnOne)
            MetaLine(
              icon: LucideIcons.messageSquare,
              text: '“${req.topic}”${req.preferredTimes == null ? '' : '\nPrefers: ${req.preferredTimes}'}',
            ),
          if (p.status == PurchaseStatus.requested)
            Callout(tone: PillTone.grey, text: 'Waiting for $mentor to reply. A reply sets the time.'),
          if ((accepted || pendingPayment) && req?.scheduledAt != null)
            Callout(
              tone: PillTone.amber,
              text:
                  '$mentor set a time: ${whenLabel(req!.scheduledAt!)} · ${minutesLabel(req.durationMin ?? 30)}'
                  '${req.mode == null ? '' : ' · ${modeLabel(req.mode!)}'}.'
                  '${req.payBy == null ? '' : ' Reply by ${whenLabel(req.payBy!)}.'}',
            ),
          if (confirmed && (b?.scheduledAt ?? req?.scheduledAt) != null)
            Callout(
              tone: PillTone.amber,
              text:
                  'Booked for ${whenLabel((b?.scheduledAt ?? req!.scheduledAt)!)}. Payment of ${inr(due)} is due to confirm it.',
            ),
          if (p.status == PurchaseStatus.declined)
            Callout(
              tone: PillTone.red,
              text: '$mentor can\'t take it${req?.declineReason == null ? '.' : ': ${req!.declineReason}'}',
            ),
          if (req != null &&
              req.timeDeclineCount > 0 &&
              p.status == PurchaseStatus.requested &&
              req.timeDeclineNote != null)
            MetaLine(icon: LucideIcons.info, text: 'You asked for another time: ${req.timeDeclineNote}'),
          if (b != null && paid) ...[
            MetaLine(
              icon: LucideIcons.calendarClock,
              text: '${whenLabel(b.scheduledAt)} (${daysFromNow(b.scheduledAt)})',
            ),
            MetaLine(icon: LucideIcons.clock, text: '${minutesLabel(b.durationMin)} · ${modeLabel(b.mode)}'),
          ],
          if (movePendingOnMe(p))
            Callout(
              key: const ValueKey('move-on-me'),
              tone: PillTone.amber,
              text:
                  '$mentor asks to move this to ${whenLabel(b!.proposedAt!)}.'
                  '${b.proposedNote == null || b.proposedNote!.isEmpty ? '' : ' “${b.proposedNote}”'}',
              actions: [
                SolidButton(
                  label: 'Accept new time',
                  icon: LucideIcons.check,
                  onPressed: () =>
                      _report(context, () => book.answerMove(p, accept: true), done: 'Moved to the new time.'),
                ),
                QuietButton(label: 'Keep booked time', onPressed: () => showKeepTimeSheet(context, book, p)),
              ],
            ),
          if (movePendingOnThem(p))
            Callout(
              key: const ValueKey('move-on-them'),
              tone: PillTone.grey,
              text: 'You asked to move this to ${whenLabel(b!.proposedAt!)}. Waiting for $mentor.',
              actions: [
                QuietButton(
                  label: 'Withdraw the request',
                  onPressed: () =>
                      _report(context, () => book.answerMove(p, accept: false), done: 'Request withdrawn.'),
                ),
              ],
            ),
          if (p.status == PurchaseStatus.cancelled && p.cancelReason != null)
            MetaLine(icon: LucideIcons.info, text: p.cancelReason!, color: AppColors.amber800),
          if (p.status == PurchaseStatus.refunded || p.status == PurchaseStatus.refundDue)
            MetaLine(
              icon: LucideIcons.info,
              text: p.status == PurchaseStatus.refunded
                  ? 'Refunded${p.cancelReason == null ? '.' : ': ${p.cancelReason}'}'
                  : 'A refund is due to you. ICR is processing it.',
              color: AppColors.amber800,
            ),
          ActionWrap(children: _actions(context, link)),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context, Uri? link) {
    final p = purchase;
    final b = p.booking;
    final held = p.status == PurchaseStatus.fulfilled;
    final mentor = p.mentor?.firstName ?? 'the mentor';
    return [
      if (p.status == PurchaseStatus.requested)
        QuietButton(
          label: 'Withdraw',
          danger: true,
          onPressed: () => _report(context, () => book.withdrawRequest(p), done: 'Request withdrawn.'),
        ),
      if (p.status == PurchaseStatus.accepted) ...[
        SolidButton(
          label: 'Accept this time',
          icon: LucideIcons.check,
          onPressed: () async {
            final done = await showAcceptTimeSheet(context, book, p);
            if (done && context.mounted) {
              final now = (book.purchases.data ?? const <ServicePurchase>[]).where((x) => x.id == p.id).firstOrNull;
              showMessage(
                context,
                now?.status == PurchaseStatus.paid ? 'Booked on both calendars.' : 'Accepted. Pay to confirm it.',
              );
            }
          },
        ),
        QuietButton(label: 'Ask another time', onPressed: () => showAskAnotherTimeSheet(context, book, p)),
        QuietButton(
          label: 'Withdraw',
          danger: true,
          onPressed: () => _report(context, () => book.withdrawRequest(p), done: 'Request withdrawn.'),
        ),
      ],
      if (p.status == PurchaseStatus.pendingPayment || p.status == PurchaseStatus.confirmed)
        SolidButton(
          label: p.status == PurchaseStatus.confirmed ? 'Pay ${moneyLabel(p.duePaisa)}' : 'Pay to confirm',
          icon: LucideIcons.creditCard,
          onPressed: () => showPaySessionSheet(context, book, p, links),
        ),
      if (p.status == PurchaseStatus.confirmed || (b != null && b.scheduled && p.status == PurchaseStatus.paid))
        QuietButton(label: 'Cancel', danger: true, onPressed: () => showCancelBookingSheet(context, book, p)),
      if (b != null && b.scheduled && p.status == PurchaseStatus.paid && link != null)
        SolidButton(label: 'Join', icon: LucideIcons.video, onPressed: () => openUrl(context, link)),
      if (b != null && b.scheduled && p.status == PurchaseStatus.paid && b.proposedAt == null)
        QuietButton(label: 'Ask to move', onPressed: () => showProposeMoveSheet(context, book, p)),
      if (p.type == ServiceType.resource && held && p.downloadUrl != null)
        SolidButton(
          label: p.fileName == null ? 'Download' : 'Download ${p.fileName}',
          icon: LucideIcons.download,
          onPressed: () => links.download(context, () => book.download(p), _fileName(p)),
        ),
      if (p.type == ServiceType.groupSession && p.groupSessionId != null && onOpenGroup != null)
        QuietButton(label: 'Open session', onPressed: () => onOpenGroup!(p.groupSessionId!)),
      if ((p.status == PurchaseStatus.paid || held) && p.mentor != null)
        QuietButton(
          label: 'Message',
          icon: LucideIcons.messageSquare,
          onPressed: () => links.messagePurchase(context, book.repository, p.id),
        ),
      if (held && !p.hasReview)
        QuietButton(
          label: 'Leave a review',
          icon: LucideIcons.star,
          onPressed: () async {
            final sent = await showReviewPurchaseSheet(context, book, p);
            if (sent && context.mounted) showMessage(context, 'Thanks. Your review is on $mentor\'s profile.');
          },
        ),
      if (p.status == PurchaseStatus.paid || held || p.status == PurchaseStatus.confirmed)
        QuietButton(
          label: 'Report a problem',
          icon: LucideIcons.flag,
          onPressed: () async {
            final sent = await showReportIssueSheet(context, book, p);
            if (sent && context.mounted) showMessage(context, 'Sent. ICR will look into it.');
          },
        ),
    ];
  }

  String _fileName(ServicePurchase p) {
    final name = p.fileName ?? p.title;
    final url = p.downloadUrl ?? '';
    final dot = url.lastIndexOf('.');
    final ext = dot > url.lastIndexOf('/') ? url.substring(dot) : '';
    return name.contains('.') ? name : '$name$ext';
  }

  PillTone _tone(PurchaseStatus s) => switch (s) {
    PurchaseStatus.paid || PurchaseStatus.fulfilled => PillTone.mint,
    PurchaseStatus.accepted || PurchaseStatus.pendingPayment || PurchaseStatus.confirmed => PillTone.amber,
    PurchaseStatus.declined || PurchaseStatus.refundDue => PillTone.red,
    _ => PillTone.grey,
  };
}

// ---------------------------------------------------------------------------
// A programme or plan term
// ---------------------------------------------------------------------------

class _TermCard extends StatelessWidget {
  const _TermCard({required this.book, required this.links, required this.term, this.onOpenPairing});

  final PurchasesBook book;
  final MentorshipLinks links;
  final PlanTerm term;
  final ValueChanged<String>? onOpenPairing;

  @override
  Widget build(BuildContext context) {
    final t = term;
    final mentor = t.counterpart?.firstName ?? 'the mentor';
    final active = t.status == 'ACTIVE';
    final left = t.sessionsLeft;
    final next = active ? t.steps.where((s) => s.isNext).firstOrNull : null;
    return Container(
      key: ValueKey('term-${t.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: termBucket(t) == PurchaseBucket.needs ? AppColors.amber500 : AppColors.cardRule),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(t.title, style: MentoringText.cardTitle)),
              StatusPill(t.statusLabel, tone: active ? PillTone.mint : (t.open ? PillTone.amber : PillTone.grey)),
            ],
          ),
          MetaLine(
            icon: LucideIcons.layers,
            text:
                '${t.programme ? 'Programme' : 'Ongoing plan'}${t.counterpart == null ? '' : ' with ${t.counterpart!.name}'}',
          ),
          MetaLine(icon: LucideIcons.indianRupee, text: t.totalPaisa == 0 ? 'Free' : inr(t.totalPaisa)),
          if (t.status == 'PENDING_MENTOR')
            Callout(tone: PillTone.grey, text: 'Waiting for $mentor to accept. You pay only after they do.'),
          if (t.status == 'PENDING_PAYMENT')
            Callout(tone: PillTone.amber, text: '$mentor accepted. Payment of ${inr(t.totalPaisa)} starts it.'),
          if (t.status == 'DECLINED')
            Callout(
              tone: PillTone.red,
              text: '$mentor can\'t take it${t.declineReason == null ? '.' : ': ${t.declineReason}'}',
            ),
          if (t.status == 'REFUNDED')
            MetaLine(
              icon: LucideIcons.info,
              text: 'Refunded${t.cancelReason == null ? '.' : ': ${t.cancelReason}'}',
              color: AppColors.amber800,
            ),
          if (active && t.sessionsAllowance > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${sessionsLeft(left, t.sessionsAllowance)}${t.periodEnd == null ? '' : ' · use by ${dayLabel(t.periodEnd!)}'}',
              key: ValueKey('term-left-${t.id}'),
              style: MentoringText.bodyStrong,
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (t.sessionsUsed.clamp(0, t.sessionsAllowance)) / t.sessionsAllowance,
                minHeight: 6,
                backgroundColor: AppColors.surfaceContainer,
                color: MentoringColors.green,
              ),
            ),
          ],
          if (next != null) MetaLine(icon: LucideIcons.listChecks, text: 'Next: ${next.title}'),
          if (t.cancelAtPeriodEnd) const MetaLine(icon: LucideIcons.info, text: 'It will not renew.'),
          ActionWrap(
            children: [
              if (t.status == 'PENDING_PAYMENT')
                SolidButton(
                  label: 'Pay ${moneyLabel(t.totalPaisa)}',
                  icon: LucideIcons.creditCard,
                  onPressed: () => showPayTermSheet(context, book, t, links),
                ),
              if (t.status == 'PENDING_MENTOR' || t.status == 'PENDING_PAYMENT')
                QuietButton(
                  label: 'Withdraw',
                  danger: true,
                  onPressed: () => _report(context, () => book.cancelTerm(t), done: 'Request withdrawn.'),
                ),
              if (t.mentorshipId != null && onOpenPairing != null && active && left > 0)
                SolidButton(label: 'Schedule a session', onPressed: () => onOpenPairing!(t.mentorshipId!)),
              if (t.mentorshipId != null && onOpenPairing != null && !(active && left > 0))
                QuietButton(label: 'Open mentorship', onPressed: () => onOpenPairing!(t.mentorshipId!)),
              if (active && !t.programme && !t.cancelAtPeriodEnd)
                QuietButton(
                  label: 'Do not renew',
                  onPressed: () => _report(context, () => book.cancelTerm(t), done: 'It will not renew.'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// A cohort place, a group seat
// ---------------------------------------------------------------------------

class _EnrolmentCard extends StatelessWidget {
  const _EnrolmentCard({required this.book, required this.enrolment, this.onOpenProgramme});

  final PurchasesBook book;
  final ProgrammeEnrolment enrolment;
  final ValueChanged<String>? onOpenProgramme;

  @override
  Widget build(BuildContext context) {
    final e = enrolment;
    final p = e.programme;
    return MentoringCard(
      key: ValueKey('enrolment-${e.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(p?.name ?? 'A cohort programme', style: MentoringText.cardTitle)),
              StatusPill(
                e.statusLabel,
                tone: switch (e.status) {
                  'ACCEPTED' || 'MATCHED' => PillTone.mint,
                  'APPLIED' => PillTone.amber,
                  _ => PillTone.grey,
                },
              ),
            ],
          ),
          MetaLine(icon: LucideIcons.users, text: 'Applied as ${e.role.label.toLowerCase()}'),
          if (e.decisionNote != null && e.decisionNote!.isNotEmpty)
            MetaLine(icon: LucideIcons.info, text: e.decisionNote!),
          ActionWrap(
            children: [
              if (p != null && onOpenProgramme != null)
                QuietButton(label: 'Open programme', onPressed: () => onOpenProgramme!(p.slug)),
              if (e.status == 'APPLIED' || e.status == 'ACCEPTED')
                QuietButton(
                  label: 'Withdraw',
                  danger: true,
                  onPressed: () => _report(context, () => book.withdrawEnrolment(e), done: 'Application withdrawn.'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeatCard extends StatelessWidget {
  const _SeatCard({required this.book, required this.session, this.onOpenGroup});

  final PurchasesBook book;
  final GroupSession session;
  final ValueChanged<String>? onOpenGroup;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return MentoringCard(
      key: ValueKey('seat-${s.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(s.title, style: MentoringText.cardTitle)),
              StatusPill(
                s.myStatus == 'WAITLISTED' ? 'Waitlisted' : 'Seat held',
                tone: s.myStatus == 'WAITLISTED' ? PillTone.amber : PillTone.mint,
              ),
            ],
          ),
          MetaLine(
            icon: LucideIcons.calendarClock,
            text: '${whenLabel(s.scheduledAt)} (${daysFromNow(s.scheduledAt)})',
          ),
          MetaLine(
            icon: LucideIcons.user,
            text: 'Hosted by ${s.host.name} · ${minutesLabel(s.durationMin)} · ${modeLabel(s.mode)}',
          ),
          ActionWrap(
            children: [
              if (onOpenGroup != null) SolidButton(label: 'Open session', onPressed: () => onOpenGroup!(s.id)),
              if (!s.paid)
                QuietButton(
                  label: 'Give up seat',
                  danger: true,
                  onPressed: () => _report(context, () => book.leaveSeat(s), done: 'You gave up your seat.'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
