/// The profile menu against the LOCAL portal API, seeded by `tool/seed/home.ts` (and `events-councils.ts`, which
/// gives Bharat Buyer his council seats and his 8.5 CPD hours this year): the app's own controller and drawer,
/// the way the app uses them, with each line read back through the API.
///
/// Everything here is a read, except Sign Out: that signs in as Pooja Professional with a throwaway session of
/// its own, signs out, and confirms the API refuses the refresh token afterwards. Bharat's state is never
/// touched.
///
///     flutter test test/live/profile_menu_live_test.dart
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/auth/auth_controller.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/profile/profile_drawer.dart';
import 'package:icr_mobile/features/profile/profile_drawer_data.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';
import 'live.dart';

/// Bharat's menu, loaded from the API once and shared by the tests that only read it.
Future<({ApiClient api, String id, ProfileDrawerController menu})>? _bharatMenu;

Future<({ApiClient api, String id, ProfileDrawerController menu})> _menuFor(LivePerson who) async {
  final api = await liveClient(who);
  final id = (await api.dio.get<Map<String, dynamic>>('/auth/me')).data!['id'] as String;
  final menu = ProfileDrawerController.live(
    api: api,
    userId: id,
    // The menu's own seed: the session's name and seal; the photo and cover are bundled twins, so that a render
    // needs no network (the API's own addresses are still read and checked below).
    seed: const ProfileDrawerData(
      name: 'Bharat Buyer',
      verified: true,
      photoAsset: 'assets/images/demo/avatar_me.jpg',
      coverAsset: 'assets/images/demo/cover_town.jpg',
    ),
  );
  await menu.refresh();
  return (api: api, id: id, menu: menu);
}

bool _seeded(ProfileDrawerData d) {
  if (d.headline == 'Lead Operations Manager at TechCorp') return true;
  markTestSkipped('the profile menu is not seeded: run tool/seed/run.ps1');
  return false;
}

void main() {
  setUpAll(loadAppFonts);

  liveTest(
    'every line of the menu is read from the API: headline, place, connections, views, impressions, chapters, councils, CPD',
    () async {
      final me = await (_bharatMenu ??= _menuFor(bharat));
      final d = me.menu.data;
      if (!_seeded(d)) return;

      // The raw answers, read again here.
      final profile = (await me.api.dio.get<Map<String, dynamic>>('/users/me/profile')).data!;
      final member = (await me.api.dio.get<Map<String, dynamic>>('/members/${me.id}')).data!;
      final performance = (await me.api.dio.get<Map<String, dynamic>>('/users/me/profile-performance')).data!;
      final cpd = (await me.api.dio.get<Map<String, dynamic>>('/mentorship/cpd/summary')).data!;
      final threads = (await me.api.dio.get<Map<String, dynamic>>(
        '/forum/threads',
        queryParameters: {'authorId': me.id, 'limit': 100},
      )).data!;

      // Under the name: the headline on his profile, then "place · connections".
      expect(d.name, 'Bharat Buyer');
      expect(d.verified, isTrue);
      expect(d.headline, (profile['user'] as Map)['designation']);
      expect(d.headline, 'Lead Operations Manager at TechCorp');
      expect(d.location, member['city']);
      expect(d.location, 'Bengaluru, Karnataka');
      final follow = member['follow'] as Map;
      expect(d.connections, (follow['followers'] as int) + (follow['following'] as int));
      expect(d.connections, greaterThan(100), reason: 'every other account follows him');
      expect(d.locationLine, 'Bengaluru, Karnataka · ${d.connectionsLabel}');

      // The two counts: recruiters who opened the profile, and how often his discussions were opened.
      expect(d.profileViews, performance['profileViewsTotal']);
      expect(d.profileViews, 42);
      final impressions = (threads['data'] as List).fold<int>(0, (n, t) => n + ((t as Map)['viewCount'] as int));
      expect(d.postImpressions, impressions);
      expect(d.postImpressions, 1204);

      // The three rows.
      final chapters = (member['chapters'] as List).cast<Map<String, dynamic>>();
      expect(d.chapterCities, chapters.map((c) => c['city']));
      expect(d.chaptersLine, 'Bengaluru, Pune, New Jersey');
      expect(d.chapterCode, 'BLR');
      final councils = (member['councils'] as List).cast<Map<String, dynamic>>();
      expect(d.councilNames, councils.map((c) => c['name']));
      expect(d.councilsLine, 'Sustainability, ESG & Net-Zero +2');
      expect(d.cpdHours, cpd['totalHours']);
      expect(
        d.cpdLabel,
        '+12 CPD',
        reason: 'the Events seed\'s 8.5 hours this year and the Home seed\'s 3.5 of last year',
      );
      expect(cpd['hoursThisYear'], 8.5, reason: 'the Events board\'s own year is untouched');

      // His pages: the profile slug resolves, the banner and the photo are uploads the API serves.
      expect(d.profilePath, '/members/bharat-buyer');
      final slug = (await me.api.dio.get<Map<String, dynamic>>('/members/bharat-buyer')).data!;
      expect(slug['id'], me.id);
      expect(d.coverUrl, endsWith('/uploads/design-home-cover_town.jpg'));
      for (final url in [d.coverUrl!, d.photoUrl!]) {
        final res = await me.api.dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
        expect(res.statusCode, 200);
        expect(res.data, isNotEmpty);
      }
    },
  );

  liveTest('the menu\'s endpoints fail on their own: a person the API does not know still gets a drawer', () async {
    final api = liveAnonymous();
    final menu = ProfileDrawerController.live(
      api: api,
      userId: 'no-such-member',
      seed: const ProfileDrawerData(name: 'Visitor'),
    );
    await menu.refresh();
    final d = menu.data;
    // Signed out, the profile and the CPD reads are refused; the unknown member is not found: nothing is made up.
    expect(d.name, 'Visitor');
    expect(d.headline, isNull);
    expect(d.connections, isNull);
    expect(d.profileViews, isNull);
    expect(d.cpdLabel, isNull);
    expect(d.chaptersLine, isNull);
    expect(menu.loaded, isTrue);
  });

  liveTest(
    'Sign Out really ends the session: a throwaway sign-in as Pooja, then the API refuses its refresh token',
    () async {
      final tokens = MemoryTokens();
      final auth = AuthController(
        api: ApiClient(tokens: tokens, baseUrl: liveBaseUrl),
        tokens: tokens,
      );
      await auth.signIn(email: pooja.email, password: pooja.password, rememberMe: false);
      expect(auth.status, SessionStatus.signedIn);
      final refresh = (await tokens.refreshToken())!;
      expect(refresh, isNotEmpty);

      await auth.signOut();
      expect(auth.status, SessionStatus.signedOut);
      expect(await tokens.refreshToken(), isNull);
      expect(await tokens.accessToken(), isNull);

      // The old refresh token is dead: the API will not swap it for a new pair.
      await expectLater(
        liveAnonymous().dio.post<dynamic>('/auth/refresh', data: {'refreshToken': refresh}),
        throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 401)),
      );
    },
  );

  group('the drawer, drawn from the live API', () {
    testWidgets('the menu reads as the design, with the local database\'s content', tags: const ['live'], (
      tester,
    ) async {
      if (!(await tester.runAsync(liveApiReachable))!) {
        markTestSkipped('the local API is not running at $liveBaseUrl');
        return;
      }
      final me = (await tester.runAsync(() => _bharatMenu ??= _menuFor(bharat)))!;
      if (!_seeded(me.menu.data)) return;
      tester.view.physicalSize = const Size(614, 1520);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final tokens = MemoryTokens();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => AuthController(
                  api: ApiClient(tokens: tokens),
                  tokens: tokens,
                ),
              ),
              ChangeNotifierProvider.value(value: me.menu),
            ],
            child: const Scaffold(backgroundColor: Colors.white, body: ProfileDrawer()),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage((element.widget as Image).image, element);
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The design's lines, in its words, with the database's figures.
      expect(find.text('Bharat Buyer'), findsOneWidget);
      expect(find.text('Lead Operations Manager at TechCorp'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^Bengaluru, Karnataka · \d+\+? Connections$')), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Profile Views'), findsOneWidget);
      expect(find.text('1,204'), findsOneWidget);
      expect(find.text('Post Impressions'), findsOneWidget);
      expect(find.text('View Full Profile'), findsNothing, reason: 'the photo and the name open the profile');
      expect(find.text('Regional Chapters'), findsOneWidget);
      expect(find.text('Bengaluru, Pune, New Jersey'), findsOneWidget);
      expect(find.text('BLR'), findsOneWidget);
      expect(find.text('Working Councils'), findsOneWidget);
      expect(find.text('Sustainability, ESG & Net-Zero +2'), findsOneWidget);
      expect(find.text('Get Involved & Volunteer'), findsOneWidget);
      expect(find.text('+12 CPD'), findsOneWidget);
      expect(find.text('MY ACTIVITY'), findsOneWidget);
      expect(find.text('Saved Items & Jobs'), findsOneWidget);
      expect(find.text('My RFQ Requirements'), findsOneWidget);
      expect(find.text('Certificates & Badges'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.ancestor(of: find.byType(ProfileDrawer), matching: find.byType(RepaintBoundary)).first,
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/screens').createSync(recursive: true);
        File('build/screens/profile_menu_live.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    });

    testWidgets(
      'Sign Out in the menu signs a throwaway Pooja session out, and the API then refuses its token',
      tags: const ['live'],
      (tester) async {
        if (!(await tester.runAsync(liveApiReachable))!) {
          markTestSkipped('the local API is not running at $liveBaseUrl');
          return;
        }
        final tokens = MemoryTokens();
        final api = ApiClient(tokens: tokens, baseUrl: liveBaseUrl);
        // A widget test's own zone has no network, so the sign-out the drawer asks for runs on the real event loop.
        final realZone = (await tester.runAsync(() async => Zone.current))!;
        final auth = _SignOutInZone(api: api, tokens: tokens, zone: realZone);
        var loggedOut = false;
        api.dio.interceptors.add(
          InterceptorsWrapper(
            onResponse: (response, handler) {
              if (response.requestOptions.path == '/auth/logout') loggedOut = true;
              handler.next(response);
            },
            onError: (error, handler) {
              if (error.requestOptions.path == '/auth/logout') loggedOut = true;
              handler.next(error);
            },
          ),
        );
        final refresh = await tester.runAsync(() async {
          await auth.signIn(email: pooja.email, password: pooja.password, rememberMe: false);
          return tokens.refreshToken();
        });
        expect(refresh, isNotNull);

        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(tester.view.reset);
        final scaffold = GlobalKey<ScaffoldState>();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthController>.value(value: auth),
              ChangeNotifierProvider(create: (_) => ProfileDrawerController.demo()),
            ],
            child: MaterialApp(
              theme: buildAppTheme(),
              home: Scaffold(key: scaffold, drawer: const ProfileDrawer(), body: const Text('the page')),
            ),
          ),
        );
        scaffold.currentState!.openDrawer();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sign Out'));
        await tester.pumpAndSettle();
        // The logout goes out and comes back on the real event loop: wait on it there.
        await tester.runAsync(() async {
          for (var i = 0; i < 300 && !loggedOut; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
        });
        expect(loggedOut, isTrue, reason: 'the API answered the logout');

        expect(auth.status, SessionStatus.signedOut);
        expect(await tokens.refreshToken(), isNull);

        final refused = await tester.runAsync(() async {
          try {
            await liveAnonymous().dio.post<dynamic>('/auth/refresh', data: {'refreshToken': refresh});
            return null;
          } on DioException catch (e) {
            return e.response?.statusCode;
          }
        });
        expect(refused, 401, reason: 'the refresh token was revoked');
      },
    );
  });
}

/// The real [AuthController], with its sign-out run in a given zone: the drawer's button calls it from a widget
/// test's own zone, which cannot reach the network.
class _SignOutInZone extends AuthController {
  _SignOutInZone({required super.api, required super.tokens, required this.zone});

  final Zone zone;

  @override
  Future<void> signOut() => zone.run(() => super.signOut());
}
