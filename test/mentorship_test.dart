import 'dart:convert';

import 'package:icr_mobile/core/util/app_actions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/widgets/search_field.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart';
import 'package:icr_mobile/features/mentorship/api_mentorship_repository.dart';
import 'package:icr_mobile/features/mentorship/demo_mentorship_repository.dart';
import 'package:icr_mobile/features/mentorship/find_mentors_screen.dart';
import 'package:icr_mobile/features/mentorship/mentorship_controller.dart';
import 'package:icr_mobile/features/mentorship/mentorship_format.dart';
import 'package:icr_mobile/features/mentorship/mentorship_models.dart';
import 'package:icr_mobile/features/mentorship/mentorship_repository.dart';
import 'package:icr_mobile/features/mentorship/mentorship_screen.dart';
import 'package:icr_mobile/features/mentorship/mentorship_styles.dart';
import 'package:icr_mobile/features/mentorship/widgets/category_chips.dart';
import 'package:icr_mobile/features/mentorship/widgets/landing_blocks.dart';
import 'package:icr_mobile/features/mentorship/widgets/mentor_card.dart';
import 'package:icr_mobile/features/shell/icr_bottom_nav.dart';
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
  final List<RequestOptions> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    final handler = routes['${options.method} ${options.path}'];
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

ApiMentorshipRepository _repo(_Api api) {
  final client = ApiClient(tokens: _NoTokens(), baseUrl: 'http://api.test/api/v1');
  client.dio.httpClientAdapter = api;
  return ApiMentorshipRepository(api: client);
}

/// One row of `GET /mentorship/mentors` (a `MentorCardDto`).
Map<String, dynamic> _row(
  String id,
  String first,
  String last, {
  String? company,
  String? org,
  String? cover,
  List<String> competencies = const ['Facility Management'],
}) => {
  'id': id,
  'user': {
    'id': 'u-$id',
    'firstName': first,
    'lastName': last,
    'avatarUrl': '/uploads/$id.jpg',
    if (company != null) 'company': {'name': company, 'logoUrl': '/uploads/${company.toLowerCase()}.png'},
  },
  'headline': 'Headline of $first',
  'coverImage': cover,
  'competencies': competencies,
  'status': 'APPROVED',
  'isTopMentor': id == 'm1',
  'rating': 4.8,
  'ratingCount': 12,
  'yearsExperience': 14,
  'career': {
    'currentRole': org == null ? null : {'title': 'VP Facility Ops', 'organisation': org},
  },
};

List<Map<String, dynamic>> _tenMentors() => [
  _row('m1', 'Rajesh', 'Sharma', company: 'Infosys', org: 'Infosys', cover: '/uploads/c1.jpg'),
  _row('m2', 'Lisa', 'Cheng', company: 'Infosys', org: 'Infosys', cover: 'skyline'),
  _row('m3', 'David', 'Kim', company: 'Google', org: 'Google'),
  _row('m4', 'Sophia', 'Patel', org: 'Cisco'),
  for (var i = 5; i <= 10; i++) _row('m$i', 'Mentor', 'Number$i'),
];

/// Ten domains, `Domain 1` listed by the most mentors.
List<Map<String, dynamic>> _domains() => [
  for (var i = 1; i <= 10; i++) {'label': 'Domain $i', 'count': 11 - i},
];

_Api _landingApi() => _Api({
  'GET /mentorship/mentors/saved/ids': (_) => {
    'ids': ['m2'],
  },
  'GET /mentorship/mentors/facets': (_) => {'total': 31, 'competencies': _domains()},
  'GET /mentorship/mentors': (o) {
    final rows = _tenMentors();
    return {
      'data': o.queryParameters['sortBy'] == 'sessionsCompleted' ? rows.reversed.toList() : rows,
      'meta': {'total': 48, 'hasNext': true},
    };
  },
  'GET /mentorship/public-stats': (_) => {'listedMentors': 31},
  'GET /mentorship/programmes': (_) => {
    'data': [
      {
        'id': 'p1',
        'slug': 'bengaluru-2027',
        'name': 'Bengaluru Graduate Mentoring',
        'enrolmentCount': 12,
        'coverUrl': '/uploads/cohort.jpg',
        'organiser': {'firstName': 'Asha', 'lastName': 'Nair', 'avatarUrl': null},
      },
    ],
    'meta': {},
  },
  'GET /mentor-services/mentors/m1': (_) => {
    'live': true,
    'services': [
      {
        'id': 's1',
        'mentorProfileId': 'm1',
        'type': 'ONE_ON_ONE',
        'title': 'Discovery Call',
        'blurb': 'A first call.',
        'durationMin': 30,
        'pricePaisa': 0,
        'active': true,
      },
      {
        'id': 's2',
        'mentorProfileId': 'm1',
        'type': 'ONE_ON_ONE',
        'title': 'Interview Strategy',
        'durationMin': 45,
        'pricePaisa': 149900,
        'active': true,
      },
      {
        'id': 's3',
        'mentorProfileId': 'm1',
        'type': 'QUERY',
        'title': 'Resume Review',
        'slaHours': 24,
        'pricePaisa': 0,
        'active': true,
      },
      {
        'id': 's4',
        'mentorProfileId': 'm1',
        'type': 'RESOURCE',
        'title': 'A fourth card is never shown',
        'pricePaisa': 0,
        'active': true,
      },
    ],
  },
  'GET /notifications/unread-count': (_) => {'unread': 3},
});

/// The demo source, recording what the screens ask it for.
class _Repo implements MentorshipRepository {
  _Repo({MentorshipOverview Function(MentorshipOverview)? transform}) : _transform = transform;

  final inner = DemoMentorshipRepository();
  final MentorshipOverview Function(MentorshipOverview)? _transform;

  /// The category each `overview()` was asked for.
  final overviews = <String?>[];

  /// Every directory page asked for.
  final searches = <(MentorFilters, int)>[];

  MentorFilters get lastFilters => searches.last.$1;

  @override
  Future<MentorshipOverview> overview({String? category}) async {
    overviews.add(category);
    final o = await inner.overview(category: category);
    return _transform == null ? o : _transform(o);
  }

  @override
  Future<List<MentorCategory>> categories() => inner.categories();

  @override
  Future<MentorPage> search(MentorFilters filters, {int page = 1}) {
    searches.add((filters, page));
    return inner.search(filters, page: page);
  }

  @override
  Future<void> setSaved(Mentor mentor, bool saved) => inner.setSaved(mentor, saved);

  @override
  Future<int> unreadNotifications() => inner.unreadNotifications();

  @override
  Uri link(Mentor mentor) => inner.link(mentor);
}

/// A screen's outward calls, recorded.
class _Calls {
  final mentors = <String>[];
  final sites = <String>[];
  var backs = 0;

  void openMentor(BuildContext context, String id) => mentors.add(id);

  Future<void> openSite(BuildContext context, String path) async => sites.add(path);
}

void _tall(WidgetTester tester, {double height = 5700}) {
  tester.view.physicalSize = Size(780, height);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// The landing, started, on a window tall enough to show all of it.
Future<MentorshipController> _pumpLanding(WidgetTester tester, _Repo repo, _Calls calls) async {
  _tall(tester);
  final mentorship = MentorshipController(repo);
  await tester.runAsync(mentorship.start);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: ChangeNotifierProvider.value(
        value: mentorship,
        child: MentorshipScreen(
          onBack: () => calls.backs++,
          onOpenMentor: calls.openMentor,
          viewer: DemoFeedRepository.me,
          onAccount: () {},
          openSite: calls.openSite,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return mentorship;
}

/// Find Mentors as a pushed screen would have it: the tab's controller above it.
Future<void> _pumpFind(
  WidgetTester tester,
  _Repo repo,
  _Calls calls, {
  String? category,
  String search = '',
  String? company,
  bool companyOnAccount = false,
  double height = 2400,
}) async {
  _tall(tester, height: height);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: ChangeNotifierProvider.value(
        value: MentorshipController(repo),
        child: FindMentorsScreen(
          onBack: () => calls.backs++,
          onOpenMentor: calls.openMentor,
          category: category,
          search: search,
          company: company,
          companyOnAccount: companyOnAccount,
          openSite: calls.openSite,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

TextField _searchBox(WidgetTester tester) =>
    tester.widget<TextField>(find.descendant(of: find.byType(IcrSearchField), matching: find.byType(TextField)));

Future<void> _submit(WidgetTester tester, Finder box, String text) async {
  await tester.enterText(box, text);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

/// Drags the page down from its top, the way a thumb pulls to refresh. The
/// indicator wants a pull of a quarter of the window, so the landing's tall
/// test window needs a long one.
Future<void> _pullToRefresh(WidgetTester tester) async {
  await tester.fling(find.byType(CustomScrollView), const Offset(0, 1800), 1000);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('the models', () {
    test('a service pill reads as the design writes it', () {
      final pills = DemoMentorshipRepository.services.map((s) => s.pill).toList();
      expect(pills, [
        '1:1 Diagnostic Call • 30 Mins • Free',
        '1:1 Session • 45 Mins • ₹1,499',
        'Async Query • 24 Hrs TAT • Free',
      ]);
      expect(DemoMentorshipRepository.services.map((s) => s.buttonLabel), [
        'Book Diagnostic (Free)',
        'Book Session',
        'Request Review',
      ]);
    });

    test('filters count the chips that are on', () {
      expect(const MentorFilters().count, 0);
      expect(const MentorFilters(category: 'Operations & FM', minExperience: 10).count, 2);
      expect(const MentorFilters(availableOnly: true).count, 1);
      expect(const MentorFilters(company: 'SpaceX').count, 1);
      expect(const MentorFilters(category: 'Operations & FM', minExperience: 10, company: 'JLL').count, 3);
    });

    test('clearing the company clears whether it was on an account too', () {
      final on = const MentorFilters(company: 'JLL', companyOnAccount: true).copyWith(clearCompany: true);
      expect(on.company, isNull);
      expect(on.companyOnAccount, isFalse);
    });

    test('a category chip takes its glyph from the domain', () {
      expect(domainGlyph('Operations & FM').size, 16);
      expect(domainGlyph('Sustainability & ESG').icon, isNot(domainGlyph('Operations & FM').icon));
      expect(domainGlyph('Smart Buildings & IoT').icon, isNot(domainGlyph('Sustainability & ESG').icon));
    });
  });

  group('counts promised with a plus', () {
    test('round down to the nearest 1, 5, 10, 50 or 500, never up', () {
      const cases = {
        0: 0,
        1: 1,
        8: 8,
        9: 9,
        10: 10,
        14: 10,
        15: 15,
        49: 45,
        50: 50,
        58: 50,
        64: 60,
        99: 90,
        100: 100,
        123: 100,
        149: 100,
        150: 150,
        999: 950,
        1000: 1000,
        3120: 3000,
        3499: 3000,
        3500: 3500,
      };
      cases.forEach((n, rounded) => expect(roundedDown(n), rounded, reason: '$n'));
      for (var n = 0; n < 5000; n += 7) {
        expect(roundedDown(n), lessThanOrEqualTo(n));
      }
    });

    test('the Domains pill words it as the design does: "8+ Domains", "50+ Domains"', () {
      expect(domainsBadgeFor(8), '8+ Domains');
      expect(domainsBadgeFor(58), '50+ Domains');
      expect(domainsBadgeFor(14), '10+ Domains');
      expect(domainsBadgeFor(0), isEmpty); // no domains, no pill
    });

    test('a count over a thousand is grouped like the design\'s "3,000+"', () {
      expect(plusCount(3120), '3,000+');
      expect(plusCount(64), '60+');
    });

    test('the banner says it with the real count', () {
      expect(
        ApiMentorshipRepository.bannerBody(64),
        'Join 60+ senior leaders guiding emerging facility managers and corporate real estate professionals.',
      );
      expect(ApiMentorshipRepository.bannerBody(0), isNot(contains('+')));
    });
  });

  group('the company tiles\' colours', () {
    test('JLL is red and CBRE blue, as the design sets them; the rest are in ink', () {
      expect(MentorshipBrand.wordmark('JLL'), MentorshipBrand.jll);
      expect(MentorshipBrand.wordmark('JLL India'), MentorshipBrand.jll);
      expect(MentorshipBrand.wordmark('Jones Lang LaSalle'), MentorshipBrand.jll);
      expect(MentorshipBrand.wordmark('CBRE'), MentorshipBrand.cbre);
      expect(MentorshipBrand.wordmark('cbre group, inc.'), MentorshipBrand.cbre);
      for (final other in ['Microsoft', 'Amazon', 'Google', 'Infosys', 'Cisco', 'SpaceX', 'Jollibee']) {
        expect(MentorshipBrand.wordmark(other), MentorshipBrand.ink, reason: other);
      }
      expect(MentorshipBrand.jll, isNot(MentorshipBrand.cbre));
    });
  });

  group('the demo source', () {
    test('holds the eight cards of the designs, as drawn', () {
      final cards = DemoMentorshipRepository.mentors;
      expect(cards.map((m) => m.name), [
        'Rajesh Sharma',
        'Rajesh Sharma',
        'Lisa Cheng',
        'David Kim',
        'Sophia Patel',
        'Michael Johnson',
        'Emma Thompson',
        'James Rodriguez',
      ]);
      expect(cards[2].role, 'Director of Sustainability @ Google');
      expect(cards[3].role, 'Chief Technology Officer @ Cisco');
      expect(cards[0].expertise, ['Smart Campuses', 'Smart Campuses', 'BMS']);
      expect(cards[7].expertise, ['Aerospace', 'Launch Operations']);
      expect(cards.every((m) => m.approved && m.avatar?.asset != null && m.cover?.asset != null), isTrue);
    });

    test('has the landing\'s bands', () async {
      final o = await DemoMentorshipRepository().overview();
      expect(o.domainsBadge, '8+ Domains');
      expect(o.selectedCategory, 'Operations & FM');
      expect(o.companies.map((c) => c.name), [
        'Microsoft',
        'Amazon',
        'JLL',
        'CBRE',
        'CBRE',
        'JLL',
        'Google',
        'Infosys',
      ]);
      expect(o.shelves.map((s) => s.title), [mentorNetworkTitle, mentorNetworkTitle]);
      expect(o.shelves.first.mentors.length, 8);
      expect(o.topics.length, 9);
      expect(o.topics.where((t) => t.tone == TopicTone.red).map((t) => t.label), [
        'Workplace Safety',
        'Employee Wellbeing',
      ]);
      expect(o.banner!.body, startsWith('Join 3,000+ senior leaders'));
      expect(o.cohort!.name, 'FM Leadership & ESG Masterclass');
      expect(o.cohort!.registeredLabel, '32 Leaders Registered');
    });

    test('pages the directory to 48', () async {
      final repo = DemoMentorshipRepository();
      final first = await repo.search(const MentorFilters());
      expect((first.mentors.length, first.total, first.hasMore), (8, 48, true));
      final last = await repo.search(const MentorFilters(), page: 6);
      expect(last.hasMore, isFalse);
    });
  });

  group('the API source', () {
    test('maps a directory row and its total', () async {
      final api = _landingApi();
      final page = await _repo(
        api,
      ).search(const MentorFilters(category: 'Operations & FM', minExperience: 10, sort: MentorSort.rating), page: 2);
      expect(page.total, 48);
      expect(page.hasMore, isTrue);
      final call = api.calls.lastWhere((c) => c.path == '/mentorship/mentors');
      expect(call.queryParameters, {
        'page': 2,
        'limit': 8,
        'sortBy': 'rating',
        'sortDir': 'desc',
        'competencies': 'Operations & FM',
        'minExperience': 10,
      });

      final rajesh = page.mentors.first;
      expect(rajesh.name, 'Rajesh Sharma');
      expect(rajesh.userId, 'u-m1');
      expect(rajesh.role, 'VP Facility Ops @ Infosys');
      expect(rajesh.avatar?.url, 'http://api.test/uploads/m1.jpg');
      expect(rajesh.cover?.url, 'http://api.test/uploads/c1.jpg');
      expect(rajesh.companyName, 'Infosys');
      expect(rajesh.companyOnAccount, isTrue);
      expect(rajesh.approved, isTrue);
      expect(rajesh.topMentor, isTrue);
      final lisa = page.mentors[1];
      expect(lisa.cover, isNull);
      expect(lisa.coverPreset, 'skyline');
      expect(lisa.saved, isTrue); // from /mentorship/mentors/saved/ids
      // Without a company on the account, the organisation on the role stands in.
      final sophia = page.mentors[3];
      expect(sophia.companyName, 'Cisco');
      expect(sophia.companyOnAccount, isFalse);
    });

    test('a mentor with no current role shows their own headline', () async {
      final api = _Api({
        'GET /mentorship/mentors/saved/ids': (_) => {'ids': []},
        'GET /mentorship/mentors': (_) => {
          'data': [_row('m9', 'Asha', 'Nair')],
          'meta': {'total': 1, 'hasNext': false},
        },
      });
      final page = await _repo(api).search(const MentorFilters());
      expect(page.mentors.single.role, isNull);
      expect(page.mentors.single.roleLine, 'Headline of Asha');
    });

    test('builds the landing from the facets, shelves, stats, programmes and storefronts', () async {
      final api = _landingApi();
      final o = await _repo(api).overview();

      // Chips: the eight most-listed domains; the rest become topics.
      expect(o.categories.length, 8);
      expect(o.categories.first.label, 'Domain 1');
      expect(o.topics.map((t) => t.label), ['Domain 9', 'Domain 10']);
      // The pill is the design's "8+ Domains": the count rounded down, with a plus.
      expect(o.domainsBadge, '10+ Domains');
      // The most-listed domain opens lit, as in the design, and the shelves are its.
      expect(o.selectedCategory, 'Domain 1');
      final lists = api.calls.where((c) => c.path == '/mentorship/mentors');
      expect(lists.every((c) => c.queryParameters['competencies'] == 'Domain 1'), isTrue);

      // Both grids wear the design's title; the first is the viewer's network
      // (here only the saved m2 is a tie), then the best rated, and the second
      // is the most sessions delivered, without repeating a face.
      expect(o.shelves.map((s) => s.title), [mentorNetworkTitle, mentorNetworkTitle]);
      expect(o.shelves.first.mentors.map((m) => m.id), ['m2', 'm1', 'm3', 'm4', 'm5', 'm6', 'm7', 'm8']);
      expect(o.shelves.last.mentors.map((m) => m.id), ['m10', 'm9']);

      // Employers: grouped from the mentors, most first.
      expect(o.companies.first.name, 'Infosys');
      expect(o.companies.first.mentors, 2);
      expect(o.companies.first.onAccount, isTrue);

      // The band uses the design's sentence with the live count rounded down,
      // and its photograph is bundled, so it is drawn live too.
      expect(o.banner!.body, startsWith('Join 30+ senior leaders'));
      expect(o.banner!.link, '/become-a-mentor');
      expect(o.banner!.photo?.asset, mentorBannerPhoto.asset);
      // The cohort: the live enrolment count, the organiser's circle and "+11".
      expect(o.cohort!.name, 'Bengaluru Graduate Mentoring');
      expect(o.cohort!.registeredLabel, '12 Registered');
      expect(o.cohort!.link, '/mentorship/programmes/bengaluru-2027');
      expect(o.cohort!.avatars.map((a) => a.initials), ['AN', '+11']);
      expect(o.cohort!.cover?.url, 'http://api.test/uploads/cohort.jpg');

      // Three advisory sessions at most, the first one featured.
      expect(o.services.map((s) => s.pill), [
        '1:1 Session • 30 Mins • Free',
        '1:1 Session • 45 Mins • ₹1,499',
        'Async Query • 24 Hrs TAT • Free',
      ]);
      expect(o.services.map((s) => s.featured), [true, false, false]);
      expect(o.services.first.mentorId, 'm1');
    });

    test('"your network": saved, followed and same-company mentors lead the first grid', () async {
      final api = _landingApi()
        ..routes.addAll({
          'GET /members/me/following': (_) => {
            'data': [
              {'id': 'u-m7'},
            ],
          },
          'GET /auth/me': (_) => {'companyId': 'c1'},
          'GET /companies/c1': (_) => {'name': 'Google'},
        });
      final o = await _repo(api).overview();
      // m2 is saved, m3 works at the viewer's own company, m7 is followed:
      // each group keeps the best-rated order, and everyone else follows.
      expect(o.shelves.first.mentors.map((m) => m.id), ['m2', 'm3', 'm7', 'm1', 'm4', 'm5', 'm6', 'm8']);
      expect(o.shelves.first.title, mentorNetworkTitle);
    });

    test('with no ties the first grid is the best rated, unchanged', () {
      final mentors = [for (var i = 1; i <= 5; i++) Mentor(id: 'm$i', userId: 'u$i', name: 'M$i')];
      expect(ApiMentorshipRepository.networkFirst(mentors).map((m) => m.id), ['m1', 'm2', 'm3', 'm4', 'm5']);
      expect(ApiMentorshipRepository.networkFirst(mentors, saved: {'m4'}, followed: {'u2'}).map((m) => m.id), [
        'm2',
        'm4',
        'm1',
        'm3',
        'm5',
      ]);
      // A company name with other case or spacing is still the viewer's.
      final at = [
        const Mentor(id: 'a', name: 'A', companyName: 'Acme'),
        const Mentor(id: 'b', name: 'B', companyName: ' ACME '),
      ];
      expect(ApiMentorshipRepository.networkFirst(at, company: 'acme').map((m) => m.id), ['a', 'b']);
      expect(ApiMentorshipRepository.networkFirst(at.reversed.toList(), company: 'Acme').map((m) => m.id), ['b', 'a']);
    });

    test('topic tints: red for the selected (top two without focus areas), blue for the suggested', () {
      final topics = [for (var i = 1; i <= 9; i++) MentorCategory(label: 'Topic $i', count: 20 - i)];
      List<TopicTone> tones(Set<String> own) => [
        for (final t in ApiMentorshipRepository.toneTopics(topics, own)) t.tone,
      ];

      expect(tones({}), [
        TopicTone.red,
        TopicTone.red,
        TopicTone.blue,
        TopicTone.blue,
        ...List.filled(5, TopicTone.neutral),
      ]);
      // The member's own focus areas (any case) are what is selected, and the
      // two most-listed others are suggested.
      expect(tones({'topic 5'}), [
        TopicTone.blue,
        TopicTone.blue,
        TopicTone.neutral,
        TopicTone.neutral,
        TopicTone.red,
        ...List.filled(4, TopicTone.neutral),
      ]);
      // A focus area that is not one of these topics selects nothing of them.
      expect(tones({'Operations & FM'}), tones({}));
      expect(ApiMentorshipRepository.toneTopics(const [], {'x'}), isEmpty);
    });

    test('the member\'s mentee focus areas select their topics; an empty mentee profile selects the top two', () async {
      final api = _landingApi()
        ..routes['GET /mentorship/mentees/me'] = (_) => {
          'focusAreas': ['Domain 10'],
        };
      var o = await _repo(api).overview();
      expect(o.topics.map((t) => t.tone), [TopicTone.blue, TopicTone.red]);

      // `GET /mentorship/mentees/me` answers 200 with no body until a mentee profile exists.
      final empty = _landingApi()..routes['GET /mentorship/mentees/me'] = (_) => (200, '');
      o = await _repo(empty).overview();
      expect(o.topics.map((t) => t.tone), [TopicTone.red, TopicTone.red]);
    });

    test('scopes the shelves to a category', () async {
      final api = _landingApi();
      final o = await _repo(api).overview(category: 'Domain 3');
      expect(o.selectedCategory, 'Domain 3');
      final lists = api.calls.where((c) => c.path == '/mentorship/mentors');
      expect(lists.length, 2);
      expect(lists.every((c) => c.queryParameters['competencies'] == 'Domain 3'), isTrue);
    });

    test('a mentor grid that cannot be read fails the landing, so it can say so and try again', () async {
      final api = _landingApi();
      api.routes['GET /mentorship/mentors'] = (_) => (429, '{"message":"Too many requests"}');
      await expectLater(_repo(api).overview(), throwsA(isA<ApiError>()));
    });

    test('a storefront that is down does not break the landing', () async {
      final api = _landingApi();
      api.routes['GET /mentor-services/mentors/m1'] = (_) => (500, '{"message":"down"}');
      final o = await _repo(api).overview();
      expect(o.services, isEmpty);
      expect(o.shelves, isNotEmpty);
    });

    test('a company on mentors\' accounts filters on `companies`, never on words', () {
      final q = ApiMentorshipRepository.directoryQuery(const MentorFilters(company: 'JLL', companyOnAccount: true));
      expect(q['companies'], 'JLL');
      expect(q.containsKey('search'), isFalse);
    });

    test('a company known only from a role is found by its words in the headline, behind its chip', () {
      final q = ApiMentorshipRepository.directoryQuery(const MentorFilters(company: 'SpaceX'));
      expect(q['search'], 'SpaceX');
      expect(q.containsKey('companies'), isFalse);
    });

    test('typed words win over a role-only company, and sit beside an account company', () {
      expect(
        ApiMentorshipRepository.directoryQuery(const MentorFilters(company: 'SpaceX', search: 'james'))['search'],
        'james',
      );
      final both = ApiMentorshipRepository.directoryQuery(
        const MentorFilters(company: 'JLL', companyOnAccount: true, search: 'meghna'),
      );
      expect((both['companies'], both['search']), ('JLL', 'meghna'));
    });

    test('every filter reaches the query: category, experience, free slots, sort and page', () async {
      final api = _landingApi();
      await _repo(api).search(
        const MentorFilters(
          category: 'Operations & FM',
          minExperience: 15,
          availableOnly: true,
          sort: MentorSort.sessionsCompleted,
        ),
        page: 3,
      );
      final q = api.calls.lastWhere((c) => c.path == '/mentorship/mentors').queryParameters;
      expect(q, {
        'page': 3,
        'limit': 8,
        'sortBy': 'sessionsCompleted',
        'sortDir': 'desc',
        'competencies': 'Operations & FM',
        'minExperience': 15,
        'availableOnly': true,
      });
    });

    test('saving a mentor posts, and taking it back deletes', () async {
      final api = _Api({
        'POST /mentorship/mentors/m1/save': (_) => {'status': 'SAVED'},
        'DELETE /mentorship/mentors/m1/save': (_) => {'status': 'NONE'},
      });
      final repo = _repo(api);
      const mentor = Mentor(id: 'm1', name: 'Rajesh Sharma');
      await repo.setSaved(mentor, true);
      await repo.setSaved(mentor, false);
      expect(api.calls.map((c) => '${c.method} ${c.path}'), [
        'POST /mentorship/mentors/m1/save',
        'DELETE /mentorship/mentors/m1/save',
      ]);
    });
  });

  group('the controllers', () {
    test('the tab loads the overview and re-scopes it on a category, the same chip clearing it', () async {
      final mentorship = MentorshipController(DemoMentorshipRepository());
      await mentorship.start();
      expect(mentorship.overview!.shelves.length, 2);
      expect(mentorship.selectedCategory, 'Operations & FM');
      expect(mentorship.unread, 1);

      await mentorship.selectCategory('Sustainability & ESG');
      expect(mentorship.selectedCategory, 'Sustainability & ESG');
      await mentorship.selectCategory('Sustainability & ESG');
      expect(mentorship.selectedCategory, 'Operations & FM'); // back to the demo's own default
    });

    test('a refused save is rolled back and says why', () async {
      final mentorship = MentorshipController(_Refusing(DemoMentorshipRepository()));
      await mentorship.start();
      final mentor = mentorship.overview!.shelves.first.mentors.first;
      expect(mentor.saved, isFalse);
      final message = await mentorship.toggleSave(mentor);
      expect(message, 'No bookmarks today.');
      expect(mentorship.find(mentor.id)!.saved, isFalse);
    });

    test('an accepted save stays', () async {
      final mentorship = MentorshipController(DemoMentorshipRepository());
      await mentorship.start();
      final mentor = mentorship.overview!.shelves.first.mentors.first;
      expect(await mentorship.toggleSave(mentor), isNull);
      expect(mentorship.find(mentor.id)!.saved, isTrue);
    });

    test('Find Mentors loads the chips and the first page, then appends the next', () async {
      final find = FindMentorsController(DemoMentorshipRepository(), category: 'Operations & FM');
      await find.start();
      expect(find.categories.first.label, 'Operations & FM');
      expect(find.mentors.length, 8);
      expect(find.total, 48);
      expect(find.hasMore, isTrue);

      await find.loadMore();
      expect(find.mentors.length, 16);
      expect(find.mentors.map((m) => m.id).toSet().length, 16);
    });

    test('Find Mentors counts the filters on and searches by name', () async {
      final find = FindMentorsController(DemoMentorshipRepository(), category: 'Operations & FM');
      await find.start();
      expect(find.filters.count, 1);
      await find.setMinExperience(10);
      expect(find.filters.count, 2);
      await find.setMinExperience(null);
      expect(find.filters.count, 1);

      await find.setSearch('lisa');
      expect(find.mentors.map((m) => m.name), ['Lisa Cheng']);
      expect(find.total, 1);

      await find.setCategory('Operations & FM'); // the same chip again clears it
      expect(find.filters.category, isNull);
      await find.setSort(MentorSort.yearsExperience);
      expect(find.filters.sort, MentorSort.yearsExperience);
    });

    test('a company chip narrows the list with the search box empty, and its cross clears it', () async {
      final find = FindMentorsController(DemoMentorshipRepository(), company: 'Infosys');
      await find.start();
      expect(find.filters.company, 'Infosys');
      expect(find.filters.search, isEmpty);
      expect(find.filters.count, 1);
      expect(find.mentors.map((m) => m.name), ['Rajesh Sharma', 'Rajesh Sharma']);
      expect(find.total, 2);

      await find.clearCompany();
      expect(find.filters.company, isNull);
      expect(find.total, 48);
    });

    test('typing words replaces a role-only company; a company on accounts stays beside them', () async {
      final roleOnly = FindMentorsController(DemoMentorshipRepository(), company: 'Infosys');
      await roleOnly.start();
      await roleOnly.setSearch('rajesh');
      expect(roleOnly.filters.company, isNull);
      expect(roleOnly.filters.search, 'rajesh');

      final account = FindMentorsController(DemoMentorshipRepository(), company: 'Infosys', companyOnAccount: true);
      await account.start();
      await account.setSearch('rajesh');
      expect(account.filters.company, 'Infosys');
      expect(account.filters.search, 'rajesh');
    });

    test('the design\'s state: Operations & FM and 10+ years is "Filters (2)"', () async {
      final find = FindMentorsController(DemoMentorshipRepository(), category: 'Operations & FM', minExperience: 10);
      await find.start();
      expect(find.filters.count, 2);
      expect((find.mentors.length, find.total), (8, 48));
    });
  });

  group('the mentor card', () {
    testWidgets('wraps its role line where the design wraps it', (tester) async {
      tester.view.physicalSize = const Size(780, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MentorGrid(mentors: DemoMentorshipRepository.mentors, onOpen: (_) {}),
            ),
          ),
        ),
      );

      String firstLine(String text) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(text).first);
        // Far to the right of the first line: the offset where that line ends.
        final end = paragraph.getPositionForOffset(const Offset(1000, 2)).offset;
        return text.substring(0, end).trim();
      }

      // The design keeps the "@" at the end of a line when it fits, and
      // carries it to the next line when it does not (at the app's 14 sp
      // "Chief Technology Officer @" no longer fits, so the "@" goes down).
      expect(firstLine('VP Facility Ops @ Infosys'), 'VP Facility Ops @ Infosys');
      expect(firstLine('Chief Technology Officer @ Cisco'), 'Chief Technology Officer');
      expect(firstLine('Director of Sustainability @ Google'), 'Director of Sustainability');
      expect(firstLine('Product Manager @ Amazon'), 'Product Manager @');
      expect(firstLine('Operations Manager @ SpaceX'), 'Operations Manager @');
    });

    testWidgets('opens the mentor on tap', (tester) async {
      Mentor? opened;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 175,
              child: MentorCard(
                mentor: DemoMentorshipRepository.mentors[2],
                onTap: () => opened = DemoMentorshipRepository.mentors[2],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Lisa Cheng'));
      expect(opened?.id, 'lisa');
    });
  });

  group('the landing: what it draws', () {
    testWidgets('both grids are titled "Top Mentors in Your Network", as the design has them', (tester) async {
      await _pumpLanding(tester, _Repo(), _Calls());
      expect(find.text('Top Mentors in Your Network'), findsNWidgets(2));
      expect(find.text('Explore by Companies'), findsOneWidget);
      expect(find.text('Explore by Expertise'), findsOneWidget);
      expect(find.text('Learn from top topics'), findsOneWidget);
      expect(find.text('Featured Advisory Sessions'), findsOneWidget);
    });

    testWidgets('the pill reads the rounded count, "50+ Domains", beside both headings', (tester) async {
      final repo = _Repo(
        transform: (o) => MentorshipOverview(
          categories: o.categories,
          selectedCategory: o.selectedCategory,
          domainsBadge: domainsBadgeFor(58),
          companies: o.companies,
          shelves: o.shelves,
          topics: o.topics,
          banner: o.banner,
          cohort: o.cohort,
          services: o.services,
        ),
      );
      await _pumpLanding(tester, repo, _Calls());
      expect(find.text('50+ Domains'), findsNWidgets(2));
      expect(find.text('58 Domains'), findsNothing);
    });

    testWidgets('the company tiles are coloured by brand: JLL red, CBRE blue, the rest in ink', (tester) async {
      await _pumpLanding(tester, _Repo(), _Calls());
      Color? colourOf(String name) => tester.widget<Text>(find.text(name).first).style?.color;
      expect(colourOf('JLL'), MentorshipBrand.jll);
      expect(colourOf('CBRE'), MentorshipBrand.cbre);
      for (final other in ['Microsoft', 'Amazon', 'Google', 'Infosys']) {
        expect(colourOf(other), MentorshipBrand.ink, reason: other);
      }
    });

    testWidgets('the topics grid is three to a row, tinted as the design tints it', (tester) async {
      await _pumpLanding(tester, _Repo(), _Calls());
      Finder topic(String label) => find.descendant(of: find.byType(TopicGrid), matching: find.text(label)).first;
      // A row is a set of tiles at one height: compare the tiles, not their labels (a label of two lines at the
      // app's 12 sp sits higher in its tile than one of a single line).
      final tiles = find.descendant(of: find.byType(TopicGrid), matching: find.byType(InkWell));
      final rows = <double>{
        for (var i = 0; i < tester.widgetList(tiles).length; i++) tester.getTopLeft(tiles.at(i)).dy.roundToDouble(),
      };
      expect(rows.length, 3);
      expect(find.descendant(of: find.byType(TopicGrid), matching: find.byType(InkWell)), findsNWidgets(9));
      Color? colourOf(String label) => tester.widget<Text>(topic(label)).style?.color;
      expect(colourOf('Workplace Safety'), MentorshipColors.topicRed);
      expect(colourOf('Budgeting & Costing'), MentorshipColors.topicBlue);
    });

    testWidgets('"View More" is the slate grey of the design', (tester) async {
      await _pumpLanding(tester, _Repo(), _Calls());
      expect(tester.widget<Text>(find.text('View More').first).style?.color, MentorshipColors.viewMore);
    });
  });

  group('the landing: every control', () {
    testWidgets('the header search is a button that opens the global search, not Find Mentors', (tester) async {
      var opened = 0;
      AppActions.openSearch = (context, {query}) async => opened++;
      addTearDown(() => AppActions.openSearch = null);
      await _pumpLanding(tester, _Repo(), _Calls());
      expect(
        find.descendant(of: find.byKey(const ValueKey('home-search')), matching: find.byType(TextField)),
        findsNothing,
        reason: 'nothing is typed into the header: words are searched on the search screen',
      );
      await tester.tap(find.byKey(const ValueKey('home-search')));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(find.byType(FindMentorsScreen), findsNothing);
    });

    testWidgets('a category chip re-scopes the shelves, and the lit one again returns to the default', (tester) async {
      final repo = _Repo();
      final controller = await _pumpLanding(tester, repo, _Calls());
      expect(controller.selectedCategory, 'Operations & FM');

      await tester.tap(find.text('Sustainability & ESG').first);
      await tester.pumpAndSettle();
      expect(repo.overviews.last, 'Sustainability & ESG');
      expect(controller.selectedCategory, 'Sustainability & ESG');

      await tester.tap(find.text('Sustainability & ESG').first);
      await tester.pumpAndSettle();
      expect(repo.overviews.last, isNull);
      expect(controller.selectedCategory, 'Operations & FM');
    });

    testWidgets('a company tile opens Find Mentors on its chip in the lit domain, with the search box empty', (
      tester,
    ) async {
      final repo = _Repo();
      await _pumpLanding(tester, repo, _Calls());
      await tester.tap(find.text('Infosys'));
      await tester.pumpAndSettle();

      expect(find.byType(FindMentorsScreen), findsOneWidget);
      expect(find.text('Company: Infosys'), findsOneWidget);
      expect(_searchBox(tester).controller!.text, isEmpty);
      expect(repo.lastFilters.company, 'Infosys');
      expect(repo.lastFilters.category, 'Operations & FM'); // the chip lit on the landing
      expect(repo.lastFilters.search, isEmpty);
      expect(find.text('Filters (2)'), findsOneWidget);
      expect(find.text('2 matches'), findsOneWidget);
    });

    testWidgets('a company tile after another domain was lit opens in that domain', (tester) async {
      final repo = _Repo();
      final controller = await _pumpLanding(tester, repo, _Calls());
      await controller.selectCategory('Sustainability & ESG');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Infosys'));
      await tester.pumpAndSettle();
      expect(repo.lastFilters.category, 'Sustainability & ESG');
      expect(repo.lastFilters.company, 'Infosys');
    });

    testWidgets('a topic chip opens Find Mentors on that domain', (tester) async {
      final repo = _Repo();
      await _pumpLanding(tester, repo, _Calls());
      await tester.tap(find.text('Vendor Management'));
      await tester.pumpAndSettle();

      expect(find.byType(FindMentorsScreen), findsOneWidget);
      expect(repo.lastFilters.category, 'Vendor Management');
    });

    testWidgets('"View More" opens Find Mentors with the landing\'s selected category', (tester) async {
      final repo = _Repo();
      await _pumpLanding(tester, repo, _Calls());
      await tester.tap(find.text('View More').first);
      await tester.pumpAndSettle();

      expect(find.byType(FindMentorsScreen), findsOneWidget);
      expect(repo.lastFilters.category, 'Operations & FM');
      // The design's Find Mentors keeps the bottom bar, Mentorship lit.
      final bar = tester.widget<IcrBottomNav>(find.byType(IcrBottomNav).hitTestable());
      expect(bar.current, AppTab.mentorship);
    });

    testWidgets('the second "View More" does the same for the second grid', (tester) async {
      final repo = _Repo();
      final controller = await _pumpLanding(tester, repo, _Calls());
      await controller.selectCategory('Sustainability & ESG');
      await tester.pumpAndSettle();
      await tester.tap(find.text('View More').last);
      await tester.pumpAndSettle();
      expect(repo.lastFilters.category, 'Sustainability & ESG');
    });

    testWidgets('the Domains pill opens Find Mentors', (tester) async {
      final repo = _Repo();
      await _pumpLanding(tester, repo, _Calls());
      await tester.tap(find.text('8+ Domains').first);
      await tester.pumpAndSettle();
      expect(find.byType(FindMentorsScreen), findsOneWidget);
      expect(repo.lastFilters.category, 'Operations & FM');
    });

    testWidgets('a mentor card opens that mentor\'s profile', (tester) async {
      final calls = _Calls();
      await _pumpLanding(tester, _Repo(), calls);
      await tester.tap(find.text('Lisa Cheng').first);
      await tester.tap(find.text('James Rodriguez').last);
      expect(calls.mentors, ['lisa', 'james']);
    });

    testWidgets('"Apply as Mentor" opens the website\'s page for it', (tester) async {
      final calls = _Calls();
      await _pumpLanding(tester, _Repo(), calls);
      await tester.tap(find.text('Apply as Mentor'));
      expect(calls.sites, ['/become-a-mentor']);
    });

    testWidgets('the cohort card\'s button opens its programme', (tester) async {
      final calls = _Calls();
      await _pumpLanding(tester, _Repo(), calls);
      expect(find.text('UPCOMING COHORT'), findsOneWidget);
      await tester.tap(find.text('Know More'));
      expect(calls.sites, ['/mentorship/programmes']);
    });

    testWidgets('each advisory session\'s button opens its mentor, where the offering is', (tester) async {
      final calls = _Calls();
      await _pumpLanding(tester, _Repo(), calls);
      await tester.tap(find.text('Book Diagnostic (Free)'));
      await tester.tap(find.text('Book Session'));
      await tester.tap(find.text('Request Review'));
      expect(calls.mentors, ['rajesh', 'rajesh', 'rajesh']);
    });

    testWidgets('the bell opens the notifications on the website', (tester) async {
      final calls = _Calls();
      await _pumpLanding(tester, _Repo(), calls);
      await tester.tap(find.bySemanticsLabel(RegExp('Notifications')));
      expect(calls.sites, ['/notifications']);
    });

    testWidgets('pulling down reads the landing again', (tester) async {
      final repo = _Repo();
      await _pumpLanding(tester, repo, _Calls());
      expect(repo.overviews.length, 1);
      await _pullToRefresh(tester);
      expect(repo.overviews.length, 2);
    });

    testWidgets('a refused load says why, and "Try again" asks again', (tester) async {
      _tall(tester);
      final calls = _Calls();
      final repo = _FailingOnce();
      final mentorship = MentorshipController(repo);
      await tester.runAsync(mentorship.start);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ChangeNotifierProvider.value(
            value: mentorship,
            child: MentorshipScreen(
              onBack: () {},
              onOpenMentor: calls.openMentor,
              viewer: DemoFeedRepository.me,
              onAccount: () {},
              openSite: calls.openSite,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load mentors"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Top Mentors in Your Network'), findsNWidgets(2));
    });
  });

  group('Find Mentors: what it draws', () {
    testWidgets('the design\'s state: Operations & FM, "Filters (2)", "Exp: 10+ Yrs", "Showing 8 of 48"', (
      tester,
    ) async {
      final repo = _Repo();
      final calls = _Calls();
      _tall(tester, height: 2400);
      final controller = FindMentorsController(repo, category: 'Operations & FM', minExperience: 10);
      await tester.runAsync(controller.start);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: FindMentorsScreen(
            onBack: () {},
            onOpenMentor: calls.openMentor,
            category: 'Operations & FM',
            controller: controller,
            openSite: calls.openSite,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Find Mentors'), findsOneWidget);
      expect(find.text('48 matches'), findsOneWidget);
      expect(find.text('Filters (2)'), findsOneWidget);
      expect(find.text('Sort:'), findsOneWidget);
      expect(find.text('Top rated'), findsOneWidget);
      expect(find.text('Exp: 10+ Yrs'), findsOneWidget);
      expect(find.text('Showing 8 of 48 mentors in this category'), findsOneWidget);
      expect(find.text('Load more mentors'), findsOneWidget);
      expect(find.byType(MentorCard), findsNWidgets(8));
    });

    testWidgets('with no category on, the foot does not say "in this category"', (tester) async {
      await _pumpFind(tester, _Repo(), _Calls());
      expect(find.text('Showing 8 of 48 mentors'), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
    });

    testWidgets('opening on a domain far down the chips brings its chip into view', (tester) async {
      await _pumpFind(tester, _Repo(), _Calls(), category: 'Energy Management');
      final chip = tester.getRect(find.text('Energy Management'));
      expect(chip.left, greaterThanOrEqualTo(0));
      expect(chip.right, lessThanOrEqualTo(390));
      final lit = tester.widget<Text>(find.text('Energy Management'));
      expect(lit.style?.color, Colors.white); // the lit chip is the one on blue (the design sets both in semi-bold)
    });

    testWidgets('a company chip leads the filter row and is in view when Find Mentors opens', (tester) async {
      await _pumpFind(tester, _Repo(), _Calls(), category: 'Operations & FM', company: 'Infosys');
      final chip = tester.getRect(find.text('Company: Infosys'));
      expect(chip.left, greaterThanOrEqualTo(0));
      expect(chip.right, lessThanOrEqualTo(390));
      expect(chip.left, lessThan(tester.getRect(find.text('Filters (2)')).left));
    });

    testWidgets('a search with no answer says so, and "Clear filters" brings the list back', (tester) async {
      final repo = _Repo();
      await _pumpFind(tester, repo, _Calls());
      await _submit(tester, find.byType(TextField).first, 'zzz');
      expect(find.text('No mentors match'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('48 matches'), findsOneWidget);
      expect(repo.lastFilters.count, 0);
    });
  });

  group('Find Mentors: every control', () {
    testWidgets('Back leaves the screen', (tester) async {
      final calls = _Calls();
      await _pumpFind(tester, _Repo(), calls);
      await tester.tap(find.bySemanticsLabel('Back'));
      expect(calls.backs, 1);
    });

    testWidgets('the search box searches by the words typed', (tester) async {
      final repo = _Repo();
      await _pumpFind(tester, repo, _Calls());
      await _submit(tester, find.byType(TextField).first, 'lisa');
      expect(repo.lastFilters.search, 'lisa');
      expect(find.text('1 match'), findsOneWidget);
      expect(find.text('Lisa Cheng'), findsOneWidget);
    });

    testWidgets('the clear cross in the search box brings the whole list back', (tester) async {
      final repo = _Repo();
      await _pumpFind(tester, repo, _Calls(), search: 'lisa');
      expect(find.text('1 match'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(repo.lastFilters.search, isEmpty);
      expect(find.text('48 matches'), findsOneWidget);
    });

    testWidgets('a category chip narrows to that domain, and the lit chip again clears it', (tester) async {
      final repo = _Repo();
      await _pumpFind(tester, repo, _Calls());
      await tester.tap(find.text('Sustainability & ESG'));
      await tester.pumpAndSettle();
      expect(repo.lastFilters.category, 'Sustainability & ESG');
      expect(find.text('Filters (1)'), findsOneWidget);
      expect(find.text('Showing 8 of 48 mentors in this category'), findsOneWidget);

      await tester.tap(find.text('Sustainability & ESG'));
      await tester.pumpAndSettle();
      expect(repo.lastFilters.category, isNull);
      expect(find.text('Filters'), findsOneWidget);
    });

    testWidgets('the Filters sheet sets the minimum experience, which shows as a chip with a cross', (tester) async {
      final repo = _Repo();
      await _pumpFind(tester, repo, _Calls(), category: 'Operations & FM');
      expect(find.text('Filters (1)'), findsOneWidget);

      await tester.tap(find.text('Filters (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Experience'), findsOneWidget);
      await tester.tap(find.text('10+ years'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show mentors'));
      await tester.pumpAndSettle();

      expect(repo.lastFilters.minExperience, 10);
      expect(find.text('Exp: 10+ Yrs'), findsOneWidget);
      expect(find.text('Filters (2)'), findsOneWidget);
    });

    testWidgets('the cross on the Exp chip takes the filter off', (tester) async {
      final repo = _Repo();
      await _pumpFind(tester, repo, _Calls(), category: 'Operations & FM');
      await tester.tap(find.text('Filters (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5+ years'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show mentors'));
      await tester.pumpAndSettle();
      expect(find.text('Exp: 5+ Yrs'), findsOneWidget);

      await tester.tap(find.text('Exp: 5+ Yrs'));
      await tester.pumpAndSettle();
      expect(repo.lastFilters.minExperience, isNull);
      expect(find.textContaining('Exp:'), findsNothing);
      expect(find.text('Filters (1)'), findsOneWidget);
    });

    testWidgets('the free-slot switch in the sheet narrows to mentors with a slot, as a removable chip', (
      tester,
    ) async {
      final repo = _Repo();
      await _pumpFind(tester, repo, _Calls());
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show mentors'));
      await tester.pumpAndSettle();

      expect(repo.lastFilters.availableOnly, isTrue);
      expect(find.text('Free slot'), findsOneWidget);
      expect(find.text('Filters (1)'), findsOneWidget);

      await tester.tap(find.text('Free slot'));
      await tester.pumpAndSettle();
      expect(repo.lastFilters.availableOnly, isFalse);
    });

    testWidgets('"Clear all" in the sheet takes off every filter the chip counts', (tester) async {
      final repo = _Repo();
      await _pumpFind(tester, repo, _Calls(), category: 'Operations & FM', company: 'Infosys');
      expect(find.text('Filters (2)'), findsOneWidget);
      await tester.tap(find.text('Filters (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();
      expect(repo.lastFilters.count, 0);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Company: Infosys'), findsNothing);
    });

    testWidgets('the sort menu orders the directory by what is chosen', (tester) async {
      final repo = _Repo();
      await _pumpFind(tester, repo, _Calls());
      expect(find.text('Top rated'), findsOneWidget);
      await tester.tap(find.text('Top rated'));
      await tester.pumpAndSettle();
      for (final label in ['Most mentees helped', 'Most sessions', 'Most experienced', 'Newest']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await tester.tap(find.text('Most sessions'));
      await tester.pumpAndSettle();

      expect(repo.lastFilters.sort, MentorSort.sessionsCompleted);
      expect(find.text('Most sessions'), findsOneWidget); // the chip now says so
      expect(find.text('Top rated'), findsNothing);
    });

    testWidgets('the company chip stays out of the search box, and its cross takes it off', (tester) async {
      final repo = _Repo();
      await _pumpFind(tester, repo, _Calls(), company: 'Infosys');
      expect(find.text('Company: Infosys'), findsOneWidget);
      expect(_searchBox(tester).controller!.text, isEmpty);
      expect(find.text('2 matches'), findsOneWidget);

      await tester.tap(find.text('Company: Infosys'));
      await tester.pumpAndSettle();
      expect(repo.lastFilters.company, isNull);
      expect(find.text('Company: Infosys'), findsNothing);
      expect(find.text('48 matches'), findsOneWidget);
    });

    testWidgets('"Load more mentors" appends the next page and moves the bar on', (tester) async {
      final repo = _Repo();
      await _pumpFind(tester, repo, _Calls(), category: 'Operations & FM', height: 4600);
      expect(find.byType(MentorCard), findsNWidgets(8));

      await tester.tap(find.text('Load more mentors'));
      await tester.pumpAndSettle();
      expect(repo.searches.last.$2, 2); // page 2 of the directory
      expect(find.byType(MentorCard), findsNWidgets(16));
      expect(find.text('Showing 16 of 48 mentors in this category'), findsOneWidget);
    });

    testWidgets('a card opens that mentor\'s profile', (tester) async {
      final calls = _Calls();
      await _pumpFind(tester, _Repo(), calls);
      await tester.tap(find.text('David Kim'));
      expect(calls.mentors, ['david']);
    });

    testWidgets('the bell opens the notifications on the website', (tester) async {
      final calls = _Calls();
      await _pumpFind(tester, _Repo(), calls);
      await tester.tap(find.bySemanticsLabel(RegExp('Notifications')));
      expect(calls.sites, ['/notifications']);
    });

    testWidgets('pulling down reads the directory again', (tester) async {
      final repo = _Repo();
      await _pumpFind(tester, repo, _Calls());
      final before = repo.searches.length;
      await _pullToRefresh(tester);
      expect(repo.searches.length, before + 1);
      expect(repo.searches.last.$2, 1);
    });
  });
}

/// The demo source, except that saving fails.
class _Refusing implements MentorshipRepository {
  _Refusing(this.inner);

  final MentorshipRepository inner;

  @override
  Future<void> setSaved(Mentor mentor, bool saved) async => throw ApiError('No bookmarks today.');

  @override
  Future<MentorshipOverview> overview({String? category}) => inner.overview(category: category);
  @override
  Future<List<MentorCategory>> categories() => inner.categories();
  @override
  Future<MentorPage> search(MentorFilters filters, {int page = 1}) => inner.search(filters, page: page);
  @override
  Future<int> unreadNotifications() => inner.unreadNotifications();
  @override
  Uri link(Mentor mentor) => inner.link(mentor);
}

/// The demo source whose first landing read fails.
class _FailingOnce extends _Refusing {
  _FailingOnce() : super(DemoMentorshipRepository());

  var _failed = false;

  @override
  Future<MentorshipOverview> overview({String? category}) async {
    if (!_failed) {
      _failed = true;
      throw ApiError('The mentors are not answering.');
    }
    return super.overview(category: category);
  }
}
