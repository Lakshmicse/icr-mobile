import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../become_mentor/become_mentor_models.dart' show competencyDomains;
import '../../mentorship_my/mentoring_clock.dart';
import '../../mentorship_my/mentoring_format.dart' show dayLabel, inr, normaliseLink, whenLabel;
import 'composer_kit.dart';
import 'group_schedule.dart';
import 'group_schedule_view.dart';
import 'offering_fields.dart' show pickAndUpload;
import 'offerings_controller.dart';
import 'offerings_files.dart';
import 'offerings_models.dart';
import 'offerings_repository.dart' show PickedUpload, platformFeeBps;
import 'offerings_rules.dart';

/// The ways a group session can meet (`MentorshipMode`): virtual (the API's VIDEO) or in person. Phone and chat
/// were taken off, and "Video call" reads "Virtual" (owner, 7 Nov 2026).
const groupModes = <String, String>{'VIDEO': 'Virtual', 'IN_PERSON': 'In Person'};

/// A cover the website's `CoverImageField` takes: 2 MB at most.
const _maxCoverBytes = 2 * 1024 * 1024;

/// Hosts a group session, edits one ([existing]), or runs one again ([copyFrom]: everything but the dates, saved
/// as a new draft), full screen, as the website's "Host a group session" page does (`GroupSessionComposer`; owner,
/// 14 Nov 2026: "implement these in the mentorship in the mobile app as it is fields"). Resolves true when saved.
Future<bool> openGroupComposer(
  BuildContext context, {
  required OfferingsController controller,
  HostedSession? existing,
  HostedSession? copyFrom,
  OfferingFilePicker pickFile = pickOfferingFile,
}) => pushComposer(
  context,
  (_) => GroupSessionComposer(controller: controller, existing: existing, copyFrom: copyFrom, pickFile: pickFile),
);

/// The composer's older name (the Offerings panel opened it in a sheet before it was a page).

/// The six numbered sections of the website's composer, laid one under another for a phone: The Pitch, When,
/// Where, The Room, The Price, Get Found. Validated as the website's `groupSessionIssues` and its schedule verdict
/// are; saved as a draft or published in the same call; several new dates may be one series or separate sessions
/// (`POST /mentorship/group-sessions/batch`). Days that have run are shown and sent back verbatim.
class GroupSessionComposer extends StatefulWidget {
  const GroupSessionComposer({
    super.key,
    required this.controller,
    this.existing,
    this.copyFrom,
    this.pickFile = pickOfferingFile,
  });

  final OfferingsController controller;
  final HostedSession? existing;
  final HostedSession? copyFrom;
  final OfferingFilePicker pickFile;

  @override
  State<GroupSessionComposer> createState() => _GroupSessionComposerState();
}

class _GroupSessionComposerState extends State<GroupSessionComposer> {
  late final HostedSession? _source = widget.existing ?? widget.copyFrom;
  bool get _editing => widget.existing != null;

  /// The session as read in full (its detail): the list holds no agenda, outcomes or link.
  HostedSession? _session;
  bool _loading = false;
  String? _loadError;

  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _outcomes = TextEditingController();
  final _agenda = TextEditingController();
  final _link = TextEditingController();
  final _venue = TextEditingController();
  final _capacity = TextEditingController(text: '12');
  final _price = TextEditingController();
  String? _cover;
  String? _coverProblem;
  bool _uploading = false;
  String _mode = 'VIDEO';

  /// The venue's pin, from the session being edited; kept only while its address line is unchanged.
  double? _lat;
  double? _lng;
  String? _pinnedVenue;
  bool _paid = false;
  bool _capped = true;
  bool _waitlist = true;
  List<String> _topics = [];

  bool _seeded = false;
  bool _zoneTouched = false;
  bool _attempted = false;
  String? _problem;

  /// Which button is working ('draft' or 'publish'), so only its label says so.
  String? _pending;
  int _feeBps = platformFeeBps;

  late final GroupSchedule _s;
  final _scroll = ScrollController();
  final _sections = {
    for (final s in ['pitch', 'when', 'where', 'room', 'price']) s: GlobalKey(),
  };

  /// The busy calendar, read slice by slice (the API serves `maxBusyRangeDays` a call).
  final _busySlices = <String, List<BusyInterval>>{};
  final _busyAsked = <String>{};

  @override
  void initState() {
    super.initState();
    _s = GroupSchedule(editing: _editing, timezone: phoneZone(), now: mentoringNow)..addListener(_onSchedule);
    for (final c in [_title, _summary, _outcomes, _agenda, _link, _venue, _capacity, _price]) {
      c.addListener(_redraw);
    }
    final source = _source;
    if (source != null) {
      if (source.roster != null) {
        _hydrate(source);
      } else {
        _read(source);
      }
    }
    unawaited(_readDefaults());
    unawaited(
      widget.controller.mentorFeeBps().then((bps) {
        if (mounted) setState(() => _feeBps = bps);
      }),
    );
    _ensureBusy();
    _ready = true;
  }

  @override
  void dispose() {
    _s
      ..removeListener(_onSchedule)
      ..dispose();
    for (final c in [_title, _summary, _outcomes, _agenda, _link, _venue, _capacity, _price]) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  /// Set once [initState] has run: a schedule change before then (hydration) needs no redraw.
  bool _ready = false;

  void _onSchedule() {
    if (!mounted) return;
    if (_ready) setState(() {});
    _ensureBusy();
  }

  // --- reading -----------------------------------------------------------------------------------------------

  Future<void> _read(HostedSession source) async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final d = await widget.controller.detail(source);
      if (!mounted) return;
      _hydrate(d);
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  /// Editing or copying: the session's own fields. A copy keeps the days' topics and lengths, never their dates.
  void _hydrate(HostedSession s) {
    _session = s;
    final copying = !_editing;
    _title.text = s.title;
    _summary.text = s.summary ?? '';
    _outcomes.text = s.outcomes.join('\n');
    _agenda.text = agendaTextOf(s.agendaHtml);
    _cover = s.coverUrl;
    final tz = s.timezone ?? 'Asia/Kolkata';
    final now = mentoringNow();
    final days = s.days.isNotEmpty
        ? s.days
        : [SessionDay(id: '', seq: 1, at: s.at, durationMin: s.durationMin, status: 'SCHEDULED')];
    _s.load([
      for (final d in days)
        rowFromDay(
          id: d.id.isEmpty ? null : d.id,
          at: d.at,
          durationMin: d.durationMin,
          status: d.status,
          title: d.title,
          tz: tz,
          copy: copying,
          draft: s.draft,
          now: now,
        ),
    ], tz);
    _zoneTouched = true;
    _mode = groupModes.containsKey(s.mode) ? s.mode : 'VIDEO';
    _link.text = s.meetingLink ?? '';
    _venue.text = s.location ?? '';
    _lat = s.locationLat;
    _lng = s.locationLng;
    _pinnedVenue = s.location;
    _paid = s.pricePaisa != null;
    _price.text = s.pricePaisa == null ? '' : '${(s.pricePaisa! / 100).round()}';
    _capped = s.capacity != null;
    _capacity.text = '${s.capacity ?? 12}';
    // A paid session's stored false is the rule, not the mentor's choice.
    _waitlist = s.pricePaisa != null || (s.waitlistEnabled ?? true);
    _topics = [...s.competencies];
  }

  /// The mentor's weekly hours always; for a new session also its standing link, zone and group defaults, laid
  /// only over what is still untouched.
  Future<void> _readDefaults() async {
    final p = await widget.controller.composerDefaults();
    if (!mounted || p == null) return;
    _s
      ..windows = p.windows
      ..windowsTz = p.timezone ?? 'Asia/Kolkata';
    if (_source == null && !_seeded) {
      _seeded = true;
      if (_link.text.isEmpty) _link.text = p.meetingLink ?? '';
      if (p.seats != null && _capacity.text == '12') _capacity.text = '${p.seats}';
      if (p.waitlist != null && _waitlist) _waitlist = p.waitlist!;
      if (p.durationMin != null && _s.rows.isEmpty) _s.setDuration(DurationPicker.clamp(p.durationMin!));
      if (p.timezone != null && !_zoneTouched && !_s.zonePicked) _s.setTimezone(p.timezone!);
    }
    setState(() {});
  }

  void _ensureBusy() {
    final (from, to) = _s.busyWindow;
    final except = widget.existing?.id;
    const slice = Duration(days: maxBusyRangeDays);
    for (var at = from; at.isBefore(to); at = at.add(slice)) {
      final end = at.add(slice).isAfter(to) ? to : at.add(slice);
      final key = '${at.toIso8601String()}|${end.toIso8601String()}';
      if (!_busyAsked.add(key)) continue;
      unawaited(
        widget.controller.busyBetween(at, end, except: except).then((intervals) {
          if (!mounted || intervals == null) return;
          _busySlices[key] = intervals;
          final seen = <String>{};
          _s.setBusy([
            for (final list in _busySlices.values)
              for (final b in list)
                if (seen.add('${b.kind}|${b.start.toIso8601String()}|${b.end.toIso8601String()}')) b,
          ]);
        }),
      );
    }
  }

  // --- rules ---------------------------------------------------------------------------------------------------

  Map<GroupField, String> get _issues => groupSessionIssues(
    title: _title.text,
    summary: _summary.text,
    outcomes: _outcomes.text,
    agenda: _agenda.text,
    inPerson: _mode == 'IN_PERSON',
    meetingLink: _link.text,
    location: _venue.text,
    capped: _capped,
    capacity: _capacity.text,
    paid: _paid,
    priceRupees: _price.text,
  );

  String? _shown(GroupField f) => _attempted ? _issues[f] : null;

  /// Repricing after a seat is sold would charge two people differently for the same room.
  bool get _priceLocked => _editing && (_session?.seatsTaken ?? 0) > 0 && _session?.pricePaisa != null;

  /// Editing something already open for registration: nothing to publish.
  bool get _alreadyLive => _editing && _session != null && !_session!.draft;

  bool get _separate => !_editing && _s.mode == RegistrationMode.separate && _s.rows.length > 1;

  String? get _sellerBlocked {
    final g = widget.controller.gates;
    if (g == null || g.live) return null;
    return g.blockedReason ?? 'Your storefront is not open yet.';
  }

  ({bool ok, bool free, int clashDay}) get _scheduleState {
    final v = _s.verdict;
    final server = _s.serverClash;
    final clashes = v.clashes + (server != null ? 1 : 0);
    final datesOk = v.complete && v.overCap == 0 && v.issues.values.every((i) => i is ClashIssue || i is DraftIssue);
    final firstClash = server?.day ?? (v.rows.indexWhere((r) => v.issues[r.key] is ClashIssue) + 1);
    return (ok: datesOk && clashes == 0, free: clashes == 0, clashDay: firstClash);
  }

  // --- saving -------------------------------------------------------------------------------------------------

  Future<void> _submit(bool publish) async {
    setState(() => _problem = null);
    final issues = _issues;
    final schedule = _scheduleState;
    if (!schedule.ok || issues.isNotEmpty) {
      // Say what is wrong instead of a greyed-out button: flag every field and go to the first.
      setState(() {
        _attempted = true;
        _problem = 'Some details need fixing before this can be saved. They are highlighted below.';
      });
      final field = GroupField.values.where(issues.containsKey).firstOrNull;
      final target = field == null
          ? (schedule.ok ? null : 'when')
          : switch (field) {
              GroupField.title || GroupField.summary || GroupField.outcomes || GroupField.agenda => 'pitch',
              GroupField.meetingLink || GroupField.location => 'where',
              GroupField.capacity => 'room',
              GroupField.price => 'price',
            };
      final ctx = target == null ? null : _sections[target]!.currentContext;
      if (ctx != null) {
        unawaited(Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), alignment: 0.02));
      }
      return;
    }
    setState(() => _pending = publish ? 'publish' : 'draft');
    final tz = _s.timezone;
    final venue = _venue.text.trim();
    final link = _link.text.trim();
    final inPerson = _mode == 'IN_PERSON';
    final summary = _summary.text.trim();
    final shared = <String, Object?>{
      'title': _title.text.trim(),
      if (summary.isNotEmpty) 'summary': summary,
      'outcomes': outcomeLines(_outcomes.text),
      if (_agenda.text.trim().isNotEmpty) 'agendaHtml': agendaHtmlOf(_agenda.text),
      'coverUrl': _cover,
      'mode': _mode,
      // Typed without https://, it is sent with it (as the API would store it).
      if (link.isNotEmpty) 'meetingLink': normaliseLink(link),
      if (venue.isNotEmpty) 'location': venue,
      // Only an in-person venue carries a pin, and only the one its address was pinned with.
      if (inPerson && _lat != null && _lng != null && venue == _pinnedVenue) ...{
        'locationLat': _lat,
        'locationLng': _lng,
      },
      'timezone': tz,
      'capacity': _capped ? int.parse(_capacity.text.trim()) : null,
      // Paid sessions run without a waitlist; the API enforces it too.
      'waitlistEnabled': _paid ? false : _waitlist,
      'competencies': _topics,
      'pricePaisa': _paid ? (num.parse(_price.text.trim()) * 100).round() : null,
      'publish': publish,
    };
    final occurrences = toOccurrences(_s.rows, tz);
    final refusal = _separate
        ? await widget.controller.saveComposedSession({
            ...shared,
            'dates': [
              for (final o in occurrences) {'scheduledAt': o['scheduledAt'], 'durationMin': o['durationMin']},
            ],
          }, separate: true)
        : await widget.controller.saveComposedSession({...shared, 'occurrences': occurrences}, id: widget.existing?.id);
    if (!mounted) return;
    if (refusal == null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _pending = null;
      _problem = refusal.message;
    });
    // The calendar gate names the day it refused; the list shows it there.
    if (refusal.code == groupDayClashCode && refusal.day != null) {
      _s.setServerClash(ServerClash(day: refusal.day!, message: refusal.message));
    }
  }

  Future<void> _pickCover() async {
    setState(() {
      _uploading = true;
      _coverProblem = null;
    });
    var tooLarge = false;
    final stored = await pickAndUpload(
      pick: ({required bool imageOnly}) async {
        final f = await widget.pickFile(imageOnly: imageOnly);
        if (f != null && f.bytes.length > _maxCoverBytes) {
          tooLarge = true;
          return null;
        }
        return f;
      },
      upload: (PickedUpload f) => widget.controller.upload(f, purpose: 'group-session'),
      imageOnly: true,
      problem: (p) => _coverProblem = p,
    );
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (tooLarge) _coverProblem = 'The image is larger than 2 MB.';
      if (stored != null) _cover = stored.url;
    });
  }

  Future<void> _pickTopics() async {
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      builder: (_) => _TopicsSheet(selected: _topics),
    );
    if (picked != null && mounted) setState(() => _topics = picked);
  }

  // --- drawing -------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final title = _editing ? 'Edit Group Session' : 'Host a Group Session';
    if (_loading || _loadError != null) {
      return ComposerPage(
        title: title,
        saveLabel: 'Save Changes',
        onSave: null,
        sections: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
                : Column(
                    children: [
                      Text('Unable to Open This Session', style: ComposerText.sectionTitle),
                      const SizedBox(height: 6),
                      Text(_loadError!, style: ComposerText.bodyMuted, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        key: const ValueKey('group-load-retry'),
                        onPressed: () => _read(_source!),
                        child: Text('Try Again', style: ComposerText.link),
                      ),
                    ],
                  ),
          ),
        ],
      );
    }

    final schedule = _scheduleState;
    final n = _s.rows.length;
    final live = _alreadyLive;
    final separate = _separate;
    final saveLabel = live
        ? 'Save Changes'
        : separate
        ? 'Publish $n Sessions'
        : (_editing ? 'Save and Publish' : 'Publish');
    return ComposerPage(
      title: title,
      lead: 'Host a group session with its own agenda and meeting room. Your 1:1 availability stays unaffected.',
      scrollController: _scroll,
      problem: _problem,
      busy: _pending != null,
      busyLabel: _pending == 'publish' ? 'Publishing…' : (live ? 'Saving…' : saveLabel),
      saveLabel: saveLabel,
      onSave: () => _submit(!live),
      secondaryLabel: live ? null : (_pending == 'draft' ? 'Saving…' : (separate ? 'Save $n Drafts' : 'Save as Draft')),
      onSecondary: live ? null : () => _submit(false),
      blocker: !schedule.free && schedule.clashDay > 0
          ? 'Day ${schedule.clashDay} clashes with a booking. Change its time or remove it.'
          : null,
      footnote: live
          ? 'Moving the date re-sends the reminders to everyone registered.'
          : separate
          ? 'Each date becomes its own listing. Publish opens registration for all $n. '
                'Drafts stay invisible until you publish each one.'
          : 'Publish opens registration right away. A draft stays invisible until you publish it.',
      sections: [
        _pitch(),
        ComposerSection(
          key: _sections['when'],
          step: 2,
          title: 'When',
          subtitle: 'Select dates on the calendar and choose a time. Each date can have its own time if needed.',
          children: [ScheduleSection(s: _s, registered: _editing ? _session?.seatsTaken : null)],
        ),
        _where(),
        _room(),
        _priceSection(),
        _getFound(),
      ],
    );
  }

  /// The count is said in the helper line, as the website's is.
  static Widget? _hiddenCounter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) => null;

  Widget _text(
    String key,
    TextEditingController c, {
    required String hint,
    int? max,
    int minLines = 1,
    int? maxLines = 1,
    String? error,
    TextInputType? keyboard,
    bool enabled = true,
    bool rupee = false,
  }) => TextField(
    key: ValueKey(key),
    controller: c,
    enabled: enabled,
    maxLength: max,
    buildCounter: max == null ? null : _hiddenCounter,
    minLines: minLines,
    maxLines: maxLines,
    keyboardType: keyboard ?? (maxLines == 1 ? null : TextInputType.multiline),
    style: ComposerText.body,
    decoration: composerDecoration(hint, error: error != null, rupee: rupee),
  );

  Widget _pitch() {
    final title = _shown(GroupField.title);
    final summary = _shown(GroupField.summary);
    final outcomes = _shown(GroupField.outcomes);
    final agenda = _shown(GroupField.agenda);
    return ComposerSection(
      key: _sections['pitch'],
      step: 1,
      first: true,
      title: 'The Pitch',
      subtitle: 'This appears on the session card and helps people decide whether to open it.',
      children: [
        ComposerField(
          label: 'Title',
          required: true,
          error: title,
          help: 'What people see when they browse the session list. · ${_title.text.length}/$maxGroupTitle',
          child: _text(
            'group-title',
            _title,
            hint: 'Office hours: your first FM budget',
            max: maxGroupTitle,
            error: title,
          ),
        ),
        ComposerField(
          label: 'One Line for the Card',
          optional: true,
          error: summary,
          help: '${_summary.text.length}/$maxGroupSummary',
          child: _text(
            'group-summary',
            _summary,
            hint: 'An hour on how to frame a portfolio case',
            max: maxGroupSummary,
          ),
        ),
        ComposerField(
          label: 'What People Will Learn',
          optional: true,
          error: outcomes,
          help:
              'Enter one outcome per line, up to $maxGroupOutcomes. The first three are highlighted on the session page.',
          child: _text(
            'group-outcomes',
            _outcomes,
            hint: 'How to read a facilities budget',
            minLines: 3,
            maxLines: 8,
            error: outcomes,
          ),
        ),
        ComposerField(
          label: 'Cover Image',
          optional: true,
          child: CoverImageField(
            keyPrefix: 'group-cover',
            url: _cover,
            busy: _uploading,
            problem: _coverProblem,
            help:
                'Displayed on the session card and at the top of the session page. PNG, JPG, or WEBP, up to 2 MB. '
                'Optional.',
            onPick: _pickCover,
            onRemove: () => setState(() => _cover = null),
          ),
        ),
        ComposerField(
          label: 'Agenda',
          optional: true,
          error: agenda,
          help: 'Describe the topics you will cover. Use blank lines to start new paragraphs.',
          child: _text(
            'group-agenda',
            _agenda,
            hint: 'What you will cover, in order',
            max: maxGroupAgenda,
            minLines: 4,
            maxLines: 12,
            error: agenda,
          ),
        ),
      ],
    );
  }

  Widget _where() {
    final inPerson = _mode == 'IN_PERSON';
    final venue = _shown(GroupField.location);
    final link = _shown(GroupField.meetingLink);
    return ComposerSection(
      key: _sections['where'],
      step: 3,
      title: 'Where',
      subtitle: 'Choose how participants will join the session.',
      children: [
        ComposerField(
          label: 'Format',
          child: DropdownButtonFormField<String>(
            key: const ValueKey('group-format'),
            initialValue: _mode,
            isExpanded: true,
            style: ComposerText.body,
            icon: const Icon(LucideIcons.chevronDown, size: 18, color: AppColors.onSurfaceVariant),
            decoration: composerDecoration(''),
            items: [
              for (final MapEntry(key: key, value: label) in groupModes.entries)
                DropdownMenuItem(key: ValueKey('mode-$key'), value: key, child: Text(label)),
            ],
            onChanged: (v) => setState(() => _mode = v ?? 'VIDEO'),
          ),
        ),
        if (inPerson)
          ComposerField(
            label: 'Venue',
            required: true,
            error: venue,
            help: 'The address people come to, with the room or floor.',
            child: _text(
              'group-venue',
              _venue,
              hint: 'ICR Bengaluru, 4th floor training room',
              max: maxGroupLocation,
              error: venue,
            ),
          )
        else
          ComposerField(
            label: 'Joining Link',
            required: true,
            error: link,
            help: 'This is visible only to registered participants.',
            child: _text(
              'group-link',
              _link,
              hint: 'https://meet.example.com/abc-defg-hij',
              max: maxGroupLink,
              keyboard: TextInputType.url,
              error: link,
            ),
          ),
      ],
    );
  }

  Widget _room() {
    final seats = _shown(GroupField.capacity);
    return ComposerSection(
      key: _sections['room'],
      step: 4,
      title: 'The Room',
      subtitle: 'Set the session capacity and choose what happens when all seats are filled.',
      children: [
        LabelledSwitch(
          keyName: 'group-capped',
          label: 'Limit the Seats',
          value: _capped,
          onChanged: (v) => setState(() => _capped = v),
        ),
        const SizedBox(height: 10),
        if (!_capped && seats != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(seats, key: const ValueKey('group-capacity-problem'), style: ComposerText.error),
          ),
        if (_capped)
          ComposerField(
            label: 'Seats',
            error: seats,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: SizedBox(
                width: 160,
                child: _text('group-capacity', _capacity, hint: '12', keyboard: TextInputType.number, error: seats),
              ),
            ),
          ),
        if (_capped && !_paid)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: LabelledSwitch(
              keyName: 'group-waitlist',
              label: 'Keep a Waitlist',
              value: _waitlist,
              onChanged: (v) => setState(() => _waitlist = v),
            ),
          ),
      ],
    );
  }

  Widget _priceSection() {
    final locked = _priceLocked;
    final blocked = _sellerBlocked;
    final typed = _price.text.trim();
    final issue = locked ? null : (typed.isNotEmpty ? _issues[GroupField.price] : _shown(GroupField.price));
    final ok = _issues[GroupField.price] == null;
    final paisa = ((num.tryParse(typed) ?? 0) * 100).round();
    final fee = (paisa * _feeBps / 10000).round();
    return ComposerSection(
      key: _sections['price'],
      step: 5,
      title: 'The Price',
      subtitle: 'Choose whether the session is free or paid.',
      children: [
        FreePaidToggle(
          keyPrefix: 'group-price',
          paid: _paid,
          enabled: !locked,
          paidEnabled: blocked == null,
          onChanged: (v) => setState(() {
            _paid = v;
            // A paid room needs a size; nothing else about the room changes.
            if (v) _capped = true;
          }),
        ),
        if (blocked != null && !_paid)
          ComposerNote(
            icon: LucideIcons.info,
            text: TextSpan(
              text: '$blocked Charging for seats needs the same seller terms as the rest of your storefront.',
            ),
          ),
        if (_paid) ...[
          ComposerField(
            label: 'Price per Seat (₹)',
            required: true,
            error: issue,
            help: locked
                ? 'Seats are already sold at this price.'
                : 'At least ${inr(minSeatPricePaisa)}. GST is added at checkout.',
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: SizedBox(
                width: 220,
                child: _text(
                  'group-price',
                  _price,
                  hint: '499',
                  enabled: !locked,
                  keyboard: const TextInputType.numberWithOptions(decimal: true),
                  error: issue,
                ),
              ),
            ),
          ),
          if (ok && typed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'ICR keeps ${_feeBps % 100 == 0 ? '${_feeBps ~/ 100}' : '${_feeBps / 100}'}%. '
                'You receive ${inr(paisa - fee)} per seat.',
                key: const ValueKey('group-fee-line'),
                style: ComposerText.help,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Seats are sold through checkout, so a paid session has no waitlist. A queue of people who have not paid '
              'cannot be honoured.',
              style: ComposerText.help,
            ),
          ),
        ],
      ],
    );
  }

  Widget _getFound() {
    return ComposerSection(
      step: 6,
      title: 'Get Found',
      subtitle: 'Topics help participants find your session through search and filters.',
      children: [
        ComposerField(
          label: 'Topics',
          optional: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectBox(
                key: const ValueKey('group-topics'),
                text: _topics.isEmpty ? 'Select topics' : '${_topics.length} selected',
                muted: _topics.isEmpty,
                icon: LucideIcons.tag,
                onTap: _pickTopics,
              ),
              if (_topics.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in _topics)
                      InputChip(
                        key: ValueKey('topic-chip-$t'),
                        label: Text(t, style: ComposerText.help.copyWith(color: AppColors.onSurface)),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.outlineVariant),
                        shape: const StadiumBorder(),
                        deleteIcon: const Icon(LucideIcons.x, size: 14),
                        onDeleted: () => setState(() => _topics = [..._topics]..remove(t)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The ICR competency domains a session is filed under (the website's `COMPETENCY_DOMAINS`), searchable, ticked.
class _TopicsSheet extends StatefulWidget {
  const _TopicsSheet({required this.selected});

  final List<String> selected;

  @override
  State<_TopicsSheet> createState() => _TopicsSheetState();
}

class _TopicsSheetState extends State<_TopicsSheet> {
  late final List<String> _picked = [...widget.selected];
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final options = [...widget.selected.where((t) => !competencyDomains.contains(t)), ...competencyDomains];
    final q = _q.trim().toLowerCase();
    final shown = [
      for (final o in options)
        if (q.isEmpty || o.toLowerCase().contains(q)) o,
    ];
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                Expanded(child: Text('Topics', style: ComposerText.sectionTitle)),
                TextButton(
                  key: const ValueKey('topics-done'),
                  onPressed: () => Navigator.pop(context, _picked),
                  child: Text('Done', style: ComposerText.link),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              key: const ValueKey('topics-search'),
              onChanged: (v) => setState(() => _q = v),
              style: ComposerText.body,
              decoration: composerDecoration(
                'Search topics',
              ).copyWith(prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.onSurfaceVariant)),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final o in shown)
                  InkWell(
                    key: ValueKey('topic-$o'),
                    onTap: () => setState(() => _picked.contains(o) ? _picked.remove(o) : _picked.add(o)),
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(child: Text(o, style: ComposerText.body)),
                          Icon(
                            _picked.contains(o) ? LucideIcons.squareCheck : LucideIcons.square,
                            size: 20,
                            color: _picked.contains(o) ? AppColors.primary : AppColors.slate400,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
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
