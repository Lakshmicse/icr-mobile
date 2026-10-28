/// Words and numbers as the Councils design writes them.
library;

import 'council_models.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// India Standard Time, which every date on the screen is read in.
const istOffset = Duration(hours: 5, minutes: 30);

DateTime inIst(DateTime t) => t.toUtc().add(istOffset);

/// "Apr 18".
String monthDay(DateTime t) {
  final d = inIst(t);
  return '${_months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}';
}

/// "APR" for the date tile.
String monthCaps(DateTime t) => _months[inIst(t).month - 1].toUpperCase();

/// "18" for the date tile.
String dayOfMonth(DateTime t) => inIst(t).day.toString().padLeft(2, '0');

/// "15:30 – 17:00 IST"; "15:30 IST" when the end is unknown.
String timeRange(DateTime start, DateTime? end) {
  String hm(DateTime t) {
    final d = inIst(t);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  return end == null ? '${hm(start)} IST' : '${hm(start)} – ${hm(end)} IST';
}

/// 2530 → "2,530".
String groupThousands(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

/// The "Peer Members" tile's figure. The design prints a rounded count with a
/// plus ("2,530+"): from a hundred up, the count rounded down to ten and
/// grouped (1,016 → "1,010+"); under a hundred, the exact count.
String peerMembersLabel(int n) => n < 100 ? groupThousands(n) : '${groupThousands(n - n % 10)}+';

/// "Net-Zero & ESG" → "#NetZeroESG": a segment as a hashtag pill.
String hashtag(String segment) {
  final compact = segment.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '');
  return compact.isEmpty ? '#$segment' : '#$compact';
}

/// "Q2" for a moment, and the quarter's first day.
(String, DateTime) quarterOf(DateTime now) {
  final q = (now.month - 1) ~/ 3 + 1;
  return ('Q$q', DateTime(now.year, (q - 1) * 3 + 1, 1));
}

/// "2 Upcoming Events" / "1 Upcoming Event".
String upcomingLabel(int n) => '$n Upcoming Event${n == 1 ? '' : 's'}';

/// "Director ESG @ DLF" → "DLF". The organisation is what follows the last
/// "@" in a person's title, up to a line break (a title that carries its own
/// break, "Brookfield\nIndia", names the first line); null when there is none.
String? organisationOf(String? title) {
  if (title == null) return null;
  final at = title.lastIndexOf('@');
  if (at < 0) return null;
  final first = title.substring(at + 1).trim().split(RegExp(r'[\r\n]+')).first;
  final org = first.replaceAll(RegExp(r'\s+'), ' ').trim();
  return org.isEmpty ? null : org;
}

/// The roundtable row's third line: "Lead: Vikram Malhotra (DLF) • 82 seats
/// claimed". [lead] is the hosting council's chair; without one the line
/// names the hosting council instead.
String roundtableLine({required CouncilChair? lead, required String host, required int going}) {
  final seats = '$going seat${going == 1 ? '' : 's'} claimed';
  if (lead == null || lead.name.isEmpty) return '$host • $seats';
  final org = organisationOf(lead.title);
  return 'Lead: ${lead.name}${org == null ? '' : ' ($org)'} • $seats';
}

/// A roundtable's mode pill, from what the API knows: an invite-only event is
/// closed-door; one held at a hybrid venue wears the city's code ("HYBRID
/// BLR"); one held online (or a webinar) is virtual; the rest are in person.
(String, RoundtableTone) roundtableMode({required String kind, required bool inviteOnly, String? location}) {
  final where = location?.trim() ?? '';
  if (inviteOnly) return ('CLOSED-DOOR', RoundtableTone.dark);
  if (RegExp(r'\bhybrid\b', caseSensitive: false).hasMatch(where)) {
    final code = cityCode(where);
    return (code == null ? 'HYBRID' : 'HYBRID $code', RoundtableTone.green);
  }
  if (kind == 'WEBINAR' || RegExp(r'\b(online|virtual|zoom|webinar)\b', caseSensitive: false).hasMatch(where)) {
    return ('VIRTUAL', RoundtableTone.blue);
  }
  return ('IN-PERSON', RoundtableTone.green);
}

const _cityCodes = {
  'bengaluru': 'BLR',
  'bangalore': 'BLR',
  'mumbai': 'BOM',
  'delhi': 'DEL',
  'new delhi': 'DEL',
  'delhi ncr': 'DEL',
  'delhi-ncr': 'DEL',
  'hyderabad': 'HYD',
  'chennai': 'MAA',
  'kolkata': 'CCU',
  'pune': 'PNQ',
  'ahmedabad': 'AMD',
  'gurugram': 'GGN',
  'noida': 'NOI',
};

/// "Bengaluru (Hybrid)" → "BLR": the airport-style code of the city a venue
/// names (the part before a bracket or comma); the first three letters of a
/// city the table lacks.
String? cityCode(String venue) {
  final city = venue.split(RegExp(r'[(,]')).first.trim();
  if (city.isEmpty) return null;
  final known = _cityCodes[city.toLowerCase()];
  if (known != null) return known;
  final letters = city.replaceAll(RegExp(r'[^A-Za-z]'), '');
  return letters.length < 3 ? null : letters.substring(0, 3).toUpperCase();
}

/// How the design dresses a council cover from its age, since the API has no
/// tier: a council three years old or more is an official council "Est. 2023";
/// one chartered in the last three years wears "CHARTERED 2024"; a new one
/// (under a year) is just "OFFICIAL COUNCIL". `badge` replaces the first pill's
/// "OFFICIAL COUNCIL"; `established` is the second pill.
({String? badge, String? established}) councilTier(DateTime? createdAt, DateTime now) {
  if (createdAt == null) return (badge: null, established: null);
  final days = now.difference(createdAt).inDays;
  final year = inIst(createdAt).year;
  if (days >= 3 * 365) return (badge: null, established: 'Est. $year');
  if (days >= 365) return (badge: 'CHARTERED $year', established: null);
  return (badge: null, established: null);
}

/// A Google Calendar "new event" page for a roundtable, which a phone opens in
/// its calendar app or the browser: the event's own title, times (in UTC, as
/// the API gives them) and venue. The API has no .ics file for an event.
Uri calendarEntry({required String title, required DateTime start, DateTime? end, String? location, String? details}) {
  String two(int n) => n.toString().padLeft(2, '0');
  String stamp(DateTime t) {
    final u = t.toUtc();
    return '${u.year.toString().padLeft(4, '0')}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
  }

  final finish = end ?? start.add(const Duration(hours: 1));
  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': title,
    'dates': '${stamp(start)}/${stamp(finish)}',
    if (details != null && details.isNotEmpty) 'details': details,
    if (location != null && location.isNotEmpty) 'location': location,
  });
}

/// Earlier first; a missing date after every date.
int compareNextEvent(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

/// The joined-councils rail's order: an executive seat first, then the council
/// whose next session comes soonest (one with none last), then by name. The
/// order is read from the data, so a join slots in where it belongs.
List<Council> sortJoined(Iterable<Council> councils) {
  final list = councils.toList();
  int lead(Council c) => c.membership == CouncilRole.lead ? 0 : 1;
  list.sort((a, b) {
    final l = lead(a) - lead(b);
    if (l != 0) return l;
    final n = compareNextEvent(a.nextEventAt, b.nextEventAt);
    if (n != 0) return n;
    return a.name.compareTo(b.name);
  });
  return list;
}
