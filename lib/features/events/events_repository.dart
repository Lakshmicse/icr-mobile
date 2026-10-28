import 'event_models.dart';

/// Where the Events screens get their events: the API, or the designs' sample
/// content.
abstract class EventsRepository {
  /// The board at rest: the upcoming events, the spotlight, the member's
  /// schedule and CPD, the category tiles.
  Future<EventsOverview> overview();

  /// The board narrowed by a search, a window or a format.
  Future<List<EventSummary>> search(EventQuery query);

  /// The sheet: the full event, its programme and the member's place.
  Future<EventDetail> detail(EventSummary event);

  /// Takes a place; the API answers GOING, or WAITLISTED when the event is full.
  Future<RsvpState> rsvp(EventSummary event);

  Future<void> cancel(EventSummary event);

  /// The pass card for a place the member holds at [event] (null when they
  /// hold none): who they are and, for a confirmed place, the pass reference.
  Future<EventPass?> passFor(EventSummary event);

  /// The first accepted speaker of each of [events] that has a programme, as
  /// a card's second line ("Dr. Radhika Iyer, VP Sustainable PropTech"),
  /// keyed by event id. Events without talks are left out.
  Future<Map<String, String>> speakers(List<EventSummary> events);

  /// The member's places that are still ahead, from the RSVPs this source
  /// knows now (taking or giving back a place changes them at once); null
  /// when they hold none.
  MySchedule? schedule(List<EventSummary> known);

  Future<int> unreadNotifications();

  /// The event's page on the website.
  Uri link(EventSummary event);
}
