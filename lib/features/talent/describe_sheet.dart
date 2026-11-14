import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/chips.dart';
import '../site/site_kit.dart';
import 'talent_models.dart';

/// The example briefs stay English: a chip both shows and runs its text, and the parser reads English.
const describeExamples = [
  'Senior facility managers in Mumbai with 8+ years, 30 day notice',
  'Remote lease administrators under 15 LPA',
  'Transactions analysts at CBRE or JLL, immediate joiners',
];

/// The website's `NlSearchBar`: describe who you want in plain English and the API turns it into filters. Closes
/// once a brief is read (the screen shows "Read as …"); a brief nothing could be read from, or the API's refusal
/// (a plan without the advanced search), is shown in the sheet.
Future<void> showDescribeSheet(BuildContext context, {required Future<ParsedQuery> Function(String text) describe}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheet) => DescribeSheet(describe: describe),
  );
}

class DescribeSheet extends StatefulWidget {
  const DescribeSheet({super.key, required this.describe});

  final Future<ParsedQuery> Function(String text) describe;

  @override
  State<DescribeSheet> createState() => _DescribeSheetState();
}

class _DescribeSheetState extends State<DescribeSheet> {
  final _text = TextEditingController();
  bool _pending = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _run(String value) async {
    final query = value.trim();
    if (query.length < 3 || _pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final parsed = await widget.describe(query);
      if (!mounted) return;
      if (parsed.matched.isEmpty) {
        setState(() {
          _pending = false;
          _error = 'Unable to read that as filters. Try naming a role, city or experience level.';
        });
        return;
      }
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pending = false;
        _error = ApiError.from(e).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _text,
          builder: (context, value, _) {
            final ready = value.text.trim().length >= 3 && !_pending;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.sparkles, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Describe Who You Want',
                        key: const ValueKey('describe-title'),
                        style: SiteText.heading,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('describe-boolean-help'),
                      tooltip: 'Boolean Search Help',
                      onPressed: () => showBooleanHelp(context),
                      icon: const Icon(LucideIcons.circleQuestionMark, size: 20, color: AppColors.outline),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('describe-input'),
                  controller: _text,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  style: SiteText.body,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _run,
                  decoration: InputDecoration(
                    hintText: 'e.g. Senior facility managers in Mumbai with 8+ years and a 30 day notice period',
                    hintStyle: SiteText.secondary,
                    hintMaxLines: 3,
                    counterText: '',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: const UnderlineInputBorder(borderSide: BorderSide(color: SiteColors.hairline)),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: SiteColors.hairline)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SiteButton(
                        key: const ValueKey('describe-apply'),
                        label: _pending ? 'Reading…' : 'Apply as Filters',
                        busy: _pending,
                        onPressed: ready ? () => _run(_text.text) : null,
                      ),
                    ),
                    if (value.text.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        key: const ValueKey('describe-clear'),
                        onPressed: () => setState(() {
                          _text.clear();
                          _error = null;
                        }),
                        icon: const Icon(LucideIcons.x, size: 16, color: AppColors.onSurfaceVariant),
                        label: Text('Clear', style: SiteText.body),
                      ),
                    ],
                  ],
                ),
                if (value.text.isEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (i, ex) in describeExamples.indexed)
                        IcrChip(
                          key: ValueKey('describe-example-$i'),
                          label: ex,
                          tone: ChipTone.outlined,
                          height: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          textStyle: SiteText.body.copyWith(fontSize: 13),
                          onTap: () {
                            _text.text = ex;
                            _run(ex);
                          },
                        ),
                    ],
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    key: const ValueKey('describe-error'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(LucideIcons.triangleAlert, size: 16, color: AppColors.amber800),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: SiteText.secondary)),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The boolean syntax the API compiles (the website's `BooleanHelp`). The syntax column is what the server parses,
/// so it stays as written.
Future<void> showBooleanHelp(BuildContext context) {
  const rows = <(String, String)>[
    ('facility manager', 'both words must appear'),
    ('"lease administration"', 'exact phrase'),
    ('FM OR facilities', 'either one'),
    ('manager NOT intern', 'exclude a term'),
    ('analyst -junior', 'shorthand for NOT'),
    ('(HVAC OR MEP) AND Mumbai', 'group with parentheses'),
  ];
  return showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      key: const ValueKey('boolean-help'),
      backgroundColor: Colors.white,
      title: Text('Boolean Search', style: SiteText.heading),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Type these into the search box. Operators must be UPPERCASE, so the word “and” still searches normally.',
            style: SiteText.secondary,
          ),
          const SizedBox(height: 12),
          for (final (syntax, meaning) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(syntax, style: SiteText.body.copyWith(fontFamily: 'monospace', fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(meaning, style: SiteText.meta)),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: Text('Close', style: SiteText.link),
        ),
      ],
    ),
  );
}
