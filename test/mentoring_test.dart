import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/widgets/title_bar.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_clock.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_models.dart';
import 'package:icr_mobile/features/mentorship_my/widgets/kit.dart';

import 'helpers/fonts.dart';
import 'mentoring_fakes.dart';

void main() {
  setUpAll(loadAppFonts);

  group('what the API sends', () {
    test('a pairing is read from the side the caller is on', () async {
      final api = FakeApi({
        'GET /mentorship/mine': (_) => page([
          pairingJson('pair-anand'),
          pairingJson(
            'pair-meera',
            side: 'MENTOR',
            mentor: anand,
            mentee: personJson('u-meera', 'Meera', 'Nair', careerStage: 'MID_CAREER'),
          ),
          pairingJson('pair-divya', status: 'COMPLETED', mentor: divya, completedAt: iso(mentoringNow())),
        ]),
      });
      final rows = await repoOf(api).pairings();
      expect(rows.map((p) => p.id), ['pair-anand', 'pair-meera', 'pair-divya']);
      expect(rows[0].viewerIsMentor, isFalse);
      expect(rows[0].counterpart.name, 'Anand Iyer');
      expect(rows[0].counterpart.subline, 'Head of Facilities Strategy at Prestige Group');
      expect(rows[0].mentorProfileId, 'mp-anand');
      expect(rows[1].viewerIsMentor, isTrue);
      expect(rows[1].counterpart.name, 'Meera Nair');
      expect(rows[1].careerStage, 'MID_CAREER');
      expect(rows[2].status, PairingStatus.completed);
      expect(rows[2].status.live, isFalse);
      expect(api.queryOf('GET /mentorship/mine'), {'limit': 50});
    });

    test('a request carries why it reached the mentor, and when it lapses', () async {
      final api = FakeApi({
        'GET /mentorship/requests/incoming': (_) => page([
          requestJson(
            'r1',
            mentee: personJson('u-isha', 'Isha', 'Verma', careerStage: 'MID_CAREER'),
            signals: ['Same city', 'Wants your domain'],
          ),
        ]),
      });
      final r = (await repoOf(api).requestsReceived()).single;
      expect(r.status, RequestStatus.pending);
      expect(r.signals, ['Same city', 'Wants your domain']);
      expect(r.careerStage, 'MID_CAREER');
      expect(r.expiresAt, isNotNull);
      expect(r.matchScore, 61);
    });

    test('the member discounts and the credit the plan carries', () async {
      final api = FakeApi({
        'GET /mentor-services/member-discounts': (_) => {
          'services': {'bps': 500, 'planName': 'Gold'},
          'plans': {'bps': 0, 'planName': null},
          'sessionCredits': {
            'perPeriod': 1,
            'remaining': 1,
            'capPaisa': 150000,
            'planName': 'Pro Plus',
            'resetsAt': '2026-11-07T06:36:50.348Z',
          },
        },
      });
      final d = await repoOf(api).memberDiscounts();
      expect(d.servicesBps, 500);
      expect(d.servicesPlan, 'Gold');
      expect(d.plansBps, 0);
      expect(d.credits!.remaining, 1);
      expect(d.credits!.capPaisa, 150000);
      expect(d.credits!.planName, 'Pro Plus');
    });

    test('a member with no plan benefits has no credit and no discount', () async {
      final api = FakeApi({
        'GET /mentor-services/member-discounts': (_) => {
          'services': {'bps': 0, 'planName': null},
          'plans': {'bps': 0, 'planName': null},
          'sessionCredits': null,
        },
      });
      final d = await repoOf(api).memberDiscounts();
      expect(d.credits, isNull);
      final q = PriceQuote.session(149900, d);
      expect(q.chargedPaisa, 149900);
      expect(q.discounted, isFalse);
    });

    test('the calendar merges pairing sessions, paid calls and group seats, in time order', () async {
      final day = mentoringNow().add(const Duration(days: 2));
      final api = FakeApi({
        'GET /mentorship/sessions': (_) => [sessionJson('s1', at: day.add(const Duration(hours: 5)))],
        'GET /mentor-services/bookings/range': (_) => [
          {
            'id': 'b1',
            'purchaseId': 'p1',
            'title': 'Career clarity call',
            'scheduledAt': iso(day),
            'durationMin': 30,
            'mode': 'VIDEO',
            'status': 'SCHEDULED',
            'meetingLink': 'https://meet.google.com/x',
            'counterpart': {'id': 'u-anand', 'firstName': 'Anand', 'lastName': 'Iyer'},
          },
        ],
        'GET /mentorship/group-sessions/mine/upcoming': (_) => [
          {
            'id': 'g1',
            'title': 'An open clinic',
            'scheduledAt': iso(day.add(const Duration(hours: 9))),
            'durationMin': 60,
            'mode': 'VIDEO',
            'status': 'SCHEDULED',
            'host': {'id': 'u-anand', 'firstName': 'Anand', 'lastName': 'Iyer'},
          },
        ],
      });
      final from = DateTime(day.year, day.month);
      final items = await repoOf(api).calendar(from, DateTime(day.year, day.month + 1));
      expect(items.map((i) => i.kind), [CalendarKind.booking, CalendarKind.session, CalendarKind.group]);
      expect(items[0].purchaseId, 'p1');
      expect(items[1].mentorshipId, 'pair-anand');
      expect(items[2].counterpartName, 'Anand Iyer');
      final q = api.queryOf('GET /mentorship/sessions')!;
      expect(q['from'], iso(from));
    });
  });

  group('the price a payment will charge', () {
    final credit = MemberDiscounts(
      servicesBps: 1000,
      servicesPlan: 'Gold',
      credits: SessionCredits(perPeriod: 1, remaining: 1, capPaisa: 150000, planName: 'Pro Plus'),
    );

    test('a credit that covers the session leaves nothing to pay, and replaces the member discount', () {
      final q = PriceQuote.session(79900, credit);
      expect(q.creditPaisa, 79900);
      expect(q.chargedPaisa, 0);
      expect(q.bps, 0);
      expect(q.canCredit, isTrue);
    });

    test('a credit pays up to its cap and the rest is charged', () {
      final q = PriceQuote.session(299900, credit);
      expect(q.creditPaisa, 150000);
      expect(q.chargedPaisa, 149900);
    });

    test('without the credit the member discount applies', () {
      final q = PriceQuote.session(79900, credit, useCredit: false);
      expect(q.creditPaisa, 0);
      expect(q.bps, 1000);
      expect(q.chargedPaisa, 71910);
      expect(q.planName, 'Gold');
    });

    test('a free session is free, with no credit or discount', () {
      final q = PriceQuote.session(0, credit);
      expect(q.free, isTrue);
      expect(q.chargedPaisa, 0);
      expect(q.canCredit, isFalse);
    });

    test('a resource or a seat takes the member discount, never a credit', () {
      final q = PriceQuote.service(49900, credit);
      expect(q.creditPaisa, 0);
      expect(q.chargedPaisa, 44910);
    });

    test('a plan takes the plans discount', () {
      final q = PriceQuote.plan(299900, const MemberDiscounts(plansBps: 2000, plansPlan: 'Silver'));
      expect(q.chargedPaisa, 239920);
      expect(q.planName, 'Silver');
    });
  });

  group('My mentoring', () {
    testWidgets('opens on the member\'s mentors, with what is next and what needs them', (tester) async {
      await pumpMyMentoring(tester, menteeRoutes());
      expect(find.text('My Mentoring'), findsOneWidget);
      final tabs = tester.widget<SegmentTabs>(find.byType(SegmentTabs)).labels;
      expect(tabs, ['Mentoring', 'Requests', 'Calendar', 'Purchases', 'Goals', 'Saved', 'Certificates']);
      expect(tabs, isNot(contains('Reports')), reason: 'only once a concern was raised');
      expect(find.text('Live pairings'), findsOneWidget);
      expect(find.text('Up next'), findsOneWidget);
      expect(find.text('Your mentors'), findsOneWidget);
      expect(find.text('Anand Iyer'), findsWidgets);
      expect(find.textContaining('1 request waiting for a mentor to reply'), findsOneWidget);
      expect(find.text('Find a mentor'), findsOneWidget);
    });

    testWidgets('a member with no mentor yet is told to ask one', (tester) async {
      final (_, rec) = await pumpMyMentoring(
        tester,
        menteeRoutes(pairings: [], sent: [], upcoming: [], summary: summaryJson(asMentee: 0, outgoing: 0)),
      );
      expect(find.text('No mentor yet'), findsOneWidget);
      expect(find.text('Nothing is waiting on you.'), findsOneWidget);
      await tester.tap(find.text('Find your first mentor'));
      await tester.tap(find.text('Find a mentor'));
      expect(rec.opened, ['directory']);
    });

    testWidgets('a load that fails says why, and Try again asks again', (tester) async {
      var fail = true;
      final routes = menteeRoutes();
      routes['GET /mentorship/mine'] = (_) =>
          fail ? refuse("We couldn't reach the mentoring service.", status: 500) : page([pairingJson('pair-anand')]);
      final (api, _) = await pumpMyMentoring(tester, routes);
      expect(find.text("Couldn't load your mentoring"), findsOneWidget);
      expect(find.text("We couldn't reach the mentoring service."), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text("Couldn't load your mentoring"), findsNothing);
      expect(find.text('Anand Iyer'), findsWidgets);
      expect(api.count('GET /mentorship/mine'), 2);
    });

    testWidgets('the bell opens the notifications', (tester) async {
      final (_, rec) = await pumpMyMentoring(tester, menteeRoutes());
      await tester.tap(find.byType(BellButton));
      await tester.pump();
      expect(rec.opened, ['bell']);
    });
  });
}
