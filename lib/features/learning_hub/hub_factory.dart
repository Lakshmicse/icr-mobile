import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../learning/api_learning_repository.dart';
import '../learning/demo_learning_repository.dart';
import '../learning/learning_controller.dart';
import '../learning_assess/api_assess_repository.dart';
import '../learning_assess/demo_assess_repository.dart';
import '../learning_study/api_study_repository.dart';
import '../learning_study/demo_study_repository.dart';
import 'api_hub_repository.dart';
import 'demo_hub_repository.dart';
import 'hub_controller.dart';

/// Builds the hub's controller (and the course controller inside it) for a
/// screen that was not handed one: the API's repositories, or the sample
/// content under `FEED_SOURCE=demo`.
///
/// A pushed route sits above the tabs' providers, so every public entry screen
/// of the Learning Center makes what it needs this way; the hub passes its own
/// controller down instead, so a pushed screen shares the loaded courses.
LearningHubController createHubController(BuildContext context) {
  if (AppConfig.demo) {
    final assess = DemoAssessRepository();
    final study = DemoStudyRepository();
    return LearningHubController(
      repository: DemoLearningHubRepository(),
      learning: LearningController(DemoLearningRepository(), assess: assess, study: study),
      assess: assess,
      study: study,
      ownsLearning: true,
    );
  }
  final api = context.read<ApiClient>();
  final assess = ApiAssessRepository(api: api);
  final study = ApiStudyRepository(api: api);
  final hub = ApiLearningHubRepository(api: api);
  return LearningHubController(
    repository: hub,
    standingReader: hub.partnerStanding,
    // The course grid's My courses reads the same assessments, mock exams and decks for its shelves of opened
    // learning.
    learning: LearningController(
      ApiLearningRepository(api: api),
      assess: assess,
      study: study,
    ),
    assess: assess,
    study: study,
    ownsLearning: true,
  );
}
