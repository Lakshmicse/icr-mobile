import 'event_models.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Every clock on the Events screens is the Indian one, which is what ICR's
/// events are announced in (and what the API's notifications read).
DateTime ist(DateTime at) => at.toUtc().add(const Duration(hours: 5, minutes: 30));

String monthShort(DateTime at) => _months[at.month - 1];

/// "OCT" for a date badge.
String monthTag(DateTime at) => monthShort(ist(at)).toUpperCase();

/// "4:00 PM".
String clock(DateTime at, {bool minutes = true}) {
  final t = ist(at);
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  final suffix = t.hour < 12 ? 'AM' : 'PM';
  return minutes || t.minute != 0 ? '$h:$m $suffix' : '$h $suffix';
}

/// "Oct 24, 2026".
String longDay(DateTime at) {
  final t = ist(at);
  return '${monthShort(t)} ${t.day.toString().padLeft(2, '0')}, ${t.year}';
}

/// "Oct 24".
String shortDay(DateTime at) {
  final t = ist(at);
  return '${monthShort(t)} ${t.day}';
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "90 mins" / "3 hrs", as the website's cards; null without an end.
String? durationLabel(EventSummary e) {
  final end = e.endsAt;
  if (end == null) return null;
  final mins = end.difference(e.startsAt).inMinutes;
  if (mins <= 0) return null;
  if (mins < 120) return '$mins mins';
  final hours = mins / 60;
  final rounded = (hours * 10).round() / 10;
  return '${rounded == rounded.roundToDouble() ? rounded.toInt() : rounded} hrs';
}

/// Online, hybrid or in person, read from the kind and the venue as the
/// website does.
EventFormat formatOf(EventSummary e) {
  if (e.format != null) return e.format!;
  final venue = (e.location ?? '').toLowerCase();
  if (RegExp(r'\bhybrid\b').hasMatch(venue)) return EventFormat.hybrid;
  if (e.kind == EventKind.webinar) return EventFormat.online;
  if (RegExp(r'\b(online|virtual|zoom|teams|google meet|webex|livestream)\b').hasMatch(venue)) {
    return EventFormat.online;
  }
  return EventFormat.inPerson;
}

/// "Oct 24, 2026 • 4:00 PM IST • 90 mins" — the line over a photo's foot.
String dateLineFor(EventSummary e) {
  if (e.dateLine != null) return e.dateLine!;
  final start = ist(e.startsAt);
  final end = e.endsAt == null ? null : ist(e.endsAt!);
  if (end != null && !_sameDay(start, end)) {
    final days = start.month == end.month
        ? '${monthShort(start)} ${start.day}-${end.day}, ${start.year}'
        : '${monthShort(start)} ${start.day} - ${monthShort(end)} ${end.day}, ${end.year}';
    return '$days • ${clock(e.startsAt)} IST';
  }
  final online = formatOf(e) == EventFormat.online;
  final tail = online ? durationLabel(e) : (e.city ?? e.location);
  if (tail == null) return '${longDay(e.startsAt)} • ${clock(e.startsAt)} IST';
  return online
      ? '${longDay(e.startsAt)} • ${clock(e.startsAt)} IST • $tail'
      : '${longDay(e.startsAt)} • ${clock(e.startsAt)} • $tail';
}

/// "10:00 AM – 4:30 PM IST" for the sheet's pass card.
String timeRange(EventSummary e) =>
    e.endsAt == null ? '${clock(e.startsAt)} IST' : '${clock(e.startsAt)} – ${clock(e.endsAt!)} IST';

/// "Oct 24, 4 PM" for "Next: … •".
String nextWhen(DateTime at) => '${shortDay(at)}, ${clock(at, minutes: false)}';

/// 8.5 → "8.5", 15.0 → "15".
String hoursLabel(double h) => h == h.roundToDouble() ? h.toInt().toString() : h.toStringAsFixed(1);

/// "15 CPD CREDITS" / "4.5 CPD Credits" / "6 CPD Points".
String cpdLabel(double hours, {String unit = 'CPD Credits'}) => '${hoursLabel(hours)} $unit';

/// "1,420".
String groupThousands(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

/// "₹1,500" for a ticketed event.
String priceLabel(int paisa) {
  final rupees = paisa ~/ 100;
  final rest = paisa % 100;
  return rest == 0 ? '₹${groupThousands(rupees)}' : '₹${groupThousands(rupees)}.${rest.toString().padLeft(2, '0')}';
}

/// The pills on a card's photo: the kind, then how it is attended (or that it
/// is invite-only).
List<EventTag> tagsFor(EventSummary e) {
  if (e.tags != null) return e.tags!;
  final kind = switch (e.kind) {
    EventKind.conference => EventTag(e.kind.tag, TagTone.blue),
    EventKind.webinar => EventTag(e.kind.tag, TagTone.white),
    EventKind.workshop => EventTag(e.kind.tag, TagTone.greenSolid),
    _ => EventTag(e.kind.tag, TagTone.whiteDark),
  };
  final second = e.inviteOnly
      ? const EventTag('INVITE ONLY', TagTone.red)
      : switch (formatOf(e)) {
          EventFormat.online => const EventTag('LIVE VIRTUAL', TagTone.green, live: true),
          EventFormat.hybrid => const EventTag('HYBRID', TagTone.blue),
          EventFormat.inPerson => const EventTag('IN PERSON', TagTone.whiteDark),
        };
  return [kind, second];
}

/// The card's second line: the first speaker, else who it is for, else where
/// it is, else who hosts it.
(String, LineIcon)? lineFor(EventSummary e) {
  if (e.line != null) return (e.line!, e.lineIcon ?? LineIcon.venue);
  if (e.speakerLine != null && e.speakerLine!.trim().isNotEmpty) return (e.speakerLine!.trim(), LineIcon.speaker);
  if (e.inviteOnly) return ('By invitation only', LineIcon.lock);
  if (e.location != null && e.location!.trim().isNotEmpty) return (e.location!.trim(), LineIcon.venue);
  if (e.host != null) return ('Hosted by ${e.host}', LineIcon.speaker);
  return null;
}

/// The short line over the spotlight's title: the kind and how it is attended
/// ("CONFERENCE • HYBRID"). The design's "FLAGSHIP GLOBAL GATHERING" is a
/// tagline the API has no field for.
String kickerFor(EventSummary e) => e.kicker ?? '${e.kind.tag} • ${formatOf(e).tag}';

/// The right-hand slot of the spotlight's venue line and of the sheet's hero,
/// where the design says "RICS Accredited": what the seat costs.
String priceNote(EventSummary e) {
  if (e.inviteOnly) return 'Invite only';
  if (e.priced) return '${priceLabel(e.pricePaisa)} per pass';
  return 'Free for members';
}

/// The card's footer from what the API knows: a free seat to register for,
/// tickets to buy on the website, an invitation, or the place already held.
EventFooter footerFor(EventSummary e) {
  if (e.footer != null) return e.footer!;
  if (e.past) return const EventFooter(note: 'Event ended', action: 'View', bookmark: false);
  if (e.rsvp == RsvpState.going || e.rsvp == RsvpState.attended) {
    return const EventFooter(note: 'Registered', noteTone: NoteTone.green, action: 'View');
  }
  if (e.rsvp == RsvpState.waitlisted) return const EventFooter(note: 'On the waitlist', action: 'View');
  if (e.inviteOnly) {
    final seats = e.seatsLeft;
    return EventFooter(note: seats == null ? 'Invite only' : '$seats / ${e.capacity} Seats Left', action: 'Details');
  }
  if (e.priced) {
    return EventFooter(
      note: '${priceLabel(e.pricePaisa)} per pass',
      noteTone: NoteTone.green,
      noteIcon: NoteIcon.ticket,
      details: true,
      bookmark: false,
      action: 'Get Tickets',
    );
  }
  if (e.full) return const EventFooter(note: 'Waitlist open', action: 'Join Waitlist');
  if (e.cpdHours != null && (e.kind == EventKind.workshop || e.kind == EventKind.masterclass)) {
    return EventFooter(
      note: cpdLabel(e.cpdHours!, unit: 'CPD Points'),
      noteTone: NoteTone.green,
      noteIcon: NoteIcon.zap,
      action: 'Reserve Pass',
    );
  }
  return const EventFooter(action: 'Register Free', share: true);
}

/// HTML as one line of plain text: tags dropped, entities decoded.
String plainText(String html) =>
    _decode(html.replaceAll(RegExp(r'<[^>]+>'), '')).replaceAll(RegExp(r'\s+'), ' ').trim();

String _decode(String text) => text
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'");

/// A description's HTML as plain paragraphs.
List<String> paragraphs(String? html) {
  if (html == null || html.trim().isEmpty) return const [];
  final text = _decode(
    html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|li|h[1-6]|div)>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]+>'), ''),
  );
  return text
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((p) => p.isNotEmpty)
      .toList();
}

/// What the sheet's About section draws from a description: its paragraphs,
/// and the highlight cards a bold-led list in it stands for.
class EventText {
  const EventText(this.paragraphs, this.highlights);

  final List<String> paragraphs;
  final List<EventHighlight> highlights;
}

/// Splits a description into About paragraphs and highlight cards. A list
/// whose every item opens with a bold title (`<li><strong>Smart IoT</strong>:
/// Deploying digital twins…</li>`) becomes cards, as the design draws its two
/// highlights; any other list stays in the paragraphs.
EventText describe(String? html) {
  if (html == null || html.trim().isEmpty) return const EventText([], []);
  final cards = <EventHighlight>[];
  final rest = html.replaceAllMapped(RegExp(r'<ul[^>]*>(.*?)</ul>', caseSensitive: false, dotAll: true), (list) {
    final items = RegExp(
      r'<li[^>]*>(.*?)</li>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(list.group(1)!).map((m) => m.group(1)!.trim()).toList();
    final parsed = [for (final item in items) _highlightOf(item)];
    if (items.isEmpty || parsed.any((h) => h == null)) return list.group(0)!;
    cards.addAll(parsed.cast<EventHighlight>());
    return '';
  });
  return EventText(paragraphs(rest), cards);
}

EventHighlight? _highlightOf(String item) {
  final m = RegExp(r'^<(strong|b)>(.*?)</\1>\s*[:–—-]?\s*(.*)$', caseSensitive: false, dotAll: true).firstMatch(item);
  if (m == null) return null;
  final title = plainText(m.group(2)!);
  if (title.isEmpty) return null;
  return EventHighlight(title: title, body: plainText(m.group(3)!));
}

/// Initials for an attendee circle: "Alex Rivers" → "AR".
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return '${parts.first[0]}${parts.length > 1 ? parts.last[0] : ''}'.toUpperCase();
}

// --- tracks ----------------------------------------------------------------------

/// The industry track a council stands for, as a tile's title: the council's
/// name without "Council", cut at its first comma ("Smart Buildings, BMS &
/// PropTech Council" is "Smart Buildings"), or at " & " when what comes
/// first is more than one word ("Data Centre & Digital Infrastructure" is
/// "Data Centre"); a short name in brackets at the end ("(BFSI)") wins. Null
/// for an event with no council.
String? trackLabelOf(String? council) {
  final name = (council ?? '').trim().replaceFirst(RegExp(r'\s+council$', caseSensitive: false), '').trim();
  if (name.isEmpty) return null;
  final acronym = RegExp(r'\(([A-Za-z]{2,8})\)$').firstMatch(name);
  if (acronym != null) return acronym.group(1);
  final comma = name.indexOf(',');
  if (comma > 0) return name.substring(0, comma).trim();
  final amp = name.indexOf(' & ');
  if (amp > 0) {
    final first = name.substring(0, amp).trim();
    if (first.contains(' ')) return first;
  }
  return name;
}

/// The glyph a track's tile wears, chosen by what its label talks about.
TrackIcon trackIconFor(String label) {
  final t = label.toLowerCase();
  bool has(List<String> words) => words.any(t.contains);
  if (has(['sustain', 'esg', 'green', 'net-zero', 'net zero', 'environment'])) return TrackIcon.sustainability;
  if (has(['data cent', 'infrastructure'])) return TrackIcon.datacentre;
  if (has(['smart', 'bms', 'tech', 'digital', 'iot'])) return TrackIcon.tech;
  if (has(['legal', 'compliance', 'contract'])) return TrackIcon.legal;
  if (has(['bfsi', 'bank', 'financ', 'insur'])) return TrackIcon.finance;
  if (has(['construction', 'project', 'mep', 'engineer'])) return TrackIcon.construction;
  if (has(['procure', 'supply', 'vendor', 'rfq'])) return TrackIcon.procurement;
  if (has(['cxo', 'leader', 'workplace', 'executive', 'management'])) return TrackIcon.leadership;
  return TrackIcon.offices;
}

/// The track an event belongs to, by its council.
String? trackOf(EventSummary e) => trackLabelOf(e.council);

// --- who is going ----------------------------------------------------------------

const _hostFiller = {'&', 'and', 'of', 'the', 'for'};

/// Up to three overlapping circles for an event. The API names no attendee,
/// so they carry the initials of the words of the hosting chapter or council
/// ("ICR Vinfraa & PropTech India Chapter" is I, V, P), or I, C, R when ICR
/// hosts it itself.
List<EventAvatar> hostAvatars(
  String? host, {
  List<AvatarTone> tones = const [AvatarTone.blue, AvatarTone.mint, AvatarTone.lavender],
}) {
  final words = (host ?? '')
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((w) => w.isNotEmpty && !_hostFiller.contains(w.toLowerCase()))
      .toList();
  final letters = words.isEmpty ? const ['I', 'C', 'R'] : [for (final w in words.take(3)) w[0].toUpperCase()];
  return [for (final (i, l) in letters.indexed) EventAvatar(l, tones[i % tones.length])];
}

/// 639 → "639", 1420 → "1.4k", 12000 → "12k": the "+N" circle's number.
String compactCount(int n) {
  if (n < 1000) return '$n';
  final k = n / 1000;
  final text = k >= 10 ? k.round().toString() : k.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  return '${text}k';
}

// --- the programme -----------------------------------------------------------------

/// How a talk is tagged: its own words say keynote, panel, fireside or
/// workshop, else it is a talk.
({String tag, bool green, bool panel}) talkTag(String title, String abstract) {
  final t = '$title $abstract'.toLowerCase();
  if (RegExp(r'\bkeynote\b').hasMatch(t)) return (tag: 'KEYNOTE', green: false, panel: false);
  if (RegExp(r'\bpanel\b').hasMatch(t)) return (tag: 'PANEL', green: true, panel: true);
  if (RegExp(r'\bfireside\b').hasMatch(t)) return (tag: 'FIRESIDE', green: true, panel: false);
  if (RegExp(r'\b(workshop|hands-on)\b').hasMatch(t)) return (tag: 'WORKSHOP', green: true, panel: false);
  return (tag: 'TALK', green: false, panel: false);
}

/// "Dr. Radhika Iyer, VP Sustainable PropTech": the card's speaker line.
String speakerCardLine(EventTalk talk) {
  final bio = talk.bio?.trim() ?? '';
  if (talk.speaker.isEmpty) return bio;
  return bio.isEmpty ? talk.speaker : '${talk.speaker}, $bio';
}

/// Where each talk sits. ICR stores no running order, so the slots are laid
/// out from the event's start: 75 minutes a talk with 15 between, squeezed to
/// fit the first day's window (and a lone talk at a short event takes all of it).
List<(DateTime, DateTime)> talkSlots(EventSummary event, int count) {
  if (count <= 0) return const [];
  const talk = 75;
  const gap = 15;
  final start = event.startsAt;
  final cap = start.add(const Duration(hours: 8));
  final end = event.endsAt;
  final windowEnd = end == null
      ? start.add(Duration(minutes: count * talk + (count - 1) * gap))
      : (end.isAfter(cap) ? cap : end);
  final window = windowEnd.difference(start).inMinutes;
  var slot = talk;
  if (count == 1 && window <= 120) {
    slot = window;
  } else if (count * talk + (count - 1) * gap > window) {
    slot = (((window - (count - 1) * gap) / count) / 5).floor() * 5;
    if (slot < 15) slot = 15;
  }
  return [
    for (var i = 0; i < count; i++)
      (start.add(Duration(minutes: i * (slot + gap))), start.add(Duration(minutes: i * (slot + gap) + slot))),
  ];
}

/// The sheet's agenda: a card per accepted talk, with its slot and tag.
List<EventSession> sessionsFor(EventSummary event, List<EventTalk> talks) {
  final slots = talkSlots(event, talks.length);
  return [
    for (final (i, t) in talks.indexed)
      () {
        final kind = talkTag(t.title, t.abstract);
        final bio = t.bio?.trim() ?? '';
        final who = t.speaker.isEmpty
            ? (bio.isEmpty ? 'Speaker to be announced' : bio)
            : (bio.isEmpty ? t.speaker : '${t.speaker} ($bio)');
        return EventSession(
          title: t.title,
          speaker: kind.panel ? '$who & Panelists' : who,
          time: '${clock(slots[i].$1)} – ${clock(slots[i].$2)}',
          tag: kind.tag,
          tagGreen: kind.green,
          panel: kind.panel,
        );
      }(),
  ];
}

// --- the member's pass -------------------------------------------------------------

/// The last four letters and digits of an event's id, upper case: its code.
String eventCode(String id) {
  final clean = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  return clean.length <= 4 ? clean : clean.substring(clean.length - 4);
}

/// "ICR-EVT-FBIS": what the pass card calls the member's place. ICR issues no
/// pass numbers, so this is the event's code, not a ticket's.
String passReference(String eventId) => 'ICR-EVT-${eventCode(eventId)}';

/// A Google Calendar "add event" page for the event, filled in. ICR syncs
/// with no calendar, so this is what "Add to calendar" opens.
Uri googleCalendarUri(EventSummary e, Uri page) {
  String two(int n) => n.toString().padLeft(2, '0');
  String stamp(DateTime d) {
    final u = d.toUtc();
    return '${u.year.toString().padLeft(4, '0')}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
  }

  final end = e.endsAt ?? e.startsAt.add(const Duration(hours: 1));
  final venue = e.location?.trim() ?? '';
  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': e.title,
    'dates': '${stamp(e.startsAt)}/${stamp(end)}',
    if (venue.isNotEmpty) 'location': venue,
    'details': 'ICR event page: $page',
  });
}
