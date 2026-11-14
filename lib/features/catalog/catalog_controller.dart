import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'catalog_models.dart';
import 'catalog_repository.dart';

/// What My Products and My Services share on screen: whether the company sells yet, the taxonomy the pickers and
/// the chips read, the plan's listing places, the rows with the website's search, sort and category filter, and
/// the writes — each sent to the API, then the list read again (the website invalidates its whole query the same
/// way). A refusal comes back as the API's own sentence: to a sheet, which keeps what was typed and shows it, or
/// to [actionError] above the list for a row's own button.
abstract class CatalogController<T extends CatalogRow> extends ChangeNotifier {
  CatalogController({required this.repository, required this.viewer});

  final CatalogRepository repository;
  final CatalogViewer viewer;

  /// `PRODUCT` or `SERVICE`: which tree the pickers offer.
  String get categoryKind;

  List<T> rows = const [];
  List<CatalogCategory> categories = const [];
  SupplierAccess? access;

  /// How many listing places the plan allows, products and services together; null when it sets no number.
  int? listingLimit;

  /// The other half of the catalogue's count, for "x of y listing places used" (both halves share the places).
  int otherCount = 0;

  bool loading = true;
  bool loaded = false;
  String? loadError;
  String? actionError;

  /// Rows a write is on its way for.
  final Set<String> busyIds = {};
  bool saving = false;
  bool startingToSell = false;

  String search = '';
  CatalogSort sort = CatalogSort.recent;

  /// A category key (products: the joined category's id) the list is narrowed to; '' for all.
  String activeCategory = '';

  bool _disposed = false;
  int _generation = 0;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Whether the company has a supplier listing; true until the access read says otherwise, so the notice never
  /// flashes for a company that sells.
  bool get hasListing => access?.hasListing ?? true;

  // --- reading -----------------------------------------------------------------------------------------------

  Future<List<T>> readRows(String companyId);

  Future<int> readOtherCount(String companyId);

  Future<void> start() => load();

  /// Reads everything. [refresh] keeps what is on screen while it loads (pull to refresh, after a write).
  Future<void> load({bool refresh = false}) async {
    if (!viewer.hasCompany || !viewer.canManage) {
      loading = false;
      _notify();
      return;
    }
    final generation = ++_generation;
    if (!refresh) {
      loading = true;
      loadError = null;
      _notify();
    }
    final companyId = viewer.companyId!;
    try {
      final results = await Future.wait<Object?>([
        readRows(companyId),
        // Each of these only decorates the page: a company with no listing, a tree that fails, a plan with no
        // number still has a catalogue to show.
        repository.access().then<SupplierAccess?>((a) => a).catchError((Object _) => null),
        repository.categories(categoryKind).catchError((Object _) => const <CatalogCategory>[]),
        repository.listingLimit().catchError((Object _) => null),
        readOtherCount(companyId).catchError((Object _) => 0),
      ]);
      if (generation != _generation) return;
      rows = results[0] as List<T>;
      access = (results[1] as SupplierAccess?) ?? access;
      categories = results[2] as List<CatalogCategory>;
      listingLimit = results[3] as int?;
      otherCount = results[4] as int;
      loaded = true;
      loadError = null;
    } catch (e) {
      if (generation != _generation) return;
      final message = ApiError.from(e).message;
      if (!loaded || !refresh) {
        loadError = message;
      } else {
        actionError = message;
      }
    } finally {
      if (generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  void dismissError() {
    if (actionError == null) return;
    actionError = null;
    _notify();
  }

  // --- the list on screen -------------------------------------------------------------------------------------

  void setSearch(String value) {
    if (value == search) return;
    search = value;
    _notify();
  }

  void setSort(CatalogSort value) {
    if (value == sort) return;
    sort = value;
    _notify();
  }

  void setCategory(String key) {
    if (key == activeCategory) return;
    activeCategory = key;
    _notify();
  }

  /// The key the category chips group a row by ('' for none).
  String categoryKeyOf(T row);

  /// Whether a row passes the kind's own status filter.
  bool passesFilter(T row);

  bool get hasFilters => search.trim().isNotEmpty || activeCategory.isNotEmpty || filterOn;

  bool get filterOn;

  void clearFilters() {
    search = '';
    activeCategory = '';
    resetFilter();
    _notify();
  }

  void resetFilter();

  /// The category chips: key, its name and how many rows sit under it, most first (the website's order).
  List<(String, String, int)> get categoryChips {
    final counts = <String, int>{};
    final names = <String, String>{};
    for (final r in rows) {
      final key = categoryKeyOf(r);
      counts[key] = (counts[key] ?? 0) + 1;
      names[key] = categoryNameOf(r);
    }
    final chips = [for (final e in counts.entries) (e.key, names[e.key]!, e.value)];
    chips.sort((a, b) => b.$3.compareTo(a.$3));
    return chips;
  }

  String categoryNameOf(T row);

  List<T> get shown {
    final q = search.trim().toLowerCase();
    final kept = [
      for (final r in rows)
        if ((activeCategory.isEmpty || categoryKeyOf(r) == activeCategory) &&
            passesFilter(r) &&
            (q.isEmpty || r.searchText.contains(q) || categoryNameOf(r).toLowerCase().contains(q)))
          r,
    ];
    return sortCatalog(kept, sort);
  }

  /// Average listing strength across every row, 0 with none.
  int get strength => rows.isEmpty ? 0 : (rows.fold<int>(0, (a, r) => a + r.score) / rows.length).round();

  int get categoryCount => {
    for (final r in rows)
      if (categoryKeyOf(r).isNotEmpty) categoryKeyOf(r),
  }.length;

  /// "x of y listing places used": both halves of the catalogue count against the plan's number.
  int get placesUsed => rows.length + otherCount;

  bool get placesFull => listingLimit != null && placesUsed >= listingLimit!;

  // --- writes ------------------------------------------------------------------------------------------------

  Future<void> deleteRow(String id);

  /// Deletes one row. Returns the API's refusal, or null.
  Future<String?> delete(T row) async {
    busyIds.add(row.id);
    _notify();
    try {
      await deleteRow(row.id);
      rows = [
        for (final r in rows)
          if (r.id != row.id) r,
      ];
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      busyIds.remove(row.id);
      _notify();
    }
  }

  /// Deletes every row named, each on its own (the website's `Promise.allSettled`). Returns how many could not be.
  Future<int> deleteMany(Iterable<String> ids) async {
    final wanted = ids.toSet();
    busyIds.addAll(wanted);
    _notify();
    var failed = 0;
    final gone = <String>{};
    Future<void> one(String id) async {
      try {
        await deleteRow(id);
        gone.add(id);
      } catch (_) {
        failed += 1;
      }
    }

    await Future.wait([for (final id in wanted) one(id)]);
    rows = [
      for (final r in rows)
        if (!gone.contains(r.id)) r,
    ];
    busyIds.removeAll(wanted);
    _notify();
    return failed;
  }

  /// Runs one write, then reads the list again so the row is as the API stored it. Returns the refusal, or null.
  Future<String?> write(Future<void> Function() action) async {
    saving = true;
    _notify();
    try {
      await action();
      await load(refresh: true);
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      saving = false;
      _notify();
    }
  }

  /// "Start selling": creates the company's supplier listing in place. Returns the API's refusal, or null.
  Future<String?> startSelling() async {
    final companyId = viewer.companyId;
    if (companyId == null) return 'Ask your company’s admin to start selling on ICR.';
    startingToSell = true;
    _notify();
    try {
      await repository.startSelling(companyId);
      access = const SupplierAccess(vendorId: 'new', verified: false);
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      startingToSell = false;
      _notify();
    }
  }
}

/// My Products: the company's products, with the website's completeness filter and its "Worth finishing" counts.
class ProductsController extends CatalogController<ProductItem> {
  ProductsController({required super.repository, required super.viewer});

  ProductFilter filter = ProductFilter.all;

  @override
  String get categoryKind => 'PRODUCT';

  @override
  Future<List<ProductItem>> readRows(String companyId) => repository.products(companyId);

  @override
  Future<int> readOtherCount(String companyId) async => (await repository.services(companyId)).length;

  @override
  String categoryKeyOf(ProductItem row) => row.category?.id ?? '';

  @override
  String categoryNameOf(ProductItem row) => row.category?.name ?? 'No Category';

  @override
  bool passesFilter(ProductItem row) => row.matches(filter);

  @override
  bool get filterOn => filter != ProductFilter.all;

  @override
  void resetFilter() => filter = ProductFilter.all;

  void setFilter(ProductFilter value) {
    filter = filter == value ? ProductFilter.all : value;
    notifyListeners();
  }

  int get withPhoto => rows.where((p) => p.hasPhoto).length;
  int get withoutPhoto => rows.length - withPhoto;
  int get withoutPrice => rows.where((p) => p.price == null).length;
  int get withoutCategory => rows.where((p) => p.category == null).length;

  @override
  Future<void> deleteRow(String id) => repository.deleteProduct(id);

  /// Saves the editor's draft: a new product (`POST`, with the company) or changes to [editing] (`PATCH`).
  Future<String?> save(ProductDraft draft, {ProductItem? editing, bool categoryChanged = false}) {
    final body = draft.payload(editing: editing != null, categoryChanged: categoryChanged);
    return write(
      () => editing == null
          ? repository.createProduct({...body, 'companyId': viewer.companyId})
          : repository.updateProduct(editing.id, body),
    );
  }

  Future<String?> duplicate(ProductItem p) =>
      write(() => repository.createProduct({'companyId': viewer.companyId, ...ProductDraft.duplicateOf(p)}));
}

/// My Services: the company's services, with the website's status filter.
class ServicesController extends CatalogController<ServiceItem> {
  ServicesController({required super.repository, required super.viewer});

  ServiceHealth status = ServiceHealth.all;

  @override
  String get categoryKind => 'SERVICE';

  @override
  Future<List<ServiceItem>> readRows(String companyId) => repository.services(companyId);

  @override
  Future<int> readOtherCount(String companyId) async => (await repository.products(companyId)).length;

  @override
  String categoryKeyOf(ServiceItem row) => row.categoryKey ?? '';

  @override
  String categoryNameOf(ServiceItem row) {
    final key = row.categoryKey;
    return key == null ? 'Uncategorized' : categoryLabelOf(categories, key);
  }

  /// A key at either level, named by the tree.
  String labelOf(String? key) => categoryLabelOf(categories, key);

  @override
  bool passesFilter(ServiceItem row) => status == ServiceHealth.all || row.health == status;

  @override
  bool get filterOn => status != ServiceHealth.all;

  @override
  void resetFilter() => status = ServiceHealth.all;

  void setStatus(ServiceHealth value) {
    status = value;
    notifyListeners();
  }

  /// The average starting price over the priced services; null with none.
  int? get averagePrice {
    final priced = rows.where((s) => s.rate != null).toList();
    if (priced.isEmpty) return null;
    return (priced.fold<double>(0, (a, s) => a + s.rate!) / priced.length).round();
  }

  int get withTurnaround => rows.where((s) => (s.turnaroundTime ?? '').isNotEmpty).length;

  /// The service with the highest listing score, the first on a tie (the website's "Most Complete" tile); null
  /// with none.
  ServiceItem? get bestCompleted => rows.isEmpty ? null : rows.reduce((a, b) => b.score > a.score ? b : a);

  @override
  Future<void> deleteRow(String id) => repository.deleteService(id);

  Future<String?> save(ServiceDraft draft, {ServiceItem? editing}) {
    final body = draft.payload(editing: editing != null);
    return write(
      () => editing == null
          ? repository.createService({...body, 'companyId': viewer.companyId, 'addToListing': draft.addToListing})
          : repository.updateService(editing.id, body),
    );
  }

  Future<String?> duplicate(ServiceItem s) =>
      write(() => repository.createService({'companyId': viewer.companyId, ...ServiceDraft.duplicateOf(s)}));
}
