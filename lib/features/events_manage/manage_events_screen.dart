import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/widgets/title_bar.dart';
import '../account/widgets/account_kit.dart' show showAccountPicker;
import '../events/event_format.dart' show clock;
import '../events/event_models.dart' show EventKind, eventsNow;
import '../shell/app_shell.dart';
import '../workspaces/page_kit.dart' show WsButton;
import 'event_form_sheet.dart';
import 'events_manage_controllers.dart';
import 'events_manage_kit.dart';
import 'events_manage_models.dart';
import 'events_manage_repository.dart';
import 'events_manage_rules.dart';
import 'events_manage_sheets.dart';
import 'manage_event_screen.dart';

/// Manage Events — the staff Events console in the app (the website's `/admin/community?tab=events` and
/// `?tab=event-hosts`, for staff holding `events:manage`). Two tabs: **Events**, the whole calendar with its
/// search, filters and "New Event" (`EventsAdminPanel`), each row opening that event's manage page; and
/// **Event Partners**, the companies asking to host events (`EventHostRequestsPanel`).
class ManageEventsScreen extends StatefulWidget {
  const ManageEventsScreen({
    super.key,
    required this.repository,
    required this.onBack,
    this.onBell,
    this.unread = 0,
    this.initialTab,
    this.focusHostApplicationId,
    this.pageWrap,
    this.pickers = const EventPickers(),
  });

  final EventsManageRepository repository;
  final VoidCallback onBack;
  final VoidCallback? onBell;
  final int unread;

  /// `event-hosts` opens on Event Partners; anything else on Events.
  final String? initialTab;

  /// A notification's request: Event Partners lists every standing, scrolls to it and opens it.
  final String? focusHostApplicationId;

  /// Put round every page this one pushes (the app's bottom bar).
  final Widget Function(Widget page)? pageWrap;

  /// The day and time dialogs of the event form (tests answer for them).
  final EventPickers pickers;

  @override
  State<ManageEventsScreen> createState() => _ManageEventsScreenState();
}

class _ManageEventsScreenState extends State<ManageEventsScreen> {
  late final ManageEventsController _events = ManageEventsController(widget.repository);
  late final HostRequestsController _hosts = HostRequestsController(
    widget.repository,
    focusId: widget.focusHostApplicationId,
  );
  late int _tab = widget.initialTab == 'event-hosts' || widget.focusHostApplicationId != null ? 1 : 0;

  @override
  void initState() {
    super.initState();
    _events.start();
    _hosts.start();
  }

  @override
  void dispose() {
    _events.dispose();
    _hosts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TitleBar(
              title: 'Manage Events',
              onBack: widget.onBack,
              unread: widget.unread,
              onBell: widget.onBell ?? () {},
            ),
            EmTabs(
              keyPrefix: 'manage-events-tab',
              labels: const ['Events', 'Event Partners'],
              selected: _tab,
              onSelect: (i) => setState(() => _tab = i),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _EventsTab(
                    controller: _events,
                    repository: widget.repository,
                    pageWrap: widget.pageWrap,
                    onBell: widget.onBell,
                    unread: widget.unread,
                    pickers: widget.pickers,
                  ),
                  _HostRequestsTab(controller: _hosts),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Events ----------------------------------------------------------------------------------------------------------

class _EventsTab extends StatefulWidget {
  const _EventsTab({
    required this.controller,
    required this.repository,
    required this.pageWrap,
    required this.onBell,
    required this.unread,
    required this.pickers,
  });

  final ManageEventsController controller;
  final EventsManageRepository repository;
  final Widget Function(Widget page)? pageWrap;
  final VoidCallback? onBell;
  final int unread;
  final EventPickers pickers;

  @override
  State<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<_EventsTab> {
  final _search = TextEditingController();
  Timer? _debounce;

  ManageEventsController get c => widget.controller;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _typed(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => c.setSearch(text.trim()));
  }

  Future<void> _pickKind() async {
    const all = 'ALL';
    final picked = await showAccountPicker<String>(
      context,
      title: 'Type',
      items: [all, for (final k in EventKind.values) k.apiKey],
      labelOf: (k) => k == all ? 'All Types' : EventKind.fromApi(k).label,
      selected: c.kind ?? all,
    );
    if (picked != null) c.setKind(picked == all ? null : picked);
  }

  Future<void> _pickHost() async {
    const all = 'all';
    final picked = await showAccountPicker<String>(
      context,
      title: 'Host',
      items: const [all, 'icr', 'partner'],
      labelOf: _hostLabel,
      selected: c.host ?? all,
    );
    if (picked != null) c.setHost(picked == all ? null : picked);
  }

  static String _hostLabel(String host) => switch (host) {
    'icr' => 'ICR Events',
    'partner' => 'Partner Events',
    _ => 'All Hosts',
  };

  Future<void> _newEvent() async {
    final saved = await showEventFormSheet(
      context,
      repository: widget.repository,
      pickers: widget.pickers,
      onSave: (body) async => (await c.create(body)).refusal,
    );
    if (saved && mounted) showMessage(context, 'Event created.');
  }

  Future<void> _open(ManagedEvent e) async {
    final wrap = widget.pageWrap ?? (Widget p) => p;
    await AppShell.push<void>(
      context,
      (pageContext) => wrap(
        ManageEventScreen(
          repository: widget.repository,
          eventId: e.id,
          initial: e,
          onBack: () => Navigator.of(pageContext).maybePop(),
          onBell: widget.onBell,
          unread: widget.unread,
          pageWrap: widget.pageWrap,
          pickers: widget.pickers,
        ),
      ),
    );
    // What was edited, removed or sold there shows in the list.
    if (mounted) c.refresh();
  }

  void _clear() {
    _debounce?.cancel();
    _search.clear();
    c.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final now = eventsNow();
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: c.refresh,
          child: ListView(
            key: const ValueKey('manage-events-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Text(
                  'Create and run the events calendar — ICR and partner events, programme, invitations, sponsorships '
                  'and tickets.',
                  style: EmText.secondary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: EmSearch(
                  fieldKey: const Key('events.search'),
                  controller: _search,
                  hint: 'Search by title, place, host, chapter or council',
                  onChanged: _typed,
                ),
              ),
              EmPillRow(
                children: [
                  for (final (value, label) in const [(null, 'All'), ('upcoming', 'Upcoming'), ('past', 'Past')])
                    EmPill(
                      key: ValueKey('events.when.${value ?? 'all'}'),
                      label: label,
                      on: c.when == value,
                      onTap: () => c.setWhen(value),
                    ),
                  EmPill(
                    key: const ValueKey('events.kind'),
                    label: c.kind == null ? 'All Types' : EventKind.fromApi(c.kind).label,
                    on: c.kind != null,
                    caret: true,
                    onTap: _pickKind,
                  ),
                  EmPill(
                    key: const ValueKey('events.host'),
                    label: _hostLabel(c.host ?? 'all'),
                    on: c.host != null,
                    caret: true,
                    onTap: _pickHost,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.loaded ? '${c.total} ${c.total == 1 ? 'event' : 'events'}' : '',
                        key: const ValueKey('events.count'),
                        style: EmText.secondary,
                      ),
                    ),
                    WsButton(
                      key: const ValueKey('events.new'),
                      label: 'New Event',
                      icon: Icons.add,
                      filled: true,
                      onPressed: _newEvent,
                    ),
                  ],
                ),
              ),
              if (c.loading && c.loaded) const LinearProgressIndicator(minHeight: 2) else const EmHairline(),
              if (!c.loaded && c.error == null)
                const EmLoading()
              else if (!c.loaded)
                EmError(key: const ValueKey('events.error'), message: c.error!, onRetry: c.refresh)
              else if (c.rows.isEmpty)
                EmEmpty(
                  key: const ValueKey('events.empty'),
                  title: c.filtered ? 'No events match' : 'No events yet',
                  body: c.filtered ? 'Try another search, or clear the filters.' : 'Create one with New Event.',
                  action: c.filtered ? 'Clear Search and Filters' : null,
                  onAction: c.filtered ? _clear : null,
                )
              else ...[
                if (c.error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Text(c.error!, style: EmText.secondary.copyWith(color: AppColors.error)),
                  ),
                for (final e in c.rows) ...[
                  _EventRow(key: ValueKey('event-${e.id}'), event: e, now: now, query: c.search, onTap: () => _open(e)),
                  const EmHairline(),
                ],
                if (c.hasMore) EmMore(key: const ValueKey('events.more'), busy: c.loadingMore, onTap: c.loadMore),
              ],
              if (c.loaded && c.otherMatches.isNotEmpty) ...[
                const EmHeading(title: 'Other Matches'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('Outside the filters above.', style: EmText.meta),
                ),
                const EmHairline(),
                for (final e in c.otherMatches) ...[
                  _EventRow(
                    key: ValueKey('event-match-${e.id}'),
                    event: e,
                    now: now,
                    query: c.search,
                    onTap: () => _open(e),
                  ),
                  const EmHairline(),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

/// One event, as the website's table row: the title, its type and partner host, the day and time, who is going
/// against the seats, and the one status. The whole row opens the event's manage page.
class _EventRow extends StatelessWidget {
  const _EventRow({super.key, required this.event, required this.now, required this.query, required this.onTap});

  final ManagedEvent event;
  final DateTime now;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final standing = standingOf(e, now);
    final going = e.capacity == null ? '${e.going} going' : '${e.going} / ${e.capacity} going';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(highlighted(e.title, query, EmText.rowTitle), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      style: EmText.secondary,
                      children: [
                        TextSpan(text: e.kindLabel),
                        if (e.hostCompany != null) ...[
                          const TextSpan(text: ' · '),
                          highlighted(e.hostCompany!.name, query, EmText.secondary),
                        ],
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${dayLabel(e.startsAt)} · ${clock(e.startsAt)} · $going',
                    style: EmText.meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: EmStatus(label: standingLabel(standing), tone: standingTone(standing)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Event Partners --------------------------------------------------------------------------------------------------

class _HostRequestsTab extends StatefulWidget {
  const _HostRequestsTab({required this.controller});

  final HostRequestsController controller;

  @override
  State<_HostRequestsTab> createState() => _HostRequestsTabState();
}

class _HostRequestsTabState extends State<_HostRequestsTab> {
  final _search = TextEditingController();
  final _focusKey = GlobalKey();
  Timer? _debounce;
  bool _focusOpened = false;

  HostRequestsController get c => widget.controller;

  static const _statuses = [
    ('PENDING', 'Waiting'),
    ('APPROVED', 'Approved'),
    ('REJECTED', 'Rejected'),
    ('REVOKED', 'Revoked'),
    (null, 'All'),
  ];

  @override
  void initState() {
    super.initState();
    c.addListener(_seekFocus);
  }

  @override
  void dispose() {
    c.removeListener(_seekFocus);
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// A notification's request opens once the list holds it (the website's `focusId`).
  void _seekFocus() {
    if (_focusOpened) return;
    final hit = c.focused;
    if (hit == null) return;
    _focusOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final row = _focusKey.currentContext;
      if (row != null) Scrollable.ensureVisible(row, alignment: 0.2, duration: const Duration(milliseconds: 200));
      _open(hit);
    });
  }

  void _typed(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => c.setSearch(text.trim()));
  }

  Future<void> _open(HostApplication r) async {
    final done = await showHostRequestSheet(context, controller: c, request: r);
    if (done == null || !mounted) return;
    showMessage(context, switch (done) {
      'approve' => '${r.company} can now host events.',
      'reject' => 'Request rejected.',
      _ => 'Hosting revoked.',
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: c.refresh,
          child: SingleChildScrollView(
            key: const ValueKey('host-requests-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Text(
                    'Companies asking to host events on ICR. Approved partners publish straight to Partner events.',
                    style: EmText.secondary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: EmSearch(
                    fieldKey: const Key('hosts.search'),
                    controller: _search,
                    hint: 'Search company or contact',
                    onChanged: _typed,
                  ),
                ),
                EmPillRow(
                  children: [
                    for (final (value, label) in _statuses)
                      EmPill(
                        key: ValueKey('hosts.status.${value ?? 'ALL'}'),
                        label: value == 'PENDING' && c.pending > 0 ? '$label (${c.pending})' : label,
                        on: c.status == value,
                        onTap: () => c.setStatus(value),
                      ),
                  ],
                ),
                if (c.loading && c.loaded) const LinearProgressIndicator(minHeight: 2) else const EmHairline(),
                if (!c.loaded && c.error == null)
                  const EmLoading()
                else if (!c.loaded)
                  EmError(key: const ValueKey('hosts.error'), message: c.error!, onRetry: c.refresh)
                else if (c.rows.isEmpty)
                  EmEmpty(
                    key: const ValueKey('hosts.empty'),
                    title: c.status == 'PENDING' && c.search.isEmpty ? 'No requests waiting' : 'No requests match',
                    body: 'Companies ask from the Host an event button on the events page.',
                  )
                else ...[
                  if (c.error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Text(c.error!, style: EmText.secondary.copyWith(color: AppColors.error)),
                    ),
                  for (final r in c.rows) ...[
                    _HostRow(
                      key: r.id == c.focusId ? _focusKey : ValueKey('host-${r.id}'),
                      request: r,
                      focused: r.id == c.focusId,
                      onTap: () => _open(r),
                    ),
                    const EmHairline(),
                  ],
                  if (c.hasMore) EmMore(key: const ValueKey('hosts.more'), busy: c.loadingMore, onTap: c.loadMore),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One request, as the website's row: the company, the kinds of event and how often, the contact, the day it was
/// asked and its standing. The row opens the request.
class _HostRow extends StatelessWidget {
  const _HostRow({super.key, required this.request, required this.focused, required this.onTap});

  final HostApplication request;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Material(
      // The request a notification named is tinted, as the website selects its row.
      color: focused ? const Color(0xFFE8F0F9) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.company, style: EmText.rowTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${r.kindsLabel ?? 'Events'}${r.frequency != null ? ' · ${r.frequency}' : ''}',
                      style: EmText.secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dayLabel(r.createdAt)} · ${r.contactName} · ${r.contactEmail}',
                      style: EmText.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: EmStatus(label: hostStatusLabel(r.status), tone: hostTone(r.status)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
