/// A stateful fake of what the Purchases tab, group sessions and programmes read and write, in the shapes the
/// real API answers with (each fixture was checked against a live call by `test/live/mentoring_live_test.dart`).
/// A write changes what the next read says; `requests` of the [FakeApi] records what was sent.
library;

import 'mentoring_fakes.dart';

final _now = DateTime(2026, 10, 26, 10);

Map<String, Object?> purchaseJson(
  String id, {
  String type = 'ONE_ON_ONE',
  String title = 'Facilities leadership strategy session',
  int price = 149900,
  String status = 'REQUESTED',
  Map<String, Object?>? request,
  Map<String, Object?>? booking,
  String? downloadUrl,
  String? fileName,
  bool hasReview = false,
  String? cancelReason,
  String? groupSessionId,
}) => {
  'id': id,
  'type': type,
  'titleSnapshot': title,
  'pricePaisa': price,
  'currency': 'INR',
  'status': status,
  'serviceId': 'svc-1',
  'side': 'BUYER',
  'buyer': bharat,
  'mentor': anand,
  'paidAt': status == 'PAID' || status == 'FULFILLED' ? iso(_now.subtract(const Duration(days: 1))) : null,
  'fulfilledAt': status == 'FULFILLED' ? iso(_now.subtract(const Duration(days: 1))) : null,
  'refundedAt': null,
  'cancelReason': cancelReason,
  'question': null,
  'conversationId': null,
  'booking': booking,
  'request': request,
  'groupSessionId': groupSessionId,
  'groupSessionTitle': null,
  'groupSessionAt': null,
  'downloadUrl': downloadUrl,
  'fileName': fileName,
  'hasReview': hasReview,
  'netPaisa': null,
  'createdAt': iso(_now.subtract(const Duration(days: 3))),
};

Map<String, Object?> requestBlock({
  String topic = 'Preparing for a facilities head interview',
  DateTime? scheduledAt,
  int list = 149900,
  int minutes = 45,
  DateTime? payBy,
  String? declineReason,
  String? timeDeclineNote,
  int timeDeclineCount = 0,
}) => {
  'topic': topic,
  'preferredTimes': null,
  'preferredTimeKeys': <String>[],
  'mode': 'VIDEO',
  'durationMin': minutes,
  'scheduledAt': scheduledAt == null ? null : iso(scheduledAt),
  'decidedAt': scheduledAt == null ? null : iso(_now.subtract(const Duration(days: 1))),
  'declineReason': declineReason,
  'payBy': payBy == null ? null : iso(payBy),
  'timeDeclinedAt': null,
  'timeDeclineNote': timeDeclineNote,
  'timeDeclineCount': timeDeclineCount,
  'listPricePaisa': list,
};

Map<String, Object?> bookingBlock({
  required DateTime at,
  String status = 'SCHEDULED',
  String? link = 'https://meet.google.com/icr-demo',
  DateTime? proposed,
  String? proposedBy,
  String? proposedNote,
}) => {
  'id': 'bk-1',
  'scheduledAt': iso(at),
  'durationMin': 30,
  'mode': 'VIDEO',
  'meetingLink': link,
  'status': status,
  'proposedScheduledAt': proposed == null ? null : iso(proposed),
  'proposedBy': proposedBy,
  'proposedAt': proposed == null ? null : iso(_now),
  'proposedNote': proposedNote,
  'rescheduleCount': 0,
  'rescheduledAt': null,
};

Map<String, Object?> termJson(
  String id, {
  String status = 'PENDING_MENTOR',
  bool programme = true,
  int total = 599900,
  int price = 599900,
  int discount = 0,
  int tax = 0,
  String? mentorshipId,
  int allowance = 3,
  int used = 0,
  String? declineReason,
}) => {
  'id': id,
  'planId': 'plan-$id',
  'titleSnapshot': programme ? 'Site to portfolio: a 3-session programme' : 'Monthly leadership coaching',
  'status': status,
  'pricePaisa': price,
  'discountPaisa': discount,
  'taxPaisa': tax,
  'totalPaisa': total,
  'currency': 'INR',
  'billingPeriodMonths': programme ? 3 : 1,
  'currentPeriodStart': status == 'ACTIVE' ? iso(_now.subtract(const Duration(days: 10))) : null,
  'currentPeriodEnd': status == 'ACTIVE' ? iso(_now.add(const Duration(days: 20))) : null,
  'sessionsAllowance': allowance,
  'sessionsUsed': used,
  'cancelAtPeriodEnd': false,
  'cancelledAt': null,
  'cancelReason': null,
  'refundedAt': null,
  'mentorshipId': mentorshipId,
  'createdAt': iso(_now.subtract(const Duration(days: 2))),
  'kind': programme ? 'CURRICULUM' : 'RECURRING',
  'steps': programme
      ? [
          for (var i = 1; i <= 3; i++)
            {
              'id': 'st$i',
              'position': i,
              'title': ['Where you are', 'Vendor and SLA governance', 'The portfolio business case'][i - 1],
              'outline': null,
              'durationMin': 60,
              'sessionId': null,
              'completedAt': null,
              'isNext': i == 1,
            },
        ]
      : <Object?>[],
  'decidedAt': null,
  'declineReason': declineReason,
  'counterpart': anand,
};

Map<String, Object?> groupJson(
  String id, {
  String title = 'From site to portfolio: an open clinic',
  String status = 'SCHEDULED',
  String? myStatus,
  int? price,
  int capacity = 25,
  int taken = 3,
  bool canRegister = true,
  bool seatForSale = false,
  String? blockedReason,
  String? meetingLink,
  DateTime? at,
  bool detail = false,
  List<Map<String, Object?>> attendees = const [],
  String? programId,
  bool hasReview = false,
  String? purchaseId,
}) {
  final when = at ?? _now.add(const Duration(days: 6));
  return {
    'id': id,
    'title': title,
    'summary': 'An hour on how to frame a portfolio case.',
    'coverUrl': null,
    'scheduledAt': iso(when),
    'durationMin': 60,
    'occurrences': [
      {
        'id': '$id-occ1',
        'seq': 1,
        'title': null,
        'scheduledAt': iso(when),
        'durationMin': 60,
        'status': status == 'COMPLETED' ? 'COMPLETED' : 'SCHEDULED',
        'completedAt': null,
        'cancelledAt': null,
      },
    ],
    'occurrenceCount': 1,
    'mode': 'VIDEO',
    'location': null,
    'timezone': 'Asia/Kolkata',
    'status': status,
    'capacity': capacity,
    'seatsTaken': taken,
    'seatsLeft': capacity - taken,
    'waitlistCount': 0,
    'focusAreas': ['Career transitions'],
    'competencies': ['Career transitions'],
    'host': {
      'id': 'u-anand',
      'firstName': 'Anand',
      'lastName': 'Iyer',
      'avatarUrl': null,
      'headline': 'Head of Facilities Strategy at Prestige Group',
      'companyName': null,
    },
    'programId': programId,
    'programName': programId == null ? null : 'Early-career mentoring circle',
    'myStatus': myStatus,
    'pricePaisa': price,
    'serviceId': null,
    if (detail) ...{
      'agendaHtml': '<p>Bring a real case.</p><ul><li>Framing</li><li>Numbers</li></ul>',
      'meetingLink': meetingLink,
      'cancelReason': null,
      'completedAt': null,
      'attendees': attendees,
      'rosterScope': attendees.isEmpty ? 'none' : 'peer',
      'rosterHiddenCount': 0,
      'isHost': false,
      'canRegister': canRegister,
      'seatForSale': seatForSale,
      'blockedReason': blockedReason,
      'conversationId': null,
      'myPurchaseId': purchaseId,
      'myPurchaseStatus': purchaseId == null ? null : 'PAID',
      'myPurchaseHasReview': hasReview,
    },
  };
}

Map<String, Object?> programmeJson(
  String slug, {
  String status = 'OPEN',
  List<Map<String, Object?>> mine = const [],
  int mentees = 1,
  int mentors = 1,
  bool detail = false,
}) => {
  'id': 'prog-$slug',
  'slug': slug,
  'name': 'Early-career mentoring circle',
  'summary': 'Twelve weeks of group mentoring for people in their first five years in facilities.',
  'coverUrl': null,
  'status': status,
  'applicationsOpenAt': iso(_now.subtract(const Duration(days: 10))),
  'applicationsCloseAt': iso(_now.add(const Duration(days: 25))),
  'startsAt': iso(_now.add(const Duration(days: 30))),
  'endsAt': iso(_now.add(const Duration(days: 120))),
  'menteeCapacity': 12,
  'mentorCapacity': 4,
  'focusAreas': ['Career transitions'],
  'competencies': ['Career transitions'],
  'organiser': {'id': 'u-anand', 'firstName': 'Anand', 'lastName': 'Iyer', 'avatarUrl': null, 'companyName': null},
  'enrolmentCount': 3,
  'mentorshipCount': 0,
  'createdAt': iso(_now),
  if (detail) ...{
    'detailHtml': '<p>A small cohort, a fixed monthly rhythm.</p>',
    'menteesTaken': mentees,
    'mentorsTaken': mentors,
    'myEnrolments': mine,
    'canOrganise': false,
  },
};

Map<String, Object?> enrolmentJson(
  String id, {
  String role = 'MENTEE',
  String status = 'APPLIED',
  String slug = 'circle',
}) => {
  'id': id,
  'programId': 'prog-$slug',
  'role': role,
  'status': status,
  'createdAt': iso(_now),
  'decidedAt': null,
  'motivation': 'I want a steadier rhythm of mentoring.',
  'decisionNote': null,
  'program': programmeJson(slug),
};

class PurchasesWorld {
  PurchasesWorld({this.live = true}) {
    final n = _now;
    purchases = [
      purchaseJson('p-req', status: 'REQUESTED', request: requestBlock()),
      purchaseJson(
        'p-acc',
        title: 'Portfolio and CV review call',
        price: 79900,
        status: 'ACCEPTED',
        request: requestBlock(
          topic: 'Review my portfolio',
          scheduledAt: n.add(const Duration(days: 4)),
          list: 79900,
          minutes: 60,
          payBy: n.add(const Duration(days: 3)),
        ),
      ),
      purchaseJson(
        'p-booked',
        title: 'Career clarity call',
        price: 0,
        status: 'PAID',
        request: requestBlock(
          topic: 'Mapping my next two years',
          scheduledAt: n.add(const Duration(days: 2)),
          list: 0,
          minutes: 30,
        ),
        booking: bookingBlock(at: n.add(const Duration(days: 2))),
      ),
      purchaseJson(
        'p-kit',
        type: 'RESOURCE',
        title: 'FM interview question bank',
        price: 49900,
        status: 'FULFILLED',
        downloadUrl: '/uploads/interview-question-bank.pdf',
        fileName: 'interview-question-bank',
      ),
      purchaseJson(
        'p-decl',
        status: 'DECLINED',
        request: requestBlock(declineReason: 'I am travelling that fortnight.'),
      ),
    ];
    terms = [
      termJson('t-prog'),
      termJson('t-pay', status: 'PENDING_PAYMENT', total: 538200, price: 599900, discount: 100000, tax: 38300),
      termJson(
        't-coach',
        status: 'ACTIVE',
        programme: false,
        total: 299900,
        price: 299900,
        mentorshipId: 'pair-anand',
        allowance: 2,
        used: 1,
      ),
    ];
    seats = [groupJson('g-clinic', myStatus: 'REGISTERED', meetingLink: 'https://meet.google.com/icr-demo')];
    enrolments = [enrolmentJson('e-1')];
  }

  final bool live;
  int _n = 0;
  List<Map<String, Object?>> purchases = [];
  List<Map<String, Object?>> terms = [];
  List<Map<String, Object?>> seats = [];
  List<Map<String, Object?>> enrolments = [];
  Map<String, Object?> discounts = {
    'services': {'bps': 0, 'planName': null},
    'plans': {'bps': 0, 'planName': null},
    'sessionCredits': {'perPeriod': 1, 'remaining': 1, 'capPaisa': 150000, 'planName': 'Pro Plus', 'resetsAt': null},
  };

  Map<String, Object?> _p(String id) => purchases.firstWhere((p) => p['id'] == id);
  Map<String, Object?> _t(String id) => terms.firstWhere((p) => p['id'] == id);

  Map<String, Reply> routes() => {
    ...menteeRoutes(),
    'GET /payments/mode': (_) => {'mode': live ? 'live' : 'simulated', 'configured': true},
    'GET /mentor-services/member-discounts': (_) => discounts,
    'GET /mentor-services/purchases/mine': (_) => page(purchases),
    'GET /mentor-plans/subscriptions/mine': (_) => terms,
    'GET /mentorship/group-sessions/mine/upcoming': (_) => seats,
    'GET /mentorship/programmes/mine': (_) => enrolments,
    'GET /mentorship/mentors/mp-anand': (_) => {
      'id': 'mp-anand',
      'preferredModes': ['VIDEO'],
    },
    'GET /mentorship/mentors/mp-anand/slots': (_) => {
      'slots': [iso(DateTime(2026, 10, 30, 18)), iso(DateTime(2026, 10, 30, 19))],
    },
    'GET http://api.test/uploads/interview-question-bank.pdf': (_) => [37, 80, 68, 70],
    'POST /mentorship/pair-anand/conversation': (_) => {'conversationId': 'conv-1'},
  };

  Map<String, Reply> idRoutes() {
    final out = <String, Reply>{};
    for (final id in ['p-req', 'p-acc', 'p-booked', 'p-kit', 'p-decl', 'p-conf']) {
      String s(String tail) => '/mentor-services/purchases/$id$tail';
      out['POST ${s('/withdraw')}'] = (_) {
        purchases = purchases.where((p) => p['id'] != id).toList();
        return {'ok': true};
      };
      out['POST ${s('/accept-time')}'] = (o) {
        final b = o.data as Map<String, dynamic>;
        final row = _p(id);
        final req = row['request'] as Map<String, Object?>;
        final free = (req['listPricePaisa'] as int) == 0 || b['useCredit'] == true;
        row['status'] = free ? 'PAID' : 'CONFIRMED';
        row['booking'] = bookingBlock(at: DateTime.parse(req['scheduledAt'] as String));
        return {'ok': true};
      };
      out['POST ${s('/decline-time')}'] = (o) {
        final b = o.data as Map<String, dynamic>;
        final row = _p(id);
        row['status'] = 'REQUESTED';
        row['request'] = {
          ...(row['request'] as Map<String, Object?>),
          'scheduledAt': null,
          'timeDeclineNote': b['note'],
          'timeDeclineCount': 1,
        };
        return {'ok': true};
      };
      out['POST ${s('/pay')}'] = (o) {
        final b = o.data as Map<String, dynamic>;
        _p(id)['status'] = 'PAID';
        return {'devActivated': true, 'purchaseId': id, 'useCredit': b['useCredit']};
      };
      out['POST ${s('/cancel')}'] = (o) {
        final b = o.data as Map<String, dynamic>;
        _p(id)
          ..['status'] = 'CANCELLED'
          ..['cancelReason'] = b['reason'];
        return {'ok': true};
      };
      out['POST ${s('/reschedule')}'] = (o) {
        final b = o.data as Map<String, dynamic>;
        final bk = _p(id)['booking'] as Map<String, Object?>;
        bk['proposedScheduledAt'] = b['scheduledAt'];
        bk['proposedBy'] = 'BUYER';
        bk['proposedAt'] = iso(_now);
        bk['proposedNote'] = b['note'];
        return {'ok': true};
      };
      out['POST ${s('/reschedule/accept')}'] = (_) {
        final bk = _p(id)['booking'] as Map<String, Object?>;
        bk['scheduledAt'] = bk['proposedScheduledAt'];
        bk['proposedScheduledAt'] = null;
        bk['proposedAt'] = null;
        bk['proposedBy'] = null;
        return {'ok': true};
      };
      out['POST ${s('/reschedule/decline')}'] = (_) {
        final bk = _p(id)['booking'] as Map<String, Object?>;
        bk['proposedScheduledAt'] = null;
        bk['proposedAt'] = null;
        bk['proposedBy'] = null;
        return {'ok': true};
      };
      out['POST ${s('/review')}'] = (_) {
        _p(id)['hasReview'] = true;
        return {'ok': true};
      };
      out['POST ${s('/report-issue')}'] = (_) => {'ok': true};
    }
    for (final id in ['t-prog', 't-pay', 't-coach']) {
      out['POST /mentor-plans/subscriptions/$id/cancel'] = (_) {
        final t = _t(id);
        if (t['kind'] == 'RECURRING') {
          t['cancelAtPeriodEnd'] = true;
        } else {
          terms = terms.where((x) => x['id'] != id).toList();
        }
        return {'ok': true};
      };
      out['POST /mentor-plans/subscriptions/$id/pay'] = (_) {
        _t(id)
          ..['status'] = 'ACTIVE'
          ..['mentorshipId'] = 'pair-anand';
        return {'devActivated': true, 'subscriptionId': id, 'mentorshipId': 'pair-anand'};
      };
    }
    out['POST /mentorship/programmes/enrolments/e-1/withdraw'] = (_) {
      enrolments = [
        for (final e in enrolments)
          if (e['id'] == 'e-1') {...e, 'status': 'WITHDRAWN'} else e,
      ];
      return {'ok': true};
    };
    out['DELETE /mentorship/group-sessions/g-clinic/register'] = (_) {
      seats = seats.where((s) => s['id'] != 'g-clinic').toList();
      return {'ok': true};
    };
    return out;
  }

  FakeApi api({Map<String, Reply> extra = const {}}) => FakeApi({...routes(), ...idRoutes(), ...extra});

  int nextId() => ++_n;
}
