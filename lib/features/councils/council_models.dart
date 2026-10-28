/// What the Councils screen draws. The live source fills it from
/// `GET /councils`, `GET /councils/memberships/mine`, `GET /events` and
/// `GET /chapters`; the demo source holds the design's sample content.
library;

import '../feed/feed_models.dart' show FeedPicture;

export '../feed/feed_models.dart' show FeedPicture;

/// The member's standing in a council (`AssociationRole`).
enum CouncilRole {
  member('Member'),
  lead('Executive Seat');

  const CouncilRole(this.label);

  /// How the joined-councils rail names the seat.
  final String label;

  /// The short word the council card's pill uses beside "JOINED".
  String get short => this == lead ? 'Executive' : 'Member';

  static CouncilRole? fromApi(String? v) => switch (v) {
    'LEAD' => lead,
    'MEMBER' => member,
    _ => null,
  };
}

/// The glyph on a council's cover tile, chosen from its name and segments
/// the way the website picks its industry icon.
enum CouncilIndustry {
  sustainability,
  legal,
  construction,
  finance,
  tech,
  health,
  education,
  logistics,
  realEstate,
  hospitality,
  government,
  manufacturing,
  security,
  people,
  general;

  static final _rules = <(CouncilIndustry, RegExp)>[
    (
      sustainability,
      RegExp(r'sustain|esg|green|net[ -]?zero|carbon|renewable|energy|solar|wind|utilit', caseSensitive: false),
    ),
    // Construction before legal: "Project Governance" is a construction topic, not a legal one.
    (construction, RegExp(r'construction|\bmep\b|project|fit-?out|engineering', caseSensitive: false)),
    (legal, RegExp(r'legal|complianc|governance|procurement|contract', caseSensitive: false)),
    (finance, RegExp(r'bfsi|bank|financ|insurance|nbfc|fintech', caseSensitive: false)),
    (
      tech,
      RegExp(
        r'tech|\bai\b|digital|data|cloud|iot|smart|automation|innovation|telecom|network|startup|proptech|bms',
        caseSensitive: false,
      ),
    ),
    (health, RegExp(r'health|hospital|pharma|life scienc|medical|wellbeing|safety|ehs', caseSensitive: false)),
    (
      education,
      RegExp(r'academ|universit|college|school|research|knowledge|young profess|student', caseSensitive: false),
    ),
    (logistics, RegExp(r'logistic|warehous|supply chain|transport|mobility|fleet|distribution', caseSensitive: false)),
    (realEstate, RegExp(r'real estate|developer|residential|lease|portfolio|commercial', caseSensitive: false)),
    (hospitality, RegExp(r'hospitality|tourism|hotel|food|beverage|catering|retail|shopping', caseSensitive: false)),
    (government, RegExp(r'government|public|smart cit|urban|defence|aerospace|airport|aviation', caseSensitive: false)),
    (manufacturing, RegExp(r'manufactur|industrial|asset|maintenance', caseSensitive: false)),
    (security, RegExp(r'security|risk|continuit', caseSensitive: false)),
    (
      people,
      RegExp(
        r'women|leadership|cxo|workplace|experience|facility|consult|advisory|community|coworking|corporate',
        caseSensitive: false,
      ),
    ),
  ];

  static CouncilIndustry of(String name, List<String> segments) {
    final hay = '$name ${segments.join(' ')}';
    for (final (key, re) in _rules) {
      if (re.hasMatch(hay)) return key;
    }
    return general;
  }
}

/// The council's chair: its first titled lead.
class CouncilChair {
  const CouncilChair({required this.name, this.title, this.photo});

  final String name;

  /// "Director ESG @ DLF".
  final String? title;
  final FeedPicture? photo;
}

class Council {
  const Council({
    required this.id,
    required this.name,
    required this.slug,
    this.focus,
    this.description,
    this.segments = const [],
    this.tags = const [],
    this.cover,
    this.memberCount = 0,
    this.upcomingEventCount = 0,
    this.createdAt,
    this.chair,
    this.membership,
    this.nextEventAt,
    this.activityLabel,
    this.badge,
    this.established,
    this.unread = 0,
  });

  final String id;
  final String name;
  final String slug;

  /// "Procurement Excellence": the council's one-line focus.
  final String? focus;
  final String? description;

  /// The member segments the council serves. The first is its category (the
  /// chip it is filed under); the rest are its topics.
  final List<String> segments;

  /// "#NetZero": the hashtag pills, one per topic.
  final List<String> tags;
  final FeedPicture? cover;
  final int memberCount;
  final int upcomingEventCount;
  final DateTime? createdAt;
  final CouncilChair? chair;

  /// Set when the member has joined.
  final CouncilRole? membership;

  /// The council's next upcoming event.
  final DateTime? nextEventAt;

  /// "2 Upcoming Events" (live) or "3 Working Groups" (the design's demo —
  /// the API has no working groups).
  final String? activityLabel;

  /// The word in the cover's first pill when it is not "OFFICIAL COUNCIL"
  /// ("CHARTERED 2024"). The API has no such flag: the live source derives it
  /// from the council's age (`councilTier`).
  final String? badge;

  /// "Est. 2023": the cover's second pill, for an established council.
  final String? established;

  /// What a joined council has posted that the member may not have seen: the
  /// announcements of the last 30 days (the API keeps no read state).
  final int unread;

  bool get joined => membership != null;

  /// The chip the council is filed under: its first segment.
  String? get category => segments.isEmpty ? null : segments.first;

  /// The copy line under a name: the focus, else the description.
  String? get blurb => focus ?? description;

  CouncilIndustry get industry => CouncilIndustry.of(name, segments);

  Council copyWith({
    String? name,
    CouncilRole? membership,
    bool clearMembership = false,
    int? unread,
    FeedPicture? cover,
    bool clearCover = false,
  }) => Council(
    id: id,
    name: name ?? this.name,
    slug: slug,
    focus: focus,
    description: description,
    segments: segments,
    tags: tags,
    cover: clearCover ? null : cover ?? this.cover,
    memberCount: memberCount,
    upcomingEventCount: upcomingEventCount,
    createdAt: createdAt,
    chair: chair,
    membership: clearMembership ? null : membership ?? this.membership,
    nextEventAt: nextEventAt,
    activityLabel: activityLabel,
    badge: badge,
    established: established,
    unread: unread ?? this.unread,
  );
}

/// How a roundtable's mode pill is tinted.
enum RoundtableTone { blue, green, dark }

/// An upcoming council event, as the Upcoming Roundtables rows draw it.
class Roundtable {
  const Roundtable({
    required this.id,
    required this.title,
    required this.startsAt,
    this.endsAt,
    this.slug,
    required this.mode,
    required this.tone,
    this.detail,
    this.councilId,
    this.location,
  });

  final String id;
  final String title;

  /// In IST; the tile and the time line read it on the Indian clock.
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? slug;

  /// "VIRTUAL", "HYBRID BLR", "CLOSED-DOOR".
  final String mode;
  final RoundtableTone tone;

  /// "Lead: Vikram Malhotra (DLF) • 82 seats claimed": the hosting council's
  /// chair and the event's GOING count (the hosting council's name when it has
  /// no chair).
  final String? detail;
  final String? councilId;

  /// Where it is held, for the calendar entry.
  final String? location;
}

/// A city chapter in the In-Person Summits footer.
class ChapterSummit {
  const ChapterSummit({required this.id, required this.slug, required this.city, this.nextEventAt});

  final String id;
  final String slug;
  final String city;
  final DateTime? nextEventAt;
}

/// The four tiles at the top.
class CouncilStats {
  const CouncilStats({
    required this.activeCouncils,
    this.newThisQuarter = 0,
    this.quarter,
    required this.peerMembers,
    this.peerMembersLabel,
    required this.domains,
    required this.activeRoundtables,
  });

  final int activeCouncils;

  /// Councils created in the running quarter, for the "+3 Q1" pill.
  final int newThisQuarter;

  /// "Q1".
  final String? quarter;
  final int peerMembers;

  /// "2,530+": the count rounded down to ten, as the design prints it. The
  /// tile falls back to the exact grouped sum when this is null.
  final String? peerMembersLabel;

  /// Distinct segments across the councils (the website's "industries covered").
  final int domains;

  /// Upcoming roundtables: council-hosted events of the roundtable kind, the
  /// same set the rows below the tiles are drawn from.
  final int activeRoundtables;
}

/// Everything the Councils screen shows at rest.
class CouncilsOverview {
  const CouncilsOverview({
    required this.stats,
    required this.councils,
    this.joined = const [],
    this.roundtables = const [],
    this.roundtablesCaption,
    this.chapters = const [],
  });

  final CouncilStats stats;
  final List<Council> councils;

  /// The councils the member belongs to, for the rail under the stats.
  final List<Council> joined;
  final List<Roundtable> roundtables;

  /// The words at the right of "Upcoming Roundtables" ("Live Chatham-House"
  /// in the design; live, "All events", which opens the events page).
  final String? roundtablesCaption;
  final List<ChapterSummit> chapters;

  CouncilsOverview copyWith({List<Council>? councils, List<Council>? joined}) => CouncilsOverview(
    stats: stats,
    councils: councils ?? this.councils,
    joined: joined ?? this.joined,
    roundtables: roundtables,
    roundtablesCaption: roundtablesCaption,
    chapters: chapters,
  );
}

/// How the directory is ordered, as the website's toolbar offers.
enum CouncilSort {
  recommended('Recommended'),
  members('Most members'),
  active('Most active'),
  newest('Newest'),
  az('A to Z');

  const CouncilSort(this.label);
  final String label;
}
