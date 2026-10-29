import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/util/links.dart' show SiteRoutes;

/// Where a tap on the Jobs screens leaves the app: the ICR website, an
/// employer's own site, the system share sheet. The screens go through it, so
/// a test can see where a control would have taken the member.
abstract class JobLinks {
  const JobLinks();

  /// Opens [uri] outside the app; false when nothing could open it.
  Future<bool> open(Uri uri);

  /// Hands [text] to the system share sheet.
  Future<void> share({required String text, String? subject});
}

/// The real thing: the browser and the share sheet.
class SystemJobLinks extends JobLinks {
  const SystemJobLinks();

  @override
  Future<bool> open(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Future<void> share({required String text, String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }
}

extension JobLinksOpening on JobLinks {
  /// A page of the ICR website (`/manage/jobs/new`).
  Future<void> openSite(BuildContext context, String path) => openUri(context, AppConfig.sitePage(path));

  /// Opens [uri] — the app's own screen when it has one for that page of the
  /// website — and says so when the phone has nothing to open it with.
  Future<void> openUri(BuildContext context, Uri uri) async {
    final inApp = SiteRoutes.inApp(uri);
    if (inApp != null) return inApp(context);
    return openExternal(context, uri);
  }

  /// Opens [uri] with the phone, never the app's own screen for it: a payment page, which the website takes, where
  /// the app's screen for the same address would only open itself again.
  Future<void> openExternal(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await open(uri);
    } catch (_) {
      // Treated as "could not open" below.
    }
    if (!opened) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("Couldn't open ${uri.host}${uri.path}")));
    }
  }
}
