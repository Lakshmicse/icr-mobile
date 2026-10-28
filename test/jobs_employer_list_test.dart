import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/jobs/employer/applicants_screen.dart';
import 'package:icr_mobile/features/jobs/employer/employer_jobs_screen.dart';
import 'package:icr_mobile/features/jobs/employer/hiring_models.dart';
import 'package:icr_mobile/features/jobs/employer/post_job_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'hiring_fakes.dart';
import 'helpers/fonts.dart';
import 'jobs_fakes.dart';

/// Every control of "Jobs you posted", tapped: what it does on the phone and what it asks of the API.
/// What the API does with them is proved in `test/live/jobs_employer_live_test.dart`.

Key _k(String key) => ValueKey(key);

Future<(SpyHiring, RecordingLinks, RecordingNavigation)> openJobs(
  WidgetTester tester, {
  SpyHiring? repo,
  PostingStatus? status,
  Size size = const Size(390, 2600),
}) async {
  final hiring = repo ?? SpyHiring();
  final nav = RecordingNavigation();
  final links = await openOnPhone(
    tester,
    (context, links) => EmployerJobsScreen(
      repository: hiring,
      links: links,
      navigation: nav.navigation,
      status: status,
      clock: hiringClock,
    ),
    size: size,
  );
  return (hiring, links, nav);
}

/// A posting with just what a test needs.
PostedJob posting(
  String id,
  String title, {
  PostingStatus status = PostingStatus.open,
  DateTime? deadline,
  DateTime? promotedUntil,
  PipelineCounts pipeline = const PipelineCounts(),
}) => PostedJob(
  id: id,
  title: title,
  status: status,
  createdAt: hiringNow.subtract(const Duration(days: 5)),
  cities: const ['Pune'],
  applyDeadline: deadline,
  promotedUntil: promotedUntil,
  pipeline: pipeline,
);

SpyHiring withPostings(List<PostedJob> list) {
  final repo = SpyHiring();
  repo.jobsAnswer = (q) async => PostedJobsPage(
    jobs: [
      for (final j in list)
        if (q.status == null || j.status == q.status) j,
    ],
    hasMore: false,
    statusCounts: {for (final j in list) j.status: list.where((x) => x.status == j.status).length},
  );
  return repo;
}

void main() {
  setUpAll(loadAppFonts);

  group('the list', () {
    testWidgets('shows the company\'s postings with the figures across them', (tester) async {
      await openJobs(tester);
      expect(find.text('Jobs you posted'), findsOneWidget);
      expect(find.byKey(_k('figures')), findsOneWidget);
      expect(find.descendant(of: find.byKey(_k('figure-open')), matching: find.text('2')), findsOneWidget);
      expect(find.text('1 closing soon'), findsOneWidget);
      expect(find.text('across 1 job'), findsOneWidget);
      for (final id in ['job-open', 'job-quiet', 'job-draft', 'job-returned', 'job-paused', 'job-closed']) {
        expect(find.byKey(_k('job-$id')), findsOneWidget, reason: id);
      }
    });

    testWidgets('the tabs count each status', (tester) async {
      await openJobs(tester);
      expect(find.text('All 6'), findsOneWidget);
      expect(find.text('Open 2'), findsOneWidget);
      expect(find.text('Drafts 2'), findsOneWidget);
      expect(find.text('In review 0'), findsOneWidget);
      expect(find.text('Paused 1'), findsOneWidget);
      expect(find.text('Closed 1'), findsOneWidget);
    });

    testWidgets('a tab narrows the list to its status, and All brings the rest back', (tester) async {
      final (repo, _, _) = await openJobs(tester);
      await tester.tap(find.byKey(_k('jobs-tab-draft')));
      await tester.pumpAndSettle();
      expect(repo.jobQueries.last.status, PostingStatus.draft);
      expect(find.byKey(_k('job-job-draft')), findsOneWidget);
      expect(find.byKey(_k('job-job-returned')), findsOneWidget);
      expect(find.byKey(_k('job-job-open')), findsNothing);
      await tester.tap(find.byKey(_k('jobs-tab-all')));
      await tester.pumpAndSettle();
      expect(repo.jobQueries.last.status, isNull);
      expect(find.byKey(_k('job-job-open')), findsOneWidget);
    });

    testWidgets('it can open on a tab', (tester) async {
      final (repo, _, _) = await openJobs(tester, status: PostingStatus.paused);
      expect(repo.jobQueries.first.status, PostingStatus.paused);
      expect(find.byKey(_k('job-job-paused')), findsOneWidget);
      expect(find.byKey(_k('job-job-open')), findsNothing);
    });

    testWidgets('the Open figure opens the Open tab', (tester) async {
      final (repo, _, _) = await openJobs(tester);
      await tester.tap(find.byKey(_k('figure-open')));
      await tester.pumpAndSettle();
      expect(repo.jobQueries.last.status, PostingStatus.open);
    });

    testWidgets('a search asks the API and clears with its cross', (tester) async {
      final (repo, _, _) = await openJobs(tester);
      await tester.enterText(find.byKey(_k('jobs-search')), 'energy');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(repo.jobQueries.last.search, 'energy');
      expect(find.byKey(_k('job-job-quiet')), findsOneWidget);
      expect(find.byKey(_k('job-job-open')), findsNothing);

      await tester.tap(find.byKey(_k('jobs-search-clear')));
      await tester.pumpAndSettle();
      expect(repo.jobQueries.last.search, '');
      expect(find.byKey(_k('job-job-open')), findsOneWidget);
    });

    testWidgets('a search that finds nothing says so, and Clear filters brings everything back', (tester) async {
      await openJobs(tester);
      await tester.enterText(find.byKey(_k('jobs-search')), 'zzz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.byKey(_k('jobs-empty')), findsOneWidget);
      expect(find.text('No jobs match'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.byKey(_k('jobs-empty')), findsNothing);
      expect(find.byKey(_k('job-job-open')), findsOneWidget);
    });

    testWidgets('Sort offers the four orders and asks the API for the one chosen', (tester) async {
      final (repo, _, _) = await openJobs(tester);
      await tester.tap(find.byKey(_k('jobs-sort')));
      await tester.pumpAndSettle();
      for (final label in ['Newest first', 'Closing soonest', 'Most applicants', 'Title A to Z']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      await tester.tap(find.text('Most applicants').last);
      await tester.pumpAndSettle();
      expect(repo.jobQueries.last.sort, 'applicants');
      expect(find.descendant(of: find.byKey(_k('jobs-sort')), matching: find.text('Most applicants')), findsOneWidget);
    });

    testWidgets('"Only jobs I started" asks for the member\'s own', (tester) async {
      final (repo, _, _) = await openJobs(tester);
      await tester.tap(find.byKey(_k('jobs-mine')));
      await tester.pumpAndSettle();
      expect(repo.jobQueries.last.mine, isTrue);
      await tester.tap(find.byKey(_k('jobs-mine')));
      await tester.pumpAndSettle();
      expect(repo.jobQueries.last.mine, isFalse);
    });

    testWidgets('"View More" brings the next page', (tester) async {
      final repo = SpyHiring();
      repo.jobsAnswer = (q) async => q.page == 1
          ? PostedJobsPage(
              jobs: [posting('a', 'First job')],
              hasMore: true,
              statusCounts: const {PostingStatus.open: 2},
            )
          : PostedJobsPage(
              jobs: [posting('b', 'Second job')],
              hasMore: false,
              statusCounts: const {PostingStatus.open: 2},
            );
      await openJobs(tester, repo: repo);
      expect(find.byKey(_k('job-a')), findsOneWidget);
      expect(find.byKey(_k('job-b')), findsNothing);
      await tester.tap(find.byKey(_k('view-more')));
      await tester.pumpAndSettle();
      expect(repo.jobQueries.last.page, 2);
      expect(find.byKey(_k('job-a')), findsOneWidget);
      expect(find.byKey(_k('job-b')), findsOneWidget);
      expect(find.byKey(_k('view-more')), findsNothing);
    });

    testWidgets('pulling down reads the list again', (tester) async {
      final (repo, _, _) = await openJobs(tester, size: const Size(390, 800));
      final before = repo.jobQueries.length;
      await tester.fling(find.byKey(_k('figures')), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(repo.jobQueries.length, greaterThan(before));
    });

    testWidgets('a list that cannot load says why, and tries again', (tester) async {
      final repo = SpyHiring()..failures['jobs'] = ApiError('We could not reach ICR.');
      await openJobs(tester, repo: repo);
      expect(find.byKey(_k('jobs-error')), findsOneWidget);
      expect(find.text('We could not reach ICR.'), findsOneWidget);
      repo.failures.remove('jobs');
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byKey(_k('jobs-error')), findsNothing);
      expect(find.byKey(_k('job-job-open')), findsOneWidget);
    });

    testWidgets('a company that never posted is asked to post its first', (tester) async {
      final repo = SpyHiring();
      repo.jobsAnswer = (q) async => const PostedJobsPage(jobs: [], hasMore: false);
      await openJobs(tester, repo: repo);
      expect(find.byKey(_k('first-job')), findsOneWidget);
      expect(find.text('Post your first job'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Post a job'));
      await tester.pumpAndSettle();
      expect(find.byType(PostJobScreen), findsOneWidget);
    });

    testWidgets('the bell opens the notifications', (tester) async {
      final (_, _, nav) = await openJobs(tester);
      await tester.tap(find.byIcon(LucideIcons.bell));
      await tester.pump();
      expect(nav.calls, ['bell']);
    });
  });

  group('each posting', () {
    testWidgets('says where it stands: status, deadline, applicants, and what is not viewed', (tester) async {
      await openJobs(tester);
      final open = find.byKey(_k('job-job-open'));
      expect(find.descendant(of: open, matching: find.text('Open')), findsOneWidget);
      expect(find.descendant(of: open, matching: find.text('Closes in 2 days')), findsOneWidget);
      expect(find.byKey(_k('applicants-line-job-open')), findsOneWidget);
      expect(find.text('9 applicants • 2 not viewed'), findsOneWidget);
      expect(find.text('No applicants yet'), findsWidgets);
      expect(find.descendant(of: open, matching: find.byKey(_k('pipeline-bar'))), findsOneWidget);
    });

    testWidgets('a draft offers to continue editing, not a pipeline', (tester) async {
      await openJobs(tester);
      final draft = find.byKey(_k('job-job-draft'));
      expect(find.descendant(of: draft, matching: find.text('Draft')), findsOneWidget);
      expect(find.byKey(_k('continue-job-draft')), findsOneWidget);
      expect(find.byKey(_k('open-applicants-job-draft')), findsNothing);
    });

    testWidgets('a draft that review sent back shows the reviewer\'s note', (tester) async {
      await openJobs(tester);
      expect(find.byKey(_k('returned-job-returned')), findsOneWidget);
      expect(find.text('ICR sent this back: Please add the salary range.'), findsOneWidget);
      expect(find.byKey(_k('returned-job-draft')), findsNothing);
    });

    testWidgets('the deadline is worded by how close it is', (tester) async {
      final today18 = DateTime(2026, 10, 26, 18);
      final repo = withPostings([
        posting('today', 'Closing today', deadline: today18),
        posting('soon', 'Closing soon', deadline: today18.add(const Duration(days: 5))),
        posting('later', 'Closing later', deadline: today18.add(const Duration(days: 10))),
        posting('late', 'Closed by date', deadline: today18.subtract(const Duration(days: 1))),
        posting(
          'paused',
          'Paused with date',
          status: PostingStatus.paused,
          deadline: today18.add(const Duration(days: 2)),
        ),
        posting('promo', 'Promoted job', promotedUntil: today18.add(const Duration(days: 20))),
      ]);
      await openJobs(tester, repo: repo);
      Finder pill(String id, String text) => find.descendant(of: find.byKey(_k('job-$id')), matching: find.text(text));
      expect(pill('today', 'Closes today'), findsOneWidget);
      expect(pill('soon', 'Closes in 5 days'), findsOneWidget);
      expect(pill('later', 'Closes 5 Nov'), findsOneWidget);
      expect(pill('late', 'Deadline passed 25 Oct'), findsOneWidget);
      expect(find.descendant(of: find.byKey(_k('job-paused')), matching: find.textContaining('Closes')), findsNothing);
      expect(pill('promo', 'Promoted'), findsOneWidget);
    });

    testWidgets('a posting shows where its applicants stand as one bar', (tester) async {
      final repo = withPostings([
        posting(
          'a',
          'With applicants',
          pipeline: const PipelineCounts(
            stages: {'APPLIED': 2, 'INTERVIEW': 1, 'HIRED': 1, 'WITHDRAWN': 4},
            unviewed: 1,
          ),
        ),
      ]);
      await openJobs(tester, repo: repo);
      expect(find.text('4 applicants • 1 not viewed'), findsOneWidget, reason: 'those who withdrew are not counted');
    });

    testWidgets('an item that needs attention opens that job\'s applicants', (tester) async {
      await openJobs(tester);
      expect(find.byKey(_k('attention-job-quiet')), findsOneWidget);
      expect(find.textContaining('No applicants yet after 17 days.'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byKey(_k('attention-job-quiet')), matching: find.text('Open')));
      await tester.pumpAndSettle();
      expect(find.byType(ApplicantsScreen), findsOneWidget);
      expect(find.text('Energy Manager'), findsOneWidget);
    });

    testWidgets('Applicants, and the posting itself, open the pipeline', (tester) async {
      final (repo, _, _) = await openJobs(tester);
      await tester.tap(find.byKey(_k('open-applicants-job-open')));
      await tester.pumpAndSettle();
      expect(find.byType(ApplicantsScreen), findsOneWidget);
      expect(repo.calls.any((c) => c.startsWith('applicants job-open')), isTrue);
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(of: find.byKey(_k('job-job-open')), matching: find.text('Facilities Operations Lead')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ApplicantsScreen), findsOneWidget);
    });

    testWidgets('a draft opens in the composer from its title and from Continue editing', (tester) async {
      await openJobs(tester);
      await tester.tap(find.byKey(_k('continue-job-draft')));
      await tester.pumpAndSettle();
      expect(find.byType(PostJobScreen), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(_k('job-title'))).controller!.text, 'Soft Services Supervisor');
    });
  });

  group('running a posting', () {
    Future<void> menu(WidgetTester tester, String id) async {
      await tester.tap(find.byKey(_k('job-menu-$id')));
      await tester.pumpAndSettle();
    }

    testWidgets('an open posting offers edit, pause, close, duplicate and delete', (tester) async {
      await openJobs(tester);
      await menu(tester, 'job-open');
      for (final item in ['Edit job', 'Pause', 'Close', 'Duplicate as draft', 'Delete']) {
        expect(find.text(item), findsOneWidget, reason: item);
      }
      expect(find.text('Resume'), findsNothing);
      expect(find.text('Reopen'), findsNothing);
    });

    testWidgets('a paused one offers resume, a closed one reopen, a draft neither pause nor close', (tester) async {
      await openJobs(tester);
      await menu(tester, 'job-paused');
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Pause'), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await menu(tester, 'job-closed');
      expect(find.text('Reopen'), findsOneWidget);
      expect(find.text('Close'), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await menu(tester, 'job-draft');
      expect(find.text('Pause'), findsNothing);
      expect(find.text('Close'), findsNothing);
      expect(find.text('Edit job'), findsOneWidget);
    });

    testWidgets('Promote is a payment: it is offered on a live posting that is not promoted, and opens the website', (
      tester,
    ) async {
      final repo = withPostings([
        posting('live', 'Live job'),
        posting('boosted', 'Boosted job', promotedUntil: DateTime(2026, 11, 20)),
        posting('held', 'Held job', status: PostingStatus.paused),
      ]);
      final (_, links, _) = await openJobs(tester, repo: repo);
      await menu(tester, 'live');
      await tester.tap(find.text('Promote'));
      await tester.pumpAndSettle();
      expect(links.paths, ['/manage/jobs']);

      await menu(tester, 'boosted');
      expect(find.text('Promote'), findsNothing, reason: 'already promoted');
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await menu(tester, 'held');
      expect(find.text('Promote'), findsNothing, reason: 'only a live posting can be promoted');
    });

    testWidgets('Edit job opens the composer on that posting', (tester) async {
      await openJobs(tester);
      await menu(tester, 'job-open');
      await tester.tap(find.text('Edit job'));
      await tester.pumpAndSettle();
      expect(find.byType(PostJobScreen), findsOneWidget);
      expect(find.text('Edit job'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(_k('job-title'))).controller!.text, 'Facilities Operations Lead');
    });

    testWidgets('Pause takes it off the board at once, and the counts follow', (tester) async {
      final (repo, _, _) = await openJobs(tester);
      await menu(tester, 'job-open');
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      expect(repo.statuses.single, (id: 'job-open', status: PostingStatus.paused));
      expect(find.text('“Facilities Operations Lead” is paused.'), findsOneWidget);
      expect(find.text('Paused 2'), findsOneWidget);
      expect(find.text('Open 1'), findsOneWidget);
    });

    testWidgets('Close asks first; Keep open does nothing, Close job closes it', (tester) async {
      final (repo, _, _) = await openJobs(tester);
      await menu(tester, 'job-open');
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byKey(_k('close-dialog')), findsOneWidget);
      await tester.tap(find.byKey(_k('close-keep')));
      await tester.pumpAndSettle();
      expect(repo.statuses, isEmpty);

      await menu(tester, 'job-open');
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_k('close-confirm')));
      await tester.pumpAndSettle();
      expect(repo.statuses.single, (id: 'job-open', status: PostingStatus.closed));
      expect(find.text('“Facilities Operations Lead” is closed.'), findsOneWidget);
      expect(find.text('Closed 2'), findsOneWidget);
    });

    testWidgets('Resume and Reopen open the posting again', (tester) async {
      final (repo, _, _) = await openJobs(tester);
      await menu(tester, 'job-paused');
      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();
      expect(repo.statuses.last, (id: 'job-paused', status: PostingStatus.open));
      expect(find.text('“Sustainability Analyst” is open again.'), findsOneWidget);

      await menu(tester, 'job-closed');
      await tester.tap(find.text('Reopen'));
      await tester.pumpAndSettle();
      expect(repo.statuses.last, (id: 'job-closed', status: PostingStatus.open));
      expect(find.text('Open 4'), findsOneWidget);
    });

    testWidgets("a refusal (the plan's room) is shown as worded and the posting stays as it was", (tester) async {
      final repo = SpyHiring()..failures['setStatus'] = ApiError('Your plan allows 2 live jobs. Close one or upgrade.');
      await openJobs(tester, repo: repo);
      await menu(tester, 'job-paused');
      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();
      expect(find.text('Your plan allows 2 live jobs. Close one or upgrade.'), findsOneWidget);
      expect(find.text('Paused 1'), findsOneWidget);
      expect(find.byKey(_k('job-menu-job-paused')), findsOneWidget, reason: 'the busy spinner is gone');
    });

    testWidgets('Duplicate makes a draft copy and opens it in the composer', (tester) async {
      final (repo, _, _) = await openJobs(tester);
      await menu(tester, 'job-open');
      await tester.tap(find.text('Duplicate as draft'));
      await tester.pumpAndSettle();
      expect(repo.created.single.status, PostingStatus.draft);
      expect(repo.created.single.draft.title, 'Facilities Operations Lead (copy)');
      expect(find.byType(PostJobScreen), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(_k('job-title'))).controller!.text,
        'Facilities Operations Lead (copy)',
      );
    });

    testWidgets('a copy that cannot be made says so', (tester) async {
      final repo = SpyHiring()..failures['createJob'] = ApiError('Not now.');
      await openJobs(tester, repo: repo);
      await menu(tester, 'job-open');
      await tester.tap(find.text('Duplicate as draft'));
      await tester.pumpAndSettle();
      expect(find.text('Not now.'), findsOneWidget);
      expect(find.byType(PostJobScreen), findsNothing);
    });

    testWidgets('Delete asks first; Keep leaves it, Delete removes it from the list', (tester) async {
      final (repo, _, _) = await openJobs(tester);
      await menu(tester, 'job-draft');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.byKey(_k('delete-dialog')), findsOneWidget);
      await tester.tap(find.byKey(_k('delete-keep')));
      await tester.pumpAndSettle();
      expect(repo.calls.where((c) => c.startsWith('deleteJob')), isEmpty);
      expect(find.byKey(_k('job-job-draft')), findsOneWidget);

      await menu(tester, 'job-draft');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_k('delete-confirm')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('deleteJob job-draft'));
      expect(find.byKey(_k('job-job-draft')), findsNothing);
      expect(find.text('“Soft Services Supervisor” was deleted.'), findsOneWidget);
      expect(find.text('Drafts 1'), findsOneWidget);
    });

    testWidgets('a delete the API refuses leaves the posting and says why', (tester) async {
      final repo = SpyHiring()..failures['deleteJob'] = ApiError('This posting cannot be deleted right now.');
      await openJobs(tester, repo: repo);
      await menu(tester, 'job-draft');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_k('delete-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('This posting cannot be deleted right now.'), findsOneWidget);
      expect(find.byKey(_k('job-job-draft')), findsOneWidget);
    });
  });

  group('posting a job from here', () {
    testWidgets('the plus opens the composer, and what was saved shows on the list when it closes', (tester) async {
      final (repo, _, _) = await openJobs(tester);
      await tester.tap(find.byKey(_k('post-job')));
      await tester.pumpAndSettle();
      expect(find.byType(PostJobScreen), findsOneWidget);
      await tester.enterText(find.byKey(_k('job-title')), 'Night Shift Supervisor');
      await tester.pump();
      await tester.ensureVisible(find.byKey(_k('save-draft')));
      await tester.tap(find.byKey(_k('save-draft')));
      await tester.pumpAndSettle();
      expect(repo.created.single.draft.title, 'Night Shift Supervisor');
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Night Shift Supervisor'), findsOneWidget);
      expect(find.text('Drafts 3'), findsOneWidget);
    });
  });

  group('anyone who is not on a hiring team', () {
    testWidgets('is told jobs are posted for a company, and offered one', (tester) async {
      final repo = SpyHiring(
        access: const HiringAccess(userId: 'me', role: 'PROFESSIONAL'),
      );
      final (_, links, nav) = await openJobs(tester, repo: repo);
      expect(find.byKey(_k('no-role')), findsOneWidget);
      expect(find.text('Posting jobs is for hiring teams'), findsOneWidget);
      expect(find.byKey(_k('figures')), findsNothing);
      await tester.tap(find.text('Set up a company'));
      await tester.pump();
      expect(nav.calls, ['create-company']);
      expect(links.opened, isEmpty);
    });

    testWidgets('a recruiter with no company is told the same', (tester) async {
      final repo = SpyHiring(
        access: const HiringAccess(userId: 'me', role: 'RECRUITER'),
      );
      await openJobs(tester, repo: repo);
      expect(find.byKey(_k('no-role')), findsOneWidget);
    });
  });

  group('who is shown the applicants of a posting', () {
    testWidgets('the screen carries the posting\'s title', (tester) async {
      await openJobs(tester);
      await tester.tap(find.byKey(_k('open-applicants-job-open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('applicants-job')), findsOneWidget);
      expect(find.text('Facilities Operations Lead'), findsWidgets);
    });
  });
}
