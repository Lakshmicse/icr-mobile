import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/discover/discover_sheet.dart';
import 'package:icr_mobile/features/shell/app_shell.dart';
import 'package:flutter/services.dart';

Widget _shell() => MaterialApp(
  theme: buildAppTheme(),
  home: const AppShell(
    home: Scaffold(body: Center(child: Text('the feed'))),
  ),
);

void main() {
  testWidgets('a door with an in-app screen opens it, and Back returns to the shell', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AppShell(
          home: const Scaffold(body: Center(child: Text('the feed'))),
          doors: {'/events': (_) => const Scaffold(body: Center(child: Text('the events screen')))},
        ),
      ),
    );
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();
    expect(find.text('the events screen'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('the events screen'), findsNothing);
    expect(find.text('the feed'), findsOneWidget);
    // The sheet closed when the door was taken.
    expect(find.text('Regional Chapters'), findsNothing);
  });

  testWidgets('a screen a door opened can open the profile menu, which leaves it first', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AppShell(
          drawer: const Drawer(child: Text('the profile menu')),
          home: const Scaffold(body: Center(child: Text('the feed'))),
          doors: {
            '/events': (ctx) => Scaffold(
              body: Center(
                child: TextButton(onPressed: () => AppShell.openDrawer(ctx), child: const Text('my photo')),
              ),
            ),
          },
        ),
      ),
    );
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();
    expect(find.text('my photo'), findsOneWidget);

    await tester.tap(find.text('my photo'));
    await tester.pumpAndSettle();
    expect(find.text('my photo'), findsNothing);
    expect(find.text('the profile menu'), findsOneWidget);
  });

  testWidgets('Discover opens the sheet over the tab, and Back closes it', (tester) async {
    await tester.pumpWidget(_shell());
    expect(find.text('Regional Chapters'), findsNothing);

    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    expect(find.text('Regional Chapters'), findsOneWidget);
    expect(find.text('Advertise'), findsOneWidget);
    // The tab is still there underneath.
    expect(find.text('the feed'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Regional Chapters'), findsNothing);
    expect(find.text('the feed'), findsOneWidget);
  });

  testWidgets('with the sheet closed the tab gets every tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AppShell(
          home: Scaffold(
            body: Center(
              child: TextButton(onPressed: () => taps++, child: const Text('like')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('like'));
    expect(taps, 1);

    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('like'), warnIfMissed: false);
    await tester.pumpAndSettle();
    // That tap landed on the page behind the sheet, which closes it.
    expect(taps, 1);
    expect(find.text('Regional Chapters'), findsNothing);
  });

  testWidgets('tapping the page behind the sheet closes it', (tester) async {
    await tester.pumpWidget(_shell());
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(200, 80));
    await tester.pumpAndSettle();
    expect(find.text('Regional Chapters'), findsNothing);
  });

  testWidgets('the Discover tab toggles the sheet and another tab closes it', (tester) async {
    await tester.pumpWidget(_shell());
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    expect(find.text('Regional Chapters'), findsNothing);

    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jobs'));
    await tester.pumpAndSettle();
    expect(find.text('Regional Chapters'), findsNothing);
    expect(find.text('Jobs is coming to the app'), findsOneWidget);
  });

  testWidgets('each door names the page it opens on the website', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: DiscoverSheet(onOpen: (door) => opened.add(door.sitePath)),
          ),
        ),
      ),
    );
    for (final label in ['Regional Chapters', 'Events', 'Post requirement', 'Hire']) {
      await tester.tap(find.text(label));
    }
    expect(opened, ['/chapters', '/events', '/rfq/new', '/account/companies/new?role=COMPANY_ADMIN']);
  });

  group('every door', () {
    /// The shell with the two screens the app has (Councils and Events) and the browser's channel listened to.
    Future<List<Uri>> pumpShell(WidgetTester tester) async {
      final launched = <Uri>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'launch') launched.add(Uri.parse((call.arguments as Map)['url'] as String));
        return call.method == 'launch' || call.method == 'canLaunch';
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: AppShell(
            home: const Scaffold(body: Center(child: Text('the feed'))),
            doors: {
              '/councils': (_) => const Scaffold(body: Center(child: Text('the councils screen'))),
              '/events': (_) => const Scaffold(body: Center(child: Text('the events screen'))),
            },
          ),
        ),
      );
      return launched;
    }

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
    }

    testWidgets('the sheet has the eight doors in the design\'s order, and the For Business rule between the rows', (
      tester,
    ) async {
      await pumpShell(tester);
      await openSheet(tester);
      final labels = [
        'Regional Chapters',
        'Working Councils',
        'Digital Library',
        'Events',
        'For Business',
        'Hire',
        'Sell',
        'Post requirement',
        'Advertise',
      ];
      // Top to bottom, left to right.
      final spots = [for (final l in labels) tester.getTopLeft(find.text(l))];
      for (var i = 1; i < spots.length; i++) {
        final a = spots[i - 1], b = spots[i];
        expect(b.dy > a.dy || (b.dy == a.dy && b.dx > a.dx), isTrue, reason: '${labels[i - 1]} then ${labels[i]}');
      }
      expect(DiscoverSheet.community.expand((r) => [r.left, r.right]).map((d) => d.label), labels.take(4));
      expect(DiscoverSheet.business.expand((r) => [r.left, r.right]).map((d) => d.label), labels.skip(5));
    });

    testWidgets('each door\'s artwork is a bundled picture', (tester) async {
      for (final row in [...DiscoverSheet.community, ...DiscoverSheet.business]) {
        for (final door in [row.left, row.right]) {
          final data = await rootBundle.load('assets/images/icons/${door.icon}');
          expect(data.lengthInBytes, greaterThan(100), reason: door.label);
        }
      }
    });

    testWidgets('Councils and Events open the app\'s own screens; Back brings the shell back each time', (
      tester,
    ) async {
      final launched = await pumpShell(tester);
      for (final (label, screen) in [('Working Councils', 'the councils screen'), ('Events', 'the events screen')]) {
        await openSheet(tester);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.text(screen), findsOneWidget, reason: label);
        expect(find.text('Regional Chapters'), findsNothing, reason: 'the sheet closed when the door was taken');

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text(screen), findsNothing);
        expect(find.text('the feed'), findsOneWidget);
      }
      expect(launched, isEmpty, reason: 'nothing went to the browser');
    });

    testWidgets('every other door opens its page on the website, query and all, and closes the sheet', (tester) async {
      final launched = await pumpShell(tester);
      const doors = {
        'Regional Chapters': 'https://icr.org.in/chapters',
        'Digital Library': 'https://icr.org.in/documents',
        'Hire': 'https://icr.org.in/account/companies/new?role=COMPANY_ADMIN',
        'Sell': 'https://icr.org.in/account/companies/new?role=VENDOR',
        'Post requirement': 'https://icr.org.in/rfq/new',
        'Advertise': 'https://icr.org.in/advertise',
      };
      for (final entry in doors.entries) {
        launched.clear();
        await openSheet(tester);
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(launched.map((u) => u.toString()), [entry.value], reason: entry.key);
        expect(find.text('Regional Chapters'), findsNothing, reason: '${entry.key} closes the sheet');
        expect(find.text('the feed'), findsOneWidget);
      }
    });

    testWidgets('a door\'s whole box is the target, not only its words', (tester) async {
      final launched = await pumpShell(tester);
      await openSheet(tester);
      // Near the box's right edge, far from the label: still the Hire door.
      final box = tester.getRect(find.text('Hire'));
      await tester.tapAt(Offset(box.right + 60, box.center.dy));
      await tester.pumpAndSettle();
      expect(launched.single.queryParameters['role'], 'COMPANY_ADMIN');
    });

    testWidgets('dragging the sheet down closes it, and a short drag settles back open', (tester) async {
      await pumpShell(tester);
      await openSheet(tester);
      final handle = tester.getCenter(find.text('For Business')) - const Offset(0, 150);
      await tester.dragFrom(handle, const Offset(0, 40));
      await tester.pumpAndSettle();
      expect(find.text('Regional Chapters'), findsOneWidget, reason: 'a short pull springs back');

      await tester.dragFrom(handle, const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.text('Regional Chapters'), findsNothing);
      expect(find.text('the feed'), findsOneWidget);
    });
  });
}
