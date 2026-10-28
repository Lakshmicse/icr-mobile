import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../mentorship_my/mentoring_format.dart';
import '../mentorship_my/mentoring_links.dart';
import '../mentorship_my/mentoring_models.dart';
import '../mentorship_my/widgets/blocks.dart';
import '../mentorship_my/widgets/forms.dart';
import '../mentorship_my/widgets/kit.dart';
import 'desk_forms.dart';
import 'mentor_desk_controller.dart';
import 'mentor_desk_models.dart';

/// Paid work: what the mentor owes (problems to answer, calls to confirm held, moves asked of them), the calls
/// still ahead, what waits on someone else, and the programmes and plans running.
class DeskWorkTab extends StatelessWidget {
  const DeskWorkTab({super.key, required this.controller, required this.links, required this.onOpenPairing});

  final MentorDeskController controller;
  final MentorshipLinks links;
  final ValueChanged<String> onOpenPairing;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final loading = (!c.sold.loaded && c.sold.loading) || (!c.terms.loaded && c.terms.loading);
    final failed = !c.sold.loaded && !c.terms.loaded ? (c.sold.error ?? c.terms.error) : null;
    final needs = c.issues.length + c.endedCalls.length + c.moveRequests.length;
    final upcoming = c.upcomingCalls;
    final waiting = c.waiting;
    final active = c.activeTerms;
    final children = <Widget>[
      if (needs == 0 && upcoming.isEmpty && waiting.isEmpty && active.isEmpty)
        const EmptyNote(
          icon: LucideIcons.briefcase,
          compact: true,
          title: 'No paid work right now',
          body: 'Calls, programmes and plans people buy from you show up here.',
        ),
      if (needs > 0) ...[
        const GroupLabel('Needs you', top: 0),
        for (final r in c.issues) _IssueCard(controller: c, links: links, row: r),
        for (final r in c.endedCalls) _EndedCallCard(controller: c, links: links, row: r),
        for (final r in c.moveRequests) _MoveAskedCard(controller: c, links: links, row: r),
      ],
      if (upcoming.isNotEmpty) ...[
        GroupLabel('Calls ahead', top: needs > 0 ? 12 : 0),
        for (final r in upcoming) _CallCard(controller: c, links: links, row: r),
      ],
      if (waiting.isNotEmpty) ...[
        const GroupLabel('Waiting on others', top: 12),
        for (final r in waiting) _WaitingCard(controller: c, row: r),
      ],
      if (active.isNotEmpty) ...[
        const GroupLabel('Programmes and plans running', top: 12),
        for (final t in active) _TermCard(term: t, onOpenPairing: onOpenPairing),
      ],
    ];
    return LoadedList(
      loading: loading,
      error: failed,
      errorTitle: "Couldn't load your paid work",
      onRefresh: () => controller.refreshTab(DeskTab.work),
      children: loading || failed != null ? const [] : children,
    );
  }
}

Widget _buyerRow(SoldRow r, {Widget? trailing, String? subline}) {
  final b = r.purchase.buyer;
  return b == null ? const SizedBox.shrink() : PersonRow(person: b, subline: subline, trailing: trailing);
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.controller, required this.links, required this.row});

  final MentorDeskController controller;
  final MentorshipLinks links;
  final SoldRow row;

  @override
  Widget build(BuildContext context) {
    final p = row.purchase;
    return MentoringCard(
      key: ValueKey('issue-${row.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buyerRow(row, trailing: const StatusPill('Problem reported', tone: PillTone.red)),
          const SizedBox(height: 8),
          Text(p.title, style: MentoringText.cardTitle),
          if (row.issueReportedAt != null)
            MetaLine(icon: LucideIcons.triangleAlert, text: 'Reported ${dayLabel(row.issueReportedAt!)}'),
          if (row.issueNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('"${row.issueNote}"', style: MentoringText.quote),
            ),
          if (row.issueRespondedAt != null)
            Callout(
              tone: PillTone.mint,
              text:
                  'You replied ${dayLabel(row.issueRespondedAt!)}${row.issueResponseNote == null ? '' : ': ${row.issueResponseNote}'}',
            ),
          ActionWrap(
            children: [
              SolidButton(
                label: row.issueRespondedAt != null ? 'Reply again' : 'Reply',
                onPressed: () => showTextSheet(
                  context,
                  title: 'Reply to ${buyerName(row)}',
                  subtitle: 'Both ${buyerName(row)} and ICR read it.',
                  label: 'Your reply',
                  hint: 'I am sorry about that. I have moved the call to...',
                  submitLabel: 'Send reply',
                  minLength: minIssueReply,
                  maxLength: maxIssueReply,
                  lines: 4,
                  onSend: (note) => controller.respondIssue(row, note),
                ),
              ),
              QuietButton(
                label: 'Message',
                icon: LucideIcons.messageSquare,
                onPressed: () => links.messagePurchase(context, controller.repository.mentoring, row.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EndedCallCard extends StatelessWidget {
  const _EndedCallCard({required this.controller, required this.links, required this.row});

  final MentorDeskController controller;
  final MentorshipLinks links;
  final SoldRow row;

  @override
  Widget build(BuildContext context) {
    final b = row.purchase.booking!;
    return MentoringCard(
      key: ValueKey('ended-${row.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buyerRow(row, trailing: const StatusPill('Confirm held', tone: PillTone.amber)),
          const SizedBox(height: 8),
          Text(row.purchase.title, style: MentoringText.cardTitle),
          MetaLine(
            icon: LucideIcons.calendarClock,
            text:
                '${whenLabel(b.scheduledAt)} · ${minutesLabel(b.durationMin)} · ended ${daysFromNow(b.scheduledAt, now: controller.now)}',
          ),
          const MetaLine(
            icon: LucideIcons.info,
            text:
                'ICR settles an unclosed call as held a day after it ends. Confirm it, or cancel if it did not happen.',
          ),
          ActionWrap(
            children: [
              SolidButton(
                label: 'Mark held',
                icon: LucideIcons.circleCheck,
                onPressed: () async {
                  final refusal = await controller.completeCall(row);
                  if (context.mounted) showMessage(context, refusal ?? 'Marked as held.');
                },
              ),
              QuietButton(label: 'Cancel call', danger: true, onPressed: () => _cancel(context, controller, row)),
              QuietButton(
                label: 'Message',
                icon: LucideIcons.messageSquare,
                onPressed: () => links.messagePurchase(context, controller.repository.mentoring, row.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _cancel(BuildContext context, MentorDeskController c, SoldRow row) => showTextSheet(
  context,
  title: 'Cancel this call?',
  subtitle: '${whenLabel(row.purchase.booking!.scheduledAt)}. ${buyerName(row)} is told, with your reason.',
  label: 'Reason',
  hint: 'Something came up at work',
  submitLabel: 'Cancel call',
  minLength: 5,
  maxLength: 500,
  danger: true,
  onSend: (reason) => c.cancelCall(row, reason),
);

class _MoveAskedCard extends StatelessWidget {
  const _MoveAskedCard({required this.controller, required this.links, required this.row});

  final MentorDeskController controller;
  final MentorshipLinks links;
  final SoldRow row;

  @override
  Widget build(BuildContext context) {
    final b = row.purchase.booking!;
    return MentoringCard(
      key: ValueKey('move-${row.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buyerRow(row, trailing: const StatusPill('Asks to move', tone: PillTone.amber)),
          const SizedBox(height: 8),
          Text(row.purchase.title, style: MentoringText.cardTitle),
          MetaLine(icon: LucideIcons.calendarClock, text: 'Booked: ${whenLabel(b.scheduledAt)}'),
          MetaLine(
            icon: LucideIcons.calendarArrowDown,
            text: 'They ask for: ${whenLabel(b.proposedAt!)}',
            color: MentoringColors.mintInk,
          ),
          if (b.proposedNote != null && b.proposedNote!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('"${b.proposedNote}"', style: MentoringText.quote),
            ),
          ActionWrap(
            children: [
              SolidButton(
                label: 'Accept new time',
                icon: LucideIcons.check,
                onPressed: () async {
                  final refusal = await controller.answerMove(row, accept: true);
                  if (context.mounted) showMessage(context, refusal ?? 'Moved to the new time.');
                },
              ),
              QuietButton(
                label: 'Offer another time',
                onPressed: () async {
                  final sent = await showFormSheet(context, (_) => ProposeMoveForm(controller: controller, row: row));
                  if (sent && context.mounted) {
                    showMessage(context, 'Sent. The call stays as booked until they accept.');
                  }
                },
              ),
              QuietButton(
                label: 'Keep the booked time',
                onPressed: () async {
                  final refusal = await controller.answerMove(row, accept: false);
                  if (context.mounted) showMessage(context, refusal ?? 'Kept the booked time.');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CallCard extends StatelessWidget {
  const _CallCard({required this.controller, required this.links, required this.row});

  final MentorDeskController controller;
  final MentorshipLinks links;
  final SoldRow row;

  @override
  Widget build(BuildContext context) {
    final b = row.purchase.booking!;
    final link = meetingUri(b.meetingLink);
    return MentoringCard(
      key: ValueKey('call-${row.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buyerRow(
            row,
            trailing: StatusPill(daysFromNow(b.scheduledAt, now: controller.now), tone: PillTone.mint),
          ),
          const SizedBox(height: 8),
          Text(row.purchase.title, style: MentoringText.cardTitle),
          MetaLine(
            icon: LucideIcons.calendarClock,
            text: '${whenLabel(b.scheduledAt)} · ${minutesLabel(b.durationMin)} · ${modeLabel(b.mode)}',
          ),
          MetaLine(
            icon: LucideIcons.indianRupee,
            text:
                '${moneyLabel(row.purchase.pricePaisa)}${row.purchase.netPaisa == null || row.purchase.pricePaisa == 0 ? '' : ' (you earn ${moneyLabel(row.purchase.netPaisa!)})'}',
          ),
          if (link == null)
            const MetaLine(icon: LucideIcons.link, text: 'No meeting link yet', color: AppColors.outline),
          ActionWrap(
            children: [
              if (link != null)
                SolidButton(label: 'Join', icon: LucideIcons.video, onPressed: () => openUrl(context, link)),
              QuietButton(
                label: 'Meeting link',
                icon: LucideIcons.link,
                onPressed: () async {
                  final sent = await showFormSheet(context, (_) => CallLinkForm(controller: controller, row: row));
                  if (sent && context.mounted) showMessage(context, 'Link saved.');
                },
              ),
              QuietButton(
                label: 'Offer another time',
                onPressed: () async {
                  final sent = await showFormSheet(context, (_) => ProposeMoveForm(controller: controller, row: row));
                  if (sent && context.mounted) {
                    showMessage(context, 'Sent. The call stays as booked until they accept.');
                  }
                },
              ),
              QuietButton(label: 'Cancel', danger: true, onPressed: () => _cancel(context, controller, row)),
              QuietButton(
                label: 'Message',
                icon: LucideIcons.messageSquare,
                onPressed: () => links.messagePurchase(context, controller.repository.mentoring, row.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({required this.controller, required this.row});

  final MentorDeskController controller;
  final SoldRow row;

  @override
  Widget build(BuildContext context) {
    final p = row.purchase;
    final b = p.booking;
    final moved = row.moveAskedByMentor;
    return MentoringCard(
      key: ValueKey('waiting-${row.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buyerRow(
            row,
            trailing: StatusPill(moved ? 'New time asked' : (row.timeHeld ? 'Awaiting answer' : 'Payment due')),
          ),
          const SizedBox(height: 8),
          Text(p.title, style: MentoringText.cardTitle),
          if (moved && b != null) ...[
            MetaLine(icon: LucideIcons.calendarClock, text: 'Booked: ${whenLabel(b.scheduledAt)}'),
            MetaLine(icon: LucideIcons.calendarArrowDown, text: 'You offered: ${whenLabel(b.proposedAt!)}'),
            ActionWrap(
              children: [
                QuietButton(
                  label: 'Withdraw the offer',
                  onPressed: () async {
                    final refusal = await controller.answerMove(row, accept: false);
                    if (context.mounted) showMessage(context, refusal ?? 'Offer withdrawn.');
                  },
                ),
              ],
            ),
          ] else if (row.timeHeld)
            MetaLine(
              icon: LucideIcons.hourglass,
              text:
                  'You set ${p.request?.scheduledAt == null ? 'a time' : whenLabel(p.request!.scheduledAt!)}; they accept and pay.',
            )
          else
            const MetaLine(icon: LucideIcons.hourglass, text: 'The call is done; the buyer has not paid yet.'),
        ],
      ),
    );
  }
}

class _TermCard extends StatelessWidget {
  const _TermCard({required this.term, required this.onOpenPairing});

  final PlanTerm term;
  final ValueChanged<String> onOpenPairing;

  @override
  Widget build(BuildContext context) {
    final t = term;
    return MentoringCard(
      key: ValueKey('running-${t.id}'),
      onTap: t.mentorshipId == null ? null : () => onOpenPairing(t.mentorshipId!),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (t.counterpart != null)
            PersonRow(
              person: t.counterpart!,
              trailing: StatusPill(t.statusLabel, tone: PillTone.mint),
            ),
          const SizedBox(height: 8),
          Text(t.title, style: MentoringText.cardTitle),
          MetaLine(
            icon: LucideIcons.layers,
            text:
                '${sessionsLeft(t.sessionsLeft, t.sessionsAllowance)}${t.periodEnd == null ? '' : ' · runs to ${dayLabel(t.periodEnd!)}'}',
          ),
          if (t.programme && t.steps.isNotEmpty)
            MetaLine(
              icon: LucideIcons.listChecks,
              text: '${t.steps.where((s) => s.done).length} of ${t.steps.length} programme sessions held',
            ),
          if (t.mentorshipId != null)
            ActionWrap(
              children: [QuietButton(label: 'Open mentorship', onPressed: () => onOpenPairing(t.mentorshipId!))],
            ),
        ],
      ),
    );
  }
}
