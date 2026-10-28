import '../../core/api/api_client.dart';
import '../../core/config.dart';
import 'catalog_models.dart';
import 'marketplace_filters.dart';
import 'marketplace_json.dart';
import 'marketplace_models.dart';
import 'marketplace_repository.dart';
import 'quote_models.dart';

/// The Marketplace from the ICR API: `/vendors` (and its saves), `/services`,
/// `/products`, `/categories`, `/certifications`, with `/rfq` and
/// `/notifications` for the numbers on the quick chips.
class ApiMarketplaceRepository implements MarketplaceRepository {
  ApiMarketplaceRepository({required this.api, this.pageSize = 12});

  final ApiClient api;

  /// How many suppliers a page holds: even and divisible by three, so a
  /// two-column phone and a three-column tablet both end on a full row.
  final int pageSize;

  List<CategoryNode>? _tree;
  Future<List<CategoryNode>>? _treeLoad;
  Map<String, String>? _certificationCategories;

  String? _abs(String? path) => AppConfig.absoluteUrl(path, apiBase: api.dio.options.baseUrl);

  Future<dynamic> _get(String path, [Map<String, dynamic>? query]) async =>
      (await api.dio.get<dynamic>(path, queryParameters: query)).data;

  Supplier _supplier(Map<String, dynamic> row) => Supplier.fromJson(row, absolute: _abs);

  SupplierPage _page(dynamic body, int page) {
    final rows = rowsOf(body);
    return SupplierPage(
      suppliers: [for (final r in rows) _supplier(r)],
      total: totalOf(body, rows.length),
      page: page,
      hasMore: hasNextOf(body),
    );
  }

  // ---- The directory --------------------------------------------------------------

  @override
  Future<SupplierPage> suppliers(MarketplaceFilters filters, {int page = 1}) async =>
      _page(await _get('/vendors', filters.query(page: page, limit: pageSize)), page);

  @override
  Future<SupplierPage> savedSuppliers({int page = 1}) async =>
      _page(await _get('/vendors/saved', {'page': page, 'limit': pageSize}), page);

  @override
  Future<Set<String>> savedIds() async => asStrings(asMap(await _get('/vendors/saved/ids'))['ids']).toSet();

  @override
  Future<void> setSaved(String vendorId, bool saved) async {
    final path = '/vendors/${Uri.encodeComponent(vendorId)}/save';
    if (saved) {
      await api.dio.post<dynamic>(path);
    } else {
      await api.dio.delete<dynamic>(path);
    }
  }

  @override
  Future<List<String>> cities() async => asStrings(await _get('/vendors/cities'));

  @override
  Future<List<CategoryNode>> categories() async {
    final cached = _tree;
    if (cached != null) return cached;
    return _treeLoad ??= () async {
      try {
        final results = await Future.wait([
          _get('/categories/tree', {'depth': 3}),
          _get('/vendors/category-counts').catchError((_) => const <dynamic>[]),
        ]);
        final counts = <String, int>{};
        for (final row in asMaps(results[1])) {
          final key = asText(row['key']);
          if (key != null) counts[key] = asInt(row['verified']) ?? asInt(row['all']) ?? 0;
        }
        return _tree = [for (final r in asMaps(results[0])) CategoryNode.fromJson(r).withCounts(counts)];
      } finally {
        _treeLoad = null;
      }
    }();
  }

  @override
  Future<MarketplaceCounts> counts() async {
    var mine = 0;
    try {
      // The number the My RFQ's screen opens on (its All tab), so the chip and the list it leads to agree.
      final views = asMap(asMap(await _get('/rfq/mine/summary'))['views']);
      mine =
          asInt(views['ALL']) ??
          (asInt(views['LIVE']) ?? 0) +
              (asInt(views['DRAFT']) ?? 0) +
              (asInt(views['AWARDED']) ?? 0) +
              (asInt(views['ENDED']) ?? 0);
    } catch (_) {
      // A member who cannot post requirements has none.
    }
    var fresh = 0;
    try {
      final rows = rowsOf(await _get('/notifications', {'limit': 100, 'unread': 'true'}));
      fresh = rows.where(_aboutRequirements).length;
    } catch (_) {
      // The chip reads plain "Alerts" until the next refresh says otherwise.
    }
    return MarketplaceCounts(myRfqs: mine, newAlerts: fresh);
  }

  /// The notification types about requirements (`notification-types.ts`), or a
  /// link into one of the member's requirements or bids.
  static const _rfqTypes = {
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

  static bool _aboutRequirements(Map<String, dynamic> row) {
    final link = asText(row['link']) ?? '';
    return _rfqTypes.contains(row['type']) ||
        link.startsWith('/manage/requirements/') ||
        link.startsWith('/manage/bids/');
  }

  @override
  Future<int> unreadNotifications() async => asInt(asMap(await _get('/notifications/unread-count'))['unread']) ?? 0;

  @override
  Future<SearchExtras> searchExtras(String query) async {
    final results = await Future.wait([
      _get('/services', {'search': query, 'limit': 3}).then<dynamic>((v) => v).catchError((_) => null),
      _get('/rfq', {'search': query, 'limit': 3}).then<dynamic>((v) => v).catchError((_) => null),
      _get('/rfq/mine', {'search': query, 'limit': 3}).then<dynamic>((v) => v).catchError((_) => null),
    ]);
    final mine = [for (final r in rowsOf(results[2])) RfqHit.fromJson(r, mine: true)];
    final seen = {for (final m in mine) m.id};
    return SearchExtras(
      services: [for (final r in rowsOf(results[0])) CatalogService.fromJson(r, absolute: _abs)],
      rfqs: [
        ...mine,
        for (final r in rowsOf(results[1]))
          if (!seen.contains('${r['id']}')) RfqHit.fromJson(r),
      ].take(3).toList(),
    );
  }

  // ---- One supplier ----------------------------------------------------------------

  @override
  Future<Supplier> supplier(String id) async => _supplier(asMap(await _get('/vendors/${Uri.encodeComponent(id)}')));

  @override
  Future<Supplier?> supplierOfCompany(String companyId) async {
    final rows = rowsOf(await _get('/vendors', {'companyId': companyId, 'limit': 1}));
    return rows.isEmpty ? null : _supplier(rows.first);
  }

  @override
  Future<List<Compliance>> compliances(String companyId) async {
    final categories = await _certificationTypes();
    final rows = asMaps(await _get('/certifications/verified', {'companyId': companyId}));
    return [for (final r in rows) Compliance.fromJson(r, categories: categories)];
  }

  Future<Map<String, String>> _certificationTypes() async {
    final cached = _certificationCategories;
    if (cached != null) return cached;
    try {
      final rows = asMaps(await _get('/certifications/types'));
      return _certificationCategories = {
        for (final r in rows)
          if (asText(r['id']) != null) asText(r['id'])!: asText(r['category']) ?? 'OTHER',
      };
    } catch (_) {
      return const {};
    }
  }

  @override
  Future<List<CatalogService>> servicesOf(String companyId) async => [
    for (final r in rowsOf(await _get('/services', {'companyId': companyId, 'limit': 50})))
      CatalogService.fromJson(r, absolute: _abs),
  ];

  @override
  Future<List<CatalogProduct>> productsOf(String companyId) async => [
    for (final r in rowsOf(await _get('/products', {'companyId': companyId, 'limit': 50})))
      CatalogProduct.fromJson(r, absolute: _abs),
  ];

  @override
  Future<String> startConversation(String vendorId, {String? message}) async {
    final res = await api.dio.post<dynamic>(
      '/messaging/conversations/supplier',
      data: {'vendorId': vendorId, if (message != null && message.trim().isNotEmpty) 'message': message.trim()},
    );
    return asText(asMap(res.data)['id']) ?? (throw StateError('The API opened no conversation.'));
  }

  @override
  Future<void> rate(String vendorId, {required int score, String? comment}) async {
    await api.dio.post<dynamic>(
      '/vendors/${Uri.encodeComponent(vendorId)}/ratings',
      data: {'score': score, if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim()},
    );
  }

  // ---- The catalogue -----------------------------------------------------------------

  @override
  Future<CatalogProduct> product(String id) async =>
      CatalogProduct.fromJson(asMap(await _get('/products/${Uri.encodeComponent(id)}')), absolute: _abs);

  @override
  Future<CatalogService> service(String id) async =>
      CatalogService.fromJson(asMap(await _get('/services/${Uri.encodeComponent(id)}')), absolute: _abs);

  @override
  Future<CatalogPage<CatalogProduct>> products({
    String? categorySlug,
    String? companyId,
    String search = '',
    int page = 1,
  }) async {
    final body = await _get('/products', {
      'page': page,
      'limit': pageSize,
      'categorySlug': ?categorySlug,
      'companyId': ?companyId,
      if (search.isNotEmpty) 'search': search,
    });
    final rows = rowsOf(body);
    return CatalogPage(
      items: [for (final r in rows) CatalogProduct.fromJson(r, absolute: _abs)],
      total: totalOf(body, rows.length),
      page: page,
      hasMore: hasNextOf(body),
    );
  }

  @override
  Future<CatalogPage<CatalogService>> services({
    String? category,
    String? companyId,
    String search = '',
    int page = 1,
  }) async {
    final body = await _get('/services', {
      'page': page,
      'limit': pageSize,
      'category': ?category,
      'companyId': ?companyId,
      if (search.isNotEmpty) 'search': search,
    });
    final rows = rowsOf(body);
    return CatalogPage(
      items: [for (final r in rows) CatalogService.fromJson(r, absolute: _abs)],
      total: totalOf(body, rows.length),
      page: page,
      hasMore: hasNextOf(body),
    );
  }

  // ---- Asking for a quote ------------------------------------------------------------------

  @override
  Future<bool> hasPhone() async {
    final me = asMap(await _get('/auth/me'));
    final user = me['user'] is Map ? asMap(me['user']) : me;
    return asText(user['phone']) != null;
  }

  @override
  Future<String?> myCompanyId() async {
    final me = asMap(await _get('/auth/me'));
    final user = me['user'] is Map ? asMap(me['user']) : me;
    return asText(user['companyId']);
  }

  @override
  Future<QuoteSent> requestQuote(QuoteRequest request) async {
    final res = await api.dio.post<dynamic>('/rfq', data: request.toJson());
    final body = asMap(res.data);
    final id = asText(body['id']);
    if (id == null) throw StateError('The API created no requirement.');
    return QuoteSent(id: id, title: asText(body['title']) ?? request.title);
  }

  @override
  Uri sitePage(String path) => AppConfig.sitePage(path);
}
