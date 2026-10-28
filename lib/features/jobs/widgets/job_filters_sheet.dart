import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../career/career_routes.dart';
import '../../career/job_alert_models.dart';
import '../job_models.dart';
import '../jobs_controller.dart';
import '../jobs_styles.dart';

/// The label on the "Date posted" chip: what it is set to, or its name.
String postedLabel(int? days) => switch (days) {
  null => 'Date posted',
  1 => 'Past 24 hours',
  7 => 'Past week',
  30 => 'Past month',
  _ => 'Past $days days',
};

/// The choices of the "Date posted" menu, as days (0 is "any time").
const postedChoices = [(0, 'Any time'), (1, 'Past 24 hours'), (7, 'Past week'), (30, 'Past month')];

/// The "Date posted" menu: sets `postedWithinDays` on the board's search.
Future<void> pickPosted(BuildContext context) async {
  final jobs = context.read<JobsController>();
  final choice = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (days, label) in postedChoices)
            ListTile(
              key: ValueKey('posted-$days'),
              title: Text(label, style: AppText.small.copyWith(color: AppColors.onSurface, fontSize: 14)),
              trailing: (jobs.filters.postedWithinDays ?? 0) == days
                  ? const Icon(LucideIcons.check, size: 18, color: AppColors.primary)
                  : null,
              onTap: () => Navigator.pop(sheet, days),
            ),
        ],
      ),
    ),
  );
  if (choice != null) await jobs.setPostedWithin(choice == 0 ? null : choice);
}

/// The member asked to keep these filters as a job alert.
class SaveFiltersAsAlert {
  const SaveFiltersAsAlert(this.filters);

  final JobFilters filters;
}

/// The search the board is showing as a saved search's criteria.
AlertCriteria criteriaOfFilters(JobFilters f) => AlertCriteria(
  search: f.search,
  cities: f.hasCity ? [f.city!] : const [],
  workModes: f.workModes,
  employmentTypes: f.employmentTypes,
  postedWithinDays: f.postedWithinDays,
);

/// The Filters sheet: work mode, employment type, city, and "Save as a job alert".
Future<void> showJobFilters(BuildContext context) async {
  final jobs = context.read<JobsController>();
  final result = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheet) => JobFiltersSheet(initial: jobs.filters),
  );
  if (result is JobFilters) {
    await jobs.setFilters(result);
  } else if (result is SaveFiltersAsAlert && context.mounted) {
    // The alert keeps the search as it is now; the board follows it too.
    await jobs.setFilters(result.filters);
    if (context.mounted) {
      await careerRoutesOf(context).alerts(create: true, criteria: criteriaOfFilters(result.filters));
    }
  }
}

class JobFiltersSheet extends StatefulWidget {
  const JobFiltersSheet({super.key, required this.initial});

  final JobFilters initial;

  @override
  State<JobFiltersSheet> createState() => _JobFiltersSheetState();
}

class _JobFiltersSheetState extends State<JobFiltersSheet> {
  late var _filters = widget.initial;
  late final _city = TextEditingController(text: widget.initial.city ?? '');

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  JobFilters _withCity() => _filters.copyWith(city: _city.text.trim(), clearCity: _city.text.trim().isEmpty);

  @override
  Widget build(BuildContext context) {
    final labelStyle = AppText.small.copyWith(color: AppColors.onSurface, fontSize: 14);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Filters', style: JobsText.formTitle),
              const SizedBox(height: 12),
              Text('Work mode', style: JobsText.formLabel),
              Wrap(
                spacing: 8,
                children: [
                  for (final mode in WorkMode.values)
                    FilterChip(
                      label: Text(mode.label),
                      selected: _filters.workModes.contains(mode),
                      onSelected: (on) => setState(() {
                        final set = {..._filters.workModes};
                        on ? set.add(mode) : set.remove(mode);
                        _filters = _filters.copyWith(workModes: set);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Employment type', style: JobsText.formLabel),
              Wrap(
                spacing: 8,
                children: [
                  for (final type in EmploymentType.values.take(5))
                    FilterChip(
                      label: Text(type.label),
                      selected: _filters.employmentTypes.contains(type),
                      onSelected: (on) => setState(() {
                        final set = {..._filters.employmentTypes};
                        on ? set.add(type) : set.remove(type);
                        _filters = _filters.copyWith(employmentTypes: set);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('City', style: JobsText.formLabel),
              const SizedBox(height: 4),
              TextField(
                controller: _city,
                style: JobsText.formInput,
                decoration: const InputDecoration(hintText: 'Any city', isDense: true, border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('save-as-alert'),
                  onPressed: () => Navigator.pop(context, SaveFiltersAsAlert(_withCity())),
                  icon: const Icon(LucideIcons.bellPlus, size: 16),
                  label: Text('Save this search as a job alert', style: labelStyle.copyWith(color: AppColors.primary)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(context, JobFilters(search: _filters.search, easyApply: _filters.easyApply)),
                    child: Text('Clear all', style: labelStyle.copyWith(color: AppColors.primary)),
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary, shape: const StadiumBorder()),
                    onPressed: () => Navigator.pop(context, _withCity()),
                    child: const Text('Show jobs'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
