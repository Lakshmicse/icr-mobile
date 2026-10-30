import '../../core/config.dart';
import 'messaging_models.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

bool sameDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// "9:05 am".
String clockTime(DateTime at) {
  final local = at.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${local.hour < 12 ? 'am' : 'pm'}';
}

/// "12 Oct", with the year when it is not this one.
String shortDate(DateTime at, {DateTime? now}) {
  final local = at.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  return '${local.day} ${_months[local.month - 1]}${local.year == current.year ? '' : ' ${local.year}'}';
}

/// "Thu, 24 Oct".
String weekdayDate(DateTime at) {
  final local = at.toLocal();
  return '${_weekdays[local.weekday - 1]}, ${local.day} ${_months[local.month - 1]}';
}

/// The inbox's stamp: "10:20 am", "Yesterday", "Mon", "12 Sep" (the website's `useListTime`).
String listTime(DateTime at, {DateTime? now}) {
  final current = now ?? DateTime.now();
  if (sameDay(at, current)) return clockTime(at);
  if (sameDay(at, current.subtract(const Duration(days: 1)))) return 'Yesterday';
  if (current.difference(at) < const Duration(days: 6)) return _weekdays[at.toLocal().weekday - 1];
  return shortDate(at, now: current);
}

/// A thread's day separator: "Today", "Yesterday", "Thu, 24 Oct".
String dayLabel(DateTime at, {DateTime? now}) {
  final current = now ?? DateTime.now();
  if (sameDay(at, current)) return 'Today';
  if (sameDay(at, current.subtract(const Duration(days: 1)))) return 'Yesterday';
  final local = at.toLocal();
  final base = weekdayDate(at);
  return local.year == current.toLocal().year ? base : '$base ${local.year}';
}

const _monthNames = [
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
];
const _weekdayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

/// "10:14 AM": the time a message was sent, as the thread draws it.
String messageTime(DateTime at) {
  final local = at.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  return '$hour:${local.minute.toString().padLeft(2, '0')} ${local.hour < 12 ? 'AM' : 'PM'}';
}

/// The thread's day pill, in the design's lower case: "today, april 16", "yesterday, april 15", then
/// "monday, 14 april" (with the year when it is not this one).
String threadDayLabel(DateTime at, {DateTime? now}) {
  final current = (now ?? DateTime.now()).toLocal();
  final local = at.toLocal();
  final month = _monthNames[local.month - 1];
  if (sameDay(local, current)) return 'today, $month ${local.day}';
  if (sameDay(local, current.subtract(const Duration(days: 1)))) return 'yesterday, $month ${local.day}';
  final base = '${_weekdayNames[local.weekday - 1]}, ${local.day} $month';
  return local.year == current.year ? base : '$base ${local.year}';
}

/// "Tomorrow, 4:00 PM – 4:20 PM IST": when a booked session runs. The app shows every time on the Indian
/// clock's name, as its other screens do.
String meetingWhen(DateTime start, DateTime end, {DateTime? now}) {
  final current = (now ?? DateTime.now()).toLocal();
  final local = start.toLocal();
  final String day;
  if (sameDay(local, current)) {
    day = 'Today';
  } else if (sameDay(local, current.add(const Duration(days: 1)))) {
    day = 'Tomorrow';
  } else {
    day = local.year == current.year ? weekdayDate(local) : '${weekdayDate(local)} ${local.year}';
  }
  return '$day, ${messageTime(local)} – ${messageTime(end)} IST';
}

/// A Google Calendar "add event" page for a session (the app syncs with no calendar of its own).
Uri googleCalendarLink({required String title, required DateTime start, required DateTime end, String? details}) {
  String two(int n) => n.toString().padLeft(2, '0');
  String stamp(DateTime d) {
    final u = d.toUtc();
    return '${u.year.toString().padLeft(4, '0')}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
  }

  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': title,
    'dates': '${stamp(start)}/${stamp(end)}',
    if (details != null && details.trim().isNotEmpty) 'details': details,
  });
}

/// What kind of file this is, for the file card's second line: "DOCX", "PDF".
String fileKind(String? name, [String? mime]) {
  final n = name ?? '';
  final dot = n.lastIndexOf('.');
  if (dot > 0 && dot < n.length - 1 && n.length - dot <= 6) return n.substring(dot + 1).toUpperCase();
  final subtype = (mime ?? '').split('/').last.split('+').first.split(';').first;
  return subtype.isNotEmpty && subtype.length <= 5 ? subtype.toUpperCase() : 'FILE';
}

/// "1.2 MB", "84 KB".
String fileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  final mb = bytes / (1024 * 1024);
  return '${mb < 10 ? mb.toStringAsFixed(1) : mb.round()} MB';
}

/// Rupees with Indian grouping: "₹12,50,000".
String rupees(num amount) {
  final whole = amount.round().abs().toString();
  String grouped;
  if (whole.length <= 3) {
    grouped = whole;
  } else {
    final last = whole.substring(whole.length - 3);
    var rest = whole.substring(0, whole.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    grouped = '${parts.join(',')},$last';
  }
  return '${amount < 0 ? '-' : ''}₹$grouped';
}

/// How a conversation is named and drawn (the website's `conversationDisplay`).
///
/// Business threads are named for the company on the other side; a
/// mentorship, a consultation or a direct thread for the person; a room for
/// what it is.
class ConversationDisplay {
  const ConversationDisplay({required this.name, required this.avatar, this.company, this.person, this.secondary});

  final String name;
  final AvatarKind avatar;
  final ChatCompany? company;
  final ChatPerson? person;

  /// The person speaking for the company, when the title is the company.
  final String? secondary;
}

enum AvatarKind { company, person, group }

ConversationDisplay conversationDisplay({
  required List<ChatPerson> participants,
  required String? meId,
  String? title,
  ConversationKind? kind,
  ChatCompany? counterpartCompany,
  String? contextLabel,
  String fallback = 'Conversation',
}) {
  final others = participants.where((p) => p.id != meId).toList();
  final person = others.length == 1 ? others.first : null;
  final k = kind ?? (title == null || title.isEmpty ? ConversationKind.direct : null);
  final company = counterpartCompany;

  if (k == ConversationKind.groupSession || (person == null && others.length > 1 && company == null)) {
    final names = others.map((p) => p.fullName).join(', ');
    return ConversationDisplay(name: _first([contextLabel, title, names]) ?? fallback, avatar: AvatarKind.group);
  }
  final business = k == ConversationKind.company || (k?.isRequirement ?? false);
  if (business && company != null) {
    return ConversationDisplay(
      name: company.name,
      avatar: AvatarKind.company,
      company: company,
      person: person,
      secondary: person?.fullName,
    );
  }
  if (person != null) {
    return ConversationDisplay(name: person.fullName, avatar: AvatarKind.person, person: person, company: company);
  }
  if (company != null) return ConversationDisplay(name: company.name, avatar: AvatarKind.company, company: company);
  return ConversationDisplay(name: _first([title]) ?? fallback, avatar: AvatarKind.group);
}

String? _first(List<String?> values) {
  for (final v in values) {
    if (v != null && v.trim().isNotEmpty) return v;
  }
  return null;
}

/// The line beside the kind badge: the requirement or consultation it is
/// about, the inbox topic, else who speaks for the company (`ConversationItem`).
String? conversationAbout(Conversation c, ConversationDisplay display) {
  final kind = c.kind;
  String? inboxTopic;
  if (c.asCompanyId != null) {
    for (final p in c.parties) {
      if (p.companyId == c.asCompanyId) inboxTopic = p.topic;
    }
  }
  if (inboxTopic != null && !(kind?.isRequirement ?? false)) return messageTopicLabels[inboxTopic] ?? inboxTopic;
  if (kind != null && kind.isRequirement) return c.contextLabel ?? c.rfqTitle;
  if (kind == ConversationKind.consultation) return c.contextLabel;
  // A thread about a job names it ("Senior Facilities Manager · Global Infra"); one between people names their company.
  if (kind == ConversationKind.direct) return c.counterpartCompany?.name ?? c.title;
  return display.secondary;
}

// --- shared records --------------------------------------------------------

/// Where a link counts as an ICR record rather than a link elsewhere.
List<String> recordOrigins([String? siteUrl]) =>
    {Uri.parse(siteUrl ?? AppConfig.siteUrl).origin, 'https://icr.org.in', 'https://www.icr.org.in'}.toList();

final _recordPaths = <(RecordType, RegExp)>[
  (RecordType.job, RegExp(r'^/jobs/([A-Za-z0-9_-]+)/?$')),
  (RecordType.requirement, RegExp(r'^/rfq/([A-Za-z0-9_-]+)/?$')),
  (RecordType.company, RegExp(r'^/companies/([A-Za-z0-9_-]+)/?$')),
  (RecordType.product, RegExp(r'^/products/([A-Za-z0-9_-]+)/?$')),
  (RecordType.mentor, RegExp(r'^/mentorship/mentors/([A-Za-z0-9_-]+)/?$')),
  (RecordType.event, RegExp(r'^/events/([A-Za-z0-9_-]+)/?$')),
];

/// Most records one message may carry.
const maxSharedRecords = 3;

/// The record a link points at, when it is one of ICR's own pages.
RecordRef? parseRecordLink(String raw, List<String> origins) {
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
  if (!origins.contains(uri.origin)) return null;
  if (uri.hasQuery || uri.hasFragment) return null;
  for (final (type, re) in _recordPaths) {
    final m = re.firstMatch(uri.path);
    if (m != null) return RecordRef(type, Uri.decodeComponent(m.group(1)!));
  }
  return null;
}

final _urlPattern = RegExp(r'''https?://[^\s<>"']+''');

/// A message body split into the words someone wrote and the records it
/// shares: a line that is only a record's link becomes a card and leaves the
/// text; a record linked mid-sentence stays a link and gets its card too.
({String text, List<RecordRef> records}) splitRecordLinks(String body, List<String> origins) {
  final records = <RecordRef>[];
  void add(RecordRef ref) {
    if (!records.contains(ref)) records.add(ref);
  }

  final kept = <String>[];
  for (final line in body.split('\n')) {
    final trimmed = line.trim();
    final whole = trimmed.isNotEmpty && !trimmed.contains(RegExp(r'\s')) ? parseRecordLink(trimmed, origins) : null;
    if (whole != null) {
      add(whole);
      continue;
    }
    for (final m in _urlPattern.allMatches(line)) {
      final ref = parseRecordLink(m.group(0)!.replaceFirst(RegExp(r'[.,;:!?)\]]+$'), ''), origins);
      if (ref != null) add(ref);
    }
    kept.add(line);
  }
  final text = kept.join('\n').replaceFirst(RegExp(r'\n+$'), '').replaceFirst(RegExp(r'^\n+'), '');
  return (text: text, records: records);
}

/// The links in a piece of text, for tapping.
Iterable<RegExpMatch> linksIn(String text) => _urlPattern.allMatches(text);

/// A row's preview of its last message (`ConversationItem`).
String messagePreview(ChatMessage? last, {required String? meId, String? asCompanyId}) {
  if (last == null) return 'No messages yet';
  if (last.deleted) return 'Message deleted';
  final shared = splitRecordLinks(last.body, recordOrigins());
  final records = shared.records.length;
  final preview = shared.text.trim().isNotEmpty
      ? shared.text.trim().replaceAll(RegExp(r'\s+'), ' ')
      : records > 0
      ? (records == 1 ? 'Shared a record' : 'Shared $records records')
      : (last.attachmentName ?? 'Attachment');
  if (!last.fromMySide(meId, asCompanyId)) return preview;
  if (last.senderId == meId || last.sender == null) return 'You: $preview';
  return '${last.sender!.firstName}: $preview';
}
