import 'community_manage_models.dart';

/// The rules the console's forms hold to, copied from the API's DTOs (`association.dto.ts`,
/// `association-requests.dto.ts`) so a form refuses what the API would, in the same places; the About sections and
/// their HTML (the website's `aboutSections.ts`); and the words the website's enums carry.

// --- limits -------------------------------------------------------------------------------------------------------

/// Field limits (`CreateChapterDto`, `CreateCouncilDto`, the content DTOs, `ASSOCIATION_REQUEST_LIMITS.reason`).
class ManageLimits {
  ManageLimits._();

  static const name = 120;
  static const slug = 120;
  static const place = 80;
  static const description = 4000;
  static const imagePath = 500;
  static const aboutHtml = 20000;
  static const minFoundedYear = 1900;
  static const councilFocus = 160;
  static const sponsorName = 120;
  static const tier = 40;
  static const resourceTitle = 160;
  static const sizeLabel = 40;
  static const announcementTitle = 160;
  static const announcementBody = 4000;
  static const leadTitle = 120;
  static const linkedinUrl = 300;
  static const leadSearch = 100;
  static const decisionReason = 1000;

  /// The website's gallery field: up to 8 images, 10 MB each (the uploads endpoint's own cap).
  static const galleryImages = 8;
  static const galleryBytes = 10 * 1024 * 1024;

  /// A chapter's banner and picture: 5 MB (`ChapterImageDialog`).
  static const coverBytes = 5 * 1024 * 1024;
}

/// The staff lists page by 20, as the website's.
const managePageSize = 20;

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

bool validEmail(String v) => _email.hasMatch(v.trim());

// --- the chapter form ----------------------------------------------------------------------------------------------

/// What the chapter sheet holds (the website's `ChapterDialog` fields, with the banner and picture the chapter
/// page's own dialog edits).
class ChapterDraft {
  ChapterDraft({
    this.name = '',
    this.scope = ChapterScope.regional,
    this.city = '',
    this.country = 'India',
    this.region = '',
    this.foundedYear = '',
    this.description = '',
    this.contactEmail = '',
    this.coverUrl = '',
    this.logoUrl = '',
    List<String>? galleryUrls,
    this.published = true,
    Map<String, String>? about,
    this.aboutExtra = '',
  }) : galleryUrls = galleryUrls ?? [],
       about = about ?? {};

  factory ChapterDraft.of(AdminChapter c) {
    final parsed = parseAbout(c.aboutHtml, chapterAboutSections);
    return ChapterDraft(
      name: c.name,
      scope: c.scope,
      city: c.city,
      country: c.country.isEmpty ? 'India' : c.country,
      region: c.region ?? '',
      foundedYear: c.foundedYear?.toString() ?? '',
      description: c.description ?? '',
      contactEmail: c.contactEmail ?? '',
      coverUrl: c.coverUrl ?? '',
      logoUrl: c.logoUrl ?? '',
      galleryUrls: [...c.galleryUrls],
      published: c.published,
      about: parsed.values,
      aboutExtra: parsed.extra,
    );
  }

  String name;
  String scope;
  String city;
  String country;
  String region;
  String foundedYear;
  String description;
  String contactEmail;
  String coverUrl;
  String logoUrl;
  List<String> galleryUrls;
  bool published;

  /// One value per About section, by its key.
  Map<String, String> about;

  /// Stored About content no field covers; kept as it is.
  String aboutExtra;

  bool get countryWide => scope == ChapterScope.country;

  String get aboutHtml => composeAbout(about, chapterAboutSections, aboutExtra);

  /// Each field's problem, by field name; empty when the API would take the form.
  Map<String, String> problems() {
    final p = <String, String>{};
    final n = name.trim();
    if (n.isEmpty) {
      p['name'] = 'Give the chapter a name.';
    } else if (n.length > ManageLimits.name) {
      p['name'] = 'Keep the name within ${ManageLimits.name} characters.';
    }
    if (countryWide) {
      if (country.trim().isEmpty) p['country'] = 'Choose the country this chapter covers.';
    } else if (city.trim().isEmpty) {
      p['city'] = 'Choose the city this regional chapter covers.';
    }
    if (city.trim().length > ManageLimits.place) p['city'] = 'Keep the city within ${ManageLimits.place} characters.';
    if (country.trim().length > ManageLimits.place) {
      p['country'] = 'Keep the country within ${ManageLimits.place} characters.';
    }
    final year = foundedYear.trim();
    if (year.isNotEmpty) {
      final y = int.tryParse(year);
      if (y == null) {
        p['foundedYear'] = 'The founded year must be a whole number.';
      } else if (y < ManageLimits.minFoundedYear) {
        p['foundedYear'] = 'The founded year must be ${ManageLimits.minFoundedYear} or later.';
      }
    }
    if (description.trim().length > ManageLimits.description) {
      p['description'] = 'Keep the description within 4,000 characters.';
    }
    if (contactEmail.trim().isNotEmpty && !validEmail(contactEmail)) {
      p['contactEmail'] = 'Enter a valid email address.';
    }
    if (aboutHtml.length > ManageLimits.aboutHtml) p['about'] = 'The About is too long. Shorten a section.';
    return p;
  }

  /// The body for `POST /chapters` (no [was]) or `PATCH /chapters/:id`, as the website's dialog sends it: no slug
  /// (the API makes the address from the name and never changes it), the About sent even when blank so clearing
  /// every field clears it. On an edit, a field that held a value and is now blank is sent as null so it is cleared.
  Map<String, Object?> body({AdminChapter? was}) {
    final year = int.tryParse(foundedYear.trim());
    final desc = description.trim();
    final email = contactEmail.trim();
    return {
      'name': name.trim(),
      'scope': scope,
      'city': countryWide ? '' : city.trim(),
      'country': country.trim(),
      'region': countryWide || region.trim().isEmpty ? null : region.trim(),
      if (desc.isNotEmpty) 'description': desc else if (was?.description != null) 'description': null,
      if (email.isNotEmpty) 'contactEmail': email else if (was?.contactEmail != null) 'contactEmail': null,
      if (year != null) 'foundedYear': year else if (was?.foundedYear != null) 'foundedYear': null,
      // A picture is sent only when it changed; '' removes it, as the chapter page's own dialog does.
      if (coverUrl != (was?.coverUrl ?? '')) 'coverUrl': coverUrl,
      if (logoUrl != (was?.logoUrl ?? '')) 'logoUrl': logoUrl,
      'galleryUrls': galleryUrls,
      'published': published,
      'aboutHtml': aboutHtml,
    };
  }
}

// --- the council form ----------------------------------------------------------------------------------------------

/// What the council sheet holds (the website's `CouncilDialog` fields, with the cover the API also takes).
class CouncilDraft {
  CouncilDraft({
    this.name = '',
    this.slug = '',
    this.focus = '',
    List<String>? segments,
    this.description = '',
    this.contactEmail = '',
    this.coverUrl = '',
    List<String>? galleryUrls,
    this.published = true,
    Map<String, String>? about,
    this.aboutExtra = '',
  }) : segments = segments ?? [],
       galleryUrls = galleryUrls ?? [],
       about = about ?? {};

  factory CouncilDraft.of(AdminCouncil c) {
    final parsed = parseAbout(c.aboutHtml, councilAboutSections);
    return CouncilDraft(
      name: c.name,
      slug: c.slug,
      focus: c.focus ?? '',
      segments: [...c.segments],
      description: c.description ?? '',
      contactEmail: c.contactEmail ?? '',
      coverUrl: c.coverUrl ?? '',
      galleryUrls: [...c.galleryUrls],
      published: c.published,
      about: parsed.values,
      aboutExtra: parsed.extra,
    );
  }

  String name;
  String slug;
  String focus;
  List<String> segments;
  String description;
  String contactEmail;
  String coverUrl;
  List<String> galleryUrls;
  bool published;
  Map<String, String> about;
  String aboutExtra;

  String get aboutHtml => composeAbout(about, councilAboutSections, aboutExtra);

  Map<String, String> problems() {
    final p = <String, String>{};
    final n = name.trim();
    if (n.isEmpty) {
      p['name'] = 'Give the council a name.';
    } else if (n.length > ManageLimits.name) {
      p['name'] = 'Keep the name within ${ManageLimits.name} characters.';
    }
    if (slug.trim().isEmpty) {
      p['slug'] = 'Give the council a slug: lower-case words joined by hyphens.';
    } else if (slug.trim().length > ManageLimits.slug) {
      p['slug'] = 'Keep the slug within ${ManageLimits.slug} characters.';
    }
    if (_focusSent.length > ManageLimits.councilFocus) {
      p['focus'] = 'Keep the focus line within ${ManageLimits.councilFocus} characters.';
    }
    if (description.trim().length > ManageLimits.description) {
      p['description'] = 'Keep the description within 4,000 characters.';
    }
    if (contactEmail.trim().isNotEmpty && !validEmail(contactEmail)) {
      p['contactEmail'] = 'Enter a valid email address.';
    }
    if (aboutHtml.length > ManageLimits.aboutHtml) p['about'] = 'The About is too long. Shorten a section.';
    return p;
  }

  /// The focus line defaults to the segments, as the website's dialog.
  String get _focusSent => focus.trim().isNotEmpty ? focus.trim() : segments.join(' · ');

  /// The body for `POST /councils` (no [was]) or `PATCH /councils/:id`.
  Map<String, Object?> body({AdminCouncil? was}) {
    final desc = description.trim();
    final email = contactEmail.trim();
    final focusLine = _focusSent;
    return {
      'name': name.trim(),
      'slug': slug.trim(),
      if (focusLine.isNotEmpty) 'focus': focusLine else if (was?.focus != null) 'focus': null,
      'segments': segments,
      if (desc.isNotEmpty) 'description': desc else if (was?.description != null) 'description': null,
      if (email.isNotEmpty) 'contactEmail': email else if (was?.contactEmail != null) 'contactEmail': null,
      if (coverUrl != (was?.coverUrl ?? '')) 'coverUrl': coverUrl,
      'galleryUrls': galleryUrls,
      'published': published,
      'aboutHtml': aboutHtml,
    };
  }
}

/// A name as a slug: lower-case words joined by hyphens, 80 characters at most (the website's `slugify`).
String slugify(String s) {
  final slug = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'(^-|-$)+'), '');
  return slug.length > 80 ? slug.substring(0, 80) : slug;
}

// --- content forms -------------------------------------------------------------------------------------------------

/// `ChapterSponsorDtoIn`: a name (120), an optional logo and website, a tier (40).
String? sponsorProblem({required String name, required String tier}) {
  if (name.trim().isEmpty) return 'Give the sponsor a name.';
  if (name.trim().length > ManageLimits.sponsorName) {
    return 'Keep the name within ${ManageLimits.sponsorName} characters.';
  }
  if (tier.trim().length > ManageLimits.tier) return 'Keep the tier within ${ManageLimits.tier} characters.';
  return null;
}

/// `ChapterResourceDtoIn`: a title (160), a kind, a URL and an optional size label (40).
String? resourceProblem({required String title, required String url, required String sizeLabel}) {
  if (title.trim().isEmpty) return 'Give the resource a title.';
  if (title.trim().length > ManageLimits.resourceTitle) {
    return 'Keep the title within ${ManageLimits.resourceTitle} characters.';
  }
  if (url.trim().isEmpty) return 'Add the resource’s URL.';
  if (sizeLabel.trim().length > ManageLimits.sizeLabel) {
    return 'Keep the size label within ${ManageLimits.sizeLabel} characters.';
  }
  return null;
}

/// `ChapterAnnouncementDtoIn`: a title (160) and a body (4,000).
String? announcementProblem({required String title, required String body}) {
  if (title.trim().isEmpty) return 'Give the update a title.';
  if (title.trim().length > ManageLimits.announcementTitle) {
    return 'Keep the title within ${ManageLimits.announcementTitle} characters.';
  }
  if (body.trim().isEmpty) return 'Write the update.';
  if (body.trim().length > ManageLimits.announcementBody) return 'Keep the update within 4,000 characters.';
  return null;
}

/// A lead's title (120), LinkedIn link (300) and term: the API refuses a term that ends before it starts, in these
/// words (`errors.association.termEndsBeforeStart`).
String? leadProblem({String title = '', String linkedinUrl = '', String? termStartsOn, String? termEndsOn}) {
  if (title.trim().length > ManageLimits.leadTitle) {
    return 'Keep the title within ${ManageLimits.leadTitle} characters.';
  }
  if (linkedinUrl.trim().length > ManageLimits.linkedinUrl) {
    return 'Keep the LinkedIn URL within ${ManageLimits.linkedinUrl} characters.';
  }
  final start = termStartsOn ?? '';
  final end = termEndsOn ?? '';
  if (start.isNotEmpty && end.isNotEmpty && end.compareTo(start) < 0) return 'A term can’t end before it starts.';
  return null;
}

/// Whether a lead's term has run out on [today] (`YYYY-MM-DD`). A term with no end never runs out; one ending
/// today is still in force (`leadTermEnded`).
bool leadTermEnded(String? termEndsOn, String today) {
  if (termEndsOn == null || termEndsOn.isEmpty) return false;
  final day = termEndsOn.length > 10 ? termEndsOn.substring(0, 10) : termEndsOn;
  return day.compareTo(today) < 0;
}

/// A decision: a decline needs its reason (the member reads it); either keeps within 1,000 characters.
String? decisionProblem({required bool declining, required String reason}) {
  if (declining && reason.trim().isEmpty) return 'Say why it isn’t approved. The member reads this.';
  if (reason.trim().length > ManageLimits.decisionReason) return 'Keep it within 1,000 characters.';
  return null;
}

// --- words ---------------------------------------------------------------------------------------------------------

/// `ResourceKind`, in the enum's order, with `RESOURCE_KIND_LABELS`.
const resourceKinds = ['PRESENTATION', 'WHITEPAPER', 'RECORDING', 'TEMPLATE', 'OTHER'];

String resourceKindLabel(String kind) => switch (kind) {
  'PRESENTATION' => 'Presentation',
  'WHITEPAPER' => 'Whitepaper',
  'RECORDING' => 'Recording',
  'TEMPLATE' => 'Template',
  'OTHER' => 'Resource',
  _ => kind,
};

/// `ASSOCIATION_REQUEST_STATUS_LABELS`.
String requestStatusLabel(String status) => switch (status) {
  RequestStatus.pending => 'Waiting for review',
  RequestStatus.approved => 'Approved',
  RequestStatus.declined => 'Declined',
  RequestStatus.withdrawn => 'Withdrawn',
  _ => status,
};

/// The status filter's words: the website calls the pending ones "To review".
String requestFilterLabel(String status) => status == RequestStatus.pending ? 'To review' : requestStatusLabel(status);

/// `CHAPTER_APPLICATION_KIND_LABELS`.
String applicationKindLabel(String kind) => switch (kind) {
  'NEW_CHAPTER' => 'Start a new chapter',
  'LEAD_EXISTING' => 'Lead an existing chapter',
  _ => kind,
};

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "12 Nov 2026", in the phone's own time.
String mediumDate(DateTime t) {
  final d = t.toLocal();
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// A stored day (`YYYY-MM-DD`) as "12 Nov 2026"; the text itself when it is not a day.
String dayLabel(String? day) {
  if (day == null || day.isEmpty) return '';
  final d = DateTime.tryParse(day.length > 10 ? day.substring(0, 10) : day);
  return d == null ? day : '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// A day as the API stores a term's (`YYYY-MM-DD`).
String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// ICR's markets, as ICR names them (`PHONE_COUNTRIES`' first thirteen), by ISO code.
const icrCountries = <String, String>{
  'IN': 'India',
  'AE': 'United Arab Emirates',
  'SA': 'Saudi Arabia',
  'QA': 'Qatar',
  'OM': 'Oman',
  'KW': 'Kuwait',
  'BH': 'Bahrain',
  'SG': 'Singapore',
  'HK': 'Hong Kong',
  'MY': 'Malaysia',
  'AU': 'Australia',
  'US': 'USA',
  'GB': 'UK',
};

/// A place's country as ICR names it ("USA" for the United States), else as the search gave it.
String countryOfPlace(PlaceOption p) => icrCountries[p.countryCode?.toUpperCase()] ?? p.country ?? '';

// --- the About, as fields --------------------------------------------------------------------------------------------

/// One field of a chapter's or council's About: the `<h3>` it is stored under, and whether it holds paragraphs
/// (a blank line starts a new one) or a list (one item per line).
class AboutSection {
  const AboutSection({required this.key, required this.heading, required this.list, required this.helper});

  final String key;
  final String heading;
  final bool list;
  final String helper;
}

const chapterAboutSections = [
  AboutSection(
    key: 'mission',
    heading: 'Mission',
    list: false,
    helper: 'Why the chapter exists, in a sentence or two.',
  ),
  AboutSection(key: 'vision', heading: 'Vision', list: false, helper: 'What it is working towards.'),
  AboutSection(
    key: 'activities',
    heading: 'What we do',
    list: true,
    helper: 'One activity per line, e.g. monthly meetups.',
  ),
  AboutSection(key: 'benefits', heading: 'Membership benefits', list: true, helper: 'One benefit per line.'),
  AboutSection(
    key: 'industries',
    heading: 'Industries served',
    list: false,
    helper: 'The sectors its members work in.',
  ),
];

const councilAboutSections = [
  AboutSection(
    key: 'mission',
    heading: 'Mission',
    list: false,
    helper: 'Why the council exists, in a sentence or two.',
  ),
  AboutSection(key: 'vision', heading: 'Vision', list: false, helper: 'What it is working towards.'),
  AboutSection(key: 'objectives', heading: 'Objectives', list: true, helper: 'One objective per line.'),
  AboutSection(key: 'benefits', heading: 'Member benefits', list: true, helper: 'One benefit per line.'),
  AboutSection(
    key: 'industries',
    heading: 'Industries covered',
    list: false,
    helper: 'The sectors the council covers.',
  ),
];

/// Stored About HTML as one value per field, and whatever the fields do not cover.
class ParsedAbout {
  const ParsedAbout({required this.values, required this.extra});

  final Map<String, String> values;
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
    if (_textOf(m[1] ?? '').isNotEmpty) _textOf(m[1] ?? ''),
];

String _valueOf(String body, AboutSection section) {
  final paragraphs = _contentsOf(body, 'p');
  final items = _contentsOf(body, 'li');
  // Text with neither paragraphs nor a list (a bare line) still counts.
  final loose = paragraphs.isNotEmpty || items.isNotEmpty
      ? const <String>[]
      : [
          if (_textOf(body).isNotEmpty) _textOf(body),
        ];
  return section.list ? [...items, ...paragraphs, ...loose].join('\n') : [...paragraphs, ...items, ...loose].join('\n\n');
}

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

final _h3Start = RegExp(r'<h3\b', caseSensitive: false);
final _h3 = RegExp(r'^<h3\b[^>]*>([\s\S]*?)</h3>', caseSensitive: false);

/// Stored About HTML → one value per field, and anything the fields do not cover (kept as stored and written back
/// after the fields, so editing the form never loses it). The website's `parseAbout`.
ParsedAbout parseAbout(String? html, List<AboutSection> sections) {
  final values = {for (final s in sections) s.key: ''};
  final source = (html ?? '').trim();
  if (source.isEmpty) return ParsedAbout(values: values, extra: '');

  // Cut before every <h3>, so each part is a heading with what follows it (and, first, whatever precedes them all).
  final cuts = [0, for (final m in _h3Start.allMatches(source)) if (m.start > 0) m.start, source.length];
  final extra = <String>[];
  for (var i = 0; i + 1 < cuts.length; i++) {
    final part = source.substring(cuts[i], cuts[i + 1]);
    final heading = _h3.firstMatch(part);
    AboutSection? section;
    if (heading != null) {
      final name = _norm(_textOf(heading[1] ?? ''));
      for (final s in sections) {
        if (_norm(s.heading) == name) {
          section = s;
          break;
        }
      }
    }
    if (heading == null || section == null) {
      if (part.trim().isNotEmpty) extra.add(part.trim());
      continue;
    }
    final value = _valueOf(part.substring(heading[0]!.length), section);
    final had = values[section.key] ?? '';
    values[section.key] = had.isEmpty ? value : '$had\n$value';
  }
  return ParsedAbout(values: values, extra: extra.join('\n'));
}

/// The fields (and any kept extra) → About HTML, or '' when everything is blank. The website's `composeAbout`.
String composeAbout(Map<String, String> values, List<AboutSection> sections, [String extra = '']) {
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
    blocks.add('<h3>${_escape(s.heading)}</h3>\n$body');
  }
  if (extra.trim().isNotEmpty) blocks.add(extra.trim());
  return blocks.join('\n');
}
