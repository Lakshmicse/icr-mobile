/// A fake API and fixtures for the mentoring screens' tests (My mentoring, a
/// pairing, purchases, group sessions, programmes, becoming a mentor, the
/// mentor's desk). The JSON has the shape the real API answers with (each
/// fixture was checked against a live call, see `test/live/mentoring_live_test.dart`).
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_clock.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_links.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_repository.dart';
import 'package:icr_mobile/features/mentorship_my/my_mentoring_controller.dart';
import 'package:icr_mobile/features/mentorship_my/my_mentoring_screen.dart';
import 'package:icr_mobile/features/mentorship_my/pairing_forms.dart' show SharePicker, pickShareFile;
import 'package:icr_mobile/features/mentorship_my/pairing_screen.dart';

class NoTokens extends TokenStore {
  @override
  Future<String?> accessToken() async => 'token';
  @override
  Future<String?> refreshToken() async => null;
}

typedef Reply = Object Function(RequestOptions options);

/// An answer with a status code and a body, for a refusal.
(int, String) refuse(String message, {int status = 400, String? code}) =>
    (status, jsonEncode({'message': message, 'statusCode': status, 'code': ?code}));

/// Answers each `METHOD /path` from a table and records the calls and bodies.
/// A route may be replaced during a test (`api.routes['GET /x'] = ...`) to
/// change what the "server" holds after a write.
class FakeApi implements HttpClientAdapter {
  FakeApi(Map<String, Reply> routes) : routes = {...routes};

  final Map<String, Reply> routes;
  final List<RequestOptions> requests = [];

  List<String> get calls => [for (final r in requests) '${r.method} ${r.path}'];

  /// The body last sent to `METHOD /path`.
  Object? bodyOf(String key) {
    for (final r in requests.reversed) {
      if ('${r.method} ${r.path}' == key) return r.data;
    }
    return null;
  }

  Map<String, dynamic>? queryOf(String key) {
    for (final r in requests.reversed) {
      if ('${r.method} ${r.path}' == key) return r.queryParameters;
    }
    return null;
  }

  int count(String key) => calls.where((c) => c == key).length;

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
    return ResponseBody.fromString(jsonEncode(result), 200, headers: _json);
  }

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}

  ApiClient client() {
    final client = ApiClient(tokens: NoTokens(), baseUrl: 'http://api.test/api/v1');
    client.dio.httpClientAdapter = this;
    return client;
  }
}

/// Records the addresses the app hands to the browser (the website's pages).
List<String> launches(WidgetTester tester) {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final urls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'launch') urls.add((call.arguments as Map)['url'] as String);
    return true;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
  return urls;
}

/// A phone-sized window.
void phone(WidgetTester tester, {double height = 1700}) {
  tester.view.physicalSize = Size(780, height);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Future<void> pumpApp(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(), home: home));
  await settle(tester);
}

/// Lets the fake API's real async work finish, then draws.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pumpAndSettle();
}

// --- JSON in the shape of the real answers ------------------------------------------

String iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, Object?> personJson(
  String id,
  String first,
  String last, {
  String? headline,
  String? mentorProfileId,
  String? careerStage,
  String? designation,
}) => {
  'id': id,
  'firstName': first,
  'lastName': last,
  'avatarUrl': null,
  'title': null,
  'company': null,
  'headline': headline,
  'designation': designation,
  'mentorProfileId': mentorProfileId,
  'careerStage': careerStage,
};

final bharat = personJson('u-bharat', 'Bharat', 'Buyer');
final anand = personJson(
  'u-anand',
  'Anand',
  'Iyer',
  headline: 'Head of Facilities Strategy at Prestige Group',
  mentorProfileId: 'mp-anand',
);
final divya = personJson(
  'u-divya',
  'Divya',
  'Rao',
  headline: 'Sustainability Lead at Brigade Group',
  mentorProfileId: 'mp-divya',
);

Map<String, Object?> pairingJson(
  String id, {
  String status = 'ACTIVE',
  String side = 'MENTEE',
  Map<String, Object?>? mentor,
  Map<String, Object?>? mentee,
  int sessions = 2,
  int minutes = 90,
  String? completedAt,
  String? conversationId,
}) => {
  'id': id,
  'status': status,
  'viewerSide': side,
  'counterpartPhone': null,
  'cadence': 'FORTNIGHTLY',
  'startedAt': iso(mentoringNow().subtract(const Duration(days: 40))),
  'endsAt': null,
  'completedAt': completedAt,
  'endedReason': null,
  'sessionsCount': sessions,
  'totalMinutes': minutes,
  'conversationId': conversationId,
  'mentor': mentor ?? anand,
  'mentee': mentee ?? bharat,
};

Map<String, Object?> sessionJson(
  String id, {
  String mentorshipId = 'pair-anand',
  required DateTime at,
  String status = 'SCHEDULED',
  int minutes = 45,
  String? agenda = 'Reviewing the scorecard draft',
  String? link = 'https://meet.google.com/icr-demo',
  String side = 'MENTEE',
  String? cancelReason,
  String createdBy = 'u-bharat',
}) => {
  'id': id,
  'mentorshipId': mentorshipId,
  'scheduledAt': iso(at),
  'durationMin': minutes,
  'mode': 'VIDEO',
  'agenda': agenda,
  'meetingLink': link,
  'status': status,
  'completedAt': null,
  'cancelledAt': null,
  'cancelReason': cancelReason,
  'notes': null,
  'recordingUrl': null,
  'summary': null,
  'summaryGeneratedAt': null,
  'createdBy': {'id': createdBy, 'firstName': 'Someone', 'lastName': 'Else'},
  'counterpart': {
    'id': 'u-anand',
    'firstName': 'Anand',
    'lastName': 'Iyer',
    'avatarUrl': null,
    'designation': 'Head of Facilities Strategy',
    'companyName': null,
  },
  'side': side,
  'createdAt': iso(mentoringNow()),
};

Map<String, Object?> requestJson(
  String id, {
  String status = 'PENDING',
  Map<String, Object?>? mentor,
  Map<String, Object?>? mentee,
  String message = 'I would like to learn how you plan workplace experience programmes for a campus.',
  String? responseNote,
  int daysLeft = 10,
  List<String> signals = const [],
}) => {
  'id': id,
  'status': status,
  'message': message,
  'focusAreas': ['Workplace leadership'],
  'matchScore': 61,
  'signals': [
    for (final s in signals) {'label': s},
  ],
  'responseNote': responseNote,
  'respondedAt': null,
  'expiresAt': iso(mentoringNow().add(Duration(days: daysLeft))),
  'createdAt': iso(mentoringNow().subtract(const Duration(days: 2))),
  'mentor': mentor ?? anand,
  'mentee': mentee ?? bharat,
};

Map<String, Object?> goalJson(
  String id, {
  String mentorshipId = 'pair-anand',
  String title = 'Lead my first site audit on my own',
  String status = 'OPEN',
  int progress = 40,
  String? detail,
}) => {
  'id': id,
  'mentorshipId': mentorshipId,
  'title': title,
  'detail': detail,
  'competency': null,
  'targetDate': iso(mentoringNow().add(const Duration(days: 60))),
  'status': status,
  'achievedAt': null,
  'progress': progress,
  'lastProgressAt': null,
  'createdBy': {'id': 'u-bharat', 'firstName': 'Bharat', 'lastName': 'Buyer'},
  'createdAt': iso(mentoringNow()),
  'counterpart': {'id': 'u-anand', 'firstName': 'Anand', 'lastName': 'Iyer'},
};

Map<String, Object?> certificateJson() => {
  'id': 'cert-1',
  'certificateId': 'ICR-MENTEE-2026-BHARATXX',
  'kind': 'MENTEE',
  'title': 'Mentoring completion certificate',
  'counterpartName': 'Divya Rao',
  'programName': null,
  'sessionsCount': 5,
  'hours': 3.75,
  'goalsAchieved': 1,
  'startedAt': iso(mentoringNow().subtract(const Duration(days: 120))),
  'completedAt': iso(mentoringNow().subtract(const Duration(days: 10))),
  'issuedAt': iso(mentoringNow().subtract(const Duration(days: 10))),
  'mentorshipId': 'pair-divya',
  'programId': null,
};

Map<String, Object?> concernJson() => {
  'id': 'concern-1',
  'category': 'UNRESPONSIVE',
  'detail': 'The mentor has not replied for three weeks.',
  'urgent': false,
  'status': 'ACTIONED',
  'outcomeNote': 'We spoke to the mentor and a session is booked.',
  'createdAt': iso(mentoringNow().subtract(const Duration(days: 9))),
  'handledAt': iso(mentoringNow().subtract(const Duration(days: 2))),
  'mentorshipId': 'pair-anand',
  'groupSessionId': null,
};

Map<String, Object?> summaryJson({
  int asMentor = 0,
  int asMentee = 1,
  int incoming = 0,
  int outgoing = 1,
  bool isMentor = false,
  String? mentorStatus,
}) => {
  'activeAsMentor': asMentor,
  'activeAsMentee': asMentee,
  'activeTotal': asMentor + asMentee,
  'pendingIncoming': incoming,
  'pendingOutgoing': outgoing,
  'isMentor': isMentor,
  'mentorStatus': mentorStatus,
  'menteesHelped': 0,
};

Map<String, Object?> page(List<Object?> rows) => {
  'data': rows,
  'meta': {'page': 1, 'limit': 50, 'total': rows.length, 'totalPages': 1, 'hasNext': false, 'hasPrev': false},
};

/// The reads My mentoring makes on first load, for a mentee with one live pairing.
Map<String, Reply> menteeRoutes({
  List<Object?>? pairings,
  List<Object?>? sent,
  List<Object?>? incoming,
  List<Object?>? upcoming,
  Map<String, Object?>? summary,
}) {
  final soon = mentoringNow().add(const Duration(days: 3));
  return {
    'GET /mentorship/summary': (_) => summary ?? summaryJson(),
    'GET /mentorship/mine': (_) => page(pairings ?? [pairingJson('pair-anand')]),
    'GET /mentorship/requests/mine': (_) => page(
      sent ??
          [
            requestJson(
              'req-neha',
              mentor: personJson(
                'u-neha',
                'Neha',
                'Kapoor',
                headline: 'Workplace Experience Manager at Wipro',
                mentorProfileId: 'mp-neha',
              ),
            ),
          ],
    ),
    'GET /mentorship/requests/incoming': (_) => page(incoming ?? []),
    'GET /mentorship/sessions/upcoming': (_) => upcoming ?? [sessionJson('s3', at: soon)],
    'GET /mentorship/mentees/me/access': (_) => {
      'tier': 'FREE',
      'capabilities': {},
      'pendingRequests': 1,
      'pendingRequestLimit': 3,
      'activeMentorships': 1,
      'activeMentorshipLimit': null,
      'canRequest': true,
    },
  };
}

// --- harness -----------------------------------------------------------------------

MentoringRepository repoOf(FakeApi api) => MentoringRepository(api: api.client());

/// What the links did, in order.
class LinkRecorder {
  final opened = <String>[];
  final sites = <String>[];
  final shared = <String>[];

  MentorshipLinks get links => MentorshipLinks(
    openMentor: (context, id) => opened.add('mentor:$id'),
    openDirectory: (context) => opened.add('directory'),
    openNotifications: (context) => opened.add('bell'),
    openConversation: (context, id) async => opened.add('conversation:$id'),
    openSite: (context, path) async => sites.add(path),
    shareFile: (context, name, bytes) async => shared.add('$name:${bytes.length}'),
  );
}

Future<(FakeApi, LinkRecorder)> pumpMyMentoring(
  WidgetTester tester,
  Map<String, Reply> routes, {
  MyTab tab = MyTab.mentoring,
  double height = 2200,
}) async {
  phone(tester, height: height);
  final api = FakeApi(routes);
  final rec = LinkRecorder();
  await pumpApp(tester, MyMentoringScreen(repository: repoOf(api), initialTab: tab, links: rec.links));
  return (api, rec);
}

Future<(FakeApi, LinkRecorder)> pumpPairingScreen(
  WidgetTester tester,
  FakeApi api, {
  String id = 'pair-anand',
  double height = 4200,
  SharePicker? pickFile,
}) async {
  phone(tester, height: height);
  final rec = LinkRecorder();
  await pumpApp(
    tester,
    PairingScreen(id: id, repository: repoOf(api), links: rec.links, pickFile: pickFile ?? pickShareFile),
  );
  return (api, rec);
}
