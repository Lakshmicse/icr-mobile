import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/config.dart';
import '../../core/util/links.dart' show showMessage;
import '../learning_assess/api_assess_repository.dart';
import '../learning_assess/assess_models.dart';
import '../learning_assess/assess_repository.dart';
import '../learning_assess/catalogue_controller.dart';
import '../learning_assess/demo_assess_repository.dart';
import '../learning_assess/group_screen.dart';
import '../learning_exam/open_paper.dart';
import '../notifications/notification_scope.dart';
import '../shell/app_shell.dart';
import '../shell/icr_bottom_nav.dart' show AppTab;
import '../shell/shell_page.dart';
import 'study_models.dart';

/// Opens the page of the Assess your knowledge course a flash-card deck belongs with, in the app: its levels,
/// the plan card ("Open with my plan"), ICR credits for a level or for them all together, and the price. The deck
/// opens whenever the course does (owner's call, 27 Oct 2026), so this is where a locked deck is unlocked.
///
/// The future completes when that page is left, so the caller reads again what the member opened there.
/// [repository] is for tests.
Future<void> openAssessCourse(BuildContext context, StudyCourseRef course, {AssessRepository? repository}) async {
  final repo =
      repository ?? (AppConfig.demo ? DemoAssessRepository() : ApiAssessRepository(api: context.read<ApiClient>()));
  // The pushed route sits above this screen's providers: the bell's count and router go with it.
  final scope = NotificationScope.of(context);
  final PaperGroup group;
  try {
    group = await repo.group(PaperKind.assessment, course.code);
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
          create: (_) => CatalogueController(repository: repo, kind: PaperKind.assessment),
          child: GroupScreen(seed: group, onBack: () => Navigator.of(c).pop(), opener: openPaper),
        ),
      ),
    ),
  );
}
