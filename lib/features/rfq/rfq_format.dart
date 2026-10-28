/// How the requirements screens word amounts, days and states.
library;

import 'rfq_models.dart';
import 'rfq_rules.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Digits grouped the Indian way: 1,50,000 and 1,00,00,000.
String indianGrouping(int n) {
  final negative = n < 0;
  final s = n.abs().toString();
  if (s.length <= 3) return '${negative ? '-' : ''}$s';
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${negative ? '-' : ''}${parts.join(',')},$last3';
}

/// "₹1,50,000" (paise only when there are any).
String formatInr(double amount) {
  final whole = amount.truncate();
  final paise = ((amount - whole).abs() * 100).round();
  return '₹${indianGrouping(whole)}${paise == 0 ? '' : '.${paise.toString().padLeft(2, '0')}'}';
}

/// "₹1.5 L", "₹2.4 Cr": a figure in a tight slot.
String compactInr(double amount) {
  if (amount >= 1e7) return '₹${_trim(amount / 1e7)} Cr';
  if (amount >= 1e5) return '₹${_trim(amount / 1e5)} L';
  return formatInr(amount);
}

String _trim(double v) {
  final s = v.toStringAsFixed(v >= 100 ? 0 : 1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// "25 Sep", the Indian calendar day of a moment.
String shortDay(DateTime moment) {
  final d = istDayOf(moment);
  return '${d.day} ${_months[d.month - 1]}';
}

/// "25 Sep 2026".
String fullDay(DateTime moment) {
  final d = istDayOf(moment);
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// "25 Sep 2026" for a day picked in a form (no time zone of its own).
String pickedDay(DateTime day) => '${day.day} ${_months[day.month - 1]} ${day.year}';

/// How urgent a deadline is.
enum Urgency { neutral, soon, urgent, past }

/// "Quotes due in 3 days · 25 Sep": the deadline that matters now.
class DeadlineLine {
  const DeadlineLine(this.label, this.relative, this.date, this.urgency);

  final String label;
  final String relative;
  final String date;
  final Urgency urgency;

  @override
  String toString() => '$label $relative';
}

/// Whole Indian calendar days from [now] to [moment]: 0 today, negative once past.
int calendarDaysUntil(DateTime moment, [DateTime? now]) => istDayOf(moment).difference(todayIst(now)).inDays;

/// "today", "tomorrow", "in 3 days", or "closed 2 days ago".
String relativeDay(DateTime moment, [DateTime? now]) {
  final n = now ?? DateTime.now();
  final days = calendarDaysUntil(moment, n);
  if (moment.isBefore(n)) return days == 0 ? 'closed today' : 'closed ${-days} day${days == -1 ? '' : 's'} ago';
  return days == 0 ? 'today' : (days == 1 ? 'tomorrow' : 'in $days days');
}

/// The deadline a requirement is waiting on, worded; null when it has none or is settled.
DeadlineLine? deadlineOf(Requirement r, [DateTime? now]) {
  if (r.status != RfqStatus.published && r.status != RfqStatus.draft) return null;
  final n = now ?? DateTime.now();
  final preQual = r.stage == RfqStage.prequalification ? r.preQualEndDate : null;
  final at = preQual ?? r.dueDate;
  if (at == null) return null;
  final days = calendarDaysUntil(at, n);
  final passed = at.isBefore(n);
  if (passed && r.status == RfqStatus.draft) {
    return DeadlineLine(
      preQual != null ? 'Pre-qual deadline' : 'Deadline',
      'passed, update it',
      shortDay(at),
      Urgency.soon,
    );
  }
  // A deadline in the past already says "closed 8 days ago": "Pre-qual closes closed 8 days ago" read twice.
  final label = passed
      ? (preQual != null ? 'Pre-qual' : (r.kind == RfqKind.rfq ? 'Quotes' : 'Replies'))
      : (preQual != null ? 'Pre-qual closes' : (r.kind == RfqKind.rfq ? 'Quotes due' : 'Replies due'));
  final urgency = passed
      ? Urgency.past
      : days <= 1
      ? Urgency.urgent
      : days <= 7
      ? Urgency.soon
      : Urgency.neutral;
  return DeadlineLine(label, relativeDay(at, n), shortDay(at), urgency);
}

/// "Posted 3d ago", "Posted today".
String postedAgo(DateTime? at, [DateTime? now]) {
  if (at == null) return '';
  final n = now ?? DateTime.now();
  final diff = n.difference(at);
  if (diff.inHours < 1) return 'Posted just now';
  if (diff.inHours < 24) return 'Posted ${diff.inHours}h ago';
  if (diff.inDays < 30) return 'Posted ${diff.inDays}d ago';
  return 'Posted ${shortDay(at)}';
}

/// "2 bids", "1 reply", "3 responses".
String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';

/// What a buyer's row counts: a staged RFQ's bids once there are any, else its
/// pre-qualification responses; anything else its replies or bids.
({int total, String noun, int fresh, String freshNoun}) responsesOf(Requirement r) {
  final c = r.responses ?? ResponseCounts(bids: r.quoteCount);
  final live = r.status == RfqStatus.published;
  if (r.staged && c.bids == 0) {
    return (
      total: c.prequal,
      noun: c.prequal == 1 ? 'response' : 'responses',
      fresh: live ? c.prequalPending : 0,
      freshNoun: 'to screen',
    );
  }
  final enquiry = r.isEnquiry;
  return (
    total: c.bids,
    noun: enquiry ? (c.bids == 1 ? 'reply' : 'replies') : (c.bids == 1 ? 'bid' : 'bids'),
    fresh: live ? c.bidsPending : 0,
    freshNoun: 'new',
  );
}

/// The one thing a buyer's row calls for, as its button reads.
({String label, int? count, String? section}) primaryOf(Requirement r) {
  final c = r.responses ?? ResponseCounts(bids: r.quoteCount);
  if (r.status == RfqStatus.draft) return (label: 'Finish draft', count: null, section: null);
  if (r.status == RfqStatus.awarded) return (label: 'View award', count: null, section: null);
  if (r.status != RfqStatus.published) return (label: 'View', count: null, section: null);
  if (c.prequalPending > 0) return (label: 'Screen', count: c.prequalPending, section: 'prequal');
  if (c.bidsPending > 0) {
    return (label: r.isEnquiry ? 'Review replies' : 'Review bids', count: c.bidsPending, section: null);
  }
  if (!r.staged && c.bids == 0) return (label: 'Invite suppliers', count: null, section: 'invited');
  if (r.staged && c.bids == 0) return (label: 'View responses', count: null, section: null);
  return (label: r.isEnquiry ? 'View replies' : 'View bids', count: null, section: null);
}

/// "ENQUIRY · HOUSEKEEPING": the kind and what it is for.
String kicker(Requirement r, String? serviceLabel) => [
  r.isEnquiry ? 'ENQUIRY' : 'RFQ',
  if (serviceLabel != null && serviceLabel.isNotEmpty) serviceLabel.toUpperCase(),
].join(' · ');

/// A taxonomy key as words, when its name is not known: "PEST_CONTROL" → "Pest control".
String prettyKey(String key) {
  final words = key.toLowerCase().replaceAll(RegExp(r'[_-]+'), ' ').trim();
  return words.isEmpty ? key : '${words[0].toUpperCase()}${words.substring(1)}';
}

/// Rich text as plain lines: tags dropped, the common entities decoded.
String plainText(String html) {
  var s = html
      .replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</\s*(p|div|li|h[1-6])\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  const entities = {'&nbsp;': ' ', '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'", '&rsquo;': '’'};
  entities.forEach((k, v) => s = s.replaceAll(k, v));
  return s.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

/// What an action item asks of the buyer, in one line.
String actionSentence(ActionItem a) {
  final reply = a.rfqKind == RfqKind.enquiry ? 'reply' : 'bid';
  return switch (a.kind) {
    'AWARD' =>
      'Quotes are in: ${plural(a.count, reply, a.rfqKind == RfqKind.enquiry ? 'replies' : null)} waiting for your decision',
    'SCREEN' => '${plural(a.count, 'pre-qualification response')} to screen',
    'BIDS' => '${plural(a.count, 'new $reply', a.rfqKind == RfqKind.enquiry ? 'new replies' : null)} to review',
    _ => 'No replies yet: invite more suppliers',
  };
}

/// "Pan-India", "11-50 employees", "Provident Fund (PF)".
String presenceLabel(Presence p) => p.label;
String sizeLabel(String bucket) => '$bucket employees';
String complianceLabel(String key) => statutoryCompliance[key] ?? prettyKey(key);

/// "site-layout-v2.pdf" becomes "site-layout-v2": a title to start from, at most 120 characters (the API's limit).
String titleFromFileName(String name) {
  final dot = name.lastIndexOf('.');
  final base = dot > 0 ? name.substring(0, dot) : name;
  return base.length > 120 ? base.substring(0, 120) : base;
}

/// The formats a requirement or a bid may carry (`uploads/upload-types.ts`), by extension.
const _mimeByExtension = {
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'csv': 'text/csv',
  'txt': 'text/plain',
  'zip': 'application/zip',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'webp': 'image/webp',
};

/// The extensions an attachment may have.
List<String> get attachmentExtensions => _mimeByExtension.keys.toList();

/// The media type of a file name, or null when it is not one of the accepted formats.
String? mimeTypeFor(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return null;
  return _mimeByExtension[fileName.substring(dot + 1).toLowerCase()];
}
