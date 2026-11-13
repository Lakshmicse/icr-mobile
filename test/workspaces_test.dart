import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/auth/auth_controller.dart';
import 'package:icr_mobile/core/auth/session_user.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/widgets/title_bar.dart';
import 'package:icr_mobile/core/widgets/workspace_embed.dart';
import 'package:icr_mobile/features/profile/profile_drawer.dart';
import 'package:icr_mobile/features/profile/profile_drawer_data.dart';
import 'package:icr_mobile/features/workspaces/role_workspaces.dart';
import 'package:icr_mobile/features/workspaces/workspace_screen.dart';
import 'package:icr_mobile/features/workspaces/workspaces.dart';
import 'package:provider/provider.dart';

import 'helpers/feed_fixtures.dart';
import 'helpers/fonts.dart';
import 'live/live.dart' show MemoryTokens;

/// The profile menu, as the owner's drawer design draws it (6 Nov 2026): Company, Marketplace, Mentorship, Learning
/// and Jobs, each opening its pages as tabs, the one of the tab on screen in blue, with what is live beside it; then
/// Account (My Account, Saved Items, Referrals, Settings). Sign Out is in Settings.
void main() {
  setUpAll(loadAppFonts);

  const member = SessionUser(id: 'u1', email: 'a@icr.test', firstName: 'Gita', lastName: 'Guest', role: 'PROFESSIONAL');

  group('the pages each row opens', () {
    test('Mentorship: the member\'s mentoring, and the mentor desk for a mentor or their profile for an applicant', () {
      const mentor = SessionUser(
        id: 'u2',
        email: 'm@icr.test',
        firstName: 'M',
        lastName: 'Entor',
        role: 'PROFESSIONAL',
        mentorStatus: 'APPROVED',
      );
      const applicant = SessionUser(
        id: 'u5',
        email: 'a@icr.test',
        firstName: 'A',
        lastName: 'Pplicant',
        role: 'PROFESSIONAL',
        mentorStatus: 'PENDING',
      );
      List<String> paths(SessionUser u) => [for (final i in mentorshipSection(u).items) i.path];
      expect(
        [for (final i in mentorshipSection(member).items) i.label],
        ['My mentoring', 'Sessions', 'Goals', 'Find a mentor', 'Group sessions', 'Cohort programmes', 'CPD record'],
      );
      expect(mentorshipSection(member).items[1].path, '/mentorship/my?tab=calendar');
      // A mentor's own workspace, as the website's Mentor workspace rows (6 Nov 2026).
      expect(paths(mentor).where((p) => p == '/mentorship/mentor' || p.startsWith('/mentorship/mentor?')), [
        '/mentorship/mentor',
        '/mentorship/mentor?tab=services',
        '/mentorship/mentor?tab=work',
        '/mentorship/mentor?tab=settings',
      ]);
      expect([for (final i in mentorshipSection(mentor).items) i.label], contains('Offerings'));
      expect(paths(mentor), isNot(contains('/mentorship/become-a-mentor')));
      expect(paths(applicant), contains('/mentorship/become-a-mentor'));
      expect(paths(member), isNot(contains('/mentorship/mentor')));
      expect(paths(member), isNot(contains('/mentorship/become-a-mentor')));
    });

    test('Learning, My Account (the plans) and Referrals: the website\'s pages, by their words and paths', () {
      expect(
        [for (final i in learningSection.items) i.path],
        [
          '/learning',
          '/learning?mine=1',
          '/learning/attempts',
          '/learning/certificates',
          '/learning/assessment',
          '/learning/mock-tests',
          '/learning/flash-cards',
          '/learning/formulas',
        ],
      );
      expect(
        [for (final i in learningSection.items.take(4)) i.label],
        ['Learning', 'My Courses', 'My Attempts', 'Certificates & Badges'],
      );
      expect(myAccountSection.title, 'My Account');
      expect(
        [for (final i in myAccountSection.items) i.path],
        ['/membership', '/membership/history', '/membership/benefits'],
      );
      expect(referralsSection.title, 'Referrals');
      expect([for (final i in referralsSection.items) i.path], ['/refer', '/refer/credits']);
    });
  });

  group('the menu', () {
    /// The drawer over a page, opened, recording what a row opened.
    Future<List<(String, int)>> pumpMenu(
      WidgetTester tester, {
      Map<String, WidgetBuilder> screens = const {},
      SessionUser user = member,
      String? current,
      ProfileDrawerController? data,
      double width = 393,
    }) async {
      // Tall enough for every row, the doors included: a tap on a row below the fold would be lost.
      tester.view.physicalSize = Size(width * 2.75, 4400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      final tokens = MemoryTokens()
        ..access = 'access'
        ..refresh = 'refresh';
      final api = ApiClient(tokens: tokens, baseUrl: 'http://api.test/api/v1')..dio.httpClientAdapter = FakeForum({});
      final opened = <(String, int)>[];
      final scaffold = GlobalKey<ScaffoldState>();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(
              value: AuthController(api: api, tokens: tokens),
            ),
            ChangeNotifierProvider.value(value: data ?? ProfileDrawerController.demo()),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              key: scaffold,
              drawer: ProfileDrawer(
                screens: screens,
                workspaces: workspacesFor(user, opens: (_) => true),
                doors: startDoorsFor(user),
                account: accountMenuFor(user),
                mentorStatus: user.mentorStatus,
                currentWorkspace: current,
                onOpenSection: (section, i) => opened.add((section.key, i)),
              ),
              body: const Center(child: Text('the page')),
            ),
          ),
        ),
      );
      scaffold.currentState!.openDrawer();
      await tester.pumpAndSettle();
      return opened;
    }

    /// The marked row reads in ICR blue (no fill: white throughout, owner, 6 Nov 2026). A row the menu does not
    /// hold (Company for a member with no company) is not marked.
    bool isSelected(WidgetTester tester, String key) {
      final label = find.descendant(of: find.byKey(ValueKey('workspace-$key')), matching: find.byType(Text));
      if (label.evaluate().isEmpty) return false;
      return tester.widget<Text>(label.first).style!.color == const Color(0xFF1D63A3);
    }

    testWidgets(
      'acting as yourself: Marketplace, Mentorship, Learning, Jobs, Company (My companies), Account, then the doors',
      (tester) async {
        await pumpMenu(tester);
        for (final key in ['marketplace', 'mentorship', 'learning', 'jobs', 'account']) {
          expect(find.byKey(ValueKey('workspace-$key')), findsOneWidget, reason: key);
        }
        // The Company row holds My companies for everyone (owner, 7 Nov 2026: it sat under Account).
        expect(find.byKey(const ValueKey('workspace-company')), findsOneWidget);
        // The website's "Do more on ICR": a company to hire, sell or buy with, and becoming a mentor.
        expect(find.text('Explore more on ICR'), findsOneWidget);
        for (final door in ['create-company', 'hire', 'sell', 'source', 'mentor']) {
          expect(find.byKey(ValueKey('door-$door')), findsOneWidget, reason: door);
        }
        expect(find.text('Create a Company'), findsOneWidget);
        expect(find.text('Become a Mentor'), findsOneWidget);
        // Each door says what it does in the website's words (WelcomeCard's intents).
        for (final caption in [
          'Create your company page, then post a job.',
          'Create your company page, then list your services.',
          'Search verified suppliers and ask for quotes.',
          'Share your expertise with the next generation.',
        ]) {
          expect(find.text(caption), findsOneWidget, reason: caption);
        }
        // The Account row among the main ones; under the rows My Uploads, My Forum and Settings (the owner's
        // document, 12 Nov 2026; the plans and Refer & Earn are the Account row's pages).
        expect(find.text('Account'), findsOneWidget);
        for (final row in ['My Uploads', 'My Forum', 'Settings']) {
          expect(find.text(row), findsOneWidget, reason: row);
        }
        for (final gone in [
          'Saved Items',
          'My Account',
          'Referrals',
          'Membership',
          'Refer & Earn',
          'Saved Jobs',
          'My companies',
          'Sign Out',
        ]) {
          expect(find.text(gone), findsNothing, reason: '$gone is not a row of the design');
        }
        // A row's pages are not listed until it is tapped.
        expect(find.byKey(const ValueKey('workspace-learning-0')), findsNothing);
        expect(find.text('Regional Chapters'), findsNothing, reason: 'the old rows are replaced');
        expect(find.text('Cohort programmes'), findsNothing, reason: 'a row\'s pages are tabs, not menu rows');
      },
    );

    testWidgets('acting for a company: the Company row, and no doors', (tester) async {
      const admin = SessionUser(
        id: 'u3',
        email: 'c@icr.test',
        firstName: 'C',
        lastName: 'Admin',
        role: 'COMPANY_ADMIN',
        companyId: 'co1',
      );
      await pumpMenu(tester, user: admin);
      expect(find.byKey(const ValueKey('workspace-company')), findsOneWidget);
      expect(find.text('Explore more on ICR'), findsNothing);
      expect(find.byKey(const ValueKey('door-create-company')), findsNothing);
    });

    testWidgets('a door opens its page and the menu closes', (tester) async {
      await pumpMenu(tester, screens: {'/account/companies/new': (_) => const Scaffold(body: Text('create company'))});
      await tester.tap(find.byKey(const ValueKey('door-create-company')));
      await tester.pumpAndSettle();
      expect(find.text('create company'), findsOneWidget);
      expect(find.byType(ProfileDrawer), findsNothing);
    });

    testWidgets('a row drops its pages down; a page opens the module on that tab, and the menu closes', (tester) async {
      final opened = await pumpMenu(tester);
      await tester.tap(find.byKey(const ValueKey('workspace-learning')));
      await tester.pumpAndSettle();
      expect(opened, isEmpty, reason: 'the row itself only opens its list');
      expect(find.byType(ProfileDrawer), findsOneWidget);
      for (final page in ['My Courses', 'My Attempts', 'My Certificates']) {
        expect(find.text(page), findsOneWidget, reason: page);
      }
      // Another row's tap closes the first list.
      await tester.tap(find.byKey(const ValueKey('workspace-mentorship')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('workspace-learning-0')), findsNothing);
      expect(find.text('Mentoring Sessions'), findsOneWidget);
      expect(find.text('Mentor Dashboard'), findsNothing, reason: 'a member who mentors nobody has no mentor desk');
      await tester.tap(find.byKey(const ValueKey('workspace-learning')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('workspace-learning-2')));
      await tester.pumpAndSettle();
      expect(opened, [('learning', 2)], reason: 'My certificates is the third page');
      expect(find.byType(ProfileDrawer), findsNothing, reason: 'the menu closes behind it');
    });

    testWidgets('the Account row: Membership first, Refer & Earn among its pages', (tester) async {
      var opened = await pumpMenu(tester);
      await tester.tap(find.byKey(const ValueKey('workspace-account')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Membership'));
      await tester.pumpAndSettle();
      expect(opened, [('account', 0)]);
      opened = await pumpMenu(tester);
      await tester.tap(find.byKey(const ValueKey('workspace-account')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refer a friend'));
      await tester.pumpAndSettle();
      expect(opened, [('account', 3)]);
    });

    testWidgets("My Uploads opens the member's own uploads", (tester) async {
      await pumpMenu(tester, screens: {'/documents?mine=1': (_) => const Scaffold(body: Text('my uploads'))});
      await tester.tap(find.text('My Uploads'));
      await tester.pumpAndSettle();
      expect(find.text('my uploads'), findsOneWidget);
      expect(find.byType(ProfileDrawer), findsNothing, reason: 'the menu closes behind it');
    });

    testWidgets("My Forum opens the member's own discussions and polls", (tester) async {
      await pumpMenu(tester, screens: {'/community?mine=1': (_) => const Scaffold(body: Text('my posts'))});
      await tester.tap(find.text('My Forum'));
      await tester.pumpAndSettle();
      expect(find.text('my posts'), findsOneWidget);
      expect(find.byType(ProfileDrawer), findsNothing);
    });

    testWidgets('Settings opens the settings screen, where Sign out lives', (tester) async {
      await pumpMenu(tester, screens: {'/profile?tab=security': (_) => const Scaffold(body: Text('settings'))});
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('settings'), findsOneWidget);
    });

    testWidgets('the row of the tab on screen is the marked one; on Home none is', (tester) async {
      await pumpMenu(tester, current: 'learning');
      expect(isSelected(tester, 'learning'), isTrue);
      expect(isSelected(tester, 'jobs'), isFalse);
      await pumpMenu(tester);
      for (final key in ['company', 'marketplace', 'mentorship', 'learning', 'jobs']) {
        expect(isSelected(tester, key), isFalse, reason: key);
      }
    });

    testWidgets('what is live: open requirements, a listed mentor, the jobs on the board', (tester) async {
      const mentor = SessionUser(
        id: 'u2',
        email: 'm@icr.test',
        firstName: 'M',
        lastName: 'Entor',
        role: 'PROFESSIONAL',
        mentorStatus: 'APPROVED',
      );
      await pumpMenu(tester, user: mentor);
      expect(find.text('LIVE RFQS'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('124'), findsOneWidget, reason: 'the open jobs');
      // A referral earns ICR credits, not CPD hours.
      expect(find.text('Earn Credits'), findsOneWidget);
      expect(find.text('Earn CPD'), findsNothing);
    });

    testWidgets('a paused mentor reads Paused; someone who mentors nobody, nothing', (tester) async {
      const paused = SessionUser(
        id: 'u3',
        email: 'p@icr.test',
        firstName: 'P',
        lastName: 'Aused',
        role: 'PROFESSIONAL',
        mentorStatus: 'PAUSED',
      );
      await pumpMenu(tester, user: paused);
      expect(find.text('Paused'), findsOneWidget);
      await pumpMenu(tester);
      expect(find.text('Available'), findsNothing);
      expect(find.text('Paused'), findsNothing);
    });

    testWidgets('nothing read yet: chevrons, never a pill with a zero or a dash', (tester) async {
      await pumpMenu(
        tester,
        data: ProfileDrawerController.live(
          api: null,
          userId: 'u1',
          seed: const ProfileDrawerData(name: 'Gita Guest'),
        ),
      );
      expect(find.text('LIVE RFQS'), findsNothing);
      expect(find.text('0'), findsNothing);
      expect(find.text('Earn Credits'), findsOneWidget, reason: 'what a referral earns is not a count');
    });

    testWidgets('ICR staff: their consoles and Settings, no member rows', (tester) async {
      const operator = SessionUser(
        id: 'u9',
        email: 'ops@icr.test',
        firstName: 'O',
        lastName: 'Ps',
        role: 'SUPER_ADMIN',
      );
      await pumpMenu(tester, user: operator);
      for (final key in ['mentorship', 'learning']) {
        expect(find.byKey(ValueKey('workspace-$key')), findsNothing, reason: key);
      }
      expect(find.byKey(const ValueKey('workspace-engage')), findsOneWidget);
      for (final row in ['My Account', 'Saved Items', 'Referrals']) {
        expect(find.text(row), findsNothing, reason: row);
      }
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('fits a narrow phone with large text', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpMenu(tester, width: 320, current: 'marketplace');
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('workspace-jobs')), findsOneWidget);
    });
  });

  group('the counts beside the rows', () {
    test('read from the boards and the member\'s bookmarks, and the job board is asked for no rows', () async {
      Map<String, Object> page(int total) => {
        'data': const [],
        'meta': {'total': total},
      };
      final api = FakeForum({
        'GET /rfq': (_) => page(8),
        'GET /jobs': (_) => page(124),
        'GET /jobs/saved': (_) => page(3),
        'GET /mentorship/mentors/saved': (_) => page(2),
        'GET /vendors/saved': (_) => (403, '{"statusCode":403}'),
        'GET /councils/saves/mine': (_) => [
          {'councilId': 'c1'},
          {'councilId': 'c2'},
        ],
        'GET /forum/saves/mine': (_) => page(7),
      });
      final controller = ProfileDrawerController.live(
        api: clientOn(api),
        userId: 'u1',
        seed: const ProfileDrawerData(name: 'Gita Guest'),
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(controller.data.liveRfqs, 8);
      expect(controller.data.openJobs, 124);
      expect(controller.data.savedItems, 14, reason: '3 + 2 + 2 + 7; a kind the account cannot hold counts nothing');
      // The board counts an impression for each promoted job it serves: a count asks for a page past the end.
      final jobs = api.to('GET', '/jobs').single;
      expect(jobs.queryParameters['page'], greaterThan(1000));
    });
  });

  group("an option's pages as tabs", () {
    const section = WorkspaceSection(
      key: 'find-work',
      title: 'Find work',
      icon: Icons.travel_explore,
      tint: Colors.purple,
      items: [
        WorkspaceItem('Jobs', Icons.work_outline, '/jobs'),
        WorkspaceItem('Companies', Icons.business_outlined, '/companies'),
      ],
    );

    testWidgets("the option's name in the bar, its pages as tabs, and a page's own bar stepping aside", (tester) async {
      final built = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceScreen(
            section: section,
            pageFor: (context, item) {
              built.add(item.path);
              if (item.path != '/jobs') return null;
              return Scaffold(
                body: Column(
                  children: [
                    TitleBar(title: 'Jobs board', onBell: () {}),
                    const Text('the jobs page'),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Find work'), findsOneWidget);
      expect(find.byKey(const ValueKey('workspace-tab-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('workspace-tab-1')), findsOneWidget);
      expect(find.text('the jobs page'), findsOneWidget);
      expect(find.text('Jobs board'), findsNothing, reason: 'the tab names the page; its title is not drawn again');
      expect(find.bySemanticsLabel('Back'), findsNothing, reason: "the page's back arrow and bell step aside");
      expect(built, ['/jobs'], reason: 'a page is built when its tab is first opened');

      await tester.tap(find.byKey(const ValueKey('workspace-tab-1')));
      await tester.pumpAndSettle();
      expect(built, ['/jobs', '/companies']);
      expect(
        find.byKey(const ValueKey('workspace-open-/companies')),
        findsOneWidget,
        reason: 'a page with no app screen offers the website page',
      );
    });

    testWidgets(
      'a page asking for another page of the workspace switches to its tab; one it lacks is left to the page',
      (tester) async {
        final answers = <bool>[];
        await tester.pumpWidget(
          MaterialApp(
            home: WorkspaceScreen(
              section: const WorkspaceSection(
                key: 'mentorship',
                title: 'Mentorship',
                icon: Icons.school_outlined,
                tint: Colors.indigo,
                items: [
                  WorkspaceItem('My mentoring', Icons.handshake_outlined, '/mentorship/my'),
                  WorkspaceItem('Find a mentor', Icons.search, '/mentorship/mentors'),
                ],
              ),
              pageFor: (context, item) => item.path == '/mentorship/my'
                  ? Builder(
                      builder: (c) => Column(
                        children: [
                          TextButton(
                            onPressed: () => answers.add(WorkspaceEmbed.openTabFor(c, '/mentorship/mentors')),
                            child: const Text('Find a mentor'),
                          ),
                          TextButton(
                            onPressed: () => answers.add(WorkspaceEmbed.openTabFor(c, '/jobs')),
                            child: const Text('Jobs'),
                          ),
                        ],
                      ),
                    )
                  : const Text('the mentor search'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Jobs'));
        expect(answers, [false], reason: 'no Jobs tab here: the page opens it itself');
        await tester.tap(find.widgetWithText(TextButton, 'Find a mentor'));
        await tester.pumpAndSettle();
        expect(answers, [false, true]);
        expect(find.text('the mentor search'), findsOneWidget);
        expect(find.byType(WorkspaceScreen), findsOneWidget, reason: 'the workspace stays open');
      },
    );
  });
}
