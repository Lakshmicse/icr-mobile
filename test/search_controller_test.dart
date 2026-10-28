import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/search/recent_searches.dart';
import 'package:icr_mobile/features/search/search_controller.dart';
import 'package:icr_mobile/features/search/search_models.dart';

/// A source that answers from a table, counts what it is asked, and can be held
/// open or made to fail.
class FakeSource extends SearchSource {
  FakeSource(this.kind, {this.answers = const {}, this.pageSize = 2, this.pageable = false});

  @override
  final SearchKind kind;
  final Map<String, List<String>> answers;
  final int pageSize;
  final bool pageable;

  final calls = <String>[];
  final pagesAsked = <int>[];
  Completer<void>? hold;
  Object? failure;

  @override
  bool get pages => pageable;

  @override
  Future<SourcePage> search(String query, {int page = 1}) async {
    calls.add(query);
    pagesAsked.add(page);
    final gate = hold;
    if (gate != null) await gate.future;
    final error = failure;
    if (error != null) throw error;
    final titles = answers[query] ?? const [];
    final start = (page - 1) * pageSize;
    final slice = titles.skip(start).take(pageSize).toList();
    return SourcePage([
      for (final t in slice) SearchHit(kind: kind, id: '${kind.name}-$t', title: t),
    ], hasMore: pageable && start + pageSize < titles.length);
  }
}

const _quick = Duration(milliseconds: 10);

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 60));

GlobalSearchController build(List<SearchSource> sources, {Set<String>? features, RecentSearches? recents}) =>
    GlobalSearchController(sources: sources, availableFeatures: features, recents: recents, debounce: _quick);

void main() {
  group('asking the sources', () {
    test('nothing is asked below two characters, but features match from one', () async {
      final people = FakeSource(SearchKind.person, answers: {'m': ['Meera']});
      final c = build([people], features: {'jobs', 'mentorship'});
      c.setQuery('m');
      await settle();
      expect(people.calls, isEmpty);
      expect(c.asks, isFalse);
      expect(c.featureMatches, isNotEmpty);
    });

    test('every source is asked once, in parallel, for a long enough query', () async {
      final sources = [
        FakeSource(SearchKind.person, answers: {'meera': ['Meera Iyer']}),
        FakeSource(SearchKind.job, answers: {'meera': ['Recruiter']}),
        FakeSource(SearchKind.event, answers: {'meera': []}),
      ];
      final c = build(sources);
      c.setQuery('meera');
      await settle();
      for (final s in sources) {
        expect(s.calls, ['meera']);
      }
      expect(c.groupOf(SearchKind.person).hits.single.title, 'Meera Iyer');
      expect(c.groupOf(SearchKind.event).status, GroupStatus.done);
      expect(c.anyLoading, isFalse);
    });

    test('typing in a burst asks once, for the last text', () async {
      final jobs = FakeSource(SearchKind.job, answers: {'mentor': ['Mentor Lead']});
      final c = build([jobs]);
      c
        ..setQuery('me')
        ..setQuery('men')
        ..setQuery('ment')
        ..setQuery('mentor');
      await settle();
      expect(jobs.calls, ['mentor']);
      expect(c.groupOf(SearchKind.job).hits.single.title, 'Mentor Lead');
    });

    test('the query is trimmed, and the same text again asks nothing', () async {
      final jobs = FakeSource(SearchKind.job, answers: {'plan': ['Planner']});
      final c = build([jobs]);
      c.setQuery('  plan ');
      await settle();
      c.setQuery('  plan ');
      c.submit();
      await settle();
      expect(jobs.calls, ['plan']);
    });

    test('shortening the text below two characters clears the results', () async {
      final jobs = FakeSource(SearchKind.job, answers: {'plan': ['Planner']});
      final c = build([jobs]);
      c.setQuery('plan');
      await settle();
      expect(c.groupOf(SearchKind.job).hits, isNotEmpty);
      c.setQuery('p');
      expect(c.groupOf(SearchKind.job).hits, isEmpty);
      expect(c.groupOf(SearchKind.job).status, GroupStatus.idle);
    });
  });

  group('stale and failing answers', () {
    test('an answer for an older query is dropped', () async {
      final jobs = FakeSource(SearchKind.job, answers: {'old': ['Old Job'], 'new': ['New Job']});
      final c = build([jobs]);
      jobs.hold = Completer<void>();
      c.setQuery('old');
      await settle();
      final firstGate = jobs.hold!;
      jobs.hold = null;
      c.setQuery('new');
      await settle();
      expect(c.groupOf(SearchKind.job).hits.single.title, 'New Job');
      firstGate.complete();
      await settle();
      expect(c.groupOf(SearchKind.job).hits.single.title, 'New Job', reason: 'the slow old answer must not replace it');
    });

    test('one source failing shows nothing for it and leaves the rest', () async {
      final people = FakeSource(SearchKind.person, answers: {'abc': ['Abc Person']});
      final jobs = FakeSource(SearchKind.job)..failure = Exception('boom');
      final c = build([people, jobs]);
      c.setQuery('abc');
      await settle();
      expect(c.groupOf(SearchKind.job).status, GroupStatus.failed);
      expect(c.allOrder, [SearchKind.person]);
      expect(c.offline, isFalse);
      expect(c.noResults, isFalse);
    });

    test('every source failing is offline, not "no results"', () async {
      final a = FakeSource(SearchKind.person)..failure = Exception('down');
      final b = FakeSource(SearchKind.job)..failure = Exception('down');
      final c = build([a, b]);
      c.setQuery('abc');
      await settle();
      expect(c.offline, isTrue);
      expect(c.noResults, isFalse);

      a.failure = null;
      b.failure = null;
      c.retry();
      await settle();
      expect(c.offline, isFalse);
      expect(a.calls.length, 2);
    });

    test('sources that answer with nothing: "no results"', () async {
      final c = build([FakeSource(SearchKind.person), FakeSource(SearchKind.job)]);
      c.setQuery('zzzzz');
      await settle();
      expect(c.noResults, isTrue);
      expect(c.hasResults, isFalse);
    });

    test('the last hits stay on screen while the next answer loads, so the page does not blank', () async {
      final jobs = FakeSource(SearchKind.job, answers: {'plan': ['Planner'], 'plans': ['Plans Manager']});
      final c = build([jobs]);
      c.setQuery('plan');
      await settle();
      jobs.hold = Completer<void>();
      c.setQuery('plans');
      await settle();
      expect(c.anyLoading, isTrue);
      expect(c.allOrder, contains(SearchKind.job));
      expect(c.groupOf(SearchKind.job).hits.single.title, 'Planner');
      jobs.hold!.complete();
      await settle();
      expect(c.groupOf(SearchKind.job).hits.single.title, 'Plans Manager');
    });
  });

  group('chips', () {
    test('choosing a kind asks only that source, once; All again reads nothing it already has', () async {
      final people = FakeSource(SearchKind.person, answers: {'abc': ['P1']});
      final jobs = FakeSource(SearchKind.job, answers: {'abc': ['J1']});
      final c = build([people, jobs]);
      c.setQuery('abc');
      await settle();
      expect([people.calls.length, jobs.calls.length], [1, 1]);

      c.setScope(SearchKind.job);
      await settle();
      c.setScope(null);
      await settle();
      expect([people.calls.length, jobs.calls.length], [1, 1], reason: 'the query already has both');
    });

    test('typing while on one chip asks that source alone', () async {
      final people = FakeSource(SearchKind.person, answers: {'abcd': ['P1']});
      final jobs = FakeSource(SearchKind.job, answers: {'abcd': ['J1']});
      final c = build([people, jobs]);
      c.setScope(SearchKind.job);
      c.setQuery('abcd');
      await settle();
      expect(jobs.calls, ['abcd']);
      expect(people.calls, isEmpty);
    });

    test('a chip tapped while others are still loading does not strand them', () async {
      final people = FakeSource(SearchKind.person, answers: {'abc': ['P1']});
      final jobs = FakeSource(SearchKind.job, answers: {'abc': ['J1']});
      final gate = Completer<void>();
      people.hold = gate;
      jobs.hold = gate;
      final c = build([people, jobs]);
      c.setQuery('abc');
      await settle();
      expect(c.anyLoading, isTrue);

      c.setScope(SearchKind.job);
      gate.complete();
      await settle();
      c.setScope(null);
      await settle();
      expect(c.anyLoading, isFalse, reason: 'no group is left loading');
      expect(c.groupOf(SearchKind.person).hits.single.title, 'P1');
      expect(c.groupOf(SearchKind.job).hits.single.title, 'J1');
    });

    test('chips list the sources, plus App when the app has features to open', () {
      final c = build([FakeSource(SearchKind.person), FakeSource(SearchKind.job)], features: {'jobs'});
      expect(c.chips, [SearchKind.person, SearchKind.job, SearchKind.feature]);
      final none = build([FakeSource(SearchKind.person)], features: <String>{});
      expect(none.chips, [SearchKind.person]);
    });
  });

  group('paging one kind', () {
    test('more() reads the next page of the same source and does not repeat a hit', () async {
      final jobs = FakeSource(SearchKind.job, answers: {'abc': ['a', 'b', 'c', 'd', 'e']}, pageable: true);
      final c = build([jobs]);
      c.setScope(SearchKind.job);
      c.setQuery('abc');
      await settle();
      expect(c.groupOf(SearchKind.job).hits.map((h) => h.title), ['a', 'b']);
      expect(c.groupOf(SearchKind.job).hasMore, isTrue);

      await c.more(SearchKind.job);
      expect(c.groupOf(SearchKind.job).hits.map((h) => h.title), ['a', 'b', 'c', 'd']);
      await c.more(SearchKind.job);
      expect(c.groupOf(SearchKind.job).hits.map((h) => h.title), ['a', 'b', 'c', 'd', 'e']);
      expect(c.groupOf(SearchKind.job).hasMore, isFalse);
      expect(jobs.pagesAsked, [1, 2, 3]);

      await c.more(SearchKind.job);
      expect(jobs.pagesAsked.length, 3, reason: 'no more pages to ask');
    });

    test('a source that does not page never reports more', () async {
      final people = FakeSource(SearchKind.person, answers: {'abc': ['a', 'b', 'c']});
      final c = build([people]);
      c.setQuery('abc');
      await settle();
      expect(c.groupOf(SearchKind.person).hasMore, isFalse);
    });
  });

  group('the order of the All chip', () {
    test('people lead, then jobs, mentors, courses, suppliers, events, discussions, documents', () async {
      final kinds = [
        SearchKind.document, SearchKind.discussion, SearchKind.event, SearchKind.supplier,
        SearchKind.course, SearchKind.mentor, SearchKind.job, SearchKind.person,
      ];
      final c = build([for (final k in kinds) FakeSource(k, answers: {'zzq': ['x']})], features: <String>{});
      c.setQuery('zzq');
      await settle();
      expect(c.allOrder, [
        SearchKind.person, SearchKind.job, SearchKind.mentor, SearchKind.course,
        SearchKind.supplier, SearchKind.event, SearchKind.discussion, SearchKind.document,
      ]);
    });

    test('a feature named by the query leads: "plans" before the people who mention it', () async {
      final c = build([FakeSource(SearchKind.person, answers: {'plans': ['Plans Person']})], features: {'plans'});
      c.setQuery('plans');
      await settle();
      expect(c.allOrder.first, SearchKind.feature);
      expect(c.featureMatches.first.feature.id, 'plans');
    });

    test('a feature that only mentions the word follows the records', () async {
      final c = build([FakeSource(SearchKind.person, answers: {'cpd': ['Cpd Person']})], features: {'certificates'});
      c.setQuery('cpd');
      await settle();
      expect(c.featureMatches, isNotEmpty);
      expect(c.featureMatches.first.strong, isFalse);
      expect(c.allOrder, [SearchKind.person, SearchKind.feature]);
    });

    test('only the features the app can open are offered', () async {
      final c = build([FakeSource(SearchKind.person)], features: {'jobs'});
      c.setQuery('learning');
      await settle();
      expect(c.featureMatches, isEmpty);
    });
  });

  group('recent searches', () {
    test('a search is kept when submitted or when a hit is opened, newest first, once', () async {
      final store = MemoryRecentStore();
      final c = build([FakeSource(SearchKind.person, answers: {'meera': ['M']})], recents: RecentSearches(store));
      c.setQuery('meera');
      c.submit();
      await settle();
      expect(c.recents.items, ['meera']);

      c.setQuery('Plans');
      await settle();
      c.opened();
      await settle();
      c.setQuery('MEERA');
      c.submit();
      await settle();
      expect(c.recents.items, ['MEERA', 'Plans'], reason: 'the repeat moves to the front, not a second row');
      expect(await store.load(), ['MEERA', 'Plans']);
    });

    test('a one-character query is never kept', () async {
      final c = build([FakeSource(SearchKind.person)]);
      c.setQuery('m');
      c.submit();
      c.opened();
      await settle();
      expect(c.recents.items, isEmpty);
    });

    test('they come back from the store, can be removed one by one, and cleared', () async {
      final c = build([FakeSource(SearchKind.person)], recents: RecentSearches(MemoryRecentStore(['one', 'two', 'three'])));
      await c.loadRecents();
      expect(c.recents.items, ['one', 'two', 'three']);
      await c.removeRecent('two');
      expect(c.recents.items, ['one', 'three']);
      await c.clearRecents();
      expect(c.recents.items, isEmpty);
    });

    test('at most ten are kept', () async {
      final r = RecentSearches(MemoryRecentStore());
      for (var i = 0; i < 14; i++) {
        await r.add('search $i');
      }
      expect(r.items.length, 10);
      expect(r.items.first, 'search 13');
    });
  });
}
