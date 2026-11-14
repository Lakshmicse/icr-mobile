import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import 'events_manage_models.dart';

/// The staff Events console (the website's `/admin/community?tab=events` and `?tab=event-hosts`, gated on the
/// permission key `events:manage`): every read and write the two tabs make.
///
/// The interface names what a console does, not whose console it is: a company's own Hosted events page (the
/// website's partner mode, `/event-hosts/me/events`) would be another implementation of [events], [createEvent],
/// [updateEvent] and [deleteEvent], with the staff-only calls left unsupported.
abstract class EventsManageRepository {
  // --- the events list ---------------------------------------------------------------------------------------------

  /// `GET /events/admin` — every event, hidden ones included, with who is going and who waits.
  Future<Paged<ManagedEvent>> events(EventsQuery query);

  /// One event by id. The API has no single-event staff read, so this looks it up through the staff list; null
  /// when the event is gone.
  Future<ManagedEvent?> event(String id);

  /// `POST /events`; the new event's id.
  Future<String> createEvent(Map<String, Object?> body);

  /// `PATCH /events/:id`.
  Future<void> updateEvent(String id, Map<String, Object?> body);

  /// `DELETE /events/:id` — cancels it and takes it off the public calendar.
  Future<void> deleteEvent(String id);

  /// The chapters an event may be hosted by (`GET /chapters/admin`, or the public list for staff without
  /// `chapters:manage`).
  Future<List<OrgRef>> chapters();

  /// The councils an event may be hosted by (`GET /councils/admin`, or the public list).
  Future<List<OrgRef>> councils();

  /// `GET /locations/addresses?q=` — venue and address suggestions for the Location field.
  Future<List<String>> addresses(String query, {String? session});

  // --- one event's programme ---------------------------------------------------------------------------------------

  /// The guest list, the talk proposals, the sponsorship requests and the packages, read together as the
  /// website's Programme dialog does (`GET /events/:id/invites`, `/proposals`, `/sponsorships`, `/programme`).
  Future<EventProgramme> programme(String eventId);

  /// `POST /events/:id/invites` — by email (or member id); unknown addresses come back, never invited.
  Future<InviteResult> invite(String eventId, {List<String> emails = const [], List<String> userIds = const []});

  /// `POST /events/:id/invites/by-tier` — everyone whose plan is on this tier or above.
  Future<TierInviteResult> inviteByTier(String eventId, String tier);

  /// `DELETE /events/:id/invites/:userId`.
  Future<void> removeInvite(String eventId, String userId);

  /// `PATCH /events/proposals/:id { status, note }` — `ACCEPTED` or `DECLINED` (a decline needs the note).
  Future<void> decideProposal(String proposalId, {required String status, String? note});

  /// `POST /events/:id/packages`.
  Future<void> createPackage(String eventId, Map<String, Object?> body);

  /// `PATCH /events/packages/:id`.
  Future<void> updatePackage(String packageId, Map<String, Object?> body);

  /// `DELETE /events/packages/:id`.
  Future<void> deletePackage(String packageId);

  /// `PATCH /events/sponsorships/:id { status, note }` — `CONFIRMED` or `DECLINED` (a decline needs the note).
  Future<void> decideSponsorship(String sponsorshipId, {required String status, String? note});

  // --- tickets and attendance --------------------------------------------------------------------------------------

  /// `GET /events/admin/tickets?eventId=&page=` — tickets sold, newest first, 50 to a page.
  Future<Paged<TicketRow>> tickets(String eventId, {int page = 1});

  /// `POST /events/tickets/:id/refund` — runs at once at or below the finance limit, else waits for a second
  /// approver.
  Future<RefundOutcome> refundTicket(String ticketId, {String? refundRef});

  /// `POST /events/:id/attendance { userIds }` — marks who came and credits their CPD hours.
  Future<AttendanceResult> markAttendance(String eventId, List<String> userIds);

  // --- companies asking to host events -----------------------------------------------------------------------------

  /// `GET /event-hosts/applications?status=&search=&page=&limit=` — waiting requests first, then newest.
  Future<Paged<HostApplication>> hostApplications({String? status, String search = '', int page = 1, int limit = 20});

  /// `GET /event-hosts/applications/pending-count`.
  Future<int> pendingHostApplications();

  /// `POST /event-hosts/applications/:id/approve|reject|revoke { note }`; [action] is one of the three.
  Future<HostApplication> decideHostApplication(String id, String action, {String? note});
}

class ApiEventsManageRepository implements EventsManageRepository {
  ApiEventsManageRepository({required this.api});

  final ApiClient api;

  /// How many staff-list pages [event] walks when the title search does not find the id.
  static const _lookupPages = 5;

  Future<T> _call<T>(Future<T> Function(Dio dio) body) async {
    try {
      return await body(api.dio);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  static Map<String, dynamic> _map(Object? data) => data is Map ? data.cast<String, dynamic>() : const {};

  static List<Map<String, dynamic>> _rows(Object? data) => [
    for (final r in data is List ? data : (data is Map && data['data'] is List ? data['data'] as List : const []))
      if (r is Map) r.cast<String, dynamic>(),
  ];

  static int _total(Object? data, int fallback) {
    final total = _map(_map(data)['meta'])['total'];
    return total is num ? total.round() : fallback;
  }

  static String _id(String id) => Uri.encodeComponent(id);

  // --- the events list ---------------------------------------------------------------------------------------------

  @override
  Future<Paged<ManagedEvent>> events(EventsQuery query) => _call((dio) async {
    final res = await dio.get<dynamic>('/events/admin', queryParameters: query.toQuery());
    final rows = [for (final r in _rows(res.data)) ManagedEvent.fromJson(r)];
    return Paged(rows, _total(res.data, rows.length));
  });

  @override
  Future<ManagedEvent?> event(String id) => _call((dio) async {
    // A listed event answers the public read by id, which gives its title to search the staff list with.
    String? title;
    try {
      final res = await dio.get<dynamic>('/events/${_id(id)}');
      title = _map(res.data)['title'] as String?;
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) rethrow;
    }
    if (title != null && title.trim().isNotEmpty) {
      final found = await events(EventsQuery(search: title, limit: 100));
      for (final e in found.rows) {
        if (e.id == id) return e;
      }
    }
    // A hidden event (or a title the search cannot match): walk the list, newest first.
    for (var page = 1; page <= _lookupPages; page++) {
      final found = await events(EventsQuery(page: page, limit: 100));
      for (final e in found.rows) {
        if (e.id == id) return e;
      }
      if (page * 100 >= found.total || found.rows.isEmpty) break;
    }
    return null;
  });

  @override
  Future<String> createEvent(Map<String, Object?> body) =>
      _call((dio) async => '${_map((await dio.post<dynamic>('/events', data: body)).data)['id'] ?? ''}');

  @override
  Future<void> updateEvent(String id, Map<String, Object?> body) =>
      _call((dio) => dio.patch<dynamic>('/events/${_id(id)}', data: body));

  @override
  Future<void> deleteEvent(String id) => _call((dio) => dio.delete<dynamic>('/events/${_id(id)}'));

  @override
  Future<List<OrgRef>> chapters() => _hosts('chapters');

  @override
  Future<List<OrgRef>> councils() => _hosts('councils');

  /// The staff list needs `chapters:manage` / `councils:manage`, which an Events Admin does not hold; the public
  /// list (published ones) answers for them.
  Future<List<OrgRef>> _hosts(String kind) => _call((dio) async {
    Response<dynamic> res;
    try {
      res = await dio.get<dynamic>('/$kind/admin', queryParameters: {'page': 1, 'limit': 100});
    } on DioException catch (e) {
      if (e.response?.statusCode != 403) rethrow;
      res = await dio.get<dynamic>('/$kind', queryParameters: {'page': 1, 'limit': 100});
    }
    return [for (final r in _rows(res.data)) ?OrgRef.from(r)];
  });

  @override
  Future<List<String>> addresses(String query, {String? session}) => _call((dio) async {
    final res = await dio.get<dynamic>(
      '/locations/addresses',
      queryParameters: {'q': query.trim(), 'session': ?session},
    );
    final seen = <String>{};
    return [
      for (final r in _rows(res.data))
        if (r['label'] is String && seen.add(r['label'] as String)) r['label'] as String,
    ];
  });

  // --- one event's programme ---------------------------------------------------------------------------------------

  @override
  Future<EventProgramme> programme(String eventId) => _call((dio) async {
    final id = _id(eventId);
    final res = await Future.wait([
      dio.get<dynamic>('/events/$id/invites'),
      dio.get<dynamic>('/events/$id/proposals'),
      dio.get<dynamic>('/events/$id/sponsorships'),
      dio.get<dynamic>('/events/$id/programme'),
    ]);
    return EventProgramme(
      invites: [for (final r in _rows(res[0].data)) EventInvite.fromJson(r)],
      proposals: [for (final r in _rows(res[1].data)) EventProposal.fromJson(r)],
      sponsorships: [for (final r in _rows(res[2].data)) SponsorshipRequest.fromJson(r)],
      packages: [for (final r in _rows(_map(res[3].data)['packages'])) SponsorPackage.fromJson(r)],
    );
  });

  @override
  Future<InviteResult> invite(String eventId, {List<String> emails = const [], List<String> userIds = const []}) =>
      _call((dio) async {
        final res = await dio.post<dynamic>(
          '/events/${_id(eventId)}/invites',
          data: {if (emails.isNotEmpty) 'emails': emails, if (userIds.isNotEmpty) 'userIds': userIds},
        );
        return InviteResult.fromJson(_map(res.data));
      });

  @override
  Future<TierInviteResult> inviteByTier(String eventId, String tier) => _call((dio) async {
    final res = await dio.post<dynamic>('/events/${_id(eventId)}/invites/by-tier', data: {'tier': tier});
    return TierInviteResult.fromJson(_map(res.data));
  });

  @override
  Future<void> removeInvite(String eventId, String userId) =>
      _call((dio) => dio.delete<dynamic>('/events/${_id(eventId)}/invites/${_id(userId)}'));

  @override
  Future<void> decideProposal(String proposalId, {required String status, String? note}) => _call(
    (dio) => dio.patch<dynamic>(
      '/events/proposals/${_id(proposalId)}',
      data: {'status': status, if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
    ),
  );

  @override
  Future<void> createPackage(String eventId, Map<String, Object?> body) =>
      _call((dio) => dio.post<dynamic>('/events/${_id(eventId)}/packages', data: body));

  @override
  Future<void> updatePackage(String packageId, Map<String, Object?> body) =>
      _call((dio) => dio.patch<dynamic>('/events/packages/${_id(packageId)}', data: body));

  @override
  Future<void> deletePackage(String packageId) =>
      _call((dio) => dio.delete<dynamic>('/events/packages/${_id(packageId)}'));

  @override
  Future<void> decideSponsorship(String sponsorshipId, {required String status, String? note}) => _call(
    (dio) => dio.patch<dynamic>(
      '/events/sponsorships/${_id(sponsorshipId)}',
      data: {'status': status, if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
    ),
  );

  // --- tickets and attendance --------------------------------------------------------------------------------------

  @override
  Future<Paged<TicketRow>> tickets(String eventId, {int page = 1}) => _call((dio) async {
    final res = await dio.get<dynamic>('/events/admin/tickets', queryParameters: {'eventId': eventId, 'page': page});
    final rows = [for (final r in _rows(res.data)) TicketRow.fromJson(r)];
    return Paged(rows, _total(res.data, rows.length));
  });

  @override
  Future<RefundOutcome> refundTicket(String ticketId, {String? refundRef}) => _call((dio) async {
    final ref = refundRef?.trim() ?? '';
    final res = await dio.post<dynamic>(
      '/events/tickets/${_id(ticketId)}/refund',
      data: {if (ref.isNotEmpty) 'refundRef': ref},
    );
    return RefundOutcome.fromJson(res.data);
  });

  @override
  Future<AttendanceResult> markAttendance(String eventId, List<String> userIds) => _call((dio) async {
    final res = await dio.post<dynamic>('/events/${_id(eventId)}/attendance', data: {'userIds': userIds});
    return AttendanceResult.fromJson(_map(res.data));
  });

  // --- companies asking to host events -----------------------------------------------------------------------------

  @override
  Future<Paged<HostApplication>> hostApplications({String? status, String search = '', int page = 1, int limit = 20}) =>
      _call((dio) async {
        final res = await dio.get<dynamic>(
          '/event-hosts/applications',
          queryParameters: {
            'page': page,
            'limit': limit,
            if (search.trim().isNotEmpty) 'search': search.trim(),
            'status': ?status,
          },
        );
        final rows = [for (final r in _rows(res.data)) HostApplication.fromJson(r)];
        return Paged(rows, _total(res.data, rows.length));
      });

  @override
  Future<int> pendingHostApplications() => _call((dio) async {
    final pending = _map((await dio.get<dynamic>('/event-hosts/applications/pending-count')).data)['pending'];
    return pending is num ? pending.round() : 0;
  });

  @override
  Future<HostApplication> decideHostApplication(String id, String action, {String? note}) => _call((dio) async {
    final res = await dio.post<dynamic>(
      '/event-hosts/applications/${_id(id)}/$action',
      data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
    );
    return HostApplication.fromJson(_map(res.data));
  });
}
