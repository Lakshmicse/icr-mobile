import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/config.dart';
import 'chapter_models.dart';
import 'chapters_repository.dart';
import 'community_api.dart';
import 'community_kit.dart';

/// The Chapters screens from the API (the portal's association module):
/// `GET /chapters` (every page), `/chapters/:slug`, `/chapters/:slug/members`,
/// `/resources` and `/announcements`, `/chapters/memberships/mine`,
/// `GET /events?when=upcoming` (the board's meetups and each chapter's next
/// date) and `?chapterSlug=` (a chapter's events), `/events/rsvps/mine`,
/// `POST|DELETE /chapters/:id/join` and `POST|DELETE /events/:id/rsvp`.
class ApiChaptersRepository implements ChaptersRepository {
  ApiChaptersRepository({required ApiClient api}) : _api = CommunityApi(api);

  final CommunityApi _api;

  static const membersPageSize = 12;

  @override
  Future<ChaptersOverview> overview() async {
    final results = await Future.wait<Object>([
      _api.all('/chapters'),
      _api.mine('/chapters/memberships/mine'),
      _api.all('/events', {'when': 'upcoming'}, 3),
    ]);
    final (rows, _) = results[0] as (List<Map<String, dynamic>>, int);
    final roles = _roles(results[1] as List<Map<String, dynamic>>);
    final (eventRows, _) = results[2] as (List<Map<String, dynamic>>, int);

    final meetups = [
      for (final e in eventRows)
        if (e['chapter'] is Map && CommunityApi.date(e['startsAt']) != null) _event(e),
    ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final next = <String, DateTime>{};
    for (final e in meetups) {
      final slug = e.chapterSlug;
      if (slug != null && !next.containsKey(slug)) next[slug] = e.startsAt;
    }
    return ChaptersOverview(
      chapters: [for (final row in rows) _summary(row, roles[row['id']], next[row['slug']])],
      meetups: meetups,
    );
  }

  @override
  Future<ChapterDetail> detail(String idOrSlug) async {
    final results = await Future.wait<Object>([
      _chapterJson(idOrSlug),
      _api.mine('/chapters/memberships/mine'),
      _rsvps(),
    ]);
    final json = results[0] as Map<String, dynamic>;
    final roles = _roles(results[1] as List<Map<String, dynamic>>);
    final rsvps = results[2] as Map<String, String>;
    final stats = json['stats'] as Map<String, dynamic>? ?? const {};
    final events = [
      for (final e in (json['upcomingEvents'] as List? ?? const []).cast<Map<String, dynamic>>())
        if (CommunityApi.date(e['startsAt']) != null) _event(e).withStatus(rsvps[e['id']]),
    ];
    final aboutHtml = CommunityApi.text(json['aboutHtml']);
    final description = CommunityApi.text(json['description']);
    return ChapterDetail(
      chapter: _summary(json, roles[json['id']], events.isEmpty ? null : events.first.startsAt),
      contactEmail: CommunityApi.text(json['contactEmail']),
      foundedYear: (json['foundedYear'] as num?)?.toInt(),
      about: aboutHtml != null
          ? htmlBlocks(aboutHtml)
          : [if (description != null) AboutBlock(AboutKind.paragraph, description)],
      gallery: [for (final url in (json['galleryUrls'] as List? ?? const []).whereType<String>()) ?_api.picture(url)],
      stats: ChapterStats(
        memberCount: CommunityApi.count(stats['memberCount']),
        leadershipCount: CommunityApi.count(stats['leadershipCount']),
        upcomingEventCount: CommunityApi.count(stats['upcomingEventCount']),
        pastEventCount: CommunityApi.count(stats['pastEventCount']),
        memberCompanyCount: CommunityApi.count(stats['memberCompanyCount']),
      ),
      sponsors: [
        for (final s in (json['sponsors'] as List? ?? const []).cast<Map<String, dynamic>>())
          ChapterSponsor(
            id: s['id'] as String,
            name: s['name'] as String? ?? '',
            logo: _api.picture(s['logoUrl'] as String?),
            url: CommunityApi.text(s['url']),
            tier: CommunityApi.text(s['tier']),
          ),
      ],
      leads: [
        for (final p in (json['leads'] as List? ?? const []).cast<Map<String, dynamic>>()) _person(p, ChapterRole.lead),
      ],
      upcomingEvents: events,
    );
  }

  @override
  Future<ChapterMembersPage> members(
    String slug, {
    int page = 1,
    String? search,
    MemberFilter filter = MemberFilter.all,
  }) async {
    final res = await _api.page('/chapters/$slug/members', {
      'page': page,
      'limit': membersPageSize,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (filter == MemberFilter.corporate) 'hasCompany': 'true',
      if (filter == MemberFilter.committee) 'role': 'LEAD',
    });
    return ChapterMembersPage(
      members: [for (final row in res.items) _person(row, ChapterRole.fromApi(row['role'] as String?))],
      total: res.total,
      page: res.page,
      hasNext: res.hasNext,
    );
  }

  @override
  Future<List<ChapterEvent>> events(String slug, {bool past = false}) async {
    final results = await Future.wait<Object>([
      _api.page('/events', {'chapterSlug': slug, 'when': past ? 'past' : 'upcoming', 'limit': 12}),
      _rsvps(),
    ]);
    final page = results[0] as ApiPage<Map<String, dynamic>>;
    final rsvps = results[1] as Map<String, String>;
    return [
      for (final e in page.items)
        if (CommunityApi.date(e['startsAt']) != null) _event(e).withStatus(rsvps[e['id']]),
    ];
  }

  @override
  Future<List<ChapterUpdate>> updates(String slug) async {
    final rows = await _api.getList('/chapters/$slug/announcements');
    final out = [
      for (final r in rows)
        ChapterUpdate(
          id: r['id'] as String,
          title: r['title'] as String? ?? '',
          body: r['body'] as String? ?? '',
          pinned: r['pinned'] == true,
          createdAt: CommunityApi.date(r['createdAt']),
        ),
    ];
    // Pinned first, then newest, as the website orders them.
    out.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
    });
    return out;
  }

  @override
  Future<List<ChapterResource>> resources(String slug) async {
    final rows = await _api.getList('/chapters/$slug/resources');
    return [
      for (final r in rows)
        ChapterResource(
          id: r['id'] as String,
          title: r['title'] as String? ?? '',
          kind: r['kind'] as String? ?? 'OTHER',
          url: AppConfig.absoluteUrl(r['url'] as String?, apiBase: _api.client.dio.options.baseUrl) ?? '',
          sizeLabel: CommunityApi.text(r['sizeLabel']),
          createdAt: CommunityApi.date(r['createdAt']),
        ),
    ];
  }

  @override
  Future<List<ChapterSummary>> nearby(ChapterSummary chapter) async {
    final res = await _api.page('/chapters', {'country': chapter.country, 'limit': 10});
    return [
      for (final row in res.items)
        if (row['id'] != chapter.id) _summary(row, null, null),
    ].take(4).toList();
  }

  @override
  Future<ChapterRole> join(ChapterSummary chapter) async {
    final res = await _api.send('POST', '/chapters/${chapter.id}/join');
    return ChapterRole.fromApi((res as Map?)?['status'] as String?) ?? ChapterRole.member;
  }

  @override
  Future<void> leave(ChapterSummary chapter) => _api.send('DELETE', '/chapters/${chapter.id}/join');

  @override
  Future<String> rsvp(ChapterEvent event) async {
    final res = await _api.send('POST', '/events/${event.id}/rsvp');
    return (res as Map?)?['status'] as String? ?? 'GOING';
  }

  @override
  Future<void> cancelRsvp(ChapterEvent event) => _api.send('DELETE', '/events/${event.id}/rsvp');

  @override
  Future<int> unreadNotifications() => _api.unreadNotifications();

  @override
  Uri link(ChapterSummary chapter) => AppConfig.sitePage('/chapters/${chapter.slug}');

  // --- reads ---------------------------------------------------------------

  /// A chapter by slug; an id (what a notification or a membership names) is
  /// looked up on the board first, since the API reads chapters by slug.
  Future<Map<String, dynamic>> _chapterJson(String idOrSlug) async {
    try {
      return await _api.getMap('/chapters/$idOrSlug');
    } on ApiError catch (e) {
      if (e.statusCode != 404) rethrow;
      final (rows, _) = await _api.all('/chapters');
      final match = rows.where((r) => r['id'] == idOrSlug).firstOrNull;
      if (match == null) rethrow;
      return _api.getMap('/chapters/${match['slug']}');
    }
  }

  /// The member's RSVPs by event id; none when signed out. The API keeps a CANCELLED row after a
  /// member gives a place back and lists it here, so those are dropped: a cancelled place is no RSVP.
  Future<Map<String, String>> _rsvps() async {
    final rows = await _api.mine('/events/rsvps/mine');
    return {
      for (final r in rows)
        if (r['eventId'] is String && r['status'] is String && r['status'] != 'CANCELLED')
          r['eventId'] as String: r['status'] as String,
    };
  }

  // --- mapping -------------------------------------------------------------

  static Map<String, ChapterRole?> _roles(List<Map<String, dynamic>> rows) => {
    for (final m in rows)
      if (m['chapterId'] is String) m['chapterId'] as String: ChapterRole.fromApi(m['role'] as String?),
  };

  ChapterSummary _summary(Map<String, dynamic> json, ChapterRole? role, DateTime? next) => ChapterSummary(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    slug: json['slug'] as String? ?? json['id'] as String,
    city: json['city'] as String? ?? '',
    country: json['country'] as String? ?? '',
    region: CommunityApi.text(json['region']),
    description: CommunityApi.text(json['description']),
    cover: _api.picture(json['coverUrl'] as String?),
    createdAt: CommunityApi.date(json['createdAt']),
    memberCount: CommunityApi.count(json['memberCount']),
    upcomingEventCount: CommunityApi.count(json['upcomingEventCount']),
    role: role,
    nextEventAt: next,
  );

  ChapterEvent _event(Map<String, dynamic> e) {
    final chapter = e['chapter'] as Map<String, dynamic>?;
    return ChapterEvent(
      id: e['id'] as String,
      slug: CommunityApi.text(e['slug']),
      title: e['title'] as String? ?? '',
      kind: e['kind'] as String? ?? 'OTHER',
      description: htmlParagraphs(e['description'] as String?).join(' '),
      location: CommunityApi.text(e['location']),
      startsAt: CommunityApi.date(e['startsAt'])!,
      endsAt: CommunityApi.date(e['endsAt']),
      capacity: (e['capacity'] as num?)?.toInt(),
      attendeeCount: CommunityApi.count(e['attendeeCount']),
      priceAmount: (e['priceAmount'] as num?)?.toInt(),
      inviteOnly: e['inviteOnly'] == true,
      chapterSlug: chapter?['slug'] as String?,
      chapterName: chapter?['name'] as String?,
    );
  }

  ChapterPerson _person(Map<String, dynamic> p, ChapterRole? role) {
    final company = p['company'];
    return ChapterPerson(
      id: p['id'] as String,
      firstName: p['firstName'] as String? ?? '',
      lastName: p['lastName'] as String? ?? '',
      photo: _api.picture(p['avatarUrl'] as String?),
      title: CommunityApi.text(p['title']),
      company: company is Map ? CommunityApi.text(company['name']) : null,
      linkedinUrl: CommunityApi.text(p['linkedinUrl']),
      role: role,
      joinedAt: CommunityApi.date(p['joinedAt']),
    );
  }
}
