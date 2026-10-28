import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../../core/widgets/chips.dart';
import 'chapter_format.dart';
import 'chapter_models.dart';
import 'chapter_screen.dart';
import 'chapters_controller.dart';
import 'community_kit.dart';
import 'widgets/chapter_card.dart';
import 'widgets/chapter_preview_sheet.dart';
import 'widgets/meetup_row.dart';

/// The Regional Chapters board: the numbers, the member's own chapters, the
/// next meetups, and the searchable directory of every city chapter.
///
/// Reads a [ChaptersController] from Provider and starts it on first build.
/// Everything that leaves the board goes through a callback the shell wires:
/// [onOpenEvent] for a meetup (the Events sheet), [onOpenVolunteer] for the
/// "lead a chapter" card, [onBell] for the bell, [onOpenMember] and [onMessage]
/// for the people on a chapter's page.
class ChaptersScreen extends StatefulWidget {
  const ChaptersScreen({
    super.key,
    required this.onBack,
    required this.onOpenEvent,
    this.onOpenVolunteer,
    this.onBell,
    this.onOpenMember,
    this.onMessage,
    this.opener = openUrl,
    this.share = shareChapterLink,
  });

  /// The arrow at the top left.
  final VoidCallback onBack;

  /// A meetup was tapped: the Events sheet, by the event's slug (else its id).
  final ValueChanged<String> onOpenEvent;

  /// "Get involved" at the foot of the board and "Volunteer with this chapter" on a chapter page (given
  /// the chapter's name there, null here); hidden when null.
  final ValueChanged<String?>? onOpenVolunteer;

  /// The bell. The ICR website's notifications page when null.
  final VoidCallback? onBell;

  /// A committee member's or a roster row on a chapter's page: their profile, by user id.
  final ValueChanged<String>? onOpenMember;

  /// The message glyph on a committee row: a conversation with that user id.
  final ValueChanged<String>? onMessage;

  /// Hands a page to the browser (or the mail app). Tests give their own.
  final Future<void> Function(BuildContext context, Uri uri) opener;

  /// Opens the phone's share sheet. Tests give their own.
  final ShareChapterLink share;

  ChapterHandoffs get _handoffs => ChapterHandoffs(
    onOpenEvent: onOpenEvent,
    onOpenVolunteer: onOpenVolunteer,
    onBell: onBell,
    onOpenMember: onOpenMember,
    onMessage: onMessage,
    opener: opener,
    share: share,
  );

  @override
  State<ChaptersScreen> createState() => _ChaptersScreenState();
}

class _ChaptersScreenState extends State<ChaptersScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    final board = context.read<ChaptersController>();
    if (!board.started) board.start();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _bell() {
    final go = widget.onBell;
    if (go != null) return go();
    widget.opener(context, AppConfig.sitePage('/notifications'));
  }

  Future<void> _run(Future<String?> action) async {
    final message = await action;
    if (message != null && mounted) showMessage(context, message);
  }

  Future<void> _leave(ChaptersController board, ChapterSummary chapter) async {
    final sure = await confirmDialog(
      context,
      title: 'Leave ${chapter.name}?',
      body: 'You will stop seeing its members-only updates. You can join again any time.',
      action: 'Leave',
    );
    if (sure && mounted) await _run(board.leave(chapter));
  }

  void _open(ChaptersController board, ChapterSummary chapter) {
    openChapterPage(
      context,
      repository: board.repository,
      idOrSlug: chapter.slug,
      handoffs: widget._handoffs,
      onChanged: board.update,
      clock: () => board.now,
    );
  }

  void _preview(ChaptersController board, ChapterSummary chapter) {
    showChapterPreview(
      context,
      board: board,
      chapter: chapter,
      onOpenEvent: (e) => widget.onOpenEvent(e.key),
      onOpenChapter: () => _open(board, chapter),
      onShare: () => widget.share(chapter.name, board.repository.link(chapter)),
    );
  }

  void _clear(ChaptersController board) {
    _search.clear();
    board.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final board = context.watch<ChaptersController>();
    return CommunityPage(
      title: 'Regional Chapters',
      onBack: widget.onBack,
      onBell: _bell,
      unread: board.unread,
      onRefresh: board.refresh,
      children: _body(board),
    );
  }

  List<Widget> _body(ChaptersController board) {
    if (board.overview == null) {
      if (board.loading || !board.started) return const [CommunityLoading()];
      return [
        CommunityNotice(
          icon: LucideIcons.cloudOff,
          title: "Couldn't load chapters",
          body: board.error ?? 'Something went wrong.',
          action: 'Try again',
          onAction: board.refresh,
        ),
      ];
    }
    final stats = board.stats!;
    final joined = board.joined;
    final meetups = board.meetups;
    final shown = board.chapters;
    final now = board.now;
    return [
      const SizedBox(height: 6),
      CommunityStatGrid(
        tiles: [
          CommunityStatTile(label: 'Chapters', value: groupThousands(stats.chapters)),
          CommunityStatTile(label: 'Members', value: groupThousands(stats.members)),
          CommunityStatTile(label: 'Countries', value: groupThousands(stats.countries)),
          CommunityStatTile(label: 'Upcoming events', value: groupThousands(stats.upcomingEvents), blue: true),
        ],
      ),
      const SizedBox(height: 8),
      const Divider(height: 1, thickness: 1, color: CommunityColors.tileRule),
      const SizedBox(height: 10),
      CommunitySectionHeading(
        title: 'Your Chapters',
        dot: AppColors.success,
        pill: joined.isEmpty ? null : '${joined.length} Joined',
      ),
      const SizedBox(height: 9),
      if (joined.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "You haven't joined a chapter yet. Find your city below and join it.",
            style: CommunityText.small,
          ),
        )
      else
        SizedBox(
          height: JoinedChapterCard.height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: joined.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => JoinedChapterCard(chapter: joined[i], onOpen: () => _open(board, joined[i])),
          ),
        ),
      const SizedBox(height: 16),
      const Divider(height: 1, thickness: 1, color: CommunityColors.tileRule),
      const SizedBox(height: 12),
      const CommunitySectionHeading(title: 'Upcoming Meetups', caption: 'Chapter events'),
      const SizedBox(height: 4),
      if (meetups.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Text('No chapter meetups are scheduled yet. Check back soon.', style: CommunityText.small),
        )
      else
        for (final (i, e) in meetups.indexed) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: CommunityColors.tileRule),
          MeetupRow(event: e, onTap: () => widget.onOpenEvent(e.key)),
        ],
      const SizedBox(height: 6),
      const Divider(height: 1, thickness: 1, color: CommunityColors.tileRule),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: CommunitySearchField(
          controller: _search,
          hint: 'Search chapters, cities or countries…',
          onChanged: board.setSearch,
          onFilters: () => _filters(board),
          filtersLabel: 'Sort and filter chapters',
          filtersActive: board.filtered || board.sort != ChapterSort.recommended,
        ),
      ),
      const SizedBox(height: 10),
      ChipRow(
        height: 31,
        gap: 6,
        padding: 16,
        children: [
          for (final scope in ChapterScope.values)
            IcrChip(
              label: '${scope.label} (${board.scopeCount(scope)})',
              tone: board.scope == scope ? ChipTone.primary : ChipTone.outlined,
              height: 31,
              textStyle: CommunityText.chip,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              onTap: () => board.setScope(scope),
            ),
        ],
      ),
      const SizedBox(height: 6),
      ChipRow(
        height: 31,
        gap: 6,
        padding: 16,
        children: [
          IcrChip(
            label: allCountriesLabel(board.countries.length),
            tone: board.country == null ? ChipTone.primary : ChipTone.outlined,
            height: 31,
            textStyle: CommunityText.chip,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            onTap: () => board.setCountry(null),
          ),
          for (final country in board.countries)
            IcrChip(
              label: country,
              tone: board.country == country ? ChipTone.primary : ChipTone.outlined,
              height: 31,
              textStyle: CommunityText.chip,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              onTap: () => board.setCountry(board.country == country ? null : country),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                board.narrowed
                    ? '${plural(shown.length, 'chapter')} of ${board.stats!.chapters}'
                    : plural(shown.length, 'chapter'),
                style: CommunityText.sectionCaption,
              ),
            ),
            if (board.narrowed)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _clear(board),
                child: Text('Clear filters', style: CommunityText.sectionLink),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      if (shown.isEmpty)
        _empty(board)
      else
        for (final c in shown)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: ChapterCard(
              chapter: c,
              busy: board.isBusy(c),
              isNew: c.isNew(now),
              onJoin: () => _run(board.join(c)),
              onLeave: () => _leave(board, c),
              onOpen: () => _open(board, c),
              onPreview: () => _preview(board, c),
            ),
          ),
      if (widget.onOpenVolunteer != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: CommunityHostCard(
            icon: LucideIcons.handHeart,
            title: 'Lead or serve on a chapter',
            body: 'Committee members and chapter leaders earn CPD credits.',
            action: 'Get involved',
            onAction: () => widget.onOpenVolunteer!(null),
          ),
        ),
      const SizedBox(height: 28),
    ];
  }

  Widget _empty(ChaptersController board) {
    // "Nearby" is relative to the member's own chapters: with none there is nothing to be near.
    if (board.scope == ChapterScope.nearby && board.scopeCount(ChapterScope.joined) == 0 && !board.filtered) {
      return CommunityNotice(
        icon: LucideIcons.mapPin,
        title: 'Nothing nearby yet',
        body: 'Nearby shows chapters in the regions and countries of the ones you join. Join your own city first.',
        action: 'Show all chapters',
        onAction: () => board.setScope(ChapterScope.all),
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      );
    }
    return CommunityNotice(
      icon: LucideIcons.mapPinOff,
      title: board.narrowed ? 'No chapters match' : 'No chapters yet',
      body: board.narrowed
          ? 'Try clearing a filter or searching for another city.'
          : 'City chapters will appear here once they are chartered.',
      action: board.narrowed ? 'Clear filters' : null,
      onAction: () => _clear(board),
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
    );
  }

  Future<void> _filters(ChaptersController board) async {
    await showCommunitySheet<void>(
      context,
      title: 'Sort and filter',
      body: (sheet, setState) {
        final regions = board.regions;
        final cities = board.cities;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CommunityChoiceWrap<ChapterSort>(
              title: 'Sort by',
              options: ChapterSort.values,
              selected: board.sort,
              label: (s) => s.label,
              onSelected: (s) => setState(() => board.setFilters(sort: s)),
            ),
            if (regions.length > 1) ...[
              const SizedBox(height: 16),
              CommunityChoiceWrap<String?>(
                title: 'Region',
                options: [null, ...regions],
                selected: board.region,
                label: (r) => r ?? 'Any region',
                onSelected: (r) => setState(() => board.setRegion(r)),
              ),
            ],
            if (cities.length > 1) ...[
              const SizedBox(height: 16),
              CommunityChoiceWrap<String?>(
                title: 'City',
                options: [null, ...cities],
                selected: board.city,
                label: (c) => c ?? 'Any city',
                onSelected: (c) => setState(() => board.setCity(c)),
              ),
            ],
            const SizedBox(height: 16),
            CommunityChoiceWrap<ChapterSize>(
              title: 'Members',
              options: ChapterSize.values,
              selected: board.size,
              label: (s) => s.label,
              onSelected: (s) => setState(() => board.setFilters(size: s)),
            ),
            const SizedBox(height: 16),
            CommunityChoiceWrap<ChapterActivity>(
              title: 'Activity',
              options: ChapterActivity.values,
              selected: board.activity,
              label: (s) => s.label,
              onSelected: (s) => setState(() => board.setFilters(activity: s)),
            ),
          ],
        );
      },
      footer: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: CommunityButton(
                label: 'Reset',
                outlined: true,
                height: 38,
                expand: true,
                onPressed: () {
                  board.setFilters(
                    sort: ChapterSort.recommended,
                    size: ChapterSize.any,
                    activity: ChapterActivity.any,
                    clearRegion: true,
                    clearCity: true,
                  );
                  Navigator.pop(sheet);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CommunityButton(
                label: 'Show chapters',
                height: 38,
                expand: true,
                onPressed: () => Navigator.pop(sheet),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
