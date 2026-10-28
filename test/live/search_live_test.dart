@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/features/events/api_events_repository.dart';
import 'package:icr_mobile/features/feed/api_feed_repository.dart';
import 'package:icr_mobile/features/jobs/api_jobs_repository.dart';
import 'package:icr_mobile/features/learning/api_learning_repository.dart';
import 'package:icr_mobile/features/library/api_library_repository.dart';
import 'package:icr_mobile/features/marketplace/api_marketplace_repository.dart';
import 'package:icr_mobile/features/mentorship/api_mentorship_repository.dart';
import 'package:icr_mobile/features/messaging/api_messaging_repository.dart';
import 'package:icr_mobile/features/search/recent_searches.dart';
import 'package:icr_mobile/features/search/repository_sources.dart';
import 'package:icr_mobile/features/search/search_controller.dart';
import 'package:icr_mobile/features/search/search_models.dart';

import 'live.dart';

/// The global search's sources against the local API: each one asks the
/// endpoint its own screen asks, so what is proved here is that every answer
/// the API really gives parses into hits a row can draw and an opener can open.
///
/// Read-only. Signed in as Bharat Buyer (`buyer@icr.dev`); people are found
/// through `GET /messaging/recipients`, which never returns the caller, so the
/// person searched for is Pooja Professional.
///
/// Run: `flutter test test/live/search_live_test.dart --concurrency=1`
void main() {
  List<SearchSource> realSources(ApiClient api) => repositorySources(
    messaging: ApiMessagingRepository(api: api),
    jobs: ApiJobsRepository(api: api),
    mentorship: ApiMentorshipRepository(api: api),
    learning: ApiLearningRepository(api: api),
    marketplace: ApiMarketplaceRepository(api: api),
    events: ApiEventsRepository(api: api),
    feed: ApiFeedRepository(api: api, viewerId: null),
    library: ApiLibraryRepository(api: api),
  );

  /// One source, asked on its own: a failure names the source.
  Future<SourcePage> ask(List<SearchSource> sources, SearchKind kind, String q) =>
      sources.firstWhere((s) => s.kind == kind).search(q);

  void checkHits(SearchKind kind, SourcePage page) {
    for (final h in page.hits) {
      expect(h.kind, kind);
      expect(h.id, isNotEmpty, reason: '$kind hit has an id to open it by');
      expect(h.title.trim(), isNotEmpty, reason: '$kind hit has a title');
      expect(h.title, isNot(contains('\n')));
      final image = h.imageUrl;
      if (image != null) expect(image, startsWith('http'), reason: 'pictures are absolute URLs');
      if (h.subtitle != null) expect(h.subtitle!.trim(), isNotEmpty);
    }
  }

  liveTest('people: a name finds the member (never the caller)', () async {
    final sources = realSources(await liveClient());
    final page = await ask(sources, SearchKind.person, 'Pooja');
    checkHits(SearchKind.person, page);
    expect(page.hits, isNotEmpty, reason: 'seeded: Pooja Professional has a public profile');
    expect(page.hits.first.title, contains('Pooja'));
    final self = await ask(sources, SearchKind.person, 'Bharat');
    expect(self.hits.where((h) => h.title.contains('Bharat Buyer')), isEmpty, reason: 'the caller is not offered to themselves');
    expect((await ask(sources, SearchKind.person, 'P')).hits, isEmpty, reason: 'one character is below the API\'s minimum');
  });

  liveTest('jobs: the board answers, each hit carries the job the sheet opens', () async {
    final sources = realSources(await liveClient());
    final page = await ask(sources, SearchKind.job, 'manager');
    checkHits(SearchKind.job, page);
    expect(page.hits, isNotEmpty, reason: 'seeded jobs include managers');
    expect(page.hits.every((h) => h.payload != null), isTrue);
  });

  liveTest('mentors: by name and by words', () async {
    final sources = realSources(await liveClient());
    final page = await ask(sources, SearchKind.mentor, 'mentor');
    checkHits(SearchKind.mentor, page);
    final byName = await ask(sources, SearchKind.mentor, 'Srikanth');
    checkHits(SearchKind.mentor, byName);
  });

  liveTest('courses: the catalogue is matched on the device', () async {
    final sources = realSources(await liveClient());
    final page = await ask(sources, SearchKind.course, 'certificate');
    checkHits(SearchKind.course, page);
    final none = await ask(sources, SearchKind.course, 'zzzqqxx');
    expect(none.hits, isEmpty);
  });

  liveTest('suppliers: listings at every trust level', () async {
    final sources = realSources(await liveClient());
    final page = await ask(sources, SearchKind.supplier, 'tech');
    checkHits(SearchKind.supplier, page);
    expect(page.hits, isNotEmpty, reason: 'seeded suppliers include SecureTech and Vikasha Aero Tech');
  });

  liveTest('events: upcoming events', () async {
    final sources = realSources(await liveClient());
    final page = await ask(sources, SearchKind.event, 'management');
    checkHits(SearchKind.event, page);
    for (final h in page.hits) {
      expect(h.slug, isNotEmpty, reason: 'the event sheet opens by slug');
    }
  });

  liveTest('discussions: forum threads by their words', () async {
    final sources = realSources(await liveClient());
    final page = await ask(sources, SearchKind.discussion, 'welcome');
    checkHits(SearchKind.discussion, page);
    for (final h in page.hits) {
      expect(h.slug, isNotEmpty, reason: 'the thread page opens by slug');
      expect(h.payload, isNotNull);
    }
  });

  liveTest('documents: the library by title', () async {
    final sources = realSources(await liveClient());
    final page = await ask(sources, SearchKind.document, 'template');
    checkHits(SearchKind.document, page);
  });

  liveTest('the controller over the real sources: one query, every group, no source stranded', () async {
    final api = await liveClient();
    final c = GlobalSearchController(
      sources: realSources(api),
      availableFeatures: {'jobs', 'mentorship', 'find_mentors', 'plans'},
      recents: RecentSearches(MemoryRecentStore()),
      debounce: const Duration(milliseconds: 5),
    );
    addTearDown(c.dispose);

    c.setQuery('manager');
    // Past the debounce, so the sources are asked; then until every one has answered or failed.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (c.anyLoading && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(c.anyLoading, isFalse, reason: 'every source answered, or failed, within 20 s');
    final failed = [for (final k in c.kinds) if (c.groupOf(k).status == GroupStatus.failed) k.name];
    expect(failed, isEmpty, reason: 'sources that failed against the real API: $failed');
    expect(c.hasResults, isTrue);
    expect(c.offline, isFalse);
    // "manager" is a word in the catalogue's keywords too: a place may lead.
    expect(c.allOrder, isNotEmpty);
  });
}
