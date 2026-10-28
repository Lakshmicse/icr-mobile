import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/section_heading.dart';
import '../council_format.dart';
import '../council_models.dart';
import '../councils_styles.dart';
import 'pills.dart';

/// One card in the "Your Joined Councils" rail: 210 × 160, the seat and the
/// unread count, the name, a line of copy, and the peers with the room link.
class JoinedCouncilCard extends StatelessWidget {
  const JoinedCouncilCard({super.key, required this.council, required this.onOpen, this.onRoom, this.onUnread});

  static const width = 211.0;
  static const height = 182.0;

  final Council council;

  /// The card itself: the council's page.
  final VoidCallback onOpen;

  /// "Room Link" / "Meeting link"; the card's own tap when not given.
  final VoidCallback? onRoom;

  /// The "N unread" pill: where the council's announcements are; the card's
  /// own tap when not given.
  final VoidCallback? onUnread;

  @override
  Widget build(BuildContext context) {
    final lead = council.membership == CouncilRole.lead;
    final next = council.nextEventAt;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: CouncilsColors.cardBorder),
          boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 3, offset: Offset(0, 1))],
        ),
        padding: const EdgeInsets.fromLTRB(13, 14, 13, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusPill(
                  label: council.membership?.label ?? CouncilRole.member.label,
                  height: 19,
                  fill: lead ? CouncilsColors.green50 : CouncilsColors.blue50,
                  style: lead ? CouncilsText.rolePill : CouncilsText.rolePill.copyWith(color: AppColors.primary),
                  dot: lead ? CouncilsColors.green700 : AppColors.primary,
                ),
                const SizedBox(width: 4),
                // Takes what the seat leaves, so a long seat and a date never overflow the card.
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: council.unread > 0
                        ? GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onUnread ?? onOpen,
                            child: StatusPill(
                              height: 19,
                              label: '${council.unread} unread',
                              fill: CouncilsColors.red50,
                              style: CouncilsText.rolePill.copyWith(color: CouncilsColors.red600),
                            ),
                          )
                        : next == null
                        ? null
                        : StatusPill(
                            height: 19,
                            label: 'Next Sync: ${monthDay(next)}',
                            fill: CouncilsColors.greyPill,
                            style: CouncilsText.rolePill.copyWith(color: AppColors.slate700),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(council.name, style: CouncilsText.joinedTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5.5),
            if (council.blurb != null)
              Text(council.blurb!, style: CouncilsText.joinedCopy, maxLines: 2, overflow: TextOverflow.ellipsis),
            const Spacer(),
            const Hairline(color: CouncilsColors.tileRule),
            const SizedBox(height: 11),
            Row(
              children: [
                const Icon(Symbols.groups, size: 14.5, fill: 1, weight: 500, color: AppColors.slate500),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${groupThousands(council.memberCount)} peers',
                    style: CouncilsText.peers,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                lead ? _RoomLink(onTap: onRoom ?? onOpen) : _MeetingLink(onTap: onRoom ?? onOpen),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The blue "Room Link" button of an executive seat.
class _RoomLink extends StatelessWidget {
  const _RoomLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 96,
          height: 24.5,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Symbols.meeting_room, size: 13, color: Colors.white),
              const SizedBox(width: 6),
              Text('Room Link', style: CouncilsText.roomLink),
            ],
          ),
        ),
      ),
    );
  }
}

/// The outlined "Meeting link" of a plain membership.
class _MeetingLink extends StatelessWidget {
  const _MeetingLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(side: const BorderSide(color: CouncilsColors.cardBorder));
    return Material(
      color: Colors.white,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: SizedBox(
          height: 25,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(widthFactor: 1, child: Text('Meeting link', style: CouncilsText.meetingLink)),
          ),
        ),
      ),
    );
  }
}
