import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/links.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/section_heading.dart';
import '../../core/widgets/title_bar.dart';
import 'council_models.dart';
import 'councils_controller.dart';
import 'councils_styles.dart';
import 'widgets/chapters_footer.dart';
import 'widgets/council_card.dart';
import 'widgets/council_search_field.dart';
import 'widgets/joined_council_card.dart';
import 'widgets/roundtable_row.dart';
import 'widgets/stat_tiles.dart';

/// The Councils screen: the stats, the member's seats, the upcoming
/// roundtables, the directory and the city chapters, as the design.
class CouncilsScreen extends StatefulWidget {
  const CouncilsScreen({super.key, required this.onBack, this.opener = openUrl});

  /// The arrow at the top left; the shell goes back to Home.
  final VoidCallback onBack;

  /// Hands a page to the browser (or the calendar app). Tests give their own
  /// to see which page a control asks for.
  final Future<void> Function(BuildContext context, Uri uri) opener;

  @override
  State<CouncilsScreen> createState() => _CouncilsScreenState();
}

class _CouncilsScreenState extends State<CouncilsScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    final councils = context.read<CouncilsController>();
    if (!councils.started) councils.start();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(Uri uri) => widget.opener(context, uri);

  Future<void> _site(String path) => _open(AppConfig.sitePage(path));

  Future<void> _run(Future<String?> action) async {
    final message = await action;
    if (message != null && mounted) showMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final councils = context.watch<CouncilsController>();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                top: TitleBar.height,
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: councils.refresh,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: _body(councils),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: TitleBar(
                  title: 'Councils',
                  onBack: widget.onBack,
                  unread: councils.unread,
                  onBell: () => _site('/notifications'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(CouncilsController councils) {
    final overview = councils.overview;
    if (overview == null) {
      if (councils.loading) {
        return const [
          SizedBox(
            height: 400,
            child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))),
          ),
        ];
      }
      return [
        _Notice(
          title: "Couldn't load councils",
          body: councils.error ?? 'Something went wrong.',
          action: 'Try again',
          onAction: councils.refresh,
        ),
      ];
    }
    final repo = councils.repository;
    final joined = councils.joined;
    final roundtables = councils.roundtables;
    final shown = councils.councils;
    return [
      const SizedBox(height: 7),
      StatTiles(stats: overview.stats),
      const SizedBox(height: 9),
      const _SoftRule(color: CouncilsColors.rowRule),
      if (joined.isNotEmpty) ...[
        const SizedBox(height: 10),
        _JoinedHeading(count: joined.length, onManage: () => _site('/councils')),
        const SizedBox(height: 9),
        SizedBox(
          height: JoinedCouncilCard.height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            clipBehavior: Clip.none,
            itemCount: joined.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) => JoinedCouncilCard(
              council: joined[i],
              onOpen: () => _open(repo.link(joined[i])),
              onRoom: () => _open(repo.link(joined[i], tab: 'events')),
              onUnread: () => _open(repo.link(joined[i], tab: 'updates')),
            ),
          ),
        ),
        const SizedBox(height: 33),
      ] else
        const SizedBox(height: 20),
      _RoundtablesHeading(caption: overview.roundtablesCaption, onCaption: () => _site('/events')),
      const SizedBox(height: 12.5),
      const Hairline(color: CouncilsColors.rowRule),
      if (roundtables.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Text('No council roundtables are scheduled yet.', style: CouncilsText.roundtableDetail),
        ),
      for (final r in roundtables) ...[
        RoundtableRow(
          roundtable: r,
          onTap: () => _open(repo.eventLink(r)),
          onCalendar: () => _open(repo.calendarLink(r)),
        ),
        const _SoftRule(color: CouncilsColors.rowRule),
      ],
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.only(left: 15, right: 15),
        child: CouncilSearchField(
          controller: _search,
          onChanged: councils.setSearch,
          onFilters: () => _pickSort(context, councils),
        ),
      ),
      const SizedBox(height: 10),
      ChipRow(
        height: 31,
        gap: 7,
        padding: 15,
        children: [
          IcrChip(
            label: 'All Categories (${overview.stats.activeCouncils})',
            tone: councils.segment == null ? ChipTone.primary : ChipTone.outlined,
            height: 31,
            padding: const EdgeInsets.symmetric(horizontal: 12.5),
            textStyle: CouncilsText.chip,
            border: CouncilsColors.cardBorder,
            onTap: () => councils.setSegment(null),
          ),
          for (final segment in councils.categories)
            IcrChip(
              label: segment,
              tone: councils.segment == segment ? ChipTone.primary : ChipTone.outlined,
              height: 31,
              padding: const EdgeInsets.symmetric(horizontal: 12.5),
              textStyle: CouncilsText.chip,
              onTap: () => councils.setSegment(councils.segment == segment ? null : segment),
            ),
        ],
      ),
      const SizedBox(height: 11.5),
      if (shown.isEmpty)
        _Notice(
          title: councils.narrowed ? 'No councils match' : 'No councils yet',
          body: councils.narrowed
              ? 'Try other words, or clear the filters.'
              : 'Councils show up here as ICR charters them.',
          action: councils.narrowed ? 'Clear filters' : null,
          onAction: councils.narrowed ? councils.clearFilters : null,
        ),
      for (final (i, c) in shown.indexed) ...[
        if (i > 0) const SizedBox(height: 4.75),
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 0, 13, 0),
          child: CouncilCard(
            key: ValueKey(c.id),
            council: c,
            busy: councils.isBusy(c),
            onJoin: () => _run(councils.join(c)),
            onLeave: () => _confirmLeave(context, councils, c),
            onOpen: () => _open(repo.link(c, tab: 'updates')),
            onPreview: () => _open(repo.link(c)),
          ),
        ),
      ],
      const SizedBox(height: 12),
      ChaptersFooter(
        chapters: councils.chapters,
        onChapter: (chapter) => _open(repo.chapterLink(chapter)),
        onDirectory: () => _site('/chapters'),
      ),
      const SizedBox(height: 24),
    ];
  }

  Future<void> _pickSort(BuildContext context, CouncilsController councils) async {
    final choice = await showModalBottomSheet<CouncilSort>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Sort councils', style: CouncilsText.sheetTitle),
              ),
            ),
            for (final sort in CouncilSort.values)
              ListTile(
                title: Text(sort.label, style: CouncilsText.sheetRow),
                trailing: councils.sort == sort
                    ? const Icon(LucideIcons.check, size: 18, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(sheet, sort),
              ),
          ],
        ),
      ),
    );
    if (choice != null) councils.setSort(choice);
  }

  Future<void> _confirmLeave(BuildContext context, CouncilsController councils, Council council) async {
    final leave = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.logOut, color: AppColors.error),
              title: Text('Leave ${council.name}', style: CouncilsText.sheetRow),
              onTap: () => Navigator.pop(sheet, true),
            ),
          ],
        ),
      ),
    );
    if (leave == true && context.mounted) await _run(councils.leave(council));
  }
}

/// A 1 dp rule with the design's faint shadow under it (the tiles' block and the roundtable rows end in one).
class _SoftRule extends StatelessWidget {
  const _SoftRule({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        color: color,
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
    );
  }
}

/// "● Your Joined Councils  [3 Active] ........ Manage →".
class _JoinedHeading extends StatelessWidget {
  const _JoinedHeading({required this.count, required this.onManage});

  final int count;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: Padding(
        padding: const EdgeInsets.only(left: 13, right: 14),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text('Your Joined Councils', style: CouncilsText.sectionTitle),
            const SizedBox(width: 10),
            Container(
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: CouncilsColors.greyPill, borderRadius: BorderRadius.circular(9)),
              child: Text('$count Active', style: CouncilsText.sectionPill),
            ),
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onManage,
              child: Row(
                children: [
                  Text('Manage', style: CouncilsText.sectionLink),
                  const SizedBox(width: 2),
                  const Icon(LucideIcons.arrowRight, size: 12, color: AppColors.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Upcoming Roundtables ........ Live Chatham-House".
class _RoundtablesHeading extends StatelessWidget {
  const _RoundtablesHeading({required this.caption, required this.onCaption});

  final String? caption;
  final VoidCallback onCaption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 15),
      child: Row(
        children: [
          Text('Upcoming Roundtables', style: CouncilsText.sectionTitle),
          const Spacer(),
          if (caption != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCaption,
              child: Text(caption!, style: CouncilsText.sectionCaption),
            ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.body, this.action, this.onAction});

  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.landmark, size: 36, color: AppColors.outline),
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
        ],
      ),
    );
  }
}
