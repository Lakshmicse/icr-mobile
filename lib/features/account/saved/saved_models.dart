/// What the Saved items screen draws: one model per kind of bookmark the API
/// keeps for a member. Each parses the real answer of its list endpoint:
///
/// | Kind | List | Save / un-save |
/// |---|---|---|
/// | jobs | `GET /jobs/saved` | `POST` / `DELETE /jobs/:id/save` |
/// | mentors | `GET /mentorship/mentors/saved` | `POST` / `DELETE /mentorship/mentors/:id/save` |
/// | suppliers | `GET /vendors/saved` | `POST` / `DELETE /vendors/:id/save` |
/// | councils | `GET /councils/saves/mine` | `POST` / `DELETE /councils/:id/save` |
/// | discussions | `GET /forum/saves/mine` | `POST` / `DELETE /forum/threads/:id/save` |
library;

/// A kind of bookmark: one chip on the screen.
enum SavedKind {
  jobs('Jobs', 'No saved jobs yet', 'Tap the bookmark on a job on the Jobs board to keep it here.'),
  mentors('Mentors', 'No saved mentors yet', 'Save a mentor from Find mentors to come back to them.'),
  suppliers('Suppliers', 'No saved suppliers yet', 'Save a supplier from the Marketplace to keep it here.'),
  councils('Councils', 'No saved councils yet', 'Bookmark a council on the Councils screen to find it here.'),
  discussions('Discussions', 'No saved discussions yet', 'Save a discussion in Forums to read it later.');

  const SavedKind(this.label, this.emptyTitle, this.emptyHint);

  /// The chip's word.
  final String label;
  final String emptyTitle;

  /// Where to save one.
  final String emptyHint;
}

/// One bookmark. [id] is what the save endpoints take: a job's id, a mentor
/// profile's id, a supplier listing's id, a council's id or a discussion's id.
sealed class SavedItem {
  const SavedItem({required this.id, this.savedAt});

  final String id;

  /// When the member saved it (jobs, suppliers and councils say).
  final DateTime? savedAt;

  SavedKind get kind;

  /// The line a row leads with, and what the un-save snackbar names.
  String get title;
}

// --- jobs -------------------------------------------------------------------------------------------------------

/// A saved job. A posting that is no longer open arrives as a stub (the API
/// sends only that it is gone, and whose it was): [closed], with no title.
class SavedJob extends SavedItem {
  const SavedJob({
    required super.id,
    super.savedAt,
    this.jobTitle,
    this.companyId = '',
    this.companyName = 'A company on ICR',
    this.companyLogo,
    this.city,
    this.state,
    this.country,
    this.workMode,
    this.employmentType,
    this.salary,
    this.postedAt,
    this.status = 'OPEN',
  });

  /// Null for a stub.
  final String? jobTitle;
  final String companyId;
  final String companyName;
  final String? companyLogo;
  final String? city;
  final String? state;
  final String? country;

  /// "On-site", "Remote", "Hybrid".
  final String? workMode;

  /// "Full-time".
  final String? employmentType;

  /// "₹18L - ₹25L / yr"; null when the employer keeps it private.
  final String? salary;
  final DateTime? postedAt;

  /// The job's status: `OPEN`, or what a stub says it became.
  final String status;

  @override
  SavedKind get kind => SavedKind.jobs;

  /// A job nobody can apply to any more: the API sends only a stub.
  bool get closed => jobTitle == null || status != 'OPEN';

  @override
  String get title => jobTitle ?? 'A role at $companyName';

  /// "Mumbai, India".
  String? get place {
    final parts = [?_text(city), ?_text(country)];
    return parts.isEmpty ? _text(state) : parts.join(', ');
  }

  /// "Mumbai, India • On-site • Full-time".
  String get facts => [?place, ?workMode, ?employmentType].join(' • ');

  factory SavedJob.fromJson(Map<String, dynamic> j) {
    final company = _map(j['company']);
    final title = _text(j['title']);
    return SavedJob(
      id: '${j['id']}',
      savedAt: _date(j['savedAt']),
      jobTitle: title,
      companyId: _text(company['id']) ?? _text(j['companyId']) ?? '',
      companyName: _text(company['name']) ?? 'A company on ICR',
      companyLogo: _text(company['logoUrl']),
      city: _text(j['city']) ?? _text(company['city']),
      state: _text(j['state']),
      country: _text(j['country']),
      workMode: switch (j['workMode']) {
        'ONSITE' => 'On-site',
        'REMOTE' => 'Remote',
        'HYBRID' => 'Hybrid',
        _ => null,
      },
      employmentType: switch (j['employmentType']) {
        'FULL_TIME' => 'Full-time',
        'PART_TIME' => 'Part-time',
        'CONTRACT' => 'Contract',
        'INTERNSHIP' => 'Internship',
        'TEMPORARY' => 'Temporary',
        'FREELANCE' => 'Freelance',
        'VOLUNTEER' => 'Volunteer',
        _ => null,
      },
      salary: title == null ? null : salaryLine(j),
      postedAt: _date(j['publishedAt']) ?? _date(j['createdAt']),
      status: _text(j['status']) ?? 'OPEN',
    );
  }

  /// "₹18L - ₹25L / yr", as the Jobs board writes it; null when hidden or unset.
  static String? salaryLine(Map<String, dynamic> j) {
    if (j['salaryVisible'] == false) return null;
    final values = [?_number(j['salaryMin']), ?_number(j['salaryMax'])].where((v) => v > 0).toList();
    if (values.isEmpty) return null;
    final currency = _text(j['salaryCurrency']);
    final rupees = currency == null || currency == 'INR';
    final symbol = rupees ? '₹' : '$currency ';
    final period = switch (j['salaryPeriod']) {
      'MONTHLY' => '/ mo',
      'HOURLY' => '/ hr',
      _ => '/ yr',
    };
    return '${values.map((v) => _short(v, symbol, rupees)).join(' - ')} $period';
  }

  /// Lakh and crore for rupees, thousand and million for any other currency.
  static String _short(double n, String symbol, bool rupees) {
    String trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
    if (rupees) {
      if (n >= 1e7) return '$symbol${trim(n / 1e7)}Cr';
      if (n >= 1e5) return '$symbol${trim(n / 1e5)}L';
    } else if (n >= 1e6) {
      return '$symbol${trim(n / 1e6)}M';
    }
    if (n >= 1e3) return '$symbol${trim(n / 1e3)}K';
    return '$symbol${n.round()}';
  }
}

// --- mentors ----------------------------------------------------------------------------------------------------

/// A saved mentor (`MentorCardDto`).
class SavedMentor extends SavedItem {
  const SavedMentor({
    required super.id,
    super.savedAt,
    required this.name,
    this.userId,
    this.photo,
    this.headline,
    this.role,
    this.expertise = const [],
    this.rating = 0,
    this.ratingCount = 0,
    this.topMentor = false,
    this.approved = true,
    this.city,
    this.planFromPaisa,
  });

  /// The member's user id (their public profile).
  final String? userId;
  final String name;
  final String? photo;
  final String? headline;

  /// "Director @ DLF": the current role.
  final String? role;

  /// Competency domains.
  final List<String> expertise;
  final double rating;
  final int ratingCount;
  final bool topMentor;
  final bool approved;
  final String? city;

  /// The cheapest plan per month, in paise.
  final int? planFromPaisa;

  @override
  SavedKind get kind => SavedKind.mentors;

  @override
  String get title => name;

  /// "Director @ DLF", else the headline.
  String get roleLine => _text(role) ?? _text(headline) ?? '';

  String get initials => initialsOf(name);

  factory SavedMentor.fromJson(Map<String, dynamic> j) {
    final user = _map(j['user']);
    final current = _map(_map(j['career'])['currentRole']);
    final currentTitle = _text(current['title']);
    final organisation = _text(current['organisation']);
    final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    return SavedMentor(
      id: '${j['id']}',
      savedAt: _date(j['savedAt']),
      userId: _text(user['id']),
      name: name.isEmpty ? 'ICR mentor' : name,
      photo: _text(user['avatarUrl']),
      headline: _text(j['headline']),
      role: currentTitle == null
          ? null
          : organisation == null
          ? currentTitle
          : '$currentTitle @ $organisation',
      expertise: _strings(j['competencies']).toSet().toList(),
      rating: _number(j['rating']) ?? 0,
      ratingCount: _number(j['ratingCount'])?.toInt() ?? 0,
      topMentor: j['isTopMentor'] == true,
      approved: j['status'] == null || j['status'] == 'APPROVED',
      city: _text(j['city']),
      planFromPaisa: _number(j['planFromPaisa'])?.toInt(),
    );
  }
}

// --- suppliers --------------------------------------------------------------------------------------------------

/// A saved supplier listing: a `GET /vendors` row plus when it was saved.
class SavedSupplier extends SavedItem {
  const SavedSupplier({
    required super.id,
    super.savedAt,
    required this.companyId,
    required this.name,
    this.logo,
    this.headline,
    this.city,
    this.state,
    this.level,
    this.rating = 0,
    this.ratingCount = 0,
    this.premium = false,
    this.gstRegistered = false,
  });

  /// The company's id (its page is `/companies/<id>`).
  final String companyId;
  final String name;
  final String? logo;

  /// The supplier's one-line pitch.
  final String? headline;
  final String? city;
  final String? state;

  /// "Verified", "Certified"... from the trust ladder; null for a plain "Registered".
  final String? level;
  final double rating;
  final int ratingCount;
  final bool premium;
  final bool gstRegistered;

  @override
  SavedKind get kind => SavedKind.suppliers;

  @override
  String get title => name;

  /// "Pune, Maharashtra".
  String? get place {
    final parts = [?_text(city), ?_text(state)];
    return parts.isEmpty ? null : parts.join(', ');
  }

  factory SavedSupplier.fromJson(Map<String, dynamic> j) {
    final company = _map(j['company']);
    final level = _text(j['verificationLevel']) ?? _text(company['verificationLevel']);
    return SavedSupplier(
      id: '${j['id']}',
      savedAt: _date(j['savedAt']),
      companyId: _text(j['companyId']) ?? _text(company['id']) ?? '',
      name: _text(company['name']) ?? 'Supplier',
      logo: _text(company['logoUrl']),
      headline: _text(j['headline']),
      city: _text(company['city']),
      state: _text(company['state']),
      level: switch (level) {
        'VERIFIED' => 'Verified',
        'CERTIFIED' => 'Certified',
        'PREFERRED' => 'Preferred',
        'ELITE' => 'Elite',
        _ => null,
      },
      rating: _number(j['rating']) ?? _number(company['ratingAvg']) ?? 0,
      ratingCount: _number(j['ratingCount'])?.toInt() ?? _number(company['ratingCount'])?.toInt() ?? 0,
      premium: j['isPremium'] == true,
      gstRegistered: company['gstRegistered'] == true,
    );
  }
}

// --- councils ---------------------------------------------------------------------------------------------------

/// A bookmarked council (`CouncilSaveDto`: the save, with a short council).
class SavedCouncil extends SavedItem {
  const SavedCouncil({
    required super.id,
    super.savedAt,
    required this.slug,
    required this.name,
    this.memberCount = 0,
    this.upcomingEventCount = 0,
  });

  /// The council's page address, `/councils/<slug>`.
  final String slug;
  final String name;
  final int memberCount;
  final int upcomingEventCount;

  @override
  SavedKind get kind => SavedKind.councils;

  @override
  String get title => name;

  factory SavedCouncil.fromJson(Map<String, dynamic> j) {
    final council = _map(j['council']);
    return SavedCouncil(
      id: '${j['councilId'] ?? council['id']}',
      savedAt: _date(j['savedAt']),
      slug: _text(council['slug']) ?? '',
      name: _text(council['name']) ?? 'Council',
      memberCount: _number(council['memberCount'])?.toInt() ?? 0,
      upcomingEventCount: _number(council['upcomingEventCount'])?.toInt() ?? 0,
    );
  }
}

// --- discussions ------------------------------------------------------------------------------------------------

/// A saved forum discussion (`ForumThreadCardDto`).
class SavedThread extends SavedItem {
  const SavedThread({
    required super.id,
    super.savedAt,
    required this.slug,
    required this.threadTitle,
    this.excerpt = '',
    this.kindLabel,
    this.topic,
    this.authorName = 'An ICR member',
    this.authorPhoto,
    this.replyCount = 0,
    this.viewCount = 0,
    this.likes = 0,
    this.answered = false,
    this.lastActivityAt,
    this.createdAt,
  });

  /// The discussion's page address, `/community/<slug>`.
  final String slug;
  final String threadTitle;

  /// The opening of the post, as plain text.
  final String excerpt;

  /// "Question", "Announcement"; null for a plain discussion.
  final String? kindLabel;

  /// The topic it is filed under ("Facility Management").
  final String? topic;
  final String authorName;
  final String? authorPhoto;
  final int replyCount;
  final int viewCount;
  final int likes;

  /// A question with an accepted answer.
  final bool answered;
  final DateTime? lastActivityAt;
  final DateTime? createdAt;

  @override
  SavedKind get kind => SavedKind.discussions;

  @override
  String get title => threadTitle;

  String get authorInitials => initialsOf(authorName);

  factory SavedThread.fromJson(Map<String, dynamic> j) {
    final author = _map(j['author']);
    final name = '${author['firstName'] ?? ''} ${author['lastName'] ?? ''}'.trim();
    return SavedThread(
      id: '${j['id']}',
      savedAt: _date(j['savedAt']),
      slug: _text(j['slug']) ?? '${j['id']}',
      threadTitle: _text(j['title']) ?? 'A discussion',
      excerpt: _text(j['excerpt']) ?? '',
      kindLabel: switch (j['kind']) {
        'QUESTION' => 'Question',
        'ANNOUNCEMENT' => 'Announcement',
        _ => null,
      },
      topic: _text(_map(j['category'])['name']),
      authorName: name.isEmpty ? 'An ICR member' : name,
      authorPhoto: _text(author['avatarUrl']),
      replyCount: _number(j['replyCount'])?.toInt() ?? 0,
      viewCount: _number(j['viewCount'])?.toInt() ?? 0,
      likes: _number(j['likes'])?.toInt() ?? 0,
      answered: j['hasAcceptedAnswer'] == true,
      lastActivityAt: _date(j['lastActivityAt']),
      createdAt: _date(j['createdAt']),
    );
  }
}

// --- a page of them ---------------------------------------------------------------------------------------------

/// One answer of a list endpoint: the rows, the member's total for the kind
/// (`meta.total`) and whether another page follows (`meta.hasNext`).
class SavedPage {
  const SavedPage({required this.items, required this.total, this.hasNext = false});

  final List<SavedItem> items;
  final int total;
  final bool hasNext;
}

/// The two letters a round photo shows when there is no picture.
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  String letter(String word) => String.fromCharCode(word.runes.first);
  return '${letter(words.first)}${words.length > 1 ? letter(words.last) : ''}'.toUpperCase();
}

// --- reading JSON -----------------------------------------------------------------------------------------------

String? _text(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

Map<String, dynamic> _map(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};

/// A number the API may send as a JSON number or, for a decimal column, a string.
double? _number(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

List<String> _strings(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is String && e.trim().isNotEmpty) e.trim(),
      ]
    : const [];
