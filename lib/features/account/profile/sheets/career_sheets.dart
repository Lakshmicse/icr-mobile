import 'package:flutter/material.dart';

import '../../../../core/api/api_error.dart';
import '../../account_labels.dart';
import '../../account_models.dart';
import '../../account_rules.dart';
import '../../widgets/account_kit.dart';
import '../profile_controller.dart';
import '../profile_fields.dart';

/// The sheets that edit one row of the career: a role, a qualification, a
/// career break. Each edits ONE item and the controller merges it into the whole
/// list the API saves (`PUT` replaces every row); Delete asks first.

bool _blank(String s) => s.trim().isEmpty;

// --- a role --------------------------------------------------------------------------------------------------

/// Adds a role, or edits [role] (and can delete it). True when something was saved.
Future<bool> showExperienceSheet(BuildContext context, MyProfileController controller, {Experience? role}) async =>
    await showEditSheet<bool>(context, builder: (_) => ExperienceSheet(controller: controller, role: role)) ?? false;

class ExperienceSheet extends StatefulWidget {
  const ExperienceSheet({super.key, required this.controller, this.role, this.now});

  final MyProfileController controller;
  final Experience? role;

  /// The clock the date rules judge against.
  final DateTime? now;

  @override
  State<ExperienceSheet> createState() => _ExperienceSheetState();
}

class _ExperienceSheetState extends State<ExperienceSheet> {
  late final Experience? _r = widget.role;
  late final _title = TextEditingController(text: _r?.title ?? '');
  late final _org = TextEditingController(text: _r?.organisation ?? '');
  late final _description = TextEditingController(text: _r?.description ?? '');
  late LinkedCompany? _picked = _r?.company;
  late String? _kind = _r?.employmentType;
  late String _city = _r?.city ?? '';
  late bool _current = _r?.isCurrent ?? false;
  late int? _startYear = _r?.startYear;
  late int? _startMonth = _r?.startMonth;
  late int? _endYear = _r?.endYear;
  late int? _endMonth = _r?.endMonth;
  bool _askToJoin = true;
  late final String _initial = _snapshot();
  List<String>? _titles;
  Set<String> _mine = const {};
  bool _saving = false;
  bool _tried = false;
  String? _error;

  String _snapshot() => [
    _title.text,
    _org.text,
    _picked?.id,
    _kind,
    _city,
    _current,
    _startYear,
    _startMonth,
    _endYear,
    _endMonth,
    _description.text,
  ].join('\u0001');

  @override
  void initState() {
    super.initState();
    _loadMine();
  }

  @override
  void dispose() {
    for (final c in [_title, _org, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The companies the person already belongs to or has asked, so "Ask to join" is not offered for them.
  Future<void> _loadMine() async {
    try {
      final mine = await widget.controller.repository.myCompanies();
      if (!mounted) return;
      setState(() => _mine = {for (final c in mine.companies) c.companyId, for (final r in mine.requests) r.companyId});
    } catch (_) {}
  }

  Experience _draft() => Experience(
    id: _r?.id,
    title: _title.text,
    organisation: _picked?.name ?? _org.text,
    company: _picked,
    employmentType: _kind,
    city: _blank(_city) ? null : _city,
    industryKeys: _r?.industryKeys ?? const [],
    startYear: _startYear ?? DateTime.now().year,
    startMonth: _startMonth,
    endYear: _current ? null : _endYear,
    endMonth: _current ? null : _endMonth,
    isCurrent: _current,
    description: _blank(_description.text) ? null : _description.text,
  );

  Map<String, String> get _problems {
    final out = experienceProblems(_draft(), now: widget.now);
    if (_startYear == null) out['start'] = 'Choose when you started.';
    return out;
  }

  bool get _offerJoin => _current && _picked != null && !_mine.contains(_picked!.id);

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _tried = true);
    if (_problems.isNotEmpty) return;
    if (_snapshot() == _initial && _r != null) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // The request to join goes first, so a refusal saves nothing.
      if (_offerJoin && _askToJoin) await widget.controller.repository.requestToJoin(_picked!.id);
      await widget.controller.saveRole(_draft());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final role = _r!;
    final ok = await confirmAction(
      context,
      title: 'Delete this role?',
      message: '${role.title} at ${role.organisation} will be taken off your profile.',
      confirm: 'Delete',
    );
    if (!ok || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.deleteRole(role.id!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<List<String>> _suggestTitles(String q) async {
    _titles ??= await widget.controller.repository.jobTitles();
    final lower = q.toLowerCase();
    return [
      for (final t in _titles!)
        if (t.toLowerCase().contains(lower) && t.toLowerCase() != lower) t,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = _tried ? _problems : const <String, String>{};
    final years = careerYearOptions(widget.now);
    return EditSheet(
      title: _r == null ? 'Add experience' : 'Edit experience',
      saving: _saving,
      error: _error,
      dirty: _snapshot() != _initial,
      onSave: _save,
      onDelete: _r == null ? null : _delete,
      children: [
        SuggestField<String>(
          fieldKey: const Key('role.title'),
          label: 'Title',
          controller: _title,
          required: true,
          maxLength: 160,
          suggest: _suggestTitles,
          labelOf: (t) => t,
          error: p['title'],
          hint: 'e.g. Facilities Manager',
          onChanged: (_) => setState(() {}),
        ),
        AccountSelectField(
          key: const Key('role.kind'),
          label: 'Employment type',
          hint: 'Choose one',
          value: employmentTypeLabel(_kind),
          onClear: () => setState(() => _kind = null),
          onTap: () async {
            final picked = await showAccountPicker<(String, String)>(
              context,
              title: 'Employment type',
              items: employmentTypes,
              labelOf: (t) => t.$2,
              selected: employmentTypes.where((t) => t.$1 == _kind).firstOrNull,
            );
            if (picked != null) setState(() => _kind = picked.$1);
          },
        ),
        SuggestField<CompanyHit>(
          fieldKey: const Key('role.organisation'),
          label: 'Organisation',
          controller: _org,
          required: true,
          maxLength: 160,
          minChars: 2,
          debounce: const Duration(milliseconds: 300),
          suggest: widget.controller.repository.searchCompanies,
          labelOf: (c) => c.name,
          subtitleOf: (c) => c.city == null ? 'On ICR' : '${c.city} · on ICR',
          error: p['organisation'],
          helper: _picked == null ? 'Pick it from the list if it is already on ICR.' : 'Linked to its page on ICR.',
          onPick: (c) => setState(() {
            _picked = LinkedCompany(id: c.id, name: c.name, logoUrl: c.logoUrl);
            _askToJoin = true;
          }),
          // Typing anything else unlinks it.
          onChanged: (text) {
            if (_picked != null && text != _picked!.name) setState(() => _picked = null);
          },
        ),
        if (_offerJoin)
          AccountCheck(
            key: const Key('role.askToJoin'),
            value: _askToJoin,
            onChanged: (v) => setState(() => _askToJoin = v),
            label: 'Ask to join ${_picked!.name}’s team on ICR. Its admins decide.',
          ),
        CityPickerField(
          fieldKey: const Key('role.city'),
          label: 'City',
          value: _city,
          loadCities: widget.controller.repository.cities,
          labelOfCity: (c) => c.name,
          error: p['city'],
          onChanged: (c) => setState(() => _city = c?.name ?? ''),
        ),
        AccountCheck(
          key: const Key('role.current'),
          value: _current,
          label: 'I work here now',
          onChanged: (v) => setState(() => _current = v),
        ),
        MonthYearField(
          label: 'Start date',
          keyPrefix: 'role.start',
          required: true,
          month: _startMonth,
          year: _startYear,
          years: years,
          error: p['start'],
          onChanged: (m, y) => setState(() {
            _startMonth = m;
            _startYear = y;
          }),
        ),
        if (!_current)
          MonthYearField(
            label: 'End date',
            keyPrefix: 'role.end',
            required: true,
            month: _endMonth,
            year: _endYear,
            years: years,
            error: p['end'],
            onChanged: (m, y) => setState(() {
              _endMonth = m;
              _endYear = y;
            }),
          ),
        AccountField(
          fieldKey: const Key('role.description'),
          label: 'Description',
          controller: _description,
          maxLength: 2000,
          minLines: 4,
          maxLines: 8,
          counter: true,
          error: p['description'],
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}

// --- a qualification -----------------------------------------------------------------------------------------

Future<bool> showEducationSheet(BuildContext context, MyProfileController controller, {Education? degree}) async =>
    await showEditSheet<bool>(context, builder: (_) => EducationSheet(controller: controller, degree: degree)) ?? false;

class EducationSheet extends StatefulWidget {
  const EducationSheet({super.key, required this.controller, this.degree, this.now});

  final MyProfileController controller;
  final Education? degree;
  final DateTime? now;

  @override
  State<EducationSheet> createState() => _EducationSheetState();
}

class _EducationSheetState extends State<EducationSheet> {
  late final Education? _e = widget.degree;
  late final _institution = TextEditingController(text: _e?.institution ?? '');
  late final _university = TextEditingController(text: _e?.university ?? '');
  late final _degree = TextEditingController(text: _e?.degree ?? '');
  late final _field = TextEditingController(text: _e?.fieldOfStudy ?? '');
  late final _grade = TextEditingController(text: _e?.grade ?? '');
  late int? _start = _e?.startYear;
  late int? _end = _e?.endYear;
  late final String _initial = _snapshot();
  bool _saving = false;
  bool _tried = false;
  String? _error;

  String _snapshot() =>
      [_institution.text, _university.text, _degree.text, _field.text, _grade.text, _start, _end].join('\u0001');

  @override
  void dispose() {
    for (final c in [_institution, _university, _degree, _field, _grade]) {
      c.dispose();
    }
    super.dispose();
  }

  Education _draft() => Education(
    id: _e?.id,
    institution: _institution.text,
    university: _blank(_university.text) ? null : _university.text,
    degree: _blank(_degree.text) ? null : _degree.text,
    fieldOfStudy: _blank(_field.text) ? null : _field.text,
    startYear: _start,
    endYear: _end,
    grade: _blank(_grade.text) ? null : _grade.text,
  );

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _tried = true);
    if (educationProblems(_draft(), now: widget.now).isNotEmpty) return;
    if (_snapshot() == _initial && _e != null) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.saveDegree(_draft());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final degree = _e!;
    final ok = await confirmAction(
      context,
      title: 'Delete this qualification?',
      message: '${degree.institution} will be taken off your profile.',
      confirm: 'Delete',
    );
    if (!ok || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.deleteDegree(degree.id!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _tried ? educationProblems(_draft(), now: widget.now) : const <String, String>{};
    final years = careerYearOptions(widget.now);
    return EditSheet(
      title: _e == null ? 'Add education' : 'Edit education',
      saving: _saving,
      error: _error,
      dirty: _snapshot() != _initial,
      onSave: _save,
      onDelete: _e == null ? null : _delete,
      children: [
        AccountField(
          fieldKey: const Key('edu.institution'),
          label: 'School or institution',
          controller: _institution,
          required: true,
          maxLength: 180,
          error: p['institution'],
          onChanged: (_) => setState(() {}),
        ),
        AccountField(
          fieldKey: const Key('edu.degree'),
          label: 'Degree',
          controller: _degree,
          maxLength: 120,
          hint: 'e.g. B.Tech',
          onChanged: (_) => setState(() {}),
        ),
        AccountField(
          fieldKey: const Key('edu.field'),
          label: 'Field of study',
          controller: _field,
          maxLength: 160,
          hint: 'e.g. Mechanical Engineering',
          onChanged: (_) => setState(() {}),
        ),
        AccountField(
          fieldKey: const Key('edu.university'),
          label: 'University',
          controller: _university,
          maxLength: 180,
          helper: 'If your college awards its degrees through one.',
          onChanged: (_) => setState(() {}),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AccountSelectField(
                key: const Key('edu.start'),
                label: 'Start year',
                hint: 'Year',
                value: _start?.toString(),
                error: p['start'],
                onClear: () => setState(() => _start = null),
                onTap: () async {
                  final y = await showAccountPicker<int>(context, title: 'Start year', items: years, labelOf: (y) => '$y', searchable: true, selected: _start);
                  if (y != null) setState(() => _start = y);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AccountSelectField(
                key: const Key('edu.end'),
                label: 'End year',
                hint: 'Year',
                value: _end?.toString(),
                error: p['end'],
                helper: 'Leave blank while you study.',
                onClear: () => setState(() => _end = null),
                onTap: () async {
                  final y = await showAccountPicker<int>(context, title: 'End year', items: years, labelOf: (y) => '$y', searchable: true, selected: _end);
                  if (y != null) setState(() => _end = y);
                },
              ),
            ),
          ],
        ),
        AccountField(
          fieldKey: const Key('edu.grade'),
          label: 'Grade',
          controller: _grade,
          maxLength: 60,
          hint: 'e.g. First class, 8.4 CGPA',
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}

// --- a career break ------------------------------------------------------------------------------------------

/// Adds a career break (from a gap, with [prefill] dates) or edits [pause].
Future<bool> showCareerBreakSheet(
  BuildContext context,
  MyProfileController controller, {
  CareerBreak? pause,
  CareerGap? prefill,
}) async =>
    await showEditSheet<bool>(context, builder: (_) => CareerBreakSheet(controller: controller, pause: pause, prefill: prefill)) ?? false;

class CareerBreakSheet extends StatefulWidget {
  const CareerBreakSheet({super.key, required this.controller, this.pause, this.prefill, this.now});

  final MyProfileController controller;
  final CareerBreak? pause;
  final CareerGap? prefill;
  final DateTime? now;

  @override
  State<CareerBreakSheet> createState() => _CareerBreakSheetState();
}

class _CareerBreakSheetState extends State<CareerBreakSheet> {
  late final CareerBreak? _b = widget.pause;
  late final _description = TextEditingController(text: _b?.description ?? '');
  late String? _reason = _b?.reason;
  late bool _current = _b?.isCurrent ?? widget.prefill?.ongoing ?? false;
  late int? _startYear = _b?.startYear ?? widget.prefill?.fromYear;
  late int? _startMonth = _b?.startMonth ?? widget.prefill?.fromMonth;
  late int? _endYear = _b?.endYear ?? (widget.prefill != null && !widget.prefill!.ongoing ? widget.prefill!.toYear : null);
  late int? _endMonth = _b?.endMonth ?? (widget.prefill != null && !widget.prefill!.ongoing ? widget.prefill!.toMonth : null);
  late final String _initial = _snapshot();
  bool _saving = false;
  bool _tried = false;
  String? _error;

  String _snapshot() => [_reason, _current, _startYear, _startMonth, _endYear, _endMonth, _description.text].join('\u0001');

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  CareerBreak _draft() => CareerBreak(
    id: _b?.id,
    reason: _reason ?? '',
    startYear: _startYear ?? DateTime.now().year,
    startMonth: _startMonth,
    endYear: _current ? null : _endYear,
    endMonth: _current ? null : _endMonth,
    isCurrent: _current,
    description: _blank(_description.text) ? null : _description.text,
  );

  Map<String, String> get _problems {
    final out = careerBreakProblems(_draft(), now: widget.now);
    if (_startYear == null) out['start'] = 'Choose when the break started.';
    return out;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _tried = true);
    if (_problems.isNotEmpty) return;
    if (_snapshot() == _initial && _b != null) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.savePause(_draft());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final pause = _b!;
    final ok = await confirmAction(
      context,
      title: 'Delete this career break?',
      message: 'It will be taken off your profile.',
      confirm: 'Delete',
    );
    if (!ok || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.deletePause(pause.id!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _tried ? _problems : const <String, String>{};
    final years = careerYearOptions(widget.now);
    return EditSheet(
      title: _b == null ? 'Add career break' : 'Edit career break',
      subtitle: 'A pause between roles, in your own words.',
      saving: _saving,
      error: _error,
      dirty: _snapshot() != _initial,
      onSave: _save,
      onDelete: _b == null ? null : _delete,
      children: [
        AccountSelectField(
          key: const Key('break.reason'),
          label: 'Reason',
          hint: 'Choose why you took this break',
          required: true,
          value: _reason == null ? null : careerBreakLabel(_reason),
          error: p['reason'],
          onTap: () async {
            final picked = await showAccountPicker<(String, String)>(
              context,
              title: 'Reason',
              items: careerBreakReasons,
              labelOf: (r) => r.$2,
              selected: careerBreakReasons.where((r) => r.$1 == _reason).firstOrNull,
            );
            if (picked != null) setState(() => _reason = picked.$1);
          },
        ),
        AccountCheck(
          key: const Key('break.current'),
          value: _current,
          label: 'I’m on this break now',
          onChanged: (v) => setState(() => _current = v),
        ),
        MonthYearField(
          label: 'Start date',
          keyPrefix: 'break.start',
          required: true,
          month: _startMonth,
          year: _startYear,
          years: years,
          error: p['start'],
          onChanged: (m, y) => setState(() {
            _startMonth = m;
            _startYear = y;
          }),
        ),
        if (!_current)
          MonthYearField(
            label: 'End date',
            keyPrefix: 'break.end',
            required: true,
            month: _endMonth,
            year: _endYear,
            years: years,
            error: p['end'],
            onChanged: (m, y) => setState(() {
              _endMonth = m;
              _endYear = y;
            }),
          ),
        AccountField(
          fieldKey: const Key('break.description'),
          label: 'Description',
          controller: _description,
          maxLength: 2000,
          minLines: 3,
          maxLines: 6,
          counter: true,
          error: p['description'],
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}
