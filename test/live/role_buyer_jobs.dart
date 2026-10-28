/// Role matrix, part 3: Jobs and the career hub for the four accounts that belong to no company.
///
/// An application cannot be undone through the API (a withdrawn one stays in the person's history), so the
/// applications go to a posting this file makes as the seeded employer and deletes at the end, and are withdrawn
/// at once. The phone-needed step runs for the account with no number; the number it is given is taken off again.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/career/api_career_repository.dart';
import 'package:icr_mobile/features/career/career_hub_screen.dart';
import 'package:icr_mobile/features/career/interviews_screen.dart';
import 'package:icr_mobile/features/career/invitations_screen.dart';
import 'package:icr_mobile/features/career/job_alerts_screen.dart';
import 'package:icr_mobile/features/career/my_applications_screen.dart';
import 'package:icr_mobile/features/career/saved_jobs_screen.dart';
import 'package:icr_mobile/features/jobs/api_jobs_repository.dart';
import 'package:icr_mobile/features/jobs/employer/hiring_models.dart';
import 'package:icr_mobile/features/jobs/job_detail_controller.dart';
import 'package:icr_mobile/features/jobs/job_models.dart';
import 'package:icr_mobile/features/jobs/jobs_controller.dart';
import 'package:icr_mobile/features/jobs/jobs_screen.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';
import 'career_live_support.dart';
import '../jobs_fakes.dart' show RecordingLinks;
import 'jobs_employer_live_test.dart' show deleteAll, hiringAs, meera, readyDraft, titled;
import 'live.dart';
import 'role_buyer_support.dart';

final _jobs = <String, ApiJobsRepository>{};
ApiJobsRepository jobsOf(Who w) => _jobs.putIfAbsent(w.email, () => ApiJobsRepository(api: w.api));

final _careers = <String, ApiCareerRepository>{};
ApiCareerRepository careerOf(Who w) =>
    _careers.putIfAbsent(w.email, () => ApiCareerRepository(api: w.api, jobs: jobsOf(w)));

void roleBuyerJobs() {
  setUpAll(loadAppFonts);

  group('Jobs', () {
    liveTest('the board, search, filters, My jobs and the career shelves read for every account', () async {
      for (final w in await everyone()) {
        final jobs = jobsOf(w);
        final career = careerOf(w);
        final overview = await jobs.overview();
        expect(overview.sections, isNotEmpty, reason: '${w.email}: the board has sections');
        final latest = await jobs.latest();
        expect(latest.jobs, isNotEmpty, reason: '${w.email}: there are jobs to read');
        final first = latest.jobs.first;
        expect((await jobs.search(const JobFilters(search: 'manager', easyApply: false))).jobs, isNotEmpty);
        expect((await jobs.search(JobFilters(easyApply: false, workModes: {WorkMode.onsite}))), isNotNull);
        expect((await jobs.search(const JobFilters(easyApply: false, postedWithinDays: 30))), isNotNull);
        final detail = await jobs.detail(first.id);
        expect(detail.title, first.title);
        await jobs.match(detail);
        await jobs.peopleAt(detail.company);
        await jobs.myJobs();
        await jobs.quota();
        await jobs.resumes();
        expect(await jobs.newAlertMatches(), greaterThanOrEqualTo(0));
        expect(await jobs.unreadNotifications(), greaterThanOrEqualTo(0));
        // The career hub's shelves.
        await career.applications();
        await career.invites();
        await career.discoverable();
        await career.alerts();
        await career.savedJobs();
        await career.hiddenJobs();
        await career.shelfCounts();
        // Two reads a plan or a missing résumé can refuse; the hub shows its own sentence for each.
        for (final read in [career.resumeInsights, career.profilePerformance]) {
          try {
            await read();
          } catch (e) {
            expect(statusOf(e), anyOf(403, 402, 404), reason: '${w.email}: ${sentenceOf(e)}');
            record('Jobs: career hub read', w.person, 'refused correctly', sentenceOf(e));
          }
        }
        final company = await career.company(detail.company.id);
        expect(company, isNotNull);
        await career.ratingSummary(detail.company.id);
        await career.reviews(detail.company.id);
        await career.salaries(detail.company.id);
        await career.interviewReviews(detail.company.id);
        await career.people(detail.company.id);
        await career.companyJobs(detail.company.id);
        record('Jobs: board, search, filters, sheet, My jobs, career shelves, company page', w.person, 'works');
      }
    });

    liveTest('a bookmark, a hidden job and a saved search are kept and taken back for every account', () async {
      for (final w in await everyone()) {
        final jobs = jobsOf(w);
        final career = careerOf(w);
        final job = (await jobs.latest()).jobs.firstWhere((j) => !j.saved && !j.applied);

        await jobs.setSaved(job, true);
        expect((await career.savedJobs()).jobs.map((j) => j.id), contains(job.id));
        expect((await career.shelfCounts()).saved, greaterThan(0));
        await jobs.setSaved(job, false);
        expect((await career.savedJobs()).jobs.map((j) => j.id), isNot(contains(job.id)));

        await jobs.setHidden(job, true);
        expect((await career.hiddenJobs()).map((j) => j.id), contains(job.id));
        await jobs.setHidden(job, false);
        expect((await career.hiddenJobs()).map((j) => j.id), isNot(contains(job.id)));

        final name = 'zz role matrix ${DateTime.now().millisecondsSinceEpoch}';
        final made = await career.createAlert(name: name, criteria: const {'search': 'chiller'});
        try {
          expect((await career.alerts()).map((a) => a.id), contains(made.id));
          final off = await career.updateAlert(made.id, alertsEnabled: false, frequency: 'WEEKLY');
          expect(off.alertsEnabled, isFalse);
          await career.runAlert(made.id);
        } finally {
          await career.deleteAlert(made.id);
        }
        expect((await career.alerts()).map((a) => a.id), isNot(contains(made.id)));
        record('Jobs: save, hide, job alerts (create, switch off, run, delete)', w.person, 'works');
      }
    });

    liveTest(
      'Easy Apply: the phone-needed step, an application, a second refused, withdrawn (on a posting this test makes)',
      () async {
        final employer = await hiringAs(meera);
        final title = titled('role buyer apply');
        final jobId = await employer.createJob(readyDraft(title), PostingStatus.open);
        try {
          for (final w in await everyone()) {
            final jobs = jobsOf(w);
            final career = careerOf(w);
            final job = await jobs.detail(jobId);
            expect(job.easyApply, isTrue);
            expect(job.applied, isFalse);
            final controller = JobDetailController(repository: jobs, seed: job);
            await controller.load();
            final needsPhone = await controller.needsPhone();
            expect(
              needsPhone,
              w.phone == null,
              reason: '${w.email}: asked for a number only when the profile has none',
            );

            var phoneGiven = false;
            if (needsPhone) {
              final refused = await controller.apply(coverNote: 'Role matrix: no number yet.');
              expect(refused.ok, isFalse);
              expect(refused.needsPhone, isTrue);
              expect(refused.message, 'Add a mobile number so the employer can reach you.');
              final mine = await career.applications();
              expect(mine.map((a) => a.jobId), isNot(contains(jobId)), reason: 'nothing was written');
              record('Jobs: apply asks for a phone number first', w.person, 'works', 'refused with the API sentence');
            }
            try {
              final sent = await controller.apply(
                coverNote: 'Role matrix: sent from the app, withdrawn straight after.',
                phone: needsPhone ? '+91 98123 45670' : null,
              );
              phoneGiven = needsPhone;
              expect(sent.ok, isTrue, reason: '${w.email}: ${sent.message}');
              expect(controller.job.applied, isTrue);
              final mine = (await career.applications()).where((a) => a.jobId == jobId).toList();
              expect(mine, hasLength(1));
              expect(mine.single.stage, 'APPLIED');
              expect((await jobs.myJobs()).applications.map((a) => a.job.id), contains(jobId));
              final again = await controller.apply();
              expect(again.ok, isFalse);
              expect(again.message, 'You have already applied to this job.');
              final withdrawn = await career.withdraw(mine.single.id);
              expect(withdrawn.stage, 'WITHDRAWN');
              expect((await jobs.myJobs()).applications.map((a) => a.job.id), isNot(contains(jobId)));
              record(
                'Jobs: Easy Apply, a second refused, My jobs, Withdraw',
                w.person,
                'works',
                'on a posting made for the test',
              );
            } finally {
              if (phoneGiven) {
                // The number the application saved is taken off again, as the account had it.
                await w.api.dio.patch<dynamic>('/users/me', data: {'phone': ''});
              }
            }
          }
        } finally {
          await deleteAll(employer, [jobId]);
        }
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  });

  group('the Jobs screens, drawn for every account', () {
    testWidgets('the board draws its sections, chips and rows for every account', tags: const ['live'], (tester) async {
      if (!await liveScreenReady(tester)) return;
      for (final w in (await tester.runAsync(everyone))!) {
        final jobs = (await tester.runAsync(() async {
          final c = JobsController(jobsOf(w));
          await c.start();
          return c;
        }))!;
        expect(jobs.error, isNull, reason: '${w.email}: the board loaded');
        await loadScreen(
          tester,
          JobsScreen(onBack: () {}),
          providers: [ChangeNotifierProvider<JobsController>.value(value: jobs)],
          size: const Size(390, 1700),
        );
        final text = expectHealthy(tester, 'the Jobs board as ${w.email}');
        expect(text, contains('Post a job'));
        expect(text, contains('Alerts'));
        expect(text, contains('Easy Apply'));
        expect(jobs.sections, isNotEmpty);
        await unmount(tester);
        jobs.dispose();
        record('Jobs: board screen', w.person, 'works');
      }
    });

    testWidgets(
      'the career hub, My applications, Saved jobs, Job alerts, Invitations and Interviews draw for every account',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        for (final w in (await tester.runAsync(everyone))!) {
          final repo = careerOf(w);
          final screens = <String, Widget Function()>{
            'the career hub': () => CareerHubScreen(key: UniqueKey(), repository: repo, links: RecordingLinks()),
            'My applications': () => MyApplicationsScreen(key: UniqueKey(), repository: repo, links: RecordingLinks()),
            'Saved jobs': () => SavedJobsScreen(key: UniqueKey(), repository: repo, links: RecordingLinks()),
            'Job alerts': () => JobAlertsScreen(key: UniqueKey(), repository: repo, links: RecordingLinks()),
            'Invitations': () => InvitationsScreen(key: UniqueKey(), repository: repo, links: RecordingLinks()),
            'Interviews': () => InterviewsScreen(key: UniqueKey(), repository: repo, links: RecordingLinks()),
          };
          for (final entry in screens.entries) {
            await loadScreen(tester, entry.value(), size: const Size(390, 2400));
            // A plan can lock a figure (the hub's résumé strength, a timeline); the screen words the lock itself.
            expectHealthy(tester, '${entry.key} as ${w.email}', allow: const ['Career Pro']);
            await unmount(tester);
          }
          record('Jobs: career hub, applications, saved, alerts, invitations, interviews screens', w.person, 'works');
        }
      },
    );

    testWidgets(
      'on the board: open a job, Easy Apply (the form asks for a number only when the profile has none), Applied',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        final employer = (await tester.runAsync(() => hiringAs(meera)))!;
        final title = titled('role buyer sheet');
        final jobId = (await tester.runAsync(() => employer.createJob(readyDraft(title), PostingStatus.open)))!;
        try {
          for (final w in (await tester.runAsync(everyone))!) {
            final jobs = (await tester.runAsync(() async {
              final c = JobsController(jobsOf(w));
              await c.start();
              // A saved search scopes the board to its cities; the cross on its bar widens it to every job.
              await c.clearContext();
              await c.setSearch(title);
              return c;
            }))!;
            await loadScreen(
              tester,
              JobsScreen(onBack: () {}),
              providers: [ChangeNotifierProvider<JobsController>.value(value: jobs)],
              size: const Size(390, 1000),
            );
            expect(find.text(title), findsWidgets, reason: '${w.email}: the search finds the posting');
            await tester.tap(find.text(title).first);
            await afterTap(tester);
            expectHealthy(tester, 'the job sheet as ${w.email}');
            await tester.tap(find.text('Easy Apply').last);
            await afterTap(tester);
            final phone = find.byKey(const ValueKey('apply-phone'));
            final needsPhone = w.phone == null;
            expect(phone.evaluate().isNotEmpty, needsPhone, reason: '${w.email}: the form asks for a number or not');
            if (needsPhone) {
              // Submitting without it is refused on the form, in words; nothing is sent.
              await tester.tap(find.text('Submit application'));
              await tester.pump();
              expect(find.text('Add the mobile number the employer can reach you on.'), findsOneWidget);
              await tester.enterText(phone, '+91 98123 45670');
            }
            await tester.ensureVisible(find.text('Submit application'));
            await tester.tap(find.text('Submit application'));
            await afterTap(tester);
            expect(find.text('Applied'), findsWidgets, reason: '${w.email}: the bar reads Applied');
            final mine = (await tester.runAsync(() => careerOf(w).applications()))!.where((a) => a.jobId == jobId);
            expect(mine, hasLength(1), reason: '${w.email}: the API holds the application');
            await tester.runAsync(() => careerOf(w).withdraw(mine.single.id));
            if (needsPhone) {
              await tester.runAsync(() => w.api.dio.patch<dynamic>('/users/me', data: {'phone': ''}));
            }
            await unmount(tester);
            jobs.dispose();
            record(
              'Jobs: Easy Apply from the job sheet',
              w.person,
              'works',
              needsPhone ? 'the form asked for a number first, then sent' : 'sent with the number on file',
            );
          }
        } finally {
          await tester.runAsync(() => deleteAll(employer, [jobId]));
        }
      },
    );
  });
}
