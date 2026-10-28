import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../mentorship_my/mentoring_format.dart';
import '../mentorship_my/widgets/forms.dart';
import '../mentorship_my/widgets/kit.dart';
import 'become_mentor_models.dart';
import 'become_mentor_rules.dart';
import 'become_mentor_widgets.dart';

/// Chooses a file on the phone; null when the person backs out. A screen takes one of these in its constructor so a
/// test can hand a file in without a platform picker.
typedef FilePick = Future<PickedFile?> Function();

/// The most a photo may weigh (the website's uploader: 5 MB) and a piece of evidence (10 MB).
const maxPhotoBytes = 5 * 1024 * 1024;
const maxEvidenceBytes = 10 * 1024 * 1024;

/// The phone's own picture chooser (`file_picker`: the system photo picker on Android and iOS).
Future<PickedFile?> pickPhotoFromDevice() async {
  final file = await FilePicker.pickFile(type: FileType.image);
  if (file == null) return null;
  return PickedFile(bytes: await file.readAsBytes(), name: file.name);
}

/// A PDF or a picture of a certificate, a letter, a proof of employment.
Future<PickedFile?> pickEvidenceFromDevice() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
  );
  if (file == null) return null;
  return PickedFile(bytes: await file.readAsBytes(), name: file.name);
}

/// The sentence for a file that is too heavy, or null when it is fine.
String? fileProblem(PickedFile f, {required int max}) =>
    f.bytes.length <= max ? null : 'That file is too big. Choose one under ${max ~/ (1024 * 1024)} MB.';

// ---------------------------------------------------------------------------
// The photo
// ---------------------------------------------------------------------------

/// The profile photo: a clear photo of the face is the first thing a mentee sees. Choosing one uploads it and
/// saves it as the member's photo; a mentor card cannot be submitted without one.
class PhotoSheet extends StatefulWidget {
  const PhotoSheet({
    super.key,
    required this.hasPhoto,
    required this.pick,
    required this.onUpload,
    required this.onRemove,
    this.name = '',
  });

  final bool hasPhoto;
  final String name;
  final FilePick pick;
  final Future<String?> Function(PickedFile file) onUpload;
  final Future<String?> Function() onRemove;

  @override
  State<PhotoSheet> createState() => _PhotoSheetState();
}

class _PhotoSheetState extends State<PhotoSheet> with SheetState<PhotoSheet> {
  Future<void> _choose() async {
    final file = await widget.pick();
    if (file == null || !mounted) return;
    final bad = fileProblem(file, max: maxPhotoBytes);
    if (bad != null) {
      setState(() => problem = bad);
      return;
    }
    await send(() => null, () => widget.onUpload(file));
  }

  @override
  Widget build(BuildContext context) {
    return frame(
      title: 'Profile photo',
      subtitle: 'A clear photo of your face. Mentees see it first.',
      submitLabel: widget.hasPhoto ? 'Change photo' : 'Choose a photo',
      onSubmit: busy ? null : _choose,
      children: [
        if (widget.hasPhoto)
          Align(
            alignment: Alignment.centerLeft,
            child: QuietButton(
              label: 'Remove photo',
              danger: true,
              icon: LucideIcons.trash2,
              onPressed: busy ? null : () => send(() => null, widget.onRemove),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The role and the years
// ---------------------------------------------------------------------------

/// The current role and the years in the profession, the person's own (`PATCH /users/me`), shown on the mentor card.
class IntroForm extends StatefulWidget {
  const IntroForm({
    super.key,
    required this.designation,
    required this.years,
    required this.jobTitles,
    required this.onSave,
  });

  final String? designation;
  final int? years;

  /// ICR's list of job titles, offered as suggestions (any text is accepted).
  final List<String> jobTitles;
  final Future<String?> Function(Map<String, dynamic> patch) onSave;

  @override
  State<IntroForm> createState() => _IntroFormState();
}

class _IntroFormState extends State<IntroForm> with SheetState<IntroForm> {
  late final _role = TextEditingController(text: widget.designation ?? '');
  late final _years = TextEditingController(text: widget.years?.toString() ?? '');

  @override
  void dispose() {
    _role.dispose();
    _years.dispose();
    super.dispose();
  }

  String? _check() => designationProblem(_role.text) ?? yearsProblem(_years.text);

  @override
  Widget build(BuildContext context) {
    final typed = _role.text.trim().toLowerCase();
    final suggestions = typed.isEmpty
        ? const <String>[]
        : [
            for (final t in widget.jobTitles)
              if (t.toLowerCase().contains(typed) && t.toLowerCase() != typed) t,
          ].take(5).toList();
    return frame(
      title: 'Your role and experience',
      subtitle: 'Shared with your profile: a change here is reflected there too.',
      submitLabel: 'Save',
      onSubmit: busy
          ? null
          : () => send(
              _check,
              () => widget.onSave({
                // An empty role clears it; blank years clear the years.
                'designation': _role.text.trim(),
                'yearsExperience': _years.text.trim().isEmpty ? null : int.parse(_years.text.trim()),
              }),
            ),
      children: [
        FieldBlock(
          label: 'Current role',
          help: 'Just the job title.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey('intro-role'),
                controller: _role,
                maxLength: MentorLimits.roleMax,
                onChanged: (_) => setState(() {}),
                style: MentoringText.formInput,
                decoration: fieldDecoration('Head of Facilities Strategy').copyWith(counterText: ''),
              ),
              if (suggestions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in suggestions)
                        ActionChip(
                          key: ValueKey('role-suggest-$s'),
                          label: Text(s),
                          onPressed: () => setState(() => _role.text = s),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        FieldBlock(
          label: 'Years in the profession',
          help: 'Whole years, ${MentorLimits.yearsMin}–${MentorLimits.yearsMax}.',
          child: TextField(
            key: const ValueKey('intro-years'),
            controller: _years,
            keyboardType: TextInputType.number,
            style: MentoringText.formInput,
            decoration: fieldDecoration('12'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Languages
// ---------------------------------------------------------------------------

/// The languages a mentor mentors in (at most 8, each at most 40 characters).
class LanguagesForm extends StatefulWidget {
  const LanguagesForm({super.key, required this.languages, required this.onSave});

  final List<String> languages;
  final Future<String?> Function(Map<String, dynamic> patch) onSave;

  @override
  State<LanguagesForm> createState() => _LanguagesFormState();
}

class _LanguagesFormState extends State<LanguagesForm> with SheetState<LanguagesForm> {
  late List<String> _languages = [...widget.languages];

  @override
  Widget build(BuildContext context) {
    final tooMany = _languages.length > MentorLimits.languagesMax
        ? 'Choose at most ${MentorLimits.languagesMax} languages.'
        : null;
    return frame(
      title: 'Languages',
      subtitle: 'The languages you can mentor in. Up to ${MentorLimits.languagesMax}.',
      submitLabel: 'Save',
      onSubmit: busy ? null : () => send(() => tooMany, () => widget.onSave({'languages': _languages})),
      children: [
        FieldBlock(
          label: 'Languages',
          child: TextChipEditor(
            fieldKey: const ValueKey('language-text'),
            items: _languages,
            max: MentorLimits.languagesMax,
            itemMax: MentorLimits.languageMax,
            suggestions: spokenLanguages,
            hint: 'Type a language',
            onChanged: (v) => setState(() => _languages = v),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Career history
// ---------------------------------------------------------------------------

/// One role of the career history: added, or edited. [onSave] gets the finished row; the page saves the whole list.
class ExperienceForm extends StatefulWidget {
  const ExperienceForm({super.key, required this.onSave, this.row, this.onRemove});

  /// The role being edited; null for a new one.
  final ExperienceRow? row;
  final Future<String?> Function(ExperienceRow row) onSave;

  /// Takes this role out of the history (an edit only).
  final Future<String?> Function()? onRemove;

  @override
  State<ExperienceForm> createState() => _ExperienceFormState();
}

class _ExperienceFormState extends State<ExperienceForm> with SheetState<ExperienceForm> {
  late final _title = TextEditingController(text: widget.row?.title ?? '');
  late final _org = TextEditingController(text: widget.row?.organisation ?? '');
  late final _city = TextEditingController(text: widget.row?.city ?? '');
  late final _desc = TextEditingController(text: widget.row?.description ?? '');
  late final _startYear = TextEditingController(text: widget.row?.startYear.toString() ?? '');
  late final _endYear = TextEditingController(text: widget.row?.endYear?.toString() ?? '');
  late int? _startMonth = widget.row?.startMonth;
  late int? _endMonth = widget.row?.endMonth;
  late bool _current = widget.row?.isCurrent ?? true;

  @override
  void dispose() {
    for (final c in [_title, _org, _city, _desc, _startYear, _endYear]) {
      c.dispose();
    }
    super.dispose();
  }

  ExperienceFacts get _facts => ExperienceFacts(
    title: _title.text,
    organisation: _org.text,
    city: _city.text,
    startYear: int.tryParse(_startYear.text.trim()),
    startMonth: _startMonth,
    endYear: int.tryParse(_endYear.text.trim()),
    endMonth: _endMonth,
    isCurrent: _current,
    description: _desc.text,
  );

  Map<ExperienceField, String> _problems() {
    final out = <ExperienceField, String>{};
    for (final p in experienceProblems(_facts)) {
      out.putIfAbsent(p.field, () => p.message);
    }
    return out;
  }

  Widget _month(String keyName, int? value, ValueChanged<int?> onChanged) => DropdownButtonFormField<int?>(
    key: ValueKey(keyName),
    initialValue: value,
    isDense: true,
    decoration: fieldDecoration('Month'),
    items: [
      const DropdownMenuItem<int?>(value: null, child: Text('Month')),
      for (var m = 1; m <= 12; m++)
        DropdownMenuItem<int?>(
          value: m,
          child: Text(
            const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1],
          ),
        ),
    ],
    onChanged: onChanged,
  );

  @override
  Widget build(BuildContext context) {
    final problems = _problems();
    final prior = widget.row;
    return frame(
      title: prior == null ? 'Add a role' : 'Edit this role',
      submitLabel: 'Save role',
      onSubmit: busy
          ? null
          : () => send(
              () => problems.values.firstOrNull,
              () => widget.onSave(
                ExperienceRow(
                  id: prior?.id,
                  title: _title.text,
                  organisation: _org.text,
                  companyId: prior != null && prior.organisation.trim() == _org.text.trim() ? prior.companyId : null,
                  employmentType: prior?.employmentType,
                  city: _city.text,
                  industryKeys: prior?.industryKeys ?? const [],
                  startYear: int.parse(_startYear.text.trim()),
                  startMonth: _startMonth,
                  endYear: _current ? null : int.tryParse(_endYear.text.trim()),
                  endMonth: _current ? null : _endMonth,
                  isCurrent: _current,
                  description: _desc.text,
                ),
              ),
            ),
      children: [
        FieldBlock(
          label: 'Role',
          child: TextField(
            key: const ValueKey('xp-title'),
            controller: _title,
            maxLength: ExperienceLimits.titleMax,
            onChanged: (_) => setState(() {}),
            style: MentoringText.formInput,
            decoration: fieldDecoration('Facility Manager').copyWith(counterText: ''),
          ),
        ),
        FieldBlock(
          label: 'Organisation',
          child: TextField(
            key: const ValueKey('xp-org'),
            controller: _org,
            maxLength: ExperienceLimits.organisationMax,
            onChanged: (_) => setState(() {}),
            style: MentoringText.formInput,
            decoration: fieldDecoration('Prestige Group').copyWith(counterText: ''),
          ),
        ),
        FieldBlock(
          label: 'City (optional)',
          child: TextField(
            key: const ValueKey('xp-city'),
            controller: _city,
            maxLength: ExperienceLimits.cityMax,
            onChanged: (_) => setState(() {}),
            style: MentoringText.formInput,
            decoration: fieldDecoration('Bengaluru').copyWith(counterText: ''),
          ),
        ),
        FieldBlock(
          label: 'Started',
          child: Row(
            children: [
              Expanded(child: _month('xp-start-month', _startMonth, (v) => setState(() => _startMonth = v))),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const ValueKey('xp-start-year'),
                  controller: _startYear,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  style: MentoringText.formInput,
                  decoration: fieldDecoration('Year'),
                ),
              ),
            ],
          ),
        ),
        SwitchListTile.adaptive(
          key: const ValueKey('xp-current'),
          contentPadding: EdgeInsets.zero,
          value: _current,
          onChanged: (v) => setState(() => _current = v),
          title: Text('I work here now', style: MentoringText.formLabel),
        ),
        if (!_current)
          FieldBlock(
            label: 'Ended',
            child: Row(
              children: [
                Expanded(child: _month('xp-end-month', _endMonth, (v) => setState(() => _endMonth = v))),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const ValueKey('xp-end-year'),
                    controller: _endYear,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    style: MentoringText.formInput,
                    decoration: fieldDecoration('Year'),
                  ),
                ),
              ],
            ),
          ),
        FieldBlock(
          label: 'What you did (optional)',
          child: TextField(
            key: const ValueKey('xp-desc'),
            controller: _desc,
            minLines: 2,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            style: MentoringText.formInput,
            decoration: fieldDecoration('Ran facilities for a 2 million sq ft campus'),
          ),
        ),
        if (problems.isNotEmpty)
          for (final m in problems.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(m, style: MentoringText.meta.copyWith(color: AppColors.error)),
            ),
        if (widget.onRemove != null)
          Align(
            alignment: Alignment.centerLeft,
            child: QuietButton(
              label: 'Remove this role',
              danger: true,
              icon: LucideIcons.trash2,
              onPressed: busy ? null : () => send(() => null, widget.onRemove!),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Evidence
// ---------------------------------------------------------------------------

/// Attaches a document as evidence (a certificate, a proof of employment, a reference). The file is uploaded first,
/// then attached; ICR's review team reads it.
class DocumentForm extends StatefulWidget {
  const DocumentForm({super.key, required this.pick, required this.onSave});

  final FilePick pick;
  final Future<String?> Function(PickedFile file, String kind, String? label) onSave;

  @override
  State<DocumentForm> createState() => _DocumentFormState();
}

class _DocumentFormState extends State<DocumentForm> with SheetState<DocumentForm> {
  String _kind = 'CERTIFICATION';
  final _label = TextEditingController();
  PickedFile? _file;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    final f = await widget.pick();
    if (f == null || !mounted) return;
    setState(() {
      _file = f;
      problem = fileProblem(f, max: maxEvidenceBytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    return frame(
      title: 'Add a document',
      subtitle:
          'Evidence for ICR\'s review team: a certificate, proof of where you work, a reference. A PDF or a picture, under 10 MB.',
      submitLabel: 'Attach',
      onSubmit: busy
          ? null
          : () => send(
              () => _file == null ? 'Choose the file to attach.' : fileProblem(_file!, max: maxEvidenceBytes),
              () => widget.onSave(_file!, _kind, _label.text),
            ),
      children: [
        FieldBlock(
          label: 'What it is',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final MapEntry(key: key, value: label) in mentorDocumentKinds.entries)
                ChoiceChip(
                  key: ValueKey('kind-$key'),
                  label: Text(label),
                  selected: _kind == key,
                  onSelected: (_) => setState(() => _kind = key),
                ),
            ],
          ),
        ),
        FieldBlock(
          label: 'A label (optional)',
          child: TextField(
            key: const ValueKey('doc-label'),
            controller: _label,
            maxLength: 200,
            style: MentoringText.formInput,
            decoration: fieldDecoration('CFMP certificate, 2021').copyWith(counterText: ''),
          ),
        ),
        FieldBlock(
          label: 'The file',
          child: Row(
            children: [
              QuietButton(
                key: const ValueKey('doc-choose'),
                label: _file == null ? 'Choose a file' : 'Choose another',
                icon: LucideIcons.paperclip,
                onPressed: busy ? null : _choose,
              ),
              if (_file != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_file!.name} · ${fileSizeLabel(_file!.bytes.length)}',
                    key: const ValueKey('doc-file'),
                    style: MentoringText.meta,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
