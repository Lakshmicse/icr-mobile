import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

/// Build-time settings, passed with `--dart-define`.
///
/// * `API_BASE_URL` — the ICR API, `/api/v1` included. A release build defaults
///   to production (`https://icr.org.in/api/v1`); a debug or profile build to
///   the local backend: `http://10.0.2.2:3001/api/v1` on the Android emulator
///   (its alias for the host machine), `http://localhost:3001/api/v1` elsewhere.
///   A phone on the same Wi-Fi needs the computer's LAN address instead.
/// * `SITE_URL` — the website, for links the app hands to the browser.
/// * `FEED_SOURCE` — `live` (the API, default) or `demo` (the design's sample
///   content, bundled, for design review without a seeded database).
class AppConfig {
  AppConfig._();

  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const siteUrl = String.fromEnvironment('SITE_URL', defaultValue: 'https://icr.org.in');
  static const _feedSource = String.fromEnvironment('FEED_SOURCE', defaultValue: 'live');

  /// The design's bundled sample content instead of the API, for review.
  static bool get demo => _feedSource == 'demo';
  static bool get demoFeed => demo;

  static String get apiBaseUrl {
    if (_apiBaseUrl.isNotEmpty) return _apiBaseUrl;
    if (kReleaseMode) return '$siteUrl/api/v1';
    final host = !kIsWeb && Platform.isAndroid ? '10.0.2.2' : 'localhost';
    return 'http://$host:3001/api/v1';
  }

  /// Uploads are served beside the API, outside its `/api/v1` prefix.
  static String uploadsOrigin([String? apiBase]) => (apiBase ?? apiBaseUrl).replaceFirst(RegExp(r'/api/v\d+/?$'), '');

  /// Turns a stored `/uploads/...` path into a URL; leaves full URLs alone.
  static String? absoluteUrl(String? path, {String? apiBase}) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '${uploadsOrigin(apiBase)}${path.startsWith('/') ? '' : '/'}$path';
  }

  static Uri sitePage(String path) => Uri.parse('$siteUrl$path');
}
