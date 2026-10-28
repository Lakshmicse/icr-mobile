import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/links.dart' show showMessage;
import '../../../core/widgets/buttons.dart';
import '../../career/career_styles.dart';
import '../../career/career_widgets.dart';
import '../job_links.dart';
import '../jobs_navigation.dart';
import '../jobs_styles.dart';
import 'hiring_models.dart';
import 'hiring_repository.dart';
import 'job_rules.dart';
import 'post_job_controller.dart';
import 'screening_editor.dart';

/// "Post a job" and "Edit job": the composer. A posting may be saved half-filled; what it needs to go
/// live is the checklist at the foot (`jobPublishBlockers`, the same list the API enforces), and the
/// API has the last word on the company's verification and plan.
class PostJobScreen extends StatefulWidget {
  const PostJobScreen({
    super.key,
    required this.repository,
    this.jobId,
    this.initial,
    this.links = const SystemJobLinks(),
    this.navigation = JobsNavigation.none,
    this.onBack,
    this.onSaved,
    this.clock,
  });

  final HiringRepository repository;

  /// The posting to edit; null makes a new one.
  final String? jobId;

  /// A draft to start from (a copy of another posting, a prefilled title).
  final JobDraft? initial;
  final JobLinks links;
  final JobsNavigation navigation;
  final VoidCallback? onBack;

  /// Tells whoever opened the composer that the posting was saved or moved.
  final void Function(PostOutcome outcome)? onSaved;
  final DateTime Function()? clock;

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  late final PostJobController _c = PostJobController(
    widget.repository,
    jobId: widget.jobId,
    initial: widget.initial,
    clock: widget.clock,
  );

  final _title = TextEditingController();
  final _department = TextEditingController();
  final _state = TextEditingController();
  final _city = TextEditingController();
  final _description = TextEditingController();
  final _skill = TextEditingController();
  final _preferred = TextEditingController();
  final _expMin = TextEditingController();
  final _expMax = TextEditingController();
  final _salMin = TextEditingController();
  final _salMax = TextEditingController();
  final _openings = TextEditingController();
  final _applyUrl = TextEditingController();
  final _titleFocus = FocusNode();
  final _scroll = ScrollController();
  final _sections = <String, GlobalKey>{for (final k in _sectionKeys) k: GlobalKey()};
  static const _sectionKeys = ['basics', 'location', 'description', 'skills', 'pay', 'apply', 'questions', 'checklist'];

  Timer? _debounce;
  List<String> _skillHints = const [];
  bool _filled = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _c.addListener(_loaded);
    _c.start();
  }

  /// The boxes take their text from the draft once, when it has loaded (a new draft is empty).
  void _loaded() {
    if (_filled || _c.loading) return;
    _filled = true;
    final d = _c.draft;
    _title.text = d.title;
    _department.text = d.department;
    _state.text = d.state;
    _description.text = d.description;
    _expMin.text = d.experienceMin?.toString() ?? '';
    _expMax.text = d.experienceMax?.toString() ?? '';
    _salMin.text = d.salaryMin == null ? '' : '${d.salaryMin!.round()}';
    _salMax.text = d.salaryMax == null ? '' : '${d.salaryMax!.round()}';
    _openings.text = '${d.openings}';
    _applyUrl.text = d.applyUrl;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _c.removeListener(_loaded);
    _c.dispose();
    for (final c in [
      _title,
      _department,
      _state,
      _city,
      _description,
      _skill,
      _preferred,
      _expMin,
      _expMax,
      _salMin,
      _salMax,
      _openings,
      _applyUrl,
    ]) {
      c.dispose();
    }
    _titleFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollTo(String section) {
    final ctx = _sections[section]?.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.05);
  }

  int? _int(String s) => int.tryParse(s.trim());
  num? _num(String s) => num.tryParse(s.trim());

  void _hintSkills(String typed) {
    _debounce?.cancel();
    if (typed.trim().length < 2) {
      setState(() => _skillHints = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final hints = await _c.skillSuggestions(typed);
      if (mounted && _skill.text == typed) setState(() => _skillHints = hints);
    });
  }

  void _addSkill(String raw, {bool preferred = false}) {
    final skill = raw.trim();
    if (skill.isEmpty) return;
    final list = preferred ? _c.draft.preferredSkills : _c.draft.skills;
    if (list.any((s) => s.toLowerCase() == skill.toLowerCase())) return;
    if (skill.length > JobLimits.skillMax) {
      setState(() => _problem = 'Keep each skill to ${JobLimits.skillMax} characters or fewer.');
      return;
    }
    if (list.length >= JobLimits.skillsMax) {
      setState(() => _problem = 'List at most ${JobLimits.skillsMax} skills.');
      return;
    }
    _problem = null;
    _c.update((d) => preferred ? d.copyWith(preferredSkills: [...list, skill]) : d.copyWith(skills: [...list, skill]));
    (preferred ? _preferred : _skill).clear();
    setState(() => _skillHints = const []);
  }

  void _addCity() {
    final city = _city.text.trim();
    if (city.isEmpty) return;
    final cities = _c.draft.cities;
    if (cities.any((c) => c.toLowerCase() == city.toLowerCase())) {
      setState(() => _problem = 'Each city can be listed once.');
      return;
    }
    if (cities.length >= JobLimits.citiesMax) {
      setState(() => _problem = 'List at most ${JobLimits.citiesMax} cities.');
      return;
    }
    if (city.length > JobLimits.cityMax) {
      setState(() => _problem = 'Keep each city to ${JobLimits.cityMax} characters or fewer.');
      return;
    }
    _problem = null;
    _c.update((d) => d.copyWith(cities: [...cities, city]));
    _city.clear();
  }

  Future<void> _run(Future<PostOutcome> Function() action) async {
    FocusScope.of(context).unfocus();
    final outcome = await action();
    if (!mounted) return;
    setState(() => _problem = outcome.ok ? null : outcome.message);
    if (!outcome.ok) {
      showMessage(context, outcome.message!);
      if (_c.blockers.isNotEmpty && outcome.jobId == null) _scrollTo('checklist');
      if (outcome.jobId != null) widget.onSaved?.call(outcome);
      return;
    }
    widget.onSaved?.call(outcome);
    showMessage(context, outcome.note ?? 'Saved.');
    // A posting that went live or into review is done with: back to the list. `pop`, not `maybePop`:
    // the guard against unsaved changes has not seen the save yet (it rebuilds on the next frame).
    if (outcome.status == PostingStatus.open || outcome.status == PostingStatus.inReview) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<bool> _confirmLeave() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        key: const ValueKey('leave-dialog'),
        title: const Text('Leave without saving?'),
        content: const Text('What you changed on this posting is not saved yet.'),
        actions: [
          TextButton(
            key: const ValueKey('leave-stay'),
            onPressed: () => Navigator.pop(context, 'stay'),
            child: const Text('Keep editing'),
          ),
          TextButton(
            key: const ValueKey('leave-discard'),
            onPressed: () => Navigator.pop(context, 'discard'),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard'),
          ),
          TextButton(
            key: const ValueKey('leave-save'),
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save draft'),
          ),
        ],
      ),
    );
    if (choice == 'save') {
      final outcome = await _c.save();
      if (!mounted) return false;
      if (!outcome.ok) {
        showMessage(context, outcome.message!);
        return false;
      }
      widget.onSaved?.call(outcome);
      return true;
    }
    return choice == 'discard';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => PopScope(
        canPop: !_c.dirty,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final navigator = Navigator.of(context);
          if (await _confirmLeave() && mounted) navigator.pop();
        },
        child: CareerScaffold(
          title: _c.editing ? 'Edit job' : 'Post a job',
          onBack: widget.onBack,
          unread: _c.unread,
          onBell: () => widget.navigation.openNotifications(context, widget.links),
          bottomBar: _c.loading || _c.error != null ? null : _actionBar(),
          body: _body(),
        ),
      ),
    );
  }

  Widget _body() {
    if (_c.loading) return const CareerLoading();
    if (_c.error != null) {
      return ListView(
        children: [
          CareerNotice(
            key: const ValueKey('composer-error'),
            icon: LucideIcons.cloudOff,
            title: "Couldn't open this posting",
            body: _c.error!,
            action: 'Try again',
            onAction: () {
              _filled = false;
              _c.start();
            },
          ),
        ],
      );
    }
    final d = _c.draft;
    // One scroll view, not a lazy list: every card is built, so the checklist can always jump to the one it names.
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._notices(),
          _card('basics', 'The role', [
            _label('Job title'),
            TextField(
              key: const ValueKey('job-title'),
              controller: _title,
              focusNode: _titleFocus,
              maxLength: JobLimits.titleMax,
              textCapitalization: TextCapitalization.words,
              style: JobsText.formInput,
              decoration: _decoration(hint: 'Facility Supervisor'),
              onChanged: _c.setTitle,
            ),
            ..._titleHints(),
            _label('Department (optional)'),
            TextField(
              key: const ValueKey('job-department'),
              controller: _department,
              style: JobsText.formInput,
              decoration: _decoration(hint: 'Operations'),
              onChanged: (v) => _c.update((x) => x.copyWith(department: v)),
            ),
            _label('Seniority'),
            _choices(
              keyPrefix: 'seniority',
              options: const [
                ('INTERN', 'Intern'),
                ('JUNIOR', 'Junior'),
                ('MID', 'Mid-level'),
                ('SENIOR', 'Senior'),
                ('LEAD', 'Lead'),
                ('DIRECTOR', 'Director'),
                ('EXECUTIVE', 'Executive'),
              ],
              value: d.seniority,
              onPick: (v) => _c.update((x) => v == null ? x.copyWith(clearSeniority: true) : x.copyWith(seniority: v)),
              clearable: true,
            ),
            _label('Job type'),
            _choices(
              keyPrefix: 'type',
              options: const [
                ('FULL_TIME', 'Full-time'),
                ('PART_TIME', 'Part-time'),
                ('CONTRACT', 'Contract'),
                ('INTERNSHIP', 'Internship'),
                ('TEMPORARY', 'Temporary'),
                ('FREELANCE', 'Freelance'),
              ],
              value: d.employmentType,
              onPick: (v) => _c.update((x) => x.copyWith(employmentType: v)),
            ),
            _label('Work mode'),
            _choices(
              keyPrefix: 'mode',
              options: const [('ONSITE', 'On-site'), ('HYBRID', 'Hybrid'), ('REMOTE', 'Remote')],
              value: d.workMode,
              onPick: (v) => _c.update((x) => x.copyWith(workMode: v)),
            ),
          ]),
          _card('location', 'Where', [
            _label('Country'),
            DropdownButtonFormField<String>(
              key: const ValueKey('job-country'),
              initialValue: jobCountries.contains(d.country) ? d.country : null,
              isDense: true,
              isExpanded: true,
              decoration: _decoration(hint: 'Pick a country'),
              items: [
                for (final c in jobCountries)
                  DropdownMenuItem(
                    value: c,
                    child: Text(c, style: JobsText.formInput.copyWith(fontSize: 14)),
                  ),
              ],
              onChanged: (v) {
                if (v != null) _c.update((x) => x.copyWith(country: v));
              },
            ),
            _label('State (optional)'),
            TextField(
              key: const ValueKey('job-state'),
              controller: _state,
              style: JobsText.formInput,
              decoration: _decoration(hint: 'Gujarat'),
              onChanged: (v) => _c.update((x) => x.copyWith(state: v)),
            ),
            _label('Cities'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('job-city'),
                    controller: _city,
                    style: JobsText.formInput,
                    decoration: _decoration(hint: 'Add a city'),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addCity(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const ValueKey('add-city'),
                  tooltip: 'Add city',
                  onPressed: _addCity,
                  icon: const Icon(LucideIcons.plus, size: 18),
                ),
              ],
            ),
            if (d.cities.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final city in d.cities)
                      InputChip(
                        key: ValueKey('city-$city'),
                        label: Text(city),
                        onDeleted: () => _c.update(
                          (x) => x.copyWith(
                            cities: x.cities.where((c) => c != city).toList(),
                            cityOpenings: {...x.cityOpenings}..remove(city),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (d.cities.length >= 2) ...[
              _label('Openings in each city'),
              for (final city in d.cities)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(city, style: CareerText.bodyStrong)),
                      SizedBox(
                        width: 90,
                        child: TextFormField(
                          key: ValueKey('openings-$city'),
                          initialValue: d.cityOpenings[city]?.toString() ?? '',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          style: JobsText.formInput,
                          decoration: _decoration(hint: 'Seats'),
                          onChanged: (v) => _c.update((x) {
                            final n = int.tryParse(v);
                            final next = {...x.cityOpenings};
                            if (n == null || n < 1) {
                              next.remove(city);
                            } else {
                              next[city] = n;
                            }
                            return x.copyWith(cityOpenings: next);
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              Text('${d.totalOpenings} openings in all', style: CareerText.meta, key: const ValueKey('openings-total')),
            ],
          ]),
          _card('description', 'The description', [
            Text(
              'Write it plainly. Start a line with "- " for a bullet and "## " for a heading.',
              style: CareerText.body,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('job-description'),
              controller: _description,
              minLines: 8,
              maxLines: 18,
              style: JobsText.formInput,
              decoration: _decoration(hint: 'What the role does, who it suits, what the first months look like'),
              onChanged: (v) => _c.update((x) => x.copyWith(description: v)),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${htmlToPlainText(descriptionToHtml(d.description)).length} of ${JobLimits.descriptionMin} characters needed to publish',
                key: const ValueKey('description-count'),
                style: CareerText.meta,
              ),
            ),
          ]),
          _card('skills', 'Skills', [
            _label('Required skills'),
            _skillInput(preferred: false),
            _skillChips(d.skills, preferred: false),
            _label('Nice-to-have skills (optional)'),
            _skillInput(preferred: true),
            _skillChips(d.preferredSkills, preferred: true),
            _label('Experience (years)'),
            Row(
              children: [
                Expanded(
                  child: _numberBox(
                    'exp-min',
                    _expMin,
                    'From',
                    (v) => _c.update(
                      (x) => v == null ? x.copyWith(clearExperienceMin: true) : x.copyWith(experienceMin: v),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numberBox(
                    'exp-max',
                    _expMax,
                    'To',
                    (v) => _c.update(
                      (x) => v == null ? x.copyWith(clearExperienceMax: true) : x.copyWith(experienceMax: v),
                    ),
                  ),
                ),
              ],
            ),
          ]),
          _card('pay', 'Pay', [
            Row(
              children: [
                Expanded(
                  child: _moneyBox(
                    'sal-min',
                    _salMin,
                    'Minimum',
                    (v) => _c.update((x) => v == null ? x.copyWith(clearSalaryMin: true) : x.copyWith(salaryMin: v)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _moneyBox(
                    'sal-max',
                    _salMax,
                    'Maximum',
                    (v) => _c.update((x) => v == null ? x.copyWith(clearSalaryMax: true) : x.copyWith(salaryMax: v)),
                  ),
                ),
              ],
            ),
            _label('Currency'),
            _choices(
              keyPrefix: 'currency',
              options: [for (final c in jobCurrencies) (c, c)],
              value: d.salaryCurrency,
              onPick: (v) => _c.update((x) => x.copyWith(salaryCurrency: v)),
            ),
            _label('Paid'),
            _choices(
              keyPrefix: 'period',
              options: const [('YEARLY', 'Per year'), ('MONTHLY', 'Per month'), ('HOURLY', 'Per hour')],
              value: d.salaryPeriod,
              onPick: (v) => _c.update((x) => x.copyWith(salaryPeriod: v)),
            ),
            SwitchListTile(
              key: const ValueKey('salary-visible'),
              contentPadding: EdgeInsets.zero,
              title: Text('Show the salary on the posting', style: JobsText.formLabel),
              subtitle: Text('A posting with pay shown gets more applicants.', style: JobsText.formHelp),
              value: d.salaryVisible,
              onChanged: (v) => _c.update((x) => x.copyWith(salaryVisible: v)),
            ),
            SwitchListTile(
              key: const ValueKey('salary-negotiable'),
              contentPadding: EdgeInsets.zero,
              title: Text('Salary is negotiable', style: JobsText.formLabel),
              value: d.negotiable,
              onChanged: (v) => _c.update((x) => x.copyWith(negotiable: v)),
            ),
          ]),
          _card('apply', 'Applying', [
            if (d.cities.length < 2) ...[
              _label('Openings'),
              SizedBox(
                width: 120,
                child: _numberBox(
                  'openings',
                  _openings,
                  '1',
                  (v) => _c.update((x) => x.copyWith(openings: v ?? 1)),
                  min: 1,
                ),
              ),
            ],
            _label('How candidates apply'),
            _choices(
              keyPrefix: 'apply',
              options: const [('ICR', 'On ICR'), ('EXTERNAL', 'On your own site')],
              value: d.externalApply ? 'EXTERNAL' : 'ICR',
              onPick: (v) => _c.update((x) => x.copyWith(externalApply: v == 'EXTERNAL')),
            ),
            if (d.externalApply) ...[
              _label('Link where candidates apply'),
              TextField(
                key: const ValueKey('apply-url'),
                controller: _applyUrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                style: JobsText.formInput,
                decoration: _decoration(hint: 'https://careers.example.com/role'),
                onChanged: (v) => _c.update((x) => x.copyWith(applyUrl: v)),
              ),
            ],
            _label('Apply by (optional)'),
            Row(
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('apply-deadline'),
                  onPressed: () async {
                    final now = (widget.clock ?? DateTime.now)();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: d.applyDeadline ?? now.add(const Duration(days: 14)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 730)),
                    );
                    if (picked != null) {
                      _c.update((x) => x.copyWith(applyDeadline: DateTime(picked.year, picked.month, picked.day, 18)));
                    }
                  },
                  icon: const Icon(LucideIcons.calendar, size: 15),
                  label: Text(d.applyDeadline == null ? 'Pick a date' : formatDeadline(d.applyDeadline!)),
                ),
                if (d.applyDeadline != null)
                  IconButton(
                    key: const ValueKey('clear-deadline'),
                    tooltip: 'No deadline',
                    onPressed: () => _c.update((x) => x.copyWith(clearDeadline: true)),
                    icon: const Icon(LucideIcons.x, size: 16),
                  ),
              ],
            ),
            SwitchListTile(
              key: const ValueKey('require-resume'),
              contentPadding: EdgeInsets.zero,
              title: Text('Ask for a résumé', style: JobsText.formLabel),
              value: d.requireResume,
              onChanged: (v) => _c.update((x) => x.copyWith(requireResume: v)),
            ),
            SwitchListTile(
              key: const ValueKey('show-contact'),
              contentPadding: EdgeInsets.zero,
              title: Text('Show me as the contact', style: JobsText.formLabel),
              subtitle: Text('Candidates can message you from the posting.', style: JobsText.formHelp),
              value: d.showHiringContact,
              onChanged: (v) => _c.update((x) => x.copyWith(showHiringContact: v)),
            ),
          ]),
          _card('questions', 'Questions for applicants', [
            ScreeningEditor(
              questions: d.screening,
              onChanged: (list) => _c.update((x) => x.copyWith(screening: list), screening: true),
            ),
          ]),
          _checklist(),
        ],
      ),
    );
  }

  List<Widget> _notices() {
    final d = _c.draft;
    final gate = _c.publishBlockedReason;
    return [
      if (_c.editing)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              StatusPill(
                d.status.label,
                tone: switch (d.status) {
                  PostingStatus.open => PillTone.success,
                  PostingStatus.inReview => PillTone.brand,
                  PostingStatus.paused => PillTone.warning,
                  _ => PillTone.neutral,
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(switch (d.status) {
                  PostingStatus.open => 'This posting is live: changes show at once.',
                  PostingStatus.inReview => 'ICR is reviewing this posting.',
                  PostingStatus.paused => 'Paused. Publish to open it again.',
                  PostingStatus.closed => 'Closed. Publish to open it again.',
                  PostingStatus.draft => 'Draft. Publish it when it is ready.',
                }, style: CareerText.meta),
              ),
            ],
          ),
        ),
      if (gate != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: NoteStrip(
            key: const ValueKey('gate-note'),
            icon: LucideIcons.shieldAlert,
            color: AppColors.amber500,
            actions: [
              StripButton(label: 'Verify', onTap: () => widget.navigation.verifyCompany(context, widget.links)),
            ],
            child: Text(gate, style: CareerText.body.copyWith(color: AppColors.onSurface)),
          ),
        ),
    ];
  }

  Widget _card(String key, String title, List<Widget> children) {
    return Padding(
      key: _sections[key],
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: CareerText.heading.copyWith(fontSize: 14)),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(text, style: JobsText.formLabel),
  );

  InputDecoration _decoration({String? hint}) =>
      InputDecoration(hintText: hint, isDense: true, counterText: '', border: const OutlineInputBorder());

  List<Widget> _titleHints() {
    final hints = _c.titleSuggestions(_title.text);
    if (hints.isEmpty) return const [];
    return [
      Container(
        key: const ValueKey('title-suggestions'),
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            for (final (i, t) in hints.indexed) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.cardRule),
              InkWell(
                key: ValueKey('title-hint-$t'),
                onTap: () {
                  _title.text = t;
                  _title.selection = TextSelection.collapsed(offset: t.length);
                  _c.setTitle(t);
                  _titleFocus.unfocus();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.briefcaseBusiness, size: 14, color: AppColors.outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(t, style: CareerText.body.copyWith(color: AppColors.onSurface)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _choices({
    required String keyPrefix,
    required List<(String, String)> options,
    required String? value,
    required void Function(String? value) onPick,
    bool clearable = false,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (v, label) in options)
          ChoiceChip(
            key: ValueKey('$keyPrefix-$v'),
            label: Text(label),
            selected: value == v,
            onSelected: (_) => onPick(clearable && value == v ? null : v),
          ),
      ],
    );
  }

  Widget _numberBox(
    String key,
    TextEditingController c,
    String hint,
    void Function(int? value) onChanged, {
    int min = 0,
  }) {
    return TextField(
      key: ValueKey(key),
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
      style: JobsText.formInput,
      decoration: _decoration(hint: hint),
      onChanged: (v) {
        final n = _int(v);
        onChanged(n == null || n < min ? null : n);
      },
    );
  }

  Widget _moneyBox(String key, TextEditingController c, String hint, void Function(num? value) onChanged) {
    return TextField(
      key: ValueKey(key),
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
      style: JobsText.formInput,
      decoration: _decoration(hint: hint),
      onChanged: (v) => onChanged(_num(v)),
    );
  }

  Widget _skillInput({required bool preferred}) {
    final c = preferred ? _preferred : _skill;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: ValueKey(preferred ? 'preferred-input' : 'skill-input'),
                controller: c,
                style: JobsText.formInput,
                decoration: _decoration(hint: 'Add a skill'),
                textInputAction: TextInputAction.done,
                onChanged: preferred ? null : _hintSkills,
                onSubmitted: (v) => _addSkill(v, preferred: preferred),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              key: ValueKey(preferred ? 'add-preferred' : 'add-skill'),
              tooltip: 'Add skill',
              onPressed: () => _addSkill(c.text, preferred: preferred),
              icon: const Icon(LucideIcons.plus, size: 18),
            ),
          ],
        ),
        if (!preferred && _skillHints.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              key: const ValueKey('skill-hints'),
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in _skillHints)
                  ActionChip(key: ValueKey('skill-hint-$s'), label: Text(s), onPressed: () => _addSkill(s)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _skillChips(List<String> skills, {required bool preferred}) {
    if (skills.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final s in skills)
            InputChip(
              key: ValueKey('${preferred ? 'preferred' : 'skill'}-$s'),
              label: Text(s),
              onDeleted: () => _c.update(
                (x) => preferred
                    ? x.copyWith(preferredSkills: x.preferredSkills.where((e) => e != s).toList())
                    : x.copyWith(skills: x.skills.where((e) => e != s).toList()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _checklist() {
    final blockers = _c.blockers;
    return Padding(
      key: _sections['checklist'],
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(color: blockers.isEmpty ? AppColors.emerald50 : Colors.white),
        child: Column(
          key: const ValueKey('checklist'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              blockers.isEmpty ? 'Ready to publish' : 'Before you publish',
              style: CareerText.heading.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (blockers.isEmpty)
              Row(
                children: [
                  const Icon(LucideIcons.circleCheck, size: 18, color: AppColors.successInk),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Everything a posting needs to go live is here.', style: CareerText.body)),
                ],
              )
            else
              for (final b in blockers)
                InkWell(
                  key: ValueKey('blocker-${b.key}'),
                  onTap: () => _scrollTo(switch (b.key) {
                    'title' => 'basics',
                    'description' => 'description',
                    'skills' => 'skills',
                    'country' || 'cityOpenings' => 'location',
                    'salaryOrder' => 'pay',
                    'experienceOrder' => 'skills',
                    'applyUrl' || 'openings' => 'apply',
                    _ => 'basics',
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(LucideIcons.circleAlert, size: 16, color: AppColors.amber800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(b.message, style: CareerText.body.copyWith(color: AppColors.onSurface)),
                        ),
                        const Icon(LucideIcons.chevronRight, size: 14, color: AppColors.outline),
                      ],
                    ),
                  ),
                ),
            if (_problem != null) FormProblem(_problem!),
            if (_c.draft.status == PostingStatus.draft && blockers.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const ValueKey('send-review'),
                  onPressed: _c.saving ? null : () => _run(_c.submitForReview),
                  child: Text('Send to ICR for review instead', style: CareerText.link),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionBar() {
    final live = _c.live;
    final reopen = _c.draft.status == PostingStatus.paused || _c.draft.status == PostingStatus.closed;
    return BottomActionBar(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const ValueKey('save-draft'),
            onPressed: _c.saving ? null : () => _run(_c.save),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_c.editing && live ? 'Save changes' : 'Save draft'),
          ),
        ),
        Expanded(
          flex: 2,
          child: PrimaryButton(
            key: const ValueKey('publish'),
            label: _c.saving ? 'Working…' : (reopen ? 'Publish again' : (live ? 'Update posting' : 'Publish')),
            icon: LucideIcons.send,
            onPressed: _c.saving || (live && _c.draft.status == PostingStatus.inReview)
                ? null
                : () => _run(live ? _c.save : _c.publish),
          ),
        ),
      ],
    );
  }
}

/// "30 Nov 2026".
String formatDeadline(DateTime at) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${at.day} ${months[at.month - 1]} ${at.year}';
}
