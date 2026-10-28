/// What the API refuses on a mentor's offerings, held once so a form refuses as
/// you type exactly what the API would, in its own words. Every limit is the
/// API's (`packages/shared` `MENTOR_SERVICE_LIMITS`, `MENTOR_PLAN_LIMITS`,
/// `GROUP_SESSION_LIMITS`, the DTOs), never a number of the app's own.
library;

import '../../mentorship_my/mentoring_format.dart' show inr, linkProblem, normaliseLink;

/// A session runs this long (`MIN_SESSION_MINUTES`, `MAX_SESSION_MINUTES`).
const minSessionMinutes = 15;
const maxSessionMinutes = 480;

/// `MENTOR_SERVICE_LIMITS`: what a service may be priced at.
const minServicePricePaisa = 49900;
const maxServicePricePaisa = 5000000;

/// The API's sentence for a resource that has no file behind it.
const fileNeededMessage = 'Upload the file before publishing a resource.';

/// A strikethrough price may not make the real one less than half of it (`maxDiscountBps` 5000).
const maxDiscountBps = 5000;

/// Services a mentor may list, drafts included (`maxActiveServices`, which counts every row that is not deleted).
const maxServices = 10;

/// `UpsertMentorServiceDto`.
const minServiceTitle = 4;
const maxServiceTitle = 120;
const maxServiceBlurb = 600;
const minSeats = 2;
const maxSeats = 500;

/// `MENTOR_PLAN_LIMITS` and the plan constants.
const minPlanTitle = 3;
const maxPlanTitle = 80;
const maxPlanBlurb = 400;
const minModuleTitle = 3;
const maxModuleTitle = 120;
const maxModuleOutline = 600;
const minAccessMonths = 1;
const maxAccessMonths = 24;
const maxInclusionChars = 80;
const maxInclusions = 8;
const minPlanModules = 2;
const maxPlanModules = 24;
const minSessionsPerMonth = 1;
const maxSessionsPerMonth = 12;
const planPeriods = [1, 3, 6, 12];

/// An ongoing plan is free, or priced between these (`MIN_PLAN_PRICE_PAISA`, `MAX_PLAN_PRICE_PAISA`).
const minPlanPricePaisa = 50000;
const maxPlanPricePaisa = 50000000;

/// The column's own ceiling (`MAX_PAISA`).
const maxPaisa = 2147483647;

/// `GROUP_SESSION_LIMITS`, `MIN/MAX_GROUP_SESSION_CAPACITY`, `MAX_SESSION_OCCURRENCES`.
const minGroupTitle = 5;
const maxGroupTitle = 160;
const maxGroupSummary = 500;
const maxGroupAgenda = 20000;
const maxGroupLocation = 300;
const maxGroupLink = 500;
const minGroupSeats = 2;
const maxGroupSeats = 50;
const maxGroupDays = 10;

/// A cancel reason (`CancelGroupSessionDto`).
const minCancelReason = 3;
const maxCancelReason = 500;

// ---------------------------------------------------------------------------
// Money
// ---------------------------------------------------------------------------

/// Rupees as typed ("1499", "1,499", "499.50") to paisa; null when it is not a plain amount.
int? paisaOf(String raw) {
  final t = raw.trim().replaceAll(',', '').replaceAll('₹', '');
  if (t.isEmpty) return null;
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(t)) return null;
  return (double.parse(t) * 100).round();
}

/// The rupees a price field starts with: whole rupees, as the website shows them.
String rupeesOf(int? paisa) => paisa == null ? '' : '${(paisa / 100).round()}';

// ---------------------------------------------------------------------------
// A service (1:1 session, resource, legacy group seat)
// ---------------------------------------------------------------------------

String? serviceTitleProblem(String title) {
  final t = title.trim();
  if (t.length < minServiceTitle) return 'Give it a title: at least $minServiceTitle characters.';
  if (t.length > maxServiceTitle) return 'Keep the title under $maxServiceTitle characters.';
  return null;
}

String? blurbProblem(String blurb, {required int max}) =>
    blurb.trim().length > max ? 'Keep the description under $max characters.' : null;

/// The price rule of every service: free, or at least ₹499 and at most ₹50,000; the strikethrough price
/// above it and the price at least half of it.
String? servicePriceProblem({required bool free, required String price, required String compareAt}) {
  if (free) return null;
  final p = paisaOf(price);
  if (p == null) return 'Enter the price in rupees, or switch on Free.';
  if (p < minServicePricePaisa) return 'Priced services start at ${inr(minServicePricePaisa)}.';
  if (p > maxServicePricePaisa) return 'Prices go up to ${inr(maxServicePricePaisa)}.';
  return compareAtProblem(price: p, compareAt: compareAt);
}

/// The strikethrough price (`compareAtPaisa`): empty is fine; else above the price, and the price at least half of it.
String? compareAtProblem({required int price, required String compareAt}) {
  if (compareAt.trim().isEmpty) return null;
  final c = paisaOf(compareAt);
  if (c == null) return 'Enter the strikethrough price in rupees, or leave it empty.';
  if (c <= price) return 'The compare-at price must be higher than the price.';
  if (price * 10000 < c * (10000 - maxDiscountBps)) {
    return 'Discounts are capped at ${maxDiscountBps ~/ 100}%: the price must be at least half of the compare-at price.';
  }
  return null;
}

String? minutesProblem(String raw, {String what = 'A session'}) {
  final m = int.tryParse(raw.trim());
  if (m == null || m < minSessionMinutes || m > maxSessionMinutes) {
    return '$what runs $minSessionMinutes to $maxSessionMinutes minutes.';
  }
  return null;
}

String? seatsProblem(String raw, {int min = minSeats, int max = maxSeats}) {
  final s = int.tryParse(raw.trim());
  if (s == null || s < min || s > max) return 'Seats: a number from $min to $max.';
  return null;
}

// ---------------------------------------------------------------------------
// A plan or programme
// ---------------------------------------------------------------------------

String? planTitleProblem(String title) {
  final t = title.trim();
  if (t.length < minPlanTitle) return 'Give it a title: at least $minPlanTitle characters.';
  if (t.length > maxPlanTitle) return 'Keep the title under $maxPlanTitle characters.';
  return null;
}

/// An ongoing plan's price: free, or between ₹500 and ₹5,00,000 a term; the strikethrough above it.
String? recurringPriceProblem({required bool free, required String price, required String compareAt}) {
  if (free) return null;
  final p = paisaOf(price);
  if (p == null) return 'Enter the price in rupees, or switch on Free.';
  if (p < minPlanPricePaisa || p > maxPlanPricePaisa) {
    return 'An ongoing plan is either free, or priced between ${inr(minPlanPricePaisa)} and ${inr(maxPlanPricePaisa)} per term.';
  }
  if (compareAt.trim().isNotEmpty) {
    final c = paisaOf(compareAt);
    if (c == null) return 'Enter the strikethrough price in rupees, or leave it empty.';
    if (c <= p) return 'The strikethrough price has to be higher than the price you are charging.';
  }
  return null;
}

/// A programme's price is the one rule of "1:1 mentoring": free, or at least ₹499; the strikethrough above it and
/// the price at least half of it.
String? programmePriceProblem({required bool free, required String price, required String compareAt}) {
  if (free) return null;
  final p = paisaOf(price);
  if (p == null) return 'Enter the price in rupees, or switch on Free.';
  if (p < minServicePricePaisa) {
    return '1:1 mentoring is either free or priced at ${inr(minServicePricePaisa)} or more.';
  }
  if (p > maxPaisa) return 'That price is too large.';
  if (compareAt.trim().isNotEmpty) {
    final c = paisaOf(compareAt);
    if (c == null) return 'Enter the strikethrough price in rupees, or leave it empty.';
    if (c <= p) return 'The strikethrough price has to be higher than the price you are charging.';
    if (p * 10000 < c * (10000 - maxDiscountBps)) {
      return 'A discount can be at most ${maxDiscountBps ~/ 100}% off the strikethrough price.';
    }
  }
  return null;
}

/// One syllabus step.
class ModuleDraft {
  ModuleDraft({this.title = '', this.outline = '', this.minutes = ''});

  String title;
  String outline;
  String minutes;
}

String? moduleProblem(int index, ModuleDraft m) {
  final n = index + 1;
  final t = m.title.trim();
  if (t.length < minModuleTitle) return 'Session $n: a title of at least $minModuleTitle characters.';
  if (t.length > maxModuleTitle) return 'Session $n: keep the title under $maxModuleTitle characters.';
  if (m.outline.trim().length > maxModuleOutline) {
    return 'Session $n: keep the outline under $maxModuleOutline characters.';
  }
  if (m.minutes.trim().isNotEmpty) {
    final mins = int.tryParse(m.minutes.trim());
    if (mins == null || mins < minSessionMinutes || mins > maxSessionMinutes) {
      return 'Session $n: $minSessionMinutes to $maxSessionMinutes minutes.';
    }
  }
  return null;
}

String? modulesProblem(List<ModuleDraft> modules) {
  if (modules.length < minPlanModules || modules.length > maxPlanModules) {
    return 'A structured program runs between $minPlanModules and $maxPlanModules sessions.';
  }
  for (final (i, m) in modules.indexed) {
    final p = moduleProblem(i, m);
    if (p != null) return p;
  }
  return null;
}

String? inclusionsProblem(List<String> lines) {
  final kept = [
    for (final l in lines)
      if (l.trim().isNotEmpty) l.trim(),
  ];
  if (kept.length > maxInclusions) return 'List up to $maxInclusions things the plan includes.';
  for (final l in kept) {
    if (l.length > maxInclusionChars) return 'Keep each line under $maxInclusionChars characters.';
  }
  return null;
}

// ---------------------------------------------------------------------------
// A group session
// ---------------------------------------------------------------------------

String? groupTitleProblem(String title) {
  final t = title.trim();
  if (t.length < minGroupTitle) return 'Give it a title: at least $minGroupTitle characters.';
  if (t.length > maxGroupTitle) return 'Keep the title under $maxGroupTitle characters.';
  return null;
}

/// Where people go on the day: a venue for an in-person session, a joining link for every other format.
/// [standingLink] is the mentor's own link on their profile, which stands in for a blank one when a session is created.
String? groupPlaceProblem({
  required bool inPerson,
  required String location,
  required String link,
  bool standingLink = false,
}) {
  if (inPerson) {
    if (location.trim().isEmpty) return 'Add the venue where people will meet.';
    if (location.trim().length > maxGroupLocation) return 'Keep the venue under $maxGroupLocation characters.';
    return null;
  }
  if (link.trim().isEmpty) return standingLink ? null : 'Add the joining link people will use to get in.';
  return linkProblem(link, max: maxGroupLink);
}

/// The link as the API stores it: https:// in front of a bare host, null when blank.
String? linkValue(String raw) => raw.trim().isEmpty ? null : normaliseLink(raw);

/// A day's start must be in the future, and days may not overlap. [days] are (start, minutes) pairs.
String? daysProblem(List<(DateTime, int)> days, DateTime now, {bool requireFuture = true}) {
  if (days.isEmpty) return 'Give the session at least one day.';
  if (days.length > maxGroupDays) return 'A session spans at most $maxGroupDays days: a longer run is a programme.';
  final sorted = [...days]..sort((a, b) => a.$1.compareTo(b.$1));
  for (final (i, d) in sorted.indexed) {
    if (requireFuture && !d.$1.isAfter(now)) return 'Pick a time in the future.';
    if (d.$2 < minSessionMinutes || d.$2 > maxSessionMinutes) {
      return 'A day runs $minSessionMinutes to $maxSessionMinutes minutes.';
    }
    if (i > 0) {
      final prev = sorted[i - 1];
      if (d.$1.isBefore(prev.$1.add(Duration(minutes: prev.$2)))) return 'Days must not overlap.';
    }
  }
  return null;
}

/// A seat price (free when empty): at least ₹499 and at most ₹50,000, and a paid session needs a number of seats.
String? seatPriceProblem({required String price, required String capacity}) {
  if (price.trim().isEmpty) return null;
  final p = paisaOf(price);
  if (p == null) return 'Enter the seat price in rupees, or leave it empty for a free session.';
  if (p < minServicePricePaisa) return 'Priced seats start at ${inr(minServicePricePaisa)}.';
  if (p > maxServicePricePaisa) return 'Prices go up to ${inr(maxServicePricePaisa)}.';
  if (capacity.trim().isEmpty) return 'A paid session needs a number of seats.';
  return null;
}

String? capacityProblem(String raw) {
  if (raw.trim().isEmpty) return null; // uncapped
  final s = int.tryParse(raw.trim());
  if (s == null || s < minGroupSeats || s > maxGroupSeats) {
    return 'Seats: a number from $minGroupSeats to $maxGroupSeats, or leave it empty for no limit.';
  }
  return null;
}

String? cancelReasonProblem(String raw) {
  final r = raw.trim();
  if (r.length < minCancelReason) return 'Write at least $minCancelReason characters.';
  if (r.length > maxCancelReason) return 'Keep the reason under $maxCancelReason characters.';
  return null;
}

/// Plain paragraphs as the simple HTML the API stores an agenda as (`agendaHtml`), escaped.
String agendaHtmlOf(String text) {
  final paras = text.trim().split(RegExp(r'\n\s*\n')).map((p) => p.trim()).where((p) => p.isNotEmpty);
  String esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  return [for (final p in paras) '<p>${esc(p).replaceAll('\n', '<br>')}</p>'].join();
}

/// The agenda's text back out of the API's HTML, for editing.
String agendaTextOf(String? html) {
  if (html == null) return '';
  return html
      .replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</\s*(p|li|h\d|div)\s*>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
