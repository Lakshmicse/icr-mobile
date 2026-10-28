import 'package:flutter/material.dart';

import '../mentoring_models.dart';
import 'forms.dart';
import 'kit.dart';

/// "What do you want out of mentoring?": the mentee profile a request needs
/// first (`PUT /mentorship/mentees/me`). Only the career stage is required;
/// the rest is what mentors read before they answer. Resolves true once saved;
/// stays open, with what was typed, when the API refuses.
Future<bool> showIntentSheet(
  BuildContext context, {
  required MenteeIntent? current,
  required List<String> focusOptions,
  required Future<String?> Function(MenteeIntent intent) onSave,
}) => showFormSheet(context, (_) => IntentForm(current: current, focusOptions: focusOptions, onSave: onSave));

class IntentForm extends StatefulWidget {
  const IntentForm({super.key, required this.current, required this.focusOptions, required this.onSave});

  final MenteeIntent? current;
  final List<String> focusOptions;
  final Future<String?> Function(MenteeIntent intent) onSave;

  @override
  State<IntentForm> createState() => _IntentFormState();
}

class _IntentFormState extends State<IntentForm> {
  static const _maxFocus = 12;
  late final TextEditingController _goal = TextEditingController(text: widget.current?.goalSummary ?? '');
  late String? _stage = widget.current?.careerStage;
  late final Set<String> _focus = {...?widget.current?.focusAreas};
  late final Set<String> _modes = {...?widget.current?.preferredModes};
  late String? _cadence = widget.current?.cadence;
  late bool _discoverable = widget.current?.discoverable ?? true;
  String? _problem;
  bool _busy = false;

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  List<String> get _focusChoices => {...widget.focusOptions.take(24), ..._focus}.toList();

  Future<void> _submit() async {
    if (_stage == null) {
      setState(() => _problem = 'Tell us where you are in your career first.');
      return;
    }
    if (_goal.text.trim().length > 2000) {
      setState(() => _problem = 'Keep what you want from mentoring under 2,000 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final refusal = await widget.onSave(
      MenteeIntent(
        careerStage: _stage!,
        focusAreas: _focus.toList(),
        goalSummary: _goal.text.trim().isEmpty ? null : _goal.text.trim(),
        preferredModes: _modes.toList(),
        cadence: _cadence,
        timezone: widget.current?.timezone ?? 'Asia/Kolkata',
        discoverable: _discoverable,
      ),
    );
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
    return MentoringForm(
      title: 'What you want from mentoring',
      subtitle: 'Mentors read this before they answer your request.',
      submitLabel: 'Save',
      busy: _busy,
      problem: _problem,
      onSubmit: _submit,
      children: [
        FieldBlock(
          label: 'Where are you in your career?',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final MapEntry(key: key, value: label) in careerStages.entries)
                ChoiceChip(
                  label: Text(label),
                  selected: _stage == key,
                  onSelected: (_) => setState(() => _stage = key),
                ),
            ],
          ),
        ),
        FieldBlock(
          label: 'What do you want help with?',
          help: _focus.length >= _maxFocus ? 'That is the most you can pick ($_maxFocus).' : 'Pick up to $_maxFocus.',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in _focusChoices)
                FilterChip(
                  label: Text(f),
                  selected: _focus.contains(f),
                  onSelected: (on) => setState(() {
                    if (on) {
                      if (_focus.length < _maxFocus) _focus.add(f);
                    } else {
                      _focus.remove(f);
                    }
                  }),
                ),
            ],
          ),
        ),
        FieldBlock(
          label: 'In your words (optional)',
          child: TextField(
            key: const ValueKey('intent-goal'),
            controller: _goal,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            style: MentoringText.formInput,
            decoration: fieldDecoration('The next step I want to take, and what is in the way'),
          ),
        ),
        FieldBlock(
          label: 'How would you like to meet?',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final MapEntry(key: key, value: label) in meetingModes.entries)
                FilterChip(
                  label: Text(label),
                  selected: _modes.contains(key),
                  onSelected: (on) => setState(() => on ? _modes.add(key) : _modes.remove(key)),
                ),
            ],
          ),
        ),
        FieldBlock(
          label: 'How often?',
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
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _discoverable,
          onChanged: (v) => setState(() => _discoverable = v),
          title: Text('Let mentors find me', style: MentoringText.formLabel),
          subtitle: Text(
            'Mentors can offer you help from their recommendations. Turn it off any time.',
            style: MentoringText.meta,
          ),
        ),
      ],
    );
  }
}
