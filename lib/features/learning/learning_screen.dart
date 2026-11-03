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
import '../feed/feed_models.dart';
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
    badge: item.via == OpenedVia.credits ? 'Credits' : null,
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
                top: TitleBar.height,
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: learning.refresh,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: LearningToolbar(searchController: _search, routes: widget.routes),
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
            title: "Couldn't load courses",
            body: learning.error!,
            action: 'Try again',
            onAction: learning.refresh,
          ),
        ),
      ];
    }
    final shelves = learning.openedShelves;
    if (sections.isEmpty && shelves.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Notice(
            title: learning.narrowed
                ? 'No courses match'
                : learning.mineOnly
                ? 'No courses yet'
                : 'No courses published yet',
            body: learning.narrowed
                ? 'Try other words, or clear the search.'
                : learning.mineOnly
                ? 'Courses and mock exams you open, and courses you take a place on, show up here.'
                : 'Courses show up here as ICR and its partner institutes publish them.',
            action: learning.narrowed
                ? 'Clear search'
                : learning.mineOnly
                ? 'Browse courses'
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
        const SizedBox(height: 6.5),
        ChipRow(
          children: [
            IcrChip(
              label: 'My courses',
              tone: learning.mineOnly ? ChipTone.primary : ChipTone.filled,
              icon: LucideIcons.graduationCap,
              iconSize: 14,
              padding: const EdgeInsets.only(left: 10, right: 12),
              gap: 6,
              onTap: learning.toggleMine,
            ),
            IcrChip(
              label: 'Mock exams',
              tone: ChipTone.outlined,
              icon: LucideIcons.clipboardCheck,
              iconSize: 14,
              padding: const EdgeInsets.only(left: 11, right: 12),
              onTap: () => pushLearningPage(context, routes.mockTests),
            ),
            IcrChip(
              label: 'Certificates',
              tone: ChipTone.outlined,
              icon: LucideIcons.award,
              iconSize: 14,
              padding: const EdgeInsets.only(left: 11, right: 12),
              onTap: () => pushLearningPage(context, routes.certificates),
            ),
            IcrChip(
              label: 'My attempts',
              tone: ChipTone.outlined,
              icon: LucideIcons.history,
              iconSize: 14,
              padding: const EdgeInsets.only(left: 11, right: 12),
              onTap: () => pushLearningPage(context, routes.myAttempts),
            ),
            IcrChip(
              label: 'Flash cards',
              tone: ChipTone.outlined,
              icon: LucideIcons.layers,
              iconSize: 14,
              padding: const EdgeInsets.only(left: 11, right: 12),
              onTap: () => pushLearningPage(context, routes.flashCards),
            ),
            IcrChip(
              label: 'Knowledge center',
              tone: ChipTone.outlined,
              icon: LucideIcons.sigma,
              iconSize: 14,
              padding: const EdgeInsets.only(left: 11, right: 12),
              onTap: () => pushLearningPage(context, routes.knowledgeCenter),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Hairline(color: AppColors.blockRule),
      ],
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
