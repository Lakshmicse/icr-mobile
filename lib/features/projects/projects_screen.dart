import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/widgets/chips.dart';
import '../../core/widgets/title_bar.dart';
import '../account/widgets/account_kit.dart' show AccountButton;
import '../account/widgets/account_session.dart';
import '../notifications/notifications_screen.dart';
import '../site/site_kit.dart';
import 'project_models.dart';
import 'project_rows.dart';
import 'project_screen.dart';
import 'project_sheet.dart';
import 'projects_controller.dart';
import 'projects_repository.dart';

/// The company's sourcing projects (the website's `/manage/projects`): talent pools that live outside any single
/// job. The list by last change with its search and the website's two switches as chips (My Projects, Show Archived),
/// "+ Create Project" opening the website's dialog as a sheet, and each row opening the project's page.
///
/// The words are the owner's for this page (05-company-workspace.docx, 12 Nov 2026): the heading "Talent Sourcing
/// Projects" (in the title bar, where it fits at 360 dp), its description, the CTA, the search placeholder, the two
/// filters and the empty state with "Create Your First Project".
///
/// The page is the hiring team's (`RECRUITER_TIER`) and belongs to a company: someone acting for none is told so
/// (the website's `NoCompany`), a role outside the tier gets a calm note, never a 403.
///
/// Rows the whole width, hairlines between, nothing boxed. [repository] and [viewer] are seams for tests.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({
    super.key,
    required this.onBack,
    this.repository,
    this.viewer,
    this.onOpenJob,
    this.onCreateCompany,
    this.searchDelay = const Duration(milliseconds: 300),
  });

  final VoidCallback onBack;

  /// Where the calls go; the API (or the sample projects in demo mode) when null.
  final ProjectsRepository? repository;

  /// Who is looking; read from the signed-in session when null.
  final ProjectsViewer? viewer;

  /// Opens a job by its id (the project's job chip, a candidate's "Applied to"), when the app can.
  final ValueChanged<String>? onOpenJob;

  /// "Create a company", offered to someone acting for no company. Hidden without it.
  final VoidCallback? onCreateCompany;

  /// How long typing settles before the search runs.
  final Duration searchDelay;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late final ProjectsRepository _repository;
  late final ProjectsController _controller;
  late final ProjectsViewer _viewer;
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final user = maybeAuth(context)?.user;
    _viewer = widget.viewer ?? (user == null ? ProjectsViewer.none : ProjectsViewer.of(user));
    _repository =
        widget.repository ??
        (AppConfig.demo ? DemoProjectsRepository() : ApiProjectsRepository(api: context.read<ApiClient>()));
    _controller = ProjectsController(_repository);
    if (_viewer.hasCompany && _viewer.reachesPage) _controller.start();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _typed(String value) {
    _debounce?.cancel();
    _debounce = Timer(widget.searchDelay, () {
      if (mounted) _controller.setSearch(value);
    });
  }

  Future<void> _create() async {
    final created = await showProjectSheet(
      context,
      jobs: _repository.companyJobs,
      send: (draft) => _controller.create(draft),
    );
    if (created && mounted) showMessage(context, 'Project created.');
  }

  Future<void> _open(Project p) async {
    final controller = _controller;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => ProjectScreen(
          projectId: p.id,
          initial: p,
          repository: _repository,
          onBack: () => Navigator.of(ctx).pop(),
          onOpenJob: widget.onOpenJob,
          onChanged: controller.took,
        ),
      ),
    );
  }

  /// The owner's page heading ("Talent Sourcing Projects" rather than the website's "Sourcing projects").
  static const _heading = 'Talent Sourcing Projects';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TitleBar(title: _heading, onBack: widget.onBack, onBell: () => openNotifications(context)),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (!_viewer.hasCompany) {
      return ProjectsNotice(
        key: const Key('projects.noCompany'),
        icon: Symbols.business,
        title: _heading,
        text: 'Talent sourcing projects belong to a company.',
        action: widget.onCreateCompany == null
            ? null
            : AccountButton(
                key: const Key('projects.createCompany'),
                label: 'Create a Company',
                icon: Symbols.add_business,
                expand: false,
                onPressed: widget.onCreateCompany,
              ),
      );
    }
    if (!_viewer.reachesPage) {
      return const ProjectsNotice(
        key: Key('projects.noAccess'),
        icon: Symbols.lock,
        title: 'This Page Is for Your Company’s Hiring Team',
        text:
            'Talent sourcing projects are managed by company admins, office admins and recruiters. Ask your company’s '
            'admin for '
            'one of those roles.',
      );
    }
    return ListenableBuilder(listenable: _controller, builder: (context, _) => _list(_controller));
  }

  Widget _list(ProjectsController c) {
    if (c.loading && !c.loaded && c.error == null) return const SiteLoading();
    if (c.error != null && !c.loaded) {
      return SiteError(key: const Key('projects.error'), message: c.error!, onRetry: c.refresh);
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => c.refresh(quiet: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) c.loadMore();
          return false;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Build and manage talent pools beyond individual job openings. Identify, engage and shortlist '
                      'candidates for current and future hiring needs.',
                      key: const Key('projects.lead'),
                      style: SiteText.secondary,
                    ),
                    const SizedBox(height: 12),
                    // The description is too long to share a 360 dp row with the button, so the CTA sits under it.
                    AccountButton(
                      key: const Key('projects.new'),
                      label: 'Create Project',
                      icon: Icons.add_rounded,
                      expand: false,
                      height: 36,
                      onPressed: _create,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('projects.search'),
                      controller: _search,
                      onChanged: _typed,
                      textInputAction: TextInputAction.search,
                      style: SiteText.body,
                      decoration: InputDecoration(
                        // The owner's words. The API matches the project's name only (`ProjectsService.list`).
                        hintText: 'Search projects by name or role…',
                        hintStyle: SiteText.secondary,
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.slate400),
                        prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: const UnderlineInputBorder(borderSide: BorderSide(color: SiteColors.hairline)),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: SiteColors.hairline)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // The website's two switches ("Only mine", "Show archived"), as chips in the owner's words.
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ToggleChip(
                          key: const Key('projects.filter.mine'),
                          label: 'My Projects',
                          on: c.mine,
                          onTap: () => c.setMine(!c.mine),
                        ),
                        _ToggleChip(
                          key: const Key('projects.filter.archived'),
                          label: 'Show Archived',
                          on: c.includeArchived,
                          onTap: () => c.setIncludeArchived(!c.includeArchived),
                        ),
                      ],
                    ),
                    if (c.error != null) ...[
                      const SizedBox(height: 12),
                      Text(c.error!, key: const Key('projects.inlineError'), style: SiteText.secondary),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            if (c.loading)
              const SliverToBoxAdapter(
                child: Padding(padding: EdgeInsets.all(24), child: SiteLoading()),
              )
            else if (c.rows.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  child: c.search.isEmpty && !c.mine
                      // Nothing at all yet: the owner's empty state, with its own way in.
                      ? Column(
                          key: const Key('projects.empty'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('No Sourcing Projects Yet', style: SiteText.strong),
                            const SizedBox(height: 4),
                            Text(
                              'Create your first project to build a talent pool and shortlist candidates for upcoming '
                              'or recurring hiring needs.',
                              style: SiteText.secondary,
                            ),
                            const SizedBox(height: 14),
                            AccountButton(
                              key: const Key('projects.empty.create'),
                              label: 'Create Your First Project',
                              expand: false,
                              height: 36,
                              onPressed: _create,
                            ),
                          ],
                        )
                      // A search or "My Projects" that finds nothing: the company may well have projects.
                      : Column(
                          key: const Key('projects.empty'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('No Matching Projects', style: SiteText.strong),
                            const SizedBox(height: 4),
                            Text('Try another name or clear the filters.', style: SiteText.secondary),
                          ],
                        ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 28),
                sliver: SliverList.separated(
                  itemCount: c.rows.length + (c.loadingMore ? 1 : 0),
                  separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
                  itemBuilder: (context, i) {
                    if (i == c.rows.length) return const Padding(padding: EdgeInsets.all(16), child: SiteLoading());
                    final p = c.rows[i];
                    return ProjectRow(key: ValueKey('projects.row.${p.id}'), project: p, onTap: () => _open(p));
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({super.key, required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IcrChip(
      label: label,
      tone: on ? ChipTone.primary : ChipTone.outlined,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      textStyle: AppText.workSans(13, FontWeight.w600, AppColors.onSurface, lineHeight: 18),
      icon: on ? Icons.check_rounded : null,
      onTap: onTap,
    );
  }
}
