import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/library/widgets/document_viewer_screen.dart';
import 'package:icr_mobile/features/jobs/employer/interview_brief_models.dart';
import 'package:icr_mobile/features/jobs/employer/interview_brief_screen.dart';
import 'package:icr_mobile/features/jobs/employer/resume_viewer.dart';

import 'helpers/fonts.dart';
import 'hiring_fakes.dart';
import 'jobs_fakes.dart' show RecordingLinks;

/// The panel's interview page (`/manage/interviews/:id` on the website), which an `interview.panel`
/// notification opens. It was the website's page in the app's web view until 4 Nov 2026, when the owner met
/// `/robots.txt` on a black page going back from it.
void main() {
  setUpAll(loadAppFonts);

  group('InterviewBrief.fromJson reads the API\'s brief (`toInterviewBrief`)', () {
    final json = <String, dynamic>{
      'id': 'iv-2',
      'applicationId': 'app-1',
      'round': 2,
      'title': 'Operations panel',
      'scheduledAt': '2026-11-05T09:30:00.000Z',
      'durationMins': 45,
      'mode': 'IN_PERSON',
      'location': 'Tower B, 4th floor, Pune',
      'meetingLink': null,
      'mapLink': null,
      'status': 'SCHEDULED',
      'notes': 'Ask about the night shift handover.',
      'interviewers': [
        {'id': 'u1', 'firstName': 'Meera', 'lastName': 'Iyer', 'email': 'm@x.in'},
        {'id': 'u2', 'firstName': 'Rohit', 'lastName': 'Rao'},
      ],
      'createdAt': '2026-11-01T09:30:00.000Z',
      'application': {
        'id': 'app-1',
        'stage': 'INTERVIEW',
        'appliedAt': '2026-10-28T09:30:00.000Z',
        'coverNote': '  ',
        'linkedinUrl': 'https://www.linkedin.com/in/asha',
        'resumeUrl': '/uploads/private/resumes/asha.DOCX',
        'applicant': {'id': 'p1', 'firstName': 'Asha', 'lastName': 'Menon', 'avatarUrl': null},
        'resume': {
          'headline': 'Facilities head',
          'skills': ['CAFM', 'Vendor SLAs'],
          'experienceYears': 9,
          'currentLocation': 'Pune',
        },
        'job': {'id': 'j1', 'title': 'Facilities Operations Lead'},
        'answers': [
          {'prompt': 'Years running sites?', 'type': 'YEARS', 'answer': '15', 'meetsIdeal': true, 'mustHave': true, 'graded': true, 'idealAnswer': '5'},
          {'prompt': 'Rate your Excel', 'type': 'RATING', 'scaleMax': 10, 'answer': '7', 'meetsIdeal': false, 'mustHave': false, 'graded': true, 'idealAnswer': '8'},
          {'prompt': 'Join by', 'type': 'DATE', 'answer': '2026-12-01', 'meetsIdeal': true, 'mustHave': false, 'graded': true, 'idealAnswer': '2026-12-15'},
          {'prompt': 'Anything else?', 'type': 'TEXT', 'answer': 'No', 'meetsIdeal': false, 'mustHave': false, 'graded': false},
        ],
        'qualification': {'met': 2, 'total': 3, 'qualified': false, 'autoArchived': false},
        'matchScore': null,
        'screeningSignals': [],
        'aiSummary': null,
        'screenedAt': '2026-10-28T10:00:00.000Z',
      },
      'isPanelist': true,
      'myScorecard': null,
      'panelScorecards': [],
      'panelSubmittedCount': 2,
      'earlierRounds': [
        {
          'id': 'iv-1',
          'round': 1,
          'title': null,
          'scheduledAt': '2026-11-01T09:30:00.000Z',
          'mode': 'PHONE',
          'status': 'COMPLETED',
          'interviewers': [
            {'id': 'u2', 'firstName': 'Rohit', 'lastName': 'Rao'},
          ],
          'scorecards': [
            {
              'id': 's1',
              'interviewer': null,
              'overallRating': 3,
              'recommendation': 'NEUTRAL',
              'strengths': null,
              'concerns': 'Notice period',
              'submittedAt': '2026-11-01T11:00:00.000Z',
            },
          ],
        },
      ],
      'teamNotes': [
        {'id': 'e1', 'type': 'STAGE_CHANGE', 'note': null, 'rating': null, 'toStage': 'INTERVIEW', 'author': null, 'createdAt': '2026-11-01T09:30:00.000Z'},
      ],
    };

    test('the round, the place and the panel', () {
      final b = InterviewBrief.fromJson(json);
      expect(b.roundLabel, 'Round 2 · Operations panel');
      expect(b.panel, ['Meera Iyer', 'Rohit Rao']);
      expect(b.address, 'Tower B, 4th floor, Pune');
      expect(b.mapUri.toString(), 'https://www.google.com/maps/search/?api=1&query=Tower+B%2C+4th+floor%2C+Pune');
      expect(b.isPanelist, isTrue);
      expect(b.panelSubmittedCount, 2);
      expect(b.earlierRounds.single.roundLabel, 'Round 1');
      expect(b.earlierRounds.single.scorecards.single.interviewer, isNull, reason: 'shown as "Former panelist"');
      expect(b.teamNotes.single.isStageChange, isTrue);
      expect(b.teamNotes.single.author, isNull, reason: 'shown as "Hiring team"');
    });

    test('the candidate, a blank cover note left out, and the résumé file\'s kind', () {
      final a = InterviewBrief.fromJson(json).application;
      expect(a.applicantName, 'Asha Menon');
      expect(a.facts, ['Facilities head', '9 yrs exp', 'Pune']);
      expect(a.coverNote, isNull);
      expect(resumeFileName(a.resumeUrl!), 'resume.docx');
      expect(a.unscorable, isTrue, reason: 'screened, with nothing to score');
      expect(a.qualified, isFalse);
    });

    test('answers and what each needed, in the website\'s words', () {
      final answers = InterviewBrief.fromJson(json).application.answers;
      expect([for (final a in answers) a.display], ['15+ years', '7 / 10', '1 Dec 2026', 'No']);
      expect([for (final a in answers) a.needed], ['at least 5 years', 'at least 8 / 10', 'on or before 15 Dec 2026', null]);
    });

    test('a scorecard is ready with a rating and a recommendation; blank words are not sent', () {
      expect(const ScorecardDraft(rating: 4).ready, isFalse);
      expect(const ScorecardDraft(recommendation: 'YES').ready, isFalse);
      const draft = ScorecardDraft(rating: 4, recommendation: 'YES', strengths: ' Calm ', concerns: '  ');
      expect(draft.ready, isTrue);
      expect(draft.toJson(), {'overallRating': 4, 'recommendation': 'YES', 'strengths': 'Calm'});
    });
  });

  group('InterviewBriefScreen', () {
    Future<SpyHiring> open(WidgetTester tester, {SpyHiring? repo, DateTime Function()? clock}) async {
      final hiring = repo ?? SpyHiring();
      await openOnPhone(
        tester,
        (context, links) =>
            InterviewBriefScreen(repository: hiring, interviewId: 'iv-9', links: links, clock: clock ?? hiringClock),
      );
      return hiring;
    }

    testWidgets('reads like the website\'s page: candidate, panel note, the round, screening, notes, rounds, scorecard', (
      tester,
    ) async {
      final repo = await open(tester);
      expect(repo.calls, contains('interviewBrief iv-9'));
      expect(find.byKey(const ValueKey('brief-name')), findsOneWidget);
      expect(find.text('Notes for the panel'), findsOneWidget);
      for (final heading in ['This interview', 'From screening', 'Hiring team notes', 'Earlier rounds', 'Your scorecard']) {
        expect(find.text(heading), findsOneWidget, reason: heading);
      }
      expect(find.text('Round 2 · Operations panel'), findsOneWidget);
      expect(find.text('Round 1 · Screening call'), findsOneWidget);
      expect(find.text('Employer questions'), findsOneWidget);
      expect(find.text('2 / 2 met'), findsOneWidget);
      expect(
        find.text('1 panelist has scored this round. You will see their scorecards once yours is in.'),
        findsOneWidget,
      );
    });

    testWidgets('the round has started: the scorecard opens, and goes in once rated and recommended', (tester) async {
      final repo = await open(tester);
      final submit = find.byKey(const ValueKey('scorecard-submit'));
      expect(tester.widget<FilledButton>(submit).onPressed, isNull, reason: 'a rating and a recommendation first');

      await tester.tap(find.byKey(const ValueKey('scorecard-star-4')));
      await tester.pump();
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('scorecard-rec-YES')));
      await tester.enterText(find.byKey(const ValueKey('scorecard-strengths')), 'Clear on escalation.');
      await tester.pump();
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(repo.calls, contains('submitScorecard iv-9 4 YES'));
      expect(find.byKey(const ValueKey('scorecard-submitted')), findsOneWidget);
      expect(find.byKey(const ValueKey('scorecard-form')), findsNothing);
      expect(find.text('The rest of the panel'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('scorecard-sc-meera')),
        findsOneWidget,
        reason: 'the other panelist\'s scorecard opens once yours is in',
      );
      expect(find.text('Clear on escalation.'), findsOneWidget);
    });

    testWidgets('before the round starts: no form yet, and Join meeting is offered', (tester) async {
      await open(tester, clock: () => hiringNow.subtract(const Duration(hours: 3)));
      expect(find.byKey(const ValueKey('scorecard-form')), findsNothing);
      expect(find.byKey(const ValueKey('scorecard-not-yet')), findsOneWidget);
      expect(find.byKey(const ValueKey('brief-join')), findsOneWidget);
    });

    testWidgets('Join meeting hands the meeting link to the phone', (tester) async {
      final links = await openOnPhone(
        tester,
        (context, links) => InterviewBriefScreen(
          repository: SpyHiring(),
          interviewId: 'iv-9',
          links: links,
          clock: () => hiringNow.subtract(const Duration(hours: 3)),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('brief-join')));
      await tester.pumpAndSettle();
      expect(links.opened.single.host, 'meet.google.com');
    });

    testWidgets('someone not on the panel is told so, with nothing to retry', (tester) async {
      await open(tester, repo: _Refusing(ApiError('Forbidden', statusCode: 403)));
      expect(find.text("You are not on this interview's panel."), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('a round that is gone says so', (tester) async {
      await open(tester, repo: _Refusing(ApiError('Interview not found', statusCode: 404)));
      expect(find.text('This interview no longer exists.'), findsOneWidget);
    });

    testWidgets('a dropped connection offers to try again', (tester) async {
      await open(tester, repo: _Refusing(ApiError('You appear to be offline.')));
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('opening the page tells the app it was seen', (tester) async {
      var seen = 0;
      await openOnPhone(
        tester,
        (context, links) => InterviewBriefScreen(
          repository: SpyHiring(),
          interviewId: 'iv-9',
          links: links,
          clock: hiringClock,
          onOpened: (_) => seen++,
        ),
      );
      expect(seen, 1);
    });
  });

  group('openApplicantResume: a résumé is a private upload, read with the session', () {
    Future<RecordingLinks> tapOpen(WidgetTester tester, _Files repo, String url) async {
      final links = await openOnPhone(
        tester,
        (context, links) => Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              key: const ValueKey('cv'),
              onPressed: () => openApplicantResume(c, repository: repo, url: url, links: links),
              child: const Text('cv'),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('cv')));
      await tester.pumpAndSettle();
      return links;
    }

    testWidgets('its bytes are drawn in the app\'s viewer; nothing goes to the phone\'s browser', (tester) async {
      final repo = _Files(bytes: utf8.encode('Sanjana Pillai\nFacilities head, 14 years'));
      final links = await tapOpen(tester, repo, 'http://localhost:3001/uploads/cv-1.txt');
      expect(repo.read, ['http://localhost:3001/uploads/cv-1.txt']);
      expect(find.byType(DocumentViewerScreen), findsOneWidget);
      expect(find.textContaining('Facilities head'), findsOneWidget);
      expect(links.opened, isEmpty);
    });

    testWidgets('a refusal says so and opens nothing', (tester) async {
      final repo = _Files(error: ApiError('Forbidden', statusCode: 403));
      final links = await tapOpen(tester, repo, 'http://localhost:3001/uploads/cv-1.pdf');
      expect(find.byType(DocumentViewerScreen), findsNothing);
      expect(find.text("Couldn't open the résumé. Try again."), findsOneWidget);
      expect(links.opened, isEmpty);
    });

    test('the viewer reads the kind from the stored name', () {
      expect(resumeFileName('/uploads/abc.PDF'), 'resume.pdf');
      expect(resumeFileName('http://localhost:3001/uploads/abc.docx?v=2'), 'resume.docx');
      expect(resumeFileName('/uploads/abc'), 'resume.pdf');
    });
  });
}

/// An employer source with files behind its links: [fileBytes] answers [bytes], or throws [error].
class _Files extends SpyHiring {
  _Files({this.bytes = const [], this.error});

  final List<int> bytes;
  final Object? error;
  final read = <String>[];

  @override
  Future<Uint8List> fileBytes(String url) async {
    read.add(url);
    if (error != null) throw error!;
    return Uint8List.fromList(bytes);
  }
}

/// An employer source whose interview page cannot be read.
class _Refusing extends SpyHiring {
  _Refusing(this.error);

  final ApiError error;

  @override
  Future<InterviewBrief> interviewBrief(String interviewId) async => throw error;
}
