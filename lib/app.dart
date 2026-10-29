import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_screens.dart';
import 'core/api/api_client.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/session_user.dart';
import 'core/auth/token_store.dart';
import 'core/config.dart';
import 'core/theme/app_theme.dart';
import 'app_notifications.dart';
import 'app_search.dart' show appSearchEnvironment;
import 'core/util/app_actions.dart';
import 'core/util/links.dart' show SiteRoutes, openSitePage;
import 'features/auth/auth_palette.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/feed/api_feed_repository.dart';
import 'features/feed/demo_feed_repository.dart';
import 'features/feed/feed_controller.dart';
import 'features/feed/feed_models.dart';
import 'features/feed/home_screen.dart';
import 'features/forum/forum_callbacks.dart';
import 'features/forum/forum_flows.dart' show startDiscussion;
import 'features/forum/forums_screen.dart';
import 'features/jobs/api_jobs_repository.dart';
import 'features/jobs/jobs_navigation.dart';
import 'features/jobs/demo_jobs_repository.dart';
import 'features/jobs/jobs_controller.dart';
import 'features/jobs/jobs_screen.dart';
import 'features/learning_hub/learning_hub_screen.dart';
import 'features/marketplace/api_marketplace_repository.dart';
import 'features/marketplace/demo_marketplace_repository.dart';
import 'features/marketplace/marketplace_controller.dart';
import 'features/marketplace/marketplace_screen.dart';
import 'features/account/companies/create_company_screen.dart';
import 'features/become_mentor/become_mentor_screen.dart';
import 'features/career/company_insights_screen.dart' show openCompanyInsightsById;
import 'features/shell/icr_bottom_nav.dart' show AppTab;
import 'features/mentorship_my/mentoring_links.dart' show MentorshipLinks;
import 'features/mentorship_my/programmes_screen.dart';
import 'features/messaging/messaging_launcher.dart';
import 'features/rfq/rfq_navigation.dart';
import 'features/mentor_profile/mentor_profile_screen.dart';
import 'features/mentorship/api_mentorship_repository.dart';
import 'features/mentorship/demo_mentorship_repository.dart';
import 'features/mentorship/mentorship_controller.dart';
import 'features/mentorship/mentorship_screen.dart';
import 'features/notifications/notification_router.dart';
import 'features/notifications/notifications_bell.dart';
import 'features/notifications/notifications_screen.dart' show openNotifications;
import 'features/profile/profile_drawer.dart';
import 'features/profile/profile_drawer_data.dart';
import 'features/search/search_screen.dart' show SearchEnvironment, openGlobalSearch;
import 'features/shell/app_shell.dart';
import 'features/web/open_in_app_web.dart';

class IcrApp extends StatelessWidget {
  const IcrApp({super.key, this.tokens});

  final TokenStore? tokens;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TokenStore>(create: (_) => tokens ?? TokenStore()),
        Provider<ApiClient>(create: (c) => ApiClient(tokens: c.read<TokenStore>())),
        ChangeNotifierProvider<AuthController>(
          create: (c) => AuthController(api: c.read<ApiClient>(), tokens: c.read<TokenStore>())..restore(),
        ),
      ],
      child: MaterialApp(
        title: 'ICR',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _SessionGate(),
      ),
    );
  }
}

/// Sign-in until there is a session, then Home.
class _SessionGate extends StatelessWidget {
  const _SessionGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.status != SessionStatus.signedIn) {
      // Signed out, a link to the website has only the legal pages to open in the app (sign-up's consent line);
      // the rest stays with the phone, and a resolver left over from a session that ended is not kept.
      SiteRoutes.resolver = signedOutSiteRoute;
      SiteRoutes.webView = null;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: switch (auth.status) {
        SessionStatus.unknown => const _Splash(),
        SessionStatus.signedOut => const SignInScreen(key: ValueKey('sign-in')),
        // Keyed on the company too: switching company (the profile menu, My companies) builds the whole app again,
        // so no tab keeps the previous company's feed, jobs or requirements.
        SessionStatus.signedIn => _Home(
          key: ValueKey('home-${auth.user?.id}-${auth.user?.companyId}'),
          user: auth.user,
        ),
      },
    );
  }
}

class _Home extends StatelessWidget {
  const _Home({super.key, required this.user});

  final SessionUser? user;

  FeedAuthor get _viewer {
    if (AppConfig.demoFeed) return DemoFeedRepository.me;
    final url = AppConfig.absoluteUrl(user?.avatarUrl);
    return FeedAuthor(
      id: user?.id ?? 'me',
      name: user?.fullName ?? 'You',
      photo: url == null ? null : FeedPicture.network(url),
    );
  }

  /// A mentor's profile, over whatever screen asked for it. It draws its own
  /// action bar, so it has no tab bar.
  /// The Mentorship tab's website hand-overs that the app now has screens for.
  Future<void> _openMentorshipPath(BuildContext context, String path) {
    switch (path) {
      case '/notifications':
        return openNotifications(context);
      case '/become-a-mentor':
        return openBecomeMentor(context);
      case '/mentorship/programmes':
        return openProgrammes(context, onBecomeMentor: (c) => openBecomeMentor(c));
      default:
        return openSitePage(context, path);
    }
  }

  /// What needs the providers: the notification openers, and the website links that open a record by its id
  /// (a job, a discussion, a company…) the same way, through [shell].
  Map<String, NotificationOpener> _wireShell(BuildContext shell) {
    SiteRoutes.resolver = (uri) => inAppSiteRoute(uri, viewer: _viewer, shell: shell);
    return appNotificationOpeners(shell: shell, viewer: _viewer);
  }

  /// "+" in the header: the composer, then the new discussion's page; the feed reads again so its card is on top.
  Future<void> _composePost(BuildContext context) async {
    final feed = context.read<FeedController>();
    final saved = await startDiscussion(
      context,
      repository: feed.repository.forum,
      viewer: _viewer,
      callbacks: ForumCallbacks(
        onBell: () => openNotifications(context),
        onOpenMember: (id) => openMemberProfile(context, id),
      ),
      unread: feed.unread,
    );
    if (saved != null) feed.refresh();
  }

  void _openMentor(BuildContext context, String mentorId) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (route) => mentorProfileRoute(route, mentorId)));
  }

  @override
  Widget build(BuildContext context) {
    final screens = inAppScreens(viewer: _viewer);
    // Every hand-off to the website asks this first, so "See plans" or a bell
    // deep in a feature opens the app's own screen for that page.
    SiteRoutes.resolver = (uri) => inAppSiteRoute(uri, viewer: _viewer);
    // The shared header's "+" and Messages (Home, Learning and Mentorship all show it).
    AppActions.composePost = (ctx) => _composePost(ctx);
    AppActions.openMessages = (ctx) => MessagingLauncher.openInbox(ctx);
    // A page the app has no screen for opens in its web view, signed in, rather than the browser.
    SiteRoutes.webView = (ctx, uri) => openInAppWeb(ctx, uri);
    // The header's search field opens the global search: people, jobs, courses, mentors, suppliers, events,
    // discussions, documents and the app's own features.
    AppActions.openSearch = openGlobalSearch;
    SearchEnvironment.current = appSearchEnvironment(viewer: _viewer);

    // One controller per tab, above the shell, so a sheet opened from a tab can
    // read its tab's controller and a tab keeps its state while another is open.
    return MultiProvider(
      providers: [
        Provider<MentorshipLinks>.value(value: appMentorshipLinks),
        ChangeNotifierProvider<FeedController>(
          create: (c) => FeedController(
            AppConfig.demoFeed ? DemoFeedRepository() : ApiFeedRepository(api: c.read<ApiClient>(), viewerId: user?.id),
          )..start(),
        ),
        ChangeNotifierProvider<ProfileDrawerController>(
          create: (c) => AppConfig.demoFeed
              ? ProfileDrawerController.demo()
              : ProfileDrawerController.live(
                  api: c.read<ApiClient>(),
                  userId: user?.id ?? '',
                  seed: ProfileDrawerData(
                    name: user?.fullName ?? 'You',
                    photoUrl: AppConfig.absoluteUrl(user?.avatarUrl),
                    verified: user?.emailVerified ?? false,
                  ),
                ),
        ),
        ChangeNotifierProvider<MentorshipController>(
          create: (c) => MentorshipController(
            AppConfig.demo ? DemoMentorshipRepository() : ApiMentorshipRepository(api: c.read<ApiClient>()),
          ),
        ),
        ChangeNotifierProvider<JobsController>(
          create: (c) =>
              JobsController(AppConfig.demo ? DemoJobsRepository() : ApiJobsRepository(api: c.read<ApiClient>())),
        ),
        ChangeNotifierProvider<MarketplaceController>(
          create: (c) => MarketplaceController(
            AppConfig.demo ? DemoMarketplaceRepository() : ApiMarketplaceRepository(api: c.read<ApiClient>()),
          ),
        ),
      ],
      // The bell's unread count and the notification router, for every tab and every pushed screen.
      child: Builder(
        // Below the providers: the notification openers read `JobsController`, `FeedController`... from here,
        // because the notifications list is a pushed route and sits above them.
        builder: (shellContext) => InboxHost(
          api: context.read<ApiClient>(),
          router: NotificationRouter(openers: _wireShell(shellContext)),
          child: AppShell(
            drawer: ProfileDrawer(
              screens: screens,
              // A company in "Your companies" opens its page in the app; `shellContext` is below the providers.
              onOpenCompany: (ctx, id) => openCompanyInsightsById(
                shellContext,
                companyId: id,
                jobs: shellContext.read<JobsController>().repository,
              ),
            ),
            home: Builder(
              builder: (ctx) => HomeScreen(
                viewer: _viewer,
                onAccount: () => AppShell.openDrawer(ctx),
                callbacks: ForumCallbacks(
                  onBell: () => openNotifications(ctx),
                  onOpenMember: (id) => openMemberProfile(ctx, id),
                ),
              ),
            ),
            learning: Builder(
              builder: (ctx) => LearningHubScreen(
                viewer: _viewer,
                onBack: () => AppShell.selectHome(ctx),
                onAccount: () => AppShell.openDrawer(ctx),
                // The banner's "Know more": the Events screen, as the Discover door opens it.
                onMasterclasses: () => AppShell.push<void>(ctx, screens['/events']!),
              ),
            ),
            mentorship: Builder(
              builder: (ctx) => MentorshipScreen(
                viewer: _viewer,
                onBack: () => AppShell.selectHome(ctx),
                onAccount: () => AppShell.openDrawer(ctx),
                onOpenMentor: _openMentor,
                openSite: _openMentorshipPath,
              ),
            ),
            jobs: Builder(
              builder: (ctx) => JobsScreen(
                onBack: () => AppShell.selectHome(ctx),
                navigation: JobsNavigation(
                  onBell: () => openNotifications(ctx),
                  onOpenConversation: (id) => MessagingLauncher.openConversation(ctx, id),
                  onOpenProfile: (id) => openMemberProfile(ctx, id),
                  onEditProfile: () => openMyProfile(ctx),
                  onOpenCompany: (id) =>
                      openCompanyInsightsById(ctx, companyId: id, jobs: ctx.read<JobsController>().repository),
                  onFindJobs: (query) {
                    AppShell.goToTab(ctx, AppTab.jobs);
                    if (query != null) ctx.read<JobsController>().setSearch(query);
                  },
                  onCreateCompany: () => AppShell.push<void>(ctx, (c) => CreateCompanyScreen()),
                  onDemonstrateSkills: () => AppShell.goToTab(ctx, AppTab.learning),
                ),
              ),
            ),
            forums: Builder(
              builder: (ctx) => ForumsScreen(
                viewer: _viewer,
                onBack: () => AppShell.selectHome(ctx),
                callbacks: ForumCallbacks(
                  onBell: () => openNotifications(ctx),
                  onOpenMember: (id) => openMemberProfile(ctx, id),
                ),
              ),
            ),
            marketplace: Builder(
              builder: (ctx) => MarketplaceScreen(
                onBack: () => AppShell.selectHome(ctx),
                onBell: () => openNotifications(ctx),
                onPostRfq: () => pushComposer(ctx, appRfqHooks(ctx)),
                onMyRfqs: () => pushMyRfqs(ctx, appRfqHooks(ctx)),
                onRfqAlerts: () => pushAlerts(ctx, appRfqHooks(ctx)),
                navigation: appMarketplaceNavigation(ctx),
              ),
            ),
            doors: screens,
          ),
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    // The card that follows is light or dark with the phone, so this is too.
    final palette = AuthPalette.of(context);
    return Scaffold(
      backgroundColor: palette.isDark ? palette.page : Colors.white,
      body: Center(child: Image.asset(palette.logo, width: 180)),
    );
  }
}
