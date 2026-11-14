import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/core/util/links.dart';
import 'package:icr_mobile/features/assistant/assistant_controller.dart';
import 'package:icr_mobile/features/assistant/assistant_screen.dart';
import 'package:icr_mobile/features/assistant/demo_assistant_repository.dart';
import 'package:icr_mobile/features/assistant/open_assistant.dart';
import 'package:provider/provider.dart';

import 'helpers/fonts.dart';

/// A controller the shell provides below the root Navigator, as the signed-in controllers are (`_Home` in
/// `app.dart`): a route pushed on that Navigator cannot read it.
class _TabController extends ChangeNotifier {}

/// Saathi opened from the shell (7 Nov 2026: "Find a mentor" did nothing — the page was opened with Saathi's own
/// context, above the shell's providers, and reading `MentorshipController` threw).
void main() {
  setUpAll(loadAppFonts);
  tearDown(() => SiteRoutes.resolver = null);

  testWidgets("a page Saathi opens is opened with the shell's context, so it can read the shell's controllers", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <String>[];
    final readable = <bool>[];
    SiteRoutes.resolver = (uri) => (ctx) async {
      opened.add(uri.path);
      readable.add(Provider.of<_TabController?>(ctx, listen: false) != null);
    };
    // Opened before the tree builds, so the greeting is already there (the app's controller lives above the shell
    // and has greeted long before Saathi is tapped), so opening it in the screen notifies no one mid-build.
    final controller = AssistantController(DemoAssistantRepository(delay: Duration.zero))..open();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AssistantController>.value(
        value: controller,
        child: MaterialApp(
          theme: buildAppTheme(),
          // The shell's controllers sit under `home`, below the Navigator, as in the app.
          home: ChangeNotifierProvider<_TabController>(
            create: (_) => _TabController(),
            child: Builder(
              builder: (shell) => Scaffold(
                body: TextButton(
                  onPressed: () => openAssistant(shell, path: '/jobs'),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('suggestion-Browse Jobs')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('suggestion-Browse Jobs')));
    await tester.pump();
    expect(opened, ['/jobs']);
    expect(readable, [true], reason: "opened with the shell's context, not Saathi's route's");
  });
}
