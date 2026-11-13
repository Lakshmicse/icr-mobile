/// The company's catalogue as the website's `/manage/products` and `/manage/services` read it: a product (the
/// owner-scoped `GET /products?companyId=`; its `price` is a `Decimal(12,2)` that arrives as a string, its category
/// the joined `Category` row) and a service (`GET /services?companyId=`; a pair of taxonomy keys in its own
/// columns), each scored the way the website's cards score them.
library;

import '../marketplace/catalog_models.dart' show formatRupees;

// --- who is looking ----------------------------------------------------------------------------------------------

/// The roles the website's pages open to (`RequireRole`) and `POST /products`, `/services`, `/vendors` accept.
const catalogManagerRoles = ['VENDOR', 'COMPANY_ADMIN', 'SUPER_ADMIN'];

/// The signed-in person, as the catalogue pages judge them: the company they act for (the catalogue is its) and
/// whether their role manages it.
class CatalogViewer {
  const CatalogViewer({required this.role, this.companyId});

  final String role;
  final String? companyId;

  /// Products and services belong to a company; without one the list is never read and every save is refused.
  bool get hasCompany => companyId != null && companyId!.isNotEmpty;

  bool get canManage => catalogManagerRoles.contains(role);
}

// --- the taxonomy --------------------------------------------------------------------------------------------------

/// One node of the two-level tree the pickers offer (`GET /categories/tree?kind=PRODUCT|SERVICE&depth=2`).
class CatalogCategory {
  const CatalogCategory({required this.key, required this.name, this.children = const []});

  final String key;
  final String name;
  final List<CatalogCategory> children;

  static CatalogCategory? fromJson(Map<String, dynamic> json) {
    final key = json['key'];
    if (json['active'] == false || key is! String || key.isEmpty) return null;
    return CatalogCategory(
      key: key,
      name: '${json['name'] ?? key}',
      children: [
        for (final c in json['children'] is List ? json['children'] as List : const [])
          if (c is Map) ?CatalogCategory.fromJson(c.cast<String, dynamic>()),
      ],
    );
  }
}

/// Where a stored key sits in the tree: `(category, subcategory)` keys, or null when the tree does not hold it.
(String, String)? placeInTree(List<CatalogCategory> tops, String key) {
  for (final top in tops) {
    if (top.key == key) return (key, '');
    for (final c in top.children) {
      if (c.key == key) return (top.key, key);
    }
  }
  return null;
}

/// The name of a key at either level; the key itself, prettified, when the tree has no such node.
String categoryLabelOf(List<CatalogCategory> tops, String? key) {
  if (key == null || key.isEmpty) return '';
  for (final top in tops) {
    if (top.key == key) return top.name;
    for (final c in top.children) {
      if (c.key == key) return c.name;
    }
  }
  return prettyKey(key);
}

/// `FACILITY_MANAGEMENT` → `Facility management`.
String prettyKey(String key) {
  final words = key.toLowerCase().split('_').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return key;
  words[0] = words[0][0].toUpperCase() + words[0].substring(1);
  return words.join(' ');
}

// --- what a row shares --------------------------------------------------------------------------------------------

/// The sorts both lists offer (`productModel.sorts`, `ServicesWorkspace.sorts`), in the website's menu order.
enum CatalogSort { recent, name, priceAsc, priceDesc, leastComplete }

String catalogSortLabel(CatalogSort s) => switch (s) {
  CatalogSort.recent => 'Most Recent',
  CatalogSort.name => 'Name (A–Z)',
  CatalogSort.priceAsc => 'Price (Low → High)',
  CatalogSort.priceDesc => 'Price (High → Low)',
  CatalogSort.leastComplete => 'Least Complete First',
};

/// What a product and a service have in common for the list: a name to sort and search on, a price to sort on, a
/// score, and when it was made.
abstract class CatalogRow {
  String get id;
  String get name;
  DateTime? get createdAt;

  /// The figure the price sorts read; null sorts last on "low → high" and on "high → low".
  double? get sortPrice;

  /// 0–100, the share of buyer-facing fields filled in.
  int get score;

  /// Every word a search may match.
  String get searchText;
}

List<T> sortCatalog<T extends CatalogRow>(List<T> rows, CatalogSort sort) {
  final out = [...rows];
  switch (sort) {
    case CatalogSort.name:
      out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case CatalogSort.priceAsc:
      out.sort((a, b) => (a.sortPrice ?? double.infinity).compareTo(b.sortPrice ?? double.infinity));
    case CatalogSort.priceDesc:
      out.sort((a, b) => (b.sortPrice ?? double.negativeInfinity).compareTo(a.sortPrice ?? double.negativeInfinity));
    case CatalogSort.leastComplete:
      out.sort((a, b) => a.score.compareTo(b.score));
    case CatalogSort.recent:
      out.sort(
        (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
          a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
  }
  return out;
}

/// A row's status chip: its words and tone (the website's `success` / `warning` / `default` chip colours).
enum CatalogStatusTone { success, warning, plain }

class CatalogStatus {
  const CatalogStatus(this.label, this.tone);

  final String label;
  final CatalogStatusTone tone;
}

// --- products ----------------------------------------------------------------------------------------------------

/// The six buyer-facing signals a product card is scored on, in the website's checklist order (`productModel`).
/// The photo leads because every product surface shows it first. The supplier's terms (stock, warranty, returns,
/// delivery, bulk pricing) are left out on purpose: they are promises, and nobody should be nudged into one.
enum ProductSignal { photo, name, category, description, price, unit }

String productSignalLabel(ProductSignal s) => switch (s) {
  ProductSignal.photo => 'Photo',
  ProductSignal.name => 'Name',
  ProductSignal.category => 'Category',
  ProductSignal.description => 'Description',
  ProductSignal.price => 'Price',
  ProductSignal.unit => 'Unit',
};

/// "Add photo", the card's words for its one gap (`productModel.addField`).
String productAddFieldLabel(ProductSignal s) => switch (s) {
  ProductSignal.photo => 'Add Photo',
  ProductSignal.name => 'Add Name',
  ProductSignal.category => 'Add Category',
  ProductSignal.description => 'Add Description',
  ProductSignal.price => 'Add Price',
  ProductSignal.unit => 'Add Unit',
};

/// The website's filter buckets (`productModel.filters`). They overlap on purpose: a product with neither photo nor
/// price is in both, because each answers "which of mine are missing X".
enum ProductFilter { all, complete, noPhoto, noPrice, noCategory, incomplete }

String productFilterLabel(ProductFilter f) => switch (f) {
  ProductFilter.all => 'All Products',
  ProductFilter.complete => 'Complete',
  ProductFilter.noPhoto => 'Missing a Photo',
  ProductFilter.noPrice => 'Missing a Price',
  ProductFilter.noCategory => 'Missing a Category',
  ProductFilter.incomplete => 'Anything Missing',
};

/// `ProductAvailability` and its words (`PRODUCT_AVAILABILITY_LABELS`).
const productAvailabilities = ['IN_STOCK', 'MADE_TO_ORDER', 'OUT_OF_STOCK'];

String productAvailabilityLabel(String? value) => switch (value) {
  'IN_STOCK' => 'In Stock',
  'MADE_TO_ORDER' => 'Made to Order',
  'OUT_OF_STOCK' => 'Out of Stock',
  null || '' => 'Not stated',
  _ => prettyKey(value),
};

/// Common selling units (`PRODUCT_UNITS`). Stored in the free-text `unit`, so anything else typed is kept.
const productUnits = ['piece', 'pack', 'box', 'carton', 'set', 'pair', 'kg', 'litre', 'metre', 'roll', 'can', 'drum'];

/// The product's category as the API returns it: the joined `Category` row.
class ProductCategoryRef {
  const ProductCategoryRef({required this.id, required this.name, this.key});

  final String id;
  final String name;
  final String? key;
}

class ProductItem implements CatalogRow {
  const ProductItem({
    required this.id,
    required this.name,
    this.description,
    this.price,
    this.unit,
    this.imageUrl,
    this.imageAsset,
    this.category,
    this.availability,
    this.warrantyMonths,
    this.returnDays,
    this.freeDeliveryOver,
    this.bulkPricingMinQty,
    this.createdAt,
  });

  @override
  final String id;
  @override
  final String name;
  final String? description;

  /// Null when buyers read "Price on request" — nothing, or zero, is "on request" (the supplier profile's rule).
  final double? price;
  final String? unit;

  /// An `/uploads/...` path or an external URL.
  final String? imageUrl;

  /// A bundled picture standing in for the photo (the demo content).
  final String? imageAsset;
  final ProductCategoryRef? category;

  /// `IN_STOCK`, `MADE_TO_ORDER`, `OUT_OF_STOCK`, or null for "not stated".
  final String? availability;
  final int? warrantyMonths;
  final int? returnDays;
  final int? freeDeliveryOver;
  final int? bulkPricingMinQty;
  @override
  final DateTime? createdAt;

  bool get hasPhoto => (imageUrl != null && imageUrl!.isNotEmpty) || imageAsset != null;

  List<ProductSignal> get missing => [
    if (!hasPhoto) ProductSignal.photo,
    if (name.trim().isEmpty) ProductSignal.name,
    if (category == null) ProductSignal.category,
    if ((description ?? '').trim().isEmpty) ProductSignal.description,
    if (price == null) ProductSignal.price,
    if ((unit ?? '').trim().isEmpty) ProductSignal.unit,
  ];

  @override
  int get score => ((ProductSignal.values.length - missing.length) / ProductSignal.values.length * 100).round();

  @override
  double? get sortPrice => price;

  @override
  String get searchText => '$name ${description ?? ''} ${category?.name ?? ''} ${unit ?? ''}'.toLowerCase();

  /// "₹1,299 / piece" — the shape the supplier profile shows buyers; null for "Price on request".
  String? get priceLabel => formatProductPrice(price, unit);

  /// The one status the card shows: the gap that costs the most, else complete (`productModel.statusOf`).
  CatalogStatus get status {
    if (!hasPhoto) return const CatalogStatus('No Photo', CatalogStatusTone.warning);
    if (price == null) return const CatalogStatus('Price on Request', CatalogStatusTone.plain);
    final gaps = missing;
    if (gaps.isEmpty) return const CatalogStatus('Complete', CatalogStatusTone.success);
    return CatalogStatus(
      gaps.length == 1 ? productAddFieldLabel(gaps.first) : 'Add ${gaps.length} Details',
      CatalogStatusTone.warning,
    );
  }

  bool matches(ProductFilter f) => switch (f) {
    ProductFilter.all => true,
    ProductFilter.complete => score == 100,
    ProductFilter.noPhoto => !hasPhoto,
    ProductFilter.noPrice => price == null,
    ProductFilter.noCategory => category == null,
    ProductFilter.incomplete => score < 100,
  };

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    return ProductItem(
      id: '${json['id']}',
      name: '${json['name'] ?? ''}',
      description: _text(json['description']),
      price: priceOf(json['price']),
      unit: _text(json['unit']),
      imageUrl: _text(json['imageUrl']),
      category: category is Map
          ? ProductCategoryRef(id: '${category['id']}', name: '${category['name'] ?? ''}', key: _text(category['key']))
          : null,
      availability: _text(json['availability']),
      warrantyMonths: _int(json['warrantyMonths']),
      returnDays: _int(json['returnDays']),
      freeDeliveryOver: _int(json['freeDeliveryOver']),
      bulkPricingMinQty: _int(json['bulkPricingMinQty']),
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
    );
  }

  /// The price as a number, or null when buyers will read "Price on request" (`productModel.priceOf`).
  static double? priceOf(Object? raw) {
    if (raw == null) return null;
    final n = raw is num ? raw.toDouble() : double.tryParse('$raw'.trim());
    return n != null && n.isFinite && n > 0 ? n : null;
  }
}

/// "₹1,450.50" for paise, "₹1,450" for a whole-rupee price, "/ unit" when the product has one.
String? formatProductPrice(double? price, String? unit) {
  if (price == null) return null;
  final amount = formatRupees(price);
  return unit != null && unit.trim().isNotEmpty ? '$amount / ${unit.trim()}' : amount;
}

// --- the supplier's terms (`product-terms.ts`) ------------------------------------------------------------------------

enum ProductTerm { warrantyMonths, returnDays, freeDeliveryOver, bulkPricingMinQty }

/// `PRODUCT_TERM_LIMITS`: warranty in months, returns in days, free delivery over whole rupees (0 = always free),
/// bulk pricing from a quantity in the product's unit (from one is just the price).
const productTermLimits = <ProductTerm, (int, int)>{
  ProductTerm.warrantyMonths: (1, 120),
  ProductTerm.returnDays: (1, 365),
  ProductTerm.freeDeliveryOver: (0, 10000000),
  ProductTerm.bulkPricingMinQty: (2, 1000000),
};

/// Why a typed term cannot be saved, or null when it can. Blank is always fine: it clears the term.
String? productTermError(ProductTerm term, String raw) {
  final v = raw.trim();
  if (v.isEmpty) return null;
  if (!RegExp(r'^\d+$').hasMatch(v)) return 'Enter a whole number.';
  final (min, max) = productTermLimits[term]!;
  final n = int.parse(v);
  if (n < min || n > max) {
    String fmt(int x) => '${term == ProductTerm.freeDeliveryOver ? '₹' : ''}${groupIndian(x)}';
    return 'Enter a value between ${fmt(min)} and ${fmt(max)}.';
  }
  return null;
}

/// "12 months" reads as "1-year"; anything that is not whole years stays in months.
String warrantyLabel(int months) => months % 12 == 0 ? '${months ~/ 12}-year warranty' : '$months-month warranty';

String returnsLabel(int days) => '$days-day returns';

String freeDeliveryLabel(int over) => over == 0 ? 'Free delivery' : 'Free delivery over ₹${groupIndian(over)}';

/// "Bulk pricing from 50 box" — B2B catalogues state a quantity in its unit, unpluralised.
String bulkPricingLabel(int minQty, String? unit) {
  final u = (unit ?? '').trim();
  return u.isEmpty ? 'Bulk pricing from ${groupIndian(minQty)} units' : 'Bulk pricing from ${groupIndian(minQty)} $u';
}

/// What a term reads as on the product page once it holds [raw]: "Buyers see “…”", or null for a blank or
/// invalid value.
String? productTermSentence(ProductTerm term, String raw, String unit) {
  final v = raw.trim();
  if (v.isEmpty || productTermError(term, raw) != null) return null;
  final n = int.parse(v);
  return switch (term) {
    ProductTerm.warrantyMonths => warrantyLabel(n),
    ProductTerm.returnDays => returnsLabel(n),
    ProductTerm.freeDeliveryOver => freeDeliveryLabel(n),
    ProductTerm.bulkPricingMinQty => bulkPricingLabel(n, unit),
  };
}

/// Whole numbers with Indian grouping: 10000000 → "1,00,00,000" (what `toLocaleString('en-IN')` prints).
String groupIndian(int n) {
  final digits = n.abs().toString();
  if (digits.length <= 3) return n < 0 ? '-$digits' : digits;
  final tail = digits.substring(digits.length - 3);
  var head = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (head.length > 2) {
    groups.insert(0, head.substring(head.length - 2));
    head = head.substring(0, head.length - 2);
  }
  if (head.isNotEmpty) groups.insert(0, head);
  return '${n < 0 ? '-' : ''}${groups.join(',')},$tail';
}

// --- the product form ---------------------------------------------------------------------------------------------

/// What the product editor holds, as typed (`ProductSlideOver`'s `ProductDraft`). Blank is "not stated".
class ProductDraft {
  const ProductDraft({
    this.name = '',
    this.category = '',
    this.subcategory = '',
    this.description = '',
    this.price = '',
    this.unit = '',
    this.imageUrl = '',
    this.availability = '',
    this.warrantyMonths = '',
    this.returnDays = '',
    this.freeDeliveryOver = '',
    this.bulkPricingMinQty = '',
  });

  final String name;

  /// Taxonomy level 1 — navigation unless no level 2 is picked.
  final String category;

  /// Taxonomy level 2.
  final String subcategory;
  final String description;
  final String price;
  final String unit;
  final String imageUrl;

  /// A `ProductAvailability`, or '' for "not stated".
  final String availability;
  final String warrantyMonths;
  final String returnDays;
  final String freeDeliveryOver;
  final String bulkPricingMinQty;

  /// The most specific level picked — a product stores one key, at whichever level.
  String get leaf => subcategory.isNotEmpty ? subcategory : category;

  List<Object?> get _fields => [
    name,
    category,
    subcategory,
    description,
    price,
    unit,
    imageUrl,
    availability,
    warrantyMonths,
    returnDays,
    freeDeliveryOver,
    bulkPricingMinQty,
  ];

  @override
  bool operator ==(Object other) => other is ProductDraft && _same(_fields, other._fields);

  @override
  int get hashCode => Object.hashAll(_fields);

  String term(ProductTerm t) => switch (t) {
    ProductTerm.warrantyMonths => warrantyMonths,
    ProductTerm.returnDays => returnDays,
    ProductTerm.freeDeliveryOver => freeDeliveryOver,
    ProductTerm.bulkPricingMinQty => bulkPricingMinQty,
  };

  /// `Decimal(12,2)`: up to ten digits before the point, two after, above zero.
  bool get priceInvalid {
    final v = price.trim();
    if (v.isEmpty) return false;
    return !RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(v) || double.parse(v) <= 0;
  }

  bool get termsInvalid => ProductTerm.values.any((t) => productTermError(t, term(t)) != null);

  ProductDraft copyWith({
    String? name,
    String? category,
    String? subcategory,
    String? description,
    String? price,
    String? unit,
    String? imageUrl,
    String? availability,
    String? warrantyMonths,
    String? returnDays,
    String? freeDeliveryOver,
    String? bulkPricingMinQty,
  }) => ProductDraft(
    name: name ?? this.name,
    category: category ?? this.category,
    subcategory: subcategory ?? this.subcategory,
    description: description ?? this.description,
    price: price ?? this.price,
    unit: unit ?? this.unit,
    imageUrl: imageUrl ?? this.imageUrl,
    availability: availability ?? this.availability,
    warrantyMonths: warrantyMonths ?? this.warrantyMonths,
    returnDays: returnDays ?? this.returnDays,
    freeDeliveryOver: freeDeliveryOver ?? this.freeDeliveryOver,
    bulkPricingMinQty: bulkPricingMinQty ?? this.bulkPricingMinQty,
  );

  ProductDraft withTerm(ProductTerm t, String value) => switch (t) {
    ProductTerm.warrantyMonths => copyWith(warrantyMonths: value),
    ProductTerm.returnDays => copyWith(returnDays: value),
    ProductTerm.freeDeliveryOver => copyWith(freeDeliveryOver: value),
    ProductTerm.bulkPricingMinQty => copyWith(bulkPricingMinQty: value),
  };

  /// The editor's draft for [p], its category placed in [tops] (an unplaced key leaves both boxes blank and is
  /// kept unless another is picked).
  factory ProductDraft.of(ProductItem p, List<CatalogCategory> tops) {
    final placed = p.category?.key == null ? null : placeInTree(tops, p.category!.key!);
    return ProductDraft(
      name: p.name,
      category: placed?.$1 ?? '',
      subcategory: placed?.$2 ?? '',
      description: p.description ?? '',
      price: p.price == null ? '' : _plain(p.price!),
      unit: p.unit ?? '',
      imageUrl: p.imageUrl ?? '',
      availability: p.availability ?? '',
      warrantyMonths: p.warrantyMonths?.toString() ?? '',
      returnDays: p.returnDays?.toString() ?? '',
      freeDeliveryOver: p.freeDeliveryOver?.toString() ?? '',
      bulkPricingMinQty: p.bulkPricingMinQty?.toString() ?? '',
    );
  }

  /// The draft scored as the cards score a product, so the checklist reads the same six signals.
  ProductItem get asItem => ProductItem(
    id: 'draft',
    name: name,
    description: description,
    price: priceInvalid ? null : ProductItem.priceOf(price.trim()),
    unit: unit,
    imageUrl: imageUrl.isEmpty ? null : imageUrl,
    category: leaf.isEmpty ? null : ProductCategoryRef(id: leaf, name: leaf, key: leaf),
    availability: availability.isEmpty ? null : availability,
  );

  /// The request body, as the website's `payloadFrom` builds it. A new product leaves a blank field out; an edit
  /// sends every field so that clearing one clears it (`null`), and sends the category only when it was changed —
  /// a product filed under a key this tree does not show would otherwise lose it on any save.
  Map<String, Object?> payload({required bool editing, required bool categoryChanged}) {
    Object? text(String v) => v.trim().isNotEmpty ? v.trim() : (editing ? null : _absent);
    final priceValue = price.trim().isEmpty ? null : double.parse(price.trim());
    final body = <String, Object?>{
      'name': name.trim(),
      'description': text(description),
      'price': priceValue ?? (editing ? null : _absent),
      'unit': text(unit),
      'imageUrl': imageUrl.isNotEmpty ? imageUrl : (editing ? null : _absent),
      'availability': availability.isNotEmpty ? availability : (editing ? null : _absent),
    };
    for (final t in ProductTerm.values) {
      final v = term(t).trim();
      body[t.name] = v.isEmpty ? (editing ? null : _absent) : int.parse(v);
    }
    // An empty key clears the category server-side; the column is nullable.
    if (editing ? categoryChanged : leaf.isNotEmpty) body['categoryKey'] = leaf;
    body.removeWhere((_, v) => identical(v, _absent));
    return body;
  }

  /// The body of a copy (`handleDuplicate`): the copy's name, and only what the original holds.
  static Map<String, Object?> duplicateOf(ProductItem p) => {
    'name': '${p.name.isEmpty ? 'Product' : p.name} (copy)',
    'description': ?p.description,
    'price': ?p.price,
    'unit': ?p.unit,
    'imageUrl': ?p.imageUrl,
    'categoryKey': ?p.category?.key,
  };
}

/// A field a new item leaves out of its body (the website's `undefined`).
const _absent = Object();

bool _same(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// 499.5 → "499.5", 1200.0 → "1200".
String _plain(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

// --- services ----------------------------------------------------------------------------------------------------

/// The seven signals a service listing is scored on (`serviceModel`). A service filed only at category level is
/// less findable — buyers filter and RFQs match at the sub-category — so a legacy row scores 6/7 until edited.
enum ServiceSignal { name, category, subcategory, description, rate, rateUnit, turnaroundTime }

String serviceSignalLabel(ServiceSignal s) => switch (s) {
  ServiceSignal.name => 'Name',
  ServiceSignal.category => 'Category',
  ServiceSignal.subcategory => 'Sub-Category',
  ServiceSignal.description => 'Description',
  ServiceSignal.rate => 'Starting Price',
  ServiceSignal.rateUnit => 'Pricing Model',
  ServiceSignal.turnaroundTime => 'Turnaround Time',
};

/// The card's words for its one gap (`ServiceCard.addField`).
String serviceAddFieldLabel(ServiceSignal s) => switch (s) {
  ServiceSignal.name => 'Add Name',
  ServiceSignal.category => 'Add Category',
  ServiceSignal.subcategory => 'Add Sub-Category',
  ServiceSignal.description => 'Add Description',
  ServiceSignal.rate => 'Add Starting Price',
  ServiceSignal.rateUnit => 'Add Pricing Model',
  ServiceSignal.turnaroundTime => 'Add Turnaround Time',
};

/// The website's status filter (`ServicesWorkspace.statuses`), computed from completeness — no invented states.
enum ServiceHealth { all, optimized, improve, noPrice }

String serviceHealthLabel(ServiceHealth h) => switch (h) {
  ServiceHealth.all => 'All Statuses',
  ServiceHealth.optimized => 'Optimized',
  ServiceHealth.improve => 'Needs Details',
  ServiceHealth.noPrice => 'No Price',
};

/// Common pricing models (`PRICING_MODELS`). Persisted to the free-text `rateUnit`.
const pricingModels = ['per visit', 'per sqft', 'per hour', 'per month', 'per year', 'per project', 'per unit'];

class ServiceItem implements CatalogRow {
  const ServiceItem({
    required this.id,
    required this.name,
    required this.category,
    this.subcategory,
    this.description,
    this.rate,
    this.rateUnit,
    this.turnaroundTime,
    this.createdAt,
  });

  @override
  final String id;
  @override
  final String name;

  /// Taxonomy level 1.
  final String category;

  /// Taxonomy level 2 — what a buyer actually searches on.
  final String? subcategory;
  final String? description;
  final double? rate;
  final String? rateUnit;
  final String? turnaroundTime;
  @override
  final DateTime? createdAt;

  /// The key a service is best identified by: the specific one, falling back to its parent.
  String? get categoryKey => (subcategory ?? '').isNotEmpty ? subcategory : (category.isEmpty ? null : category);

  List<ServiceSignal> get missing => [
    if (name.trim().isEmpty) ServiceSignal.name,
    if (category.trim().isEmpty) ServiceSignal.category,
    if ((subcategory ?? '').trim().isEmpty) ServiceSignal.subcategory,
    if ((description ?? '').trim().isEmpty) ServiceSignal.description,
    if (rate == null) ServiceSignal.rate,
    if ((rateUnit ?? '').trim().isEmpty) ServiceSignal.rateUnit,
    if ((turnaroundTime ?? '').trim().isEmpty) ServiceSignal.turnaroundTime,
  ];

  @override
  int get score => ((ServiceSignal.values.length - missing.length) / ServiceSignal.values.length * 100).round();

  @override
  double? get sortPrice => rate;

  @override
  String get searchText => '$name ${description ?? ''} $category ${subcategory ?? ''}'.toLowerCase();

  ServiceHealth get health {
    if (rate == null) return ServiceHealth.noPrice;
    return score >= 100 ? ServiceHealth.optimized : ServiceHealth.improve;
  }

  /// "₹5,000 per visit"; null when no price is set.
  String? get priceLabel => formatServicePrice(rate, rateUnit);

  /// The chip the card shows: the gap itself ("Add pricing model"), or "Optimized" once nothing is missing.
  CatalogStatus get status {
    final gaps = missing;
    if (gaps.isEmpty) return const CatalogStatus('Optimized', CatalogStatusTone.success);
    return CatalogStatus(
      gaps.length == 1 ? serviceAddFieldLabel(gaps.first) : 'Add ${gaps.length} Details',
      health == ServiceHealth.noPrice ? CatalogStatusTone.plain : CatalogStatusTone.warning,
    );
  }

  factory ServiceItem.fromJson(Map<String, dynamic> json) => ServiceItem(
    id: '${json['id']}',
    name: '${json['name'] ?? ''}',
    category: '${json['category'] ?? ''}',
    subcategory: _text(json['subcategory']),
    description: _text(json['description']),
    rate: json['rate'] is num ? (json['rate'] as num).toDouble() : double.tryParse('${json['rate'] ?? ''}'),
    rateUnit: _text(json['rateUnit']),
    turnaroundTime: _text(json['turnaroundTime']),
    createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
  );
}

String? formatServicePrice(double? rate, String? unit) {
  if (rate == null) return null;
  final amount = formatRupees(rate);
  return unit != null && unit.trim().isNotEmpty ? '$amount ${unit.trim()}' : amount;
}

/// What the service editor holds (`ServiceSlideOver`'s `ServiceDraft`).
class ServiceDraft {
  const ServiceDraft({
    this.name = '',
    this.category = '',
    this.subcategory = '',
    this.description = '',
    this.rate = '',
    this.rateUnit = '',
    this.turnaroundTime = '',
    this.addToListing = true,
  });

  final String name;

  /// Taxonomy level 1.
  final String category;

  /// Taxonomy level 2, a child of [category]. Optional — blank offers the whole category.
  final String subcategory;
  final String description;
  final String rate;
  final String rateUnit;
  final String turnaroundTime;

  /// On a new service only: also add its sub-category (else its category) to the company's listing.
  final bool addToListing;

  bool get rateInvalid => rate.trim().isNotEmpty && double.tryParse(rate.trim()) == null;

  List<Object?> get _fields => [name, category, subcategory, description, rate, rateUnit, turnaroundTime, addToListing];

  @override
  bool operator ==(Object other) => other is ServiceDraft && _same(_fields, other._fields);

  @override
  int get hashCode => Object.hashAll(_fields);

  ServiceDraft copyWith({
    String? name,
    String? category,
    String? subcategory,
    String? description,
    String? rate,
    String? rateUnit,
    String? turnaroundTime,
    bool? addToListing,
  }) => ServiceDraft(
    name: name ?? this.name,
    category: category ?? this.category,
    subcategory: subcategory ?? this.subcategory,
    description: description ?? this.description,
    rate: rate ?? this.rate,
    rateUnit: rateUnit ?? this.rateUnit,
    turnaroundTime: turnaroundTime ?? this.turnaroundTime,
    addToListing: addToListing ?? this.addToListing,
  );

  factory ServiceDraft.of(ServiceItem s) => ServiceDraft(
    name: s.name,
    category: s.category,
    subcategory: s.subcategory ?? '',
    description: s.description ?? '',
    rate: s.rate == null ? '' : _plain(s.rate!),
    rateUnit: s.rateUnit ?? '',
    turnaroundTime: s.turnaroundTime ?? '',
  );

  /// The body the website's `handleSave` sends. On an edit, null clears an optional field that was set (left out,
  /// the API keeps the old value); a new service just leaves blanks out.
  Map<String, Object?> payload({required bool editing}) {
    Object? blank() => editing ? null : _absent;
    final body = <String, Object?>{
      'name': name.trim(),
      'category': category,
      'subcategory': subcategory.isNotEmpty ? subcategory : blank(),
      'description': description.isNotEmpty ? description : blank(),
      'rate': rate.trim().isEmpty ? blank() : double.parse(rate.trim()),
      'rateUnit': rateUnit.isNotEmpty ? rateUnit : blank(),
      'turnaroundTime': turnaroundTime.isNotEmpty ? turnaroundTime : blank(),
    };
    body.removeWhere((_, v) => identical(v, _absent));
    return body;
  }

  /// The body of a copy (`handleDuplicate`).
  static Map<String, Object?> duplicateOf(ServiceItem s) => {
    'name': '${s.name.isEmpty ? 'Service' : s.name} (copy)',
    'category': s.category,
    'subcategory': ?s.subcategory,
    'description': ?s.description,
    'rate': ?s.rate,
    'rateUnit': ?s.rateUnit,
    'turnaroundTime': ?s.turnaroundTime,
  };
}

// --- the supplier listing ------------------------------------------------------------------------------------------

/// Whether the company sells on ICR yet (`GET /vendors/me/access`): the listing every bid, reply and Supplier Mart
/// entry is filed under. `vendorId` null means the company has none.
class SupplierAccess {
  const SupplierAccess({this.vendorId, this.verified = false});

  final String? vendorId;
  final bool verified;

  bool get hasListing => vendorId != null && vendorId!.isNotEmpty;

  factory SupplierAccess.fromJson(Map<String, dynamic> json) =>
      SupplierAccess(vendorId: _text(json['vendorId']), verified: json['verified'] == true);
}

String? _text(Object? v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
