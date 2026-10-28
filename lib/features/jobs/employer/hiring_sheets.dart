import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/buttons.dart';
import '../../career/career_format.dart';
import '../../career/career_styles.dart';
import '../../career/career_widgets.dart';
import '../jobs_styles.dart';
import 'hiring_models.dart';
import 'job_rules.dart';

InputDecoration hiringDecoration({String? hint, String? prefix}) => InputDecoration(
  hintText: hint,
  prefixText: prefix,
  isDense: true,
  counterText: '',
  border: const OutlineInputBorder(),
);

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(text, style: JobsText.formLabel),
  );
}

class _Choices extends StatelessWidget {
  const _Choices({required this.keyPrefix, required this.options, required this.value, required this.onPick});

  final String keyPrefix;
  final List<(String, String)> options;
  final String value;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final (v, label) in options)
        ChoiceChip(
          key: ValueKey('$keyPrefix-$v'),
          label: Text(label),
          selected: value == v,
          onSelected: (_) => onPick(v),
        ),
    ],
  );
}

/// A sheet's frame: a grabber, the title, a scrolling body and the action pinned under it.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.children, required this.action});

  final String title;
  final List<Widget> children;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: AppColors.slate300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: CareerText.companyName)),
                  IconButton(
                    key: const ValueKey('sheet-close'),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(LucideIcons.x, size: 20),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
              ),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), child: action),
          ],
        ),
      ),
    );
  }
}

/// Books an interview round, or moves one to a new time or place. [onSubmit] sends it and hands back
/// the API's sentence when it is refused (the sheet stays open and shows it) or null when it went through.
Future<void> showInterviewSheet(
  BuildContext context, {
  required List<TeamMember> team,
  required Future<String?> Function(InterviewDraft draft) onSubmit,
  required DateTime Function() clock,
  String? meId,
  TeamInterview? existing,
  String? applicantName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (_) => InterviewSheet(
      team: team,
      meId: meId,
      existing: existing,
      applicantName: applicantName,
      clock: clock,
      onSubmit: onSubmit,
    ),
  );
}

class InterviewSheet extends StatefulWidget {
  const InterviewSheet({
    super.key,
    required this.team,
    required this.onSubmit,
    required this.clock,
    this.meId,
    this.existing,
    this.applicantName,
  });

  final List<TeamMember> team;
  final String? meId;
  final TeamInterview? existing;
  final String? applicantName;
  final DateTime Function() clock;
  final Future<String?> Function(InterviewDraft draft) onSubmit;

  @override
  State<InterviewSheet> createState() => _InterviewSheetState();
}

class _InterviewSheetState extends State<InterviewSheet> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _link = TextEditingController(text: widget.existing?.meetingLink ?? '');
  late final _location = TextEditingController(text: widget.existing?.location ?? '');
  late final _map = TextEditingController(text: widget.existing?.mapLink ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late DateTime? _date = widget.existing?.scheduledAt;
  late TimeOfDay? _time = widget.existing == null ? null : TimeOfDay.fromDateTime(widget.existing!.scheduledAt);
  late String _mode = widget.existing?.mode ?? 'VIDEO';
  late int _duration = widget.existing?.durationMins ?? 60;
  late final Set<String> _panel = {
    ...?widget.existing?.panel.map((p) => p.id),
    if (widget.existing == null && widget.meId != null) widget.meId!,
  };
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    for (final c in [_title, _link, _location, _map, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime? get _at {
    final d = _date;
    if (d == null) return null;
    final t = _time ?? const TimeOfDay(hour: 10, minute: 0);
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  InterviewDraft get _draft => InterviewDraft(
    scheduledAt: _at,
    title: _title.text,
    mode: _mode,
    durationMins: _duration,
    meetingLink: _mode == 'VIDEO' ? _link.text : '',
    location: _mode == 'IN_PERSON' ? _location.text : '',
    mapLink: _mode == 'IN_PERSON' ? _map.text : '',
    notes: _notes.text,
    interviewerIds: _panel.toList(),
  );

  Future<void> _pickDate() async {
    final now = widget.clock();
    final first = DateTime(now.year, now.month, now.day);
    final initial = _date != null && !_date!.isBefore(first) ? _date! : first.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: first.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time ?? const TimeOfDay(hour: 10, minute: 0));
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final draft = _draft;
    final problem = draft.problem(widget.clock());
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final error = await widget.onSubmit(draft);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _problem = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final at = _at;
    final team = widget.team;
    return _SheetFrame(
      title: editing ? 'Reschedule ${widget.existing!.name}' : 'Schedule an interview',
      action: PrimaryButton(
        key: const ValueKey('interview-save'),
        label: _busy ? 'Saving…' : (editing ? 'Save the new time' : 'Schedule interview'),
        icon: LucideIcons.calendarCheck,
        onPressed: _busy ? null : _save,
      ),
      children: [
        if (widget.applicantName != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'They are told by email and in the app, with the link or the address.',
              style: JobsText.formHelp,
            ),
          ),
        const _Label('Round name (optional)'),
        TextField(
          key: const ValueKey('interview-title'),
          controller: _title,
          style: JobsText.formInput,
          decoration: hiringDecoration(hint: 'Technical round'),
        ),
        const _Label('When'),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('interview-date'),
                onPressed: _pickDate,
                icon: const Icon(LucideIcons.calendar, size: 15),
                label: Text(_date == null ? 'Pick a date' : formatWeekday(_date!)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('interview-time'),
                onPressed: _pickTime,
                icon: const Icon(LucideIcons.clock, size: 15),
                label: Text(
                  _time == null
                      ? (_date == null ? 'Pick a time' : '10:00 AM')
                      : formatTime(DateTime(2000, 1, 1, _time!.hour, _time!.minute)),
                ),
              ),
            ),
          ],
        ),
        if (at != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(formatWhen(at), key: const ValueKey('interview-when'), style: CareerText.metaStrong),
          ),
        const _Label('How long'),
        _Choices(
          keyPrefix: 'interview-minutes',
          options: const [('30', '30 min'), ('45', '45 min'), ('60', '1 hour'), ('90', '90 min')],
          value: '$_duration',
          onPick: (v) => setState(() => _duration = int.parse(v)),
        ),
        const _Label('How'),
        _Choices(
          keyPrefix: 'interview-mode',
          options: const [('VIDEO', 'Video call'), ('IN_PERSON', 'In person'), ('PHONE', 'Phone call')],
          value: _mode,
          onPick: (v) => setState(() => _mode = v),
        ),
        if (_mode == 'VIDEO') ...[
          const _Label('Meeting link (optional)'),
          TextField(
            key: const ValueKey('interview-link'),
            controller: _link,
            keyboardType: TextInputType.url,
            style: JobsText.formInput,
            decoration: hiringDecoration(hint: 'https://meet.google.com/abc-defg-hij'),
          ),
        ],
        if (_mode == 'IN_PERSON') ...[
          const _Label('Address'),
          TextField(
            key: const ValueKey('interview-location'),
            controller: _location,
            maxLength: 300,
            minLines: 2,
            maxLines: 3,
            style: JobsText.formInput,
            decoration: hiringDecoration(hint: 'Floor 3, Northwind House, Andheri East'),
          ),
          const _Label('Map link (optional)'),
          TextField(
            key: const ValueKey('interview-map'),
            controller: _map,
            keyboardType: TextInputType.url,
            style: JobsText.formInput,
            decoration: hiringDecoration(hint: 'https://maps.app.goo.gl/AbCdEf123'),
          ),
        ],
        const _Label('Notes for the panel (optional)'),
        TextField(
          key: const ValueKey('interview-notes'),
          controller: _notes,
          minLines: 2,
          maxLines: 5,
          maxLength: JobLimits.interviewNotesMax,
          style: JobsText.formInput,
          decoration: hiringDecoration(hint: 'What screening found and what to probe'),
        ),
        const _Label('Panel'),
        if (team.isEmpty)
          Text('Only you can be on the panel for now.', key: const ValueKey('panel-empty'), style: CareerText.meta)
        else
          for (final m in team)
            CheckboxListTile(
              key: ValueKey('panel-${m.id}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _panel.contains(m.id),
              title: Text(m.id == widget.meId ? '${m.name} (you)' : m.name, style: CareerText.bodyStrong),
              subtitle: m.role.isEmpty ? null : Text(_roleWord(m.role), style: CareerText.meta),
              onChanged: (v) => setState(() => v == true ? _panel.add(m.id) : _panel.remove(m.id)),
            ),
        if (team.isEmpty && widget.meId != null && !_panel.contains(widget.meId))
          TextButton(
            key: const ValueKey('panel-add-me'),
            onPressed: () => setState(() => _panel.add(widget.meId!)),
            child: const Text('Add me to the panel'),
          ),
        if (_problem != null) FormProblem(_problem!),
      ],
    );
  }

  static String _roleWord(String role) => switch (role) {
    'COMPANY_ADMIN' => 'Company admin',
    'BRANCH_ADMIN' => 'Office admin',
    'RECRUITER' => 'Recruiter',
    'HIRING_MANAGER' => 'Hiring manager',
    _ => role.isEmpty ? '' : '${role[0]}${role.substring(1).toLowerCase().replaceAll('_', ' ')}',
  };
}

/// Makes an offer. [onSubmit] gets the draft and whether to send it now; it hands back the API's sentence or null.
Future<void> showOfferSheet(
  BuildContext context, {
  required Future<String?> Function(OfferDraft draft, bool send) onSubmit,
  required DateTime Function() clock,
  String? jobTitle,
  String? applicantName,
  TeamOffer? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (_) => OfferSheet(
      onSubmit: onSubmit,
      clock: clock,
      jobTitle: jobTitle,
      applicantName: applicantName,
      existing: existing,
    ),
  );
}

class OfferSheet extends StatefulWidget {
  const OfferSheet({
    super.key,
    required this.onSubmit,
    required this.clock,
    this.jobTitle,
    this.applicantName,
    this.existing,
  });

  final Future<String?> Function(OfferDraft draft, bool send) onSubmit;
  final DateTime Function() clock;
  final String? jobTitle;
  final String? applicantName;

  /// An offer being changed: the sheet starts from it. A sent offer can be changed but not sent twice.
  final TeamOffer? existing;

  @override
  State<OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends State<OfferSheet> {
  late final _amount = TextEditingController(text: widget.existing == null ? '' : '${widget.existing!.amount.round()}');
  late final _title = TextEditingController(text: widget.existing?.jobTitle ?? widget.jobTitle ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late String _period = widget.existing?.period ?? 'YEARLY';
  late DateTime? _joining = widget.existing?.joiningDate;
  late DateTime? _expires = widget.existing?.expiresAt;
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  OfferDraft get _draft => OfferDraft(
    amount: num.tryParse(_amount.text.trim()),
    period: _period,
    jobTitle: _title.text,
    joiningDate: _joining,
    expiresAt: _expires,
    notes: _notes.text,
  );

  Future<DateTime?> _day(DateTime? current, {required bool future}) async {
    final now = widget.clock();
    final first = DateTime(now.year, now.month, now.day).add(Duration(days: future ? 1 : 0));
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null && !current.isBefore(first) ? current : first.add(const Duration(days: 7)),
      firstDate: first,
      lastDate: first.add(const Duration(days: 730)),
    );
    return picked == null ? null : DateTime(picked.year, picked.month, picked.day, 18);
  }

  Future<void> _submit(bool send) async {
    final draft = _draft;
    final problem = draft.problem(widget.clock());
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final error = await widget.onSubmit(draft, send);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _problem = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sent = widget.existing?.status == 'SENT';
    return _SheetFrame(
      title: widget.existing == null ? 'Make an offer' : 'Change the offer',
      action: sent
          ? PrimaryButton(
              key: const ValueKey('offer-save'),
              label: _busy ? 'Saving…' : 'Save changes',
              icon: LucideIcons.check,
              onPressed: _busy ? null : () => _submit(false),
            )
          : Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('offer-draft'),
                    onPressed: _busy ? null : () => _submit(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save draft'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    key: const ValueKey('offer-send'),
                    label: _busy ? 'Sending…' : 'Send offer',
                    icon: LucideIcons.send,
                    onPressed: _busy ? null : () => _submit(true),
                  ),
                ),
              ],
            ),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            sent
                ? 'The offer is with ${widget.applicantName ?? 'the applicant'}. A change is sent to them.'
                : widget.applicantName == null
                ? 'Sending moves the application to Offer. The applicant accepts or declines in the app.'
                : 'Sending moves ${widget.applicantName}\'s application to Offer. They accept or decline in the app.',
            style: JobsText.formHelp,
          ),
        ),
        const _Label('Salary offered'),
        TextField(
          key: const ValueKey('offer-amount'),
          controller: _amount,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
          style: JobsText.formInput,
          decoration: hiringDecoration(hint: '650000', prefix: '₹ '),
        ),
        const _Label('Paid'),
        _Choices(
          keyPrefix: 'offer-period',
          options: const [('YEARLY', 'Per year'), ('MONTHLY', 'Per month'), ('HOURLY', 'Per hour')],
          value: _period,
          onPick: (v) => setState(() => _period = v),
        ),
        const _Label('Job title on the offer (optional)'),
        TextField(
          key: const ValueKey('offer-title'),
          controller: _title,
          style: JobsText.formInput,
          decoration: hiringDecoration(hint: widget.jobTitle ?? 'Facility Supervisor'),
        ),
        const _Label('Joining date (optional)'),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('offer-joining'),
                onPressed: () async {
                  final d = await _day(_joining, future: true);
                  if (d != null && mounted) setState(() => _joining = d);
                },
                icon: const Icon(LucideIcons.calendar, size: 15),
                label: Text(_joining == null ? 'Pick a date' : formatDay(_joining!, now: widget.clock(), year: true)),
              ),
            ),
            if (_joining != null)
              IconButton(
                key: const ValueKey('offer-joining-clear'),
                tooltip: 'Clear the joining date',
                onPressed: () => setState(() => _joining = null),
                icon: const Icon(LucideIcons.x, size: 16),
              ),
          ],
        ),
        const _Label('Reply by (optional)'),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('offer-expires'),
                onPressed: () async {
                  final d = await _day(_expires, future: true);
                  if (d != null && mounted) setState(() => _expires = d);
                },
                icon: const Icon(LucideIcons.calendarClock, size: 15),
                label: Text(_expires == null ? 'Pick a date' : formatDay(_expires!, now: widget.clock(), year: true)),
              ),
            ),
            if (_expires != null)
              IconButton(
                key: const ValueKey('offer-expires-clear'),
                tooltip: 'Clear the reply-by date',
                onPressed: () => setState(() => _expires = null),
                icon: const Icon(LucideIcons.x, size: 16),
              ),
          ],
        ),
        const _Label('Note to the applicant (optional)'),
        TextField(
          key: const ValueKey('offer-notes'),
          controller: _notes,
          minLines: 2,
          maxLines: 5,
          maxLength: 1000,
          style: JobsText.formInput,
          decoration: hiringDecoration(hint: 'Benefits, the first week, who to ask'),
        ),
        if (_problem != null) FormProblem(_problem!),
      ],
    );
  }
}

/// Asks why before an application is moved out of the pipeline: a note, optional, goes with the move.
/// Returns null when cancelled; the note (possibly empty) when confirmed.
Future<String?> askStageNote(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  bool destructive = false,
  String hint = 'A note for your team (optional)',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _StageNoteDialog(title: title, body: body, confirm: confirm, destructive: destructive, hint: hint),
  );
}

class _StageNoteDialog extends StatefulWidget {
  const _StageNoteDialog({
    required this.title,
    required this.body,
    required this.confirm,
    required this.destructive,
    required this.hint,
  });

  final String title;
  final String body;
  final String confirm;
  final bool destructive;
  final String hint;

  @override
  State<_StageNoteDialog> createState() => _StageNoteDialogState();
}

class _StageNoteDialogState extends State<_StageNoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('stage-note-dialog'),
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.body),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('stage-note'),
            controller: _controller,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            decoration: hiringDecoration(hint: widget.hint),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('stage-note-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey('stage-note-confirm'),
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          style: widget.destructive ? TextButton.styleFrom(foregroundColor: AppColors.error) : null,
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}
