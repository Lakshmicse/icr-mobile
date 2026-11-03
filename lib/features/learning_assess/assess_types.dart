import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../learning_exam/open_paper.dart' show PaperRef;

/// Opens a paper: its brief, the exam, the result. The exam builder's `openPaper`; tests give their own.
typedef PaperOpener = Future<void> Function(BuildContext context, PaperRef paper);

/// Hands a page to the browser. Tests give their own to see which page a control asks for.
typedef SiteLauncher = Future<void> Function(BuildContext context, Uri uri);

/// Opens the phone's share sheet with a programme's, an exam's or a set's page on the website. Tests give their own.
typedef ShareLink = Future<void> Function(String title, Uri link);

Future<void> shareAssessLink(String title, Uri link) =>
    SharePlus.instance.share(ShareParams(text: '$title\n$link', subject: title)).then((_) {});
