/// The COMPANY accounts through the hiring side and the companies screens, against the LOCAL portal API: the
/// app's own repositories and controllers, every effect read back through the API, every write undone.
///
/// Accounts (`role_company_support.dart`): Chetan (COMPANY_ADMIN) and Farah (COMPANY_ADMIN, personally a
/// PROFESSIONAL) of E2E Test Vendor Co; Bina (BRANCH_ADMIN) and Rahul (RECRUITER), both placed at the company's Head
/// Office; Hema (HIRING_MANAGER, interview feedback only); Maya (COMPANY_ADMIN) and Nikhil (BUYER) of the
/// Marketplace seed's buyer company, which is not employer-verified.
///
/// What is made and how it is undone: every posting a test makes is deleted at its end; an applicant is a throwaway
/// person (`@account-live.icr.test`, swept by the account seed's `--cleanup-live`) whose application dies with the
/// posting; an interview round is called off; a join request is withdrawn; the one account that is switched to
/// itself and back ends where it began. The requirements side is `role_company_rfq_live_test.dart`, the company
/// inbox `role_company_inbox_live_test.dart`, the drawn screens `role_company_screens_live_test.dart`.
///
///     flutter test --no-pub test/live/role_company_live_test.dart --concurrency=1
@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/auth/auth_controller.dart';
import 'package:icr_mobile/features/account/account_models.dart';
import 'package:icr_mobile/features/account/api_account_repository.dart';
import 'package:icr_mobile/features/account/companies/companies_controller.dart';
import 'package:icr_mobile/features/career/api_career_repository.dart';
import 'package:icr_mobile/features/jobs/api_jobs_repository.dart';
import 'package:icr_mobile/features/jobs/employer/api_hiring_repository.dart';
import 'package:icr_mobile/features/jobs/employer/applicants_controller.dart';
import 'package:icr_mobile/features/jobs/employer/employer_jobs_controller.dart';
import 'package:icr_mobile/features/jobs/employer/hiring_models.dart';
import 'package:icr_mobile/features/jobs/employer/post_job_controller.dart';
import 'package:icr_mobile/features/jobs/jobs_controller.dart';
import 'package:icr_mobile/features/notifications/api_notifications_repository.dart';

import 'live.dart';
import 'role_company_support.dart';

Future<ApiHiringRepository> hiringAs(LivePerson who, {int pageSize = 50}) async =>
    ApiHiringRepository(api: await liveClient(who), pageSize: pageSize);

/// What the tests title their postings, so a dead run's leftovers can be found and swept.
const marker = 'MOBILE-LIVE company';

String titled(String what, [Object? run]) => '$marker ${run ?? DateTime.now().millisecondsSinceEpoch} $what';

Future<void> deleteAll(ApiHiringRepository repo, Iterable<String> ids) async {
  for (final id in ids) {
    try {
      await repo.deleteJob(id);
    } catch (_) {
      // Already gone, or not this account's to delete: the account that made it deletes it.
    }
  }
}

/// A draft made as [repo]'s person, deleted when the test ends.
Future<String> draftAs(ApiHiringRepository repo, String title) async {
  final id = await repo.createJob(readyDraft(title), PostingStatus.draft);
  addTearDown(() => deleteAll(repo, [id]));
  return id;
}

/// A posting published through the composer's own controller, deleted when the test ends.
Future<String> publishAs(ApiHiringRepository repo, String title) async {
  final composer = PostJobController(repo, initial: readyDraft(title));
  addTearDown(composer.dispose);
  await composer.start();
  expect(composer.blockers, isEmpty);
  final out = await composer.publish();
  expect(out.ok, isTrue, reason: out.message);
  expect(out.status, PostingStatus.open);
  addTearDown(() => deleteAll(repo, [out.jobId!]));
  return out.jobId!;
}

/// The status the API refuses with, or null when the call went through.
Future<int?> refusedWith(Future<Object?> call) async {
  try {
    await call;
    return null;
  } catch (e) {
    return ApiError.from(e).statusCode;
  }
}

Matcher refused = isIn([400, 403, 404]);

void main() {
  group('who is on a hiring team', () {
    companyTest('the app and the API agree on who may post jobs, for each of the seven accounts', () async {
      final expected = <LivePerson, ({String role, bool manage, bool publish})>{
        companyAdmin: (role: 'COMPANY_ADMIN', manage: true, publish: true),
        founder: (role: 'COMPANY_ADMIN', manage: true, publish: true),
        branchAdmin: (role: 'BRANCH_ADMIN', manage: true, publish: true),
        recruiter: (role: 'RECRUITER', manage: true, publish: true),
        hiringManager: (role: 'HIRING_MANAGER', manage: false, publish: true),
        // The Marketplace seed's buyer company never filed its company check: the team may draft, not publish.
        marketBuyer: (role: 'COMPANY_ADMIN', manage: true, publish: false),
        marketNoPhone: (role: 'BUYER', manage: false, publish: true),
      };
      for (final entry in expected.entries) {
        final access = await (await hiringAs(entry.key)).access();
        expect(access.role, entry.value.role, reason: entry.key.label);
        expect(access.companyId, isNotNull, reason: entry.key.label);
        expect(access.canManage, entry.value.manage, reason: entry.key.label);
        if (entry.value.manage) expect(access.canPublish, entry.value.publish, reason: entry.key.label);
      }
    });

    companyTest('a hiring manager and a buyer are refused every hiring call, in the API\'s sentence', () async {
      for (final who in [hiringManager, marketNoPhone]) {
        final repo = await hiringAs(who);
        for (final call in <Future<Object?> Function()>[
          () => repo.jobs(),
          () => repo.overview(),
          () => repo.createJob(readyDraft(titled('refused')), PostingStatus.draft),
          () => repo.teamMembers(),
        ]) {
          try {
            await call();
            fail('${who.label}: the API accepted a hiring call');
          } catch (e) {
            final error = ApiError.from(e);
            expect(error.statusCode, anyOf(403, 404), reason: who.label);
            expect(error.message, isNotEmpty, reason: who.label);
          }
        }
      }
    });
  });

  group('the Jobs board and the career hub, whatever the hat', () {
    companyTest(
      'the board loads for every company account, and offers Post a job only to the ones that post',
      () async {
        final canHire = <LivePerson, bool>{
          companyAdmin: true,
          founder: true,
          branchAdmin: true,
          recruiter: true,
          marketBuyer: true,
          hiringManager: false,
          marketNoPhone: false,
        };
        for (final entry in canHire.entries) {
          final board = JobsController(ApiJobsRepository(api: await liveClient(entry.key)));
          addTearDown(board.dispose);
          await board.start();
          expect(board.error, isNull, reason: entry.key.label);
          expect(board.sections, isNotEmpty, reason: '${entry.key.label}: the board has its sections');
          expect(
            board.canHire,
            entry.value,
            reason: '${entry.key.label}: Post a job opens the composer only for a hiring team',
          );
        }
      },
    );

    companyTest('the bell reads for each account: its notifications, its count and who the reader is', () async {
      for (final who in [companyAdmin, founder, branchAdmin, recruiter, hiringManager, marketBuyer, marketNoPhone]) {
        final repo = ApiNotificationsRepository(api: await liveClient(who));
        final page = await repo.list();
        expect(page.items.every((n) => n.id.isNotEmpty), isTrue, reason: who.label);
        expect(await repo.unreadCount(), greaterThanOrEqualTo(0), reason: who.label);
        final viewer = await repo.viewer();
        expect(viewer, isNotNull, reason: who.label);
      }
    });

    companyTest(
      'the own career reads of a person (applications, saved jobs, alerts, invitations, quota) work for each, not gated on the hat',
      () async {
        for (final who in [companyAdmin, founder, branchAdmin, recruiter, hiringManager, marketBuyer, marketNoPhone]) {
          final api = await liveClient(who);
          final career = ApiCareerRepository(
            api: api,
            jobs: ApiJobsRepository(api: api),
          );
          final reads = <String, Future<Object?> Function()>{
            'applications': career.applications,
            'saved jobs': career.savedJobs,
            'alerts': career.alerts,
            'invitations': career.invites,
            'discoverable': career.discoverable,
            'shelf counts': career.shelfCounts,
            'quota': career.quota,
          };
          for (final read in reads.entries) {
            Object? error;
            try {
              await read.value();
            } catch (e) {
              error = e;
            }
            expect(
              error,
              isNull,
              reason: '${who.label}: ${read.key} ${error == null ? '' : ApiError.from(error).message}',
            );
          }
        }
      },
    );
  });

  group('the company\'s jobs and the office scope', () {
    companyTest('admins read the whole company; the office roles read their office, and no more', () async {
      final run = DateTime.now().millisecondsSinceEpoch;
      final ca = await hiringAs(companyAdmin);
      final fp = await hiringAs(founder);
      final rc = await hiringAs(recruiter);
      final ba = await hiringAs(branchAdmin);
      // An admin's posting has no office; the recruiter's and the office admin's land in their own.
      final noOffice = await draftAs(ca, titled('no office', run));
      final recruiters = await draftAs(rc, titled('by the recruiter', run));
      final officeAdmins = await draftAs(ba, titled('by the office admin', run));

      Future<Set<String>> seen(ApiHiringRepository repo, {bool mine = false}) async => {
        for (final j in (await repo.jobs(search: '$marker $run', mine: mine)).jobs) j.id,
      };

      expect(await seen(ca), {noOffice, recruiters, officeAdmins});
      expect(await seen(fp), {noOffice, recruiters, officeAdmins}, reason: 'the second admin reads the same company');
      expect(await seen(rc), {recruiters, officeAdmins}, reason: 'a posting with no office is the admins\'');
      expect(await seen(ba), {recruiters, officeAdmins});
      expect(await seen(ba, mine: true), {officeAdmins}, reason: '"Only jobs I started"');
      expect(await seen(rc, mine: true), {recruiters});
      expect(await seen(ca, mine: true), {noOffice});

      // The figures follow the scope: the office roles' totals are never bigger than the admins'.
      final all = await ca.jobs();
      final office = await ba.jobs();
      expect(office.total, lessThanOrEqualTo(all.total));
      expect({for (final j in office.jobs) j.id}.difference({for (final j in all.jobs) j.id}), isEmpty);
      final ov = await ba.overview();
      final cov = await ca.overview();
      expect(ov.open, lessThanOrEqualTo(cov.open));
    });

    companyTest(
      'a posting outside the office cannot be read, run or deleted by the office roles; the admins run all of it',
      () async {
        final run = DateTime.now().millisecondsSinceEpoch;
        final ca = await hiringAs(companyAdmin);
        final fp = await hiringAs(founder);
        final rc = await hiringAs(recruiter);
        final ba = await hiringAs(branchAdmin);
        final adminJob = await publishAs(ca, titled('admin job', run));
        final officeJob = await publishAs(rc, titled('office job', run));

        for (final (who, repo) in [(recruiter, rc), (branchAdmin, ba)]) {
          expect(await refusedWith(repo.applicants(adminJob)), refused, reason: '${who.label}: its pipeline');
          expect(
            await refusedWith(repo.updateJob(adminJob, readyDraft(titled('hijack', run)))),
            refused,
            reason: who.label,
          );
          expect(await refusedWith(repo.setStatus(adminJob, PostingStatus.closed)), refused, reason: who.label);
          expect(await refusedWith(repo.deleteJob(adminJob)), refused, reason: who.label);
        }
        final untouched = await ca.job(adminJob);
        expect(untouched.status, PostingStatus.open);
        expect(untouched.title, contains('admin job'));

        // The office admin runs the recruiter's posting (same office); both admins run anything.
        expect(await refusedWith(ba.applicants(officeJob)), isNull);
        await ba.setStatus(officeJob, PostingStatus.paused);
        expect((await rc.job(officeJob)).status, PostingStatus.paused);
        await fp.setStatus(officeJob, PostingStatus.open);
        expect((await ca.job(officeJob)).status, PostingStatus.open);
        expect(await refusedWith(fp.applicants(adminJob)), isNull);
        expect(await refusedWith(fp.setStatus(adminJob, PostingStatus.paused)), isNull);
        await ca.setStatus(adminJob, PostingStatus.open);
      },
    );
  });

  group('the composer: the shared publish rules, and salary optional', () {
    companyTest(
      'the checklist names what stops a publish, and the API refuses in the same words, for the office roles too',
      () async {
        for (final who in [recruiter, branchAdmin]) {
          final repo = await hiringAs(who);
          final base = readyDraft(titled('rules'));
          expect(base.blockers, isEmpty, reason: 'a complete posting with no salary');
          final id = await draftAs(repo, base.title);
          final cases = <String, JobDraft>{
            'title': base.copyWith(title: 'HR'),
            'description': base.copyWith(description: 'Too short to publish.'),
            'skills': base.copyWith(skills: const []),
            'applyUrl': base.copyWith(externalApply: true, applyUrl: ''),
          };
          for (final entry in cases.entries) {
            final expected = entry.value.blockers;
            expect(expected.first.key, entry.key, reason: '${who.label}: the case breaks only ${entry.key}');
            await expectLater(
              repo.updateJob(id, entry.value, status: PostingStatus.open),
              throwsA(isA<ApiError>().having((e) => e.message, '${entry.key} message', expected.first.message)),
              reason: '${who.label}: ${entry.key}',
            );
          }
          expect(
            (await repo.job(id)).status,
            PostingStatus.draft,
            reason: 'a refused publish leaves the draft a draft',
          );
        }
      },
    );

    companyTest(
      'the composer lists every blocker of an empty posting and publishes nothing until they are done',
      () async {
        final repo = await hiringAs(companyAdmin);
        final c = PostJobController(repo);
        addTearDown(c.dispose);
        await c.start();
        expect(c.access!.canPublish, isTrue);
        expect(c.blockers.map((b) => b.key), containsAll(['title', 'description', 'skills']));
        final out = await c.publish();
        expect(out.ok, isFalse);
        expect(out.message, anyOf(contains('Finish'), isNotEmpty));
        expect(c.id, isNull, reason: 'nothing was made');

        c.setTitle(titled('checklist'));
        c.update((d) => d.copyWith(description: longDescription, cities: const ['Pune'], skills: const ['HVAC']));
        expect(c.blockers, isEmpty);
        // No pay anywhere: the posting is complete all the same.
        expect(c.draft.salaryMin, isNull);
        expect(c.draft.salaryMax, isNull);
        final live = await c.publish();
        expect(live.ok, isTrue, reason: live.message);
        addTearDown(() => deleteAll(repo, [live.jobId!]));
        expect((await repo.job(live.jobId!)).status, PostingStatus.open);
        expect((await repo.job(live.jobId!)).salaryMin, isNull);
      },
    );

    companyTest(
      'a company that has not filed its company check drafts but cannot publish, in the API\'s words',
      () async {
        final repo = await hiringAs(marketBuyer);
        final access = await repo.access();
        expect(access.canManage, isTrue);
        expect(access.canPublish, isFalse);
        final c = PostJobController(repo, initial: readyDraft(titled('unverified')));
        addTearDown(c.dispose);
        await c.start();
        expect(c.publishBlockedReason, isNotNull);
        expect(c.publishBlockedReason, contains('Verify your company'));
        final out = await c.publish();
        expect(out.ok, isFalse);
        expect(out.message, c.publishBlockedReason);
        // A draft is still welcome.
        final saved = await c.save();
        expect(saved.ok, isTrue, reason: saved.message);
        addTearDown(() => deleteAll(repo, [saved.jobId!]));
        expect((await repo.job(saved.jobId!)).status, PostingStatus.draft);
        // And the API says the same when asked directly.
        await expectLater(
          repo.updateJob(saved.jobId!, readyDraft(titled('unverified')), status: PostingStatus.open),
          throwsA(isA<ApiError>().having((e) => e.message, 'message', contains('Verify your company'))),
        );
      },
    );
  });

  group('posting, editing and closing, by role', () {
    companyTest(
      'a recruiter publishes, edits, pauses, closes, reopens and deletes; the office admin and an admin see each step',
      () async {
        final run = DateTime.now().millisecondsSinceEpoch;
        final rc = await hiringAs(recruiter);
        final ba = await hiringAs(branchAdmin);
        final ca = await hiringAs(companyAdmin);
        final title = titled('lifecycle', run);
        final id = await publishAs(rc, title);
        expect((await rc.job(id)).status, PostingStatus.open);
        expect((await ba.jobs(search: title)).jobs.single.status, PostingStatus.open);
        expect((await ca.jobs(search: title)).jobs.single.id, id);

        final list = EmployerJobsController(rc);
        addTearDown(list.dispose);
        await list.start();
        await list.setSearch(title);
        var row = list.jobs.singleWhere((j) => j.id == id);
        expect(row.publishedAt, isNotNull);
        expect(await list.move(row, PostingStatus.paused), isNull);
        expect((await ca.job(id)).status, PostingStatus.paused);
        row = list.jobs.singleWhere((j) => j.id == id);
        expect(await list.move(row, PostingStatus.closed), isNull);
        expect((await ba.job(id)).status, PostingStatus.closed);
        row = list.jobs.singleWhere((j) => j.id == id);
        expect(await list.move(row, PostingStatus.open), isNull);
        expect((await ca.job(id)).status, PostingStatus.open);

        // Editing a live posting saves at once and does not unpublish; a posting that stops passing the checklist is refused.
        final editor = PostJobController(rc, jobId: id);
        addTearDown(editor.dispose);
        await editor.start();
        expect(editor.live, isTrue);
        editor.update((d) => d.copyWith(department: 'Estates'));
        final saved = await editor.save();
        expect(saved.ok, isTrue, reason: saved.message);
        expect((await ca.job(id)).department, 'Estates');
        expect((await ca.job(id)).status, PostingStatus.open);
        editor.update((d) => d.copyWith(skills: const []));
        final refusedSave = await editor.save();
        expect(refusedSave.ok, isFalse);
        expect(refusedSave.message, editor.blockers.single.message);
        expect((await ca.job(id)).skills, ['HVAC'], reason: 'the refused save changed nothing');

        row = list.jobs.singleWhere((j) => j.id == id);
        expect(await list.delete(row), isNull);
        expect((await ca.jobs(search: title)).jobs, isEmpty);
      },
    );

    companyTest(
      'an office admin publishes a posting of her own; it lands in her office, where the recruiter and the admins see it',
      () async {
        final run = DateTime.now().millisecondsSinceEpoch;
        final ba = await hiringAs(branchAdmin);
        final title = titled('office admin', run);
        final id = await publishAs(ba, title);
        for (final who in [recruiter, companyAdmin, founder]) {
          expect(
            (await (await hiringAs(who)).jobs(search: title)).jobs.map((j) => j.id),
            contains(id),
            reason: who.label,
          );
        }
        // She started it, so "only jobs I started" has it; the recruiter's list of her own does not.
        expect((await ba.jobs(search: title, mine: true)).jobs.map((j) => j.id), contains(id));
        expect((await (await hiringAs(recruiter)).jobs(search: title, mine: true)).jobs, isEmpty);
      },
    );

    companyTest('the second admin closes and reopens what the first posted', () async {
      final ca = await hiringAs(companyAdmin);
      final fp = await hiringAs(founder);
      final id = await publishAs(ca, titled('second admin'));
      await fp.setStatus(id, PostingStatus.closed);
      expect((await ca.job(id)).status, PostingStatus.closed);
      await fp.setStatus(id, PostingStatus.open);
      expect((await ca.job(id)).status, PostingStatus.open);
    });
  });

  group('a job\'s pipeline and its interviews', () {
    companyTest(
      'an applicant arrives; the team reads, moves, rates, writes and books; the panel and the office are held to their rules',
      () async {
        final run = DateTime.now().millisecondsSinceEpoch;
        final ca = await hiringAs(companyAdmin);
        final rc = await hiringAs(recruiter);
        final ba = await hiringAs(branchAdmin);
        final adminJob = await publishAs(ca, titled('pipeline admin', run));
        final officeJob = await publishAs(rc, titled('pipeline office', run));

        // A throwaway applicant applies to both.
        final applicant = await signUpThrowaway(first: 'Applicant');
        final applications = <String, String>{};
        for (final job in [adminJob, officeJob]) {
          final res = await applicant.api.dio.post<Map<String, dynamic>>(
            '/jobs/$job/apply',
            data: {'coverNote': 'Role test application.', 'phone': '+919812345678'},
          );
          applications[job] = res.data!['id'] as String;
        }

        // The admin reads the pipeline: one new applicant nobody has opened.
        var page = await ca.applicants(adminJob);
        expect(page.applicants.single.id, applications[adminJob]);
        expect(page.applicants.single.stage, 'APPLIED');
        expect(page.applicants.single.viewedAt, isNull);
        expect(page.stageCounts['APPLIED'], 1);

        // Opening the application is the team's receipt; the answers, rounds and trail come with it.
        final id = applications[adminJob]!;
        final detail = await ca.applicant(id);
        expect(detail.applicant.name, contains('Applicant'));
        expect(detail.applicant.coverNote, 'Role test application.');
        expect((await ca.applicants(adminJob)).applicants.single.viewedAt, isNotNull);

        // Move on, rate, write; the trail keeps who did it.
        await ca.moveStage(id, 'SCREENING');
        await ca.addNote(id, rating: 4);
        final note = 'MOBILE-LIVE note $run';
        await ca.addNote(id, note: note);
        page = await ca.applicants(adminJob);
        expect(page.applicants.single.stage, 'SCREENING');
        expect(page.applicants.single.rating, 4);
        final trail = (await ca.applicant(id)).events;
        expect(trail.where((e) => e.type == 'NOTE').map((e) => e.note), contains(note));
        expect(trail.any((e) => e.type == 'STAGE_CHANGE' && e.toStage == 'SCREENING'), isTrue);
        expect(await refusedWith(ca.moveStage(id, 'HIRED')), 400, reason: 'not a move the pipeline allows');

        // The thread with the applicant: the same one every time.
        final thread = await ca.messageApplicant(id);
        expect(thread, isNotEmpty);
        expect(await ca.messageApplicant(id), thread);

        // An interview with the hiring manager on its panel.
        final team = await ca.teamMembers();
        final hmId = team.singleWhere((m) => m.name.contains('Hema')).id;
        final me = (await ca.access()).userId;
        DateTime at(int days, [int hour = 11]) {
          final d = DateTime.now().add(Duration(days: days));
          return DateTime(d.year, d.month, d.day, hour);
        }

        final round = await ca.scheduleInterview(
          id,
          InterviewDraft(
            scheduledAt: at(3),
            title: 'MOBILE-LIVE panel',
            meetingLink: 'https://meet.example.com/role-company',
            interviewerIds: [me, hmId],
          ),
        );
        addTearDown(() async {
          try {
            await ca.updateInterview(round.id, status: 'CANCELLED');
          } catch (_) {}
        });
        expect(round.panel.map((p) => p.name), containsAll(['Hema HiringManager']));
        final moved = await ca.updateInterview(
          round.id,
          draft: InterviewDraft(scheduledAt: at(4, 15), title: 'MOBILE-LIVE panel', interviewerIds: [me, hmId]),
        );
        expect(moved.status, 'RESCHEDULED');
        final other = await ca.scheduleInterview(
          id,
          InterviewDraft(scheduledAt: at(5), title: 'MOBILE-LIVE without the manager', interviewerIds: [me]),
        );
        addTearDown(() async {
          try {
            await ca.updateInterview(other.id, status: 'CANCELLED');
          } catch (_) {}
        });

        // The hiring manager reads only the panels he is on, and may not score before the interview starts.
        final hm = await liveClient(hiringManager);
        final mine = (await hm.dio.get<List<dynamic>>('/interviews/mine')).data!.cast<Map<String, dynamic>>();
        final ids = {for (final i in mine) i['id']};
        expect(ids, contains(round.id));
        expect(ids, isNot(contains(other.id)), reason: 'he is not on that panel');
        expect(
          await refusedWith(hm.dio.get<dynamic>('/interviews/${round.id}')),
          isNull,
          reason: 'his own panel\'s brief',
        );
        expect(await refusedWith(hm.dio.get<dynamic>('/interviews/${other.id}')), refused, reason: 'not his panel');
        final early = await hm.dio
            .post<dynamic>('/interviews/${round.id}/feedback', data: {'overallRating': 4, 'recommendation': 'YES'})
            .then<ApiError?>((_) => null)
            .catchError((Object e) => ApiError.from(e));
        expect(early, isNotNull, reason: 'a scorecard opens after the interview starts');
        expect(early!.statusCode, 400);
        expect(early.message, contains('after the interview starts'));
        final notHis = await hm.dio
            .post<dynamic>('/interviews/${other.id}/feedback', data: {'overallRating': 4, 'recommendation': 'YES'})
            .then<ApiError?>((_) => null)
            .catchError((Object e) => ApiError.from(e));
        expect(notHis!.statusCode, 403);
        expect(notHis.message, 'Only assigned interviewers can submit feedback.');
        // He is not the hiring team: no pipeline, no notes, no moves.
        expect(await refusedWith(hm.dio.post<dynamic>('/applications/$id/notes', data: {'note': 'x'})), 403);
        expect(await refusedWith(hm.dio.patch<dynamic>('/applications/$id/stage', data: {'stage': 'INTERVIEW'})), 403);
        expect(await refusedWith(hm.dio.get<dynamic>('/jobs/$adminJob/applications')), 403);

        // The office roles: the admin's posting is not theirs, the office posting is.
        for (final (who, repo) in [(recruiter, rc), (branchAdmin, ba)]) {
          expect(await refusedWith(repo.applicants(adminJob)), refused, reason: '${who.label}: outside the office');
          expect(await refusedWith(repo.applicant(id)), refused, reason: who.label);
          expect(await refusedWith(repo.moveStage(id, 'REJECTED')), refused, reason: who.label);
        }
        final officeApp = applications[officeJob]!;
        expect((await ba.applicants(officeJob)).applicants.single.id, officeApp);
        await ba.moveStage(officeApp, 'SCREENING');
        expect((await rc.applicants(officeJob)).applicants.single.stage, 'SCREENING');
        // Her own controller applies a move at once and puts back what the API refuses.
        final controller = ApplicantsController(ba, jobId: officeJob, jobTitle: 'office job');
        addTearDown(controller.dispose);
        await controller.start();
        final a = controller.applicants.single;
        expect(await controller.move(a, 'HIRED'), isNotNull);
        expect(controller.applicants.single.stage, 'SCREENING', reason: 'put back');
        expect(await controller.move(a, 'REJECTED', note: 'MOBILE-LIVE no fit'), isNull);
        expect(
          (await ca.applicants(officeJob)).applicants.single.stage,
          'REJECTED',
          reason: 'an admin sees the office admin\'s move',
        );
      },
    );
  });

  group('the companies screens\' calls', () {
    companyTest(
      'each account lists its company with its role, office and what waits; only the sole admin is told she cannot leave',
      () async {
        final expected = <LivePerson, ({String company, String role, String? office, bool sole})>{
          companyAdmin: (company: companyName, role: 'COMPANY_ADMIN', office: null, sole: false),
          founder: (company: companyName, role: 'COMPANY_ADMIN', office: null, sole: false),
          branchAdmin: (company: companyName, role: 'BRANCH_ADMIN', office: 'Head Office', sole: false),
          recruiter: (company: companyName, role: 'RECRUITER', office: 'Head Office', sole: false),
          hiringManager: (company: companyName, role: 'HIRING_MANAGER', office: 'Head Office', sole: false),
          marketBuyer: (company: 'Meridian Corporate Estates', role: 'COMPANY_ADMIN', office: null, sole: true),
          marketNoPhone: (company: 'Meridian Corporate Estates', role: 'BUYER', office: null, sole: false),
        };
        for (final entry in expected.entries) {
          final mine = await ApiAccountRepository(api: await liveClient(entry.key)).myCompanies();
          final active = mine.active;
          expect(active, isNotNull, reason: entry.key.label);
          expect(active!.name, entry.value.company, reason: entry.key.label);
          expect(active.role, entry.value.role, reason: entry.key.label);
          expect(active.branchName, entry.value.office, reason: entry.key.label);
          expect(active.soleAdmin, entry.value.sole, reason: entry.key.label);
          expect(mine.companies, hasLength(1), reason: entry.key.label);
          expect(mine.requests, isEmpty, reason: entry.key.label);
          expect(mine.canJoinCompanies, isTrue, reason: entry.key.label);
        }
      },
    );

    companyTest(
      'the only admin of a company cannot leave it: the API refuses in a sentence and nothing changes',
      () async {
        final repo = ApiAccountRepository(api: await liveClient(marketBuyer));
        final before = (await repo.myCompanies()).active!;
        expect(before.soleAdmin, isTrue);
        Object? error;
        try {
          await repo.leaveCompany(before.companyId);
        } catch (e) {
          error = e;
        }
        expect(error, isNotNull, reason: 'the API refuses');
        final refusal = ApiError.from(error!);
        expect(refusal.statusCode, anyOf(400, 403, 409));
        expect(refusal.message, isNotEmpty);
        final after = (await repo.myCompanies()).active!;
        expect(after.companyId, before.companyId);
        expect(after.role, 'COMPANY_ADMIN');
      },
    );

    companyTest(
      'a member acts for themselves and back, with a fresh token pair each time and the office kept',
      () async {
        // A session of its own: the role rides in the token, and the shared one stays as the other tests expect it.
        final api = await liveClient(hiringManager, true);
        final auth = AuthController(api: api, tokens: api.tokens);
        final repo = ApiAccountRepository(api: api);
        final controller = CompaniesController(
          repository: repo,
          adopt: (t) => auth.adoptSession(accessToken: t.accessToken, refreshToken: t.refreshToken, user: t.user),
        );
        addTearDown(controller.dispose);
        await controller.load();
        final company = controller.data!.active!;
        expect(company.role, 'HIRING_MANAGER');
        addTearDown(() async {
          // Whatever happened, the account ends acting for its company.
          try {
            if ((await repo.myCompanies()).active == null) await controller.switchTo(company.companyId);
          } catch (_) {}
        });

        expect(await controller.switchTo(null), isTrue, reason: controller.actionError ?? '');
        expect(controller.data!.active, isNull);
        expect(auth.user!.companyId, isNull);
        expect(auth.user!.role, 'PROFESSIONAL', reason: 'with no company active the role is the person\'s own');
        // As themselves they have no hiring surface at all.
        expect((await ApiHiringRepository(api: api).access()).canManage, isFalse);

        expect(await controller.switchTo(company.companyId), isTrue, reason: controller.actionError ?? '');
        expect(controller.data!.active!.companyId, company.companyId);
        expect(controller.data!.active!.role, 'HIRING_MANAGER');
        expect(controller.data!.active!.branchName, 'Head Office', reason: 'the office comes back with the place');
        expect(auth.user!.role, 'HIRING_MANAGER');
      },
    );

    companyTest(
      'a member asks to join another company; its admin is told; the member takes the request back',
      () async {
        final api = await liveClient(hiringManager);
        final repo = ApiAccountRepository(api: api);
        final admin = ApiAccountRepository(api: await liveClient(marketBuyer));
        final before = (await admin.myCompanies()).active!.pendingJoinRequests ?? 0;
        addTearDown(() async {
          try {
            await repo.withdrawRequest(marketCompanyId);
          } catch (_) {}
        });
        final lookalike = await repo.searchCompanies('Meridian');
        expect(lookalike.map((c) => c.id), contains(marketCompanyId));

        await repo.requestToJoin(marketCompanyId, note: 'Role test: Hema would like a place on this team.');
        var mine = await repo.myCompanies();
        expect(mine.requests.single.companyId, marketCompanyId);
        expect(mine.requests.single.note, contains('Role test'));
        expect(mine.companies.single.name, companyName, reason: 'asking moves nobody');
        expect((await admin.myCompanies()).active!.pendingJoinRequests, before + 1, reason: 'the admin is told');
        expect(await refusedWith(repo.requestToJoin(marketCompanyId)), isIn([400, 409]), reason: 'a second request');

        mine = await repo.withdrawRequest(marketCompanyId);
        expect(mine.requests, isEmpty);
        expect((await admin.myCompanies()).active!.pendingJoinRequests ?? 0, before);
      },
    );

    companyTest('a new person founds a company and is its admin; it appears in the company search', () async {
      final founderPerson = await signUpThrowaway(first: 'Founder');
      final repo = ApiAccountRepository(api: founderPerson.api);
      final name = 'Account Live Test Co role-company ${DateTime.now().millisecondsSinceEpoch}';
      final made = await repo.createCompany(
        CompanyDraft(
          name: name,
          industry: 'FM_SERVICES',
          size: '11-50',
          legalStructure: 'PRIVATE_LIMITED',
          city: 'Pune',
          state: 'Maharashtra',
        ),
      );
      await founderPerson.auth.adoptSession(
        accessToken: made.accessToken,
        refreshToken: made.refreshToken,
        user: made.user,
      );
      expect(founderPerson.auth.user!.role, 'COMPANY_ADMIN');
      final mine = await repo.myCompanies();
      expect(mine.active!.name, name);
      expect(mine.active!.soleAdmin, isTrue);
      expect((await repo.searchCompanies('Account Live Test Co role-company')).map((c) => c.name), contains(name));
      // A company admin\'s first hiring call works, and the company has no postings yet.
      final hiring = ApiHiringRepository(api: founderPerson.api);
      expect((await hiring.access()).canManage, isTrue);
      expect((await hiring.jobs()).jobs, isEmpty);
    });
  });
}
