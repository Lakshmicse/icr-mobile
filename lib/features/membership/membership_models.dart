/// What the Membership screen draws: the website's plans (`GET /subscriptions/catalogue`),
/// what the member holds on each audience (`GET /subscriptions/me`, `/me/all`), a
/// checkout's answer and the membership history. Shapes follow `packages/shared/src/dto.ts`
/// (`MembershipPlanDto`, `MySubscriptionDto`, `MyMembershipDto`, `MembershipCheckoutDto`,
/// `MembershipHistoryDto`).
library;

/// One ladder of plans per stakeholder, as `MEMBERSHIP_AUDIENCE_META` names them
/// (`packages/shared/src/enums.ts`): the API's key, the label people see, the
/// website's `/pricing/<slug>`, the tagline and the one line under the name.
enum MembershipAudience {
  seeker(
    'SEEKER',
    'Professional',
    'professional',
    'Learn. Connect. Grow.',
    'For CRE, FM, workplace, projects, engineering, procurement and sustainability professionals.',
  ),
  mentor(
    'MENTOR',
    'Mentor',
    'mentor',
    'Guide. Influence. Lead.',
    'For senior professionals, leaders and subject-matter experts who mentor on ICR.',
  ),
  supplier(
    'SUPPLIER',
    'Market Place',
    'supplier',
    'Showcase. Connect. Grow.',
    'For manufacturers, service providers, consultants and technology companies on Supplier Mart.',
  ),
  company(
    'COMPANY',
    'Job Portal',
    'corporate',
    'Discover. Hire. Build talent.',
    'For employers hiring CRE and FM professionals.',
  ),
  learning(
    'LEARNING',
    'Learning',
    'learning',
    'Assess. Learn. Certify.',
    'Structured learning and certification preparation, on top of any other plan.',
  ),
  institution(
    'INSTITUTION',
    'Partner Institution',
    'institution',
    'Teach. Enrol. Certify.',
    'For universities, academies and training providers publishing courses on ICR.',
  );

  const MembershipAudience(this.api, this.label, this.slug, this.tagline, this.description);

  final String api;
  final String label;
  final String slug;
  final String tagline;
  final String description;

  static MembershipAudience? fromApi(String? value) {
    for (final a in values) {
      if (a.api == value) return a;
    }
    return null;
  }

  static MembershipAudience? fromSlug(String? slug) {
    for (final a in values) {
      if (a.slug == slug) return a;
    }
    return null;
  }

  /// The audience a page of the website names: `/pricing/<slug>`, `/career/plans`
  /// (the Professional ladder), `/membership…?audience=<API key>`. Null for a
  /// page that names none (`/pricing`, `/membership`).
  static MembershipAudience? fromSitePath(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length == 2 && segments[0] == 'pricing') return fromSlug(segments[1]);
    if (segments.length == 2 && segments[0] == 'career' && segments[1] == 'plans') return seeker;
    return fromApi(uri.queryParameters['audience']) ?? fromSlug(uri.queryParameters['audience']);
  }
}

/// A term a plan is sold for: the whole term's price before GST, in paisa.
class PlanPrice {
  const PlanPrice({
    required this.id,
    required this.months,
    required this.pricePaisa,
    this.compareAtPaisa,
    this.active = true,
    this.validUntil,
  });

  final String id;
  final int months;
  final int pricePaisa;
  final int? compareAtPaisa;
  final bool active;
  final DateTime? validUntil;

  /// "/year", "/month", "/6 months".
  String get suffix => months == 12
      ? '/year'
      : months == 1
      ? '/month'
      : '/$months months';

  static PlanPrice fromJson(Map<String, dynamic> j) => PlanPrice(
    id: j['id'] as String,
    months: (j['billingPeriodMonths'] as num?)?.toInt() ?? 12,
    pricePaisa: (j['pricePaisa'] as num?)?.toInt() ?? 0,
    compareAtPaisa: (j['compareAtPaisa'] as num?)?.toInt(),
    active: j['active'] as bool? ?? true,
    validUntil: _date(j['validUntil']),
  );
}

/// One line of what a plan includes, worded by the API from the plan's own
/// values (`PlanBenefitValueDto`): the card never promises what the plan does
/// not give. A `term` is a promise people keep (an account manager), listed apart.
class PlanBenefit {
  const PlanBenefit({
    required this.key,
    required this.text,
    this.shown = true,
    this.headline = false,
    this.term = false,
  });

  final String key;
  final String text;
  final bool shown;
  final bool headline;
  final bool term;

  static PlanBenefit fromJson(Map<String, dynamic> j) => PlanBenefit(
    key: j['key'] as String? ?? '',
    text: j['text'] as String? ?? '',
    shown: j['shown'] as bool? ?? true,
    headline: j['headline'] as bool? ?? false,
    term: j['style'] == 'term',
  );
}

class MembershipPlan {
  const MembershipPlan({
    required this.id,
    required this.name,
    required this.tier,
    required this.audience,
    this.description,
    this.contactSales = false,
    this.prices = const [],
    this.benefits = const [],
    this.availableUntil,
  });

  final String id;
  final String name;

  /// `FREE`, `SILVER`, `GOLD`, `ENTERPRISE`: the ladder's own rung, never shown.
  final String tier;
  final MembershipAudience? audience;
  final String? description;

  /// Sold by conversation: "Talk to us" instead of a checkout.
  final bool contactSales;
  final List<PlanPrice> prices;
  final List<PlanBenefit> benefits;
  final DateTime? availableUntil;

  bool get isFree => tier == 'FREE';

  /// The term a card leads with: the annual price where there is one (the price
  /// list is annual), else the shortest term on sale. Null for a plan priced
  /// only through a custom offer.
  PlanPrice? get headlineTerm {
    final live = prices.where((p) => p.active).toList();
    for (final p in live) {
      if (p.months == 12) return p;
    }
    if (live.isEmpty) return null;
    live.sort((a, b) => a.months.compareTo(b.months));
    return live.first;
  }

  List<PlanBenefit> get features => [
    for (final b in benefits)
      if (b.shown && !b.term) b,
  ];

  List<PlanBenefit> get terms => [
    for (final b in benefits)
      if (b.shown && b.term) b,
  ];

  static MembershipPlan fromJson(Map<String, dynamic> j) => MembershipPlan(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    tier: j['tier'] as String? ?? 'FREE',
    audience: MembershipAudience.fromApi(j['audience'] as String?),
    description: j['description'] as String?,
    contactSales: j['contactSales'] as bool? ?? false,
    prices: [
      for (final p in (j['prices'] as List? ?? const []))
        if (p is Map) PlanPrice.fromJson(p.cast<String, dynamic>()),
    ],
    benefits: [
      for (final b in (j['benefits'] as List? ?? const []))
        if (b is Map) PlanBenefit.fromJson(b.cast<String, dynamic>()),
    ],
    availableUntil: _date(j['availableUntil']),
  );
}

/// The plan the member holds on an audience now.
class MySubscription {
  const MySubscription({
    required this.id,
    required this.planId,
    required this.planName,
    required this.tier,
    required this.status,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
    this.autoRenew = false,
    this.pricePaisa = 0,
    this.provider,
  });

  final String id;
  final String planId;
  final String planName;
  final String tier;
  final String status;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final bool autoRenew;
  final int pricePaisa;

  /// `comp` for a complimentary plan, else the gateway.
  final String? provider;

  static MySubscription fromJson(Map<String, dynamic> j) {
    final plan = (j['plan'] as Map?)?.cast<String, dynamic>() ?? const {};
    return MySubscription(
      id: j['id'] as String? ?? '',
      planId: j['planId'] as String? ?? plan['id'] as String? ?? '',
      planName: plan['name'] as String? ?? 'Your plan',
      tier: plan['tier'] as String? ?? 'FREE',
      status: j['status'] as String? ?? 'ACTIVE',
      currentPeriodEnd: _date(j['currentPeriodEnd']),
      cancelAtPeriodEnd: j['cancelAtPeriodEnd'] as bool? ?? false,
      autoRenew: j['autoRenew'] as bool? ?? false,
      pricePaisa: (j['pricePaisa'] as num?)?.toInt() ?? 0,
      provider: j['provider'] as String?,
    );
  }
}

/// What renewing the running term costs today: the plan's current price, which
/// a renewal is charged whatever the term was bought at.
class RenewalQuote {
  const RenewalQuote({required this.priceId, required this.totalPaisa, this.priceChanged = false});

  final String priceId;
  final int totalPaisa;
  final bool priceChanged;

  static RenewalQuote? fromJson(Object? v) {
    if (v is! Map) return null;
    final j = v.cast<String, dynamic>();
    final priceId = j['priceId'] as String?;
    if (priceId == null) return null;
    return RenewalQuote(
      priceId: priceId,
      totalPaisa: (j['totalPaisa'] as num?)?.toInt() ?? 0,
      priceChanged: j['priceChanged'] as bool? ?? false,
    );
  }
}

/// The member's standing on one audience: the plan held (none means the free
/// one), what renewing costs, and whether they may buy here at all.
class MyPlan {
  const MyPlan({
    required this.audience,
    this.tier = 'FREE',
    this.subscription,
    this.renewal,
    this.planRetired = false,
    this.nextTermPlanName,
    this.scheduledChangePlanName,
    this.scheduledChangeAt,
    this.canBuy = true,
    this.reason,
  });

  final MembershipAudience audience;
  final String tier;
  final MySubscription? subscription;
  final RenewalQuote? renewal;
  final bool planRetired;

  /// A term already paid for that starts when this one ends.
  final String? nextTermPlanName;

  /// A change to another plan waiting for the term's end.
  final String? scheduledChangePlanName;
  final DateTime? scheduledChangeAt;

  /// False when the member cannot buy this audience's plans; [reason] says why.
  final bool canBuy;
  final String? reason;

  bool get held => subscription != null;

  static MyPlan fromJson(Map<String, dynamic> j, {required MembershipAudience fallback}) {
    final sub = j['subscription'];
    final next = (j['nextTerm'] as Map?)?.cast<String, dynamic>();
    final change = (j['scheduledChange'] as Map?)?.cast<String, dynamic>();
    return MyPlan(
      audience: MembershipAudience.fromApi(j['audience'] as String?) ?? fallback,
      tier: j['tier'] as String? ?? 'FREE',
      subscription: sub is Map ? MySubscription.fromJson(sub.cast<String, dynamic>()) : null,
      renewal: RenewalQuote.fromJson(j['renewal']),
      planRetired: j['planRetired'] as bool? ?? false,
      nextTermPlanName: next?['planName'] as String?,
      scheduledChangePlanName: change?['planName'] as String?,
      scheduledChangeAt: _date(change?['at']),
      canBuy: j['canBuy'] as bool? ?? true,
      reason: j['reason'] as String?,
    );
  }
}

/// What `POST /subscriptions/checkout` answers: the term is live already (test
/// mode, or ₹0), or the gateway's form (an `action` URL and its fields) the
/// member's browser must post to pay.
class CheckoutOutcome {
  const CheckoutOutcome({required this.subscriptionId, this.devActivated = false, this.gatewayAction, this.fields});

  final String subscriptionId;
  final bool devActivated;
  final String? gatewayAction;
  final Map<String, String>? fields;

  bool get needsGateway => !devActivated && gatewayAction != null;

  static CheckoutOutcome fromJson(Map<String, dynamic> j) => CheckoutOutcome(
    subscriptionId: j['subscriptionId'] as String? ?? '',
    devActivated: j['devActivated'] as bool? ?? false,
    gatewayAction: j['action'] as String?,
    fields: (j['fields'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())),
  );
}

/// One term of the member's history on an audience, newest first.
class MembershipTerm {
  const MembershipTerm({
    required this.id,
    required this.planName,
    required this.tier,
    required this.status,
    this.startsAt,
    this.endsAt,
    this.totalPaisa = 0,
    this.paidAt,
    this.end,
    this.complimentary = false,
  });

  final String id;
  final String planName;
  final String tier;
  final String status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int totalPaisa;
  final DateTime? paidAt;

  /// Why it stopped: RENEWED, CHANGED_PLAN, CANCELLED, ENDED; null while it runs.
  final String? end;
  final bool complimentary;

  bool get running => end == null;

  static MembershipTerm fromJson(Map<String, dynamic> j) {
    final sub = (j['subscription'] as Map?)?.cast<String, dynamic>() ?? const {};
    final plan = (sub['plan'] as Map?)?.cast<String, dynamic>() ?? const {};
    final settings = (j['settings'] as Map?)?.cast<String, dynamic>() ?? const {};
    return MembershipTerm(
      id: sub['id'] as String? ?? '',
      planName: plan['name'] as String? ?? 'Plan',
      tier: plan['tier'] as String? ?? 'FREE',
      status: sub['status'] as String? ?? '',
      startsAt: _date(sub['currentPeriodStart'] ?? sub['startsAt']),
      endsAt: _date(sub['currentPeriodEnd']),
      totalPaisa: (sub['totalPaisa'] as num?)?.toInt() ?? 0,
      paidAt: _date(sub['paidAt']),
      end: j['end'] as String?,
      complimentary: settings['complimentary'] as bool? ?? false,
    );
  }
}

class MembershipHistory {
  const MembershipHistory({required this.audience, this.reason, this.terms = const []});

  final MembershipAudience audience;

  /// Why this member cannot hold a plan on the audience, when they cannot.
  final String? reason;
  final List<MembershipTerm> terms;

  static MembershipHistory fromJson(Map<String, dynamic> j, {required MembershipAudience fallback}) =>
      MembershipHistory(
        audience: MembershipAudience.fromApi(j['audience'] as String?) ?? fallback,
        reason: j['reason'] as String?,
        terms: [
          for (final t in (j['terms'] as List? ?? const []))
            if (t is Map) MembershipTerm.fromJson(t.cast<String, dynamic>()),
        ],
      );
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
