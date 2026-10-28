import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/rfq/demo_rfq_repository.dart';
import 'package:icr_mobile/features/rfq/post_rfq_screen.dart';
import 'package:icr_mobile/features/rfq/rfq_detail_screen.dart';
import 'package:icr_mobile/features/rfq/rfq_links.dart';
import 'package:icr_mobile/features/rfq/rfq_models.dart';
import 'package:icr_mobile/features/rfq/widgets/owner_parts.dart';
import 'package:icr_mobile/features/rfq/widgets/rfq_widgets.dart' show PillTabs, TonePill;
import 'package:icr_mobile/features/rfq/widgets/supplier_parts.dart' show RfqSmallButton;

import 'helpers/fonts.dart';
import 'rfq_fakes.dart';

/// Every control of the buyer's requirement page, tapped: the header and what each state offers, the bids (sort,
/// compare, shortlist and take it back, decline and restore, award or select, message, files), the staged RFQ's
/// stages and pre-qualification responses, the suppliers invited and the threads, the brief, and the owner's moves
/// (publish, edit, close, cancel, delete, post a similar one). What the API does is proved in
/// `test/live/rfq_live_test.dart`.
void main() {
  late FlakyRfqRepository repo;
  late RecordingRfqLinks links;
  final threads = <String>[];

  setUpAll(loadAppFonts);
  setUp(() {
    RfqClock.now = () => DateTime.utc(2026, 10, 25, 9);
    repo = FlakyRfqRepository(now: RfqClock.now());
    links = RecordingRfqLinks();
    threads.clear();
  });
  tearDown(RfqClock.reset);

  /// A window tall enough to build the whole page.
  Future<void> open(
    WidgetTester tester,
    String id, {
    String? section,
    String? focusBid,
    bool wireChat = true,
    double height = 2600,
  }) async {
    tester.view.physicalSize = Size(390, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: RfqDetailScreen(
          id,
          section: section,
          focusBidId: focusBid,
          repository: repo,
          links: links,
          onOpenConversation: wireChat ? threads.add : null,
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

  List<String> bidOrder(WidgetTester tester) => [
    for (final c in tester.widgetList<BidResponseCard>(find.byType(BidResponseCard))) c.bid.id,
  ];

  String pillOf(WidgetTester tester, String bidId) {
    final card = find.byKey(ValueKey('bid-card-$bidId'));
    final pills = find.descendant(of: card, matching: find.byType(TonePill));
    return tester.widget<TonePill>(pills.first).label;
  }

  const security = DemoRfqRepository.securityId;
  const ifm = DemoRfqRepository.ifmId;
  const home = DemoRfqRepository.homeId;

  group('an enquiry with bids', () {
    testWidgets('says where it stands, and lists the replies shortlisted first, then by price', (tester) async {
      await open(tester, security);
      expect(find.text('ENQUIRY · PHYSICAL SECURITY'), findsOneWidget);
      expect(find.text('Corporate Security — Biometric systems, CCTV & Manpower'), findsOneWidget);
      expect(find.text('3 replies so far'), findsOneWidget);
      expect(find.text('Replies due in 9 days'), findsOneWidget);
      expect(find.text('Live'), findsWidgets);
      expect(find.text('Replies 3'), findsOneWidget);
      expect(find.text('Suppliers 2'), findsOneWidget);
      expect(find.text('Messages 2'), findsOneWidget);
      expect(bidOrder(tester), ['demo-bid-innowork', 'demo-bid-securetech', 'demo-bid-bluedot']);
      expect(find.text('₹12,50,000'), findsOneWidget);
      expect(find.text('Indicative · 7 days lead time'), findsOneWidget);
      expect(find.textContaining('Twelve PSARA-licensed guards'), findsOneWidget);
    });

    testWidgets('marks the best price and the top rating, and reading it tells the API', (tester) async {
      await open(tester, security);
      final secure = find.byKey(const ValueKey('bid-card-demo-bid-securetech'));
      expect(find.descendant(of: secure, matching: find.text('Best price')), findsOneWidget);
      expect(find.descendant(of: secure, matching: find.text('Top rated')), findsNothing);
      for (final id in ['demo-bid-bluedot', 'demo-bid-innowork']) {
        final card = find.byKey(ValueKey('bid-card-$id'));
        expect(find.descendant(of: card, matching: find.text('Top rated')), findsOneWidget, reason: id);
      }
      expect(repo.seen, [(AlertSide.owner, security)], reason: 'opening the page reads what told the owner about it');
    });

    testWidgets('the sort picks what the replies are weighed on', (tester) async {
      await open(tester, security);
      await tapKey(tester, 'bids-sort');
      await tester.tap(find.text('Fastest lead time'));
      await settle(tester, 10);
      expect(bidOrder(tester), ['demo-bid-innowork', 'demo-bid-bluedot', 'demo-bid-securetech']);
      await tapKey(tester, 'bids-sort');
      await tester.tap(find.text('Highest rating'));
      await settle(tester, 10);
      expect(bidOrder(tester).first, 'demo-bid-innowork');
      await tapKey(tester, 'bids-sort');
      await tester.tap(find.text('Lowest price'));
      await settle(tester, 10);
      expect(bidOrder(tester), ['demo-bid-innowork', 'demo-bid-securetech', 'demo-bid-bluedot']);
    });

    testWidgets('Compare lays the live bids side by side, the best in each row marked, and a name opens that bid', (tester) async {
      await open(tester, security);
      await tapKey(tester, 'compare');
      expect(find.text('Compare the replies'), findsOneWidget);
      expect(key('compare-table'), findsOneWidget);
      expect(find.text('₹10,80,000'), findsWidgets);
      expect(find.text('Lowest'), findsOneWidget);
      expect(find.text('+5.6%'), findsOneWidget, reason: 'BlueDot is 5.6% above the lowest');
      expect(find.text('7 days'), findsWidgets);
      await tester.ensureVisible(key('compare-open-demo-bid-bluedot'));
      await tester.tap(key('compare-open-demo-bid-bluedot'));
      await settle(tester, 12);
      expect(key('compare-table'), findsNothing);
      expect(key('bid-card-demo-bid-bluedot'), findsOneWidget);
    });

    testWidgets('Compare leaves out a declined bid, and is not offered for one bid', (tester) async {
      await open(tester, security);
      await tapKey(tester, 'bid-decline-demo-bid-bluedot');
      await tapKey(tester, 'compare');
      expect(key('compare-open-demo-bid-bluedot'), findsNothing);
      expect(key('compare-open-demo-bid-innowork'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await settle(tester, 10);
      await tapKey(tester, 'bid-decline-demo-bid-securetech');
      expect(key('compare'), findsNothing, reason: 'one live bid has nothing to be compared with');
    });
  });

  group('deciding on a bid', () {
    testWidgets('Shortlist shows at once, goes to the API, and can be taken back', (tester) async {
      await open(tester, security);
      expect(pillOf(tester, 'demo-bid-bluedot'), 'New');
      await tapKey(tester, 'bid-shortlist-demo-bid-bluedot');
      expect(pillOf(tester, 'demo-bid-bluedot'), 'Shortlisted');
      expect(repo.calls, contains('triageBid'));
      expect(key('bid-shortlist-demo-bid-bluedot'), findsNothing);
      await tapKey(tester, 'bid-unshortlist-demo-bid-bluedot');
      expect(pillOf(tester, 'demo-bid-bluedot'), 'New');
    });

    testWidgets('Decline and Restore', (tester) async {
      await open(tester, security);
      await tapKey(tester, 'bid-decline-demo-bid-securetech');
      expect(pillOf(tester, 'demo-bid-securetech'), 'Declined');
      expect(bidOrder(tester).last, 'demo-bid-securetech', reason: 'declined ones go last');
      expect(key('bid-award-demo-bid-securetech'), findsNothing);
      await tapKey(tester, 'bid-restore-demo-bid-securetech');
      expect(pillOf(tester, 'demo-bid-securetech'), 'New');
      expect(key('bid-award-demo-bid-securetech'), findsOneWidget);
    });

    testWidgets('a refusal puts the bid back and says why in the API\'s words', (tester) async {
      await open(tester, security);
      repo.refuseNextWrite = 'An awarded bid cannot change status';
      await tapKey(tester, 'bid-decline-demo-bid-bluedot');
      expect(pillOf(tester, 'demo-bid-bluedot'), 'New');
      expect(find.text('An awarded bid cannot change status'), findsOneWidget);
    });

    testWidgets('Select asks first: Keep it changes nothing, confirming closes the enquiry with that supplier', (tester) async {
      await open(tester, security);
      await tapKey(tester, 'bid-award-demo-bid-bluedot');
      expect(find.text('Select BlueDot?'), findsOneWidget);
      expect(find.textContaining('closes the enquiry with BlueDot as your chosen supplier'), findsOneWidget);
      await tester.tap(find.text('Keep it'));
      await settle(tester, 10);
      expect(pillOf(tester, 'demo-bid-bluedot'), 'New');
      expect(repo.calls, isNot(contains('award')));
      await tapKey(tester, 'bid-award-demo-bid-bluedot');
      await tester.tap(find.text('Confirm selection'));
      await settle(tester, 12);
      expect(find.text('BlueDot selected. The other suppliers have been told.'), findsOneWidget);
      expect(pillOf(tester, 'demo-bid-bluedot'), 'Selected');
      expect(pillOf(tester, 'demo-bid-innowork'), 'Declined');
      expect(key('bid-award-demo-bid-innowork'), findsNothing, reason: 'a settled requirement takes no more decisions');
      expect(find.text('Awarded. Close it once the work is under way.'), findsOneWidget);
    });

    testWidgets('an RFQ is awarded, and the purchase order comes back in the sentence', (tester) async {
      repo.addBidFor(
        ifm,
        Bid(id: 'rfq-bid-1', rfqId: ifm, supplier: DemoRfqRepository.vikasha, status: BidStatus.pending, amount: 24000000, leadTimeDays: 30),
      );
      repo.setRfqStage(ifm, RfqStage.quotation);
      await open(tester, ifm);
      expect(find.text('Bids (1)'), findsOneWidget);
      await tapKey(tester, 'bid-award-rfq-bid-1');
      expect(find.text('Award to Vikasha Aero Tech?'), findsOneWidget);
      expect(find.textContaining('generates a purchase order, and declines all other bids'), findsOneWidget);
      await tester.tap(find.text('Confirm award'));
      await settle(tester, 12);
      expect(find.textContaining('Awarded to Vikasha Aero Tech — purchase order PO-DEMO'), findsOneWidget);
      expect(pillOf(tester, 'rfq-bid-1'), 'Awarded');
    });

    testWidgets('a refused award changes nothing and shows the API\'s sentence', (tester) async {
      await open(tester, security);
      repo.refuseNextWrite = 'Only a published requirement that is still open can be awarded';
      await tapKey(tester, 'bid-award-demo-bid-bluedot');
      await tester.tap(find.text('Confirm selection'));
      await settle(tester, 12);
      expect(find.text('Only a published requirement that is still open can be awarded'), findsOneWidget);
      expect(pillOf(tester, 'demo-bid-bluedot'), 'New');
    });

    testWidgets('a long message is cut and Show more reads it all', (tester) async {
      repo.addBidFor(
        security,
        Bid(
          id: 'long-bid',
          rfqId: security,
          supplier: DemoRfqRepository.safeHome,
          status: BidStatus.pending,
          amount: 1300000,
          message: List.filled(40, 'We would deliver this in phases with a supervisor on site.').join(' '),
        ),
      );
      await open(tester, security);
      expect(key('bid-more-long-bid'), findsOneWidget);
      expect(tester.widget<Text>(key('bid-message-text-long-bid')).maxLines, 4);
      await tapKey(tester, 'bid-more-long-bid');
      expect(tester.widget<Text>(key('bid-message-text-long-bid')).maxLines, isNull);
      expect(find.text('Show less'), findsOneWidget);
    });
  });

  group('messages and files', () {
    testWidgets('Message on a bid that has a thread opens that thread through the lead callback', (tester) async {
      await open(tester, security);
      await tapKey(tester, 'bid-message-demo-bid-bluedot');
      expect(threads, ['demo-thread-bluedot']);
      expect(repo.calls, isNot(contains('openConversation')), reason: 'the bid already carries its thread');
    });

    testWidgets('on a bid with no thread yet the API opens one, naming the supplier\'s company', (tester) async {
      await open(tester, security);
      await tapKey(tester, 'bid-message-demo-bid-securetech');
      expect(threads, ['demo-thread-demo-c-securetech-demo-rfq-security']);
      expect(repo.calls, contains('openConversation'));
    });

    testWidgets('with no chat wired the website\'s inbox opens on the thread', (tester) async {
      await open(tester, security, wireChat: false);
      await tapKey(tester, 'bid-message-demo-bid-bluedot');
      expect(links.opened.single.path, '/messaging');
      expect(links.opened.single.query, 'c=demo-thread-bluedot');
    });

    testWidgets('a thread that cannot be opened says why', (tester) async {
      await open(tester, security);
      repo.refuseNextWrite = 'That supplier has not been involved in this requirement.';
      await tapKey(tester, 'bid-message-demo-bid-securetech');
      expect(find.text('That supplier has not been involved in this requirement.'), findsOneWidget);
      expect(threads, isEmpty);
    });

    testWidgets('a bid\'s file is a private upload: it is fetched with the session and handed to the phone', (tester) async {
      await open(tester, security);
      await tapKey(tester, 'bid-file-demo-bidfile-1');
      expect(repo.calls, contains('saveFile'));
      expect(links.shared, [('/tmp/demo-quotation.pdf', 'quotation.pdf')]);
    });

    testWidgets('a file the phone cannot take is said so, and one that cannot be fetched too', (tester) async {
      links = RecordingRfqLinks(opens: false);
      await open(tester, security);
      await tapKey(tester, 'bid-file-demo-bidfile-1');
      expect(find.textContaining('Nothing on this phone could open quotation.pdf'), findsOneWidget);
      repo.refuseNextWrite = 'forbidden';
      await tapKey(tester, 'bid-file-demo-bidfile-1');
      expect(find.textContaining("Couldn't fetch quotation.pdf"), findsOneWidget);
    });
  });

  group('the suppliers', () {
    testWidgets('lists who was invited and what they did, and messages them', (tester) async {
      await open(tester, security);
      await tester.tap(find.text('Suppliers 2'));
      await settle(tester, 10);
      expect(find.text('Invited companies (2)'), findsOneWidget);
      final blue = find.byKey(const ValueKey('invited-demo-v-bluedot'));
      expect(find.descendant(of: blue, matching: find.text('Responded')), findsOneWidget);
      final vikasha = find.byKey(const ValueKey('invited-demo-v-vikasha'));
      expect(find.descendant(of: vikasha, matching: find.text('Invited')), findsOneWidget);
      await tapKey(tester, 'invited-message-demo-v-bluedot');
      expect(threads, ['demo-thread-demo-c-bluedot-$security']);
    });

    testWidgets('Invite companies suggests the ones that fit, leaves out the invited, and sends the choice', (tester) async {
      await open(tester, security);
      await tester.tap(find.text('Suppliers 2'));
      await settle(tester, 10);
      await tapKey(tester, 'invite-open', frames: 14);
      expect(find.text('Suggested for this requirement'), findsOneWidget);
      expect(key('supplier-demo-v-bluedot'), findsNothing, reason: 'already invited');
      expect(key('supplier-demo-v-greenguard'), findsOneWidget);
      expect(find.text('fit 80'), findsOneWidget);
      await tester.tap(key('supplier-demo-v-greenguard'));
      await settle(tester);
      await tester.tap(key('supplier-demo-v-safehome'));
      await settle(tester);
      expect(find.text('Invite (2)'), findsOneWidget);
      await tester.tap(key('supplier-confirm'));
      await settle(tester, 14);
      expect(find.text('Invitations sent.'), findsOneWidget);
      expect(find.text('Invited companies (4)'), findsOneWidget);
      expect(key('invited-demo-v-greenguard'), findsOneWidget);
    });

    testWidgets('a supplier is found by name, and a refusal stays in the sheet with the choice kept', (tester) async {
      await open(tester, security);
      await tester.tap(find.text('Suppliers 2'));
      await settle(tester, 10);
      await tapKey(tester, 'invite-open', frames: 14);
      await tester.enterText(key('supplier-search'), 'secure');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(key('supplier-demo-v-securetech'), findsOneWidget);
      expect(key('supplier-demo-v-greenguard'), findsNothing);
      await tester.tap(key('supplier-demo-v-securetech'));
      await settle(tester);
      repo.refuseNextWrite = 'You can invite at most 50 suppliers to one requirement.';
      await tester.tap(key('supplier-confirm'));
      await settle(tester, 12);
      expect(find.text('You can invite at most 50 suppliers to one requirement.'), findsOneWidget);
      expect(find.text('Invite (1)'), findsOneWidget, reason: 'the choice is kept so it can be sent again');
      await tester.tap(key('supplier-confirm'));
      await settle(tester, 14);
      expect(find.text('Invitations sent.'), findsOneWidget);
    });

    testWidgets('a closed requirement offers no invitations', (tester) async {
      await open(tester, security);
      await tapKey(tester, 'act-close');
      await tester.tap(find.text('Close it'));
      await settle(tester, 12);
      await tester.tap(find.text('Suppliers 2'));
      await settle(tester, 10);
      expect(key('invite-open'), findsNothing);
    });
  });

  group('the threads', () {
    testWidgets('each supplier\'s thread shows the last words and what is unread, and opens in the chat', (tester) async {
      await open(tester, security);
      await tester.tap(find.text('Messages 2'));
      await settle(tester, 10);
      expect(find.text('Supplier messages (2)'), findsOneWidget);
      expect(find.text('Happy to walk the floors with your admin team this week.'), findsOneWidget);
      expect(find.descendant(of: key('thread-unread-demo-thread-bluedot'), matching: find.text('1')), findsOneWidget);
      expect(key('thread-unread-demo-thread-innowork'), findsNothing);
      await tester.tap(key('thread-demo-thread-bluedot'));
      await settle(tester, 10);
      expect(threads, ['demo-thread-bluedot']);
    });

    testWidgets('a requirement nobody has written about says so', (tester) async {
      await open(tester, ifm);
      await tester.tap(find.text('Messages 0'));
      await settle(tester, 10);
      expect(find.text('No messages yet'), findsOneWidget);
    });
  });

  group('what was posted', () {
    testWidgets('shows the brief to the owner, with the contact on it and the files opened outside the app', (tester) async {
      await open(tester, security);
      await tester.tap(find.text('What you posted'));
      await settle(tester, 10);
      expect(find.text('At a glance'), findsOneWidget);
      expect(find.text('Line items'), findsOneWidget);
      expect(find.text('Security guards (24×7)'), findsOneWidget);
      expect(find.text('Contact on this requirement'), findsOneWidget);
      expect(find.text('Bharat Buyer'), findsWidgets);
      expect(find.text('1 file from the buyer'), findsOneWidget);
      await tapKey(tester, 'brief-file-demo-file-1');
      expect(links.opened.single.path, '/uploads/demo-floor-plan.pdf');
      expect(repo.calls, isNot(contains('saveFile')), reason: 'requirement files are public: the phone opens them itself');
    });
  });

  group('the owner\'s moves', () {
    testWidgets('a live requirement offers Edit, Close, Cancel and a similar one, never Publish or Delete', (tester) async {
      await open(tester, security);
      expect(find.text('Live: suppliers can find it and reply.'), findsOneWidget);
      for (final k in ['act-edit', 'act-close', 'act-cancel', 'act-similar']) {
        expect(key(k), findsOneWidget, reason: k);
      }
      expect(key('act-publish'), findsNothing);
      expect(key('act-delete'), findsNothing);
    });

    testWidgets('Close asks first and then says it is closed', (tester) async {
      await open(tester, security);
      await tapKey(tester, 'act-close');
      expect(find.text('Close this enquiry?'), findsOneWidget);
      await tester.tap(find.text('Keep it'));
      await settle(tester, 10);
      expect(repo.calls, isNot(contains('act')));
      await tapKey(tester, 'act-close');
      await tester.tap(find.text('Close it'));
      await settle(tester, 12);
      expect(find.text('Closed: suppliers can no longer reply.'), findsOneWidget);
      expect(key('act-close'), findsNothing);
      expect(key('bid-award-demo-bid-bluedot'), findsNothing);
    });

    testWidgets('Cancel says it cannot be undone and takes the requirement off the board', (tester) async {
      await open(tester, security);
      await tapKey(tester, 'act-cancel');
      expect(find.textContaining('can’t be undone'), findsOneWidget);
      await tester.tap(find.text('Cancel requirement').last);
      await settle(tester, 12);
      expect(find.text('Cancelled: it is no longer listed.'), findsOneWidget);
    });

    testWidgets('a refused close puts the page back and shows the API\'s sentence', (tester) async {
      await open(tester, security);
      await tapKey(tester, 'act-close');
      repo.refuseNextWrite = 'Cannot move requirement from CLOSED to CLOSED';
      await tester.tap(find.text('Close it'));
      await settle(tester, 12);
      expect(find.text('Cannot move requirement from CLOSED to CLOSED'), findsOneWidget);
      expect(find.text('Live: suppliers can find it and reply.'), findsOneWidget);
    });

    testWidgets('a draft offers Publish, Edit, Cancel and Delete, and Publish makes it live', (tester) async {
      await open(tester, home);
      expect(find.text('Only your team can see it. Publish it to reach suppliers.'), findsOneWidget);
      for (final k in ['act-publish', 'act-edit', 'act-similar', 'act-cancel', 'act-delete']) {
        expect(key(k), findsOneWidget, reason: k);
      }
      expect(key('act-close'), findsNothing);
      await tapKey(tester, 'act-publish');
      expect(find.text('Live: suppliers can find it and reply.'), findsOneWidget);
      expect(key('act-publish'), findsNothing);
    });

    testWidgets('Delete draft asks first, then leaves the page', (tester) async {
      tester.view.physicalSize = const Size(390, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => RfqDetailScreen(home, repository: repo, links: links)),
                ),
                child: const Text('open it'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open it'));
      await settle(tester, 14);
      await tapKey(tester, 'act-delete');
      expect(find.text('Delete this draft?'), findsOneWidget);
      await tester.tap(find.text('Keep it'));
      await settle(tester, 10);
      expect(find.byType(RfqDetailScreen), findsOneWidget);
      await tapKey(tester, 'act-delete');
      await tester.tap(find.text('Delete draft').last);
      await settle(tester, 16);
      expect(find.byType(RfqDetailScreen), findsNothing);
      expect(repo.calls, contains('deleteDraft'));
    });

    testWidgets('Edit opens the composer on this requirement, and the page reads it again when it comes back', (tester) async {
      await open(tester, security);
      final before = repo.calls.where((c) => c == 'bids').length;
      await tapKey(tester, 'act-edit', frames: 14);
      final composer = tester.widget<PostRfqScreen>(find.byType(PostRfqScreen));
      expect(composer.editRfqId, security);
      await tester.tap(find.bySemanticsLabel('Back').last);
      await settle(tester, 14);
      expect(repo.calls.where((c) => c == 'bids').length, before, reason: 'nothing was saved, so nothing is read again');
    });

    testWidgets('"Post a similar one" opens the composer starting from it', (tester) async {
      await open(tester, security);
      await tapKey(tester, 'act-similar', frames: 14);
      expect(tester.widget<PostRfqScreen>(find.byType(PostRfqScreen)).copyFromRfqId, security);
    });
  });

  group('a staged RFQ', () {
    testWidgets('shows its five stages, and the button moves it on', (tester) async {
      await open(tester, ifm);
      expect(find.text('Tender stage'), findsOneWidget);
      for (final s in RfqStage.values) {
        expect(find.textContaining(s.label), findsWidgets, reason: s.label);
      }
      expect(find.text('Until 30 Oct'), findsOneWidget);
      expect(find.text('By 13 Nov'), findsOneWidget);
      expect(find.text('Responses 2'), findsOneWidget);
      expect(find.text('Start screening & shortlist'), findsOneWidget);
      await tapKey(tester, 'stage-advance');
      expect(find.text('Open detailed quotes'), findsOneWidget);
      expect(repo.calls, contains('setStage'));
    });

    testWidgets('a refused move shows the sentence and the stage stays', (tester) async {
      await open(tester, ifm);
      repo.refuseNextWrite = 'Cannot move RFQ stage from PREQUALIFICATION to SHORTLISTING';
      await tapKey(tester, 'stage-advance');
      expect(find.text('Cannot move RFQ stage from PREQUALIFICATION to SHORTLISTING'), findsOneWidget);
      expect(find.text('Start screening & shortlist'), findsOneWidget);
    });

    testWidgets('each pre-qualification response is read against the criteria, with the unmet ones named', (tester) async {
      await open(tester, ifm, section: 'prequal');
      expect(find.text('Pre-qualification responses (2)'), findsOneWidget);
      expect(find.text('Meets all your criteria'), findsOneWidget);
      expect(find.textContaining('3 unmet: Annual turnover, Presence, Statutory compliance (ESI)'), findsOneWidget);
      final green = find.byKey(const ValueKey('prequal-demo-v-greenguard'));
      expect(find.descendant(of: green, matching: find.text('To screen')), findsOneWidget);
      expect(find.descendant(of: green, matching: find.text('₹8.2 Cr')), findsOneWidget);
      expect(find.descendant(of: green, matching: find.text('Pan-India')), findsWidgets);
      expect(find.descendant(of: green, matching: find.text('Provident Fund (PF)')), findsOneWidget);
    });

    testWidgets('Qualify and Not qualified screen a response, and Shortlist waits for the shortlisting stage', (tester) async {
      await open(tester, ifm);
      await tapKey(tester, 'prequal-qualify-demo-v-greenguard');
      final green = find.byKey(const ValueKey('prequal-demo-v-greenguard'));
      expect(find.descendant(of: green, matching: find.text('Qualified')), findsOneWidget);
      expect(tester.widget<RfqSmallButton>(key('prequal-shortlist-demo-v-greenguard')).onTap, isNull, reason: 'not yet');
      expect(find.text('Move the RFQ on to "Screening & shortlist" to shortlist qualified suppliers.'), findsOneWidget);
      await tapKey(tester, 'stage-advance');
      await tapKey(tester, 'prequal-shortlist-demo-v-greenguard');
      expect(find.descendant(of: green, matching: find.text('Shortlisted')), findsOneWidget);
      expect(key('prequal-shortlist-demo-v-greenguard'), findsNothing);
      await tapKey(tester, 'prequal-reject-demo-v-safehome');
      final safe = find.byKey(const ValueKey('prequal-demo-v-safehome'));
      expect(find.descendant(of: safe, matching: find.text('Not qualified')), findsWidgets);
      expect(repo.calls, containsAll(['screen', 'setStage', 'shortlist']));
    });

    testWidgets('a refused screening goes back and shows the API\'s sentence', (tester) async {
      await open(tester, ifm);
      repo.refuseNextWrite = 'Could not update this response.';
      await tapKey(tester, 'prequal-qualify-demo-v-greenguard');
      expect(find.text('Could not update this response.'), findsOneWidget);
      final green = find.byKey(const ValueKey('prequal-demo-v-greenguard'));
      expect(find.descendant(of: green, matching: find.text('To screen')), findsOneWidget);
    });

    testWidgets('Message on a response opens the thread with that supplier', (tester) async {
      await open(tester, ifm);
      await tapKey(tester, 'prequal-message-demo-v-greenguard');
      expect(threads, ['demo-thread-demo-c-greenguard-$ifm']);
    });

    testWidgets('a staged RFQ has no Suppliers tab: the screening is its way of choosing suppliers', (tester) async {
      await open(tester, ifm);
      final tabs = find.byType(PillTabs<OwnerTab>);
      expect(find.descendant(of: tabs, matching: find.textContaining('Suppliers')), findsNothing);
      expect(find.descendant(of: tabs, matching: find.text('Responses 2')), findsOneWidget);
    });
  });

  group('landing from a notification', () {
    testWidgets('a bid in the link is ringed, and the page opens on the bids', (tester) async {
      await open(tester, security, focusBid: 'demo-bid-securetech');
      expect(tester.widget<BidResponseCard>(key('bid-card-demo-bid-securetech')).focused, isTrue);
      expect(tester.widget<BidResponseCard>(key('bid-card-demo-bid-bluedot')).focused, isFalse);
    });

    testWidgets('section=invited opens the suppliers', (tester) async {
      await open(tester, security, section: 'invited');
      expect(find.text('Invited companies (2)'), findsOneWidget);
    });
  });

  group('when the page cannot be shown', () {
    testWidgets('a requirement that is not the caller\'s shows the brief and says so', (tester) async {
      repo.forbidBids = true;
      await open(tester, security);
      expect(find.textContaining('belongs to another company or person'), findsOneWidget);
      expect(key('manage-card'), findsNothing);
      expect(find.text('At a glance'), findsOneWidget);
      expect(find.text('Replies 0'), findsNothing);
    });

    testWidgets('a failed load says so and Try again reads it again', (tester) async {
      repo.failReads = true;
      await open(tester, security, height: 900);
      expect(find.text("Couldn't load this requirement"), findsOneWidget);
      repo.failReads = false;
      await tester.tap(find.text('Try again'));
      await settle(tester, 12);
      expect(find.text('3 replies so far'), findsOneWidget);
    });

    testWidgets('pulling the page down reads it again', (tester) async {
      await open(tester, security, height: 900);
      final before = repo.calls.where((c) => c == 'bids').length;
      await tester.fling(find.byType(BidResponseCard).first, const Offset(0, 300), 1000);
      await settle(tester, 14);
      expect(repo.calls.where((c) => c == 'bids').length, greaterThan(before));
    });

    testWidgets('an enquiry with no replies says so', (tester) async {
      await open(tester, home);
      expect(find.text('No replies yet'), findsOneWidget);
      expect(find.text('Suppliers who reply to your enquiry appear here.'), findsOneWidget);
    });
  });
}
