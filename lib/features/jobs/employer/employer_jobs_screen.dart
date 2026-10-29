import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/config.dart';
import '../../../core/util/links.dart' show showMessage;
import '../../career/career_format.dart';
import '../../career/career_styles.dart';
import '../../career/career_widgets.dart';
import '../job_links.dart';
import '../jobs_navigation.dart';
import 'applicants_screen.dart';
import 'employer_jobs_controller.dart';
import 'hiring_models.dart';
import 'hiring_repository.dart';
import 'post_job_screen.dart';

/// "Jobs you posted": the company's postings by status, each with its pipeline at a glance and the
/// ways to run it (applicants, edit, pause, close, duplicate, delete). The website's `/manage/jobs`.
/// Only for the hiring team: a member without the role is told so, not shown it.
class EmployerJobsScreen extends StatefulWidget {
  const EmployerJobsScreen({
    super.key,
    required this.repository,
    this.links = const SystemJobLinks(),
    this.navigation = JobsNavigation.none,
    this.status,
    this.onBack,
    this.clock,
  });

  final HiringRepository repository;
  final JobLinks links;
  final JobsNavigation navigation;

  /// The tab it opens on; null is All.
  final PostingStatus? status;
  final VoidCallback? onBack;
  final DateTime Function()? clock;

  @override
  State<EmployerJobsScreen> createState() => _EmployerJobsScreenState();
}

class _EmployerJobsScreenState extends State<EmployerJobsScreen> {
  late final EmployerJobsController _c = EmployerJobsController(
    widget.repository,
    status: widget.status,
    clock: widget.clock,
  );
  final _search = TextEditingController();

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _c.start();
  }

  @override
  void dispose() {
    _search.dispose();
    _c.dispose();
    super.dispose();
  }

  Future<void> _post({String? editId, JobDraft? initial}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PostJobScreen(
          repository: widget.repository,
          jobId: editId,
          initial: initial,
          links: widget.links,
          navigation: widget.navigation,
          clock: widget.clock,
        ),
      ),
    );
    if (mounted) _c.refresh();
  }

  Future<void> _applicants(PostedJob job) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ApplicantsScreen(
          repository: widget.repository,
          jobId: job.id,
          jobTitle: job.title,
          links: widget.links,
          navigation: widget.navigation,
          clock: widget.clock,
        ),
      ),
    );
    if (mounted) _c.refresh();
  }

  /// A promotion is bought: the website takes the payment (its list has a Promote on each live posting), so this
  /// leaves the app for it rather than opening the app's own jobs list again.
  Future<void> _promote(PostedJob job) => widget.links.openExternal(context, AppConfig.sitePage('/manage/jobs'));

  Future<void> _move(PostedJob job, PostingStatus to) async {
    if (to == PostingStatus.closed) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          key: const ValueKey('close-dialog'),
          title: Text('Close “${job.title}”?'),
          content: const Text('It stops taking applications and leaves the job board. You can reopen it later.'),
          actions: [
            TextButton(
              key: const ValueKey('close-keep'),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep open'),
            ),
            TextButton(
              key: const ValueKey('close-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Close job'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final message = await _c.move(job, to);
    if (!mounted) return;
    showMessage(
      context,
      message ??
          switch (to) {
            PostingStatus.paused => '“${job.title}” is paused.',
            PostingStatus.closed => '“${job.title}” is closed.',
            _ => '“${job.title}” is open again.',
          },
    );
  }

  Future<void> _delete(PostedJob job) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        key: const ValueKey('delete-dialog'),
        title: Text('Delete “${job.title}”?'),
        content: const Text(
          'It leaves your list and the job board. Applications already sent are kept for your records.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('delete-keep'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            key: const ValueKey('delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final message = await _c.delete(job);
    if (!mounted) return;
    showMessage(context, message ?? '“${job.title}” was deleted.');
  }

  Future<void> _duplicate(PostedJob job) async {
    final copy = await _c.duplicate(job);
    if (!mounted) return;
    if (copy.error != null) {
      showMessage(context, copy.error!);
      return;
    }
    showMessage(context, 'A draft copy of “${job.title}” was made.');
    if (copy.id != null) await _post(editId: copy.id);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => CareerScaffold(
        title: 'Jobs you posted',
        onBack: widget.onBack,
        unread: _c.unread,
        onBell: () => widget.navigation.openNotifications(context, widget.links),
        actions: [
          IconButton(
            key: const ValueKey('post-job'),
            tooltip: 'Post a job',
            onPressed: () => _post(),
            icon: const Icon(LucideIcons.circlePlus, size: 22, color: AppColors.primary),
          ),
        ],
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _c.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            children: _children(),
          ),
        ),
      ),
    );
  }

  List<Widget> _children() {
    final access = _c.access;
    if (access != null && !access.canManage) {
      return [
        CareerNotice(
          key: const ValueKey('no-role'),
          icon: LucideIcons.lock,
          title: 'Posting jobs is for hiring teams',
          body:
              'Your account does not post jobs for a company. Ask your company\'s admin to make you a recruiter, or set up a company.',
          action: 'Set up a company',
          onAction: () => widget.navigation.createCompany(context, widget.links),
        ),
      ];
    }
    if (_c.error != null && !_c.loaded) {
      return [
        CareerNotice(
          key: const ValueKey('jobs-error'),
          icon: LucideIcons.cloudOff,
          title: "Couldn't load your jobs",
          body: _c.error!,
          action: 'Try again',
          onAction: _c.refresh,
        ),
      ];
    }
    if (!_c.loaded) return const [CareerLoading()];
    if (_c.noJobsAtAll) {
      return [
        CareerNotice(
          key: const ValueKey('first-job'),
          icon: LucideIcons.briefcaseBusiness,
          title: 'Post your first job',
          body: 'Describe the role, add a few questions, and it goes live once your company is verified.',
          action: 'Post a job',
          onAction: () => _post(),
        ),
      ];
    }
    final overview = _c.overview;
    return [
      if (overview != null) ...[const SizedBox(height: 12), _Figures(overview: overview, onTab: _c.selectTab)],
      if (overview != null && overview.attention.isNotEmpty) ...[
        const SizedBox(height: 10),
        for (final item in overview.attention.take(3))
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            child: NoteStrip(
              key: ValueKey('attention-${item.jobId}'),
              icon: LucideIcons.triangleAlert,
              color: AppColors.amber500,
              actions: [
                StripButton(
                  label: 'Open',
                  onTap: () {
                    final job = _c.jobs.where((j) => j.id == item.jobId);
                    if (job.isNotEmpty) _applicants(job.first);
                  },
                ),
              ],
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${item.title}: ', style: CareerText.bodyStrong),
                    TextSpan(text: item.words, style: CareerText.body),
                  ],
                ),
              ),
            ),
          ),
      ],
      const SizedBox(height: 10),
      SizedBox(
        height: 30,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          children: [
            for (final s in [null, ...PostingStatus.values])
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: _TabChip(
                  key: ValueKey('jobs-tab-${s?.name ?? 'all'}'),
                  label: '${s == null ? 'All' : _tabLabel(s)} ${_c.count(s)}',
                  selected: _c.status == s,
                  onTap: () => _c.selectTab(s),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 9),
                    const Icon(LucideIcons.search, size: 16, color: AppColors.outline),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        key: const ValueKey('jobs-search'),
                        controller: _search,
                        style: CareerText.body.copyWith(color: AppColors.onSurface),
                        textAlignVertical: TextAlignVertical.center,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _c.setSearch,
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: 'Search your jobs',
                          hintStyle: CareerText.body.copyWith(color: AppColors.outline),
                        ),
                      ),
                    ),
                    if (_c.search.isNotEmpty)
                      IconButton(
                        key: const ValueKey('jobs-search-clear'),
                        tooltip: 'Clear search',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                        iconSize: 15,
                        onPressed: () {
                          _search.clear();
                          _c.setSearch('');
                        },
                        icon: const Icon(LucideIcons.x, color: AppColors.outline),
                      )
                    else
                      const SizedBox(width: 10),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<JobsSort>(
              key: const ValueKey('jobs-sort'),
              tooltip: 'Sort by',
              onSelected: _c.setSort,
              itemBuilder: (_) => [
                for (final s in JobsSort.values)
                  CheckedPopupMenuItem(value: s, checked: s == _c.sort, child: Text(s.label)),
              ],
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.arrowDownUp, size: 14),
                    const SizedBox(width: 5),
                    Text(_c.sort.label, style: CareerText.tabLabel),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FilterChip(
            key: const ValueKey('jobs-mine'),
            label: const Text('Only jobs I started'),
            selected: _c.mine,
            onSelected: _c.setMine,
          ),
        ),
      ),
      const SizedBox(height: 4),
      const Divider(height: 1, color: AppColors.blockRule),
      if (_c.loading && _c.jobs.isEmpty)
        const CareerLoading()
      else if (_c.error != null && _c.jobs.isEmpty)
        CareerNotice(
          key: const ValueKey('jobs-error'),
          icon: LucideIcons.cloudOff,
          title: "Couldn't load your jobs",
          body: _c.error!,
          action: 'Try again',
          onAction: _c.refresh,
        )
      else if (_c.jobs.isEmpty)
        CareerNotice(
          key: const ValueKey('jobs-empty'),
          icon: LucideIcons.briefcaseBusiness,
          title: _c.search.isNotEmpty || _c.mine ? 'No jobs match' : 'No jobs here',
          body: _c.search.isNotEmpty || _c.mine
              ? 'Try other words, or clear the filters.'
              : 'Postings in this status show up here.',
          action: _c.search.isNotEmpty || _c.mine || _c.status != null ? 'Clear filters' : null,
          onAction: () {
            _search.clear();
            _c.setMine(false);
            _c.setSearch('');
            _c.selectTab(null);
          },
        )
      else
        for (final job in _c.jobs)
          _JobCard(
            job: job,
            now: _now,
            busy: _c.busy(job.id),
            onApplicants: () => _applicants(job),
            onEdit: () => _post(editId: job.id),
            onMove: (to) => _move(job, to),
            onDuplicate: () => _duplicate(job),
            onDelete: () => _delete(job),
            onPromote: () => _promote(job),
          ),
      if (_c.hasMore) ViewMoreRow(loading: _c.loadingMore, onTap: _c.loadMore),
    ];
  }

  static String _tabLabel(PostingStatus s) => switch (s) {
    PostingStatus.draft => 'Drafts',
    _ => s.label,
  };
}

class _TabChip extends StatelessWidget {
  const _TabChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.primary : AppColors.outlineVariant)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Center(
            child: Text(label, style: CareerText.tabLabel.copyWith(color: selected ? Colors.white : null)),
          ),
        ),
      ),
    );
  }
}

/// The figures across every posting; Open and the interview count open their tab.
class _Figures extends StatelessWidget {
  const _Figures({required this.overview, required this.onTab});

  final HiringOverview overview;
  final ValueChanged<PostingStatus?> onTab;

  @override
  Widget build(BuildContext context) {
    Widget tile(String key, String label, int n, String hint, {VoidCallback? onTap}) => Expanded(
      child: InkWell(
        key: ValueKey(key),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: CareerText.label.copyWith(fontSize: 12)),
              Text('$n', style: CareerText.bigNumber.copyWith(fontSize: 22, height: 1.2)),
              Text(hint, style: CareerText.meta.copyWith(fontSize: 12), maxLines: 2),
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DecoratedBox(
        key: const ValueKey('figures'),
        decoration: cardDecoration(),
        child: Row(
          children: [
            tile(
              'figure-open',
              'Open',
              overview.open,
              overview.closingSoon == 0 ? 'None closing soon' : '${overview.closingSoon} closing soon',
              onTap: () => onTab(PostingStatus.open),
            ),
            tile('figure-unviewed', 'Not viewed', overview.unviewed, 'Applicants nobody opened'),
            tile(
              'figure-interviewing',
              'Interviewing',
              overview.interviewing,
              overview.interviewingJobs == 0
                  ? 'No rounds on'
                  : 'across ${overview.interviewingJobs} ${overview.interviewingJobs == 1 ? 'job' : 'jobs'}',
            ),
            tile('figure-hired', 'Hired', overview.hired, 'From these jobs'),
          ],
        ),
      ),
    );
  }
}

enum _JobAction { edit, promote, pause, resume, close, reopen, duplicate, delete }

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.now,
    required this.busy,
    required this.onApplicants,
    required this.onEdit,
    required this.onMove,
    required this.onDuplicate,
    required this.onDelete,
    required this.onPromote,
  });

  final PostedJob job;
  final DateTime now;
  final bool busy;
  final VoidCallback onApplicants;
  final VoidCallback onEdit;
  final void Function(PostingStatus to) onMove;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onPromote;

  /// "Closes in 2 days" for a live posting with a deadline close by; the date beyond a week.
  static String? deadlineWords(DateTime? deadline, DateTime now) {
    if (deadline == null) return null;
    final days = DateTime(
      deadline.year,
      deadline.month,
      deadline.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days < 0) return 'Deadline passed ${formatDay(deadline, now: now)}';
    if (days == 0) return 'Closes today';
    if (days <= 7) return 'Closes in $days ${days == 1 ? 'day' : 'days'}';
    return 'Closes ${formatDay(deadline, now: now)}';
  }

  @override
  Widget build(BuildContext context) {
    final pipeline = job.pipeline;
    final live =
        job.status == PostingStatus.open || job.status == PostingStatus.paused || job.status == PostingStatus.closed;
    final deadline = job.status == PostingStatus.open ? deadlineWords(job.applyDeadline, now) : null;
    final tone = switch (job.status) {
      PostingStatus.open => PillTone.success,
      PostingStatus.inReview => PillTone.brand,
      PostingStatus.paused => PillTone.warning,
      PostingStatus.closed => PillTone.neutral,
      PostingStatus.draft => PillTone.neutral,
    };
    return Container(
      key: ValueKey('job-${job.id}'),
      padding: const EdgeInsets.fromLTRB(10, 12, 4, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.cardRule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: live || job.status == PostingStatus.inReview ? onApplicants : onEdit,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: CareerText.cardTitle.copyWith(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (job.place.isNotEmpty) job.place,
                          ?job.workMode?.label,
                          if (job.postedBy != null && job.postedBy!.isNotEmpty) 'by ${job.postedBy}',
                        ].join(' • '),
                        style: CareerText.companyMeta,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          KeyedSubtree(
                            key: const ValueKey('job-status'),
                            child: StatusPill(job.status.label, tone: tone),
                          ),
                          if (job.promoted) const StatusPill('Promoted', tone: PillTone.brand, icon: LucideIcons.zap),
                          if (deadline != null)
                            StatusPill(
                              deadline,
                              tone: deadline.startsWith('Closes in') || deadline == 'Closes today'
                                  ? PillTone.warning
                                  : PillTone.neutral,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                PopupMenuButton<_JobAction>(
                  key: ValueKey('job-menu-${job.id}'),
                  tooltip: 'More for ${job.title}',
                  icon: const Icon(LucideIcons.ellipsisVertical, size: 18, color: AppColors.onSurfaceVariant),
                  onSelected: (a) => switch (a) {
                    _JobAction.edit => onEdit(),
                    _JobAction.promote => onPromote(),
                    _JobAction.pause => onMove(PostingStatus.paused),
                    _JobAction.resume || _JobAction.reopen => onMove(PostingStatus.open),
                    _JobAction.close => onMove(PostingStatus.closed),
                    _JobAction.duplicate => onDuplicate(),
                    _JobAction.delete => onDelete(),
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: _JobAction.edit, child: Text('Edit job')),
                    if (job.status == PostingStatus.open && !job.promoted)
                      const PopupMenuItem(value: _JobAction.promote, child: Text('Promote')),
                    if (job.status == PostingStatus.open)
                      const PopupMenuItem(value: _JobAction.pause, child: Text('Pause')),
                    if (job.status == PostingStatus.paused)
                      const PopupMenuItem(value: _JobAction.resume, child: Text('Resume')),
                    if (job.status == PostingStatus.open || job.status == PostingStatus.paused)
                      const PopupMenuItem(value: _JobAction.close, child: Text('Close')),
                    if (job.status == PostingStatus.closed)
                      const PopupMenuItem(value: _JobAction.reopen, child: Text('Reopen')),
                    const PopupMenuItem(value: _JobAction.duplicate, child: Text('Duplicate as draft')),
                    const PopupMenuItem(
                      value: _JobAction.delete,
                      child: Text('Delete', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
            ],
          ),
          if (job.returned) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: NoteStrip(
                key: ValueKey('returned-${job.id}'),
                icon: LucideIcons.undo2,
                color: AppColors.amber500,
                child: Text(
                  'ICR sent this back: ${job.reviewNote}',
                  style: CareerText.body.copyWith(color: AppColors.onSurface),
                ),
              ),
            ),
          ],
          if (live || job.status == PostingStatus.inReview) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _PipelineBar(counts: pipeline),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    pipeline.total == 0
                        ? 'No applicants yet'
                        : '${pipeline.total} ${pipeline.total == 1 ? 'applicant' : 'applicants'}'
                              '${pipeline.unviewed == 0 ? '' : ' • ${pipeline.unviewed} not viewed'}',
                    key: ValueKey('applicants-line-${job.id}'),
                    style: CareerText.meta,
                  ),
                ),
                OutlinedButton(
                  key: ValueKey('open-applicants-${job.id}'),
                  onPressed: onApplicants,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: AppColors.outlineVariant),
                    shape: const StadiumBorder(),
                  ),
                  child: Text('Applicants', style: CareerText.link),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  key: ValueKey('continue-${job.id}'),
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: AppColors.outlineVariant),
                    shape: const StadiumBorder(),
                  ),
                  child: Text('Continue editing', style: CareerText.link),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A posting's applicants by stage as one bar: applied, in review, interview, offer, hired, then not selected.
class _PipelineBar extends StatelessWidget {
  const _PipelineBar({required this.counts});

  final PipelineCounts counts;

  static const _colors = {
    'APPLIED': AppColors.slate300,
    'SCREENING': Color(0xFF93C5FD),
    'INTERVIEW': AppColors.primary,
    'OFFER': AppColors.amber500,
    'HIRED': AppColors.success,
    'REJECTED': AppColors.slate200,
  };

  @override
  Widget build(BuildContext context) {
    final parts = [
      for (final e in _colors.entries)
        if (counts.count(e.key) > 0) (e.key, counts.count(e.key), e.value),
    ];
    return ClipRRect(
      key: const ValueKey('pipeline-bar'),
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: parts.isEmpty
            ? const ColoredBox(color: AppColors.surfaceContainer)
            : Row(
                children: [
                  for (final p in parts)
                    Expanded(
                      flex: p.$2,
                      child: ColoredBox(color: p.$3),
                    ),
                ],
              ),
      ),
    );
  }
}
