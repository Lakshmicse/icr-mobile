import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/widgets/buttons.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/section_heading.dart';
import '../jobs/job_detail_sheet.dart';
import '../jobs/job_links.dart';
import '../jobs/jobs_styles.dart';
import '../jobs/jobs_navigation.dart';
import '../jobs/widgets/job_row.dart';
import 'career_format.dart';
import 'career_models.dart';
import 'career_repository.dart';
import 'career_styles.dart';
import 'career_widgets.dart';
import 'job_alert_models.dart';
import 'job_alerts_controller.dart';

/// Opens "Job alerts" over whatever is showing. [create] opens the "New alert" form on
/// arrival, filled from [criteria] (the board saves the search it is showing this way);
/// [onChanged] hears that the board's "N new" may have changed.
Future<void> openJobAlerts(
  BuildContext context, {
  required CareerRepository repository,
  JobLinks? links,
  JobsNavigation? navigation,
  bool create = false,
  AlertCriteria? criteria,
  VoidCallback? onChanged,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => JobAlertsScreen(
        repository: repository,
        links: links ?? const SystemJobLinks(),
        navigation: navigation ?? JobsNavigationScope.of(context),
        startWithForm: create,
        initialCriteria: criteria,
        onChanged: onChanged,
      ),
    ),
  );
}

/// "Job alerts": the searches the member saved and what each has found. The website's
/// `/career/alerts`, plus making and editing a search (the website saves one from the board).
class JobAlertsScreen extends StatefulWidget {
  const JobAlertsScreen({
    super.key,
    required this.repository,
    this.links = const SystemJobLinks(),
    this.navigation = JobsNavigation.none,
    this.onBack,
    this.onChanged,
    this.startWithForm = false,
    this.initialCriteria,
  });

  final CareerRepository repository;
  final JobLinks links;
  final JobsNavigation navigation;
  final VoidCallback? onBack;

  /// Tells the board that "N new" may have changed.
  final VoidCallback? onChanged;

  /// Opens the "New alert" form as the screen opens.
  final bool startWithForm;

  /// The filters the "New alert" form starts from.
  final AlertCriteria? initialCriteria;

  @override
  State<JobAlertsScreen> createState() => _JobAlertsScreenState();
}

class _JobAlertsScreenState extends State<JobAlertsScreen> {
  late final JobAlertsController _c = JobAlertsController(widget.repository, onSeen: widget.onChanged);

  @override
  void initState() {
    super.initState();
    _c.start();
    if (widget.startWithForm) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _newAlert(widget.initialCriteria);
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _newAlert([AlertCriteria? criteria]) async {
    final saved = await showAlertForm(context, criteria: criteria, onSave: (draft) => _c.create(draft));
    if (saved == true && mounted) showMessage(context, 'Alert saved. We will tell you when new jobs match.');
  }

  Future<void> _edit(JobAlert alert) async {
    final saved = await showAlertForm(context, alert: alert, onSave: (draft) => _c.edit(alert, draft));
    if (saved == true && mounted) showMessage(context, 'Alert updated.');
  }

  Future<void> _delete(JobAlert alert) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        key: const ValueKey('delete-alert-dialog'),
        title: Text('Delete “${alert.name}”?'),
        content: const Text('You will stop hearing about new jobs for this search. You can make it again any time.'),
        actions: [
          TextButton(
            key: const ValueKey('delete-alert-keep'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            key: const ValueKey('delete-alert-confirm'),
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final message = await _c.delete(alert);
    if (!mounted) return;
    showMessage(context, message ?? 'Alert deleted.');
  }

  Future<void> _toggle(JobAlert alert, bool on) async {
    final message = await _c.setEnabled(alert, on);
    if (message != null && mounted) showMessage(context, message);
  }

  Future<void> _frequency(JobAlert alert, String frequency) async {
    final message = await _c.setFrequency(alert, frequency);
    if (message != null && mounted) showMessage(context, message);
  }

  void _openJob(JobAlert alert, Job job) => showJobDetail(
    context,
    job,
    repository: widget.repository.jobs,
    links: widget.links,
    navigation: widget.navigation,
    onChanged: (j) => _c.jobChanged(alert.id, j),
    onApplied: (j) => _c.jobChanged(alert.id, j),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => CareerScaffold(
        title: 'Job alerts',
        onBack: widget.onBack,
        unread: _c.unread,
        onBell: () => widget.navigation.openNotifications(context, widget.links),
        actions: [
          IconButton(
            key: const ValueKey('new-alert'),
            tooltip: 'New alert',
            onPressed: () => _newAlert(),
            icon: const Icon(LucideIcons.circlePlus, size: 22, color: AppColors.primary),
          ),
        ],
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _c.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 32),
            children: _children(),
          ),
        ),
      ),
    );
  }

  List<Widget> _children() {
    if (_c.error != null && !_c.loaded) {
      return [
        CareerNotice(
          key: const ValueKey('alerts-error'),
          icon: LucideIcons.cloudOff,
          title: "Couldn't load your alerts",
          body: _c.error!,
          action: 'Try again',
          onAction: _c.refresh,
        ),
      ];
    }
    if (!_c.loaded) return const [CareerLoading()];
    if (_c.alerts.isEmpty) {
      return [
        CareerNotice(
          key: const ValueKey('alerts-empty'),
          icon: LucideIcons.bellRing,
          title: 'No job alerts yet',
          body: 'Save a search and we will tell you when new jobs match it.',
          action: 'Create an alert',
          onAction: () => _newAlert(),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          _c.totalNew == 0
              ? 'Searches you saved. We tell you when new jobs match.'
              : '${_c.totalNew} new ${_c.totalNew == 1 ? 'job matches' : 'jobs match'} your searches.',
          key: const ValueKey('alerts-lead'),
          style: CareerText.body,
        ),
      ),
      for (final alert in _c.alerts) ...[
        _AlertCard(
          alert: alert,
          matches: _c.openId == alert.id ? _c.matchesOf(alert.id) : null,
          onToggleMatches: () => _c.toggleMatches(alert),
          onEnabled: (on) => _toggle(alert, on),
          onFrequency: (f) => _frequency(alert, f),
          onEdit: () => _edit(alert),
          onDelete: () => _delete(alert),
          onOpenJob: (job) => _openJob(alert, job),
          onSave: (job) async {
            final message = await _c.toggleSave(alert.id, job);
            if (message != null && mounted) showMessage(context, message);
          },
          onMore: () => _c.loadMoreMatches(alert),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.matches,
    required this.onToggleMatches,
    required this.onEnabled,
    required this.onFrequency,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenJob,
    required this.onSave,
    required this.onMore,
  });

  final JobAlert alert;

  /// The open alert's matches; null while it is closed.
  final AlertMatches? matches;
  final VoidCallback onToggleMatches;
  final ValueChanged<bool> onEnabled;
  final ValueChanged<String> onFrequency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(Job job) onOpenJob;
  final void Function(Job job) onSave;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final words = criteriaWords(alert.criteria, money: formatMoneyShort);
    final open = matches != null;
    final isNew = alert.newMatches > 0;
    return Container(
      key: ValueKey('alert-${alert.id}'),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(alert.name, style: CareerText.cardTitle.copyWith(fontSize: 14), maxLines: 2),
                      ),
                      if (isNew) ...[
                        const SizedBox(width: 8),
                        PillBadge('${alert.newMatches} new', color: AppColors.primary),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  key: ValueKey('alert-menu-${alert.id}'),
                  tooltip: 'More for ${alert.name}',
                  icon: const Icon(LucideIcons.ellipsisVertical, size: 18, color: AppColors.onSurfaceVariant),
                  onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit search')),
                    PopupMenuItem(value: 'delete', child: Text('Delete alert')),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: words.isEmpty
                ? Text('Every open job', style: CareerText.meta)
                : Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (final w in words)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(w, style: CareerText.metaStrong),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    alert.alertsEnabled
                        ? (alert.frequency == 'WEEKLY' ? 'Telling you weekly' : 'Telling you daily')
                        : 'Alerts are off',
                    key: ValueKey('alert-state-${alert.id}'),
                    style: CareerText.meta,
                  ),
                ),
                Switch(
                  key: ValueKey('alert-switch-${alert.id}'),
                  value: alert.alertsEnabled,
                  onChanged: onEnabled,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                for (final f in const [('DAILY', 'Daily'), ('WEEKLY', 'Weekly')]) ...[
                  IcrChip(
                    key: ValueKey('alert-${f.$1.toLowerCase()}-${alert.id}'),
                    label: f.$2,
                    height: 26,
                    tone: alert.frequency == f.$1 ? ChipTone.primary : ChipTone.outlined,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: JobsText.filterChip,
                    onTap: alert.alertsEnabled && alert.frequency != f.$1 ? () => onFrequency(f.$1) : null,
                  ),
                  const SizedBox(width: 5),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinePillButton(
                key: ValueKey('alert-matches-${alert.id}'),
                label: open ? 'Hide matches' : (isNew ? 'See ${alert.newMatches} new' : 'See matches'),
                height: 30,
                onPressed: onToggleMatches,
              ),
            ),
          ),
          if (open) ..._matchRows(matches!),
        ],
      ),
    );
  }

  List<Widget> _matchRows(AlertMatches m) {
    if (m.loading) return const [Padding(padding: EdgeInsets.only(bottom: 14), child: CareerLoading())];
    if (m.error != null) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Text(
            m.error!,
            key: const ValueKey('matches-error'),
            style: CareerText.body.copyWith(color: AppColors.error),
          ),
        ),
      ];
    }
    if (m.jobs.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Text(
            'Nothing open matches this search right now.',
            key: const ValueKey('matches-empty'),
            style: CareerText.body,
          ),
        ),
      ];
    }
    return [
      const Hairline(color: AppColors.cardRule),
      for (final (i, job) in m.jobs.indexed) ...[
        if (i > 0) const Hairline(indent: 10, endIndent: 10.5),
        JobRow(
          key: ValueKey('match-${alert.id}-${job.id}'),
          job: job,
          onTap: () => onOpenJob(job),
          onSave: () => onSave(job),
        ),
      ],
      if (m.hasMore) ViewMoreRow(loading: m.loadingMore, onTap: onMore),
    ];
  }
}

// --- the form -------------------------------------------------------------------

/// The "New alert" / "Edit search" form. [onSave] returns null when saved, else the
/// API's sentence, which the form shows without losing what was typed. Resolves true once saved.
Future<bool?> showAlertForm(
  BuildContext context, {
  JobAlert? alert,
  AlertCriteria? criteria,
  required Future<String?> Function(AlertDraft draft) onSave,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
    builder: (_) => AlertForm(alert: alert, criteria: criteria, onSave: onSave),
  );
}

class AlertForm extends StatefulWidget {
  const AlertForm({super.key, this.alert, this.criteria, required this.onSave});

  /// The search being edited; null makes a new one.
  final JobAlert? alert;

  /// The filters a new search starts from.
  final AlertCriteria? criteria;
  final Future<String?> Function(AlertDraft draft) onSave;

  @override
  State<AlertForm> createState() => _AlertFormState();
}

class _AlertFormState extends State<AlertForm> {
  late final AlertCriteria _start = widget.alert != null
      ? AlertCriteria.fromMap(widget.alert!.criteria)
      : (widget.criteria ?? const AlertCriteria());
  late final _name = TextEditingController(text: widget.alert?.name ?? (_start.isEmpty ? '' : _start.suggestedName()));
  late final _search = TextEditingController(text: _start.search);
  late final _cities = TextEditingController(text: _start.cities.join(', '));
  late final _salary = TextEditingController(text: _start.salaryMin == null ? '' : '${_start.salaryMin!.round()}');
  late final Set<WorkMode> _modes = {..._start.workModes};
  late final Set<EmploymentType> _types = {..._start.employmentTypes};
  late bool _enabled = widget.alert?.alertsEnabled ?? true;
  late String _frequency = widget.alert?.frequency ?? 'DAILY';
  String? _problem;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _search, _cities, _salary]) {
      c.dispose();
    }
    super.dispose();
  }

  AlertDraft _draft() => AlertDraft(
    name: _name.text,
    alertsEnabled: _enabled,
    frequency: _frequency,
    criteria: AlertCriteria(
      search: _search.text,
      cities: _cities.text.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList(),
      workModes: _modes,
      employmentTypes: _types,
      salaryMin: num.tryParse(_salary.text.trim()),
      postedWithinDays: _start.postedWithinDays,
      other: _start.other,
    ),
  );

  Future<void> _submit() async {
    final draft = _draft();
    final problem = draft.problem;
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    setState(() {
      _saving = true;
      _problem = null;
    });
    final refusal = await widget.onSave(draft);
    if (!mounted) return;
    if (refusal != null) {
      // What was typed stays: only the sentence is new.
      setState(() {
        _saving = false;
        _problem = refusal;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 4),
    child: Text(text, style: JobsText.formLabel),
  );

  Widget _field(
    TextEditingController c, {
    Key? key,
    String? hint,
    int? maxLength,
    TextInputType? keyboard,
    String? prefix,
    List<TextInputFormatter>? formatters,
  }) => TextField(
    key: key,
    controller: c,
    maxLength: maxLength,
    keyboardType: keyboard,
    inputFormatters: formatters,
    style: JobsText.formInput,
    decoration: InputDecoration(
      hintText: hint,
      prefixText: prefix,
      isDense: true,
      counterText: '',
      border: const OutlineInputBorder(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final editing = widget.alert != null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(editing ? 'Edit search' : 'New job alert', style: JobsText.formTitle),
            const SizedBox(height: 4),
            Text('Save a search and we tell you when new jobs match it.', style: JobsText.formHelp),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Name'),
                    _field(
                      _name,
                      key: const ValueKey('alert-name'),
                      hint: 'FM manager, Bengaluru',
                      maxLength: alertNameMax,
                    ),
                    _label('Keywords'),
                    _field(_search, key: const ValueKey('alert-keywords'), hint: 'Job title or skill'),
                    _label('Cities'),
                    _field(_cities, key: const ValueKey('alert-cities'), hint: 'Mumbai, Pune'),
                    _label('Work mode'),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final m in WorkMode.values)
                          FilterChip(
                            key: ValueKey('alert-mode-${m.name}'),
                            label: Text(m.label),
                            selected: _modes.contains(m),
                            onSelected: (on) => setState(() => on ? _modes.add(m) : _modes.remove(m)),
                          ),
                      ],
                    ),
                    _label('Job type'),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in const [
                          EmploymentType.fullTime,
                          EmploymentType.partTime,
                          EmploymentType.contract,
                          EmploymentType.internship,
                        ])
                          FilterChip(
                            key: ValueKey('alert-type-${t.name}'),
                            label: Text(t.label),
                            selected: _types.contains(t),
                            onSelected: (on) => setState(() => on ? _types.add(t) : _types.remove(t)),
                          ),
                      ],
                    ),
                    _label('Minimum salary (a year, in rupees)'),
                    _field(
                      _salary,
                      key: const ValueKey('alert-salary'),
                      keyboard: TextInputType.number,
                      prefix: '₹ ',
                      formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      key: const ValueKey('alert-enabled'),
                      contentPadding: EdgeInsets.zero,
                      title: Text('Tell me when new jobs match', style: JobsText.formLabel),
                      value: _enabled,
                      onChanged: (v) => setState(() => _enabled = v),
                    ),
                    if (_enabled)
                      Row(
                        children: [
                          for (final f in const [('DAILY', 'Daily'), ('WEEKLY', 'Weekly')]) ...[
                            ChoiceChip(
                              key: ValueKey('alert-form-${f.$1.toLowerCase()}'),
                              label: Text(f.$2),
                              selected: _frequency == f.$1,
                              onSelected: (_) => setState(() => _frequency = f.$1),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),
            if (_problem != null) FormProblem(_problem!),
            const SizedBox(height: 12),
            PrimaryButton(
              key: const ValueKey('alert-save'),
              label: _saving ? 'Saving…' : (editing ? 'Save changes' : 'Save alert'),
              icon: LucideIcons.bellRing,
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
