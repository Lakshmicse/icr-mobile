import 'package:flutter/material.dart';

import '../../mentorship_my/mentoring_format.dart' show inr;
import 'composer_kit.dart';
import 'offering_fields.dart' show pickAndUpload;
import 'offerings_controller.dart';
import 'offerings_files.dart';
import 'offerings_models.dart';
import 'offerings_rules.dart';

/// Creates or edits an ongoing plan, as the website's "Create a plan" dialog does (`PlanFormDialog` +
/// `PlanFormFields`, owner, 14 Nov 2026: "Create Plan button click and the dialog opened ... just implement how the
/// web is working"): Title, Description, Cover Image, Free or Paid, Price per Term and Billed Every, Sessions a Month
/// and the length of each, What Else Is Included, and Published. A programme (1:1 mentoring of several sessions) is
/// composed in the 1:1 mentoring composer instead.
///
/// A new plan opens as the website's does: ₹25,000 every month, 2 sessions a month of 1 hour, a draft. Resolves true
/// when saved.
Future<bool> openOngoingPlanForm(
  BuildContext context, {
  required OfferingsController controller,
  OfferingFilePicker pickFile = pickOfferingFile,
  OfferedPlan? existing,
}) => pushComposer(context, (_) => OngoingPlanForm(controller: controller, pickFile: pickFile, existing: existing));

class OngoingPlanForm extends StatefulWidget {
  const OngoingPlanForm({super.key, required this.controller, required this.pickFile, this.existing});

  final OfferingsController controller;
  final OfferingFilePicker pickFile;
  final OfferedPlan? existing;

  @override
  State<OngoingPlanForm> createState() => _OngoingPlanFormState();
}

class _OngoingPlanFormState extends State<OngoingPlanForm> {
  OfferedPlan? get _plan => widget.existing;
  bool get _editing => _plan != null;

  late final _title = TextEditingController(text: _plan?.title ?? '');
  late final _blurb = TextEditingController(text: _plan?.blurb ?? '');
  late final _price = TextEditingController(text: _plan == null ? '25000' : rupeesOf(_plan!.pricePaisa == 0 ? null : _plan!.pricePaisa));
  late final _perMonth = TextEditingController(text: '${(_plan?.sessionsPerMonth ?? 0) > 0 ? _plan!.sessionsPerMonth : 2}');
  late final _inclusions = TextEditingController(text: (_plan?.inclusions ?? const []).join('\n'));
  late bool _paid = _plan == null || _plan!.pricePaisa > 0;
  late int _period = planPeriods.contains(_plan?.billingPeriodMonths) ? _plan!.billingPeriodMonths : 1;
  late int _minutes = _plan?.sessionDurationMin ?? 60;
  late bool _active = _plan?.active ?? false;
  late String? _cover = _plan?.coverUrl;
  String? _coverProblem;
  bool _uploading = false;
  bool _busy = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    for (final c in [_title, _price, _perMonth, _inclusions]) {
      c.addListener(_redraw);
    }
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_title, _blurb, _price, _perMonth, _inclusions]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _inclusionLines => [
    for (final l in _inclusions.text.split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];

  int get _rupees => int.tryParse(_price.text.trim()) ?? 0;

  /// What still stops the save, in the website's words and order (`usePlanForm`'s blocker); null when it may go.
  String? get _blocker {
    final title = _title.text.trim();
    if (title.isEmpty) return 'Enter a title.';
    if (title.length < minPlanTitle) return 'Enter a title (at least $minPlanTitle characters).';
    if (_paid && _rupees * 100 < minPlanPricePaisa) return 'A priced plan starts at ${inr(minPlanPricePaisa)}.';
    if (_paid && _rupees * 100 > maxPlanPricePaisa) return 'A priced plan is at most ${inr(maxPlanPricePaisa)} per term.';
    final perMonth = int.tryParse(_perMonth.text.trim());
    if (perMonth == null || perMonth < minSessionsPerMonth || perMonth > maxSessionsPerMonth) {
      return 'Set sessions a month to $minSessionsPerMonth–$maxSessionsPerMonth.';
    }
    if (_inclusionLines.any((l) => l.length > maxInclusionChars)) {
      return 'Keep each line of "What Else Is Included" to $maxInclusionChars characters.';
    }
    return null;
  }

  Future<void> _pickCover() async {
    setState(() => _uploading = true);
    final stored = await pickAndUpload(
      pick: widget.pickFile,
      upload: (f) => widget.controller.upload(f, purpose: 'mentor-offering'),
      imageOnly: true,
      problem: (p) => _coverProblem = p,
    );
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (stored != null) _cover = stored.url;
    });
  }

  Future<void> _save() async {
    final blocker = _blocker;
    if (blocker != null) {
      setState(() => _problem = blocker);
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final blurb = _blurb.text.trim();
    final body = <String, Object?>{
      'title': _title.text.trim(),
      if (blurb.isNotEmpty || _editing) 'blurb': blurb.isEmpty ? null : blurb,
      'coverUrl': _cover,
      'pricePaisa': _paid ? _rupees * 100 : 0,
      'sessionDurationMin': _minutes,
      'inclusions': _inclusionLines.take(maxInclusions).toList(),
      'active': _active,
      if (!_editing) 'kind': 'RECURRING',
      'billingPeriodMonths': _period,
      'sessionsPerMonth': int.parse(_perMonth.text.trim()),
    };
    final refusal = await widget.controller.savePlan(body, id: _plan?.id);
    if (!mounted) return;
    if (refusal == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _problem = refusal;
    });
  }

  static String _periodLabel(int months) => months == 1 ? 'Month' : '$months Months';

  @override
  Widget build(BuildContext context) {
    final blocker = _blocker;
    return ComposerPage(
      title: _editing ? 'Edit Ongoing Plan' : 'New Ongoing Plan',
      lead: 'A set number of sessions a month for a term, booked as needed.',
      blocker: blocker,
      problem: _problem,
      busy: _busy || _uploading,
      saveLabel: 'Save Plan',
      onSave: _save,
      sections: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ComposerField(
                label: 'Title',
                required: true,
                help: 'What the mentee is buying, in your own words.',
                child: TextField(
                  key: const ValueKey('plan-title'),
                  controller: _title,
                  maxLength: maxPlanTitle,
                  style: ComposerText.body,
                  decoration: composerDecoration('e.g. Monthly career coaching').copyWith(counterText: ''),
                ),
              ),
              ComposerField(
                label: 'Description',
                optional: true,
                child: TextField(
                  key: const ValueKey('plan-description'),
                  controller: _blurb,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: maxPlanBlurb,
                  style: ComposerText.body,
                  decoration: composerDecoration('What the mentee will get from this.').copyWith(counterText: ''),
                ),
              ),
              ComposerField(
                label: 'Cover Image',
                optional: true,
                child: CoverImageField(
                  url: _cover,
                  busy: _uploading,
                  problem: _coverProblem,
                  onPick: _pickCover,
                  onRemove: () => setState(() => _cover = null),
                  help: 'Shown on your profile card and when someone books or buys it. PNG, JPG or WEBP, up to 2 MB.',
                ),
              ),
              FreePaidToggle(
                keyPrefix: 'plan-price',
                paid: _paid,
                freeNote: 'Nothing is charged for the term.',
                onChanged: (paid) => setState(() {
                  _paid = paid;
                  // Coming back to Paid with nothing in the box would read as ₹0, the thing just switched away from.
                  if (paid && _rupees <= 0) _price.text = rupeesOf(minPlanPricePaisa);
                }),
              ),
              if (_paid)
                ComposerField(
                  label: 'Price per Term (₹)',
                  help: 'At least ${inr(minPlanPricePaisa)}. GST is added at checkout.',
                  child: TextField(
                    key: const ValueKey('plan-price'),
                    controller: _price,
                    keyboardType: TextInputType.number,
                    style: ComposerText.body,
                    decoration: composerDecoration('25000', rupee: true),
                  ),
                ),
              ComposerField(
                label: 'Billed Every',
                child: DropdownButtonFormField<int>(
                  key: const ValueKey('plan-period'),
                  initialValue: _period,
                  style: ComposerText.body,
                  decoration: composerDecoration(''),
                  items: [for (final m in planPeriods) DropdownMenuItem(value: m, child: Text(_periodLabel(m)))],
                  onChanged: (v) => setState(() => _period = v ?? _period),
                ),
              ),
              ComposerField(
                label: 'Sessions a Month',
                help: 'The allowance a subscriber may book.',
                child: TextField(
                  key: const ValueKey('plan-per-month'),
                  controller: _perMonth,
                  keyboardType: TextInputType.number,
                  style: ComposerText.body,
                  decoration: composerDecoration('2'),
                ),
              ),
              ComposerField(
                label: 'Session Length',
                help: 'How long each session runs.',
                child: DurationPicker(
                  keyPrefix: 'plan-length',
                  minutes: _minutes,
                  onChanged: (m) => setState(() => _minutes = m),
                ),
              ),
              ComposerField(
                label: 'What Else Is Included',
                optional: true,
                help: 'One per line, up to $maxInclusions. Include only what you will actually provide.',
                child: TextField(
                  key: const ValueKey('plan-inclusions'),
                  controller: _inclusions,
                  minLines: 3,
                  maxLines: 8,
                  style: ComposerText.body,
                  decoration: composerDecoration('e.g. A CV review each quarter'),
                ),
              ),
              PublishedSwitch(
                keyName: 'plan-published',
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                onText: 'Published. Mentees can view and buy this plan.',
                offText: 'Draft. Hidden from your profile.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
