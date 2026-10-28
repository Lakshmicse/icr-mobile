import 'marketplace_models.dart';

/// The orders the Sort sheet offers. The API always puts paid placement and
/// higher trust first, then this.
enum SupplierSort {
  recommended('Recommended', null),
  topRated('Top rated', 'rating'),
  mostReviewed('Most reviewed', 'ratingCount'),
  mostProjects('Most projects', 'projectsCompleted'),
  mostExperienced('Most experienced', 'yearsExperience'),
  newest('Newest', 'createdAt');

  const SupplierSort(this.label, this.sortBy);

  final String label;
  final String? sortBy;
}

/// The minimum ratings the "By ratings" sheet offers.
const ratingSteps = <double>[4.5, 4, 3.5, 3];

String ratingStepLabel(double v) => '${v == v.roundToDouble() ? v.toInt() : v}★ & up';

/// Company sizes the API filters on (`COMPANY_SIZES`).
const companySizes = <String>['1-10', '11-50', '51-200', '201-500', '500+'];

/// The Marketplace's search, filters and order, as the website's Supplier Mart
/// keeps them (`vendorFilters.ts`): the mart opens on verified suppliers.
class MarketplaceFilters {
  const MarketplaceFilters({
    this.search = '',
    this.categories = const {},
    this.city,
    this.minLevel = SupplierLevel.verified,
    this.minRating,
    this.sizes = const {},
    this.gst = false,
    this.msme = false,
    this.sort = SupplierSort.topRated,
    this.savedOnly = false,
  });

  final String search;
  final Set<String> categories;
  final String? city;

  /// The trust ladder from this rung up; null for every supplier.
  final SupplierLevel? minLevel;
  final double? minRating;
  final Set<String> sizes;
  final bool gst;
  final bool msme;
  final SupplierSort sort;

  /// Only the suppliers the member bookmarked (`GET /vendors/saved`).
  final bool savedOnly;

  /// "Verified only": the trust ladder from Verified up.
  bool get verifiedOnly => minLevel != null && minLevel!.isVerified;

  /// The number on "Filters (N)": what the Filters sheet sets. The rating and
  /// "Verified only" have chips of their own, so a level counts here only
  /// when it asks for more than Verified.
  int get sheetCount =>
      categories.length +
      (city != null ? 1 : 0) +
      sizes.length +
      (gst ? 1 : 0) +
      (msme ? 1 : 0) +
      (minLevel != null && minLevel!.index > SupplierLevel.verified.index ? 1 : 0) +
      (savedOnly ? 1 : 0);

  /// Anything that narrows the list beyond the default (the order does not).
  bool get narrows => search.isNotEmpty || sheetCount > 0 || minRating != null || !verifiedOnly;

  MarketplaceFilters copyWith({
    String? search,
    Set<String>? categories,
    String? city,
    bool clearCity = false,
    SupplierLevel? minLevel,
    bool clearLevel = false,
    double? minRating,
    bool clearRating = false,
    Set<String>? sizes,
    bool? gst,
    bool? msme,
    SupplierSort? sort,
    bool? savedOnly,
  }) => MarketplaceFilters(
    search: search ?? this.search,
    categories: categories ?? this.categories,
    city: clearCity ? null : (city ?? this.city),
    minLevel: clearLevel ? null : (minLevel ?? this.minLevel),
    minRating: clearRating ? null : (minRating ?? this.minRating),
    sizes: sizes ?? this.sizes,
    gst: gst ?? this.gst,
    msme: msme ?? this.msme,
    sort: sort ?? this.sort,
    savedOnly: savedOnly ?? this.savedOnly,
  );

  /// The sheet's filters cleared; the search, the order, the rating and
  /// "Verified only" stay.
  MarketplaceFilters clearedSheet() => MarketplaceFilters(
    search: search,
    sort: sort,
    minRating: minRating,
    minLevel: verifiedOnly ? SupplierLevel.verified : null,
  );

  /// The `GET /vendors` query.
  Map<String, dynamic> query({int page = 1, int limit = 10}) => {
    'page': page,
    'limit': limit,
    if (search.isNotEmpty) 'search': search,
    if (categories.isNotEmpty) 'categories': categories.join(','),
    'city': ?city,
    if (minLevel != null) 'minVerificationLevel': minLevel!.api,
    'minRating': ?minRating,
    if (sizes.isNotEmpty) 'size': sizes.join(','),
    if (gst) 'gst': 'true',
    if (msme) 'msme': 'true',
    if (sort.sortBy != null) ...{'sortBy': sort.sortBy, 'sortDir': 'desc'},
  };

  @override
  bool operator ==(Object other) =>
      other is MarketplaceFilters &&
      other.search == search &&
      _sameSet(other.categories, categories) &&
      other.city == city &&
      other.minLevel == minLevel &&
      other.minRating == minRating &&
      _sameSet(other.sizes, sizes) &&
      other.gst == gst &&
      other.msme == msme &&
      other.sort == sort &&
      other.savedOnly == savedOnly;

  @override
  int get hashCode => Object.hash(
    search,
    Object.hashAllUnordered(categories),
    city,
    minLevel,
    minRating,
    Object.hashAllUnordered(sizes),
    gst,
    msme,
    sort,
    savedOnly,
  );
}

bool _sameSet(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);

/// A page of suppliers.
class SupplierPage {
  const SupplierPage({required this.suppliers, required this.total, required this.page, required this.hasMore});

  final List<Supplier> suppliers;
  final int total;
  final int page;
  final bool hasMore;
}
