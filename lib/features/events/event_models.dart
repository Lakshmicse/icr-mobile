/// What the Events screens draw. The live source fills it from `GET /events`,
/// `GET /events/:slug`, `GET /events/:id/programme`, `GET /events/rsvps/mine`
/// and `GET /mentorship/cpd/target`; the demo source holds the designs' sample
/// content. Fields the API cannot give are marked "demo only".
library;

import '../feed/feed_models.dart' show FeedPicture;

export '../feed/feed_models.dart' show FeedPicture;

/// The Events module's "now": what makes an event past, or a call for proposals still open.
///
/// It reads the device clock. Tests replace it, because the designs' sample content is dated (Oct 24)
/// and its screens change as that day goes by: "RSVP Free" becomes "Ended", "Registration Confirmed"
/// becomes "Event Ended". A golden pins the clock to a day before the design's dates.
DateTime Function() eventsNow = DateTime.now;

/// `EventKind` on the API.
enum EventKind {
  chapterMeet('CHAPTER_MEET', 'Chapter meetup', 'Chapter meetups', 'CHAPTER MEET'),
  webinar('WEBINAR', 'Webinar', 'Webinars', 'WEBINAR'),
  conference('CONFERENCE', 'Conference', 'Conferences', 'CONFERENCE'),
  workshop('WORKSHOP', 'Workshop', 'Workshops', 'WORKSHOP'),
  masterclass('MASTERCLASS', 'Masterclass', 'Masterclasses', 'MASTERCLASS'),
  roundtable('ROUNDTABLE', 'Roundtable', 'Roundtables', 'ROUNDTABLE');

  const EventKind(this.apiKey, this.label, this.plural, this.tag);

  final String apiKey;
  final String label;

  /// The chip's word ("Conferences").
  final String plural;

  /// The pill on a card's photo ("CONFERENCE").
  final String tag;

  static EventKind fromApi(String? v) => values.firstWhere((k) => k.apiKey == v, orElse: () => chapterMeet);
}

/// How an event is attended. The API has no format field: a webinar is online,
/// a venue that names a video platform or "hybrid" says so, the rest is in
/// person (the website reads it the same way).
enum EventFormat {
  inPerson('IN PERSON'),
  online('LIVE VIRTUAL'),
  hybrid('HYBRID');

  const EventFormat(this.tag);
  final String tag;
}

/// `RsvpStatus` on the API, plus "none" for an event the member has no row on.
enum RsvpState {
  none,
  going,
  waitlisted,
  attended,
  cancelled;

  static RsvpState fromApi(String? v) => switch (v) {
    'GOING' => going,
    'WAITLISTED' => waitlisted,
    'ATTENDED' => attended,
    'CANCELLED' => cancelled,
    _ => none,
  };

  /// The member holds a place (or came).
  bool get holds => this == going || this == waitlisted || this == attended;
}

/// The tints of the small pills on a card's photo and in the sheet's hero.
enum TagTone {
  /// Primary fill, white text (CONFERENCE, HYBRID).
  blue,

  /// White fill, primary text (WEBINAR).
  white,

  /// White fill, dark text (ROUNDTABLE, HANDS-ON LAB, 15 CPD CREDITS).
  whiteDark,

  /// Mint fill, dark green text (LIVE VIRTUAL).
  green,

  /// Dark green fill, white text (WORKSHOP).
  greenSolid,

  /// Pink fill, red text (CLOSED-DOOR).
  red,

  /// Translucent navy fill, white text (the hero's kind chip).
  dark,
}

/// A pill on a photo: "WEBINAR", "LIVE VIRTUAL", "15 CPD CREDITS".
class EventTag {
  const EventTag(this.label, this.tone, {this.live = false});

  final String label;
  final TagTone tone;

  /// Draws the little broadcast glyph before the word (LIVE VIRTUAL).
  final bool live;
}

/// The glyph before a card's second line.
enum LineIcon { speaker, venue, lock, lab }

/// The glyph before a footer's note.
enum NoteIcon { none, ticket, zap }

/// The tint of a footer's note.
enum NoteTone { grey, green, caps }

/// The bottom row of an event card: an optional note, share and bookmark
/// glyphs, "Details", and the one thing to do.
class EventFooter {
  const EventFooter({
    this.note,
    this.noteTone = NoteTone.grey,
    this.noteIcon = NoteIcon.none,
    this.action,
    this.share = false,
    this.bookmark = true,
    this.details = false,
  });

  final String? note;
  final NoteTone noteTone;
  final NoteIcon noteIcon;

  /// The outlined button's label ("Register Free"); null for no button.
  final String? action;
  final bool share;
  final bool bookmark;

  /// A "Details" word before the button.
  final bool details;
}

/// The colour of an attendee's initials circle.
enum AvatarTone { blue, mint, lavender, green, slate, count }

/// One circle in an attendee strip. Demo only: the API publishes a count of
/// members going, never who they are.
class EventAvatar {
  const EventAvatar(this.initials, this.tone);

  final String initials;
  final AvatarTone tone;
}

/// An event as the board and the sheet draw it.
class EventSummary {
  const EventSummary({
    required this.id,
    required this.title,
    required this.kind,
    required this.startsAt,
    this.slug,
    this.endsAt,
    this.location,
    this.city,
    this.cover,
    this.host,
    this.council,
    this.capacity,
    this.going = 0,
    this.pricePaisa = 0,
    this.inviteOnly = false,
    this.cpdHours,
    this.rsvp = RsvpState.none,
    this.saved = false,
    this.description,
    this.takesProposals = false,
    this.kicker,
    this.tags,
    this.dateLine,
    this.line,
    this.lineIcon,
    this.lineMaxLines = 2,
    this.speakerLine,
    this.footer,
    this.badge,
    this.attendeePreview = const [],
    this.accreditation,
    this.format,
  });

  final String id;
  final String? slug;
  final String title;
  final EventKind kind;

  /// UTC, as the API sends it; the screens show the Indian clock.
  final DateTime startsAt;
  final DateTime? endsAt;

  /// The venue, as one free-text line on the API.
  final String? location;

  /// The city for the date line ("• Bengaluru"). The API keeps no city apart
  /// from the venue line, so live events leave it null.
  final String? city;
  final FeedPicture? cover;

  /// The chapter or council hosting it.
  final String? host;

  /// The council the event belongs to, when it has one: the industry track the
  /// Explore by Category tiles group by.
  final String? council;
  final int? capacity;

  /// Members going (`attendeeCount`).
  final int going;

  /// Ticket price in paise; 0 is a free event.
  final int pricePaisa;
  final bool inviteOnly;

  /// The hours the CPD ledger would credit for attending: the event's own
  /// length, or one hour when it has no end (the API's `markAttendance` rule).
  final double? cpdHours;
  final RsvpState rsvp;

  /// A bookmark kept on the device; the API has no saved-events list.
  final bool saved;
  final String? description;

  /// Taking talk proposals (`callForSpeakersUntil` ahead).
  final bool takesProposals;

  /// Demo only: the line over the spotlight's title ("FLAGSHIP GLOBAL GATHERING").
  final String? kicker;

  /// The pills on the photo, when the source words them itself; otherwise
  /// [tagsFor] derives them from the kind, format and invitation.
  final List<EventTag>? tags;

  /// The date line, when the source words it itself.
  final String? dateLine;

  /// The card's second line (a speaker, a venue, who it is for).
  final String? line;
  final LineIcon? lineIcon;

  /// Demo only: the design clips a repeated card's line to one row.
  final int lineMaxLines;

  /// The first accepted talk's speaker ("Dr. Radhika Iyer, VP Sustainable
  /// PropTech"), read from the programme; it takes the card's second line
  /// when the event has one.
  final String? speakerLine;

  /// The card's footer, when the source words it itself.
  final EventFooter? footer;

  /// Demo only: the green tick line at the right of the spotlight's venue
  /// ("RICS Accredited"); live events show the price there.
  final String? badge;

  /// Demo only: the overlapping circles before "N Attendees Registered".
  final List<EventAvatar> attendeePreview;

  /// Demo only: the hero's right-hand chip ("RICS CERTIFIED").
  final String? accreditation;

  /// When the source knows the format; else [formatOf] reads the kind and venue.
  final EventFormat? format;

  bool get priced => pricePaisa > 0;
  bool get full => capacity != null && going >= capacity!;
  int? get seatsLeft => capacity == null ? null : (capacity! - going).clamp(0, capacity!);
  bool get past => startsAt.isBefore(eventsNow());

  EventSummary copyWith({
    RsvpState? rsvp,
    bool? saved,
    int? going,
    String? description,
    FeedPicture? cover,
    String? speakerLine,
  }) => EventSummary(
    id: id,
    slug: slug,
    title: title,
    kind: kind,
    startsAt: startsAt,
    endsAt: endsAt,
    location: location,
    city: city,
    cover: cover ?? this.cover,
    host: host,
    council: council,
    capacity: capacity,
    going: going ?? this.going,
    pricePaisa: pricePaisa,
    inviteOnly: inviteOnly,
    cpdHours: cpdHours,
    rsvp: rsvp ?? this.rsvp,
    saved: saved ?? this.saved,
    description: description ?? this.description,
    takesProposals: takesProposals,
    kicker: kicker,
    tags: tags,
    dateLine: dateLine,
    line: line,
    lineIcon: lineIcon,
    lineMaxLines: lineMaxLines,
    speakerLine: speakerLine ?? this.speakerLine,
    footer: footer,
    badge: badge,
    attendeePreview: attendeePreview,
    accreditation: accreditation,
    format: format,
  );
}

/// "My Schedule (2) — Next: AI in FM • Oct 24, 4 PM".
class MySchedule {
  const MySchedule({required this.count, this.next, this.nextLabel});

  /// Upcoming events the member holds a place at.
  final int count;
  final EventSummary? next;

  /// Demo only: the design's short name for the next event ("AI in FM").
  final String? nextLabel;
}

/// "CPD Earned 8.5 / 15 — 6.5 credits needed by Dec 31".
class CpdProgress {
  const CpdProgress({required this.earned, required this.target, required this.year});

  final double earned;
  final double target;
  final int year;

  double get fraction => target <= 0 ? 0 : (earned / target).clamp(0, 1);
  double get remaining => (target - earned).clamp(0, double.infinity);
}

/// The glyph on a category tile.
enum TrackIcon {
  offices,
  tech,
  sustainability,
  conference,
  webinar,
  workshop,
  masterclass,
  roundtable,
  chapter,
  leadership,
  legal,
  finance,
  construction,
  datacentre,
  procurement,
}

/// "Commercial Offices — 12 Events": a tile in Explore by Category. Live
/// tiles are the industry tracks the upcoming events' councils stand for
/// (an event has a kind and a council, never an industry of its own); with
/// fewer than two councils among them they are the event kinds instead.
class EventTrack {
  const EventTrack({
    required this.key,
    required this.label,
    required this.count,
    required this.icon,
    this.kind,
    this.council,
  });

  final String key;
  final String label;
  final int count;
  final TrackIcon icon;

  /// The kind the tile filters by (a kind tile).
  final EventKind? kind;

  /// The track label the tile filters by (`trackLabelOf` of an event's
  /// council); null for a kind tile and for the demo's categories.
  final String? council;

  /// Whether a tap narrows the agenda: the demo's categories match nothing.
  bool get filters => kind != null || council != null;
}

/// Everything the Events tab shows at rest.
class EventsOverview {
  const EventsOverview({
    required this.events,
    this.spotlight,
    this.upcomingCount = 0,
    this.schedule,
    this.cpd,
    this.tracks = const [],
    this.readyCount = 0,
    this.hostBlurb = "Engage ICR's community of CRE & PropTech leaders",
  });

  /// Upcoming events, soonest first.
  final List<EventSummary> events;

  /// The event with the most members going.
  final EventSummary? spotlight;

  /// The number on the "Upcoming" chip: events in the next 30 days.
  final int upcomingCount;
  final MySchedule? schedule;
  final CpdProgress? cpd;
  final List<EventTrack> tracks;

  /// Events in the agenda open to register (not full, not invite-only).
  final int readyCount;

  /// The line under "Host or Propose an Event".
  final String hostBlurb;

  EventsOverview copyWith({
    List<EventSummary>? events,
    EventSummary? spotlight,
    MySchedule? schedule,
    bool clearSchedule = false,
  }) => EventsOverview(
    events: events ?? this.events,
    spotlight: spotlight ?? this.spotlight,
    upcomingCount: upcomingCount,
    schedule: clearSchedule ? null : schedule ?? this.schedule,
    cpd: cpd,
    tracks: tracks,
    readyCount: readyCount,
    hostBlurb: hostBlurb,
  );
}

/// The window and words a search is scoped to.
enum EventWhen { upcoming, past }

enum FormatFilter { any, online, inPerson }

class EventQuery {
  const EventQuery({this.search = '', this.kind, this.when = EventWhen.upcoming, this.format = FormatFilter.any});

  final String search;
  final EventKind? kind;
  final EventWhen when;
  final FormatFilter format;

  /// Anything beyond the board at rest and its kind chips.
  bool get narrows => search.isNotEmpty || when == EventWhen.past || format != FormatFilter.any;

  EventQuery copyWith({
    String? search,
    EventKind? kind,
    bool clearKind = false,
    EventWhen? when,
    FormatFilter? format,
  }) => EventQuery(
    search: search ?? this.search,
    kind: clearKind ? null : kind ?? this.kind,
    when: when ?? this.when,
    format: format ?? this.format,
  );
}

/// An accepted talk on an event's programme, as `GET /events/:id/programme`
/// lists it: a title, an abstract, who gives it and their own line. The API
/// stores no time slot and no session kind (`sessionsFor` spaces and tags them).
class EventTalk {
  const EventTalk({required this.title, this.abstract = '', this.speaker = '', this.bio});

  final String title;
  final String abstract;

  /// The speaker's name.
  final String speaker;

  /// The speaker's own line ("VP Global Real Estate, Infosys").
  final String? bio;
}

/// A session on the sheet's agenda: a talk with the slot and tag
/// `sessionsFor` gives it.
class EventSession {
  const EventSession({
    required this.title,
    required this.speaker,
    this.time,
    this.tag,
    this.tagGreen = false,
    this.panel = false,
  });

  final String title;
  final String speaker;
  final String? time;

  /// "KEYNOTE" / "PANEL".
  final String? tag;
  final bool tagGreen;

  /// Draws the group glyph instead of the microphone.
  final bool panel;
}

/// "Smart IoT & FM Automation — Deploying integrated digital twins…". An
/// event has a description and no list of themes, so a live card is an item of
/// a bold-led list in the description (`describe`); the demo writes its own.
class EventHighlight {
  const EventHighlight({required this.title, required this.body});

  final String title;
  final String body;
}

/// The member's place at the event, as the sheet's pass card shows it.
class EventPass {
  const EventPass({this.reference, required this.holder, this.role = 'Member', this.calendarSynced = false});

  /// Demo only ("ICR-EVT-8849"): the API issues no pass number or QR code to
  /// members; a paid seat is an `EventTicket` row only staff can list.
  final String? reference;

  /// "Alex Rivers (TechCorp)".
  final String holder;

  /// "General Delegate".
  final String role;

  /// Demo only: nothing syncs to a calendar; the website offers an .ics file.
  final bool calendarSynced;
}

/// One event's sheet.
class EventDetail {
  const EventDetail({
    required this.event,
    this.organiser,
    this.sessions = const [],
    this.highlights = const [],
    this.agendaNote,
    this.attendeeNote,
    this.pass,
    this.invited = false,
    this.sellsTickets = false,
  });

  final EventSummary event;

  /// "ICR Vinfraa & PropTech India Chapter".
  final String? organiser;
  final List<EventSession> sessions;
  final List<EventHighlight> highlights;

  /// The pill beside the agenda heading ("Full Day Track • Oct 24").
  final String? agendaNote;

  /// Under "N Attendees Registered" ("19 colleagues from TechCorp attending";
  /// live events say how many seats there are).
  final String? attendeeNote;
  final EventPass? pass;

  /// The member holds an invitation to an invite-only event.
  final bool invited;

  /// A priced event whose seats are bought online right now.
  final bool sellsTickets;

  EventDetail copyWith({EventSummary? event, EventPass? pass, bool clearPass = false}) => EventDetail(
    event: event ?? this.event,
    organiser: organiser,
    sessions: sessions,
    highlights: highlights,
    agendaNote: agendaNote,
    attendeeNote: attendeeNote,
    pass: clearPass ? null : pass ?? this.pass,
    invited: invited,
    sellsTickets: sellsTickets,
  );
}
