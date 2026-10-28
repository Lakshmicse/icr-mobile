import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../../mentorship_my/mentoring_models.dart' show asMaps;
import 'offerings_models.dart';

/// A file the phone picked, with its bytes read.
class PickedUpload {
  const PickedUpload({required this.bytes, required this.name, this.mimeType});

  final Uint8List bytes;
  final String name;
  final String? mimeType;
}

/// A file stored by `POST /uploads` (`url` is root-relative: `/uploads/<stored name>`).
class StoredUpload {
  const StoredUpload({required this.url, required this.name, required this.size});

  final String url;
  final String name;
  final int size;

  /// The stored file name: what a resource is saved with as its `uploadId`.
  String get uploadId => url.split('/').last;
}

/// The seller gates and the services behind them.
class Storefront {
  const Storefront({required this.gates, required this.services});

  final StorefrontGates gates;
  final List<OfferedService> services;
}

/// Everything the Offerings panel reads and writes, on the real API: the
/// storefront (`/mentor-services/mine`), ongoing plans and programmes
/// (`/mentor-plans`), group sessions (`/mentorship/group-sessions`) and uploads.
/// A refusal is thrown as an [ApiError] carrying the API's own sentence.
class OfferingsRepository {
  OfferingsRepository({required this.api});

  final ApiClient api;

  // --- storefront ----------------------------------------------------------------

  Future<Storefront> storefront() async => _storefrontFrom(await _get('/mentor-services/mine'));

  /// Accepts the seller terms and opens the storefront. [version] must be the current one.
  Future<Storefront> acceptTerms(String version) async =>
      _storefrontFrom(await _send('POST', '/mentor-services/mine/terms', {'version': version}) as Map<String, dynamic>);

  Storefront _storefrontFrom(Map<String, dynamic> j) => Storefront(
    gates: StorefrontGates(
      optedIn: j['optedIn'] == true,
      termsAcceptedVersion: j['termsAcceptedVersion'] as String?,
      termsCurrentVersion: j['termsCurrentVersion'] as String? ?? '',
      suspended: j['suspended'] == true,
      live: j['live'] == true,
      blockedReason: j['blockedReason'] as String?,
    ),
    services: [for (final s in asMaps(j['services'])) OfferedService.fromJson(s)],
  );

  Future<OfferedService> createService(Map<String, Object?> body) async =>
      OfferedService.fromJson(await _send('POST', '/mentor-services/mine', body) as Map<String, dynamic>);

  Future<OfferedService> updateService(String id, Map<String, Object?> body) async =>
      OfferedService.fromJson(await _send('PATCH', '/mentor-services/mine/$id', body) as Map<String, dynamic>);

  /// Soft delete: purchases keep their snapshots.
  Future<void> deleteService(String id) => _send('DELETE', '/mentor-services/mine/$id');

  // --- plans and programmes --------------------------------------------------------

  Future<List<OfferedPlan>> plans() async => [
    for (final p in await _getList('/mentor-plans/mine')) OfferedPlan.fromJson(p),
  ];

  Future<OfferedPlan> createPlan(Map<String, Object?> body) async =>
      OfferedPlan.fromJson(await _send('POST', '/mentor-plans', body) as Map<String, dynamic>);

  /// A partial patch: only what is sent changes.
  Future<OfferedPlan> updatePlan(String id, Map<String, Object?> body) async =>
      OfferedPlan.fromJson(await _send('PATCH', '/mentor-plans/$id', body) as Map<String, dynamic>);

  Future<void> deletePlan(String id) => _send('DELETE', '/mentor-plans/$id');

  // --- group sessions ----------------------------------------------------------------

  /// The sessions the caller hosts, drafts and held ones included, nearest first as the API orders them.
  Future<List<HostedSession>> sessions() async {
    final res = await _get('/mentorship/group-sessions', {'mine': true, 'limit': 50});
    return [for (final s in asMaps(res['data'])) HostedSession.fromJson(s)];
  }

  /// One session with its roster (the host also reads each person's question).
  Future<HostedSession> session(String id) async =>
      HostedSession.fromJson(await _get('/mentorship/group-sessions/$id'));

  Future<HostedSession> createSession(Map<String, Object?> body) async =>
      HostedSession.fromJson(await _send('POST', '/mentorship/group-sessions', body) as Map<String, dynamic>);

  /// A full replacement of the session's fields: send everything it should keep.
  Future<HostedSession> updateSession(String id, Map<String, Object?> body) async =>
      HostedSession.fromJson(await _send('PATCH', '/mentorship/group-sessions/$id', body) as Map<String, dynamic>);

  /// DRAFT to open for registration.
  Future<HostedSession> publishSession(String id) async =>
      HostedSession.fromJson(await _send('POST', '/mentorship/group-sessions/$id/publish') as Map<String, dynamic>);

  /// Cancels every day still ahead; registered people are told [reason] as written.
  Future<void> cancelSession(String id, String reason) =>
      _send('POST', '/mentorship/group-sessions/$id/cancel', {'reason': reason.trim()});

  /// Records who was there; everyone else is marked a no-show. Only once a day has started.
  Future<HostedSession> completeSession(String id, List<String> attendedIds, {int? durationMin, String? note}) async =>
      HostedSession.fromJson(
        await _send('POST', '/mentorship/group-sessions/$id/complete', {
              'attendedIds': attendedIds,
              'durationMin': ?durationMin,
              if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
            })
            as Map<String, dynamic>,
      );

  // --- files -------------------------------------------------------------------------

  /// Stores a file for [purpose] (`mentor-resource` for a resource's file, `mentor-offering` for a cover).
  Future<StoredUpload> upload(PickedUpload file, {required String purpose}) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          file.bytes,
          filename: file.name,
          contentType: file.mimeType == null ? null : DioMediaType.parse(file.mimeType!),
        ),
      });
      final res = await api.dio.post<Map<String, dynamic>>(
        '/uploads',
        data: form,
        queryParameters: {'purpose': purpose},
      );
      final d = res.data!;
      return StoredUpload(
        url: d['url'] as String,
        name: d['name'] as String? ?? file.name,
        size: (d['size'] as num?)?.toInt() ?? file.bytes.length,
      );
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  // --- transport ------------------------------------------------------------------------

  Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? query]) async {
    try {
      final res = await api.dio.get<dynamic>(path, queryParameters: query);
      final data = res.data;
      return data is Map<String, dynamic> ? data : const {};
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    try {
      final res = await api.dio.get<dynamic>(path);
      final data = res.data;
      if (data is List) return data.whereType<Map<String, dynamic>>().toList();
      if (data is Map && data['data'] is List) return asMaps(data['data']);
      return const [];
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<dynamic> _send(String method, String path, [Map<String, Object?>? body]) async {
    try {
      final res = await api.dio.request<dynamic>(
        path,
        data: body,
        options: Options(method: method),
      );
      return res.data;
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}
