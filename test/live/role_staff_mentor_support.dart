/// What the mentor tests do to the other side: a mentee asks Srikanth through the app's own profile controller,
/// a pairing is made and ended, and the desk's figures are read raw.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/features/mentor_profile/api_mentor_profile_repository.dart';
import 'package:icr_mobile/features/mentor_profile/mentor_profile_controller.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_models.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_repository.dart';

import 'live.dart';
import 'role_staff_support.dart';

Future<void> clearPhone(ApiClient api) async {
  await api.dio.patch<dynamic>('/users/me', data: {'phone': ''});
}

Future<Map<String, dynamic>> getJson(ApiClient api, String path, [Map<String, dynamic>? query]) async =>
    (await api.dio.get<Map<String, dynamic>>(path, queryParameters: query)).data!;

/// Srikanth's dashboard numbers: places taken, places in all, requests waiting.
Future<({int active, int total, int pending})> deskFigures() async {
  final raw = await getJson(await clientFor(srikanth), '/mentorship/mentors/me/dashboard');
  final capacity = raw['capacity'] as Map;
  return (
    active: (capacity['active'] as num).toInt(),
    total: (capacity['total'] as num).toInt(),
    pending: ((raw['requests'] as Map)['pending'] as num).toInt(),
  );
}

/// [who] asks Srikanth for mentoring through the app's own profile controller (the request sheet's call), with a
/// phone number only when the account has none (taken off again afterwards). Returns the request as the sender
/// reads it.
Future<MentoringRequest> askSrikanth(LivePerson who, String message) async {
  final api = await clientFor(who);
  final profile = MentorProfileController(
    repository: ApiMentorProfileRepository(api: api),
    mentorId: srikanthProfileId,
  );
  try {
    await profile.load();
    final viewer = profile.profile!.viewer!;
    expect(viewer.canRequest, isTrue, reason: viewer.blockedReason);
    final needsPhone = await profile.needsPhone();
    final failure = await profile.requestMentoring(message: message, phone: needsPhone ? aPhone : null);
    if (needsPhone) await clearPhone(api);
    expect(failure, isNull);
  } finally {
    profile.dispose();
  }
  final sent = await MentoringRepository(api: api).requestsSent();
  return sent.firstWhere((r) => r.message == message);
}

/// Withdraws a request that is still open (a failed run); an answered one is left as it is.
Future<void> withdrawIfOpen(LivePerson who, MentoringRequest request) async {
  try {
    await MentoringRepository(api: await clientFor(who)).withdrawRequest(request.id);
  } on Object {
    // answered already
  }
}

/// Ends the live pairing of Srikanth with [menteeName], so the mentor's place is free again. A pairing cannot be
/// deleted: it stays as an ended row.
Future<void> endPairingWith(String menteeName) async {
  final repo = MentoringRepository(api: await clientFor(srikanth));
  for (final p in (await repo.pairings()).where((p) => p.status.live && p.counterpart.name == menteeName)) {
    await repo.updatePairing(
      p.id,
      PairingStatus.endedEarly,
      endedReason: 'A staff live test ends the pairing it made.',
    );
  }
}

/// A pairing of Srikanth with Rohan made for one test: Rohan asks, Srikanth accepts. Both sides have a
/// repository on it; [end] closes it.
class RohanPairing {
  RohanPairing(this.id, this.request);

  final String id;
  final MentoringRequest request;

  static Future<RohanPairing> start({String? message}) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final ask = await askSrikanth(
      rohan,
      message ?? 'A staff test ($stamp): Rohan asks for a mentor on regional operations.',
    );
    final mentor = MentoringRepository(api: await clientFor(srikanth));
    await mentor.respondToRequest(ask.id, accept: true, note: 'Welcome.', cadence: 'FORTNIGHTLY');
    final id = (await mentor.pairings()).firstWhere((p) => p.status.live && p.counterpart.name == 'Rohan Das').id;
    return RohanPairing(id, ask);
  }

  Future<void> end() => endPairingWith('Rohan Das');
}
