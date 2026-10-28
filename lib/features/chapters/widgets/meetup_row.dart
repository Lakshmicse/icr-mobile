import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../chapter_format.dart';
import '../chapter_models.dart';
import '../community_kit.dart';

/// One chapter event as a row: the date tile, the kind and time, the title,
/// and where. Used by the board's "Upcoming meetups" (with the chapter named)
/// and by a chapter page's Events section.
class MeetupRow extends StatelessWidget {
  const MeetupRow({
    super.key,
    required this.event,
    required this.onTap,
    this.showChapter = true,
    this.past = false,
    this.footer,
  });

  final ChapterEvent event;
  final VoidCallback onTap;

  /// Under the seats line: the RSVP control a chapter's page gives its own meetups.
  final Widget? footer;

  /// Name the chapter under the title (the board does; a chapter's own page does not).
  final bool showChapter;

  /// A session that has happened: the tile greys out.
  final bool past;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final detail = [
      if (showChapter && e.chapterName != null) e.chapterName!,
      if (e.location != null) e.location!,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateTile(start: e.startsAt, past: past),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      CommunityPill(
                        label: e.kindLabel,
                        fill: CommunityColors.blue50,
                        style: CommunityText.pill.copyWith(color: CommunityColors.blue700),
                        height: 16,
                      ),
                      if (e.inviteOnly)
                        CommunityPill(
                          label: 'INVITE ONLY',
                          fill: CommunityColors.amber50,
                          style: CommunityText.pill.copyWith(color: CommunityColors.amber700),
                          height: 16,
                        ),
                      Text(timeRange(e.startsAt, e.endsAt), style: CommunityText.meta),
                      // A row with its own RSVP bar says it there; the pill is for a row without one.
                      if (footer == null && e.myStatus != null && e.myStatus != 'CANCELLED')
                        CommunityPill(
                          label: e.going
                              ? (e.myStatus == 'ATTENDED' ? 'You attended' : 'You are going')
                              : _status(e.myStatus!),
                          fill: e.waitlisted ? CommunityColors.amber50 : CommunityColors.green50,
                          style: CommunityText.pill.copyWith(
                            color: e.waitlisted ? CommunityColors.amber700 : CommunityColors.green700,
                          ),
                          height: 16,
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(e.title, style: CommunityText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(detail, style: CommunityText.personLine, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  if (e.attendeeCount > 0 || e.capacity != null) ...[
                    const SizedBox(height: 4),
                    Text(_seats(e), style: CommunityText.meta),
                  ],
                  if (footer != null) ...[const SizedBox(height: 8), footer!],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Icon(LucideIcons.chevronRight, size: 16, color: AppColors.slate400),
            ),
          ],
        ),
      ),
    );
  }

  static String _status(String s) => s == 'WAITLISTED'
      ? 'On the waitlist'
      : s.isEmpty
      ? s
      : '${s[0]}${s.substring(1).toLowerCase()}';

  static String _seats(ChapterEvent e) {
    if (e.capacity == null) return '${groupThousands(e.attendeeCount)} going';
    if (e.full) return 'Full · ${groupThousands(e.attendeeCount)} going';
    return '${groupThousands(e.attendeeCount)} going · ${e.seatsLeft} seats left';
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.start, required this.past});

  final DateTime start;
  final bool past;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: past ? CommunityColors.greyPill : CommunityColors.green50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            monthCaps(start),
            style: CommunityText.pill.copyWith(color: past ? AppColors.slate500 : CommunityColors.green700),
          ),
          Text(dayOfMonth(start), style: CommunityText.statValue.copyWith(fontSize: 18, height: 1.1)),
        ],
      ),
    );
  }
}

/// The RSVP control under a chapter meetup: "RSVP" (or "Join waitlist" when full), or the place the
/// member holds with "Cancel". A ticketed event is bought on the events sheet, so it reads "Get
/// ticket" and hands the event over; a finished one has no control.
class MeetupRsvpBar extends StatelessWidget {
  const MeetupRsvpBar({
    super.key,
    required this.event,
    required this.busy,
    required this.onRsvp,
    required this.onCancel,
    required this.onTicket,
    required this.now,
  });

  final ChapterEvent event;
  final bool busy;
  final VoidCallback onRsvp;
  final VoidCallback onCancel;
  final VoidCallback onTicket;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final e = event;
    if (e.isOver(now)) {
      return Text('Event ended', style: CommunityText.meta);
    }
    if (e.holding) {
      return Row(
        children: [
          Icon(
            e.waitlisted ? LucideIcons.hourglass : LucideIcons.circleCheck,
            size: 13,
            color: e.waitlisted ? CommunityColors.amber700 : CommunityColors.green700,
          ),
          const SizedBox(width: 5),
          Text(
            e.waitlisted ? 'On the waitlist' : 'You are going',
            style: CommunityText.metaStrong.copyWith(
              color: e.waitlisted ? CommunityColors.amber700 : CommunityColors.green700,
            ),
          ),
          const Spacer(),
          Semantics(
            button: true,
            excludeSemantics: true,
            label: 'Cancel RSVP for ${e.title}',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: busy ? null : onCancel,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: busy
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6))
                    : Text('Cancel', style: CommunityText.buttonQuiet),
              ),
            ),
          ),
        ],
      );
    }
    if (e.ticketed) {
      return Align(
        alignment: Alignment.centerLeft,
        child: CommunityButton(
          label: 'Get ticket',
          icon: LucideIcons.ticket,
          outlined: true,
          height: 28,
          onPressed: onTicket,
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: CommunityButton(
        label: e.full ? 'Join waitlist' : 'RSVP',
        icon: e.full ? LucideIcons.hourglass : LucideIcons.calendarCheck,
        height: 28,
        busy: busy,
        onPressed: onRsvp,
      ),
    );
  }
}
