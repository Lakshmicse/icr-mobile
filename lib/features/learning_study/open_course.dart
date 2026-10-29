import 'package:flutter/material.dart';

import '../learning_assess/assess_models.dart';
import '../learning_assess/assess_repository.dart';
import '../learning_assess/open_group.dart';
import 'study_models.dart';

/// Opens the page of the Assess your knowledge course a flash-card deck belongs with, in the app: its levels,
/// the plan card ("Open with my plan"), ICR credits for a level or for them all together, and the price. The deck
/// opens whenever the course does (owner's call, 27 Oct 2026), so this is where a locked deck is unlocked.
///
/// The future completes when that page is left, so the caller reads again what the member opened there.
/// [repository] is for tests.
Future<void> openAssessCourse(BuildContext context, StudyCourseRef course, {AssessRepository? repository}) =>
    openPaperGroup(context, PaperKind.assessment, course.code, repository: repository);
