import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/app_notifications.dart';
import 'package:icr_mobile/app_screens.dart';
import 'package:icr_mobile/features/account/companies/my_companies_screen.dart';
import 'package:icr_mobile/features/account/demo_account_repository.dart';
import 'package:icr_mobile/features/account/settings/settings_screen.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart';
import 'package:icr_mobile/features/feed/feed_controller.dart';
import 'package:icr_mobile/features/jobs/demo_jobs_repository.dart';
import 'package:icr_mobile/features/jobs/jobs_controller.dart';
import 'package:icr_mobile/features/notifications/notification_router.dart';
import 'package:icr_mobile/features/notifications/notification_target.dart';
import 'package:icr_mobile/features/support/support_screen.dart';
import 'package:icr_mobile/features/support/ticket_screen.dart';
import 'package:icr_mobile/features/team/team_screen.dart';
import 'package:icr_mobile/features/web/in_app_web_screen.dart';
import 'package:provider/provider.dart';

import 'helpers/account_harness.dart';
import 'helpers/fonts.dart';

/// The three notification targets that used to open the website in the app's web view (a join request, a help
/// request, a company that added you) open the app's own screens (5 Nov 2026), and so do the links to the same pages.
/// The router is the app's (`appNotificationOpeners`) over a fake API, and each tap goes through a pushed route above
/// the providers, as the notifications list does.
void main() {
  setUpAll(loadAppFonts);

  final company = {
    'companyId': 'co-1',
    'name': 'E2E Test Vendor Co',
    'logoUrl': null,
    'role': 'COMPANY_ADMIN',
    'branchName': null,
    'active': true,
    'hasSupplierListing': true,
    'city': 'Bengaluru',
    'state': 'KA',
    'industry': null,
    'verified': true,
    'joinedAt': '2026-10-06T18:22:05.559Z',
    'memberCount': 6,
    'soleAdmin': false,
    'pendingJoinRequests': 1,
  };

  Map<String, ApiHandler> routes() => {
    'GET /team/members': (_) => [
      {
        'id': 'u-admin',
        'email': 'companyadmin@icr.test',
        'firstName': 'Chetan',
        'lastName': 'CompanyAdmin',
        'isActive': true,
        'role': 'COMPANY_ADMIN',
        'learningRoles': <Object>[],
        'inboxTopics': <Object>[],
        'handlesTopics': ['SALES'],
        'branchId': null,
        'branch': null,
        'createdAt': '2026-10-06T12:52:03.942Z',
      },
    ],
    'GET /team/requests': (_) => [
      {
        'id': 'req-1',
        'role': 'PROFESSIONAL',
        'note': 'I run facilities at your Pune site.',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'user': {'id': 'u-pooja', 'firstName': 'Pooja', 'lastName': 'Professional', 'avatarUrl': null},
      },
    ],
    'GET /team/invitations': (_) => <Object>[],
    'GET /team/invites': (_) => <Object>[],
    'GET /branches': (_) => <Object>[],
    'GET /support/tickets/t1': (_) => {
      'id': 't1',
      'reference': 12,
      'subject': 'Invoice has the wrong GSTIN',
      'category': 'BILLING_PAYMENTS',
      'status': 'OPEN',
      'priority': 'NORMAL',
      'contextType': 'NONE',
      'contextId': null,
      'contextLabel': null,
      'contextHref': null,
      'firstResponseHours': 12,
      'firstRespondedAt': null,
      'resolvedAt': null,
      'closedAt': null,
      'ratingScore': null,
      'reopenable': false,
      'messages': [
        {
          'id': 'm1',
          'author': {'id': 'u-admin', 'firstName': 'Chetan', 'lastName': 'CompanyAdmin', 'avatarUrl': null},
          'visibility': 'SHARED',
          'body': 'The GSTIN on the Gold invoice is not ours.',
          'attachments': <Object>[],
          'createdAt': '2026-10-07T13:00:39.377Z',
        },
      ],
      'events': <Object>[],
      'messageCount': 1,
      'lastActivityAt': '2026-10-09T09:30:00.354Z',
      'createdAt': '2026-10-07T13:00:39.377Z',
    },
    'GET /support/tickets': (_) => {
      'data': <Object>[],
      'meta': {'page': 1, 'limit': 20, 'total': 0, 'totalPages': 1, 'hasNext': false, 'hasPrev': false},
    },
    'GET /support/faqs': (_) => <Object>[],
    'GET /subscriptions/account-manager': (_) => null,
    'PATCH /notifications/seen': (_) => {'updated': 1},
    'GET /me/companies': (_) => {
      'personalRole': 'PROFESSIONAL',
      'canJoinCompanies': true,
      'companies': [company],
      'requests': <Object>[],
      'invitations': [
        {
          'companyId': 'co-2',
          'name': 'Global Infra Solutions',
          'logoUrl': null,
          'role': 'RECRUITER',
          'branchName': null,
          'learningRoles': <Object>[],
          'invitedBy': 'Asha Rao',
          'invitedAt': DateTime.now().toUtc().toIso8601String(),
        },
      ],
    },
  };

  late AccountHarness h;
  late Map<String, NotificationOpener> openers;
  final sites = <String>[];

  /// A notification (or a link) tapped on a route pushed above the providers, as the app's list is.
  Future<void> tapThrough(WidgetTester tester, String href) async {
    h = AccountHarness(routes: routes());
    await h.signIn(tester, userJson(role: 'COMPANY_ADMIN', companyId: 'co-1'));
    usePhone(tester);
    sites.clear();
    late NotificationRouter router;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<JobsController>(create: (_) => JobsController(DemoJobsRepository())),
          ChangeNotifierProvider<FeedController>(create: (_) => FeedController(DemoFeedRepository())),
        ],
        child: h.app(
          Builder(
            builder: (shell) {
              openers = appNotificationOpeners(shell: shell, viewer: DemoFeedRepository.me);
              router = NotificationRouter(openers: openers, openSite: (context, path) async => sites.add(path));
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(shell).push(
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
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tap')));
    await tester.pumpAndSettle();
  }

  group('a notification opens the app\'s own screen, not the website in a web view', () {
    testWidgets('"someone asked to join your team" opens the team on Requests, with the request and its note', (
      tester,
    ) async {
      await tapThrough(tester, '/manage/team?tab=requests');
      expect(find.byType(TeamScreen), findsOneWidget);
      expect(find.byType(InAppWebScreen), findsNothing);
      expect(sites, isEmpty);
      expect(find.byKey(const Key('team.requests')), findsOneWidget, reason: 'the Requests tab is the one on show');
      expect(find.text('Pooja Professional'), findsOneWidget);
      expect(find.textContaining('I run facilities at your Pune site.'), findsOneWidget);
      expect(h.api.count('GET /team/requests'), 1);
    });

    testWidgets('a team link with no tab opens on Members', (tester) async {
      await tapThrough(tester, '/manage/team');
      expect(find.byType(TeamScreen), findsOneWidget);
      expect(find.byKey(const Key('team.requests')), findsNothing);
      expect(find.text('Chetan CompanyAdmin'), findsOneWidget);
    });

    testWidgets('a help request opens its thread and reads what told the person about it', (tester) async {
      await tapThrough(tester, '/support/t1');
      expect(find.byType(TicketScreen), findsOneWidget);
      expect(find.byType(InAppWebScreen), findsNothing);
      expect(sites, isEmpty);
      expect(find.text('Invoice has the wrong GSTIN'), findsOneWidget);
      expect(find.text('The GSTIN on the Gold invoice is not ours.'), findsOneWidget);
      expect(h.api.count('GET /support/tickets/t1'), 1);
      final seen = h.api.last('PATCH /notifications/seen');
      expect(seen.json, {'kind': 'support.ticket', 'id': 't1'}, reason: 'the website\'s useMarkSeen("support.ticket")');
    });

    testWidgets('the help desk itself (a "support" row) opens the list of requests', (tester) async {
      await tapThrough(tester, '/support');
      expect(find.byType(SupportScreen), findsOneWidget);
      expect(find.byType(InAppWebScreen), findsNothing);
      expect(sites, isEmpty);
      expect(find.text('Help & Support'), findsOneWidget);
    });

    testWidgets('"X added you to a company" opens My companies on the invitation, ready to accept or decline', (
      tester,
    ) async {
      await tapThrough(tester, '/account/companies?focus=invitations');
      expect(find.byType(MyCompaniesScreen), findsOneWidget);
      expect(find.byType(InAppWebScreen), findsNothing);
      expect(sites, isEmpty);
      expect(find.text('Waiting for You'), findsOneWidget);
      expect(find.byKey(const Key('invitation.accept.co-2')), findsOneWidget);
      expect(find.byKey(const Key('invitation.decline.co-2')), findsOneWidget);
    });

    testWidgets('My companies without the focus opens as it always did, with the same card', (tester) async {
      await tapThrough(tester, '/account/companies');
      expect(find.byType(MyCompaniesScreen), findsOneWidget);
      expect(find.byKey(const Key('companies.invitations')), findsOneWidget);
    });
  });

  group('Settings: Help & support', () {
    Future<List<String>> pumpSettings(WidgetTester tester, {bool wired = true}) async {
      final log = <String>[];
      final harness = AccountHarness();
      await harness.signIn(tester);
      usePhone(tester);
      await tester.pumpWidget(
        harness.app(
          SettingsScreen(repository: DemoAccountRepository(), onSupport: wired ? () => log.add('support') : null),
        ),
      );
      await tester.pumpAndSettle();
      return log;
    }

    testWidgets('a row above Contact us opens the help desk, and does something Contact us does not', (tester) async {
      final log = await pumpSettings(tester);
      final row = find.byKey(const Key('settings.support'));
      await tester.ensureVisible(row);
      await tester.pump();
      expect(find.descendant(of: row, matching: find.text('Help & Support')), findsOneWidget);
      expect(find.byKey(const Key('settings.contact')), findsOneWidget);
      await tester.tap(row);
      await tester.pump();
      expect(log, ['support']);
    });

    testWidgets('a Settings screen with no hand-over for it shows no such row', (tester) async {
      await pumpSettings(tester, wired: false);
      expect(find.byKey(const Key('settings.support')), findsNothing);
    });
  });

  group('the router\'s table', () {
    test('the three kinds are registered openers now, and the web view keeps five', () {
      expect(
        appNotificationKinds,
        containsAll([NotificationKinds.team, NotificationKinds.supportTicket, NotificationKinds.support]),
      );
      expect(notificationKindsInWebView, {
        NotificationKinds.talentSearch,
        NotificationKinds.learningTeaching,
        NotificationKinds.teamInvite,
        NotificationKinds.companyWorkspace,
        NotificationKinds.articlesMine,
      });
    });

    test('a link to the account page keeps its focus when it is read back', () {
      final t = NotificationTarget.parse('/account/companies?focus=invitations');
      expect(t.kind, NotificationKinds.accountCompanies);
      expect(t['focus'], 'invitations');
      expect(NotificationTarget.parse('/account/companies')['focus'], isNull);
    });
  });

  group('links to the same pages (a message, a record) take the same screens', () {
    final viewer = DemoFeedRepository.me;
    Uri site(String path) => Uri.parse('https://icr.org.in$path');

    test('the team, with and without its tab, help and a request are the app\'s', () {
      for (final path in [
        '/manage/team',
        '/manage/team?tab=requests',
        '/manage/team?tab=pending',
        '/support',
        '/support/t1',
        '/account/companies?focus=invitations',
      ]) {
        expect(inAppSiteRoute(site(path), viewer: viewer), isNotNull, reason: path);
      }
    });

    test('an email invitation by token is still the website\'s page', () {
      expect(inAppSiteRoute(site('/invite/some-token'), viewer: viewer), isNull);
    });
  });
}
