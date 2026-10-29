import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/config.dart';
import '../../core/util/links.dart' show showMessage;
import '../learning_exam/open_paper.dart';
import '../notifications/notification_scope.dart';
import '../shell/app_shell.dart';
import '../shell/icr_bottom_nav.dart' show AppTab;
import '../shell/shell_page.dart';
import 'api_assess_repository.dart';
import 'assess_models.dart';
import 'assess_repository.dart';
import 'catalogue_controller.dart';
import 'demo_assess_repository.dart';
import 'group_screen.dart';

/// Opens an Assess your knowledge programme's page (its levels, the plan card, ICR credits, the price) or a mock
/// exam subject's page (its sets), from anywhere in the app that only knows its key: a notification ("You enrolled
/// into AEE CBCP – Set 2"), a link to `/learning/assessment/<code>` or `/learning/mock-tests/<subject>`, a flash-card
/// deck's "Open the course". [key] is the programme's code, or the subject's slug.
///
/// The future completes when that page is left, so the caller can read again what the member opened there.
/// [repository] is for tests.
Future<void> openPaperGroup(BuildContext context, PaperKind kind, String key, {AssessRepository? repository}) async {
  final repo =
      repository ?? (AppConfig.demo ? DemoAssessRepository() : ApiAssessRepository(api: context.read<ApiClient>()));
  // The pushed route sits above this context's providers: the bell's count and router go with it.
  final scope = NotificationScope.of(context);
  final PaperGroup group;
  try {
    group = await repo.group(kind, key);
  } catch (e) {
    if (context.mounted) showMessage(context, ApiError.from(e).message);
    return;
  }
  if (!context.mounted) return;
  await AppShell.push<void>(
    context,
    (c) => scope.wrap(
      ShellPage(
        tab: AppTab.learning,
        child: ChangeNotifierProvider<CatalogueController>(
          create: (_) => CatalogueController(repository: repo, kind: kind),
          child: GroupScreen(seed: group, onBack: () => Navigator.of(c).pop(), opener: openPaper),
        ),
      ),
    ),
  );
}
