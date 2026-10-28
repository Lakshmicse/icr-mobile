import '../../core/config.dart';
import 'event_models.dart';
import 'events_repository.dart';

const _demo = 'assets/images/demo/events';

/// The Events designs' sample content, word for word, for design review.
/// Actions succeed locally and are not sent anywhere.
class DemoEventsRepository implements EventsRepository {
  DemoEventsRepository();

  final _rsvps = <String, RsvpState>{};
  final _saved = <String>{};

  /// Indian clock to UTC.
  static DateTime _ist(int y, int m, int d, int h, [int min = 0]) =>
      DateTime.utc(y, m, d, h, min).subtract(const Duration(hours: 5, minutes: 30));

  // --- the board -----------------------------------------------------------

  static final ai = EventSummary(
    id: 'ai-in-fm',
    slug: 'future-of-ai-in-facility-management',
    title: 'Future of AI in Facility Management',
    kind: EventKind.webinar,
    startsAt: _ist(2026, 10, 24, 16),
    endsAt: _ist(2026, 10, 24, 17, 30),
    location: 'Online',
    cover: const FeedPicture.asset('$_demo/card_ai.jpg'),
    going: 480,
    cpdHours: 1.5,
    format: EventFormat.online,
    tags: const [EventTag('WEBINAR', TagTone.white), EventTag('LIVE VIRTUAL', TagTone.green, live: true)],
    line: 'Dr. Radhika Iyer, VP Sustainable PropTech',
    lineIcon: LineIcon.speaker,
    footer: const EventFooter(action: 'Register Free', share: true),
  );

  static final summit = EventSummary(
    id: 'proptech-summit-2026',
    slug: 'global-cre-proptech-summit-2026',
    title: 'Global CRE PropTech Summit 2026',
    kind: EventKind.conference,
    startsAt: _ist(2026, 11, 12, 9),
    endsAt: _ist(2026, 11, 14, 17),
    location: 'Mumbai Convention Centre, Bandra Kurla Complex',
    city: 'Mumbai',
    cover: const FeedPicture.asset('$_demo/card_summit.jpg'),
    going: 1420,
    pricePaisa: 1500000,
    cpdHours: 15,
    format: EventFormat.hybrid,
    tags: const [EventTag('CONFERENCE', TagTone.blue), EventTag('15 CPD CREDITS', TagTone.whiteDark)],
    line: 'Mumbai Convention Centre, Bandra Kurla Complex',
    lineIcon: LineIcon.venue,
    footer: const EventFooter(
      note: 'Early Bird Passes Open',
      noteTone: NoteTone.green,
      noteIcon: NoteIcon.ticket,
      details: true,
      bookmark: false,
      action: 'Get Tickets',
    ),
  );

  static final gcc = EventSummary(
    id: 'gcc-net-zero',
    slug: 'sustainable-gcc-campus-net-zero-operations',
    title: 'Sustainable GCC Campus & Net-Zero Operations',
    kind: EventKind.roundtable,
    startsAt: _ist(2026, 11, 25, 14, 30),
    endsAt: _ist(2026, 11, 25, 17),
    location: 'Bengaluru',
    city: 'Bengaluru',
    cover: const FeedPicture.asset('$_demo/card_gcc.jpg'),
    capacity: 25,
    going: 7,
    inviteOnly: true,
    cpdHours: 2.5,
    tags: const [EventTag('ROUNDTABLE', TagTone.whiteDark), EventTag('CLOSED-DOOR', TagTone.red)],
    line: 'Directors & Heads of CRE only (Invitation)',
    lineIcon: LineIcon.lock,
    lineMaxLines: 1,
    footer: const EventFooter(note: '18 / 25 Executive Seats Left', action: 'Request Invite'),
  );

  static final bms = EventSummary(
    id: 'smart-bms-masterclass',
    slug: 'smart-bms-predictive-maintenance-masterclass',
    title: 'Smart BMS & Predictive Maintenance Masterclass',
    kind: EventKind.workshop,
    startsAt: _ist(2026, 12, 4, 10),
    endsAt: _ist(2026, 12, 4, 16),
    location: 'Bangalore HQ',
    city: 'Bangalore HQ',
    cover: const FeedPicture.asset('$_demo/card_bms.jpg'),
    going: 36,
    cpdHours: 6,
    tags: const [EventTag('WORKSHOP', TagTone.greenSolid), EventTag('HANDS-ON LAB', TagTone.whiteDark)],
    line: 'Lab Simulation & Live Sensor Calibration',
    lineIcon: LineIcon.lab,
    lineMaxLines: 1,
    footer: const EventFooter(
      note: '6 CPD Points',
      noteTone: NoteTone.green,
      noteIcon: NoteIcon.zap,
      action: 'Reserve Pass',
    ),
  );

  /// The design repeats the first three cards with their lines on one row and
  /// the webinar's footer counting its registrations.
  static final aiAgain = EventSummary(
    id: 'ai-in-fm-again',
    slug: ai.slug,
    title: ai.title,
    kind: ai.kind,
    startsAt: ai.startsAt,
    endsAt: ai.endsAt,
    location: ai.location,
    cover: ai.cover,
    going: ai.going,
    cpdHours: ai.cpdHours,
    format: ai.format,
    tags: ai.tags,
    line: ai.line,
    lineIcon: ai.lineIcon,
    lineMaxLines: 1,
    footer: const EventFooter(
      note: '480 REGISTERED • FREE SEAT',
      noteTone: NoteTone.caps,
      share: true,
      action: 'Register Free',
    ),
  );

  static final summitAgain = EventSummary(
    id: 'proptech-summit-2026-again',
    slug: summit.slug,
    title: summit.title,
    kind: summit.kind,
    startsAt: summit.startsAt,
    endsAt: summit.endsAt,
    location: summit.location,
    city: summit.city,
    cover: summit.cover,
    going: summit.going,
    pricePaisa: summit.pricePaisa,
    cpdHours: summit.cpdHours,
    format: summit.format,
    tags: summit.tags,
    line: summit.line,
    lineIcon: summit.lineIcon,
    lineMaxLines: 1,
    footer: summit.footer,
  );

  static final gccAgain = EventSummary(
    id: 'gcc-net-zero-again',
    slug: gcc.slug,
    title: gcc.title,
    kind: gcc.kind,
    startsAt: gcc.startsAt,
    endsAt: gcc.endsAt,
    location: gcc.location,
    city: gcc.city,
    cover: gcc.cover,
    capacity: gcc.capacity,
    going: gcc.going,
    inviteOnly: true,
    cpdHours: gcc.cpdHours,
    tags: gcc.tags,
    line: gcc.line,
    lineIcon: gcc.lineIcon,
    lineMaxLines: 1,
    footer: gcc.footer,
  );

  /// The spotlight card: the summit as the design's flagship, free to RSVP.
  static final spotlight = EventSummary(
    id: 'proptech-summit-2026-spotlight',
    slug: summit.slug,
    title: summit.title,
    kind: EventKind.conference,
    startsAt: _ist(2026, 10, 24, 9),
    endsAt: _ist(2026, 10, 24, 17),
    location: 'Mumbai Convention Centre & Hybrid',
    city: 'Mumbai',
    cover: const FeedPicture.asset('$_demo/spotlight.jpg'),
    going: 1420,
    cpdHours: 15,
    format: EventFormat.hybrid,
    kicker: 'FLAGSHIP GLOBAL GATHERING',
    badge: 'RICS Accredited',
    attendeePreview: const [
      EventAvatar('AI', AvatarTone.blue),
      EventAvatar('SI', AvatarTone.mint),
      EventAvatar('VN', AvatarTone.lavender),
    ],
  );

  // --- the sheet -----------------------------------------------------------

  /// The event every card opens: the Event Sheet design.
  EventSummary get sheetEvent => EventSummary(
    id: 'fbis-2024',
    slug: 'future-of-business-innovation-summit',
    title: 'Future of Business & Innovation Summit 2024',
    kind: EventKind.conference,
    startsAt: _ist(2026, 10, 24, 10),
    endsAt: _ist(2026, 10, 24, 16, 30),
    location: 'Grand Auditorium, Hall 3 • Mumbai Convention Centre',
    city: 'Mumbai',
    cover: const FeedPicture.asset('$_demo/sheet_hero.jpg'),
    host: 'ICR Vinfraa & PropTech India Chapter',
    going: 642,
    cpdHours: 4.5,
    format: EventFormat.hybrid,
    rsvp: _rsvps['fbis-2024'] ?? RsvpState.going,
    saved: _saved.contains('fbis-2024'),
    kicker: 'FACILITY MANAGEMENT INNOVATION CONFERENCE',
    accreditation: 'RICS CERTIFIED',
    tags: const [EventTag('CONFERENCE', TagTone.dark), EventTag('HYBRID', TagTone.blue)],
    attendeePreview: const [
      EventAvatar('MK', AvatarTone.blue),
      EventAvatar('TL', AvatarTone.green),
      EventAvatar('RS', AvatarTone.slate),
      EventAvatar('+16', AvatarTone.count),
    ],
    description:
        'The ICR Future of Business & Innovation Summit convenes commercial real estate directors, chief '
        'sustainability officers, and facility operations leaders to explore autonomous building technologies, '
        'predictive maintenance workflows, and net-zero portfolio decarbonization.',
  );

  EventDetail get sheetDetail => EventDetail(
    event: sheetEvent,
    organiser: 'ICR Vinfraa & PropTech India Chapter',
    attendeeNote: '19 colleagues from TechCorp attending',
    pass: sheetEvent.rsvp.holds
        ? const EventPass(
            reference: 'ICR-EVT-8849',
            holder: 'Alex Rivers (TechCorp)',
            role: 'General Delegate',
            calendarSynced: true,
          )
        : null,
    highlights: const [
      EventHighlight(
        title: 'Smart IoT & FM Automation',
        body: 'Deploying integrated digital twins across campus environments.',
      ),
      EventHighlight(
        title: 'ESG & Decarbonization',
        body: 'Operational benchmarking for RICS and LEED zero-carbon audits.',
      ),
    ],
    agendaNote: 'Full Day Track • Oct 24',
    sessions: const [
      EventSession(
        time: '10:00 AM – 11:15 AM',
        tag: 'KEYNOTE',
        title: 'The Autonomous Facility: 2025 Architecture',
        speaker: 'Rajesh Sharma (VP Global Real Estate, Infosys)',
      ),
      EventSession(
        time: '11:30 AM – 12:45 PM',
        tag: 'PANEL',
        tagGreen: true,
        title: 'Retrofitting Commercial Towers with Smart Sensors',
        speaker: 'Priya Nambiar (IGBC AP) & Panelists',
        panel: true,
      ),
    ],
  );

  List<EventSummary> get _agenda => [ai, summit, gcc, bms, aiAgain, summitAgain, gccAgain];

  EventSummary _withState(EventSummary e) => e.copyWith(rsvp: _rsvps[e.id] ?? e.rsvp, saved: _saved.contains(e.id));

  @override
  Future<EventsOverview> overview() async => EventsOverview(
    events: _agenda.map(_withState).toList(),
    spotlight: _withState(spotlight),
    upcomingCount: 24,
    schedule: MySchedule(count: 2, next: ai, nextLabel: 'AI in FM'),
    cpd: const CpdProgress(earned: 8.5, target: 15, year: 2026),
    tracks: const [
      EventTrack(key: 'offices', label: 'Commercial Offices', count: 12, icon: TrackIcon.offices),
      EventTrack(key: 'tech', label: 'Smart Tech & BMS', count: 9, icon: TrackIcon.tech),
      EventTrack(key: 'sustainability', label: 'Sustainability', count: 8, icon: TrackIcon.sustainability),
      EventTrack(key: 'operations', label: 'FM Operations', count: 7, icon: TrackIcon.workshop),
      EventTrack(key: 'proptech', label: 'PropTech', count: 5, icon: TrackIcon.conference),
      EventTrack(key: 'leadership', label: 'Leadership', count: 4, icon: TrackIcon.roundtable),
    ],
    readyCount: 4,
    hostBlurb: 'Engage 18,000+ CRE & PropTech leaders',
  );

  @override
  Future<List<EventSummary>> search(EventQuery query) async {
    final q = query.search.toLowerCase();
    return _agenda
        .where((e) => query.kind == null || e.kind == query.kind)
        .where((e) => q.isEmpty || e.title.toLowerCase().contains(q) || (e.location ?? '').toLowerCase().contains(q))
        .map(_withState)
        .toList();
  }

  @override
  Future<EventDetail> detail(EventSummary event) async => sheetDetail;

  @override
  Future<RsvpState> rsvp(EventSummary event) async => _rsvps[event.id] = RsvpState.going;

  @override
  Future<void> cancel(EventSummary event) async => _rsvps[event.id] = RsvpState.cancelled;

  /// The design's pass, for any place the sample member holds.
  @override
  Future<EventPass?> passFor(EventSummary event) async => event.rsvp.holds
      ? const EventPass(
          reference: 'ICR-EVT-8849',
          holder: 'Alex Rivers (TechCorp)',
          role: 'General Delegate',
          calendarSynced: true,
        )
      : null;

  /// The design's cards word their own second lines.
  @override
  Future<Map<String, String>> speakers(List<EventSummary> events) async => const {};

  /// The design's schedule does not move with the sample actions.
  @override
  MySchedule? schedule(List<EventSummary> known) => MySchedule(count: 2, next: ai, nextLabel: 'AI in FM');

  @override
  Future<int> unreadNotifications() async => 1;

  @override
  Uri link(EventSummary event) => AppConfig.sitePage('/events/${event.slug ?? event.id}');

  /// Keeps the sheet's own bookmark, which the API cannot.
  void setSaved(String id, bool saved) => saved ? _saved.add(id) : _saved.remove(id);
}
