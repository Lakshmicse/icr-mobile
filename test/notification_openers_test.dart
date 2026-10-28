import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/app_notifications.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart';
import 'package:icr_mobile/features/feed/feed_controller.dart';
import 'package:icr_mobile/features/forum/thread_screen.dart';
import 'package:icr_mobile/features/jobs/demo_jobs_repository.dart';
import 'package:icr_mobile/features/jobs/job_models.dart';
import 'package:icr_mobile/features/jobs/jobs_controller.dart';
import 'package:icr_mobile/features/notifications/notification_router.dart';
import 'package:icr_mobile/features/notifications/notification_target.dart';
import 'package:icr_mobile/features/notifications/notifications_screen.dart';
import 'package:icr_mobile/features/notifications/unread_counts.dart';
import 'package:provider/provider.dart';

import 'helpers/fonts.dart';
import 'notifications_fakes.dart';

/// Every kind of notification, and where a tap on it goes: the app's own screen (an opener registered by
/// `appNotificationOpeners`, or one the router has built in), nothing (the staff consoles), or the website's page in
/// the app's web view. `docs/NOTIFICATION_TARGETS.md` is this table in words; the test fails when a kind is added to
/// the API's list and not placed here.
void main() {
  setUpAll(loadAppFonts);

  /// One page of the website for each kind, as the API stores it.
  const hrefs = <String, String>{
    NotificationKinds.job: '/jobs/j1',
    NotificationKinds.jobEdit: '/manage/jobs/j1/edit',
    NotificationKinds.applicationEmployer: '/manage/jobs/j1/pipeline?applicant=a1',
    NotificationKinds.applicationCandidate: '/career/applications/a1',
    NotificationKinds.interviewPanel: '/manage/interviews/i1',
    NotificationKinds.jobAlert: '/career/alerts?search=s1',
    NotificationKinds.talentSearch: '/talent?savedSearch=s1',
    NotificationKinds.career: '/career',
    NotificationKinds.adminJobReview: '/admin/jobs/review?job=j1',
    NotificationKinds.team: '/manage/team?tab=requests',
    NotificationKinds.teamInvite: '/invite/tok',
    NotificationKinds.accountCompanies: '/account/companies',
    NotificationKinds.companyPage: '/companies/c1',
    NotificationKinds.companyWorkspace: '/company?tab=verification',
    NotificationKinds.adminVerificationSupplier: '/admin/verification?vendor=v1',
    NotificationKinds.adminVerificationCompany: '/admin/verification?view=kyc',
    NotificationKinds.adminCompany: '/admin/companies/c1',
    NotificationKinds.rfqOwner: '/manage/requirements/r1',
    NotificationKinds.rfqSupplier: '/manage/bids/r1',
    NotificationKinds.rfqPublic: '/rfq/r1',
    NotificationKinds.product: '/products/p1',
    NotificationKinds.mentorshipPairing: '/mentorship/my/m1',
    NotificationKinds.mentorshipMine: '/mentorship/my?tab=purchases',
    NotificationKinds.mentorshipGroupSession: '/mentorship/groups/g1',
    NotificationKinds.mentorshipProgramme: '/mentorship/programmes/prog',
    NotificationKinds.mentorshipCertificate: '/mentorship/certificates/c1',
    NotificationKinds.mentorshipCpd: '/mentorship/cpd',
    NotificationKinds.mentorProfile: '/mentorship/mentors/mp1',
    NotificationKinds.mentorDirectory: '/mentorship/mentors',
    NotificationKinds.mentorApplication: '/mentorship/become-a-mentor',
    NotificationKinds.mentorDesk: '/mentorship/mentor?tab=work',
    NotificationKinds.mentorPurchase: '/mentorship/my/sessions/p1',
    NotificationKinds.adminMentorshipConcern: '/admin/mentorship?concern=c1',
    NotificationKinds.learningAssessment: '/learning/assessment/ABC/paper',
    NotificationKinds.learningCourse: '/learning/professional-development/ABC',
    NotificationKinds.learningWorkspace: '/learning/courses/ABC',
    NotificationKinds.adminLearning: '/admin/learning/courses',
    NotificationKinds.learningPartners: '/learning/partners',
    NotificationKinds.event: '/events/summit',
    NotificationKinds.forumThread: '/community/t1#reply-r1',
    NotificationKinds.forum: '/community',
    NotificationKinds.adminForum: '/admin/forum?tab=reports',
    NotificationKinds.blog: '/blogs/post',
    NotificationKinds.articlesMine: '/manage/articles',
    NotificationKinds.adminBlogs: '/admin/blogs',
    NotificationKinds.member: '/members/u1',
    NotificationKinds.documents: '/documents',
    NotificationKinds.adminDocumentReports: '/admin/documents/reports',
    NotificationKinds.conversation: '/messaging?c=c1',
    NotificationKinds.messaging: '/messaging',
    NotificationKinds.notifications: '/notifications',
    NotificationKinds.adminMessageReports: '/admin/messaging/reports',
    NotificationKinds.profile: '/profile?tab=credentials',
    NotificationKinds.supportTicket: '/support/t1',
    NotificationKinds.adminSupportTicket: '/admin/support?ticket=t1',
    NotificationKinds.support: '/support',
    NotificationKinds.membershipPlans: '/pricing/professional',
    NotificationKinds.membershipHistory: '/membership/history',
    NotificationKinds.adminSubscriptions: '/admin/subscriptions',
    NotificationKinds.refer: '/refer',
    NotificationKinds.advertise: '/advertise',
    NotificationKinds.dashboard: '/dashboard',
    NotificationKinds.adminMarketing: '/marketing',
    NotificationKinds.adminContact: '/admin/contact',
    NotificationKinds.path: '/some/old/page',
  };

  /// The ICR pages with no screen of the app (and the catch-all `path`): their page opens in the app's web view.
  final webViewKinds = {...notificationKindsInWebView, NotificationKinds.path};

  late Map<String, NotificationOpener> openers;

  Future<void> pumpShell(WidgetTester tester, Widget Function(BuildContext shell) home) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<JobsController>(create: (_) => JobsController(DemoJobsRepository())),
            ChangeNotifierProvider<FeedController>(create: (_) => FeedController(DemoFeedRepository())),
          ],
          child: Builder(
            builder: (shell) {
              openers = appNotificationOpeners(shell: shell, viewer: DemoFeedRepository.me);
              return home(shell);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the table of kinds', () {
    testWidgets('every kind the API can send is placed: the app\'s screen, nothing (staff), or the web view', (
      tester,
    ) async {
      await pumpShell(tester, (_) => const SizedBox());
      final inApp = {...openers.keys, ...NotificationRouter.builtInKinds};
      final staff = NotificationRouter.staffKinds;
      for (final kind in NotificationKinds.all) {
        if (kind == NotificationKinds.none) continue;
        final placed = [inApp.contains(kind), staff.contains(kind), webViewKinds.contains(kind)].where((x) => x).length;
        expect(placed, 1, reason: '"$kind" must be in exactly one of: the app\'s screens, staff-only, the web view');
      }
      expect(hrefs.keys.toSet(), NotificationKinds.all.toSet()..remove(NotificationKinds.none));
    });

    testWidgets('each page reads back as its kind', (tester) async {
      for (final e in hrefs.entries) {
        expect(NotificationTarget.parse(e.value).kind, e.key, reason: e.value);
      }
    });

    testWidgets('the counts the docs give: how many kinds open where', (tester) async {
      await pumpShell(tester, (_) => const SizedBox());
      final inApp = {...openers.keys, ...NotificationRouter.builtInKinds};
      expect(openers.keys.toSet(), appNotificationKinds, reason: 'the constant and the map say the same');
      expect(inApp.length, 42, reason: '39 registered openers + the 3 the router has built in');
      expect(NotificationRouter.staffKinds.length, 14);
      expect(webViewKinds.length - 1, 8, reason: 'without the catch-all `path`');
    });
  });

  group('from the list: a tap on a row of each kind reaches the opener for that kind', () {
    testWidgets('every registered kind, tapped on its own row', (tester) async {
      await pumpShell(tester, (_) => const SizedBox());
      final kinds = [...openers.keys];
      final reached = <String>[];
      final router = NotificationRouter(
        openers: {
          for (final kind in kinds)
            kind: (context, t) {
              reached.add(t.kind);
              return true;
            },
        },
      );
      final repo = FakeNotificationsRepository(
        pageSize: 100,
        items: [
          for (final kind in kinds)
            note('n-$kind', title: 'About $kind', type: 'info', link: hrefs[kind], at: DateTime(2026, 10, 25, 9)),
        ],
      );
      tester.view.physicalSize = const Size(390, 12000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final counts = UnreadCounts(_NoSource(), interval: const Duration(hours: 1));
      addTearDown(counts.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<UnreadCounts>.value(value: counts),
            Provider<NotificationRouter>.value(value: router),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: NotificationsScreen(repository: repo, clock: () => DateTime(2026, 10, 25, 15)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final kind in kinds) {
        final row = find.byKey(ValueKey('notification-n-$kind'));
        expect(row, findsOneWidget, reason: kind);
        await tester.ensureVisible(row);
        await tester.tap(row);
        await tester.pump();
        expect(reached.last, kind, reason: 'a tap on a "$kind" row opens the "$kind" opener');
      }
      expect(reached.toSet(), kinds.toSet());
    });

    testWidgets('a kind with no opener goes to the website\'s page in the app, never to nothing', (tester) async {
      await pumpShell(tester, (_) => const Scaffold(body: SizedBox(key: ValueKey('ctx'))));
      final sites = <String>[];
      final router = NotificationRouter(openers: openers, openSite: (context, path) async => sites.add(path));
      final context = tester.element(find.byKey(const ValueKey('ctx')));
      for (final kind in webViewKinds) {
        await router.open(context, NotificationTarget.parse(hrefs[kind]));
      }
      expect(sites, [for (final kind in webViewKinds) hrefs[kind]]);
    });

    testWidgets('a staff-only kind opens nothing and says so; it is not sent to the web view', (tester) async {
      await pumpShell(tester, (_) => const Scaffold(body: SizedBox(key: ValueKey('ctx'))));
      final sites = <String>[];
      final router = NotificationRouter(openers: openers, openSite: (context, path) async => sites.add(path));
      final context = tester.element(find.byKey(const ValueKey('ctx')));
      await router.open(context, NotificationTarget.parse(hrefs[NotificationKinds.adminSubscriptions]));
      await tester.pump();
      expect(sites, isEmpty);
      expect(find.textContaining('staff tools'), findsOneWidget);
    });
  });

  group('opening a record by its id', () {
    Future<void> tapThrough(WidgetTester tester, String href) async {
      late NotificationRouter router;
      await pumpShell(tester, (shell) {
        router = NotificationRouter(openers: openers, openSite: (context, path) async {});
        return Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(shell).push(
                // A pushed route, as the notifications list is: above the providers.
                MaterialPageRoute<void>(
                  builder: (routeContext) => Scaffold(
                    body: Center(
                      child: ElevatedButton(
                        key: const ValueKey('tap'),
                        onPressed: () => router.open(routeContext, NotificationTarget.parse(href)),
                        child: const Text('tap'),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        );
      });
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tap')));
      await tester.pumpAndSettle();
    }

    testWidgets('a job opens its sheet, read through the app\'s own jobs source, from outside the shell\'s providers', (
      tester,
    ) async {
      await tapThrough(tester, '/jobs/anything');
      final title = DemoJobsRepository().detailJob.title;
      expect(find.textContaining(title), findsWidgets);
      expect(find.text('This is no longer available.'), findsNothing);
    });

    testWidgets('a job that cannot be read says so calmly and opens nothing', (tester) async {
      late NotificationRouter router;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<JobsController>(create: (_) => JobsController(_GoneJobs())),
              ChangeNotifierProvider<FeedController>(create: (_) => FeedController(DemoFeedRepository())),
            ],
            child: Builder(
              builder: (shell) {
                router = NotificationRouter(
                  openers: appNotificationOpeners(shell: shell, viewer: DemoFeedRepository.me),
                  openSite: (context, path) async {},
                );
                return Scaffold(
                  body: Builder(
                    builder: (c) => TextButton(
                      key: const ValueKey('tap'),
                      onPressed: () => router.open(c, NotificationTarget.parse('/jobs/deleted')),
                      child: const Text('tap'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('tap')));
      await tester.pumpAndSettle();
      expect(find.text('This is no longer available.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'the spinner is gone');
      expect(find.byType(ThreadScreen), findsNothing);
    });

    testWidgets('a discussion reply opens its thread page', (tester) async {
      await tapThrough(tester, '/community/some-thread#reply-r9');
      expect(find.byType(ThreadScreen), findsOneWidget);
    });
  });
}

class _GoneJobs extends DemoJobsRepository {
  @override
  Future<Job> detail(String id) async => throw StateError('gone');
}

class _NoSource implements UnreadSource {
  @override
  Future<int> notifications() async => 0;

  @override
  Future<int> messages() async => 0;
}
