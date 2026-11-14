import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../account/widgets/account_kit.dart';
import 'project_models.dart';

/// Sends the form; null when it went, else the API's sentence.
typedef SendProject = Future<String?> Function(ProjectDraft draft);

/// The website's "New sourcing project" dialog as a sheet, and the same form over an existing [project] for an edit.
/// True when created or saved.
Future<bool> showProjectSheet(
  BuildContext context, {
  Project? project,
  required Future<List<ProjectJobOption>> Function() jobs,
  required SendProject send,
}) async =>
    await showEditSheet<bool>(
      context,
      builder: (_) => ProjectSheet(project: project, jobs: jobs, send: send),
    ) ??
    false;

/// The form: project name, description, visibility, the job it sources for, then the ideal candidate (job titles,
/// skills, locations as comma-separated lists, minimum years) — the website's fields, in its order.
class ProjectSheet extends StatefulWidget {
  const ProjectSheet({super.key, this.project, required this.jobs, required this.send});

  /// The project being edited; null for a new one.
  final Project? project;

  /// The company's jobs for "Sourcing for a job"; a read that fails leaves only "Not tied to a job".
  final Future<List<ProjectJobOption>> Function() jobs;
  final SendProject send;

  @override
  State<ProjectSheet> createState() => _ProjectSheetState();
}

class _ProjectSheetState extends State<ProjectSheet> {
  late final _name = TextEditingController(text: widget.project?.name ?? '');
  late final _description = TextEditingController(text: widget.project?.description ?? '');
  late final _titles = TextEditingController(text: widget.project?.titles.join(', ') ?? '');
  late final _skills = TextEditingController(text: widget.project?.skills.join(', ') ?? '');
  late final _locations = TextEditingController(text: widget.project?.locations.join(', ') ?? '');
  late final _minYears = TextEditingController(text: widget.project?.minYears?.toString() ?? '');
  late String _visibility = widget.project?.visibility ?? 'TEAM';
  late String? _jobId = widget.project?.jobId;
  late String? _jobTitle = widget.project?.jobTitle;

  List<ProjectJobOption> _jobs = const [];
  bool _jobsLoading = true;
  bool _sending = false;
  String? _error;

  /// The website's "Not tied to a job" option.
  static const _noJob = ProjectJobOption(id: '', title: 'Not Linked to a Job');

  bool get _editing => widget.project != null;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _description, _titles, _skills, _locations, _minYears]) {
      c.addListener(_changed);
    }
    widget
        .jobs()
        .then((rows) {
          if (!mounted) return;
          setState(() {
            _jobs = rows;
            _jobsLoading = false;
          });
        })
        .catchError((Object _) {
          if (mounted) setState(() => _jobsLoading = false);
        });
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _titles, _skills, _locations, _minYears]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() {});

  ProjectDraft get _draft => ProjectDraft(
    name: _name.text,
    description: _description.text,
    visibility: _visibility,
    jobId: _jobId,
    titles: ProjectDraft.csv(_titles.text),
    skills: ProjectDraft.csv(_skills.text),
    locations: ProjectDraft.csv(_locations.text),
    minYears: _minYears.text.trim().isEmpty ? null : int.tryParse(_minYears.text.trim()),
  );

  bool get _dirty {
    final p = widget.project;
    if (p == null) {
      return _name.text.trim().isNotEmpty ||
          _description.text.trim().isNotEmpty ||
          _visibility != 'TEAM' ||
          (_jobId ?? '').isNotEmpty ||
          _titles.text.trim().isNotEmpty ||
          _skills.text.trim().isNotEmpty ||
          _locations.text.trim().isNotEmpty ||
          _minYears.text.trim().isNotEmpty;
    }
    return _draft.changesFrom(p).isNotEmpty;
  }

  /// The website's Create is disabled until the name is typed; Save, until something changed.
  bool get _canSend => _name.text.trim().isNotEmpty && !_sending && (!_editing || _dirty);

  Future<void> _send() async {
    if (!_canSend) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final failure = await widget.send(_draft);
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    // The form keeps what was typed.
    setState(() {
      _sending = false;
      _error = failure.isEmpty ? (_editing ? 'Unable to save the project.' : 'Unable to create the project.') : failure;
    });
  }

  Future<void> _pickVisibility() async {
    final picked = await showAccountPicker<String>(
      context,
      title: 'Visibility',
      items: projectVisibilities,
      labelOf: projectVisibilityLabel,
      selected: _visibility,
    );
    if (picked != null && mounted) setState(() => _visibility = picked);
  }

  Future<void> _pickJob() async {
    final current = _jobs.where((j) => j.id == _jobId).firstOrNull ?? _noJob;
    final picked = await showAccountPicker<ProjectJobOption>(
      context,
      title: 'Sourcing for a Job',
      items: [_noJob, ..._jobs],
      labelOf: (j) => j.title,
      selected: current,
      searchable: _jobs.length > 8,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _jobId = picked.id.isEmpty ? null : picked.id;
      _jobTitle = picked.id.isEmpty ? null : picked.title;
    });
  }

  @override
  Widget build(BuildContext context) {
    final jobValue = (_jobId ?? '').isEmpty
        ? null
        : (_jobs.where((j) => j.id == _jobId).firstOrNull?.title ?? _jobTitle ?? _jobId);
    return EditSheet(
      title: _editing ? 'Edit Project' : 'New Sourcing Project',
      saveLabel: _editing ? 'Save' : 'Create',
      saving: _sending,
      error: _error,
      dirty: _dirty,
      onSave: _canSend ? _send : null,
      children: [
        AccountField(
          label: 'Project Name',
          controller: _name,
          fieldKey: const Key('project.name'),
          hint: 'Regional FM Managers, West',
          maxLength: 120,
          textCapitalization: TextCapitalization.words,
          required: true,
        ),
        AccountField(
          label: 'Description (Optional)',
          controller: _description,
          fieldKey: const Key('project.description'),
          maxLength: 2000,
          maxLines: 4,
          minLines: 2,
        ),
        AccountSelectField(
          key: const Key('project.visibility'),
          label: 'Visibility',
          hint: 'Select',
          value: projectVisibilityLabel(_visibility),
          onTap: _sending ? null : _pickVisibility,
        ),
        AccountSelectField(
          key: const Key('project.job'),
          label: 'Sourcing for a Job (Optional)',
          hint: _jobsLoading ? 'Loading your jobs…' : 'Not Linked to a Job',
          value: jobValue,
          onTap: _sending || _jobsLoading ? null : _pickJob,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 10),
          child: Text('IDEAL CANDIDATE', style: AccountText.meta.copyWith(letterSpacing: 0.8)),
        ),
        AccountField(
          label: 'Job Titles',
          controller: _titles,
          fieldKey: const Key('project.titles'),
          hint: 'Facility Manager, Transactions',
          helper: 'Separate with commas.',
          textCapitalization: TextCapitalization.words,
        ),
        AccountField(
          label: 'Skills',
          controller: _skills,
          fieldKey: const Key('project.skills'),
          hint: 'FM, Lease admin',
          textCapitalization: TextCapitalization.words,
        ),
        AccountField(
          label: 'Locations',
          controller: _locations,
          fieldKey: const Key('project.locations'),
          hint: 'Mumbai, Pune',
          textCapitalization: TextCapitalization.words,
        ),
        _NumberField(label: 'Minimum Years', controller: _minYears, fieldKey: const Key('project.minYears')),
      ],
    );
  }
}

/// A whole-number field (the website's `type="number"`).
class _NumberField extends StatelessWidget {
  const _NumberField({required this.label, required this.controller, required this.fieldKey});

  final String label;
  final TextEditingController controller;
  final Key fieldKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: AccountText.label),
          const SizedBox(height: 6),
          TextField(
            key: fieldKey,
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
            style: AccountText.input,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.slate300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
