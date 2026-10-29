import 'membership_models.dart';

/// Where the Membership screen gets the plans and what the member holds: the
/// API, or a little sample content.
abstract class MembershipRepository {
  /// The ladders worth a chip, as the website's `/membership` page decides them:
  /// one the member holds a plan on, or may buy on and that has a plan on sale.
  /// So a ladder with nothing on sale (Learning is not sold any more) or that
  /// the member cannot buy on (Partner Institution, for a professional) has no
  /// chip. In the website's order. Throws [ApiError] when the member's own
  /// ladders cannot be read, and the screen keeps to the ladder it opened on.
  Future<List<MembershipAudience>> audiences();

  /// Every plan on sale this instant on [audience], the ladder's order (`GET /subscriptions/catalogue`).
  Future<List<MembershipPlan>> plans(MembershipAudience audience);

  /// What the member holds on [audience] and whether they may buy there
  /// (`GET /subscriptions/me?audience=` with `GET /subscriptions/me/all`'s `canBuy`).
  Future<MyPlan> mine(MembershipAudience audience);

  /// The member's terms on [audience], newest first (`GET /subscriptions/me/history`).
  Future<MembershipHistory> history(MembershipAudience audience);

  /// Starts a term on a price (`POST /subscriptions/checkout { priceId }`). Throws
  /// [ApiError] with the API's own sentence when it refuses (a term already paid
  /// for, a plan that must wait for the renewal, no gateway).
  Future<CheckoutOutcome> checkout(String priceId);
}
