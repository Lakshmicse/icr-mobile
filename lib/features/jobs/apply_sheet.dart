import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/widgets/buttons.dart';
import '../../core/widgets/chips.dart';
import 'apply_rules.dart';
import 'job_detail_controller.dart';
import 'job_links.dart';
import 'job_models.dart';
import 'jobs_styles.dart';
import 'screening.dart';

/// The cover note's cap (`COVER_NOTE_MAX_CHARS`).
const coverNoteMax = 2000;

/// The most an expected salary may be (`ApplyDto.expectedSalary`).
const expectedSalaryMax = 1000000000;

/// Easy Apply, as the website's apply dialog: a mobile number if the member
/// has none on file, the résumé to send, the employer's screening questions,
/// the expected salary, an optional note, then `POST /jobs/:id/apply`. A job
/// that takes applications on the employer's own site opens that site instead.
Future<void> startApplication(BuildContext context, JobDetailController controller) async {
  final job = controller.job;
  if (job.externalApply) {
    final site = Uri.tryParse(job.applyUrl!);
    if (site != null) await controller.links.openUri(context, site);
    return;
  }
  final setup = await controller.applyContext();
  if (!context.mounted) return;
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
    builder: (_) =>
        ApplyForm(controller: controller, needsPhone: setup.needsPhone, resumes: setup.resumes, quota: setup.quota),
  );
  if (sent == true && context.mounted) showMessage(context, 'Application sent to ${job.company.name}.');
}

class ApplyForm extends StatefulWidget {
  const ApplyForm({super.key, required this.controller, required this.needsPhone, this.resumes = const [], this.quota});

  final JobDetailController controller;
  final bool needsPhone;
  final List<ResumeChoice> resumes;
  final SeekerQuota? quota;

  @override
  State<ApplyForm> createState() => _ApplyFormState();
}

class _ApplyFormState extends State<ApplyForm> {
  final _phone = TextEditingController();
  final _note = TextEditingController();
  final _salary = TextEditingController();
  final _linkedin = TextEditingController();
  final Set<String> _declared = {};
  String? _gender;
  final Map<String, TextEditingController> _texts = {};
  final Map<String, String> _answers = {};
  final Set<String> _touched = {};
  String? _problem;
  bool _sending = false;

  /// Shows every question's problem once the member tried to send.
  bool _tried = false;

  /// Asks for the number: the profile has none, or the API said it needs one.
  late var _askPhone = widget.needsPhone;

  /// The default résumé is chosen to begin with, as the website's.
  late String? _resumeId = widget.resumes.isEmpty
      ? null
      : widget.resumes.firstWhere((r) => r.isDefault, orElse: () => widget.resumes.first).id;

  List<ScreeningQuestion> get _questions => widget.controller.job.screening;

  @override
  void dispose() {
    _phone.dispose();
    _note.dispose();
    _salary.dispose();
    _linkedin.dispose();
    for (final c in _texts.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _answer(ScreeningQuestion q, String value) => setState(() {
    _answers[q.id] = value;
    _touched.add(q.id);
  });

  String? _problemOf(ScreeningQuestion q) =>
      _tried || _touched.contains(q.id) ? screeningAnswerProblem(q, _answers[q.id]) : null;

  Future<void> _submit() async {
    setState(() => _tried = true);
    if (_askPhone && _phone.text.trim().length < 8) {
      setState(() => _problem = 'Add the mobile number the employer can reach you on.');
      return;
    }
    final unanswered = _questions.where((q) => screeningAnswerProblem(q, _answers[q.id]) != null).length;
    if (unanswered > 0) {
      setState(
        () => _problem = unanswered == 1
            ? 'Answer the question above in the format it asks for.'
            : 'Answer the $unanswered questions above in the format they ask for.',
      );
      return;
    }
    final job = widget.controller.job;
    if (job.diversityOnly && job.diversityCategories.isNotEmpty && _declared.isEmpty) {
      setState(() => _problem = 'Choose the group that applies to you, or this role cannot take your application.');
      return;
    }
    if (genderRequiredBy(job.genderPreference) != null && _gender == null) {
      setState(() => _problem = 'Choose your gender: this role is open to one gender only.');
      return;
    }
    final linkedin = linkedinProblem(_linkedin.text);
    if (linkedin != null) {
      setState(() => _problem = linkedin);
      return;
    }
    final salaryText = _salary.text.trim();
    final salary = salaryText.isEmpty ? null : num.tryParse(salaryText);
    if (salaryText.isNotEmpty && (salary == null || salary < 0 || salary > expectedSalaryMax)) {
      setState(() => _problem = 'Enter your expected salary as a yearly amount in rupees.');
      return;
    }
    setState(() {
      _sending = true;
      _problem = null;
    });
    final result = await widget.controller.apply(
      phone: _phone.text,
      coverNote: _note.text,
      resumeId: _resumeId,
      expectedSalary: salary,
      answers: _questions.isEmpty ? null : {for (final q in _questions) q.id: _answers[q.id] ?? ''},
      linkedinUrl: _linkedin.text,
      diversityIdentities: _declared.isEmpty ? null : _declared.toList(),
      gender: _gender,
    );
    if (!mounted) return;
    if (!result.ok) {
      // What the member typed stays: only the sentence and, when the number is
      // what was missing, the field for it are new.
      setState(() {
        _sending = false;
        _problem = result.message;
        if (result.needsPhone) _askPhone = true;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.controller.job;
    final quota = widget.quota;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Apply to ${job.title}', style: JobsText.formTitle),
              const SizedBox(height: 4),
              Text('${job.company.name}${job.place == null ? '' : ' • ${job.place}'}', style: JobsText.formHelp),
              if (quota?.limit != null) ...[
                const SizedBox(height: 12),
                QuotaNotice(quota: quota!, onPlans: () => widget.controller.links.openSite(context, '/career/plans')),
              ],
              const SizedBox(height: 16),
              if (_askPhone) ...[
                Text('Mobile number', style: JobsText.formLabel),
                const SizedBox(height: 4),
                TextField(
                  key: const ValueKey('apply-phone'),
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  maxLength: 30,
                  style: JobsText.formInput,
                  decoration: const InputDecoration(
                    hintText: '+91 98765 43210',
                    isDense: true,
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 4),
                Text('The employer needs a way to reach you. It is saved to your profile.', style: JobsText.formHelp),
                const SizedBox(height: 14),
              ],
              if (widget.resumes.isNotEmpty) ...[
                Text('Résumé to send', style: JobsText.formLabel),
                const SizedBox(height: 2),
                for (final r in widget.resumes)
                  ResumeOption(
                    key: ValueKey('resume-${r.id}'),
                    resume: r,
                    selected: _resumeId == r.id,
                    onTap: () => setState(() => _resumeId = r.id),
                  ),
                const SizedBox(height: 10),
              ] else ...[
                Text(
                  job.requireResume
                      ? 'This employer asks for a résumé. Add one to your ICR profile first.'
                      : 'Your ICR profile goes with the application.',
                  style: JobsText.formHelp,
                ),
                const SizedBox(height: 14),
              ],
              if (_questions.isNotEmpty) ...[
                Text('The employer asks', style: JobsText.formLabel),
                const SizedBox(height: 8),
                for (final (i, q) in _questions.indexed) ...[
                  ScreeningAnswerField(
                    key: ValueKey('screening-${q.id}'),
                    question: q,
                    index: i,
                    value: _answers[q.id] ?? '',
                    problem: _problemOf(q),
                    textController: q.type == ScreeningType.text || q.type == ScreeningType.numeric
                        ? _texts.putIfAbsent(q.id, TextEditingController.new)
                        : null,
                    onChanged: (v) => _answer(q, v),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
              if (job.diversityOnly && job.diversityCategories.isNotEmpty) ...[
                Text(
                  'This role accepts applications only from ${diversityAudienceSentence(job.diversityCategories)}.',
                  key: const ValueKey('apply-diversity-note'),
                  style: JobsText.formLabel,
                ),
                const SizedBox(height: 2),
                Text(
                  'Tell the employer which applies to you. It is saved to your profile and stays private to the hiring team.',
                  style: JobsText.formHelp,
                ),
                for (final c in job.diversityCategories)
                  CheckboxListTile(
                    key: ValueKey('apply-diversity-$c'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(diversityLabels[c] ?? c, style: JobsText.formInput.copyWith(fontSize: 14)),
                    value: _declared.contains(c),
                    onChanged: (on) => setState(() => on == true ? _declared.add(c) : _declared.remove(c)),
                  ),
                const SizedBox(height: 10),
              ],
              if (genderRequiredBy(job.genderPreference) != null) ...[
                Text(
                  genderOnlySentence(job.genderPreference)!,
                  key: const ValueKey('apply-gender-note'),
                  style: JobsText.formLabel,
                ),
                const SizedBox(height: 2),
                Text(
                  'Your gender is private. It is kept with your profile once you give it.',
                  style: JobsText.formHelp,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (value, label) in genderChoices)
                      IcrChip(
                        key: ValueKey('apply-gender-$value'),
                        label: label,
                        tone: _gender == value ? ChipTone.primary : ChipTone.outlined,
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        textStyle: JobsText.filterChip,
                        onTap: () => setState(() => _gender = value),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              Text('Your LinkedIn profile (optional)', style: JobsText.formLabel),
              const SizedBox(height: 4),
              TextField(
                key: const ValueKey('apply-linkedin'),
                controller: _linkedin,
                keyboardType: TextInputType.url,
                autocorrect: false,
                style: JobsText.formInput,
                decoration: const InputDecoration(
                  hintText: 'linkedin.com/in/your-name',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              Text('Expected salary (optional)', style: JobsText.formLabel),
              const SizedBox(height: 4),
              TextField(
                key: const ValueKey('apply-salary'),
                controller: _salary,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                style: JobsText.formInput,
                decoration: const InputDecoration(
                  hintText: 'Yearly, in rupees',
                  prefixText: '₹ ',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              Text('A note to the hiring team (optional)', style: JobsText.formLabel),
              const SizedBox(height: 4),
              TextField(
                key: const ValueKey('apply-note'),
                controller: _note,
                minLines: 3,
                maxLines: 6,
                maxLength: coverNoteMax,
                style: JobsText.formInput,
                decoration: const InputDecoration(
                  hintText: 'Why this role suits you',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              if (_problem != null) ...[
                const SizedBox(height: 8),
                Text(_problem!, style: JobsText.formHelp.copyWith(color: AppColors.error)),
              ],
              const SizedBox(height: 16),
              PrimaryButton(
                label: _sending ? 'Sending…' : 'Submit application',
                icon: LucideIcons.zap,
                onPressed: _sending ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "7 of 10 applications left this month", with the way to more.
class QuotaNotice extends StatelessWidget {
  const QuotaNotice({super.key, required this.quota, required this.onPlans});

  final SeekerQuota quota;
  final VoidCallback onPlans;

  @override
  Widget build(BuildContext context) {
    final out = !quota.canApply || quota.left == 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: out ? AppColors.amber50 : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(out ? LucideIcons.triangleAlert : LucideIcons.info, size: 16, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              out
                  ? "You've used all ${quota.limit} applications on your plan this month."
                  : '${quota.left} of ${quota.limit} applications left this month.',
              style: JobsText.formHelp.copyWith(color: AppColors.onSurface),
            ),
          ),
          TextButton(
            onPressed: onPlans,
            child: Text('See plans', style: AppText.link.copyWith(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// One résumé to choose: a radio, its kind, its title, "Default".
class ResumeOption extends StatelessWidget {
  const ResumeOption({super.key, required this.resume, required this.selected, required this.onTap});

  final ResumeChoice resume;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? AppColors.primary : AppColors.outline,
              ),
              const SizedBox(width: 10),
              Icon(
                resume.hasFile ? LucideIcons.fileText : LucideIcons.idCard,
                size: 16,
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  resume.title,
                  style: JobsText.formInput.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (resume.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(6)),
                  child: Text('Default', style: AppText.badgeCount.copyWith(color: AppColors.onSurfaceVariant)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One screening question as the input its answer type asks for, so the
/// member can only answer in that format, with the shared rule's reason under it.
class ScreeningAnswerField extends StatelessWidget {
  const ScreeningAnswerField({
    super.key,
    required this.question,
    required this.index,
    required this.value,
    required this.onChanged,
    this.problem,
    this.textController,
  });

  final ScreeningQuestion question;
  final int index;
  final String value;
  final ValueChanged<String> onChanged;
  final String? problem;

  /// For the typed answers (text, a number).
  final TextEditingController? textController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${index + 1}. ${question.prompt}', style: JobsText.formInput.copyWith(fontSize: 14)),
        const SizedBox(height: 6),
        _input(context),
        if (problem != null) ...[
          const SizedBox(height: 4),
          Text(problem!, style: JobsText.formHelp.copyWith(color: AppColors.error)),
        ],
      ],
    );
  }

  Widget _choice(String label, bool selected, VoidCallback onTap) => IcrChip(
    label: label,
    tone: selected ? ChipTone.primary : ChipTone.outlined,
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    textStyle: JobsText.filterChip,
    onTap: onTap,
  );

  Widget _input(BuildContext context) {
    final q = question;
    switch (q.type) {
      case ScreeningType.yesNo:
        return Wrap(
          spacing: 8,
          children: [
            _choice('Yes', value == 'true', () => onChanged('true')),
            _choice('No', value == 'false', () => onChanged('false')),
          ],
        );
      case ScreeningType.singleSelect:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final o in q.options) _choice(o, value == o, () => onChanged(o))],
        );
      case ScreeningType.multiSelect:
        final picked = value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in q.options)
              _choice(o, picked.contains(o), () {
                final next = picked.contains(o) ? (picked..remove(o)) : [...picked, o];
                onChanged(next.join(','));
              }),
          ],
        );
      case ScreeningType.rating:
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (var n = 1; n <= q.ratingMax; n++) _choice('$n', value == '$n', () => onChanged('$n'))],
        );
      case ScreeningType.years:
        return DropdownButtonFormField<String>(
          initialValue: value.isEmpty ? null : value,
          isDense: true,
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), hintText: 'Choose'),
          items: [
            for (var n = 0; n <= screeningYearsMax; n++)
              DropdownMenuItem(
                value: '$n',
                child: Text(
                  n == 0 ? 'Less than a year' : '${yearsChoiceLabel(n)} ${n == 1 ? 'year' : 'years'}',
                  style: JobsText.formInput.copyWith(fontSize: 14),
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        );
      case ScreeningType.date:
        return OutlinedButton.icon(
          icon: const Icon(LucideIcons.calendar, size: 16),
          label: Text(value.isEmpty ? 'Pick a date' : value, style: JobsText.formInput.copyWith(fontSize: 14)),
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.tryParse(value) ?? now,
              firstDate: DateTime(now.year - 60),
              lastDate: DateTime(now.year + 10),
            );
            if (picked != null) onChanged(isoDay(picked));
          },
        );
      case ScreeningType.numeric:
        return TextField(
          controller: textController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: JobsText.formInput,
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), hintText: '0'),
          onChanged: onChanged,
        );
      case ScreeningType.text:
        return TextField(
          controller: textController,
          minLines: 2,
          maxLines: 5,
          maxLength: screeningTextMax,
          style: JobsText.formInput,
          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
          onChanged: onChanged,
        );
    }
  }
}

/// yyyy-mm-dd, the day as the API reads a date answer.
String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
