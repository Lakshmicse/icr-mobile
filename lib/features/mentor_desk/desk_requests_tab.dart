import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/util/links.dart';
import '../mentorship_my/mentoring_format.dart';
import '../mentorship_my/mentoring_links.dart';
import '../mentorship_my/mentoring_models.dart';
import '../mentorship_my/my_mentoring_tabs.dart' show respondToRequest;
import '../mentorship_my/widgets/blocks.dart';
import '../mentorship_my/widgets/forms.dart';
import '../mentorship_my/widgets/kit.dart';
import 'desk_forms.dart';
import 'mentor_desk_controller.dart';
import 'mentor_desk_models.dart';

/// What is asked of the mentor: free mentoring requests (accept or decline), sessions asked for (accept by
/// setting a time, or decline), and programme or plan requests (accept or decline).
class DeskRequestsTab extends StatelessWidget {
  const DeskRequestsTab({super.key, required this.controller, required this.links});

  final MentorDeskController controller;
  final MentorshipLinks links;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final m = c.mentoring;
    final loading =
        (!m.received.loaded && m.received.loading) ||
        (!c.sold.loaded && c.sold.loading) ||
        (!c.terms.loaded && c.terms.loading);
    final failed = !m.received.loaded && !c.sold.loaded && !c.terms.loaded
        ? (m.received.error ?? c.sold.error ?? c.terms.error)
        : null;
    final all = [...?m.received.data]
      ..sort((a, b) {
        final ap = a.status == RequestStatus.pending ? 0 : 1;
        final bp = b.status == RequestStatus.pending ? 0 : 1;
        return ap != bp ? ap - bp : b.createdAt.compareTo(a.createdAt);
      });
    final pending = all.where((r) => r.status == RequestStatus.pending).toList();
    final answered = all.where((r) => r.status != RequestStatus.pending).take(5).toList();
    final empty =
        pending.isEmpty &&
        c.sessionRequests.isEmpty &&
        c.heldTimes.isEmpty &&
        c.programmeRequests.isEmpty &&
        c.unpaidTerms.isEmpty;
    final children = <Widget>[
      if (empty && answered.isEmpty)
        const EmptyNote(
          icon: LucideIcons.inbox,
          compact: true,
          title: 'Nothing Needs Your Attention',
          body: 'Mentoring requests, session requests and programme requests will appear here.',
        ),
      if (pending.isNotEmpty) ...[
        const GroupLabel('Mentoring Requests', top: 0),
        for (final r in pending)
          RequestCard(
            request: r,
            received: true,
            actions: [
              SolidButton(
                label: 'Accept',
                icon: LucideIcons.check,
                onPressed: () => respondToRequest(context, m, r, accept: true),
              ),
              QuietButton(label: 'Decline', onPressed: () => respondToRequest(context, m, r, accept: false)),
            ],
          ),
      ],
      if (c.sessionRequests.isNotEmpty) ...[
        GroupLabel('Session Requests', top: pending.isEmpty ? 0 : 12),
        for (final r in c.sessionRequests) _SessionRequestCard(controller: c, links: links, row: r),
      ],
      if (c.heldTimes.isNotEmpty) ...[
        const GroupLabel('Waiting for the Mentee', top: 12),
        for (final r in c.heldTimes) _HeldTimeCard(controller: c, links: links, row: r),
      ],
      if (c.programmeRequests.isNotEmpty) ...[
        const GroupLabel('Programme and Plan Requests', top: 12),
        for (final t in c.programmeRequests) _TermRequestCard(controller: c, term: t),
      ],
      if (c.unpaidTerms.isNotEmpty) ...[
        const GroupLabel('Accepted, Awaiting Payment', top: 12),
        for (final t in c.unpaidTerms)
          MentoringCard(
            key: ValueKey('unpaid-${t.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(t.title, style: MentoringText.cardTitle)),
                    const StatusPill('Payment Due', tone: PillTone.amber),
                  ],
                ),
                if (t.counterpart != null)
                  MetaLine(icon: LucideIcons.user, text: '${t.counterpart!.name} · ${moneyLabel(t.totalPaisa)}'),
                const MetaLine(
                  icon: LucideIcons.hourglass,
                  text: 'They pay on the website. The mentorship starts when they pay.',
                ),
              ],
            ),
          ),
      ],
      if (answered.isNotEmpty) ...[
        GroupLabel('Recently Answered', top: empty ? 0 : 12),
        for (final r in answered) RequestCard(request: r, received: true),
      ],
    ];
    return LoadedList(
      loading: loading,
      error: failed,
      errorTitle: 'Unable to Load Your Requests',
      onRefresh: () => controller.refreshTab(DeskTab.requests),
      children: loading || failed != null ? const [] : children,
    );
  }
}

class _SessionRequestCard extends StatelessWidget {
  const _SessionRequestCard({required this.controller, required this.links, required this.row});

  final MentorDeskController controller;
  final MentorshipLinks links;
  final SoldRow row;

  @override
  Widget build(BuildContext context) {
    final p = row.purchase;
    final req = p.request!;
    final buyer = p.buyer;
    return MentoringCard(
      key: ValueKey('sreq-${row.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (buyer != null)
            PersonRow(
              person: buyer,
              subline: 'asked ${dayLabel(p.createdAt, now: controller.now)}',
              trailing: const StatusPill('Awaiting Your Reply', tone: PillTone.amber),
            ),
          const SizedBox(height: 8),
          Text(p.title, style: MentoringText.cardTitle),
          MetaLine(
            icon: LucideIcons.clock,
            text:
                '${minutesLabel(req.durationMin ?? 30)}${req.mode == null ? '' : ' · ${modeLabel(req.mode!)}'} · ${moneyLabel(p.duePaisa)}',
          ),
          if (req.topic.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('"${req.topic}"', style: MentoringText.quote),
            ),
          if (req.preferredTimes != null)
            MetaLine(icon: LucideIcons.calendarClock, text: 'Preferred times: ${req.preferredTimes}'),
          if (row.timeDeclinedAt != null && req.timeDeclineNote != null)
            Callout(
              tone: PillTone.grey,
              text: 'Asked for another time (${dayLabel(row.timeDeclinedAt!)}): ${req.timeDeclineNote}',
            ),
          ActionWrap(
            children: [
              SolidButton(
                label: 'Accept and Set Time',
                icon: LucideIcons.calendarCheck,
                onPressed: () async {
                  final sent = await showFormSheet(context, (_) => AcceptSessionForm(controller: controller, row: row));
                  if (sent && context.mounted) {
                    showMessage(
                      context,
                      p.duePaisa == 0
                          ? 'Booked. ${buyerName(row)} has been notified.'
                          : 'Time set. ${buyerName(row)} confirms it and pays.',
                    );
                  }
                },
              ),
              QuietButton(
                label: 'Message',
                icon: LucideIcons.messageSquare,
                onPressed: () => links.messagePurchase(context, controller.repository.mentoring, row.id),
              ),
              QuietButton(
                label: 'Decline',
                danger: true,
                onPressed: () => showTextSheet(
                  context,
                  title: 'Decline This Request?',
                  subtitle: '${buyerName(row)} reads your reason as written.',
                  label: 'Reason',
                  hint: 'I am not taking new sessions this month',
                  submitLabel: 'Decline Request',
                  minLength: minDeclineReason,
                  maxLength: maxDeclineReason,
                  danger: true,
                  onSend: (reason) => controller.declineSession(row, reason),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeldTimeCard extends StatelessWidget {
  const _HeldTimeCard({required this.controller, required this.links, required this.row});

  final MentorDeskController controller;
  final MentorshipLinks links;
  final SoldRow row;

  @override
  Widget build(BuildContext context) {
    final p = row.purchase;
    final req = p.request!;
    return MentoringCard(
      key: ValueKey('held-${row.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.buyer != null) PersonRow(person: p.buyer!, trailing: const StatusPill('Awaiting Answer')),
          const SizedBox(height: 8),
          Text(p.title, style: MentoringText.cardTitle),
          if (req.scheduledAt != null) MetaLine(icon: LucideIcons.calendarClock, text: whenLabel(req.scheduledAt!)),
          if (req.payBy != null) MetaLine(icon: LucideIcons.hourglass, text: 'They answer by ${whenLabel(req.payBy!)}'),
          ActionWrap(
            children: [
              QuietButton(
                label: 'Message',
                icon: LucideIcons.messageSquare,
                onPressed: () => links.messagePurchase(context, controller.repository.mentoring, row.id),
              ),
              if (p.status == PurchaseStatus.accepted)
                QuietButton(
                  label: 'Withdraw This Time',
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (dialog) => AlertDialog(
                        title: const Text('Withdraw This Time?'),
                        content: Text(
                          'The request is cancelled and ${buyerName(row)} is notified. '
                          'The time you held is free again, and they can ask again.',
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Keep It')),
                          TextButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Withdraw')),
                        ],
                      ),
                    );
                    if (ok != true || !context.mounted) return;
                    final refusal = await controller.withdrawHeld(row);
                    if (context.mounted) showMessage(context, refusal ?? 'Request withdrawn.');
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TermRequestCard extends StatelessWidget {
  const _TermRequestCard({required this.controller, required this.term});

  final MentorDeskController controller;
  final PlanTerm term;

  @override
  Widget build(BuildContext context) {
    final t = term;
    return MentoringCard(
      key: ValueKey('term-${t.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (t.counterpart != null)
            PersonRow(
              person: t.counterpart!,
              subline: 'asked ${dayLabel(t.createdAt, now: controller.now)}',
              trailing: const StatusPill('Awaiting Your Reply', tone: PillTone.amber),
            ),
          const SizedBox(height: 8),
          Text(t.title, style: MentoringText.cardTitle),
          MetaLine(
            icon: t.programme ? LucideIcons.layers : LucideIcons.repeat,
            text:
                '${t.programme ? 'Programme' : 'Ongoing plan'} · ${countLabel(t.sessionsAllowance, 'session')} · ${moneyLabel(t.totalPaisa)}',
          ),
          const MetaLine(
            icon: LucideIcons.info,
            text: 'Accepting commits your time. They are charged only when they pay.',
          ),
          ActionWrap(
            children: [
              SolidButton(
                label: 'Accept',
                icon: LucideIcons.check,
                onPressed: () async {
                  final refusal = await controller.decideTerm(t, accept: true);
                  if (context.mounted) showMessage(context, refusal ?? 'Accepted. They can now pay to start.');
                },
              ),
              QuietButton(
                label: 'Decline',
                danger: true,
                onPressed: () => showTextSheet(
                  context,
                  title: 'Decline This Request?',
                  subtitle:
                      'They read your reason as written. A kind note helps, as they may consider another of your offerings.',
                  label: 'Reason',
                  hint: 'My programme places are full until the new year',
                  submitLabel: 'Decline Request',
                  minLength: 5,
                  maxLength: 400,
                  danger: true,
                  onSend: (reason) => controller.decideTerm(t, accept: false, reason: reason),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
