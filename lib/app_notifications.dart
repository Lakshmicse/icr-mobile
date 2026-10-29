import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_records.dart';
import 'app_screens.dart';
import 'app_search.dart' show openMentorProfile;
import 'features/account/companies/create_company_screen.dart';
import 'features/account/profile/my_profile_screen.dart' show ProfileSection;
import 'features/become_mentor/become_mentor_screen.dart';
import 'features/career/career_routes.dart';
import 'features/career/company_insights_screen.dart' show openCompanyInsightsById;
import 'features/feed/feed_controller.dart';
import 'features/feed/feed_models.dart';
import 'features/forum/forum_callbacks.dart';
import 'features/forum/thread_screen.dart';
import 'features/jobs/employer/hiring_routes.dart';
import 'features/jobs/job_detail_sheet.dart';
import 'features/jobs/jobs_controller.dart';
import 'features/jobs/jobs_navigation.dart';
import 'features/learning_assess/assess_models.dart' show PaperKind;
import 'features/learning_assess/open_group.dart';
import 'features/learning_hub/learning_doors.dart';
import 'features/marketplace/catalog_pages.dart' show showProductPage;
import 'features/membership/membership_models.dart' show MembershipAudience;
import 'features/mentor_desk/mentor_desk_screen.dart';
import 'features/mentorship/find_mentors_screen.dart';
import 'features/mentorship_my/group_sessions_screen.dart';
import 'features/mentorship_my/my_mentoring_controller.dart' show MyTab;
import 'features/mentorship_my/my_mentoring_screen.dart';
import 'features/mentorship_my/pairing_screen.dart';
import 'features/mentorship_my/programmes_screen.dart';
import 'features/messaging/messaging_launcher.dart';
import 'features/notifications/notification_router.dart';
import 'features/notifications/notification_target.dart';
import 'features/notifications/notifications_screen.dart' show openNotifications;
import 'features/shell/app_shell.dart';
import 'features/shell/icr_bottom_nav.dart' show AppTab;
import 'features/site/blog_screens.dart' show openBlogPost, openBlogs;

/// The kinds [appNotificationOpeners] registers: each opens the app's own screen for its record. (The router has
/// three more built in: `conversation`, `messaging`, `notifications`; and the staff consoles open nothing.)
/// `test/notification_openers_test.dart` keeps this equal to the map's keys.
const appNotificationKinds = <String>{
  NotificationKinds.job,
  NotificationKinds.jobEdit,
  NotificationKinds.applicationEmployer,
  NotificationKinds.applicationCandidate,
  NotificationKinds.jobAlert,
  NotificationKinds.career,
  NotificationKinds.companyPage,
  NotificationKinds.rfqOwner,
  NotificationKinds.rfqSupplier,
  NotificationKinds.rfqPublic,
  NotificationKinds.product,
  NotificationKinds.mentorshipPairing,
  NotificationKinds.mentorshipGroupSession,
  NotificationKinds.mentorshipProgramme,
  NotificationKinds.mentorshipMine,
  NotificationKinds.mentorshipCertificate,
  NotificationKinds.mentorPurchase,
  NotificationKinds.mentorDesk,
  NotificationKinds.mentorApplication,
  NotificationKinds.mentorProfile,
  NotificationKinds.mentorDirectory,
  NotificationKinds.learningAssessment,
  NotificationKinds.learningCourse,
  NotificationKinds.learningWorkspace,
  NotificationKinds.learningPartners,
  NotificationKinds.event,
  NotificationKinds.forumThread,
  NotificationKinds.forum,
  NotificationKinds.member,
  NotificationKinds.documents,
  NotificationKinds.profile,
  NotificationKinds.membershipPlans,
  NotificationKinds.membershipHistory,
  NotificationKinds.dashboard,
  NotificationKinds.accountCompanies,
  NotificationKinds.mentorshipCpd,
  NotificationKinds.blog,
  NotificationKinds.refer,
  NotificationKinds.advertise,
};

/// The ICR pages the app has no screen for: a tap opens the website's page in the app's web view, signed in
/// (never the phone's browser). `docs/NOTIFICATION_TARGETS.md` says why for each.
const notificationKindsInWebView = <String>{
  NotificationKinds.interviewPanel,
  NotificationKinds.talentSearch,
  NotificationKinds.team,
  NotificationKinds.teamInvite,
  NotificationKinds.companyWorkspace,
  NotificationKinds.articlesMine,
  NotificationKinds.supportTicket,
  NotificationKinds.support,
};

/// Where each kind of notification opens, in the app's own screens (`docs/NOTIFICATION_TARGETS.md` lists every
/// kind and what it opens, or why it opens the website's page in the app's web view, or nothing).
///
/// [shell] is a context below the signed-in app's providers (`JobsController`, `FeedController`,
/// `MarketplaceController`…): the notifications list is a pushed route, above them, so an opener reads the
/// providers from [shell] and pushes over the context it was handed. A record that is read by id
/// (`_record`) shows a spinner while it loads and "This is no longer available." when it cannot be read.
Map<String, NotificationOpener> appNotificationOpeners({required BuildContext shell, required FeedAuthor viewer}) {
  JobsController jobs() => shell.read<JobsController>();
  JobsNavigation navigation() => appJobsNavigation(shell);
  CareerRoutes career() => careerRoutesOf(shell, navigation: navigation());
  HiringRoutes hiring() => hiringRoutesOf(shell, navigation: navigation());

  /// The openers that need one id from the page; one without it passes (the web view takes the page).
  NotificationOpener withId(String key, void Function(BuildContext ctx, String id, NotificationTarget t) open) =>
      (ctx, t) {
        final id = t[key];
        if (id == null) return false;
        open(ctx, id, t);
        return true;
      };

  NotificationOpener plain(void Function(BuildContext ctx, NotificationTarget t) open) => (ctx, t) {
    open(ctx, t);
    return true;
  };

  /// A page of the website that the app draws itself: the same opener a link to it would take.
  NotificationOpener site(String path) => plain((ctx, t) {
    final open = inAppSiteRoute(Uri.parse(path), viewer: viewer, shell: shell);
    if (open != null) unawaited(open(ctx));
  });

  return {
    // --- Jobs and hiring -----------------------------------------------------------------------------------
    NotificationKinds.job: withId(
      'jobId',
      (ctx, id, t) => openRecord(
        ctx,
        () => jobs().repository.detail(id),
        (job) => showJobDetail(
          ctx,
          job,
          repository: jobs().repository,
          links: jobs().links,
          navigation: navigation(),
          onChanged: jobs().update,
          onApplied: jobs().applied,
          onHidden: jobs().hidden,
        ),
      ),
    ),
    NotificationKinds.jobEdit: withId('jobId', (ctx, id, t) => unawaited(hiring().editJob(id))),
    NotificationKinds.applicationEmployer: withId('jobId', (ctx, id, t) => unawaited(hiring().applicants(id))),
    NotificationKinds.applicationCandidate: withId(
      'applicationId',
      (ctx, id, t) => openRecord(ctx, () => careerRepositoryOf(shell).application(id), (app) => career().application(app)),
    ),
    NotificationKinds.jobAlert: plain((ctx, t) => unawaited(career().alerts())),
    NotificationKinds.career: plain((ctx, t) => unawaited(career().hub())),
    NotificationKinds.companyPage: withId(
      'companyId',
      (ctx, id, t) => unawaited(openCompanyInsightsById(shell, companyId: id, jobs: jobs().repository)),
    ),

    // --- Requirements, enquiries and bids ------------------------------------------------------------------
    NotificationKinds.rfqOwner: withId('rfqId', (ctx, id, t) => openRfqRecord(ctx, id, owner: true, section: t['section'], bidId: t['bidId'])),
    NotificationKinds.rfqSupplier: withId('rfqId', (ctx, id, t) => openRfqRecord(ctx, id, owner: false, section: t['section'])),
    NotificationKinds.rfqPublic: withId('rfqId', (ctx, id, t) => openRfqRecord(ctx, id, owner: false, section: t['section'])),
    NotificationKinds.product: withId(
      'productId',
      (ctx, id, t) => unawaited(quietly(ctx, () => showProductPage(shell, id))),
    ),

    // --- Mentorship ----------------------------------------------------------------------------------------
    NotificationKinds.mentorshipPairing: withId('mentorshipId', (ctx, id, t) => unawaited(openPairing(ctx, id))),
    NotificationKinds.mentorshipGroupSession: withId('sessionId', (ctx, id, t) => unawaited(openGroupSession(ctx, id))),
    NotificationKinds.mentorshipProgramme: withId('slug', (ctx, id, t) => unawaited(openProgramme(ctx, id))),
    NotificationKinds.mentorshipMine: plain((ctx, t) => unawaited(openMyMentoring(ctx, tab: _myTab(t['tab'])))),
    NotificationKinds.mentorshipCertificate: plain(
      (ctx, t) => unawaited(openMyMentoring(ctx, tab: MyTab.certificates)),
    ),
    // A bought 1:1 opens on the buyer's purchases; one sold, on the mentor's desk.
    NotificationKinds.mentorPurchase: plain((ctx, t) {
      if (t['side'] == 'seller') {
        unawaited(openMentorDesk(ctx));
      } else {
        unawaited(openMyMentoring(ctx, tab: MyTab.purchases));
      }
    }),
    NotificationKinds.mentorDesk: plain((ctx, t) => unawaited(openMentorDesk(ctx))),
    NotificationKinds.mentorApplication: plain((ctx, t) => unawaited(openBecomeMentor(ctx))),
    NotificationKinds.mentorProfile: withId('mentorProfileId', (ctx, id, t) => unawaited(openMentorProfile(ctx, id))),
    NotificationKinds.mentorDirectory: plain(
      (ctx, t) => unawaited(openFindMentors(ctx, onOpenMentor: (c, id) => openMentorProfile(c, id))),
    ),

    // --- Learning, events, community -----------------------------------------------------------------------
    // "You enrolled into AEE CBCP – Level": the programme's own page (levels, plan, credits), not the landing.
    NotificationKinds.learningAssessment: (ctx, t) {
      final code = t['courseCode'];
      if (code == null) {
        unawaited(pushLearningPage<void>(ctx, const LearningRoutes().assessment));
      } else {
        unawaited(openPaperGroup(ctx, PaperKind.assessment, code));
      }
      return true;
    },
    NotificationKinds.learningCourse: withId('code', (ctx, code, t) => openCourseByCode(ctx, code)),
    NotificationKinds.learningWorkspace: withId('code', (ctx, code, t) => openCourseByCode(ctx, code)),
    NotificationKinds.learningPartners: plain((ctx, t) => AppShell.goToTab(ctx, AppTab.learning)),
    NotificationKinds.event: (ctx, t) {
      final id = t['slug'] ?? t['eventId'];
      if (id == null) return false;
      unawaited(openEventBySlug(ctx, id));
      return true;
    },
    NotificationKinds.forumThread: withId('slug', (ctx, slug, t) {
      final feed = shell.read<FeedController>();
      unawaited(
        openThreadPage(
          ctx,
          repository: feed.repository.forum,
          viewer: viewer,
          slug: slug,
          focusReplyId: t['replyId'],
          unread: feed.unread,
          callbacks: ForumCallbacks(
            onBell: () => openNotifications(ctx),
            onOpenMember: (id) => openMemberProfile(ctx, id),
          ),
        ),
      );
    }),
    NotificationKinds.forum: plain((ctx, t) => AppShell.goToTab(ctx, AppTab.forums)),
    NotificationKinds.member: withId('userId', (ctx, id, t) => unawaited(openMemberProfile(ctx, id))),
    NotificationKinds.documents: plain(
      (ctx, t) => unawaited(inAppSiteRoute(Uri.parse('/documents'), viewer: viewer)?.call(ctx)),
    ),

    // --- The person, plans, home ---------------------------------------------------------------------------
    NotificationKinds.profile: plain(
      (ctx, t) => unawaited(openMyProfile(ctx, section: t['tab'] == 'credentials' ? ProfileSection.credentials : null)),
    ),
    NotificationKinds.membershipPlans: plain((ctx, t) => unawaited(openMembership(ctx, audience: _audienceOf(t)))),
    NotificationKinds.membershipHistory: plain(
      (ctx, t) => unawaited(openMembershipHistory(ctx, audience: _audienceOf(t))),
    ),
    NotificationKinds.dashboard: plain((ctx, t) => AppShell.goToTab(ctx, AppTab.home)),

    // --- Pages the app draws itself (`lib/app_site_pages.dart`) --------------------------------------------
    NotificationKinds.accountCompanies: site('/account/companies'),
    NotificationKinds.mentorshipCpd: site('/mentorship/cpd'),
    NotificationKinds.refer: site('/refer'),
    NotificationKinds.advertise: site('/advertise'),
    NotificationKinds.blog: (ctx, t) {
      final slug = t['slug'];
      unawaited(slug == null ? openBlogs(ctx) : openBlogPost(ctx, slug));
      return true;
    },
  };
}

/// The Jobs tab's hand-overs, for a job or a career screen opened from outside it (a notification).
JobsNavigation appJobsNavigation(BuildContext shell) => JobsNavigation(
  onBell: () => openNotifications(shell),
  onOpenConversation: (id) => MessagingLauncher.openConversation(shell, id),
  onOpenProfile: (id) => openMemberProfile(shell, id),
  onEditProfile: () => openMyProfile(shell),
  onOpenCompany: (id) => openCompanyInsightsById(shell, companyId: id, jobs: shell.read<JobsController>().repository),
  onFindJobs: (query) {
    AppShell.goToTab(shell, AppTab.jobs);
    if (query != null) shell.read<JobsController>().setSearch(query);
  },
  onCreateCompany: () => AppShell.push<void>(shell, (c) => CreateCompanyScreen()),
  onDemonstrateSkills: () => AppShell.goToTab(shell, AppTab.learning),
);

MyTab? _myTabOrNull(String? name) {
  if (name == null) return null;
  for (final tab in MyTab.values) {
    if (tab.name == name) return tab;
  }
  return null;
}

/// `/mentorship/my?tab=requests|purchases|reports`: the tab the page names, else the first.
MyTab _myTab(String? name) => _myTabOrNull(name) ?? MyTab.mentoring;

/// The ladder a membership notification names: `?audience=` as the API key, or the plans page's slug.
MembershipAudience? _audienceOf(NotificationTarget t) =>
    MembershipAudience.fromApi(t['audience']) ?? MembershipAudience.fromSlug(t['slug'] ?? t['audience']);
