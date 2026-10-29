import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../../core/widgets/detail_sheet.dart';
import 'event_detail_controller.dart';
import 'event_format.dart';
import 'event_models.dart';
import 'event_pass.dart';
import 'events_controller.dart';
import 'events_styles.dart';
import 'widgets/pills.dart';

/// Opens an event over the board, as the Event Sheet design.
Future<void> showEventSheet(BuildContext context, EventSummary event) async {
  final events = context.read<EventsController>();
  final controller = EventDetailController(repository: events.repository, seed: event, onChanged: events.update)
    ..load();
  await showDetailSheet<void>(
    context,
    handleTop: 10,
    handleHeight: 24,
    body: (_) => ChangeNotifierProvider.value(value: controller, child: const EventSheetBody()),
    bottomBar: (_) => ChangeNotifierProvider.value(value: controller, child: const EventSheetBar()),
  );
  controller.dispose();
}

/// The scrolling part of the sheet.
class EventSheetBody extends StatelessWidget {
  const EventSheetBody({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EventDetailController>();
    final detail = controller.detail;
    final e = detail.event;
    // A bold-led list in the description is the design's highlight cards.
    final text = describe(e.description);
    final paras = text.paragraphs;
    final highlights = detail.highlights.isNotEmpty ? detail.highlights : text.highlights;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15.5, 1.5, 18, 0),
          child: _TopRow(event: e, onSave: controller.toggleSave),
        ),
        const SizedBox(height: 11),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: _Hero(event: e, organiser: detail.organiser),
        ),
        const SizedBox(height: 9.5),
        if (detail.pass != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 10.5),
            child: _PassCard(event: e, pass: detail.pass!),
          ),
          const SizedBox(height: 0.5),
        ] else ...[
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 10.5),
            child: _WhenWhere(event: e),
          ),
          const SizedBox(height: 0.5),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: _AttendeesStrip(event: e, note: detail.attendeeNote),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16),
          // As tall as its text (17 dp at the 12 sp floor, not the design's 13); the gap below gave up the 4 dp.
          child: Row(children: [Text('About', style: EventsText.sectionLabel)]),
        ),
        const SizedBox(height: 8.5),
        if (controller.loading && paras.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2))),
          )
        else if (controller.error != null && paras.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(controller.error!, style: EventsText.body),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16.5, 0),
            child: paras.isEmpty
                ? Text('The organiser will share the details soon.', style: EventsText.paragraph)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (i, p) in paras.indexed) ...[
                        if (i > 0) const SizedBox(height: 8),
                        Text(p, style: EventsText.paragraph),
                      ],
                    ],
                  ),
          ),
        if (highlights.isNotEmpty) ...[
          const SizedBox(height: 11),
          for (final (i, h) in highlights.indexed) ...[
            if (i > 0) const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 15.5),
              child: _HighlightCard(highlight: h),
            ),
          ],
        ],
        if (detail.sessions.isNotEmpty) ...[
          const SizedBox(height: 11.5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // The row and its pill are as tall as their text (17 dp, the design's 15); the gap below gave up the 2.
            child: Row(
              children: [
                Text(
                  // "SUMMIT AGENDA", or the kind's word for an event that is not one.
                  e.title.toLowerCase().contains('summit') ? 'SUMMIT AGENDA' : '${e.kind.label.toUpperCase()} AGENDA',
                  style: EventsText.agendaHeading,
                ),
                const Spacer(),
                if (detail.agendaNote != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(color: EventsColors.panel, borderRadius: BorderRadius.circular(8.5)),
                    child: Text(detail.agendaNote!, style: EventsText.agendaPill),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Timeline(sessions: detail.sessions),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

/// The bar under the sheet: the member's standing and what they can do.
class EventSheetBar extends StatelessWidget {
  const EventSheetBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EventDetailController>();
    final detail = controller.detail;
    final e = detail.event;
    final link = controller.repository.link(e);
    final going = e.rsvp == RsvpState.going || e.rsvp == RsvpState.attended;
    final waitlisted = e.rsvp == RsvpState.waitlisted;
    final seats = e.seatsLeft;

    final (title, note, dot) = e.past
        ? ('This event has ended', '${groupThousands(e.going)} attended', AppColors.outline)
        : going
        ? ('Your Booking is Active', '1 delegate seat confirmed', AppColors.online)
        : waitlisted
        ? ("You're on the waitlist", 'We will move you up as seats free', AppColors.amber500)
        : e.inviteOnly && !detail.invited
        ? ('By invitation', 'This event is invite-only', AppColors.outline)
        : e.full
        ? ('This event is full', 'Join the waitlist', AppColors.amber500)
        : (
            'Seats available',
            e.priced
                ? '${priceLabel(e.pricePaisa)} per pass'
                : seats == null
                ? 'Free for ICR members'
                : '$seats of ${e.capacity} seats left • Free',
            AppColors.online,
          );

    // No button when there is nothing to do here: an ended or invite-only event has its status line, and the
    // "Event page" that stood there only opened this sheet again.
    Widget? primary;
    Widget? secondary;
    if (e.past || (e.inviteOnly && !detail.invited && !e.rsvp.holds)) {
      primary = null;
    } else if (going || waitlisted) {
      secondary = _BarButton.secondary(
        label: 'Cancel',
        icon: LucideIcons.x,
        onTap: controller.busy ? null : () => _run(context, controller.cancel()),
      );
      // A confirmed place has a pass to show (the event's code and a QR to
      // its page); a waitlisted one has none yet, so Cancel stands alone.
      final pass = detail.pass;
      final hasPass = going && pass?.reference != null;
      primary = hasPass
          ? _BarButton.primary(
              label: 'View Pass & QR',
              icon: LucideIcons.qrCode,
              onTap: () => showEventPass(context, event: e, pass: pass!, link: link),
            )
          : null;
    } else if (e.priced && detail.sellsTickets) {
      // Tickets are bought on the website (the app has no checkout): the phone opens it, never this sheet again.
      primary = _BarButton.primary(
        label: 'Get Tickets',
        icon: LucideIcons.ticket,
        onTap: () => openExternal(context, link),
      );
    } else {
      primary = _BarButton.primary(
        label: e.full ? 'Join Waitlist' : 'Register Now',
        icon: LucideIcons.check,
        onTap: controller.busy ? null : () => _run(context, controller.register()),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, -3))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13.5, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The status line is as tall as its text (17 dp at the 12 sp floor, the design's 14); the gap below
              // gave up the 3 dp.
              Row(
                children: [
                  const SizedBox(width: 2.5),
                  Container(
                    width: 10.5,
                    height: 10.5,
                    decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(title, style: EventsText.barTitle),
                  // The note takes what the title leaves, right-aligned, and gives way with an ellipsis on a narrow
                  // phone rather than running past the bar.
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      note,
                      textAlign: TextAlign.end,
                      style: EventsText.barNote,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              if (primary != null || secondary != null) ...[
                const SizedBox(height: 9.5),
                Padding(
                  padding: EdgeInsets.only(right: primary != null && secondary != null ? 19.5 : 0),
                  child: Row(
                    children: [
                      if (secondary != null) Expanded(flex: primary == null ? 1 : 159, child: secondary),
                      if (secondary != null && primary != null) const SizedBox(width: 8.5),
                      if (primary != null) Expanded(flex: secondary == null ? 1 : 171, child: primary),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _run(BuildContext context, Future<String?> action) async {
    final message = await action;
    if (message != null && context.mounted) showMessage(context, message);
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton.primary({required this.label, required this.icon, required this.onTap}) : filled = true;
  const _BarButton.secondary({required this.label, required this.icon, required this.onTap}) : filled = false;

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = filled ? (enabled ? AppColors.primary : AppColors.primary.withValues(alpha: 0.5)) : Colors.white;
    final style = filled ? EventsText.barPrimary : EventsText.barCancel;
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: filled ? BorderSide.none : const BorderSide(color: Color(0xFFF2F2F2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 39.5,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: filled ? 16 : 20, color: style.color),
              SizedBox(width: filled ? 8 : 9),
              Text(label, style: style),
            ],
          ),
        ),
      ),
    );
  }
}

/// The status and CPD pills, then share, bookmark and close.
class _TopRow extends StatelessWidget {
  const _TopRow({required this.event, required this.onSave});

  final EventSummary event;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final going = e.rsvp == RsvpState.going || e.rsvp == RsvpState.attended;
    final (status, icon) = e.past
        ? ('Event Ended', LucideIcons.circleCheck)
        : going
        ? ('Registration Confirmed', LucideIcons.circleCheck)
        : e.rsvp == RsvpState.waitlisted
        ? ('On the Waitlist', LucideIcons.hourglass)
        : e.full
        ? ('Waitlist Open', LucideIcons.hourglass)
        : ('Registration Open', LucideIcons.circleCheck);
    final link = context.read<EventDetailController>().repository.link(e);
    // The pills wrap onto a second line when the status, the hours and the three glyphs do not all fit one,
    // so a long status ("Registration Confirmed") is read in full at the app's text sizes.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 29),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              spacing: 5.5,
              runSpacing: 5,
              children: [
                _Pill(
                  fill: going ? EventsColors.confirmedPill : EventsColors.cpdPill,
                  icon: icon,
                  label: status,
                  style: going ? EventsText.statusPill : EventsText.sheetCpdPill,
                ),
                if (e.cpdHours != null)
                  _Pill(
                    fill: EventsColors.cpdPill,
                    icon: LucideIcons.badgeCheck,
                    label: cpdLabel(e.cpdHours!),
                    style: EventsText.sheetCpdPill,
                    padding: 6,
                    iconSize: 12.5,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // The glyphs sit on the first line, centred on the 29 dp pill.
          SizedBox(
            height: 29,
            child: Row(
              children: [
                GlyphButton(
                  icon: LucideIcons.share2,
                  size: 19,
                  box: 24,
                  color: AppColors.onSurfaceVariant,
                  label: 'Share event',
                  onTap: () => SharePlus.instance.share(ShareParams(text: '${e.title}\n$link', subject: e.title)),
                ),
                const SizedBox(width: 6),
                GlyphButton(
                  icon: e.saved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
                  size: 18,
                  box: 24,
                  color: e.saved ? AppColors.primary : AppColors.onSurfaceVariant,
                  label: e.saved ? 'Remove bookmark' : 'Save event',
                  onTap: onSave,
                ),
                const SizedBox(width: 8),
                GlyphButton(
                  icon: LucideIcons.x,
                  size: 16,
                  box: 24,
                  color: AppColors.onSurface,
                  label: 'Close',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.fill,
    required this.icon,
    required this.label,
    required this.style,
    this.padding = 8,
    this.iconSize = 12.5,
  });

  final Color fill;
  final IconData icon;
  final String label;
  final TextStyle style;
  final double padding;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 29,
      padding: EdgeInsets.only(left: padding, right: padding + 1),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(14.5)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: style.color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// The dark photo with the kind and format chips, the accreditation, the
/// kicker, the title and who organises it.
class _Hero extends StatelessWidget {
  const _Hero({required this.event, required this.organiser});

  final EventSummary event;
  final String? organiser;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final tags = e.tags ?? [EventTag(e.kind.tag, TagTone.dark), EventTag(formatOf(e).tag, TagTone.blue)];
    // Where the design says "RICS CERTIFIED": what the seat costs.
    final aside = e.accreditation ?? priceNote(e).toUpperCase();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 176.5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            EventCover(event: e),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.45, 1],
                  colors: [Color(0x330F172A), Color(0x660F172A), Color(0xE60F172A)],
                ),
              ),
            ),
            Positioned(
              left: 11.7,
              top: 16,
              child: Row(
                children: [
                  for (final (i, tag) in tags.indexed) ...[
                    if (i > 0) const SizedBox(width: 5),
                    TagPill(tag, height: 22, radius: 11, padding: 10, style: EventsText.heroChip),
                  ],
                ],
              ),
            ),
            Positioned(right: 18, top: 20.5, child: Text(aside, style: EventsText.heroAside)),
            Positioned(
              left: 11.7,
              right: 16,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    e.kicker ?? (e.host?.toUpperCase() ?? e.kind.label.toUpperCase()),
                    style: EventsText.heroKicker,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(e.title, style: EventsText.heroTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(LucideIcons.building2, size: 12, color: AppColors.success),
                      const SizedBox(width: 4.5),
                      Expanded(
                        child: Text(
                          'Organised by ${organiser ?? e.host ?? 'ICR'}',
                          style: EventsText.heroOrganiser,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The grey card with the date badge, the pass, "Show Pass", and the white
/// panel with the time and the venue.
class _PassCard extends StatelessWidget {
  const _PassCard({required this.event, required this.pass});

  final EventSummary event;
  final EventPass pass;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final link = context.read<EventDetailController>().repository.link(e);
    final waitlisted = e.rsvp == RsvpState.waitlisted;
    return Container(
      padding: const EdgeInsets.fromLTRB(12.5, 5, 11.5, 3),
      decoration: BoxDecoration(color: EventsColors.panel, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 50,
            child: Row(
              children: [
                DateBadge(
                  at: e.startsAt,
                  width: 45,
                  height: 50,
                  headHeight: 17,
                  radius: 8,
                  color: EventsColors.badgeRed,
                  monthStyle: EventsText.passMonth,
                  dayStyle: EventsText.passDay,
                  shadow: true,
                ),
                const SizedBox(width: 9.5),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              pass.reference == null ? 'Your place' : 'Pass #${pass.reference}',
                              style: EventsText.passTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // As tall as its word (17 dp at the 12 sp floor, the design's 13).
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: waitlisted ? AppColors.amber100 : EventsColors.activePill,
                              borderRadius: BorderRadius.circular(8.5),
                            ),
                            child: Text(
                              waitlisted ? 'Waitlisted' : 'Active Pass',
                              style: waitlisted
                                  ? EventsText.activePill.copyWith(color: AppColors.amber800)
                                  : EventsText.activePill,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.5),
                      Text(
                        '${pass.role} • ${pass.holder}',
                        style: EventsText.passHolder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (pass.reference != null) ...[
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => showEventPass(context, event: e, pass: pass, link: link),
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 81.5,
                        height: 37.5,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.qrCode, size: 13, color: EventsColors.link),
                            const SizedBox(width: 4),
                            Text('Show Pass', style: EventsText.passButton),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 11.5),
          _WhenWherePanel(event: e, synced: pass.calendarSynced),
        ],
      ),
    );
  }
}

/// The time and venue panel on its own, for an event the member has no
/// place at yet.
class _WhenWhere extends StatelessWidget {
  const _WhenWhere({required this.event});

  final EventSummary event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12.5, 5, 11.5, 3),
      decoration: BoxDecoration(color: EventsColors.panel, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DateBadge(
            at: event.startsAt,
            width: 45,
            height: 50,
            headHeight: 17,
            radius: 8,
            color: EventsColors.badgeRed,
            monthStyle: EventsText.passMonth,
            dayStyle: EventsText.passDay,
            shadow: true,
          ),
          const SizedBox(width: 9.5),
          Expanded(child: _WhenWherePanel(event: event, synced: false)),
        ],
      ),
    );
  }
}

class _WhenWherePanel extends StatelessWidget {
  const _WhenWherePanel({required this.event, required this.synced});

  final EventSummary event;
  final bool synced;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final link = context.read<EventDetailController>().repository.link(e);
    final venue = e.location?.trim();
    final online = formatOf(e) == EventFormat.online;
    // "Grand Auditorium, Hall 3 • Mumbai Convention Centre": the hall bold,
    // the venue after the first separator in grey.
    final split = venue == null ? null : RegExp(r'\s*•\s*').firstMatch(venue);
    final head = venue == null
        ? (online ? 'Online' : 'Venue to be announced')
        : split == null
        ? venue
        : '${venue.substring(0, split.start)} •';
    final tail = split == null ? '' : ' ${venue!.substring(split.end)}';
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 13, 10, 11.5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.clock, size: 16, color: EventsColors.link),
              const SizedBox(width: 4),
              Expanded(child: Text(timeRange(e), style: EventsText.panelStrong)),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: synced ? null : () => openUrl(context, googleCalendarUri(e, link)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      synced ? LucideIcons.refreshCw : LucideIcons.calendarPlus,
                      size: 11,
                      color: EventsColors.mintInk,
                    ),
                    const SizedBox(width: 3),
                    Text(synced ? 'Synced to Calendar' : 'Add to calendar', style: EventsText.synced),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14.5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(online ? LucideIcons.video : LucideIcons.mapPin, size: 16, color: EventsColors.link),
              const SizedBox(width: 4),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: head, style: EventsText.panelStrong),
                      TextSpan(text: tail, style: EventsText.panelSoft),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "642 Attendees Registered" with the initials circles and "View Network".
class _AttendeesStrip extends StatelessWidget {
  const _AttendeesStrip({required this.event, required this.note});

  final EventSummary event;
  final String? note;

  /// The design's circles and its "+16": the API names no attendee, so a live
  /// event draws its host's initials, then how many more are going.
  static List<EventAvatar> _people(EventSummary e) {
    if (e.attendeePreview.isNotEmpty) return e.attendeePreview;
    final host = hostAvatars(e.host, tones: const [AvatarTone.blue, AvatarTone.green, AvatarTone.slate]);
    final more = e.going - host.length;
    return [...host, if (more > 0) EventAvatar('+${compactCount(more)}', AvatarTone.count)];
  }

  @override
  Widget build(BuildContext context) {
    final e = event;
    return Container(
      height: 55.5,
      padding: const EdgeInsets.only(left: 11.5, right: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EventsColors.borderSoft),
        boxShadow: const [BoxShadow(color: Color(0x0A0F2A4A), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          AvatarStack(avatars: _people(e), size: 29.5, step: 20, style: EventsText.sheetAvatar),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${groupThousands(e.going)} Attendee${e.going == 1 ? '' : 's'} Registered',
                  style: EventsText.attendeesTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (note != null) ...[
                  const SizedBox(height: 1),
                  Text(note!, style: EventsText.attendeesNote, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => openSitePage(context, '/network'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('View Network', style: EventsText.sheetLink),
                const SizedBox(width: 1),
                const Icon(LucideIcons.chevronRight, size: 12, color: EventsColors.link),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.highlight});

  final EventHighlight highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 11, 12, 8.5),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: EventsColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 22,
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(color: EventsColors.checkCircle, shape: BoxShape.circle),
                  child: const Icon(LucideIcons.check, size: 12, color: AppColors.tertiary),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(highlight.title, style: EventsText.highlightTitle)),
              ],
            ),
          ),
          if (highlight.body.isNotEmpty) ...[
            const SizedBox(height: 3.5),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(highlight.body, style: EventsText.highlightBody),
            ),
          ],
        ],
      ),
    );
  }
}

/// The agenda: a rail of dots down the left, a card per session.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.sessions});

  final List<EventSession> sessions;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(left: 20, top: 0, bottom: 11, child: Container(width: 2, color: EventsColors.rail)),
        Padding(
          padding: const EdgeInsets.only(top: 3.5),
          child: Column(
            children: [
              for (final (i, s) in sessions.indexed) ...[
                if (i > 0) const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(left: 35.5, right: 15.5),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _SessionCard(session: s),
                      Positioned(
                        left: -19.5,
                        top: 2.5,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
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
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final EventSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Container(
      padding: const EdgeInsets.fromLTRB(10.5, 8, 11, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: EventsColors.borderSoft),
        boxShadow: const [BoxShadow(color: Color(0x0A0F2A4A), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The time and tag row is as tall as its text (17 dp, the design's 15); the gap below gave up the 2.
          Row(
            children: [
              Text(s.time ?? 'Session', style: EventsText.sessionTime),
              const Spacer(),
              if (s.tag != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: s.tagGreen ? EventsColors.panelPill : EventsColors.keynotePill,
                    borderRadius: BorderRadius.circular(8.5),
                  ),
                  child: Text(
                    s.tag!,
                    style: s.tagGreen
                        ? EventsText.sessionTag.copyWith(color: EventsColors.activeInk)
                        : EventsText.sessionTag,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10.5),
          Text(s.title, style: EventsText.sessionTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12.5),
          Row(
            children: [
              Icon(s.panel ? LucideIcons.users : LucideIcons.mic, size: 11, color: AppColors.outline),
              const SizedBox(width: 4),
              Expanded(
                child: Text(s.speaker, style: EventsText.sessionSpeaker, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
