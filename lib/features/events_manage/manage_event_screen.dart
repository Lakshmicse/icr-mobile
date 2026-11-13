import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show SiteRoutes, openUrl, showMessage;
import '../../core/widgets/title_bar.dart';
import '../account/widgets/account_kit.dart' show AccountImage, confirmAction;
import '../events/event_format.dart' show paragraphs;
import '../events/event_models.dart' show eventsNow;
import '../workspaces/page_kit.dart' show WsButton;
import 'event_form_sheet.dart';
import 'events_manage_controllers.dart';
import 'events_manage_kit.dart';
import 'events_manage_models.dart';
import 'events_manage_repository.dart';
import 'events_manage_rules.dart';
import 'events_manage_sheets.dart';

/// One event's manage page for staff holding `events:manage`: what the website's Events console offers on a row —
/// its details with Edit and Remove (`EventDetails`, `EventDialog`), and the Programme and Tickets dialogs as tabs:
/// the guest list (invite by email or by tier, revoke), the talk proposals (accept, decline), the sponsorship
/// packages and requests, the tickets sold (refund) and attendance. It loads by id on its own, so it also opens
/// from an event's public sheet.
class ManageEventScreen extends StatefulWidget {
  const ManageEventScreen({
    super.key,
    required this.repository,
    required this.eventId,
    required this.onBack,
    this.onBell,
    this.unread = 0,
    this.pageWrap,
    this.initial,
    this.pickers = const EventPickers(),
  });

  final EventsManageRepository repository;
  final String eventId;
  final VoidCallback onBack;
  final VoidCallback? onBell;
  final int unread;

  /// Put round any page this one pushes (the app's bottom bar). It pushes none today; kept for the contract.
  final Widget Function(Widget page)? pageWrap;

  /// The list's row, drawn at once while the page reads the event again.
  final ManagedEvent? initial;

  /// The day and time dialogs of the event form (tests answer for them).
  final EventPickers pickers;

  @override
  State<ManageEventScreen> createState() => _ManageEventScreenState();
}

class _ManageEventScreenState extends State<ManageEventScreen> {
  late final ManageEventController _c = ManageEventController(
    widget.repository,
    eventId: widget.eventId,
    initial: widget.initial,
  );
  int _tab = 0;
  bool _removing = false;

  @override
  void initState() {
    super.initState();
    _c.start();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // --- the event's own actions -------------------------------------------------------------------------------------

  Future<void> _edit() async {
    final e = _c.event;
    if (e == null) return;
    final saved = await showEventFormSheet(
      context,
      repository: widget.repository,
      event: e,
      pickers: widget.pickers,
      onSave: _c.save,
    );
    if (saved && mounted) showMessage(context, 'Event saved.');
  }

  Future<void> _remove() async {
    final e = _c.event;
    if (e == null) return;
    final ok = await confirmAction(
      context,
      title: 'Remove This Event?',
      message: 'Cancel & remove "${e.title}" from the public calendar?',
      confirm: 'Remove',
    );
    if (!ok || !mounted) return;
    setState(() => _removing = true);
    final refusal = await _c.delete();
    if (!mounted) return;
    setState(() => _removing = false);
    if (refusal != null) {
      showMessage(context, refusal);
      return;
    }
    showMessage(context, 'Event removed.');
    widget.onBack();
  }

  void _say(String? refusal) {
    if (refusal != null && mounted) showMessage(context, refusal);
  }

  // --- guest list --------------------------------------------------------------------------------------------------

  Future<void> _inviteByEmail() async {
    final line = await showInviteByEmailSheet(context, controller: _c);
    if (line != null) _c.setInviteNotice(line);
  }

  Future<void> _inviteByTier() async {
    final line = await showInviteByTierSheet(context, controller: _c);
    if (line != null) _c.setInviteNotice(line);
  }

  Future<void> _revoke(EventInvite invite) async {
    final ok = await confirmAction(
      context,
      title: 'Revoke This Invite?',
      message: '${invite.name} is taken off the guest list.',
      confirm: 'Revoke',
    );
    if (!ok) return;
    _say(await _c.removeInvite(invite));
  }

  // --- speakers, sponsors, tickets, attendance ---------------------------------------------------------------------

  Future<void> _openProposal(EventProposal p) async {
    final decided = await showProposalSheet(context, controller: _c, proposal: p);
    if (decided && mounted) showMessage(context, 'Decision saved. The speaker has been told.');
  }

  Future<void> _openPackage([SponsorPackage? p]) async {
    final done = await showPackageSheet(context, controller: _c, package: p);
    if (done != null && mounted) showMessage(context, done == 'removed' ? 'Package removed.' : 'Package saved.');
  }

  Future<void> _openSponsorship(SponsorshipRequest r) async {
    final decided = await showSponsorshipSheet(context, controller: _c, request: r);
    if (decided && mounted) showMessage(context, 'Decision saved. The company has been told.');
  }

  Future<void> _refund(TicketRow t) async {
    final outcome = await showRefundSheet(context, controller: _c, ticket: t);
    if (outcome is RefundDone && mounted) showMessage(context, 'Refund recorded.');
  }

  Future<void> _markAttendance() async {
    final line = await showAttendanceSheet(context, controller: _c);
    if (line != null) _c.setAttendanceNotice(line);
  }

  // --- the page ----------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TitleBar(
              title: 'Manage Event',
              onBack: widget.onBack,
              unread: widget.unread,
              onBell: widget.onBell ?? () {},
            ),
            Expanded(
              child: ListenableBuilder(listenable: _c, builder: (context, _) => _body()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final e = _c.event;
    if (e == null) {
      if (_c.loading) return const EmLoading();
      return ListView(
        children: [
          _c.gone
              ? const EmEmpty(key: ValueKey('event.gone'), title: 'Event not found', body: 'It may have been removed.')
              : EmError(key: const ValueKey('event.error'), message: _c.error ?? '', onRetry: _c.refresh),
        ],
      );
    }
    final now = eventsNow();
    final programme = _c.programme;
    final standing = standingOf(e, now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${e.kindLabel}${e.host != null ? ' · ${e.host}' : ''}',
                style: EmText.meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                e.title,
                key: const ValueKey('event.heading'),
                style: EmText.pageTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              EmStatus(label: standingLabel(standing), tone: standingTone(standing)),
            ],
          ),
        ),
        EmTabs(
          keyPrefix: 'event-tab',
          labels: [
            'Details',
            'Guest List${programme != null ? ' (${programme.invites.length})' : ''}',
            'Speakers${programme != null ? ' (${programme.toReview} to review)' : ''}',
            'Sponsors${programme != null ? ' (${programme.toDecide} to decide)' : ''}',
            'Tickets',
            'Attendance',
          ],
          selected: _tab,
          onSelect: (i) => setState(() => _tab = i),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _c.refresh,
            child: ListView(
              key: ValueKey('event-tab-body-$_tab'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 28),
              children: switch (_tab) {
                0 => _details(e),
                1 => _guestList(e),
                2 => _speakers(),
                3 => _sponsors(),
                4 => _tickets(e),
                _ => _attendance(e, now),
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- Details -----------------------------------------------------------------------------------------------------

  List<Widget> _details(ManagedEvent e) {
    final description = _description(e.description);
    final page = e.slug == null ? null : AppConfig.sitePage('/events/${e.slug}');
    // The public page opens only where the app has a screen of its own for it, never a web view.
    final opens = page != null && e.published && SiteRoutes.hasScreen(page) == true;
    return [
      if (e.coverUrl != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 16 / 7,
              child: AccountImage(
                source: e.coverUrl,
                fallback: const ColoredBox(color: AppColors.surfaceContainer),
              ),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmDetail(label: 'Date', value: longDayLabel(e.startsAt)),
            EmDetail(label: 'Time', value: timeRangeLabel(e)),
            EmDetail(label: 'Location', value: e.location ?? '—'),
            EmDetail(
              label: 'Hosted by',
              value: e.hostCompany != null ? '${e.hostCompany!.name} (partner)' : (e.host ?? 'ICR'),
            ),
            EmDetail(label: 'Attendance', value: attendanceLine(e)),
            EmDetail(label: 'Price', value: e.priced ? '${eventPriceLabel(e)} (GST added at checkout)' : 'Free'),
            EmDetail(label: 'Who can join', value: e.inviteOnly ? 'Invited members only' : 'Any member'),
            EmDetail(
              label: 'Call for speakers',
              value: e.callForSpeakersUntil != null
                  ? 'Open until ${dayLabel(e.callForSpeakersUntil!)}'
                  : 'Not taking talks',
            ),
            EmDetail(label: 'Visibility', value: e.published ? 'Listed publicly' : 'Hidden from the calendar'),
            if (e.slug != null)
              EmDetail(
                label: 'Public page',
                child: opens
                    ? InkWell(
                        key: const ValueKey('event.publicPage'),
                        onTap: () => openUrl(context, page),
                        child: Text('/events/${e.slug}', style: EmText.body.copyWith(color: AppColors.primary)),
                      )
                    : Text(
                        e.published ? '/events/${e.slug}' : '/events/${e.slug} (not live while hidden)',
                        style: EmText.body.copyWith(color: e.published ? null : AppColors.outline),
                      ),
              ),
            if (e.createdAt != null) EmDetail(label: 'Created', value: dayLabel(e.createdAt!)),
            const SizedBox(height: 16),
            Text('Description', style: EmText.label),
            const SizedBox(height: 6),
            if (description.isEmpty)
              Text('No description yet.', style: EmText.body.copyWith(color: AppColors.outline))
            else
              ...description,
            const SizedBox(height: 12),
            Row(
              children: [
                WsButton(
                  key: const ValueKey('event.edit'),
                  label: 'Edit Event',
                  icon: Icons.edit_outlined,
                  filled: true,
                  onPressed: _edit,
                ),
                const Spacer(),
                TextButton(
                  key: const ValueKey('event.remove'),
                  onPressed: _removing ? null : _remove,
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: Text(_removing ? 'Removing…' : 'Remove Event', style: EmText.danger),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  /// The description as the public page reads it: the overview, then each heading with its paragraphs or its
  /// list, then whatever was written outside the form's fields.
  static final _newline = RegExp(r'\n');
  static final _blankLine = RegExp(r'\n\s*\n');

  List<Widget> _description(String? html) {
    final about = parseAbout(html);
    Widget line(String text, {bool bullet = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: bullet
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 16, child: Text('•', style: EmText.body)),
                Expanded(child: Text(text, style: EmText.body)),
              ],
            )
          : Text(text, style: EmText.body),
    );
    return [
      for (final s in eventDescriptionSections)
        if ((about.values[s.key] ?? '').trim().isNotEmpty) ...[
          if (!s.lead)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Text(s.heading, style: EmText.rowTitle),
            ),
          // A list is one item to a line; text is paragraphs, a blank line between them.
          for (final part in about.values[s.key]!.split(s.list ? _newline : _blankLine))
            if (part.trim().isNotEmpty) line(part.trim(), bullet: s.list),
        ],
      for (final p in paragraphs(about.extra)) line(p),
    ];
  }

  // --- Guest List --------------------------------------------------------------------------------------------------

  /// The programme's reads as one of three states: loading, failed, or [build] with what came back.
  List<Widget> _withProgramme(List<Widget> Function(EventProgramme p) build) {
    final p = _c.programme;
    if (p == null) {
      if (_c.programmeLoading) return const [EmLoading()];
      return [EmError(message: _c.programmeError ?? '', onRetry: _c.refresh)];
    }
    return build(p);
  }

  List<Widget> _guestList(ManagedEvent e) => _withProgramme(
    (p) => [
      if (!e.inviteOnly)
        const EmNote(
          text:
              'This event is open to everyone. Invites still work as a guest list and a nudge; switch on “Invite '
              'only” in the event to restrict RSVPs to it.',
        ),
      if (_c.inviteNotice != null)
        EmNote(
          key: const ValueKey('invite.notice'),
          text: _c.inviteNotice!,
          tone: EmTone.good,
          onClose: () => _c.setInviteNotice(null),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            WsButton(
              key: const ValueKey('invite.byEmail'),
              label: 'Invite by Email',
              icon: Icons.mail_outline,
              filled: true,
              onPressed: _inviteByEmail,
            ),
            WsButton(
              key: const ValueKey('invite.byTier'),
              label: 'Invite by Tier',
              icon: Icons.workspace_premium_outlined,
              onPressed: _inviteByTier,
            ),
          ],
        ),
      ),
      EmHeading(title: '${p.invites.length} invited'),
      const EmHairline(),
      if (p.invites.isEmpty)
        const EmEmpty(title: 'Nobody is on the guest list yet', body: 'Invite members by email, or a whole tier.')
      else
        for (final i in p.invites) ...[
          Padding(
            key: ValueKey('invite-${i.userId}'),
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.name, style: EmText.rowTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        '${i.email} · ${i.sourceLabel}',
                        style: EmText.meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (_c.busy.contains(i.id))
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else
                  IconButton(
                    key: ValueKey('invite-revoke-${i.userId}'),
                    tooltip: 'Revoke',
                    onPressed: () => _revoke(i),
                    icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                  ),
              ],
            ),
          ),
          const EmHairline(),
        ],
    ],
  );

  // --- Speakers ----------------------------------------------------------------------------------------------------

  List<Widget> _speakers() => _withProgramme(
    (p) => [
      if (p.proposals.isEmpty)
        const EmEmpty(
          key: ValueKey('proposals.empty'),
          title: 'No talk proposals yet',
          body: 'Set a call-for-speakers date on the event to open the call.',
        )
      else
        for (final t in p.proposals) ...[
          InkWell(
            key: ValueKey('proposal-${t.id}'),
            onTap: () => _openProposal(t),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(t.title, style: EmText.rowTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: EmStatus(label: proposalStatusLabel(t.status), tone: proposalTone(t.status)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [t.speaker, t.email, if (t.bio != null) t.bio!].join(' · '),
                    style: EmText.meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(t.abstract, style: EmText.secondary, maxLines: 3, overflow: TextOverflow.ellipsis),
                  if (t.reviewNote != null) ...[
                    const SizedBox(height: 4),
                    Text('Note: ${t.reviewNote}', style: EmText.meta, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ),
          const EmHairline(),
        ],
    ],
  );

  // --- Sponsors ----------------------------------------------------------------------------------------------------

  List<Widget> _sponsors() => _withProgramme(
    (p) => [
      EmHeading(
        title: 'Packages',
        action: WsButton(
          key: const ValueKey('package.add'),
          label: 'Add a Package',
          icon: Icons.add,
          filled: true,
          onPressed: () => _openPackage(),
        ),
      ),
      const EmHairline(),
      if (p.packages.isEmpty)
        const EmEmpty(title: 'No packages yet', body: 'Add one for companies to ask for.')
      else
        for (final k in p.packages) ...[
          InkWell(
            key: ValueKey('package-${k.id}'),
            onTap: () => _openPackage(k),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${k.name} · ${rupeesLabel(k.pricePaisa)}'
                          '${k.slots != null ? ' · ${k.taken}/${k.slots} taken' : ''}',
                          style: EmText.rowTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (k.benefits.isNotEmpty)
                          Text(
                            k.benefits.join(' · '),
                            style: EmText.meta,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 20, color: AppColors.outline),
                ],
              ),
            ),
          ),
          const EmHairline(),
        ],
      const EmHeading(title: 'Requests'),
      const EmHairline(),
      if (p.sponsorships.isEmpty)
        const EmEmpty(key: ValueKey('sponsorships.empty'), title: 'No sponsorship requests yet')
      else
        for (final r in p.sponsorships) ...[
          InkWell(
            key: ValueKey('sponsorship-${r.id}'),
            onTap: () => _openSponsorship(r),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '${r.company} — ${r.package}',
                          style: EmText.rowTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: EmStatus(label: sponsorshipStatusLabel(r.status), tone: sponsorshipTone(r.status)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${r.contact} · ${r.email}', style: EmText.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (r.note != null) ...[
                    const SizedBox(height: 4),
                    Text(r.note!, style: EmText.secondary, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  if (r.decisionNote != null) ...[
                    const SizedBox(height: 4),
                    Text('Note: ${r.decisionNote}', style: EmText.meta, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ),
          const EmHairline(),
        ],
    ],
  );

  // --- Tickets -----------------------------------------------------------------------------------------------------

  List<Widget> _tickets(ManagedEvent e) {
    final pending = _c.refundPending;
    return [
      if (pending != null)
        EmNote(
          key: const ValueKey('refund.pending'),
          title: approvalSentTitle,
          text: approvalSentBody(pending.amountPaisa),
        ),
      if (_c.ticketsLoading && _c.tickets.isEmpty)
        const EmLoading()
      else if (_c.ticketsError != null && _c.tickets.isEmpty)
        EmError(message: _c.ticketsError!, onRetry: _c.refresh)
      else if (_c.tickets.isEmpty)
        EmEmpty(
          key: const ValueKey('tickets.empty'),
          title: 'No tickets sold yet',
          body: e.priced ? null : 'This event is free, so it sells no tickets.',
        )
      else ...[
        for (final t in _c.tickets) ...[
          InkWell(
            key: ValueKey('ticket-${t.id}'),
            // A paid ticket opens its refund; any other only shows where it stands.
            onTap: t.refundable ? () => _refund(t) : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.name, style: EmText.rowTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          '${t.email}${t.couponCode != null ? ' · code ${t.couponCode}' : ''}',
                          style: EmText.meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (t.refundRef != null)
                          Text(
                            'Refund reference: ${t.refundRef}',
                            style: EmText.meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (t.refundable)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Refund', style: EmText.link),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(moneyLabel(t.totalPaisa), style: EmText.rowTitle),
                      const SizedBox(height: 2),
                      EmStatus(label: ticketStatusLabel(t.status), tone: _ticketTone(t.status)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const EmHairline(),
        ],
        if (_c.hasMoreTickets) EmMore(busy: _c.ticketsLoadingMore, onTap: _c.loadMoreTickets),
      ],
    ];
  }

  static EmTone _ticketTone(String status) => switch (status) {
    'PAID' => EmTone.good,
    'REFUNDED' => EmTone.warn,
    _ => EmTone.muted,
  };

  // --- Attendance --------------------------------------------------------------------------------------------------

  List<Widget> _attendance(ManagedEvent e, DateTime now) {
    final started = e.hasStarted(now);
    final ready = _c.programme != null && !_c.ticketsLoading;
    final people = ready ? _c.attendanceCandidates : const [];
    return [
      if (_c.attendanceNotice != null)
        EmNote(
          key: const ValueKey('attendance.notice'),
          text: _c.attendanceNotice!,
          tone: EmTone.good,
          onClose: () => _c.setAttendanceNotice(null),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(attendanceLine(e), key: const ValueKey('attendance.line'), style: EmText.rowTitle),
            const SizedBox(height: 6),
            Text(
              'Record who actually turned up. An RSVP is an intention; only attendance earns CPD hours, credited '
              'from the event’s length.',
              style: EmText.secondary,
            ),
            const SizedBox(height: 6),
            Text(
              !started
                  ? 'Attendance can be marked once the event has started.'
                  : !ready
                  ? 'Reading the guest list and the tickets…'
                  : people.isEmpty
                  ? 'Nobody to mark yet: the guest list and the paid tickets are who can be marked here.'
                  : 'The guest list and the paid ticket holders can be marked here (${people.length}).',
              key: const ValueKey('attendance.hint'),
              style: EmText.meta,
            ),
            if (started && people.isNotEmpty) ...[
              const SizedBox(height: 14),
              WsButton(
                key: const ValueKey('attendance.mark'),
                label: 'Mark Attendance',
                icon: Icons.how_to_reg_outlined,
                filled: true,
                onPressed: _markAttendance,
              ),
            ],
          ],
        ),
      ),
    ];
  }
}
