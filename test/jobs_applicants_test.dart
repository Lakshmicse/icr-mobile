import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/jobs/employer/applicant_detail_screen.dart';
import 'package:icr_mobile/features/jobs/employer/applicants_screen.dart';
import 'package:icr_mobile/features/jobs/employer/hiring_models.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'hiring_fakes.dart';
import 'helpers/fonts.dart';
import 'jobs_fakes.dart';

/// Every control of a job's pipeline and of one application, tapped: what it does on the phone and
/// what it sends. What the API does with them is proved in `test/live/jobs_employer_live_test.dart`.

Key _k(String key) => ValueKey(key);

Future<(SpyHiring, RecordingLinks, RecordingNavigation)> openPipeline(
  WidgetTester tester, {
  SpyHiring? repo,
  String jobId = 'job-open',
  String? title = 'Facilities Operations Lead',
  String? stage,
}) async {
  final hiring = repo ?? SpyHiring();
  final nav = RecordingNavigation();
  final links = await openOnPhone(
    tester,
    (context, links) => ApplicantsScreen(
      repository: hiring,
      jobId: jobId,
      jobTitle: title,
      stage: stage,
      links: links,
      navigation: nav.navigation,
      clock: hiringClock,
    ),
    size: const Size(390, 2600),
  );
  return (hiring, links, nav);
}

/// The pipeline row the demo holds for [id], as the pipeline would hand it to the detail screen.
Future<Applicant> seedOf(String id, {String jobId = 'job-open'}) async {
  final page = await SpyHiring().applicants(jobId);
  return page.applicants.firstWhere((a) => a.id == id);
}

Future<(SpyHiring, RecordingLinks, RecordingNavigation, List<Applicant>)> openDetail(
  WidgetTester tester,
  String id, {
  SpyHiring? repo,
}) async {
  final hiring = repo ?? SpyHiring();
  final nav = RecordingNavigation();
  final seed = await seedOf(id);
  final changes = <Applicant>[];
  final links = await openOnPhone(
    tester,
    (context, links) => ApplicantDetailScreen(
      repository: hiring,
      applicant: seed,
      jobTitle: 'Facilities Operations Lead',
      links: links,
      navigation: nav.navigation,
      onChanged: changes.add,
      clock: hiringClock,
    ),
    size: const Size(390, 4200),
  );
  return (hiring, links, nav, changes);
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(_k(key)));
  await tester.tap(find.byKey(_k(key)));
  await tester.pumpAndSettle();
}

ApplicantDetail detailOf(
  Applicant a, {
  List<GradedAnswer> answers = const [],
  List<TeamInterview> interviews = const [],
  List<TeamOffer> offers = const [],
  List<ActivityEvent> events = const [],
  String? summary,
}) => ApplicantDetail(
  applicant: a,
  jobTitle: 'Facilities Operations Lead',
  answers: answers,
  interviews: interviews,
  offers: offers,
  events: events,
  aiSummary: summary,
);

void main() {
  setUpAll(loadAppFonts);

  group('the pipeline', () {
    testWidgets('names the job and counts the applicants not yet viewed', (tester) async {
      await openPipeline(tester);
      expect(find.byKey(_k('applicants-job')), findsOneWidget);
      expect(find.text('Facilities Operations Lead'), findsOneWidget);
      expect(find.text('6 applicants • 1 not viewed'), findsOneWidget, reason: 'Divya was opened');
    });

    testWidgets('the stage tabs count each stage', (tester) async {
      await openPipeline(tester);
      expect(find.text('All 6'), findsOneWidget);
      expect(find.text('Applied 2'), findsOneWidget);
      expect(find.text('In review 1'), findsOneWidget);
      expect(find.text('Interview 1'), findsOneWidget);
      expect(find.text('Offer 1'), findsOneWidget);
      // The tabs run sideways: at the app's 13 sp label size the last ones are past the edge until it is dragged.
      await tester.drag(find.byKey(_k('stage-OFFER')), const Offset(-250, 0));
      await tester.pumpAndSettle();
      expect(find.text('Hired 0'), findsOneWidget);
      await tester.drag(find.text('Hired 0'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('Not selected 1'), findsOneWidget);
    });

    testWidgets('a row says who they are, how well they match, and where they stand', (tester) async {
      await openPipeline(tester);
      final aarav = find.byKey(_k('applicant-app-aarav'));
      expect(find.descendant(of: aarav, matching: find.text('Aarav Khanna')), findsOneWidget);
      expect(
        find.descendant(
          of: aarav,
          matching: find.text('Facilities Manager - healthcare campuses • Apollo Hospitals • 11 yrs'),
        ),
        findsOneWidget,
      );
      expect(find.descendant(of: aarav, matching: find.text('Applied')), findsOneWidget);
      expect(find.descendant(of: aarav, matching: find.text('82% match')), findsOneWidget);
      expect(find.descendant(of: aarav, matching: find.text('Applied 24 Oct')), findsOneWidget);
      expect(find.byKey(_k('unviewed-app-aarav')), findsOneWidget, reason: 'nobody on the team has opened it');
      expect(find.byKey(_k('unviewed-app-divya')), findsNothing);
      expect(find.byKey(_k('unviewed-app-nisha')), findsNothing, reason: 'only a new application is flagged');
    });

    testWidgets('an interview and an offer show on their rows', (tester) async {
      await openPipeline(tester);
      expect(find.text('Interview Wed 28 Oct, 3:00 PM'), findsOneWidget);
      expect(find.text('Offer sent, awaiting reply'), findsOneWidget);
    });

    testWidgets('a stage tab shows that stage, and an empty one says so and offers everyone back', (tester) async {
      final (repo, _, _) = await openPipeline(tester);
      await tapKey(tester, 'stage-INTERVIEW');
      expect(repo.applicantQueries.last.stage, 'INTERVIEW');
      expect(find.byKey(_k('applicant-app-sanjana')), findsOneWidget);
      expect(find.byKey(_k('applicant-app-aarav')), findsNothing);

      await tapKey(tester, 'stage-HIRED');
      expect(find.byKey(_k('applicants-empty')), findsOneWidget);
      expect(find.text('No one matches'), findsOneWidget);
      await tester.tap(find.text('Show everyone'));
      await tester.pumpAndSettle();
      expect(repo.applicantQueries.last.stage, isNull);
      expect(find.byKey(_k('applicant-app-aarav')), findsOneWidget);
    });

    testWidgets('it can open on a stage', (tester) async {
      final (repo, _, _) = await openPipeline(tester, stage: 'OFFER');
      expect(repo.applicantQueries.first.stage, 'OFFER');
      expect(find.byKey(_k('applicant-app-ishita')), findsOneWidget);
      expect(find.byKey(_k('applicant-app-aarav')), findsNothing);
    });

    testWidgets('Sort ranks by match or by qualifications and asks the API', (tester) async {
      final (repo, _, _) = await openPipeline(tester);
      await tester.tap(find.byKey(_k('applicants-sort')));
      await tester.pumpAndSettle();
      for (final label in ['Most recent', 'Best match', 'Most qualified']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      await tester.tap(find.text('Best match').last);
      await tester.pumpAndSettle();
      expect(repo.applicantQueries.last.sort, 'match');
      final tops = [
        for (final id in ['app-ishita', 'app-sanjana', 'app-aarav'])
          tester.getTopLeft(find.byKey(_k('applicant-$id'))).dy,
      ];
      expect(tops[0] < tops[1] && tops[1] < tops[2], isTrue, reason: 'best match first: 93, 91, 82');
    });

    testWidgets('the rating filter keeps those rated at or above the chosen stars', (tester) async {
      final (repo, _, _) = await openPipeline(tester);
      await tester.tap(find.byKey(_k('applicants-rating')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4 stars and up'));
      await tester.pumpAndSettle();
      expect(repo.applicantQueries.last.minRating, 4);
      expect(find.byKey(_k('applicant-app-nisha')), findsOneWidget);
      expect(find.byKey(_k('applicant-app-harsh')), findsNothing);
      expect(find.byKey(_k('applicant-app-aarav')), findsNothing);
      expect(find.text('4+ stars'), findsOneWidget);

      await tester.tap(find.byKey(_k('applicants-rating')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Any rating'));
      await tester.pumpAndSettle();
      expect(repo.applicantQueries.last.minRating, isNull);
      expect(find.byKey(_k('applicant-app-aarav')), findsOneWidget);
    });

    testWidgets('"Qualified" asks only for those who met the must-haves, and goes off again', (tester) async {
      final (repo, _, _) = await openPipeline(tester);
      await tester.tap(find.byKey(_k('applicants-qualified')));
      await tester.pumpAndSettle();
      expect(repo.applicantQueries.last.qualifiedOnly, isTrue);
      await tester.tap(find.byKey(_k('applicants-qualified')));
      await tester.pumpAndSettle();
      expect(repo.applicantQueries.last.qualifiedOnly, isFalse);
    });

    testWidgets('a job with no applicants says so', (tester) async {
      await openPipeline(tester, jobId: 'job-quiet', title: 'Energy Manager');
      expect(find.byKey(_k('applicants-empty')), findsOneWidget);
      expect(find.text('No applicants yet'), findsWidgets);
    });

    testWidgets('a pipeline that cannot load says why, and tries again', (tester) async {
      final repo = SpyHiring()..failures['applicants'] = ApiError('We could not reach ICR.');
      await openPipeline(tester, repo: repo);
      expect(find.byKey(_k('applicants-error')), findsOneWidget);
      expect(find.text('We could not reach ICR.'), findsOneWidget);
      repo.failures.remove('applicants');
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byKey(_k('applicants-error')), findsNothing);
      expect(find.byKey(_k('applicant-app-aarav')), findsOneWidget);
    });

    testWidgets('the bell opens the notifications', (tester) async {
      final (_, _, nav) = await openPipeline(tester);
      await tester.tap(find.byIcon(LucideIcons.bell));
      await tester.pump();
      expect(nav.calls, ['bell']);
    });
  });

  group('moving someone on from the list', () {
    Future<void> menu(WidgetTester tester, String id) async {
      await tester.tap(find.byKey(_k('applicant-menu-$id')));
      await tester.pumpAndSettle();
    }

    testWidgets('the menu offers only the moves the API allows from their stage', (tester) async {
      await openPipeline(tester);
      await menu(tester, 'app-aarav');
      expect(find.text('Move to review'), findsOneWidget);
      expect(find.text('Move to interview'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(find.text('Move to offer'), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await menu(tester, 'app-sanjana');
      expect(find.text('Move to offer'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(find.text('Move to review'), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await menu(tester, 'app-ishita');
      expect(find.text('Mark as hired'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await menu(tester, 'app-harsh');
      expect(find.text('Move to review'), findsOneWidget);
      expect(find.text('Move to interview'), findsOneWidget);
      expect(find.text('Reject'), findsNothing, reason: 'already not selected');
    });

    testWidgets('a move shows at once, the counts follow, and the API is told', (tester) async {
      final (repo, _, _) = await openPipeline(tester);
      await menu(tester, 'app-aarav');
      await tester.tap(find.text('Move to review'));
      await tester.pumpAndSettle();
      expect(repo.moves.single, (id: 'app-aarav', stage: 'SCREENING', note: null));
      expect(
        find.descendant(of: find.byKey(_k('applicant-app-aarav')), matching: find.text('In review')),
        findsOneWidget,
      );
      expect(find.text('Aarav Khanna moved to in review.'), findsOneWidget);
      expect(find.text('Applied 1'), findsOneWidget);
      expect(find.text('In review 2'), findsOneWidget);
    });

    testWidgets('on a stage tab, a moved applicant leaves the tab', (tester) async {
      final (repo, _, _) = await openPipeline(tester, stage: 'APPLIED');
      await menu(tester, 'app-aarav');
      await tester.tap(find.text('Move to interview'));
      await tester.pumpAndSettle();
      expect(repo.moves.single.stage, 'INTERVIEW');
      expect(find.byKey(_k('applicant-app-aarav')), findsNothing);
      expect(find.byKey(_k('applicant-app-divya')), findsOneWidget);
    });

    testWidgets('Reject asks for a reason first: Cancel does nothing, Reject sends it with the move', (tester) async {
      final (repo, _, _) = await openPipeline(tester);
      await menu(tester, 'app-aarav');
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      expect(find.byKey(_k('stage-note-dialog')), findsOneWidget);
      expect(find.text('Not selecting Aarav Khanna?'), findsOneWidget);
      await tester.tap(find.byKey(_k('stage-note-cancel')));
      await tester.pumpAndSettle();
      expect(repo.moves, isEmpty);

      await menu(tester, 'app-aarav');
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(_k('stage-note')), 'Not enough audit experience');
      await tester.tap(find.byKey(_k('stage-note-confirm')));
      await tester.pumpAndSettle();
      expect(repo.moves.single, (id: 'app-aarav', stage: 'REJECTED', note: 'Not enough audit experience'));
      expect(
        find.descendant(of: find.byKey(_k('applicant-app-aarav')), matching: find.text('Not selected')),
        findsOneWidget,
      );
    });

    testWidgets('a move the API refuses is put back, with its sentence', (tester) async {
      final repo = SpyHiring()..failures['moveStage'] = ApiError('That move is not allowed from here.');
      await openPipeline(tester, repo: repo);
      await menu(tester, 'app-aarav');
      await tester.tap(find.text('Move to review'));
      await tester.pumpAndSettle();
      expect(find.text('That move is not allowed from here.'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(_k('applicant-app-aarav')), matching: find.text('Applied')),
        findsOneWidget,
      );
      expect(find.text('Applied 2'), findsOneWidget);
    });

    testWidgets('stars on a row rate the application; a refusal takes the stars back', (tester) async {
      final (repo, _, _) = await openPipeline(tester);
      await tester.tap(find.byKey(_k('rate-app-aarav-4')));
      await tester.pumpAndSettle();
      expect(repo.notes.single, (id: 'app-aarav', note: null, rating: 4));

      repo.failures['addNote'] = ApiError('Ratings are closed for this job.');
      await tester.tap(find.byKey(_k('rate-app-divya-2')));
      await tester.pumpAndSettle();
      expect(find.text('Ratings are closed for this job.'), findsOneWidget);
      expect(repo.notes, hasLength(1));
    });

    testWidgets('tapping the star already given does not clear it (the API has no way to)', (tester) async {
      final (repo, _, _) = await openPipeline(tester);
      await tester.tap(find.byKey(_k('rate-app-nisha-4')));
      await tester.pumpAndSettle();
      expect(repo.notes, isEmpty);
    });
  });

  group('one application', () {
    testWidgets('opens from the pipeline, and a change made there is on the pipeline when it closes', (tester) async {
      final (repo, _, _) = await openPipeline(tester);
      await tester.tap(find.byKey(_k('applicant-app-aarav')));
      await tester.pumpAndSettle();
      expect(find.byType(ApplicantDetailScreen), findsOneWidget);
      expect(find.text('Aarav Khanna'), findsOneWidget);
      expect(repo.calls, contains('applicant app-aarav'));

      await tapKey(tester, 'detail-move-SCREENING');
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byKey(_k('applicant-app-aarav')), matching: find.text('In review')),
        findsOneWidget,
      );
    });

    testWidgets('says who applied: headline, company, place, years, skills, when and how', (tester) async {
      await openDetail(tester, 'app-aarav');
      expect(find.byKey(_k('detail-name')), findsOneWidget);
      expect(find.text('Facilities Manager - healthcare campuses'), findsOneWidget);
      expect(find.text('Apollo Hospitals • Ahmedabad • 11 yrs experience'), findsOneWidget);
      expect(find.text('HVAC Chillers'), findsOneWidget);
      expect(find.text('Statutory Audits'), findsOneWidget);
      expect(find.text('Applied 24 Oct 2026'), findsOneWidget);
      expect(find.descendant(of: find.byKey(_k('detail-stage')), matching: find.text('Applied')), findsOneWidget);
      expect(find.text('82% match'), findsOneWidget);
      expect(find.text('I have run three healthcare campuses for eleven years.'), findsOneWidget);
      expect(find.byKey(_k('detail-email')), findsOneWidget);
    });

    testWidgets('the screening answers are marked against the bar', (tester) async {
      final repo = SpyHiring();
      final seed = await seedOf('app-aarav');
      repo.applicantAnswer = (id) async => detailOf(
        seed,
        answers: const [
          GradedAnswer(prompt: 'Years in FM?', answer: '9', type: 'YEARS', meetsIdeal: true, mustHave: true),
          GradedAnswer(
            prompt: 'Rotational shifts?',
            answer: 'false',
            type: 'YES_NO',
            meetsIdeal: false,
            mustHave: true,
          ),
          GradedAnswer(prompt: 'NEBOSH?', answer: 'true', type: 'YES_NO', meetsIdeal: false),
          GradedAnswer(prompt: 'Why this role?', answer: 'Close to home.', type: 'TEXT'),
          GradedAnswer(prompt: 'Shifts you can work', answer: 'Day, Night', type: 'MULTI_SELECT'),
        ],
      );
      await openDetail(tester, 'app-aarav', repo: repo);
      expect(find.text('9 years'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);
      expect(find.text('Close to home.'), findsOneWidget);
      expect(find.text('Day, Night'), findsOneWidget);
      expect(find.text('Misses a must-have'), findsOneWidget);
      expect(find.text('Below your bar'), findsOneWidget);
      expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget);
      expect(find.byIcon(LucideIcons.circleX), findsNWidgets(2));
      expect(find.byIcon(LucideIcons.circleHelp), findsNWidgets(2), reason: 'not graded: no bar to mark against');
    });

    testWidgets('the links open what they name: the mail app, the résumé, LinkedIn, the profile', (tester) async {
      final repo = SpyHiring();
      final seed = Applicant(
        id: 'app-x',
        jobId: 'job-open',
        userId: 'u-x',
        name: 'Rhea Shah',
        stage: 'APPLIED',
        appliedAt: hiringNow,
        email: 'rhea@example.test',
        resumeFileUrl: 'https://files.example.test/rhea.pdf',
        resumeTitle: 'Rhea CV',
        linkedinUrl: 'https://www.linkedin.com/in/rhea',
        profilePublic: true,
      );
      repo.applicantAnswer = (id) async => detailOf(seed);
      final nav = RecordingNavigation();
      final links = await openOnPhone(
        tester,
        (context, links) => ApplicantDetailScreen(
          repository: repo,
          applicant: seed,
          links: links,
          navigation: nav.navigation,
          clock: hiringClock,
        ),
        size: const Size(390, 4200),
      );
      await tester.tap(find.byKey(_k('detail-email')));
      await tester.pump();
      await tester.tap(find.byKey(_k('detail-resume')));
      await tester.pump();
      await tester.tap(find.byKey(_k('detail-linkedin')));
      await tester.pump();
      expect(links.opened.map((u) => u.toString()), [
        'mailto:rhea@example.test',
        'https://files.example.test/rhea.pdf',
        'https://www.linkedin.com/in/rhea',
      ]);
      expect(find.text('Rhea CV'), findsOneWidget);
      await tester.tap(find.byKey(_k('detail-profile')));
      await tester.pump();
      expect(nav.calls, ['profile u-x']);
    });

    testWidgets('an application that cannot be read says why, and tries again', (tester) async {
      final repo = SpyHiring()..failures['applicant'] = ApiError('We could not reach ICR.');
      await openDetail(tester, 'app-aarav', repo: repo);
      expect(find.byKey(_k('detail-error')), findsOneWidget);
      expect(find.text('We could not reach ICR.'), findsOneWidget);
      repo.failures.remove('applicant');
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byKey(_k('detail-error')), findsNothing);
      expect(find.byKey(_k('section-answers')), findsOneWidget);
    });

    testWidgets('the activity trail starts with the application', (tester) async {
      await openDetail(tester, 'app-aarav');
      expect(find.byKey(_k('section-activity')), findsOneWidget);
      expect(find.byKey(_k('activity-0')), findsOneWidget);
    });
  });

  group('what the team can do from an application', () {
    Finder action(String key) => find.byKey(_k(key));

    testWidgets('a new application: review, interview, book, message, reject', (tester) async {
      await openDetail(tester, 'app-aarav');
      expect(action('detail-move-SCREENING'), findsOneWidget);
      expect(action('detail-move-INTERVIEW'), findsOneWidget);
      expect(action('detail-schedule'), findsOneWidget);
      expect(action('detail-message'), findsOneWidget);
      expect(action('detail-reject'), findsOneWidget);
      expect(action('detail-offer'), findsNothing, reason: 'no offer before they are in review');
    });

    testWidgets('one in review can also be offered', (tester) async {
      await openDetail(tester, 'app-nisha');
      expect(action('detail-move-INTERVIEW'), findsOneWidget);
      expect(action('detail-offer'), findsOneWidget);
      expect(action('detail-schedule'), findsOneWidget);
    });

    testWidgets('one with an offer out has "Mark as hired" and no second offer', (tester) async {
      await openDetail(tester, 'app-ishita');
      expect(action('detail-move-HIRED'), findsOneWidget);
      expect(action('detail-offer'), findsNothing);
      expect(action('detail-schedule'), findsNothing);
      expect(find.text('₹21,00,000 / yr'), findsOneWidget);
      expect(find.text('Sent'), findsOneWidget);
    });

    testWidgets('one who was not selected can be moved back, not rejected again', (tester) async {
      await openDetail(tester, 'app-harsh');
      expect(action('detail-move-SCREENING'), findsOneWidget);
      expect(action('detail-move-INTERVIEW'), findsOneWidget);
      expect(action('detail-reject'), findsNothing);
      expect(action('detail-schedule'), findsNothing);
    });

    testWidgets('a move updates the stage, the next steps, the trail, and the pipeline row', (tester) async {
      final (repo, _, _, changes) = await openDetail(tester, 'app-aarav');
      await tapKey(tester, 'detail-move-SCREENING');
      expect(repo.moves.single, (id: 'app-aarav', stage: 'SCREENING', note: null));
      expect(find.descendant(of: find.byKey(_k('detail-stage')), matching: find.text('In review')), findsOneWidget);
      expect(find.text('Moved from applied to in review'), findsOneWidget);
      expect(find.text('Aarav Khanna moved to in review.'), findsOneWidget);
      expect(action('detail-offer'), findsOneWidget, reason: 'in review: an offer is possible');
      expect(changes.last.stage, 'SCREENING');
    });

    testWidgets('Reject asks why, and sends the reason with the move', (tester) async {
      final (repo, _, _, _) = await openDetail(tester, 'app-aarav');
      await tapKey(tester, 'detail-reject');
      expect(find.byKey(_k('stage-note-dialog')), findsOneWidget);
      await tester.tap(find.byKey(_k('stage-note-cancel')));
      await tester.pumpAndSettle();
      expect(repo.moves, isEmpty);

      await tapKey(tester, 'detail-reject');
      await tester.enterText(find.byKey(_k('stage-note')), 'Not a fit');
      await tester.tap(find.byKey(_k('stage-note-confirm')));
      await tester.pumpAndSettle();
      expect(repo.moves.single, (id: 'app-aarav', stage: 'REJECTED', note: 'Not a fit'));
      expect(find.descendant(of: find.byKey(_k('detail-stage')), matching: find.text('Not selected')), findsOneWidget);
      expect(action('detail-reject'), findsNothing);
      expect(find.text('Moved from applied to not selected: Not a fit'), findsOneWidget);
    });

    testWidgets('a move the API refuses shows its sentence and changes nothing', (tester) async {
      final repo = SpyHiring();
      final (_, _, _, _) = await openDetail(tester, 'app-aarav', repo: repo);
      repo.failures['moveStage'] = ApiError('This application can no longer be moved.');
      await tapKey(tester, 'detail-move-SCREENING');
      expect(find.text('This application can no longer be moved.'), findsOneWidget);
      expect(find.descendant(of: find.byKey(_k('detail-stage')), matching: find.text('Applied')), findsOneWidget);
    });

    testWidgets('Message opens the conversation with the applicant, in the app', (tester) async {
      final (repo, links, nav, _) = await openDetail(tester, 'app-aarav');
      await tapKey(tester, 'detail-message');
      expect(repo.calls, contains('messageApplicant app-aarav'));
      expect(nav.calls, ['conversation conv-1']);
      expect(links.opened, isEmpty);
    });

    testWidgets('Message without the app\'s inbox opens the thread on the website', (tester) async {
      final hiring = SpyHiring();
      final seed = await seedOf('app-aarav');
      final links = await openOnPhone(
        tester,
        (context, links) =>
            ApplicantDetailScreen(repository: hiring, applicant: seed, links: links, clock: hiringClock),
        size: const Size(390, 4200),
      );
      await tapKey(tester, 'detail-message');
      expect(links.paths, ['/messaging?c=conv-1']);
    });

    testWidgets('Message says why it could not, and opens nothing', (tester) async {
      final repo = SpyHiring();
      final (_, _, nav, _) = await openDetail(tester, 'app-aarav', repo: repo);
      repo.failures['messageApplicant'] = ApiError('You can start 30 conversations an hour.');
      await tapKey(tester, 'detail-message');
      expect(find.text('You can start 30 conversations an hour.'), findsOneWidget);
      expect(nav.calls, isEmpty);
    });
  });

  group('notes and rating', () {
    testWidgets('an empty note with no stars is refused in the form', (tester) async {
      final (repo, _, _, _) = await openDetail(tester, 'app-aarav');
      await tapKey(tester, 'note-save');
      expect(find.text('Write a note or give a rating.'), findsOneWidget);
      expect(repo.notes, isEmpty);
    });

    testWidgets('a note and stars are sent together, shown on the trail, and the form clears', (tester) async {
      final (repo, _, _, _) = await openDetail(tester, 'app-aarav');
      await tester.ensureVisible(find.byKey(_k('note-input')));
      await tester.enterText(find.byKey(_k('note-input')), 'Strong on audits');
      await tester.tap(find.byKey(_k('note-star-4')));
      await tester.pump();
      await tapKey(tester, 'note-save');
      expect(repo.notes.single, (id: 'app-aarav', note: 'Strong on audits', rating: 4));
      expect(find.text('Note: Strong on audits'), findsOneWidget);
      expect(find.text('Rated 4 stars'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(_k('note-input'))).controller!.text, isEmpty);
    });

    testWidgets('stars alone are enough, and a note alone too', (tester) async {
      final (repo, _, _, _) = await openDetail(tester, 'app-aarav');
      await tester.ensureVisible(find.byKey(_k('note-star-5')));
      await tester.tap(find.byKey(_k('note-star-5')));
      await tester.pump();
      await tapKey(tester, 'note-save');
      expect(repo.notes.last, (id: 'app-aarav', note: '', rating: 5));

      await tester.enterText(find.byKey(_k('note-input')), 'Call back Monday');
      await tapKey(tester, 'note-save');
      expect(repo.notes.last.rating, isNull);
      expect(repo.notes.last.note, 'Call back Monday');
    });

    testWidgets('a refusal stays in the form with what was typed', (tester) async {
      final repo = SpyHiring();
      await openDetail(tester, 'app-aarav', repo: repo);
      repo.failures['addNote'] = ApiError('Notes are locked on closed jobs.');
      await tester.ensureVisible(find.byKey(_k('note-input')));
      await tester.enterText(find.byKey(_k('note-input')), 'Strong on audits');
      await tapKey(tester, 'note-save');
      expect(find.text('Notes are locked on closed jobs.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(_k('note-input'))).controller!.text, 'Strong on audits');
    });
  });

  group('interviews', () {
    Future<void> pickDateAndTime(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(_k('interview-date')));
      await tester.tap(find.byKey(_k('interview-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    testWidgets('the sheet starts with the booker on the panel and the team to choose from', (tester) async {
      await openDetail(tester, 'app-aarav');
      await tapKey(tester, 'detail-schedule');
      expect(find.text('Schedule an interview'), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(find.byKey(_k('panel-me'))).value, isTrue);
      expect(tester.widget<CheckboxListTile>(find.byKey(_k('panel-meera'))).value, isFalse);
      expect(find.text('Company admin'), findsOneWidget);
    });

    testWidgets('booking needs a date, a future time, a panel, and an address for an in-person round', (tester) async {
      final (repo, _, _, _) = await openDetail(tester, 'app-aarav');
      await tapKey(tester, 'detail-schedule');
      await tapKey(tester, 'interview-save');
      expect(find.text('Pick a date and time.'), findsOneWidget);

      await pickDateAndTime(tester);
      expect(find.text('Tue 27 Oct'), findsOneWidget);
      expect(find.text('Tue 27 Oct, 10:00 AM'), findsOneWidget);

      await tester.tap(find.byKey(_k('panel-me')));
      await tester.pump();
      await tapKey(tester, 'interview-save');
      expect(find.text('Choose at least one person for the panel.'), findsOneWidget);
      await tester.tap(find.byKey(_k('panel-meera')));
      await tester.pump();

      await tester.tap(find.byKey(_k('interview-mode-IN_PERSON')));
      await tester.pump();
      await tapKey(tester, 'interview-save');
      expect(find.text('Give the address for an in-person interview.'), findsOneWidget);

      await tester.enterText(find.byKey(_k('interview-map')), 'maps');
      await tester.enterText(find.byKey(_k('interview-location')), 'Floor 3, Northwind House');
      await tapKey(tester, 'interview-save');
      expect(find.text('The map link must be a full URL starting with https://'), findsOneWidget);
      expect(repo.booked, isEmpty, reason: 'nothing was sent while the form was wrong');
    });

    testWidgets('a good booking is sent with everything set, and shows on the application', (tester) async {
      final (repo, _, _, _) = await openDetail(tester, 'app-aarav');
      await tapKey(tester, 'detail-schedule');
      await tester.enterText(find.byKey(_k('interview-title')), 'Technical round');
      await pickDateAndTime(tester);
      await tester.tap(find.byKey(_k('interview-minutes-45')));
      await tester.pump();
      await tester.enterText(find.byKey(_k('interview-link')), 'https://meet.google.com/abc-defg-hij');
      await tester.enterText(find.byKey(_k('interview-notes')), 'Probe the audit answers');
      await tester.tap(find.byKey(_k('panel-meera')));
      await tester.pump();
      await tapKey(tester, 'interview-save');

      final booked = repo.booked.single;
      expect(booked.app, 'app-aarav');
      expect(booked.draft.title, 'Technical round');
      expect(booked.draft.scheduledAt, DateTime(2026, 10, 27, 10));
      expect(booked.draft.durationMins, 45);
      expect(booked.draft.mode, 'VIDEO');
      expect(booked.draft.meetingLink, 'https://meet.google.com/abc-defg-hij');
      expect(booked.draft.notes, 'Probe the audit answers');
      expect(booked.draft.interviewerIds, containsAll(['me', 'meera']));

      expect(find.text('Schedule an interview'), findsNothing, reason: 'the sheet closed');
      expect(find.byKey(_k('interview-iv-100')), findsOneWidget);
      expect(find.text('Technical round'), findsOneWidget);
      expect(find.text('Tue 27 Oct, 10:00 AM • 45 min • Video call'), findsOneWidget);
      expect(find.text('Scheduled'), findsOneWidget);
    });

    testWidgets('the API\'s refusal stays in the sheet, which stays open with what was set', (tester) async {
      final repo = SpyHiring();
      await openDetail(tester, 'app-aarav', repo: repo);
      repo.failures['scheduleInterview'] = ApiError('All interviewers must belong to your company.');
      await tapKey(tester, 'detail-schedule');
      await pickDateAndTime(tester);
      await tapKey(tester, 'interview-save');
      expect(find.text('All interviewers must belong to your company.'), findsOneWidget);
      expect(find.text('Tue 27 Oct, 10:00 AM'), findsOneWidget);
      repo.failures.remove('scheduleInterview');
      await tapKey(tester, 'interview-save');
      expect(repo.booked, hasLength(1));
      expect(find.text('Schedule an interview'), findsNothing);
    });

    testWidgets('a round is moved to a new time from its card', (tester) async {
      final (repo, _, _, _) = await openDetail(tester, 'app-aarav');
      await tapKey(tester, 'detail-schedule');
      await pickDateAndTime(tester);
      await tapKey(tester, 'interview-save');
      await tapKey(tester, 'interview-reschedule-iv-100');
      expect(find.text('Reschedule Round 1'), findsOneWidget);
      expect(find.text('Tue 27 Oct, 10:00 AM'), findsOneWidget, reason: 'starts from the booked time');
      await tester.tap(find.byKey(_k('interview-mode-PHONE')));
      await tester.pump();
      await tapKey(tester, 'interview-save');
      expect(repo.changedRounds.single.id, 'iv-100');
      expect(repo.changedRounds.single.draft!.mode, 'PHONE');
      expect(find.text('Reschedule Round 1'), findsNothing);
      expect(find.text('Rescheduled'), findsOneWidget);
    });

    testWidgets('Cancel asks first; Keep it does nothing, Cancel interview calls it off', (tester) async {
      final (repo, _, _, _) = await openDetail(tester, 'app-aarav');
      await tapKey(tester, 'detail-schedule');
      await pickDateAndTime(tester);
      await tapKey(tester, 'interview-save');

      await tapKey(tester, 'interview-cancel-iv-100');
      expect(find.byKey(_k('cancel-interview-dialog')), findsOneWidget);
      await tester.tap(find.byKey(_k('cancel-interview-keep')));
      await tester.pumpAndSettle();
      expect(repo.changedRounds, isEmpty);

      await tapKey(tester, 'interview-cancel-iv-100');
      await tester.tap(find.byKey(_k('cancel-interview-confirm')));
      await tester.pumpAndSettle();
      expect(repo.changedRounds.single.status, 'CANCELLED');
      expect(find.text('Round 1 is cancelled.'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.byKey(_k('interview-reschedule-iv-100')), findsNothing, reason: 'a cancelled round has no actions');
    });

    testWidgets('a round whose time has passed can be marked done or a no-show', (tester) async {
      final repo = SpyHiring();
      final seed = await seedOf('app-sanjana');
      repo.applicantAnswer = (id) async => detailOf(
        seed,
        interviews: [
          TeamInterview(
            id: 'iv-past',
            round: 1,
            scheduledAt: hiringNow.subtract(const Duration(days: 1)),
            mode: 'VIDEO',
            status: 'SCHEDULED',
            meetingLink: 'https://meet.example.test/x',
            panel: const [TeamMember(id: 'meera', name: 'Meera Iyer', role: '')],
            feedback: const [
              InterviewFeedbackRow(
                interviewer: 'Meera Iyer',
                rating: 4,
                recommendation: 'YES',
                strengths: 'Clear on audits',
              ),
            ],
          ),
          TeamInterview(
            id: 'iv-next',
            round: 2,
            scheduledAt: hiringNow.add(const Duration(days: 2)),
            mode: 'IN_PERSON',
            status: 'SCHEDULED',
            location: 'Floor 3',
          ),
        ],
      );
      await openDetail(tester, 'app-sanjana', repo: repo);
      expect(find.byKey(_k('interview-done-iv-past')), findsOneWidget);
      expect(find.byKey(_k('interview-noshow-iv-past')), findsOneWidget);
      expect(find.byKey(_k('interview-done-iv-next')), findsNothing, reason: 'it has not happened yet');
      expect(find.text('Meera Iyer: 4/5, Yes. Clear on audits'), findsOneWidget);
      expect(find.text('Panel: Meera Iyer'), findsOneWidget);
      expect(find.text('Floor 3'), findsOneWidget);

      await tapKey(tester, 'interview-done-iv-past');
      expect(repo.changedRounds.last.id, 'iv-past');
      expect(repo.changedRounds.last.status, 'COMPLETED');
      expect(find.text('Round 1 is marked done.'), findsOneWidget);

      await tapKey(tester, 'interview-noshow-iv-past');
      expect(repo.changedRounds.last.status, 'NO_SHOW');
    });

    testWidgets('the meeting link on a round opens', (tester) async {
      final repo = SpyHiring();
      final seed = await seedOf('app-sanjana');
      repo.applicantAnswer = (id) async => detailOf(
        seed,
        interviews: [
          TeamInterview(
            id: 'iv-1',
            round: 1,
            scheduledAt: hiringNow.add(const Duration(days: 2)),
            mode: 'VIDEO',
            status: 'SCHEDULED',
            meetingLink: 'https://meet.example.test/x',
          ),
        ],
      );
      final (_, links, _, _) = await openDetail(tester, 'app-sanjana', repo: repo);
      await tester.ensureVisible(find.byKey(_k('interview-link-iv-1')));
      await tester.tap(find.byKey(_k('interview-link-iv-1')));
      await tester.pump();
      expect(links.opened.single.toString(), 'https://meet.example.test/x');
    });
  });

  group('offers', () {
    testWidgets('an offer needs a salary, and goes out with the terms typed', (tester) async {
      final (repo, _, _, _) = await openDetail(tester, 'app-sanjana');
      await tapKey(tester, 'detail-offer');
      expect(find.text('Make an offer'), findsWidgets);
      await tapKey(tester, 'offer-send');
      expect(find.text('Enter the salary you are offering.'), findsOneWidget);
      expect(repo.offered, isEmpty);

      await tester.enterText(find.byKey(_k('offer-amount')), '1850000');
      await tester.tap(find.byKey(_k('offer-period-MONTHLY')));
      await tester.pump();
      await tester.enterText(find.byKey(_k('offer-title')), 'AVP Facilities');
      await tester.enterText(find.byKey(_k('offer-notes')), 'Welcome aboard');
      await tester.ensureVisible(find.byKey(_k('offer-joining')));
      await tester.tap(find.byKey(_k('offer-joining')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_k('offer-expires')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'offer-send');

      final made = repo.offered.single;
      expect(made.app, 'app-sanjana');
      expect(made.send, isTrue);
      expect(made.draft.amount, 1850000);
      expect(made.draft.period, 'MONTHLY');
      expect(made.draft.jobTitle, 'AVP Facilities');
      expect(made.draft.notes, 'Welcome aboard');
      expect(made.draft.joiningDate, isNotNull);
      expect(made.draft.expiresAt, isNotNull);
    });

    testWidgets('a sent offer moves the application to Offer and shows on it', (tester) async {
      final (repo, _, _, changes) = await openDetail(tester, 'app-sanjana');
      await tapKey(tester, 'detail-offer');
      await tester.enterText(find.byKey(_k('offer-amount')), '1850000');
      await tapKey(tester, 'offer-send');
      expect(find.text('Make an offer'), findsNothing, reason: 'the sheet closed');
      expect(find.descendant(of: find.byKey(_k('detail-stage')), matching: find.text('Offer')), findsOneWidget);
      expect(find.text('₹18,50,000 / yr'), findsOneWidget);
      expect(find.text('Sent'), findsOneWidget);
      expect(find.byKey(_k('detail-offer')), findsNothing, reason: 'one live offer at a time');
      expect(find.byKey(_k('detail-move-HIRED')), findsOneWidget);
      expect(changes.last.stage, 'OFFER');
      expect(repo.offered.single.send, isTrue);
    });

    testWidgets('a draft offer is kept, then sent from its card', (tester) async {
      final (repo, _, _, _) = await openDetail(tester, 'app-sanjana');
      await tapKey(tester, 'detail-offer');
      await tester.enterText(find.byKey(_k('offer-amount')), '1850000');
      await tapKey(tester, 'offer-draft');
      expect(repo.offered.single.send, isFalse);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.descendant(of: find.byKey(_k('detail-stage')), matching: find.text('Interview')), findsOneWidget);

      await tapKey(tester, 'offer-send-draft-offer-100');
      expect(repo.calls, contains('sendOffer offer-100'));
      expect(find.text('Sent'), findsOneWidget);
      expect(find.descendant(of: find.byKey(_k('detail-stage')), matching: find.text('Offer')), findsOneWidget);
      expect(find.text('The offer was sent to Sanjana Pillai.'), findsOneWidget);
    });

    testWidgets('a draft offer is changed from its card, starting from what it said', (tester) async {
      final (repo, _, _, _) = await openDetail(tester, 'app-sanjana');
      await tapKey(tester, 'detail-offer');
      await tester.enterText(find.byKey(_k('offer-amount')), '1850000');
      await tapKey(tester, 'offer-draft');

      await tapKey(tester, 'offer-edit-offer-100');
      expect(find.text('Change the offer'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(_k('offer-amount'))).controller!.text, '1850000');
      await tester.enterText(find.byKey(_k('offer-amount')), '1900000');
      await tapKey(tester, 'offer-draft');
      expect(repo.calls, contains('updateOffer offer-100'));
      expect(find.text('₹19,00,000 / yr'), findsOneWidget);
    });

    testWidgets('a sent offer can be changed but not sent again', (tester) async {
      final (repo, _, _, _) = await openDetail(tester, 'app-ishita');
      await tapKey(tester, 'offer-edit-offer-app-ishita');
      expect(find.text('Change the offer'), findsOneWidget);
      expect(find.byKey(_k('offer-send')), findsNothing);
      expect(find.byKey(_k('offer-draft')), findsNothing);
      await tester.enterText(find.byKey(_k('offer-amount')), '2200000');
      await tapKey(tester, 'offer-save');
      expect(repo.calls, contains('updateOffer offer-app-ishita'));
      expect(repo.calls.where((c) => c.startsWith('sendOffer')), isEmpty);
    });

    testWidgets('the API\'s refusal stays in the sheet', (tester) async {
      final repo = SpyHiring();
      await openDetail(tester, 'app-sanjana', repo: repo);
      repo.failures['makeOffer'] = ApiError('This application already has an active offer.');
      await tapKey(tester, 'detail-offer');
      await tester.enterText(find.byKey(_k('offer-amount')), '1850000');
      await tapKey(tester, 'offer-send');
      expect(find.text('This application already has an active offer.'), findsOneWidget);
      expect(find.text('Make an offer'), findsWidgets);
    });

    testWidgets('the joining and reply-by dates can be taken off again', (tester) async {
      await openDetail(tester, 'app-sanjana');
      await tapKey(tester, 'detail-offer');
      await tester.ensureVisible(find.byKey(_k('offer-joining')));
      await tester.tap(find.byKey(_k('offer-joining')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byKey(_k('offer-joining-clear')), findsOneWidget);
      await tester.tap(find.byKey(_k('offer-joining-clear')));
      await tester.pump();
      expect(find.byKey(_k('offer-joining-clear')), findsNothing);

      await tester.tap(find.byKey(_k('offer-expires')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_k('offer-expires-clear')));
      await tester.pump();
      expect(find.byKey(_k('offer-expires-clear')), findsNothing);
    });
  });
}
