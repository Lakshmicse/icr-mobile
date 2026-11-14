import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/career/application_detail_screen.dart';
import 'package:icr_mobile/features/career/application_logic.dart';
import 'package:icr_mobile/features/career/career_hub_screen.dart';
import 'package:icr_mobile/features/career/career_models.dart';
import 'package:icr_mobile/features/career/job_alerts_screen.dart';
import 'package:icr_mobile/features/career/my_applications_screen.dart';
import 'package:icr_mobile/features/jobs/jobs_navigation.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'career_fakes.dart';
import 'helpers/fonts.dart';
import 'jobs_fakes.dart';

/// 'My Applications' and one application's page, every control tapped. What the API does with the
/// taps (withdraw, answer an offer, message the team) is proved in `test/live/career_live_test.dart`.

/// A Monday. The demo's applications are dated from it: the interview is Thursday, the offer
/// is answered by Saturday.
final _now = DateTime(2026, 10, 26, 12);

/// Ten minutes before the demo round (Thu 29 Oct, 11:30, 45 min): its call is open from 11:15.
final _inCallWindow = DateTime(2026, 10, 29, 11, 20);

class Rig {
  Rig(this.repo, this.links, this.conversations, this.finds);

  final SpyCareer repo;
  final RecordingLinks links;
  final List<String> conversations;
  final List<String?> finds;
}

Future<Rig> pumpTracker(
  WidgetTester tester, {
  SpyCareer? repo,
  ApplicationsTab? tab,
  Size size = const Size(390, 1600),
  DateTime? at,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final spy = repo ?? SpyCareer(jobs: SpyJobsRepository(), now: _now);
  final links = RecordingLinks();
  final conversations = <String>[];
  final finds = <String?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: MyApplicationsScreen(
        key: UniqueKey(),
        repository: spy,
        links: links,
        tab: tab,
        clock: () => at ?? _now,
        navigation: JobsNavigation(onOpenConversation: conversations.add, onFindJobs: finds.add),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return Rig(spy, links, conversations, finds);
}

Future<Rig> pumpDetail(
  WidgetTester tester,
  String id, {
  SpyCareer? repo,
  JobsNavigation? navigation,
  Size size = const Size(390, 2400),
  DateTime? at,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final spy = repo ?? SpyCareer(jobs: SpyJobsRepository(), now: _now);
  final links = RecordingLinks();
  final conversations = <String>[];
  final changed = <String>[];
  final seed = await spy.application(id);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: ApplicationDetailScreen(
        key: UniqueKey(),
        repository: spy,
        application: seed,
        links: links,
        clock: () => at ?? _now,
        onChanged: (a) => changed.add('${a.id} ${a.stage}'),
        navigation: navigation ?? JobsNavigation(onOpenConversation: conversations.add),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return Rig(spy, links, conversations, changed);
}

/// The tracker's row for [id].
Finder row(String id) => find.byKey(ValueKey('app-$id'));
Finder inRow(String id, Finder f) => find.descendant(of: row(id), matching: f);

Future<void> openTab(WidgetTester tester, ApplicationsTab tab) async {
  await tester.ensureVisible(find.byKey(ValueKey('applications-tab-${tab.name}')));
  await tester.tap(find.byKey(ValueKey('applications-tab-${tab.name}')));
  await tester.pumpAndSettle();
}

Future<void> openMenu(WidgetTester tester, String id) async {
  await tester.ensureVisible(inRow(id, find.byKey(const ValueKey('row-menu'))));
  await tester.tap(inRow(id, find.byKey(const ValueKey('row-menu'))));
  await tester.pumpAndSettle();
}

CareerApplication lockedApp() => CareerApplication(
  id: 'locked',
  jobId: 'j-locked',
  jobTitle: 'Facilities Planner',
  stage: 'APPLIED',
  createdAt: DateTime(2026, 10, 24),
  companyName: 'Northwind Facilities',
  visibilityLocked: true,
  signalsLocked: true,
  matchScore: 66,
);

void main() {
  setUpAll(loadAppFonts);

  group('the figures and what is up next', () {
    testWidgets('the four figures read the list: active, viewed, interviews, offers', (tester) async {
      await pumpTracker(tester);
      expect(find.text('My Applications'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('summary-active')), matching: find.text('3')),
        findsOneWidget,
      );
      expect(find.text('1 sent this week'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('summary-viewed')), matching: find.text('3')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const ValueKey('summary-interviews')), matching: find.text('1')),
        findsOneWidget,
      );
      expect(find.text('Next: Thu 29 Oct'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('summary-offers')), matching: find.text('1')),
        findsOneWidget,
      );
      expect(find.text('1 awaiting your reply'), findsOneWidget);
    });

    testWidgets('each figure opens its tab', (tester) async {
      await pumpTracker(tester);
      await tester.tap(find.byKey(const ValueKey('summary-interviews')));
      await tester.pumpAndSettle();
      expect(row('app-1'), findsOneWidget);
      expect(row('app-2'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('summary-offers')));
      await tester.pumpAndSettle();
      expect(row('app-3'), findsOneWidget);
      expect(row('app-1'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('summary-active')));
      await tester.pumpAndSettle();
      expect(row('app-1'), findsOneWidget);
      expect(row('app-3'), findsOneWidget);
    });

    testWidgets('a plan without viewed receipts sees a lock and the way to the plans, not a figure', (tester) async {
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now)..applicationsAnswer = [lockedApp()];
      final rig = await pumpTracker(tester, repo: repo);
      expect(find.byKey(const ValueKey('summary-viewed')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('summary-viewed-locked')));
      await tester.pump();
      expect(rig.links.paths, ['/career/plans']);
    });

    testWidgets('Up next lists the round to come and the offer waiting, soonest first', (tester) async {
      await pumpTracker(tester);
      final upNext = find.byKey(const ValueKey('up-next'));
      expect(upNext, findsOneWidget);
      expect(
        find.descendant(of: upNext, matching: find.text('Round 1 interview • Senior Facilities Manager for STP Plant')),
        findsOneWidget,
      );
      expect(find.descendant(of: upNext, matching: find.text('Offer from Global Infra Solutions')), findsOneWidget);
      final interview = tester.getTopLeft(find.byKey(const ValueKey('up-next-iv-1'))).dy;
      final offer = tester.getTopLeft(find.byKey(const ValueKey('up-next-offer-1'))).dy;
      expect(interview, lessThan(offer));
    });

    testWidgets('Up next: Join opens the call, Details the application, Review offer the Offers tab', (tester) async {
      final rig = await pumpTracker(tester, at: _inCallWindow);
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('up-next-iv-1')), matching: find.text('Join')));
      await tester.pump();
      expect(rig.links.opened.single.toString(), 'https://meet.example.com/icr-demo');

      await tester.tap(
        find.descendant(of: find.byKey(const ValueKey('up-next-offer-1')), matching: find.text('Review Offer')),
      );
      await tester.pumpAndSettle();
      expect(row('app-3'), findsOneWidget);
      expect(row('app-1'), findsNothing, reason: 'the Offers tab holds only the offer');

      await openTab(tester, ApplicationsTab.active);
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('up-next-iv-1')), matching: find.text('Details')));
      await tester.pumpAndSettle();
      expect(find.byType(ApplicationDetailScreen), findsOneWidget);
    });
  });

  group('the tabs, search and sort', () {
    testWidgets('Active opens, with every tab and its count', (tester) async {
      await pumpTracker(tester);
      expect(find.text('Active 3'), findsOneWidget);
      expect(find.text('Interviews 1'), findsOneWidget);
      expect(find.text('Offers 1'), findsOneWidget);
      expect(find.text('Archived 1'), findsOneWidget);
      expect(find.text('All 4'), findsOneWidget);
      expect(row('app-4'), findsNothing);
      expect(find.text('Showing 3 of 4 applications'), findsOneWidget);
    });

    testWidgets('Archived and All show what they hold', (tester) async {
      await pumpTracker(tester);
      await openTab(tester, ApplicationsTab.archived);
      expect(row('app-4'), findsOneWidget);
      expect(row('app-1'), findsNothing);
      await openTab(tester, ApplicationsTab.all);
      for (final id in ['app-1', 'app-2', 'app-3', 'app-4']) {
        expect(row(id), findsOneWidget);
      }
      expect(find.text('Showing 4 of 4 applications', skipOffstage: false), findsOneWidget);
    });

    testWidgets('a tab asked for opens first', (tester) async {
      await pumpTracker(tester, tab: ApplicationsTab.offers);
      expect(row('app-3'), findsOneWidget);
      expect(row('app-1'), findsNothing);
    });

    testWidgets('with nothing in play the tracker opens on All', (tester) async {
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now);
      final all = await repo.applications();
      repo.applicationsAnswer = [all.last];
      await pumpTracker(tester, repo: repo);
      expect(row('app-4'), findsOneWidget);
    });

    testWidgets('search narrows by job title, company or city, and clears', (tester) async {
      await pumpTracker(tester);
      await tester.tap(find.byKey(const ValueKey('applications-tab-all')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('applications-search')), 'energy');
      await tester.pumpAndSettle();
      expect(row('app-3'), findsOneWidget);
      expect(row('app-1'), findsNothing);
      expect(find.text('Showing 1 of 4 applications', skipOffstage: false), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('applications-search')), 'pune');
      await tester.pumpAndSettle();
      expect(row('app-2'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('applications-search-clear')));
      await tester.pumpAndSettle();
      expect(row('app-1'), findsOneWidget);
    });

    testWidgets('a search with no match says so and Clear search brings the list back', (tester) async {
      await pumpTracker(tester);
      await tester.enterText(find.byKey(const ValueKey('applications-search')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('applications-search-empty')), findsOneWidget);
      expect(find.text('No Applications Match “zzz”'), findsOneWidget);
      await tester.tap(find.text('Clear Search'));
      await tester.pumpAndSettle();
      expect(row('app-1'), findsOneWidget);
    });

    testWidgets('an empty tab says what goes in it', (tester) async {
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now);
      final all = await repo.applications();
      repo.applicationsAnswer = [all[1]];
      await pumpTracker(tester, repo: repo);
      await openTab(tester, ApplicationsTab.offers);
      expect(find.byKey(const ValueKey('applications-tab-empty')), findsOneWidget);
      expect(find.text('No Offers Yet'), findsOneWidget);
      await tester.tap(find.text('View All Applications'));
      await tester.pumpAndSettle();
      expect(row('app-2'), findsOneWidget);
    });

    testWidgets('Sort orders by recent activity, date applied or best match', (tester) async {
      await pumpTracker(tester);
      List<String> order() => [
        for (final w in tester.widgetList<Widget>(
          find.byWidgetPredicate(
            (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('app-app-'),
          ),
        ))
          (w.key! as ValueKey<String>).value,
      ];
      // Recent activity: the offer sent yesterday, the application viewed two days ago, then the interview.
      expect(order(), ['app-app-3', 'app-app-2', 'app-app-1']);

      await tester.tap(find.byKey(const ValueKey('applications-sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Best Match').last);
      await tester.pumpAndSettle();
      expect(order(), ['app-app-3', 'app-app-1', 'app-app-2']);

      await tester.tap(find.byKey(const ValueKey('applications-sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Date Applied').last);
      await tester.pumpAndSettle();
      expect(order(), ['app-app-2', 'app-app-1', 'app-app-3']);
    });
  });

  group('a row', () {
    testWidgets('reads: status, match, how far it has come, and the round to come', (tester) async {
      await pumpTracker(tester);
      expect(inRow('app-1', find.text('Senior Facilities Manager for STP Plant')), findsOneWidget);
      expect(inRow('app-1', find.text('CBRE South Asia • Mumbai')), findsOneWidget);
      expect(inRow('app-1', find.text('Interviewing')), findsOneWidget);
      expect(inRow('app-1', find.text('88% Match')), findsOneWidget);
      for (final step in ['Applied', 'Viewed', 'In Review', 'Interview', 'Offer']) {
        expect(inRow('app-1', find.text(step)), findsWidgets);
      }
      expect(inRow('app-1', find.byKey(const ValueKey('interview-strip'))), findsOneWidget);
      expect(inRow('app-1', find.textContaining('Round 1', findRichText: true)), findsWidgets);
      // Three days ahead the call is drawn greyed with the time it opens.
      expect(inRow('app-1', find.text('Join Call from 11:15 AM')), findsOneWidget);
    });

    testWidgets('Join call opens the meeting; an in-person round offers the map instead', (tester) async {
      final rig = await pumpTracker(tester, at: _inCallWindow);
      await tester.tap(inRow('app-1', find.text('Join Call')));
      await tester.pump();
      expect(rig.links.opened.single.toString(), 'https://meet.example.com/icr-demo');

      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now);
      final all = await repo.applications();
      final first = all.first;
      repo.applicationsAnswer = [
        CareerApplication(
          id: first.id,
          jobId: first.jobId,
          jobTitle: first.jobTitle,
          stage: 'INTERVIEW',
          createdAt: first.createdAt,
          companyName: first.companyName,
          interviews: [
            CareerInterview(
              id: 'iv-map',
              round: 2,
              scheduledAt: DateTime(2026, 10, 29, 10),
              mode: InterviewMode.inPerson,
              location: 'Tech Park, Pune',
            ),
          ],
        ),
      ];
      final map = await pumpTracker(tester, repo: repo);
      expect(find.text('Join Call'), findsNothing);
      await tester.tap(
        find.descendant(of: find.byKey(const ValueKey('interview-strip')), matching: find.text('Open in Maps')),
      );
      await tester.pump();
      expect(map.links.opened.single.host, 'www.google.com');
    });

    testWidgets('the offer strip shows the terms and the reply-by date', (tester) async {
      await pumpTracker(tester);
      final strip = inRow('app-3', find.byKey(const ValueKey('offer-strip')));
      expect(strip, findsOneWidget);
      expect(
        find.descendant(of: strip, matching: find.textContaining('₹24,00,000 a year', findRichText: true)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: strip, matching: find.textContaining('joining 1 Nov', findRichText: true)),
        findsOneWidget,
      );
      expect(find.descendant(of: strip, matching: find.text('Reply by 31 Oct • 5 days left')), findsOneWidget);
    });

    testWidgets('Accept asks first, sends the note, opens the Offers tab and says so', (tester) async {
      final rig = await pumpTracker(tester);
      await tester.tap(inRow('app-3', find.text('Accept')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('accept-dialog')), findsOneWidget);
      expect(find.text('Accept This Offer?'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('offer-note')), 'Delighted, thank you.');
      await tester.tap(find.byKey(const ValueKey('offer-confirm')));
      await tester.pumpAndSettle();
      expect(rig.repo.log, contains('offer offer-1 accept Delighted, thank you.'));
      expect(find.text('Offer accepted. It is now under Offers.'), findsOneWidget);
      // The application is read again: it is hired now, under Offers.
      expect(rig.repo.log.where((l) => l == 'application app-3'), isNotEmpty);
      expect(row('app-3'), findsOneWidget);
      expect(row('app-1'), findsNothing);
    });

    testWidgets('Decline asks first and archives the application', (tester) async {
      final rig = await pumpTracker(tester);
      await tester.tap(inRow('app-3', find.text('Decline')));
      await tester.pumpAndSettle();
      expect(find.text('Decline This Offer?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('offer-confirm')));
      await tester.pumpAndSettle();
      expect(rig.repo.log, contains('offer offer-1 decline'));
      expect(find.text('Offer declined. It is now under Archived.'), findsOneWidget);
      expect(row('app-3'), findsNothing, reason: 'a declined offer leaves Active');
      await openTab(tester, ApplicationsTab.archived);
      expect(row('app-3'), findsOneWidget);
      expect(inRow('app-3', find.text('Offer Declined')), findsOneWidget);
    });

    testWidgets('backing out of the offer dialog sends nothing', (tester) async {
      final rig = await pumpTracker(tester);
      await tester.tap(inRow('app-3', find.text('Accept')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('offer-cancel')));
      await tester.pumpAndSettle();
      expect(rig.repo.log.where((l) => l.startsWith('offer')), isEmpty);
    });

    testWidgets('the API refusing an answer is shown, and the offer stays', (tester) async {
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now)
        ..offerError = ApiError('This offer has expired.', statusCode: 400);
      await pumpTracker(tester, repo: repo);
      await tester.tap(inRow('app-3', find.text('Accept')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('offer-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('This offer has expired.'), findsOneWidget);
      expect(inRow('app-3', find.byKey(const ValueKey('offer-strip'))), findsOneWidget);
    });

    testWidgets('Withdraw asks first; keeping does nothing, withdrawing archives with the API\'s say', (tester) async {
      final rig = await pumpTracker(tester);
      await openMenu(tester, 'app-2');
      await tester.tap(find.text('Withdraw Application'));
      await tester.pumpAndSettle();
      expect(find.text('Withdraw Your Application?'), findsOneWidget);
      expect(find.textContaining('will no longer see your application for Facilities Operations Lead'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('withdraw-keep')));
      await tester.pumpAndSettle();
      expect(rig.repo.log.where((l) => l.startsWith('withdraw')), isEmpty);

      await openMenu(tester, 'app-2');
      await tester.tap(find.text('Withdraw Application'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('withdraw-confirm')));
      await tester.pumpAndSettle();
      expect(rig.repo.log, contains('withdraw app-2'));
      expect(find.text('Application withdrawn. It is now under Archived.'), findsOneWidget);
      expect(row('app-2'), findsNothing);
      await openTab(tester, ApplicationsTab.archived);
      expect(inRow('app-2', find.text('Withdrawn')), findsOneWidget);
      expect(inRow('app-2', find.byKey(const ValueKey('outcome'))), findsOneWidget);
    });

    testWidgets('a refused withdrawal keeps the application and says why', (tester) async {
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now)
        ..withdrawError = ApiError('A hired application cannot be withdrawn.', statusCode: 400);
      await pumpTracker(tester, repo: repo);
      await openMenu(tester, 'app-2');
      await tester.tap(find.text('Withdraw Application'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('withdraw-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('A hired application cannot be withdrawn.'), findsOneWidget);
      expect(row('app-2'), findsOneWidget);
    });

    testWidgets('an archived application has no Withdraw in its menu', (tester) async {
      await pumpTracker(tester);
      await openTab(tester, ApplicationsTab.archived);
      await openMenu(tester, 'app-4');
      expect(find.text('Withdraw Application'), findsNothing);
      expect(find.text('View Job'), findsOneWidget);
      expect(find.text('Message Hiring Team'), findsOneWidget);
    });

    testWidgets('View job in the menu opens the job sheet', (tester) async {
      await pumpTracker(tester);
      await openMenu(tester, 'app-2');
      await tester.tap(find.text('View Job'));
      await tester.pumpAndSettle();
      expect(find.text('JOB DETAILS'), findsOneWidget);
    });

    testWidgets('Message hiring team opens the conversation the app wired', (tester) async {
      final rig = await pumpTracker(tester);
      await openMenu(tester, 'app-2');
      await tester.tap(find.text('Message Hiring Team'));
      await tester.pumpAndSettle();
      expect(rig.repo.log, contains('message demo-2'));
      expect(rig.conversations, ['conv-1']);
    });

    testWidgets('Message hiring team refused says why and opens nothing', (tester) async {
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now)
        ..messageError = ApiError('This job has no one to message.', statusCode: 400);
      final rig = await pumpTracker(tester, repo: repo);
      await openMenu(tester, 'app-2');
      await tester.tap(find.text('Message Hiring Team'));
      await tester.pumpAndSettle();
      expect(find.text('This job has no one to message.'), findsOneWidget);
      expect(rig.conversations, isEmpty);
    });

    testWidgets('a Not selected row says so and offers similar jobs through the app', (tester) async {
      final rig = await pumpTracker(tester);
      await openTab(tester, ApplicationsTab.archived);
      expect(inRow('app-4', find.textContaining('Not Selected')), findsWidgets);
      expect(inRow('app-4', find.textContaining('The employer selected other candidates')), findsOneWidget);
      expect(inRow('app-4', find.byKey(const ValueKey('step-locked'))), findsNothing);
      await tester.tap(inRow('app-4', find.byKey(const ValueKey('outcome-link'))));
      await tester.pump();
      expect(rig.finds, ['Soft Services Manager']);
    });

    testWidgets('a locked plan sees a dashed lock where the viewed step is, and the notice with a way to the plans', (
      tester,
    ) async {
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now)..applicationsAnswer = [lockedApp()];
      final rig = await pumpTracker(tester, repo: repo);
      expect(inRow('locked', find.byKey(const ValueKey('step-locked'))), findsOneWidget);
      expect(find.byKey(const ValueKey('locked-timeline')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('locked-upgrade')));
      await tester.pump();
      expect(rig.links.paths, ['/career/plans']);
    });

    testWidgets('a job that closed under an early application says the application is still with the employer', (
      tester,
    ) async {
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now);
      final first = (await repo.applications())[1];
      repo.applicationsAnswer = [
        CareerApplication(
          id: first.id,
          jobId: first.jobId,
          jobTitle: first.jobTitle,
          stage: 'APPLIED',
          createdAt: first.createdAt,
          companyName: first.companyName,
          jobStatus: 'CLOSED',
        ),
      ];
      await pumpTracker(tester, repo: repo);
      expect(find.textContaining('no longer accepting applications'), findsOneWidget);
    });

    testWidgets('a row, its title and View application all open the application\'s page', (tester) async {
      await pumpTracker(tester);
      await tester.tap(inRow('app-2', find.byKey(const ValueKey('view-application'))));
      await tester.pumpAndSettle();
      expect(find.byType(ApplicationDetailScreen), findsOneWidget);
      expect(find.text('Your Application'), findsOneWidget);
      await tester.tap(find.byIcon(Symbols.arrow_back).last);
      await tester.pumpAndSettle();
      await tester.tap(inRow('app-2', find.text('Facilities Operations Lead')));
      await tester.pumpAndSettle();
      expect(find.byType(ApplicationDetailScreen), findsOneWidget);
    });
  });

  group('the screen', () {
    testWidgets('no applications at all: where to start, in the app', (tester) async {
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now)..applicationsAnswer = const [];
      final rig = await pumpTracker(tester, repo: repo);
      expect(find.byKey(const ValueKey('applications-first')), findsOneWidget);
      await tester.tap(find.text('Find Jobs'));
      await tester.pump();
      expect(rig.finds, [null]);
      await tester.tap(find.text('Create a Job Alert'));
      await tester.pumpAndSettle();
      expect(find.byType(JobAlertsScreen), findsOneWidget);
      expect(rig.links.opened, isEmpty);
    });

    testWidgets('a tracker that cannot load says why, and Try again reads it again', (tester) async {
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now)
        ..applicationsError = ApiError('The tracker is down.', statusCode: 500);
      await pumpTracker(tester, repo: repo);
      expect(find.byKey(const ValueKey('applications-error')), findsOneWidget);
      expect(find.text('The tracker is down.'), findsOneWidget);
      repo.applicationsError = null;
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      expect(row('app-1'), findsOneWidget);
    });

    testWidgets('pull to refresh reads the list again', (tester) async {
      final rig = await pumpTracker(tester);
      // The indicator arms at a quarter of the 1600 px viewport (400 px of overscroll), so the pull goes past that.
      await tester.fling(find.byType(ListView).first, const Offset(0, 600), 1000);
      await tester.pumpAndSettle();
      expect(rig.repo.log.where((l) => l == 'applications').length, greaterThan(1));
    });

    testWidgets('the bell opens the notifications on the website when the app wired none', (tester) async {
      final rig = await pumpTracker(tester);
      await tester.tap(find.byIcon(LucideIcons.bell));
      await tester.pump();
      expect(rig.links.paths, ['/notifications'], reason: 'this rig wired conversations, not the bell');
    });
  });

  group('one application\'s page', () {
    testWidgets('names the job, the company and the status, and reads the whole application', (tester) async {
      final rig = await pumpDetail(tester, 'app-1');
      expect(find.text('Your Application'), findsOneWidget);
      expect(find.text('Senior Facilities Manager for STP Plant'), findsWidgets);
      expect(find.text('Interviewing'), findsOneWidget);
      expect(rig.repo.log, contains('application app-1'));
      expect(find.text('Viewed 18 Oct'), findsOneWidget);
    });

    testWidgets('the match: the score, its breakdown, and the plan notice when the breakdown is locked', (
      tester,
    ) async {
      await pumpDetail(tester, 'app-1');
      expect(find.byKey(const ValueKey('match-score')), findsOneWidget);
      expect(find.text('88%'), findsOneWidget);
      expect(find.byKey(const ValueKey('match-breakdown')), findsOneWidget);
      expect(find.text('Skills'), findsOneWidget);
      expect(find.text('4 of 5 skills match your résumé.'), findsOneWidget);

      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now)..applicationsAnswer = [lockedApp()];
      final rig = await pumpDetail(tester, 'locked', repo: repo);
      expect(find.byKey(const ValueKey('match-locked')), findsOneWidget);
      await tester.tap(find.text('View Plans'));
      await tester.pump();
      expect(rig.links.paths, ['/career/plans']);
    });

    testWidgets('the answers and what was sent', (tester) async {
      await pumpDetail(tester, 'app-1');
      expect(find.byKey(const ValueKey('my-answers')), findsOneWidget);
      expect(find.text('Years running a campus?'), findsOneWidget);
      expect(find.text('9 years'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(find.byKey(const ValueKey('sent')), findsOneWidget);
      expect(find.text('Senior Facilities Manager résumé'), findsOneWidget);
      expect(find.text('I have run three campuses of this size.'), findsOneWidget);
      expect(find.text('₹22,00,000 a year'), findsOneWidget);
    });

    testWidgets("the stepper is the website's: the stage reached is filled, the ones before it ticked", (tester) async {
      // app-1 is at INTERVIEW: Applied and Screening done, Interview current, Offer and Hired ahead.
      await pumpDetail(tester, 'app-1');
      expect(find.byKey(const ValueKey('stepper-2')), findsOneWidget);
      for (final label in ['Applied', 'Screening', 'Interview', 'Offer', 'Hired']) {
        expect(find.text(label), findsWidgets, reason: label);
      }

      // The employer moved it on: the page reads again (pull, or the app coming back in front) and the step moves.
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now);
      final seed = await repo.application('app-1');
      repo.applicationsAnswer = [seed.copyWith(stage: 'OFFER')];
      await pumpDetail(tester, 'app-1', repo: repo);
      expect(find.byKey(const ValueKey('stepper-3')), findsOneWidget);
      repo.applicationsAnswer = [seed.copyWith(stage: 'HIRED')];
      await pumpDetail(tester, 'app-1', repo: repo);
      expect(find.byKey(const ValueKey('stepper-4')), findsOneWidget);
    });

    testWidgets('not selected and withdrawn show the line, not the steps', (tester) async {
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now);
      final seed = await repo.application('app-1');
      repo.applicationsAnswer = [seed.copyWith(stage: 'REJECTED')];
      await pumpDetail(tester, 'app-1', repo: repo);
      expect(find.byKey(const ValueKey('stepper-rejected')), findsOneWidget);
      expect(find.text('Not Selected'), findsWidgets);
      repo.applicationsAnswer = [seed.copyWith(stage: 'WITHDRAWN')];
      await pumpDetail(tester, 'app-1', repo: repo);
      expect(find.byKey(const ValueKey('stepper-withdrawn')), findsOneWidget);
    });

    testWidgets('the timeline lists what happened in the member\'s words; a locked plan sees the notice', (
      tester,
    ) async {
      await pumpDetail(tester, 'app-1');
      expect(find.byKey(const ValueKey('timeline')), findsOneWidget);
      expect(find.text('You applied'), findsOneWidget);
      expect(find.text('A recruiter viewed your application'), findsOneWidget);
      expect(find.text('Moved to in review'), findsOneWidget);
      expect(find.text('Moved to interview'), findsOneWidget);

      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now)..applicationsAnswer = [lockedApp()];
      await pumpDetail(tester, 'locked', repo: repo);
      expect(find.byKey(const ValueKey('timeline')), findsNothing);
      expect(find.byKey(const ValueKey('locked-timeline')), findsOneWidget);
    });

    testWidgets('an interview round: when, how, Join call; Confirm sends a message to the hiring team', (tester) async {
      final rig = await pumpDetail(tester, 'app-1', at: _inCallWindow);
      expect(find.byKey(const ValueKey('round-iv-1')), findsOneWidget);
      expect(find.text('Technical round'), findsOneWidget);
      expect(find.text('Thu 29 Oct, 11:30 AM • Video Call • 45 min'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('join-iv-1')));
      await tester.pump();
      expect(rig.links.opened.single.toString(), 'https://meet.example.com/icr-demo');

      await tester.tap(find.byKey(const ValueKey('confirm-iv-1')));
      await tester.pumpAndSettle();
      expect(
        rig.repo.messages.single,
        'Hello, I confirm I will attend Technical round for Senior Facilities Manager for STP Plant on Thu 29 Oct, 11:30 AM.',
      );
      expect(rig.conversations, ['conv-1']);
    });

    testWidgets('a round whose call has closed offers no Join', (tester) async {
      // 11:30 for 45 minutes: the room closes at 12:45.
      await pumpDetail(tester, 'app-1', at: DateTime(2026, 10, 29, 12, 46));
      expect(find.byKey(const ValueKey('round-iv-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('join-iv-1')), findsNothing);
    });

    testWidgets('Ask for another time needs a proposal, then sends it with the round named', (tester) async {
      final rig = await pumpDetail(tester, 'app-1');
      await tester.tap(find.byKey(const ValueKey('reschedule-iv-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('another-time-send')));
      await tester.pumpAndSettle();
      expect(find.text('Enter the times you are available.'), findsOneWidget);
      expect(rig.repo.messages, isEmpty);
      await tester.enterText(find.byKey(const ValueKey('another-time-text')), 'Friday after 3 pm.');
      await tester.tap(find.byKey(const ValueKey('another-time-send')));
      await tester.pumpAndSettle();
      expect(rig.repo.messages.single, contains('I cannot make Technical round'));
      expect(rig.repo.messages.single, endsWith('Friday after 3 pm.'));
      expect(rig.conversations, ['conv-1']);
    });

    testWidgets('a message refused says why and opens no thread', (tester) async {
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now)
        ..messageError = ApiError('Messaging is switched off.', statusCode: 403);
      final rig = await pumpDetail(tester, 'app-1', repo: repo);
      await tester.tap(find.byKey(const ValueKey('message-team')));
      await tester.pumpAndSettle();
      expect(find.text('Messaging is switched off.'), findsOneWidget);
      expect(rig.conversations, isEmpty);
    });

    testWidgets('the offer: Accept asks first and tells the list', (tester) async {
      final rig = await pumpDetail(tester, 'app-3');
      expect(find.byKey(const ValueKey('offer-strip')), findsOneWidget);
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('offer-confirm')));
      await tester.pumpAndSettle();
      expect(rig.repo.log, contains('offer offer-1 accept'));
      expect(find.text('Offer accepted.'), findsOneWidget);
      expect(find.byKey(const ValueKey('offer-answered')), findsOneWidget);
      expect(find.text('You accepted this offer: ₹24,00,000 a year.'), findsOneWidget);
      expect(rig.finds.last, startsWith('app-3 '));
    });

    testWidgets('Withdraw asks first, then archives the application and tells the list', (tester) async {
      final rig = await pumpDetail(tester, 'app-2');
      await tester.tap(find.byKey(const ValueKey('withdraw')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('withdraw-confirm')));
      await tester.pumpAndSettle();
      expect(rig.repo.log, contains('withdraw app-2'));
      expect(find.text('Withdrawn'), findsWidgets);
      expect(find.byKey(const ValueKey('withdraw')), findsNothing, reason: 'nothing left to withdraw');
      expect(rig.finds.last, 'app-2 WITHDRAWN');
    });

    testWidgets('an application that is not found says so', (tester) async {
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now);
      final seed = await repo.application('app-2');
      final broken = _Gone(repo);
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ApplicationDetailScreen(repository: broken, application: seed, clock: () => _now),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('application-error')), findsOneWidget);
      expect(find.text('Application not found'), findsOneWidget);
    });

    testWidgets('View job opens the job sheet', (tester) async {
      await pumpDetail(tester, 'app-2');
      await tester.tap(find.byKey(const ValueKey('view-job')));
      await tester.pumpAndSettle();
      expect(find.text('JOB DETAILS'), findsOneWidget);
    });
  });

  group('the career hub', () {
    Future<void> pumpHub(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: CareerHubScreen(
            repository: SpyCareer(jobs: SpyJobsRepository(), now: _now),
            clock: () => _now,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the search at a glance, what is next, how visible, where each application stands', (tester) async {
      await pumpHub(tester);
      expect(find.text('Your Career'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('hub-active')), matching: find.text('3')), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('hub-interviews')), matching: find.text('1')),
        findsOneWidget,
      );
      expect(find.descendant(of: find.byKey(const ValueKey('hub-saved')), matching: find.text('2')), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('hub-invitations')), matching: find.text('1')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('quota')), findsOneWidget);
      expect(find.text('3 of 10 applications used this month'), findsOneWidget);
      expect(find.byKey(const ValueKey('next-steps')), findsOneWidget);
      expect(find.byKey(const ValueKey('resume-score')), findsOneWidget);
      expect(find.text('67%'), findsOneWidget);
      expect(find.byKey(const ValueKey('stage-INTERVIEW')), findsOneWidget);
    });

    testWidgets('each shortcut opens its screen in the app', (tester) async {
      await pumpHub(tester);
      for (final (key, screen) in <(String, String)>[
        ('go-applications', 'My Applications'),
        ('go-interviews', 'Interviews'),
        ('go-saved', 'Saved Jobs'),
        ('go-hidden', 'Saved Jobs'),
        ('go-alerts', 'Job Alerts'),
        ('go-invitations', 'Invitations'),
      ]) {
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expect(find.text(screen), findsOneWidget, reason: key);
        await tester.tap(find.byIcon(Symbols.arrow_back).last);
        await tester.pumpAndSettle();
      }
    });
  });
}

/// A career source whose application cannot be read.
class _Gone extends SpyCareer {
  _Gone(SpyCareer from) : super(jobs: from.jobs, now: DateTime(2026, 10, 26, 12));

  @override
  Future<CareerApplication> application(String id) async => throw ApiError('Application not found', statusCode: 404);
}
