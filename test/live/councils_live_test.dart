/// The Councils screen against the LOCAL portal API, seeded by `tool/seed`
/// (events-councils.ts): the app's own repository and controller, the way the
/// screen uses them, with the effect read back through the API.
///
/// Writes use Pooja Professional and undo themselves: she joins a council that
/// is none of the designed seats and leaves it again. Bharat's and Pooja's
/// designed seats (the CXO executive seat, Sustainability, Workplace) are never
/// touched.
///
///     flutter test test/live/councils_live_test.dart
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/councils/api_councils_repository.dart';
import 'package:icr_mobile/features/councils/council_format.dart';
import 'package:icr_mobile/features/councils/council_models.dart';
import 'package:icr_mobile/features/councils/councils_controller.dart';
import 'package:icr_mobile/features/councils/councils_repository.dart';
import 'package:icr_mobile/features/councils/councils_screen.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';
import 'live.dart';

/// The six designed councils in the order the design lists them.
const _designSlugs = [
  'sustainability-esg-net-zero-design',
  'cxo-workplace-strategy-design',
  'smart-buildings-bms-proptech-design',
  'legal-compliance-procurement-design',
  'construction-projects-mep-design',
  'corporate-commercial-real-estate', // the association seed's own row, adopted by the seed
];

/// The chips the design shows first.
const _designCategories = [
  'Net-Zero & ESG',
  'CXO & Workplace',
  'Smart Buildings',
  'Legal & Procurement',
  'Construction & MEP',
  'Real Estate',
];

/// The seats Bharat and Pooja hold by design.
const _designedSeats = {'sustainability-esg-net-zero-design', 'cxo-workplace-strategy-design', 'workplace-experience'};

Future<ApiCouncilsRepository> _repository([LivePerson who = bharat]) async =>
    ApiCouncilsRepository(api: await liveClient(who));

Future<CouncilsController> _controller([LivePerson who = bharat]) async {
  final controller = CouncilsController(await _repository(who));
  await controller.start();
  expect(controller.error, isNull, reason: 'the councils should load from the local API');
  return controller;
}

Future<List<Map<String, dynamic>>> _rows(ApiClient api, String path, [Map<String, dynamic>? query]) async {
  final res = await api.dio.get<Map<String, dynamic>>(path, queryParameters: {'limit': 100, ...?query});
  return (res.data!['data'] as List).cast<Map<String, dynamic>>();
}

/// Whether the designed councils are in the database.
bool _hasDesign(CouncilsController controller) {
  final have = controller.overview!.councils.map((c) => c.slug).toSet();
  return _designSlugs.every(have.contains);
}

/// Skips the rest of a test when the designed councils are not in the database.
Future<bool> _seeded(CouncilsController controller) async {
  if (_hasDesign(controller)) return true;
  markTestSkipped('the designed councils are not seeded: run tool/seed/run.ps1');
  return false;
}

/// A council Pooja may join and leave: not designed, not hers already.
Council _spare(CouncilsController controller) => controller.overview!.councils.firstWhere(
  (c) => !c.joined && !c.slug.endsWith('-design') && !_designSlugs.contains(c.slug) && !_designedSeats.contains(c.slug),
);

void main() {
  setUpAll(loadAppFonts);

  liveTest('the directory is the API\'s, with the designed councils first, in the design\'s order', () async {
    final controller = await _controller();
    if (!await _seeded(controller)) return;
    final api = await liveClient();
    final raw = await _rows(api, '/councils');

    // Every council the API lists is a card, and the tile counts the same.
    expect(controller.overview!.councils.map((c) => c.id).toSet(), raw.map((r) => r['id']).toSet());
    expect(controller.stats!.activeCouncils, raw.length);
    expect(controller.councils.length, raw.length);

    // The design's order, and its chips, from the data: no list of names in the app.
    expect(controller.councils.take(6).map((c) => c.slug), _designSlugs);
    expect(controller.categories.take(6), _designCategories);
    // Each card is filed under the category its chip names.
    for (final (i, c) in controller.councils.take(6).indexed) {
      expect(c.category, _designCategories[i]);
    }
  });

  liveTest('the stat tiles are read from the data', () async {
    final controller = await _controller();
    final api = await liveClient();
    final raw = await _rows(api, '/councils');
    final stats = controller.stats!;

    final peers = raw.fold<int>(0, (n, r) => n + (r['memberCount'] as int));
    expect(stats.peerMembers, peers);
    expect(stats.peerMembersLabel, peerMembersLabel(peers));
    expect(
      stats.peerMembersLabel,
      matches(RegExp(r'^\d{1,3}(,\d{3})*\+$')),
      reason: 'grouped, with the design\'s plus',
    );
    expect(stats.domains, {for (final r in raw) ...(r['segments'] as List).cast<String>()}.length);

    // "+N Qn": the councils created in the running quarter.
    final (quarter, start) = quarterOf(DateTime.now());
    final created = raw.where((r) => !DateTime.parse(r['createdAt'] as String).isBefore(start)).length;
    expect(stats.quarter, quarter);
    expect(stats.newThisQuarter, created);
    if (_hasDesign(controller)) {
      expect(
        created,
        greaterThanOrEqualTo(3),
        reason: 'the seed creates three designed councils in the running quarter',
      );
    }

    // "Active Roundtables": the upcoming roundtables a council hosts.
    final events = await _rows(api, '/events', {'when': 'upcoming', 'kind': 'ROUNDTABLE'});
    expect(stats.activeRoundtables, events.where((e) => e['council'] != null).length);
    if (_hasDesign(controller)) expect(stats.activeRoundtables, greaterThan(0));
  });

  liveTest(
    'the three roundtable rows are the design\'s: the dates, the mode, the lead and the seats claimed',
    () async {
      final controller = await _controller();
      if (!await _seeded(controller)) return;
      final api = await liveClient();
      final rows = controller.roundtables;
      expect(rows, hasLength(3));

      // Apr 18, Apr 25 and May 03 of next year's spring, in the design's order.
      expect(rows.map((r) => (monthCaps(r.startsAt), dayOfMonth(r.startsAt))), [
        ('APR', '18'),
        ('APR', '25'),
        ('MAY', '03'),
      ]);
      expect(rows.map((r) => r.title), [
        'ESG Mandates: BRSR Core & Scope 3',
        'GCC Workplace Leadership & AI FM',
        'Vendor RFP Standardization & AMCs',
      ]);
      expect(rows.map((r) => timeRange(r.startsAt, r.endsAt)), [
        '15:30 – 17:00 IST',
        '16:00 – 17:30 IST',
        '11:00 – 12:30 IST',
      ]);
      expect(rows.map((r) => r.mode), ['VIRTUAL', 'HYBRID BLR', 'CLOSED-DOOR']);
      expect(rows.map((r) => r.tone), [RoundtableTone.blue, RoundtableTone.green, RoundtableTone.dark]);

      // "Lead: <chair> (<org>) • N seats claimed", N being what the API counts as going.
      final leads = ['Vikram Malhotra (DLF)', 'Rajesh Sharma (Infosys)', 'Arvind Swamy (Brookfield)'];
      for (final (i, r) in rows.indexed) {
        final event = (await api.dio.get<Map<String, dynamic>>('/events/${r.slug}')).data!;
        expect(r.detail, 'Lead: ${leads[i]} • ${event['attendeeCount']} seats claimed');
        expect(event['attendeeCount'], greaterThan(0));
      }
      expect(controller.overview!.roundtablesCaption, 'All events');
    },
  );

  liveTest(
    'the member\'s rail is their seats: the executive seat with its unread count, then the next session',
    () async {
      final controller = await _controller();
      if (!await _seeded(controller)) return;
      final api = await liveClient();
      final joined = controller.joined;

      // The executive seat first, then the soonest session, then the rest.
      expect(joined.first.slug, 'cxo-workplace-strategy-design');
      expect(joined.first.membership, CouncilRole.lead);
      expect(joined.map((c) => c.slug).toSet(), _designedSeats);
      expect(joined[1].slug, 'sustainability-esg-net-zero-design');
      expect(joined[1].membership, CouncilRole.member);

      // "N unread" is what the council posted in the last 30 days.
      final posts = (await api.dio.get<List<dynamic>>('/councils/${joined.first.slug}/announcements')).data!;
      final since = DateTime.now().subtract(unreadWindow);
      final recent = posts.where((p) => DateTime.parse(p['createdAt'] as String).isAfter(since)).length;
      expect(
        recent,
        greaterThan(0),
        reason: 'the seed posts three announcements to the CXO council: re-run tool/seed/run.ps1',
      );
      expect(joined.first.unread, recent);
      // A council with nothing recent shows its next session instead.
      expect(joined[1].unread, 0);
      expect(monthDay(joined[1].nextEventAt!), 'Apr 18');
    },
  );

  liveTest('a council joined is a seat the API keeps, and leaving gives it back', () async {
    final poojaApi = await liveClient(pooja);
    final repo = ApiCouncilsRepository(api: poojaApi);
    final before = await repo.overview();
    final target = before.councils.firstWhere(
      (c) =>
          !c.joined &&
          !c.slug.endsWith('-design') &&
          !_designSlugs.contains(c.slug) &&
          !_designedSeats.contains(c.slug),
    );
    final seatsBefore = before.joined.map((c) => c.id).toSet();
    var joinedByTest = false;
    addTearDown(() async {
      if (joinedByTest) await repo.leave(target);
    });

    joinedByTest = true;
    expect(await repo.join(target), CouncilRole.member);
    final during = await repo.overview();
    expect(during.joined.map((c) => c.id), contains(target.id));
    expect(during.councils.firstWhere((c) => c.id == target.id).membership, CouncilRole.member);
    expect(during.councils.firstWhere((c) => c.id == target.id).memberCount, target.memberCount + 1);
    // The API says the same.
    final seats = (await poojaApi.dio.get<List<dynamic>>(
      '/councils/memberships/mine',
    )).data!.cast<Map<String, dynamic>>();
    expect(seats.map((s) => s['councilId']), contains(target.id));

    await repo.leave(target);
    joinedByTest = false;
    final after = await repo.overview();
    expect(after.joined.map((c) => c.id), isNot(contains(target.id)));
    expect(after.councils.firstWhere((c) => c.id == target.id).memberCount, target.memberCount);
    expect(after.joined.map((c) => c.id).toSet(), seatsBefore, reason: 'her designed seats are untouched');
  });

  liveTest('the controller takes a seat at once, keeps it across a refresh, and gives it up', () async {
    final controller = await _controller(pooja);
    final target = _spare(controller);
    final repo = controller.repository;
    var joinedByTest = false;
    addTearDown(() async {
      if (joinedByTest) await repo.leave(target);
    });

    joinedByTest = true;
    expect(await controller.join(target), isNull);
    expect(controller.find(target.id)!.joined, isTrue);
    expect(controller.joined.map((c) => c.id), contains(target.id));
    await controller.refresh(); // pull to refresh: what the server holds
    expect(controller.find(target.id)!.joined, isTrue);

    expect(await controller.leave(controller.find(target.id)!), isNull);
    joinedByTest = false;
    expect(controller.find(target.id)!.joined, isFalse);
    await controller.refresh();
    expect(controller.find(target.id)!.joined, isFalse);
    expect(controller.joined.map((c) => c.id), isNot(contains(target.id)));
  });

  liveTest('a refusal from the API rolls the seat back and says why', () async {
    // Signed out, the API refuses a join: the card must not keep the seat.
    final anonymous = CouncilsController(ApiCouncilsRepository(api: liveAnonymous()));
    await anonymous.start();
    expect(anonymous.error, isNull);
    expect(anonymous.joined, isEmpty);
    final target = anonymous.councils.first;
    final message = await anonymous.join(target);
    expect(message, isNotNull);
    expect(message, isNotEmpty);
    expect(anonymous.find(target.id)!.joined, isFalse);
    expect(anonymous.joined, isEmpty);
    expect(anonymous.isBusy(target), isFalse);

    // A council the API does not know is refused with its own sentence.
    await expectLater(
      anonymous.repository.join(const Council(id: 'no-such-council', name: 'x', slug: 'x')),
      throwsA(isA<ApiError>()),
    );
    final signedIn = await _controller(pooja);
    final unknown = await signedIn.join(const Council(id: 'no-such-council', name: 'x', slug: 'x'));
    expect(unknown, 'Council not found');
    expect(signedIn.joined.map((c) => c.slug).toSet(), _designedSeats);
  });

  liveTest('the search, the category chips and the sort choices work over the live directory', () async {
    final controller = await _controller();
    if (!await _seeded(controller)) return;
    final api = await liveClient();
    final raw = await _rows(api, '/councils');

    // Search: name, copy, topics and the chair, as the website's board reads them.
    controller.setSearch('Vikram Malhotra');
    expect(controller.councils.map((c) => c.slug), ['sustainability-esg-net-zero-design']);
    controller.setSearch('decarbonization');
    expect(controller.councils.map((c) => c.slug), contains('sustainability-esg-net-zero-design'));
    controller.setSearch('no council has this phrase');
    expect(controller.councils, isEmpty);
    controller.clearFilters();
    expect(controller.councils, hasLength(raw.length));

    // A chip narrows to the councils filed under it.
    controller.setSegment('Legal & Procurement');
    expect(controller.councils.map((c) => c.slug), ['legal-compliance-procurement-design']);
    controller.setSegment(_designCategories.last);
    expect(controller.councils.map((c) => c.slug), ['corporate-commercial-real-estate']);
    controller.setSegment(null);

    // The sort sheet's choices.
    int members(Council c) => c.memberCount;
    controller.setSort(CouncilSort.members);
    expect(
      controller.councils.map(members),
      orderedEquals([...controller.councils.map(members)]..sort((a, b) => b - a)),
    );
    expect(
      controller.councils.first.memberCount,
      raw.map((r) => r['memberCount'] as int).reduce((a, b) => a > b ? a : b),
    );
    controller.setSort(CouncilSort.az);
    final names = controller.councils.map((c) => c.name).toList();
    expect(names, orderedEquals([...names]..sort()));
    controller.setSort(CouncilSort.newest);
    final newest = raw.map((r) => DateTime.parse(r['createdAt'] as String)).reduce((a, b) => a.isAfter(b) ? a : b);
    expect(controller.councils.first.createdAt, newest);
    controller.setSort(CouncilSort.active);
    final scores = controller.councils.map((c) => c.upcomingEventCount * 10 + c.memberCount).toList();
    expect(scores, orderedEquals([...scores]..sort((a, b) => b - a)));
    controller.setSort(CouncilSort.recommended);
    expect(controller.councils.take(6).map((c) => c.slug), _designSlugs);
  });

  liveTest('the links open pages the API knows, and the calendar entry is the event\'s own', () async {
    final controller = await _controller();
    if (!await _seeded(controller)) return;
    final api = await liveClient();
    final repo = controller.repository;

    // A council's page and its tabs: the slug resolves.
    final council = controller.councils.first;
    expect(repo.link(council).path, '/councils/${council.slug}');
    expect(repo.link(council, tab: 'events').queryParameters, {'tab': 'events'});
    expect((await api.dio.get<Map<String, dynamic>>('/councils/${council.slug}')).data!['id'], council.id);

    // A roundtable's page, and a calendar entry with the API's own start and end.
    final rt = controller.roundtables.first;
    expect(repo.eventLink(rt).path, '/events/${rt.slug}');
    final event = (await api.dio.get<Map<String, dynamic>>('/events/${rt.slug}')).data!;
    final entry = repo.calendarLink(rt);
    String stamp(String iso) => DateTime.parse(iso).toUtc().toIso8601String().replaceAll(RegExp(r'[-:]|\.\d+'), '');
    expect(entry.queryParameters['dates'], '${stamp(event['startsAt'] as String)}/${stamp(event['endsAt'] as String)}');
    expect(entry.queryParameters['text'], event['title']);
    expect(entry.queryParameters['location'], event['location']);

    // A chapter's page.
    final chapter = controller.chapters.first;
    expect(repo.chapterLink(chapter).path, '/chapters/${chapter.slug}');
    expect((await api.dio.get<Map<String, dynamic>>('/chapters/${chapter.slug}')).data!['id'], chapter.id);
  });

  liveTest('the In-Person Summits tiles are the four chapters, each with the API\'s next date for it', () async {
    final controller = await _controller();
    if (!await _seeded(controller)) return;
    final api = await liveClient();
    final chapters = controller.chapters;
    expect(chapters, hasLength(4));
    expect(chapters.map((c) => c.slug).toSet(), {'bengaluru', 'mumbai', 'delhi-ncr', 'hyderabad'});

    // A chapter's date is its soonest upcoming event of any kind. The portal's own seed also holds chapter events
    // sooner than the designed 2027 summits for Bengaluru and Mumbai, so read them back rather than assume.
    final events = await _rows(api, '/events', {'when': 'upcoming'});
    DateTime? soonest(String slug) {
      final dates = [
        for (final e in events)
          if ((e['chapter'] as Map?)?['slug'] == slug) DateTime.parse(e['startsAt'] as String),
      ]..sort();
      return dates.isEmpty ? null : dates.first;
    }

    for (final c in chapters) {
      expect(c.nextEventAt, soonest(c.slug), reason: c.slug);
    }
    // The designed summits are there to be found: Delhi NCR and Hyderabad have nothing sooner.
    expect(monthDay(chapters.firstWhere((c) => c.slug == 'delhi-ncr').nextEventAt!), 'May 17');
    expect(monthDay(chapters.firstWhere((c) => c.slug == 'hyderabad').nextEventAt!), 'Jun 05');
    // Soonest first.
    final dates = chapters.map((c) => c.nextEventAt!).toList();
    expect(dates, orderedEquals([...dates]..sort()));
  });

  liveTest('pulling down reads what the server holds now', () async {
    final bharatController = await _controller();
    final poojaApi = await liveClient(pooja);
    final repo = ApiCouncilsRepository(api: poojaApi);
    final target = _spare(bharatController);
    final before = bharatController.find(target.id)!.memberCount;
    var joinedByTest = false;
    addTearDown(() async {
      if (joinedByTest) await repo.leave(target);
    });

    // Someone else takes a seat; Bharat's screen shows it only after the refresh.
    joinedByTest = true;
    await repo.join(target);
    expect(bharatController.find(target.id)!.memberCount, before);
    await bharatController.refresh();
    expect(bharatController.find(target.id)!.memberCount, before + 1);

    await repo.leave(target);
    joinedByTest = false;
    await bharatController.refresh();
    expect(bharatController.find(target.id)!.memberCount, before);
  });

  liveTest('the bell\'s count is the member\'s unread notifications', () async {
    final api = await liveClient();
    final repo = ApiCouncilsRepository(api: api);
    final raw = (await api.dio.get<Map<String, dynamic>>('/notifications/unread-count')).data!['unread'] as int;
    expect(await repo.unreadNotifications(), raw);
    final controller = await _controller();
    expect(controller.unread, raw);
  });

  group('the screen, drawn from the live API', () {
    /// The live source with the council covers swapped for the bundled design covers, since a test has no network
    /// to fetch photos from; everything else is what the API sent.
    Future<void> pumpLive(WidgetTester tester, {String? category, required String shot}) async {
      final controller = await tester.runAsync(() async {
        final c = CouncilsController(_OfflineCovers(await _repository()));
        await c.start();
        return c;
      });
      if (controller == null || controller.overview == null) fail('the councils did not load');
      if (category != null) controller.setSegment(category);
      tester.view.physicalSize = const Size(780, 5659);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: ChangeNotifierProvider.value(
            value: controller,
            child: CouncilsScreen(onBack: () {}, opener: (context, uri) async {}),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage((element.widget as Image).image, element);
        }
      });
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.ancestor(of: find.byType(CouncilsScreen), matching: find.byType(RepaintBoundary)).first,
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/screens').createSync(recursive: true);
        File('build/screens/$shot.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    testWidgets('the top of the screen reads as the design, with the local database\'s content', tags: const ['live'], (
      tester,
    ) async {
      if (!(await tester.runAsync(liveApiReachable))!) {
        markTestSkipped('the local API is not running at $liveBaseUrl');
        return;
      }
      await pumpLive(tester, shot: 'councils_live');
      expect(tester.takeException(), isNull);

      // The tiles, the rail and the roundtables, in the design's words.
      expect(find.text('Active Councils'), findsOneWidget);
      expect(find.text('Peer Members'), findsOneWidget);
      expect(find.text('Domains Covered'), findsOneWidget);
      expect(find.text('Active Roundtables'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^\+\d+ Q[1-4]$')), findsOneWidget);
      expect(find.text('Your Joined Councils'), findsOneWidget);
      expect(find.text('3 Active'), findsOneWidget);
      expect(find.text('Executive Seat'), findsOneWidget);
      expect(find.text('Member'), findsWidgets);
      expect(find.text('Room Link'), findsOneWidget);
      expect(find.text('Upcoming Roundtables'), findsOneWidget);
      for (final mode in ['VIRTUAL', 'HYBRID BLR', 'CLOSED-DOOR']) {
        expect(find.text(mode), findsOneWidget);
      }
      expect(find.textContaining(RegExp(r'^Lead: Vikram Malhotra \(DLF\) • \d+ seats claimed$')), findsOneWidget);
      expect(find.textContaining(RegExp(r'^Lead: Rajesh Sharma \(Infosys\) • \d+ seats claimed$')), findsOneWidget);
      expect(find.textContaining(RegExp(r'^Lead: Arvind Swamy \(Brookfield\) • \d+ seats claimed$')), findsOneWidget);
      // The unread pill of the executive seat.
      expect(find.textContaining(RegExp(r'^\d+ unread$')), findsOneWidget);
      // The search box and the chips.
      expect(find.text('Search councils by name, topic, or leader...'), findsOneWidget);
      expect(find.textContaining('All Categories ('), findsOneWidget);
      expect(find.text('Net-Zero & ESG'), findsOneWidget);
      expect(find.text('CXO & Workplace'), findsOneWidget);
      // The first card: the member's own council, with its pills, tags and buttons.
      expect(find.text('Sustainability, ESG & Net-Zero Council'), findsWidgets); // the rail and the directory
      expect(find.text('#NetZero'), findsOneWidget);
      expect(find.text('#NetZeroESG'), findsNothing);
      expect(find.text('Open Member Lounge'), findsWidgets);
      expect(find.text('Join Council'), findsWidgets);
      expect(find.text('Preview Chapter'), findsWidgets);
    });

    testWidgets('narrowed to one category, the list ends in the In-Person Summits footer', tags: const ['live'], (
      tester,
    ) async {
      if (!(await tester.runAsync(liveApiReachable))!) {
        markTestSkipped('the local API is not running at $liveBaseUrl');
        return;
      }
      await pumpLive(tester, category: 'Real Estate', shot: 'councils_live_footer');
      expect(find.text('Corporate & Commercial Real Estate Council'), findsOneWidget);
      expect(find.text('IN-PERSON SUMMITS'), findsOneWidget);
      expect(find.text('Regional In-Person Chapters'), findsOneWidget);
      expect(find.text('View Regional Chapters Directory'), findsOneWidget);
      // Each tile carries its chapter's next date.
      final controller = Provider.of<CouncilsController>(tester.element(find.byType(CouncilsScreen)), listen: false);
      for (final chapter in controller.chapters) {
        expect(find.text(chapter.city), findsOneWidget);
        expect(find.text(monthDay(chapter.nextEventAt!)), findsWidgets);
      }
    });
  });
}

/// The live source, with each cover that is a design council's replaced by the bundled design cover (and any
/// other photo dropped, so the card falls back to its gradient): a widget test has no network for photos.
class _OfflineCovers implements CouncilsRepository {
  _OfflineCovers(this.inner);

  final CouncilsRepository inner;

  static const _covers = {
    'sustainability-esg-net-zero-design': 'cover_sustainability',
    'cxo-workplace-strategy-design': 'cover_cxo',
    'smart-buildings-bms-proptech-design': 'cover_smart_buildings',
    'legal-compliance-procurement-design': 'cover_legal',
    'construction-projects-mep-design': 'cover_construction',
    'corporate-commercial-real-estate': 'cover_real_estate',
  };

  Council _offline(Council c) {
    final name = _covers[c.slug];
    return name == null
        ? c.copyWith(clearCover: true)
        : c.copyWith(cover: FeedPicture.asset('assets/images/demo/councils/$name.png'));
  }

  @override
  Future<CouncilsOverview> overview() async {
    final o = await inner.overview();
    return o.copyWith(councils: o.councils.map(_offline).toList(), joined: o.joined.map(_offline).toList());
  }

  @override
  Future<CouncilRole> join(Council council) => inner.join(council);
  @override
  Future<void> leave(Council council) => inner.leave(council);
  @override
  Future<int> unreadNotifications() => inner.unreadNotifications();
  @override
  Uri link(Council council, {String? tab}) => inner.link(council, tab: tab);
  @override
  Uri eventLink(Roundtable roundtable) => inner.eventLink(roundtable);
  @override
  Uri calendarLink(Roundtable roundtable) => inner.calendarLink(roundtable);
  @override
  Uri chapterLink(ChapterSummit chapter) => inner.chapterLink(chapter);
}
