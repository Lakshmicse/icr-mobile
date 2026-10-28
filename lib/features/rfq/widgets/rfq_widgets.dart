import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../rfq_models.dart';
import '../rfq_styles.dart';

/// A white card with the slate hairline.
class RfqCard extends StatelessWidget {
  const RfqCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final inner = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: rfqCardDecoration,
      child: onTap == null
          ? inner
          : Material(
              color: Colors.transparent,
              child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: inner),
            ),
    );
  }
}

/// A short word in a tinted pill ("Live", "Shortlisted").
class TonePill extends StatelessWidget {
  const TonePill(this.label, {super.key, this.tone = Tone.slate, this.icon});

  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: tone.fill, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, color: tone.ink), const SizedBox(width: 4)],
          Text(label, style: RfqText.pill.copyWith(color: tone.ink)),
        ],
      ),
    );
  }
}

Tone statusTone(RfqStatus s) => switch (s) {
  RfqStatus.draft => Tone.slate,
  RfqStatus.published => Tone.green,
  RfqStatus.awarded => Tone.blue,
  RfqStatus.closed => Tone.slate,
  RfqStatus.cancelled => Tone.red,
};

Tone bidTone(BidStatus s) => switch (s) {
  BidStatus.pending => Tone.amber,
  BidStatus.shortlisted => Tone.blue,
  BidStatus.rejected => Tone.slate,
  BidStatus.awarded => Tone.green,
};

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});

  final RfqStatus status;

  @override
  Widget build(BuildContext context) => TonePill(status.label, tone: statusTone(status));
}

/// The square logo tile of a company, or its initials.
class LogoTile extends StatelessWidget {
  const LogoTile({super.key, required this.name, this.logoUrl, this.size = 40});

  final String name;
  final String? logoUrl;
  final double size;

  String get _initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.absoluteUrl(logoUrl);
    final initials = Center(
      child: Text(_initials, style: RfqText.metaStrong.copyWith(color: AppColors.primary, fontSize: size * 0.32)),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFD6E2EE),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: url == null
          ? initials
          : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, errorWidget: (_, _, _) => initials),
    );
  }
}

/// Loading, an error with "Try again", or nothing there: one notice for all three.
class RfqNotice extends StatelessWidget {
  const RfqNotice({
    super.key,
    required this.title,
    this.body,
    this.icon = LucideIcons.fileText,
    this.action,
    this.onAction,
    this.secondary,
    this.onSecondary,
  });

  final String title;
  final String? body;
  final IconData icon;
  final String? action;
  final VoidCallback? onAction;
  final String? secondary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(color: AppColors.slate100, shape: BoxShape.circle),
            child: Icon(icon, size: 24, color: AppColors.slate500),
          ),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: RfqText.section),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(body!, textAlign: TextAlign.center, style: RfqText.body.copyWith(color: AppColors.slate600)),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(action!, style: RfqText.tab.copyWith(color: Colors.white)),
            ),
          ],
          if (secondary != null) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: onSecondary,
              child: Text(secondary!, style: RfqText.link),
            ),
          ],
        ],
      ),
    );
  }
}

class RfqSpinner extends StatelessWidget {
  const RfqSpinner({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(width: size, height: size, child: const CircularProgressIndicator(strokeWidth: 2.4)),
  );
}

/// The Supplier Overview's tabs: pills, the one on show filled blue.
class PillTabs<T> extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
    this.countOf,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelect;
  final int? Function(T)? countOf;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final v = values[i];
          final on = v == selected;
          final count = countOf?.call(v);
          final label = count == null ? labelOf(v) : '${labelOf(v)} $count';
          final shape = StadiumBorder(side: BorderSide(color: on ? AppColors.primary : AppColors.slate200));
          return Semantics(
            selected: on,
            button: true,
            child: Material(
              color: on ? AppColors.primary : Colors.white,
              shape: shape,
              child: InkWell(
                customBorder: shape,
                onTap: () => onSelect(v),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    widthFactor: 1,
                    child: Text(label, style: RfqText.tab.copyWith(color: on ? Colors.white : AppColors.slate700)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A label and its value, one line of a fact sheet.
class FactRow extends StatelessWidget {
  const FactRow({super.key, required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.slate500),
          const SizedBox(width: 10),
          SizedBox(width: 108, child: Text(label, style: RfqText.meta)),
          Expanded(child: Text(value, style: RfqText.metaStrong)),
        ],
      ),
    );
  }
}

/// A heading over a block of a page.
class RfqSectionTitle extends StatelessWidget {
  const RfqSectionTitle(this.title, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 10)});

  final String title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Text(title, style: RfqText.section)),
          ?trailing,
        ],
      ),
    );
  }
}

/// The match score in a ring ("82 match").
class MatchRing extends StatelessWidget {
  const MatchRing({super.key, required this.score, this.size = 40});

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final value = (score.clamp(0, 100)) / 100;
    final color = score >= 60 ? AppColors.emerald700 : (score >= 35 ? AppColors.amber500 : AppColors.slate400);
    return Semantics(
      label: 'Match $score',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 3,
                backgroundColor: AppColors.slate100,
                color: color,
              ),
            ),
            Text('$score', style: RfqText.metaStrong.copyWith(fontSize: size * 0.3, color: color)),
          ],
        ),
      ),
    );
  }
}

/// Asks before a move that cannot be undone; true when confirmed.
Future<bool> confirmMove(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  String keep = 'Keep it',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(title, style: RfqText.sheetTitle),
      content: Text(body, style: RfqText.body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(keep, style: RfqText.link)),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: destructive ? AppColors.error : AppColors.primary),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// One choice from a list, in a sheet with a search when the list is long.
/// Null when the sheet is dismissed; `(value: null)` for [clearLabel].
Future<({T? value})?> pickOne<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required String Function(T) labelOf,
  T? selected,
  String? clearLabel,
}) {
  return showModalBottomSheet<({T? value})>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => _PickOneSheet<T>(
      title: title,
      options: options,
      labelOf: labelOf,
      selected: selected,
      clearLabel: clearLabel,
    ),
  );
}

class _PickOneSheet<T> extends StatefulWidget {
  const _PickOneSheet({
    required this.title,
    required this.options,
    required this.labelOf,
    this.selected,
    this.clearLabel,
  });

  final String title;
  final List<T> options;
  final String Function(T) labelOf;
  final T? selected;
  final String? clearLabel;

  @override
  State<_PickOneSheet<T>> createState() => _PickOneSheetState<T>();
}

class _PickOneSheetState<T> extends State<_PickOneSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.options
        : [for (final o in widget.options) if (widget.labelOf(o).toLowerCase().contains(q)) o];
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * (widget.options.length > 8 ? 0.75 : 0.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(widget.title, style: RfqText.sheetTitle),
            ),
            if (widget.options.length > 8)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => _query = v),
                  style: RfqText.formInput,
                  decoration: rfqInputDecoration(hint: 'Search', prefix: LucideIcons.search),
                ),
              ),
            Expanded(
              child: ListView(
                children: [
                  if (widget.clearLabel != null)
                    ListTile(
                      title: Text(widget.clearLabel!, style: RfqText.body.copyWith(color: AppColors.slate500)),
                      onTap: () => Navigator.pop(context, (value: null)),
                    ),
                  for (final o in shown)
                    ListTile(
                      title: Text(widget.labelOf(o), style: RfqText.body.copyWith(color: AppColors.slate900)),
                      trailing: o == widget.selected ? const Icon(LucideIcons.check, size: 18, color: AppColors.primary) : null,
                      onTap: () => Navigator.pop(context, (value: o)),
                    ),
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Nothing matches', textAlign: TextAlign.center, style: RfqText.meta),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The forms' outlined input look.
InputDecoration rfqInputDecoration({String? hint, String? error, IconData? prefix, String? prefixText, String? suffixText}) =>
    InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: RfqText.formHint,
      errorText: error,
      errorMaxLines: 3,
      prefixIcon: prefix == null ? null : Icon(prefix, size: 18, color: AppColors.slate400),
      prefixText: prefixText,
      suffixText: suffixText,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.slate200)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.slate200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );

/// A labelled text box that keeps its own controller in step with the value.
class RfqField extends StatefulWidget {
  const RfqField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.help,
    this.error,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.prefixText,
    this.suffixText,
    this.readOnly = false,
    this.optional = false,
    this.fieldKey,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final String? help;
  final String? error;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final String? prefixText;
  final String? suffixText;
  final bool readOnly;
  final bool optional;

  /// Finds the box in a test.
  final Key? fieldKey;

  @override
  State<RfqField> createState() => _RfqFieldState();
}

class _RfqFieldState extends State<RfqField> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(RfqField old) {
    super.didUpdateWidget(old);
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(widget.label, optional: widget.optional),
        const SizedBox(height: 6),
        TextField(
          key: widget.fieldKey,
          controller: _controller,
          onChanged: widget.onChanged,
          readOnly: widget.readOnly,
          keyboardType: widget.keyboardType,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          maxLength: widget.maxLength,
          style: RfqText.formInput.copyWith(color: widget.readOnly ? AppColors.slate500 : null),
          decoration: rfqInputDecoration(
            hint: widget.hint,
            error: widget.error,
            prefixText: widget.prefixText,
            suffixText: widget.suffixText,
          ),
        ),
        if (widget.help != null && widget.error == null) ...[
          const SizedBox(height: 4),
          Text(widget.help!, style: RfqText.formHelp),
        ],
      ],
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.label, {super.key, this.optional = false});

  final String label;
  final bool optional;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      text: label,
      style: RfqText.formLabel,
      children: [if (optional) TextSpan(text: '  Optional', style: RfqText.formHelp)],
    ),
  );
}

/// A box that opens a picker, showing what is chosen.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.hint = 'Select',
    this.error,
    this.help,
    this.optional = false,
    this.enabled = true,
    this.icon = LucideIcons.chevronDown,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final String hint;
  final String? error;
  final String? help;
  final bool optional;
  final bool enabled;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final empty = value == null || value!.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label, optional: optional),
        const SizedBox(height: 6),
        Semantics(
          button: true,
          label: label,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(minHeight: 46),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: enabled ? Colors.white : AppColors.slate50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: error != null ? AppColors.error : AppColors.slate200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      empty ? hint : value!,
                      style: empty ? RfqText.formHint : RfqText.formInput,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(icon, size: 18, color: AppColors.slate500),
                ],
              ),
            ),
          ),
        ),
        if (error != null) ...[const SizedBox(height: 4), Text(error!, style: RfqText.error)],
        if (error == null && help != null) ...[const SizedBox(height: 4), Text(help!, style: RfqText.formHelp)],
      ],
    );
  }
}

/// A notice band: the API's refusal, or a note.
class RfqBanner extends StatelessWidget {
  const RfqBanner(this.message, {super.key, this.tone = Tone.red, this.icon = LucideIcons.circleAlert, this.action, this.onAction});

  final String message;
  final Tone tone;
  final IconData icon;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: tone.fill, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 16, color: tone.ink)),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: RfqText.meta.copyWith(color: tone.ink))),
          if (action != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onAction,
              child: Text(action!, style: RfqText.link.copyWith(color: tone.ink, decoration: TextDecoration.underline)),
            ),
          ],
        ],
      ),
    );
  }
}
