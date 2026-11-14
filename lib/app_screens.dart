import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/auth/auth_controller.dart';
import 'core/config.dart';
import 'app_community_manage.dart';
import 'app_site_pages.dart';
import 'core/util/links.dart' show SiteRouteOpener, openSitePage;
import 'core/util/screen_trail.dart' show SitePlace;
import 'app_workspaces.dart' show workspaceRouteFor;
import 'features/directory/companies_directory_screen.dart';
import 'features/career/company_insights_screen.dart';
import 'features/jobs/jobs_controller.dart';
import 'features/councils/api_councils_repository.dart';
import 'features/councils/council_screen.dart' show CouncilHandoffs;
import 'features/councils/councils_controller.dart';
import 'features/councils/councils_screen.dart';
import 'features/councils/demo_councils_repository.dart';
import 'features/events/api_events_repository.dart';
import 'features/events/demo_events_repository.dart';
import 'features/events/events_controller.dart';
import 'features/events/event_manage_scope.dart';
import 'features/events/events_screen.dart';
import 'features/account/companies/create_company_screen.dart';
import 'features/account/members/member_profile_screen.dart';
import 'features/assistant/open_assistant.dart' show openAssistant;
import 'features/account/profile/my_profile_screen.dart';
import 'features/account/saved/saved_items_screen.dart';
import 'features/account/settings/settings_screen.dart';
import 'features/account/widgets/account_session.dart';
import 'features/chapters/api_chapters_repository.dart';
import 'features/chapters/chapters_controller.dart';
import 'features/chapters/chapters_screen.dart';
import 'features/chapters/demo_chapters_repository.dart';
import 'features/events/event_models.dart' show EventKind, EventSummary, eventsNow;
import 'features/events/event_sheet.dart' show showEventSheet;
import 'features/feed/feed_models.dart';
import 'features/feed/session_viewer.dart';
import 'features/forum/api_forum_repository.dart';
import 'features/forum/demo_forum_repository.dart';
import 'features/forum/forum_callbacks.dart';
import 'features/forum/forum_models.dart' show ForumView;
import 'features/forum/forums_controller.dart';
import 'features/forum/forums_screen.dart';
import 'features/library/api_library_repository.dart';
import 'features/library/demo_library_repository.dart';
import 'features/library/library_controller.dart';
import 'features/library/library_models.dart' show LibraryQuery;
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
import 'features/membership/plan_benefits_screen.dart';
import 'features/mentorship_my/mentoring_links.dart' show MentorshipLinks;
import 'features/become_mentor/become_mentor_controller.dart' show FixTarget;
import 'features/become_mentor/become_mentor_screen.dart' show openBecomeMentor;
import 'features/contact/contact_screen.dart' show contactRoute;
import 'features/mentor_profile/mentor_profile_screen.dart' show mentorProfileRoute;
import 'features/mentorship_my/group_sessions_screen.dart' show openGroupSession;
import 'features/mentorship_my/pairing_screen.dart' show openPairing;
import 'features/mentorship_my/programmes_screen.dart' show openProgramme, openProgrammes;
import 'features/messaging/messaging_launcher.dart';
import 'features/network/network_screen.dart' show networkRoute;
import 'features/notifications/notifications_bell.dart';
import 'features/notifications/notifications_screen.dart' show openNotifications;
import 'features/partner_console/batches_screen.dart' show ManageBatchesScreen;
import 'features/partner_console/courses_screen.dart' show ManageCoursesScreen;
import 'features/partner_console/enrolments_screen.dart' show EnrolmentsScreen;
import 'features/partner_enquiries/enquiries_screen.dart';
import 'features/catalog/products_screen.dart' show ProductsScreen;
import 'features/company/company_workspace_screen.dart' show CompanyWorkspaceScreen;
import 'features/catalog/services_screen.dart' show ServicesScreen;
import 'features/projects/project_screen.dart' show ProjectScreen;
import 'features/projects/projects_screen.dart' show ProjectsScreen;
import 'features/talent/talent_screen.dart' show TalentScreen;
import 'features/rfq/my_bids_screen.dart';
import 'features/rfq/my_rfqs_screen.dart';
import 'features/rfq/open_requirements_screen.dart';
import 'features/rfq/post_rfq_screen.dart';
import 'features/rfq/requirements_board_screen.dart';
import 'features/rfq/rfq_navigation.dart';
import 'features/rfq/rfq_scope.dart';
import 'features/shell/app_shell.dart';
import 'features/site/credits_screen.dart';
import 'features/site/legal_page.dart' show legalPages;
import 'features/site/legal_page_screen.dart' show LegalPageScreen;
import 'features/site/reviews_screen.dart';
import 'features/shell/icr_bottom_nav.dart';
import 'features/support/support_routes.dart' show openSupport;
import 'features/support/support_screen.dart' show SupportScreen;
import 'features/team/team_screen.dart' show TeamScreen, TeamTab;
import 'features/shell/shell_page.dart';
import 'features/mentorship_my/certificate_check.dart';
import 'features/mentor_desk/mentor_desk_controller.dart' show DeskTab;
import 'features/mentor_desk/mentor_desk_screen.dart' show openMentorDesk;
import 'app_search.dart' show openMentorProfile;
import 'core/widgets/workspace_embed.dart';
import 'features/mentorship/find_mentors_screen.dart' show openFindMentors;
import 'features/mentorship/mentorship_controller.dart';

/// An event's sheet by its slug or id (a chapter's meetup, a notification), over whatever called it. The sheet
/// shows a blank title until the event has been read.
Future<void> openEventBySlug(BuildContext context, String slugOrId) {
  final events = EventsController(
    AppConfig.demo ? DemoEventsRepository() : ApiEventsRepository(api: context.read<ApiClient>()),
  );
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (_, _, _) => SitePlace(
        path: '/events/$slugOrId',
        child: ChangeNotifierProvider<EventsController>.value(
          value: events,
          child: EventManageScope(onManage: manageEventDoor(context), child: _EventSheetLauncher(slugOrId)),
        ),
      ),
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

/// The Chapters board, in the Home frame (the bottom bar under it, as under every Chapters, Councils and Events
/// page; owner, 13 Nov 2026), with the pencil for the staff who run chapters.
Widget chaptersScreen(BuildContext ctx) => ChangeNotifierProvider<ChaptersController>(
  create: (c) =>
      ChaptersController(AppConfig.demo ? DemoChaptersRepository() : ApiChaptersRepository(api: c.read<ApiClient>())),
  child: communityFrame(
    ChaptersScreen(
      onBack: () => Navigator.of(ctx).pop(),
      onOpenEvent: (slugOrId) => openEventBySlug(ctx, slugOrId),
      onOpenVolunteer: (chapter) => AppShell.push<void>(ctx, (c) => getInvolvedScreen(c, chapter: chapter)),
      onBell: () => openNotifications(ctx),
      onOpenMember: (id) => openMemberProfile(ctx, id),
      onMessage: (id) => MessagingLauncher.withPerson(ctx, id),
      onManage: manageChaptersDoor(ctx),
      manage: chapterManageDoor(ctx),
      pageWrap: communityFrame,
    ),
  ),
);

/// What a council's own page hands on to the app: the event sheet, a member's profile, a conversation and the
/// bell. The councils board and a link to `/councils/<slug>` (`app_site_pages.dart`) give the page the same ones.
CouncilHandoffs appCouncilHandoffs(BuildContext ctx) => CouncilHandoffs(
  onOpenEvent: (slugOrId) => openEventBySlug(ctx, slugOrId),
  onBell: () => openNotifications(ctx),
  onOpenMember: (id) => openMemberProfile(ctx, id),
  onMessage: (id) => MessagingLauncher.withPerson(ctx, id),
  manage: councilManageDoor(ctx),
  pageWrap: communityFrame,
);

Widget libraryScreen(BuildContext ctx) => _libraryScreen(ctx, mine: false);

/// The library (`/documents`), or the member's own uploads alone (`/documents?mine=1`, the menu's My Uploads: the
/// documents they put in the library, each to edit or delete — the owner's document, 12 Nov 2026).
Widget _libraryScreen(BuildContext ctx, {required bool mine}) => ChangeNotifierProvider<LibraryController>(
  create: (c) => LibraryController(
    AppConfig.demo ? DemoLibraryRepository() : ApiLibraryRepository(api: c.read<ApiClient>()),
    initial: LibraryQuery(mine: mine),
  ),
  child: LibraryScreen(
    onBack: () => Navigator.of(ctx).pop(),
    onBell: () => openNotifications(ctx),
    onOpenMember: (id) => openMemberProfile(ctx, id),
  ),
);

/// The member's own discussions and polls (`/community?mine=1`, the menu's My Forum): the forum on its My posts
/// view with a controller of its own, so the Forums tab keeps its view; a post's page has Edit and Delete for its
/// author. A pushed route cannot read the tabs' controllers, so the repository is built from the API client.
Widget myForumScreen(BuildContext ctx) {
  final viewerId = maybeAuth(ctx)?.user?.id ?? '';
  return ChangeNotifierProvider<ForumsController>(
    create: (c) => ForumsController(
      AppConfig.demo ? DemoForumRepository() : ApiForumRepository(api: c.read<ApiClient>(), viewerId: viewerId),
      initialView: ForumView.mine,
      ownTopics: true,
    ),
    child: SessionViewer(
      builder: (c, v) => ForumsScreen(
        viewer: v,
        title: 'My Forum',
        ownOnly: true,
        controller: c.read<ForumsController>(),
        onBack: () => Navigator.of(ctx).pop(),
        callbacks: ForumCallbacks(onBell: () => openNotifications(c), onOpenMember: (id) => openMemberProfile(c, id)),
      ),
    ),
  );
}

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
  openDirectory: openMentorSearch,
  openConversation: (c, id) => MessagingLauncher.openConversation(c, id),
  openPairingThread: (c, id) => MessagingLauncher.forMentorship(c, id),
  openPurchaseThread: (c, id) => MessagingLauncher.forPurchase(c, id),
  openGroupThread: (c, id) => MessagingLauncher.forGroupSession(c, id),
  openNotifications: (c) => openNotifications(c),
);

/// "Find a mentor" (and "Find another") on the mentoring screens: the mentor search. Inside a workspace that has a
/// Find a mentor tab, that tab; elsewhere the search pushed over the screen. A screen opened where the signed-in
/// controllers do not reach goes back instead, as it always did (it was opened from the search).
void openMentorSearch(BuildContext context) {
  if (WorkspaceEmbed.openTabFor(context, '/mentorship/mentors')) return;
  try {
    context.read<MentorshipController>();
  } on ProviderNotFoundException {
    Navigator.of(context).maybePop();
    return;
  }
  openFindMentors(context, onOpenMentor: (c, id) => openMentorProfile(c, id));
}

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
);

Future<void> openSettings(BuildContext context) => AppShell.push<void>(context, settingsScreen);

/// Settings, with "Help & support" opening the member's requests (the website's `/support`).
Widget settingsScreen(BuildContext ctx) =>
    SettingsScreen(onOpenProfile: () => openMyProfile(ctx), onSupport: () => openSupport(ctx));

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

/// Signed out, the app has only the legal pages to open itself ("Terms of Service" and "Privacy Policy" under the
/// sign-up consent line); anything else stays with the phone.
SiteRouteOpener? signedOutSiteRoute(Uri uri) {
  final legal = legalPages[uri.path];
  if (legal == null) return null;
  return (ctx) => Navigator.of(ctx).push(
    MaterialPageRoute<void>(
      builder: (c) => LegalPageScreen(page: legal, onBack: () => Navigator.of(c).pop()),
    ),
  );
}

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
    // The website's assistant page: Saathi, the app's own since 6 Nov 2026.
    case '/ai':
      return (ctx) => openAssistant(ctx);
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
  if (screen == null) {
    final page = appSitePage(uri, path, viewer: viewer, shell: shell);
    if (page != null || shell == null) return page;
    // A page of the drawer's own rows (Post a job, Flash cards, My company...) reached by a link - Saathi's pill, a
    // notification - opens as the row would, never in the web view (owner, 7 Nov 2026).
    return workspaceRouteFor(uri, viewer: viewer, shell: shell);
  }
  return (ctx) => AppShell.push<void>(ctx, screen);
}

/// The partner institute's Manage Courses (`/admin/learning/courses`, and `/admin/learning?course=` from a course's
/// review decision).
Future<void> openPartnerCourses(BuildContext ctx) =>
    AppShell.push<void>(ctx, (c) => ManageCoursesScreen(onBack: () => Navigator.of(c).pop()));

/// The partner institute's Manage Batches (`/admin/learning/batches`), narrowed to [courseId] when a link names one.
Future<void> openPartnerBatches(BuildContext ctx, {String? courseId}) =>
    AppShell.push<void>(ctx, (c) => ManageBatchesScreen(onBack: () => Navigator.of(c).pop(), courseId: courseId));

/// The partner institute's Enrolment (`/admin/learning/enrolments`), narrowed to [courseId] when a link names one.
Future<void> openPartnerEnrolments(BuildContext ctx, {String? courseId}) =>
    AppShell.push<void>(ctx, (c) => EnrolmentsScreen(onBack: () => Navigator.of(c).pop(), courseId: courseId));

/// The company the member acts for (`/company[?tab=]`, the website's company workspace): its details, verification and
/// certificates. Its public page and its team open the app's own screens.
Widget companyWorkspaceScreen(BuildContext ctx, {String? tab, VoidCallback? onBack}) => CompanyWorkspaceScreen(
  onBack: onBack ?? () => Navigator.of(ctx).pop(),
  tab: tab,
  onOpenCompanyPage: (id) => openSitePage(ctx, '/companies/$id'),
  onOpenTeam: () => AppShell.push<void>(ctx, (c) => teamScreen(c)),
);

/// One sourcing project's page (`/manage/projects/<id>`).
Future<void> openProjectById(BuildContext ctx, String id) => AppShell.push<void>(
  ctx,
  (c) => ProjectScreen(
    projectId: id,
    onBack: () => Navigator.of(c).pop(),
    onOpenJob: (jobId) => openSitePage(c, '/jobs/$jobId'),
  ),
);

/// The partner institute's enquiries (`/admin/learning/enquiries`), on [focusId] when a notification names one.
Future<void> openPartnerEnquiries(BuildContext ctx, {String? focusId}) =>
    AppShell.push<void>(ctx, (c) => PartnerEnquiriesScreen(onBack: () => Navigator.of(c).pop(), focusId: focusId));

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
  // `?fix=availability` opens that form on arrival: the mentor desk's missing lines.
  if (path == '/become-a-mentor' || path == '/mentorship/become-a-mentor') {
    final fix = FixTarget.values.asNameMap()[uri.queryParameters['fix']];
    return (ctx) => openBecomeMentor(ctx, fix: fix);
  }
  // The website's `/profile?tab=<section>` lands on that section (security is its own screen, in the table below).
  if (path == '/profile') {
    final section = ProfileSection.values.asNameMap()[uri.queryParameters['tab']];
    if (section != null) return (ctx) => openMyProfile(ctx, section: section);
  }
  if (path == '/mentorship/programmes') {
    return (ctx) => openProgrammes(ctx, onBecomeMentor: (c) => openBecomeMentor(c));
  }
  // The website's mentor dashboard (`?tab=services|work|settings`), which My mentoring's "Open Engagements" and the
  // website's own links name: the app's mentor desk on the same tab, never the web view.
  if (path == '/mentorship/mentor') {
    return (ctx) => openMentorDesk(
      ctx,
      tab: switch (uri.queryParameters['tab']) {
        'services' => DeskTab.offerings,
        'work' => DeskTab.work,
        'settings' => DeskTab.settings,
        _ => DeskTab.overview,
      },
    );
  }
  // The mentoring records the notification router opens (`app_notifications.dart`), so a cohort card's "Know
  // more" or a link in a message reaches the app's screen and not the web view. The public certificate check
  // (`/mentorship/certificates/<number>`, the certificate sheet's "Verify online") is the app's own sheet since
  // 4 Nov 2026.
  if (parts.length == 3 && parts[0] == 'mentorship') {
    switch (parts[1]) {
      case 'programmes':
        return (ctx) => openProgramme(ctx, parts[2]);
      case 'groups':
        return (ctx) => openGroupSession(ctx, parts[2]);
      case 'my':
        return (ctx) => openPairing(ctx, parts[2]);
      case 'certificates':
        return (ctx) => showMentoringCertificateCheck(ctx, parts[2]);
    }
  }
  if (path == '/account/companies/new') return (ctx) => AppShell.push<void>(ctx, (c) => CreateCompanyScreen.routed(c));
  if (path == '/network') {
    return (ctx) => AppShell.push<void>(
      ctx,
      (c) => networkRoute(c, onOpenProfile: (id) => openMemberProfile(c, id), onBell: () => openNotifications(c)),
    );
  }
  if (path == '/contact') {
    return (ctx) => AppShell.push<void>(
      ctx,
      (c) => contactRoute(
        c,
        subject: uri.queryParameters['subject'],
        onBell: () => openNotifications(c),
        // A signed-in member is pointed to a request, which has a reference and a thread: the app's own desk.
        onRaiseRequest: () => openSupport(c),
      ),
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
  onCreateCompany: () => AppShell.push<void>(ctx, (c) => CreateCompanyScreen.routed(c)),
  // "Posting for" and "Switch company" on the requirement form: the account's switch, with its fresh session
  // adopted, as the profile menu's companies switch.
  onSwitchCompany: (companyId) async {
    final auth = ctx.read<AuthController>();
    final tokens = await accountRepositoryOf(ctx).switchCompany(companyId);
    await auth.adoptSession(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken, user: tokens.user);
  },
);

/// The company's team (the website's `/manage/team`): members, join requests, and people added who have not answered.
/// `?tab=requests` ("someone asked to join your team") opens on Requests.
Widget teamScreen(
  BuildContext ctx, {
  TeamTab tab = TeamTab.members,
  String? inviteLearningRole,
  VoidCallback? onBack,
}) => TeamScreen(
  initialTab: tab,
  inviteLearningRole: inviteLearningRole,
  onBack: onBack ?? () => Navigator.of(ctx).pop(),
  onOpenMember: (id) => openMemberProfile(ctx, id),
  onCreateCompany: () => AppShell.push<void>(ctx, (c) => CreateCompanyScreen.routed(c)),
);

/// Help & support (the website's `/support`): the member's requests to ICR.
Widget supportScreen(BuildContext ctx) =>
    SupportScreen(onBack: () => Navigator.of(ctx).pop(), onOpenContext: (href) => openSitePage(ctx, href));

/// Screens the Discover doors and the profile menu open in the app, keyed by
/// the website path they replace. A pushed route sits above the tab
/// controllers, so each brings its own.
Map<String, WidgetBuilder> inAppScreens({required FeedAuthor viewer, bool? demo}) {
  final sample = demo ?? AppConfig.demo;
  return {
    '/chapters': chaptersScreen,
    '/documents': libraryScreen,
    // The menu's My Uploads and My Forum (the owner's document, 12 Nov 2026).
    '/documents?mine=1': (ctx) => _libraryScreen(ctx, mine: true),
    '/community?mine=1': myForumScreen,
    '/get-involved': getInvolvedScreen,
    // Founding a company: the website's "Create a Company Page +" and "what brings you here" links (which it shows
    // only to someone acting for no company). The Discover sheet's Hire and Sell no longer come here: Hire is Post a
    // job (`openPostJob`, which asks for a company only from someone who has none) and Sell the Supplier Mart, as on
    // the website — mapping them here sent a member with a company to "create a company" (owner, 3 Nov 2026).
    '/account/companies/new?role=COMPANY_ADMIN': (ctx) => CreateCompanyScreen.routed(ctx),
    '/account/companies/new?role=VENDOR': (ctx) => CreateCompanyScreen.routed(ctx),
    '/profile': (ctx) => myProfileScreen(ctx),
    // Native since 5 Nov 2026 (they were the website's pages in the web view). A `?tab=` has its own key: a path with a
    // query is looked up whole before the bare path.
    '/manage/team': teamScreen,
    '/manage/team?tab=requests': (ctx) => teamScreen(ctx, tab: TeamTab.requests),
    '/manage/team?tab=pending': (ctx) => teamScreen(ctx, tab: TeamTab.pending),
    '/support': supportScreen,
    // The hiring team's sourcing projects (the Jobs row's Projects), the app's own since 12 Nov 2026. A job named on a
    // project opens through the site route, so the shell's jobs source serves it wherever the list was pushed from.
    // The company the member acts for (the Company row's Dashboard; "Verify your company" links), the app's own since
    // 12 Nov 2026. A `?tab=` has its own key, as the team's do.
    '/company': companyWorkspaceScreen,
    for (final tab in const ['overview', 'identity', 'verification', 'certifications'])
      '/company?tab=$tab': (ctx) => companyWorkspaceScreen(ctx, tab: tab),
    // The website's old verification page, which it redirects to the company check.
    '/manage/verification': (ctx) => companyWorkspaceScreen(ctx, tab: 'verification'),
    // The seller's catalogue (the Marketplace and Company rows' My Products and My Services), the app's own since
    // 12 Nov 2026.
    '/manage/products': (ctx) => ProductsScreen(
      onBack: () => Navigator.of(ctx).pop(),
      onCreateCompany: () => AppShell.push<void>(ctx, (c) => CreateCompanyScreen.routed(c)),
    ),
    '/manage/services': (ctx) => ServicesScreen(
      onBack: () => Navigator.of(ctx).pop(),
      onCreateCompany: () => AppShell.push<void>(ctx, (c) => CreateCompanyScreen.routed(c)),
    ),
    // The Jobs row's Source Candidates (the website's talent search), the app's own since 12 Nov 2026. A public
    // profile opens the app's member page.
    '/talent': (ctx) =>
        TalentScreen(onBack: () => Navigator.of(ctx).pop(), onOpenMember: (id) => openSitePage(ctx, '/members/$id')),
    '/manage/projects': (ctx) => ProjectsScreen(
      onBack: () => Navigator.of(ctx).pop(),
      onOpenJob: (id) => openSitePage(ctx, '/jobs/$id'),
      onCreateCompany: () => AppShell.push<void>(ctx, (c) => CreateCompanyScreen.routed(c)),
    ),
    '/profile?tab=security': settingsScreen,
    '/career/saved': (ctx) => SavedItemsScreen(
      onBell: () => openNotifications(ctx),
      unread: bellUnread(ctx),
      onOpenSupplier: (id) => showSupplierSheetById(ctx, id, navigation: appMarketplaceNavigation(ctx)),
    ),
    '/learning/certificates': (ctx) => CertificatesScreen(onBack: () => Navigator.of(ctx).pop()),
    // The four pages of the website's workspace menu the app had no screen for (owner, 4 Nov 2026: "website
    // redirecting should be avoided"): the companies directory, what the member's plans include, their credits and
    // redemptions, and the platform's reviews.
    '/companies': (ctx) => CompaniesDirectoryScreen(
      onBack: () => Navigator.of(ctx).pop(),
      onBell: () => openNotifications(ctx),
      // The company's page in the app (owner, 7 Nov 2026), read with the shell's jobs source.
      onOpenCompany: (id) => openCompanyInsightsById(ctx, companyId: id, jobs: ctx.read<JobsController>().repository),
    ),
    '/membership/benefits': (ctx) => PlanBenefitsScreen(
      onBack: () => Navigator.of(ctx).pop(),
      onBell: () => openNotifications(ctx),
      onSeePlans: () => openMembership(ctx),
    ),
    '/refer/credits': (ctx) => CreditsScreen(
      onBack: () => Navigator.of(ctx).pop(),
      onBell: () => openNotifications(ctx),
      onRefer: () => openSitePage(ctx, '/refer'),
    ),
    '/reviews': (ctx) => ReviewsScreen(onBack: () => Navigator.of(ctx).pop(), onBell: () => openNotifications(ctx)),
    // Everything posted on ICR, the website's Requirements page: the profile menu's Requirements row, and every
    // `/rfq` link (it opened the Marketplace tab until 3 Nov 2026, which lists no requirements).
    '/rfq': (ctx) {
      final hooks = appRfqHooks(ctx);
      return RequirementsBoardScreen(
        repository: hooks.repository,
        links: hooks.links,
        onOpenConversation: hooks.onOpenConversation,
        onOpenSupplier: hooks.onOpenSupplier,
        onCreateCompany: hooks.onCreateCompany,
      );
    },
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
    // The supplier's side of the board: Find Work & Bid, and its tabs of the member's own bids.
    '/manage/bids': (ctx) {
      final hooks = appRfqHooks(ctx);
      return OpenRequirementsScreen(
        repository: hooks.repository,
        links: hooks.links,
        onOpenConversation: hooks.onOpenConversation,
        onOpenSupplier: hooks.onOpenSupplier,
      );
    },
    for (final tab in const ['submitted', 'negotiation', 'awarded', 'archived'])
      '/manage/bids?tab=$tab': (ctx) {
        final hooks = appRfqHooks(ctx);
        return MyBidsScreen(
          repository: hooks.repository,
          links: hooks.links,
          onOpenConversation: hooks.onOpenConversation,
          onOpenSupplier: hooks.onOpenSupplier,
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
        onSwitchCompany: hooks.onSwitchCompany,
      );
    },
    '/councils': (ctx) => ChangeNotifierProvider<CouncilsController>(
      create: (c) =>
          CouncilsController(sample ? DemoCouncilsRepository() : ApiCouncilsRepository(api: c.read<ApiClient>())),
      child: communityFrame(
        CouncilsScreen(
          onBack: () => Navigator.of(ctx).pop(),
          handoffs: appCouncilHandoffs(ctx),
          onManage: manageCouncilsDoor(ctx),
        ),
      ),
    ),
    '/events': (ctx) => ChangeNotifierProvider<EventsController>(
      create: (c) => EventsController(sample ? DemoEventsRepository() : ApiEventsRepository(api: c.read<ApiClient>())),
      // The Events design stands under the Home tab, with the bar showing.
      child: ShellPage(
        tab: AppTab.home,
        child: EventManageScope(
          onManage: manageEventDoor(ctx),
          child: EventsScreen(
            viewer: viewer,
            onBack: () => Navigator.of(ctx).pop(),
            onAccount: () => AppShell.openDrawer(ctx),
            onManage: manageEventsDoor(ctx),
          ),
        ),
      ),
    ),
  };
}
