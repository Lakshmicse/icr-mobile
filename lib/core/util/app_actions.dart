import 'package:flutter/widgets.dart';

/// App-level actions a shared widget (the Home header, shown on Home, Learning
/// and Mentorship) calls without every screen passing a callback down to it.
/// `app.dart` fills them in once the signed-in app is built, the way
/// `SiteRoutes.resolver` is; until then (tests, a screen mounted alone) a call
/// does nothing.
class AppActions {
  AppActions._();

  /// Starts a new post: what the header's "+" and the composer card open.
  static Future<void> Function(BuildContext context)? composePost;

  /// The Messages inbox.
  static Future<void> Function(BuildContext context)? openMessages;

  /// The global search screen, optionally with a query already typed.
  static Future<void> Function(BuildContext context, {String? query})? openSearch;
}
