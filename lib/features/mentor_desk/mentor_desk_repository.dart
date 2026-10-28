import 'package:dio/dio.dart' show Options;

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../mentorship_my/mentoring_clock.dart';
import '../mentorship_my/mentoring_models.dart';
import '../mentorship_my/mentoring_repository.dart';
import 'mentor_desk_models.dart';

/// Everything the mentor's desk reads and writes. What the member-side
/// screens already do (answering a free request, the calendar, a pairing)
/// goes through [mentoring]; the mentor's own endpoints are here.
class MentorDeskRepository {
  MentorDeskRepository({required this.api}) : mentoring = MentoringRepository(api: api);

  final ApiClient api;
  final MentoringRepository mentoring;

  // --- the dashboard and the profile ---------------------------------------------

  Future<DeskDashboard> dashboard() async {
    final res = await _get('/mentorship/mentors/me/dashboard');
    final p = res['profile'] as Map<String, dynamic>?;
    final c = res['completeness'] as Map<String, dynamic>? ?? const {};
    final cap = res['capacity'] as Map<String, dynamic>? ?? const {};
    final rq = res['requests'] as Map<String, dynamic>? ?? const {};
    final mn = res['mentees'] as Map<String, dynamic>? ?? const {};
    final status = DeskStatus.fromApi(p?['status'] as String?);
    return DeskDashboard(
      hasProfile: res['hasProfile'] == true,
      profile: p == null || status == null
          ? null
          : DeskProfile(
              id: p['id'] as String? ?? '',
              status: status,
              headline: p['headline'] as String? ?? '',
              discoverable: p['discoverable'] != false,
              reviewNote: _text(p['reviewNote']),
              rating: (p['rating'] as num?)?.toDouble() ?? 0,
              ratingCount: asInt(p['ratingCount']),
              menteesHelped: asInt(p['menteesHelped']),
            ),
      completenessScore: asInt(c['score']),
      missing: asStrings(c['missing']),
      capacityTotal: asInt(cap['total']),
      capacityActive: asInt(cap['active']),
      capacityOpen: asInt(cap['open']),
      requestsPending: asInt(rq['pending']),
      answeredThisMonth: asInt(rq['answeredThisMonth']),
      acceptedThisMonth: asInt(rq['acceptedThisMonth']),
      acceptRatePct: asInt(rq['acceptRateThisMonth']),
      menteesActive: asInt(mn['active']),
      menteesCompleted: asInt(mn['completed']),
      isListed: res['isListed'] == true,
      recentActivity: [
        for (final e in asMaps(res['recentActivity']))
          TimelineEntry(
            id: e['id'] as String? ?? '',
            type: e['type'] as String? ?? '',
            createdAt: parseDate(e['createdAt']) ?? mentoringNow(),
            note: _text(e['note']),
            shared: (e['visibility'] as String? ?? 'SHARED') == 'SHARED',
            actorName: switch (e['actor']) {
              final Map<String, dynamic> a => '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.trim(),
              _ => null,
            },
          ),
      ],
    );
  }

  /// The profile's own settings and weekly hours.
  Future<DeskSettings> settings() async {
    final m = await _get('/mentorship/mentors/me');
    return DeskSettings(
      id: m['id'] as String? ?? '',
      status: DeskStatus.fromApi(m['status'] as String?),
      bioHtml: m['bioHtml'] as String? ?? '',
      preferredModes: asStrings(m['preferredModes']),
      cadence: m['cadence'] as String?,
      capacity: asInt(m['capacity'], 2),
      timezone: m['timezone'] as String? ?? 'Asia/Kolkata',
      availabilityNote: m['availabilityNote'] as String? ?? '',
      meetingLink: m['meetingLink'] as String? ?? '',
      discoverable: m['discoverable'] != false,
      openSlots: asInt(m['openSlots']),
      blocks: [
        for (final b in asMaps(m['availabilityBlocks']))
          WeeklyBlock(weekday: asInt(b['weekday']), startMin: asInt(b['startMin']), endMin: asInt(b['endMin'])),
      ],
    );
  }

  /// Sends only what changed: the API keeps every field a body leaves out.
  Future<void> saveSettings(Map<String, dynamic> changes) => _send('PUT', '/mentorship/mentors/me', changes);

  /// Replaces the weekly hours (an empty list clears them).
  Future<void> saveHours(List<WeeklyBlock> blocks) => _send('PUT', '/mentorship/mentors/me/availability', {
    'blocks': [for (final b in blocks) b.toJson()],
  });

  /// Lists or hides the profile in the directory without withdrawing it.
  Future<void> setVisibility(bool discoverable) =>
      _send('PATCH', '/mentorship/mentors/me/visibility', {'discoverable': discoverable});

  // --- mentees -----------------------------------------------------------------------

  /// The mentor's own mentees (live pairings), as pairings read from the mentor's side.
  Future<List<Pairing>> roster() async => [
    for (final p in await _getList('/mentorship/mentors/me/roster')) mentoring.pairingFrom(p),
  ];

  // --- what was sold -----------------------------------------------------------------

  /// Sales (the seller's side): every one that still needs the mentor ([open]), or all of them.
  Future<List<SoldRow>> sold({bool open = true}) async {
    final res = await _get('/mentor-services/purchases/mine', {
      'limit': 100,
      'side': 'SELLER',
      'scope': ?(open ? 'open' : null),
    });
    return [for (final p in asMaps(res['data'])) soldFrom(p)];
  }

  SoldRow soldFrom(Map<String, dynamic> p) => SoldRow(
    purchase: mentoring.purchaseFrom(p),
    timeDeclinedAt: parseDate((p['request'] as Map?)?['timeDeclinedAt']),
    issueReportedAt: parseDate(p['issueReportedAt']),
    issueNote: _text(p['issueNote']),
    issueRespondedAt: parseDate(p['issueRespondedAt']),
    issueResponseNote: _text(p['issueResponseNote']),
    issueResolvedAt: parseDate(p['issueResolvedAt']),
  );

  /// Programme and plan requests and terms sold by the caller.
  Future<List<PlanTerm>> soldTerms() => mentoring.soldTerms();

  /// Free times to offer for a request, the mentee's quick picks ranked first.
  Future<SuggestedTimes> suggestedTimes(String purchaseId) async {
    final res = await _get('/mentor-services/purchases/$purchaseId/suggested-times');
    return SuggestedTimes(
      timezone: res['timezone'] as String? ?? 'Asia/Kolkata',
      hasWeeklyHours: res['hasWeeklyHours'] == true,
      suggestions: [
        for (final s in asMaps(res['suggestions']))
          if (DateTime.tryParse(s['at'] as String? ?? '') != null)
            Slot(DateTime.parse(s['at'] as String), preferred: s['preferred'] == true),
      ],
    );
  }

  /// The mentor's free starts (their weekly hours less what is booked) for a call of [durationMin].
  Future<List<Slot>> slots(String mentorProfileId, {int durationMin = 60}) =>
      mentoring.slots(mentorProfileId, durationMin: durationMin);

  /// Accepts a request and sets the time: a free session is booked, a paid one is held until the mentee pays.
  Future<void> acceptSessionRequest(String purchaseId, DateTime at) =>
      _send('POST', '/mentor-services/purchases/$purchaseId/accept', {'scheduledAt': at.toUtc().toIso8601String()});

  Future<void> declineSessionRequest(String purchaseId, String reason) =>
      _send('POST', '/mentor-services/purchases/$purchaseId/decline', {'reason': reason.trim()});

  /// Takes back a time the mentor set and the mentee has not accepted or paid for.
  Future<void> withdrawHeldTime(String purchaseId) => _send('POST', '/mentor-services/purchases/$purchaseId/withdraw');

  /// Answers a programme or plan request. A decline needs a reason the buyer reads as written.
  Future<void> decidePlanRequest(String subscriptionId, {required bool accept, String? reason}) => _send(
    'POST',
    '/mentor-plans/subscriptions/$subscriptionId/decide',
    {'decision': accept ? 'ACCEPT' : 'DECLINE', if (!accept && reason != null) 'reason': reason.trim()},
  );

  /// The mentor confirms a paid call was held.
  Future<void> completeCall(String purchaseId) => _send('POST', '/mentor-services/purchases/$purchaseId/complete');

  Future<void> cancelCall(String purchaseId, String reason) => mentoring.cancelBooking(purchaseId, reason);

  Future<void> setCallLink(String purchaseId, String? link) =>
      _send('PATCH', '/mentor-services/purchases/$purchaseId/meeting-link', {'meetingLink': link});

  Future<void> proposeMove(String purchaseId, DateTime at, {String? note}) =>
      mentoring.proposeReschedule(purchaseId, at, note: note);

  /// Accepts the mentee's new time, or turns it down (and, for a move the mentor proposed, takes it back).
  Future<void> answerMove(String purchaseId, {required bool accept, String? reason}) =>
      mentoring.answerReschedule(purchaseId, accept: accept, reason: reason);

  /// The seller's reply to a problem the buyer reported; the buyer and ICR read it.
  Future<void> respondIssue(String purchaseId, String note) =>
      _send('POST', '/mentor-services/purchases/$purchaseId/respond-issue', {'note': note.trim()});

  // --- earnings, reviews ---------------------------------------------------------------

  Future<Earnings> earnings() async {
    final res = await _get('/mentor-services/mine/earnings');
    return Earnings(
      unsettledPaisa: asInt(res['unsettledPaisa']),
      settledPaisa: asInt(res['settledPaisa']),
      entries: [
        for (final e in asMaps(res['entries']))
          EarningEntry(
            id: e['id'] as String? ?? '',
            kind: e['kind'] as String? ?? 'EARNING',
            amountPaisa: asInt(e['amountPaisa']),
            createdAt: parseDate(e['createdAt']) ?? mentoringNow(),
            purchaseId: e['purchaseId'] as String?,
            subscriptionId: e['subscriptionId'] as String?,
            settledAt: parseDate(e['settledAt']),
            settlementRef: _text(e['settlementRef']),
          ),
      ],
    );
  }

  /// Anonymous ratings mentees left about their mentorships with this mentor.
  Future<List<MenteeFeedback>> menteeFeedback(String mentorProfileId) async => [
    for (final f in await _getList('/mentorship/mentors/$mentorProfileId/feedback'))
      MenteeFeedback(
        id: f['id'] as String? ?? '',
        rating: asInt(f['rating']),
        createdAt: parseDate(f['createdAt']) ?? mentoringNow(),
        comment: _text(f['comment']),
      ),
  ];

  /// What the mentor sells, for the reviews of each.
  Future<List<({String id, String title})>> serviceTitles() async {
    final res = await _get('/mentor-services/mine');
    return [
      for (final s in asMaps(res['services']))
        if (s['id'] is String) (id: s['id'] as String, title: s['title'] as String? ?? 'A service'),
    ];
  }

  Future<List<ServiceReviewRow>> serviceReviews(String serviceId, String title) async => [
    for (final r in await _getList('/mentor-services/$serviceId/reviews'))
      ServiceReviewRow(
        id: r['id'] as String? ?? '',
        rating: asInt(r['rating']),
        serviceTitle: title,
        createdAt: parseDate(r['createdAt']) ?? mentoringNow(),
        comment: _text(r['comment']),
        authorName: _text(r['authorName']),
      ),
  ];

  // --- transport -------------------------------------------------------------------------

  static String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

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
