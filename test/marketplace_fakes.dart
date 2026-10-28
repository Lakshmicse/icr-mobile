/// Stand-ins for the Marketplace tests: where each tap would have gone, the
/// demo source with every call written down, and the real API's answers
/// (captured from the local portal, `test/fixtures/marketplace/`) served from a
/// table.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/features/marketplace/api_marketplace_repository.dart';
import 'package:icr_mobile/features/marketplace/catalog_models.dart';
import 'package:icr_mobile/features/marketplace/demo_marketplace_repository.dart';
import 'package:icr_mobile/features/marketplace/marketplace_filters.dart';
import 'package:icr_mobile/features/marketplace/marketplace_links.dart';
import 'package:icr_mobile/features/marketplace/marketplace_models.dart';
import 'package:icr_mobile/features/marketplace/marketplace_repository.dart';
import 'package:icr_mobile/features/marketplace/quote_models.dart';

/// Where each tap would have gone, instead of the dialler, the browser and the share sheet.
class RecordingLinks extends MarketplaceLinks {
  final opened = <Uri>[];
  final shared = <String>[];

  /// What [open] answers: false is "nothing could open it".
  bool opens = true;

  /// The paths (and queries) of the opened website pages, `https://icr.org.in` dropped.
  List<String> get paths => [
    for (final u in opened)
      if (u.host == 'icr.org.in') '${u.path}${u.hasQuery ? '?${u.query}' : ''}',
  ];

  /// Everything opened that is not a page of the website, as text (`tel:+9180...`, `https://wa.me/...`).
  List<String> get outside => [
    for (final u in opened)
      if (u.host != 'icr.org.in') '$u',
  ];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return opens;
  }

  @override
  Future<void> share({required String text, String? subject}) async => shared.add(text);
}

/// A supplier a card can show.
Supplier fakeSupplier(
  String id, {
  String name = 'BlueDot',
  String? headline = 'Corporate Security',
  String? about = 'Biometric systems, CCTV & Manpower',
  double rating = 4.8,
  int ratingCount = 124,
  SupplierLevel level = SupplierLevel.verified,
  List<String> categories = const ['PHYSICAL_SECURITY'],
}) => Supplier(
  id: id,
  companyId: 'co-$id',
  name: name,
  headline: headline,
  about: about,
  rating: rating,
  ratingCount: ratingCount,
  level: level,
  categories: categories,
);

/// The demo source, with its calls recorded and its answers replaceable.
class SpyMarketplaceRepository extends DemoMarketplaceRepository {
  SpyMarketplaceRepository({super.cards, super.total});

  final calls = <String>[];
  final searches = <({MarketplaceFilters filters, int page})>[];
  final saves = <({String id, bool saved})>[];
  final ratings = <({String id, int score, String? comment})>[];
  final conversations = <String>[];
  final quotes = <QuoteRequest>[];

  /// What `hasPhone` answers (the member's profile has a number).
  bool phoneOnFile = true;

  /// While set, sending a quote waits for it.
  Completer<void>? quoteGate;

  /// Replaces what a search answers.
  SupplierPage Function(MarketplaceFilters filters, int page)? searchAnswer;

  /// Replaces what the member's saved list answers.
  SupplierPage Function(int page)? savedAnswer;

  SearchExtras extrasAnswer = SearchExtras.none;
  MarketplaceCounts countsAnswer = const MarketplaceCounts(myRfqs: 3, newAlerts: 2);
  int unreadAnswer = 1;

  /// Replaces what a supplier's own read answers (the full listing).
  Supplier Function(String id)? supplierAnswer;
  List<Compliance> Function(String companyId)? compliancesAnswer;
  List<CatalogService> Function(String companyId)? servicesAnswer;
  List<CatalogProduct> Function(String companyId)? productsAnswer;

  /// What `GET /services/:id`, `GET /products/:id` and the supplier of a company answer.
  CatalogService Function(String id)? serviceAnswer;
  CatalogProduct Function(String id)? productAnswer;
  Supplier? Function(String companyId)? supplierOfCompanyAnswer;

  /// Replaces the category tree.
  List<CategoryNode> Function()? treeAnswer;

  /// Every catalogue board read: which kind, its category, its words and its page.
  final boardReads = <({String kind, String? category, String? slug, String search, int page})>[];
  CatalogPage<CatalogProduct> Function(int page, String search)? boardProducts;
  CatalogPage<CatalogService> Function(int page, String search)? boardServices;

  /// While set, a directory read waits for it (to look at the loading state).
  Completer<void>? gate;

  /// Makes the next call to the named method throw.
  final failing = <String, Object>{};

  void _maybeFail(String name) {
    final error = failing[name];
    if (error != null) throw error;
  }

  @override
  Future<SupplierPage> suppliers(MarketplaceFilters filters, {int page = 1}) async {
    calls.add('suppliers');
    searches.add((filters: filters, page: page));
    await gate?.future;
    _maybeFail('suppliers');
    final answer = searchAnswer;
    return answer != null ? answer(filters, page) : super.suppliers(filters, page: page);
  }

  @override
  Future<SupplierPage> savedSuppliers({int page = 1}) async {
    calls.add('savedSuppliers');
    _maybeFail('savedSuppliers');
    final answer = savedAnswer;
    return answer != null ? answer(page) : super.savedSuppliers(page: page);
  }

  @override
  Future<void> setSaved(String vendorId, bool saved) async {
    calls.add('setSaved');
    saves.add((id: vendorId, saved: saved));
    _maybeFail('setSaved');
    await super.setSaved(vendorId, saved);
  }

  @override
  Future<MarketplaceCounts> counts() async {
    calls.add('counts');
    return countsAnswer;
  }

  @override
  Future<int> unreadNotifications() async => unreadAnswer;

  @override
  Future<SearchExtras> searchExtras(String query) async {
    calls.add('searchExtras:$query');
    return extrasAnswer;
  }

  @override
  Future<Supplier> supplier(String id) async {
    calls.add('supplier');
    _maybeFail('supplier');
    final answer = supplierAnswer;
    return answer != null ? answer(id) : super.supplier(id);
  }

  @override
  Future<List<Compliance>> compliances(String companyId) async {
    calls.add('compliances');
    _maybeFail('compliances');
    final answer = compliancesAnswer;
    return answer != null ? answer(companyId) : super.compliances(companyId);
  }

  @override
  Future<List<CatalogService>> servicesOf(String companyId) async {
    calls.add('servicesOf');
    _maybeFail('servicesOf');
    final answer = servicesAnswer;
    return answer != null ? answer(companyId) : super.servicesOf(companyId);
  }

  @override
  Future<List<CatalogProduct>> productsOf(String companyId) async {
    calls.add('productsOf');
    _maybeFail('productsOf');
    final answer = productsAnswer;
    return answer != null ? answer(companyId) : super.productsOf(companyId);
  }

  @override
  Future<List<CategoryNode>> categories() async {
    calls.add('categories');
    final answer = treeAnswer;
    return answer != null ? answer() : super.categories();
  }

  @override
  Future<CatalogService> service(String id) async {
    calls.add('service');
    _maybeFail('service');
    final answer = serviceAnswer;
    return answer != null ? answer(id) : super.service(id);
  }

  @override
  Future<CatalogProduct> product(String id) async {
    calls.add('product');
    _maybeFail('product');
    final answer = productAnswer;
    return answer != null ? answer(id) : super.product(id);
  }

  @override
  Future<Supplier?> supplierOfCompany(String companyId) async {
    calls.add('supplierOfCompany');
    _maybeFail('supplierOfCompany');
    final answer = supplierOfCompanyAnswer;
    return answer != null ? answer(companyId) : super.supplierOfCompany(companyId);
  }

  @override
  Future<CatalogPage<CatalogProduct>> products({
    String? categorySlug,
    String? companyId,
    String search = '',
    int page = 1,
  }) async {
    calls.add('products');
    boardReads.add((kind: 'products', category: null, slug: categorySlug, search: search, page: page));
    _maybeFail('products');
    final answer = boardProducts;
    return answer != null
        ? answer(page, search)
        : super.products(categorySlug: categorySlug, companyId: companyId, search: search, page: page);
  }

  @override
  Future<CatalogPage<CatalogService>> services({
    String? category,
    String? companyId,
    String search = '',
    int page = 1,
  }) async {
    calls.add('services');
    boardReads.add((kind: 'services', category: category, slug: null, search: search, page: page));
    _maybeFail('services');
    final answer = boardServices;
    return answer != null
        ? answer(page, search)
        : super.services(category: category, companyId: companyId, search: search, page: page);
  }

  @override
  Future<bool> hasPhone() async {
    calls.add('hasPhone');
    _maybeFail('hasPhone');
    return phoneOnFile;
  }

  @override
  Future<QuoteSent> requestQuote(QuoteRequest request) async {
    calls.add('requestQuote');
    quotes.add(request);
    await quoteGate?.future;
    _maybeFail('requestQuote');
    return QuoteSent(id: 'rfq-${quotes.length}', title: request.title);
  }

  @override
  Future<String> startConversation(String vendorId, {String? message}) async {
    calls.add('startConversation');
    conversations.add(vendorId);
    _maybeFail('startConversation');
    return 'conversation-$vendorId';
  }

  @override
  Future<void> rate(String vendorId, {required int score, String? comment}) async {
    calls.add('rate');
    ratings.add((id: vendorId, score: score, comment: comment));
    _maybeFail('rate');
  }
}

/// A page of [count] fake suppliers starting at [from].
SupplierPage pageOf(int count, {int from = 1, int total = 100, bool hasMore = true, int page = 1}) => SupplierPage(
  suppliers: [for (var i = 0; i < count; i++) fakeSupplier('s${from + i}', name: 'Supplier ${from + i}')],
  total: total,
  page: page,
  hasMore: hasMore,
);

// ---- The real API's answers ----------------------------------------------------------------

/// A captured answer of the portal (`test/fixtures/marketplace/<name>`).
Object fixture(String name) => jsonDecode(File('test/fixtures/marketplace/$name').readAsStringSync()) as Object;

class _NoTokens extends TokenStore {
  @override
  Future<String?> accessToken() async => 'token';
  @override
  Future<String?> refreshToken() async => null;
}

/// Answers each route from a table and records the calls.
class MartApi implements HttpClientAdapter {
  MartApi(this.routes);

  final Map<String, Object Function(RequestOptions options)> routes;
  final List<RequestOptions> requests = [];

  List<String> get calls => [for (final o in requests) '${o.method} ${o.path}'];

  /// The query of the last call to [route] (`GET /vendors` → its `queryParameters`).
  Map<String, dynamic> queryOf(String route) => requests
      .lastWhere((o) => '${o.method} ${o.path}' == route, orElse: () => throw StateError('no call to $route'))
      .queryParameters;

  /// The body of the last call to [route].
  Object? bodyOf(String route) => requests
      .lastWhere((o) => '${o.method} ${o.path}' == route, orElse: () => throw StateError('no call to $route'))
      .data;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final handler = routes['${options.method} ${options.path}'];
    if (handler == null) return ResponseBody.fromString('{"message":"Not found"}', 404, headers: _json);
    final result = handler(options);
    if (result is (int, String)) return ResponseBody.fromString(result.$2, result.$1, headers: _json);
    return ResponseBody.fromString(jsonEncode(result), 200, headers: _json);
  }

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}

/// The Marketplace repository over [api] (a [MartApi]).
ApiMarketplaceRepository apiRepo(MartApi api, {int pageSize = 12}) {
  final client = ApiClient(tokens: _NoTokens(), baseUrl: 'http://api.test/api/v1');
  client.dio.httpClientAdapter = api;
  return ApiMarketplaceRepository(api: client, pageSize: pageSize);
}

/// The routes every Marketplace read goes through, answered as the portal answered them.
Map<String, Object Function(RequestOptions)> realRoutes() => {
  'GET /vendors': (_) => fixture('vendors_page.json'),
  'GET /vendors/design-mkt-v-vikasha': (_) => fixture('vendor_detail.json'),
  'GET /vendors/saved/ids': (_) => fixture('saved_ids.json'),
  'GET /vendors/cities': (_) => fixture('cities.json'),
  'GET /vendors/category-counts': (_) => fixture('category_counts.json'),
  'GET /categories/tree': (_) => fixture('categories_tree.json'),
  'GET /rfq/mine/summary': (_) => fixture('rfq_summary.json'),
  'GET /notifications': (_) => {
    'data': [],
    'meta': {'total': 0, 'hasNext': false},
  },
  'GET /notifications/unread-count': (_) => fixture('unread_count.json'),
  'GET /certifications/verified': (_) => fixture('certifications_verified.json'),
  'GET /certifications/types': (_) => fixture('certification_types.json'),
  'GET /services': (_) => fixture('services_page.json'),
  'GET /products': (_) => fixture('products_page.json'),
};

/// A rows-and-meta page, as the portal's list endpoints answer.
Map<String, Object?> pageJson(List<Object?> rows, {int? total, bool hasNext = false}) => {
  'data': rows,
  'meta': {
    'page': 1,
    'limit': 12,
    'total': total ?? rows.length,
    'totalPages': 1,
    'hasNext': hasNext,
    'hasPrev': false,
  },
};

/// The catalogue categories a test can name.
const sampleTree = [
  CategoryNode(
    key: 'SECURITY',
    name: 'Security Services',
    count: 62,
    children: [
      CategoryNode(key: 'PHYSICAL_SECURITY', name: 'Physical Security', count: 41),
      CategoryNode(key: 'ELECTRONIC_SECURITY', name: 'Electronic Security', count: 33),
    ],
  ),
  CategoryNode(key: 'MEP', name: 'Engineering Services', count: 20),
];

/// A full listing (`GET /vendors/:id`) with everything a profile draws.
Supplier fullSupplier(
  String id, {
  String name = 'Vikasha Aero Tech',
  String? about,
  String? website = 'https://vikasha.example.in',
  String? phone = '+91 80 4000 1100',
  SupplierLevel level = SupplierLevel.elite,
  List<SupplierReview>? reviews,
  List<SupplierHub>? hubs,
  int ratingCount = 84,
}) => Supplier(
  id: id,
  companyId: 'co-$id',
  name: name,
  headline: 'AI-Guided Robotic High-Rise Maintenance.',
  about:
      about ??
      'Revolutionizing commercial facility maintenance through DGCA-licensed robotic and drone-based cleaning solutions.',
  categories: const ['HOUSEKEEPING'],
  serviceAreas: const ['Bengaluru', 'Pune'],
  rating: 4.9,
  ratingCount: ratingCount,
  level: level,
  website: website,
  size: '51-200',
  foundedYear: 2019,
  yearsExperience: 7,
  projectsCompleted: 150,
  responseTime: 'WITHIN_4H',
  legalStructure: 'PRIVATE_LIMITED',
  registrationNumber: 'CIN-U74999KA2019PTC1',
  detailed: true,
  hubs:
      hubs ??
      [
        SupplierHub(
          id: 'h1',
          name: 'Bengaluru HQ',
          city: 'Bengaluru',
          state: 'Karnataka',
          phone: phone,
          headOffice: true,
          latitude: 12.97,
          longitude: 77.59,
        ),
        const SupplierHub(id: 'h2', name: 'Pune Hub', city: 'Pune', state: 'Maharashtra', phone: '+91 20 4000 1300'),
      ],
  reviews:
      reviews ??
      [
        SupplierReview(
          id: 'r1',
          score: 5,
          comment: 'Transitioned our 14-tower facade cleaning to drones.',
          createdAt: DateTime.utc(2026, 10, 5),
        ),
        const SupplierReview(id: 'r2', score: 4),
      ],
);

/// A page holding just [suppliers].
SupplierPage pageWith(List<Supplier> suppliers) =>
    SupplierPage(suppliers: suppliers, total: suppliers.length, page: 1, hasMore: false);
