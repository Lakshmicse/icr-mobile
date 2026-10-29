import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/events/demo_events_repository.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart';
import 'package:icr_mobile/features/jobs/demo_jobs_repository.dart';
import 'package:icr_mobile/features/jobs/job_models.dart';
import 'package:icr_mobile/features/learning/demo_learning_repository.dart';
import 'package:icr_mobile/features/learning/learning_models.dart';
import 'package:icr_mobile/features/learning/learning_repository.dart';
import 'package:icr_mobile/features/library/demo_library_repository.dart';
import 'package:icr_mobile/features/marketplace/demo_marketplace_repository.dart';
import 'package:icr_mobile/features/mentorship/demo_mentorship_repository.dart';
import 'package:icr_mobile/features/mentorship/mentorship_models.dart';
import 'package:icr_mobile/features/messaging/demo_messaging_repository.dart';
import 'package:icr_mobile/features/search/repository_sources.dart';
import 'package:icr_mobile/features/search/search_models.dart';

/// The courses endpoint, counted, and made to fail on demand.
class _CountingLearning implements LearningRepository {
  _CountingLearning(this.courseList);

  final List<Course> courseList;
  int reads = 0;
  Object? failure;

  @override
  Future<void> withdraw(Course course) async {}

  @override
  Future<List<Course>> courses() async {
    reads++;
    final error = failure;
    if (error != null) throw error;
    return courseList;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late List<SearchSource> sources;

  setUp(() {
    sources = repositorySources(
      messaging: DemoMessagingRepository(),
      jobs: DemoJobsRepository(),
      mentorship: DemoMentorshipRepository(),
      learning: DemoLearningRepository(),
      marketplace: DemoMarketplaceRepository(),
      events: DemoEventsRepository(),
      feed: DemoFeedRepository(),
      library: DemoLibraryRepository(),
    );
  });

  SearchSource of(SearchKind kind) => sources.firstWhere((s) => s.kind == kind);

  group('every kind of source', () {
    test('there is one source per searchable kind, and none for the app features', () {
      expect(sources.map((s) => s.kind).toSet(), {
        SearchKind.person,
        SearchKind.job,
        SearchKind.mentor,
        SearchKind.course,
        SearchKind.supplier,
        SearchKind.event,
        SearchKind.discussion,
        SearchKind.document,
      });
      expect(sources.length, 8);
    });

    test('people: a name finds the member, with the id the profile opens by', () async {
      final page = await of(SearchKind.person).search('sarah');
      expect(page.hits, isNotEmpty);
      final hit = page.hits.first;
      expect(hit.kind, SearchKind.person);
      expect(hit.title, contains('Sarah'));
      expect(hit.id, isNotEmpty);
      expect(page.hasMore, isFalse);
    });

    test('jobs: the board, not only Easy Apply, and each hit carries the job it opens', () async {
      final all = await DemoJobsRepository().search(const JobFilters(easyApply: false));
      final word = all.jobs.first.title.split(' ').first;
      final page = await of(SearchKind.job).search(word);
      expect(page.hits, isNotEmpty);
      expect(page.hits.first.payload, isA<Job>());
      expect(page.hits.first.subtitle, contains(all.jobs.first.company.name));
      expect(of(SearchKind.job).pages, isTrue);
    });

    test('mentors: by name', () async {
      final everyone = await DemoMentorshipRepository().search(const MentorFilters());
      final first = everyone.mentors.first.name.split(' ').first;
      final page = await of(SearchKind.mentor).search(first);
      expect(page.hits, isNotEmpty);
      expect(page.hits.first.kind, SearchKind.mentor);
      expect(page.hits.first.title, contains(first));
    });

    test('suppliers: at any trust level, with the listing for the sheet', () async {
      final page = await of(SearchKind.supplier).search('facility');
      expect(page.hits, isNotEmpty);
      expect(page.hits.first.title, isNotEmpty);
      expect(page.hits.first.id, isNotEmpty);
    });

    test('events: kind, day and place in one line, and the slug the sheet opens by', () async {
      final page = await of(SearchKind.event).search('facility');
      expect(page.hits, isNotEmpty);
      final hit = page.hits.first;
      expect(hit.slug, isNotNull);
      expect(hit.subtitle, contains('Webinar'));
    });

    test('discussions: a title on one line, the author and the comment count', () async {
      final page = await of(SearchKind.discussion).search('hvac');
      expect(page.hits, isNotEmpty);
      for (final h in page.hits) {
        expect(h.title, isNot(contains('\n')), reason: 'a wrapped title is flattened for a row');
        expect(h.subtitle, contains('comment'));
        expect(h.slug, isNotEmpty);
      }
    });

    test('documents: the title, its category and who shared it', () async {
      final page = await of(SearchKind.document).search('facility');
      expect(page.hits, isNotEmpty);
      expect(page.hits.first.subtitle, isNotEmpty);
    });

    test('a query nothing matches is an empty page, never an error', () async {
      for (final s in sources) {
        final page = await s.search('zzzqqxx');
        expect(page.hits, isEmpty, reason: s.kind.name);
      }
    });
  });

  group('courses', () {
    late List<Course> demo;

    setUp(() async => demo = await DemoLearningRepository().courses());

    test('are matched on the device over the one catalogue read, by title, code, summary or provider', () async {
      final repo = _CountingLearning(demo);
      final source = CoursesSource(repo);
      final title = demo.first.title.split(' ').first.toLowerCase();

      final byTitle = await source.search(title);
      expect(byTitle.hits.map((h) => h.id), contains(demo.first.id));
      expect(byTitle.hits.first.payload, isA<Course>());

      await source.search(title);
      await source.search(demo.first.code);
      expect(repo.reads, 1, reason: 'one read of the catalogue serves every keystroke');
    });

    test('every word has to match, and a title match outranks a summary match', () async {
      final source = CoursesSource(_CountingLearning(demo));
      expect((await source.search('leadership zzzqq')).hits, isEmpty);
      final page = await source.search('leadership');
      expect(page.hits, isNotEmpty);
      expect(page.hits.first.title.toLowerCase(), contains('leadership'));
    });

    test('the catalogue is read again after a minute, and a failed read is not remembered', () async {
      var now = DateTime(2026, 10, 27, 12);
      final repo = _CountingLearning(demo);
      final source = CoursesSource(repo, clock: () => now);
      await source.search('leadership');
      now = now.add(const Duration(seconds: 30));
      await source.search('leadership');
      expect(repo.reads, 1);
      now = now.add(const Duration(seconds: 40));
      await source.search('leadership');
      expect(repo.reads, 2);

      final broken = _CountingLearning(demo)..failure = Exception('offline');
      final fresh = CoursesSource(broken, clock: () => now);
      await expectLater(fresh.search('leadership'), throwsException);
      broken.failure = null;
      final page = await fresh.search('leadership');
      expect(page.hits, isNotEmpty, reason: 'the failure was not cached');
    });
  });
}
