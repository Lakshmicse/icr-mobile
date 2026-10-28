import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/detail_sheet.dart';
import 'study_format.dart';
import 'study_models.dart';
import 'study_styles.dart';
import 'widgets/formula_math.dart';

/// One formula as the sheet shows it, with where it sits in the list the sheet pages through.
class FormulaEntry {
  const FormulaEntry({required this.card, required this.shelf, required this.number});

  final StudyCard card;

  /// The group it belongs to ("Time Value of Money").
  final String shelf;

  /// Its place in that group, as the row's number.
  final int number;
}

/// A formula in full over the Knowledge Center: its name and group, the expression drawn as math, what the symbols
/// stand for, the worked examples (the figures, the working, the answer, what it means and what to do), and "Copy".
/// Previous and next page through [entries] (the list the person was looking at), starting at [index].
Future<void> showFormulaSheet(BuildContext context, {required List<FormulaEntry> entries, required int index}) {
  final at = ValueNotifier<int>(index.clamp(0, entries.length - 1));
  return showDetailSheet<void>(
    context,
    body: (_) => ValueListenableBuilder<int>(
      valueListenable: at,
      builder: (_, i, _) =>
          FormulaDetail(key: ValueKey(entries[i].card.id), entry: entries[i], position: i + 1, total: entries.length),
    ),
    bottomBar: (_) => ValueListenableBuilder<int>(
      valueListenable: at,
      builder: (_, i, _) => FormulaBar(
        entry: entries[i],
        hasPrevious: i > 0,
        hasNext: i < entries.length - 1,
        onPrevious: () => at.value = i - 1,
        onNext: () => at.value = i + 1,
      ),
    ),
  ).whenComplete(at.dispose);
}

/// The sheet's scrolling body.
class FormulaDetail extends StatelessWidget {
  const FormulaDetail({super.key, required this.entry, required this.position, required this.total});

  final FormulaEntry entry;
  final int position;
  final int total;

  @override
  Widget build(BuildContext context) {
    final card = entry.card;
    final parts = splitBack(card.back);
    final expression = parseExpression(parts.expression);
    final variables = parts.note.isEmpty ? null : parseVariables(parts.note);
    final examples = examplesOf(card);
    final count = examples.parts.length + examples.text.length;
    return ListView(
      key: const ValueKey('formula-detail'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Row(
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.chipEmphasis, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  entry.shelf,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: StudyText.faceLabel.copyWith(letterSpacing: 0.1),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('$position of $total', key: const ValueKey('formula-position'), style: StudyText.shelfCount),
          ],
        ),
        const SizedBox(height: 10),
        Text(card.front, key: const ValueKey('formula-title'), style: StudyText.sheetTitle),
        const SizedBox(height: 18),
        _Block(
          title: 'Formula',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            decoration: BoxDecoration(
              color: StudyColors.formulaPlate,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: StudyColors.formulaPlateBorder),
            ),
            child: FormulaMath(expression: expression, fontSize: 22),
          ),
        ),
        if (variables != null) ...[
          const SizedBox(height: 20),
          _Block(
            title: 'Where',
            child: Column(
              key: const ValueKey('formula-variables'),
              children: [for (final v in variables) _VariableRow(variable: v)],
            ),
          ),
        ] else if (parts.note.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(parts.note, key: const ValueKey('formula-note'), style: StudyText.body),
        ],
        for (var i = 0; i < examples.parts.length; i++) ...[
          const SizedBox(height: 22),
          _Block(
            title: count > 1 ? 'Worked example ${i + 1}' : 'Worked example',
            child: _ExampleCard(example: examples.parts[i]),
          ),
        ],
        for (var i = 0; i < examples.text.length; i++) ...[
          const SizedBox(height: 22),
          _Block(
            title: count > 1 ? 'Worked example ${i + 1}' : 'Worked example',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: StudyColors.border),
              ),
              child: Text(examples.text[i], style: StudyText.body),
            ),
          ),
        ],
        if (card.tags.isNotEmpty) ...[
          const SizedBox(height: 22),
          _Block(
            title: 'Related',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in card.tags)
                  Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: StudyColors.border),
                    ),
                    child: Text(t, style: StudyText.faceTag),
                  ),
              ],
            ),
          ),
        ],
        if (card.resourceUrl != null) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('formula-resource'),
              onPressed: () => openUrl(context, Uri.parse(card.resourceUrl!)),
              icon: const Icon(LucideIcons.fileText, size: 16),
              label: Text(card.resourceLabel ?? 'Open resource'),
            ),
          ),
        ],
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: StudyText.blockTitle)),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _VariableRow extends StatelessWidget {
  const _VariableRow({required this.variable});

  final FormulaVariable variable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.chipEmphasis, borderRadius: BorderRadius.circular(8)),
            child: Text(variable.symbol, style: StudyText.symbol),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(variable.meaning, style: StudyText.bodyStrong.copyWith(fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }
}

/// One worked example, laid out down the phone: the figures it starts from, the working, the answer, then what
/// it means and what to do about it.
class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.example});

  final FormulaExample example;

  @override
  Widget build(BuildContext context) {
    final given = example.given.where((g) => g.label.isNotEmpty || g.value.isNotEmpty).toList();
    final working = example.working;
    final result = example.result;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StudyColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (given.isNotEmpty)
            Container(
              color: AppColors.slate50,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Given', style: StudyText.bodyStrong),
                  const SizedBox(height: 8),
                  for (final g in given)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(child: Text(g.label, style: StudyText.body)),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(g.value, textAlign: TextAlign.right, style: StudyText.bodyStrong),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (working != null || result != null)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (working != null) ...[
                    Text('Working', style: StudyText.bodyStrong),
                    const SizedBox(height: 6),
                    SelectableText(working, style: StudyText.mono),
                  ],
                  if (result != null) ...[
                    if (working != null) const SizedBox(height: 12),
                    Container(
                      key: const ValueKey('example-result'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: StudyColors.formulaPlate,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: StudyColors.formulaPlateBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Result', style: StudyText.resultLabel),
                          const SizedBox(height: 2),
                          Text(result, style: StudyText.result),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (example.analysis != null || example.decision != null)
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: StudyColors.border)),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (example.analysis != null) ...[
                    Text('Analysis', style: StudyText.bodyStrong),
                    const SizedBox(height: 4),
                    Text(example.analysis!, style: StudyText.body),
                  ],
                  if (example.decision != null) ...[
                    if (example.analysis != null) const SizedBox(height: 12),
                    Container(
                      key: const ValueKey('example-decision'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: StudyColors.greenFill.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: StudyColors.greenInk.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(Symbols.task_alt, size: 20, color: StudyColors.greenInk),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Decision', style: StudyText.decisionLabel),
                                const SizedBox(height: 2),
                                Text(example.decision!, style: StudyText.body.copyWith(color: AppColors.onSurface)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The pinned bar: previous, Copy (the formula as text), next.
class FormulaBar extends StatefulWidget {
  const FormulaBar({
    super.key,
    required this.entry,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
  });

  final FormulaEntry entry;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  State<FormulaBar> createState() => _FormulaBarState();
}

class _FormulaBarState extends State<FormulaBar> {
  bool _copied = false;

  @override
  void didUpdateWidget(FormulaBar old) {
    super.didUpdateWidget(old);
    if (old.entry.card.id != widget.entry.card.id) _copied = false;
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: formulaCopyText(widget.entry.card)));
    if (!mounted) return;
    setState(() => _copied = true);
    // A snackbar would sit behind the sheet, so the button itself says it.
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return BottomActionBar(
      children: [
        _Step(
          key: const ValueKey('formula-previous'),
          label: 'Previous formula',
          icon: Symbols.arrow_back,
          onPressed: widget.hasPrevious ? widget.onPrevious : null,
        ),
        Expanded(
          child: PrimaryButton(
            key: const ValueKey('formula-copy'),
            label: _copied ? 'Copied' : 'Copy formula',
            icon: _copied ? Symbols.check : Symbols.content_copy,
            iconSize: 18,
            onPressed: _copy,
          ),
        ),
        _Step(
          key: const ValueKey('formula-next'),
          label: 'Next formula',
          icon: Symbols.arrow_forward,
          onPressed: widget.hasNext ? widget.onNext : null,
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({super.key, required this.label, required this.icon, required this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, size: 22, weight: 600, color: enabled ? AppColors.onSurface : AppColors.slate300),
          ),
        ),
      ),
    );
  }
}
