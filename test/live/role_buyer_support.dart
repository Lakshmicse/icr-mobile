/// Shared pieces of the BUYER / PROFESSIONAL role matrix (`role_buyer_live_test.dart`,
/// `docs/ROLE_TEST_buyer.md`): the four accounts that belong to no company, and the
/// helpers every flow group uses.
///
/// The passwords are never written here: the e2e fixtures hold them, and
/// [roleBuyerPeople] reads that file when the tests run (Bharat's and Pooja's are the
/// app's own constants in `live.dart`).
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'career_live_support.dart';
import 'live.dart';

/// The e2e fixtures, relative to this package and (for a run from elsewhere) absolute.
const _fixtureCandidates = ['../irc-portal/e2e/fixtures/users.json', 'E:/ICR/irc-portal/e2e/fixtures/users.json'];

String? _fixturePassword(String email) {
  for (final path in _fixtureCandidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final rows = jsonDecode(file.readAsStringSync()) as List<dynamic>;
    for (final row in rows.cast<Map<String, dynamic>>()) {
      if (row['email'] == email) return row['password'] as String?;
    }
  }
  return null;
}

/// Bhavna Buyer: the e2e BUYER, no company, a phone number on file.
LivePerson? get bhavna => _person('buyer@icr.test', 'Bhavna Buyer (BUYER)');

/// Gita Guest: a person with no company and nothing set up (the retired GUEST persona).
LivePerson? get gita => _person('guest@icr.test', 'Gita Guest (no company, nothing set up)');

LivePerson? _person(String email, String label) {
  final password = _fixturePassword(email);
  return password == null ? null : LivePerson(email, password, label);
}

/// Sana Admin, ICR staff: used only to put away what a member cannot (a report, a contact message).
LivePerson? get sana => _person('superadmin@icr.test', 'Sana Admin (staff)');

/// The four accounts of this role, in the order the report lists them. An account whose
/// password the fixtures do not hold is left out (and the test says so).
List<LivePerson> roleBuyerPeople() => [?bhavna, bharat, pooja, ?gita];

/// One account, as the matrix names it.
String who(LivePerson p) => p.email;

/// A row of the report: what a flow did for an account.
class RoleRow {
  RoleRow(this.flow, this.account, this.verdict, [this.note = '']);

  final String flow;
  final String account;

  /// `works`, `refused correctly`, `bug fixed`, `bug open` or `gap`.
  final String verdict;
  final String note;

  @override
  String toString() => '$flow | $account | $verdict | $note';
}

/// The rows a run collected; printed at the end so they can be copied into the report.
final roleRows = <RoleRow>[];

void record(String flow, LivePerson person, String verdict, [String note = '']) =>
    roleRows.add(RoleRow(flow, person.email, verdict, note));

/// Prints the matrix (it appears in the test output, under `-r expanded`).
void printRoleRows() {
  for (final r in roleRows) {
    // ignore: avoid_print
    print('ROLE_ROW $r');
  }
}

/// One signed-in account of the matrix: its client and its id, opened once per test file.
class Who {
  Who._(this.person, this.api, this.id, this.me);

  final LivePerson person;
  final ApiClient api;
  final String id;

  /// `GET /auth/me` when it was opened.
  final Map<String, dynamic> me;

  String get email => person.email;
  String get first => (me['firstName'] as String?) ?? person.label;
  String? get phone => me['phone'] as String?;

  static final _open = <String, Future<Who>>{};

  static Future<Who> of(LivePerson person) => _open.putIfAbsent(person.email, () async {
    final api = await liveClient(person);
    api.dio.interceptors.add(_reconnect(api.dio));
    final me = (await api.dio.get<Map<String, dynamic>>('/auth/me')).data!;
    return Who._(person, api, me['id'] as String, me);
  });
}

/// A screen test lets seconds pass between requests (the test clock is wound forward), and the API drops an idle
/// connection after five: the next request on it fails before it is sent. Ask again on a fresh connection.
Interceptor _reconnect(Dio dio) => InterceptorsWrapper(
  onError: (error, handler) async {
    final tries = (error.requestOptions.extra['reconnects'] as int?) ?? 0;
    final dropped = error.response == null && error.type != DioExceptionType.cancel;
    if (!dropped || tries >= 2) return handler.next(error);
    error.requestOptions.extra['reconnects'] = tries + 1;
    try {
      handler.resolve(await dio.fetch<dynamic>(error.requestOptions));
    } on DioException catch (again) {
      handler.next(again);
    }
  },
);

/// Every account of this role, opened.
Future<List<Who>> everyone() async => [for (final p in roleBuyerPeople()) await Who.of(p)];

/// The sentence a refused call carries (`ApiError`'s), or the exception's text.
String sentenceOf(Object e) => ApiError.from(e).message;

/// The status code of a refused call, if it got an answer.
int? statusOf(Object e) => ApiError.from(e).statusCode;

/// Expects [action] to throw and returns what it threw.
Future<Object> thrownBy(Future<Object?> Function() action) async {
  try {
    await action();
  } catch (e) {
    return e;
  }
  fail('expected a refusal, but the call went through');
}

// ---- Screens ---------------------------------------------------------------------------------

/// Pumps a real [screen] in a phone-sized window, under the app's theme. [providers] sit above the screen (below
/// the navigator, like the tabs' controllers); [appProviders] sit above the whole app, where `IcrApp` keeps the
/// API client and the session, so a route pushed over the screen can reach them.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<SingleChildWidget> providers = const [],
  List<SingleChildWidget> appProviders = const [],
  Size size = const Size(390, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final home = providers.isEmpty ? screen : MultiProvider(providers: providers, child: screen);
  final app = MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(), home: home);
  await tester.pumpWidget(appProviders.isEmpty ? app : MultiProvider(providers: appProviders, child: app));
}

/// Takes the screen down and lets the idle HTTP timers of its requests run out.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await finishLive(tester);
}

/// Words that mean a screen is showing a failure, not content (compared in lower case; a regular expression
/// this long makes the Dart VM run out of memory compiling it).
const _failureWords = [
  "couldn't load",
  'could not load',
  'something went wrong',
  'exception',
  'is not a subtype',
  'null check',
  'dioexception',
  'rangeerror',
  'formatexception',
  'nosuchmethod',
  'instance of',
];

/// Every piece of text on the screen, one string.
String screenText(WidgetTester tester) {
  final out = StringBuffer();
  for (final e in find.byType(Text).evaluate()) {
    final w = e.widget as Text;
    out.writeln(w.data ?? w.textSpan?.toPlainText() ?? '');
  }
  for (final e in find.byType(RichText).evaluate()) {
    out.writeln((e.widget as RichText).text.toPlainText());
  }
  return out.toString();
}

/// The screen drew without a framework error and shows no failure words ([allow] names the ones a state
/// legitimately says). Returns the screen's text for further checks.
String expectHealthy(WidgetTester tester, String what, {List<String> allow = const []}) {
  final error = tester.takeException();
  expect(error, isNull, reason: '$what threw: $error');
  final text = screenText(tester);
  final lower = text.toLowerCase();
  for (final word in _failureWords) {
    var at = lower.indexOf(word);
    while (at >= 0) {
      final hit = text.substring(at, (at + word.length + 40).clamp(0, text.length)).split(newline).first;
      if (!allow.any((a) => hit.toLowerCase().contains(a.toLowerCase()))) {
        fail('$what shows a failure: "$hit"');
      }
      at = lower.indexOf(word, at + word.length);
    }
  }
  return text;
}

/// Pumps and waits for a screen over real HTTP.
Future<void> loadScreen(
  WidgetTester tester,
  Widget screen, {
  List<SingleChildWidget> providers = const [],
  List<SingleChildWidget> appProviders = const [],
  Size size = const Size(390, 900),
  Duration timeout = const Duration(seconds: 15),
}) async {
  await pumpScreen(tester, screen, providers: providers, appProviders: appProviders, size: size);
  await settleLive(tester, timeout: timeout);
}

/// A line break (spelled out so a source writer cannot turn the escape into a real one).
final newline = String.fromCharCode(10);

/// After a tap that opens or closes a sheet or a route: lets the request finish, then runs the animation out.
Future<void> afterTap(WidgetTester tester) async {
  // A sheet may open only after the requests it needs have answered, so the wait and the animation run twice.
  for (var i = 0; i < 2; i++) {
    await settleLive(tester);
    await tester.pump(const Duration(milliseconds: 900));
  }
}

/// Waits in real time (frames pumped between) until [finder] matches something, or [timeout] is up. For a screen
/// that draws skeleton cards instead of a spinner while it loads, which [settleLive] cannot see.
Future<void> waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  final until = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(until)) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Takes a contact message (and the lead the API filed for it) found by its [marker] out of the ICR inbox as far
/// as the API allows: the lead is deleted and the message set to SPAM. Staff only; a no-op without staff.
Future<void> putAwayContact(String marker, {String? topic}) async {
  final staff = sana;
  if (staff == null) return;
  final admin = await liveClient(staff);
  final res = await admin.dio.get<Map<String, dynamic>>(
    '/contact',
    queryParameters: {'topic': ?topic, 'search': marker, 'limit': 20},
  );
  for (final row in (res.data!['data'] as List).cast<Map<String, dynamic>>()) {
    final lead = (row['lead'] as Map?)?['id'] as String?;
    if (lead != null) await admin.dio.delete<dynamic>('/crm/leads/$lead');
    await admin.dio.patch<dynamic>('/contact/${row['id']}/status', data: {'status': 'SPAM'});
  }
}

/// Runs [call]; a refused call is rethrown with [what] and the API's own body, so a failing test says what failed.
Future<T> described<T>(String what, Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw StateError(
      '$what: ${e.requestOptions.method} ${e.requestOptions.path} -> ${e.response?.statusCode} ${e.response?.data}',
    );
  }
}
