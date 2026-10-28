import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/career/application_detail_screen.dart';
import 'package:icr_mobile/features/career/career_models.dart';
import 'package:icr_mobile/features/career/interviews_screen.dart';
import 'package:icr_mobile/features/career/invitations_screen.dart';
import 'package:icr_mobile/features/jobs/jobs_navigation.dart';

import 'career_fakes.dart';
import 'helpers/fonts.dart';
import 'jobs_fakes.dart';

/// "Interviews" and "Invitations", every control tapped. What the API does with the taps is proved
/// in `test/live/career_live_test.dart`.

final _now = DateTime(2026, 10, 26, 12);

CareerApplication app(
  String id, {
  String stage = 'INTERVIEW',
  List<CareerInterview> interviews = const [],
  String? company,
  String title = 'Facilities Manager',
}) => CareerApplication(
  id: id,
  jobId: 'job-$id',
  jobTitle: title,
  stage: stage,
  createdAt: DateTime(2026, 10, 10),
  companyName: company ?? 'Global Infra Solutions',
  city: 'Pune',
  interviews: interviews,
);

CareerInterview round(
  String id,
  int n,
  DateTime at, {
  InterviewMode mode = InterviewMode.video,
  String status = 'SCHEDULED',
  String? link,
  String? location,
  String? title,
}) => CareerInterview(
  id: id,
  round: n,
  scheduledAt: at,
  mode: mode,
  status: status,
  meetingLink: link,
  location: location,
  title: title,
  durationMins: 45,
);

/// Two upcoming rounds on two applications, one more on an archived application, and a
/// finished round on the first.
List<CareerApplication> interviewApps() => [
  app(
    'a1',
    interviews: [
      round(
        'r1',
        1,
        DateTime(2026, 10, 20, 11),
        status: 'COMPLETED',
        title: 'Screening call',
        mode: InterviewMode.phone,
      ),
      round('r2', 2, DateTime(2026, 10, 30, 15), link: 'https://meet.example.com/a1', title: 'Technical round'),
    ],
  ),
  app(
    'a2',
    title: 'Energy Manager',
    company: 'Northwind Facilities',
    interviews: [
      round('r3', 1, DateTime(2026, 10, 28, 10), mode: InterviewMode.inPerson, location: 'Tech Park, Pune 411057'),
    ],
  ),
  app('a3', stage: 'REJECTED', interviews: [round('r4', 1, DateTime(2026, 10, 27, 9))]),
];

Future<({SpyCareer repo, RecordingLinks links, List<String> conversations})> pumpInterviews(
  WidgetTester tester, {
  SpyCareer? repo,
  Size size = const Size(390, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final spy = repo ?? (SpyCareer(jobs: SpyJobsRepository(), now: _now)..applicationsAnswer = interviewApps());
  final links = RecordingLinks();
  final conversations = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: InterviewsScreen(
        key: UniqueKey(),
        repository: spy,
        links: links,
        clock: () => _now,
        navigation: JobsNavigation(onOpenConversation: conversations.add),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (repo: spy, links: links, conversations: conversations);
}

Future<({SpyCareer repo, RecordingLinks links, List<String> profiles})> pumpInvites(
  WidgetTester tester, {
  SpyCareer? repo,
  JobsNavigation navigation = JobsNavigation.none,
}) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final spy = repo ?? SpyCareer(jobs: SpyJobsRepository(), now: _now);
  final links = RecordingLinks();
  final profiles = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: InvitationsScreen(key: UniqueKey(), repository: spy, links: links, navigation: navigation),
    ),
  );
  await tester.pumpAndSettle();
  return (repo: spy, links: links, profiles: profiles);
}

void main() {
  setUpAll(loadAppFonts);

  group('interviews to come', () {
    testWidgets('lists every round still to happen, soonest first, across the applications', (tester) async {
      await pumpInterviews(tester);
      expect(find.text('Interviews'), findsOneWidget);
      expect(find.text('Upcoming 2'), findsOneWidget, reason: 'the archived application\'s round is not counted');
      final soonest = tester.getTopLeft(find.byKey(const ValueKey('interview-r3'))).dy;
      final later = tester.getTopLeft(find.byKey(const ValueKey('interview-r2'))).dy;
      expect(soonest, lessThan(later));
      expect(find.byKey(const ValueKey('interview-r4')), findsNothing);
      expect(find.byKey(const ValueKey('interview-r1')), findsNothing, reason: 'a finished round is under Past');
    });

    testWidgets('a round shows when, how long, how, which job and where', (tester) async {
      await pumpInterviews(tester);
      expect(find.text('Round 2 • Technical round'), findsOneWidget);
      expect(find.text('Fri 30 Oct, 3:00 PM • 45 min • Video call'), findsOneWidget);
      expect(find.text('Global Infra Solutions • Pune'), findsOneWidget);
      expect(find.text('Wed 28 Oct, 10:00 AM • 45 min • In person'), findsOneWidget);
      expect(find.text('Tech Park, Pune 411057'), findsOneWidget);
    });

    testWidgets('Join call opens the meeting; an in-person round opens the map', (tester) async {
      final rig = await pumpInterviews(tester);
      await tester.tap(find.byKey(const ValueKey('join-r2')));
      await tester.pump();
      expect(rig.links.opened.single.toString(), 'https://meet.example.com/a1');
      expect(find.byKey(const ValueKey('join-r3')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('map-r3')));
      await tester.pump();
      expect(rig.links.opened.last.host, 'www.google.com');
      expect(rig.links.opened.last.queryParameters['query'], 'Tech Park, Pune 411057');
    });

    testWidgets('Confirm tells the hiring team the member will attend, and opens the thread', (tester) async {
      final rig = await pumpInterviews(tester);
      await tester.tap(find.byKey(const ValueKey('confirm-r2')));
      await tester.pumpAndSettle();
      expect(rig.repo.log, contains('message job-a1'));
      expect(
        rig.repo.messages.single,
        'Hello, I confirm I will attend Technical round for Facilities Manager on Fri 30 Oct, 3:00 PM.',
      );
      expect(rig.conversations, ['conv-1']);
    });

    testWidgets('Ask for another time needs a proposal and sends it with the round named', (tester) async {
      final rig = await pumpInterviews(tester);
      await tester.tap(find.byKey(const ValueKey('reschedule-r3')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('another-time-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('another-time-send')));
      await tester.pumpAndSettle();
      expect(find.text('Say when you could do instead.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('another-time-text')), 'Thursday morning.');
      await tester.tap(find.byKey(const ValueKey('another-time-send')));
      await tester.pumpAndSettle();
      expect(rig.repo.messages.single, contains('I cannot make Round 1 for Energy Manager on Wed 28 Oct, 10:00 AM.'));
      expect(rig.repo.messages.single, endsWith('Thursday morning.'));
      expect(rig.conversations, ['conv-1']);
    });

    testWidgets('a message the API refuses says why and opens no thread', (tester) async {
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now)
        ..applicationsAnswer = interviewApps()
        ..messageError = ApiError('Messaging is off for this company.', statusCode: 403);
      final rig = await pumpInterviews(tester, repo: repo);
      await tester.tap(find.byKey(const ValueKey('confirm-r2')));
      await tester.pumpAndSettle();
      expect(find.text('Messaging is off for this company.'), findsOneWidget);
      expect(rig.conversations, isEmpty);
    });

    testWidgets('a card opens its application', (tester) async {
      await pumpInterviews(tester);
      await tester.tap(find.text('Energy Manager'));
      await tester.pumpAndSettle();
      expect(find.byType(ApplicationDetailScreen), findsOneWidget);
    });

    testWidgets('none to come: it says what would put one here', (tester) async {
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now)..applicationsAnswer = [app('a1', stage: 'APPLIED')];
      await pumpInterviews(tester, repo: repo);
      expect(find.byKey(const ValueKey('upcoming-empty')), findsOneWidget);
      expect(find.text('No interviews coming up'), findsOneWidget);
    });

    testWidgets('a list that cannot load says why, and Try again reads it again', (tester) async {
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now)
        ..applicationsAnswer = interviewApps()
        ..applicationsError = ApiError('The interviews are down.', statusCode: 500);
      await pumpInterviews(tester, repo: repo);
      expect(find.byKey(const ValueKey('interviews-error')), findsOneWidget);
      repo.applicationsError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('interview-r2')), findsOneWidget);
    });
  });

  group('interviews already held', () {
    testWidgets('Past reads each application whole, the first time it is opened, and lists the finished rounds', (
      tester,
    ) async {
      final rig = await pumpInterviews(tester);
      expect(rig.repo.log.where((l) => l.startsWith('application ')), isEmpty);
      await tester.tap(find.byKey(const ValueKey('interviews-tab-past')));
      await tester.pumpAndSettle();
      expect(rig.repo.log.where((l) => l.startsWith('application ')), isNotEmpty);
      expect(find.byKey(const ValueKey('interview-r1')), findsOneWidget);
      expect(find.text('Round 1 • Screening call'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      // A held round has no way in and nothing to confirm.
      expect(find.byKey(const ValueKey('join-r1')), findsNothing);
      expect(find.byKey(const ValueKey('confirm-r1')), findsNothing);
    });

    testWidgets('nothing held yet: it says so', (tester) async {
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now)..applicationsAnswer = [app('a1', stage: 'APPLIED')];
      await pumpInterviews(tester, repo: repo);
      await tester.tap(find.byKey(const ValueKey('interviews-tab-past')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('past-empty')), findsOneWidget);
    });
  });

  group('invitations', () {
    testWidgets('lists each invitation: the role, the company, who sent it and what they wrote', (tester) async {
      await pumpInvites(tester);
      expect(find.text('Invitations'), findsOneWidget);
      expect(find.byKey(const ValueKey('invite-inv-1')), findsOneWidget);
      expect(find.text('Senior Facilities Manager for STP Plant'), findsOneWidget);
      expect(find.text('CBRE South Asia • Mumbai'), findsOneWidget);
      expect(find.textContaining('Invited by Priya Sharma'), findsOneWidget);
      expect(find.text('“Your résumé is a strong fit. We would like you to apply.”'), findsOneWidget);
    });

    testWidgets('View & apply tells the recruiter it was seen and opens the job', (tester) async {
      final rig = await pumpInvites(tester);
      await tester.tap(find.byKey(const ValueKey('open-inv-1')));
      await tester.pumpAndSettle();
      expect(rig.repo.log, contains('invite inv-1 view'));
      expect(find.text('JOB DETAILS'), findsOneWidget);
    });

    testWidgets('an invitation already seen is not marked again, and says Viewed', (tester) async {
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now)
        ..invitesAnswer = [
          JobInvite(
            id: 'inv-9',
            jobId: 'demo-1',
            jobTitle: 'Procurement Lead',
            status: 'VIEWED',
            createdAt: DateTime(2026, 10, 20),
            companyName: 'Northwind Facilities',
            invitedBy: 'Rohit Rao',
          ),
        ];
      await pumpInvites(tester, repo: repo);
      expect(find.text('Viewed'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('open-inv-9')));
      await tester.pumpAndSettle();
      expect(repo.log.where((l) => l.startsWith('invite ')), isEmpty);
    });

    testWidgets('Decline asks first; keeping does nothing, declining removes it and tells the API', (tester) async {
      final rig = await pumpInvites(tester);
      await tester.tap(find.byKey(const ValueKey('decline-inv-1')));
      await tester.pumpAndSettle();
      expect(find.text('Decline this invitation?'), findsOneWidget);
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(rig.repo.log.where((l) => l.startsWith('invite ')), isEmpty);

      await tester.tap(find.byKey(const ValueKey('decline-inv-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('decline-invite-confirm')));
      await tester.pumpAndSettle();
      expect(rig.repo.log, contains('invite inv-1 decline'));
      expect(find.byKey(const ValueKey('invite-inv-1')), findsNothing);
      expect(find.byKey(const ValueKey('invites-empty')), findsOneWidget);
      expect(find.text('Invitation declined.'), findsOneWidget);
    });

    testWidgets('a refused decline puts the invitation back and says why', (tester) async {
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now)
        ..inviteError = ApiError('Invitation not found', statusCode: 404);
      await pumpInvites(tester, repo: repo);
      await tester.tap(find.byKey(const ValueKey('decline-inv-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('decline-invite-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Invitation not found'), findsOneWidget);
      expect(find.byKey(const ValueKey('invite-inv-1')), findsOneWidget);
    });

    testWidgets('the Open to opportunities switch tells the API, and a refusal puts it back', (tester) async {
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now);
      await pumpInvites(tester, repo: repo);
      Switch sw() => tester.widget<Switch>(find.byKey(const ValueKey('discoverable-switch')));
      expect(sw().value, isTrue);
      await tester.tap(find.byKey(const ValueKey('discoverable-switch')));
      await tester.pumpAndSettle();
      expect(repo.log, contains('discoverable false'));
      expect(sw().value, isFalse);

      repo.discoverableError = ApiError('Add a resume first.', statusCode: 400);
      await tester.tap(find.byKey(const ValueKey('discoverable-switch')));
      await tester.pumpAndSettle();
      expect(find.text('Add a resume first.'), findsOneWidget);
      expect(sw().value, isFalse, reason: 'put back to what it was');
    });

    testWidgets('with no résumé the switch waits and the page says how to get one', (tester) async {
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now)..noDiscoverable = true;
      final rig = await pumpInvites(tester, repo: repo);
      expect(tester.widget<Switch>(find.byKey(const ValueKey('discoverable-switch'))).onChanged, isNull);
      expect(find.byKey(const ValueKey('no-resume')), findsOneWidget);
      await tester.tap(find.text('Profile'));
      await tester.pump();
      expect(rig.links.paths, ['/profile']);
    });

    testWidgets('with the profile editor in the app wired, the Profile link opens it and not the website', (
      tester,
    ) async {
      var edits = 0;
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now)..noDiscoverable = true;
      final rig = await pumpInvites(
        tester,
        repo: repo,
        navigation: JobsNavigation(onEditProfile: () => edits++),
      );
      await tester.tap(find.text('Profile'));
      await tester.pump();
      expect(edits, 1);
      expect(rig.links.opened, isEmpty);
    });

    testWidgets('none yet: it says what brings one; an error says why and tries again', (tester) async {
      final repo = SpyCareer(jobs: SpyJobsRepository(), now: _now)..invitesAnswer = const [];
      await pumpInvites(tester, repo: repo);
      expect(find.byKey(const ValueKey('invites-empty')), findsOneWidget);

      final broken = SpyCareer(jobs: SpyJobsRepository(), now: _now)
        ..invitesError = ApiError('Invitations are down.', statusCode: 500);
      await pumpInvites(tester, repo: broken);
      expect(find.byKey(const ValueKey('invites-error')), findsOneWidget);
      broken.invitesError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('invite-inv-1')), findsOneWidget);
    });
  });
}
