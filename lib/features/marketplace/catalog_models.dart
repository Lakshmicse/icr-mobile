import 'marketplace_json.dart';

/// A service a supplier offers (`GET /services`, `GET /services/:id`).
class CatalogService {
  const CatalogService({
    required this.id,
    required this.companyId,
    required this.name,
    this.category,
    this.subcategory,
    this.description,
    this.rate,
    this.rateUnit,
    this.turnaround,
    this.imageUrl,
    this.imageAsset,
    this.group,
    this.ctaLabel,
    this.supplierName,
    this.supplierLogoUrl,
    this.supplierLevel,
    this.supplierId,
  });

  final String id;
  final String companyId;
  final String name;

  /// Taxonomy keys.
  final String? category;
  final String? subcategory;
  final String? description;
  final double? rate;
  final String? rateUnit;

  /// What the supplier says about how fast ("24 hours", "Night shifts available").
  final String? turnaround;

  /// A photo of the service. The API has none yet (docs/backend-requests/marketplace.md),
  /// so a live row draws a tile with the service's initial.
  final String? imageUrl;

  /// Demo content only: the design's photo, bundled at 4x.
  final String? imageAsset;

  /// Demo content only: the design's chip label ("Facade").
  final String? group;

  /// Demo content only: the design's button ("Book Inspection").
  final String? ctaLabel;

  final String? supplierName;
  final String? supplierLogoUrl;
  final String? supplierLevel;
  final String? supplierId;

  /// A service with a fixed rate can be booked as it stands; one without is
  /// priced by quote.
  bool get bookable => rate != null && rate! > 0;

  /// The button on the row.
  String get action => ctaLabel ?? (bookable ? 'Book Service' : 'Get Quote');

  /// "Rs 5,000 per visit".
  String? get rateLabel {
    if (rate == null) return null;
    final unit = rateUnit == null
        ? ''
        : ' ${rateUnit!.startsWith('per') || rateUnit!.startsWith('/') ? '' : 'per '}${rateUnit!}';
    return '${formatRupees(rate!)}$unit';
  }

  factory CatalogService.fromJson(Map<String, dynamic> j, {required String? Function(String?) absolute}) {
    final company = asMap(j['company']);
    return CatalogService(
      id: '${j['id']}',
      companyId: '${j['companyId'] ?? company['id'] ?? ''}',
      name: asText(j['name']) ?? 'Service',
      category: asText(j['category']),
      subcategory: asText(j['subcategory']),
      description: asText(j['description']),
      rate: asDouble(j['rate']),
      rateUnit: asText(j['rateUnit']),
      turnaround: asText(j['turnaroundTime']),
      imageUrl: absolute(asText(j['imageUrl'])),
      supplierName: asText(company['name']),
      supplierLogoUrl: absolute(asText(company['logoUrl'])),
      supplierLevel: asText(company['verificationLevel']),
    );
  }
}

/// What a supplier says about a product's stock.
enum ProductStock {
  inStock('IN_STOCK', 'In stock'),
  madeToOrder('MADE_TO_ORDER', 'Made to order'),
  outOfStock('OUT_OF_STOCK', 'Out of stock');

  const ProductStock(this.api, this.label);

  final String api;
  final String label;

  static ProductStock? parse(Object? raw) {
    for (final s in values) {
      if (s.api == raw) return s;
    }
    return null;
  }
}

/// A product a supplier sells (`GET /products`, `GET /products/:id`).
class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.companyId,
    required this.name,
    this.description,
    this.price,
    this.unit,
    this.imageUrl,
    this.imageAsset,
    this.stock,
    this.warrantyMonths,
    this.returnDays,
    this.freeDeliveryOver,
    this.bulkPricingMinQty,
    this.categoryKey,
    this.categoryName,
    this.supplierName,
    this.supplierLogoUrl,
    this.supplierLevel,
    this.supplierRating,
    this.supplierRatingCount,
    this.supplierVendorId,
  });

  final String id;
  final String companyId;
  final String name;
  final String? description;

  /// Rupees.
  final double? price;
  final String? unit;
  final String? imageUrl;
  final String? imageAsset;
  final ProductStock? stock;
  final int? warrantyMonths;
  final int? returnDays;

  /// Whole rupees; 0 means every order ships free.
  final int? freeDeliveryOver;
  final int? bulkPricingMinQty;
  final String? categoryKey;
  final String? categoryName;
  final String? supplierName;
  final String? supplierLogoUrl;
  final String? supplierLevel;
  final double? supplierRating;
  final int? supplierRatingCount;

  /// The supplier's listing (`company.vendor.id`), when it has one.
  final String? supplierVendorId;

  /// "Rs 480 / piece".
  String? get priceLabel {
    if (price == null) return null;
    return unit == null ? formatRupees(price!) : '${formatRupees(price!)} / $unit';
  }

  /// The supplier's own terms, one line each, only for what is stated.
  List<String> get terms => [
    if (warrantyMonths != null && warrantyMonths! > 0)
      warrantyMonths! % 12 == 0 ? '${warrantyMonths! ~/ 12}-year warranty' : '$warrantyMonths-month warranty',
    if (returnDays != null && returnDays! > 0) '$returnDays-day returns',
    if (freeDeliveryOver != null)
      freeDeliveryOver == 0 ? 'Free delivery' : 'Free delivery over ${formatRupees(freeDeliveryOver!.toDouble())}',
    if (bulkPricingMinQty != null) 'Bulk pricing from $bulkPricingMinQty${unit == null ? '' : ' $unit'}',
  ];

  factory CatalogProduct.fromJson(Map<String, dynamic> j, {required String? Function(String?) absolute}) {
    final company = asMap(j['company']);
    final category = asMap(j['category']);
    final vendor = asMap(company['vendor']);
    return CatalogProduct(
      id: '${j['id']}',
      companyId: '${j['companyId'] ?? company['id'] ?? ''}',
      name: asText(j['name']) ?? 'Product',
      description: asText(j['description']),
      price: asDouble(j['price']),
      unit: asText(j['unit']),
      imageUrl: absolute(asText(j['imageUrl'])),
      stock: ProductStock.parse(j['availability']),
      warrantyMonths: asInt(j['warrantyMonths']),
      returnDays: asInt(j['returnDays']),
      freeDeliveryOver: asInt(j['freeDeliveryOver']),
      bulkPricingMinQty: asInt(j['bulkPricingMinQty']),
      categoryKey: asText(category['key']),
      categoryName: asText(category['name']),
      supplierName: asText(company['name']),
      supplierLogoUrl: absolute(asText(company['logoUrl'])),
      supplierLevel: asText(company['verificationLevel']),
      supplierRating: asDouble(vendor['rating']),
      supplierRatingCount: asInt(vendor['ratingCount']),
      supplierVendorId: asText(vendor['id']),
    );
  }
}

/// A requirement the search found (`GET /rfq?search=`, `GET /rfq/mine?search=`).
class RfqHit {
  const RfqHit({
    required this.id,
    required this.title,
    this.city,
    this.kind,
    this.status,
    this.dueDate,
    this.mine = false,
  });

  final String id;
  final String title;
  final String? city;
  final String? kind;
  final String? status;
  final DateTime? dueDate;

  /// The member's own requirement.
  final bool mine;

  factory RfqHit.fromJson(Map<String, dynamic> j, {bool mine = false}) {
    final locations = asStrings(j['locations']);
    return RfqHit(
      id: '${j['id']}',
      title: asText(j['title']) ?? 'Requirement',
      city: asText(j['city']) ?? (locations.isEmpty ? null : locations.first),
      kind: asText(j['kind']),
      status: asText(j['status']),
      dueDate: asDate(j['dueDate']),
      mine: mine,
    );
  }
}

/// What a search finds besides suppliers.
class SearchExtras {
  const SearchExtras({this.services = const [], this.rfqs = const []});

  static const none = SearchExtras();

  final List<CatalogService> services;
  final List<RfqHit> rfqs;

  bool get isEmpty => services.isEmpty && rfqs.isEmpty;
}

/// A node of the category tree (`GET /categories/tree`).
class CategoryNode {
  const CategoryNode({
    required this.key,
    required this.name,
    this.slug,
    this.blurb,
    this.children = const [],
    this.count,
  });

  final String key;
  final String name;
  final String? slug;
  final String? blurb;
  final List<CategoryNode> children;

  /// Live listings under it (`GET /vendors/category-counts`).
  final int? count;

  CategoryNode withCounts(Map<String, int> counts) => CategoryNode(
    key: key,
    name: name,
    slug: slug,
    blurb: blurb,
    count: counts[key] ?? 0,
    children: [for (final c in children) c.withCounts(counts)],
  );

  factory CategoryNode.fromJson(Map<String, dynamic> j) => CategoryNode(
    key: '${j['key'] ?? j['slug'] ?? j['id']}',
    name: asText(j['name']) ?? '',
    slug: asText(j['slug']),
    blurb: asText(j['blurb']),
    children: [
      for (final c in asMaps(j['children']))
        if (c['active'] != false) CategoryNode.fromJson(c),
    ],
  );
}

/// Whole rupees with Indian grouping: "Rs 12,50,000" is written "₹12,50,000".
String formatRupees(double amount) {
  final whole = amount == amount.roundToDouble();
  final text = whole ? amount.toInt().toString() : amount.toStringAsFixed(2);
  final parts = text.split('.');
  var digits = parts.first;
  final sign = digits.startsWith('-') ? '-' : '';
  if (sign.isNotEmpty) digits = digits.substring(1);
  if (digits.length > 3) {
    final tail = digits.substring(digits.length - 3);
    var head = digits.substring(0, digits.length - 3);
    final groups = <String>[];
    while (head.length > 2) {
      groups.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    if (head.isNotEmpty) groups.insert(0, head);
    digits = '${groups.join(',')},$tail';
  }
  return '₹$sign$digits${parts.length > 1 ? '.${parts[1]}' : ''}';
}
