import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/career/career_hub_screen.dart';
import 'package:icr_mobile/features/career/company_insights_screen.dart';
import 'package:icr_mobile/features/career/job_alerts_screen.dart';
import 'package:icr_mobile/features/career/my_applications_screen.dart';
import 'package:icr_mobile/features/career/saved_jobs_screen.dart';
import 'package:icr_mobile/features/jobs/employer/demo_hiring_repository.dart';
import 'package:icr_mobile/features/jobs/employer/employer_jobs_screen.dart';
import 'package:icr_mobile/features/jobs/employer/hiring_models.dart';
import 'package:icr_mobile/features/jobs/employer/hiring_repository.dart';
import 'package:icr_mobile/features/jobs/employer/post_job_screen.dart';
import 'package:icr_mobile/features/jobs/job_detail_sheet.dart';
import 'package:icr_mobile/features/jobs/job_models.dart';
import 'package:icr_mobile/features/jobs/jobs_controller.dart';
import 'package:icr_mobile/features/jobs/jobs_navigation.dart';
import 'package:icr_mobile/features/jobs/jobs_screen.dart';
import 'package:icr_mobile/features/jobs/widgets/job_filters_sheet.dart';
import 'package:icr_mobile/features/jobs/widgets/job_row.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import 'helpers/fonts.dart';
import 'jobs_fakes.dart';

/// Every control of the Jobs tab and its job sheet, tapped: what it does here,
/// and where it leaves the app. What the API does with a tap is proved in
/// `test/live/jobs_live_test.dart`.

class BoardUnderTest {
  BoardUnderTest(this.repo, this.links, this.jobs, this.backs);

  final SpyJobsRepository repo;
  final RecordingLinks links;
  final JobsController jobs;
  final List<String> backs;
}

Future<BoardUnderTest> pumpBoard(
  WidgetTester tester, {
  SpyJobsRepository? repo,
  Size size = const Size(390, 900),
  HiringRepository? hiring,
  JobsNavigation? navigation,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final spy = repo ?? SpyJobsRepository();
  final links = RecordingLinks();
  final jobs = JobsController(spy, links: links, hiring: hiring);
  addTearDown(jobs.dispose);
  final backs = <String>[];
  await tester.runAsync(jobs.start);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: ChangeNotifierProvider.value(
        value: jobs,
        child: JobsScreen(onBack: () => backs.add('back'), navigation: navigation),
      ),
    ),
  );
  await tester.pump();
  return BoardUnderTest(spy, links, jobs, backs);
}

/// A board of [sections], each of the given jobs.
SpyJobsRepository boardOf(List<JobSection> sections, {JobContext? alert}) =>
    SpyJobsRepository()
      ..overviewAnswer = ((_) => JobsOverview(sections: sections, myJobs: 3, newAlerts: 2, alert: alert));

/// The bookmark of the [index]th row (the My jobs chip has a bookmark glyph too).
Finder rowBookmark(IconData icon, [int index = 0]) =>
    find.descendant(of: find.byType(JobRow).at(index), matching: find.byIcon(icon));

Finder inSheet(Finder finder) => find.descendant(of: find.byType(JobSheetBody), matching: finder);
Finder inBar(Finder finder) => find.descendant(of: find.byType(JobSheetBar), matching: finder);

Future<void> openFirstJob(WidgetTester tester) async {
  await tester.tap(find.byType(JobRow).first);
  await tester.pumpAndSettle();
  expect(find.text('JOB DETAILS'), findsOneWidget);
}

/// Brings something already built (a chip in the sideways row) into view.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// Scrolls the job sheet until [finder] is built and on screen (its list builds lazily).
Future<void> scrollSheetTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.descendant(of: find.byType(JobSheetBody), matching: find.byType(Scrollable)).first,
  );
  await tester.pumpAndSettle();
}

/// A hiring source that cannot be reached: the account cannot be told.
class _UnreachableHiring extends DemoHiringRepository {
  @override
  Future<HiringAccess> access() => Future.error(ApiError('offline'));
}

void main() {
  setUpAll(loadAppFonts);

  group('the title bar', () {
    testWidgets('Back goes back, and the bell opens the notifications on the website', (tester) async {
      final board = await pumpBoard(tester);
      await tester.tap(find.byIcon(Symbols.arrow_back));
      expect(board.backs, ['back']);

      await tester.tap(find.byIcon(LucideIcons.bell));
      await tester.pump();
      expect(board.links.paths, ['/notifications']);
    });

    testWidgets('the bell says how many notifications are unread', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpBoard(tester);
      expect(find.bySemanticsLabel('Notifications, 1 unread'), findsOneWidget);
      handle.dispose();
    });
  });

  group('the chips', () {
    testWidgets('Demonstrate skills opens its website page', (tester) async {
      final board = await pumpBoard(tester);
      await scrollTo(tester, find.text('Demonstrate skills'));
      await tester.tap(find.text('Demonstrate skills'));
      await tester.pump();
      expect(board.links.paths, ['/learning/assessment']);
    });

    testWidgets('Demonstrate skills hands over to the assessments in the app when they are wired', (tester) async {
      var opened = 0;
      final board = await pumpBoard(tester, navigation: JobsNavigation(onDemonstrateSkills: () => opened++));
      await scrollTo(tester, find.text('Demonstrate skills'));
      await tester.tap(find.text('Demonstrate skills'));
      await tester.pump();
      expect(opened, 1);
      expect(board.links.opened, isEmpty);
    });

    testWidgets('a page the phone cannot open is said so', (tester) async {
      final board = await pumpBoard(tester);
      board.links.opens = false;
      await scrollTo(tester, find.text('Demonstrate skills'));
      await tester.tap(find.text('Demonstrate skills'));
      await tester.pump();
      expect(find.text("Couldn't open icr.org.in/learning/assessment"), findsOneWidget);
    });

    testWidgets('Post a job opens the composer for a member on a hiring team', (tester) async {
      final board = await pumpBoard(tester, hiring: DemoHiringRepository());
      expect(board.jobs.canHire, isTrue);
      await tester.tap(find.text('Post a job'));
      await tester.pumpAndSettle();
      expect(find.byType(PostJobScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('hirers-only-dialog')), findsNothing);
      expect(board.links.opened, isEmpty, reason: 'nothing leaves the app');
    });

    testWidgets('Post a job tells anyone else that jobs are posted for a company, and offers to make one', (
      tester,
    ) async {
      final board = await pumpBoard(tester);
      expect(board.jobs.canHire, isFalse);
      await tester.tap(find.text('Post a job'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('hirers-only-dialog')), findsOneWidget);
      expect(find.byType(PostJobScreen), findsNothing);

      await tester.tap(find.byKey(const ValueKey('hirers-only-later')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('hirers-only-dialog')), findsNothing);
      expect(board.links.opened, isEmpty);

      await tester.tap(find.text('Post a job'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('hirers-only-create')));
      await tester.pumpAndSettle();
      expect(board.links.paths, [
        '/account/companies/new',
      ], reason: 'the company page is the website until the app has one');
    });

    testWidgets('Create a company hands over to the app when it is wired', (tester) async {
      var made = 0;
      final board = await pumpBoard(tester, navigation: JobsNavigation(onCreateCompany: () => made++));
      await tester.tap(find.text('Post a job'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('hirers-only-create')));
      await tester.pumpAndSettle();
      expect(made, 1);
      expect(board.links.opened, isEmpty);
    });

    testWidgets('Post a job says so when the account cannot be checked, and opens nothing', (tester) async {
      final board = await pumpBoard(tester, hiring: _UnreachableHiring());
      await tester.tap(find.text('Post a job'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't check your account. Try again in a moment."), findsOneWidget);
      expect(find.byKey(const ValueKey('hirers-only-dialog')), findsNothing);
      expect(find.byType(PostJobScreen), findsNothing);
      expect(board.links.opened, isEmpty);
    });

    testWidgets('My jobs offers "Jobs you posted" to a hiring team only', (tester) async {
      await pumpBoard(tester);
      await tester.tap(find.text('My jobs'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('my-jobs-posted')), findsNothing);
    });

    testWidgets("My jobs 'Jobs you posted' opens the company's postings in the app", (tester) async {
      final board = await pumpBoard(tester, hiring: DemoHiringRepository());
      await tester.tap(find.text('My jobs'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('my-jobs-posted')));
      await tester.pumpAndSettle();
      expect(find.byType(EmployerJobsScreen), findsOneWidget);
      expect(find.text('Jobs you posted'), findsWidgets);
      expect(board.links.opened, isEmpty);
    });

    testWidgets('the career hub lists "Jobs you posted" for a hiring team, and not for anyone else', (tester) async {
      await pumpBoard(tester);
      await tester.tap(find.text('My jobs'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('my-jobs-hub')));
      await tester.pumpAndSettle();
      expect(find.byType(CareerHubScreen), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('go-invitations')), 300);
      expect(find.byKey(const ValueKey('go-posted')), findsNothing);
    });

    testWidgets("the career hub's 'Jobs you posted' opens the postings", (tester) async {
      await pumpBoard(tester, hiring: DemoHiringRepository());
      await tester.tap(find.text('My jobs'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('my-jobs-hub')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const ValueKey('go-posted')), 300);
      await scrollTo(tester, find.byKey(const ValueKey('go-posted')));
      await tester.tap(find.byKey(const ValueKey('go-posted')));
      await tester.pumpAndSettle();
      expect(find.byType(EmployerJobsScreen), findsOneWidget);
    });

    testWidgets('My jobs lists the applications, with where each stands, and a row opens its job', (tester) async {
      final board = await pumpBoard(tester);
      await tester.tap(find.text('My jobs'));
      await tester.pumpAndSettle();

      expect(board.repo.calls, contains('myJobs'));
      expect(find.text('Applied (3)'), findsOneWidget);
      expect(find.text('Saved (0)'), findsOneWidget);
      expect(find.textContaining('Interview • Applied 3d ago'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('my-jobs-saved')));
      await tester.pump();
      expect(find.text('Jobs you bookmark show up here.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('my-jobs-applied')));
      await tester.pump();

      await tester.tap(find.textContaining('Interview • Applied').first);
      await tester.pumpAndSettle();
      expect(find.text('JOB DETAILS'), findsOneWidget, reason: 'the job opened over the board');
    });

    testWidgets('My jobs leads on to the whole tracker, the saved jobs and the career hub, all in the app', (
      tester,
    ) async {
      final board = await pumpBoard(tester);
      await tester.tap(find.text('My jobs'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('my-jobs-see-all')));
      await tester.pumpAndSettle();
      expect(find.byType(MyApplicationsScreen), findsOneWidget);
      await tester.tap(find.byIcon(Symbols.arrow_back).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('My jobs'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('my-jobs-saved')));
      await tester.pump();
      await tester.tap(find.text('See all saved jobs'));
      await tester.pumpAndSettle();
      expect(find.byType(SavedJobsScreen), findsOneWidget);
      await tester.tap(find.byIcon(Symbols.arrow_back).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('My jobs'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('my-jobs-hub')));
      await tester.pumpAndSettle();
      expect(find.byType(CareerHubScreen), findsOneWidget);
      expect(board.links.opened, isEmpty, reason: 'nothing leaves the app');
    });

    testWidgets('the My jobs count is the open applications; the Alerts badge the new matches', (tester) async {
      await pumpBoard(tester);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2 new'), findsOneWidget);
    });

    testWidgets('Alerts runs the saved search and the badge goes', (tester) async {
      final board = await pumpBoard(tester);
      await tester.tap(find.text('Alerts'));
      await tester.pumpAndSettle();
      expect(board.repo.calls, contains('runAlert'));
      expect(find.text('2 new'), findsNothing);
      expect(board.jobs.newAlerts, 0);
    });

    testWidgets('Alerts scrolls the saved search\'s results into view', (tester) async {
      await pumpBoard(tester, size: const Size(390, 640));
      // The third section's heading is below the fold of a short screen.
      final heading = find.text('Recommended Jobs for You').last;
      expect(tester.getTopLeft(heading).dy, greaterThan(640));

      await tester.tap(find.text('Alerts'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(heading).dy, lessThan(640 - 100), reason: 'it is on the screen now');
    });

    testWidgets('Alerts with no saved search opens the form to make one, in the app', (tester) async {
      final repo = SpyJobsRepository()
        ..overviewAnswer = ((_) => JobsOverview(
          sections: [
            JobSection(key: 'latest', title: 'Latest jobs', jobs: [fakeJob('a')]),
          ],
        ));
      final board = await pumpBoard(tester, repo: repo);
      await tester.tap(find.text('Alerts'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(board.repo.calls, isNot(contains('runAlert')));
      expect(find.byType(JobAlertsScreen), findsOneWidget);
      expect(find.text('New job alert'), findsOneWidget);
      expect(board.links.opened, isEmpty);
    });
  });

  group('the scope bar', () {
    Finder scopeText() => find.textContaining('Facilities & Real Estate', findRichText: true);

    testWidgets('names the saved search and where, and its cross drops the scope', (tester) async {
      final board = await pumpBoard(tester);
      expect(scopeText(), findsOneWidget);
      expect(find.textContaining('Bengaluru, IN', findRichText: true), findsOneWidget);
      expect(find.text('Filters (3)'), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();

      expect(scopeText(), findsNothing);
      expect(board.repo.calls.last, 'overview scoped=false');
      expect(find.text('Filters (1)'), findsOneWidget, reason: 'the search\'s two filters went with its scope');
    });
  });

  group('the filters', () {
    testWidgets('the Filters sheet sets work mode, type and city on the search', (tester) async {
      final board = await pumpBoard(tester);
      await tester.tap(find.text('Filters (3)'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, 'Remote'));
      await tester.tap(find.widgetWithText(FilterChip, 'Contract'));
      await tester.enterText(
        find.descendant(of: find.byType(JobFiltersSheet), matching: find.byType(TextField)),
        ' Pune ',
      );
      await tester.pump();
      await tester.tap(find.text('Show jobs'));
      await tester.pumpAndSettle();

      final filters = board.repo.searches.last.filters;
      expect(filters.workModes, {WorkMode.remote});
      expect(filters.employmentTypes, {EmploymentType.contract});
      expect(filters.city, 'Pune');
      expect(
        find.text('Filters (5)'),
        findsOneWidget,
        reason: 'Easy Apply, remote, contract, Pune and the search\'s country',
      );
      expect(find.textContaining('Jobs matching your filters'), findsOneWidget);
    });

    testWidgets('Clear all in the sheet takes the filters off and keeps Easy Apply', (tester) async {
      final board = await pumpBoard(tester);
      await board.jobs.setFilters(const JobFilters(workModes: {WorkMode.remote}, easyApply: false));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Filters ('));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();
      expect(board.jobs.filters.workModes, isEmpty);
      expect(board.jobs.filters.easyApply, isFalse);
      expect(board.jobs.narrowed, isFalse);
    });

    testWidgets('Easy Apply hides the jobs that send people to the employer\'s site, and off shows them', (
      tester,
    ) async {
      final repo = boardOf([
        JobSection(
          key: 'foryou',
          title: 'Recommended Jobs for You',
          jobs: [
            fakeJob('a', title: 'On ICR'),
            fakeJob('b', title: 'On their site', easyApply: false, applyUrl: 'https://x.test/b'),
          ],
        ),
      ]);
      await pumpBoard(tester, repo: repo);
      expect(find.text('On ICR'), findsOneWidget);
      expect(find.text('On their site'), findsNothing);
      expect(find.text('Filters (1)'), findsOneWidget, reason: 'Easy Apply is a filter in force');
      expect(find.byIcon(LucideIcons.check), findsOneWidget, reason: 'the tick on the chip that is on');

      await tester.tap(find.text('Easy Apply'));
      await tester.pumpAndSettle();
      expect(find.text('On their site'), findsOneWidget);
      expect(find.byIcon(LucideIcons.check), findsNothing);
      expect(find.text('Filters (1)'), findsNothing);
      expect(find.text('Filters'), findsOneWidget, reason: 'no filter in force: no count');
    });

    testWidgets('with every job on the employer\'s site, Easy Apply says so and offers them all', (tester) async {
      final repo = boardOf([
        JobSection(
          key: 'foryou',
          title: 'Recommended Jobs for You',
          jobs: [fakeJob('b', title: 'On their site', easyApply: false, applyUrl: 'https://x.test/b')],
        ),
      ]);
      await pumpBoard(tester, repo: repo);
      expect(find.text('No Easy Apply jobs here'), findsOneWidget);
      await tester.tap(find.text('Show all jobs'));
      await tester.pumpAndSettle();
      expect(find.text('On their site'), findsOneWidget);
    });

    testWidgets('Date posted offers the periods, sets the search and shows what it is set to', (tester) async {
      final board = await pumpBoard(tester);
      await tester.tap(find.text('Date posted'));
      await tester.pumpAndSettle();
      for (final label in ['Any time', 'Past 24 hours', 'Past week', 'Past month']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('Past week'));
      await tester.pumpAndSettle();
      expect(board.repo.searches.last.filters.postedWithinDays, 7);
      expect(find.text('Past week'), findsOneWidget, reason: 'on the chip now');
      expect(find.text('Date posted'), findsNothing);

      await tester.tap(find.text('Past week'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('posted-0')));
      await tester.pumpAndSettle();
      expect(board.jobs.filters.postedWithinDays, isNull);
      expect(find.text('Date posted'), findsOneWidget);
    });

    testWidgets('In my network says it is not in the app and offers the website\'s network', (tester) async {
      final board = await pumpBoard(tester);
      await scrollTo(tester, find.text('In my network'));
      await tester.tap(find.text('In my network'));
      await tester.pumpAndSettle();
      expect(find.text("Jobs at companies in your network aren't in the app yet."), findsOneWidget);
      expect(board.links.opened, isEmpty, reason: 'nothing leaves the app until the member asks');

      await tester.tap(find.text('Open network'));
      await tester.pump();
      expect(board.links.paths, ['/network']);
    });

    testWidgets('a search is made inside the scope, and shows its results as one list', (tester) async {
      final board = await pumpBoard(tester);
      await tester.enterText(find.byType(TextField).first, 'stp');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(board.repo.searches.last.filters.search, 'stp');
      expect(board.repo.searches.last.scope?.label, 'Facilities & Real Estate');
      expect(find.text('Jobs matching "stp"'), findsOneWidget);
    });

    testWidgets('a search with no results says so, and Clear filters brings the board back', (tester) async {
      final repo = SpyJobsRepository()..searchAnswer = ((filters, page) => const JobPage(jobs: [], hasMore: false));
      final board = await pumpBoard(tester, repo: repo);
      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('No jobs match'), findsOneWidget);
      await board.jobs.setSearch('');
      await tester.pumpAndSettle();
      expect(find.text('No jobs match'), findsNothing);
    });
  });

  group('the sections', () {
    List<Job> jobs(String prefix, int n) => [for (var i = 0; i < n; i++) fakeJob('$prefix$i', title: 'Job $prefix$i')];

    testWidgets('each shows three rows and View More, as the design draws them', (tester) async {
      final board = await pumpBoard(tester);
      expect(board.jobs.sections, hasLength(3));
      expect(board.jobs.sections.map((s) => s.title), everyElement('Recommended Jobs for You'));
      expect(find.text('View More'), findsWidgets);
      for (final section in board.jobs.sections) {
        expect(board.jobs.visible(section), hasLength(3));
        expect(board.jobs.actionLabel(section), 'View More');
      }
    });

    testWidgets('View More shows the rest, then the next page, and Show Less folds it', (tester) async {
      final repo = boardOf([
        JobSection(key: 'alert', title: 'Facilities & Real Estate', jobs: jobs('a', 5), hasMore: true),
      ])..moreAnswer = ((section, page) => JobPage(jobs: [fakeJob('p$page', title: 'Page $page')], hasMore: false));
      await pumpBoard(tester, repo: repo);
      expect(find.byType(JobRow), findsNWidgets(3));

      await tester.tap(find.text('View More'));
      await tester.pumpAndSettle();
      expect(find.byType(JobRow), findsNWidgets(5));

      await tester.tap(find.text('View More'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('more alert 2'));
      expect(find.byType(JobRow), findsNWidgets(6));
      expect(find.text('Page 2'), findsOneWidget);

      await tester.tap(find.text('Show Less'));
      await tester.pumpAndSettle();
      expect(find.byType(JobRow), findsNWidgets(3));
      expect(find.text('View More'), findsOneWidget);
    });

    testWidgets('a bookmark is saved, shows it, and is taken back by the same tap', (tester) async {
      final board = await pumpBoard(tester);
      await tester.tap(rowBookmark(LucideIcons.bookmark));
      await tester.pump();
      expect(board.repo.saves.single.saved, isTrue);
      expect(rowBookmark(LucideIcons.bookmarkCheck), findsOneWidget);
      await tester.tap(rowBookmark(LucideIcons.bookmarkCheck));
      await tester.pump();
      expect(board.repo.saves.map((s) => s.saved), [true, false]);
      expect(find.byIcon(LucideIcons.bookmarkCheck), findsNothing);
    });

    testWidgets('a bookmark the API refuses is taken back, with the reason', (tester) async {
      final repo = SpyJobsRepository()..setSavedError = ApiError('Bookmarks are full.', statusCode: 403);
      await pumpBoard(tester, repo: repo);
      await tester.tap(rowBookmark(LucideIcons.bookmark));
      await tester.pump();
      await tester.pump();
      expect(find.text('Bookmarks are full.'), findsOneWidget);
      expect(find.byIcon(LucideIcons.bookmarkCheck), findsNothing);
    });

    testWidgets('pull to refresh reads the board again', (tester) async {
      final board = await pumpBoard(tester);
      expect(board.repo.calls.where((c) => c.startsWith('overview')), hasLength(1));
      await tester.fling(find.byType(CustomScrollView), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(board.repo.calls.where((c) => c.startsWith('overview')), hasLength(2));
    });

    testWidgets('a board that cannot load says so and tries again', (tester) async {
      final repo = SpyJobsRepository();
      var fail = true;
      repo.overviewAnswer = ((_) {
        if (fail) throw ApiError("Can't reach ICR right now.");
        return JobsOverview(
          sections: [
            JobSection(
              key: 'foryou',
              title: 'Recommended Jobs for You',
              jobs: [fakeJob('a', title: 'Job a')],
            ),
          ],
        );
      });
      await pumpBoard(tester, repo: repo);
      expect(find.text("Couldn't load jobs"), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Job a'), findsOneWidget);
    });
  });

  group('the job sheet', () {
    testWidgets('a row opens its job, in the design\'s slots: name, tagline, status, count, chips', (tester) async {
      final repo = SpyJobsRepository()
        ..detailAnswer = Job(
          id: 'j',
          title: 'Senior Facilities Manager',
          company: const JobCompany(
            id: 'c1',
            name: 'Global Infra Solutions',
            tagline: 'Commercial Real Estate Services',
            kind: 'Real Estate',
            size: '500+ employees',
            verified: true,
          ),
          city: 'Bengaluru',
          state: 'Karnataka',
          workMode: WorkMode.onsite,
          employmentType: EmploymentType.fullTime,
          salaryMin: 1800000,
          salaryMax: 2500000,
          openings: 2,
          postedAt: DateTime.now().subtract(const Duration(days: 3)),
          matchScore: 95,
        )
        ..matchSet = true;
      await pumpBoard(tester, repo: repo);
      await openFirstJob(tester);
      expect(find.text('Global Infra Solutions'), findsWidgets);
      expect(find.text('Commercial Real Estate Services'), findsOneWidget);
      expect(find.text('Accepting applications'), findsOneWidget);
      expect(find.text('Posted 3d ago'), findsOneWidget);
      expect(find.text('2 openings'), findsOneWidget);
      expect(find.text('₹18L - ₹25L / yr'), findsOneWidget);
      expect(find.text('95% Profile Match'), findsOneWidget);
    });

    testWidgets('a count the API gives its team is shown in the same slot', (tester) async {
      final repo = SpyJobsRepository()
        ..detailAnswer = Job(
          id: 'j',
          title: 'Mine',
          company: const JobCompany(id: 'c1', name: 'My Company'),
          applicants: 142,
          openings: 2,
          postedAt: DateTime.now().subtract(const Duration(days: 3)),
        );
      await pumpBoard(tester, repo: repo);
      await openFirstJob(tester);
      expect(find.text('142 applicants'), findsOneWidget);
      expect(find.text('2 openings'), findsNothing);
    });

    testWidgets('Share hands the title and link to the share sheet', (tester) async {
      final board = await pumpBoard(tester);
      await openFirstJob(tester);
      await tester.tap(find.byIcon(LucideIcons.share2));
      await tester.pump();
      expect(board.links.shared.single, 'Senior Facilities Manager\nhttps://icr.org.in/jobs');
    });

    testWidgets('the bookmark, in the header and in the bar, saves and un-saves, and the board follows', (
      tester,
    ) async {
      final repo = boardOf([
        JobSection(
          key: 'foryou',
          title: 'Recommended Jobs for You',
          jobs: [fakeJob('x1', title: 'Job x1')],
        ),
      ])..detailAnswer = fakeJob('x1', title: 'Job x1');
      final board = await pumpBoard(tester, repo: repo);
      await openFirstJob(tester);
      await tester.tap(inSheet(find.byIcon(LucideIcons.bookmark)));
      await tester.pump();
      expect(board.repo.saves.single.saved, isTrue);
      expect(inSheet(find.byIcon(LucideIcons.bookmarkCheck)), findsOneWidget);
      expect(inBar(find.byIcon(LucideIcons.bookmarkCheck)), findsOneWidget, reason: 'the bar keeps in step');
      expect(board.jobs.find('x1')!.saved, isTrue, reason: 'and the row behind the sheet');

      await tester.tap(inBar(find.byIcon(LucideIcons.bookmarkCheck)));
      await tester.pump();
      expect(board.repo.saves.map((s) => s.saved), [true, false]);
    });

    testWidgets('More offers to copy the link, or to open the job on the website', (tester) async {
      final board = await pumpBoard(tester);
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await openFirstJob(tester);

      await tester.tap(find.byIcon(LucideIcons.ellipsis));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy link'));
      await tester.pumpAndSettle();
      expect(copied, ['https://icr.org.in/jobs']);
      expect(find.text('Link copied'), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.ellipsis));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open on the ICR website'));
      await tester.pumpAndSettle();
      expect(board.links.opened.single.toString(), 'https://icr.org.in/jobs');
    });

    testWidgets('the match card counts what is met and its link opens the job on the website', (tester) async {
      final repo = SpyJobsRepository()
        ..matchSet = true
        ..matchAnswer = const JobMatch(
          locked: true,
          checks: [
            MatchCheck(
              label: '8+ years of experience',
              detail: 'Your résumé lists 9.4 years of experience.',
              met: true,
            ),
            MatchCheck(
              label: 'B.Tech / B.E. in Mechanical or Electrical',
              detail: 'Your profile lists B.Tech.',
              met: true,
            ),
            MatchCheck(
              label: 'RICS or IFMA Facility Management Charter',
              detail: 'Preferred credential. Not on your profile yet.',
              met: false,
            ),
          ],
        );
      final board = await pumpBoard(tester, repo: repo);
      await openFirstJob(tester);
      await scrollSheetTo(tester, find.text('Show comparative applicant insights'));
      expect(find.text('Your profile matches 2 of 3 requirements'), findsOneWidget);
      expect(find.text('8+ years of experience'), findsOneWidget);
      expect(find.text('Preferred credential. Not on your profile yet.'), findsOneWidget);

      await tester.tap(find.text('Show comparative applicant insights'));
      await tester.pump();
      expect(board.links.opened.single.toString(), 'https://icr.org.in/jobs');
    });

    testWidgets('a job with nothing to compare has no match card', (tester) async {
      final repo = SpyJobsRepository()..matchSet = true;
      await pumpBoard(tester, repo: repo);
      await openFirstJob(tester);
      expect(find.textContaining('Your profile matches'), findsNothing);
    });

    testWidgets('Message opens the conversation with the hiring contact, then its thread on the website', (
      tester,
    ) async {
      final board = await pumpBoard(tester);
      await openFirstJob(tester);
      await scrollSheetTo(tester, find.text('Message'));
      await tester.tap(find.text('Message'));
      await tester.pumpAndSettle();
      expect(board.repo.calls, contains('message'));
      expect(board.links.opened.single.toString(), 'https://icr.org.in/messaging?c=conv-1');
    });

    testWidgets('Message says why it could not, and opens nothing', (tester) async {
      final repo = SpyJobsRepository()..messageError = ApiError('This job has no one to message.', statusCode: 400);
      final board = await pumpBoard(tester, repo: repo);
      await openFirstJob(tester);
      await scrollSheetTo(tester, find.text('Message'));
      await tester.tap(find.text('Message'));
      await tester.pumpAndSettle();
      expect(find.text('This job has no one to message.'), findsOneWidget);
      expect(board.links.opened, isEmpty);
    });

    testWidgets('the faces open the company\'s People tab in the app, each with initials or a photo, and "+4"', (
      tester,
    ) async {
      final board = await pumpBoard(tester);
      await openFirstJob(tester);
      await scrollSheetTo(tester, find.text('+4'));
      expect(find.text('NM'), findsOneWidget);
      expect(find.text('AR'), findsOneWidget);
      await tester.tap(find.text('+4'));
      await tester.pumpAndSettle();
      expect(board.links.opened, isEmpty, reason: 'the app has the company page; the website is not opened');
      expect(find.byType(CompanyInsightsScreen), findsOneWidget);
      expect(find.text('2 people from Global Infra Solutions on ICR'), findsOneWidget);
    });

    testWidgets('+ Follow says companies cannot be followed yet, and opens the company\'s page in the app', (
      tester,
    ) async {
      final board = await pumpBoard(tester);
      await openFirstJob(tester);
      await scrollSheetTo(tester, find.text('+ Follow'));
      await tester.tap(find.text('+ Follow'));
      await tester.pumpAndSettle();
      expect(find.text(JobSheetBody.followNotice), findsOneWidget);
      expect(board.links.opened, isEmpty);
      expect(find.byType(CompanyInsightsScreen), findsOneWidget);
    });

    testWidgets('About the company shows the photo tile, the legal name and "kind • size"', (tester) async {
      await pumpBoard(tester);
      await openFirstJob(tester);
      await scrollSheetTo(tester, find.text('+ Follow'));
      expect(find.text('About Global Infra Solutions'), findsOneWidget);
      expect(find.text('Global Infra Solutions Ltd.'), findsOneWidget);
      expect(find.text('Real Estate Facilities • 8,400+ employees'), findsOneWidget);
    });
  });

  group('Easy Apply', () {
    Finder noteField() => find.byKey(const ValueKey('apply-note'));
    Finder phoneField() => find.byKey(const ValueKey('apply-phone'));

    Future<void> openApplyForm(WidgetTester tester) async {
      await tester.tap(inBar(find.text('Easy Apply')));
      await tester.pumpAndSettle();
    }

    testWidgets('asks for a note, sends the application, and the bar says Applied', (tester) async {
      final board = await pumpBoard(tester);
      await openFirstJob(tester);
      await openApplyForm(tester);
      expect(find.text('Mobile number'), findsNothing, reason: 'the profile has one');
      await tester.ensureVisible(noteField());
      await tester.enterText(noteField(), '  Keen to lead this.  ');
      await tester.tap(find.text('Submit application'));
      await tester.pumpAndSettle();

      final sent = board.repo.applications.single;
      expect(sent.note, '  Keen to lead this.  ', reason: 'the repository trims what it sends');
      expect(sent.phone, '');
      expect(find.text('Application sent to Global Infra Solutions.'), findsOneWidget);
      expect(inBar(find.text('Applied')), findsOneWidget);
      expect(board.jobs.myJobs, 4, reason: 'My jobs grows');
    });

    testWidgets('with no phone on file the form asks for one, refuses a short one, and sends the number', (
      tester,
    ) async {
      final repo = SpyJobsRepository()..phoneOnFile = false;
      await pumpBoard(tester, repo: repo);
      await openFirstJob(tester);
      await openApplyForm(tester);
      expect(find.text('Mobile number'), findsOneWidget);

      await tester.tap(find.text('Submit application'));
      await tester.pump();
      expect(find.text('Add the mobile number the employer can reach you on.'), findsOneWidget);
      expect(repo.applications, isEmpty);

      await tester.enterText(phoneField(), '+91 98765 43210');
      await tester.tap(find.text('Submit application'));
      await tester.pumpAndSettle();
      expect(repo.applications.single.phone, '+91 98765 43210');
    });

    testWidgets('a refusal for want of a number asks for it, though the profile seemed to have one', (tester) async {
      final repo = SpyJobsRepository()
        ..applyError = ApiError('Add a mobile number so the employer can reach you.', statusCode: 400);
      await pumpBoard(tester, repo: repo);
      await openFirstJob(tester);
      await openApplyForm(tester);
      expect(find.text('Mobile number'), findsNothing);

      await tester.tap(find.text('Submit application'));
      await tester.pumpAndSettle();
      expect(find.text('Add a mobile number so the employer can reach you.'), findsOneWidget);
      expect(find.text('Mobile number'), findsOneWidget, reason: 'the field is there now');

      repo.applyError = null;
      await tester.enterText(phoneField(), '+91 98765 43210');
      await tester.tap(find.text('Submit application'));
      await tester.pumpAndSettle();
      expect(repo.applications.last.phone, '+91 98765 43210');
      expect(inBar(find.text('Applied')), findsOneWidget);
    });

    testWidgets('any other refusal is shown in the form, which stays open', (tester) async {
      final repo = SpyJobsRepository()..applyError = ApiError('You have already applied to this job.', statusCode: 409);
      await pumpBoard(tester, repo: repo);
      await openFirstJob(tester);
      await openApplyForm(tester);
      await tester.tap(find.text('Submit application'));
      await tester.pumpAndSettle();
      expect(find.text('You have already applied to this job.'), findsOneWidget);
      expect(find.text('Submit application'), findsOneWidget);
      expect(inBar(find.text('Applied')), findsNothing);
    });

    testWidgets('a job that takes applications on the employer\'s site opens it, and sends nothing', (tester) async {
      final repo = SpyJobsRepository()
        ..detailAnswer = fakeJob(
          'ext',
          title: 'Estate Operations Manager',
          easyApply: false,
          applyUrl: 'https://careers.example.com/ext',
        );
      final board = await pumpBoard(tester, repo: repo);
      await openFirstJob(tester);
      expect(inBar(find.text('Apply on company site')), findsOneWidget);
      expect(inBar(find.text('Easy Apply')), findsNothing);

      await tester.tap(inBar(find.text('Apply on company site')));
      await tester.pumpAndSettle();
      expect(board.links.opened.single.toString(), 'https://careers.example.com/ext');
      expect(repo.applications, isEmpty);
      expect(find.text('Submit application'), findsNothing);
    });

    testWidgets('a job with screening questions asks them in the form, and sends the answers', (tester) async {
      final repo = SpyJobsRepository()
        ..detailAnswer = Job(
          id: 'q',
          title: 'Questions',
          company: const JobCompany(id: 'c', name: 'C'),
          screening: const [
            ScreeningQuestion(id: 'q1', prompt: 'Can you work night shifts?', type: ScreeningType.yesNo),
            ScreeningQuestion(id: 'q2', prompt: 'Years running a campus?', type: ScreeningType.years),
          ],
        );
      await pumpBoard(tester, repo: repo);
      await openFirstJob(tester);
      await openApplyForm(tester);
      expect(find.text('1. Can you work night shifts?'), findsOneWidget);

      await tester.tap(find.text('Submit application'));
      await tester.pump();
      expect(find.text('Answer the 2 questions above in the format they ask for.'), findsOneWidget);
      expect(repo.applications, isEmpty);

      await tester.tap(find.text('Yes'));
      await tester.pump();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 years').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit application'));
      await tester.pumpAndSettle();
      expect(repo.applications.single.answers, {'q1': 'true', 'q2': '3'});
    });

    testWidgets('a diversity-only role asks which group applies, refuses none, and sends the declaration', (
      tester,
    ) async {
      final repo = SpyJobsRepository()
        ..detailAnswer = Job(
          id: 'd',
          title: 'Women in FM',
          company: const JobCompany(id: 'c', name: 'C'),
          diversityOnly: true,
          diversityCategories: const ['WOMEN', 'WOMEN_RETURNING'],
        );
      await pumpBoard(tester, repo: repo);
      await openFirstJob(tester);
      await openApplyForm(tester);
      expect(
        find.text('This role accepts applications only from women or women returning to work candidates.'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Submit application'));
      await tester.tap(find.text('Submit application'));
      await tester.pump();
      expect(
        find.text('Choose the group that applies to you, or this role cannot take your application.'),
        findsOneWidget,
      );
      expect(repo.applications, isEmpty);

      await tester.tap(find.byKey(const ValueKey('apply-diversity-WOMEN_RETURNING')));
      await tester.pump();
      await tester.tap(find.text('Submit application'));
      await tester.pumpAndSettle();
      expect(repo.applications.single.diversityIdentities, ['WOMEN_RETURNING']);
    });

    testWidgets('a role for one gender asks for it, and sends the choice', (tester) async {
      final repo = SpyJobsRepository()
        ..detailAnswer = Job(
          id: 'g',
          title: 'Site supervisor',
          company: const JobCompany(id: 'c', name: 'C'),
          genderPreference: 'FEMALE',
        );
      await pumpBoard(tester, repo: repo);
      await openFirstJob(tester);
      await openApplyForm(tester);
      expect(find.text('This role accepts applications only from women.'), findsOneWidget);
      await tester.ensureVisible(find.text('Submit application'));
      await tester.tap(find.text('Submit application'));
      await tester.pump();
      expect(find.text('Choose your gender: this role is open to one gender only.'), findsOneWidget);
      expect(repo.applications, isEmpty);

      await tester.tap(find.byKey(const ValueKey('apply-gender-WOMAN')));
      await tester.pump();
      await tester.tap(find.text('Submit application'));
      await tester.pumpAndSettle();
      expect(repo.applications.single.gender, 'WOMAN');
    });

    testWidgets('a role for one gender that the API still refuses shows its sentence and keeps the choice', (
      tester,
    ) async {
      final repo = SpyJobsRepository()
        ..applyError = ApiError('This role accepts applications only from women.', statusCode: 400)
        ..detailAnswer = Job(
          id: 'g',
          title: 'Site supervisor',
          company: const JobCompany(id: 'c', name: 'C'),
          genderPreference: 'FEMALE',
        );
      await pumpBoard(tester, repo: repo);
      await openFirstJob(tester);
      await openApplyForm(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('apply-gender-MAN')));
      await tester.tap(find.byKey(const ValueKey('apply-gender-MAN')));
      await tester.pump();
      await tester.ensureVisible(find.text('Submit application'));
      await tester.tap(find.text('Submit application'));
      await tester.pumpAndSettle();
      expect(find.text('This role accepts applications only from women.'), findsWidgets);
      expect(find.text('Submit application'), findsOneWidget, reason: 'the form stays open');
    });

    testWidgets('a LinkedIn link is optional, checked as the API checks it, and sent when good', (tester) async {
      final repo = SpyJobsRepository();
      await pumpBoard(tester, repo: repo);
      await openFirstJob(tester);
      await openApplyForm(tester);
      await tester.enterText(find.byKey(const ValueKey('apply-linkedin')), 'example.com/in/me');
      await tester.ensureVisible(find.text('Submit application'));
      await tester.tap(find.text('Submit application'));
      await tester.pump();
      expect(find.text('Enter your LinkedIn profile link, such as linkedin.com/in/your-name.'), findsOneWidget);
      expect(repo.applications, isEmpty);

      await tester.enterText(find.byKey(const ValueKey('apply-linkedin')), 'linkedin.com/in/pooja-p');
      await tester.tap(find.text('Submit application'));
      await tester.pumpAndSettle();
      expect(repo.applications.single.linkedinUrl, 'linkedin.com/in/pooja-p');
    });

    testWidgets('a job already applied to cannot be applied to again', (tester) async {
      final repo = SpyJobsRepository()..detailAnswer = fakeJob('done', applied: true);
      await pumpBoard(tester, repo: repo);
      await openFirstJob(tester);
      expect(inBar(find.text('Applied')), findsOneWidget);
      await tester.tap(inBar(find.text('Applied')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Submit application'), findsNothing);
      expect(repo.applications, isEmpty);
    });
  });
}
