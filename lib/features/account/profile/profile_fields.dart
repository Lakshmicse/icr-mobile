import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../account_labels.dart';
import '../account_models.dart';
import '../widgets/account_kit.dart';

/// The form pieces the profile sheets share.

// --- suggestions ---------------------------------------------------------------------------------------------

/// A text field with a list of suggestions under it while it has the focus and
/// the text matches (a job title from the staff's list, a company page on ICR).
/// Typing anything else is fine: [onChanged] says so, and a pick calls [onPick].
class SuggestField<T> extends StatefulWidget {
  const SuggestField({
    super.key,
    required this.label,
    required this.controller,
    required this.suggest,
    required this.labelOf,
    this.subtitleOf,
    this.onPick,
    this.onChanged,
    this.fieldKey,
    this.hint,
    this.helper,
    this.error,
    this.maxLength,
    this.required = false,
    this.enabled = true,
    this.minChars = 1,
    this.debounce = Duration.zero,
    this.capitalization = TextCapitalization.words,
  });

  final String label;
  final TextEditingController controller;

  /// What to offer for the text typed. A failure offers nothing.
  final Future<List<T>> Function(String query) suggest;
  final String Function(T) labelOf;
  final String Function(T)? subtitleOf;
  final ValueChanged<T>? onPick;
  final ValueChanged<String>? onChanged;
  final Key? fieldKey;
  final String? hint;
  final String? helper;
  final String? error;
  final int? maxLength;
  final bool required;
  final bool enabled;
  final int minChars;
  final Duration debounce;
  final TextCapitalization capitalization;

  @override
  State<SuggestField<T>> createState() => _SuggestFieldState<T>();
}

class _SuggestFieldState<T> extends State<SuggestField<T>> {
  final _focus = FocusNode();
  Timer? _timer;
  List<T> _found = const [];
  String _for = '';
  String? _picked;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _typed(String text) {
    widget.onChanged?.call(text);
    if (_picked != null && text != _picked) _picked = null;
    _timer?.cancel();
    final q = text.trim();
    if (q.length < widget.minChars) {
      setState(() {
        _found = const [];
        _for = '';
      });
      return;
    }
    Future<void> run() async {
      try {
        final hits = await widget.suggest(q);
        if (!mounted || widget.controller.text.trim() != q) return;
        setState(() {
          _found = hits;
          _for = q;
        });
      } catch (_) {
        // A failed look-up leaves the text as typed.
      }
    }

    if (widget.debounce == Duration.zero) {
      run();
    } else {
      _timer = Timer(widget.debounce, run);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showing = _focus.hasFocus && _picked == null && _found.isNotEmpty && _for == widget.controller.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccountField(
          fieldKey: widget.fieldKey,
          label: widget.label,
          controller: widget.controller,
          focusNode: _focus,
          hint: widget.hint,
          helper: showing ? null : widget.helper,
          error: widget.error,
          maxLength: widget.maxLength,
          required: widget.required,
          enabled: widget.enabled,
          textCapitalization: widget.capitalization,
          onChanged: _typed,
        ),
        if (showing)
          Container(
            key: const Key('suggestions'),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.slate200),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Column(
              children: [
                for (final item in _found.take(6))
                  InkWell(
                    onTap: () {
                      final text = widget.labelOf(item);
                      widget.controller.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
                      setState(() {
                        _picked = text;
                        _found = const [];
                      });
                      widget.onChanged?.call(text);
                      widget.onPick?.call(item);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.labelOf(item), style: AccountText.input.copyWith(fontSize: 16)),
                                if (widget.subtitleOf != null) Text(widget.subtitleOf!(item), style: AccountText.meta),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// --- dates ---------------------------------------------------------------------------------------------------

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// A month and a year, side by side: the month is optional, the year is not
/// (unless [yearOptional]). "Start date", "End date".
class MonthYearField extends StatelessWidget {
  const MonthYearField({
    super.key,
    required this.label,
    required this.month,
    required this.year,
    required this.years,
    required this.onChanged,
    this.error,
    this.required = false,
    this.enabled = true,
    this.keyPrefix = 'date',
  });

  final String label;
  final int? month;
  final int? year;
  final List<int> years;
  final void Function(int? month, int? year) onChanged;
  final String? error;
  final bool required;
  final bool enabled;
  final String keyPrefix;

  Future<void> _pickMonth(BuildContext context) async {
    final picked = await showAccountPicker<int>(
      context,
      title: '$label: month',
      items: [for (var m = 1; m <= 12; m++) m],
      labelOf: (m) => _monthNames[m - 1],
      selected: month,
    );
    if (picked != null) onChanged(picked, year);
  }

  Future<void> _pickYear(BuildContext context) async {
    final picked = await showAccountPicker<int>(
      context,
      title: '$label: year',
      items: years,
      labelOf: (y) => '$y',
      searchable: true,
      selected: year,
    );
    if (picked != null) onChanged(month, picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(required ? '$label *' : label, style: AccountText.label),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _Cell(
                  key: Key('$keyPrefix.month'),
                  text: month == null ? 'Month' : _monthNames[month! - 1],
                  filled: month != null,
                  error: error != null,
                  onTap: enabled ? () => _pickMonth(context) : null,
                  onClear: enabled && month != null ? () => onChanged(null, year) : null,
                  semantics: '$label month',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Cell(
                  key: Key('$keyPrefix.year'),
                  text: year == null ? 'Year' : '$year',
                  filled: year != null,
                  error: error != null,
                  onTap: enabled ? () => _pickYear(context) : null,
                  semantics: '$label year',
                ),
              ),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(error!, style: AccountText.error),
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({super.key, required this.text, required this.filled, required this.error, required this.onTap, this.onClear, required this.semantics});

  final String text;
  final bool filled;
  final bool error;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$semantics, ${filled ? text : 'not set'}',
      excludeSemantics: true,
      child: Material(
        color: onTap == null ? AppColors.slate50 : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: error ? AppColors.error : AppColors.slate300),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 46,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: filled ? AccountText.input : AccountText.hint),
                ),
                if (onClear != null)
                  GestureDetector(
                    onTap: onClear,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.close_rounded, size: 18, color: AppColors.slate500),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.expand_more_rounded, color: AppColors.slate500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A calendar day, chosen from the phone's date picker.
class DateSelectField extends StatelessWidget {
  const DateSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.error,
    this.helper,
    this.first,
    this.last,
    this.fieldKey,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String? error;
  final String? helper;
  final DateTime? first;
  final DateTime? last;
  final Key? fieldKey;

  static String format(DateTime d) => '${d.day} ${monthName(d.month)} ${d.year}';

  @override
  Widget build(BuildContext context) {
    return AccountSelectField(
      key: fieldKey,
      label: label,
      hint: 'Choose a date',
      value: value == null ? null : format(value!),
      error: error,
      helper: helper,
      onClear: () => onChanged(null),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? (last != null && last!.isBefore(now) ? last! : now),
          firstDate: first ?? DateTime(1950),
          lastDate: last ?? DateTime(now.year + 30, 12, 31),
        );
        if (picked != null) onChanged(DateTime(picked.year, picked.month, picked.day));
      },
    );
  }
}

// --- a city --------------------------------------------------------------------------------------------------

/// A place chosen from ICR's cities, with the typed value kept when it is not on
/// the list (a profile saved before, a town the list does not hold).
class CityPickerField extends StatelessWidget {
  const CityPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.loadCities,
    required this.onChanged,
    this.hint = 'Choose a city',
    this.helper,
    this.error,
    this.labelOfCity,
    this.fieldKey,
  });

  final String label;
  final String? value;
  final Future<List<CityOption>> Function() loadCities;
  final ValueChanged<CityOption?> onChanged;
  final String hint;
  final String? helper;
  final String? error;

  /// How a picked city is written into the value: its name, or "Pune, Maharashtra".
  final String Function(CityOption)? labelOfCity;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    return AccountSelectField(
      key: fieldKey,
      label: label,
      hint: hint,
      value: (value ?? '').trim().isEmpty ? null : value,
      helper: helper,
      error: error,
      onClear: () => onChanged(null),
      onTap: () async {
        List<CityOption> cities;
        try {
          cities = await loadCities();
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text("Couldn't load the cities. Check your connection and try again.")));
          return;
        }
        if (!context.mounted) return;
        final picked = await showAccountPicker<CityOption>(
          context,
          title: label,
          items: cities,
          labelOf: (c) => c.name,
          subtitleOf: (c) => c.state ?? '',
          searchable: true,
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

// --- chips ---------------------------------------------------------------------------------------------------

/// Skills or languages: the ones chosen as removable chips, a box to type
/// another, and the suggestions not chosen yet, one tap each.
class ChipEditor extends StatefulWidget {
  const ChipEditor({
    super.key,
    required this.label,
    required this.items,
    required this.onChanged,
    required this.suggestions,
    required this.max,
    required this.maxLength,
    required this.hint,
    this.helper,
    this.error,
    this.suggestionsTitle = 'Suggestions',
  });

  final String label;
  final List<String> items;
  final ValueChanged<List<String>> onChanged;
  final List<String> suggestions;
  final int max;
  final int maxLength;
  final String hint;
  final String? helper;
  final String? error;
  final String suggestionsTitle;

  @override
  State<ChipEditor> createState() => _ChipEditorState();
}

class _ChipEditorState extends State<ChipEditor> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool _has(String s) => widget.items.any((i) => i.toLowerCase() == s.toLowerCase());

  void _add(String raw) {
    final s = raw.trim();
    if (s.isEmpty || _has(s) || widget.items.length >= widget.max) return;
    widget.onChanged([...widget.items, s]);
    _text.clear();
    setState(() {});
  }

  void _remove(String s) => widget.onChanged([
    for (final i in widget.items)
      if (i != s) i,
  ]);

  @override
  Widget build(BuildContext context) {
    final full = widget.items.length >= widget.max;
    final q = _text.text.trim().toLowerCase();
    final offered = [
      for (final s in widget.suggestions)
        if (!_has(s) && (q.isEmpty || s.toLowerCase().contains(q))) s,
    ].take(q.isEmpty ? 12 : 6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in widget.items)
                  InputChip(
                    key: Key('chip.$s'),
                    label: Text(s, style: AccountText.chip.copyWith(fontWeight: FontWeight.w600)),
                    onDeleted: () => _remove(s),
                    deleteButtonTooltipMessage: 'Remove $s',
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.slate300),
                    shape: const StadiumBorder(),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        AccountField(
          fieldKey: const Key('chips.input'),
          label: widget.label,
          controller: _text,
          hint: full ? 'That is the most you can add' : widget.hint,
          enabled: !full,
          maxLength: widget.maxLength,
          error: widget.error,
          helper: widget.helper ?? '${widget.items.length} of ${widget.max}',
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: _add,
          suffix: IconButton(
            key: const Key('chips.add'),
            tooltip: 'Add',
            onPressed: full || _text.text.trim().isEmpty ? null : () => _add(_text.text),
            icon: const Icon(Icons.add_circle_rounded, color: AppColors.primary),
          ),
        ),
        if (offered.isNotEmpty && !full) ...[
          Text(widget.suggestionsTitle, style: AccountText.meta.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in offered)
                ActionChip(
                  key: Key('suggest.$s'),
                  label: Text('+ $s', style: AccountText.chip),
                  onPressed: () => _add(s),
                  backgroundColor: AppColors.slate50,
                  side: const BorderSide(color: AppColors.slate200),
                  shape: const StadiumBorder(),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
