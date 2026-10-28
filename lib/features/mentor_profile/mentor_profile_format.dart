import 'mentor_profile_models.dart';

/// "₹12,500", "₹1,25,000": rupees in Indian grouping, paise dropped when
/// there are none (the website's `inr`).
String inr(int paisa) {
  final rupees = paisa ~/ 100;
  final paise = paisa % 100;
  final digits = rupees.toString();
  String grouped;
  if (digits.length <= 3) {
    grouped = digits;
  } else {
    final head = digits.substring(0, digits.length - 3);
    final tail = digits.substring(digits.length - 3);
    grouped = '${head.replaceAllMapped(RegExp(r'(\d)(?=(\d{2})+$)'), (m) => '${m[1]},')},$tail';
  }
  return paise == 0 ? '₹$grouped' : '₹$grouped.${paise.toString().padLeft(2, '0')}';
}

/// "Video call", as the website names a meeting mode.
String modeLabel(String key) => switch (key) {
  'VIDEO' => 'Video call',
  'PHONE' => 'Phone',
  'IN_PERSON' => 'In person',
  'CHAT' => 'Chat / async',
  _ => key,
};

/// "FREE" or the price.
String priceLabel(int paisa) => paisa == 0 ? 'FREE' : inr(paisa);

/// Sales a service (or subscribers a plan) needs before the row says
/// "BEST SELLER": the API's `BEST_SELLER_MIN_SALES`.
const bestSellerMinSales = 5;

/// "26+" for a mentor with a double-digit count of sessions (the design's
/// "26+ Sessions Conducted"; the "+" says "at least", which an exact count
/// always is), the plain number below that.
String sessionsLabel(int sessions) => sessions >= 10 ? '$sessions+' : '$sessions';

/// "1 Month", "3 Months": the length of a programme's term.
String termLabel(int months) => '$months Month${months == 1 ? '' : 's'}';

/// "Month 1" for a one-month term, "Months 1-3" for a three-month one: the span
/// of the roadmap's single block (the design's "Month 1" badge).
String monthsSpan(int months) => months <= 1 ? 'Month 1' : 'Months 1-$months';

/// The name on a plan's "Apply for …" button: the plan's title without a
/// closing "Tier" or "Plan", as the design words it ("Apply for Pro Mentorship"
/// on the "Pro Mentorship Tier" card).
String applyName(String title) {
  final short = title.trim().replaceFirst(RegExp(r'\s+(Tier|Plan)$', caseSensitive: false), '');
  return short.isEmpty ? title.trim() : short;
}

/// "Session 2: Plan" for the second module of a syllabus; a title that
/// already carries the mentor's own numbering ("Week 2: Plan", "Module 2 - Plan")
/// is left as written.
String stepLabel(int index, String title) {
  final text = title.trim();
  if (RegExp(r'^[A-Za-z]+\s+\d+\s*[:\-–]').hasMatch(text)) return text;
  return 'Session ${index + 1}: $text';
}

/// The first tag on a resource's row, from the file behind it.
///
/// A file with a known extension is named for what it is ("PDF Guide"). One
/// stored under a plain name the mentor wrote ("Curated Prompts") keeps that
/// name, as the website shows a resource by its file name. Anything else
/// (a slug like `linkedin-niche-bible`) is a "Digital Guide".
///
/// [generic] is true for that last case: the row then also promises "Instant
/// Download", since the tag says nothing about the file.
({String label, bool generic}) resourceTag(String? fileName) {
  const generic = (label: 'Digital Guide', generic: true);
  final name = fileName?.trim() ?? '';
  if (name.isEmpty) return generic;
  final dot = name.lastIndexOf('.');
  final ext = dot > 0 && dot >= name.length - 6 ? name.substring(dot + 1).toLowerCase() : null;
  if (ext != null && RegExp(r'^[a-z0-9]{1,5}$').hasMatch(ext)) {
    final label = switch (ext) {
      'pdf' => 'PDF Guide',
      'doc' || 'docx' => 'Word Document',
      'xls' || 'xlsx' || 'csv' => 'Spreadsheet',
      'ppt' || 'pptx' => 'Slide Deck',
      'zip' => 'Templates Pack',
      'epub' => 'eBook',
      _ => '${ext.toUpperCase()} File',
    };
    return (label: label, generic: false);
  }
  // A name a person wrote: words, not a slug.
  final readable = name.length <= 24 && name.contains(' ') && !name.contains(RegExp(r'[_/\\]'));
  return readable ? (label: name, generic: false) : generic;
}

/// Whether an API refusal is "add a mobile number" (`PHONE_NEEDED`): the number
/// on file is missing or unusable, so the member is asked for one and may try again.
bool isPhoneRefusal(String? message) => message != null && message.toLowerCase().contains('mobile number');

/// Whole months between two month-years; the end defaults to now.
int monthsBetween(int startYear, int? startMonth, int? endYear, int? endMonth, [DateTime? now]) {
  final current = now ?? DateTime.now();
  final a = startYear * 12 + ((startMonth ?? 1) - 1);
  final b = (endYear ?? current.year) * 12 + ((endMonth ?? (endYear == null ? current.month : 12)) - 1);
  return (b - a + 1).clamp(0, 1 << 20);
}

/// "2 yrs 4 mos", as the design writes a role's length.
String durationLabel(int months) {
  final years = months ~/ 12;
  final rest = months % 12;
  final parts = [
    if (years > 0) '$years yr${years == 1 ? '' : 's'}',
    if (rest > 0 || years == 0) '$rest mo${rest == 1 ? '' : 's'}',
  ];
  return parts.join(' ');
}

/// "10 Yrs" / "8 mos": the short length at a past role's right.
String durationShort(int months) {
  if (months < 12) return '$months mo${months == 1 ? '' : 's'}';
  final years = (months / 12).round();
  return '$years Yr${years == 1 ? '' : 's'}';
}

/// "1 yr ago", "3 mo ago", "12d ago", "today".
String reviewAgo(DateTime at, [DateTime? now]) {
  final days = (now ?? DateTime.now()).difference(at).inDays;
  if (days < 1) return 'today';
  if (days < 30) return '${days}d ago';
  if (days < 365) return '${days ~/ 30} mo ago';
  final years = days ~/ 365;
  return '$years yr${years == 1 ? '' : 's'} ago';
}

/// The next start in the mentor's weekly hours, read in their timezone.
class NextSlot {
  const NextSlot({required this.daysAhead, required this.startMin, required this.weekday});

  final int daysAhead;
  final int startMin;
  final int weekday;

  /// "Next Slot: Tomorrow, 7:00 PM".
  String get label {
    final when = switch (daysAhead) {
      0 => 'Today',
      1 => 'Tomorrow',
      _ => weekdayShort(weekday),
    };
    return 'Next Slot: $when, ${clockLabel(startMin)}';
  }
}

const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

String weekdayShort(int weekday) => _weekdays[weekday % 7];

/// "7:00 PM" for a minute of the day.
String clockLabel(int startMin) {
  final h = startMin ~/ 60;
  final m = startMin % 60;
  final hour12 = h % 12 == 0 ? 12 : h % 12;
  return '$hour12:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}

/// Fixed offsets for the zones mentors on ICR actually use; a zone not here
/// reads the phone's clock, as the website falls back to the viewer's. Zones
/// with daylight saving are taken at standard time.
const _zoneOffsets = <String, int>{
  'Asia/Kolkata': 330,
  'Asia/Calcutta': 330,
  'UTC': 0,
  'Etc/UTC': 0,
  'Asia/Dubai': 240,
  'Asia/Riyadh': 180,
  'Asia/Singapore': 480,
  'Asia/Kuala_Lumpur': 480,
  'Asia/Hong_Kong': 480,
  'Asia/Tokyo': 540,
  'Australia/Sydney': 600,
  'Europe/London': 0,
  'Europe/Berlin': 60,
  'Europe/Paris': 60,
  'America/New_York': -300,
  'America/Chicago': -360,
  'America/Los_Angeles': -480,
};

/// The weekday (0 = Sunday) and minute of the day it is now in [timezone].
({int weekday, int minutes}) zonedNow(DateTime now, String timezone) {
  final offset = _zoneOffsets[timezone];
  final local = offset == null ? now.toLocal() : now.toUtc().add(Duration(minutes: offset));
  return (weekday: local.weekday % 7, minutes: local.hour * 60 + local.minute);
}

/// The website's `nextSlot`: a block already running counts only if it has
/// not begun, since the reader wants a start they can still make.
NextSlot? nextSlot(List<AvailabilityBlock> blocks, String timezone, [DateTime? now]) {
  if (blocks.isEmpty) return null;
  final current = zonedNow(now ?? DateTime.now(), timezone);
  for (var d = 0; d < 8; d++) {
    final day = (current.weekday + d) % 7;
    final starts =
        blocks.where((b) => b.weekday == day && (d > 0 || b.startMin > current.minutes)).map((b) => b.startMin).toList()
          ..sort();
    if (starts.isNotEmpty) return NextSlot(daysAhead: d, startMin: starts.first, weekday: day);
  }
  return null;
}

/// "Mon, Thu, Sat slots": the weekdays the mentor keeps hours on.
String? slotDaysLabel(List<AvailabilityBlock> blocks) {
  if (blocks.isEmpty) return null;
  final days = blocks.map((b) => b.weekday % 7).toSet().toList()..sort();
  // Monday first, Sunday last, as a week reads.
  days.sort((a, b) => ((a + 6) % 7).compareTo((b + 6) % 7));
  return '${days.map(weekdayShort).join(', ')} slots';
}

/// "Sat, 24 Oct • 6:00 PM" for a group session's date.
String sessionDateLabel(DateTime at) {
  final local = at.toLocal();
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${weekdayShort(local.weekday % 7)}, ${local.day} ${months[local.month - 1]} • '
      '${clockLabel(local.hour * 60 + local.minute)}';
}

/// A bio's HTML as paragraphs of plain text.
List<String> bioParagraphs(String? html) {
  if (html == null || html.trim().isEmpty) return const [];
  final blocks = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .split(RegExp(r'</(p|div|li|h[1-6])>', caseSensitive: false))
      .map(
        (b) => b
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&quot;', '"')
            .replaceAll('&#39;', "'")
            .replaceAll(RegExp(r'[ \t]+'), ' ')
            .trim(),
      )
      .where((b) => b.isNotEmpty)
      .toList();
  if (blocks.length == 1 && blocks.single.contains('\n\n')) {
    return blocks.single.split(RegExp(r'\n{2,}')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  }
  return blocks;
}
