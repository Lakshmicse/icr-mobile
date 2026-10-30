import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../messaging_format.dart';
import '../messaging_models.dart';
import '../messaging_styles.dart';
import 'chat_avatar.dart';

IconData recordIcon(RecordType type) => switch (type) {
  RecordType.job => LucideIcons.briefcase,
  RecordType.requirement => LucideIcons.clipboardList,
  RecordType.company => LucideIcons.building2,
  RecordType.product => LucideIcons.package,
  RecordType.mentor => LucideIcons.graduationCap,
  RecordType.event => LucideIcons.calendarDays,
};

/// The one line under a record's title: its owner, place and the figure that matters.
String recordLine(RecordFacts f, {DateTime? now}) {
  final parts = <String>[
    ?f.owner,
    ?f.city,
    if (f.amount != null) f.unit != null ? '${rupees(f.amount!)} / ${f.unit}' : rupees(f.amount!),
    if (f.date != null) shortDate(f.date!, now: now),
    if (f.years != null) '${f.years} yrs experience',
  ];
  return parts.join(' · ');
}

/// An ICR record shared in a message (a job, a requirement…), drawn as a card
/// read through the record's own public endpoint. A record the reader may not
/// see says so instead of leaking its title.
class RecordCard extends StatelessWidget {
  const RecordCard({super.key, required this.ref, required this.load, this.onOpen, this.now});

  final RecordRef ref;
  final Future<RecordFacts> Function(RecordRef ref) load;
  final ValueChanged<RecordRef>? onOpen;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RecordFacts>(
      future: load(ref),
      builder: (context, snap) {
        final facts = snap.data;
        final failed = snap.hasError;
        final blocked = failed && ApiError.from(snap.error!).statusCode != null;
        // The thread's white hairline card, as the file card beside it (docs/designs/messaging-thread.png).
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1))],
          ),
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.outlineVariant),
            ),
            child: InkWell(
              key: ValueKey('record-${ref.type.name}-${ref.id}'),
              customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: facts == null && !failed ? null : () => onOpen?.call(ref),
              child: Container(
                constraints: const BoxConstraints(minWidth: 230),
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (facts != null && facts.image != null)
                      ChatAvatar(picture: facts.image, name: facts.title, size: 36, company: true)
                    else
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: ChatColors.composerChip,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(recordIcon(ref.type), size: 18, color: AppColors.primary),
                      ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: facts != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ref.type.label.toUpperCase(), style: ChatText.kindBadge),
                                Text(
                                  facts.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: ChatText.cardTitle,
                                ),
                                if (recordLine(facts, now: now).isNotEmpty)
                                  Text(
                                    recordLine(facts, now: now),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: ChatText.fileMeta,
                                  ),
                              ],
                            )
                          : failed
                          ? Text(
                              blocked ? ref.type.unavailable : "Couldn't load this ${ref.type.label.toLowerCase()}.",
                              style: ChatText.fileMeta,
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ref.type.label.toUpperCase(), style: ChatText.kindBadge),
                                const SizedBox(height: 4),
                                const SizedBox(width: 120, child: LinearProgressIndicator(minHeight: 2)),
                              ],
                            ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.slate400),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
