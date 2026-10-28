/// Helpers for the staff / mentor role pass (`role_staff_live_test.dart`).
///
/// * The three staff accounts' passwords are read from the portal's e2e fixtures at run time
///   (`E:\ICR\irc-portal\e2e\fixtures\users.json`), never written into a file of ours.
/// * [pumpAs] draws one screen the way `lib/app.dart` builds the signed-in app: the same providers
///   (`ApiClient`, `AuthController`, the tab controllers, the mentoring links, the bell's counts), over a
///   client signed in as the person.
/// * [bootApp] draws the whole app (`IcrApp`) for a person who is already signed in.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' show DioException, DioExceptionType, InterceptorsWrapper;
import 'package:dio/io.dart' show IOHttpClientAdapter;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/app.dart';
import 'package:icr_mobile/app_screens.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/auth/auth_controller.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/feed/api_feed_repository.dart';
import 'package:icr_mobile/features/feed/feed_controller.dart';
import 'package:icr_mobile/features/jobs/api_jobs_repository.dart';
import 'package:icr_mobile/features/jobs/jobs_controller.dart';
import 'package:icr_mobile/features/marketplace/api_marketplace_repository.dart';
import 'package:icr_mobile/features/marketplace/marketplace_controller.dart';
import 'package:icr_mobile/features/mentorship/api_mentorship_repository.dart';
import 'package:icr_mobile/features/mentorship/mentorship_controller.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_links.dart';
import 'package:icr_mobile/features/notifications/notifications_bell.dart';
import 'package:provider/provider.dart';

import 'live.dart';

export 'career_live_support.dart' show finishLive, liveScreenReady, mockImageCachePlugins, settleLive;

const _fixtures = r'E:\ICR\irc-portal\e2e\fixtures\users.json';

String? _fixturePassword(String email) {
  final file = File(_fixtures);
  if (!file.existsSync()) return null;
  for (final row in (jsonDecode(file.readAsStringSync()) as List).cast<Map<String, dynamic>>()) {
    if (row['email'] == email) return row['password'] as String?;
  }
  return null;
}

LivePerson _fromFixtures(String email, String label) =>
    LivePerson(email, _fixturePassword(email) ?? '(users.json not found)', label);

/// A SUPER_ADMIN with no company.
final superAdmin = _fromFixtures('superadmin@icr.test', 'Sana Admin (SUPER_ADMIN)');

/// A PROFESSIONAL holding the custom "Content Admin" role (`blogs:manage`, `contact:read`, `contact:manage`).
final contentAdmin = _fromFixtures('contentadmin@icr.test', 'Nadia ContentAdmin');

/// A PROFESSIONAL holding the custom "Support Agent" role (`support:read`, `support:manage`).
final supportAgent = _fromFixtures('supportagent@icr.test', 'Arun SupportAgent');

/// The three staff accounts, with what the portal lets each moderate.
final staffPeople = <LivePerson>[superAdmin, contentAdmin, supportAgent];

/// Srikanth Sriramagiri, the mentor on the profile design: an approved profile, four places, two live mentees.
const srikanth = LivePerson('mentorship.srikanth@design.icr.test', 'Password123!', 'Srikanth Sriramagiri (mentor)');
const srikanthProfileId = 'dsgn-mentorship-mp-srikanth';

/// Rohan Das: a mentee made for the live tests (a profile, no phone, a pairing history already).
const rohan = LivePerson('mentoring.rohan@design.icr.test', 'Password123!', 'Rohan Das (mentee)');

/// Meera Nair: a mentee with a profile who has asked and been answered before.
const meera = LivePerson('mentoring.meera@design.icr.test', 'Password123!', 'Meera Nair (mentee)');

/// A number the API takes as a mobile; a person who sends it with an action gets it saved, so a test clears it.
const aPhone = '9876501234';

/// Pooja Professional's id is not needed; a second ordinary member for "someone else wrote this".
Future<String> idOf(ApiClient api) async => (await api.dio.get<Map<String, dynamic>>('/auth/me')).data!['id'] as String;

/// The providers `_Home` in `lib/app.dart` puts above the shell, over [api] (signed in as the person).
Widget appProviders({required ApiClient api, required Widget child, String? userId}) {
  return MultiProvider(
    providers: [
      Provider<MentorshipLinks>.value(value: appMentorshipLinks),
      ChangeNotifierProvider<FeedController>(
        create: (c) => FeedController(ApiFeedRepository(api: api, viewerId: userId))..start(),
      ),
      ChangeNotifierProvider<MentorshipController>(
        create: (c) => MentorshipController(ApiMentorshipRepository(api: api)),
      ),
      ChangeNotifierProvider<JobsController>(create: (c) => JobsController(ApiJobsRepository(api: api))),
      ChangeNotifierProvider<MarketplaceController>(
        create: (c) => MarketplaceController(ApiMarketplaceRepository(api: api)),
      ),
    ],
    child: InboxHost(api: api, child: child),
  );
}

final _hardened = <ApiClient>{};

/// Waits [d] of real time even inside a widget test, where `Future.delayed` runs on the test's fake clock and
/// never finishes while nobody pumps it.
Future<void> _realDelay(Duration d) {
  final done = Completer<void>();
  Zone.root.createTimer(d, done.complete);
  return done.future;
}

/// The signed-in client for [who] (see `liveClient`), with two guards that also hold when a screen made the call
/// inside a widget test:
///
/// * a "too many requests" (the shared API allows 120 a minute per address) is waited out in real time and sent
///   again, up to eight times, as `liveClient` does but on the real clock;
/// * a request that fails because the API closed an idle keep-alive connection is sent again, as a phone would.
///
/// Applied once per client, ahead of the others.
Future<ApiClient> clientFor(LivePerson who, [bool fresh = false]) async {
  final api = await liveClient(who, fresh);
  if (_hardened.add(api)) {
    // No connection is kept for the next request. A kept one belongs to the zone that opened it (a screen's, on the
    // test's fake clock, or a helper's, on the real one), and the other zone's request on it never gets its answer.
    api.dio.httpClientAdapter = IOHttpClientAdapter(createHttpClient: () => HttpClient()..idleTimeout = Duration.zero);
    api.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onError: (error, handler) async {
          final options = error.requestOptions;
          final throttled = error.response?.statusCode == 429;
          final dropped =
              error.response == null &&
              (error.type == DioExceptionType.connectionError || error.type == DioExceptionType.unknown);
          final tries = (options.extra['staffRetry'] as int?) ?? 0;
          if ((!throttled && !dropped) || tries >= (throttled ? 8 : 2)) return handler.next(error);
          options.extra['staffRetry'] = tries + 1;
          final wait = throttled
              ? (int.tryParse(error.response?.headers.value('retry-after') ?? '') ?? 8).clamp(2, 30)
              : 0;
          await _realDelay(throttled ? Duration(seconds: wait) : const Duration(milliseconds: 100));
          try {
            handler.resolve(await api.dio.fetch<dynamic>(options));
          } on DioException catch (again) {
            handler.next(again);
          }
        },
      ),
    );
  }
  return api;
}

/// Draws [screen] as [who] sees it, over the live API, and lets it finish loading.
///
/// `ApiClient` and `AuthController` sit above the `MaterialApp`, as in `IcrApp`, so a screen pushed from the one
/// drawn here still finds them; the tab controllers sit inside it, as `_Home` has them.
Future<ApiClient> pumpAs(
  WidgetTester tester,
  LivePerson who,
  Widget Function(BuildContext context) screen, {
  Size size = const Size(390, 900),
}) async {
  final api = (await tester.runAsync(() => clientFor(who)))!;
  final me = (await tester.runAsync(() => idOf(api)))!;
  final auth = AuthController(api: api, tokens: api.tokens);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      // A new tree each time: a second screen drawn over the first would otherwise keep the first one's state
      // (and its repository, signed in as the previous person).
      key: UniqueKey(),
      providers: [
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<AuthController>.value(value: auth),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: appProviders(
          api: api,
          userId: me,
          child: Builder(builder: screen),
        ),
      ),
    ),
  );
  await tester.runAsync(() => auth.restore());
  return api;
}

/// Draws the whole app for [who] (a fresh sign-in; the app signs itself in from the saved session).
Future<ApiClient> bootApp(WidgetTester tester, LivePerson who, {Size size = const Size(390, 844)}) async {
  final api = (await tester.runAsync(() => clientFor(who, true)))!;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(IcrApp(tokens: api.tokens));
  return api;
}

/// Lets real time pass between frames until [finder] matches (or [timeout] is up); true when it matched.
Future<bool> pumpUntil(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  final until = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(until)) {
    if (finder.evaluate().isNotEmpty) return true;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  return finder.evaluate().isNotEmpty;
}

/// Lets real time pass until nothing is loading and the words on screen stopped changing for [quiet] looks
/// (a skeleton or a list that arrives late shows no spinner, so "no spinner" alone ends too early). A [ready]
/// says what the caller is waiting for, when the words alone cannot tell (a sheet that says "Sending…" until the
/// API answers).
Future<void> settle(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 15),
  int quiet = 3,
  bool Function()? ready,
}) async {
  final until = DateTime.now().add(timeout);
  String? last;
  var same = 0;
  while (DateTime.now().isBefore(until)) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    // 120 ms of the test clock a look, so a sheet that slides in (250 ms) is in place by the third.
    await tester.pump(const Duration(milliseconds: 120));
    final spinning = loadingSpinners().evaluate().isNotEmpty;
    final signature = shownTexts().join('');
    if (!spinning && signature == last && (ready == null || ready())) {
      if (++same >= quiet) return;
    } else {
      same = 0;
      last = signature;
    }
  }
}

/// The shared API allows 120 calls a minute per address, and other test runs share it, so a screen can meet a
/// "too many requests" and offer Try again, as it would to a person. Presses it up to [times] times (and says
/// so), so what is left is a screen that really cannot load.
Future<void> retryWhileFailed(WidgetTester tester, {int times = 3, String? what}) async {
  for (var i = 0; i < times; i++) {
    final again = find.text('Try again');
    if (again.evaluate().isEmpty) return;
    // ignore: avoid_print
    print(
      '[retry ${i + 1}] ${what ?? 'screen'} offered Try again: ${shownTexts().where((t) => t.isNotEmpty).take(12).toList()}',
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 4)));
    await tester.tap(again.first);
    await settle(tester);
  }
}

/// Scrolls the screen's vertical list until [what] is built and on screen, whichever way it lies (a long list builds
/// only what it shows, so a card above or below the view is not there to find until it is scrolled to).
Future<void> bringIntoView(WidgetTester tester, Finder what) async {
  final list = find
      .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical, description: 'a vertical list')
      .first;
  Future<void> clearOfTheEdge() async {
    // ensureVisible stops when the widget touches the edge of the list, which can be the edge of the window.
    final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    for (var i = 0; i < 6; i++) {
      final y = tester.getCenter(what.first).dy;
      if (y >= 100 && y <= height - 110) return;
      final move = y > height - 110 ? -(y - (height - 220)) : (140 - y);
      await tester.drag(list, Offset(0, move), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
      if ((tester.getCenter(what.first).dy - y).abs() < 1) return;
    }
  }

  if (what.evaluate().isNotEmpty) {
    await tester.ensureVisible(what.first);
    await tester.pump(const Duration(milliseconds: 100));
    await clearOfTheEdge();
    return;
  }
  for (final step in const [-300.0, 300.0]) {
    try {
      await tester.scrollUntilVisible(what, step, scrollable: list, maxScrolls: 60);
      await tester.pump(const Duration(milliseconds: 100));
      await clearOfTheEdge();
      return;
    } on StateError {
      // not that way
    }
  }
}

/// True when the frame holds no framework exception; the message when it does.
String? thrown(WidgetTester tester) {
  final e = tester.takeException();
  return e?.toString();
}

/// The text of every `Text` widget on screen, for "the screen says X" checks.
Iterable<String> shownTexts() => find
    .byType(Text)
    .evaluate()
    .map((e) => (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText() ?? '');

/// Raw exception text, an error state, or an endless spinner: what a finished screen must not show.
const _errorMarkers = [
  'DioException',
  'Exception:',
  'type \'Null\'',
  'is not a subtype',
  'RangeError',
  'NoSuchMethodError',
  'Bad state',
  'StateError',
  'FormatException',
  'Null check operator',
];

/// Fails the test when the screen shows the raw text of an exception or a framework error.
void expectNoRawErrors(WidgetTester tester, String what) {
  final shown = shownTexts().toList();
  for (final marker in _errorMarkers) {
    expect(shown.where((t) => t.contains(marker)), isEmpty, reason: '$what shows raw error text ($marker)');
  }
  expect(find.byType(ErrorWidget), findsNothing, reason: '$what drew a red screen');
}

/// Everything the page shows has settled: no spinner left.
void expectNoSpinner(String what) => expect(loadingSpinners(), findsNothing, reason: '$what is still loading');

/// A spinner that is waiting on something. A ring with a value (a score drawn as a ring) is a figure, not a wait.
Finder loadingSpinners() =>
    find.byWidgetPredicate((w) => w is CircularProgressIndicator && w.value == null, description: 'a loading spinner');

/// The two staff accounts hold their powers through custom roles (`Content Admin`, `Support Agent`) that the
/// portal's `db:seed:access` creates. A local database that never ran that seed has no roles at all, which makes
/// them plain members. This makes the starter roles through the access API as the SUPER_ADMIN (what the seed does,
/// and what `/admin/roles` does on the website), assigns them, and [restore] takes back what it made.
class StaffRoles {
  StaffRoles._();

  static final _madeRoles = <String>[];
  static final _assigned = <String>[];

  /// True when this database has no permission catalogue (`db:seed:access` never ran): no role can be made, so
  /// the two accounts are plain members here and the tests expect exactly that.
  static bool catalogueMissing = false;

  static const _defs = <(String email, String name, String description, List<String> keys)>[
    (
      'contentadmin@icr.test',
      'Content Admin',
      'Manages the public blog and the contact inbox.',
      ['blogs:manage', 'contact:read', 'contact:manage'],
    ),
    (
      'supportagent@icr.test',
      'Support Agent',
      'Works the support queue: answers, assigns and closes tickets.',
      ['support:read', 'support:manage'],
    ),
  ];

  /// Makes and assigns the roles that are missing. Safe to call twice.
  static Future<void> ensure() async {
    if (!await liveApiReachable()) return;
    final admin = await clientFor(superAdmin);
    final existing = ((await admin.dio.get<List<dynamic>>('/access/roles')).data ?? const [])
        .cast<Map<String, dynamic>>();
    for (final (email, name, description, keys) in _defs) {
      final person = email == contentAdmin.email ? contentAdmin : supportAgent;
      final userId = await idOf(await clientFor(person));
      var roleId = existing.where((r) => r['name'] == name).map((r) => r['id'] as String).firstOrNull;
      if (roleId == null) {
        try {
          final made = await admin.dio.post<Map<String, dynamic>>(
            '/access/roles',
            data: {'name': name, 'description': description, 'permissionKeys': keys},
          );
          roleId = made.data!['id'] as String;
          _madeRoles.add(roleId);
        } on DioException catch (e) {
          if (e.response?.statusCode == 404 && '${e.response?.data}'.contains('db:seed:access')) {
            catalogueMissing = true;
            return;
          }
          rethrow;
        }
      }
      final held = ((await admin.dio.get<List<dynamic>>('/access/users/$userId/roles')).data ?? const [])
          .cast<Map<String, dynamic>>()
          .map((r) => r['id'] as String)
          .toList();
      if (!held.contains(roleId)) {
        await admin.dio.put<dynamic>(
          '/access/users/$userId/roles',
          data: {
            'roleIds': [...held, roleId],
          },
        );
        _assigned.add('$userId|$roleId');
      }
    }
  }

  /// Takes back the assignments and the roles [ensure] made.
  static Future<void> restore() async {
    if (_assigned.isEmpty && _madeRoles.isEmpty) return;
    if (!await liveApiReachable()) return;
    final admin = await clientFor(superAdmin);
    for (final entry in _assigned) {
      final parts = entry.split('|');
      final held = ((await admin.dio.get<List<dynamic>>('/access/users/${parts[0]}/roles')).data ?? const [])
          .cast<Map<String, dynamic>>()
          .map((r) => r['id'] as String)
          .where((id) => id != parts[1])
          .toList();
      await admin.dio.put<dynamic>('/access/users/${parts[0]}/roles', data: {'roleIds': held});
    }
    for (final id in _madeRoles) {
      await admin.dio.delete<dynamic>('/access/roles/$id');
    }
    _assigned.clear();
    _madeRoles.clear();
  }
}
