import 'job_format.dart';
import 'job_models.dart';

/// One education entry of the member's profile (`GET /profile/education`).
class EducationEntry {
  const EducationEntry({this.degree, this.field, this.institution});

  /// "B.Tech".
  final String? degree;

  /// "Mechanical Engineering".
  final String? field;
  final String? institution;

  /// "B.Tech, Mechanical Engineering".
  String get summary => [degree, field].where((p) => p != null && p.trim().isNotEmpty).join(', ');

  String get text => [degree, field, institution].where((p) => p != null && p.trim().isNotEmpty).join(' ');
}

/// What the member's profile says, to hold a job's requirements against.
class MemberFacts {
  const MemberFacts({this.years, this.skills = const {}, this.education = const [], this.credentials = const []});

  /// Years of experience (the profile's, else the résumé's), when given.
  final double? years;

  /// The résumé's skills, lower-cased.
  final Set<String> skills;
  final List<EducationEntry> education;

  /// Names of the member's certifications and credentials.
  final List<String> credentials;
}

/// The rows of the job sheet's "Your profile matches N of M requirements"
/// card, built from what the job asks for: the years of experience, the
/// degrees it accepts, the qualifications it names (required, then preferred)
/// and its skills, each held against the member's profile.
///
/// This is the card when the AI match preview is not available (it is a Career
/// Pro feature, and the scorer needs a vector database): the same rows the
/// design draws, from the job's own fields instead of the model's signals.
List<MatchCheck> requirementChecks(Job job, MemberFacts me) {
  final checks = <MatchCheck>[];

  final needed = job.experienceMin ?? 0;
  if (needed > 0) {
    final label = experienceLabel(job);
    final years = me.years;
    checks.add(
      MatchCheck(
        label: '$label of experience',
        met: years != null && years >= needed,
        detail: years == null
            ? 'Add your years of experience to your profile.'
            : 'Your résumé lists ${_years(years)} ${years == 1 ? 'year' : 'years'} of experience.',
      ),
    );
  }

  final degrees = [for (final key in job.educationQualifications) ?_EducationKey.parse(key)];
  if (degrees.isNotEmpty) {
    final found = _educationMeeting(degrees, me.education);
    checks.add(
      MatchCheck(
        label: degreesLabel(job.educationQualifications),
        met: found != null,
        detail: found != null
            ? 'Your profile lists ${found.summary.isEmpty ? found.institution : found.summary}.'
            : me.education.isEmpty
            ? 'Add your education to your profile.'
            : 'Not on your profile yet.',
      ),
    );
  }

  final texts = [for (final e in me.education) e.text, ...me.credentials];
  for (final q in job.qualifications) {
    final met = _textMatches(q, texts);
    checks.add(MatchCheck(label: q, met: met, detail: met ? 'Listed on your profile.' : 'Not on your profile yet.'));
  }
  for (final q in job.preferredQualifications) {
    final met = _textMatches(q, texts);
    checks.add(
      MatchCheck(
        label: q,
        met: met,
        detail: met
            ? 'Preferred credential. Listed on your profile.'
            : 'Preferred credential. Not on your profile yet.',
      ),
    );
  }

  for (final skill in job.skills) {
    final met = me.skills.contains(skill.trim().toLowerCase());
    checks.add(MatchCheck(label: skill, met: met, detail: met ? 'Listed on your résumé.' : 'Not on your résumé yet.'));
  }
  return checks;
}

/// 9.4 → "9.4", 9.0 → "9".
String _years(double years) => years == years.roundToDouble() ? years.toInt().toString() : years.toStringAsFixed(1);

// --- degrees -------------------------------------------------------------------

/// A degree the job accepts, from a taxonomy key such as `UG_BTECH_MECHANICAL`
/// (`packages/shared/src/education.ts`): level, degree, and the specialisation
/// when the key names one. `UG_ANY` is "any graduate degree".
class _EducationKey {
  const _EducationKey(this.level, this.degree, this.stream);

  final String level;
  final String degree;
  final String? stream;

  bool get isAny => degree == 'ANY';
  String get family => '${level}_$degree';

  static final _pattern = RegExp(r'^(UG|PG|DOC)_([A-Z]+)(?:_(.+))?$');

  static _EducationKey? parse(String key) {
    final m = _pattern.firstMatch(key);
    if (m == null) return null;
    final key2 = _EducationKey(m[1]!, m[2]!, m[3]);
    return key2.isAny || _degreeLabels.containsKey(key2.family) ? key2 : null;
  }
}

/// Degree labels, as the website's job composer words them.
const _degreeLabels = <String, String>{
  'UG_BTECH': 'B.Tech / B.E.',
  'UG_DIPLOMA': 'Diploma',
  'UG_BSC': 'B.Sc',
  'UG_BA': 'B.A',
  'UG_BCOM': 'B.Com',
  'UG_BBA': 'BBA / BMS',
  'UG_BCA': 'BCA',
  'UG_BARCH': 'B.Arch',
  'UG_LLB': 'LLB',
  'UG_BPHARMA': 'B.Pharma',
  'UG_MBBS': 'MBBS',
  'UG_BDS': 'BDS',
  'UG_BHM': 'BHM',
  'UG_BED': 'B.Ed',
  'UG_BFA': 'BFA',
  'UG_BDES': 'B.Des',
  'UG_BVSC': 'BVSc',
  'UG_BAMS': 'BAMS',
  'UG_BHMS': 'BHMS',
  'UG_BPT': 'BPT',
  'UG_BELED': 'B.El.Ed',
  'UG_BFTECH': 'BFTech',
  'PG_MTECH': 'M.Tech / M.E.',
  'PG_MBA': 'MBA / PGDM',
  'PG_MSC': 'M.Sc / MS (Science)',
  'PG_MA': 'M.A',
  'PG_MCOM': 'M.Com',
  'PG_MCA': 'MCA',
  'PG_MARCH': 'M.Arch',
  'PG_LLM': 'LLM',
  'PG_MPHARMA': 'M.Pharma',
  'PG_MED': 'M.Ed',
  'PG_MD': 'MD / MS (Medicine)',
  'PG_MDS': 'MDS',
  'PG_MVSC': 'MVSc',
  'PG_MFA': 'MFA',
  'PG_MDES': 'M.Des',
  'PG_DIPLOMA': 'PG Diploma',
  'PG_CA': 'CA',
  'PG_CS': 'CS',
  'PG_ICWA': 'ICWA (CMA)',
  'PG_INTEGRATED': 'Integrated PG',
  'DOC_PHD': 'Ph.D / Doctorate',
  'DOC_MPHIL': 'M.Phil',
  'DOC_MCH': 'MCh',
  'DOC_DM': 'DM',
};

const _anyLabels = <String, String>{'UG': 'A graduate degree', 'PG': 'A postgraduate degree', 'DOC': 'A doctorate'};

/// What else a degree is called, besides the label's own parts.
const _longAliases = <String, List<String>>{
  'UG_BTECH': ['bachelorofengineering', 'bacheloroftechnology', 'bachelorsofengineering', 'bachelorsoftechnology'],
  'PG_MTECH': ['masterofengineering', 'masteroftechnology', 'mastersofengineering', 'mastersoftechnology'],
  'PG_MBA': ['masterofbusinessadministration', 'mastersofbusinessadministration'],
  'UG_BSC': ['bachelorofscience', 'bachelorsofscience'],
  'PG_MSC': ['masterofscience', 'mastersofscience'],
  'UG_BA': ['bachelorofarts', 'bachelorsofarts'],
  'PG_MA': ['masterofarts', 'mastersofarts'],
  'UG_BCOM': ['bachelorofcommerce', 'bachelorsofcommerce'],
  'PG_MCOM': ['masterofcommerce', 'mastersofcommerce'],
  'UG_BBA': ['bachelorofbusinessadministration'],
  'UG_BCA': ['bachelorofcomputerapplications'],
  'PG_MCA': ['masterofcomputerapplications'],
  'UG_LLB': ['bacheloroflaws'],
  'PG_LLM': ['masteroflaws'],
  'DOC_PHD': ['doctorofphilosophy', 'doctorate', 'phd'],
  'UG_DIPLOMA': ['polytechnic'],
  'PG_DIPLOMA': ['postgraduatediploma', 'pgd'],
};

/// Stream words that read better than their key.
const _streamLabels = <String, String>{
  'ELECTRONICS': 'Electronics',
  'PRODUCTION': 'Production / Industrial',
  'HR': 'HR',
  'IT_SYSTEMS': 'IT / Systems',
  'HOTEL_MGMT': 'Hotel Management',
  'PROJECT_MGMT': 'Project Management',
  'MANAGEMENT': 'Management',
};

String _streamLabel(String stream) =>
    _streamLabels[stream] ??
    stream.split('_').map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}').join(' ');

String _or(List<String> items) =>
    items.length <= 1 ? items.join() : '${items.sublist(0, items.length - 1).join(', ')} or ${items.last}';

/// "B.Tech / B.E. in Mechanical or Electrical": the degrees a job accepts, in
/// the order its keys list them. A degree named with no specialisation means
/// any specialisation. Empty when the job needs no degree.
String degreesLabel(List<String> keys) {
  final parsed = [for (final k in keys) ?_EducationKey.parse(k)];
  final order = <String>[];
  final streams = <String, List<String>>{};
  final whole = <String>{};
  for (final k in parsed) {
    if (k.isAny) {
      if (!order.contains(k.family)) order.add(k.family);
      whole.add(k.family);
      continue;
    }
    if (!order.contains(k.family)) order.add(k.family);
    if (k.stream == null) {
      whole.add(k.family);
    } else {
      (streams[k.family] ??= []).add(_streamLabel(k.stream!));
    }
  }
  final parts = <String>[];
  for (final family in order) {
    final level = family.split('_').first;
    final label = family.endsWith('_ANY') ? _anyLabels[level]! : _degreeLabels[family]!;
    final list = streams[family] ?? const [];
    parts.add(whole.contains(family) || list.isEmpty ? label : '$label in ${_or(list)}');
  }
  return parts.join(' or ');
}

String _compact(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

bool _aliasHits(String segment, String alias) {
  if (alias.length < 5) return segment == alias;
  if (alias.length < 8) return segment.startsWith(alias);
  return segment.contains(alias);
}

/// The key of the degree family a degree as the member typed it belongs to
/// ("B.Tech" → `UG_BTECH`), or null when it is none we know.
String? _familyOf(String degree) {
  final segments = degree.split(RegExp(r'[/,;()]')).map(_compact).where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;
  for (final family in _degreeLabels.keys) {
    final aliases = <String>{
      for (final part in _degreeLabels[family]!.replaceAll(RegExp(r'\([^)]*\)'), '').split('/')) _compact(part),
      if (family != 'PG_DIPLOMA') family.split('_').skip(1).join().toLowerCase(),
      ...?_longAliases[family],
    }..remove('');
    if (segments.any((s) => aliases.any((a) => _aliasHits(s, a)))) return family;
  }
  return null;
}

bool _streamMatches(String stream, EducationEntry e) {
  var word = stream.split('_').first.toLowerCase();
  if (word.length > 4 && word.endsWith('s')) word = word.substring(0, word.length - 1);
  final hay = '${e.field ?? ''} ${e.degree ?? ''}'.toLowerCase();
  return RegExp('\\b${RegExp.escape(word)}').hasMatch(hay);
}

EducationEntry? _educationMeeting(List<_EducationKey> keys, List<EducationEntry> entries) {
  for (final e in entries) {
    final degree = e.degree;
    if (degree == null) continue;
    final family = _familyOf(degree);
    if (family == null) continue;
    for (final k in keys) {
      if (k.isAny) {
        if (family.startsWith('${k.level}_')) return e;
        continue;
      }
      if (family != k.family) continue;
      if (k.stream == null || _streamMatches(k.stream!, e)) return e;
    }
  }
  return null;
}

// --- free-text qualifications ---------------------------------------------------

/// Whether a qualification the employer wrote ("RICS or IFMA Facility
/// Management Charter") appears among [texts] (the member's credentials and
/// education): by its acronyms (RICS, IFMA), or as the whole phrase.
bool _textMatches(String requirement, List<String> texts) {
  final wanted = requirement.trim();
  if (wanted.isEmpty) return false;
  final acronyms = RegExp(r'\b[A-Z][A-Z0-9&]{1,7}\b').allMatches(wanted).map((m) => m[0]!).toSet();
  final phrase = wanted.toLowerCase();
  for (final text in texts) {
    final lower = text.toLowerCase();
    if (lower.contains(phrase)) return true;
    for (final a in acronyms) {
      if (RegExp('\\b${RegExp.escape(a)}\\b', caseSensitive: false).hasMatch(text)) return true;
    }
  }
  return false;
}
