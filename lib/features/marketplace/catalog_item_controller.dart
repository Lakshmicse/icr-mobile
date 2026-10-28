import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'marketplace_models.dart';

/// A product or a service page's state: the item, then the supplier it belongs
/// to (the page's "Sold by" card opens that supplier's profile).
///
/// The row the member tapped seeds it, so the page has a name and a price at
/// once; the API's own read fills in the rest and replaces it.
class CatalogItemController<T> extends ChangeNotifier {
  CatalogItemController({required this.read, required this.supplierFor, T? seed}) : _item = seed;

  /// Reads the item (`GET /services/:id`, `GET /products/:id`).
  final Future<T> Function() read;

  /// The supplier that has [item], when it has a listing (`null` for a company with none).
  final Future<Supplier?> Function(T item) supplierFor;

  T? _item;
  Supplier? _supplier;
  bool _loading = false;
  bool _loadingSupplier = false;
  String? _error;
  bool _disposed = false;

  T? get item => _item;
  Supplier? get supplier => _supplier;
  bool get loading => _loading;
  bool get loadingSupplier => _loadingSupplier;

  /// Why the item could not be read.
  String? get error => _error;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    _notify();
    try {
      final item = await read();
      _item = item;
      _loading = false;
      _notify();
      await _loadSupplier(item);
    } catch (e) {
      _error = ApiError.from(e).message;
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> _loadSupplier(T item) async {
    _loadingSupplier = true;
    _notify();
    try {
      _supplier = await supplierFor(item);
    } catch (_) {
      // The page is the item; the supplier card is a way on.
    } finally {
      _loadingSupplier = false;
      _notify();
    }
  }
}
