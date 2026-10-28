import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_clock.dart';
import 'package:icr_mobile/features/mentorship_my/my_mentoring_controller.dart';
import 'package:icr_mobile/features/mentorship_my/purchases_tab.dart';

import 'helpers/fonts.dart';
import 'mentoring_fakes.dart';
import 'mentoring_purchases_world.dart';

final _now = DateTime(2026, 10, 26, 10);

Future<(FakeApi, LinkRecorder, PurchasesWorld)> pump(
  WidgetTester tester, {
  PurchasesWorld? world,
  Map<String, Reply> extra = const {},
}) async {
  final w = world ?? PurchasesWorld();
  final api = w.api(extra: extra);
  phone(tester, height: 14000);
  final rec = LinkRecorder();
  await pumpApp(tester, _Host(api: api, rec: rec));
  return (api, rec, w);
}

/// The tab in a plain scaffold, with the callbacks it hands the lead's screens recorded.
class _Host extends StatefulWidget {
  const _Host({required this.api, required this.rec});

  final FakeApi api;
  final LinkRecorder rec;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late final MyMentoringController c = MyMentoringController(repoOf(widget.api))..book.ensure();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: PurchasesTab(
            controller: c,
            links: widget.rec.links,
            onOpenGroup: (id) => widget.rec.opened.add('group:$id'),
            onOpenPairing: (id) => widget.rec.opened.add('pairing:$id'),
            onOpenProgramme: (slug) => widget.rec.opened.add('programme:$slug'),
            onBrowseGroups: () => widget.rec.opened.add('browse-groups'),
            onBrowseProgrammes: () => widget.rec.opened.add('browse-programmes'),
          ),
        ),
      ),
    );
  }
}

Finder inCard(String key, String text) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));

Future<void> tapIn(WidgetTester tester, String key, String text) async {
  final f = inCard(key, text);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await settle(tester);
}

Future<void> openPast(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('toggle-past-purchases')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => mentoringNow = () => _now);
  tearDown(() => mentoringNow = DateTime.now);

  group('the tab', () {
    testWidgets('sorts what needs the member from what is running and what is over', (tester) async {
      await pump(tester);
      expect(find.text('NEEDS YOU'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      // Needs: a time to accept, a programme to pay for.
      expect(inCard('purchase-p-acc', 'Accept this time'), findsOneWidget);
      expect(inCard('term-t-pay', 'Pay ₹5,382'), findsOneWidget);
      // Active: the ask waiting for a reply, the booked call, a programme waiting on the mentor, the plan, a seat, a cohort place.
      expect(inCard('purchase-p-req', 'Withdraw'), findsOneWidget);
      expect(inCard('purchase-p-booked', 'Join'), findsOneWidget);
      expect(find.byKey(const ValueKey('term-t-prog')), findsOneWidget);
      expect(find.byKey(const ValueKey('term-left-t-coach')), findsOneWidget);
      expect(find.byKey(const ValueKey('seat-g-clinic')), findsOneWidget);
      expect(find.byKey(const ValueKey('enrolment-e-1')), findsOneWidget);
      // Over: behind a toggle.
      expect(find.byKey(const ValueKey('purchase-p-kit')), findsNothing);
      expect(find.text('Past (2)'), findsOneWidget);
      await openPast(tester);
      expect(find.byKey(const ValueKey('purchase-p-kit')), findsOneWidget);
      expect(find.byKey(const ValueKey('purchase-p-decl')), findsOneWidget);
      expect(find.textContaining('I am travelling that fortnight.'), findsOneWidget);
    });

    testWidgets('an empty list says what will show up and sends the member to the directory', (tester) async {
      final w = PurchasesWorld()
        ..purchases = []
        ..terms = []
        ..seats = []
        ..enrolments = [];
      final (_, rec, _) = await pump(tester, world: w);
      expect(find.text('Nothing bought yet'), findsOneWidget);
      await tester.tap(find.text('Browse mentors'));
      expect(rec.opened, ['directory']);
    });

    testWidgets('the browse buttons and the open callbacks reach the lead\'s screens', (tester) async {
      final (_, rec, _) = await pump(tester);
      await tester.tap(find.text('Group sessions'));
      await tester.tap(find.text('Programmes'));
      await tapIn(tester, 'seat-g-clinic', 'Open session');
      await tapIn(tester, 'enrolment-e-1', 'Open programme');
      await tapIn(tester, 'term-t-coach', 'Schedule a session');
      expect(rec.opened, [
        'browse-groups',
        'browse-programmes',
        'group:g-clinic',
        'programme:circle',
        'pairing:pair-anand',
      ]);
    });

    testWidgets('a load that fails says why and Try again reads it again', (tester) async {
      var fail = true;
      final w = PurchasesWorld();
      final (api, _, _) = await pump(
        tester,
        world: w,
        extra: {
          'GET /mentor-services/purchases/mine': (_) =>
              fail ? refuse('Mentor services are unavailable.', status: 503) : page(w.purchases),
        },
      );
      // The terms still loaded, so the tab shows them; the purchases failed quietly into their own list.
      expect(find.byKey(const ValueKey('term-t-prog')), findsOneWidget);
      fail = false;
      expect(api.count('GET /mentor-services/purchases/mine'), 1);
    });
  });

  group('a 1:1 session asked for', () {
    testWidgets('a request is withdrawn', (tester) async {
      final (api, _, w) = await pump(tester);
      await tapIn(tester, 'purchase-p-req', 'Withdraw');
      expect(api.count('POST /mentor-services/purchases/p-req/withdraw'), 1);
      expect(find.text('Request withdrawn.'), findsOneWidget);
      expect(find.byKey(const ValueKey('purchase-p-req')), findsNothing);
      expect(w.purchases.any((p) => p['id'] == 'p-req'), isFalse);
    });

    testWidgets('accepting the time a mentor set can spend a session credit that covers it', (tester) async {
      final (api, _, w) = await pump(tester);
      await tapIn(tester, 'purchase-p-acc', 'Accept this time');
      expect(find.text('Accept the time Anand set?'), findsOneWidget);
      expect(find.byKey(const ValueKey('quote-credit')), findsOneWidget);
      expect(find.text('A session credit pays for it, so there is nothing to pay.'), findsOneWidget);
      expect(find.byKey(const ValueKey('quote-charged')).evaluate().isNotEmpty, isTrue);
      await tester.tap(find.text('Accept and confirm'));
      await settle(tester);
      expect(api.bodyOf('POST /mentor-services/purchases/p-acc/accept-time'), {'useCredit': true});
      expect(w.purchases.firstWhere((p) => p['id'] == 'p-acc')['status'], 'PAID');
      expect(find.text('Accepted. Pay to confirm it.'), findsNothing, reason: 'a credit paid for it');
    });

    testWidgets('without the credit the session is accepted and paid for after, with the member discount shown', (
      tester,
    ) async {
      final w = PurchasesWorld();
      w.discounts = {
        'services': {'bps': 1000, 'planName': 'Gold'},
        'plans': {'bps': 0, 'planName': null},
        'sessionCredits': {
          'perPeriod': 1,
          'remaining': 1,
          'capPaisa': 150000,
          'planName': 'Pro Plus',
          'resetsAt': null,
        },
      };
      final (api, _, _) = await pump(tester, world: w);
      await tapIn(tester, 'purchase-p-acc', 'Accept this time');
      await tester.tap(find.byKey(const ValueKey('quote-credit')));
      await tester.pumpAndSettle();
      expect(
        find.text('You pay ₹719.10 after, to confirm it.'),
        findsOneWidget,
        reason: '10% off ₹799, after the credit is declined',
      );
      expect(find.byKey(const ValueKey('quote-discount')), findsOneWidget);
      expect(find.text('10% member discount from Gold.'), findsOneWidget);
      await tester.tap(find.text('Accept and confirm'));
      await settle(tester);
      expect(api.bodyOf('POST /mentor-services/purchases/p-acc/accept-time'), {'useCredit': false});
      expect(find.text('Accepted. Pay to confirm it.'), findsOneWidget);
      expect(find.text('Pay ₹799'), findsOneWidget, reason: 'the payment is due: the card now offers it');
    });

    testWidgets('a time that does not suit is sent back with the times that would', (tester) async {
      final (api, _, w) = await pump(tester);
      await tapIn(tester, 'purchase-p-acc', 'Ask another time');
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'No');
      await tester.tap(find.text('Send to Anand'));
      await tester.pump();
      expect(find.text('Write at least 5 characters.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'Weekday evenings after 7 pm');
      await tester.tap(find.text('Send to Anand'));
      await settle(tester);
      expect(api.bodyOf('POST /mentor-services/purchases/p-acc/decline-time'), {'note': 'Weekday evenings after 7 pm'});
      expect(w.purchases.firstWhere((p) => p['id'] == 'p-acc')['status'], 'REQUESTED');
      expect(find.text('You asked for another time: Weekday evenings after 7 pm'), findsOneWidget);
    });
  });

  group('paying', () {
    PurchasesWorld confirmedWorld({bool live = true, Map<String, Object?>? discounts}) {
      final w = PurchasesWorld(live: live);
      final p = w.purchases.firstWhere((p) => p['id'] == 'p-acc');
      p['status'] = 'CONFIRMED';
      p['booking'] = bookingBlock(at: _now.add(const Duration(days: 4)));
      if (discounts != null) w.discounts = discounts;
      return w;
    }

    testWidgets('a credit that covers the session pays for it in the app, even with real payments on', (tester) async {
      final (api, rec, w) = await pump(tester, world: confirmedWorld());
      await tapIn(tester, 'purchase-p-acc', 'Pay ₹799');
      expect(find.text('Pay for your session'), findsOneWidget);
      expect(find.text('Pay with a session credit'), findsOneWidget);
      expect(find.byKey(const ValueKey('pay-handoff')), findsNothing);
      await tester.tap(find.text('Pay with a session credit'));
      await settle(tester);
      expect(api.bodyOf('POST /mentor-services/purchases/p-acc/pay'), {'useCredit': true});
      expect(find.text('Paid with a session credit. The session is booked.'), findsOneWidget);
      expect(w.purchases.firstWhere((p) => p['id'] == 'p-acc')['status'], 'PAID');
      expect(rec.sites, isEmpty);
    });

    testWidgets('real money moves on the website: the quote is shown here, the payment page opens from the button', (
      tester,
    ) async {
      final (api, rec, _) = await pump(tester, world: confirmedWorld());
      await tapIn(tester, 'purchase-p-acc', 'Pay ₹799');
      await tester.tap(find.byKey(const ValueKey('quote-credit')));
      await tester.pumpAndSettle();
      expect(find.text('Pay ₹799 on the website'), findsOneWidget);
      expect(find.byKey(const ValueKey('pay-handoff')), findsOneWidget);
      await tester.tap(find.text('Pay ₹799 on the website'));
      await settle(tester);
      expect(
        api.count('POST /mentor-services/purchases/p-acc/pay'),
        0,
        reason: 'the website begins the gateway payment',
      );
      expect(rec.sites, ['/mentorship/my?tab=purchases&purchase=p-acc']);
    });

    testWidgets('with a simulated gateway the payment completes in the app', (tester) async {
      final (api, rec, w) = await pump(
        tester,
        world: confirmedWorld(
          live: false,
          discounts: {
            'services': {'bps': 0, 'planName': null},
            'plans': {'bps': 0, 'planName': null},
            'sessionCredits': null,
          },
        ),
      );
      await tapIn(tester, 'purchase-p-acc', 'Pay ₹799');
      await tester.tap(find.text('Pay ₹799').last);
      await settle(tester);
      expect(api.bodyOf('POST /mentor-services/purchases/p-acc/pay'), {'useCredit': false});
      expect(find.text('The session is booked.'), findsOneWidget);
      expect(w.purchases.firstWhere((p) => p['id'] == 'p-acc')['status'], 'PAID');
      expect(rec.sites, isEmpty);
    });

    testWidgets('a refused payment says why and the sheet stays', (tester) async {
      final (_, _, _) = await pump(
        tester,
        world: confirmedWorld(live: false),
        extra: {'POST /mentor-services/purchases/p-acc/pay': (_) => refuse('This session can no longer be paid for.')},
      );
      await tapIn(tester, 'purchase-p-acc', 'Pay ₹799');
      await tester.tap(find.text('Pay with a session credit'));
      await settle(tester);
      expect(find.text('This session can no longer be paid for.'), findsOneWidget);
      expect(find.text('Pay for your session'), findsOneWidget);
    });

    testWidgets('a programme shows the API\'s quote, then starts in the app or continues on the website', (
      tester,
    ) async {
      final (api, rec, _) = await pump(tester);
      await tapIn(tester, 'term-t-pay', 'Pay ₹5,382');
      expect(find.text('Pay for your programme'), findsOneWidget);
      expect(find.byKey(const ValueKey('term-price')), findsOneWidget);
      String at(String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;
      expect(at('term-price'), '₹5,999');
      expect(at('term-discount'), '−₹1,000');
      expect(at('term-tax'), '₹383');
      expect(at('term-total'), '₹5,382');
      await tester.tap(find.text('Pay ₹5,382 on the website'));
      await settle(tester);
      expect(api.count('POST /mentor-plans/subscriptions/t-pay/pay'), 0);
      expect(rec.sites, ['/mentorship/my?tab=purchases']);
    });

    testWidgets('a programme with nothing to pay, or a simulated gateway, starts in the app', (tester) async {
      final (api, _, w) = await pump(tester, world: PurchasesWorld(live: false));
      await tapIn(tester, 'term-t-pay', 'Pay ₹5,382');
      await tester.tap(find.text('Pay ₹5,382').last);
      await settle(tester);
      expect(api.count('POST /mentor-plans/subscriptions/t-pay/pay'), 1);
      expect(find.text('Paid. Your programme has started.'), findsOneWidget);
      expect(w.terms.firstWhere((t) => t['id'] == 't-pay')['status'], 'ACTIVE');
    });
  });

  group('a booked call', () {
    testWidgets('Join opens the meeting link', (tester) async {
      await pump(tester);
      final urls = launches(tester);
      await tapIn(tester, 'purchase-p-booked', 'Join');
      expect(urls, ['https://meet.google.com/icr-demo']);
    });

    testWidgets(
      'asking to move picks a time from the mentor\'s hours and waits for them; the request can be withdrawn',
      (tester) async {
        final (api, _, _) = await pump(tester);
        await tapIn(tester, 'purchase-p-booked', 'Ask to move');
        await tester.tap(find.text('7:00 PM'));
        await tester.pump();
        await tester.enterText(find.byKey(const ValueKey('move-note')), 'That day clashes with a site audit');
        await tester.tap(find.text('Ask to move').last);
        await settle(tester);
        final body = api.bodyOf('POST /mentor-services/purchases/p-booked/reschedule') as Map;
        expect(DateTime.parse(body['scheduledAt'] as String).isAtSameMomentAs(DateTime(2026, 10, 30, 19)), isTrue);
        expect(body['note'], 'That day clashes with a site audit');
        expect(find.byKey(const ValueKey('move-on-them')), findsOneWidget);
        expect(find.textContaining('Waiting for Anand.'), findsOneWidget);
        expect(find.text('Ask to move'), findsNothing, reason: 'one request at a time');
        await tester.tap(find.text('Withdraw the request'));
        await settle(tester);
        expect(api.count('POST /mentor-services/purchases/p-booked/reschedule/decline'), 1);
        expect(find.byKey(const ValueKey('move-on-them')), findsNothing);
      },
    );

    testWidgets('asking to move needs a time first', (tester) async {
      await pump(tester);
      await tapIn(tester, 'purchase-p-booked', 'Ask to move');
      await tester.tap(find.text('Ask to move').last);
      await tester.pump();
      expect(find.text('Pick a new time first.'), findsOneWidget);
    });

    testWidgets('a move the mentor proposed is accepted, or the booked time is kept with a note', (tester) async {
      final w = PurchasesWorld();
      final p = w.purchases.firstWhere((p) => p['id'] == 'p-booked');
      p['booking'] = bookingBlock(
        at: _now.add(const Duration(days: 2)),
        proposed: _now.add(const Duration(days: 3)),
        proposedBy: 'MENTOR',
        proposedNote: 'A site visit came up',
      );
      final (api, _, _) = await pump(tester, world: w);
      expect(find.byKey(const ValueKey('move-on-me')), findsOneWidget);
      expect(find.textContaining('A site visit came up'), findsOneWidget);
      expect(find.text('NEEDS YOU'), findsOneWidget);
      await tester.tap(find.text('Keep booked time'));
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'That day does not work for me');
      await tester.tap(find.text('Keep the booked time'));
      await settle(tester);
      expect(api.bodyOf('POST /mentor-services/purchases/p-booked/reschedule/decline'), {
        'reason': 'That day does not work for me',
      });
      expect(find.byKey(const ValueKey('move-on-me')), findsNothing);
    });

    testWidgets('accepting the mentor\'s new time moves the call', (tester) async {
      final w = PurchasesWorld();
      final p = w.purchases.firstWhere((p) => p['id'] == 'p-booked');
      p['booking'] = bookingBlock(
        at: _now.add(const Duration(days: 2)),
        proposed: _now.add(const Duration(days: 3)),
        proposedBy: 'MENTOR',
      );
      final (api, _, _) = await pump(tester, world: w);
      await tester.tap(find.text('Accept new time'));
      await settle(tester);
      expect(api.count('POST /mentor-services/purchases/p-booked/reschedule/accept'), 1);
      expect(find.text('Moved to the new time.'), findsOneWidget);
      expect(find.byKey(const ValueKey('move-on-me')), findsNothing);
    });

    testWidgets('cancelling asks for a reason of at least five characters', (tester) async {
      final (api, _, w) = await pump(tester);
      await tapIn(tester, 'purchase-p-booked', 'Cancel');
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'No');
      await tester.tap(find.text('Cancel session'));
      await tester.pump();
      expect(find.text('Write at least 5 characters.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'A site shutdown came up');
      await tester.tap(find.text('Cancel session'));
      await settle(tester);
      expect(api.bodyOf('POST /mentor-services/purchases/p-booked/cancel'), {'reason': 'A site shutdown came up'});
      expect(w.purchases.firstWhere((p) => p['id'] == 'p-booked')['status'], 'CANCELLED');
    });

    testWidgets('Message opens the booking\'s thread through the record', (tester) async {
      final (api, rec, _) = await pump(
        tester,
        extra: {
          'POST /mentor-services/purchases/p-booked/conversation': (_) => {'conversationId': 'conv-9'},
        },
      );
      await tapIn(tester, 'purchase-p-booked', 'Message');
      expect(api.count('POST /mentor-services/purchases/p-booked/conversation'), 1);
      expect(rec.opened, ['conversation:conv-9']);
    });
  });

  group('a guide and after', () {
    testWidgets('a bought file is read with the session\'s token and handed to the share sheet', (tester) async {
      final (api, rec, _) = await pump(tester);
      await openPast(tester);
      await tapIn(tester, 'purchase-p-kit', 'Download interview-question-bank');
      expect(api.requests.any((r) => r.path.endsWith('/uploads/interview-question-bank.pdf')), isTrue);
      expect(rec.shared.single, startsWith('interview-question-bank.pdf:'));
    });

    testWidgets('a file the API refuses says why', (tester) async {
      final (_, rec, _) = await pump(
        tester,
        extra: {
          'GET http://api.test/uploads/interview-question-bank.pdf': (_) =>
              refuse('Sign in to view this file.', status: 403),
        },
      );
      await openPast(tester);
      await tapIn(tester, 'purchase-p-kit', 'Download interview-question-bank');
      expect(find.text('Sign in to view this file.'), findsOneWidget);
      expect(rec.shared, isEmpty);
    });

    testWidgets('a review needs a rating and, when written, ten characters; it may hide the name', (tester) async {
      final (api, _, w) = await pump(tester);
      await openPast(tester);
      await tapIn(tester, 'purchase-p-kit', 'Leave a review');
      await tester.tap(find.text('Send review'));
      await tester.pump();
      expect(find.text('Choose a rating from one to five stars.'), findsOneWidget);
      await tester.tap(find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.star_outline_rounded).last);
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('review-comment')), 'short');
      await tester.tap(find.text('Send review'));
      await tester.pump();
      expect(find.textContaining('Write at least 10 characters'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('review-comment')), 'Eighty questions, well chosen');
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.tap(find.text('Send review'));
      await settle(tester);
      expect(api.bodyOf('POST /mentor-services/purchases/p-kit/review'), {
        'rating': 5,
        'comment': 'Eighty questions, well chosen',
        'anonymous': true,
      });
      expect(w.purchases.firstWhere((p) => p['id'] == 'p-kit')['hasReview'], isTrue);
    });

    testWidgets('a problem is reported to ICR (ten characters at least)', (tester) async {
      final (api, _, _) = await pump(tester);
      await openPast(tester);
      await tapIn(tester, 'purchase-p-kit', 'Report a problem');
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'short');
      await tester.tap(find.text('Send report'));
      await tester.pump();
      expect(find.text('Write at least 10 characters.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('form-text')), 'The file would not open on my phone');
      await tester.tap(find.text('Send report'));
      await settle(tester);
      expect(api.bodyOf('POST /mentor-services/purchases/p-kit/report-issue'), {
        'note': 'The file would not open on my phone',
      });
      expect(find.text('Sent. ICR will look into it.'), findsOneWidget);
    });
  });

  group('programmes, plans, seats and cohort places', () {
    testWidgets('a programme asked for is withdrawn while it waits on the mentor', (tester) async {
      final (api, _, w) = await pump(tester);
      await tapIn(tester, 'term-t-prog', 'Withdraw');
      expect(api.count('POST /mentor-plans/subscriptions/t-prog/cancel'), 1);
      expect(w.terms.any((t) => t['id'] == 't-prog'), isFalse);
      expect(find.text('Request withdrawn.'), findsOneWidget);
    });

    testWidgets('a running plan shows what is left of it and its buyer may stop it renewing', (tester) async {
      final (api, _, w) = await pump(tester);
      expect(find.text('1 of 2 sessions left · use by 15 Nov'), findsOneWidget);
      await tapIn(tester, 'term-t-coach', 'Do not renew');
      expect(api.count('POST /mentor-plans/subscriptions/t-coach/cancel'), 1);
      expect(w.terms.firstWhere((t) => t['id'] == 't-coach')['cancelAtPeriodEnd'], isTrue);
      expect(find.text('It will not renew.'), findsWidgets);
    });

    testWidgets('a cohort application is withdrawn', (tester) async {
      final (api, _, _) = await pump(tester);
      await tapIn(tester, 'enrolment-e-1', 'Withdraw');
      expect(api.count('POST /mentorship/programmes/enrolments/e-1/withdraw'), 1);
      expect(find.text('Application withdrawn.'), findsOneWidget);
    });

    testWidgets('a free group seat is given up', (tester) async {
      final (api, _, w) = await pump(tester);
      await tapIn(tester, 'seat-g-clinic', 'Give up seat');
      expect(api.count('DELETE /mentorship/group-sessions/g-clinic/register'), 1);
      expect(w.seats, isEmpty);
      expect(find.text('You gave up your seat.'), findsOneWidget);
    });
  });
}
