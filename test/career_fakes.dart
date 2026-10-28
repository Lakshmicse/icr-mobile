/// Stand-ins for the career tests: an HTTP table that answers each route and
/// writes down the calls, and the career source built on it.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/features/career/api_career_repository.dart';
import 'package:icr_mobile/features/career/career_models.dart';
import 'package:icr_mobile/features/career/demo_career_repository.dart';
import 'package:icr_mobile/features/jobs/api_jobs_repository.dart';

class _Token extends TokenStore {
  @override
  Future<String?> accessToken() async => 'token';
  @override
  Future<String?> refreshToken() async => null;
}

/// Answers each `METHOD /path` from a table (a value is sent as JSON, a
/// `(status, body)` record as it is) and records the calls.
class FakeApi implements HttpClientAdapter {
  FakeApi(this.routes);

  final Map<String, Object? Function(RequestOptions options)> routes;
  final List<RequestOptions> requests = [];

  List<String> get calls => [for (final r in requests) '${r.method} ${r.path}'];

  /// The last request to [route] (`'POST /jobs/j1/apply'`).
  RequestOptions last(String route) =>
      requests.lastWhere((o) => '${o.method} ${o.path}' == route, orElse: () => throw StateError('no call to $route'));

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final handler = routes['${options.method} ${options.path}'];
    if (handler == null) return ResponseBody.fromString('{"message":"Not found"}', 404, headers: _json);
    final result = handler(options);
    if (result is (int, String)) return ResponseBody.fromString(result.$2, result.$1, headers: _json);
    if (result == null) return ResponseBody.fromString('', 200, headers: _json);
    return ResponseBody.fromString(jsonEncode(result), 200, headers: _json);
  }

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}

ApiClient fakeClient(FakeApi api) {
  final client = ApiClient(tokens: _Token(), baseUrl: 'http://api.test/api/v1');
  client.dio.httpClientAdapter = api;
  return client;
}

ApiCareerRepository apiCareer(FakeApi api) {
  final client = fakeClient(api);
  return ApiCareerRepository(
    api: client,
    jobs: ApiJobsRepository(api: client),
  );
}

/// The demo career source with every call written down and any answer replaceable, for
/// the screens' widget tests.
class SpyCareer extends DemoCareerRepository {
  SpyCareer({super.jobs, super.now});

  /// What the writes were, in order.
  final log = <String>[];
  final messages = <String?>[];

  ApiError? withdrawError;
  ApiError? offerError;
  ApiError? messageError;
  ApiError? alertError;
  ApiError? saveError;
  ApiError? inviteError;
  ApiError? applicationsError;
  ApiError? savedError;

  /// Replaces what the tracker reads.
  List<CareerApplication>? applicationsAnswer;
  bool noDiscoverable = false;
  String? conversationId = 'conv-1';
  List<Job> savedAnswer = const [];
  bool savedHasMore = false;
  bool savedSet = false;
  List<Job>? hiddenAnswer;
  ApiError? hiddenError;
  ApiError? discoverableError;
  ApiError? invitesError;
  List<JobInvite>? invitesAnswer;
  bool matchesMore = false;

  @override
  Future<List<CareerApplication>> applications() async {
    log.add('applications');
    final error = applicationsError;
    if (error != null) throw error;
    return applicationsAnswer ?? await super.applications();
  }

  @override
  Future<CareerApplication> application(String id) async {
    log.add('application $id');
    final fromAnswer = applicationsAnswer?.where((a) => a.id == id);
    if (fromAnswer != null && fromAnswer.isNotEmpty) return fromAnswer.first;
    return super.application(id);
  }

  @override
  Future<CareerApplication> withdraw(String id) async {
    log.add('withdraw $id');
    final error = withdrawError;
    if (error != null) throw error;
    return super.withdraw(id);
  }

  @override
  Future<void> respondToOffer(String offerId, {required bool accept, String? note}) async {
    log.add('offer $offerId ${accept ? 'accept' : 'decline'} ${note ?? ''}'.trim());
    final error = offerError;
    if (error != null) throw error;
    return super.respondToOffer(offerId, accept: accept, note: note);
  }

  @override
  Future<String?> messageHiringTeam(String jobId, {String? message}) async {
    log.add('message $jobId');
    messages.add(message);
    final error = messageError;
    if (error != null) throw error;
    return conversationId;
  }

  @override
  Future<JobAlert> createAlert({
    required String name,
    required Map<String, String> criteria,
    bool alertsEnabled = true,
    String frequency = 'DAILY',
  }) async {
    log.add('createAlert $name $criteria $alertsEnabled $frequency');
    final error = alertError;
    if (error != null) throw error;
    return super.createAlert(name: name, criteria: criteria, alertsEnabled: alertsEnabled, frequency: frequency);
  }

  @override
  Future<JobAlert> updateAlert(
    String id, {
    String? name,
    Map<String, String>? criteria,
    bool? alertsEnabled,
    String? frequency,
  }) async {
    log.add('updateAlert $id name=$name criteria=$criteria enabled=$alertsEnabled frequency=$frequency');
    final error = alertError;
    if (error != null) throw error;
    return super.updateAlert(id, name: name, criteria: criteria, alertsEnabled: alertsEnabled, frequency: frequency);
  }

  @override
  Future<void> deleteAlert(String id) async {
    log.add('deleteAlert $id');
    final error = alertError;
    if (error != null) throw error;
    return super.deleteAlert(id);
  }

  @override
  Future<JobPage> runAlert(String id, {int page = 1}) async {
    log.add('runAlert $id $page');
    final error = alertError;
    if (error != null) throw error;
    final got = await super.runAlert(id, page: page);
    return JobPage(jobs: got.jobs, hasMore: matchesMore && page == 1);
  }

  @override
  Future<JobPage> savedJobs({int page = 1}) async {
    log.add('savedJobs $page');
    final error = savedError;
    if (error != null) throw error;
    if (savedSet) return JobPage(jobs: savedAnswer, hasMore: savedHasMore && page == 1);
    return super.savedJobs(page: page);
  }

  @override
  Future<List<Job>> hiddenJobs() async {
    log.add('hidden');
    final error = hiddenError;
    if (error != null) throw error;
    return hiddenAnswer ?? await super.hiddenJobs();
  }

  @override
  Future<void> respondToInvite(String id, {required bool decline}) async {
    log.add('invite $id ${decline ? 'decline' : 'view'}');
    final error = inviteError;
    if (error != null) throw error;
    return super.respondToInvite(id, decline: decline);
  }

  @override
  Future<bool?> discoverable() async => noDiscoverable ? null : super.discoverable();

  @override
  Future<void> setDiscoverable(bool on) async {
    log.add('discoverable $on');
    final error = discoverableError;
    if (error != null) throw error;
    return super.setDiscoverable(on);
  }

  @override
  Future<List<JobInvite>> invites() async {
    log.add('invites');
    final error = invitesError;
    if (error != null) throw error;
    return invitesAnswer ?? await super.invites();
  }
}
