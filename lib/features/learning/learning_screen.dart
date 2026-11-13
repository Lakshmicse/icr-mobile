import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/section_heading.dart';
import '../../core/widgets/title_bar.dart';
import '../learning_assess/api_assess_repository.dart';
import '../learning_assess/assess_models.dart';
import '../learning_assess/catalogue_controller.dart';
import '../learning_assess/demo_assess_repository.dart';
import '../learning_assess/group_screen.dart';
import '../learning_exam/open_paper.dart';
import '../learning_hub/learning_doors.dart';
import '../learning_hub/widgets/learn_card.dart';
import '../learning_study/study_models.dart';
import 'course_sheet.dart';
import 'learning_controller.dart';
import 'opened_learning.dart';
import 'learning_links.dart';
import 'widgets/course_card.dart';
import '../notifications/notifications_screen.dart';

/// The catalogue of courses, as a grid of cards that open the course sheet.
///
/// It is the Learning hub's "ICR Courses" door (the hub pushes it); it was the
/// Learning tab itself until the tab became the hub. It reads its
/// [LearningController] from `Provider`: the hub hands it the controller it
/// already loaded.
class LearningScreen extends StatefulWidget {
  const LearningScreen({
    super.key,
    required this.onBack,
    this.title = 'Learning',
    this.routes = const LearningRoutes(),
    this.onOpenDeck,
  });

  /// The arrow at the top left; the shell goes back to Home (the hub pops the route).
  final VoidCallback onBack;

  /// The title bar's words: "ICR Courses" under the hub.
  final String title;

  /// Where the chips under the search lead (the Learning Center's other doors).
  final LearningRoutes routes;

  /// A flash-card deck on the My courses shelf: the hub opens its study screen; left out, the Flash Cards door.
  final ValueChanged<StudyTopic>? onOpenDeck;

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  final _search = TextEditingController();

  /// The My Courses chip that is on: one of [myCourseGroups], or null for All (owner, 12 Nov 2026: "add the chips
  /// like Mock Exams, and other so that clicks will show those course enrolled").
  String? _group;

  @override
  void initState() {
    super.initState();
    final learning = context.read<LearningController>();
    if (!learning.started) learning.start();
    // The controller may arrive narrowed (the hub's "View All" carries its search in).
    _search.text = learning.search;
    // The list narrows as the person types; the keyboard's search key and the
    // clear button reach the same place.
    _search.addListener(() {
      if (mounted) context.read<LearningController>().setSearch(_search.text);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// A course or mock exam the member opened, as the hub's card draws it: the catalogue's photo and name, and
  /// only a place redeemed with ICR credits badged (the website's tile).
  Widget _openedCard(OpenedItem item) => LearnCard(
    key: ValueKey('opened-${item.key}'),
    title: item.title,
    cover: item.cover ?? FeedPicture.asset(_doorFor(item.kind).image),
    tag: item.via == OpenedVia.credits ? 'Credits' : null,
    onShare: () => shareLearningLink(item.title, item.link),
    onTap: () => _openOpened(item),
  );

  static LearningDoor _doorFor(OpenedKind kind) => switch (kind) {
    OpenedKind.mock => LearningDoor.mockTests,
    OpenedKind.course => LearningDoor.assessment,
    OpenedKind.deck => LearningDoor.flashCards,
  };

  void _openOpened(OpenedItem item) {
    final deck = item.deck;
    if (deck != null) {
      final open = widget.onOpenDeck;
      if (open != null) return open(deck);
      pushLearningPage(context, widget.routes.flashCards);
      return;
    }
    _openGroup(item.group!.kind, item.group!);
  }

  /// A programme's levels or a subject's sets, as the hub opens them: with a catalogue controller of its own
  /// above (the group screen reads one for the member's places and its refresh).
  void _openGroup(PaperKind kind, PaperGroup group) {
    final assess =
        context.read<LearningController>().assess ??
        (AppConfig.demo ? DemoAssessRepository() : ApiAssessRepository(api: context.read<ApiClient>()));
    final catalogue = CatalogueController(repository: assess, kind: kind);
    pushLearningPage<void>(
      context,
      (route, back) => ChangeNotifierProvider<CatalogueController>(
        create: (_) => catalogue,
        child: GroupScreen(seed: group, onBack: back, opener: openPaper),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final learning = context.watch<LearningController>();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                top: TitleBar.reserved(context),
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: learning.refresh,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: LearningToolbar(searchController: _search, routes: widget.routes),
                      ),
                      if (learning.mineOnly)
                        SliverToBoxAdapter(
                          child: MyCourseChips(on: _group, onSelect: (g) => setState(() => _group = g)),
                        ),
                      ..._body(learning),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: TitleBar(
                  title: widget.title,
                  onBack: widget.onBack,
                  unread: learning.unread,
                  onBell: () => openNotifications(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(LearningController learning) {
    final sections = learning.sections;
    if (learning.loading && learning.courses.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))),
        ),
      ];
    }
    if (learning.error != null && learning.courses.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Notice(
            title: 'Unable to Load Courses',
            body: learning.error!,
            action: 'Try Again',
            onAction: learning.refresh,
          ),
        ),
      ];
    }
    final allShelves = learning.openedShelves;
    final group = learning.mineOnly ? _group : null;
    // My Courses' chips: one group at a time, the rest hidden.
    final shelves = [
      for (final s in allShelves)
        if (group == null || s.title == group) s,
    ];
    if (group != null && learning.sections.every((s) => s.title != group) && shelves.isEmpty) {
      final words = myCourseGroupNotices[group]!;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Notice(
            title: learning.narrowed ? 'No Matches Found' : words.$1,
            body: learning.narrowed ? 'Try other words, or clear the search.' : words.$2,
            action: 'Show All',
            onAction: () => setState(() => _group = null),
          ),
        ),
      ];
    }
    if (sections.isEmpty && shelves.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Notice(
            title: learning.narrowed
                ? 'No Courses Match'
                : learning.mineOnly
                ? 'No Courses Yet'
                : 'No Courses Published Yet',
            body: learning.narrowed
                ? 'Try other words, or clear the search.'
                : learning.mineOnly
                ? 'Courses and mock exams you open, and courses you take a place on, will appear here.'
                : 'Courses will appear here as ICR and its partner institutes publish them.',
            action: learning.narrowed
                ? 'Clear Search'
                : learning.mineOnly
                ? 'Browse Courses'
                : null,
            onAction: learning.narrowed
                ? () {
                    _search.clear();
                    learning.clearSearch();
                  }
                : learning.mineOnly
                ? learning.toggleMine
                : null,
          ),
        ),
      ];
    }
    // Each section: its heading, then its courses two to a row, as the Events agenda is laid out.
    final children = <Widget>[];
    // My courses opens with the website's shelves of opened learning (Mock Exams, Assess Your Knowledge), the
    // hub's cards two to a row, before the places the member holds.
    for (final shelf in shelves) {
      children.add(const SizedBox(height: 12));
      children.add(SectionHeading(title: shelf.title));
      children.add(const SizedBox(height: 11.5));
      final items = shelf.items;
      for (var i = 0; i < items.length; i += 2) {
        if (i > 0) children.add(const SizedBox(height: LearnGridRow.rowGap));
        children.add(
          LearnGridRow(left: _openedCard(items[i]), right: i + 1 < items.length ? _openedCard(items[i + 1]) : null),
        );
      }
      children.add(const SizedBox(height: 12.5));
    }
    for (final section in sections) {
      if (group != null && section.title != group) continue;
      children.add(const SizedBox(height: 12));
      children.add(SectionHeading(title: section.title));
      children.add(const SizedBox(height: 11.5));
      final courses = section.courses;
      for (var i = 0; i < courses.length; i += 2) {
        if (i > 0) children.add(const SizedBox(height: CourseGridRow.rowGap));
        children.add(
          CourseGridRow(
            left: courses[i],
            right: i + 1 < courses.length ? courses[i + 1] : null,
            showPlace: learning.mineOnly,
            onOpen: (course) => showCourseSheet(context, course),
          ),
        );
      }
      children.add(const SizedBox(height: 12.5));
    }
    children.add(const SizedBox(height: 24));
    return [SliverList(delegate: SliverChildListDelegate(children))];
  }
}

/// Under the title bar: the search, the member's own doors, then the rule
/// the list hangs from.
class LearningToolbar extends StatelessWidget {
  const LearningToolbar({super.key, required this.searchController, this.routes = const LearningRoutes()});

  final TextEditingController searchController;
  final LearningRoutes routes;

  @override
  Widget build(BuildContext context) {
    final learning = context.watch<LearningController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: IcrSearchField(
            controller: searchController,
            hint: 'Search courses, certifications...',
            onSubmitted: learning.setSearch,
          ),
        ),
        // No row of chips under the search (owner, 7 Nov 2026: "remove this bar, let it be navigation through
        // top 3 categories"): the hub's tabs are the way around.
        const SizedBox(height: 12),
        const Hairline(color: AppColors.blockRule),
      ],
    );
  }
}

/// My Courses' groups, as its shelves and sections are headed: what each chip shows.
const myCourseGroups = ['Mock Exams', 'Knowledge Assessments', 'Flashcards', 'ICR Programmes', 'Partner Programmes'];

/// What a chip with nothing under it says.
const myCourseGroupNotices = {
  'Mock Exams': (
    'No Mock Exams Yet',
    'Mock exams you open with your plan, ICR credits or a purchase will appear here.',
  ),
  'Knowledge Assessments': (
    'No Knowledge Assessments Yet',
    'Assessments you open with your plan, ICR credits or a purchase will appear here.',
  ),
  'Flashcards': ('No Flashcards Yet', 'Flashcard decks included with your plan or your courses will appear here.'),
  'ICR Programmes': ('No ICR Programmes Yet', 'ICR programmes you take a place on will appear here.'),
  'Partner Programmes': (
    'No Partner Programmes Yet',
    "Partner institutes' programmes you take a place on will appear here.",
  ),
};

/// The chips under My Courses' search: All, then each group. Always the same chips, whatever the member holds, so
/// none comes and goes (owner, 9 Nov 2026); one with nothing under it says so.
class MyCourseChips extends StatelessWidget {
  const MyCourseChips({super.key, required this.on, required this.onSelect});

  /// The group that is on; null for All.
  final String? on;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, String? group) => IcrChip(
      key: ValueKey('my-courses-chip-${group ?? 'all'}'),
      label: label,
      tone: on == group ? ChipTone.primary : ChipTone.outlined,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      textStyle: AppText.workSans(13, FontWeight.w600, AppColors.onSurface, lineHeight: 18),
      onTap: () => onSelect(group),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: SizedBox(
        height: 34,
        // Six chips: all built at once (a lazy list would leave the last ones unbuilt until scrolled to).
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              chip('All', null),
              for (final g in myCourseGroups) ...[const SizedBox(width: 8), chip(g, g)],
            ],
          ),
        ),
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
          const Icon(LucideIcons.graduationCap, size: 36, color: AppColors.outline),
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
