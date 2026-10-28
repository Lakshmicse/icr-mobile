import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../event_format.dart';
import '../event_models.dart';
import '../events_styles.dart';
import 'pills.dart';

/// The flagship card under the chips: the photo with the "SPOTLIGHT EVENT"
/// and CPD pills, the date badge, the kicker and title over its foot; then the
/// venue, the accreditation, who is going and the RSVP button.
class SpotlightCard extends StatelessWidget {
  const SpotlightCard({
    super.key,
    required this.event,
    required this.onTap,
    required this.onSave,
    required this.onAction,
    this.busy = false,
  });

  static const photoHeight = 146.0;

  final EventSummary event;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final VoidCallback onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final venue = e.location ?? (formatOf(e) == EventFormat.online ? 'Online' : 'Venue to be announced');
    final aside = e.badge ?? priceNote(e);
    final going = '${groupThousands(e.going)} Attendee${e.going == 1 ? '' : 's'} Registered';
    // The API names no attendee, so the circles carry the host's initials.
    final people = e.attendeePreview.isNotEmpty ? e.attendeePreview : hostAvatars(e.host);
    final (label, enabled) = _action(e);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: EventsColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: photoHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  EventCover(event: e),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.45, 1],
                        colors: [Color(0x00081422), Color(0xB3081422)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 11.5,
                    child: Row(
                      children: [
                        Container(
                          height: 28,
                          padding: const EdgeInsets.only(left: 8, right: 8),
                          decoration: BoxDecoration(
                            color: EventsColors.navyPill,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(color: AppColors.online, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 5),
                              Text('SPOTLIGHT EVENT', style: EventsText.spotlightPill),
                            ],
                          ),
                        ),
                        if (e.cpdHours != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            height: 28,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: EventsColors.stonePill,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(cpdLabel(e.cpdHours!, unit: 'CPD CREDITS'), style: EventsText.cpdPill),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    right: 17.5,
                    top: 8,
                    child: DateBadge(at: e.startsAt, width: 41.5, height: 51, headHeight: 19),
                  ),
                  Positioned(
                    left: 10,
                    right: 20,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(kickerFor(e), style: EventsText.kicker, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 10),
                        Text(e.title, style: EventsText.spotlightTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16.5, 7, 9.5),
              child: Column(
                children: [
                  SizedBox(
                    height: 13,
                    child: Row(
                      children: [
                        const Icon(LucideIcons.mapPin, size: 13, color: AppColors.linkIcon),
                        const SizedBox(width: 3.5),
                        Expanded(
                          child: Text(venue, style: EventsText.venue, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        const Icon(LucideIcons.badgeCheck, size: 13, color: AppColors.tertiary),
                        const SizedBox(width: 4),
                        Text(aside, style: EventsText.badgeLine),
                        const SizedBox(width: 5),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12.5),
                  SizedBox(
                    height: 36,
                    child: Row(
                      children: [
                        AvatarStack(avatars: people),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(going, style: EventsText.attendees, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        GlyphButton(
                          icon: e.saved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
                          label: e.saved ? 'Remove bookmark' : 'Save event',
                          color: e.saved ? AppColors.primary : AppColors.outline,
                          size: 15.5,
                          box: 24,
                          onTap: onSave,
                        ),
                        const SizedBox(width: 10),
                        // The design's button is 76.5 × 31 dp, centred in the row, its right edge in line
                        // with the venue row's "RICS Accredited" (12 dp from the card's edge).
                        Material(
                          color: enabled && !busy ? AppColors.primary : AppColors.primary.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: enabled && !busy ? onAction : null,
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              height: 31,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.75),
                                child: Center(child: Text(label, style: EventsText.rsvpButton)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5.5),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The button's word and whether a tap does anything here.
  static (String, bool) _action(EventSummary e) {
    if (e.past) return ('Ended', false);
    if (e.rsvp == RsvpState.going || e.rsvp == RsvpState.attended) return ('Registered', false);
    if (e.rsvp == RsvpState.waitlisted) return ('Waitlisted', false);
    if (e.priced) return ('Get Tickets', true);
    if (e.inviteOnly) return ('Invite Only', true);
    if (e.full) return ('Join Waitlist', true);
    return ('RSVP Free', true);
  }
}
