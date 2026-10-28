import 'mentorship_models.dart';

/// Where the Mentorship screens get their mentors: the API, or the designs'
/// sample content.
abstract class MentorshipRepository {
  /// The landing at rest, its mentor shelves scoped to [category] when one is
  /// selected.
  Future<MentorshipOverview> overview({String? category});

  /// Every competency domain a listed mentor has, most mentors first: the
  /// category chips of Find Mentors.
  Future<List<MentorCategory>> categories();

  /// The directory narrowed by the filters; `total` counts every match.
  Future<MentorPage> search(MentorFilters filters, {int page = 1});

  Future<void> setSaved(Mentor mentor, bool saved);

  Future<int> unreadNotifications();

  /// The mentor's page on the website.
  Uri link(Mentor mentor);
}
