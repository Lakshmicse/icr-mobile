import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../feed/feed_models.dart' show FeedAuthor, FeedPicture;
import '../feed/widgets/home_header.dart';
import '../learning/course_sheet.dart';
import '../learning/learning_controller.dart';
import '../learning/learning_screen.dart';
import '../learning/opened_learning.dart';
import '../learning_assess/api_assess_repository.dart';
import '../learning_assess/assess_models.dart';
import '../learning_assess/assess_repository.dart';
import '../learning_assess/catalogue_controller.dart';
import '../learning_assess/demo_assess_repository.dart';
import '../learning_assess/group_screen.dart';
import '../learning_exam/open_paper.dart';
import '../learning_study/api_study_repository.dart';
import '../learning_study/deck_study_screen.dart';
import '../learning_study/demo_study_repository.dart';
import '../learning_study/study_models.dart';
import '../learning_study/study_repository.dart';
import '../notifications/notification_scope.dart';
import '../notifications/notifications_bell.dart';
import '../notifications/notifications_screen.dart';
import 'catalogue_screen.dart';
import 'partner_screen.dart';
import 'widgets/institute_card.dart';
import 'hub_controller.dart';
import 'hub_models.dart';
import 'hub_factory.dart';
import 'learning_doors.dart';
import 'partner_courses_screen.dart';
import 'widgets/catalogue_rail.dart';
import 'widgets/flash_tile.dart';
import 'widgets/hub_parts.dart';
import 'widgets/hub_section.dart';
import 'widgets/learn_card.dart';
import 'widgets/masterclass_banner.dart';

/// The Learning tab, built to the Learning Centre design
/// (`docs/designs/hires/learning-centre.png`, a 390-wide frame at 4x). Top to
/// bottom: the Home header (photo, search, bell), **Catalogue** (the four tiles),
/// **Assess Your Knowledge** and **Mock Exams** (two-column grids of six cards
/// from the paper catalogue), **Flash Cards** (a rail of dark tiles, one per
/// deck), **ICR Certifications** and **Partner Courses** (the grids again, from
/// the course catalogue), and the **Masterclasses** banner. Every section has a
/// "View More" that opens its full screen; the header's search narrows them all.
///
/// [controller] and [routes] are for tests; the app mounts
/// `LearningHubScreen(onBack: …, viewer: …, onAccount: …, onMasterclasses: …)`
/// and the screen builds its own controller (a pushed route cannot reach the
/// tab's providers). [onBack] is kept for the shell's Back, which goes Home.
class LearningHubScreen extends StatefulWidget {
  const LearningHubScreen({
    super.key,
    required this.onBack,
    this.viewer,
    this.onAccount,
    this.onMasterclasses,
    this.controller,
    this.routes = const LearningRoutes(),
  });

  /// What the shell does on Back; the header itself has no arrow.
  final VoidCallback onBack;

  /// The reader, for the header's photo; initials "?" without one.
  final FeedAuthor? viewer;

  /// The header's photo: the profile menu.
  final VoidCallback? onAccount;

  /// The banner's "Know more": the app's Events screen; the website's when left out.
  final VoidCallback? onMasterclasses;
  final LearningHubController? controller;
  final LearningRoutes routes;

  @override
  State<LearningHubScreen> createState() => _LearningHubScreenState();
}

class _LearningHubScreenState extends State<LearningHubScreen> {
  final _search = TextEditingController();
  late final LearningHubController _hub;
  late final bool _ownsHub;

  @override
  void initState() {
    super.initState();
    _ownsHub = widget.controller == null;
    _hub = widget.controller ?? createHubController(context);
    if (!_hub.started) _hub.start();
  }

  @override
  void dispose() {
    _search.dispose();
    if (_ownsHub) _hub.dispose();
    super.dispose();
  }

  // --- opening things -------------------------------------------------------------

  void _openDoor(LearningDoor door) {
    switch (door) {
      case LearningDoor.icrCourses:
        _openCourses();
      case LearningDoor.partnerCourses:
        _openPartners();
      default:
        _pushAndRecount(widget.routes.forDoor(door)!);
    }
  }

  /// A page where the member may open a level, a set or a whole course (credits, a plan place, a purchase): the
  /// My courses row reads what they hold again when they come back.
  Future<void> _pushAndRecount(LearningPageBuilder page) async {
    await pushLearningPage<void>(context, page);
    if (mounted) _hub.reloadAccess();
  }

  /// "My courses · View More": the My courses page, which files what the member holds under its own headings — Mock
  /// Exams, Assess Your Knowledge, Flash Cards, then ICR Courses and Partner Courses (the website's My courses).
  Future<void> _openMyCourses() async {
    final learning = _hub.learning
      ..setSearch('')
      ..setMineOnly(true);
    await pushLearningPage<void>(
      context,
      (route, back) => ChangeNotifierProvider<LearningController>.value(
        value: learning,
        child: LearningScreen(onBack: back, title: 'My courses', routes: widget.routes, onOpenDeck: _openDeck),
      ),
    );
    if (mounted) _hub.reloadAccess();
  }

  /// A card of the My courses row: an exam or programme opens its levels or sets, a deck its study screen.
  void _openOpened(OpenedItem item) {
    final deck = item.deck;
    if (deck != null) {
      _openDeck(deck);
      return;
    }
    _openGroup(item.group!.kind, item.group!);
  }

  /// The ICR Courses grid, over the hub. It shares the hub's course controller,
  /// so what is loaded is not read again; [search] carries the hub's search in.
  void _openCourses({String search = ''}) {
    final learning = _hub.learning
      ..setSearch(search)
      ..setMineOnly(false);
    pushLearningPage<void>(
      context,
      (route, back) => ChangeNotifierProvider<LearningController>.value(
        value: learning,
        child: LearningScreen(onBack: back, title: 'ICR Courses', routes: widget.routes, onOpenDeck: _openDeck),
      ),
    );
  }

  void _openPartners() {
    pushLearningPage<void>(context, (route, back) => PartnerCoursesScreen(onBack: back, hub: _hub));
  }

  /// An institute's page: its courses, as the directory opens it.
  void _openInstitute(Institute institute) {
    pushLearningPage<void>(context, (route, back) => PartnerScreen(institute: institute, onBack: back, hub: _hub));
  }

  /// "Catalogue · View More": the six doors as tiles — the categories — not the ICR Courses list, which is one
  /// door of the six (owner's call, 2 Nov 2026).
  void _openCatalogue() {
    pushLearningPage<void>(
      context,
      (route, back) => CatalogueScreen(
        onBack: back,
        onOpen: _openDoor,
        unread: _hub.learning.unread,
        onBell: () => openNotifications(route),
      ),
    );
  }

  AssessRepository get _assess =>
      _hub.assess ?? (AppConfig.demo ? DemoAssessRepository() : ApiAssessRepository(api: context.read<ApiClient>()));

  StudyRepository get _study =>
      _hub.study ?? (AppConfig.demo ? DemoStudyRepository() : ApiStudyRepository(api: context.read<ApiClient>()));

  /// A programme's levels or a subject's sets, the page the catalogue screens
  /// open, with a catalogue controller of its own above it (the group screen
  /// reads one for the member's places and its refresh).
  void _openGroup(PaperKind kind, PaperGroup group) {
    final catalogue = CatalogueController(repository: _assess, kind: kind);
    _pushAndRecount(
      (route, back) => ChangeNotifierProvider<CatalogueController>(
        create: (_) => catalogue,
        child: GroupScreen(seed: group, onBack: back, opener: openPaper),
      ),
    );
  }

  /// A deck opens the study screen, as the Flash Cards screen opens it; a deck
  /// read takes one of the plan's places, so the decks are read again after.
  Future<void> _openDeck(StudyTopic deck) async {
    final scope = NotificationScope.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => scope.wrap(DeckStudyScreen.deck(repository: _study, deck: deck)),
      ),
    );
    if (mounted) _hub.reloadDecks();
  }

  void _knowMore() {
    final open = widget.onMasterclasses;
    if (open != null) return open();
    openSitePage(context, '/events');
  }

  // --- build --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final viewer = widget.viewer;
    return ChangeNotifierProvider<LearningController>.value(
      value: _hub.learning,
      child: ListenableBuilder(
        listenable: _hub,
        builder: (context, _) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Positioned.fill(
                    top: HomeHeader.height,
                    child: RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _hub.refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        children: _content(context),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: HomeHeader(
                      photo: viewer?.photo,
                      initials: viewer?.initials ?? '?',
                      unread: math.max(bellUnread(context), _hub.unread),
                      searchController: _search,
                      onSearch: _hub.setSearch,
                      onAvatarTap: widget.onAccount ?? () {},
                      onBellTap: () => openNotifications(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// [context] is under the hub's `Provider<LearningController>`: the course sheet reads it.
  List<Widget> _content(BuildContext context) {
    if (_hub.nothingMatches) {
      return [
        HubNotice(
          title: 'No matches',
          body: 'Nothing in the Learning Centre matches that. Try other words, or clear the search.',
          action: 'Clear search',
          onAction: () {
            _search.clear();
            _hub.clearSearch();
          },
          icon: Icons.search_off_rounded,
        ),
      ];
    }
    final assessments = _hub.assessmentsShown;
    final mocks = _hub.mocksShown;
    final decks = _hub.decksShown;
    final certifications = _hub.icrCourses;
    // The institutes, as the website's "Partner institutes" rail lists them (ICR's own institute among them).
    final institutes = _hub.institutesShown.take(LearningHubController.gridLimit).toList();
    // Each section is its heading row (36 dp) and what it holds; `rule` says whether a hairline closes it when
    // another section follows (the export draws none between Mock Exams and Flash Cards).
    final sections = <({List<Widget> body, bool rule})>[
      (
        body: _grid(
          key: 'assess',
          title: 'Assess Your Knowledge',
          onMore: () => _pushAndRecount(widget.routes.assessment),
          loading: _hub.assessLoading,
          error: _hub.assessError,
          onRetry: _hub.reloadAssess,
          cards: [
            for (final (i, g) in assessments.indexed)
              LearnCard(
                key: ValueKey('assess-${g.key}'),
                title: g.title,
                cover: coverFor(g.cover, i),
                onTap: () => _openGroup(PaperKind.assessment, g),
              ),
          ],
          absent: _hub.assess == null,
        ),
        rule: true,
      ),
      (
        body: _grid(
          key: 'mock',
          title: 'Mock Exams',
          onMore: () => _pushAndRecount(widget.routes.mockTests),
          loading: _hub.mockLoading,
          error: _hub.mockError,
          onRetry: _hub.reloadMocks,
          cards: [
            for (final (i, g) in mocks.indexed)
              LearnCard(
                key: ValueKey('mock-${g.key}'),
                title: g.title,
                cover: coverFor(g.cover, i),
                onTap: () => _openGroup(PaperKind.mock, g),
              ),
          ],
          absent: _hub.assess == null,
        ),
        rule: false,
      ),
      (body: _flashRail(decks), rule: true),
      (
        body: _grid(
          key: 'cert',
          title: 'ICR Certifications',
          onMore: () => _openCourses(search: _search.text.trim()),
          loading: _hub.coursesLoading,
          error: _hub.coursesError,
          onRetry: _hub.refresh,
          cards: [
            for (final (i, c) in certifications.indexed)
              LearnCard(
                key: ValueKey('cert-${c.id}'),
                title: c.title,
                cover: coverFor(c.cover, i),
                badge: 'ICR',
                onTap: () => showCourseSheet(context, c),
              ),
          ],
        ),
        rule: true,
      ),
      (
        body: _grid(
          key: 'partner',
          title: 'Partner Courses',
          onMore: _openPartners,
          loading: _hub.institutesLoading,
          error: _hub.institutesError,
          onRetry: _hub.refresh,
          // Each institute with its logo and how many courses it runs; a card opens the institute's own course
          // list, as the website's "Explore courses" does (owner's call, 2 Nov 2026: the section listed the
          // institutes' courses mixed together).
          cards: [for (final i in institutes) InstituteCard(institute: i, onTap: () => _openInstitute(i))],
        ),
        rule: false,
      ),
    ].where((s) => s.body.isNotEmpty).toList();

    return [
      // The design's rhythm (docs/designs/learning-hub-v2.png, below its 57 dp header): the Catalogue row at the
      // header's edge, the tiles 1 dp under it, a hairline 5 dp under their shadow, then each section's 36 dp
      // heading row 6 dp under that.
      if (!_hub.narrowed) ...[
        HubSectionHeading(title: 'Catalogue', onAction: _openCatalogue),
        const SizedBox(height: 1),
        CatalogueRail(onOpen: _openDoor),
        const SizedBox(height: 5.1),
        const HubRule(),
        const SizedBox(height: 6.2),
      ],
      ..._myCoursesRow(),
      for (final (i, section) in sections.indexed) ...[
        ...section.body,
        // 10.2 dp under the last card (or tile), the hairline, 5.9 dp, the next heading — or, with no hairline,
        // the same 16 dp of white; the last section leaves 10 dp for the banner.
        if (i == sections.length - 1)
          const SizedBox(height: 10)
        else if (section.rule) ...[
          const SizedBox(height: 10.2),
          const HubRule(),
          const SizedBox(height: 5.9),
        ] else
          const SizedBox(height: 16),
      ],
      if (!_hub.narrowed) MasterclassBanner(onKnowMore: _knowMore),
    ];
  }

  /// A heading row and the cards, two a row, under it — or the section's loading boxes, its failure, or nothing
  /// when it has nothing (an empty list).
  List<Widget> _grid({
    required String key,
    required String title,
    required VoidCallback onMore,
    required bool loading,
    required String? error,
    required Future<void> Function() onRetry,
    required List<Widget> cards,
    bool absent = false,
  }) {
    if (absent) return const [];
    if (!loading && error == null && cards.isEmpty) return const [];
    final rows = <Widget>[];
    if (loading) {
      rows.add(
        LearnGridRow(key: ValueKey('$key-skeleton'), left: const LearnCardSkeleton(), right: const LearnCardSkeleton()),
      );
    } else if (error != null) {
      rows.add(
        HubNotice(
          title: "Couldn't load this section",
          body: error,
          action: 'Try again',
          onAction: onRetry,
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 8),
        ),
      );
    } else {
      for (var i = 0; i < cards.length; i += 2) {
        if (i > 0) rows.add(const SizedBox(height: LearnGridRow.rowGap));
        rows.add(LearnGridRow(left: cards[i], right: i + 1 < cards.length ? cards[i + 1] : null));
      }
    }
    return [HubSectionHeading(key: ValueKey('$key-heading'), title: title, onAction: onMore), ...rows];
  }

  /// "My courses" (owner, 3 Nov 2026): one horizontal row under the Catalogue of everything the member holds —
  /// the exams, programmes and decks they opened and the courses they hold a place on, the hub's own cards — with
  /// "View More" for the My courses page. Nothing at all while they hold nothing.
  List<Widget> _myCoursesRow() {
    final entries = _hub.myLearning;
    if (entries.isEmpty) return const [];
    return [
      HubSectionHeading(key: const ValueKey('my-courses-heading'), title: 'My courses', onAction: _openMyCourses),
      const SizedBox(height: 1),
      SingleChildScrollView(
        key: const ValueKey('rail-my-courses'),
        scrollDirection: Axis.horizontal,
        // Room under the cards for their shadow.
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, entry) in entries.indexed) ...[
                if (i > 0) const SizedBox(width: _myCardGap),
                SizedBox(width: _myCardWidth, child: _myCard(entry, i)),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 6.2),
      const HubRule(),
      const SizedBox(height: 5.9),
    ];
  }

  /// The row's cards: a little narrower than the grid's, so the next one shows at the edge and says it scrolls.
  static const _myCardWidth = 160.0;
  static const _myCardGap = 12.0;

  Widget _myCard(MyLearningEntry entry, int index) {
    final item = entry.opened;
    if (item != null) {
      return LearnCard(
        key: ValueKey('my-${entry.key}'),
        title: item.title,
        cover: item.cover ?? FeedPicture.asset(_doorFor(item.kind).image),
        // As the My courses page badges it: only a place redeemed with ICR credits.
        badge: item.via == OpenedVia.credits ? 'Credits' : null,
        onTap: () => _openOpened(item),
      );
    }
    final course = entry.course!;
    return LearnCard(
      key: ValueKey('my-${entry.key}'),
      title: course.title,
      cover: coverFor(course.cover, index),
      badge: LearningHubController.isIcr(course) ? 'ICR' : null,
      onTap: () => showCourseSheet(context, course),
    );
  }

  static LearningDoor _doorFor(OpenedKind kind) => switch (kind) {
    OpenedKind.mock => LearningDoor.mockTests,
    OpenedKind.course => LearningDoor.assessment,
    OpenedKind.deck => LearningDoor.flashCards,
  };

  List<Widget> _flashRail(List<StudyTopic> decks) {
    if (_hub.study == null) return const [];
    final loading = _hub.decksLoading;
    final error = _hub.decksError;
    if (!loading && error == null && decks.isEmpty) return const [];
    return [
      HubSectionHeading(
        key: const ValueKey('flash-heading'),
        title: 'Flash Cards',
        onAction: () => pushLearningPage(context, widget.routes.flashCards),
      ),
      if (loading)
        SizedBox(
          key: const ValueKey('flash-skeleton'),
          height: FlashTile.height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(left: 16),
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(width: FlashTile.gap),
            itemBuilder: (_, _) => const HubSkeleton(width: FlashTile.width, height: FlashTile.height, radius: 8),
          ),
        )
      else if (error != null)
        HubNotice(
          title: "Couldn't load the decks",
          body: error,
          action: 'Try again',
          onAction: _hub.reloadDecks,
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 8),
        )
      else
        SizedBox(
          height: FlashTile.height,
          child: ListView.separated(
            key: const ValueKey('rail-decks'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 12),
            itemCount: decks.length,
            separatorBuilder: (_, _) => const SizedBox(width: FlashTile.gap),
            itemBuilder: (_, i) => FlashTile(
              key: ValueKey('deck-${decks[i].slug}'),
              title: decks[i].title,
              count: decks[i].cardCount,
              cover: coverFor(decks[i].cover, i),
              onTap: () => _openDeck(decks[i]),
            ),
          ),
        ),
    ];
  }
}
