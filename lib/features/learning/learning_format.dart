import 'learning_models.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _two(int n) => n.toString().padLeft(2, '0');

/// A run's dates as the design's tiles write them: "Aug 23 - 27, 2024",
/// "Aug 30 - Sep 03, 2024", "Dec 30, 2024 - Jan 03, 2025", or one day.
String runDates(DateTime start, DateTime? end) {
  final s = start.toLocal();
  final e = end?.toLocal();
  String month(DateTime d) => _months[d.month - 1];
  if (e == null || (e.year == s.year && e.month == s.month && e.day == s.day)) {
    return '${month(s)} ${_two(s.day)}, ${s.year}';
  }
  if (e.year == s.year && e.month == s.month) return '${month(s)} ${_two(s.day)} - ${_two(e.day)}, ${s.year}';
  if (e.year == s.year) return '${month(s)} ${_two(s.day)} - ${month(e)} ${_two(e.day)}, ${s.year}';
  return '${month(s)} ${_two(s.day)}, ${s.year} - ${month(e)} ${_two(e.day)}, ${e.year}';
}

/// "2024 Schedule": the year the shown runs start in.
String? scheduleLabel(List<CourseRun> runs) {
  if (runs.isEmpty) return null;
  final years = runs.map((r) => r.startsAt.toLocal().year).toSet().toList()..sort();
  return years.length == 1 ? '${years.first} Schedule' : '${years.first}–${years.last} Schedule';
}

/// "₹11,800" from paise, keeping paise only when there are some; "Free" for
/// nothing; another currency reads "AED 1,200".
String priceLabel(int? paise, [String currency = 'INR']) {
  if (paise == null || paise <= 0) return 'Free';
  final whole = paise ~/ 100;
  final rest = paise % 100;
  final number = rest == 0 ? groupThousands(whole) : '${groupThousands(whole)}.${_two(rest)}';
  return currency == 'INR' ? '₹$number' : '$currency $number';
}

/// Indian grouping, as the website: 1180000 → "11,80,000"; 11800 → "11,800".
String groupThousands(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final last = s.substring(s.length - 3);
  var head = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (head.length > 2) {
    parts.insert(0, head.substring(head.length - 2));
    head = head.substring(0, head.length - 2);
  }
  if (head.isNotEmpty) parts.insert(0, head);
  return '${parts.join(',')},$last';
}

/// "Leadership" from the API's `LearningLevel`.
String? levelLabel(String? level) => switch (level) {
  'FOUNDATION' => 'Foundation',
  'INTERMEDIATE' => 'Intermediate',
  'ADVANCED' => 'Advanced',
  'LEADERSHIP' => 'Leadership',
  'SPECIALIST' => 'Specialist',
  _ => null,
};

/// The levels the website sells as senior credentials.
bool _seniorLevel(String? level) => level == 'ADVANCED' || level == 'LEADERSHIP' || level == 'SPECIALIST';

/// The pill on a course's cover, worded from the course itself: a course that
/// issues a certificate reads "PREMIUM CERTIFICATION" at the senior levels
/// (Advanced, Leadership, Specialist) and "CERTIFICATION" below them; one that
/// does not reads its level — "LEADERSHIP COURSE", or "FOUNDATION
/// CERTIFICATION" for a certification programme (its levels are sat as papers).
String? coverBadge(String? level, CourseKind kind, {bool certificateEnabled = false}) {
  if (certificateEnabled) return _seniorLevel(level) ? 'PREMIUM CERTIFICATION' : 'CERTIFICATION';
  final label = levelLabel(level)?.toUpperCase();
  if (kind == CourseKind.assessment) return label == null ? 'CERTIFICATION' : '$label CERTIFICATION';
  return label == null ? null : '$label COURSE';
}

/// ICR's published enquiries address (the website's contact page and terms).
/// The design prints the enrolment specialist's own address under their name;
/// the API never publishes a trainer's contact, so a live course shows this.
const icrEnquiryEmail = 'info@icr.org.in';

String _lowerFirst(String text) =>
    text.length > 1 && text[0] == text[0].toUpperCase() && text[1] == text[1].toLowerCase()
    ? '${text[0].toLowerCase()}${text.substring(1)}'
    : text;

/// The paragraph under "About the Certificate", worded only from what the
/// record holds: who awards it, how it is delivered, that it issues a
/// certificate and the CPD it logs. Null for a course that issues neither.
String? aboutCertificateText({
  CourseProvider? provider,
  int cpdCredits = 0,
  bool certificateEnabled = false,
  String? deliveryMode,
}) {
  if (!certificateEnabled && cpdCredits <= 0) return null;
  final how = deliveryMode == null ? '' : ' as ${_lowerFirst(deliveryMode)}';
  final who = provider == null
      ? 'This programme is delivered and awarded by ICR Institute$how.'
      : 'This programme is delivered through ICR$how and awarded by ${provider.name}'
            '${provider.verified ? ', a partner institute ICR has verified' : ''}.';
  final done = certificateEnabled
      ? ' Upon successful completion, participants receive a certificate recognizing their achievement.'
      : '';
  final cpd = cpdCredits > 0
      ? ' It also logs $cpdCredits CPD credit${cpdCredits == 1 ? '' : 's'} on your ICR profile.'
      : '';
  return '$who$done$cpd';
}

/// Whether a row's meta line says when and how long (a clock beside it), as
/// opposed to what the course is.
bool courseMetaTimed(Course course) =>
    course.durationLabel != null || course.runs.isNotEmpty || course.deliveryMode != null;

/// "4 days · 32 hours • In person", for a list row. A course the API gives no
/// duration or delivery for (a certification programme) says what it is:
/// "Foundation • Certification programme".
String courseMeta(Course course) {
  final mode = course.runs.isNotEmpty
      ? (course.runs.first.mode == DeliveryMode.inPerson ? 'In person' : 'Live virtual')
      : course.deliveryMode;
  final parts = [?course.durationLabel, ?mode];
  if (parts.isNotEmpty) return parts.join(' • ');
  return [?course.level, course.kind == CourseKind.assessment ? 'Certification programme' : 'Course'].join(' • ');
}

/// "CA" for "Certificate in Advanced Leadership Skills": the first letters of the
/// first two words that carry meaning (small joining words skipped), drawn on the
/// plate of a card whose course has no cover. One word gives its first two letters.
String courseInitials(String title) {
  const small = {'a', 'an', 'and', 'for', 'in', 'of', 'on', 'the', 'to', '&', '-', '–'};
  final words = [
    for (final w in title.trim().split(RegExp(r'\s+')))
      if (w.isNotEmpty && !small.contains(w.toLowerCase()) && RegExp(r'^[A-Za-z0-9]').hasMatch(w)) w,
  ];
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    final w = words.first;
    return (w.length > 1 ? w.substring(0, 2) : w).toUpperCase();
  }
  return '${words[0][0]}${words[1][0]}'.toUpperCase();
}

/// "Aug 23 - 27, 2027 • Riyadh, KSA": the run a member holds a place on.
String? enrolmentMeta(MyEnrolment? mine) {
  final start = mine?.startsAt;
  if (mine == null || start == null) return null;
  return [runDates(start, mine.endsAt), ?mine.location].join(' • ');
}

/// The first paragraph of a description that may carry HTML or blank lines.
String plainText(String text) => text
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'</p>\s*<p[^>]*>', caseSensitive: false), '\n\n')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll(RegExp(r'[ \t]+'), ' ')
    .trim();
