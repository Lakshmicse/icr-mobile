import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';

/// One read a screen shows: the data, whether it is loading, and the API's
/// refusal as a sentence. A newer [load] wins over an older one still in flight.
class Loader<T> {
  Loader(this._fetch, this._changed);

  final Future<T> Function() _fetch;
  final VoidCallback _changed;

  T? data;
  String? error;
  bool loading = false;
  bool loaded = false;
  int _generation = 0;

  /// Reads again. A failure keeps what was already shown and records [error].
  Future<void> load() async {
    final mine = ++_generation;
    loading = true;
    error = null;
    _changed();
    try {
      final value = await _fetch();
      if (mine != _generation) return;
      data = value;
      loaded = true;
    } catch (e) {
      if (mine != _generation) return;
      error = ApiError.from(e).message;
    }
    loading = false;
    _changed();
  }

  /// Reads once; later calls do nothing while it holds data or is in flight.
  Future<void> ensure() => loaded || loading ? Future.value() : load();

  /// Forgets the data, so the next [ensure] reads again.
  void reset() {
    _generation++;
    data = null;
    error = null;
    loading = false;
    loaded = false;
  }
}
