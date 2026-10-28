import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/career/career_models.dart';
import 'package:icr_mobile/features/career/saved_jobs_controller.dart';
import 'package:icr_mobile/features/career/saved_jobs_screen.dart';
import 'package:icr_mobile/features/jobs/jobs_navigation.dart';
import 'package:icr_mobile/features/jobs/widgets/job_row.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'career_fakes.dart';
import 'helpers/fonts.dart';
import 'jobs_fakes.dart';

/// "Saved jobs": the bookmarks and the hidden jobs, every control tapped. What the API does with
/// the taps is proved in `test/live/career_live_test.dart`.

final _now = DateTime(2026, 10, 26, 12);

Future<({SpyCareer repo, SpyJobsRepository jobs, RecordingLinks links})> pumpSaved(
  WidgetTester tester, {
  SavedTab tab = SavedTab.saved,
  SpyCareer? career,
  SpyJobsRepository? jobs,
  JobsNavigation navigation = JobsNavigation.none,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final spyJobs = jobs ?? SpyJobsRepository();
  final repo = career ?? SpyCareer(jobs: spyJobs, now: _now);
  final links = RecordingLinks();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: SavedJobsScreen(repository: repo, links: links, navigation: navigation, tab: tab),
    ),
  );
  await tester.pumpAndSettle();
  return (repo: repo, jobs: spyJobs, links: links);
}

void main() {
  setUpAll(loadAppFonts);

  group('the saved shelf', () {
    testWidgets('lists the bookmarks with their count, each row bookmarked', (tester) async {
      await pumpSaved(tester);
      expect(find.text('Saved jobs'), findsOneWidget);
      expect(find.byType(JobRow), findsNWidgets(2));
      expect(find.text('Saved 2'), findsOneWidget);
      expect(find.byIcon(LucideIcons.bookmarkCheck), findsNWidgets(2));
    });

    testWidgets('taking a bookmark off removes the row at once, tells the API, and Undo puts it back', (tester) async {
      final s = await pumpSaved(tester);
      await tester.tap(find.byIcon(LucideIcons.bookmarkCheck).first);
      await tester.pumpAndSettle();
      expect(find.byType(JobRow), findsNWidgets(1));
      expect(s.jobs.saves, [(jobId: 'demo-1', saved: false)]);
      expect(find.text('Bookmark removed'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.byType(JobRow), findsNWidgets(2));
      expect(s.jobs.saves.last, (jobId: 'demo-1', saved: true));
      // Back where it was: the first row.
      expect(find.byType(JobRow).first, findsOneWidget);
      expect(tester.widget<JobRow>(find.byType(JobRow).first).job.id, 'demo-1');
    });

    testWidgets('a refusal puts the row back and says why', (tester) async {
      final jobs = SpyJobsRepository()..setSavedError = ApiError('Try again later.', statusCode: 500);
      await pumpSaved(tester, jobs: jobs);
      await tester.tap(find.byIcon(LucideIcons.bookmarkCheck).first);
      await tester.pumpAndSettle();
      expect(find.byType(JobRow), findsNWidgets(2));
      expect(find.text('Try again later.'), findsOneWidget);
    });

    testWidgets('a row opens the job sheet', (tester) async {
      await pumpSaved(tester);
      await tester.tap(find.byType(JobRow).first);
      await tester.pumpAndSettle();
      expect(find.text('JOB DETAILS'), findsOneWidget);
    });

    testWidgets('a job that stopped taking applications says so on its row', (tester) async {
      final repo = SpyCareer(now: _now)
        ..savedSet = true
        ..savedAnswer = [fakeJob('a', saved: true).copyWith(status: 'CLOSED')];
      await pumpSaved(tester, career: repo);
      expect(find.text('No longer accepting applications'), findsOneWidget);
    });

    testWidgets('View More reads the next page without repeating a job', (tester) async {
      final repo = SpyCareer(now: _now)
        ..savedSet = true
        ..savedHasMore = true
        ..savedAnswer = [fakeJob('a', saved: true), fakeJob('b', saved: true)];
      await pumpSaved(tester, career: repo);
      await tester.tap(find.byKey(const ValueKey('view-more')));
      await tester.pumpAndSettle();
      expect(repo.log.where((l) => l.startsWith('savedJobs')), ['savedJobs 1', 'savedJobs 2']);
      expect(find.byType(JobRow), findsNWidgets(2), reason: 'page two answered the same jobs: none twice');
      expect(find.byKey(const ValueKey('view-more')), findsNothing);
    });

    testWidgets('nothing saved: it says so and offers the board', (tester) async {
      final repo = SpyCareer(now: _now)
        ..savedSet = true
        ..savedAnswer = const [];
      await pumpSaved(tester, career: repo);
      expect(find.byKey(const ValueKey('saved-empty')), findsOneWidget);
      expect(find.text('Browse jobs'), findsOneWidget);
    });

    testWidgets('a shelf that cannot load says why, and Try again reads it again', (tester) async {
      final repo = SpyCareer(now: _now)..savedError = ApiError('The jobs are down.', statusCode: 500);
      await pumpSaved(tester, career: repo);
      expect(find.byKey(const ValueKey('saved-error')), findsOneWidget);
      expect(find.text('The jobs are down.'), findsOneWidget);
      repo.savedError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(JobRow), findsNWidgets(2));
    });

    testWidgets('pull to refresh reads the shelf again', (tester) async {
      final s = await pumpSaved(tester);
      await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(s.repo.log.where((l) => l.startsWith('savedJobs')).length, greaterThan(1));
    });

    testWidgets('the bell opens the notifications the app wired', (tester) async {
      var bells = 0;
      await pumpSaved(tester, navigation: JobsNavigation(onBell: () => bells++));
      await tester.tap(find.byIcon(LucideIcons.bell));
      expect(bells, 1);
    });
  });

  group('the hidden shelf', () {
    testWidgets('lists what the member hid, each with Show again', (tester) async {
      await pumpSaved(tester, tab: SavedTab.hidden);
      expect(find.byType(HiddenJobRow), findsOneWidget);
      expect(find.text('Soft Services Manager'), findsOneWidget);
      expect(find.text('Show again'), findsOneWidget);
      expect(find.text('Hidden 1'), findsOneWidget);
    });

    testWidgets('switching to Hidden reads it on first show, not before', (tester) async {
      final s = await pumpSaved(tester);
      expect(find.byType(HiddenJobRow), findsNothing);
      expect(s.repo.log, isNot(contains('hidden')), reason: 'the second shelf has not been opened');
      await tester.tap(find.byKey(const ValueKey('saved-tab-hidden')));
      await tester.pumpAndSettle();
      expect(find.byType(HiddenJobRow), findsOneWidget);
      expect(s.repo.log.where((l) => l == 'hidden'), hasLength(1));
    });

    testWidgets('Show again brings the job back to the board, and Undo hides it again', (tester) async {
      final s = await pumpSaved(tester, tab: SavedTab.hidden);
      await tester.tap(find.text('Show again'));
      await tester.pumpAndSettle();
      expect(find.byType(HiddenJobRow), findsNothing);
      expect(s.jobs.hidden, isEmpty, reason: 'unhidden through the API');
      expect(find.byKey(const ValueKey('hidden-empty')), findsOneWidget);
      expect(find.text('Back on your board'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.byType(HiddenJobRow), findsOneWidget);
      expect(s.jobs.hidden, contains('demo-hidden-1'));
    });

    testWidgets('a job that has since closed still shows, cannot be opened, and can be shown again', (tester) async {
      final repo = SpyCareer(now: _now)
        ..hiddenAnswer = [
          Job(
            id: 'gone',
            title: 'A job that is no longer open',
            company: const JobCompany(id: '', name: 'Closed'),
            status: 'CLOSED',
          ),
        ];
      final s = await pumpSaved(tester, tab: SavedTab.hidden, career: repo);
      expect(find.text('A job that is no longer open'), findsOneWidget);
      await tester.tap(find.text('A job that is no longer open'));
      await tester.pumpAndSettle();
      expect(find.text('JOB DETAILS'), findsNothing);
      await tester.tap(find.text('Show again'));
      await tester.pumpAndSettle();
      expect(find.byType(HiddenJobRow), findsNothing);
      expect(s.jobs.hidden, isEmpty);
    });

    testWidgets('a hidden shelf that cannot load says why, and Try again reads it again', (tester) async {
      final repo = SpyCareer(now: _now)..hiddenError = ApiError('Hidden jobs are down.', statusCode: 500);
      await pumpSaved(tester, tab: SavedTab.hidden, career: repo);
      expect(find.byKey(const ValueKey('hidden-error')), findsOneWidget);
      expect(find.text('Hidden jobs are down.'), findsOneWidget);
      repo.hiddenError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(HiddenJobRow), findsOneWidget);
    });
  });
}
