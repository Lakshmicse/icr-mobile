import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_screens.dart';
import 'core/api/api_client.dart';
import 'core/config.dart';
import 'core/util/links.dart' show showMessage;
import 'core/widgets/detail_sheet.dart';
import 'features/account/companies/create_company_screen.dart';
import 'features/become_mentor/become_mentor_screen.dart';
import 'features/career/career_routes.dart';
import 'features/events/api_events_repository.dart';
import 'features/events/demo_events_repository.dart';
import 'features/events/events_repository.dart';
import 'features/feed/api_feed_repository.dart';
import 'features/feed/demo_feed_repository.dart';
import 'features/feed/feed_controller.dart';
import 'features/feed/feed_models.dart';
import 'features/feed/feed_repository.dart';
import 'features/forum/forum_callbacks.dart';
import 'features/forum/thread_screen.dart';
import 'features/jobs/api_jobs_repository.dart';
import 'features/jobs/demo_jobs_repository.dart';
import 'features/jobs/employer/hiring_routes.dart';
import 'features/jobs/job_detail_sheet.dart';
import 'features/jobs/job_models.dart';
import 'features/jobs/jobs_controller.dart';
import 'features/jobs/jobs_repository.dart';
import 'features/learning/api_learning_repository.dart';
import 'features/learning/course_sheet.dart';
import 'features/learning/course_sheet_controller.dart';
import 'features/learning/demo_learning_repository.dart';
import 'features/learning/learning_models.dart';
import 'features/learning/learning_repository.dart';
import 'features/learning_hub/learning_doors.dart';
import 'features/library/api_library_repository.dart';
import 'features/library/demo_library_repository.dart';
import 'features/library/document_screen.dart';
import 'features/library/library_models.dart';
import 'features/library/library_repository.dart';
import 'features/marketplace/api_marketplace_repository.dart';
import 'features/marketplace/demo_marketplace_repository.dart';
import 'features/marketplace/marketplace_controller.dart';
import 'features/marketplace/marketplace_repository.dart';
import 'features/marketplace/supplier_sheet.dart';
import 'features/mentor_desk/mentor_desk_screen.dart';
import 'features/mentor_profile/mentor_profile_screen.dart';
import 'features/mentorship/api_mentorship_repository.dart';
import 'features/mentorship/demo_mentorship_repository.dart';
import 'features/mentorship/find_mentors_screen.dart';
import 'features/mentorship/mentorship_controller.dart';
import 'features/mentorship/mentorship_repository.dart';
import 'features/mentorship_my/group_sessions_screen.dart';
import 'features/mentorship_my/my_mentoring_screen.dart';
import 'features/mentorship_my/programmes_screen.dart';
import 'features/messaging/api_messaging_repository.dart';
import 'features/messaging/demo_messaging_repository.dart';
import 'features/messaging/messaging_launcher.dart';
import 'features/notifications/notifications_screen.dart' show openNotifications;
import 'features/rfq/rfq_navigation.dart';
import 'features/search/recent_searches.dart';
import 'features/search/repository_sources.dart';
import 'features/search/search_models.dart';
import 'features/search/search_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/shell/icr_bottom_nav.dart' show AppTab;

/// What the global search needs from the rest of the app, in one place so the
/// search feature itself imports none of the features it opens: the sources
/// (each built on a screen's own repository), the opener for each kind of
/// record, and the opener for each place in the app the catalogue names.
///
/// Every opener runs with the context the search was opened from, which sits
/// inside the shell: the providers the screens read (`JobsController`,
/// `MentorshipLinks`...) are in reach, and a tab or a pushed screen reaches the
/// shell the way it does from Home.
SearchEnvironment appSearchEnvironment({required FeedAuthor viewer}) => SearchEnvironment(
  sources: _sources,
  recents: (ctx) => AppConfig.demo ? MemoryRecentStore() : SecureRecentStore(userId: viewer.id),
  openers: {
    SearchKind.person: (ctx, hit) => openMemberProfile(ctx, hit.id),
    SearchKind.job: (ctx, hit) => showJobSheet(ctx, hit.payload as Job),
    SearchKind.mentor: (ctx, hit) => openMentorProfile(ctx, hit.id),
    SearchKind.course: (ctx, hit) => _openCourse(ctx, hit.payload as Course),
    SearchKind.supplier: (ctx, hit) =>
        showSupplierSheetById(ctx, hit.id, navigation: appMarketplaceNavigation(ctx)),
    SearchKind.event: (ctx, hit) => openEventBySlug(ctx, hit.slug ?? hit.id),
    SearchKind.discussion: (ctx, hit) => _openThread(ctx, hit.payload as FeedPost, viewer),
    SearchKind.document: (ctx, hit) => _openDocument(ctx, hit.payload as LibraryDocument),
  },
  features: _features(viewer),
);

/// A mentor's profile over whatever asked for it.
Future<void> openMentorProfile(BuildContext context, String mentorId) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (route) => mentorProfileRoute(route, mentorId)));

// --- the sources -------------------------------------------------------------

/// The repository a tab already holds when the search was opened from inside
/// the shell, else one of its own.
T _held<T>(BuildContext ctx, T Function(BuildContext) read, T Function() make) {
  try {
    return read(ctx);
  } catch (_) {
    return make();
  }
}

List<SearchSource> _sources(BuildContext ctx) {
  final api = ctx.read<ApiClient>();
  final demo = AppConfig.demo;
  return repositorySources(
    messaging: demo ? DemoMessagingRepository() : ApiMessagingRepository(api: api),
    jobs: _held<JobsRepository>(
      ctx,
      (c) => c.read<JobsController>().repository,
      () => demo ? DemoJobsRepository() : ApiJobsRepository(api: api),
    ),
    mentorship: _held<MentorshipRepository>(
      ctx,
      (c) => c.read<MentorshipController>().repository,
      () => demo ? DemoMentorshipRepository() : ApiMentorshipRepository(api: api),
    ),
    learning: _learning(api),
    marketplace: _held<MarketplaceRepository>(
      ctx,
      (c) => c.read<MarketplaceController>().repository,
      () => demo ? DemoMarketplaceRepository() : ApiMarketplaceRepository(api: api),
    ),
    events: _events(api),
    feed: _held<FeedRepository>(
      ctx,
      (c) => c.read<FeedController>().repository,
      () => demo ? DemoFeedRepository() : ApiFeedRepository(api: api, viewerId: null),
    ),
    library: _library(api),
  );
}

LearningRepository _learning(ApiClient api) => AppConfig.demo ? DemoLearningRepository() : ApiLearningRepository(api: api);
EventsRepository _events(ApiClient api) => AppConfig.demo ? DemoEventsRepository() : ApiEventsRepository(api: api);
LibraryRepository _library(ApiClient api) => AppConfig.demo ? DemoLibraryRepository() : ApiLibraryRepository(api: api);

// --- the records -------------------------------------------------------------

/// A course's sheet. `showCourseSheet` reads the Learning list's controller,
/// which a search does not have, so this is the same sheet without the list.
Future<void> _openCourse(BuildContext ctx, Course course) async {
  final controller = CourseSheetController(repository: _learning(ctx.read<ApiClient>()), seed: course)..load();
  await showDetailSheet<void>(
    ctx,
    body: (_) => ChangeNotifierProvider.value(value: controller, child: const CourseSheetBody()),
    bottomBar: (_) => ChangeNotifierProvider.value(value: controller, child: const CourseSheetBar()),
  );
  controller.dispose();
}

/// A discussion's page, as Home opens one.
Future<void> _openThread(BuildContext ctx, FeedPost post, FeedAuthor viewer) async {
  final feed = ctx.read<FeedController>();
  await openThreadPage(
    ctx,
    repository: feed.repository.forum,
    viewer: viewer,
    slug: post.slug,
    preview: post,
    unread: feed.unread,
    callbacks: ForumCallbacks(
      onBell: () => openNotifications(ctx),
      onOpenMember: (id) => openMemberProfile(ctx, id),
    ),
  );
}

Future<void> _openDocument(BuildContext ctx, LibraryDocument doc) =>
    openDocumentPage(ctx, repository: _library(ctx.read<ApiClient>()), documentId: doc.id, initial: doc);

// --- the places in the app ---------------------------------------------------

/// Every catalogue id the app can open. An id left out is not offered.
Map<String, FeatureOpener> _features(FeedAuthor viewer) {
  FeatureOpener tab(AppTab t) =>
      (ctx) async => AppShell.goToTab(ctx, t);

  /// A page the app already has a screen for, by the website path the rest of
  /// the app maps (`inAppSiteRoute`).
  FeatureOpener path(String p) => (ctx) async {
    final open = inAppSiteRoute(Uri.parse(p), viewer: viewer);
    if (open != null) await open(ctx);
  };

  FeatureOpener learning(LearningPageBuilder Function(LearningRoutes r) pick) =>
      (ctx) => pushLearningPage<void>(ctx, pick(const LearningRoutes()));

  return {
    'home': tab(AppTab.home),
    'jobs': tab(AppTab.jobs),
    'learning': tab(AppTab.learning),
    'mentorship': tab(AppTab.mentorship),
    'marketplace': tab(AppTab.marketplace),
    'forums': tab(AppTab.forums),

    'assess': learning((r) => r.assessment),
    'mock': learning((r) => r.mockTests),
    'flash': learning((r) => r.flashCards),
    'knowledge': learning((r) => r.knowledgeCenter),
    'attempts': learning((r) => r.myAttempts),
    'certificates': path('/learning/certificates'),

    'saved_jobs': (ctx) => careerRoutesOf(ctx).savedJobs(),
    'applications': (ctx) => careerRoutesOf(ctx).applications(),
    'job_alerts': (ctx) => careerRoutesOf(ctx).alerts(),
    'interviews': (ctx) => careerRoutesOf(ctx).interviews(),
    'career': (ctx) => careerRoutesOf(ctx).hub(),
    'posted_jobs': (ctx) async {
      if (ctx.read<JobsController>().canHire) return hiringRoutesOf(ctx).jobs();
      showMessage(ctx, 'Posting jobs starts with a company. Create one and invite your hiring team.');
      return AppShell.push<void>(ctx, (c) => CreateCompanyScreen());
    },

    'find_mentors': (ctx) => openFindMentors(ctx, onOpenMentor: (c, id) => openMentorProfile(c, id)),
    'become_mentor': (ctx) => openBecomeMentor(ctx),
    'my_mentoring': (ctx) => openMyMentoring(ctx),
    'mentor_desk': (ctx) => openMentorDesk(ctx),
    'programmes': (ctx) => openProgrammes(ctx, onBecomeMentor: (c) => openBecomeMentor(c)),
    'group_sessions': (ctx) => openGroupSessions(ctx),

    'post_rfq': path('/rfq/new'),
    'my_rfqs': path('/manage/requirements'),
    'rfq_alerts': (ctx) => pushAlerts(ctx, appRfqHooks(ctx)),
    'create_company': path('/account/companies/new?role=COMPANY_ADMIN'),

    'events': path('/events'),
    'councils': path('/councils'),
    'chapters': path('/chapters'),
    'library': path('/documents'),
    'get_involved': path('/get-involved'),

    'profile': path('/profile'),
    'settings': path('/profile?tab=security'),
    'saved': path('/career/saved'),
    'plans': path('/pricing'),
    'plan_history': path('/membership/history'),
    'notifications': (ctx) => openNotifications(ctx),
    'messages': (ctx) => MessagingLauncher.openInbox(ctx),
  };
}
