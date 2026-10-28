/// What the Mentorship screens draw. The live source fills it from the public
/// mentor directory (`GET /mentorship/mentors`, its `facets`), the public
/// stats, the open cohort programmes and the top mentors' storefronts; the
/// demo source holds the designs' sample content.
library;

import '../feed/feed_models.dart' show FeedPicture;

export '../feed/feed_models.dart' show FeedPicture;

/// One of the category chips ("Operations & FM"): a competency domain the
/// directory can filter on, with how many mentors list it.
class MentorCategory {
  const MentorCategory({required this.label, this.count = 0});

  final String label;
  final int count;
}

/// A mentor as the directory card draws them.
class Mentor {
  const Mentor({
    required this.id,
    this.userId,
    required this.name,
    this.headline,
    this.role,
    this.avatar,
    this.cover,
    this.coverPreset,
    this.expertise = const [],
    this.approved = true,
    this.topMentor = false,
    this.featured = false,
    this.rating = 0,
    this.ratingCount = 0,
    this.yearsExperience,
    this.companyName,
    this.companyLogo,
    this.companyOnAccount = false,
    this.saved = false,
  });

  final String id;

  /// The mentor's member account: what a "follow" is keyed on.
  final String? userId;
  final String name;

  /// The mentor's own one-liner, shown when they have no current role.
  final String? headline;

  /// "VP Facility Ops @ Infosys": the current role from their career history.
  final String? role;
  final FeedPicture? avatar;

  /// An uploaded banner, when the mentor has one.
  final FeedPicture? cover;

  /// One of the website's ready-made covers (`PROFILE_COVERS` ids) when the
  /// mentor picked one instead of uploading; drawn as its gradient band.
  final String? coverPreset;

  /// The competency domains on the card's small chips.
  final List<String> expertise;

  /// Listed by ICR (every mentor in the public directory is); the seal.
  final bool approved;
  final bool topMentor;
  final bool featured;
  final double rating;
  final int ratingCount;
  final int? yearsExperience;

  /// The employer on the mentor's ICR account, else on their current role.
  final String? companyName;
  final FeedPicture? companyLogo;

  /// Only a company on the account can filter the directory.
  final bool companyOnAccount;
  final bool saved;

  String get roleLine => role ?? headline ?? '';

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return '${parts.first[0]}${parts.length > 1 ? parts.last[0] : ''}'.toUpperCase();
  }

  Mentor copyWith({bool? saved}) => Mentor(
    id: id,
    userId: userId,
    name: name,
    headline: headline,
    role: role,
    avatar: avatar,
    cover: cover,
    coverPreset: coverPreset,
    expertise: expertise,
    approved: approved,
    topMentor: topMentor,
    featured: featured,
    rating: rating,
    ratingCount: ratingCount,
    yearsExperience: yearsExperience,
    companyName: companyName,
    companyLogo: companyLogo,
    companyOnAccount: companyOnAccount,
    saved: saved ?? this.saved,
  );
}

/// An employer tile ("Learn from top leaders at top enterprises").
class MentorCompany {
  const MentorCompany({required this.name, this.logo, this.mentors = 0, this.onAccount = false, this.brandColor});

  final String name;
  final FeedPicture? logo;

  /// How many listed mentors work there.
  final int mentors;

  /// The directory's company filter matches the company on a mentor's
  /// account, so only such a tile can open a filtered list.
  final bool onAccount;

  /// The wordmark colour (ARGB) when the source names one (the demo does).
  /// Otherwise the tile asks `MentorshipBrand.wordmark` for the company's.
  final int? brandColor;
}

/// How a topic chip is tinted. The design's red chips are the topics a member
/// has selected and its blue ones the topics suggested to them; the API has no
/// such thing, so live they are worked out (`toneTopics`).
enum TopicTone { neutral, blue, red }

class MentorTopic {
  const MentorTopic(this.label, {this.tone = TopicTone.neutral, this.selected = false});

  final String label;
  final TopicTone tone;

  /// Drawn on a grey fill (the design's pressed first chip); only the demo has one.
  final bool selected;
}

/// The woman at the right of the "Become an ICR Mentor" band: the design's own
/// photograph, bundled, since the API has no picture for the band. It is drawn
/// live as well as in the demo.
const mentorBannerPhoto = FeedPicture.asset('assets/images/demo/mentorship/banner_photo.jpg');

/// The "Become an ICR Mentor" band.
class MentorBanner {
  const MentorBanner({required this.title, required this.body, required this.cta, this.photo, this.link});

  final String title;
  final String body;
  final String cta;
  final FeedPicture? photo;

  /// A path on the ICR website.
  final String? link;
}

class CohortAvatar {
  const CohortAvatar({required this.initials, this.photo});

  final String initials;
  final FeedPicture? photo;
}

/// The next cohort programme open for applications.
class MentorCohort {
  const MentorCohort({
    required this.id,
    required this.name,
    required this.registeredLabel,
    this.slug,
    this.avatars = const [],
    this.cover,
    this.link,
  });

  final String id;
  final String? slug;
  final String name;

  /// "32 Leaders Registered".
  final String registeredLabel;
  final List<CohortAvatar> avatars;
  final FeedPicture? cover;
  final String? link;
}

/// `MentorServiceType`.
enum MentorServiceKind {
  oneOnOne('1:1 Session'),
  query('Async Query'),
  groupSession('Group Session'),
  resource('Resource');

  const MentorServiceKind(this.label);
  final String label;

  static MentorServiceKind? fromApi(String? v) => switch (v) {
    'ONE_ON_ONE' => oneOnOne,
    'QUERY' => query,
    'GROUP_SESSION' => groupSession,
    'RESOURCE' => resource,
    _ => null,
  };
}

/// The glyph at the right of a session card's pill row.
enum ServiceGlyph { diagnostic, session, query, group, resource }

/// One offering from a mentor's storefront, as a "Featured Advisory Sessions"
/// card.
class MentorService {
  const MentorService({
    required this.id,
    required this.mentorId,
    required this.kind,
    required this.title,
    this.blurb,
    this.kindLabel,
    this.durationMin,
    this.slaHours,
    this.pricePaisa = 0,
    this.cta,
    this.featured = false,
    this.glyph,
  });

  final String id;
  final String mentorId;
  final MentorServiceKind kind;
  final String title;
  final String? blurb;

  /// The first part of the pill, when it is not just the kind's label (the
  /// design's "1:1 Diagnostic Call").
  final String? kindLabel;
  final int? durationMin;
  final int? slaHours;
  final int pricePaisa;

  /// The button's words, when the source words them itself.
  final String? cta;

  /// The first card: a green pill and a filled button.
  final bool featured;
  final ServiceGlyph? glyph;

  bool get free => pricePaisa <= 0;

  /// "1:1 Session • 45 Mins • ₹1,499".
  String get pill {
    final parts = [
      kindLabel ?? kind.label,
      if (durationMin != null) '$durationMin Mins' else if (slaHours != null) '$slaHours Hrs TAT',
      free ? 'Free' : '₹${_group(pricePaisa ~/ 100)}',
    ];
    return parts.join(' • ');
  }

  String get buttonLabel =>
      cta ??
      switch (kind) {
        MentorServiceKind.oneOnOne => free ? 'Book Session (Free)' : 'Book Session',
        MentorServiceKind.query => 'Send a Query',
        MentorServiceKind.groupSession => 'Reserve a Seat',
        MentorServiceKind.resource => free ? 'Get Resource (Free)' : 'Get Resource',
      };

  ServiceGlyph get glyphOrDefault =>
      glyph ??
      switch (kind) {
        MentorServiceKind.oneOnOne => ServiceGlyph.session,
        MentorServiceKind.query => ServiceGlyph.query,
        MentorServiceKind.groupSession => ServiceGlyph.group,
        MentorServiceKind.resource => ServiceGlyph.resource,
      };

  static String _group(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
}

/// What the design calls both mentor grids. ICR has no network graph, so
/// "your network" is the mentors the member saved or follows, or who work where
/// they do, ahead of the best rated.
const mentorNetworkTitle = 'Top Mentors in Your Network';

/// A titled grid of mentors on the landing.
class MentorShelf {
  const MentorShelf({required this.key, required this.title, required this.mentors});

  final String key;
  final String title;
  final List<Mentor> mentors;

  MentorShelf copyWith({List<Mentor>? mentors}) =>
      MentorShelf(key: key, title: title, mentors: mentors ?? this.mentors);
}

/// Everything the Mentorship tab shows at rest.
class MentorshipOverview {
  const MentorshipOverview({
    required this.categories,
    this.selectedCategory,
    required this.domainsBadge,
    this.companies = const [],
    this.shelves = const [],
    this.topics = const [],
    this.banner,
    this.cohort,
    this.services = const [],
  });

  final List<MentorCategory> categories;
  final String? selectedCategory;

  /// "8+ Domains" as the design words it: the count of domains with a mentor,
  /// rounded down with a "+" (`domainsBadgeFor`).
  final String domainsBadge;
  final List<MentorCompany> companies;
  final List<MentorShelf> shelves;
  final List<MentorTopic> topics;
  final MentorBanner? banner;
  final MentorCohort? cohort;
  final List<MentorService> services;

  MentorshipOverview copyWith({List<MentorShelf>? shelves}) => MentorshipOverview(
    categories: categories,
    selectedCategory: selectedCategory,
    domainsBadge: domainsBadge,
    companies: companies,
    shelves: shelves ?? this.shelves,
    topics: topics,
    banner: banner,
    cohort: cohort,
    services: services,
  );
}

/// The directory's sort fields.
enum MentorSort {
  rating('Top rated'),
  menteesHelped('Most mentees helped'),
  sessionsCompleted('Most sessions'),
  yearsExperience('Most experienced'),
  createdAt('Newest');

  const MentorSort(this.label);
  final String label;
}

class MentorFilters {
  const MentorFilters({
    this.category,
    this.search = '',
    this.sort = MentorSort.rating,
    this.minExperience,
    this.availableOnly = false,
    this.company,
    this.companyOnAccount = false,
  });

  /// A competency domain.
  final String? category;
  final String search;
  final MentorSort sort;
  final int? minExperience;
  final bool availableOnly;

  /// An employer ("Company: SpaceX"): a removable chip of its own, never words
  /// in the search box.
  final String? company;

  /// Whether the employer is the company on mentors' ICR accounts (the
  /// directory's `companies` filter) or only the organisation on their current
  /// role, which the directory can find only by searching its words.
  final bool companyOnAccount;

  /// How many filters the "Filters (n)" chip counts.
  int get count =>
      (category == null ? 0 : 1) +
      (minExperience == null ? 0 : 1) +
      (availableOnly ? 1 : 0) +
      (company == null ? 0 : 1);

  MentorFilters copyWith({
    String? category,
    bool clearCategory = false,
    String? search,
    MentorSort? sort,
    int? minExperience,
    bool clearExperience = false,
    bool? availableOnly,
    String? company,
    bool? companyOnAccount,
    bool clearCompany = false,
  }) => MentorFilters(
    category: clearCategory ? null : category ?? this.category,
    search: search ?? this.search,
    sort: sort ?? this.sort,
    minExperience: clearExperience ? null : minExperience ?? this.minExperience,
    availableOnly: availableOnly ?? this.availableOnly,
    company: clearCompany ? null : company ?? this.company,
    companyOnAccount: clearCompany ? false : companyOnAccount ?? this.companyOnAccount,
  );
}

class MentorPage {
  const MentorPage({required this.mentors, required this.total, required this.hasMore});

  final List<Mentor> mentors;

  /// Every mentor matching the filters, not just this page.
  final int total;
  final bool hasMore;
}
