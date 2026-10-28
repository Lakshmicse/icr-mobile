@Tags(['live'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart' show DioException;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/widgets/detail_sheet.dart';
import 'package:icr_mobile/features/events/api_events_repository.dart';
import 'package:icr_mobile/features/events/event_detail_controller.dart';
import 'package:icr_mobile/features/events/event_format.dart';
import 'package:icr_mobile/features/events/event_models.dart';
import 'package:icr_mobile/features/events/event_sheet.dart';
import 'package:icr_mobile/features/events/events_controller.dart';
import 'package:icr_mobile/features/events/events_repository.dart';
import 'package:icr_mobile/features/events/events_screen.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';
import 'live.dart';

/// The Events screens against the LOCAL API, as the emulator runs them: the
/// seeded design events (`tool/seed/events-councils.ts`), Bharat Buyer signed
/// in. Every test that writes does it as Pooja Professional, on an event she
/// holds no place at, and gives the place back; Bharat's two designed places
/// (the sheet's event and the CXO roundtable) are never touched.
///
/// The API answers 120 requests a minute per address and other people's
/// tests share it, so the suite signs in once per person, loads each board
/// once and waits out a 429.
void main() {
  setUpAll(loadAppFonts);

  const aiTitle = 'Future of AI in Facility Management';
  const summitTitle = 'Global CRE PropTech Summit 2026';
  const gccTitle = 'Sustainable GCC Campus & Net-Zero Operations';
  const bmsTitle = 'Smart BMS & Predictive Maintenance Masterclass';
  const sheetTitle = 'Future of Business & Innovation Summit 2024';

  // --- shared state ---------------------------------------------------------------

  final clients = <String, Future<ApiClient>>{};
  Future<ApiClient> clientFor(LivePerson who) => clients.putIfAbsent(who.email, () => patient(() => liveClient(who)));

  /// Bharat's board, read through the bundled copies of the covers (so the render tests can draw it);
  /// Pooja's reads no speakers (the RSVP tests do not look at them).
  final boards = <String, Future<EventsController>>{};
  Future<EventsController> board([LivePerson who = bharat]) => boards.putIfAbsent(who.email, () async {
    final api = await clientFor(who);
    final inner = ApiEventsRepository(api: api);
    final controller = EventsController(who == bharat ? _OfflineCovers(inner) : _NoSpeakers(inner));
    for (var attempt = 0; attempt < 5; attempt++) {
      await controller.start();
      await controller.speakersSettled;
      if (controller.overview != null) return controller;
      await Future<void>.delayed(const Duration(seconds: 15));
    }
    throw StateError('the board did not load: ${controller.error}');
  });

  EventSummary card(EventsController c, String title) => c.agenda.firstWhere((e) => e.title == title);

  /// Back to the board at rest, without a request when nothing was narrowed to the API.
  Future<void> rest(EventsController c) async {
    if (c.narrowed) {
      await c.clearAll();
    } else {
      c.selectAll();
    }
  }

  group('the board', () {
    liveTest('lists the design events soonest first, in the design\'s order, with the flagship apart', () async {
      final events = await board();
      final overview = events.overview!;
      final flagship = overview.spotlight!;
      expect(flagship.title, summitTitle);
      expect(overview.events.map((e) => e.id), isNot(contains(flagship.id)), reason: 'the flagship has its own card');
      expect(flagship.going, greaterThanOrEqualTo(overview.events.map((e) => e.going).reduce((a, b) => a > b ? a : b)));

      final starts = overview.events.map((e) => e.startsAt).toList();
      expect([...starts]..sort(), starts, reason: 'the agenda is in date order, as the API gives it');
      final titles = overview.events.map((e) => e.title).toList();
      expect(titles, containsAllInOrder([aiTitle, summitTitle, gccTitle, bmsTitle]));
      expect(titles.indexOf(bmsTitle), lessThan(6), reason: 'the design\'s cards lead the agenda');
    });

    liveTest('shows the member\'s places, their CPD year and the unread bell', () async {
      final events = await board();
      final overview = events.overview!;
      expect(overview.schedule!.count, greaterThanOrEqualTo(2), reason: 'Bharat\'s two designed places');
      expect(overview.schedule!.next!.title, sheetTitle);
      expect(overview.cpd!.earned, 8.5);
      expect(overview.cpd!.target, 15);
      expect(overview.cpd!.fraction, closeTo(8.5 / 15, 1e-9));
      expect(overview.cpd!.remaining, 6.5);
      expect(events.unread, greaterThanOrEqualTo(0));
    });

    liveTest('counts its own agenda: "Upcoming" is the next 30 days, "Ready" the seats still open', () async {
      final overview = (await board()).overview!;
      final soon = DateTime.now().add(const Duration(days: 30));
      expect(overview.upcomingCount, overview.events.where((e) => e.startsAt.isBefore(soon)).length);
      expect(overview.readyCount, overview.events.where((e) => !e.inviteOnly && !e.full && !e.past).length);
    });

    liveTest('an invite-only event is on the board for the people asked to it, and for nobody else', () async {
      final asked = (await board()).overview!;
      expect(asked.events.map((e) => e.title), contains(gccTitle));
      final stranger = await patient(() => ApiEventsRepository(api: liveAnonymous()).overview());
      expect(stranger.events.map((e) => e.title), isNot(contains(gccTitle)));
    });

    liveTest('a card\'s second line is the first speaker of its programme', () async {
      final events = await board();
      expect(card(events, aiTitle).speakerLine, 'Dr. Radhika Iyer, VP Sustainable PropTech');
      expect(lineFor(card(events, aiTitle))!.$2, LineIcon.speaker);
      expect(card(events, bmsTitle).speakerLine, isNull, reason: 'no talks, so the card keeps its venue');
      expect(lineFor(card(events, bmsTitle))!.$1, 'Bangalore HQ');
    });
  });

  group('the chips, the tiles, the search and the filters', () {
    liveTest('a kind chip shows that kind\'s events only, and "All Events" brings the rest back', () async {
      final events = await board();
      final all = events.agenda.length;
      events.chips.firstWhere((c) => c.label == 'Webinars').select();
      expect(events.agenda, isNotEmpty);
      expect(events.agenda.every((e) => e.kind == EventKind.webinar), isTrue);
      events.chips.firstWhere((c) => c.label == 'Conferences').select();
      expect(events.agenda.every((e) => e.kind == EventKind.conference), isTrue);
      events.chips.first.select();
      expect(events.agenda.length, all);
      expect(events.chips.first.selected, isTrue);
    });

    liveTest('"Upcoming (N)" is the events of the next 30 days', () async {
      final events = await board();
      final label = events.chips[1].label;
      events.chips[1].select();
      final soon = DateTime.now().add(const Duration(days: 30));
      expect(events.agenda.every((e) => e.startsAt.isBefore(soon)), isTrue);
      expect(label, 'Upcoming (${events.agenda.length})');
      events.chips.first.select();
    });

    liveTest('a category tile narrows the agenda to its track, and a second tap lifts it', () async {
      final events = await board();
      final tile = events.tracks.first;
      expect(tile.council, isNotNull, reason: 'the seeded events sit in several councils, so the tiles are tracks');
      expect(events.tracks.length, greaterThanOrEqualTo(2));
      final all = events.agenda.length;

      events.selectTrack(tile);
      expect(events.track!.key, tile.key);
      expect(events.agenda.length, tile.count);
      expect(events.agenda.every((e) => trackOf(e) == tile.council), isTrue);
      expect(events.agendaTitle, '${tile.label} Events');
      expect(events.filtered, isTrue);

      events.selectTrack(tile);
      expect(events.track, isNull);
      expect(events.agenda.length, all);
    });

    liveTest('a search goes to the API, "Clear" comes back', () async {
      final events = await board();
      await events.setSearch('masterclass');
      expect(events.narrowed, isTrue);
      expect(events.agendaTitle, 'Events matching "masterclass"');
      expect(events.agenda.map((e) => e.title), contains(bmsTitle));
      expect(events.agenda.map((e) => e.title), isNot(contains(aiTitle)));
      await events.setSearch('zzzz-no-such-event');
      expect(events.agenda, isEmpty);
      await events.clearAll();
      expect(events.narrowed, isFalse);
      expect(events.agenda.map((e) => e.title), contains(aiTitle));
    });

    liveTest('the filter glyph\'s Past window reads the past events; Online keeps the online ones', () async {
      final events = await board();
      await events.setQuery(const EventQuery(when: EventWhen.past));
      expect(events.agendaTitle, 'Past Events');
      expect(events.agenda, isNotEmpty);
      expect(events.agenda.every((e) => e.past), isTrue);

      await events.setQuery(const EventQuery(format: FormatFilter.online));
      expect(events.agenda, isNotEmpty);
      expect(events.agenda.every((e) => formatOf(e) != EventFormat.inPerson), isTrue);
      await events.setQuery(const EventQuery(format: FormatFilter.inPerson));
      expect(events.agenda.every((e) => formatOf(e) != EventFormat.online), isTrue);
      await events.clearAll();
      expect(events.narrowed, isFalse);
    });

    liveTest('a bookmark stays on the device: the card keeps it until it is taken off', () async {
      final events = await board();
      final ai = card(events, aiTitle);
      events.toggleSave(ai);
      expect(events.find(ai.id)!.saved, isTrue);
      events.toggleSave(events.find(ai.id)!);
      expect(events.find(ai.id)!.saved, isFalse);
      await rest(events);
    });
  });

  group('taking a place and giving it back (as Pooja, on events she holds none at)', () {
    Future<Map<String, String>> placesOf(LivePerson who) async {
      final api = await clientFor(who);
      final rows = (await patient(
        () => api.dio.get<List<dynamic>>('/events/rsvps/mine'),
      )).data!.cast<Map<String, dynamic>>();
      return {for (final r in rows) r['eventId'] as String: r['status'] as String};
    }

    Future<int> goingAt(String id) async {
      final json = (await patient(() => liveAnonymous().dio.get<Map<String, dynamic>>('/events/$id'))).data!;
      return (json['attendeeCount'] as num).toInt();
    }

    Future<void> giveBack(String id) async {
      final api = await clientFor(pooja);
      await api.dio.delete<dynamic>('/events/$id/rsvp');
    }

    liveTest(
      'Register Free / Reserve Pass: the API keeps the place, My Schedule counts it, Cancel gives it back',
      () async {
        final events = await board(pooja);
        final bms = card(events, bmsTitle);
        expect(bms.rsvp.holds, isFalse, reason: 'Pooja holds no place at the masterclass');
        final before = events.schedule?.count ?? 0;
        final seats = await goingAt(bms.id);
        addTearDown(() => giveBack(bms.id)); // whatever happened below, leave Pooja without a place here

        expect(await events.register(bms), isNull);
        expect(events.find(bms.id)!.rsvp, RsvpState.going);
        expect(events.schedule!.count, before + 1);
        expect((await placesOf(pooja))[bms.id], 'GOING');
        expect(await goingAt(bms.id), seats + 1);

        expect(await events.cancel(events.find(bms.id)!), isNull);
        expect(events.find(bms.id)!.rsvp, RsvpState.cancelled);
        expect(events.schedule?.count ?? 0, before);
        expect((await placesOf(pooja))[bms.id], 'CANCELLED');
        expect(await goingAt(bms.id), seats);
      },
    );

    liveTest('an invitation is a place: the invited member registers for the closed-door roundtable', () async {
      final events = await board(pooja);
      final gcc = card(events, gccTitle);
      addTearDown(() => giveBack(gcc.id));
      final seats = gcc.seatsLeft!;
      expect(await events.register(gcc), isNull);
      expect(events.find(gcc.id)!.rsvp, RsvpState.going);
      expect(events.find(gcc.id)!.seatsLeft, seats - 1);
      expect((await placesOf(pooja))[gcc.id], 'GOING');
      expect(await events.cancel(events.find(gcc.id)!), isNull);
      expect((await placesOf(pooja))[gcc.id], 'CANCELLED');
      expect(events.find(gcc.id)!.seatsLeft, seats);
    });

    liveTest('a priced seat is refused as a free place: the card puts it back and says why', () async {
      final api = await clientFor(pooja);
      final events = await board(pooja);
      final summit = card(events, summitTitle);
      expect(summit.priced, isTrue);
      final quote = (await patient(() => api.dio.get<Map<String, dynamic>>('/events/${summit.id}/ticket/quote'))).data!;
      if (quote['payable'] != true) {
        markTestSkipped('payments are not configured on this API, so a priced seat is still a free RSVP');
        return;
      }
      final going = summit.going;
      final message = await events.register(summit);
      expect(message, 'This event is ticketed. Buy a ticket to take your place.');
      expect(events.find(summit.id)!.rsvp.holds, isFalse);
      expect(events.find(summit.id)!.going, going);
      expect((await placesOf(pooja))[summit.id], isNull);
    });

    // Pooja's seat at the Advanced Lease Audit Workshop was bought (the seed writes the ticket a PayU
    // purchase leaves), so the API will not let her give it up: a refused cancel changes nothing, which is
    // why this proof has nothing to undo.
    liveTest(
      'a paid seat refuses to cancel: the API\'s words are shown, and the place, the pass and the count stay',
      () async {
        const refusal = 'Your ticket is paid for. To cancel it, contact ICR support, who will arrange any refund.';
        final events = await board(pooja);
        final paid = card(events, 'Advanced Lease Audit Workshop');
        expect(paid.rsvp, RsvpState.going);
        expect(paid.priced, isTrue);

        expect(await events.cancel(paid), refusal, reason: 'the board\'s Cancel');
        expect(events.find(paid.id)!.rsvp, RsvpState.going);
        expect(events.find(paid.id)!.going, paid.going);
        expect((await placesOf(pooja))[paid.id], 'GOING');

        final sheet = EventDetailController(repository: events.repository, seed: paid, onChanged: events.update);
        await sheet.load();
        expect(sheet.detail.pass!.reference, 'ICR-EVT-SHOP');
        expect(await sheet.cancel(), refusal, reason: 'the sheet\'s Cancel');
        expect(sheet.event.rsvp, RsvpState.going);
        expect(sheet.event.going, paid.going);
        expect(sheet.detail.pass, isNotNull, reason: 'the pass comes back with the place');
        expect((await placesOf(pooja))[paid.id], 'GOING');
        sheet.dispose();
      },
    );

    liveTest('the sheet registers and cancels through the same routes, and tells the board', () async {
      final events = await board(pooja);
      final repo = events.repository;
      final ai = card(events, aiTitle);
      final sheet = EventDetailController(repository: repo, seed: ai, onChanged: events.update);
      addTearDown(() => giveBack(ai.id));
      await sheet.load();
      expect(sheet.event.rsvp.holds, isFalse);
      expect(sheet.detail.pass, isNull);

      expect(await sheet.register(), isNull);
      expect(sheet.event.rsvp, RsvpState.going);
      expect(events.find(ai.id)!.rsvp, RsvpState.going, reason: 'the board follows the sheet');
      expect((await placesOf(pooja))[ai.id], 'GOING');

      expect(await sheet.cancel(), isNull);
      expect(sheet.event.rsvp, RsvpState.cancelled);
      expect(events.find(ai.id)!.rsvp, RsvpState.cancelled);
      expect((await placesOf(pooja))[ai.id], 'CANCELLED');
      sheet.dispose();
    });
  });

  group('an event\'s sheet', () {
    liveTest('reads the seeded event: organiser, pass, highlights and the programme with times and tags', () async {
      final events = await board();
      final detail = await patient(() => events.repository.detail(card(events, sheetTitle)));

      expect(detail.organiser, 'ICR Vinfraa & PropTech India Chapter');
      expect(detail.event.rsvp, RsvpState.going);
      expect(detail.pass!.holder, startsWith('Bharat Buyer'));
      expect(detail.pass!.reference, 'ICR-EVT-FBIS');
      expect(detail.attendeeNote, 'Open to every ICR member');

      final text = describe(detail.event.description);
      expect(text.paragraphs, hasLength(1));
      expect(text.highlights.map((h) => h.title), ['Smart IoT & FM Automation', 'ESG & Decarbonization']);

      expect(detail.sessions.map((s) => s.title), [
        'The Autonomous Facility: 2025 Architecture',
        'Retrofitting Commercial Towers with Smart Sensors',
      ]);
      expect(detail.sessions.map((s) => s.time), ['10:00 AM – 11:15 AM', '11:30 AM – 12:45 PM']);
      expect(detail.sessions.map((s) => s.tag), ['KEYNOTE', 'PANEL']);
      expect(detail.sessions.first.speaker, 'Rajesh Sharma (VP Global Real Estate, Infosys)');
      expect(detail.sessions.last.speaker, 'Priya Nambiar (IGBC AP) & Panelists');
      expect(detail.agendaNote, startsWith('Indicative times'));
    });

    liveTest('an event the member has no place at has no pass; a lone talk fills a short webinar', () async {
      final events = await board(pooja);
      final ai = await patient(() => events.repository.detail(card(events, aiTitle)));
      expect(ai.pass, isNull);
      expect(ai.sessions.single.time, '4:00 PM – 5:30 PM');
      expect(ai.sessions.single.tag, 'TALK');
      final summit = await patient(() => events.repository.detail(card(events, summitTitle)));
      expect(summit.pass, isNull);
      expect(summit.event.priced, isTrue);
    });
  });

  group('what the screens look like with this data', () {
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

    Future<EventsController?> loaded(WidgetTester tester) async {
      if (await tester.runAsync(liveApiReachable) != true) {
        markTestSkipped('the local API is not running at $liveBaseUrl');
        return null;
      }
      return tester.runAsync(board);
    }

    // The covers are served by the API as /uploads files, which a widget test cannot fetch: the same
    // pictures (the seed copies assets/images/demo/events into uploads) are read from the bundle.
    testWidgets(
      'the board (build/screens/events_home_live.png)',
      (tester) async {
        final events = await loaded(tester);
        if (events == null) return;
        tester.view.physicalSize = const Size(780, 4309);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

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
        await export(tester, find.byType(EventsScreen), 'events_home_live');
        expect(find.text('Explore by Category'), findsOneWidget);
      },
      tags: const ['live'],
      timeout: const Timeout(Duration(minutes: 2)),
    );

    for (final (title, name) in [
      (sheetTitle, 'event_sheet_live'),
      (aiTitle, 'event_sheet_ai_live'),
      (summitTitle, 'event_sheet_summit_live'),
    ]) {
      testWidgets(
        'the sheet of "$title" (build/screens/$name.png)',
        (tester) async {
          final events = await loaded(tester);
          if (events == null) return;
          tester.view.physicalSize = const Size(780, 2261);
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);

          late EventDetailController sheet;
          await tester.runAsync(() async {
            sheet = EventDetailController(repository: events.repository, seed: card(events, title));
            await patient(sheet.load);
          });
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildAppTheme(),
              home: ChangeNotifierProvider<EventsController>.value(
                value: events,
                child: ChangeNotifierProvider.value(
                  value: sheet,
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
          await export(tester, find.byType(DetailSheetFrame), name);
          expect(find.text(title), findsWidgets);
        },
        tags: const ['live'],
        timeout: const Timeout(Duration(minutes: 2)),
      );
    }
  });
}

/// Runs [call], waiting out the API's rate limit (HTTP 429) a few times before giving up.
Future<T> patient<T>(Future<T> Function() call) async {
  for (var attempt = 0; ; attempt++) {
    try {
      return await call();
    } catch (e) {
      final throttled = (e is ApiError && e.statusCode == 429) || (e is DioException && e.response?.statusCode == 429);
      if (!throttled || attempt >= 5) rethrow;
      await Future<void>.delayed(const Duration(seconds: 15));
    }
  }
}

/// The API's repository with each cover swapped for the bundled copy of the same picture, so a render
/// draws what the emulator draws (`CachedNetworkImage` cannot fetch in a widget test).
class _OfflineCovers implements EventsRepository {
  _OfflineCovers(this.inner);

  final ApiEventsRepository inner;

  EventSummary _local(EventSummary e) {
    final name = e.cover?.url == null ? null : Uri.parse(e.cover!.url!).pathSegments.last;
    final match = name == null ? null : RegExp(r'^design-events-(.+)$').firstMatch(name);
    return match == null ? e : e.copyWith(cover: FeedPicture.asset('assets/images/demo/events/${match[1]}'));
  }

  @override
  Future<EventsOverview> overview() async {
    final o = await inner.overview();
    return o.copyWith(
      events: o.events.map(_local).toList(),
      spotlight: o.spotlight == null ? null : _local(o.spotlight!),
    );
  }

  @override
  Future<List<EventSummary>> search(EventQuery query) async => (await inner.search(query)).map(_local).toList();

  @override
  Future<EventDetail> detail(EventSummary event) async {
    final d = await inner.detail(event);
    return d.copyWith(event: _local(d.event));
  }

  @override
  Future<RsvpState> rsvp(EventSummary event) => inner.rsvp(event);
  @override
  Future<void> cancel(EventSummary event) => inner.cancel(event);
  @override
  Future<EventPass?> passFor(EventSummary event) => inner.passFor(event);
  @override
  Future<Map<String, String>> speakers(List<EventSummary> events) => inner.speakers(events);
  @override
  MySchedule? schedule(List<EventSummary> known) => inner.schedule(known);
  @override
  Future<int> unreadNotifications() => inner.unreadNotifications();
  @override
  Uri link(EventSummary event) => inner.link(event);
}

/// The API's repository without the per-card programme lookups, for the tests that write.
class _NoSpeakers extends _OfflineCovers {
  _NoSpeakers(super.inner);

  @override
  Future<Map<String, String>> speakers(List<EventSummary> events) async => const {};
}
