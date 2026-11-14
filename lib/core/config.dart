import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

/// Build-time settings, passed with `--dart-define`.
///
/// * `API_BASE_URL` — the ICR API, `/api/v1` included. A release build defaults
///   to production (`https://icr.org.in/api/v1`); a debug or profile build to
///   the local backend: `http://10.0.2.2:3001/api/v1` on the Android emulator
///   (its alias for the host machine), `http://localhost:3001/api/v1` elsewhere.
///   A phone on the same Wi-Fi needs the computer's LAN address instead.
/// * `SITE_URL` — the website, for links the app hands out and opens. Leave it
///   out: it follows `API_BASE_URL` (owner, 14 Nov 2026: "when it's on
///   dev.icr it should point there, on icr.org to the respective backend"),
///   so a build pointed at `https://dev.icr.org.in/api/v1` shares and opens
///   dev.icr.org.in links, one at `https://icr.org.in/api/v1` production's.
/// * `FEED_SOURCE` — `live` (the API, default) or `demo` (the design's sample
///   content, bundled, for design review without a seeded database).
class AppConfig {
  AppConfig._();

  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _siteUrl = String.fromEnvironment('SITE_URL');

  /// The production website, where a build with neither address goes.
  static const productionSite = 'https://icr.org.in';

  /// The website the app links to: [siteFor] the build's two addresses.
  static String get siteUrl => siteFor(site: _siteUrl, api: _apiBaseUrl);

  /// The website for a build: `SITE_URL` when given; else the origin of an `https` API (the website and the API
  /// share a host on every ICR server: `https://dev.icr.org.in/api/v1` is dev.icr.org.in's); else production. A
  /// local API (`http://10.0.2.2:3001`) has no website on its origin, so it keeps production's.
  static String siteFor({required String site, required String api}) {
    if (site.isNotEmpty) return site.endsWith('/') ? site.substring(0, site.length - 1) : site;
    final uri = Uri.tryParse(api);
    if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) return uri.origin;
    return productionSite;
  }

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
