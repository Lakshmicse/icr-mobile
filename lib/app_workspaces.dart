import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_notifications.dart' show appJobsNavigation;
import 'app_records.dart';
import 'app_screens.dart';
import 'app_search.dart' show openMentorProfile;
import 'core/api/api_client.dart';
import 'core/config.dart';
import 'features/account/companies/my_companies_screen.dart';
import 'features/become_mentor/become_mentor_screen.dart';
import 'features/career/career_hub_screen.dart';
import 'features/career/career_routes.dart' show careerRepositoryOf;
import 'features/career/invitations_screen.dart';
import 'features/career/my_applications_screen.dart';
import 'features/career/saved_jobs_screen.dart';
import 'features/events/api_events_repository.dart';
import 'features/events/demo_events_repository.dart';
import 'features/events/events_controller.dart';
import 'features/events/events_screen.dart';
import 'features/feed/feed_controller.dart';
import 'features/feed/feed_models.dart' show FeedAuthor;
import 'features/feed/session_viewer.dart';
import 'features/forum/forum_callbacks.dart';
import 'features/forum/forums_controller.dart';
import 'features/forum/forums_screen.dart';
import 'features/jobs/jobs_controller.dart';
import 'features/jobs/jobs_screen.dart';
import 'features/learning_hub/learning_doors.dart' show LearningRoutes;
import 'features/marketplace/marketplace_controller.dart';
import 'features/membership/membership_models.dart';
import 'features/membership/membership_screen.dart';
import 'features/learning_hub/learning_hub_screen.dart';
import 'features/learning_hub/my_courses_screen.dart';
import 'features/mentor_desk/mentor_desk_controller.dart' show DeskTab;
import 'features/mentor_desk/mentor_desk_screen.dart';
import 'features/mentorship/find_mentors_screen.dart';
import 'features/mentorship/mentorship_controller.dart';
import 'features/mentorship_my/group_sessions_screen.dart';
import 'features/mentorship_my/mentoring_links.dart';
import 'features/mentorship_my/my_mentoring_controller.dart' show MyTab;
import 'features/mentorship_my/my_mentoring_screen.dart';
import 'features/mentorship_my/programmes_screen.dart';
import 'features/messaging/inbox_screen.dart';
import 'features/notifications/notification_scope.dart';
import 'features/notifications/notifications_screen.dart' show openNotifications;
import 'features/profile/profile_drawer_data.dart';
import 'features/shell/app_shell.dart';
import 'features/site/refer_screen.dart';
import 'features/workspaces/workspace_screen.dart';
import 'features/workspaces/workspaces.dart';
import 'core/util/links.dart' show openSitePage;
import 'features/contact/contact_screen.dart' show contactRoute;
import 'features/jobs/employer/employer_jobs_screen.dart';
import 'features/marketplace/catalog_board_controller.dart' show CatalogKind;
import 'features/marketplace/categories_screen.dart' show CategoriesScreen, CatalogBoardScreen;
import 'features/marketplace/marketplace_links.dart' show SystemMarketplaceLinks;
import 'features/marketplace/marketplace_navigation.dart' show MarketplaceScope;
import 'features/marketplace/marketplace_screen.dart';
import 'features/site/advertise_screen.dart';
import 'features/support/support_screen.dart';

/// Opens a workspace option ([section]: Mentorship, My career…) on its page [index], from the profile menu. [shell]
/// is a context below the signed-in app's providers (the menu's own): the option's screen is a route pushed above
/// them, so the controllers its pages read — the tabs' (`JobsController`, `FeedController`, `ForumsController`,
/// `MentorshipController`…), the mentoring links, the bell's scope — are handed on to it, as the same objects the tabs
/// use.
Future<void> openWorkspaceSection(
  BuildContext shell,
  WorkspaceSection section, {
  int index = 0,
  required FeedAuthor viewer,
}) {
  final screens = inAppScreens(viewer: viewer);
  final scope = NotificationScope.of(shell);
  final carried = MultiProvider(
    providers: [
      Provider<MentorshipLinks>.value(value: shell.read<MentorshipLinks>()),
      ChangeNotifierProvider<FeedController>.value(value: shell.read<FeedController>()),
      InheritedProvider<ForumsController>.value(value: shell.read<ForumsController>()),
      ChangeNotifierProvider<ProfileDrawerController>.value(value: shell.read<ProfileDrawerController>()),
      ChangeNotifierProvider<MentorshipController>.value(value: shell.read<MentorshipController>()),
      ChangeNotifierProvider<JobsController>.value(value: shell.read<JobsController>()),
      ChangeNotifierProvider<MarketplaceController>.value(value: shell.read<MarketplaceController>()),
    ],
    child: WorkspaceScreen(
      section: section,
      initialIndex: index,
      pageFor: (ctx, item) => workspacePage(ctx, shell, item, viewer: viewer, screens: screens),
    ),
  );
  return AppShell.push<void>(shell, (_) => scope.wrap(carried));
}

/// The pages [workspacePage] builds itself, by path: with the app's screens map ([inAppScreens]), what a workspace's
/// menu may list. Kept beside the switch below; `workspaces_test.dart` builds each.
const workspaceBuiltPaths = {
  '/membership',
  '/career/plans',
  '/membership/history',
  '/refer',
  '/mentorship/my',
  '/mentorship/mentors',
  '/mentorship/groups',
  '/mentorship/programmes',
  '/mentorship/cpd',
  '/mentorship/mentor',
  '/mentorship/become-a-mentor',
  '/account/companies',
  '/learning/assessment',
  '/learning/mock-tests',
  '/learning/flash-cards',
  '/learning/formulas',
  '/learning/attempts',
  '/learning/certificates',
  '/career',
  '/career/applications',
  '/career/invitations',
  '/career/saved',
  '/profile',
  '/jobs',
  '/learning',
  '/community',
  '/events',
  '/messaging',
  '/manage/jobs',
  '/vendors',
  '/products',
  '/categories',
  '/advertise',
  '/support',
};

/// Whether a workspace tab can show [path] as the app's own screen: one [workspacePage] builds, or one in the app's
/// screens map. The menu lists only these (owner: nothing hands the member to the website).
bool workspaceOpens(String path, Map<String, WidgetBuilder> screens) {
  final uri = Uri.parse(path);
  return workspaceBuiltPaths.contains(uri.path) || screens.containsKey(path) || screens.containsKey(uri.path);
}

/// The app's own screen for a workspace page (`WorkspaceItem.path`, the website's page), built for a tab: [context]
/// is inside the workspace (its providers), [shell] below the app's. Null for a page the app has no screen for —
/// the tab offers the website's page then.
Widget? workspacePage(
  BuildContext context,
  BuildContext shell,
  WorkspaceItem item, {
  required FeedAuthor viewer,
  required Map<String, WidgetBuilder> screens,
}) {
  void back() => Navigator.of(context).maybePop();
  MentorshipLinks links() => MentorshipLinks.resolve(context, null);
  final uri = Uri.parse(item.path);
  final tab = uri.queryParameters['tab'];
  const learning = LearningRoutes();
  switch (uri.path) {
    // Membership
    case '/membership':
    case '/career/plans':
      return MembershipScreen(audience: MembershipAudience.seeker, onBack: back);
    case '/membership/history':
      return MembershipHistoryScreen(audience: MembershipAudience.seeker, onBack: back);
    case '/refer':
      return ReferScreen(onBack: back);

    // Mentorship
    case '/mentorship/my':
      return MyMentoringScreen(
        initialTab: switch (tab) {
          'calendar' => MyTab.calendar,
          'goals' => MyTab.goals,
          _ => MyTab.mentoring,
        },
        onBack: back,
        links: links(),
      );
    case '/mentorship/mentors':
      return FindMentorsScreen(onBack: back, onOpenMentor: openMentorProfile);
    case '/mentorship/groups':
      return GroupSessionsScreen(links: links());
    case '/mentorship/programmes':
      return ProgrammesScreen(links: links(), onBecomeMentor: (c) => openBecomeMentor(c));
    case '/mentorship/cpd':
      // The CPD record and volunteering are one screen, with its controller (`/get-involved`'s builder).
      return getInvolvedScreen(context);
    case '/mentorship/mentor':
      return MentorDeskScreen(
        initialTab: switch (tab) {
          'services' => DeskTab.offerings,
          'work' => DeskTab.work,
          'settings' => DeskTab.settings,
          _ => DeskTab.overview,
        },
        onBack: back,
        links: links(),
      );
    case '/mentorship/become-a-mentor':
      return BecomeMentorScreen(onBack: back, links: links());

    // Company
    case '/account/companies':
      return MyCompaniesScreen(onBack: back, onOpenCompany: (id) => openCompanyById(shell, id));
    case '/manage/team':
      // `?invite=TRAINER`: the invite form open with that learning role ticked (the Partner Institute row).
      return teamScreen(shell, inviteLearningRole: uri.queryParameters['invite'], onBack: back);

    // Learning
    case '/learning/assessment':
      return learning.assessment(context, back);
    case '/learning/mock-tests':
      return learning.mockTests(context, back);
    case '/learning/flash-cards':
      return learning.flashCards(context, back);
    case '/learning/formulas':
      return learning.knowledgeCenter(context, back);
    case '/learning/attempts':
      return learning.myAttempts(context, back);
    case '/learning/certificates':
      return learning.certificates(context, back);

    // Jobs
    case '/career':
      return CareerHubScreen(
        repository: careerRepositoryOf(shell),
        links: shell.read<JobsController>().links,
        navigation: appJobsNavigation(shell),
      );
    case '/career/applications':
      return MyApplicationsScreen(
        repository: careerRepositoryOf(shell),
        links: shell.read<JobsController>().links,
        navigation: appJobsNavigation(shell),
      );
    case '/career/invitations':
      return InvitationsScreen(
        repository: careerRepositoryOf(shell),
        links: shell.read<JobsController>().links,
        navigation: appJobsNavigation(shell),
      );
    case '/career/saved':
      return SavedJobsScreen(
        repository: careerRepositoryOf(shell),
        links: shell.read<JobsController>().links,
        navigation: appJobsNavigation(shell),
      );
    case '/profile':
      return myProfileScreen(context);
    case '/jobs':
      return JobsScreen(onBack: back, navigation: appJobsNavigation(shell));
    case '/learning':
      // `?mine=1` (the Learning row's "My courses"): the My courses page alone — what the member holds, not the
      // hub (owner, 6 Nov 2026).
      if (uri.queryParameters['mine'] == '1') return MyCoursesScreen(onBack: back);
      return LearningHubScreen(viewer: viewer, onBack: back);

    // Community
    case '/community':
      return SessionViewer(
        builder: (ctx, v) => ForumsScreen(
          viewer: v,
          controller: ctx.read<ForumsController>(),
          onBack: back,
          callbacks: ForumCallbacks(
            onBell: () => openNotifications(ctx),
            onOpenMember: (id) => openMemberProfile(ctx, id),
            onOpenCompany: (id) => openCompanyById(shell, id),
          ),
        ),
      );
    case '/events':
      return ChangeNotifierProvider<EventsController>(
        create: (c) =>
            EventsController(AppConfig.demo ? DemoEventsRepository() : ApiEventsRepository(api: c.read<ApiClient>())),
        child: EventsScreen(viewer: viewer, onBack: back, onAccount: back),
      );
    case '/messaging':
      return const InboxScreen();

    // Hire
    case '/manage/jobs':
      return EmployerJobsScreen(
        repository: shell.read<JobsController>().hiring,
        links: shell.read<JobsController>().links,
        navigation: appJobsNavigation(shell),
      );

    // Company: buying, selling and finding companies
    case '/vendors':
      return MarketplaceScope(
        navigation: appMarketplaceNavigation(shell),
        links: const SystemMarketplaceLinks(),
        child: MarketplaceScreen(
          onBack: back,
          onBell: () => openNotifications(context),
          navigation: appMarketplaceNavigation(shell),
        ),
      );
    case '/products':
      return MarketplaceScope(
        navigation: appMarketplaceNavigation(shell),
        links: const SystemMarketplaceLinks(),
        child: const CatalogBoardScreen(kind: CatalogKind.products),
      );
    case '/categories':
      return MarketplaceScope(
        navigation: appMarketplaceNavigation(shell),
        links: const SystemMarketplaceLinks(),
        child: const CategoriesScreen(),
      );
    case '/advertise':
      return AdvertiseScreen(
        onBack: back,
        onTalk: (subject) => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (r) => contactRoute(r, subject: subject, onBell: () => openNotifications(r)),
          ),
        ),
      );

    // Help
    case '/support':
      return SupportScreen(onBack: back, onOpenContext: (href) => openSitePage(context, href));
  }
  // The rest the app already has a screen for, as the profile menu and the doors open it (`/rfq`, `/manage/bids`,
  // `/chapters`, `/councils`).
  final screen = screens[item.path] ?? screens[uri.path];
  return screen?.call(context);
}
