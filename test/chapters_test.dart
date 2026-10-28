import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/config.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/chapters/api_chapters_repository.dart';
import 'package:icr_mobile/features/chapters/chapter_controller.dart';
import 'package:icr_mobile/features/chapters/chapter_format.dart';
import 'package:icr_mobile/features/chapters/chapter_models.dart';
import 'package:icr_mobile/features/chapters/chapter_screen.dart';
import 'package:icr_mobile/features/chapters/chapters_controller.dart';
import 'package:icr_mobile/features/chapters/chapters_screen.dart';
import 'package:icr_mobile/features/chapters/community_kit.dart';
import 'package:icr_mobile/features/chapters/demo_chapters_repository.dart';
import 'package:icr_mobile/features/chapters/widgets/chapter_card.dart';
import 'package:icr_mobile/features/chapters/widgets/chapter_preview_sheet.dart';
import 'package:icr_mobile/features/chapters/widgets/chapter_sections.dart';
import 'package:icr_mobile/features/chapters/widgets/meetup_row.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import 'helpers/community_fakes.dart';
import 'helpers/fonts.dart';

// The API's rows, as `GET /chapters`, `/chapters/:slug` and `/events` give them.

const _chapterRow = {
  'id': 'c1',
  'name': 'ICR Bengaluru Chapter',
  'slug': 'bengaluru',
  'city': 'Bengaluru',
  'country': 'India',
  'region': 'Karnataka',
  'description': 'India’s tech-campus capital.',
  'coverUrl': '/uploads/blr.jpg',
  'createdAt': '2026-10-23T02:54:32.433Z',
  'memberCount': 9,
  'upcomingEventCount': 2,
};

const _otherRow = {
  'id': 'c2',
  'name': 'ICR Hong Kong Chapter',
  'slug': 'hong-kong',
  'city': 'Hong Kong',
  'country': 'Hong Kong',
  'region': null,
  'description': null,
  'coverUrl': null,
  'createdAt': '2025-01-01T00:00:00.000Z',
  'memberCount': 3,
  'upcomingEventCount': 0,
};

const _eventRow = {
  'id': 'e1',
  'title': 'Chapter Meetup — Campus FM at GCC scale',
  'slug': 'blr-meetup',
  'kind': 'CHAPTER_MEET',
  'description': '<p>Site talk + networking.</p>',
  'location': 'Koramangala, Bengaluru',
  'coverUrl': null,
  'capacity': 60,
  'priceAmount': null,
  'priceCurrency': 'INR',
  'startsAt': '2026-11-01T05:30:00.000Z',
  'endsAt': '2026-11-01T08:30:00.000Z',
  'attendeeCount': 12,
  'chapter': {'id': 'c1', 'name': 'ICR Bengaluru Chapter', 'slug': 'bengaluru'},
  'council': null,
  'inviteOnly': false,
  'callForSpeakersUntil': null,
};

const _councilEventRow = {
  'id': 'e2',
  'title': 'A council roundtable',
  'slug': 'rt',
  'kind': 'ROUNDTABLE',
  'startsAt': '2026-11-02T05:30:00.000Z',
  'attendeeCount': 0,
  'chapter': null,
  'council': {'id': 'k1', 'name': 'A council', 'slug': 'a-council'},
};

Map<String, dynamic> _page(List<Object> rows, {bool hasNext = false, int? total}) => {
  'data': rows,
  'meta': {
    'page': 1,
    'limit': 100,
    'total': total ?? rows.length,
    'totalPages': 1,
    'hasNext': hasNext,
    'hasPrev': false,
  },
};

const _detailJson = {
  ..._chapterRow,
  'contactEmail': 'blr@icr.test',
  'foundedYear': 2014,
  'aboutHtml':
      '<h3>Mission</h3>\n<p>To connect &amp; elevate the community.</p>\n<h3>What we do</h3>\n<ul>\n<li>Monthly meetups</li>\n<li>Site visits</li>\n</ul>',
  'galleryUrls': ['https://picsum.photos/seed/icr-bengaluru-1/800/600'],
  'stats': {
    'memberCount': 9,
    'leadershipCount': 3,
    'upcomingEventCount': 2,
    'pastEventCount': 0,
    'memberCompanyCount': 3,
  },
  'sponsors': [
    {'id': 's1', 'name': 'CBRE', 'logoUrl': null, 'url': 'https://example.com', 'tier': 'Gold'},
  ],
  'leads': [
    {
      'id': 'u1',
      'firstName': 'Super',
      'lastName': 'Admin',
      'avatarUrl': null,
      'title': 'Chapter President',
      'linkedinUrl': 'https://www.linkedin.com/in/super-admin',
      'company': null,
    },
    {
      'id': 'u2',
      'firstName': 'Bharat',
      'lastName': 'Buyer',
      'avatarUrl': '/uploads/me.jpg',
      'title': 'Secretary',
      'linkedinUrl': null,
      'company': {'name': 'TechCorp', 'logoUrl': null},
    },
  ],
  'upcomingEvents': [_eventRow],
};

/// A phone 390 dp wide and [height] dp tall: tall enough that a lazy list builds the whole screen.
void _view(WidgetTester tester, {double height = 3600}) {
  tester.view.physicalSize = Size(780, height * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

class _Board {
  _Board(this.repo) : controller = ChaptersController(repo, clock: () => testNow);

  final FakeChapters repo;
  final ChaptersController controller;
  int backs = 0;

  /// The chapter name each "Volunteer" tap carried (null from the board).
  final volunteers = <String?>[];
  int bells = 0;
  final members = <String>[];
  final messages = <String>[];

  /// The slug (or id) of each event a tap handed to the shell.
  final events = <String>[];
  final opened = <Uri>[];
  final shared = <(String, Uri)>[];

  Future<void> open(BuildContext context, Uri uri) async => opened.add(uri);

  Future<void> share(String title, Uri link) async => shared.add((title, link));
}

Future<_Board> _pumpBoard(
  WidgetTester tester, {
  FakeChapters? repo,
  bool volunteer = true,
  bool ownBell = false,
  double height = 3600,
}) async {
  _view(tester, height: height);
  final board = _Board(repo ?? FakeChapters());
  // A fresh tree, so a second pump in one test starts its screen again.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: ChangeNotifierProvider.value(
        value: board.controller,
        child: ChaptersScreen(
          onBack: () => board.backs++,
          onOpenEvent: board.events.add,
          onOpenVolunteer: volunteer ? board.volunteers.add : null,
          onBell: ownBell ? () => board.bells++ : null,
          onOpenMember: board.members.add,
          onMessage: board.messages.add,
          opener: board.open,
          share: board.share,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return board;
}

/// A chapter's page for [slug], with its calls and taps recorded.
Future<_Board> _pumpPage(
  WidgetTester tester,
  String slug, {
  FakeChapters? repo,
  bool volunteer = true,
  double height = 5200,
}) async {
  _view(tester, height: height);
  final board = _Board(repo ?? FakeChapters());
  // A fresh tree, so a second pump in one test starts its screen again.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: ChangeNotifierProvider(
        create: (_) => ChapterController(
          repository: board.repo,
          idOrSlug: slug,
          onChanged: board.controller.update,
          clock: () => testNow,
        ),
        child: ChapterScreen(
          onBack: () => board.backs++,
          onOpenEvent: board.events.add,
          onOpenVolunteer: volunteer ? board.volunteers.add : null,
          onOpenMember: board.members.add,
          onMessage: board.messages.add,
          opener: board.open,
          share: board.share,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return board;
}

Finder _card(String name) => find.widgetWithText(ChapterCard, name);

void main() {
  setUpAll(loadAppFonts);

  group('formatting', () {
    test('a chapter without a photo gets its slug’s two-tone banner, the same every time', () {
      final (a1, b1) = coverColors('bengaluru');
      final (a2, b2) = coverColors('bengaluru');
      expect((a1, b1), (a2, b2));
      expect(coverColors('mumbai').$1, isNot(a1));
      expect(HSLColor.fromColor(a1).saturation, closeTo(0.55, 0.02));
      expect(HSLColor.fromColor(a1).lightness, closeTo(0.32, 0.02));
      expect(HSLColor.fromColor(b1).lightness, closeTo(0.24, 0.02));
    });

    test('the glyph follows the place, as the website’s placeIconKey', () {
      expect(PlaceKind.of('ICR Mumbai Chapter', 'Mumbai', 'Maharashtra'), PlaceKind.coastal);
      expect(PlaceKind.of('ICR Delhi NCR Chapter', 'Delhi NCR', null), PlaceKind.capital);
      expect(PlaceKind.of('ICR Bengaluru Chapter', 'Bengaluru', 'Karnataka'), PlaceKind.tech);
      expect(PlaceKind.of('ICR Hong Kong Chapter', 'Hong Kong', null), PlaceKind.general);
      expect(placeIcon(PlaceKind.tech), LucideIcons.cpu);
    });

    test('dates read on the Indian clock', () {
      final start = DateTime.utc(2026, 11, 1, 5, 30);
      expect(monthDay(start), 'Nov 01');
      expect(monthCaps(start), 'NOV');
      expect(timeRange(start, DateTime.utc(2026, 11, 1, 8, 30)), '11:00 – 14:00 IST');
      expect(timeRange(start, null), '11:00 IST');
      expect(joinedLabel(DateTime.utc(2026, 3, 31, 20)), 'Joined Apr 2026');
      expect(nextLabel(sampleChapter('x', next: start)), 'Next: Nov 01');
      expect(nextLabel(sampleChapter('x')), isNull);
    });

    test('the About html becomes headings, paragraphs and bullets in order', () {
      final blocks = htmlBlocks(
        '<h3>Mission</h3>\n<p>To connect &amp; elevate\nus.</p>\n<ul><li>Monthly <b>meetups</b></li><li>Visits</li></ul>',
      );
      expect(blocks, const [
        AboutBlock(AboutKind.heading, 'Mission'),
        AboutBlock(AboutKind.paragraph, 'To connect & elevate us.'),
        AboutBlock(AboutKind.bullet, 'Monthly meetups'),
        AboutBlock(AboutKind.bullet, 'Visits'),
      ]);
      expect(htmlBlocks('Just some words'), const [AboutBlock(AboutKind.paragraph, 'Just some words')]);
      expect(htmlBlocks(null), isEmpty);
      expect(htmlBlocks('   '), isEmpty);
    });

    test('numbers and plurals', () {
      expect(plural(1, 'member'), '1 member');
      expect(plural(2530, 'member'), '2,530 members');
      expect(membersLabel(9), '9 members');
      expect(eventsLabel(1), '1 upcoming event');
      expect(allCountriesLabel(3), 'All Countries (3)');
    });
  });

  group('the API mapping', () {
    TableApi api({bool signedIn = true}) => TableApi({
      'GET /chapters': (o) => _page([_chapterRow, _otherRow]),
      'GET /chapters/memberships/mine': (_) => signedIn
          ? [
              {
                'chapterId': 'c1',
                'role': 'LEAD',
                'joinedAt': '2026-10-23T02:54:32.790Z',
                'chapter': {'id': 'c1'},
              },
            ]
          : (401, '{"message":"Unauthorized"}'),
      'GET /events': (o) =>
          o.queryParameters.containsKey('chapterSlug') ? _page([_eventRow]) : _page([_eventRow, _councilEventRow]),
      'GET /events/rsvps/mine': (_) => [
        {'eventId': 'e1', 'status': 'GOING'},
      ],
      'GET /chapters/bengaluru': (_) => _detailJson,
      'GET /chapters/bengaluru/members': (_) => {
        'data': [
          {
            'id': 'u1',
            'firstName': 'Bharat',
            'lastName': 'Buyer',
            'avatarUrl': '/uploads/me.jpg',
            'role': 'LEAD',
            'title': 'Secretary',
            'company': {'name': 'TechCorp', 'logoUrl': null},
            'joinedAt': '2026-10-23T02:54:32.630Z',
          },
        ],
        'meta': {'page': 2, 'limit': 12, 'total': 13, 'totalPages': 2, 'hasNext': false},
      },
      'GET /chapters/bengaluru/announcements': (_) => [
        {'id': 'a1', 'title': 'Older', 'body': 'b', 'pinned': false, 'createdAt': '2026-10-02T00:00:00.000Z'},
        {'id': 'a2', 'title': 'Pinned', 'body': 'b', 'pinned': true, 'createdAt': '2026-10-01T00:00:00.000Z'},
        {'id': 'a3', 'title': 'Newer', 'body': 'b', 'pinned': false, 'createdAt': '2026-10-05T00:00:00.000Z'},
      ],
      'GET /chapters/bengaluru/resources': (_) => [
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
      'POST /chapters/c2/join': (_) => {'status': 'MEMBER'},
      'DELETE /chapters/c1/join': (_) => {'status': 'NONE'},
      'GET /notifications/unread-count': (_) => {'unread': 4},
    });

    test('the board is every chapter with the member’s place and the next date of each chapter’s meetup', () async {
      final table = api();
      final overview = await ApiChaptersRepository(api: table.client()).overview();
      expect(overview.chapters.map((c) => c.slug), ['bengaluru', 'hong-kong']);
      final blr = overview.chapters.first;
      expect(blr.role, ChapterRole.lead);
      expect(blr.joined, isTrue);
      expect(blr.memberCount, 9);
      expect(blr.upcomingEventCount, 2);
      expect(blr.place, 'Bengaluru · Karnataka · India');
      expect(blr.cover!.url, 'http://api.test/uploads/blr.jpg');
      expect(blr.nextEventAt, DateTime.utc(2026, 11, 1, 5, 30));
      expect(overview.chapters.last.joined, isFalse);
      expect(overview.chapters.last.place, 'Hong Kong');
      expect(overview.chapters.last.cover, isNull);
      // Only events a chapter hosts are meetups; a council's roundtable is not.
      expect(overview.meetups.map((e) => e.id), ['e1']);
      expect(overview.stats.chapters, 2);
      expect(overview.stats.members, 12);
      expect(overview.stats.countries, 2);
      expect(overview.stats.upcomingEvents, 2);
      expect(table.queryOf('GET /chapters')['limit'], 100);
      expect(table.queryOf('GET /events')['when'], 'upcoming');
    });

    test('signed out, the board still reads and nothing is joined', () async {
      final overview = await ApiChaptersRepository(api: api(signedIn: false).client()).overview();
      expect(overview.chapters.every((c) => !c.joined), isTrue);
    });

    test('a chapter’s page: about, gallery, numbers, sponsors, committee and the next events with the RSVP', () async {
      final detail = await ApiChaptersRepository(api: api().client()).detail('bengaluru');
      expect(detail.chapter.role, ChapterRole.lead);
      expect(detail.contactEmail, 'blr@icr.test');
      expect(detail.foundedYear, 2014);
      expect(detail.about, const [
        AboutBlock(AboutKind.heading, 'Mission'),
        AboutBlock(AboutKind.paragraph, 'To connect & elevate the community.'),
        AboutBlock(AboutKind.heading, 'What we do'),
        AboutBlock(AboutKind.bullet, 'Monthly meetups'),
        AboutBlock(AboutKind.bullet, 'Site visits'),
      ]);
      expect(detail.gallery.single.url, 'https://picsum.photos/seed/icr-bengaluru-1/800/600');
      expect(detail.stats.memberCount, 9);
      expect(detail.stats.leadershipCount, 3);
      expect(detail.stats.memberCompanyCount, 3);
      expect(detail.sponsors.single.name, 'CBRE');
      expect(detail.sponsors.single.tier, 'Gold');
      expect(detail.leads.map((p) => p.name), ['Super Admin', 'Bharat Buyer']);
      expect(detail.leads.last.company, 'TechCorp');
      expect(detail.leads.last.photo!.url, 'http://api.test/uploads/me.jpg');
      expect(detail.leads.first.linkedinUrl, 'https://www.linkedin.com/in/super-admin');
      expect(detail.upcomingEvents.single.myStatus, 'GOING');
      expect(detail.upcomingEvents.single.description, 'Site talk + networking.');
      expect(detail.upcomingEvents.single.endsAt, DateTime.utc(2026, 11, 1, 8, 30));
    });

    test('an id is looked up on the board first, since the API reads chapters by slug', () async {
      final table = api();
      table.routes['GET /chapters/c1'] = (_) => (404, '{"message":"Chapter not found"}');
      final detail = await ApiChaptersRepository(api: table.client()).detail('c1');
      expect(detail.chapter.slug, 'bengaluru');
      expect(table.calls, containsAllInOrder(['GET /chapters/c1', 'GET /chapters', 'GET /chapters/bengaluru']));
    });

    test('a slug the API does not know is the API’s own refusal', () async {
      final table = api();
      table.routes['GET /chapters/nope'] = (_) => (404, '{"message":"Chapter not found"}');
      await expectLater(
        ApiChaptersRepository(api: table.client()).detail('nope'),
        throwsA(isA<ApiError>().having((e) => e.message, 'message', 'Chapter not found')),
      );
    });

    test('the roster sends the filter as the API names it, and a page at a time', () async {
      final table = api();
      final repo = ApiChaptersRepository(api: table.client());
      await repo.members('bengaluru');
      expect(table.queryOf('GET /chapters/bengaluru/members'), {'page': 1, 'limit': 12});
      final page = await repo.members('bengaluru', page: 2, search: ' bharat ', filter: MemberFilter.committee);
      expect(table.queryOf('GET /chapters/bengaluru/members'), {
        'page': 2,
        'limit': 12,
        'search': 'bharat',
        'role': 'LEAD',
      });
      expect(page.total, 13);
      expect(page.hasNext, isFalse);
      expect(page.members.single.role, ChapterRole.lead);
      await repo.members('bengaluru', filter: MemberFilter.corporate);
      expect(table.queryOf('GET /chapters/bengaluru/members')['hasCompany'], 'true');
    });

    test('a chapter’s events are read as upcoming or past, with the RSVP on each', () async {
      final table = api();
      final repo = ApiChaptersRepository(api: table.client());
      final up = await repo.events('bengaluru');
      expect(table.queryOf('GET /events'), {'chapterSlug': 'bengaluru', 'when': 'upcoming', 'limit': 12});
      expect(up.single.myStatus, 'GOING');
      await repo.events('bengaluru', past: true);
      expect(table.queryOf('GET /events')['when'], 'past');
    });

    test('dispatches are pinned first and then newest; resources get absolute links and tags', () async {
      final repo = ApiChaptersRepository(api: api().client());
      final updates = await repo.updates('bengaluru');
      expect(updates.map((u) => u.title), ['Pinned', 'Newer', 'Older']);
      final resources = await repo.resources('bengaluru');
      expect(resources.map((r) => r.tag), ['PPTX', 'MP4']);
      expect(resources.first.url, 'http://api.test/uploads/deck.pdf');
      expect(resources.last.url, 'https://example.com/rec');
      expect(resources.first.kindLabel, 'Presentation');
      expect(resources.first.sizeLabel, '5 MB');
    });

    test('join and leave are the two calls the website makes, and the bell is the unread count', () async {
      final table = api();
      final repo = ApiChaptersRepository(api: table.client());
      final other = (await repo.overview()).chapters.last;
      expect(await repo.join(other), ChapterRole.member);
      expect(table.calls, contains('POST /chapters/c2/join'));
      await repo.leave((await repo.overview()).chapters.first);
      expect(table.calls, contains('DELETE /chapters/c1/join'));
      expect(await repo.unreadNotifications(), 4);
      expect(repo.link(other), AppConfig.sitePage('/chapters/hong-kong'));
    });

    test('other chapters in the same country leave the open one out', () async {
      final table = api();
      table.routes['GET /chapters'] = (o) => _page([_chapterRow, _otherRow]);
      final repo = ApiChaptersRepository(api: table.client());
      final blr = (await repo.overview()).chapters.first;
      final near = await repo.nearby(blr);
      expect(table.queryOf('GET /chapters')['country'], 'India');
      expect(near.map((c) => c.slug), ['hong-kong']);
    });
  });

  group('the board’s controller', () {
    Future<ChaptersController> started([FakeChapters? repo]) async {
      final c = ChaptersController(repo ?? FakeChapters(), clock: () => testNow);
      await c.start();
      return c;
    }

    test('the numbers are read from the chapters', () async {
      final c = await started();
      expect(c.stats!.chapters, 5);
      expect(c.stats!.members, 128 + 96 + 2 + 2 + 9);
      expect(c.stats!.countries, 3);
      expect(c.stats!.upcomingEvents, 4);
      expect(c.countries, ['India', 'Singapore', 'USA']);
    });

    test('my chapters list a lead first, then by name', () async {
      final c = await started();
      expect(c.joined.map((x) => x.slug), ['bengaluru', 'pune']);
    });

    test('Recommended puts the chapters near my own first, then the busiest', () async {
      final c = await started();
      // I belong to Karnataka (Bengaluru) and Maharashtra (Pune); Mumbai shares a region with Pune.
      final order = c.chapters.map((x) => x.slug).toList();
      expect(order.indexOf('mumbai'), lessThan(order.indexOf('new-york')));
      expect(order.indexOf('mumbai'), lessThan(order.indexOf('singapore')));
    });

    test('search, country, size and activity narrow the directory, and each can be taken off', () async {
      final c = await started();
      c.setSearch('mumbai');
      expect(c.chapters.map((x) => x.slug), ['mumbai']);
      c.setSearch('  ');
      expect(c.chapters, hasLength(5));
      c.setSearch('india');
      expect(c.chapters, hasLength(3));
      c.setSearch('');
      c.setCountry('Singapore');
      expect(c.chapters.map((x) => x.slug), ['singapore']);
      c.setCountry(null);
      c.setFilters(size: ChapterSize.large);
      expect(c.chapters.map((x) => x.slug).toSet(), {'bengaluru', 'mumbai'});
      expect(c.filtered, isTrue);
      c.setFilters(size: ChapterSize.small);
      expect(c.chapters.map((x) => x.slug).toSet(), {'pune', 'singapore'});
      c.setFilters(size: ChapterSize.any, activity: ChapterActivity.events);
      expect(c.chapters.map((x) => x.slug).toSet(), {'bengaluru', 'mumbai'});
      c.setFilters(activity: ChapterActivity.fresh);
      expect(c.chapters.map((x) => x.slug), ['pune']);
      c.clearFilters();
      expect(c.chapters, hasLength(5));
      expect(c.narrowed, isFalse);
    });

    test('the other sorts are the website’s', () async {
      final c = await started();
      c.setFilters(sort: ChapterSort.members);
      expect(c.chapters.first.slug, 'bengaluru');
      c.setFilters(sort: ChapterSort.az);
      expect(c.chapters.map((x) => x.name), [
        'ICR Bengaluru Chapter',
        'ICR Mumbai Chapter',
        'ICR New-york Chapter',
        'ICR Pune Chapter',
        'ICR Singapore Chapter',
      ]);
      c.setFilters(sort: ChapterSort.active);
      expect(c.chapters.first.slug, 'bengaluru');
      c.setFilters(sort: ChapterSort.newest);
      expect(c.chapters.first.slug, 'pune');
    });

    test(
      'a join shows at once, keeps what the API answers, and gives the place back with the API’s words on a refusal',
      () async {
        final repo = FakeChapters();
        final c = await started(repo);
        final mumbai = c.find('id-mumbai')!;
        final pending = c.join(mumbai);
        expect(c.find('id-mumbai')!.joined, isTrue);
        expect(c.find('id-mumbai')!.memberCount, 97);
        expect(c.isBusy(mumbai), isTrue);
        expect(await pending, isNull);
        expect(c.isBusy(mumbai), isFalse);
        expect(c.joined.map((x) => x.slug), contains('mumbai'));

        repo.failures['join'] = ApiError('Sign in to join a chapter.', statusCode: 401);
        final singapore = c.find('id-singapore')!;
        expect(await c.join(singapore), 'Sign in to join a chapter.');
        expect(c.find('id-singapore')!.joined, isFalse);
        expect(c.find('id-singapore')!.memberCount, 2);
      },
    );

    test('leaving takes the place back at once and puts it back when the API refuses', () async {
      final repo = FakeChapters();
      final c = await started(repo);
      final pune = c.find('id-pune')!;
      expect(await c.leave(pune), isNull);
      expect(c.find('id-pune')!.joined, isFalse);
      expect(c.find('id-pune')!.memberCount, 1);

      repo.failures['leave'] = ApiError('Try later', statusCode: 500);
      final blr = c.find('id-bengaluru')!;
      expect(await c.leave(blr), 'Try later');
      expect(c.find('id-bengaluru')!.role, ChapterRole.lead);
      expect(c.find('id-bengaluru')!.memberCount, 128);
    });

    test('a join or leave already under way is not sent twice', () async {
      final repo = FakeChapters();
      final c = await started(repo);
      final mumbai = c.find('id-mumbai')!;
      final first = c.join(mumbai);
      expect(await c.join(mumbai), isNull);
      await first;
      expect(repo.count('join'), 1);
    });

    test('a failed read keeps the error until a refresh reads again', () async {
      final repo = FakeChapters()..failures['overview'] = ApiError('Boom', statusCode: 500);
      final c = await started(repo);
      expect(c.overview, isNull);
      expect(c.error, 'Boom');
      repo.failures.clear();
      await c.refresh();
      expect(c.error, isNull);
      expect(c.chapters, hasLength(5));
    });

    test('a refresh reads the chapters and the bell again', () async {
      final repo = FakeChapters(unread: 2);
      final c = await started(repo);
      expect(c.unread, 2);
      repo.unread = 5;
      await c.refresh();
      expect(c.unread, 5);
      expect(repo.count('overview'), 2);
    });
  });

  group('the Regional Chapters screen', () {
    testWidgets('draws the numbers, my chapters, the next meetup and the directory', (tester) async {
      await _pumpBoard(tester);
      expect(find.text('Regional Chapters'), findsOneWidget);
      for (final label in ['Chapters', 'Members', 'Countries', 'Upcoming events']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('237'), findsOneWidget);
      expect(find.text('Your Chapters'), findsOneWidget);
      expect(find.text('2 Joined'), findsOneWidget);
      expect(find.text('Upcoming Meetups'), findsOneWidget);
      expect(find.byType(MeetupRow), findsOneWidget);
      expect(find.text('Campus FM at GCC scale'), findsOneWidget);
      expect(find.byType(ChapterCard), findsNWidgets(5));
      expect(find.text('All Countries (3)'), findsOneWidget);
      expect(find.text('5 chapters'), findsOneWidget);
      expect(find.text('Join Chapter'), findsNWidgets(3));
      expect(find.text('Open Chapter'), findsNWidgets(2));
    });

    testWidgets('Back and the bell', (tester) async {
      final board = await _pumpBoard(tester);
      await tester.tap(find.byIcon(Symbols.arrow_back));
      expect(board.backs, 1);
      await tester.tap(find.byIcon(LucideIcons.bell));
      expect(board.opened.last, AppConfig.sitePage('/notifications'));

      final own = await _pumpBoard(tester, ownBell: true);
      await tester.tap(find.byIcon(LucideIcons.bell));
      expect(own.bells, 1);
      expect(own.opened, isEmpty);
    });

    testWidgets('the bell wears its dot while there is something unread', (tester) async {
      await _pumpBoard(tester, repo: FakeChapters(unread: 3));
      expect(find.bySemanticsLabel('Notifications, 3 unread'), findsOneWidget);
    });

    testWidgets('a meetup opens through the callback the shell wires, by the event slug', (tester) async {
      final board = await _pumpBoard(tester);
      await tester.tap(find.text('Campus FM at GCC scale'));
      expect(board.events.single, 'e1-slug');
    });

    testWidgets(
      'the search narrows the cards as it is typed, says when nothing matches, and Clear filters brings them back',
      (tester) async {
        await _pumpBoard(tester);
        await tester.enterText(find.byType(TextField), 'mumbai');
        await tester.pumpAndSettle();
        expect(find.byType(ChapterCard), findsOneWidget);
        expect(find.text('1 chapter of 5'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'zzz');
        await tester.pumpAndSettle();
        expect(find.byType(ChapterCard), findsNothing);
        expect(find.text('No chapters match'), findsOneWidget);
        await tester.tap(find.text('Clear filters').last);
        await tester.pumpAndSettle();
        expect(find.byType(ChapterCard), findsNWidgets(5));
        expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
      },
    );

    testWidgets('a country chip narrows to that country; again, or All Countries, widens', (tester) async {
      await _pumpBoard(tester);
      await tester.tap(find.text('India').first);
      await tester.pumpAndSettle();
      expect(find.byType(ChapterCard), findsNWidgets(3));
      await tester.tap(find.text('India').first);
      await tester.pumpAndSettle();
      expect(find.byType(ChapterCard), findsNWidgets(5));
      await tester.tap(find.text('USA'));
      await tester.pumpAndSettle();
      expect(find.byType(ChapterCard), findsOneWidget);
      await tester.tap(find.text('All Countries (3)'));
      await tester.pumpAndSettle();
      expect(find.byType(ChapterCard), findsNWidgets(5));
    });

    testWidgets('the sliders glyph opens the sort and filters, and each choice acts', (tester) async {
      final board = await _pumpBoard(tester);
      await tester.tap(find.bySemanticsLabel('Sort and filter chapters'));
      await tester.pumpAndSettle();
      expect(find.text('Sort and filter'), findsOneWidget);
      for (final label in ['Recommended', 'Most members', 'Most active', 'Newest', 'A to Z']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('A to Z'));
      await tester.pumpAndSettle();
      expect(board.controller.sort, ChapterSort.az);
      await tester.tap(find.text('10+ members'));
      await tester.pumpAndSettle();
      expect(board.controller.size, ChapterSize.large);
      await tester.tap(find.text('Has upcoming events'));
      await tester.pumpAndSettle();
      expect(board.controller.activity, ChapterActivity.events);
      await tester.tap(find.text('Show chapters'));
      await tester.pumpAndSettle();
      expect(find.byType(ChapterCard), findsNWidgets(2));
      expect(tester.widget<ChapterCard>(find.byType(ChapterCard).first).chapter.slug, 'bengaluru');

      await tester.tap(find.bySemanticsLabel('Sort and filter chapters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(board.controller.sort, ChapterSort.recommended);
      expect(board.controller.filtered, isFalse);
      expect(find.byType(ChapterCard), findsNWidgets(5));
    });

    testWidgets('Join Chapter takes the place at once and keeps it', (tester) async {
      final board = await _pumpBoard(tester);
      expect(find.descendant(of: _card('ICR Mumbai Chapter'), matching: find.text('Join Chapter')), findsOneWidget);
      await tester.tap(find.descendant(of: _card('ICR Mumbai Chapter'), matching: find.text('Join Chapter')));
      await tester.pumpAndSettle();
      expect(board.repo.calls, contains('join:id-mumbai'));
      expect(find.descendant(of: _card('ICR Mumbai Chapter'), matching: find.text('Open Chapter')), findsOneWidget);
      expect(find.descendant(of: _card('ICR Mumbai Chapter'), matching: find.text('97 members')), findsOneWidget);
      expect(find.text('3 Joined'), findsOneWidget);
    });

    testWidgets('a refused join puts the card back and says why', (tester) async {
      final repo = FakeChapters()..failures['join'] = ApiError('Sign in to join a chapter.', statusCode: 401);
      await _pumpBoard(tester, repo: repo);
      await tester.tap(find.descendant(of: _card('ICR Mumbai Chapter'), matching: find.text('Join Chapter')));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to join a chapter.'), findsOneWidget);
      expect(find.descendant(of: _card('ICR Mumbai Chapter'), matching: find.text('Join Chapter')), findsOneWidget);
      expect(find.text('2 Joined'), findsOneWidget);
    });

    testWidgets('Leave asks first; Cancel keeps the place and Leave gives it up', (tester) async {
      final board = await _pumpBoard(tester);
      await tester.tap(find.descendant(of: _card('ICR Pune Chapter'), matching: find.text('Leave')));
      await tester.pumpAndSettle();
      expect(find.text('Leave ICR Pune Chapter?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(board.repo.count('leave'), 0);
      expect(find.text('2 Joined'), findsOneWidget);

      await tester.tap(find.descendant(of: _card('ICR Pune Chapter'), matching: find.text('Leave')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Leave')));
      await tester.pumpAndSettle();
      expect(board.repo.calls, contains('leave:id-pune'));
      expect(find.text('1 Joined'), findsOneWidget);
      expect(find.descendant(of: _card('ICR Pune Chapter'), matching: find.text('Join Chapter')), findsOneWidget);
    });

    testWidgets('a card opens the chapter’s page', (tester) async {
      final board = await _pumpBoard(tester);
      await tester.tap(find.text('ICR Mumbai Chapter').first);
      await tester.pumpAndSettle();
      expect(board.repo.calls, contains('detail:mumbai'));
      expect(find.byType(ChapterScreen), findsOneWidget);
      expect(find.text('Join Chapter'), findsWidgets);
    });

    testWidgets('a place the member takes on a chapter’s page shows on the board behind it', (tester) async {
      final board = await _pumpBoard(tester);
      await tester.tap(find.text('ICR Mumbai Chapter').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join Chapter').first);
      await tester.pumpAndSettle();
      expect(find.text('Joined'), findsOneWidget);
      expect(board.controller.find('id-mumbai')!.joined, isTrue);
      expect(board.controller.find('id-mumbai')!.memberCount, 97);
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('3 Joined'), findsOneWidget);
    });

    testWidgets('the card for a chapter I belong to opens from the rail too', (tester) async {
      final board = await _pumpBoard(tester);
      await tester.tap(find.text('Open chapter').first);
      await tester.pumpAndSettle();
      expect(board.repo.calls, contains('detail:bengaluru'));
    });

    testWidgets('the "Get involved" card is the shell’s callback, and is left out without one', (tester) async {
      final board = await _pumpBoard(tester);
      await tester.tap(find.text('Get involved'));
      expect(board.volunteers, [null]);
      await _pumpBoard(tester, volunteer: false);
      expect(find.text('Get involved'), findsNothing);
    });

    testWidgets('with no chapter joined it says so, and with no meetups it says that', (tester) async {
      final repo = FakeChapters(chapters: [sampleChapter('mumbai', city: 'Mumbai')])..meetups = [];
      await _pumpBoard(tester, repo: repo);
      expect(find.textContaining("You haven't joined a chapter yet"), findsOneWidget);
      expect(find.textContaining('No chapter meetups are scheduled yet'), findsOneWidget);
    });

    testWidgets('an empty directory says so', (tester) async {
      final repo = FakeChapters(chapters: const [])..meetups = [];
      await _pumpBoard(tester, repo: repo);
      expect(find.text('No chapters yet'), findsOneWidget);
    });

    testWidgets('loading shows a spinner; a failed read offers Try again, which reads again', (tester) async {
      final repo = FakeChapters()..failures['overview'] = ApiError('Server down', statusCode: 500);
      await _pumpBoard(tester, repo: repo);
      expect(find.text("Couldn't load chapters"), findsOneWidget);
      expect(find.text('Server down'), findsOneWidget);
      repo.failures.clear();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(ChapterCard), findsNWidgets(5));
      expect(repo.count('overview'), 2);
    });

    testWidgets('while the first read is on its way there is a spinner and nothing else', (tester) async {
      _view(tester);
      final repo = FakeChapters();
      final gate = Completer<void>();
      repo.gate = gate.future;
      final controller = ChaptersController(repo);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ChangeNotifierProvider.value(
            value: controller,
            child: ChaptersScreen(onBack: () {}, onOpenEvent: (_) {}),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(ChapterCard), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ChapterCard), findsNWidgets(5));
    });

    testWidgets('pulling down reads the chapters again, the bell with them', (tester) async {
      // A phone-sized frame: the indicator arms after a fraction of the list's height.
      final board = await _pumpBoard(tester, height: 800);
      expect(board.repo.count('overview'), 1);
      board.repo.unread = 2;
      await tester.fling(find.byType(ListView).first, const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(board.repo.count('overview'), 2);
      expect(board.controller.unread, 2);
    });
  });

  group('a chapter’s page', () {
    testWidgets('draws the identity, the numbers and the sections from the API', (tester) async {
      await _pumpPage(tester, 'bengaluru');
      expect(find.text('ICR Bengaluru Chapter'), findsWidgets);
      expect(find.text('Karnataka'), findsOneWidget);
      expect(find.text('Est. 2014'), findsOneWidget);
      expect(find.text('Chapter lead'), findsOneWidget);
      expect(find.text('Active members'), findsOneWidget);
      expect(find.text('1 on committee'), findsOneWidget);
      expect(find.text('Member companies'), findsOneWidget);
      expect(find.text('Hosted sessions'), findsOneWidget);
      expect(find.text('since 2014'), findsOneWidget);
      for (final section in [
        'About',
        'Leadership',
        'Events & meetups',
        'Updates',
        'Resources',
        'Members',
        'Sponsors',
      ]) {
        expect(find.text(section), findsWidgets, reason: section);
      }
      expect(find.text('Mission'), findsOneWidget);
      expect(find.text('Connect the community.'), findsOneWidget);
      expect(find.text('Monthly meetups'), findsOneWidget);
      expect(find.text('Vikram Malhotra'), findsOneWidget);
      expect(find.text('Chapter President · DLF'), findsOneWidget);
      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('PINNED'), findsOneWidget);
      expect(find.text('Benchmark 2026'), findsOneWidget);
      expect(find.text('CBRE'), findsOneWidget);
      expect(find.text('Other chapters in India'), findsOneWidget);
    });

    testWidgets('Back goes back, and an unknown chapter says so with Try again', (tester) async {
      final board = await _pumpPage(tester, 'bengaluru');
      await tester.tap(find.byIcon(Symbols.arrow_back));
      expect(board.backs, 1);

      await _pumpPage(tester, 'nowhere');
      expect(find.text("Couldn't load this chapter"), findsOneWidget);
      expect(find.text('Chapter not found'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('Join Chapter takes the place; Leave asks, then gives it back', (tester) async {
      final board = await _pumpPage(tester, 'mumbai');
      expect(find.text('Join Chapter'), findsOneWidget);
      await tester.tap(find.text('Join Chapter'));
      await tester.pumpAndSettle();
      expect(board.repo.calls, contains('join:id-mumbai'));
      expect(find.text('Joined'), findsOneWidget);
      expect(find.text('97'), findsWidgets);

      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(find.text('Leave ICR Mumbai Chapter?'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Leave')));
      await tester.pumpAndSettle();
      expect(board.repo.calls, contains('leave:id-mumbai'));
      expect(find.text('Join Chapter'), findsOneWidget);
    });

    testWidgets('a refused join says why and leaves the page as it was', (tester) async {
      final repo = FakeChapters()..failures['join'] = ApiError('Chapter is full.', statusCode: 400);
      await _pumpPage(tester, 'mumbai', repo: repo);
      await tester.tap(find.text('Join Chapter'));
      await tester.pumpAndSettle();
      expect(find.text('Chapter is full.'), findsOneWidget);
      expect(find.text('Join Chapter'), findsOneWidget);
      expect(find.text('96'), findsWidgets);
    });

    testWidgets('Share hands the chapter and its link to the share sheet; Email opens the mail app', (tester) async {
      final board = await _pumpPage(tester, 'bengaluru');
      await tester.tap(find.bySemanticsLabel('Share chapter'));
      expect(board.shared.single.$1, 'ICR Bengaluru Chapter');
      expect(board.shared.single.$2, Uri.parse('https://icr.test/chapters/bengaluru'));
      await tester.tap(find.bySemanticsLabel('Email the chapter'));
      expect(board.opened.single, Uri(scheme: 'mailto', path: 'blr@icr.test'));
      await _pumpPage(tester, 'mumbai');
      expect(find.bySemanticsLabel('Email the chapter'), findsNothing);
    });

    testWidgets('the committee’s link, a resource and a sponsor open where they point', (tester) async {
      final board = await _pumpPage(tester, 'bengaluru');
      await tester.tap(find.byTooltip('LinkedIn profile of Vikram Malhotra'));
      await tester.tap(find.text('Benchmark 2026'));
      await tester.tap(find.text('CBRE'));
      expect(board.opened, [
        Uri.parse('https://www.linkedin.com/in/vm'),
        Uri.parse('https://files.test/b.pdf'),
        Uri.parse('https://cbre.test'),
      ]);
    });

    testWidgets('Volunteer with this chapter is the shell’s callback and is left out without one', (tester) async {
      final board = await _pumpPage(tester, 'bengaluru');
      await tester.tap(find.text('Volunteer with this chapter'));
      expect(board.volunteers, ['ICR Bengaluru Chapter']);
      await _pumpPage(tester, 'bengaluru', volunteer: false);
      expect(find.text('Volunteer with this chapter'), findsNothing);
    });

    testWidgets('Events: Upcoming and Past are each read, a row opens through the shell, and an empty tab says so', (
      tester,
    ) async {
      final repo = FakeChapters()
        ..upcoming = [sampleEvent('e5', 'Site tour', 'bengaluru', DateTime.utc(2026, 12, 5, 4), status: 'GOING')]
        ..past = [sampleEvent('e0', 'Q2 meetup', 'bengaluru', DateTime.utc(2026, 6, 14, 5, 30))];
      final board = await _pumpPage(tester, 'bengaluru', repo: repo);
      expect(find.text('Site tour'), findsOneWidget);
      expect(find.text('You are going'), findsOneWidget);
      await tester.tap(find.text('Site tour'));
      expect(board.events.single, 'e5-slug');

      await tester.tap(find.text('Past'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('events:bengaluru:past'));
      expect(find.text('Q2 meetup'), findsOneWidget);
      expect(find.text('Site tour'), findsNothing);
      await tester.tap(find.text('Q2 meetup'));
      expect(board.events.last, 'e0-slug');

      repo.past = [];
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Past'));
      await tester.pumpAndSettle();
      expect(find.text('No past events yet.'), findsOneWidget);
    });

    testWidgets('a section that fails says so itself and Try again reads it; the rest of the page stands', (
      tester,
    ) async {
      final repo = FakeChapters()
        ..failures['updates'] = ApiError('Updates are down.', statusCode: 500)
        ..failures['events'] = ApiError('Events are down.', statusCode: 500);
      await _pumpPage(tester, 'bengaluru', repo: repo);
      expect(find.text('Updates are down.'), findsOneWidget);
      expect(find.text('Events are down.'), findsOneWidget);
      expect(find.text('Connect the community.'), findsOneWidget);
      repo.failures.clear();
      await tester.tap(find.text('Try again').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again').first);
      await tester.pumpAndSettle();
      expect(find.text('Updates are down.'), findsNothing);
      expect(find.text('Events are down.'), findsNothing);
      expect(find.text('Welcome'), findsOneWidget);
    });

    testWidgets('Members: the total, Show more members, the three filters and the search', (tester) async {
      final repo = FakeChapters();
      await _pumpPage(tester, 'bengaluru', repo: repo);
      expect(find.text('5 members'), findsOneWidget);
      expect(find.text('Person Number1'), findsOneWidget);
      expect(find.text('Person Number3'), findsNothing);
      await tester.tap(find.text('Show more members'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('members:bengaluru:2:all:'));
      expect(find.text('Person Number3'), findsOneWidget);
      expect(find.text('Person Number4'), findsOneWidget);

      await tester.tap(find.text('Committee'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('members:bengaluru:1:committee:'));
      expect(find.text('1 member'), findsOneWidget);
      expect(find.text('Person Number1'), findsOneWidget);
      expect(find.text('Person Number2'), findsNothing);

      await tester.tap(find.text('Corporate only'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(MembersSection), matching: find.text('2 members')), findsOneWidget);

      await tester.tap(find.text('All members'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '').last, 'Number5');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('members:bengaluru:1:all:Number5'));
      expect(find.text('Person Number5'), findsOneWidget);
      expect(find.text('Person Number1'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'Number5'), 'nobody');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('No members match.'), findsOneWidget);
    });

    testWidgets('an Other chapters card opens that chapter’s own page', (tester) async {
      final board = await _pumpPage(tester, 'bengaluru');
      await tester.tap(find.text('ICR Pune Chapter').first);
      await tester.pumpAndSettle();
      expect(board.repo.calls, contains('detail:pune'));
    });

    testWidgets('the section chips scroll to their section', (tester) async {
      await _pumpPage(tester, 'bengaluru', height: 800);
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
      expect(scroll.position.pixels, 0);
      await tester.tap(find.text('Events'));
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, greaterThan(300));
    });

    testWidgets('pulling down reads the page and its sections again', (tester) async {
      final repo = FakeChapters();
      await _pumpPage(tester, 'bengaluru', repo: repo, height: 800);
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

  group('the board: scope, region, city and the preview', () {
    testWidgets('the scope chips count the chapters and narrow the directory to joined or nearby', (tester) async {
      await _pumpBoard(tester);
      expect(find.text('All Chapters (5)'), findsOneWidget);
      expect(find.text('Joined (2)'), findsOneWidget);
      // Nearby: chapters I do not belong to in a region or country of one I do (Mumbai shares Pune's region).
      expect(find.text('Nearby (1)'), findsOneWidget);

      await tester.tap(find.text('Joined (2)'));
      await tester.pumpAndSettle();
      expect(find.byType(ChapterCard), findsNWidgets(2));
      expect(find.text('2 chapters of 5'), findsOneWidget);

      await tester.tap(find.text('Nearby (1)'));
      await tester.pumpAndSettle();
      expect(tester.widget<ChapterCard>(find.byType(ChapterCard)).chapter.slug, 'mumbai');

      await tester.tap(find.text('All Chapters (5)'));
      await tester.pumpAndSettle();
      expect(find.byType(ChapterCard), findsNWidgets(5));
    });

    testWidgets('Nearby with no chapter of my own says what it needs', (tester) async {
      final repo = FakeChapters(
        chapters: [
          sampleChapter('mumbai', city: 'Mumbai', region: 'Maharashtra'),
          sampleChapter('pune', city: 'Pune'),
        ],
      );
      await _pumpBoard(tester, repo: repo);
      await tester.tap(find.text('Nearby (0)'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing nearby yet'), findsOneWidget);
      await tester.tap(find.text('Show all chapters'));
      await tester.pumpAndSettle();
      expect(find.byType(ChapterCard), findsNWidgets(2));
    });

    testWidgets('the sheet filters by region and by city, and each can be taken off', (tester) async {
      final board = await _pumpBoard(tester);
      await tester.tap(find.bySemanticsLabel('Sort and filter chapters'));
      await tester.pumpAndSettle();
      expect(find.text('Region'), findsOneWidget);
      await tester.tap(find.text('Maharashtra'));
      await tester.pumpAndSettle();
      expect(board.controller.region, 'Maharashtra');
      await tester.tap(find.text('Show chapters'));
      await tester.pumpAndSettle();
      expect(find.byType(ChapterCard), findsNWidgets(2));
      expect(find.text('2 chapters of 5'), findsOneWidget);

      // The city list is narrowed to the region: Pune and Mumbai.
      await tester.tap(find.bySemanticsLabel('Sort and filter chapters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pune').last);
      await tester.pumpAndSettle();
      expect(board.controller.city, 'Pune');
      await tester.tap(find.text('Show chapters'));
      await tester.pumpAndSettle();
      expect(tester.widget<ChapterCard>(find.byType(ChapterCard)).chapter.slug, 'pune');

      await tester.tap(find.bySemanticsLabel('Sort and filter chapters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Any city'));
      await tester.tap(find.text('Any region'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show chapters'));
      await tester.pumpAndSettle();
      expect(board.controller.region, isNull);
      expect(board.controller.city, isNull);
      expect(find.byType(ChapterCard), findsNWidgets(5));
    });

    test('a country chip drops a region the country has no chapter in', () async {
      final c = ChaptersController(FakeChapters(), clock: () => testNow);
      await c.start();
      c.setRegion('Maharashtra');
      c.setCountry('USA');
      expect(c.region, isNull);
      expect(c.regions, ['NY']);
      expect(c.cities, ['New York']);
    });

    testWidgets('Preview Chapter opens a sheet read from the chapter’s page; View full details opens the page', (
      tester,
    ) async {
      final board = await _pumpBoard(tester);
      await tester.tap(find.descendant(of: _card('ICR Mumbai Chapter'), matching: find.text('Preview Chapter')));
      await tester.pumpAndSettle();
      expect(board.repo.calls, contains('detail:mumbai'));
      expect(find.byType(ChapterScreen), findsNothing);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Leadership'), findsOneWidget);
      expect(find.text('Vikram Malhotra'), findsOneWidget);
      expect(find.text('Upcoming events'), findsWidgets);

      await tester.tap(find.text('View full details'));
      await tester.pumpAndSettle();
      expect(find.byType(ChapterScreen), findsOneWidget);
    });

    testWidgets('Join from the preview takes the place on the board behind it; Share hands the link over', (
      tester,
    ) async {
      final board = await _pumpBoard(tester);
      await tester.tap(find.descendant(of: _card('ICR Mumbai Chapter'), matching: find.text('Preview Chapter')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(ChapterPreviewSheet), matching: find.text('Join Chapter')));
      await tester.pumpAndSettle();
      expect(board.repo.calls, contains('join:id-mumbai'));
      expect(find.descendant(of: find.byType(ChapterPreviewSheet), matching: find.text('Joined')), findsOneWidget);
      expect(board.controller.find('id-mumbai')!.joined, isTrue);

      await tester.tap(find.descendant(of: find.byType(ChapterPreviewSheet), matching: find.text('Leave')));
      await tester.pumpAndSettle();
      expect(board.repo.calls, contains('leave:id-mumbai'));
      expect(board.controller.find('id-mumbai')!.joined, isFalse);

      await tester.tap(find.bySemanticsLabel('Share chapter'));
      expect(board.shared.single.$1, 'ICR Mumbai Chapter');
    });

    testWidgets('a preview of a chapter that will not load says so and Try again reads it', (tester) async {
      final repo = FakeChapters()..failures['detail:mumbai'] = ApiError('Chapter not found', statusCode: 404);
      await _pumpBoard(tester, repo: repo);
      await tester.tap(find.descendant(of: _card('ICR Mumbai Chapter'), matching: find.text('Preview Chapter')));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load this chapter"), findsOneWidget);
      repo.failures.clear();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Overview'), findsOneWidget);
    });

    testWidgets('a chapter lead has no Leave on the card, and Preview Chapter in its place', (tester) async {
      await _pumpBoard(tester);
      expect(find.descendant(of: _card('ICR Bengaluru Chapter'), matching: find.text('Leave')), findsNothing);
      expect(
        find.descendant(of: _card('ICR Bengaluru Chapter'), matching: find.text('Preview Chapter')),
        findsOneWidget,
      );
      expect(find.descendant(of: _card('ICR Pune Chapter'), matching: find.text('Leave')), findsOneWidget);
    });
  });

  group('a chapter’s page: people, leads and the lead’s own seat', () {
    testWidgets('a committee row opens the member and the message glyph starts a conversation, by user id', (
      tester,
    ) async {
      final board = await _pumpPage(tester, 'bengaluru');
      await tester.tap(find.text('Vikram Malhotra'));
      expect(board.members.single, 'l1');
      await tester.tap(find.byTooltip('Message Vikram Malhotra'));
      expect(board.messages.single, 'l1');
    });

    testWidgets('a roster row opens the member too', (tester) async {
      final board = await _pumpPage(tester, 'bengaluru');
      await tester.tap(find.text('Person Number1'));
      expect(board.members.last, 'p1');
    });

    testWidgets('a lead sees "Chapter lead" and no Leave on their own chapter’s page', (tester) async {
      await _pumpPage(tester, 'bengaluru');
      expect(find.text('Chapter lead'), findsOneWidget);
      expect(find.text('Leave'), findsNothing);
    });
  });

  group('a chapter’s meetups: RSVP through the events API', () {
    final future = DateTime.utc(2026, 11, 20, 4);

    FakeChapters repoWith(List<ChapterEvent> events) => FakeChapters()..upcoming = events;

    testWidgets('RSVP takes the place at once, through POST /events/:id/rsvp, and Cancel gives it back', (
      tester,
    ) async {
      final repo = repoWith([sampleEvent('e5', 'Site tour', 'bengaluru', future)]);
      await _pumpPage(tester, 'bengaluru', repo: repo);
      expect(find.text('RSVP'), findsOneWidget);
      expect(find.text('42 going · 18 seats left'), findsOneWidget);

      await tester.tap(find.text('RSVP'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('rsvp:e5'));
      expect(find.text('You are going'), findsOneWidget);
      expect(find.text('43 going · 17 seats left'), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(MeetupRsvpBar), matching: find.text('Cancel')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('cancel:e5'));
      expect(find.text('RSVP'), findsOneWidget);
      expect(find.text('42 going · 18 seats left'), findsOneWidget);
    });

    testWidgets('a full event offers the waitlist, and the place it gives is the API’s WAITLISTED', (tester) async {
      final repo = repoWith([sampleEvent('e6', 'Summit', 'bengaluru', future, capacity: 30, going: 30)]);
      await _pumpPage(tester, 'bengaluru', repo: repo);
      expect(find.text('Full · 30 going'), findsOneWidget);
      await tester.tap(find.text('Join waitlist'));
      await tester.pumpAndSettle();
      expect(find.text('On the waitlist'), findsOneWidget);
      // A waitlisted place takes no seat.
      expect(find.text('Full · 30 going'), findsOneWidget);
    });

    testWidgets('the API’s refusal of an RSVP is shown and the row goes back as it was', (tester) async {
      final repo = repoWith([sampleEvent('e7', 'Closed door', 'bengaluru', future, inviteOnly: true)])
        ..failures['rsvp'] = ApiError('This event is by invitation only.', statusCode: 403);
      await _pumpPage(tester, 'bengaluru', repo: repo);
      await tester.tap(find.text('RSVP'));
      await tester.pumpAndSettle();
      expect(find.text('This event is by invitation only.'), findsOneWidget);
      expect(find.text('RSVP'), findsOneWidget);
      expect(find.text('You are going'), findsNothing);
    });

    testWidgets('a paid ticket cannot be cancelled here: the API says so and the place stays', (tester) async {
      final repo = repoWith([sampleEvent('e8', 'Workshop', 'bengaluru', future, status: 'GOING', price: 250000)])
        ..failures['cancel'] = ApiError('Your ticket is paid for. To cancel it, contact ICR support.', statusCode: 403);
      await _pumpPage(tester, 'bengaluru', repo: repo);
      await tester.tap(find.descendant(of: find.byType(MeetupRsvpBar), matching: find.text('Cancel')));
      await tester.pumpAndSettle();
      expect(find.text('Your ticket is paid for. To cancel it, contact ICR support.'), findsOneWidget);
      expect(find.text('You are going'), findsOneWidget);
    });

    testWidgets('a ticketed event is bought on the events sheet: "Get ticket" hands it over, no RSVP is sent', (
      tester,
    ) async {
      final repo = repoWith([sampleEvent('e9', 'Lease audit', 'bengaluru', future, price: 250000)]);
      final board = await _pumpPage(tester, 'bengaluru', repo: repo);
      expect(find.text('RSVP'), findsNothing);
      await tester.tap(find.text('Get ticket'));
      expect(board.events.single, 'e9-slug');
      expect(repo.count('rsvp'), 0);
    });

    testWidgets(
      'an invite-only event says so on its row (the chapter’s page lists it to anyone), and the API’s refusal is shown',
      (tester) async {
        final repo = repoWith([sampleEvent('e11', 'Closed door', 'bengaluru', future, inviteOnly: true)])
          ..failures['rsvp'] = ApiError('This event is invite-only.', statusCode: 403);
        await _pumpPage(tester, 'bengaluru', repo: repo);
        expect(find.text('INVITE ONLY'), findsOneWidget);
        await tester.tap(find.text('RSVP'));
        await tester.pumpAndSettle();
        expect(find.text('This event is invite-only.'), findsOneWidget);
        expect(find.text('You are going'), findsNothing);
      },
    );

    testWidgets('an event that is over has no RSVP, only "Event ended"', (tester) async {
      final repo = repoWith([sampleEvent('e10', 'Old meetup', 'bengaluru', DateTime.utc(2026, 10, 20, 4))]);
      await _pumpPage(tester, 'bengaluru', repo: repo);
      expect(find.text('Event ended'), findsOneWidget);
      expect(find.text('RSVP'), findsNothing);
    });

    testWidgets('the Past tab has no RSVP either', (tester) async {
      final repo = FakeChapters()
        ..past = [sampleEvent('e0', 'Q2 meetup', 'bengaluru', DateTime.utc(2026, 6, 14, 5, 30))];
      await _pumpPage(tester, 'bengaluru', repo: repo);
      await tester.tap(find.text('Past'));
      await tester.pumpAndSettle();
      expect(find.text('Q2 meetup'), findsOneWidget);
      expect(find.text('RSVP'), findsNothing);
      expect(find.text('Event ended'), findsNothing);
    });

    testWidgets('a row opens the event sheet through the shell and an RSVP in flight is not sent twice', (
      tester,
    ) async {
      final repo = repoWith([sampleEvent('e5', 'Site tour', 'bengaluru', future)]);
      final board = await _pumpPage(tester, 'bengaluru', repo: repo);
      final page = tester.element(find.byType(ChapterScreen)).read<ChapterController>();
      final event = page.events.items.single;
      final first = page.rsvp(event);
      expect(await page.rsvp(event), isNull);
      await first;
      expect(repo.count('rsvp'), 1);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Site tour'));
      expect(board.events.single, 'e5-slug');
    });
  });

  group('the API’s RSVP rows', () {
    test('a CANCELLED row (what the API keeps after Cancel) is no RSVP; GOING, WAITLISTED and ATTENDED are', () async {
      final table = TableApi({
        'GET /chapters/bengaluru': (_) => _detailJson,
        'GET /chapters/memberships/mine': (_) => <Object>[],
        'GET /events/rsvps/mine': (_) => [
          {'eventId': 'e1', 'status': 'CANCELLED'},
          {'eventId': 'e2', 'status': 'WAITLISTED'},
          {'eventId': 'e3', 'status': 'ATTENDED'},
        ],
        'GET /events': (_) => _page([
          _eventRow,
          {..._eventRow, 'id': 'e2', 'slug': 'two'},
          {..._eventRow, 'id': 'e3', 'slug': 'three'},
        ]),
      });
      final repo = ApiChaptersRepository(api: table.client());
      final events = await repo.events('bengaluru');
      expect(events.map((e) => e.myStatus), [null, 'WAITLISTED', 'ATTENDED']);
      expect(events.map((e) => e.holding), [false, true, false]);
      expect(events.last.going, isTrue);
    });

    test('RSVP and cancel are the events API’s two calls, and the answer’s status is kept', () async {
      final table = TableApi({
        'POST /events/e1/rsvp': (_) => {'status': 'WAITLISTED'},
        'DELETE /events/e1/rsvp': (_) => {'status': 'CANCELLED'},
      });
      final repo = ApiChaptersRepository(api: table.client());
      final event = ChapterEvent(id: 'e1', title: 'T', startsAt: DateTime.utc(2026, 11, 1));
      expect(await repo.rsvp(event), 'WAITLISTED');
      await repo.cancelRsvp(event);
      expect(table.calls, ['POST /events/e1/rsvp', 'DELETE /events/e1/rsvp']);
    });

    test('an RSVP the API refuses throws its own sentence', () async {
      final table = TableApi({
        'POST /events/e1/rsvp': (_) => (400, '{"message":"This event is ticketed. Buy a ticket to take your place."}'),
      });
      final repo = ApiChaptersRepository(api: table.client());
      await expectLater(
        repo.rsvp(ChapterEvent(id: 'e1', title: 'T', startsAt: DateTime.utc(2026, 11, 1))),
        throwsA(
          isA<ApiError>().having(
            (e) => e.message,
            'message',
            'This event is ticketed. Buy a ticket to take your place.',
          ),
        ),
      );
    });

    test('the event model moves its seat count with the place', () {
      final e = sampleEvent('e', 'T', 'bengaluru', DateTime.utc(2026, 12, 1));
      expect(e.withStatus('GOING', moveCount: true).attendeeCount, 43);
      expect(e.withStatus('WAITLISTED', moveCount: true).attendeeCount, 42);
      final going = e.withStatus('GOING');
      expect(going.withStatus(null, moveCount: true).attendeeCount, 41);
      expect(going.withStatus('WAITLISTED', moveCount: true).attendeeCount, 41);
      expect(going.withStatus('GOING', moveCount: true).attendeeCount, 42);
    });
  });

  group('the sample source', () {
    test('answers the board and a chapter, and keeps a join', () async {
      final repo = DemoChaptersRepository();
      final overview = await repo.overview();
      expect(overview.chapters, hasLength(6));
      final mumbai = overview.chapters.firstWhere((c) => c.slug == 'mumbai');
      await repo.join(mumbai);
      expect((await repo.overview()).chapters.firstWhere((c) => c.slug == 'mumbai').joined, isTrue);
      final detail = await repo.detail('bengaluru');
      expect(detail.about.first.kind, AboutKind.heading);
      expect(detail.leads, hasLength(3));
    });
  });
}
