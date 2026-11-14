import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../learning_exam/exam_format.dart' show dayLabel;
import '../site/site_kit.dart';
import 'partner_console_kit.dart';
import 'partner_console_models.dart';
import 'partner_console_rules.dart';

/// One enrolment in full, and the decision on it (the website's `EnrolmentDialog`): who applied, for which course
/// and batch, when, what they wrote — with Cancel enrolment and Confirm place at the foot for those who may decide.
/// Returns the status chosen (`CONFIRMED` or `CANCELLED`), or null.
Future<String?> showEnrolmentSheet(BuildContext context, {required ConsoleEnrolment enrolment, required bool canEdit}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheet) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.9),
      child: _EnrolmentView(e: enrolment, canEdit: canEdit),
    ),
  );
}

class _EnrolmentView extends StatelessWidget {
  const _EnrolmentView({required this.e, required this.canEdit});

  final ConsoleEnrolment e;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.name, key: const Key('enrolmentView.name'), style: SiteText.heading),
              const SizedBox(height: 2),
              Text(e.email, style: SiteText.meta),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConsoleChip(label: enrolmentStatusLabel(e.status), tone: enrolmentStatusTone(e.status), filled: true),
                const SizedBox(height: 16),
                Fact(label: 'Course', value: '${e.courseCode} · ${e.courseTitle}'),
                const SizedBox(height: 12),
                FactGrid(
                  facts: [
                    Fact(label: 'Batch', value: e.batchId == null ? 'Single cohort' : (e.batchTitle ?? '—')),
                    if (e.batchMode != null) Fact(label: 'Mode', value: deliveryModeLabel(e.batchMode!)),
                    Fact(label: 'Starts', value: e.batchStartsAt == null ? '—' : batchDayLabel(e.batchStartsAt)),
                    Fact(label: 'Applied', value: dayLabel(e.createdAt)),
                    if (e.decidedAt != null) Fact(label: 'Decided', value: dayLabel(e.decidedAt)),
                  ],
                ),
                Fact(
                  label: 'Note from the Candidate',
                  value: e.note?.trim().isNotEmpty == true ? e.note!.trim() : '—',
                  strong: false,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
              if (canEdit && e.status != 'CANCELLED')
                OutlinedButton.icon(
                  key: const Key('enrolment.cancel'),
                  onPressed: () => Navigator.of(context).pop('CANCELLED'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rose600,
                    side: const BorderSide(color: AppColors.rose600),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.highlight_off_rounded, size: 18),
                  label: const Text('Cancel Enrolment'),
                ),
              if (canEdit && e.status != 'CONFIRMED')
                FilledButton.icon(
                  key: const Key('enrolment.confirm'),
                  onPressed: () => Navigator.of(context).pop('CONFIRMED'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary, shape: const StadiumBorder()),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Confirm Place'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
