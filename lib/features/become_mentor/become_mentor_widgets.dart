import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../mentorship_my/widgets/forms.dart';
import '../mentorship_my/widgets/kit.dart';

/// What every sheet of this flow does: check what was typed, send it, stay open (with what was typed and the
/// API's own sentence) when it is refused, close when it went through.
mixin SheetState<T extends StatefulWidget> on State<T> {
  bool busy = false;
  String? problem;

  /// [check] answers a sentence for what is wrong before anything is sent, or null. [action] answers the API's
  /// refusal, or null once it went through.
  Future<void> send(String? Function() check, Future<String?> Function() action) async {
    final bad = check();
    if (bad != null) {
      setState(() => problem = bad);
      return;
    }
    setState(() {
      busy = true;
      problem = null;
    });
    final refusal = await action();
    if (!mounted) return;
    if (refusal != null) {
      setState(() {
        busy = false;
        problem = refusal;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  Widget frame({
    required String title,
    required List<Widget> children,
    required String submitLabel,
    required VoidCallback? onSubmit,
    String? subtitle,
    bool danger = false,
  }) => MentoringForm(
    title: title,
    subtitle: subtitle,
    submitLabel: submitLabel,
    busy: busy,
    problem: problem,
    danger: danger,
    onSubmit: onSubmit,
    children: children,
  );
}

/// A list of short texts (topics, roles, languages): type one and add it, tap a suggestion to add it, tap a chip's
/// cross to take it away. At most [max] items, each at most [itemMax] characters.
class TextChipEditor extends StatefulWidget {
  const TextChipEditor({
    super.key,
    required this.items,
    required this.onChanged,
    required this.max,
    this.suggestions = const [],
    this.hint = 'Type and press Add',
    this.itemMax = 100,
    this.fieldKey,
    this.error,
  });

  final List<String> items;
  final ValueChanged<List<String>> onChanged;
  final int max;
  final List<String> suggestions;
  final String hint;
  final int itemMax;
  final Key? fieldKey;
  final String? error;

  @override
  State<TextChipEditor> createState() => _TextChipEditorState();
}

class _TextChipEditorState extends State<TextChipEditor> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _full => widget.items.length >= widget.max;

  void _add(String raw) {
    final t = raw.trim();
    if (t.isEmpty || _full) return;
    if (widget.items.any((i) => i.toLowerCase() == t.toLowerCase())) {
      _text.clear();
      return;
    }
    widget.onChanged([...widget.items, t.length > widget.itemMax ? t.substring(0, widget.itemMax) : t]);
    _text.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final typed = _text.text.trim().toLowerCase();
    final shown = [
      for (final s in widget.suggestions)
        if (!widget.items.any((i) => i.toLowerCase() == s.toLowerCase()) &&
            (typed.isEmpty || s.toLowerCase().contains(typed)))
          s,
    ].take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final i in widget.items)
                  InputChip(
                    key: ValueKey('chip-$i'),
                    label: Text(i),
                    onDeleted: () => widget.onChanged([...widget.items]..remove(i)),
                    deleteButtonTooltipMessage: 'Remove $i',
                  ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: widget.fieldKey,
                controller: _text,
                enabled: !_full,
                maxLength: widget.itemMax,
                style: MentoringText.formInput,
                onChanged: (_) => setState(() {}),
                onSubmitted: _add,
                decoration: fieldDecoration(
                  _full ? 'That is the most you can add (${widget.max})' : widget.hint,
                ).copyWith(counterText: ''),
              ),
            ),
            const SizedBox(width: 8),
            QuietButton(
              label: 'Add',
              icon: LucideIcons.plus,
              onPressed: _full || typed.isEmpty ? null : () => _add(_text.text),
            ),
          ],
        ),
        if (shown.isNotEmpty && !_full)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in shown)
                  ActionChip(key: ValueKey('suggest-$s'), label: Text(s), onPressed: () => _add(s)),
              ],
            ),
          ),
        if (widget.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(widget.error!, style: MentoringText.error),
          ),
      ],
    );
  }
}

/// Choose from a long list by searching it: the chosen ones lead, tapping a chip chooses or drops it, at most [max].
class OptionPicker extends StatefulWidget {
  const OptionPicker({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.max,
    this.searchHint = 'Search',
    this.error,
  });

  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final int max;
  final String searchHint;
  final String? error;

  @override
  State<OptionPicker> createState() => _OptionPickerState();
}

class _OptionPickerState extends State<OptionPicker> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(String o, bool on) {
    if (on && widget.selected.length >= widget.max) return;
    final next = [...widget.selected];
    on ? next.add(o) : next.remove(o);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    // A chosen value that is not in the list (an older, free-typed one) stays visible so it can be dropped.
    final all = [...widget.selected, ...widget.options.where((o) => !widget.selected.contains(o))];
    final shown = [
      for (final o in all)
        if (q.isEmpty || o.toLowerCase().contains(q)) o,
    ];
    final full = widget.selected.length >= widget.max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('option-search'),
          controller: _search,
          style: MentoringText.formInput,
          onChanged: (_) => setState(() {}),
          decoration: fieldDecoration(widget.searchHint).copyWith(prefixIcon: const Icon(LucideIcons.search, size: 16)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final o in shown)
              FilterChip(
                key: ValueKey('option-$o'),
                label: Text(o),
                selected: widget.selected.contains(o),
                onSelected: !widget.selected.contains(o) && full ? null : (on) => _toggle(o, on),
              ),
          ],
        ),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Nothing matches.', style: MentoringText.meta),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            full
                ? '${widget.max} of ${widget.max} chosen: the most you can pick.'
                : '${widget.selected.length} chosen, up to ${widget.max}.',
            style: MentoringText.meta.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
        if (widget.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(widget.error!, style: MentoringText.error),
          ),
      ],
    );
  }
}

/// A tick or an empty ring beside a line: the application's steps and the training modules.
class GateRow extends StatelessWidget {
  const GateRow({super.key, required this.done, required this.label, this.caption});

  final bool done;
  final String label;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          done ? LucideIcons.circleCheck : LucideIcons.circle,
          size: 18,
          color: done ? MentoringColors.green : AppColors.outline,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: MentoringText.bodyStrong),
              if (caption != null) Text(caption!, style: MentoringText.meta),
            ],
          ),
        ),
      ],
    );
  }
}

/// A card of the composer: a title, what it holds (or why it is empty), and one button that opens its sheet.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.onEdit,
    required this.editLabel,
    required this.child,
    this.subtitle,
    this.cardKey,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final String editLabel;
  final VoidCallback? onEdit;
  final Widget child;
  final Key? cardKey;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return MentoringCard(
      key: cardKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: MentoringText.cardTitle)),
              ?trailing,
              if (onEdit != null)
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(editLabel, style: MentoringText.buttonQuiet),
                  ),
                ),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle!, style: MentoringText.meta),
            ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// A small caps label over a value ("MENTEES AT A TIME", "2").
class FactLine extends StatelessWidget {
  const FactLine(this.label, this.value, {super.key});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: MentoringText.pill.copyWith(color: AppColors.outline, letterSpacing: 0.6)),
          const SizedBox(height: 2),
          value,
        ],
      ),
    );
  }
}
