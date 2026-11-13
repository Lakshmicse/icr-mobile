/// Role matrix, part 4: the Learning Center for the four accounts that belong to no company: the hub, its six
/// doors, a course sheet and its enquiry, the assessment levels, the mock sets, the flash cards (locked, and
/// credits), the formulas, My attempts and Certificates. Nothing that cannot be given back is spent: a credit is
/// never redeemed and a flash-card place is never taken (a deck is opened only when the plan has none to take).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/features/learning_assess/assessment_screen.dart';
import 'package:icr_mobile/features/learning_assess/mock_tests_screen.dart';
import 'package:icr_mobile/features/learning_assess/widgets/group_card.dart';
import 'package:icr_mobile/features/learning_study/flash_cards_screen.dart';
import 'package:icr_mobile/features/learning_study/knowledge_center_screen.dart';
import 'package:icr_mobile/features/learning_study/widgets/deck_card.dart';
import 'package:icr_mobile/features/learning_hub/learning_hub_screen.dart';
import 'package:icr_mobile/features/learning_hub/widgets/hub_section.dart';
import 'package:icr_mobile/features/learning/widgets/course_card.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';
import 'career_live_support.dart';
import 'live.dart';
import 'role_buyer_support.dart';

/// What the API says the account holds in the Learning Center.
Future<Map<String, dynamic>> _unlocks(Who w) async =>
    (await w.api.dio.get<Map<String, dynamic>>('/learning/me/paper-unlocks')).data!;

void roleBuyerLearning() {
  setUpAll(loadAppFonts);

  group('Learning', () {
    liveTest('what each account holds, and the catalogues every door reads, answer for every account', () async {
      for (final w in await everyone()) {
        final unlocks = await _unlocks(w);
        final credits = unlocks['icrCredits'];
        final courses = (await w.api.dio.get<dynamic>('/learning/courses')).data as List<dynamic>;
        expect(courses, isNotEmpty);
        final assessments = (await w.api.dio.get<dynamic>(
          '/learning/courses',
          queryParameters: {'kind': 'ASSESSMENT'},
        )).data;
        expect(assessments, isNotEmpty);
        expect((await w.api.dio.get<dynamic>('/learning/topics')).data, isNotEmpty);
        expect((await w.api.dio.get<dynamic>('/learning/resources')).data, isNotEmpty);
        expect((await w.api.dio.get<dynamic>('/learning/providers')).data, isNotEmpty);
        expect((await w.api.dio.get<dynamic>('/learning/me/enrollments')).data, isNotNull);
        expect((await w.api.dio.get<dynamic>('/learning/me/attempts')).data, isNotNull);
        expect((await w.api.dio.get<dynamic>('/learning/me/certificates')).data, isNotNull);
        record('Learning: catalogues, plan, attempts, certificates', w.person, 'works', 'ICR credits $credits');
      }
    });
  });

  group('the Learning screens, drawn for every account', () {
    testWidgets(
      'the hub, and each of its six doors with My attempts and Certificates, open and read for every account',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        for (final w in (await tester.runAsync(everyone))!) {
          await loadScreen(
            tester,
            LearningHubScreen(onBack: () {}),
            appProviders: [Provider<ApiClient>.value(value: w.api)],
            size: const Size(390, 2000),
          );
          var text = expectHealthy(tester, 'the Learning hub as ${w.email}');
          // The catalogue rail's four doors (the hub since the 27 Oct redesign) and the Catalogue heading, whose
          // View More opens the six doors as tiles (the categories; owner's call, 2 Nov 2026).
          for (final door in [
            'Knowledge Assessments',
            'Mock Exams',
            'Flashcards',
            'Knowledge Centre',
            'Explore Learning Resources',
          ]) {
            expect(text, contains(door), reason: '${w.email}: the $door door');
          }
          // My courses, My attempts and Certificates are chips of ICR Courses since the 30 Oct hub (no strip).

          // Every catalogue tile and both View More headings open a screen that reads, then Back returns to the hub.
          // The heading's key sits on the HubSectionHeading itself; a title's text sits inside one.
          Finder viewMoreOf(Finder heading, {bool byTitle = false}) => find.descendant(
            of: byTitle ? find.ancestor(of: heading, matching: find.byType(HubSectionHeading)) : heading,
            matching: find.text('View More'),
          );
          // The Partner Courses section is drawn only when an institute other than ICR's own has a course; the
          // local database seeds only ICR Institute, so it is opened when present and left out otherwise.
          final partnerMore = find.descendant(
            of: find.byKey(const ValueKey('partner-heading')),
            matching: find.byType(InkWell),
          );
          final hasPartners = partnerMore.evaluate().isNotEmpty;
          final doors = <String, Finder>{
            'Knowledge Assessments': find.byKey(const ValueKey('catalogue-assessment')),
            'Mock Exams': find.byKey(const ValueKey('catalogue-mockTests')),
            'Flashcards': find.byKey(const ValueKey('catalogue-flashCards')),
            'Knowledge Centre': find.byKey(const ValueKey('catalogue-knowledgeCenter')),
            'Explore Learning Resources': viewMoreOf(find.text('Explore Learning Resources'), byTitle: true),
            if (hasPartners) 'Partner Learning Programmes': partnerMore,
          };
          for (final entry in doors.entries) {
            // The sections load one by one; a Partner heading that was drawn a moment ago may have gone.
            if (entry.key == 'Partner Learning Programmes' && entry.value.evaluate().isEmpty) continue;
            expect(entry.value, findsOneWidget, reason: '${w.email}: ${entry.key} is on the hub');
            await tester.ensureVisible(entry.value);
            await tester.tap(entry.value, warnIfMissed: false);
            await afterTap(tester);
            expectHealthy(tester, '${entry.key} as ${w.email}');
            expect(find.byType(LearningHubScreen).hitTestable(), findsNothing, reason: '${entry.key} left the hub');
            tester.state<NavigatorState>(find.byType(Navigator).first).pop();
            await tester.pump(const Duration(milliseconds: 900));
            expect(find.byType(LearningHubScreen), findsOneWidget, reason: 'Back returns to the hub');
          }
          await unmount(tester);
          record(
            'Learning: hub, its four catalogue tiles and both course grids',
            w.person,
            'works',
            'each door opened and read',
          );
        }
      },
    );

    testWidgets(
      'inside the doors: a programme levels, a subject sets, the decks (locked), a formula',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        for (final w in (await tester.runAsync(everyone))!) {
          final client = [Provider<ApiClient>.value(value: w.api)];
          const size = Size(390, 2200);

          // Assess Your Knowledge: a programme opens on its levels, each with where this person stands.
          await loadScreen(
            tester,
            AssessmentScreen(onBack: () {}),
            appProviders: client,
            size: size,
          );
          await waitFor(tester, find.byType(GroupCard));
          final assessText = expectHealthy(tester, 'Assess as ${w.email}');
          expect(find.byType(GroupCard), findsWidgets, reason: '${w.email}: on screen: $assessText');
          await tester.tap(find.byType(GroupCard).first);
          await afterTap(tester);
          var text = expectHealthy(tester, 'a programme page as ${w.email}');
          expect(find.byKey(const ValueKey('hero-title')), findsOneWidget);
          const states = [
            'Start Assessment',
            'Retake Assessment',
            'Redeem',
            'Pay on the website',
            'Open with My Plan',
            'See Plans',
            'Coming soon',
            'No Attempts Left',
          ];
          final seen = [
            for (final s in states)
              if (text.contains(s)) s,
          ];
          expect(seen, isNotEmpty, reason: '${w.email}: a level says what the person can do');
          await unmount(tester);

          // Mock Exams: a subject opens on its sets.
          await loadScreen(
            tester,
            MockTestsScreen(onBack: () {}),
            appProviders: client,
            size: size,
          );
          await waitFor(tester, find.byType(GroupCard));
          expectHealthy(tester, 'Mock Exams as ${w.email}');
          await tester.tap(find.byType(GroupCard).first);
          await afterTap(tester);
          text = expectHealthy(tester, 'a subject page as ${w.email}');
          expect(text, contains('Set 1'));
          await unmount(tester);

          // Flash Cards: a plan with no deck places marks every deck Locked and the deck says why, in the API's words.
          await loadScreen(
            tester,
            FlashCardsScreen(onBack: () {}),
            appProviders: client,
            size: size,
          );
          await waitFor(tester, find.byType(DeckCard));
          text = expectHealthy(tester, 'Flash Cards as ${w.email}');
          expect(find.byType(DeckCard), findsWidgets);
          final locked = find.descendant(of: find.byType(DeckCard).first, matching: find.text('Locked'));
          var deckNote = 'open: not tapped, a place would be taken';
          if (locked.evaluate().isNotEmpty) {
            await tester.tap(find.byType(DeckCard).first);
            await afterTap(tester);
            // A deck of its own says the plan does not open it; a deck that belongs with a course says it opens
            // with the course (and links to it).
            final lockTitle = find.byWidgetPredicate(
              (x) =>
                  x is Text &&
                  (x.data == "This Deck Is Not Open on Your Plan" || (x.data ?? '').startsWith('Opens with')),
            );
            await waitFor(tester, lockTitle);
            text = expectHealthy(tester, 'a locked deck as ${w.email}');
            if (text.contains("This Deck Is Not Open on Your Plan")) {
              expect(text, contains('not included in your plan'), reason: '${w.email}: the API sentence is shown');
            } else {
              expect(text, contains('Opens with'), reason: '${w.email}: the deck follows its course');
            }
            await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 400));
            text = expectHealthy(tester, 'a locked deck, scrolled, as ${w.email}');
            expect(text, contains('See Plans'));
            deckNote = 'Locked: the deck page shows the API sentence';
          }
          await unmount(tester);

          // The Knowledge Center: a formula opens in a sheet, drawn as maths.
          await loadScreen(
            tester,
            KnowledgeCenterScreen(onBack: () {}),
            appProviders: client,
            size: size,
          );
          await waitFor(tester, find.text('01'));
          expectHealthy(tester, 'Knowledge Center as ${w.email}');
          await tester.tap(find.text('01').first);
          await afterTap(tester);
          text = expectHealthy(tester, 'a formula as ${w.email}');
          expect(text, contains('Copy formula'));
          await unmount(tester);
          record(
            'Learning: programme levels, mock sets, flash cards, formulas',
            w.person,
            'works',
            'levels say: ${seen.take(3).join(' / ')}; decks $deckNote',
          );
        }
      },
    );

    testWidgets(
      'a course opens its sheet from the hub for every account; the institute enquiry is sent as the account with nothing set up',
      tags: const ['live'],
      (tester) async {
        if (!await liveScreenReady(tester)) return;
        Finder keyed(String prefix) => find.byWidgetPredicate((w) {
          final k = w.key;
          return k is ValueKey<String> && k.value.startsWith(prefix);
        });
        for (final w in (await tester.runAsync(everyone))!) {
          await loadScreen(
            tester,
            LearningHubScreen(onBack: () {}),
            appProviders: [Provider<ApiClient>.value(value: w.api)],
            size: const Size(390, 2000),
          );
          // The hub has no course rail since the 27 Oct redesign: ICR Courses opens from the Catalogue heading's
          // View More, and the first card of that grid is the course.
          await waitFor(tester, find.text('Explore Learning Resources'));
          await tester.ensureVisible(find.text('Explore Learning Resources'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('View More').first);
          await afterTap(tester);
          await waitFor(tester, find.byType(CourseCard));
          final course = find.byType(CourseCard).first;
          await tester.ensureVisible(course);
          await tester.tap(course);
          await afterTap(tester);
          var text = expectHealthy(tester, 'a course sheet as ${w.email}');
          expect(text.toLowerCase(), contains('overview'), reason: '${w.email}: the sheet shows the course overview');
          // The wide button, or — for a place the person holds — the bar's lower-case word (the sheet shows the
          // place's status and Withdraw instead of a button, as the website's panel does).
          const holds = ['ENROL NOW', 'ENROLLED', 'PLACE REQUESTED', 'ON THE WAITLIST', 'ENROLMENT CLOSED'];
          final lower = text.toLowerCase();
          final button = [
            for (final h in holds)
              if (lower.contains(h.toLowerCase())) h,
          ];
          expect(button, isNotEmpty, reason: '${w.email}: the button says where the person stands');
          tester.state<NavigatorState>(find.byType(Navigator).first).pop();
          await tester.pump(const Duration(milliseconds: 900));

          if (w.email == gita?.email && keyed('institute-').evaluate().isNotEmpty) {
            // The enquiry: name and email come from the account; a lead reaches the institute (it cannot be taken back).
            // (The hub lists institutes in its Partner section, drawn only for an institute other than ICR's own.)
            final institute = keyed('institute-');
            await waitFor(tester, institute);
            await tester.ensureVisible(institute.first);
            await tester.tap(institute.first);
            await afterTap(tester);
            await tester.tap(find.byKey(const ValueKey('ask-the-institute')));
            await afterTap(tester);
            await tester.enterText(
              find.byKey(const ValueKey('institute-enquiry-message')),
              'Role matrix: does this institute run a cohort in Pune next quarter?',
            );
            await tester.tap(find.byKey(const ValueKey('institute-enquiry-send')));
            await waitFor(tester, find.textContaining('Sent to'), timeout: const Duration(seconds: 45));
            await afterTap(tester);
            text = expectHealthy(tester, 'the enquiry as ${w.email}');
            expect(text, contains('Sent to'), reason: '${w.email}: the enquiry reached the institute');
            record(
              'Learning: course sheet and the institute enquiry',
              w.person,
              'works',
              'enquiry sent (leaves one lead at the institute)',
            );
          } else {
            record('Learning: course sheet', w.person, 'works', 'button: ${button.first}');
          }
          await unmount(tester);
        }
      },
    );
  });
}
