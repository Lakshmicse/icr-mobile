/// The company profile's rules, as `@icr/shared` words them (`tax-ids.ts`, `email-domains.ts`, `company-fields.ts`,
/// `CreateCompanyDto`): the identity sheets refuse what the API refuses, in the same sentence, before a round trip.
/// The API stays the last word.
library;

import '../account/account_labels.dart' show legalStructures;

final _letter = RegExp(r'\p{L}', unicode: true);

/// A name must say something: at least two characters, at least one of them a letter.
bool hasLetter(String? value) => _letter.hasMatch(value ?? '');

String? companyNameProblem(String value) {
  final v = value.trim();
  return v.length >= 2 && hasLetter(v) ? null : 'Enter the company name. It needs at least one letter.';
}

/// Blank is "the same as the company name", not a problem.
String? legalNameProblem(String value) {
  final v = value.trim();
  if (v.isEmpty) return null;
  return v.length >= 2 && hasLetter(v) ? null : 'Enter the registered legal name. It needs at least one letter.';
}

// --- PAN and GSTIN -------------------------------------------------------------------------------------------------

final panRe = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
final gstRe = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$');

const panShapeMessage = 'Enter a valid PAN (e.g. AAAPZ1234C).';
const gstinShapeMessage = 'Enter a valid 15-character GSTIN.';

/// The 4th character of a PAN says what kind of holder it belongs to; which letters each organisation type can hold
/// (`PAN_HOLDER_TYPES`). Absent (OTHER) means any.
const panHolderTypes = <String, List<String>>{
  'PRIVATE_LIMITED': ['C'],
  'PUBLIC_LIMITED': ['C'],
  'LLP': ['F'],
  'PARTNERSHIP': ['F'],
  'SOLE_PROPRIETORSHIP': ['P'],
  'GOVERNMENT': ['G', 'L', 'C', 'J', 'A'],
  'TRUST_NGO': ['T', 'A'],
};

/// An example PAN of the right holder type, for the field's placeholder.
String panExample(String? structure) => 'AAA${panHolderTypes[structure]?.first ?? 'C'}Z1234C';

String _structureLabel(String structure) {
  for (final (k, label) in legalStructures) {
    if (k == structure) return label.toLowerCase();
  }
  return structure.toLowerCase();
}

/// What is wrong with a company PAN, or null. Upper-cases before checking; with an organisation type, also checks the
/// 4th letter fits it — the commonest slip being a founder's personal PAN filed for a private limited company.
String? panProblem(String? pan, [String? structure]) {
  final p = (pan ?? '').trim().toUpperCase();
  if (p.isEmpty) return null;
  if (!panRe.hasMatch(p)) return panShapeMessage;
  final allowed = structure == null ? null : panHolderTypes[structure];
  if (allowed != null && !allowed.contains(p[3])) {
    final letters = allowed.length == 1
        ? allowed.first
        : '${allowed.sublist(0, allowed.length - 1).join(', ')} or ${allowed.last}';
    return 'For a ${_structureLabel(structure!)} organisation the PAN’s 4th letter is $letters '
        '(e.g. ${panExample(structure)}); this one has ${p[3]}. Check the PAN or the organisation type.';
  }
  return null;
}

const _gstinChars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

/// The check character a GSTIN ends with, from its first 14 (the GSTN's base-36 scheme).
String gstinCheckChar(String first14) {
  var sum = 0;
  for (var i = 0; i < 14; i++) {
    final product = _gstinChars.indexOf(first14[i]) * (i.isEven ? 1 : 2);
    sum += product ~/ 36 + product % 36;
  }
  return _gstinChars[(36 - sum % 36) % 36];
}

bool _gstinStateCode(String code) {
  final n = int.tryParse(code);
  return n != null && ((n >= 1 && n <= 38) || n == 97 || n == 99);
}

/// What is wrong with a GSTIN, or null: the shape, the state code, the check character, and — given the company's
/// PAN — that the GSTIN carries it (characters 3–12 of a GSTIN are the holder's PAN).
String? gstinProblem(String? gstin, {String? pan}) {
  final g = (gstin ?? '').trim().toUpperCase();
  if (g.isEmpty) return null;
  if (!gstRe.hasMatch(g)) return gstinShapeMessage;
  if (!_gstinStateCode(g.substring(0, 2))) {
    return 'The first two digits of a GSTIN are a state code (01–38). Check the GSTIN.';
  }
  if (gstinCheckChar(g.substring(0, 14)) != g[14]) {
    return 'This GSTIN’s last character does not match the rest. Check it for a typing error.';
  }
  final p = (pan ?? '').trim().toUpperCase();
  if (panRe.hasMatch(p) && g.substring(2, 12) != p) {
    return 'A GSTIN carries the company’s PAN in characters 3–12. This one carries ${g.substring(2, 12)}, not $p.';
  }
  return null;
}

// --- year, PIN, email, phone -------------------------------------------------------------------------------------

/// Nothing was incorporated before this, and nothing is founded next year.
const earliestFoundingYear = 1800;
int latestFoundingYear([DateTime? now]) => (now ?? DateTime.now()).year;

/// The range, said beside the field before anything is typed.
String foundedYearHint([DateTime? now]) => 'A four-digit year, $earliestFoundingYear–${latestFoundingYear(now)}.';

/// What is wrong with a year of establishment, or null when it is fine (or blank — the field is optional).
String? foundedYearProblem(String value, [DateTime? now]) {
  final s = value.trim();
  if (s.isEmpty) return null;
  final year = RegExp(r'^\d{4}$').hasMatch(s) ? int.parse(s) : null;
  if (year != null && year >= earliestFoundingYear && year <= latestFoundingYear(now)) return null;
  return 'Enter a year between $earliestFoundingYear and ${latestFoundingYear(now)}.';
}

final pinRe = RegExp(r'^[1-9][0-9]{5}$');
const pinMessage = 'Enter a 6-digit PIN code.';

/// Whether an address is in India, where the PIN rule applies (blank means the default, India).
bool isIndianAddress(String? country) {
  final c = (country ?? '').trim();
  return c.isEmpty || c.toLowerCase() == 'india';
}

String? pinProblem(String value, String? country) {
  final v = value.trim();
  if (v.isEmpty || !isIndianAddress(country) || pinRe.hasMatch(v)) return null;
  return pinMessage;
}

const _freeEmailDomains = {
  'gmail.com', 'googlemail.com', 'yahoo.com', 'yahoo.co.in', 'yahoo.co.uk', 'ymail.com', 'rocketmail.com', //
  'outlook.com', 'hotmail.com', 'hotmail.co.uk', 'live.com', 'live.in', 'outlook.in', 'msn.com', 'aol.com', //
  'icloud.com', 'me.com', 'mac.com', 'proton.me', 'protonmail.com', 'pm.me', 'zoho.com', 'zohomail.com', //
  'gmx.com', 'gmx.net', 'mail.com', 'yandex.com', 'tutanota.com', 'rediffmail.com', 'rediff.com', 'sify.com', //
  'indiatimes.com',
};

const _disposableEmailDomains = {
  'mailinator.com', 'guerrillamail.com', 'guerrillamail.net', 'sharklasers.com', '10minutemail.com', //
  'tempmail.com', 'temp-mail.org', 'throwawaymail.com', 'yopmail.com', 'trashmail.com', 'getnada.com', //
  'dispostable.com', 'maildrop.cc', 'fakeinbox.com', 'mintemail.com', 'spamgourmet.com', 'mailnesia.com', //
  'tempinbox.com', 'emailondeck.com', 'moakt.com',
};

const workEmailMessage =
    'Use an email address on your company’s own domain. Gmail, Yahoo, Outlook and other public providers are not '
    'accepted.';

/// Whether the address is on a free or throwaway provider (`isPublicEmailDomain`).
bool isPublicEmailDomain(String email) {
  final at = email.lastIndexOf('@');
  if (at < 0) return false;
  var host = email.substring(at + 1).trim().toLowerCase();
  if (host.startsWith('www.')) host = host.substring(4);
  return _freeEmailDomains.contains(host) || _disposableEmailDomains.contains(host);
}

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// The company's work email, on its own domain. Blank is fine; an address saved before the rule is not re-judged
/// ([saved]), so it does not stop every other edit.
String? workEmailProblem(String value, {String? saved}) {
  final v = value.trim();
  if (v.isEmpty || v == (saved ?? '')) return null;
  if (!_email.hasMatch(v)) return 'Enter a valid email address, like name@company.com.';
  return isPublicEmailDomain(v) ? workEmailMessage : null;
}

final _contactPhone = RegExp(r'^\+?[ ()-]*(?:[0-9][ ()-]*){10,15}$');

/// `CONTACT_PHONE_PATTERN`: 10 to 15 digits, with the punctuation people type. Blank is fine.
String? contactPhoneProblem(String value) {
  final v = value.trim();
  return v.isEmpty || _contactPhone.hasMatch(v) ? null : 'Enter a phone number of 10 to 15 digits.';
}

/// "Required with the GSTIN — verification reads it." when a document the facts call for is not on file.
String requiredWithTaxId(String id) => 'Required with the $id. Verification uses it.';

/// "Required for a private limited — verification reads it."
String requiredForStructure(String structure) => 'Required for a ${_structureLabel(structure)}. Verification uses it.';
