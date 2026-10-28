/// The profile's rules, as `@icr/shared` words them (`phone.ts`,
/// `profile-rules.ts`): the edit sheets refuse what the API refuses, in the
/// same sentence, before a round trip. The API stays the last word.
library;

import 'account_models.dart';

// --- phone ---------------------------------------------------------------------------------------------------

/// A country the phone rules know: its dialling code and how many digits follow.
class PhoneCountry {
  const PhoneCountry(this.country, this.dial, this.min, this.max);

  final String country;
  final String dial;
  final int min;
  final int max;

  String get digitCount => min == max ? '$min' : '$min–$max';
}

const phoneCountries = [
  PhoneCountry('India', '91', 10, 10),
  PhoneCountry('United Arab Emirates', '971', 9, 9),
  PhoneCountry('Saudi Arabia', '966', 9, 9),
  PhoneCountry('Qatar', '974', 8, 8),
  PhoneCountry('Oman', '968', 8, 8),
  PhoneCountry('Kuwait', '965', 8, 8),
  PhoneCountry('Bahrain', '973', 8, 8),
  PhoneCountry('Singapore', '65', 8, 8),
  PhoneCountry('Hong Kong', '852', 8, 8),
  PhoneCountry('Malaysia', '60', 9, 10),
  PhoneCountry('Australia', '61', 9, 9),
  PhoneCountry('USA', '1', 10, 10),
  PhoneCountry('UK', '44', 10, 10),
];

const phoneHelp = 'Include your country code, like +44 7700 900123. Indian mobiles can be typed without +91.';

final _separators = RegExp(r'[\s().-]');
final _indianMobile = RegExp(r'^[6-9]\d{9}$');
final _e164Digits = RegExp(r'^[1-9]\d{6,14}$');

PhoneCountry? _countryOfDigits(String digits) {
  PhoneCountry? best;
  for (final c in phoneCountries) {
    if (digits.startsWith(c.dial) && (best == null || c.dial.length > best.dial.length)) best = c;
  }
  return best;
}

/// The number as the API stores it (E.164), or null when it is not one. An
/// Indian mobile may be typed bare or with 91; a leading 0 is never guessed.
String? normalizePhone(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  var s = raw.trim().replaceAll(_separators, '');
  if (s.startsWith('00')) s = '+${s.substring(2)}';
  if (!s.startsWith('+')) {
    if (_indianMobile.hasMatch(s)) return '+91$s';
    if (RegExp(r'^91[6-9]\d{9}$').hasMatch(s)) return '+$s';
    return null;
  }
  final digits = s.substring(1);
  if (!_e164Digits.hasMatch(digits)) return null;
  if (digits.startsWith('91') && !_indianMobile.hasMatch(digits.substring(2))) return null;
  final c = _countryOfDigits(digits);
  if (c != null) {
    final n = digits.length - c.dial.length;
    if (n < c.min || n > c.max) return null;
  }
  return '+$digits';
}

String? _lengthIssue(String digits, {bool mobile = true}) {
  final c = _countryOfDigits(digits);
  if (c == null) return null;
  final national = digits.substring(c.dial.length);
  if (national.isEmpty) return null;
  if (c.dial == '91' && mobile) return _indianMobile.hasMatch(national) ? null : 'Enter a 10-digit Indian mobile number.';
  if (national.length >= c.min && national.length <= c.max) return null;
  return 'Enter ${c.digitCount} digits after +${c.dial} for ${c.country}.';
}

/// Why a typed number is refused (`phoneError`), or null when it is fine or empty.
String? phoneError(String? raw) {
  if (raw == null || raw.trim().isEmpty || normalizePhone(raw) != null) return null;
  final s = raw.trim().replaceAll(_separators, '');
  if (RegExp(r'^(\+|00)?91').hasMatch(s) && s.replaceFirst(RegExp(r'^(\+|00)'), '').length >= 12) {
    return 'Enter a 10-digit Indian mobile number.';
  }
  if (!RegExp(r'^(\+|00)').hasMatch(s)) {
    return 'Add your country code, like +44 7700 900123. Indian mobiles can be typed without +91.';
  }
  return _lengthIssue(s.replaceFirst(RegExp(r'^(\+|00)'), '')) ??
      'Enter a mobile number with its country code, like +44 7700 900123.';
}

/// Codes go through an Indian SMS gateway, so only a +91 number can be confirmed.
bool canTextPhone(String? phone) => normalizePhone(phone)?.startsWith('+91') ?? false;

bool samePhone(String? a, String? b) =>
    (normalizePhone(a) ?? a?.trim() ?? '') == (normalizePhone(b) ?? b?.trim() ?? '');

/// "+91 9876543210": the code apart from the rest.
String formatPhone(String? raw) {
  final e164 = normalizePhone(raw);
  if (e164 == null) return (raw ?? '').trim();
  final digits = e164.substring(1);
  final c = _countryOfDigits(digits);
  return c == null ? e164 : '+${c.dial} ${digits.substring(c.dial.length)}';
}

/// A stored or typed number as the phone field shows it: the listed country and
/// the digits after its code, or, for a number from anywhere else, no country
/// and the whole number. A bare Indian mobile reads as India (`splitPhone`).
({PhoneCountry? country, String national}) splitPhone(String? raw) {
  final s = (raw ?? '').trim().replaceAll(_separators, '');
  if (s.isEmpty) return (country: null, national: '');
  if (!RegExp(r'^(\+|00)').hasMatch(s)) {
    final bare = s.replaceFirst(RegExp(r'^91(?=[6-9]\d{9}$)'), '');
    return _indianMobile.hasMatch(bare)
        ? (country: phoneCountries.first, national: bare)
        : (country: null, national: raw!.trim());
  }
  final digits = s.replaceFirst(RegExp(r'^(\+|00)'), '');
  final c = _countryOfDigits(digits);
  return c == null
      ? (country: null, national: '+$digits')
      : (country: c, national: digits.substring(c.dial.length));
}

/// The number to store from a picked country and the typed digits: `+`, the
/// code, then the digits, a trunk 0 dropped ("07700 900123" in the UK) and a
/// code typed twice ignored. With no country the typed text is the number,
/// code and all. Empty digits are no number at all ('').
String joinPhone(PhoneCountry? country, String national) {
  final typed = national.trim();
  if (typed.isEmpty) return '';
  if (country == null) return typed;
  var digits = typed.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '');
  if (digits.startsWith(country.dial) && digits.length - country.dial.length >= country.min) {
    digits = digits.substring(country.dial.length);
  }
  return '+${country.dial}$digits';
}

/// The country a stored number belongs to, for the contact card.
String? phoneCountryName(String? raw) {
  final e164 = normalizePhone(raw);
  return e164 == null ? null : _countryOfDigits(e164.substring(1))?.country;
}

/// The second number (`@IsAltPhone`): 10 to 15 digits, a known country's length.
String? altPhoneError(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return null;
  final s = value.replaceAll(_separators, '');
  if (RegExp(r'^(\+|00)').hasMatch(s)) {
    final issue = _lengthIssue(s.replaceFirst(RegExp(r'^(\+|00)'), ''), mobile: false);
    if (issue != null) return issue;
  }
  if (!RegExp(r'^\+?[ ()-]*(?:[0-9][ ()-]*){10,15}$').hasMatch(value)) {
    return 'Enter a phone number of 10 to 15 digits';
  }
  return null;
}

// --- email and links -----------------------------------------------------------------------------------------

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? workEmailError(String value) =>
    value.trim().isEmpty || _email.hasMatch(value.trim()) ? null : 'Enter a valid email address, like name@company.com.';

/// The examples the website gives for each link.
const linkExamples = {
  'linkedinUrl': 'https://linkedin.com/in/your-name',
  'websiteUrl': 'https://yourname.com',
  'twitterUrl': 'https://x.com/yourname',
  'githubUrl': 'https://github.com/yourname',
  'portfolioUrl': 'https://behance.net/yourname',
};

/// A link as the API saves it: trimmed, `https://` added when there is no scheme.
String normalizeLink(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return '';
  return RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false).hasMatch(t) ? t : 'https://$t';
}

/// Why a link is refused, or null.
String? linkError(String key, String raw, {bool changed = true}) {
  final value = normalizeLink(raw);
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  final ok =
      uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.contains('.') &&
      !value.contains(' ');
  if (!ok) return 'Enter a full web address, like ${linkExamples[key]}';
  if (key == 'linkedinUrl' && changed && !RegExp(r'(^|\.)linkedin\.com$').hasMatch(uri.host.toLowerCase())) {
    return 'Enter your LinkedIn profile address, like https://linkedin.com/in/your-name';
  }
  return null;
}

/// "linkedin.com/in/nikhil", as the contact card shows a link.
String displayLink(String url) => url.replaceFirst(RegExp(r'^https?://'), '').replaceFirst(RegExp(r'^www\.'), '');

// --- dates ---------------------------------------------------------------------------------------------------

/// Today in India, which the API's career dates are judged against.
({int year, int month}) indiaYearMonth([DateTime? now]) {
  final india = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 5, minutes: 30));
  return (year: india.year, month: india.month);
}

int _ym(int year, int? month, {bool end = false}) => year * 12 + (month ?? (end ? 12 : 1));

// --- the intro -----------------------------------------------------------------------------------------------

({String? firstName, String? headline, String? years}) introProblems({
  required String firstName,
  required String headline,
  required String years,
}) => (
  firstName: firstName.trim().isEmpty ? 'Add your first name.' : null,
  headline: headline.trim().isNotEmpty && headline.trim().length < 2 ? 'A headline needs at least 2 characters.' : null,
  years: () {
    final t = years.trim();
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    return n == null || n < 0 || n > 60 ? 'Whole years, 0–60.' : null;
  }(),
);

// --- experience ----------------------------------------------------------------------------------------------

/// The first problem per field of a role (`experienceProblems`). [strict] for a
/// new or edited role; a row saved before stays as it is.
Map<String, String> experienceProblems(Experience e, {bool strict = true, DateTime? now}) {
  final out = <String, String>{};
  final today = indiaYearMonth(now);
  final title = e.title.trim();
  if (title.isEmpty) {
    out['title'] = 'Add your role.';
  } else if (title.length < 2) {
    out['title'] = 'A role needs at least 2 characters.';
  }
  final org = e.organisation.trim();
  if (org.isEmpty) {
    out['organisation'] = 'Add the organisation.';
  } else if (org.length < 2) {
    out['organisation'] = 'An organisation needs at least 2 characters.';
  }
  if ((e.city ?? '').trim().length > 120) out['city'] = 'Keep the city under 120 characters.';
  if (_ym(e.startYear, e.startMonth) > _ym(today.year, today.month)) {
    out['start'] = 'The start date can’t be in the future.';
  }
  if (!e.isCurrent) {
    if (e.endYear == null) {
      if (strict && e.endMonth != null) {
        out['end'] = 'Add the end year too.';
      } else if (strict) {
        out['end'] = 'Add when this role ended, or tick “I work here now”.';
      }
    } else if (_ym(e.endYear!, e.endMonth, end: e.endMonth == null) >
        _ym(today.year, today.month, end: e.endMonth == null)) {
      out['end'] = 'The end date can’t be in the future. If you still work here, tick “I work here now”.';
    } else if (_ym(e.endYear!, e.endMonth, end: true) < _ym(e.startYear, e.startMonth)) {
      out['end'] = 'The end date is before the start date.';
    }
  }
  if ((e.description ?? '').length > 2000) out['description'] = 'Keep the description under 2,000 characters.';
  return out;
}

/// A career break's problems.
Map<String, String> careerBreakProblems(CareerBreak b, {DateTime? now}) {
  final out = <String, String>{};
  final today = indiaYearMonth(now);
  if (b.reason.isEmpty) out['reason'] = 'Choose why you took this break.';
  if (b.startYear < 1950) out['start'] = 'Choose a year from 1950 on.';
  if (_ym(b.startYear, b.startMonth) > _ym(today.year, today.month)) {
    out['start'] = 'The start date can’t be in the future.';
  }
  if (!b.isCurrent) {
    if (b.endYear == null) {
      out['end'] = b.endMonth != null ? 'Add the end year too.' : 'Add when the break ended, or tick “I’m on this break now”.';
    } else if (_ym(b.endYear!, b.endMonth) > _ym(today.year, today.month)) {
      out['end'] = 'The end date can’t be in the future.';
    } else if (_ym(b.endYear!, b.endMonth, end: true) < _ym(b.startYear, b.startMonth)) {
      out['end'] = 'The end date is before the start date.';
    }
  }
  if ((b.description ?? '').length > 2000) out['description'] = 'Keep the description under 2,000 characters.';
  return out;
}

// --- education -----------------------------------------------------------------------------------------------

Map<String, String> educationProblems(Education e, {DateTime? now}) {
  final out = <String, String>{};
  final year = indiaYearMonth(now).year;
  final name = e.institution.trim();
  if (name.isEmpty) {
    out['institution'] = 'Add the institution.';
  } else if (name.length < 2) {
    out['institution'] = 'An institution needs at least 2 characters.';
  }
  if (e.startYear != null && e.startYear! > year) out['start'] = 'The start year can’t be in the future.';
  if (e.endYear != null && e.endYear! > year) {
    out['end'] = 'The end year can’t be in the future. Leave it blank while you are still studying.';
  } else if (e.endYear != null && e.startYear != null && e.endYear! < e.startYear!) {
    out['end'] = 'The end year is before the start year.';
  }
  return out;
}

// --- credentials ---------------------------------------------------------------------------------------------

Map<String, String> credentialProblems(CredentialDraft d, {DateTime? now}) {
  final out = <String, String>{};
  final name = d.name.trim();
  if (name.isEmpty) {
    out['name'] = 'Give the credential a name.';
  } else if (name.length < 2) {
    out['name'] = 'A credential’s name needs at least 2 characters.';
  }
  final india = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 5, minutes: 30));
  final today = DateTime.utc(india.year, india.month, india.day);
  if (d.issuedOn != null && DateTime.utc(d.issuedOn!.year, d.issuedOn!.month, d.issuedOn!.day).isAfter(today)) {
    out['issuedOn'] = 'The issue date can’t be in the future.';
  }
  if (d.issuedOn != null && d.expiresOn != null && d.expiresOn!.isBefore(d.issuedOn!)) {
    out['expiresOn'] = 'The expiry date is before the issue date.';
  }
  final url = (d.credentialUrl ?? '').trim();
  if (url.isNotEmpty) {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
      out['credentialUrl'] = 'Enter a full web address, like https://issuer.org/verify/12345.';
    }
  }
  return out;
}

// --- company -------------------------------------------------------------------------------------------------

final _letter = RegExp(r'\p{L}', unicode: true);

/// "Create a company page": the website's checks on Create, field by field.
Map<String, String> companyProblems({
  required String name,
  required bool differentLegalName,
  required String legalName,
  required String website,
  required String? industry,
  required String? size,
  required String? legalStructure,
  required String? city,
  required bool authorised,
}) {
  final out = <String, String>{};
  final n = name.trim();
  if (n.length < 2 || !_letter.hasMatch(n)) out['name'] = 'Enter the company name.';
  final l = legalName.trim();
  if (differentLegalName && l.isNotEmpty && (l.length < 2 || !_letter.hasMatch(l))) {
    out['legalName'] = 'Enter the registered legal name — it needs at least one letter.';
  }
  final w = website.trim();
  if (w.isNotEmpty && !_isWebsite(w)) out['website'] = 'Enter a website like acme.com or https://acme.com';
  if (industry == null) out['industry'] = 'Choose the industry it works in.';
  if (city == null) out['city'] = 'Choose where the head office is.';
  if (size == null) out['size'] = 'Choose how many people work there.';
  if (legalStructure == null) out['legalStructure'] = 'Choose how the organisation is set up.';
  if (!authorised) out['authorised'] = 'Confirm that you may create this page for the company.';
  return out;
}

/// validator.js `isURL` with the scheme optional: a host with a dot and a TLD,
/// no spaces or underscores in the host.
bool _isWebsite(String raw) {
  if (raw.length > 2084 || raw.contains(' ')) return false;
  final withScheme = RegExp(r'^[a-z]+://', caseSensitive: false).hasMatch(raw) ? raw : 'https://$raw';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'ftp')) return false;
  final host = uri.host;
  if (host.contains('_') || !host.contains('.')) return false;
  final tld = host.split('.').last;
  return RegExp(r'^[a-z¡-￿]{2,}$', caseSensitive: false).hasMatch(tld);
}

// --- the timeline --------------------------------------------------------------------------------------------

/// The dates a career timeline is ordered by: a role, a qualification, a break.
typedef TimelineDates = ({int? startYear, int? startMonth, int? endYear, int? endMonth, bool isCurrent});

/// A list sorted newer first, as `[a, b, c]` keys compare; equal dates keep the
/// order they came in (`newerFirst` of the website's `@icr/shared`).
List<T> newerFirst<T>(List<T> rows, List<int> Function(T) keys) {
  final keyed = [for (var i = 0; i < rows.length; i++) (i: i, row: rows[i], key: keys(rows[i]))];
  keyed.sort((a, b) {
    for (var i = 0; i < a.key.length; i++) {
      if (a.key[i] != b.key[i]) return b.key[i].compareTo(a.key[i]);
    }
    return a.i.compareTo(b.i);
  });
  return [for (final k in keyed) k.row];
}

/// A role (or a break) is open while it is current or has no end: what is still
/// going on first, newest start first; then by when it ended, then when it started.
List<int> experienceKeys(TimelineDates r) {
  final open = r.isCurrent || r.endYear == null;
  return [open ? 1 : 0, open ? 0 : r.endYear! * 12 + (r.endMonth ?? 0), (r.startYear ?? 0) * 12 + (r.startMonth ?? 0)];
}

/// Qualifications: still studying first, then by end year, then start year.
List<int> educationKeys(TimelineDates r) => [
  r.endYear == null && r.startYear != null ? 1 : 0,
  r.endYear ?? 0,
  r.startYear ?? 0,
];

/// Gaps shorter than this are a notice period or a holiday, not a gap.
const careerGapMinMonths = 6;

/// A stretch no role or break accounts for. [ongoing]: it runs up to this month.
class CareerGap {
  const CareerGap({required this.fromYear, required this.fromMonth, required this.toYear, required this.toMonth, required this.months, required this.ongoing});

  final int fromYear;
  final int fromMonth;
  final int toYear;
  final int toMonth;
  final int months;
  final bool ongoing;
}

/// The stretches of a career no role or break covers, oldest first: from the
/// first role's start to this month (in India), at least [minMonths] long.
/// Shown only to the person, as "Add a career break" prompts. Generous by
/// design: a missing start month counts as January, a missing end month as
/// December, and a role with no end runs to today.
List<CareerGap> careerGaps(
  List<TimelineDates> roles, {
  List<TimelineDates> breaks = const [],
  DateTime? now,
  int minMonths = careerGapMinMonths,
}) {
  final today = indiaYearMonth(now);
  final nowIdx = today.year * 12 + today.month - 1;
  (int, int)? span(TimelineDates r) {
    if (r.startYear == null) return null;
    final start = r.startYear! * 12 + (r.startMonth ?? 1) - 1;
    final open = r.isCurrent || r.endYear == null;
    final end = open ? nowIdx : r.endYear! * 12 + (r.endMonth ?? 12) - 1;
    return (start, end < nowIdx ? end : nowIdx);
  }

  final roleSpans = [for (final r in roles) ?span(r)];
  if (roleSpans.isEmpty) return const [];
  final first = roleSpans.map((s) => s.$1).reduce((a, b) => a < b ? a : b);
  final covered = [...roleSpans, for (final b in breaks) ?span(b)].where((s) => s.$2 >= s.$1).toList()
    ..sort((x, y) => x.$1.compareTo(y.$1));
  final gaps = <CareerGap>[];
  var cursor = first;
  void flush(int until) {
    final months = until - cursor + 1;
    if (months >= minMonths) {
      gaps.add(CareerGap(
        fromYear: cursor ~/ 12,
        fromMonth: cursor % 12 + 1,
        toYear: until ~/ 12,
        toMonth: until % 12 + 1,
        months: months,
        ongoing: until == nowIdx,
      ));
    }
  }

  for (final (a, b) in covered) {
    if (b < cursor) continue;
    if (a > cursor) flush(a - 1);
    cursor = cursor > b + 1 ? cursor : b + 1;
  }
  if (cursor <= nowIdx) flush(nowIdx);
  return gaps;
}

/// The years a role can start in, newest first: this year in India back to 1950.
List<int> careerYearOptions([DateTime? now]) => [for (var y = indiaYearMonth(now).year; y >= 1950; y--) y];
