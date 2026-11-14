import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../../mentorship_my/mentoring_models.dart' show asMaps;
import 'group_schedule.dart' show BusyInterval, GroupComposerDefaults;
import 'offerings_models.dart';

/// The standard platform fee on a mentor's sale (`PLATFORM_FEE_BPS`), before a plan's reduction.
const platformFeeBps = 2000;

/// A group-session save the API refused: its sentence, its code, and for the calendar gate (`GROUP_DAY_CLASH`) the
/// 1-based day it named, so the composer can mark that row.
class GroupSaveRefusal implements Exception {
  const GroupSaveRefusal(this.message, {this.code, this.day});

  factory GroupSaveRefusal.from(Object error) {
    if (error is GroupSaveRefusal) return error;
    final e = ApiError.from(error);
    int? day;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['day'] is num) day = (data['day'] as num).toInt();
    }
    return GroupSaveRefusal(e.message, code: e.code, day: day);
  }

  final String message;
  final String? code;
  final int? day;

  @override
  String toString() => message;
}

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

  // --- the group-session composer ----------------------------------------------------

  /// What a new session starts from: the mentor's standing link, zone, weekly hours and group defaults (the same
  /// read as the website's `useMyMentorProfile`, `GET /mentorship/mentors/me`).
  Future<GroupComposerDefaults> composerDefaults() async =>
      GroupComposerDefaults.fromJson(await _get('/mentorship/mentors/me'));

  /// Everything already on the host's calendar in [from, to) (`GET /mentorship/group-sessions/mine/busy`, at most
  /// `maxBusyRangeDays` a call). [except] is the session being edited, left out of the answer.
  Future<List<BusyInterval>> busy(DateTime from, DateTime to, {String? except}) async {
    final res = await _get('/mentorship/group-sessions/mine/busy', {
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
      'except': ?except,
    });
    return [for (final b in asMaps(res['intervals'])) BusyInterval.fromJson(b)];
  }

  /// What ICR keeps from the mentor's sale, in basis points: the standard 20% less their plan's
  /// `mentorship.feeReduction` (the website's `useMentorFeeBps` over `GET /subscriptions/entitlements`).
  Future<int> mentorFeeBps() async {
    final res = await _get('/subscriptions/entitlements');
    final benefits = res['benefits'];
    final v = benefits is Map ? benefits['mentorship.feeReduction'] : null;
    final reduction = v is Map && v['kind'] == 'DISCOUNT' ? (v['bps'] as num?)?.toInt() ?? 0 : 0;
    return (platformFeeBps - (reduction < 0 ? 0 : reduction)).clamp(0, platformFeeBps);
  }

  /// Creates ([id] null) or saves a session from the composer. A refusal is a [GroupSaveRefusal], which keeps the
  /// day the calendar gate named.
  Future<HostedSession> composeSession(Map<String, Object?> body, {String? id}) async => HostedSession.fromJson(
    await _sendGroup(id == null ? 'POST' : 'PATCH', '/mentorship/group-sessions${id == null ? '' : '/$id'}', body)
        as Map<String, dynamic>,
  );

  /// "Repeat" as separate sessions: one session per date, every other field shared, all or nothing
  /// (`POST /mentorship/group-sessions/batch`). Answers the new sessions' ids in date order.
  Future<List<String>> createSessionBatch(Map<String, Object?> body) async {
    final res = await _sendGroup('POST', '/mentorship/group-sessions/batch', body);
    return [for (final s in asMaps(res is Map ? res['sessions'] : null)) s['id'] as String? ?? ''];
  }

  Future<dynamic> _sendGroup(String method, String path, Map<String, Object?> body) async {
    try {
      final res = await api.dio.request<dynamic>(path, data: body, options: Options(method: method));
      return res.data;
    } catch (e) {
      throw GroupSaveRefusal.from(e);
    }
  }

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
