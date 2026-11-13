import '../../core/auth/session_user.dart';
import '../learning_exam/exam_format.dart' show groupThousands;
import 'partner_console_models.dart';

/// The rules the console shares with the website: who may use which part of it (`LEARNING_STAFF_ACCESS`,
/// `useLearningCan`), and how a batch's dates, class days and times read (`batch-schedule.ts`).

/// Who is looking at the console. A partner company's admin keeps every area; a member given learning roles
/// reaches the areas their roles allow; anyone else is told the console is the institute's.
class PartnerConsoleViewer {
  const PartnerConsoleViewer({
    required this.role,
    this.learningRoles = const [],
    this.learningPartner = false,
    this.companyId,
  });

  /// With no session to read (a test, the demo): the admin's view.
  static const full = PartnerConsoleViewer(role: 'COMPANY_ADMIN', learningPartner: true, companyId: 'demo');

  factory PartnerConsoleViewer.of(SessionUser? user) => user == null
      ? full
      : PartnerConsoleViewer(
          role: user.role,
          learningRoles: user.learningRoles,
          learningPartner: user.learningPartner,
          companyId: user.companyId,
        );

  final String role;
  final List<String> learningRoles;
  final bool learningPartner;
  final String? companyId;

  /// The owner's access table (13 Oct 2026). `edit` includes view; absent means no access.
  static const access = <String, Map<String, String>>{
    'COURSE_ADMIN': {
      'console': 'view',
      'institution': 'view',
      'courses': 'edit',
      'publish': 'edit',
      'materials': 'edit',
      'batches': 'view',
      'enrolments': 'view',
      'attendance': 'view',
      'assessments': 'edit',
      'certificates': 'view',
    },
    'BATCH_ADMIN': {
      'console': 'view',
      'institution': 'view',
      'courses': 'view',
      'materials': 'view',
      'batches': 'edit',
      'enrolments': 'edit',
      'attendance': 'edit',
      'assessments': 'view',
      'certificates': 'view',
    },
    'ENROLMENT_ADMIN': {
      'console': 'view',
      'institution': 'view',
      'courses': 'view',
      'batches': 'view',
      'enrolments': 'edit',
      'attendance': 'view',
      'certificates': 'view',
    },
    'TRAINER': {
      'console': 'view',
      'courses': 'view',
      'materials': 'edit',
      'batches': 'view',
      'enrolments': 'view',
      'attendance': 'edit',
      'assessments': 'edit',
      'certificates': 'view',
    },
    'FINANCE': {'console': 'view', 'institution': 'view', 'courses': 'view', 'batches': 'view', 'enrolments': 'view'},
  };

  /// Staff of a partner institute: anyone given a learning role at the company they act for, and the admin of a
  /// company ICR approved as a learning partner (the drawer's own rule, `role_workspaces.dart`).
  bool get isPartnerStaff =>
      role == 'PARTNER_ADMIN' ||
      (companyId != null && (learningRoles.isNotEmpty || (role == 'COMPANY_ADMIN' && learningPartner)));

  /// Whether the viewer may use [area] (`learningCan`): a company admin has every area; a learning-role member
  /// what the table grants.
  bool can(String area, {bool edit = true}) {
    if (learningRoles.isEmpty) return true;
    return learningRoles.any((r) {
      final granted = access[r]?[area];
      return granted == 'edit' || (granted == 'view' && !edit);
    });
  }
}

// --- days and times -------------------------------------------------------------------------------------------------

const _dayMs = 86400000;

/// The Indian calendar day a batch date falls on, `YYYY-MM-DD` (`batchCalendarDay`): a picked day is stored at
/// its UTC midnight, 05:30 that day in India.
String indiaDay(DateTime value) {
  final t = value.toUtc().add(const Duration(minutes: 330));
  return '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

/// A calendar day as its UTC midnight ISO string, the form a batch date is stored in (`calendarDayIso`).
String calendarDayIso(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}T00:00:00.000Z';

DateTime? _parseDay(String? day) =>
    day == null || day.length < 10 ? null : DateTime.tryParse('${day.substring(0, 10)}T00:00:00Z');

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "1 Mar 2027" for a `YYYY-MM-DD` day.
String dayWords(String? day) {
  final d = _parseDay(day);
  return d == null ? '—' : '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// A batch date as the day it means in India: "1 Mar 2027".
String batchDayLabel(DateTime? value) => value == null ? '—' : dayWords(indiaDay(value));

/// The weekdays between two calendar days, inclusive, in timetable order (`weekdaysBetween`). A batch of seven
/// days or more, or one with no end, can meet on any.
List<int> weekdaysBetween(String startDay, String? endDay) {
  final start = _parseDay(startDay);
  final end = _parseDay(endDay);
  if (start == null || end == null || end.isBefore(start)) return [...BatchDraft.batchWeekdays];
  final days = (end.difference(start).inMilliseconds / _dayMs).round() + 1;
  if (days >= 7) return [...BatchDraft.batchWeekdays];
  final present = <int>{for (var i = 0; i < days; i++) start.add(Duration(days: i)).weekday % 7};
  return [
    for (final d in BatchDraft.batchWeekdays)
      if (present.contains(d)) d,
  ];
}

/// Runs of three or more consecutive days collapse: "Mon–Fri", "Sat & Sun", "Mon, Wed & Fri".
String _daysLabel(Iterable<int> days) {
  const week = BatchDraft.batchWeekdays;
  final order = [
    for (final d in week)
      if (days.contains(d)) d,
  ];
  if (order.isEmpty) return '';
  final runs = <List<int>>[];
  for (final d in order) {
    final run = runs.isEmpty ? null : runs.last;
    if (run != null && week.indexOf(d) == week.indexOf(run.last) + 1) {
      run.add(d);
    } else {
      runs.add([d]);
    }
  }
  final parts = [
    for (final r in runs)
      if (r.length >= 3)
        '${weekdayShort[r.first]}–${weekdayShort[r.last]}'
      else ...[
        for (final d in r) weekdayShort[d]!,
      ],
  ];
  return parts.length == 1 ? parts.first : '${parts.sublist(0, parts.length - 1).join(', ')} & ${parts.last}';
}

/// The timetable's display string, or null with neither days nor a time (`batchScheduleLabel`).
String? batchScheduleLabel(Iterable<int> days, String? startTime, String? endTime) {
  final dayText = _daysLabel(days);
  final timeText = startTime != null && endTime != null
      ? '$startTime–$endTime'
      : startTime != null
      ? 'from $startTime'
      : '';
  final text = [dayText, timeText].where((s) => s.isNotEmpty).join(', ');
  return text.isEmpty ? null : text;
}

final _classTimeRe = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

/// Why a class time pair is refused, or null (`classTimesError`).
String? classTimesError(String? startTime, String? endTime) {
  if (startTime != null && !_classTimeRe.hasMatch(startTime)) return 'The class start time must be HH:mm.';
  if (endTime != null && !_classTimeRe.hasMatch(endTime)) return 'The class end time must be HH:mm.';
  if (endTime != null && startTime == null) return 'Set the class start time too.';
  if (startTime != null && endTime != null && endTime.compareTo(startTime) <= 0) {
    return 'Classes must end after they start.';
  }
  return null;
}

/// How many classes fall between two calendar days, inclusive, on the given weekdays (`countClassDates`).
int countClassDates(String startDay, String endDay, Iterable<int> days) {
  final start = _parseDay(startDay);
  final end = _parseDay(endDay);
  if (start == null || end == null || end.isBefore(start) || days.isEmpty) return 0;
  var n = 0;
  for (var t = start; !t.isAfter(end); t = t.add(const Duration(days: 1))) {
    if (days.contains(t.weekday % 7)) n++;
  }
  return n;
}

int _minutesOf(String t) => int.parse(t.substring(0, 2)) * 60 + int.parse(t.substring(3, 5));

/// A batch's length from its dates and class days, "6 classes · 18 hours" (`batchLength`); hours only when the
/// class time is known.
String? batchLengthLabel(int classes, String? startTime, String? endTime) {
  if (classes <= 0) return null;
  final mins =
      startTime != null && endTime != null && _classTimeRe.hasMatch(startTime) && _classTimeRe.hasMatch(endTime)
      ? (_minutesOf(endTime) - _minutesOf(startTime)).clamp(0, 24 * 60)
      : 0;
  final hours = ((classes * mins) / 60).round();
  return '$classes class${classes == 1 ? '' : 'es'}${hours > 0 ? ' · $hours hour${hours == 1 ? '' : 's'}' : ''}';
}

/// "3 hrs", "1.5 hrs", "30 min" — how long a class from [start] to [end] runs.
String classSpanLabel(String start, String end) {
  final mins = _minutesOf(end) - _minutesOf(start);
  if (mins < 60) return '$mins min';
  final hrs = mins / 60;
  final text = hrs == hrs.roundToDouble() ? hrs.round().toString() : hrs.toStringAsFixed(1);
  return '$text hr${hrs == 1 ? '' : 's'}';
}

/// A class time on a 12-hour clock: "10:00 AM".
String classTimeWords(String? hhmm) {
  if (hhmm == null || !_classTimeRe.hasMatch(hhmm)) return '';
  final h = int.parse(hhmm.substring(0, 2));
  final m = hhmm.substring(3, 5);
  final hour12 = h % 12 == 0 ? 12 : h % 12;
  return '$hour12:$m ${h < 12 ? 'AM' : 'PM'}';
}

/// Where a batch stands, from its dates alone, as of [now] (`batchStatusFor`): Cancelled when someone cancelled
/// it; else Open until enrolment closes, Scheduled until it starts, Running through its last day, then Completed.
String shownBatchStatus(ConsoleBatch b, {DateTime? now}) {
  if (b.status == 'CANCELLED') return 'CANCELLED';
  final at = now ?? DateTime.now();
  final today = indiaDay(at);
  final lastDay = indiaDay(b.endsAt ?? b.startsAt);
  if (today.compareTo(lastDay) > 0) return 'COMPLETED';
  if (today.compareTo(indiaDay(b.startsAt)) >= 0) return 'RUNNING';
  final closes = b.enrollmentClosesAt ?? b.startsAt;
  return at.isBefore(closes) ? 'OPEN' : 'SCHEDULED';
}

// --- money --------------------------------------------------------------------------------------------------------

const maxDiscountPercent = 90;

/// A stored discount, made safe: a whole number from 0 to the cap (`clampAssessmentDiscount`).
int clampDiscount(num? percent) {
  if (percent == null || !percent.isFinite) return 0;
  final n = percent.round();
  return n <= 0 ? 0 : (n > maxDiscountPercent ? maxDiscountPercent : n);
}

/// What an offer of [percent] takes off [listPaisa], rounded to the paisa (`offerPaisa`).
int offerPaisa(int listPaisa, int percent) => ((listPaisa < 0 ? 0 : listPaisa) * clampDiscount(percent) / 100).round();

/// "₹1,49,900" or "₹374.25" from paise, Indian grouping; paise show only when there are some.
String rupees(int paise) {
  final whole = paise ~/ 100;
  final rest = paise.abs() % 100;
  final text = groupThousands(whole);
  return rest == 0 ? '₹$text' : '₹$text.${rest.toString().padLeft(2, '0')}';
}

/// Whether a `YYYY-MM-DD` offer day is already over today in India (`offerEndDateInPast`).
bool offerEndDateInPast(String endsOn, {DateTime? now}) => endsOn.compareTo(indiaDay(now ?? DateTime.now())) < 0;
