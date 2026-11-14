/// The panel's interview page (`InterviewBriefScreen`, the website's `/manage/interviews/:id`) against the LOCAL
/// portal API: what a panelist, a recruiter off the panel and a stranger read of a seeded round, and that the
/// scorecard's body is the one the API takes.
///
/// Nothing is written: the only submits are ones the API refuses after validating the body (a round that has
/// not started, a recruiter who is not on the panel), so the refusal's sentence is the proof the body was right.
///
/// Needs the seeds of `tool/seed` (`learning-jobs.ts`, then `career.ts`): Sanjana's round 1 is two days away and
/// Tejas's round 1 was three days ago, both with Meera alone on the panel, Tejas's scored by her.
@Tags(['live'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/jobs/employer/api_hiring_repository.dart';
import 'package:icr_mobile/features/jobs/employer/interview_brief_controller.dart';
import 'package:icr_mobile/features/jobs/employer/interview_brief_models.dart';
import 'package:icr_mobile/features/jobs/employer/interview_brief_screen.dart';

import '../helpers/fonts.dart';
import '../jobs_fakes.dart';
import 'career_live_support.dart';
import 'live.dart';

const meera = LivePerson('meera.iyer@career.icr.test', 'Career@12345', 'Meera Iyer');
const rohit = LivePerson('rohit.rao@career.icr.test', 'Career@12345', 'Rohit Rao');

/// A seeded round: `design-career-iv-<applicant>-<round>`.
String round(String who) => 'design-career-iv-$who-1';

Future<ApiHiringRepository> hiringAs(LivePerson who) async => ApiHiringRepository(api: await liveClient(who));

/// Sanjana's round, which the seed puts two days ahead of its own run: null, and the test skipped, once it has
/// started. A test that submits a scorecard to see it refused asks this first, so it can never score a round it
/// meant to find closed (4 Nov 2026: a seed four days old let one through, and it had to be deleted by hand).
Future<InterviewBrief?> roundToCome() async {
  final b = await (await hiringAs(meera)).interviewBrief(round('sanjana'));
  if (b.scheduledAt.isAfter(DateTime.now())) return b;
  markTestSkipped(
    "Sanjana's round (${b.scheduledAt}) has already started: the seed is more than two days old. "
    'Re-run tool/seed/career.ts.',
  );
  return null;
}

void main() {
  setUpAll(loadAppFonts);

  group('what the API sends is what the page reads', () {
    liveTest('a panelist reads a round whole: the candidate, the note, the round, screening', () async {
      final b = await (await hiringAs(meera)).interviewBrief(round('sanjana'));
      expect(b.application.applicantName, 'Sanjana Pillai');
      expect(b.application.jobTitle, isNotEmpty);
      expect(b.application.stage, 'INTERVIEW');
      expect(b.roundLabel, 'Round 1 · Operations round');
      expect(b.mode, 'VIDEO');
      expect(b.durationMins, 45);
      expect(b.status, 'SCHEDULED');
      expect(b.meetingLink, 'https://meet.example.com/northwind-ops-1');
      expect(b.notes, 'Probe the multi-site rota she ran at Embassy.');
      expect(b.panel, ['Meera Iyer']);
      expect(b.isPanelist, isTrue);
      expect(b.myScorecard, isNull);
      expect(b.panelScorecards, isEmpty);
      expect(b.earlierRounds, isEmpty);

      final answers = b.application.answers;
      expect(answers.map((a) => a.prompt), [
        'How many years have you run site operations?',
        'Can you work rotational shifts?',
      ]);
      expect(answers.map((a) => a.display), ['14 years', 'Yes']);
      expect(answers.first.mustHave, isTrue);
      expect(answers.every((a) => a.graded && a.meetsIdeal), isTrue);
      expect(answers.map((a) => a.needed), ['at least 6 years', 'Yes'], reason: 'the ideal answers, worded');
      expect(b.application.matchScore, 91);
      expect(b.teamNotes, isNotEmpty, reason: 'her stage moves and the team\'s note');
    });

    liveTest('a round already held and scored: the panelist\'s own scorecard comes back', () async {
      final b = await (await hiringAs(meera)).interviewBrief(round('tejas'));
      expect(b.roundLabel, 'Round 1 · Screening call');
      expect(b.status, 'COMPLETED');
      expect(b.mode, 'PHONE');
      expect(b.scheduledAt.isBefore(DateTime.now()), isTrue);
      final mine = b.myScorecard!;
      expect(mine.interviewer, 'Meera Iyer');
      expect(mine.rating, 4);
      expect(recommendationWord(mine.recommendation), 'Yes');
      expect(mine.strengths, contains('vendor management'));
      expect(mine.concerns, contains('statutory audit'));
      expect(b.panelScorecards, isEmpty, reason: 'no one else sits on it');
      expect(b.panelSubmittedCount, 0);
    });

    liveTest('the hiring team off the panel reads the panel\'s scorecards', () async {
      final b = await (await hiringAs(rohit)).interviewBrief(round('tejas'));
      expect(b.isPanelist, isFalse);
      expect(b.myScorecard, isNull);
      expect(b.panelScorecards.single.interviewer, 'Meera Iyer');
    });

    liveTest('someone with no part in the round is refused, in the page\'s words', () async {
      final c = InterviewBriefController(await hiringAs(pooja), round('sanjana'));
      await c.load();
      expect(c.brief, isNull);
      expect(c.error, "You are not on this interview's panel.");
      expect(c.canRetry, isFalse);

      final gone = InterviewBriefController(await hiringAs(meera), 'design-career-iv-nobody-9');
      await gone.load();
      expect(gone.error, 'This interview no longer exists.');
      expect(gone.canRetry, isFalse);
    });
  });

  group('the scorecard\'s body is the one the API takes (nothing is written)', () {
    const card = ScorecardDraft(rating: 4, recommendation: 'YES', strengths: 'MOBILE-LIVE', concerns: 'MOBILE-LIVE');

    liveTest('a round that has not started refuses it for that reason alone', () async {
      final b = await roundToCome();
      if (b == null) return;
      expect(b.isPanelist, isTrue);
      expect(b.myScorecard, isNull);
      await expectLater(
        (await hiringAs(meera)).submitScorecard(b.id, card),
        throwsA(
          isA<ApiError>()
              .having((e) => e.statusCode, 'status', 400)
              .having((e) => e.message, 'message', 'The scorecard opens after the interview starts.'),
        ),
      );
    });

    liveTest('a recruiter who is not on the panel cannot score it', () async {
      // Refused before the round's time is looked at: the API checks the panel first.
      expect((await (await hiringAs(rohit)).interviewBrief(round('tejas'))).isPanelist, isFalse);
      await expectLater(
        (await hiringAs(rohit)).submitScorecard(round('tejas'), card),
        throwsA(
          isA<ApiError>()
              .having((e) => e.statusCode, 'status', 403)
              .having((e) => e.message, 'message', 'Only assigned interviewers can submit feedback.'),
        ),
      );
    });

    liveTest('a body without a recommendation is refused by the API\'s validation, as the form refuses it', () async {
      const half = ScorecardDraft(rating: 4);
      expect(half.ready, isFalse);
      expect(half.toJson()['recommendation'], isNull, reason: 'refused by the DTO before the service runs');
      await expectLater(
        (await hiringAs(meera)).submitScorecard(round('sanjana'), half),
        throwsA(
          isA<ApiError>()
              .having((e) => e.statusCode, 'status', 400)
              .having((e) => e.message, 'message', isNot('The scorecard opens after the interview starts.')),
        ),
      );
    });
  });

  group('the screen over the API', () {
    testWidgets('a scored round reads "Feedback Submitted" with the panelist\'s scorecard', tags: const ['live'], (
      tester,
    ) async {
      if (!await liveScreenReady(tester)) return;
      final repo = await tester.runAsync(() => hiringAs(meera));
      await pumpLive(
        tester,
        InterviewBriefScreen(repository: repo!, interviewId: round('tejas'), links: RecordingLinks()),
        size: const Size(390, 3200),
      );
      await settleLive(tester);
      expect(find.byKey(const ValueKey('brief-name')), findsOneWidget);
      expect(find.text('Round 1 · Screening call'), findsOneWidget);
      expect(find.byKey(const ValueKey('scorecard-submitted')), findsOneWidget);
      expect(find.byKey(const ValueKey('scorecard-form')), findsNothing);
      expect(find.textContaining('vendor management'), findsOneWidget);
      await finishLive(tester);
    });

    testWidgets(
      'an unscored round: the scorecard waits for the start (Join meeting offered), then opens; nothing is sent',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        final repo = await tester.runAsync(() => hiringAs(meera));
        final b = await tester.runAsync(() => repo!.interviewBrief(round('sanjana')));
        expect(b!.myScorecard, isNull, reason: 'the seed leaves it unscored');
        await pumpLive(
          tester,
          InterviewBriefScreen(repository: repo!, interviewId: b.id, links: RecordingLinks()),
          size: const Size(390, 3200),
        );
        await settleLive(tester);
        expect(find.text('Notes for the Panel'), findsOneWidget);
        expect(find.text('91%'), findsOneWidget);
        if (b.scheduledAt.isAfter(DateTime.now())) {
          expect(find.byKey(const ValueKey('scorecard-not-yet')), findsOneWidget);
          expect(find.byKey(const ValueKey('brief-join')), findsOneWidget);
        } else {
          // The seed is more than two days old: the round has started, so the scorecard is open.
          expect(find.byKey(const ValueKey('scorecard-form')), findsOneWidget);
          final submit = tester.widget<FilledButton>(find.byKey(const ValueKey('scorecard-submit')));
          expect(submit.onPressed, isNull, reason: 'nothing rated yet; and this test never presses it');
          expect(find.byKey(const ValueKey('brief-join')), findsNothing, reason: 'the website offers it only before');
        }
        await finishLive(tester);
      },
    );
  });
}
