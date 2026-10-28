/// What an application may need beyond the note and the answers, ported from `@icr/shared`
/// (`enums.ts`, `profile-rules.ts`, `linkedin.ts`), which the API runs on the same input, so
/// the form can ask first and refuse locally what the API would refuse.
library;

/// The groups a posting can be opened to (`JobDiversityCategory`), as the profile words them.
const diversityLabels = <String, String>{
  'WOMEN': 'Women',
  'WOMEN_RETURNING': 'Women returning to work',
  'EX_DEFENCE': 'Ex-defence personnel',
  'DIFFERENTLY_ABLED': 'Differently-abled',
  'LGBTQ': 'LGBTQ+',
};

const _audience = <String, String>{
  'WOMEN': 'women',
  'WOMEN_RETURNING': 'women returning to work',
  'EX_DEFENCE': 'ex-defence',
  'DIFFERENTLY_ABLED': 'differently-abled',
  'LGBTQ': 'LGBTQ+',
};

/// "women or ex-defence candidates".
String diversityAudienceSentence(Iterable<String> categories) {
  final nouns = {for (final c in categories) ?_audience[c]};
  return nouns.isEmpty ? 'these candidates' : '${nouns.join(' or ')} candidates';
}

/// The gender a posting is restricted to (`JobGenderPreference` to `Gender`); null when open to anyone.
String? genderRequiredBy(String? preference) => switch (preference) {
  'MALE' => 'MAN',
  'FEMALE' => 'WOMAN',
  'OTHER' => 'NON_BINARY',
  _ => null,
};

/// "This role accepts applications only from women."
String? genderOnlySentence(String? preference) => switch (genderRequiredBy(preference)) {
  'MAN' => 'This role accepts applications only from men.',
  'WOMAN' => 'This role accepts applications only from women.',
  'NON_BINARY' => 'This role accepts applications only from non-binary people.',
  _ => null,
};

/// The genders a person can give (`Gender`), in the order the profile lists them.
const genderChoices = <(String, String)>[
  ('WOMAN', 'Woman'),
  ('MAN', 'Man'),
  ('NON_BINARY', 'Non-binary'),
  ('PREFER_NOT_TO_SAY', 'Prefer not to say'),
];

final _linkedinHosts = RegExp(r'^(?:[a-z0-9-]+\.)*linkedin\.com$|^lnkd\.in$');

/// The https link of a LinkedIn profile, or null when the text is not one
/// (`normalizeLinkedInUrl`): a scheme is optional, a bare host is not a profile.
String? normalizeLinkedIn(String? raw) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  final withScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(trimmed) ? trimmed : 'https://$trimmed';
  final url = Uri.tryParse(withScheme);
  if (url == null || !url.hasAuthority) return null;
  if (url.scheme != 'https' && url.scheme != 'http') return null;
  if (!_linkedinHosts.hasMatch(url.host.toLowerCase())) return null;
  if (url.path.isEmpty || url.path == '/') return null;
  return 'https://${url.host.toLowerCase()}${url.path.replaceAll(RegExp(r'/+$'), '')}';
}

/// Why a LinkedIn link cannot be sent; null when it is empty (no link) or good.
String? linkedinProblem(String? raw) {
  if ((raw ?? '').trim().isEmpty) return null;
  return normalizeLinkedIn(raw) == null ? 'Enter your LinkedIn profile link, such as linkedin.com/in/your-name.' : null;
}
