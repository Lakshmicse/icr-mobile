import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/messaging/api_messaging_repository.dart';
import 'package:icr_mobile/features/messaging/conversation_screen.dart';
import 'package:icr_mobile/features/messaging/inbox_screen.dart';
import 'package:icr_mobile/features/messaging/messaging_launcher.dart';
import 'package:icr_mobile/features/messaging/messaging_models.dart';
import 'package:icr_mobile/features/messaging/messaging_repository.dart';
import 'package:icr_mobile/features/messaging/widgets/new_message_sheet.dart';
import 'package:icr_mobile/features/notifications/notification_router.dart';
import 'package:icr_mobile/features/notifications/notification_target.dart';
import 'package:icr_mobile/features/notifications/unread_counts.dart';
import 'package:provider/provider.dart';

import 'helpers/fonts.dart';
import 'messaging_fakes.dart';

/// Every way into Messages: the inbox, one thread by its id, and each
/// "Message" button (a person, a supplier by listing or by company, a company
/// page, a job's hiring contact, a pairing, a bought session, a group room, a
/// requirement's other side, an applicant), then "New message". The thread a
/// record's endpoint answers opens over the screen that asked; a refusal is the
/// API's own sentence and opens nothing. What each endpoint does for real:
/// `test/live/messaging_live_test.dart`.
void main() {
  setUpAll(loadAppFonts);

  late FakeMessagingRepository repo;
  late _Spy spy;

  FakeMessagingRepository withThread() => FakeMessagingRepository(
    rows: [convo('conv-started', last: msg('c1', 'conv-started', sarah, 'Hello Bharat', ago: 30))],
    threads: {
      'conv-started': [msg('c1', 'conv-started', sarah, 'Hello Bharat', ago: 30)],
    },
    contexts: {'conv-started': const ConversationContext(kind: ConversationKind.direct, person: sarah)},
  )..startAnswer = 'conv-started';

  /// An app with a button that runs [action] with its context, over whatever the providers hold.
  Future<BuildContext> pump(
    WidgetTester tester, {
    FakeMessagingRepository? repository,
    ApiClient? api,
    NotificationRouter? router,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo = repository ?? withThread();
    spy = _Spy();
    final counts = UnreadCounts(spy, interval: const Duration(hours: 1));
    addTearDown(counts.dispose);
    late BuildContext context;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UnreadCounts>.value(value: counts),
          Provider<NotificationRouter>.value(value: router ?? NotificationRouter()),
          if (api == null) Provider<MessagingRepository>.value(value: repo) else Provider<ApiClient>.value(value: api),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (c) {
              context = c;
              return const Scaffold(body: Center(child: Text('the page below')));
            },
          ),
        ),
      ),
    );
    return context;
  }

  /// The thread the launcher pushed, if one is on screen.
  ConversationScreen? threadOnScreen(WidgetTester tester) =>
      tester.widgetList<ConversationScreen>(find.byType(ConversationScreen)).firstOrNull;

  group('the inbox and a thread by its id', () {
    testWidgets('openInbox pushes Messages over the page; Back returns', (tester) async {
      final context = await pump(tester);
      unawaited(MessagingLauncher.openInbox(context));
      await tester.pumpAndSettle();
      expect(find.byType(InboxScreen), findsOneWidget);
      expect(tester.widget<InboxScreen>(find.byType(InboxScreen)).initialInbox, isNull);
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(InboxScreen), findsNothing);
      expect(find.text('the page below'), findsOneWidget);
    });

    testWidgets('openInbox(inbox:) opens on that company inbox', (tester) async {
      final context = await pump(tester);
      unawaited(MessagingLauncher.openInbox(context, inbox: 'co-acme'));
      await tester.pumpAndSettle();
      expect(tester.widget<InboxScreen>(find.byType(InboxScreen)).initialInbox, 'co-acme');
    });

    testWidgets('openConversation pushes the thread with its side, its focus and the row in hand', (tester) async {
      final context = await pump(tester);
      final row = convo('conv-started');
      unawaited(
        MessagingLauncher.openConversation(
          context,
          'conv-started',
          asCompanyId: 'co-acme',
          focusMessageId: 'c1',
          initial: row,
        ),
      );
      await tester.pumpAndSettle();
      final screen = threadOnScreen(tester)!;
      expect(screen.conversationId, 'conv-started');
      expect(screen.asCompanyId, 'co-acme');
      expect(screen.focusMessageId, 'c1');
      expect(screen.initial, row);
    });

    testWidgets('a pushed screen still reaches the app-wide counts and the router (a route is outside the providers)', (
      tester,
    ) async {
      final router = NotificationRouter();
      final context = await pump(tester, router: router);
      unawaited(MessagingLauncher.openConversation(context, 'conv-started'));
      await tester.pumpAndSettle();
      final inside = tester.element(find.byType(ConversationScreen));
      expect(Provider.of<NotificationRouter>(inside, listen: false), same(router));
      expect(Provider.of<UnreadCounts?>(inside, listen: false), isNotNull);
      expect(Provider.of<MessagingRepository?>(inside, listen: false), same(repo));
      // Reading the thread told the app-wide badge.
      expect(spy.messageReads, greaterThan(0));
    });
  });

  group('each "Message" button opens its thread through the record\'s endpoint', () {
    Future<void> check(WidgetTester tester, Future<bool> Function(BuildContext) press, String call) async {
      final context = await pump(tester);
      final opened = press(context);
      await tester.pumpAndSettle();
      expect(await opened, isTrue);
      expect(
        repo.calls.where(
          (c) =>
              !c.startsWith('thread') &&
              !c.startsWith('context') &&
              !c.startsWith('markRead') &&
              !c.startsWith('viewerId'),
        ),
        [call],
      );
      expect(threadOnScreen(tester)!.conversationId, 'conv-started');
    }

    testWidgets('a person: their plain thread, reused when the two share one', (tester) async {
      await check(tester, (c) => MessagingLauncher.withPerson(c, 'sarah'), 'startWithPerson sarah message=null');
    });

    testWidgets('a person with a first message', (tester) async {
      await check(
        tester,
        (c) => MessagingLauncher.withPerson(c, 'sarah', message: 'Hello again'),
        'startWithPerson sarah message=Hello again',
      );
    });

    testWidgets('a supplier by its listing (its sales inbox answers)', (tester) async {
      await check(
        tester,
        (c) => MessagingLauncher.withSupplier(c, vendorId: 'v1'),
        'startWithSupplier v1 rfq=null message=null',
      );
    });

    testWidgets('a supplier about a requirement: the buying team\'s thread with it', (tester) async {
      await check(
        tester,
        (c) => MessagingLauncher.withSupplier(c, vendorId: 'v1', rfqId: 'R1', message: 'Can you quote?'),
        'startWithSupplier v1 rfq=R1 message=Can you quote?',
      );
    });

    testWidgets('a supplier known only by its company: the company\'s sales inbox', (tester) async {
      await check(
        tester,
        (c) => MessagingLauncher.withSupplier(c, companyId: 'co-care'),
        'startWithCompany co-care topic=SALES message=null',
      );
    });

    testWidgets('a company page, about a topic (careers, partnership…)', (tester) async {
      await check(
        tester,
        (c) => MessagingLauncher.withCompany(c, 'co-gi', topic: 'CAREERS'),
        'startWithCompany co-gi topic=CAREERS message=null',
      );
    });

    testWidgets('a company page with no topic is General', (tester) async {
      await check(
        tester,
        (c) => MessagingLauncher.withCompany(c, 'co-gi'),
        'startWithCompany co-gi topic=GENERAL message=null',
      );
    });

    testWidgets('a job: the hiring contact the API picks', (tester) async {
      await check(
        tester,
        (c) => MessagingLauncher.forJob(c, 'J1', message: 'Is this still open?'),
        'startWithJobContact J1 message=Is this still open?',
      );
    });

    testWidgets('a mentoring pairing', (tester) async {
      await check(tester, (c) => MessagingLauncher.forMentorship(c, 'M1'), 'openForMentorship M1');
    });

    testWidgets('a bought session or consultation', (tester) async {
      await check(tester, (c) => MessagingLauncher.forPurchase(c, 'P1'), 'openForPurchase P1');
    });

    testWidgets('a group session\'s room', (tester) async {
      await check(tester, (c) => MessagingLauncher.forGroupSession(c, 'G1'), 'openForGroupSession G1');
    });

    testWidgets('a requirement\'s other side: a supplier opens its own, the buying team names the supplier', (
      tester,
    ) async {
      await check(tester, (c) => MessagingLauncher.forRfq(c, 'R1'), 'openForRfq R1 supplier=null');
      await tester.pumpWidget(const SizedBox());
      await check(
        tester,
        (c) => MessagingLauncher.forRfq(c, 'R1', supplierCompanyId: 'co-care'),
        'openForRfq R1 supplier=co-care',
      );
    });

    testWidgets('an applicant (a recruiter\'s thread)', (tester) async {
      await check(tester, (c) => MessagingLauncher.forApplication(c, 'A1'), 'openForApplication A1');
    });
  });

  group('when the API refuses or is not reachable', () {
    testWidgets('its own sentence is shown, nothing opens, and the answer is false', (tester) async {
      final repository = withThread()
        ..errors['startWithJobContact'] = ApiError(
          'You cannot message the hiring contact of your own company\'s job.',
          statusCode: 400,
        );
      final context = await pump(tester, repository: repository);
      final result = MessagingLauncher.forJob(context, 'J1');
      await tester.pumpAndSettle();
      expect(await result, isFalse);
      expect(find.text("You cannot message the hiring contact of your own company's job."), findsOneWidget);
      expect(threadOnScreen(tester), isNull);
    });

    testWidgets('no connection: the plain sentence', (tester) async {
      final repository = withThread()
        ..errors['openForMentorship'] = ApiError("Can't reach ICR right now. Check your connection and try again.");
      final context = await pump(tester, repository: repository);
      final result = MessagingLauncher.forMentorship(context, 'M1');
      await tester.pumpAndSettle();
      expect(await result, isFalse);
      expect(find.text("Can't reach ICR right now. Check your connection and try again."), findsOneWidget);
    });

    testWidgets('a second tap while the first is on its way does nothing (one thread, not two)', (tester) async {
      final repository = withThread();
      final gate = Completer<void>();
      repository.holds['startWithPerson'] = gate;
      final context = await pump(tester, repository: repository);
      final first = MessagingLauncher.withPerson(context, 'sarah');
      await tester.pump();
      expect(await MessagingLauncher.withPerson(context, 'sarah'), isFalse);
      gate.complete();
      await tester.pumpAndSettle();
      expect(await first, isTrue);
      expect(repository.calls.where((c) => c.startsWith('startWithPerson')), hasLength(1));
      expect(find.byType(ConversationScreen), findsOneWidget);
    });

    testWidgets('a person who left the screen before the answer arrives is not pushed anything', (tester) async {
      final repository = withThread();
      final gate = Completer<void>();
      repository.holds['startWithPerson'] = gate;
      final context = await pump(tester, repository: repository);
      final result = MessagingLauncher.withPerson(context, 'sarah');
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      gate.complete();
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });
  });

  group('through the real API client (no repository provided above)', () {
    testWidgets('withPerson posts the people and the first message, and the answer\'s id opens the thread', (
      tester,
    ) async {
      final adapter = TableAdapter({
        'POST /messaging/conversations': (o) => {'id': 'conv-api', 'participants': [], 'messages': []},
        'GET /messaging/conversations/conv-api': (o) => {
          'id': 'conv-api',
          'participants': [],
          'messages': [],
          'hasMore': false,
        },
        'GET /messaging/conversations/conv-api/context': (o) => (404, '{"message":"x"}'),
        'POST /messaging/conversations/conv-api/read': (o) => {'read': 0},
        'GET /auth/me': (o) => {'id': 'me'},
        'GET /messaging/unread-count': (o) => {'count': 0},
        'GET /notifications/unread-count': (o) => {'unread': 0},
      });
      final context = await pump(tester, api: clientFor(adapter));
      final opened = MessagingLauncher.withPerson(context, 'sarah', message: 'Hi');
      await tester.pumpAndSettle();
      expect(await opened, isTrue);
      expect(adapter.last('POST /messaging/conversations').data, {
        'participantIds': ['sarah'],
        'message': 'Hi',
      });
      expect(threadOnScreen(tester)!.conversationId, 'conv-api');
    });

    test('each record endpoint is the portal\'s own and answers { conversationId } or the conversation', () async {
      final adapter = TableAdapter({
        'POST /mentorship/M1/conversation': (o) => {'conversationId': 'c-m'},
        'POST /mentor-services/purchases/P1/conversation': (o) => {'conversationId': 'c-p'},
        'POST /mentorship/group-sessions/G1/conversation': (o) => {'conversationId': 'c-g'},
        'POST /rfq/R1/conversation': (o) => {'id': 'c-r', 'rfqId': 'R1'},
        'POST /applications/A1/conversation': (o) => {'id': 'c-a'},
        'POST /messaging/conversations/job': (o) => {'id': 'c-j'},
        'POST /messaging/conversations/supplier': (o) => {'id': 'c-s'},
        'POST /messaging/conversations/company': (o) => {'id': 'c-c'},
      });
      final api = clientFor(adapter);
      final r = ApiMessagingRepository(api: api);
      expect(await r.openForMentorship('M1'), 'c-m');
      expect(await r.openForPurchase('P1'), 'c-p');
      expect(await r.openForGroupSession('G1'), 'c-g');
      expect(await r.openForRfq('R1', supplierCompanyId: 'co-care'), 'c-r');
      expect(adapter.last('POST /rfq/R1/conversation').data, {'supplierCompanyId': 'co-care'});
      expect(await r.openForApplication('A1'), 'c-a');
      expect(await r.startWithJobContact('J1', message: ' hi '), 'c-j');
      expect(adapter.last('POST /messaging/conversations/job').data, {'jobId': 'J1', 'message': 'hi'});
      expect(await r.startWithSupplier('V1', rfqId: 'R1'), 'c-s');
      expect(adapter.last('POST /messaging/conversations/supplier').data, {'vendorId': 'V1', 'rfqId': 'R1'});
      expect(await r.startWithCompany('C1', 'CAREERS'), 'c-c');
      expect(adapter.last('POST /messaging/conversations/company').data, {'companyId': 'C1', 'topic': 'CAREERS'});
    });
  });

  group('"New message" (the pencil on the inbox)', () {
    late Future<String?> result;

    FakeMessagingRepository people() => withThread()
      ..recipientsAnswer = const Recipients(
        people: [
          RecipientPerson(person: sarah, headline: 'Senior Facilities Manager', companyName: 'Google'),
          RecipientPerson(person: david),
        ],
        suppliers: [
          RecipientSupplier(vendorId: 'v1', companyId: 'co-care', name: 'Bengaluru Care 101', city: 'Bengaluru'),
        ],
      );

    Future<void> openSheet(WidgetTester tester, FakeMessagingRepository repository) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      repo = repository;
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (c) {
              context = c;
              return const Scaffold();
            },
          ),
        ),
      );
      result = showNewMessage(context, repository);
      await tester.pumpAndSettle();
    }

    testWidgets('asks for two letters first; nothing is searched for fewer', (tester) async {
      await openSheet(tester, people());
      expect(find.text('Who would you like to message?'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('recipient-search')), 's');
      await tester.pump(const Duration(milliseconds: 500));
      expect(repo.calls.where((c) => c.startsWith('recipients')), isEmpty);
    });

    testWidgets('lists people (with who they are) and suppliers (their sales team replies)', (tester) async {
      await openSheet(tester, people());
      await tester.enterText(find.byKey(const ValueKey('recipient-search')), 'sa');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('recipients sa'));
      expect(find.text('PEOPLE'), findsOneWidget);
      expect(find.text('Sarah Jenkins'), findsOneWidget);
      expect(find.text('Senior Facilities Manager · Google'), findsOneWidget);
      expect(find.text('SUPPLIERS'), findsOneWidget);
      expect(find.text('Bengaluru · Sales team replies'), findsOneWidget);
    });

    testWidgets('a person: opens (or reuses) their plain thread and closes with its id', (tester) async {
      await openSheet(tester, people());
      await tester.enterText(find.byKey(const ValueKey('recipient-search')), 'sa');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('person-sarah')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('startWithPerson sarah message=null'));
      expect(await result, 'conv-started');
    });

    testWidgets('a supplier: its sales inbox, by its listing', (tester) async {
      await openSheet(tester, people());
      await tester.enterText(find.byKey(const ValueKey('recipient-search')), 'care');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('supplier-v1')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('startWithSupplier v1 rfq=null message=null'));
      expect(await result, 'conv-started');
    });

    testWidgets('a refusal stays in the sheet, in the API\'s words, and another can be tried', (tester) async {
      final repository = people()
        ..errors['startWithSupplier'] = ApiError(
          'This supplier has no one answering its sales inbox yet.',
          statusCode: 400,
        );
      await openSheet(tester, repository);
      await tester.enterText(find.byKey(const ValueKey('recipient-search')), 'care');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('supplier-v1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('start-error')), findsOneWidget);
      expect(find.text('This supplier has no one answering its sales inbox yet.'), findsOneWidget);
      repository.errors.remove('startWithSupplier');
      await tester.tap(find.byKey(const ValueKey('supplier-v1')));
      await tester.pumpAndSettle();
      expect(await result, 'conv-started');
    });

    testWidgets('no one found, and a failed search can be retried', (tester) async {
      final repository = people()..recipientsAnswer = const Recipients();
      await openSheet(tester, repository);
      await tester.enterText(find.byKey(const ValueKey('recipient-search')), 'zz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('No one found'), findsOneWidget);

      repository.errors['recipients'] = ApiError('Search is busy.', statusCode: 503);
      await tester.enterText(find.byKey(const ValueKey('recipient-search')), 'zzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't search."), findsOneWidget);
      expect(find.text('Search is busy.'), findsOneWidget);
      repository.errors.remove('recipients');
      repository.recipientsAnswer = const Recipients(people: [RecipientPerson(person: david)]);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('David Chen'), findsOneWidget);
    });

    testWidgets('the inbox\'s pencil opens it, and the thread it started opens next', (tester) async {
      final repository = people();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      repo = repository;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: InboxScreen(repository: repository, poll: false, clock: () => testNow),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('compose')));
      await tester.pumpAndSettle();
      expect(find.text('New message'), findsWidgets);
      await tester.enterText(find.byKey(const ValueKey('recipient-search')), 'sa');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('person-sarah')));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationScreen), findsOneWidget);
      expect(threadOnScreen(tester)!.conversationId, 'conv-started');
    });
  });

  group('a notification that names a conversation opens it in the app (the router\'s own opener)', () {
    testWidgets('/messaging?c=<id>&inbox=<company>&m=<message> opens that thread as that company, on that message', (
      tester,
    ) async {
      final context = await pump(tester);
      unawaited(NotificationRouter.of(context).openHref(context, '/messaging?c=conv-started&inbox=co-acme&m=c1'));
      await tester.pumpAndSettle();
      final screen = threadOnScreen(tester)!;
      expect((screen.conversationId, screen.asCompanyId, screen.focusMessageId), ('conv-started', 'co-acme', 'c1'));
    });

    testWidgets('a personal thread carries no company side', (tester) async {
      final context = await pump(tester);
      unawaited(NotificationRouter.of(context).openHref(context, '/messaging?c=conv-started&inbox=personal'));
      await tester.pumpAndSettle();
      expect(threadOnScreen(tester)!.asCompanyId, isNull);
    });

    testWidgets('/messaging?inbox=<company> opens that company\'s inbox, and /messaging the person\'s own', (
      tester,
    ) async {
      final context = await pump(tester);
      unawaited(NotificationRouter.of(context).openHref(context, '/messaging?inbox=co-acme'));
      await tester.pumpAndSettle();
      expect(tester.widget<InboxScreen>(find.byType(InboxScreen)).initialInbox, 'co-acme');
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      unawaited(NotificationRouter.of(context).openHref(context, '/messaging'));
      await tester.pumpAndSettle();
      expect(tester.widget<InboxScreen>(find.byType(InboxScreen)).initialInbox, isNull);
    });

    testWidgets('the target kinds are the API\'s', (tester) async {
      expect(NotificationTarget.parse('/messaging?c=x').kind, NotificationKinds.conversation);
      expect(
        NotificationRouter.builtInKinds,
        containsAll([NotificationKinds.conversation, NotificationKinds.messaging]),
      );
    });
  });
}

class _Spy implements UnreadSource {
  int messageReads = 0;
  @override
  Future<int> notifications() async => 0;
  @override
  Future<int> messages() async {
    messageReads++;
    return 0;
  }
}
