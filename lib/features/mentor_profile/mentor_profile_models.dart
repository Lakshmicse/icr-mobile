/// What the Mentor Profile screens draw. The live source fills it from
/// `GET /mentorship/mentors/:id`, the storefront, the plans and the reviews;
/// the demo source holds the designs' sample content.
library;

import '../feed/feed_models.dart' show FeedPicture;

export '../feed/feed_models.dart' show FeedPicture;

/// Why the viewer cannot ask this mentor for free mentoring (`MentorAskBlocker`).
enum AskBlocker {
  owner,
  alreadyMatched,
  requestPending,
  atCapacity,
  noMenteeProfile,
  planLimit;

  static AskBlocker? fromApi(String? v) => switch (v) {
    'OWNER' => owner,
    'ALREADY_MATCHED' => alreadyMatched,
    'REQUEST_PENDING' => requestPending,
    'AT_CAPACITY' => atCapacity,
    'NO_MENTEE_PROFILE' => noMenteeProfile,
    'PLAN_LIMIT' => planLimit,
    _ => null,
  };
}

/// The signed-in member's standing with this mentor; null signed out.
class MentorViewer {
  const MentorViewer({
    this.isOwner = false,
    this.canRequest = true,
    this.blockedReason,
    this.blocker,
    this.mentorshipId,
    this.pendingRequestId,
  });

  final bool isOwner;
  final bool canRequest;

  /// Why `canRequest` is false, worded by the API to be shown verbatim.
  final String? blockedReason;
  final AskBlocker? blocker;

  /// A live pairing with this mentor: "Send Message" opens its thread.
  final String? mentorshipId;
  final String? pendingRequestId;

  MentorViewer copyWith({bool? canRequest, String? blockedReason, AskBlocker? blocker, String? pendingRequestId}) =>
      MentorViewer(
        isOwner: isOwner,
        canRequest: canRequest ?? this.canRequest,
        blockedReason: blockedReason ?? this.blockedReason,
        blocker: blocker ?? this.blocker,
        mentorshipId: mentorshipId,
        pendingRequestId: pendingRequestId ?? this.pendingRequestId,
      );
}

/// One weekly window the mentor is bookable in, in their own timezone.
class AvailabilityBlock {
  const AvailabilityBlock({required this.weekday, required this.startMin, required this.endMin});

  /// 0 = Sunday … 6 = Saturday.
  final int weekday;
  final int startMin;
  final int endMin;
}

/// A role on the mentor's career history (`ExperienceDto`).
class MentorRole {
  const MentorRole({
    required this.title,
    required this.organisation,
    this.organisationLinked = false,
    required this.startYear,
    this.startMonth,
    this.endYear,
    this.endMonth,
    this.isCurrent = false,
    this.place,
    this.description,
    this.durationLabel,
  });

  final String title;
  final String organisation;

  /// The organisation is a company page on ICR, drawn as a link.
  final bool organisationLinked;
  final int startYear;
  final int? startMonth;
  final int? endYear;
  final int? endMonth;
  final bool isCurrent;

  /// The city, live; the demo writes the design's unit name here.
  final String? place;
  final String? description;

  /// Only the demo sets this; live roles compute it from the dates.
  final String? durationLabel;

  /// "2022 - Present" / "2012 - 2022".
  String get years => '$startYear - ${isCurrent || endYear == null ? 'Present' : endYear}';
}

class MentorEducation {
  const MentorEducation({required this.institution, this.degree, this.field, this.startYear, this.endYear});

  final String institution;
  final String? degree;
  final String? field;
  final int? startYear;
  final int? endYear;

  /// "Batch of 2009 - 2011".
  String? get batch {
    final years = [?startYear, ?endYear];
    return years.isEmpty ? null : 'Batch of ${years.join(' - ')}';
  }
}

/// One review: a named testimonial, or anonymous mentee feedback.
class MentorReview {
  const MentorReview({
    required this.id,
    required this.name,
    this.subline,
    this.photo,
    this.rating,
    required this.quote,
    this.createdAt,
    this.agoLabel,
  });

  final String id;
  final String name;

  /// "Operations Analyst".
  final String? subline;
  final FeedPicture? photo;
  final int? rating;
  final String quote;
  final DateTime? createdAt;

  /// Only the demo sets this; live reviews compute it from `createdAt`.
  final String? agoLabel;
}

/// The stats strip: the numbers as they read on the card.
class MentorStats {
  const MentorStats({
    required this.sessions,
    this.sessionsBadge,
    required this.mentees,
    this.menteesCaption = 'Mentees Helped',
    this.menteesNote,
  });

  /// "26+" (demo) / "26" (live, sessions completed).
  final String sessions;

  /// "Top 5% Mentor" (demo) / "Top Mentor" (live, the API's `isTopMentor`).
  final String? sessionsBadge;

  /// "12" (live: mentees helped, i.e. mentorships completed).
  final String mentees;

  /// "Mentees Helped" (live); the design's "Active Mentees" is demo-only, as the API
  /// counts completed mentorships and no live ones.
  final String menteesCaption;

  /// "Across 4 countries" (demo) / "2 slots open" (live, from capacity).
  final String? menteesNote;
}

class MentorProfile {
  const MentorProfile({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.roleTitle,
    this.roleOrganisation,
    this.headline,
    this.bioHtml,
    this.photo,
    this.cover,
    this.verified = true,
    this.yearsExperience,
    this.city,
    this.modes = const [],
    this.modeKeys = const [],
    this.languages = const [],
    this.competencies = const [],
    this.topics = const [],
    this.competenciesLabel = 'Domain Expertise',
    this.topicsLabel = 'Softwares & Frameworks',
    this.rating = 0,
    this.ratingCount = 0,
    required this.stats,
    this.experience = const [],
    this.education = const [],
    this.availability = const [],
    this.timezone = 'Asia/Kolkata',
    this.viewer,
    this.openSlots = 0,
    this.capacity = 0,
    this.yearsLabel,
    this.slotLabel,
  });

  final String id;
  final String userId;
  final String firstName;
  final String lastName;

  /// The current role ("Supply Chain Leader" at "Microsoft"), from the career
  /// history; the headline follows it.
  final String? roleTitle;
  final String? roleOrganisation;
  final String? headline;
  final String? bioHtml;
  final FeedPicture? photo;
  final FeedPicture? cover;

  /// A listed mentor is one ICR approved; the directory never shows another.
  final bool verified;
  final int? yearsExperience;
  final String? city;

  /// "Video", "In person"…
  final List<String> modes;

  /// The same modes as the API names them (`VIDEO`, `IN_PERSON`…), for a request.
  final List<String> modeKeys;
  final List<String> languages;
  final List<String> competencies;
  final List<String> topics;
  final String competenciesLabel;
  final String topicsLabel;
  final double rating;
  final int ratingCount;
  final MentorStats stats;
  final List<MentorRole> experience;
  final List<MentorEducation> education;
  final List<AvailabilityBlock> availability;
  final String timezone;
  final MentorViewer? viewer;
  final int openSlots;
  final int capacity;

  /// "15+ Years Leadership": the demo's wording; live says "N years".
  final String? yearsLabel;

  /// "Next Slot: Tomorrow, 7:00 PM" as the design has it; live computes the
  /// label from [availability] at render time.
  final String? slotLabel;

  String get name => '$firstName $lastName'.trim();

  /// How the mentor meets: "Hybrid" when they offer both a meeting in person
  /// and a remote one (the design's "Hyderabad (Hybrid)"), else the modes
  /// themselves ("Video / Phone", "In person").
  String? get meetingLabel {
    if (modes.isEmpty) return null;
    final inPerson = modes.contains('In person');
    final remote = modes.any((m) => m != 'In person');
    if (inPerson && remote) return 'Hybrid';
    return modes.join(' / ');
  }

  /// "Hyderabad (Hybrid)": the city with how they meet.
  String? get placeLabel {
    final how = meetingLabel;
    if (city == null && how == null) return null;
    if (city == null) return how;
    return how == null ? city : '$city ($how)';
  }

  MentorProfile copyWith({MentorViewer? viewer, FeedPicture? photo, FeedPicture? cover}) => MentorProfile(
    id: id,
    userId: userId,
    firstName: firstName,
    lastName: lastName,
    roleTitle: roleTitle,
    roleOrganisation: roleOrganisation,
    headline: headline,
    bioHtml: bioHtml,
    photo: photo ?? this.photo,
    cover: cover ?? this.cover,
    verified: verified,
    yearsExperience: yearsExperience,
    city: city,
    modes: modes,
    modeKeys: modeKeys,
    languages: languages,
    competencies: competencies,
    topics: topics,
    competenciesLabel: competenciesLabel,
    topicsLabel: topicsLabel,
    rating: rating,
    ratingCount: ratingCount,
    stats: stats,
    experience: experience,
    education: education,
    availability: availability,
    timezone: timezone,
    viewer: viewer ?? this.viewer,
    openSlots: openSlots,
    capacity: capacity,
    yearsLabel: yearsLabel,
    slotLabel: slotLabel,
  );
}

/// What a mentor sells. A single session and a syllabus are both "1:1
/// mentoring" on ICR (a `ONE_ON_ONE` service and a `CURRICULUM` plan); an
/// ongoing plan is `RECURRING`; a resource is a download; a group session is
/// a seat bought on the session's own page.
enum OfferingKind { oneOnOne, program, plan, resource, groupSession, query }

/// The chips under the Offerings tab.
enum OfferingFilter {
  all('All'),
  oneOnOne('1:1 Mentorship'),
  groupSessions('Group Sessions'),
  resources('Resources');

  const OfferingFilter(this.label);
  final String label;

  bool admits(MentorOffering o) => switch (this) {
    all => true,
    oneOnOne => o.kind == OfferingKind.oneOnOne || o.kind == OfferingKind.program || o.kind == OfferingKind.plan,
    groupSessions => o.kind == OfferingKind.groupSession,
    resources => o.kind == OfferingKind.resource || o.kind == OfferingKind.query,
  };
}

/// A small grey tag at the top of an offering row; green for a promise
/// ("Instant Download").
class OfferingTag {
  const OfferingTag(this.label, {this.green = false});

  final String label;
  final bool green;
}

/// The glyph on a sheet tile or chip.
enum OfferingGlyph { calendar, clock, list, chat, person, sessions, download, group, infinity }

class OfferingFact {
  const OfferingFact({required this.glyph, required this.label});

  final OfferingGlyph glyph;
  final String label;
}

/// One "Program Details" tile.
class OfferingDetail {
  const OfferingDetail({required this.glyph, required this.title, required this.body});

  final OfferingGlyph glyph;
  final String title;
  final String body;
}

/// A module of the roadmap: "① Root Cause Analysis & Strategy — Month 1".
class RoadmapModule {
  const RoadmapModule({required this.title, this.badge, this.steps = const []});

  final String title;
  final String? badge;
  final List<String> steps;
}

/// One term of the roadmap's segmented control ("1 Month").
class RoadmapTerm {
  const RoadmapTerm({required this.label, required this.modules});

  final String label;
  final List<RoadmapModule> modules;
}

class MentorOffering {
  const MentorOffering({
    required this.id,
    required this.kind,
    required this.title,
    this.blurb,
    this.pricePaisa = 0,
    this.compareAtPaisa,
    this.durationMin,
    this.tags = const [],
    required this.ctaLabel,
    this.isBestSeller = false,
    this.rating = 0,
    this.ratingCount = 0,
    this.salesCount = 0,
    this.cover,
    this.fileName,
    this.slaHours,
    this.sessionsPerMonth,
    this.sessionDurationMin,
    this.billingPeriodMonths,
    this.perMonthPaisa,
    this.inclusions = const [],
    this.accessMonths,
    this.totalSessions,
    this.nextSessionAt,
    this.seatsLeft,
    this.groupSessionId,
    this.myOpenRequestId,
    this.myUpcomingBookingAt,
    required this.kicker,
    this.sheetTitle,
    this.sheetBlurb,
    this.facts = const [],
    this.details = const [],
    this.roadmap = const [],
    this.previewLabel,
    this.planKicker,
    this.seatsNote,
    this.applyLabel,
    this.familyKey,
    this.termMonths,
  });

  final String id;
  final OfferingKind kind;
  final String title;
  final String? blurb;
  final int pricePaisa;

  /// The struck-through price, when the mentor set one.
  final int? compareAtPaisa;
  final int? durationMin;
  final List<OfferingTag> tags;

  /// "Book Now" / "Purchase Guide" / "Ask Query".
  final String ctaLabel;
  final bool isBestSeller;
  final double rating;
  final int ratingCount;
  final int salesCount;
  final FeedPicture? cover;
  final String? fileName;
  final int? slaHours;

  // Plans.
  final int? sessionsPerMonth;
  final int? sessionDurationMin;
  final int? billingPeriodMonths;
  final int? perMonthPaisa;

  /// The mentor's own inclusions, in their words.
  final List<String> inclusions;
  final int? accessMonths;
  final int? totalSessions;

  // Group sessions.
  final DateTime? nextSessionAt;
  final int? seatsLeft;
  final String? groupSessionId;

  /// A 1:1 request of the viewer's still in play; the row says so rather
  /// than invite a second.
  final String? myOpenRequestId;
  final DateTime? myUpcomingBookingAt;

  // The sheet.
  /// "DISCOVERY CALL": the pill on the sheet's photo.
  final String kicker;

  /// The sheet's own title and copy when they differ from the row's (the
  /// design's "What's going wrong?"); live offerings use the row's.
  final String? sheetTitle;
  final String? sheetBlurb;
  final List<OfferingFact> facts;
  final List<OfferingDetail> details;

  /// The roadmap's terms; empty hides the section.
  final List<RoadmapTerm> roadmap;

  /// "Inspect 4-week diagnostic preview": the row's link to the sheet.
  final String? previewLabel;

  // The dark plan card.
  /// "FLAGSHIP COHORT" (demo) / "ONGOING PLAN" (live).
  final String? planKicker;

  /// "Only 2 slots left".
  final String? seatsNote;

  /// "Apply for Pro Mentorship" (demo) / "Apply for {title}" (live).
  final String? applyLabel;

  /// Programmes the mentor lists once per length share a title: those are one
  /// programme in several terms ("1 Month", "3 Months"). The key is the title
  /// folded to lower case; null for anything that is not a programme.
  final String? familyKey;

  /// How long this term runs, in months (a programme's access window).
  final int? termMonths;

  bool get free => pricePaisa == 0;
  bool get isPlan => kind == OfferingKind.plan || kind == OfferingKind.program;

  /// A session the mentor has to accept before anything is paid.
  bool get isRequested => kind == OfferingKind.oneOnOne || kind == OfferingKind.query || kind == OfferingKind.program;

  MentorOffering copyWith({String? myOpenRequestId, bool clearRequest = false, FeedPicture? cover}) => MentorOffering(
    id: id,
    kind: kind,
    title: title,
    blurb: blurb,
    pricePaisa: pricePaisa,
    compareAtPaisa: compareAtPaisa,
    durationMin: durationMin,
    tags: tags,
    ctaLabel: ctaLabel,
    isBestSeller: isBestSeller,
    rating: rating,
    ratingCount: ratingCount,
    salesCount: salesCount,
    cover: cover ?? this.cover,
    fileName: fileName,
    slaHours: slaHours,
    sessionsPerMonth: sessionsPerMonth,
    sessionDurationMin: sessionDurationMin,
    billingPeriodMonths: billingPeriodMonths,
    perMonthPaisa: perMonthPaisa,
    inclusions: inclusions,
    accessMonths: accessMonths,
    totalSessions: totalSessions,
    nextSessionAt: nextSessionAt,
    seatsLeft: seatsLeft,
    groupSessionId: groupSessionId,
    myOpenRequestId: clearRequest ? null : myOpenRequestId ?? this.myOpenRequestId,
    myUpcomingBookingAt: myUpcomingBookingAt,
    kicker: kicker,
    sheetTitle: sheetTitle,
    sheetBlurb: sheetBlurb,
    facts: facts,
    details: details,
    roadmap: roadmap,
    previewLabel: previewLabel,
    planKicker: planKicker,
    seatsNote: seatsNote,
    applyLabel: applyLabel,
    familyKey: familyKey,
    termMonths: termMonths,
  );
}

/// What happened when the member bought or asked for an offering.
enum CheckoutState {
  /// Fulfilled or activated at once (free).
  completed,

  /// Sent to the mentor; they accept, then the member pays (on the website).
  requested,

  /// Paid checkout runs on the website.
  website,

  /// The API said no (or the profile had not loaded); [CheckoutOutcome.message]
  /// is its sentence.
  refused,
}

class CheckoutOutcome {
  const CheckoutOutcome(this.state, {this.message, this.sitePath});

  final CheckoutState state;

  /// A sentence for the member.
  final String? message;

  /// The website path to continue on.
  final String? sitePath;
}
