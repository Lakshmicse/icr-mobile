/// The requirements (RFQ) module's data, as the API sends it (`/rfq/*`).
///
/// One [Requirement] class serves every list and page: the buyer's own rows
/// (`GET /rfq/mine`, with [Requirement.responses]), the supplier's board
/// (`GET /rfq/open`, with the buyer, the match and `hasBid`), the invitations
/// (`GET /rfq/invited`, with [Requirement.inviteStatus]) and the page itself
/// (`GET /rfq/:id`, with items and files). Fields a list leaves out are null.
library;

/// A light enquiry, or a full staged request for quotation.
enum RfqKind {
  enquiry('ENQUIRY', 'Enquiry'),
  rfq('RFQ', 'RFQ');

  const RfqKind(this.wire, this.label);
  final String wire;
  final String label;

  static RfqKind parse(Object? v) => v == 'ENQUIRY' ? enquiry : rfq;
}

enum RfqStatus {
  draft('DRAFT', 'Draft'),
  published('PUBLISHED', 'Live'),
  closed('CLOSED', 'Closed'),
  awarded('AWARDED', 'Awarded'),
  cancelled('CANCELLED', 'Cancelled');

  const RfqStatus(this.wire, this.label);
  final String wire;
  final String label;

  static RfqStatus parse(Object? v) => values.firstWhere((s) => s.wire == v, orElse: () => published);

  /// Closed, awarded or cancelled: suppliers can no longer reply.
  bool get ended => this == closed || this == cancelled;
}

/// The staged RFQ's steps, in order (the requirement stays PUBLISHED throughout).
enum RfqStage {
  prequalification('PREQUALIFICATION', 'Pre-qualification'),
  shortlisting('SHORTLISTING', 'Shortlist'),
  quotation('QUOTATION', 'Quotes'),
  evaluation('EVALUATION', 'Evaluation'),
  completed('COMPLETED', 'Awarded');

  const RfqStage(this.wire, this.label);
  final String wire;
  final String label;

  static RfqStage? parse(Object? v) {
    for (final s in values) {
      if (s.wire == v) return s;
    }
    return null;
  }

  /// The stage the owner moves it on to ("Start screening & shortlist"…), as the API allows.
  RfqStage? get next => switch (this) {
    prequalification => shortlisting,
    shortlisting => quotation,
    quotation => evaluation,
    _ => null,
  };

  /// The words on the owner's button that moves it on.
  String? get nextAction => switch (this) {
    prequalification => 'Start screening & shortlist',
    shortlisting => 'Open detailed quotes',
    quotation => 'Begin evaluation',
    _ => null,
  };
}

enum RfqVisibility {
  public('PUBLIC'),
  targeted('TARGETED');

  const RfqVisibility(this.wire);
  final String wire;

  static RfqVisibility parse(Object? v) => v == 'TARGETED' ? targeted : public;
}

/// A bid's place in the buyer's triage.
enum BidStatus {
  pending('PENDING', 'New'),
  shortlisted('SHORTLISTED', 'Shortlisted'),
  rejected('REJECTED', 'Declined'),
  awarded('AWARDED', 'Awarded');

  const BidStatus(this.wire, this.label);
  final String wire;
  final String label;

  static BidStatus parse(Object? v) => values.firstWhere((s) => s.wire == v, orElse: () => pending);
}

enum InviteStatus {
  invited('INVITED', 'Invited'),
  responded('RESPONDED', 'Responded'),
  declined('DECLINED', 'Declined');

  const InviteStatus(this.wire, this.label);
  final String wire;
  final String label;

  static InviteStatus? parse(Object? v) {
    for (final s in values) {
      if (s.wire == v) return s;
    }
    return null;
  }
}

enum PreQualStatus {
  pending('PENDING', 'To screen'),
  qualified('QUALIFIED', 'Qualified'),
  rejected('REJECTED', 'Not qualified');

  const PreQualStatus(this.wire, this.label);
  final String wire;
  final String label;

  static PreQualStatus parse(Object? v) => values.firstWhere((s) => s.wire == v, orElse: () => pending);
}

/// A supplier's reach, and the reach an RFQ asks for.
enum Presence {
  local('LOCAL', 'Local'),
  panIndia('PAN_INDIA', 'Pan-India'),
  global('GLOBAL', 'Global');

  const Presence(this.wire, this.label);
  final String wire;
  final String label;

  static Presence? parse(Object? v) {
    for (final p in values) {
      if (p.wire == v) return p;
    }
    return null;
  }
}

/// The owner's lifecycle moves (`POST /rfq/:id/publish|close|cancel`).
enum RfqAction { publish, close, cancel }

// ---- Parsing helpers ---------------------------------------------------------

double? asDouble(Object? v) => switch (v) {
  null => null,
  num n => n.toDouble(),
  String s => double.tryParse(s),
  _ => null,
};

int? asInt(Object? v) => switch (v) {
  null => null,
  int n => n,
  num n => n.round(),
  String s => int.tryParse(s),
  _ => null,
};

DateTime? asDate(Object? v) => v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

String? asText(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

List<String> asStrings(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is String && e.isNotEmpty) e,
      ]
    : const [];

Map<String, dynamic> asMap(Object? v) => v is Map<String, dynamic> ? v : const {};

List<Map<String, dynamic>> asMaps(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is Map<String, dynamic>) e,
      ]
    : const [];

// ---- Pieces of a requirement ----------------------------------------------------

/// One line of what is wanted ("Floor scrubber machine × 2 units").
class RfqItem {
  const RfqItem({required this.name, this.quantity = 1, this.unit, this.specification});

  final String name;
  final int quantity;
  final String? unit;
  final String? specification;

  factory RfqItem.fromJson(Map<String, dynamic> j) => RfqItem(
    name: j['name'] as String? ?? '',
    quantity: asInt(j['quantity']) ?? 1,
    unit: asText(j['unit']),
    specification: asText(j['specification']),
  );

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'quantity': quantity,
    if (unit != null && unit!.trim().isNotEmpty) 'unit': unit!.trim(),
    if (specification != null && specification!.trim().isNotEmpty) 'specification': specification!.trim(),
  };
}

/// One service location as the place search returned it (`GET /locations/search`), with its own state and
/// country: a requirement's `serviceLocations`.
class RfqPlace {
  const RfqPlace({required this.label, this.city, this.state, this.country, this.countryCode});

  final String label;
  final String? city;
  final String? state;
  final String? country;

  /// ISO 3166-1 alpha-2, when known.
  final String? countryCode;

  /// A place typed rather than picked: its own name, nothing more known.
  factory RfqPlace.typed(String name) => RfqPlace(label: name.trim(), city: name.trim());

  factory RfqPlace.fromJson(Map<String, dynamic> j) => RfqPlace(
    label: j['label'] as String? ?? '',
    city: asText(j['city']),
    state: asText(j['state']),
    country: asText(j['country']),
    countryCode: asText(j['countryCode']),
  );

  /// As `CreateRfqDto.serviceLocations` takes it.
  Map<String, dynamic> toJson() => {
    'label': label,
    'city': city,
    'state': state,
    'country': country,
    'countryCode': countryCode,
  };

  /// "Maharashtra, India": what a picker shows under the name, leaving out what the name already says.
  String get hint => [
    for (final part in [city, state, country])
      if (part != null && !label.toLowerCase().contains(part.toLowerCase())) part,
  ].join(', ');

  @override
  bool operator ==(Object other) => other is RfqPlace && other.label.toLowerCase() == label.toLowerCase();

  @override
  int get hashCode => label.toLowerCase().hashCode;
}

/// A drawing, photo or quotation, with the title its sender gave it.
class RfqFile {
  const RfqFile({required this.id, required this.title, required this.url, this.name, this.mimeType, this.size});

  final String id;
  final String title;
  final String url;
  final String? name;
  final String? mimeType;
  final int? size;

  factory RfqFile.fromJson(Map<String, dynamic> j) => RfqFile(
    id: j['id'] as String? ?? '',
    title: j['title'] as String? ?? 'File',
    url: j['url'] as String? ?? '',
    name: asText(j['name']),
    mimeType: asText(j['mimeType']),
    size: asInt(j['size']),
  );

  bool get isImage => mimeType?.startsWith('image/') ?? false;
}

/// Who posted a requirement, as suppliers see it: the company it was posted
/// for (verified or not), else the name typed on it, else the poster.
class BuyerInfo {
  const BuyerInfo({
    required this.name,
    this.companyId,
    this.companyName,
    this.logoUrl,
    this.verified = false,
    this.verificationLevel,
    this.gstVerified = false,
  });

  final String name;
  final String? companyId;
  final String? companyName;
  final String? logoUrl;
  final bool verified;
  final String? verificationLevel;
  final bool gstVerified;

  String get displayName => companyName ?? name;

  static BuyerInfo? fromJson(Object? v) {
    if (v is! Map<String, dynamic>) return null;
    return BuyerInfo(
      name: v['name'] as String? ?? 'A buyer',
      companyId: asText(v['companyId']),
      companyName: asText(v['companyName']),
      logoUrl: asText(v['logoUrl']),
      verified: v['verified'] == true,
      verificationLevel: asText(v['verificationLevel']),
      gstVerified: v['gstVerified'] == true,
    );
  }
}

/// One reason a requirement suits a supplier ("Matches your service category").
class MatchReason {
  const MatchReason({required this.key, required this.label, required this.points, required this.hit});

  final String key;
  final String label;
  final int points;
  final bool hit;

  factory MatchReason.fromJson(Map<String, dynamic> j) => MatchReason(
    key: j['key'] as String? ?? '',
    label: j['label'] as String? ?? '',
    points: asInt(j['points']) ?? 0,
    hit: j['hit'] == true,
  );
}

/// What a requirement has drawn so far, on the buyer's list.
class ResponseCounts {
  const ResponseCounts({
    this.bids = 0,
    this.bidsPending = 0,
    this.prequal = 0,
    this.prequalPending = 0,
    this.invites = 0,
  });

  final int bids;
  final int bidsPending;
  final int prequal;
  final int prequalPending;
  final int invites;

  static ResponseCounts? fromJson(Object? v) {
    if (v is! Map<String, dynamic>) return null;
    return ResponseCounts(
      bids: asInt(v['bids']) ?? 0,
      bidsPending: asInt(v['bidsPending']) ?? 0,
      prequal: asInt(v['prequal']) ?? 0,
      prequalPending: asInt(v['prequalPending']) ?? 0,
      invites: asInt(v['invites']) ?? 0,
    );
  }
}

/// The supplier criteria of an RFQ (pre-qualification thresholds).
class SupplierCriteria {
  const SupplierCriteria({
    this.minYearsInBusiness,
    this.minAnnualTurnover,
    this.minLast3YrTurnover,
    this.minEmployees,
    this.requiredPresence,
    this.statutoryCompliance = const [],
  });

  final int? minYearsInBusiness;
  final double? minAnnualTurnover;
  final double? minLast3YrTurnover;
  final String? minEmployees;
  final Presence? requiredPresence;
  final List<String> statutoryCompliance;

  /// How many criteria are set (the compliance list counts as one).
  int get count =>
      [
        minYearsInBusiness,
        minAnnualTurnover,
        minLast3YrTurnover,
        minEmployees,
        requiredPresence,
      ].where((v) => v != null).length +
      (statutoryCompliance.isEmpty ? 0 : 1);

  bool get isEmpty => count == 0;

  factory SupplierCriteria.fromJson(Map<String, dynamic> j) => SupplierCriteria(
    minYearsInBusiness: asInt(j['minYearsInBusiness']),
    minAnnualTurnover: asDouble(j['minAnnualTurnover']),
    minLast3YrTurnover: asDouble(j['minLast3YrTurnover']),
    minEmployees: asText(j['minEmployees']),
    requiredPresence: Presence.parse(j['requiredPresence']),
    statutoryCompliance: asStrings(j['statutoryCompliance']),
  );
}

// ---- The requirement --------------------------------------------------------------

class Requirement {
  const Requirement({
    required this.id,
    required this.title,
    required this.kind,
    required this.status,
    this.description,
    this.stage,
    this.visibility = RfqVisibility.public,
    this.closedReason,
    this.buyerId,
    this.companyId,
    this.category,
    this.subcategory,
    this.service,
    this.facilityType,
    this.locations = const [],
    this.serviceLocations = const [],
    this.city,
    this.state,
    this.country,
    this.scope,
    this.budget,
    this.dueDate,
    this.preQualEndDate,
    this.criteria = const SupplierCriteria(),
    this.contactName,
    this.contactEmail,
    this.contactPhone,
    this.companyName,
    this.items = const [],
    this.files = const [],
    this.quoteCount = 0,
    this.inviteCount = 0,
    this.createdAt,
    this.publishedAt,
    this.updatedAt,
    this.postedBy,
    this.responses,
    this.awardedTo,
    this.buyer,
    this.hasBid = false,
    this.matchScore,
    this.matched = false,
    this.matchReasons = const [],
    this.inviteStatus,
    this.invitedAt,
  });

  final String id;
  final String title;
  final RfqKind kind;
  final RfqStatus status;
  final String? description;
  final RfqStage? stage;
  final RfqVisibility visibility;

  /// `EXPIRED` (an enquiry's reply-by date passed) or `BUYER`.
  final String? closedReason;
  final String? buyerId;
  final String? companyId;

  /// Taxonomy keys, broadest first.
  final String? category;
  final String? subcategory;
  final String? service;
  final String? facilityType;
  final List<String> locations;

  /// Each place as picked, with its state and country (empty on a requirement older than the place search).
  final List<RfqPlace> serviceLocations;
  final String? city;
  final String? state;
  final String? country;
  final String? scope;
  final double? budget;
  final DateTime? dueDate;
  final DateTime? preQualEndDate;
  final SupplierCriteria criteria;
  final String? contactName;
  final String? contactEmail;
  final String? contactPhone;
  final String? companyName;
  final List<RfqItem> items;
  final List<RfqFile> files;

  /// Bids or replies received (`_count.quotes`).
  final int quoteCount;
  final int inviteCount;
  final DateTime? createdAt;
  final DateTime? publishedAt;
  final DateTime? updatedAt;

  /// On the buyer's list: the colleague who posted it (null when it is the viewer's own).
  final String? postedBy;
  final ResponseCounts? responses;

  /// The supplier whose bid won.
  final String? awardedTo;

  /// On the supplier's board.
  final BuyerInfo? buyer;
  final bool hasBid;
  final int? matchScore;
  final bool matched;
  final List<MatchReason> matchReasons;
  final InviteStatus? inviteStatus;
  final DateTime? invitedAt;

  bool get isEnquiry => kind == RfqKind.enquiry;

  /// A staged RFQ: pre-qualification, shortlist, quotes, evaluation, award.
  bool get staged => kind == RfqKind.rfq && stage != null;

  bool get live => status == RfqStatus.published;

  /// An enquiry that closed on its reply-by date: the buyer may still select a reply.
  bool get expiredEnquiry => isEnquiry && status == RfqStatus.closed && closedReason == 'EXPIRED';

  /// The most specific taxonomy key it was posted under.
  String? get serviceKey => service ?? subcategory ?? category;

  /// Where the work is: the cities, else the one city.
  List<String> get places => locations.isNotEmpty ? locations : [?city];

  /// What suppliers read: the scope of an RFQ, else the description.
  String? get text => (kind == RfqKind.rfq ? asText(scope) : null) ?? asText(description) ?? asText(scope);

  /// The deadline that matters now: the pre-qualification cutoff while an RFQ
  /// is in pre-qualification, else the quote (or reply-by) date.
  DateTime? get currentDeadline => stage == RfqStage.prequalification ? (preQualEndDate ?? dueDate) : dueDate;

  factory Requirement.fromJson(Map<String, dynamic> j) {
    final count = asMap(j['_count']);
    final awarded = j['awardedTo'];
    final posted = j['postedBy'];
    return Requirement(
      id: j['id'] as String? ?? '',
      title: (j['title'] as String? ?? '').trim(),
      kind: RfqKind.parse(j['kind']),
      status: RfqStatus.parse(j['status']),
      description: asText(j['description']),
      stage: RfqStage.parse(j['stage']),
      visibility: RfqVisibility.parse(j['visibility']),
      closedReason: asText(j['closedReason']),
      buyerId: asText(j['buyerId']),
      companyId: asText(j['companyId']),
      category: asText(j['category']),
      subcategory: asText(j['subcategory']),
      service: asText(j['service']),
      facilityType: asText(j['facilityType']),
      locations: asStrings(j['locations']),
      serviceLocations: [for (final p in asMaps(j['serviceLocations'])) RfqPlace.fromJson(p)],
      city: asText(j['city']),
      state: asText(j['state']),
      country: asText(j['country']),
      scope: asText(j['scope']),
      budget: asDouble(j['budget']),
      dueDate: asDate(j['dueDate']),
      preQualEndDate: asDate(j['preQualEndDate']),
      criteria: SupplierCriteria.fromJson(j),
      contactName: asText(j['contactName']),
      contactEmail: asText(j['contactEmail']),
      contactPhone: asText(j['contactPhone']),
      companyName: asText(j['companyName']),
      items: [for (final i in asMaps(j['items'])) RfqItem.fromJson(i)],
      files: [for (final f in asMaps(j['attachments'])) RfqFile.fromJson(f)],
      quoteCount: asInt(count['quotes']) ?? 0,
      inviteCount: asInt(count['invites']) ?? 0,
      createdAt: asDate(j['createdAt']),
      publishedAt: asDate(j['publishedAt']),
      updatedAt: asDate(j['updatedAt']),
      postedBy: posted is Map ? asText(posted['name']) : null,
      responses: ResponseCounts.fromJson(j['responses']),
      awardedTo: awarded is Map ? asText(awarded['name']) : null,
      buyer: BuyerInfo.fromJson(j['buyer']),
      hasBid: j['hasBid'] == true,
      matchScore: asInt(j['matchScore']),
      matched: j['matched'] == true,
      matchReasons: [for (final r in asMaps(j['matchReasons'])) MatchReason.fromJson(r)],
      inviteStatus: InviteStatus.parse(j['inviteStatus']),
      invitedAt: asDate(j['invitedAt']),
    );
  }

  Requirement copyWith({
    RfqStatus? status,
    RfqStage? stage,
    bool clearStage = false,
    String? title,
    bool? hasBid,
    ResponseCounts? responses,
    InviteStatus? inviteStatus,
  }) => Requirement(
    id: id,
    title: title ?? this.title,
    kind: kind,
    status: status ?? this.status,
    description: description,
    stage: clearStage ? null : (stage ?? this.stage),
    visibility: visibility,
    closedReason: closedReason,
    buyerId: buyerId,
    companyId: companyId,
    category: category,
    subcategory: subcategory,
    service: service,
    facilityType: facilityType,
    locations: locations,
    serviceLocations: serviceLocations,
    city: city,
    state: state,
    country: country,
    scope: scope,
    budget: budget,
    dueDate: dueDate,
    preQualEndDate: preQualEndDate,
    criteria: criteria,
    contactName: contactName,
    contactEmail: contactEmail,
    contactPhone: contactPhone,
    companyName: companyName,
    items: items,
    files: files,
    quoteCount: quoteCount,
    inviteCount: inviteCount,
    createdAt: createdAt,
    publishedAt: publishedAt,
    updatedAt: updatedAt,
    postedBy: postedBy,
    responses: responses ?? this.responses,
    awardedTo: awardedTo,
    buyer: buyer,
    hasBid: hasBid ?? this.hasBid,
    matchScore: matchScore,
    matched: matched,
    matchReasons: matchReasons,
    inviteStatus: inviteStatus ?? this.inviteStatus,
    invitedAt: invitedAt,
  );
}

/// A page of the buyer's requirements.
class RequirementPage {
  const RequirementPage({required this.rows, required this.total, required this.hasMore});

  final List<Requirement> rows;
  final int total;
  final bool hasMore;
}

/// The buyer's views (tabs and tiles), as `GET /rfq/mine` takes them.
enum MyView {
  all('ALL', 'All'),
  live('LIVE', 'Live'),
  draft('DRAFT', 'Drafts'),
  awarded('AWARDED', 'Awarded'),
  ended('ENDED', 'Ended'),
  attention('ATTENTION', 'Waiting on you'),
  closing('CLOSING', 'Closing this week');

  const MyView(this.wire, this.label);
  final String wire;
  final String label;
}

/// How the buyer's list is ordered (`sort`).
enum MySort {
  updated('updated', 'Recently updated'),
  closing('closing', 'Closing soonest'),
  newest('newest', 'Newest'),
  title('title', 'Title A–Z');

  const MySort(this.wire, this.label);
  final String wire;
  final String label;
}

/// One thing a live requirement is waiting on the buyer for.
class ActionItem {
  const ActionItem({
    required this.kind,
    required this.rfqId,
    required this.title,
    required this.rfqKind,
    required this.count,
    this.deadline,
  });

  /// `AWARD`, `SCREEN`, `BIDS` or `NO_REPLIES`.
  final String kind;
  final String rfqId;
  final String title;
  final RfqKind rfqKind;
  final int count;
  final DateTime? deadline;

  factory ActionItem.fromJson(Map<String, dynamic> j) => ActionItem(
    kind: j['kind'] as String? ?? 'BIDS',
    rfqId: j['rfqId'] as String? ?? '',
    title: j['title'] as String? ?? '',
    rfqKind: RfqKind.parse(j['rfqKind']),
    count: asInt(j['count']) ?? 0,
    deadline: asDate(j['deadline']),
  );
}

/// The counts on the buyer's tabs and tiles (`GET /rfq/mine/summary`).
class RequirementsSummary {
  const RequirementsSummary({
    this.views = const {},
    this.pendingResponses = 0,
    this.enquiries = 0,
    this.rfqs = 0,
    this.nextDeadline,
    this.actionItems = const [],
    this.actionCount = 0,
  });

  final Map<MyView, int> views;
  final int pendingResponses;
  final int enquiries;
  final int rfqs;
  final DateTime? nextDeadline;
  final List<ActionItem> actionItems;
  final int actionCount;

  int count(MyView view) => views[view] ?? 0;

  /// What the "My RFQ's" chip counts: every requirement the screen lists when it opens (its All tab: live, drafts,
  /// awarded and ended). It once counted only the live ones and drafts, so a chip that read 4 opened a list of 6.
  int get open => count(MyView.all);

  factory RequirementsSummary.fromJson(Map<String, dynamic> j) {
    final views = asMap(j['views']);
    return RequirementsSummary(
      views: {for (final v in MyView.values) v: asInt(views[v.wire]) ?? 0},
      pendingResponses: asInt(j['pendingResponses']) ?? 0,
      enquiries: asInt(j['enquiries']) ?? 0,
      rfqs: asInt(j['rfqs']) ?? 0,
      nextDeadline: asDate(j['nextDeadline']),
      actionItems: [for (final a in asMaps(j['actionItems'])) ActionItem.fromJson(a)],
      actionCount: asInt(j['actionCount']) ?? 0,
    );
  }
}

// ---- Responses, for the owner ----------------------------------------------------------

/// A supplier, as a row about them names them.
class SupplierRef {
  const SupplierRef({
    required this.vendorId,
    required this.name,
    this.companyId,
    this.logoUrl,
    this.rating = 0,
    this.ratingCount = 0,
    this.headline,
    this.city,
    this.verificationLevel,
  });

  final String vendorId;
  final String name;
  final String? companyId;
  final String? logoUrl;
  final double rating;
  final int ratingCount;
  final String? headline;
  final String? city;
  final String? verificationLevel;

  bool get verified => verificationLevel != null && verificationLevel != 'REGISTERED';

  /// A `vendor` object with its `company` inside (bids, invites, responses).
  factory SupplierRef.fromVendor(Map<String, dynamic> v, {String? companyId}) {
    final company = asMap(v['company']);
    return SupplierRef(
      vendorId: v['id'] as String? ?? '',
      name: asText(company['name']) ?? asText(v['headline']) ?? 'Supplier',
      companyId: companyId ?? asText(v['companyId']),
      logoUrl: asText(company['logoUrl']),
      rating: asDouble(v['rating']) ?? 0,
      ratingCount: asInt(v['ratingCount']) ?? 0,
      headline: asText(v['headline']),
      city: asText(company['city']) ?? asText(v['city']),
      verificationLevel: asText(v['verificationLevel']),
    );
  }
}

/// A bid (or an enquiry reply) on the owner's requirement.
class Bid {
  const Bid({
    required this.id,
    required this.rfqId,
    required this.supplier,
    required this.status,
    this.amount,
    this.message,
    this.leadTimeDays,
    this.isAwarded = false,
    this.createdAt,
    this.files = const [],
    this.conversationId,
  });

  final String id;
  final String rfqId;
  final SupplierRef supplier;
  final BidStatus status;
  final double? amount;
  final String? message;
  final int? leadTimeDays;
  final bool isAwarded;
  final DateTime? createdAt;
  final List<RfqFile> files;

  /// The thread the bid opened with its supplier, when there is one.
  final String? conversationId;

  factory Bid.fromJson(Map<String, dynamic> j) => Bid(
    id: j['id'] as String? ?? '',
    rfqId: j['rfqId'] as String? ?? '',
    supplier: SupplierRef.fromVendor(asMap(j['vendor']), companyId: asText(j['supplierCompanyId'])),
    status: j['isAwarded'] == true ? BidStatus.awarded : BidStatus.parse(j['status']),
    amount: asDouble(j['totalAmount']),
    message: asText(j['message']),
    leadTimeDays: asInt(j['leadTimeDays']),
    isAwarded: j['isAwarded'] == true,
    createdAt: asDate(j['createdAt']),
    files: [for (final f in asMaps(j['attachments'])) RfqFile.fromJson(f)],
    conversationId: asText(j['conversationId']),
  );

  Bid withStatus(BidStatus next) => Bid(
    id: id,
    rfqId: rfqId,
    supplier: supplier,
    status: next,
    amount: amount,
    message: message,
    leadTimeDays: leadTimeDays,
    isAwarded: next == BidStatus.awarded,
    createdAt: createdAt,
    files: files,
    conversationId: conversationId,
  );
}

/// A supplier invited to quote, and what they did about it.
class SupplierInvite {
  const SupplierInvite({required this.supplier, required this.status, this.createdAt});

  final SupplierRef supplier;
  final InviteStatus status;
  final DateTime? createdAt;

  factory SupplierInvite.fromJson(Map<String, dynamic> j) => SupplierInvite(
    supplier: SupplierRef.fromVendor(asMap(j['vendor'])),
    status: InviteStatus.parse(j['status']) ?? InviteStatus.invited,
    createdAt: asDate(j['createdAt']),
  );
}

/// A supplier that fits the requirement and is not invited yet, or one found by name.
class SupplierHit {
  const SupplierHit({required this.supplier, this.matchScore});

  final SupplierRef supplier;
  final int? matchScore;

  factory SupplierHit.fromJson(Map<String, dynamic> j) =>
      SupplierHit(supplier: SupplierRef.fromVendor(j), matchScore: asInt(j['matchScore']));
}

/// One supplier's pre-qualification answers on a staged RFQ.
class PreQualResponse {
  const PreQualResponse({
    required this.supplier,
    required this.status,
    this.shortlisted = false,
    this.yearsInBusiness,
    this.annualTurnover,
    this.last3YrTurnover,
    this.employeeCount,
    this.presence,
    this.statutoryCompliance = const [],
    this.meetsCriteria = true,
    this.failures = const [],
    this.submittedAt,
  });

  final SupplierRef supplier;
  final PreQualStatus status;
  final bool shortlisted;
  final int? yearsInBusiness;
  final double? annualTurnover;
  final double? last3YrTurnover;
  final String? employeeCount;
  final Presence? presence;
  final List<String> statutoryCompliance;
  final bool meetsCriteria;
  final List<String> failures;
  final DateTime? submittedAt;

  factory PreQualResponse.fromJson(Map<String, dynamic> j) => PreQualResponse(
    supplier: SupplierRef.fromVendor(asMap(j['vendor'])),
    status: PreQualStatus.parse(j['preQualStatus']),
    shortlisted: j['shortlisted'] == true,
    yearsInBusiness: asInt(j['yearsInBusiness']),
    annualTurnover: asDouble(j['annualTurnover']),
    last3YrTurnover: asDouble(j['last3YrTurnover']),
    employeeCount: asText(j['employeeCount']),
    presence: Presence.parse(j['presence']),
    statutoryCompliance: asStrings(j['statutoryCompliance']),
    meetsCriteria: j['meetsCriteria'] != false,
    failures: asStrings(j['failures']),
    submittedAt: asDate(j['submittedAt']),
  );

  PreQualResponse copyWith({PreQualStatus? status, bool? shortlisted}) => PreQualResponse(
    supplier: supplier,
    status: status ?? this.status,
    shortlisted: shortlisted ?? this.shortlisted,
    yearsInBusiness: yearsInBusiness,
    annualTurnover: annualTurnover,
    last3YrTurnover: last3YrTurnover,
    employeeCount: employeeCount,
    presence: presence,
    statutoryCompliance: statutoryCompliance,
    meetsCriteria: meetsCriteria,
    failures: failures,
    submittedAt: submittedAt,
  );
}

/// A conversation with one supplier about the requirement (`GET /rfq/:id/conversations`).
class SupplierThread {
  const SupplierThread({
    required this.conversationId,
    required this.companyId,
    required this.companyName,
    this.lastMessage,
    this.lastAt,
    this.unread = 0,
  });

  final String conversationId;
  final String companyId;
  final String companyName;
  final String? lastMessage;
  final DateTime? lastAt;
  final int unread;

  factory SupplierThread.fromJson(Map<String, dynamic> j) {
    final company = asMap(j['company']);
    final last = asMap(j['lastMessage']);
    return SupplierThread(
      conversationId: j['conversationId'] as String? ?? '',
      companyId: company['id'] as String? ?? '',
      companyName: company['name'] as String? ?? 'Supplier',
      lastMessage: asText(last['body']),
      lastAt: asDate(last['at']) ?? asDate(j['updatedAt']),
      unread: asInt(j['unread']) ?? 0,
    );
  }
}

// ---- The supplier's side ---------------------------------------------------------------

/// What the supplier's company may do on the board (`GET /vendors/me/access`).
class VendorAccess {
  const VendorAccess({
    this.vendorId,
    this.verified = false,
    this.canBid = false,
    this.canRespondToEnquiry = false,
    this.bidsUsed = 0,
    this.bidLimit,
    this.canRevealContact = false,
    this.listingStartsVerified = false,
    this.verificationLevel,
    this.tier,
  });

  final String? vendorId;
  final bool verified;
  final bool canBid;
  final bool canRespondToEnquiry;
  final int bidsUsed;

  /// This month's RFQ quote allowance; null is unlimited.
  final int? bidLimit;
  final bool canRevealContact;
  final bool listingStartsVerified;
  final String? verificationLevel;
  final String? tier;

  bool get hasListing => vendorId != null;

  factory VendorAccess.fromJson(Map<String, dynamic> j) => VendorAccess(
    vendorId: asText(j['vendorId']),
    verified: j['verified'] == true,
    canBid: j['canBid'] == true,
    canRespondToEnquiry: j['canRespondToEnquiry'] == true,
    bidsUsed: asInt(j['bidsUsed']) ?? 0,
    bidLimit: asInt(j['bidLimit']),
    canRevealContact: j['canRevealContact'] == true,
    listingStartsVerified: j['listingStartsVerified'] == true,
    verificationLevel: asText(j['verificationLevel']),
    tier: asText(j['tier']),
  );
}

/// The supplier's own bid, with the requirement it is on.
class MyBid {
  const MyBid({
    required this.id,
    required this.rfqId,
    required this.status,
    this.amount,
    this.message,
    this.leadTimeDays,
    this.isAwarded = false,
    this.createdAt,
    this.files = const [],
    this.requirement,
    this.poNumber,
  });

  final String id;
  final String rfqId;
  final BidStatus status;
  final double? amount;
  final String? message;
  final int? leadTimeDays;
  final bool isAwarded;
  final DateTime? createdAt;
  final List<RfqFile> files;
  final Requirement? requirement;
  final String? poNumber;

  factory MyBid.fromJson(Map<String, dynamic> j) {
    final rfq = j['rfq'];
    final po = asMap(j['purchaseOrder']);
    return MyBid(
      id: j['id'] as String? ?? '',
      rfqId: j['rfqId'] as String? ?? (rfq is Map ? rfq['id'] as String? ?? '' : ''),
      status: j['isAwarded'] == true ? BidStatus.awarded : BidStatus.parse(j['status']),
      amount: asDouble(j['totalAmount']),
      message: asText(j['message']),
      leadTimeDays: asInt(j['leadTimeDays']),
      isAwarded: j['isAwarded'] == true,
      createdAt: asDate(j['createdAt']),
      files: [for (final f in asMaps(j['attachments'])) RfqFile.fromJson(f)],
      requirement: rfq is Map<String, dynamic> ? Requirement.fromJson(rfq) : null,
      poNumber: asText(po['poNumber']),
    );
  }
}

/// The board's view of one requirement for the supplier reading it.
class OpportunityContext {
  const OpportunityContext({this.buyer, this.matchScore, this.matched = false, this.reasons = const [], this.myBid});

  final BuyerInfo? buyer;
  final int? matchScore;
  final bool matched;
  final List<MatchReason> reasons;
  final MyBid? myBid;

  factory OpportunityContext.fromJson(Map<String, dynamic> j) {
    final match = asMap(j['match']);
    final bid = j['myBid'];
    return OpportunityContext(
      buyer: BuyerInfo.fromJson(j['buyer']),
      matchScore: asInt(match['score']),
      matched: match['matched'] == true,
      reasons: [for (final r in asMaps(match['reasons'])) MatchReason.fromJson(r)],
      myBid: bid is Map<String, dynamic> ? MyBid.fromJson(bid) : null,
    );
  }
}

/// The buyer's contact, once a supplier who bid may see it.
class BuyerContact {
  const BuyerContact({required this.name, this.companyName, this.email, this.phone});

  final String name;
  final String? companyName;
  final String? email;
  final String? phone;

  factory BuyerContact.fromJson(Map<String, dynamic> j) {
    final person = '${j['firstName'] as String? ?? ''} ${j['lastName'] as String? ?? ''}'.trim();
    return BuyerContact(
      name: asText(j['contactName']) ?? (person.isEmpty ? 'The buyer' : person),
      companyName: asText(j['companyName']),
      email: asText(j['email']),
      phone: asText(j['phone']),
    );
  }
}

/// The open board's sorts (`sort` on `GET /rfq/open`).
enum BoardSort {
  match('match', 'Best match'),
  newest('newest', 'Newest'),
  closing('closing', 'Closing soon'),
  budget('budget', 'Highest budget');

  const BoardSort(this.wire, this.label);
  final String wire;
  final String label;
}

/// What the open board is narrowed to.
class BoardQuery {
  const BoardQuery({
    this.search = '',
    this.matchedOnly = false,
    this.sort = BoardSort.match,
    this.city,
    this.minBudget,
    this.maxBudget,
    this.closingInDays,
    this.verifiedBuyer = false,
  });

  final String search;
  final bool matchedOnly;
  final BoardSort sort;
  final String? city;
  final double? minBudget;
  final double? maxBudget;
  final int? closingInDays;
  final bool verifiedBuyer;

  /// Filters beyond the tab, the search and the sort.
  int get filterCount =>
      [city, minBudget, maxBudget, closingInDays].where((v) => v != null).length + (verifiedBuyer ? 1 : 0);

  Map<String, dynamic> toQuery({required int page, required int limit}) => {
    'page': page,
    'limit': limit,
    if (search.trim().isNotEmpty) 'search': search.trim(),
    if (matchedOnly) 'matchedOnly': 'true',
    'sort': sort.wire,
    if (city != null && city!.trim().isNotEmpty) 'city': city!.trim(),
    'minBudget': ?minBudget,
    'maxBudget': ?maxBudget,
    'closingInDays': ?closingInDays,
    if (verifiedBuyer) 'verifiedBuyer': 'true',
  };

  BoardQuery copyWith({
    String? search,
    bool? matchedOnly,
    BoardSort? sort,
    String? city,
    bool clearCity = false,
    double? minBudget,
    bool clearMin = false,
    double? maxBudget,
    bool clearMax = false,
    int? closingInDays,
    bool clearClosing = false,
    bool? verifiedBuyer,
  }) => BoardQuery(
    search: search ?? this.search,
    matchedOnly: matchedOnly ?? this.matchedOnly,
    sort: sort ?? this.sort,
    city: clearCity ? null : (city ?? this.city),
    minBudget: clearMin ? null : (minBudget ?? this.minBudget),
    maxBudget: clearMax ? null : (maxBudget ?? this.maxBudget),
    closingInDays: clearClosing ? null : (closingInDays ?? this.closingInDays),
    verifiedBuyer: verifiedBuyer ?? this.verifiedBuyer,
  );

  /// The tab, the search and the sort, without the filters.
  BoardQuery cleared() => BoardQuery(search: search, matchedOnly: matchedOnly, sort: sort);
}

// ---- Alerts ------------------------------------------------------------------------------

/// Which side of a requirement an alert is about.
enum AlertSide { owner, supplier }

/// A notification about a requirement: a match, an invitation, a bid in, an
/// outcome. The "Alerts" chip's list.
class RfqAlert {
  const RfqAlert({
    required this.id,
    required this.title,
    required this.type,
    this.body,
    this.link,
    this.readAt,
    this.createdAt,
    this.companyName,
    this.count = 1,
  });

  final String id;
  final String title;
  final String type;
  final String? body;
  final String? link;
  final DateTime? readAt;
  final DateTime? createdAt;

  /// The company the reader was told this as a member of.
  final String? companyName;
  final int count;

  bool get unread => readAt == null;

  /// The notification types about requirements (`notification-types.ts`).
  static const types = {
    'bid_received',
    'bid_awarded',
    'bid_rejected',
    'rfq_invite',
    'rfq_match',
    'enquiry_match',
    'enquiry_expired',
    'prequal_submitted',
    'prequal_result',
    'shortlisted',
    'rfq_quotes_open',
  };

  static final _owner = RegExp(r'^/manage/requirements/([^/?#]+)');
  static final _bid = RegExp(r'[?&]bid=([^&#]+)');
  static final _section = RegExp(r'[?&]section=([^&#]+)');
  static final _supplier = RegExp(r'^/manage/bids/([^/?#]+)');

  /// The requirement it is about, read from its link.
  String? get rfqId => _owner.firstMatch(link ?? '')?.group(1) ?? _supplier.firstMatch(link ?? '')?.group(1);

  /// The one bid an alert about a bid came for (`?bid=`): the owner's page rings it.
  String? get bidId => _bid.firstMatch(link ?? '')?.group(1);

  /// The part of the page it opens on (`?section=`: `prequal`, `invited`, `response`).
  String? get section => _section.firstMatch(link ?? '')?.group(1);

  /// The owner's page or the supplier's.
  AlertSide get side => _owner.hasMatch(link ?? '') ? AlertSide.owner : AlertSide.supplier;

  /// One of ours: an RFQ type, or a link into a requirement.
  static bool isAbout(Map<String, dynamic> j) {
    final link = j['link'] as String? ?? '';
    return types.contains(j['type']) || _owner.hasMatch(link) || _supplier.hasMatch(link);
  }

  factory RfqAlert.fromJson(Map<String, dynamic> j) => RfqAlert(
    id: j['id'] as String? ?? '',
    title: j['title'] as String? ?? '',
    type: j['type'] as String? ?? 'info',
    body: asText(j['body']),
    link: asText(j['link']),
    readAt: asDate(j['readAt']),
    createdAt: asDate(j['createdAt']),
    companyName: asText(asMap(j['company'])['name']),
    count: asInt(j['count']) ?? 1,
  );

  RfqAlert read([DateTime? at]) => RfqAlert(
    id: id,
    title: title,
    type: type,
    body: body,
    link: link,
    readAt: at ?? DateTime.now(),
    createdAt: createdAt,
    companyName: companyName,
    count: count,
  );
}

/// What the Marketplace's chips show: "My RFQ's 3" and "Alerts 2 new".
class RfqCounts {
  const RfqCounts({this.myRfqs = 0, this.newAlerts = 0});

  /// The buyer's requirements still in play: live and drafts (`GET /rfq/mine/summary`).
  final int myRfqs;

  /// Unread notifications about requirements (`GET /notifications?unread=true`).
  final int newAlerts;
}

// ---- The composer's lookups --------------------------------------------------------------

/// A node of the service taxonomy (`GET /categories/tree?kind=SERVICE`).
class CategoryNode {
  const CategoryNode({required this.id, required this.key, required this.name, this.children = const []});

  final String id;
  final String key;
  final String name;
  final List<CategoryNode> children;

  factory CategoryNode.fromJson(Map<String, dynamic> j) => CategoryNode(
    id: j['id'] as String? ?? '',
    key: (j['key'] as String?) ?? (j['slug'] as String? ?? ''),
    name: j['name'] as String? ?? '',
    children: [for (final c in asMaps(j['children'])) CategoryNode.fromJson(c)],
  );
}

/// Who is posting: the person and the company they act for.
class Poster {
  const Poster({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.companyId,
    this.companyName,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? companyId;
  final String? companyName;

  bool get hasPhone => phone != null && phone!.trim().isNotEmpty;

  /// Roles that post and run requirements (`REQUIREMENT_TEAM_ROLES` + staff).
  bool get canPost => const {'BUYER', 'COMPANY_ADMIN', 'VENDOR', 'SUPER_ADMIN'}.contains(role);

  /// Roles the supplier board is open to.
  bool get canSell => const {'VENDOR', 'COMPANY_ADMIN', 'SUPER_ADMIN'}.contains(role);

  /// A member of a company in a role that does not post or run requirements (an office admin, a recruiter, a hiring
  /// manager): the API refuses every call with "Insufficient role permissions", and a new company is not the fix.
  bool get roleCannotPost => companyId != null && !canPost;

  /// The role in words, for [cannotPostMessage].
  String get roleWords => switch (role) {
    'BRANCH_ADMIN' => 'an office admin',
    'RECRUITER' => 'a recruiter',
    'HIRING_MANAGER' => 'a hiring manager',
    _ => 'a team member',
  };

  /// Why this account cannot post, in the words the screens show before the API has to refuse.
  String get cannotPostMessage {
    final at = (companyName ?? '').trim().isEmpty ? '' : ' at $companyName';
    return "Posting and running requirements is for a company's admins and buyers. As $roleWords$at you can't post or "
        "manage them. Ask one of the company's admins to post it for you.";
  }
}

/// What posting answered: the requirement, and how many suppliers it reached.
class PostResult {
  const PostResult({required this.id, required this.kind, required this.status, this.alertedNow, this.alertedLater});

  final String id;
  final RfqKind kind;
  final RfqStatus status;
  final int? alertedNow;
  final int? alertedLater;

  factory PostResult.fromJson(Map<String, dynamic> j) {
    final alerts = asMap(j['matchAlerts']);
    return PostResult(
      id: j['id'] as String? ?? '',
      kind: RfqKind.parse(j['kind']),
      status: RfqStatus.parse(j['status']),
      alertedNow: asInt(alerts['now']),
      alertedLater: asInt(alerts['later']),
    );
  }
}
