import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/section_heading.dart';
import '../../core/widgets/title_bar.dart';
import '../shell/app_shell.dart';
import '../shell/icr_bottom_nav.dart';
import '../shell/shell_page.dart';
import 'mentorship_controller.dart';
import 'mentorship_models.dart';
import 'mentorship_styles.dart';
import 'widgets/category_chips.dart';
import 'widgets/mentor_card.dart';
import 'widgets/notice.dart';

/// How a screen opens a page of the ICR website; the browser by default, a
/// recorder in tests.
typedef OpenSite = Future<void> Function(BuildContext context, String path);

/// Pushes Find Mentors over the tab, handing it the tab's controller (a pushed
/// route sits above the shell's providers, so it cannot read them itself). Its
/// design keeps the bottom bar, with Mentorship lit. [company] opens it on an
/// employer's chip ("Company: SpaceX") with the search box empty.
Future<void> openFindMentors(
  BuildContext context, {
  String? category,
  String search = '',
  String? company,
  bool companyOnAccount = false,
  required void Function(BuildContext context, String mentorId) onOpenMentor,
  OpenSite openSite = openSitePage,
}) {
  final mentorship = context.read<MentorshipController>();
  return AppShell.push<void>(
    context,
    (route) => ShellPage(
      tab: AppTab.mentorship,
      child: ChangeNotifierProvider.value(
        value: mentorship,
        child: FindMentorsScreen(
          onBack: () => Navigator.of(route).pop(),
          onOpenMentor: onOpenMentor,
          category: category,
          search: search,
          company: company,
          companyOnAccount: companyOnAccount,
          openSite: openSite,
        ),
      ),
    ),
  );
}

/// Find Mentors: the directory with its category chips, filters and "Load
/// more mentors", as the Find Mentors design.
class FindMentorsScreen extends StatefulWidget {
  const FindMentorsScreen({
    super.key,
    required this.onBack,
    required this.onOpenMentor,
    this.category,
    this.search = '',
    this.company,
    this.companyOnAccount = false,
    this.controller,
    this.openSite = openSitePage,
  });

  final VoidCallback onBack;

  /// Opens a mentor's profile.
  final void Function(BuildContext context, String mentorId) onOpenMentor;

  /// The domain the screen opens on.
  final String? category;

  /// The words the screen opens on (the Home-style search box of the tab).
  final String search;

  /// The employer the screen opens on, as a removable chip. The search box
  /// stays empty.
  final String? company;

  /// Whether [company] is on mentors' ICR accounts (see `MentorFilters`).
  final bool companyOnAccount;

  /// A controller the caller owns (and has started); by default the screen
  /// makes its own from the [MentorshipController] in Provider.
  final FindMentorsController? controller;

  /// Opens a page of the website (the bell opens the notifications).
  final OpenSite openSite;

  @override
  State<FindMentorsScreen> createState() => _FindMentorsScreenState();
}

class _FindMentorsScreenState extends State<FindMentorsScreen> {
  late final FindMentorsController _c;
  late final bool _owns;
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    final given = widget.controller;
    _owns = given == null;
    _c =
        given ??
        FindMentorsController(
          context.read<MentorshipController>().repository,
          category: widget.category,
          search: widget.search,
          company: widget.company,
          companyOnAccount: widget.companyOnAccount,
        );
    _search = TextEditingController(text: _c.filters.search);
    if (_owns) _c.start();
  }

  @override
  void dispose() {
    _search.dispose();
    if (_owns) _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: _c,
            builder: (context, _) => Stack(
              children: [
                Positioned.fill(
                  top: TitleBar.height,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Toolbar(controller: _c),
                      Expanded(
                        child: RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: _c.refresh,
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: _body(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: TitleBar(
                    leading: _BackLeading(onBack: widget.onBack),
                    // The design leaves 12 dp between the box and the bell.
                    middle: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: IcrSearchField(controller: _search, height: 40, onSubmitted: _c.setSearch),
                    ),
                    unread: _c.unread,
                    onBell: () => widget.openSite(context, '/notifications'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    final mentors = _c.mentors;
    if (_c.loading && mentors.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))),
        ),
      ];
    }
    if (_c.error != null && mentors.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: MentorshipNotice(
            title: "Couldn't load mentors",
            body: _c.error!,
            action: 'Try again',
            onAction: _c.refresh,
          ),
        ),
      ];
    }
    if (mentors.isEmpty) {
      final narrowed = _c.filters.count > 0 || _c.filters.search.isNotEmpty;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: MentorshipNotice(
            title: narrowed ? 'No mentors match' : 'No mentors are listed yet',
            body: narrowed ? 'Try other words, or clear the filters.' : 'Mentors show up here as ICR approves them.',
            action: narrowed ? 'Clear filters' : null,
            onAction: narrowed ? () => _c.setFilters(const MentorFilters()) : null,
          ),
        ),
      ];
    }
    final rows = (mentors.length + 1) ~/ 2;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(17, 5.6, 17, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            childCount: rows,
            (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: MentorRow(
                left: mentors[i * 2],
                right: i * 2 + 1 < mentors.length ? mentors[i * 2 + 1] : null,
                onOpen: (m) => widget.onOpenMentor(context, m.id),
              ),
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: _Footer(
          shown: mentors.length,
          total: _c.total,
          hasMore: _c.hasMore,
          loadingMore: _c.loadingMore,
          inCategory: _c.filters.category != null,
          onMore: _c.loadMore,
        ),
      ),
    ];
  }
}

/// The back arrow, placed so the search box starts where the design's does.
class _BackLeading extends StatelessWidget {
  const _BackLeading({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48.25,
      child: Row(
        children: [
          const SizedBox(width: 17.75),
          Semantics(
            button: true,
            label: 'Back',
            child: InkResponse(
              onTap: onBack,
              radius: 24,
              child: const SizedBox(
                width: 24,
                height: 56,
                child: Icon(Symbols.arrow_back, size: 24, color: AppColors.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Under the title bar: the heading with its count, the category chips and
/// the filter chips, then the rule the grid hangs from.
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller});

  final FindMentorsController controller;

  @override
  Widget build(BuildContext context) {
    final filters = controller.filters;
    final total = controller.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 7.5),
        SizedBox(
          height: 20,
          child: Padding(
            padding: const EdgeInsets.only(left: 10.5, right: 20.5),
            child: Row(
              children: [
                Expanded(child: Text('Find Mentors', style: MentorshipText.heading)),
                if (!controller.loading || controller.mentors.isNotEmpty)
                  Text(total == 1 ? '1 match' : '$total matches', style: MentorshipText.matches),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8.2),
        CategoryChipRow(
          categories: controller.categories,
          selected: filters.category,
          onSelect: controller.setCategory,
        ),
        const SizedBox(height: 11.5),
        ChipRow(
          height: 25,
          gap: 5.5,
          padding: 10,
          children: [
            // The employer a company tile asked for leads the row, so its cross is on
            // screen when Find Mentors opens (the design's row has no such chip).
            if (filters.company != null)
              IcrChip(
                label: 'Company: ${filters.company}',
                tone: ChipTone.tinted,
                fill: Colors.white,
                border: MentorshipColors.chipBorder,
                trailing: const Icon(LucideIcons.circleX, size: 14, color: AppColors.onSurface),
                trailingGap: 3.6,
                padding: const EdgeInsets.only(left: 13.5, right: 10.9),
                textStyle: MentorshipText.filterChip,
                onTap: controller.clearCompany,
              ),
            IcrChip(
              label: filters.count > 0 ? 'Filters (${filters.count})' : 'Filters',
              icon: LucideIcons.slidersHorizontal,
              iconSize: 14,
              padding: const EdgeInsets.only(left: 10.9, right: 12.5),
              gap: 6.5,
              textStyle: MentorshipText.filterChip,
              onTap: () => _showFilters(context, controller),
            ),
            IcrChip(
              label: filters.sort.label,
              tone: ChipTone.tinted,
              fill: Colors.white,
              border: MentorshipColors.chipBorder,
              leading: Text('Sort:', style: MentorshipText.filterPrefix),
              gap: 5.5,
              trailing: const Icon(LucideIcons.chevronDown, size: 15, color: AppColors.onSurface),
              trailingGap: 1.3,
              padding: const EdgeInsets.only(left: 13, right: 8.5),
              textStyle: MentorshipText.filterChip,
              onTap: () => _showSort(context, controller),
            ),
            if (filters.minExperience != null)
              IcrChip(
                label: 'Exp: ${filters.minExperience}+ Yrs',
                tone: ChipTone.tinted,
                fill: Colors.white,
                border: MentorshipColors.chipBorder,
                trailing: const Icon(LucideIcons.circleX, size: 14, color: AppColors.onSurface),
                trailingGap: 3.6,
                padding: const EdgeInsets.only(left: 13.5, right: 10.9),
                textStyle: MentorshipText.filterChip,
                onTap: () => controller.setMinExperience(null),
              ),
            if (filters.availableOnly)
              IcrChip(
                label: 'Free slot',
                tone: ChipTone.tinted,
                fill: Colors.white,
                border: MentorshipColors.chipBorder,
                trailing: const Icon(LucideIcons.circleX, size: 14, color: AppColors.onSurface),
                trailingGap: 3.6,
                padding: const EdgeInsets.only(left: 13.5, right: 10.9),
                textStyle: MentorshipText.filterChip,
                onTap: () => controller.setAvailableOnly(false),
              ),
          ],
        ),
        const SizedBox(height: 10),
        const Hairline(color: AppColors.blockRule),
      ],
    );
  }
}

/// "Showing 8 of 48 mentors in this category", the bar, and "Load more mentors".
class _Footer extends StatelessWidget {
  const _Footer({
    required this.shown,
    required this.total,
    required this.hasMore,
    required this.loadingMore,
    required this.inCategory,
    required this.onMore,
  });

  static const _barWidth = 193.0;

  final int shown;
  final int total;
  final bool hasMore;
  final bool loadingMore;
  final bool inCategory;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final fraction = total <= 0 ? 0.0 : (shown / total).clamp(0.0, 1.0);
    return Column(
      children: [
        const SizedBox(height: 21.7),
        Text('Showing $shown of $total mentors${inCategory ? ' in this category' : ''}', style: MentorshipText.showing),
        const SizedBox(height: 4.5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3.2),
          child: SizedBox(
            width: _barWidth,
            height: 6.4,
            child: Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: MentorshipColors.track)),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: _barWidth * fraction,
                  child: const ColoredBox(color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
        if (hasMore) ...[
          const SizedBox(height: 6.3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: MentorshipColors.panelBorder),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: loadingMore ? null : onMore,
                child: SizedBox(
                  height: 24,
                  width: double.infinity,
                  child: Center(
                    child: loadingMore
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.8))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Load more mentors', style: MentorshipText.loadMore),
                              const SizedBox(width: 3.8),
                              const Icon(LucideIcons.chevronDown, size: 18, color: AppColors.onSurface),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

/// The Filters sheet: experience and open slots (the domain is the chips').
Future<void> _showFilters(BuildContext context, FindMentorsController controller) async {
  final result = await showModalBottomSheet<MentorFilters>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheet) => _FilterSheet(initial: controller.filters),
  );
  if (result != null) controller.setFilters(result);
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});

  final MentorFilters initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late var _filters = widget.initial;

  static const _years = [null, 5, 10, 15];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Filters', style: MentorshipText.formTitle),
            const SizedBox(height: 12),
            Text('Experience', style: MentorshipText.formLabel),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (final y in _years)
                  ChoiceChip(
                    label: Text(y == null ? 'Any' : '$y+ years'),
                    selected: _filters.minExperience == y,
                    onSelected: (_) => setState(
                      () => _filters = y == null
                          ? _filters.copyWith(clearExperience: true)
                          : _filters.copyWith(minExperience: y),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Only mentors with a free slot', style: MentorshipText.option),
              value: _filters.availableOnly,
              onChanged: (on) => setState(() => _filters = _filters.copyWith(availableOnly: on)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  // Every filter the "Filters (n)" chip counts; the words and the
                  // sort order are the member's own and stay.
                  onPressed: () => Navigator.pop(context, MentorFilters(search: _filters.search, sort: _filters.sort)),
                  child: const Text('Clear all'),
                ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary, shape: const StadiumBorder()),
                  onPressed: () => Navigator.pop(context, _filters),
                  child: const Text('Show mentors'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showSort(BuildContext context, FindMentorsController controller) async {
  final choice = await showModalBottomSheet<MentorSort>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final sort in MentorSort.values)
            ListTile(
              title: Text(sort.label, style: MentorshipText.option),
              trailing: controller.filters.sort == sort
                  ? const Icon(LucideIcons.check, size: 18, color: AppColors.primary)
                  : null,
              onTap: () => Navigator.pop(sheet, sort),
            ),
        ],
      ),
    ),
  );
  if (choice != null) controller.setSort(choice);
}
