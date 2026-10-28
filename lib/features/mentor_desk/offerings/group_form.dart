import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../mentorship_my/mentoring_clock.dart';
import '../../mentorship_my/mentoring_format.dart' show dayLabel, whenLabel;
import '../../mentorship_my/widgets/forms.dart';
import '../../mentorship_my/widgets/kit.dart';
import 'offerings_controller.dart';
import 'offerings_models.dart';
import 'offerings_rules.dart';

/// The ways a group session can meet (`MentorshipMode`).
const groupModes = <String, String>{'VIDEO': 'Video call', 'PHONE': 'Phone', 'IN_PERSON': 'In person', 'CHAT': 'Chat'};

class _Day {
  _Day({this.id, this.at, int minutes = 60, this.title, this.locked = false, this.status})
    : minutes = TextEditingController(text: '$minutes');

  final String? id;
  DateTime? at;
  final TextEditingController minutes;
  final String? title;

  /// A day that has run (or been closed): the API takes it back verbatim and refuses a change.
  final bool locked;
  final String? status;

  int? get minutesValue => int.tryParse(minutes.text.trim());
}

/// Hosts a group session, or edits one: title, what it is about, how and where it
/// meets, its days (one, or a run of up to ten), seats, a seat price (or free),
/// and whether it opens for registration now. Validated as the API's
/// `UpsertGroupSessionDto` and its service are; days that have already run are
/// shown, never editable (the API keeps them as the record).
class GroupSessionForm extends StatefulWidget {
  const GroupSessionForm({super.key, required this.controller, this.existing});

  final OfferingsController controller;
  final HostedSession? existing;

  @override
  State<GroupSessionForm> createState() => _GroupSessionFormState();
}

class _GroupSessionFormState extends State<GroupSessionForm> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _summary = TextEditingController(text: widget.existing?.summary ?? '');
  late final _agenda = TextEditingController(text: agendaTextOf(widget.existing?.agendaHtml));
  late final _venue = TextEditingController(text: widget.existing?.location ?? '');
  late final _link = TextEditingController(text: widget.existing?.meetingLink ?? '');
  late final _capacity = TextEditingController(
    text: widget.existing == null ? '25' : (widget.existing!.capacity == null ? '' : '${widget.existing!.capacity}'),
  );
  late final _price = TextEditingController(
    text: widget.existing?.pricePaisa == null ? '' : rupeesOf(widget.existing!.pricePaisa),
  );
  late String _mode = widget.existing?.mode ?? 'VIDEO';
  bool _waitlist = true;
  bool _publish = false;
  final _days = <_Day>[];
  String? _problem;
  bool _busy = false;

  bool get _editing => widget.existing != null;
  bool get _editingDraft => widget.existing?.draft ?? false;
  bool get _paid => _price.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e == null) {
      _days.add(_Day(at: null));
    } else {
      final now = mentoringNow();
      for (final d in e.days) {
        // A draft has no record, so every day of it may be re-set; a live one keeps the days that ran.
        final locked = !e.draft && (!d.scheduled || !d.at.isAfter(now));
        _days.add(
          _Day(id: d.id, at: d.at.toLocal(), minutes: d.durationMin, title: d.title, locked: locked, status: d.status),
        );
      }
      if (_days.isEmpty) _days.add(_Day(at: null));
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _summary, _agenda, _venue, _link, _capacity, _price]) {
      c.dispose();
    }
    for (final d in _days) {
      d.minutes.dispose();
    }
    super.dispose();
  }

  String? _validate() {
    final title = groupTitleProblem(_title.text);
    if (title != null) return title;
    if (_summary.text.trim().length > maxGroupSummary) return 'Keep the summary under $maxGroupSummary characters.';
    if (_agenda.text.trim().length > maxGroupAgenda) return 'Keep the agenda under $maxGroupAgenda characters.';
    final place = groupPlaceProblem(
      inPerson: _mode == 'IN_PERSON',
      location: _venue.text,
      link: _link.text,
      // On create the API stands the mentor's own link in for a blank one: it judges that.
      standingLink: !_editing,
    );
    if (place != null) return place;
    final now = mentoringNow();
    final pairs = <(DateTime, int)>[];
    for (final d in _days) {
      if (d.at == null) return 'Pick a date and time for every day.';
      final m = d.minutesValue;
      if (m == null) return 'A day runs $minSessionMinutes to $maxSessionMinutes minutes.';
      if (!d.locked && !d.at!.isAfter(now)) return 'Pick a time in the future.';
      pairs.add((d.at!, m));
    }
    final days = daysProblem(pairs, now, requireFuture: false);
    if (days != null) return days;
    final cap = capacityProblem(_capacity.text);
    if (cap != null) return cap;
    return seatPriceProblem(price: _price.text, capacity: _capacity.text);
  }

  Map<String, Object?> _body() {
    final e = widget.existing;
    final sorted = [..._days]..sort((a, b) => a.at!.compareTo(b.at!));
    final cap = _capacity.text.trim().isEmpty ? null : int.parse(_capacity.text.trim());
    final inPerson = _mode == 'IN_PERSON';
    return {
      'title': _title.text.trim(),
      if (_summary.text.trim().isNotEmpty) 'summary': _summary.text.trim(),
      if (_agenda.text.trim().isNotEmpty) 'agendaHtml': agendaHtmlOf(_agenda.text),
      'mode': _mode,
      if (!inPerson && linkValue(_link.text) != null) 'meetingLink': linkValue(_link.text),
      if (inPerson) 'location': _venue.text.trim(),
      'occurrences': [
        for (final d in sorted)
          {
            'id': ?d.id,
            if (d.title != null) 'title': d.title,
            'scheduledAt': d.at!.toUtc().toIso8601String(),
            'durationMin': d.minutesValue,
          },
      ],
      'capacity': cap,
      'pricePaisa': _paid ? paisaOf(_price.text) : null,
      if (!_editing) 'waitlistEnabled': _paid ? false : _waitlist,
      // An edit replaces what it does not name: send back what the session already holds.
      if (e != null) ...{
        'coverUrl': e.coverUrl,
        if (e.timezone != null) 'timezone': e.timezone,
        if (inPerson && e.locationLat != null && e.locationLng != null) ...{
          'locationLat': e.locationLat,
          'locationLng': e.locationLng,
        },
      },
      if (_publish && (!_editing || _editingDraft)) 'publish': true,
    };
  }

  Future<void> _submit() async {
    final bad = _validate();
    if (bad != null) {
      setState(() => _problem = bad);
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final refusal = await widget.controller.saveSession(_body(), id: widget.existing?.id);
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
      title: _editing ? 'Edit group session' : 'Host a group session',
      subtitle: _editing
          ? 'People who registered are told when the time moves. Days that already ran cannot change.'
          : 'A clinic or a short series (up to $maxGroupDays days). Free sessions keep a waitlist; a seat price turns it off.',
      submitLabel: _editing
          ? (_publish && _editingDraft ? 'Save and publish' : 'Save')
          : (_publish ? 'Publish' : 'Save draft'),
      busy: _busy,
      problem: _problem,
      onSubmit: _submit,
      children: [
        FieldBlock(
          label: 'Title',
          child: TextField(
            key: const ValueKey('group-title'),
            controller: _title,
            maxLength: maxGroupTitle,
            style: MentoringText.formInput,
            decoration: fieldDecoration('From site to portfolio: an open clinic'),
          ),
        ),
        FieldBlock(
          label: 'Summary (optional)',
          child: TextField(
            key: const ValueKey('group-summary'),
            controller: _summary,
            minLines: 2,
            maxLines: 4,
            maxLength: maxGroupSummary,
            style: MentoringText.formInput,
            decoration: fieldDecoration('An hour on how to frame a portfolio case'),
          ),
        ),
        FieldBlock(
          label: 'Agenda (optional)',
          help: 'Plain text; a blank line starts a new paragraph.',
          child: TextField(
            key: const ValueKey('group-agenda'),
            controller: _agenda,
            minLines: 3,
            maxLines: 8,
            style: MentoringText.formInput,
            decoration: fieldDecoration('What you will cover, in order'),
          ),
        ),
        FieldBlock(
          label: 'How it meets',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final MapEntry(key: key, value: label) in groupModes.entries)
                ChoiceChip(
                  key: ValueKey('mode-$key'),
                  label: Text(label),
                  selected: _mode == key,
                  onSelected: (_) => setState(() => _mode = key),
                ),
            ],
          ),
        ),
        if (_mode == 'IN_PERSON')
          FieldBlock(
            label: 'Venue',
            child: TextField(
              key: const ValueKey('group-venue'),
              controller: _venue,
              maxLength: maxGroupLocation,
              style: MentoringText.formInput,
              decoration: fieldDecoration('Prestige Tech Park, Bengaluru'),
            ),
          )
        else
          FieldBlock(
            label: 'Joining link',
            help: _editing ? null : 'Leave it empty to use the standing link on your mentor profile.',
            child: TextField(
              key: const ValueKey('group-link'),
              controller: _link,
              keyboardType: TextInputType.url,
              style: MentoringText.formInput,
              decoration: fieldDecoration('https://meet.google.com/abc-defg-hij'),
            ),
          ),
        FieldBlock(
          label: _days.length == 1 ? 'When' : 'Days',
          child: Column(children: [for (final (i, d) in _days.indexed) _dayRow(i, d)]),
        ),
        if (_days.length < maxGroupDays)
          Align(
            alignment: Alignment.centerLeft,
            child: QuietButton(
              key: const ValueKey('day-add'),
              label: 'Add a day',
              icon: LucideIcons.plus,
              onPressed: () => setState(() => _days.add(_Day(at: null))),
            ),
          ),
        const SizedBox(height: 14),
        FieldBlock(
          label: 'Seats ($minGroupSeats to $maxGroupSeats; empty for no limit)',
          child: TextField(
            key: const ValueKey('group-capacity'),
            controller: _capacity,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            style: MentoringText.formInput,
            decoration: fieldDecoration('25'),
          ),
        ),
        FieldBlock(
          label: 'Seat price (₹, empty for a free session)',
          help: 'Charged seats start at ₹499 and need a number of seats. A paid session has no waitlist.',
          child: TextField(
            key: const ValueKey('group-price'),
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            style: MentoringText.formInput,
            decoration: fieldDecoration('299'),
          ),
        ),
        if (!_editing)
          SwitchListTile.adaptive(
            key: const ValueKey('group-waitlist'),
            contentPadding: EdgeInsets.zero,
            value: _paid ? false : _waitlist,
            onChanged: _paid ? null : (v) => setState(() => _waitlist = v),
            title: Text('Keep a waitlist when it fills', style: MentoringText.formLabel),
          ),
        if (!_editing || _editingDraft)
          SwitchListTile.adaptive(
            key: const ValueKey('group-publish'),
            contentPadding: EdgeInsets.zero,
            value: _publish,
            onChanged: (v) => setState(() => _publish = v),
            title: Text('Open for registration now', style: MentoringText.formLabel),
            subtitle: Text(
              _editing ? 'Off keeps it a draft: nobody can register.' : 'Off saves a draft you can publish later.',
              style: MentoringText.meta,
            ),
          ),
      ],
    );
  }

  Widget _dayRow(int i, _Day d) {
    if (d.locked) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            const Icon(LucideIcons.lock, size: 14, color: AppColors.outline),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${whenLabel(d.at!)} · ${d.minutes.text} min · ${d.status == 'CANCELLED' ? 'Cancelled' : 'Held'}',
                key: ValueKey('day-locked-$i'),
                style: MentoringText.body,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: QuietButton(
              key: ValueKey('day-pick-$i'),
              label: d.at == null ? 'Pick a date and time' : whenLabel(d.at!),
              icon: LucideIcons.calendarClock,
              onPressed: () async {
                final at = await pickDateTime(context, initial: d.at);
                if (at != null && mounted) setState(() => d.at = at);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              key: ValueKey('day-minutes-$i'),
              controller: d.minutes,
              keyboardType: TextInputType.number,
              style: MentoringText.formInput,
              decoration: fieldDecoration('min'),
            ),
          ),
          if (_days.length > 1)
            IconButton(
              key: ValueKey('day-remove-$i'),
              tooltip: 'Remove this day',
              onPressed: () => setState(() => _days.removeAt(i).minutes.dispose()),
              icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.outline),
            ),
        ],
      ),
    );
  }
}

/// "Mon 26 Oct" for a series' first day, with how many days it spans.
String seriesLine(HostedSession s) {
  final first = s.days.isEmpty ? s.at : s.days.first.at;
  return s.days.length > 1
      ? '${dayLabel(first)} and ${s.days.length - 1} more day${s.days.length == 2 ? '' : 's'}'
      : whenLabel(first);
}
