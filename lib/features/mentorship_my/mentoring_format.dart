import 'mentoring_clock.dart';

/// "₹12,500", "₹1,25,000": rupees in Indian grouping, paise only when there are some.
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

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "7:00 PM", on the phone's clock.
String timeLabel(DateTime at) {
  final local = at.toLocal();
  final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
  return '$h:${local.minute.toString().padLeft(2, '0')} ${local.hour < 12 ? 'AM' : 'PM'}';
}

/// "24 Oct", with the year when it is not this one.
String dayLabel(DateTime at, {DateTime? now}) {
  final local = at.toLocal();
  final year = (now ?? mentoringNow()).year == local.year ? '' : ' ${local.year}';
  return '${local.day} ${_months[local.month - 1]}$year';
}

/// "Sat 24 Oct".
String weekdayDay(DateTime at, {DateTime? now}) => '${_weekdays[at.toLocal().weekday - 1]} ${dayLabel(at, now: now)}';

/// "Today", "Tomorrow", else "Mon 26 Oct": the heading over a day's times.
String dayHeading(DateTime at, {DateTime? now}) {
  final today = now ?? mentoringNow();
  final local = at.toLocal();
  final d0 = DateTime(today.year, today.month, today.day);
  final d1 = DateTime(local.year, local.month, local.day);
  return switch (d1.difference(d0).inDays) {
    0 => 'Today',
    1 => 'Tomorrow',
    _ => weekdayDay(at, now: now),
  };
}

/// "Sat 24 Oct, 7:00 PM".
String whenLabel(DateTime at, {DateTime? now}) => '${weekdayDay(at, now: now)}, ${timeLabel(at)}';

/// "Free" or "₹1,499".
String moneyLabel(int paisa) => paisa == 0 ? 'Free' : inr(paisa);

/// "in 3 days", "tomorrow", "today", "yesterday", "2 days ago": how far a day is from today.
String daysFromNow(DateTime at, {DateTime? now}) {
  final today = now ?? mentoringNow();
  final local = at.toLocal();
  final days = DateTime(
    local.year,
    local.month,
    local.day,
  ).difference(DateTime(today.year, today.month, today.day)).inDays;
  return switch (days) {
    0 => 'today',
    1 => 'tomorrow',
    -1 => 'yesterday',
    > 1 => 'in $days days',
    _ => '${-days} days ago',
  };
}

/// "Sat 24 Oct" over "7:00 PM - 7:45 PM": a session's span on one line.
String spanLabel(DateTime at, int minutes) => '${timeLabel(at)} - ${timeLabel(at.add(Duration(minutes: minutes)))}';

/// "October 2026".
String monthLabel(DateTime at) => '${_fullMonths[at.month - 1]} ${at.year}';

const _fullMonths = [
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

/// "45 min", "1 hr", "1 hr 30 min".
String minutesLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h hr' : '$h hr $m min';
}

/// "3 sessions", "1 session".
String countLabel(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';

/// The meeting link as a URL the phone can open; a bare host gets https.
Uri? meetingUri(String? link) {
  final raw = link?.trim();
  if (raw == null || raw.isEmpty) return null;
  final withScheme = raw.startsWith('http://') || raw.startsWith('https://') ? raw : 'https://$raw';
  final uri = Uri.tryParse(withScheme);
  return uri == null || uri.host.isEmpty ? null : uri;
}

/// Plain text from the API's sanitised HTML (agenda, programme detail).
String plainText(String? html) {
  if (html == null) return '';
  return html
      .replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</\s*(p|li|h\d|div)\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// What the website's forms do to a link before it is sent (`normaliseLinkInput`): trim, and put https:// in
/// front of a bare host.
String normaliseLink(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return t;
  return RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false).hasMatch(t) ? t : 'https://$t';
}

/// Why a link would be refused (the API's `IsMeetingLink`: http(s), a host with a dot, at most [max]
/// characters), or null when it is fine. A blank link is fine: it clears the field.
String? linkProblem(String raw, {int max = 500, String what = 'link'}) {
  if (raw.trim().isEmpty) return null;
  final link = normaliseLink(raw);
  if (link.length > max) return 'Keep the $what under $max characters.';
  final uri = Uri.tryParse(link);
  final ok = uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.contains('.');
  return ok ? null : 'Enter a full web address, for example https://meet.google.com/abc-defg-hij.';
}

/// "3 of 4 sessions left".
String sessionsLeft(int left, int allowance) => '$left of ${countLabel(allowance, 'session')} left';

/// "250 KB", "1.2 MB".
String fileSizeLabel(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB'
    : '${(bytes / 1024).round().clamp(1, 1 << 30)} KB';
