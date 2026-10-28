/// The career screens drawn over the LOCAL portal API: the real payloads must
/// parse and draw (the repository tests prove the shapes; this proves the screen).
///
/// Needs `tool/seed/learning-jobs.ts` and `career.ts`.
@Tags(['live'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/career/api_career_repository.dart';
import 'package:icr_mobile/features/career/application_detail_screen.dart';
import 'package:icr_mobile/features/career/career_hub_screen.dart';
import 'package:icr_mobile/features/career/company_insights_controller.dart';
import 'package:icr_mobile/features/career/company_insights_screen.dart';
import 'package:icr_mobile/features/career/interviews_screen.dart';
import 'package:icr_mobile/features/career/invitations_screen.dart';
import 'package:icr_mobile/features/career/job_alerts_screen.dart';
import 'package:icr_mobile/features/career/my_applications_screen.dart';
import 'package:icr_mobile/features/career/saved_jobs_screen.dart';
import 'package:icr_mobile/features/jobs/api_jobs_repository.dart';

import '../helpers/fonts.dart';
import '../jobs_fakes.dart';
import 'career_live_support.dart';
import 'live.dart';

const _globalInfra = 'design-lj-co-global-infra';

Future<ApiCareerRepository> _career(WidgetTester tester, LivePerson who) async {
  final api = (await tester.runAsync(() => liveClient(who)))!;
  return ApiCareerRepository(
    api: api,
    jobs: ApiJobsRepository(api: api),
  );
}

void main() {
  setUpAll(loadAppFonts);

  group('a company\'s careers page', () {
    testWidgets('opened by its id it draws the header and every tab from the API', tags: const ['live'], (
      tester,
    ) async {
      if (!await liveScreenReady(tester)) return;
      final repo = await _career(tester, bharat);
      await pumpLive(
        tester,
        CompanyInsightsScreen.forId(repository: repo, companyId: _globalInfra, links: RecordingLinks()),
      );
      await settleLive(tester);

      // The header: the name and the line under it come from GET /companies/:id.
      expect(find.text('Global Infra Solutions'), findsWidgets);
      expect(find.byKey(const ValueKey('header-rating')), findsOneWidget, reason: 'it has approved reviews');

      // Jobs lead.
      expect(find.text('Senior Facilities Manager'), findsWidgets);

      for (final (tab, probe) in [
        (InsightsTab.people, 'Nikhil Menon'),
        (InsightsTab.reviews, 'A place that lets facilities people lead'),
        (InsightsTab.salaries, 'Facilities Manager'),
        (InsightsTab.interviews, 'Senior Facilities Manager'),
      ]) {
        await tester.tap(find.byKey(ValueKey('tab-${tab.name}')));
        await settleLive(tester);
        expect(find.text(probe), findsWidgets, reason: '${tab.label} shows "$probe"');
      }
      await finishLive(tester);
    });
  });

  group('the member screens', () {
    testWidgets('My applications draws Bharat tracker from the API: figures, up next, rows', tags: const ['live'], (
      tester,
    ) async {
      if (!await liveScreenReady(tester)) return;
      final repo = await _career(tester, bharat);
      await pumpLive(
        tester,
        MyApplicationsScreen(key: UniqueKey(), repository: repo, links: RecordingLinks()),
        size: const Size(390, 2400),
      );
      await settleLive(tester);
      expect(find.text('My applications'), findsOneWidget);
      expect(find.byKey(const ValueKey('summary-active')), findsOneWidget);
      expect(find.byKey(const ValueKey('up-next')), findsOneWidget, reason: 'a round is coming up');
      expect(find.text('Energy and Sustainability Lead'), findsWidgets);
      expect(find.text('Interviewing'), findsWidgets);
      expect(find.byKey(const ValueKey('progress')), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('applications-tab-archived')));
      await settleLive(tester);
      expect(find.text('Withdrawn'), findsWidgets);
      await finishLive(tester);
    });

    testWidgets('an application page draws the rounds, the match, the answers and the timeline', tags: const ['live'], (
      tester,
    ) async {
      if (!await liveScreenReady(tester)) return;
      final repo = await _career(tester, bharat);
      final seed = (await tester.runAsync(() => repo.application('design-lj-app-bharat-extra-2')))!;
      await pumpLive(
        tester,
        ApplicationDetailScreen(key: UniqueKey(), repository: repo, application: seed, links: RecordingLinks()),
        size: const Size(390, 2600),
      );
      await settleLive(tester);
      expect(find.text('Energy and Sustainability Lead'), findsWidgets);
      expect(find.byKey(const ValueKey('match-score')), findsOneWidget);
      expect(find.byKey(const ValueKey('match-breakdown')), findsOneWidget);
      expect(find.byKey(const ValueKey('interviews')), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('HR screening'), findsOneWidget);
      expect(find.byKey(const ValueKey('timeline')), findsOneWidget);
      expect(find.text('You applied'), findsOneWidget);
      await finishLive(tester);
    });

    testWidgets('Interviews draws Pooja rounds to come and the ones held', tags: const ['live'], (tester) async {
      if (!await liveScreenReady(tester)) return;
      final repo = await _career(tester, pooja);
      await pumpLive(
        tester,
        InterviewsScreen(key: UniqueKey(), repository: repo, links: RecordingLinks()),
        size: const Size(390, 2000),
      );
      await settleLive(tester);
      expect(find.text('Round 2 • Site head round'), findsOneWidget);
      expect(find.byKey(const ValueKey('join-design-career-iv-pooja-interview-2')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('interviews-tab-past')));
      await settleLive(tester);
      expect(find.text('Round 1 • Technical round'), findsWidgets);
      expect(find.text('Completed'), findsWidgets);
      await finishLive(tester);
    });

    testWidgets('Saved jobs draws Bharat bookmarks and his hidden job', tags: const ['live'], (tester) async {
      if (!await liveScreenReady(tester)) return;
      final repo = await _career(tester, bharat);
      await pumpLive(tester, SavedJobsScreen(key: UniqueKey(), repository: repo, links: RecordingLinks()));
      await settleLive(tester);
      expect(find.text('Senior Manager - Hard Services'), findsOneWidget);
      expect(find.text('Energy Manager'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('saved-tab-hidden')));
      await settleLive(tester);
      expect(find.text('Procurement Lead - Facilities'), findsOneWidget);
      expect(find.text('Show again'), findsOneWidget);
      await finishLive(tester);
    });

    testWidgets('Job alerts draws Pooja searches with their filters and what is new', tags: const ['live'], (
      tester,
    ) async {
      if (!await liveScreenReady(tester)) return;
      final repo = await _career(tester, pooja);
      await pumpLive(
        tester,
        JobAlertsScreen(key: UniqueKey(), repository: repo, links: RecordingLinks()),
        size: const Size(390, 1400),
      );
      await settleLive(tester);
      expect(find.text('Facilities in Pune and Ahmedabad'), findsOneWidget);
      expect(find.text('Remote roles'), findsOneWidget);
      expect(find.text('Pune'), findsOneWidget);
      expect(find.text('Remote'), findsWidgets);
      expect(find.textContaining(' new'), findsWidgets);
      await finishLive(tester);
    });

    testWidgets('Invitations draws what recruiters wrote', tags: const ['live'], (tester) async {
      if (!await liveScreenReady(tester)) return;
      final repo = await _career(tester, pooja);
      await pumpLive(tester, InvitationsScreen(key: UniqueKey(), repository: repo, links: RecordingLinks()));
      await settleLive(tester);
      expect(find.text('Facility Operations Head'), findsOneWidget);
      expect(find.textContaining('Invited by Meera Iyer'), findsWidgets);
      expect(find.byKey(const ValueKey('discoverable-switch')), findsOneWidget);
      await finishLive(tester);
    });

    testWidgets('The career hub draws the figures, the next steps and the visibility card', tags: const ['live'], (
      tester,
    ) async {
      if (!await liveScreenReady(tester)) return;
      final repo = await _career(tester, bharat);
      await pumpLive(
        tester,
        CareerHubScreen(key: UniqueKey(), repository: repo, links: RecordingLinks()),
        size: const Size(390, 3000),
      );
      await settleLive(tester);
      expect(find.byKey(const ValueKey('snapshot')), findsOneWidget);
      expect(find.byKey(const ValueKey('next-steps')), findsOneWidget);
      expect(find.byKey(const ValueKey('resume-score')), findsOneWidget);
      expect(find.byKey(const ValueKey('stage-INTERVIEW')), findsOneWidget);
      expect(find.byKey(const ValueKey('go-alerts')), findsOneWidget);
      await finishLive(tester);
    });
  });
}
