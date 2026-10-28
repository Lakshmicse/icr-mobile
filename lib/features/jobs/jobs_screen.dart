import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/widgets/section_heading.dart';
import '../../core/widgets/title_bar.dart';
import '../career/career_routes.dart';
import 'job_detail_sheet.dart';
import 'jobs_controller.dart';
import 'jobs_navigation.dart';
import 'widgets/job_row.dart';
import 'widgets/jobs_toolbar.dart';

/// The Jobs tab: the board from the Jobs design.
class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key, required this.onBack, this.navigation});

  /// The arrow at the top left; the shell goes back to Home.
  final VoidCallback onBack;

  /// Where a company, a conversation, a member, the bell and the profile open from the board
  /// and every screen it opens. Without it, the nearest [JobsNavigationScope], else the website.
  final JobsNavigation? navigation;

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();

  /// The saved search's heading, for "Alerts" to scroll to.
  final _alertKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final jobs = context.read<JobsController>();
    if (!jobs.started) jobs.start();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) context.read<JobsController>().loadMore();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> action) async {
    final message = await action;
    if (message != null && mounted) showMessage(context, message);
  }

  /// "Alerts": runs the saved search and shows its results; with no saved
  /// search to run, the form to make one.
  Future<void> _alerts() async {
    final jobs = context.read<JobsController>();
    if (!jobs.hasAlert) {
      await careerRoutesOf(context).alerts(create: true);
      if (mounted) await jobs.refresh();
      return;
    }
    _search.clear();
    final message = await jobs.runAlert();
    if (!mounted) return;
    if (message != null) {
      showMessage(context, message);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _alertKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final navigation = widget.navigation;
    final screen = _screen(context);
    return navigation == null ? screen : JobsNavigationScope(navigation: navigation, child: screen);
  }

  Widget _screen(BuildContext context) {
    final jobs = context.watch<JobsController>();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                top: TitleBar.height,
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: jobs.refresh,
                  child: CustomScrollView(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: JobsToolbar(searchController: _search, onAlerts: _alerts),
                      ),
                      ..._body(jobs),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: TitleBar(
                  title: 'Jobs',
                  onBack: widget.onBack,
                  unread: jobs.unread,
                  onBell: () =>
                      (widget.navigation ?? JobsNavigationScope.of(context)).openNotifications(context, jobs.links),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(JobsController jobs) {
    final sections = jobs.sections;
    final nothing = sections.every((s) => jobs.jobsOf(s).isEmpty);
    if (jobs.loading && nothing) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))),
        ),
      ];
    }
    if (jobs.error != null && nothing) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Notice(title: "Couldn't load jobs", body: jobs.error!, action: 'Try again', onAction: jobs.refresh),
        ),
      ];
    }
    if (nothing) {
      // Easy Apply hides every job that sends people to the employer's own site.
      final hidden = jobs.filters.easyApply && sections.any((s) => s.jobs.isNotEmpty);
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: hidden
              ? _Notice(
                  title: 'No Easy Apply jobs here',
                  body: "These jobs take applications on the employer's own site.",
                  action: 'Show all jobs',
                  onAction: jobs.toggleEasyApply,
                )
              : _Notice(
                  title: jobs.narrowed ? 'No jobs match' : 'No open jobs right now',
                  body: jobs.narrowed
                      ? 'Try other words, or clear the filters.'
                      : 'New roles show up here as employers post them.',
                  action: jobs.narrowed ? 'Clear filters' : null,
                  onAction: jobs.narrowed ? () => jobs.clearFilters() : null,
                ),
        ),
      ];
    }
    final children = <Widget>[];
    var first = true;
    for (final section in sections) {
      if (jobs.jobsOf(section).isEmpty) continue;
      children.add(SizedBox(height: first ? 12.5 : 10.5));
      first = false;
      children.add(
        KeyedSubtree(
          key: section.key == 'alert' ? _alertKey : ValueKey('heading-${section.key}'),
          child: SectionHeading(
            title: section.title,
            action: jobs.actionLabel(section),
            onAction: () => jobs.act(section),
          ),
        ),
      );
      children.add(const SizedBox(height: 11.5));
      for (final (i, job) in jobs.visible(section).indexed) {
        if (i > 0) children.add(const Hairline(indent: 10, endIndent: 10.5));
        children.add(
          JobRow(
            key: ValueKey('${section.key}-${job.id}'),
            job: job,
            onTap: () => showJobSheet(context, job),
            onSave: () => _run(jobs.toggleSave(job)),
          ),
        );
      }
    }
    children.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: jobs.loadingMore
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const SizedBox(height: 20),
        ),
      ),
    );
    // A column, not a lazy list: "Alerts" scrolls to a heading, which has to be built to be found.
    return [
      SliverToBoxAdapter(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    ];
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.body, this.action, this.onAction});

  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.briefcaseBusiness, size: 36, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: AppText.postTitle.copyWith(fontSize: 16, height: 1.3)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: AppText.small),
          if (action != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.outlineVariant),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(action!, style: AppText.link),
            ),
          ],
        ],
      ),
    );
  }
}
