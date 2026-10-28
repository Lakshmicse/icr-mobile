import 'chapter_models.dart';

/// Where the Chapters screens get their chapters: the API, or the sample
/// content.
abstract class ChaptersRepository {
  /// The board: every published chapter with the member's place in it, and
  /// the upcoming chapter events.
  Future<ChaptersOverview> overview();

  /// A chapter's page, by its slug (or its id), with the member's place.
  Future<ChapterDetail> detail(String idOrSlug);

  /// The roster, a page at a time.
  Future<ChapterMembersPage> members(
    String slug, {
    int page = 1,
    String? search,
    MemberFilter filter = MemberFilter.all,
  });

  /// The chapter's events, upcoming or past, with the member's RSVP on each.
  Future<List<ChapterEvent>> events(String slug, {bool past = false});

  Future<List<ChapterUpdate>> updates(String slug);

  Future<List<ChapterResource>> resources(String slug);

  /// Other chapters in the same country (the website's sidebar).
  Future<List<ChapterSummary>> nearby(ChapterSummary chapter);

  /// Joins the chapter; the role the API gave back.
  Future<ChapterRole> join(ChapterSummary chapter);

  Future<void> leave(ChapterSummary chapter);

  /// Takes a place at one of the chapter's events (the events API's RSVP): `GOING`, or
  /// `WAITLISTED` when the event is full. Throws the API's own refusal (an invite-only event,
  /// a ticketed one).
  Future<String> rsvp(ChapterEvent event);

  /// Gives the place back. A paid ticket is refused by the API, with the sentence to show.
  Future<void> cancelRsvp(ChapterEvent event);

  Future<int> unreadNotifications();

  /// The chapter's page on the website, to share.
  Uri link(ChapterSummary chapter);
}
