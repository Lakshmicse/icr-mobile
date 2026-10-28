import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/learning/api_learning_repository.dart';
import 'package:icr_mobile/features/learning/course_sheet.dart';
import 'package:icr_mobile/features/learning/learning_controller.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';
import 'live.dart';

void main() {
  setUpAll(loadAppFonts);
  testWidgets('scratch: a programme sheet', (tester) async {
    await tester.runAsync(liveApiReachable);
    final api = (await tester.runAsync(() => liveClient(bharat)))!;
    final repo = ApiLearningRepository(
      api: ApiClient(tokens: api.tokens, baseUrl: liveBaseUrl),
    );
    final ctl = LearningController(repo);
    await tester.runAsync(ctl.start);
    final prog = ctl.courses.firstWhere((c) => c.code == 'CP');
    tester.view.physicalSize = const Size(780, 4000);
    tester.view.devicePixelRatio = 2;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ChangeNotifierProvider.value(
          value: ctl,
          child: Builder(
            builder: (c) => TextButton(onPressed: () => showCourseSheet(c, prog), child: const Text('open')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    // ignore: avoid_print
    print(tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').where((t) => t.isNotEmpty).join(' | '));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  }, tags: const ['live']);
}
