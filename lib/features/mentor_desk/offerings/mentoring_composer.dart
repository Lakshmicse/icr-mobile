import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../become_mentor/become_mentor_models.dart' show mentorModes;
import '../../mentorship_my/mentoring_format.dart' show inr;
import '../mentor_desk_models.dart' show DeskSettings;
import '../mentor_desk_repository.dart';
import 'composer_kit.dart';
import 'offering_fields.dart' show pickAndUpload;
import 'offerings_controller.dart';
import 'offerings_files.dart';
import 'offerings_models.dart';
import 'offerings_rules.dart';

/// The 1:1 mentoring composer, as the website's (`MentoringComposer` + `composer/sections.tsx`, owner, 14 Nov 2026:
/// "implement these in the mentorship in the mobile app as it is fields with the mobile supportive width and design
/// ... just implement how the web is working"): Overview, Format, a Syllabus once there are several sessions,
/// Delivery, Pricing and Visibility, numbered and stacked full width.
///
/// One offering to mentors and mentees, two engines underneath, chosen by the session count: one session is a
/// `MentorService` ONE_ON_ONE (`POST/PATCH /mentor-services/mine`), two to twenty-four a CURRICULUM plan
/// (`POST/PATCH /mentor-plans`). Crossing between one and several carries the shared fields over. An offering keeps
/// the engine it was saved with, so editing holds the count to its side of that line and says why.
///
/// [service] edits a 1:1 session (held to one), [plan] a programme (held to 2–24), neither makes a new offering, which
/// starts as one session. [onOpenSettings] is what "Manage in Settings" and "Change in Settings" call, after the
/// composer closes (the website's links leave the page the same way); without it those links are not drawn.
/// Resolves true when saved.
Future<bool> openMentoringComposer(
  BuildContext context, {
  required OfferingsController controller,
  OfferingFilePicker pickFile = pickOfferingFile,
  OfferedService? service,
  OfferedPlan? plan,
  VoidCallback? onOpenSettings,
}) => pushComposer(
  context,
  (_) => MentoringComposer(
    controller: controller,
    pickFile: pickFile,
    service: service,
    plan: plan,
    onOpenSettings: onOpenSettings,
  ),
);

// ---------------------------------------------------------------------------
// The website's limits and defaults (`OneSessionFields`, `usePlanForm`, `WhereFields`, `MENTOR_SERVICE_LIMITS`)
// ---------------------------------------------------------------------------

/// A new programme starts at this many rupees (`usePlanForm`'s draft), shown once the count crosses to two.
const _defaultProgrammeRupees = 25000;

/// `DEFAULT_CURRICULUM_ACCESS_MONTHS`.
const _defaultAccessMonths = 6;

/// `MENTOR_SERVICE_LIMITS.locationMax`: an in-person offering's venue line.
const _venueMax = 300;

/// The website's cover field refuses a file over this before uploading (`CoverImageField`'s `MAX_BYTES`).
const _coverMaxBytes = 2 * 1024 * 1024;

/// `MentorshipMode`, in the order the website lists them everywhere.
const _allModes = ['VIDEO', 'PHONE', 'IN_PERSON', 'CHAT'];

const _modeIcons = <String, IconData>{
  'VIDEO': LucideIcons.video,
  'PHONE': LucideIcons.phone,
  'IN_PERSON': LucideIcons.mapPin,
  'CHAT': LucideIcons.messageSquare,
};

/// The ways an offering meets (`offeringModes` in `@icr/shared`): the offering's own pick among the ways the mentor
/// meets in Settings; none picked (or none left) is every way the mentor meets; a mentor who never narrowed Settings
/// meets every way.
List<String> _offeringModes(List<String>? offering, List<String>? profile) {
  final settings = [
    for (final m in profile ?? const <String>[])
      if (_allModes.contains(m)) m,
  ];
  final base = settings.isNotEmpty ? settings : _allModes;
  final own = [
    for (final m in offering ?? const <String>[])
      if (base.contains(m)) m,
  ];
  final pick = own.isNotEmpty ? own : base;
  return [
    for (final m in _allModes)
      if (pick.contains(m)) m,
  ];
}

/// Rupees as typed, as the website's `Number(...)` reads them (anything that is not a number reads as nothing).
double _rupeesOf(String raw) => double.tryParse(raw.trim()) ?? 0;

int _paisaOf(String raw) => (_rupeesOf(raw) * 100).round();

String _rupeesText(num r) => r == r.roundToDouble() ? '${r.round()}' : '$r';

/// One session of a programme's syllabus. [minutes] is '' when the row has no length of its own.
class _SyllabusRow {
  _SyllabusRow({String title = '', String outline = '', this.minutes = ''})
    : title = TextEditingController(text: title),
      outline = TextEditingController(text: outline);

  /// A new row, carrying the programme's per-session minutes already filled in (`blankModule`).
  _SyllabusRow.blank(int defaultMinutes) : this(minutes: defaultMinutes > 0 ? '$defaultMinutes' : '');

  final TextEditingController title;
  final TextEditingController outline;
  String minutes;

  /// Anything the mentor put in this row beyond what a blank row carries.
  bool typed(int defaultMinutes) =>
      title.text.trim().isNotEmpty ||
      outline.text.trim().isNotEmpty ||
      (minutes.isNotEmpty && minutes != '$defaultMinutes');

  void dispose() {
    title.dispose();
    outline.dispose();
  }
}

enum _Lock { single, programme }

class MentoringComposer extends StatefulWidget {
  const MentoringComposer({
    super.key,
    required this.controller,
    required this.pickFile,
    this.service,
    this.plan,
    this.onOpenSettings,
  }) : assert(service == null || plan == null, 'Edit a service or a programme, not both');

  final OfferingsController controller;
  final OfferingFilePicker pickFile;

  /// A ONE_ON_ONE service being edited.
  final OfferedService? service;

  /// A CURRICULUM programme being edited.
  final OfferedPlan? plan;
  final VoidCallback? onOpenSettings;

  @override
  State<MentoringComposer> createState() => _MentoringComposerState();
}

class _MentoringComposerState extends State<MentoringComposer> {
  OfferedService? get _service => widget.service;
  OfferedPlan? get _plan => widget.plan;
  bool get _editing => _service != null || _plan != null;

  /// Which engine an existing offering is held to; null while it is new and the count may still cross.
  _Lock? get _lockedTo => _service != null ? _Lock.single : (_plan != null ? _Lock.programme : null);

  int get _min => _lockedTo == _Lock.programme ? minPlanModules : 1;
  int get _max => _lockedTo == _Lock.single ? 1 : maxPlanModules;

  // --- what both engines share (carried over when the count crosses) -----------------------------------------
  late bool _isSingle = _plan == null;
  late final _title = TextEditingController(text: _service?.title ?? _plan?.title ?? '');
  late final _blurb = TextEditingController(text: _service?.blurb ?? _plan?.blurb ?? '');
  late String? _cover = _service?.coverUrl ?? _plan?.coverUrl;
  late bool _paid = switch ((_service, _plan)) {
    (final OfferedService s, _) => s.pricePaisa > 0,
    (_, final OfferedPlan p) => (p.pricePaisa / 100).round() > 0,
    _ => true,
  };

  /// The price box: a single session's rupees, or the programme's while the count is two or more.
  late final _price = TextEditingController(
    text: switch ((_service, _plan)) {
      (final OfferedService s, _) => s.pricePaisa > 0 ? '${(s.pricePaisa / 100).round()}' : '',
      (_, final OfferedPlan p) => (p.pricePaisa / 100).round() > 0 ? '${(p.pricePaisa / 100).round()}' : '',
      _ => '',
    },
  );
  late final _compareAt = TextEditingController(
    text: (() {
      final c = _service?.compareAtPaisa ?? _plan?.compareAtPaisa;
      return c != null && c > 0 ? '${(c / 100).round()}' : '';
    })(),
  );
  late bool _active = _service?.active ?? _plan?.active ?? true;

  // --- the single session's own ------------------------------------------------------------------------------
  late int _singleMinutes = _service?.durationMin ?? 60;

  // --- the programme's own -------------------------------------------------------------------------------------
  /// The programme's price while a single session is on screen (it comes back when the count crosses again).
  late num _planRupees = _plan != null ? (_plan!.pricePaisa / 100).round() : _defaultProgrammeRupees;
  late int _planMinutes = _plan?.sessionDurationMin ?? 60;
  late final _access = TextEditingController(text: '${_plan?.accessMonths ?? _defaultAccessMonths}');
  late final _inclusions = TextEditingController(text: (_plan?.inclusions ?? const <String>[]).join('\n'));
  final _rows = <_SyllabusRow>[];

  /// Rows a shrink cut that had something typed in, kept only long enough to offer an undo.
  ({List<_SyllabusRow> rows, int filled})? _dropped;

  // --- the count ---------------------------------------------------------------------------------------------
  late final _count = TextEditingController(text: '$_countValue');
  final _countFocus = FocusNode();

  int get _countValue => _isSingle ? 1 : _rows.length;

  // --- where (Delivery) --------------------------------------------------------------------------------------
  /// The mentor's pick; null while untouched, which reads the offering as saved.
  List<String>? _picked;
  late final _venue = TextEditingController(text: _service?.location ?? _plan?.location ?? '');

  /// The saved map pin, kept only while the venue line is the one it was saved with: the phone has no map to show or
  /// move it, so a rewritten venue goes without a pin rather than with someone else's.
  late final double? _savedLat = _service?.locationLat ?? _plan?.locationLat;
  late final double? _savedLng = _service?.locationLng ?? _plan?.locationLng;
  late final String _savedVenue = (_service?.location ?? _plan?.location ?? '').trim();

  DeskSettings? _settings;
  String? _settingsProblem;
  bool _settingsLoading = true;

  // --- the page ----------------------------------------------------------------------------------------------
  String? _coverProblem;
  bool _uploading = false;
  bool _busy = false;
  String? _apiProblem;

  /// Save was tapped while something still blocked it: the footer's sentence shows in the problem bar too.
  bool _tappedBlocked = false;

  @override
  void initState() {
    super.initState();
    final plan = _plan;
    if (plan != null && plan.steps.isNotEmpty) {
      for (final s in plan.steps) {
        // A step that never had its own length shows the plan's, rather than an empty box that means the same.
        final m = (s.durationMin ?? 0) > 0 ? s.durationMin : plan.sessionDurationMin;
        _rows.add(_SyllabusRow(title: s.title, outline: s.outline ?? '', minutes: m == null ? '' : '$m'));
      }
    } else {
      // Two blank rows rather than none: the minimum is two.
      _rows
        ..add(_SyllabusRow.blank(_planMinutes))
        ..add(_SyllabusRow.blank(_planMinutes));
    }
    _count.text = '$_countValue';
    _countFocus.addListener(_onCountFocus);
    _loadSettings();
  }

  @override
  void dispose() {
    _countFocus
      ..removeListener(_onCountFocus)
      ..dispose();
    for (final c in [_title, _blurb, _price, _compareAt, _access, _inclusions, _count, _venue]) {
      c.dispose();
    }
    for (final r in _rows) {
      r.dispose();
    }
    for (final r in _dropped?.rows ?? const <_SyllabusRow>[]) {
      r.dispose();
    }
    super.dispose();
  }

  /// The mentor's ways of meeting and weekly hours (`GET /mentorship/mentors/me`, the desk's Settings read).
  Future<void> _loadSettings() async {
    setState(() {
      _settingsLoading = true;
      _settingsProblem = null;
    });
    try {
      final s = await MentorDeskRepository(api: widget.controller.repository.api).settings();
      if (!mounted) return;
      setState(() {
        _settings = s;
        _settingsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _settingsLoading = false;
        _settingsProblem = ApiError.from(e).message;
      });
    }
  }

  // ===========================================================================
  // The count decides the engine
  // ===========================================================================

  void _setCountText(String text) {
    if (_count.text == text) return;
    _count.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }

  void _onCountTyped(String raw) {
    final n = int.tryParse(raw.trim());
    // A half-typed "1" on the way to "12" must not swap the form to a single session, so one waits for the field
    // to lose focus; two and up apply now.
    if (n != null && n >= 2 && n <= _max) _applyCount(n);
  }

  void _onCountFocus() {
    if (!_countFocus.hasFocus && mounted) _commitCount();
  }

  void _commitCount() => _applyCount(int.tryParse(_count.text.trim()) ?? 0);

  /// Crossing between one and several carries the shared fields over; within a programme it resizes the syllabus.
  void _applyCount(int raw) {
    final n = (raw == 0 ? _countValue : raw).clamp(_min, _max);
    setState(() {
      if (n == 1 && !_isSingle) {
        _toSingle();
      } else if (n >= 2 && _isSingle) {
        _toProgramme(n);
      } else if (n >= 2) {
        _resize(n);
      }
    });
    _setCountText('$n');
  }

  /// Takes over what the mentor typed into the programme before the count goes down to one (`single.adopt`).
  void _toSingle() {
    _planRupees = _rupeesOf(_price.text);
    _isSingle = true;
    _price.text = _paid && _planRupees > 0 ? _rupeesText(_planRupees) : '';
    if (_planMinutes > 0) _singleMinutes = _planMinutes;
    _apiProblem = null;
  }

  /// Takes over what the mentor typed as a single session before the count goes up, and sizes the syllabus to the
  /// count they asked for (`planState.adopt`).
  void _toProgramme(int sessions) {
    final n = sessions.clamp(minPlanModules, maxPlanModules);
    final singleRupees = _rupeesOf(_price.text);
    if (_paid && singleRupees > 0) _planRupees = singleRupees;
    final previous = _planMinutes;
    if (_singleMinutes > 0) _planMinutes = _singleMinutes;
    // Rows still showing the old per-session minutes follow the new one, as the Session Length field does.
    for (final r in _rows) {
      if (r.minutes.isEmpty || r.minutes == '$previous') r.minutes = '$_planMinutes';
    }
    while (_rows.length > n) {
      _rows.removeLast().dispose();
    }
    while (_rows.length < n) {
      _rows.add(_SyllabusRow.blank(_planMinutes));
    }
    _isSingle = false;
    _price.text = _planRupees > 0 ? _rupeesText(_planRupees) : '';
    _apiProblem = null;
  }

  /// The session count is the syllabus itself: typing 8 leaves exactly eight rows. Shrinking drops rows from the end,
  /// and anything typed into those rows is offered back rather than silently lost.
  void _resize(int next) {
    final n = next.clamp(minPlanModules, maxPlanModules);
    final have = _rows.length;
    if (n == have) return;
    if (n > have) {
      for (var i = have; i < n; i++) {
        _rows.add(_SyllabusRow.blank(_planMinutes));
      }
      return;
    }
    final cut = _rows.sublist(n);
    _rows.removeRange(n, have);
    final filled = cut.where((r) => r.typed(_planMinutes)).length;
    _clearDropped();
    if (filled > 0) {
      _dropped = (rows: cut, filled: filled);
    } else {
      for (final r in cut) {
        r.dispose();
      }
    }
  }

  void _clearDropped() {
    for (final r in _dropped?.rows ?? const <_SyllabusRow>[]) {
      r.dispose();
    }
    _dropped = null;
  }

  void _undoDrop() {
    final d = _dropped;
    if (d == null) return;
    setState(() {
      _rows.addAll(d.rows);
      _dropped = null;
    });
    _setCountText('$_countValue');
  }

  void _addRow() {
    if (_rows.length >= maxPlanModules) return;
    setState(() => _rows.add(_SyllabusRow.blank(_planMinutes)));
    _setCountText('$_countValue');
  }

  void _removeRow(_SyllabusRow row) {
    if (_rows.length <= minPlanModules) return;
    setState(() {
      _rows.remove(row);
      row.dispose();
    });
    _setCountText('$_countValue');
  }

  /// The per-session minutes go into every row still showing the old default; a row given its own length keeps it.
  void _setPlanMinutes(int next) {
    final previous = _planMinutes;
    setState(() {
      _planMinutes = next;
      for (final r in _rows) {
        if (r.minutes.isEmpty || r.minutes == '$previous') r.minutes = '$next';
      }
    });
  }

  // ===========================================================================
  // Where (Delivery)
  // ===========================================================================

  /// Every way the mentor meets: what an offering may pick from.
  List<String> get _available => _settings == null ? const [] : _offeringModes(const [], _settings!.preferredModes);

  List<String> get _modes =>
      _picked ?? (_settings == null ? const [] : _offeringModes(_service?.modes ?? _plan?.modes, _settings!.preferredModes));

  bool get _inPerson => _modes.contains('IN_PERSON');
  bool get _everyWay => _available.isNotEmpty && _available.every(_modes.contains);

  String? get _whereProblem {
    if (_settings == null) return null;
    if (_modes.isEmpty) return 'Select at least one format.';
    final venue = _venue.text.trim();
    if (_inPerson && venue.isEmpty) return 'Add the venue for in-person sessions.';
    if (_inPerson && venue.length > _venueMax) return 'Keep the venue under $_venueMax characters.';
    return null;
  }

  /// The fields a save sends: none until the mentor's Settings have loaded, which leaves the saved "Where" alone.
  /// Every way the mentor meets is sent as `[]`, so a way they add in Settings later joins in on its own.
  Map<String, Object?> get _wherePayload {
    if (_settings == null) return const {};
    final venue = _venue.text.trim();
    final pinned = _savedLat != null && _savedLng != null && venue == _savedVenue;
    return {
      'modes': _everyWay ? <String>[] : _modes,
      'location': _inPerson ? venue : null,
      'locationLat': _inPerson && pinned ? _savedLat : null,
      'locationLng': _inPerson && pinned ? _savedLng : null,
    };
  }

  void _toggleMode(String m) {
    final now = _modes;
    setState(() {
      _picked = [
        for (final x in _available)
          if (x == m ? !now.contains(m) : now.contains(x)) x,
      ];
    });
  }

  void _openSettings() {
    final open = widget.onOpenSettings;
    if (open == null) return;
    Navigator.of(context).pop(false);
    open();
  }

  // ===========================================================================
  // What still blocks the save, in the website's words and order
  // ===========================================================================

  bool get _atCap => widget.controller.listingsUsed >= maxServices;

  bool get _titleShort => _title.text.trim().length < minServiceTitle;

  int get _singlePricePaisa => _paid ? _paisaOf(_price.text) : 0;

  /// The programme's price in rupees, as the box reads.
  double get _programmeRupees => _rupeesOf(_price.text);

  int get _programmePricePaisa => _paid ? (_programmeRupees * 100).round() : 0;

  int? get _compareAtPaisa => _paid && _compareAt.text.isNotEmpty ? _paisaOf(_compareAt.text) : null;

  /// The API's discount rule, said before Save rather than after it.
  String? get _compareAtProblem {
    final c = _compareAtPaisa;
    if (c == null) return null;
    final price = _isSingle ? _singlePricePaisa : _programmePricePaisa;
    if (c <= price) return 'Compare-at price must exceed the price.';
    if (price * 10000 < c * (10000 - maxDiscountBps)) return 'Discount cannot exceed ${maxDiscountBps ~/ 100}%.';
    return null;
  }

  /// A single session's price, under its box and in the footer.
  String? get _singlePriceProblem {
    if (!_paid) return null;
    final p = _singlePricePaisa;
    if (p < minOneToOnePricePaisa) return 'A paid session is at least ${inr(minOneToOnePricePaisa)}.';
    if (p > maxServicePricePaisa) return 'Prices go up to ${inr(maxServicePricePaisa)}.';
    return null;
  }

  bool get _accessOutOfRange {
    final a = int.tryParse(_access.text.trim());
    return a == null || a < minAccessMonths || a > maxAccessMonths;
  }

  List<String> get _inclusionLines => [
    for (final l in _inclusions.text.split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];

  List<_SyllabusRow> get _filledRows => [
    for (final r in _rows)
      if (r.title.text.trim().isNotEmpty) r,
  ];

  String? get _singleBlocker {
    if (_service == null && _atCap) {
      return 'Listing limit reached ($maxServices). Retire a single session to add another.';
    }
    if (_titleShort) return 'Enter a title (at least $minServiceTitle characters).';
    return _whereProblem ?? _singlePriceProblem ?? _compareAtProblem;
  }

  String? get _programmeBlocker {
    final title = _title.text.trim();
    if (title.isEmpty) return 'Enter a title.';
    if (title.length < minPlanTitle) return 'Enter a title (at least $minPlanTitle characters).';
    if (title.length > maxPlanTitle) return 'Keep the title under $maxPlanTitle characters.';
    if (_blurb.text.trim().length > maxPlanBlurb) return 'Keep the description under $maxPlanBlurb characters.';
    final short = _rows.indexWhere((r) {
      final t = r.title.text.trim();
      return t.isNotEmpty && t.length < minModuleTitle;
    });
    if (short >= 0) return 'Session ${short + 1} needs a title of at least $minModuleTitle characters.';
    if (_filledRows.length < minPlanModules) return 'List at least $minPlanModules sessions.';
    final where = _whereProblem;
    if (where != null) return where;
    if (_paid && _programmeRupees * 100 < minOneToOnePricePaisa) {
      return 'A paid programme is at least ${inr(minOneToOnePricePaisa)}.';
    }
    if (_paid && _programmeRupees <= 0) return 'Set a price, or make it free.';
    if (_programmePricePaisa > maxPaisa) return 'That price is too large.';
    final compare = _compareAtProblem;
    if (compare != null) return compare;
    if (_accessOutOfRange) return 'Set "Complete Within" to $minAccessMonths–$maxAccessMonths months.';
    if (_inclusionLines.any((l) => l.length > maxInclusionChars)) {
      return 'Keep each line of "What\'s Included" to $maxInclusionChars characters.';
    }
    return null;
  }

  String? get _blocker => _isSingle ? _singleBlocker : _programmeBlocker;

  // ===========================================================================
  // Saving
  // ===========================================================================

  /// `POST/PATCH /mentor-services/mine`, as the website sends it (`useOneSessionForm.submit`).
  Map<String, Object?> get _serviceBody {
    final blurb = _blurb.text.trim();
    return {
      'type': ServiceKind.oneOnOne.api,
      'title': _title.text.trim(),
      if (blurb.isNotEmpty) 'blurb': blurb,
      'coverUrl': _cover,
      'pricePaisa': _singlePricePaisa,
      'compareAtPaisa': _compareAtPaisa,
      'durationMin': _singleMinutes,
      'active': _active,
      ..._wherePayload,
    };
  }

  /// `POST/PATCH /mentor-plans`, as the website sends a programme (`usePlanForm.submit`): rows with no title are
  /// left out, and `kind` goes only with a new one (the API refuses a change of kind).
  Map<String, Object?> get _programmeBody {
    final blurb = _blurb.text.trim();
    return {
      'title': _title.text.trim(),
      if (blurb.isNotEmpty) 'blurb': blurb,
      'coverUrl': _cover,
      'pricePaisa': _programmePricePaisa,
      'compareAtPaisa': _compareAtPaisa,
      'sessionDurationMin': _planMinutes,
      'inclusions': _inclusionLines.take(maxInclusions).toList(),
      'active': _active,
      if (_plan == null) 'kind': 'CURRICULUM',
      ..._wherePayload,
      'accessMonths': int.parse(_access.text.trim()),
      'modules': [
        for (final r in _filledRows)
          {
            'title': r.title.text.trim(),
            if (r.outline.text.trim().isNotEmpty) 'outline': r.outline.text.trim(),
            if (r.minutes.isNotEmpty) 'durationMin': int.parse(r.minutes),
          },
      ],
    };
  }

  Future<void> _save() async {
    // A count still being typed counts as typed: the website applies it when the box loses focus to the button.
    FocusManager.instance.primaryFocus?.unfocus();
    _commitCount();
    final blocker = _blocker;
    if (blocker != null) {
      setState(() {
        _tappedBlocked = true;
        _apiProblem = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _apiProblem = null;
    });
    final c = widget.controller;
    final refusal = _isSingle
        ? await c.saveService(_serviceBody, id: _service?.id)
        : await c.savePlan(_programmeBody, id: _plan?.id);
    if (!mounted) return;
    if (refusal == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _apiProblem = refusal;
    });
  }

  Future<void> _pickCover() async {
    setState(() {
      _uploading = true;
      _coverProblem = null;
    });
    final stored = await pickAndUpload(
      pick: widget.pickFile,
      upload: (f) async {
        if (f.bytes.length > _coverMaxBytes) {
          throw ApiError('That image is over 2MB. Compress it or choose a smaller one.');
        }
        return widget.controller.upload(f, purpose: 'mentor-offering');
      },
      imageOnly: true,
      problem: (p) => _coverProblem = p,
    );
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (stored != null) _cover = stored.url;
    });
  }

  // ===========================================================================
  // The page
  // ===========================================================================

  void _redraw([Object? _]) => setState(() {});

  @override
  Widget build(BuildContext context) {
    final blocker = _blocker;
    if (blocker == null) _tappedBlocked = false;
    final after = _isSingle ? 0 : 1;
    return ComposerPage(
      title: _editing ? 'Edit 1:1 Mentoring' : 'New 1:1 Mentoring',
      lead: _editing
          ? 'Changes apply to new requests. Sessions already booked keep their terms.'
          : 'Offer a single session or a multi-session programme that mentees can request from your profile.',
      blocker: blocker,
      problem: _apiProblem ?? (_tappedBlocked ? blocker : null),
      busy: _busy,
      saveLabel: _isSingle ? 'Save Session' : 'Save Programme',
      onSave: _uploading ? null : _save,
      sections: [
        _overview(),
        _format(),
        if (!_isSingle) _syllabus(3),
        _delivery(3 + after),
        _pricing(4 + after),
        _visibility(5 + after),
      ],
    );
  }

  Widget _overview() {
    final titleError = _isSingle && _titleShort && _title.text.isNotEmpty ? 'At least $minServiceTitle characters.' : null;
    return ComposerSection(
      key: const ValueKey('composer-overview'),
      step: 1,
      first: true,
      title: 'Overview',
      subtitle: 'This is displayed on your profile for mentees.',
      children: [
        ComposerField(
          label: 'Title',
          required: true,
          error: titleError,
          child: TextField(
            key: const ValueKey('composer-title'),
            controller: _title,
            maxLength: _isSingle ? maxServiceTitle : maxPlanTitle,
            onChanged: _redraw,
            style: ComposerText.body,
            textCapitalization: TextCapitalization.sentences,
            decoration: composerDecoration(
              'e.g. CV review and next-role plan',
              error: titleError != null,
            ).copyWith(counterText: ''),
          ),
        ),
        ComposerField(
          label: 'Description',
          optional: true,
          child: TextField(
            key: const ValueKey('composer-description'),
            controller: _blurb,
            minLines: 3,
            maxLines: 6,
            maxLength: _isSingle ? maxServiceBlurb : maxPlanBlurb,
            onChanged: _redraw,
            style: ComposerText.body,
            textCapitalization: TextCapitalization.sentences,
            decoration: composerDecoration('Describe what the mentee will gain from this.').copyWith(counterText: ''),
          ),
        ),
        ComposerField(
          label: 'Cover Image',
          optional: true,
          child: CoverImageField(
            keyPrefix: 'composer-cover',
            url: _cover,
            busy: _uploading,
            problem: _coverProblem,
            onPick: _pickCover,
            onRemove: () => setState(() => _cover = null),
          ),
        ),
      ],
    );
  }

  Widget _format() {
    final locked = _lockedTo;
    final note = switch (locked) {
      _Lock.single => 'Saved as a single session. Create a new offering to sell several.',
      _Lock.programme => 'Saved as a programme ($minPlanModules–$maxPlanModules sessions).',
      null => '1 for a single session; $minPlanModules–$maxPlanModules for a programme.',
    };
    return ComposerSection(
      key: const ValueKey('composer-format'),
      step: 2,
      title: 'Format',
      subtitle: 'The number of sessions determines the format.',
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ComposerLabel('Number of Sessions'),
              TextField(
                key: const ValueKey('composer-count'),
                controller: _count,
                focusNode: _countFocus,
                enabled: locked != _Lock.single,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                onChanged: _onCountTyped,
                onSubmitted: (_) => _commitCount(),
                style: ComposerText.body,
                decoration: composerDecoration('1'),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (locked != null) ...[
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(LucideIcons.lock, size: 14, color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(note, key: const ValueKey('composer-count-note'), style: ComposerText.help),
                  ),
                ],
              ),
            ],
          ),
        ),
        ComposerField(
          label: 'Session Length',
          help: _isSingle ? null : 'Applied to every session; adjust any session below.',
          child: DurationPicker(
            keyPrefix: 'composer-length',
            minutes: _isSingle ? _singleMinutes : _planMinutes,
            onChanged: (m) => _isSingle ? setState(() => _singleMinutes = m) : _setPlanMinutes(m),
          ),
        ),
        if (!_isSingle)
          ComposerField(
            label: 'Complete Within (Months)',
            child: TextField(
              key: const ValueKey('composer-access'),
              controller: _access,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
              onChanged: _redraw,
              style: ComposerText.body,
              decoration: composerDecoration('$_defaultAccessMonths', error: _accessOutOfRange),
            ),
          ),
      ],
    );
  }

  Widget _syllabus(int step) {
    final dropped = _dropped;
    return ComposerSection(
      key: const ValueKey('composer-syllabus'),
      step: step,
      title: 'Syllabus',
      subtitle: 'Sessions in the order you run them. Mentees see this before requesting.',
      trailing: Text(
        '${_rows.length} of $maxPlanModules',
        key: const ValueKey('composer-syllabus-count'),
        style: ComposerText.help.copyWith(fontWeight: FontWeight.w600),
      ),
      children: [
        if (dropped != null)
          Container(
            key: const ValueKey('composer-dropped'),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
            decoration: BoxDecoration(color: AppColors.amber50, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _droppedSentence(dropped.rows.length, dropped.filled),
                    style: ComposerText.body.copyWith(color: AppColors.amber800),
                  ),
                ),
                TextButton(
                  key: const ValueKey('composer-dropped-undo'),
                  onPressed: _undoDrop,
                  child: Text('Undo', style: ComposerText.link),
                ),
                IconButton(
                  key: const ValueKey('composer-dropped-close'),
                  tooltip: 'Close',
                  onPressed: () => setState(_clearDropped),
                  icon: const Icon(LucideIcons.x, size: 16, color: AppColors.amber800),
                ),
              ],
            ),
          ),
        for (final (i, r) in _rows.indexed) _rowView(i, r),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TextButton.icon(
              key: const ValueKey('composer-add-session'),
              onPressed: _rows.length >= maxPlanModules ? null : _addRow,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: Text('Add a Session', style: ComposerText.link),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
            ),
          ),
        ),
        ComposerField(
          label: "What's Included",
          optional: true,
          help: 'One item per line, up to $maxInclusions.',
          child: TextField(
            key: const ValueKey('composer-included'),
            controller: _inclusions,
            minLines: 3,
            maxLines: 8,
            onChanged: _redraw,
            style: ComposerText.body,
            decoration: composerDecoration(''),
          ),
        ),
      ],
    );
  }

  static String _droppedSentence(int count, int filled) =>
      'Removed ${count == 1 ? '1 session' : '$count sessions'}, ${filled == 1 ? 'one' : '$filled'} with details entered.';

  /// One row of the syllabus, closed by a hairline (never boxed): its number and Remove, then the title, the topics
  /// and the length stacked for a phone's width.
  Widget _rowView(int i, _SyllabusRow r) {
    final t = r.title.text.trim();
    final short = t.isNotEmpty && t.length < minModuleTitle;
    return Container(
      key: ObjectKey(r),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.cardRule)),
      ),
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Session ${i + 1}', style: ComposerText.sectionTitle.copyWith(fontSize: 14))),
              IconButton(
                key: ValueKey('composer-row-remove-$i'),
                tooltip: 'Remove This Session',
                onPressed: _rows.length <= minPlanModules ? null : () => _removeRow(r),
                icon: Icon(
                  LucideIcons.trash2,
                  size: 16,
                  color: _rows.length <= minPlanModules ? AppColors.slate300 : AppColors.outline,
                ),
              ),
            ],
          ),
          ComposerField(
            label: 'Session Title',
            child: TextField(
              key: ValueKey('composer-row-title-$i'),
              controller: r.title,
              maxLength: maxModuleTitle,
              onChanged: _redraw,
              style: ComposerText.body,
              textCapitalization: TextCapitalization.sentences,
              decoration: composerDecoration('', error: short).copyWith(counterText: ''),
            ),
          ),
          ComposerField(
            label: 'Topics Covered',
            child: TextField(
              key: ValueKey('composer-row-topics-$i'),
              controller: r.outline,
              minLines: 1,
              maxLines: 4,
              maxLength: maxModuleOutline,
              onChanged: _redraw,
              style: ComposerText.body,
              textCapitalization: TextCapitalization.sentences,
              decoration: composerDecoration('').copyWith(counterText: ''),
            ),
          ),
          ComposerField(
            label: 'Length',
            child: DurationPicker(
              keyPrefix: 'composer-row-length-$i',
              minutes: int.tryParse(r.minutes) ?? _planMinutes,
              onChanged: (m) => setState(() => r.minutes = '$m'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _delivery(int step) {
    final open = widget.onOpenSettings == null ? null : _openSettings;
    return ComposerSection(
      key: const ValueKey('composer-delivery'),
      step: step,
      title: 'Delivery',
      subtitle: 'Choose how and when mentees can meet you.',
      children: [
        if (_settingsLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          )
        else if (_settings == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              key: const ValueKey('composer-delivery-error'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Unable to Load Your Meeting Formats', style: ComposerText.label),
                const SizedBox(height: 2),
                Text(_settingsProblem ?? '', style: ComposerText.help),
                TextButton(
                  onPressed: _loadSettings,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: Text('Try Again', style: ComposerText.link),
                ),
              ],
            ),
          )
        else ..._whereFields(open),
      ],
    );
  }

  List<Widget> _whereFields(VoidCallback? openSettings) {
    final modes = _modes;
    final helper = modes.isEmpty
        ? 'Select at least one format.'
        : (_everyWay ? 'Available meeting formats.' : 'Mentees can request only the selected formats.');
    final s = _settings!;
    final days = s.blocks.map((b) => b.weekday).toSet().length;
    final hours = days == 0
        ? 'No weekly hours set. Mentees can still request; you set each time.'
        : '${days == 1 ? '1 day' : '$days days'} per week · ${s.timezone}';
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The label keeps its line beside the link (the kit's label shares the row half and half).
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text('Meeting Format', style: ComposerText.label)),
                  if (openSettings != null)
                    TextButton(
                      key: const ValueKey('composer-manage-settings'),
                      onPressed: openSettings,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text('Manage in Settings', style: ComposerText.link),
                    ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _available)
                  _ModeChip(mode: m, selected: modes.contains(m), onTap: () => _toggleMode(m)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              helper,
              key: const ValueKey('composer-modes-note'),
              style: modes.isEmpty ? ComposerText.error : ComposerText.help,
            ),
          ],
        ),
      ),
      if (_inPerson)
        // The website pins the venue on a map as well; the phone takes the venue line alone.
        ComposerField(
          label: 'Venue',
          required: true,
          help: 'Shown to mentees before they request.',
          child: TextField(
            key: const ValueKey('composer-venue'),
            controller: _venue,
            maxLength: _venueMax,
            onChanged: _redraw,
            style: ComposerText.body,
            textCapitalization: TextCapitalization.sentences,
            decoration: composerDecoration('e.g. ICR Bengaluru, 4th floor training room').copyWith(counterText: ''),
          ),
        ),
      ComposerNote(
        key: const ValueKey('composer-availability'),
        icon: LucideIcons.clock,
        text: TextSpan(
          children: [
            const TextSpan(text: 'Availability: ', style: TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: hours),
          ],
        ),
        action: openSettings == null ? null : 'Change in Settings',
        onAction: openSettings,
        actionBelow: true,
      ),
    ];
  }

  Widget _pricing(int step) {
    final priceProblem = _isSingle && _price.text.isNotEmpty ? _singlePriceProblem : null;
    final compareProblem = _compareAtProblem;
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    return ComposerSection(
      key: const ValueKey('composer-pricing'),
      step: step,
      title: 'Pricing',
      subtitle: _isSingle ? 'GST will be added at checkout.' : 'Charged once, on acceptance. GST is added at checkout.',
      children: [
        FreePaidToggle(
          keyPrefix: 'composer-pricing',
          paid: _paid,
          freeNote: _isSingle ? 'One free session per mentee.' : 'No charge. Requests still need your acceptance.',
          onChanged: (paid) => setState(() => _paid = paid),
        ),
        if (_paid) ...[
          // Stacked: side by side, the two labels and the discount line do not fit a 360 dp phone.
          ComposerField(
            label: _isSingle ? 'Price (₹)' : 'Programme Price (₹)',
            error: priceProblem,
            child: TextField(
              key: const ValueKey('composer-price'),
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: digits,
              onChanged: _redraw,
              style: ComposerText.body,
              decoration: composerDecoration('', rupee: true, error: priceProblem != null),
            ),
          ),
          ComposerField(
            label: 'Compare-at Price',
            optional: true,
            error: compareProblem,
            help: 'Displayed as a strikethrough price. Discounts cannot exceed ${maxDiscountBps ~/ 100}%.',
            child: TextField(
              key: const ValueKey('composer-compare-at'),
              controller: _compareAt,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: digits,
              onChanged: _redraw,
              style: ComposerText.body,
              decoration: composerDecoration('', rupee: true, error: compareProblem != null),
            ),
          ),
        ],
      ],
    );
  }

  Widget _visibility(int step) => ComposerSection(
    key: const ValueKey('composer-visibility'),
    step: step,
    title: 'Visibility',
    subtitle: 'Draft offerings are saved but not visible to mentees.',
    children: [
      PublishedSwitch(
        keyName: 'composer-published',
        value: _active,
        onChanged: (v) => setState(() => _active = v),
        onText: 'Published and visible on your profile.',
        offText: 'Draft. Hidden from your profile.',
      ),
    ],
  );
}

/// One way of meeting, as the website's toggle (an icon and the name); selected reads tinted with a primary edge.
class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.mode, required this.selected, required this.onTap});

  final String mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? const Color(0xFFE8EEF5) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: selected ? AppColors.primary : AppColors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('composer-mode-$mode'),
          onTap: onTap,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_modeIcons[mode] ?? LucideIcons.video, size: 16, color: color),
                const SizedBox(width: 8),
                Text(mentorModes[mode] ?? mode, style: selected ? ComposerText.toggleOn : ComposerText.toggle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
