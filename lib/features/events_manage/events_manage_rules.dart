/// The rules the staff Events console's forms hold to, copied from the API's DTOs so the app refuses what the
/// API would (`CreateEventDto`, `CreatePackageDto`, `InviteMembersDto`, `ReviewProposalDto`, `ReviewEventHostDto`,
/// `RecordTicketRefundDto`), plus the description's fields (the website's `aboutSections.ts`) and the clock.
library;

import '../events/event_format.dart' show clock, groupThousands, ist, priceLabel;
import 'events_manage_models.dart';

// --- limits (the DTOs' numbers) --------------------------------------------------------------------------------------

const eventTitleMax = 160;
const eventSlugMax = 160;
const eventDescriptionMax = 8000;
const eventLocationMax = 240;

/// ₹10,00,000, in paise (`@Max(100_000_000)`).
const eventPriceMaxPaisa = 100000000;

const packageNameMax = 120;

/// ₹1,00,00,000, in paise (`@Max(1_000_000_000)`).
const packagePriceMaxPaisa = 1000000000;
const packageBenefitsMax = 20;
const packageBenefitMax = 200;
const packageSlotsMax = 1000;

/// A note to a speaker or a sponsor.
const decisionNoteMax = 2000;

/// A note to a company asking to host.
const hostNoteMax = 1000;
const refundRefMin = 3;
const refundRefMax = 120;
const inviteEmailsMax = 500;
const attendanceMax = 2000;

// --- the clock -------------------------------------------------------------------------------------------------------

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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
const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// The moment a day and a time on the Indian clock stand for. Every clock on the app's Events screens is the
/// Indian one (`ist` in `event_format.dart`), so the form writes what those screens will read back.
DateTime istWallToUtc(int year, int month, int day, int hour, int minute) =>
    DateTime.utc(year, month, day, hour, minute).subtract(const Duration(hours: 5, minutes: 30));

/// "12 Nov 2026".
String dayLabel(DateTime at) {
  final t = ist(at);
  return '${t.day} ${_months[t.month - 1]} ${t.year}';
}

/// "Thursday, 12 November 2026".
String longDayLabel(DateTime at) {
  final t = ist(at);
  return '${_weekdays[t.weekday - 1]}, ${t.day} ${_monthsLong[t.month - 1]} ${t.year}';
}

/// "12 Nov 2026, 4:00 PM IST" — what a date-and-time field shows.
String dayTimeLabel(DateTime at) => '${dayLabel(at)}, ${clock(at)} IST';

/// "4:00 PM – 6:00 PM IST".
String timeRangeLabel(ManagedEvent e) =>
    e.endsAt == null ? '${clock(e.startsAt)} IST' : '${clock(e.startsAt)} – ${clock(e.endsAt!)} IST';

/// "₹1,500", whole rupees (the Programme's `rupees`).
String rupeesLabel(int paisa) => '₹${groupThousands((paisa / 100).round())}';

/// "₹1,500" or "₹1,499.50" (the Tickets list and the approval notice).
String moneyLabel(int paisa) => priceLabel(paisa);

/// "Free" or the ticket's price.
String eventPriceLabel(ManagedEvent e) => e.priced ? moneyLabel(e.pricePaisa) : 'Free';

/// One status per event: hidden, ended, or live.
enum EventStanding { hidden, ended, published }

EventStanding standingOf(ManagedEvent e, DateTime now) =>
    !e.published ? EventStanding.hidden : (e.hasEnded(now) ? EventStanding.ended : EventStanding.published);

String standingLabel(EventStanding s) => switch (s) {
  EventStanding.hidden => 'Hidden',
  EventStanding.ended => 'Ended',
  EventStanding.published => 'Published',
};

/// "12 going of 50 seats · 3 on the waitlist".
String attendanceLine(ManagedEvent e) =>
    '${e.going} going${e.capacity != null ? ' of ${e.capacity} seats' : ' · no seat limit'}'
    '${e.waitlisted > 0 ? ' · ${e.waitlisted} on the waitlist' : ''}';

// --- the event's address ---------------------------------------------------------------------------------------------

/// The website's `slugify`: lower case, anything else a dash, 80 characters at most.
String slugify(String s) {
  final slug = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'(^-|-$)+'), '');
  return slug.length > 80 ? slug.substring(0, 80) : slug;
}

// --- the description as fields (the website's aboutSections.ts) ------------------------------------------------------

class AboutSection {
  const AboutSection({
    required this.key,
    required this.heading,
    required this.list,
    required this.helper,
    this.lead = false,
  });

  final String key;

  /// The `<h3>` it is stored under, as the public page shows it.
  final String heading;

  /// A list takes one item per line; text takes paragraphs, a blank line between them.
  final bool list;
  final String helper;

  /// Stored with no heading, ahead of the others: the intro a card's preview reads first.
  final bool lead;
}

/// An event's description (owner's call, 6 Nov 2026: fields, not HTML). Speakers live in the Programme.
const eventDescriptionSections = [
  AboutSection(
    key: 'overview',
    heading: 'Overview',
    list: false,
    lead: true,
    helper: 'What the event is, in a short paragraph or two. Cards show its first lines.',
  ),
  AboutSection(
    key: 'agenda',
    heading: 'Agenda',
    list: true,
    helper: 'One item per line, e.g. 10:00 — Registration and coffee.',
  ),
  AboutSection(
    key: 'audience',
    heading: 'Who should attend',
    list: true,
    helper: 'One group per line, e.g. Facility managers.',
  ),
  AboutSection(key: 'takeaways', heading: 'What you will take away', list: true, helper: 'One takeaway per line.'),
  AboutSection(
    key: 'goodToKnow',
    heading: 'Good to know',
    list: false,
    helper: 'Parking, dress code, what to bring, how to reach the venue.',
  ),
];

class ParsedAbout {
  const ParsedAbout(this.values, this.extra);

  final Map<String, String> values;

  /// Whatever the fields do not cover, kept as stored and written back after them.
  final String extra;
}

String _decode(String s) => s
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll(RegExp(r'&#0?39;|&apos;'), "'")
    .replaceAll('&amp;', '&');

String _escape(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

/// An element's text: its tags dropped, entities decoded, whitespace tidied.
String _textOf(String html) => _decode(
  html.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n').replaceAll(RegExp(r'<[^>]+>'), ''),
).split('\n').map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim()).join('\n').trim();

List<String> _contentsOf(String html, String tag) => [
  for (final m in RegExp('<$tag\\b[^>]*>([\\s\\S]*?)</$tag>', caseSensitive: false).allMatches(html))
    if (_textOf(m.group(1)!).isNotEmpty) _textOf(m.group(1)!),
];

String _valueOf(String body, AboutSection section) {
  final paragraphs = _contentsOf(body, 'p');
  final items = _contentsOf(body, 'li');
  final loose = paragraphs.isNotEmpty || items.isNotEmpty
      ? const <String>[]
      : [_textOf(body)].where((t) => t.isNotEmpty).toList();
  return section.list
      ? [...items, ...paragraphs, ...loose].join('\n')
      : [...paragraphs, ...items, ...loose].join('\n\n');
}

bool _isPlainBlock(String html) => RegExp(
  r'</?([a-z0-9]+)\b',
  caseSensitive: false,
).allMatches(html).every((m) => const ['p', 'br', 'ul', 'ol', 'li'].contains(m.group(1)!.toLowerCase()));

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

/// Stored description HTML → one value per field, and anything the fields do not cover.
ParsedAbout parseAbout(String? html, [List<AboutSection> sections = eventDescriptionSections]) {
  final values = {for (final s in sections) s.key: ''};
  final source = (html ?? '').trim();
  if (source.isEmpty) return ParsedAbout(values, '');

  final lead = sections.where((s) => s.lead).firstOrNull;
  final parts = source.split(RegExp(r'(?=<h3\b)', caseSensitive: false));
  final extra = <String>[];
  for (final (index, part) in parts.indexed) {
    final heading = RegExp(r'^<h3\b[^>]*>([\s\S]*?)</h3>', caseSensitive: false).firstMatch(part);
    // The intro before any heading is the lead's, when it is only text, paragraphs and lists.
    if (heading == null && index == 0 && lead != null && _isPlainBlock(part)) {
      final value = _valueOf(part, lead);
      if (value.isNotEmpty) values[lead.key] = value;
      continue;
    }
    final section = heading == null
        ? null
        : sections.where((s) => _norm(s.heading) == _norm(_textOf(heading.group(1)!))).firstOrNull;
    if (heading == null || section == null) {
      if (part.trim().isNotEmpty) extra.add(part.trim());
      continue;
    }
    final value = _valueOf(part.substring(heading.group(0)!.length), section);
    final had = values[section.key] ?? '';
    values[section.key] = had.isEmpty ? value : '$had\n$value';
  }
  return ParsedAbout(values, extra.join('\n'));
}

/// The fields (and any kept extra) → description HTML, or '' when everything is blank.
String composeAbout(
  Map<String, String> values, {
  List<AboutSection> sections = eventDescriptionSections,
  String extra = '',
}) {
  final blocks = <String>[];
  for (final s in sections) {
    final raw = (values[s.key] ?? '').trim();
    if (raw.isEmpty) continue;
    final String body;
    if (s.list) {
      final items = raw
          .split('\n')
          .map((l) => l.replaceFirst(RegExp(r'^[\s•*-]+'), '').trim())
          .where((l) => l.isNotEmpty);
      body = '<ul>\n${items.map((i) => '<li>${_escape(i)}</li>').join('\n')}\n</ul>';
    } else {
      body = raw
          .split(RegExp(r'\n\s*\n'))
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .map((p) => '<p>${_escape(p).replaceAll('\n', '<br>')}</p>')
          .join('\n');
    }
    // The lead goes first with no heading, whatever its place in the list.
    if (s.lead) {
      blocks.insert(0, body);
    } else {
      blocks.add('<h3>${_escape(s.heading)}</h3>\n$body');
    }
  }
  if (extra.trim().isNotEmpty) blocks.add(extra.trim());
  return blocks.join('\n');
}

// --- the event form --------------------------------------------------------------------------------------------------

/// What the event sheet holds while it is filled in (the website's `EventDialog` values).
class EventDraft {
  EventDraft({
    this.title = '',
    this.slug = '',
    this.kind = 'CHAPTER_MEET',
    this.capacity = '',
    this.price = '',
    this.chapterId = '',
    this.councilId = '',
    this.location = '',
    this.startsAt,
    this.endsAt,
    Map<String, String>? about,
    this.extra = '',
    this.published = true,
    this.inviteOnly = false,
    this.callForSpeakersUntil,
  }) : about = about ?? {for (final s in eventDescriptionSections) s.key: ''};

  factory EventDraft.of(ManagedEvent? e) {
    if (e == null) return EventDraft();
    final parsed = parseAbout(e.description);
    final rupees = e.pricePaisa / 100;
    return EventDraft(
      title: e.title,
      slug: e.slug ?? '',
      kind: e.kind,
      capacity: e.capacity?.toString() ?? '',
      price: e.pricePaisa > 0 ? (rupees == rupees.roundToDouble() ? rupees.toInt().toString() : '$rupees') : '',
      chapterId: e.chapter?.id ?? '',
      councilId: e.council?.id ?? '',
      location: e.location ?? '',
      startsAt: e.startsAt,
      endsAt: e.endsAt,
      about: parsed.values,
      extra: parsed.extra,
      published: e.published,
      inviteOnly: e.inviteOnly,
      callForSpeakersUntil: e.callForSpeakersUntil,
    );
  }

  String title;
  String slug;
  String kind;

  /// As typed; blank is unlimited.
  String capacity;

  /// Rupees as typed; blank is free.
  String price;
  String chapterId;
  String councilId;
  String location;
  DateTime? startsAt;
  DateTime? endsAt;
  Map<String, String> about;
  String extra;
  bool published;
  bool inviteOnly;
  DateTime? callForSpeakersUntil;

  String get description => composeAbout(about, extra: extra);

  int? get capacityValue => int.tryParse(capacity.trim());
  int? get pricePaisa {
    final typed = num.tryParse(price.trim());
    return typed == null ? null : (typed * 100).round();
  }

  /// What the API would refuse, by field, before it is asked.
  Map<String, String> problems() {
    final out = <String, String>{};
    final t = title.trim();
    if (t.isEmpty) {
      out['title'] = 'Enter the event’s title.';
    } else if (t.length > eventTitleMax) {
      out['title'] = 'The title can be $eventTitleMax characters at most.';
    }
    if (slug.length > eventSlugMax) out['slug'] = 'The slug can be $eventSlugMax characters at most.';
    if (capacity.trim().isNotEmpty) {
      final n = capacityValue;
      if (n == null || n < 1) out['capacity'] = 'Enter a whole number, 1 or more. Leave it blank for unlimited.';
    }
    if (price.trim().isNotEmpty) {
      final p = pricePaisa;
      if (p == null || p < 0) {
        out['price'] = 'Enter the price in rupees. Leave it blank for a free event.';
      } else if (p > eventPriceMaxPaisa) {
        out['price'] = 'A ticket can cost ${moneyLabel(eventPriceMaxPaisa)} at most.';
      }
    }
    if (location.trim().length > eventLocationMax) {
      out['location'] = 'The location can be $eventLocationMax characters at most.';
    }
    if (startsAt == null) {
      out['startsAt'] = 'Select when the event starts.';
    } else if (endsAt != null && !endsAt!.isAfter(startsAt!)) {
      out['endsAt'] = 'The end must be after the start.';
    }
    if (description.length > eventDescriptionMax) {
      out['description'] =
          'The description is too long: ${groupThousands(eventDescriptionMax)} characters at most, its headings '
          'included.';
    }
    return out;
  }

  /// The body of `POST /events` or `PATCH /events/:id`. A field cleared while editing is sent as null — the API
  /// stores null for it — where the website leaves it out and so cannot clear a capacity, a venue, an end time or
  /// the host chapter once set.
  Map<String, Object?> toJson({required bool create}) {
    final body = <String, Object?>{
      'title': title.trim(),
      if (slug.isNotEmpty) 'slug': slug,
      'kind': kind,
      // Sent even when blank, so clearing every field clears the description.
      'description': description,
      'priceAmount': price.trim().isEmpty ? null : pricePaisa,
      'startsAt': startsAt!.toUtc().toIso8601String(),
      'published': published,
      'inviteOnly': inviteOnly,
      // Blank closes the call; the API stores null.
      'callForSpeakersUntil': callForSpeakersUntil?.toUtc().toIso8601String(),
    };
    void optional(String key, Object? value) {
      if (value != null) {
        body[key] = value;
      } else if (!create) {
        body[key] = null;
      }
    }

    optional('location', location.trim().isEmpty ? null : location.trim());
    optional('chapterId', chapterId.isEmpty ? null : chapterId);
    optional('councilId', councilId.isEmpty ? null : councilId);
    optional('capacity', capacity.trim().isEmpty ? null : capacityValue);
    optional('endsAt', endsAt?.toUtc().toIso8601String());
    return body;
  }
}

// --- a sponsorship package -------------------------------------------------------------------------------------------

/// The package sheet's fields; `problems` holds them to `CreatePackageDto`.
class PackageDraft {
  PackageDraft({this.name = '', this.price = '', this.slots = '', this.benefits = ''});

  factory PackageDraft.of(SponsorPackage? p) {
    if (p == null) return PackageDraft();
    final rupees = p.pricePaisa / 100;
    return PackageDraft(
      name: p.name,
      price: rupees == rupees.roundToDouble() ? rupees.toInt().toString() : '$rupees',
      slots: p.slots?.toString() ?? '',
      benefits: p.benefits.join('\n'),
    );
  }

  String name;

  /// Rupees as typed.
  String price;

  /// Blank: no cap.
  String slots;

  /// One per line.
  String benefits;

  List<String> get benefitList => benefits.split('\n').map((b) => b.trim()).where((b) => b.isNotEmpty).toList();
  int? get pricePaisa {
    final typed = num.tryParse(price.trim());
    return typed == null ? null : (typed * 100).round();
  }

  Map<String, String> problems() {
    final out = <String, String>{};
    final n = name.trim();
    if (n.isEmpty) {
      out['name'] = 'Enter the package’s name.';
    } else if (n.length > packageNameMax) {
      out['name'] = 'The name can be $packageNameMax characters at most.';
    }
    final p = pricePaisa;
    if (price.trim().isEmpty || p == null || p < 0) {
      out['price'] = 'Enter the price in rupees (0 for a package that costs nothing).';
    } else if (p > packagePriceMaxPaisa) {
      out['price'] = 'A package can cost ${rupeesLabel(packagePriceMaxPaisa)} at most.';
    }
    if (slots.trim().isNotEmpty) {
      final s = int.tryParse(slots.trim());
      if (s == null || s < 1 || s > packageSlotsMax) {
        out['slots'] =
            'Enter a whole number from 1 to ${groupThousands(packageSlotsMax)}, or leave it blank for no cap.';
      }
    }
    final list = benefitList;
    if (list.length > packageBenefitsMax) {
      out['benefits'] = 'A package can list $packageBenefitsMax benefits at most.';
    } else if (list.any((b) => b.length > packageBenefitMax)) {
      out['benefits'] = 'Each benefit can be $packageBenefitMax characters at most.';
    }
    return out;
  }

  Map<String, Object?> toJson() => {
    'name': name.trim(),
    'priceAmount': pricePaisa,
    'benefits': benefitList,
    'slots': slots.trim().isEmpty ? null : int.parse(slots.trim()),
  };
}

// --- invitations -----------------------------------------------------------------------------------------------------

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// The addresses typed into "Invite by email": split on spaces, commas and semicolons, as the website does.
List<String> splitEmails(String text) =>
    text.split(RegExp(r'[\s,;]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

/// Why the typed addresses cannot be sent, or null: the API takes 500 at a time and each must be an email.
String? inviteEmailsProblem(List<String> emails) {
  if (emails.isEmpty) return 'Enter at least one email address.';
  if (emails.length > inviteEmailsMax) return 'Invite $inviteEmailsMax people at most at a time.';
  final bad = emails.where((e) => !_email.hasMatch(e)).toList();
  if (bad.isNotEmpty) {
    return bad.length == 1
        ? '${bad.first} is not an email address.'
        : 'These are not email addresses: ${bad.join(', ')}.';
  }
  return null;
}

/// "2 invited · not members: a@x.com" — the website's sentence after an invite by email.
String inviteResultLine(InviteResult r) =>
    '${r.invited} invited${r.unknown.isNotEmpty ? ' · not members: ${r.unknown.join(', ')}' : ''}';

/// "3 new invites from 40 members on Gold or above." — after a tier sweep.
String tierResultLine(TierInviteResult r, String tier) =>
    '${r.invited} new ${r.invited == 1 ? 'invite' : 'invites'} from ${r.considered} members on ${tierLabel(tier)} or '
    'above.';

// --- refunds ---------------------------------------------------------------------------------------------------------

/// A refund reference may be left empty (above the limit the approver adds it); once typed it is 3 to 120
/// characters (`RecordTicketRefundDto`).
String? refundRefProblem(String ref) {
  final r = ref.trim();
  if (r.isEmpty) return null;
  if (r.length < refundRefMin) return 'A reference has at least $refundRefMin characters.';
  if (r.length > refundRefMax) return 'A reference can be $refundRefMax characters at most.';
  return null;
}

/// The website's `ApprovalSentNotice` (`common.ApprovalSent`).
const approvalSentTitle = 'Sent for approval';
String approvalSentBody(int amountPaisa) =>
    '${moneyLabel(amountPaisa)} is more than one person may move alone, so someone else who approves finance actions '
    'must approve it. Nothing has been recorded yet.';
const approvalReferenceHelp =
    'Above the approval limit you may leave this empty: the approver adds it once the money is sent.';

// --- attendance ------------------------------------------------------------------------------------------------------

/// "3 marked present · 2 CPD hours each."
String attendanceResultLine(AttendanceResult r, int asked) {
  final hours = r.hoursEach;
  final h = hours == null ? '' : (hours == hours.roundToDouble() ? hours.toInt().toString() : hours.toString());
  final credited = r.marked > 0 && hours != null ? ' · $h CPD ${hours == 1 ? 'hour' : 'hours'} each' : '';
  final skipped = asked - r.marked;
  final rest = skipped > 0
      ? ' $skipped had no place at this event, so ${skipped == 1 ? 'was' : 'were'} not marked.'
      : '';
  return '${r.marked} marked present$credited.$rest';
}
