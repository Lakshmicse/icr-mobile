import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/links.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/title_bar.dart' show BarEditButton;
import '../feed/feed_models.dart';
import 'event_models.dart';
import 'event_sheet.dart';
import 'event_tickets.dart';
import 'events_controller.dart';
import 'events_styles.dart';
import 'widgets/event_card.dart';
import 'widgets/events_header.dart';
import 'widgets/spotlight_card.dart';

/// The Events tab: the board from the Events design.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, required this.onBack, required this.viewer, required this.onAccount, this.onManage});

  /// The pencil beside the bell: the Manage Events page, for the staff who run events. No pencil when null.
  final VoidCallback? onManage;

  /// Takes the shell back to Home. The design's header has no back arrow (the
  /// reader's photo sits there) and the shell's own `PopScope` already returns
  /// to Home on the hardware back, so the screen calls this only from the
  /// "Back to Home" action of its error state.
  final VoidCallback onBack;

  /// The signed-in person, for the header's photo.
  final FeedAuthor viewer;

  /// The header's photo opens the account menu.
  final VoidCallback onAccount;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final events = context.read<EventsController>();
    if (!events.started) events.start();
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> action) async {
    final message = await action;
    if (message != null && mounted) showMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final events = context.watch<EventsController>();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                top: EventsHeader.height,
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: events.refresh,
                  child: CustomScrollView(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: EventsToolbar(searchController: _search)),
                      ..._body(events),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: EventsHeader(
                  photo: widget.viewer.photo,
                  initials: widget.viewer.initials,
                  unread: events.unread,
                  onAvatarTap: widget.onAccount,
                  onBellTap: () => openSitePage(context, '/notifications'),
                  actions: [
                    if (widget.onManage != null) BarEditButton(label: 'Manage events', onTap: widget.onManage!),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(EventsController events) {
    final overview = events.overview;
    if (events.loading && overview == null) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))),
        ),
      ];
    }
    if (events.error != null && overview == null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Notice(
            title: 'Unable to Load Events',
            body: events.error!,
            action: 'Try Again',
            onAction: events.refresh,
            secondary: 'Back to Home',
            onSecondary: widget.onBack,
          ),
        ),
      ];
    }
    final agenda = events.agenda;
    final children = <Widget>[];
    if (!events.narrowed) {
      final spotlight = events.spotlight;
      if (spotlight != null) {
        children.add(const SizedBox(height: 6));
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: SpotlightCard(
              event: spotlight,
              onTap: () => showEventSheet(context, spotlight),
              onSave: () => events.toggleSave(spotlight),
              onAction: () => _act(spotlight),
            ),
          ),
        );
      }
      // The "My Schedule" and "CPD Earned" tiles that sat here went (owner, 12 Nov 2026: no count tiles over the Chapters, Councils and Events hubs); a booked
      // event's sheet, with its pass and Cancel, opens from its own card.
      if (events.tracks.isNotEmpty) {
        children.add(const SizedBox(height: 10));
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 9.5),
            child: Row(
              children: [
                Expanded(child: Text('Explore by Category', style: EventsText.heading)),
                Text('${events.tracks.length} Tracks', style: EventsText.headingAside),
              ],
            ),
          ),
        );
        children.add(const SizedBox(height: 17.5));
        children.add(_TrackRow(tracks: events.tracks, selectedKey: events.track?.key, onSelect: events.selectTrack));
      }
    }
    children.add(SizedBox(height: events.narrowed ? 10.0 : 4.5));
    children.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Text(events.agendaTitle, style: EventsText.heading, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (!events.narrowed && events.readyCount > 0) ...[
              const SizedBox(width: 6.5),
              Container(
                height: 16.5,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: EventsColors.readyPill, borderRadius: BorderRadius.circular(8.25)),
                child: Text('${events.readyCount} Ready', style: EventsText.readyPill),
              ),
            ],
            if (events.filtered) ...[
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _search.clear();
                  events.clearAll();
                },
                child: Text('Clear', style: AppText.sectionAction),
              ),
            ],
          ],
        ),
      ),
    );
    children.add(const SizedBox(height: 7));
    if (agenda.isEmpty) {
      children.add(
        _Notice(
          title: events.narrowed ? 'No Events Match' : 'No Upcoming Events',
          body: events.narrowed
              ? 'Try other words, or clear the filters.'
              : 'New events will appear here when ICR announces them.',
        ),
      );
    } else {
      for (var i = 0; i < agenda.length; i += 2) {
        if (i > 0) children.add(const SizedBox(height: 4));
        final left = agenda[i];
        final right = i + 1 < agenda.length ? agenda[i + 1] : null;
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 9, right: 9.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _card(events, left)),
                const SizedBox(width: 3),
                Expanded(child: right == null ? const SizedBox.shrink() : _card(events, right)),
              ],
            ),
          ),
        );
      }
    }
    children.add(const SizedBox(height: 24));
    children.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: _HostCard(blurb: events.hostBlurb, onSubmit: () => openSitePage(context, '/contact')),
      ),
    );
    children.add(const SizedBox(height: 24));
    return [SliverList(delegate: SliverChildListDelegate(children))];
  }

  Widget _card(EventsController events, EventSummary e) => EventCard(
    key: ValueKey(e.id),
    event: e,
    onTap: () => showEventSheet(context, e),
    onSave: () => events.toggleSave(e),
    onShare: () => _share(e),
    onAction: () => _act(e),
  );

  void _share(EventSummary e) {
    final link = context.read<EventsController>().repository.link(e);
    SharePlus.instance.share(ShareParams(text: '${e.title}\n$link', subject: e.title));
  }

  /// A card's button: a free seat is taken here, a ticket is bought and paid for in the app's own payment view
  /// (`buyEventTicket`), and an invitation or anything already held opens the sheet.
  void _act(EventSummary e) {
    final events = context.read<EventsController>();
    final open = !e.past && !e.rsvp.holds && !e.inviteOnly;
    if (open && e.priced) {
      _run(buyEventTicket(context, events.repository, e, onPaid: events.refresh));
      return;
    }
    if (open) {
      _run(events.register(e).then((m) => m ?? (e.full ? 'Added to the waitlist.' : 'You are registered.')));
      return;
    }
    showEventSheet(context, e);
  }
}

/// Under the header: the search with its filter glyph, then the chips.
class EventsToolbar extends StatelessWidget {
  const EventsToolbar({super.key, required this.searchController});

  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final events = context.watch<EventsController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 13.5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SearchBox(
            controller: searchController,
            onSubmitted: events.setSearch,
            onFilters: () => showEventFilters(context),
          ),
        ),
        const SizedBox(height: 11.5),
        ChipRow(
          height: 26,
          gap: 5.5,
          padding: 13,
          children: [
            for (final chip in events.chips)
              IcrChip(
                label: chip.label,
                tone: chip.selected ? ChipTone.primary : ChipTone.outlined,
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                onTap: chip.select,
              ),
          ],
        ),
      ],
    );
  }
}

/// The search box: 35 dp, a hairline border, the small magnifier, the hint
/// and the sliders glyph that opens the filters.
class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.onSubmitted, required this.onFilters});

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onFilters;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 35,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17.5),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(LucideIcons.search, size: 11.5, color: AppColors.outline),
          const SizedBox(width: 8.5),
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => TextField(
                controller: controller,
                style: EventsText.searchInput,
                textInputAction: TextInputAction.search,
                onSubmitted: onSubmitted,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Search events, summits, webinars...',
                  hintStyle: EventsText.searchHint,
                  hintMaxLines: 1,
                  suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear Search',
                          padding: EdgeInsets.zero,
                          iconSize: 14,
                          onPressed: () {
                            controller.clear();
                            onSubmitted('');
                          },
                          icon: const Icon(LucideIcons.x, color: AppColors.outline),
                        ),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Filters',
            child: InkResponse(
              onTap: onFilters,
              radius: 18,
              child: const SizedBox(
                width: 28,
                height: 28,
                child: Icon(LucideIcons.slidersHorizontal, size: 12.5, color: AppColors.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(width: 7),
        ],
      ),
    );
  }
}

/// "Explore by Category": a sideways row of tinted tiles.
class _TrackRow extends StatelessWidget {
  const _TrackRow({required this.tracks, required this.onSelect, this.selectedKey});

  final List<EventTrack> tracks;
  final ValueChanged<EventTrack> onSelect;

  /// The tile the agenda is narrowed to: it wears the brand's pale tint.
  final String? selectedKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: tracks.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final t = tracks[i];
          final (icon, color) = _trackGlyph(t.icon);
          final selected = t.key == selectedKey;
          // A tinted tile; the one the agenda is narrowed to takes the brand's pale tint instead of a border.
          return Material(
            color: selected ? AppColors.chipEmphasis : EventsColors.panel,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => onSelect(t),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                        child: Icon(icon, size: 13, color: color),
                      ),
                    ),
                    const SizedBox(width: 5.5),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.label, style: EventsText.trackTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('${t.count} Event${t.count == 1 ? '' : 's'}', style: EventsText.trackCount),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static (IconData, Color) _trackGlyph(TrackIcon icon) => switch (icon) {
    TrackIcon.offices => (LucideIcons.building2, AppColors.onSurfaceVariant),
    TrackIcon.tech => (Symbols.precision_manufacturing, AppColors.primary),
    TrackIcon.sustainability => (LucideIcons.leaf, AppColors.tertiary),
    TrackIcon.conference => (LucideIcons.presentation, AppColors.primary),
    TrackIcon.webinar => (LucideIcons.monitorPlay, AppColors.primary),
    TrackIcon.workshop => (LucideIcons.wrench, AppColors.tertiary),
    TrackIcon.masterclass => (LucideIcons.graduationCap, AppColors.tertiary),
    TrackIcon.roundtable => (LucideIcons.messagesSquare, AppColors.onSurfaceVariant),
    TrackIcon.chapter => (LucideIcons.mapPin, AppColors.onSurfaceVariant),
    TrackIcon.leadership => (LucideIcons.users, AppColors.onSurfaceVariant),
    TrackIcon.legal => (LucideIcons.scale, AppColors.onSurfaceVariant),
    TrackIcon.finance => (LucideIcons.landmark, AppColors.primary),
    TrackIcon.construction => (LucideIcons.hardHat, AppColors.onSurfaceVariant),
    TrackIcon.datacentre => (LucideIcons.server, AppColors.primary),
    TrackIcon.procurement => (LucideIcons.handshake, AppColors.tertiary),
  };
}

/// "Host or Propose an Event", the light-blue card at the foot of the board.
class _HostCard extends StatelessWidget {
  const _HostCard({required this.blurb, required this.onSubmit});

  final String blurb;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 71,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(color: AppColors.chipEmphasis, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
            child: const Icon(LucideIcons.calendarPlus, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Host or Propose an Event', style: EventsText.hostTitle),
                const SizedBox(height: 11.5),
                Text(blurb, style: EventsText.hostBody, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onSubmit,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 83,
                height: 34,
                child: Center(child: Text('Submit Topic', style: EventsText.hostButton)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Filters sheet: upcoming or past, online or in person.
Future<void> showEventFilters(BuildContext context) async {
  final events = context.read<EventsController>();
  final result = await showModalBottomSheet<EventQuery>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheet) => _FilterSheet(initial: events.query),
  );
  if (result != null) events.setQuery(result);
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});

  final EventQuery initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late var _query = widget.initial;

  @override
  Widget build(BuildContext context) {
    final labelStyle = AppText.small.copyWith(color: AppColors.onSurface, fontSize: 14);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Filters', style: EventsText.formTitle),
            const SizedBox(height: 12),
            Text('When', style: EventsText.formLabel),
            Wrap(
              spacing: 8,
              children: [
                for (final (window, label) in [(EventWhen.upcoming, 'Upcoming'), (EventWhen.past, 'Past')])
                  ChoiceChip(
                    label: Text(label),
                    selected: _query.when == window,
                    onSelected: (_) => setState(() => _query = _query.copyWith(when: window)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Format', style: EventsText.formLabel),
            Wrap(
              spacing: 8,
              children: [
                for (final (format, label) in [
                  (FormatFilter.any, 'Anywhere'),
                  (FormatFilter.online, 'Online'),
                  (FormatFilter.inPerson, 'In Person'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _query.format == format,
                    onSelected: (_) => setState(() => _query = _query.copyWith(format: format)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, EventQuery(search: _query.search)),
                  child: Text('Clear All', style: labelStyle.copyWith(color: AppColors.primary)),
                ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary, shape: const StadiumBorder()),
                  onPressed: () => Navigator.pop(context, _query),
                  child: const Text('Show Events'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.title,
    required this.body,
    this.action,
    this.onAction,
    this.secondary,
    this.onSecondary,
  });

  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;
  final String? secondary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.calendarDays, size: 36, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: AppText.postTitle.copyWith(fontSize: 16, height: 1.3)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: AppText.small),
          if (action != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.outlineVariant),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(action!, style: AppText.link),
            ),
          ],
          if (secondary != null) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: onSecondary,
              child: Text(secondary!, style: AppText.link),
            ),
          ],
        ],
      ),
    );
  }
}
