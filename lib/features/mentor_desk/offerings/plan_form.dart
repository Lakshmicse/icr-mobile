import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../mentorship_my/widgets/forms.dart';
import '../../mentorship_my/widgets/kit.dart';
import 'offering_fields.dart';
import 'offerings_controller.dart';
import 'offerings_files.dart';
import 'offerings_models.dart';
import 'offerings_rules.dart';

/// Creates or edits an ongoing plan (a prepaid term with sessions a month) or a
/// programme (a fixed syllabus, requested, accepted, then paid). Validated as the
/// API's `CreateMentorPlanDto` and the plan service's price and shape rules are.
class PlanForm extends StatefulWidget {
  const PlanForm({super.key, required this.controller, required this.pickFile, this.programme = false, this.existing});

  final OfferingsController controller;
  final OfferingFilePicker pickFile;

  /// What a new offering is (an existing one keeps its own kind: the API refuses a change).
  final bool programme;
  final OfferedPlan? existing;

  @override
  State<PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<PlanForm> {
  late bool _programme = widget.existing?.programme ?? widget.programme;
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _blurb = TextEditingController(text: widget.existing?.blurb ?? '');
  late final _price = TextEditingController(
    text: rupeesOf(widget.existing?.pricePaisa == 0 ? null : widget.existing?.pricePaisa),
  );
  late final _compare = TextEditingController(text: rupeesOf(widget.existing?.compareAtPaisa));
  late final _perMonth = TextEditingController(
    text: '${(widget.existing?.sessionsPerMonth ?? 0) > 0 ? widget.existing!.sessionsPerMonth : 2}',
  );
  late final _length = TextEditingController(
    text: widget.existing?.sessionDurationMin == null ? '' : '${widget.existing!.sessionDurationMin}',
  );
  late final _access = TextEditingController(text: '${widget.existing?.accessMonths ?? 6}');
  late final _inclusions = TextEditingController(text: (widget.existing?.inclusions ?? const []).join('\n'));
  late int _period = widget.existing?.billingPeriodMonths ?? 1;
  late bool _free = widget.existing != null && widget.existing!.pricePaisa == 0;
  late bool _active = widget.existing?.active ?? true;

  final _modTitles = <TextEditingController>[];
  final _modOutlines = <TextEditingController>[];
  final _modMinutes = <TextEditingController>[];

  late String? _cover = widget.existing?.coverUrl;
  bool _coverChanged = false;
  String? _coverName;
  String? _problem;
  bool _busy = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final steps = widget.existing?.steps ?? const [];
    if (steps.isNotEmpty) {
      for (final s in steps) {
        _addModule(title: s.title, outline: s.outline ?? '', minutes: s.durationMin == null ? '' : '${s.durationMin}');
      }
    } else {
      _addModule();
      _addModule();
    }
  }

  void _addModule({String title = '', String outline = '', String minutes = ''}) {
    _modTitles.add(TextEditingController(text: title));
    _modOutlines.add(TextEditingController(text: outline));
    _modMinutes.add(TextEditingController(text: minutes));
  }

  void _removeModule(int i) {
    setState(() {
      _modTitles.removeAt(i).dispose();
      _modOutlines.removeAt(i).dispose();
      _modMinutes.removeAt(i).dispose();
    });
  }

  @override
  void dispose() {
    for (final c in [_title, _blurb, _price, _compare, _perMonth, _length, _access, _inclusions]) {
      c.dispose();
    }
    for (final c in [..._modTitles, ..._modOutlines, ..._modMinutes]) {
      c.dispose();
    }
    super.dispose();
  }

  List<ModuleDraft> get _modules => [
    for (var i = 0; i < _modTitles.length; i++)
      ModuleDraft(title: _modTitles[i].text, outline: _modOutlines[i].text, minutes: _modMinutes[i].text),
  ];

  List<String> get _inclusionLines => [
    for (final l in _inclusions.text.split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];

  Future<void> _pickCover() async {
    setState(() => _uploading = true);
    final stored = await pickAndUpload(
      pick: widget.pickFile,
      upload: (f) => widget.controller.upload(f, purpose: 'mentor-offering'),
      imageOnly: true,
      problem: (p) => setState(() => _problem = p),
    );
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (stored != null) {
        _cover = stored.url;
        _coverName = stored.name;
        _coverChanged = true;
      }
    });
  }

  String? _validate() {
    final title = planTitleProblem(_title.text);
    if (title != null) return title;
    final blurb = blurbProblem(_blurb.text, max: maxPlanBlurb);
    if (blurb != null) return blurb;
    final price = _programme
        ? programmePriceProblem(free: _free, price: _price.text, compareAt: _compare.text)
        : recurringPriceProblem(free: _free, price: _price.text, compareAt: _compare.text);
    if (price != null) return price;
    if (_programme) {
      final access = int.tryParse(_access.text.trim());
      if (access == null || access < minAccessMonths || access > maxAccessMonths) {
        return 'Access: $minAccessMonths to $maxAccessMonths months to use the sessions.';
      }
      final mods = modulesProblem(_modules);
      if (mods != null) return mods;
    } else {
      final n = int.tryParse(_perMonth.text.trim());
      if (n == null || n < minSessionsPerMonth || n > maxSessionsPerMonth) {
        return 'Say how many sessions a month the plan includes: $minSessionsPerMonth to $maxSessionsPerMonth.';
      }
    }
    if (_length.text.trim().isNotEmpty) {
      final m = minutesProblem(_length.text);
      if (m != null) return m;
    }
    return inclusionsProblem(_inclusionLines);
  }

  Map<String, Object?> _body() {
    final price = _free ? 0 : paisaOf(_price.text)!;
    final compare = _free || _compare.text.trim().isEmpty ? null : paisaOf(_compare.text);
    final editing = widget.existing != null;
    return {
      'title': _title.text.trim(),
      if (_blurb.text.trim().isNotEmpty || editing) 'blurb': _blurb.text.trim(),
      if (!editing) 'kind': _programme ? 'CURRICULUM' : 'RECURRING',
      'pricePaisa': price,
      if (compare != null || (editing && widget.existing!.compareAtPaisa != null)) 'compareAtPaisa': compare,
      if (_programme)
        'accessMonths': int.parse(_access.text.trim())
      else ...{
        'billingPeriodMonths': _period,
        'sessionsPerMonth': int.parse(_perMonth.text.trim()),
      },
      if (_length.text.trim().isNotEmpty) 'sessionDurationMin': int.parse(_length.text.trim()),
      if (_programme)
        'modules': [
          for (final m in _modules)
            {
              'title': m.title.trim(),
              if (m.outline.trim().isNotEmpty) 'outline': m.outline.trim(),
              if (m.minutes.trim().isNotEmpty) 'durationMin': int.parse(m.minutes.trim()),
            },
        ],
      'inclusions': _inclusionLines,
      'active': _active,
      if (_coverChanged || (!editing && _cover != null)) 'coverUrl': _cover,
    };
  }

  Future<void> _submit() async {
    final bad = _validate();
    if (bad != null) {
      setState(() => _problem = bad);
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final refusal = await widget.controller.savePlan(_body(), id: widget.existing?.id);
    if (!mounted) return;
    if (refusal != null) {
      setState(() {
        _busy = false;
        _problem = refusal;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return MentoringForm(
      title: editing
          ? 'Edit ${_programme ? 'programme' : 'plan'}'
          : (_programme ? 'Add a programme' : 'Add an ongoing plan'),
      subtitle: _programme
          ? 'A fixed run of sessions. A member asks, you accept, they pay, and the sessions are booked against your syllabus.'
          : 'A prepaid term with sessions every month. Nothing is debited automatically: a renewal is a new purchase.',
      submitLabel: editing ? 'Save' : 'Add',
      busy: _busy,
      problem: _problem,
      onSubmit: _uploading ? null : _submit,
      children: [
        if (!editing)
          FieldBlock(
            label: 'What are you offering?',
            child: Wrap(
              spacing: 6,
              children: [
                ChoiceChip(
                  key: const ValueKey('kind-recurring'),
                  label: const Text('Ongoing plan'),
                  selected: !_programme,
                  onSelected: (_) => setState(() => _programme = false),
                ),
                ChoiceChip(
                  key: const ValueKey('kind-programme'),
                  label: const Text('Programme'),
                  selected: _programme,
                  onSelected: (_) => setState(() => _programme = true),
                ),
              ],
            ),
          ),
        FieldBlock(
          label: 'Title',
          child: TextField(
            key: const ValueKey('offering-title'),
            controller: _title,
            maxLength: maxPlanTitle,
            style: MentoringText.formInput,
            decoration: fieldDecoration(
              _programme ? 'Site to portfolio: a 3-session programme' : 'Monthly leadership coaching',
            ),
          ),
        ),
        FieldBlock(
          label: 'Description (optional)',
          child: TextField(
            key: const ValueKey('offering-blurb'),
            controller: _blurb,
            minLines: 2,
            maxLines: 5,
            maxLength: maxPlanBlurb,
            style: MentoringText.formInput,
            decoration: fieldDecoration('Who it is for and what changes'),
          ),
        ),
        PriceBlock(
          free: _free,
          onFree: (v) => setState(() => _free = v),
          price: _price,
          compareAt: _compare,
          priceHelp: _programme
              ? 'For the whole programme. Free, or ₹499 or more.'
              : 'For one term. Free, or between ₹500 and ₹5,00,000.',
        ),
        if (!_programme) ...[
          FieldBlock(
            label: 'How long is a term?',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in planPeriods)
                  ChoiceChip(
                    key: ValueKey('period-$m'),
                    label: Text(m == 1 ? '1 month' : '$m months'),
                    selected: _period == m,
                    onSelected: (_) => setState(() => _period = m),
                  ),
              ],
            ),
          ),
          FieldBlock(
            label: 'Sessions a month ($minSessionsPerMonth to $maxSessionsPerMonth)',
            child: TextField(
              key: const ValueKey('plan-per-month'),
              controller: _perMonth,
              keyboardType: TextInputType.number,
              style: MentoringText.formInput,
              decoration: fieldDecoration('2'),
            ),
          ),
        ] else
          FieldBlock(
            label: 'Months to use the sessions ($minAccessMonths to $maxAccessMonths)',
            child: TextField(
              key: const ValueKey('plan-access'),
              controller: _access,
              keyboardType: TextInputType.number,
              style: MentoringText.formInput,
              decoration: fieldDecoration('6'),
            ),
          ),
        FieldBlock(
          label: 'Usual session length (minutes, optional)',
          child: TextField(
            key: const ValueKey('plan-length'),
            controller: _length,
            keyboardType: TextInputType.number,
            style: MentoringText.formInput,
            decoration: fieldDecoration('45'),
          ),
        ),
        if (_programme) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Syllabus: $minPlanModules to $maxPlanModules sessions', style: MentoringText.formLabel),
          ),
          for (var i = 0; i < _modTitles.length; i++) _moduleCard(i),
          if (_modTitles.length < maxPlanModules)
            Align(
              alignment: Alignment.centerLeft,
              child: QuietButton(
                key: const ValueKey('module-add'),
                label: 'Add a session',
                icon: LucideIcons.plus,
                onPressed: () => setState(_addModule),
              ),
            ),
          const SizedBox(height: 14),
        ],
        FieldBlock(
          label: 'What it includes (one line each, up to $maxInclusions)',
          child: TextField(
            key: const ValueKey('plan-inclusions'),
            controller: _inclusions,
            minLines: 3,
            maxLines: 8,
            style: MentoringText.formInput,
            decoration: fieldDecoration('Notes after every session'),
          ),
        ),
        FileRow(
          label: 'Cover image (optional)',
          pickKey: 'offering-cover',
          name: _cover == null ? null : (_coverName ?? 'Current cover'),
          busy: _uploading,
          pickLabel: _cover == null ? 'Choose an image' : 'Replace the image',
          onPick: _pickCover,
          onClear: () => setState(() {
            _cover = null;
            _coverName = null;
            _coverChanged = true;
          }),
        ),
        SwitchListTile.adaptive(
          key: const ValueKey('offering-active'),
          contentPadding: EdgeInsets.zero,
          value: _active,
          onChanged: (v) => setState(() => _active = v),
          title: Text('Live on your storefront', style: MentoringText.formLabel),
          subtitle: Text('Members see only what is live. Switch it off to pause it.', style: MentoringText.meta),
        ),
      ],
    );
  }

  Widget _moduleCard(int i) {
    return Container(
      key: ValueKey('module-$i'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardRule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Session ${i + 1}', style: MentoringText.cardTitle)),
              if (_modTitles.length > minPlanModules)
                IconButton(
                  key: ValueKey('module-remove-$i'),
                  tooltip: 'Remove session ${i + 1}',
                  onPressed: () => _removeModule(i),
                  icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.outline),
                ),
            ],
          ),
          TextField(
            key: ValueKey('module-title-$i'),
            controller: _modTitles[i],
            maxLength: maxModuleTitle,
            style: MentoringText.formInput,
            decoration: fieldDecoration('Title'),
          ),
          const SizedBox(height: 6),
          TextField(
            key: ValueKey('module-outline-$i'),
            controller: _modOutlines[i],
            minLines: 2,
            maxLines: 4,
            maxLength: maxModuleOutline,
            style: MentoringText.formInput,
            decoration: fieldDecoration('What it covers (optional)'),
          ),
          const SizedBox(height: 6),
          TextField(
            key: ValueKey('module-minutes-$i'),
            controller: _modMinutes[i],
            keyboardType: TextInputType.number,
            style: MentoringText.formInput,
            decoration: fieldDecoration('Minutes (optional, $minSessionMinutes to $maxSessionMinutes)'),
          ),
        ],
      ),
    );
  }
}
