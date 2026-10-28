/// Helpers for live tests that pump a real screen over the real API.
///
/// A widget test runs in a fake-async zone, where a socket never completes. The
/// screens start reading in `initState`, so these helpers hand the event loop real
/// time between frames until the screen has nothing left to load.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/career/api_career_repository.dart';
import 'package:icr_mobile/features/jobs/api_jobs_repository.dart';

import 'live.dart';

/// Photos and logos come through `cached_network_image`, which needs the phone's
/// file system and a SQLite cache index. A widget test has neither, so the two
/// plugin channels answer just enough for the cache to run (an empty index, a
/// temp folder) and the picture is fetched from the API like on a device.
void mockImageCachePlugins() {
  final root = Directory.systemTemp.createTempSync('icr-live-images');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async {
    return root.path;
  });
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

/// False (and the test skipped) when the local API is not running.
Future<bool> liveScreenReady(WidgetTester tester) async {
  if (await tester.runAsync(liveApiReachable) != true) {
    markTestSkipped('the local API is not running at $liveBaseUrl');
    return false;
  }
  mockImageCachePlugins();
  return true;
}

/// Pumps [screen] in a phone-sized window under the app's theme.
Future<void> pumpLive(WidgetTester tester, Widget screen, {Size size = const Size(390, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: screen));
}

/// Lets real time pass between frames until no spinner is left (or [timeout] is up).
Future<void> settleLive(WidgetTester tester, {Duration timeout = const Duration(seconds: 12)}) async {
  final until = DateTime.now().add(timeout);
  var quiet = 0;
  while (DateTime.now().isBefore(until)) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      // Two quiet frames in a row: a second request may only start after the first answers.
      if (++quiet >= 2) return;
    } else {
      quiet = 0;
    }
  }
}

/// Ends a live widget test: the HTTP client's idle timers were made in the test's fake clock, so the
/// clock is wound past them (a test fails on a timer still pending).
Future<void> finishLive(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pump(const Duration(seconds: 20));
  await tester.pump(const Duration(seconds: 20));
}

/// The career source for [who], over the app's own client (one sign-in per person per test file).
Future<ApiCareerRepository> careerRepoFor(LivePerson who) async {
  final api = await liveClient(who);
  return ApiCareerRepository(
    api: api,
    jobs: ApiJobsRepository(api: api),
  );
}
