import 'package:dio/dio.dart' show Options;

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/config.dart';
import 'mentorship_format.dart';
import 'mentorship_models.dart';
import 'mentorship_repository.dart';

/// The Mentorship screens from the API: the public directory
/// (`GET /mentorship/mentors` and its `facets`), the public stats, the open
/// cohort programmes, the top mentors' storefronts, and what is known about
/// the viewer (saved mentors, who they follow, their company and their own
/// focus areas) for "Top Mentors in Your Network" and the selected topics.
class ApiMentorshipRepository implements MentorshipRepository {
  ApiMentorshipRepository({required this.api});

  final ApiClient api;

  Set<String>? _savedIds;

  /// The directory design shows eight cards a page.
  static const pageSize = 8;

  /// How many category chips the landing offers, and how many topic chips.
  static const _categoryCount = 8;
  static const _topicCount = 9;
  static const _companyCount = 8;
  static const _shelfSize = 8;

  /// Storefronts read for "Featured Advisory Sessions", and cards shown.
  static const _storefrontReads = 6;
  static const _serviceCount = 3;

  @override
  Future<MentorshipOverview> overview({String? category}) async {
    final competencies = _facet((await _get('/mentorship/mentors/facets'))['competencies']);
    final categories = competencies.take(_categoryCount).toList();
    // The design opens with the most-listed domain lit, and the shelves are its.
    final chosen = category ?? categories.firstOrNull?.label;
    final scope = <String, dynamic>{'competencies': ?chosen};
    final results = await Future.wait([
      _rows('/mentorship/mentors', {'limit': 48, 'sortBy': 'rating', 'sortDir': 'desc', ...scope}, required: true),
      _rows('/mentorship/mentors', {
        'limit': 24,
        'sortBy': 'sessionsCompleted',
        'sortDir': 'desc',
        ...scope,
      }, required: true),
      _stats(),
      _openCohort(),
      _viewer(),
    ]);
    final rated = (results[0] as List<Map<String, dynamic>>).map(_mentor).toList();
    final busiest = (results[1] as List<Map<String, dynamic>>).map(_mentor).toList();
    final listedMentors = results[2] as int;
    final cohort = results[3] as MentorCohort?;
    final viewer = results[4] as _Viewer;

    final topics = toneTopics(competencies.skip(_categoryCount).take(_topicCount).toList(), viewer.focusAreas);

    // Both grids carry the design's title. The first is the viewer's network
    // (saved, followed, same employer) ahead of the best rated; the second is
    // the most sessions delivered, without repeating a face from the first.
    final first = networkFirst(
      rated,
      saved: _savedIds ?? const {},
      followed: viewer.followedUsers,
      company: viewer.company,
    ).take(_shelfSize).toList();
    final shown = first.map((m) => m.id).toSet();
    final second = busiest.where((m) => !shown.contains(m.id)).take(_shelfSize).toList();

    return MentorshipOverview(
      categories: categories,
      selectedCategory: chosen,
      domainsBadge: domainsBadgeFor(competencies.length),
      companies: groupByEmployer(rated).take(_companyCount).toList(),
      shelves: [
        if (first.isNotEmpty) MentorShelf(key: 'network', title: mentorNetworkTitle, mentors: first),
        if (second.isNotEmpty) MentorShelf(key: 'network-2', title: mentorNetworkTitle, mentors: second),
      ],
      topics: topics,
      banner: MentorBanner(
        title: 'Become an ICR Mentor & Shape the Next Generation',
        body: bannerBody(listedMentors),
        cta: 'Apply as Mentor',
        photo: mentorBannerPhoto,
        link: '/become-a-mentor',
      ),
      cohort: cohort,
      services: await _featuredServices(first),
    );
  }

  @override
  Future<List<MentorCategory>> categories() async => _facet((await _get('/mentorship/mentors/facets'))['competencies']);

  @override
  Future<MentorPage> search(MentorFilters filters, {int page = 1}) async {
    await _flags();
    final res = await _get('/mentorship/mentors', directoryQuery(filters, page: page));
    final rows = (res['data'] as List? ?? const []).cast<Map<String, dynamic>>();
    final meta = res['meta'] as Map<String, dynamic>? ?? const {};
    return MentorPage(
      mentors: rows.map(_mentor).toList(),
      total: (meta['total'] as num?)?.toInt() ?? rows.length,
      hasMore: meta['hasNext'] == true,
    );
  }

  /// The query of one directory page. A company that is on mentors' ICR
  /// accounts filters on `companies`; one known only from a current-role line
  /// can be found only by its words, which the directory's `search` matches in
  /// a mentor's headline, so it goes there (the chip is the member's view of it,
  /// never words in the search box). Typed words win over a role-only company.
  static Map<String, dynamic> directoryQuery(MentorFilters filters, {int page = 1, int limit = pageSize}) {
    final company = filters.company;
    final roleOnly = company != null && !filters.companyOnAccount;
    final words = filters.search.isNotEmpty ? filters.search : (roleOnly ? company : null);
    return {
      'page': page,
      'limit': limit,
      'sortBy': filters.sort.name,
      'sortDir': 'desc',
      if (filters.category != null) 'competencies': filters.category,
      'search': ?words,
      if (company != null && filters.companyOnAccount) 'companies': company,
      if (filters.minExperience != null) 'minExperience': filters.minExperience,
      if (filters.availableOnly) 'availableOnly': true,
    };
  }

  @override
  Future<void> setSaved(Mentor mentor, bool saved) async {
    await _send(saved ? 'POST' : 'DELETE', '/mentorship/mentors/${mentor.id}/save');
    saved ? (_savedIds ??= {}).add(mentor.id) : _savedIds?.remove(mentor.id);
  }

  @override
  Future<int> unreadNotifications() async {
    final res = await _get('/notifications/unread-count');
    return (res['unread'] as num?)?.toInt() ?? 0;
  }

  @override
  Uri link(Mentor mentor) => AppConfig.sitePage('/mentorship/mentors/${mentor.id}');

  // --- mapping -------------------------------------------------------------

  Mentor _mentor(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    final company = user['company'] as Map<String, dynamic>?;
    final career = json['career'] as Map<String, dynamic>?;
    final current = career?['currentRole'] as Map<String, dynamic>?;
    final coverImage = json['coverImage'] as String?;
    final uploaded = coverImage != null && coverImage.startsWith('/uploads/');
    final accountCompany = (company?['name'] as String?)?.trim();
    final roleCompany = (current?['organisation'] as String?)?.trim();
    final companyName = accountCompany?.isNotEmpty == true ? accountCompany : roleCompany;
    return Mentor(
      id: json['id'] as String,
      userId: user['id'] as String?,
      name: '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim(),
      headline: json['headline'] as String?,
      role: current == null ? null : '${current['title']} @ ${current['organisation']}',
      avatar: _picture(user['avatarUrl'] as String?),
      cover: uploaded ? _picture(coverImage) : null,
      coverPreset: coverImage != null && !uploaded ? coverImage : null,
      expertise: _strings(json['competencies']),
      approved: json['status'] == 'APPROVED',
      topMentor: json['isTopMentor'] == true,
      featured: json['featured'] == true,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      yearsExperience: (json['yearsExperience'] as num?)?.toInt(),
      companyName: companyName?.isNotEmpty == true ? companyName : null,
      companyLogo: _picture(company?['logoUrl'] as String?),
      companyOnAccount: accountCompany?.isNotEmpty == true,
      saved: _savedIds?.contains(json['id']) ?? false,
    );
  }

  /// "Your network": the mentors the viewer saved or follows, or who work at
  /// the viewer's own company, ahead of everyone else; each group keeps its
  /// order (best rated first). ICR has no connections graph, so these are the
  /// ties it does have; with none, the list is the best rated, unchanged.
  static List<Mentor> networkFirst(
    List<Mentor> mentors, {
    Set<String> saved = const {},
    Set<String> followed = const {},
    String? company,
  }) {
    final mine = company?.trim().toLowerCase();
    bool tied(Mentor m) =>
        saved.contains(m.id) ||
        (m.userId != null && followed.contains(m.userId)) ||
        (mine != null && mine.isNotEmpty && m.companyName?.trim().toLowerCase() == mine);
    return [...mentors.where(tied), ...mentors.where((m) => !tied(m))];
  }

  /// Tints the topic chips as the design does: red for the topics the member
  /// selected (their own focus areas when any is among these topics, else the
  /// two most-listed), blue for the two most-listed others, as suggestions.
  /// [topics] come most-listed first.
  static List<MentorTopic> toneTopics(List<MentorCategory> topics, Set<String> focusAreas) {
    final own = focusAreas.map((f) => f.trim().toLowerCase()).toSet();
    var selected = {
      for (final (i, t) in topics.indexed)
        if (own.contains(t.label.toLowerCase())) i,
    };
    if (selected.isEmpty) selected = {for (var i = 0; i < topics.length && i < 2; i++) i};
    final suggested = [
      for (var i = 0; i < topics.length; i++)
        if (!selected.contains(i)) i,
    ].take(2).toSet();
    return [
      for (final (i, t) in topics.indexed)
        MentorTopic(
          t.label,
          tone: selected.contains(i)
              ? TopicTone.red
              : suggested.contains(i)
              ? TopicTone.blue
              : TopicTone.neutral,
        ),
    ];
  }

  /// The employers behind the directory, as the website's landing groups
  /// them: the company on the mentor's account, else the organisation on
  /// their current role; most mentors first.
  static List<MentorCompany> groupByEmployer(List<Mentor> mentors) {
    final map = <String, MentorCompany>{};
    for (final m in mentors) {
      final name = m.companyName;
      if (name == null) continue;
      final key = name.toLowerCase();
      final row = map[key];
      map[key] = MentorCompany(
        name: row?.name ?? name,
        logo: row?.logo ?? m.companyLogo,
        mentors: (row?.mentors ?? 0) + 1,
        onAccount: (row?.onAccount ?? false) || m.companyOnAccount,
      );
    }
    final out = map.values.toList()
      ..sort((a, b) => b.mentors != a.mentors ? b.mentors.compareTo(a.mentors) : a.name.compareTo(b.name));
    return out;
  }

  /// The banner's sentence, the design's own with the live count rounded down:
  /// "Join 60+ senior leaders guiding emerging facility managers and corporate
  /// real estate professionals."
  static String bannerBody(int listedMentors) => listedMentors > 0
      ? 'Join ${plusCount(listedMentors)} senior leaders guiding emerging facility managers and corporate real '
            'estate professionals.'
      : 'Join senior leaders guiding emerging facility managers and corporate real estate professionals.';

  MentorCohort _cohort(Map<String, dynamic> json) {
    final organiser = json['organiser'] as Map<String, dynamic>?;
    final count = (json['enrolmentCount'] as num?)?.toInt() ?? 0;
    final initials = '${_initial(organiser?['firstName'])}${_initial(organiser?['lastName'])}'.toUpperCase();
    final slug = json['slug'] as String?;
    return MentorCohort(
      id: json['id'] as String,
      slug: slug,
      name: json['name'] as String? ?? 'Cohort programme',
      registeredLabel: '$count Registered',
      // The API does not say who registered: the organiser's circle, then one
      // for everyone else ("+31").
      avatars: [
        if (organiser != null && initials.isNotEmpty)
          CohortAvatar(initials: initials, photo: _picture(organiser['avatarUrl'] as String?)),
        if (count > 1) CohortAvatar(initials: '+${count - 1}'),
      ],
      cover: _picture(json['coverUrl'] as String?),
      link: slug == null ? '/mentorship/programmes' : '/mentorship/programmes/$slug',
    );
  }

  static String _initial(Object? name) => name is String && name.trim().isNotEmpty ? name.trim()[0] : '';

  MentorService? _service(Map<String, dynamic> json, {required bool featured}) {
    final kind = MentorServiceKind.fromApi(json['type'] as String?);
    if (kind == null || json['active'] == false) return null;
    return MentorService(
      id: json['id'] as String,
      mentorId: json['mentorProfileId'] as String,
      kind: kind,
      title: json['title'] as String? ?? kind.label,
      blurb: json['blurb'] as String?,
      durationMin: (json['durationMin'] as num?)?.toInt(),
      slaHours: (json['slaHours'] as num?)?.toInt(),
      pricePaisa: (json['pricePaisa'] as num?)?.toInt() ?? 0,
      featured: featured,
    );
  }

  static List<MentorCategory> _facet(Object? v) {
    final rows = (v as List? ?? const []).cast<Map<String, dynamic>>();
    final out = [
      for (final r in rows)
        if (r['label'] is String && (r['label'] as String).isNotEmpty)
          MentorCategory(label: r['label'] as String, count: (r['count'] as num?)?.toInt() ?? 0),
    ]..sort((a, b) => b.count.compareTo(a.count));
    return out;
  }

  static List<String> _strings(Object? v) => (v as List? ?? const []).map((e) => e.toString()).toList();

  FeedPicture? _picture(String? path) {
    final url = AppConfig.absoluteUrl(path, apiBase: api.dio.options.baseUrl);
    return url == null ? null : FeedPicture.network(url);
  }

  // --- the pieces around the directory ----------------------------------------

  Future<int> _stats() async {
    try {
      final res = await _get('/mentorship/public-stats');
      return (res['listedMentors'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<MentorCohort?> _openCohort() async {
    final rows = await _rows('/mentorship/programmes', {'status': 'OPEN', 'limit': 1});
    return rows.isEmpty ? null : _cohort(rows.first);
  }

  /// What the API knows of the viewer that the landing uses: the saved mentors
  /// (kept for the screen's life), the members they follow, the company they
  /// act for and the focus areas on their mentee profile. Each read is an aid:
  /// one that fails leaves that signal out.
  Future<_Viewer> _viewer() async {
    final results = await Future.wait([_flags(), _followedUsers(), _focusAreas(), _companyName()]);
    return _Viewer(
      followedUsers: results[1] as Set<String>,
      focusAreas: results[2] as Set<String>,
      company: results[3] as String?,
    );
  }

  Future<Set<String>> _followedUsers() async {
    try {
      final res = await _get('/members/me/following', {'limit': 100});
      return {
        for (final r in (res['data'] as List? ?? const []).cast<Map<String, dynamic>>())
          if (r['id'] is String) r['id'] as String,
      };
    } catch (_) {
      return const {};
    }
  }

  /// `GET /mentorship/mentees/me`: answers with an empty body until the member
  /// has made a mentee profile.
  Future<Set<String>> _focusAreas() async {
    try {
      final res = await api.dio.get<dynamic>('/mentorship/mentees/me');
      final body = res.data;
      return body is Map ? _strings(body['focusAreas']).toSet() : const {};
    } catch (_) {
      return const {};
    }
  }

  Future<String?> _companyName() async {
    try {
      final companyId = (await _get('/auth/me'))['companyId'] as String?;
      if (companyId == null || companyId.isEmpty) return null;
      return (await _get('/companies/$companyId'))['name'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Offerings from the first live storefronts among the top mentors. There is
  /// no cross-mentor list of services, so this reads a few storefronts and
  /// stops at three cards.
  Future<List<MentorService>> _featuredServices(List<Mentor> mentors) async {
    final out = <MentorService>[];
    for (final mentor in mentors.take(_storefrontReads)) {
      if (out.length >= _serviceCount) break;
      try {
        final res = await _get('/mentor-services/mentors/${mentor.id}');
        if (res['live'] != true) continue;
        for (final row in (res['services'] as List? ?? const []).cast<Map<String, dynamic>>()) {
          final service = _service(row, featured: out.isEmpty);
          if (service != null) out.add(service);
          if (out.length >= _serviceCount) break;
        }
      } catch (_) {
        // A storefront that cannot be read is simply not featured.
      }
    }
    return out;
  }

  Future<void> _flags() async {
    if (_savedIds != null) return;
    try {
      final res = await _get('/mentorship/mentors/saved/ids');
      _savedIds = _strings(res['ids']).toSet();
    } catch (_) {
      _savedIds = {};
    }
  }

  // --- transport -------------------------------------------------------------

  /// The rows of a list. A list the screen cannot do without ([required], the
  /// two mentor grids) lets its failure through, so the landing says it could
  /// not load (and "Try again" works) instead of drawing empty shelves; the
  /// others (the cohort) are simply left out.
  Future<List<Map<String, dynamic>>> _rows(String path, Map<String, dynamic> query, {bool required = false}) async {
    try {
      final res = await _get(path, query);
      return (res['data'] as List? ?? const []).cast<Map<String, dynamic>>();
    } catch (_) {
      if (required) rethrow;
      return const [];
    }
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

/// What the landing knows about the person looking at it.
class _Viewer {
  const _Viewer({this.followedUsers = const {}, this.focusAreas = const {}, this.company});

  /// Account ids of the members they follow.
  final Set<String> followedUsers;

  /// The competency domains on their mentee profile.
  final Set<String> focusAreas;

  /// The company they act for.
  final String? company;
}
