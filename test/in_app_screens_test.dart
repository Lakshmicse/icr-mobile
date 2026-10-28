import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/app_screens.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/auth/auth_controller.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/discover/discover_sheet.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart';
import 'package:icr_mobile/features/profile/profile_drawer.dart';
import 'package:icr_mobile/features/profile/profile_drawer_data.dart';
import 'package:icr_mobile/features/shell/app_shell.dart';
import 'package:provider/provider.dart';

import 'helpers/fonts.dart';

class _NoTokens extends TokenStore {
  @override
  Future<String?> accessToken() async => null;
  @override
  Future<String?> refreshToken() async => null;
}

/// The shell as the app builds it, with the screens it really opens, on the
/// design's sample content.
Future<void> _pumpShell(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);

  final tokens = _NoTokens();
  final auth = AuthController(
    api: ApiClient(tokens: tokens),
    tokens: tokens,
  );
  final screens = inAppScreens(viewer: DemoFeedRepository.me, demo: true);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => ProfileDrawerController.demo()),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: AppShell(
          drawer: ProfileDrawer(screens: screens),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(onPressed: () => AppShell.openDrawer(ctx), child: const Text('open menu')),
              ),
            ),
          ),
          doors: screens,
        ),
      ),
    ),
  );
}

/// A few frames, not `pumpAndSettle`: a spinner never settles.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  setUpAll(loadAppFonts);

  test('every Discover door but Advertise (a paid placement) opens an app screen, never the website', () {
    final screens = inAppScreens(viewer: DemoFeedRepository.me, demo: true);
    final doors = [
      for (final row in [...DiscoverSheet.community, ...DiscoverSheet.business]) ...[row.left, row.right],
    ];
    expect(doors, hasLength(8));
    final leaving = [
      for (final d in doors)
        if (!screens.containsKey(d.sitePath)) d.sitePath,
    ];
    // Hire and Sell once fell through to Chrome because only `/profile` and the community doors were mapped.
    expect(leaving, ['/advertise']);
  });

  testWidgets('Working Councils opens from the profile menu without a framework error', (tester) async {
    await _pumpShell(tester);
    await tester.tap(find.text('open menu'));
    await _frames(tester);
    await tester.tap(find.text('Working Councils'));
    await _frames(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Your Joined Councils'), findsOneWidget);
  });

  testWidgets('Working Councils opens from the Discover sheet without a framework error', (tester) async {
    await _pumpShell(tester);
    await tester.tap(find.text('Discover'));
    await _frames(tester);
    await tester.tap(find.text('Working Councils'));
    await _frames(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Your Joined Councils'), findsOneWidget);
  });

  testWidgets('Events opens from the Discover sheet without a framework error, with the bar under it', (tester) async {
    await _pumpShell(tester);
    await tester.tap(find.text('Discover'));
    await _frames(tester);
    await tester.tap(find.text('Events'));
    await _frames(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Explore by Category'), findsOneWidget);
    expect(find.text('Mentorship').hitTestable(), findsOneWidget);
  });
}
