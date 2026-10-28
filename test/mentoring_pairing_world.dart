/// A stateful fake of everything one pairing's page reads and writes, in the
/// shapes the real API answers with: a write changes what the next read says,
/// so a test proves the effect, and `requests` records what was sent.
library;

import 'package:dio/dio.dart';

import 'mentoring_fakes.dart';

class PairingWorld {
  PairingWorld({
    this.id = 'pair-anand',
    this.side = 'MENTEE',
    this.status = 'ACTIVE',
    DateTime? now,
    bool withPlan = false,
    bool programme = false,
  }) : now = now ?? DateTime(2026, 10, 26, 10) {
    final n = this.now;
    sessions = [
      sessionJson(
        's-overdue',
        mentorshipId: id,
        at: n.subtract(const Duration(days: 1)),
        agenda: 'Reviewing the scorecard draft',
        side: side,
      ),
      sessionJson(
        's-next',
        mentorshipId: id,
        at: n.add(const Duration(days: 3)),
        agenda: 'Mock panel interview',
        side: side,
      ),
      sessionJson(
        's-req',
        mentorshipId: id,
        at: n.add(const Duration(days: 9)),
        status: 'REQUESTED',
        agenda: 'Vendor SLA governance',
        side: side,
        link: null,
      ),
      sessionJson(
        's-held',
        mentorshipId: id,
        at: n.subtract(const Duration(days: 14)),
        status: 'COMPLETED',
        agenda: 'Where you are and where you want to be',
        side: side,
      )..['notes'] = 'Agreed a 90-day target.',
      sessionJson(
        's-cancelled',
        mentorshipId: id,
        at: n.subtract(const Duration(days: 6)),
        status: 'CANCELLED',
        cancelReason: 'A site shutdown came up that week.',
        side: side,
        agenda: null,
      ),
    ];
    goals = [
      goalJson('g1', mentorshipId: id),
      goalJson('g3', mentorshipId: id, title: 'Understand SLA reporting', status: 'ACHIEVED', progress: 100),
    ];
    tasks = [
      _task(
        't1',
        'Draft the vendor scorecard template',
        mine: false,
        overdue: true,
        due: n.subtract(const Duration(days: 2)),
      ),
      _task('t3', 'Send Anand the current org chart', mine: true, done: true),
    ];
    timeline = [
      {
        'id': 'ev0',
        'type': 'STARTED',
        'note': 'The pairing began.',
        'visibility': 'SHARED',
        'actor': {'id': 'u-anand', 'firstName': 'Anand', 'lastName': 'Iyer'},
        'metadata': null,
        'createdAt': iso(n.subtract(const Duration(days: 40))),
      },
    ];
    if (withPlan) term = _term(programme: programme);
  }

  final String id;
  final String side;
  String status;
  final DateTime now;
  String cadence = 'FORTNIGHTLY';
  String? endedReason;
  String? conversationId;
  List<Map<String, Object?>> sessions = [];
  List<Map<String, Object?>> goals = [];
  List<Map<String, Object?>> tasks = [];
  List<Map<String, Object?>> timeline = [];
  List<Map<String, Object?>> resources = [];
  List<Map<String, Object?>> certificates = [];
  Map<String, Object?>? feedback;
  Map<String, Object?>? term;
  List<String> modes = ['VIDEO', 'PHONE'];
  List<DateTime> slots = [];
  int _n = 0;

  bool get mentor => side == 'MENTOR';

  Map<String, Object?> _task(
    String id,
    String title, {
    bool mine = false,
    bool overdue = false,
    DateTime? due,
    bool done = false,
  }) => {
    'id': id,
    'mentorshipId': this.id,
    'sessionId': null,
    'goalId': null,
    'title': title,
    'detail': null,
    'dueAt': due == null ? null : iso(due),
    'status': done ? 'DONE' : 'OPEN',
    'completedAt': null,
    'createdById': mine ? 'u-bharat' : 'u-anand',
    'createdAt': iso(now),
    'isMine': mine,
    'overdue': overdue,
  };

  Map<String, Object?> _term({required bool programme}) => {
    'id': 'term-1',
    'planId': 'plan-1',
    'titleSnapshot': programme ? 'Site to portfolio: a 3-session programme' : 'Monthly leadership coaching',
    'status': 'ACTIVE',
    'pricePaisa': 299900,
    'discountPaisa': 0,
    'taxPaisa': 0,
    'totalPaisa': 299900,
    'currency': 'INR',
    'billingPeriodMonths': 1,
    'currentPeriodStart': iso(now.subtract(const Duration(days: 10))),
    'currentPeriodEnd': iso(now.add(const Duration(days: 20))),
    'sessionsAllowance': programme ? 3 : 2,
    'sessionsUsed': 1,
    'cancelAtPeriodEnd': false,
    'cancelledAt': null,
    'cancelReason': null,
    'mentorshipId': id,
    'createdAt': iso(now),
    'kind': programme ? 'CURRICULUM' : 'RECURRING',
    'steps': programme
        ? [
            for (var i = 1; i <= 3; i++)
              {
                'id': 'step-$i',
                'position': i,
                'title': ['Where you are', 'Vendor and SLA governance', 'The portfolio business case'][i - 1],
                'outline': null,
                'durationMin': 60,
                'sessionId': i == 1 ? 's-held' : null,
                'completedAt': i == 1 ? iso(now) : null,
                'isNext': i == 2,
              },
          ]
        : [],
    'counterpart': anand,
  };

  Map<String, Object?> get pairing =>
      pairingJson(
          id,
          status: status,
          side: side,
          mentor: anand,
          mentee: mentor ? personJson('u-meera', 'Meera', 'Nair', careerStage: 'MID_CAREER') : bharat,
          conversationId: conversationId,
          completedAt: status == 'COMPLETED' ? iso(now) : null,
        )
        ..['cadence'] = cadence
        ..['endedReason'] = endedReason;

  Map<String, Object?> _session(String id) => sessions.firstWhere((s) => s['id'] == id);

  Map<String, Reply> routes() {
    String p(String tail) => '/mentorship/$id$tail';
    return {
      'GET ${p('')}': (_) => pairing,
      'GET ${p('/sessions')}': (_) => sessions,
      'GET ${p('/goals')}': (_) => goals,
      'GET ${p('/tasks')}': (_) => tasks,
      'GET ${p('/timeline')}': (_) => timeline,
      'GET /mentorship/resources': (_) => resources,
      'GET ${p('/feedback/mine')}': (_) => feedback ?? '',
      'GET /mentor-plans/subscriptions/mine': (_) => mentor || term == null ? <Object?>[] : [term],
      'GET /mentor-plans/subscriptions/sold': (_) => mentor && term != null ? [term] : <Object?>[],
      'GET /mentorship/mine/certificates': (_) => certificates,
      'GET /mentorship/mentors/mp-anand': (_) => {'id': 'mp-anand', 'preferredModes': modes},
      'GET /mentorship/mentors/mp-anand/slots': (o) => {
        'slots': [for (final s in slots) iso(s)],
      },
      'POST ${p('/conversation')}': (_) => {'conversationId': conversationId ??= 'conv-1'},
      'PATCH ${p('')}': (o) {
        final b = o.data as Map<String, dynamic>;
        if (b['status'] != null) status = b['status'] as String;
        if (b['cadence'] != null) cadence = b['cadence'] as String;
        if (b['endedReason'] != null) endedReason = b['endedReason'] as String;
        if (status == 'COMPLETED') {
          certificates = [certificateJson()..['mentorshipId'] = id];
        }
        return pairing;
      },
      'POST ${p('/sessions')}': (o) {
        final b = o.data as Map<String, dynamic>;
        final s = sessionJson(
          'new-${++_n}',
          mentorshipId: id,
          at: DateTime.parse(b['scheduledAt'] as String),
          status: mentor ? 'SCHEDULED' : 'REQUESTED',
          minutes: b['durationMin'] as int,
          agenda: b['agenda'] as String?,
          side: side,
        )..['mode'] = b['mode'];
        sessions = [s, ...sessions];
        return s;
      },
      'POST ${p('/notes')}': (o) {
        final b = o.data as Map<String, dynamic>;
        timeline = [
          ...timeline,
          {
            'id': 'ev-${++_n}',
            'type': 'NOTE_ADDED',
            'note': b['note'],
            'visibility': b['privateToMe'] == true ? 'MENTEE_ONLY' : 'SHARED',
            'actor': {'id': 'u-bharat', 'firstName': 'Bharat', 'lastName': 'Buyer'},
            'metadata': null,
            'createdAt': iso(now),
          },
        ];
        return timeline.last;
      },
      'POST ${p('/goals')}': (o) {
        final b = o.data as Map<String, dynamic>;
        goals = [
          ...goals,
          goalJson(
            'g-${++_n}',
            mentorshipId: id,
            title: b['title'] as String,
            progress: 0,
            detail: b['detail'] as String?,
          ),
        ];
        return goals.last;
      },
      'POST ${p('/tasks')}': (o) {
        final b = o.data as Map<String, dynamic>;
        tasks = [...tasks, _task('t-${++_n}', b['title'] as String, mine: true)];
        return tasks.last;
      },
      'POST ${p('/feedback')}': (o) {
        final b = o.data as Map<String, dynamic>;
        feedback = {
          'rating': b['rating'],
          'comment': b['comment'],
          'wouldRecommend': b['wouldRecommend'],
          'createdAt': iso(now),
        };
        return {'ok': true};
      },
      'POST ${p('/concerns')}': (_) => {'id': 'concern-new'},
      'POST /support/tickets': (_) => {'id': 'ticket-1'},
      'POST /mentorship/resources': (o) {
        final b = o.data as Map<String, dynamic>;
        resources = [
          ...resources,
          {
            'id': 'r-${++_n}',
            'title': b['title'],
            'kind': b['kind'],
            'note': b['note'],
            'url': b['url'],
            'fileName': null,
            'fileSize': null,
            'addedBy': {'id': 'u-bharat', 'firstName': 'Bharat', 'lastName': 'Buyer'},
            'canRemove': true,
            'createdAt': iso(now),
          },
        ];
        return resources.last;
      },
    };
  }

  /// Routes that carry an id in the path: the harness registers them per known id.
  Map<String, Reply> idRoutes() {
    final out = <String, Reply>{};
    for (final sid in ['s-overdue', 's-next', 's-req', 's-held', 's-cancelled', 'new-1', 'new-2']) {
      String s(String tail) => '/mentorship/$id/sessions/$sid$tail';
      out['PATCH ${s('')}'] = (o) {
        final b = o.data as Map<String, dynamic>;
        final row = _session(sid);
        row['scheduledAt'] = b['scheduledAt'];
        row['durationMin'] = b['durationMin'];
        row['mode'] = b['mode'];
        row['agenda'] = b['agenda'];
        row['status'] = 'SCHEDULED';
        return row;
      };
      out['POST ${s('/approve')}'] = (_) => _session(sid)..['status'] = 'SCHEDULED';
      out['POST ${s('/cancel')}'] = (o) {
        final b = o.data as Map<String, dynamic>;
        return _session(sid)
          ..['status'] = 'CANCELLED'
          ..['cancelReason'] = b['reason'];
      };
      out['POST ${s('/complete')}'] = (o) {
        final b = o.data as Map<String, dynamic>;
        return _session(sid)
          ..['status'] = 'COMPLETED'
          ..['durationMin'] = b['durationMin'] ?? _session(sid)['durationMin'];
      };
      out['PATCH ${s('/meeting-link')}'] = (o) {
        final b = o.data as Map<String, dynamic>;
        return _session(sid)..['meetingLink'] = b['meetingLink'];
      };
      out['PATCH ${s('/record')}'] = (o) {
        final b = o.data as Map<String, dynamic>;
        final row = _session(sid);
        if (b.containsKey('notes') && b['notes'] != row['notes']) row['summary'] = null;
        row['notes'] = b['notes'] ?? row['notes'];
        if (b.containsKey('recordingUrl')) row['recordingUrl'] = b['recordingUrl'];
        return row;
      };
      out['POST ${s('/summarise')}'] = (_) {
        final row = _session(sid);
        row['summary'] = 'Discussed the 90-day target. Decided to start with the scorecard. Next: review it.';
        return {'summary': row['summary'], 'cached': false};
      };
    }
    for (final gid in ['g1', 'g3', 'g-1']) {
      String g(String tail) => '/mentorship/$id/goals/$gid$tail';
      out['POST ${g('/status')}'] = (o) {
        final b = o.data as Map<String, dynamic>;
        final row = goals.firstWhere((x) => x['id'] == gid);
        row['status'] = b['status'];
        if (b['status'] == 'ACHIEVED') row['progress'] = 100;
        return row;
      };
      out['POST ${g('/progress')}'] = (o) {
        final b = o.data as Map<String, dynamic>;
        final row = goals.firstWhere((x) => x['id'] == gid);
        row['progress'] = b['progress'];
        return row;
      };
      out['DELETE ${g('')}'] = (_) {
        goals = goals.where((x) => x['id'] != gid).toList();
        return {'ok': true};
      };
    }
    for (final tid in ['t1', 't3', 't-1']) {
      String t(String tail) => '/mentorship/$id/tasks/$tid$tail';
      out['PATCH ${t('')}'] = (o) {
        final b = o.data as Map<String, dynamic>;
        final row = tasks.firstWhere((x) => x['id'] == tid);
        row['status'] = b['status'];
        return row;
      };
      out['DELETE ${t('')}'] = (_) {
        tasks = tasks.where((x) => x['id'] != tid).toList();
        return {'ok': true};
      };
    }
    for (final rid in ['r-1', 'r-2']) {
      out['DELETE /mentorship/resources/$rid'] = (_) {
        resources = resources.where((x) => x['id'] != rid).toList();
        return {'ok': true};
      };
    }
    out['POST /mentor-plans/subscriptions/term-1/cancel'] = (_) {
      term?['cancelAtPeriodEnd'] = true;
      return {'ok': true};
    };
    return out;
  }

  FakeApi api({Map<String, Reply> extra = const {}}) => FakeApi({...routes(), ...idRoutes(), ...extra});
}

/// A stored file the fake serves for a shared resource.
Object fileReply(RequestOptions o) => [37, 80, 68, 70];
