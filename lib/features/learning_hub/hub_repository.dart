import 'hub_models.dart';

/// Where the Learning hub gets what the course catalogue does not carry: the
/// institutes, the member's attempt and certificate counts, and a way to write
/// to an institute. The courses themselves come from `LearningRepository`.
abstract class LearningHubRepository {
  /// Every active partner institute, featured ones first.
  Future<List<Institute>> institutes();

  /// How many attempts and certificates the member holds.
  Future<MyLearning> myLearning();

  /// Writes to [institute] (`POST /learning/providers/:slug/enquire`) with the
  /// member's own name and email.
  Future<void> enquireInstitute(Institute institute, {required String message});
}
