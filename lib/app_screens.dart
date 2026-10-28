import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/config.dart';
import 'app_site_pages.dart';
import 'core/util/links.dart' show SiteRouteOpener;
import 'features/councils/api_councils_repository.dart';
import 'features/councils/councils_controller.dart';
import 'features/councils/councils_screen.dart';
import 'features/councils/demo_councils_repository.dart';
import 'features/events/api_events_repository.dart';
import 'features/events/demo_events_repository.dart';
import 'features/events/events_controller.dart';
import 'features/events/events_screen.dart';
import 'features/account/companies/create_company_screen.dart';
import 'features/account/members/member_profile_screen.dart';
import 'features/account/profile/my_profile_screen.dart';
import 'features/account/saved/saved_items_screen.dart';
import 'features/account/settings/settings_screen.dart';
import 'features/chapters/api_chapters_repository.dart';
import 'features/chapters/chapters_controller.dart';
import 'features/chapters/chapters_screen.dart';
import 'features/chapters/demo_chapters_repository.dart';
import 'features/events/event_models.dart' show EventKind, EventSummary, eventsNow;
import 'features/events/event_sheet.dart' show showEventSheet;
import 'features/feed/feed_models.dart';
import 'features/library/api_library_repository.dart';
import 'features/library/demo_library_repository.dart';
import 'features/library/library_controller.dart';
import 'features/library/library_screen.dart';
import 'features/volunteer/api_volunteer_repository.dart';
import 'features/volunteer/demo_volunteer_repository.dart';
import 'features/volunteer/get_involved_screen.dart';
import 'features/volunteer/volunteer_controller.dart';
import 'features/volunteer/volunteer_models.dart' show VolunteerIntent;
import 'features/learning_exam/certificates_screen.dart';
import 'features/marketplace/marketplace_navigation.dart';
import 'features/marketplace/supplier_sheet.dart';
import 'features/membership/membership_models.dart' show MembershipAudience;
import 'features/membership/membership_screen.dart';
import 'features/mentorship_my/mentoring_links.dart' show MentorshipLinks;
import 'features/become_mentor/become_mentor_screen.dart' show openBecomeMentor;
import 'features/contact/contact_screen.dart' show contactRoute;
import 'features/mentor_profile/mentor_profile_screen.dart' show mentorProfileRoute;
import 'features/mentorship_my/programmes_screen.dart' show openProgrammes;
import 'features/messaging/messaging_launcher.dart';
import 'features/network/network_screen.dart' show networkRoute;
import 'features/notifications/notifications_bell.dart';
import 'features/notifications/notifications_screen.dart' show openNotifications;
import 'features/rfq/my_rfqs_screen.dart';
import 'features/rfq/post_rfq_screen.dart';
import 'features/rfq/rfq_navigation.dart';
import 'features/rfq/rfq_scope.dart';
import 'features/shell/app_shell.dart';
import 'features/shell/icr_bottom_nav.dart';
import 'features/shell/shell_page.dart';

/// An event's sheet by its slug or id (a chapter's meetup, a notification), over whatever called it. The sheet
/// shows a blank title until the event has been read.
Future<void> openEventBySlug(BuildContext context, String slugOrId) {
  final events = EventsController(
    AppConfig.demo ? DemoEventsRepository() : ApiEventsRepository(api: context.read<ApiClient>()),
  );
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (_, _, _) =>
          ChangeNotifierProvider<EventsController>.value(value: events, child: _EventSheetLauncher(slugOrId)),
    ),
  );
}

class _EventSheetLauncher extends StatefulWidget {
  const _EventSheetLauncher(this.slugOrId);

  final String slugOrId;

  @override
  State<_EventSheetLauncher> createState() => _EventSheetLauncherState();
}

class _EventSheetLauncherState extends State<_EventSheetLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final seed = EventSummary(
        id: widget.slugOrId,
        slug: widget.slugOrId,
        title: '',
        kind: EventKind.webinar,
        startsAt: eventsNow(),
      );
      await showEventSheet(context, seed);
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Widget chaptersScreen(BuildContext ctx) => ChangeNotifierProvider<ChaptersController>(
  create: (c) =>
      ChaptersController(AppConfig.demo ? DemoChaptersRepository() : ApiChaptersRepository(api: c.read<ApiClient>())),
  child: ChaptersScreen(
    onBack: () => Navigator.of(ctx).pop(),
    onOpenEvent: (slugOrId) => openEventBySlug(ctx, slugOrId),
    onOpenVolunteer: (chapter) => AppShell.push<void>(ctx, (c) => getInvolvedScreen(c, chapter: chapter)),
    onBell: () => openNotifications(ctx),
    onOpenMember: (id) => openMemberProfile(ctx, id),
    onMessage: (id) => MessagingLauncher.withPerson(ctx, id),
  ),
);

Widget libraryScreen(BuildContext ctx) => ChangeNotifierProvider<LibraryController>(
  create: (c) =>
      LibraryController(AppConfig.demo ? DemoLibraryRepository() : ApiLibraryRepository(api: c.read<ApiClient>())),
  child: LibraryScreen(
    onBack: () => Navigator.of(ctx).pop(),
    onBell: () => openNotifications(ctx),
    onOpenMember: (id) => openMemberProfile(ctx, id),
  ),
);

Widget getInvolvedScreen(BuildContext ctx, {String? chapter}) => ChangeNotifierProvider<VolunteerController>(
  create: (c) => VolunteerController(
    AppConfig.demo ? DemoVolunteerRepository() : ApiVolunteerRepository(api: c.read<ApiClient>()),
  ),
  child: GetInvolvedScreen(
    onBack: () => Navigator.of(ctx).pop(),
    onBell: () => openNotifications(ctx),
    onOpenChapters: () => AppShell.push<void>(ctx, chaptersScreen),
    intent: chapter == null ? null : VolunteerIntent.chapter(chapter),
  ),
);

/// What the mentoring screens (My mentoring, a pairing, the mentor desk, becoming a mentor) hand back to the app:
/// every "Message" opens the app's conversation, the bell the app's notifications.
final appMentorshipLinks = MentorshipLinks(
  openConversation: (c, id) => MessagingLauncher.openConversation(c, id),
  openPairingThread: (c, id) => MessagingLauncher.forMentorship(c, id),
  openPurchaseThread: (c, id) => MessagingLauncher.forPurchase(c, id),
  openGroupThread: (c, id) => MessagingLauncher.forGroupSession(c, id),
  openNotifications: (c) => openNotifications(c),
);

/// A person's public page: what every name or photo in the app opens.
Future<void> openMemberProfile(BuildContext context, String userId) =>
    AppShell.push<void>(context, (ctx) => memberProfileScreen(ctx, userId));

Widget memberProfileScreen(BuildContext ctx, String userId) => MemberProfileScreen(
  userId: userId,
  onMessage: (conversationId, _) => MessagingLauncher.openConversation(ctx, conversationId),
  onEditProfile: () => openMyProfile(ctx),
);

/// The signed-in person's own profile page.
Future<void> openMyProfile(BuildContext context, {ProfileSection? section}) =>
    AppShell.push<void>(context, (ctx) => myProfileScreen(ctx, section: section));

Widget myProfileScreen(BuildContext ctx, {ProfileSection? section}) => MyProfileScreen(
  initialSection: section,
  onOpenPublicProfile: (userId) => openMemberProfile(ctx, userId),
  onOpenSettings: () => openSettings(ctx),
  onOpenSecurity: () => openSettings(ctx),
);

Future<void> openSettings(BuildContext context) =>
    AppShell.push<void>(context, (ctx) => SettingsScreen(onOpenProfile: () => openMyProfile(ctx)));

/// The plans (`/pricing/<audience>`, `/career/plans`, `/membership`), over whatever asked for them.
Future<void> openMembership(BuildContext context, {MembershipAudience? audience}) => AppShell.push<void>(
  context,
  (ctx) => MembershipScreen(audience: audience ?? MembershipAudience.seeker, onBack: () => Navigator.of(ctx).pop()),
);

/// The member's terms on one ladder (`/membership/history?audience=`).
Future<void> openMembershipHistory(BuildContext context, {MembershipAudience? audience}) => AppShell.push<void>(
  context,
  (ctx) =>
      MembershipHistoryScreen(audience: audience ?? MembershipAudience.seeker, onBack: () => Navigator.of(ctx).pop()),
);

/// The pages of the website the app opens itself, for `SiteRoutes.resolver`:
/// the notifications, the plans and the history, and every screen a Discover
/// door or a profile-menu row has (`/chapters`, `/events`, `/profile`, …).
/// Anything else is `appSitePage` (`lib/app_site_pages.dart`: the tabs, records by id, the small pages), and
/// then null: the app's web view opens it (see `SiteRoutes.webView`).
SiteRouteOpener? inAppSiteRoute(Uri uri, {required FeedAuthor viewer, BuildContext? shell}) {
  final path = uri.path.endsWith('/') && uri.path.length > 1 ? uri.path.substring(0, uri.path.length - 1) : uri.path;
  switch (path) {
    case '/notifications':
      return (ctx) => openNotifications(ctx);
    case '/pricing':
    case '/career/plans':
    case '/membership':
      return (ctx) => openMembership(ctx, audience: MembershipAudience.fromSitePath(uri));
    case '/membership/history':
      return (ctx) => openMembershipHistory(ctx, audience: MembershipAudience.fromSitePath(uri));
  }
  if (path.startsWith('/pricing/')) {
    final audience = MembershipAudience.fromSitePath(uri);
    if (audience != null) return (ctx) => openMembership(ctx, audience: audience);
  }
  final record = _inAppRecord(uri, path);
  if (record != null) return record;
  final screens = inAppScreens(viewer: viewer);
  // The website's "request a quote" page is the requirement form here.
  final screen = path == '/quote'
      ? screens['/rfq/new']
      : screens[uri.hasQuery ? '$path?${uri.query}' : path] ?? screens[path];
  if (screen == null) return appSitePage(uri, path, viewer: viewer, shell: shell);
  return (ctx) => AppShell.push<void>(ctx, screen);
}

/// The website's pages for one record (`/events/<slug>`, `/mentorship/mentors/<id>`, `/members/<id>`, `/vendors/<id>`,
/// `/messaging?c=<id>`) and the section pages that are not doors (`/network`, `/contact`, the mentoring ones), as the
/// app's own screens.
SiteRouteOpener? _inAppRecord(Uri uri, String path) {
  final parts = path.split('/').where((p) => p.isNotEmpty).toList();
  if (parts.length == 2 && parts[0] == 'events') return (ctx) => openEventBySlug(ctx, parts[1]);
  if (parts.length == 3 && parts[0] == 'mentorship' && parts[1] == 'mentors') {
    return (ctx) => AppShell.push<void>(ctx, (route) => mentorProfileRoute(route, parts[2]));
  }
  if (parts.length == 2 && parts[0] == 'members') return (ctx) => openMemberProfile(ctx, parts[1]);
  if (parts.length == 2 && parts[0] == 'vendors') {
    return (ctx) => showSupplierSheetById(ctx, parts[1], navigation: appMarketplaceNavigation(ctx));
  }
  if (path == '/messaging') {
    final conversation = uri.queryParameters['c'];
    return (ctx) =>
        conversation == null ? MessagingLauncher.openInbox(ctx) : MessagingLauncher.openConversation(ctx, conversation);
  }
  if (path == '/become-a-mentor' || path == '/mentorship/become-a-mentor') return (ctx) => openBecomeMentor(ctx);
  if (path == '/mentorship/programmes') {
    return (ctx) => openProgrammes(ctx, onBecomeMentor: (c) => openBecomeMentor(c));
  }
  if (path == '/account/companies/new') return (ctx) => AppShell.push<void>(ctx, (c) => CreateCompanyScreen());
  if (path == '/network') {
    return (ctx) => AppShell.push<void>(
      ctx,
      (c) => networkRoute(c, onOpenProfile: (id) => openMemberProfile(c, id), onBell: () => openNotifications(c)),
    );
  }
  if (path == '/contact') {
    return (ctx) => AppShell.push<void>(
      ctx,
      (c) => contactRoute(c, subject: uri.queryParameters['subject'], onBell: () => openNotifications(c)),
    );
  }
  return null;
}

/// The Marketplace's hand-overs: a message opens the app's conversation, a requirement its page.
MarketplaceNavigation appMarketplaceNavigation(BuildContext ctx) => MarketplaceNavigation(
  onOpenConversation: (id) => MessagingLauncher.openConversation(ctx, id),
  onOpenRfq: (id) => pushRfqDetail(ctx, appRfqHooks(ctx), id),
);

/// What every requirements screen needs from the rest of the app.
RfqHooks appRfqHooks(BuildContext ctx) => rfqHooksFor(
  ctx,
  onOpenConversation: (id) => MessagingLauncher.openConversation(ctx, id),
  onOpenSupplier: (id) => showSupplierSheetById(ctx, id, navigation: appMarketplaceNavigation(ctx)),
  onCreateCompany: () => AppShell.push<void>(ctx, (c) => CreateCompanyScreen()),
);

/// Screens the Discover doors and the profile menu open in the app, keyed by
/// the website path they replace. A pushed route sits above the tab
/// controllers, so each brings its own.
Map<String, WidgetBuilder> inAppScreens({required FeedAuthor viewer, bool? demo}) {
  final sample = demo ?? AppConfig.demo;
  return {
    '/chapters': chaptersScreen,
    '/documents': libraryScreen,
    '/get-involved': getInvolvedScreen,
    // Hire and Sell are the same page on the website: one company buys, sells and hires, and selling is switched on
    // afterwards ("Start selling"). Founding it is an app screen, so neither door leaves the app.
    '/account/companies/new?role=COMPANY_ADMIN': (ctx) => CreateCompanyScreen(),
    '/account/companies/new?role=VENDOR': (ctx) => CreateCompanyScreen(),
    '/profile': (ctx) => myProfileScreen(ctx),
    '/profile?tab=security': (ctx) => SettingsScreen(onOpenProfile: () => openMyProfile(ctx)),
    '/career/saved': (ctx) => SavedItemsScreen(
      onBell: () => openNotifications(ctx),
      unread: bellUnread(ctx),
      onOpenSupplier: (id) => showSupplierSheetById(ctx, id, navigation: appMarketplaceNavigation(ctx)),
    ),
    '/learning/certificates': (ctx) => CertificatesScreen(onBack: () => Navigator.of(ctx).pop()),
    '/manage/requirements': (ctx) {
      final hooks = appRfqHooks(ctx);
      return MyRfqsScreen(
        repository: hooks.repository,
        links: hooks.links,
        onOpenConversation: hooks.onOpenConversation,
        onOpenSupplier: hooks.onOpenSupplier,
        onCreateCompany: hooks.onCreateCompany,
      );
    },
    '/rfq/new': (ctx) {
      final hooks = appRfqHooks(ctx);
      return PostRfqScreen(
        repository: hooks.repository,
        links: hooks.links,
        onOpenConversation: hooks.onOpenConversation,
        onOpenSupplier: hooks.onOpenSupplier,
        onCreateCompany: hooks.onCreateCompany,
      );
    },
    '/councils': (ctx) => ChangeNotifierProvider<CouncilsController>(
      create: (c) =>
          CouncilsController(sample ? DemoCouncilsRepository() : ApiCouncilsRepository(api: c.read<ApiClient>())),
      child: CouncilsScreen(onBack: () => Navigator.of(ctx).pop()),
    ),
    '/events': (ctx) => ChangeNotifierProvider<EventsController>(
      create: (c) => EventsController(sample ? DemoEventsRepository() : ApiEventsRepository(api: c.read<ApiClient>())),
      // The Events design stands under the Home tab, with the bar showing.
      child: ShellPage(
        tab: AppTab.home,
        child: EventsScreen(
          viewer: viewer,
          onBack: () => Navigator.of(ctx).pop(),
          onAccount: () => AppShell.openDrawer(ctx),
        ),
      ),
    ),
  };
}
