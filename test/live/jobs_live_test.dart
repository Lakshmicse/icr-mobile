/// The Jobs controls against the LOCAL portal API: each one does the real thing,
/// the effect is read back through the API, and what can be undone is undone
/// (a bookmark, a temporary saved search, an application withdrawn).
///
/// What cannot be undone through the API, and what the test does about it:
///  - "Message" opens a conversation with the job's contact. The thread stays
///    (it is reused by the next run); `learning-jobs.ts --remove` deletes the
///    conversations with its seeded people.
///  - An application cannot be deleted, only withdrawn (`POST
///    /applications/:id/withdraw`): the Easy Apply test applies as Pooja to one
///    seeded job and withdraws it, and a later run re-applies to the same row.
///
/// Needs the seeds of `tool/seed` (`learning-jobs.ts`); run them first.
@Tags(['live'])
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/jobs/api_jobs_repository.dart';
import 'package:icr_mobile/features/jobs/job_detail_controller.dart';
import 'package:icr_mobile/features/jobs/job_format.dart';
import 'package:icr_mobile/features/jobs/job_models.dart';
import 'package:icr_mobile/features/jobs/jobs_controller.dart';
import 'package:icr_mobile/features/jobs/jobs_repository.dart';

import '../jobs_fakes.dart';
import 'live.dart';

/// A member with no saved search and no résumé, for the board that shows plain "Latest jobs". Pooja used to be
/// that person; `tool/seed/career.ts` gives her two saved searches (her board is then scoped to the first), so
/// the tests that need the unscoped board read it as Meera Iyer, who signs in with the career seed's password.
const plainBoard = LivePerson('meera.iyer@career.icr.test', 'Career@12345', 'Meera Iyer');

/// The seeded jobs the tests lean on (`tool/seed/learning-jobs.ts`).
const sheetJob = 'design-lj-job-global-infra';
const stpJob = 'design-lj-job-stp-1';
const campusJob = 'design-lj-job-extra-1';
const energyJob = 'design-lj-job-extra-2';
const externalJob = 'design-lj-job-external-1';

final _clients = <String, Future<ApiClient>>{};

/// One signed-in client per person for the whole file (the API allows a few
/// sign-ins a minute), that waits out a "too many requests" instead of failing:
/// the portal's limit is 120 requests a minute for everyone on this machine,
/// and the other screens' live tests share it.
Future<ApiClient> clientFor(LivePerson who) => _clients.putIfAbsent(who.email, () async {
  for (var attempt = 0; ; attempt++) {
    try {
      final api = await liveClient(who);
      api.dio.interceptors.add(_waitWhenThrottled(api.dio));
      return api;
    } on DioException catch (e) {
      if (e.response?.statusCode != 429 || attempt >= 6) rethrow;
      await Future<void>.delayed(const Duration(seconds: 12));
    }
  }
});

Interceptor _waitWhenThrottled(Dio dio) => InterceptorsWrapper(
  onError: (error, handler) async {
    final tries = (error.requestOptions.extra['throttled'] as int?) ?? 0;
    if (error.response?.statusCode != 429 || tries >= 6) return handler.next(error);
    final wait = int.tryParse(error.response?.headers.value('retry-after') ?? '') ?? 8;
    await Future<void>.delayed(Duration(seconds: wait.clamp(2, 30)));
    error.requestOptions.extra['throttled'] = tries + 1;
    try {
      handler.resolve(await dio.fetch(error.requestOptions));
    } on DioException catch (again) {
      handler.next(again);
    }
  },
);

Future<ApiJobsRepository> repoFor(LivePerson who, {int pageSize = 20}) async =>
    ApiJobsRepository(api: await clientFor(who), pageSize: pageSize);

/// The board, started, as the screen does it.
Future<JobsController> startedBoard(JobsRepository repo) async {
  final jobs = JobsController(repo, links: RecordingLinks());
  addTearDown(jobs.dispose);
  await jobs.start();
  expect(jobs.error, isNull, reason: 'the board loads');
  return jobs;
}

Future<Map<String, dynamic>> getMap(ApiClient api, String path, [Map<String, dynamic>? query]) async =>
    (await api.dio.get<Map<String, dynamic>>(path, queryParameters: query)).data!;

Future<List<dynamic>> getList(ApiClient api, String path) async => (await api.dio.get<List<dynamic>>(path)).data!;

Iterable<String> idsOf(JobsController jobs) => jobs.sections.expand((s) => s.jobs).map((j) => j.id);

/// The board with a job of its own that the API has never heard of.
class _GhostBoard extends ApiJobsRepository {
  _GhostBoard({required super.api});

  static final ghost = fakeJob('ghost-job', title: 'A job that is gone');

  @override
  Future<JobsOverview> overview({bool scoped = true}) async {
    final real = await super.overview(scoped: scoped);
    return JobsOverview(
      sections: [
        JobSection(key: 'ghost', title: 'Ghost', jobs: [ghost]),
        ...real.sections,
      ],
      myJobs: real.myJobs,
      newAlerts: real.newAlerts,
      alert: real.alert,
    );
  }
}

void main() {
  liveTest(
    'the board: three sections of three rows and View More, the saved search as the scope, the counts',
    () async {
      final api = await clientFor(bharat);
      final repo = await repoFor(bharat);
      final jobs = await startedBoard(repo);

      expect(jobs.sections.map((s) => s.key), ['foryou', 'preferences', 'alert']);
      expect(jobs.sections.map((s) => s.title), [
        'Recommended Jobs for You',
        'Matching your preferences',
        'Facilities & Real Estate',
      ]);
      for (final section in jobs.sections) {
        expect(jobs.visible(section), hasLength(3), reason: '${section.key} shows three rows until View More');
        expect(jobs.actionLabel(section), 'View More', reason: '${section.key} has more than three');
      }
      expect(jobs.sections.first.jobs.map((j) => j.id), containsAll([stpJob, sheetJob]));
      expect(
        jobs.sections.first.jobs.every((j) => j.matchScore != null),
        isTrue,
        reason: 'the for-you feed scores each',
      );
      expect(jobs.sections.first.hasMore, isFalse, reason: 'a short feed has no second page');

      expect(jobs.context?.label, 'Facilities & Real Estate');
      expect(jobs.context?.place, 'Bengaluru, IN');
      expect(jobs.context?.criteria, {'city': 'Bengaluru,Mumbai', 'country': 'India'});
      expect(jobs.filterCount, 3, reason: 'Easy Apply, and the saved search\'s city and country');
      expect(jobs.myJobs, greaterThanOrEqualTo(3), reason: 'the three seeded applications');

      final unread = await getMap(api, '/notifications/unread-count');
      expect(jobs.unread, unread['unread'], reason: 'the bell');
    },
  );

  liveTest('View More: the rest, then real pages of the saved search until it is all on show', () async {
    final api = await clientFor(bharat);
    final jobs = await startedBoard(await repoFor(bharat, pageSize: 3));
    var section = jobs.sections.firstWhere((s) => s.key == 'alert');
    expect(section.jobs, hasLength(3));
    expect(section.hasMore, isTrue, reason: 'the saved search matches more than a page of three');
    expect(jobs.actionLabel(section), 'View More');

    var taps = 0;
    while (jobs.actionLabel(section) == 'View More') {
      expect(taps++, lessThan(12), reason: 'it ends');
      await jobs.act(section);
      section = jobs.sections.firstWhere((s) => s.key == 'alert');
    }
    expect(jobs.isExpanded(section), isTrue);
    expect(jobs.actionLabel(section), 'Show Less');

    final all = await getMap(api, '/jobs', {'city': 'Bengaluru,Mumbai', 'country': 'India', 'limit': 50});
    final expected = (all['data'] as List).map((j) => (j as Map)['id']).toSet();
    expect(section.jobs.map((j) => j.id).toSet(), expected, reason: 'every page, each job once');
    expect(section.jobs.length, expected.length);

    await jobs.act(section);
    expect(jobs.visible(jobs.sections.firstWhere((s) => s.key == 'alert')), hasLength(3), reason: 'Show Less');
  });

  liveTest('View More pages the latest jobs too, and a search\'s results as the list scrolls', () async {
    final repo = await repoFor(plainBoard, pageSize: 5);
    final first = await repo.latest();
    final second = await repo.latest(page: 2);
    expect(first.jobs, hasLength(5));
    expect(first.hasMore, isTrue);
    expect(second.jobs, hasLength(5));
    expect(second.jobs.map((j) => j.id).toSet().intersection(first.jobs.map((j) => j.id).toSet()), isEmpty);

    final jobs = await startedBoard(repo);
    await jobs.setSearch('Manager');
    final results = jobs.sections.single;
    expect(results.jobs, hasLength(5));
    expect(results.hasMore, isTrue, reason: 'more than five managers on the board');
    await jobs.loadMore();
    expect(jobs.sections.single.jobs.length, greaterThan(5));
    expect(jobs.sections.single.jobs.map((j) => j.id).toSet(), hasLength(jobs.sections.single.jobs.length));
  });

  liveTest('search, the date and the filters narrow GET /jobs', () async {
    final repo = await repoFor(plainBoard);
    final jobs = await startedBoard(repo);
    expect(jobs.sections.last.key, 'latest', reason: 'this member has no saved search, so no scope');
    expect(jobs.context, isNull);

    await jobs.setSearch('STP');
    expect(jobs.narrowed, isTrue);
    expect(jobs.sections.single.title, 'Jobs matching "STP"');
    final stp = jobs.sections.single.jobs;
    expect(stp.map((j) => j.id), contains(stpJob));
    expect(
      stp.every((j) => '${j.title} ${j.descriptionHtml} ${j.skills.join(' ')}'.toLowerCase().contains('stp')),
      isTrue,
    );

    await jobs.setSearch('zzzqqqxxx');
    expect(jobs.sections.single.jobs, isEmpty, reason: 'a search nothing matches');

    // The seeded STP job was posted a few days before the seed ran.
    await jobs.setSearch('STP');
    final age = DateTime.now().difference(stp.firstWhere((j) => j.id == stpJob).postedAt!).inDays;
    await jobs.setPostedWithin(age + 2);
    expect(idsOf(jobs), contains(stpJob), reason: 'inside the window');
    expect(jobs.filters.postedWithinDays, age + 2);
    if (age >= 2) {
      await jobs.setPostedWithin(age - 1);
      expect(idsOf(jobs), isNot(contains(stpJob)), reason: 'outside the window');
    }
    await jobs.setPostedWithin(null);
    expect(jobs.filters.postedWithinDays, isNull);

    await jobs.setFilters(const JobFilters(search: 'STP', workModes: {WorkMode.remote}));
    expect(jobs.sections.single.jobs, isEmpty, reason: 'the STP jobs are on-site');
    await jobs.setFilters(const JobFilters(search: 'STP', workModes: {WorkMode.onsite}));
    expect(idsOf(jobs), contains(stpJob));
    expect(jobs.sections.single.jobs.every((j) => j.workMode == WorkMode.onsite), isTrue);

    await jobs.setFilters(const JobFilters(search: 'STP', employmentTypes: {EmploymentType.contract}));
    expect(idsOf(jobs), isNot(contains(stpJob)), reason: 'it is full-time');
    await jobs.setFilters(const JobFilters(search: 'STP', employmentTypes: {EmploymentType.fullTime}));
    expect(idsOf(jobs), contains(stpJob));

    await jobs.setFilters(const JobFilters(search: 'STP', city: 'Pune'));
    expect(jobs.sections.single.jobs, isEmpty, reason: 'it is in Mumbai');
    await jobs.setFilters(const JobFilters(search: 'STP', city: 'Mumbai'));
    expect(idsOf(jobs), contains(stpJob));
    expect(jobs.filterCount, 2, reason: 'Easy Apply and the city');

    await jobs.clearFilters();
    expect(jobs.narrowed, isTrue, reason: 'the search is still there');
    await jobs.setSearch('');
    expect(jobs.narrowed, isFalse);
  });

  liveTest('a search is made inside the saved search, and the cross widens it', () async {
    final jobs = await startedBoard(await repoFor(bharat));
    expect(jobs.filterCount, 3);
    await jobs.setSearch('Sustainability');
    expect(idsOf(jobs), isNot(contains(energyJob)), reason: 'that job is in Pune, outside Bengaluru and Mumbai');

    await jobs.clearContext();
    expect(jobs.context, isNull);
    expect(jobs.filterCount, 1, reason: 'Easy Apply only: the saved search\'s city and country went with the scope');
    expect(idsOf(jobs), contains(energyJob), reason: 'the same search over every job');

    await jobs.setSearch('');
    expect(jobs.sections.map((s) => s.key), ['foryou', 'preferences', 'latest'], reason: 'the board, unscoped');
    final latest = jobs.sections.last.jobs;
    expect(latest.length, greaterThan(13), reason: 'more than the saved search\'s 13');
  });

  liveTest('Easy Apply trims the job that takes applications on its own site, which the API will not take', () async {
    final repo = await repoFor(plainBoard);
    final jobs = await startedBoard(repo);
    await jobs.setSearch('Estate Operations');
    final results = jobs.sections.single;
    final external = results.jobs.firstWhere((j) => j.id == externalJob);
    expect(external.easyApply, isFalse);
    expect(external.externalApply, isTrue);
    expect(external.applyUrl, 'https://careers.globalinfra.example/jobs/estate-operations-manager');

    expect(jobs.filters.easyApply, isTrue);
    expect(jobs.jobsOf(results).map((j) => j.id), isNot(contains(externalJob)));
    jobs.toggleEasyApply();
    expect(jobs.jobsOf(results).map((j) => j.id), contains(externalJob));
    expect(jobs.filterCount, 0);

    // The sheet opens the employer's site instead, because the API refuses.
    await expectLater(
      repo.apply(external),
      throwsA(
        isA<ApiError>().having((e) => e.message, 'message', 'This employer accepts applications on their own site.'),
      ),
    );
  });

  liveTest('bookmarks are the API\'s: saved, read back, kept by a refresh, undone; a refused one rolls back', () async {
    final api = await clientFor(plainBoard);
    Future<bool> savedOnServer() async => (await getMap(api, '/jobs/actions'))['savedIds'].contains(campusJob) as bool;
    addTearDown(() async {
      if (await savedOnServer()) await api.dio.delete<dynamic>('/jobs/$campusJob/save');
    });
    if (await savedOnServer()) await api.dio.delete<dynamic>('/jobs/$campusJob/save');

    final jobs = await startedBoard(await repoFor(plainBoard));
    await jobs.setSearch('Technology Campus');
    final job = jobs.sections.single.jobs.firstWhere((j) => j.id == campusJob);
    expect(job.saved, isFalse);

    expect(await jobs.toggleSave(job), isNull);
    expect(jobs.find(campusJob)!.saved, isTrue);
    expect(await savedOnServer(), isTrue);

    await jobs.refresh();
    expect(jobs.find(campusJob)!.saved, isTrue, reason: 'a refresh reads the bookmark from the API');

    expect(await jobs.toggleSave(jobs.find(campusJob)!), isNull);
    expect(jobs.find(campusJob)!.saved, isFalse);
    expect(await savedOnServer(), isFalse);

    final ghostBoard = await startedBoard(_GhostBoard(api: api));
    final message = await ghostBoard.toggleSave(_GhostBoard.ghost);
    expect(message, isNotNull, reason: 'the API has no such job: ${message ?? ''}');
    expect(ghostBoard.find('ghost-job')!.saved, isFalse, reason: 'rolled back');
  });

  liveTest('Alerts: opening the board does not mark the saved search seen', () async {
    final api = await clientFor(bharat);
    Future<Object?> newMatches() async => (await getList(api, '/jobs/alerts')).first['newMatchCount'];

    final before = await newMatches();
    final repo = await repoFor(bharat);
    await repo.overview();
    await repo.overview();
    expect(await newMatches(), before, reason: 'reading the saved search\'s results is not running it');
  });

  liveTest('Alerts: tapping it runs the saved search, which counts its matches as seen', () async {
    final api = await clientFor(plainBoard);
    final made = await api.dio.post<Map<String, dynamic>>(
      '/jobs/alerts',
      data: {
        'name': 'Jobs live test',
        'criteria': {'city': 'Bengaluru'},
        'alertsEnabled': false,
      },
    );
    final id = made.data!['id'] as String;
    addTearDown(() => api.dio.delete<dynamic>('/jobs/alerts/$id'));
    final started = DateTime.now().toUtc().subtract(const Duration(minutes: 1));

    final jobs = await startedBoard(await repoFor(plainBoard));
    expect(jobs.context?.label, 'Jobs live test');
    expect(jobs.context?.alertId, id);
    expect(jobs.context?.place, 'Bengaluru, IN');
    final section = jobs.sections.firstWhere((s) => s.key == 'alert');
    expect(section.jobs, isNotEmpty);
    expect(section.jobs.every((j) => j.city == 'Bengaluru'), isTrue, reason: 'the saved search\'s filter');

    expect(await jobs.runAlert(), isNull);

    final row = (await getList(api, '/jobs/alerts')).cast<Map<String, dynamic>>().firstWhere((a) => a['id'] == id);
    expect(DateTime.parse(row['lastRunAt'] as String).isAfter(started), isTrue, reason: 'the API ran it');
    expect(row['newMatchCount'], 0);
    expect(jobs.newAlerts, 0);
    expect(jobs.isExpanded(jobs.sections.firstWhere((s) => s.key == 'alert')), isTrue);
    expect(jobs.context, isNotNull);
  });

  liveTest(
    'the job sheet: tagline, About tile, contact and no counts, from GET /jobs/:id and GET /companies/:id',
    () async {
      final repo = await repoFor(bharat);
      final job = await repo.detail(sheetJob);
      expect(job.title, 'Senior Facilities Manager');
      expect(job.company.name, 'Global Infra Solutions');
      expect(job.company.tagline, 'Commercial Real Estate Services', reason: 'the company\'s industry');
      expect(job.company.kind, 'Real Estate');
      expect(job.company.size, '500+ employees');
      expect(job.company.cover?.url, endsWith('design-lj-company-photo.png'), reason: 'the first photo of its gallery');
      expect(job.company.logo?.url, endsWith('design-lj-company-logo.png'));
      expect(job.company.legalName, isNull, reason: 'the API keeps it private');
      expect(job.highlight, 'Commercial Grade-A Towers • 2.4M+ sq.ft.');
      expect(job.contact?.name, 'Priya Sharma');
      expect(job.contact?.role, 'Job poster');
      expect(job.contact?.designation, 'Lead Talent Partner @ Global Infra');
      expect(job.contact?.photo?.url, endsWith('design-lj-avatar-priya.png'));
      expect(job.contact?.degree, isNull);
      expect(job.contact?.activity, isNull);
      expect(job.applicants, isNull, reason: 'the API tells only the job\'s team');
      expect(job.views, isNull);
      expect(applicantsOrOpenings(job), '2 openings');
      expect(job.educationQualifications, ['UG_BTECH_MECHANICAL', 'UG_BTECH_ELECTRICAL']);
      expect(job.externalApply, isFalse);
    },
  );

  liveTest('the match card: the job\'s years, degree, credential and skills against Bharat\'s profile', () async {
    final repo = await repoFor(bharat);
    final job = await repo.detail(sheetJob);
    final match = await repo.match(job);
    expect(match, isNotNull);
    expect(match!.checks, isNotEmpty);
    if (!match.locked) return; // the AI preview answered (a database with pgvector): its own rows
    expect(match.checks.map((c) => c.label), [
      '8+ years of experience',
      'B.Tech / B.E. in Mechanical or Electrical',
      'RICS or IFMA Facility Management Charter',
      'BMS Automation',
      'HVAC Chillers',
      'EHS Auditing',
      'Vendor SLAs',
      'OpEx Planning',
    ]);
    expect(match.checks.map((c) => c.met), [true, true, false, true, true, true, true, false]);
    final profile = await getMap(await clientFor(bharat), '/users/me/profile');
    final years = ((profile['resume'] as Map)['yearsExperience'] as num).toDouble();
    final yearsText = years == years.roundToDouble() ? '${years.round()}' : '$years';
    expect(match.checks[0].detail, 'Your résumé lists $yearsText years of experience.');
    expect(match.checks[1].detail, 'Your profile lists B.Tech, Mechanical Engineering.');
    expect(match.checks[2].detail, 'Preferred credential. Not on your profile yet.');
    expect(match.met, 6);
  });

  liveTest('the strip of faces: who works at the company, from GET /companies/:id/people', () async {
    final repo = await repoFor(bharat);
    final job = await repo.detail(sheetJob);
    final people = await repo.peopleAt(job.company);
    expect(people, isNotNull);
    expect(people!.total, 5);
    expect(people.names.first, 'Nikhil M.');
    expect(people.others, 4);
    expect(people.text, 'Nikhil M. and 4 others from ICR work at this organization.');
    expect(people.initials.first, 'NM');
    expect(people.photos.whereType<FeedPicture>().map((p) => p.url), [contains('design-lj-avatar-priya.png')]);
  });

  liveTest('My jobs lists the applications, with where each stands, from GET /applications/mine', () async {
    final repo = await repoFor(bharat);
    final mine = await repo.myJobs();
    final titles = mine.applications.map((a) => a.job.title);
    expect(titles, containsAll(['Facilities Manager - Technology Campus', 'Energy and Sustainability Lead']));
    expect(mine.applications.map((a) => a.stageLabel), containsAll(['Applied', 'Interview']));
    expect(mine.applications.every((a) => a.open && a.appliedAt != null), isTrue);
    expect(mine.applications.first.job.company.name, isNotEmpty);
  });

  liveTest('Message opens the real conversation with the hiring contact, and the same one again', () async {
    final api = await clientFor(bharat);
    final repo = await repoFor(bharat);
    final controller = JobDetailController(repository: repo, seed: await repo.detail(sheetJob));
    final first = await controller.messageContact();
    expect(first.error, isNull);
    final id = first.thread!.queryParameters['c'];
    expect(first.thread!.path, '/messaging');
    expect(id, isNotEmpty);

    final conversations = (await api.dio.get<dynamic>('/messaging/conversations')).data;
    final rows = (conversations is List ? conversations : (conversations as Map)['data'] as List).cast<Map>();
    expect(rows.map((c) => c['id']), contains(id), reason: 'it is in Bharat\'s conversations');

    final again = await controller.messageContact();
    expect(again.thread!.queryParameters['c'], id, reason: 'one thread per job contact');
  });

  liveTest('Easy Apply with no phone on file is refused before anything is written', () async {
    final api = await clientFor(bharat);
    final me = await getMap(api, '/auth/me');
    final phone = me['phone'] as String?;
    if (phone != null && phone.trim().isNotEmpty) {
      markTestSkipped('Bharat has a phone on file now, so an application would really be sent');
      return;
    }
    final repo = await repoFor(bharat);
    final controller = JobDetailController(repository: repo, seed: await repo.detail(sheetJob));
    expect(await controller.needsPhone(), isTrue);

    final result = await controller.apply(coverNote: 'This must not be sent.');
    expect(result.ok, isFalse);
    expect(result.needsPhone, isTrue);
    expect(result.message, 'Add a mobile number so the employer can reach you.');
    expect(controller.job.applied, isFalse);

    final mine = await getList(api, '/applications/mine');
    expect(mine.map((a) => (a as Map)['jobId']), isNot(contains(sheetJob)), reason: 'nothing was written');
  });

  liveTest('Easy Apply sends a real application, My jobs lists it, a second is refused, and it is withdrawn', () async {
    final api = await clientFor(pooja);
    Future<List<Map<String, dynamic>>> open() async => (await getList(
      api,
      '/applications/mine',
    )).cast<Map<String, dynamic>>().where((a) => a['jobId'] == campusJob && a['stage'] != 'WITHDRAWN').toList();
    Future<void> withdraw() async {
      for (final a in await open()) {
        await api.dio.post<dynamic>('/applications/${a['id']}/withdraw');
      }
    }

    addTearDown(withdraw);
    await withdraw(); // a run that died half way left one

    final repo = await repoFor(pooja);
    final job = await repo.detail(campusJob);
    expect(job.easyApply, isTrue);
    expect(job.applied, isFalse);
    final jobs = await startedBoard(repo);
    final before = jobs.myJobs;
    final controller = JobDetailController(
      repository: repo,
      seed: job,
      onChanged: jobs.update,
      onApplied: jobs.applied,
    );
    await controller.load();
    expect(await controller.needsPhone(), isFalse, reason: 'Pooja has a phone on file');

    final result = await controller.apply(
      coverNote: 'Live test: sent from the app, withdrawn straight after.',
      linkedinUrl: 'linkedin.com/in/mobile-live-tester',
    );
    expect(result.ok, isTrue, reason: result.message);
    expect(controller.job.applied, isTrue);
    expect(jobs.myJobs, before + 1);

    final sent = (await open()).single;
    expect(sent['stage'], 'APPLIED');
    expect(sent['coverNote'], 'Live test: sent from the app, withdrawn straight after.');
    expect(
      sent['linkedinUrl'],
      contains('linkedin.com/in/mobile-live-tester'),
      reason: 'the link travels with the application',
    );

    final mine = await (await repoFor(pooja)).myJobs();
    expect(mine.applications.map((a) => a.job.id), contains(campusJob));
    expect(mine.applications.firstWhere((a) => a.job.id == campusJob).stageLabel, 'Applied');

    final again = await controller.apply();
    expect(again.ok, isFalse);
    expect(again.message, 'You have already applied to this job.');

    await withdraw();
    expect(await open(), isEmpty);
    final after = await (await repoFor(pooja)).myJobs();
    expect(after.applications.map((a) => a.job.id), isNot(contains(campusJob)), reason: 'no longer one of My jobs');
  });

  liveTest(
    'the API refuses what the form asks first: a bad LinkedIn link, a diversity-only role, a role for one gender',
    () async {
      final repo = await repoFor(pooja);
      final api = await clientFor(pooja);
      Future<ApiError> refusal(Future<void> Function() send) async {
        try {
          await send();
        } on ApiError catch (e) {
          return e;
        }
        fail('the API took an application it should have refused');
      }

      final campus = await repo.detail(campusJob);
      final badLink = await refusal(() => repo.apply(campus, linkedinUrl: 'example.com/in/me'));
      expect(badLink.statusCode, 400);
      expect(badLink.message, contains('LinkedIn'));

      final women = await repo.detail('design-career-job-womenonly');
      expect(women.diversityOnly, isTrue);
      expect(women.diversityCategories, ['WOMEN_RETURNING']);
      final noDeclaration = await refusal(() => repo.apply(women));
      expect(noDeclaration.statusCode, 400);
      expect(
        noDeclaration.message,
        startsWith('This role accepts applications only from women returning to work candidates.'),
      );

      final female = await repo.detail('design-career-job-femaleonly');
      expect(female.genderPreference, 'FEMALE');
      final noGender = await refusal(() => repo.apply(female));
      expect(noGender.statusCode, 400);
      expect(noGender.message, 'This role accepts applications only from women.');

      final mine = (await getList(api, '/applications/mine')).cast<Map<String, dynamic>>();
      expect(
        mine.map((a) => a['jobId']),
        isNot(containsAll(['design-career-job-womenonly', 'design-career-job-femaleonly'])),
      );
    },
  );

  liveTest('the bell\'s count is the API\'s unread count', () async {
    final api = await clientFor(pooja);
    final repo = await repoFor(pooja);
    expect(await repo.unreadNotifications(), (await getMap(api, '/notifications/unread-count'))['unread']);
  });
}
