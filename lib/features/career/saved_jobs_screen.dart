import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/widgets/buttons.dart';
import '../../core/widgets/section_heading.dart';
import '../jobs/job_detail_sheet.dart';
import '../jobs/job_links.dart';
import '../jobs/jobs_navigation.dart';
import '../jobs/jobs_styles.dart';
import '../jobs/widgets/job_row.dart';
import 'career_models.dart';
import 'career_repository.dart';
import 'career_styles.dart';
import 'career_widgets.dart';
import 'saved_jobs_controller.dart';

/// "Saved jobs": the jobs the member bookmarked, and, on the second shelf, the
/// ones they told the board they are not interested in (each with "Show again").
/// The website's `/career/saved`, plus the hidden jobs it only offers inside the job.
class SavedJobsScreen extends StatefulWidget {
  const SavedJobsScreen({
    super.key,
    required this.repository,
    this.links = const SystemJobLinks(),
    this.navigation = JobsNavigation.none,
    this.tab = SavedTab.saved,
    this.onBack,
  });

  final CareerRepository repository;
  final JobLinks links;

  /// Where a company, a conversation, a member and the bell open.
  final JobsNavigation navigation;

  /// The shelf it opens on: the career hub's "Hidden jobs" opens the second.
  final SavedTab tab;
  final VoidCallback? onBack;

  @override
  State<SavedJobsScreen> createState() => _SavedJobsScreenState();
}

class _SavedJobsScreenState extends State<SavedJobsScreen> {
  late final SavedJobsController _c = SavedJobsController(widget.repository, tab: widget.tab);

  @override
  void initState() {
    super.initState();
    _c.start();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _open(Job job) => showJobDetail(
    context,
    job,
    repository: _c.repository.jobs,
    links: widget.links,
    navigation: widget.navigation,
    onChanged: _c.jobChanged,
    onApplied: _c.jobChanged,
    onHidden: (_) => _c.refresh(),
  );

  Future<void> _unsave(Job job) async {
    final at = _c.indexOfSaved(job);
    final message = await _c.unsave(job);
    if (!mounted) return;
    if (message != null) {
      showMessage(context, message);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Bookmark removed'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              final refusal = await _c.resave(job, at: at);
              if (refusal != null && mounted) showMessage(context, refusal);
            },
          ),
        ),
      );
  }

  Future<void> _unhide(Job job) async {
    final message = await _c.unhide(job);
    if (!mounted) return;
    if (message != null) {
      showMessage(context, message);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Back on your board'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              final refusal = await _c.rehide(job);
              if (refusal != null && mounted) showMessage(context, refusal);
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => CareerScaffold(
        title: 'Saved jobs',
        onBack: widget.onBack,
        unread: _c.unread,
        onBell: () => widget.navigation.openNotifications(context, widget.links),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _c.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const SizedBox(height: 10),
              CountTabs<SavedTab>(
                values: SavedTab.values,
                selected: _c.tab,
                label: (t) => t.label,
                keyPrefix: 'saved-tab',
                count: (t) => t == SavedTab.saved
                    ? (_c.savedLoaded ? _c.saved.length : -1)
                    : (_c.hiddenLoaded ? _c.hidden.length : -1),
                onSelect: _c.select,
              ),
              const SizedBox(height: 8),
              const Hairline(color: AppColors.blockRule),
              ..._body(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body() {
    return _c.tab == SavedTab.saved ? _savedBody() : _hiddenBody();
  }

  List<Widget> _savedBody() {
    if (_c.savedError != null && !_c.savedLoaded) {
      return [
        CareerNotice(
          key: const ValueKey('saved-error'),
          icon: LucideIcons.cloudOff,
          title: "Couldn't load your saved jobs",
          body: _c.savedError!,
          action: 'Try again',
          onAction: _c.refresh,
        ),
      ];
    }
    if (!_c.savedLoaded) return const [CareerLoading()];
    if (_c.saved.isEmpty) {
      return [
        CareerNotice(
          key: const ValueKey('saved-empty'),
          icon: LucideIcons.bookmark,
          title: 'No saved jobs yet',
          body: 'Tap the bookmark on a job to keep it here.',
          action: 'Browse jobs',
          onAction: widget.onBack ?? () => Navigator.maybePop(context),
        ),
      ];
    }
    return [
      for (final (i, job) in _c.saved.indexed) ...[
        if (i > 0) const Hairline(indent: 10, endIndent: 10.5),
        JobRow(
          key: ValueKey('saved-${job.id}'),
          job: job,
          caption: job.isOpen ? null : 'No longer accepting applications',
          onTap: () => _open(job),
          onSave: () => _unsave(job),
        ),
      ],
      if (_c.savedHasMore) ViewMoreRow(loading: _c.loadingMore, onTap: _c.loadMore),
    ];
  }

  List<Widget> _hiddenBody() {
    if (_c.hiddenError != null && !_c.hiddenLoaded) {
      return [
        CareerNotice(
          key: const ValueKey('hidden-error'),
          icon: LucideIcons.cloudOff,
          title: "Couldn't load your hidden jobs",
          body: _c.hiddenError!,
          action: 'Try again',
          onAction: _c.refresh,
        ),
      ];
    }
    if (!_c.hiddenLoaded) return const [CareerLoading()];
    if (_c.hidden.isEmpty) {
      return const [
        CareerNotice(
          key: ValueKey('hidden-empty'),
          icon: LucideIcons.eyeOff,
          title: 'No hidden jobs',
          body: 'A job you mark "Not interested" leaves your board and waits here, in case you change your mind.',
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 2),
        child: Text('These jobs stay off your board and your recommendations.', style: CareerText.body),
      ),
      for (final (i, job) in _c.hidden.indexed) ...[
        if (i > 0) const Hairline(indent: 10, endIndent: 10.5),
        HiddenJobRow(
          key: ValueKey('hidden-${job.id}'),
          job: job,
          onTap: job.company.id.isEmpty ? null : () => _open(job),
          onShowAgain: () => _unhide(job),
        ),
      ],
    ];
  }
}

/// One hidden job: its logo, title and company, and "Show again".
class HiddenJobRow extends StatelessWidget {
  const HiddenJobRow({super.key, required this.job, required this.onShowAgain, this.onTap});

  final Job job;
  final VoidCallback onShowAgain;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          children: [
            CompanyLogoTile(company: job.company),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.title, style: JobsText.rowTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(job.company.name, style: JobsText.rowCompany, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    [?job.place, 'Hidden'].join(' • '),
                    style: JobsText.rowMeta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinePillButton(label: 'Show again', onPressed: onShowAgain, height: 28),
          ],
        ),
      ),
    );
  }
}
