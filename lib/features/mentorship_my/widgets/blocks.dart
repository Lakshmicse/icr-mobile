import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../mentoring_format.dart';
import '../mentoring_models.dart';
import 'kit.dart';

/// The navy band with a headline and one white button: the design's "Pro
/// Mentorship" card, used for the prompts that start something (find a mentor,
/// become one).
class BlueBand extends StatelessWidget {
  const BlueBand({
    super.key,
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onPressed,
    this.kicker,
    this.icon,
  });

  final String? kicker;
  final String title;
  final String body;
  final String buttonLabel;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MentoringColors.navyDeep, MentoringColors.navyMid, AppColors.primary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kicker != null) ...[
            Text(kicker!.toUpperCase(), style: MentoringText.planKicker),
            const SizedBox(height: 6),
          ],
          Text(title, style: MentoringText.planTitle.copyWith(fontSize: 16, height: 20 / 15)),
          const SizedBox(height: 6),
          Text(body, style: MentoringText.planLine.copyWith(fontSize: 13, height: 16 / 11.5)),
          const SizedBox(height: 14),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 15, color: AppColors.primary), const SizedBox(width: 7)],
                    Text(buttonLabel, style: MentoringText.planButton),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One thing that needs the member's hands, and where it leads.
class NeedItem {
  const NeedItem({required this.icon, required this.text, required this.onTap, this.tone = PillTone.amber});

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final PillTone tone;
}

/// "Needs you": what is waiting on the member, each line a way in; a quiet
/// line when nothing is.
class NeedsYouCard extends StatelessWidget {
  const NeedsYouCard({super.key, required this.items, this.clear = 'You are all caught up.'});

  final List<NeedItem> items;
  final String clear;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: AppColors.emerald50, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(LucideIcons.circleCheck, size: 16, color: AppColors.emerald700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(clear, style: MentoringText.body.copyWith(color: AppColors.emerald700)),
            ),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.amber50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text('NEEDS YOU', style: MentoringText.pill.copyWith(color: AppColors.amber800, letterSpacing: 0.8)),
          ),
          for (final item in items)
            InkWell(
              onTap: item.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  children: [
                    Icon(item.icon, size: 16, color: AppColors.amber800),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item.text, style: MentoringText.bodyStrong)),
                    const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.outline),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// A pairing in a list: who, how it stands, what is next.
class PairingCard extends StatelessWidget {
  const PairingCard({super.key, required this.pairing, required this.onOpen, this.next, this.onMessage});

  final Pairing pairing;
  final PairingSession? next;
  final VoidCallback onOpen;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final p = pairing;
    final who = p.counterpart;
    return MentoringCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PersonRow(
            person: who,
            size: 48,
            trailing: StatusPill(
              p.status.label,
              tone: switch (p.status) {
                PairingStatus.active => PillTone.mint,
                PairingStatus.paused => PillTone.amber,
                PairingStatus.completed => PillTone.blue,
                PairingStatus.endedEarly => PillTone.grey,
              },
            ),
          ),
          if (next != null)
            MetaLine(
              icon: LucideIcons.calendarClock,
              color: MentoringColors.mintInk,
              text: 'Next: ${whenLabel(next!.scheduledAt)} (${daysFromNow(next!.scheduledAt)})',
            )
          else if (p.status.live)
            const MetaLine(icon: LucideIcons.calendarClock, text: 'No session booked yet'),
          MetaLine(
            icon: LucideIcons.clock,
            text:
                '${countLabel(p.sessionsCount, 'session')} held · ${minutesLabel(p.totalMinutes)}'
                '${p.status == PairingStatus.completed && p.completedAt != null ? ' · finished ${dayLabel(p.completedAt!)}' : ''}',
          ),
          if (p.status.live && onMessage != null)
            ActionWrap(
              top: 10,
              children: [
                QuietButton(label: 'Message', icon: LucideIcons.messageSquare, onPressed: onMessage),
                SolidButton(label: 'Open', onPressed: onOpen),
              ],
            ),
        ],
      ),
    );
  }
}

/// A free mentoring request, sent (to a mentor) or received (from a mentee).
class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.request, required this.received, this.actions = const []});

  final MentoringRequest request;

  /// True when the member is the mentor being asked.
  final bool received;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final who = received ? r.mentee : r.mentor;
    return MentoringCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PersonRow(
            person: who,
            subline: received
                ? [
                    if (r.careerStage != null) careerStages[r.careerStage] ?? r.careerStage,
                    'asked ${dayLabel(r.createdAt)}',
                  ].join(' · ')
                : '${who.subline ?? 'Mentor'} · asked ${dayLabel(r.createdAt)}',
            trailing: StatusPill(
              r.status.label,
              tone: switch (r.status) {
                RequestStatus.pending => PillTone.amber,
                RequestStatus.accepted => PillTone.mint,
                RequestStatus.declined => PillTone.red,
                _ => PillTone.grey,
              },
            ),
          ),
          const SizedBox(height: 10),
          Text(r.message, style: MentoringText.body, maxLines: 6, overflow: TextOverflow.ellipsis),
          if (r.focusAreas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final f in r.focusAreas.take(4)) StatusPill(f, tone: PillTone.blue)],
              ),
            ),
          if (r.matchScore != null && received)
            MetaLine(icon: LucideIcons.sparkles, text: 'Match score ${r.matchScore}%'),
          if (r.responseNote != null && r.responseNote!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(8)),
              child: Text(
                received ? 'Your reply: ${r.responseNote}' : '${r.mentor.firstName} replied: ${r.responseNote}',
                style: MentoringText.quote,
              ),
            ),
          if (r.status == RequestStatus.pending && r.expiresAt != null)
            MetaLine(icon: LucideIcons.hourglass, text: 'Lapses ${daysFromNow(r.expiresAt!)} if nobody answers'),
          ActionWrap(children: actions),
        ],
      ),
    );
  }
}

/// A small caps label over a group of cards.
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key, this.top = 8});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top, bottom: 8, left: 2),
    child: Text(text.toUpperCase(), style: MentoringText.pill.copyWith(color: AppColors.outline, letterSpacing: 0.8)),
  );
}

/// A line of text that is a fact, in the page's body face.
class FactLine extends StatelessWidget {
  const FactLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: MentoringText.body),
  );
}

/// The star and rating line of a mentor ("4.8 (14 reviews)").
String ratingLine(double rating, int count) =>
    count == 0 ? 'No reviews yet' : '${rating.toStringAsFixed(1)} · ${countLabel(count, 'review')}';

/// A bordered number tile row ("2 Active", "1 Pending").
class StatStrip extends StatelessWidget {
  const StatStrip({super.key, required this.tiles});

  final List<(String value, String label)> tiles;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          for (final (i, t) in tiles.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            StatTile(value: t.$1, label: t.$2),
          ],
        ],
      ),
    );
  }
}

/// The caption style some blocks borrow.
TextStyle get captionStyle => AppText.plexSans(11, FontWeight.w500, AppColors.outline, lineHeight: 15);
