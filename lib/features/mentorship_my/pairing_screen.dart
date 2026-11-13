import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/util/links.dart';
import 'mentoring_format.dart';
import 'mentoring_links.dart';
import 'mentoring_models.dart';
import 'mentoring_repository.dart';
import 'pairing_controller.dart';
import 'pairing_forms.dart';
import 'pairing_sessions.dart';
import 'pairing_work.dart';
import 'widgets/forms.dart';
import 'widgets/kit.dart';

/// Pushes [PairingScreen] for pairing [id].
Future<void> openPairing(
  BuildContext context,
  String id, {
  MentorshipLinks? links,
  OpenConversation? onOpenConversation,
  void Function(BuildContext context, String mentorProfileId)? onOpenMentor,
  void Function(BuildContext context)? onBell,
  OpenSitePath? onOpenWebsite,
}) {
  final resolved = MentorshipLinks.resolve(
    context,
    links,
    onOpenConversation: onOpenConversation,
    onOpenMentor: onOpenMentor,
    onBell: onBell,
    onOpenWebsite: onOpenWebsite,
  );
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PairingScreen(id: id, links: resolved),
    ),
  );
}

/// One pairing, from either side (the website's `/mentorship/my/<id>`): who it
/// is with, the session that needs attention, the plan behind it, its sessions
/// (ask for or book a time, move, cancel, mark held, notes, meeting link),
/// goals and tasks, shared links and files, the timeline, the review and the
/// certificate once it is complete, a concern, and pausing or ending it.
///
/// "Message" opens the pairing's thread through the record
/// (`POST /mentorship/:id/conversation`): [onOpenConversation] (or
/// `MentorshipLinks.openPairingThread`) is the messaging feature's chat screen.
class PairingScreen extends StatefulWidget {
  const PairingScreen({
    super.key,
    required this.id,
    this.onBack,
    this.links,
    this.repository,
    this.onOpenConversation,
    this.onOpenMentor,
    this.onBell,
    this.onOpenWebsite,
    this.pickFile = pickShareFile,
  });

  final String id;
  final VoidCallback? onBack;
  final MentorshipLinks? links;

  /// A seam for tests; the API by default.
  final MentoringRepository? repository;

  /// Opens the messaging feature's chat for a conversation id.
  final OpenConversation? onOpenConversation;

  /// Opens a mentor's profile by mentor profile id.
  final void Function(BuildContext context, String mentorProfileId)? onOpenMentor;

  /// The bell.
  final void Function(BuildContext context)? onBell;

  /// Opens a page of the website (a path such as `/notifications`).
  final OpenSitePath? onOpenWebsite;

  /// The file chooser for "Share a file": the phone's by default, a test's stand-in otherwise.
  final SharePicker pickFile;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  late final PairingController _c;
  late final MentorshipLinks _links;

  @override
  void initState() {
    super.initState();
    final repo = widget.repository ?? MentoringRepository(api: context.read<ApiClient>());
    _links = MentorshipLinks.resolve(
      context,
      widget.links,
      onOpenConversation: widget.onOpenConversation,
      onOpenMentor: widget.onOpenMentor,
      onBell: widget.onBell,
      onOpenWebsite: widget.onOpenWebsite,
    );
    _c = PairingController(repo, widget.id)..load();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final p = _c.pairing;
        return MentoringPage(
          title: p == null ? 'Mentorship' : (p.viewerIsMentor ? 'Your Mentee' : 'Your Mentor'),
          onBack: widget.onBack,
          onBell: () => _links.notifications(context),
          body: LoadedList(
            loading: _c.loading,
            error: _c.error,
            errorTitle: 'Unable to Load This Mentorship',
            onRefresh: _c.load,
            children: p == null ? const [] : _content(context, p),
          ),
        );
      },
    );
  }

  List<Widget> _content(BuildContext context, Pairing p) {
    final showGoals = !_c.isProgramme || _c.goals.isNotEmpty;
    return [
      _Header(
        pairing: p,
        controller: _c,
        onMessage: () => _links.messagePairing(context, _c.repository, p.id),
        onProfile: p.viewerIsMentor || p.mentorProfileId.isEmpty
            ? null
            : () => _links.mentor(context, p.mentorProfileId),
      ),
      if (p.endedReason != null && !p.status.live) Callout(tone: PillTone.grey, text: 'Ended: ${p.endedReason}'),
      if (p.status == PairingStatus.paused)
        const Callout(tone: PillTone.amber, text: 'Paused. Resume it to book sessions.'),
      SessionsSection(controller: _c, links: _links),
      PlanSection(controller: _c),
      if (showGoals) GoalsSection(controller: _c),
      TasksSection(controller: _c),
      ResourcesSection(controller: _c, links: _links, pickFile: widget.pickFile),
      FeedbackSection(controller: _c, links: _links),
      TimelineSection(controller: _c),
      _Manage(controller: _c),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.pairing, required this.controller, required this.onMessage, this.onProfile});

  final Pairing pairing;
  final PairingController controller;
  final VoidCallback onMessage;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    final p = pairing;
    return MentoringCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PersonRow(
            person: p.counterpart,
            size: 52,
            trailing: StatusPill(
              p.status.label,
              tone: switch (p.status) {
                PairingStatus.active => PillTone.mint,
                PairingStatus.paused => PillTone.amber,
                PairingStatus.completed => PillTone.blue,
                PairingStatus.endedEarly => PillTone.grey,
              },
            ),
          ),
          MetaLine(
            icon: LucideIcons.calendarDays,
            text:
                '${p.viewerIsMentor ? 'Mentee' : 'Mentor'} since ${dayLabel(p.startedAt)}'
                '${p.cadence == null ? '' : ' · ${cadences[p.cadence] ?? p.cadence}'}',
          ),
          MetaLine(
            icon: LucideIcons.clock,
            text: '${countLabel(p.sessionsCount, 'session')} held · ${minutesLabel(p.totalMinutes)} in all',
          ),
          if (p.counterpartPhone != null) MetaLine(icon: LucideIcons.phone, text: p.counterpartPhone!),
          ActionWrap(
            children: [
              SolidButton(label: 'Message', icon: LucideIcons.messageSquare, onPressed: onMessage),
              if (onProfile != null) QuietButton(label: 'Mentor Profile', onPressed: onProfile),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pause, resume, mark complete, end early, the rhythm, a concern and support.
class _Manage extends StatelessWidget {
  const _Manage({required this.controller});

  final PairingController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.pairing!;
    final other = p.counterpart.firstName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'This Mentorship'),
        if (p.status.live) ...[
          FieldRow(
            label: 'Meeting Frequency',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final MapEntry(key: key, value: label) in cadences.entries)
                  ChoiceChip(
                    key: ValueKey('cadence-$key'),
                    label: Text(label),
                    selected: p.cadence == key,
                    onSelected: p.cadence == key
                        ? null
                        : (_) => report(context, () => c.setCadence(key), done: 'Meeting frequency updated.'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        ActionWrap(
          top: 0,
          children: [
            if (p.status == PairingStatus.active)
              QuietButton(
                label: 'Pause',
                icon: LucideIcons.pause,
                onPressed: () => report(context, () => c.setStatus(PairingStatus.paused), done: 'Paused.'),
              ),
            if (p.status == PairingStatus.paused)
              QuietButton(
                label: 'Resume',
                icon: LucideIcons.play,
                onPressed: () => report(context, () => c.setStatus(PairingStatus.active), done: 'Resumed.'),
              ),
            if (p.status.live)
              QuietButton(
                label: 'Mark Complete',
                icon: LucideIcons.circleCheck,
                onPressed: () => _complete(context, p),
              ),
            if (p.status.live)
              QuietButton(
                label: 'End Early',
                icon: LucideIcons.circleX,
                danger: true,
                onPressed: () => _endEarly(context),
              ),
            QuietButton(
              label: 'Report a Concern',
              icon: LucideIcons.flag,
              onPressed: () async {
                final sent = await showFormSheet(context, (_) => ConcernForm(controller: c));
                if (sent && context.mounted) {
                  showMessage(context, 'Sent to ICR. The team will review it and reply to you.');
                }
              },
            ),
            QuietButton(
              label: 'Contact ICR Support',
              icon: LucideIcons.lifeBuoy,
              onPressed: () async {
                final sent = await showFormSheet(
                  context,
                  (_) => SupportForm(
                    onSend: (subject, body) => c.askSupport(subject: subject, body: body),
                  ),
                );
                if (sent && context.mounted) showMessage(context, 'Sent. ICR support will reply to you.');
              },
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'A concern is private to ICR. $other is not notified and nothing is shown to them.',
            style: MentoringText.meta,
          ),
        ),
      ],
    );
  }

  Future<void> _complete(BuildContext context, Pairing p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Mark This Mentorship Complete?'),
        content: Text(
          'This closes the mentorship for you both and cancels any booked sessions. '
          '${p.counterpart.firstName} is notified, and you can both leave a review.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Not Yet')),
          TextButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Mark Complete')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await report(context, () => controller.setStatus(PairingStatus.completed), done: 'Marked complete.');
    }
  }

  Future<void> _endEarly(BuildContext context) => showTextSheet(
    context,
    title: 'End This Mentorship Early?',
    subtitle: 'You both see the reason. Any booked sessions are cancelled.',
    label: 'Reason',
    hint: 'Our schedules no longer match',
    submitLabel: 'End Mentorship',
    minLength: 3,
    maxLength: 1000,
    danger: true,
    onSend: (reason) => controller.setStatus(PairingStatus.endedEarly, reason: reason),
  );
}

/// A label over a control.
class FieldRow extends StatelessWidget {
  const FieldRow({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MentoringText.formLabel),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
