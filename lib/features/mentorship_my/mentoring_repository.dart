import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart' show DioException, DioMediaType, FormData, MultipartFile, Options, Response, ResponseType;

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/config.dart';
import 'mentoring_models.dart';
import 'mentoring_clock.dart';

/// Everything after a member finds a mentor, from the API: pairings and what
/// happens inside one (sessions, goals, tasks, feedback, concerns), requests,
/// bookings, group seats, programmes, goals and certificates.
///
/// Money: a payment the API completes itself (₹0, a session credit that
/// covers it, or a gateway in simulated mode) is completed here; a real PayU
/// payment continues on the website, which runs the gateway's return leg.
class MentoringRepository {
  MentoringRepository({required this.api});

  final ApiClient api;

  // --- My mentoring --------------------------------------------------------

  /// Which sides the caller mentors on (`GET /mentorship/summary`).
  Future<MentoringSummary> summary() async {
    final res = await _get('/mentorship/summary');
    return MentoringSummary(
      isMentor: res['isMentor'] == true,
      mentorStatus: res['mentorStatus'] as String?,
      pendingIncoming: asInt(res['pendingIncoming']),
      pendingOutgoing: asInt(res['pendingOutgoing']),
      activeAsMentor: asInt(res['activeAsMentor']),
      activeAsMentee: asInt(res['activeAsMentee']),
      menteesHelped: asInt(res['menteesHelped']),
    );
  }

  /// Every pairing the caller is in, either side, newest first.
  Future<List<Pairing>> pairings() async {
    final res = await _get('/mentorship/mine', {'limit': 50});
    return [for (final m in asMaps(res['data'])) pairingFrom(m)];
  }

  Future<Pairing> pairing(String id) async => pairingFrom(await _get('/mentorship/$id'));

  /// Requests the caller sent.
  Future<List<MentoringRequest>> requestsSent() async {
    final res = await _get('/mentorship/requests/mine', {'limit': 50});
    return [for (final r in asMaps(res['data'])) requestFrom(r)];
  }

  Future<void> withdrawRequest(String id) => _send('POST', '/mentorship/requests/$id/withdraw');

  /// Requests waiting on the caller as a mentor (and answered ones, newest first).
  Future<List<MentoringRequest>> requestsReceived() async {
    final res = await _get('/mentorship/requests/incoming', {'limit': 50});
    return [for (final r in asMaps(res['data'])) requestFrom(r)];
  }

  /// A mentor answers a request. Accepting pairs them (a note and a cadence may ride along);
  /// declining sends the note back as written.
  Future<void> respondToRequest(String id, {required bool accept, String? note, String? cadence}) =>
      _send('POST', '/mentorship/requests/$id/${accept ? 'accept' : 'decline'}', {
        if (note != null && note.trim().isNotEmpty) 'responseNote': note.trim(),
        if (accept && cadence != null) 'cadence': cadence,
      });

  /// The next few sessions across every live pairing.
  Future<List<PairingSession>> upcomingSessions() async => [
    for (final s in await _getList('/mentorship/sessions/upcoming')) sessionFrom(s),
  ];

  /// The member's quota: pending requests and live pairings against the plan's limits.
  Future<MentoringQuota> quota() async {
    final res = await _get('/mentorship/mentees/me/access');
    return MentoringQuota(
      pending: asInt(res['pendingRequests']),
      pendingLimit: (res['pendingRequestLimit'] as num?)?.toInt(),
      active: asInt(res['activeMentorships']),
      activeLimit: (res['activeMentorshipLimit'] as num?)?.toInt(),
      canRequest: res['canRequest'] != false,
      tier: res['tier'] as String?,
    );
  }

  /// The mentors the member bookmarked, newest save first.
  Future<List<SavedMentor>> savedMentors() async {
    final res = await _get('/mentorship/mentors/saved', {'limit': 50});
    return [
      for (final m in asMaps(res['data']))
        SavedMentor(
          mentorProfileId: m['id'] as String,
          person: personFrom(m['user'] as Map<String, dynamic>?, subline: _nonEmpty(m['headline'])),
          headline: _nonEmpty(m['headline']),
          rating: (m['rating'] as num?)?.toDouble() ?? 0,
          ratingCount: asInt(m['ratingCount']),
          openSlots: asInt(m['openSlots']),
          city: _nonEmpty(m['city']),
        ),
    ];
  }

  Future<void> unsaveMentor(String mentorProfileId) => _send('DELETE', '/mentorship/mentors/$mentorProfileId/save');

  Future<void> saveMentor(String mentorProfileId) => _send('POST', '/mentorship/mentors/$mentorProfileId/save');

  /// Concerns the member raised, and where each one got to.
  Future<List<MentoringConcern>> concerns() async => [
    for (final c in await _getList('/mentorship/concerns/mine'))
      MentoringConcern(
        id: c['id'] as String,
        category: ConcernCategory.fromApi(c['category'] as String?),
        detail: c['detail'] as String? ?? '',
        status: c['status'] as String? ?? 'OPEN',
        createdAt: parseDate(c['createdAt']) ?? mentoringNow(),
        urgent: c['urgent'] == true,
        outcomeNote: _nonEmpty(c['outcomeNote']),
        handledAt: parseDate(c['handledAt']),
        mentorshipId: c['mentorshipId'] as String?,
        groupSessionId: c['groupSessionId'] as String?,
      ),
  ];

  /// Everything on the member's calendar between [from] and [to] (at most 62 days):
  /// pairing sessions, paid calls and the group sessions they hold a seat at.
  Future<List<CalendarItem>> calendar(DateTime from, DateTime to) async {
    final query = {'from': from.toUtc().toIso8601String(), 'to': to.toUtc().toIso8601String()};
    final results = await Future.wait([
      _getList('/mentorship/sessions', query),
      _getList('/mentor-services/bookings/range', query),
      _getList('/mentorship/group-sessions/mine/upcoming'),
    ]);
    final items = <CalendarItem>[];
    for (final s in results[0]) {
      final who = s['counterpart'] as Map<String, dynamic>?;
      items.add(
        CalendarItem(
          kind: CalendarKind.session,
          id: s['id'] as String,
          title: _nonEmpty(s['agenda']) ?? 'Mentoring session',
          at: parseDate(s['scheduledAt']) ?? from,
          durationMin: asInt(s['durationMin'], 30),
          status: s['status'] as String? ?? 'SCHEDULED',
          mentorshipId: s['mentorshipId'] as String?,
          counterpartName: who == null ? null : personFrom(who).name,
          meetingLink: _nonEmpty(s['meetingLink']),
          mode: s['mode'] as String?,
        ),
      );
    }
    for (final b in results[1]) {
      final who = b['counterpart'] as Map<String, dynamic>?;
      items.add(
        CalendarItem(
          kind: CalendarKind.booking,
          id: b['id'] as String,
          title: b['title'] as String? ?? 'Paid session',
          at: parseDate(b['scheduledAt']) ?? from,
          durationMin: asInt(b['durationMin'], 30),
          status: b['status'] as String? ?? 'SCHEDULED',
          purchaseId: b['purchaseId'] as String?,
          counterpartName: who == null ? null : personFrom(who).name,
          meetingLink: _nonEmpty(b['meetingLink']),
          mode: b['mode'] as String?,
        ),
      );
    }
    for (final g in results[2]) {
      final at = parseDate(g['scheduledAt']);
      if (at == null || at.isBefore(from) || !at.isBefore(to)) continue;
      final host = g['host'] as Map<String, dynamic>?;
      items.add(
        CalendarItem(
          kind: CalendarKind.group,
          id: g['id'] as String,
          title: g['title'] as String? ?? 'Group session',
          at: at,
          durationMin: asInt(g['durationMin'], 60),
          status: g['status'] as String? ?? 'SCHEDULED',
          counterpartName: host == null ? null : personFrom(host).name,
          mode: g['mode'] as String?,
        ),
      );
    }
    items.sort((a, b) => a.at.compareTo(b.at));
    return items;
  }

  /// The caller's purchases and session requests (buyer side).
  Future<List<ServicePurchase>> purchases({bool seller = false, String? scope}) async {
    final res = await _get('/mentor-services/purchases/mine', {
      'limit': 50,
      if (seller) 'side': 'SELLER',
      'scope': ?scope,
    });
    return [for (final p in asMaps(res['data'])) purchaseFrom(p)];
  }

  Future<ServicePurchase> purchase(String id) async => purchaseFrom(await _get('/mentor-services/purchases/$id'));

  /// Seats the caller holds at upcoming group sessions.
  Future<List<GroupSession>> groupSeats() async {
    final res = await _getList('/mentorship/group-sessions/mine/upcoming');
    return [for (final g in res) groupFrom(g)];
  }

  /// Goals across every live pairing.
  Future<List<PairingGoal>> goalsAcross() async {
    final res = await _getList('/mentorship/goals/mine');
    return [for (final g in res) goalFrom(g)];
  }

  Future<List<MentoringCertificate>> certificates() async {
    final res = await _getList('/mentorship/mine/certificates');
    return [
      for (final c in res)
        MentoringCertificate(
          id: c['id'] as String,
          certificateId: c['certificateId'] as String? ?? '',
          title: c['title'] as String? ?? 'Mentoring certificate',
          issuedAt: parseDate(c['issuedAt']) ?? parseDate(c['completedAt']) ?? mentoringNow(),
          kind: c['kind'] as String?,
          counterpartName: c['counterpartName'] as String?,
          programName: c['programName'] as String?,
          sessionsCount: asInt(c['sessionsCount']),
          hours: (c['hours'] as num?)?.toDouble() ?? 0,
          mentorshipId: c['mentorshipId'] as String?,
          goalsAchieved: asInt(c['goalsAchieved']),
        ),
    ];
  }

  /// Programme and plan terms the caller asked for or holds (buyer side).
  Future<List<PlanTerm>> planTerms() async {
    final res = await _getList('/mentor-plans/subscriptions/mine');
    return [for (final s in res) planTermFrom(s)];
  }

  /// Withdraws a programme asked for, or stops a plan renewing.
  Future<void> cancelPlanTerm(String id, {String? reason}) => _send('POST', '/mentor-plans/subscriptions/$id/cancel', {
    if (reason != null && reason.isNotEmpty) 'reason': reason,
  });

  /// Pays for a programme the mentor accepted. A term the API completes itself (nothing to pay, or a gateway in
  /// simulated mode) is completed here; a real PayU payment continues on the website, which runs the gateway's
  /// return leg: the screen has shown the API's quote (price, member discount, tax, total) before this is called.
  Future<PaymentOutcome> payPlanTerm(PlanTerm term) async {
    if (term.totalPaisa > 0 && await paymentsLive()) {
      return const PaymentOutcome(completed: false, sitePath: '/mentorship/my?tab=purchases');
    }
    final res = await _send('POST', '/mentor-plans/subscriptions/${term.id}/pay') as Map<String, dynamic>?;
    if (res?['devActivated'] == true) {
      return PaymentOutcome(
        completed: true,
        message: 'Paid. Your programme has started.',
        mentorshipId: res?['mentorshipId'] as String?,
      );
    }
    return const PaymentOutcome(completed: false, sitePath: '/mentorship/my?tab=purchases');
  }

  /// The member's mentoring intent; null until they have written one.
  Future<MenteeIntent?> menteeIntent() async {
    final res = await _get('/mentorship/mentees/me');
    if (res['careerStage'] == null) return null;
    return MenteeIntent(
      careerStage: res['careerStage'] as String,
      focusAreas: asStrings(res['focusAreas']),
      goalSummary: res['goalSummary'] as String?,
      preferredModes: asStrings(res['preferredModes']),
      cadence: res['cadence'] as String?,
      timezone: res['timezone'] as String? ?? 'Asia/Kolkata',
      discoverable: res['discoverable'] != false,
    );
  }

  Future<void> saveMenteeIntent(MenteeIntent intent) => _send('PUT', '/mentorship/mentees/me', intent.toJson());

  /// The competency domains a member can pick from, most-listed first.
  Future<List<String>> focusOptions() async {
    final res = await _get('/mentorship/mentors/facets');
    return [
      for (final c in asMaps(res['competencies']))
        if (c['label'] is String) c['label'] as String,
    ];
  }

  // --- Bookings --------------------------------------------------------------

  /// Pulls a session request back before it is paid.
  Future<void> withdrawPurchaseRequest(String id) => _send('POST', '/mentor-services/purchases/$id/withdraw');

  /// Takes the time the mentor set. A free session (or one a credit covers) is booked.
  Future<void> acceptTime(String id, {bool useCredit = false}) =>
      _send('POST', '/mentor-services/purchases/$id/accept-time', {'useCredit': useCredit});

  /// Sends a set time back: "ask another time".
  Future<void> declineTime(String id, String note) =>
      _send('POST', '/mentor-services/purchases/$id/decline-time', {'note': note.trim()});

  /// Pays for an accepted session, as the screen's [quote] worked it out: in the app when nothing is left to pay
  /// (a free session, or a session credit that covers it) or the gateway is simulated; on the website otherwise,
  /// which runs PayU's return leg.
  Future<PaymentOutcome> pay(ServicePurchase p, {required PriceQuote quote}) async {
    final site = '/mentorship/my?tab=purchases&purchase=${p.id}';
    if (quote.chargedPaisa > 0 && await paymentsLive()) {
      return PaymentOutcome(completed: false, sitePath: site);
    }
    final res =
        await _send('POST', '/mentor-services/purchases/${p.id}/pay', {'useCredit': quote.creditPaisa > 0})
            as Map<String, dynamic>?;
    if (res?['devActivated'] == true) {
      return PaymentOutcome(
        completed: true,
        message: quote.creditPaisa > 0 && quote.chargedPaisa == 0
            ? 'Paid with a session credit. The session is booked.'
            : 'The session is booked.',
      );
    }
    return PaymentOutcome(completed: false, sitePath: site);
  }

  Future<void> cancelBooking(String id, String reason) =>
      _send('POST', '/mentor-services/purchases/$id/cancel', {'reason': reason.trim()});

  Future<void> proposeReschedule(String id, DateTime at, {String? note}) => _send(
    'POST',
    '/mentor-services/purchases/$id/reschedule',
    {'scheduledAt': at.toUtc().toIso8601String(), if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
  );

  Future<void> answerReschedule(String id, {required bool accept, String? reason}) => accept
      ? _send('POST', '/mentor-services/purchases/$id/reschedule/accept')
      : _send('POST', '/mentor-services/purchases/$id/reschedule/decline', {
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        });

  Future<void> reviewPurchase(String id, {required int rating, String? comment, bool anonymous = false}) =>
      _send('POST', '/mentor-services/purchases/$id/review', {
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
        'anonymous': anonymous,
      });

  /// The thread "Message" opens for a booking: a consultation's own, else the
  /// pair's mentoring thread.
  Future<String?> purchaseConversation(String id) async {
    final res = await _send('POST', '/mentor-services/purchases/$id/conversation') as Map<String, dynamic>?;
    return res?['conversationId'] as String?;
  }

  // --- A pairing ---------------------------------------------------------------

  Future<List<PairingSession>> sessions(String mentorshipId) async => [
    for (final s in await _getList('/mentorship/$mentorshipId/sessions')) sessionFrom(s),
  ];

  Future<List<PairingGoal>> goals(String mentorshipId) async => [
    for (final g in await _getList('/mentorship/$mentorshipId/goals')) goalFrom(g),
  ];

  Future<List<PairingTask>> tasks(String mentorshipId) async => [
    for (final t in await _getList('/mentorship/$mentorshipId/tasks'))
      PairingTask(
        id: t['id'] as String,
        title: t['title'] as String? ?? '',
        status: TaskStatus.fromApi(t['status'] as String?),
        detail: t['detail'] as String?,
        dueAt: parseDate(t['dueAt']),
        isMine: t['isMine'] == true,
        overdue: t['overdue'] == true,
      ),
  ];

  /// The viewer's own feedback on the pairing; null when they have left none.
  Future<PairingFeedback?> myFeedback(String mentorshipId) async {
    final res = await _get('/mentorship/$mentorshipId/feedback/mine');
    if (res['rating'] == null) return null;
    return PairingFeedback(
      rating: asInt(res['rating']),
      comment: res['comment'] as String?,
      wouldRecommend: res['wouldRecommend'] as bool?,
      createdAt: parseDate(res['createdAt']),
    );
  }

  /// A mentee asks for a time (the mentor approves it); a mentor books it.
  Future<PairingSession> scheduleSession(
    String mentorshipId, {
    required DateTime at,
    required int durationMin,
    required String mode,
    String? agenda,
    String? planStepId,
  }) async {
    final res = await _send('POST', '/mentorship/$mentorshipId/sessions', {
      'scheduledAt': at.toUtc().toIso8601String(),
      'durationMin': durationMin,
      'mode': mode,
      if (agenda != null && agenda.trim().isNotEmpty) 'agenda': agenda.trim(),
      if (planStepId != null && planStepId.isNotEmpty) 'planStepId': planStepId,
    });
    return sessionFrom(res as Map<String, dynamic>);
  }

  /// Moves a scheduled session (either side), or sets another time on a request (the mentor).
  Future<void> rescheduleSession(
    String mentorshipId,
    String sessionId, {
    required DateTime at,
    required int durationMin,
    required String mode,
    String? agenda,
  }) => _send('PATCH', '/mentorship/$mentorshipId/sessions/$sessionId', {
    'scheduledAt': at.toUtc().toIso8601String(),
    'durationMin': durationMin,
    'mode': mode,
    if (agenda != null && agenda.trim().isNotEmpty) 'agenda': agenda.trim(),
  });

  /// The mentor sets (or clears) the meeting link for one session.
  Future<void> setSessionLink(String mentorshipId, String sessionId, String? link) =>
      _send('PATCH', '/mentorship/$mentorshipId/sessions/$sessionId/meeting-link', {'meetingLink': link?.trim()});

  Future<void> approveSession(String mentorshipId, String sessionId) =>
      _send('POST', '/mentorship/$mentorshipId/sessions/$sessionId/approve');

  Future<void> cancelSession(String mentorshipId, String sessionId, String reason) =>
      _send('POST', '/mentorship/$mentorshipId/sessions/$sessionId/cancel', {'reason': reason.trim()});

  /// The mentor marks a session held; the counters move on this alone.
  Future<void> completeSession(String mentorshipId, String sessionId, {int? durationMin, String? note}) => _send(
    'POST',
    '/mentorship/$mentorshipId/sessions/$sessionId/complete',
    {'durationMin': ?durationMin, if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
  );

  Future<PairingGoal> addGoal(
    String mentorshipId, {
    required String title,
    String? detail,
    DateTime? targetDate,
  }) async {
    final res = await _send('POST', '/mentorship/$mentorshipId/goals', {
      'title': title.trim(),
      if (detail != null && detail.trim().isNotEmpty) 'detail': detail.trim(),
      if (targetDate != null) 'targetDate': _day(targetDate),
    });
    return goalFrom(res as Map<String, dynamic>);
  }

  Future<void> setGoalStatus(String mentorshipId, String goalId, GoalStatus status) =>
      _send('POST', '/mentorship/$mentorshipId/goals/$goalId/status', {'status': status.api});

  Future<void> setGoalProgress(String mentorshipId, String goalId, int progress) =>
      _send('POST', '/mentorship/$mentorshipId/goals/$goalId/progress', {'progress': progress});

  Future<void> removeGoal(String mentorshipId, String goalId) =>
      _send('DELETE', '/mentorship/$mentorshipId/goals/$goalId');

  Future<void> addTask(String mentorshipId, {required String title, DateTime? dueAt}) => _send(
    'POST',
    '/mentorship/$mentorshipId/tasks',
    {'title': title.trim(), if (dueAt != null) 'dueAt': dueAt.toUtc().toIso8601String()},
  );

  Future<void> setTaskStatus(String mentorshipId, String taskId, TaskStatus status) =>
      _send('PATCH', '/mentorship/$mentorshipId/tasks/$taskId', {'status': status.api});

  Future<void> deleteTask(String mentorshipId, String taskId) =>
      _send('DELETE', '/mentorship/$mentorshipId/tasks/$taskId');

  /// Pause, resume, complete or end a pairing early (with a reason both see).
  Future<Pairing> updatePairing(String mentorshipId, PairingStatus status, {String? endedReason}) async {
    final res = await _send('PATCH', '/mentorship/$mentorshipId', {
      'status': switch (status) {
        PairingStatus.active => 'ACTIVE',
        PairingStatus.paused => 'PAUSED',
        PairingStatus.completed => 'COMPLETED',
        PairingStatus.endedEarly => 'ENDED_EARLY',
      },
      if (endedReason != null && endedReason.trim().isNotEmpty) 'endedReason': endedReason.trim(),
    });
    return pairingFrom(res as Map<String, dynamic>);
  }

  Future<void> submitFeedback(String mentorshipId, {required int rating, String? comment, bool? wouldRecommend}) =>
      _send('POST', '/mentorship/$mentorshipId/feedback', {
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
        'wouldRecommend': ?wouldRecommend,
      });

  Future<void> raiseConcern(
    String mentorshipId, {
    required ConcernCategory category,
    required String detail,
    bool urgent = false,
  }) => _send('POST', '/mentorship/$mentorshipId/concerns', {
    'category': category.api,
    'detail': detail.trim(),
    'urgent': urgent,
  });

  /// The pairing's thread, opened (or reused) through the record.
  Future<String?> pairingConversation(String mentorshipId) async {
    final res = await _send('POST', '/mentorship/$mentorshipId/conversation') as Map<String, dynamic>?;
    return res?['conversationId'] as String?;
  }

  /// Start times a session of [durationMin] can take with this mentor, the
  /// next two weeks, their weekly hours less what is booked.
  Future<List<Slot>> slots(String mentorProfileId, {int durationMin = 60}) async {
    final res = await _get('/mentorship/mentors/$mentorProfileId/slots', {'durationMin': durationMin, 'days': 14});
    return [
      for (final s in asStrings(res['slots']))
        if (DateTime.tryParse(s) != null) Slot(DateTime.parse(s)),
    ];
  }

  /// How this mentor meets (`preferredModes`); empty means any.
  Future<List<String>> mentorModes(String mentorProfileId) async {
    final res = await _get('/mentorship/mentors/$mentorProfileId');
    return asStrings(res['preferredModes']);
  }

  /// The pairing's timeline, newest last as the API sends it: shared entries and the caller's own private notes.
  Future<List<TimelineEntry>> timeline(String mentorshipId) async => [
    for (final e in await _getList('/mentorship/$mentorshipId/timeline'))
      TimelineEntry(
        id: e['id'] as String,
        type: e['type'] as String? ?? '',
        createdAt: parseDate(e['createdAt']) ?? mentoringNow(),
        note: _nonEmpty(e['note']),
        shared: (e['visibility'] as String? ?? 'SHARED') == 'SHARED',
        actorName: switch (e['actor']) {
          final Map<String, dynamic> a => '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.trim(),
          _ => null,
        },
      ),
  ];

  /// A note on the timeline: shared with the other person, or kept to the author.
  Future<void> addNote(String mentorshipId, String note, {bool privateToMe = false}) =>
      _send('POST', '/mentorship/$mentorshipId/notes', {'note': note.trim(), if (privateToMe) 'privateToMe': true});

  /// Pause or resume rhythm: how often the pair aims to meet.
  Future<void> setCadence(String mentorshipId, String cadence) =>
      _send('PATCH', '/mentorship/$mentorshipId', {'cadence': cadence});

  /// What the pair shared inside the mentorship (links and files).
  Future<List<SharedResource>> resources(String mentorshipId) async => [
    for (final r in await _getList('/mentorship/resources', {'mentorshipId': mentorshipId}))
      SharedResource(
        id: r['id'] as String,
        title: r['title'] as String? ?? '',
        kind: r['kind'] as String? ?? 'OTHER',
        addedByName: switch (r['addedBy']) {
          final Map<String, dynamic> a => '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.trim(),
          _ => '',
        },
        createdAt: parseDate(r['createdAt']) ?? mentoringNow(),
        note: _nonEmpty(r['note']),
        url: _nonEmpty(r['url']),
        fileName: _nonEmpty(r['fileName']),
        fileSize: (r['fileSize'] as num?)?.toInt(),
        canRemove: r['canRemove'] == true,
      ),
  ];

  /// Shares a link with the other person (the website's "Add" takes files too; the app takes links).
  Future<void> addResourceLink(
    String mentorshipId, {
    required String title,
    required String url,
    String kind = 'OTHER',
    String? note,
  }) => _send('POST', '/mentorship/resources', {
    'mentorshipId': mentorshipId,
    'title': title.trim(),
    'kind': kind,
    'url': url.trim(),
    if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
  });

  /// Uploads a file for a shared resource (`POST /uploads?purpose=mentorship-resource`: a PDF or an image, 10 MB)
  /// and shares it. The API stores the file's basename, not its URL.
  Future<void> addResourceFile(
    String mentorshipId, {
    required Uint8List bytes,
    required String name,
    String? mimeType,
    required String title,
    String kind = 'OTHER',
    String? note,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: name,
          contentType: mimeType == null ? null : DioMediaType.parse(mimeType),
        ),
      });
      final res = await api.dio.post<Map<String, dynamic>>(
        '/uploads',
        data: form,
        queryParameters: {'purpose': 'mentorship-resource'},
      );
      final d = res.data ?? const {};
      final url = d['url'] as String? ?? '';
      await _send('POST', '/mentorship/resources', {
        'mentorshipId': mentorshipId,
        'title': title.trim(),
        'kind': kind,
        'uploadId': url.split('/').last,
        'fileName': d['name'] as String? ?? name,
        'fileSize': (d['size'] as num?)?.toInt() ?? bytes.length,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<void> removeResource(String id) => _send('DELETE', '/mentorship/resources/$id');

  /// A stored file's bytes. Private uploads are read with the session's token, never by a browser link.
  Future<Uint8List> downloadBytes(String url) async {
    try {
      final res = await api.dio.get<List<int>>(
        AppConfig.absoluteUrl(url, apiBase: api.dio.options.baseUrl)!,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(res.data ?? const []);
    } on DioException catch (e) {
      throw _errorOfBytes(e);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  /// A refusal to a bytes download arrives as bytes: read the API's JSON sentence out of them.
  ApiError _errorOfBytes(DioException e) {
    final data = e.response?.data;
    if (data is List<int>) {
      try {
        final decoded = jsonDecode(utf8.decode(data));
        return ApiError.from(
          DioException(
            requestOptions: e.requestOptions,
            type: e.type,
            response: Response<dynamic>(
              requestOptions: e.requestOptions,
              statusCode: e.response?.statusCode,
              data: decoded,
            ),
          ),
        );
      } catch (_) {
        // not JSON: the generic sentence will do
      }
    }
    return ApiError.from(e);
  }

  /// Terms the caller SOLD (the mentor's side): programmes and plans asked of or bought from them.
  Future<List<PlanTerm>> soldTerms() async {
    final res = await _getList('/mentor-plans/subscriptions/sold');
    return [for (final s in res) planTermFrom(s)];
  }

  /// Notes and the recording link of one session. Either person may write them.
  Future<void> saveSessionRecord(String mentorshipId, String sessionId, {String? notes, String? recordingUrl}) =>
      _send('PATCH', '/mentorship/$mentorshipId/sessions/$sessionId/record', {
        'notes': ?notes,
        if (recordingUrl != null) 'recordingUrl': recordingUrl.trim().isEmpty ? null : recordingUrl.trim(),
      });

  /// Asks for a summary of the notes (on request only: the site never does it by itself).
  Future<SessionRecord> summariseSession(String mentorshipId, String sessionId) async {
    final res = await _send('POST', '/mentorship/$mentorshipId/sessions/$sessionId/summarise') as Map<String, dynamic>?;
    return SessionRecord(summary: _nonEmpty(res?['summary']), unavailable: res?['unavailable'] == true);
  }

  /// Raises a support request about a record (a pairing, a purchase), the way the website's "Contact ICR support" does.
  Future<void> raiseSupportTicket({
    required String subject,
    required String body,
    String category = 'MENTORSHIP',
    String contextType = 'MENTORSHIP',
    String? contextId,
  }) => _send('POST', '/support/tickets', {
    'subject': subject.trim(),
    'category': category,
    'body': body.trim(),
    'contextType': contextType,
    'contextId': ?contextId,
  });

  // --- Group sessions ----------------------------------------------------------

  Future<GroupSession> groupSession(String id) async => groupFrom(await _get('/mentorship/group-sessions/$id'));

  /// A free seat (or the waitlist once it fills).
  Future<void> registerGroup(String id, {String? question}) => _send(
    'POST',
    '/mentorship/group-sessions/$id/register',
    {if (question != null && question.trim().isNotEmpty) 'question': question.trim()},
  );

  Future<void> leaveGroup(String id) => _send('DELETE', '/mentorship/group-sessions/$id/register');

  Future<String?> groupConversation(String id) async {
    final res = await _send('POST', '/mentorship/group-sessions/$id/conversation') as Map<String, dynamic>?;
    return res?['conversationId'] as String?;
  }

  /// A page of group sessions: the public list, or the ones the caller holds a seat at ([registered]).
  Future<PageOf<GroupSession>> groupSessions({
    int page = 1,
    int limit = 12,
    String? mode,
    bool availableOnly = false,
    bool registered = false,
    String? search,
    String? programId,
    String? status,
  }) async {
    final res = await _get('/mentorship/group-sessions', {
      'page': page,
      'limit': limit,
      'mode': ?mode,
      if (availableOnly) 'availableOnly': true,
      if (registered) 'registered': true,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      'programId': ?programId,
      'status': ?status,
    });
    final meta = res['meta'] as Map<String, dynamic>? ?? const {};
    return PageOf(
      [for (final g in asMaps(res['data'])) groupFrom(g)],
      hasNext: meta['hasNext'] == true,
      total: asInt(meta['total']),
    );
  }

  /// Buys a seat at a paid session: in the app when the API completes it (nothing to pay after the member
  /// discount, or a simulated gateway), on the website when real money moves.
  Future<PaymentOutcome> buyGroupSeat(GroupSession s, {String? question, required PriceQuote quote}) async {
    final site = '/mentorship/groups/${s.id}';
    if (quote.chargedPaisa > 0 && await paymentsLive()) return PaymentOutcome(completed: false, sitePath: site);
    final res =
        await _send('POST', '/mentorship/group-sessions/${s.id}/seat/checkout', {
              if (question != null && question.trim().isNotEmpty) 'question': question.trim(),
            })
            as Map<String, dynamic>?;
    if (res?['devActivated'] == true) return const PaymentOutcome(completed: true, message: 'Your seat is booked.');
    return PaymentOutcome(completed: false, sitePath: site);
  }

  /// The caller's own rating of a finished session; null when they left none.
  Future<GroupFeedback?> myGroupFeedback(String id) async {
    final res = await _get('/mentorship/group-sessions/$id/feedback/mine');
    if (res['rating'] == null) return null;
    return GroupFeedback(
      rating: asInt(res['rating']),
      comment: _nonEmpty(res['comment']),
      // The API names the author unless they hid it.
      anonymous: res['authorName'] == null,
    );
  }

  Future<void> rateGroupSession(String id, {required int rating, String? comment, bool anonymous = false}) =>
      _send('POST', '/mentorship/group-sessions/$id/feedback', {
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
        if (anonymous) 'anonymous': true,
      });

  Future<void> raiseGroupConcern(
    String id, {
    required ConcernCategory category,
    required String detail,
    bool urgent = false,
  }) => _send('POST', '/mentorship/group-sessions/$id/concerns', {
    'category': category.api,
    'detail': detail.trim(),
    'urgent': urgent,
  });

  /// A buyer says something went wrong with a purchase (it lands in ICR's queue and the seller reads it).
  Future<void> reportPurchaseIssue(String id, String note) =>
      _send('POST', '/mentor-services/purchases/$id/report-issue', {'note': note.trim()});

  Future<void> withdrawPurchaseIssue(String id) => _send('POST', '/mentor-services/purchases/$id/withdraw-issue');

  // --- Programmes --------------------------------------------------------------

  /// Programmes, newest first; [status] is OPEN (applications open), RUNNING, ... or null for all.
  Future<List<Programme>> programmes({String? status}) async {
    final res = await _get('/mentorship/programmes', {'limit': 30, 'status': ?status});
    return [for (final p in asMaps(res['data'])) programmeFrom(p)];
  }

  Future<Programme> programme(String slug) async => programmeFrom(await _get('/mentorship/programmes/$slug'));

  /// Applies to a programme on one side. The API's `PROGRAMME_NEEDS_*` codes
  /// ride on the [ApiError] it throws.
  Future<void> enrol(String slug, ProgrammeRole role, {String? motivation}) => _send(
    'POST',
    '/mentorship/programmes/$slug/enrol',
    {'role': role.api, if (motivation != null && motivation.trim().isNotEmpty) 'motivation': motivation.trim()},
  );

  Future<void> withdrawEnrolment(String enrolmentId) =>
      _send('POST', '/mentorship/programmes/enrolments/$enrolmentId/withdraw');

  Future<List<ProgrammeEnrolment>> myProgrammes() async => [
    for (final e in await _getList('/mentorship/programmes/mine')) enrolmentFrom(e),
  ];

  // --- Payments ------------------------------------------------------------------

  bool? _live;

  /// Whether a paid checkout goes through the real gateway (`GET /payments/mode`).
  Future<bool> paymentsLive() async {
    if (_live != null) return _live!;
    try {
      final res = await _get('/payments/mode');
      return _live = res['mode'] == 'live';
    } catch (_) {
      return true; // when in doubt, money goes through the website
    }
  }

  /// What the member's plans take off sessions and plans, and their session credits.
  Future<MemberDiscounts> memberDiscounts() async {
    final res = await _get('/mentor-services/member-discounts');
    final services = res['services'] as Map<String, dynamic>? ?? const {};
    final plans = res['plans'] as Map<String, dynamic>? ?? const {};
    final credits = res['sessionCredits'] as Map<String, dynamic>?;
    return MemberDiscounts(
      servicesBps: asInt(services['bps']),
      servicesPlan: _nonEmpty(services['planName']),
      plansBps: asInt(plans['bps']),
      plansPlan: _nonEmpty(plans['planName']),
      credits: credits == null
          ? null
          : SessionCredits(
              perPeriod: asInt(credits['perPeriod']),
              remaining: asInt(credits['remaining']),
              capPaisa: asInt(credits['capPaisa']),
              planName: _nonEmpty(credits['planName']),
              resetsAt: parseDate(credits['resetsAt']),
            ),
    );
  }

  /// A plan session credit is left and pays the whole price.
  Future<bool> creditCovers(int paisa) async {
    try {
      final d = await memberDiscounts();
      final credits = d.credits;
      return credits != null && credits.remaining > 0 && credits.capPaisa >= paisa;
    } catch (_) {
      return false;
    }
  }

  // --- mapping -------------------------------------------------------------------

  FeedPicture? picture(String? path) {
    final url = AppConfig.absoluteUrl(path, apiBase: api.dio.options.baseUrl);
    return url == null ? null : FeedPicture.network(url);
  }

  Person personFrom(Map<String, dynamic>? json, {String? subline}) {
    final j = json ?? const {};
    final company = j['company'];
    return Person(
      id: j['id'] as String? ?? '',
      firstName: j['firstName'] as String? ?? '',
      lastName: j['lastName'] as String? ?? '',
      photo: picture(j['avatarUrl'] as String?),
      subline:
          subline ??
          _nonEmpty(j['headline']) ??
          _nonEmpty(j['designation']) ??
          _nonEmpty(j['title']) ??
          (company is Map ? _nonEmpty(company['name']) : null) ??
          _nonEmpty(j['companyName']),
    );
  }

  Pairing pairingFrom(Map<String, dynamic> m) {
    final mentor = m['mentor'] as Map<String, dynamic>? ?? const {};
    final mentee = m['mentee'] as Map<String, dynamic>? ?? const {};
    return Pairing(
      id: m['id'] as String,
      status: PairingStatus.fromApi(m['status'] as String?),
      viewerIsMentor: m['viewerSide'] == 'MENTOR',
      mentor: personFrom(mentor),
      mentorProfileId: mentor['mentorProfileId'] as String? ?? '',
      mentee: personFrom(mentee),
      startedAt: parseDate(m['startedAt']) ?? mentoringNow(),
      cadence: m['cadence'] as String?,
      completedAt: parseDate(m['completedAt']),
      endedReason: m['endedReason'] as String?,
      sessionsCount: asInt(m['sessionsCount']),
      totalMinutes: asInt(m['totalMinutes']),
      conversationId: m['conversationId'] as String?,
      counterpartPhone: m['counterpartPhone'] as String?,
      careerStage: mentee['careerStage'] as String?,
    );
  }

  MentoringRequest requestFrom(Map<String, dynamic> r) {
    final mentor = r['mentor'] as Map<String, dynamic>? ?? const {};
    final mentee = r['mentee'] as Map<String, dynamic>? ?? const {};
    return MentoringRequest(
      id: r['id'] as String,
      status: RequestStatus.fromApi(r['status'] as String?),
      message: r['message'] as String? ?? '',
      createdAt: parseDate(r['createdAt']) ?? mentoringNow(),
      mentor: personFrom(mentor),
      mentorProfileId: mentor['mentorProfileId'] as String? ?? '',
      mentee: personFrom(mentee),
      focusAreas: asStrings(r['focusAreas']),
      responseNote: r['responseNote'] as String?,
      expiresAt: parseDate(r['expiresAt']),
      matchScore: (r['matchScore'] as num?)?.toInt(),
      careerStage: mentee['careerStage'] as String?,
      signals: [
        for (final s in asMaps(r['signals']))
          if (s['label'] is String) s['label'] as String,
      ],
      respondedAt: parseDate(r['respondedAt']),
    );
  }

  PairingSession sessionFrom(Map<String, dynamic> s) {
    final counterpart = s['counterpart'] as Map<String, dynamic>?;
    return PairingSession(
      id: s['id'] as String,
      mentorshipId: s['mentorshipId'] as String? ?? '',
      scheduledAt: parseDate(s['scheduledAt']) ?? mentoringNow(),
      durationMin: asInt(s['durationMin'], 30),
      mode: s['mode'] as String? ?? 'VIDEO',
      status: SessionStatus.fromApi(s['status'] as String?),
      agenda: s['agenda'] as String?,
      meetingLink: _nonEmpty(s['meetingLink']),
      cancelReason: s['cancelReason'] as String?,
      createdById: (s['createdBy'] as Map<String, dynamic>?)?['id'] as String?,
      notes: s['notes'] as String?,
      summary: s['summary'] as String?,
      recordingUrl: _nonEmpty(s['recordingUrl']),
      counterpart: counterpart == null ? null : personFrom(counterpart),
      viewerIsMentor: switch (s['side']) {
        'MENTOR' => true,
        'MENTEE' => false,
        _ => null,
      },
    );
  }

  PairingGoal goalFrom(Map<String, dynamic> g) {
    final by = g['createdBy'] as Map<String, dynamic>?;
    final other = g['counterpart'] as Map<String, dynamic>?;
    return PairingGoal(
      id: g['id'] as String,
      mentorshipId: g['mentorshipId'] as String? ?? '',
      title: g['title'] as String? ?? '',
      status: GoalStatus.fromApi(g['status'] as String?),
      progress: asInt(g['progress']),
      detail: g['detail'] as String?,
      targetDate: parseDate(g['targetDate']),
      createdByName: by == null ? null : '${by['firstName'] ?? ''} ${by['lastName'] ?? ''}'.trim(),
      counterpartName: other == null ? null : '${other['firstName'] ?? ''} ${other['lastName'] ?? ''}'.trim(),
    );
  }

  ServicePurchase purchaseFrom(Map<String, dynamic> p) {
    final b = p['booking'] as Map<String, dynamic>?;
    final r = p['request'] as Map<String, dynamic>?;
    final mentor = p['mentor'] as Map<String, dynamic>?;
    final buyer = p['buyer'] as Map<String, dynamic>?;
    return ServicePurchase(
      id: p['id'] as String,
      type: ServiceType.fromApi(p['type'] as String?),
      title: p['titleSnapshot'] as String? ?? '',
      pricePaisa: asInt(p['pricePaisa']),
      status: PurchaseStatus.fromApi(p['status'] as String?),
      createdAt: parseDate(p['createdAt']) ?? mentoringNow(),
      serviceId: p['serviceId'] as String?,
      sellerSide: p['side'] == 'SELLER',
      mentor: mentor == null ? null : personFrom(mentor),
      mentorProfileId: mentor?['mentorProfileId'] as String?,
      buyer: buyer == null ? null : personFrom(buyer),
      paidAt: parseDate(p['paidAt']),
      cancelReason: p['cancelReason'] as String?,
      booking: b == null
          ? null
          : PurchaseBooking(
              id: b['id'] as String? ?? '',
              scheduledAt: parseDate(b['scheduledAt']) ?? mentoringNow(),
              durationMin: asInt(b['durationMin'], 30),
              mode: b['mode'] as String? ?? 'VIDEO',
              status: b['status'] as String? ?? 'SCHEDULED',
              meetingLink: _nonEmpty(b['meetingLink']),
              proposedAt: parseDate(b['proposedScheduledAt']),
              proposedBy: b['proposedBy'] as String?,
              proposedNote: b['proposedNote'] as String?,
              rescheduleCount: asInt(b['rescheduleCount']),
            ),
      request: r == null
          ? null
          : PurchaseRequest(
              topic: r['topic'] as String? ?? '',
              preferredTimes: _nonEmpty(r['preferredTimes']),
              mode: r['mode'] as String?,
              durationMin: (r['durationMin'] as num?)?.toInt(),
              scheduledAt: parseDate(r['scheduledAt']),
              declineReason: r['declineReason'] as String?,
              payBy: parseDate(r['payBy']),
              listPricePaisa: asInt(r['listPricePaisa']),
              timeDeclineCount: asInt(r['timeDeclineCount']),
              timeDeclineNote: r['timeDeclineNote'] as String?,
            ),
      groupSessionId: p['groupSessionId'] as String?,
      groupSessionTitle: p['groupSessionTitle'] as String?,
      groupSessionAt: parseDate(p['groupSessionAt']),
      downloadUrl: p['downloadUrl'] as String?,
      fileName: p['fileName'] as String?,
      hasReview: p['hasReview'] == true,
      conversationId: p['conversationId'] as String?,
      netPaisa: (p['netPaisa'] as num?)?.toInt(),
    );
  }

  GroupSession groupFrom(Map<String, dynamic> g) {
    final host = g['host'] as Map<String, dynamic>? ?? const {};
    final attendees = g['attendees'];
    return GroupSession(
      id: g['id'] as String,
      title: g['title'] as String? ?? '',
      scheduledAt: parseDate(g['scheduledAt']) ?? mentoringNow(),
      durationMin: asInt(g['durationMin'], 60),
      mode: g['mode'] as String? ?? 'VIDEO',
      status: g['status'] as String? ?? 'SCHEDULED',
      host: personFrom(host),
      summary: g['summary'] as String?,
      cover: picture(g['coverUrl'] as String?),
      occurrenceCount: asInt(g['occurrenceCount'], 1),
      location: _nonEmpty(g['location']),
      capacity: (g['capacity'] as num?)?.toInt(),
      seatsTaken: asInt(g['seatsTaken']),
      seatsLeft: (g['seatsLeft'] as num?)?.toInt(),
      waitlistCount: asInt(g['waitlistCount']),
      myStatus: g['myStatus'] as String?,
      pricePaisa: (g['pricePaisa'] as num?)?.toInt(),
      programName: g['programName'] as String?,
      competencies: asStrings(g['competencies']),
      agendaHtml: g['agendaHtml'] as String?,
      meetingLink: _nonEmpty(g['meetingLink']),
      isHost: g['isHost'] == true,
      canRegister: g['canRegister'] == true,
      seatForSale: g['seatForSale'] == true,
      blockedReason: g['blockedReason'] as String?,
      conversationId: g['conversationId'] as String?,
      cancelReason: g['cancelReason'] as String?,
      attendeeCount: attendees is List ? attendees.length : null,
      occurrences: [
        for (final o in asMaps(g['occurrences']))
          GroupOccurrence(
            id: o['id'] as String? ?? '',
            seq: asInt(o['seq'], 1),
            scheduledAt: parseDate(o['scheduledAt']) ?? mentoringNow(),
            durationMin: asInt(o['durationMin'], 60),
            status: o['status'] as String? ?? 'SCHEDULED',
            title: _nonEmpty(o['title']),
          ),
      ],
      attendees: [
        for (final a in asMaps(attendees))
          GroupAttendee(
            id: a['id'] as String? ?? '',
            person: personFrom(a['user'] as Map<String, dynamic>?),
            status: a['status'] as String? ?? 'REGISTERED',
          ),
      ],
      rosterScope: g['rosterScope'] as String?,
      rosterHiddenCount: asInt(g['rosterHiddenCount']),
      timezone: g['timezone'] as String?,
      myPurchaseId: g['myPurchaseId'] as String?,
      myPurchaseStatus: g['myPurchaseStatus'] as String?,
      myPurchaseHasReview: g['myPurchaseHasReview'] == true,
    );
  }

  Programme programmeFrom(Map<String, dynamic> p) {
    final organiser = p['organiser'] as Map<String, dynamic>? ?? const {};
    return Programme(
      id: p['id'] as String,
      slug: p['slug'] as String? ?? p['id'] as String,
      name: p['name'] as String? ?? '',
      status: p['status'] as String? ?? 'OPEN',
      organiser: personFrom(organiser),
      summary: p['summary'] as String?,
      cover: picture(p['coverUrl'] as String?),
      applicationsCloseAt: parseDate(p['applicationsCloseAt']),
      startsAt: parseDate(p['startsAt']),
      endsAt: parseDate(p['endsAt']),
      menteeCapacity: (p['menteeCapacity'] as num?)?.toInt(),
      mentorCapacity: (p['mentorCapacity'] as num?)?.toInt(),
      focusAreas: asStrings(p['focusAreas']),
      competencies: asStrings(p['competencies']),
      enrolmentCount: asInt(p['enrolmentCount']),
      detailHtml: p['detailHtml'] as String?,
      menteesTaken: (p['menteesTaken'] as num?)?.toInt(),
      mentorsTaken: (p['mentorsTaken'] as num?)?.toInt(),
      myEnrolments: [for (final e in asMaps(p['myEnrolments'])) enrolmentFrom(e)],
    );
  }

  ProgrammeEnrolment enrolmentFrom(Map<String, dynamic> e) => ProgrammeEnrolment(
    id: e['id'] as String,
    programId: e['programId'] as String? ?? '',
    role: ProgrammeRole.fromApi(e['role'] as String?),
    status: e['status'] as String? ?? 'APPLIED',
    createdAt: parseDate(e['createdAt']),
    decisionNote: e['decisionNote'] as String?,
    programme: e['program'] is Map<String, dynamic> ? programmeFrom(e['program'] as Map<String, dynamic>) : null,
  );

  PlanTerm planTermFrom(Map<String, dynamic> s) {
    final other = s['counterpart'] as Map<String, dynamic>?;
    return PlanTerm(
      id: s['id'] as String,
      planId: s['planId'] as String? ?? '',
      title: s['titleSnapshot'] as String? ?? '',
      status: s['status'] as String? ?? 'PENDING_MENTOR',
      kind: s['kind'] as String? ?? 'CURRICULUM',
      totalPaisa: asInt(s['totalPaisa']),
      createdAt: parseDate(s['createdAt']) ?? mentoringNow(),
      pricePaisa: asInt(s['pricePaisa']),
      discountPaisa: asInt(s['discountPaisa']),
      taxPaisa: asInt(s['taxPaisa']),
      counterpart: other == null ? null : personFrom(other),
      mentorshipId: s['mentorshipId'] as String?,
      sessionsAllowance: asInt(s['sessionsAllowance']),
      sessionsUsed: asInt(s['sessionsUsed']),
      declineReason: s['declineReason'] as String?,
      billingPeriodMonths: asInt(s['billingPeriodMonths'], 1),
      periodEnd: parseDate(s['currentPeriodEnd']),
      cancelAtPeriodEnd: s['cancelAtPeriodEnd'] == true,
      cancelReason: _nonEmpty(s['cancelReason']),
      steps: [
        for (final st in asMaps(s['steps']))
          PlanStep(
            id: st['id'] as String? ?? '',
            position: asInt(st['position']),
            title: st['title'] as String? ?? '',
            outline: _nonEmpty(st['outline']),
            durationMin: (st['durationMin'] as num?)?.toInt(),
            done: st['completedAt'] != null,
            booked: st['sessionId'] != null,
            isNext: st['isNext'] == true,
          ),
      ],
    );
  }

  static String? _nonEmpty(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // --- transport -------------------------------------------------------------------

  Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? query]) async {
    try {
      final res = await api.dio.get<dynamic>(path, queryParameters: query);
      final data = res.data;
      return data is Map<String, dynamic> ? data : const {};
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<List<Map<String, dynamic>>> _getList(String path, [Map<String, dynamic>? query]) async {
    try {
      final res = await api.dio.get<dynamic>(path, queryParameters: query);
      final data = res.data;
      if (data is List) return data.whereType<Map<String, dynamic>>().toList();
      if (data is Map && data['data'] is List) return asMaps(data['data']);
      return const [];
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body]) async {
    try {
      final res = await api.dio.request<dynamic>(
        path,
        data: body,
        options: Options(method: method),
      );
      return res.data;
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}
