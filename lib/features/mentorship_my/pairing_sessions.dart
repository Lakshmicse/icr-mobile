import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import 'mentoring_clock.dart';
import 'mentoring_format.dart';
import 'mentoring_links.dart';
import 'mentoring_models.dart';
import 'pairing_controller.dart';
import 'pairing_forms.dart';
import 'widgets/forms.dart';
import 'widgets/kit.dart';

/// Runs an action and says what came of it: the API's refusal as a sentence, else [done].
Future<void> report(BuildContext context, Future<String?> Function() action, {String? done}) async {
  final refusal = await action();
  if (!context.mounted) return;
  if (refusal != null) {
    showMessage(context, refusal);
  } else if (done != null) {
    showMessage(context, done);
  }
}

/// The sessions of one pairing: the one that needs attention leads, live ones
/// follow (overdue, asks, upcoming), history sits behind a toggle.
class SessionsSection extends StatefulWidget {
  const SessionsSection({super.key, required this.controller, required this.links, this.featuredFirst = true});

  final PairingController controller;
  final MentorshipLinks links;
  final bool featuredFirst;

  @override
  State<SessionsSection> createState() => _SessionsSectionState();
}

class _SessionsSectionState extends State<SessionsSection> {
  bool _showPast = false;

  PairingController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    final p = c.pairing!;
    final featured = c.featured();
    final live = c.upcoming().where((s) => s.id != featured?.id).toList();
    final past = c.past();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (featured != null) ...[
          SectionTitle(title: _featuredHeading(featured), top: 6),
          SessionCard(controller: c, links: widget.links, session: featured, featured: true),
        ],
        SectionTitle(
          title: 'Sessions',
          action: c.active ? (c.isMentor ? 'Book a session' : 'Ask for a time') : null,
          onAction: () => openSessionForm(context, c, p),
          top: featured != null ? 8 : 18,
        ),
        if (!c.active && c.live)
          const Callout(tone: PillTone.amber, text: 'This mentorship is paused. Resume it to book a session.'),
        if (live.isEmpty && featured == null)
          Text(
            c.active
                ? (c.isMentor
                      ? 'Nothing booked. Book a time from your hours.'
                      : 'Nothing booked yet. Ask for a time; your mentor confirms it.')
                : 'No sessions ahead.',
            style: MentoringText.body,
          ),
        if (live.isEmpty && featured != null) Text('Nothing else is booked.', style: MentoringText.body),
        for (final s in live) SessionCard(controller: c, links: widget.links, session: s),
        if (past.isNotEmpty) ...[
          InkWell(
            key: const ValueKey('toggle-past'),
            onTap: () => setState(() => _showPast = !_showPast),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _showPast ? 'Hide past sessions' : 'Past sessions (${past.length})',
                style: MentoringText.buttonQuiet,
              ),
            ),
          ),
          if (_showPast)
            for (final s in past) SessionCard(controller: c, links: widget.links, session: s),
        ],
      ],
    );
  }

  String _featuredHeading(PairingSession s) {
    if (c.overdue(s)) return 'Needs you: a session to close';
    if (s.status == SessionStatus.requested) {
      return c.isMentor ? 'Needs you: a time to answer' : 'Waiting on ${c.pairing!.mentor.firstName}';
    }
    return 'Up next';
  }
}

/// Opens the form that asks for or books a session (a new one when [session] is null, else moves it).
Future<void> openSessionForm(BuildContext context, PairingController c, Pairing p, {PairingSession? session}) async {
  final sent = await showFormSheet(context, (_) => SessionTimeForm(controller: c, pairing: p, session: session));
  if (sent && context.mounted) {
    showMessage(
      context,
      session != null
          ? (session.status == SessionStatus.requested
                ? 'Booked at the new time.'
                : 'Moved. ${p.counterpart.firstName} has been told.')
          : (c.isMentor
                ? 'Booked. ${p.counterpart.firstName} has been told.'
                : 'Asked. Your mentor confirms the time.'),
    );
  }
}

/// One session with the buttons its state and the viewer's side allow.
class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.controller,
    required this.links,
    required this.session,
    this.featured = false,
  });

  final PairingController controller;
  final MentorshipLinks links;
  final PairingSession session;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final s = session;
    final p = c.pairing!;
    final now = mentoringNow();
    final overdue = c.overdue(s, now);
    final requested = s.status == SessionStatus.requested;
    final scheduled = s.status == SessionStatus.scheduled;
    final held = s.status == SessionStatus.completed;
    final link = meetingUri(s.meetingLink);
    return Container(
      key: ValueKey('session-${s.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: overdue ? AppColors.amber500 : AppColors.cardRule),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(whenLabel(s.scheduledAt), style: MentoringText.cardTitle)),
              StatusPill(
                overdue ? 'Overdue' : _statusWord(c, s),
                tone: overdue
                    ? PillTone.amber
                    : switch (s.status) {
                        SessionStatus.scheduled => PillTone.mint,
                        SessionStatus.requested => PillTone.amber,
                        SessionStatus.completed => PillTone.blue,
                        _ => PillTone.grey,
                      },
              ),
            ],
          ),
          MetaLine(
            icon: LucideIcons.clock,
            text:
                '${minutesLabel(s.durationMin)} · ${modeLabel(s.mode)}'
                '${overdue ? ' · ${_daysAgo(s.scheduledAt, now)}' : ''}'
                '${held ? ' · counted' : ''}',
          ),
          if (s.agenda != null && s.agenda!.isNotEmpty) MetaLine(icon: LucideIcons.notebookPen, text: s.agenda!),
          if (s.cancelReason != null && s.status == SessionStatus.cancelled)
            MetaLine(icon: LucideIcons.info, text: s.cancelReason!, color: AppColors.amber800),
          if (s.summary != null && s.summary!.isNotEmpty) MetaLine(icon: LucideIcons.sparkles, text: s.summary!),
          if (held && s.notes != null && s.notes!.isNotEmpty && (s.summary == null || s.summary!.isEmpty))
            MetaLine(icon: LucideIcons.fileText, text: s.notes!),
          if (held && s.recordingUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: InkWell(
                onTap: () {
                  final uri = meetingUri(s.recordingUrl);
                  if (uri != null) openUrl(context, uri);
                },
                child: Row(
                  children: [
                    const Icon(LucideIcons.video, size: 13, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text('Recording', style: MentoringText.buttonQuiet),
                  ],
                ),
              ),
            ),
          if (c.isMentor && (scheduled || requested) && (s.meetingLink == null || s.meetingLink!.isEmpty))
            MetaLine(icon: LucideIcons.link, text: 'No meeting link yet', color: AppColors.outline),
          ActionWrap(
            children: [
              if (scheduled && link != null)
                SolidButton(label: 'Join', icon: LucideIcons.video, onPressed: () => openUrl(context, link)),
              if (c.isMentor && requested) ...[
                SolidButton(
                  label: 'Approve',
                  icon: LucideIcons.check,
                  onPressed: () => report(context, () => c.approve(s), done: 'Approved. It is on both calendars.'),
                ),
                QuietButton(
                  label: 'Offer another time',
                  onPressed: () => openSessionForm(context, c, p, session: s),
                ),
                QuietButton(
                  label: 'Decline',
                  danger: true,
                  onPressed: () => showTextSheet(
                    context,
                    title: 'Decline this time?',
                    subtitle: '${whenLabel(s.scheduledAt)}. ${p.counterpart.firstName} is told, with your reason.',
                    label: 'Reason',
                    hint: 'I am travelling that day',
                    submitLabel: 'Decline',
                    minLength: 3,
                    danger: true,
                    onSend: (reason) => c.cancel(s, reason),
                  ),
                ),
              ],
              if (!c.isMentor && requested)
                QuietButton(
                  label: 'Withdraw',
                  onPressed: () =>
                      report(context, () => c.cancel(s, 'Withdrawn by the mentee.'), done: 'Request withdrawn.'),
                ),
              if (c.canComplete(s, now) && overdue)
                SolidButton(label: 'Mark held', onPressed: () => _complete(context)),
              if (c.canComplete(s, now) && !overdue)
                QuietButton(label: 'Mark held', onPressed: () => _complete(context)),
              if (scheduled && c.active)
                QuietButton(
                  label: 'Move',
                  onPressed: () => openSessionForm(context, c, p, session: s),
                ),
              if (scheduled)
                QuietButton(
                  label: 'Cancel',
                  onPressed: () => showTextSheet(
                    context,
                    title: 'Cancel this session?',
                    subtitle: '${whenLabel(s.scheduledAt)}. The other person is told, with your reason.',
                    label: 'Reason',
                    hint: 'Something came up at work',
                    submitLabel: 'Cancel session',
                    minLength: 3,
                    danger: true,
                    onSend: (reason) => c.cancel(s, reason),
                  ),
                ),
              if (c.isMentor && (scheduled || requested))
                QuietButton(
                  label: 'Meeting link',
                  icon: LucideIcons.link,
                  onPressed: () async {
                    final sent = await showFormSheet(context, (_) => MeetingLinkForm(controller: c, session: s));
                    if (sent && context.mounted) showMessage(context, 'Link saved.');
                  },
                ),
              if (held)
                QuietButton(
                  label: (s.notes ?? '').isEmpty ? 'Add notes' : 'Notes',
                  icon: LucideIcons.notebookPen,
                  onPressed: () async {
                    final sent = await showFormSheet(context, (_) => SessionRecordForm(controller: c, session: s));
                    if (sent && context.mounted) showMessage(context, 'Notes saved.');
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _complete(BuildContext context) async {
    final sent = await showFormSheet(context, (_) => CompleteSessionForm(controller: controller, session: session));
    if (sent && context.mounted) showMessage(context, 'Marked as held.');
  }

  static String _statusWord(PairingController c, PairingSession s) => switch (s.status) {
    SessionStatus.requested => c.isMentor ? 'Asks for this time' : 'Awaiting ${c.pairing!.mentor.firstName}',
    _ => s.status.label,
  };

  static String _daysAgo(DateTime at, DateTime now) {
    final days = now.difference(at).inDays;
    return days <= 0 ? 'was today' : '${countLabel(days, 'day')} ago';
  }
}
