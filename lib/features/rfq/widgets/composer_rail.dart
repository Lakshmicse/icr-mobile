import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../rfq_links.dart' show RfqClock;
import '../rfq_models.dart';
import '../rfq_rules.dart' show todayIst;
import '../rfq_styles.dart';
import 'rfq_widgets.dart';

/// The website composer's side rail, which follows the form on a phone: the sections ticked as they are completed,
/// what happens after posting, and why the responses are worth waiting for. The words are the website's
/// (`rfq.ProgressCard`, `rfq.WhatHappensNextCard`, `rfq.PostingTrustCard`), "My Requirements" read as the app's
/// "My RFQ's".

/// One section of the composer as the progress card lists it.
class ProgressStep {
  const ProgressStep({required this.id, required this.label, required this.done});

  /// The section's anchor, scrolled to on a tap.
  final String id;
  final String label;
  final bool done;
}

class _RailHeading extends StatelessWidget {
  const _RailHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: RfqText.small.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.8));
}

/// "Your progress": the sections, ticked as they are completed, each a tap away.
class ComposerProgress extends StatelessWidget {
  const ComposerProgress({super.key, required this.steps, required this.onGo});

  final List<ProgressStep> steps;
  final ValueChanged<String> onGo;

  @override
  Widget build(BuildContext context) {
    final done = steps.where((s) => s.done).length;
    final all = steps.isNotEmpty && done == steps.length;
    return RfqCard(
      key: const ValueKey('composer-progress'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: _RailHeading('Your progress')),
              Text('$done of ${steps.length}', style: RfqText.small),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: steps.isEmpty ? 0 : done / steps.length,
              minHeight: 4,
              backgroundColor: AppColors.slate100,
              color: all ? AppColors.emerald700 : AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          for (final s in steps)
            InkWell(
              key: ValueKey('progress-${s.id}'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => onGo(s.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
                child: Row(
                  children: [
                    Icon(
                      s.done ? LucideIcons.circleCheck : LucideIcons.circle,
                      size: 17,
                      color: s.done ? AppColors.emerald700 : AppColors.slate300,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.label,
                        style: RfqText.body.copyWith(color: s.done ? AppColors.slate500 : AppColors.slate900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "12 Sep" for a day picked on the form; null for none, or one already gone (it is not echoed back as a plan).
String? _planDay(DateTime? day) {
  if (day == null) return null;
  final d = DateTime(day.year, day.month, day.day);
  if (d.isBefore(todayIst(RfqClock.now()))) return null;
  return '${d.day} ${_months[d.month - 1]}';
}

/// "What happens next": the steps after posting, numbered, with the dates picked on an RFQ.
class WhatHappensNext extends StatelessWidget {
  const WhatHappensNext({super.key, required this.kind, this.preQualEnd, this.dueDate});

  final RfqKind kind;
  final DateTime? preQualEnd;
  final DateTime? dueDate;

  List<(String, String)> get _steps {
    if (kind != RfqKind.rfq) {
      return const [
        ('You post your requirement', 'Nothing is shared until you send it.'),
        ('Your enquiry goes to matching suppliers', 'Verified suppliers in your cities and category.'),
        ('Suppliers reply', 'With questions, a price or a visit to arrange.'),
        ('Compare replies', "Side by side in My RFQ's."),
        ('Choose a supplier', 'Select the one you want to work with.'),
      ];
    }
    final d1 = _planDay(preQualEnd);
    final d2 = _planDay(dueDate);
    return [
      ('You post your requirement', 'Nothing is shared until you create it.'),
      (
        'Suppliers pre-qualify',
        d1 == null ? 'They answer your criteria first.' : 'They answer your criteria until $d1.',
      ),
      ('You shortlist', 'Only the suppliers you choose move ahead.'),
      ('The shortlist sends quotes', d2 == null ? 'Detailed, itemised and comparable.' : 'Itemised quotes by $d2.'),
      ('Compare and award', "Side by side in My RFQ's."),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    return RfqCard(
      key: const ValueKey('what-happens-next'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _RailHeading('What happens next'),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(color: AppColors.chipEmphasis, shape: BoxShape.circle),
                        child: Text('${i + 1}', style: RfqText.metaStrong.copyWith(color: AppColors.primary)),
                      ),
                      // The line down to the next step.
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 1.5,
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            color: AppColors.slate200,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 2, bottom: i < steps.length - 1 ? 14 : 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(steps[i].$1, style: RfqText.bodyStrong),
                          const SizedBox(height: 2),
                          Text(steps[i].$2, style: RfqText.meta),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "Why ICR": only what the platform does, and what becomes of the member's requirement.
class WhyIcrCard extends StatelessWidget {
  const WhyIcrCard({super.key});

  static const rows = [
    (LucideIcons.shieldCheck, 'Every supplier is verified by ICR'),
    (LucideIcons.receiptText, 'GST, PF/ESI and ISO checked at verification'),
    (LucideIcons.searchCheck, 'Matched by service category and city'),
    (LucideIcons.arrowLeftRight, "Responses compared side by side in My RFQ's"),
    (
      LucideIcons.lock,
      'Your name, phone and email reach a supplier only after it responds, on plans that include them',
    ),
    (LucideIcons.globe, 'Also listed on the public requirements board, without your contact details'),
  ];

  @override
  Widget build(BuildContext context) {
    return RfqCard(
      key: const ValueKey('why-icr'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _RailHeading('Why ICR'),
          const SizedBox(height: 10),
          for (final (icon, text) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(icon, size: 16, color: AppColors.emerald700),
                  ),
                  const SizedBox(width: 9),
                  Expanded(child: Text(text, style: RfqText.body)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
