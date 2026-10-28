@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/widgets/detail_sheet.dart';
import 'package:icr_mobile/features/events/demo_events_repository.dart';
import 'package:icr_mobile/features/events/event_detail_controller.dart';
import 'package:icr_mobile/features/events/event_models.dart' show eventsNow;
import 'package:icr_mobile/features/events/event_sheet.dart';
import 'package:icr_mobile/features/events/events_controller.dart';
import 'package:icr_mobile/features/events/events_screen.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart';
import 'package:provider/provider.dart';

import '../helpers/events_fixtures.dart';
import '../helpers/fonts.dart';

/// The Events screens at the designs' frames, exported at 2x to build/screens/
/// (`events_home.png`, `event_sheet.png`) for tool/design/compare.py.
void main() {
  // The designs' sample events are dated Oct 24, 2026. Pin the clock to the week before, or each of them
  // turns into "Ended" the day that date passes and every golden below changes with it.
  final realNow = eventsNow;
  setUpAll(() async {
    eventsNow = () => DateTime(2026, 10, 20, 9);
    await loadAppFonts();
  });
  tearDownAll(() => eventsNow = realNow);

  Future<void> precacheAll(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
  }

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

  testWidgets('events home (demo content) at 390 × 2154.5', (tester) async {
    tester.view.physicalSize = const Size(780, 4309);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final events = EventsController(DemoEventsRepository());
    await tester.runAsync(events.start);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ChangeNotifierProvider.value(
          value: events,
          child: EventsScreen(onBack: () {}, viewer: DemoFeedRepository.me, onAccount: () {}),
        ),
      ),
    );
    await precacheAll(tester);
    await export(tester, find.byType(EventsScreen), 'events_home');
    await expectLater(find.byType(EventsScreen), matchesGoldenFile('goldens/events_home.png'));
  });

  testWidgets('event sheet (demo content) at 390 × 1130.5', (tester) async {
    tester.view.physicalSize = const Size(780, 2261);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final repo = DemoEventsRepository();
    final controller = EventDetailController(repository: repo, seed: repo.sheetEvent);
    await tester.runAsync(controller.load);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ChangeNotifierProvider<EventsController>(
          create: (_) => EventsController(repo),
          child: ChangeNotifierProvider.value(
            value: controller,
            child: const Scaffold(
              backgroundColor: Colors.white,
              body: DetailSheetFrame(
                topInset: 0,
                handleTop: 10,
                handleHeight: 24,
                body: EventSheetBody(),
                bottomBar: EventSheetBar(),
              ),
            ),
          ),
        ),
      ),
    );
    await precacheAll(tester);
    await export(tester, find.byType(DetailSheetFrame), 'event_sheet');
    await expectLater(find.byType(DetailSheetFrame), matchesGoldenFile('goldens/event_sheet.png'));
  });

  // The same screens over what the API gives, through the real repository (a fake API with fixed dates, so
  // the render is the same every day): the category tiles are council tracks, the circles carry the host's
  // initials, a card's second line is its first speaker, the agenda has indicative times, the pass card has
  // the event's code. `build/screens/events_home_api.png` and `event_sheet_api.png` are what to put beside
  // the designs; the pictures differ from the demo's because the fixtures carry no covers.
  EventsWorld apiShapedWorld() {
    // Indian clock on October 2099.
    DateTime at(int day, int hour, [int minute = 0]) =>
        DateTime.utc(2099, 10, day, hour, minute).subtract(const Duration(hours: 5, minutes: 30));
    const vinfraa = 'ICR Vinfraa & PropTech India Chapter';
    final world = EventsWorld(
      events: [
        eventRow(
          'flag',
          'Global CRE PropTech Summit 2026',
          kind: 'CONFERENCE',
          on: at(24, 8),
          length: const Duration(hours: 15),
          location: 'Mumbai Convention Centre & Hybrid',
          chapter: vinfraa,
          going: 185,
        ),
        eventRow('ai', 'Future of AI in Facility Management', on: at(24, 16), going: 184),
        eventRow(
          'summit',
          'Global CRE PropTech Summit 2026',
          kind: 'CONFERENCE',
          on: at(25, 9),
          length: const Duration(days: 2, hours: 8),
          location: 'Mumbai Convention Centre, Bandra Kurla Complex',
          chapter: vinfraa,
          price: 1500000,
          going: 184,
        ),
        eventRow(
          'gcc',
          'Sustainable GCC Campus & Net-Zero Operations',
          kind: 'ROUNDTABLE',
          on: at(25, 14, 30),
          length: const Duration(minutes: 150),
          location: 'Bengaluru',
          council: 'CXO Workplace Strategy & FM Leadership Council',
          capacity: 25,
          going: 7,
          invite: true,
        ),
        eventRow(
          'bms',
          'Smart BMS & Predictive Maintenance Masterclass',
          kind: 'WORKSHOP',
          on: at(26, 10),
          length: const Duration(hours: 6),
          location: 'Bangalore HQ',
          council: 'Smart Buildings, BMS & PropTech Council',
          going: 36,
        ),
        eventRow(
          'fbis',
          'Future of Business & Innovation Summit 2024',
          kind: 'CONFERENCE',
          on: at(27, 10),
          length: const Duration(hours: 6, minutes: 30),
          location: 'Grand Auditorium, Hall 3 • Mumbai Convention Centre',
          chapter: vinfraa,
          going: 184,
          description:
              '<p>The ICR Future of Business &amp; Innovation Summit convenes commercial real estate directors, chief sustainability officers, and facility operations leaders to explore autonomous building technologies, predictive maintenance workflows, and net-zero portfolio decarbonization.</p>'
              '<ul><li><strong>Smart IoT &amp; FM Automation</strong>: Deploying integrated digital twins across campus environments.</li>'
              '<li><strong>ESG &amp; Decarbonization</strong>: Operational benchmarking for RICS and LEED zero-carbon audits.</li></ul>',
        ),
        eventRow(
          'esg',
          'ESG Mandates: BRSR Core & Scope 3',
          on: at(28, 15, 30),
          council: 'Sustainability, ESG & Net-Zero Council',
          going: 82,
        ),
      ],
    );
    world.places
      ..clear()
      ..['fbis'] = 'GOING'
      ..['esg'] = 'GOING';
    world.talks.clear();
    world.talks['ai'] = [
      {
        'id': 't1',
        'title': 'Future of AI in Facility Management',
        'abstract': 'Where AI already pays for itself in facility management.',
        'bio': 'VP Sustainable PropTech',
        'speaker': {'id': 'u1', 'firstName': 'Dr. Radhika', 'lastName': 'Iyer'},
      },
    ];
    world.talks['fbis'] = [
      {
        'id': 't2',
        'title': 'The Autonomous Facility: 2025 Architecture',
        'abstract': 'Keynote on the architecture of the autonomous facility.',
        'bio': 'VP Global Real Estate, Infosys',
        'speaker': {'id': 'u2', 'firstName': 'Rajesh', 'lastName': 'Sharma'},
      },
      {
        'id': 't3',
        'title': 'Retrofitting Commercial Towers with Smart Sensors',
        'abstract': 'Panel on retrofitting commercial towers with smart sensors.',
        'bio': 'IGBC AP',
        'speaker': {'id': 'u3', 'firstName': 'Priya', 'lastName': 'Nambiar'},
      },
    ];
    return world;
  }

  testWidgets('events home (API-shaped content) at 390 × 2154.5', (tester) async {
    tester.view.physicalSize = const Size(780, 4309);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final events = EventsController(repoOn(FakeApi(apiShapedWorld().routes())));
    await tester.runAsync(() async {
      await events.start();
      await events.speakersSettled;
    });
    addTearDown(events.dispose);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ChangeNotifierProvider.value(
          value: events,
          child: EventsScreen(onBack: () {}, viewer: DemoFeedRepository.me, onAccount: () {}),
        ),
      ),
    );
    await precacheAll(tester);
    await export(tester, find.byType(EventsScreen), 'events_home_api');
    await expectLater(find.byType(EventsScreen), matchesGoldenFile('goldens/events_home_api.png'));
  });

  testWidgets('event sheet (API-shaped content) at 390 × 1130.5', (tester) async {
    tester.view.physicalSize = const Size(780, 2261);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final events = EventsController(repoOn(FakeApi(apiShapedWorld().routes())));
    late EventDetailController controller;
    await tester.runAsync(() async {
      await events.start();
      controller = EventDetailController(
        repository: events.repository,
        seed: events.agenda.firstWhere((e) => e.id == 'fbis'),
      );
      await controller.load();
    });
    addTearDown(events.dispose);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ChangeNotifierProvider<EventsController>.value(
          value: events,
          child: ChangeNotifierProvider.value(
            value: controller,
            child: const Scaffold(
              backgroundColor: Colors.white,
              body: DetailSheetFrame(
                topInset: 0,
                handleTop: 10,
                handleHeight: 24,
                body: EventSheetBody(),
                bottomBar: EventSheetBar(),
              ),
            ),
          ),
        ),
      ),
    );
    await precacheAll(tester);
    await export(tester, find.byType(DetailSheetFrame), 'event_sheet_api');
    await expectLater(find.byType(DetailSheetFrame), matchesGoldenFile('goldens/event_sheet_api.png'));
  });
}
