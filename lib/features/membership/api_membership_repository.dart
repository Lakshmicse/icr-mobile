import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import 'membership_models.dart';
import 'membership_repository.dart';

/// The website's membership, from the API (`backend/src/modules/subscriptions`).
class ApiMembershipRepository implements MembershipRepository {
  ApiMembershipRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? query]) async {
    try {
      final res = await _api.dio.get<dynamic>(path, queryParameters: query);
      return (res.data as Map?)?.cast<String, dynamic>() ?? const {};
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  @override
  Future<List<MembershipPlan>> plans(MembershipAudience audience) async {
    final json = await _get('/subscriptions/catalogue', {'audience': audience.api});
    return [
      for (final p in (json['plans'] as List? ?? const []))
        if (p is Map) MembershipPlan.fromJson(p.cast<String, dynamic>()),
    ];
  }

  /// `/me` gives the plan held; `/me/all` whether the member may buy here and
  /// why not. The second is a nicety: when it fails the member may still try,
  /// and the checkout's own refusal says why.
  @override
  Future<MyPlan> mine(MembershipAudience audience) async {
    final json = await _get('/subscriptions/me', {'audience': audience.api});
    var canBuy = true;
    String? reason;
    try {
      final all = await _get('/subscriptions/me/all');
      for (final m in (all['memberships'] as List? ?? const [])) {
        if (m is Map && m['audience'] == audience.api) {
          canBuy = m['canBuy'] as bool? ?? true;
          reason = m['reason'] as String?;
        }
      }
    } on ApiError {
      // Left as "may buy".
    }
    return MyPlan.fromJson({...json, 'canBuy': canBuy, 'reason': reason}, fallback: audience);
  }

  @override
  Future<MembershipHistory> history(MembershipAudience audience) async {
    final json = await _get('/subscriptions/me/history', {'audience': audience.api});
    return MembershipHistory.fromJson(json, fallback: audience);
  }

  @override
  Future<CheckoutOutcome> checkout(String priceId) async {
    try {
      final res = await _api.dio.post<dynamic>('/subscriptions/checkout', data: {'priceId': priceId});
      return CheckoutOutcome.fromJson((res.data as Map?)?.cast<String, dynamic>() ?? const {});
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}
