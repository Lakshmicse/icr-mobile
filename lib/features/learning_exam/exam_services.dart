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

  /// Opens a page of the website in the browser.
  static Future<void> Function(BuildContext context, Uri uri) openUrl = links.openUrl;

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
