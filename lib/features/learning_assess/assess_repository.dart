import 'assess_models.dart';

/// Where the Assess Your Knowledge and Mock Exams screens get their programmes,
/// subjects and papers: the API, or a little sample content.
abstract class AssessRepository {
  /// Every group of [kind] that has something to sit: programmes with assessment
  /// levels, or mock exam subjects with sets (those with no paper are left out:
  /// a card that leads to an empty page is worse than not offering it).
  Future<List<PaperGroup>> groups(PaperKind kind);

  /// One group in full and fresh: a programme by its code, a subject by its slug.
  /// Throws [ApiError] with a 404 when nothing is published there.
  Future<PaperGroup> group(PaperKind kind, String key);

  /// What the member holds and how they did on each paper of [kind]. Never throws:
  /// a read that fails leaves its part empty (see [MemberLearning.none]).
  Future<MemberLearning> member(PaperKind kind);

  /// What a paper would cost this member, in money and in ICR credits. Takes nothing.
  Future<PaperQuote> quote(AssessPaper paper);

  /// The "all levels" offer of a programme (by its code) or the "all sets" offer of a mock exam (by its slug) for
  /// this member, in money and in ICR credits. Takes nothing.
  Future<BundleQuote> bundleQuote(String key, {PaperKind kind = PaperKind.assessment});

  /// Opens every closed level or set of a programme or mock exam for good, together, with ICR credits
  /// (`POST /learning/assessment-bundles/:code/redeem`, `/learning/mock-bundles/:slug/redeem`). The credits must cover
  /// the whole bundle: otherwise the API's own sentence.
  Future<RedeemBundleResult> redeemBundle(PaperKind kind, String key);

  /// The global discount the level cards show.
  Future<AssessmentPricing> pricing();

  /// Opens one level or set for good with ICR credits (`POST /learning/papers/:slug/redeem`).
  Future<RedeemResult> redeem(AssessPaper paper);

  /// Opens a whole programme or mock exam with one of the plan's places
  /// (`POST /learning/me/opens`); idempotent for one already open.
  Future<void> openWithPlan(PaperKind kind, String targetId);

  Future<int> unreadNotifications();

  /// The website's page for a paper, where a payment is made (the app has no gateway leg).
  Uri paperLink(PaperGroup group, AssessPaper paper);

  /// The website's page for a programme or subject: its level or set choice, and the bundle's checkout.
  Uri groupLink(PaperGroup group);

  /// The plans that open more.
  Uri plansLink();

  /// The partner institutes' certifications, catalogued under Professional Development.
  Uri partnerLink();
}
