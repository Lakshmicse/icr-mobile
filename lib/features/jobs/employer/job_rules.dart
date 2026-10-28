/// What a job posting may hold and what it needs before it goes live: a port of
/// `packages/shared/src/job-rules.ts` (`JOB_LIMITS`, `jobPublishBlockers`) and
/// `job-openings.ts`, which the API runs on every move to OPEN or IN_REVIEW, so the
/// composer's checklist and the API's refusal are the same sentences.
library;

/// The limits (`JOB_LIMITS`).
class JobLimits {
  JobLimits._();

  static const titleMin = 3;
  static const titleMax = 120;
  static const descriptionMin = 120;
  static const descriptionMax = 20000;
  static const descriptionHtmlMax = 60000;
  static const skillMax = 60;
  static const cityMax = 60;
  static const openingsMin = 1;
  static const openingsMax = 999;
  static const salaryMax = 999999999;
  static const screeningPromptMin = 3;
  static const screeningPromptMax = 300;
  static const screeningOptionMax = 100;
  static const screeningOptionsMax = 10;
  static const interviewNotesMax = 2000;

  /// `MAX_JOB_CITIES`, `MAX_JOB_SKILLS`, `MAX_SCREENING_QUESTIONS`.
  static const citiesMax = 10;
  static const skillsMax = 30;
  static const screeningQuestionsMax = 10;
  static const experienceMax = 60;
}

/// The countries a role may be based in (`COUNTRIES`).
const jobCountries = [
  'India',
  'United Arab Emirates',
  'Saudi Arabia',
  'Qatar',
  'Oman',
  'Kuwait',
  'Bahrain',
  'Singapore',
  'Hong Kong',
  'Malaysia',
  'Australia',
  'USA',
  'UK',
];

/// The currencies a salary may be quoted in (`JOB_SALARY_CURRENCIES`).
const jobCurrencies = ['INR', 'USD', 'AED', 'GBP', 'EUR'];

/// Rich HTML as the plain text a reader sees, for counting (`htmlToPlainText`).
String htmlToPlainText(String? html) => (html ?? '')
    .replaceAll(RegExp(r'<[^>]*>'), ' ')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// An http(s) link a candidate can be sent to (`isApplyUrl`).
bool isApplyUrl(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return false;
  final u = Uri.tryParse(v);
  return u != null && u.hasAuthority && (u.scheme == 'https' || u.scheme == 'http') && u.host.contains('.');
}

/// One thing standing between a posting and going live.
class JobBlocker {
  const JobBlocker(this.key, this.message, {this.cityIndex});

  /// title, description, skills, country, salaryOrder, experienceOrder, cityOpenings, applyUrl or openings.
  final String key;
  final String message;

  /// For `cityOpenings`: the index in the cities of the first one missing its count.
  final int? cityIndex;
}

/// The facts the rules read: a composer's values.
class JobFacts {
  const JobFacts({
    this.title = '',
    this.description = '',
    this.skills = const [],
    this.preferredSkills = const [],
    this.country,
    this.salaryMin,
    this.salaryMax,
    this.experienceMin,
    this.experienceMax,
    this.cities = const [],
    this.cityOpenings = const {},
    this.externalApply = false,
    this.applyUrl,
    this.openings,
  });

  final String title;

  /// The description as rich text (HTML) or plain: tags do not count.
  final String description;
  final List<String> skills;
  final List<String> preferredSkills;
  final String? country;
  final num? salaryMin;
  final num? salaryMax;
  final num? experienceMin;
  final num? experienceMax;
  final List<String> cities;

  /// City (as listed) to its seats.
  final Map<String, int> cityOpenings;
  final bool externalApply;
  final String? applyUrl;
  final num? openings;
}

String _grouped(int n) {
  final s = n.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

/// The first city of [cities] with no seat count, once there are two or more (`firstCityMissingOpenings`); -1 when none.
int firstCityMissingOpenings(List<String> cities, Map<String, int> openings) {
  final list = [
    for (final c in cities)
      if (c.trim().isNotEmpty) c.trim(),
  ];
  if (list.length < 2) return -1;
  final have = {for (final e in openings.entries) e.key.trim().toLowerCase(): e.value};
  for (final (i, c) in list.indexed) {
    final n = have[c.toLowerCase()];
    if (n == null || n < 1) return i;
  }
  return -1;
}

/// Everything between a posting and going live, in the order the composer shows it. Empty means it may
/// publish (`jobPublishBlockers`).
List<JobBlocker> jobPublishBlockers(JobFacts job) {
  final out = <JobBlocker>[];
  if (job.title.trim().length < JobLimits.titleMin) {
    out.add(
      const JobBlocker('title', 'Give the role a clear, specific title (at least ${JobLimits.titleMin} characters).'),
    );
  }
  final descLen = htmlToPlainText(job.description).length;
  if (descLen < JobLimits.descriptionMin) {
    out.add(const JobBlocker('description', 'Write a description of at least ${JobLimits.descriptionMin} characters.'));
  } else if (descLen > JobLimits.descriptionMax) {
    out.add(JobBlocker('description', 'Keep the description under ${_grouped(JobLimits.descriptionMax)} characters.'));
  }
  if (!job.skills.any((s) => s.trim().isNotEmpty)) {
    out.add(const JobBlocker('skills', 'Add at least one required skill so the right candidates find this role.'));
  }
  for (final s in [...job.skills, ...job.preferredSkills]) {
    if (s.trim().length > JobLimits.skillMax) {
      final shown = s.trim().substring(0, 24);
      out.add(JobBlocker('skills', 'Shorten the skill “$shown…” to ${JobLimits.skillMax} characters or fewer.'));
      break;
    }
  }
  if (job.country == null || !jobCountries.contains(job.country)) {
    out.add(const JobBlocker('country', 'Pick the country this role is based in.'));
  }
  final sMin = job.salaryMin;
  final sMax = job.salaryMax;
  if (sMin != null && sMax != null && sMin > 0 && sMax > 0 && sMin > sMax) {
    out.add(const JobBlocker('salaryOrder', 'Maximum salary must be at least the minimum.'));
  }
  final eMin = job.experienceMin;
  final eMax = job.experienceMax;
  if (eMin != null && eMax != null && eMin > eMax) {
    out.add(const JobBlocker('experienceOrder', 'Minimum experience cannot exceed the maximum.'));
  }
  final missing = firstCityMissingOpenings(job.cities, job.cityOpenings);
  if (missing >= 0) {
    final city = [
      for (final c in job.cities)
        if (c.trim().isNotEmpty) c.trim(),
    ][missing];
    out.add(
      JobBlocker('cityOpenings', 'Enter the number of openings for each city ($city is missing).', cityIndex: missing),
    );
  }
  if (job.externalApply && !isApplyUrl(job.applyUrl)) {
    out.add(const JobBlocker('applyUrl', 'Add the link where candidates apply (starting with https://).'));
  }
  final openings = job.openings;
  if (openings != null &&
      (openings != openings.roundToDouble() || openings < JobLimits.openingsMin || openings > JobLimits.openingsMax)) {
    out.add(
      const JobBlocker(
        'openings',
        'Openings must be a whole number from ${JobLimits.openingsMin} to ${JobLimits.openingsMax}.',
      ),
    );
  }
  return out;
}

// --- the description, as text a thumb can type and the HTML the API stores ---------------

/// The composer's text as rich HTML: blank-line paragraphs, `## ` headings, `- ` bullets.
String descriptionToHtml(String text) {
  final out = StringBuffer();
  var inList = false;
  String esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  void closeList() {
    if (inList) out.write('</ul>');
    inList = false;
  }

  final paragraph = <String>[];
  void flush() {
    if (paragraph.isEmpty) return;
    out.write('<p>${paragraph.map(esc).join('<br>')}</p>');
    paragraph.clear();
  }

  for (final raw in text.split('\n')) {
    final t = raw.trim();
    if (t.isEmpty) {
      flush();
      closeList();
    } else if (t.startsWith('## ')) {
      flush();
      closeList();
      out.write('<h3>${esc(t.substring(3).trim())}</h3>');
    } else if (t.startsWith('- ') || t.startsWith('• ') || t.startsWith('* ')) {
      flush();
      if (!inList) out.write('<ul>');
      inList = true;
      out.write('<li>${esc(t.substring(2).trim())}</li>');
    } else {
      closeList();
      paragraph.add(t);
    }
  }
  flush();
  closeList();
  return out.toString();
}

/// Stored rich HTML back to the composer's text ([descriptionToHtml]'s inverse for what it writes).
String htmlToDescription(String? html) {
  if (html == null || html.trim().isEmpty) return '';
  var s = html;
  s = s.replaceAllMapped(RegExp(r'<h[1-6][^>]*>(.*?)</h[1-6]>', dotAll: true), (m) => '\n\n## ${m[1]}\n\n');
  s = s.replaceAllMapped(RegExp(r'<li[^>]*>(.*?)</li>', dotAll: true), (m) => '\n- ${m[1]}');
  s = s.replaceAll(RegExp(r'</ul>|</ol>', caseSensitive: false), '\n\n');
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
  s = s.replaceAll(RegExp(r'<[^>]*>'), '');
  s = s.replaceAll('&nbsp;', ' ').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&amp;', '&');
  return s.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}
