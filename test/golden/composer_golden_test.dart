@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/forum/composer_controller.dart';
import 'package:icr_mobile/features/forum/demo_forum_repository.dart';
import 'package:icr_mobile/features/forum/new_thread_screen.dart';
import 'package:icr_mobile/features/forum/rich_document.dart';
import 'package:icr_mobile/features/forum/rich_text_controller.dart';

import '../helpers/fonts.dart';

/// The composer is the website's "Create a post" form on a phone (360 wide, 2x): the discussion and the poll, empty
/// and filled in with formatted details. Refresh with
/// `flutter test --update-goldens --tags golden test/golden/composer_golden_test.dart`.
void main() {
  setUpAll(loadAppFonts);

  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> open(WidgetTester tester, {ComposerMode mode = ComposerMode.discussion}) async {
    tester.view.physicalSize = const Size(720, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: NewThreadScreen(repository: DemoForumRepository(), mode: mode),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
  }

  Future<void> fillIn(WidgetTester tester, {required bool poll}) async {
    await tester.tap(key('composer-topic'));
    await tester.pumpAndSettle();
    await tester.tap(key('topic-option:TECHNOLOGY_INNOVATION'));
    await tester.pumpAndSettle();
    await tester.tap(key('composer-subtopic'));
    await tester.pumpAndSettle();
    await tester.tap(key('topic-option:BMS'));
    await tester.pumpAndSettle();
    await tester.enterText(
      key('composer-title'),
      poll ? 'Which CAFM platform does your team use today?' : 'What actually moved the needle on energy?',
    );
    if (poll) {
      await tester.enterText(key('poll-field:0'), 'Planon');
      await tester.enterText(key('poll-field:1'), 'Archibus');
    }
    final body = tester.widget<TextField>(key('composer-body')).controller! as RichTextController;
    body.load(
      RichDoc.fromHtml(
        poll
            ? '<p>We are about to <strong>renew</strong> and want to know what others run before we commit.</p>'
            : '<h3>Where we started</h3><p>Two sites, <strong>one BMS</strong>, a <em>lot</em> of manual rounds. '
                  'Notes at <a href="https://icr.org.in/community">icr.org.in/community</a>.</p>'
                  '<ul><li>Sub-metering on every floor</li><li>Set-point review each quarter</li></ul>'
                  '<ol><li>Baseline</li><li>Pilot</li></ol>',
      ),
    );
    await tester.enterText(key('composer-tag'), 'energy, bms,');
    await tester.pumpAndSettle();
  }

  testWidgets('a discussion, empty (360 wide)', (tester) async {
    await open(tester);
    await expectLater(find.byType(NewThreadScreen), matchesGoldenFile('goldens/composer_discussion_empty.png'));
  });

  testWidgets('a discussion, filled in with formatted details (360 wide)', (tester) async {
    await open(tester);
    await fillIn(tester, poll: false);
    await expectLater(find.byType(NewThreadScreen), matchesGoldenFile('goldens/composer_discussion_filled.png'));
  });

  testWidgets('a poll, empty (360 wide)', (tester) async {
    await open(tester, mode: ComposerMode.poll);
    await expectLater(find.byType(NewThreadScreen), matchesGoldenFile('goldens/composer_poll_empty.png'));
  });

  testWidgets('the Category list searching the whole tree (360 wide)', (tester) async {
    await open(tester);
    await tester.tap(key('composer-topic'));
    await tester.pumpAndSettle();
    await tester.enterText(key('topic-search'), 'techno');
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/composer_category_search.png'));
  });

  testWidgets('a poll, filled in (360 wide)', (tester) async {
    await open(tester, mode: ComposerMode.poll);
    await fillIn(tester, poll: true);
    await expectLater(find.byType(NewThreadScreen), matchesGoldenFile('goldens/composer_poll_filled.png'));
  });
}
