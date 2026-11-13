import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/widgets/chips.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/title_bar.dart';
import '../chapters/community_kit.dart' show pickFromSheet;
import '../notifications/notifications_screen.dart';
import '../site/site_kit.dart';
import 'candidate_quick_view.dart';
import 'candidate_row.dart';
import 'describe_sheet.dart';
import 'talent_controller.dart';
import 'talent_filter_sheet.dart';
import 'talent_models.dart';
import 'talent_repository.dart';

/// The employer's talent search — the website's `/talent` ("Source candidates" under Jobs): search the pool by
/// name, headline, skill or employer, narrow it with the website's filters, describe who you want in plain
/// English, keep saved searches with alerts, or rank the pool against one of the company's jobs; each candidate
/// opens a quick view with their contact behind the paywall, an invitation, a message, and the team's private
/// notes and tags. A member with no hiring role, or acting for no company, is told so in the app's words.
///
/// Rows the whole width, hairlines between, nothing boxed. [repository] is a seam for tests; [onOpenMember] opens
/// a candidate's public profile (the lead connects it to the member profile).
class TalentScreen extends StatefulWidget {
  const TalentScreen({super.key, required this.onBack, this.onOpenMember, this.repository});

  final VoidCallback onBack;
  final void Function(String id)? onOpenMember;
  final TalentRepository? repository;

  @override
  State<TalentScreen> createState() => _TalentScreenState();
}

class _TalentScreenState extends State<TalentScreen> {
  late final TalentRepository _repo;
  late final TalentController _c;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo =
        widget.repository ??
        (AppConfig.demo ? DemoTalentRepository() : ApiTalentRepository(api: context.read<ApiClient>()));
    _c = TalentController(_repo)..start();
    _search.addListener(_typed);
    _c.addListener(_syncSearchBox);
  }

  @override
  void dispose() {
    _c.removeListener(_syncSearchBox);
    _search.removeListener(_typed);
    _c.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Free text is debounced; every other facet applies at once.
  void _typed() {
    if (_search.text != _c.query) _c.setQuery(_search.text);
  }

  /// A saved search, a brief or Clear all changed the query under the box.
  void _syncSearchBox() {
    if (_search.text != _c.query) _search.text = _c.query;
  }

  Future<void> _openFilters() async {
    final result = await showTalentFilters(
      context,
      initial: _c.filters,
      masters: _c.masters,
      // Matching is already to one job, so the sheet offers no other job to exclude for.
      jobs: _c.mode == TalentMode.match ? const [] : _c.jobs,
    );
    if (!mounted) return;
    switch (result) {
      case ApplyFilters(:final filters):
        await _c.setFilters(filters);
      case ClearAllFilters():
        await _c.reset();
      case null:
        break;
    }
  }

  Future<void> _pickSort() async {
    final picked = await pickFromSheet<TalentSort>(
      context,
      title: 'Sort',
      options: TalentSort.values,
      label: (s) => s.label,
      selected: _c.filters.sort,
    );
    if (picked != null && mounted) await _c.setSort(picked);
  }

  Future<void> _pickMatchJob() async {
    final picked = await pickFromSheet<JobOption>(
      context,
      title: 'Match Candidates to This Job',
      options: _c.jobs,
      label: (j) => j.title,
      selected: _c.matchJob,
    );
    if (picked != null && mounted) await _c.setMatchJob(picked.id);
  }

  Future<void> _describe() => showDescribeSheet(context, describe: _c.describe);

  Future<void> _saveSearch() async {
    if (_c.filterCount == 0) {
      showMessage(context, 'Set at least one filter first.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialog) => _SaveSearchDialog(onSave: (name, alerts) => _c.saveSearch(name, alertsEnabled: alerts)),
    );
  }

  Future<void> _savedMenu(SavedSearch s) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(s.name, style: SiteText.subheading),
              ),
            ),
            ListTile(
              key: const ValueKey('saved-menu-alerts'),
              leading: Icon(s.alertsEnabled ? LucideIcons.bellOff : LucideIcons.bellRing, size: 20),
              title: Text(s.alertsEnabled ? 'Turn Off Alerts' : 'Alert Me on New Matches', style: SiteText.body),
              onTap: () => Navigator.pop(sheet, 'alerts'),
            ),
            ListTile(
              key: const ValueKey('saved-menu-update'),
              leading: const Icon(LucideIcons.refreshCw, size: 20),
              title: Text('Update to Current Filters', style: SiteText.body),
              onTap: () => Navigator.pop(sheet, 'update'),
            ),
            ListTile(
              key: const ValueKey('saved-menu-delete'),
              leading: const Icon(LucideIcons.trash2, size: 20, color: AppColors.error),
              title: Text('Delete', style: SiteText.body.copyWith(color: AppColors.error)),
              onTap: () => Navigator.pop(sheet, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    final refusal = switch (action) {
      'alerts' => await _c.toggleAlerts(s),
      'update' => await _c.updateSavedToCurrent(s),
      'delete' => await _c.deleteSaved(s),
      _ => null,
    };
    if (refusal != null && mounted) showMessage(context, refusal);
  }

  void _openCandidate(Candidate c) {
    showCandidateQuickView(
      context,
      repository: _repo,
      candidate: c,
      hasCompany: !_c.noCompany,
      access: _c.access,
      viewer: _c.viewer,
      jobs: _c.jobs,
      onOpenMember: widget.onOpenMember,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              TitleBar(title: 'Source Candidates', onBack: widget.onBack, onBell: () => openNotifications(context)),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final c = _c;
    if (c.starting) return const SiteLoading();
    if (c.startError != null) {
      return SiteError(key: const ValueKey('talent-start-error'), message: c.startError!, onRetry: c.start);
    }
    if (!c.allowed) return _HirersOnly(viewer: c.viewer!);
    final match = c.mode == TalentMode.match;
    final rows = match ? c.matches : c.rows;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: match ? c.refreshMatch : c.refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (!match && n.metrics.pixels > n.metrics.maxScrollExtent - 200) c.loadMore();
          return false;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _toolbar()),
            ..._results(rows, match),
          ],
        ),
      ),
    );
  }

  Widget _toolbar() {
    final c = _c;
    final match = c.mode == TalentMode.match;
    final chips = c.chips;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            'Search the talent pool and reach out to professionals who match your roles.',
            style: SiteText.secondary,
          ),
        ),
        const SizedBox(height: 10),
        if (c.noCompany)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              key: const ValueKey('talent-no-company'),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              color: SiteColors.blueTint,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(LucideIcons.info, size: 16, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can search candidates and save searches. Matching them to jobs, saving them to '
                      'projects, and inviting or contacting them require a company.',
                      style: SiteText.body,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _ToolChip(
                  key: const ValueKey('mode-browse'),
                  label: 'Browse',
                  on: !match,
                  onTap: () => c.setMode(TalentMode.browse),
                ),
                const SizedBox(width: 8),
                _ToolChip(
                  key: const ValueKey('mode-match'),
                  label: 'Match to a Job',
                  on: match,
                  onTap: () => c.setMode(TalentMode.match),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IcrSearchField(
            key: const ValueKey('talent-search'),
            controller: _search,
            hint: 'Search name, headline, skill, employer…',
            height: 36,
            onSubmitted: c.submitQuery,
          ),
        ),
        const SizedBox(height: 10),
        // The actions wrap so every one stays in reach; the saved searches scroll sideways under them.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ToolChip(
                key: const ValueKey('talent-filters-chip'),
                label: c.filterCount > 0 ? 'Filters (${c.filterCount})' : 'Filters',
                icon: LucideIcons.slidersHorizontal,
                on: c.filterCount > 0,
                onTap: _openFilters,
              ),
              if (!match)
                _ToolChip(
                  key: const ValueKey('talent-sort-chip'),
                  label: c.filters.sort.label,
                  trailing: const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.onSurfaceVariant),
                  onTap: _pickSort,
                ),
              _ToolChip(
                key: const ValueKey('talent-describe-chip'),
                label: 'Describe Who You Want',
                icon: LucideIcons.sparkles,
                onTap: _describe,
              ),
              _ToolChip(
                key: const ValueKey('talent-save-search'),
                label: 'Save Search',
                icon: LucideIcons.bookmarkPlus,
                dim: c.filterCount == 0,
                onTap: _saveSearch,
              ),
            ],
          ),
        ),
        if (c.savedSearches.isNotEmpty) ...[
          const SizedBox(height: 10),
          ChipRow(
            height: 32,
            gap: 8,
            padding: 16,
            children: [
              for (final s in c.savedSearches)
                _ToolChip(
                  key: ValueKey('saved-${s.id}'),
                  label: s.name,
                  icon: s.alertsEnabled ? LucideIcons.bellRing : null,
                  on: c.activeSearchId == s.id,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.newMatchCount > 0) ...[
                        PillBadge(
                          s.newMatchCount > 99 ? '99+' : '${s.newMatchCount}',
                          color: c.activeSearchId == s.id ? Colors.white : AppColors.primary,
                          textColor: c.activeSearchId == s.id ? AppColors.primary : Colors.white,
                        ),
                        const SizedBox(width: 4),
                      ],
                      GestureDetector(
                        key: ValueKey('saved-menu-${s.id}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _savedMenu(s),
                        child: Icon(
                          LucideIcons.ellipsisVertical,
                          size: 16,
                          color: c.activeSearchId == s.id ? Colors.white : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => c.applySaved(s),
                ),
            ],
          ),
        ],
        if (c.lastParse != null) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              key: const ValueKey('talent-parse-line'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(LucideIcons.sparkles, size: 14, color: AppColors.primary),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(c.lastParse!.sentence, style: SiteText.meta)),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: c.dismissParse,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(LucideIcons.x, size: 14, color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final chip in chips)
                  IcrChip(
                    key: ValueKey('chip-${chip.key}'),
                    label: chip.label,
                    tone: ChipTone.filled,
                    height: 28,
                    textStyle: SiteText.meta.copyWith(color: SiteColors.ink, fontWeight: FontWeight.w500),
                    trailing: const Icon(LucideIcons.x, size: 14, color: AppColors.onSurfaceVariant),
                    trailingGap: 6,
                    onTap: () => c.removeChip(chip.key),
                  ),
                IcrChip(
                  key: const ValueKey('talent-clear-all'),
                  label: 'Clear All',
                  tone: ChipTone.outlined,
                  height: 28,
                  textStyle: SiteText.meta.copyWith(color: SiteColors.ink, fontWeight: FontWeight.w500),
                  onTap: c.reset,
                ),
              ],
            ),
          ),
        ],
        if (match) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: IcrChip(
              key: const ValueKey('match-job-chip'),
              label: c.matchJob?.title ?? 'Match Candidates to This Job',
              tone: ChipTone.outlined,
              icon: LucideIcons.briefcase,
              iconSize: 15,
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: SiteText.body,
              trailing: const Icon(Icons.expand_more, size: 18, color: AppColors.onSurfaceVariant),
              onTap: c.jobs.isEmpty ? null : _pickMatchJob,
            ),
          ),
          if (c.jobs.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text('No jobs to match against yet. Post a job first.', style: SiteText.meta),
            ),
        ],
        const SizedBox(height: 12),
        const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
      ],
    );
  }

  List<Widget> _results(List<Candidate> rows, bool match) {
    final c = _c;
    Widget pad(Widget child, {Key? key}) => SliverToBoxAdapter(
      child: Padding(key: key, padding: const EdgeInsets.fromLTRB(16, 20, 16, 20), child: child),
    );
    if (match) {
      if (c.matchJobId == null) {
        return [
          pad(
            _Empty(title: 'Select a Job', body: 'Select one of your jobs to rank matching candidates.'),
            key: const ValueKey('match-pick'),
          ),
        ];
      }
      if (c.matchLoading && rows.isEmpty) {
        return const [SliverToBoxAdapter(child: SizedBox(height: 160, child: SiteLoading()))];
      }
      if (c.matchError != null && rows.isEmpty) {
        return [pad(Text(c.matchError!, key: const ValueKey('match-error'), style: SiteText.secondary))];
      }
      if (rows.isEmpty) {
        return [
          pad(
            _Empty(
              title: 'No Matches Yet',
              body:
                  "No discoverable candidates meet this job's requirements and your filters, or they've already applied.",
            ),
            key: const ValueKey('match-empty'),
          ),
        ];
      }
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Showing candidates who meet this job's experience and cities, hold at least one of its required "
                  'skills, and match your filters.',
                  style: SiteText.meta,
                ),
                const SizedBox(height: 8),
                Text(_count(rows.length), key: const ValueKey('talent-count'), style: SiteText.secondary),
              ],
            ),
          ),
        ),
        _list(rows, trailingSpinner: false),
      ];
    }
    if (c.loading && rows.isEmpty) {
      return const [SliverToBoxAdapter(child: SizedBox(height: 200, child: SiteLoading()))];
    }
    if (c.error != null && rows.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 240,
            child: SiteError(key: const ValueKey('talent-error'), message: c.error!, onRetry: c.refresh),
          ),
        ),
      ];
    }
    if (rows.isEmpty) {
      return [
        pad(
          _Empty(title: 'No Candidates Found', body: 'Try removing a filter or widening the notice-period range.'),
          key: const ValueKey('talent-empty'),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(_count(c.total), key: const ValueKey('talent-count'), style: SiteText.secondary),
              ),
              if (c.loading) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
      ),
      if (c.error != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(c.error!, key: const ValueKey('talent-inline-error'), style: SiteText.secondary),
          ),
        ),
      _list(rows, trailingSpinner: c.loadingMore),
    ];
  }

  static String _count(int n) => n == 1 ? '1 candidate' : '$n candidates';

  Widget _list(List<Candidate> rows, {required bool trailingSpinner}) => SliverPadding(
    padding: const EdgeInsets.only(top: 4, bottom: 28),
    sliver: SliverList.separated(
      itemCount: rows.length + (trailingSpinner ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
      itemBuilder: (context, i) {
        if (i == rows.length) return const Padding(padding: EdgeInsets.all(16), child: SiteLoading());
        final cand = rows[i];
        return CandidateRow(
          key: ValueKey('candidate-${cand.userId}'),
          candidate: cand,
          onOpen: () => _openCandidate(cand),
        );
      },
    ),
  );
}

/// The toolbar's chips: on in blue, off outlined, dimmed when the action is not yet possible.
class _ToolChip extends StatelessWidget {
  const _ToolChip({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.on = false,
    this.dim = false,
    this.trailing,
  });

  final String label;
  final IconData? icon;
  final bool on;
  final bool dim;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = on ? Colors.white : (dim ? AppColors.outline : SiteColors.ink);
    return IcrChip(
      label: label,
      tone: on ? ChipTone.primary : ChipTone.outlined,
      icon: icon,
      iconSize: 14,
      iconColor: ink,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      gap: 6,
      trailing: trailing,
      trailingGap: 6,
      textStyle: SiteText.body.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: ink),
      onTap: onTap,
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: SiteText.subheading),
        const SizedBox(height: 4),
        Text(body, style: SiteText.secondary),
      ],
    );
  }
}

/// What a member who is not on a hiring team sees instead of the search, in the order the job composer's
/// `showHirersOnly` says it (the website's `NoCompany` on `/talent`): acting as themselves while they belong to
/// companies, switch to one; belonging to none, create one; acting for a company in a role that does not source,
/// ask its admin for the recruiter role.
class _HirersOnly extends StatelessWidget {
  const _HirersOnly({required this.viewer});

  final TalentViewer viewer;

  @override
  Widget build(BuildContext context) {
    final actingForCompany = viewer.hasCompany;
    final canSwitch = !actingForCompany && viewer.companiesHeld > 0;
    final (title, body) = actingForCompany
        ? (
            'Candidates Are Sourced by the Hiring Team',
            'Your role at this company cannot source candidates. Ask its admin to make you a recruiter to '
                'search the talent pool, save searches and invite people to apply.',
          )
        : canSwitch
        ? (
            'You Are Using Your Personal Account',
            'Candidate sourcing belongs to a company. Switch to one of your companies (My Companies, in your profile '
                'menu) to search the talent pool on its behalf.',
          )
        : (
            'Candidates Are Sourced for a Company',
            'Create your company on ICR to search the talent pool, save searches and invite people to apply. '
                'If your company is already on ICR, ask its admin to make you a recruiter.',
          );
    return Padding(
      key: const ValueKey('talent-hirers-only'),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.users, size: 28, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(title, style: SiteText.heading),
          const SizedBox(height: 6),
          Text(body, style: SiteText.secondary),
        ],
      ),
    );
  }
}

/// "Save this search": a name, whether to be told of new matches (checked once a day), and the API's refusal when
/// it will not keep it.
class _SaveSearchDialog extends StatefulWidget {
  const _SaveSearchDialog({required this.onSave});

  final Future<String?> Function(String name, bool alerts) onSave;

  @override
  State<_SaveSearchDialog> createState() => _SaveSearchDialogState();
}

class _SaveSearchDialogState extends State<_SaveSearchDialog> {
  final _name = TextEditingController();
  bool _alerts = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final refusal = await widget.onSave(name, _alerts);
    if (!mounted) return;
    if (refusal != null) {
      setState(() {
        _saving = false;
        _error = refusal;
      });
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Save This Search', style: SiteText.heading),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('save-search-name'),
            controller: _name,
            autofocus: true,
            maxLength: 80,
            style: SiteText.body,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Name',
              counterText: '',
              helperText: _error ?? 'e.g. "Mumbai FM leads, 30-day notice"',
              helperStyle: _error == null ? SiteText.meta : SiteText.meta.copyWith(color: AppColors.error),
              helperMaxLines: 3,
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const ValueKey('save-search-alerts'),
            value: _alerts,
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.primary,
            title: Text('Notify Me When New Candidates Match', style: SiteText.body),
            onChanged: (v) => setState(() => _alerts = v),
          ),
          Text('Alerts are checked once a day.', style: SiteText.meta),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: SiteText.link),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _name,
          builder: (context, value, _) => FilledButton(
            key: const ValueKey('save-search-submit'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary, shape: const StadiumBorder()),
            onPressed: value.text.trim().isEmpty || _saving ? null : _submit,
            child: Text('Save', style: SiteText.button),
          ),
        ),
      ],
    );
  }
}
