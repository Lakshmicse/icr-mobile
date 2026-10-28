import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/app_screens.dart';
import 'package:icr_mobile/core/util/links.dart';
import 'package:icr_mobile/core/util/site_policy.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart';
import 'package:icr_mobile/features/web/in_app_web_screen.dart';
import 'package:icr_mobile/features/web/web_session.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'helpers/fonts.dart';

/// Every hand-off to the website, in the order the app tries them: its own screen, then its web view, and
/// the phone only for what a web view should not do. See `docs/WEBSITE_HANDOFFS.md`.
void main() {
  final site = Uri.parse('https://icr.org.in');

  group('SitePolicy', () {
    test('a page of the website is the same scheme, host and port', () {
      expect(SitePolicy.isSite(Uri.parse('https://icr.org.in/privacy'), site: site), isTrue);
      expect(SitePolicy.isSite(Uri.parse('https://icr.org.in:443/privacy'), site: site), isTrue);
      expect(SitePolicy.isSite(Uri.parse('http://icr.org.in/privacy'), site: site), isFalse);
      expect(SitePolicy.isSite(Uri.parse('https://www.icr.org.in/privacy'), site: site), isFalse);
      expect(SitePolicy.isSite(Uri.parse('https://icr.org.in.evil.example/privacy'), site: site), isFalse);
      expect(SitePolicy.isSite(Uri.parse('mailto:a@b.co'), site: site), isFalse);
      expect(SitePolicy.isSite(Uri.parse('/privacy'), site: site), isFalse);
    });

    test('a local site is told apart by its port', () {
      final local = Uri.parse('http://localhost:3000');
      expect(SitePolicy.isSite(Uri.parse('http://localhost:3000/jobs'), site: local), isTrue);
      expect(SitePolicy.isSite(Uri.parse('http://localhost:3001/api/v1'), site: local), isFalse);
    });

    test('a payment return, an upload and a file stay with the phone', () {
      for (final path in [
        '/api/v1/payments/payu/callback',
        '/uploads/docs/brochure.pdf',
        '/payments/receipt',
        '/events/summit/ticket.ics',
        '/files/report.XLSX',
        '/.well-known/assetlinks.json',
        '/auth/callback?code=abc123',
        '/auth/callback',
      ]) {
        expect(SitePolicy.staysExternal(Uri.parse('https://icr.org.in$path')), isTrue, reason: path);
      }
    });

    test('an ordinary page does not', () {
      for (final path in ['/privacy', '/terms', '/advertise', '/events/summit', '/community/hello.world', '/']) {
        expect(SitePolicy.staysExternal(Uri.parse('https://icr.org.in$path')), isFalse, reason: path);
      }
    });

    test('the web view follows the site and blank pages; everything else goes to the phone', () {
      WebNavigation nav(String url) => SitePolicy.navigation(Uri.parse(url), site: site);
      expect(nav('https://icr.org.in/privacy'), WebNavigation.inApp);
      expect(nav('https://icr.org.in/jobs?search=hvac#top'), WebNavigation.inApp);
      expect(nav('about:blank'), WebNavigation.inApp);
      expect(nav('data:text/html,hi'), WebNavigation.inApp);
      expect(nav('https://www.payu.in/_payment'), WebNavigation.external);
      expect(nav('https://accounts.google.com/o/oauth2/auth'), WebNavigation.external);
      expect(nav('mailto:contact@icr.org.in'), WebNavigation.external);
      expect(nav('tel:+919876543210'), WebNavigation.external);
      expect(nav('intent://scan/#Intent;scheme=zxing;end'), WebNavigation.external);
      expect(nav('whatsapp://send?text=hi'), WebNavigation.external);
      expect(nav('https://icr.org.in/uploads/brochure.pdf'), WebNavigation.external);
    });

    test("the sign-in return leg is never the web view's or the routing's: the secure tab hands it to the app", () {
      final callback = Uri.parse('https://icr.org.in/auth/callback?code=abc123');
      expect(SitePolicy.navigation(callback, site: site), WebNavigation.external);
      SiteRoutes.resolver = (_) => null;
      SiteRoutes.webView = (c, uri) async {};
      addTearDown(() {
        SiteRoutes.resolver = null;
        SiteRoutes.webView = null;
      });
      expect(SiteRoutes.inApp(callback), isNull);
      expect(SiteRoutes.inApp(Uri.parse('https://icr.org.in/auth/callbacks')), isNull);
      expect(SiteRoutes.inApp(Uri.parse('https://icr.org.in/auth')), isNotNull, reason: 'only the callback is excluded');
    });
  });

  group('SiteRoutes (what a hand-off to the website opens)', () {
    final opened = <String>[];

    setUp(() {
      opened.clear();
      SiteRoutes.resolver = null;
      SiteRoutes.webView = null;
    });
    tearDown(() {
      SiteRoutes.resolver = null;
      SiteRoutes.webView = null;
    });

    Future<void> run(WidgetTester tester, Uri uri, {bool inApp = true}) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final launches = <String>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'launch') launches.add((call.arguments as Map)['url'] as String);
        return true;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
      await openUrl(context, uri, inApp: inApp);
      opened.addAll(launches.map((u) => 'browser:$u'));
    }

    SiteRouteOpener? nativeFor(Uri uri) =>
        uri.path == '/notifications' ? (c) async => opened.add('native:${uri.path}') : null;

    testWidgets('a page the app has a screen for opens that screen', (tester) async {
      SiteRoutes.resolver = nativeFor;
      SiteRoutes.webView = (c, uri) async => opened.add('web:${uri.path}');
      await run(tester, Uri.parse('https://icr.org.in/notifications'));
      expect(opened, ['native:/notifications']);
    });

    testWidgets('any other page of the website opens in the web view, not the browser', (tester) async {
      SiteRoutes.resolver = nativeFor;
      SiteRoutes.webView = (c, uri) async => opened.add('web:${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}');
      await run(tester, Uri.parse('https://icr.org.in/advertise'));
      await run(tester, Uri.parse('https://icr.org.in/privacy?lang=hi'));
      expect(opened, ['web:/advertise', 'web:/privacy?lang=hi']);
    });

    testWidgets('a download, a payment or another site goes to the phone', (tester) async {
      SiteRoutes.resolver = nativeFor;
      SiteRoutes.webView = (c, uri) async => opened.add('web:${uri.path}');
      await run(tester, Uri.parse('https://icr.org.in/uploads/brochure.pdf'));
      await run(tester, Uri.parse('https://icr.org.in/api/v1/payments/payu/return'));
      await run(tester, Uri.parse('https://www.linkedin.com/in/someone'));
      await run(tester, Uri.parse('https://meet.google.com/abc-defg-hij'));
      expect(opened, [
        'browser:https://icr.org.in/uploads/brochure.pdf',
        'browser:https://icr.org.in/api/v1/payments/payu/return',
        'browser:https://www.linkedin.com/in/someone',
        'browser:https://meet.google.com/abc-defg-hij',
      ]);
    });

    testWidgets('inApp: false keeps a page on the website itself (a checkout)', (tester) async {
      SiteRoutes.resolver = nativeFor;
      SiteRoutes.webView = (c, uri) async => opened.add('web:${uri.path}');
      await run(tester, Uri.parse('https://icr.org.in/pricing/professional'), inApp: false);
      expect(opened, ['browser:https://icr.org.in/pricing/professional']);
    });

    testWidgets('openExternal sends a paper page to the browser even though the app has a screen for it', (tester) async {
      // The app draws /learning/assessment/<code>/<slug> itself; a "Pay on the website" button must reach the
      // website's page (its checkout), not land back on that screen.
      SiteRoutes.resolver = (uri) => uri.path.startsWith('/learning/') ? (c) async => opened.add('native:${uri.path}') : null;
      SiteRoutes.webView = (c, uri) async => opened.add('web:${uri.path}');
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final launches = <String>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'launch') launches.add((call.arguments as Map)['url'] as String);
        return true;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

      final paper = Uri.parse('https://icr.org.in/learning/mock-tests/aee-cem/aee-cem-set-1');
      await openExternal(context, paper);
      expect(launches, [paper.toString()]);
      expect(opened, isEmpty, reason: 'neither the app screen nor the web view');

      // openUrl, by contrast, would have taken the app's screen.
      await openUrl(context, paper);
      expect(opened, ['native:/learning/mock-tests/aee-cem/aee-cem-set-1']);
    });

    testWidgets('with nothing set (a screen in a test), the browser, as before', (tester) async {
      await run(tester, Uri.parse('https://icr.org.in/privacy'));
      expect(opened, ['browser:https://icr.org.in/privacy']);
    });

    test('inApp() is null for a payment, a file and another site, whatever is set', () {
      SiteRoutes.resolver = (_) => null;
      SiteRoutes.webView = (c, uri) async {};
      expect(SiteRoutes.inApp(Uri.parse('https://icr.org.in/privacy')), isNotNull);
      expect(SiteRoutes.inApp(Uri.parse('https://icr.org.in/uploads/a.pdf')), isNull);
      expect(SiteRoutes.inApp(Uri.parse('https://example.org/privacy')), isNull);
    });
  });

  group('the app\'s own screens for pages of the website', () {
    final viewer = DemoFeedRepository.me;
    bool takesIn(BuildContext? shell, String url) =>
        inAppSiteRoute(Uri.parse(url), viewer: viewer, shell: shell) != null;
    bool takes(String url) => takesIn(null, url);

    test('a record\'s page, a section page and every door open the app\'s screen', () {
      for (final url in [
        'https://icr.org.in/notifications',
        'https://icr.org.in/pricing/supplier',
        'https://icr.org.in/career/plans',
        'https://icr.org.in/membership/history',
        'https://icr.org.in/events/rsm-summit-2026',
        'https://icr.org.in/mentorship/mentors/MP1',
        'https://icr.org.in/mentorship/mentors/MP1#reviews',
        'https://icr.org.in/members/jane-doe',
        'https://icr.org.in/network',
        'https://icr.org.in/vendors/V1',
        'https://icr.org.in/messaging',
        'https://icr.org.in/messaging?c=C1',
        'https://icr.org.in/become-a-mentor',
        'https://icr.org.in/mentorship/become-a-mentor',
        'https://icr.org.in/mentorship/programmes',
        'https://icr.org.in/account/companies/new',
        'https://icr.org.in/quote',
        'https://icr.org.in/contact',
        'https://icr.org.in/contact?subject=Enrol%20me',
        'https://icr.org.in/events',
        'https://icr.org.in/chapters',
        'https://icr.org.in/councils',
        'https://icr.org.in/documents',
        'https://icr.org.in/get-involved',
        'https://icr.org.in/rfq/new',
        'https://icr.org.in/profile',
        'https://icr.org.in/profile?tab=security',
        'https://icr.org.in/account/companies/new?role=VENDOR',
      ]) {
        expect(takes(url), isTrue, reason: url);
      }
    });

    test('the tabs, the small pages and the records named by a slug need no more than the app', () {
      for (final url in [
        'https://icr.org.in/privacy',
        'https://icr.org.in/terms',
        'https://icr.org.in/blogs',
        'https://icr.org.in/blogs/welcome-to-icr',
        'https://icr.org.in/refer',
        'https://icr.org.in/advertise',
        'https://icr.org.in/learning/partners/apply',
        'https://icr.org.in/learning/partners?apply=1',
        'https://icr.org.in/account/companies',
        'https://icr.org.in/jobs',
        'https://icr.org.in/jobs?q=hvac',
        'https://icr.org.in/learning',
        'https://icr.org.in/learning/professional-development',
        'https://icr.org.in/learning/professional-development/AEE-CBCP',
        'https://icr.org.in/learning/assessment',
        'https://icr.org.in/learning/assessment/capital-planning',
        'https://icr.org.in/learning/verify?id=ICR-123',
        'https://icr.org.in/learning/certificates/ICR-123',
        'https://icr.org.in/mentorship',
        'https://icr.org.in/mentorship/mentors',
        'https://icr.org.in/mentorship/my?tab=purchases',
        'https://icr.org.in/mentorship/mentor-desk',
        'https://icr.org.in/mentorship/cpd',
        'https://icr.org.in/community',
        'https://icr.org.in/vendors',
        'https://icr.org.in/services',
        'https://icr.org.in/products',
        'https://icr.org.in/rfq',
        'https://icr.org.in/rfq/R1?section=bids',
        'https://icr.org.in/manage/requirements/R1',
        'https://icr.org.in/chapters/bengaluru',
        'https://icr.org.in/councils/sustainability-esg',
      ]) {
        expect(takes(url), isTrue, reason: url);
      }
    });

    testWidgets('a record whose screen reads the app providers is taken once there is a shell to read them from', (
      tester,
    ) async {
      late BuildContext shell;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              shell = c;
              return const SizedBox();
            },
          ),
        ),
      );
      for (final url in [
        'https://icr.org.in/jobs/J1',
        'https://icr.org.in/community/implementing-iot-sensors',
        'https://icr.org.in/community/implementing-iot-sensors?reply=R9',
        'https://icr.org.in/companies/C1',
        'https://icr.org.in/companies/C1?tab=reviews',
        'https://icr.org.in/products/P1',
        'https://icr.org.in/manage/jobs',
        'https://icr.org.in/manage/jobs/new',
        'https://icr.org.in/manage/jobs/J1',
        'https://icr.org.in/manage/jobs/J1/edit',
        'https://icr.org.in/manage/jobs/J1/applicants',
        // The candidate's side: the application page is where every stage move, interview and offer lands.
        'https://icr.org.in/career',
        'https://icr.org.in/career/applications',
        'https://icr.org.in/career/applications?tab=offers',
        'https://icr.org.in/career/applications/A1',
        'https://icr.org.in/career/alerts',
        'https://icr.org.in/career/invitations',
        'https://icr.org.in/career/interviews',
      ]) {
        expect(takes(url), isFalse, reason: '$url has no shell to read JobsController / FeedController from');
        expect(takesIn(shell, url), isTrue, reason: url);
      }
    });

    test('what is left for the web view is what the app has no screen for, each on purpose', () {
      for (final url in [
        // The company workspace: the KYC dossier with its document uploads, and the team and office admin.
        'https://icr.org.in/company',
        'https://icr.org.in/company?tab=verification',
        'https://icr.org.in/manage/team',
        'https://icr.org.in/manage/articles',
        'https://icr.org.in/support',
        'https://icr.org.in/support/T1',
        'https://icr.org.in/talent',
        'https://icr.org.in/events/rsm-summit-2026/extra',
        'https://icr.org.in/community/category/hvac',
      ]) {
        expect(takes(url), isFalse, reason: url);
        expect(takesIn(null, url), isFalse, reason: url);
      }
    });
  });

  group('WebSessionBridge', () {
    String jwt(Map<String, Object?> claims) {
      String part(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
      return '${part({'alg': 'HS256'})}.${part(claims)}.signature';
    }

    test('reads the seconds a token has left', () {
      final now = DateTime.utc(2026, 10, 27, 12);
      final exp = now.add(const Duration(minutes: 10)).millisecondsSinceEpoch ~/ 1000;
      expect(WebSessionBridge.secondsLeft(jwt({'exp': exp}), now: now), 600);
      expect(WebSessionBridge.secondsLeft(jwt({'exp': exp - 1200}), now: now), -600);
    });

    test('a token with no expiry, or no token at all, has none to read', () {
      expect(WebSessionBridge.secondsLeft(jwt({'sub': 'u1'})), isNull);
      expect(WebSessionBridge.secondsLeft('not-a-jwt'), isNull);
      expect(WebSessionBridge.secondsLeft('a.b.c'), isNull);
    });

    test('the script sets the access token and removes the refresh token, so the page never renews itself', () {
      final script = WebSessionBridge.script('abc.def.ghi');
      expect(script, contains("localStorage.setItem('icr.accessToken',\"abc.def.ghi\")"));
      expect(script, contains("localStorage.removeItem('icr.refreshToken')"));
      expect(script, isNot(contains("setItem('icr.refreshToken'")));
    });

    test('a token is quoted, never concatenated into the script', () {
      final script = WebSessionBridge.script('x");alert(1);("');
      expect(script, contains(r'"x\");alert(1);(\""'));
    });

    test('closing the screen clears both keys', () {
      expect(WebSessionBridge.clearScript, allOf(contains('icr.accessToken'), contains('icr.refreshToken')));
    });
  });

  group('InAppWebScreen', () {
    late _FakeWebPlatform platform;
    late _FakeController web;

    setUpAll(() async {
      await loadAppFonts();
    });

    setUp(() {
      platform = _FakeWebPlatform();
      WebViewPlatform.instance = platform;
    });

    Future<void> pump(
      WidgetTester tester, {
      Uri? uri,
      Future<String?> Function()? accessToken,
      List<Uri>? launched,
      bool launchOk = true,

      /// A signed-out page has loaded once the screen is up (as a real one does). The loading state is a spinner
      /// that never settles, so a test of it passes false and pumps by hand.
      bool loaded = true,
    }) async {
      final controller = WebViewController();
      web = controller.platform as _FakeController;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => InAppWebScreen(
                        uri: uri ?? Uri.parse('https://icr.org.in/privacy'),
                        title: 'Privacy',
                        accessToken: accessToken,
                        controller: controller,
                        site: site,
                        launchExternal: (u) async {
                          launched?.add(u);
                          return launchOk;
                        },
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      if (loaded && accessToken == null) {
        web.delegate.onPageFinished!((uri ?? Uri.parse('https://icr.org.in/privacy')).toString());
      }
      await tester.pump();
      await tester.pump();
    }

    Future<NavigationDecision> request(String url, {bool mainFrame = true}) async =>
        await web.delegate.onNavigationRequest!(NavigationRequest(url: url, isMainFrame: mainFrame));

    testWidgets('signed out, it loads the page and asks for no session', (tester) async {
      await pump(tester);
      expect(web.loaded, ['https://icr.org.in/privacy']);
      expect(web.scripts, isEmpty);
      expect(find.text('Privacy'), findsOneWidget);
    });

    testWidgets('signed in, it fills the page\'s storage from a page of the same site, then loads the page', (
      tester,
    ) async {
      await pump(tester, accessToken: () async => 'tok.en.value', uri: Uri.parse('https://icr.org.in/dashboard'));
      expect(web.loaded, ['https://icr.org.in/robots.txt'], reason: 'the storage is written before the page runs');
      expect(web.scripts, isEmpty);

      web.delegate.onPageFinished!('https://icr.org.in/robots.txt');
      await tester.pump();
      expect(web.scripts.single, contains('"tok.en.value"'));
      expect(web.loaded, ['https://icr.org.in/robots.txt', 'https://icr.org.in/dashboard']);
    });

    testWidgets('a page of another site never gets the session', (tester) async {
      var asked = false;
      await pump(
        tester,
        uri: Uri.parse('https://example.org/page'),
        accessToken: () async {
          asked = true;
          return 'tok.en.value';
        },
      );
      expect(asked, isFalse);
      expect(web.loaded, ['https://example.org/page']);
      expect(web.scripts, isEmpty);
    });

    testWidgets('a link on the site stays in the view', (tester) async {
      await pump(tester);
      expect(await request('https://icr.org.in/terms'), NavigationDecision.navigate);
    });

    testWidgets('another site, mail and the dialler go to the phone, and the view stays put', (tester) async {
      final launched = <Uri>[];
      await pump(tester, launched: launched);
      for (final url in ['https://www.payu.in/_payment', 'mailto:contact@icr.org.in', 'tel:+919876543210']) {
        expect(await request(url), NavigationDecision.prevent, reason: url);
      }
      await tester.pump();
      expect(launched.map((u) => u.toString()), [
        'https://www.payu.in/_payment',
        'mailto:contact@icr.org.in',
        'tel:+919876543210',
      ]);
    });

    testWidgets('a download of the site goes to the phone too', (tester) async {
      final launched = <Uri>[];
      await pump(tester, launched: launched);
      expect(await request('https://icr.org.in/uploads/brochure.pdf'), NavigationDecision.prevent);
      expect(launched.single.path, '/uploads/brochure.pdf');
    });

    testWidgets('a frame inside the page (a video, a map) is the page\'s own business', (tester) async {
      final launched = <Uri>[];
      await pump(tester, launched: launched);
      expect(await request('https://www.youtube.com/embed/abc', mainFrame: false), NavigationDecision.navigate);
      expect(launched, isEmpty);
    });

    testWidgets('a link the phone cannot open says so', (tester) async {
      await pump(tester, launchOk: false);
      await request('https://www.payu.in/_payment');
      await tester.pumpAndSettle();
      expect(find.textContaining("Couldn't open www.payu.in"), findsOneWidget);
    });

    testWidgets('the page names itself in the bar when it has loaded', (tester) async {
      await pump(tester);
      web.title = 'Terms of Service | ICR';
      web.delegate.onPageFinished!('https://icr.org.in/privacy');
      await tester.pump();
      await tester.pump();
      expect(find.text('Terms of Service | ICR'), findsOneWidget);
    });

    testWidgets('the page is covered by white until it has finished: never a black or a plain-text frame', (
      tester,
    ) async {
      await pump(tester, loaded: false);
      final cover = find.byKey(const Key('web.loading'));
      expect(cover, findsOneWidget, reason: 'the web view opens under the app own loading state');
      expect(
        tester.widget<ColoredBox>(find.descendant(of: cover, matching: find.byType(ColoredBox)).first).color,
        Colors.white,
      );
      web.delegate.onPageFinished!('https://icr.org.in/privacy');
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('web.loading')), findsNothing);
    });

    testWidgets('with a session to carry across, the static page it is written from is never shown', (tester) async {
      await pump(tester, accessToken: () async => 'tok.en.value', uri: Uri.parse('https://icr.org.in/dashboard'));
      web.delegate.onPageFinished!('https://icr.org.in/robots.txt');
      await tester.pump();
      expect(find.byKey(const Key('web.loading')), findsOneWidget, reason: '/robots.txt has finished, the page has not');
      web.delegate.onPageFinished!('https://icr.org.in/dashboard');
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('web.loading')), findsNothing);
    });

    testWidgets('the web view itself is painted white too', (tester) async {
      await pump(tester, loaded: false);
      expect(web.backgroundColor, Colors.white);
    });

    testWidgets('a progress line shows while the page loads', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('web.progress')), findsNothing);
      web.delegate.onProgress!(40);
      await tester.pump();
      expect(find.byKey(const Key('web.progress')), findsOneWidget);
      web.delegate.onProgress!(100);
      await tester.pump();
      expect(find.byKey(const Key('web.progress')), findsNothing);
    });

    testWidgets('Back goes back through the page\'s history first, then leaves the screen', (tester) async {
      await pump(tester);
      web.canGoBackNow = true;
      await tester.tap(find.byKey(const Key('web.back')));
      await tester.pumpAndSettle();
      expect(web.wentBack, 1);
      expect(find.byType(InAppWebScreen), findsOneWidget);

      web.canGoBackNow = false;
      await tester.tap(find.byKey(const Key('web.back')));
      await tester.pumpAndSettle();
      expect(find.byType(InAppWebScreen), findsNothing);
    });

    testWidgets('the hardware Back button does the same', (tester) async {
      await pump(tester);
      web.canGoBackNow = true;
      web.delegate.onUrlChange!(UrlChange(url: 'https://icr.org.in/terms'));
      await tester.pump();
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(web.wentBack, 1);
      expect(find.byType(InAppWebScreen), findsOneWidget);

      web.canGoBackNow = false;
      web.delegate.onUrlChange!(UrlChange(url: 'https://icr.org.in/privacy'));
      await tester.pump();
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(InAppWebScreen), findsNothing);
    });

    testWidgets('Close leaves the screen from anywhere in the history', (tester) async {
      await pump(tester);
      web.canGoBackNow = true;
      await tester.tap(find.byKey(const Key('web.close')));
      await tester.pumpAndSettle();
      expect(find.byType(InAppWebScreen), findsNothing);
    });

    testWidgets('closing takes the session out of the page\'s storage', (tester) async {
      await pump(tester, accessToken: () async => 'tok.en.value');
      await tester.tap(find.byKey(const Key('web.close')));
      await tester.pumpAndSettle();
      expect(web.scripts.last, WebSessionBridge.clearScript);
    });

    testWidgets('a page that fails to load offers to try again', (tester) async {
      await pump(tester);
      web.delegate.onWebResourceError!(
        WebResourceError(errorCode: -2, description: 'net::ERR_INTERNET_DISCONNECTED', isForMainFrame: true),
      );
      await tester.pump();
      expect(find.text("This page didn't load."), findsOneWidget);
      await tester.tap(find.byKey(const Key('web.retry')));
      expect(web.reloaded, 1);
    });
  });
}

// ── A web view that draws nothing and remembers what it was asked ─────────────────────────────────────────

class _FakeWebPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(PlatformWebViewControllerCreationParams params) =>
      _FakeController(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(PlatformNavigationDelegateCreationParams params) =>
      _FakeDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(PlatformWebViewWidgetCreationParams params) =>
      _FakeWidget(params);
}

class _FakeController extends PlatformWebViewController {
  _FakeController(super.params) : super.implementation();

  final loaded = <String>[];
  final scripts = <String>[];
  String? title;
  Color? backgroundColor;
  bool canGoBackNow = false;
  int wentBack = 0;
  int reloaded = 0;
  late _FakeDelegate delegate;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async => backgroundColor = color;

  /// The view reads every page fresh (a stage moved on the web shows at once).
  var cacheCleared = 0;
  @override
  Future<void> clearCache() async => cacheCleared++;

  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate handler) async =>
      delegate = handler as _FakeDelegate;

  @override
  Future<void> loadRequest(LoadRequestParams params) async => loaded.add(params.uri.toString());

  @override
  Future<void> runJavaScript(String javaScript) async => scripts.add(javaScript);

  @override
  Future<String?> getTitle() async => title;

  @override
  Future<bool> canGoBack() async => canGoBackNow;

  @override
  Future<void> goBack() async => wentBack++;

  @override
  Future<void> reload() async => reloaded++;
}

class _FakeDelegate extends PlatformNavigationDelegate {
  _FakeDelegate(super.params) : super.implementation();

  NavigationRequestCallback? onNavigationRequest;
  PageEventCallback? onPageFinished;
  PageEventCallback? onPageStarted;
  ProgressCallback? onProgress;
  WebResourceErrorCallback? onWebResourceError;
  UrlChangeCallback? onUrlChange;

  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback onNavigationRequest) async =>
      this.onNavigationRequest = onNavigationRequest;

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async => this.onPageStarted = onPageStarted;

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async => this.onPageFinished = onPageFinished;

  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async => this.onProgress = onProgress;

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback onWebResourceError) async =>
      this.onWebResourceError = onWebResourceError;

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async => this.onUrlChange = onUrlChange;
}

class _FakeWidget extends PlatformWebViewWidget {
  _FakeWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand(key: Key('web.fake'));
}
