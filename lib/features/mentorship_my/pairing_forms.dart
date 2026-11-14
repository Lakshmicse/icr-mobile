import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_error.dart';
import 'mentoring_clock.dart';
import 'mentoring_format.dart';
import 'mentoring_models.dart';
import 'mentoring_repository.dart';
import 'pairing_controller.dart';
import 'widgets/forms.dart';
import 'widgets/kit.dart';

/// The API's session length limits (`MIN_SESSION_MINUTES`, `MAX_SESSION_MINUTES`).
const minSessionMinutes = 15;
const maxSessionMinutes = 480;

/// The API's note and agenda limits.
const maxSessionNotes = 8000;
const minNotesForSummary = 200;

// ---------------------------------------------------------------------------
// A session: ask for it, book it, move it
// ---------------------------------------------------------------------------

/// Asks for (mentee) or books (mentor) one session; with [session] it moves
/// that session (either person on a booked one, the mentor answering a request
/// with another time). Length, how, when (a free time from the mentor's weekly
/// hours, or any time the phone's pickers give), what to cover, and for a
/// programme the step it belongs to. A refusal stays in the sheet, with what
/// was typed.
class SessionTimeForm extends StatefulWidget {
  const SessionTimeForm({super.key, required this.controller, required this.pairing, this.session});

  final PairingController controller;
  final Pairing pairing;
  final PairingSession? session;

  @override
  State<SessionTimeForm> createState() => _SessionTimeFormState();
}

class _SessionTimeFormState extends State<SessionTimeForm> {
  static const _lengths = [30, 45, 60, 90];
  final _agenda = TextEditingController();
  final _other = TextEditingController();
  late int _minutes = widget.session?.durationMin ?? 60;
  bool _custom = false;
  String? _mode;
  DateTime? _at;
  String? _stepId;
  late Future<List<Slot>> _slots;
  late final Future<List<String>> _modes;
  String? _problem;
  bool _busy = false;

  MentoringRepository get _repo => widget.controller.repository;
  bool get _moving => widget.session != null;

  @override
  void initState() {
    super.initState();
    _agenda.text = widget.session?.agenda ?? '';
    _mode = widget.session?.mode;
    _custom = !_lengths.contains(_minutes);
    if (_custom) _other.text = '$_minutes';
    _slots = _loadSlots();
    _modes = _repo.mentorModes(widget.pairing.mentorProfileId).catchError((_) => const <String>[]);
    final steps = widget.controller.openSteps;
    if (!_moving && widget.controller.isProgramme && steps.isNotEmpty) {
      _stepId = (steps.where((s) => s.isNext).firstOrNull ?? steps.first).id;
    }
  }

  Future<List<Slot>> _loadSlots() =>
      _repo.slots(widget.pairing.mentorProfileId, durationMin: _minutes).catchError((_) => const <Slot>[]);

  @override
  void dispose() {
    _agenda.dispose();
    _other.dispose();
    super.dispose();
  }

  void _setMinutes(int m) {
    setState(() {
      _minutes = m;
      _at = null;
      _slots = _loadSlots();
    });
  }

  Future<void> _submit(List<String> modes) async {
    if (_minutes < minSessionMinutes || _minutes > maxSessionMinutes) {
      setState(() => _problem = 'A session runs $minSessionMinutes to $maxSessionMinutes minutes.');
      return;
    }
    final at = _at ?? (_moving ? widget.session!.scheduledAt : null);
    if (at == null) {
      setState(() => _problem = 'Select a time first.');
      return;
    }
    if (!at.isAfter(mentoringNow())) {
      setState(() => _problem = 'Select a time in the future.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final mode = _mode ?? (modes.isEmpty ? 'VIDEO' : modes.first);
    final refusal = _moving
        ? await widget.controller.reschedule(
            widget.session!,
            at: at,
            durationMin: _minutes,
            mode: mode,
            agenda: _agenda.text.trim().isEmpty ? null : _agenda.text,
          )
        : await widget.controller.schedule(
            at: at,
            durationMin: _minutes,
            mode: mode,
            agenda: _agenda.text,
            planStepId: _stepId,
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
    final mentor = widget.controller.isMentor;
    final answering = _moving && widget.session!.status == SessionStatus.requested;
    return FutureBuilder<List<String>>(
      future: _modes,
      builder: (context, modesSnap) {
        final modes = (modesSnap.data == null || modesSnap.data!.isEmpty)
            ? meetingModes.keys.toList()
            : modesSnap.data!;
        final mode = (_mode != null && modes.contains(_mode)) ? _mode! : modes.first;
        final steps = widget.controller.openSteps;
        return MentoringForm(
          title: answering
              ? 'Offer Another Time'
              : _moving
              ? 'Move This Session'
              : (mentor ? 'Book a Session' : 'Request a Time'),
          subtitle: answering
              ? '${widget.pairing.mentee.firstName} is notified, and the session is booked at the time you select.'
              : _moving
              ? 'The other person is notified. The session stays booked at the new time.'
              : mentor
              ? 'It is added to both calendars immediately.'
              : '${widget.pairing.mentor.firstName} confirms it before it is booked.',
          submitLabel: answering
              ? 'Book This Time'
              : _moving
              ? 'Move Session'
              : (mentor ? 'Book Session' : 'Send Request'),
          busy: _busy,
          problem: _problem,
          onSubmit: () => _submit(modes),
          children: [
            if (!_moving && widget.controller.isProgramme && steps.isNotEmpty)
              FieldBlock(
                label: 'Programme Session',
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in steps)
                      ChoiceChip(
                        key: ValueKey('step-${s.id}'),
                        label: Text('${s.position}. ${s.title}'),
                        selected: _stepId == s.id,
                        onSelected: (_) => setState(() {
                          _stepId = s.id;
                          if (s.durationMin != null && !_custom && _lengths.contains(s.durationMin)) {
                            _setMinutes(s.durationMin!);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            FieldBlock(
              label: 'Duration',
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final m in _lengths)
                    ChoiceChip(
                      label: Text(minutesLabel(m)),
                      selected: !_custom && m == _minutes,
                      onSelected: (_) {
                        setState(() => _custom = false);
                        _setMinutes(m);
                      },
                    ),
                  ChoiceChip(
                    key: const ValueKey('length-other'),
                    label: const Text('Other'),
                    selected: _custom,
                    onSelected: (_) => setState(() => _custom = true),
                  ),
                ],
              ),
            ),
            if (_custom)
              FieldBlock(
                label: 'Minutes ($minSessionMinutes to $maxSessionMinutes)',
                child: TextField(
                  key: const ValueKey('session-minutes'),
                  controller: _other,
                  keyboardType: TextInputType.number,
                  style: MentoringText.formInput,
                  decoration: fieldDecoration('50'),
                  onChanged: (v) {
                    final m = int.tryParse(v.trim());
                    if (m != null && m >= minSessionMinutes && m <= maxSessionMinutes && m != _minutes) {
                      _setMinutes(m);
                    } else if (m != null) {
                      setState(() => _minutes = m);
                    }
                  },
                ),
              ),
            FieldBlock(
              label: 'Meeting Mode',
              child: Wrap(
                spacing: 6,
                children: [
                  for (final m in modes)
                    ChoiceChip(
                      label: Text(meetingModes[m] ?? m),
                      selected: m == mode,
                      onSelected: (_) => setState(() => _mode = m),
                    ),
                ],
              ),
            ),
            FutureBuilder<List<Slot>>(
              future: _slots,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  );
                }
                final slots = snap.data ?? const <Slot>[];
                final own = _at != null && !slots.any((s) => s.at.isAtSameMomentAs(_at!));
                return FieldBlock(
                  label: slots.isEmpty ? 'Date and Time' : 'Free Times in ${mentor ? 'Your' : 'Their'} Hours',
                  help: slots.isEmpty
                      ? 'No open times in the next two weeks. Select a day and time.'
                      : 'Times are shown in your phone\'s time zone. A time outside the mentor\'s hours or overlapping another session is not accepted.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_moving && _at == null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('Now: ${whenLabel(widget.session!.scheduledAt)}', style: MentoringText.meta),
                        ),
                      if (slots.isNotEmpty)
                        SlotPicker(slots: slots, selected: _at, onSelect: (at) => setState(() => _at = at)),
                      const SizedBox(height: 8),
                      QuietButton(
                        label: own ? whenLabel(_at!) : (slots.isEmpty ? 'Select a Day and Time' : 'Another Time'),
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
              label: 'Agenda (Optional)',
              child: TextField(
                key: const ValueKey('session-agenda'),
                controller: _agenda,
                minLines: 2,
                maxLines: 4,
                maxLength: 2000,
                style: MentoringText.formInput,
                decoration: fieldDecoration('What you want to cover'),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Closing out a session
// ---------------------------------------------------------------------------

/// The mentor marks a session held, with the minutes it really ran (CPD and the
/// pairing's counters are claimed on that number) and an optional note for
/// the timeline.
class CompleteSessionForm extends StatefulWidget {
  const CompleteSessionForm({super.key, required this.controller, required this.session});

  final PairingController controller;
  final PairingSession session;

  @override
  State<CompleteSessionForm> createState() => _CompleteSessionFormState();
}

class _CompleteSessionFormState extends State<CompleteSessionForm> {
  late final _minutes = TextEditingController(text: '${widget.session.durationMin}');
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
    final m = int.tryParse(_minutes.text.trim());
    if (m == null || m < minSessionMinutes || m > maxSessionMinutes) {
      setState(() => _problem = 'Enter the minutes it ran, from $minSessionMinutes to $maxSessionMinutes.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final refusal = await widget.controller.complete(
      widget.session,
      durationMin: m,
      note: _note.text.trim().isEmpty ? null : _note.text,
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
      title: 'Mark Session as Held',
      subtitle:
          'This duration is counted. ${minutesLabel(widget.session.durationMin)} was booked. '
          'Change it if the session ran shorter or longer.',
      submitLabel: 'Mark as Held',
      busy: _busy,
      problem: _problem,
      onSubmit: _submit,
      children: [
        FieldBlock(
          label: 'Actual Minutes',
          child: TextField(
            key: const ValueKey('held-minutes'),
            controller: _minutes,
            keyboardType: TextInputType.number,
            style: MentoringText.formInput,
            decoration: fieldDecoration('45'),
          ),
        ),
        FieldBlock(
          label: 'Timeline Note (Optional)',
          child: TextField(
            key: const ValueKey('held-note'),
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

/// What a session left behind: notes, a recording link the pair made
/// themselves (ICR does not record calls) and, on request only, a summary of
/// the notes. Editing the notes clears the summary, as the API does.
class SessionRecordForm extends StatefulWidget {
  const SessionRecordForm({super.key, required this.controller, required this.session});

  final PairingController controller;
  final PairingSession session;

  @override
  State<SessionRecordForm> createState() => _SessionRecordFormState();
}

class _SessionRecordFormState extends State<SessionRecordForm> {
  late final _notes = TextEditingController(text: widget.session.notes ?? '');
  late final _link = TextEditingController(text: widget.session.recordingUrl ?? '');
  late String? _summary = widget.session.summary;
  String? _note;
  String? _problem;
  bool _busy = false;
  bool _summarising = false;

  PairingSession get _s =>
      widget.controller.sessions.firstWhere((x) => x.id == widget.session.id, orElse: () => widget.session);

  @override
  void dispose() {
    _notes.dispose();
    _link.dispose();
    super.dispose();
  }

  bool get _dirty => _notes.text != (_s.notes ?? '') || _link.text.trim() != (_s.recordingUrl ?? '');
  bool get _tooShort => _notes.text.trim().length < minNotesForSummary;

  Future<void> _save() async {
    final bad = linkProblem(_link.text, max: 2000, what: 'recording link');
    if (bad != null) {
      setState(() => _problem = bad);
      return;
    }
    if (_notes.text.length > maxSessionNotes) {
      setState(() => _problem = 'Notes are limited to $maxSessionNotes characters.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final link = normaliseLink(_link.text);
    final refusal = await widget.controller.saveRecord(widget.session, notes: _notes.text, recordingUrl: link);
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

  Future<void> _summarise() async {
    setState(() {
      _summarising = true;
      _problem = null;
      _note = null;
    });
    try {
      final r = await widget.controller.summarise(widget.session);
      if (!mounted) return;
      setState(() {
        _summarising = false;
        _summary = r.summary;
        if (r.unavailable) _note = 'Summaries are not available yet.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _summarising = false;
        _problem = ApiError.from(e).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MentoringForm(
      title: 'Notes for ${dayLabel(widget.session.scheduledAt)}',
      subtitle: 'Either of you can write these notes. They are private to you both.',
      submitLabel: 'Save Notes',
      busy: _busy,
      problem: _problem,
      onSubmit: _dirty ? _save : null,
      children: [
        FieldBlock(
          label: 'What Happened',
          help: '${_notes.text.length} of $maxSessionNotes characters',
          child: TextField(
            key: const ValueKey('record-notes'),
            controller: _notes,
            minLines: 5,
            maxLines: 12,
            maxLength: maxSessionNotes,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            onChanged: (_) => setState(() {}),
            style: MentoringText.formInput,
            decoration: fieldDecoration('Decisions, actions, what to bring next time'),
          ),
        ),
        FieldBlock(
          label: 'Recording Link (Optional)',
          help: 'ICR does not record calls. Keep a link to a recording you made yourselves.',
          child: TextField(
            key: const ValueKey('record-link'),
            controller: _link,
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() {}),
            style: MentoringText.formInput,
            decoration: fieldDecoration('https://'),
          ),
        ),
        QuietButton(
          label: _summarising ? 'Summarising…' : 'Summarise Notes',
          icon: LucideIcons.sparkles,
          onPressed: _summarising || _dirty || _tooShort ? null : _summarise,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            _dirty
                ? 'Save your changes first. A summary is made from the saved notes.'
                : _tooShort
                ? 'A summary needs at least $minNotesForSummary characters of notes.'
                : 'Runs only when you select it. The notes are sent to an AI model to be summarised.',
            style: MentoringText.meta,
          ),
        ),
        if (_note != null) Callout(text: _note!, tone: PillTone.grey),
        if (_summary != null) Callout(text: _summary!, tone: PillTone.mint),
      ],
    );
  }
}

/// The mentor sets (or clears) the link for one session.
class MeetingLinkForm extends StatefulWidget {
  const MeetingLinkForm({super.key, required this.controller, required this.session});

  final PairingController controller;
  final PairingSession session;

  @override
  State<MeetingLinkForm> createState() => _MeetingLinkFormState();
}

class _MeetingLinkFormState extends State<MeetingLinkForm> {
  late final _link = TextEditingController(text: widget.session.meetingLink ?? '');
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
    final refusal = await widget.controller.setMeetingLink(widget.session, value);
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
      title: 'Meeting Link',
      subtitle:
          '${whenLabel(widget.session.scheduledAt)}. ${widget.controller.pairing?.mentee.firstName ?? 'The mentee'} is notified when it changes. '
          'Leave it empty to clear it.',
      submitLabel: 'Save Link',
      busy: _busy,
      problem: _problem,
      onSubmit: _submit,
      children: [
        FieldBlock(
          label: 'Link',
          child: TextField(
            key: const ValueKey('meeting-link'),
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

// ---------------------------------------------------------------------------
// Goals, tasks
// ---------------------------------------------------------------------------

class GoalForm extends StatefulWidget {
  const GoalForm({super.key, required this.controller});

  final PairingController controller;

  @override
  State<GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<GoalForm> {
  final _title = TextEditingController();
  final _detail = TextEditingController();
  DateTime? _target;
  String? _problem;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_title.text.trim().length < 3) {
      setState(() => _problem = 'Enter a goal of at least 3 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final refusal = await widget.controller.addGoal(title: _title.text, detail: _detail.text, targetDate: _target);
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
      title: 'Add a Goal',
      subtitle: 'A goal you both agree to work towards. Either of you can update it.',
      submitLabel: 'Add Goal',
      busy: _busy,
      problem: _problem,
      onSubmit: _submit,
      children: [
        FieldBlock(
          label: 'Goal',
          child: TextField(
            key: const ValueKey('goal-title'),
            controller: _title,
            maxLength: 200,
            style: MentoringText.formInput,
            decoration: fieldDecoration('Lead a site audit on my own'),
          ),
        ),
        FieldBlock(
          label: 'Details (Optional)',
          child: TextField(
            key: const ValueKey('goal-detail'),
            controller: _detail,
            minLines: 2,
            maxLines: 4,
            maxLength: 2000,
            style: MentoringText.formInput,
            decoration: fieldDecoration('What success looks like'),
          ),
        ),
        FieldBlock(
          label: 'Target Date (Optional)',
          child: QuietButton(
            label: _target == null ? 'Select a Date' : dayLabel(_target!),
            icon: LucideIcons.calendar,
            onPressed: () async {
              final now = mentoringNow();
              final day = await showDatePicker(
                context: context,
                initialDate: _target ?? now.add(const Duration(days: 30)),
                firstDate: now,
                lastDate: now.add(const Duration(days: 730)),
              );
              if (day != null && mounted) setState(() => _target = day);
            },
          ),
        ),
      ],
    );
  }
}

class TaskForm extends StatefulWidget {
  const TaskForm({super.key, required this.controller});

  final PairingController controller;

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final _title = TextEditingController();
  DateTime? _due;
  String? _problem;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_title.text.trim().length < 2) {
      setState(() => _problem = 'Enter a task of at least 2 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final refusal = await widget.controller.addTask(title: _title.text, dueAt: _due);
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
      title: 'Add a Task',
      submitLabel: 'Add Task',
      busy: _busy,
      problem: _problem,
      onSubmit: _submit,
      children: [
        FieldBlock(
          label: 'Task',
          child: TextField(
            key: const ValueKey('task-title'),
            controller: _title,
            maxLength: 160,
            style: MentoringText.formInput,
            decoration: fieldDecoration('Draft the vendor scorecard'),
          ),
        ),
        FieldBlock(
          label: 'Due Date (Optional)',
          child: QuietButton(
            label: _due == null ? 'Select a Date' : dayLabel(_due!),
            icon: LucideIcons.calendar,
            onPressed: () async {
              final now = mentoringNow();
              final day = await showDatePicker(
                context: context,
                initialDate: _due ?? now.add(const Duration(days: 7)),
                firstDate: now,
                lastDate: now.add(const Duration(days: 365)),
              );
              if (day != null && mounted) setState(() => _due = DateTime(day.year, day.month, day.day, 18));
            },
          ),
        ),
      ],
    );
  }
}

class ProgressForm extends StatefulWidget {
  const ProgressForm({super.key, required this.controller, required this.goal});

  final PairingController controller;
  final PairingGoal goal;

  @override
  State<ProgressForm> createState() => _ProgressFormState();
}

class _ProgressFormState extends State<ProgressForm> {
  late double _value = widget.goal.progress.toDouble();
  String? _problem;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    final refusal = await widget.controller.setGoalProgress(widget.goal, _value.round());
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
      title: widget.goal.title,
      subtitle: 'Set the progress. 100% marks the goal as achieved.',
      submitLabel: 'Save Progress',
      busy: _busy,
      problem: _problem,
      onSubmit: _submit,
      children: [
        Text('${_value.round()}%', key: const ValueKey('progress-value'), style: MentoringText.statValue),
        Slider(
          key: const ValueKey('progress-slider'),
          value: _value,
          max: 100,
          divisions: 10,
          onChanged: (v) => setState(() => _value = v),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Notes, shared links, concerns, support
// ---------------------------------------------------------------------------

/// A note on the pairing's timeline: shared with the other person, or kept to the author.
class NoteForm extends StatefulWidget {
  const NoteForm({super.key, required this.controller});

  final PairingController controller;

  @override
  State<NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends State<NoteForm> {
  final _note = TextEditingController();
  bool _private = false;
  String? _problem;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_note.text.trim().isEmpty) {
      setState(() => _problem = 'Enter a note first.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final refusal = await widget.controller.addNote(_note.text, privateToMe: _private);
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
      title: 'Add a Note',
      subtitle: 'A timeline entry. Describe what happened and what is next.',
      submitLabel: 'Add Note',
      busy: _busy,
      problem: _problem,
      onSubmit: _submit,
      children: [
        FieldBlock(
          label: 'Note',
          child: TextField(
            key: const ValueKey('note-text'),
            controller: _note,
            minLines: 3,
            maxLines: 8,
            maxLength: 4000,
            style: MentoringText.formInput,
            decoration: fieldDecoration('What happened, what is next'),
          ),
        ),
        SwitchListTile.adaptive(
          key: const ValueKey('note-private'),
          contentPadding: EdgeInsets.zero,
          value: _private,
          onChanged: (v) => setState(() => _private = v),
          title: Text('Private. Only you can see it.', style: MentoringText.formLabel),
        ),
      ],
    );
  }
}

/// Asks the phone for a file: a PDF or an image, which is what the API's `mentorship-resource` upload takes.
typedef SharePicker = Future<PickedShare?> Function();

const shareExtensions = ['pdf', 'png', 'jpg', 'jpeg', 'webp'];

/// The API stops a file here (10 MB).
const maxShareBytes = 10 * 1024 * 1024;

String? shareMimeOf(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return null;
  return switch (name.substring(dot + 1).toLowerCase()) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    _ => null,
  };
}

Future<PickedShare?> pickShareFile() async {
  final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: shareExtensions);
  if (file == null) return null;
  return PickedShare(bytes: await file.readAsBytes(), name: file.name, mimeType: shareMimeOf(file.name));
}

/// Why a picked file would be refused before it is sent, or null.
String? shareFileProblem(PickedShare f) {
  final dot = f.name.lastIndexOf('.');
  final ext = dot < 0 ? '' : f.name.substring(dot + 1).toLowerCase();
  if (!shareExtensions.contains(ext)) return 'Share a PDF or an image (PNG, JPG or WebP).';
  if (f.bytes.length > maxShareBytes) return 'The file is larger than 10 MB.';
  return null;
}

/// Shares a link or a file (a document, a recording, a template) with the other person.
class ResourceLinkForm extends StatefulWidget {
  const ResourceLinkForm({super.key, required this.controller, this.pickFile = pickShareFile});

  final PairingController controller;

  /// The file chooser: the phone's by default, a test's stand-in otherwise.
  final SharePicker pickFile;

  @override
  State<ResourceLinkForm> createState() => _ResourceLinkFormState();
}

class _ResourceLinkFormState extends State<ResourceLinkForm> {
  final _title = TextEditingController();
  final _url = TextEditingController();
  final _note = TextEditingController();
  String _kind = 'OTHER';
  bool _file = false;
  PickedShare? _picked;
  String? _problem;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    final f = await widget.pickFile();
    if (f == null || !mounted) return;
    final bad = shareFileProblem(f);
    setState(() {
      _problem = bad;
      _picked = bad == null ? f : null;
      if (bad == null && _title.text.trim().isEmpty) {
        _title.text = f.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
      }
    });
  }

  Future<void> _submit() async {
    if (_title.text.trim().length < 2) {
      setState(() => _problem = 'Enter a title of at least 2 characters.');
      return;
    }
    if (_file) {
      if (_picked == null) {
        setState(() => _problem = 'Choose the file to share.');
        return;
      }
    } else {
      if (_url.text.trim().isEmpty) {
        setState(() => _problem = 'Paste the link to share.');
        return;
      }
      final bad = linkProblem(_url.text, max: 2000);
      if (bad != null) {
        setState(() => _problem = bad);
        return;
      }
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final refusal = _file
        ? await widget.controller.addResourceFile(file: _picked!, title: _title.text, kind: _kind, note: _note.text)
        : await widget.controller.addResourceLink(
            title: _title.text,
            url: normaliseLink(_url.text),
            kind: _kind,
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
      title: _file ? 'Share a File' : 'Share a Link',
      subtitle: 'The other person sees it on this page.',
      submitLabel: 'Share',
      busy: _busy,
      problem: _problem,
      onSubmit: _submit,
      children: [
        FieldBlock(
          label: 'Link or File',
          child: Wrap(
            spacing: 6,
            children: [
              ChoiceChip(
                key: const ValueKey('share-link'),
                label: const Text('Link'),
                selected: !_file,
                onSelected: (_) => setState(() => _file = false),
              ),
              ChoiceChip(
                key: const ValueKey('share-file'),
                label: const Text('File'),
                selected: _file,
                onSelected: (_) => setState(() => _file = true),
              ),
            ],
          ),
        ),
        FieldBlock(
          label: 'Title',
          child: TextField(
            key: const ValueKey('resource-title'),
            controller: _title,
            maxLength: 160,
            style: MentoringText.formInput,
            decoration: fieldDecoration('Handover checklist template'),
          ),
        ),
        if (_file)
          FieldBlock(
            label: 'File',
            help: 'A PDF or an image, up to 10 MB.',
            child: Row(
              children: [
                QuietButton(
                  key: const ValueKey('choose-file'),
                  label: _picked == null ? 'Choose a File' : 'Choose Another',
                  icon: LucideIcons.paperclip,
                  onPressed: _busy ? null : _choose,
                ),
                if (_picked != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_picked!.name} · ${fileSizeLabel(_picked!.bytes.length)}',
                      key: const ValueKey('picked-file'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MentoringText.meta,
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          FieldBlock(
            label: 'Link',
            child: TextField(
              key: const ValueKey('resource-url'),
              controller: _url,
              keyboardType: TextInputType.url,
              style: MentoringText.formInput,
              decoration: fieldDecoration('https://'),
            ),
          ),
        FieldBlock(
          label: 'Resource Type',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final MapEntry(key: key, value: label) in resourceKinds.entries)
                ChoiceChip(label: Text(label), selected: _kind == key, onSelected: (_) => setState(() => _kind = key)),
            ],
          ),
        ),
        FieldBlock(
          label: 'Why It Is Useful (Optional)',
          child: TextField(
            key: const ValueKey('resource-note'),
            controller: _note,
            minLines: 2,
            maxLines: 3,
            maxLength: 500,
            style: MentoringText.formInput,
            decoration: fieldDecoration('Start with section 3'),
          ),
        ),
      ],
    );
  }
}

class ConcernForm extends StatefulWidget {
  const ConcernForm({super.key, required this.controller});

  final PairingController controller;

  @override
  State<ConcernForm> createState() => _ConcernFormState();
}

class _ConcernFormState extends State<ConcernForm> {
  final _detail = TextEditingController();
  ConcernCategory _category = ConcernCategory.conduct;
  bool _urgent = false;
  String? _problem;
  bool _busy = false;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_detail.text.trim().length < 10) {
      setState(() => _problem = 'Describe what happened in at least 10 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final refusal = await widget.controller.raiseConcern(
      category: _category,
      detail: _detail.text,
      urgent: _urgent || _category == ConcernCategory.safety,
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
      title: 'Report a Concern',
      subtitle: 'This goes to ICR\'s safeguarding team, not to the other person.',
      submitLabel: 'Send to ICR',
      busy: _busy,
      problem: _problem,
      onSubmit: _submit,
      children: [
        FieldBlock(
          label: 'Concern Type',
          help: _category.hint,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in ConcernCategory.values)
                ChoiceChip(
                  label: Text(c.label),
                  selected: c == _category,
                  onSelected: (_) => setState(() => _category = c),
                ),
            ],
          ),
        ),
        FieldBlock(
          label: 'What Happened',
          child: TextField(
            key: const ValueKey('concern-detail'),
            controller: _detail,
            minLines: 4,
            maxLines: 8,
            maxLength: 4000,
            style: MentoringText.formInput,
            decoration: fieldDecoration('What happened, and when'),
          ),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _urgent || _category == ConcernCategory.safety,
          onChanged: _category == ConcernCategory.safety ? null : (v) => setState(() => _urgent = v),
          title: Text('Mark as Urgent', style: MentoringText.formLabel),
        ),
      ],
    );
  }
}

/// "Contact ICR Support": an ordinary request about a record (not a conduct concern, which is confidential).
class SupportForm extends StatefulWidget {
  const SupportForm({super.key, required this.onSend, this.about = 'this mentorship'});

  final Future<String?> Function(String subject, String body) onSend;
  final String about;

  @override
  State<SupportForm> createState() => _SupportFormState();
}

class _SupportFormState extends State<SupportForm> {
  final _subject = TextEditingController();
  final _body = TextEditingController();
  String? _problem;
  bool _busy = false;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_subject.text.trim().length < 5) {
      setState(() => _problem = 'Enter a subject of at least 5 characters.');
      return;
    }
    if (_body.text.trim().length < 10) {
      setState(() => _problem = 'Describe what went wrong in at least 10 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final refusal = await widget.onSend(_subject.text, _body.text);
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
      title: 'Contact ICR Support',
      subtitle: 'About ${widget.about}. For conduct issues, use "Report a Concern". It stays private.',
      submitLabel: 'Send',
      busy: _busy,
      problem: _problem,
      onSubmit: _submit,
      children: [
        FieldBlock(
          label: 'Subject',
          child: TextField(
            key: const ValueKey('support-subject'),
            controller: _subject,
            maxLength: 160,
            style: MentoringText.formInput,
            decoration: fieldDecoration('The booking will not load'),
          ),
        ),
        FieldBlock(
          label: 'What Happened',
          child: TextField(
            key: const ValueKey('support-body'),
            controller: _body,
            minLines: 4,
            maxLines: 8,
            maxLength: 8000,
            style: MentoringText.formInput,
            decoration: fieldDecoration('What you did, and what you saw'),
          ),
        ),
      ],
    );
  }
}
