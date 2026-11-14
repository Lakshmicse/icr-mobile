import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/util/links.dart';
import 'package:icr_mobile/core/util/screen_trail.dart';
import 'package:icr_mobile/features/shell/app_shell.dart';
import 'package:icr_mobile/features/shell/icr_bottom_nav.dart';

/// Android ends an app in the background when another app needs the memory; coming back, the app opened on Home
/// (owner, 14 Nov 2026: "the ICR will refresh from current screen to home screen"). `restartAndRestore` is what
/// Android does: the app is built again from nothing but the state the activity saved.
Widget _app({String restorationId = 'shell-u1-c1'}) => MaterialApp(
  theme: buildAppTheme(),
  restorationScopeId: 'icr',
  navigatorObservers: [ScreenTrail.instance],
  home: AppShell(
    restorationId: restorationId,
    home: const Scaffold(body: Center(child: Text('the feed'))),
    jobs: const Scaffold(body: Center(child: Text('the jobs board'))),
  ),
);

/// The pages the test's "website" has: each opens a page saying which it is, as `SiteRoutes.resolver` does in the app.
SiteRouteOpener? _resolver(Uri uri) {
  const pages = {'/jobs/42': 'job 42', '/members/7': 'member 7'};
  final title = pages[uri.path];
  if (title == null) return null;
  return (ctx) => AppShell.push<void>(ctx, (c) => Scaffold(body: Center(child: Text(title))));
}

AppTab _tab(WidgetTester tester) => tester.widget<IcrBottomNav>(find.byType(IcrBottomNav).first).current;

BuildContext _inShell(WidgetTester tester) => tester.element(find.text('the feed', skipOffstage: false));

void main() {
  setUp(() => SiteRoutes.resolver = _resolver);
  tearDown(() => SiteRoutes.resolver = null);

  testWidgets('the app comes back on the tab it was on', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('Jobs'));
    await tester.pumpAndSettle();
    expect(_tab(tester), AppTab.jobs);

    await tester.restartAndRestore();
    expect(_tab(tester), AppTab.jobs);
    expect(find.text('the jobs board'), findsOneWidget);
  });

  testWidgets('the app comes back to the screen it was on, opened again as its link opens it', (tester) async {
    await tester.pumpWidget(_app());
    unawaited(openSitePage(_inShell(tester), '/jobs/42'));
    await tester.pumpAndSettle();
    expect(find.text('job 42'), findsOneWidget);
    expect(ScreenTrail.instance.place, '/jobs/42');

    await tester.restartAndRestore();
    await tester.pumpAndSettle();
    expect(find.text('job 42'), findsOneWidget);

    // Back from it is the tabs, as before.
    Navigator.of(tester.element(find.text('job 42'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('job 42'), findsNothing);
    expect(_tab(tester), AppTab.home);
  });

  testWidgets('a screen opened by a tap says which page it is; a dialog or an unmarked screen over it keeps it', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final shell = _inShell(tester);
    unawaited(
      AppShell.push<void>(
        shell,
        (c) => const SitePlace(
          path: '/members/7',
          child: Scaffold(body: Text('a member, tapped')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(ScreenTrail.instance.place, '/members/7');

    final member = tester.element(find.text('a member, tapped'));
    unawaited(
      showDialog<void>(
        context: member,
        builder: (_) => const AlertDialog(content: Text('a dialog')),
      ),
    );
    await tester.pumpAndSettle();
    expect(ScreenTrail.instance.place, '/members/7');
    Navigator.of(tester.element(find.text('a dialog'))).pop();
    await tester.pumpAndSettle();

    unawaited(AppShell.push<void>(member, (c) => const Scaffold(body: Text('a form with no page'))));
    await tester.pumpAndSettle();
    expect(ScreenTrail.instance.place, '/members/7');

    await tester.restartAndRestore();
    await tester.pumpAndSettle();
    expect(find.text('member 7'), findsOneWidget);
  });

  testWidgets('leaving every screen leaves nothing to reopen', (tester) async {
    await tester.pumpWidget(_app());
    unawaited(openSitePage(_inShell(tester), '/jobs/42'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('job 42'))).pop();
    await tester.pumpAndSettle();
    expect(ScreenTrail.instance.place, isNull);

    await tester.restartAndRestore();
    await tester.pumpAndSettle();
    expect(find.text('job 42'), findsNothing);
    expect(_tab(tester), AppTab.home);
  });

  testWidgets('another account (or company) never gets the saved tab and screen', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('Jobs'));
    await tester.pumpAndSettle();
    unawaited(openSitePage(_inShell(tester), '/jobs/42'));
    await tester.pumpAndSettle();
    final saved = await tester.getRestorationData();

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(restorationId: 'shell-u2-c2'));
    await tester.restoreFrom(saved);
    await tester.pumpAndSettle();
    expect(_tab(tester), AppTab.home);
    expect(find.text('job 42'), findsNothing);
  });
}
