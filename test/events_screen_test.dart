import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/events/event_pass.dart';
import 'package:icr_mobile/features/events/events_controller.dart';
import 'package:icr_mobile/features/events/event_sheet.dart';
import 'package:icr_mobile/features/events/events_screen.dart';
import 'package:icr_mobile/features/events/widgets/event_card.dart';
import 'package:icr_mobile/features/events/widgets/qr_code.dart';
import 'package:icr_mobile/features/events/widgets/spotlight_card.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'helpers/events_fixtures.dart';
import 'helpers/fonts.dart';

/// Every control of the Events board and of an event's sheet, pressed on the real screens over the real
/// repository, with only the API faked (`helpers/events_fixtures.dart`) and the two platform channels it
/// ends in (the browser, the share sheet) listened to. What the API itself does in answer is proved by
/// `test/live/events_live_test.dart`.
void main() {
  setUpAll(loadAppFonts);

  /// The addresses the browser was asked to open, and what the share sheet was given.
  final launched = <Uri>[];
  final shared = <Map<String, dynamic>>[];
  var accountTapped = 0;

  setUp(() {
    launched.clear();
    shared.clear();
    accountTapped = 0;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), (call) async {
      if (call.method == 'launch') launched.add(Uri.parse((call.arguments as Map)['url'] as String));
      return call.method == 'launch' || call.method == 'canLaunch';
    });
    messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/share'), (call) async {
      shared.add(Map<String, dynamic>.from(call.arguments as Map));
      return null;
    });
  });

  tearDown(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), null);
    messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/share'), null);
  });

  /// Lets work that waits on the real event loop (the fake API's futures) finish, then draws.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
  }

  late FakeApi api;
  late EventsWorld world;
  late EventsController events;

  Future<void> pumpBoard(WidgetTester tester, {EventsWorld? custom, double height = 7000}) async {
    tester.view.physicalSize = Size(780, height);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    world = custom ?? EventsWorld();
    api = FakeApi(world.routes());
    events = EventsController(repoOn(api));
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
          child: EventsScreen(onBack: () {}, viewer: DemoFeedRepository.me, onAccount: () => accountTapped++),
        ),
      ),
    );
    await settle(tester);
  }

  Finder cardOf(String id) => find.byWidgetPredicate((w) => w is EventCard && w.event.id == id);
  Finder inCard(String id, Finder what) => find.descendant(of: cardOf(id), matching: what);
  Finder spotlight() => find.byType(SpotlightCard);
  int cards() => find.byType(EventCard).evaluate().length;
  Set<String> shown() => {for (final e in find.byType(EventCard).evaluate()) (e.widget as EventCard).event.id};

  /// Taps a chip, first scrolling the row of chips sideways until the chip is on the screen.
  Future<void> tapChip(WidgetTester tester, String label) async {
    final row = find.descendant(of: find.byType(EventsToolbar), matching: find.byType(ListView));
    await tester.drag(row, const Offset(1000, 0)); // back to the first chip
    await tester.pumpAndSettle();
    for (var i = 0; i < 10; i++) {
      final chip = find.text(label);
      if (chip.evaluate().isNotEmpty) {
        final x = tester.getCenter(chip).dx;
        if (x > 30 && x < 340) break;
      }
      await tester.drag(row, const Offset(-120, 0));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  /// A button drawn past its card's edge, as the design draws "Get Tickets": its left end is what shows.
  Future<void> tapLeftEnd(WidgetTester tester, Finder f) async {
    // The board is taller than the test window at the app's text sizes: bring the button into view first.
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tapAt(tester.getTopLeft(f) + const Offset(10, 6));
    await settle(tester);
  }

  group('the board at rest', () {
    testWidgets('draws the flagship, the two tiles, the tracks and the agenda from the API', (tester) async {
      await pumpBoard(tester);
      expect(find.text('Events'), findsOneWidget);
      expect(find.text('SPOTLIGHT EVENT'), findsOneWidget);
      expect(find.text('CONFERENCE • HYBRID'), findsOneWidget, reason: 'a short, true kicker');
      expect(find.text('Free for members'), findsOneWidget);
      expect(find.text('500 Attendees Registered'), findsOneWidget);
      expect(find.text('RSVP Free'), findsOneWidget);
      expect(find.text('My Schedule (1)'), findsOneWidget);
      expect(find.textContaining('Future of AI in Facility Management'), findsWidgets);
      expect(find.text('CPD Earned'), findsOneWidget);
      expect(find.text('8.5 / 15'), findsOneWidget);
      expect(find.text('6.5 credits needed by Dec 31'), findsOneWidget);
      expect(find.text('Explore by Category'), findsOneWidget);
      expect(find.text('3 Tracks'), findsOneWidget);
      expect(find.text('Smart Buildings'), findsOneWidget);
      expect(find.text('Upcoming Agenda'), findsOneWidget);
      expect(find.text('6 Ready'), findsOneWidget);
      expect(cards(), 7);
      expect(shown(), isNot(contains('flag')), reason: 'the flagship is not repeated in the agenda');
      expect(find.text('Host or Propose an Event'), findsOneWidget);
    });

    testWidgets('the card of the first talk shows its speaker where the venue would be', (tester) async {
      await pumpBoard(tester);
      expect(inCard('ai', find.text('Dr. Radhika Iyer, VP Sustainable PropTech')), findsOneWidget);
      expect(inCard('bms', find.text('Bangalore HQ')), findsOneWidget);
      expect(inCard('gcc', find.text('By invitation only')), findsOneWidget);
    });

    testWidgets('the flagship\'s circles carry its host\'s initials', (tester) async {
      await pumpBoard(tester);
      for (final letter in ['I', 'V', 'P']) {
        expect(find.descendant(of: spotlight(), matching: find.text(letter)), findsOneWidget);
      }
    });

    testWidgets('"Next:" keeps the day and hour when the title is long', (tester) async {
      world = EventsWorld();
      world.byId('ai')['title'] = 'A very long title that cannot possibly fit on the one line of the tile';
      await pumpBoard(tester, custom: world);
      expect(find.textContaining(' • ', findRichText: true), findsWidgets);
      expect(
        find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith(' • ') && (w.data ?? '').contains(',')),
        findsOneWidget,
      );
    });

    testWidgets('a board that cannot load says so, offers a retry, and Back to Home', (tester) async {
      tester.view.physicalSize = const Size(780, 4000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      var homeTapped = 0;
      final routes = EventsWorld().routes();
      var down = true;
      final inner = routes['GET /events']!;
      routes['GET /events'] = (o) => down ? (503, '{"message":"The API is down."}') : inner(o);
      final controller = EventsController(repoOn(FakeApi(routes)));
      await tester.runAsync(controller.start);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ChangeNotifierProvider.value(
            value: controller,
            child: EventsScreen(onBack: () => homeTapped++, viewer: DemoFeedRepository.me, onAccount: () {}),
          ),
        ),
      );
      await settle(tester);
      expect(find.text("Couldn't load events"), findsOneWidget);
      expect(find.text('The API is down.'), findsOneWidget);

      await tester.tap(find.text('Back to Home'));
      expect(homeTapped, 1);

      down = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('Explore by Category'), findsOneWidget);
    });
  });

  group('the header', () {
    testWidgets('the photo opens the account menu and the bell opens the notifications page', (tester) async {
      await pumpBoard(tester);
      await tester.tap(find.bySemanticsLabel('Your account'));
      expect(accountTapped, 1);
      await tester.tap(find.byIcon(LucideIcons.bell));
      await tester.pump();
      expect(launched.single.toString(), 'https://icr.org.in/notifications');
    });

    testWidgets('the bell\'s red dot is the API\'s unread count', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpBoard(tester);
      expect(find.bySemanticsLabel('Notifications, 2 unread'), findsOneWidget);
      handle.dispose();
    });
  });

  group('search and the filter glyph', () {
    testWidgets('a search is sent to the API, narrows the board to its results, and Clear brings the board back', (
      tester,
    ) async {
      await pumpBoard(tester);
      await tester.enterText(find.byType(TextField), 'ESG');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      expect(api.queries.last['search'], 'ESG');
      expect(find.text('Events matching "ESG"'), findsOneWidget);
      expect(shown(), {'esg'});
      expect(find.text('SPOTLIGHT EVENT'), findsNothing, reason: 'a search shows its results alone');
      expect(find.text('Clear'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await settle(tester);
      expect(find.text('Upcoming Agenda'), findsOneWidget);
      expect(find.text('SPOTLIGHT EVENT'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
      expect(cards(), 7);
    });

    testWidgets('a search with no match says so', (tester) async {
      await pumpBoard(tester);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      expect(find.text('No events match'), findsOneWidget);
      expect(find.text('Try other words, or clear the filters.'), findsOneWidget);
    });

    testWidgets('the small cross in the field clears the search', (tester) async {
      await pumpBoard(tester);
      await tester.enterText(find.byType(TextField), 'ESG');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      await tester.tap(find.byIcon(LucideIcons.x));
      await settle(tester);
      expect(find.text('Upcoming Agenda'), findsOneWidget);
      expect(cards(), 7);
    });

    testWidgets('the filter glyph opens the filters; Past reads the past events', (tester) async {
      await pumpBoard(tester);
      await tester.tap(find.byIcon(LucideIcons.slidersHorizontal));
      await tester.pumpAndSettle();
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('When'), findsOneWidget);
      expect(find.text('Format'), findsOneWidget);
      await tester.tap(find.text('Past'));
      await tester.pump();
      await tester.tap(find.text('Show events'));
      await settle(tester);
      expect(api.queries.last['when'], 'past');
      expect(find.text('Past Events'), findsOneWidget);
      expect(shown(), {'old'});
    });

    testWidgets('Online keeps the online events and In person the others; Clear all comes back', (tester) async {
      await pumpBoard(tester);
      await tester.tap(find.byIcon(LucideIcons.slidersHorizontal));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Online'));
      await tester.pump();
      await tester.tap(find.text('Show events'));
      await settle(tester);
      expect(shown(), {'flag', 'ai', 'esg', 'zoom'});

      await tester.tap(find.byIcon(LucideIcons.slidersHorizontal));
      await tester.pumpAndSettle();
      await tester.tap(find.text('In person'));
      await tester.pump();
      await tester.tap(find.text('Show events'));
      await settle(tester);
      expect(shown(), {'flag', 'bms', 'summit', 'gcc', 'far'});

      await tester.tap(find.byIcon(LucideIcons.slidersHorizontal));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear all'));
      await settle(tester);
      expect(find.text('Upcoming Agenda'), findsOneWidget);
      expect(cards(), 7);
    });
  });

  group('the chips and the category tiles', () {
    testWidgets('each chip narrows the agenda; All Events brings it back', (tester) async {
      await pumpBoard(tester);
      expect(find.text('All Events'), findsOneWidget);

      await tapChip(tester, 'Webinars');
      expect(shown(), {'ai', 'esg'});
      await tapChip(tester, 'Conferences');
      expect(shown(), {'summit'});
      await tapChip(tester, 'Roundtables');
      expect(shown(), {'gcc'});
      await tapChip(tester, 'Workshops');
      expect(shown(), {'zoom', 'bms'});
      await tapChip(tester, 'Chapter meetups');
      expect(shown(), {'far'});

      await tapChip(tester, 'All Events');
      expect(cards(), 7);
    });

    testWidgets('"Upcoming (6)" keeps the events of the next 30 days', (tester) async {
      await pumpBoard(tester);
      await tester.tap(find.text('Upcoming (6)'));
      await tester.pumpAndSettle();
      expect(shown(), {'ai', 'esg', 'zoom', 'bms', 'summit', 'gcc'});
    });

    testWidgets('a tile narrows the agenda to its track, a second tap lifts it, Clear resets', (tester) async {
      await pumpBoard(tester);
      await tester.tap(find.text('Smart Buildings'));
      await tester.pumpAndSettle();
      expect(find.text('Smart Buildings Events'), findsOneWidget);
      expect(shown(), {'bms', 'far'});
      expect(find.text('Clear'), findsOneWidget);

      await tester.tap(find.text('Smart Buildings'));
      await tester.pumpAndSettle();
      expect(find.text('Upcoming Agenda'), findsOneWidget);
      expect(cards(), 7);

      await tester.tap(find.text('Sustainability'));
      await tester.pumpAndSettle();
      expect(shown(), {'esg', 'zoom'});
      await tester.tap(find.text('Clear'));
      await settle(tester);
      expect(find.text('Upcoming Agenda'), findsOneWidget);
      expect(cards(), 7);
    });

    testWidgets('a tile and a chip work together', (tester) async {
      await pumpBoard(tester);
      await tester.tap(find.text('Sustainability'));
      await tester.pumpAndSettle();
      await tapChip(tester, 'Workshops');
      expect(shown(), {'zoom'});
    });
  });

  group('the flagship card', () {
    testWidgets('its bookmark is kept on the device and toggles', (tester) async {
      await pumpBoard(tester);
      expect(find.descendant(of: spotlight(), matching: find.byIcon(LucideIcons.bookmark)), findsOneWidget);
      await tester.tap(find.descendant(of: spotlight(), matching: find.byIcon(LucideIcons.bookmark)));
      await tester.pump();
      expect(events.spotlight!.saved, isTrue);
      expect(find.descendant(of: spotlight(), matching: find.byIcon(LucideIcons.bookmarkCheck)), findsOneWidget);
      await tester.tap(find.descendant(of: spotlight(), matching: find.byIcon(LucideIcons.bookmarkCheck)));
      await tester.pump();
      expect(events.spotlight!.saved, isFalse);
      expect(api.calls.where((c) => c.startsWith('POST') || c.startsWith('DELETE')), isEmpty);
    });

    testWidgets('RSVP Free takes the place through the API, says so, and the tile counts it', (tester) async {
      await pumpBoard(tester);
      await tester.tap(find.text('RSVP Free'));
      await settle(tester);
      expect(api.calls, contains('POST /events/flag/rsvp'));
      expect(world.places['flag'], 'GOING');
      expect(find.text('You are registered.'), findsOneWidget);
      expect(find.text('Registered'), findsWidgets);
      expect(find.text('501 Attendees Registered'), findsOneWidget);
      expect(find.text('My Schedule (2)'), findsOneWidget);
    });

    testWidgets('a refusal puts the card back and shows the API\'s words', (tester) async {
      await pumpBoard(tester);
      world.refuseRsvp = 'Something the API said.';
      await tester.tap(find.text('RSVP Free'));
      await settle(tester);
      expect(find.text('Something the API said.'), findsOneWidget);
      expect(find.text('RSVP Free'), findsOneWidget);
      expect(find.text('500 Attendees Registered'), findsOneWidget);
      expect(find.text('My Schedule (1)'), findsOneWidget);
    });

    testWidgets('the card opens the sheet', (tester) async {
      await pumpBoard(tester);
      await tester.tap(find.descendant(of: spotlight(), matching: find.text('Global CRE PropTech Summit 2026')));
      await settle(tester);
      expect(find.text('About'), findsOneWidget);
      expect(find.text('Registration Open'), findsOneWidget);
    });
  });

  group('the cards of the agenda', () {
    testWidgets('Register Free takes a free seat, the footer then says Registered with a View button', (tester) async {
      await pumpBoard(tester);
      await tester.tap(inCard('esg', find.text('Register Free')));
      await settle(tester);
      expect(api.calls, contains('POST /events/esg/rsvp'));
      expect(world.places['esg'], 'GOING');
      expect(find.text('You are registered.'), findsOneWidget);
      expect(inCard('esg', find.text('Registered')), findsOneWidget);
      expect(inCard('esg', find.text('View')), findsOneWidget);
      expect(find.text('My Schedule (2)'), findsOneWidget);
    });

    testWidgets('Reserve Pass does the same for a workshop', (tester) async {
      await pumpBoard(tester);
      expect(inCard('zoom', find.text('2 CPD Points')), findsNothing, reason: 'the hours are the event\'s own length');
      await tester.ensureVisible(inCard('zoom', find.text('Reserve Pass')));
      await tester.pump();
      await tester.tap(inCard('zoom', find.text('Reserve Pass')));
      await settle(tester);
      expect(world.places['zoom'], 'GOING');
      expect(find.text('You are registered.'), findsOneWidget);
    });

    testWidgets('a refused Register Free leaves the card as it was', (tester) async {
      await pumpBoard(tester);
      world.refuseRsvp = 'No seats for you.';
      await tester.tap(inCard('esg', find.text('Register Free')));
      await settle(tester);
      expect(find.text('No seats for you.'), findsOneWidget);
      expect(inCard('esg', find.text('Register Free')), findsOneWidget);
      expect(world.places.containsKey('esg'), isFalse);
    });

    testWidgets('a full event\'s button joins the waitlist', (tester) async {
      world = EventsWorld();
      world.events.add(eventRow('full', 'Sold-out clinic', capacity: 5, going: 5, at: const Duration(days: 6)));
      world.waitlisted.add('full');
      await pumpBoard(tester, custom: world);
      expect(inCard('full', find.text('Waitlist open')), findsOneWidget);
      await tester.tap(inCard('full', find.text('Join Waitlist')));
      await settle(tester);
      expect(world.places['full'], 'WAITLISTED');
      expect(find.text('Added to the waitlist.'), findsOneWidget);
      expect(inCard('full', find.text('On the waitlist')), findsOneWidget);
    });

    testWidgets('Get Tickets opens the event\'s page on the website; nothing is registered', (tester) async {
      await pumpBoard(tester);
      expect(inCard('summit', find.text('₹15,000 per pass')), findsOneWidget);
      await tapLeftEnd(tester, inCard('summit', find.text('Get Tickets')));
      expect(launched.single.toString(), 'https://icr.org.in/events/slug-summit');
      expect(api.calls.where((c) => c.startsWith('POST')), isEmpty);
    });

    testWidgets('Details opens the sheet, for a priced event too', (tester) async {
      await pumpBoard(tester);
      await tester.tap(inCard('summit', find.text('Details')));
      await settle(tester);
      expect(launched, isEmpty);
      expect(find.text('Get Tickets'), findsWidgets);
      expect(find.text('About'), findsOneWidget);
      expect(find.text('Registration Open'), findsOneWidget);
    });

    testWidgets('an invite-only event\'s button is Details, and opens the sheet', (tester) async {
      await pumpBoard(tester);
      expect(inCard('gcc', find.text('18 / 25 Seats Left')), findsOneWidget);
      await tester.tap(inCard('gcc', find.text('Details')));
      await settle(tester);
      expect(world.places.containsKey('gcc'), isFalse);
      expect(find.text('Registration Open'), findsOneWidget);
    });

    testWidgets('View, on a place already held, opens the sheet', (tester) async {
      await pumpBoard(tester);
      expect(inCard('ai', find.text('Registered')), findsOneWidget);
      await tester.tap(inCard('ai', find.text('View')));
      await settle(tester);
      expect(find.text('Registration Confirmed'), findsOneWidget);
    });

    testWidgets('the card itself opens the sheet', (tester) async {
      await pumpBoard(tester);
      await tester.tap(inCard('bms', find.text('Smart BMS Masterclass')));
      await settle(tester);
      expect(find.text('Registration Open'), findsOneWidget);
    });

    testWidgets('share hands the share sheet the title and the event\'s page', (tester) async {
      await pumpBoard(tester);
      await tester.tap(inCard('esg', find.byIcon(LucideIcons.share2)));
      await tester.pump();
      expect(shared.single['text'], 'ESG Mandates: BRSR Core & Scope 3\nhttps://icr.org.in/events/slug-esg');
      expect(shared.single['subject'], 'ESG Mandates: BRSR Core & Scope 3');
    });

    testWidgets('the bookmark glyph toggles on its own card only', (tester) async {
      await pumpBoard(tester);
      await tester.ensureVisible(inCard('esg', find.byIcon(LucideIcons.bookmark)));
      await tester.pump();
      await tester.tap(inCard('esg', find.byIcon(LucideIcons.bookmark)));
      await tester.pump();
      expect(events.find('esg')!.saved, isTrue);
      expect(events.find('zoom')!.saved, isFalse);
      expect(inCard('esg', find.byIcon(LucideIcons.bookmarkCheck)), findsOneWidget);
      await tester.tap(inCard('esg', find.byIcon(LucideIcons.bookmarkCheck)));
      await tester.pump();
      expect(events.find('esg')!.saved, isFalse);
    });
  });

  group('the tiles and the host card', () {
    testWidgets('Manage & View opens the next booked event\'s sheet, where its pass and Cancel are', (tester) async {
      await pumpBoard(tester);
      await tester.tap(find.text('Manage & View'));
      await settle(tester);
      expect(find.byType(EventSheetBar), findsOneWidget);
      expect(launched, isEmpty, reason: 'the website\'s events page is this screen');
    });

    testWidgets('Submit Topic opens the website\'s contact page', (tester) async {
      await pumpBoard(tester);
      expect(find.text("Engage ICR's community of CRE & PropTech leaders"), findsOneWidget);
      await tester.tap(find.text('Submit Topic'));
      await tester.pump();
      expect(launched.single.toString(), 'https://icr.org.in/contact');
    });

    testWidgets('pulling the board down refreshes it from the API', (tester) async {
      // A viewport short enough that the indicator's trigger distance (a quarter of it) is a short drag.
      await pumpBoard(tester, height: 1700);
      final before = api.calls.where((c) => c == 'GET /events').length;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(api.calls.where((c) => c == 'GET /events').length, before + 1);
    });
  });

  group('an event\'s sheet', () {
    Future<void> openSheet(WidgetTester tester, String id) async {
      await tester.tap(inCard(id, find.byType(InkWell)).first);
      await settle(tester);
    }

    testWidgets('a held place: the confirmed pill, the pass card, the booking line and the two buttons', (
      tester,
    ) async {
      await pumpBoard(tester);
      await openSheet(tester, 'ai');
      expect(find.text('Registration Confirmed'), findsOneWidget);
      expect(find.text('1.5 CPD Credits'), findsOneWidget);
      expect(find.text('Pass #ICR-EVT-AI'), findsOneWidget);
      expect(find.text('Active Pass'), findsOneWidget);
      expect(find.text('Member • Bharat Buyer (TechCorp)'), findsOneWidget);
      expect(find.text('Show Pass'), findsOneWidget);
      expect(find.text('Add to calendar'), findsOneWidget);
      expect(find.text('180 Attendees Registered'), findsOneWidget);
      expect(find.text('Open to every ICR member'), findsOneWidget);
      expect(find.text('Your Booking is Active'), findsOneWidget);
      expect(find.text('1 delegate seat confirmed'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('View Pass & QR'), findsOneWidget);
      // The programme: a lone talk fills the webinar.
      expect(find.text('WEBINAR AGENDA'), findsOneWidget);
      expect(find.text('TALK'), findsOneWidget);
      expect(find.text('Dr. Radhika Iyer (VP Sustainable PropTech)'), findsOneWidget);
      expect(find.text('FREE FOR MEMBERS'), findsOneWidget);
    });

    testWidgets('Show Pass and View Pass & QR open the pass: the event\'s code and a QR to its page', (tester) async {
      await pumpBoard(tester);
      await openSheet(tester, 'ai');
      await tester.tap(find.text('Show Pass'));
      await tester.pumpAndSettle();
      expect(find.byType(EventPassDialog), findsOneWidget);
      expect(find.byType(QrView), findsOneWidget);
      final shownCode = tester.widget<QrView>(find.byType(QrView)).code;
      expect(shownCode.toRows(), QrCode.encode('https://icr.org.in/events/slug-ai').toRows());
      expect(find.text('Pass #ICR-EVT-AI'), findsWidgets);
      expect(find.text('Member • Bharat Buyer (TechCorp)'), findsWidgets);

      expect(find.text('Event page'), findsNothing, reason: 'the pass sits on the event\'s own sheet');

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byType(EventPassDialog), findsNothing);

      await tester.tap(find.text('View Pass & QR'));
      await tester.pumpAndSettle();
      expect(find.byType(EventPassDialog), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.x).last);
      await tester.pumpAndSettle();
      expect(find.byType(EventPassDialog), findsNothing);
      expect(find.text('Registration Confirmed'), findsOneWidget, reason: 'the sheet is still open under the pass');
    });

    testWidgets('Add to calendar opens Google Calendar with the event filled in', (tester) async {
      await pumpBoard(tester);
      await openSheet(tester, 'ai');
      await tester.tap(find.text('Add to calendar'));
      await tester.pump();
      final url = launched.single;
      expect(url.host, 'calendar.google.com');
      expect(url.queryParameters['text'], 'Future of AI in Facility Management');
      expect(url.queryParameters['dates'], matches(RegExp(r'^\d{8}T\d{6}Z/\d{8}T\d{6}Z$')));
      expect(url.queryParameters['details'], contains('https://icr.org.in/events/slug-ai'));
    });

    testWidgets('View Network opens the network; About has no link out (the sheet is the overview)', (tester) async {
      await pumpBoard(tester);
      await openSheet(tester, 'ai');
      expect(find.text('Overview'), findsNothing);
      await tester.tap(find.text('View Network'));
      await tester.pump();
      expect(launched.map((u) => u.toString()), ['https://icr.org.in/network']);
    });

    testWidgets('share and bookmark: the sheet\'s and the board\'s agree', (tester) async {
      await pumpBoard(tester);
      await openSheet(tester, 'ai');
      await tester.tap(find.byIcon(LucideIcons.share2).last);
      await tester.pump();
      expect(shared.single['text'], 'Future of AI in Facility Management\nhttps://icr.org.in/events/slug-ai');

      await tester.tap(find.byIcon(LucideIcons.bookmark).last);
      await tester.pump();
      expect(find.byIcon(LucideIcons.bookmarkCheck), findsWidgets);
      expect(events.find('ai')!.saved, isTrue, reason: 'the board was told');
      await tester.tap(find.byIcon(LucideIcons.bookmarkCheck).last);
      await tester.pump();
      expect(events.find('ai')!.saved, isFalse);
    });

    testWidgets('Cancel gives the place back through the API: the pill, the pass card and the button follow', (
      tester,
    ) async {
      await pumpBoard(tester);
      await openSheet(tester, 'ai');
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(api.calls, contains('DELETE /events/ai/rsvp'));
      expect(world.places['ai'], 'CANCELLED');
      expect(find.text('Registration Open'), findsOneWidget);
      expect(find.text('Show Pass'), findsNothing);
      expect(find.text('Register Now'), findsOneWidget);
      expect(find.text('Seats available'), findsOneWidget);
      expect(find.text('179 Attendees Registered'), findsOneWidget);
      expect(events.schedule, isNull, reason: 'the board\'s tile follows');
    });

    testWidgets('Register Now takes the place again: the pass comes back', (tester) async {
      await pumpBoard(tester);
      await openSheet(tester, 'ai');
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      await tester.tap(find.text('Register Now'));
      await settle(tester);
      expect(world.places['ai'], 'GOING');
      expect(find.text('Registration Confirmed'), findsOneWidget);
      expect(find.text('Pass #ICR-EVT-AI'), findsOneWidget);
      expect(find.text('View Pass & QR'), findsOneWidget);
      expect(events.schedule!.count, 1);
    });

    testWidgets('a paid seat refuses to cancel: the API\'s words are shown and the place stays', (tester) async {
      await pumpBoard(tester);
      world.refuseCancel = 'Your ticket is paid for. To cancel it, contact ICR support, who will arrange any refund.';
      await openSheet(tester, 'ai');
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.textContaining('Your ticket is paid for'), findsOneWidget);
      expect(find.text('Registration Confirmed'), findsOneWidget);
      expect(find.text('Show Pass'), findsOneWidget);
      expect(find.text('180 Attendees Registered'), findsOneWidget);
      expect(world.places['ai'], 'GOING');
    });

    testWidgets('an open event: Register Now registers, and a refusal says why', (tester) async {
      await pumpBoard(tester);
      await openSheet(tester, 'bms');
      expect(find.text('Registration Open'), findsOneWidget);
      expect(find.text('Free for ICR members'), findsOneWidget);
      world.refuseRsvp = 'Registration closed.';
      await tester.tap(find.text('Register Now'));
      await settle(tester);
      expect(find.text('Registration closed.'), findsOneWidget);
      expect(find.text('Registration Open'), findsOneWidget);

      world.refuseRsvp = null;
      await tester.tap(find.text('Register Now'));
      await settle(tester);
      expect(world.places['bms'], 'GOING');
      expect(find.text('Registration Confirmed'), findsOneWidget);
      expect(find.text('Pass #ICR-EVT-BMS'), findsOneWidget);
    });

    testWidgets('a priced event: Get Tickets opens the website, the price is in the bar', (tester) async {
      await pumpBoard(tester);
      await openSheet(tester, 'summit');
      expect(find.text('₹15,000 per pass'), findsWidgets);
      expect(find.text('₹15,000 PER PASS'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(EventSheetBar), matching: find.text('Get Tickets')));
      await tester.pump();
      expect(launched.single.toString(), 'https://icr.org.in/events/slug-summit');
      expect(api.calls.where((c) => c.startsWith('POST')), isEmpty);
    });

    testWidgets('an invite-only event the member was not asked to: By invitation, and no button', (tester) async {
      final w = EventsWorld()..notInvited.add('gcc');
      await pumpBoard(tester, custom: w);
      await openSheet(tester, 'gcc');
      expect(find.text('By invitation'), findsOneWidget);
      expect(find.text('This event is invite-only'), findsOneWidget);
      expect(find.descendant(of: find.byType(EventSheetBody), matching: find.text('INVITE ONLY')), findsOneWidget);
      expect(find.text('Event page'), findsNothing, reason: 'it only opened this sheet again');
      expect(launched, isEmpty);
    });

    testWidgets('a waitlisted place: the pill, the badge, no pass; Cancel alone', (tester) async {
      world = EventsWorld()..places['gcc'] = 'WAITLISTED';
      await pumpBoard(tester, custom: world);
      await openSheet(tester, 'gcc');
      expect(find.text('On the Waitlist'), findsOneWidget);
      expect(find.text('Waitlisted'), findsOneWidget);
      expect(find.text("You're on the waitlist"), findsOneWidget);
      expect(find.text('Your place'), findsOneWidget);
      expect(find.text('Event page'), findsNothing);
      expect(find.text('Show Pass'), findsNothing);
      expect(find.text('View Pass & QR'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(world.places['gcc'], 'CANCELLED');
    });

    testWidgets('a past event: ended, and no button', (tester) async {
      await pumpBoard(tester);
      await tester.tap(find.byIcon(LucideIcons.slidersHorizontal));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Past'));
      await tester.pump();
      await tester.tap(find.text('Show events'));
      await settle(tester);
      await openSheet(tester, 'old');
      expect(find.text('Event Ended'), findsOneWidget);
      expect(find.text('This event has ended'), findsOneWidget);
      expect(find.text('Event page'), findsNothing);
      expect(find.text('It happened.'), findsOneWidget);
    });

    testWidgets('the cross and the back button close the sheet', (tester) async {
      await pumpBoard(tester);
      await openSheet(tester, 'ai');
      expect(find.text('About'), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.x).first);
      await tester.pumpAndSettle();
      expect(find.text('About'), findsNothing);
      expect(find.text('Upcoming Agenda'), findsOneWidget);

      await openSheet(tester, 'ai');
      expect(find.text('About'), findsOneWidget);
      await tester.binding.handlePopRoute(); // the system's Back
      await tester.pumpAndSettle();
      expect(find.text('About'), findsNothing);
    });

    testWidgets('the sheet\'s highlight cards are the description\'s bold-led list', (tester) async {
      world = EventsWorld();
      world.byId('ai')['description'] =
          '<p>About the webinar.</p><ul><li><strong>Smart IoT &amp; FM Automation</strong>: Deploying digital twins.</li>'
          '<li><strong>ESG &amp; Decarbonization</strong>: Benchmarking.</li></ul>';
      await pumpBoard(tester, custom: world);
      await openSheet(tester, 'ai');
      expect(find.text('About the webinar.'), findsOneWidget);
      expect(find.text('Smart IoT & FM Automation'), findsOneWidget);
      expect(find.text('Deploying digital twins.'), findsOneWidget);
      expect(find.text('ESG & Decarbonization'), findsOneWidget);
    });
  });
}
