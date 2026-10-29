import 'membership_models.dart';
import 'membership_repository.dart';

/// Sample plans for review without a database: a free rung, two paid ones and
/// an Enterprise sold by conversation on every ladder, with the Professional
/// plan held on the Professional ladder. Choosing a plan activates it on the
/// spot, as the API does with no gateway.
class DemoMembershipRepository implements MembershipRepository {
  DemoMembershipRepository({DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final DateTime Function() _now;
  final _held = <MembershipAudience, MySubscription>{};
  final checkouts = <String>[];

  static const _year = 12;

  List<MembershipPlan> _ladder(MembershipAudience a) {
    final k = a.slug;
    return [
      MembershipPlan(
        id: '$k-free',
        name: 'Free',
        tier: 'FREE',
        audience: a,
        description: 'Get started on ICR.',
        prices: [PlanPrice(id: '$k-free-12', months: _year, pricePaisa: 0)],
        benefits: [
          PlanBenefit(key: 'profile', text: 'A public profile and the community', headline: true),
          PlanBenefit(key: 'alerts', text: 'Weekly job and requirement alerts'),
        ],
      ),
      MembershipPlan(
        id: '$k-silver',
        name: 'Silver',
        tier: 'SILVER',
        audience: a,
        description: 'For professionals who are active every week.',
        prices: [PlanPrice(id: '$k-silver-12', months: _year, pricePaisa: 499900)],
        benefits: [
          PlanBenefit(key: 'content', text: 'Expanded learning content: mock exams and flash cards', headline: true),
          PlanBenefit(key: 'apply', text: '30 job applications a month', headline: true),
          PlanBenefit(key: 'mentoring', text: '2 mentoring requests open at once'),
          PlanBenefit(key: 'events', text: '10% off event tickets'),
        ],
      ),
      MembershipPlan(
        id: '$k-gold',
        name: 'Gold',
        tier: 'GOLD',
        audience: a,
        description: 'Everything open, with a seat at every table.',
        prices: [PlanPrice(id: '$k-gold-12', months: _year, pricePaisa: 1299900, compareAtPaisa: 1499900)],
        benefits: [
          PlanBenefit(key: 'content', text: 'Full learning content, every paper and deck', headline: true),
          PlanBenefit(key: 'apply', text: 'Unlimited job applications', headline: true),
          PlanBenefit(key: 'mentoring', text: '3 mentor session credits a year'),
          PlanBenefit(key: 'events', text: '25% off event tickets'),
          PlanBenefit(key: 'manager', text: 'A named ICR account manager', term: true),
        ],
      ),
      MembershipPlan(
        id: '$k-enterprise',
        name: 'Enterprise',
        tier: 'ENTERPRISE',
        audience: a,
        description: 'Priced for your organisation.',
        contactSales: true,
        prices: [PlanPrice(id: '$k-ent-12', months: _year, pricePaisa: 10000000)],
        benefits: [
          PlanBenefit(key: 'seats', text: 'Seats for the whole team', headline: true),
          PlanBenefit(key: 'reports', text: 'Quarterly insight reports'),
          PlanBenefit(key: 'manager', text: 'A named ICR account manager', term: true),
        ],
      ),
    ];
  }

  /// Every ladder the website sells on. Learning is not sold any more, so it has no chip.
  @override
  Future<List<MembershipAudience>> audiences() async => [
    for (final a in MembershipAudience.values)
      if (a != MembershipAudience.learning) a,
  ];

  @override
  Future<List<MembershipPlan>> plans(MembershipAudience audience) async => _ladder(audience);

  @override
  Future<MyPlan> mine(MembershipAudience audience) async {
    final held = _held[audience];
    if (held == null && audience == MembershipAudience.seeker) {
      _held[audience] = MySubscription(
        id: 'sub-seeker',
        planId: 'professional-silver',
        planName: 'Silver',
        tier: 'SILVER',
        status: 'ACTIVE',
        currentPeriodEnd: _now().add(const Duration(days: 212)),
        pricePaisa: 499900,
        provider: 'payu',
      );
    }
    final sub = _held[audience];
    final company = audience == MembershipAudience.supplier || audience == MembershipAudience.company;
    return MyPlan(
      audience: audience,
      tier: sub?.tier ?? 'FREE',
      subscription: sub,
      renewal: sub == null
          ? null
          : RenewalQuote(priceId: '${audience.slug}-${sub.tier.toLowerCase()}-12', totalPaisa: 589882),
      canBuy: !company || audience == MembershipAudience.company,
      reason: company && audience != MembershipAudience.company
          ? 'These plans are bought by a company. Create your company page first, or switch to it.'
          : null,
    );
  }

  @override
  Future<MembershipHistory> history(MembershipAudience audience) async {
    final sub = (await mine(audience)).subscription;
    return MembershipHistory(
      audience: audience,
      terms: [
        if (sub != null)
          MembershipTerm(
            id: sub.id,
            planName: sub.planName,
            tier: sub.tier,
            status: sub.status,
            startsAt: sub.currentPeriodEnd?.subtract(const Duration(days: 365)),
            endsAt: sub.currentPeriodEnd,
            totalPaisa: 589882,
            paidAt: sub.currentPeriodEnd?.subtract(const Duration(days: 365)),
          ),
        if (audience == MembershipAudience.seeker)
          MembershipTerm(
            id: 'sub-old',
            planName: 'Free',
            tier: 'FREE',
            status: 'EXPIRED',
            startsAt: _now().subtract(const Duration(days: 520)),
            endsAt: _now().subtract(const Duration(days: 153)),
            end: 'CHANGED_PLAN',
          ),
      ],
    );
  }

  @override
  Future<CheckoutOutcome> checkout(String priceId) async {
    checkouts.add(priceId);
    for (final a in MembershipAudience.values) {
      for (final p in _ladder(a)) {
        for (final price in p.prices) {
          if (price.id == priceId) {
            _held[a] = MySubscription(
              id: 'sub-${p.id}',
              planId: p.id,
              planName: p.name,
              tier: p.tier,
              status: 'ACTIVE',
              currentPeriodEnd: _now().add(Duration(days: 30 * price.months)),
              pricePaisa: price.pricePaisa,
              provider: 'simulated',
            );
            return CheckoutOutcome(subscriptionId: 'sub-${p.id}', devActivated: true);
          }
        }
      }
    }
    return CheckoutOutcome(subscriptionId: 'sub-unknown', devActivated: true);
  }
}
