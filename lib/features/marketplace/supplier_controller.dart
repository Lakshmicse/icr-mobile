import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'catalog_models.dart';
import 'marketplace_models.dart';
import 'marketplace_repository.dart';

/// The tabs of a supplier's profile.
enum SupplierTab {
  overview('Overview'),
  catalog('Products & services'),
  proofs('Compliances & Proofs');

  const SupplierTab(this.label);

  final String label;
}

/// One part of a profile that loads on its own: what it holds, whether it is on
/// its way, and why it could not be read.
class Loadable<T> {
  Loadable({this.value, this.loading = false, this.error});

  T? value;
  bool loading;
  String? error;

  bool get loaded => value != null;
}

/// The state of one supplier's profile sheet. The card the member tapped seeds
/// it (name, rating, headline), `GET /vendors/:id` fills in the offices and the
/// ratings, and each tab reads what it shows the first time it is opened, so a
/// profile that is only glanced at costs one request.
class SupplierController extends ChangeNotifier {
  SupplierController({
    required this.repository,
    required Supplier seed,
    bool saved = false,
    this.onSaved,
    this.onLoaded,
    SupplierTab tab = SupplierTab.overview,
  }) : _supplier = seed,
       _saved = saved,
       _tab = tab;

  final MarketplaceRepository repository;

  /// The list behind the sheet follows what the member does here.
  final void Function(String id, bool saved)? onSaved;

  /// The full listing was read: the card keeps the rating it shows.
  final ValueChanged<Supplier>? onLoaded;

  Supplier _supplier;
  bool _saved;
  SupplierTab _tab;
  bool _disposed = false;

  /// The listing's own read: offices, registration, ratings.
  final detail = Loadable<Supplier>();
  final compliances = Loadable<List<Compliance>>();
  final services = Loadable<List<CatalogService>>();
  final products = Loadable<List<CatalogProduct>>();

  Supplier get supplier => _supplier;
  bool get saved => _saved;
  SupplierTab get tab => _tab;

  /// Whether the full listing has been read (the offices, the ratings).
  bool get hasDetail => _supplier.detailed;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ---- Loading -----------------------------------------------------------------------------

  /// Reads the listing, and the tab the sheet opened on. A seed that knows only
  /// the listing's id has no company to read the tab with yet, so the listing
  /// is read first.
  Future<void> load() async {
    if (_supplier.companyId.isEmpty) {
      await _loadDetail();
      await _loadTab(_tab);
      return;
    }
    await Future.wait([_loadDetail(), _loadTab(_tab)]);
  }

  Future<void> retry() => load();

  Future<void> _loadDetail() async {
    if (detail.loading) return;
    detail
      ..loading = true
      ..error = null;
    _notify();
    try {
      final full = await repository.supplier(_supplier.id);
      // The card's brand colour and logo asset stay with the supplier the member tapped.
      _supplier = Supplier.merged(full, card: _supplier);
      detail.value = _supplier;
      onLoaded?.call(_supplier);
    } catch (e) {
      detail.error = ApiError.from(e).message;
    } finally {
      detail.loading = false;
      _notify();
    }
  }

  /// Moves to a tab, reading what it shows the first time.
  Future<void> select(SupplierTab tab) async {
    if (tab == _tab) return;
    _tab = tab;
    _notify();
    await _loadTab(tab);
  }

  Future<void> _loadTab(SupplierTab tab) {
    if (_supplier.companyId.isEmpty) return Future.value();
    switch (tab) {
      case SupplierTab.overview:
        return Future.value();
      case SupplierTab.catalog:
        return Future.wait([
          _part(services, () => repository.servicesOf(_supplier.companyId)),
          _part(products, () => repository.productsOf(_supplier.companyId)),
        ]);
      case SupplierTab.proofs:
        return _part(compliances, () => repository.compliances(_supplier.companyId));
    }
  }

  Future<void> _part<T>(Loadable<T> part, Future<T> Function() read) async {
    if (part.loading || part.loaded) return;
    part
      ..loading = true
      ..error = null;
    _notify();
    try {
      part.value = await read();
    } catch (e) {
      part.error = ApiError.from(e).message;
    } finally {
      part.loading = false;
      _notify();
    }
  }

  /// Reads one part again (the "Try again" under an error).
  Future<void> reload(SupplierTab tab) async {
    switch (tab) {
      case SupplierTab.overview:
        return _loadDetail();
      case SupplierTab.catalog:
        services.error = products.error = null;
        return _loadTab(tab);
      case SupplierTab.proofs:
        compliances.error = null;
        return _loadTab(tab);
    }
  }

  // ---- What the member does -----------------------------------------------------------------

  /// Bookmarks the supplier, or takes the bookmark back; a sentence when the API refuses.
  Future<String?> toggleSave() async {
    final next = !_saved;
    _saved = next;
    onSaved?.call(_supplier.id, next);
    _notify();
    try {
      await repository.setSaved(_supplier.id, next);
      return null;
    } catch (e) {
      _saved = !next;
      onSaved?.call(_supplier.id, !next);
      _notify();
      return ApiError.from(e).message;
    }
  }

  /// The member's rating of the supplier, then the listing read again for the new
  /// average; a sentence when the API refuses (the supplier's own team may not rate it).
  Future<String?> rate({required int score, String? comment}) async {
    try {
      await repository.rate(_supplier.id, score: score, comment: comment);
    } catch (e) {
      return ApiError.from(e).message;
    }
    unawaited(_loadDetail());
    return null;
  }

  /// Opens a conversation with the supplier's team; its id, or a sentence on a refusal.
  Future<({String? conversationId, String? error})> startConversation({String? message}) async {
    try {
      final id = await repository.startConversation(_supplier.id, message: message);
      return (conversationId: id, error: null);
    } catch (e) {
      return (conversationId: null, error: ApiError.from(e).message);
    }
  }
}
