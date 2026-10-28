import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import 'mentoring_format.dart';
import 'mentoring_links.dart';
import 'mentoring_models.dart';
import 'my_mentoring_controller.dart';
import 'widgets/blocks.dart';
import 'widgets/intent_form.dart';
import 'widgets/kit.dart';
import 'widgets/month_grid.dart';
import 'widgets/request_sheets.dart';
import 'mentoring_clock.dart';

/// A mentor answers a request: [accept] pairs them, otherwise it is declined
/// with a note. The sheet stays open, with what was typed, on a refusal.
Future<void> respondToRequest(
  BuildContext context,
  MyMentoringController c,
  MentoringRequest r, {
  required bool accept,
}) async {
  final bool sent;
  if (accept) {
    sent = await showAcceptRequestSheet(
      context,
      request: r,
      onSend: (note, cadence) => c.respond(r, accept: true, note: note, cadence: cadence),
    );
  } else {
    sent = await showDeclineRequestSheet(
      context,
      request: r,
      onSend: (note) => c.respond(r, accept: false, note: note),
    );
  }
  if (sent && context.mounted) {
    showMessage(
      context,
      accept ? 'You are now ${r.mentee.firstName}\'s mentor.' : 'Declined. ${r.mentee.firstName} has been told.',
    );
  }
}

// ---------------------------------------------------------------------------
// Requests
// ---------------------------------------------------------------------------

/// Requests, from the side they arrived on: what is asked of the member as a
/// mentor (answer it here), and what they asked of others (withdraw it).
class RequestsTab extends StatelessWidget {
  const RequestsTab({super.key, required this.controller, required this.links});

  final MyMentoringController controller;
  final MentorshipLinks links;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final loading = (!c.sent.loaded && c.sent.loading) || (!c.received.loaded && c.received.loading);
    final failed = !c.sent.loaded && !c.received.loaded ? (c.sent.error ?? c.received.error) : null;
    final received = [...?c.received.data]..sort(_pendingFirst);
    final sent = [...?c.sent.data]..sort(_pendingFirst);
    final quota = c.quota.data;
    final children = <Widget>[
      if (c.actsAsMentor) ...[
        const GroupLabel('Asked of you', top: 0),
        if (received.isEmpty)
          const EmptyNote(
            icon: LucideIcons.inbox,
            compact: true,
            title: 'No requests yet',
            body: 'When a member asks you to mentor them, it lands here.',
          ),
        for (final r in received)
          RequestCard(
            request: r,
            received: true,
            actions: r.status == RequestStatus.pending
                ? [
                    SolidButton(
                      label: 'Accept',
                      icon: LucideIcons.check,
                      onPressed: () => respondToRequest(context, c, r, accept: true),
                    ),
                    QuietButton(label: 'Decline', onPressed: () => respondToRequest(context, c, r, accept: false)),
                  ]
                : const [],
          ),
      ],
      if (c.actsAsMentee) ...[
        GroupLabel('Sent by you', top: c.actsAsMentor ? 14 : 0),
        if (quota != null && quota.pendingLimit != null)
          Callout(
            tone: quota.canRequest ? PillTone.blue : PillTone.amber,
            text: quota.canRequest
                ? 'You have ${quota.pending} of ${quota.pendingLimit} open requests on your plan.'
                : 'You have used all ${quota.pendingLimit} open requests on your plan. Withdraw one or wait for a reply.',
          ),
        if (sent.isEmpty)
          EmptyNote(
            icon: LucideIcons.send,
            compact: true,
            title: 'You have not asked anyone yet',
            body: 'Find a mentor whose experience fits and send a request.',
            action: 'Find a mentor',
            onAction: () => links.directory(context),
          ),
        for (final r in sent)
          RequestCard(
            request: r,
            received: false,
            actions: [
              if (r.status == RequestStatus.pending) ...[
                QuietButton(
                  label: 'View profile',
                  onPressed: r.mentorProfileId.isEmpty ? null : () => links.mentor(context, r.mentorProfileId),
                ),
                QuietButton(label: 'Withdraw', danger: true, onPressed: () => _withdraw(context, r)),
              ] else if (r.status != RequestStatus.accepted)
                QuietButton(label: 'Find similar mentors', onPressed: () => links.directory(context)),
            ],
          ),
      ],
    ];
    return LoadedList(
      loading: loading,
      error: failed,
      errorTitle: "Couldn't load your requests",
      onRefresh: () => c.refreshTab(MyTab.requests),
      children: loading || failed != null ? const [] : children,
    );
  }

  static int _pendingFirst(MentoringRequest a, MentoringRequest b) {
    final ap = a.status == RequestStatus.pending ? 0 : 1;
    final bp = b.status == RequestStatus.pending ? 0 : 1;
    return ap != bp ? ap - bp : b.createdAt.compareTo(a.createdAt);
  }

  Future<void> _withdraw(BuildContext context, MentoringRequest r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Withdraw this request?'),
        content: Text('${r.mentor.firstName} will no longer see it. You can ask again later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Withdraw')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final refusal = await controller.withdrawRequest(r);
    if (context.mounted) showMessage(context, refusal ?? 'Request withdrawn.');
  }
}

// ---------------------------------------------------------------------------
// Calendar
// ---------------------------------------------------------------------------

/// The month: a grid with a dot on every day that holds a mentoring session, a
/// paid call or a group session, and the picked day's agenda under it.
class CalendarTab extends StatefulWidget {
  const CalendarTab({
    super.key,
    required this.controller,
    required this.links,
    required this.onRefresh,
    this.onOpenPairing,
    this.onOpenPurchase,
    this.onOpenGroup,
    this.now,
  });

  final MyMentoringController controller;
  final MentorshipLinks links;
  final Future<void> Function() onRefresh;
  final ValueChanged<String>? onOpenPairing;
  final ValueChanged<String>? onOpenPurchase;
  final ValueChanged<String>? onOpenGroup;

  /// A seam for tests.
  final DateTime? now;

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  late DateTime _selected = _today;

  DateTime get _today {
    final n = widget.now ?? mentoringNow();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final month = c.month;
    final items = c.calendar.data ?? const <CalendarItem>[];
    final loading = !c.calendar.loaded && c.calendar.loading;
    final failed = !c.calendar.loaded ? c.calendar.error : null;
    final marks = <int, Set<CalendarKind>>{};
    for (final i in items) {
      final at = i.at.toLocal();
      if (at.year == month.year && at.month == month.month && i.status != 'CANCELLED') {
        marks.putIfAbsent(at.day, () => {}).add(i.kind);
      }
    }
    // The picked day follows the month: keep it inside the month shown.
    final selected = (_selected.year == month.year && _selected.month == month.month)
        ? _selected
        : (_today.year == month.year && _today.month == month.month ? _today : month);
    final dayItems = [
      for (final i in items)
        if (_sameDay(i.at.toLocal(), selected)) i,
    ];
    final children = <Widget>[
      MonthGrid(
        month: month,
        selected: selected,
        marks: marks,
        today: widget.now,
        onSelect: (d) => setState(() => _selected = d),
        onPrevious: () => _go(c.previousMonth),
        onNext: () => _go(c.nextMonth),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          for (final (kind, label) in const [
            (CalendarKind.session, 'Mentoring'),
            (CalendarKind.booking, 'Paid call'),
            (CalendarKind.group, 'Group session'),
          ])
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: MonthGrid.kindColor(kind), shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(label, style: MentoringText.meta),
              ],
            ),
        ],
      ),
      SectionTitle(title: dayHeading(selected, now: widget.now), top: 16),
      if (c.calendar.error != null && c.calendar.loaded)
        Callout(tone: PillTone.amber, text: 'Could not refresh this month: ${c.calendar.error}'),
      if (dayItems.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Nothing on this day.', style: MentoringText.body),
        ),
      for (final i in dayItems) _CalendarRow(item: i, onTap: () => _open(context, i)),
    ];
    return LoadedList(
      loading: loading,
      error: failed,
      errorTitle: "Couldn't load your calendar",
      onRefresh: widget.onRefresh,
      children: loading || failed != null ? const [] : children,
    );
  }

  Future<void> _go(Future<void> Function() move) async {
    await move();
    if (!mounted) return;
    final month = widget.controller.month;
    setState(() => _selected = _today.year == month.year && _today.month == month.month ? _today : month);
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  void _open(BuildContext context, CalendarItem item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (sheet) => CalendarItemSheet(
        item: item,
        onOpenPairing: item.mentorshipId == null || widget.onOpenPairing == null
            ? null
            : () {
                Navigator.pop(sheet);
                widget.onOpenPairing!(item.mentorshipId!);
              },
        onOpenPurchase: item.purchaseId == null || widget.onOpenPurchase == null
            ? null
            : () {
                Navigator.pop(sheet);
                widget.onOpenPurchase!(item.purchaseId!);
              },
        onOpenGroup: item.kind != CalendarKind.group || widget.onOpenGroup == null
            ? null
            : () {
                Navigator.pop(sheet);
                widget.onOpenGroup!(item.id);
              },
      ),
    );
  }
}

class _CalendarRow extends StatelessWidget {
  const _CalendarRow({required this.item, required this.onTap});

  final CalendarItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final i = item;
    final cancelled = i.status == 'CANCELLED';
    return MentoringCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(color: MonthGrid.kindColor(i.kind), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MentoringText.cardTitle.copyWith(decoration: cancelled ? TextDecoration.lineThrough : null),
                ),
                const SizedBox(height: 2),
                Text(
                  '${spanLabel(i.at, i.durationMin)}'
                  '${i.counterpartName == null ? '' : ' · ${i.counterpartName}'}',
                  style: MentoringText.meta,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusPill(
            _statusWord(i),
            tone: cancelled
                ? PillTone.grey
                : i.status == 'REQUESTED'
                ? PillTone.amber
                : i.status == 'COMPLETED'
                ? PillTone.blue
                : PillTone.mint,
          ),
        ],
      ),
    );
  }
}

String _statusWord(CalendarItem i) => switch (i.status) {
  'REQUESTED' => 'Awaiting',
  'COMPLETED' => 'Held',
  'CANCELLED' => 'Cancelled',
  'NO_SHOW' => 'No-show',
  'CONFIRMED' || 'PAID' || 'SCHEDULED' => i.kind == CalendarKind.group ? 'Going' : 'Booked',
  _ => 'Booked',
};

/// One calendar entry in full: when, with whom, how, and the buttons that fit.
class CalendarItemSheet extends StatelessWidget {
  const CalendarItemSheet({super.key, required this.item, this.onOpenPairing, this.onOpenPurchase, this.onOpenGroup});

  final CalendarItem item;
  final VoidCallback? onOpenPairing;
  final VoidCallback? onOpenPurchase;
  final VoidCallback? onOpenGroup;

  @override
  Widget build(BuildContext context) {
    final i = item;
    final link = meetingUri(i.meetingLink);
    final kind = switch (i.kind) {
      CalendarKind.session => 'Mentoring session',
      CalendarKind.booking => 'Paid call',
      CalendarKind.group => 'Group session',
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kind.toUpperCase(), style: MentoringText.pill.copyWith(color: AppColors.outline, letterSpacing: 0.8)),
            const SizedBox(height: 4),
            Text(i.title, style: MentoringText.hero),
            MetaLine(icon: LucideIcons.calendarClock, text: '${whenLabel(i.at)} (${daysFromNow(i.at)})'),
            MetaLine(
              icon: LucideIcons.clock,
              text: '${minutesLabel(i.durationMin)}${i.mode == null ? '' : ' · ${modeLabel(i.mode!)}'}',
            ),
            if (i.counterpartName != null)
              MetaLine(
                icon: LucideIcons.user,
                text: i.kind == CalendarKind.group ? 'Hosted by ${i.counterpartName}' : 'With ${i.counterpartName}',
              ),
            MetaLine(icon: LucideIcons.info, text: _statusWord(i)),
            ActionWrap(
              top: 14,
              children: [
                if (link != null && i.open)
                  SolidButton(label: 'Join', icon: LucideIcons.video, onPressed: () => openUrl(context, link)),
                if (onOpenPairing != null) QuietButton(label: 'Open mentorship', onPressed: onOpenPairing),
                if (onOpenPurchase != null) QuietButton(label: 'Open booking', onPressed: onOpenPurchase),
                if (onOpenGroup != null) QuietButton(label: 'Open session', onPressed: onOpenGroup),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Goals
// ---------------------------------------------------------------------------

/// "What you want from mentoring" (the mentee's own intent, which mentors read
/// before they answer) over the goals across every live pairing.
class GoalsTab extends StatelessWidget {
  const GoalsTab({super.key, required this.controller, required this.onOpenPairing});

  final MyMentoringController controller;
  final ValueChanged<String> onOpenPairing;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final loading = (!c.goals.loaded && c.goals.loading) || (!c.intent.loaded && c.intent.loading);
    final failed = !c.goals.loaded && !c.intent.loaded ? (c.goals.error ?? c.intent.error) : null;
    final intent = c.intent.data;
    final goals = c.goals.data ?? const <PairingGoal>[];
    final open = goals.where((g) => g.status == GoalStatus.open).toList();
    final closed = goals.where((g) => g.status != GoalStatus.open).toList();
    final children = <Widget>[
      _IntentCard(intent: intent, onEdit: () => _editIntent(context, intent)),
      SectionTitle(title: 'Goals in your mentorships'),
      if (goals.isEmpty)
        Text(
          'No goals yet. Open a mentorship and add one: a goal is what the two of you are working towards.',
          style: MentoringText.body,
        ),
      for (final g in open) _GoalRow(goal: g, onTap: () => onOpenPairing(g.mentorshipId)),
      if (closed.isNotEmpty) ...[
        const GroupLabel('Finished or dropped'),
        for (final g in closed) _GoalRow(goal: g, onTap: () => onOpenPairing(g.mentorshipId)),
      ],
    ];
    return LoadedList(
      loading: loading,
      error: failed,
      errorTitle: "Couldn't load your goals",
      onRefresh: () => c.refreshTab(MyTab.goals),
      children: loading || failed != null ? const [] : children,
    );
  }

  Future<void> _editIntent(BuildContext context, MenteeIntent? intent) async {
    await controller.focusOptions.ensure();
    if (!context.mounted) return;
    final saved = await showIntentSheet(
      context,
      current: intent,
      focusOptions: controller.focusOptions.data ?? const [],
      onSave: controller.saveIntent,
    );
    if (saved && context.mounted) showMessage(context, 'Saved. Mentors will read this before they answer.');
  }
}

class _IntentCard extends StatelessWidget {
  const _IntentCard({required this.intent, required this.onEdit});

  final MenteeIntent? intent;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final i = intent;
    if (i == null) {
      return Callout(
        text:
            'Tell mentors what you want out of mentoring. A request needs your career stage first, and a few '
            'lines about the next step you want to take help it get answered.',
        actions: [SolidButton(label: 'Set it up', icon: LucideIcons.pencil, onPressed: onEdit)],
      );
    }
    return MentoringCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('What you want from mentoring', style: MentoringText.cardTitle)),
              StatusPill(
                i.discoverable ? 'Visible to mentors' : 'Hidden',
                tone: i.discoverable ? PillTone.mint : PillTone.grey,
              ),
            ],
          ),
          MetaLine(icon: LucideIcons.briefcase, text: careerStages[i.careerStage] ?? i.careerStage),
          if (i.goalSummary != null && i.goalSummary!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(i.goalSummary!, style: MentoringText.quote),
            ),
          if (i.focusAreas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final f in i.focusAreas) StatusPill(f, tone: PillTone.blue)],
              ),
            ),
          if (i.preferredModes.isNotEmpty || i.cadence != null)
            MetaLine(
              icon: LucideIcons.video,
              text: [
                if (i.preferredModes.isNotEmpty) i.preferredModes.map((m) => meetingModes[m] ?? m).join(', '),
                if (i.cadence != null) cadences[i.cadence] ?? i.cadence!,
              ].join(' · '),
            ),
          ActionWrap(
            children: [QuietButton(label: 'Edit', icon: LucideIcons.pencil, onPressed: onEdit)],
          ),
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal, required this.onTap});

  final PairingGoal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = goal;
    return MentoringCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(g.title, style: MentoringText.cardTitle)),
              StatusPill(
                g.status.label,
                tone: switch (g.status) {
                  GoalStatus.achieved => PillTone.mint,
                  GoalStatus.dropped => PillTone.grey,
                  GoalStatus.open => PillTone.blue,
                },
              ),
            ],
          ),
          if (g.counterpartName != null) MetaLine(icon: LucideIcons.users, text: 'With ${g.counterpartName}'),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: g.progress / 100,
              minHeight: 6,
              backgroundColor: AppColors.surfaceContainer,
              color: g.status == GoalStatus.achieved ? MentoringColors.green : AppColors.primary,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${g.progress}%${g.targetDate == null ? '' : ' · by ${dayLabel(g.targetDate!)}'}',
              style: MentoringText.meta,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Saved mentors
// ---------------------------------------------------------------------------

/// The shortlist: mentors the member bookmarked.
class SavedTab extends StatelessWidget {
  const SavedTab({super.key, required this.controller, required this.links});

  final MyMentoringController controller;
  final MentorshipLinks links;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final loading = !c.saved.loaded && c.saved.loading;
    final failed = !c.saved.loaded ? c.saved.error : null;
    final rows = c.saved.data ?? const <SavedMentor>[];
    final children = <Widget>[
      if (rows.isEmpty)
        EmptyNote(
          icon: LucideIcons.bookmark,
          title: 'Nothing saved yet',
          body: 'Save a mentor from their profile to keep a shortlist before you ask anyone. Only you see it.',
          action: 'Browse mentors',
          onAction: () => links.directory(context),
        )
      else ...[
        Text('${rows.length} saved. Only you see this list.', style: MentoringText.meta),
        const SizedBox(height: 10),
        for (final m in rows)
          MentoringCard(
            onTap: () => links.mentor(context, m.mentorProfileId),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PersonRow(person: m.person, size: 48),
                MetaLine(icon: LucideIcons.star, text: ratingLine(m.rating, m.ratingCount)),
                MetaLine(
                  icon: LucideIcons.calendarCheck,
                  text: m.openSlots > 0 ? countLabel(m.openSlots, 'open mentoring slot') : 'No open mentoring slots',
                  color: m.openSlots > 0 ? MentoringColors.mintInk : null,
                ),
                if (m.city != null) MetaLine(icon: LucideIcons.mapPin, text: m.city!),
                ActionWrap(
                  children: [
                    SolidButton(label: 'View profile', onPressed: () => links.mentor(context, m.mentorProfileId)),
                    QuietButton(
                      label: 'Remove',
                      icon: LucideIcons.bookmarkMinus,
                      onPressed: () async {
                        final refusal = await c.unsave(m);
                        if (context.mounted) {
                          showMessage(context, refusal ?? '${m.person.firstName} removed from your list.');
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    ];
    return LoadedList(
      loading: loading,
      error: failed,
      errorTitle: "Couldn't load your saved mentors",
      onRefresh: () => c.refreshTab(MyTab.saved),
      children: loading || failed != null ? const [] : children,
    );
  }
}

// ---------------------------------------------------------------------------
// Certificates
// ---------------------------------------------------------------------------

/// Certificates the member earned by finishing a mentorship or a programme.
class CertificatesTab extends StatelessWidget {
  const CertificatesTab({super.key, required this.controller, this.links});

  final MyMentoringController controller;
  final MentorshipLinks? links;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final loading = !c.certificates.loaded && c.certificates.loading;
    final failed = !c.certificates.loaded ? c.certificates.error : null;
    final rows = c.certificates.data ?? const <MentoringCertificate>[];
    final children = <Widget>[
      if (rows.isEmpty)
        const EmptyNote(
          icon: LucideIcons.award,
          title: 'No certificates yet',
          body: 'A certificate is issued when a mentorship or a programme you took part in is marked complete.',
        )
      else
        for (final cert in rows)
          MentoringCard(
            onTap: () => showCertificateSheet(context, cert, links: links),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppColors.chipEmphasis, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(LucideIcons.award, size: 22, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cert.title, style: MentoringText.cardTitle),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (cert.counterpartName != null) 'With ${cert.counterpartName}',
                          if (cert.programName != null) cert.programName!,
                          'Issued ${dayLabel(cert.issuedAt)}',
                        ].join(' · '),
                        style: MentoringText.meta,
                      ),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.outline),
              ],
            ),
          ),
    ];
    return LoadedList(
      loading: loading,
      error: failed,
      errorTitle: "Couldn't load your certificates",
      onRefresh: () => c.refreshTab(MyTab.certificates),
      children: loading || failed != null ? const [] : children,
    );
  }
}

/// A certificate in full, with the number anyone can check it by.
Future<void> showCertificateSheet(BuildContext context, MentoringCertificate cert, {MentorshipLinks? links}) {
  final site = MentorshipLinks.of(context, links);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(LucideIcons.badgeCheck, size: 28, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(cert.title, style: MentoringText.hero),
            const SizedBox(height: 4),
            Text(
              cert.kind == 'MENTOR' ? 'Awarded for mentoring' : 'Awarded for completing a mentorship',
              style: MentoringText.body,
            ),
            if (cert.counterpartName != null) MetaLine(icon: LucideIcons.users, text: 'With ${cert.counterpartName}'),
            if (cert.programName != null) MetaLine(icon: LucideIcons.layers, text: cert.programName!),
            MetaLine(
              icon: LucideIcons.clock,
              text: '${countLabel(cert.sessionsCount, 'session')} · ${_hours(cert.hours)}',
            ),
            MetaLine(icon: LucideIcons.calendarDays, text: 'Issued ${dayLabel(cert.issuedAt)}'),
            MetaLine(icon: LucideIcons.hash, text: cert.certificateId),
            ActionWrap(
              top: 14,
              children: [
                SolidButton(
                  label: 'Verify online',
                  icon: LucideIcons.externalLink,
                  onPressed: () => site.openSite(sheet, '/mentorship/certificates/${cert.certificateId}'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

String _hours(double h) =>
    h == h.roundToDouble() ? '${h.round()} hr' : '${h.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '')} hr';

// ---------------------------------------------------------------------------
// Reports
// ---------------------------------------------------------------------------

/// The concerns the member raised, and what ICR told them.
class ReportsTab extends StatelessWidget {
  const ReportsTab({super.key, required this.controller, required this.onOpenPairing});

  final MyMentoringController controller;
  final ValueChanged<String> onOpenPairing;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final loading = !c.concerns.loaded && c.concerns.loading;
    final failed = !c.concerns.loaded ? c.concerns.error : null;
    final rows = c.concerns.data ?? const <MentoringConcern>[];
    final children = <Widget>[
      if (rows.isEmpty)
        const EmptyNote(
          icon: LucideIcons.flag,
          title: 'No reports',
          body: 'You have not raised a concern. You can from any mentorship: it goes to ICR, not to the other person.',
        )
      else
        for (final r in rows)
          MentoringCard(
            onTap: r.mentorshipId == null ? null : () => onOpenPairing(r.mentorshipId!),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(r.category.label, style: MentoringText.cardTitle)),
                    if (r.urgent) ...[const StatusPill('Urgent', tone: PillTone.red), const SizedBox(width: 6)],
                    StatusPill(r.statusLabel, tone: r.closed ? PillTone.grey : PillTone.blue),
                  ],
                ),
                MetaLine(icon: LucideIcons.calendarDays, text: 'Raised ${dayLabel(r.createdAt)}'),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(r.detail, style: MentoringText.body),
                ),
                if (r.outcomeNote != null)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FROM ICR',
                          style: MentoringText.pill.copyWith(color: AppColors.outline, letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 3),
                        Text(r.outcomeNote!, style: MentoringText.body),
                      ],
                    ),
                  ),
              ],
            ),
          ),
    ];
    return LoadedList(
      loading: loading,
      error: failed,
      errorTitle: "Couldn't load your reports",
      onRefresh: () => c.refreshTab(MyTab.reports),
      children: loading || failed != null ? const [] : children,
    );
  }
}
