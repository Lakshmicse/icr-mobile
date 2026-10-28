import 'package:flutter/painting.dart' show Color;

import 'marketplace_json.dart';

/// The supplier trust ladder (`VerificationLevel` in the API), lowest first.
enum SupplierLevel {
  registered('REGISTERED', 'Registered'),
  verified('VERIFIED', 'Verified'),
  certified('CERTIFIED', 'Certified'),
  preferred('PREFERRED', 'Preferred'),
  elite('ELITE', 'Elite');

  const SupplierLevel(this.api, this.label);

  final String api;
  final String label;

  /// At least Verified: the profile's blue seal beside the name.
  bool get isVerified => index >= SupplierLevel.verified.index;

  bool atLeast(SupplierLevel other) => index >= other.index;

  /// The profile's tier line ("Tier-1"): the top rung is the first tier.
  /// Registered is on the ladder but not a tier.
  String? get tier => switch (this) {
    SupplierLevel.elite => 'Tier-1',
    SupplierLevel.preferred => 'Tier-2',
    SupplierLevel.certified => 'Tier-3',
    SupplierLevel.verified => 'Tier-4',
    SupplierLevel.registered => null,
  };

  static SupplierLevel parse(Object? raw) {
    for (final l in values) {
      if (l.api == raw) return l;
    }
    return SupplierLevel.registered;
  }
}

/// How a company is incorporated, shortened the way a profile line writes it.
String? legalStructureShort(String? raw) => switch (raw) {
  'PRIVATE_LIMITED' => 'Pvt Ltd',
  'PUBLIC_LIMITED' => 'Public Ltd',
  'LLP' => 'LLP',
  'PARTNERSHIP' => 'Partnership',
  'SOLE_PROPRIETORSHIP' => 'Proprietorship',
  'GOVERNMENT' => 'Govt / PSU',
  'TRUST_NGO' => 'Trust / NGO',
  _ => null,
};

/// One of the company's offices: the profile's "hubs" (`company.branches`).
class SupplierHub {
  const SupplierHub({
    required this.id,
    required this.name,
    this.city,
    this.state,
    this.address,
    this.phone,
    this.headOffice = false,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String? city;
  final String? state;
  final String? address;
  final String? phone;
  final bool headOffice;
  final double? latitude;
  final double? longitude;

  /// "Bengaluru, Karnataka".
  String get place => [?city, ?state].join(', ');

  factory SupplierHub.fromJson(Map<String, dynamic> j) => SupplierHub(
    id: '${j['id']}',
    name: asText(j['name']) ?? '',
    city: asText(j['city']),
    state: asText(j['state']),
    address: asText(j['addressLine']),
    phone: asText(j['phone']),
    headOffice: j['isHeadOffice'] == true,
    latitude: asDouble(j['latitude']),
    longitude: asDouble(j['longitude']),
  );
}

/// A member's rating of a supplier (`VendorRating`). The API publishes no
/// name: every rating comes from a signed-in member, one per member, so what
/// the app can say of the author is "Verified buyer . ICR member". The demo
/// content carries the design's own reviewer ([byline], [role]).
class SupplierReview {
  const SupplierReview({required this.id, required this.score, this.comment, this.createdAt, this.byline, this.role});

  final String id;
  final int score;
  final String? comment;
  final DateTime? createdAt;

  /// The design's reviewer organisation ("Embassy TechZone (Pune SEZ Campus)").
  /// Never sent by the API.
  final String? byline;

  /// The design's reviewer role and project ("Facilities Director . 14 Towers Project").
  final String? role;

  bool get written => (comment ?? '').trim().isNotEmpty;

  factory SupplierReview.fromJson(Map<String, dynamic> j) => SupplierReview(
    id: '${j['id']}',
    score: (asInt(j['score']) ?? 0).clamp(0, 5),
    comment: asText(j['comment']),
    createdAt: asDate(j['createdAt']),
  );
}

/// One of the four tiles under "Enterprise Track Record".
class TrackTile {
  const TrackTile({
    required this.value,
    required this.caption,
    this.tone = TrackTone.blue,
    this.glyph = TrackGlyph.check,
  });

  final String value;
  final String caption;
  final TrackTone tone;
  final TrackGlyph glyph;
}

enum TrackTone { blue, green, ink }

enum TrackGlyph { check, shield, building, hubs, handshake, calendar }

/// The grey band under the tiles ("PAN-INDIA FAST DISPATCH").
class DispatchBand {
  const DispatchBand({required this.kicker, required this.title, required this.line});

  final String kicker;
  final String title;
  final String line;
}

/// A supplier listing: the card on the Marketplace and the profile it opens.
/// The list rows (`GET /vendors`) carry the card's fields; the profile
/// (`GET /vendors/:id`) adds the offices, the legal structure and the ratings.
class Supplier {
  const Supplier({
    required this.id,
    required this.companyId,
    required this.name,
    this.logoUrl,
    this.lockupAsset,
    this.brandColor,
    this.headline,
    this.about,
    this.categories = const [],
    this.serviceAreas = const [],
    this.rating = 0,
    this.ratingCount = 0,
    this.level = SupplierLevel.registered,
    this.isPremium = false,
    this.city,
    this.state,
    this.website,
    this.size,
    this.foundedYear,
    this.yearsExperience,
    this.projectsCompleted,
    this.clientsServed,
    this.responseTime,
    this.msmeNumber,
    this.registrationNumber,
    this.legalStructure,
    this.gstRegistered = false,
    this.acceptingWork = true,
    this.certificationNames = const [],
    this.hubs = const [],
    this.reviews = const [],
    this.detailed = false,
    this.demoTiles,
    this.demoDispatch,
  });

  final String id;
  final String companyId;
  final String name;

  /// The company's logo as a full URL.
  final String? logoUrl;

  /// Demo content only: the design's logo and its name drawn as one picture
  /// (153 x 37 dp, bundled at 4x). Live cards draw [logoUrl] and the name.
  final String? lockupAsset;

  /// The name's colour on a live card; the API has none.
  final Color? brandColor;

  /// The supplier's one-line pitch: the card's title and the profile's tagline.
  final String? headline;

  /// The company's own description: the card's two lines (its first
  /// paragraph) and the profile's "About Organization".
  final String? about;

  /// Taxonomy keys.
  final List<String> categories;
  final List<String> serviceAreas;
  final double rating;
  final int ratingCount;
  final SupplierLevel level;
  final bool isPremium;
  final String? city;
  final String? state;
  final String? website;
  final String? size;
  final int? foundedYear;
  final int? yearsExperience;
  final int? projectsCompleted;
  final int? clientsServed;
  final String? responseTime;

  /// The Udyam (MSME) registration number the supplier declared.
  final String? msmeNumber;

  /// A company registration number such as a CIN, when the API carries one
  /// (`company.cin`; see docs/backend-requests/marketplace.md).
  final String? registrationNumber;
  final String? legalStructure;
  final bool gstRegistered;
  final bool acceptingWork;

  /// Verified certification names (`verifiedCertifications`).
  final List<String> certificationNames;
  final List<SupplierHub> hubs;

  /// The latest twenty ratings (profile only).
  final List<SupplierReview> reviews;

  /// Read from `GET /vendors/:id` (offices, ratings), not just a list row.
  final bool detailed;

  /// Demo content only: the design's four tiles and dispatch band.
  final List<TrackTile>? demoTiles;
  final DispatchBand? demoDispatch;

  /// The head office, else the first office.
  SupplierHub? get headOffice {
    for (final h in hubs) {
      if (h.headOffice) return h;
    }
    return hubs.isEmpty ? null : hubs.first;
  }

  /// The number "Call HQ" and "WhatsApp" use: the head office's line.
  String? get phone {
    final head = headOffice?.phone;
    if (head != null) return head;
    for (final h in hubs) {
      if (h.phone != null) return h.phone;
    }
    return null;
  }

  /// The card's two lines: the description's opening paragraph.
  String? get blurb {
    final text = about?.trim();
    if (text == null || text.isEmpty) return null;
    return text.split(RegExp(r'\n\s*\n')).first.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// "Pvt Ltd . Reg. CIN-U74999KA2019PTC1": how it is incorporated and the
  /// registration number it declared (the API keeps the GSTIN and PAN private).
  String? get registrationLine {
    final reg = registrationNumber ?? msmeNumber;
    final parts = <String>[
      ?legalStructureShort(legalStructure),
      if (legalStructure == null && gstRegistered) 'GST registered',
      if (reg != null) 'Reg. $reg',
    ];
    return parts.isEmpty ? null : parts.join(' • ');
  }

  /// The rating as the cards print it: one decimal ("4.8").
  String get ratingLabel => rating.toStringAsFixed(1);

  /// The first letter of the name, for a logo tile when there is no logo.
  String get initial => name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();

  /// "84 Enterprise Reviews".
  String get reviewsLabel => ratingCount == 1 ? '1 Enterprise Review' : '$ratingCount Enterprise Reviews';

  /// The tiles under "Enterprise Track Record": the design's own in demo mode,
  /// else what the listing can back (a tile with no number is left out).
  List<TrackTile> get trackRecord {
    final demo = demoTiles;
    if (demo != null) return demo;
    final cities = hubCities;
    return [
      if ((projectsCompleted ?? 0) > 0)
        TrackTile(value: _plus(projectsCompleted!), caption: 'Projects Executed', tone: TrackTone.blue),
      if ((clientsServed ?? 0) > 0)
        TrackTile(
          value: _plus(clientsServed!),
          caption: 'Clients Served',
          tone: TrackTone.green,
          glyph: TrackGlyph.handshake,
        ),
      if ((yearsExperience ?? 0) > 0)
        TrackTile(
          value: _plus(yearsExperience!),
          caption: yearsExperience == 1 ? 'Year of Experience' : 'Years of Experience',
          tone: TrackTone.ink,
          glyph: TrackGlyph.calendar,
        ),
      if (hubs.isNotEmpty)
        TrackTile(
          value: hubs.length == 1 ? '1 Hub' : '${hubs.length} Hubs',
          caption: cities.isEmpty ? headOffice?.name ?? '' : _list(cities),
          glyph: TrackGlyph.hubs,
        ),
    ].take(4).toList();
  }

  /// The cities its offices are in, head office first, each once.
  List<String> get hubCities {
    final ordered = [...hubs.where((h) => h.headOffice), ...hubs.where((h) => !h.headOffice)];
    final seen = <String>{};
    return [
      for (final h in ordered)
        if (h.city != null && seen.add(h.city!)) h.city!,
    ];
  }

  /// The grey band under the tiles: the design's own in demo mode, else one
  /// read from the offices (none for a supplier with a single office).
  DispatchBand? get dispatch {
    final demo = demoDispatch;
    if (demo != null) return demo;
    if (hubs.length < 2) return null;
    final cities = hubCities;
    final wide = cities.length >= 3;
    final sla = responseTime == null ? '' : ' • replies ${responseTimeLabel(responseTime)}';
    return DispatchBand(
      kicker: wide ? 'PAN-INDIA PRESENCE' : 'OPERATING HUBS',
      title: '${hubs.length} Operational Hubs',
      line: cities.isEmpty ? '${hubs.length} offices$sla' : '${cities.join(' • ')}$sla',
    );
  }

  /// The full listing [full] with what only the tapped card knows (its brand
  /// colour, the design's lockup picture) kept.
  factory Supplier.merged(Supplier full, {required Supplier card}) =>
      full.copyWith(brandColor: full.brandColor ?? card.brandColor, lockupAsset: full.lockupAsset ?? card.lockupAsset);

  Supplier copyWith({
    double? rating,
    int? ratingCount,
    List<SupplierReview>? reviews,
    Color? brandColor,
    String? lockupAsset,
  }) => Supplier(
    id: id,
    companyId: companyId,
    name: name,
    logoUrl: logoUrl,
    lockupAsset: lockupAsset ?? this.lockupAsset,
    brandColor: brandColor ?? this.brandColor,
    headline: headline,
    about: about,
    categories: categories,
    serviceAreas: serviceAreas,
    rating: rating ?? this.rating,
    ratingCount: ratingCount ?? this.ratingCount,
    level: level,
    isPremium: isPremium,
    city: city,
    state: state,
    website: website,
    size: size,
    foundedYear: foundedYear,
    yearsExperience: yearsExperience,
    projectsCompleted: projectsCompleted,
    clientsServed: clientsServed,
    responseTime: responseTime,
    msmeNumber: msmeNumber,
    registrationNumber: registrationNumber,
    legalStructure: legalStructure,
    gstRegistered: gstRegistered,
    acceptingWork: acceptingWork,
    certificationNames: certificationNames,
    hubs: hubs,
    reviews: reviews ?? this.reviews,
    detailed: detailed,
    demoTiles: demoTiles,
    demoDispatch: demoDispatch,
  );

  /// A `GET /vendors` row or the `GET /vendors/:id` body. [absolute] turns a
  /// stored `/uploads/...` path into a URL.
  factory Supplier.fromJson(Map<String, dynamic> j, {required String? Function(String?) absolute}) {
    final company = asMap(j['company']);
    return Supplier(
      id: '${j['id']}',
      companyId: '${j['companyId'] ?? company['id'] ?? ''}',
      name: asText(company['name']) ?? 'Supplier',
      logoUrl: absolute(asText(company['logoUrl'])),
      headline: asText(j['headline']),
      about: asText(company['description']),
      categories: asStrings(j['categories']),
      serviceAreas: asStrings(j['serviceAreas']),
      rating: asDouble(j['rating']) ?? 0,
      ratingCount: asInt(j['ratingCount']) ?? 0,
      level: SupplierLevel.parse(j['verificationLevel']),
      isPremium: j['isPremium'] == true,
      city: asText(company['city']),
      state: asText(company['state']),
      website: asText(company['website']),
      size: asText(company['size']),
      foundedYear: asInt(company['foundedYear']),
      yearsExperience: asInt(j['yearsExperience']),
      projectsCompleted: asInt(j['projectsCompleted']),
      clientsServed: asInt(j['clientsServed']),
      responseTime: asText(j['responseTime']),
      msmeNumber: asText(j['msmeNumber']),
      registrationNumber: asText(company['cin']),
      legalStructure: asText(company['legalStructure']),
      gstRegistered: company['gstRegistered'] == true,
      acceptingWork: j['acceptingWork'] != false,
      certificationNames: asStrings(j['verifiedCertifications']),
      hubs: [for (final b in asMaps(company['branches'])) SupplierHub.fromJson(b)],
      reviews: [for (final r in asMaps(j['ratings'])) SupplierReview.fromJson(r)],
      detailed: company.containsKey('branches') || j.containsKey('ratings'),
    );
  }
}

String _plus(int n) => n >= 10 ? '$n+' : '$n';

String _list(List<String> items) {
  if (items.length <= 1) return items.join();
  return '${items.take(items.length - 1).join(', ')} & ${items.last}';
}

/// "within 2 days", from the API's response-time buckets (`RESPONSE_TIMES` in
/// `@icr/shared`: WITHIN_1H, WITHIN_4H, WITHIN_24H, WITHIN_48H, WITHIN_WEEK).
String responseTimeLabel(String? bucket) => switch (bucket) {
  'WITHIN_1H' => 'within an hour',
  'WITHIN_4H' => 'within 4 hours',
  'WITHIN_24H' => 'within a day',
  'WITHIN_48H' => 'within 2 days',
  'WITHIN_WEEK' => 'within a week',
  _ => bucket == null ? '' : bucket.toLowerCase().replaceAll('_', ' '),
};

/// How a compliance row reads its status.
enum ComplianceTone { positive, neutral }

/// What a compliance row's glyph shows.
enum ComplianceGlyph { licence, quality, safety, insurance, green, membership, generic }

/// A certification the company holds that ICR shows the public
/// (`GET /certifications/verified`), joined to its type's category.
class Compliance {
  const Compliance({
    required this.id,
    required this.title,
    this.category = 'OTHER',
    this.number,
    this.issuer,
    this.note,
    this.issuedOn,
    this.expiresAt,
    this.url,
    this.statusOverride,
  });

  final String id;
  final String title;

  /// The certification type's category (GOVERNMENT, ISO, SAFETY...).
  final String category;
  final String? number;
  final String? issuer;
  final String? note;
  final DateTime? issuedOn;
  final DateTime? expiresAt;
  final String? url;

  /// Demo content only.
  final String? statusOverride;

  bool get _insurance => RegExp(r'insur|assurance|indemnity|policy', caseSensitive: false).hasMatch(title);
  bool get _licence => RegExp(r'licen[cs]e|permit|registration', caseSensitive: false).hasMatch(title);

  /// "Active" for a licence or registration, "Certified" for a standard,
  /// "Insured" for a policy, "Member" for a membership.
  String get status {
    if (statusOverride != null) return statusOverride!;
    if (_insurance) return 'Insured';
    return switch (category) {
      'GOVERNMENT' || 'BUSINESS' => 'Active',
      'MEMBERSHIP' => 'Member',
      'SAFETY' when _licence => 'Active',
      'OTHER' => _licence ? 'Active' : 'On file',
      _ => 'Certified',
    };
  }

  ComplianceTone get tone => switch (status) {
    'Active' || 'Certified' => ComplianceTone.positive,
    _ => ComplianceTone.neutral,
  };

  ComplianceGlyph get glyph {
    if (_insurance) return ComplianceGlyph.insurance;
    if (RegExp('safety', caseSensitive: false).hasMatch(title) || category == 'SAFETY') {
      return _licence ? ComplianceGlyph.licence : ComplianceGlyph.safety;
    }
    return switch (category) {
      'GOVERNMENT' || 'BUSINESS' => ComplianceGlyph.licence,
      'ISO' || 'QUALITY' || 'INDUSTRY' || 'SECURITY' => ComplianceGlyph.quality,
      'GREEN' || 'ENVIRONMENTAL' => ComplianceGlyph.green,
      'MEMBERSHIP' => ComplianceGlyph.membership,
      _ => _licence ? ComplianceGlyph.licence : ComplianceGlyph.generic,
    };
  }

  /// The line under the title: the registration number, else the company's
  /// own note on the record, else who audited it.
  String? get detail {
    if (number != null) return 'Reg: #$number';
    if (note != null) return note;
    if (issuer != null) {
      final audited = const {'ISO', 'QUALITY', 'SAFETY', 'ENVIRONMENTAL', 'GREEN', 'SECURITY'}.contains(category);
      return '${audited ? 'Audited' : 'Issued'} by $issuer';
    }
    return null;
  }

  /// The licence number is drawn in a typewriter face in the design; the other
  /// lines are small print.
  bool get detailIsNumber => number != null;

  factory Compliance.fromJson(Map<String, dynamic> j, {Map<String, String> categories = const {}}) {
    final type = asMap(j['certificationType']);
    final typeId = '${type['id'] ?? j['certificationTypeId'] ?? ''}';
    return Compliance(
      id: '${j['id']}',
      title: asText(type['name']) ?? 'Certification',
      category: asText(type['category']) ?? categories[typeId] ?? 'OTHER',
      number: asText(j['certificateNumber']),
      issuer: asText(j['issuer']),
      note: asText(j['note']),
      issuedOn: asDate(j['issuedOn']),
      expiresAt: asDate(j['expiresAt']),
      url: asText(j['certificateUrl']),
    );
  }
}

/// "Showing 6 of 180+": a count a long list rounds down to tens.
String roughTotal(int total) => total >= 100 ? '${total ~/ 10 * 10}+' : '$total';

/// The numbers on the quick chips: "My RFQ's 3" and "Alerts 2 new".
class MarketplaceCounts {
  const MarketplaceCounts({this.myRfqs = 0, this.newAlerts = 0});

  final int myRfqs;
  final int newAlerts;
}
