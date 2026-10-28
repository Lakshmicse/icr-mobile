import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/jobs/employer/hiring_models.dart';
import 'package:icr_mobile/features/jobs/employer/post_job_screen.dart';
import 'package:icr_mobile/features/jobs/employer/screening_editor.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'hiring_fakes.dart';
import 'helpers/fonts.dart';
import 'jobs_fakes.dart';

/// Every control of "Post a job" and "Edit job", tapped: what it does on the phone and what it sends.
/// What the API does with a posting is proved in `test/live/jobs_employer_live_test.dart`.

final _description =
    'Lead day-to-day facilities operations across four logistics parks: rosters, statutory audits and the vendors who run them.';

Key _k(String key) => ValueKey(key);

Future<(SpyHiring, RecordingLinks, RecordingNavigation)> openComposer(
  WidgetTester tester, {
  SpyHiring? repo,
  String? jobId,
  JobDraft? initial,
  Size size = const Size(390, 6000),
}) async {
  final hiring = repo ?? SpyHiring();
  final nav = RecordingNavigation();
  final links = await openOnPhone(
    tester,
    (context, links) => PostJobScreen(
      repository: hiring,
      jobId: jobId,
      initial: initial,
      links: links,
      navigation: nav.navigation,
      clock: hiringClock,
    ),
    size: size,
  );
  return (hiring, links, nav);
}

Future<void> type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(_k(key)), text);
  await tester.pump();
}

Future<void> tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(_k(key)));
  await tester.pump();
}

/// A posting that passes every rule.
Future<void> fillReady(WidgetTester tester, {String title = 'Facility Supervisor'}) async {
  await type(tester, 'job-title', title);
  await type(tester, 'job-description', _description);
  await type(tester, 'skill-input', 'HVAC');
  await tap(tester, 'add-skill');
}

void main() {
  setUpAll(loadAppFonts);

  group('opening the composer', () {
    testWidgets('a new posting starts empty and lists what it needs to go live', (tester) async {
      await openComposer(tester);
      expect(find.text('Post a job'), findsOneWidget);
      expect(find.text('Before you publish'), findsOneWidget);
      expect(find.byKey(_k('blocker-title')), findsOneWidget);
      expect(find.byKey(_k('blocker-description')), findsOneWidget);
      expect(find.byKey(_k('blocker-skills')), findsOneWidget);
      expect(find.byKey(_k('blocker-country')), findsNothing, reason: 'India is the starting country');
      expect(find.byKey(_k('gate-note')), findsNothing);
      expect(find.text('Draft saved.'), findsNothing);
    });

    testWidgets('an existing posting loads into the form, with its status said', (tester) async {
      await openComposer(tester, jobId: 'job-open');
      expect(find.text('Edit job'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(_k('job-title'))).controller!.text, 'Facilities Operations Lead');
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('This posting is live: changes show at once.'), findsOneWidget);
      expect(find.text('Update posting'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
    });

    testWidgets('a posting that cannot be opened says why and tries again', (tester) async {
      final repo = SpyHiring()..failures['job'] = ApiError('We could not reach ICR.');
      await openComposer(tester, repo: repo, jobId: 'job-open');
      expect(find.byKey(_k('composer-error')), findsOneWidget);
      expect(find.text('We could not reach ICR.'), findsOneWidget);
      repo.failures.remove('job');
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byKey(_k('composer-error')), findsNothing);
      expect(tester.widget<TextField>(find.byKey(_k('job-title'))).controller!.text, 'Facilities Operations Lead');
    });

    testWidgets('a paused posting offers to publish it again, a draft sent back shows nothing odd', (tester) async {
      await openComposer(tester, jobId: 'job-paused');
      expect(find.text('Publish again'), findsOneWidget);
      expect(find.text('Paused. Publish to open it again.'), findsOneWidget);
    });
  });

  group('the role', () {
    testWidgets('typing a title offers the staff-managed titles, and a tap fills it', (tester) async {
      await openComposer(tester);
      await type(tester, 'job-title', 'faci');
      expect(find.byKey(_k('title-suggestions')), findsOneWidget);
      expect(find.byKey(_k('title-hint-Facility Supervisor')), findsOneWidget);
      expect(find.byKey(_k('title-hint-Facilities Manager')), findsOneWidget);
      await tap(tester, 'title-hint-Facility Supervisor');
      expect(tester.widget<TextField>(find.byKey(_k('job-title'))).controller!.text, 'Facility Supervisor');
      expect(find.byKey(_k('title-suggestions')), findsNothing);
      expect(find.byKey(_k('blocker-title')), findsNothing);
    });

    testWidgets('a listed title tags the posting with its function; any other title clears it', (tester) async {
      final (repo, _, _) = await openComposer(tester);
      await type(tester, 'job-title', 'energy');
      await tap(tester, 'title-hint-Energy Manager');
      await tap(tester, 'save-draft');
      expect(repo.created.single.draft.jobFunctions, ['ENERGY_SUSTAIN']);
      expect(repo.created.single.draft.toJson()['jobFunctions'], ['ENERGY_SUSTAIN']);

      await type(tester, 'job-title', 'Energy Manager (nights)');
      await tap(tester, 'save-draft');
      expect(repo.updated.last.draft.jobFunctions, isEmpty, reason: 'no longer the listed title');

      await type(tester, 'job-title', '  energy   MANAGER ');
      await tap(tester, 'save-draft');
      expect(repo.updated.last.draft.jobFunctions, [
        'ENERGY_SUSTAIN',
      ], reason: 'spelled the same, whatever the case or spacing');
    });

    testWidgets('a title that is not on the list is as good: suggested, never enforced', (tester) async {
      await openComposer(tester);
      await type(tester, 'job-title', 'Plant Whisperer');
      expect(find.byKey(_k('title-suggestions')), findsNothing);
      expect(find.byKey(_k('blocker-title')), findsNothing);
    });

    testWidgets('a title shorter than three characters still blocks publishing', (tester) async {
      await openComposer(tester);
      await type(tester, 'job-title', 'HR');
      expect(find.byKey(_k('blocker-title')), findsOneWidget);
      expect(find.text('Give the role a clear, specific title (at least 3 characters).'), findsOneWidget);
    });

    testWidgets('seniority, type and work mode are chosen with a tap; seniority can be cleared', (tester) async {
      final (repo, _, _) = await openComposer(tester);
      await tap(tester, 'seniority-SENIOR');
      await tap(tester, 'type-CONTRACT');
      await tap(tester, 'mode-HYBRID');
      await type(tester, 'job-department', 'Operations');
      await type(tester, 'job-title', 'Supervisor');
      await tap(tester, 'save-draft');
      await tester.pump();
      var draft = repo.created.single.draft;
      expect(draft.seniority, 'SENIOR');
      expect(draft.employmentType, 'CONTRACT');
      expect(draft.workMode, 'HYBRID');
      expect(draft.department, 'Operations');
      await tap(tester, 'seniority-SENIOR');
      await tap(tester, 'save-draft');
      await tester.pump();
      draft = repo.updated.last.draft;
      expect(draft.seniority, isNull, reason: 'a second tap takes the seniority off');
    });
  });

  group('where', () {
    testWidgets('the country is picked from the list and sent', (tester) async {
      final (repo, _, _) = await openComposer(tester);
      await tester.tap(find.byKey(_k('job-country')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Qatar').last);
      await tester.pumpAndSettle();
      await type(tester, 'job-state', 'Doha Municipality');
      await type(tester, 'job-title', 'Supervisor');
      await tap(tester, 'save-draft');
      final draft = repo.created.single.draft;
      expect(draft.country, 'Qatar');
      expect(draft.state, 'Doha Municipality');
    });

    testWidgets('cities are added and removed, each once', (tester) async {
      await openComposer(tester);
      await type(tester, 'job-city', 'Pune');
      await tap(tester, 'add-city');
      expect(find.byKey(_k('city-Pune')), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(_k('job-city'))).controller!.text, isEmpty);

      await type(tester, 'job-city', 'pune');
      await tap(tester, 'add-city');
      expect(find.text('Each city can be listed once.'), findsOneWidget);
      expect(find.byKey(_k('city-pune')), findsNothing);

      await tester.tap(find.descendant(of: find.byKey(_k('city-Pune')), matching: find.byTooltip('Delete')));
      await tester.pump();
      expect(find.byKey(_k('city-Pune')), findsNothing);
    });

    testWidgets('a city name has a length limit and a blank adds nothing', (tester) async {
      await openComposer(tester);
      await tap(tester, 'add-city');
      expect(find.byType(InputChip), findsNothing);
      await type(tester, 'job-city', 'C' * 61);
      await tap(tester, 'add-city');
      expect(find.text('Keep each city to 60 characters or fewer.'), findsOneWidget);
    });

    testWidgets('no more than ten cities', (tester) async {
      await openComposer(tester);
      for (var i = 0; i < 10; i++) {
        await type(tester, 'job-city', 'City$i');
        await tap(tester, 'add-city');
      }
      await type(tester, 'job-city', 'One too many');
      await tap(tester, 'add-city');
      expect(find.text('List at most 10 cities.'), findsOneWidget);
      expect(find.byKey(_k('city-One too many')), findsNothing);
    });

    testWidgets('two cities each ask for their seats, and the total follows', (tester) async {
      final (repo, _, _) = await openComposer(tester);
      await fillReady(tester);
      await type(tester, 'job-city', 'Pune');
      await tap(tester, 'add-city');
      expect(find.byKey(_k('openings')), findsOneWidget, reason: 'one city: one count');
      await type(tester, 'job-city', 'Mumbai');
      await tap(tester, 'add-city');
      expect(find.byKey(_k('openings')), findsNothing);
      expect(find.byKey(_k('openings-Pune')), findsOneWidget);
      expect(find.byKey(_k('blocker-cityOpenings')), findsOneWidget);
      expect(find.text('Enter the number of openings for each city (Pune is missing).'), findsOneWidget);

      await type(tester, 'openings-Pune', '2');
      expect(find.text('Enter the number of openings for each city (Mumbai is missing).'), findsOneWidget);
      await type(tester, 'openings-Mumbai', '3');
      expect(find.byKey(_k('blocker-cityOpenings')), findsNothing);
      expect(find.text('5 openings in all'), findsOneWidget);

      await tap(tester, 'save-draft');
      final json = repo.created.single.draft.toJson();
      expect(json['openings'], 5);
      expect(json['cityOpenings'], [
        {'city': 'Pune', 'openings': 2},
        {'city': 'Mumbai', 'openings': 3},
      ]);
    });
  });

  group('the description', () {
    testWidgets('counts the characters a reader sees against the 120 needed', (tester) async {
      await openComposer(tester);
      expect(find.text('0 of 120 characters needed to publish'), findsOneWidget);
      await type(tester, 'job-description', 'Run the sites.');
      expect(find.text('14 of 120 characters needed to publish'), findsOneWidget);
      expect(find.byKey(_k('blocker-description')), findsOneWidget);
      await type(tester, 'job-description', _description);
      expect(find.byKey(_k('blocker-description')), findsNothing);
    });

    testWidgets('bullets and headings are stored as rich text', (tester) async {
      final (repo, _, _) = await openComposer(tester);
      await type(tester, 'job-title', 'Supervisor');
      await type(tester, 'job-description', 'Run the sites.\n\n## You will\n- Own shifts\n- Hold vendors to SLAs');
      await tap(tester, 'save-draft');
      expect(
        repo.created.single.draft.toJson()['description'],
        '<p>Run the sites.</p><h3>You will</h3><ul><li>Own shifts</li><li>Hold vendors to SLAs</li></ul>',
      );
    });
  });

  group('skills and experience', () {
    testWidgets('a skill is added with the plus or the keyboard, once, and removed with its cross', (tester) async {
      await openComposer(tester);
      await type(tester, 'skill-input', 'HVAC');
      await tap(tester, 'add-skill');
      expect(find.byKey(_k('skill-HVAC')), findsOneWidget);
      expect(find.byKey(_k('blocker-skills')), findsNothing);

      await type(tester, 'skill-input', 'hvac');
      await tap(tester, 'add-skill');
      expect(find.byKey(_k('skill-hvac')), findsNothing, reason: 'the same skill, whatever its case');

      await type(tester, 'skill-input', 'Fire Safety');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.byKey(_k('skill-Fire Safety')), findsOneWidget);

      await tester.tap(find.descendant(of: find.byKey(_k('skill-HVAC')), matching: find.byTooltip('Delete')));
      await tester.pump();
      expect(find.byKey(_k('skill-HVAC')), findsNothing);
    });

    testWidgets('typing offers matching skills, and a tap adds one', (tester) async {
      await openComposer(tester);
      await type(tester, 'skill-input', 'bud');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.byKey(_k('skill-hints')), findsOneWidget);
      expect(find.byKey(_k('skill-hint-Budgeting')), findsOneWidget);
      expect(find.byKey(_k('skill-hint-Budget Control')), findsOneWidget);
      await tap(tester, 'skill-hint-Budgeting');
      expect(find.byKey(_k('skill-Budgeting')), findsOneWidget);
      expect(find.byKey(_k('skill-hints')), findsNothing);
    });

    testWidgets('a skill over 60 characters is refused with the limit', (tester) async {
      await openComposer(tester);
      await type(tester, 'skill-input', 'S' * 61);
      await tap(tester, 'add-skill');
      expect(find.text('Keep each skill to 60 characters or fewer.'), findsOneWidget);
      expect(find.byType(InputChip), findsNothing);
    });

    testWidgets('no more than thirty skills', (tester) async {
      await openComposer(tester);
      for (var i = 0; i < 30; i++) {
        await type(tester, 'skill-input', 'Skill $i');
        await tap(tester, 'add-skill');
      }
      await type(tester, 'skill-input', 'One more');
      await tap(tester, 'add-skill');
      expect(find.text('List at most 30 skills.'), findsOneWidget);
    });

    testWidgets('nice-to-have skills are kept apart from the required ones', (tester) async {
      final (repo, _, _) = await openComposer(tester);
      await type(tester, 'job-title', 'Supervisor');
      await type(tester, 'preferred-input', 'NEBOSH');
      await tap(tester, 'add-preferred');
      expect(find.byKey(_k('preferred-NEBOSH')), findsOneWidget);
      expect(find.byKey(_k('blocker-skills')), findsOneWidget, reason: 'a nice-to-have is not a required skill');
      await tap(tester, 'save-draft');
      final draft = repo.created.single.draft;
      expect(draft.preferredSkills, ['NEBOSH']);
      expect(draft.skills, isEmpty);
    });

    testWidgets('experience is whole years, from and to, and the order is checked', (tester) async {
      final (repo, _, _) = await openComposer(tester);
      await type(tester, 'job-title', 'Supervisor');
      await type(tester, 'exp-min', '8');
      await type(tester, 'exp-max', '3');
      expect(find.byKey(_k('blocker-experienceOrder')), findsOneWidget);
      expect(find.text('Minimum experience cannot exceed the maximum.'), findsOneWidget);
      await tap(tester, 'save-draft');
      expect(repo.created, isEmpty, reason: 'the API refuses it on every save, so nothing is sent');
      await type(tester, 'exp-max', '12');
      expect(find.byKey(_k('blocker-experienceOrder')), findsNothing);
      await tap(tester, 'save-draft');
      final draft = repo.created.single.draft;
      expect(draft.experienceMin, 8);
      expect(draft.experienceMax, 12);
    });

    testWidgets('a box that holds a year count takes digits only', (tester) async {
      await openComposer(tester);
      await type(tester, 'exp-min', '1a2b');
      expect(tester.widget<TextField>(find.byKey(_k('exp-min'))).controller!.text, '12');
    });
  });

  group('pay', () {
    testWidgets('salary is optional, and a maximum below the minimum is called out', (tester) async {
      final (repo, _, _) = await openComposer(tester);
      await fillReady(tester);
      expect(find.text('Ready to publish'), findsOneWidget, reason: 'no salary needed');
      await type(tester, 'sal-min', '900000');
      await type(tester, 'sal-max', '500000');
      expect(find.byKey(_k('blocker-salaryOrder')), findsOneWidget);
      expect(find.text('Maximum salary must be at least the minimum.'), findsOneWidget);
      await tap(tester, 'save-draft');
      expect(repo.created, isEmpty, reason: 'the API refuses it on every save, so nothing is sent');
      expect(find.text('Maximum salary must be at least the minimum.'), findsWidgets);
      await type(tester, 'sal-max', '1200000');
      expect(find.byKey(_k('blocker-salaryOrder')), findsNothing);
      await tap(tester, 'save-draft');
      final draft = repo.created.single.draft;
      expect(draft.salaryMin, 900000);
      expect(draft.salaryMax, 1200000);
    });

    testWidgets('a salary box takes nine digits at most', (tester) async {
      await openComposer(tester);
      await type(tester, 'sal-max', '12345678901');
      expect(tester.widget<TextField>(find.byKey(_k('sal-max'))).controller!.text, '123456789');
    });

    testWidgets('the currency, the period and the two switches are sent', (tester) async {
      final (repo, _, _) = await openComposer(tester);
      await type(tester, 'job-title', 'Supervisor');
      await tap(tester, 'currency-AED');
      await tap(tester, 'period-MONTHLY');
      await tester.tap(find.byKey(_k('salary-visible')));
      await tester.pump();
      await tester.tap(find.byKey(_k('salary-negotiable')));
      await tester.pump();
      await tap(tester, 'save-draft');
      final draft = repo.created.single.draft;
      expect(draft.salaryCurrency, 'AED');
      expect(draft.salaryPeriod, 'MONTHLY');
      expect(draft.salaryVisible, isFalse, reason: 'it started on');
      expect(draft.negotiable, isTrue, reason: 'it started off');
    });
  });

  group('applying', () {
    testWidgets('openings are a whole number, one by default', (tester) async {
      final (repo, _, _) = await openComposer(tester);
      await fillReady(tester);
      await type(tester, 'openings', '4');
      await tap(tester, 'save-draft');
      expect(repo.created.single.draft.openings, 4);
    });

    testWidgets('an own-site apply asks for a link, and the checklist waits for a good one', (tester) async {
      final (repo, _, _) = await openComposer(tester);
      await fillReady(tester);
      expect(find.byKey(_k('apply-url')), findsNothing);
      await tap(tester, 'apply-EXTERNAL');
      expect(find.byKey(_k('apply-url')), findsOneWidget);
      expect(find.byKey(_k('blocker-applyUrl')), findsOneWidget);

      await type(tester, 'apply-url', 'careers.example.com');
      expect(find.byKey(_k('blocker-applyUrl')), findsOneWidget);
      await tap(tester, 'save-draft');
      expect(find.text('The apply link must be a full URL including https://'), findsWidgets);
      expect(repo.created, isEmpty, reason: 'a bad link is not even saved');

      await type(tester, 'apply-url', 'https://careers.example.com/jobs/1');
      expect(find.byKey(_k('blocker-applyUrl')), findsNothing);
      await tap(tester, 'save-draft');
      final json = repo.created.single.draft.toJson();
      expect(json['applyMethod'], 'EXTERNAL_URL');
      expect(json['applyUrl'], 'https://careers.example.com/jobs/1');

      await tap(tester, 'apply-ICR');
      expect(find.byKey(_k('apply-url')), findsNothing);
    });

    testWidgets('the apply-by date is picked, shown, and cleared', (tester) async {
      final (repo, _, _) = await openComposer(tester);
      await type(tester, 'job-title', 'Supervisor');
      expect(find.text('Pick a date'), findsOneWidget);
      await tap(tester, 'apply-deadline');
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('9 Nov 2026'), findsOneWidget, reason: 'two weeks on from the 26th');
      await tap(tester, 'save-draft');
      expect(repo.created.single.draft.applyDeadline, isNotNull);

      await tap(tester, 'clear-deadline');
      expect(find.text('Pick a date'), findsOneWidget);
      expect(find.byKey(_k('clear-deadline')), findsNothing);
    });

    testWidgets('the résumé and contact switches are sent', (tester) async {
      final (repo, _, _) = await openComposer(tester);
      await type(tester, 'job-title', 'Supervisor');
      await tester.tap(find.byKey(_k('require-resume')));
      await tester.pump();
      await tester.tap(find.byKey(_k('show-contact')));
      await tester.pump();
      await tap(tester, 'save-draft');
      final draft = repo.created.single.draft;
      expect(draft.requireResume, isTrue);
      expect(draft.showHiringContact, isFalse);
    });
  });

  group('the checklist', () {
    testWidgets('a complete posting is "Ready to publish"', (tester) async {
      await openComposer(tester);
      await fillReady(tester);
      expect(find.text('Ready to publish'), findsOneWidget);
      expect(find.byKey(_k('blocker-title')), findsNothing);
      expect(find.byKey(_k('send-review')), findsOneWidget);
    });

    testWidgets('a row of the checklist takes you to the section it is about', (tester) async {
      await openComposer(tester, size: const Size(390, 800));
      await tester.scrollUntilVisible(
        find.byKey(_k('blocker-skills')),
        300,
        scrollable: find.descendant(of: find.byType(PostJobScreen), matching: find.byType(Scrollable)).first,
      );
      await tester.tap(find.byKey(_k('blocker-skills')));
      await tester.pumpAndSettle();
      // The skills card is on screen now.
      final top = tester.getTopLeft(find.byKey(_k('skill-input'))).dy;
      expect(top, inInclusiveRange(0, 800));
    });
  });

  group('saving', () {
    testWidgets('a draft is saved with only a title, and the screen stays', (tester) async {
      final (repo, _, _) = await openComposer(tester);
      await type(tester, 'job-title', 'Supervisor');
      await tap(tester, 'save-draft');
      await tester.pump();
      expect(repo.created.single.status, PostingStatus.draft);
      expect(repo.created.single.draft.title, 'Supervisor');
      expect(find.text('Draft saved.'), findsOneWidget);
      expect(find.byKey(_k('job-title')), findsOneWidget, reason: 'still on the composer');
    });

    testWidgets('saving again changes that posting, it does not make another', (tester) async {
      final (repo, _, _) = await openComposer(tester);
      await type(tester, 'job-title', 'Supervisor');
      await tap(tester, 'save-draft');
      await type(tester, 'job-title', 'Senior Supervisor');
      await tap(tester, 'save-draft');
      expect(repo.created, hasLength(1));
      expect(repo.updated.single.draft.title, 'Senior Supervisor');
    });

    testWidgets('a draft with no title is not saved, and says why', (tester) async {
      final (repo, _, _) = await openComposer(tester);
      await tap(tester, 'save-draft');
      await tester.pump();
      expect(find.text('Give the posting a title to save it.'), findsWidgets);
      expect(repo.created, isEmpty);
    });

    testWidgets('a refusal from the API is shown and nothing typed is lost', (tester) async {
      final repo = SpyHiring()..failures['createJob'] = ApiError('Something went wrong on our side.');
      await openComposer(tester, repo: repo);
      await type(tester, 'job-title', 'Supervisor');
      await tap(tester, 'save-draft');
      await tester.pump();
      expect(find.text('Something went wrong on our side.'), findsWidgets);
      expect(tester.widget<TextField>(find.byKey(_k('job-title'))).controller!.text, 'Supervisor');
      repo.failures.remove('createJob');
      await tap(tester, 'save-draft');
      expect(repo.created, hasLength(1));
    });

    testWidgets('editing a live posting saves the changes and keeps it live', (tester) async {
      final (repo, _, _) = await openComposer(tester, jobId: 'job-open');
      await type(tester, 'job-title', 'Facilities Operations Head');
      await tap(tester, 'save-draft');
      await tester.pump();
      expect(repo.updated.single.id, 'job-open');
      expect(repo.updated.single.status, isNull, reason: 'its status is left alone');
      expect(repo.updated.single.draft.title, 'Facilities Operations Head');
      expect(find.text('Changes saved.'), findsOneWidget);
    });
  });

  group('publishing', () {
    testWidgets('a ready posting is saved, then moved to open, and the composer closes', (tester) async {
      final (repo, _, _) = await openComposer(tester);
      await fillReady(tester);
      await tap(tester, 'publish');
      await tester.pumpAndSettle();
      expect(repo.created.single.status, PostingStatus.draft, reason: 'saved first, so nothing typed is lost');
      expect(repo.updated.single.status, PostingStatus.open);
      expect(find.byKey(_k('job-title')), findsNothing);
      expect(find.byKey(_k('open-screen')), findsOneWidget);
      expect(find.text('Published. It is live on the job board.'), findsOneWidget);
    });

    testWidgets('a posting with several things missing is not sent, and counts them', (tester) async {
      final (repo, _, _) = await openComposer(tester);
      await type(tester, 'job-title', 'Supervisor');
      await tap(tester, 'publish');
      await tester.pump();
      expect(find.text('Finish 2 things before publishing.'), findsWidgets);
      expect(repo.created, isEmpty);
    });

    testWidgets('a posting with one thing missing names it', (tester) async {
      final (repo, _, _) = await openComposer(tester);
      await type(tester, 'job-title', 'Supervisor');
      await type(tester, 'job-description', _description);
      await tap(tester, 'publish');
      await tester.pump();
      expect(find.text('Add at least one required skill so the right candidates find this role.'), findsWidgets);
      expect(repo.created, isEmpty);
    });

    testWidgets(
      "the plan's limit is shown as the API words it, the draft is kept, and a retry makes no second posting",
      (tester) async {
        final repo = SpyHiring()
          ..failures['updateJob'] = ApiError('Your plan allows 1 live job. Close one or upgrade.');
        await openComposer(tester, repo: repo);
        await fillReady(tester);
        await tap(tester, 'publish');
        await tester.pumpAndSettle();
        expect(find.text('Your plan allows 1 live job. Close one or upgrade.'), findsWidgets);
        expect(repo.created, hasLength(1), reason: 'the posting stays a saved draft');
        expect(find.byKey(_k('job-title')), findsOneWidget);

        repo.failures.remove('updateJob');
        await tap(tester, 'publish');
        await tester.pumpAndSettle();
        expect(repo.created, hasLength(1));
        expect(repo.updated.last.status, PostingStatus.open);
        expect(find.byKey(_k('job-title')), findsNothing);
      },
    );

    testWidgets('a paused posting is published again from the composer', (tester) async {
      final (repo, _, _) = await openComposer(tester, jobId: 'job-paused');
      await tap(tester, 'publish');
      await tester.pumpAndSettle();
      expect(repo.updated.last.status, PostingStatus.open);
      expect(repo.created, isEmpty);
    });

    testWidgets("a company that is not verified yet is told so, can still draft, and is sent to verify", (
      tester,
    ) async {
      final repo = SpyHiring(
        access: const HiringAccess(
          userId: 'me',
          role: 'COMPANY_ADMIN',
          companyId: 'c',
          canPublish: false,
          publishNote: 'Your company check is still with ICR.',
        ),
      );
      final (_, links, nav) = await openComposer(tester, repo: repo);
      expect(find.byKey(_k('gate-note')), findsOneWidget);
      expect(find.text('Your company check is still with ICR.'), findsOneWidget);
      await fillReady(tester);
      await tap(tester, 'publish');
      await tester.pump();
      expect(find.text('Your company check is still with ICR.'), findsWidgets);
      expect(repo.created, isEmpty);

      await tap(tester, 'save-draft');
      expect(repo.created.single.status, PostingStatus.draft, reason: 'a draft is always allowed');

      await tester.tap(find.text('Verify'));
      await tester.pump();
      expect(nav.calls, ['verify-company']);
      expect(links.opened, isEmpty);
    });

    testWidgets('without the app\'s verification screen, Verify opens the website page', (tester) async {
      final repo = SpyHiring(
        access: const HiringAccess(userId: 'me', role: 'COMPANY_ADMIN', companyId: 'c', canPublish: false),
      );
      final hiring = repo;
      final links = await openOnPhone(
        tester,
        (context, links) => PostJobScreen(repository: hiring, links: links, clock: hiringClock),
        size: const Size(390, 6000),
      );
      expect(find.textContaining('Verify your company before publishing jobs'), findsOneWidget);
      await tester.tap(find.text('Verify'));
      await tester.pump();
      expect(links.paths, ['/company?tab=verification']);
    });

    testWidgets('a draft can be sent to ICR for review instead, and the composer closes', (tester) async {
      final (repo, _, _) = await openComposer(tester);
      await fillReady(tester);
      await tap(tester, 'send-review');
      await tester.pumpAndSettle();
      expect(repo.created.single.status, PostingStatus.draft);
      expect(repo.calls, contains(startsWith('submitForReview')));
      expect(find.byKey(_k('open-screen')), findsOneWidget);
      expect(find.text('Sent to ICR for review. It goes live once approved.'), findsOneWidget);
    });
  });

  group('leaving', () {
    testWidgets('a form nobody touched closes without asking', (tester) async {
      await openComposer(tester);
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byKey(_k('leave-dialog')), findsNothing);
      expect(find.byKey(_k('open-screen')), findsOneWidget);
    });

    testWidgets('unsaved changes ask first: keep editing, discard, or save as a draft', (tester) async {
      final (repo, _, _) = await openComposer(tester);
      await type(tester, 'job-title', 'Supervisor');

      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byKey(_k('leave-dialog')), findsOneWidget);
      await tap(tester, 'leave-stay');
      await tester.pumpAndSettle();
      expect(find.byKey(_k('job-title')), findsOneWidget);

      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();
      await tap(tester, 'leave-discard');
      await tester.pumpAndSettle();
      expect(find.byKey(_k('open-screen')), findsOneWidget);
      expect(repo.created, isEmpty, reason: 'discarded');
    });

    testWidgets('"Save draft" on the way out saves, then leaves', (tester) async {
      final (repo, _, _) = await openComposer(tester);
      await type(tester, 'job-title', 'Supervisor');
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();
      await tap(tester, 'leave-save');
      await tester.pumpAndSettle();
      expect(repo.created.single.draft.title, 'Supervisor');
      expect(find.byKey(_k('open-screen')), findsOneWidget);
    });

    testWidgets('"Save draft" on the way out stays if the save is refused', (tester) async {
      final repo = SpyHiring()..failures['createJob'] = ApiError('Not now.');
      await openComposer(tester, repo: repo);
      await type(tester, 'job-title', 'Supervisor');
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();
      await tap(tester, 'leave-save');
      await tester.pumpAndSettle();
      expect(find.text('Not now.'), findsOneWidget);
      expect(find.byKey(_k('job-title')), findsOneWidget, reason: 'nothing was lost');
    });

    testWidgets('after a save the form is clean again', (tester) async {
      await openComposer(tester);
      await type(tester, 'job-title', 'Supervisor');
      await tap(tester, 'save-draft');
      await tester.pump();
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byKey(_k('leave-dialog')), findsNothing);
      expect(find.byKey(_k('open-screen')), findsOneWidget);
    });
  });

  group('the questions a job asks', () {
    Future<void> addQuestion(
      WidgetTester tester, {
      String type = 'YES_NO',
      String prompt = 'Can you work rotational shifts?',
      String? options,
      String? ideal,
      bool must = false,
    }) async {
      await tap(tester, 'add-question');
      await tester.pumpAndSettle();
      if (type != 'YES_NO') {
        await tester.tap(find.byKey(_k('qtype-$type')));
        await tester.pumpAndSettle();
      }
      await tester.enterText(find.byKey(_k('question-prompt')), prompt);
      if (options != null) await tester.enterText(find.byKey(_k('question-options')), options);
      if (ideal != null) await tester.enterText(find.byKey(_k('question-ideal')), ideal);
      if (must) {
        await tester.tap(find.byKey(_k('question-must')));
        await tester.pump();
      }
      await tester.tap(find.byKey(_k('question-save')));
      await tester.pumpAndSettle();
    }

    testWidgets('starts with none, and a question is added, listed with its kind', (tester) async {
      await openComposer(tester);
      expect(find.byKey(_k('no-questions')), findsOneWidget);
      await addQuestion(tester, ideal: 'true', must: true);
      expect(find.byKey(_k('no-questions')), findsNothing);
      expect(find.text('1. Can you work rotational shifts?'), findsOneWidget);
      expect(find.text('Yes or no • Must have'), findsOneWidget);
    });

    testWidgets('a question too short is refused in the dialog', (tester) async {
      await openComposer(tester);
      await tap(tester, 'add-question');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(_k('question-prompt')), 'Hi');
      await tester.tap(find.byKey(_k('question-save')));
      await tester.pump();
      expect(find.text('Write each question in at least 3 characters.'), findsOneWidget);
      expect(find.byKey(_k('question-dialog')), findsOneWidget);
    });

    testWidgets('a pick-one question needs two options, one to a line', (tester) async {
      await openComposer(tester);
      await tap(tester, 'add-question');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_k('qtype-SINGLE_SELECT')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(_k('question-prompt')), 'Which shift?');
      await tester.enterText(find.byKey(_k('question-options')), 'Day');
      await tester.tap(find.byKey(_k('question-save')));
      await tester.pump();
      expect(find.text('Give "Which shift?" at least two options.'), findsOneWidget);
      await tester.enterText(find.byKey(_k('question-options')), 'Day\nNight\n');
      await tester.tap(find.byKey(_k('question-save')));
      await tester.pumpAndSettle();
      expect(find.text('Pick one • 2 options'), findsOneWidget);
    });

    testWidgets('a rating asks for its scale; a text question has no answer to match', (tester) async {
      await openComposer(tester);
      await tap(tester, 'add-question');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_k('qtype-RATING')));
      await tester.pumpAndSettle();
      expect(find.byKey(_k('scale-5')), findsOneWidget);
      expect(find.byKey(_k('scale-10')), findsOneWidget);
      await tester.tap(find.byKey(_k('qtype-TEXT')));
      await tester.pumpAndSettle();
      expect(find.byKey(_k('scale-5')), findsNothing);
      expect(find.byKey(_k('question-ideal')), findsNothing);
      expect(find.byKey(_k('question-options')), findsNothing);
    });

    testWidgets('a question is edited by a tap on it, moved up, and removed', (tester) async {
      await openComposer(tester);
      await addQuestion(tester, prompt: 'First question?');
      await addQuestion(tester, prompt: 'Second question?');
      expect(find.byKey(_k('question-up-0')), findsNothing);
      await tap(tester, 'question-up-1');
      expect(find.text('1. Second question?'), findsOneWidget);
      expect(find.text('2. First question?'), findsOneWidget);

      await tester.tap(find.text('1. Second question?'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(_k('question-prompt')), 'Second, reworded?');
      await tester.tap(find.byKey(_k('question-save')));
      await tester.pumpAndSettle();
      expect(find.text('1. Second, reworded?'), findsOneWidget);

      await tap(tester, 'question-remove-0');
      expect(find.text('1. First question?'), findsOneWidget);
      expect(find.text('Second, reworded?'), findsNothing);
    });

    testWidgets('the questions are saved with the posting, in order', (tester) async {
      final (repo, _, _) = await openComposer(tester);
      await type(tester, 'job-title', 'Supervisor');
      await addQuestion(tester, prompt: 'First question?');
      await addQuestion(tester, type: 'YEARS', prompt: 'Years in FM?', ideal: '5', must: true);
      await tap(tester, 'save-draft');
      await tester.pump();
      final saved = repo.questionSets.single;
      expect(saved.questions.map((q) => q.prompt), ['First question?', 'Years in FM?']);
      expect(saved.questions[1].type, 'YEARS');
      expect(saved.questions[1].idealAnswer, '5');
      expect(saved.questions[1].mustHave, isTrue);
    });

    testWidgets('a posting that changed no question does not rewrite them', (tester) async {
      final (repo, _, _) = await openComposer(tester, jobId: 'job-open');
      await type(tester, 'job-title', 'Facilities Operations Head');
      await tap(tester, 'save-draft');
      await tester.pump();
      expect(repo.questionSets, isEmpty);
    });

    testWidgets('ten questions is the most, and then the add button waits', (tester) async {
      await openComposer(
        tester,
        initial: JobDraft(
          title: 'Supervisor',
          screening: [for (var i = 0; i < 10; i++) ScreeningDraft(prompt: 'Question number $i?')],
        ),
      );
      expect(tester.widget<OutlinedButton>(find.byKey(_k('add-question'))).onPressed, isNull);
      await tap(tester, 'question-remove-9');
      expect(tester.widget<OutlinedButton>(find.byKey(_k('add-question'))).onPressed, isNotNull);
    });

    test('every kind of question has a label', () {
      for (final (v, label) in ScreeningDraft.types) {
        expect(ScreeningEditor.typeLabel(v), label);
      }
      expect(ScreeningEditor.typeLabel('MYSTERY'), 'MYSTERY');
    });
  });
}
