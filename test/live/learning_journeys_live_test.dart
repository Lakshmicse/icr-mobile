/// The Learning Center walked the way a person walks it: the REAL screens (no stand-ins for the other builders'
/// doors, no recording `openPaper`) on the LOCAL portal API, signed in as the seeded personas. The per-feature live
/// files prove each repository and one screen at a time; this file proves the screens are joined: a door of the hub
/// opens the real screen, a card on that screen opens the real next one, "Start" opens the real brief, the brief
/// the real exam, the exam the real result, and the result the real certificate.
///
/// Run with the API up (and `tool/seed/learning-jobs.ts`, `learning-study.ts`, `learning-flows.ts` in):
/// `flutter test test/live/learning_journeys_live_test.dart`.
///
/// What the journeys write, and why it stays:
///  * Pooja Professional sits a mock set (an attempt cannot be deleted through the API; the set has no attempt
///    limit, and her attempts only add up).
///  * The Exam Persona redeems ICR credits for a level and sits it twice (a miss, then the pass the key gives):
///    credits cannot be given back and an attempt cannot be deleted, which is why a throwaway account does it.
///    Running `tool/seed/learning-flows.ts` again resets her, so the journey runs from the start every time.
///  * A star on a flash card is taken back. Nothing else is written.
///
/// Pictures are left out (the client below blanks every image URL in the API's answers): a widget test cannot reach
/// the network for them, and what is on a card does not depend on them. Everything else is the real API.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/learning/learning_screen.dart';
import 'package:icr_mobile/features/learning/widgets/course_card.dart';
import 'package:icr_mobile/features/learning_assess/assessment_screen.dart';
import 'package:icr_mobile/features/learning_assess/mock_tests_screen.dart';
import 'package:icr_mobile/features/learning_assess/widgets/group_card.dart';
import 'package:icr_mobile/features/learning_assess/widgets/paper_card.dart';
import 'package:icr_mobile/features/learning_exam/api_exam_repository.dart';
import 'package:icr_mobile/features/learning_exam/brief_sheet.dart';
import 'package:icr_mobile/features/learning_exam/certificate_view.dart';
import 'package:icr_mobile/features/learning_exam/certificates_screen.dart';
import 'package:icr_mobile/features/learning_exam/exam_controller.dart';
import 'package:icr_mobile/features/learning_exam/exam_progress_store.dart';
import 'package:icr_mobile/features/learning_exam/exam_screen.dart';
import 'package:icr_mobile/features/learning_exam/exam_services.dart';
import 'package:icr_mobile/features/learning_exam/my_attempts_screen.dart';
import 'package:icr_mobile/features/learning_hub/learning_doors.dart';
import 'package:icr_mobile/features/learning_hub/learning_hub_screen.dart';
import 'package:icr_mobile/features/learning_hub/partner_courses_screen.dart';
import 'package:icr_mobile/features/learning_hub/widgets/institute_card.dart';
import 'package:icr_mobile/features/learning_study/flash_cards_screen.dart';
import 'package:icr_mobile/features/learning_study/knowledge_center_screen.dart';
import 'package:icr_mobile/features/learning_study/study_models.dart';
import 'package:icr_mobile/features/learning_study/widgets/deck_card.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';
import 'live.dart';

/// One sign-in per person for the whole file: the API allows ten logins a minute from one address.
final _clients = <String, Future<ApiClient>>{};

Future<ApiClient> _as(LivePerson who) => _clients[who.email] ??= liveClient(who);

/// The keys whose string values are pictures; they come back blank so the screens draw their plates.
final _pictureKeys = RegExp(r'(image|logo|cover|photo|avatar|thumbnail|picture)', caseSensitive: false);

dynamic _withoutPictures(dynamic json) {
  if (json is List) return <dynamic>[for (final e in json) _withoutPictures(e)];
  if (json is Map) {
    return <String, dynamic>{
      for (final e in json.entries)
        e.key as String: e.value is String && _pictureKeys.hasMatch(e.key as String) ? null : _withoutPictures(e.value),
    };
  }
  return json;
}

/// A client for a screen: its own connection pool on the same sign-in (a socket opened under a widget test's fake
/// clock belongs to that clock's zone), a 429 waited out, and the pictures blanked.
ApiClient _screenClient(ApiClient signedIn) {
  final client = ApiClient(tokens: signedIn.tokens, baseUrl: liveBaseUrl);
  client.dio.interceptors.addAll([
    InterceptorsWrapper(
      onResponse: (response, handler) {
        final data = response.data;
        if (data is Map || data is List) response.data = _withoutPictures(data);
        handler.next(response);
      },
      onError: (error, handler) async {
        final tries = (error.requestOptions.extra['throttled'] as int?) ?? 0;
        if (error.response?.statusCode != 429 || tries >= 6) return handler.next(error);
        final wait = int.tryParse(error.response?.headers.value('retry-after') ?? '') ?? 6;
        await Future<void>.delayed(Duration(seconds: wait.clamp(2, 20)));
        error.requestOptions.extra['throttled'] = tries + 1;
        try {
          handler.resolve(await client.dio.fetch(error.requestOptions));
        } on DioException catch (again) {
          handler.next(again);
        }
      },
    ),
  ]);
  return client;
}

/// Pages of the website the app handed to the browser during the test.
final _urls = <String>[];

/// A live test that draws screens: skipped, with a reason, when the API is not running. It ends by letting
/// what is in flight finish and the HTTP client's idle timers fire, so no timer is left on the fake clock.
void journeyTest(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(
    description,
    (tester) async {
      if (await tester.runAsync(liveApiReachable) != true) {
        markTestSkipped('the local API is not running at $liveBaseUrl');
        return;
      }
      ExamServices.progress = MemoryExamProgressStore();
      addTearDown(ExamServices.reset);
      // The website is the browser's: a page the app hands over is recorded in [_urls], never opened.
      _urls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async {
          if (call.method == 'launch') _urls.add((call.arguments as Map)['url'] as String);
          return true;
        },
      );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          null,
        ),
      );
      await body(tester);
      await _settle(tester, until: () => find.byType(LinearProgressIndicator).evaluate().isEmpty);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    },
    tags: const ['live'],
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

/// Lets real network calls finish and the tree catch up. Plain pumps, never `pumpAndSettle`: while a page loads a
/// progress bar animates for ever, and settling it would run the fake clock past the requests' own timeouts.
Future<void> _settle(WidgetTester tester, {required bool Function() until, int rounds = 120}) async {
  for (var i = 0; i < rounds && !until(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

/// Waits until [finder] finds something, failing with [what] when it never does.
Future<void> _waitFor(WidgetTester tester, Finder finder, String what, {int rounds = 120}) async {
  await _settle(tester, until: () => finder.evaluate().isNotEmpty, rounds: rounds);
  expect(finder, findsWidgets, reason: 'waited for $what; on screen: ${_texts(tester)}');
}

/// Every line of text on screen, for a failure message.
String _texts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .where((t) => t.trim().isNotEmpty)
    .take(60)
    .join(' | ');

/// A tap whose handler talks to the network: it runs outside the test's fake clock.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.runAsync(() => tester.tap(finder.first));
  await tester.pump();
}

/// The arrow at the top left of the screen on top, once its page has finished sliding in; then the page below.
Future<void> _back(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.runAsync(() => tester.tap(find.byIcon(Symbols.arrow_back).first));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

/// The person `tool/seed/learning-study.ts` makes: a plan with three flash-card places, all taken by the first
/// three decks.
const studyPersona = LivePerson('study.cards@learning-study.icr.test', 'Study@12345', 'Study Persona');

/// The Exam Persona `tool/seed/learning-flows.ts` makes: a PROFESSIONAL with the signup credits and a plan that
/// opens nothing.
const examPersona = LivePerson('exam.sitter@learning-flows.icr.test', 'Exam@12345', 'Exam Persona');

/// A signed-in client, or null (the test is skipped, with the reason) when the persona is not in the database.
Future<ApiClient?> _tryAs(WidgetTester tester, LivePerson who) async {
  try {
    return await tester.runAsync(() => _as(who));
  } catch (_) {
    markTestSkipped('${who.label} (${who.email}) cannot sign in: run the seeds in tool/seed first');
    return null;
  }
}

/// The key to a paper, read from the newest sitting of it the person has: question id to right option indexes.
/// Null when they have never sat it.
Future<Map<String, List<int>>?> _keyFrom(ApiClient signedIn, String slug) async {
  final repo = ApiExamRepository(api: signedIn);
  final sat = [
    for (final a in await repo.attempts())
      if (a.paper?.slug == slug) a,
  ];
  if (sat.isEmpty) return null;
  sat.sort((a, b) => b.attempt.compareTo(a.attempt));
  final result = await repo.attempt(sat.first.id);
  return {for (final q in result.review) q.id: q.correctIndexes};
}

/// Answers the paper on screen from [key] (or leaves it blank when null) and sends it through the overview.
/// Ends on the result.
///
/// [answer] answers some of it by hand instead, from the screen's own controls, and may check the overview's counts
/// through [overview].
Future<void> _sit(
  WidgetTester tester, {
  Map<String, List<int>>? key,
  Future<void> Function(ExamController c)? answer,
  void Function(ExamController c)? overview,
}) async {
  await _waitFor(tester, find.byType(OptionTile), 'the first question');
  final c = tester.widget<ExamScreen>(find.byType(ExamScreen)).controller;
  if (answer != null) await answer(c);
  if (key != null) {
    for (var i = 0; i < c.total; i++) {
      expect(c.current, i, reason: 'on question ${i + 1}');
      final right = key[c.question.id];
      expect(right, isNotNull, reason: 'the key has question ${c.question.id}');
      for (final o in right!) {
        await tester.tap(find.byType(OptionTile).at(o));
        await tester.pump();
      }
      if (i < c.total - 1) {
        await tester.tap(find.text('Submit & Next'));
        await tester.pump(const Duration(milliseconds: 200));
      }
    }
    expect(c.counts.answered, c.total, reason: 'every question answered from the screen');
  }
  await tester.tap(find.text(key == null ? 'Finish' : 'Submit'));
  await tester.pump(const Duration(milliseconds: 400));
  await _waitFor(tester, find.text('Submit test'), 'the overview');
  await tester.pump(const Duration(milliseconds: 300));
  expect(
    find.textContaining('${c.counts.answered} answered, ${c.counts.skipped} skipped'),
    findsWidgets,
    reason: 'the overview counts what the screen holds',
  );
  overview?.call(c);
  await _tap(tester, find.text('Submit test'));
  await _waitFor(tester, find.text('Test Results'), 'the result');
  await tester.pump(const Duration(milliseconds: 500));
}

/// A paper's id by its slug, from the public list (a locked paper's own route is refused).
Future<String> _paperId(ApiClient api, String slug) async {
  for (final kind in ['MOCK', 'ASSESSMENT']) {
    final res = await api.dio.get<dynamic>('/learning/papers', queryParameters: {'kind': kind});
    for (final row in (res.data as List).cast<Map<String, dynamic>>()) {
      if (row['slug'] == slug) return row['id'] as String;
    }
  }
  throw StateError('no paper $slug');
}

/// What the API says the person holds: credits and the papers opened.
Future<Map<String, dynamic>> _unlocks(ApiClient api) async =>
    (await api.dio.get<Map<String, dynamic>>('/learning/me/paper-unlocks')).data!;

/// Waits, in real time, until what the API holds is [ready] (a request the screen made is still on its way).
Future<void> _eventually(WidgetTester tester, Future<bool> Function() ready) async {
  for (var i = 0; i < 40; i++) {
    if ((await tester.runAsync(ready)) == true) return;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The frames an animation needs: the first starts it, the others carry it to its end.
Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

/// The frames a closing sheet needs: it slides away on the first and is taken off the stack on the next.
Future<void> _closeSheet(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// The app's frame around a screen: the API client the screens read, a phone-width tall page.
Future<void> _pump(WidgetTester tester, ApiClient api, Widget home, {double heightDp = 2400}) async {
  tester.view.physicalSize = Size(780, heightDp * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Provider<ApiClient>.value(
      value: api,
      child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(), home: home),
    ),
  );
}

Finder _door(LearningDoor d) => find.byKey(ValueKey('door-${d.name}'));

void main() {
  setUpAll(loadAppFonts);

  journeyTest('the hub: every door opens its real screen with real content, and Back returns to the hub', (
    tester,
  ) async {
    final api = _screenClient((await tester.runAsync(() => _as(bharat)))!);
    await _pump(tester, api, LearningHubScreen(onBack: () {}));
    await _waitFor(tester, _door(LearningDoor.assessment), 'the doors');

    // door, the real screen it opens, and what shows once that screen has read the API
    final doors = <(LearningDoor, Type, Finder)>[
      (LearningDoor.assessment, AssessmentScreen, find.byType(GroupCard)),
      (LearningDoor.mockTests, MockTestsScreen, find.byType(GroupCard)),
      (LearningDoor.flashCards, FlashCardsScreen, find.byType(DeckCard)),
      (LearningDoor.knowledgeCenter, KnowledgeCenterScreen, find.textContaining(' formulas')),
      (LearningDoor.icrCourses, LearningScreen, find.byType(CourseCard)),
      (LearningDoor.partnerCourses, PartnerCoursesScreen, find.byType(InstituteCard)),
    ];
    for (final (door, screen, content) in doors) {
      await _tap(tester, _door(door));
      await _waitFor(tester, find.byType(screen), '${door.title}: its screen');
      await _waitFor(tester, content, '${door.title}: real content from the API');
      expect(find.byType(LearningHubScreen), findsNothing, reason: '${door.title}: the hub is under the new screen');
      await _back(tester);
      expect(find.byType(LearningHubScreen), findsOneWidget, reason: '${door.title}: Back returns to the hub');
    }

    // The two tiles of My learning that open other doors' screens.
    await _tap(tester, find.byKey(const ValueKey('my-learning-attempts')));
    await _waitFor(tester, find.byType(AttemptCard), 'his attempts, listed');
    await _back(tester);
    await _tap(tester, find.byKey(const ValueKey('my-learning-certificates')));
    await _waitFor(tester, find.byType(CertificateCard), 'his certificates, listed');
    await _back(tester);
    expect(find.byType(LearningHubScreen), findsOneWidget);
  });

  journeyTest(
    'Assess Your Knowledge, end to end (Exam Persona): a level is redeemed with credits, started, failed blank, '
    'retaken on the key, passed, and its certificate opens',
    (tester) async {
      final signed = await _tryAs(tester, examPersona);
      if (signed == null) return;
      const slug = 'compliance-and-standards-foundation';
      const paperId = 'cmv6luaqq00drmyt8ko9eh6fs';

      await _pump(tester, _screenClient(signed), AssessmentScreen(onBack: () {}));
      await _waitFor(tester, find.byType(GroupCard), 'the programmes');
      await tester.enterText(find.byType(TextField), 'compliance');
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(GroupCard, 'Compliance and Standards'));
      await _waitFor(tester, find.byType(PaperCard), 'the levels');
      await _settle(tester, until: () => find.byType(LinearProgressIndicator).evaluate().isEmpty);
      final card = find.byKey(const ValueKey('paper-$paperId'));
      expect(card, findsOneWidget, reason: 'the Foundation level');

      // Locked until credits are spent (a later run finds it open, and spends nothing).
      final redeem = find.descendant(of: card, matching: find.textContaining('Redeem'));
      if (redeem.evaluate().isNotEmpty) {
        final held =
            (await tester.runAsync(
                  () => signed.dio.get<Map<String, dynamic>>('/learning/me/paper-unlocks'),
                ))!.data!['icrCredits']
                as int;
        await _tap(tester, redeem);
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.textContaining('This level opens for good'), findsOneWidget, reason: 'it asks before it spends');
        await _tap(tester, find.descendant(of: find.byType(BottomSheet), matching: find.textContaining('Redeem')));
        await _settle(
          tester,
          until: () => find.descendant(of: card, matching: find.text('Unlocked')).evaluate().isNotEmpty,
        );
        final left =
            (await tester.runAsync(
                  () => signed.dio.get<Map<String, dynamic>>('/learning/me/paper-unlocks'),
                ))!.data!['icrCredits']
                as int;
        expect(left, lessThan(held), reason: 'the API took the credits');
        expect(find.textContaining('credit'), findsWidgets, reason: 'a snackbar says what was spent');
        // The snackbar is the app's, not the screen's: it would sit over the next screens' bottom bars for 4 s.
        await tester.pump(const Duration(seconds: 6));
      }
      expect(find.descendant(of: card, matching: find.text('Unlocked')), findsOneWidget);

      // Start -> the real brief.
      await _tap(tester, find.descendant(of: card, matching: find.byType(ActionButton)).last);
      final take = find.descendant(
        of: find.byType(BriefBar),
        matching: find.textContaining(RegExp(r'^(Take|Retake) test$')),
      );
      await _waitFor(tester, take, 'the brief, ready to start');
      expect(find.text('Test parameters'), findsOneWidget);

      // The key is read from the Exam Persona's earlier sittings; a first-ever sitting is sat blank to get it.
      Map<String, List<int>>? key = await tester.runAsync<Map<String, List<int>>?>(() => _keyFrom(signed, slug));
      await _tap(tester, take);
      await _waitFor(tester, find.byType(ExamScreen), 'the exam');
      if (key == null) {
        await _sit(tester);
        expect(find.text('Not quite there yet'), findsOneWidget, reason: 'a blank sitting fails a certifying paper');
        expect(find.textContaining('Certificate issued'), findsNothing);
        key = await tester.runAsync<Map<String, List<int>>?>(() => _keyFrom(signed, slug));
        expect(key, isNotNull, reason: 'the failed sitting shows the key');
        // Retake -> the brief again -> the exam again.
        await _tap(tester, find.text('Retake test'));
        await _waitFor(tester, take, 'the brief again');
        await _tap(tester, take);
        await _waitFor(tester, find.byType(ExamScreen), 'the exam again');
      }
      await _sit(tester, key: key);

      // The pass: the result, the certificate, and the level it earned.
      expect(find.text('Outstanding result'), findsOneWidget);
      expect(find.text('Passed'), findsWidgets);
      expect(find.textContaining('Certificate issued: ICR-'), findsOneWidget);
      await _tap(tester, find.text('View certificate').first);
      await _waitFor(tester, find.byType(CertificateSheetView), 'the certificate');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tapAt(const Offset(195, 12)); // the barrier above the sheet
      await _closeSheet(tester);
      expect(find.byType(CertificateSheetView), findsNothing, reason: 'the certificate sheet closed');

      // Retake on the result opens the brief again, ready for another sitting (closing it ends the flow).
      await _tap(tester, find.text('Retake Test').last);
      await _waitFor(tester, take, 'the brief again, after Retake');
      await tester.tapAt(const Offset(195, 12));
      await _closeSheet(tester);

      // Back on the programme: the level now says it earned the certificate and how the person did.
      await _settle(tester, until: () => find.text('CERTIFIED').evaluate().isNotEmpty);
      expect(find.descendant(of: card, matching: find.text('CERTIFIED')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.textContaining('Best score')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Passed')), findsOneWidget);
    },
  );

  journeyTest(
    'Mock Exams, end to end (Pooja): a subject, its sets (one held, one to redeem), a set started, a multiple-choice '
    'question answered, the result, and the new sitting counted',
    (tester) async {
      final signed = (await tester.runAsync(() => _as(pooja)))!;
      final api = _screenClient(signed);
      final set1 = (await tester.runAsync(() => _paperId(signed, 'ashrae-bemp-set-1')))!;
      final set2 = (await tester.runAsync(() => _paperId(signed, 'ashrae-bemp-set-2')))!;
      final held = (await tester.runAsync(() => _unlocks(signed)))!;
      expect((held['paperIds'] as List), contains(set1), reason: 'Pooja holds Set 1 (the exam live test sits it)');
      final before = (await tester.runAsync(
        () => ApiExamRepository(api: signed).attempts(),
      ))!.where((a) => a.paperId == set1).length;

      await _pump(tester, api, MockTestsScreen(onBack: () {}));
      await _waitFor(tester, find.byType(GroupCard), 'the subjects');
      await tester.enterText(find.byType(TextField), 'ashrae');
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(GroupCard, 'ASHRAE BEMP'));
      await _waitFor(tester, find.byType(PaperCard), 'the sets');
      await _settle(tester, until: () => find.byType(LinearProgressIndicator).evaluate().isEmpty);

      // Set 2 is closed to her: it offers her credits, asks before it spends them, and Cancel spends nothing.
      final closed = find.byKey(ValueKey('paper-$set2'));
      expect(closed, findsOneWidget);
      final redeem = find.descendant(of: closed, matching: find.textContaining('Redeem'));
      expect(redeem, findsOneWidget, reason: 'a closed set offers her credits');
      expect(find.descendant(of: closed, matching: find.textContaining('You have')), findsOneWidget);
      await _tap(tester, redeem);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('This set opens for good'), findsOneWidget, reason: 'it asks first');
      await _tap(tester, find.widgetWithText(ActionButton, 'Cancel'));
      await _closeSheet(tester);
      expect(find.textContaining('This set opens for good'), findsNothing);
      final after = (await tester.runAsync(() => _unlocks(signed)))!;
      expect(after['icrCredits'], held['icrCredits'], reason: 'Cancel spent nothing');
      expect(after['paperIds'], held['paperIds']);

      // Set 1 is hers: Start opens the real brief, then the exam.
      final open = find.byKey(ValueKey('paper-$set1'));
      await _tap(tester, find.descendant(of: open, matching: find.byType(ActionButton)).last);
      final take = find.descendant(
        of: find.byType(BriefBar),
        matching: find.textContaining(RegExp(r'^(Take|Retake) test$')),
      );
      await _waitFor(tester, take, 'the brief');
      expect(
        find.text('Mock exam'),
        findsWidgets,
        reason: 'the brief says what the paper is; on screen: ${_texts(tester)}',
      );
      await _tap(tester, take);
      await _waitFor(tester, find.byType(ExamScreen), 'the exam');

      await _sit(
        tester,
        answer: (c) async {
          // The first question: one option. The first multiple-choice question: three options.
          await tester.tap(find.byType(OptionTile).at(1));
          await tester.pump();
          final multiple = [
            for (final (i, q) in c.questions.indexed)
              if (q.multiple) i,
          ].first;
          while (c.current < multiple) {
            await tester.tap(find.text('Submit & Next'));
            await tester.pump(const Duration(milliseconds: 200));
          }
          expect(find.text('Select all that apply.'), findsOneWidget, reason: 'a multiple-choice question says so');
          for (final o in [3, 0, 1]) {
            await tester.tap(find.byType(OptionTile).at(o));
            await tester.pump();
          }
          expect(c.picked(c.question.id), [0, 1, 3], reason: 'the picks are kept, in order');
        },
        overview: (c) => expect(c.counts.answered, 2),
      );
      // A mock set is practice: it says what was scored, and never "Certificate".
      expect(find.textContaining(RegExp(r'^You scored \d+%$')), findsOneWidget);
      expect(find.textContaining('Certificate issued'), findsNothing);
      await _tap(tester, find.text('Back').last);
      await _closeSheet(tester);

      // The API kept the sitting, and the set's card counts it.
      final sat = (await tester.runAsync(
        () => ApiExamRepository(api: signed).attempts(),
      ))!.where((a) => a.paperId == set1).toList();
      expect(sat.length, before + 1, reason: 'one sitting, kept by the API');
      final count = find.descendant(of: open, matching: find.textContaining('${before + 1} attempt'));
      await _settle(tester, until: () => count.evaluate().isNotEmpty);
      expect(count, findsWidgets, reason: 'the header chip and the line under the score both count it');
    },
  );

  journeyTest(
    'Flash Cards, end to end (study persona, three deck places): a locked deck explains itself, an open deck is '
    'studied: flip, mark, star, the Starred pass, the summary, Study starred; the stars are taken back',
    (tester) async {
      final signed = await _tryAs(tester, studyPersona);
      if (signed == null) return;
      final stars = '/learning/me/resource-stars';
      Future<List<String>> starredIds() async {
        final res = await signed.dio.get<dynamic>(stars);
        return [for (final r in (res.data as List).cast<Map<String, dynamic>>()) r['id'] as String];
      }

      try {
        final api = _screenClient(signed);
        await _pump(tester, api, FlashCardsScreen(onBack: () {}), heightDp: 6000);
        await _waitFor(tester, find.byType(DeckCard), 'the decks');
        final decks = tester.widgetList<DeckCard>(find.byType(DeckCard)).toList();
        final locked = decks.where((d) => d.state == DeckState.locked).toList();
        final open = decks.where((d) => d.state == DeckState.open).toList();
        expect(open, isNotEmpty, reason: 'the three decks her places opened');
        expect(locked, isNotEmpty, reason: 'every other deck is locked by her plan');
        expect(find.byKey(const ValueKey('study-plan-note')), findsOneWidget);
        expect(find.textContaining('Your plan opens 3 flash-card decks'), findsOneWidget);

        // A locked deck still opens, and the API's own sentence says why; the plans page is a link.
        await _tap(tester, find.widgetWithText(DeckCard, locked.first.deck.title));
        await _waitFor(tester, find.text("This deck isn't open on your plan"), 'the lock notice');
        expect(find.textContaining('opened them all'), findsOneWidget, reason: "the API's sentence");
        await _tap(tester, find.text('See plans'));
        expect(_urls.last, endsWith('/pricing/professional'));
        await _tap(tester, find.text('All decks'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(DeckCard), findsWidgets, reason: 'back on the decks');

        // An open deck: the first card's question, a real flip to the answer, Got it moves on.
        final deck = open.first.deck;
        await _tap(tester, find.widgetWithText(DeckCard, deck.title));
        await _waitFor(tester, find.byKey(const ValueKey('study-position')), 'the first card');
        expect(find.text('1 of ${deck.cardCount}'), findsOneWidget);
        expect(find.text('Tap to see the answer'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('study-flip')));
        await _frames(tester);
        expect(find.text('ANSWER'), findsWidgets, reason: 'the card turned over');
        await tester.tap(find.byKey(const ValueKey('study-got-it')));
        await _frames(tester);
        expect(find.text('2 of ${deck.cardCount}'), findsOneWidget, reason: 'Got it moves to the next card');
        expect(find.byKey(const ValueKey('study-tally')), findsOneWidget);

        // Star this card and the next: the API keeps both, and the Starred chip appears.
        expect(await tester.runAsync(starredIds), isEmpty, reason: 'nothing starred to begin with');
        await _tap(tester, find.byKey(const ValueKey('study-star')));
        await _frames(tester);
        await tester.tap(find.byKey(const ValueKey('study-next')));
        await _frames(tester);
        await _tap(tester, find.byKey(const ValueKey('study-star')));
        await _frames(tester);
        await _eventually(tester, () async => (await starredIds()).length == 2);
        expect(await tester.runAsync(starredIds), hasLength(2), reason: "both stars are the API's");

        // The Starred pass is those two cards; Finish ends it with the summary.
        await tester.tap(find.byKey(const ValueKey('study-chip-starred')));
        await _frames(tester);
        expect(find.text('1 of 2'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('study-next')));
        await _frames(tester);
        expect(find.text('2 of 2'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('study-next')));
        await _frames(tester);
        expect(find.byKey(const ValueKey('study-summary')), findsOneWidget);
        expect(find.text('Deck complete'), findsOneWidget);
        expect(find.text('You went through 2 cards.'), findsOneWidget);
        await _tap(tester, find.byKey(const ValueKey('study-summary-back')));
        await _frames(tester);
        await _frames(tester);

        // The grid counts the stars and offers them as a pass of their own.
        await _settle(tester, until: () => find.textContaining('Study starred (2)').evaluate().isNotEmpty);
        expect(find.textContaining('Study starred (2)'), findsOneWidget);
        await _tap(tester, find.textContaining('Study starred (2)'));
        await _waitFor(tester, find.text('Starred cards'), 'the starred session');
        await _waitFor(tester, find.text('1 of 2'), 'the two starred cards');

        // Taking the stars back is the API's too.
        await _tap(tester, find.byKey(const ValueKey('study-star')));
        await _frames(tester);
        await tester.tap(find.byKey(const ValueKey('study-next')));
        await _frames(tester);
        await _tap(tester, find.byKey(const ValueKey('study-star')));
        await _frames(tester);
        await _eventually(tester, () async => (await starredIds()).isEmpty);
        expect(await tester.runAsync(starredIds), isEmpty, reason: 'both stars taken back');
      } finally {
        // Whatever happened above, leave the person with no stars.
        await tester.runAsync(() async {
          for (final id in await starredIds()) {
            await signed.dio.delete<dynamic>('$stars/$id');
          }
        });
      }
    },
  );
}
