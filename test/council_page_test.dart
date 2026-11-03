import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/app_screens.dart' show inAppSiteRoute;
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/chapters/chapter_models.dart' show ChapterEvent, ChapterRole;
import 'package:icr_mobile/features/chapters/community_kit.dart';
import 'package:icr_mobile/features/councils/api_councils_repository.dart';
import 'package:icr_mobile/features/councils/council_format.dart' show sortJoined;
import 'package:icr_mobile/features/councils/council_controller.dart';
import 'package:icr_mobile/features/councils/council_models.dart';
import 'package:icr_mobile/features/councils/council_screen.dart';
import 'package:icr_mobile/features/councils/councils_controller.dart';
import 'package:icr_mobile/features/councils/councils_repository.dart';
import 'package:icr_mobile/features/councils/councils_screen.dart';
import 'package:icr_mobile/features/councils/demo_councils_repository.dart';
import 'package:icr_mobile/features/councils/widgets/joined_council_card.dart';
import 'package:icr_mobile/features/feed/feed_models.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import 'helpers/community_fakes.dart' show TableApi;
import 'helpers/fonts.dart';

// The API's rows, as `GET /councils/:slug`, its members, resources and announcements, and `GET /events` give them.

const _councilRow = {
  'id': 'k1',
  'name': 'CXO Workplace Strategy',
  'slug': 'cxo-workplace-strategy',
  'focus': 'Campus consolidation',
  'segments': ['CXO & Workplace', 'Leadership'],
  'description': 'Executive strategy table.',
  'coverUrl': '/uploads/cxo.jpg',
  'memberCount': 580,
  'upcomingEventCount': 2,
  'createdAt': '2022-09-01T00:00:00.000Z',
  'chair': {
    'id': 'u1',
    'firstName': 'Rajesh',
    'lastName': 'Sharma',
    'avatarUrl': '/uploads/rajesh.jpg',
    'title': 'VP Facilities @ Infosys',
  },
};

const _otherRow = {
  'id': 'k2',
  'name': 'Legal & Procurement',
  'slug': 'legal-procurement',
  'focus': null,
  'segments': ['Legal'],
  'description': null,
  'coverUrl': null,
  'memberCount': 340,
  'upcomingEventCount': 0,
  'createdAt': '2025-01-01T00:00:00.000Z',
  'chair': null,
};

const _eventRow = {
  'id': 'e1',
  'title': 'Quarterly roundtable',
  'slug': 'q-roundtable',
  'kind': 'ROUNDTABLE',
  'description': '<p>Closed door.</p>',
  'location': 'Bengaluru (Hybrid)',
  'capacity': 60,
  'priceAmount': null,
  'startsAt': '2026-11-20T10:00:00.000Z',
  'endsAt': '2026-11-20T12:00:00.000Z',
  'attendeeCount': 12,
  'chapter': null,
  'council': {'id': 'k1', 'name': 'CXO Workplace Strategy', 'slug': 'cxo-workplace-strategy'},
  'inviteOnly': true,
};

final _detailJson = {
  ..._councilRow,
  'contactEmail': 'cxo@icr.test',
  'aboutHtml':
      '<h3>Mission</h3>\n<p>To steer the &amp; workplace.</p>\n<ul>\n<li>Roundtables</li>\n<li>Benchmarks</li>\n</ul>',
  'galleryUrls': ['/uploads/g1.jpg'],
  'stats': {
    'memberCount': 580,
    'leadershipCount': 2,
    'upcomingEventCount': 2,
    'pastEventCount': 7,
    'memberCompanyCount': 31,
  },
  'leads': [
    {
      'id': 'u1',
      'firstName': 'Rajesh',
      'lastName': 'Sharma',
      'avatarUrl': '/uploads/rajesh.jpg',
      'title': 'Chair',
      'linkedinUrl': 'https://www.linkedin.com/in/rajesh',
      'company': {'name': 'Infosys', 'logoUrl': null},
    },
    {'id': 'u2', 'firstName': 'Ananya', 'lastName': 'Rao', 'avatarUrl': null, 'title': 'Vice Chair', 'company': null},
  ],
  'upcomingEvents': [
    {..._eventRow, 'startsAt': '2026-12-01T10:00:00.000Z'},
    _eventRow,
  ],
};

Map<String, dynamic> _page(List<Object> rows, {bool hasNext = false, int? total, int page = 1}) => {
  'data': rows,
  'meta': {
    'page': page,
    'limit': 100,
    'total': total ?? rows.length,
    'totalPages': 1,
    'hasNext': hasNext,
    'hasPrev': false,
  },
};

/// A phone 390 dp wide and [height] dp tall: tall enough that a lazy list builds the whole screen.
void _view(WidgetTester tester, {double height = 5200}) {
  tester.view.physicalSize = Size(780, height * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

// --- a source for the board and the page ---------------------------------------------------------------

Council _council(
  String slug, {
  String? name,
  CouncilRole? role,
  int members = 40,
  int events = 0,
  List<String> segments = const ['Cat'],
  CouncilChair? chair,
  String? description,
  DateTime? next,
}) => Council(
  id: 'id-$slug',
  name: name ?? 'Council $slug',
  slug: slug,
  focus: 'Focus of $slug',
  description: description,
  segments: segments,
  tags: const [],
  memberCount: members,
  upcomingEventCount: events,
  createdAt: DateTime.utc(2022, 9, 1),
  chair: chair,
  membership: role,
  nextEventAt: next,
);

ChapterEvent _event(
  String id,
  String title,
  DateTime at, {
  String? status,
  int? price,
  int going = 12,
  int? capacity,
}) => ChapterEvent(
  id: id,
  slug: '$id-slug',
  title: title,
  kind: 'ROUNDTABLE',
  location: 'Bengaluru (Hybrid)',
  startsAt: at,
  endsAt: at.add(const Duration(hours: 2)),
  capacity: capacity,
  attendeeCount: going,
  priceAmount: price,
  myStatus: status,
);

/// A recording source for the board and the page behind it: every call is logged by name, a call can be made to
/// fail with an [ApiError], and a join or leave changes the member's seat the way the API's does.
class FakeCouncils implements CouncilsRepository, CouncilPageRepository {
  FakeCouncils({List<Council>? councils, this.unread = 0}) : councils = councils ?? _sampleCouncils();

  List<Council> councils;
  int unread;
  final calls = <String>[];

  /// Method name (or `method:arg`) to what it throws.
  final failures = <String, Object>{};

  /// Calls wait on this when set (to see a loading state).
  Future<void>? gate;

  /// A call by name ('detail', 'members'…) that waits on its own gate: a slow section on a quick page.
  final gates = <String, Future<void>>{};

  List<CouncilEvent> upcoming = [_event('e1', 'Quarterly roundtable', DateTime.utc(2026, 11, 20, 10), status: 'GOING')];
  List<CouncilEvent> past = [_event('e0', 'Annual forum 2025', DateTime.utc(2025, 11, 14, 4, 30), going: 180)];
  List<CouncilUpdate> updatesNow = [
    CouncilUpdate(
      id: 'a1',
      title: 'Welcome to the council',
      body: 'Hello members',
      pinned: true,
      createdAt: DateTime.utc(2026, 10, 1),
    ),
  ];
  List<CouncilResource> resourcesNow = const [
    CouncilResource(
      id: 'r1',
      title: 'Benchmark 2026',
      kind: 'WHITEPAPER',
      url: 'https://files.test/b.pdf',
      sizeLabel: '2 MB',
    ),
  ];
  List<CouncilPerson> roster = [
    for (var i = 1; i <= 5; i++)
      CouncilPerson(
        id: 'p$i',
        firstName: 'Person',
        lastName: 'Number$i',
        company: i.isEven ? 'Acme' : null,
        role: i == 1 ? ChapterRole.lead : ChapterRole.member,
      ),
  ];
  List<FeedPicture> gallery = const [];
  List<AboutBlock> aboutNow = const [
    AboutBlock(AboutKind.heading, 'Mission'),
    AboutBlock(AboutKind.paragraph, 'Steer the workplace.'),
    AboutBlock(AboutKind.bullet, 'Roundtables'),
  ];
  List<CouncilPerson> leadsNow = const [
    CouncilPerson(
      id: 'l1',
      firstName: 'Rajesh',
      lastName: 'Sharma',
      title: 'Chair',
      company: 'Infosys',
      linkedinUrl: 'https://www.linkedin.com/in/rajesh',
      role: ChapterRole.lead,
    ),
    CouncilPerson(id: 'l2', firstName: 'Ananya', lastName: 'Rao', title: 'Vice Chair', role: ChapterRole.lead),
  ];
  int pageSize = 2;

  Future<T> _call<T>(String name, T Function() body, [String? arg]) async {
    final key = arg == null ? name : '$name:$arg';
    calls.add(key);
    if (gate != null) await gate;
    final own = gates[name];
    if (own != null) await own;
    final failure = failures[key] ?? failures[name];
    if (failure != null) throw failure;
    return body();
  }

  int count(String name) => calls.where((c) => c == name || c.startsWith('$name:')).length;

  Council find(String idOrSlug) => councils.firstWhere(
    (c) => c.slug == idOrSlug || c.id == idOrSlug,
    orElse: () => throw ApiError('Council not found', statusCode: 404),
  );

  @override
  Future<CouncilsOverview> overview() => _call(
    'overview',
    () => CouncilsOverview(
      stats: CouncilStats(
        activeCouncils: councils.length,
        peerMembers: councils.fold(0, (n, c) => n + c.memberCount),
        domains: 3,
        activeRoundtables: 0,
      ),
      councils: List.of(councils),
      joined: sortJoined(councils.where((c) => c.joined)),
    ),
  );

  @override
  Future<CouncilDetail> detail(String idOrSlug) => _call('detail', () {
    final c = find(idOrSlug);
    return CouncilDetail(
      council: c,
      contactEmail: c.slug == 'cxo-workplace-strategy' ? 'cxo@icr.test' : null,
      about: aboutNow,
      gallery: gallery,
      stats: CouncilKpis(
        memberCount: c.memberCount,
        memberCompanyCount: 31,
        upcomingEventCount: c.upcomingEventCount,
        pastEventCount: 4,
        leadershipCount: 2,
      ),
      leads: leadsNow,
    );
  }, idOrSlug);

  @override
  Future<CouncilMembersPage> members(
    String slug, {
    int page = 1,
    String? search,
    MemberFilter filter = MemberFilter.all,
  }) => _call('members', () {
    var rows = roster;
    if (filter == MemberFilter.committee) rows = rows.where((p) => p.role == ChapterRole.lead).toList();
    if (filter == MemberFilter.corporate) rows = rows.where((p) => p.company != null).toList();
    final q = (search ?? '').trim().toLowerCase();
    if (q.isNotEmpty) rows = rows.where((p) => p.name.toLowerCase().contains(q)).toList();
    final from = (page - 1) * pageSize;
    final slice = rows.skip(from).take(pageSize).toList();
    return CouncilMembersPage(members: slice, total: rows.length, page: page, hasNext: from + pageSize < rows.length);
  }, '$slug:$page:${filter.name}:${search ?? ''}');

  @override
  Future<List<CouncilEvent>> events(String slug, {bool past = false}) =>
      _call('events', () => past ? this.past : upcoming, '$slug:${past ? 'past' : 'upcoming'}');

  @override
  Future<List<CouncilUpdate>> updates(String slug) => _call('updates', () => updatesNow, slug);

  @override
  Future<List<CouncilResource>> resources(String slug) => _call('resources', () => resourcesNow, slug);

  @override
  Future<CouncilRole> join(Council council) => _call('join', () {
    councils = [for (final c in councils) c.id == council.id ? c.copyWith(membership: CouncilRole.member) : c];
    return CouncilRole.member;
  }, council.id);

  @override
  Future<void> leave(Council council) => _call('leave', () {
    councils = [for (final c in councils) c.id == council.id ? c.copyWith(clearMembership: true) : c];
  }, council.id);

  @override
  Future<int> unreadNotifications() => _call('unread', () => unread);

  @override
  Uri link(Council council, {String? tab}) =>
      Uri.parse('https://icr.test/councils/${council.slug}${tab == null ? '' : '?tab=$tab'}');

  @override
  Uri eventLink(Roundtable roundtable) => Uri.parse('https://icr.test/events/${roundtable.id}');
  @override
  Uri calendarLink(Roundtable roundtable) => Uri.parse('https://icr.test/events');
  @override
  Uri chapterLink(ChapterSummit chapter) => Uri.parse('https://icr.test/chapters/${chapter.slug}');
}

/// The member leads CXO, belongs to ESG and has not joined Legal.
List<Council> _sampleCouncils() => [
  _council(
    'cxo-workplace-strategy',
    name: 'CXO Workplace Strategy',
    role: CouncilRole.lead,
    members: 580,
    events: 2,
    segments: const ['CXO & Workplace', 'Leadership'],
    chair: const CouncilChair(name: 'Rajesh Sharma', title: 'VP Facilities @ Infosys'),
    description: 'Executive strategy table.',
  ),
  _council('sustainability-esg', name: 'Sustainability and ESG', role: CouncilRole.member, members: 642, events: 1),
  _council('legal-procurement', name: 'Legal and Procurement', members: 340),
];

/// A council's page for [slug], with its calls and taps recorded.
class _Page {
  _Page(this.repo);

  final FakeCouncils repo;
  int backs = 0;
  int bells = 0;
  final events = <String>[];
  final members = <String>[];
  final messages = <String>[];
  final opened = <Uri>[];
  final shared = <(String, Uri)>[];
  final changed = <Council>[];

  CouncilHandoffs handoffs({bool ownBell = false, bool people = true}) => CouncilHandoffs(
    onOpenEvent: events.add,
    onBell: ownBell ? () => bells++ : null,
    onOpenMember: people ? members.add : null,
    onMessage: people ? messages.add : null,
    opener: (context, uri) async => opened.add(uri),
    share: (title, link) async => shared.add((title, link)),
  );
}

Future<_Page> _pumpPage(
  WidgetTester tester,
  String slug, {
  FakeCouncils? repo,
  String? tab,
  bool ownBell = false,
  bool people = true,
  double height = 5200,
}) async {
  _view(tester, height: height);
  final page = _Page(repo ?? FakeCouncils());
  // A fresh tree, so a second pump in one test starts its screen again.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: ChangeNotifierProvider(
        create: (_) => CouncilController(repository: page.repo, idOrSlug: slug, onChanged: page.changed.add),
        child: CouncilScreen(
          onBack: () => page.backs++,
          handoffs: page.handoffs(ownBell: ownBell, people: people),
          tab: tab,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return page;
}

/// The councils board on [repo], whose controls open the council's page.
class _Board {
  _Board(this.repo) : controller = CouncilsController(repo);

  final FakeCouncils repo;
  final CouncilsController controller;
  final opened = <Uri>[];
  final events = <String>[];
  final bells = <int>[];
}

Future<_Board> _pumpBoard(WidgetTester tester, {FakeCouncils? repo, double height = 3200}) async {
  _view(tester, height: height);
  final board = _Board(repo ?? FakeCouncils());
  await tester.runAsync(board.controller.start);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: ChangeNotifierProvider.value(
        value: board.controller,
        child: CouncilsScreen(
          onBack: () {},
          opener: (context, uri) async => board.opened.add(uri),
          handoffs: CouncilHandoffs(onOpenEvent: board.events.add, onBell: () => board.bells.add(1)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return board;
}

Finder _heading(String title) => find.descendant(of: find.byType(CommunitySectionHeading), matching: find.text(title));

double _top(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

void main() {
  setUpAll(loadAppFonts);

  group('the sections', () {
    test('a ?tab= names a section by the website\'s tab id; an unknown tab or none names none', () {
      expect(CouncilSection.fromTab('events'), CouncilSection.events);
      expect(CouncilSection.fromTab('leadership'), CouncilSection.leadership);
      expect(CouncilSection.fromTab('members'), CouncilSection.members);
      expect(CouncilSection.fromTab('knowledge'), CouncilSection.knowledge);
      expect(CouncilSection.fromTab('updates'), CouncilSection.updates);
      expect(CouncilSection.fromTab('overview'), CouncilSection.overview);
      expect(CouncilSection.fromTab('gallery'), CouncilSection.gallery);
      // The website's Discussions tab is a "coming soon" card there; the page has no such part.
      expect(CouncilSection.fromTab('discussions'), isNull);
      expect(CouncilSection.fromTab('nonsense'), isNull);
      expect(CouncilSection.fromTab(null), isNull);
      expect(CouncilSection.values.map((s) => s.tab).take(6), [
        'overview',
        'events',
        'leadership',
        'members',
        'knowledge',
        'updates',
      ]);
    });

    test('a seat taken or given back moves the member count, never below zero', () {
      const kpis = CouncilKpis(memberCount: 1, memberCompanyCount: 3, pastEventCount: 4);
      expect(kpis.withMembers(1).memberCount, 2);
      expect(kpis.withMembers(-1).memberCount, 0);
      expect(kpis.withMembers(-5).memberCount, 0);
      expect(kpis.withMembers(1).memberCompanyCount, 3);
      expect(kpis.withMembers(1).pastEventCount, 4);
    });
  });

  group('the API mapping', () {
    TableApi api({bool signedIn = true}) => TableApi({
      'GET /councils': (o) => _page([_councilRow, _otherRow]),
      'GET /councils/memberships/mine': (_) => signedIn
          ? [
              {
                'councilId': 'k1',
                'role': 'LEAD',
                'joinedAt': '2026-10-23T02:54:32.790Z',
                'council': {'id': 'k1'},
              },
            ]
          : (401, '{"message":"Unauthorized"}'),
      'GET /councils/cxo-workplace-strategy': (_) => _detailJson,
      'GET /councils/cxo-workplace-strategy/members': (_) => {
        'data': [
          {
            'id': 'u1',
            'firstName': 'Bharat',
            'lastName': 'Buyer',
            'avatarUrl': '/uploads/me.jpg',
            'role': 'LEAD',
            'title': 'Secretary',
            'company': {'name': 'TechCorp', 'logoUrl': null},
            'joinedAt': '2026-09-01T00:00:00.000Z',
          },
          {'id': 'u2', 'firstName': 'Pooja', 'lastName': 'Seeker', 'role': 'MEMBER', 'company': null},
        ],
        'meta': {'page': 1, 'limit': 12, 'total': 13, 'totalPages': 2, 'hasNext': true},
      },
      'GET /events': (o) => _page([
        _eventRow,
        {..._eventRow, 'id': 'e2', 'title': 'Workshop', 'slug': null, 'priceAmount': 49900},
      ]),
      'GET /events/rsvps/mine': (_) => [
        {'eventId': 'e1', 'status': 'GOING'},
        {'eventId': 'e2', 'status': 'CANCELLED'},
      ],
      'GET /councils/cxo-workplace-strategy/announcements': (_) => [
        {'id': 'a1', 'title': 'Older', 'body': 'b', 'pinned': false, 'createdAt': '2026-10-02T00:00:00.000Z'},
        {'id': 'a2', 'title': 'Pinned', 'body': 'b', 'pinned': true, 'createdAt': '2026-10-01T00:00:00.000Z'},
        {'id': 'a3', 'title': 'Newer', 'body': 'b', 'pinned': false, 'createdAt': '2026-10-05T00:00:00.000Z'},
      ],
      'GET /councils/cxo-workplace-strategy/resources': (_) => [
        {
          'id': 'r1',
          'title': 'Deck',
          'kind': 'PRESENTATION',
          'url': '/uploads/deck.pdf',
          'sizeLabel': '5 MB',
          'createdAt': '2026-10-23T00:00:00.000Z',
        },
        {'id': 'r2', 'title': 'Rec', 'kind': 'RECORDING', 'url': 'https://example.com/rec', 'sizeLabel': '58 min'},
      ],
      'POST /councils/k2/join': (_) => {'status': 'MEMBER'},
      'DELETE /councils/k1/join': (_) => {'status': 'NONE'},
      'GET /notifications/unread-count': (_) => {'unread': 4},
    });

    ApiCouncilsRepository repo(TableApi table) => ApiCouncilsRepository(api: table.client());

    test('a council\'s page: the card with the seat, About, gallery, the five figures and the leadership', () async {
      final table = api();
      final detail = await repo(table).detail('cxo-workplace-strategy');
      final c = detail.council;
      expect(c.name, 'CXO Workplace Strategy');
      expect(c.membership, CouncilRole.lead);
      expect(c.segments, ['CXO & Workplace', 'Leadership']);
      expect(c.cover!.url, 'http://api.test/uploads/cxo.jpg');
      expect(c.chair!.name, 'Rajesh Sharma');
      expect(c.chair!.title, 'VP Facilities @ Infosys');
      // The soonest of the upcoming events the page carries.
      expect(c.nextEventAt, DateTime.utc(2026, 11, 20, 10));
      expect(detail.contactEmail, 'cxo@icr.test');
      expect(detail.about, const [
        AboutBlock(AboutKind.heading, 'Mission'),
        AboutBlock(AboutKind.paragraph, 'To steer the & workplace.'),
        AboutBlock(AboutKind.bullet, 'Roundtables'),
        AboutBlock(AboutKind.bullet, 'Benchmarks'),
      ]);
      expect(detail.gallery.single.url, 'http://api.test/uploads/g1.jpg');
      expect(detail.stats.memberCount, 580);
      expect(detail.stats.memberCompanyCount, 31);
      expect(detail.stats.upcomingEventCount, 2);
      expect(detail.stats.pastEventCount, 7);
      expect(detail.stats.leadershipCount, 2);
      expect(detail.leads.map((p) => p.name), ['Rajesh Sharma', 'Ananya Rao']);
      expect(detail.leads.every((p) => p.role == ChapterRole.lead), isTrue);
      expect(detail.leads.first.company, 'Infosys');
      expect(detail.leads.first.linkedinUrl, 'https://www.linkedin.com/in/rajesh');
      expect(detail.leads.first.photo!.url, 'http://api.test/uploads/rajesh.jpg');
      expect(table.calls, containsAll(['GET /councils/cxo-workplace-strategy', 'GET /councils/memberships/mine']));
    });

    test('signed out the page still reads, with no seat; a council with no About text shows its description', () async {
      final table = api(signedIn: false);
      table.routes['GET /councils/cxo-workplace-strategy'] = (_) => {..._detailJson, 'aboutHtml': null};
      final detail = await repo(table).detail('cxo-workplace-strategy');
      expect(detail.council.membership, isNull);
      expect(detail.council.joined, isFalse);
      expect(detail.about, const [AboutBlock(AboutKind.paragraph, 'Executive strategy table.')]);
    });

    test('an id is looked up on the directory first, since the API reads councils by slug', () async {
      final table = api();
      table.routes['GET /councils/k1'] = (_) => (404, '{"message":"Council not found"}');
      final detail = await repo(table).detail('k1');
      expect(detail.council.slug, 'cxo-workplace-strategy');
      expect(
        table.calls,
        containsAllInOrder(['GET /councils/k1', 'GET /councils', 'GET /councils/cxo-workplace-strategy']),
      );
    });

    test('a slug the API does not know is the API\'s own refusal', () async {
      final table = api();
      table.routes['GET /councils/nope'] = (_) => (404, '{"message":"Council not found"}');
      await expectLater(
        repo(table).detail('nope'),
        throwsA(isA<ApiError>().having((e) => e.message, 'message', 'Council not found')),
      );
    });

    test(
      'the roster is a page of twelve with its search, Corporate only and Committee as the API takes them',
      () async {
        final table = api();
        final r = repo(table);
        final page = await r.members('cxo-workplace-strategy');
        expect(table.queryOf('GET /councils/cxo-workplace-strategy/members'), {'page': 1, 'limit': 12});
        expect(page.total, 13);
        expect(page.hasNext, isTrue);
        expect(page.members.first.name, 'Bharat Buyer');
        expect(page.members.first.role, ChapterRole.lead);
        expect(page.members.first.title, 'Secretary');
        expect(page.members.first.company, 'TechCorp');
        expect(page.members.first.photo!.url, 'http://api.test/uploads/me.jpg');
        expect(page.members.last.role, ChapterRole.member);
        expect(page.members.last.company, isNull);
        await r.members('cxo-workplace-strategy', page: 2, search: '  poo ', filter: MemberFilter.corporate);
        expect(table.queryOf('GET /councils/cxo-workplace-strategy/members'), {
          'page': 2,
          'limit': 12,
          'search': 'poo',
          'hasCompany': 'true',
        });
        await r.members('cxo-workplace-strategy', filter: MemberFilter.committee);
        expect(table.queryOf('GET /councils/cxo-workplace-strategy/members')['role'], 'LEAD');
      },
    );

    test(
      'events are the council\'s own, upcoming or past, each with the member\'s RSVP (a cancelled one is none)',
      () async {
        final table = api();
        final r = repo(table);
        final rows = await r.events('cxo-workplace-strategy');
        expect(table.queryOf('GET /events'), {
          'councilSlug': 'cxo-workplace-strategy',
          'when': 'upcoming',
          'limit': 12,
        });
        expect(rows.map((e) => e.id), ['e1', 'e2']);
        expect(rows.first.myStatus, 'GOING');
        expect(rows.first.inviteOnly, isTrue);
        expect(rows.first.description, 'Closed door.');
        expect(rows.first.kind, 'ROUNDTABLE');
        expect(rows.first.key, 'q-roundtable');
        expect(rows.last.myStatus, isNull);
        expect(rows.last.key, 'e2');
        expect(rows.last.ticketed, isTrue);
        await r.events('cxo-workplace-strategy', past: true);
        expect(table.queryOf('GET /events')['when'], 'past');
      },
    );

    test('announcements come pinned first, then newest; files get absolute links and their tag', () async {
      final r = repo(api());
      final updates = await r.updates('cxo-workplace-strategy');
      expect(updates.map((u) => u.title), ['Pinned', 'Newer', 'Older']);
      expect(updates.first.pinned, isTrue);
      final resources = await r.resources('cxo-workplace-strategy');
      expect(resources.map((x) => x.url), ['http://api.test/uploads/deck.pdf', 'https://example.com/rec']);
      expect(resources.map((x) => x.tag), ['PPTX', 'MP4']);
      expect(resources.first.sizeLabel, '5 MB');
    });

    test('joining and leaving are the board\'s calls, and the page\'s link is the website\'s', () async {
      final table = api();
      final r = repo(table);
      final detail = await r.detail('cxo-workplace-strategy');
      const legal = Council(id: 'k2', name: 'Legal & Procurement', slug: 'legal-procurement');
      expect(await r.join(legal), CouncilRole.member);
      await r.leave(detail.council);
      expect(table.calls, containsAll(['POST /councils/k2/join', 'DELETE /councils/k1/join']));
      expect(r.link(detail.council), Uri.parse('https://icr.org.in/councils/cxo-workplace-strategy'));
      expect(
        r.link(detail.council, tab: 'events'),
        Uri.parse('https://icr.org.in/councils/cxo-workplace-strategy?tab=events'),
      );
      expect(await r.unreadNotifications(), 4);
    });
  });

  group('the page\'s controller', () {
    CouncilController make(FakeCouncils repo, {String slug = 'legal-procurement', List<Council>? changed}) =>
        CouncilController(repository: repo, idOrSlug: slug, onChanged: changed?.add);

    test('reads the council, then its sections side by side, and is settled once they have answered', () async {
      final repo = FakeCouncils()..unread = 3;
      final page = make(repo);
      expect(page.settled, isFalse);
      await page.start();
      expect(page.council!.name, 'Legal and Procurement');
      expect(page.settled, isTrue);
      expect(page.unread, 3);
      expect(page.members.items, hasLength(2));
      expect(page.memberTotal, 5);
      expect(page.events.items.single.title, 'Quarterly roundtable');
      expect(page.updates.items.single.title, 'Welcome to the council');
      expect(page.resources.items.single.title, 'Benchmark 2026');
      expect(repo.count('detail'), 1);
    });

    test('a council that will not load says so, and the sections are not asked for', () async {
      final repo = FakeCouncils();
      final page = make(repo, slug: 'nowhere');
      await page.start();
      expect(page.detail, isNull);
      expect(page.error, 'Council not found');
      expect(page.settled, isFalse);
      expect(repo.count('members'), 0);
      expect(repo.count('events'), 0);
    });

    test('a section that fails keeps its own sentence and the rest of the page stands', () async {
      final repo = FakeCouncils()..failures['updates'] = ApiError('Updates are down.', statusCode: 500);
      final page = make(repo);
      await page.start();
      expect(page.detail, isNotNull);
      expect(page.updates.error, 'Updates are down.');
      expect(page.resources.items, isNotEmpty);
      expect(page.settled, isTrue, reason: 'a failed section has answered too');
      repo.failures.clear();
      await page.retryUpdates();
      expect(page.updates.error, isNull);
      expect(page.updates.items, isNotEmpty);
    });

    test('a join takes the seat and a member at once, keeps what the API answers, and tells the board', () async {
      final repo = FakeCouncils();
      final changed = <Council>[];
      final page = make(repo, changed: changed);
      await page.start();
      final before = page.detail!.stats.memberCount;
      final done = page.join();
      expect(page.council!.membership, CouncilRole.member);
      expect(page.detail!.stats.memberCount, before + 1);
      expect(page.busy, isTrue);
      expect(await done, isNull);
      expect(page.busy, isFalse);
      expect(page.council!.joined, isTrue);
      expect(changed.last.membership, CouncilRole.member);
      expect(repo.calls, contains('join:id-legal-procurement'));
      // Joined: a second join does nothing.
      expect(await page.join(), isNull);
      expect(repo.count('join'), 1);
    });

    test('a refused join puts the page back and returns the API\'s sentence', () async {
      final repo = FakeCouncils()..failures['join'] = ApiError('Council is full.', statusCode: 400);
      final changed = <Council>[];
      final page = make(repo, changed: changed);
      await page.start();
      final before = page.detail!.stats.memberCount;
      expect(await page.join(), 'Council is full.');
      expect(page.council!.joined, isFalse);
      expect(page.detail!.stats.memberCount, before);
      expect(changed.last.joined, isFalse);
    });

    test('a leave gives the seat back, and a refused one keeps it', () async {
      final repo = FakeCouncils();
      final page = make(repo, slug: 'sustainability-esg');
      await page.start();
      final before = page.detail!.stats.memberCount;
      expect(await page.leave(), isNull);
      expect(page.council!.joined, isFalse);
      expect(page.detail!.stats.memberCount, before - 1);

      final stubborn = FakeCouncils()..failures['leave'] = ApiError('Stay a while.', statusCode: 403);
      final kept = make(stubborn, slug: 'sustainability-esg');
      await kept.start();
      expect(await kept.leave(), 'Stay a while.');
      expect(kept.council!.joined, isTrue);
      expect(kept.detail!.stats.memberCount, before);
    });

    test('the roster: a search and a filter each read again, "more" appends the next page', () async {
      final repo = FakeCouncils();
      final page = make(repo);
      await page.start();
      expect(page.membersHasNext, isTrue);
      await page.moreMembers();
      expect(page.members.items.map((p) => p.id), ['p1', 'p2', 'p3', 'p4']);
      page.setMemberFilter(MemberFilter.committee);
      await Future<void>.delayed(Duration.zero);
      expect(page.members.items.map((p) => p.id), ['p1']);
      expect(page.memberTotal, 1);
      page.setMemberFilter(MemberFilter.all);
      page.setMemberSearch(' number5 ');
      await Future<void>.delayed(Duration.zero);
      expect(page.members.items.map((p) => p.id), ['p5']);
      expect(repo.calls, contains('members:legal-procurement:1:all:number5'));
    });

    test('Past reads the past events; Upcoming reads them again', () async {
      final repo = FakeCouncils();
      final page = make(repo);
      await page.start();
      await page.loadEvents(past: true);
      expect(page.pastEvents, isTrue);
      expect(page.events.items.single.title, 'Annual forum 2025');
      await page.loadEvents(past: false);
      expect(page.events.items.single.title, 'Quarterly roundtable');
      expect(repo.calls, containsAll(['events:legal-procurement:past', 'events:legal-procurement:upcoming']));
    });
  });

  group('a council\'s page', () {
    testWidgets('draws the identity, the five figures and the sections from the API', (tester) async {
      await _pumpPage(tester, 'cxo-workplace-strategy');
      expect(find.text('CXO Workplace Strategy'), findsWidgets);
      expect(find.text('Industry Council'), findsOneWidget);
      expect(find.text('CXO & Workplace'), findsWidgets);
      expect(find.text('Executive strategy table.'), findsOneWidget);
      expect(find.textContaining('Chaired by'), findsOneWidget);
      expect(find.textContaining('VP Facilities @ Infosys'), findsOneWidget);
      expect(find.text('Council lead'), findsOneWidget);
      for (final tile in ['Members', 'Companies', 'Upcoming Events', 'Events Hosted', 'Leadership']) {
        expect(find.text(tile), findsWidgets, reason: tile);
      }
      expect(find.text('580'), findsWidgets);
      expect(find.text('31'), findsOneWidget);
      expect(find.text('RSVP open'), findsOneWidget);
      for (final section in [
        'About this council',
        'Events',
        'Council leadership',
        'Members',
        'Knowledge library',
        'News & updates',
      ]) {
        expect(_heading(section), findsOneWidget, reason: section);
      }
      expect(find.text('Mission'), findsOneWidget);
      expect(find.text('Steer the workplace.'), findsOneWidget);
      expect(find.text('Roundtables'), findsOneWidget);
      expect(find.text('Industries covered'), findsOneWidget);
      expect(find.text('Rajesh Sharma'), findsOneWidget);
      expect(find.text('Chair · Infosys'), findsOneWidget);
      expect(find.text('Quarterly roundtable'), findsOneWidget);
      expect(find.text('Person Number1'), findsOneWidget);
      expect(find.text('Benchmark 2026'), findsOneWidget);
      expect(find.text('Welcome to the council'), findsOneWidget);
      expect(find.text('PINNED'), findsOneWidget);
      // No gallery to show: neither its section nor its chip.
      expect(_heading('Gallery'), findsNothing);
      expect(find.byKey(const ValueKey('chip-gallery')), findsNothing);
    });

    testWidgets('the section chips are the website\'s tabs, in order', (tester) async {
      await _pumpPage(tester, 'cxo-workplace-strategy');
      final labels = ['Overview', 'Events', 'Leadership', 'Members', 'Knowledge', 'Updates'];
      for (final label in labels) {
        final chip = find.byKey(ValueKey('chip-${label.toLowerCase()}'));
        expect(chip, findsOneWidget, reason: label);
        expect(
          find.descendant(of: chip, matching: find.text(label)),
          findsOneWidget,
          reason: label,
        );
      }
      final lefts = [for (final l in labels) tester.getTopLeft(find.byKey(ValueKey('chip-${l.toLowerCase()}'))).dx];
      expect(lefts, [...lefts]..sort(), reason: 'left to right in the website\'s order');
    });

    testWidgets('a council with a gallery shows it, with its chip', (tester) async {
      final repo = FakeCouncils()..gallery = const [FeedPicture.asset('assets/images/demo/events/card_gcc.jpg')];
      await _pumpPage(tester, 'cxo-workplace-strategy', repo: repo);
      expect(_heading('Gallery'), findsOneWidget);
      expect(find.byKey(const ValueKey('chip-gallery')), findsOneWidget);
    });

    testWidgets('a long council name wraps in the banner; the bar says "Council"', (tester) async {
      const name = 'Sustainability, ESG, Net-Zero and Climate Resilience Council for Corporate Real Estate';
      final repo = FakeCouncils(
        councils: [_council('long-one', name: name, role: CouncilRole.member)],
      );
      await _pumpPage(tester, 'long-one', repo: repo);
      expect(tester.takeException(), isNull, reason: 'a long name must not overflow');
      expect(find.text(name), findsOneWidget);
      expect(find.text('Council'), findsOneWidget);
    });

    testWidgets('Back goes back, and an unknown council says so with Try again, which reads again', (tester) async {
      final page = await _pumpPage(tester, 'cxo-workplace-strategy');
      await tester.tap(find.byIcon(Symbols.arrow_back));
      expect(page.backs, 1);

      final repo = FakeCouncils();
      await _pumpPage(tester, 'nowhere', repo: repo);
      expect(find.text("Couldn't load this council"), findsOneWidget);
      expect(find.text('Council not found'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(repo.count('detail'), 2);
    });

    testWidgets('while the first read is on its way there is a spinner and nothing else', (tester) async {
      final gate = Future<void>.delayed(const Duration(seconds: 3));
      final repo = FakeCouncils()..gate = gate;
      _view(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ChangeNotifierProvider(
            create: (_) => CouncilController(repository: repo, idOrSlug: 'cxo-workplace-strategy'),
            child: CouncilScreen(
              onBack: () {},
              handoffs: CouncilHandoffs(onOpenEvent: (_) {}),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Join Council'), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 4));
      expect(find.text('Council lead'), findsOneWidget);
    });

    testWidgets('Join Council takes the seat; Leave asks, then gives it back', (tester) async {
      final page = await _pumpPage(tester, 'legal-procurement');
      expect(find.text('Join Council'), findsOneWidget);
      expect(find.text('340'), findsWidgets);
      await tester.tap(find.text('Join Council'));
      await tester.pumpAndSettle();
      expect(page.repo.calls, contains('join:id-legal-procurement'));
      expect(find.text('Joined'), findsOneWidget);
      expect(find.text('Council lead'), findsNothing);
      expect(find.text('341'), findsWidgets);
      expect(page.changed.last.membership, CouncilRole.member);

      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(find.text('Leave Legal and Procurement?'), findsOneWidget);
      // Cancel keeps the seat.
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Cancel')));
      await tester.pumpAndSettle();
      expect(page.repo.calls, isNot(contains('leave:id-legal-procurement')));
      expect(find.text('Joined'), findsOneWidget);

      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Leave')));
      await tester.pumpAndSettle();
      expect(page.repo.calls, contains('leave:id-legal-procurement'));
      expect(find.text('Join Council'), findsOneWidget);
      expect(find.text('340'), findsWidgets);
      expect(page.changed.last.joined, isFalse);
    });

    testWidgets('a refused join says why and leaves the page as it was', (tester) async {
      final repo = FakeCouncils()..failures['join'] = ApiError('Council is full.', statusCode: 400);
      await _pumpPage(tester, 'legal-procurement', repo: repo);
      await tester.tap(find.text('Join Council'));
      await tester.pumpAndSettle();
      expect(find.text('Council is full.'), findsOneWidget);
      expect(find.text('Join Council'), findsOneWidget);
      expect(find.text('340'), findsWidgets);
    });

    testWidgets('a council lead sees "Council lead" and no Leave, as on the website', (tester) async {
      await _pumpPage(tester, 'cxo-workplace-strategy');
      expect(find.text('Council lead'), findsOneWidget);
      expect(find.text('Leave'), findsNothing);
      expect(find.text('Join Council'), findsNothing);
    });

    testWidgets('Share hands the council and its page to the share sheet; Email opens the mail app', (tester) async {
      final page = await _pumpPage(tester, 'cxo-workplace-strategy');
      await tester.tap(find.bySemanticsLabel('Share council'));
      expect(page.shared.single.$1, 'CXO Workplace Strategy');
      expect(page.shared.single.$2, Uri.parse('https://icr.test/councils/cxo-workplace-strategy'));
      await tester.tap(find.bySemanticsLabel('Email the council'));
      expect(page.opened.single, Uri(scheme: 'mailto', path: 'cxo@icr.test'));
      // A council with no contact address has no Email.
      await _pumpPage(tester, 'legal-procurement');
      expect(find.bySemanticsLabel('Email the council'), findsNothing);
    });

    testWidgets('the bell is the shell\'s callback, else the website\'s notifications; its dot is the unread count', (
      tester,
    ) async {
      final own = await _pumpPage(tester, 'cxo-workplace-strategy', ownBell: true);
      await tester.tap(find.byIcon(LucideIcons.bell));
      expect(own.bells, 1);
      expect(own.opened, isEmpty);
      final site = await _pumpPage(tester, 'cxo-workplace-strategy', repo: FakeCouncils(unread: 2));
      await tester.tap(find.byIcon(LucideIcons.bell));
      expect(site.opened.single.path, '/notifications');
    });

    testWidgets('Leadership: a row opens the member, the message glyph a conversation, the link glyph LinkedIn', (
      tester,
    ) async {
      final page = await _pumpPage(tester, 'cxo-workplace-strategy');
      await tester.tap(find.text('Rajesh Sharma'));
      expect(page.members, ['l1']);
      await tester.tap(find.byTooltip('Message Rajesh Sharma'));
      expect(page.messages, ['l1']);
      await tester.tap(find.byTooltip('LinkedIn profile of Rajesh Sharma'));
      expect(page.opened, [Uri.parse('https://www.linkedin.com/in/rajesh')]);
    });

    testWidgets('without member and message hand-offs a leader\'s row is only a row', (tester) async {
      await _pumpPage(tester, 'cxo-workplace-strategy', people: false);
      expect(find.byTooltip('Message Rajesh Sharma'), findsNothing);
      expect(find.text('Rajesh Sharma'), findsOneWidget);
    });

    testWidgets('a council with no leaders yet says so', (tester) async {
      final repo = FakeCouncils()..leadsNow = [];
      await _pumpPage(tester, 'cxo-workplace-strategy', repo: repo);
      expect(find.text('Council office-bearers will be announced shortly.'), findsOneWidget);
      expect(find.text('Rajesh Sharma'), findsNothing);
    });

    testWidgets(
      'Events: Upcoming and Past are each read, a row opens the event sheet by its slug, and an empty tab says so',
      (tester) async {
        final repo = FakeCouncils();
        final page = await _pumpPage(tester, 'cxo-workplace-strategy', repo: repo);
        expect(find.text('Quarterly roundtable'), findsOneWidget);
        expect(find.text('ROUNDTABLE'), findsOneWidget);
        // The member's place is on the row.
        expect(find.text('You are going'), findsOneWidget);
        await tester.tap(find.text('Quarterly roundtable'));
        expect(page.events, ['e1-slug']);

        await tester.tap(find.text('Past'));
        await tester.pumpAndSettle();
        expect(repo.calls, contains('events:cxo-workplace-strategy:past'));
        expect(find.text('Annual forum 2025'), findsOneWidget);
        expect(find.text('Quarterly roundtable'), findsNothing);

        repo.past = [];
        await tester.tap(find.text('Upcoming'));
        await tester.pumpAndSettle();
        repo.upcoming = [];
        await tester.tap(find.text('Past'));
        await tester.pumpAndSettle();
        expect(find.text('No past events. Past sessions will appear here.'), findsOneWidget);
        await tester.tap(find.text('Upcoming'));
        await tester.pumpAndSettle();
        expect(find.textContaining('No upcoming events'), findsOneWidget);
      },
    );

    testWidgets('a section that fails says so itself and Try again reads it; the rest of the page stands', (
      tester,
    ) async {
      final repo = FakeCouncils()
        ..failures['updates'] = ApiError('Updates are down.', statusCode: 500)
        ..failures['resources'] = ApiError('Library is down.', statusCode: 500)
        ..failures['events'] = ApiError('Events are down.', statusCode: 500)
        ..failures['members'] = ApiError('Roster is down.', statusCode: 500);
      await _pumpPage(tester, 'cxo-workplace-strategy', repo: repo);
      for (final sentence in ['Updates are down.', 'Library is down.', 'Events are down.', 'Roster is down.']) {
        expect(find.text(sentence), findsOneWidget, reason: sentence);
      }
      expect(find.text('Council lead'), findsOneWidget);
      expect(find.text('Rajesh Sharma'), findsOneWidget);
      expect(find.text('Try again'), findsNWidgets(4));
      repo.failures.clear();
      await tester.tap(find.text('Try again').first);
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsNWidgets(3));
    });

    testWidgets('Members: the total, Show more members, the three filters and the search', (tester) async {
      final repo = FakeCouncils();
      await _pumpPage(tester, 'cxo-workplace-strategy', repo: repo);
      expect(find.text('Showing 2 of 5 members'), findsOneWidget);
      expect(find.text('Person Number1'), findsOneWidget);
      expect(find.text('Person Number3'), findsNothing);
      await tester.tap(find.text('Show more members'));
      await tester.pumpAndSettle();
      expect(find.text('Person Number3'), findsOneWidget);
      expect(find.text('Person Number4'), findsOneWidget);
      expect(find.text('Showing 4 of 5 members'), findsOneWidget);

      await tester.tap(find.text('Committee'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('members:cxo-workplace-strategy:1:committee:'));
      expect(find.text('Showing 1 of 1 member'), findsOneWidget);
      expect(find.text('Person Number2'), findsNothing);

      await tester.tap(find.text('Corporate only'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('members:cxo-workplace-strategy:1:corporate:'));
      expect(find.text('Person Number2'), findsOneWidget);

      await tester.tap(find.text('All members'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nobody');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('members:cxo-workplace-strategy:1:all:nobody'));
      expect(find.text('No members match. Try a different search or clear the filter.'), findsOneWidget);
    });

    testWidgets('a roster row opens the member, by user id', (tester) async {
      final page = await _pumpPage(tester, 'cxo-workplace-strategy');
      await tester.tap(find.text('Person Number1'));
      expect(page.members, ['p1']);
    });

    testWidgets('Knowledge: a file opens where it points; with no files it says so', (tester) async {
      final page = await _pumpPage(tester, 'cxo-workplace-strategy');
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('Whitepaper · 2 MB'), findsOneWidget);
      await tester.tap(find.text('Benchmark 2026'));
      expect(page.opened, [Uri.parse('https://files.test/b.pdf')]);

      final empty = FakeCouncils()..resourcesNow = [];
      await _pumpPage(tester, 'cxo-workplace-strategy', repo: empty);
      expect(find.text("No resources yet. The council's shared assets will appear here."), findsOneWidget);
    });

    testWidgets('Updates: pinned ones are marked; none says so', (tester) async {
      await _pumpPage(tester, 'cxo-workplace-strategy');
      expect(find.text('Hello members'), findsOneWidget);
      expect(find.text('1 Oct 2026'), findsOneWidget);
      final empty = FakeCouncils()..updatesNow = [];
      await _pumpPage(tester, 'cxo-workplace-strategy', repo: empty);
      expect(find.text('No announcements yet. Council updates will appear here.'), findsOneWidget);
    });

    testWidgets('a council with no About text says so', (tester) async {
      final repo = FakeCouncils()..aboutNow = [];
      await _pumpPage(tester, 'cxo-workplace-strategy', repo: repo);
      expect(find.text('Council details will be published shortly.'), findsOneWidget);
      expect(find.text('Mission'), findsNothing);
    });

    testWidgets('the section chips scroll to their section', (tester) async {
      await _pumpPage(tester, 'cxo-workplace-strategy', height: 800);
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
      expect(scroll.position.pixels, 0);
      await tester.tap(find.byKey(const ValueKey('chip-events')));
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, greaterThan(300));
      final events = scroll.position.pixels;
      // The chips are part of the page, so they scroll away with it: back to the top for the next one.
      scroll.position.jumpTo(0);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chip-members')));
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, greaterThan(events));
    });

    testWidgets('pulling down reads the page and its sections again', (tester) async {
      final repo = FakeCouncils();
      await _pumpPage(tester, 'cxo-workplace-strategy', repo: repo, height: 800);
      expect(repo.count('detail'), 1);
      await tester.fling(find.byType(ListView).first, const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(repo.count('detail'), 2);
      expect(repo.count('updates'), 2);
      expect(repo.count('resources'), 2);
    });
  });

  group('?tab= opens the page on a section', () {
    /// The page on a short phone, opened on [tab]; how far it scrolled.
    Future<double> openOn(WidgetTester tester, String? tab) async {
      await _pumpPage(tester, 'cxo-workplace-strategy', tab: tab, height: 800);
      return tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
    }

    testWidgets('with no tab, or one the page does not have, it opens at the top', (tester) async {
      expect(await openOn(tester, null), 0);
      expect(await openOn(tester, 'discussions'), 0);
      expect(await openOn(tester, 'nonsense'), 0);
    });

    testWidgets('events lands on the Events section, leadership on Council leadership', (tester) async {
      expect(await openOn(tester, 'events'), greaterThan(300));
      expect(_top(tester, _heading('Events')), lessThan(160));
      expect(await openOn(tester, 'leadership'), greaterThan(300));
      expect(_top(tester, _heading('Council leadership')), lessThan(400));
    });

    testWidgets('members, knowledge and updates land on their section, in sight', (tester) async {
      for (final (tab, heading) in [
        ('members', 'Members'),
        ('knowledge', 'Knowledge library'),
        ('updates', 'News & updates'),
      ]) {
        expect(await openOn(tester, tab), greaterThan(300), reason: tab);
        // The last sections may rest short of the top of the window (the page ends), but they are on it.
        final top = _top(tester, _heading(heading));
        expect(top, greaterThan(40), reason: tab);
        expect(top, lessThan(780), reason: tab);
      }
    });

    testWidgets('overview lands on About this council', (tester) async {
      expect(await openOn(tester, 'overview'), greaterThan(100));
      expect(_top(tester, _heading('About this council')), lessThan(160));
    });

    testWidgets('waits for the sections: a slow roster does not leave the page short of its target', (tester) async {
      final repo = FakeCouncils()..gates['members'] = Future<void>.delayed(const Duration(seconds: 2));
      _view(tester, height: 800);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ChangeNotifierProvider(
            create: (_) => CouncilController(repository: repo, idOrSlug: 'cxo-workplace-strategy'),
            child: CouncilScreen(
              onBack: () {},
              handoffs: CouncilHandoffs(onOpenEvent: (_) {}),
              tab: 'knowledge',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
      // The council is here and the roster is not: the page has not moved yet.
      expect(find.text('Council lead'), findsOneWidget);
      expect(scroll.position.pixels, 0);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(scroll.position.pixels, greaterThan(300));
      // Near the end of the page, so it may rest short of the top of the window; it is on it.
      expect(_top(tester, _heading('Knowledge library')), inInclusiveRange(40, 780));
    });

    testWidgets('a reader who has already scrolled is not pulled away from where they are', (tester) async {
      final repo = FakeCouncils()..gates['members'] = Future<void>.delayed(const Duration(seconds: 2));
      _view(tester, height: 800);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ChangeNotifierProvider(
            create: (_) => CouncilController(repository: repo, idOrSlug: 'cxo-workplace-strategy'),
            child: CouncilScreen(
              onBack: () {},
              handoffs: CouncilHandoffs(onOpenEvent: (_) {}),
              tab: 'updates',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
      scroll.position.jumpTo(100);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(scroll.position.pixels, 100);
    });
  });

  group('the board opens the council\'s page', () {
    testWidgets('a joined card, Open Member Lounge, Preview Chapter and a seat row each open it, in the app', (
      tester,
    ) async {
      final board = await _pumpBoard(tester);
      // A joined card (the rail's first card is the executive seat).
      await tester.tap(
        find.descendant(of: find.byType(JoinedCouncilCard).first, matching: find.text('CXO Workplace Strategy')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CouncilScreen), findsOneWidget);
      expect(board.repo.calls, contains('detail:cxo-workplace-strategy'));
      expect(tester.widget<CouncilScreen>(find.byType(CouncilScreen)).tab, isNull);
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();

      // The directory card's lounge opens it on Updates.
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('id-sustainability-esg')),
          matching: find.text('Open Member Lounge'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<CouncilScreen>(find.byType(CouncilScreen)).tab, 'updates');
      expect(board.repo.calls, contains('detail:sustainability-esg'));
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();

      // Preview Chapter, on a council not joined.
      await tester.tap(
        find.descendant(of: find.byKey(const ValueKey('id-legal-procurement')), matching: find.text('Preview Chapter')),
      );
      await tester.pumpAndSettle();
      expect(board.repo.calls, contains('detail:legal-procurement'));
      expect(find.text('Join Council'), findsWidgets);
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();

      // A seat in the Your councils sheet.
      await tester.tap(find.text('Manage'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('seat-id-sustainability-esg')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('manage-seats')), findsNothing);
      expect(find.byType(CouncilScreen), findsOneWidget);
      expect(board.repo.count('detail'), 4);
      // Nothing left for the website.
      expect(board.opened, isEmpty);
    });

    testWidgets('the page\'s sessions, people and bell reach the shell\'s hand-offs through the board', (tester) async {
      final board = await _pumpBoard(tester);
      await tester.tap(
        find.descendant(of: find.byType(JoinedCouncilCard).first, matching: find.text('CXO Workplace Strategy')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quarterly roundtable'));
      expect(board.events, ['e1-slug']);
      await tester.tap(find.byIcon(LucideIcons.bell));
      expect(board.bells, [1]);
    });

    testWidgets('a seat taken on the page shows on the board behind it, and the rail of joined councils grows', (
      tester,
    ) async {
      final board = await _pumpBoard(tester);
      expect(board.controller.joined, hasLength(2));
      await tester.tap(
        find.descendant(of: find.byKey(const ValueKey('id-legal-procurement')), matching: find.text('Preview Chapter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join Council'));
      await tester.pumpAndSettle();
      expect(find.text('Joined'), findsOneWidget);
      expect(board.controller.find('id-legal-procurement')!.joined, isTrue);
      expect(board.controller.joined.map((c) => c.id), contains('id-legal-procurement'));
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('3 Active'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('id-legal-procurement')),
          matching: find.text('Open Member Lounge'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a seat given back on the page leaves the rail and puts Join Council back on the card', (tester) async {
      final board = await _pumpBoard(tester);
      expect(board.controller.joined.map((c) => c.id), contains('id-sustainability-esg'));
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('id-sustainability-esg')),
          matching: find.text('Open Member Lounge'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Leave')));
      await tester.pumpAndSettle();
      expect(board.repo.calls, contains('leave:id-sustainability-esg'));
      expect(board.controller.find('id-sustainability-esg')!.joined, isFalse);
      expect(board.controller.joined.map((c) => c.id), isNot(contains('id-sustainability-esg')));
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('1 Active'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('id-sustainability-esg')), matching: find.text('Join Council')),
        findsOneWidget,
      );
    });

    testWidgets('the board keeps what it read of the council (its next date, its category) when the seat moves', (
      tester,
    ) async {
      final board = await _pumpBoard(tester);
      final before = board.controller.find('id-legal-procurement')!;
      board.controller.follow(before.copyWith(membership: CouncilRole.member));
      final after = board.controller.find('id-legal-procurement')!;
      expect(after.joined, isTrue);
      expect(after.memberCount, before.memberCount);
      expect(after.segments, before.segments);
      // The same seat again, and a council the board does not list, change nothing.
      board.controller.follow(after);
      board.controller.follow(_council('unknown', role: CouncilRole.member));
      expect(board.controller.joined.where((c) => c.id == 'id-legal-procurement'), hasLength(1));
      expect(board.controller.find('id-unknown'), isNull);
    });

    test('a source that cannot feed a page has none, and the card then goes to the website', () {
      // The sample, behind a wrapper that is not a page source.
      expect(CouncilsController(DemoCouncilsRepository()).pages, isNotNull);
      expect(CouncilsController(_BoardOnly(DemoCouncilsRepository())).pages, isNull);
    });
  });

  group('/councils/<slug> on the website', () {
    Future<_Opened> pump(WidgetTester tester, String url) async {
      _view(tester);
      final table = TableApi({
        'GET /councils': (_) => _page([_councilRow, _otherRow]),
        'GET /councils/memberships/mine': (_) => <Object>[],
        'GET /councils/cxo-workplace-strategy': (_) => _detailJson,
        'GET /councils/cxo-workplace-strategy/members': (_) => _page([]),
        'GET /events': (_) => _page([_eventRow]),
        'GET /events/rsvps/mine': (_) => <Object>[],
        'GET /councils/cxo-workplace-strategy/announcements': (_) => <Object>[],
        'GET /councils/cxo-workplace-strategy/resources': (_) => <Object>[],
        'GET /notifications/unread-count': (_) => {'unread': 0},
      });
      late BuildContext context;
      await tester.pumpWidget(
        Provider<ApiClient>.value(
          value: table.client(),
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Builder(
              builder: (c) {
                context = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final open = inAppSiteRoute(
        Uri.parse(url),
        viewer: const FeedAuthor(id: 'u1', name: 'Bharat Buyer'),
      );
      expect(open, isNotNull, reason: url);
      unawaited(open!(context));
      await tester.pumpAndSettle();
      return _Opened(table);
    }

    testWidgets('opens the council\'s own page in the app, read by its slug', (tester) async {
      final opened = await pump(tester, 'https://icr.org.in/councils/cxo-workplace-strategy');
      expect(find.byType(CouncilScreen), findsOneWidget);
      expect(tester.widget<CouncilScreen>(find.byType(CouncilScreen)).tab, isNull);
      expect(find.text('CXO Workplace Strategy'), findsWidgets);
      expect(opened.table.calls, contains('GET /councils/cxo-workplace-strategy'));
      expect(opened.table.queryOf('GET /events')['councilSlug'], 'cxo-workplace-strategy');
    });

    testWidgets('?tab= opens it on that section', (tester) async {
      await pump(tester, 'https://icr.org.in/councils/cxo-workplace-strategy?tab=leadership');
      expect(tester.widget<CouncilScreen>(find.byType(CouncilScreen)).tab, 'leadership');
    });

    testWidgets('an id works too, as a notification names one', (tester) async {
      final opened = await pump(tester, 'https://icr.org.in/councils/k1');
      expect(find.byType(CouncilScreen), findsOneWidget);
      expect(
        opened.table.calls,
        containsAllInOrder(['GET /councils/k1', 'GET /councils', 'GET /councils/cxo-workplace-strategy']),
      );
    });
  });

  group('the sample source', () {
    test('every council on the board has a page: leads, a roster, sessions, dispatches and files', () async {
      final repo = DemoCouncilsRepository();
      final overview = await repo.overview();
      for (final c in overview.councils) {
        final detail = await repo.detail(c.slug);
        expect(detail.council.id, c.id);
        expect(detail.leads, isNotEmpty);
        expect(detail.about, isNotEmpty);
        expect(detail.stats.memberCount, c.memberCount);
        expect((await repo.events(c.slug)), isNotEmpty, reason: c.name);
        expect((await repo.events(c.slug, past: true)), isNotEmpty);
        expect((await repo.updates(c.slug)).first.pinned, isTrue);
        expect((await repo.resources(c.slug)), hasLength(3));
      }
      // An id reads the same page, and an unknown council is a 404.
      expect((await repo.detail('demo-cxo')).council.slug, 'cxo-workplace-strategy');
      await expectLater(repo.detail('nope'), throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 404)));
    });

    test('the chair leads first; the roster pages and filters like the API\'s', () async {
      final repo = DemoCouncilsRepository();
      final detail = await repo.detail('cxo-workplace-strategy');
      expect(detail.leads.first.name, 'Rajesh Sharma');
      expect(detail.leads.first.title, 'Chair');
      expect(detail.leads.first.company, 'Infosys');
      final first = await repo.members('cxo-workplace-strategy');
      expect(first.members, hasLength(6));
      expect(first.hasNext, isTrue);
      final second = await repo.members('cxo-workplace-strategy', page: 2);
      expect(second.hasNext, isFalse);
      expect(first.total, second.total);
      final committee = await repo.members('cxo-workplace-strategy', filter: MemberFilter.committee);
      expect(committee.members.every((p) => p.role == ChapterRole.lead), isTrue);
      final corporate = await repo.members('cxo-workplace-strategy', filter: MemberFilter.corporate);
      expect(corporate.members.every((p) => p.company != null), isTrue);
      final found = await repo.members('cxo-workplace-strategy', search: 'sarah');
      expect(found.members.single.name, 'Sarah Jenkins');
    });

    test('a join and a leave are kept, and the page reads the seat', () async {
      final repo = DemoCouncilsRepository();
      expect((await repo.detail('legal-compliance-procurement')).council.joined, isFalse);
      final legal = (await repo.overview()).councils.firstWhere((c) => c.slug == 'legal-compliance-procurement');
      await repo.join(legal);
      expect((await repo.detail('legal-compliance-procurement')).council.joined, isTrue);
      await repo.leave(legal);
      expect((await repo.detail('legal-compliance-procurement')).council.joined, isFalse);
      expect((await repo.detail('cxo-workplace-strategy')).council.membership, CouncilRole.lead);
    });
  });
}

class _Opened {
  _Opened(this.table);

  final TableApi table;
}

/// A board source that is not also a page source (a test double, as the board's own tests use).
class _BoardOnly implements CouncilsRepository {
  _BoardOnly(this.inner);

  final CouncilsRepository inner;

  @override
  Future<CouncilsOverview> overview() => inner.overview();
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
