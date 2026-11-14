/// The "When" half of the group-session composer, as the website holds it (`group-schedule/schedule.ts`,
/// `repeat.ts`, `useGroupSchedule.ts`): dates picked on a calendar, a start time they share in the SESSION's time
/// zone (never the phone's), a length, a repeat rule, and a verdict on each date against the mentor's calendar
/// (`GET /mentorship/group-sessions/mine/busy`) before the API judges it. Pure: no widgets.
library;

import 'package:flutter/foundation.dart';

import '../../notifications/viewer_time_zone.dart';
import 'offerings_rules.dart' show maxGroupDays, maxRepeatSessions, maxSessionMinutes, minSessionMinutes;

// ---------------------------------------------------------------------------
// Time zones
// ---------------------------------------------------------------------------

enum _Dst { none, eu, us, au }

/// The zones the composer offers, with their standard offset in minutes and their daylight-saving rule. Dart has no
/// IANA database, so the zones ICR's mentors use are written out; a zone not here (an older session's or a profile's
/// own) reads the phone's clock, as the mentor profile does (`mentor_profile_format.dart`).
const _zones = <String, (int, _Dst)>{
  'Asia/Kolkata': (330, _Dst.none),
  'Asia/Calcutta': (330, _Dst.none),
  'Asia/Colombo': (330, _Dst.none),
  'Asia/Kathmandu': (345, _Dst.none),
  'Asia/Dhaka': (360, _Dst.none),
  'Asia/Karachi': (300, _Dst.none),
  'Asia/Dubai': (240, _Dst.none),
  'Asia/Muscat': (240, _Dst.none),
  'Asia/Riyadh': (180, _Dst.none),
  'Asia/Qatar': (180, _Dst.none),
  'Asia/Bahrain': (180, _Dst.none),
  'Asia/Kuwait': (180, _Dst.none),
  'Asia/Bangkok': (420, _Dst.none),
  'Asia/Jakarta': (420, _Dst.none),
  'Asia/Singapore': (480, _Dst.none),
  'Asia/Kuala_Lumpur': (480, _Dst.none),
  'Asia/Hong_Kong': (480, _Dst.none),
  'Asia/Shanghai': (480, _Dst.none),
  'Asia/Manila': (480, _Dst.none),
  'Asia/Tokyo': (540, _Dst.none),
  'Australia/Perth': (480, _Dst.none),
  'Australia/Sydney': (600, _Dst.au),
  'Australia/Melbourne': (600, _Dst.au),
  'Africa/Lagos': (60, _Dst.none),
  'Africa/Johannesburg': (120, _Dst.none),
  'Africa/Nairobi': (180, _Dst.none),
  'Europe/London': (0, _Dst.eu),
  'Europe/Dublin': (0, _Dst.eu),
  'Europe/Paris': (60, _Dst.eu),
  'Europe/Berlin': (60, _Dst.eu),
  'Europe/Amsterdam': (60, _Dst.eu),
  'Europe/Madrid': (60, _Dst.eu),
  'Europe/Rome': (60, _Dst.eu),
  'Europe/Zurich': (60, _Dst.eu),
  'America/Sao_Paulo': (-180, _Dst.none),
  'America/New_York': (-300, _Dst.us),
  'America/Toronto': (-300, _Dst.us),
  'America/Chicago': (-360, _Dst.us),
  'America/Denver': (-420, _Dst.us),
  'America/Los_Angeles': (-480, _Dst.us),
  'UTC': (0, _Dst.none),
  'Etc/UTC': (0, _Dst.none),
};

/// The zones the Timezone picker lists (Kolkata first, `Asia/Calcutta` left out as the same clock).
final List<String> groupTimezones = [
  for (final z in _zones.keys)
    if (z != 'Asia/Calcutta' && z != 'Etc/UTC') z,
];

bool knownZone(String tz) => _zones.containsKey(tz);

/// The zone a new session starts in before the profile is read: the phone's, as the website takes the browser's.
String phoneZone() => viewerTimeZone() ?? 'Asia/Kolkata';

/// The n-th (1-based) Sunday of a month, or the last one when [nth] is 0, as a UTC midnight.
DateTime _sunday(int year, int month, int nth) {
  if (nth == 0) {
    final last = DateTime.utc(year, month + 1, 0);
    return last.subtract(Duration(days: last.weekday % 7));
  }
  final first = DateTime.utc(year, month, 1);
  return first.add(Duration(days: (7 - first.weekday % 7) % 7 + (nth - 1) * 7));
}

/// The zone's offset from UTC, in minutes, at [utc].
int zoneOffsetAt(String tz, DateTime utc) {
  final z = _zones[tz];
  if (z == null) return utc.toLocal().timeZoneOffset.inMinutes;
  final (std, dst) = z;
  final t = utc.toUtc();
  final y = t.year;
  bool inside(DateTime from, DateTime to) => !t.isBefore(from) && t.isBefore(to);
  final on = switch (dst) {
    _Dst.none => false,
    // Last Sunday of March 01:00 UTC to last Sunday of October 01:00 UTC.
    _Dst.eu => inside(_sunday(y, 3, 0).add(const Duration(hours: 1)), _sunday(y, 10, 0).add(const Duration(hours: 1))),
    // Second Sunday of March 02:00 standard to first Sunday of November 02:00 daylight.
    _Dst.us => inside(
      _sunday(y, 3, 2).add(Duration(minutes: 120 - std)),
      _sunday(y, 11, 1).add(Duration(minutes: 120 - std - 60)),
    ),
    // Southern summer: first Sunday of October 02:00 standard until the first Sunday of April 03:00 daylight.
    _Dst.au => !inside(
      _sunday(y, 4, 1).add(Duration(minutes: 180 - std - 60)),
      _sunday(y, 10, 1).add(Duration(minutes: 120 - std)),
    ),
  };
  return std + (on ? 60 : 0);
}

/// `YYYY-MM-DD` and minutes past midnight in [tz] → the UTC instant (the website's `zonedTimeToUtc`, two passes).
DateTime wallToUtc(String date, int minutes, String tz) {
  final d = parseDateKey(date);
  if (!knownZone(tz)) return DateTime(d.year, d.month, d.day, 0, minutes).toUtc();
  final wall = DateTime.utc(d.year, d.month, d.day, 0, minutes);
  var ts = wall;
  for (var i = 0; i < 2; i++) {
    ts = wall.subtract(Duration(minutes: zoneOffsetAt(tz, ts)));
  }
  return ts;
}

/// An instant → its calendar date and minutes past midnight in [tz].
({String date, int minutes}) wallOf(DateTime instant, String tz) {
  final DateTime w = knownZone(tz)
      ? instant.toUtc().add(Duration(minutes: zoneOffsetAt(tz, instant)))
      : instant.toLocal();
  return (date: dateKeyOf(w.year, w.month, w.day), minutes: w.hour * 60 + w.minute);
}

/// Today, as a calendar date in the zone.
String todayKeyIn(String tz, DateTime now) => wallOf(now, tz).date;

// ---------------------------------------------------------------------------
// Calendar dates as `YYYY-MM-DD` keys (no zone: which dates a weekly clinic falls on does not depend on the hour)
// ---------------------------------------------------------------------------

String dateKeyOf(int y, int m, int d) =>
    '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

DateTime parseDateKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]);
}

String _keyOfUtc(DateTime d) => dateKeyOf(d.year, d.month, d.day);

String addDays(String key, int n) => _keyOfUtc(parseDateKey(key).add(Duration(days: n)));

/// 0 = Sunday … 6 = Saturday.
int weekdayOf(String key) => parseDateKey(key).weekday % 7;

/// Which occurrence of its weekday a date is in its month: 1..5.
int nthWeekdayOf(String key) => (parseDateKey(key).day - 1) ~/ 7 + 1;

int _daysInMonth(int y, int m) => DateTime.utc(y, m + 1, 0).day;

String? _nthWeekdayIn(int y, int m, int weekday, int nth) {
  final first = DateTime.utc(y, m, 1).weekday % 7;
  final day = 1 + (weekday - first + 7) % 7 + (nth - 1) * 7;
  return day <= _daysInMonth(y, m) ? dateKeyOf(y, m, day) : null;
}

/// `YYYY-MM` of a key, and the month after or before.
String monthOf(String key) => key.substring(0, 7);

String shiftMonth(String month, int by) {
  final y = int.parse(month.substring(0, 4));
  final m = int.parse(month.substring(5, 7)) - 1 + by;
  return '${(y + (m / 12).floor()).toString().padLeft(4, '0')}-${(m % 12 + 1).toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// Words: dates and times as the composer prints them
// ---------------------------------------------------------------------------

const _monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthsLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _weekdaysLong = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

/// A weekday name, 0 = Sunday: "Tuesday", "Tue", "T".
String fmtWeekday(int weekday, {String form = 'long'}) {
  final w = _weekdaysLong[weekday % 7];
  return switch (form) {
    'short' => w.substring(0, 3),
    'narrow' => w.substring(0, 1),
    _ => w,
  };
}

/// "Tue, 27 Oct".
String fmtDay(String key) {
  final d = parseDateKey(key);
  return '${fmtWeekday(d.weekday % 7, form: 'short')}, ${d.day} ${_monthsShort[d.month - 1]}';
}

/// "27 Oct".
String fmtShortDay(String key) {
  final d = parseDateKey(key);
  return '${d.day} ${_monthsShort[d.month - 1]}';
}

/// "Tuesday, 27 October 2026".
String fmtLongDay(String key) {
  final d = parseDateKey(key);
  return '${fmtWeekday(d.weekday % 7)}, ${d.day} ${_monthsLong[d.month - 1]} ${d.year}';
}

/// "October 2026" for `2026-10`.
String fmtMonth(String month) => '${_monthsLong[int.parse(month.substring(5, 7)) - 1]} ${month.substring(0, 4)}';

/// "6:00 PM" for minutes past midnight (the app's clock words).
String fmtClock(int minutes) {
  final m = minutes % (24 * 60);
  final h = m ~/ 60;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${(m % 60).toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}

/// "6:00 PM" for an instant on [tz]'s clock.
String fmtInstantClock(DateTime instant, String tz) => fmtClock(wallOf(instant, tz).minutes);

/// "Tue, 27 Oct" for an instant's date in [tz].
String fmtInstantDay(DateTime instant, String tz) => fmtDay(wallOf(instant, tz).date);

/// "6:00 PM–7:00 PM".
String fmtRange(String from, String to) => '$from–$to';

// ---------------------------------------------------------------------------
// The mentor's calendar
// ---------------------------------------------------------------------------

/// Something already on the host's calendar (`GroupBusyIntervalDto`).
class BusyInterval {
  const BusyInterval({
    required this.start,
    required this.end,
    required this.kind,
    required this.blocking,
    this.title,
    this.href,
  });

  factory BusyInterval.fromJson(Map<String, dynamic> j) => BusyInterval(
    start: DateTime.parse(j['start'] as String).toUtc(),
    end: DateTime.parse(j['end'] as String).toUtc(),
    kind: j['kind'] as String? ?? 'GROUP',
    blocking: j['blocking'] != false,
    title: j['title'] as String?,
    href: j['href'] as String?,
  );

  final DateTime start;

  /// Exclusive: back to back is not a clash.
  final DateTime end;

  /// GROUP, GROUP_DRAFT, ONE_TO_ONE, BOOKING or HELD.
  final String kind;

  /// False for another draft's day: a warning, never a refusal.
  final bool blocking;
  final String? title;
  final String? href;

  /// "Group session “Open clinic”", "1:1 session with Meera Nair" (`busyKinds`).
  String get words {
    final t = title ?? '';
    return switch (kind) {
      'GROUP_DRAFT' => 'Draft group session “$t”',
      'ONE_TO_ONE' => '1:1 session with $t',
      'BOOKING' => 'Paid session with $t',
      'HELD' => 'Time held for $t’s request',
      _ => 'Group session “$t”',
    };
  }
}

/// One weekly window the mentor is bookable in, in the profile's zone.
class WeeklyWindow {
  const WeeklyWindow({required this.weekday, required this.startMin, required this.endMin});

  final int weekday;
  final int startMin;
  final int endMin;
}

/// What a new session starts from (`GET /mentorship/mentors/me`): the standing link, the zone, the weekly hours and
/// the group defaults the mentor stored.
class GroupComposerDefaults {
  const GroupComposerDefaults({
    this.meetingLink,
    this.timezone,
    this.windows = const [],
    this.durationMin,
    this.seats,
    this.waitlist,
  });

  factory GroupComposerDefaults.fromJson(Map<String, dynamic> j) => GroupComposerDefaults(
    meetingLink: _text(j['meetingLink']),
    timezone: _text(j['timezone']),
    windows: [
      for (final b in (j['availabilityBlocks'] as List? ?? const []).whereType<Map<String, dynamic>>())
        WeeklyWindow(
          weekday: (b['weekday'] as num?)?.toInt() ?? 0,
          startMin: (b['startMin'] as num?)?.toInt() ?? 0,
          endMin: (b['endMin'] as num?)?.toInt() ?? 0,
        ),
    ],
    durationMin: (j['defaultGroupDurationMin'] as num?)?.toInt(),
    seats: (j['defaultGroupSeats'] as num?)?.toInt(),
    waitlist: j['defaultGroupWaitlist'] is bool ? j['defaultGroupWaitlist'] as bool : null,
  );

  final String? meetingLink;
  final String? timezone;
  final List<WeeklyWindow> windows;
  final int? durationMin;
  final int? seats;
  final bool? waitlist;
}

String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

/// Does [start, start + minutes) fit inside one of the weekly windows (`fitsAvailability`)?
bool fitsWindows(List<WeeklyWindow> windows, String tz, DateTime start, int minutes) {
  final end = start.add(Duration(minutes: minutes));
  for (final offset in [-1, 0, 1]) {
    final day = wallOf(start.add(Duration(days: offset)), tz).date;
    for (final w in windows) {
      if (w.weekday != weekdayOf(day)) continue;
      final from = wallToUtc(day, w.startMin, tz);
      final to = wallToUtc(day, w.endMin, tz);
      if (!start.isBefore(from) && !end.isAfter(to)) return true;
    }
  }
  return false;
}

/// The first interval [start, end) overlaps; `end` exclusive.
BusyInterval? clashWith(DateTime start, DateTime end, List<BusyInterval> busy, {bool blockingOnly = false}) {
  for (final b in busy) {
    if (blockingOnly && !b.blocking) continue;
    if (start.isBefore(b.end) && end.isAfter(b.start)) return b;
  }
  return null;
}

/// The intervals that start on a calendar date in the zone.
List<BusyInterval> busyOnDay(List<BusyInterval> busy, String date, String tz) => [
  for (final b in busy)
    if (wallOf(b.start, tz).date == date) b,
];

// ---------------------------------------------------------------------------
// The dates
// ---------------------------------------------------------------------------

/// A series: one registration for every date. Or one draft per date.
enum RegistrationMode { series, separate }

int capFor(RegistrationMode mode) => mode == RegistrationMode.series ? maxGroupDays : maxRepeatSessions;

var _keyCounter = 0;
String nextRowKey() => 'date-${_keyCounter += 1}';

/// One date of the session: a calendar date and a wall-clock time in the session's zone.
class DateRow {
  DateRow({
    this.id,
    String? key,
    this.date = '',
    this.time,
    required this.durationMin,
    this.title = '',
    this.locked = false,
    this.stored,
    this.status,
  }) : key = key ?? nextRowKey();

  /// The occurrence's id: binds an edit to that day.
  final String? id;
  final String key;

  /// `YYYY-MM-DD` in the session's zone; empty for a copied day not yet given a date.
  String date;

  /// Minutes past midnight in the session's zone; null for a copied day not yet given a date.
  int? time;
  int durationMin;

  /// The day's own topic ("Before the keys").
  String title;

  /// A day that ran, or was closed or cancelled: shown, its topic editable, its time not.
  final bool locked;

  /// A locked row's stored instant, sent back verbatim so the API's exact match holds.
  final DateTime? stored;

  /// The occurrence's status (SCHEDULED, COMPLETED, CANCELLED).
  final String? status;

  bool get dated => locked || (date.isNotEmpty && time != null);
}

/// A dated row's start instant (a locked row's stored one), and its end.
DateTime startOf(DateRow r, String tz) => r.locked && r.stored != null ? r.stored! : wallToUtc(r.date, r.time!, tz);
DateTime endOf(DateRow r, String tz) => startOf(r, tz).add(Duration(minutes: r.durationMin));

List<DateRow> sortRows(Iterable<DateRow> rows, String tz) => [
  for (final r in rows)
    if (r.dated) r,
]..sort((a, b) => startOf(a, tz).compareTo(startOf(b, tz)));

/// What is wrong with a date, as the date list says it.
sealed class RowIssue {
  const RowIssue();
}

class PastIssue extends RowIssue {
  const PastIssue();
}

class MinutesIssue extends RowIssue {
  const MinutesIssue();
}

/// Overlaps the day before it ([day] is that day's number).
class OverlapIssue extends RowIssue {
  const OverlapIssue(this.day);
  final int day;
}

/// Over something booked: blocks the save.
class ClashIssue extends RowIssue {
  const ClashIssue(this.with_);
  final BusyInterval with_;
}

/// Over another draft's day: allowed, said out loud.
class DraftIssue extends RowIssue {
  const DraftIssue(this.with_);
  final BusyInterval with_;
}

class ScheduleVerdict {
  const ScheduleVerdict({
    required this.rows,
    required this.issues,
    required this.complete,
    required this.overCap,
    required this.outsideHours,
  });

  /// Chronological, the order the API will number them in (dated rows only).
  final List<DateRow> rows;
  final Map<String, RowIssue> issues;

  /// Every row has a date and a time.
  final bool complete;

  /// Rows beyond the registration mode's cap.
  final int overCap;

  /// Rows outside the mentor's weekly hours: a reminder, never a block.
  final List<String> outsideHours;

  int get clashes => issues.values.whereType<ClashIssue>().length;
}

/// The website's `judgeSchedule`: chronological, no overlap, every open day in the future, no blocking clash, the
/// caps. Locked rows are history and never judged.
ScheduleVerdict judgeSchedule(
  List<DateRow> rows, {
  required String tz,
  required List<BusyInterval> busy,
  required RegistrationMode mode,
  required DateTime now,
  List<WeeklyWindow> windows = const [],
  String? windowsTz,
}) {
  final sorted = sortRows(rows, tz);
  final issues = <String, RowIssue>{};
  final outside = <String>[];
  for (final (i, r) in sorted.indexed) {
    if (r.locked) continue;
    final start = startOf(r, tz);
    final end = endOf(r, tz);
    if (r.durationMin < minSessionMinutes || r.durationMin > maxSessionMinutes) {
      issues[r.key] = const MinutesIssue();
      continue;
    }
    if (!start.isAfter(now)) {
      issues[r.key] = const PastIssue();
      continue;
    }
    if (i > 0 && start.isBefore(endOf(sorted[i - 1], tz))) {
      issues[r.key] = OverlapIssue(i);
      continue;
    }
    final hit = clashWith(start, end, busy);
    if (hit != null) {
      issues[r.key] = hit.blocking ? ClashIssue(hit) : DraftIssue(hit);
      if (hit.blocking) continue;
    }
    if (windows.isNotEmpty && !fitsWindows(windows, windowsTz ?? tz, start, r.durationMin)) outside.add(r.key);
  }
  return ScheduleVerdict(
    rows: sorted,
    issues: issues,
    complete: rows.isNotEmpty && sorted.length == rows.length,
    overCap: (rows.length - capFor(mode)).clamp(0, 1 << 20),
    outsideHours: outside,
  );
}

/// The payload's days: chronological, a locked row's instant verbatim.
List<Map<String, Object?>> toOccurrences(List<DateRow> rows, String tz) => [
  for (final r in sortRows(rows, tz))
    {
      'id': ?r.id,
      'title': r.title.trim().isEmpty ? null : r.title.trim(),
      'scheduledAt': startOf(r, tz).toUtc().toIso8601String(),
      'durationMin': r.durationMin,
    },
];

// ---------------------------------------------------------------------------
// Repeat
// ---------------------------------------------------------------------------

enum RepeatFreq { day, week, month }

enum RepeatPreset { daily, weekdays, weekly, fortnightly, monthly }

class RepeatRule {
  const RepeatRule({
    required this.freq,
    this.interval = 1,
    this.weekdays = const [],
    this.monthlyByWeekday = true,
    this.count,
    this.until,
  });

  final RepeatFreq freq;
  final int interval;

  /// Week only: 0 = Sunday … 6 = Saturday; empty is the first date's weekday.
  final List<int> weekdays;

  /// Month only: the same nth weekday (true) or the same date.
  final bool monthlyByWeekday;

  /// Ends after this many dates, or [until] (inclusive). One of them is set.
  final int? count;
  final String? until;

  RepeatRule copyWith({
    RepeatFreq? freq,
    int? interval,
    List<int>? weekdays,
    bool? monthlyByWeekday,
    int? count,
    String? until,
    bool endsByCount = true,
  }) => RepeatRule(
    freq: freq ?? this.freq,
    interval: interval ?? this.interval,
    weekdays: weekdays ?? this.weekdays,
    monthlyByWeekday: monthlyByWeekday ?? this.monthlyByWeekday,
    count: endsByCount ? (count ?? this.count ?? defaultRepeatCount) : null,
    until: endsByCount ? null : (until ?? this.until),
  );
}

const defaultRepeatCount = 6;

RepeatRule presetRule(RepeatPreset preset, String first, int count) => switch (preset) {
  RepeatPreset.daily => RepeatRule(freq: RepeatFreq.day, count: count),
  RepeatPreset.weekdays => RepeatRule(freq: RepeatFreq.week, weekdays: const [1, 2, 3, 4, 5], count: count),
  RepeatPreset.weekly => RepeatRule(freq: RepeatFreq.week, weekdays: [weekdayOf(first)], count: count),
  RepeatPreset.fortnightly => RepeatRule(
    freq: RepeatFreq.week,
    interval: 2,
    weekdays: [weekdayOf(first)],
    count: count,
  ),
  RepeatPreset.monthly => RepeatRule(freq: RepeatFreq.month, count: count),
};

/// The preset a rule is, or null when it is custom.
RepeatPreset? presetOf(RepeatRule rule, String first) {
  final w = rule.weekdays;
  if (rule.freq == RepeatFreq.day && rule.interval == 1) return RepeatPreset.daily;
  if (rule.freq == RepeatFreq.week && rule.interval == 1 && w.length == 5 && [1, 2, 3, 4, 5].every(w.contains)) {
    return RepeatPreset.weekdays;
  }
  if (rule.freq == RepeatFreq.week && w.length == 1 && w.first == weekdayOf(first)) {
    if (rule.interval == 1) return RepeatPreset.weekly;
    if (rule.interval == 2) return RepeatPreset.fortnightly;
  }
  if (rule.freq == RepeatFreq.month && rule.interval == 1 && rule.monthlyByWeekday) return RepeatPreset.monthly;
  return null;
}

/// The dates a rule names, [first] included and first, at most [cap] (`repeatDates`).
List<String> repeatDates(String first, RepeatRule rule, int cap) {
  final limit = (rule.count ?? cap).clamp(1, cap < 1 ? 1 : cap);
  final until = rule.count == null ? rule.until : null;
  final interval = rule.interval < 1 ? 1 : rule.interval;
  final out = <String>[first];
  bool push(String key) {
    if (out.length >= limit) return false;
    if (until != null && key.compareTo(until) > 0) return false;
    if (key.compareTo(first) > 0 && !out.contains(key)) out.add(key);
    return true;
  }

  switch (rule.freq) {
    case RepeatFreq.day:
      for (var i = 1; i < limit * interval + 1; i++) {
        if (!push(addDays(first, i * interval))) break;
        if (out.length >= limit) break;
      }
    case RepeatFreq.week:
      final weekdays = ({
        ...(rule.weekdays.isEmpty ? [weekdayOf(first)] : rule.weekdays),
      }.toList()..sort());
      final weekStart = addDays(first, -weekdayOf(first));
      for (var w = 0; w <= 60 * 12; w++) {
        final base = addDays(weekStart, w * 7 * interval);
        var went = true;
        for (final wd in weekdays) {
          final key = addDays(base, wd);
          if (key.compareTo(first) <= 0) continue;
          went = push(key);
          if (!went) break;
        }
        if (!went || out.length >= limit) break;
      }
    case RepeatFreq.month:
      final d = parseDateKey(first);
      final nth = nthWeekdayOf(first);
      final wd = weekdayOf(first);
      for (var i = 1; i < 12 * 10; i++) {
        final total = (d.month - 1) + i * interval;
        final yy = d.year + total ~/ 12;
        final mm = total % 12 + 1;
        final key = rule.monthlyByWeekday
            ? _nthWeekdayIn(yy, mm, wd, nth)
            : (d.day <= _daysInMonth(yy, mm) ? dateKeyOf(yy, mm, d.day) : null);
        if (key == null) continue;
        if (!push(key) || out.length >= limit) break;
      }
  }
  return out;
}

const _nthWords = {1: 'First', 2: 'Second', 3: 'Third', 4: 'Fourth', 5: 'Fifth'};

/// The whole rule in a few words, for the Repeat menu and the custom sheet's summary.
String ruleWords(RepeatRule rule, String first) {
  final weekday = fmtWeekday(weekdayOf(first));
  final nth = _nthWords[nthWeekdayOf(first)]!;
  switch (presetOf(rule, first)) {
    case RepeatPreset.daily:
      return 'Daily';
    case RepeatPreset.weekdays:
      return 'Every Weekday (Mon–Fri)';
    case RepeatPreset.weekly:
      return 'Weekly on $weekday';
    case RepeatPreset.fortnightly:
      return 'Every 2 Weeks on $weekday';
    case RepeatPreset.monthly:
      return 'Monthly on the $nth $weekday';
    case null:
      break;
  }
  final n = rule.interval;
  switch (rule.freq) {
    case RepeatFreq.week:
      final days = (rule.weekdays.isEmpty ? [weekdayOf(first)] : rule.weekdays)
          .map((d) => fmtWeekday(d, form: 'short'))
          .join(', ');
      return n == 1 ? 'Weekly on $days' : 'Every $n Weeks on $days';
    case RepeatFreq.month:
      final every = n == 1 ? 'Monthly' : 'Every $n Months';
      return rule.monthlyByWeekday ? '$every on the $nth $weekday' : '$every on the Same Date';
    case RepeatFreq.day:
      return 'Every $n Days';
  }
}

// ---------------------------------------------------------------------------
// The schedule's state (`useGroupSchedule`)
// ---------------------------------------------------------------------------

/// What the API said no to on save: the row it named, so the list can show it there.
class ServerClash {
  const ServerClash({required this.day, required this.message});

  final int day;
  final String message;
}

/// The dates, the time they share, the zone, the repeat rule that made them, and the busy calendar they are judged
/// against. Every change notifies; the composer redraws and reads the calendar for the window on screen.
class GroupSchedule extends ChangeNotifier {
  GroupSchedule({required this.editing, required this.timezone, required this.now, int defaultDurationMin = 60})
    : durationMin = defaultDurationMin;

  /// Editing a session: days that ran stay, and only a series is possible.
  final bool editing;
  final DateTime Function() now;

  String timezone;

  /// The start time the open dates share, in minutes past midnight.
  int time = 18 * 60;
  int durationMin;
  final List<DateRow> rows = [];
  RepeatRule? rule;
  RegistrationMode mode = RegistrationMode.series;
  String? focused;
  String? _month;
  ServerClash? serverClash;
  List<BusyInterval> busy = const [];
  List<WeeklyWindow> windows = const [];
  String? windowsTz;

  String get today => todayKeyIn(timezone, now());

  /// `YYYY-MM` on screen: the one chosen, else the first date's, else this month.
  String get month {
    if (_month != null) return _month!;
    final first = sortRows(rows.where((r) => r.date.isNotEmpty), timezone);
    return monthOf(first.isEmpty ? today : first.first.date);
  }

  set month(String m) {
    _month = m;
    notifyListeners();
  }

  int get cap => capFor(mode);
  int get lockedCount => rows.where((r) => r.locked).length;

  ScheduleVerdict get verdict =>
      judgeSchedule(rows, tz: timezone, busy: busy, mode: mode, now: now(), windows: windows, windowsTz: windowsTz);

  /// The calendar window the busy read covers: the month on screen and a week either side, stretched over every
  /// dated row, as UTC instants.
  (DateTime, DateTime) get busyWindow {
    final m = month;
    var from = addDays('$m-01', -7);
    var to = addDays('${shiftMonth(m, 1)}-01', 7);
    for (final r in rows) {
      if (r.date.isEmpty) continue;
      if (r.date.compareTo(from) < 0) from = addDays(r.date, -1);
      if (r.date.compareTo(to) >= 0) to = addDays(r.date, 2);
    }
    return (wallToUtc(from, 0, timezone), wallToUtc(to, 0, timezone));
  }

  /// The date a repeat starts from: the first open date, else the day after the last day that ran.
  String? get anchor {
    final open = sortRows(rows.where((r) => !r.locked && r.date.isNotEmpty), timezone);
    if (open.isNotEmpty) return open.first.date;
    final locked = sortRows(rows.where((r) => r.locked), timezone);
    return locked.isEmpty ? null : addDays(wallOf(startOf(locked.last, timezone), timezone).date, 1);
  }

  void _edit(void Function() fn) {
    serverClash = null;
    fn();
    notifyListeners();
  }

  /// A calendar tap: add the date, or take it away. A copied day still without a date takes it first.
  void toggleDate(String date) {
    if (date.compareTo(today) < 0) return;
    focused = date;
    final existing = rows.where((r) => r.date == date).firstOrNull;
    if (existing?.locked ?? false) {
      notifyListeners();
      return;
    }
    rule = null;
    _edit(() {
      if (existing != null) {
        rows.remove(existing);
        return;
      }
      final undated = rows.where((r) => !r.locked && r.date.isEmpty).firstOrNull;
      if (undated != null) {
        undated
          ..date = date
          ..time = time;
      } else {
        rows.add(DateRow(date: date, time: time, durationMin: durationMin));
      }
    });
  }

  void removeRow(String key) {
    rule = null;
    _edit(() => rows.removeWhere((r) => r.key == key));
  }

  void updateRow(String key, {int? time, int? durationMin, String? title}) => _edit(() {
    final r = rows.firstWhere((r) => r.key == key);
    if (time != null) r.time = time;
    if (durationMin != null) r.durationMin = durationMin;
    if (title != null) r.title = title;
  });

  void clear() {
    rule = null;
    _edit(() => rows.removeWhere((r) => !r.locked));
  }

  /// The shared start time: every open date takes it.
  void setTime(int next) {
    time = next;
    _edit(() {
      for (final r in rows) {
        if (!r.locked && r.date.isNotEmpty) r.time = next;
      }
    });
  }

  void setDuration(int next) {
    durationMin = next;
    _edit(() {
      for (final r in rows) {
        if (!r.locked) r.durationMin = next;
      }
    });
  }

  void setTimezone(String next) => _edit(() => timezone = next);

  /// The mentor chose the zone: the profile's, arriving late, no longer replaces it.
  bool zonePicked = false;

  void pickZone(String next) {
    zonePicked = true;
    setTimezone(next);
  }

  void setMode(RegistrationMode next) {
    mode = next;
    notifyListeners();
  }

  void setFocused(String? date) {
    focused = date;
    notifyListeners();
  }

  /// Rebuilds the open dates from a rule; rows already on a kept date keep their time and topic.
  void setRule(RepeatRule? next) {
    rule = next;
    final first = anchor;
    if (next == null || first == null) {
      notifyListeners();
      return;
    }
    _edit(() {
      final keep = rows.where((r) => r.locked).toList();
      final open = rows.where((r) => !r.locked).toList();
      final dates = repeatDates(first, next, (cap - keep.length).clamp(1, cap));
      final built = [
        for (final date in dates)
          open.where((r) => r.date == date).firstOrNull ?? DateRow(date: date, time: time, durationMin: durationMin),
      ];
      rows
        ..clear()
        ..addAll(keep)
        ..addAll(built);
    });
  }

  /// Hydration: an existing session's days, or a copy's dateless ones.
  void load(List<DateRow> next, String zone) {
    rows
      ..clear()
      ..addAll(next);
    timezone = zone;
    final dated = sortRows(next.where((r) => r.date.isNotEmpty), zone);
    final first = dated.isNotEmpty ? dated.first : next.firstOrNull;
    if (first?.time != null) time = first!.time!;
    if (first != null) durationMin = first.durationMin;
    focused = (first?.date.isEmpty ?? true) ? null : first!.date;
    _month = null;
    notifyListeners();
  }

  void setServerClash(ServerClash? clash) {
    serverClash = clash;
    notifyListeners();
  }

  void setBusy(List<BusyInterval> next) {
    busy = next;
    notifyListeners();
  }
}

/// The row an existing day becomes on edit, or on "Run it again" (no date, no id, no lock). A day that ran is
/// locked, except on a draft, which nobody could have attended.
DateRow rowFromDay({
  required String? id,
  required DateTime at,
  required int durationMin,
  required String status,
  String? title,
  required String tz,
  required bool copy,
  required bool draft,
  required DateTime now,
}) {
  if (copy) return DateRow(durationMin: durationMin, title: title ?? '');
  final w = wallOf(at, tz);
  final locked = !draft && (status != 'SCHEDULED' || at.isBefore(now));
  return DateRow(
    id: id,
    date: w.date,
    time: w.minutes,
    durationMin: durationMin,
    title: title ?? '',
    locked: locked,
    stored: locked ? at.toUtc() : null,
    status: status,
  );
}

/// The calendar gate's refusal code: its body names the 1-based day it refused (`MentorCalendarService.assertFree`).
const groupDayClashCode = 'GROUP_DAY_CLASH';
