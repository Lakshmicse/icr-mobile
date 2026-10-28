import 'package:dio/dio.dart' show Options;

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/config.dart';
import 'council_format.dart';
import 'council_models.dart';
import 'councils_repository.dart';

/// Announcements this recent are what a joined council card calls "unread":
/// the API keeps no read state, so the nearest true count is what the council
/// has posted in the last month.
const unreadWindow = Duration(days: 30);

/// The Councils screen from the API: the directory (`GET /councils`), the
/// member's seats (`GET /councils/memberships/mine`), every upcoming event
/// (`GET /events?when=upcoming`, for each council's and chapter's next date),
/// the upcoming roundtables (the same call with `kind=ROUNDTABLE`, those a
/// council hosts), the city chapters (`GET /chapters`) and, for each council
/// the member belongs to, its announcements.
class ApiCouncilsRepository implements CouncilsRepository {
  ApiCouncilsRepository({required this.api, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final ApiClient api;
  final DateTime Function() _clock;

  static const _pageSize = 100;
  static const _maxPages = 10;

  @override
  Future<CouncilsOverview> overview() async {
    final results = await Future.wait([
      _pages('/councils'),
      _list('/councils/memberships/mine'),
      _pages('/events', {'when': 'upcoming'}),
      _pages('/events', {'when': 'upcoming', 'kind': 'ROUNDTABLE'}),
      _get('/chapters', {'limit': 50}),
    ]);
    final (councilRows, councilTotal) = results[0] as (List<Map<String, dynamic>>, int);
    final memberships = results[1] as List<Map<String, dynamic>>;
    final (events, _) = results[2] as (List<Map<String, dynamic>>, int);
    final (roundtableEvents, _) = results[3] as (List<Map<String, dynamic>>, int);
    final chaptersRes = results[4] as Map<String, dynamic>;

    final roles = {
      for (final m in memberships)
        if (m['councilId'] is String) m['councilId'] as String: CouncilRole.fromApi(m['role'] as String?),
    };
    final nextByCouncil = <String, DateTime>{};
    final nextByChapter = <String, DateTime>{};
    for (final e in events) {
      final at = _date(e['startsAt']);
      if (at == null) continue;
      final council = (e['council'] as Map<String, dynamic>?)?['id'] as String?;
      final chapter = (e['chapter'] as Map<String, dynamic>?)?['slug'] as String?;
      if (council != null && (nextByCouncil[council] == null || at.isBefore(nextByCouncil[council]!))) {
        nextByCouncil[council] = at;
      }
      if (chapter != null && (nextByChapter[chapter] == null || at.isBefore(nextByChapter[chapter]!))) {
        nextByChapter[chapter] = at;
      }
    }

    final now = _clock();
    var councils = [for (final row in councilRows) _council(row, roles[row['id']], nextByCouncil[row['id']], now)];

    // What a joined council has posted lately, one read per seat.
    final mine = councils.where((c) => c.joined).toList();
    final recent = await Future.wait([for (final c in mine) _recentAnnouncements(c.slug, now)]);
    final unread = {for (final (i, c) in mine.indexed) c.id: recent[i]};
    councils = [for (final c in councils) c.joined ? c.copyWith(unread: unread[c.id] ?? 0) : c];

    final byId = {for (final c in councils) c.id: c};
    final roundtables = [
      for (final e in roundtableEvents)
        if (e['council'] is Map && _date(e['startsAt']) != null) _roundtable(e, byId),
    ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final chapters = [for (final row in _rows(chaptersRes)) _chapter(row, nextByChapter[row['slug']])]
      ..sort((a, b) {
        if (a.nextEventAt == null && b.nextEventAt == null) return a.city.compareTo(b.city);
        return compareNextEvent(a.nextEventAt, b.nextEventAt);
      });

    final (quarter, quarterStart) = quarterOf(now);
    final peers = councils.fold(0, (n, c) => n + c.memberCount);
    return CouncilsOverview(
      stats: CouncilStats(
        activeCouncils: councilTotal,
        newThisQuarter: councils.where((c) => c.createdAt != null && !c.createdAt!.isBefore(quarterStart)).length,
        quarter: quarter,
        peerMembers: peers,
        peerMembersLabel: peerMembersLabel(peers),
        domains: {for (final c in councils) ...c.segments}.length,
        activeRoundtables: roundtables.length,
      ),
      councils: councils,
      joined: sortJoined(councils.where((c) => c.joined)),
      roundtables: roundtables.take(3).toList(),
      roundtablesCaption: roundtables.isEmpty ? null : 'All events',
      chapters: chapters.take(4).toList(),
    );
  }

  @override
  Future<CouncilRole> join(Council council) async {
    final res = await _send('POST', '/councils/${council.id}/join');
    return CouncilRole.fromApi((res as Map<String, dynamic>?)?['status'] as String?) ?? CouncilRole.member;
  }

  @override
  Future<void> leave(Council council) => _send('DELETE', '/councils/${council.id}/join');

  @override
  Future<int> unreadNotifications() async {
    final res = await _get('/notifications/unread-count');
    return (res['unread'] as num?)?.toInt() ?? 0;
  }

  @override
  Uri link(Council council, {String? tab}) =>
      AppConfig.sitePage('/councils/${council.slug}${tab == null ? '' : '?tab=$tab'}');

  @override
  Uri eventLink(Roundtable roundtable) => AppConfig.sitePage('/events/${roundtable.slug ?? roundtable.id}');

  @override
  Uri calendarLink(Roundtable roundtable) => calendarEntry(
    title: roundtable.title,
    start: roundtable.startsAt,
    end: roundtable.endsAt,
    location: roundtable.location,
    details: eventLink(roundtable).toString(),
  );

  @override
  Uri chapterLink(ChapterSummit chapter) => AppConfig.sitePage('/chapters/${chapter.slug}');

  // --- mapping -------------------------------------------------------------

  Council _council(Map<String, dynamic> json, CouncilRole? role, DateTime? nextEventAt, DateTime now) {
    final segments = _strings(json['segments']);
    // The first segment is the category (its chip); the rest are the topics
    // the card tags. A council with only one tags it with that.
    final topics = segments.length > 1 ? segments.sublist(1) : segments;
    final chairJson = json['chair'] as Map<String, dynamic>?;
    final upcoming = (json['upcomingEventCount'] as num?)?.toInt() ?? 0;
    final createdAt = _date(json['createdAt']);
    final tier = councilTier(createdAt, now);
    return Council(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? json['id'] as String,
      focus: _text(json['focus']),
      description: _text(json['description']),
      segments: segments,
      tags: topics.map(hashtag).toList(),
      cover: _picture(json['coverUrl'] as String?),
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      upcomingEventCount: upcoming,
      createdAt: createdAt,
      chair: chairJson == null
          ? null
          : CouncilChair(
              name: '${chairJson['firstName'] ?? ''} ${chairJson['lastName'] ?? ''}'.trim(),
              title: _text(chairJson['title']),
              photo: _picture(chairJson['avatarUrl'] as String?),
            ),
      membership: role,
      nextEventAt: nextEventAt,
      activityLabel: upcoming > 0 ? upcomingLabel(upcoming) : null,
      badge: tier.badge,
      established: tier.established,
    );
  }

  Roundtable _roundtable(Map<String, dynamic> json, Map<String, Council> councils) {
    final councilRef = json['council'] as Map<String, dynamic>;
    final (mode, tone) = roundtableMode(
      kind: json['kind'] as String? ?? '',
      inviteOnly: json['inviteOnly'] == true,
      location: json['location'] as String?,
    );
    final going = (json['attendeeCount'] as num?)?.toInt() ?? 0;
    final host = councils[councilRef['id']];
    return Roundtable(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      startsAt: _date(json['startsAt'])!,
      endsAt: _date(json['endsAt']),
      slug: json['slug'] as String?,
      mode: mode,
      tone: tone,
      detail: roundtableLine(
        lead: host?.chair,
        host: host?.name ?? councilRef['name'] as String? ?? 'A council',
        going: going,
      ),
      councilId: councilRef['id'] as String?,
      location: _text(json['location']),
    );
  }

  ChapterSummit _chapter(Map<String, dynamic> json, DateTime? nextEventAt) => ChapterSummit(
    id: json['id'] as String,
    slug: json['slug'] as String? ?? json['id'] as String,
    city: json['city'] as String? ?? json['name'] as String? ?? '',
    nextEventAt: nextEventAt,
  );

  static String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

  static DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

  static List<String> _strings(Object? v) => (v as List? ?? const []).map((e) => e.toString()).toList();

  static List<Map<String, dynamic>> _rows(Map<String, dynamic> page) =>
      (page['data'] as List? ?? const []).cast<Map<String, dynamic>>();

  FeedPicture? _picture(String? path) {
    final url = AppConfig.absoluteUrl(path, apiBase: api.dio.options.baseUrl);
    return url == null ? null : FeedPicture.network(url);
  }

  // --- transport -------------------------------------------------------------

  Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? query]) async {
    try {
      final res = await api.dio.get<Map<String, dynamic>>(path, queryParameters: query);
      return res.data ?? const {};
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  /// Every row of a paginated list (a page at a time, up to a thousand rows),
  /// with the total the API reports.
  Future<(List<Map<String, dynamic>>, int)> _pages(String path, [Map<String, dynamic>? query]) async {
    final rows = <Map<String, dynamic>>[];
    var total = 0;
    for (var page = 1; page <= _maxPages; page++) {
      final res = await _get(path, {...?query, 'page': page, 'limit': _pageSize});
      rows.addAll(_rows(res));
      final meta = res['meta'] as Map<String, dynamic>? ?? const {};
      total = (meta['total'] as num?)?.toInt() ?? rows.length;
      if (meta['hasNext'] != true) break;
    }
    return (rows, total);
  }

  /// A list endpoint that is the member's own: signed out it answers 401,
  /// which reads as "none".
  Future<List<Map<String, dynamic>>> _list(String path) async {
    try {
      final res = await api.dio.get<dynamic>(path);
      return (res.data as List? ?? const []).cast<Map<String, dynamic>>();
    } catch (_) {
      return const [];
    }
  }

  /// How many announcements the council posted inside [unreadWindow]; none
  /// when the read fails (the pill then shows the next session instead).
  Future<int> _recentAnnouncements(String slug, DateTime now) async {
    final since = now.subtract(unreadWindow);
    final rows = await _list('/councils/$slug/announcements');
    return rows.where((a) {
      final at = _date(a['createdAt']);
      return at != null && !at.isBefore(since);
    }).length;
  }

  Future<dynamic> _send(String method, String path) async {
    try {
      final res = await api.dio.request<dynamic>(path, options: Options(method: method));
      return res.data;
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}
