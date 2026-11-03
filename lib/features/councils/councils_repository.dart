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

/// What a council's own page reads and does (`council_screen.dart`). Kept apart from [CouncilsRepository] so a
/// source that only feeds the board (a test double) is not asked for it; the API and the sample sources are both.
abstract class CouncilPageRepository {
  /// A council's page by its slug (or its id: a notification or a membership names one), with the member's seat.
  Future<CouncilDetail> detail(String idOrSlug);

  /// The roster, a page at a time.
  Future<CouncilMembersPage> members(
    String slug, {
    int page = 1,
    String? search,
    MemberFilter filter = MemberFilter.all,
  });

  /// The council's events, upcoming or past, with the member's RSVP on each.
  Future<List<CouncilEvent>> events(String slug, {bool past = false});

  /// Announcements, pinned first, then newest.
  Future<List<CouncilUpdate>> updates(String slug);

  /// The knowledge library.
  Future<List<CouncilResource>> resources(String slug);

  /// Joins the council; the role the API gave back.
  Future<CouncilRole> join(Council council);

  Future<void> leave(Council council);

  Future<int> unreadNotifications();

  /// The council's page on the website, to share.
  Uri link(Council council, {String? tab});
}
