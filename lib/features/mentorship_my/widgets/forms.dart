import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/buttons.dart';
import '../mentoring_format.dart';
import '../mentoring_models.dart';
import 'kit.dart';
import '../mentoring_clock.dart';

/// Runs a send and answers the API's refusal, or null when it went through.
/// A form stays open on a refusal, with what was typed, and shows the sentence.
typedef Send<T> = Future<String?> Function(T value);

/// Opens a form in a bottom sheet; resolves true when it was sent.
Future<bool> showFormSheet(BuildContext context, WidgetBuilder builder) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: builder,
  );
  return sent == true;
}

/// The frame of a mentoring form: title, a line under it, the fields, the
/// refusal (in red) and the send button.
class MentoringForm extends StatelessWidget {
  const MentoringForm({
    super.key,
    required this.title,
    required this.children,
    required this.submitLabel,
    required this.onSubmit,
    this.subtitle,
    this.problem,
    this.busy = false,
    this.danger = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final String submitLabel;
  final VoidCallback? onSubmit;
  final String? problem;
  final bool busy;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: MentoringText.formTitle),
              if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: MentoringText.formHelp)],
              const SizedBox(height: 16),
              ...children,
              if (problem != null) ...[const SizedBox(height: 4), Text(problem!, style: MentoringText.error)],
              const SizedBox(height: 14),
              PrimaryButton(
                label: busy ? 'Sending…' : submitLabel,
                color: danger ? AppColors.error : AppColors.primary,
                onPressed: busy ? null : onSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A label over a field, with an optional help line.
class FieldBlock extends StatelessWidget {
  const FieldBlock({super.key, required this.label, required this.child, this.help});

  final String label;
  final Widget child;
  final String? help;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: MentoringText.formLabel),
          const SizedBox(height: 5),
          child,
          if (help != null) ...[const SizedBox(height: 4), Text(help!, style: MentoringText.formHelp)],
        ],
      ),
    );
  }
}

InputDecoration fieldDecoration(String hint) => InputDecoration(
  hintText: hint,
  isDense: true,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.outlineVariant),
  ),
);

/// Asks for a sentence (a reason, a note) and sends it; the sheet stays open,
/// with the text, when the API refuses. Resolves true once sent.
Future<bool> showTextSheet(
  BuildContext context, {
  required String title,
  required String label,
  required String submitLabel,
  required Send<String> onSend,
  String? subtitle,
  String hint = '',
  int minLength = 0,
  int maxLength = 500,
  bool optional = false,
  bool danger = false,
  int lines = 3,
}) => showFormSheet(
  context,
  (_) => _TextForm(
    title: title,
    subtitle: subtitle,
    label: label,
    hint: hint,
    submitLabel: submitLabel,
    minLength: minLength,
    maxLength: maxLength,
    optional: optional,
    danger: danger,
    lines: lines,
    onSend: onSend,
  ),
);

class _TextForm extends StatefulWidget {
  const _TextForm({
    required this.title,
    required this.subtitle,
    required this.label,
    required this.hint,
    required this.submitLabel,
    required this.minLength,
    required this.maxLength,
    required this.optional,
    required this.danger,
    required this.lines,
    required this.onSend,
  });

  final String title;
  final String? subtitle;
  final String label;
  final String hint;
  final String submitLabel;
  final int minLength;
  final int maxLength;
  final bool optional;
  final bool danger;
  final int lines;
  final Send<String> onSend;

  @override
  State<_TextForm> createState() => _TextFormState();
}

class _TextFormState extends State<_TextForm> {
  final _text = TextEditingController();
  String? _problem;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _text.text.trim();
    if (!(widget.optional && value.isEmpty) && value.length < widget.minLength) {
      setState(() => _problem = 'Write at least ${widget.minLength} characters.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final refusal = await widget.onSend(value);
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
      title: widget.title,
      subtitle: widget.subtitle,
      submitLabel: widget.submitLabel,
      danger: widget.danger,
      busy: _busy,
      problem: _problem,
      onSubmit: _submit,
      children: [
        FieldBlock(
          label: widget.label,
          child: TextField(
            key: const ValueKey('form-text'),
            controller: _text,
            minLines: widget.lines,
            maxLines: widget.lines + 3,
            maxLength: widget.maxLength,
            style: MentoringText.formInput,
            decoration: fieldDecoration(widget.hint),
          ),
        ),
      ],
    );
  }
}

/// One to five stars, tappable.
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.value, required this.onChanged, this.size = 30});

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          Semantics(
            button: true,
            label: '$i star${i == 1 ? '' : 's'}',
            selected: i <= value,
            child: InkResponse(
              onTap: () => onChanged(i),
              radius: size / 1.6,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: size,
                  color: i <= value ? MentoringColors.star : AppColors.outline,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A rating, a comment and (for a pairing) "would you recommend": the review
/// the API keeps. Resolves true once sent.
Future<bool> showReviewSheet(
  BuildContext context, {
  required String title,
  required Future<String?> Function(int rating, String comment, bool flag) onSend,
  String? subtitle,
  String? flagLabel,
  bool flagDefault = true,
  int minComment = 0,
}) => showFormSheet(
  context,
  (_) => _ReviewForm(
    title: title,
    subtitle: subtitle,
    flagLabel: flagLabel,
    flagDefault: flagDefault,
    minComment: minComment,
    onSend: onSend,
  ),
);

class _ReviewForm extends StatefulWidget {
  const _ReviewForm({
    required this.title,
    required this.subtitle,
    required this.flagLabel,
    required this.flagDefault,
    required this.minComment,
    required this.onSend,
  });

  final String title;
  final String? subtitle;
  final String? flagLabel;
  final bool flagDefault;
  final int minComment;
  final Future<String?> Function(int rating, String comment, bool flag) onSend;

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  final _comment = TextEditingController();
  int _rating = 0;
  late bool _flag = widget.flagDefault;
  String? _problem;
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _problem = 'Choose a rating from one to five stars.');
      return;
    }
    final comment = _comment.text.trim();
    if (comment.isNotEmpty && comment.length < widget.minComment) {
      setState(() => _problem = 'Write at least ${widget.minComment} characters, or leave the comment empty.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final refusal = await widget.onSend(_rating, comment, _flag);
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
      title: widget.title,
      subtitle: widget.subtitle,
      submitLabel: 'Send review',
      busy: _busy,
      problem: _problem,
      onSubmit: _submit,
      children: [
        FieldBlock(
          label: 'Your rating',
          child: RatingStars(value: _rating, onChanged: (v) => setState(() => _rating = v)),
        ),
        FieldBlock(
          label: 'What was it like? (optional)',
          child: TextField(
            key: const ValueKey('review-comment'),
            controller: _comment,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            style: MentoringText.formInput,
            decoration: fieldDecoration('What helped, and what could be better'),
          ),
        ),
        if (widget.flagLabel != null)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _flag,
            onChanged: (v) => setState(() => _flag = v),
            title: Text(widget.flagLabel!, style: MentoringText.formLabel),
          ),
      ],
    );
  }
}

/// Start times grouped by day, one chip per time; [selected] is lit.
class SlotPicker extends StatelessWidget {
  const SlotPicker({super.key, required this.slots, required this.selected, required this.onSelect, this.limit = 40});

  final List<Slot> slots;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final days = <String, List<Slot>>{};
    for (final s in slots.take(limit)) {
      days.putIfAbsent(dayHeading(s.at), () => []).add(s);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final MapEntry(key: day, value: times) in days.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: Text(day, style: MentoringText.meta.copyWith(color: AppColors.onSurface)),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in times)
                ChoiceChip(
                  label: Text('${timeLabel(s.at)}${s.preferred ? ' ★' : ''}'),
                  selected: selected != null && selected!.isAtSameMomentAs(s.at),
                  onSelected: (_) => onSelect(s.at),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A date then a time from the phone's pickers; null when either is dismissed.
Future<DateTime?> pickDateTime(BuildContext context, {DateTime? initial}) async {
  final now = mentoringNow();
  final start = initial ?? now.add(const Duration(days: 1));
  final day = await showDatePicker(
    context: context,
    initialDate: start,
    firstDate: now,
    lastDate: now.add(const Duration(days: 180)),
  );
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start));
  if (time == null) return null;
  return DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

/// Picks a start time from [slots] (or from the phone's pickers when there
/// are none) and sends it with an optional note. Resolves true once sent.
Future<bool> showTimeSheet(
  BuildContext context, {
  required String title,
  required String submitLabel,
  required Future<List<Slot>> slots,
  required Future<String?> Function(DateTime at, String note) onSend,
  String? subtitle,
  String? noteLabel,
  int noteMax = 300,
}) => showFormSheet(
  context,
  (_) => _TimeForm(
    title: title,
    subtitle: subtitle,
    submitLabel: submitLabel,
    slots: slots,
    noteLabel: noteLabel,
    noteMax: noteMax,
    onSend: onSend,
  ),
);

class _TimeForm extends StatefulWidget {
  const _TimeForm({
    required this.title,
    required this.subtitle,
    required this.submitLabel,
    required this.slots,
    required this.noteLabel,
    required this.noteMax,
    required this.onSend,
  });

  final String title;
  final String? subtitle;
  final String submitLabel;
  final Future<List<Slot>> slots;
  final String? noteLabel;
  final int noteMax;
  final Future<String?> Function(DateTime at, String note) onSend;

  @override
  State<_TimeForm> createState() => _TimeFormState();
}

class _TimeFormState extends State<_TimeForm> {
  final _note = TextEditingController();
  DateTime? _at;
  String? _problem;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickOwn() async {
    final at = await pickDateTime(context, initial: _at);
    if (at != null && mounted) setState(() => _at = at);
  }

  Future<void> _submit() async {
    final at = _at;
    if (at == null) {
      setState(() => _problem = 'Pick a time first.');
      return;
    }
    if (!at.isAfter(mentoringNow())) {
      setState(() => _problem = 'Pick a time in the future.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final refusal = await widget.onSend(at, _note.text.trim());
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
      title: widget.title,
      subtitle: widget.subtitle,
      submitLabel: widget.submitLabel,
      busy: _busy,
      problem: _problem,
      onSubmit: _submit,
      children: [
        FutureBuilder<List<Slot>>(
          future: widget.slots,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              );
            }
            final slots = snap.data ?? const <Slot>[];
            final own = _at != null && !slots.any((s) => s.at.isAtSameMomentAs(_at!));
            return FieldBlock(
              label: slots.isEmpty ? 'When?' : 'Free times',
              help: slots.isEmpty
                  ? 'No open times are listed for the next two weeks; pick a day and time.'
                  : 'On your phone\'s clock.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (slots.isNotEmpty)
                    SlotPicker(slots: slots, selected: _at, onSelect: (at) => setState(() => _at = at)),
                  const SizedBox(height: 8),
                  QuietButton(
                    label: own ? whenLabel(_at!) : (slots.isEmpty ? 'Pick a day and time' : 'Another time'),
                    icon: LucideIcons.calendarClock,
                    onPressed: _pickOwn,
                  ),
                ],
              ),
            );
          },
        ),
        if (widget.noteLabel != null)
          FieldBlock(
            label: widget.noteLabel!,
            child: TextField(
              key: const ValueKey('time-note'),
              controller: _note,
              minLines: 2,
              maxLines: 4,
              maxLength: widget.noteMax,
              style: MentoringText.formInput,
              decoration: fieldDecoration(''),
            ),
          ),
      ],
    );
  }
}
