import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/widgets/buttons.dart';
import '../jobs/jobs_styles.dart';
import 'career_models.dart';
import 'career_styles.dart';
import 'company_insights_controller.dart';

/// "Write a review": the member's say about working at the company. It is
/// anonymous and goes through moderation before it shows; sending it again
/// replaces the earlier one (the form opens with what they wrote).
Future<void> showReviewForm(BuildContext context, CompanyInsightsController controller) async {
  final sent = await _showForm(context, ReviewForm(controller: controller));
  if (sent == true && context.mounted) {
    showMessage(context, 'Thanks. Your review is anonymous and appears once ICR has read it.');
  }
}

/// "Share your salary": anonymous, shown only as an average of at least five reports.
Future<void> showSalaryForm(BuildContext context, CompanyInsightsController controller) async {
  final sent = await _showForm(context, SalaryForm(controller: controller));
  if (sent == true && context.mounted) {
    showMessage(context, 'Thanks. Salaries are anonymous and only ever shown as an average.');
  }
}

/// "Share your interview": how the process went, anonymous, moderated.
Future<void> showInterviewForm(BuildContext context, CompanyInsightsController controller) async {
  final sent = await _showForm(context, InterviewForm(controller: controller));
  if (sent == true && context.mounted) {
    showMessage(context, 'Thanks. Your interview experience appears once ICR has read it.');
  }
}

Future<bool?> _showForm(BuildContext context, Widget form) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: Colors.white,
  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
  builder: (_) => form,
);

const _employmentStatuses = [('CURRENT', 'Current employee'), ('FORMER', 'Former employee')];
const _outcomes = [
  ('OFFER_ACCEPTED', 'Offer accepted'),
  ('OFFER_DECLINED', 'Offer declined'),
  ('NO_OFFER', 'No offer'),
  ('IN_PROGRESS', 'Still in progress'),
];

/// The frame all three forms share: a title, the fields, the API's refusal, and the send button.
class _FormFrame extends StatelessWidget {
  const _FormFrame({
    required this.title,
    required this.lead,
    required this.children,
    required this.submitLabel,
    required this.sending,
    required this.onSubmit,
    this.problem,
  });

  final String title;
  final String lead;
  final List<Widget> children;
  final String submitLabel;
  final bool sending;
  final VoidCallback onSubmit;
  final String? problem;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: JobsText.formTitle),
            const SizedBox(height: 4),
            Text(lead, style: JobsText.formHelp),
            const SizedBox(height: 12),
            // The fields scroll; the refusal and the send button stay in reach.
            Flexible(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
              ),
            ),
            if (problem != null) ...[
              const SizedBox(height: 4),
              Text(
                problem!,
                key: const ValueKey('form-problem'),
                style: JobsText.formHelp.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: 12),
            PrimaryButton(
              label: sending ? 'Sending…' : submitLabel,
              icon: LucideIcons.send,
              onPressed: sending ? null : onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

Widget _field(
  String label,
  TextEditingController controller, {
  Key? fieldKey,
  int minLines = 1,
  int? maxLines,
  int? maxLength,
  TextInputType? keyboard,
  List<TextInputFormatter>? formatters,
  String? hint,
  String? prefix,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 14),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: JobsText.formLabel),
      const SizedBox(height: 4),
      TextField(
        key: fieldKey,
        controller: controller,
        minLines: minLines,
        maxLines: maxLines ?? (minLines > 1 ? minLines + 3 : 1),
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
      ),
    ],
  ),
);

Widget _stars(String label, int value, ValueChanged<int> onChanged, String keyPrefix, {double size = 28}) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Row(
    children: [
      Expanded(child: Text(label, style: JobsText.formLabel)),
      StarPicker(value: value, onChanged: onChanged, size: size, keyPrefix: keyPrefix),
    ],
  ),
);

Widget _choices(
  String label,
  List<(String, String)> options,
  String? value,
  ValueChanged<String?> onChanged,
  String keyPrefix,
) => Padding(
  padding: const EdgeInsets.only(bottom: 14),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: JobsText.formLabel),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (key, text) in options)
            ChoiceChip(
              key: ValueKey('$keyPrefix-$key'),
              label: Text(text),
              selected: value == key,
              // Tapping the chosen one again takes it back: "prefer not to say".
              onSelected: (on) => onChanged(on ? key : null),
            ),
        ],
      ),
    ],
  ),
);

class ReviewForm extends StatefulWidget {
  const ReviewForm({super.key, required this.controller});

  final CompanyInsightsController controller;

  @override
  State<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<ReviewForm> {
  late final EmployerReview? _earlier = widget.controller.mine;
  late int _overall = _earlier?.rating ?? 0;
  late final Map<String, int> _subs = {...?_earlier?.subRatings};
  late final _title = TextEditingController(text: _earlier?.title);
  late final _pros = TextEditingController(text: _earlier?.pros);
  late final _cons = TextEditingController(text: _earlier?.cons);
  late final _advice = TextEditingController(text: _earlier?.advice);
  late final _jobTitle = TextEditingController(text: _earlier?.jobTitle);
  late String? _status = _earlier?.employmentStatus;
  String? _problem;
  bool _sending = false;

  @override
  void dispose() {
    for (final c in [_title, _pros, _cons, _advice, _jobTitle]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final draft = ReviewDraft(
      overall: _overall,
      title: _title.text,
      pros: _pros.text,
      cons: _cons.text,
      subRatings: {
        for (final e in _subs.entries)
          if (e.value > 0) e.key: e.value,
      },
      advice: _advice.text,
      jobTitle: _jobTitle.text,
      employmentStatus: _status,
    );
    final problem = draft.problem;
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    setState(() {
      _sending = true;
      _problem = null;
    });
    final refusal = await widget.controller.submitReview(draft);
    if (!mounted) return;
    if (refusal != null) {
      // What was typed stays: only the sentence is new.
      setState(() {
        _sending = false;
        _problem = refusal;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final company = widget.controller.company.name;
    return _FormFrame(
      title: _earlier == null ? 'Review $company' : 'Update your review of $company',
      lead: 'Reviews are published anonymously and are read by ICR before they show.',
      submitLabel: _earlier == null ? 'Submit review' : 'Replace my review',
      sending: _sending,
      problem: _problem,
      onSubmit: _submit,
      children: [
        _stars('Overall rating', _overall, (v) => setState(() => _overall = v), 'overall', size: 34),
        for (final e in reviewSubRatings.entries)
          _stars(e.value, _subs[e.key] ?? 0, (v) => setState(() => _subs[e.key] = v), 'sub-${e.key}', size: 22),
        const SizedBox(height: 4),
        _field('Headline', _title, fieldKey: const ValueKey('review-title'), maxLength: ReviewDraft.titleMax),
        _field(
          'Pros',
          _pros,
          fieldKey: const ValueKey('review-pros'),
          minLines: 2,
          maxLength: ReviewDraft.textMax,
          hint: 'What is good about working here',
        ),
        _field(
          'Cons',
          _cons,
          fieldKey: const ValueKey('review-cons'),
          minLines: 2,
          maxLength: ReviewDraft.textMax,
          hint: 'What could be better',
        ),
        _field('Advice to management (optional)', _advice, minLines: 2, maxLength: ReviewDraft.textMax),
        _field('Your job title (optional)', _jobTitle, maxLength: ReviewDraft.jobTitleMax),
        _choices('Employment status', _employmentStatuses, _status, (v) => setState(() => _status = v), 'status'),
      ],
    );
  }
}

class SalaryForm extends StatefulWidget {
  const SalaryForm({super.key, required this.controller});

  final CompanyInsightsController controller;

  @override
  State<SalaryForm> createState() => _SalaryFormState();
}

class _SalaryFormState extends State<SalaryForm> {
  final _jobTitle = TextEditingController();
  final _city = TextEditingController();
  final _amount = TextEditingController();
  final _years = TextEditingController();
  String _period = 'YEARLY';
  String? _status;
  String? _problem;
  bool _sending = false;

  @override
  void dispose() {
    for (final c in [_jobTitle, _city, _amount, _years]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final draft = SalaryDraft(
      jobTitle: _jobTitle.text,
      amount: num.tryParse(_amount.text.trim()),
      period: _period,
      city: _city.text,
      years: num.tryParse(_years.text.trim()),
      employmentStatus: _status,
    );
    final problem = draft.problem;
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    setState(() {
      _sending = true;
      _problem = null;
    });
    final refusal = await widget.controller.submitSalary(draft);
    if (!mounted) return;
    if (refusal != null) {
      setState(() {
        _sending = false;
        _problem = refusal;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return _FormFrame(
      title: 'Share a salary at ${widget.controller.company.name}',
      lead: 'Anonymous. It only ever shows as an average, once at least five people report the same role.',
      submitLabel: 'Share salary',
      sending: _sending,
      problem: _problem,
      onSubmit: _submit,
      children: [
        _field('Job title', _jobTitle, fieldKey: const ValueKey('salary-title'), maxLength: SalaryDraft.jobTitleMax),
        _field('City (optional)', _city, maxLength: SalaryDraft.cityMax),
        _field(
          'Amount',
          _amount,
          fieldKey: const ValueKey('salary-amount'),
          keyboard: const TextInputType.numberWithOptions(decimal: true),
          formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          prefix: '₹ ',
        ),
        _choices(
          'Paid',
          const [('YEARLY', 'Per year'), ('MONTHLY', 'Per month'), ('HOURLY', 'Per hour')],
          _period,
          (v) => setState(() => _period = v ?? _period),
          'period',
        ),
        _field(
          'Years of experience (optional)',
          _years,
          keyboard: const TextInputType.numberWithOptions(decimal: true),
          formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        ),
        _choices('Employment status', _employmentStatuses, _status, (v) => setState(() => _status = v), 'status'),
      ],
    );
  }
}

class InterviewForm extends StatefulWidget {
  const InterviewForm({super.key, required this.controller});

  final CompanyInsightsController controller;

  @override
  State<InterviewForm> createState() => _InterviewFormState();
}

class _InterviewFormState extends State<InterviewForm> {
  final _jobTitle = TextEditingController();
  final _process = TextEditingController();
  final _questions = TextEditingController();
  final _days = TextEditingController();
  int _difficulty = 0;
  int _experience = 0;
  String? _outcome;
  String? _problem;
  bool _sending = false;

  @override
  void dispose() {
    for (final c in [_jobTitle, _process, _questions, _days]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final draft = InterviewReviewDraft(
      difficulty: _difficulty,
      experience: _experience,
      process: _process.text,
      jobTitle: _jobTitle.text,
      outcome: _outcome,
      questions: _questions.text,
      durationDays: int.tryParse(_days.text.trim()),
    );
    final problem = draft.problem;
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    setState(() {
      _sending = true;
      _problem = null;
    });
    final refusal = await widget.controller.submitInterview(draft);
    if (!mounted) return;
    if (refusal != null) {
      setState(() {
        _sending = false;
        _problem = refusal;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return _FormFrame(
      title: 'Your interview at ${widget.controller.company.name}',
      lead: 'Anonymous. It helps the next person who sits there.',
      submitLabel: 'Share interview',
      sending: _sending,
      problem: _problem,
      onSubmit: _submit,
      children: [
        _field('Role you interviewed for (optional)', _jobTitle, maxLength: SalaryDraft.jobTitleMax),
        _stars('Difficulty (1 easy, 5 hard)', _difficulty, (v) => setState(() => _difficulty = v), 'difficulty'),
        _stars('Overall experience', _experience, (v) => setState(() => _experience = v), 'experience'),
        _choices('Outcome', _outcomes, _outcome, (v) => setState(() => _outcome = v), 'outcome'),
        _field(
          'How did the process go?',
          _process,
          fieldKey: const ValueKey('interview-process'),
          minLines: 3,
          maxLength: InterviewReviewDraft.textMax,
        ),
        _field('Questions you were asked (optional)', _questions, minLines: 2, maxLength: InterviewReviewDraft.textMax),
        _field(
          'Process length in days (optional)',
          _days,
          keyboard: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      ],
    );
  }
}
