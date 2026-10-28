import '../config.dart';

/// What the app does with a link that points at the ICR website.
///
/// A page of the website opens in the app: as the app's own screen when it has
/// one (`SiteRoutes.resolver`), else in the app's web view. Only what a web
/// view cannot or should not do stays with the phone: a payment, a file the
/// system should open, `mailto:`/`tel:`, and other people's websites.
class SitePolicy {
  SitePolicy._();

  /// Paths under the website's own host that the phone handles itself: the
  /// API (a payment's return leg, a download), uploaded files, the `.well-known`
  /// files, and `/auth/callback`, where Google / LinkedIn sign-in comes back: the
  /// secure browser tab that started it returns it to the app through its own
  /// intent filter, so neither the app's routing nor the web view may take it.
  static const externalPrefixes = ['/api/', '/uploads/', '/payments/', '/.well-known/', '/auth/callback'];

  /// Files a web view would only offer to download: the system opens them.
  static const externalExtensions = {
    'pdf',
    'ics',
    'zip',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'csv',
    'apk',
    'vcf',
  };

  /// The website's origin, as the app is configured to reach it.
  static Uri get site => Uri.parse(AppConfig.siteUrl);

  /// [uri] is a page of the ICR website (the same scheme, host and port).
  static bool isSite(Uri uri, {Uri? site}) {
    final s = site ?? SitePolicy.site;
    return uri.hasAuthority && uri.scheme == s.scheme && uri.host == s.host && _port(uri) == _port(s);
  }

  static int _port(Uri u) => u.hasPort ? u.port : (u.scheme == 'https' ? 443 : 80);

  /// A page of the website the phone must handle (a payment, a download),
  /// because a web view in the app would be the wrong place for it.
  static bool staysExternal(Uri uri) {
    final path = uri.path;
    for (final prefix in externalPrefixes) {
      if (path.startsWith(prefix)) return true;
    }
    final dot = path.lastIndexOf('.');
    if (dot > path.lastIndexOf('/') && externalExtensions.contains(path.substring(dot + 1).toLowerCase())) {
      return true;
    }
    return false;
  }

  /// A link the web view may follow itself: a page of the website, a blank
  /// page, or an inline document. Everything else (another site, `mailto:`,
  /// `tel:`, an `intent:`) goes to the phone.
  static WebNavigation navigation(Uri uri, {Uri? site}) {
    if (uri.scheme == 'about' || uri.scheme == 'data' || uri.scheme == 'blob') return WebNavigation.inApp;
    if (uri.scheme != 'http' && uri.scheme != 'https') return WebNavigation.external;
    if (!isSite(uri, site: site)) return WebNavigation.external;
    return staysExternal(uri) ? WebNavigation.external : WebNavigation.inApp;
  }
}

/// Where the web view sends a navigation.
enum WebNavigation { inApp, external }
