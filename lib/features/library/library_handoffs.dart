import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'library_device.dart';

/// Opens the phone's share sheet with a page link.
typedef ShareLibraryLink = Future<void> Function(String title, Uri link);

Future<void> shareLibraryLink(String title, Uri link) =>
    SharePlus.instance.share(ShareParams(text: '$title\n$link', subject: title)).then((_) {});

/// Where the Library screens hand a person on to: the shell wires each one. One value, so a document's
/// page, opened from the list or by the shell for a notification, is given the same ones.
class LibraryHandoffs {
  const LibraryHandoffs({
    this.onBell,
    this.onOpenMember,
    this.onOpenPlans,
    this.device = const SystemLibraryDevice(),
    this.share = shareLibraryLink,
  });

  /// The bell. The website's notifications page when null.
  final VoidCallback? onBell;

  /// The name of whoever shared a document opens their profile (user id); not tappable without it.
  final ValueChanged<String>? onOpenMember;

  /// "See plans" on the card that says a plan does not open a document; the card has no button without it.
  final VoidCallback? onOpenPlans;

  /// Choosing files, handing a downloaded file to the phone, opening a page. Tests give their own.
  final LibraryDevice device;

  /// Opens the phone's share sheet. Tests give their own.
  final ShareLibraryLink share;
}
