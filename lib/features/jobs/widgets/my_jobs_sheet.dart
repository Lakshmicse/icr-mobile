import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/util/links.dart' show showMessage;
import '../../../core/util/time_ago.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/section_heading.dart';
import '../../career/career_routes.dart';
import '../../career/saved_jobs_controller.dart';
import '../employer/hiring_routes.dart';
import '../job_detail_sheet.dart';
import '../job_models.dart';
import '../jobs_controller.dart';
import '../jobs_styles.dart';
import 'job_row.dart';

/// Where the footer of "My jobs" leads.
enum MyJobsExit { applications, saved, hub, posted }

/// The "My jobs" chip: the member's applications and the jobs they saved, from
/// `GET /applications/mine` and `GET /jobs/saved`. A row opens the job; the footer
/// opens the whole tracker, the saved jobs or the career hub.
Future<void> showMyJobs(BuildContext context) async {
  final jobs = context.read<JobsController>();
  final picked = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.82),
    builder: (_) => ChangeNotifierProvider.value(value: jobs, child: const MyJobsSheet()),
  );
  if (!context.mounted) return;
  switch (picked) {
    case Job job:
      await showJobSheet(context, job);
    case MyJobsExit.applications:
      await careerRoutesOf(context).applications();
    case MyJobsExit.saved:
      await careerRoutesOf(context).savedJobs(tab: SavedTab.saved);
    case MyJobsExit.hub:
      await careerRoutesOf(context).hub();
    case MyJobsExit.posted:
      await hiringRoutesOf(context).jobs();
    default:
      return;
  }
  // What was done over there changes the chip's count.
  if (context.mounted) await context.read<JobsController>().refresh();
}

enum _MyTab { applied, saved }

class MyJobsSheet extends StatefulWidget {
  const MyJobsSheet({super.key});

  @override
  State<MyJobsSheet> createState() => _MyJobsSheetState();
}

class _MyJobsSheetState extends State<MyJobsSheet> {
  MyJobs? _data;
  String? _error;
  var _loading = true;
  var _tab = _MyTab.applied;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<JobsController>().loadMyJobs();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiError.from(e).message;
        _loading = false;
      });
    }
  }

  /// Flips the bookmark on every copy of the job this sheet holds.
  void _mark(String id, bool saved) {
    final data = _data;
    if (data == null) return;
    setState(() {
      _data = MyJobs(
        applications: [
          for (final a in data.applications)
            a.job.id == id
                ? JobApplication(
                    id: a.id,
                    job: a.job.copyWith(saved: saved),
                    stage: a.stage,
                    appliedAt: a.appliedAt,
                  )
                : a,
        ],
        saved: [for (final j in data.saved) j.id == id ? j.copyWith(saved: saved) : j],
      );
    });
  }

  Future<void> _save(Job job) async {
    _mark(job.id, !job.saved);
    final message = await context.read<JobsController>().toggleSave(job);
    if (message == null) return;
    _mark(job.id, job.saved);
    if (mounted) showMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final jobs = context.read<JobsController>();
    final data = _data;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('My jobs', style: JobsText.formTitle),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                IcrChip(
                  key: const ValueKey('my-jobs-applied'),
                  label: data == null ? 'Applied' : 'Applied (${data.applications.length})',
                  tone: _tab == _MyTab.applied ? ChipTone.primary : ChipTone.outlined,
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: JobsText.filterChip,
                  onTap: () => setState(() => _tab = _MyTab.applied),
                ),
                const SizedBox(width: 5),
                IcrChip(
                  key: const ValueKey('my-jobs-saved'),
                  label: data == null ? 'Saved' : 'Saved (${data.saved.length})',
                  tone: _tab == _MyTab.saved ? ChipTone.primary : ChipTone.outlined,
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: JobsText.filterChip,
                  onTap: () => setState(() => _tab = _MyTab.saved),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Hairline(color: AppColors.blockRule),
          Flexible(child: _body(jobs, data)),
          const Hairline(color: AppColors.outlineVariant),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  key: const ValueKey('my-jobs-see-all'),
                  onTap: () =>
                      Navigator.pop(context, _tab == _MyTab.applied ? MyJobsExit.applications : MyJobsExit.saved),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _tab == _MyTab.applied ? 'See all applications' : 'See all saved jobs',
                          style: JobsText.insights,
                        ),
                        const SizedBox(width: 3),
                        const Icon(LucideIcons.chevronRight, size: 12, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24, child: VerticalDivider(width: 1, color: AppColors.outlineVariant)),
              Expanded(
                child: InkWell(
                  key: const ValueKey('my-jobs-hub'),
                  onTap: () => Navigator.pop(context, MyJobsExit.hub),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Your career hub', style: JobsText.insights),
                        const SizedBox(width: 3),
                        const Icon(LucideIcons.chevronRight, size: 12, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (jobs.canHire) ...[
            const Hairline(color: AppColors.outlineVariant),
            InkWell(
              key: const ValueKey('my-jobs-posted'),
              onTap: () => Navigator.pop(context, MyJobsExit.posted),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Jobs you posted', style: JobsText.insights),
                    const SizedBox(width: 3),
                    const Icon(LucideIcons.chevronRight, size: 12, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _body(JobsController jobs, MyJobs? data) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2))),
      );
    }
    if (_error != null || data == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? "Couldn't load your jobs.", textAlign: TextAlign.center, style: AppText.small),
            TextButton(
              onPressed: _load,
              child: Text('Try again', style: AppText.link),
            ),
          ],
        ),
      );
    }
    final applied = _tab == _MyTab.applied;
    final rows = applied ? data.applications.length : data.saved.length;
    if (rows == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        child: Text(
          applied ? "You haven't applied to a job yet." : 'Jobs you bookmark show up here.',
          textAlign: TextAlign.center,
          style: AppText.small,
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: rows,
      separatorBuilder: (_, _) => const Hairline(indent: 10, endIndent: 10.5),
      itemBuilder: (context, i) {
        if (applied) {
          final a = data.applications[i];
          final when = a.appliedAt == null ? null : 'Applied ${timeAgo(a.appliedAt!)}';
          return JobRow(
            key: ValueKey('applied-${a.id}'),
            job: a.job,
            caption: [a.stageLabel, ?when].join(' • '),
            onTap: () => Navigator.pop(context, a.job),
            onSave: () => _save(a.job),
          );
        }
        final job = data.saved[i];
        return JobRow(
          key: ValueKey('saved-${job.id}'),
          job: job,
          onTap: () => Navigator.pop(context, job),
          onSave: () => _save(job),
        );
      },
    );
  }
}
