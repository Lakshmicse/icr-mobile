import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/chips.dart';
import '../site/site_kit.dart';
import 'talent_labels.dart';
import 'talent_models.dart';

/// What the Filters sheet hands back: the facets to apply, or "Clear all".
sealed class FilterSheetResult {
  const FilterSheetResult();
}

class ApplyFilters extends FilterSheetResult {
  const ApplyFilters(this.filters);

  final TalentFilters filters;
}

class ClearAllFilters extends FilterSheetResult {
  const ClearAllFilters();
}

/// The website's filter rail (`TalentFilterRail`) as a sheet: Role & skills, Location, What they want, Experience,
/// Availability & pay, Activity — every label, helper and option word the rail's. Text facets are read when the
/// sheet is applied; chips and ticks are held in the sheet until then. Null when dismissed.
Future<FilterSheetResult?> showTalentFilters(
  BuildContext context, {
  required TalentFilters initial,
  required TalentMasters masters,
  List<JobOption> jobs = const [],
}) {
  return showModalBottomSheet<FilterSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheet) => TalentFilterSheet(initial: initial, masters: masters, jobs: jobs),
  );
}

class TalentFilterSheet extends StatefulWidget {
  const TalentFilterSheet({super.key, required this.initial, required this.masters, this.jobs = const []});

  final TalentFilters initial;
  final TalentMasters masters;

  /// The company's jobs: "Scope exclusions to a job" (hidden while matching, which is already to one job).
  final List<JobOption> jobs;

  @override
  State<TalentFilterSheet> createState() => _TalentFilterSheetState();
}

class _TalentFilterSheetState extends State<TalentFilterSheet> {
  late TalentFilters _f = widget.initial;
  late final _titles = TextEditingController(text: widget.initial.titles.join(', '));
  late final _skills = TextEditingController(text: widget.initial.skills.join(', '));
  late final _company = TextEditingController(text: widget.initial.currentCompany ?? '');
  late final _locations = TextEditingController(text: widget.initial.locations.join(', '));
  late final _minYears = TextEditingController(text: _num(widget.initial.minYears));
  late final _maxYears = TextEditingController(text: _num(widget.initial.maxYears));
  late final _salary = TextEditingController(text: _num(widget.initial.expectedSalaryMax));

  static String _num(num? v) => v == null ? '' : (v is int || v == v.roundToDouble() ? '${v.round()}' : '$v');

  @override
  void dispose() {
    for (final c in [_titles, _skills, _company, _locations, _minYears, _maxYears, _salary]) {
      c.dispose();
    }
    super.dispose();
  }

  static List<String> _csv(String raw) => raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  static int? _int(String raw) => int.tryParse(raw.trim());

  /// The facets as the sheet shows them: the chips and ticks held in [_f], the text boxes read now.
  TalentFilters _collect() {
    final salary = num.tryParse(_salary.text.trim().replaceAll(',', ''));
    return _f.copyWith(
      titles: _csv(_titles.text),
      skills: _csv(_skills.text),
      currentCompany: _company.text.trim().isEmpty ? null : _company.text.trim(),
      locations: _csv(_locations.text),
      minYears: _int(_minYears.text),
      maxYears: _int(_maxYears.text),
      expectedSalaryMax: salary,
    );
  }

  void _set(TalentFilters next) => setState(() => _f = next);

  @override
  Widget build(BuildContext context) {
    final m = widget.masters;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.92,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
              child: Row(
                children: [
                  Expanded(child: Text('Filters', style: SiteText.heading)),
                  TextButton(
                    key: const ValueKey('filters-clear'),
                    onPressed: () => Navigator.pop(context, const ClearAllFilters()),
                    child: Text('Clear All', style: SiteText.link),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
            Expanded(
              child: ListView(
                key: const ValueKey('filters-list'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  _Section(
                    title: 'Role & Skills',
                    children: [
                      _TextFacet(
                        key: const ValueKey('filter-titles'),
                        controller: _titles,
                        label: 'Job Titles',
                        hint: 'Facility Manager, Analyst',
                        help: 'Matches their headline or desired roles.',
                      ),
                      _TextFacet(
                        key: const ValueKey('filter-skills'),
                        controller: _skills,
                        label: 'Skills',
                        hint: 'FM, Lease admin',
                      ),
                      _TextFacet(
                        key: const ValueKey('filter-company'),
                        controller: _company,
                        label: 'Current Employer',
                        hint: 'CBRE',
                      ),
                    ],
                  ),
                  _Section(
                    title: 'Location',
                    children: [
                      _TextFacet(
                        key: const ValueKey('filter-locations'),
                        controller: _locations,
                        label: 'Locations',
                        hint: 'Mumbai, Pune',
                        help: 'Their current or preferred location.',
                      ),
                      _Label('Work Mode'),
                      _Choices(
                        keyPrefix: 'wm',
                        options: [for (final e in workModeLabels.entries) (e.key, e.value)],
                        value: _f.desiredWorkMode,
                        onPick: (v) => _set(_f.copyWith(desiredWorkMode: v)),
                      ),
                      _Tick(
                        key: const ValueKey('filter-reloc'),
                        label: 'Open to Relocating',
                        value: _f.willingToRelocate,
                        onChanged: (v) => _set(_f.copyWith(willingToRelocate: v)),
                      ),
                    ],
                  ),
                  _Section(
                    title: 'What They Want',
                    children: [
                      _Label('Job Types'),
                      _MultiChoices(
                        keyPrefix: 'et',
                        options: [for (final e in employmentTypeLabels.entries) (e.key, e.value)],
                        values: _f.employmentTypes,
                        onChanged: (v) => _set(_f.copyWith(employmentTypes: v)),
                      ),
                      _Label('Industries'),
                      _MultiChoices(
                        keyPrefix: 'ind',
                        options: [for (final o in m.industries) (o.key, o.label)],
                        values: _f.industries,
                        onChanged: (v) => _set(_f.copyWith(industries: v)),
                      ),
                      _Label('Job Functions'),
                      _MultiChoices(
                        keyPrefix: 'fn',
                        options: [for (final o in m.functions) (o.key, o.label)],
                        values: _f.functions,
                        onChanged: (v) => _set(_f.copyWith(functions: v)),
                      ),
                      _Label('Shift', help: 'Includes anyone open to flexible shifts.'),
                      _Choices(
                        keyPrefix: 'shift',
                        options: [
                          for (final e in shiftLabels.entries)
                            if (e.key != 'FLEXIBLE') (e.key, e.value),
                        ],
                        value: _f.shift,
                        onPick: (v) => _set(_f.copyWith(shift: v)),
                      ),
                    ],
                  ),
                  _Section(
                    title: 'Experience',
                    children: [
                      _Label('Seniority', help: 'Derived from years of experience.'),
                      _Choices(
                        keyPrefix: 'sen',
                        options: [for (final e in seniorityLabels.entries) (e.key, e.value)],
                        value: _f.seniority,
                        onPick: (v) => _set(_f.copyWith(seniority: v)),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _TextFacet(
                              key: const ValueKey('filter-min-years'),
                              controller: _minYears,
                              label: 'Min Years',
                              number: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _TextFacet(
                              key: const ValueKey('filter-max-years'),
                              controller: _maxYears,
                              label: 'Max Years',
                              number: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _Section(
                    title: 'Availability & Pay',
                    children: [
                      _Tick(
                        key: const ValueKey('filter-next-role'),
                        label: 'Ready for Their Next Role',
                        value: _f.nextRole,
                        onChanged: (v) => _set(_f.copyWith(nextRole: v)),
                      ),
                      _Label('Notice Period'),
                      _Choices(
                        keyPrefix: 'notice',
                        options: [for (final (d, l) in noticeFilterOptions) ('$d', l)],
                        value: _f.noticePeriodMaxDays?.toString(),
                        onPick: (v) => _set(_f.copyWith(noticePeriodMaxDays: v == null ? null : int.parse(v))),
                      ),
                      _TextFacet(
                        key: const ValueKey('filter-salary'),
                        controller: _salary,
                        label: 'Expected Salary Up To',
                        hint: '1500000',
                        help: 'Their expected salary, per year.',
                        number: true,
                      ),
                      Text(
                        'Narrows the list by what candidates expect. A card shows the figure only when the candidate '
                        'allows it.',
                        style: SiteText.meta,
                      ),
                    ],
                  ),
                  _Section(
                    title: 'Activity',
                    last: true,
                    children: [
                      _Label('Profile Updated'),
                      _Choices(
                        keyPrefix: 'recency',
                        options: [for (final (d, l) in recencyFilterOptions) ('$d', l)],
                        value: _f.updatedWithinDays?.toString(),
                        anyLabel: 'Any Time',
                        onPick: (v) => _set(_f.copyWith(updatedWithinDays: v == null ? null : int.parse(v))),
                      ),
                      _Tick(
                        key: const ValueKey('filter-hide-viewed'),
                        label: 'Hide Viewed Profiles',
                        value: _f.hideViewed,
                        onChanged: (v) => _set(_f.copyWith(hideViewed: v)),
                      ),
                      _Tick(
                        key: const ValueKey('filter-hide-past'),
                        label: 'Hide Past Applicants',
                        value: _f.hidePastApplicants,
                        onChanged: (v) => _set(_f.copyWith(hidePastApplicants: v)),
                      ),
                      if (widget.jobs.isNotEmpty) ...[
                        _Label('Scope Exclusions to a Job', help: 'Also hides anyone already invited to it.'),
                        _Choices(
                          keyPrefix: 'scope-job',
                          options: [for (final j in widget.jobs) (j.id, j.title)],
                          value: _f.jobId,
                          anyLabel: 'All My Jobs',
                          onPick: (v) => _set(_f.copyWith(jobId: v)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: SiteButton(
                key: const ValueKey('filters-apply'),
                label: 'Show Candidates',
                onPressed: () => Navigator.pop(context, ApplyFilters(_collect())),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.last = false});

  final String title;
  final List<Widget> children;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Text(title.toUpperCase(), style: SiteText.meta.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        for (final child in children) ...[child, const SizedBox(height: 10)],
        if (!last) const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.help});

  final String text;
  final String? help;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: SiteText.strong),
        if (help != null) Text(help!, style: SiteText.meta),
      ],
    );
  }
}

/// A text facet: label over an underlined field, with the rail's hint and helper.
class _TextFacet extends StatelessWidget {
  const _TextFacet({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.help,
    this.number = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? help;
  final bool number;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: SiteText.strong),
        TextField(
          controller: controller,
          style: SiteText.body,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: SiteText.secondary,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: const UnderlineInputBorder(borderSide: BorderSide(color: SiteColors.hairline)),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: SiteColors.hairline)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
          ),
        ),
        if (help != null) ...[const SizedBox(height: 4), Text(help!, style: SiteText.meta)],
      ],
    );
  }
}

/// One of several, or "Any" (the rail's selects).
class _Choices extends StatelessWidget {
  const _Choices({
    required this.keyPrefix,
    required this.options,
    required this.value,
    required this.onPick,
    this.anyLabel = 'Any',
  });

  final String keyPrefix;
  final List<(String, String)> options;
  final String? value;
  final String anyLabel;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _OptionChip(key: ValueKey('$keyPrefix-any'), label: anyLabel, on: value == null, onTap: () => onPick(null)),
        for (final (key, label) in options)
          _OptionChip(
            key: ValueKey('$keyPrefix-$key'),
            label: label,
            on: value == key,
            onTap: () => onPick(value == key ? null : key),
          ),
      ],
    );
  }
}

/// Any number of several (the rail's multi-selects).
class _MultiChoices extends StatelessWidget {
  const _MultiChoices({required this.keyPrefix, required this.options, required this.values, required this.onChanged});

  final String keyPrefix;
  final List<(String, String)> options;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (key, label) in options)
          _OptionChip(
            key: ValueKey('$keyPrefix-$key'),
            label: label,
            on: values.contains(key),
            onTap: () => onChanged(
              values.contains(key)
                  ? [
                      for (final v in values)
                        if (v != key) v,
                    ]
                  : [...values, key],
            ),
          ),
      ],
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({super.key, required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IcrChip(
      label: label,
      tone: on ? ChipTone.primary : ChipTone.outlined,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      textStyle: SiteText.body.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
      onTap: onTap,
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (v) => onChanged(v ?? false),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: SiteText.body)),
        ],
      ),
    );
  }
}
