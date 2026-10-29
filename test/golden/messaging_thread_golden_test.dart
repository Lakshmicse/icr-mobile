@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/messaging/conversation_controller.dart';
import 'package:icr_mobile/features/messaging/conversation_screen.dart';
import 'package:icr_mobile/features/messaging/demo_messaging_repository.dart';
import 'package:icr_mobile/features/notifications/unread_counts.dart';
import 'package:provider/provider.dart';

import '../helpers/fonts.dart';

/// The conversation screen at the design's frame (docs/designs/messaging-thread.png: 390 × 961 dp at 2x) over
/// the demo thread with Dr. Radhika Iyer, exported at 2x to build/screens/messaging_thread.png for
/// tool/design/compare.py.
void main() {
  setUpAll(loadAppFonts);
  setUp(DraftStore.clearAll);

  /// The design reads "today, april 16", her messages at 10:14 and 10:42, mine at 10:30, and a sync "tomorrow".
  final now = DateTime(2026, 4, 16, 10, 50);

  Future<void> precacheAll(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> export(WidgetTester tester, Finder finder, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.ancestor(of: finder, matching: find.byType(RepaintBoundary)).first,
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/screens').createSync(recursive: true);
      File('build/screens/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('messaging thread (demo content) at 390 × 961', (tester) async {
    tester.view.physicalSize = const Size(780, 1922);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    // The bell wears its red dot, as the design's does.
    final counts = UnreadCounts(_Waiting(), interval: const Duration(hours: 1));
    addTearDown(counts.dispose);
    await tester.runAsync(counts.refresh);

    await tester.pumpWidget(
      ChangeNotifierProvider<UnreadCounts>.value(
        value: counts,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: ConversationScreen(
            conversationId: 'c-radhika',
            repository: DemoMessagingRepository(now: now),
            poll: false,
            clock: () => now,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await precacheAll(tester);

    // The design shows "Draft Saved" over an empty box: a draft is kept a second after typing stops, and the
    // box was emptied again inside that second (the label goes when the empty box is kept).
    final box = find.byKey(const ValueKey('composer'));
    await tester.enterText(box, 'Thanks, Dr. Radhika');
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.enterText(box, '');
    // Two frames: the hint fades back in on the second.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    // The design draws no caret.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 100));

    await export(tester, find.byType(ConversationScreen), 'messaging_thread');
    await expectLater(find.byType(ConversationScreen), matchesGoldenFile('goldens/messaging_thread.png'));
  });

  /// The whole thread, from its day pill down, in a frame tall enough to hold it (the app sets its text at
  /// 14 sp where the design's is about 10, so at the design's frame the oldest message scrolls under the card).
  /// Exported for review only: `build/screens/messaging_thread_full.png`.
  testWidgets('messaging thread, the whole of it (export only)', (tester) async {
    tester.view.physicalSize = const Size(780, 2500);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ConversationScreen(
          conversationId: 'c-radhika',
          repository: DemoMessagingRepository(now: now),
          poll: false,
          clock: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await precacheAll(tester);
    await export(tester, find.byType(ConversationScreen), 'messaging_thread_full');
  });
}

class _Waiting implements UnreadSource {
  @override
  Future<int> notifications() async => 3;

  @override
  Future<int> messages() async => 0;
}
