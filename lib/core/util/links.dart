import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import 'site_policy.dart';

/// Opens a page of the app for a page of the website, given the page's URI;
/// null when the app has no screen for it.
typedef SiteRouteOpener = Future<void> Function(BuildContext context);
typedef SiteRouteResolver = SiteRouteOpener? Function(Uri uri);

/// Opens a page of the website in the app's web view, signed in as the person.
typedef SiteWebOpener = Future<void> Function(BuildContext context, Uri uri);

/// The pages of the website the app opens itself. The lead sets [resolver]
/// once where the app is put together (`lib/app.dart`); every hand-off to the
/// website asks it first, so a "See plans" or a bell deep in a feature reaches
/// the app's own screen without that feature knowing it exists. A page the app
/// has no screen for opens in [webView] (the app's in-app web view) instead of
/// the browser, unless it must stay with the phone ([SitePolicy.staysExternal]).
/// Tests leave both unset, and every hand-off reaches the browser as before.
class SiteRoutes {
  SiteRoutes._();

  static SiteRouteResolver? resolver;

  /// Where a page of the website with no app screen opens. Unset, it reaches the browser.
  static SiteWebOpener? webView;

  /// The app's opener for [uri], when it is a page of the website: its own screen,
  /// else the in-app web view. Null for another site, a payment or a file, and
  /// while no [resolver] is set.
  static SiteRouteOpener? inApp(Uri uri) {
    final resolve = resolver;
    if (resolve == null) return null;
    if (!SitePolicy.isSite(uri)) return null;
    final native = resolve(uri);
    if (native != null) return native;
    final web = webView;
    if (web == null || SitePolicy.staysExternal(uri)) return null;
    return (context) => web(context, uri);
  }
}

/// Opens a page of the ICR website: the app's own screen when it has one, else
/// the app's web view; only a payment, a download or another site leaves the app.
Future<void> openSitePage(BuildContext context, String path) => openUrl(context, AppConfig.sitePage(path));

/// Opens [uri]: the app's own screen for a page of the website it has one for,
/// else the app's web view (unless [inApp] is false, for a page that must be the
/// website's own tab — a payment), else the browser.
Future<void> openUrl(BuildContext context, Uri uri, {bool inApp = true}) async {
  if (inApp) {
    final open = SiteRoutes.inApp(uri);
    if (open != null) return open(context);
  }
  final messenger = ScaffoldMessenger.of(context);
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened) {
    messenger.showSnackBar(SnackBar(content: Text("Couldn't open ${uri.host}${uri.path}")));
  }
}

/// Opens [uri] in the phone's browser, never in the app: a payment page. Payments (PayU) are made on the website;
/// the app cannot run them, and a page of the website that the app also has a screen for (a paper's page) would
/// otherwise open that screen again instead of the checkout.
Future<void> openExternal(BuildContext context, Uri uri) => openUrl(context, uri, inApp: false);

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
