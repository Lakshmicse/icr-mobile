import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/auth/auth_controller.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/account/account_models.dart';
import 'package:icr_mobile/features/account/account_repository.dart';
import 'package:icr_mobile/features/account/companies/create_company_screen.dart';
import 'package:icr_mobile/features/account/companies/my_companies_screen.dart';
import 'package:icr_mobile/features/account/demo_account_repository.dart';
import 'package:icr_mobile/features/profile/profile_drawer.dart';
import 'package:icr_mobile/features/profile/profile_drawer_data.dart';
import 'package:provider/provider.dart';

import 'helpers/feed_fixtures.dart';
import 'helpers/fonts.dart';
import 'live/live.dart' show MemoryTokens;

/// Every control of the profile menu, pressed on the real drawer, with only the portal faked
/// (`helpers/feed_fixtures.dart`'s adapter) and the browser's channel listened to. What the portal answers,
/// and a sign-out that really revokes the session, is proved by `test/live/profile_menu_live_test.dart`.
void main() {
  setUpAll(loadAppFonts);

  final launched = <Uri>[];

  setUp(() {
    launched.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        if (call.method == 'launch') launched.add(Uri.parse((call.arguments as Map)['url'] as String));
        return call.method == 'launch' || call.method == 'canLaunch';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      null,
    );
  });

  /// The drawer over a page, opened. [api] answers the drawer's reads (the demo member when null).
  Future<({AuthController auth, MemoryTokens tokens})> pumpDrawer(
    WidgetTester tester, {
    FakeForum? api,
    Map<String, WidgetBuilder> screens = const {},
    ProfileDrawerData? seed,
    AccountRepository? companies,
    void Function(BuildContext, String)? onOpenCompany,
    bool withApiClient = false,
    MyCompanies? cachedCompanies,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final tokens = MemoryTokens()
      ..access = 'access'
      ..refresh = 'refresh';
    // The session's own client talks to the same fake, so what Sign Out asks of the API can be read back.
    final authApi = ApiClient(tokens: tokens, baseUrl: 'http://api.test/api/v1')
      ..dio.httpClientAdapter = api ?? FakeForum({});
    final auth = AuthController(api: authApi, tokens: tokens);
    final controller = api == null
        ? ProfileDrawerController.demo()
        : ProfileDrawerController.live(
            api: clientOn(api),
            userId: 'me',
            seed: seed ?? const ProfileDrawerData(name: 'Bharat Buyer', verified: true),
          );
    controller.cachedCompanies = cachedCompanies;
    if (api != null) await tester.runAsync(controller.refresh);
    final scaffold = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: controller),
          if (withApiClient) Provider<ApiClient>.value(value: authApi),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            key: scaffold,
            drawer: ProfileDrawer(screens: screens, companiesRepository: companies, onOpenCompany: onOpenCompany),
            body: const Center(child: Text('the page')),
          ),
        ),
      ),
    );
    scaffold.currentState!.openDrawer();
    await tester.pumpAndSettle();
    return (auth: auth, tokens: tokens);
  }

  Future<void> tapRow(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  group('the rows', () {
    testWidgets('a row the app has a screen for opens it, and the others still open the website', (tester) async {
      await pumpDrawer(tester, screens: {'/councils': (_) => const Scaffold(body: Text('the councils screen'))});
      expect(find.text('Working Councils'), findsOneWidget);

      await tapRow(tester, 'Working Councils');
      expect(find.text('the councils screen'), findsOneWidget);
      expect(launched, isEmpty);
    });

    testWidgets('there is no View Full Profile button; the photo and the name open the app\'s own profile screen', (
      tester,
    ) async {
      // A signed-in member's profile path is the website's `/members/<slug>`; the app maps only `/profile`.
      await pumpDrawer(tester, screens: {'/profile': (_) => const Scaffold(body: Text('my profile screen'))});
      expect(find.text('View Full Profile'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Open your profile')), findsOneWidget);

      await tester.tap(find.text('Nikhil Majjagi'));
      await tester.pumpAndSettle();
      expect(find.text('my profile screen'), findsOneWidget);
      expect(launched, isEmpty);
      expect(find.byType(ProfileDrawer), findsNothing, reason: 'the menu closes behind it');
    });

    for (final text in ['Lead Operations Manager at TechCorp', 'Bengaluru, Karnataka · 500+ Connections']) {
      testWidgets('the line "$text" under the name opens the profile too', (tester) async {
        await pumpDrawer(tester, screens: {'/profile': (_) => const Scaffold(body: Text('my profile screen'))});
        await tester.tap(find.text(text));
        await tester.pumpAndSettle();
        expect(find.text('my profile screen'), findsOneWidget);
        expect(find.byType(ProfileDrawer), findsNothing);
      });
    }

    testWidgets('the photo opens the profile too', (tester) async {
      await pumpDrawer(tester, screens: {'/profile': (_) => const Scaffold(body: Text('my profile screen'))});
      // The oval the avatar is clipped to.
      await tester.tap(find.byType(ClipOval).first);
      await tester.pumpAndSettle();
      expect(find.text('my profile screen'), findsOneWidget);
      expect(find.byType(ProfileDrawer), findsNothing);
    });

    testWidgets('the two counts under the name are plain: they do not open anything', (tester) async {
      await pumpDrawer(tester, screens: {'/profile': (_) => const Scaffold(body: Text('my profile screen'))});
      await tester.tap(find.text('Profile Views'));
      await tester.pumpAndSettle();
      expect(find.text('my profile screen'), findsNothing);
      expect(find.byType(ProfileDrawer), findsOneWidget);
    });

    testWidgets('each row opens its page on the website and the menu closes behind it', (tester) async {
      const rows = {
        'Regional Chapters': '/chapters',
        'Working Councils': '/councils',
        'Get Involved & Volunteer': '/get-involved',
        'Saved Items & Jobs': '/career/saved',
        'My RFQ Requirements': '/manage/requirements',
        'Certificates & Badges': '/learning/certificates',
        'Settings': '/profile?tab=security',
        'Nikhil Majjagi': '/members/nikhil-majjagi',
      };
      for (final entry in rows.entries) {
        launched.clear();
        await pumpDrawer(tester);
        await tapRow(tester, entry.key);
        expect(launched.single.toString(), 'https://icr.org.in${entry.value}', reason: entry.key);
        expect(find.byType(ProfileDrawer), findsNothing, reason: '${entry.key} closes the menu');
        expect(find.text('the page'), findsOneWidget);
      }
    });

    testWidgets('Back closes the menu and nothing else happens', (tester) async {
      await pumpDrawer(tester);
      expect(find.byType(ProfileDrawer), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ProfileDrawer), findsNothing);
      expect(find.text('the page'), findsOneWidget);
      expect(launched, isEmpty);
    });

    testWidgets('Sign Out ends the session: the saved tokens go and the API is told to revoke the refresh token', (
      tester,
    ) async {
      final api = FakeForum({
        ..._memberRoutes(),
        'POST /auth/logout': (_) => {'success': true},
      });
      final session = await pumpDrawer(tester, api: api);

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pumpAndSettle();

      expect(session.auth.status, SessionStatus.signedOut);
      expect(await session.tokens.refreshToken(), isNull);
      expect(await session.tokens.accessToken(), isNull);
      expect(find.byType(ProfileDrawer), findsNothing, reason: 'the menu closes first');
      // The API is asked to revoke exactly the token that was saved; that it does is proved live.
      expect(api.to('POST', '/auth/logout').single.data, {'refreshToken': 'refresh'});
    });
  });

  group('what the menu shows', () {
    testWidgets('the member\'s lines are the API\'s, worded as the design words them', (tester) async {
      await pumpDrawer(tester, api: FakeForum(_memberRoutes()));
      expect(find.text('Bharat Buyer'), findsOneWidget);
      expect(find.text('Lead Operations Manager at TechCorp'), findsOneWidget);
      expect(find.text('Bengaluru, Karnataka · 267 Connections'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Profile Views'), findsOneWidget);
      expect(find.text('1,204'), findsOneWidget);
      expect(find.text('Post Impressions'), findsOneWidget);
      // The chapters by their cities, the first one's code, the first council and how many more, the CPD.
      expect(find.text('Bengaluru, Pune, New Jersey'), findsOneWidget);
      expect(find.text('BLR'), findsOneWidget);
      expect(find.text('Sustainability, ESG & Net-Zero +2'), findsOneWidget);
      expect(find.text('+12 CPD'), findsOneWidget);
      // With the design's own pill the title fits as it is: it is not scaled down (at the app's 14 sp the
      // text is a quarter of a pixel wider than its box, a scale of 0.998, which is no scaling a reader sees).
      final title = find.text('Get Involved & Volunteer');
      expect(title, findsOneWidget);
      final box = tester.getSize(find.ancestor(of: title, matching: find.byType(FittedBox))).width;
      expect(tester.getSize(title).width, closeTo(box, box * 0.02));
    });

    testWidgets('a member with nothing yet reads the design\'s own words and dashes, never zeros that mislead', (
      tester,
    ) async {
      await pumpDrawer(tester, api: FakeForum({}));
      // Every read failed: no headline, no line under the name, a dash for each count, the design's words.
      expect(find.text('Bharat Buyer'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('Bengaluru, Mumbai, Delhi & more'), findsOneWidget);
      expect(find.text('Sustainability, ESG & Smart PropTech'), findsOneWidget);
      expect(find.textContaining('CPD'), findsOneWidget, reason: 'only the row\'s own "Earn certified CPD credits"');
    });

    testWidgets('each read fails on its own: the rest of the menu still fills in', (tester) async {
      final routes = _memberRoutes();
      routes['GET /members/me'] = (_) => (500, '{"message":"down"}');
      routes['GET /mentorship/cpd/summary'] = (_) => (500, '{"message":"down"}');
      await pumpDrawer(tester, api: FakeForum(routes));
      expect(find.text('Lead Operations Manager at TechCorp'), findsOneWidget, reason: 'from the profile read');
      expect(find.text('42'), findsOneWidget);
      expect(find.text('1,204'), findsOneWidget);
      expect(find.textContaining('Connections'), findsNothing);
      expect(find.text('+12 CPD'), findsNothing);
    });

    testWidgets('a wider pill does not cut the row\'s title short', (tester) async {
      final routes = _memberRoutes();
      routes['GET /mentorship/cpd/summary'] = (_) => {'totalHours': 108.5, 'hoursThisYear': 8.5};
      await pumpDrawer(tester, api: FakeForum(routes));
      expect(find.text('+108.5 CPD'), findsOneWidget);
      // The title is whole: laid out at its own width and scaled down to the room it has, not ellipsised.
      final title = find.text('Get Involved & Volunteer');
      expect(title, findsOneWidget);
      final room = tester.getSize(find.ancestor(of: title, matching: find.byType(FittedBox)));
      expect(tester.getSize(title).width, greaterThan(room.width));
      expect(tester.takeException(), isNull);
    });
  });

  group('Your companies', () {
    const mine = MyCompany(companyId: 'co-mine', name: 'My Own Co', role: 'COMPANY_ADMIN', active: true);
    const north = MyCompany(companyId: 'co-north', name: 'Northwind Facilities', role: 'PROFESSIONAL');
    const tech = MyCompany(companyId: 'co-tech', name: 'TechCorp', role: 'RECRUITER');
    const globe = MyCompany(companyId: 'co-globe', name: 'Global Infra Solutions', role: 'VENDOR');
    const harbor = MyCompany(companyId: 'co-harbor', name: 'Harbor Soft Services', role: 'BUYER');

    DemoAccountRepository repoWith(List<MyCompany> list) =>
        DemoAccountRepository(companies: MyCompanies(personalRole: 'PROFESSIONAL', companies: list));

    testWidgets('three of five, the one acted for first and marked Active, and See all for the rest', (tester) async {
      final repo = repoWith(const [north, tech, globe, harbor, mine]);
      await pumpDrawer(tester, companies: repo);
      expect(find.text('YOUR COMPANIES'), findsOneWidget);
      // The company being acted for leads the list whatever its place in the API's answer.
      expect(find.text('My Own Co'), findsOneWidget);
      expect(find.text('Northwind Facilities'), findsOneWidget);
      expect(find.text('TechCorp'), findsOneWidget);
      expect(find.text('Global Infra Solutions'), findsNothing);
      expect(find.text('Harbor Soft Services'), findsNothing);
      expect(find.text('Company Admin'), findsOneWidget, reason: 'the role under the name');
      expect(find.text('Professional'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.byKey(const ValueKey('drawer-company-active:co-mine')), findsOneWidget);
      expect(find.byKey(const ValueKey('drawer-company-active:co-north')), findsNothing);
      // The first row is the active one.
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('drawer-company:co-mine'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('drawer-company:co-north'))).dy),
      );

      await tester.tap(find.byKey(const ValueKey('drawer-companies-all')));
      await tester.pumpAndSettle();
      expect(find.byType(MyCompaniesScreen), findsOneWidget);
      expect(find.byType(ProfileDrawer), findsNothing, reason: 'the menu closes behind See all');
      expect(find.text('Global Infra Solutions'), findsOneWidget, reason: 'My companies lists them all');
    });

    testWidgets('three or fewer: no See all, and nothing is offered to create', (tester) async {
      await pumpDrawer(tester, companies: repoWith(const [mine, north]));
      expect(find.text('My Own Co'), findsOneWidget);
      expect(find.text('Northwind Facilities'), findsOneWidget);
      expect(find.byKey(const ValueKey('drawer-companies-all')), findsNothing);
      expect(find.byKey(const ValueKey('drawer-company-create')), findsNothing);
    });

    testWidgets('a tap on the company being acted for opens its page, and switches nothing', (tester) async {
      final repo = repoWith(const [north, mine]);
      final opened = <String>[];
      await pumpDrawer(tester, companies: repo, onOpenCompany: (_, id) => opened.add(id));
      await tester.tap(find.byKey(const ValueKey('drawer-company:co-mine')));
      await tester.pumpAndSettle();
      expect(opened, ['co-mine']);
      expect(repo.calls.where((c) => c.startsWith('switchCompany')), isEmpty);
      expect(find.byType(ProfileDrawer), findsNothing);
      expect(launched, isEmpty, reason: 'the page is the app\'s, not the website\'s');
    });

    testWidgets('with no opener the page is the website\'s, through the app\'s own routing', (tester) async {
      await pumpDrawer(tester, companies: repoWith(const [mine]));
      await tester.tap(find.byKey(const ValueKey('drawer-company:co-mine')));
      await tester.pumpAndSettle();
      expect(launched.single.toString(), 'https://icr.org.in/companies/co-mine');
    });

    testWidgets('a tap on another company makes it the one acted for, hands over the fresh session and says so', (
      tester,
    ) async {
      final repo = repoWith(const [mine, north]);
      final opened = <String>[];
      final session = await pumpDrawer(tester, companies: repo, onOpenCompany: (_, id) => opened.add(id));
      final before = await session.tokens.accessToken();

      await tester.tap(find.byKey(const ValueKey('drawer-company:co-north')));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('switchCompany:co-north'));
      expect(await session.tokens.accessToken(), isNot(before), reason: 'the fresh token pair is adopted');
      expect(opened, isEmpty, reason: 'a switch does not also open the page');
      expect(find.byType(ProfileDrawer), findsNothing, reason: 'the menu closes behind it');
      expect(find.text('Now working as Northwind Facilities.'), findsOneWidget);
    });

    testWidgets('a refused switch shows the API\'s sentence and keeps the menu open', (tester) async {
      final repo = repoWith(const [mine, north])
        ..failures['switchCompany'] = ApiError('That company is suspended.', statusCode: 403);
      await pumpDrawer(tester, companies: repo);
      await tester.tap(find.byKey(const ValueKey('drawer-company:co-north')));
      await tester.pumpAndSettle();
      expect(find.text('That company is suspended.'), findsOneWidget);
      expect(find.byType(ProfileDrawer), findsOneWidget);
      expect(find.byKey(const ValueKey('drawer-company-active:co-mine')), findsOneWidget, reason: 'nothing changed');
    });

    testWidgets('with no company the block offers only to create one', (tester) async {
      await pumpDrawer(tester, companies: repoWith(const []), withApiClient: true);
      expect(find.text('YOUR COMPANIES'), findsOneWidget);
      expect(find.text('Create a company'), findsOneWidget);
      expect(find.byKey(const ValueKey('drawer-companies-all')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('drawer-company-create')));
      await tester.pumpAndSettle();
      expect(find.byType(CreateCompanyScreen), findsOneWidget);
      expect(find.byType(ProfileDrawer), findsNothing);
    });

    testWidgets('while it reads, two grey rows; a failed read draws nothing and never an error', (tester) async {
      final gate = Completer<void>();
      final slow = repoWith(const [mine])..gate = gate.future;
      await pumpDrawer(tester, companies: slow);
      expect(find.text('YOUR COMPANIES'), findsOneWidget, reason: 'the heading and the grey rows wait for the read');
      expect(find.text('My Own Co'), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('My Own Co'), findsOneWidget);

      final failing = repoWith(const [mine])..failures['myCompanies'] = ApiError('The server is busy.', statusCode: 503);
      await pumpDrawer(tester, companies: failing);
      expect(find.text('YOUR COMPANIES'), findsNothing);
      expect(find.text('The server is busy.'), findsNothing);
      expect(find.text('Regional Chapters'), findsOneWidget, reason: 'the rest of the menu is untouched');
    });

    testWidgets('a menu opened again shows the last list at once, with no grey rows, while it reads it again', (
      tester,
    ) async {
      final gate = Completer<void>();
      final repo = repoWith(const [mine, north])..gate = gate.future;
      await pumpDrawer(
        tester,
        companies: repo,
        cachedCompanies: const MyCompanies(personalRole: 'PROFESSIONAL', companies: [mine, north]),
      );
      // The read is held, yet the rows are there.
      expect(find.text('My Own Co'), findsOneWidget);
      expect(find.text('Northwind Facilities'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('My Own Co'), findsOneWidget);
      expect(repo.count('myCompanies'), 1, reason: 'and it was read again');
    });

    testWidgets('an ICR staff account is personal: no companies block at all', (tester) async {
      final staff = DemoAccountRepository(
        companies: const MyCompanies(personalRole: 'SUPER_ADMIN', canJoinCompanies: false),
      );
      await pumpDrawer(tester, companies: staff);
      expect(find.text('YOUR COMPANIES'), findsNothing);
      expect(find.text('Create a company'), findsNothing);
    });

    testWidgets('without an account repository (no API client above the menu) there is no block', (tester) async {
      await pumpDrawer(tester);
      expect(find.text('YOUR COMPANIES'), findsNothing);
    });

    testWidgets('the menu scrolls at the phone\'s width with large text, with nothing overflowing', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpDrawer(tester, companies: repoWith(const [mine, north, tech, globe]));
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Certificates & Badges'), 120, scrollable: find.byType(Scrollable).first);
      expect(find.text('Certificates & Badges'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the data', () {
    test('connections read "500+" from five hundred, and the one-connection sentence', () {
      expect(const ProfileDrawerData(name: 'A B', connections: 267).connectionsLabel, '267 Connections');
      expect(const ProfileDrawerData(name: 'A B', connections: 500).connectionsLabel, '500+ Connections');
      expect(const ProfileDrawerData(name: 'A B', connections: 1).connectionsLabel, '1 Connection');
      expect(const ProfileDrawerData(name: 'A B', connections: 0).connectionsLabel, '0 Connections');
      expect(const ProfileDrawerData(name: 'A B').connectionsLabel, isNull);
      expect(
        const ProfileDrawerData(name: 'A B', location: 'Bengaluru, Karnataka', connections: 12).locationLine,
        'Bengaluru, Karnataka · 12 Connections',
      );
      expect(const ProfileDrawerData(name: 'A B', location: 'Pune').locationLine, 'Pune');
    });

    test('the chapters line is the cities, three at most and "& more" after; no chapter, no line', () {
      String? line(List<String> cities) => ProfileDrawerData(name: 'A B', chapterCities: cities).chaptersLine;
      expect(line([]), isNull);
      expect(line(['Bengaluru']), 'Bengaluru');
      expect(line(['Bengaluru', 'Pune', 'New Jersey']), 'Bengaluru, Pune, New Jersey');
      expect(line(['Bengaluru', 'Mumbai', 'Delhi', 'Hyderabad']), 'Bengaluru, Mumbai, Delhi & more');
      expect(line(['Bengaluru', 'Bengaluru', 'Pune']), 'Bengaluru, Pune', reason: 'a city once');
    });

    test('the councils line is the first council by its short name and how many more', () {
      String? line(List<String> names) => ProfileDrawerData(name: 'A B', councilNames: names).councilsLine;
      expect(line([]), isNull);
      expect(line(['Sustainability, ESG & Net-Zero Council']), 'Sustainability, ESG & Net-Zero');
      expect(line(['CXO Workplace Strategy & FM Leadership']), 'CXO Workplace Strategy & FM Leadership');
      expect(
        line(['Sustainability, ESG & Net-Zero Council', 'CXO Workplace Strategy & FM Leadership', 'Workplace Council']),
        'Sustainability, ESG & Net-Zero +2',
      );
    });

    test('the CPD pill reads whole hours plainly and tenths with one decimal; none, no pill', () {
      String? pill(double? hours) => ProfileDrawerData(name: 'A B', cpdHours: hours).cpdLabel;
      expect(pill(12), '+12 CPD');
      expect(pill(8.5), '+8.5 CPD');
      expect(pill(0), isNull);
      expect(pill(null), isNull);
    });

    test('a chapter badge is the city\'s airport-style code, or its first three letters', () {
      expect(chapterCodeFor('Bengaluru'), 'BLR');
      expect(chapterCodeFor('  new delhi '), 'DEL');
      expect(chapterCodeFor('New Jersey'), 'NEW');
      expect(chapterCodeFor('Pune'), 'PNQ');
      expect(chapterCodeFor('Ab'), 'AB');
    });

    test('the initials come from the first and last word of the name', () {
      expect(const ProfileDrawerData(name: 'Bharat Buyer').initials, 'BB');
      expect(const ProfileDrawerData(name: 'Madonna').initials, 'M');
      expect(const ProfileDrawerData(name: '  ').initials, '?');
    });
  });
}

/// What the portal answers Bharat's menu with: the profile (headline, photo, cover), the public member (city,
/// follows, chapters, councils), the profile's views, his discussions' views and his CPD ledger.
Map<String, Handler> _memberRoutes() => {
  'GET /users/me/profile': (_) => {
    'user': {
      'id': 'me',
      'firstName': 'Bharat',
      'lastName': 'Buyer',
      'profileSlug': 'bharat-buyer',
      'designation': 'Lead Operations Manager at TechCorp',
      'avatarUrl': null,
      'coverImage': null,
    },
    'company': null,
    'resume': {'location': null},
  },
  'GET /members/me': (_) => {
    'id': 'me',
    'profileSlug': 'bharat-buyer',
    'headline': 'Lead Operations Manager · TechCorp',
    'city': 'Bengaluru, Karnataka',
    'follow': {'followers': 255, 'following': 12, 'viewerFollows': false},
    'chapters': [
      {'slug': 'bengaluru', 'name': 'ICR Bengaluru Chapter', 'city': 'Bengaluru'},
      {'slug': 'pune', 'name': 'ICR Pune Chapter', 'city': 'Pune'},
      {'slug': 'new-jersey', 'name': 'ICR New Jersey Chapter', 'city': 'New Jersey'},
    ],
    'councils': [
      {'slug': 'sustainability', 'name': 'Sustainability, ESG & Net-Zero Council'},
      {'slug': 'cxo', 'name': 'CXO Workplace Strategy & FM Leadership'},
      {'slug': 'workplace', 'name': 'Workplace & Employee Experience Council'},
    ],
  },
  'GET /users/me/profile-performance': (_) => {'profileViewsTotal': 42, 'profileViews30d': 42},
  'GET /forum/threads': (_) =>
      page([threadCard('a', views: 640), threadCard('b', views: 410), threadCard('c', views: 154)]),
  'GET /mentorship/cpd/summary': (_) => {'totalHours': 12, 'hoursThisYear': 8.5},
};
