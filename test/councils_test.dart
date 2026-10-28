import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/core/config.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/widgets/chips.dart' show ChipRow;
import 'package:icr_mobile/features/councils/api_councils_repository.dart';
import 'package:icr_mobile/features/councils/council_format.dart';
import 'package:icr_mobile/features/councils/council_models.dart';
import 'package:icr_mobile/features/councils/councils_controller.dart';
import 'package:icr_mobile/features/councils/councils_repository.dart';
import 'package:icr_mobile/features/councils/councils_screen.dart';
import 'package:icr_mobile/features/councils/demo_councils_repository.dart';
import 'package:icr_mobile/features/councils/widgets/council_card.dart';
import 'package:icr_mobile/features/councils/widgets/joined_council_card.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import 'helpers/fonts.dart';

class _NoTokens extends TokenStore {
  @override
  Future<String?> accessToken() async => 'token';
  @override
  Future<String?> refreshToken() async => null;
}

/// Answers each route from a table and records the calls.
class _Api implements HttpClientAdapter {
  _Api(this.routes);

  final Map<String, Object Function(RequestOptions options)> routes;
  final List<String> calls = [];
  final List<Map<String, dynamic>> queries = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    calls.add(key);
    queries.add(options.queryParameters);
    final handler = routes[key];
    if (handler == null) return ResponseBody.fromString('{"message":"Not found"}', 404, headers: _json);
    final result = handler(options);
    if (result is (int, String)) return ResponseBody.fromString(result.$2, result.$1, headers: _json);
    return ResponseBody.fromString(jsonEncode(result), 200, headers: _json);
  }

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}

// The API's rows, as `GET /councils` and `GET /events` give them.

const _councilRow = {
  'id': 'c1',
  'name': 'Sustainability, ESG & Net-Zero Council',
  'slug': 'sustainability',
  'focus': 'Scope 1-3 benchmarks',
  'segments': ['Net-Zero & ESG', 'Corporate Real Estate', 'Scope 3'],
  'description': 'Setting technical decarbonization benchmarks.',
  'coverUrl': '/uploads/councils/esg.jpg',
  'memberCount': 642,
  'upcomingEventCount': 2,
  'createdAt': '2026-10-02T08:00:00.000Z',
  'chair': {
    'id': 'u1',
    'firstName': 'Vikram',
    'lastName': 'Malhotra',
    'avatarUrl': null,
    'title': 'Director ESG @ DLF',
  },
};

const _otherRow = {
  'id': 'c2',
  'name': 'CXO Workplace Strategy & FM Leadership',
  'slug': 'cxo',
  'focus': null,
  'segments': ['CXO & Workplace'],
  'description': null,
  'coverUrl': null,
  'memberCount': 580,
  'upcomingEventCount': 0,
  'createdAt': '2025-01-01T08:00:00.000Z',
  'chair': null,
};

const _oldRow = {
  'id': 'c3',
  'name': 'Legal, Compliance & Procurement Council',
  'slug': 'legal',
  'focus': null,
  'segments': ['Legal & Procurement', 'Contracts'],
  'description': null,
  'coverUrl': null,
  'memberCount': 340,
  'upcomingEventCount': 0,
  'createdAt': '2022-09-01T08:00:00.000Z',
  'chair': null,
};

const _roundtableRow = {
  'id': 'e1',
  'title': 'ESG Mandates: BRSR Core & Scope 3',
  'slug': 'esg-mandates',
  'kind': 'ROUNDTABLE',
  'location': 'Online',
  'startsAt': '2027-04-18T10:00:00.000Z',
  'endsAt': '2027-04-18T11:30:00.000Z',
  'attendeeCount': 82,
  'inviteOnly': false,
  'council': {'id': 'c1', 'name': 'Sustainability, ESG & Net-Zero Council', 'slug': 'sustainability'},
  'chapter': null,
};

const _hybridRow = {
  'id': 'e3',
  'title': 'GCC Workplace Leadership & AI FM',
  'slug': 'gcc-workplace',
  'kind': 'ROUNDTABLE',
  'location': 'Bengaluru (Hybrid)',
  'startsAt': '2027-04-25T10:30:00.000Z',
  'endsAt': '2027-04-25T12:00:00.000Z',
  'attendeeCount': 120,
  'inviteOnly': false,
  'council': {'id': 'c2', 'name': 'CXO Workplace Strategy & FM Leadership', 'slug': 'cxo'},
  'chapter': null,
};

/// A council event that is not a roundtable: it gives its council a "Next:"
/// date but is not a row under Upcoming Roundtables.
const _workshopRow = {
  'id': 'e4',
  'title': 'BACnet working session',
  'slug': 'bacnet',
  'kind': 'WORKSHOP',
  'location': 'Online',
  'startsAt': '2027-03-01T10:00:00.000Z',
  'endsAt': null,
  'attendeeCount': 5,
  'inviteOnly': false,
  'council': {'id': 'c1', 'name': 'Sustainability, ESG & Net-Zero Council', 'slug': 'sustainability'},
  'chapter': null,
};

const _chapterEventRow = {
  'id': 'e2',
  'title': 'Bengaluru chapter meet',
  'slug': 'blr-meet',
  'kind': 'CHAPTER_MEET',
  'location': 'Bengaluru',
  'startsAt': '2027-04-26T04:30:00.000Z',
  'endsAt': null,
  'attendeeCount': 12,
  'inviteOnly': true,
  'council': null,
  'chapter': {'id': 'ch1', 'name': 'Bengaluru Chapter', 'slug': 'bengaluru'},
};

/// The clock the API source reads: the 22nd of October 2026, in the fourth quarter.
final _now = DateTime(2026, 10, 22);

ApiCouncilsRepository _repo(_Api api) {
  final client = ApiClient(tokens: _NoTokens(), baseUrl: 'http://api.test/api/v1');
  client.dio.httpClientAdapter = api;
  return ApiCouncilsRepository(api: client, clock: () => _now);
}

/// The routes of a signed-in member with three councils, one of them a seat.
Map<String, Object Function(RequestOptions options)> _routes({List<Map<String, Object?>> announcements = const []}) => {
  'GET /councils': (_) => {
    'data': [_councilRow, _otherRow, _oldRow],
    'meta': {'total': 3, 'hasNext': false},
  },
  'GET /councils/memberships/mine': (_) => [
    {
      'councilId': 'c2',
      'role': 'LEAD',
      'joinedAt': '2026-01-01T00:00:00.000Z',
      'council': {'id': 'c2', 'name': 'CXO', 'slug': 'cxo'},
    },
  ],
  'GET /councils/cxo/announcements': (_) => announcements,
  'GET /events': (o) {
    expect(o.queryParameters['when'], 'upcoming');
    final rows = o.queryParameters['kind'] == 'ROUNDTABLE'
        ? [_hybridRow, _roundtableRow]
        : [_workshopRow, _roundtableRow, _hybridRow, _chapterEventRow];
    return {
      'data': rows,
      'meta': {'total': rows.length},
    };
  },
  'GET /chapters': (_) => {
    'data': [
      {'id': 'ch2', 'name': 'Mumbai Chapter', 'slug': 'mumbai', 'city': 'Mumbai', 'memberCount': 3},
      {'id': 'ch1', 'name': 'Bengaluru Chapter', 'slug': 'bengaluru', 'city': 'Bengaluru', 'memberCount': 9},
    ],
    'meta': {'total': 2},
  },
  'GET /notifications/unread-count': (_) => {'unread': 4},
};

List<Map<String, Object?>> _posts(List<String> days) => [
  for (final (i, day) in days.indexed) {'id': 'a$i', 'title': 'Post $i', 'body': '', 'pinned': false, 'createdAt': day},
];

// --- the controller's fixtures -------------------------------------------------

Council _c(
  String id, {
  List<String> segments = const [],
  int members = 4,
  int events = 0,
  DateTime? next,
  CouncilRole? role,
  int year = 2020,
  String? chair,
  String? description,
}) => Council(
  id: id,
  name: 'Council $id',
  slug: id.toLowerCase(),
  segments: segments,
  memberCount: members,
  upcomingEventCount: events,
  nextEventAt: next,
  membership: role,
  createdAt: DateTime(year),
  chair: chair == null ? null : CouncilChair(name: chair),
  description: description,
);

/// A repository that answers with the councils it is given.
class _Fixed implements CouncilsRepository {
  _Fixed(this.build, {this.unread = 0});

  final CouncilsOverview Function(int call) build;
  int unread;
  int calls = 0;
  final joinedIds = <String>[];
  final leftIds = <String>[];
  Completer<void>? holdJoin;

  @override
  Future<CouncilsOverview> overview() async => build(calls++);

  @override
  Future<CouncilRole> join(Council council) async {
    await holdJoin?.future;
    joinedIds.add(council.id);
    return CouncilRole.member;
  }

  @override
  Future<void> leave(Council council) async => leftIds.add(council.id);

  @override
  Future<int> unreadNotifications() async => unread;

  @override
  Uri link(Council council, {String? tab}) => AppConfig.sitePage('/councils/${council.slug}');
  @override
  Uri eventLink(Roundtable roundtable) => AppConfig.sitePage('/events');
  @override
  Uri calendarLink(Roundtable roundtable) => AppConfig.sitePage('/events');
  @override
  Uri chapterLink(ChapterSummit chapter) => AppConfig.sitePage('/chapters');
}

CouncilsOverview _overviewOf(List<Council> councils) => CouncilsOverview(
  stats: CouncilStats(activeCouncils: councils.length, peerMembers: 0, domains: 0, activeRoundtables: 0),
  councils: councils,
  joined: sortJoined(councils.where((c) => c.joined)),
);

/// The six councils of the ordering tests, in the API's order (by name).
List<Council> _directory() => [
  _c(
    'J',
    segments: ['Cat J', 'shared'],
    members: 40,
    role: CouncilRole.member,
    next: DateTime.utc(2027, 6, 1),
    year: 2020,
  ),
  _c('K', segments: ['Cat K', 'shared'], members: 4, year: 2021),
  _c('L', segments: ['Cat L'], members: 30, events: 3, next: DateTime.utc(2027, 4, 10), year: 2022),
  _c('M', segments: ['Cat M'], members: 30, next: DateTime.utc(2027, 5, 1), year: 2023),
  _c('N', segments: ['Cat N'], members: 50, year: 2024),
  _c('O', segments: ['Cat O'], members: 6, next: DateTime.utc(2027, 1, 1), year: 2025),
  _c('P', segments: ['Cat P'], members: 2, next: DateTime.utc(2027, 1, 1), year: 2026),
  _c('Q', segments: ['Cat Q'], members: 31, next: DateTime.utc(2027, 4, 10), year: 2027),
];

Future<CouncilsController> _started(List<Council> councils) async {
  final controller = CouncilsController(_Fixed((_) => _overviewOf(councils)));
  await controller.start();
  return controller;
}

// --- the screen's fixtures -------------------------------------------------------

/// The demo source, recording what the screen asks of it.
class _Spy implements CouncilsRepository {
  _Spy({this.refuseJoin = false});

  final inner = DemoCouncilsRepository();
  bool refuseJoin;
  int overviewCalls = 0;
  final joinedIds = <String>[];
  final leftIds = <String>[];

  @override
  Future<CouncilsOverview> overview() {
    overviewCalls++;
    return inner.overview();
  }

  @override
  Future<CouncilRole> join(Council council) async {
    if (refuseJoin) throw ApiError('No seats today.', statusCode: 403);
    joinedIds.add(council.id);
    return inner.join(council);
  }

  @override
  Future<void> leave(Council council) async {
    leftIds.add(council.id);
    return inner.leave(council);
  }

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

/// The screen on a frame tall enough to lay out every card, with what it opened and how often Back was pressed.
class _Screen {
  _Screen(this.repository) : controller = CouncilsController(repository);

  final CouncilsRepository repository;
  final CouncilsController controller;
  final opened = <Uri>[];
  int backs = 0;

  Future<void> open(BuildContext context, Uri uri) async => opened.add(uri);

  Uri get lastOpened => opened.last;

  List<String> get cards => [for (final card in _cards) card.council.id];

  Iterable<CouncilCard> get _cards => find.byType(CouncilCard).evaluate().map((e) => e.widget as CouncilCard);
}

Future<_Screen> _pumpScreen(WidgetTester tester, [CouncilsRepository? repository, double height = 5659]) async {
  tester.view.physicalSize = Size(780, height);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final screen = _Screen(repository ?? _Spy());
  await tester.runAsync(screen.controller.start);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: ChangeNotifierProvider.value(
        value: screen.controller,
        child: CouncilsScreen(onBack: () => screen.backs++, opener: screen.open),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return screen;
}

Finder _inCard(String id, Finder inside) => find.descendant(of: find.byKey(ValueKey(id)), matching: inside);

Uri _site(String path) => AppConfig.sitePage(path);

void main() {
  setUpAll(loadAppFonts);

  group('formatting', () {
    test('dates and times read on the Indian clock', () {
      final start = DateTime.utc(2026, 4, 18, 10, 0);
      expect(monthCaps(start), 'APR');
      expect(dayOfMonth(start), '18');
      expect(monthDay(start), 'Apr 18');
      expect(monthDay(DateTime.utc(2026, 5, 2, 20, 0)), 'May 03');
      expect(timeRange(start, DateTime.utc(2026, 4, 18, 11, 30)), '15:30 – 17:00 IST');
      expect(timeRange(start, null), '15:30 IST');
    });

    test('segments become hashtags and quarters are named', () {
      expect(hashtag('Net-Zero & ESG'), '#NetZeroESG');
      expect(hashtag('Scope 3'), '#Scope3');
      expect(groupThousands(2530), '2,530');
      expect(quarterOf(DateTime(2026, 10, 22)).$1, 'Q4');
      expect(quarterOf(DateTime(2026, 10, 22)).$2, DateTime(2026, 10, 1));
      expect(quarterOf(DateTime(2027, 2, 3)).$1, 'Q1');
      expect(upcomingLabel(1), '1 Upcoming Event');
      expect(upcomingLabel(3), '3 Upcoming Events');
    });

    test('the peer count is rounded down to ten with a plus, as the design prints it', () {
      expect(peerMembersLabel(2530), '2,530+');
      expect(peerMembersLabel(1016), '1,010+');
      expect(peerMembersLabel(1222), '1,220+');
      expect(peerMembersLabel(100), '100+');
      expect(peerMembersLabel(99), '99');
      expect(peerMembersLabel(0), '0');
    });

    test('the organisation is what follows the @ in a title, up to a line break', () {
      expect(organisationOf('Director ESG @ DLF'), 'DLF');
      expect(organisationOf('Global Portfolio Head @ Standard Chartered'), 'Standard Chartered');
      expect(organisationOf('General Counsel @ Brookfield\nIndia'), 'Brookfield');
      expect(organisationOf('Council Chair'), isNull);
      expect(organisationOf('Head @ '), isNull);
      expect(organisationOf(null), isNull);
    });

    test('a roundtable names its lead and the seats claimed, else its council', () {
      const vikram = CouncilChair(name: 'Vikram Malhotra', title: 'Director ESG @ DLF');
      expect(
        roundtableLine(lead: vikram, host: 'Sustainability Council', going: 82),
        'Lead: Vikram Malhotra (DLF) • 82 seats claimed',
      );
      expect(
        roundtableLine(
          lead: const CouncilChair(name: 'Sia Picker', title: 'Council Chair'),
          host: 'X',
          going: 1,
        ),
        'Lead: Sia Picker • 1 seat claimed',
      );
      expect(
        roundtableLine(lead: null, host: 'Sustainability Council', going: 0),
        'Sustainability Council • 0 seats claimed',
      );
    });

    test('a roundtable wears its mode from what the API knows', () {
      expect(roundtableMode(kind: 'ROUNDTABLE', inviteOnly: false, location: 'Online'), (
        'VIRTUAL',
        RoundtableTone.blue,
      ));
      expect(roundtableMode(kind: 'WEBINAR', inviteOnly: false), ('VIRTUAL', RoundtableTone.blue));
      expect(roundtableMode(kind: 'ROUNDTABLE', inviteOnly: false, location: 'Bengaluru (Hybrid)'), (
        'HYBRID BLR',
        RoundtableTone.green,
      ));
      expect(roundtableMode(kind: 'ROUNDTABLE', inviteOnly: true, location: 'Mumbai'), (
        'CLOSED-DOOR',
        RoundtableTone.dark,
      ));
      expect(roundtableMode(kind: 'ROUNDTABLE', inviteOnly: true, location: 'Online'), (
        'CLOSED-DOOR',
        RoundtableTone.dark,
      ));
      expect(roundtableMode(kind: 'ROUNDTABLE', inviteOnly: false, location: 'Mumbai'), (
        'IN-PERSON',
        RoundtableTone.green,
      ));
      expect(cityCode('Hyderabad, India (Hybrid)'), 'HYD');
      expect(cityCode('Delhi NCR (Hybrid)'), 'DEL');
      expect(cityCode('Jaipur (Hybrid)'), 'JAI');
      expect(cityCode(''), isNull);
    });

    test('a cover is dressed from the council\'s age', () {
      final now = DateTime(2026, 10, 23);
      // Three years or more: an official council, "Est. 2023".
      expect(councilTier(DateTime.utc(2023, 3, 1), now), (badge: null, established: 'Est. 2023'));
      // Chartered in the last three years: "CHARTERED 2024", with no second pill.
      expect(councilTier(DateTime.utc(2024, 1, 15), now), (badge: 'CHARTERED 2024', established: null));
      expect(councilTier(DateTime.utc(2024, 2, 1), now), (badge: 'CHARTERED 2024', established: null));
      // New (under a year): just "OFFICIAL COUNCIL".
      expect(councilTier(DateTime.utc(2026, 10, 3), now), (badge: null, established: null));
      expect(councilTier(null, now), (badge: null, established: null));
      // The year is the Indian one: midnight on 1 January in Delhi is still December in UTC.
      expect(councilTier(DateTime.utc(2023, 12, 31, 20), now), (badge: 'CHARTERED 2024', established: null));
    });

    test('a roundtable becomes a calendar entry with the event\'s own times and venue', () {
      final entry = calendarEntry(
        title: 'ESG Mandates: BRSR Core & Scope 3',
        start: DateTime.utc(2027, 4, 18, 10),
        end: DateTime.utc(2027, 4, 18, 11, 30),
        location: 'Online',
        details: 'https://icr.org.in/events/esg-mandates',
      );
      expect(entry.host, 'calendar.google.com');
      expect(entry.queryParameters['action'], 'TEMPLATE');
      expect(entry.queryParameters['text'], 'ESG Mandates: BRSR Core & Scope 3');
      expect(entry.queryParameters['dates'], '20270418T100000Z/20270418T113000Z');
      expect(entry.queryParameters['location'], 'Online');
      expect(entry.queryParameters['details'], 'https://icr.org.in/events/esg-mandates');
      // An event with no end is an hour long.
      final open = calendarEntry(title: 'x', start: DateTime.utc(2027, 4, 18, 10));
      expect(open.queryParameters['dates'], '20270418T100000Z/20270418T110000Z');
      expect(open.queryParameters.containsKey('location'), isFalse);
    });

    test('the industry glyph follows the name', () {
      expect(CouncilIndustry.of('Sustainability, ESG & Net-Zero Council', []), CouncilIndustry.sustainability);
      expect(CouncilIndustry.of('Legal, Compliance & Procurement Council', []), CouncilIndustry.legal);
      expect(CouncilIndustry.of('Construction, Projects & MEP Council', []), CouncilIndustry.construction);
      expect(CouncilIndustry.of('Smart Buildings, BMS & PropTech Council', []), CouncilIndustry.tech);
      expect(CouncilIndustry.of('Corporate & Commercial Real Estate Council', []), CouncilIndustry.realEstate);
      expect(CouncilIndustry.of('CXO Workplace Strategy & FM Leadership', []), CouncilIndustry.people);
      expect(CouncilIndustry.of('Something else', []), CouncilIndustry.general);
    });

    test('the glyph of each designed council holds when its topics are read as well', () {
      CouncilIndustry of(String name, List<String> segments) => CouncilIndustry.of(name, segments);
      expect(
        of('Sustainability, ESG & Net-Zero Council', ['Net-Zero & ESG', 'NetZero', 'Decarbonization', 'Scope 3']),
        CouncilIndustry.sustainability,
      );
      expect(
        of('CXO Workplace Strategy & FM Leadership', ['CXO & Workplace', 'WorkplaceStrategy', 'Campus Ops', 'CapEx']),
        CouncilIndustry.people,
      );
      expect(
        of('Smart Buildings, BMS & PropTech Council', ['Smart Buildings', 'BMS', 'Digital Twins', 'PropTech', 'IoT']),
        CouncilIndustry.tech,
      );
      expect(
        of('Legal, Compliance & Procurement Council', [
          'Legal & Procurement',
          'SLA Compliance',
          'Procurement',
          'Contracts',
        ]),
        CouncilIndustry.legal,
      );
      // "Project Governance" is a topic of this council, not a reason to give it the gavel.
      expect(
        of('Construction, Projects & MEP Council', [
          'Construction & MEP',
          'MEP Design',
          'Project Governance',
          'Modular Build',
        ]),
        CouncilIndustry.construction,
      );
      expect(
        of('Corporate & Commercial Real Estate Council', [
          'Real Estate',
          'Transaction Mgmt',
          'Portfolio Strategy',
          'SEZ Regs',
        ]),
        CouncilIndustry.realEstate,
      );
    });
  });

  group('the API source', () {
    test('maps the directory, the seats, the roundtables and the chapters', () async {
      final api = _Api(
        _routes(
          announcements: _posts(['2026-10-20T08:00:00.000Z', '2026-09-23T08:00:00.000Z', '2026-09-21T08:00:00.000Z']),
        ),
      );
      final overview = await _repo(api).overview();

      expect(overview.stats.activeCouncils, 3);
      expect(overview.stats.peerMembers, 1562);
      expect(overview.stats.peerMembersLabel, '1,560+');
      expect(overview.stats.domains, 6);
      expect(overview.stats.newThisQuarter, 1);
      expect(overview.stats.quarter, 'Q4');
      // The tile counts what the rows are drawn from: roundtables a council hosts.
      expect(overview.stats.activeRoundtables, 2);

      final esg = overview.councils.firstWhere((c) => c.id == 'c1');
      expect(esg.cover?.url, 'http://api.test/uploads/councils/esg.jpg');
      expect(esg.category, 'Net-Zero & ESG');
      expect(esg.tags, ['#CorporateRealEstate', '#Scope3']);
      expect(esg.chair?.name, 'Vikram Malhotra');
      expect(esg.chair?.title, 'Director ESG @ DLF');
      expect(esg.joined, isFalse);
      expect(esg.activityLabel, '2 Upcoming Events');
      // Any upcoming event of the council, not only a roundtable.
      expect(monthDay(esg.nextEventAt!), 'Mar 01');
      expect(esg.badge, isNull);
      expect(esg.established, isNull);

      final cxo = overview.councils.firstWhere((c) => c.id == 'c2');
      expect(cxo.membership, CouncilRole.lead);
      expect(cxo.cover, isNull);
      expect(cxo.activityLabel, isNull);
      expect(cxo.badge, 'CHARTERED 2025');
      // A council with a single segment tags itself with it.
      expect(overview.councils.firstWhere((c) => c.id == 'c3').tags, ['#Contracts']);
      expect(overview.councils.firstWhere((c) => c.id == 'c3').established, 'Est. 2022');
      expect(overview.joined.map((c) => c.id), ['c2']);
      // Two of its three announcements are inside the last 30 days.
      expect(overview.joined.single.unread, 2);
      expect(overview.councils.firstWhere((c) => c.id == 'c2').unread, 2);
      expect(overview.councils.firstWhere((c) => c.id == 'c1').unread, 0);

      // Only roundtables, soonest first, each with its council's chair as the lead.
      expect(overview.roundtables.map((r) => r.id), ['e1', 'e3']);
      final rt = overview.roundtables.first;
      expect(rt.mode, 'VIRTUAL');
      expect(rt.tone, RoundtableTone.blue);
      expect(rt.detail, 'Lead: Vikram Malhotra (DLF) • 82 seats claimed');
      expect(timeRange(rt.startsAt, rt.endsAt), '15:30 – 17:00 IST');
      expect(monthDay(rt.startsAt), 'Apr 18');
      expect(overview.roundtablesCaption, 'All events');
      final hybrid = overview.roundtables.last;
      expect(hybrid.mode, 'HYBRID BLR');
      expect(hybrid.tone, RoundtableTone.green);
      // No chair on the hosting council: the line names the council.
      expect(hybrid.detail, 'CXO Workplace Strategy & FM Leadership • 120 seats claimed');

      expect(overview.chapters.map((c) => c.city), ['Bengaluru', 'Mumbai']);
      expect(monthDay(overview.chapters.first.nextEventAt!), 'Apr 26');
      expect(overview.chapters.last.nextEventAt, isNull);

      // The roundtables are asked for by kind; the next dates come from every upcoming event.
      expect(api.queries.where((q) => q['kind'] == 'ROUNDTABLE'), hasLength(1));
      expect(api.calls, contains('GET /councils/cxo/announcements'));
      expect(api.calls, isNot(contains('GET /councils/sustainability/announcements')));
    });

    test('an announcement read that fails leaves the unread count at none', () async {
      final routes = _routes()..remove('GET /councils/cxo/announcements');
      final overview = await _repo(_Api(routes)).overview();
      expect(overview.joined.single.unread, 0);
    });

    test('a directory of several pages is read through to the end', () async {
      final api = _Api({
        'GET /councils': (o) {
          final page = o.queryParameters['page'];
          expect(o.queryParameters['limit'], 100);
          return page == 1
              ? {
                  'data': [_councilRow],
                  'meta': {'total': 2, 'hasNext': true},
                }
              : {
                  'data': [_otherRow],
                  'meta': {'total': 2, 'hasNext': false},
                };
        },
        'GET /councils/memberships/mine': (_) => [],
        'GET /events': (_) => {'data': [], 'meta': {}},
        'GET /chapters': (_) => {'data': [], 'meta': {}},
      });
      final overview = await _repo(api).overview();
      expect(overview.councils.map((c) => c.id), ['c1', 'c2']);
      expect(overview.stats.activeCouncils, 2);
      expect(api.queries.where((q) => q.containsKey('page') && q['limit'] == 100), isNotEmpty);
    });

    test('signed out, the seats read as none and joining asks the API', () async {
      final api = _Api({
        'GET /councils': (_) => {
          'data': [_councilRow],
          'meta': {'total': 1},
        },
        'GET /councils/memberships/mine': (_) => (401, '{"statusCode":401,"message":"Unauthorized"}'),
        'GET /events': (_) => {'data': [], 'meta': {}},
        'GET /chapters': (_) => {'data': [], 'meta': {}},
        'POST /councils/c1/join': (_) => {'status': 'MEMBER'},
        'DELETE /councils/c1/join': (_) => {'status': 'NONE'},
      });
      final repo = _repo(api);
      final overview = await repo.overview();
      expect(overview.joined, isEmpty);
      expect(overview.roundtables, isEmpty);
      expect(overview.roundtablesCaption, isNull);
      expect(overview.stats.activeRoundtables, 0);
      final council = overview.councils.single;
      expect(await repo.join(council), CouncilRole.member);
      await repo.leave(council);
      expect(api.calls, containsAll(['POST /councils/c1/join', 'DELETE /councils/c1/join']));
      expect(api.calls.where((c) => c.contains('announcements')), isEmpty);
    });

    test('an executive seat comes back as the lead role and a refusal as the API\'s sentence', () async {
      final api = _Api({
        'POST /councils/c1/join': (_) => {'status': 'LEAD'},
        'DELETE /councils/c2/join': (_) => (403, '{"statusCode":403,"message":"Not yours to give up."}'),
      });
      final repo = _repo(api);
      expect(await repo.join(const Council(id: 'c1', name: 'x', slug: 'x')), CouncilRole.lead);
      await expectLater(
        repo.leave(const Council(id: 'c2', name: 'x', slug: 'x')),
        throwsA(isA<ApiError>().having((e) => e.message, 'message', 'Not yours to give up.')),
      );
    });

    test('the links point at the website\'s council tabs, event, chapter and calendar', () async {
      final repo = _repo(_Api(_routes()));
      final overview = await repo.overview();
      final esg = overview.councils.firstWhere((c) => c.id == 'c1');
      expect(repo.link(esg), _site('/councils/sustainability'));
      expect(repo.link(esg, tab: 'events'), _site('/councils/sustainability?tab=events'));
      expect(repo.link(esg, tab: 'updates').toString(), 'https://icr.org.in/councils/sustainability?tab=updates');
      final rt = overview.roundtables.first;
      expect(repo.eventLink(rt), _site('/events/esg-mandates'));
      final calendar = repo.calendarLink(rt);
      expect(calendar.host, 'calendar.google.com');
      expect(calendar.queryParameters['text'], rt.title);
      expect(calendar.queryParameters['dates'], '20270418T100000Z/20270418T113000Z');
      expect(calendar.queryParameters['location'], 'Online');
      expect(calendar.queryParameters['details'], 'https://icr.org.in/events/esg-mandates');
      expect(repo.chapterLink(overview.chapters.first), _site('/chapters/bengaluru'));
    });

    test('the bell\'s count comes from the unread notifications', () async {
      expect(await _repo(_Api(_routes())).unreadNotifications(), 4);
    });
  });

  group('the controller', () {
    test('joins at once and rolls back when the API refuses', () async {
      final councils = CouncilsController(_Spy(refuseJoin: true));
      await councils.start();
      final legal = councils.find(DemoCouncilsRepository.legal.id)!;
      expect(legal.joined, isFalse);
      final before = councils.joined.length;

      final message = await councils.join(legal);
      expect(message, 'No seats today.');
      expect(councils.find(legal.id)!.joined, isFalse);
      expect(councils.joined.length, before);
    });

    test('a join shows at once, is busy until the API answers, and keeps the seat it gives', () async {
      final repository = _Fixed((_) => _overviewOf(_directory()));
      final hold = repository.holdJoin = Completer<void>();
      final councils = CouncilsController(repository);
      await councils.start();
      final k = councils.find('K')!;

      final pending = councils.join(k);
      expect(councils.find('K')!.joined, isTrue);
      expect(councils.isBusy(k), isTrue);
      expect(councils.joined.map((c) => c.id), contains('K'));
      // A second tap while it is in flight does nothing.
      expect(await councils.join(k), isNull);
      hold.complete();
      expect(await pending, isNull);
      expect(councils.isBusy(k), isFalse);
      expect(repository.joinedIds, ['K']);
    });

    test('a join keeps the seat the API gives, and leaving gives it up', () async {
      final councils = CouncilsController(DemoCouncilsRepository());
      await councils.start();
      final legal = councils.find(DemoCouncilsRepository.legal.id)!;
      expect(await councils.join(legal), isNull);
      expect(councils.find(legal.id)!.membership, CouncilRole.member);
      expect(councils.joined.any((c) => c.id == legal.id), isTrue);

      expect(await councils.leave(councils.find(legal.id)!), isNull);
      expect(councils.find(legal.id)!.joined, isFalse);
      expect(councils.joined.any((c) => c.id == legal.id), isFalse);
    });

    test('a refused leave puts the seat back', () async {
      final councils = CouncilsController(_RefusingLeave(DemoCouncilsRepository()));
      await councils.start();
      final cxo = councils.find(DemoCouncilsRepository.cxo.id)!;
      expect(cxo.joined, isTrue);
      expect(await councils.leave(cxo), 'Stay a while.');
      expect(councils.find(cxo.id)!.membership, CouncilRole.lead);
      expect(councils.joined.map((c) => c.id), contains(cxo.id));
    });

    test('the rail lists an executive seat first, then the soonest session, and a join slots in by date', () async {
      final r = _c('R', segments: ['Cat R'], role: CouncilRole.lead);
      final councils = CouncilsController(
        _Fixed((_) {
          final all = [..._directory(), r];
          return _overviewOf(all);
        }),
      );
      await councils.start();
      expect(councils.joined.map((c) => c.id), ['R', 'J']);
      await councils.join(councils.find('L')!); // its session is in April; J's is in June
      expect(councils.joined.map((c) => c.id), ['R', 'L', 'J']);
      await councils.join(councils.find('N')!); // no session: after the others
      expect(councils.joined.map((c) => c.id), ['R', 'L', 'J', 'N']);
    });

    test('Recommended lifts a shared segment, then big communities, then the soonest session, then size', () async {
      final councils = await _started(_directory());
      expect(councils.sort, CouncilSort.recommended);
      expect(councils.councils.map((c) => c.id), [
        'K', // shares "shared" with J, the member's own
        'Q', // large, April 10, 31 members
        'L', // large, April 10, 30 members
        'M', // large, May
        'J', // large, June (a seat does not lift its own council)
        'N', // large, no session
        'O', // medium
        'P', // small
      ]);
    });

    test('the other sorts are the website\'s, ties keeping the API\'s order', () async {
      final councils = await _started(_directory());
      List<String> ids() => councils.councils.map((c) => c.id).toList();

      councils.setSort(CouncilSort.members);
      expect(ids(), ['N', 'J', 'Q', 'L', 'M', 'O', 'K', 'P']);
      councils.setSort(CouncilSort.active);
      expect(ids(), ['L', 'N', 'J', 'Q', 'M', 'O', 'K', 'P']);
      councils.setSort(CouncilSort.newest);
      expect(ids(), ['Q', 'P', 'O', 'N', 'M', 'L', 'K', 'J']);
      councils.setSort(CouncilSort.az);
      expect(ids(), ['J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q']);
    });

    test('the category chips are each council\'s first segment, in the order the cards come', () async {
      final councils = await _started([
        ..._directory(),
        _c('Z', segments: []),
        _c('Y', segments: ['Cat K']),
      ]);
      expect(councils.categories, ['Cat K', 'Cat Q', 'Cat L', 'Cat M', 'Cat J', 'Cat N', 'Cat O', 'Cat P']);
    });

    test('a category narrows to the councils filed under it, not to any topic they carry', () async {
      final councils = await _started(_directory());
      councils.setSegment('Cat K');
      expect(councils.councils.map((c) => c.id), ['K']);
      councils.setSegment('shared'); // a topic of J and K, not the category of either
      expect(councils.councils, isEmpty);
      expect(councils.narrowed, isTrue);
      councils.setSegment(null);
      expect(councils.councils, hasLength(8));
    });

    test('the search reads names, copy, topics and the chair', () async {
      final councils = await _started([
        _c('A', segments: ['Cat A', 'Decarbonization'], chair: 'Vikram Malhotra'),
        _c('B', segments: ['Cat B'], description: 'Hybrid occupancy benchmarks'),
        _c('C', segments: ['Cat C']),
      ]);
      List<String> ids() => councils.councils.map((c) => c.id).toList();

      councils.setSearch('vikram');
      expect(ids(), ['A']);
      councils.setSearch('  OCCUPANCY ');
      expect(ids(), ['B']);
      councils.setSearch('decarbon');
      expect(ids(), ['A']);
      councils.setSearch('council c');
      expect(ids(), ['C']);
      councils.setSearch('nothing like it');
      expect(ids(), isEmpty);
      councils.clearFilters();
      expect(ids(), hasLength(3));
      expect(councils.narrowed, isFalse);
    });

    test('the search and the category narrow the design\'s directory', () async {
      final councils = CouncilsController(DemoCouncilsRepository());
      await councils.start();
      expect(councils.councils.length, 6);
      // The design's order: by the soonest session, all six being large communities.
      expect(councils.councils.map((c) => c.slug), [
        'sustainability-esg-net-zero',
        'cxo-workplace-strategy',
        'smart-buildings-bms-proptech',
        'legal-compliance-procurement',
        'construction-projects-mep',
        'corporate-commercial-real-estate',
      ]);
      expect(councils.categories, [
        'Net-Zero & ESG',
        'CXO & Workplace',
        'Smart Buildings',
        'Legal & Procurement',
        'Construction & MEP',
        'Real Estate',
      ]);

      councils.setSearch('Vikram');
      expect(councils.councils.map((c) => c.id), [DemoCouncilsRepository.sustainability.id]);
      councils.setSearch('');
      councils.setSegment('Legal & Procurement');
      expect(councils.councils.map((c) => c.id), [DemoCouncilsRepository.legal.id]);
      expect(councils.narrowed, isTrue);
      councils.clearFilters();
      expect(councils.narrowed, isFalse);

      councils.setSort(CouncilSort.members);
      expect(councils.councils.first.id, DemoCouncilsRepository.sustainability.id);
      councils.setSort(CouncilSort.az);
      expect(councils.councils.first.id, DemoCouncilsRepository.cxo.id);
    });

    test('a refresh reads the councils again, and the bell with them', () async {
      final repository = _Fixed(
        (call) => _overviewOf(
          call == 0
              ? [
                  _c('A', segments: ['Cat A']),
                ]
              : [
                  _c('A', segments: ['Cat A']),
                  _c('B', segments: ['Cat B']),
                ],
        ),
        unread: 2,
      );
      final councils = CouncilsController(repository);
      await councils.start();
      expect(councils.councils, hasLength(1));
      expect(councils.unread, 2);

      repository.unread = 5;
      await councils.refresh();
      expect(repository.calls, 2);
      expect(councils.councils, hasLength(2));
      expect(councils.unread, 5);
      expect(councils.loading, isFalse);
    });

    test('a failed first read says so, and a refresh recovers', () async {
      var up = false;
      final councils = CouncilsController(
        _Fixed((_) => up ? _overviewOf([_c('A')]) : throw ApiError('No connection.')),
      );
      await councils.start();
      expect(councils.overview, isNull);
      expect(councils.error, 'No connection.');
      up = true;
      await councils.refresh();
      expect(councils.error, isNull);
      expect(councils.councils, hasLength(1));
    });
  });

  group('the screen\'s controls', () {
    testWidgets('Back and the bell', (tester) async {
      final screen = await _pumpScreen(tester);
      await tester.tap(find.byIcon(Symbols.arrow_back));
      expect(screen.backs, 1);
      await tester.tap(find.byIcon(LucideIcons.bell));
      expect(screen.lastOpened, _site('/notifications'));
    });

    testWidgets('Manage and the roundtables\' caption open the website', (tester) async {
      final screen = await _pumpScreen(tester);
      await tester.tap(find.text('Manage'));
      expect(screen.lastOpened, _site('/councils'));
      await tester.tap(find.text('Live Chatham-House'));
      expect(screen.lastOpened, _site('/events'));
    });

    testWidgets('a joined card opens its council; Room Link, the unread count and Meeting link open its tabs', (
      tester,
    ) async {
      final screen = await _pumpScreen(tester);
      final first = find.byType(JoinedCouncilCard).first;

      await tester.tap(find.descendant(of: first, matching: find.text('CXO Workplace Strategy & FM Leadership')));
      expect(screen.lastOpened, _site('/councils/cxo-workplace-strategy'));
      await tester.tap(find.text('Room Link'));
      expect(screen.lastOpened, _site('/councils/cxo-workplace-strategy?tab=events'));
      await tester.tap(find.text('3 unread'));
      expect(screen.lastOpened, _site('/councils/cxo-workplace-strategy?tab=updates'));

      // The member's card is the next in the rail, which scrolls.
      await tester.drag(first, const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('Next Sync: Apr 18'), findsOneWidget);
      await tester.tap(find.text('Meeting link').first);
      expect(screen.lastOpened, _site('/councils/sustainability-esg-net-zero?tab=events'));
      expect(screen.opened, hasLength(4));
    });

    testWidgets('a roundtable row opens its event and its calendar glyph the calendar entry', (tester) async {
      final screen = await _pumpScreen(tester);
      await tester.tap(find.text('ESG Mandates: BRSR Core & Scope 3'));
      expect(screen.lastOpened, _site('/events'));
      await tester.tap(find.byIcon(LucideIcons.calendarPlus).first);
      final entry = screen.lastOpened;
      expect(entry.host, 'calendar.google.com');
      expect(entry.queryParameters['text'], 'ESG Mandates: BRSR Core & Scope 3');
      expect(entry.queryParameters['dates'], '20260418T100000Z/20260418T113000Z');
      expect(entry.queryParameters['location'], 'Online');
      // The second row's glyph is its own entry.
      await tester.tap(find.byIcon(LucideIcons.calendarPlus).at(1));
      expect(screen.lastOpened.queryParameters['text'], 'GCC Workplace Leadership & AI FM');
      expect(screen.lastOpened.queryParameters['location'], 'Bengaluru (Hybrid)');
    });

    testWidgets('the search narrows the cards as it is typed, says when nothing matches, and clears', (tester) async {
      final screen = await _pumpScreen(tester);
      expect(screen.cards, hasLength(6));

      await tester.enterText(find.byType(TextField), 'Vikram');
      await tester.pumpAndSettle();
      expect(screen.cards, ['demo-sustainability']);

      await tester.tap(find.byIcon(LucideIcons.x)); // the clear glyph in the box
      await tester.pumpAndSettle();
      expect(screen.cards, hasLength(6));

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No councils match'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(screen.cards, hasLength(6));
      expect(find.text('No councils match'), findsNothing);
    });

    testWidgets('a category chip narrows the cards, tapping it again and All Categories widen them', (tester) async {
      final screen = await _pumpScreen(tester);
      expect(find.text('All Categories (39)'), findsOneWidget);

      await tester.tap(find.text('Net-Zero & ESG'));
      await tester.pumpAndSettle();
      expect(screen.cards, ['demo-sustainability']);
      await tester.tap(find.text('Net-Zero & ESG'));
      await tester.pumpAndSettle();
      expect(screen.cards, hasLength(6));

      // The chips are a lazy row: scroll along it to the last one.
      final row = find.descendant(of: find.byType(ChipRow), matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(find.text('Real Estate'), 150, scrollable: row);
      await tester.ensureVisible(find.text('Real Estate'));
      await tester.tap(find.text('Real Estate'));
      await tester.pumpAndSettle();
      expect(screen.cards, ['demo-real-estate']);
      await tester.drag(row, const Offset(900, 0)); // back to the first chip
      await tester.pumpAndSettle();
      await tester.tap(find.text('All Categories (39)'));
      await tester.pumpAndSettle();
      expect(screen.cards, hasLength(6));
    });

    testWidgets('the filters glyph opens the sort choices and a choice reorders the cards', (tester) async {
      final screen = await _pumpScreen(tester);
      expect(screen.cards.first, 'demo-sustainability');

      await tester.tap(find.byIcon(LucideIcons.slidersHorizontal));
      await tester.pumpAndSettle();
      for (final label in ['Recommended', 'Most members', 'Most active', 'Newest', 'A to Z']) {
        expect(find.text(label), findsOneWidget);
      }
      Finder ticked(String label) =>
          find.descendant(of: find.widgetWithText(ListTile, label), matching: find.byIcon(LucideIcons.check));
      expect(ticked('Recommended'), findsOneWidget);
      await tester.tap(find.text('A to Z'));
      await tester.pumpAndSettle();
      expect(screen.cards, [
        'demo-cxo',
        'demo-construction',
        'demo-real-estate',
        'demo-legal',
        'demo-smart-buildings',
        'demo-sustainability',
      ]);

      await tester.tap(find.byIcon(LucideIcons.slidersHorizontal));
      await tester.pumpAndSettle();
      expect(ticked('A to Z'), findsOneWidget);
      expect(ticked('Recommended'), findsNothing);
      await tester.tap(find.text('Most members'));
      await tester.pumpAndSettle();
      expect(screen.cards.first, 'demo-sustainability');
      expect(screen.cards.last, 'demo-legal');
    });

    testWidgets('Join Council takes a seat at once, and a refusal puts it back with the API\'s sentence', (
      tester,
    ) async {
      final spy = _Spy();
      final screen = await _pumpScreen(tester, spy);
      expect(find.text('3 Active'), findsOneWidget);
      await tester.tap(_inCard('demo-legal', find.text('Join Council')));
      await tester.pumpAndSettle();
      expect(spy.joinedIds, ['demo-legal']);
      expect(_inCard('demo-legal', find.text('Open Member Lounge')), findsOneWidget);
      expect(_inCard('demo-legal', find.text('JOINED')), findsOneWidget);
      expect(_inCard('demo-legal', find.text('Member')), findsOneWidget);
      expect(find.text('4 Active'), findsOneWidget);
      expect(screen.opened, isEmpty);

      spy.refuseJoin = true;
      await tester.tap(_inCard('demo-construction', find.text('Join Council')));
      await tester.pumpAndSettle();
      expect(find.text('No seats today.'), findsOneWidget);
      expect(_inCard('demo-construction', find.text('Join Council')), findsOneWidget);
      expect(find.text('4 Active'), findsOneWidget);
    });

    testWidgets(
      'Open Member Lounge opens the council\'s updates, a long press offers to leave, and leaving gives the seat up',
      (tester) async {
        final spy = _Spy();
        final screen = await _pumpScreen(tester, spy);
        await tester.tap(_inCard('demo-cxo', find.text('Open Member Lounge')));
        expect(screen.lastOpened, _site('/councils/cxo-workplace-strategy?tab=updates'));

        await tester.longPress(_inCard('demo-cxo', find.text('Open Member Lounge')));
        await tester.pumpAndSettle();
        expect(find.text('Leave CXO Workplace Strategy & FM Leadership'), findsOneWidget);
        await tester.tap(find.text('Leave CXO Workplace Strategy & FM Leadership'));
        await tester.pumpAndSettle();
        expect(spy.leftIds, ['demo-cxo']);
        expect(_inCard('demo-cxo', find.text('Join Council')), findsOneWidget);
        expect(_inCard('demo-cxo', find.text('JOINED')), findsNothing);
        expect(find.text('2 Active'), findsOneWidget);
      },
    );

    testWidgets('Preview Chapter opens the council\'s page', (tester) async {
      final screen = await _pumpScreen(tester);
      await tester.tap(_inCard('demo-legal', find.text('Preview Chapter')));
      expect(screen.lastOpened, _site('/councils/legal-compliance-procurement'));
    });

    testWidgets('pulling down reads the councils again', (tester) async {
      final spy = _Spy();
      // A phone-sized frame: the indicator arms after a fraction of the list's height.
      await _pumpScreen(tester, spy, 1600);
      expect(spy.overviewCalls, 1);
      await tester.fling(find.byType(ListView).first, const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(spy.overviewCalls, 2);
    });

    testWidgets('a city tile opens its chapter and the directory button the chapters page', (tester) async {
      final screen = await _pumpScreen(tester);
      // The page is taller at the app's text sizes than the test window: scroll to what is tapped.
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('Mumbai'), 200, scrollable: scrollable);
      await tester.tap(find.text('Mumbai'));
      expect(screen.lastOpened, _site('/chapters/mumbai'));
      await tester.scrollUntilVisible(find.text('View Regional Chapters Directory'), 200, scrollable: scrollable);
      await tester.pump();
      await tester.tap(find.text('View Regional Chapters Directory'));
      expect(screen.lastOpened, _site('/chapters'));
    });

    testWidgets('a failed read offers Try again, which reads again', (tester) async {
      var up = false;
      final repository = _Fixed(
        (_) => up
            ? _overviewOf([
                _c('A', segments: ['Cat A']),
              ])
            : throw ApiError('No connection.'),
      );
      await _pumpScreen(tester, repository);
      expect(find.text("Couldn't load councils"), findsOneWidget);
      expect(find.text('No connection.'), findsOneWidget);
      up = true;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load councils"), findsNothing);
      expect(find.text('Council A'), findsOneWidget);
    });

    testWidgets('the screen draws what the API gave, worded as the design words it', (tester) async {
      final routes = _routes(announcements: _posts(['2026-10-20T08:00:00.000Z', '2026-10-15T08:00:00.000Z']));
      // No cover photo: a test has no network to fetch it from.
      routes['GET /councils'] = (_) => {
        'data': [
          {..._councilRow, 'coverUrl': null},
          _otherRow,
          _oldRow,
        ],
        'meta': {'total': 3, 'hasNext': false},
      };
      final api = _Api(routes);
      final client = ApiClient(tokens: _NoTokens(), baseUrl: 'http://api.test/api/v1')..dio.httpClientAdapter = api;
      final repository = ApiCouncilsRepository(api: client, clock: () => _now);
      final screen = await _pumpScreen(tester, repository);

      // The tiles.
      expect(find.text('+1 Q4'), findsOneWidget);
      expect(find.text('1,560+'), findsOneWidget);
      expect(find.text('Active Roundtables'), findsOneWidget);
      // The rail: the executive seat and its recent announcements.
      expect(find.text('Executive Seat'), findsOneWidget);
      expect(find.text('2 unread'), findsOneWidget);
      expect(find.text('1 Active'), findsOneWidget);
      // The rows.
      expect(find.text('VIRTUAL'), findsOneWidget);
      expect(find.text('HYBRID BLR'), findsOneWidget);
      expect(find.text('Lead: Vikram Malhotra (DLF) • 82 seats claimed'), findsOneWidget);
      expect(find.text('CXO Workplace Strategy & FM Leadership • 120 seats claimed'), findsOneWidget);
      // The chips and the cards.
      expect(find.text('All Categories (3)'), findsOneWidget);
      expect(find.text('Net-Zero & ESG'), findsOneWidget);
      expect(find.text('#Scope3'), findsOneWidget);
      expect(find.text('#NetZeroESG'), findsNothing);
      expect(find.text('JOINED'), findsOneWidget);
      expect(find.text('Executive'), findsOneWidget);
      expect(find.text('Est. 2022'), findsOneWidget);
      expect(find.text('2 Upcoming Events'), findsOneWidget);
      expect(screen.cards, hasLength(3));
    });
  });
}

/// The demo source, except that giving a seat up fails.
class _RefusingLeave implements CouncilsRepository {
  _RefusingLeave(this.inner);

  final CouncilsRepository inner;

  @override
  Future<void> leave(Council council) async => throw ApiError('Stay a while.', statusCode: 403);

  @override
  Future<CouncilRole> join(Council council) => inner.join(council);
  @override
  Future<CouncilsOverview> overview() => inner.overview();
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
