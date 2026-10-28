import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the searches a person made are kept between launches.
abstract class RecentStore {
  Future<List<String>> load();
  Future<void> save(List<String> searches);
}

/// On the device, for the signed-in person only: the key carries their id, so
/// a second account on the same phone does not see the first one's searches.
class SecureRecentStore implements RecentStore {
  SecureRecentStore({required this.userId, FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final String userId;
  final FlutterSecureStorage _storage;

  String get _key => 'icr.search.recent.v1.$userId';

  @override
  Future<List<String>> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return const [];
      return (jsonDecode(raw) as List).whereType<String>().toList();
    } catch (_) {
      // A store that cannot be read is an empty history, never a failed search.
      return const [];
    }
  }

  @override
  Future<void> save(List<String> searches) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(searches));
    } catch (_) {}
  }
}

/// Kept in memory only: tests, the demo, a screen mounted alone.
class MemoryRecentStore implements RecentStore {
  MemoryRecentStore([List<String> initial = const []]) : _items = [...initial];

  List<String> _items;

  @override
  Future<List<String>> load() async => [..._items];

  @override
  Future<void> save(List<String> searches) async => _items = [...searches];
}

/// The last searches, newest first, without repeats (ignoring case), at most [limit].
class RecentSearches {
  RecentSearches(this._store, {this.limit = 10});

  final RecentStore _store;
  final int limit;
  List<String> _items = const [];

  List<String> get items => _items;

  Future<void> load() async => _items = (await _store.load()).take(limit).toList();

  Future<void> add(String query) async {
    final q = query.trim();
    if (q.length < 2) return;
    _items = [q, ..._items.where((s) => s.toLowerCase() != q.toLowerCase())].take(limit).toList();
    await _store.save(_items);
  }

  Future<void> remove(String query) async {
    _items = _items.where((s) => s != query).toList();
    await _store.save(_items);
  }

  Future<void> clear() async {
    _items = const [];
    await _store.save(_items);
  }
}
