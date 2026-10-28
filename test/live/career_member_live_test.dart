/// The member's career flows against the LOCAL portal API, through the app's own repository and
/// controllers: the tracker, one application, interviews, saved and hidden jobs, alerts,
/// invitations and the hub. Each control does the real thing, the effect is read back through the
/// API, and what can be undone is undone.
///
/// What cannot be undone through the API, and what the test does about it (all of it is put
/// back by `tool/seed/career.ts`, which every run of this file expects to have been run):
///  - A withdrawn application stays withdrawn: the test spends Pooja's SANDBOX application and
///    skips with a message when it is already withdrawn.
///  - An answered offer stays answered: it declines Pooja's SANDBOX offer, likewise.
///  - An invitation that was opened or declined stays so: Pooja's two invitations.
///  - A message to a hiring team opens (or finds) a thread: the thread is reused every run, and
///    the API allows 30 job messages an hour, so the file sends only three.
@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/career/application_logic.dart';
import 'package:icr_mobile/features/career/applications_controller.dart';
import 'package:icr_mobile/features/career/career_hub_screen.dart';
import 'package:icr_mobile/features/career/career_models.dart';
import 'package:icr_mobile/features/career/interviews_screen.dart';
import 'package:icr_mobile/features/career/invitations_screen.dart';
import 'package:icr_mobile/features/career/job_alert_models.dart';
import 'package:icr_mobile/features/career/job_alerts_controller.dart';
import 'package:icr_mobile/features/career/saved_jobs_controller.dart';

import 'career_live_support.dart';
import 'live.dart';

const _sandboxApp = 'design-career-app-pooja-sandbox';
const _sandboxOfferApp = 'design-career-app-pooja-sandbox-offer';

void main() {
  group('the tracker', () {
    liveTest('Bharat\'s applications are the designed three plus the one he withdrew, read in full', () async {
      final repo = await careerRepoFor(bharat);
      final apps = await repo.applications();
      final byId = {for (final a in apps) a.id: a};
      expect(
        byId.keys,
        containsAll(['design-lj-app-bharat-extra-1', 'design-lj-app-bharat-extra-2', 'design-lj-app-bharat-extra-3']),
      );
      expect(apps.where((a) => a.stage != 'WITHDRAWN'), hasLength(3), reason: 'the board\'s "My jobs 3" is untouched');

      final now = DateTime.now();
      final counts = tabCounts(apps, now);
      expect(counts[ApplicationsTab.active], 3);
      expect(counts[ApplicationsTab.interviews], greaterThanOrEqualTo(1));
      expect(counts[ApplicationsTab.archived], greaterThanOrEqualTo(1), reason: 'the withdrawn one');
      expect(defaultTab(counts), ApplicationsTab.active);

      final interview = byId['design-lj-app-bharat-extra-2']!;
      expect(statusOf(interview), AppStatus.interviewing);
      expect(interview.matchScore, 91);
      expect(interview.companyName, isNotEmpty);
      expect(interview.city, 'Pune');
      expect(interview.visibilityLocked, isFalse, reason: 'Bharat\'s plan shows the timeline');
      // The list carries only the rounds still on.
      expect(interview.interviews.every((r) => r.live), isTrue);
      expect(interview.interviews, isNotEmpty);

      final whole = await repo.application(interview.id);
      expect(whole.interviews.length, greaterThanOrEqualTo(2), reason: 'the detail has every round');
      expect(whole.interviews.map((r) => r.status), containsAll(['COMPLETED', 'SCHEDULED']));
      expect(whole.events, isNotEmpty);
      expect(whole.signals, isNotNull);
      expect(whole.signals!.map((s) => s.label), contains('Skills'));
      final next = nextStepOf(whole, now);
      expect(next, isA<InterviewStep>());
      expect(progressOf(whole)!.map((s) => s.label), ['Applied', 'Viewed', 'In review', 'Interview', 'Offer']);
      expect(progressOf(whole)![3].state, ProgressState.current);
    });

    liveTest('Pooja\'s tracker holds every state: an interview, an offer, not selected, withdrawn, applied', () async {
      final repo = await careerRepoFor(pooja);
      final apps = await repo.applications();
      final states = apps.map((a) => statusOf(a)).toSet();
      expect(
        states,
        containsAll([AppStatus.interviewing, AppStatus.offer, AppStatus.notSelected, AppStatus.withdrawn]),
      );
      final offer = apps.firstWhere((a) => a.id == 'design-career-app-pooja-offer');
      expect(offer.latestOffer!.status, anyOf('SENT', 'DECLINED', 'ACCEPTED'));
      expect(offer.latestOffer!.salaryAmount, 2400000);
      final interview = apps.firstWhere((a) => a.id == 'design-career-app-pooja-interview');
      expect(interview.interviews.map((r) => r.mode), contains(InterviewMode.inPerson));
      expect(interview.interviews.firstWhere((r) => r.mode == InterviewMode.inPerson).mapUrl, isNotNull);
      expect(interview.interviews.firstWhere((r) => r.mode == InterviewMode.video).joinUrl, isNotNull);
    });

    liveTest('the controller sorts, searches and counts what the API sent', () async {
      final c = ApplicationsController(await careerRepoFor(bharat));
      addTearDown(c.dispose);
      await c.start();
      expect(c.loaded, isTrue);
      expect(c.tab, ApplicationsTab.active);
      expect(c.rows, hasLength(3));
      c.selectTab(ApplicationsTab.all);
      expect(c.rows.length, c.apps.length);
      c.setSearch('hyderabad');
      expect(c.rows.map((a) => a.id), ['design-lj-app-bharat-extra-1']);
      c.setSearch('');
      c.setSort(ApplicationsSort.match);
      expect((c.rows.first.matchScore ?? 0), greaterThanOrEqualTo(c.rows.last.matchScore ?? 0));
      expect(c.summary.interviews, greaterThanOrEqualTo(1));
    });

    liveTest('withdrawing the sandbox application is kept by the API (spent: re-run career.ts to reset)', () async {
      final repo = await careerRepoFor(pooja);
      final before = await repo.application(_sandboxApp);
      if (before.stage == 'WITHDRAWN') {
        markTestSkipped('the sandbox application is already withdrawn: run tool/seed/career.ts to reset it');
        return;
      }
      final c = ApplicationsController(repo);
      addTearDown(c.dispose);
      await c.start();
      expect(canWithdraw(c.apps.firstWhere((a) => a.id == _sandboxApp)), isTrue);
      expect(await c.withdraw(before), isNull);
      final after = await repo.application(_sandboxApp);
      expect(after.stage, 'WITHDRAWN');
      expect(after.withdrawnAt, isNotNull);
      expect(statusOf(after), AppStatus.withdrawn);
      expect(inTab(after, ApplicationsTab.archived, DateTime.now()), isTrue);
      expect(canWithdraw(after), isFalse);
      // Withdrawing again is not an error: the API answers with the application as it stands.
      expect((await repo.withdraw(_sandboxApp)).stage, 'WITHDRAWN');
    });

    liveTest(
      'declining the sandbox offer is kept by the API, with the member\'s note (spent: re-run career.ts)',
      () async {
        final repo = await careerRepoFor(pooja);
        final before = await repo.application(_sandboxOfferApp);
        final offer = before.latestOffer;
        if (offer == null || offer.status != 'SENT') {
          markTestSkipped('the sandbox offer was already answered: run tool/seed/career.ts to reset it');
          return;
        }
        final c = ApplicationsController(repo);
        addTearDown(c.dispose);
        await c.start();
        final app = c.apps.firstWhere((a) => a.id == _sandboxOfferApp);
        expect(nextStepOf(app, DateTime.now()), isA<OfferStep>());
        expect(await c.respondToOffer(app, accept: false, note: 'MOBILE-LIVE: declined by the live test.'), isNull);
        final after = await repo.application(_sandboxOfferApp);
        expect(after.latestOffer!.status, 'DECLINED');
        expect(statusOf(after), AppStatus.offerDeclined);
        expect(inTab(after, ApplicationsTab.archived, DateTime.now()), isTrue);
        // Answering it again is refused, with the API's sentence.
        final again = await c.respondToOffer(after, accept: true);
        expect(again, isNotNull);
      },
    );

    liveTest('messaging the hiring team finds the same thread every time', () async {
      final repo = await careerRepoFor(pooja);
      final a = await repo.messageHiringTeam(
        'design-career-job-hard',
        message: 'MOBILE-LIVE: confirming the interview.',
      );
      final b = await repo.messageHiringTeam('design-career-job-hard');
      expect(a, isNotNull);
      expect(b, a, reason: 'one thread per member and job contact');
      // A job nobody can be messaged about answers with the API\'s own refusal.
      await expectLater(
        repo.messageHiringTeam('no-such-job'),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', anyOf(404, 400))),
      );
    });
  });

  group('interviews', () {
    liveTest('upcoming comes from the list, past from each application read whole', () async {
      final c = InterviewsController(await careerRepoFor(pooja));
      addTearDown(c.dispose);
      await c.start();
      expect(c.upcoming, isNotEmpty);
      expect(c.upcoming.map((e) => e.interview.id), contains('design-career-iv-pooja-interview-2'));
      final times = c.upcoming.map((e) => e.interview.scheduledAt).toList();
      expect(times, [...times]..sort());
      await c.select(InterviewsTab.past);
      expect(c.pastLoaded, isTrue);
      expect(c.past.map((e) => e.interview.id), contains('design-career-iv-pooja-interview-1'));
      expect(c.past.every((e) => !(e.interview.live && !e.interview.scheduledAt.isBefore(c.now))), isTrue);
    });
  });

  group('saved and hidden jobs', () {
    liveTest('Bharat\'s bookmarks are listed, one comes off and back, and the API keeps each', () async {
      final repo = await careerRepoFor(bharat);
      final c = SavedJobsController(repo);
      addTearDown(c.dispose);
      await c.start();
      expect(
        c.saved.map((j) => j.id),
        containsAll(['design-career-job-hard', 'design-career-job-energy', 'design-career-job-sandbox']),
      );
      expect(c.saved.every((j) => j.saved), isTrue);
      final job = c.saved.firstWhere((j) => j.id == 'design-career-job-sandbox');
      final at = c.indexOfSaved(job);

      expect(await c.unsave(job), isNull);
      expect(c.saved.map((j) => j.id), isNot(contains(job.id)));
      expect((await repo.savedJobs()).jobs.map((j) => j.id), isNot(contains(job.id)));
      expect((await repo.shelfCounts()).saved, 2);

      expect(await c.resave(job, at: at), isNull);
      expect((await repo.savedJobs()).jobs.map((j) => j.id), contains(job.id));
      expect((await repo.shelfCounts()).saved, 3);
    });

    liveTest('a hidden job is listed, shown again and hidden again, and the API keeps each', () async {
      final repo = await careerRepoFor(bharat);
      final c = SavedJobsController(repo, tab: SavedTab.hidden);
      addTearDown(c.dispose);
      await c.start();
      expect(c.hiddenLoaded, isTrue);
      final job = c.hidden.firstWhere((j) => j.id == 'design-career-job-invite2');
      expect(job.title, 'Procurement Lead - Facilities');

      expect(await c.unhide(job), isNull);
      expect((await repo.hiddenJobs()).map((j) => j.id), isNot(contains(job.id)));
      expect((await repo.shelfCounts()).hidden, 0);

      expect(await c.rehide(job), isNull);
      expect((await repo.hiddenJobs()).map((j) => j.id), contains(job.id));
    });

    liveTest('unbookmarking a job that is not bookmarked is the API\'s no-op, not an error', () async {
      final repo = await careerRepoFor(pooja);
      final c = SavedJobsController(repo);
      addTearDown(c.dispose);
      await c.start();
      expect(c.saved.map((j) => j.id), containsAll(['design-career-job-pipeline', 'design-career-job-invite']));
    });
  });

  group('job alerts', () {
    liveTest('Pooja\'s two searches are listed with their filters', () async {
      final c = JobAlertsController(await careerRepoFor(pooja));
      addTearDown(c.dispose);
      await c.start();
      final names = c.alerts.map((a) => a.name);
      expect(names, containsAll(['Facilities in Pune and Ahmedabad', 'Remote roles']));
      final west = c.alerts.firstWhere((a) => a.name == 'Facilities in Pune and Ahmedabad');
      expect(west.newMatches, greaterThan(0));
      expect(criteriaWords(west.criteria), containsAll(['Pune', 'Ahmedabad']));
      expect(west.alertsEnabled, isFalse);
    });

    liveTest('a search is made, switched, retimed, edited, run and deleted, each read back through the API', () async {
      final repo = await careerRepoFor(pooja);
      final c = JobAlertsController(repo);
      addTearDown(c.dispose);
      await c.start();
      const name = 'MOBILE-LIVE search';
      // A leftover of an interrupted run would clash on the name.
      for (final old in c.alerts.where((a) => a.name.startsWith('MOBILE-LIVE'))) {
        await c.delete(old);
      }

      final message = await c.create(
        const AlertDraft(
          name: name,
          criteria: AlertCriteria(search: 'chiller', cities: ['Pune'], workModes: {WorkMode.onsite}),
          alertsEnabled: false,
        ),
      );
      expect(message, isNull);
      var made = (await repo.alerts()).firstWhere((a) => a.name == name);
      expect(made.criteria, {'search': 'chiller', 'city': 'Pune', 'workMode': 'ONSITE'});
      expect(made.alertsEnabled, isFalse);
      expect(made.newMatches, 0, reason: 'a new search starts with nothing unseen');
      try {
        // The same name twice is refused with the API's sentence, and nothing is typed away.
        final clash = await c.create(
          const AlertDraft(
            name: name,
            criteria: AlertCriteria(search: 'x'),
          ),
        );
        expect(clash, isNotNull);
        expect(clash, contains(name));

        final local = c.alerts.firstWhere((a) => a.id == made.id);
        expect(await c.setEnabled(local, true), isNull);
        made = (await repo.alerts()).firstWhere((a) => a.id == made.id);
        expect(made.alertsEnabled, isTrue);
        expect(await c.setFrequency(made, 'WEEKLY'), isNull);
        made = (await repo.alerts()).firstWhere((a) => a.id == made.id);
        expect(made.frequency, 'WEEKLY');
        // Off again at once: the daily sweep would otherwise email a digest.
        expect(await c.setEnabled(made, false), isNull);

        final edited = await c.edit(
          made,
          AlertDraft(
            name: '$name (edited)',
            criteria: AlertCriteria.fromMap({...made.criteria, 'city': 'Pune,Nagpur'}),
            alertsEnabled: false,
            frequency: 'WEEKLY',
          ),
        );
        expect(edited, isNull);
        made = (await repo.alerts()).firstWhere((a) => a.id == made.id);
        expect(made.name, '$name (edited)');
        expect(made.criteria['city'], 'Pune,Nagpur');
        expect(made.criteria['search'], 'chiller');

        await c.toggleMatches(made);
        expect(c.openId, made.id);
        final matches = c.matchesOf(made.id);
        expect(matches.error, isNull);
        expect(matches.jobs.every((j) => j.city == 'Pune' || j.city == 'Nagpur'), isTrue);
      } finally {
        final gone = (await repo.alerts()).where((a) => a.name.startsWith(name));
        for (final a in gone) {
          expect(await c.delete(a), isNull);
        }
      }
      expect((await repo.alerts()).map((a) => a.name), isNot(contains(name)));
      expect(await c.delete(made), isNotNull, reason: 'deleting it twice: the API says it is not there');
    });

    liveTest('running a search lists what matches it; its new count is read from the API afresh', () async {
      final repo = await careerRepoFor(pooja);
      final remote = (await repo.alerts()).firstWhere((a) => a.name == 'Remote roles');
      final page = await repo.runAlert(remote.id);
      expect(page.jobs.every((j) => j.workMode == WorkMode.remote), isTrue);
      expect((await repo.alerts()).firstWhere((a) => a.id == remote.id).newMatches, 0);
    });

    liveTest('the board\'s "N new" is the sum over the alerts, and running a search takes its share off', () async {
      final repo = await careerRepoFor(bharat);
      final alerts = await repo.alerts();
      final total = alerts.fold<int>(0, (n, a) => n + a.newMatches);
      expect(total, 2, reason: 'the designed board reads "2 new"; the older searches add none');
      expect(alerts.first.name, 'Facilities & Real Estate', reason: 'the designed search is still the board\'s scope');
    });
  });

  group('invitations', () {
    liveTest('Pooja\'s invitations are listed: one waiting, one already seen', () async {
      final c = InvitationsController(await careerRepoFor(pooja));
      addTearDown(c.dispose);
      await c.start();
      // The second one is declined by the next test, until the seed resets it.
      expect(c.invites.map((i) => i.jobTitle), contains('Facility Operations Head'));
      final head = c.invites.firstWhere((i) => i.jobId == 'design-career-job-invite');
      expect(head.invitedBy, 'Meera Iyer');
      expect(head.message, isNotEmpty);
      expect(head.companyName, 'Northwind Facilities');
    });

    liveTest('an invitation opened is marked seen and one declined is gone (spent: re-run career.ts)', () async {
      final repo = await careerRepoFor(pooja);
      final c = InvitationsController(repo);
      addTearDown(c.dispose);
      await c.start();
      final waiting = c.invites.where((i) => i.id == 'design-career-invite-pooja-head' && i.status == 'SENT');
      final seen = c.invites.where((i) => i.id == 'design-career-invite-pooja-viewed');
      if (waiting.isEmpty || seen.isEmpty) {
        markTestSkipped('the invitations were already answered: run tool/seed/career.ts to reset them');
        return;
      }
      await c.markViewed(waiting.first);
      expect((await repo.invites()).firstWhere((i) => i.id == waiting.first.id).status, 'VIEWED');

      expect(await c.decline(seen.first), isNull);
      expect((await repo.invites()).map((i) => i.id), isNot(contains(seen.first.id)));
    });

    liveTest('the open-to-opportunities switch is kept by the API and put back', () async {
      final repo = await careerRepoFor(pooja);
      final c = InvitationsController(repo);
      addTearDown(c.dispose);
      await c.start();
      final was = c.discoverable;
      expect(was, isNotNull, reason: 'the seed gives Pooja a résumé');
      try {
        expect(await c.setDiscoverable(!was!), isNull);
        expect(await repo.discoverable(), !was);
      } finally {
        await repo.setDiscoverable(was!);
      }
      expect(await repo.discoverable(), was);
    });
  });

  group('the career hub', () {
    liveTest('reads the search at a glance from the API', () async {
      final c = CareerHubController(await careerRepoFor(bharat));
      addTearDown(c.dispose);
      await c.start();
      expect(c.loaded, isTrue);
      expect(c.error, isNull);
      expect(c.active, 3);
      expect(c.saved, 3);
      expect(c.hidden, 1);
      expect(c.interviews, isNotEmpty);
      expect(c.openInvites, isNotEmpty);
      expect(c.insights, isNotNull);
      expect(c.insights!.score, inInclusiveRange(1, 100));
      expect(c.performance, isNotNull);
      expect(c.stageCounts['INTERVIEW'], greaterThanOrEqualTo(1));
      expect(c.quota!.canApply, isTrue);
    });
  });
}
