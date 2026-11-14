import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../account/account_models.dart' show PickedPhoto;
import 'catalog_models.dart';

export '../account/account_models.dart' show PickedPhoto;

/// Where My Products and My Services read and write: the company's catalogue (`/products`, `/services`, owner
/// scoped by `companyId`), the taxonomy the pickers offer, the product photo upload, whether the company sells yet
/// and the one way to start, and the plan's number of listing places. Every refusal comes out as an [ApiError]
/// carrying the API's own sentence (an unknown category, the plan's listing limit, a company that already sells).
abstract class CatalogRepository {
  /// `GET /vendors/me/access`: whether the company has a supplier listing (`vendorId`).
  Future<SupplierAccess> access();

  /// `GET /products?companyId=&limit=100`, as the website's `productsApi.useMine`.
  Future<List<ProductItem>> products(String companyId);

  /// `GET /services?companyId=&limit=100`.
  Future<List<ServiceItem>> services(String companyId);

  /// `GET /categories/tree?kind=PRODUCT|SERVICE&depth=2`: the two levels the pickers offer, active keyed nodes only.
  Future<List<CatalogCategory>> categories(String kind);

  /// `POST /products` with the website's body plus `companyId`.
  Future<ProductItem> createProduct(Map<String, Object?> body);

  /// `PATCH /products/:id`.
  Future<ProductItem> updateProduct(String id, Map<String, Object?> body);

  /// `DELETE /products/:id` (a soft delete; nothing on screen brings it back).
  Future<void> deleteProduct(String id);

  /// `POST /services`.
  Future<ServiceItem> createService(Map<String, Object?> body);

  /// `PATCH /services/:id`.
  Future<ServiceItem> updateService(String id, Map<String, Object?> body);

  /// `DELETE /services/:id`.
  Future<void> deleteService(String id);

  /// `POST /uploads?purpose=catalog`: the product photo, PUBLIC because product pages are read logged out. Returns
  /// the root-relative `/uploads/...` path the product stores as `imageUrl`.
  Future<String> uploadPhoto(PickedPhoto photo);

  /// `POST /vendors { companyId }`: switches selling on, the API filling the listing from what the company holds
  /// (the website's `StartSellingButton`).
  Future<void> startSelling(String companyId);

  /// `GET /subscriptions/entitlements` → `benefits['listing.items'].limit`: how many listing places the plan
  /// allows, products and services together; null when the plan sets no number (or the read fails).
  Future<int?> listingLimit();
}

class ApiCatalogRepository implements CatalogRepository {
  ApiCatalogRepository({required this.api});

  final ApiClient api;

  Future<T> _call<T>(Future<T> Function(Dio dio) body) async {
    try {
      return await body(api.dio);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  static Map<String, dynamic> _map(Object? data) => data is Map ? data.cast<String, dynamic>() : const {};

  static List<Map<String, dynamic>> _rows(Object? data) {
    final rows = data is Map ? data['data'] : data;
    return [
      for (final r in rows is List ? rows : const [])
        if (r is Map) r.cast<String, dynamic>(),
    ];
  }

  @override
  Future<SupplierAccess> access() =>
      _call((dio) async => SupplierAccess.fromJson(_map((await dio.get<dynamic>('/vendors/me/access')).data)));

  @override
  Future<List<ProductItem>> products(String companyId) => _call((dio) async {
    final res = await dio.get<dynamic>('/products', queryParameters: {'companyId': companyId, 'limit': 100});
    return [for (final r in _rows(res.data)) ProductItem.fromJson(r)];
  });

  @override
  Future<List<ServiceItem>> services(String companyId) => _call((dio) async {
    final res = await dio.get<dynamic>('/services', queryParameters: {'companyId': companyId, 'limit': 100});
    return [for (final r in _rows(res.data)) ServiceItem.fromJson(r)];
  });

  @override
  Future<List<CatalogCategory>> categories(String kind) => _call((dio) async {
    final res = await dio.get<dynamic>('/categories/tree', queryParameters: {'kind': kind, 'depth': 2});
    return [for (final r in _rows(res.data)) ?CatalogCategory.fromJson(r)];
  });

  @override
  Future<ProductItem> createProduct(Map<String, Object?> body) =>
      _call((dio) async => ProductItem.fromJson(_map((await dio.post<dynamic>('/products', data: body)).data)));

  @override
  Future<ProductItem> updateProduct(String id, Map<String, Object?> body) => _call(
    (dio) async =>
        ProductItem.fromJson(_map((await dio.patch<dynamic>('/products/${Uri.encodeComponent(id)}', data: body)).data)),
  );

  @override
  Future<void> deleteProduct(String id) => _call((dio) => dio.delete<dynamic>('/products/${Uri.encodeComponent(id)}'));

  @override
  Future<ServiceItem> createService(Map<String, Object?> body) =>
      _call((dio) async => ServiceItem.fromJson(_map((await dio.post<dynamic>('/services', data: body)).data)));

  @override
  Future<ServiceItem> updateService(String id, Map<String, Object?> body) => _call(
    (dio) async =>
        ServiceItem.fromJson(_map((await dio.patch<dynamic>('/services/${Uri.encodeComponent(id)}', data: body)).data)),
  );

  @override
  Future<void> deleteService(String id) => _call((dio) => dio.delete<dynamic>('/services/${Uri.encodeComponent(id)}'));

  @override
  Future<String> uploadPhoto(PickedPhoto photo) => _call((dio) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        photo.bytes,
        filename: photo.name,
        contentType: DioMediaType.parse(photo.contentType),
      ),
    });
    final res = await dio.post<dynamic>('/uploads', data: form, queryParameters: {'purpose': 'catalog'});
    final url = _map(res.data)['url'];
    if (url is! String || url.isEmpty) throw ApiError('Upload failed. Check the file and try again.');
    return url;
  });

  @override
  Future<void> startSelling(String companyId) =>
      _call((dio) => dio.post<dynamic>('/vendors', data: {'companyId': companyId}));

  @override
  Future<int?> listingLimit() async {
    try {
      final res = await api.dio.get<dynamic>('/subscriptions/entitlements');
      final benefit = _map(_map(res.data)['benefits'])['listing.items'];
      if (benefit is! Map || benefit['kind'] != 'LIMIT') return null;
      return (benefit['limit'] as num?)?.toInt();
    } catch (_) {
      // A plan figure the page can do without.
      return null;
    }
  }
}

/// The catalogue with no API: a sample company's products and services kept in memory, so changes stick for the
/// session, behaving as the API does where the screens depend on it (a create answers the stored row with an id, a
/// delete takes the row away, "Start selling" gives the company a listing).
///
/// Tests use it as their stand-in: every write is logged in [sent] (`{'op': ..., 'id'?: ..., 'body'?: ...}`), a
/// read can be made to fail ([failList]), [hasListing] says whether the company sells, [listingLimit] stands in for
/// the plan, and [delay] holds calls to show loading.
class DemoCatalogRepository implements CatalogRepository {
  DemoCatalogRepository({
    List<ProductItem>? products,
    List<ServiceItem>? services,
    List<CatalogCategory>? categories,
    this.hasListing = true,
    this.failList = false,
    this.failWrites = false,
    int? listingLimit,
    this.delay = Duration.zero,
  }) : productsNow = [...(products ?? sampleProducts())],
       servicesNow = [...(services ?? sampleServices())],
       categoriesNow = categories ?? sampleCategories,
       _listingLimit = listingLimit;

  List<ProductItem> productsNow;
  List<ServiceItem> servicesNow;
  final List<CatalogCategory> categoriesNow;
  bool hasListing;
  final bool failList;

  /// Every write is refused with a sample sentence, as the API refuses one over a plan's limit.
  final bool failWrites;
  final int? _listingLimit;
  final Duration delay;

  /// Every write sent, in order (tests).
  final sent = <Map<String, Object?>>[];

  int _next = 100;

  static const _art = 'assets/images/demo/marketplace';

  static List<ProductItem> sampleProducts() => [
    ProductItem(
      id: 'p-1',
      name: 'Biometric Access Terminal',
      description: 'Fingerprint and card access terminal with a 7-inch display, door relay and an audit log.',
      price: 18500,
      unit: 'piece',
      imageAsset: '$_art/lockup_securetech.png',
      category: const ProductCategoryRef(
        id: 'c-access',
        name: 'Access Control',
        key: 'ELECTRONIC_SECURITY_ACCESS_CONTROL',
      ),
      availability: 'IN_STOCK',
      warrantyMonths: 24,
      returnDays: 7,
      freeDeliveryOver: 25000,
      bulkPricingMinQty: 10,
      createdAt: DateTime(2026, 10, 30, 14, 13),
    ),
    ProductItem(
      id: 'p-2',
      name: 'Industrial Floor Cleaner 5L',
      description: 'Low-foam alkaline cleaner for scrubber-driers; one litre dilutes to 50.',
      price: 499.5,
      unit: 'can',
      category: const ProductCategoryRef(id: 'c-hk', name: 'Housekeeping', key: 'HOUSEKEEPING'),
      createdAt: DateTime(2026, 11, 2, 9, 5),
    ),
    ProductItem(id: 'p-3', name: 'Visitor Badge Printer', createdAt: DateTime(2026, 11, 8, 17, 40)),
  ];

  static List<ServiceItem> sampleServices() => [
    ServiceItem(
      id: 's-1',
      name: 'Daily Office Housekeeping',
      category: 'FACILITY_MANAGEMENT',
      subcategory: 'HOUSEKEEPING',
      description: 'Trained staff, consumables and supervision for offices up to 50,000 sq ft.',
      rate: 85000,
      rateUnit: 'per month',
      turnaroundTime: '48 hours to mobilise',
      createdAt: DateTime(2026, 10, 26, 10, 24),
    ),
    ServiceItem(
      id: 's-2',
      name: 'Drone Facade Cleaning',
      category: 'FACILITY_MANAGEMENT',
      subcategory: 'HOUSEKEEPING',
      description: 'Precision wash for high-rise glass commercial towers up to 150 m.',
      turnaroundTime: 'SLA: 24h setup',
      createdAt: DateTime(2026, 10, 30, 14, 13),
    ),
    ServiceItem(
      id: 's-3',
      name: 'Annual Fire Audit',
      category: 'SAFETY_SECURITY',
      rate: 15000,
      rateUnit: 'per visit',
      createdAt: DateTime(2026, 11, 6, 8, 0),
    ),
  ];

  static const sampleCategories = <CatalogCategory>[
    CatalogCategory(
      key: 'FACILITY_MANAGEMENT',
      name: 'Facility Management',
      children: [
        CatalogCategory(key: 'HOUSEKEEPING', name: 'Housekeeping'),
        CatalogCategory(key: 'PEST_CONTROL', name: 'Pest Control'),
        CatalogCategory(key: 'LANDSCAPING', name: 'Landscaping'),
      ],
    ),
    CatalogCategory(
      key: 'SAFETY_SECURITY',
      name: 'Safety & Security',
      children: [
        CatalogCategory(key: 'ELECTRONIC_SECURITY_ACCESS_CONTROL', name: 'Access Control'),
        CatalogCategory(key: 'FIRE_SAFETY', name: 'Fire Safety'),
      ],
    ),
    CatalogCategory(
      key: 'CORPORATE_REAL_ESTATE',
      name: 'Corporate Real Estate',
      children: [CatalogCategory(key: 'REAL_ESTATE_ADVISORY', name: 'Real Estate Advisory')],
    ),
  ];

  Future<void> _enter(String op, {String? id, Map<String, Object?>? body}) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (op != 'read') sent.add({'op': op, 'id': ?id, 'body': ?body});
    if (op == 'read' && failList) throw ApiError('Could not load the catalogue.');
    if (op != 'read' && failWrites) {
      throw ApiError('Your plan lists up to 3 products and services. Remove one, or move to a larger plan.');
    }
  }

  @override
  Future<SupplierAccess> access() async {
    await _enter('read');
    return SupplierAccess(vendorId: hasListing ? 'v-1' : null, verified: hasListing);
  }

  @override
  Future<List<ProductItem>> products(String companyId) async {
    await _enter('read');
    return [...productsNow];
  }

  @override
  Future<List<ServiceItem>> services(String companyId) async {
    await _enter('read');
    return [...servicesNow];
  }

  @override
  Future<List<CatalogCategory>> categories(String kind) async {
    await _enter('read');
    return categoriesNow;
  }

  ProductCategoryRef? _categoryRef(Object? key) {
    if (key is! String || key.isEmpty) return null;
    return ProductCategoryRef(id: 'c-$key', name: categoryLabelOf(categoriesNow, key), key: key);
  }

  ProductItem _product(String id, Map<String, Object?> body, ProductItem? was) {
    double? price = was?.price;
    if (body.containsKey('price')) price = ProductItem.priceOf(body['price']);
    int? term(String k, int? old) => body.containsKey(k) ? (body[k] as num?)?.toInt() : old;
    return ProductItem(
      id: id,
      name: '${body['name'] ?? was?.name ?? ''}',
      description: body.containsKey('description') ? body['description'] as String? : was?.description,
      price: price,
      unit: body.containsKey('unit') ? body['unit'] as String? : was?.unit,
      imageUrl: body.containsKey('imageUrl') ? body['imageUrl'] as String? : was?.imageUrl,
      imageAsset: body.containsKey('imageUrl') ? null : was?.imageAsset,
      category: body.containsKey('categoryKey') ? _categoryRef(body['categoryKey']) : was?.category,
      availability: body.containsKey('availability') ? body['availability'] as String? : was?.availability,
      warrantyMonths: term('warrantyMonths', was?.warrantyMonths),
      returnDays: term('returnDays', was?.returnDays),
      freeDeliveryOver: term('freeDeliveryOver', was?.freeDeliveryOver),
      bulkPricingMinQty: term('bulkPricingMinQty', was?.bulkPricingMinQty),
      createdAt: was?.createdAt ?? DateTime.now(),
    );
  }

  @override
  Future<ProductItem> createProduct(Map<String, Object?> body) async {
    await _enter('createProduct', body: body);
    final row = _product('p-${_next++}', body, null);
    productsNow = [...productsNow, row];
    return row;
  }

  @override
  Future<ProductItem> updateProduct(String id, Map<String, Object?> body) async {
    await _enter('updateProduct', id: id, body: body);
    final i = productsNow.indexWhere((p) => p.id == id);
    if (i < 0) throw ApiError('Product not found', statusCode: 404);
    final row = _product(id, body, productsNow[i]);
    productsNow = [...productsNow]..[i] = row;
    return row;
  }

  @override
  Future<void> deleteProduct(String id) async {
    await _enter('deleteProduct', id: id);
    productsNow = [
      for (final p in productsNow)
        if (p.id != id) p,
    ];
  }

  ServiceItem _service(String id, Map<String, Object?> body, ServiceItem? was) => ServiceItem(
    id: id,
    name: '${body['name'] ?? was?.name ?? ''}',
    category: '${body['category'] ?? was?.category ?? ''}',
    subcategory: body.containsKey('subcategory') ? body['subcategory'] as String? : was?.subcategory,
    description: body.containsKey('description') ? body['description'] as String? : was?.description,
    rate: body.containsKey('rate') ? (body['rate'] as num?)?.toDouble() : was?.rate,
    rateUnit: body.containsKey('rateUnit') ? body['rateUnit'] as String? : was?.rateUnit,
    turnaroundTime: body.containsKey('turnaroundTime') ? body['turnaroundTime'] as String? : was?.turnaroundTime,
    createdAt: was?.createdAt ?? DateTime.now(),
  );

  @override
  Future<ServiceItem> createService(Map<String, Object?> body) async {
    await _enter('createService', body: body);
    final row = _service('s-${_next++}', body, null);
    servicesNow = [...servicesNow, row];
    return row;
  }

  @override
  Future<ServiceItem> updateService(String id, Map<String, Object?> body) async {
    await _enter('updateService', id: id, body: body);
    final i = servicesNow.indexWhere((s) => s.id == id);
    if (i < 0) throw ApiError('Service not found', statusCode: 404);
    final row = _service(id, body, servicesNow[i]);
    servicesNow = [...servicesNow]..[i] = row;
    return row;
  }

  @override
  Future<void> deleteService(String id) async {
    await _enter('deleteService', id: id);
    servicesNow = [
      for (final s in servicesNow)
        if (s.id != id) s,
    ];
  }

  @override
  Future<String> uploadPhoto(PickedPhoto photo) async {
    await _enter('uploadPhoto', body: {'name': photo.name, 'size': photo.bytes.length, 'type': photo.contentType});
    return '/uploads/demo-${_next++}-${photo.name}';
  }

  @override
  Future<void> startSelling(String companyId) async {
    await _enter('startSelling', body: {'companyId': companyId});
    hasListing = true;
  }

  @override
  Future<int?> listingLimit() async => _listingLimit;
}
