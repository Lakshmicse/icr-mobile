import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/config.dart';
import 'api_exam_repository.dart';
import 'brief_controller.dart';
import 'brief_sheet.dart';
import 'demo_exam_repository.dart';
import 'exam_controller.dart';
import 'exam_models.dart';
import 'exam_repository.dart';
import 'exam_screen.dart';
import 'exam_services.dart';

export 'exam_models.dart' show PaperRef;

/// Opens a paper: its brief (what it is, how long, what it costs or whether the member holds it, their
/// record on it), then the exam as a full-screen route with no tab bar, then the result.
///
/// Completes when the member has left the flow: closed the brief, left the exam, or closed the result, so a
/// landing can refresh its best scores and attempt counts after it. [repository] is a seam for tests; the app
/// reads the API (or the sample content in the design-review build).
Future<void> openPaper(BuildContext context, PaperRef paper, {ExamRepository? repository}) async {
  final repo =
      repository ?? (AppConfig.demo ? DemoExamRepository() : ApiExamRepository(api: context.read<ApiClient>()));
  final navigator = Navigator.of(context);
  final (id: userId, firstName: firstName) = _session(context);
  final brief = BriefController(
    repository: repo,
    ref: paper,
    store: ExamServices.progress,
    userId: userId,
    now: ExamServices.now,
  );
  final start = await showBriefSheet(context, brief);
  if (start == null || !navigator.mounted) return;

  final controller = ExamController(
    sitting: start.sitting,
    repository: repo,
    store: ExamServices.progress,
    userId: userId,
    resume: start.resume,
    now: ExamServices.now,
  );
  final done = Completer<void>();
  final route = MaterialPageRoute<void>(
    builder: (_) => ExamScreen(
      controller: controller,
      firstName: firstName,
      onFlowEnd: () {
        if (!done.isCompleted) done.complete();
      },
      onRetake: () {
        if (context.mounted) unawaited(openPaper(context, paper, repository: repository));
      },
    ),
  );
  unawaited(navigator.push(route));
  await done.future;
}

/// Who is signed in, for keying a saved sitting and greeting the result. Absent in a bare test tree.
({String id, String? firstName}) _session(BuildContext context) {
  try {
    final user = Provider.of<AuthController>(context, listen: false).user;
    return (id: user?.id ?? 'me', firstName: user?.firstName);
  } catch (_) {
    return (id: 'me', firstName: null);
  }
}
