import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../account/account_models.dart';

/// What the profile drawer shows. The live loader fills it from several
/// endpoints; the demo one holds the design's sample content.
class ProfileDrawerData {
  const ProfileDrawerData({
    required this.name,
    this.headline,
    this.location,
    this.connections,
    this.photoUrl,
    this.photoAsset,
    this.coverUrl,
    this.coverAsset,
    this.verified = false,
    this.profileViews,
    this.postImpressions,
    this.chapterCode,
    this.chapterCities = const [],
    this.councilNames = const [],
    this.cpdHours,
    this.profilePath = '/profile',
  });

  final String name;
  final String? headline;
  final String? location;

  /// Followers + following; "500+" when it goes past 500.
  final int? connections;
  final String? photoUrl;
  final String? photoAsset;
  final String? coverUrl;
  final String? coverAsset;
  final bool verified;
  final int? profileViews;
  final int? postImpressions;

  /// The member's first chapter, as a short code ("BLR").
  final String? chapterCode;

  /// The cities of the chapters the member belongs to, in the order they joined.
  final List<String> chapterCities;
  final List<String> councilNames;

  /// CPD hours earned to date (the ledger's `totalHours`), for the Volunteer row's "+12 CPD" pill.
  final double? cpdHours;

  /// The member's page on the website.
  final String profilePath;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return '${parts.first[0]}${parts.length > 1 ? parts.last[0] : ''}'.toUpperCase();
  }

  String? get connectionsLabel {
    final n = connections;
    if (n == null) return null;
    final count = n >= 500 ? '500+' : '$n';
    return n == 1 ? '1 Connection' : '$count Connections';
  }

  /// "Bengaluru, Karnataka · 500+ Connections"
  String? get locationLine {
    final parts = [?location, ?connectionsLabel];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// The Regional Chapters row's second line, as the design writes it ("Bengaluru, Mumbai, Delhi & more"): the
  /// cities of up to three chapters, then "& more" when there are others. Null when the member has no chapter.
  String? get chaptersLine {
    final cities = <String>[];
    for (final c in chapterCities) {
      final city = c.trim();
      if (city.isNotEmpty && !cities.contains(city)) cities.add(city);
    }
    if (cities.isEmpty) return null;
    return cities.length > 3 ? '${cities.take(3).join(', ')} & more' : cities.join(', ');
  }

  /// The Working Councils row's second line: the first council by its short name ("Sustainability, ESG &
  /// Net-Zero", the word Council dropped), and how many others there are ("+2"). Null with no council.
  String? get councilsLine {
    final names = [
      for (final n in councilNames)
        if (n.trim().isNotEmpty) n.trim().replaceFirst(RegExp(r'\s+Council$'), ''),
    ];
    if (names.isEmpty) return null;
    return names.length == 1 ? names.first : '${names.first} +${names.length - 1}';
  }

  /// The pill on the Volunteer row ("+12 CPD", "+8.5 CPD"); null while there is nothing to show.
  String? get cpdLabel {
    final hours = cpdHours;
    if (hours == null || hours <= 0) return null;
    final n = hours == hours.roundToDouble() ? hours.toInt().toString() : hours.toStringAsFixed(1);
    return '+$n CPD';
  }

  ProfileDrawerData copyWith({
    String? headline,
    String? location,
    int? connections,
    String? photoUrl,
    String? coverUrl,
    bool? verified,
    int? profileViews,
    int? postImpressions,
    String? chapterCode,
    List<String>? chapterCities,
    List<String>? councilNames,
    double? cpdHours,
    String? profilePath,
  }) => ProfileDrawerData(
    name: name,
    headline: headline ?? this.headline,
    location: location ?? this.location,
    connections: connections ?? this.connections,
    photoUrl: photoUrl ?? this.photoUrl,
    photoAsset: photoAsset,
    coverUrl: coverUrl ?? this.coverUrl,
    coverAsset: coverAsset,
    verified: verified ?? this.verified,
    profileViews: profileViews ?? this.profileViews,
    postImpressions: postImpressions ?? this.postImpressions,
    chapterCode: chapterCode ?? this.chapterCode,
    chapterCities: chapterCities ?? this.chapterCities,
    councilNames: councilNames ?? this.councilNames,
    cpdHours: cpdHours ?? this.cpdHours,
    profilePath: profilePath ?? this.profilePath,
  );

  /// The design's sample member.
  static const demo = ProfileDrawerData(
    name: 'Nikhil Majjagi',
    headline: 'Lead Operations Manager at TechCorp',
    location: 'Bengaluru, Karnataka',
    connections: 500,
    photoAsset: 'assets/images/demo/avatar_me.jpg',
    coverAsset: 'assets/images/demo/cover_town.jpg',
    verified: true,
    profileViews: 42,
    postImpressions: 1204,
    chapterCode: 'BLR',
    chapterCities: ['Bengaluru', 'Mumbai', 'Delhi', 'Hyderabad'],
    councilNames: ['Sustainability, ESG & Smart PropTech Council'],
    cpdHours: 12,
    profilePath: '/members/nikhil-majjagi',
  );
}

/// Short codes for the chapter badge, airport-style, as the design shows "BLR".
const _cityCodes = {
  'bengaluru': 'BLR',
  'bangalore': 'BLR',
  'mumbai': 'BOM',
  'delhi': 'DEL',
  'new delhi': 'DEL',
  'gurugram': 'GGN',
  'gurgaon': 'GGN',
  'noida': 'NOI',
  'hyderabad': 'HYD',
  'chennai': 'MAA',
  'pune': 'PNQ',
  'kolkata': 'CCU',
  'ahmedabad': 'AMD',
  'kochi': 'COK',
  'jaipur': 'JAI',
  'chandigarh': 'IXC',
};

String chapterCodeFor(String city) {
  final key = city.trim().toLowerCase();
  final code = _cityCodes[key];
  if (code != null) return code;
  final letters = key.replaceAll(RegExp(r'[^a-z]'), '');
  return letters.length >= 3 ? letters.substring(0, 3).toUpperCase() : letters.toUpperCase();
}

/// Loads the drawer for the signed-in member. Each endpoint fails on its own:
/// a line the API cannot fill stays empty rather than hiding the drawer.
class ProfileDrawerController extends ChangeNotifier {
  ProfileDrawerController.live({required this.api, required this.userId, required ProfileDrawerData seed})
    : _data = seed,
      _demo = false;

  ProfileDrawerController.demo()
    : api = null,
      userId = null,
      _data = ProfileDrawerData.demo,
      _demo = true,
      _loaded = true;

  final ApiClient? api;
  final String? userId;
  final bool _demo;
  ProfileDrawerData _data;
  bool _loaded = false;
  bool _loading = false;

  ProfileDrawerData get data => _data;
  bool get loaded => _loaded;

  /// "Your companies" as the menu last read it. The menu's body is built afresh each time it opens, so this is
  /// what it shows at once, while it reads the list again.
  MyCompanies? cachedCompanies;

  Future<void> ensureLoaded() {
    if (_loaded || _loading) return Future.value();
    return refresh();
  }

  Future<void> refresh() async {
    if (_demo || api == null) return;
    _loading = true;
    try {
      await Future.wait([_profile(), _member(), _performance(), _impressions(), _cpd()]);
      _loaded = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> _get(String path, [Map<String, dynamic>? query]) async {
    try {
      final res = await api!.dio.get<Map<String, dynamic>>(path, queryParameters: query);
      return res.data;
    } catch (_) {
      return null;
    }
  }

  /// `GET /users/me/profile`: the headline on file, the cover, the company.
  Future<void> _profile() async {
    final json = await _get('/users/me/profile');
    if (json == null) return;
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    final company = json['company'] as Map<String, dynamic>?;
    final resume = json['resume'] as Map<String, dynamic>?;
    final designation = (user['designation'] as String?)?.trim();
    final companyName = (company?['name'] as String?)?.trim();
    final headline = designation != null && designation.isNotEmpty
        ? (companyName != null && companyName.isNotEmpty && !designation.contains(companyName)
              ? '$designation at $companyName'
              : designation)
        : null;
    final base = api!.dio.options.baseUrl;
    _data = _data.copyWith(
      headline: headline,
      photoUrl: AppConfig.absoluteUrl(user['avatarUrl'] as String?, apiBase: base),
      coverUrl: AppConfig.absoluteUrl(user['coverImage'] as String?, apiBase: base),
      location: _data.location ?? (resume?['location'] as String?) ?? (company?['city'] as String?),
      profilePath: user['profileSlug'] is String ? '/members/${user['profileSlug']}' : null,
    );
    notifyListeners();
  }

  /// `GET /members/:id`: the current role's city, chapters, councils, follows.
  Future<void> _member() async {
    final json = await _get('/members/$userId');
    if (json == null) return;
    final follow = json['follow'] as Map<String, dynamic>?;
    final chapters = (json['chapters'] as List? ?? const []).cast<Map<String, dynamic>>();
    final councils = (json['councils'] as List? ?? const []).cast<Map<String, dynamic>>();
    final city = json['city'] as String?;
    final headline = (json['headline'] as String?)?.replaceFirst(' · ', ' at ');
    _data = _data.copyWith(
      headline: _data.headline ?? headline,
      location: city ?? _data.location,
      connections: follow == null
          ? null
          : ((follow['followers'] as num?)?.toInt() ?? 0) + ((follow['following'] as num?)?.toInt() ?? 0),
      chapterCode: chapters.isEmpty ? null : chapterCodeFor(chapters.first['city'] as String? ?? ''),
      chapterCities: chapters.map((c) => c['city'] as String? ?? '').where((n) => n.isNotEmpty).toList(),
      councilNames: councils.map((c) => c['name'] as String? ?? '').where((n) => n.isNotEmpty).toList(),
      profilePath: json['profileSlug'] is String ? '/members/${json['profileSlug']}' : null,
    );
    notifyListeners();
  }

  /// `GET /users/me/profile-performance`: how many recruiters opened the profile.
  Future<void> _performance() async {
    final json = await _get('/users/me/profile-performance');
    final views = (json?['profileViewsTotal'] as num?)?.toInt();
    if (views == null) return;
    _data = _data.copyWith(profileViews: views);
    notifyListeners();
  }

  /// Post impressions: how often the member's discussions were opened.
  Future<void> _impressions() async {
    final json = await _get('/forum/threads', {'authorId': userId, 'limit': 100});
    final rows = (json?['data'] as List?)?.cast<Map<String, dynamic>>();
    if (rows == null) return;
    _data = _data.copyWith(postImpressions: rows.fold<int>(0, (n, t) => n + ((t['viewCount'] as num?)?.toInt() ?? 0)));
    notifyListeners();
  }

  /// `GET /mentorship/cpd/summary`: the CPD hours the member has earned to date (`totalHours`; the Events board
  /// reads the same ledger for its year, `hoursThisYear`).
  Future<void> _cpd() async {
    final json = await _get('/mentorship/cpd/summary');
    final hours = (json?['totalHours'] as num?)?.toDouble();
    if (hours == null) return;
    _data = _data.copyWith(cpdHours: hours);
    notifyListeners();
  }
}
