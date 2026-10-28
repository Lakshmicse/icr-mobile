import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../mentorship_my/mentoring_format.dart';
import '../mentorship_my/mentoring_models.dart';
import '../mentorship_my/widgets/forms.dart';
import '../mentorship_my/widgets/kit.dart';
import 'mentor_desk_controller.dart';
import 'mentor_desk_models.dart';

/// The API's limits (`MAX_AVAILABILITY_BLOCKS`, `MAX_MENTOR_CAPACITY`, the profile DTO).
const maxAvailabilityBlocks = 21;
const maxMentorCapacity = 10;
const maxAvailabilityNote = 280;
const maxBio = 20000;
const maxTimezone = 64;

/// Why a set of weekly windows would be refused, in the API's words (or ours for the cap), or null when fine.
String? hoursProblem(List<WeeklyBlock> blocks) {
  if (blocks.length > maxAvailabilityBlocks) return 'You can keep at most $maxAvailabilityBlocks windows.';
  for (final b in blocks) {
    if (b.endMin <= b.startMin) return 'Each window must end after it starts.';
  }
  final byDay = <int, List<WeeklyBlock>>{};
  for (final b in blocks) {
    byDay.putIfAbsent(b.weekday, () => []).add(b);
  }
  for (final list in byDay.values) {
    list.sort((a, b) => a.startMin.compareTo(b.startMin));
    for (var i = 1; i < list.length; i++) {
      if (list[i].startMin < list[i - 1].endMin) return 'Windows on the same day must not overlap.';
    }
  }
  return null;
}

/// The weekly hours the mentor takes calls in. Edit a day, then save: the API replaces them all at once.
class DeskHoursTab extends StatefulWidget {
  const DeskHoursTab({super.key, required this.controller});

  final MentorDeskController controller;

  @override
  State<DeskHoursTab> createState() => _DeskHoursTabState();
}

class _DeskHoursTabState extends State<DeskHoursTab> {
  List<WeeklyBlock>? _blocks;
  bool _busy = false;
  String? _problem;

  /// Monday first, as the week reads on a phone; the API's 0 is Sunday.
  static const _order = [1, 2, 3, 4, 5, 6, 0];

  List<WeeklyBlock> get _saved => widget.controller.settings.data?.blocks ?? const [];

  List<WeeklyBlock> get _working => _blocks ?? _saved;

  bool get _dirty {
    final a = [..._working]..sort(_by);
    final b = [..._saved]..sort(_by);
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return true;
    }
    return false;
  }

  static int _by(WeeklyBlock a, WeeklyBlock b) {
    final d = a.weekday.compareTo(b.weekday);
    return d != 0 ? d : a.startMin.compareTo(b.startMin);
  }

  Future<void> _addWindows() async {
    final result = await showModalBottomSheet<List<WeeklyBlock>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _WindowForm(existing: _working),
    );
    if (result == null || result.isEmpty || !mounted) return;
    setState(() {
      _blocks = [..._working, ...result]..sort(_by);
      _problem = null;
    });
  }

  Future<void> _save() async {
    final blocks = _working;
    final bad = hoursProblem(blocks);
    if (bad != null) {
      setState(() => _problem = bad);
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final refusal = await widget.controller.saveHours(blocks);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (refusal == null) {
        _blocks = null;
      } else {
        _problem = refusal;
      }
    });
    if (refusal == null) showMessage(context, 'Hours saved.');
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = c.settings.data;
    final loading = s == null && c.settings.loading;
    final failed = s == null ? c.settings.error : null;
    final blocks = _working;
    final children = <Widget>[
      if (s != null) ...[
        Callout(
          tone: PillTone.blue,
          text:
              'Members book calls with you inside these windows, in ${s.timezone}. '
              'Your phone may be in another timezone: the times here are yours, as you set them.',
        ),
        const SizedBox(height: 4),
        for (final day in _order)
          _DayRow(
            day: day,
            blocks: [
              for (final b in blocks)
                if (b.weekday == day) b,
            ]..sort(_by),
            onRemove: (b) => setState(() {
              _blocks = [
                for (final x in blocks)
                  if (x != b) x,
              ];
              _problem = null;
            }),
          ),
        if (blocks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'No hours set. Without them members can still ask you for a time, and you pick it.',
              style: MentoringText.body,
            ),
          ),
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_problem!, style: MentoringText.error),
          ),
        ActionWrap(
          top: 14,
          children: [
            QuietButton(
              key: const ValueKey('add-window'),
              label: 'Add a window',
              icon: LucideIcons.plus,
              onPressed: _addWindows,
            ),
            SolidButton(label: 'Save hours', busy: _busy, onPressed: _dirty ? _save : null),
            if (_dirty) QuietButton(label: 'Discard', onPressed: () => setState(() => _blocks = null)),
          ],
        ),
      ],
    ];
    return LoadedList(
      loading: loading,
      error: failed,
      errorTitle: "Couldn't load your hours",
      onRefresh: () async {
        setState(() => _blocks = null);
        await c.refreshTab(DeskTab.hours);
      },
      children: loading || failed != null ? const [] : children,
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.blocks, required this.onRemove});

  final int day;
  final List<WeeklyBlock> blocks;
  final ValueChanged<WeeklyBlock> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('day-$day'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardRule),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 96, child: Text(weekdayNames[day], style: MentoringText.bodyStrong)),
          Expanded(
            child: blocks.isEmpty
                ? Text('Not available', style: MentoringText.meta)
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final b in blocks)
                        InputChip(
                          key: ValueKey('window-$day-${b.startMin}-${b.endMin}'),
                          label: Text(b.span),
                          onDeleted: () => onRemove(b),
                          deleteButtonTooltipMessage: 'Remove ${weekdayNames[day]} ${b.span}',
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Adds one window, on one or several days.
class _WindowForm extends StatefulWidget {
  const _WindowForm({required this.existing});

  final List<WeeklyBlock> existing;

  @override
  State<_WindowForm> createState() => _WindowFormState();
}

class _WindowFormState extends State<_WindowForm> {
  final _days = <int>{};
  int _start = 18 * 60;
  int _end = 20 * 60;
  String? _problem;

  Future<void> _pick(bool start) async {
    final cur = start ? _start : _end;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60),
    );
    if (t == null || !mounted) return;
    setState(() {
      if (start) {
        _start = t.hour * 60 + t.minute;
      } else {
        _end = t.hour * 60 + t.minute;
      }
      _problem = null;
    });
  }

  void _add() {
    if (_days.isEmpty) {
      setState(() => _problem = 'Pick at least one day.');
      return;
    }
    final added = [for (final d in _days) WeeklyBlock(weekday: d, startMin: _start, endMin: _end)];
    final bad = hoursProblem([...widget.existing, ...added]);
    if (bad != null) {
      setState(() => _problem = bad);
      return;
    }
    Navigator.pop(context, added);
  }

  @override
  Widget build(BuildContext context) {
    return MentoringForm(
      title: 'Add a window',
      subtitle: 'The hours you take calls, on the days you pick.',
      submitLabel: 'Add window',
      problem: _problem,
      onSubmit: _add,
      children: [
        FieldBlock(
          label: 'Days',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in _DeskHoursTabState._order)
                FilterChip(
                  key: ValueKey('pick-day-$d'),
                  label: Text(weekdayNames[d].substring(0, 3)),
                  selected: _days.contains(d),
                  onSelected: (on) => setState(() {
                    on ? _days.add(d) : _days.remove(d);
                    _problem = null;
                  }),
                ),
            ],
          ),
        ),
        FieldBlock(
          label: 'From and to',
          child: Row(
            children: [
              Expanded(
                child: QuietButton(
                  key: const ValueKey('window-start'),
                  label: hm(_start),
                  icon: LucideIcons.clock,
                  onPressed: () => _pick(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: QuietButton(
                  key: const ValueKey('window-end'),
                  label: hm(_end),
                  icon: LucideIcons.clock,
                  onPressed: () => _pick(false),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

/// Plain text to the `<p>` paragraphs the API keeps (a blank line or a line break starts a paragraph).
String bioToHtml(String text) {
  final paragraphs = text.split(RegExp(r'\n+')).map((p) => p.trim()).where((p) => p.isNotEmpty);
  String esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  return paragraphs.map((p) => '<p>${esc(p)}</p>').join();
}

/// How the mentor meets and how much they take on: modes, rhythm, places, timezone, standing link, note, bio.
/// Only what changed is sent, and a bio is sent only when it was edited (the editor here is plain text, so an
/// untouched rich bio keeps its formatting).
class DeskSettingsTab extends StatefulWidget {
  const DeskSettingsTab({super.key, required this.controller});

  final MentorDeskController controller;

  @override
  State<DeskSettingsTab> createState() => _DeskSettingsTabState();
}

class _DeskSettingsTabState extends State<DeskSettingsTab> {
  final _timezone = TextEditingController();
  final _link = TextEditingController();
  final _note = TextEditingController();
  final _bio = TextEditingController();
  Set<String> _modes = {};
  String? _cadence;
  int _capacity = 2;
  DeskSettings? _loadedFor;
  String? _problem;
  bool _busy = false;

  @override
  void dispose() {
    _timezone.dispose();
    _link.dispose();
    _note.dispose();
    _bio.dispose();
    super.dispose();
  }

  /// Fills the form from the API's copy, once per copy (a save or a refresh brings a new one).
  void _fill(DeskSettings s) {
    if (identical(_loadedFor, s)) return;
    _loadedFor = s;
    _timezone.text = s.timezone;
    _link.text = s.meetingLink;
    _note.text = s.availabilityNote;
    _bio.text = plainText(s.bioHtml);
    _modes = {...s.preferredModes};
    _cadence = s.cadence;
    _capacity = s.capacity.clamp(1, maxMentorCapacity);
  }

  Map<String, dynamic> _changes(DeskSettings s) => {
    if (!_sameSet(_modes, s.preferredModes.toSet())) 'preferredModes': _modes.toList(),
    if (_cadence != null && _cadence != s.cadence) 'cadence': _cadence,
    if (_capacity != s.capacity) 'capacity': _capacity,
    if (_timezone.text.trim() != s.timezone) 'timezone': _timezone.text.trim(),
    if (_link.text.trim() != s.meetingLink) 'meetingLink': _link.text.trim().isEmpty ? '' : normaliseLink(_link.text),
    if (_note.text.trim() != s.availabilityNote.trim()) 'availabilityNote': _note.text.trim(),
    if (_bio.text.trim() != plainText(s.bioHtml).trim()) 'bioHtml': bioToHtml(_bio.text),
  };

  static bool _sameSet(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);

  Future<void> _save(DeskSettings s) async {
    final changes = _changes(s);
    if (changes.isEmpty) return;
    if (_modes.isEmpty) {
      setState(() => _problem = 'Pick at least one way you meet.');
      return;
    }
    if (_timezone.text.trim().isEmpty || _timezone.text.trim().length > maxTimezone) {
      setState(() => _problem = 'Give your timezone, for example Asia/Kolkata.');
      return;
    }
    final bad = linkProblem(_link.text);
    if (bad != null) {
      setState(() => _problem = bad);
      return;
    }
    if (_note.text.trim().length > maxAvailabilityNote) {
      setState(() => _problem = 'Keep the note on your availability under $maxAvailabilityNote characters.');
      return;
    }
    if (bioToHtml(_bio.text).length > maxBio) {
      setState(() => _problem = 'Your bio is too long: keep it under $maxBio characters.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final refusal = await widget.controller.saveSettings(changes);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _problem = refusal;
    });
    if (refusal == null) showMessage(context, 'Saved.');
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = c.settings.data;
    final loading = s == null && c.settings.loading;
    final failed = s == null ? c.settings.error : null;
    if (s != null) _fill(s);
    final children = <Widget>[
      if (s != null) ...[
        FieldBlock(
          label: 'How you meet',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final MapEntry(key: key, value: label) in meetingModes.entries)
                FilterChip(
                  key: ValueKey('mode-$key'),
                  label: Text(label),
                  selected: _modes.contains(key),
                  onSelected: (on) => setState(() {
                    on ? _modes.add(key) : _modes.remove(key);
                    _problem = null;
                  }),
                ),
            ],
          ),
        ),
        FieldBlock(
          label: 'How often you usually meet',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final MapEntry(key: key, value: label) in cadences.entries)
                ChoiceChip(
                  key: ValueKey('cadence-$key'),
                  label: Text(label),
                  selected: _cadence == key,
                  onSelected: (_) => setState(() => _cadence = key),
                ),
            ],
          ),
        ),
        FieldBlock(
          label: 'Mentees at a time',
          help: 'Places for free mentoring, 1 to $maxMentorCapacity. A paid programme or plan is separate.',
          child: Row(
            children: [
              IconButton.outlined(
                key: const ValueKey('capacity-down'),
                tooltip: 'Fewer places',
                onPressed: _capacity > 1 ? () => setState(() => _capacity--) : null,
                icon: const Icon(LucideIcons.minus, size: 16),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text('$_capacity', key: const ValueKey('capacity-value'), style: MentoringText.statValue),
              ),
              IconButton.outlined(
                key: const ValueKey('capacity-up'),
                tooltip: 'More places',
                onPressed: _capacity < maxMentorCapacity ? () => setState(() => _capacity++) : null,
                icon: const Icon(LucideIcons.plus, size: 16),
              ),
              const SizedBox(width: 12),
              Text('${s.openSlots} open now', style: MentoringText.meta),
            ],
          ),
        ),
        FieldBlock(
          label: 'Your timezone',
          help: 'Your weekly hours are read in it.',
          child: TextField(
            key: const ValueKey('timezone'),
            controller: _timezone,
            maxLength: maxTimezone,
            style: MentoringText.formInput,
            decoration: fieldDecoration('Asia/Kolkata'),
          ),
        ),
        FieldBlock(
          label: 'Your standing meeting link',
          help: 'Used for sessions where you set no link of your own. Leave it empty to clear it.',
          child: TextField(
            key: const ValueKey('standing-link'),
            controller: _link,
            keyboardType: TextInputType.url,
            style: MentoringText.formInput,
            decoration: fieldDecoration('https://meet.google.com/abc-defg-hij'),
          ),
        ),
        FieldBlock(
          label: 'A note on your availability',
          child: TextField(
            key: const ValueKey('availability-note'),
            controller: _note,
            minLines: 2,
            maxLines: 3,
            maxLength: maxAvailabilityNote,
            style: MentoringText.formInput,
            decoration: fieldDecoration('Weekday evenings after 7pm IST'),
          ),
        ),
        FieldBlock(
          label: 'How you mentor',
          help: 'Shown on your profile. A blank line starts a new paragraph.',
          child: TextField(
            key: const ValueKey('bio'),
            controller: _bio,
            minLines: 5,
            maxLines: 12,
            style: MentoringText.formInput,
            decoration: fieldDecoration('What you help with, and how'),
          ),
        ),
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_problem!, style: MentoringText.error),
          ),
        SolidButton(label: 'Save settings', busy: _busy, onPressed: () => _save(s)),
      ],
    ];
    return LoadedList(
      loading: loading,
      error: failed,
      errorTitle: "Couldn't load your settings",
      onRefresh: () async {
        _loadedFor = null;
        await c.refreshTab(DeskTab.settings);
      },
      children: loading || failed != null ? const [] : children,
    );
  }
}
