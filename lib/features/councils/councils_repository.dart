import 'council_models.dart';

/// Where the Councils screen gets its councils: the API, or the design's
/// sample content.
abstract class CouncilsRepository {
  /// The screen at rest: the stats, the member's councils, the upcoming
  /// roundtables, the directory and the city chapters.
  Future<CouncilsOverview> overview();

  /// Joins the council; the role the API gave back.
  Future<CouncilRole> join(Council council);

  Future<void> leave(Council council);

  Future<int> unreadNotifications();

  /// The council's page on the website, or one of its tabs (`events`,
  /// `updates`, `leadership`, `members`…).
  Uri link(Council council, {String? tab});

  /// The event's page on the website.
  Uri eventLink(Roundtable roundtable);

  /// The page that adds the roundtable to the member's calendar.
  Uri calendarLink(Roundtable roundtable);

  /// The chapter's page on the website.
  Uri chapterLink(ChapterSummit chapter);
}
