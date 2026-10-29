import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/util/links.dart' as links;
import 'exam_progress_store.dart';

/// The few things the exam flow does outside the app, behind one seam each so a
/// test can stand in for the keystore, the browser and the share sheet.
class ExamServices {
  ExamServices._();

  /// Where an unsent sitting is kept between launches.
  static ExamProgressStore progress = SecureExamProgressStore();

  /// Opens a page of the website: the app's own screen when it has one, else the app's web view.
  static Future<void> Function(BuildContext context, Uri uri) openUrl = links.openUrl;

  /// Opens a page of the website with the phone, never the app's own screen for it: a payment, or a download
  /// the website makes. The app's screen for the same address would only open itself again.
  static Future<void> Function(BuildContext context, Uri uri) openExternal = links.openExternal;

  /// Hands text (a link) to the system share sheet.
  static Future<void> Function(String text, {String? subject}) share = _share;

  /// The clock the exam runs on.
  static DateTime Function() now = DateTime.now;

  static Future<void> _share(String text, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }

  /// Back to the real ones (a test's tear-down).
  static void reset() {
    progress = SecureExamProgressStore();
    openUrl = links.openUrl;
    share = _share;
    now = DateTime.now;
  }
}
