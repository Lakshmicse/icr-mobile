import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/messaging/conversation_controller.dart';
import 'package:icr_mobile/features/messaging/conversation_screen.dart';
import 'package:icr_mobile/features/messaging/demo_messaging_repository.dart';
import 'package:icr_mobile/features/messaging/messaging_launcher.dart';
import 'package:icr_mobile/features/messaging/messaging_models.dart';
import 'package:icr_mobile/features/messaging/widgets/composer.dart';
import 'package:icr_mobile/features/messaging/widgets/message_bubble.dart';
import 'package:icr_mobile/features/notifications/notification_router.dart';
import 'package:icr_mobile/features/notifications/unread_counts.dart';
import 'package:provider/provider.dart';

import 'helpers/fonts.dart';
import 'messaging_fakes.dart';

/// Every control of an open conversation, tapped: the newest messages with
/// earlier ones paged in, what it is about under the header, sending (and a
/// refusal that keeps the words), reply, copy, delete, report, "Seen", the
/// star, pin and company-inbox sorting in the header menu, and the poll that
/// brings new messages in. Files and shared records: `messaging_files_test.dart`.
/// What the API does with each call: `test/live/messaging_live_test.dart`.
void main() {
  setUpAll(loadAppFonts);
  // Drafts live in memory for the life of the app: every test opens a thread with an empty box.
  setUp(DraftStore.clearAll);

  /// A thread between Bharat and Sarah that spans three days, ends on Bharat's message and has been read.
  List<ChatMessage> sarahThread() => [
    msg('s1', 'sarah', me, 'Hi Sarah, your post was a great read.', ago: 3000, read: true),
    msg(
      's2',
      'sarah',
      sarah,
      'Thanks Bharat! I will send it across today.',
      ago: 2900,
      read: true,
      replyTo: const MessageReply(
        id: 's1',
        senderId: meId,
        senderName: 'Bharat Buyer',
        excerpt: 'Hi Sarah, your post was a great read.',
      ),
    ),
    msg('s3', 'sarah', sarah, 'One more thing: this role might suit you.', ago: 1500, read: true),
    msg('s4', 'sarah', sarah, 'Did you get a chance to look at it?', ago: 40),
    msg('s5', 'sarah', sarah, 'Happy to jump on a call this week.', ago: 38),
    msg('s6', 'sarah', me, 'Yes, I did. Thursday works.', ago: 20, read: true),
  ];

  late FakeMessagingRepository repo;
  late List<String> routed;
  late List<String> site;
  late _CountSource source;

  FakeMessagingRepository sarahRepo({
    List<ChatMessage>? messages,
    ConversationContext? context,
    List<Conversation>? rows,
    bool seen = true,
  }) {
    final thread = messages ?? sarahThread();
    return FakeMessagingRepository(
        rows: rows ?? [convo('sarah', unread: 2, last: thread.last, updatedAgo: 20)],
        threads: {'sarah': thread},
        contexts: {'sarah': context ?? const ConversationContext(kind: ConversationKind.direct, person: sarah)},
      )
      ..seenAt.addAll({
        if (seen) 'sarah': MessageSeen(messageId: thread.lastWhere((m) => m.senderId == meId).id, at: minutesAgo(15)),
      });
  }

  Future<void> pump(
    WidgetTester tester, {
    FakeMessagingRepository? repository,
    String id = 'sarah',
    String? asCompanyId,
    Conversation? initial,
    String? focus,
    AttachmentPicker? pickAttachment,
    bool poll = false,
    Duration pollInterval = const Duration(seconds: 4),
    Size size = const Size(390, 844),
    bool settle = true,
    bool pushed = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo = repository ?? sarahRepo();
    routed = [];
    site = [];
    source = _CountSource();
    final counts = UnreadCounts(source, interval: const Duration(hours: 1));
    addTearDown(counts.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UnreadCounts>.value(value: counts),
          Provider<NotificationRouter>.value(
            value: NotificationRouter(
              openSite: (context, path) async => site.add(path),
              openers: {
                for (final k in const [
                  'job',
                  'company.page',
                  'member',
                  'rfq.owner',
                  'rfq.supplier',
                  'mentorship.pairing',
                ])
                  k: (context, t) {
                    routed.add('${t.kind} ${t.params}');
                    return true;
                  },
              },
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) {
              final screen = ConversationScreen(
                conversationId: id,
                repository: repo,
                asCompanyId: asCompanyId,
                initial: initial,
                focusMessageId: focus,
                pickAttachment: pickAttachment,
                poll: poll,
                pollInterval: pollInterval,
                clock: () => testNow,
              );
              if (!pushed) return screen;
              return Scaffold(
                body: Center(
                  child: TextButton(
                    key: const ValueKey('open'),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen)),
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    if (pushed) {
      await tester.tap(find.byKey(const ValueKey('open')));
    }
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Finder text(String t) => find.text(t, findRichText: true);
  Finder composer() => find.byKey(const ValueKey('composer'));
  Finder sendButton() => find.byKey(const ValueKey('send'));

  Future<void> typeAndSend(WidgetTester tester, String words) async {
    await tester.enterText(composer(), words);
    await tester.pump();
    await tester.tap(sendButton());
    await tester.pump();
  }

  Future<void> hold(WidgetTester tester, Finder bubble) async {
    await tester.longPress(bubble);
    await tester.pumpAndSettle();
  }

  group('opening a conversation', () {
    testWidgets('reads the newest window, with the day, the time, whose it is and what it quotes', (tester) async {
      // Tall enough that the oldest day's pill is in view (an item outside the viewport is not "on stage").
      await pump(tester, size: const Size(390, 1100));
      expect(repo.calls, contains('thread sarah take=50 as=null'));
      // Header: who it is with, and "Direct" once the context is in.
      expect(find.text('Sarah Jenkins'), findsWidgets);
      expect(text('Thanks Bharat! I will send it across today.'), findsOneWidget);
      expect(text('Did you get a chance to look at it?'), findsOneWidget);
      // Day separators, in the design's lower case.
      expect(find.text('today, october 25'), findsOneWidget);
      expect(find.text('yesterday, october 24'), findsOneWidget);
      expect(find.text('friday, 23 october'), findsOneWidget);
      // Their block carries their name and the time of its first message (s4, 14:20); mine carries its time
      // (s6, 14:40); s2, on the Friday, was also sent at 14:40.
      expect(find.text('2:20 PM'), findsOneWidget);
      expect(find.text('2:40 PM'), findsNWidgets(2));
      // The reply's quote carries the quoted person and words.
      expect(find.text('Bharat Buyer'), findsOneWidget);
      expect(text('Hi Sarah, your post was a great read.'), findsNWidgets(2), reason: 'the message and the quote');
      // Mine on the right, theirs on the left.
      final mine = tester.getTopRight(
        find.ancestor(of: text('Yes, I did. Thursday works.'), matching: find.byType(Container)).first,
      );
      final theirs = tester.getTopLeft(
        find.ancestor(of: text('Did you get a chance to look at it?'), matching: find.byType(Container)).first,
      );
      expect(mine.dx, greaterThan(200));
      expect(theirs.dx, lessThan(60));
    });

    testWidgets('reads the thread as read: the API is told, and the bell and the inbox badge read again', (
      tester,
    ) async {
      await pump(tester);
      expect(repo.calls, contains('markRead sarah as=null'));
      expect(source.messageReads, greaterThan(0));
    });

    testWidgets('messages from one person within five minutes read as one block (one name, one time)', (tester) async {
      await pump(tester);
      // s4 and s5 are two minutes apart: the first carries its time, the second does not.
      final controller = ConversationController(repo, conversationId: 'sarah', viewerId: meId, clock: () => testNow);
      await controller.start();
      final items = controller.timeline.whereType<MessageItem>().toList();
      expect(
        [for (final i in items) '${i.message.id}:${i.continued}'],
        ['s1:false', 's2:false', 's3:false', 's4:false', 's5:true', 's6:false'],
      );
      controller.dispose();
    });

    testWidgets('the header fills from the inbox row at once, before the thread has loaded', (tester) async {
      final gate = Completer<void>();
      final repository = sarahRepo()..holds['thread'] = gate;
      await pump(
        tester,
        repository: repository,
        initial: convo('sarah', last: sarahThread().last),
        settle: false,
      );
      expect(find.text('Sarah Jenkins'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(text('Did you get a chance to look at it?'), findsOneWidget);
    });

    testWidgets('a failure says why and Retry loads it', (tester) async {
      final repository = sarahRepo()..errors['thread'] = ApiError('Unable to reach the server.');
      await pump(tester, repository: repository);
      expect(find.text('Unable to load this conversation.'), findsOneWidget);
      expect(find.byType(Composer), findsNothing);
      repository.errors.remove('thread');
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(text('Did you get a chance to look at it?'), findsOneWidget);
    });

    testWidgets("someone else's thread (403/404): can't open, and the way back", (tester) async {
      final repository = sarahRepo()..errors['thread'] = ApiError('Forbidden', statusCode: 403);
      await pump(tester, repository: repository, pushed: true);
      expect(find.text("You can't open this conversation"), findsOneWidget);
      expect(find.text('It may belong to another account, or you may have left it.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing, reason: 'no composer');
      await tester.tap(find.text('Back to messages'));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationScreen), findsNothing);
    });

    testWidgets('an empty thread introduces itself and the composer is ready', (tester) async {
      final repository = FakeMessagingRepository(
        rows: [convo('sarah')],
        threads: {'sarah': const []},
        contexts: {'sarah': const ConversationContext(kind: ConversationKind.direct, person: sarah)},
      );
      await pump(tester, repository: repository);
      expect(find.text('No messages yet — say hello.'), findsOneWidget);
      expect(composer(), findsOneWidget);
    });
  });

  group('earlier messages', () {
    /// 120 messages, one a minute, alternating; ids m0 (oldest) to m119.
    List<ChatMessage> long() => [
      for (var i = 0; i < 120; i++)
        msg('m$i', 'sarah', i.isEven ? sarah : me, 'Message number $i', ago: 300 - i * 2, read: true),
    ];

    testWidgets(
      'only the newest 50 are read, "Load earlier messages" pages back, and the end of history has no button',
      (tester) async {
        final repository = FakeMessagingRepository(
          rows: [convo('sarah')],
          threads: {'sarah': long()},
          contexts: {'sarah': const ConversationContext(kind: ConversationKind.direct, person: sarah)},
        );
        await pump(tester, repository: repository, size: const Size(390, 5000));
        expect(text('Message number 119'), findsOneWidget);
        expect(text('Message number 70'), findsOneWidget);
        expect(text('Message number 69'), findsNothing);
        final earlier = find.byKey(const ValueKey('load-earlier'));
        expect(earlier, findsOneWidget);

        await tester.tap(earlier);
        await tester.pumpAndSettle();
        expect(repository.calls, contains('older sarah before=m70 take=50'));
        expect(text('Message number 69'), findsOneWidget);
        final thread = find.byKey(const ValueKey('thread'));
        await tester.dragUntilVisible(text('Message number 20'), thread, const Offset(0, 800));
        // Scrolling to the top asks for the page before it by itself.
        await tester.dragUntilVisible(text('Message number 0'), thread, const Offset(0, 800));
        await tester.pumpAndSettle();
        expect(repository.calls, contains('older sarah before=m20 take=50'));
        expect(earlier, findsNothing, reason: 'nothing earlier');
      },
    );

    testWidgets('scrolling to the top pages back by itself', (tester) async {
      final repository = FakeMessagingRepository(
        rows: [convo('sarah')],
        threads: {'sarah': long()},
        contexts: {'sarah': const ConversationContext(kind: ConversationKind.direct, person: sarah)},
      );
      await pump(tester, repository: repository);
      await tester.fling(find.byKey(const ValueKey('thread')), const Offset(0, 3000), 6000);
      await tester.pumpAndSettle();
      expect(repository.calls.where((c) => c.startsWith('older sarah')), isNotEmpty);
    });

    testWidgets('a failed page leaves the thread as it was and can be asked for again', (tester) async {
      final repository = FakeMessagingRepository(
        rows: [convo('sarah')],
        threads: {'sarah': long()},
        contexts: {'sarah': const ConversationContext(kind: ConversationKind.direct, person: sarah)},
      );
      await pump(tester, repository: repository, size: const Size(390, 5000));
      repository.errors['older'] = ApiError('down');
      await tester.tap(find.byKey(const ValueKey('load-earlier')));
      await tester.pumpAndSettle();
      expect(text('Message number 70'), findsOneWidget);
      expect(text('Message number 69'), findsNothing);
      repository.errors.remove('older');
      await tester.tap(find.byKey(const ValueKey('load-earlier')));
      await tester.pumpAndSettle();
      expect(text('Message number 69'), findsOneWidget);
    });

    testWidgets('a message named by a search hit that is older than the window is paged back to and shown', (
      tester,
    ) async {
      final repository = FakeMessagingRepository(
        rows: [convo('sarah')],
        threads: {'sarah': long()},
        contexts: {'sarah': const ConversationContext(kind: ConversationKind.direct, person: sarah)},
      );
      await pump(tester, repository: repository, focus: 'm30', size: const Size(390, 700));
      expect(repository.calls.where((c) => c.startsWith('older sarah')), hasLength(1));
      expect(find.byKey(const ValueKey('thread')), findsOneWidget);
      expect(text('Message number 30'), findsOneWidget, reason: 'scrolled into view');
    });

    testWidgets('a focused message the thread does not have says so', (tester) async {
      await pump(tester, focus: 'no-such-message');
      expect(find.text('That message is no longer in this conversation.'), findsOneWidget);
    });
  });

  group('sending', () {
    testWidgets('the words go to the API as typed (trimmed), appear as "Sending…" and then as a message', (
      tester,
    ) async {
      final repository = sarahRepo();
      final gate = Completer<void>();
      repository.holds['send'] = gate;
      await pump(tester, repository: repository);
      await typeAndSend(tester, '  Thursday at 11 then.  ');
      expect(text('Thursday at 11 then.'), findsOneWidget);
      expect(find.text('Sending…'), findsOneWidget);
      expect(tester.widget<TextField>(composer()).controller!.text, isEmpty, reason: 'the box is clear at once');
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Sending…'), findsNothing);
      expect(repository.sent.single.body, 'Thursday at 11 then.');
      expect(text('Thursday at 11 then.'), findsOneWidget);
    });

    testWidgets('Send is off while there is nothing to send, and on once there is', (tester) async {
      await pump(tester);
      await tester.tap(sendButton());
      await tester.pump();
      expect(repo.sent, isEmpty);
      await tester.enterText(composer(), 'hello');
      await tester.pump();
      await tester.tap(sendButton());
      await tester.pumpAndSettle();
      expect(repo.sent, hasLength(1));
    });

    testWidgets('a refusal leaves the message in the thread with its reason, Retry and Discard', (tester) async {
      final repository = sarahRepo()
        ..errors['send'] = ApiError('Messaging is switched off for this company.', statusCode: 400);
      await pump(tester, repository: repository);
      await typeAndSend(tester, 'Are you free on Friday?');
      await tester.pumpAndSettle();
      expect(text('Are you free on Friday?'), findsOneWidget, reason: 'nothing typed is lost');
      expect(find.text('Messaging is switched off for this company.'), findsOneWidget);
      expect(find.byKey(const ValueKey('pending-retry')), findsOneWidget);

      // Retry sends it for real.
      repository.errors.remove('send');
      await tester.tap(find.byKey(const ValueKey('pending-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pending-retry')), findsNothing);
      expect(repository.sent.single.body, 'Are you free on Friday?');
      expect(find.text('Messaging is switched off for this company.'), findsNothing);
    });

    testWidgets('Discard puts the words back in the box', (tester) async {
      final repository = sarahRepo()..errors['send'] = ApiError('Nope', statusCode: 400);
      await pump(tester, repository: repository);
      await typeAndSend(tester, 'Are you free on Friday?');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pending-discard')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pending-retry')), findsNothing);
      expect(tester.widget<TextField>(composer()).controller!.text, 'Are you free on Friday?');
    });

    testWidgets('over 4000 characters is refused before it is sent, with the count shown near the limit', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(composer(), 'x' * 3600);
      await tester.pump();
      expect(find.text('3600/4000'), findsOneWidget);
      await tester.enterText(composer(), 'x' * 4001);
      await tester.pump();
      await tester.tap(sendButton());
      await tester.pump();
      expect(find.text('A message can be at most 4000 characters.'), findsOneWidget);
      expect(repo.sent, isEmpty);
    });

    testWidgets('a long thread scrolls to the new message as it is sent', (tester) async {
      final many = [
        for (var i = 0; i < 40; i++) msg('m$i', 'sarah', i.isEven ? sarah : me, 'Line $i', ago: 200 - i, read: true),
      ];
      await pump(
        tester,
        repository: sarahRepo(messages: many, seen: false),
        size: const Size(390, 500),
      );
      await tester.fling(find.byKey(const ValueKey('thread')), const Offset(0, 600), 1000);
      await tester.pumpAndSettle();
      expect(text('Line 39'), findsNothing, reason: 'scrolled away from the newest');
      await typeAndSend(tester, 'Back at the bottom');
      await tester.pumpAndSettle();
      expect(text('Back at the bottom'), findsOneWidget);
    });

    testWidgets('a conversation read from a company inbox writes as that company and says so', (tester) async {
      const party = ThreadParty(companyId: 'co-acme', name: 'Acme FM', topic: 'SALES', status: ThreadStatus.open);
      final repository = FakeMessagingRepository(
        rows: [
          convo(
            'enq',
            people: const [me],
            kind: ConversationKind.company,
            counterpart: globalInfra,
            asCompanyId: 'co-acme',
            parties: const [party],
          ),
        ],
        threads: {
          'enq': [msg('e1', 'enq', me, 'Do you cover Chennai?', ago: 90)],
        },
        contexts: {
          'enq': const ConversationContext(
            kind: ConversationKind.company,
            company: ContextCompany(id: 'co-gi', name: 'Global Infra Solutions'),
          ),
        },
      );
      await pump(tester, repository: repository, id: 'enq', asCompanyId: 'co-acme');
      expect(repository.calls, contains('thread enq take=50 as=co-acme'));
      expect(find.text('Replying as Acme FM'), findsOneWidget);
      await typeAndSend(tester, 'Yes, from next month.');
      await tester.pumpAndSettle();
      expect(repository.sent.single.asCompanyId, 'co-acme');
    });
  });

  group('a message\'s menu (press and hold)', () {
    testWidgets('Reply quotes it: the bar names the person, Send carries the id, the quote shows in the thread', (
      tester,
    ) async {
      await pump(tester);
      await hold(tester, text('Did you get a chance to look at it?'));
      await tester.tap(find.byKey(const ValueKey('action-reply')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reply-bar')), findsOneWidget);
      expect(find.text('Replying to Sarah'), findsOneWidget);
      await typeAndSend(tester, 'Yes, I read it.');
      await tester.pumpAndSettle();
      expect(repo.sent.single.replyToId, 's4');
      expect(find.byKey(const ValueKey('reply-bar')), findsNothing, reason: 'the bar goes with the send');
      expect(text('Did you get a chance to look at it?'), findsNWidgets(2), reason: 'the message and its quote');
    });

    testWidgets('the reply bar can be closed without sending', (tester) async {
      await pump(tester);
      await hold(tester, text('Did you get a chance to look at it?'));
      await tester.tap(find.byKey(const ValueKey('action-reply')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byKey(const ValueKey('reply-bar')), matching: find.byTooltip('Remove')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reply-bar')), findsNothing);
      await typeAndSend(tester, 'Plain message');
      await tester.pumpAndSettle();
      expect(repo.sent.single.replyToId, isNull);
    });

    testWidgets('tapping a quote scrolls to the message it quotes', (tester) async {
      await pump(tester);
      // s2 quotes s1: the quote is the copy of s1's words inside s2's bubble.
      final reply = find.ancestor(
        of: text('Thanks Bharat! I will send it across today.'),
        matching: find.byType(MessageBubble),
      );
      final quote = find.descendant(of: reply, matching: text('Hi Sarah, your post was a great read.'));
      expect(quote, findsOneWidget);
      await tester.ensureVisible(quote);
      await tester.tap(quote);
      await tester.pumpAndSettle();
      expect(find.byType(ConversationScreen), findsOneWidget);
      expect(text('Hi Sarah, your post was a great read.'), findsNWidgets(2), reason: 'the message and its quote');
    });

    testWidgets('Copy text puts the words on the clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pump(tester);
      await hold(tester, text('Did you get a chance to look at it?'));
      await tester.tap(find.byKey(const ValueKey('action-copy')));
      await tester.pumpAndSettle();
      expect(copied, 'Did you get a chance to look at it?');
      expect(find.text('Copied'), findsOneWidget);
    });

    testWidgets('your own message offers Delete, theirs offers Report', (tester) async {
      await pump(tester);
      await hold(tester, text('Yes, I did. Thursday works.'));
      expect(find.byKey(const ValueKey('action-delete')), findsOneWidget);
      expect(find.byKey(const ValueKey('action-report')), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await hold(tester, text('Did you get a chance to look at it?'));
      expect(find.byKey(const ValueKey('action-report')), findsOneWidget);
      expect(find.byKey(const ValueKey('action-delete')), findsNothing);
    });

    testWidgets('Delete asks, withdraws it for everyone, and the bubble says so', (tester) async {
      await pump(tester);
      await hold(tester, text('Yes, I did. Thursday works.'));
      await tester.tap(find.byKey(const ValueKey('action-delete')));
      await tester.pumpAndSettle();
      expect(find.text('Delete this message?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-delete')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('deleteMessage sarah s6'));
      expect(find.text('This message was deleted'), findsOneWidget);
      expect(text('Yes, I did. Thursday works.'), findsNothing);
    });

    testWidgets('Cancel on the confirmation changes nothing', (tester) async {
      await pump(tester);
      await hold(tester, text('Yes, I did. Thursday works.'));
      await tester.tap(find.byKey(const ValueKey('action-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.calls.where((c) => c.startsWith('deleteMessage')), isEmpty);
      expect(text('Yes, I did. Thursday works.'), findsOneWidget);
    });

    testWidgets('a refused delete puts the message back and shows the reason', (tester) async {
      final repository = sarahRepo()
        ..errors['deleteMessage'] = ApiError('You can only delete your own messages.', statusCode: 403);
      await pump(tester, repository: repository);
      await hold(tester, text('Yes, I did. Thursday works.'));
      await tester.tap(find.byKey(const ValueKey('action-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-delete')));
      await tester.pumpAndSettle();
      expect(text('Yes, I did. Thursday works.'), findsOneWidget);
      expect(find.text('You can only delete your own messages.'), findsOneWidget);
    });

    testWidgets('a withdrawn message has no menu', (tester) async {
      final thread = [...sarahThread(), msg('s7', 'sarah', sarah, 'oops', ago: 5, deleted: true)];
      await pump(tester, repository: sarahRepo(messages: thread));
      await tester.longPress(find.text('This message was deleted'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('action-reply')), findsNothing);
    });

    testWidgets('Report asks why (Report stays off until a reason is picked), then sends it with the note', (
      tester,
    ) async {
      await pump(tester);
      await hold(tester, text('Did you get a chance to look at it?'));
      await tester.tap(find.byKey(const ValueKey('action-report')));
      await tester.pumpAndSettle();
      expect(find.text('Report this message'), findsOneWidget);
      final send = find.byKey(const ValueKey('send-report'));
      expect(tester.widget<FilledButton>(send).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('reason-HARASSMENT')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'Add a note (optional)'),
        'Repeated unwanted contact',
      );
      expect(tester.widget<FilledButton>(send).onPressed, isNotNull);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(repo.reports.single, (messageId: 's4', reason: 'HARASSMENT', note: 'Repeated unwanted contact'));
      expect(find.text('Thanks. ICR will review this message.'), findsOneWidget);
    });

    testWidgets('a refused report shows the API\'s sentence', (tester) async {
      final repository = sarahRepo()
        ..errors['report'] = ApiError('You already reported this message.', statusCode: 409);
      await pump(tester, repository: repository);
      await hold(tester, text('Did you get a chance to look at it?'));
      await tester.tap(find.byKey(const ValueKey('action-report')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reason-SPAM')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('send-report')));
      await tester.pumpAndSettle();
      expect(find.text('You already reported this message.'), findsOneWidget);
    });
  });

  group('"Seen" (a green double tick under your message on a one-to-one thread)', () {
    Finder tick(String key) => find.byKey(ValueKey(key));
    Finder inNewest(String key) => find.descendant(of: find.byType(MessageBubble).first, matching: tick(key));

    testWidgets('sits under your messages the other person has read, up to the one the API names', (tester) async {
      await pump(tester);
      // s1 and s6 are mine; the API says the other side has read up to s6, so both are read.
      expect(tick('tick-seen'), findsNWidgets(2));
      expect(tick('tick-sent'), findsNothing);
      expect(inNewest('tick-seen'), findsOneWidget);
      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(tester.getSemantics(inNewest('tick-seen')).label, contains('Seen'), reason: 'a screen reader says it');
      semantics.dispose();
    });

    testWidgets('is not drawn when the API gives none (a room, or nothing read yet): a single grey tick', (
      tester,
    ) async {
      await pump(tester, repository: sarahRepo(seen: false));
      expect(tick('tick-seen'), findsNothing);
      expect(tick('tick-sent'), findsNWidgets(2));
    });

    testWidgets('moves to the newer message when the other side reads it, on the next poll', (tester) async {
      final repository = sarahRepo();
      await pump(tester, repository: repository, poll: true);
      await typeAndSend(tester, 'See you then');
      await tester.pumpAndSettle();
      expect(inNewest('tick-sent'), findsOneWidget, reason: 'sent, not read yet');
      final sentId = repository.sent.isEmpty ? null : repository.threads['sarah']!.last.id;
      repository.seenAt['sarah'] = MessageSeen(messageId: sentId!, at: testNow.add(const Duration(minutes: 9)));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(inNewest('tick-seen'), findsOneWidget);
      expect(tick('tick-sent'), findsNothing);
    });
  });

  group('new messages arrive by polling (there is no socket client)', () {
    testWidgets('a message sent by the other side shows within a few seconds, with no spinner, and is read', (
      tester,
    ) async {
      await pump(tester, poll: true);
      final readsBefore = repo.calls.where((c) => c.startsWith('markRead')).length;
      repo.arrive('sarah', sarah, 'Also: I attached nothing, sorry!');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(text('Also: I attached nothing, sorry!'), findsOneWidget);
      expect(repo.calls.any((c) => c.startsWith('newer sarah after=s6')), isTrue);
      expect(repo.calls.where((c) => c.startsWith('markRead')).length, greaterThan(readsBefore));
    });

    testWidgets('a poll that fails changes nothing and says nothing', (tester) async {
      await pump(tester, poll: true);
      repo.errors['newer'] = ApiError('down');
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(text('Did you get a chance to look at it?'), findsOneWidget);
      expect(find.text('Unable to load this conversation.'), findsNothing);
    });

    testWidgets('it stops in the background and catches up when the app returns', (tester) async {
      await pump(tester, poll: true);
      for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      final before = repo.calls.where((c) => c.startsWith('newer')).length;
      repo.arrive('sarah', sarah, 'While you were away');
      await tester.pump(const Duration(seconds: 30));
      expect(repo.calls.where((c) => c.startsWith('newer')).length, before);
      for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pumpAndSettle();
      expect(text('While you were away'), findsOneWidget);
    });

    testWidgets('leaving the screen stops the poll', (tester) async {
      await pump(tester, poll: true);
      await tester.pumpWidget(const SizedBox());
      final before = repo.calls.where((c) => c.startsWith('newer')).length;
      await tester.pump(const Duration(seconds: 30));
      expect(repo.calls.where((c) => c.startsWith('newer')).length, before);
    });
  });

  group('the header', () {
    testWidgets('tapping who it is with opens their profile (the router) and a company opens its page', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('thread-header')));
      await tester.pumpAndSettle();
      expect(routed, ['member {userId: sarah}']);
    });

    testWidgets('a company thread opens the company page', (tester) async {
      final repository = FakeMessagingRepository(
        rows: [
          convo('co', people: const [me], kind: ConversationKind.company, counterpart: globalInfra),
        ],
        threads: {
          'co': [msg('c1', 'co', priya, 'Hello', company: globalInfra, ago: 30)],
        },
        contexts: {
          'co': const ConversationContext(
            kind: ConversationKind.company,
            company: ContextCompany(id: 'co-gi', name: 'Global Infra Solutions'),
          ),
        },
      );
      await pump(tester, repository: repository, id: 'co');
      await tester.tap(find.byKey(const ValueKey('thread-header')));
      await tester.pumpAndSettle();
      expect(routed, ['company.page {companyId: co-gi}']);
    });

    testWidgets('Star and Pin save at once and the menu names the state; a refusal puts it back with the reason', (
      tester,
    ) async {
      await pump(tester);
      Future<void> menu(String entry) async {
        await tester.tap(find.byKey(const ValueKey('thread-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry));
        await tester.pumpAndSettle();
      }

      await menu('Star conversation');
      expect(repo.calls, contains('setPreference sarah starred=true pinned=null'));
      await tester.tap(find.byKey(const ValueKey('thread-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Remove star'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      repo.errors['setPreference'] = ApiError('You can pin at most ten conversations.', statusCode: 400);
      await menu('Pin to top');
      expect(find.text('You can pin at most ten conversations.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('thread-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Pin to top'), findsOneWidget, reason: 'still not pinned');
    });
  });

  group('a company inbox thread (Done, Spam, assign)', () {
    const open = ThreadParty(companyId: 'co-acme', name: 'Acme FM', topic: 'SALES', status: ThreadStatus.open);
    FakeMessagingRepository inbox() => FakeMessagingRepository(
      rows: [
        convo(
          'enq',
          people: const [me],
          kind: ConversationKind.company,
          counterpart: globalInfra,
          asCompanyId: 'co-acme',
          parties: const [open],
        ),
      ],
      threads: {
        'enq': [msg('e1', 'enq', me, 'Do you cover Chennai?', ago: 90)],
      },
      contexts: {'enq': const ConversationContext(kind: ConversationKind.company)},
    );

    Future<void> menu(WidgetTester tester, String entry) async {
      await tester.tap(find.byKey(const ValueKey('thread-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry));
      await tester.pumpAndSettle();
    }

    testWidgets('Mark done, back to open, Mark as spam and Assign to me are each sent to the company, with the side', (
      tester,
    ) async {
      final repository = inbox();
      await pump(tester, repository: repository, id: 'enq', asCompanyId: 'co-acme');
      await menu(tester, 'Mark done');
      expect(repository.calls.last, 'updateCompanyThread enq company=co-acme status=done assignee=null unassign=false');
      await tester.tap(find.byKey(const ValueKey('thread-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Move back to open'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await menu(tester, 'Move back to open');
      expect(repository.calls.last, contains('status=open'));
      await menu(tester, 'Mark as spam');
      expect(repository.calls.last, contains('status=spam'));
      await menu(tester, 'Move back to open');
      await menu(tester, 'Assign to me');
      expect(repository.calls.last, 'updateCompanyThread enq company=co-acme status=null assignee=me unassign=false');
      await tester.tap(find.byKey(const ValueKey('thread-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Unassign'), findsOneWidget);
      await tester.tap(find.text('Unassign'));
      await tester.pumpAndSettle();
      expect(repository.calls.last, contains('unassign=true'));
    });

    testWidgets('a person who is not answering for a company is not offered the company\'s menu', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('thread-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Mark done'), findsNothing);
    });

    testWidgets('a refusal puts the status back and shows why', (tester) async {
      final repository = inbox()..errors['updateCompanyThread'] = ApiError('Not your inbox.', statusCode: 403);
      await pump(tester, repository: repository, id: 'enq', asCompanyId: 'co-acme');
      await menu(tester, 'Mark done');
      expect(find.text('Not your inbox.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('thread-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Mark done'), findsOneWidget, reason: 'still open');
    });
  });

  group("the contact card and the design's pieces", () {
    testWidgets("the card names who it is with, the company's role and city, and a verified company", (tester) async {
      const company = ContextCompany(
        id: 'co-cbre',
        name: 'CBRE',
        industry: 'Chair, Net-Zero Council',
        city: 'Bengaluru',
        verified: true,
      );
      await pump(
        tester,
        repository: sarahRepo(
          context: const ConversationContext(kind: ConversationKind.direct, person: sarah, company: company),
        ),
      );
      expect(find.text('Chair, Net-Zero Council • Bengaluru'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('verified-badge')),
        findsWidgets,
        reason: "the card's avatar and their messages'",
      );
      expect(find.text('Messages'), findsOneWidget, reason: 'the bar');
    });

    testWidgets('a company that is not verified draws no badge, and a thread with no company says what it is', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('verified-badge')), findsNothing);
      expect(find.text('Direct'), findsOneWidget);
    });

    testWidgets('a chevron opens what the thread is about, and a tap on it opens the record', (tester) async {
      final repository = FakeMessagingRepository(
        rows: [convo('rfq', kind: ConversationKind.requirement, counterpart: globalInfra)],
        threads: {
          'rfq': [msg('q1', 'rfq', priya, 'Happy to quote.', company: globalInfra, ago: 30)],
        },
        contexts: {
          'rfq': ConversationContext(
            kind: ConversationKind.requirement,
            perspective: Perspective.owner,
            company: const ContextCompany(id: 'co-gi', name: 'Global Infra Solutions'),
            requirement: ContextRequirement(
              id: 'r1',
              title: 'Annual Housekeeping',
              kind: 'RFQ',
              status: 'PUBLISHED',
              location: 'Chennai',
              dueDate: testNow.add(const Duration(days: 9)),
            ),
          ),
        },
      );
      await pump(tester, repository: repository, id: 'rfq');
      expect(find.byKey(const ValueKey('context-strip')), findsNothing, reason: 'closed, as the design draws it');
      await tester.tap(find.byKey(const ValueKey('thread-about')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('context-strip')), findsOneWidget);
      expect(find.text('Annual Housekeeping'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('context-strip')));
      await tester.pumpAndSettle();
      expect(routed.single, startsWith('rfq.owner'));
      await tester.tap(find.byKey(const ValueKey('thread-about')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('context-strip')), findsNothing);
    });

    testWidgets('a thread with nothing to say about itself has no chevron', (tester) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('thread-about')), findsNothing);
    });

    testWidgets('a long press on the card opens the menu', (tester) async {
      await pump(tester);
      await tester.longPress(find.byKey(const ValueKey('thread-header')));
      await tester.pumpAndSettle();
      expect(find.text('Star conversation'), findsOneWidget);
    });

    testWidgets("a file is a card under the sender's bubble, with its size and kind", (tester) async {
      final thread = [
        msg('t1', 'sarah', sarah, 'Here is the rider.', ago: 30, attachment: 'Rider.docx', attachmentSize: 696320),
      ];
      await pump(tester, repository: sarahRepo(messages: thread, seen: false));
      expect(find.text('Here is the rider.'), findsOneWidget);
      expect(find.text('Rider.docx'), findsOneWidget);
      expect(find.text('680 KB • DOCX'), findsOneWidget);
    });
  });

  group('the booked session (the meeting card)', () {
    final launched = <Uri>[];

    setUp(launched.clear);

    ConversationContext booked({DateTime? at, bool oneOnOne = true}) => ConversationContext(
      kind: ConversationKind.consultation,
      person: sarah,
      consultation: ContextConsultation(
        id: 'k1',
        title: '1:1 Council Pre-Flight Sync',
        buyer: true,
        oneOnOne: oneOnOne,
        scheduledAt: at ?? DateTime(2026, 10, 26, 16),
      ),
    );

    testWidgets('is drawn after the last message: title, kind, when it runs, Add to Cal and Join Meeting', (
      tester,
    ) async {
      await pump(tester, repository: sarahRepo(context: booked()));
      expect(find.byKey(const ValueKey('meeting-card')), findsOneWidget);
      expect(find.text('1:1 Council Pre-Flight Sync'), findsOneWidget);
      expect(find.text('Consultation'), findsWidgets, reason: "the kind, with no topic of the thread's own");
      expect(find.text('Tomorrow, 4:00 PM – 4:20 PM IST'), findsOneWidget);
      expect(find.text('Add to Cal'), findsOneWidget);
      expect(find.text('Join Meeting'), findsOneWidget);
      // The session carries no join link: its line is left out.
      expect(find.textContaining('Encrypted ICR Room'), findsNothing);
      // After the last message: the card sits below the newest bubble.
      final meeting = tester.getTopLeft(find.byKey(const ValueKey('meeting-card'))).dy;
      final newest = tester.getBottomLeft(find.byType(MessageBubble).first).dy;
      expect(meeting, greaterThan(newest));
    });

    testWidgets("names the thread's topic under the title when it has one", (tester) async {
      final row = convo('sarah', contextLabel: 'WG-01 Charter Finalization');
      final repository = FakeMessagingRepository(
        rows: [row],
        threads: {'sarah': sarahThread()},
        contexts: {'sarah': booked()},
      );
      await pump(tester, repository: repository, initial: row);
      expect(find.text('WG-01 Charter Finalization'), findsOneWidget);
    });

    testWidgets('a session already over, or with no time set, draws no card', (tester) async {
      await pump(
        tester,
        repository: sarahRepo(context: booked(at: DateTime(2026, 10, 24, 16))),
      );
      expect(find.byKey(const ValueKey('meeting-card')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await pump(tester);
      expect(find.byKey(const ValueKey('meeting-card')), findsNothing);
    });

    testWidgets("a pairing's next session and a group session's next one are drawn too", (tester) async {
      await pump(
        tester,
        repository: sarahRepo(
          context: ConversationContext(
            kind: ConversationKind.mentorship,
            person: sarah,
            mentorship: ContextMentorship(
              id: 'm1',
              mentee: true,
              mentorProfileId: 'p1',
              sessionsCount: 2,
              topics: const ['Supply chain', 'Careers', 'Ignored'],
              nextSessionAt: DateTime(2026, 10, 29, 9, 30),
            ),
          ),
        ),
      );
      expect(find.text('Supply chain, Careers'), findsOneWidget);
      expect(find.text('Thu, 29 Oct, 9:30 AM – 9:50 AM IST'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await pump(
        tester,
        repository: sarahRepo(
          context: ConversationContext(
            kind: ConversationKind.groupSession,
            groupSession: ContextGroupSession(
              id: 'g1',
              title: 'CXO Workplace Group',
              nextAt: DateTime(2026, 10, 25, 17),
            ),
          ),
        ),
      );
      expect(
        find.descendant(of: find.byKey(const ValueKey('meeting-card')), matching: find.text('CXO Workplace Group')),
        findsOneWidget,
      );
      expect(find.text('Today, 5:00 PM – 5:20 PM IST'), findsOneWidget);
    });

    testWidgets('Join Meeting, with no link on the session, opens its record through the router', (tester) async {
      await pump(
        tester,
        repository: sarahRepo(
          context: ConversationContext(
            kind: ConversationKind.mentorship,
            person: sarah,
            mentorship: ContextMentorship(
              id: 'm1',
              mentee: true,
              mentorProfileId: 'p1',
              sessionsCount: 2,
              nextSessionAt: DateTime(2026, 10, 26, 10),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('meeting-join')));
      await tester.pumpAndSettle();
      expect(routed.single, startsWith('mentorship.pairing'));
    });

    testWidgets('Add to Cal opens a Google Calendar "add event" page for the session, twenty minutes long', (
      tester,
    ) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), (call) async {
        if (call.method == 'launch') launched.add(Uri.parse((call.arguments as Map)['url'] as String));
        return call.method == 'launch' || call.method == 'canLaunch';
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), null),
      );
      await pump(tester, repository: sarahRepo(context: booked()));
      await tester.tap(find.byKey(const ValueKey('meeting-calendar')));
      await tester.pumpAndSettle();
      final uri = launched.single;
      expect(uri.host, 'calendar.google.com');
      expect(uri.queryParameters['action'], 'TEMPLATE');
      expect(uri.queryParameters['text'], '1:1 Council Pre-Flight Sync');
      final dates = uri.queryParameters['dates']!.split('/');
      expect(DateTime.parse(dates[1]).difference(DateTime.parse(dates[0])), const Duration(minutes: 20));
      expect(DateTime.parse(dates[0]), DateTime(2026, 10, 26, 16).toUtc());
    });

    testWidgets("the Meet pill opens the thread's own record, and is not offered when there is none", (tester) async {
      await pump(tester, repository: sarahRepo(context: booked()));
      expect(find.byKey(const ValueKey('meet')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('meet')));
      await tester.pumpAndSettle();
      expect(routed.length + site.length, 1, reason: "the purchase's page, through the router or the website");
      await tester.pumpWidget(const SizedBox());
      await pump(tester);
      expect(find.byKey(const ValueKey('meet')), findsNothing);
    });
  });

  group("the composer's pills and the draft", () {
    testWidgets('a hint, the paperclip, RFQ, the emoji pill, and no microphone', (tester) async {
      await pump(tester);
      expect(
        find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'Write a message or attach RFP...'),
        findsOneWidget,
      );
      for (final key in ['attach', 'share-record', 'emoji', 'send']) {
        expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
      }
      expect(find.text('RFQ'), findsOneWidget);
      expect(find.byTooltip('Record'), findsNothing);
    });

    testWidgets('the smiley offers common emoji and puts the one chosen in at the cursor', (tester) async {
      await pump(tester);
      await tester.enterText(composer(), 'abcd');
      final field = tester.widget<TextField>(composer());
      field.controller!.selection = const TextSelection.collapsed(offset: 2);
      await tester.tap(find.byKey(const ValueKey('emoji')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('emoji-👍')));
      await tester.pumpAndSettle();
      expect(field.controller!.text, 'ab👍cd');
      expect(field.controller!.selection.baseOffset, 4);
    });

    testWidgets('a draft is kept a second after typing stops, restored on reopening, and cleared by sending', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Draft Saved'), findsNothing);
      await tester.enterText(composer(), 'Half a thought');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Draft Saved'), findsNothing, reason: 'still typing');
      expect(DraftStore.of('sarah'), isNull);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Draft Saved'), findsOneWidget);
      expect(DraftStore.of('sarah'), 'Half a thought');

      // Leave and come back: the words are where they were.
      await tester.pumpWidget(const SizedBox());
      await pump(tester);
      expect(tester.widget<TextField>(composer()).controller!.text, 'Half a thought');
      expect(find.text('Draft Saved'), findsOneWidget);

      await tester.tap(sendButton());
      await tester.pumpAndSettle();
      expect(repo.sent.single.body, 'Half a thought');
      expect(DraftStore.of('sarah'), isNull);
      expect(find.text('Draft Saved'), findsNothing);
      expect(tester.widget<TextField>(composer()).controller!.text, isEmpty);
    });

    testWidgets('leaving at once keeps what was typed, and an emptied box keeps nothing', (tester) async {
      await pump(tester);
      await tester.enterText(composer(), 'Typed and left');
      await tester.pumpWidget(const SizedBox());
      expect(DraftStore.of('sarah'), 'Typed and left');

      await pump(tester);
      await tester.enterText(composer(), '');
      await tester.pumpWidget(const SizedBox());
      expect(DraftStore.of('sarah'), isNull);
    });

    testWidgets('a draft belongs to its conversation', (tester) async {
      DraftStore.save('someone-else', 'not here');
      await pump(tester);
      expect(tester.widget<TextField>(composer()).controller!.text, isEmpty);
    });
  });

  group("the designed thread (demo content) at a phone's width", () {
    final day = DateTime(2026, 4, 16, 10, 50);

    for (final width in [390.0, 360.0]) {
      testWidgets('draws whole at ${width.toInt()} dp: no overflow, every piece of the design', (tester) async {
        final demo = DemoMessagingRepository(now: day);
        tester.view.physicalSize = Size(width, 1500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: ConversationScreen(conversationId: 'c-radhika', repository: demo, poll: false, clock: () => day),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Dr. Radhika Iyer'), findsWidgets);
        expect(find.text('Chair, Net-Zero Council • Bengaluru'), findsOneWidget);
        expect(find.text('today, april 16'), findsOneWidget);
        expect(find.text('10:14 AM'), findsOneWidget);
        expect(find.text('10:30 AM'), findsOneWidget);
        expect(find.text('10:42 AM'), findsOneWidget);
        expect(find.text('Standardized_Green_SLA_Rider_v2.4.docx'), findsOneWidget);
        expect(find.text('680 KB • DOCX'), findsOneWidget);
        expect(find.text('1:1 Council Pre-Flight Sync'), findsOneWidget);
        expect(find.text('Tomorrow, 4:00 PM – 4:20 PM IST'), findsOneWidget);
        expect(find.text('RFQ'), findsOneWidget);
        expect(find.text('Meet'), findsOneWidget);
        expect(find.byKey(const ValueKey('tick-seen')), findsOneWidget);
      });
    }
  });

  group('the conversation controller', () {
    test('timeline: days, business events inside the loaded window only, pending messages last', () async {
      final repository = sarahRepo(
        context: ConversationContext(
          kind: ConversationKind.requirement,
          requirement: const ContextRequirement(id: 'r1', title: 'T', kind: 'RFQ', status: 'PUBLISHED'),
          events: [
            ThreadEvent(id: 'ev1', type: 'BID_SUBMITTED', at: minutesAgo(1600), amount: 1000),
            ThreadEvent(id: 'ev0', type: 'BID_SUBMITTED', at: minutesAgo(9999)),
          ],
        ),
      );
      final c = ConversationController(repository, conversationId: 'sarah', viewerId: meId, clock: () => testNow);
      await c.start();
      await Future<void>.delayed(Duration.zero);
      final kinds = [for (final i in c.timeline) i.runtimeType.toString()];
      expect(kinds.where((k) => k == 'DayItem'), hasLength(4), reason: 'the earliest event, then the three days');
      expect(
        kinds.where((k) => k == 'EventItem'),
        hasLength(2),
        reason: 'no earlier history is held back: both events show',
      );
      c.dispose();
    });

    test('an event older than the window is left out while earlier messages are still to load', () async {
      final many = [for (var i = 0; i < 60; i++) msg('m$i', 'sarah', sarah, 'x', ago: 100 - i, read: true)];
      final repository = FakeMessagingRepository(
        rows: [convo('sarah')],
        threads: {'sarah': many},
        contexts: {
          'sarah': ConversationContext(
            kind: ConversationKind.requirement,
            events: [ThreadEvent(id: 'old', type: 'BID_SUBMITTED', at: minutesAgo(5000))],
          ),
        },
      );
      final c = ConversationController(repository, conversationId: 'sarah', viewerId: meId, clock: () => testNow);
      await c.start();
      await Future<void>.delayed(Duration.zero);
      expect(c.hasMore, isTrue);
      expect(c.timeline.whereType<EventItem>(), isEmpty);
      c.dispose();
    });

    test('ensureLoaded pages back until the message is held, and stops when it is not there', () async {
      final many = [for (var i = 0; i < 130; i++) msg('m$i', 'sarah', sarah, 'x', ago: 400 - i, read: true)];
      final repository = FakeMessagingRepository(rows: [convo('sarah')], threads: {'sarah': many});
      final c = ConversationController(repository, conversationId: 'sarah', viewerId: meId, clock: () => testNow);
      await c.start();
      expect(await c.ensureLoaded('m119'), isTrue, reason: 'already held');
      expect(await c.ensureLoaded('m5'), isTrue);
      expect(c.messages.first.id, 'm0');
      expect(await c.ensureLoaded('nope'), isFalse);
      c.dispose();
    });

    test('problemWith: empty and too long, but a file alone is a message', () async {
      final repository = sarahRepo();
      final c = ConversationController(repository, conversationId: 'sarah', viewerId: meId, clock: () => testNow);
      expect(c.problemWith('   '), 'Write a message or attach a file.');
      expect(c.problemWith('x' * 4001), 'A message can be at most 4000 characters.');
      expect(c.problemWith('ok'), isNull);
      c.dispose();
    });
  });
}

class _CountSource implements UnreadSource {
  int messageReads = 0;
  @override
  Future<int> notifications() async => 0;
  @override
  Future<int> messages() async {
    messageReads++;
    return 0;
  }
}
