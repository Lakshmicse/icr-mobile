import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/rfq/demo_rfq_repository.dart';
import 'package:icr_mobile/features/rfq/my_bids_screen.dart';
import 'package:icr_mobile/features/rfq/opportunity_screen.dart';
import 'package:icr_mobile/features/rfq/rfq_detail_screen.dart';
import 'package:icr_mobile/features/rfq/rfq_links.dart';
import 'package:icr_mobile/features/rfq/rfq_models.dart';
import 'package:icr_mobile/features/rfq/supplier_controllers.dart';

import 'helpers/fonts.dart';
import 'rfq_fakes.dart';

/// Every control of the supplier's page of a requirement, tapped: who is buying and how well it fits, the one card
/// that says what can be done now (reply, quote, answer pre-qualification, wait, read back what was sent, change or
/// withdraw it, decline an invitation), what each refusal looks like (a used-up plan, an unverified listing, the
/// early-access window, a closed requirement), the buyer's contact and the chat. What the API does is proved in
/// `test/live/rfq_live_test.dart`.
void main() {
  late FlakyRfqRepository repo;
  late RecordingRfqLinks links;
  final threads = <String>[];
  var plans = 0;

  setUpAll(loadAppFonts);
  setUp(() {
    RfqClock.now = () => DateTime.utc(2026, 10, 25, 9);
    repo = FlakyRfqRepository(now: RfqClock.now());
    links = RecordingRfqLinks();
    threads.clear();
    plans = 0;
  });
  tearDown(RfqClock.reset);

  Future<void> open(
    WidgetTester tester,
    String id, {
    String? section,
    bool wirePlans = true,
    double height = 3200,
  }) async {
    tester.view.physicalSize = Size(390, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: OpportunityScreen(
          id,
          section: section,
          repository: repo,
          links: links,
          onOpenConversation: threads.add,
          onSeePlans: wirePlans ? () => plans++ : null,
        ),
      ),
    );
    await settle(tester, 10);
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> tapKey(WidgetTester tester, String k, {int frames = 10}) async {
    await tester.ensureVisible(key(k));
    await tester.tap(key(k));
    await settle(tester, frames);
  }

  Future<void> type(WidgetTester tester, String k, String text) async {
    await tester.ensureVisible(key(k));
    await tester.enterText(key(k), text);
    await tester.pump();
  }

  const hvac = DemoRfqRepository.boardId;
  const facade = DemoRfqRepository.invitedId;
  const guarding = DemoRfqRepository.guardingId;
  const housekeeping = 'demo-board-housekeeping';

  group('the page', () {
    testWidgets('names the buyer, how well the requirement fits and what the supplier can do', (tester) async {
      await open(tester, hvac);
      expect(find.text('Alpha Tech Parks'), findsOneWidget);
      expect(find.text('Verified buyer • GST on file'), findsOneWidget);
      expect(find.text('Annual HVAC AMC — Alpha Tech Park, Hyderabad'), findsOneWidget);
      expect(find.text('Reply to this enquiry'), findsOneWidget);
      expect(find.text("Replying to an enquiry doesn't use your monthly bids."), findsOneWidget);
      expect(find.text('Strong match'), findsOneWidget);
      expect(find.text('In a category you list'), findsOneWidget);
      expect(find.descendant(of: key('match-category'), matching: find.text('+50')), findsOneWidget);
      expect(find.descendant(of: key('match-location'), matching: find.text('+0')), findsNothing);
      expect(find.text('Reply now'), findsOneWidget);
      expect(find.text('At a glance'), findsOneWidget);
      expect(find.text('Contact the buyer'), findsOneWidget);
      expect(repo.seen, [(AlertSide.supplier, hvac)]);
    });

    testWidgets('the arrow goes back and the bell opens the alerts', (tester) async {
      await open(tester, hvac);
      await tester.tap(find.bySemanticsLabel(RegExp('Notifications')));
      await settle(tester, 14);
      expect(find.text('Alerts'), findsOneWidget);
    });

    testWidgets('a failed load says so and Try again reads it again', (tester) async {
      repo.failReads = true;
      await open(tester, hvac, height: 900);
      expect(find.text("Couldn't load this requirement"), findsOneWidget);
      repo.failReads = false;
      await tester.tap(find.text('Try again'));
      await settle(tester, 12);
      expect(find.text('Reply to this enquiry'), findsOneWidget);
    });

    testWidgets('pulling the page down reads it again', (tester) async {
      await open(tester, hvac, height: 900);
      final before = repo.calls.where((c) => c == 'opportunity').length;
      await tester.fling(find.text('Reply to this enquiry'), const Offset(0, 300), 1000);
      await settle(tester, 14);
      expect(repo.calls.where((c) => c == 'opportunity').length, greaterThan(before));
    });

    testWidgets('the early-access window shows the API\'s sentence and the way to the plans', (tester) async {
      repo.requirementError = ApiError(
        'This requirement opens to your plan on 27 Oct 2026, 3:00 PM. The Business plan sees it now.',
        statusCode: 403,
      );
      await open(tester, hvac, height: 900);
      expect(find.text('Not open to your plan yet'), findsOneWidget);
      expect(find.textContaining('The Business plan sees it now'), findsOneWidget);
      await tester.tap(find.text('See plans'));
      expect(plans, 1);
    });

    testWidgets('with no plans screen wired, "See plans" opens the website\'s pricing page', (tester) async {
      repo.requirementError = ApiError('This requirement opens to your plan on 27 Oct 2026.', statusCode: 403);
      await open(tester, hvac, wirePlans: false, height: 900);
      await tester.tap(find.text('See plans'));
      await settle(tester);
      expect(links.opened.single.path, '/pricing/supplier');
    });

    testWidgets('a private or missing requirement is simply not available', (tester) async {
      repo.requirementError = ApiError('RFQ not found', statusCode: 404);
      await open(tester, facade, height: 900);
      expect(find.text('This requirement is not available'), findsOneWidget);
      expect(find.text('Reply to this enquiry'), findsNothing);
    });
  });

  group('replying to an enquiry', () {
    testWidgets('an empty reply is refused before it is sent', (tester) async {
      await open(tester, hvac);
      await tapKey(tester, 'reply-send');
      expect(find.text('Write a reply, or give an indicative price'), findsOneWidget);
      expect(repo.placed, isEmpty);
    });

    testWidgets('a reply is sent as the API takes it and read back, with the bar now saying so', (tester) async {
      await open(tester, hvac);
      await type(tester, 'reply-message', 'We can start in a week and cover both plants.');
      await type(tester, 'reply-amount', '17,00,000');
      await type(tester, 'reply-lead', '7');
      await tapKey(tester, 'reply-send', frames: 14);
      final (id, body) = repo.placed.single;
      expect(id, hvac);
      expect(body, {
        'totalAmount': 1700000.0,
        'leadTimeDays': 7,
        'message': 'We can start in a week and cover both plants.',
      });
      expect(find.text('Your reply'), findsOneWidget);
      expect(find.text('Your reply was sent.'), findsOneWidget);
      expect(find.text('₹17,00,000'), findsWidgets);
      expect(find.text('7 days'), findsOneWidget);
      expect(find.text('Replied'), findsOneWidget);
      expect(find.text('View your reply'), findsOneWidget);
      expect(key('reply-send'), findsNothing);
    });

    testWidgets('a reply with a price only is enough, and a message only too', (tester) async {
      await open(tester, hvac);
      await type(tester, 'reply-amount', '1700000');
      await tapKey(tester, 'reply-send', frames: 14);
      expect(repo.placed.single.$2, {'totalAmount': 1700000.0});
    });

    testWidgets('the price and lead time are held to the rules the API holds', (tester) async {
      await open(tester, hvac);
      await type(tester, 'reply-message', 'Fine.');
      await type(tester, 'reply-amount', '-5');
      await tapKey(tester, 'reply-send');
      expect(find.text('Cannot be negative'), findsOneWidget);
      await type(tester, 'reply-amount', 'abc');
      expect(find.text('Enter an amount in rupees'), findsOneWidget);
      await type(tester, 'reply-amount', '9999999999999');
      expect(find.text('That amount is too large'), findsOneWidget);
      await type(tester, 'reply-amount', '100');
      await type(tester, 'reply-lead', '2.5');
      expect(find.text('Use whole days'), findsOneWidget);
      await type(tester, 'reply-lead', '999999');
      expect(find.text('That is too many days'), findsOneWidget);
      expect(repo.placed, isEmpty);
    });

    testWidgets('files go up as bid attachments, keep the title typed, and are sent with the reply', (tester) async {
      links.toPick = [PickedRfqFile(name: 'quotation.pdf', bytes: List.filled(1024, 1))];
      await open(tester, hvac);
      await type(tester, 'reply-message', 'Quotation attached.');
      await tapKey(tester, 'attach-add');
      expect(repo.uploadPurposes, ['bid-attachment'], reason: 'a quotation is private to the buyer');
      await type(tester, 'file-title-0', 'Priced quotation');
      await tapKey(tester, 'reply-send', frames: 14);
      final files = repo.placed.single.$2['attachments'] as List;
      expect((files.single as Map)['title'], 'Priced quotation');
      expect((files.single as Map)['url'], startsWith('/uploads/'));
    });

    testWidgets('a file with no title is refused, and a send waits while a file is still going up', (tester) async {
      links.toPick = [PickedRfqFile(name: 'quotation.pdf', bytes: List.filled(1024, 1))];
      await open(tester, hvac);
      await type(tester, 'reply-message', 'Quotation attached.');
      await tapKey(tester, 'attach-add');
      await type(tester, 'file-title-0', '');
      await tapKey(tester, 'reply-send');
      expect(find.text('Give every file a title'), findsWidgets);
      expect(repo.placed, isEmpty);
    });
  });

  group('quoting on an RFQ', () {
    testWidgets('a shortlisted supplier at the quote stage is told so, needs a price and sees the allowance', (
      tester,
    ) async {
      await open(tester, guarding);
      expect(find.text('Submit your quote'), findsOneWidget);
      expect(find.text('You\'ve been shortlisted: submit your detailed quote below.'), findsOneWidget);
      expect(find.text('Your plan includes unlimited bids.'), findsOneWidget);
      expect(find.text('Your price'), findsOneWidget);
      expect(find.textContaining('Message to buyer'), findsOneWidget);
      await tapKey(tester, 'reply-send');
      expect(find.text('Enter your price'), findsOneWidget);
      expect(repo.placed, isEmpty);
      await type(tester, 'reply-amount', '41,00,000');
      await type(tester, 'reply-lead', '30');
      await type(tester, 'reply-message', 'Twenty-four guards from the first of next month.');
      await tapKey(tester, 'reply-send', frames: 14);
      expect(repo.placed.single.$2, {
        'totalAmount': 4100000.0,
        'leadTimeDays': 30,
        'message': 'Twenty-four guards from the first of next month.',
      });
      expect(find.text('Your quote'), findsOneWidget);
      expect(find.text('Your quote was submitted.'), findsOneWidget);
      expect(find.text('Submitted'), findsOneWidget);
    });

    testWidgets('the stages show to the supplier as a timeline, with no owner\'s button', (tester) async {
      await open(tester, guarding);
      expect(find.text('Tender stage'), findsOneWidget);
      expect(key('stage-advance'), findsNothing);
      expect(find.text('Review the quotes and award one.'), findsNothing);
    });
  });

  group('the plan and the listing', () {
    testWidgets('a used-up plan is said up front, still lets the send go, and shows the API\'s sentence in the form', (
      tester,
    ) async {
      repo.vendorAccess = const VendorAccess(
        vendorId: 'v',
        verified: true,
        canBid: false,
        canRespondToEnquiry: true,
        bidLimit: 3,
        bidsUsed: 3,
        tier: 'FREE',
      );
      await open(tester, guarding);
      expect(find.text('3 of 3 bids used this month.'), findsOneWidget);
      expect(find.textContaining("You've used this month's bids"), findsOneWidget);
      await type(tester, 'reply-amount', '41,00,000');
      repo.refuseNextWrite = "You've used all 3 of this month's bids. The Business plan includes unlimited bids.";
      await tapKey(tester, 'reply-send', frames: 12);
      expect(
        find.text("You've used all 3 of this month's bids. The Business plan includes unlimited bids."),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(key('reply-amount')).controller!.text,
        '41,00,000',
        reason: 'the form keeps what was typed',
      );
      expect(find.text('Your quote'), findsNothing);
      await tester.tap(find.descendant(of: key('reply-error'), matching: find.text('See plans')));
      expect(plans, 1);
    });

    testWidgets('an unverified listing is told so, and what the API refuses it with is shown', (tester) async {
      repo.vendorAccess = const VendorAccess(vendorId: 'v', verified: false, canBid: false, canRespondToEnquiry: false);
      await open(tester, hvac);
      expect(find.text('Your supplier listing must be verified before you can respond.'), findsOneWidget);
      await type(tester, 'reply-message', 'We would like to reply.');
      repo.refuseNextWrite = 'Your vendor profile must be verified before you can place bids.';
      await tapKey(tester, 'reply-send', frames: 12);
      expect(find.text('Your vendor profile must be verified before you can place bids.'), findsOneWidget);
    });

    testWidgets('a deadline that has passed is the API\'s refusal, shown in place', (tester) async {
      await open(tester, hvac);
      await type(tester, 'reply-message', 'Late reply.');
      repo.refuseNextWrite = 'The deadline for responses to this requirement has passed.';
      await tapKey(tester, 'reply-send', frames: 12);
      expect(find.text('The deadline for responses to this requirement has passed.'), findsOneWidget);
      expect(key('my-reply'), findsNothing);
    });

    testWidgets('a company with no supplier listing starts selling in one tap, then sees the form', (tester) async {
      repo.vendorAccess = const VendorAccess();
      await open(tester, hvac);
      expect(find.text('Start selling to reply to requirements'), findsOneWidget);
      expect(key('reply-send'), findsNothing);
      await tester.tap(find.text('Start selling'));
      await settle(tester, 12);
      expect(repo.calls, contains('startSelling'));
      expect(key('reply-send'), findsOneWidget);
    });

    testWidgets('a verified company with no listing is told it can quote right away', (tester) async {
      repo.vendorAccess = const VendorAccess(listingStartsVerified: true);
      await open(tester, hvac);
      expect(find.textContaining('Your company is already verified'), findsOneWidget);
    });

    testWidgets('a buyer\'s account is told the page is for suppliers, and is offered no form and no match', (
      tester,
    ) async {
      repo.accessError = ApiError('Insufficient role permissions', statusCode: 403);
      await open(tester, hvac);
      expect(find.text('Responses come from suppliers'), findsOneWidget);
      expect(key('reply-send'), findsNothing);
      expect(key('match-card'), findsNothing);
      expect(key('contact-buyer'), findsNothing);
      expect(find.text('At a glance'), findsOneWidget, reason: 'the requirement itself is still readable');
    });

    testWidgets('a company\'s own requirement is not bid on: the page says so and opens it as its owner', (
      tester,
    ) async {
      await open(tester, DemoRfqRepository.securityId);
      expect(find.text('This is your company\'s own requirement'), findsOneWidget);
      expect(key('reply-send'), findsNothing);
      await tester.tap(find.text('Open as owner'));
      await settle(tester, 14);
      expect(find.byType(RfqDetailScreen), findsOneWidget);
    });
  });

  group('an invitation', () {
    testWidgets('is said at the top of the form, and Decline asks first', (tester) async {
      await open(tester, facade);
      expect(find.text('Private invite'), findsOneWidget);
      expect(find.text('You\'ve been invited to reply to this enquiry.'), findsOneWidget);
      await tapKey(tester, 'reply-decline');
      expect(find.text('Decline this invitation?'), findsOneWidget);
      await tester.tap(find.text('Keep it'));
      await settle(tester, 10);
      expect(repo.calls, isNot(contains('declineInvite')));
      await tapKey(tester, 'reply-decline');
      await tester.tap(find.text('Decline').last);
      await settle(tester, 12);
      expect(find.text('Invitation declined'), findsOneWidget);
      expect(find.text('You\'ve declined this quote request. The buyer has been notified.'), findsOneWidget);
      expect(key('reply-send'), findsNothing);
    });

    testWidgets('a refused decline leaves the invitation open with the API\'s sentence', (tester) async {
      await open(tester, facade);
      repo.refuseNextWrite = 'You have already responded to this invitation';
      await tapKey(tester, 'reply-decline');
      await tester.tap(find.text('Decline').last);
      await settle(tester, 12);
      expect(find.text('You have already responded to this invitation'), findsOneWidget);
      expect(key('reply-send'), findsOneWidget);
    });

    testWidgets('an ordinary requirement carries no invitation', (tester) async {
      await open(tester, hvac);
      expect(key('reply-decline'), findsNothing);
    });
  });

  group('pre-qualification', () {
    testWidgets('an RFQ in pre-qualification asks for the criteria answers, validated as the API does', (tester) async {
      await open(tester, housekeeping);
      expect(find.text('Submit pre-qualification response'), findsOneWidget);
      expect(find.text('Respond to the criteria'), findsOneWidget);
      await type(tester, 'pq-years', 'many');
      await type(tester, 'pq-turnover', 'lots');
      await tapKey(tester, 'pq-send');
      expect(find.text('Use a whole number of years'), findsOneWidget);
      expect(find.text('Enter an amount in rupees, like 50,00,000'), findsOneWidget);
      expect(repo.prequalSent, isEmpty);
    });

    testWidgets('the answers go as the API takes them, and the card then says it is being screened', (tester) async {
      await open(tester, housekeeping);
      await type(tester, 'pq-years', '8');
      await type(tester, 'pq-turnover', '5,00,00,000');
      await tapKey(tester, 'pq-presence-PAN_INDIA');
      await tapKey(tester, 'pq-compliance-GST');
      await tapKey(tester, 'pq-compliance-PF');
      await tapKey(tester, 'pq-employees', frames: 12);
      await tester.tap(find.text('201-500 employees').last);
      await settle(tester, 12);
      await tapKey(tester, 'pq-send', frames: 14);
      final (id, body) = repo.prequalSent.single;
      expect(id, housekeeping);
      expect(body['yearsInBusiness'], 8);
      expect(body['annualTurnover'], 50000000.0);
      expect(body['presence'], 'PAN_INDIA');
      expect(body['employeeCount'], '201-500');
      expect(body['statutoryCompliance'], ['GST', 'PF']);
      expect(find.text('Under evaluation'), findsOneWidget);
      expect(find.textContaining('The buyer is screening pre-qualification responses'), findsOneWidget);
    });

    testWidgets('a refusal is shown in the form and the answers stay', (tester) async {
      await open(tester, housekeeping);
      await type(tester, 'pq-years', '8');
      repo.refuseNextWrite = 'Pre-qualification is not open for this RFQ';
      await tapKey(tester, 'pq-send', frames: 12);
      expect(find.text('Pre-qualification is not open for this RFQ'), findsOneWidget);
      expect(tester.widget<TextField>(key('pq-years')).controller!.text, '8');
    });
  });

  group('what was sent', () {
    Future<void> sendReply(WidgetTester tester) async {
      await repo.placeBid(hvac, {'totalAmount': 1700000, 'leadTimeDays': 7, 'message': 'We can start in a week.'});
    }

    testWidgets('is read back with its price, lead time and message, and the bar says "View your reply"', (
      tester,
    ) async {
      await sendReply(tester);
      await open(tester, hvac);
      expect(find.text('Your reply'), findsOneWidget);
      expect(find.text('Sent 25 Oct 2026'), findsOneWidget);
      expect(find.text('₹17,00,000'), findsWidgets);
      expect(find.text('We can start in a week.'), findsOneWidget);
      expect(find.text('View your reply'), findsOneWidget);
      expect(key('reply-send'), findsNothing);
      expect(find.text('Your reply was sent.'), findsNothing, reason: 'only straight after sending');
    });

    testWidgets('"See all your bids" opens My Bids', (tester) async {
      await sendReply(tester);
      await open(tester, hvac);
      await tapKey(tester, 'see-all-bids', frames: 14);
      expect(find.byType(MyBidsScreen), findsOneWidget);
    });

    testWidgets('Edit bid opens the form with what was sent, and saving sends the changes', (tester) async {
      await sendReply(tester);
      await open(tester, hvac);
      await tapKey(tester, 'reply-edit');
      expect(find.text('Change your reply'), findsOneWidget);
      expect(tester.widget<TextField>(key('reply-amount')).controller!.text, '1700000');
      expect(tester.widget<TextField>(key('reply-message')).controller!.text, 'We can start in a week.');
      await type(tester, 'reply-amount', '16,50,000');
      await tapKey(tester, 'reply-send', frames: 14);
      expect(repo.bidChangesSent.single.$1, hvac);
      expect(repo.bidChangesSent.single.$2['totalAmount'], 1650000.0);
      expect(find.text('Your bid was updated.'), findsOneWidget);
      expect(find.text('₹16,50,000'), findsWidgets);
      expect(key('reply-edit'), findsOneWidget);
    });

    testWidgets('leaving an edit keeps the bid as it was', (tester) async {
      await sendReply(tester);
      await open(tester, hvac);
      await tapKey(tester, 'reply-edit');
      await type(tester, 'reply-amount', '1');
      await tapKey(tester, 'reply-cancel');
      expect(repo.bidChangesSent, isEmpty);
      expect(find.text('₹17,00,000'), findsWidgets);
    });

    testWidgets('a refused change shows the API\'s sentence and keeps the form as typed', (tester) async {
      await sendReply(tester);
      await open(tester, hvac);
      await tapKey(tester, 'reply-edit');
      await type(tester, 'reply-amount', '16,00,000');
      repo.refuseNextWrite = 'The deadline for responses to this requirement has passed.';
      await tapKey(tester, 'reply-send', frames: 12);
      expect(find.text('The deadline for responses to this requirement has passed.'), findsOneWidget);
      expect(tester.widget<TextField>(key('reply-amount')).controller!.text, '16,00,000');
    });

    testWidgets('Withdraw asks first, takes the bid back and opens the form again', (tester) async {
      await sendReply(tester);
      await open(tester, hvac);
      await tapKey(tester, 'reply-withdraw');
      expect(find.text('Withdraw your reply?'), findsOneWidget);
      await tester.tap(find.text('Keep it'));
      await settle(tester, 10);
      expect(repo.withdrawn, isEmpty);
      await tapKey(tester, 'reply-withdraw');
      await tester.tap(find.text('Withdraw').last);
      await settle(tester, 14);
      expect(repo.withdrawn, [hvac]);
      expect(find.text('Your bid was withdrawn.'), findsOneWidget);
      expect(key('reply-send'), findsOneWidget);
    });

    testWidgets('where the API has no call to change a bid the buttons are not drawn, and the page says why', (
      tester,
    ) async {
      repo.bidChanges = false;
      await sendReply(tester);
      await open(tester, hvac);
      expect(find.text('Your reply'), findsOneWidget);
      expect(key('reply-edit'), findsNothing);
      expect(key('reply-withdraw'), findsNothing);
      // Two missing buttons are not left unexplained: the sentence names the way (the buyer) and the cause.
      expect(key('bid-changes-note'), findsOneWidget);
      expect(
        find.text('A sent reply cannot be changed or withdrawn on ICR yet. To correct it, message the buyer.'),
        findsOneWidget,
      );
    });

    testWidgets('where a bid can be changed the page offers the buttons and no excuse', (tester) async {
      await sendReply(tester);
      await open(tester, hvac);
      expect(key('reply-edit'), findsOneWidget);
      expect(key('bid-changes-note'), findsNothing);
    });

    testWidgets('a requirement that has closed takes no changes, and does not promise a way to make them', (
      tester,
    ) async {
      repo.bidChanges = false;
      await sendReply(tester);
      repo.setBoardStatus(hvac, RfqStatus.closed);
      await open(tester, hvac);
      expect(key('reply-edit'), findsNothing);
      expect(key('reply-withdraw'), findsNothing);
      expect(key('bid-changes-note'), findsNothing, reason: 'nothing can be corrected on a closed requirement');
    });

    testWidgets('a quotation the supplier sent is opened through their session', (tester) async {
      await repo.placeBid(hvac, {
        'totalAmount': 1700000,
        'attachments': [
          {'title': 'Priced quotation', 'url': '/uploads/q.pdf', 'name': 'q.pdf', 'mimeType': 'application/pdf'},
        ],
      });
      await open(tester, hvac);
      final fileKey = find.byWidgetPredicate(
        (w) => w.key is ValueKey && (w.key as ValueKey).value.toString().startsWith('my-reply-file-'),
      );
      await tester.ensureVisible(fileKey);
      await tester.tap(fileKey);
      await settle(tester);
      expect(links.shared.single.$2, 'q.pdf');
    });

    test('a bid awarded, declined or past its deadline cannot be changed', () async {
      final awarded = _WithBid(
        MyBid(id: 'b', rfqId: DemoRfqRepository.boardId, status: BidStatus.awarded, isAwarded: true, amount: 1),
      );
      final c1 = OpportunityController(repository: awarded, rfqId: DemoRfqRepository.boardId);
      await c1.start();
      expect(c1.canChangeBid, isFalse);
      final declined = _WithBid(
        MyBid(id: 'b', rfqId: DemoRfqRepository.boardId, status: BidStatus.rejected, amount: 1),
      );
      final c2 = OpportunityController(repository: declined, rfqId: DemoRfqRepository.boardId);
      await c2.start();
      expect(c2.canChangeBid, isFalse);
      final pending = _WithBid(MyBid(id: 'b', rfqId: DemoRfqRepository.boardId, status: BidStatus.pending, amount: 1));
      final c3 = OpportunityController(repository: pending, rfqId: DemoRfqRepository.boardId);
      await c3.start();
      expect(c3.canChangeBid, isTrue);
      RfqClock.now = () => DateTime.utc(2027, 1, 1);
      expect(c3.canChangeBid, isFalse, reason: 'the requirement\'s due date has passed');
    });

    test('with no API call to change a bid, only a bid still being weighed is sent to the buyer', () async {
      Future<OpportunityController> controller(MyBid bid) async {
        final c = OpportunityController(repository: _WithBid(bid, changes: false), rfqId: DemoRfqRepository.boardId);
        await c.start();
        return c;
      }

      final pending = await controller(
        MyBid(id: 'b', rfqId: DemoRfqRepository.boardId, status: BidStatus.pending, amount: 1),
      );
      expect(pending.canChangeBid, isFalse);
      expect(pending.bidChangesNeedBuyer, isTrue);
      final shortlisted = await controller(
        MyBid(id: 'b', rfqId: DemoRfqRepository.boardId, status: BidStatus.shortlisted, amount: 1),
      );
      expect(shortlisted.bidChangesNeedBuyer, isTrue);
      final awarded = await controller(
        MyBid(id: 'b', rfqId: DemoRfqRepository.boardId, status: BidStatus.awarded, isAwarded: true, amount: 1),
      );
      expect(awarded.bidChangesNeedBuyer, isFalse, reason: 'a settled bid is not corrected by anyone');
      final declined = await controller(
        MyBid(id: 'b', rfqId: DemoRfqRepository.boardId, status: BidStatus.rejected, amount: 1),
      );
      expect(declined.bidChangesNeedBuyer, isFalse);
      RfqClock.now = () => DateTime.utc(2027, 1, 1);
      expect(pending.bidChangesNeedBuyer, isFalse, reason: 'the deadline has passed');
      RfqClock.reset();

      // Where the API has the calls, the note is never wanted.
      final supported = OpportunityController(
        repository: _WithBid(MyBid(id: 'b', rfqId: DemoRfqRepository.boardId, status: BidStatus.pending, amount: 1)),
        rfqId: DemoRfqRepository.boardId,
      );
      await supported.start();
      expect(supported.bidChangesNeedBuyer, isFalse);
      expect(supported.canChangeBid, isTrue);
    });
  });

  group('the buyer', () {
    testWidgets('Message the buyer opens the thread through the lead callback', (tester) async {
      await open(tester, hvac);
      await tapKey(tester, 'contact-message');
      expect(threads, ['demo-thread-buyer-$hvac']);
    });

    testWidgets('a thread that cannot be opened is said in the card', (tester) async {
      await open(tester, hvac);
      repo.refuseNextWrite = 'This requirement is not open for messages yet.';
      await tapKey(tester, 'contact-message');
      expect(find.text('This requirement is not open for messages yet.'), findsOneWidget);
      expect(threads, isEmpty);
    });

    testWidgets('the contact details are refused before a bid, in the API\'s words, and shown after', (tester) async {
      await open(tester, hvac);
      await tapKey(tester, 'contact-reveal');
      expect(find.text('Place a bid before contacting the buyer'), findsOneWidget);
      expect(key('contact-details'), findsNothing);
      await repo.placeBid(hvac, {'message': 'We can start in a week.'});
      await tester.fling(find.byType(ListView).first, const Offset(0, 300), 1000);
      await settle(tester, 14);
      await tapKey(tester, 'contact-reveal');
      expect(key('contact-details'), findsOneWidget);
      expect(find.text('procurement@example.com'), findsOneWidget);
      expect(find.text('+91 80 4000 1234'), findsOneWidget);
    });

    testWidgets('a plan that does not include the contact offers the plans', (tester) async {
      await repo.placeBid(hvac, {'message': 'We can start in a week.'});
      await open(tester, hvac);
      repo.refuseNextWrite = 'Buyer contact details come with the Business plan.';
      await tapKey(tester, 'contact-reveal');
      expect(find.text('Buyer contact details come with the Business plan.'), findsOneWidget);
      await tester.tap(find.descendant(of: key('contact-error'), matching: find.text('See plans')));
      expect(plans, 1);
    });
  });

  group('the brief', () {
    testWidgets('files of the buyer\'s open in the phone\'s viewer, not the website', (tester) async {
      await open(tester, hvac);
      expect(
        find.text('Quarterly preventive maintenance of two 400 TR chiller plants and 60 AHUs, with breakdown cover.'),
        findsOneWidget,
      );
      expect(find.text('Budget'), findsOneWidget);
      expect(find.text('₹18,00,000'), findsOneWidget);
    });
  });
}

/// The sample repository, with a bid of the supplier's already on the requirement.
class _WithBid extends DemoRfqRepository {
  _WithBid(this.bid, {this.changes = true});

  final MyBid bid;

  /// Whether the API has the calls to change and withdraw a bid.
  final bool changes;

  @override
  bool get supportsBidChanges => changes;

  @override
  Future<OpportunityContext> opportunity(String rfqId) async {
    final base = await super.opportunity(rfqId);
    return OpportunityContext(
      buyer: base.buyer,
      matchScore: base.matchScore,
      matched: base.matched,
      reasons: base.reasons,
      myBid: bid,
    );
  }
}
