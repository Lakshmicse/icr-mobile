/// A stateful fake of what the mentor's desk reads and writes, in the shapes the real API answers with (each
/// shape was checked against a live call as Anand). A write changes what the next read says, so a test proves
/// the effect, and `requests` records what was sent.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/mentor_desk/mentor_desk_repository.dart';
import 'package:icr_mobile/features/mentor_desk/mentor_desk_screen.dart';
import 'package:icr_mobile/features/mentor_desk/mentor_desk_controller.dart';

import 'mentoring_fakes.dart';

final _isha = personJson('u-isha', 'Isha', 'Verma', careerStage: 'MID_CAREER');
final _vikram = personJson('u-vikram', 'Vikram', 'Singh');
final _sana = personJson('u-sana', 'Sana', 'Qureshi');
final _meera = personJson('u-meera', 'Meera', 'Nair', careerStage: 'MID_CAREER');

Map<String, Object?> _buyer(Map<String, Object?> p) => {
  'id': p['id'],
  'firstName': p['firstName'],
  'lastName': p['lastName'],
  'avatarUrl': null,
  'designation': null,
  'companyName': null,
};

/// A purchase as the seller reads it (`side: SELLER`, the buyer, the mentor's own profile id).
Map<String, Object?> soldJson(
  String id, {
  String type = 'ONE_ON_ONE',
  String status = 'REQUESTED',
  Map<String, Object?>? buyer,
  int price = 149900,
  String title = 'Facilities leadership strategy session',
  Map<String, Object?>? request,
  Map<String, Object?>? booking,
  DateTime? createdAt,
  Map<String, Object?> extra = const {},
}) => {
  'id': id,
  'type': type,
  'titleSnapshot': title,
  'pricePaisa': price,
  'currency': 'INR',
  'status': status,
  'serviceId': 'svc-strategy',
  'side': 'SELLER',
  'buyer': _buyer(buyer ?? _isha),
  'mentor': {
    ...anand,
    'designation': 'Head of Facilities Strategy',
    'companyName': null,
    'mentorProfileId': 'mp-anand',
  },
  'paidAt': null,
  'fulfilledAt': null,
  'refundedAt': null,
  'cancelReason': null,
  'question': null,
  'slaDeadlineAt': null,
  'answeredAt': null,
  'conversationId': null,
  'booking': booking,
  'request': request,
  'groupSessionId': null,
  'groupSessionTitle': null,
  'groupSessionAt': null,
  'downloadUrl': null,
  'fileName': null,
  'issueReportedAt': null,
  'issueNote': null,
  'issueRespondedAt': null,
  'issueResponseNote': null,
  'issueResolvedAt': null,
  'issueResolvedBy': null,
  'lateAnswerDecisionDueAt': null,
  'lateAnswerDecision': null,
  'hasReview': false,
  'netPaisa': (price * 0.8).round(),
  'createdAt': iso(createdAt ?? DateTime(2026, 10, 24, 10)),
  ...extra,
};

Map<String, Object?> requestBlock({
  String topic = 'Preparing for a facilities head interview',
  int minutes = 45,
  int list = 149900,
  String? preferred,
  DateTime? scheduledAt,
  DateTime? payBy,
  DateTime? timeDeclinedAt,
  String? timeDeclineNote,
}) => {
  'topic': topic,
  'preferredTimes': preferred,
  'preferredTimeKeys': <String>[],
  'mode': 'VIDEO',
  'durationMin': minutes,
  'scheduledAt': scheduledAt == null ? null : iso(scheduledAt),
  'decidedAt': scheduledAt == null ? null : iso(DateTime(2026, 10, 25, 10)),
  'declineReason': null,
  'payBy': payBy == null ? null : iso(payBy),
  'timeDeclinedAt': timeDeclinedAt == null ? null : iso(timeDeclinedAt),
  'timeDeclineNote': timeDeclineNote,
  'timeDeclineCount': timeDeclineNote == null ? 0 : 1,
  'listPricePaisa': list,
};

Map<String, Object?> bookingBlock(
  DateTime at, {
  int minutes = 45,
  String? link = 'https://meet.google.com/icr-demo',
  DateTime? proposedAt,
  String? proposedBy,
  String? proposedNote,
}) => {
  'id': 'bk-${at.millisecondsSinceEpoch}',
  'scheduledAt': iso(at),
  'durationMin': minutes,
  'mode': 'VIDEO',
  'meetingLink': link,
  'status': 'SCHEDULED',
  'proposedScheduledAt': proposedAt == null ? null : iso(proposedAt),
  'proposedBy': proposedBy,
  'proposedAt': proposedAt == null ? null : iso(DateTime(2026, 10, 25, 12)),
  'proposedNote': proposedNote,
  'rescheduleCount': 0,
  'rescheduledAt': null,
};

Map<String, Object?> termJson(
  String id, {
  String status = 'PENDING_MENTOR',
  String kind = 'CURRICULUM',
  Map<String, Object?>? buyer,
  int total = 599900,
  String title = 'Site to portfolio: a 3-session programme',
  String? mentorshipId,
  int allowance = 3,
  int used = 0,
}) => {
  'id': id,
  'planId': 'plan-1',
  'titleSnapshot': title,
  'status': status,
  'pricePaisa': total,
  'discountPaisa': 0,
  'taxPaisa': 0,
  'totalPaisa': total,
  'currency': 'INR',
  'billingPeriodMonths': 3,
  'currentPeriodStart': status == 'ACTIVE' ? iso(DateTime(2026, 10, 16)) : null,
  'currentPeriodEnd': status == 'ACTIVE' ? iso(DateTime(2026, 11, 15)) : null,
  'sessionsAllowance': allowance,
  'sessionsUsed': used,
  'cancelAtPeriodEnd': false,
  'cancelledAt': null,
  'cancelReason': null,
  'refundedAt': null,
  'mentorshipId': mentorshipId,
  'createdAt': iso(DateTime(2026, 10, 24, 10)),
  'kind': kind,
  'steps': <Object?>[],
  'decidedAt': null,
  'declineReason': null,
  'counterpart': {..._buyer(buyer ?? _vikram), 'designation': null, 'companyName': null},
};

class DeskWorld {
  DeskWorld({this.status = 'APPROVED', this.hasProfile = true, DateTime? now})
    : now = now ?? DateTime(2026, 10, 26, 10) {
    final n = this.now;
    freeRequests = [
      requestJson('r-isha', mentor: anand, mentee: _isha, signals: ['Same city']),
      requestJson(
        'r-vikram',
        mentor: anand,
        mentee: _vikram,
        message: 'I am preparing for a head of facilities panel next month.',
      ),
    ];
    freeRequests[0]['createdAt'] = iso(n.subtract(const Duration(days: 1)));
    sold = [
      soldJson(
        'p-req',
        request: requestBlock(preferred: 'Weekday evenings'),
        createdAt: DateTime(2026, 10, 24, 10),
      ),
      soldJson(
        'p-free',
        price: 0,
        title: 'Career clarity call',
        buyer: _vikram,
        request: requestBlock(topic: 'Mapping my next two years', minutes: 30, list: 0),
      ),
      soldJson(
        'p-asked-again',
        buyer: _sana,
        request: requestBlock(
          topic: 'A smart-building retrofit case',
          timeDeclinedAt: DateTime(2026, 10, 25, 9),
          timeDeclineNote: 'Evenings after 7 suit me better.',
        ),
      ),
      soldJson(
        'p-held',
        status: 'ACCEPTED',
        buyer: _sana,
        request: requestBlock(scheduledAt: n.add(const Duration(days: 4)), payBy: n.add(const Duration(days: 3))),
      ),
      soldJson(
        'p-ended',
        status: 'PAID',
        buyer: _meera,
        request: requestBlock(scheduledAt: n.subtract(const Duration(days: 1))),
        booking: bookingBlock(n.subtract(const Duration(days: 1))),
      ),
      soldJson(
        'p-ahead',
        status: 'PAID',
        buyer: _isha,
        request: requestBlock(scheduledAt: n.add(const Duration(days: 5))),
        booking: bookingBlock(n.add(const Duration(days: 5)), link: null),
      ),
      soldJson(
        'p-move',
        status: 'PAID',
        buyer: _vikram,
        request: requestBlock(scheduledAt: n.add(const Duration(days: 6))),
        booking: bookingBlock(
          n.add(const Duration(days: 6)),
          proposedAt: n.add(const Duration(days: 8)),
          proposedBy: 'BUYER',
          proposedNote: 'A site visit that day',
        ),
      ),
      soldJson(
        'p-mine',
        status: 'PAID',
        buyer: _sana,
        request: requestBlock(scheduledAt: n.add(const Duration(days: 7))),
        booking: bookingBlock(
          n.add(const Duration(days: 7)),
          proposedAt: n.add(const Duration(days: 9)),
          proposedBy: 'MENTOR',
        ),
      ),
      soldJson(
        'p-issue',
        status: 'FULFILLED',
        type: 'RESOURCE',
        title: 'FM interview question bank',
        price: 49900,
        buyer: _isha,
        extra: {
          'issueReportedAt': iso(n.subtract(const Duration(days: 2))),
          'issueNote': 'The file would not open on my phone.',
        },
      ),
    ];
    terms = [
      termJson('t-prog', buyer: _vikram),
      termJson('t-unpaid', status: 'PENDING_PAYMENT', buyer: _sana),
      termJson(
        't-run',
        status: 'ACTIVE',
        kind: 'RECURRING',
        title: 'Monthly leadership coaching',
        buyer: _meera,
        total: 299900,
        mentorshipId: 'pair-meera',
        allowance: 2,
        used: 1,
      ),
    ];
    roster = [pairingJson('pair-meera', side: 'MENTOR', mentor: anand, mentee: _meera, conversationId: 'conv-meera')];
    finished = [
      pairingJson(
        'pair-tanvi',
        status: 'COMPLETED',
        side: 'MENTOR',
        mentor: anand,
        mentee: personJson('u-tanvi', 'Tanvi', 'Joshi'),
        completedAt: iso(n),
      ),
    ];
    upcoming = [
      sessionJson(
        's-next',
        mentorshipId: 'pair-meera',
        at: n.add(const Duration(days: 3)),
        agenda: 'Reviewing the scorecard draft',
        side: 'MENTOR',
      ),
      sessionJson(
        's-ask',
        mentorshipId: 'pair-meera',
        at: n.add(const Duration(days: 9)),
        status: 'REQUESTED',
        agenda: 'Mock panel',
        side: 'MENTOR',
      ),
    ];
    for (final x in upcoming) {
      x['counterpart'] = {
        'id': 'u-meera',
        'firstName': 'Meera',
        'lastName': 'Nair',
        'avatarUrl': null,
        'designation': null,
        'companyName': null,
      };
    }
    earnings = {
      'unsettledPaisa': 879600,
      'settledPaisa': 199760,
      'entries': [
        {
          'id': 'led-1',
          'kind': 'EARNING',
          'amountPaisa': 119920,
          'purchaseId': 'p-ended',
          'subscriptionId': null,
          'settledAt': null,
          'settlementRef': null,
          'createdAt': iso(DateTime(2026, 10, 23)),
        },
        {
          'id': 'led-2',
          'kind': 'EARNING',
          'amountPaisa': 239920,
          'purchaseId': null,
          'subscriptionId': 't-run',
          'settledAt': iso(DateTime(2026, 10, 21)),
          'settlementRef': 'NEFT-DEMO-0042',
          'createdAt': iso(DateTime(2026, 10, 16)),
        },
      ],
    };
    feedback = [
      {
        'id': 'fb-1',
        'rating': 5,
        'comment': 'Anand asked the questions I had been avoiding.',
        'createdAt': iso(DateTime(2026, 10, 8)),
      },
      {'id': 'fb-2', 'rating': 4, 'comment': null, 'createdAt': iso(DateTime(2026, 10, 7))},
    ];
    services = [
      {'id': 'svc-strategy', 'title': 'Facilities leadership strategy session'},
      {'id': 'svc-kit', 'title': 'FM interview question bank'},
    ];
    serviceReviews = {
      'svc-strategy': [
        {
          'id': 'rv-1',
          'rating': 5,
          'comment': 'Worth every rupee.',
          'authorName': 'Tanvi Joshi',
          'createdAt': iso(DateTime(2026, 10, 20)),
        },
      ],
      'svc-kit': <Object?>[],
    };
    blocks = [
      {'weekday': 2, 'startMin': 1080, 'endMin': 1230},
      {'weekday': 4, 'startMin': 1080, 'endMin': 1230},
      {'weekday': 6, 'startMin': 600, 'endMin': 780},
    ];
  }

  final String status;
  final bool hasProfile;
  final DateTime now;
  bool discoverable = true;
  int capacity = 6;
  List<String> modes = ['VIDEO', 'PHONE'];
  String? cadence = 'FORTNIGHTLY';
  String timezone = 'Asia/Kolkata';
  String meetingLink = 'https://meet.google.com/icr-mentoring-demo';
  String availabilityNote = 'Tuesday and Thursday evenings, Saturday mornings (IST).';
  String bioHtml = '<p>Nine years running facilities for large campuses.</p>';
  List<Map<String, Object?>> blocks = [];
  List<Map<String, Object?>> freeRequests = [];
  List<Map<String, Object?>> sold = [];
  List<Map<String, Object?>> terms = [];
  List<Map<String, Object?>> roster = [];
  List<Map<String, Object?>> finished = [];
  List<Map<String, Object?>> upcoming = [];
  List<Map<String, Object?>> feedback = [];
  List<Map<String, Object?>> services = [];
  Map<String, List<Object?>> serviceReviews = {};
  Map<String, Object?> earnings = {};
  int answeredThisMonth = 2;
  bool offline = false;

  Map<String, Object?> _row(String id) => sold.firstWhere((p) => p['id'] == id);
  Map<String, Object?> _term(String id) => terms.firstWhere((p) => p['id'] == id);

  Map<String, Object?> get dashboard => hasProfile
      ? {
          'hasProfile': true,
          'profile': {
            'id': 'mp-anand',
            'headline': 'Head of Facilities Strategy at Prestige Group',
            'status': status,
            'discoverable': discoverable,
            'reviewNote': status == 'REJECTED' ? 'Please add a second reference.' : null,
            'submittedAt': iso(DateTime(2026, 5, 29)),
            'approvedAt': iso(DateTime(2026, 6, 3)),
            'rating': 4.8,
            'ratingCount': 14,
            'menteesHelped': 6,
          },
          'completeness': {
            'score': 73,
            'missing': ['List your certifications', 'Add your work history'],
          },
          'capacity': {'total': capacity, 'active': roster.length, 'open': (capacity - roster.length).clamp(0, 99)},
          'requests': {
            'pending': freeRequests.where((r) => r['status'] == 'PENDING').length,
            'answeredThisMonth': answeredThisMonth,
            'acceptedThisMonth': 1,
            'acceptRateThisMonth': 50,
          },
          'mentees': {'active': roster.length, 'completed': finished.length},
          'isListed': status == 'APPROVED' && discoverable,
          'recentActivity': [
            {
              'id': 'ev-1',
              'type': 'COMPLETED',
              'note': 'Marked complete by the mentor.',
              'visibility': 'SHARED',
              'actor': {'id': 'u-anand', 'firstName': 'Anand', 'lastName': 'Iyer'},
              'metadata': null,
              'createdAt': iso(DateTime(2026, 10, 6)),
            },
          ],
        }
      : {
          'hasProfile': false,
          'profile': null,
          'completeness': null,
          'capacity': null,
          'requests': null,
          'mentees': null,
          'isListed': false,
          'recentActivity': <Object?>[],
        };

  Map<String, Reply> routes() {
    final r = <String, Reply>{
      'GET /mentorship/mentors/me/dashboard': (_) => offline ? refuse('The desk is down.', status: 500) : dashboard,
      'GET /mentorship/mentors/me/roster': (_) => roster,
      'GET /mentorship/mentors/me': (_) => {
        'id': 'mp-anand',
        'status': status,
        'bioHtml': bioHtml,
        'preferredModes': modes,
        'cadence': cadence,
        'capacity': capacity,
        'timezone': timezone,
        'availabilityNote': availabilityNote,
        'meetingLink': meetingLink,
        'discoverable': discoverable,
        'openSlots': (capacity - roster.length).clamp(0, 99),
        'availabilityBlocks': blocks,
      },
      'PUT /mentorship/mentors/me': (o) {
        final b = o.data as Map<String, dynamic>;
        if (b.containsKey('preferredModes')) modes = (b['preferredModes'] as List).cast<String>();
        if (b.containsKey('cadence')) cadence = b['cadence'] as String?;
        if (b.containsKey('capacity')) capacity = b['capacity'] as int;
        if (b.containsKey('timezone')) timezone = b['timezone'] as String;
        if (b.containsKey('meetingLink')) meetingLink = (b['meetingLink'] as String?) ?? '';
        if (b.containsKey('availabilityNote')) availabilityNote = b['availabilityNote'] as String;
        if (b.containsKey('bioHtml')) bioHtml = b['bioHtml'] as String;
        return {'id': 'mp-anand'};
      },
      'PUT /mentorship/mentors/me/availability': (o) {
        final b = o.data as Map<String, dynamic>;
        blocks = [
          for (final x in (b['blocks'] as List)) {...(x as Map<String, dynamic>)},
        ];
        return {'id': 'mp-anand'};
      },
      'PATCH /mentorship/mentors/me/visibility': (o) {
        discoverable = (o.data as Map<String, dynamic>)['discoverable'] as bool;
        return {'discoverable': discoverable};
      },
      'GET /mentorship/mine': (_) => page([...roster, ...finished]),
      'GET /mentorship/requests/incoming': (_) => page(freeRequests),
      'GET /mentorship/requests/mine': (_) => page([]),
      'GET /mentorship/summary': (_) => summaryJson(
        asMentor: roster.length,
        asMentee: 0,
        incoming: freeRequests.length,
        outgoing: 0,
        isMentor: true,
        mentorStatus: status,
      ),
      'GET /mentorship/sessions/upcoming': (_) => upcoming,
      'GET /mentorship/mentees/me/access': (_) => {
        'tier': 'FREE',
        'pendingRequests': 0,
        'pendingRequestLimit': null,
        'activeMentorships': 0,
        'activeMentorshipLimit': null,
        'canRequest': true,
      },
      'GET /mentor-services/purchases/mine': (o) {
        final open = o.queryParameters['scope'] == 'open';
        final rows = open
            ? sold.where(
                (p) =>
                    !const {'FULFILLED', 'DECLINED', 'CANCELLED', 'REFUNDED', 'EXPIRED'}.contains(p['status']) ||
                    p['issueReportedAt'] != null && p['issueResolvedAt'] == null,
              )
            : sold;
        return page(rows.toList());
      },
      'GET /mentor-plans/subscriptions/sold': (_) => terms,
      'GET /mentor-services/mine/earnings': (_) => earnings,
      'GET /mentorship/mentors/mp-anand/feedback': (_) => feedback,
      'GET /mentor-services/mine': (_) => {'optedIn': true, 'services': services},
      'GET /mentorship/mentors/mp-anand/slots': (_) => {
        'timezone': 'Asia/Kolkata',
        'slots': [iso(DateTime(2026, 10, 28, 18)), iso(DateTime(2026, 10, 28, 19)), iso(DateTime(2026, 10, 30, 18))],
      },
      'GET /mentorship/sessions': (_) => [],
      'GET /mentor-services/bookings/range': (_) => [],
      'GET /mentorship/group-sessions/mine/upcoming': (_) => [],
    };
    for (final id in ['r-isha', 'r-vikram']) {
      r['POST /mentorship/requests/$id/accept'] = (_) {
        freeRequests.firstWhere((x) => x['id'] == id)['status'] = 'ACCEPTED';
        roster = [
          ...roster,
          pairingJson('pair-$id', side: 'MENTOR', mentor: anand, mentee: id == 'r-isha' ? _isha : _vikram),
        ];
        return {'id': 'pair-$id'};
      };
      r['POST /mentorship/requests/$id/decline'] = (_) {
        freeRequests.firstWhere((x) => x['id'] == id)['status'] = 'DECLINED';
        return {'ok': true};
      };
    }
    for (final s in services) {
      final id = s['id'] as String;
      r['GET /mentor-services/$id/reviews'] = (_) => serviceReviews[id] ?? <Object?>[];
    }
    for (final p in sold) {
      final id = p['id'] as String;
      String path(String tail) => '/mentor-services/purchases/$id$tail';
      r['GET ${path('/suggested-times')}'] = (_) => {
        'timezone': 'Asia/Kolkata',
        'hasWeeklyHours': true,
        'preferred': <String>[],
        'suggestions': [
          {'at': iso(DateTime(2026, 10, 28, 18)), 'preferred': true},
          {'at': iso(DateTime(2026, 10, 30, 18)), 'preferred': false},
        ],
      };
      r['POST ${path('/accept')}'] = (o) {
        final row = _row(id);
        final at = (o.data as Map<String, dynamic>)['scheduledAt'] as String;
        final req = {...(row['request'] as Map<String, Object?>), 'scheduledAt': at, 'decidedAt': iso(now)};
        row['request'] = req;
        if ((row['pricePaisa'] as int) == 0) {
          row['status'] = 'PAID';
          row['booking'] = bookingBlock(DateTime.parse(at), minutes: req['durationMin'] as int);
        } else {
          row['status'] = 'ACCEPTED';
        }
        return row;
      };
      r['POST ${path('/decline')}'] = (o) {
        final row = _row(id);
        row['status'] = 'DECLINED';
        return row;
      };
      r['POST ${path('/withdraw')}'] = (_) {
        final row = _row(id);
        row['status'] = 'CANCELLED';
        row['cancelReason'] = 'Withdrawn by the mentor before payment.';
        return row;
      };
      r['POST ${path('/complete')}'] = (_) {
        final row = _row(id);
        row['status'] = 'FULFILLED';
        row['booking'] = null;
        return row;
      };
      r['POST ${path('/cancel')}'] = (o) {
        final row = _row(id);
        row['status'] = 'CANCELLED';
        row['booking'] = null;
        row['cancelReason'] = (o.data as Map<String, dynamic>)['reason'];
        return row;
      };
      r['PATCH ${path('/meeting-link')}'] = (o) {
        final row = _row(id);
        final b = Map<String, Object?>.from(row['booking'] as Map<String, Object?>);
        b['meetingLink'] = (o.data as Map<String, dynamic>)['meetingLink'];
        row['booking'] = b;
        return row;
      };
      r['POST ${path('/reschedule')}'] = (o) {
        final row = _row(id);
        final body = o.data as Map<String, dynamic>;
        final b = Map<String, Object?>.from(row['booking'] as Map<String, Object?>);
        b['proposedScheduledAt'] = body['scheduledAt'];
        b['proposedBy'] = 'MENTOR';
        b['proposedAt'] = iso(now);
        b['proposedNote'] = body['note'];
        row['booking'] = b;
        return row;
      };
      r['POST ${path('/reschedule/accept')}'] = (_) {
        final row = _row(id);
        final b = Map<String, Object?>.from(row['booking'] as Map<String, Object?>);
        b['scheduledAt'] = b['proposedScheduledAt'];
        b['proposedScheduledAt'] = null;
        b['proposedBy'] = null;
        b['proposedAt'] = null;
        row['booking'] = b;
        return row;
      };
      r['POST ${path('/reschedule/decline')}'] = (_) {
        final row = _row(id);
        final b = Map<String, Object?>.from(row['booking'] as Map<String, Object?>);
        b['proposedScheduledAt'] = null;
        b['proposedBy'] = null;
        b['proposedAt'] = null;
        row['booking'] = b;
        return row;
      };
      r['POST ${path('/respond-issue')}'] = (o) {
        final row = _row(id);
        row['issueRespondedAt'] = iso(now);
        row['issueResponseNote'] = (o.data as Map<String, dynamic>)['note'];
        return row;
      };
    }
    for (final t in terms) {
      final id = t['id'] as String;
      r['POST /mentor-plans/subscriptions/$id/decide'] = (o) {
        final b = o.data as Map<String, dynamic>;
        final row = _term(id);
        row['status'] = b['decision'] == 'ACCEPT' ? 'PENDING_PAYMENT' : 'DECLINED';
        return {'ok': true, 'status': row['status']};
      };
    }
    return r;
  }

  FakeApi api({Map<String, Reply> extra = const {}}) => FakeApi({...routes(), ...extra});
}

/// Pumps the desk over [world] (the pinned clock is the caller's to set), and returns the api and what the links did.
Future<(FakeApi, LinkRecorder)> pumpDesk(
  WidgetTester tester,
  DeskWorld world, {
  DeskTab tab = DeskTab.overview,
  double height = 6000,
  Map<String, Reply> extra = const {},
  void Function(BuildContext context)? onBecomeMentor,
  List<String>? becameMentor,
}) async {
  phone(tester, height: height);
  final api = world.api(extra: extra);
  final rec = LinkRecorder();
  await pumpApp(
    tester,
    MentorDeskScreen(
      repository: MentorDeskRepository(api: api.client()),
      initialTab: tab,
      links: rec.links,
      onBecomeMentor: onBecomeMentor ?? (context) => becameMentor?.add('become'),
    ),
  );
  return (api, rec);
}
