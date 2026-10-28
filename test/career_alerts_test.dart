import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/career/career_models.dart';
import 'package:icr_mobile/features/career/job_alert_models.dart';
import 'package:icr_mobile/features/career/job_alerts_screen.dart';
import 'package:icr_mobile/features/jobs/widgets/job_row.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'career_fakes.dart';
import 'helpers/fonts.dart';
import 'jobs_fakes.dart';

/// "Job alerts": the list, the switch, how often, the matches, make, edit and delete. What the API
/// does with the taps is proved in `test/live/career_alerts_live_test.dart`.

final _now = DateTime(2026, 10, 26, 12);

class Rig {
  Rig(this.repo, this.jobs, this.links, this.changed);

  final SpyCareer repo;
  final SpyJobsRepository jobs;
  final RecordingLinks links;
  final List<String> changed;
}

Future<Rig> pumpAlerts(
  WidgetTester tester, {
  SpyCareer? repo,
  bool startWithForm = false,
  AlertCriteria? criteria,
  Size size = const Size(390, 1800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final jobs = SpyJobsRepository();
  final spy = repo ?? SpyCareer(jobs: jobs, now: _now);
  final links = RecordingLinks();
  final changed = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: JobAlertsScreen(
        key: UniqueKey(),
        repository: spy,
        links: links,
        startWithForm: startWithForm,
        initialCriteria: criteria,
        onChanged: () => changed.add('changed'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return Rig(spy, jobs, links, changed);
}

Finder card(String id) => find.byKey(ValueKey('alert-$id'));

Future<void> openMenu(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ValueKey('alert-menu-$id')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('the list', () {
    testWidgets('names each search with its filters, how often it speaks and what is new', (tester) async {
      await pumpAlerts(tester);
      expect(find.text('Job alerts'), findsOneWidget);
      expect(find.text('Facilities & Real Estate'), findsOneWidget);
      expect(find.text('2 new'), findsOneWidget);
      expect(find.descendant(of: card('alert-1'), matching: find.text('Bengaluru')), findsOneWidget);
      expect(find.descendant(of: card('alert-1'), matching: find.text('India')), findsOneWidget);
      expect(find.descendant(of: card('alert-2'), matching: find.text('“MEP”')), findsOneWidget);
      expect(find.descendant(of: card('alert-2'), matching: find.text('Remote')), findsOneWidget);
      expect(find.byKey(const ValueKey('alert-state-alert-1')), findsOneWidget);
      expect(find.text('Telling you daily'), findsOneWidget);
      expect(find.text('Telling you weekly'), findsOneWidget);
      expect(find.text('2 new jobs match your searches.'), findsOneWidget);
    });

    testWidgets('no alerts: it says so and offers to make one', (tester) async {
      final repo = SpyCareer(now: _now);
      for (final a in await repo.alerts()) {
        await repo.deleteAlert(a.id);
      }
      await pumpAlerts(tester, repo: repo);
      expect(find.byKey(const ValueKey('alerts-empty')), findsOneWidget);
      await tester.tap(find.text('Create an alert'));
      await tester.pumpAndSettle();
      expect(find.text('New job alert'), findsOneWidget);
    });

    testWidgets('a list that cannot load says why, and Try again reads it again', (tester) async {
      final broken = _AlertsDown(SpyJobsRepository());
      await pumpAlerts(tester, repo: broken);
      expect(find.byKey(const ValueKey('alerts-error')), findsOneWidget);
      expect(find.text('The alerts are down.'), findsOneWidget);
      broken.down = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Facilities & Real Estate'), findsOneWidget);
    });

    testWidgets('pull to refresh reads the searches again', (tester) async {
      final repo = SpyCareer(now: _now);
      await pumpAlerts(tester, repo: repo);
      await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Facilities & Real Estate'), findsOneWidget);
    });
  });

  group('the switch and how often', () {
    testWidgets('the switch turns alerts off at once and tells the API; the frequency chips wait', (tester) async {
      final rig = await pumpAlerts(tester);
      await tester.tap(find.byKey(const ValueKey('alert-switch-alert-1')));
      await tester.pumpAndSettle();
      expect(rig.repo.log.last, 'updateAlert alert-1 name=null criteria=null enabled=false frequency=null');
      expect(find.text('Alerts are off'), findsOneWidget);
      // With alerts off, "Weekly" cannot be chosen.
      await tester.tap(find.byKey(const ValueKey('alert-weekly-alert-1')));
      await tester.pumpAndSettle();
      expect(rig.repo.log.where((l) => l.contains('frequency=WEEKLY')), isEmpty);
      // And back on.
      await tester.tap(find.byKey(const ValueKey('alert-switch-alert-1')));
      await tester.pumpAndSettle();
      expect(find.text('Telling you daily'), findsOneWidget);
    });

    testWidgets('Weekly changes how often an alert speaks', (tester) async {
      final rig = await pumpAlerts(tester);
      await tester.tap(find.byKey(const ValueKey('alert-weekly-alert-1')));
      await tester.pumpAndSettle();
      expect(rig.repo.log.last, 'updateAlert alert-1 name=null criteria=null enabled=null frequency=WEEKLY');
      expect(find.byKey(const ValueKey('alert-state-alert-1')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('alert-state-alert-1'))).data, 'Telling you weekly');
    });

    testWidgets('a refused switch is put back, with the API\'s sentence', (tester) async {
      final repo = SpyCareer(now: _now)..alertError = ApiError('Alerts are paused for your account.', statusCode: 403);
      await pumpAlerts(tester, repo: repo);
      await tester.tap(find.byKey(const ValueKey('alert-switch-alert-1')));
      await tester.pumpAndSettle();
      expect(find.text('Alerts are paused for your account.'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('alert-state-alert-1'))).data, 'Telling you daily');
    });
  });

  group('the matches', () {
    testWidgets('See the new ones runs the search, clears the badge, tells the board and lists the jobs', (
      tester,
    ) async {
      final rig = await pumpAlerts(tester);
      expect(find.text('See 2 new'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('alert-matches-alert-1')));
      await tester.pumpAndSettle();
      expect(rig.repo.log, contains('runAlert alert-1 1'));
      expect(find.text('2 new'), findsNothing, reason: 'the badge counts as seen');
      expect(find.text('Hide matches'), findsOneWidget);
      expect(find.descendant(of: card('alert-1'), matching: find.byType(JobRow)), findsNWidgets(3));
      expect(rig.changed, isNotEmpty);
      expect(find.text('Searches you saved. We tell you when new jobs match.'), findsOneWidget);
    });

    testWidgets('Hide matches folds the list away; opening another search closes the first', (tester) async {
      await pumpAlerts(tester);
      await tester.tap(find.byKey(const ValueKey('alert-matches-alert-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('alert-matches-alert-1')));
      await tester.pumpAndSettle();
      expect(find.byType(JobRow), findsNothing);
      await tester.tap(find.byKey(const ValueKey('alert-matches-alert-1')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('alert-matches-alert-2')));
      await tester.tap(find.byKey(const ValueKey('alert-matches-alert-2')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: card('alert-1'), matching: find.byType(JobRow)), findsNothing);
      expect(find.descendant(of: card('alert-2'), matching: find.byType(JobRow)), findsNWidgets(3));
    });

    testWidgets('View More adds the next page without repeating a job', (tester) async {
      final repo = SpyCareer(now: _now)..matchesMore = true;
      await pumpAlerts(tester, repo: repo);
      await tester.tap(find.byKey(const ValueKey('alert-matches-alert-1')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('view-more')));
      await tester.tap(find.byKey(const ValueKey('view-more')));
      await tester.pumpAndSettle();
      expect(repo.log.where((l) => l.startsWith('runAlert')), ['runAlert alert-1 1', 'runAlert alert-1 2']);
      expect(find.descendant(of: card('alert-1'), matching: find.byType(JobRow)), findsNWidgets(3));
      expect(find.byKey(const ValueKey('view-more')), findsNothing);
    });

    testWidgets('a match\'s bookmark saves it, and a refusal puts it back', (tester) async {
      final rig = await pumpAlerts(tester);
      await tester.tap(find.byKey(const ValueKey('alert-matches-alert-1')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byIcon(LucideIcons.bookmark).first);
      await tester.tap(find.byIcon(LucideIcons.bookmark).first);
      await tester.pumpAndSettle();
      expect(rig.jobs.saves, [(jobId: 'demo-1', saved: true)]);
      expect(find.byIcon(LucideIcons.bookmarkCheck), findsOneWidget);

      rig.jobs.setSavedError = ApiError('Your plan allows 50 saved jobs.', statusCode: 403);
      await tester.tap(find.byIcon(LucideIcons.bookmark).first);
      await tester.pumpAndSettle();
      expect(find.text('Your plan allows 50 saved jobs.'), findsOneWidget);
      expect(find.byIcon(LucideIcons.bookmarkCheck), findsOneWidget);
    });

    testWidgets('a match opens the job sheet', (tester) async {
      await pumpAlerts(tester);
      await tester.tap(find.byKey(const ValueKey('alert-matches-alert-1')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(JobRow).first);
      await tester.tap(find.byType(JobRow).first);
      await tester.pumpAndSettle();
      expect(find.text('JOB DETAILS'), findsOneWidget);
    });

    testWidgets('a search that cannot be run says why', (tester) async {
      final repo = SpyCareer(now: _now);
      await pumpAlerts(tester, repo: repo);
      repo.alertError = ApiError('Search is down.', statusCode: 500);
      await tester.tap(find.byKey(const ValueKey('alert-matches-alert-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('matches-error')), findsOneWidget);
      expect(find.text('Search is down.'), findsOneWidget);
    });
  });

  group('making a search', () {
    Future<void> fill(WidgetTester tester) async {
      await tester.enterText(find.byKey(const ValueKey('alert-name')), 'MEP in Pune');
      await tester.enterText(find.byKey(const ValueKey('alert-keywords')), 'MEP');
      await tester.enterText(find.byKey(const ValueKey('alert-cities')), 'Pune, Mumbai');
      await tester.tap(find.byKey(const ValueKey('alert-mode-hybrid')));
      await tester.tap(find.byKey(const ValueKey('alert-type-fullTime')));
      await tester.enterText(find.byKey(const ValueKey('alert-salary')), '1200000');
      await tester.pump();
    }

    testWidgets('the + opens a form that needs a name, and says so', (tester) async {
      final rig = await pumpAlerts(tester);
      await tester.tap(find.byKey(const ValueKey('new-alert')));
      await tester.pumpAndSettle();
      expect(find.text('New job alert'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('alert-save')));
      await tester.pumpAndSettle();
      expect(find.text('Give the search a name.'), findsOneWidget);
      expect(rig.repo.log.where((l) => l.startsWith('createAlert')), isEmpty);
    });

    testWidgets('a good form saves with the filters the board uses, and the new search leads the list', (tester) async {
      final rig = await pumpAlerts(tester);
      await tester.tap(find.byKey(const ValueKey('new-alert')));
      await tester.pumpAndSettle();
      await fill(tester);
      await tester.tap(find.byKey(const ValueKey('alert-form-weekly')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('alert-save')));
      await tester.pumpAndSettle();
      expect(
        rig.repo.log.last,
        'createAlert MEP in Pune {search: MEP, city: Pune,Mumbai, workMode: HYBRID, employmentType: FULL_TIME, salaryMin: 1200000} true WEEKLY',
      );
      expect(find.text('Alert saved. We will tell you when new jobs match.'), findsOneWidget);
      expect(find.text('MEP in Pune'), findsOneWidget);
      expect(rig.changed, isNotEmpty);
    });

    testWidgets('the API\'s refusal (the plan\'s limit) is shown and nothing typed is lost', (tester) async {
      final repo = SpyCareer(now: _now)
        ..alertError = ApiError('Your plan includes 3 saved job alerts.', statusCode: 403);
      await pumpAlerts(tester, repo: repo);
      await tester.tap(find.byKey(const ValueKey('new-alert')));
      await tester.pumpAndSettle();
      await fill(tester);
      await tester.tap(find.byKey(const ValueKey('alert-save')));
      await tester.pumpAndSettle();
      expect(find.text('Your plan includes 3 saved job alerts.'), findsOneWidget);
      expect(find.text('MEP in Pune'), findsOneWidget, reason: 'the name is still in the box');
      repo.alertError = null;
      await tester.tap(find.byKey(const ValueKey('alert-save')));
      await tester.pumpAndSettle();
      expect(repo.log.where((l) => l.startsWith('createAlert')), hasLength(2));
      expect(find.text('Alert saved. We will tell you when new jobs match.'), findsOneWidget);
    });

    testWidgets('the form can start from a search the board was showing, with a name suggested', (tester) async {
      final rig = await pumpAlerts(
        tester,
        startWithForm: true,
        criteria: const AlertCriteria(search: 'chiller', cities: ['Pune'], workModes: {WorkMode.onsite}),
      );
      expect(find.text('New job alert'), findsOneWidget);
      expect(find.text('chiller • Pune • On-site'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('alert-save')));
      await tester.pumpAndSettle();
      expect(
        rig.repo.log.last,
        startsWith('createAlert chiller • Pune • On-site {search: chiller, city: Pune, workMode: ONSITE}'),
      );
    });
  });

  group('editing and deleting', () {
    testWidgets('Edit opens the saved filters; saving sends the changes and keeps the filters the form does not edit', (
      tester,
    ) async {
      final rig = await pumpAlerts(tester);
      await openMenu(tester, 'alert-1');
      await tester.tap(find.text('Edit search'));
      await tester.pumpAndSettle();
      expect(find.text('Edit search'), findsOneWidget);
      expect(find.text('Facilities & Real Estate'), findsWidgets);
      expect(find.text('Bengaluru'), findsWidgets);
      await tester.enterText(find.byKey(const ValueKey('alert-name')), 'Bengaluru facilities');
      await tester.tap(find.byKey(const ValueKey('alert-save')));
      await tester.pumpAndSettle();
      expect(
        rig.repo.log.last,
        'updateAlert alert-1 name=Bengaluru facilities criteria={country: India, city: Bengaluru} enabled=true frequency=DAILY',
      );
      expect(find.text('Alert updated.'), findsOneWidget);
      expect(find.text('Bengaluru facilities'), findsOneWidget);
    });

    testWidgets('Delete asks first; Keep does nothing, Delete removes the search', (tester) async {
      final rig = await pumpAlerts(tester);
      await openMenu(tester, 'alert-2');
      await tester.tap(find.text('Delete alert'));
      await tester.pumpAndSettle();
      expect(find.text('Delete “Remote MEP roles”?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('delete-alert-keep')));
      await tester.pumpAndSettle();
      expect(rig.repo.log.where((l) => l.startsWith('deleteAlert')), isEmpty);

      await openMenu(tester, 'alert-2');
      await tester.tap(find.text('Delete alert'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-alert-confirm')));
      await tester.pumpAndSettle();
      expect(rig.repo.log, contains('deleteAlert alert-2'));
      expect(find.text('Remote MEP roles'), findsNothing);
      expect(find.text('Alert deleted.'), findsOneWidget);
      expect(rig.changed, isNotEmpty);
    });

    testWidgets('a refused delete keeps the search and says why', (tester) async {
      final repo = SpyCareer(now: _now)..alertError = ApiError('Saved search not found', statusCode: 404);
      await pumpAlerts(tester, repo: repo);
      await openMenu(tester, 'alert-2');
      await tester.tap(find.text('Delete alert'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-alert-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Saved search not found'), findsOneWidget);
      expect(find.text('Remote MEP roles'), findsOneWidget);
    });
  });

  group('criteria', () {
    test('a saved query reads into the form and writes back whole', () {
      final c = AlertCriteria.fromMap({
        'search': 'MEP',
        'city': 'Pune,Mumbai',
        'workMode': 'REMOTE,HYBRID',
        'employmentType': 'FULL_TIME',
        'salaryMin': '900000',
        'country': 'India',
        'shift': 'NIGHT',
      });
      expect(c.cities, ['Pune', 'Mumbai']);
      expect(c.workModes, {WorkMode.remote, WorkMode.hybrid});
      expect(c.employmentTypes, {EmploymentType.fullTime});
      expect(c.salaryMin, 900000);
      expect(c.other, {'country': 'India', 'shift': 'NIGHT'});
      expect(c.toMap(), {
        'country': 'India',
        'shift': 'NIGHT',
        'search': 'MEP',
        'city': 'Pune,Mumbai',
        'workMode': 'REMOTE,HYBRID',
        'employmentType': 'FULL_TIME',
        'salaryMin': '900000',
      });
    });

    test('a draft needs a name of 1 to 80 characters', () {
      const c = AlertCriteria();
      expect(const AlertDraft(name: ' ', criteria: c).problem, 'Give the search a name.');
      expect(AlertDraft(name: 'x' * 81, criteria: c).problem, 'Keep the name to 80 characters.');
      expect(AlertDraft(name: 'x' * 80, criteria: c).problem, isNull);
    });

    test('the chips word the filters, the website\'s way', () {
      expect(criteriaWords({'search': 'MEP', 'city': 'Pune', 'workMode': 'REMOTE', 'seniority': 'SENIOR,LEAD'}), [
        '“MEP”',
        'Pune',
        'Remote',
        'Senior',
        'Lead',
      ]);
      expect(criteriaWords(const {}), isEmpty);
    });
  });
}

/// A career source whose alerts cannot be read, until [down] is cleared.
class _AlertsDown extends SpyCareer {
  _AlertsDown(SpyJobsRepository jobs) : super(jobs: jobs, now: DateTime(2026, 10, 26, 12));

  bool down = true;

  @override
  Future<List<JobAlert>> alerts() async {
    if (down) throw ApiError('The alerts are down.', statusCode: 500);
    return super.alerts();
  }
}
