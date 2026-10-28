/// What the Chapters screens draw: the website's `/chapters` board and
/// `/chapters/[slug]` page, from the portal's association module
/// (`GET /chapters`, `/chapters/:slug` and its members, resources and
/// announcements, `/chapters/memberships/mine`, `/events?chapterSlug=`).
library;

import 'community_kit.dart';

export 'community_kit.dart' show FeedPicture, AboutBlock, AboutKind;

/// The member's standing in a chapter (`AssociationRole`).
enum ChapterRole {
  member('Member'),
  lead('Chapter lead');

  const ChapterRole(this.label);
  final String label;

  static ChapterRole? fromApi(String? v) => switch (v) {
    'LEAD' => lead,
    'MEMBER' => member,
    _ => null,
  };
}

/// The glyph a chapter's banner carries, chosen from its place the way the
/// website's `placeIconKey` does.
enum PlaceKind {
  coastal,
  capital,
  tech,
  industrial,
  heritage,
  metro,
  general;

  static final _rules = <(PlaceKind, RegExp)>[
    (
      coastal,
      RegExp(
        r'mumbai|chennai|kochi|goa|vizag|visakhapatnam|surat|port|harbour|harbor|coast|beach|bay',
        caseSensitive: false,
      ),
    ),
    (
      capital,
      RegExp(r'delhi|ncr|capital|washington|london|canberra|ottawa|brasilia|riyadh|abu dhabi', caseSensitive: false),
    ),
    (
      tech,
      RegExp(
        r'bengaluru|bangalore|hyderabad|pune|silicon|tech|cyber|it park|gurugram|gurgaon|noida',
        caseSensitive: false,
      ),
    ),
    (
      industrial,
      RegExp(r'jamshedpur|coimbatore|ludhiana|kanpur|industrial|manufactur|steel|auto', caseSensitive: false),
    ),
    (heritage, RegExp(r'jaipur|varanasi|agra|mysuru|mysore|udaipur|heritage|old city|lucknow', caseSensitive: false)),
    (metro, RegExp(r'kolkata|ahmedabad|metro|city|urban|greater', caseSensitive: false)),
  ];

  static PlaceKind of(String name, String city, String? region) {
    final hay = '$name $city ${region ?? ''}';
    for (final (key, re) in _rules) {
      if (re.hasMatch(hay)) return key;
    }
    return general;
  }
}

/// A chapter on the board.
class ChapterSummary {
  const ChapterSummary({
    required this.id,
    required this.name,
    required this.slug,
    required this.city,
    required this.country,
    this.region,
    this.description,
    this.cover,
    this.createdAt,
    this.memberCount = 0,
    this.upcomingEventCount = 0,
    this.role,
    this.nextEventAt,
  });

  final String id;
  final String name;
  final String slug;
  final String city;
  final String country;
  final String? region;
  final String? description;
  final FeedPicture? cover;
  final DateTime? createdAt;
  final int memberCount;
  final int upcomingEventCount;

  /// Set when the member belongs.
  final ChapterRole? role;

  /// The chapter's soonest upcoming event (from the events the board reads).
  final DateTime? nextEventAt;

  bool get joined => role != null;

  /// "Bengaluru · Karnataka · India", without repeating a value.
  String get place {
    final parts = <String>[];
    for (final p in [city, region, country]) {
      if (p != null && p.trim().isNotEmpty && !parts.contains(p)) parts.add(p);
    }
    return parts.join(' · ');
  }

  PlaceKind get placeKind => PlaceKind.of(name, city, region);

  /// Created within the last 60 days (the website's "New").
  bool isNew(DateTime now) => createdAt != null && now.difference(createdAt!).inDays < 60 && !now.isBefore(createdAt!);

  /// The website's activity signal ("Most active", recommendation ties).
  int get activity => upcomingEventCount * 10 + memberCount;

  ChapterSummary copyWith({ChapterRole? role, bool clearRole = false, int? memberCount}) => ChapterSummary(
    id: id,
    name: name,
    slug: slug,
    city: city,
    country: country,
    region: region,
    description: description,
    cover: cover,
    createdAt: createdAt,
    memberCount: memberCount ?? this.memberCount,
    upcomingEventCount: upcomingEventCount,
    role: clearRole ? null : role ?? this.role,
    nextEventAt: nextEventAt,
  );
}

/// An event a chapter hosts.
class ChapterEvent {
  const ChapterEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    this.slug,
    this.kind = 'CHAPTER_MEET',
    this.description,
    this.location,
    this.endsAt,
    this.capacity,
    this.attendeeCount = 0,
    this.priceAmount,
    this.inviteOnly = false,
    this.chapterSlug,
    this.chapterName,
    this.myStatus,
  });

  final String id;
  final String? slug;
  final String title;
  final String kind;
  final String? description;
  final String? location;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int? capacity;
  final int attendeeCount;

  /// Paise; null or 0 is free.
  final int? priceAmount;
  final bool inviteOnly;
  final String? chapterSlug;
  final String? chapterName;

  /// The member's RSVP ("GOING", "WAITLISTED"…).
  final String? myStatus;

  /// What the event sheet is opened with: the slug, else the id.
  String get key => slug ?? id;

  int? get seatsLeft => capacity == null ? null : (capacity! - attendeeCount).clamp(0, capacity!);
  bool get full => capacity != null && attendeeCount >= capacity!;

  /// A seat is bought (`priceAmount` is in paise): the events sheet sells it, a bare RSVP is refused.
  bool get ticketed => (priceAmount ?? 0) > 0;

  /// The member has a place (GOING) or a spot on the waitlist; a cancelled RSVP is no RSVP.
  bool get holding => myStatus == 'GOING' || myStatus == 'WAITLISTED';
  bool get going => myStatus == 'GOING' || myStatus == 'ATTENDED';
  bool get waitlisted => myStatus == 'WAITLISTED';

  /// Over by [now] (an event with no end time lasts three hours).
  bool isOver(DateTime now) => (endsAt ?? startsAt.add(const Duration(hours: 3))).isBefore(now);

  /// "CHAPTER MEET".
  String get kindLabel => kind.replaceAll('_', ' ').toUpperCase();

  /// The same event with the member's RSVP set to [status] (null for none). [attendeeCount] moves with
  /// a GOING seat: taken when [status] is GOING and was not, given back when it was and is no longer.
  ChapterEvent withStatus(String? status, {bool moveCount = false}) {
    var count = attendeeCount;
    if (moveCount) {
      final was = myStatus == 'GOING';
      final is_ = status == 'GOING';
      if (is_ && !was) count += 1;
      if (was && !is_) count = (count - 1).clamp(0, 1 << 30);
    }
    return ChapterEvent(
      id: id,
      slug: slug,
      title: title,
      kind: kind,
      description: description,
      location: location,
      startsAt: startsAt,
      endsAt: endsAt,
      capacity: capacity,
      attendeeCount: count,
      priceAmount: priceAmount,
      inviteOnly: inviteOnly,
      chapterSlug: chapterSlug,
      chapterName: chapterName,
      myStatus: status,
    );
  }
}

/// A committee member or roster row.
class ChapterPerson {
  const ChapterPerson({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.photo,
    this.title,
    this.company,
    this.linkedinUrl,
    this.role,
    this.joinedAt,
  });

  final String id;
  final String firstName;
  final String lastName;
  final FeedPicture? photo;

  /// "Chapter President".
  final String? title;
  final String? company;
  final String? linkedinUrl;
  final ChapterRole? role;
  final DateTime? joinedAt;

  String get name => '$firstName $lastName'.trim();
  String get initials => initialsOf(firstName, lastName);
}

class ChapterSponsor {
  const ChapterSponsor({required this.id, required this.name, this.logo, this.url, this.tier});

  final String id;
  final String name;
  final FeedPicture? logo;
  final String? url;
  final String? tier;
}

/// The four headline numbers in the hero.
class ChapterStats {
  const ChapterStats({
    this.memberCount = 0,
    this.leadershipCount = 0,
    this.upcomingEventCount = 0,
    this.pastEventCount = 0,
    this.memberCompanyCount = 0,
  });

  final int memberCount;
  final int leadershipCount;
  final int upcomingEventCount;
  final int pastEventCount;
  final int memberCompanyCount;

  ChapterStats withMembers(int delta) => ChapterStats(
    memberCount: (memberCount + delta).clamp(0, 1 << 30),
    leadershipCount: leadershipCount,
    upcomingEventCount: upcomingEventCount,
    pastEventCount: pastEventCount,
    memberCompanyCount: memberCompanyCount,
  );
}

/// A chapter's page.
class ChapterDetail {
  const ChapterDetail({
    required this.chapter,
    this.contactEmail,
    this.foundedYear,
    this.about = const [],
    this.gallery = const [],
    this.stats = const ChapterStats(),
    this.sponsors = const [],
    this.leads = const [],
    this.upcomingEvents = const [],
  });

  final ChapterSummary chapter;
  final String? contactEmail;
  final int? foundedYear;

  /// `aboutHtml` as headings, paragraphs and bullet points.
  final List<AboutBlock> about;
  final List<FeedPicture> gallery;
  final ChapterStats stats;
  final List<ChapterSponsor> sponsors;
  final List<ChapterPerson> leads;
  final List<ChapterEvent> upcomingEvents;

  ChapterDetail copyWith({ChapterSummary? chapter, ChapterStats? stats, List<ChapterEvent>? upcomingEvents}) =>
      ChapterDetail(
        chapter: chapter ?? this.chapter,
        contactEmail: contactEmail,
        foundedYear: foundedYear,
        about: about,
        gallery: gallery,
        stats: stats ?? this.stats,
        sponsors: sponsors,
        leads: leads,
        upcomingEvents: upcomingEvents ?? this.upcomingEvents,
      );
}

/// The roster's three filters, each a parameter the members API takes.
enum MemberFilter {
  all('All members'),
  corporate('Corporate only'),
  committee('Committee');

  const MemberFilter(this.label);
  final String label;
}

class ChapterMembersPage {
  const ChapterMembersPage({required this.members, required this.total, required this.page, required this.hasNext});

  final List<ChapterPerson> members;
  final int total;
  final int page;
  final bool hasNext;
}

/// A deck, template or recording the chapter shares (`ResourceKind`).
class ChapterResource {
  const ChapterResource({
    required this.id,
    required this.title,
    required this.kind,
    required this.url,
    this.sizeLabel,
    this.createdAt,
  });

  final String id;
  final String title;

  /// PRESENTATION, WHITEPAPER, TEMPLATE, RECORDING, OTHER.
  final String kind;
  final String url;
  final String? sizeLabel;
  final DateTime? createdAt;

  /// The website's coloured tag (PPTX, PDF, XLSX, MP4, FILE).
  String get tag => switch (kind) {
    'PRESENTATION' => 'PPTX',
    'WHITEPAPER' => 'PDF',
    'TEMPLATE' => 'XLSX',
    'RECORDING' => 'MP4',
    _ => 'FILE',
  };

  /// "Whitepaper".
  String get kindLabel => switch (kind) {
    'PRESENTATION' => 'Presentation',
    'WHITEPAPER' => 'Whitepaper',
    'TEMPLATE' => 'Template',
    'RECORDING' => 'Recording',
    _ => 'Other',
  };
}

/// A committee dispatch.
class ChapterUpdate {
  const ChapterUpdate({required this.id, required this.title, required this.body, this.pinned = false, this.createdAt});

  final String id;
  final String title;
  final String body;
  final bool pinned;
  final DateTime? createdAt;
}

/// The board's four tiles.
class ChaptersStats {
  const ChaptersStats({
    required this.chapters,
    required this.members,
    required this.countries,
    required this.upcomingEvents,
  });

  final int chapters;
  final int members;
  final int countries;
  final int upcomingEvents;
}

/// Everything the board shows at rest.
class ChaptersOverview {
  const ChaptersOverview({required this.chapters, this.meetups = const []});

  final List<ChapterSummary> chapters;

  /// Upcoming chapter events, soonest first (the website's sidebar).
  final List<ChapterEvent> meetups;

  ChaptersStats get stats => ChaptersStats(
    chapters: chapters.length,
    members: chapters.fold(0, (n, c) => n + c.memberCount),
    countries: {for (final c in chapters) c.country}.length,
    upcomingEvents: chapters.fold(0, (n, c) => n + c.upcomingEventCount),
  );

  ChaptersOverview copyWith({List<ChapterSummary>? chapters}) =>
      ChaptersOverview(chapters: chapters ?? this.chapters, meetups: meetups);
}

/// The board's size filter (the website's "Members").
enum ChapterSize {
  any('Any size'),
  small('1–2 members'),
  medium('3–10 members'),
  large('10+ members');

  const ChapterSize(this.label);
  final String label;

  bool matches(int count) => switch (this) {
    any => true,
    small => count <= 2,
    medium => count >= 3 && count <= 10,
    large => count > 10,
  };
}

/// The board's activity filter.
enum ChapterActivity {
  any('Any activity'),
  events('Has upcoming events'),
  fresh('New this quarter');

  const ChapterActivity(this.label);
  final String label;
}

/// The board's first row of chips: every chapter, the ones the member belongs to, or the ones in the
/// places they already meet in (a region or a country shared with one of their chapters).
enum ChapterScope {
  all('All Chapters'),
  joined('Joined'),
  nearby('Nearby');

  const ChapterScope(this.label);
  final String label;
}

/// How the board is ordered, as the website's toolbar offers.
enum ChapterSort {
  recommended('Recommended'),
  members('Most members'),
  active('Most active'),
  newest('Newest'),
  az('A to Z');

  const ChapterSort(this.label);
  final String label;
}
