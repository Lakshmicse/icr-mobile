import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import 'saved_models.dart';

/// What the Saved items screen reads and writes: a page of each kind of
/// bookmark, and the save and un-save of one.
abstract class SavedRepository {
  /// Rows per page, for the kinds the API pages.
  static const pageSize = 20;

  /// A page of [kind]. Councils are not paged: the API answers with all of them.
  /// Throws an [ApiError]; a 403 means the account cannot hold this kind.
  Future<SavedPage> load(SavedKind kind, {int page = 1});

  /// Saves [item] again (the Undo of an un-save).
  Future<void> save(SavedItem item);

  /// Takes the bookmark off.
  Future<void> unsave(SavedItem item);
}

/// The real API. Every call is bearer-authenticated through [ApiClient].
class ApiSavedRepository implements SavedRepository {
  ApiSavedRepository({required this.api});

  final ApiClient api;

  @override
  Future<SavedPage> load(SavedKind kind, {int page = 1}) async {
    final data = await _get(switch (kind) {
      SavedKind.jobs => '/jobs/saved',
      SavedKind.mentors => '/mentorship/mentors/saved',
      SavedKind.suppliers => '/vendors/saved',
      SavedKind.councils => '/councils/saves/mine',
      SavedKind.discussions => '/forum/saves/mine',
    }, kind == SavedKind.councils ? null : {'page': page, 'limit': SavedRepository.pageSize});

    // The councils' answer is a bare list, the others `{ data, meta }`.
    final rows = (data is Map ? data['data'] : data);
    final meta = data is Map && data['meta'] is Map ? (data['meta'] as Map).cast<String, dynamic>() : const {};
    final items = <SavedItem>[];
    for (final row in rows is List ? rows : const []) {
      if (row is! Map) continue;
      final json = row.cast<String, dynamic>();
      // A row with no id cannot be un-saved, so it is not drawn.
      if (json[kind == SavedKind.councils ? 'councilId' : 'id'] == null) continue;
      items.add(switch (kind) {
        SavedKind.jobs => SavedJob.fromJson(json),
        SavedKind.mentors => SavedMentor.fromJson(json),
        SavedKind.suppliers => SavedSupplier.fromJson(json),
        SavedKind.councils => SavedCouncil.fromJson(json),
        SavedKind.discussions => SavedThread.fromJson(json),
      });
    }
    return SavedPage(
      items: items,
      total: (meta['total'] as num?)?.toInt() ?? items.length,
      hasNext: meta['hasNext'] == true,
    );
  }

  @override
  Future<void> save(SavedItem item) => _send('POST', _savePath(item));

  @override
  Future<void> unsave(SavedItem item) => _send('DELETE', _savePath(item));

  static String _savePath(SavedItem item) => switch (item.kind) {
    SavedKind.jobs => '/jobs/${item.id}/save',
    SavedKind.mentors => '/mentorship/mentors/${item.id}/save',
    SavedKind.suppliers => '/vendors/${item.id}/save',
    SavedKind.councils => '/councils/${item.id}/save',
    SavedKind.discussions => '/forum/threads/${item.id}/save',
  };

  Future<Object?> _get(String path, Map<String, dynamic>? query) async {
    try {
      final res = await api.dio.get<Object?>(path, queryParameters: query);
      return res.data;
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<void> _send(String method, String path) async {
    try {
      await api.dio.request<Object?>(path, options: Options(method: method));
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }
}
