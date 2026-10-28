/// A job's screening questions as the candidate answers them, and the rule
/// that checks each answer: a port of `validateScreeningAnswer` in
/// `@icr/shared` (`packages/shared/src/screening.ts`), which the API runs on the
/// same answers, so the reason shows in the form instead of as a refusal.
///
/// Answers travel as strings: "true"/"false", a number as text, comma-joined
/// option labels, an integer rating or years, or an ISO date (yyyy-mm-dd).
library;

enum ScreeningType {
  yesNo,
  numeric,
  singleSelect,
  multiSelect,
  rating,
  years,
  date,
  text;

  static ScreeningType fromApi(String? v) => switch (v) {
    'YES_NO' => yesNo,
    'NUMERIC' => numeric,
    'SINGLE_SELECT' => singleSelect,
    'MULTI_SELECT' => multiSelect,
    'RATING' => rating,
    'YEARS' => years,
    'DATE' => date,
    _ => text,
  };
}

/// Free-text answers are capped at this many characters (`SCREENING_TEXT_MAX_CHARS`).
const screeningTextMax = 1000;

/// The top of the years list, shown as "15+" (`SCREENING_YEARS_MAX`).
const screeningYearsMax = 15;

/// One question as `GET /jobs/:id` gives it to a candidate (no grading key).
class ScreeningQuestion {
  const ScreeningQuestion({
    required this.id,
    required this.prompt,
    this.type = ScreeningType.text,
    this.options = const [],
    this.scaleMax,
  });

  factory ScreeningQuestion.fromJson(Map<String, dynamic> json) => ScreeningQuestion(
    id: json['id'].toString(),
    prompt: json['prompt'] as String? ?? '',
    type: ScreeningType.fromApi(json['type'] as String?),
    options: (json['options'] as List? ?? const []).map((o) => o.toString()).toList(),
    scaleMax: (json['scaleMax'] as num?)?.toInt(),
  );

  final String id;
  final String prompt;
  final ScreeningType type;

  /// The choices of a single- or multi-select question.
  final List<String> options;

  /// A rating's top: 5, or 10 when the question says so.
  final int? scaleMax;

  int get ratingMax => scaleMax == 10 ? 10 : 5;
}

/// "15+" for the top of the years list, else the number.
String yearsChoiceLabel(int n) => n >= screeningYearsMax ? '$screeningYearsMax+' : '$n';

bool _isIsoDate(String value) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
  if (m == null) return false;
  final y = int.parse(m[1]!);
  final mo = int.parse(m[2]!);
  final d = int.parse(m[3]!);
  if (mo < 1 || mo > 12 || d < 1) return false;
  final dt = DateTime.utc(y, mo, d);
  return dt.year == y && dt.month == mo && dt.day == d;
}

num? _numberOf(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  final n = num.tryParse(t);
  return n == null || n.isNaN || n.isInfinite ? null : n;
}

/// Why [answer] does not fit [q], in the API's words; null when it does.
String? screeningAnswerProblem(ScreeningQuestion q, String? answer) {
  final a = (answer ?? '').trim();
  if (a.isEmpty) return 'This question needs an answer.';
  final options = q.options.map((o) => o.trim().toLowerCase()).toList();
  switch (q.type) {
    case ScreeningType.yesNo:
      return const ['true', 'false'].contains(a.toLowerCase()) ? null : 'Choose Yes or No.';
    case ScreeningType.numeric:
      final n = _numberOf(a);
      return n != null && n >= 0 ? null : 'Enter a number (0 or more).';
    case ScreeningType.singleSelect:
      return options.contains(a.toLowerCase()) ? null : 'Choose one of the listed options.';
    case ScreeningType.multiSelect:
      final picked = a.split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toList();
      return picked.isNotEmpty && picked.every(options.contains) ? null : 'Choose at least one of the listed options.';
    case ScreeningType.text:
      return a.length <= screeningTextMax ? null : 'Keep it under $screeningTextMax characters.';
    case ScreeningType.rating:
      final n = _numberOf(a);
      final max = q.ratingMax;
      return n != null && n == n.roundToDouble() && n >= 1 && n <= max ? null : 'Pick a rating from 1 to $max.';
    case ScreeningType.years:
      final n = _numberOf(a);
      return n != null && n == n.roundToDouble() && n >= 0 && n <= screeningYearsMax
          ? null
          : 'Choose your years of experience.';
    case ScreeningType.date:
      return _isIsoDate(a) ? null : 'Enter a valid date.';
  }
}
