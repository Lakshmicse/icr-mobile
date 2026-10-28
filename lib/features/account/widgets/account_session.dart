import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/config.dart';
import '../account_repository.dart';
import '../api_account_repository.dart';
import '../demo_account_repository.dart';

/// The app's [AuthController], or null where none is provided (a screen shown
/// on its own, a test). `context.read<AuthController?>()` would not find one
/// provided as `AuthController`: the lookup is by exact type.
AuthController? maybeAuth(BuildContext context) {
  try {
    return Provider.of<AuthController>(context, listen: false);
  } on ProviderNotFoundException {
    return null;
  }
}

/// Whether the signed-in person's email is confirmed; listens, so the tick
/// appears when a confirmation lands. False with no session.
bool emailConfirmed(BuildContext context) {
  try {
    return Provider.of<AuthController>(context).user?.emailVerified ?? false;
  } on ProviderNotFoundException {
    return false;
  }
}

/// [maybeAuth] that rebuilds the widget when the session changes (a new name or photo).
AuthController? watchAuth(BuildContext context) {
  try {
    return Provider.of<AuthController>(context);
  } on ProviderNotFoundException {
    return null;
  }
}

/// The account calls for this screen: the API through the app's client, or the
/// sample member in demo mode (`FEED_SOURCE=demo`).
AccountRepository accountRepositoryOf(BuildContext context) =>
    AppConfig.demo ? DemoAccountRepository() : ApiAccountRepository(api: Provider.of<ApiClient>(context, listen: false));
