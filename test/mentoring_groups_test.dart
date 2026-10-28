import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/mentorship_my/group_sessions_screen.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_clock.dart';
import 'package:icr_mobile/features/mentorship_my/programmes_screen.dart';

import 'helpers/fonts.dart';
import 'mentoring_fakes.dart';
import 'mentoring_purchases_world.dart';

final _now = DateTime(2026, 10, 26, 10);

/// The group sessions and programmes the API holds, changing as the screens write.
class GroupsWorld {
  GroupsWorld({this.live = true}) {
    sessions = [
      groupJson('g-clinic', canRegister: true),
      groupJson(
        'g-paid',
        title: 'Panel interview masterclass',
        price: 29900,
        seatForSale: true,
        canRegister: false,
        capacity: 15,
        taken: 0,
      ),
      groupJson('g-full', title: 'A full clinic', capacity: 10, taken: 10, canRegister: true),
      groupJson(
        'g-mine',
        title: 'Reading an SLA',
        myStatus: 'REGISTERED',
        canRegister: false,
        blockedReason: 'You are registered.',
        meetingLink: 'https://meet.google.com/icr-demo',
      ),
    ];
    programmes = [programmeJson('circle'), programmeJson('masterclass', status: 'RUNNING')];
    final paid = sessions.firstWhere((s) => s['id'] == 'g-paid');
    paid['_seatForSale'] = true;
    paid['_canRegister'] = false;
  }

  final bool live;
  List<Map<String, Object?>> sessions = [];
  List<Map<String, Object?>> programmes = [];
  List<Map<String, Object?>> enrolments = [];
  Map<String, Object?>? feedback;
  Map<String, Object?> discounts = {
    'services': {'bps': 0, 'planName': null},
    'plans': {'bps': 0, 'planName': null},
    'sessionCredits': null,
  };

  Map<String, Object?> detailOf(String id) {
    final row = sessions.firstWhere((s) => s['id'] == id);
    final mine = row['myStatus'] as String?;
    final held = mine == 'REGISTERED' || mine == 'ATTENDED';
    return groupJson(
      id,
      title: row['title'] as String,
      status: row['status'] as String,
      myStatus: mine,
      price: row['pricePaisa'] as int?,
      capacity: row['capacity'] as int,
      taken: row['seatsTaken'] as int,
      canRegister: row['_canRegister'] as bool? ?? (mine == null),
      seatForSale: row['_seatForSale'] as bool? ?? false,
      blockedReason: held ? 'You are registered.' : row['_blocked'] as String?,
      meetingLink: held ? 'https://meet.google.com/icr-demo' : null,
      detail: true,
      attendees: held
          ? [
              {
                'id': 'a0',
                'user': {
                  'id': 'u-meera',
                  'firstName': 'Meera',
                  'lastName': 'Nair',
                  'avatarUrl': null,
                  'companyName': null,
                },
                'status': 'REGISTERED',
                'registeredAt': iso(_now),
              },
            ]
          : const [],
      hasReview: row['_hasReview'] as bool? ?? false,
      purchaseId: row['_purchaseId'] as String?,
    );
  }

  Map<String, Reply> routes() => {
    ...menteeRoutes(),
    'GET /payments/mode': (_) => {'mode': live ? 'live' : 'simulated', 'configured': true},
    'GET /mentor-services/member-discounts': (_) => discounts,
    'GET /mentorship/mentors/facets': (_) => {
      'competencies': [
        {'label': 'Career transitions', 'count': 4},
      ],
    },
    'GET /mentorship/mentees/me': (_) => '',
    'GET /mentorship/programmes/mine': (_) => enrolments,
    'GET /mentorship/group-sessions': (o) {
      final q = o.queryParameters;
      var rows = sessions;
      if (q['registered'] == true) rows = rows.where((s) => s['myStatus'] != null).toList();
      if (q['availableOnly'] == true) rows = rows.where((s) => (s['seatsLeft'] as int) > 0).toList();
      if (q['mode'] != null) rows = rows.where((s) => s['mode'] == q['mode']).toList();
      final word = (q['search'] as String?)?.toLowerCase();
      if (word != null) {
        rows = rows.where((s) => (s['title'] as String).toLowerCase().contains(word)).toList();
      }
      if (q['programId'] != null) rows = rows.where((s) => s['programId'] == q['programId']).toList();
      final limit = q['limit'] as int? ?? 12;
      final pageNo = q['page'] as int? ?? 1;
      final slice = rows.skip((pageNo - 1) * limit).take(limit).toList();
      return {
        'data': slice,
        'meta': {
          'page': pageNo,
          'limit': limit,
          'total': rows.length,
          'totalPages': 1,
          'hasNext': pageNo * limit < rows.length,
          'hasPrev': pageNo > 1,
        },
      };
    },
    'GET /mentorship/programmes': (o) {
      final status = o.queryParameters['status'];
      return page(programmes.where((p) => status == null || p['status'] == status).toList());
    },
    'GET /mentorship/programmes/circle': (_) => programmeJson(
      'circle',
      detail: true,
      mine: [
        for (final e in enrolments)
          if (e['status'] != 'WITHDRAWN') e,
      ],
    ),
    'GET /mentorship/programmes/masterclass': (_) => programmeJson('masterclass', status: 'RUNNING', detail: true),
  };

  Map<String, Reply> idRoutes() {
    final out = <String, Reply>{};
    for (final id in ['g-clinic', 'g-paid', 'g-full', 'g-mine']) {
      out['GET /mentorship/group-sessions/$id'] = (_) => detailOf(id);
      out['GET /mentorship/group-sessions/$id/feedback/mine'] = (_) => feedback ?? '';
      out['POST /mentorship/group-sessions/$id/register'] = (o) {
        final row = sessions.firstWhere((s) => s['id'] == id);
        final full = (row['seatsLeft'] as int) <= 0;
        row['myStatus'] = full ? 'WAITLISTED' : 'REGISTERED';
        if (!full) {
          row['seatsTaken'] = (row['seatsTaken'] as int) + 1;
          row['seatsLeft'] = (row['seatsLeft'] as int) - 1;
        }
        return {'status': row['myStatus']};
      };
      out['DELETE /mentorship/group-sessions/$id/register'] = (_) {
        sessions.firstWhere((s) => s['id'] == id)['myStatus'] = null;
        return {'ok': true};
      };
      out['POST /mentorship/group-sessions/$id/seat/checkout'] = (_) {
        final row = sessions.firstWhere((s) => s['id'] == id);
        row['myStatus'] = 'REGISTERED';
        row['_purchaseId'] = 'pur-1';
        return {'devActivated': true, 'purchaseId': 'pur-1'};
      };
      out['POST /mentorship/group-sessions/$id/feedback'] = (o) {
        final b = o.data as Map<String, dynamic>;
        feedback = {'rating': b['rating'], 'comment': b['comment'], 'anonymous': b['anonymous'] == true};
        return {'ok': true};
      };
      out['POST /mentorship/group-sessions/$id/concerns'] = (_) => {'id': 'c-1'};
      out['POST /mentorship/group-sessions/$id/conversation'] = (_) => {'conversationId': 'room-1'};
    }
    out['POST /mentor-services/purchases/pur-1/review'] = (_) {
      sessions.firstWhere((s) => s['id'] == 'g-paid')['_hasReview'] = true;
      return {'ok': true};
    };
    out['POST /mentorship/programmes/circle/enrol'] = (o) {
      final b = o.data as Map<String, dynamic>;
      enrolments = [...enrolments, enrolmentJson('e-new', role: b['role'] as String, status: 'APPLIED')];
      return {'ok': true};
    };
    out['POST /mentorship/programmes/enrolments/e-new/withdraw'] = (_) {
      enrolments = [
        for (final e in enrolments)
          if (e['id'] == 'e-new') {...e, 'status': 'WITHDRAWN'} else e,
      ];
      return {'ok': true};
    };
    out['PUT /mentorship/mentees/me'] = (_) => {'ok': true};
    return out;
  }

  FakeApi api({Map<String, Reply> extra = const {}}) => FakeApi({...routes(), ...idRoutes(), ...extra});
}

Future<(FakeApi, LinkRecorder)> pumpGroups(
  WidgetTester tester,
  GroupsWorld w, {
  bool registeredOnly = false,
  Map<String, Reply> extra = const {},
}) async {
  phone(tester, height: 9000);
  final api = w.api(extra: extra);
  final rec = LinkRecorder();
  await pumpApp(tester, GroupSessionsScreen(repository: repoOf(api), links: rec.links, registeredOnly: registeredOnly));
  return (api, rec);
}

Future<(FakeApi, LinkRecorder)> pumpGroup(
  WidgetTester tester,
  GroupsWorld w,
  String id, {
  Map<String, Reply> extra = const {},
}) async {
  phone(tester, height: 9000);
  final api = w.api(extra: extra);
  final rec = LinkRecorder();
  await pumpApp(tester, GroupSessionScreen(id: id, repository: repoOf(api), links: rec.links));
  return (api, rec);
}

Future<void> tapText(WidgetTester tester, String text, {int index = 0}) async {
  final f = find.text(text).at(index);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await settle(tester);
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await settle(tester);
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => mentoringNow = () => _now);
  tearDown(() => mentoringNow = DateTime.now);

  group('the browser', () {
    testWidgets('lists open sessions with who hosts them, when, and the seats and price', (tester) async {
      final (api, _) = await pumpGroups(tester, GroupsWorld());
      expect(find.text('Group sessions'), findsOneWidget);
      expect(find.text('From site to portfolio: an open clinic'), findsOneWidget);
      expect(find.text('Panel interview masterclass'), findsOneWidget);
      expect(find.text('Free · 22 of 25 seats left'), findsNWidgets(2));
      expect(find.text('₹299 a seat · 15 of 15 seats left'), findsOneWidget);
      expect(find.text('Free · Full, with a waitlist (0 waiting)'), findsOneWidget);
      expect(find.text('Seat held'), findsOneWidget);
      expect(api.queryOf('GET /mentorship/group-sessions'), {'page': 1, 'limit': 12});
    });

    testWidgets('My seats shows only the sessions the member holds a seat at', (tester) async {
      final (api, _) = await pumpGroups(tester, GroupsWorld());
      await tester.tap(find.text('My seats'));
      await settle(tester);
      expect(api.queryOf('GET /mentorship/group-sessions')!['registered'], true);
      expect(find.text('Reading an SLA'), findsOneWidget);
      expect(find.text('Panel interview masterclass'), findsNothing);
    });

    testWidgets('an empty My seats says how to get one', (tester) async {
      final w = GroupsWorld();
      for (final s in w.sessions) {
        s['myStatus'] = null;
      }
      await pumpGroups(tester, w, registeredOnly: true);
      expect(find.text('No seats held'), findsOneWidget);
    });

    testWidgets('the filters ask the API: how they meet, seats free, and words', (tester) async {
      final (api, _) = await pumpGroups(tester, GroupsWorld());
      await tester.tap(find.byKey(const ValueKey('mode-PHONE')));
      await settle(tester);
      expect(api.queryOf('GET /mentorship/group-sessions')!['mode'], 'PHONE');
      expect(find.text('No sessions match'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mode-PHONE')));
      await settle(tester);
      expect(api.queryOf('GET /mentorship/group-sessions')!.containsKey('mode'), isFalse);
      await tester.tap(find.byKey(const ValueKey('seats-free')));
      await settle(tester);
      expect(api.queryOf('GET /mentorship/group-sessions')!['availableOnly'], true);
      expect(find.text('A full clinic'), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('groups-search')), 'panel');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      expect(api.queryOf('GET /mentorship/group-sessions')!['search'], 'panel');
      expect(find.text('Panel interview masterclass'), findsOneWidget);
      expect(find.text('From site to portfolio: an open clinic'), findsNothing);
      await tester.tap(find.byTooltip('Clear search'));
      await settle(tester);
      expect(find.text('From site to portfolio: an open clinic'), findsOneWidget);
    });

    testWidgets('Load more reads the next page and adds it', (tester) async {
      final w = GroupsWorld();
      w.sessions = [for (var i = 0; i < 14; i++) groupJson('g-$i', title: 'Clinic $i')];
      final (api, _) = await pumpGroups(tester, w);
      expect(find.text('Clinic 0'), findsOneWidget);
      expect(find.text('Clinic 13'), findsNothing);
      await tapKey(tester, 'groups-more');
      expect(api.queryOf('GET /mentorship/group-sessions')!['page'], 2);
      expect(find.text('Clinic 13'), findsOneWidget);
      expect(find.byKey(const ValueKey('groups-more')), findsNothing);
    });

    testWidgets('a card opens the session, and a load that fails offers Try again', (tester) async {
      var fail = true;
      final w = GroupsWorld();
      final (api, _) = await pumpGroups(
        tester,
        w,
        extra: {
          'GET /mentorship/group-sessions': (o) =>
              fail ? refuse('Sessions are unavailable.', status: 503) : page(w.sessions),
        },
      );
      expect(find.text("Couldn't load the sessions"), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(api.count('GET /mentorship/group-sessions'), 2);
      await tester.tap(find.text('From site to portfolio: an open clinic'));
      await settle(tester);
      expect(find.text('Your seat'), findsOneWidget);
    });
  });

  group('one session', () {
    testWidgets('shows who hosts it, the agenda, the days of a series and what it costs', (tester) async {
      final (_, _) = await pumpGroup(tester, GroupsWorld(), 'g-clinic');
      expect(find.text('From site to portfolio: an open clinic'), findsOneWidget);
      expect(find.text('Anand Iyer'), findsOneWidget);
      expect(find.textContaining('Host · Head of Facilities Strategy'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('agenda'))).data, contains('Bring a real case.'));
      expect(tester.widget<Text>(find.byKey(const ValueKey('agenda'))).data, contains('• Framing'));
      expect(find.text('Career transitions'), findsOneWidget);
      expect(find.text('Free · 22 of 25 seats left'), findsOneWidget);
    });

    testWidgets('a free seat is taken with a question for the host, and the call and the room open once it is', (
      tester,
    ) async {
      final (api, rec) = await pumpGroup(tester, GroupsWorld(), 'g-clinic');
      expect(find.byKey(const ValueKey('seat-free')), findsOneWidget);
      expect(find.text('Join the session'), findsNothing, reason: 'the call is for people with a seat');
      await tester.enterText(find.byKey(const ValueKey('seat-question')), 'How do I present a case to finance?');
      await tapText(tester, 'Reserve my seat');
      expect(api.bodyOf('POST /mentorship/group-sessions/g-clinic/register'), {
        'question': 'How do I present a case to finance?',
      });
      expect(find.text('Your seat is booked.'), findsOneWidget);
      expect(find.byKey(const ValueKey('seat-held')), findsOneWidget);
      expect(find.text('Who is going (1)'), findsOneWidget);
      final urls = launches(tester);
      await tapText(tester, 'Join the session');
      expect(urls, ['https://meet.google.com/icr-demo']);
      await tapText(tester, 'Room chat');
      expect(api.count('POST /mentorship/group-sessions/g-clinic/conversation'), 1);
      expect(rec.opened, ['conversation:room-1']);
    });

    testWidgets('a seat is given up, and the open card comes back', (tester) async {
      final (api, _) = await pumpGroup(tester, GroupsWorld(), 'g-mine');
      await tapText(tester, 'Give up my seat');
      expect(api.count('DELETE /mentorship/group-sessions/g-mine/register'), 1);
      expect(find.text('You gave up your seat.'), findsOneWidget);
      expect(find.byKey(const ValueKey('seat-held')), findsNothing);
    });

    testWidgets('a full session offers the waitlist, and leaving it is one tap', (tester) async {
      final (api, _) = await pumpGroup(tester, GroupsWorld(), 'g-full');
      expect(find.text('It is full, but you can join the waitlist.'), findsOneWidget);
      await tapText(tester, 'Join the waitlist');
      expect(api.count('POST /mentorship/group-sessions/g-full/register'), 1);
      expect(find.text('You are on the waitlist.'), findsOneWidget);
      expect(find.byKey(const ValueKey('seat-waitlisted')), findsOneWidget);
      await tapText(tester, 'Leave the waitlist');
      expect(api.count('DELETE /mentorship/group-sessions/g-full/register'), 1);
      expect(find.byKey(const ValueKey('seat-waitlisted')), findsNothing);
    });

    testWidgets('when the API says no, its reason is shown as written', (tester) async {
      final w = GroupsWorld();
      final row = w.sessions.firstWhere((s) => s['id'] == 'g-clinic');
      row['_canRegister'] = false;
      row['_blocked'] = 'Only members of the Early Career circle can join this clinic.';
      await pumpGroup(tester, w, 'g-clinic');
      expect(find.byKey(const ValueKey('seat-blocked')), findsOneWidget);
      expect(find.text('Only members of the Early Career circle can join this clinic.'), findsOneWidget);
    });

    testWidgets('a refused registration says why and the card stays', (tester) async {
      await pumpGroup(
        tester,
        GroupsWorld(),
        'g-clinic',
        extra: {
          'POST /mentorship/group-sessions/g-clinic/register': (_) =>
              refuse('Registration closed an hour before the session.'),
        },
      );
      await tapText(tester, 'Reserve my seat');
      expect(find.text('Registration closed an hour before the session.'), findsOneWidget);
      expect(find.byKey(const ValueKey('seat-free')), findsOneWidget);
    });

    testWidgets('a paid seat shows the quote with the member discount, then the payment page on the website', (
      tester,
    ) async {
      final w = GroupsWorld();
      w.discounts = {
        'services': {'bps': 1000, 'planName': 'Gold'},
        'plans': {'bps': 0, 'planName': null},
        'sessionCredits': null,
      };
      final (api, rec) = await pumpGroup(tester, w, 'g-paid');
      expect(find.byKey(const ValueKey('seat-for-sale')), findsOneWidget);
      expect(find.text('₹269.10'), findsOneWidget);
      expect(find.text('₹299'), findsOneWidget, reason: 'the list price, struck through');
      expect(find.text('10% member discount from Gold.'), findsOneWidget);
      await tapText(tester, 'Reserve a seat · ₹269.10');
      expect(find.text('Reserve your seat'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('seat-sheet-question')), 'Will there be a mock panel?');
      expect(find.byKey(const ValueKey('pay-handoff')), findsOneWidget);
      await tester.tap(find.text('Pay ₹269.10 on the website'));
      await settle(tester);
      expect(
        api.count('POST /mentorship/group-sessions/g-paid/seat/checkout'),
        0,
        reason: 'the website begins the gateway payment',
      );
      expect(rec.sites, ['/mentorship/groups/g-paid']);
    });

    testWidgets('with a simulated gateway the seat is bought in the app', (tester) async {
      final (api, rec) = await pumpGroup(tester, GroupsWorld(live: false), 'g-paid');
      await tapText(tester, 'Reserve a seat · ₹299');
      await tester.enterText(find.byKey(const ValueKey('seat-sheet-question')), 'Will there be a mock panel?');
      await tester.tap(find.text('Pay ₹299'));
      await settle(tester);
      expect(api.bodyOf('POST /mentorship/group-sessions/g-paid/seat/checkout'), {
        'question': 'Will there be a mock panel?',
      });
      expect(find.text('Your seat is booked.'), findsOneWidget);
      expect(find.byKey(const ValueKey('seat-held')), findsOneWidget);
      expect(find.text('A paid seat is cancelled from your purchases.'), findsOneWidget);
      expect(find.text('Give up my seat'), findsNothing, reason: 'money moved: a cancel goes through the purchase');
      expect(rec.sites, isEmpty);
    });

    testWidgets('a refused seat purchase says why in the sheet', (tester) async {
      await pumpGroup(
        tester,
        GroupsWorld(live: false),
        'g-paid',
        extra: {'POST /mentorship/group-sessions/g-paid/seat/checkout': (_) => refuse('This session is sold out.')},
      );
      await tapText(tester, 'Reserve a seat · ₹299');
      await tester.tap(find.text('Pay ₹299'));
      await settle(tester);
      expect(find.text('This session is sold out.'), findsOneWidget);
      expect(find.text('Reserve your seat'), findsOneWidget);
    });

    testWidgets(
      'a held session is rated once by someone who attended: a rating, ten characters if written, a hidden name',
      (tester) async {
        final w = GroupsWorld();
        final row = w.sessions.firstWhere((s) => s['id'] == 'g-mine');
        row['status'] = 'COMPLETED';
        row['myStatus'] = 'ATTENDED';
        final (api, _) = await pumpGroup(tester, w, 'g-mine');
        expect(find.text('You attended this session.'), findsOneWidget);
        await tapText(tester, 'Rate this session');
        await tester.tap(find.text('Send review'));
        await tester.pump();
        expect(find.text('Choose a rating from one to five stars.'), findsOneWidget);
        await tester.tap(find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.star_outline_rounded).at(3));
        await tester.pump();
        await tester.enterText(find.byKey(const ValueKey('review-comment')), 'Practical and well paced');
        await tester.tap(find.byType(Switch));
        await tester.pump();
        await tester.tap(find.text('Send review'));
        await settle(tester);
        expect(api.bodyOf('POST /mentorship/group-sessions/g-mine/feedback'), {
          'rating': 4,
          'comment': 'Practical and well paced',
          'anonymous': true,
        });
        expect(find.byKey(const ValueKey('my-group-rating')), findsOneWidget);
        expect(find.text('Rate this session'), findsNothing);
      },
    );

    testWidgets('a paid seat is reviewed through its purchase', (tester) async {
      final w = GroupsWorld();
      final row = w.sessions.firstWhere((s) => s['id'] == 'g-paid');
      row['status'] = 'COMPLETED';
      row['myStatus'] = 'ATTENDED';
      row['_purchaseId'] = 'pur-1';
      final (api, _) = await pumpGroup(tester, w, 'g-paid');
      await tapText(tester, 'Rate this session');
      await tester.tap(find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.star_outline_rounded).last);
      await tester.pump();
      await tester.tap(find.text('Send review'));
      await settle(tester);
      expect(api.count('POST /mentor-services/purchases/pur-1/review'), 1);
      expect(find.text('You reviewed this seat. Thank you.'), findsOneWidget);
    });

    testWidgets('a concern about a session is private to ICR and needs ten characters', (tester) async {
      final (api, _) = await pumpGroup(tester, GroupsWorld(), 'g-mine');
      await tapText(tester, 'Report a concern');
      await tester.enterText(find.byKey(const ValueKey('group-concern-detail')), 'short');
      await tester.tap(find.text('Send to ICR'));
      await tester.pump();
      expect(find.text('Tell ICR what happened: at least 10 characters.'), findsOneWidget);
      await tester.tap(find.text('Safety'));
      await tester.enterText(
        find.byKey(const ValueKey('group-concern-detail')),
        'The host shared my details with the room',
      );
      await tester.tap(find.text('Send to ICR'));
      await settle(tester);
      expect(api.bodyOf('POST /mentorship/group-sessions/g-mine/concerns'), {
        'category': 'SAFETY',
        'detail': 'The host shared my details with the room',
        'urgent': true,
      });
      expect(find.textContaining('Sent to ICR.'), findsOneWidget);
    });

    testWidgets('a session that cannot be read says why and Try again reads it again', (tester) async {
      var fail = true;
      final w = GroupsWorld();
      final (api, _) = await pumpGroup(
        tester,
        w,
        'g-clinic',
        extra: {
          'GET /mentorship/group-sessions/g-clinic': (_) =>
              fail ? refuse('Session not found', status: 404) : w.detailOf('g-clinic'),
        },
      );
      expect(find.text("Couldn't load this session"), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('Your seat'), findsOneWidget);
      expect(api.count('GET /mentorship/group-sessions/g-clinic'), 2);
    });
  });

  group('programmes', () {
    Future<(FakeApi, LinkRecorder)> pumpProgrammes(
      WidgetTester tester,
      GroupsWorld w, {
      void Function(BuildContext)? onBecome,
    }) async {
      phone(tester, height: 9000);
      final api = w.api();
      final rec = LinkRecorder();
      await pumpApp(tester, ProgrammesScreen(repository: repoOf(api), links: rec.links, onBecomeMentor: onBecome));
      return (api, rec);
    }

    Future<(FakeApi, LinkRecorder)> pumpProgramme(
      WidgetTester tester,
      GroupsWorld w, {
      void Function(BuildContext)? onBecome,
      Map<String, Reply> extra = const {},
    }) async {
      phone(tester, height: 9000);
      final api = w.api(extra: extra);
      final rec = LinkRecorder();
      await pumpApp(
        tester,
        ProgrammeScreen(slug: 'circle', repository: repoOf(api), links: rec.links, onBecomeMentor: onBecome),
      );
      return (api, rec);
    }

    testWidgets('the browser opens on programmes open for applications, and the tabs ask for the others', (
      tester,
    ) async {
      final (api, _) = await pumpProgrammes(tester, GroupsWorld());
      expect(api.queryOf('GET /mentorship/programmes')!['status'], 'OPEN');
      expect(find.byKey(const ValueKey('programme-circle')), findsOneWidget);
      expect(find.byKey(const ValueKey('programme-masterclass')), findsNothing);
      await tester.tap(find.text('Under way'));
      await settle(tester);
      expect(api.queryOf('GET /mentorship/programmes')!['status'], 'RUNNING');
      expect(find.byKey(const ValueKey('programme-masterclass')), findsOneWidget);
      await tester.tap(find.text('All'));
      await settle(tester);
      expect(api.queryOf('GET /mentorship/programmes')!.containsKey('status'), isFalse);
      expect(find.byKey(const ValueKey('programme-circle')), findsOneWidget);
    });

    testWidgets('a programme the member applied to shows their status on its card', (tester) async {
      final w = GroupsWorld()..enrolments = [enrolmentJson('e-new')];
      await pumpProgrammes(tester, w);
      expect(find.text('Applied'), findsOneWidget);
    });

    testWidgets('a programme shows its dates, who it has room for, the detail and its sessions', (tester) async {
      final w = GroupsWorld();
      w.sessions.add(groupJson('g-prog', title: 'Cohort kick-off', programId: 'prog-circle'));
      await pumpProgramme(tester, w);
      expect(find.text('Early-career mentoring circle'), findsOneWidget);
      expect(find.textContaining('Applications close'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('capacity-line')),
          matching: find.text('Mentees 1 of 12 · Mentors 1 of 4'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('programme-detail')), findsOneWidget);
      expect(find.text('Cohort kick-off'), findsOneWidget);
    });

    testWidgets('applying sends the side and why, and the application shows, with Withdraw', (tester) async {
      final (api, _) = await pumpProgramme(tester, GroupsWorld());
      await tapText(tester, 'Apply to join');
      await tester.tap(find.byKey(const ValueKey('role-MENTOR')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('role-MENTEE')));
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('apply-motivation')), 'I want a steadier rhythm of mentoring.');
      await tester.tap(find.text('Send application'));
      await settle(tester);
      expect(api.bodyOf('POST /mentorship/programmes/circle/enrol'), {
        'role': 'MENTEE',
        'motivation': 'I want a steadier rhythm of mentoring.',
      });
      expect(find.text('Application sent. The organisers will be in touch.'), findsOneWidget);
      expect(find.byKey(const ValueKey('enrolment-MENTEE')), findsOneWidget);
      await tapText(tester, 'Withdraw');
      expect(api.count('POST /mentorship/programmes/enrolments/e-new/withdraw'), 1);
      expect(find.byKey(const ValueKey('enrolment-MENTEE')), findsNothing);
    });

    testWidgets('a mentor needs an approved profile: the API\'s sentence and the way to fix it', (tester) async {
      var become = 0;
      final (api, _) = await pumpProgramme(
        tester,
        GroupsWorld(),
        onBecome: (_) => become++,
        extra: {
          'POST /mentorship/programmes/circle/enrol': (_) => refuse(
            'Mentors join a programme from an approved mentor profile: submit yours for review first.',
            code: 'PROGRAMME_NEEDS_MENTOR_PROFILE',
          ),
        },
      );
      await tapText(tester, 'Apply to join');
      await tester.tap(find.byKey(const ValueKey('role-MENTOR')));
      await tester.pump();
      await tester.tap(find.text('Send application'));
      await settle(tester);
      expect(api.count('POST /mentorship/programmes/circle/enrol'), 1);
      expect(find.byKey(const ValueKey('apply-fix')), findsOneWidget);
      expect(find.textContaining('Mentors join a programme from an approved mentor profile'), findsOneWidget);
      await tester.tap(find.text('Set up my mentor profile'));
      await tester.pump();
      expect(become, 1);
    });

    testWidgets('a mentee needs to say what they are after: it is asked here, saved, and the application can go', (
      tester,
    ) async {
      var refuseFirst = true;
      final (api, _) = await pumpProgramme(
        tester,
        GroupsWorld(),
        extra: {
          'POST /mentorship/programmes/circle/enrol': (o) {
            if (refuseFirst) {
              refuseFirst = false;
              return refuse('Tell us what you want from mentoring first.', code: 'PROGRAMME_NEEDS_MENTEE_PROFILE');
            }
            return {'ok': true};
          },
        },
      );
      await tapText(tester, 'Apply to join');
      await tester.tap(find.text('Send application'));
      await settle(tester);
      expect(find.text('Tell us what you are after'), findsOneWidget);
      await tester.tap(find.text('Tell us what you are after'));
      await settle(tester);
      await tester.tap(find.text('Mid career'));
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(api.count('PUT /mentorship/mentees/me'), 1);
      expect((api.bodyOf('PUT /mentorship/mentees/me') as Map)['careerStage'], 'MID_CAREER');
      await tester.tap(find.text('Send application'));
      await settle(tester);
      expect(api.count('POST /mentorship/programmes/circle/enrol'), 2);
      expect(find.text('Application sent. The organisers will be in touch.'), findsOneWidget);
    });

    testWidgets('a full side says so and cannot be applied to', (tester) async {
      final w = GroupsWorld();
      await pumpProgramme(
        tester,
        w,
        extra: {'GET /mentorship/programmes/circle': (_) => programmeJson('circle', detail: true, mentors: 4)},
      );
      await tapText(tester, 'Apply to join');
      await tester.tap(find.byKey(const ValueKey('role-MENTOR')));
      await tester.pump();
      expect(find.text('The mentor side is full.'), findsOneWidget);
    });

    testWidgets('a programme that is not open takes no applications', (tester) async {
      final w = GroupsWorld();
      await pumpProgramme(
        tester,
        w,
        extra: {'GET /mentorship/programmes/circle': (_) => programmeJson('circle', status: 'RUNNING', detail: true)},
      );
      expect(find.text('This programme is not taking applications.'), findsOneWidget);
      expect(find.text('Apply to join'), findsNothing);
    });
  });
}
