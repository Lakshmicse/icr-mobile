/// The Mentorship landing and Find Mentors against the LOCAL portal API, signed
/// in as Bharat Buyer, through the screens' own repository and controllers.
///
/// They read what `tool/seed/mentorship.ts` put in the database (the design's
/// eight mentors, 48 matches for Operations & FM with 10+ years, the cohort, the
/// storefront) and prove each control reaches the API and changes what comes
/// back. What they write (a saved mentor, a follow) they take back in a
/// `finally`, so they can run again; nothing here creates a row that stays.
///
///     flutter test test/live/mentorship_live_test.dart
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/features/mentorship/api_mentorship_repository.dart';
import 'package:icr_mobile/features/mentorship/mentorship_controller.dart';
import 'package:icr_mobile/features/mentorship/mentorship_format.dart';
import 'package:icr_mobile/features/mentorship/mentorship_models.dart';

import 'live.dart';

const _design = [
  'Rajesh Sharma',
  'Rajesh Sharma',
  'Lisa Cheng',
  'David Kim',
  'Sophia Patel',
  'Michael Johnson',
  'Emma Thompson',
  'James Rodriguez',
];

/// One sign-in for the whole file: the API throttles `POST /auth/login`, and
/// every test signs in as the same person.
Future<ApiClient>? _signedIn;
Future<ApiClient> _client() => _signedIn ??= _signIn();

/// The API lets one address make 120 requests a minute and the landing alone
/// reads a dozen per load (with other people's tests sharing the address), so a
/// request it turns away with 429 waits out the window it names and goes again,
/// rather than the test reading a throttled empty answer as the app's own.
Future<ApiClient> _signIn() async {
  late ApiClient api;
  for (var attempt = 0; ; attempt++) {
    try {
      api = await liveClient();
      break;
    } on DioException catch (e) {
      if (e.response?.statusCode != 429 || attempt >= 4) rethrow;
      await Future<void>.delayed(const Duration(seconds: 20));
    }
  }
  api.dio.interceptors.add(
    InterceptorsWrapper(
      onError: (e, handler) async {
        final tries = e.requestOptions.extra['throttleRetries'] as int? ?? 0;
        if (e.response?.statusCode != 429 || tries >= 4) return handler.next(e);
        final reset = int.tryParse(e.response?.headers.value('x-ratelimit-reset') ?? '') ?? 20;
        await Future<void>.delayed(Duration(seconds: reset.clamp(1, 60) + 1));
        e.requestOptions.extra['throttleRetries'] = tries + 1;
        try {
          handler.resolve(await api.dio.fetch<dynamic>(e.requestOptions));
        } on DioException catch (again) {
          handler.next(again);
        }
      },
    ),
  );
  return api;
}

Future<Map<String, dynamic>> _get(ApiClient api, String path, [Map<String, dynamic>? query]) async {
  final res = await api.dio.get<Map<String, dynamic>>(path, queryParameters: query);
  return res.data!;
}

/// The raw directory page the repository would read for [filters].
Future<List<Map<String, dynamic>>> _rawPage(ApiClient api, MentorFilters filters, {int page = 1}) async {
  final res = await _get(api, '/mentorship/mentors', ApiMentorshipRepository.directoryQuery(filters, page: page));
  return (res['data'] as List).cast<Map<String, dynamic>>();
}

/// One column of the raw rows. [skipNull] leaves out rows that have none: the
/// directory orders a mentor with no years of experience FIRST under
/// `sortBy=yearsExperience&sortDir=desc` (Postgres puts NULL first on a
/// descending sort), so the order is only meaningful among the rows that have one.
List<num> _numbers(List<Map<String, dynamic>> rows, String key, {bool skipNull = false}) => [
  for (final r in rows)
    if (!skipNull || r[key] != null) (r[key] as num?) ?? 0,
];

void _expectNonIncreasing(List<num> values, String reason) {
  for (var i = 1; i < values.length; i++) {
    expect(values[i], lessThanOrEqualTo(values[i - 1]), reason: '$reason at $i: $values');
  }
}

/// What Bharat has saved and follows, so the last test can show the file left it as it found it.
Future<(Set<String>, Set<String>)> _ties(ApiClient api) async {
  final saved = (await _get(api, '/mentorship/mentors/saved/ids'))['ids'] as List;
  final following = (await _get(api, '/members/me/following', {'limit': 100}))['data'] as List;
  return ({...saved.cast<String>()}, {for (final f in following) (f as Map)['id'] as String});
}

void main() {
  (Set<String>, Set<String>)? atStart;

  setUpAll(() async {
    if (await liveApiReachable()) atStart = await _ties(await _client());
  });

  group('the Mentorship landing, live', () {
    liveTest('reads like the design: chips, pill, both grids, tiles, topics, banner, cohort and sessions', () async {
      final api = await _client();
      final repo = ApiMentorshipRepository(api: api);
      final o = await repo.overview();
      final domains = (await repo.categories()).length;

      // The category chips: the most-listed domains, the biggest lit.
      expect(o.categories.length, 8);
      expect(o.categories.first.label, 'Operations & FM');
      expect(o.selectedCategory, 'Operations & FM');

      // "8+ Domains": the real count, rounded down with a plus, never up.
      expect(o.domainsBadge, domainsBadgeFor(domains));
      expect(o.domainsBadge, matches(RegExp(r'^\d+\+ Domains$')));
      expect(int.parse(o.domainsBadge.split('+').first), lessThanOrEqualTo(domains));

      // Both grids carry the design's title; the first is the design's eight in
      // the design's order (Bharat has no saved or followed mentors, and no company).
      expect(o.shelves.map((s) => s.title), [mentorNetworkTitle, mentorNetworkTitle]);
      expect(o.shelves.first.mentors.map((m) => m.name), _design);
      expect(o.shelves.last.mentors, isNotEmpty);
      final firstIds = o.shelves.first.mentors.map((m) => m.id).toSet();
      expect(
        o.shelves.last.mentors.any((m) => firstIds.contains(m.id)),
        isFalse,
        reason: 'the second grid repeats no face',
      );
      expect(o.shelves.first.mentors.first.role, 'VP Facility Ops @ Infosys');
      expect(o.shelves.first.mentors.first.expertise.take(3), ['Smart Campuses', 'Smart Campuses', 'BMS']);

      // "Learn from top leaders at top enterprises".
      expect(o.companies.take(4).map((c) => c.name), ['Microsoft', 'Amazon', 'JLL', 'CBRE']);
      expect(o.companies.map((c) => c.name), containsAll(['Google', 'Infosys']));
      expect(o.companies.length, 8);

      // "Learn from top topics": nine, three to a row, red for the selected (the
      // top two while Bharat has no focus areas), blue for the suggested.
      expect(o.topics.length, 9);
      expect(o.topics.first.label, 'Space Optimization');
      expect(o.topics.map((t) => t.tone).take(4), [TopicTone.red, TopicTone.red, TopicTone.blue, TopicTone.blue]);

      // The banner: the design's sentence with the real count rounded down.
      final stats = await _get(api, '/mentorship/public-stats');
      final listed = (stats['listedMentors'] as num).toInt();
      expect(
        o.banner!.body,
        'Join ${plusCount(listed)} senior leaders guiding emerging facility managers and '
        'corporate real estate professionals.',
      );
      expect(o.banner!.photo?.asset, mentorBannerPhoto.asset);
      expect(o.banner!.link, '/become-a-mentor');

      // The cohort card.
      expect(o.cohort!.name, 'FM Leadership & ESG Masterclass');
      expect(o.cohort!.registeredLabel, matches(RegExp(r'^\d+ Registered$')));
      expect(o.cohort!.avatars.first.initials, 'RK');
      expect(o.cohort!.avatars.last.initials, matches(RegExp(r'^\+\d+$')));
      expect(o.cohort!.cover?.url, isNotNull);
      expect(o.cohort!.link, '/mentorship/programmes/fm-leadership-esg-masterclass');

      // "Featured Advisory Sessions": Rajesh's first three offerings, the first featured.
      expect(o.services.length, 3);
      expect(o.services.map((s) => s.pill), [
        '1:1 Session • 30 Mins • Free',
        '1:1 Session • 45 Mins • ₹1,499',
        'Resource • Free', // the design's "Async Query" type is retired by the API
      ]);
      expect(o.services.map((s) => s.buttonLabel), ['Book Session (Free)', 'Book Session', 'Get Resource (Free)']);
      expect(o.services.map((s) => s.featured), [true, false, false]);
      expect(o.services.map((s) => s.mentorId).toSet(), {o.shelves.first.mentors.first.id});
    });

    liveTest('a category chip re-scopes both grids, live, and the lit chip again goes back', () async {
      final controller = MentorshipController(ApiMentorshipRepository(api: await _client()));
      await controller.start();
      expect(controller.selectedCategory, 'Operations & FM');

      await controller.selectCategory('Sustainability & ESG');
      expect(controller.selectedCategory, 'Sustainability & ESG');
      final mentors = [for (final s in controller.overview!.shelves) ...s.mentors];
      expect(mentors, isNotEmpty);
      expect(
        mentors.every((m) => m.expertise.contains('Sustainability & ESG')),
        isTrue,
        reason: 'every card in the re-scoped grids is a Sustainability & ESG mentor',
      );

      await controller.selectCategory('Sustainability & ESG');
      expect(controller.selectedCategory, 'Operations & FM');
      expect(controller.overview!.shelves.first.mentors.map((m) => m.name), _design);
    });

    liveTest('pulling down reads the landing again and gets the same answer', () async {
      final controller = MentorshipController(ApiMentorshipRepository(api: await _client()));
      await controller.start();
      final before = controller.overview!.shelves.first.mentors.map((m) => m.id).toList();
      await controller.refresh();
      expect(controller.error, isNull);
      expect(controller.overview!.shelves.first.mentors.map((m) => m.id), before);
      expect(controller.unread, greaterThanOrEqualTo(0));
    });

    liveTest('the bell\'s number is the API\'s unread count', () async {
      final api = await _client();
      final repo = ApiMentorshipRepository(api: api);
      final raw = await _get(api, '/notifications/unread-count');
      expect(await repo.unreadNotifications(), (raw['unread'] as num).toInt());
    });

    liveTest(
      'every card opens a mentor that exists, and the cohort and session buttons land on real records',
      () async {
        final api = await _client();
        final o = await ApiMentorshipRepository(api: api).overview();
        for (final mentor in o.shelves.first.mentors.take(3)) {
          final profile = await _get(api, '/mentorship/mentors/${mentor.id}');
          final user = profile['user'] as Map<String, dynamic>;
          expect('${user['firstName']} ${user['lastName']}', mentor.name);
        }
        // "Know More" opens the programme's website page; the programme is there.
        final programme = await _get(api, '/mentorship/programmes/${o.cohort!.slug}');
        expect(programme['name'], o.cohort!.name);
        // A session card opens its mentor, whose storefront is live and lists the offering.
        final storefront = await _get(api, '/mentor-services/mentors/${o.services.first.mentorId}');
        expect(storefront['live'], isTrue);
        expect((storefront['services'] as List).map((s) => (s as Map)['id']), contains(o.services.first.id));
      },
    );
  });

  group('"Top Mentors in Your Network", live', () {
    liveTest('a saved mentor leads the first grid, and taking the bookmark back puts the grid as it was', () async {
      final api = await _client();
      final repo = ApiMentorshipRepository(api: api);
      final before = (await repo.overview()).shelves.first.mentors.map((m) => m.id).toList();

      // Someone well down the Operations & FM list, so saving them visibly moves them up.
      final page2 = await repo.search(const MentorFilters(category: 'Operations & FM'), page: 2);
      final pick = page2.mentors.firstWhere((m) => !before.contains(m.id));

      await repo.setSaved(pick, true);
      try {
        final saved = await _get(api, '/mentorship/mentors/saved/ids');
        expect(saved['ids'], contains(pick.id));
        final grid = (await repo.overview()).shelves.first.mentors;
        expect(grid.first.id, pick.id, reason: 'a saved mentor is in the viewer\'s network');
        expect(grid.first.saved, isTrue);
        expect(grid.length, 8);
      } finally {
        await repo.setSaved(pick, false);
      }
      final saved = await _get(api, '/mentorship/mentors/saved/ids');
      expect(saved['ids'], isNot(contains(pick.id)));
      expect((await repo.overview()).shelves.first.mentors.map((m) => m.id), before);
    });

    liveTest('a followed mentor leads the first grid too, and unfollowing takes them back', () async {
      final api = await _client();
      final repo = ApiMentorshipRepository(api: api);
      final before = (await repo.overview()).shelves.first.mentors.map((m) => m.id).toList();
      final page2 = await repo.search(const MentorFilters(category: 'Operations & FM'), page: 2);
      final pick = page2.mentors.firstWhere((m) => !before.contains(m.id) && m.userId != null);

      Future<void> unfollow() async {
        try {
          await api.dio.delete<dynamic>('/members/${pick.userId}/follow');
        } on DioException {
          // Not following, nothing to take back.
        }
      }

      await api.dio.post<dynamic>('/members/${pick.userId}/follow');
      try {
        final grid = (await ApiMentorshipRepository(api: api).overview()).shelves.first.mentors;
        expect(grid.first.id, pick.id, reason: 'a followed mentor is in the viewer\'s network');
      } finally {
        await unfollow();
      }
      expect((await ApiMentorshipRepository(api: api).overview()).shelves.first.mentors.map((m) => m.id), before);
    });

    liveTest('the optimistic save through the controller reaches the API and rolls back with it', () async {
      final api = await _client();
      final controller = MentorshipController(ApiMentorshipRepository(api: api));
      await controller.start();
      final mentor = controller.overview!.shelves.first.mentors.first;
      expect(mentor.saved, isFalse);

      expect(await controller.toggleSave(mentor), isNull);
      try {
        expect(controller.find(mentor.id)!.saved, isTrue);
        expect((await _get(api, '/mentorship/mentors/saved/ids'))['ids'], contains(mentor.id));
      } finally {
        expect(await controller.toggleSave(controller.find(mentor.id)!), isNull);
      }
      expect(controller.find(mentor.id)!.saved, isFalse);
      expect((await _get(api, '/mentorship/mentors/saved/ids'))['ids'], isNot(contains(mentor.id)));
    });
  });

  group('Find Mentors, live', () {
    liveTest('the design\'s state: Operations & FM and 10+ years is 48 matches, "Filters (2)", eight cards', () async {
      final find = FindMentorsController(
        ApiMentorshipRepository(api: await _client()),
        category: 'Operations & FM',
        minExperience: 10,
      );
      await find.start();
      expect(find.filters.count, 2);
      expect(find.total, 48);
      expect(find.mentors.map((m) => m.name), _design);
      expect(find.hasMore, isTrue);
      expect(find.categories.first.label, 'Operations & FM');
    });

    liveTest('the search box finds a mentor by name, and clearing it brings every mentor back', () async {
      final find = FindMentorsController(ApiMentorshipRepository(api: await _client()));
      await find.start();
      final everyone = find.total;
      expect(everyone, greaterThanOrEqualTo(64));

      await find.setSearch('Srikanth');
      expect(find.total, 1);
      expect(find.mentors.single.name, 'Srikanth Sriramagiri');
      await find.setSearch('lisa');
      expect(find.mentors.map((m) => m.name), contains('Lisa Cheng'));

      await find.setSearch('');
      expect(find.total, everyone);
    });

    liveTest('a category chip narrows to that domain; the same chip again clears it', () async {
      final find = FindMentorsController(ApiMentorshipRepository(api: await _client()));
      await find.start();
      final everyone = find.total;
      await find.setCategory('Sustainability & ESG');
      expect(find.total, lessThan(everyone));
      expect(find.mentors.every((m) => m.expertise.contains('Sustainability & ESG')), isTrue);
      expect(find.total, find.categories.firstWhere((c) => c.label == 'Sustainability & ESG').count);
      await find.setCategory('Sustainability & ESG');
      expect(find.total, everyone);
    });

    liveTest('a topic chip from the landing is a domain the directory filters on, with the facet\'s count', () async {
      final api = await _client();
      final repo = ApiMentorshipRepository(api: api);
      final o = await repo.overview();
      final facets = await repo.categories();
      for (final topic in o.topics.take(3)) {
        final find = FindMentorsController(repo, category: topic.label);
        await find.start();
        expect(find.total, facets.firstWhere((c) => c.label == topic.label).count, reason: topic.label);
        expect(find.mentors.every((m) => m.expertise.contains(topic.label)), isTrue, reason: topic.label);
      }
    });

    liveTest('a company tile narrows to that employer behind its chip, with the search box empty', () async {
      final api = await _client();
      final repo = ApiMentorshipRepository(api: api);
      final tile = (await repo.overview()).companies.firstWhere((c) => c.name == 'SpaceX');
      // The seeded employers are on the mentors' current roles, not on their ICR accounts.
      expect(tile.onAccount, isFalse);

      final find = FindMentorsController(repo, company: tile.name, companyOnAccount: tile.onAccount);
      await find.start();
      expect(find.filters.search, isEmpty);
      expect(find.filters.company, 'SpaceX');
      expect(find.total, tile.mentors);
      expect(find.mentors.every((m) => m.roleLine.endsWith('@ SpaceX')), isTrue);

      // The chip's cross takes it off.
      await find.clearCompany();
      expect(find.filters.company, isNull);
      expect(find.total, greaterThan(tile.mentors));
    });

    liveTest('a company on mentors\' accounts goes to the directory\'s own `companies` filter', () async {
      final repo = ApiMentorshipRepository(api: await _client());
      // No seeded mentor has a company on their account, so the filter is honoured by being empty.
      final page = await repo.search(const MentorFilters(company: 'SpaceX', companyOnAccount: true));
      expect(page.total, 0);
      expect(page.mentors, isEmpty);
    });

    liveTest(
      'the minimum-experience filter keeps only mentors with that many years, and narrows as it rises',
      () async {
        final repo = ApiMentorshipRepository(api: await _client());
        var previous = 1 << 30;
        for (final years in [5, 10, 15]) {
          final page = await repo.search(MentorFilters(minExperience: years));
          expect(page.mentors, isNotEmpty);
          expect(page.mentors.every((m) => (m.yearsExperience ?? 0) >= years), isTrue, reason: '$years+ years');
          expect(page.total, lessThanOrEqualTo(previous), reason: '$years+ years');
          previous = page.total;
        }
      },
    );

    liveTest('the free-slot switch asks for mentors with an open slot', () async {
      final api = await _client();
      const filters = MentorFilters(availableOnly: true);
      final rows = await _rawPage(api, filters);
      expect(rows, isNotEmpty);
      expect(rows.every((r) => (r['openSlots'] as num) > 0), isTrue);
      final page = await ApiMentorshipRepository(api: api).search(filters);
      expect(page.mentors.map((m) => m.id), rows.map((r) => r['id']));
    });

    liveTest('every sort reaches the API and the cards come back in that order', () async {
      final api = await _client();
      final repo = ApiMentorshipRepository(api: api);
      for (final sort in MentorSort.values) {
        final filters = MentorFilters(sort: sort);
        final rows = await _rawPage(api, filters);
        final page = await repo.search(filters);
        expect(page.mentors.map((m) => m.id), rows.map((r) => r['id']), reason: sort.name);
        switch (sort) {
          case MentorSort.rating:
            _expectNonIncreasing(_numbers(rows, 'rating'), sort.name);
          case MentorSort.menteesHelped:
            _expectNonIncreasing(_numbers(rows, 'menteesHelped'), sort.name);
          case MentorSort.sessionsCompleted:
            _expectNonIncreasing(_numbers(rows, 'sessionsCompleted'), sort.name);
          case MentorSort.yearsExperience:
            _expectNonIncreasing(_numbers(rows, 'yearsExperience', skipNull: true), sort.name);
          case MentorSort.createdAt:
            _expectNonIncreasing([
              for (final r in rows) DateTime.parse(r['createdAt'] as String).millisecondsSinceEpoch,
            ], sort.name);
        }
      }
      // And the choice really changes the list: the most-sessions leader is not the top rated.
      final byRating = await repo.search(const MentorFilters());
      final bySessions = await repo.search(const MentorFilters(sort: MentorSort.sessionsCompleted));
      expect(bySessions.mentors.first.id, isNot(byRating.mentors.first.id));
    });

    liveTest('"Load more mentors" reads the real next page, and the pages add up to the total', () async {
      final find = FindMentorsController(ApiMentorshipRepository(api: await _client()), category: 'Operations & FM');
      await find.start();
      expect(find.mentors.length, 8);
      expect(find.total, 48);

      await find.loadMore();
      expect(find.mentors.length, 16);
      expect(find.mentors.map((m) => m.id).toSet().length, 16, reason: 'page 2 holds new faces');
      expect(find.hasMore, isTrue);

      while (find.hasMore) {
        await find.loadMore();
      }
      expect(find.mentors.length, find.total);
      expect(find.mentors.map((m) => m.id).toSet().length, find.total);
    });

    liveTest('a filter changed after "Load more" starts the list again from page one', () async {
      final find = FindMentorsController(ApiMentorshipRepository(api: await _client()), category: 'Operations & FM');
      await find.start();
      await find.loadMore();
      expect(find.mentors.length, 16);
      await find.setMinExperience(15);
      expect(find.mentors.length, lessThanOrEqualTo(8));
      expect(find.mentors.every((m) => (m.yearsExperience ?? 0) >= 15), isTrue);
      await find.setMinExperience(null);
      expect(find.mentors.length, 8);
    });

    liveTest('pulling down reads the directory again and keeps the filters', () async {
      final find = FindMentorsController(
        ApiMentorshipRepository(api: await _client()),
        category: 'Operations & FM',
        minExperience: 10,
      );
      await find.start();
      final before = find.mentors.map((m) => m.id).toList();
      await find.refresh();
      expect(find.error, isNull);
      expect(find.mentors.map((m) => m.id), before);
      expect(find.total, 48);
    });

    liveTest('the Filters sheet\'s "Clear all" state is the whole directory', () async {
      final find = FindMentorsController(
        ApiMentorshipRepository(api: await _client()),
        category: 'Operations & FM',
        company: 'SpaceX',
        minExperience: 10,
      );
      await find.start();
      expect(find.filters.count, 3);
      final narrowed = find.total;
      await find.setFilters(MentorFilters(sort: find.filters.sort));
      expect(find.filters.count, 0);
      expect(find.total, greaterThan(narrowed));
      expect(find.total, greaterThanOrEqualTo(64));
    });

    liveTest('and the tests left what Bharat saves and follows exactly as they found it', () async {
      final now = await _ties(await _client());
      expect(now.$1, atStart!.$1, reason: 'saved mentors');
      expect(now.$2, atStart!.$2, reason: 'followed members');
    });
  });
}
