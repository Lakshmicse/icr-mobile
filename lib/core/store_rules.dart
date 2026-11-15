import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// What the App Store build leaves out (owner, 15 Nov 2026, before the first App Store submission):
///
/// * **No Google or LinkedIn sign-in on iOS.** App Review guideline 4.8 asks an app that offers a third-party
///   sign-in to offer Sign in with Apple beside it; until the app has one, iOS signs in with email and password
///   only. Android keeps both providers.
/// * **No buying of digital things on iOS.** Guideline 3.1.1 wants In-App Purchase for digital content, so the
///   iOS app sells none of it — membership plans, course places, papers and their bundles, mock sets and group
///   sessions show no buy button. What Apple lets an app sell another way stays: 1:1 mentoring with a person
///   (3.1.3(d)) and tickets to events attended in person or hybrid (3.1.3(e)). A ticket to an online-only event is
///   a one-to-many live service, which 3.1.1 also keeps to In-App Purchase, so the iOS app sells none of those
///   either. The iOS app does not point to the website for what it hides.
///
/// `STORE_RULES=ios` or `STORE_RULES=none` overrides the platform, so either set of rules can be tried on any
/// device or simulator.
class StoreRules {
  StoreRules._();

  static const _override = String.fromEnvironment('STORE_RULES');

  static bool get _appStore => switch (_override) {
    'ios' => true,
    'none' => false,
    _ => !kIsWeb && Platform.isIOS,
  };

  /// Google and LinkedIn sign-in may be offered.
  static bool get socialSignIn => !_appStore;

  /// Digital goods (plans, course places, papers, bundles, mock sets, group sessions) may be bought in the app.
  static bool get sellsDigitalGoods => !_appStore;

  /// The line shown where a buy button would be, when [sellsDigitalGoods] is false.
  static const notSoldInApp = "Purchases aren't available in the iOS app.";
}
