import 'package:dio/dio.dart' show Options;

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/config.dart';
import 'event_format.dart';
import 'event_models.dart';
import 'events_repository.dart';

/// The Events screens from the API: the board (`GET /events`), the member's
/// places (`GET /events/rsvps/mine`), their CPD year (`GET /mentorship/cpd/
/// target`), an event (`GET /events/:slug`) with its programme
/// (`GET /events/:id/programme`), and the RSVP routes.
class ApiEventsRepository implements EventsRepository {
  ApiEventsRepository({required this.api});

  final ApiClient api;

  /// The member's RSVP rows, by event id.
  Map<String, _Rsvp>? _rsvps;
  _Me? _me;

  static const _pageSize = 100;
  static const _soon = Duration(days: 30);

  /// How many events a card-line lookup reads the programme of at once: the
  /// board shows a handful of cards, and the API lists one programme per call.
  static const speakerLookups = 12;

  @override
  Future<EventsOverview> overview() async {
    // The rows are mapped only once the member's places are known, so each
    // card carries its own RSVP.
    final results = await Future.wait([
      _rows('/events', {'when': 'upcoming', 'limit': _pageSize}),
      _loadRsvps(force: true),
      _cpd(),
    ]);
    final all = (results[0] as List<Map<String, dynamic>>).map(_event).toList();
    final cpd = results[2] as CpdProgress?;
    final now = eventsNow();

    // The flagship: the event with the most members going (the first of equals).
    EventSummary? spotlight;
    for (final e in all) {
      if (spotlight == null || e.going > spotlight.going) spotlight = e;
    }
    // The agenda is everything else: the spotlight has its own card above it.
    final events = spotlight == null ? all : all.where((e) => e.id != spotlight!.id).toList();

    return EventsOverview(
      events: events,
      spotlight: spotlight,
      upcomingCount: events.where((e) => e.startsAt.isBefore(now.add(_soon))).length,
      schedule: schedule(all),
      cpd: cpd,
      tracks: _tracks(events),
      readyCount: events.where((e) => !e.inviteOnly && !e.full && !e.past).length,
    );
  }

  /// The tiles of Explore by Category: the industry tracks the agenda's
  /// councils stand for, most events first. With fewer than two of them (an
  /// event has a kind and a council, never an industry) the tiles are the
  /// event kinds.
  List<EventTrack> _tracks(List<EventSummary> agenda) {
    final counts = <String, int>{};
    for (final e in agenda) {
      final label = trackOf(e);
      if (label != null) counts[label] = (counts[label] ?? 0) + 1;
    }
    if (counts.length >= 2) {
      final labels = counts.keys.toList()
        ..sort((a, b) {
          final byCount = counts[b]!.compareTo(counts[a]!);
          return byCount != 0 ? byCount : a.compareTo(b);
        });
      return [
        for (final label in labels)
          EventTrack(
            key: 'council:$label',
            label: label,
            count: counts[label]!,
            icon: trackIconFor(label),
            council: label,
          ),
      ];
    }
    return [
      for (final kind in _kindOrder)
        EventTrack(
          key: kind.apiKey,
          label: kind.plural,
          count: agenda.where((e) => e.kind == kind).length,
          icon: _trackIcon(kind),
          kind: kind,
        ),
    ]..sort((a, b) => b.count.compareTo(a.count));
  }

  @override
  MySchedule? schedule(List<EventSummary> known) {
    final now = eventsNow();
    final held =
        (_rsvps?.values ?? const Iterable<_Rsvp>.empty())
            .where((r) => r.state.holds && r.startsAt.isAfter(now))
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    if (held.isEmpty) return null;
    final first = held.first;
    final next = known.where((e) => e.id == first.eventId).firstOrNull ?? first.summary;
    return MySchedule(count: held.length, next: next);
  }

  @override
  Future<List<EventSummary>> search(EventQuery query) async {
    await _loadRsvps();
    final rows = await _list({
      'when': query.when == EventWhen.past ? 'past' : 'upcoming',
      'limit': _pageSize,
      if (query.kind != null) 'kind': query.kind!.apiKey,
      if (query.search.isNotEmpty) 'search': query.search,
    });
    return switch (query.format) {
      FormatFilter.any => rows,
      FormatFilter.online => rows.where((e) => formatOf(e) != EventFormat.inPerson).toList(),
      FormatFilter.inPerson => rows.where((e) => formatOf(e) != EventFormat.online).toList(),
    };
  }

  @override
  Future<EventDetail> detail(EventSummary seed) async {
    await _loadRsvps();
    final json = await _get('/events/${seed.slug ?? seed.id}');
    final fresh = _event(json);
    final results = await Future.wait([_programme(fresh.id), _whoAmI(), _quote(fresh)]);
    final programme = results[0] as Map<String, dynamic>?;
    final me = results[1] as _Me?;
    final quote = results[2] as Map<String, dynamic>?;

    final talks = _talks(programme);
    // The card's second line comes along with the event, so the board keeps it
    // when the sheet reports the event back.
    final event = fresh.copyWith(
      saved: seed.saved,
      speakerLine: seed.speakerLine ?? (talks.isEmpty ? null : speakerCardLine(talks.first)),
    );
    final sessions = sessionsFor(event, talks);
    final mine = programme?['mine'] as Map<String, dynamic>?;
    return EventDetail(
      event: event,
      organiser: event.host ?? 'ICR',
      sessions: sessions,
      agendaNote: sessions.isEmpty ? null : 'Indicative times • ${shortDay(event.startsAt)}',
      attendeeNote: event.capacity != null
          ? '${groupThousands(event.capacity!)} seats in total'
          : 'Open to every ICR member',
      // ICR issues no pass number or QR to a member: the pass carries the
      // event's code, and the code the pass dialog draws leads to its page.
      pass: _pass(event, me),
      invited: mine?['invited'] == true,
      sellsTickets: quote?['payable'] == true && quote?['soldOut'] != true,
    );
  }

  /// The pass card: the member's name and company, and for a confirmed place
  /// (not a waitlist one) the event's code as the pass reference.
  static EventPass? _pass(EventSummary event, _Me? me) {
    if (!event.rsvp.holds || me == null) return null;
    final confirmed = event.rsvp == RsvpState.going || event.rsvp == RsvpState.attended;
    return EventPass(holder: me.holderLine, reference: confirmed ? passReference(event.id) : null);
  }

  @override
  Future<EventPass?> passFor(EventSummary event) async => _pass(event, await _whoAmI());

  @override
  Future<Map<String, String>> speakers(List<EventSummary> events) async {
    final found = <String, String>{};
    await Future.wait([
      for (final e in events.take(speakerLookups))
        () async {
          final talks = _talks(await _programme(e.id));
          if (talks.isNotEmpty) found[e.id] = speakerCardLine(talks.first);
        }(),
    ]);
    return found;
  }

  @override
  Future<RsvpState> rsvp(EventSummary event) async {
    final res = await _send('POST', '/events/${event.id}/rsvp');
    final state = RsvpState.fromApi((res as Map<String, dynamic>?)?['status'] as String?);
    (_rsvps ??= {})[event.id] = _Rsvp(event.id, state, event.startsAt, event);
    return state == RsvpState.none ? RsvpState.going : state;
  }

  @override
  Future<void> cancel(EventSummary event) async {
    await _send('DELETE', '/events/${event.id}/rsvp');
    (_rsvps ??= {})[event.id] = _Rsvp(event.id, RsvpState.cancelled, event.startsAt, event);
  }

  @override
  Future<int> unreadNotifications() async {
    final res = await _get('/notifications/unread-count');
    return (res['unread'] as num?)?.toInt() ?? 0;
  }

  @override
  Uri link(EventSummary event) => AppConfig.sitePage('/events/${event.slug ?? event.id}');

  // --- mapping -------------------------------------------------------------

  EventSummary _event(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final startsAt = _date(json['startsAt']) ?? DateTime.now();
    final endsAt = _date(json['endsAt']);
    final chapter = json['chapter'] as Map<String, dynamic>?;
    final council = json['council'] as Map<String, dynamic>?;
    final callUntil = _date(json['callForSpeakersUntil']);
    // What the CPD ledger credits for attending: the event's own length, or
    // an hour when it has no end (`EventsService.markAttendance`).
    final hours = endsAt == null
        ? 1.0
        : ((endsAt.difference(startsAt).inMinutes / 60 * 100).round() / 100).clamp(0.5, double.infinity);
    return EventSummary(
      id: id,
      slug: json['slug'] as String?,
      title: json['title'] as String? ?? '',
      kind: EventKind.fromApi(json['kind'] as String?),
      startsAt: startsAt,
      endsAt: endsAt,
      location: json['location'] as String?,
      cover: _picture(json['coverUrl'] as String?),
      host: chapter?['name'] as String? ?? council?['name'] as String?,
      council: council?['name'] as String?,
      capacity: (json['capacity'] as num?)?.toInt(),
      going: (json['attendeeCount'] as num?)?.toInt() ?? 0,
      pricePaisa: (json['priceAmount'] as num?)?.toInt() ?? 0,
      inviteOnly: json['inviteOnly'] == true,
      cpdHours: hours,
      rsvp: _rsvps?[id]?.state ?? RsvpState.none,
      description: json['description'] as String?,
      takesProposals: callUntil != null && callUntil.isAfter(eventsNow()),
    );
  }

  /// The programme's accepted talks, in the order the API lists them.
  static List<EventTalk> _talks(Map<String, dynamic>? programme) {
    final rows = (programme?['speakers'] as List? ?? const []).cast<Map<String, dynamic>>();
    return [
      for (final s in rows)
        EventTalk(
          title: s['title'] as String? ?? '',
          abstract: s['abstract'] as String? ?? '',
          speaker: _speakerName(s['speaker'] as Map<String, dynamic>?),
          bio: s['bio'] as String?,
        ),
    ];
  }

  static String _speakerName(Map<String, dynamic>? person) =>
      '${person?['firstName'] ?? ''} ${person?['lastName'] ?? ''}'.trim();

  static const _kindOrder = [
    EventKind.conference,
    EventKind.webinar,
    EventKind.roundtable,
    EventKind.workshop,
    EventKind.masterclass,
    EventKind.chapterMeet,
  ];

  static TrackIcon _trackIcon(EventKind kind) => switch (kind) {
    EventKind.conference => TrackIcon.conference,
    EventKind.webinar => TrackIcon.webinar,
    EventKind.workshop => TrackIcon.workshop,
    EventKind.masterclass => TrackIcon.masterclass,
    EventKind.roundtable => TrackIcon.roundtable,
    EventKind.chapterMeet => TrackIcon.chapter,
  };

  static DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

  FeedPicture? _picture(String? path) {
    final url = AppConfig.absoluteUrl(path, apiBase: api.dio.options.baseUrl);
    return url == null ? null : FeedPicture.network(url);
  }

  // --- the member's own state ----------------------------------------------

  Future<void> _loadRsvps({bool force = false}) async {
    if (!force && _rsvps != null) return;
    try {
      final res = await api.dio.get<dynamic>('/events/rsvps/mine');
      final rows = (res.data as List? ?? const []).cast<Map<String, dynamic>>();
      _rsvps = {
        for (final r in rows)
          if (r['eventId'] is String)
            r['eventId'] as String: _Rsvp(
              r['eventId'] as String,
              RsvpState.fromApi(r['status'] as String?),
              _date((r['event'] as Map<String, dynamic>?)?['startsAt']) ?? DateTime.now(),
              _bare(r['event'] as Map<String, dynamic>? ?? const {}, r['eventId'] as String),
            ),
      };
    } catch (_) {
      _rsvps ??= {};
    }
  }

  /// The event block `rsvps/mine` carries: id, title, slug, startsAt, kind.
  EventSummary _bare(Map<String, dynamic> e, String id) => EventSummary(
    id: e['id'] as String? ?? id,
    slug: e['slug'] as String?,
    title: e['title'] as String? ?? 'Event',
    kind: EventKind.fromApi(e['kind'] as String?),
    startsAt: _date(e['startsAt']) ?? DateTime.now(),
    rsvp: _rsvps?[id]?.state ?? RsvpState.going,
  );

  /// The member's CPD year, as `GET /mentorship/cpd/target` reports it; the
  /// summary's hours this year when the target route is unavailable.
  Future<CpdProgress?> _cpd() async {
    try {
      final res = await _get('/mentorship/cpd/target');
      return CpdProgress(
        earned: (res['achievedHours'] as num?)?.toDouble() ?? 0,
        target: (res['targetHours'] as num?)?.toDouble() ?? 0,
        year: (res['year'] as num?)?.toInt() ?? DateTime.now().year,
      );
    } catch (_) {}
    try {
      final res = await _get('/mentorship/cpd/summary');
      return CpdProgress(earned: (res['hoursThisYear'] as num?)?.toDouble() ?? 0, target: 0, year: DateTime.now().year);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _programme(String id) async {
    try {
      return await _get('/events/$id/programme');
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _quote(EventSummary event) async {
    if (!event.priced) return null;
    try {
      return await _get('/events/${event.id}/ticket/quote');
    } catch (_) {
      return null;
    }
  }

  /// The name on the pass card, with the company the member acts for.
  Future<_Me?> _whoAmI() async {
    if (_me != null) return _me;
    try {
      final me = await _get('/auth/me');
      final user = (me['user'] as Map<String, dynamic>?) ?? me;
      final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
      String? company;
      final companyId = user['companyId'] as String?;
      if (companyId != null && companyId.isNotEmpty) {
        try {
          company = (await _get('/companies/$companyId'))['name'] as String?;
        } catch (_) {}
      }
      return _me = _Me(name.isEmpty ? 'You' : name, company);
    } catch (_) {
      return null;
    }
  }

  // --- transport -------------------------------------------------------------

  Future<List<EventSummary>> _list(Map<String, dynamic> query) async =>
      (await _rows('/events', query)).map(_event).toList();

  Future<List<Map<String, dynamic>>> _rows(String path, Map<String, dynamic> query) async {
    final res = await _get(path, query);
    return (res['data'] as List? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? query]) async {
    try {
      final res = await api.dio.get<Map<String, dynamic>>(path, queryParameters: query);
      return res.data ?? const {};
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

class _Rsvp {
  const _Rsvp(this.eventId, this.state, this.startsAt, this.summary);

  final String eventId;
  final RsvpState state;
  final DateTime startsAt;
  final EventSummary summary;
}

class _Me {
  const _Me(this.name, this.company);

  final String name;
  final String? company;

  String get holderLine => company == null || company!.isEmpty ? name : '$name ($company)';
}
