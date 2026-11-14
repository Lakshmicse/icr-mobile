import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../site/site_kit.dart';
import 'partner_console_kit.dart';
import 'partner_console_models.dart';
import 'partner_console_rules.dart';

/// What the viewer chose at the foot of the batch view.
enum BatchViewAction { edit, delete }

/// Everything about one batch (the website's `BatchViewDialog`), for the eye on its row — which itself shows only
/// the name, start, seats and status. Read-only; the foot offers Edit and Delete to a viewer who may change
/// batches. Returns what was chosen, or null.
Future<BatchViewAction?> showBatchViewSheet(
  BuildContext context, {
  required ConsoleCourse course,
  required ConsoleBatch batch,
  required bool canEdit,
  DateTime? now,
}) {
  return showModalBottomSheet<BatchViewAction>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheet) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.9),
      child: _BatchView(course: course, batch: batch, canEdit: canEdit, now: now),
    ),
  );
}

class _BatchView extends StatelessWidget {
  const _BatchView({required this.course, required this.batch, required this.canEdit, this.now});

  final ConsoleCourse course;
  final ConsoleBatch batch;
  final bool canEdit;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final b = batch;
    final status = shownBatchStatus(b, now: now);
    final length = b.durationLabel ?? _duration(b);
    final price = b.priceAmount ?? course.priceAmount;
    final places = b.trainerPlaces;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.name, key: const Key('batchView.title'), style: SiteText.heading),
              const SizedBox(height: 2),
              Text('${course.code} · ${course.title} · ${b.code}', style: SiteText.meta),
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
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ConsoleChip(
                      label: batchStatusLabel(status),
                      tone: batchStatusTone(status),
                      filled: status == 'OPEN',
                    ),
                    ConsoleChip(label: deliveryModeLabel(b.mode), tone: ConsoleTone.muted),
                    if (length != null) ConsoleChip(label: length, tone: ConsoleTone.muted),
                  ],
                ),
                const SizedBox(height: 18),
                const ConsoleHeading('Schedule'),
                FactGrid(
                  facts: [
                    Fact(label: 'Starts', value: batchDayLabel(b.startsAt)),
                    Fact(label: 'Ends', value: b.endsAt == null ? '—' : batchDayLabel(b.endsAt)),
                    Fact(
                      label: 'Enrolment Closes',
                      value: b.enrollmentClosesAt == null ? 'When the batch starts' : _moment(b.enrollmentClosesAt!),
                    ),
                    Fact(label: 'Classes', value: b.schedule ?? '—'),
                    Fact(label: 'Time Zone', value: b.timezone ?? '—'),
                    if (b.location != null) Fact(label: 'Venue', value: b.location!),
                  ],
                ),
                if (b.meetingUrl != null) ...[
                  Fact(label: 'Joining Link', value: b.meetingUrl!),
                  const SizedBox(height: 12),
                ],
                const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
                const SizedBox(height: 14),
                const ConsoleHeading('Seats and Price'),
                FactGrid(
                  facts: [
                    Fact(
                      label: 'Enrolled',
                      value: b.seatsCapacity == null
                          ? '${b.seatsTaken} · uncapped'
                          : '${b.seatsTaken} of ${b.seatsCapacity}',
                    ),
                    Fact(label: 'Seats Held Back', value: '${b.reservedSeats}'),
                    Fact(label: 'Waitlist', value: b.waitlistEnabled ? 'On when full' : 'Off'),
                    Fact(label: 'Price', value: price == null || price == 0 ? 'Free' : rupees(price)),
                    if (b.discountPercent > 0)
                      Fact(
                        label: 'Offer',
                        value:
                            '${b.discountPercent}% off${b.discountEndsOn != null ? ' until ${dayWords(b.discountEndsOn)}' : ''}',
                      ),
                  ],
                ),
                const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
                const SizedBox(height: 14),
                const ConsoleHeading('Team'),
                if (course.providerId != null)
                  if (places.isEmpty)
                    Text('No trainer named yet.', style: SiteText.secondary)
                  else
                    for (final p in places)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(child: Text(p.name, style: SiteText.strong)),
                            Text('Trainer', style: SiteText.meta),
                            const SizedBox(width: 8),
                            ConsoleChip(label: trainerAnswerLabel(p.status), tone: trainerAnswerTone(p.status)),
                          ],
                        ),
                      )
                else
                  Text(
                    b.instructor != null
                        ? '${b.instructor}${b.instructorTitle != null ? ' — ${b.instructorTitle}' : ''}'
                        : 'No mentor named yet.',
                    style: SiteText.body,
                  ),
                if (b.enrolmentSpecialistName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(b.enrolmentSpecialistName!, style: SiteText.strong)),
                        Text('Specialist – Program Enrollment', style: SiteText.meta),
                      ],
                    ),
                  ),
                if (b.notes != null) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
                  const SizedBox(height: 14),
                  const ConsoleHeading('Notes'),
                  Text(b.notes!, style: SiteText.body),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: SiteColors.hairline),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              if (canEdit)
                TextButton.icon(
                  key: const Key('batchView.delete'),
                  onPressed: () => Navigator.of(context).pop(BatchViewAction.delete),
                  style: TextButton.styleFrom(foregroundColor: AppColors.rose600),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete'),
                ),
              const Spacer(),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
              if (canEdit) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const Key('batchView.edit'),
                  onPressed: () => Navigator.of(context).pop(BatchViewAction.edit),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary, shape: const StadiumBorder()),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit Batch'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String? _duration(ConsoleBatch b) {
    final parts = [
      if (b.durationWeeks != null && b.durationWeeks! > 0) '${b.durationWeeks} weeks',
      if (b.durationHours != null && b.durationHours! > 0) '${b.durationHours} hours',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String _moment(DateTime at) {
    final l = at.toLocal();
    final hhmm = '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
    return '${dayWords(indiaDay(DateTime.utc(l.year, l.month, l.day)))}, ${classTimeWords(hhmm)}';
  }
}
