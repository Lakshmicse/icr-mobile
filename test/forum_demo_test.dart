import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/feed/demo_feed_repository.dart';
import 'package:icr_mobile/features/forum/demo_forum_repository.dart';
import 'package:icr_mobile/features/forum/forum_callbacks.dart';
import 'package:icr_mobile/features/forum/forums_controller.dart';
import 'package:icr_mobile/features/forum/forums_screen.dart';
import 'package:icr_mobile/features/forum/thread_screen.dart';

import 'helpers/fonts.dart';

/// The forum with the design's sample content (`--dart-define=FEED_SOURCE=demo`): every screen works against it
/// without a database, and every write changes the in-memory copy only.
void main() {
  setUpAll(loadAppFonts);

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  late ForumsController forums;

  Future<void> pumpDemo(WidgetTester tester) async {
    tester.view.physicalSize = const Size(780, 5200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    forums = ForumsController(DemoForumRepository(now: DateTime(2026, 10, 26, 12)));
    addTearDown(forums.dispose);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: ForumsScreen(
          viewer: DemoFeedRepository.me,
          controller: forums,
          onBack: () {},
          callbacks: const ForumCallbacks(),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('the tab lists the design\'s discussions and its topics', (tester) async {
    await pumpDemo(tester);
    expect(forums.posts, hasLength(6));
    expect(find.text('Technology (3)'), findsOneWidget);
    expect(find.text('Sarah Jenkins'), findsOneWidget);
    expect(find.text('What is your primary FM Software in 2026?'), findsOneWidget);
  });

  testWidgets('a view, a topic and a search work on the sample content', (tester) async {
    await pumpDemo(tester);
    await tester.tap(key('view:polls'));
    await settle(tester);
    expect(forums.posts.map((p) => p.id), ['fm-software-poll']);
    await tester.tap(key('view:all'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'amc');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    expect(forums.posts.map((p) => p.id), ['amc-escalation']);
  });

  testWidgets('a discussion opens on its page with its replies; a reply sent shows; a like is local', (tester) async {
    await pumpDemo(tester);
    await tester.tap(key('open:iot-hvac'));
    await settle(tester);
    expect(find.byType(ThreadScreen), findsOneWidget);
    expect(find.text('Arvind Swamy'), findsWidgets);
    expect(find.text('VP Sustainability'), findsWidgets);
    await tester.enterText(key('reply-input'), 'From the demo');
    await tester.pump();
    await tester.tap(key('reply-send'));
    await settle(tester);
    expect(find.text('From the demo'), findsOneWidget);
  });

  testWidgets('the composer posts a discussion into the sample forum, and it joins the list', (tester) async {
    await pumpDemo(tester);
    await tester.tap(key('home-composer'));
    await tester.pumpAndSettle();
    await settle(tester);
    await tester.tap(key('composer-topic'));
    await tester.pumpAndSettle();
    await tester.tap(key('topic-option:TECHNOLOGY_INNOVATION'));
    await tester.pumpAndSettle();
    await tester.enterText(key('composer-title'), 'A discussion from the demo');
    await tester.enterText(key('composer-body'), 'Some words');
    await tester.pump();
    await tester.ensureVisible(key('composer-send'));
    await tester.tap(key('composer-send'));
    await settle(tester);
    expect(find.byType(ThreadScreen), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back').first);
    await settle(tester);
    expect(forums.posts.first.title, 'A discussion from the demo');
  });
}
