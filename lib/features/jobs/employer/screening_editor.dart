import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../career/career_styles.dart';
import '../jobs_styles.dart';
import 'hiring_models.dart';
import 'job_rules.dart';

/// The questions a job asks with an application: listed, edited in a dialog, removed, ordered by the
/// list. Saved with the posting (`PUT /jobs/:id/screening-questions`). A must-have question that an
/// applicant fails marks them unqualified for the hiring team.
class ScreeningEditor extends StatelessWidget {
  const ScreeningEditor({super.key, required this.questions, required this.onChanged});

  final List<ScreeningDraft> questions;
  final ValueChanged<List<ScreeningDraft>> onChanged;

  static String typeLabel(String type) =>
      ScreeningDraft.types.firstWhere((t) => t.$1 == type, orElse: () => (type, type)).$2;

  Future<void> _edit(BuildContext context, {int? index}) async {
    final result = await showDialog<ScreeningDraft>(
      context: context,
      builder: (_) => ScreeningQuestionDialog(initial: index == null ? null : questions[index]),
    );
    if (result == null) return;
    final next = [...questions];
    if (index == null) {
      next.add(result);
    } else {
      next[index] = result;
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('screening-editor'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ask applicants up to ${JobLimits.screeningQuestionsMax} questions. Their answers are graded for you.',
          style: CareerText.body,
        ),
        const SizedBox(height: 8),
        if (questions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('No questions yet.', key: const ValueKey('no-questions'), style: CareerText.meta),
          ),
        for (final (i, q) in questions.indexed)
          Container(
            key: ValueKey('question-$i'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _edit(context, index: i),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. ${q.prompt.isEmpty ? 'Untitled question' : q.prompt}',
                          style: CareerText.bodyStrong,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            typeLabel(q.type),
                            if (q.mustHave) 'Must have',
                            if (q.hasOptions && q.options.isNotEmpty) '${q.options.length} options',
                          ].join(' • '),
                          style: CareerText.meta,
                        ),
                      ],
                    ),
                  ),
                ),
                if (i > 0)
                  IconButton(
                    key: ValueKey('question-up-$i'),
                    tooltip: 'Move up',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final next = [...questions];
                      next.insert(i - 1, next.removeAt(i));
                      onChanged(next);
                    },
                    icon: const Icon(LucideIcons.arrowUp, size: 16),
                  ),
                IconButton(
                  key: ValueKey('question-remove-$i'),
                  tooltip: 'Remove question',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onChanged([...questions]..removeAt(i)),
                  icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.error),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const ValueKey('add-question'),
            onPressed: questions.length >= JobLimits.screeningQuestionsMax ? null : () => _edit(context),
            icon: const Icon(LucideIcons.plus, size: 15),
            label: const Text('Add a question'),
          ),
        ),
      ],
    );
  }
}

/// One question's form: its kind, the words, the options, the answer that passes, and whether it must pass.
class ScreeningQuestionDialog extends StatefulWidget {
  const ScreeningQuestionDialog({super.key, this.initial});

  final ScreeningDraft? initial;

  @override
  State<ScreeningQuestionDialog> createState() => _ScreeningQuestionDialogState();
}

class _ScreeningQuestionDialogState extends State<ScreeningQuestionDialog> {
  late String _type = widget.initial?.type ?? 'YES_NO';
  late final _prompt = TextEditingController(text: widget.initial?.prompt ?? '');
  late final _options = TextEditingController(text: (widget.initial?.options ?? const []).join('\n'));
  late final _ideal = TextEditingController(text: widget.initial?.idealAnswer ?? '');
  late bool _must = widget.initial?.mustHave ?? false;
  late int _scale = widget.initial?.scaleMax == 10 ? 10 : 5;
  String? _problem;

  @override
  void dispose() {
    _prompt.dispose();
    _options.dispose();
    _ideal.dispose();
    super.dispose();
  }

  ScreeningDraft _draft() => ScreeningDraft(
    id: widget.initial?.id,
    type: _type,
    prompt: _prompt.text,
    options: _options.text.split('\n').map((o) => o.trim()).where((o) => o.isNotEmpty).toList(),
    scaleMax: _type == 'RATING' ? _scale : null,
    idealAnswer: _ideal.text.trim().isEmpty ? null : _ideal.text.trim(),
    mustHave: _must,
  );

  void _save() {
    final d = _draft();
    final problem = d.problem;
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.pop(context, d);
  }

  /// What the ideal answer box asks for.
  String? get _idealHint => switch (_type) {
    'YES_NO' => 'The answer that passes: true or false',
    'YEARS' => 'The fewest years that pass (0 to 15)',
    'NUMERIC' => 'The smallest number that passes',
    'RATING' => 'The lowest rating that passes',
    'SINGLE_SELECT' => 'The option that passes (exactly as written)',
    'DATE' => 'The latest date that passes (yyyy-mm-dd)',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('question-dialog'),
      title: Text(widget.initial == null ? 'Add a question' : 'Edit question'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (v, label) in ScreeningDraft.types)
                  ChoiceChip(
                    key: ValueKey('qtype-$v'),
                    label: Text(label),
                    selected: _type == v,
                    onSelected: (_) => setState(() => _type = v),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('question-prompt'),
              controller: _prompt,
              minLines: 2,
              maxLines: 4,
              maxLength: JobLimits.screeningPromptMax,
              style: JobsText.formInput,
              decoration: const InputDecoration(
                hintText: 'How many years of hard-services FM experience do you have?',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (_type == 'SINGLE_SELECT' || _type == 'MULTI_SELECT') ...[
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('question-options'),
                controller: _options,
                minLines: 3,
                maxLines: 8,
                style: JobsText.formInput,
                decoration: const InputDecoration(
                  hintText: 'One option on each line',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_type == 'RATING') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final n in const [5, 10]) ...[
                    ChoiceChip(
                      key: ValueKey('scale-$n'),
                      label: Text('1 to $n'),
                      selected: _scale == n,
                      onSelected: (_) => setState(() => _scale = n),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ],
            if (_idealHint != null) ...[
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('question-ideal'),
                controller: _ideal,
                style: JobsText.formInput,
                decoration: InputDecoration(hintText: _idealHint, isDense: true, border: const OutlineInputBorder()),
              ),
            ],
            SwitchListTile(
              key: const ValueKey('question-must'),
              contentPadding: EdgeInsets.zero,
              title: Text('Must have', style: JobsText.formLabel),
              subtitle: Text('Missing it marks the applicant unqualified.', style: JobsText.formHelp),
              value: _must,
              onChanged: (v) => setState(() => _must = v),
            ),
            if (_problem != null)
              Text(
                _problem!,
                key: const ValueKey('question-problem'),
                style: JobsText.formHelp.copyWith(color: AppColors.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(key: const ValueKey('question-save'), onPressed: _save, child: const Text('Save question')),
      ],
    );
  }
}
