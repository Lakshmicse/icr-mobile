import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../shell/app_shell.dart';
import 'in_app_web_screen.dart';
import 'web_session.dart';

/// Opens a page of the ICR website in the app, signed in as the person: what
/// `SiteRoutes.webView` is set to. Pushed with [AppShell.push], so the profile
/// menu and the tabs stay reachable from under it.
Future<void> openInAppWeb(BuildContext context, Uri uri, {String? title}) {
  final api = Provider.of<ApiClient?>(context, listen: false);
  final session = api == null ? null : WebSessionBridge(api);
  return AppShell.push<void>(
    context,
    (_) => InAppWebScreen(uri: uri, title: title, accessToken: session?.freshAccessToken),
  );
}
