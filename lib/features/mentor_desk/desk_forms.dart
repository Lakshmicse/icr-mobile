import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../mentorship_my/mentoring_format.dart';
import '../mentorship_my/mentoring_models.dart';
import '../mentorship_my/widgets/forms.dart';
import '../mentorship_my/widgets/kit.dart';
import 'mentor_desk_controller.dart';
import 'mentor_desk_models.dart';

/// The API's limits on the notes these forms send.
const minDeclineReason = 5;
const maxDeclineReason = 500;
const maxMoveNote = 300;
const minIssueReply = 10;
const maxIssueReply = 2000;

String buyerName(SoldRow r) => r.purchase.buyer?.name ?? 'A member';

/// The mentor accepts a session request by setting the time: one of the suggested
/// free times (the mentee's quick picks first), any of their weekly hours, or any
/// future time of their own. A free session is booked at once; a paid one is held
/// until the mentee accepts the time and pays.
class AcceptSessionForm extends StatefulWidget {
  const AcceptSessionForm({super.key, required this.controller, required this.row});

  final MentorDeskController controller;
  final SoldRow row;

  @override
  State<AcceptSessionForm> createState() => _AcceptSessionFormState();
}

class _AcceptSessionFormState extends State<AcceptSessionForm> {
  late final Future<SuggestedTimes> _suggested = widget.controller.repository
      .suggestedTimes(widget.row.id)
      .catchError((_) => const SuggestedTimes());
  Future<List<Slot>>? _slots;
  DateTime? _at;
  String? _problem;
  bool _busy = false;

  ServicePurchase get _p => widget.row.purchase;
  int get _minutes => _p.request?.durationMin ?? 30;
  bool get _free => _p.duePaisa == 0;

  Future<void> _submit() async {
    final at = _at;
    if (at == null) {
      setState(() => _problem = 'Pick a time first.');
      return;
    }
    if (!at.isAfter(widget.controller.now)) {
      setState(() => _problem = 'Pick a time in the future.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final refusal = await widget.controller.acceptSession(widget.row, at);
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
    final req = _p.request!;
    final name = buyerName(widget.row);
    return MentoringForm(
      title: 'Accept $name',
      subtitle: '${_p.title}. ${minutesLabel(_minutes)}${req.mode == null ? '' : ' · ${modeLabel(req.mode!)}'}.',
      submitLabel: _free ? 'Accept and book' : 'Accept',
      busy: _busy,
      problem: _problem,
      onSubmit: _submit,
      children: [
        if (req.preferredTimes != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('They said: ${req.preferredTimes}', style: MentoringText.body),
          ),
        if (widget.row.timeDeclinedAt != null && req.timeDeclineNote != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Callout(
              tone: PillTone.grey,
              text: '$name asked for another time (${dayLabel(widget.row.timeDeclinedAt!)}): ${req.timeDeclineNote}',
            ),
          ),
        FutureBuilder<SuggestedTimes>(
          future: _suggested,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              );
            }
            final s = snap.data ?? const SuggestedTimes();
            return FieldBlock(
              label: 'Suggested times',
              help: s.suggestions.isEmpty
                  ? 'Nothing free is suggested. Pick any time below.'
                  : 'Free on your calendar, in your hours. A star is a time they said suits them.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final slot in s.suggestions)
                        ChoiceChip(
                          key: ValueKey('suggest-${slot.at.toUtc().toIso8601String()}'),
                          label: Text('${weekdayDay(slot.at)}, ${timeLabel(slot.at)}${slot.preferred ? ' ★' : ''}'),
                          selected: _at != null && _at!.isAtSameMomentAs(slot.at),
                          onSelected: (_) => setState(() {
                            _at = slot.at;
                            _problem = null;
                          }),
                        ),
                    ],
                  ),
                  if (s.hasWeeklyHours)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: InkWell(
                        key: const ValueKey('see-all-slots'),
                        onTap: () => setState(() {
                          _slots = _slots == null
                              ? widget.controller.repository
                                    .slots(_p.mentorProfileId ?? '', durationMin: _minutes)
                                    .catchError((_) => const <Slot>[])
                              : null;
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            _slots == null ? 'See all free times' : 'Hide the full list',
                            style: MentoringText.buttonQuiet,
                          ),
                        ),
                      ),
                    ),
                  if (_slots != null)
                    FutureBuilder<List<Slot>>(
                      future: _slots,
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.all(8),
                            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        }
                        final slots = snap.data ?? const <Slot>[];
                        return slots.isEmpty
                            ? Text('No free times in the next two weeks.', style: MentoringText.meta)
                            : SlotPicker(slots: slots, selected: _at, onSelect: (at) => setState(() => _at = at));
                      },
                    ),
                ],
              ),
            );
          },
        ),
        FieldBlock(
          label: 'Or choose another time',
          help:
              'Your weekly hours do not bind it: any future time you pick is yours to set. A clash with another session does.',
          child: QuietButton(
            label: _at == null ? 'Pick a day and time' : whenLabel(_at!),
            icon: LucideIcons.calendarClock,
            onPressed: () async {
              final at = await pickDateTime(context, initial: _at);
              if (at != null && mounted) {
                setState(() {
                  _at = at;
                  _problem = null;
                });
              }
            },
          ),
        ),
        Callout(
          tone: PillTone.blue,
          text: _free
              ? 'It is booked on both calendars at once.'
              : 'The time is held for $name. It is booked once they accept it and pay; nothing is charged before.',
        ),
      ],
    );
  }
}

/// The mentor proposes another time for a booked call; the mentee accepts or keeps the old one.
class ProposeMoveForm extends StatefulWidget {
  const ProposeMoveForm({super.key, required this.controller, required this.row});

  final MentorDeskController controller;
  final SoldRow row;

  @override
  State<ProposeMoveForm> createState() => _ProposeMoveFormState();
}

class _ProposeMoveFormState extends State<ProposeMoveForm> {
  final _note = TextEditingController();
  late final Future<List<Slot>> _slots = widget.controller.repository
      .slots(widget.row.purchase.mentorProfileId ?? '', durationMin: widget.row.purchase.booking?.durationMin ?? 30)
      .catchError((_) => const <Slot>[]);
  DateTime? _at;
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
      setState(() => _problem = 'Pick a time first.');
      return;
    }
    if (!at.isAfter(widget.controller.now)) {
      setState(() => _problem = 'Pick a time in the future.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final refusal = await widget.controller.proposeMove(widget.row, at, note: _note.text);
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
    final b = widget.row.purchase.booking!;
    final name = buyerName(widget.row);
    return MentoringForm(
      title: 'Offer another time',
      subtitle: 'Booked now: ${whenLabel(b.scheduledAt)}. $name is asked; the call stays as it is until they accept.',
      submitLabel: 'Send new time',
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
              label: slots.isEmpty ? 'When?' : 'Free times in your hours',
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
          label: 'A note for $name (optional)',
          child: TextField(
            key: const ValueKey('move-note'),
            controller: _note,
            minLines: 2,
            maxLines: 4,
            maxLength: maxMoveNote,
            style: MentoringText.formInput,
            decoration: fieldDecoration('I have a site visit that morning'),
          ),
        ),
      ],
    );
  }
}

/// The mentor sets (or clears) the meeting link of one paid call.
class CallLinkForm extends StatefulWidget {
  const CallLinkForm({super.key, required this.controller, required this.row});

  final MentorDeskController controller;
  final SoldRow row;

  @override
  State<CallLinkForm> createState() => _CallLinkFormState();
}

class _CallLinkFormState extends State<CallLinkForm> {
  late final _link = TextEditingController(text: widget.row.purchase.booking?.meetingLink ?? '');
  String? _problem;
  bool _busy = false;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final bad = linkProblem(_link.text);
    if (bad != null) {
      setState(() => _problem = bad);
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final value = _link.text.trim().isEmpty ? null : normaliseLink(_link.text);
    final refusal = await widget.controller.setCallLink(widget.row, value);
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
    final b = widget.row.purchase.booking!;
    return MentoringForm(
      title: 'Meeting link',
      subtitle:
          '${whenLabel(b.scheduledAt)}. ${buyerName(widget.row)} is told when it changes. Leave it empty to use your standing link.',
      submitLabel: 'Save link',
      busy: _busy,
      problem: _problem,
      onSubmit: _submit,
      children: [
        FieldBlock(
          label: 'Link',
          child: TextField(
            key: const ValueKey('call-link'),
            controller: _link,
            keyboardType: TextInputType.url,
            style: MentoringText.formInput,
            decoration: fieldDecoration('https://meet.google.com/abc-defg-hij'),
          ),
        ),
      ],
    );
  }
}
