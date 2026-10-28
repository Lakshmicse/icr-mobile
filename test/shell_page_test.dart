import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/shell/app_shell.dart';
import 'package:icr_mobile/features/shell/icr_bottom_nav.dart';
import 'package:icr_mobile/features/shell/shell_page.dart';

Widget _app({required Map<String, WidgetBuilder> doors}) => MaterialApp(
  theme: buildAppTheme(),
  home: AppShell(
    drawer: const Drawer(child: Text('the profile menu')),
    home: const Scaffold(body: Center(child: Text('the feed'))),
    doors: doors,
  ),
);

Future<void> _openEvents(WidgetTester tester) async {
  await tester.tap(find.text('Discover'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Events'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a pushed screen keeps the bar, lit on its own tab, and a tab leaves it', (tester) async {
    await tester.pumpWidget(
      _app(
        doors: {
          '/events': (_) => const ShellPage(
            tab: AppTab.home,
            child: Center(child: Text('the events screen')),
          ),
        },
      ),
    );
    await _openEvents(tester);
    expect(find.text('the events screen'), findsOneWidget);
    // The pushed screen's own bar is the one on show: the shell's is covered.
    expect(find.byType(IcrBottomNav).hitTestable(), findsOneWidget);
    expect(tester.widget<IcrBottomNav>(find.byType(IcrBottomNav).hitTestable()).current, AppTab.home);

    await tester.tap(find.text('Learning').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('the events screen'), findsNothing);
    expect(find.text('Learning is coming to the app'), findsOneWidget);
    expect(tester.widget<IcrBottomNav>(find.byType(IcrBottomNav)).current, AppTab.learning);
  });

  testWidgets('"open this tab" works from a route the shell did not push (the notifications list, a sheet)', (
    tester,
  ) async {
    await tester.pumpWidget(_app(doors: const {}));
    late BuildContext outside;
    // A plain route pushed on the app's navigator, not with AppShell.push: it is not under the shell.
    Navigator.of(tester.element(find.text('the feed'))).push(
      MaterialPageRoute<void>(
        builder: (c) {
          outside = c;
          return const Scaffold(body: Text('a route outside the shell'));
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('a route outside the shell'), findsOneWidget);

    AppShell.goToTab(outside, AppTab.jobs);
    await tester.pumpAndSettle();

    expect(find.text('a route outside the shell'), findsNothing, reason: 'the route is left');
    expect(tester.widget<IcrBottomNav>(find.byType(IcrBottomNav)).current, AppTab.jobs);
  });

  testWidgets('a screen pushed from a pushed screen is left in one go by a tab', (tester) async {
    await tester.pumpWidget(
      _app(
        doors: {
          '/events': (ctx) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => AppShell.push<void>(
                  ctx,
                  (_) => const ShellPage(
                    tab: AppTab.mentorship,
                    child: Center(child: Text('the second screen')),
                  ),
                ),
                child: const Text('open another'),
              ),
            ),
          ),
        },
      ),
    );
    await _openEvents(tester);
    await tester.tap(find.text('open another'));
    await tester.pumpAndSettle();
    expect(find.text('the second screen'), findsOneWidget);

    await tester.tap(find.text('Jobs').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('the second screen'), findsNothing);
    expect(find.text('open another'), findsNothing);
    expect(find.text('Jobs is coming to the app'), findsOneWidget);
  });

  testWidgets('the Discover tab on a pushed screen opens the Discover sheet over the shell', (tester) async {
    await tester.pumpWidget(
      _app(
        doors: {
          '/events': (_) => const ShellPage(
            tab: AppTab.home,
            child: Center(child: Text('the events screen')),
          ),
        },
      ),
    );
    await _openEvents(tester);

    await tester.tap(find.text('Discover').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('the events screen'), findsNothing);
    expect(find.text('Regional Chapters'), findsOneWidget);
  });

  group('Back with the profile menu open', () {
    // Android decides whether a Back press reaches the app or closes it from the last
    // `setFrameworkHandlesBack` the framework sent, so this is what "Back exits the app" is made of.
    bool? handlesBack;

    setUp(() => handlesBack = null);

    Future<void> mockPlatform(WidgetTester tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemNavigator.setFrameworkHandlesBack') handlesBack = call.arguments as bool;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      // The framework tells the engine nothing until the app is in the foreground.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }

    Future<void> openMenu(WidgetTester tester) async {
      tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
      await tester.pumpAndSettle();
      expect(find.text('the profile menu'), findsOneWidget);
    }

    testWidgets('on Home the app keeps Back while the menu is open, then lets go of it', (tester) async {
      await mockPlatform(tester);
      await tester.pumpWidget(_app(doors: const {}));
      await tester.pumpAndSettle();
      await openMenu(tester);

      expect(handlesBack, isTrue, reason: 'Android would otherwise close the app with the menu still open');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('the profile menu'), findsNothing);
      expect(find.text('the feed'), findsOneWidget);
      // Menu shut, nothing open: the next Back leaves the app as it always did.
      expect(handlesBack, isFalse);
    });

    testWidgets('on another tab Back closes the menu first and keeps the tab', (tester) async {
      await mockPlatform(tester);
      await tester.pumpWidget(_app(doors: const {}));
      await tester.tap(find.text('Learning'));
      await tester.pumpAndSettle();
      expect(tester.widget<IcrBottomNav>(find.byType(IcrBottomNav)).current, AppTab.learning);
      await openMenu(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('the profile menu'), findsNothing);
      expect(tester.widget<IcrBottomNav>(find.byType(IcrBottomNav)).current, AppTab.learning);

      // The second Back is the one that goes Home.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.widget<IcrBottomNav>(find.byType(IcrBottomNav)).current, AppTab.home);
    });
  });

  testWidgets('a tab is built the first time it is opened, and kept with its place after', (tester) async {
    var jobsBuilt = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AppShell(
          home: const Scaffold(body: Center(child: Text('the feed'))),
          jobs: Builder(
            builder: (_) {
              jobsBuilt++;
              return const Scaffold(
                body: Center(child: TextField(key: ValueKey('jobs-search'))),
              );
            },
          ),
        ),
      ),
    );
    // Opening the app builds Home alone.
    expect(jobsBuilt, 0);

    await tester.tap(find.text('Jobs'));
    await tester.pumpAndSettle();
    expect(jobsBuilt, 1);
    await tester.enterText(find.byKey(const ValueKey('jobs-search')), 'facility');

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jobs'));
    await tester.pumpAndSettle();

    expect(jobsBuilt, 1);
    expect(find.text('facility'), findsOneWidget);
  });
}
