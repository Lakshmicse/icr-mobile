import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../account/widgets/account_kit.dart';
import '../events/event_format.dart' show ist;
import '../events/event_models.dart' show EventKind;
import 'events_manage_kit.dart';
import 'events_manage_models.dart';
import 'events_manage_repository.dart';
import 'events_manage_rules.dart';

/// Where the event sheet reaches the phone's day and time dialogs, behind one seam so a test can answer for them.
class EventPickers {
  const EventPickers();

  Future<DateTime?> pickDay(BuildContext context, {required DateTime initial, String? help}) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
    helpText: help,
  );

  Future<TimeOfDay?> pickTime(BuildContext context, {required TimeOfDay initial, String? help}) =>
      showTimePicker(context: context, initialTime: initial, helpText: help);
}

/// Opens the event sheet (the website's `EventDialog`, staff mode); true when saved. [onSave] sends the body and
/// answers the API's refusal, or null.
Future<bool> showEventFormSheet(
  BuildContext context, {
  required EventsManageRepository repository,
  required Future<String?> Function(Map<String, Object?> body) onSave,
  ManagedEvent? event,
  EventPickers pickers = const EventPickers(),
}) async =>
    await showEditSheet<bool>(
      context,
      builder: (_) => EventFormSheet(repository: repository, onSave: onSave, event: event, pickers: pickers),
    ) ??
    false;

/// Create or edit an event: every field of the website's form — title and slug, type, capacity and ticket price,
/// the host chapter or council, the venue (with address suggestions), when it starts and ends, the description as
/// fields, whether it is listed, whether it is invite-only and until when talks are taken. Times are on the Indian
/// clock, the one every Events screen of the app reads.
class EventFormSheet extends StatefulWidget {
  const EventFormSheet({
    super.key,
    required this.repository,
    required this.onSave,
    this.event,
    this.pickers = const EventPickers(),
  });

  final EventsManageRepository repository;
  final Future<String?> Function(Map<String, Object?> body) onSave;
  final ManagedEvent? event;
  final EventPickers pickers;

  @override
  State<EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<EventFormSheet> {
  late final EventDraft _d = EventDraft.of(widget.event);
  late final _title = TextEditingController(text: _d.title);
  late final _slug = TextEditingController(text: _d.slug);
  late final _capacity = TextEditingController(text: _d.capacity);
  late final _price = TextEditingController(text: _d.price);
  late final _location = TextEditingController(text: _d.location);
  late final Map<String, TextEditingController> _about = {
    for (final s in eventDescriptionSections) s.key: TextEditingController(text: _d.about[s.key] ?? ''),
  };

  List<OrgRef> _chapters = const [];
  List<OrgRef> _councils = const [];
  List<String> _suggestions = const [];
  Timer? _suggestTimer;
  int _suggestRun = 0;

  /// One token from the first letter to the pick: Google bills that as one session.
  String _session = _newSession();

  bool _saving = false;
  bool _dirty = false;
  bool _checked = false;
  String? _error;

  bool get _editing => widget.event != null;

  static String _newSession() => '${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(1 << 32)}';

  @override
  void initState() {
    super.initState();
    widget.repository.chapters().then((list) {
      if (mounted) setState(() => _chapters = list);
    }, onError: (Object _) {});
    widget.repository.councils().then((list) {
      if (mounted) setState(() => _councils = list);
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _suggestTimer?.cancel();
    _title.dispose();
    _slug.dispose();
    _capacity.dispose();
    _price.dispose();
    _location.dispose();
    for (final c in _about.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _touch(VoidCallback change) => setState(() {
    change();
    _dirty = true;
  });

  Map<String, String> get _problems => _checked ? _d.problems() : const {};

  // --- hosts -------------------------------------------------------------------------------------------------------

  static const _none = OrgRef(id: '', name: 'None');

  /// The list a host picker offers: None, what the API listed, and the event's own host if the list lacks it.
  List<OrgRef> _options(List<OrgRef> listed, OrgRef? own) => [
    _none,
    ...listed,
    if (own != null && !listed.contains(own)) own,
  ];

  String? _nameOf(String id, List<OrgRef> listed, OrgRef? own) {
    if (id.isEmpty) return null;
    return listed.where((o) => o.id == id).firstOrNull?.name ?? (own?.id == id ? own!.name : null);
  }

  Future<void> _pickChapter() async {
    final options = _options(_chapters, widget.event?.chapter);
    final picked = await showAccountPicker<OrgRef>(
      context,
      title: 'Host Chapter',
      items: options,
      labelOf: (o) => o.name,
      searchable: options.length > 8,
      selected: options.where((o) => o.id == _d.chapterId).firstOrNull,
    );
    if (picked == null) return;
    _touch(() {
      _d.chapterId = picked.id;
      // An event has one host: a chapter or a council.
      if (picked.id.isNotEmpty) _d.councilId = '';
    });
  }

  Future<void> _pickCouncil() async {
    final options = _options(_councils, widget.event?.council);
    final picked = await showAccountPicker<OrgRef>(
      context,
      title: 'Host Council',
      items: options,
      labelOf: (o) => o.name,
      searchable: options.length > 8,
      selected: options.where((o) => o.id == _d.councilId).firstOrNull,
    );
    if (picked == null) return;
    _touch(() {
      _d.councilId = picked.id;
      if (picked.id.isNotEmpty) _d.chapterId = '';
    });
  }

  Future<void> _pickKind() async {
    final picked = await showAccountPicker<EventKind>(
      context,
      title: 'Type',
      items: EventKind.values,
      labelOf: (k) => k.label,
      selected: EventKind.fromApi(_d.kind),
    );
    if (picked == null) return;
    _touch(() => _d.kind = picked.apiKey);
  }

  // --- the venue ---------------------------------------------------------------------------------------------------

  void _locationTyped(String text) {
    _touch(() => _d.location = text);
    _suggestTimer?.cancel();
    final q = text.trim();
    if (q.length < 3) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
      return;
    }
    _suggestTimer = Timer(const Duration(milliseconds: 500), () async {
      final run = ++_suggestRun;
      final found = await widget.repository.addresses(q, session: _session).catchError((Object _) => <String>[]);
      if (!mounted || run != _suggestRun || _location.text.trim() != q) return;
      setState(() => _suggestions = found.where((s) => s != q).take(5).toList());
    });
  }

  void _pickSuggestion(String label) {
    _suggestTimer?.cancel();
    _suggestRun += 1;
    _session = _newSession();
    _location.text = label;
    _touch(() {
      _d.location = label;
      _suggestions = const [];
    });
  }

  // --- when --------------------------------------------------------------------------------------------------------

  /// A day then a time, both on the Indian clock; null when either dialog is backed out of.
  Future<DateTime?> _pickMoment(DateTime? current, {required String help, DateTime? fallback}) async {
    final base = ist(current ?? fallback ?? DateTime.now().toUtc());
    final day = await widget.pickers.pickDay(context, initial: DateTime(base.year, base.month, base.day), help: help);
    if (day == null || !mounted) return null;
    final time = await widget.pickers.pickTime(
      context,
      initial: current == null && fallback == null
          ? const TimeOfDay(hour: 10, minute: 0)
          : TimeOfDay(hour: base.hour, minute: base.minute),
      help: help,
    );
    if (time == null) return null;
    return istWallToUtc(day.year, day.month, day.day, time.hour, time.minute);
  }

  Future<void> _pickStarts() async {
    final at = await _pickMoment(_d.startsAt, help: 'Starts');
    if (at != null) _touch(() => _d.startsAt = at);
  }

  Future<void> _pickEnds() async {
    final at = await _pickMoment(_d.endsAt, help: 'Ends', fallback: _d.startsAt?.add(const Duration(hours: 1)));
    if (at != null) _touch(() => _d.endsAt = at);
  }

  Future<void> _pickCall() async {
    final at = await _pickMoment(_d.callForSpeakersUntil, help: 'Call for Speakers Open Until');
    if (at != null) _touch(() => _d.callForSpeakersUntil = at);
  }

  // --- save --------------------------------------------------------------------------------------------------------

  Future<void> _save() async {
    for (final s in eventDescriptionSections) {
      _d.about[s.key] = _about[s.key]!.text;
    }
    final problems = _d.problems();
    if (problems.isNotEmpty) {
      setState(() {
        _checked = true;
        _error = problems.length == 1 ? problems.values.first : 'Check the fields marked in red.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final refusal = await widget.onSave(_d.toJson(create: !_editing));
    if (!mounted) return;
    if (refusal == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = refusal;
    });
  }

  @override
  Widget build(BuildContext context) {
    final problems = _problems;
    return EditSheet(
      title: _editing ? 'Edit Event' : 'Create Event',
      subtitle: _editing ? widget.event!.title : null,
      saving: _saving,
      error: _error,
      dirty: _dirty,
      saveLabel: _editing ? 'Save Changes' : 'Create Event',
      onSave: _saving ? null : _save,
      children: [
        AccountField(
          fieldKey: const Key('event.title'),
          label: 'Title',
          required: true,
          controller: _title,
          maxLength: eventTitleMax,
          error: problems['title'],
          onChanged: (v) => _touch(() {
            _d.title = v;
            // A new event's address follows its title.
            if (!_editing) {
              _d.slug = slugify(v);
              _slug.text = _d.slug;
            }
          }),
        ),
        AccountField(
          fieldKey: const Key('event.slug'),
          label: 'Slug',
          controller: _slug,
          textCapitalization: TextCapitalization.none,
          helper: 'The event’s address: /events/${_d.slug.isEmpty ? '…' : _d.slug}',
          error: problems['slug'],
          onChanged: (v) => _touch(() => _d.slug = slugify(v)),
        ),
        AccountSelectField(
          key: const Key('event.kind'),
          label: 'Type',
          hint: 'Select a type',
          value: EventKind.fromApi(_d.kind).label,
          onTap: _pickKind,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AccountField(
                fieldKey: const Key('event.capacity'),
                label: 'Capacity',
                controller: _capacity,
                keyboardType: TextInputType.number,
                helper: 'Blank = unlimited',
                error: problems['capacity'],
                onChanged: (v) => _touch(() => _d.capacity = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AccountField(
                fieldKey: const Key('event.price'),
                label: 'Ticket Price (₹)',
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                helper: 'Blank = free. GST is added at checkout.',
                error: problems['price'],
                onChanged: (v) => _touch(() => _d.price = v),
              ),
            ),
          ],
        ),
        AccountSelectField(
          key: const Key('event.chapter'),
          label: 'Host Chapter',
          hint: 'None',
          value: _nameOf(_d.chapterId, _chapters, widget.event?.chapter),
          onTap: _pickChapter,
        ),
        AccountSelectField(
          key: const Key('event.council'),
          label: 'Host Council',
          hint: 'None',
          value: _nameOf(_d.councilId, _councils, widget.event?.council),
          onTap: _pickCouncil,
        ),
        AccountField(
          fieldKey: const Key('event.location'),
          label: 'Location',
          controller: _location,
          maxLength: eventLocationMax,
          hint: 'Search a venue or address, or type Online',
          helper: _suggestions.isEmpty ? 'Pick a suggestion, or type any place.' : null,
          error: problems['location'],
          onChanged: _locationTyped,
        ),
        if (_suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, s) in _suggestions.indexed) ...[
                  InkWell(
                    key: ValueKey('event.suggestion.$i'),
                    onTap: () => _pickSuggestion(s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 18, color: AppColors.outline),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(s, style: EmText.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const EmHairline(),
                ],
              ],
            ),
          ),
        AccountSelectField(
          key: const Key('event.startsAt'),
          label: 'Starts',
          required: true,
          hint: 'Select a day and time',
          value: _d.startsAt == null ? null : dayTimeLabel(_d.startsAt!),
          error: problems['startsAt'],
          onTap: _pickStarts,
        ),
        AccountSelectField(
          key: const Key('event.endsAt'),
          label: 'Ends',
          hint: 'Select a day and time',
          value: _d.endsAt == null ? null : dayTimeLabel(_d.endsAt!),
          error: problems['endsAt'],
          onTap: _pickEnds,
          onClear: _d.endsAt == null ? null : () => _touch(() => _d.endsAt = null),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 10),
          child: Text('Description', style: EmText.heading),
        ),
        for (final s in eventDescriptionSections)
          AccountField(
            fieldKey: Key('event.about.${s.key}'),
            label: s.heading,
            controller: _about[s.key]!,
            maxLines: 8,
            minLines: s.list ? 3 : 2,
            helper: s.helper,
            onChanged: (v) => _touch(() => _d.about[s.key] = v),
          ),
        if (problems['description'] != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(problems['description']!, style: AccountText.error),
          ),
        if (_d.extra.isNotEmpty) const Padding(padding: EdgeInsets.only(bottom: 14), child: _ExtraNote()),
        AccountCheck(
          key: const Key('event.published'),
          value: _d.published,
          label: _d.published ? 'Published (listed publicly)' : 'Unpublished (hidden)',
          onChanged: (on) => _touch(() => _d.published = on),
        ),
        AccountCheck(
          key: const Key('event.inviteOnly'),
          value: _d.inviteOnly,
          label: 'Invite only — on the board and open to RSVP only for members on the guest list',
          onChanged: (on) => _touch(() => _d.inviteOnly = on),
        ),
        const SizedBox(height: 6),
        AccountSelectField(
          key: const Key('event.callForSpeakers'),
          label: 'Call for Speakers Open Until',
          hint: 'Not taking talk proposals',
          value: _d.callForSpeakersUntil == null ? null : dayTimeLabel(_d.callForSpeakersUntil!),
          helper:
              'Leave blank when not taking talk proposals. Members offer a talk from the event page; review them '
              'under Speakers.',
          onTap: _pickCall,
          onClear: _d.callForSpeakersUntil == null ? null : () => _touch(() => _d.callForSpeakersUntil = null),
        ),
      ],
    );
  }
}

class _ExtraNote extends StatelessWidget {
  const _ExtraNote();

  @override
  Widget build(BuildContext context) => Text(
    'This description also has text outside these fields (added earlier). It is kept as it is and still shows on '
    'the public page.',
    style: AccountText.meta,
  );
}
