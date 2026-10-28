import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'membership_models.dart';
import 'membership_repository.dart';

/// The Membership screen's state: the ladder being looked at, its plans, what
/// the member holds there, and a checkout in flight.
class MembershipController extends ChangeNotifier {
  MembershipController(this.repository, {MembershipAudience audience = MembershipAudience.seeker})
    : _audience = audience;

  final MembershipRepository repository;

  MembershipAudience _audience;
  List<MembershipPlan> _plans = const [];
  MyPlan? _mine;
  bool _started = false;
  bool _loading = false;
  String? _error;
  String? _busyPriceId;
  String? _message;
  CheckoutOutcome? _gateway;
  bool _disposed = false;
  int _generation = 0;

  MembershipAudience get audience => _audience;
  List<MembershipPlan> get plans => _plans;

  /// Null until read, or when the read failed (the cards still show).
  MyPlan? get mine => _mine;
  bool get started => _started;
  bool get loading => _loading;

  /// Why the plans could not be read; null when they could.
  String? get error => _error;

  /// The price being bought, while the API answers.
  String? get busyPriceId => _busyPriceId;

  /// A line for the person: the plan is live, or the API's refusal in its own words.
  String? get message => _message;

  /// A checkout the gateway must finish: the screen hands the person to the website.
  CheckoutOutcome? get gateway => _gateway;

  bool isCurrent(MembershipPlan plan) {
    final sub = _mine?.subscription;
    if (sub == null) return plan.isFree;
    return sub.planId == plan.id || (sub.planId.isEmpty && sub.tier == plan.tier);
  }

  Future<void> start() {
    _started = true;
    return _load(notify: false);
  }

  Future<void> refresh() => _load(notify: true);

  void setAudience(MembershipAudience next) {
    if (next == _audience) return;
    _audience = next;
    _message = null;
    _load(notify: true);
  }

  void dismissMessage() {
    _message = null;
    _notify();
  }

  void gatewayHandled() {
    _gateway = null;
  }

  /// Buys [plan]'s headline term. Nothing happens for a plan with no term, the
  /// free rung, one sold by conversation, or the plan already held.
  Future<void> choose(MembershipPlan plan) {
    if (plan.isFree || plan.contactSales || isCurrent(plan)) return Future.value();
    return buyPrice(plan.headlineTerm?.id, plan.name);
  }

  /// Renews the running term at today's price.
  Future<void> renew() {
    final mine = _mine;
    return buyPrice(mine?.renewal?.priceId, mine?.subscription?.planName ?? 'your plan');
  }

  Future<void> buyPrice(String? priceId, String planName) async {
    if (priceId == null || _busyPriceId != null) return;
    _busyPriceId = priceId;
    _message = null;
    _notify();
    try {
      final outcome = await repository.checkout(priceId);
      if (outcome.devActivated) {
        _message = "You're on $planName.";
        await _loadMine();
      } else if (outcome.needsGateway) {
        _gateway = outcome;
        _message = 'The payment for $planName continues on the ICR website.';
      } else {
        _message = 'The checkout for $planName was started; ICR will confirm it.';
      }
    } catch (e) {
      _message = ApiError.from(e).message;
    } finally {
      _busyPriceId = null;
      _notify();
    }
  }

  Future<void> _load({required bool notify}) async {
    final generation = ++_generation;
    final audience = _audience;
    _loading = true;
    _error = null;
    if (notify) _notify();
    try {
      final results = await Future.wait<Object?>([
        repository.plans(audience),
        repository.mine(audience).then<Object?>((m) => m).catchError((Object _) => null),
      ]);
      if (generation != _generation) return;
      _plans = results[0] as List<MembershipPlan>;
      _mine = results[1] as MyPlan?;
    } catch (e) {
      if (generation != _generation) return;
      _plans = const [];
      _mine = null;
      _error = ApiError.from(e).message;
    } finally {
      if (generation == _generation) {
        _loading = false;
        _notify();
      }
    }
  }

  Future<void> _loadMine() async {
    try {
      _mine = await repository.mine(_audience);
    } catch (_) {
      // The cards stand; the next refresh reads it again.
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
