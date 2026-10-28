/// The Regional Chapters screens against the LOCAL portal API (the association module's chapters and
/// the events API's RSVP): the app's own repository and controllers, the way the screens use them,
/// with the effect read back through the API.
///
/// Writes undo themselves. Bharat Buyer leads Bengaluru, New Jersey and belongs to Pune by design and
/// those seats are never touched: a test joins a chapter that is none of them and leaves it again, and
/// RSVPs to an event of such a chapter and cancels. (The API keeps a CANCELLED row after a cancel, so a
/// run leaves one such row per event it used; an RSVP after it re-enters the place.)
///
///     flutter test test/live/chapters_live_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/chapters/api_chapters_repository.dart';
import 'package:icr_mobile/features/chapters/chapter_controller.dart';
import 'package:icr_mobile/features/chapters/chapter_models.dart';
import 'package:icr_mobile/features/chapters/chapters_controller.dart';

import 'live.dart';

/// The seats Bharat holds by design: never joined, left or changed here.
const _designedSeats = {'bengaluru', 'pune', 'new-jersey'};

Future<ApiChaptersRepository> _repository([LivePerson who = bharat]) async =>
    ApiChaptersRepository(api: await liveClient(who));

Future<ChaptersController> _board([LivePerson who = bharat]) async {
  final controller = ChaptersController(await _repository(who));
  await controller.start();
  expect(controller.error, isNull, reason: 'the chapters should load from the local API');
  return controller;
}

Future<List<Map<String, dynamic>>> _rows(ApiClient api, String path, [Map<String, dynamic>? query]) async {
  final res = await api.dio.get<Map<String, dynamic>>(path, queryParameters: {'limit': 100, ...?query});
  return (res.data!['data'] as List).cast<Map<String, dynamic>>();
}

/// A chapter Bharat may join and leave: not one of his designed seats, and not his already.
ChapterSummary _spare(ChaptersController board) =>
    board.overview!.chapters.firstWhere((c) => !c.joined && !_designedSeats.contains(c.slug));

void main() {
  liveTest('the board is the API\'s: every published chapter, the numbers read from them, my seats by role', () async {
    final board = await _board();
    final api = await liveClient();
    final raw = await _rows(api, '/chapters');

    expect(board.overview!.chapters.map((c) => c.id).toSet(), raw.map((r) => r['id']).toSet());
    expect(board.stats!.chapters, raw.length);
    expect(board.stats!.members, raw.fold<int>(0, (n, r) => n + (r['memberCount'] as int)));
    expect(board.stats!.countries, {for (final r in raw) r['country']}.length);
    expect(board.stats!.upcomingEvents, raw.fold<int>(0, (n, r) => n + (r['upcomingEventCount'] as int)));

    // The seats the API says Bharat holds, with their roles (GET /chapters/memberships/mine).
    final mine = (await api.dio.get<List<dynamic>>('/chapters/memberships/mine')).data!.cast<Map<String, dynamic>>();
    expect(board.joined.map((c) => c.id).toSet(), mine.map((m) => m['chapterId']).toSet());
    for (final m in mine) {
      final c = board.find(m['chapterId'] as String)!;
      expect(c.role, ChapterRole.fromApi(m['role'] as String?), reason: c.name);
    }
    // A lead is listed before a member.
    final roles = board.joined.map((c) => c.role).toList();
    expect(roles, [...roles]..sort((a, b) => a == b ? 0 : (a == ChapterRole.lead ? -1 : 1)));
  });

  liveTest(
    'the board\'s meetups are the upcoming events a chapter hosts, soonest first, and each chapter\'s next date',
    () async {
      final board = await _board();
      final api = await liveClient();
      final raw = await _rows(api, '/events', {'when': 'upcoming'});
      final hosted = raw.where((e) => e['chapter'] is Map).toList();

      final all = board.overview!.meetups;
      expect(all.map((e) => e.id).toSet(), hosted.map((e) => e['id']).toSet());
      for (var i = 1; i < all.length; i++) {
        expect(all[i - 1].startsAt.isAfter(all[i].startsAt), isFalse);
      }
      expect(board.meetups.length, lessThanOrEqualTo(3));
      // A chapter's "Next:" is its soonest event.
      for (final c in board.overview!.chapters) {
        final own = all.where((e) => e.chapterSlug == c.slug).toList();
        expect(c.nextEventAt, own.isEmpty ? isNull : own.first.startsAt, reason: c.name);
      }
    },
  );

  liveTest('search, country, scope, region and city narrow the live directory, and clear', () async {
    final board = await _board();
    final total = board.chapters.length;
    expect(total, greaterThan(3));

    board.setSearch('mumbai');
    expect(board.chapters.map((c) => c.slug), contains('mumbai'));
    expect(board.chapters.length, lessThan(total));
    board.setSearch('');

    final country = board.countries.first;
    board.setCountry(country);
    expect(board.chapters.every((c) => c.country == country), isTrue);
    board.setCountry(null);

    board.setScope(ChapterScope.joined);
    expect(board.chapters.map((c) => c.id).toSet(), board.joined.map((c) => c.id).toSet());
    board.setScope(ChapterScope.nearby);
    expect(board.chapters.every((c) => !c.joined && board.recommendScore(c) > 0), isTrue);
    expect(board.chapters.length, board.scopeCount(ChapterScope.nearby));
    board.setScope(ChapterScope.all);

    // Maharashtra holds Pune (mine) and Mumbai; the region filter and then the city narrow to them.
    board.setRegion('Maharashtra');
    expect(board.chapters.map((c) => c.city).toSet(), containsAll({'Mumbai', 'Pune'}));
    board.setCity('Mumbai');
    expect(board.chapters.map((c) => c.slug), ['mumbai']);
    board.clearFilters();
    expect(board.chapters.length, total);
  });

  liveTest(
    'a chapter\'s page: about, committee, numbers, sponsors, gallery and the next events, as the API gives them',
    () async {
      final repo = await _repository();
      final api = await liveClient();
      final raw = (await api.dio.get<Map<String, dynamic>>('/chapters/bengaluru')).data!;
      final detail = await repo.detail('bengaluru');

      expect(detail.chapter.name, raw['name']);
      expect(detail.chapter.role, ChapterRole.lead, reason: 'Bharat leads Bengaluru');
      expect(detail.foundedYear, raw['foundedYear']);
      expect(detail.about, isNotEmpty);
      expect(detail.about.first.kind, AboutKind.heading);
      expect(detail.about.any((b) => b.kind == AboutKind.bullet), isTrue);
      expect(detail.stats.memberCount, (raw['stats'] as Map)['memberCount']);
      expect(detail.stats.leadershipCount, (raw['stats'] as Map)['leadershipCount']);
      expect(detail.leads.map((p) => p.id), (raw['leads'] as List).map((p) => (p as Map)['id']));
      expect(detail.leads.every((p) => p.role == ChapterRole.lead), isTrue);
      expect(detail.sponsors.length, (raw['sponsors'] as List).length);
      expect(detail.gallery.length, (raw['galleryUrls'] as List).length);
      expect(detail.upcomingEvents.map((e) => e.id), (raw['upcomingEvents'] as List).map((e) => (e as Map)['id']));
      expect(detail.upcomingEvents.every((e) => e.chapterSlug == 'bengaluru'), isTrue);

      // An id works where a slug does (a notification or a membership names the id).
      final byId = await repo.detail(raw['id'] as String);
      expect(byId.chapter.slug, 'bengaluru');
    },
  );

  liveTest('an unknown chapter is the API\'s own refusal', () async {
    final repo = await _repository();
    await expectLater(
      repo.detail('no-such-chapter'),
      throwsA(
        isA<ApiError>()
            .having((e) => e.statusCode, 'status', 404)
            .having((e) => e.message, 'message', 'Chapter not found'),
      ),
    );
  });

  liveTest('the roster pages, and its three filters and search are the API\'s', () async {
    final repo = await _repository();
    final api = await liveClient();
    final first = await repo.members('bengaluru');
    final rawAll = await api.dio.get<Map<String, dynamic>>(
      '/chapters/bengaluru/members',
      queryParameters: {'limit': 100},
    );
    final total = (rawAll.data!['meta'] as Map)['total'] as int;
    expect(first.total, total);
    expect(first.members.length, lessThanOrEqualTo(ApiChaptersRepository.membersPageSize));
    // Leads come first.
    expect(first.members.first.role, ChapterRole.lead);

    if (first.hasNext) {
      final second = await repo.members('bengaluru', page: 2);
      expect(second.page, 2);
      expect(second.members.map((p) => p.id).toSet().intersection(first.members.map((p) => p.id).toSet()), isEmpty);
    }

    final committee = await repo.members('bengaluru', filter: MemberFilter.committee);
    expect(committee.members.every((p) => p.role == ChapterRole.lead), isTrue);
    expect(committee.total, (await repo.detail('bengaluru')).stats.leadershipCount);

    final corporate = await repo.members('bengaluru', filter: MemberFilter.corporate);
    expect(corporate.members.every((p) => p.company != null), isTrue);
    expect(corporate.total, lessThanOrEqualTo(total));

    final named = await repo.members('bengaluru', search: 'Bharat');
    expect(named.members.map((p) => p.name), contains('Bharat Buyer'));
    expect((await repo.members('bengaluru', search: 'zzzznobody')).members, isEmpty);
  });

  liveTest('a chapter\'s events: upcoming and past are read, and the dispatches are pinned first', () async {
    final repo = await _repository();
    final upcoming = await repo.events('bengaluru');
    expect(upcoming, isNotEmpty);
    expect(upcoming.every((e) => e.chapterSlug == 'bengaluru'), isTrue);
    final past = await repo.events('bengaluru', past: true);
    expect(past.every((e) => e.startsAt.isBefore(DateTime.now())), isTrue);

    final updates = await repo.updates('bengaluru');
    expect(updates, isNotEmpty);
    final pinned = updates.takeWhile((u) => u.pinned).length;
    expect(updates.skip(pinned).every((u) => !u.pinned), isTrue, reason: 'pinned dispatches lead');

    final resources = await repo.resources('bengaluru');
    expect(resources, isNotEmpty);
    expect(resources.every((r) => r.url.startsWith('http')), isTrue);
  });

  liveTest('a chapter joined from the screen is a seat the API keeps, and leaving gives it back', () async {
    final board = await _board();
    final spare = _spare(board);
    final api = await liveClient();
    final before = spare.memberCount;

    expect(await board.join(spare), isNull);
    expect(board.find(spare.id)!.joined, isTrue);
    expect(board.find(spare.id)!.role, ChapterRole.member, reason: 'a join gives the member role, never lead');
    expect(board.find(spare.id)!.memberCount, before + 1);

    try {
      // Read back through the API: the seat is in my memberships and the count is the API's.
      final mine = (await api.dio.get<List<dynamic>>('/chapters/memberships/mine')).data!.cast<Map<String, dynamic>>();
      expect(mine.map((m) => m['chapterId']), contains(spare.id));
      final fresh = await _board();
      expect(fresh.find(spare.id)!.role, ChapterRole.member);
      expect(fresh.find(spare.id)!.memberCount, before + 1);
      expect(fresh.joined.map((c) => c.id), contains(spare.id));

      // The API's join is idempotent: a second one changes nothing.
      expect(await (await _repository()).join(spare), ChapterRole.member);
      expect((await _board()).find(spare.id)!.memberCount, before + 1);
    } finally {
      expect(await board.leave(board.find(spare.id)!), isNull);
    }
    expect(board.find(spare.id)!.joined, isFalse);
    final after = await _board();
    expect(after.find(spare.id)!.joined, isFalse);
    expect(after.find(spare.id)!.memberCount, before);
  });

  liveTest('joining a chapter I already lead keeps the lead role (the API\'s rule: a join never demotes)', () async {
    final repo = await _repository();
    final board = await _board();
    final blr = board.joined.firstWhere((c) => c.slug == 'bengaluru');
    expect(blr.role, ChapterRole.lead);
    expect(await repo.join(blr), ChapterRole.lead);
    expect((await _board()).find(blr.id)!.role, ChapterRole.lead);
  });

  liveTest('a join with no session is refused by the API and the card goes back', () async {
    final signedOut = ApiChaptersRepository(api: liveAnonymous());
    final board = ChaptersController(signedOut);
    await board.start();
    expect(board.overview!.chapters.every((c) => !c.joined), isTrue, reason: 'signed out, nothing is joined');
    final target = board.overview!.chapters.first;
    final message = await board.join(target);
    expect(message, isNotNull);
    expect(board.find(target.id)!.joined, isFalse);
    expect(board.find(target.id)!.memberCount, target.memberCount);
  });

  liveTest('an RSVP from a chapter\'s page is a place the events API keeps, and Cancel gives it back', () async {
    final repo = await _repository();
    final board = await _board();
    // An upcoming event of a chapter that is none of the designed seats' own RSVPs, free and not invite-only.
    final candidates = <ChapterEvent>[];
    for (final c in board.overview!.chapters) {
      if (c.upcomingEventCount == 0) continue;
      for (final e in await repo.events(c.slug)) {
        if (!e.holding && !e.ticketed && !e.inviteOnly && !e.full) candidates.add(e);
      }
    }
    if (candidates.isEmpty) {
      markTestSkipped('no free upcoming chapter event to RSVP to');
      return;
    }
    final event = candidates.first;
    final slug = event.chapterSlug!;
    final page = ChapterController(repository: repo, idOrSlug: slug);
    await page.start();
    final shown = page.events.items.firstWhere((e) => e.id == event.id);
    final seats = shown.attendeeCount;

    expect(await page.rsvp(shown), isNull);
    try {
      final going = page.events.items.firstWhere((e) => e.id == event.id);
      expect(going.myStatus, 'GOING');
      expect(going.attendeeCount, seats + 1);

      // Read back through the events API: the RSVP is mine and the count is the API's.
      final api = await liveClient();
      final rsvps = (await api.dio.get<List<dynamic>>('/events/rsvps/mine')).data!.cast<Map<String, dynamic>>();
      expect(rsvps.firstWhere((r) => r['eventId'] == event.id)['status'], 'GOING');
      final reread = (await repo.events(slug)).firstWhere((e) => e.id == event.id);
      expect(reread.myStatus, 'GOING');
      expect(reread.attendeeCount, seats + 1);

      // A second RSVP is the API's idempotent no-op.
      expect(await repo.rsvp(reread), 'GOING');
    } finally {
      expect(await page.cancelRsvp(page.events.items.firstWhere((e) => e.id == event.id)), isNull);
    }
    final after = (await repo.events(slug)).firstWhere((e) => e.id == event.id);
    expect(after.myStatus, isNull, reason: 'a CANCELLED row is no RSVP');
    expect(after.holding, isFalse);
    expect(after.attendeeCount, seats);
  });

  liveTest('an RSVP with no session is refused and the row goes back', () async {
    final repo = await _repository();
    final board = await _board();
    final c = board.overview!.chapters.firstWhere((c) => c.upcomingEventCount > 0);
    final event = (await repo.events(c.slug)).firstWhere((e) => !e.holding);
    final page = ChapterController(
      repository: ApiChaptersRepository(api: liveAnonymous()),
      idOrSlug: c.slug,
    );
    await page.start();
    final shown = page.events.items.firstWhere((e) => e.id == event.id);
    final message = await page.rsvp(shown);
    expect(message, isNotNull);
    expect(page.events.items.firstWhere((e) => e.id == event.id).myStatus, isNull);
    expect(page.events.items.firstWhere((e) => e.id == event.id).attendeeCount, shown.attendeeCount);
  });

  liveTest('the bell is the member\'s unread notifications, and the page link is the website\'s', () async {
    final repo = await _repository();
    final api = await liveClient();
    final raw = await api.dio.get<Map<String, dynamic>>('/notifications/unread-count');
    expect(await repo.unreadNotifications(), (raw.data!['unread'] as num).toInt());
    final board = await _board();
    expect(repo.link(board.overview!.chapters.first).path, '/chapters/${board.overview!.chapters.first.slug}');
  });
}
