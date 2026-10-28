import 'package:flutter/widgets.dart';

import '../learning_exam/open_paper.dart' show PaperRef;

/// Opens a paper: its brief, the exam, the result. The exam builder's `openPaper`; tests give their own.
typedef PaperOpener = Future<void> Function(BuildContext context, PaperRef paper);

/// Hands a page to the browser. Tests give their own to see which page a control asks for.
typedef SiteLauncher = Future<void> Function(BuildContext context, Uri uri);
