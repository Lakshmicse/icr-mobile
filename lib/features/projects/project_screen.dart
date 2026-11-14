import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/widgets/chips.dart';
import '../../core/widgets/title_bar.dart';
import '../account/widgets/account_kit.dart' show AccountButton, confirmAction;
import '../notifications/notifications_screen.dart';
import '../site/site_kit.dart';
import 'project_models.dart';
import 'project_rows.dart';
import 'project_sheet.dart';
import 'projects_controller.dart';
import 'projects_repository.dart';

/// Tells the list what the page did to its project: the row as it now stands, or null when deleted.
typedef ProjectChanged = void Function(String id, Project? project);

/// A project's page (the website's `/manage/projects/[id]`): its name and subtitle, Archive / Un-archive and a menu
/// (Edit, Delete), its visibility, job and criteria as chips, then two tabs — **Pipeline**, the saved candidates by
/// stage (Sourced, Contacted, Replied, Shortlisted, with Archived under them), each moved on with the arrow or
/// anywhere from its menu, or taken out; and **Find candidates**, the people its criteria match, each saved with one
/// tap (rule-based filters, not an AI ranking).
///
/// [repository] is a seam for tests; [initial] draws the heading before the page has been read.
class ProjectScreen extends StatefulWidget {
  const ProjectScreen({
    super.key,
    required this.projectId,
    this.initial,
    this.repository,
    this.onBack,
    this.onOpenJob,
    this.onChanged,
  });

  final String projectId;
  final Project? initial;
  final ProjectsRepository? repository;

  /// Back from the title bar; defaults to popping the route.
  final VoidCallback? onBack;

  /// Opens a job by its id (the job chip, a candidate's "Applied to"), when the app can.
  final ValueChanged<String>? onOpenJob;

  /// Told when the project changed here (archived, edited, deleted, a candidate added or removed).
  final ProjectChanged? onChanged;

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  late final ProjectsRepository _repository;
  late final ProjectController _controller;
  int _tab = 0;
  bool _toldOnce = false;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        (AppConfig.demo ? DemoProjectsRepository() : ApiProjectsRepository(api: context.read<ApiClient>()));
    _controller = ProjectController(_repository, projectId: widget.projectId, initial: widget.initial)..start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Tells the list once, on the way out, when the project changed here.
  void _told() {
    if (_toldOnce || !_controller.changed) return;
    _toldOnce = true;
    widget.onChanged?.call(widget.projectId, _controller.deleted ? null : _controller.project);
  }

  void _back() {
    _told();
    (widget.onBack ?? () => Navigator.of(context).maybePop())();
  }

  Future<void> _archive(Project p) async {
    final refusal = await _controller.setArchived(!p.archived);
    if (!mounted) return;
    if (refusal != null) {
      showMessage(context, refusal);
      return;
    }
    showMessage(context, p.archived ? 'Project unarchived.' : 'Project archived.');
  }

  Future<void> _edit(Project p) async {
    final saved = await showProjectSheet(
      context,
      project: p,
      jobs: _repository.companyJobs,
      send: (draft) => _controller.update(draft.changesFrom(p)),
    );
    if (saved && mounted) showMessage(context, 'Project saved.');
  }

  Future<void> _delete(Project p) async {
    final ok = await confirmAction(
      context,
      title: 'Delete ${p.name}?',
      message:
          'The project and its ${p.candidateCount == 1 ? 'saved candidate' : 'saved candidates'} will be removed from '
          'your company’s projects. No applications are affected.',
      confirm: 'Delete',
    );
    if (!ok || !mounted) return;
    final refusal = await _controller.delete();
    if (!mounted) return;
    if (refusal != null) {
      showMessage(context, refusal);
      return;
    }
    _back();
  }

  Future<void> _move(ProjectCandidate c, String stage) async {
    final refusal = await _controller.moveCandidate(c, stage);
    if (refusal != null && mounted) showMessage(context, refusal);
  }

  Future<void> _remove(ProjectCandidate c) async {
    final refusal = await _controller.removeCandidate(c);
    if (!mounted) return;
    showMessage(context, refusal ?? 'Removed ${c.name} from the project.');
  }

  Future<void> _save(CandidateMatch m) async {
    final refusal = await _controller.saveMatch(m);
    if (refusal == null && mounted) showMessage(context, 'Saved ${m.name} to the project.');
  }

  void _selectTab(int i) {
    setState(() => _tab = i);
    if (i == 1) _controller.loadMatches();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _told();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              TitleBar(title: 'Project', onBack: _back, onBell: () => openNotifications(context)),
              Expanded(
                child: ListenableBuilder(listenable: _controller, builder: (context, _) => _body(_controller)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(ProjectController c) {
    final p = c.project;
    if (p == null) {
      if (c.loading) return const SiteLoading();
      return SiteError(
        key: const Key('project.error'),
        message: c.error ?? 'Unable to load the project.',
        onRetry: c.refresh,
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await c.refresh();
        if (_tab == 1) await c.refreshMatches();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          _Heading(
            project: p,
            busy: c.busy,
            onArchive: () => _archive(p),
            onEdit: () => _edit(p),
            onDelete: () => _delete(p),
            onOpenJob: widget.onOpenJob,
          ),
          if (c.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(c.error!, key: const Key('project.inlineError'), style: SiteText.secondary),
            ),
          ProjectTabs(
            labels: ['Pipeline (${p.candidateCount})', 'Find Candidates'],
            keys: const [Key('project.tab.pipeline'), Key('project.tab.find')],
            selected: _tab,
            onSelect: _selectTab,
          ),
          if (_tab == 0) ..._pipeline(c) else ..._matches(c),
        ],
      ),
    );
  }

  // --- Pipeline ------------------------------------------------------------------------------------------------------

  List<Widget> _pipeline(ProjectController c) {
    if (c.rosterLoading && c.candidates.isEmpty) {
      return const [Padding(padding: EdgeInsets.all(24), child: SiteLoading())];
    }
    if (c.candidates.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            key: const Key('project.roster.empty'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No Candidates Yet', style: SiteText.strong),
              const SizedBox(height: 4),
              Text(
                "Use “Find Candidates” to add people who match this project's criteria, save them from talent "
                "search, or add applicants from a job's pipeline.",
                style: SiteText.secondary,
              ),
            ],
          ),
        ),
      ];
    }
    final archived = c.inStage('ARCHIVED');
    return [
      for (final stage in sourcingBoardStages) ...[
        ProjectSectionHeading(
          key: Key('project.stage.$stage'),
          title: sourcingStageLabel(stage),
          count: c.inStage(stage).length,
        ),
        if (c.inStage(stage).isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text('No candidates in this stage yet.', style: SiteText.meta),
          )
        else
          ..._rows(c, c.inStage(stage)),
      ],
      if (archived.isNotEmpty) ...[
        ProjectSectionHeading(key: const Key('project.stage.ARCHIVED'), title: 'Archived', count: archived.length),
        ..._rows(c, archived),
      ],
    ];
  }

  List<Widget> _rows(ProjectController c, List<ProjectCandidate> rows) => [
    for (final (i, r) in rows.indexed) ...[
      if (i > 0) const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
      CandidateRow(
        key: ValueKey('project.candidate.${r.candidateId}'),
        candidate: r,
        busy: c.candidateBusy(r.candidateId),
        onMove: (stage) => _move(r, stage),
        onRemove: () => _remove(r),
        onOpenJob: widget.onOpenJob,
      ),
    ],
  ];

  // --- Find candidates -------------------------------------------------------------------------------------------------

  List<Widget> _matches(ProjectController c) {
    final rows = c.matches;
    // The website disables every Save while one is on its way.
    final saving = rows != null && rows.any((m) => c.candidateBusy(m.userId));
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Text(
          "Candidates matching this project's criteria, excluding anyone already saved. These are rule-based "
          'filters, not an AI ranking.',
          style: SiteText.secondary,
        ),
      ),
      if (c.saveError != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(
            key: const Key('project.saveError'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(LucideIcons.triangleAlert, size: 16, color: AppColors.amber800),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(c.saveError!, style: SiteText.secondary)),
              IconButton(
                tooltip: 'Dismiss',
                visualDensity: VisualDensity.compact,
                onPressed: c.dismissSaveError,
                icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.slate500),
              ),
            ],
          ),
        ),
      if (c.matchesLoading && rows == null)
        const Padding(padding: EdgeInsets.all(24), child: SiteLoading())
      else if (c.matchesError != null && rows == null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            key: const Key('project.matches.error'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.matchesError!, style: SiteText.secondary),
              const SizedBox(height: 10),
              AccountButton(label: 'Try Again', outlined: true, expand: false, height: 36, onPressed: c.refreshMatches),
            ],
          ),
        )
      else if (rows == null || rows.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            key: const Key('project.matches.empty'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No Matches', style: SiteText.strong),
              const SizedBox(height: 4),
              Text("Broaden the project's criteria or add candidates from talent search.", style: SiteText.secondary),
            ],
          ),
        )
      else
        for (final (i, m) in rows.indexed) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
          MatchRow(
            key: ValueKey('project.match.${m.userId}'),
            match: m,
            busy: c.candidateBusy(m.userId),
            disabled: saving || c.candidateBusy(m.userId),
            onSave: () => _save(m),
          ),
        ],
    ];
  }
}

/// The page's head, as the website's `PageHeader` and chips: name, subtitle, Archive / Un-archive and the menu,
/// then the visibility, the job and each criterion.
class _Heading extends StatelessWidget {
  const _Heading({
    required this.project,
    required this.busy,
    required this.onArchive,
    required this.onEdit,
    required this.onDelete,
    this.onOpenJob,
  });

  final Project project;
  final bool busy;
  final VoidCallback onArchive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String>? onOpenJob;

  @override
  Widget build(BuildContext context) {
    final p = project;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, key: const Key('project.title'), style: SiteText.title),
                    const SizedBox(height: 4),
                    Text(p.subtitle, key: const Key('project.subtitle'), style: SiteText.secondary),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: const Key('project.menu'),
                tooltip: 'More for this project',
                enabled: !busy,
                icon: const Icon(LucideIcons.ellipsisVertical, size: 20, color: AppColors.onSurfaceVariant),
                onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(key: Key('project.menu.edit'), value: 'edit', child: Text('Edit Project')),
                  PopupMenuItem(
                    key: Key('project.menu.delete'),
                    value: 'delete',
                    child: Text('Delete Project', style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AccountButton(
                  key: const Key('project.archive'),
                  label: p.archived ? 'Unarchive' : 'Archive',
                  outlined: true,
                  expand: false,
                  height: 34,
                  busy: busy,
                  onPressed: onArchive,
                ),
                IcrChip(
                  key: const Key('project.visibility.chip'),
                  label: projectVisibilityLabel(p.visibility),
                  height: 26,
                ),
                if (p.jobTitle != null)
                  IcrChip(
                    key: const Key('project.job.chip'),
                    label: p.jobTitle!,
                    height: 26,
                    icon: LucideIcons.briefcaseBusiness,
                    onTap: onOpenJob == null || p.jobId == null ? null : () => onOpenJob!(p.jobId!),
                  ),
                for (final c in p.criteria) IcrChip(label: c, tone: ChipTone.outlined, height: 26),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
