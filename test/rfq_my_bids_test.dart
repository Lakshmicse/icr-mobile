import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/rfq/demo_rfq_repository.dart';
import 'package:icr_mobile/features/rfq/my_bids_screen.dart';
import 'package:icr_mobile/features/rfq/open_requirements_screen.dart';
import 'package:icr_mobile/features/rfq/opportunity_screen.dart';
import 'package:icr_mobile/features/rfq/rfq_links.dart';
import 'package:icr_mobile/features/rfq/rfq_models.dart';
import 'package:icr_mobile/features/rfq/supplier_controllers.dart';
import 'package:icr_mobile/features/rfq/widgets/supplier_parts.dart';

import 'helpers/fonts.dart';
import 'rfq_fakes.dart';

/// Every control of "My Bids", tapped. What the API does is proved in
/// `test/live/rfq_live_test.dart`.
void main() {
  late FlakyRfqRepository repo;
  final threads = <String>[];

  setUpAll(loadAppFonts);
  setUp(() {
    RfqClock.now = () => DateTime.utc(2026, 10, 25, 9);
    repo = FlakyRfqRepository(now: RfqClock.now());
    threads.clear();
  });
  tearDown(RfqClock.reset);

  Future<void> open(WidgetTester tester) =>
      pumpScreen(tester, MyBidsScreen(repository: repo, links: RecordingRfqLinks(), onOpenConversation: threads.add));

  testWidgets('opens on Submitted, with counts on every tab', (tester) async {
    await open(tester);
    expect(find.text('Submitted 0'), findsOneWidget);
    expect(find.text('Shortlisted 1'), findsOneWidget);
    expect(find.text('Won 1'), findsOneWidget);
    expect(find.text('Archived 0'), findsOneWidget);
    expect(find.text('No bids waiting'), findsOneWidget);
  });

  testWidgets('Find work from the empty Submitted tab opens the open board', (tester) async {
    await open(tester);
    await tester.tap(find.text('Find work'));
    await settle(tester, 8);
    expect(find.byType(OpenRequirementsScreen), findsOneWidget);
  });

  testWidgets('Shortlisted shows the bid with its price, lead time and status', (tester) async {
    await open(tester);
    await tester.tap(find.text('Shortlisted 1'));
    await settle(tester);
    expect(find.byType(MyBidCard), findsOneWidget);
    expect(find.text('Corporate Offices — Cafeteria deep cleaning'), findsOneWidget);
    expect(find.text('₹4,20,000'), findsOneWidget);
    expect(find.textContaining('5 days lead time'), findsOneWidget);
    expect(find.text('Shortlisted'), findsWidgets);
  });

  testWidgets('Won shows the purchase order', (tester) async {
    await open(tester);
    await tester.tap(find.text('Won 1'));
    await settle(tester);
    expect(find.text('Purchase order PO-MH3K9Z'), findsOneWidget);
  });

  testWidgets('a fresh bid shows under Submitted and a declined invitation under Archived', (tester) async {
    await repo.placeBid(DemoRfqRepository.boardId, {'message': 'We can start in a week.', 'totalAmount': 1700000});
    await repo.declineInvite(DemoRfqRepository.invitedId);
    await open(tester);
    expect(find.text('Submitted 1'), findsOneWidget);
    expect(find.text('Annual HVAC AMC — Alpha Tech Park, Hyderabad'), findsOneWidget);
    expect(find.text('₹17,00,000'), findsOneWidget);

    await tester.tap(find.text('Archived 1'));
    await settle(tester);
    expect(find.text('You declined this invitation'), findsOneWidget);
    await tester.tap(find.text('Drone facade cleaning — four towers'));
    await settle(tester, 8);
    expect(find.byType(OpportunityScreen), findsOneWidget);
  });

  testWidgets('a card opens the requirement as the supplier sees it', (tester) async {
    await open(tester);
    await tester.tap(find.text('Shortlisted 1'));
    await settle(tester);
    await tester.tap(find.text('View requirement'));
    await settle(tester, 8);
    expect(find.byType(OpportunityScreen), findsOneWidget);
  });

  testWidgets('Message buyer opens the thread with the buyer through the lead callback', (tester) async {
    await open(tester);
    await tester.tap(find.text('Shortlisted 1'));
    await settle(tester);
    await tester.tap(find.text('Message buyer'));
    await settle(tester);
    expect(threads, ['demo-thread-buyer-demo-board-cafeteria']);
  });

  testWidgets('with no listing the screen offers to start selling, and does', (tester) async {
    repo.vendorAccess = const VendorAccess();
    await open(tester);
    expect(find.text('Start selling to bid on requirements'), findsOneWidget);
    await tester.tap(find.text('Start selling'));
    await settle(tester);
    expect(find.text('Shortlisted 1'), findsOneWidget);
  });

  testWidgets('a buyer account is told the screen is for suppliers', (tester) async {
    repo.accessError = ApiError('Insufficient role permissions', statusCode: 403);
    await open(tester);
    expect(find.text('This is for supplier accounts'), findsOneWidget);
  });

  testWidgets('a failed load says so, and Try again reads it again', (tester) async {
    repo.failReads = true;
    await open(tester);
    expect(find.text("Couldn't load your bids"), findsOneWidget);
    repo.failReads = false;
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(find.text('Shortlisted 1'), findsOneWidget);
  });

  testWidgets('pulling down reads the bids again', (tester) async {
    await open(tester);
    await tester.tap(find.text('Shortlisted 1'));
    await settle(tester);
    final before = repo.calls.where((c) => c == 'myBids').length;
    await tester.fling(find.byType(MyBidCard), const Offset(0, 300), 1000);
    await settle(tester, 12);
    expect(repo.calls.where((c) => c == 'myBids').length, greaterThan(before));
  });

  test('the words on a bid', () {
    MyBid bid(BidStatus s, {bool awarded = false, RfqKind kind = RfqKind.rfq, RfqStatus rfq = RfqStatus.published}) =>
        MyBid(
          id: 'b',
          rfqId: 'r',
          status: s,
          isAwarded: awarded,
          requirement: Requirement(id: 'r', title: 't', kind: kind, status: rfq),
        );
    expect(myBidStatusLabel(bid(BidStatus.pending)), 'Submitted');
    expect(myBidStatusLabel(bid(BidStatus.pending, kind: RfqKind.enquiry)), 'Replied');
    expect(myBidStatusLabel(bid(BidStatus.pending, rfq: RfqStatus.closed)), 'Closed');
    expect(myBidStatusLabel(bid(BidStatus.rejected)), 'Not selected');
    expect(myBidStatusLabel(bid(BidStatus.awarded, awarded: true)), 'Won');
    expect(myBidStatusLabel(bid(BidStatus.awarded, awarded: true, kind: RfqKind.enquiry)), 'Selected');
    expect(leadTimeLabel(1), '1 day');
    expect(leadTimeLabel(0), 'Same day');
  });

  test('the tabs sort a bid by where it stands', () async {
    final c = MyBidsController(repo);
    await c.start();
    expect(c.bidsIn(BidsTab.shortlisted).map((b) => b.id), ['demo-mybid-1']);
    expect(c.bidsIn(BidsTab.awarded).map((b) => b.id), ['demo-mybid-2']);
    expect(c.count(BidsTab.archived), 0);
  });
}
