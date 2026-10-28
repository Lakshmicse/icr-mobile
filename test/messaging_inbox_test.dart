import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/messaging/conversation_screen.dart';
import 'package:icr_mobile/features/messaging/inbox_controller.dart';
import 'package:icr_mobile/features/messaging/inbox_screen.dart';
import 'package:icr_mobile/features/messaging/messaging_models.dart';
import 'package:icr_mobile/features/messaging/messaging_repository.dart';
import 'package:icr_mobile/features/messaging/widgets/conversation_tile.dart';
import 'package:icr_mobile/features/notifications/unread_counts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'helpers/fonts.dart';
import 'messaging_fakes.dart';

/// Every control of the Messages list, tapped: the rows and how each says
/// what it is, the filters, search, pinned threads, star and pin, "mark all
/// read", the company inboxes, paging, polling and every refusal. What the
/// API does with each call is proved in `test/live/messaging_live_test.dart`.
void main() {
  setUpAll(loadAppFonts);

  const hrParty = ThreadParty(companyId: 'co-acme', name: 'Acme FM', topic: 'SALES', status: ThreadStatus.open);

  /// Seven threads of every shape the list draws.
  List<Conversation> sample() => [
    convo(
      'sarah',
      unread: 2,
      last: msg('sarah-5', 'sarah', sarah, 'Did you get a chance to look at it?', ago: 35),
      updatedAgo: 35,
    ),
    convo(
      'company',
      people: const [me],
      kind: ConversationKind.company,
      counterpart: globalInfra,
      unread: 1,
      parties: const [ThreadParty(companyId: 'co-gi', name: 'Global Infra Solutions', topic: 'CAREERS')],
      last: msg('co-3', 'company', priya, 'We would like to set up an intro call.', ago: 300, company: globalInfra),
      updatedAgo: 300,
    ),
    convo(
      'rfq',
      people: const [me],
      kind: ConversationKind.requirement,
      counterpart: careSupplier,
      contextLabel: 'Annual Housekeeping Contract',
      title: 'Annual Housekeeping Contract',
      unread: 1,
      last: msg('rfq-2', 'rfq', priya, 'Our rate is ₹18,500 per person.', ago: 1500, company: careSupplier),
      updatedAgo: 1500,
    ),
    convo(
      'david',
      people: const [me, david],
      starred: true,
      pinned: true,
      last: msg('david-4', 'david', me, "Let's talk next week.", ago: 4000, read: true),
      updatedAgo: 4000,
    ),
    convo(
      'file',
      people: const [me, priya],
      last: msg('f-1', 'file', priya, '', ago: 5000, attachment: 'Quote.pdf', attachmentMime: 'application/pdf'),
      updatedAgo: 5000,
    ),
    convo(
      'gone',
      people: const [me, david],
      kind: ConversationKind.mentorship,
      last: msg('g-1', 'gone', david, 'oops', ago: 9000, deleted: true),
      updatedAgo: 9000,
    ),
    convo('empty', people: const [me, priya], kind: ConversationKind.direct, updatedAgo: 20000),
  ];

  late FakeMessagingRepository repo;
  late UnreadCounts counts;
  late _FakeSource source;

  /// Opens the inbox on [repository] (or a fresh fake of [sample]).
  Future<void> pump(
    WidgetTester tester, {
    FakeMessagingRepository? repository,
    String? initialInbox,
    bool poll = false,
    Size size = const Size(390, 1100),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo = repository ?? FakeMessagingRepository(rows: sample());
    source = _FakeSource();
    counts = UnreadCounts(source, interval: const Duration(hours: 1));
    addTearDown(counts.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<UnreadCounts>.value(
        value: counts,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: InboxScreen(repository: repo, initialInbox: initialInbox, poll: poll, clock: () => testNow),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder tile(String id) => find.byKey(ValueKey('conversation-$id'));
  Finder inTile(String id, Finder f) => find.descendant(of: tile(id), matching: f);
  Finder chip(String key) => find.byKey(ValueKey(key));

  /// The last listing the screen asked for.
  String lastList() => repo.calls.lastWhere((c) => c.startsWith('conversations'));

  group('the rows', () {
    testWidgets('each says who it is with, why it exists, the last word and when', (tester) async {
      await pump(tester);

      // A person: their name, "Direct", the preview, 2:25 pm, and the two waiting.
      expect(inTile('sarah', find.text('Sarah Jenkins')), findsOneWidget);
      expect(inTile('sarah', find.text('Did you get a chance to look at it?')), findsOneWidget);
      expect(inTile('sarah', find.text('2:25 pm')), findsOneWidget);
      expect(inTile('sarah', find.text('2')), findsOneWidget, reason: 'the unread count');
      expect(inTile('sarah', find.text('Direct')), findsOneWidget);

      // A company's inbox thread: the company's name, its topic, and who wrote it as the company.
      expect(inTile('company', find.text('Global Infra Solutions')), findsOneWidget);
      expect(inTile('company', find.text('Company')), findsOneWidget);
      expect(inTile('company', find.text('We would like to set up an intro call.')), findsOneWidget);

      // A requirement: the company on the other side, the badge, the requirement beside it.
      expect(inTile('rfq', find.text('Bengaluru Care 101')), findsOneWidget);
      expect(inTile('rfq', find.text('Requirement')), findsOneWidget);
      expect(inTile('rfq', find.text('Annual Housekeeping Contract')), findsOneWidget);
      expect(inTile('rfq', find.text('Yesterday')), findsOneWidget);
    });

    testWidgets('your own last word reads "You:", an attachment reads as its file, a withdrawn message says so', (
      tester,
    ) async {
      await pump(tester);
      await tester.scrollUntilVisible(tile('gone'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text("You: Let's talk next week."), findsOneWidget);
      expect(find.text('Quote.pdf'), findsOneWidget);
      expect(find.byIcon(Icons.attach_file), findsNothing);
      expect(inTile('gone', find.text('Message deleted')), findsOneWidget);
      expect(inTile('empty', find.text('No messages yet')), findsOneWidget);
    });

    testWidgets('unread is said by weight, a dot and a count, and read out as one sentence', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      expect(
        tester.getSemantics(tile('sarah')).label,
        'Sarah Jenkins, 2 unread, Direct, Did you get a chance to look at it?, 2:25 pm',
      );
      expect(tester.getSemantics(tile('company')).label, startsWith('Global Infra Solutions, 1 unread, Company, '));
      expect(tester.getSemantics(tile('file')).label, isNot(contains('unread')));
      final unreadName = tester.widget<Text>(inTile('sarah', find.text('Sarah Jenkins')));
      final readName = tester.widget<Text>(find.descendant(of: tile('file'), matching: find.text('Priya Sharma')));
      expect(unreadName.style!.fontWeight, FontWeight.w700);
      expect(readName.style!.fontWeight, FontWeight.w600);
      semantics.dispose();
    });

    testWidgets('a pinned thread is listed above the rest under "Pinned", a starred one carries its star', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('PINNED'), findsOneWidget);
      expect(find.text('ALL MESSAGES'), findsOneWidget);
      expect(tester.getTopLeft(tile('david')).dy, lessThan(tester.getTopLeft(tile('sarah')).dy));
      expect(inTile('david', find.byIcon(Icons.star_rounded)), findsOneWidget);
      expect(inTile('david', find.byIcon(LucideIcons.pin)), findsOneWidget);
      expect(inTile('sarah', find.byIcon(Icons.star_rounded)), findsNothing);
      expect(repo.calls, contains('pinned'));
    });

    testWidgets('a direct thread titled for a job names the job beside its badge', (tester) async {
      await pump(
        tester,
        repository: FakeMessagingRepository(
          rows: [
            convo(
              'job',
              people: const [me, priya],
              title: 'Senior Facilities Manager · Global Infra Solutions',
              last: msg('j-1', 'job', priya, 'Thanks for your interest.', ago: 90),
            ),
          ],
        ),
      );
      expect(inTile('job', find.text('Priya Sharma')), findsOneWidget);
      expect(inTile('job', find.text('Senior Facilities Manager · Global Infra Solutions')), findsOneWidget);
    });
  });

  group('states', () {
    testWidgets('loading shows a spinner, then the list', (tester) async {
      final gate = Completer<void>();
      final repository = FakeMessagingRepository(rows: sample())..holds['conversations'] = gate;
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: InboxScreen(repository: repository, poll: false, clock: () => testNow),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ConversationTile), findsWidgets);
    });

    testWidgets('a failed load says why and Retry loads it', (tester) async {
      final repository = FakeMessagingRepository(rows: sample())
        ..errors['conversations'] = ApiError('The server is busy.', statusCode: 503);
      await pump(tester, repository: repository);
      expect(find.text('Your messages could not be loaded.'), findsOneWidget);
      expect(find.text('The server is busy.'), findsOneWidget);
      repository.errors.remove('conversations');
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationTile), findsWidgets);
    });

    testWidgets('no messages at all: the empty state offers "New message"', (tester) async {
      await pump(tester, repository: FakeMessagingRepository());
      expect(find.text('No messages yet'), findsOneWidget);
      expect(find.text('New message'), findsOneWidget);
    });

    testWidgets('nothing unread, nothing starred, nothing of a kind: each says so', (tester) async {
      await pump(
        tester,
        repository: FakeMessagingRepository(rows: [convo('only', last: msg('o', 'only', sarah, 'hi', read: true))]),
      );
      await tester.tap(chip('filter-unread'));
      await tester.pumpAndSettle();
      expect(find.text("You're all caught up"), findsOneWidget);
      await tester.tap(chip('filter-starred'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing starred'), findsOneWidget);
      await tester.tap(chip('filter-all'));
      await tester.pumpAndSettle();
      await tester.tap(chip('kind-requirement'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.text('No requirements and bids conversations.'), findsOneWidget);
    });

    testWidgets('pull to refresh reads the list and the inboxes again', (tester) async {
      await pump(tester);
      final before = repo.listCalls;
      await tester.fling(find.byType(CustomScrollView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(repo.listCalls, before + 1);
      expect(repo.calls.where((c) => c == 'inboxes').length, greaterThanOrEqualTo(2));
    });
  });

  group('filters', () {
    testWidgets('Unread, Starred and All ask the API for each and list what it answers', (tester) async {
      await pump(tester);
      expect(lastList(), contains('filter=all'));
      expect(lastList(), contains('excludePinned=true'));

      await tester.tap(chip('filter-unread'));
      await tester.pumpAndSettle();
      expect(lastList(), contains('filter=unread'));
      expect(lastList(), contains('excludePinned=false'), reason: 'pinned threads are not set apart off the All tab');
      expect(find.byType(ConversationTile), findsNWidgets(3));

      await tester.tap(chip('filter-starred'));
      await tester.pumpAndSettle();
      expect(lastList(), contains('filter=starred'));
      expect(find.byType(ConversationTile), findsOneWidget);
      expect(tile('david'), findsOneWidget);

      await tester.tap(chip('filter-all'));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationTile), findsNWidgets(7));
    });

    testWidgets('a kind narrows the list; the same kind again clears it', (tester) async {
      await pump(tester);
      await tester.ensureVisible(chip('kind-requirement'));
      await tester.tap(chip('kind-requirement'));
      await tester.pumpAndSettle();
      expect(lastList(), contains('kind=requirement'));
      expect(lastList(), contains('excludePinned=false'), reason: 'a pinned thread of the kind must stay in the list');
      expect(find.byType(ConversationTile), findsOneWidget);
      expect(tile('rfq'), findsOneWidget);
      expect(find.text('PINNED'), findsNothing, reason: "the pinned list is the All tab's");

      await tester.tap(chip('kind-requirement'));
      await tester.pumpAndSettle();
      expect(lastList(), contains('kind=null'));
      expect(find.byType(ConversationTile), findsNWidgets(7));

      await tester.ensureVisible(chip('kind-mentorship'));
      await tester.tap(chip('kind-mentorship'));
      await tester.pumpAndSettle();
      expect(tile('gone'), findsOneWidget);
      await tester.ensureVisible(chip('kind-direct'));
      await tester.tap(chip('kind-direct'));
      await tester.pumpAndSettle();
      expect(lastList(), contains('kind=direct'));
      expect(tile('gone'), findsNothing);
    });

    testWidgets('the Unread chip carries the count while it is not the one on', (tester) async {
      await pump(
        tester,
        repository: FakeMessagingRepository(
          rows: sample(),
          inboxList: const [MessagingInbox(id: MessagingInbox.personalId, personal: true, unread: 4)],
        ),
      );
      expect(find.descendant(of: chip('filter-unread'), matching: find.text('4')), findsOneWidget);
      await tester.tap(chip('filter-unread'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: chip('filter-unread'), matching: find.text('4')), findsNothing);
    });
  });

  group('search', () {
    testWidgets('typing searches people, companies and message text a moment after the person pauses', (tester) async {
      repo = FakeMessagingRepository(rows: sample())
        ..hits = [
          MessageSearchHit(
            messageId: 'david-1',
            conversationId: 'david',
            participants: const [me, david],
            sender: david,
            snippet: '…the checklist we use for new campus sites.',
            createdAt: minutesAgo(5000),
          ),
        ];
      await pump(tester, repository: repo);
      await tester.enterText(find.byType(TextField).first, 'checklist');
      await tester.pump(const Duration(milliseconds: 200));
      expect(repo.calls.where((c) => c.contains('search="checklist"')), isEmpty, reason: 'still typing');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(repo.calls.where((c) => c.contains('search="checklist"')), isNotEmpty);
      expect(repo.calls, contains('search q="checklist" inbox=personal'));
      expect(find.text('MESSAGES'), findsOneWidget);
      expect(find.textContaining('checklist we use'), findsOneWidget);
      expect(find.byKey(const ValueKey('hit-david-1')), findsOneWidget);
    });

    testWidgets('a name finds the thread; no match says so with the words searched', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField).first, 'sarah');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationTile), findsOneWidget);
      expect(tile('sarah'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'zzzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('No matches'), findsOneWidget);
      expect(find.textContaining('"zzzz"'), findsOneWidget);
    });

    testWidgets('Clear search brings every thread back', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField).first, 'sarah');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationTile), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationTile), findsNWidgets(7));
      expect(lastList(), contains('search=""'));
    });

    testWidgets('a hit opens its thread on the message', (tester) async {
      final repository =
          FakeMessagingRepository(
              rows: sample(),
              threads: {
                'david': [
                  msg('david-1', 'david', david, 'Here is the checklist', ago: 5000),
                  msg('david-4', 'david', me, 'Thanks', ago: 4000),
                ],
              },
              contexts: {'david': ConversationContext(kind: ConversationKind.direct, person: david)},
            )
            ..hits = [
              MessageSearchHit(
                messageId: 'david-1',
                conversationId: 'david',
                participants: const [me, david],
                sender: david,
                snippet: 'Here is the checklist',
                createdAt: minutesAgo(5000),
              ),
            ];
      await pump(tester, repository: repository);
      await tester.enterText(find.byType(TextField).first, 'checklist');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('hit-david-1')));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationScreen), findsOneWidget);
      expect(repository.calls.where((c) => c.startsWith('thread david')), isNotEmpty);
    });
  });

  group('opening a thread', () {
    testWidgets('a tap opens it from the row already in hand, and the row has lost its count on coming back', (
      tester,
    ) async {
      final repository = FakeMessagingRepository(
        rows: sample(),
        threads: {
          'sarah': [msg('sarah-5', 'sarah', sarah, 'Did you get a chance to look at it?', ago: 35)],
        },
        contexts: {'sarah': const ConversationContext(kind: ConversationKind.direct, person: sarah)},
      );
      await pump(tester, repository: repository);
      await tester.tap(tile('sarah'));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationScreen), findsOneWidget);
      expect(repository.calls, contains('markRead sarah as=null'));

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(InboxScreen), findsOneWidget);
      expect(inTile('sarah', find.text('2')), findsNothing, reason: 'its count went with the read');
      expect(source.messageReads, greaterThan(0), reason: 'the app-wide badge was asked to read again');
    });
  });

  group('star and pin (press and hold)', () {
    Future<void> hold(WidgetTester tester, String id) async {
      await tester.longPress(tile(id));
      await tester.pumpAndSettle();
    }

    testWidgets('Star saves at once and the row carries its star', (tester) async {
      await pump(tester);
      await hold(tester, 'sarah');
      await tester.tap(find.byKey(const ValueKey('menu-star')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('setPreference sarah starred=true pinned=null'));
      expect(inTile('sarah', find.byIcon(Icons.star_rounded)), findsOneWidget);
    });

    testWidgets('Pin moves it to the Pinned list; Unpin moves it back', (tester) async {
      await pump(tester);
      await hold(tester, 'sarah');
      await tester.tap(find.byKey(const ValueKey('menu-pin')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('setPreference sarah starred=null pinned=true'));
      expect(tester.getTopLeft(tile('sarah')).dy, lessThan(tester.getTopLeft(tile('company')).dy));
      expect(find.byIcon(LucideIcons.pin), findsNWidgets(2));

      await hold(tester, 'sarah');
      expect(find.text('Unpin from top'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('menu-pin')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('setPreference sarah starred=null pinned=false'));
      expect(find.byIcon(LucideIcons.pin), findsOneWidget);
    });

    testWidgets('a refusal puts it back and shows the API\'s sentence', (tester) async {
      await pump(tester);
      repo.errors['setPreference'] = ApiError('You can pin at most ten conversations.', statusCode: 400);
      await hold(tester, 'sarah');
      await tester.tap(find.byKey(const ValueKey('menu-pin')));
      await tester.pumpAndSettle();
      expect(find.text('You can pin at most ten conversations.'), findsOneWidget);
      expect(find.byIcon(LucideIcons.pin), findsOneWidget, reason: 'only the thread that was pinned before');
    });

    testWidgets('the menu says Remove star / Unpin for what already is', (tester) async {
      await pump(tester);
      await hold(tester, 'david');
      expect(find.text('Remove star'), findsOneWidget);
      expect(find.text('Unpin from top'), findsOneWidget);
    });
  });

  group('mark all as read', () {
    testWidgets('reads every thread, clears the counts and the badges, says so', (tester) async {
      await pump(
        tester,
        repository: FakeMessagingRepository(
          rows: sample(),
          inboxList: const [MessagingInbox(id: MessagingInbox.personalId, personal: true, unread: 4)],
        ),
      );
      final button = find.byKey(const ValueKey('mark-all-read'));
      expect(tester.widget<IconButton>(button).onPressed, isNotNull);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(repo.calls, contains('markAllRead inbox=personal'));
      expect(find.text('All marked as read'), findsOneWidget);
      expect(inTile('sarah', find.text('2')), findsNothing);
      expect(tester.widget<IconButton>(button).onPressed, isNull, reason: 'nothing left to read');
    });

    testWidgets('a refusal brings every count back and shows why', (tester) async {
      await pump(
        tester,
        repository: FakeMessagingRepository(
          rows: sample(),
          inboxList: const [MessagingInbox(id: MessagingInbox.personalId, personal: true, unread: 4)],
        )..errors['markAllRead'] = ApiError('Try again later.', statusCode: 500),
      );
      await tester.tap(find.byKey(const ValueKey('mark-all-read')));
      await tester.pumpAndSettle();
      expect(find.text('Try again later.'), findsOneWidget);
      expect(inTile('sarah', find.text('2')), findsOneWidget);
    });
  });

  group('paging', () {
    testWidgets('"Show more conversations" appends the next page without repeating a row', (tester) async {
      final many = [
        for (var i = 0; i < 30; i++)
          convo(
            'c$i',
            people: [
              me,
              ChatPerson(id: 'p$i', firstName: 'Person', lastName: '$i'),
            ],
            updatedAgo: i + 1,
          ),
      ];
      await pump(
        tester,
        repository: FakeMessagingRepository(rows: many),
        size: const Size(390, 6000),
      );
      expect(find.byType(ConversationTile), findsNWidgets(25));
      expect(find.byKey(const ValueKey('load-more')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('load-more')));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationTile), findsNWidgets(30));
      expect(find.byKey(const ValueKey('load-more')), findsNothing);
      expect(repo.calls.any((c) => c.startsWith('conversations page=2')), isTrue);
    });
  });

  group('polling', () {
    testWidgets('a thread that arrives is on the list within half a minute, with no spinner', (tester) async {
      await pump(tester, poll: true);
      expect(tile('fresh'), findsNothing);
      repo.rows = [
        convo(
          'fresh',
          people: const [me, priya],
          unread: 1,
          last: msg('fr-1', 'fresh', priya, 'Hello from Priya', ago: 1),
          updatedAgo: 1,
        ),
        ...repo.rows,
      ];
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(tile('fresh'), findsOneWidget);
      expect(find.text('Hello from Priya'), findsOneWidget);
    });

    testWidgets('it stops while the app is in the background and reads again on return', (tester) async {
      await pump(tester, poll: true);
      for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      final before = repo.listCalls;
      await tester.pump(const Duration(seconds: 95));
      expect(repo.listCalls, before, reason: 'nothing read while in the background');
      for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pumpAndSettle();
      expect(repo.listCalls, greaterThan(before));
    });

    testWidgets('a poll that fails keeps what is on screen and says nothing', (tester) async {
      await pump(tester, poll: true);
      repo.errors['conversations'] = ApiError('down');
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationTile), findsWidgets);
      expect(find.text('Your messages could not be loaded.'), findsNothing);
    });
  });

  group("the company inboxes (a seller's own and the companies they answer for)", () {
    final acmeThread = convo(
      'acme-1',
      people: const [me],
      kind: ConversationKind.requirement,
      counterpart: globalInfra,
      title: 'Facade cleaning',
      contextLabel: 'Facade cleaning',
      asCompanyId: 'co-acme',
      unread: 2,
      parties: const [hrParty],
      last: msg('ac-1', 'acme-1', me, 'Can you quote?', ago: 50),
      updatedAgo: 50,
    );
    final acmeDone = convo(
      'acme-2',
      people: const [me, priya],
      asCompanyId: 'co-acme',
      parties: const [
        ThreadParty(companyId: 'co-acme', name: 'Acme FM', topic: 'PROCUREMENT', status: ThreadStatus.done),
      ],
      last: msg('ac-2', 'acme-2', priya, 'Thanks, all sorted.', ago: 700, read: true),
      updatedAgo: 700,
    );
    List<Conversation> withCompany() => [...sample(), acmeThread, acmeDone];
    List<MessagingInbox> twoInboxes({int acmeUnread = 2}) => [
      const MessagingInbox(id: MessagingInbox.personalId, personal: true, unread: 4),
      MessagingInbox(
        id: 'co-acme',
        personal: false,
        name: 'Acme FM',
        topics: const ['SALES', 'PROCUREMENT'],
        unread: acmeUnread,
      ),
    ];

    testWidgets('with no company inbox the switcher is not drawn', (tester) async {
      await pump(tester);
      expect(chip('inbox-personal'), findsNothing);
      expect(chip('view-open'), findsNothing);
    });

    testWidgets('the switcher lists My messages and each company, with the other inbox\'s unread count', (
      tester,
    ) async {
      await pump(
        tester,
        repository: FakeMessagingRepository(rows: withCompany(), inboxList: twoInboxes()),
      );
      expect(chip('inbox-personal'), findsOneWidget);
      expect(chip('inbox-co-acme'), findsOneWidget);
      expect(find.text('Acme FM'), findsOneWidget);
      expect(find.descendant(of: chip('inbox-co-acme'), matching: find.text('2')), findsOneWidget);
      expect(
        find.descendant(of: chip('inbox-personal'), matching: find.text('4')),
        findsNothing,
        reason: 'the inbox on screen',
      );
    });

    testWidgets('picking a company reads its own list through Open, Unread, Mine, Done and Spam, and its topics', (
      tester,
    ) async {
      await pump(
        tester,
        repository: FakeMessagingRepository(rows: withCompany(), inboxList: twoInboxes()),
      );
      await tester.tap(chip('inbox-co-acme'));
      await tester.pumpAndSettle();
      expect(lastList(), contains('inbox=co-acme'));
      expect(lastList(), contains('view=open'));
      expect(find.byType(ConversationTile), findsOneWidget);
      expect(tile('acme-1'), findsOneWidget);
      // The company's inbox draws its own filters, not the person's.
      expect(chip('filter-unread'), findsNothing);
      for (final v in ['open', 'unread', 'mine', 'done', 'spam']) {
        expect(chip('view-$v'), findsOneWidget);
      }

      await tester.tap(chip('view-done'));
      await tester.pumpAndSettle();
      expect(lastList(), contains('view=done'));
      expect(tile('acme-2'), findsOneWidget);
      expect(tile('acme-1'), findsNothing);

      await tester.tap(chip('view-mine'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing assigned to you'), findsOneWidget);

      await tester.tap(chip('view-open'));
      await tester.pumpAndSettle();
      await tester.tap(chip('topic-PROCUREMENT'));
      await tester.pumpAndSettle();
      expect(lastList(), contains('topic=PROCUREMENT'));
      expect(find.text('Nothing waiting in this inbox'), findsOneWidget);
      await tester.tap(chip('topic-all'));
      await tester.pumpAndSettle();
      expect(lastList(), contains('topic=null'));
      expect(tile('acme-1'), findsOneWidget);
    });

    testWidgets('a company thread opens as that company, and its row says which topic it is in', (tester) async {
      final repository = FakeMessagingRepository(
        rows: withCompany(),
        inboxList: twoInboxes(),
        threads: {
          'acme-1': [msg('ac-1', 'acme-1', me, 'Can you quote?', ago: 50)],
        },
      );
      await pump(tester, repository: repository);
      await tester.tap(chip('inbox-co-acme'));
      await tester.pumpAndSettle();
      expect(inTile('acme-1', find.text('Facade cleaning')), findsOneWidget);
      await tester.tap(tile('acme-1'));
      await tester.pumpAndSettle();
      expect(repository.calls, contains('thread acme-1 take=50 as=co-acme'));
    });

    testWidgets('opening on a company inbox starts there', (tester) async {
      await pump(
        tester,
        repository: FakeMessagingRepository(rows: withCompany(), inboxList: twoInboxes()),
        initialInbox: 'co-acme',
      );
      expect(lastList(), contains('inbox=co-acme'));
      expect(tile('acme-1'), findsOneWidget);
    });

    testWidgets('an inbox the person no longer answers for falls back to their own', (tester) async {
      final repository = FakeMessagingRepository(rows: withCompany(), inboxList: twoInboxes());
      await pump(tester, repository: repository);
      await tester.tap(chip('inbox-co-acme'));
      await tester.pumpAndSettle();
      repository.inboxList = [const MessagingInbox(id: MessagingInbox.personalId, personal: true, unread: 4)];
      await tester.fling(find.byType(CustomScrollView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(lastList(), contains('inbox=personal'));
      expect(chip('inbox-co-acme'), findsNothing);
    });
  });

  group('the inbox controller', () {
    InboxController make(FakeMessagingRepository repo, {VoidCallback? onRead}) =>
        InboxController(repo, viewerId: meId, clock: () => testNow, onRead: onRead);

    test('an inbox opens on its first view, with no filter carried over', () async {
      final repo = FakeMessagingRepository(
        rows: [],
        inboxList: const [
          MessagingInbox(id: MessagingInbox.personalId, personal: true, unread: 0),
          MessagingInbox(id: 'co-acme', personal: false, name: 'Acme FM', topics: ['SALES'], unread: 0),
        ],
      );
      final c = make(repo);
      await c.start();
      await c.setFilter(InboxFilter.unread);
      await c.setKind(InboxKind.mentorship);
      await c.setInbox('co-acme');
      expect(c.query.inbox, 'co-acme');
      expect(c.query.filter, InboxFilter.all);
      expect(c.query.kind, isNull);
      expect(c.query.view, CompanyInboxView.open);
      c.dispose();
    });

    test('a search of one character is not sent for message text', () async {
      final repo = FakeMessagingRepository(rows: sample());
      final c = make(repo);
      await c.start();
      await c.setSearch('s');
      expect(repo.calls.where((c) => c.startsWith('search')), isEmpty);
      await c.setSearch('sa');
      expect(repo.calls.where((c) => c.startsWith('search')), hasLength(1));
      c.dispose();
    });

    test('pinning keeps the pinned list and the rest apart; a refusal restores both', () async {
      final repo = FakeMessagingRepository(rows: sample());
      final c = make(repo);
      await c.start();
      expect(c.pinned.map((x) => x.id), ['david']);
      expect(c.conversations.any((x) => x.id == 'david'), isFalse);

      expect(await c.togglePin(c.conversations.first), isNull);
      expect(c.pinned.map((x) => x.id), ['sarah', 'david']);

      repo.errors['setPreference'] = ApiError('no', statusCode: 400);
      expect(await c.togglePin(c.pinned.first), 'no');
      expect(c.pinned.map((x) => x.id), ['sarah', 'david'], reason: 'put back');
      c.dispose();
    });

    test('onRead is told when everything was read', () async {
      var told = 0;
      final repo = FakeMessagingRepository(rows: sample());
      final c = make(repo, onRead: () => told++);
      await c.start();
      await c.markAllRead();
      expect(told, 1);
      c.dispose();
    });

    test('an older answer never overwrites a newer one (a slow search arrives after the next filter)', () async {
      final repo = FakeMessagingRepository(rows: sample());
      final gate = Completer<void>();
      final c = make(repo);
      await c.start();
      repo.holds['conversations'] = gate;
      final slow = c.setFilter(InboxFilter.unread);
      await Future<void>.delayed(Duration.zero);
      repo.holds.remove('conversations');
      await c.setFilter(InboxFilter.starred);
      gate.complete();
      await slow;
      expect(c.query.filter, InboxFilter.starred);
      expect(c.conversations.map((x) => x.id), ['david']);
      c.dispose();
    });
  });
}

class _FakeSource implements UnreadSource {
  int messageReads = 0;
  @override
  Future<int> notifications() async => 0;
  @override
  Future<int> messages() async {
    messageReads++;
    return 0;
  }
}
