import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports, depend_on_referenced_packages
import 'package:test_api/src/backend/invoker.dart';

import 'helpers/layout_audit.dart';

/// Runs around every test file. With `LAYOUT_AUDIT=1` in the environment, every frame a widget test pumps is
/// looked over ([layoutProblems]) and what was found is written, once per test, to
/// `build/layout_audit/<test file>.txt` — a sweep of every screen state the suite pumps, dialogs and sheets
/// included, with no test changed. The tests themselves never fail on it; the file is for reading. (A hook
/// after the test is too late: flutter_test replaces the tree with its "Test finished." page first.)
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (Platform.environment['LAYOUT_AUDIT'] == '1') {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final seen = <String>{};
    // Registered after the rendering binding's own, so it runs once the frame is laid out.
    binding.addPersistentFrameCallback((_) {
      if (binding.rootElement == null) return;
      seen.addAll(layoutProblems());
    });
    tearDown(() {
      final live = Invoker.current?.liveTest;
      final problems = seen.where((p) => !p.contains('Test finished.')).toList();
      seen.clear();
      if (live == null || problems.isEmpty) return;
      final file = live.suite.path ?? 'unknown';
      final name = file.replaceAll('\\', '/').split('/').last.replaceAll('.dart', '');
      final dir = Directory('build/layout_audit')..createSync(recursive: true);
      File(
        '${dir.path}/$name.txt',
      ).writeAsStringSync('## ${live.test.name}\n${problems.map((p) => '  $p').join('\n')}\n\n', mode: FileMode.append);
    });
  }
  await testMain();
}
