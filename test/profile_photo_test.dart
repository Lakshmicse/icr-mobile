import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:icr_mobile/features/account/account_models.dart';
import 'package:icr_mobile/features/account/profile/my_profile_screen.dart';
import 'package:icr_mobile/features/account/widgets/account_kit.dart' show CoverBand;
import 'package:icr_mobile/features/account/widgets/photo_picker.dart';
import 'package:icr_mobile/features/feed/session_viewer.dart';
import 'package:icr_mobile/features/feed/widgets/feed_avatar.dart';
import 'package:icr_mobile/features/feed/widgets/home_header.dart';
import 'package:icr_mobile/features/profile/profile_drawer_data.dart';
import 'package:icr_mobile/features/shell/app_shell.dart';

import 'helpers/account_harness.dart';
import 'helpers/fonts.dart';

/// Changing one's own profile photo from the app. The API takes the upload and the `PATCH /users/me` (proved against the
/// local portal: `POST /uploads`, then `{ avatarUrl }`, then `GET /auth/me` answers the new address); what failed
/// the person was everything AFTER that: the shell built each tab once and kept it, so the Home header and the other
/// tabs went on drawing the old photo, and the profile menu read its photo once and never again. And a photo from
/// a phone's camera is often over the 5 MB the screen allowed, which was refused instead of shrunk.
void main() {
  setUpAll(() async {
    await loadAppFonts();
    CoverBand.loadArt = false;
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
  }

  /// A photo comes through `cached_network_image`, which wants the phone's file system and a SQLite index; the two
  /// plugin channels answer just enough for it to run (the picture itself cannot be fetched in a widget test, so the
  /// avatar falls back to initials, and what these tests read is the address it was given).
  void mockImageCache() {
    final root = Directory.systemTemp.createTempSync('icr-photo-test');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => root.path,
    );
    messenger.setMockMethodCallHandler(const MethodChannel('com.tekartik.sqflite'), (call) async {
      switch (call.method) {
        case 'getDatabasesPath':
          return root.path;
        case 'openDatabase':
          return 1;
        case 'query':
          return <String, Object?>{'columns': <String>[], 'rows': <Object?>[]};
        case 'insert':
        case 'update':
        case 'batch':
          return 1;
        default:
          return null;
      }
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
      messenger.setMockMethodCallHandler(const MethodChannel('com.tekartik.sqflite'), null);
    });
  }

  /// The portal, as far as the photo goes: the picture is stored, `PATCH /users/me` makes it the avatar, and the
  /// session and the profile both read it back.
  group('from the profile page to every place the photo shows', () {
    late AccountHarness h;
    var avatar = '/uploads/old.jpg';
    final uploads = <ApiCall>[];

    Map<String, dynamic> me() => {...userJson(first: 'Anita', last: 'Rao'), 'avatarUrl': avatar};

    Map<String, dynamic> profile() => {
      'user': {...me(), 'designation': 'Analyst', 'profileSlug': 'anita-rao'},
      'resume': {'jobTitle': 'Analyst'},
      'completeness': {'score': 60, 'missing': <String>[]},
    };

    setUp(() {
      mockImageCache();
      avatar = '/uploads/old.jpg';
      uploads.clear();
      h = AccountHarness(
        routes: {
          'GET /auth/me': (_) => me(),
          'GET /users/me/profile': (_) => profile(),
          'GET /profile/experience': (_) => <Object?>[],
          'GET /profile/education': (_) => <Object?>[],
          'GET /profile/career-breaks': (_) => <Object?>[],
          'GET /profile/links': (_) => <String, Object?>{},
          'GET /credentials/me': (_) => {'credentials': <Object?>[]},
          'POST /uploads': (call) {
            uploads.add(call);
            return {'url': '/uploads/new-photo.png', 'name': 'me.png', 'size': 64, 'mimeType': 'image/png'};
          },
          'PATCH /users/me': (call) {
            avatar = call.json['avatarUrl'] as String;
            return profile();
          },
        },
      );
    });

    PickedPhoto photo() => PickedPhoto(bytes: List.filled(64, 7), name: 'me.png');

    FeedAvatar headerAvatar(WidgetTester tester) =>
        tester.widget<FeedAvatar>(find.descendant(of: find.byType(HomeHeader), matching: find.byType(FeedAvatar)));

    /// Signs in; the session is then read from what the portal holds NOW (`signIn` pins the answer it was given).
    Future<void> signIn(WidgetTester tester) async {
      await h.signIn(tester, me());
      h.api.routes['GET /auth/me'] = (_) => me();
    }

    Future<void> pumpApp(WidgetTester tester) async {
      usePhone(tester);
      await signIn(tester);
      await tester.pumpWidget(
        h.app(
          AppShell(
            // The Home tab, as `lib/app.dart` builds it: from the session as it is now.
            home: SessionViewer(
              builder: (ctx, viewer) => Scaffold(
                body: Column(
                  children: [
                    HomeHeader(
                      photo: viewer.photo,
                      initials: viewer.initials,
                      unread: 0,
                      onSearchTap: () {},
                      onCompose: () {},
                      onMessages: () {},
                      onBellTap: () {},
                      onAvatarTap: () => Navigator.of(ctx).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              MyProfileScreen(pickPhoto: () async => photo(), now: DateTime.utc(2026, 10, 26)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets('the Home header shows the new photo as soon as it is saved, with no restart', (tester) async {
      await pumpApp(tester);
      expect(headerAvatar(tester).photo?.url, 'http://localhost:3001/uploads/old.jpg');

      await tester.tap(find.byKey(const ValueKey('home-avatar')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('profile.avatar')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('photo.choose')));
      await settle(tester);

      // What the app sent: the file, then the address it was given as the avatar.
      expect(uploads, hasLength(1));
      expect(h.api.last('PATCH /users/me').json, {'avatarUrl': '/uploads/new-photo.png'});
      expect(h.api.count('GET /auth/me'), greaterThan(1), reason: 'the session is read again');
      expect(find.text('Change Photo'), findsOneWidget);

      await tester.tap(find.byKey(const Key('sheet.save')));
      await settle(tester);
      Navigator.of(tester.element(find.byType(MyProfileScreen))).pop();
      await settle(tester);
      expect(headerAvatar(tester).photo?.url, 'http://localhost:3001/uploads/new-photo.png');
      expect(h.auth.user?.avatarUrl, '/uploads/new-photo.png');
      // The image cache's own clean-up timer (ten seconds) runs out.
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('removing the photo shows initials in the header', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('home-avatar')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('profile.avatar')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('sheet.delete')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirm.ok')));
      await settle(tester);
      expect(h.api.last('PATCH /users/me').json, {'avatarUrl': ''});
      await tester.tap(find.byKey(const Key('sheet.save')));
      await settle(tester);
      Navigator.of(tester.element(find.byType(MyProfileScreen))).pop();
      await settle(tester);
      expect(headerAvatar(tester).photo, isNull);
      expect(find.descendant(of: find.byType(HomeHeader), matching: find.text('AR')), findsOneWidget);
    });

    testWidgets('the profile menu reads its photo again when the session is read anew', (tester) async {
      await signIn(tester);
      final menu = ProfileDrawerController.live(
        api: h.client,
        userId: 'u1',
        seed: ProfileDrawerData(name: 'Anita Rao', photoUrl: 'http://api.test/uploads/old.jpg'),
        session: h.auth,
      );
      addTearDown(menu.dispose);
      await tester.runAsync(menu.ensureLoaded);
      expect(menu.data.photoUrl, 'http://api.test/uploads/old.jpg');

      avatar = '/uploads/new-photo.png';
      await tester.runAsync(() async {
        await h.auth.refreshUser();
        // The menu reads eight things again at once; wait for it (up to 2 s) rather than a fixed 50 ms, which a busy
        // machine overran (12 Nov 2026).
        for (var i = 0; i < 100 && menu.data.photoUrl != 'http://api.test/uploads/new-photo.png'; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      expect(menu.data.photoUrl, 'http://api.test/uploads/new-photo.png');
    });

    testWidgets('a menu not opened yet does not race its first read', (tester) async {
      await signIn(tester);
      final menu = ProfileDrawerController.live(
        api: h.client,
        userId: 'u1',
        seed: ProfileDrawerData(name: 'Anita Rao'),
        session: h.auth,
      );
      addTearDown(menu.dispose);
      await tester.runAsync(() async {
        await h.auth.refreshUser();
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      expect(h.api.count('GET /users/me/profile'), 0);
    });
  });

  testWidgets('why the tabs watch the session: the shell keeps the widget each tab was first given', (tester) async {
    var name = 'Anita';
    late StateSetter change;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            change = setState;
            final first = name;
            return AppShell(home: Builder(builder: (_) => Text('plain: $first')));
          },
        ),
      ),
    );
    expect(find.text('plain: Anita'), findsOneWidget);
    change(() => name = 'Anita Rao');
    await tester.pump();
    expect(find.text('plain: Anita'), findsOneWidget, reason: 'the old tab widget is kept');
    expect(find.text('plain: Anita Rao'), findsNothing);
  });

  group('a photo from the phone', () {
    /// A picture with a lot in it, so it does not compress to nothing.
    Future<Uint8List> picture(int w, int h) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint();
      final random = math.Random(7);
      for (var i = 0; i < 900; i++) {
        paint.color = Color(0xFF000000 | random.nextInt(0xFFFFFF));
        canvas.drawRect(Rect.fromLTWH(random.nextDouble() * w, random.nextDouble() * h, 40, 40), paint);
      }
      final image = await recorder.endRecording().toImage(w, h);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    }

    Future<ui.Image> decode(WidgetTester tester, List<int> bytes) async {
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      return (await codec.getNextFrame()).image;
    }

    testWidgets('a picture within the limit, in a type the API takes, is sent as it is', (tester) async {
      final file = PickedPhoto(bytes: List.filled(1000, 3), name: 'IMG_1.JPG');
      final out = (await tester.runAsync(() => fitForUpload(file)))!;
      expect(identical(out, file), isTrue);
    });

    testWidgets('a picture over the limit is shrunk, not turned away, and sent as a PNG within it', (tester) async {
      final bytes = await tester.runAsync(() => picture(1200, 800));
      expect(bytes!.length, greaterThan(40 * 1024), reason: 'the picture is heavy enough to need shrinking');
      final out = (await tester.runAsync(
        () => fitForUpload(
          PickedPhoto(bytes: bytes, name: 'IMG_2041.jpg'),
          max: 40 * 1024,
          side: 400,
        ),
      ))!;
      expect(out.name, 'IMG_2041.png');
      expect(out.contentType, 'image/png');
      expect(out.bytes.length, lessThanOrEqualTo(40 * 1024));
      expect(photoProblem(out, max: 40 * 1024), isNull);
      final image = (await tester.runAsync(() => decode(tester, out.bytes)))!;
      expect(math.max(image.width, image.height), lessThanOrEqualTo(400));
      expect(image.width / image.height, closeTo(1200 / 800, 0.02), reason: 'its proportions are kept');
    });

    testWidgets('a tall picture is kept to the side limit on its height', (tester) async {
      final bytes = await tester.runAsync(() => picture(600, 1500));
      final out = (await tester.runAsync(
        () => fitForUpload(
          PickedPhoto(bytes: bytes!, name: 'tall.png'),
          max: 20 * 1024,
          side: 500,
        ),
      ))!;
      final image = (await tester.runAsync(() => decode(tester, out.bytes)))!;
      expect(image.height, lessThanOrEqualTo(500));
      expect(image.width / image.height, closeTo(600 / 1500, 0.02));
    });

    testWidgets('a format the API refuses (HEIC) is turned into a PNG even when it is small', (tester) async {
      final bytes = await tester.runAsync(() => picture(200, 120));
      final out = (await tester.runAsync(() => fitForUpload(PickedPhoto(bytes: bytes!, name: 'IMG_3.heic'))))!;
      expect(out.name, 'IMG_3.png');
      expect(out.contentType, 'image/png');
    });

    testWidgets('something that is not a picture comes back unchanged (and is refused for its weight)', (tester) async {
      final junk = PickedPhoto(bytes: List.filled(5 * 1024 * 1024 + 1, 1), name: 'big.jpg');
      final out = (await tester.runAsync(() => fitForUpload(junk)))!;
      expect(identical(out, junk), isTrue);
      expect(photoProblem(out), 'The file is too large. Choose one under 5 MB.');
    });
  });
}
