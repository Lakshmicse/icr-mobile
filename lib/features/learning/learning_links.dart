import 'package:share_plus/share_plus.dart';

import '../../core/config.dart';
import '../learning_assess/assess_models.dart' show AssessPaper, PaperGroup, PaperKind;
import '../learning_study/study_models.dart' show StudyTopic;
import 'learning_models.dart' show Course;

/// The website page a learning card stands for, as its share disc sends it: a course's public page, a programme's
/// or a mock exam subject's page, one level or set of it, a flash-card deck's page. The programme and mock paths
/// are the ones `ApiAssessRepository.groupLink` / `paperLink` build (`learning_links_test.dart` holds them equal).
abstract final class LearningLinks {
  static Uri course(Course course) => AppConfig.sitePage('/learning/professional-development/${course.code}');

  static Uri group(PaperGroup group) => AppConfig.sitePage(
    group.kind == PaperKind.mock
        ? '/learning/mock-tests/${group.key}'
        : '/learning/assessment/${group.key.toLowerCase()}',
  );

  static Uri paper(PaperGroup group, AssessPaper paper) => AppConfig.sitePage(
    group.kind == PaperKind.mock
        ? '/learning/mock-tests/${group.key}/${paper.slug}'
        : '/learning/assessment/${group.key.toLowerCase()}/${paper.slug}',
  );

  static Uri deck(StudyTopic deck) => AppConfig.sitePage('/learning/resources/${deck.slug}');
}

/// The phone's share sheet with a card's name and its website link, as the app shares a post, an event or a
/// chapter (owner, 12 Nov 2026: the learning cards' share disc did nothing).
Future<void> shareLearningLink(String title, Uri link) =>
    SharePlus.instance.share(ShareParams(text: '$title\n$link', subject: title)).then((_) {});
