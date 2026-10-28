import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/features/events/api_events_repository.dart';

/// The Events tests' stand-in for the portal: an adapter that answers each route from a table, and a small
/// world (events, the member's places, programmes, refusals) the table can be built from.
class NoTokens extends TokenStore {
  @override
  Future<String?> accessToken() async => 'token';
  @override
  Future<String?> refreshToken() async => null;
}

/// Answers each route from a table and records the calls.
class FakeApi implements HttpClientAdapter {
  FakeApi(this.routes);

  final Map<String, Object Function(RequestOptions options)> routes;
  final List<String> calls = [];
  final List<Map<String, dynamic>> queries = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    calls.add(key);
    queries.add(options.queryParameters);
    final handler = routes[key];
    if (handler == null) return ResponseBody.fromString('{"message":"Not found"}', 404, headers: _json);
    final result = handler(options);
    if (result is (int, String)) return ResponseBody.fromString(result.$2, result.$1, headers: _json);
    return ResponseBody.fromString(jsonEncode(result), 200, headers: _json);
  }

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}

ApiEventsRepository repoOn(FakeApi api) {
  final client = ApiClient(tokens: NoTokens(), baseUrl: 'http://api.test/api/v1');
  client.dio.httpClientAdapter = api;
  return ApiEventsRepository(api: client);
}

// --- a small world the API source can be run against ------------------------------------------

String isoFrom(Duration from) => DateTime.now().toUtc().add(from).toIso8601String();

Map<String, Object?> eventRow(
  String id,
  String title, {
  String kind = 'WEBINAR',
  Duration at = const Duration(days: 3),
  Duration length = const Duration(minutes: 90),
  String location = 'Online',
  String? council,
  String? chapter,
  int going = 0,
  int? capacity,
  int? price,
  bool invite = false,
  String? description,

  /// A fixed start (UTC) instead of "[at] from now", for the goldens.
  DateTime? on,
}) => {
  'id': id,
  'title': title,
  'slug': 'slug-$id',
  'kind': kind,
  'description': description,
  'location': location,
  'coverUrl': null,
  'capacity': capacity,
  'priceAmount': price,
  'priceCurrency': 'INR',
  'startsAt': on != null ? on.toIso8601String() : isoFrom(at),
  'endsAt': on != null ? on.add(length).toIso8601String() : isoFrom(at + length),
  'attendeeCount': going,
  'chapter': chapter == null ? null : {'id': 'ch', 'name': chapter, 'slug': 'ch'},
  'council': council == null ? null : {'id': 'co-${council.length}', 'name': council, 'slug': 'co'},
  'inviteOnly': invite,
  'callForSpeakersUntil': null,
};

/// The flagship, a webinar the member holds a place at, two workshops and a webinar in two sustainability
/// councils, a priced summit, an invite-only roundtable, a chapter meeting beyond 30 days and one past event.
List<Map<String, Object?>> worldEvents() => [
  eventRow(
    'flag',
    'Global CRE PropTech Summit 2026',
    kind: 'CONFERENCE',
    at: const Duration(days: 1),
    length: const Duration(hours: 15),
    location: 'Mumbai Convention Centre & Hybrid',
    chapter: 'ICR Vinfraa & PropTech India Chapter',
    going: 500,
  ),
  eventRow('ai', 'Future of AI in Facility Management', at: const Duration(days: 2), going: 180),
  eventRow(
    'esg',
    'ESG Mandates: BRSR Core & Scope 3',
    council: 'Sustainability, ESG & Net-Zero Council',
    going: 40,
    at: const Duration(days: 3),
  ),
  eventRow(
    'zoom',
    'Uptime Clinic',
    kind: 'WORKSHOP',
    location: 'Online (Zoom)',
    council: 'Sustainability, ESG & Green Buildings Council',
    going: 3,
    at: const Duration(days: 5),
  ),
  eventRow(
    'bms',
    'Smart BMS Masterclass',
    kind: 'WORKSHOP',
    location: 'Bangalore HQ',
    council: 'Smart Buildings, BMS & PropTech Council',
    going: 36,
    at: const Duration(days: 9),
  ),
  eventRow(
    'summit',
    'Global CRE PropTech Summit 2026',
    kind: 'CONFERENCE',
    location: 'Mumbai Convention Centre, Bandra Kurla Complex',
    price: 1500000,
    going: 120,
    at: const Duration(days: 10),
    length: const Duration(days: 3),
  ),
  eventRow(
    'gcc',
    'Sustainable GCC Campus & Net-Zero Operations',
    kind: 'ROUNDTABLE',
    location: 'Bengaluru',
    council: 'CXO Workplace Strategy & FM Leadership Council',
    capacity: 25,
    going: 7,
    invite: true,
    at: const Duration(days: 12),
  ),
  eventRow(
    'far',
    'Mumbai Chapter Summit',
    kind: 'CHAPTER_MEET',
    location: 'Mumbai',
    council: 'Smart Buildings, BMS & PropTech Council',
    at: const Duration(days: 90),
  ),
  eventRow('old', 'Delhi NCR Summer Mixer', at: const Duration(days: -5), description: 'It happened.'),
];

/// The API as far as the Events screens use it, with the member's places and the refusals it can make.
class EventsWorld {
  EventsWorld({List<Map<String, Object?>>? events}) : events = events ?? worldEvents() {
    places['ai'] = 'GOING';
  }

  final List<Map<String, Object?>> events;

  /// event id → RSVP status
  final Map<String, String> places = {};

  /// event id → the programme's accepted talks
  final Map<String, List<Map<String, Object?>>> talks = {
    'ai': [
      {
        'id': 't1',
        'title': 'Future of AI in Facility Management',
        'abstract': 'Where AI pays for itself.',
        'bio': 'VP Sustainable PropTech',
        'speaker': {'id': 'u1', 'firstName': 'Dr. Radhika', 'lastName': 'Iyer'},
      },
    ],
    'esg': [
      {
        'id': 't2',
        'title': 'Scope 3 data: where to start',
        'abstract': 'Keynote on collecting supplier data.',
        'bio': 'Director ESG',
        'speaker': {'id': 'u2', 'firstName': 'Vikram', 'lastName': 'Malhotra'},
      },
      {
        'id': 't3',
        'title': 'BRSR Core in practice',
        'abstract': 'Panel with three CFOs.',
        'bio': 'IGBC AP',
        'speaker': {'id': 'u3', 'firstName': 'Priya', 'lastName': 'Nambiar'},
      },
    ],
  };

  /// What the RSVP route answers with a refusal (a 400 with this message).
  String? refuseRsvp;

  /// What the cancel route answers with a refusal (a 403 with this message).
  String? refuseCancel;

  /// Events whose seat the API gives as a waitlist place.
  final Set<String> waitlisted = {};

  /// Invite-only events the member holds no invitation to (by default they are asked to every one).
  final Set<String> notInvited = {};

  Map<String, Object?> byId(String id) => events.firstWhere((e) => e['id'] == id);

  List<Map<String, Object?>> _listed(RequestOptions o) {
    final q = o.queryParameters;
    final now = DateTime.now().toUtc();
    final past = q['when'] == 'past';
    final word = (q['search'] as String?)?.toLowerCase();
    final rows = events.where((e) {
      final at = DateTime.parse(e['startsAt'] as String);
      if (past != at.isBefore(now)) return false;
      if (q['kind'] != null && e['kind'] != q['kind']) return false;
      if (word != null) {
        final hay = '${e['title']} ${e['location']} ${e['description'] ?? ''}'.toLowerCase();
        if (!hay.contains(word)) return false;
      }
      return true;
    }).toList()..sort((a, b) => (a['startsAt'] as String).compareTo(b['startsAt'] as String));
    return past ? rows.reversed.toList() : rows;
  }

  Map<String, Object Function(RequestOptions)> routes() => {
    'GET /events': (o) {
      final rows = _listed(o);
      return {
        'data': rows,
        'meta': {'total': rows.length, 'hasNext': false},
      };
    },
    'GET /events/rsvps/mine': (_) => [
      for (final MapEntry(:key, :value) in places.entries)
        {
          'eventId': key,
          'status': value,
          'createdAt': isoFrom(const Duration(days: -1)),
          'event': {
            'id': key,
            'title': byId(key)['title'],
            'slug': byId(key)['slug'],
            'startsAt': byId(key)['startsAt'],
            'kind': byId(key)['kind'],
          },
        },
    ],
    'GET /mentorship/cpd/target': (_) => {
      'year': 2026,
      'targetHours': 15,
      'achievedHours': 8.5,
      'progress': 0.57,
      'isDefault': false,
    },
    'GET /notifications/unread-count': (_) => {'unread': 2},
    'GET /auth/me': (_) => {'firstName': 'Bharat', 'lastName': 'Buyer', 'companyId': 'co1'},
    'GET /companies/co1': (_) => {'id': 'co1', 'name': 'TechCorp'},
    for (final e in events) ...{
      'GET /events/${e['slug']}': (_) => e,
      'GET /events/${e['id']}/programme': (_) => {
        'eventId': e['id'],
        'inviteOnly': e['inviteOnly'],
        'speakers': talks[e['id']] ?? const [],
        'mine': {'invited': e['inviteOnly'] == true && !notInvited.contains(e['id'])},
      },
      'GET /events/${e['id']}/ticket/quote': (_) => {'payable': true, 'soldOut': false},
      'POST /events/${e['id']}/rsvp': (_) {
        if (refuseRsvp != null) return (400, jsonEncode({'statusCode': 400, 'message': refuseRsvp}));
        final status = waitlisted.contains(e['id']) ? 'WAITLISTED' : 'GOING';
        places[e['id'] as String] = status;
        return {'status': status};
      },
      'DELETE /events/${e['id']}/rsvp': (_) {
        if (refuseCancel != null) return (403, jsonEncode({'statusCode': 403, 'message': refuseCancel}));
        places[e['id'] as String] = 'CANCELLED';
        return {'status': 'CANCELLED'};
      },
    },
  };
}
