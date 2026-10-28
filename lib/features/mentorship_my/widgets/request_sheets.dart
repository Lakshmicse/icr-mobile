import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../mentoring_models.dart';
import 'forms.dart';
import 'kit.dart';

/// A mentor accepts a request: an optional note back and the cadence agreed.
/// Resolves true once the API took it; the sheet stays open, with what was
/// typed, when it refuses.
Future<bool> showAcceptRequestSheet(
  BuildContext context, {
  required MentoringRequest request,
  required Future<String?> Function(String note, String? cadence) onSend,
}) => showFormSheet(context, (_) => _AcceptForm(request: request, onSend: onSend));

class _AcceptForm extends StatefulWidget {
  const _AcceptForm({required this.request, required this.onSend});

  final MentoringRequest request;
  final Future<String?> Function(String note, String? cadence) onSend;

  @override
  State<_AcceptForm> createState() => _AcceptFormState();
}

class _AcceptFormState extends State<_AcceptForm> {
  final _note = TextEditingController();
  String? _cadence;
  String? _problem;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    final refusal = await widget.onSend(_note.text.trim(), _cadence);
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
    final mentee = widget.request.mentee;
    return MentoringForm(
      title: 'Accept ${mentee.firstName}',
      subtitle: 'You become ${mentee.firstName}\'s mentor and they are told. You can pause or end it later.',
      submitLabel: 'Accept and start',
      busy: _busy,
      problem: _problem,
      onSubmit: _submit,
      children: [
        FieldBlock(
          label: 'How often will you meet?',
          help: 'Optional. It is a rhythm to aim for, not a rule.',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final MapEntry(key: key, value: label) in cadences.entries)
                ChoiceChip(
                  label: Text(label),
                  selected: _cadence == key,
                  onSelected: (on) => setState(() => _cadence = on ? key : null),
                ),
            ],
          ),
        ),
        FieldBlock(
          label: 'A note back (optional)',
          child: TextField(
            key: const ValueKey('accept-note'),
            controller: _note,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            style: MentoringText.formInput,
            decoration: fieldDecoration('What to bring to your first call'),
          ),
        ),
      ],
    );
  }
}

/// A mentor declines a request, with a note the mentee reads as written.
Future<bool> showDeclineRequestSheet(
  BuildContext context, {
  required MentoringRequest request,
  required Future<String?> Function(String note) onSend,
}) => showTextSheet(
  context,
  title: 'Decline ${request.mentee.firstName}?',
  subtitle: 'They are told, with your note. A kind line helps: they may look for someone else.',
  label: 'A note back (optional)',
  hint: 'My cohort is full until next quarter',
  submitLabel: 'Decline request',
  maxLength: 2000,
  optional: true,
  danger: true,
  onSend: onSend,
);

/// The tag a chip row of choices shows in a form: one choice lit.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.labelOf,
  });

  final List<T> options;
  final T? selected;
  final ValueChanged<T> onSelect;
  final String Function(T) labelOf;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(labelOf(o)),
            selected: o == selected,
            onSelected: (_) => onSelect(o),
            selectedColor: AppColors.chipEmphasis,
          ),
      ],
    );
  }
}
