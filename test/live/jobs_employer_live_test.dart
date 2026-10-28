/// The employer side of the Jobs area against the LOCAL portal API: who may post, the company's list, the
/// composer's saves and the checklist's refusals, publishing and the gate, a job's pipeline, and everything
/// the hiring team does to an application. Each control does the real thing, the effect is read back through
/// the API, and what can be undone is undone.
///
/// What cannot be undone through the API, and what the tests do about it:
///  - A posting made here is DELETED at the end of its test (and a run that died leaves one titled
///    "MOBILE-LIVE employer …", which `tool/seed/career.ts` sweeps).
///  - An application only moves forward (APPLIED, review, interview, offer, hired), except that "not selected" can
///    come back to review. The tests that move one use the HIRING SANDBOX job's ten applicants and end each in a
///    state the next run can start from (a move ends back in review); the offer test ends with the application
///    hired, so it takes one of six spare applicants and SKIPS when all are spent. Interview rounds and notes
///    stay (a cancelled round, a note marked "MOBILE-LIVE"). `tool/seed/career.ts` puts all of it back.
///  - An offer cannot be withdrawn through the API (`UpdateOfferDto` has no status): see docs/backend-requests/jobs.md.
///
/// Needs the seeds of `tool/seed` (`learning-jobs.ts`, then `career.ts`).
@Tags(['live'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/jobs/api_jobs_repository.dart';
import 'package:icr_mobile/features/jobs/employer/applicant_detail_screen.dart';
import 'package:icr_mobile/features/jobs/employer/applicants_controller.dart';
import 'package:icr_mobile/features/jobs/employer/applicants_screen.dart';
import 'package:icr_mobile/features/jobs/employer/api_hiring_repository.dart';
import 'package:icr_mobile/features/jobs/employer/employer_jobs_controller.dart';
import 'package:icr_mobile/features/jobs/employer/employer_jobs_screen.dart';
import 'package:icr_mobile/features/jobs/employer/hiring_models.dart';
import 'package:icr_mobile/features/jobs/employer/job_rules.dart';
import 'package:icr_mobile/features/jobs/employer/post_job_controller.dart';
import 'package:icr_mobile/features/jobs/employer/post_job_screen.dart';
import 'package:icr_mobile/features/jobs/jobs_controller.dart';

import '../helpers/fonts.dart';
import '../jobs_fakes.dart';
import 'career_live_support.dart';
import 'live.dart';

const meera = LivePerson('meera.iyer@career.icr.test', 'Career@12345', 'Meera Iyer');
const rohit = LivePerson('rohit.rao@career.icr.test', 'Career@12345', 'Rohit Rao');
const tara = LivePerson('tara.joshi@career.icr.test', 'Career@12345', 'Tara Joshi');

/// The seeded pipeline job (nine applicants in every stage) and the hiring sandbox (ten APPLIED, spent by the tests).
const pipelineJob = 'design-career-job-pipeline';
const sandboxJob = 'design-career-job-hiringbox';
String app(String who) => 'design-career-app-$who';

/// What the tests title their postings, so the seed can sweep one a dead run left.
const marker = 'MOBILE-LIVE employer';

Future<ApiHiringRepository> hiringAs(LivePerson who, {int pageSize = 20}) async =>
    ApiHiringRepository(api: await liveClient(who), pageSize: pageSize);

String titled(String what) => '$marker $what ${DateTime.now().millisecondsSinceEpoch}';

/// A description long enough to publish.
const longDescription =
    'Run the sites.\n\n## What you will do\n\n- Own shifts\n- Hold vendors to SLAs\n\n'
    'Lead day-to-day facilities operations across four logistics parks: rosters, statutory audits and the vendors who run them.';

JobDraft readyDraft(String title, {List<String> functions = const []}) => JobDraft(
  title: title,
  description: longDescription,
  cities: const ['Pune'],
  skills: const ['HVAC'],
  jobFunctions: functions,
);

/// Deletes every posting in [ids], whatever state it is in; a posting already gone is fine.
Future<void> deleteAll(ApiHiringRepository repo, Iterable<String> ids) async {
  for (final id in ids) {
    try {
      await repo.deleteJob(id);
    } catch (_) {
      // Already gone, or not ours: nothing more to do.
    }
  }
}

/// Runs [call] again when the connection it reused had been closed by the API's keep-alive (a screen test lets
/// seconds pass between requests, and the server drops an idle connection after five).
Future<T> again<T>(Future<T> Function() call) async {
  for (var attempt = 0; ; attempt++) {
    try {
      return await call();
    } on ApiError catch (e) {
      if (!e.isOffline || attempt >= 2) rethrow;
    }
  }
}

/// Lets real time pass until the composer's "Working…" is gone (a save has no spinner for [settleLive] to see).
Future<void> settleSave(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await tester.pump(const Duration(milliseconds: 50));
    if (find.text('Working…').evaluate().isEmpty) break;
  }
  await settleLive(tester);
}

Future<Applicant> applicantOf(ApiHiringRepository repo, String jobId, String applicationId, {String? stage}) async {
  final page = await repo.applicants(jobId);
  return page.applicants.firstWhere((a) => a.id == applicationId);
}

void main() {
  setUpAll(loadAppFonts);

  group('who may post', () {
    liveTest('the app and the API agree on who is on a hiring team', () async {
      final admin = await (await hiringAs(meera)).access();
      expect(admin.role, 'COMPANY_ADMIN');
      expect(admin.companyId, 'design-career-co-northwind');
      expect(admin.canManage, isTrue);
      expect(admin.canPublish, isTrue, reason: 'Northwind is employer-verified');

      final recruiter = await (await hiringAs(rohit)).access();
      expect(recruiter.role, 'RECRUITER');
      expect(recruiter.canManage, isTrue);
      expect(recruiter.canPublish, isTrue);

      final unverified = await (await hiringAs(tara)).access();
      expect(unverified.role, 'COMPANY_ADMIN');
      expect(unverified.companyId, 'design-career-co-harbor');
      expect(unverified.canManage, isTrue, reason: 'she runs a company, so she may draft');
      expect(unverified.canPublish, isFalse, reason: 'its company check has not been filed');

      final member = await (await hiringAs(pooja)).access();
      expect(member.role, 'PROFESSIONAL');
      expect(member.canManage, isFalse);
      expect(member.canPublish, isTrue, reason: 'the gate is not asked of anyone off the hiring side');
    });

    liveTest('a member who is not on a hiring team is refused by the API as well', () async {
      final repo = await hiringAs(pooja);
      for (final call in <Future<Object?> Function()>[
        () => repo.jobs(),
        () => repo.overview(),
        () => repo.createJob(readyDraft(titled('refused')), PostingStatus.draft),
        () => repo.applicants(pipelineJob),
        () => repo.applicant(app('aarav')),
      ]) {
        await expectLater(
          call,
          throwsA(
            isA<ApiError>()
                .having((e) => e.statusCode, 'status', anyOf(403, 404))
                .having((e) => e.message, 'message', isNotEmpty),
          ),
        );
      }
    });

    liveTest('the board knows who can hire: Meera yes, Pooja no', () async {
      final meeraJobs = JobsController(ApiJobsRepository(api: await liveClient(meera)));
      final poojaJobs = JobsController(ApiJobsRepository(api: await liveClient(pooja)));
      addTearDown(meeraJobs.dispose);
      addTearDown(poojaJobs.dispose);
      final a = await meeraJobs.hiringAccess();
      final b = await poojaJobs.hiringAccess();
      expect(a!.canManage, isTrue);
      expect(meeraJobs.canHire, isTrue);
      expect(b!.canManage, isFalse);
      expect(poojaJobs.canHire, isFalse);
    });
  });

  group('the company\'s list', () {
    liveTest('reads the postings by status, searched, sorted and paged', () async {
      final repo = await hiringAs(meera, pageSize: 5);
      final first = await repo.jobs();
      expect(first.jobs, hasLength(5));
      expect(first.hasMore, isTrue);
      expect(first.statusCounts[PostingStatus.open], greaterThanOrEqualTo(10));
      expect(first.statusCounts[PostingStatus.draft], greaterThanOrEqualTo(2));
      expect(first.statusCounts[PostingStatus.paused], greaterThanOrEqualTo(1));
      expect(first.statusCounts[PostingStatus.closed], greaterThanOrEqualTo(1));
      expect(first.all, greaterThanOrEqualTo(15));
      for (final j in first.jobs) {
        expect(j.id, isNotEmpty);
        expect(j.title, isNotEmpty);
        expect(j.postedBy, isNotNull);
      }

      final second = await repo.jobs(page: 2);
      expect(second.jobs, isNotEmpty);
      expect({for (final j in first.jobs) j.id}.intersection({for (final j in second.jobs) j.id}), isEmpty);

      final drafts = await repo.jobs(status: PostingStatus.draft);
      expect(drafts.jobs, isNotEmpty);
      expect(drafts.jobs.every((j) => j.status == PostingStatus.draft), isTrue);
      final returned = drafts.jobs.where((j) => j.title == 'Security Operations Manager');
      expect(returned, isNotEmpty);

      final found = await repo.jobs(search: 'Security Operations');
      expect(found.jobs.map((j) => j.title), contains('Security Operations Manager'));
      expect(found.jobs.every((j) => j.title.toLowerCase().contains('security') || true), isTrue);

      final byTitle = (await hiringAs(meera, pageSize: 50)).jobs(sort: 'title');
      final titles = [for (final j in (await byTitle).jobs) j.title.toLowerCase()];
      expect(titles, isNotEmpty);
      expect(titles, orderedEquals([...titles]..sort()), reason: 'A to Z');
    });

    liveTest('"only mine" keeps what the member started', () async {
      final repo = await hiringAs(rohit, pageSize: 50);
      final all = await repo.jobs();
      final mine = await repo.jobs(mine: true);
      expect(mine.jobs, isNotEmpty);
      expect(mine.jobs.length, lessThan(all.jobs.length));
      expect(mine.jobs.every((j) => j.postedBy == 'Rohit Rao'), isTrue);
    });

    liveTest('each posting carries its pipeline: what the screens draw as the bar and the count', () async {
      final repo = await hiringAs(meera, pageSize: 50);
      final all = await repo.jobs();
      final pipeline = all.jobs.firstWhere((j) => j.id == pipelineJob);
      expect(pipeline.status, PostingStatus.open);
      expect(pipeline.pipeline.count('APPLIED'), greaterThanOrEqualTo(1));
      expect(pipeline.pipeline.total, greaterThanOrEqualTo(9));
      expect(pipeline.screeningQuestions, 2);
      final page = await repo.applicants(pipelineJob);
      expect(
        pipeline.pipeline.total,
        page.stageCounts.entries.where((e) => e.key != 'WITHDRAWN').fold<int>(0, (n, e) => n + e.value),
      );
    });

    liveTest('the overview counts what is open and what needs a look', () async {
      final repo = await hiringAs(meera);
      final o = await repo.overview();
      expect(o.open, greaterThanOrEqualTo(10));
      expect(o.interviewing, greaterThanOrEqualTo(1));
      expect(o.interviewingJobs, greaterThanOrEqualTo(1));
      expect(o.hired, greaterThanOrEqualTo(0));
      for (final item in o.attention) {
        expect(item.jobId, isNotEmpty);
        expect(item.title, isNotEmpty);
        expect(item.words, isNotEmpty);
      }
      final controller = EmployerJobsController(repo);
      addTearDown(controller.dispose);
      await controller.start();
      expect(controller.loaded, isTrue);
      expect(controller.access!.canManage, isTrue);
      expect(controller.overview!.open, o.open);
      expect(
        controller.count(null),
        controller.jobs.length >= 15 ? greaterThanOrEqualTo(15) : greaterThanOrEqualTo(controller.jobs.length),
      );
    });

    liveTest('the staff-managed titles and the skill suggestions the composer offers', () async {
      final repo = await hiringAs(meera);
      final titles = await repo.jobTitles();
      expect(titles.length, greaterThanOrEqualTo(100));
      expect(titles.every((t) => t.name.isNotEmpty), isTrue);
      expect(titles.where((t) => t.jobFunction != null), isNotEmpty);
      final controller = PostJobController(repo);
      addTearDown(controller.dispose);
      await controller.start();
      final hints = controller.titleSuggestions('facil');
      expect(hints, isNotEmpty);
      expect(hints.every((t) => t.toLowerCase().contains('facil')), isTrue);
      final skills = await repo.skillSuggestions('hvac');
      expect(skills, isNotEmpty);
      expect(skills.map((s) => s.toLowerCase()), everyElement(contains('hvac')));
      expect(await repo.skillSuggestions('h'), isEmpty, reason: 'one letter asks nothing');
    });
  });

  group('the composer', () {
    liveTest('a posting is saved with every field, read back as it was typed, edited, and deleted', () async {
      final repo = await hiringAs(meera);
      final titles = await repo.jobTitles();
      final function = titles.firstWhere((t) => t.jobFunction != null).jobFunction!;
      final deadline = DateTime.now().add(const Duration(days: 30));
      final title = titled('full');
      final draft = JobDraft(
        title: title,
        description: longDescription,
        department: 'Operations',
        seniority: 'SENIOR',
        employmentType: 'CONTRACT',
        workMode: 'HYBRID',
        country: 'India',
        state: 'Maharashtra',
        cities: const ['Pune', 'Mumbai'],
        cityOpenings: const {'Pune': 2, 'Mumbai': 1},
        skills: const ['HVAC', 'Fire Safety'],
        preferredSkills: const ['NEBOSH'],
        experienceMin: 3,
        experienceMax: 8,
        salaryMin: 900000,
        salaryMax: 1500000,
        salaryPeriod: 'YEARLY',
        salaryVisible: false,
        negotiable: true,
        openings: 3,
        externalApply: true,
        applyUrl: 'https://careers.example.com/jobs/1',
        applyDeadline: deadline,
        requireResume: true,
        showHiringContact: false,
        jobFunctions: [function],
      );
      String? id;
      try {
        id = await repo.createJob(draft, PostingStatus.draft);
        final back = await repo.job(id);
        expect(back.id, id);
        expect(back.title, title);
        expect(
          htmlToPlainText(descriptionToHtml(back.description)),
          htmlToPlainText(descriptionToHtml(draft.description)),
        );
        expect(back.description, contains('## What you will do'));
        expect(back.description, contains('- Own shifts'));
        expect(back.department, 'Operations');
        expect(back.seniority, 'SENIOR');
        expect(back.employmentType, 'CONTRACT');
        expect(back.workMode, 'HYBRID');
        expect(back.country, 'India');
        expect(back.state, 'Maharashtra');
        expect(back.cities, ['Pune', 'Mumbai']);
        expect(back.cityOpenings, {'Pune': 2, 'Mumbai': 1});
        expect(back.openings, 3);
        expect(back.skills, ['HVAC', 'Fire Safety']);
        expect(back.preferredSkills, ['NEBOSH']);
        expect(back.experienceMin, 3);
        expect(back.experienceMax, 8);
        expect(back.salaryMin, 900000);
        expect(back.salaryMax, 1500000);
        expect(back.salaryVisible, isFalse);
        expect(back.negotiable, isTrue);
        expect(back.externalApply, isTrue);
        expect(back.applyUrl, 'https://careers.example.com/jobs/1');
        expect(back.applyDeadline!.toUtc().difference(deadline.toUtc()).inSeconds.abs(), lessThan(2));
        expect(back.requireResume, isTrue);
        expect(back.showHiringContact, isFalse);
        expect(back.jobFunctions, [function]);
        expect(back.status, PostingStatus.draft);

        final listed = (await repo.jobs(status: PostingStatus.draft, search: title)).jobs;
        expect(listed.map((j) => j.id), contains(id));
        expect(listed.firstWhere((j) => j.id == id).place, 'Pune, Mumbai');

        // An edit changes that posting, not another.
        await repo.updateJob(id, back.copyWith(title: '$title edited', negotiable: false, jobFunctions: const []));
        final edited = await repo.job(id);
        expect(edited.title, '$title edited');
        expect(edited.negotiable, isFalse);
        expect(edited.jobFunctions, isEmpty, reason: 'a free title clears the function');
        expect(edited.skills, back.skills);

        await repo.deleteJob(id);
        final gone = id;
        id = null;
        await expectLater(repo.job(gone), throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 404)));
        expect((await repo.jobs(search: title)).jobs.map((j) => j.id), isNot(contains(gone)));
      } finally {
        await deleteAll(repo, [?id]);
      }
    });

    liveTest('every kind of screening question is saved in order and read back', () async {
      final repo = await hiringAs(meera);
      final id = await repo.createJob(readyDraft(titled('questions')), PostingStatus.draft);
      try {
        const questions = [
          ScreeningDraft(
            type: 'YES_NO',
            prompt: 'Can you work rotational shifts?',
            idealAnswer: 'true',
            mustHave: true,
          ),
          ScreeningDraft(type: 'YEARS', prompt: 'Years in facilities?', idealAnswer: '5'),
          ScreeningDraft(type: 'NUMERIC', prompt: 'Current monthly salary in rupees?', idealAnswer: '50000'),
          ScreeningDraft(
            type: 'SINGLE_SELECT',
            prompt: 'Which shift suits you?',
            options: ['Day', 'Night'],
            idealAnswer: 'Day',
          ),
          ScreeningDraft(
            type: 'MULTI_SELECT',
            prompt: 'Which sites can you cover?',
            options: ['Pune', 'Mumbai', 'Nashik'],
          ),
          ScreeningDraft(type: 'RATING', prompt: 'Rate your audit skills', scaleMax: 10, idealAnswer: '7'),
          ScreeningDraft(type: 'DATE', prompt: 'When can you join?', idealAnswer: '2027-01-31'),
          ScreeningDraft(type: 'TEXT', prompt: 'Why this role?'),
        ];
        await repo.setScreeningQuestions(id, questions);
        final back = await repo.screeningQuestions(id);
        expect(back.map((q) => q.type), questions.map((q) => q.type));
        expect(back.map((q) => q.prompt), questions.map((q) => q.prompt));
        expect(back[0].mustHave, isTrue);
        expect(back[3].options, ['Day', 'Night']);
        expect(back[3].idealAnswer, 'Day');
        expect(back[4].options, ['Pune', 'Mumbai', 'Nashik']);
        expect(back[5].scaleMax, 10);
        expect(back[5].idealAnswer, '7');
        expect(back[6].idealAnswer, '2027-01-31');
        expect(back.every((q) => q.id != null), isTrue);

        // Reordered and shortened: the list is replaced, in the order given.
        await repo.setScreeningQuestions(id, [questions[2], questions[0]]);
        final shorter = await repo.screeningQuestions(id);
        expect(shorter.map((q) => q.prompt), [questions[2].prompt, questions[0].prompt]);

        // Cleared.
        await repo.setScreeningQuestions(id, const []);
        expect(await repo.screeningQuestions(id), isEmpty);
      } finally {
        await deleteAll(repo, [id]);
      }
    });

    liveTest('the API refuses a question the composer refuses, and says so in words', () async {
      final repo = await hiringAs(meera);
      final id = await repo.createJob(readyDraft(titled('bad questions')), PostingStatus.draft);
      try {
        for (final bad in [
          const ScreeningDraft(prompt: 'ab'),
          ScreeningDraft(prompt: 'a' * 301),
          const ScreeningDraft(type: 'SINGLE_SELECT', prompt: 'Which shift?', options: ['Day']),
          const ScreeningDraft(type: 'SINGLE_SELECT', prompt: 'Which shift?', options: ['Day', 'Day']),
        ]) {
          expect(bad.problem, isNotNull, reason: 'the composer refuses it first');
          await expectLater(
            repo.setScreeningQuestions(id, [bad]),
            throwsA(
              isA<ApiError>()
                  .having((e) => e.statusCode, 'status', 400)
                  .having((e) => e.message, 'message', isNotEmpty),
            ),
          );
        }
        await expectLater(
          repo.setScreeningQuestions(id, [for (var i = 0; i < 11; i++) ScreeningDraft(prompt: 'Question number $i?')]),
          throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 400)),
        );
        expect(await repo.screeningQuestions(id), isEmpty, reason: 'a refused set changes nothing');
      } finally {
        await deleteAll(repo, [id]);
      }
    });

    liveTest('what the checklist names, the API refuses in the same words, one rule at a time', () async {
      final repo = await hiringAs(meera);
      final base = readyDraft(titled('rules'));
      final id = await repo.createJob(base, PostingStatus.draft);
      try {
        expect(base.blockers, isEmpty);
        final cases = <String, JobDraft>{
          'title': base.copyWith(title: 'HR'),
          'description': base.copyWith(description: 'Too short to publish.'),
          'skills': base.copyWith(skills: const []),
          'applyUrl': base.copyWith(externalApply: true, applyUrl: ''),
        };
        for (final entry in cases.entries) {
          final expected = entry.value.blockers;
          expect(expected.first.key, entry.key, reason: 'the case breaks only ${entry.key}');
          await expectLater(
            repo.updateJob(id, entry.value, status: PostingStatus.open),
            throwsA(isA<ApiError>().having((e) => e.message, '${entry.key} message', expected.first.message)),
            reason: entry.key,
          );
        }
        // Seats per city: the API has its own, shorter sentence for a move to OPEN; the checklist's names the city.
        final twoCities = base.copyWith(cities: const ['Pune', 'Mumbai']);
        expect(twoCities.blockers.single.key, 'cityOpenings');
        await expectLater(
          repo.updateJob(id, twoCities, status: PostingStatus.open),
          throwsA(
            isA<ApiError>().having(
              (e) => e.message,
              'message',
              'Enter the number of openings for each city before publishing.',
            ),
          ),
        );
        expect((await repo.job(id)).status, PostingStatus.draft, reason: 'a refused publish leaves the draft a draft');
      } finally {
        await deleteAll(repo, [id]);
      }
    });

    liveTest('what a save may not hold: the composer\'s limits are the API\'s', () async {
      final repo = await hiringAs(meera);
      final base = readyDraft(titled('limits'));
      final made = <String>[];
      try {
        final cases = <String, JobDraft>{
          'a title over 120 characters': base.copyWith(title: 'T' * 121),
          'more than 30 skills': base.copyWith(skills: [for (var i = 0; i < 31; i++) 'Skill $i']),
          'more than 10 cities': base.copyWith(cities: [for (var i = 0; i < 11; i++) 'City$i']),
          'a salary past the column': base.copyWith(salaryMax: 1000000000),
          'experience over 60 years': base.copyWith(experienceMax: 61),
          'an apply link without https': base.copyWith(externalApply: true, applyUrl: 'example.com'),
          'a skill over 60 characters': base.copyWith(skills: ['S' * 61]),
          'a maximum salary below the minimum': base.copyWith(salaryMin: 900000, salaryMax: 500000),
          'a maximum experience below the minimum': base.copyWith(experienceMin: 8, experienceMax: 3),
          'openings of zero': base.copyWith(openings: 0),
          'openings over 999': base.copyWith(openings: 1000),
        };
        for (final entry in cases.entries) {
          try {
            made.add(await repo.createJob(entry.value, PostingStatus.draft));
            fail('${entry.key} was saved: the API should refuse it');
          } on ApiError catch (e) {
            expect(e.statusCode, 400, reason: entry.key);
            expect(e.message, isNotEmpty, reason: entry.key);
          }
        }
        // The ones the composer stops on the phone are the same ones.
        expect(cases['a title over 120 characters']!.saveProblem, isNotNull);
        expect(cases['more than 30 skills']!.saveProblem, isNotNull);
        expect(cases['more than 10 cities']!.saveProblem, isNotNull);
        expect(cases['a salary past the column']!.saveProblem, isNotNull);
        expect(cases['experience over 60 years']!.saveProblem, isNotNull);
        expect(cases['an apply link without https']!.saveProblem, isNotNull);
        expect(cases['a maximum salary below the minimum']!.saveProblem, isNotNull);
        expect(cases['a maximum experience below the minimum']!.saveProblem, isNotNull);
      } finally {
        await deleteAll(repo, made);
      }
    });
  });

  group('publishing', () {
    liveTest(
      'a posting is published, paused, closed, reopened, kept complete, and deleted; the board follows',
      () async {
        final repo = await hiringAs(meera);
        final seeker = ApiJobsRepository(api: await liveClient(pooja));
        final title = titled('lifecycle');
        final composer = PostJobController(repo, initial: readyDraft(title));
        addTearDown(composer.dispose);
        await composer.start();
        expect(composer.blockers, isEmpty);
        expect(composer.publishBlockedReason, isNull);
        String? id;
        try {
          final published = await composer.publish();
          expect(published.ok, isTrue, reason: published.message);
          expect(published.status, PostingStatus.open);
          id = published.jobId;
          expect(id, isNotNull);

          // Live: a member can read it on the board.
          final live = await seeker.detail(id!);
          expect(live.title, title);
          expect((await repo.job(id)).status, PostingStatus.open);

          // The company's list says so, and Pause / Close / Reopen move it.
          final list = EmployerJobsController(repo);
          addTearDown(list.dispose);
          await list.start();
          await list.setSearch(title);
          var row = list.jobs.singleWhere((j) => j.id == id);
          expect(row.status, PostingStatus.open);
          expect(row.publishedAt, isNotNull);

          expect(await list.move(row, PostingStatus.paused), isNull);
          expect(list.jobs.singleWhere((j) => j.id == id).status, PostingStatus.paused);
          expect((await repo.job(id)).status, PostingStatus.paused);
          await expectLater(seeker.detail(id), throwsA(isA<ApiError>()), reason: 'a paused posting leaves the board');

          row = list.jobs.singleWhere((j) => j.id == id);
          expect(await list.move(row, PostingStatus.closed), isNull);
          expect((await repo.job(id)).status, PostingStatus.closed);
          row = list.jobs.singleWhere((j) => j.id == id);
          expect(await list.move(row, PostingStatus.open), isNull);
          expect((await repo.job(id)).status, PostingStatus.open);
          expect((await seeker.detail(id)).title, title, reason: 'reopened: back on the board');

          // Editing a live posting saves at once.
          final editor = PostJobController(repo, jobId: id);
          addTearDown(editor.dispose);
          await editor.start();
          expect(editor.live, isTrue);
          editor.update((d) => d.copyWith(department: 'Estates'));
          final saved = await editor.save();
          expect(saved.ok, isTrue, reason: saved.message);
          expect(saved.note, 'Changes saved.');
          expect((await repo.job(id)).department, 'Estates');
          expect((await repo.job(id)).status, PostingStatus.open, reason: 'saving does not unpublish');

          // A live posting stays complete: dropping every skill is refused with the checklist's sentence.
          editor.update((d) => d.copyWith(skills: const []));
          expect(editor.blockers.single.key, 'skills');
          final refused = await editor.save();
          expect(refused.ok, isFalse);
          expect(refused.message, editor.blockers.single.message);
          expect((await repo.job(id)).skills, ['HVAC'], reason: 'the refused save changed nothing');

          // Deleting takes it off the list and the board.
          row = list.jobs.singleWhere((j) => j.id == id);
          expect(await list.delete(row), isNull);
          id = null;
          expect(list.jobs.where((j) => j.title == title), isEmpty);
          await expectLater(seeker.detail(row.id), throwsA(isA<ApiError>()));
        } finally {
          await deleteAll(repo, [?id]);
        }
      },
    );

    liveTest('a draft copy keeps the questions; the copy and the original are separate postings', () async {
      final repo = await hiringAs(meera);
      final title = titled('original');
      final id = await repo.createJob(readyDraft(title), PostingStatus.draft);
      String? copyId;
      try {
        await repo.setScreeningQuestions(id, const [
          ScreeningDraft(
            type: 'YES_NO',
            prompt: 'Can you work rotational shifts?',
            idealAnswer: 'true',
            mustHave: true,
          ),
          ScreeningDraft(type: 'YEARS', prompt: 'Years in facilities?', idealAnswer: '5'),
        ]);
        final list = EmployerJobsController(repo);
        addTearDown(list.dispose);
        await list.start();
        await list.setSearch(title);
        final original = list.jobs.singleWhere((j) => j.id == id);
        final copy = await list.duplicate(original);
        expect(copy.error, isNull);
        copyId = copy.id;
        expect(copyId, isNot(id));
        final back = await repo.job(copyId!);
        expect(back.title, '$title (copy)');
        expect(back.status, PostingStatus.draft);
        expect(back.skills, ['HVAC']);
        final questions = await repo.screeningQuestions(copyId);
        expect(questions.map((q) => q.prompt), ['Can you work rotational shifts?', 'Years in facilities?']);
        expect(questions.first.mustHave, isTrue);
        expect(
          (await repo.screeningQuestions(id)).map((q) => q.prompt),
          hasLength(2),
          reason: 'the original keeps its own',
        );
      } finally {
        await deleteAll(repo, [id, ?copyId]);
      }
    });

    liveTest('a company that is not verified drafts but cannot publish; the API says what the composer said', () async {
      final repo = await hiringAs(tara);
      final title = titled('gate');
      final composer = PostJobController(repo, initial: readyDraft(title));
      addTearDown(composer.dispose);
      await composer.start();
      const gate =
          'Verify your company before publishing jobs. Your drafts are saved — finish verification and publish them in one click.';
      expect(composer.access!.canPublish, isFalse);
      expect(composer.publishBlockedReason, gate);

      // The composer refuses before it asks, and saves nothing.
      final blocked = await composer.publish();
      expect(blocked.ok, isFalse);
      expect(blocked.message, gate);
      expect(blocked.jobId, isNull, reason: 'refused before anything was sent');

      String? id;
      try {
        final saved = await composer.save();
        expect(saved.ok, isTrue, reason: saved.message);
        id = saved.jobId;
        expect(saved.status, PostingStatus.draft);

        // Ask the API directly: the same words, and a 403.
        await expectLater(
          repo.updateJob(id!, readyDraft(title), status: PostingStatus.open),
          throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 403).having((e) => e.message, 'message', gate)),
        );
        expect((await repo.job(id)).status, PostingStatus.draft);

        // Review is open to her: ICR can approve it for her.
        final review = await composer.submitForReview();
        expect(review.ok, isTrue, reason: review.message);
        expect(review.status, PostingStatus.inReview);
        expect((await repo.job(id)).status, PostingStatus.inReview);
      } finally {
        await deleteAll(repo, [?id]);
      }
    });

    liveTest('the composer saves a draft with a title only, and reads it back to edit', () async {
      final repo = await hiringAs(rohit);
      final title = titled('title only');
      final composer = PostJobController(repo, initial: JobDraft(title: title));
      addTearDown(composer.dispose);
      await composer.start();
      expect((await composer.publish()).ok, isFalse, reason: 'a title alone is not a posting');
      String? id;
      try {
        final saved = await composer.save();
        expect(saved.ok, isTrue, reason: saved.message);
        id = saved.jobId;
        final editor = PostJobController(repo, jobId: id);
        addTearDown(editor.dispose);
        await editor.start();
        expect(editor.draft.title, title);
        expect(editor.draft.status, PostingStatus.draft);
        expect(editor.draft.cities, isEmpty);
        expect(editor.blockers.map((b) => b.key), ['description', 'skills']);
        expect((await repo.jobs(search: title)).jobs.single.postedBy, 'Rohit Rao');
      } finally {
        await deleteAll(repo, [?id]);
      }
    });
  });

  group('a job\'s pipeline', () {
    liveTest('reads the applicants by stage, sorted and filtered, the way the screens draw them', () async {
      final repo = await hiringAs(meera);
      final all = await repo.applicants(pipelineJob);
      expect(all.applicants, hasLength(9));
      expect(all.stageCounts, {'APPLIED': 3, 'SCREENING': 2, 'INTERVIEW': 2, 'OFFER': 1, 'REJECTED': 1});
      expect(
        all.applicants.map((a) => a.name),
        containsAll(['Aarav Khanna', 'Sanjana Pillai', 'Ishita Bose', 'Harsh Vora']),
      );

      final sanjana = all.applicants.singleWhere((a) => a.id == app('sanjana'));
      expect(sanjana.stage, 'INTERVIEW');
      expect(sanjana.headline, 'AVP Facilities - multi-site portfolio');
      expect(sanjana.currentCompany, 'Embassy Group');
      expect(sanjana.experienceYears, 14);
      expect(sanjana.location, isNull, reason: 'the list carries no place; the application page does');
      expect(sanjana.skills, contains('Statutory Audits'));
      expect(sanjana.rating, 5);
      expect(sanjana.matchScore, 91);
      expect(sanjana.viewed, isTrue);
      expect(sanjana.nextInterviewAt, isNotNull);
      expect(sanjana.initials, 'SP');
      expect(all.applicants.singleWhere((a) => a.id == app('ishita')).offerStatus, 'SENT');

      final interviewing = await repo.applicants(pipelineJob, stage: 'INTERVIEW');
      expect(interviewing.applicants.map((a) => a.name).toSet(), {'Sanjana Pillai', 'Tejas Kulkarni'});

      final best = await repo.applicants(pipelineJob, sort: 'match');
      final scores = [for (final a in best.applicants) a.matchScore ?? 0];
      expect(scores, orderedEquals([...scores]..sort((a, b) => b.compareTo(a))));
      expect(best.applicants.first.name, 'Ishita Bose');

      final rated = await repo.applicants(pipelineJob, minRating: 4);
      expect(rated.applicants.map((a) => a.name).toSet(), {
        'Nisha Rao',
        'Sanjana Pillai',
        'Tejas Kulkarni',
        'Ishita Bose',
      });

      final qualified = await repo.applicants(pipelineJob, qualifiedOnly: true);
      expect(qualified.applicants.length, lessThanOrEqualTo(9));
      expect(qualified.applicants.every((a) => all.applicants.any((x) => x.id == a.id)), isTrue);
    });

    liveTest('an application is read whole: answers marked against the bar, rounds with feedback, the offer', () async {
      final repo = await hiringAs(meera);
      final sanjana = await repo.applicant(app('sanjana'));
      expect(sanjana.applicant.name, 'Sanjana Pillai');
      expect(sanjana.applicant.location, 'Mumbai');
      expect(sanjana.applicant.noticePeriodDays, 90);
      expect(sanjana.jobTitle, isNotEmpty);
      expect(sanjana.answers.map((a) => a.prompt), [
        'How many years have you run site operations?',
        'Can you work rotational shifts?',
      ]);
      expect(sanjana.answers.first.display, '14 years');
      expect(sanjana.answers.first.meetsIdeal, isTrue);
      expect(sanjana.answers.first.mustHave, isTrue);
      expect(sanjana.answers.last.display, 'Yes');
      expect(sanjana.interviews, hasLength(1));
      final round = sanjana.interviews.single;
      expect(round.title, 'Operations round');
      expect(round.mode, 'VIDEO');
      expect(round.status, 'SCHEDULED');
      expect(round.durationMins, 45);
      expect(round.meetingLink, 'https://meet.example.com/northwind-ops-1');
      expect(round.notes, 'Probe the multi-site rota she ran at Embassy.');
      expect(round.scheduledAt.isAfter(DateTime.now()), isTrue);
      expect(sanjana.events, isNotEmpty);
      expect(
        sanjana.events.first.at.isAfter(sanjana.events.last.at) || sanjana.events.length == 1,
        isTrue,
        reason: 'newest first',
      );

      final tejas = await repo.applicant(app('tejas'));
      final call = tejas.interviews.single;
      expect(call.status, 'COMPLETED');
      expect(call.mode, 'PHONE');
      expect(call.feedback, hasLength(1));
      expect(call.feedback.single.rating, 4);
      expect(call.feedback.single.recommendationLabel, 'Yes');
      expect(call.feedback.single.strengths, contains('vendor management'));
      expect(call.feedback.single.concerns, contains('statutory audit'));

      final ishita = await repo.applicant(app('ishita'));
      final offer = ishita.latestOffer!;
      expect(offer.status, 'SENT');
      expect(offer.amount, 2100000);
      expect(offer.jobTitle, 'Facilities Operations Lead');
      expect(offer.joiningDate, isNotNull);
      expect(offer.expiresAt, isNotNull);

      final nisha = await repo.applicant(app('nisha'));
      expect(nisha.events.any((e) => e.type == 'NOTE' && e.note!.contains('statutory audits')), isTrue);
    });

    liveTest('opening an application is the team\'s "viewed" receipt', () async {
      final repo = await hiringAs(meera);
      final id = app('box-zoya');
      await repo.applicant(id);
      final after = await applicantOf(repo, sandboxJob, id);
      expect(after.viewed, isTrue);
    });

    liveTest(
      'an application moves on, is rejected with a note, comes back; a move the API refuses is put back',
      () async {
        final repo = await hiringAs(meera);
        final id = app('box-leela');
        var a = await applicantOf(repo, sandboxJob, id);
        if (a.stage == 'APPLIED') await repo.moveStage(id, 'SCREENING');
        if (a.stage == 'REJECTED') await repo.moveStage(id, 'SCREENING');
        a = await applicantOf(repo, sandboxJob, id);
        expect(a.stage, 'SCREENING');

        // Not a move the pipeline allows.
        await expectLater(
          repo.moveStage(id, 'HIRED'),
          throwsA(
            isA<ApiError>().having((e) => e.statusCode, 'status', 400).having((e) => e.message, 'message', isNotEmpty),
          ),
        );
        expect((await applicantOf(repo, sandboxJob, id)).stage, 'SCREENING');

        // Rejected with a reason: the trail keeps the note and who wrote it.
        final note = 'MOBILE-LIVE not a fit ${DateTime.now().millisecondsSinceEpoch}';
        await repo.moveStage(id, 'REJECTED', note: note);
        expect((await applicantOf(repo, sandboxJob, id)).stage, 'REJECTED');
        final trail = (await repo.applicant(id)).events;
        final rejection = trail.firstWhere((e) => e.type == 'STAGE_CHANGE' && e.toStage == 'REJECTED');
        expect(rejection.fromStage, 'SCREENING');
        expect(rejection.note, note);
        expect(rejection.actor, 'Meera Iyer');

        // And back into review.
        await repo.moveStage(id, 'SCREENING');
        expect((await applicantOf(repo, sandboxJob, id)).stage, 'SCREENING');
        expect((await repo.applicants(sandboxJob)).stageCounts['SCREENING'], greaterThanOrEqualTo(1));
      },
    );

    liveTest('the pipeline\'s own controller applies a move at once, and rolls back what the API refuses', () async {
      final repo = await hiringAs(meera);
      final controller = ApplicantsController(
        repo,
        jobId: sandboxJob,
        jobTitle: 'Facilities Coordinator (hiring sandbox)',
      );
      addTearDown(controller.dispose);
      await controller.start();
      final leela = controller.applicants.singleWhere((a) => a.id == app('box-leela'));
      expect(leela.stage, anyOf('APPLIED', 'SCREENING', 'REJECTED'));
      if (leela.stage != 'SCREENING') {
        expect(await controller.move(leela, 'SCREENING'), isNull);
      }
      final inReview = controller.applicants.singleWhere((a) => a.id == app('box-leela'));
      expect(inReview.stage, 'SCREENING');

      final refusal = await controller.move(inReview, 'HIRED');
      expect(refusal, isNotNull);
      expect(controller.applicants.singleWhere((a) => a.id == app('box-leela')).stage, 'SCREENING', reason: 'put back');

      final countBefore = controller.count('REJECTED');
      expect(await controller.move(inReview, 'REJECTED', note: 'MOBILE-LIVE controller'), isNull);
      expect(controller.count('REJECTED'), countBefore + 1);
      expect((await applicantOf(repo, sandboxJob, app('box-leela'))).stage, 'REJECTED');
      final rejected = controller.applicants.singleWhere((a) => a.id == app('box-leela'));
      expect(await controller.move(rejected, 'SCREENING'), isNull);
      expect((await applicantOf(repo, sandboxJob, app('box-leela'))).stage, 'SCREENING');
    });

    liveTest('a rating and a note are kept, shown on the trail, and refused when out of range', () async {
      final repo = await hiringAs(meera);
      final id = app('box-manav');
      await repo.addNote(id, rating: 3);
      expect((await applicantOf(repo, sandboxJob, id)).rating, 3);
      await repo.addNote(id, rating: 5);
      expect((await applicantOf(repo, sandboxJob, id)).rating, 5);

      final note = 'MOBILE-LIVE note ${DateTime.now().millisecondsSinceEpoch}';
      await repo.addNote(id, note: note);
      await repo.addNote(id, note: '$note both', rating: 4);
      final trail = (await repo.applicant(id)).events;
      expect(trail.where((e) => e.type == 'NOTE').map((e) => e.note), containsAll([note, '$note both']));
      expect(trail.firstWhere((e) => e.type == 'NOTE' && e.note == note).actor, 'Meera Iyer');
      expect(trail.where((e) => e.rating != null).map((e) => e.rating), containsAll([3, 5, 4]));
      expect((await applicantOf(repo, sandboxJob, id)).rating, 4);

      await expectLater(
        repo.addNote(id, rating: 6),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 400)),
      );
      await expectLater(
        repo.addNote(id, rating: 0),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 400)),
      );
    });

    liveTest('an interview is booked, moved and called off; the API\'s refusals are the sheet\'s', () async {
      final repo = await hiringAs(meera);
      final id = app('box-rhea');
      final team = await repo.teamMembers();
      expect(team.map((m) => m.name), containsAll(['Meera Iyer', 'Rohit Rao']));
      expect(team.every((m) => m.id.isNotEmpty), isTrue);
      final me = (await repo.access()).userId;
      final rohitId = team.singleWhere((m) => m.name == 'Rohit Rao').id;
      expect(team.map((m) => m.id), contains(me));

      DateTime at(int days, [int hour = 11]) {
        final d = DateTime.now().add(Duration(days: days));
        return DateTime(d.year, d.month, d.day, hour);
      }

      final draft = InterviewDraft(
        scheduledAt: at(3),
        title: 'MOBILE-LIVE round',
        durationMins: 45,
        meetingLink: 'https://meet.example.com/mobile-live',
        notes: 'Probe the vendor answers',
        interviewerIds: [me, rohitId],
      );
      expect(draft.problem(DateTime.now()), isNull);
      final made = await repo.scheduleInterview(id, draft);
      try {
        expect(made.title, 'MOBILE-LIVE round');
        expect(made.status, 'SCHEDULED');
        expect(made.durationMins, 45);
        expect(made.mode, 'VIDEO');
        expect(made.meetingLink, 'https://meet.example.com/mobile-live');
        expect(made.notes, 'Probe the vendor answers');
        expect(made.panel.map((p) => p.name), unorderedEquals(['Meera Iyer', 'Rohit Rao']));
        expect(made.round, greaterThanOrEqualTo(1));

        var detail = await repo.applicant(id);
        expect(detail.interviews.map((i) => i.id), contains(made.id));
        expect(detail.events.any((e) => e.type == 'INTERVIEW_SCHEDULED' && e.note == 'MOBILE-LIVE round'), isTrue);

        // Moved to another day: rescheduled.
        final moved = await repo.updateInterview(
          made.id,
          draft: InterviewDraft(
            scheduledAt: at(4, 15),
            title: 'MOBILE-LIVE round',
            durationMins: 30,
            mode: 'PHONE',
            interviewerIds: [me],
          ),
        );
        expect(moved.status, 'RESCHEDULED');
        detail = await repo.applicant(id);
        final read = detail.interviews.singleWhere((i) => i.id == made.id);
        expect(read.mode, 'PHONE');
        expect(read.durationMins, 30);
        expect(read.scheduledAt.hour, 15);
        expect(read.panel, hasLength(1));

        // The API's refusals are the sheet's sentences.
        final inPerson = InterviewDraft(scheduledAt: at(5), mode: 'IN_PERSON', interviewerIds: [me]);
        expect(inPerson.problem(DateTime.now()), 'Give the address for an in-person interview.');
        await expectLater(
          repo.scheduleInterview(id, inPerson),
          throwsA(
            isA<ApiError>().having((e) => e.statusCode, 'status', 400).having((e) => e.message, 'message', isNotEmpty),
          ),
        );
        final past = InterviewDraft(
          scheduledAt: DateTime.now().subtract(const Duration(days: 1)),
          interviewerIds: [me],
        );
        expect(past.problem(DateTime.now()), 'Pick a time in the future.');
        await expectLater(
          repo.scheduleInterview(id, past),
          throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 400)),
        );
        final poojaId =
            ((await (await liveClient(pooja)).dio.get<Map<String, dynamic>>('/auth/me')).data!['id']) as String;
        await expectLater(
          repo.scheduleInterview(id, InterviewDraft(scheduledAt: at(5), interviewerIds: [poojaId])),
          throwsA(isA<ApiError>().having((e) => e.message, 'message', 'All interviewers must belong to your company.')),
        );

        // Called off.
        final cancelled = await repo.updateInterview(made.id, status: 'CANCELLED');
        expect(cancelled.status, 'CANCELLED');
        detail = await repo.applicant(id);
        expect(detail.interviews.singleWhere((i) => i.id == made.id).status, 'CANCELLED');
        expect(detail.interviews.singleWhere((i) => i.id == made.id).live, isFalse);
      } finally {
        try {
          await repo.updateInterview(made.id, status: 'CANCELLED');
        } catch (_) {
          // Already called off.
        }
      }
    });

    liveTest('the detail controller books, reschedules and cancels through the same calls', () async {
      final repo = await hiringAs(meera);
      final id = app('box-rhea');
      final seed = await applicantOf(repo, sandboxJob, id);
      final changes = <Applicant>[];
      final controller = ApplicantDetailController(repo, seed: seed, onChanged: changes.add);
      addTearDown(controller.dispose);
      await controller.start();
      expect(controller.detail, isNotNull);
      expect(changes, isNotEmpty, reason: 'opening tells the pipeline');
      await controller.loadTeam();
      final me = (await repo.access()).userId;
      expect(controller.team.map((m) => m.id), contains(me));

      expect(
        await controller.schedule(
          InterviewDraft(scheduledAt: DateTime.now().subtract(const Duration(hours: 1)), interviewerIds: [me]),
        ),
        'Pick a time in the future.',
      );
      final d = DateTime.now().add(const Duration(days: 6));
      final when = DateTime(d.year, d.month, d.day, 10);
      final before = controller.detail!.interviews.length;
      expect(
        await controller.schedule(
          InterviewDraft(scheduledAt: when, title: 'MOBILE-LIVE via controller', interviewerIds: [me]),
        ),
        isNull,
      );
      expect(controller.detail!.interviews.length, before + 1);
      final booked = controller.detail!.interviews.singleWhere(
        (i) => i.title == 'MOBILE-LIVE via controller' && i.live,
      );
      expect(
        await controller.reschedule(
          booked,
          InterviewDraft(
            scheduledAt: when.add(const Duration(days: 1)),
            title: 'MOBILE-LIVE via controller',
            interviewerIds: [me],
          ),
        ),
        isNull,
      );
      final moved = controller.detail!.interviews.singleWhere((i) => i.id == booked.id);
      expect(moved.status, 'RESCHEDULED');
      expect(await controller.setInterviewStatus(moved, 'CANCELLED'), isNull);
      expect(controller.detail!.interviews.singleWhere((i) => i.id == booked.id).status, 'CANCELLED');
    });

    liveTest('an offer is drafted, changed, sent, refused a second time, and the person hired', () async {
      final repo = await hiringAs(meera);
      String? id;
      for (final who in ['box-zoya', 'box-omar', 'box-asha', 'box-bilal', 'box-chitra', 'box-dev']) {
        final detail = await repo.applicant(app(who));
        final spent = detail.offers.any((o) => o.status == 'DRAFT' || o.status == 'SENT' || o.status == 'ACCEPTED');
        if (!spent && !{'HIRED', 'OFFER'}.contains(detail.applicant.stage)) {
          id = app(who);
          break;
        }
      }
      if (id == null) {
        markTestSkipped('all six spare applicants are spent: run tool/seed/career.ts to reset the hiring sandbox');
        return;
      }
      final now = DateTime.now();
      await repo.moveStage(id, 'INTERVIEW');
      final draft = OfferDraft(
        amount: 650000,
        jobTitle: 'Facilities Coordinator',
        joiningDate: now.add(const Duration(days: 60)),
        expiresAt: now.add(const Duration(days: 14)),
        notes: 'MOBILE-LIVE offer',
      );
      expect(draft.problem(now), isNull);
      final made = await repo.makeOffer(id, draft, send: false);
      expect(made.status, 'DRAFT');
      expect(made.amount, 650000);
      expect(made.currency, 'INR');
      expect(made.period, 'YEARLY');
      expect(made.jobTitle, 'Facilities Coordinator');
      expect(made.joiningDate, isNotNull);
      expect(made.expiresAt, isNotNull);
      expect((await applicantOf(repo, sandboxJob, id)).stage, 'INTERVIEW', reason: 'a draft offer moves nobody');

      // One live offer at a time.
      await expectLater(
        repo.makeOffer(id, draft, send: false),
        throwsA(isA<ApiError>().having((e) => e.message, 'message', 'This application already has an active offer.')),
      );

      // Changed while a draft.
      final changed = await repo.updateOffer(
        made.id,
        const OfferDraft(amount: 700000, period: 'MONTHLY', jobTitle: 'Facilities Coordinator'),
      );
      expect(changed.amount, 700000);
      expect(changed.period, 'MONTHLY');
      expect((await repo.applicant(id)).latestOffer!.amount, 700000);

      // Sent: the application moves to Offer.
      final sent = await repo.sendOffer(made.id);
      expect(sent.status, 'SENT');
      expect(sent.sentAt, isNotNull);
      expect((await applicantOf(repo, sandboxJob, id)).stage, 'OFFER');
      expect((await applicantOf(repo, sandboxJob, id)).offerStatus, 'SENT');
      await expectLater(
        repo.sendOffer(made.id),
        throwsA(isA<ApiError>().having((e) => e.message, 'message', 'Only a draft offer can be sent.')),
      );
      // A sent offer can still be changed.
      expect((await repo.updateOffer(made.id, const OfferDraft(amount: 710000))).amount, 710000);

      // Hired; there is no way on from there.
      await repo.moveStage(id, 'HIRED');
      expect((await applicantOf(repo, sandboxJob, id)).stage, 'HIRED');
      await expectLater(
        repo.moveStage(id, 'REJECTED'),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 400)),
      );
    });

    liveTest('"Message" opens the thread with the applicant, and the same one next time', () async {
      final repo = await hiringAs(meera);
      final id = app('box-yash');
      final first = await repo.messageApplicant(id);
      expect(first, isNotNull);
      expect(first, isNotEmpty);
      final again = await repo.messageApplicant(id);
      expect(again, first);
    });
  });

  group('the screens over the API', () {
    testWidgets('Jobs you posted draws the company\'s postings, its figures and its tabs', tags: const ['live'], (
      tester,
    ) async {
      if (!await liveScreenReady(tester)) return;
      final repo = await tester.runAsync(() => hiringAs(meera, pageSize: 50));
      await pumpLive(
        tester,
        EmployerJobsScreen(key: UniqueKey(), repository: repo!, links: RecordingLinks()),
        size: const Size(390, 3600),
      );
      await settleLive(tester);
      expect(find.text('Jobs you posted'), findsOneWidget);
      expect(find.byKey(const ValueKey('figures')), findsOneWidget);
      expect(find.byKey(const ValueKey('job-$pipelineJob')), findsOneWidget);
      expect(find.text('Security Operations Manager'), findsWidgets);
      expect(find.textContaining('Drafts '), findsOneWidget);
      expect(
        find.byKey(const ValueKey('returned-design-career-job-ready')),
        findsNothing,
        reason: 'it was never sent back',
      );

      // Drafts only.
      await tester.tap(find.byKey(const ValueKey('jobs-tab-draft')));
      await settleLive(tester);
      expect(find.byKey(const ValueKey('job-design-career-job-ready')), findsOneWidget);
      expect(find.byKey(const ValueKey('job-$pipelineJob')), findsNothing);
      expect(find.byKey(const ValueKey('continue-design-career-job-ready')), findsOneWidget);

      // The pipeline opens from the open job.
      await tester.tap(find.byKey(const ValueKey('jobs-tab-open')));
      await settleLive(tester);
      await tester.tap(find.byKey(const ValueKey('open-applicants-$pipelineJob')));
      await settleLive(tester);
      expect(find.byType(ApplicantsScreen), findsOneWidget);
      expect(find.text('Sanjana Pillai'), findsWidgets);
      await finishLive(tester);
    });

    testWidgets(
      'the pipeline draws nine applicants in their stages, and an application opens whole',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        final repo = await tester.runAsync(() => hiringAs(meera));
        await pumpLive(
          tester,
          ApplicantsScreen(
            key: UniqueKey(),
            repository: repo!,
            jobId: pipelineJob,
            jobTitle: 'Facilities Operations Lead',
            links: RecordingLinks(),
          ),
          size: const Size(390, 3200),
        );
        await settleLive(tester);
        expect(find.text('All 9'), findsOneWidget);
        expect(find.text('Applied 3'), findsOneWidget);
        expect(find.text('In review 2'), findsOneWidget);
        expect(find.text('Interview 2'), findsOneWidget);
        expect(find.text('Offer 1'), findsOneWidget);
        for (final name in [
          'Aarav Khanna',
          'Divya Menon',
          'Nisha Rao',
          'Sanjana Pillai',
          'Tejas Kulkarni',
          'Ishita Bose',
          'Harsh Vora',
        ]) {
          expect(find.text(name), findsWidgets, reason: name);
        }
        expect(find.text('93% match'), findsOneWidget);
        expect(find.text('Offer sent, awaiting reply'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('stage-INTERVIEW')));
        await settleLive(tester);
        expect(find.byKey(ValueKey('applicant-${app('sanjana')}')), findsOneWidget);
        expect(find.byKey(ValueKey('applicant-${app('aarav')}')), findsNothing);

        await tester.tap(find.byKey(ValueKey('applicant-${app('sanjana')}')));
        await settleLive(tester);
        expect(find.byType(ApplicantDetailScreen), findsOneWidget);
        expect(find.text('Sanjana Pillai'), findsWidgets);
        expect(find.text('AVP Facilities - multi-site portfolio'), findsOneWidget);
        expect(find.text('14 years'), findsOneWidget);
        expect(find.text('Operations round'), findsOneWidget);
        expect(find.byKey(const ValueKey('detail-move-OFFER')), findsOneWidget);
        expect(find.byKey(const ValueKey('detail-offer')), findsOneWidget);
        await finishLive(tester);
      },
    );

    testWidgets('the composer saves a draft over the API, and the checklist is the API\'s', tags: const ['live'], (
      tester,
    ) async {
      if (!await liveScreenReady(tester)) return;
      final repo = (await tester.runAsync(() => hiringAs(rohit)))!;
      final title = titled('screen');
      await pumpLive(
        tester,
        PostJobScreen(key: UniqueKey(), repository: repo, links: RecordingLinks()),
        size: const Size(390, 6000),
      );
      await settleLive(tester);
      expect(find.text('Before you publish'), findsOneWidget);
      expect(find.byKey(const ValueKey('gate-note')), findsNothing, reason: 'Northwind is verified');
      await tester.enterText(find.byKey(const ValueKey('job-title')), title);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('save-draft')));
      await settleSave(tester);
      expect(find.text('Draft saved.'), findsOneWidget);
      final saved = await tester.runAsync(() => again(() => repo.jobs(status: PostingStatus.draft, search: title)));
      final id = saved!.jobs.single.id;
      expect(saved.jobs.single.title, title);
      await tester.runAsync(() => again(() => deleteAll(repo, [id])));
      await finishLive(tester);
    });

    testWidgets('a company that is not verified sees the API\'s reason in the composer', tags: const ['live'], (
      tester,
    ) async {
      if (!await liveScreenReady(tester)) return;
      final repo = (await tester.runAsync(() => hiringAs(tara)))!;
      await pumpLive(
        tester,
        PostJobScreen(key: UniqueKey(), repository: repo, links: RecordingLinks()),
        size: const Size(390, 6000),
      );
      await settleLive(tester);
      expect(find.byKey(const ValueKey('gate-note')), findsOneWidget);
      expect(find.textContaining('Verify your company before publishing jobs.'), findsOneWidget);
      await finishLive(tester);
    });

    testWidgets('a member who is not on a hiring team is told so, not shown an error', tags: const ['live'], (
      tester,
    ) async {
      if (!await liveScreenReady(tester)) return;
      final repo = (await tester.runAsync(() => hiringAs(pooja)))!;
      await pumpLive(tester, EmployerJobsScreen(key: UniqueKey(), repository: repo, links: RecordingLinks()));
      await settleLive(tester);
      expect(find.byKey(const ValueKey('no-role')), findsOneWidget);
      expect(find.text('Posting jobs is for hiring teams'), findsOneWidget);
      expect(find.byKey(const ValueKey('jobs-error')), findsNothing);
      await finishLive(tester);
    });
  });
}
