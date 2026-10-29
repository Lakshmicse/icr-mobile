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

  /// `/me/all` says what the member holds and may buy on each ladder; the
  /// catalogue (every audience at once) says which ladders have a plan on sale.
  /// A ladder gets a chip when the member holds a plan on it, or may buy there
  /// and it has one on sale: the website's own rule (`MembershipPlansPage`). When
  /// the catalogue cannot be read nothing is hidden for want of it, as there.
  @override
  Future<List<MembershipAudience>> audiences() async {
    Set<String>? onSale;
    try {
      final catalogue = await _get('/subscriptions/catalogue');
      onSale = {
        for (final p in (catalogue['plans'] as List? ?? const []))
          if (p is Map && p['audience'] is String) p['audience'] as String,
      };
    } on ApiError {
      onSale = null;
    }
    final all = await _get('/subscriptions/me/all');
    final shown = <MembershipAudience>{};
    for (final m in (all['memberships'] as List? ?? const [])) {
      if (m is! Map) continue;
      final audience = MembershipAudience.fromApi(m['audience'] as String?);
      if (audience == null) continue;
      final holds = m['subscription'] != null;
      final canBuy = m['canBuy'] as bool? ?? false;
      if (holds || (canBuy && (onSale == null || onSale.contains(audience.api)))) shown.add(audience);
    }
    return [for (final a in MembershipAudience.values) if (shown.contains(a)) a];
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
