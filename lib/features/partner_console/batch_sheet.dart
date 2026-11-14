import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../account/widgets/account_kit.dart';
import '../site/site_kit.dart';
import 'partner_console_controllers.dart';
import 'partner_console_kit.dart';
import 'partner_console_models.dart';
import 'partner_console_rules.dart';

/// Opens the batch sheet (the website's `BatchDialog`); true when saved.
Future<bool> showBatchSheet(
  BuildContext context, {
  required BatchesController controller,
  required ConsoleCourse course,
  ConsoleBatch? batch,
  ConsolePickers pickers = const ConsolePickers(),
  DateTime Function()? now,
}) async =>
    await showEditSheet<bool>(
      context,
      builder: (_) => BatchSheet(controller: controller, course: course, batch: batch, pickers: pickers, now: now),
    ) ??
    false;

/// The zones a class time may be on; an older batch's own value joins the list.
const _timezones = [
  'Asia/Kolkata',
  'Asia/Dubai',
  'Asia/Riyadh',
  'Asia/Karachi',
  'Asia/Dhaka',
  'Asia/Colombo',
  'Asia/Kathmandu',
  'Asia/Singapore',
  'Asia/Kuala_Lumpur',
  'Asia/Hong_Kong',
  'Asia/Tokyo',
  'Australia/Sydney',
  'Europe/London',
  'Europe/Paris',
  'Europe/Berlin',
  'Africa/Johannesburg',
  'Africa/Nairobi',
  'America/New_York',
  'America/Chicago',
  'America/Los_Angeles',
  'America/Toronto',
  'America/Sao_Paulo',
];

/// Create or edit a batch — one scheduled run of a course. Everything that decides whether a candidate can join
/// lives here: the days it runs and the days and time classes meet, how it is delivered and where, who teaches
/// it, how many seats there are and what a place costs. The status is never picked: the dates set it, and
/// Cancel is the one choice, once the batch exists.
class BatchSheet extends StatefulWidget {
  const BatchSheet({
    super.key,
    required this.controller,
    required this.course,
    this.batch,
    this.pickers = const ConsolePickers(),
    this.now,
  });

  final BatchesController controller;
  final ConsoleCourse course;
  final ConsoleBatch? batch;
  final ConsolePickers pickers;

  /// The clock the date rules read (tests).
  final DateTime Function()? now;

  @override
  State<BatchSheet> createState() => _BatchSheetState();
}

class _BatchSheetState extends State<BatchSheet> {
  late final BatchDraft _d = widget.batch == null
      ? BatchDraft.blank(widget.course)
      : BatchDraft.fromBatch(widget.batch!);
  late final _title = TextEditingController(text: _d.title);
  late final _venue = TextEditingController(text: _d.location);
  late final _size = TextEditingController(text: _d.maxSeats?.toString() ?? '');
  late final _price = TextEditingController(text: _d.priceAmount == null ? '' : (_d.priceAmount! ~/ 100).toString());
  late final _discount = TextEditingController(text: _d.discountPercent == 0 ? '' : _d.discountPercent.toString());
  List<FacultyMember> _faculty = const [];
  bool _saving = false;
  bool _dirty = false;
  bool _showMissing = false;
  String? _error;
  String? _asked;

  ConsoleCourse get course => widget.course;
  ConsoleBatch? get batch => widget.batch;
  bool get _instituteCourse => course.providerId != null;
  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    if (_instituteCourse) {
      widget.controller.faculty().then((list) {
        if (mounted) setState(() => _faculty = list);
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _venue.dispose();
    _size.dispose();
    _price.dispose();
    _discount.dispose();
    super.dispose();
  }

  void _touch(VoidCallback change) => setState(() {
    change();
    _dirty = true;
  });

  // --- what the dates give -----------------------------------------------------------------------------------------

  String? get _startDay => _d.startsAt == null ? null : indiaDay(DateTime.parse(_d.startsAt!));
  String? get _endDay => _d.endsAt == null ? null : indiaDay(DateTime.parse(_d.endsAt!));
  String get _today => indiaDay(_now);

  List<int> get _inRange => _startDay == null ? [...BatchDraft.batchWeekdays] : weekdaysBetween(_startDay!, _endDay);
  List<int> get _pickedDays => [
    for (final d in BatchDraft.batchWeekdays)
      if (_d.classDays.contains(d) && _inRange.contains(d)) d,
  ];
  String? get _timesProblem => classTimesError(_d.classStartTime, _d.classEndTime);
  String? get _length => _startDay != null && _endDay != null
      ? batchLengthLabel(countClassDates(_startDay!, _endDay!, _pickedDays), _d.classStartTime, _d.classEndTime)
      : null;

  /// A batch already under way keeps the start it has; it cannot be moved to another past day.
  bool get _keptStart => batch != null && _d.startsAt == batch!.startsAt.toUtc().toIso8601String();
  bool get _startError => _startDay != null && _startDay!.compareTo(_today) < 0 && !_keptStart;
  bool get _endError => _startDay != null && _endDay != null && _endDay!.compareTo(_startDay!) <= 0;

  bool get _paid => course.paid;

  /// What a batch needs before it is saved (the website's `need`), in its order.
  Map<String, bool> get _need => {
    'startsAt': _d.startsAt == null,
    'endsAt': _d.endsAt == null,
    'classDays': _pickedDays.isEmpty,
    'classStartTime': _d.classStartTime == null,
    'classEndTime': _d.classEndTime == null,
    'timezone': _d.timezone.trim().isEmpty,
    'location': _d.inPerson && _venue.text.trim().isEmpty,
    'priceAmount': _paid && _d.priceAmount == null,
  };

  static const _needLabels = {
    'startsAt': 'Batch Starts',
    'endsAt': 'Batch Ends',
    'classDays': 'Class Days',
    'classStartTime': 'Class Starts',
    'classEndTime': 'Class Ends',
    'timezone': 'Time Zone',
    'location': 'Venue',
    'priceAmount': 'Price',
  };

  bool _flag(String key) => _showMissing && (_need[key] ?? false);

  // --- pickers ------------------------------------------------------------------------------------------------------

  DateTime _dayOf(String ymd) => DateTime.parse('${ymd}T00:00:00');

  Future<void> _pickStart() async {
    final today = _dayOf(_today);
    final current = _startDay == null ? null : _dayOf(_startDay!);
    final first = _keptStart && current != null && current.isBefore(today) ? current : today;
    final picked = await widget.pickers.pickDay(
      context,
      initial: current ?? today,
      first: first,
      last: today.add(const Duration(days: 365 * 5)),
      help: 'Batch Starts',
    );
    if (picked == null) return;
    _touch(() {
      _d.startsAt = calendarDayIso(picked);
      // An end on or before the new start would only be refused.
      if (_d.endsAt != null && _d.endsAt!.compareTo(_d.startsAt!) <= 0) _d.endsAt = null;
    });
  }

  Future<void> _pickEnd() async {
    if (_startDay == null) return;
    final first = _dayOf(_startDay!).add(const Duration(days: 1));
    final current = _endDay == null ? null : _dayOf(_endDay!);
    final picked = await widget.pickers.pickDay(
      context,
      initial: current != null && !current.isBefore(first) ? current : first,
      first: first,
      last: first.add(const Duration(days: 365 * 5)),
      help: 'Batch Ends',
    );
    if (picked == null) return;
    _touch(() => _d.endsAt = calendarDayIso(picked));
  }

  Future<void> _pickCloses() async {
    final now = _now;
    final latest = _startDay == null ? now.add(const Duration(days: 365 * 5)) : _dayOf(_startDay!);
    final current = _d.enrollmentClosesAt?.toLocal();
    final day = await widget.pickers.pickDay(
      context,
      initial: current ?? (latest.isBefore(now) ? latest : now),
      first: DateTime(2020),
      last: latest.isBefore(now) ? now : latest,
      help: 'Enrolment Closes',
    );
    if (day == null || !mounted) return;
    final time = await widget.pickers.pickTime(
      context,
      initial: current == null ? const TimeOfDay(hour: 23, minute: 59) : TimeOfDay.fromDateTime(current),
      help: 'Enrolment Closes At',
    );
    if (time == null) return;
    _touch(() => _d.enrollmentClosesAt = DateTime(day.year, day.month, day.day, time.hour, time.minute));
  }

  Future<void> _pickClassTime({required bool start}) async {
    final current = start ? _d.classStartTime : _d.classEndTime;
    final picked = await widget.pickers.pickTime(
      context,
      initial: current == null
          ? (start ? const TimeOfDay(hour: 10, minute: 0) : const TimeOfDay(hour: 13, minute: 0))
          : TimeOfDay(hour: int.parse(current.substring(0, 2)), minute: int.parse(current.substring(3, 5))),
      help: start ? 'Class Starts' : 'Class Ends',
    );
    if (picked == null) return;
    final hhmm = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    _touch(() {
      if (start) {
        _d.classStartTime = hhmm;
        // An end at or before the new start would only be refused.
        if (_d.classEndTime != null && _d.classEndTime!.compareTo(hhmm) <= 0) _d.classEndTime = null;
      } else {
        _d.classEndTime = hhmm;
      }
    });
  }

  Future<void> _pickMode() async {
    final options = [...schedulableModes, if (!schedulableModes.contains(_d.mode)) _d.mode];
    final picked = await showAccountPicker<String>(
      context,
      title: 'Mode',
      items: options,
      labelOf: (m) => '${deliveryModeLabel(m)}${schedulableModes.contains(m) ? '' : ', no longer offered'}',
      selected: _d.mode,
    );
    if (picked == null) return;
    _touch(() => _d.mode = picked);
  }

  Future<void> _pickTimezone() async {
    final options = [..._timezones, if (_d.timezone.isNotEmpty && !_timezones.contains(_d.timezone)) _d.timezone];
    final picked = await showAccountPicker<String>(
      context,
      title: 'Time Zone',
      items: options,
      labelOf: (z) => z,
      searchable: true,
      selected: _d.timezone,
    );
    if (picked == null) return;
    _touch(() => _d.timezone = picked);
  }

  Future<void> _pickOfferEnd() async {
    final today = _dayOf(_today);
    final current = _d.discountEndsOn == null ? null : _dayOf(_d.discountEndsOn!);
    final picked = await widget.pickers.pickDay(
      context,
      initial: current ?? today,
      first: current != null && current.isBefore(today) ? current : today,
      last: today.add(const Duration(days: 365 * 5)),
      help: 'Offer Valid Until',
    );
    if (picked == null) return;
    _touch(() => _d.discountEndsOn = indiaDay(DateTime.utc(picked.year, picked.month, picked.day)));
  }

  List<FacultyMember> get _trainers => [
    for (final t in _faculty)
      if (t.role == 'TRAINER' && (t.active || _d.trainerIds.contains(t.id))) t,
  ];
  List<FacultyMember> get _specialists => [
    for (final t in _faculty)
      if (t.role == 'ENROLMENT_SPECIALIST' && (t.active || t.id == _d.enrolmentSpecialistId)) t,
  ];

  Future<void> _pickTrainers() async {
    final picked = {..._d.trainerIds};
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trainers', style: SiteText.subheading),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final t in _trainers)
                      AccountCheck(
                        key: ValueKey('trainer-${t.id}'),
                        value: picked.contains(t.id),
                        label: t.hasUser ? t.label : '${t.label}\nLink their ICR account under Team to ask them',
                        onChanged: !t.hasUser && !picked.contains(t.id)
                            ? null
                            : (on) => setSheet(() => on ? picked.add(t.id) : picked.remove(t.id)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SiteButton(label: 'Done', onPressed: () => Navigator.of(sheet).pop()),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    _touch(
      () => _d.trainerIds = [
        for (final t in _trainers)
          if (picked.contains(t.id)) t.id,
      ],
    );
  }

  Future<void> _pickSpecialist() async {
    const none = FacultyMember(id: '', name: 'None', role: 'ENROLMENT_SPECIALIST');
    final picked = await showAccountPicker<FacultyMember>(
      context,
      title: 'Specialist – Program Enrollment',
      items: [none, ..._specialists],
      labelOf: (t) => t.id.isEmpty ? t.name : t.label,
      selected: _specialists.where((t) => t.id == _d.enrolmentSpecialistId).firstOrNull ?? none,
    );
    if (picked == null) return;
    _touch(() => _d.enrolmentSpecialistId = picked.id.isEmpty ? null : picked.id);
  }

  Future<void> _askAgain(String trainerId) async {
    final b = batch;
    if (b == null) return;
    final refusal = await widget.controller.reinvite(b, trainerId);
    if (!mounted) return;
    if (refusal != null) {
      setState(() => _error = refusal);
      return;
    }
    setState(() => _asked = trainerId);
  }

  // --- save ---------------------------------------------------------------------------------------------------------

  Future<void> _save() async {
    _d.title = _title.text;
    _d.location = _venue.text;
    final missing = [
      for (final e in _need.entries)
        if (e.value) _needLabels[e.key]!,
    ];
    if (missing.isNotEmpty) {
      setState(() {
        _showMissing = true;
        _error = 'Fill in the required fields: ${missing.join(', ')}.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = _d.toJson(create: batch == null, instituteCourse: _instituteCourse, pickedDays: _pickedDays);
    final refusal = await widget.controller.save(course, batch, body);
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

  // --- the form -----------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final blocked = _timesProblem != null || _startError || _endError;
    final scheduleWords =
        _timesProblem ??
        [batchScheduleLabel(_pickedDays, _d.classStartTime, _d.classEndTime), _length].whereType<String>().join(' · ');
    return EditSheet(
      title: batch == null ? course.title : '${course.title} - ${batch!.code}',
      subtitle: batch == null ? 'A new batch of ${course.code}' : null,
      saving: _saving,
      error: _error,
      dirty: _dirty,
      onSave: blocked || _saving ? null : _save,
      children: [
        AccountField(
          key: const Key('batch.title'),
          label: 'Batch Name',
          controller: _title,
          hint: 'March 2026 — weekend',
          helper: 'Leave blank to name it after the start month.',
          onChanged: (_) => _touch(() {}),
        ),
        if (batch != null)
          AccountCheck(
            key: const Key('batch.cancel'),
            value: _d.cancelled,
            label: 'Cancel This Batch',
            onChanged: (on) => _touch(() => _d.cancelled = on),
          ),
        const SectionLabel('Schedule'),
        AccountSelectField(
          key: const Key('batch.startsAt'),
          label: 'Batch Starts',
          required: true,
          hint: 'Select a day',
          value: _startDay == null ? null : dayWords(_startDay),
          error: _startError
              ? 'Select today or a later day.'
              : _flag('startsAt')
              ? 'Select the day the batch starts.'
              : null,
          onTap: _pickStart,
        ),
        AccountSelectField(
          key: const Key('batch.endsAt'),
          label: 'Batch Ends',
          required: true,
          hint: 'Select a day',
          value: _endDay == null ? null : dayWords(_endDay),
          error: _endError
              ? 'Must be after the start date.'
              : _flag('endsAt')
              ? 'Select the day the batch ends.'
              : null,
          onTap: _d.startsAt == null ? null : _pickEnd,
        ),
        AccountSelectField(
          key: const Key('batch.closesAt'),
          label: 'Enrolment Closes',
          hint: 'Leave blank to stay open until the batch starts',
          value: _d.enrollmentClosesAt == null ? null : _closesWords(_d.enrollmentClosesAt!),
          onTap: _pickCloses,
          onClear: _d.enrollmentClosesAt == null ? null : () => _touch(() => _d.enrollmentClosesAt = null),
        ),
        Text('Class Days *', style: AccountText.label.copyWith(color: _flag('classDays') ? AppColors.error : null)),
        const SizedBox(height: 4),
        Wrap(
          children: [
            for (final d in BatchDraft.batchWeekdays)
              SizedBox(
                width: 100,
                child: AccountCheck(
                  key: ValueKey('batch.day.$d'),
                  value: _inRange.contains(d) && _d.classDays.contains(d),
                  label: weekdayShort[d]!,
                  onChanged: !_inRange.contains(d)
                      ? null
                      : (on) => _touch(() => on ? _d.classDays.add(d) : _d.classDays.remove(d)),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            _flag('classDays')
                ? 'Select at least one class day.'
                : 'Classes run on the selected days between the start and end dates.',
            style: _flag('classDays') ? AccountText.error : AccountText.meta,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AccountSelectField(
                key: const Key('batch.classStart'),
                label: 'Class Starts',
                required: true,
                hint: '10:00 AM',
                value: _d.classStartTime == null ? null : classTimeWords(_d.classStartTime),
                error: _flag('classStartTime') ? 'Select a time.' : null,
                onTap: () => _pickClassTime(start: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AccountSelectField(
                key: const Key('batch.classEnd'),
                label: 'Class Ends',
                required: true,
                hint: '1:00 PM',
                value: _d.classEndTime == null ? null : classTimeWords(_d.classEndTime),
                error: _flag('classEndTime') ? 'Select a time.' : null,
                helper: _d.classStartTime != null && _d.classEndTime != null && _timesProblem == null
                    ? '${classSpanLabel(_d.classStartTime!, _d.classEndTime!)} class'
                    : null,
                onTap: () => _pickClassTime(start: false),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            key: const Key('batch.scheduleWords'),
            scheduleWords.isEmpty ? 'Select the class days and the class time.' : scheduleWords,
            style: _timesProblem != null ? AccountText.error : AccountText.body,
          ),
        ),
        const SectionLabel('Delivery'),
        AccountSelectField(
          key: const Key('batch.mode'),
          label: 'Mode',
          required: true,
          hint: 'Select a mode',
          value: deliveryModeLabel(_d.mode),
          onTap: _pickMode,
        ),
        AccountSelectField(
          key: const Key('batch.timezone'),
          label: 'Time Zone',
          required: true,
          hint: 'Select a time zone',
          value: _d.timezone.isEmpty ? null : _d.timezone,
          helper: 'The class time is in this time zone.',
          error: _flag('timezone') ? 'Select the time zone for the class time.' : null,
          onTap: _pickTimezone,
        ),
        if (_d.inPerson)
          AccountField(
            key: const Key('batch.venue'),
            label: 'Venue',
            required: true,
            controller: _venue,
            hint: 'ICR Bengaluru campus',
            error: _flag('location') ? 'Enter where the classes meet.' : null,
            onChanged: (_) => _touch(() {}),
          ),
        const SectionLabel('Team'),
        if (_instituteCourse) ...[
          AccountSelectField(
            key: const Key('batch.trainers'),
            label: 'Trainers',
            hint: 'Select trainers',
            value: _d.trainerIds.isEmpty
                ? null
                : [
                    for (final t in _trainers)
                      if (_d.trainerIds.contains(t.id)) t.name,
                  ].join(', '),
            helper: _trainers.isEmpty
                ? 'Add trainers under Team to select them here.'
                : 'Add one or more trainers for this batch. Each trainer receives a request and teaches the batch once they '
                      'accept. The course page then shows their profile.',
            onTap: _trainers.isEmpty ? null : _pickTrainers,
          ),
          for (final t in _trainers)
            if (_d.trainerIds.contains(t.id))
              _TrainerAnswer(trainer: t, batch: batch, asked: _asked == t.id, onAskAgain: _askAgain),
          if (_d.trainerIds.isNotEmpty) const SizedBox(height: 10),
          AccountSelectField(
            key: const Key('batch.specialist'),
            label: 'Specialist – Program Enrollment',
            hint: 'None',
            value: _specialists.where((t) => t.id == _d.enrolmentSpecialistId).firstOrNull?.label,
            helper: _specialists.isNotEmpty
                ? 'Explains the course to applicants and takes them through enrolment. Shown on the course page as '
                      'the contact for this batch.'
                : 'Add a Specialist – Program Enrollment under Team to select one here.',
            onTap: _specialists.isEmpty ? null : _pickSpecialist,
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text('ICR’s own courses name their mentor on the website’s console.', style: AccountText.meta),
          ),
        const SectionLabel('Batch Size & Price'),
        AccountField(
          key: const Key('batch.size'),
          label: 'Batch Size',
          controller: _size,
          keyboardType: TextInputType.number,
          helper: 'Maximum number of candidates. Leave blank for no limit.',
          onChanged: (v) => _touch(() => _d.maxSeats = int.tryParse(v.trim())),
        ),
        if (_paid)
          ..._priceFields()
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text('This course is free. Set its Access to Paid to price its batches.', style: AccountText.meta),
          ),
      ],
    );
  }

  List<Widget> _priceFields() {
    final pricePaisa = _d.priceAmount ?? 0;
    final percent = _d.discountPercent;
    final endsOn = _d.discountEndsOn;
    final dayPast = endsOn != null && offerEndDateInPast(endsOn, now: _now);
    final salePaisa = pricePaisa - offerPaisa(pricePaisa, percent);
    return [
      AccountField(
        key: const Key('batch.price'),
        label: _d.inPerson ? 'Face 2 Face Price (₹)' : 'Live Virtual Price (₹)',
        required: true,
        controller: _price,
        keyboardType: TextInputType.number,
        helper: 'Per place, before GST.',
        error: _flag('priceAmount') ? 'Enter the price of a place.' : null,
        onChanged: (v) => _touch(() {
          final rupeesTyped = num.tryParse(v.trim());
          _d.priceAmount = rupeesTyped == null ? null : (rupeesTyped < 0 ? 0 : (rupeesTyped * 100).round());
        }),
      ),
      AccountField(
        key: const Key('batch.discount'),
        label: 'Discount (%)',
        controller: _discount,
        keyboardType: TextInputType.number,
        helper: '0–$maxDiscountPercent%. Leave blank for no offer.',
        onChanged: (v) => _touch(() => _d.discountPercent = clampDiscount(num.tryParse(v.trim()))),
      ),
      AccountSelectField(
        key: const Key('batch.offerEnd'),
        label: 'Offer Valid Until',
        hint: 'Leave blank to run it until removed',
        value: endsOn == null ? null : dayWords(endsOn),
        error: dayPast ? 'This day has already passed.' : null,
        helper: dayPast ? null : 'Last day of the offer. Leave blank to run it until removed.',
        onTap: percent == 0 ? null : _pickOfferEnd,
        onClear: endsOn == null ? null : () => _touch(() => _d.discountEndsOn = null),
      ),
      if (pricePaisa > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text.rich(
            key: const Key('batch.priceWords'),
            TextSpan(
              children: [
                const TextSpan(text: 'Learners pay '),
                TextSpan(
                  text: rupees(salePaisa),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: ' + GST'),
                if (percent > 0) ...[
                  const TextSpan(text: ' instead of '),
                  TextSpan(
                    text: rupees(pricePaisa),
                    style: const TextStyle(decoration: TextDecoration.lineThrough),
                  ),
                  TextSpan(text: ' ($percent% off${endsOn != null ? ', until ${dayWords(endsOn)}' : ''})'),
                ],
                const TextSpan(text: '.'),
              ],
            ),
            style: AccountText.body,
          ),
        ),
    ];
  }

  static String _closesWords(DateTime at) {
    final l = at.toLocal();
    final t = TimeOfDay.fromDateTime(l);
    return '${dayWords(indiaDay(DateTime.utc(l.year, l.month, l.day)))}, ${classTimeWords('${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')}';
  }
}

/// One picked trainer and their answer: asked when the batch is saved, waiting, accepted or declined (with "Ask
/// again").
class _TrainerAnswer extends StatelessWidget {
  const _TrainerAnswer({required this.trainer, required this.batch, required this.asked, required this.onAskAgain});

  final FacultyMember trainer;
  final ConsoleBatch? batch;
  final bool asked;
  final ValueChanged<String> onAskAgain;

  @override
  Widget build(BuildContext context) {
    final place = batch?.trainerPlaces.where((p) => p.trainerId == trainer.id).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(trainer.name, style: AccountText.body)),
          if (place == null)
            const ConsoleChip(label: 'Asked when you save', tone: ConsoleTone.muted)
          else
            ConsoleChip(label: trainerAnswerLabel(place.status), tone: trainerAnswerTone(place.status)),
          if (place?.status == 'DECLINED' && batch != null)
            TextButton(
              key: ValueKey('askAgain-${trainer.id}'),
              onPressed: asked ? null : () => onAskAgain(trainer.id),
              child: Text(asked ? 'Asked Again' : 'Ask Again'),
            ),
        ],
      ),
    );
  }
}
