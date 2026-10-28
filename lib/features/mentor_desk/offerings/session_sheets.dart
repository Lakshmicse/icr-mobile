import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/links.dart';
import '../../mentorship_my/mentoring_clock.dart';
import '../../mentorship_my/mentoring_format.dart' show countLabel, inr, minutesLabel, whenLabel;
import '../../mentorship_my/widgets/blocks.dart' show GroupLabel;
import '../../mentorship_my/widgets/forms.dart';
import '../../mentorship_my/widgets/kit.dart';
import 'group_form.dart';
import 'offerings_controller.dart';
import 'offerings_models.dart';
import 'offerings_rules.dart';

/// Opens a hosted session in full: its days, seats, the roster (with each
/// person's question), and what the host may do next: edit, publish a draft,
/// record who came, cancel. Reads the session's detail first (the list holds no roster).
Future<void> showSessionSheet(BuildContext context, OfferingsController controller, HostedSession session) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
    builder: (_) => SessionSheet(controller: controller, session: session),
  );
}

class SessionSheet extends StatefulWidget {
  const SessionSheet({super.key, required this.controller, required this.session});

  final OfferingsController controller;
  final HostedSession session;

  @override
  State<SessionSheet> createState() => _SessionSheetState();
}

class _SessionSheetState extends State<SessionSheet> {
  HostedSession? _detail;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await widget.controller.detail(widget.session);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiError.from(e).message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    return SafeArea(
      child: _loading
          ? const SizedBox(height: 240, child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)))
          : d == null
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: EmptyNote(
                icon: LucideIcons.cloudOff,
                compact: true,
                title: "Couldn't open this session",
                body: _error ?? 'Try again.',
                action: 'Try again',
                onAction: _load,
              ),
            )
          : _body(context, d),
    );
  }

  Widget _body(BuildContext context, HostedSession d) {
    final c = widget.controller;
    final now = mentoringNow();
    final roster = d.roster ?? const <RosterPerson>[];
    final seated = roster.where((r) => r.holdsSeat).toList();
    final waiting = roster.where((r) => r.status == 'WAITLISTED').toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      shrinkWrap: true,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(d.title, key: const ValueKey('session-title'), style: MentoringText.hero),
            ),
            StatusPill(
              d.statusLabel,
              tone: switch (d.status) {
                'SCHEDULED' => PillTone.mint,
                'DRAFT' => PillTone.amber,
                'COMPLETED' => PillTone.blue,
                _ => PillTone.grey,
              },
            ),
          ],
        ),
        if (d.summary != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(d.summary!, style: MentoringText.body),
          ),
        MetaLine(icon: LucideIcons.video, text: groupModes[d.mode] ?? d.mode),
        if (d.inPerson && d.location != null) MetaLine(icon: LucideIcons.mapPin, text: d.location!),
        if (!d.inPerson && d.meetingLink != null) MetaLine(icon: LucideIcons.link, text: d.meetingLink!),
        MetaLine(icon: LucideIcons.indianRupee, text: d.pricePaisa == null ? 'Free' : '${inr(d.pricePaisa!)} a seat'),
        MetaLine(
          icon: LucideIcons.users,
          text:
              '${countLabel(d.seatsTaken, 'seat')} taken${d.capacity == null ? ', no limit' : ' of ${d.capacity}'}'
              '${d.waitlistCount > 0 ? ' · ${d.waitlistCount} waiting' : ''}',
        ),
        if (d.cancelReason != null)
          MetaLine(icon: LucideIcons.info, text: 'Cancelled: ${d.cancelReason}', color: AppColors.amber800),
        const SectionTitle(title: 'Days', top: 14),
        for (final day in d.days)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text('${whenLabel(day.at)} · ${minutesLabel(day.durationMin)}', style: MentoringText.body),
                ),
                StatusPill(
                  switch (day.status) {
                    'COMPLETED' => 'Held',
                    'CANCELLED' => 'Cancelled',
                    _ => 'Scheduled',
                  },
                  tone: day.status == 'COMPLETED'
                      ? PillTone.blue
                      : (day.status == 'CANCELLED' ? PillTone.grey : PillTone.mint),
                ),
              ],
            ),
          ),
        SectionTitle(title: 'Who is coming (${seated.length})', top: 14),
        if (d.draft)
          Text('A draft: nobody can register until you publish it.', style: MentoringText.body)
        else if (seated.isEmpty && waiting.isEmpty)
          Text('Nobody has registered yet.', style: MentoringText.body),
        for (final r in seated) _RosterRow(person: r),
        if (waiting.isNotEmpty) ...[const GroupLabel('Waitlist'), for (final r in waiting) _RosterRow(person: r)],
        ActionWrap(
          children: [
            if (!d.closed)
              QuietButton(
                key: const ValueKey('session-edit'),
                label: 'Edit',
                icon: LucideIcons.pencil,
                onPressed: () async {
                  final saved = await showFormSheet(context, (_) => GroupSessionForm(controller: c, existing: d));
                  if (saved && context.mounted) {
                    showMessage(context, 'Saved.');
                    await _load();
                  }
                },
              ),
            if (d.draft)
              SolidButton(
                key: const ValueKey('session-publish'),
                label: 'Publish',
                icon: LucideIcons.send,
                onPressed: () => _publish(context, d),
              ),
            if (d.startedBy(now))
              SolidButton(
                key: const ValueKey('session-attendance'),
                label: 'Record who came',
                icon: LucideIcons.clipboardCheck,
                onPressed: () async {
                  final saved = await showFormSheet(context, (_) => AttendanceForm(controller: c, session: d));
                  if (saved && context.mounted) {
                    showMessage(context, 'Attendance recorded.');
                    await _load();
                  }
                },
              ),
            if (!d.closed)
              QuietButton(
                key: const ValueKey('session-cancel'),
                label: 'Cancel session',
                danger: true,
                onPressed: () async {
                  final done = await showTextSheet(
                    context,
                    title: 'Cancel this session?',
                    subtitle:
                        '${d.seatsTaken == 0 ? 'Nobody is registered.' : 'Everyone registered is told, with your reason.'}'
                        '${d.paid && d.seatsTaken > 0 ? ' Paid seats are refunded.' : ''}',
                    label: 'Reason',
                    hint: 'I have to travel that week',
                    submitLabel: 'Cancel session',
                    minLength: minCancelReason,
                    maxLength: maxCancelReason,
                    danger: true,
                    onSend: (reason) => c.cancelSession(d, reason),
                  );
                  if (done && context.mounted) {
                    showMessage(context, 'Session cancelled.');
                    await _load();
                  }
                },
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _publish(BuildContext context, HostedSession d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Publish this session?'),
        content: const Text('It opens for registration now. Check the date, the place and the seats first.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Not yet')),
          TextButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Publish')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final refusal = await widget.controller.publishSession(d);
    if (!context.mounted) return;
    showMessage(context, refusal ?? 'Published. Members can register.');
    if (refusal == null) await _load();
  }
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({required this.person});

  final RosterPerson person;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('roster-${person.id}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(person.name, style: MentoringText.bodyStrong)),
              StatusPill(person.statusLabel, tone: person.status == 'ATTENDED' ? PillTone.blue : PillTone.grey),
            ],
          ),
          if (person.question != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('"${person.question}"', style: MentoringText.quote),
            ),
        ],
      ),
    );
  }
}

/// Records who was there: everyone ticked is marked attended, everyone else a no-show. Only once a day has started.
class AttendanceForm extends StatefulWidget {
  const AttendanceForm({super.key, required this.controller, required this.session});

  final OfferingsController controller;
  final HostedSession session;

  @override
  State<AttendanceForm> createState() => _AttendanceFormState();
}

class _AttendanceFormState extends State<AttendanceForm> {
  late final List<RosterPerson> _people = [
    for (final r in widget.session.roster ?? const <RosterPerson>[])
      if (r.holdsSeat) r,
  ];
  late final Set<String> _present = {for (final r in _people) r.id};
  final _minutes = TextEditingController();
  final _note = TextEditingController();
  String? _problem;
  bool _busy = false;

  @override
  void dispose() {
    _minutes.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    int? minutes;
    if (_minutes.text.trim().isNotEmpty) {
      minutes = int.tryParse(_minutes.text.trim());
      if (minutes == null || minutes < minSessionMinutes || minutes > maxSessionMinutes) {
        setState(() => _problem = 'Minutes it ran: $minSessionMinutes to $maxSessionMinutes, or leave it empty.');
        return;
      }
    }
    if (_note.text.trim().length > 2000) {
      setState(() => _problem = 'Keep the note under 2,000 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    // The API takes the attendee rows' ids: the roster's `id`.
    final refusal = await widget.controller.completeSession(
      widget.session,
      [
        for (final p in _people)
          if (_present.contains(p.id)) p.id,
      ],
      durationMin: minutes,
      note: _note.text,
    );
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
    return MentoringForm(
      title: 'Who came?',
      subtitle: 'Tick everyone who was there. Anyone left unticked is marked a no-show.',
      submitLabel: 'Record attendance',
      busy: _busy,
      problem: _problem,
      onSubmit: _submit,
      children: [
        if (_people.isEmpty) Text('Nobody holds a seat, so there is no one to mark.', style: MentoringText.body),
        for (final p in _people)
          CheckboxListTile(
            key: ValueKey('present-${p.id}'),
            contentPadding: EdgeInsets.zero,
            value: _present.contains(p.id),
            onChanged: (v) => setState(() => v == true ? _present.add(p.id) : _present.remove(p.id)),
            title: Text(p.name, style: MentoringText.bodyStrong),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        const SizedBox(height: 8),
        FieldBlock(
          label: 'Minutes it actually ran (optional)',
          child: TextField(
            key: const ValueKey('attendance-minutes'),
            controller: _minutes,
            keyboardType: TextInputType.number,
            style: MentoringText.formInput,
            decoration: fieldDecoration('60'),
          ),
        ),
        FieldBlock(
          label: 'A note (optional)',
          child: TextField(
            key: const ValueKey('attendance-note'),
            controller: _note,
            minLines: 2,
            maxLines: 4,
            maxLength: 2000,
            style: MentoringText.formInput,
            decoration: fieldDecoration('What you covered'),
          ),
        ),
      ],
    );
  }
}
