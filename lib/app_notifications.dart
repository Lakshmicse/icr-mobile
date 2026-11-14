import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_records.dart';
import 'app_screens.dart';
import 'app_search.dart' show openMentorProfile;
import 'features/account/companies/create_company_screen.dart';
import 'features/account/profile/my_profile_screen.dart' show ProfileSection;
import 'features/account/widgets/account_session.dart' show maybeAuth;
import 'features/workspaces/workspaces.dart' show isStaff;
import 'features/become_mentor/become_mentor_screen.dart';
import 'features/career/career_routes.dart';
import 'features/career/company_insights_controller.dart' show InsightsTab;
import 'features/career/company_insights_screen.dart' show openCompanyInsightsById;
import 'features/feed/feed_controller.dart';
import 'features/feed/feed_models.dart';
import 'features/forum/forum_callbacks.dart';
import 'features/forum/thread_screen.dart';
import 'features/jobs/employer/applicant_detail_screen.dart';
import 'features/jobs/employer/hiring_routes.dart';
import 'features/jobs/job_detail_sheet.dart';
import 'features/jobs/jobs_controller.dart';
import 'features/jobs/jobs_navigation.dart';
import 'features/learning_assess/assess_models.dart' show PaperKind;
import 'features/learning_assess/open_group.dart';
import 'features/learning_hub/learning_doors.dart';
import 'features/marketplace/catalog_pages.dart' show showProductPage;
import 'features/membership/membership_models.dart' show MembershipAudience;
import 'features/mentor_desk/mentor_desk_controller.dart' show DeskTab;
import 'features/mentor_desk/mentor_desk_screen.dart';
import 'features/mentorship/find_mentors_screen.dart';
import 'features/mentorship_my/certificate_check.dart' show showMentoringCertificateCheck;
import 'features/mentorship_my/group_sessions_screen.dart';
import 'features/mentorship_my/my_mentoring_controller.dart' show MyTab;
import 'features/mentorship_my/my_mentoring_screen.dart';
import 'features/mentorship_my/pairing_screen.dart';
import 'features/mentorship_my/programmes_screen.dart';
import 'features/messaging/messaging_launcher.dart';
import 'features/notifications/notification_router.dart';
import 'features/notifications/notification_seen.dart';
import 'features/notifications/notification_target.dart';
import 'features/notifications/notifications_screen.dart' show openNotifications;
import 'features/shell/app_shell.dart';
import 'features/shell/icr_bottom_nav.dart' show AppTab;
import 'features/site/blog_screens.dart' show openBlogPost, openBlogs;
import 'features/support/support_routes.dart' show openSupport, openSupportTicket;

/// The kinds [appNotificationOpeners] registers: each opens the app's own screen for its record. (The router has
/// three more built in: `conversation`, `messaging`, `notifications`; and the staff consoles open nothing.)
/// `test/notification_openers_test.dart` keeps this equal to the map's keys.
const appNotificationKinds = <String>{
  NotificationKinds.job,
  NotificationKinds.jobEdit,
  NotificationKinds.applicationEmployer,
  NotificationKinds.interviewPanel,
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
  NotificationKinds.adminLearning,
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
  NotificationKinds.team,
  NotificationKinds.supportTicket,
  NotificationKinds.support,
};

/// The ICR pages the app has no screen for: a tap opens the website's page in the app's web view, signed in
/// (never the phone's browser). `docs/NOTIFICATION_TARGETS.md` says why for each.
const notificationKindsInWebView = <String>{
  NotificationKinds.talentSearch,
  NotificationKinds.learningTeaching,
  NotificationKinds.teamInvite,
  NotificationKinds.companyWorkspace,
  NotificationKinds.articlesMine,
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

  /// [site] with the options the notification's page carried (`?tab=requests`, `?focus=invitations`): only the
  /// [keys] it named, so the screen opens where the website's page does.
  NotificationOpener siteWith(String path, List<String> keys) => plain((ctx, t) {
    final query = {
      for (final key in keys)
        if (t[key] != null) key: t[key]!,
    };
    final open = inAppSiteRoute(
      Uri(path: path, queryParameters: query.isEmpty ? null : query),
      viewer: viewer,
      shell: shell,
    );
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
    // The job's applicants; with `?applicant=` that applicant's page over them, as the website opens the drawer on
    // the job's pipeline.
    NotificationKinds.applicationEmployer: withId('jobId', (ctx, id, t) {
      final applicationId = t['applicationId'];
      if (applicationId == null) {
        unawaited(hiring().applicants(id));
      } else {
        unawaited(_openApplicant(ctx, hiring(), id, applicationId));
      }
    }),
    // The panel's page for the round, as the website's `/manage/interviews/:id` (it was that page in a web view
    // until 4 Nov 2026). Opening it reads every notification about the round, as the website's page does.
    NotificationKinds.interviewPanel: withId(
      'interviewId',
      (ctx, id, t) => unawaited(
        hiring().interview(
          id,
          onOpened: (c) => unawaited(markNotificationsSeen(c, NotificationKinds.interviewPanel, id)),
        ),
      ),
    ),
    NotificationKinds.applicationCandidate: withId(
      'applicationId',
      (ctx, id, t) => openRecord(ctx, () => careerRepositoryOf(shell).application(id), (app) {
        // Every stage move and interview told about this application is read once it is open.
        _seen(ctx, NotificationKinds.applicationCandidate, id);
        return career().application(app);
      }),
    ),
    NotificationKinds.jobAlert: plain((ctx, t) => unawaited(career().alerts())),
    NotificationKinds.career: plain((ctx, t) => unawaited(career().hub())),
    // On the tab the link names (`?tab=reviews|interviews|jobs|people`), as the website's page opens on it.
    NotificationKinds.companyPage: withId(
      'companyId',
      (ctx, id, t) => unawaited(
        openCompanyInsightsById(shell, companyId: id, jobs: jobs().repository, tab: insightsTabOf(t['tab'])),
      ),
    ),

    // --- Requirements, enquiries and bids ------------------------------------------------------------------
    NotificationKinds.rfqOwner: withId(
      'rfqId',
      (ctx, id, t) => openRfqRecord(ctx, id, owner: true, section: t['section'], bidId: t['bidId']),
    ),
    NotificationKinds.rfqSupplier: withId(
      'rfqId',
      (ctx, id, t) => openRfqRecord(ctx, id, owner: false, section: t['section']),
    ),
    NotificationKinds.rfqPublic: withId(
      'rfqId',
      (ctx, id, t) => openRfqRecord(ctx, id, owner: false, section: t['section']),
    ),
    NotificationKinds.product: withId(
      'productId',
      (ctx, id, t) => unawaited(quietly(ctx, () => showProductPage(shell, id))),
    ),

    // --- The partner institute's console ------------------------------------------------------------------
    // Its enquiries (`/admin/learning/enquiries?lead=`) are the app's own list since 7 Nov 2026, opened on the one
    // the row is about (the owner's tap on "New enquiry about CSF" was told "staff tools"). The console's other
    // sections are still the website's staff pages, which the app does not draw.
    NotificationKinds.adminLearning: (ctx, t) {
      final section = t['section'];
      if (section == 'enquiries') {
        unawaited(openPartnerEnquiries(ctx, focusId: t['leadId']));
        return true;
      }
      // The rest of the partner institute's console: a course's review decision (no section), its batches and its
      // enrolments. ICR's own Learning Center (and its other sections) is a staff console the app does not have.
      final user = maybeAuth(ctx)?.user;
      final institute = user != null && (!isStaff(user) || user.role == 'PARTNER_ADMIN');
      if (!institute) return NotificationRouter.staffOnly(ctx);
      switch (section) {
        case null:
        case 'courses':
          unawaited(openPartnerCourses(ctx));
          return true;
        case 'batches':
          unawaited(openPartnerBatches(ctx, courseId: t['courseId']));
          return true;
        case 'enrolments':
          unawaited(openPartnerEnrolments(ctx, courseId: t['courseId']));
          return true;
      }
      return NotificationRouter.staffOnly(ctx);
    },

    // --- Mentorship ----------------------------------------------------------------------------------------
    NotificationKinds.mentorshipPairing: withId('mentorshipId', (ctx, id, t) {
      _seen(ctx, NotificationKinds.mentorshipPairing, id);
      unawaited(openPairing(ctx, id));
    }),
    NotificationKinds.mentorshipGroupSession: withId('sessionId', (ctx, id, t) {
      _seen(ctx, NotificationKinds.mentorshipGroupSession, id);
      unawaited(openGroupSession(ctx, id));
    }),
    NotificationKinds.mentorshipProgramme: withId('slug', (ctx, id, t) => unawaited(openProgramme(ctx, id))),
    NotificationKinds.mentorshipMine: plain((ctx, t) => unawaited(openMyMentoring(ctx, tab: _myTab(t['tab'])))),
    // The certificate's own page (the website's public `/mentorship/certificates/:id`: valid, whose, for what, when),
    // the app's sheet since 4 Nov 2026; the certificates list when the link names none.
    NotificationKinds.mentorshipCertificate: (ctx, t) {
      final id = t['certificateId'];
      if (id == null) {
        unawaited(openMyMentoring(ctx, tab: MyTab.certificates));
      } else {
        unawaited(showMentoringCertificateCheck(ctx, id));
      }
      return true;
    },
    // A bought 1:1 opens on the buyer's purchases; one sold, on the mentor's desk's work board.
    NotificationKinds.mentorPurchase: plain((ctx, t) {
      _seen(ctx, NotificationKinds.mentorPurchase, t['purchaseId']);
      if (t['side'] == 'seller') {
        unawaited(openMentorDesk(ctx, tab: DeskTab.work));
      } else {
        unawaited(openMyMentoring(ctx, tab: MyTab.purchases));
      }
    }),
    // On the tab the link names (`?tab=work|sales|services|plans|settings`).
    NotificationKinds.mentorDesk: plain((ctx, t) => unawaited(openMentorDesk(ctx, tab: deskTabOf(t['tab'])))),
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
    // `?apply=1` is the institute application; the page itself is the Learning tab's Partner Courses.
    NotificationKinds.learningPartners: (ctx, t) {
      if (t['apply'] != null) return site('/learning/partners?apply=1')(ctx, t);
      AppShell.goToTab(ctx, AppTab.learning);
      return true;
    },
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
    // "{company} wants you on its team" (`?focus=invitations`) lands on the places waiting for the person.
    NotificationKinds.accountCompanies: siteWith('/account/companies', const ['focus']),
    // The company's team, opened on the tab the link names (`?tab=requests`: someone asked to join).
    NotificationKinds.team: siteWith('/manage/team', const ['tab']),
    // The help desk. A request opens its thread and reads the notifications about it, as the website's page does.
    NotificationKinds.supportTicket: withId('ticketId', (ctx, id, t) {
      unawaited(
        openSupportTicket(
          ctx,
          id,
          onOpened: (c) => unawaited(markNotificationsSeen(c, NotificationKinds.supportTicket, id)),
        ),
      );
    }),
    NotificationKinds.support: plain((ctx, t) => unawaited(openSupport(ctx))),
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
  onCreateCompany: () => AppShell.push<void>(shell, (c) => CreateCompanyScreen.routed(c)),
  onDemonstrateSkills: () => AppShell.goToTab(shell, AppTab.learning),
);

/// Reads whatever else told the person about the record that was just opened (the website's `useMarkSeen`, which its
/// record pages call): the row they tapped is read already, its siblings are read here and the bell follows.
void _seen(BuildContext ctx, String kind, String? id) {
  if (id != null) unawaited(markNotificationsSeen(ctx, kind, id));
}

/// One applicant, as the website opens them in the job's pipeline drawer: the job's applicants underneath (Back lands
/// there), the applicant's page over it. An applicant that cannot be read leaves the pipeline showing, and says so.
Future<void> _openApplicant(BuildContext ctx, HiringRoutes hiring, String jobId, String applicationId) async {
  unawaited(hiring.applicants(jobId));
  await openRecord(ctx, () => hiring.repository.applicant(applicationId), (detail) {
    _seen(ctx, NotificationKinds.applicationEmployer, applicationId);
    return Navigator.of(ctx).push<void>(
      MaterialPageRoute(
        builder: (_) => ApplicantDetailScreen(
          repository: hiring.repository,
          applicant: detail.applicant,
          jobTitle: detail.jobTitle,
          links: hiring.links,
          navigation: hiring.navigation,
          clock: hiring.clock,
        ),
      ),
    );
  });
}

/// The mentor desk tab a website `?tab=` names: its Work board and Sales have the app's Work and Earnings, Services
/// and Plans the Offerings, Mentoring the Mentees; anything else the Overview.
@visibleForTesting
DeskTab deskTabOf(String? tab) => switch (tab) {
  'work' => DeskTab.work,
  'sales' => DeskTab.earnings,
  'services' || 'plans' || 'cohorts' => DeskTab.offerings,
  'mentoring' => DeskTab.mentees,
  'settings' => DeskTab.settings,
  _ => DeskTab.overview,
};

/// A company page's tab (`?tab=`): the website's Overview opens the first.
@visibleForTesting
InsightsTab insightsTabOf(String? tab) => switch (tab) {
  'people' => InsightsTab.people,
  'reviews' => InsightsTab.reviews,
  'salaries' => InsightsTab.salaries,
  'interviews' => InsightsTab.interviews,
  _ => InsightsTab.jobs,
};

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
