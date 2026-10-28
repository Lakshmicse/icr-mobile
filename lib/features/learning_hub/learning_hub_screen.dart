import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../feed/feed_models.dart' show FeedAuthor;
import '../feed/widgets/home_header.dart';
import '../learning/course_sheet.dart';
import '../learning/learning_controller.dart';
import '../learning/learning_screen.dart';
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
import 'hub_controller.dart';
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
        pushLearningPage(context, widget.routes.forDoor(door)!);
    }
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
        child: LearningScreen(onBack: back, title: 'ICR Courses', routes: widget.routes),
      ),
    );
  }

  void _openPartners() {
    pushLearningPage<void>(context, (route, back) => PartnerCoursesScreen(onBack: back, hub: _hub));
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
    pushLearningPage<void>(
      context,
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
    final partners = _hub.partnerCourses;
    return [
      // The design's rhythm from the header: 15 dp, the heading line, 10 dp, the tiles.
      if (!_hub.narrowed) ...[
        const SizedBox(height: 15 - HubSectionHeading.lineInset),
        HubSectionHeading(title: 'Catalogue', onAction: _openCourses),
        const SizedBox(height: 10 - HubSectionHeading.lineInset),
        CatalogueRail(onOpen: _openDoor),
        const SizedBox(height: 7),
        const HubRule(),
      ],
      ..._grid(
        key: 'assess',
        title: 'Assess Your Knowledge',
        onMore: () => pushLearningPage(context, widget.routes.assessment),
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
      ..._grid(
        key: 'mock',
        title: 'Mock Exams',
        onMore: () => pushLearningPage(context, widget.routes.mockTests),
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
      ..._flashRail(decks),
      ..._grid(
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
      ..._grid(
        key: 'partner',
        title: 'Partner Courses',
        onMore: _openPartners,
        loading: _hub.coursesLoading,
        error: null,
        onRetry: _hub.refresh,
        cards: [
          for (final (i, c) in partners.indexed)
            LearnCard(
              key: ValueKey('partner-${c.id}'),
              title: c.title,
              cover: coverFor(c.cover, i),
              // The design draws ICR's tab there too; an institute's is only its own.
              badge: c.provider?.logo == null ? 'ICR' : null,
              onTap: () => showCourseSheet(context, c),
            ),
        ],
        rule: false,
      ),
      if (!_hub.narrowed) ...[const SizedBox(height: 8), MasterclassBanner(onKnowMore: _knowMore)],
      const SizedBox(height: 24),
    ];
  }

  /// A heading, two cards a row, and the rule under the last row — or the
  /// section's loading boxes, its failure, or nothing when it has nothing.
  List<Widget> _grid({
    required String key,
    required String title,
    required VoidCallback onMore,
    required bool loading,
    required String? error,
    required Future<void> Function() onRetry,
    required List<Widget> cards,
    bool absent = false,
    bool rule = true,
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
    return [
      const SizedBox(height: 13 - HubSectionHeading.lineInset),
      HubSectionHeading(key: ValueKey('$key-heading'), title: title, onAction: onMore),
      const SizedBox(height: 10 - HubSectionHeading.lineInset),
      ...rows,
      const SizedBox(height: 2.25),
      if (rule) const HubRule(),
    ];
  }

  List<Widget> _flashRail(List<StudyTopic> decks) {
    if (_hub.study == null) return const [];
    final loading = _hub.decksLoading;
    final error = _hub.decksError;
    if (!loading && error == null && decks.isEmpty) return const [];
    return [
      const SizedBox(height: 13 - HubSectionHeading.lineInset),
      HubSectionHeading(
        key: const ValueKey('flash-heading'),
        title: 'Flash Cards',
        onAction: () => pushLearningPage(context, widget.routes.flashCards),
      ),
      const SizedBox(height: 8.75 - HubSectionHeading.lineInset),
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
      const SizedBox(height: 10),
      const HubRule(),
    ];
  }
}
