@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/auth/auth_controller.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/auth/sign_in_screen.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart';
import 'package:icr_mobile/features/feed/feed_controller.dart';
import 'package:icr_mobile/features/feed/home_screen.dart';
import 'package:icr_mobile/features/account/account_models.dart';
import 'package:icr_mobile/features/account/demo_account_repository.dart';
import 'package:icr_mobile/features/profile/profile_drawer.dart';
import 'package:icr_mobile/features/profile/profile_drawer_data.dart';
import 'package:icr_mobile/features/shell/app_shell.dart';
import 'package:icr_mobile/features/shell/icr_bottom_nav.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';

/// Renders the screens at the design's frame (390 wide, 2x) so they can be
/// laid over the design image. Refresh with `flutter test --update-goldens
/// --tags golden`.
void main() {
  setUpAll(loadAppFonts);

  Future<void> precacheAll(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
      final context = tester.element(find.byType(Scaffold).first);
      await precacheImage(const AssetImage('assets/images/demo/sponsored_bg.jpg'), context);
    });
    await tester.pumpAndSettle();
  }

  /// Also writes the screen at 2x to build/screens/, the scale of the design
  /// export, for laying the two side by side.
  Future<void> export(WidgetTester tester, Finder finder, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.ancestor(of: finder, matching: find.byType(RepaintBoundary)).first,
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/screens').createSync(recursive: true);
      File('build/screens/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('home (demo content) at 390 × 1996', (tester) async {
    tester.view.physicalSize = const Size(780, 3992);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final feed = FeedController(DemoFeedRepository());
    await tester.runAsync(feed.start);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ChangeNotifierProvider.value(
          value: feed,
          child: HomeScreen(viewer: DemoFeedRepository.me, onAccount: () {}),
        ),
      ),
    );
    await precacheAll(tester);
    await export(tester, find.byType(HomeScreen), 'home_demo');
    await expectLater(find.byType(HomeScreen), matchesGoldenFile('goldens/home_demo.png'));
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('sign in ($mode) at 390 × 844', (tester) async {
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final tokens = _NoTokens();
      final api = ApiClient(tokens: tokens);
      // Production offers both providers; answer as it does, with no network.
      api.dio.httpClientAdapter = _ProvidersReply();
      final auth = AuthController(api: api, tokens: tokens);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: ChangeNotifierProvider.value(value: auth, child: const SignInScreen()),
        ),
      );
      // Let the providers request finish on the test clock.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await precacheAll(tester);
      // The design shows an address and a password typed in.
      await tester.enterText(find.byKey(const Key('signIn.email')), 'chetukpl49@gmail.com');
      await tester.enterText(find.byKey(const Key('signIn.password')), 'password123');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await export(tester, find.byType(SignInScreen), 'sign_in_$mode');
      await expectLater(find.byType(SignInScreen), matchesGoldenFile('goldens/sign_in_$mode.png'));
    });
  }

  testWidgets('bottom navigation at 390 wide', (tester) async {
    tester.view.physicalSize = const Size(780, 108);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: Scaffold(
          backgroundColor: Colors.white,
          body: RepaintBoundary(
            child: Align(
              alignment: Alignment.topCenter,
              child: IcrBottomNav(current: AppTab.home, onSelect: (_) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await export(tester, find.byType(IcrBottomNav), 'bottom_nav');
    await expectLater(find.byType(IcrBottomNav), matchesGoldenFile('goldens/bottom_nav.png'));
  });
  testWidgets('discover sheet over home at 390 × 767', (tester) async {
    tester.view.physicalSize = const Size(780, 1534);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final feed = FeedController(DemoFeedRepository());
    await tester.runAsync(feed.start);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ChangeNotifierProvider.value(
          value: feed,
          child: AppShell(
            home: HomeScreen(viewer: DemoFeedRepository.me, onAccount: () {}),
          ),
        ),
      ),
    );
    await precacheAll(tester);
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    // The doors' artwork.
    await precacheAll(tester);
    await export(tester, find.byType(AppShell), 'discover_sheet');
    await expectLater(find.byType(AppShell), matchesGoldenFile('goldens/discover_sheet.png'));
  });

  testWidgets('profile drawer (demo content) at 307 × 760', (tester) async {
    tester.view.physicalSize = const Size(614, 1520);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final tokens = _NoTokens();
    final auth = AuthController(
      api: ApiClient(tokens: tokens),
      tokens: tokens,
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => ProfileDrawerController.demo()),
          ],
          child: const Scaffold(backgroundColor: Colors.white, body: ProfileDrawer()),
        ),
      ),
    );
    await precacheAll(tester);
    await export(tester, find.byType(ProfileDrawer), 'profile_drawer');
    await expectLater(find.byType(ProfileDrawer), matchesGoldenFile('goldens/profile_drawer.png'));
  });

  testWidgets('profile drawer with Your companies (3 of 4, one active) on a 360 dp phone', (tester) async {
    tester.view.physicalSize = const Size(720, 1520);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final tokens = _NoTokens();
    final auth = AuthController(api: ApiClient(tokens: tokens), tokens: tokens);
    final repo = DemoAccountRepository(
      companies: const MyCompanies(
        personalRole: 'PROFESSIONAL',
        companies: [
          MyCompany(companyId: 'co-north', name: 'Northwind Facilities', role: 'PROFESSIONAL'),
          MyCompany(companyId: 'co-tech', name: 'TechCorp', role: 'COMPANY_ADMIN', active: true),
          MyCompany(companyId: 'co-globe', name: 'Global Infra Solutions Private Limited', role: 'VENDOR'),
          MyCompany(companyId: 'co-harbor', name: 'Harbor Soft Services', role: 'BUYER'),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => ProfileDrawerController.demo()),
          ],
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: ProfileDrawer.width, child: ProfileDrawer(companiesRepository: repo)),
            ),
          ),
        ),
      ),
    );
    await precacheAll(tester);
    await tester.pumpAndSettle();
    await export(tester, find.byType(ProfileDrawer), 'profile_drawer_companies');
    await expectLater(find.byType(ProfileDrawer), matchesGoldenFile('goldens/profile_drawer_companies.png'));
  });
}

/// `GET /auth/social/providers` as production answers it.
class _ProvidersReply implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"providers":["GOOGLE","LINKEDIN"]}',
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

/// Signed out, with no platform keystore in tests.
class _NoTokens extends TokenStore {
  @override
  Future<String?> accessToken() async => null;
  @override
  Future<String?> refreshToken() async => null;
}
