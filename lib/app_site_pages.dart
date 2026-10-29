import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_notifications.dart' show appJobsNavigation;
import 'app_records.dart';
import 'app_screens.dart';
import 'core/api/api_client.dart';
import 'core/config.dart';
import 'core/util/links.dart' show SiteRouteOpener;
import 'features/account/companies/create_company_screen.dart';
import 'features/account/companies/my_companies_screen.dart';
import 'features/career/application_logic.dart' show ApplicationsTab;
import 'features/career/career_routes.dart' show CareerRoutes, careerRepositoryOf, careerRoutesOf;
import 'features/career/company_insights_controller.dart' show InsightsTab;
import 'features/chapters/api_chapters_repository.dart';
import 'features/chapters/chapter_screen.dart' show ChapterHandoffs, openChapterPage;
import 'features/chapters/demo_chapters_repository.dart';
import 'features/contact/contact_screen.dart' show contactRoute;
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
import 'features/notifications/notifications_screen.dart' show openNotifications;
import 'features/shell/app_shell.dart';
import 'features/shell/icr_bottom_nav.dart' show AppTab;
import 'features/site/advertise_screen.dart';
import 'features/site/blog_screens.dart';
import 'features/site/legal_page.dart' show legalPages;
import 'features/site/legal_page_screen.dart';
import 'features/site/partner_apply_screen.dart';
import 'features/site/refer_screen.dart';
import 'features/volunteer/get_involved_screen.dart' show GetInvolvedScreen;
import 'app_search.dart' show openMentorProfile;

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
        onCreateCompany: () => AppShell.push<void>(c, (r) => CreateCompanyScreen()),
      ),
    );
  }
  if (path == '/account/companies') {
    return (ctx) => AppShell.push<void>(
      ctx,
      (c) => MyCompaniesScreen(
        onBack: () => Navigator.of(c).pop(),
        onOpenCompany: shell == null ? null : (id) => unawaited(openCompanyById(shell, id)),
      ),
    );
  }

  // --- The tabs ---------------------------------------------------------------------------------------------
  switch (path) {
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
    case '/rfq':
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
        // The app has the councils directory, not a page per council: it opens there.
        return (ctx) => AppShell.push<void>(ctx, inAppScreens(viewer: viewer)['/councils']!);
      case 'rfq':
        return (ctx) async => openRfqRecord(ctx, parts[1], owner: false, section: q['section']);
    }
  }
  if (parts.length >= 2 && parts[0] == 'manage' && parts[1] == 'requirements' && parts.length == 3) {
    return (ctx) async => openRfqRecord(ctx, parts[2], owner: true, section: q['section'], bidId: q['bid']);
  }

  // --- Hiring ------------------------------------------------------------------------------------------------
  if (shell != null && parts.isNotEmpty && parts[0] == 'manage' && parts.length >= 2 && parts[1] == 'jobs') {
    HiringRoutes hiring() => hiringRoutesOf(shell, navigation: appJobsNavigation(shell));
    if (parts.length == 2) return (ctx) => hiring().jobs();
    if (parts.length == 3 && parts[2] == 'new') return (ctx) => hiring().postJob();
    if (parts.length == 3) return (ctx) => hiring().editJob(parts[2]);
    if (parts.length == 4 && parts[3] == 'edit') return (ctx) => hiring().editJob(parts[2]);
    if (parts.length == 4 && parts[3] == 'applicants') return (ctx) => hiring().applicants(parts[2]);
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
  ),
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
