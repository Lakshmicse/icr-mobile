import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/library/widgets/document_viewer_screen.dart';
import 'package:icr_mobile/features/support/api_support_repository.dart';
import 'package:icr_mobile/features/support/demo_support_repository.dart';
import 'package:icr_mobile/features/support/raise_ticket_sheet.dart';
import 'package:icr_mobile/features/support/support_models.dart';
import 'package:icr_mobile/features/support/support_repository.dart';
import 'package:icr_mobile/features/support/support_routes.dart';
import 'package:icr_mobile/features/support/support_screen.dart';
import 'package:icr_mobile/features/support/support_words.dart';
import 'package:icr_mobile/features/support/ticket_screen.dart';

import 'helpers/account_harness.dart';
import 'helpers/fonts.dart';

/// The support desk: "Help & Support" (the member's requests under a status tab and a search, the common questions,
/// the ICR account manager), one request's thread (banners, messages, history, reply, reopen, rating), and the
/// form that raises one. The website's `/support`, `/support/[id]` and `RaiseTicketDialog`, over a fake API.
void main() {
  setUpAll(loadAppFonts);

  final now = DateTime.now().toUtc();
  String ago(Duration d) => now.subtract(d).toIso8601String();

  Map<String, dynamic> ticketJson({
    String id = 't1',
    int reference = 12,
    String subject = 'Payment taken twice for the Gold plan',
    String category = 'BILLING_PAYMENTS',
    String status = 'OPEN',
    int messageCount = 3,
    String? contextLabel,
    String? contextHref,
    String? firstRespondedAt,
    int? ratingScore,
    bool reopenable = false,
    int firstResponseHours = 12,
    List<Map<String, dynamic>>? messages,
    List<Map<String, dynamic>>? events,
  }) => {
    'id': id,
    'reference': reference,
    'subject': subject,
    'category': category,
    'status': status,
    'priority': 'NORMAL',
    'contextType': contextLabel == null ? 'NONE' : 'MENTORSHIP',
    'contextId': null,
    'contextLabel': contextLabel,
    'contextHref': contextHref,
    'firstResponseHours': firstResponseHours,
    'firstRespondedAt': firstRespondedAt,
    'resolvedAt': null,
    'closedAt': null,
    'ratingScore': ratingScore,
    'reopenable': reopenable,
    'messages': ?messages,
    'events': ?events,
    'messageCount': messageCount,
    'lastActivityAt': ago(const Duration(hours: 5)),
    'createdAt': ago(const Duration(days: 3)),
  };

  Map<String, dynamic> message(
    String id,
    String body, {
    bool staff = false,
    bool icr = false,
    List<Map<String, dynamic>> attachments = const [],
  }) => {
    'id': id,
    'author': icr
        ? null
        : staff
        ? {'id': 'staff', 'firstName': 'Asha', 'lastName': 'Nair', 'avatarUrl': null}
        : {'id': 'u1', 'firstName': 'Sam', 'lastName': 'Rao', 'avatarUrl': null},
    'visibility': 'SHARED',
    'body': body,
    'attachments': attachments,
    'createdAt': ago(const Duration(hours: 4)),
  };

  Map<String, dynamic> page(List<Map<String, dynamic>> rows, {int number = 1, int totalPages = 1, int? total}) => {
    'data': rows,
    'meta': {
      'page': number,
      'limit': 20,
      'total': total ?? rows.length,
      'totalPages': totalPages,
      'hasNext': number < totalPages,
      'hasPrev': number > 1,
    },
  };

  late AccountHarness h;
  late SupportRepository repo;

  Future<void> start(WidgetTester tester, Widget Function() screen, {Map<String, ApiHandler> routes = const {}}) async {
    // A fresh screen each time, as the app always pushes one: no state carries over from the last.
    await tester.pumpWidget(const SizedBox());
    h = AccountHarness(routes: routes);
    await h.signIn(tester);
    usePhone(tester);
    repo = ApiSupportRepository(api: h.client);
    await tester.pumpWidget(h.app(screen()));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder, {Finder? within}) async {
    final scrollable = within ?? find.byType(Scrollable).first;
    await tester.scrollUntilVisible(finder, 250, scrollable: scrollable);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final target = find.byKey(Key(key));
    await reveal(tester, target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> typeKey(WidgetTester tester, String key, String text) async {
    final target = find.byKey(Key(key));
    await reveal(tester, target);
    await tester.enterText(target, text);
    await tester.pumpAndSettle();
  }

  /// The sheet's own scroll view (its text fields have scrollables of their own, which come later in the tree).
  Finder inSheet() => find.descendant(of: find.byType(RaiseTicketSheet), matching: find.byType(Scrollable)).first;

  group('the list', () {
    Map<String, ApiHandler> listRoutes({
      List<Map<String, dynamic>>? rows,
      Object? manager,
      List<Map<String, dynamic>>? faqs,
    }) => {
      'GET /support/tickets': (call) => page(
        rows ??
            [
              ticketJson(contextLabel: 'Gold plan', status: 'AWAITING_USER'),
              ticketJson(
                id: 't2',
                reference: 9,
                subject: 'Certificate will not download',
                category: 'LEARNING',
                status: 'NEW',
                messageCount: 1,
              ),
            ],
      ),
      'GET /support/faqs': (_) =>
          faqs ??
          [
            {
              'id': 'f1',
              'question': 'How do I get verified?',
              'answer': 'Submit your GST from the company profile.',
              'category': null,
            },
            {
              'id': 'f2',
              'question': 'Where is my invoice?',
              'answer': 'In your plan history.',
              'category': 'BILLING_PAYMENTS',
            },
          ],
      'GET /subscriptions/account-manager': (_) => manager,
      'POST /support/faqs/f1/view': (_) => null,
      'POST /support/faqs/f1/helpful': (_) => null,
    };

    Future<void> pump(
      WidgetTester tester,
      Map<String, ApiHandler> routes, {
      Future<void> Function(BuildContext, Uri)? opener,
    }) => start(
      tester,
      () => SupportScreen(repository: repo, searchDelay: Duration.zero, opener: opener),
      routes: routes,
    );

    testWidgets(
      'open requests first: subject, reference, category, what it is about, status, replies and last activity',
      (tester) async {
        await pump(tester, listRoutes());
        expect(find.text('Help & Support'), findsOneWidget);
        expect(find.text('Raise a request, follow it, and reply to the ICR team in one place.'), findsOneWidget);
        final first = h.api.where('GET /support/tickets').first;
        expect(first.query['status'], 'OPEN_ONLY');
        expect(first.query['page'], 1);
        expect(first.query['limit'], 20);
        expect(first.query.containsKey('search'), isFalse);

        expect(find.text('Payment taken twice for the Gold plan'), findsOneWidget);
        expect(find.text('ICR-12 · Billing & Payments · Gold plan'), findsOneWidget);
        expect(find.text('3 replies · 5h ago'), findsOneWidget);
        expect(find.text('ICR-9 · Learning Center'), findsOneWidget);
        expect(find.text('1 reply · 5h ago'), findsOneWidget);
        // The statuses read as the member reads them; the one waiting on them is told apart.
        expect(find.byKey(const Key('support.status.AWAITING_USER')), findsOneWidget);
        expect(find.text('Waiting on You'), findsNWidgets(2), reason: 'the tab and the chip');
        expect(find.byKey(const Key('support.status.NEW')), findsOneWidget);
      },
    );

    testWidgets('each tab asks for its own status: Open, Waiting on you, Resolved, All', (tester) async {
      await pump(tester, listRoutes());
      Future<String?> pick(String key) async {
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        return h.api.where('GET /support/tickets').last.query['status'] as String?;
      }

      expect(await pick('support.filter.waiting'), 'AWAITING_USER');
      expect(await pick('support.filter.resolved'), 'RESOLVED');
      expect(await pick('support.filter.all'), 'ALL');
      expect(await pick('support.filter.open'), 'OPEN_ONLY');
    });

    testWidgets('a search is sent as `search`, from the first page, whatever tab is open', (tester) async {
      await pump(tester, listRoutes());
      await tester.tap(find.byKey(const Key('support.filter.all')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('support.search')), '  invoice ');
      await tester.pumpAndSettle();
      final last = h.api.where('GET /support/tickets').last;
      expect(last.query['search'], 'invoice');
      expect(last.query['status'], 'ALL');
      expect(last.query['page'], 1);
    });

    testWidgets('a long list pages: Load more asks for the next page and adds to the end', (tester) async {
      var requested = <int>[];
      await pump(tester, {
        ...listRoutes(),
        'GET /support/tickets': (call) {
          final n = call.query['page'] as int;
          requested = [...requested, n];
          return page(
            [ticketJson(id: 'p$n', reference: n, subject: 'Request on page $n')],
            number: n,
            totalPages: 2,
            total: 2,
          );
        },
      });
      expect(find.text('Request on page 1'), findsOneWidget);
      await tapKey(tester, 'support.more');
      expect(requested, [1, 2]);
      expect(find.text('Request on page 1'), findsOneWidget);
      expect(find.text('Request on page 2'), findsOneWidget);
      expect(find.byKey(const Key('support.more')), findsNothing, reason: 'it was the last page');
    });

    testWidgets('nothing open says so and offers a new request; a search with no match says that instead', (
      tester,
    ) async {
      await pump(tester, {...listRoutes(), 'GET /support/tickets': (_) => page(const [])});
      expect(find.byKey(const Key('support.empty')), findsOneWidget);
      expect(find.text('No Open Requests'), findsOneWidget);
      expect(find.text('When something is not working, raise a request here and follow its progress.'), findsOneWidget);
      expect(find.byKey(const Key('support.empty.new')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('support.search')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No Matching Requests'), findsOneWidget);
      expect(find.byKey(const Key('support.empty.new')), findsNothing);
    });

    testWidgets('a failure says why with Try again, and Try again reads the list', (tester) async {
      var fail = true;
      await pump(tester, {
        ...listRoutes(),
        'GET /support/tickets': (_) => fail ? ApiReply.refusal(503, 'The server is busy.') : page([ticketJson()]),
      });
      expect(find.text('The server is busy.'), findsOneWidget);
      fail = false;
      await tester.tap(find.byKey(const Key('account.retry')));
      await tester.pumpAndSettle();
      expect(find.text('Payment taken twice for the Gold plan'), findsOneWidget);
    });

    testWidgets('common questions: opening one counts a view once; "This Was Helpful" counts and says Thanks', (
      tester,
    ) async {
      await pump(tester, listRoutes());
      expect(find.text('Common Questions'), findsOneWidget);
      expect(find.text('How do I get verified?'), findsOneWidget);
      expect(find.byKey(const Key('support.faq.answer.f1')), findsNothing, reason: 'closed until opened');
      expect(h.api.count('POST /support/faqs/f1/view'), 0);

      await tester.tap(find.byKey(const Key('support.faq.f1')));
      await tester.pumpAndSettle();
      expect(find.text('Submit your GST from the company profile.'), findsOneWidget);
      expect(h.api.count('POST /support/faqs/f1/view'), 1);
      // Closing and opening again is not a second view.
      await tester.tap(find.byKey(const Key('support.faq.f1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('support.faq.f1')));
      await tester.pumpAndSettle();
      expect(h.api.count('POST /support/faqs/f1/view'), 1);

      expect(find.text('This Was Helpful'), findsOneWidget);
      await tester.tap(find.byKey(const Key('support.faq.helpful.f1')));
      await tester.pumpAndSettle();
      expect(h.api.count('POST /support/faqs/f1/helpful'), 1);
      expect(find.text('Thank you'), findsOneWidget);
      expect(find.text('This Was Helpful'), findsNothing);
    });

    testWidgets('a counter that fails never breaks the page', (tester) async {
      await pump(tester, {...listRoutes(), 'POST /support/faqs/f1/view': (_) => ApiReply.refusal(500, 'no')});
      await tester.tap(find.byKey(const Key('support.faq.f1')));
      await tester.pumpAndSettle();
      expect(find.text('Submit your GST from the company profile.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the account manager card shows only when ICR has named one', (tester) async {
      await pump(tester, listRoutes());
      expect(find.byKey(const Key('support.manager')), findsNothing);

      final opened = <Uri>[];
      await pump(
        tester,
        listRoutes(
          manager: {
            'id': 'am1',
            'manager': {
              'id': 'u9',
              'firstName': 'Meera',
              'lastName': 'Iyer',
              'email': 'meera@icr.org.in',
              'phone': '+91 98450 00000',
              'avatarUrl': null,
            },
            'note': 'Your first call for anything.',
            'since': ago(const Duration(days: 30)),
          },
        ),
        opener: (context, uri) async => opened.add(uri),
      );
      expect(find.byKey(const Key('support.manager')), findsOneWidget);
      expect(find.text('Your ICR Account Manager'), findsOneWidget);
      expect(find.text('Meera Iyer'), findsOneWidget);
      expect(find.text('meera@icr.org.in · +91 98450 00000'), findsOneWidget);
      expect(find.text('Your first call for anything.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('support.manager.email')));
      await tester.pumpAndSettle();
      expect(opened.single.toString(), 'mailto:meera@icr.org.in');
    });

    testWidgets('a missing account manager (an empty answer) or failing furniture leaves the rest of the page alone', (
      tester,
    ) async {
      await pump(tester, {
        ...listRoutes(),
        'GET /subscriptions/account-manager': (_) => ApiReply.refusal(500, 'x'),
        'GET /support/faqs': (_) => ApiReply.refusal(500, 'x'),
      });
      expect(find.byKey(const Key('support.manager')), findsNothing);
      expect(find.byKey(const Key('support.faqs')), findsNothing);
      expect(find.text('Payment taken twice for the Gold plan'), findsOneWidget);
    });

    testWidgets('a pull reads the list again and keeps it on screen meanwhile', (tester) async {
      await pump(tester, listRoutes());
      final before = h.api.count('GET /support/tickets');
      await tester.fling(find.byKey(const Key('support.list')), const Offset(0, 400), 1000);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(h.api.count('GET /support/tickets'), before + 1);
      expect(find.text('Payment taken twice for the Gold plan'), findsOneWidget);
    });

    testWidgets('on a narrow phone nothing overflows, whatever the length of a subject or a name', (tester) async {
      const long =
          'A very long subject about a payment that was taken twice for the Gold plan on the second of November';
      h = AccountHarness(
        routes: {
          ...listRoutes(
            rows: [
              ticketJson(
                subject: long,
                contextLabel: 'Mentoring with a mentor whose name is quite long',
                status: 'AWAITING_USER',
              ),
            ],
            manager: {
              'manager': {
                'firstName': 'Meera',
                'lastName': 'Iyer-Venkataraman',
                'email': 'meera.iyer.venkataraman@icr.org.in',
                'phone': '+91 98450 00000',
              },
              'note': 'Your first call for anything at all, any day of the week.',
            },
          ),
          'GET /support/tickets/t1': (_) => ticketJson(
            subject: long,
            messages: [message('m1', long)],
            firstRespondedAt: ago(const Duration(days: 1)),
          ),
        },
      );
      await h.signIn(tester);
      usePhone(tester, width: 320, height: 640);
      repo = ApiSupportRepository(api: h.client);
      await tester.pumpWidget(h.app(SupportScreen(repository: repo, searchDelay: Duration.zero)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await reveal(tester, find.byKey(const Key('support.ticket.t1')));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('support.ticket.t1')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TicketScreen), findsOneWidget);
    });

    testWidgets('tapping a request opens its thread', (tester) async {
      await pump(tester, {
        ...listRoutes(),
        'GET /support/tickets/t1': (_) => ticketJson(
          contextLabel: 'Gold plan',
          status: 'AWAITING_USER',
          messages: [message('m1', 'I was charged twice.')],
        ),
      });
      await tester.tap(find.byKey(const Key('support.ticket.t1')));
      await tester.pumpAndSettle();
      expect(find.byType(TicketScreen), findsOneWidget);
      expect(find.text('I was charged twice.'), findsOneWidget);
    });
  });

  group('a request', () {
    Map<String, dynamic> thread({
      String status = 'OPEN',
      String? firstRespondedAt,
      int? ratingScore,
      bool reopenable = false,
      String? contextLabel,
      String? contextHref,
      List<Map<String, dynamic>>? messages,
      List<Map<String, dynamic>>? events,
      int firstResponseHours = 12,
    }) => ticketJson(
      status: status,
      firstRespondedAt: firstRespondedAt,
      ratingScore: ratingScore,
      reopenable: reopenable,
      contextLabel: contextLabel,
      contextHref: contextHref,
      firstResponseHours: firstResponseHours,
      messages:
          messages ??
          [
            message('m1', 'I was charged twice for the Gold plan.\nOn 2 November.'),
            message('m2', 'Sorry about that. Could you send the statement?', staff: true),
          ],
      events:
          events ??
          [
            {
              'id': 'e1',
              'type': 'RAISED',
              'fromValue': null,
              'toValue': null,
              'note': null,
              'createdAt': ago(const Duration(days: 3)),
            },
            {
              'id': 'e2',
              'type': 'STATUS_CHANGED',
              'fromValue': 'NEW',
              'toValue': 'AWAITING_USER',
              'note': 'Needs the statement',
              'createdAt': ago(const Duration(days: 2)),
            },
          ],
    );

    Future<void> open(
      WidgetTester tester,
      Map<String, dynamic> Function() ticket, {
      Map<String, ApiHandler> routes = const {},
      void Function(String href)? onOpenContext,
      FilePickFn? pickFiles,
      void Function(BuildContext)? onOpened,
    }) => start(
      tester,
      () => TicketScreen(
        ticketId: 't1',
        repository: repo,
        onOpenContext: onOpenContext,
        pickFiles: pickFiles,
        onOpened: onOpened,
      ),
      routes: {'GET /support/tickets/t1': (_) => ticket(), ...routes},
    );

    testWidgets('the subject, status, "ICR-12 · Category · raised 3d ago", the messages and the history', (
      tester,
    ) async {
      await open(tester, () => thread(status: 'AWAITING_USER', firstRespondedAt: ago(const Duration(days: 2))));
      expect(find.text('ICR-12'), findsOneWidget, reason: 'the bar');
      expect(find.byKey(const Key('ticket.subject')), findsOneWidget);
      expect(find.text('Payment taken twice for the Gold plan'), findsOneWidget);
      expect(find.byKey(const Key('support.status.AWAITING_USER')), findsOneWidget);
      expect(find.text('ICR-12 · Billing & Payments · raised 3d ago'), findsOneWidget);
      // Messages, oldest first, with the author's name; the body keeps its line break.
      expect(find.text('Sam Rao'), findsOneWidget);
      expect(find.text('I was charged twice for the Gold plan.\nOn 2 November.'), findsOneWidget);
      expect(find.text('Asha Nair'), findsOneWidget);
      // History.
      await reveal(tester, find.byKey(const Key('ticket.history')));
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Raised · 3d ago'), findsOneWidget);
      expect(find.text('Status changed → Waiting on You · 2d ago · Needs the statement'), findsOneWidget);
    });

    testWidgets('a message from ICR with no named person is drawn as ICR', (tester) async {
      await open(tester, () => thread(messages: [message('m1', 'Logged by the desk.', icr: true)]));
      expect(find.text('Logged by the desk.'), findsOneWidget);
      expect(find.text('ICR'), findsNWidgets(2), reason: 'the badge and the name');
    });

    testWidgets('banners: a reply target while unanswered; "we need something from you" while waiting', (tester) async {
      await open(tester, () => thread(status: 'NEW', firstResponseHours: 24));
      expect(
        find.text('We aim to reply within 24 hours. You will receive a notification and an email when we reply.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ticket.waiting')), findsNothing);

      await open(tester, () => thread(status: 'AWAITING_USER', firstRespondedAt: ago(const Duration(days: 1))));
      expect(find.byKey(const Key('ticket.aim')), findsNothing, reason: 'it was answered');
      expect(find.text('We need more information from you to continue. Reply below.'), findsOneWidget);
    });

    testWidgets('a closed request has no reply box and says what to do instead; no reply target either', (
      tester,
    ) async {
      await open(tester, () => thread(status: 'CLOSED', ratingScore: 4));
      expect(find.byKey(const Key('ticket.closed')), findsOneWidget);
      expect(find.text('This request is closed. If the issue returns, raise a new request.'), findsOneWidget);
      expect(find.byKey(const Key('ticket.replyBox')), findsNothing);
      expect(find.byKey(const Key('ticket.reply')), findsNothing);
      expect(find.byKey(const Key('ticket.aim')), findsNothing);
      await reveal(tester, find.byKey(const Key('ticket.rated')));
      expect(find.text('You rated this'), findsOneWidget);
    });

    testWidgets('a reply is sent as typed, the box clears, and the thread is read again', (tester) async {
      var replied = false;
      await open(
        tester,
        () => thread(
          firstRespondedAt: ago(const Duration(days: 2)),
          messages: [message('m1', 'I was charged twice.'), if (replied) message('m3', 'Statement attached below.')],
        ),
        routes: {
          'POST /support/tickets/t1/messages': (_) {
            replied = true;
            return ticketJson(status: 'OPEN', messageCount: 2);
          },
        },
      );
      final reads = h.api.count('GET /support/tickets/t1');
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(of: find.byKey(const Key('ticket.send')), matching: find.byType(FilledButton)),
            )
            .onPressed,
        isNull,
        reason: 'nothing typed yet',
      );

      await typeKey(tester, 'ticket.reply', '  Statement attached below.  ');
      await tapKey(tester, 'ticket.send');
      final post = h.api.last('POST /support/tickets/t1/messages');
      expect(post.json['body'], 'Statement attached below.');
      expect(post.json.containsKey('attachments'), isFalse);
      expect(
        h.api.count('GET /support/tickets/t1'),
        reads + 1,
        reason: 'the answer carries no thread: it is read again',
      );
      expect(find.text('Statement attached below.'), findsOneWidget, reason: 'now in the thread');
      expect(tester.widget<TextField>(find.byKey(const Key('ticket.reply'))).controller!.text, isEmpty);
    });

    testWidgets('a reply that is refused keeps what was typed and shows the sentence', (tester) async {
      await open(
        tester,
        () => thread(),
        routes: {
          'POST /support/tickets/t1/messages': (_) =>
              ApiReply.refusal(400, 'This request is closed. Please raise a new one.'),
        },
      );
      await typeKey(tester, 'ticket.reply', 'One more thing');
      await tapKey(tester, 'ticket.send');
      expect(find.text('This request is closed. Please raise a new one.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('ticket.reply'))).controller!.text, 'One more thing');
    });

    testWidgets('a reply with a file: uploaded as `support`, then sent with its path', (tester) async {
      await open(
        tester,
        () => thread(),
        pickFiles: (max) async => [
          SupportPickedFile(bytes: Uint8List.fromList([1, 2, 3]), name: 'statement.png'),
        ],
        routes: {
          'POST /uploads': (_) => {
            'url': '/uploads/ab12.png',
            'name': 'statement.png',
            'size': 3,
            'mimeType': 'image/png',
          },
          'POST /support/tickets/t1/messages': (_) => ticketJson(),
        },
      );
      await typeKey(tester, 'ticket.reply', 'Here it is');
      await tapKey(tester, 'support.attach');
      final upload = h.api.last('POST /uploads');
      expect(upload.query['purpose'], 'support');
      expect(upload.body, isA<FormData>());
      expect(find.text('statement.png'), findsOneWidget, reason: 'a chip for the attached file');

      await tapKey(tester, 'ticket.send');
      final post = h.api.last('POST /support/tickets/t1/messages');
      expect(post.json['attachments'], [
        {'fileUrl': '/uploads/ab12.png', 'fileName': 'statement.png', 'mimeType': 'image/png', 'sizeBytes': 3},
      ]);
      expect(find.byKey(const Key('support.attached.0')), findsNothing, reason: 'the tray empties after sending');
    });

    testWidgets('Reopen is there only while the API says the request is reopenable', (tester) async {
      await open(tester, () => thread(status: 'RESOLVED', reopenable: false));
      expect(find.byKey(const Key('ticket.reopen')), findsNothing);

      var reopened = false;
      await open(
        tester,
        () => thread(status: reopened ? 'OPEN' : 'RESOLVED', reopenable: !reopened),
        routes: {
          'POST /support/tickets/t1/reopen': (_) {
            reopened = true;
            return ticketJson(status: 'OPEN');
          },
        },
      );
      expect(find.text('Reopen This Request'), findsOneWidget);
      await tapKey(tester, 'ticket.reopen');
      expect(h.api.count('POST /support/tickets/t1/reopen'), 1);
      expect(find.byKey(const Key('support.status.OPEN')), findsOneWidget);
      expect(find.byKey(const Key('ticket.reopen')), findsNothing);
    });

    testWidgets('a refused reopen says why', (tester) async {
      await open(
        tester,
        () => thread(status: 'RESOLVED', reopenable: true),
        routes: {
          'POST /support/tickets/t1/reopen': (_) =>
              ApiReply.refusal(400, 'This request was resolved more than 14 days ago. Please raise a new one.'),
        },
      );
      await tapKey(tester, 'ticket.reopen');
      expect(find.text('This request was resolved more than 14 days ago. Please raise a new one.'), findsOneWidget);
    });

    testWidgets('a resolved, unrated request asks "Rate Our Support"; a score is sent once, then shown', (
      tester,
    ) async {
      int? score;
      await open(
        tester,
        () => thread(status: 'RESOLVED', ratingScore: score, reopenable: true),
        routes: {
          'POST /support/tickets/t1/rate': (call) {
            score = call.json['score'] as int;
            return ticketJson(status: 'RESOLVED', ratingScore: score);
          },
        },
      );
      await reveal(tester, find.byKey(const Key('ticket.rating')));
      expect(find.text('Rate Our Support'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(of: find.byKey(const Key('ticket.rate')), matching: find.byType(FilledButton)),
            )
            .onPressed,
        isNull,
        reason: 'no stars chosen yet',
      );
      await tester.tap(find.byKey(const Key('support.star.4')));
      await tester.pumpAndSettle();
      await tapKey(tester, 'ticket.rate');
      expect(h.api.last('POST /support/tickets/t1/rate').json, {'score': 4});
      await reveal(tester, find.byKey(const Key('ticket.rated')));
      expect(find.text('You rated this'), findsOneWidget);
      expect(find.byKey(const Key('ticket.rating')), findsNothing);
    });

    testWidgets('what the request is about: a plain chip, or a link when the screen can open it', (tester) async {
      await open(tester, () => thread(contextLabel: 'Mentoring pairing', contextHref: '/mentorship/my/m1'));
      expect(find.text('Mentoring pairing'), findsOneWidget);
      expect(find.byType(ActionChip), findsNothing, reason: 'a plain chip: nothing to open it with');

      final opened = <String>[];
      await open(
        tester,
        () => thread(contextLabel: 'Mentoring pairing', contextHref: '/mentorship/my/m1'),
        onOpenContext: opened.add,
      );
      await tester.tap(find.byKey(const Key('ticket.context')));
      await tester.pumpAndSettle();
      expect(opened, ['/mentorship/my/m1']);
    });

    testWidgets('an attachment opens in the app\'s viewer, read with the session', (tester) async {
      final auth = <Object?>[];
      h = AccountHarness(
        routes: {
          'GET /support/tickets/t1': (_) => thread(
            messages: [
              message(
                'm1',
                'See the receipt.',
                attachments: [
                  {
                    'id': 'a1',
                    'fileUrl': '/uploads/receipt.txt',
                    'fileName': 'receipt.txt',
                    'mimeType': 'text/plain',
                    'sizeBytes': 20,
                  },
                ],
              ),
            ],
          ),
          'GET http://api.test/uploads/receipt.txt': (_) => 'Receipt 4411 for the Gold plan',
        },
      );
      h.client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, next) {
            if (o.path.endsWith('/uploads/receipt.txt')) auth.add(o.headers['Authorization']);
            next.next(o);
          },
        ),
      );
      await h.signIn(tester);
      usePhone(tester);
      repo = ApiSupportRepository(api: h.client);
      await tester.pumpWidget(h.app(TicketScreen(ticketId: 't1', repository: repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ticket.file.a1')));
      await tester.pumpAndSettle();
      expect(h.api.count('GET http://api.test/uploads/receipt.txt'), 1);
      expect(auth.single, 'Bearer a1', reason: 'the private file is read with the member\'s session');
      expect(find.byType(DocumentViewerScreen), findsOneWidget);
      expect(find.textContaining('Receipt 4411'), findsOneWidget);
    });

    testWidgets('a file the viewer cannot show says so, and one that cannot be read says that', (tester) async {
      await open(
        tester,
        () => thread(
          messages: [
            message(
              'm1',
              'Files',
              attachments: [
                {'id': 'a1', 'fileUrl': '/uploads/disk.dmg', 'fileName': 'disk.dmg', 'mimeType': null},
                {'id': 'a2', 'fileUrl': '/uploads/gone.pdf', 'fileName': 'gone.pdf', 'mimeType': 'application/pdf'},
              ],
            ),
          ],
        ),
        routes: {
          'GET http://api.test/uploads/disk.dmg': (_) => 'x',
          'GET http://api.test/uploads/gone.pdf': (_) => ApiReply.refusal(404, 'Not found'),
        },
      );
      await tester.tap(find.byKey(const Key('ticket.file.a1')));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentViewerScreen), findsNothing);
      expect(find.text("This file's type can't be shown in the app."), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.byKey(const Key('ticket.file.a2')));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentViewerScreen), findsNothing);
      expect(find.text('Not found'), findsOneWidget);
    });

    testWidgets('a request that cannot be read says so with Try again', (tester) async {
      var found = false;
      await start(
        tester,
        () => TicketScreen(ticketId: 't1', repository: repo),
        routes: {'GET /support/tickets/t1': (_) => found ? thread() : ApiReply.refusal(404, 'Not found')},
      );
      expect(
        find.text('Unable to open this request. It may have been removed, or it belongs to another account.'),
        findsOneWidget,
      );
      found = true;
      await tester.tap(find.byKey(const Key('account.retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ticket.subject')), findsOneWidget);
    });

    testWidgets('onOpened runs once, after the request has been read (the caller reads its notifications)', (
      tester,
    ) async {
      var opened = 0;
      await open(tester, () => thread(), onOpened: (_) => opened++);
      expect(opened, 1);
      await tester.fling(find.byKey(const Key('ticket.list')), const Offset(0, 400), 1000);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(opened, 1, reason: 'a pull to refresh is not another opening');
    });
  });

  group('raising a request', () {
    SupportTicketRaised? raised;

    Future<void> openSheet(
      WidgetTester tester, {
      Map<String, ApiHandler> routes = const {},
      String? category,
      String? contextType,
      String? contextId,
      String? contextLabel,
      String? subject,
      FilePickFn? pickFiles,
    }) async {
      raised = null;
      await tester.pumpWidget(const SizedBox());
      h = AccountHarness(
        routes: {
          'GET /support/faqs': (call) => [
            {
              'id': 'f9',
              'question': call.query['category'] == 'BILLING_PAYMENTS' ? 'Where is my invoice?' : 'Anything else?',
              'answer': 'Answer for ${call.query['category']}.',
              'category': call.query['category'],
            },
          ],
          ...routes,
        },
      );
      await h.signIn(tester);
      usePhone(tester);
      repo = ApiSupportRepository(api: h.client);
      await tester.pumpWidget(
        h.app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('go'),
                onPressed: () async => raised = await showRaiseTicketSheet(
                  context,
                  repository: repo,
                  category: category,
                  contextType: contextType,
                  contextId: contextId,
                  contextLabel: contextLabel,
                  subject: subject,
                  pickFiles: pickFiles,
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('go')));
      await tester.pumpAndSettle();
    }

    Future<void> fill(
      WidgetTester tester, {
      String subject = 'Payment taken twice',
      String body = 'I was charged twice on 2 November.',
    }) async {
      await tester.enterText(find.byKey(const Key('raise.subject')), subject);
      await tester.enterText(find.byKey(const Key('raise.body')), body);
      await tester.pumpAndSettle();
    }

    bool sendEnabled(WidgetTester tester) =>
        tester
            .widget<FilledButton>(
              find.descendant(of: find.byKey(const Key('sheet.save')), matching: find.byType(FilledButton)),
            )
            .onPressed !=
        null;

    testWidgets('opens on "Something Else" with its hint; Send waits for a subject of 5 and a story of 10 characters', (
      tester,
    ) async {
      await openSheet(tester);
      expect(find.text('Get Help from ICR'), findsOneWidget);
      expect(find.text('Something Else'), findsOneWidget);
      expect(find.text('Describe it in your own words.'), findsOneWidget);
      expect(find.text('Summarise the problem in one line'), findsOneWidget);
      expect(find.text('What you did, what you expected, and what happened instead.'), findsOneWidget);
      expect(sendEnabled(tester), isFalse);

      await fill(tester, subject: 'Help', body: 'It does not work at all');
      expect(sendEnabled(tester), isFalse, reason: 'the subject is 4 characters');
      await fill(tester, subject: 'Help!', body: 'Too short');
      expect(sendEnabled(tester), isFalse, reason: 'the story is 9 characters');
      await fill(tester, subject: '  Hello  ', body: 'Ten chars!');
      expect(sendEnabled(tester), isTrue);
    });

    testWidgets('the category list has all eleven; choosing one changes the hint and asks for its articles', (
      tester,
    ) async {
      await openSheet(tester);
      expect(h.api.last('GET /support/faqs').query['category'], 'OTHER');
      expect(SupportWords.categories, hasLength(11), reason: 'every SupportTicketCategory');
      await tester.tap(find.descendant(of: find.byKey(const Key('raise.category')), matching: find.byType(InkWell)));
      await tester.pumpAndSettle();
      expect(find.text('Select a Topic'), findsWidgets);
      expect(find.text('Account & Sign-In'), findsOneWidget);
      expect(find.text('Billing & Payments'), findsOneWidget);
      await tester.tap(find.text('Billing & Payments'));
      await tester.pumpAndSettle();
      expect(
        find.text('A payment that failed or charged twice, a refund, an invoice, a membership you did not expect.'),
        findsOneWidget,
      );
      expect(h.api.last('GET /support/faqs').query['category'], 'BILLING_PAYMENTS');
      expect(h.api.last('GET /support/faqs').query['limit'], 3);
      expect(find.text('Common Questions on This Topic'), findsOneWidget);
      expect(find.text('Where is my invoice?'), findsOneWidget);
    });

    testWidgets('a category given by the caller is the one chosen', (tester) async {
      await openSheet(tester, category: 'MENTORSHIP', subject: 'About my session');
      expect(find.text('Mentorship'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('raise.subject'))).controller!.text, 'About my session');
    });

    testWidgets('Send posts the trimmed subject, category and story, and returns the request logged', (tester) async {
      await openSheet(tester, routes: {'POST /support/tickets': (_) => ticketJson(id: 'new1', reference: 77)});
      await fill(tester, subject: '  Payment taken twice ', body: '  I was charged twice on 2 November.  ');
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      final post = h.api.last('POST /support/tickets');
      expect(post.json, {
        'subject': 'Payment taken twice',
        'category': 'OTHER',
        'body': 'I was charged twice on 2 November.',
      });
      expect(raised?.id, 'new1');
      expect(raised?.reference, 77);
      expect(find.byType(RaiseTicketSheet), findsNothing, reason: 'the sheet closes');
    });

    testWidgets('a file is uploaded as `support` when chosen, and its path goes with the request', (tester) async {
      await openSheet(
        tester,
        pickFiles: (max) async => [
          SupportPickedFile(bytes: Uint8List.fromList(List.filled(8, 7)), name: 'error.png'),
          SupportPickedFile(bytes: Uint8List.fromList([1]), name: 'log.pdf'),
        ],
        routes: {
          'POST /uploads': (call) => {'url': '/uploads/x.bin', 'name': 'uploaded', 'size': 8, 'mimeType': 'image/png'},
          'POST /support/tickets': (_) => ticketJson(id: 'new2', reference: 78),
        },
      );
      await fill(tester);
      await reveal(tester, find.byKey(const Key('support.attach')), within: inSheet());
      await tester.tap(find.byKey(const Key('support.attach')));
      await tester.pumpAndSettle();
      expect(h.api.count('POST /uploads'), 2);
      expect(h.api.where('POST /uploads').every((c) => c.query['purpose'] == 'support'), isTrue);
      expect(find.byKey(const Key('support.attached.0')), findsOneWidget);
      expect(find.byKey(const Key('support.attached.1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      final sent = h.api.last('POST /support/tickets').json['attachments'] as List;
      expect(sent, hasLength(2));
      expect((sent.first as Map)['fileUrl'], '/uploads/x.bin');
      expect((sent.first as Map)['sizeBytes'], 8);
    });

    testWidgets('a file over 10 MB, or one the upload refuses, is named in a note and not attached', (tester) async {
      await openSheet(
        tester,
        pickFiles: (max) async => [
          SupportPickedFile(bytes: Uint8List(SupportWords.maxFileBytes + 1), name: 'huge.pdf'),
          SupportPickedFile(bytes: Uint8List.fromList([1, 2]), name: 'refused.png'),
        ],
        routes: {
          'POST /uploads': (_) => ApiReply.refusal(400, 'image/gif is not an accepted file type for this upload.'),
        },
      );
      await reveal(tester, find.byKey(const Key('support.attach')), within: inSheet());
      await tester.tap(find.byKey(const Key('support.attach')));
      await tester.pumpAndSettle();
      expect(h.api.count('POST /uploads'), 1, reason: 'the heavy one never leaves the phone');
      expect(find.byKey(const Key('support.attached.0')), findsNothing);
      expect(find.text('refused.png could not be uploaded. PDFs and images up to 10 MB.'), findsOneWidget);
    });

    testWidgets('a chip takes a file back off; five files fill the tray', (tester) async {
      var n = 0;
      await openSheet(
        tester,
        pickFiles: (max) async => [
          for (var i = 0; i < max; i++) SupportPickedFile(bytes: Uint8List.fromList([i]), name: 'shot$i.png'),
        ],
        routes: {
          'POST /uploads': (_) {
            n++;
            return {'url': '/uploads/f$n.png', 'name': 'shot$n.png', 'size': 1, 'mimeType': 'image/png'};
          },
        },
      );
      await reveal(tester, find.byKey(const Key('support.attach')), within: inSheet());
      await tester.tap(find.byKey(const Key('support.attach')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        expect(find.byKey(Key('support.attached.$i')), findsOneWidget);
      }
      expect(
        tester
            .widget<OutlinedButton>(
              find.descendant(of: find.byKey(const Key('support.attach')), matching: find.byType(OutlinedButton)),
            )
            .onPressed,
        isNull,
        reason: 'five is the most',
      );
      await tester.tap(
        find.descendant(of: find.byKey(const Key('support.attached.0')), matching: find.byTooltip('Delete')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('support.attached.4')), findsNothing);
    });

    testWidgets('raised from a record: "About …" and the record go with the request; NONE sends no context', (
      tester,
    ) async {
      await openSheet(
        tester,
        category: 'MENTORSHIP',
        contextType: 'MENTORSHIP',
        contextId: 'm1',
        contextLabel: 'Mentoring with Ravi',
        routes: {'POST /support/tickets': (_) => ticketJson(id: 'new3', reference: 79)},
      );
      expect(find.byKey(const Key('raise.context')), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      expect(find.text('Mentoring with Ravi'), findsOneWidget);
      await fill(tester);
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      final post = h.api.last('POST /support/tickets').json;
      expect(post['category'], 'MENTORSHIP');
      expect(post['contextType'], 'MENTORSHIP');
      expect(post['contextId'], 'm1');

      await openSheet(
        tester,
        contextType: 'NONE',
        routes: {'POST /support/tickets': (_) => ticketJson(id: 'new4', reference: 80)},
      );
      expect(find.byKey(const Key('raise.context')), findsNothing);
      await fill(tester);
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      final none = h.api.last('POST /support/tickets').json;
      expect(none.containsKey('contextType'), isFalse);
      expect(none.containsKey('contextId'), isFalse);
    });

    testWidgets('a refusal (the cap on open requests) is shown in the API\'s words; what was typed stays', (
      tester,
    ) async {
      await openSheet(
        tester,
        routes: {
          'POST /support/tickets': (_) => ApiReply.refusal(
            400,
            'You already have 10 open requests. Please reply on one of those instead of opening another.',
          ),
        },
      );
      await fill(tester);
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      expect(
        find.text('You already have 10 open requests. Please reply on one of those instead of opening another.'),
        findsOneWidget,
      );
      expect(find.byType(RaiseTicketSheet), findsOneWidget, reason: 'still open');
      expect(tester.widget<TextField>(find.byKey(const Key('raise.subject'))).controller!.text, 'Payment taken twice');
      expect(raised, isNull);
    });

    testWidgets('with no sentence from the API, "Unable to submit your request."', (tester) async {
      await openSheet(
        tester,
        routes: {
          'POST /support/tickets': (_) => ApiReply(500, {'statusCode': 500}),
        },
      );
      await fill(tester);
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();
      expect(find.text('Unable to submit your request.'), findsOneWidget);
    });
  });

  group('from the list', () {
    testWidgets('New request raises one, then opens its thread and reads the list again', (tester) async {
      var created = false;
      SupportTicketRaised? hooked;
      h = AccountHarness(
        routes: {
          'GET /support/tickets': (_) => page([
            if (created) ticketJson(id: 'n1', reference: 90, subject: 'My new request', status: 'NEW', messageCount: 1),
          ]),
          'GET /support/faqs': (_) => [],
          'GET /subscriptions/account-manager': (_) => null,
          'POST /support/tickets': (_) {
            created = true;
            return ticketJson(id: 'n1', reference: 90, subject: 'My new request', status: 'NEW', messageCount: 1);
          },
          'GET /support/tickets/n1': (_) => ticketJson(
            id: 'n1',
            reference: 90,
            subject: 'My new request',
            status: 'NEW',
            messageCount: 1,
            messages: [message('m1', 'Something is not working at all.')],
          ),
        },
      );
      await h.signIn(tester);
      usePhone(tester);
      repo = ApiSupportRepository(api: h.client);
      await tester.pumpWidget(
        h.app(SupportScreen(repository: repo, searchDelay: Duration.zero, onRaise: (r) => hooked = r)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('support.empty')), findsOneWidget);

      await tester.tap(find.byKey(const Key('support.new')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('raise.subject')), 'My new request');
      await tester.enterText(find.byKey(const Key('raise.body')), 'Something is not working at all.');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sheet.save')));
      await tester.pumpAndSettle();

      expect(hooked?.id, 'n1');
      expect(find.byType(TicketScreen), findsOneWidget, reason: 'the website opens the new request\'s thread');
      expect(find.text('ICR-90'), findsOneWidget);
      expect(find.text('Something is not working at all.'), findsOneWidget);

      // Back on the list, the new request is in it.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(TicketScreen), findsNothing);
      expect(find.text('My new request'), findsOneWidget);
    });

    testWidgets('openSupport and openSupportTicket push the screens', (tester) async {
      final demo = DemoSupportRepository(now: now);
      h = AccountHarness();
      await h.signIn(tester);
      usePhone(tester);
      var opened = 0;
      await tester.pumpWidget(
        h.app(
          Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  key: const Key('list'),
                  onPressed: () => openSupport(context, repository: demo),
                  child: const Text('list'),
                ),
                TextButton(
                  key: const Key('one'),
                  onPressed: () => openSupportTicket(context, 'demo-1', repository: demo, onOpened: (_) => opened++),
                  child: const Text('one'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('one')));
      await tester.pumpAndSettle();
      expect(find.byType(TicketScreen), findsOneWidget);
      expect(find.text('Payment taken twice for the Gold plan'), findsOneWidget);
      expect(opened, 1);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('list')));
      await tester.pumpAndSettle();
      expect(find.byType(SupportScreen), findsOneWidget);
      expect(find.text('Certificate PDF will not download'), findsNothing, reason: 'resolved: not under Open');
      await tester.tap(find.byKey(const Key('support.filter.all')));
      await tester.pumpAndSettle();
      expect(find.text('Certificate PDF will not download'), findsOneWidget);
    });
  });

  group('the sample (design review)', () {
    test('replies, reopens and rates against the in-memory desk, and a closed request refuses a reply', () async {
      final demo = DemoSupportRepository(now: now);
      final open = await demo.tickets();
      expect(open.items.map((t) => t.status), everyElement(isIn(['NEW', 'OPEN', 'AWAITING_USER'])));
      await demo.reply('demo-1', 'Statement attached', const []);
      expect((await demo.ticket('demo-1')).status, 'OPEN');
      expect((await demo.ticket('demo-1')).messages, hasLength(3));
      await demo.reopen('demo-2');
      expect((await demo.ticket('demo-2')).status, 'OPEN');
      await expectLater(demo.reply('demo-3', 'Hello', const []), throwsA(isA<Exception>()));
      final raised = await demo.raise(
        const RaiseDraft(subject: 'Hello there', category: 'OTHER', body: 'Some story here'),
      );
      expect((await demo.ticket(raised.id)).subject, 'Hello there');
      expect(utf8.decode(await demo.fileBytes('/uploads/x')), 'Sample attachment');
    });
  });
}
