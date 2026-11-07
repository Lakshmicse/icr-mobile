import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/auth/session_user.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/assistant/api_assistant_repository.dart';
import 'package:icr_mobile/features/assistant/assistant_controller.dart';
import 'package:icr_mobile/features/assistant/assistant_models.dart';
import 'package:icr_mobile/features/assistant/assistant_repository.dart';
import 'package:icr_mobile/features/assistant/assistant_screen.dart';
import 'package:icr_mobile/features/assistant/demo_assistant_repository.dart';

import 'helpers/fonts.dart';

/// Saathi in the app: the chips for where the person is, the API's stream read as the website reads it, the
/// conversation's rules, and the screen.
void main() {
  setUpAll(loadAppFonts);

  group('suggestionsFor: the chips for where the person is (the website\'s suggestionsEn)', () {
    test('a module page gets the module\'s own chips', () {
      expect(suggestionsFor(const AssistantContext(path: '/jobs')).map((s) => s.label), [
        'Browse jobs',
        'Job alerts',
        'Post a job',
      ]);
      expect(suggestionsFor(const AssistantContext(path: '/vendors')).map((s) => s.label).first, 'Request a quote');
      expect(suggestionsFor(const AssistantContext(path: '/community')).first.href, '/community/new');
      expect(suggestionsFor(const AssistantContext(path: '/mentorship/mentors/abc')).first.href, '/mentorship/mentors');
      expect(suggestionsFor(const AssistantContext(path: '/learning')).first.ask, isNotNull);
    });

    test('a member with no company is offered the doors a company opens', () {
      expect(suggestionsFor(const AssistantContext(path: '/', signedIn: true, hasCompany: false)).map((s) => s.label), [
        'Start selling',
        'Hire for a team',
        'Find a mentor',
        'Post a requirement',
      ]);
    });

    test("the doors' chips ask the website's questions (UNDECIDED_MEMBER_SUGGESTIONS) and open nothing themselves", () {
      final chips = suggestionsFor(const AssistantContext(path: '/', signedIn: true, hasCompany: false));
      expect(
        {for (final c in chips) c.label: c.ask},
        {
          'Start selling': 'How do I list my business?',
          'Hire for a team': 'How do I post a job?',
          'Find a mentor': 'How do I find a mentor?',
          'Post a requirement': 'How do I post a requirement?',
        },
      );
      expect(chips.every((c) => !c.isPage), isTrue, reason: 'the reply explains the step; it is not a link');
      // The same chips for a signed-in member whatever the role: the doors follow the company, not the hat.
      for (final role in ['PROFESSIONAL', 'VENDOR', 'BUYER']) {
        expect(
          suggestionsFor(
            AssistantContext(path: '/', signedIn: true, role: role, hasCompany: false),
          ).map((s) => s.label),
          ['Start selling', 'Hire for a team', 'Find a mentor', 'Post a requirement'],
          reason: role,
        );
      }
    });

    test('a member with a company, and a visitor', () {
      expect(suggestionsFor(const AssistantContext(path: '/', signedIn: true, hasCompany: true)).map((s) => s.label), [
        'What can I do on ICR?',
        'Find a mentor',
        'Dashboard',
        'Get help',
      ]);
      expect(suggestionsFor(const AssistantContext(path: '/', signedIn: false)).map((s) => s.label), [
        'What can I do on ICR?',
        'Find a job',
        'Request a quote',
        'Join free',
      ]);
    });

    test(
      'the chips follow the role (owner, 6 Nov 2026): a mentor\'s desk, a company\'s hiring, selling and buying',
      () {
        List<String> labels(AssistantContext c) => suggestionsFor(c).map((s) => s.label).toList();
        expect(labels(const AssistantContext(path: '/', signedIn: true, hasCompany: true, mentor: true)), [
          'What can I do on ICR?',
          'Mentor dashboard',
          'My offerings',
          'Get help',
        ]);
        expect(labels(const AssistantContext(path: '/', signedIn: true, hasCompany: true, role: 'COMPANY_ADMIN')), [
          'What can I do on ICR?',
          'Find a mentor',
          'Post a job',
          'Enquiries & RFQs',
          'Post a requirement',
          'Get help',
        ]);
        expect(labels(const AssistantContext(path: '/', signedIn: true, hasCompany: true, role: 'VENDOR')), [
          'What can I do on ICR?',
          'Find a mentor',
          'Enquiries & RFQs',
          'Post a requirement',
          'Get help',
        ]);
        expect(labels(const AssistantContext(path: '/', signedIn: true, hasCompany: true, role: 'BUYER')), [
          'What can I do on ICR?',
          'Find a mentor',
          'Post a requirement',
          'Get help',
        ]);
        expect(
          labels(const AssistantContext(path: '/', signedIn: true, hasCompany: true, role: 'RECRUITER')),
          contains('Post a job'),
        );
        // A mentor acting as themselves: the desk, then the doors a company opens.
        expect(
          labels(const AssistantContext(path: '/', signedIn: true, hasCompany: false, mentor: true)).first,
          'Mentor dashboard',
        );
        // A page a chip opens is the app's own screen.
        expect(
          suggestionsFor(
            const AssistantContext(path: '/', signedIn: true, hasCompany: true, mentor: true),
          ).firstWhere((s) => s.label == 'My offerings').href,
          '/mentorship/mentor?tab=services',
        );
      },
    );

    test('the module of a page is the longest root it starts with', () {
      expect(IcrModule.forPath('/career/alerts'), IcrModule.jobs);
      expect(IcrModule.forPath('/rfq/new'), IcrModule.supplierMart);
      expect(IcrModule.forPath('/councils/abc/'), IcrModule.chaptersCouncils);
      expect(IcrModule.forPath('/'), isNull);
      expect(IcrModule.forPath('/jobsboard'), isNull, reason: 'a root matches whole, never as a prefix of a word');
    });
  });

  group('ApiAssistantRepository reads POST /ai/chat as the website does', () {
    late _Api api;
    late ApiAssistantRepository repo;

    setUp(() {
      api = _Api();
      final client = ApiClient(tokens: _NoTokens(), baseUrl: 'http://api.test/api/v1');
      client.dio.httpClientAdapter = api;
      repo = ApiAssistantRepository(api: client);
    });

    Future<List<AssistantEvent>> ask(String text, [AssistantContext ctx = const AssistantContext(path: '/jobs')]) =>
        repo.ask([const AssistantMessage.assistant('hi'), AssistantMessage.user(text)], ctx).toList();

    test('the stream: words as they arrive, then the pages, until [DONE]', () async {
      api.stream = [
        'data: {"delta":"Open "}\n\n',
        'data: {"delta":"Jobs."}\n\ndata: {"actions":[{"label":"Browse jobs","href":"/jobs"}]}\n\n',
        'data: [DONE]\n\n',
      ];
      final events = await ask('where are the jobs?');
      expect(events.whereType<AssistantDelta>().map((e) => e.text).join(), 'Open Jobs.');
      expect(events.whereType<AssistantActions>().single.actions, [
        const QuickAction(label: 'Browse jobs', href: '/jobs'),
      ]);
      final sent = api.lastBody!;
      expect(sent['context'], {'path': '/jobs'});
      expect((sent['messages'] as List).map((m) => m['role']), ['assistant', 'user']);
      expect(api.lastAccept, 'text/event-stream');
    });

    test('a frame split across chunks is read whole', () async {
      api.stream = ['data: {"del', 'ta":"Hel', 'lo"}\n\ndata: [DONE]\n\n'];
      final events = await ask('hi');
      expect((events.single as AssistantDelta).text, 'Hello');
    });

    test('only the latest 20 messages go, role and content only', () async {
      api.stream = ['data: {"delta":"ok"}\n\ndata: [DONE]\n\n'];
      final history = [for (var i = 0; i < 30; i++) AssistantMessage.user('q$i', at: DateTime(2026))];
      await repo.ask(history, const AssistantContext()).toList();
      final messages = (api.lastBody!['messages'] as List).cast<Map>();
      expect(messages, hasLength(20));
      expect(messages.first, {'role': 'user', 'content': 'q10'});
      expect(messages.last.keys, ['role', 'content']);
    });

    test('an error frame after words keeps them; before any, the reply fails', () async {
      api.stream = ['data: {"delta":"Half "}\n\n', 'data: {"error":true}\n\n'];
      final events = await ask('hi');
      expect(events, hasLength(1));

      api.stream = ['data: {"error":true}\n\n'];
      await expectLater(ask('hi'), throwsA(isA<AssistantUnavailable>()));
    });

    test('rate-limited: the website\'s line, and no second request', () async {
      api.status = 429;
      final events = await ask('hi');
      expect((events.single as AssistantDelta).text, AssistantCopy.rateLimited);
      expect(api.calls, 1);
    });

    test('when the stream cannot be had, one JSON reply is asked for', () async {
      api.status = 503;
      api.json = {
        'reply': 'From JSON.',
        'actions': [
          {'label': 'Support', 'href': '/support'},
        ],
      };
      final events = await ask('hi');
      expect((events.first as AssistantDelta).text, 'From JSON.');
      expect((events.last as AssistantActions).actions.single.href, '/support');
      expect(api.calls, 2);
      expect(api.lastAccept, 'application/json');
    });

    test('a JSON body on the stream request is read as the reply', () async {
      api.streamType = 'application/json';
      api.stream = ['{"reply":"Plain.","actions":[]}'];
      final events = await ask('hi');
      expect((events.single as AssistantDelta).text, 'Plain.');
    });
  });

  group('AssistantController', () {
    final clock = DateTime(2026, 11, 6, 10, 30);

    test('opens with the greeting once; a question adds the turn and writes the reply in', () async {
      final demo = DemoAssistantRepository(delay: Duration.zero);
      final c = AssistantController(demo, clock: () => clock);
      c.open();
      c.open();
      expect(c.messages.map((m) => m.content), [AssistantCopy.greeting]);

      await c.send('How do I find a mentor?', const AssistantContext(path: '/mentorship'));
      expect(c.messages, hasLength(3));
      expect(c.messages[1].role, ChatRole.user);
      expect(c.messages[1].at, clock);
      expect(c.messages.last.content, contains('Find Mentors'));
      expect(c.messages.last.actions.map((a) => a.href), contains('/mentorship/mentors'));
      expect(c.streaming, isFalse);
      expect(demo.asked.single.context.path, '/mentorship');
    });

    test('a failed reply reads as "trouble responding"; a reply cut off midway keeps what it said', () async {
      final c = AssistantController(_Failing(after: const []));
      await c.send('hi', const AssistantContext());
      expect(c.messages.last.content, AssistantCopy.troubleResponding);

      final cut = AssistantController(_Failing(after: const [AssistantDelta('Some words')]));
      await cut.send('hi', const AssistantContext());
      expect(cut.messages.last.content, 'Some words');
    });

    test('a reply that stalls is given up on, and the composer is free again', () async {
      final c = AssistantController(_Stalling(), stall: const Duration(milliseconds: 20));
      await c.send('hi', const AssistantContext());
      expect(c.streaming, isFalse);
      expect(c.messages.last.content, AssistantCopy.troubleResponding);
    });

    test('a second send while one is in flight is ignored; the conversation is capped', () async {
      final slow = _Stalling();
      final c = AssistantController(slow, stall: const Duration(milliseconds: 50));
      final first = c.send('one', const AssistantContext());
      await c.send('two', const AssistantContext());
      expect(c.messages.where((m) => m.role == ChatRole.user).map((m) => m.content), ['one']);
      await first;

      final demo = AssistantController(DemoAssistantRepository(delay: Duration.zero));
      for (var i = 0; i < 20; i++) {
        await demo.send('hi $i', const AssistantContext());
      }
      expect(demo.messages.length, lessThanOrEqualTo(AssistantController.maxHistory + 1));
    });
  });

  group('AssistantScreen', () {
    const pooja = SessionUser(
      id: 'u1',
      email: 'p@icr.test',
      firstName: 'Pooja',
      lastName: 'Professional',
      role: 'PROFESSIONAL',
    );

    Future<(AssistantController, List<String>)> pump(
      WidgetTester tester, {
      AssistantContext context = const AssistantContext(path: '/jobs', signedIn: true, hasCompany: true),
      SessionUser? user = pooja,
      bool Function(String href)? opens,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = AssistantController(
        DemoAssistantRepository(delay: Duration.zero),
        clock: () => DateTime(2026, 11, 6, 10, 30),
      );
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: AssistantScreen(
            controller: c,
            context: context,
            user: user,
            onOpenPage: (_, href) => opened.add(href),
            opens: opens,
          ),
        ),
      );
      await tester.pump();
      return (c, opened);
    }

    testWidgets('opens on the greeting with the page\'s chips, on white, no boxes', (tester) async {
      await pump(tester);
      expect(find.text(assistantName), findsWidgets);
      expect(find.text(AssistantCopy.online), findsOneWidget);
      expect(find.textContaining("I'm Saathi"), findsOneWidget);
      expect(find.byKey(const ValueKey('suggestion-Browse jobs')), findsOneWidget);
      expect(find.byKey(const ValueKey('suggestion-Post a job')), findsOneWidget);
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, Colors.white);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('a typed question is sent, answered with its pages, and a page opens from its pill', (tester) async {
      final (c, opened) = await pump(tester);
      await tester.enterText(find.byKey(const ValueKey('assistant-input')), 'How do I find a mentor?');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('assistant-send')));
      await tester.pumpAndSettle();
      expect(find.text('You'), findsOneWidget);
      expect(find.text('How do I find a mentor?'), findsOneWidget);
      expect(find.text('10:30 AM'), findsWidgets);
      expect(find.textContaining('Find Mentors lists'), findsOneWidget);
      expect(c.messages, hasLength(3));
      await tester.tap(find.byKey(const ValueKey('action-/mentorship/mentors')));
      expect(opened, ['/mentorship/mentors']);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('assistant-input'))).controller!.text, isEmpty);
    });

    testWidgets('a page the app has no screen for is never offered: not as a chip, not under a reply (7 Nov 2026)', (
      tester,
    ) async {
      final (c, opened) = await pump(tester, opens: (href) => href == '/jobs');
      expect(find.byKey(const ValueKey('suggestion-Browse jobs')), findsOneWidget);
      expect(find.byKey(const ValueKey('suggestion-Post a job')), findsOneWidget, reason: 'a question, not a page');
      expect(find.byKey(const ValueKey('suggestion-Job alerts')), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('assistant-input')), 'How do I find a mentor?');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('assistant-send')));
      await tester.pumpAndSettle();
      expect(c.messages, hasLength(3));
      expect(find.textContaining('Find Mentors lists'), findsOneWidget, reason: 'the answer stays');
      expect(find.byKey(const ValueKey('action-/mentorship/mentors')), findsNothing);
      expect(find.byKey(const ValueKey('action-/mentorship/groups')), findsNothing);
      expect(opened, isEmpty);
    });

    testWidgets('a page chip opens the page; a question chip asks on the person\'s behalf', (tester) async {
      final (c, opened) = await pump(tester);
      // The chips sit under the latest reply (the greeting, to begin with).
      await tester.tap(find.byKey(const ValueKey('suggestion-Browse jobs')));
      expect(opened, ['/jobs']);
      await tester.tap(find.byKey(const ValueKey('suggestion-Post a job')));
      await tester.pumpAndSettle();
      expect(c.messages[1].content, 'How do I post a job?');
      expect(c.messages, hasLength(3));
    });

    testWidgets('Send stays off with nothing typed, and while a reply is being written (typing dots meanwhile)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final slow = _Held();
      final c = AssistantController(slow, stall: const Duration(minutes: 1));
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: AssistantScreen(
            controller: c,
            context: const AssistantContext(path: '/jobs'),
            onOpenPage: (_, _) {},
          ),
        ),
      );
      await tester.pump();
      InkWell send() => tester.widget<InkWell>(find.byKey(const ValueKey('assistant-send')));
      expect(send().onTap, isNull);
      await tester.enterText(find.byKey(const ValueKey('assistant-input')), 'hello');
      await tester.pump();
      expect(send().onTap, isNotNull);

      await tester.tap(find.byKey(const ValueKey('assistant-send')));
      await tester.pump();
      expect(send().onTap, isNull, reason: 'a reply is being written');
      expect(find.byKey(const ValueKey('assistant-typing')), findsOneWidget, reason: 'no words yet');

      slow.say('Here you go.');
      await tester.pump();
      expect(find.byKey(const ValueKey('assistant-typing')), findsNothing);
      expect(find.text('Here you go.'), findsOneWidget);
      slow.done();
      // The stream's end reaches the controller on the real clock, not through the fake one's pumps.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      expect(c.streaming, isFalse);
      expect(send().onTap, isNull, reason: 'the box is empty again');
    });

    testWidgets('a visitor\'s own rows carry a plain glyph, and a visitor\'s chips', (tester) async {
      final (c, _) = await pump(tester, user: null, context: const AssistantContext(path: '/', signedIn: false));
      // Sent outside the widget, so it runs on the real clock: the fake one would hold the reply's stream.
      await tester.runAsync(() => c.send('hi', const AssistantContext()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('You'), findsOneWidget);
      expect(find.text('PP'), findsNothing);
      expect(find.byKey(const ValueKey('suggestion-Join free')), findsOneWidget);
    });
  });
}

// ── fakes ────────────────────────────────────────────────────────────────────────────────────────────────────

class _NoTokens extends TokenStore {
  @override
  Future<String?> accessToken() async => null;
  @override
  Future<String?> refreshToken() async => null;
  @override
  Future<void> save({required String accessToken, required String refreshToken}) async {}
  @override
  Future<void> clear() async {}
}

/// Answers POST /ai/chat: an SSE stream of [stream] chunks (as [streamType]) when the Accept header asks for one,
/// a JSON body otherwise; [status] other than 200 refuses the stream request.
class _Api implements HttpClientAdapter {
  List<String> stream = const [];
  String streamType = 'text/event-stream';
  Map<String, dynamic>? json;
  int status = 200;
  int calls = 0;
  Map<String, dynamic>? lastBody;
  String? lastAccept;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    lastBody = (options.data as Map).cast<String, dynamic>();
    lastAccept = options.headers['Accept'] as String?;
    if (lastAccept == 'application/json') {
      return ResponseBody.fromString(
        jsonEncode(json ?? {}),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (status != 200) {
      return ResponseBody.fromString(
        '{"message":"no"}',
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody(
      Stream.fromIterable([for (final s in stream) Uint8List.fromList(utf8.encode(s))]),
      200,
      headers: {
        Headers.contentTypeHeader: [streamType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Says [after], then fails.
class _Failing implements AssistantRepository {
  const _Failing({required this.after});

  final List<AssistantEvent> after;

  @override
  Stream<AssistantEvent> ask(List<AssistantMessage> history, AssistantContext context) async* {
    yield* Stream.fromIterable(after);
    throw const AssistantUnavailable('down');
  }
}

/// Never answers: a stream that stays open and says nothing.
class _Stalling implements AssistantRepository {
  @override
  Stream<AssistantEvent> ask(List<AssistantMessage> history, AssistantContext context) =>
      StreamController<AssistantEvent>().stream;
}

/// Answers when told to: [say] a line, [done] to end the reply.
class _Held implements AssistantRepository {
  final _out = StreamController<AssistantEvent>();

  void say(String text) => _out.add(AssistantDelta(text));
  void done() => _out.close();

  @override
  Stream<AssistantEvent> ask(List<AssistantMessage> history, AssistantContext context) => _out.stream;
}
