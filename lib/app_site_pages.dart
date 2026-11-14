import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_notifications.dart' show appJobsNavigation;
import 'app_community_manage.dart';
import 'app_records.dart';
import 'app_screens.dart';
import 'core/api/api_client.dart';
import 'core/config.dart';
import 'core/util/links.dart' show SiteRouteOpener, showMessage;
import 'features/account/companies/create_company_screen.dart';
import 'features/account/companies/my_companies_screen.dart';
import 'features/career/application_logic.dart' show ApplicationsTab;
import 'features/career/career_routes.dart' show CareerRoutes, careerRepositoryOf, careerRoutesOf;
import 'features/career/company_insights_controller.dart' show InsightsTab;
import 'features/chapters/api_chapters_repository.dart';
import 'features/chapters/chapter_screen.dart' show ChapterHandoffs, openChapterPage;
import 'features/chapters/demo_chapters_repository.dart';
import 'features/contact/contact_screen.dart' show contactRoute;
import 'features/councils/api_councils_repository.dart';
import 'features/councils/council_screen.dart' show openCouncilPage;
import 'features/councils/demo_councils_repository.dart';
import 'features/feed/feed_models.dart';
import 'features/jobs/employer/hiring_routes.dart';
import 'features/jobs/jobs_controller.dart';
import 'features/learning_exam/api_exam_repository.dart';
import 'features/learning_exam/certificate_view.dart' show showCertificateSheet;
import 'features/learning_exam/demo_exam_repository.dart';
import 'features/learning_exam/exam_repository.dart' show ExamRepository;
import 'features/learning_exam/verify_sheet.dart' show showVerifySheet;
import 'features/learning_assess/assess_models.dart' show PaperKind;
import 'features/learning_assess/open_group.dart';
import 'features/learning_hub/learning_doors.dart';
import 'features/marketplace/catalog_pages.dart' show showProductPage;
import 'features/mentor_desk/mentor_desk_screen.dart';
import 'features/mentorship/find_mentors_screen.dart';
import 'features/mentorship_my/my_mentoring_controller.dart' show MyTab;
import 'features/mentorship_my/my_mentoring_screen.dart';
import 'features/messaging/messaging_launcher.dart';
import 'features/notifications/notification_seen.dart';
import 'features/notifications/notification_target.dart' show NotificationKinds;
import 'features/notifications/notifications_screen.dart' show openNotifications;
import 'features/shell/app_shell.dart';
import 'features/shell/icr_bottom_nav.dart' show AppTab;
import 'features/site/advertise_screen.dart';
import 'features/site/blog_screens.dart';
import 'features/site/legal_page.dart' show legalPages;
import 'features/site/legal_page_screen.dart';
import 'features/site/partner_apply_screen.dart';
import 'features/site/refer_screen.dart';
import 'features/support/support_routes.dart' show openSupportTicket;
import 'features/volunteer/get_involved_screen.dart' show GetInvolvedScreen;
import 'app_search.dart' show openMentorProfile;
import 'features/account/widgets/account_session.dart' show maybeAuth;
import 'features/forum/forums_controller.dart';
import 'features/forum/new_thread_screen.dart' show openComposer;
import 'features/learning_hub/my_courses_screen.dart';
import 'features/learning_hub/partner_courses_screen.dart';
import 'features/site/about_screen.dart';

/// The pages of the ICR website that the app draws itself, beyond the doors and records `inAppSiteRoute` knows:
/// the tabs, a record named by its id (a job, a discussion, a company, a product, a course, a chapter, a
/// requirement), the small pages (the legal ones, the blog, invitations, advertising, the partner application) and
/// the mentoring and hiring screens. Null for a path the app has no screen for: it opens the app's web view then.
/// `docs/WEBSITE_HANDOFFS.md` lists every path and what it opens.
///
/// [shell] is a context below the signed-in app's providers (`JobsController`, `FeedController`,
/// `MarketplaceController`…); a path whose screen needs one is not taken without it.
SiteRouteOpener? appSitePage(Uri uri, String path, {required FeedAuthor viewer, BuildContext? shell}) {
  final parts = path.split('/').where((p) => p.isNotEmpty).toList();
  final q = uri.queryParameters;

  /// "Open this tab": from any route (a sheet, the notifications list), the shell shows it.
  SiteRouteOpener tab(AppTab t) =>
      (ctx) async => AppShell.goToTab(ctx, t);

  // --- The small pages --------------------------------------------------------------------------------------
  final legal = legalPages[path];
  if (legal != null) {
    return (ctx) => AppShell.push<void>(ctx, (c) => LegalPageScreen(page: legal, onBack: () => Navigator.of(c).pop()));
  }
  // The website's About page (Saathi's "About ICR"; Settings' row), the app's own since 7 Nov 2026.
  if (path == '/about') {
    return (ctx) => AppShell.push<void>(
      ctx,
      (c) => AboutScreen(onBack: () => Navigator.of(c).pop(), signedIn: maybeAuth(c)?.user != null),
    );
  }
  // The website's community console (a staff notification's page: a chapter application, a council proposal, a
  // company asking to host events): the app's own manage pages for the staff who run chapters, councils or
  // events, on the tab and the request the link names.
  if (path == '/admin/community') {
    return (ctx) async {
      final open = communityConsoleRoute(ctx, q);
      if (open == null) return showMessage(ctx, 'This page is for the ICR staff who run chapters, councils or events.');
      await open(ctx);
    };
  }
  // The partner institute's enquiries (`?lead=` opens on one), the app's own since 7 Nov 2026.
  if (path == '/admin/learning/enquiries') return (ctx) => openPartnerEnquiries(ctx, focusId: q['lead']);
  // The partner institute's console (the Learning Partner row), the app's own since 12 Nov 2026.
  if (path == '/admin/learning/courses') return (ctx) => openPartnerCourses(ctx);
  if (path == '/admin/learning/batches') return (ctx) => openPartnerBatches(ctx, courseId: q['course']);
  if (path == '/admin/learning/enrolments') return (ctx) => openPartnerEnrolments(ctx, courseId: q['course']);
  // The partner institutes (the Learning hub's door) and the learner's own courses (`/learning/courses` is the
  // website's My courses), so a link to either stays in the app.
  if (path == '/learning/partners' && q['apply'] != '1') {
    return (ctx) => AppShell.push<void>(ctx, (c) => PartnerCoursesScreen(onBack: () => Navigator.of(c).pop()));
  }
  if (path == '/learning/courses') {
    return (ctx) => AppShell.push<void>(ctx, (c) => MyCoursesScreen(onBack: () => Navigator.of(c).pop()));
  }
  if (shell != null) {
    // "Post a job" (`/manage/jobs/new`): the composer, or what a member who cannot post is told.
    if (path == '/manage/jobs/new') return (ctx) => openPostJob(shell, navigation: appJobsNavigation(shell));
    // "Start a discussion" (`/community/new`): the forum's composer.
    if (path == '/community/new') {
      return (ctx) async {
        await openComposer(ctx, repository: shell.read<ForumsController>().repository);
      };
    }
  }
  if (path == '/blogs') return (ctx) => openBlogs(ctx);
  if (parts.length == 2 && parts[0] == 'blogs') return (ctx) => openBlogPost(ctx, parts[1]);
  if (path == '/refer' || path == '/refer/credits') return (ctx) => openRefer(ctx);
  if (path == '/advertise') {
    return (ctx) => AppShell.push<void>(
      ctx,
      (c) => AdvertiseScreen(
        onBack: () => Navigator.of(c).pop(),
        onTalk: (subject) => Navigator.of(c).push<void>(
          MaterialPageRoute(
            builder: (r) => contactRoute(r, subject: subject, onBell: () => openNotifications(r)),
          ),
        ),
      ),
    );
  }
  if (path == '/learning/partners/apply' || (path == '/learning/partners' && q['apply'] == '1')) {
    return (ctx) => AppShell.push<void>(
      ctx,
      (c) => PartnerApplyScreen(
        onBack: () => Navigator.of(c).pop(),
        onCreateCompany: () => AppShell.push<void>(c, (r) => CreateCompanyScreen.routed(r)),
      ),
    );
  }
  // `?focus=invitations` ("{company} wants you on its team") brings the places waiting for the person into view.
  if (path == '/account/companies') {
    return (ctx) => AppShell.push<void>(
      ctx,
      (c) => MyCompaniesScreen(
        onBack: () => Navigator.of(c).pop(),
        onOpenCompany: shell == null ? null : (id) => unawaited(openCompanyById(shell, id)),
        focusInvitations: q['focus'] == 'invitations',
      ),
    );
  }
  // One help request's thread (`/support/<id>`; opening it reads the notifications about it, as the website's page
  // does). The list (`/support`) and the company's team (`/manage/team`) are `inAppScreens`. Native since 5 Nov 2026.
  if (parts.length == 2 && parts[0] == 'support') {
    return (ctx) => openSupportTicket(
      ctx,
      parts[1],
      onOpened: (c) => unawaited(markNotificationsSeen(c, NotificationKinds.supportTicket, parts[1])),
    );
  }

  // --- The tabs ---------------------------------------------------------------------------------------------
  switch (path) {
    case '/':
    case '/dashboard':
      return tab(AppTab.home);
    case '/jobs':
      return (ctx) async {
        AppShell.goToTab(ctx, AppTab.jobs);
        final search = q['q'] ?? q['search'];
        if (search != null && shell != null) shell.read<JobsController>().setSearch(search);
      };
    case '/learning':
    case '/learning/professional-development':
      return tab(AppTab.learning);
    case '/mentorship':
      return tab(AppTab.mentorship);
    case '/community':
      return tab(AppTab.forums);
    case '/vendors':
    case '/services':
    case '/products':
      // `/rfq` is not here: it is the app's Requirements board (`inAppScreens`), found before this is asked.
      return tab(AppTab.marketplace);
  }

  // --- Career (the candidate's side: `/career/...`) ----------------------------------------------------------
  // The application page is where every stage move, interview and offer lands (`application.candidate`
  // notifications, "Your application" links): always the app's own screen, never the website's.
  if (parts.isNotEmpty && parts[0] == 'career' && shell != null) {
    // Built when tapped, not when the path is looked at: the routes read the shell's providers.
    CareerRoutes career() => careerRoutesOf(shell, navigation: appJobsNavigation(shell));
    if (parts.length == 1) return (ctx) => career().hub();
    if (parts[1] == 'applications') {
      if (parts.length == 2) return (ctx) => career().applications(tab: _applicationsTab(q['tab']));
      if (parts.length == 3) {
        final id = parts[2];
        return (ctx) =>
            openRecord(ctx, () => careerRepositoryOf(shell).application(id), (app) => career().application(app));
      }
    }
    if (parts.length == 2) {
      switch (parts[1]) {
        case 'saved':
          return (ctx) => career().savedJobs();
        case 'alerts':
          return (ctx) => career().alerts();
        case 'invitations':
          return (ctx) => career().invitations();
        case 'interviews':
          return (ctx) => career().interviews();
      }
    }
  }

  // --- Learning ---------------------------------------------------------------------------------------------
  // A programme (`/learning/assessment/<code>`, and a level of it `/<code>/<slug>`) and a mock exam subject
  // (`/learning/mock-tests/<subject>[/<set>]`): their own pages, where a level or set is opened, bought or sat.
  if (parts.length == 2 && parts[0] == 'learning' && parts[1] == 'assessment') {
    return (ctx) => pushLearningPage<void>(ctx, const LearningRoutes().assessment);
  }
  if (parts.length >= 3 && parts.length <= 4 && parts[0] == 'learning' && parts[1] == 'assessment') {
    return (ctx) => openPaperGroup(ctx, PaperKind.assessment, parts[2]);
  }
  if (parts.length == 2 && parts[0] == 'learning' && parts[1] == 'mock-tests') {
    return (ctx) => pushLearningPage<void>(ctx, const LearningRoutes().mockTests);
  }
  if (parts.length >= 3 && parts.length <= 4 && parts[0] == 'learning' && parts[1] == 'mock-tests') {
    return (ctx) => openPaperGroup(ctx, PaperKind.mock, parts[2]);
  }
  if (parts.length == 3 && parts[0] == 'learning' && parts[1] == 'professional-development') {
    return (ctx) async => openCourseByCode(ctx, parts[2]);
  }
  if (path == '/learning/verify') {
    return (ctx) => showVerifySheet(ctx, _examRepository(ctx), initial: q['id'] ?? q['code'] ?? '');
  }
  if (parts.length == 3 && parts[0] == 'learning' && parts[1] == 'certificates') {
    return (ctx) {
      final repo = _examRepository(ctx);
      return openRecord(
        ctx,
        () async => (await repo.verifyCertificate(parts[2]))!,
        (cert) => showCertificateSheet(ctx, cert),
      );
    };
  }

  // --- Mentoring --------------------------------------------------------------------------------------------
  if (path == '/mentorship/mentors') {
    return (ctx) => openFindMentors(
      ctx,
      category: q['category'],
      search: q['q'] ?? '',
      onOpenMentor: (c, id) => openMentorProfile(c, id),
    );
  }
  if (path == '/mentorship/my') return (ctx) => openMyMentoring(ctx, tab: _myTab(q['tab']));
  if (path == '/mentorship/mentor-desk' || path == '/mentorship/desk') return (ctx) => openMentorDesk(ctx);
  if (path == '/mentorship/cpd') {
    return (ctx) => AppShell.push<void>(
      ctx,
      (c) => GetInvolvedScreen(onBack: () => Navigator.of(c).pop(), onBell: () => openNotifications(c)),
    );
  }

  // --- Records, by id ----------------------------------------------------------------------------------------
  if (parts.length == 2) {
    switch (parts[0]) {
      case 'jobs':
        if (shell != null) return (ctx) => openJobById(shell, ctx, parts[1]);
      case 'community':
        if (shell != null && parts[1] != 'category') {
          return (ctx) => openThreadBySlug(shell, ctx, viewer, parts[1], replyId: q['reply']);
        }
      case 'companies':
        if (shell != null) return (ctx) => openCompanyById(shell, parts[1], tab: _insightsTab(q['tab']));
      case 'products':
        if (shell != null) return (ctx) => quietly(ctx, () => showProductPage(shell, parts[1]));
      case 'chapters':
        return (ctx) => _openChapter(ctx, parts[1]);
      case 'councils':
        // A council's own page is native since 2 Nov 2026 (`council_screen.dart`: overview, events, leadership,
        // members, knowledge, updates; `?tab=` opens on one). Until then the app had no page per council, so this
        // opened the councils directory, and a joined card, its Meeting link and Manage all looked like the same
        // screen (the owner's report).
        return (ctx) => _openCouncil(ctx, parts[1], tab: q['tab']);
      case 'rfq':
        return (ctx) async => openRfqRecord(ctx, parts[1], owner: false, section: q['section']);
    }
  }
  // A sourcing project's page (`/manage/projects/<id>`), the app's own since 12 Nov 2026.
  if (parts.length == 3 && parts[0] == 'manage' && parts[1] == 'projects') {
    return (ctx) => openProjectById(ctx, parts[2]);
  }
  if (parts.length >= 2 && parts[0] == 'manage' && parts[1] == 'requirements' && parts.length == 3) {
    return (ctx) async => openRfqRecord(ctx, parts[2], owner: true, section: q['section'], bidId: q['bid']);
  }

  // --- Hiring ------------------------------------------------------------------------------------------------
  if (shell != null && parts.isNotEmpty && parts[0] == 'manage' && parts.length >= 2 && parts[1] == 'jobs') {
    HiringRoutes hiring() => hiringRoutesOf(shell, navigation: appJobsNavigation(shell));
    if (parts.length == 2) return (ctx) => hiring().jobs();
    // The website's page gates the composer on a company to post for (`NoCompany`); so does the app's.
    if (parts.length == 3 && parts[2] == 'new') {
      return (ctx) => openPostJob(shell, navigation: appJobsNavigation(shell));
    }
    if (parts.length == 3) return (ctx) => hiring().editJob(parts[2]);
    if (parts.length == 4 && parts[3] == 'edit') return (ctx) => hiring().editJob(parts[2]);
    if (parts.length == 4 && parts[3] == 'applicants') return (ctx) => hiring().applicants(parts[2]);
  }
  // An interview's page for its panel (`/manage/interviews/<id>`): the app's own since 4 Nov 2026. Opening it reads
  // what told the person about the round, as the website's page does (`useMarkSeen`).
  if (shell != null && parts.length == 3 && parts[0] == 'manage' && parts[1] == 'interviews') {
    return (ctx) => hiringRoutesOf(shell, navigation: appJobsNavigation(shell)).interview(
      parts[2],
      onOpened: (c) => unawaited(markNotificationsSeen(c, NotificationKinds.interviewPanel, parts[2])),
    );
  }
  return null;
}

InsightsTab _insightsTab(String? name) {
  for (final t in InsightsTab.values) {
    if (t.name == name) return t;
  }
  return InsightsTab.jobs;
}

MyTab _myTab(String? name) {
  for (final t in MyTab.values) {
    if (t.name == name) return t;
  }
  return MyTab.mentoring;
}

ExamRepository _examRepository(BuildContext ctx) =>
    AppConfig.demo ? DemoExamRepository() : ApiExamRepository(api: ctx.read<ApiClient>());

/// A chapter's page by its slug or id, with the hand-overs the Chapters screen gives it.
Future<void> _openChapter(BuildContext ctx, String idOrSlug) => openChapterPage(
  ctx,
  repository: AppConfig.demo ? DemoChaptersRepository() : ApiChaptersRepository(api: ctx.read<ApiClient>()),
  idOrSlug: idOrSlug,
  handoffs: ChapterHandoffs(
    onOpenEvent: (slugOrId) => openEventBySlug(ctx, slugOrId),
    onOpenVolunteer: (chapter) => AppShell.push<void>(ctx, (c) => getInvolvedScreen(c, chapter: chapter)),
    onBell: () => openNotifications(ctx),
    onOpenMember: (id) => openMemberProfile(ctx, id),
    onMessage: (id) => MessagingLauncher.withPerson(ctx, id),
    manage: chapterManageDoor(ctx),
    pageWrap: communityFrame,
  ),
);

/// A council's page by its slug or id, on the website's `?tab=` when it names one, with the hand-overs the
/// Councils board gives it.
Future<void> _openCouncil(BuildContext ctx, String idOrSlug, {String? tab}) => openCouncilPage(
  ctx,
  repository: AppConfig.demo ? DemoCouncilsRepository() : ApiCouncilsRepository(api: ctx.read<ApiClient>()),
  idOrSlug: idOrSlug,
  handoffs: appCouncilHandoffs(ctx),
  tab: tab,
);

/// The tracker's tab a `?tab=` names (`/career/applications?tab=offers`); the first tab otherwise.
ApplicationsTab? _applicationsTab(String? tab) => switch (tab) {
  'interviews' => ApplicationsTab.interviews,
  'offers' => ApplicationsTab.offers,
  'archived' => ApplicationsTab.archived,
  'all' => ApplicationsTab.all,
  'active' => ApplicationsTab.active,
  _ => null,
};
