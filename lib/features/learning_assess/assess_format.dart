import 'assess_models.dart';

/// Indian grouping, as the website: 1180000 → "11,80,000"; 11800 → "11,800".
String groupThousands(int n) {
  final negative = n < 0;
  final s = n.abs().toString();
  if (s.length <= 3) return negative ? '-$s' : s;
  final last = s.substring(s.length - 3);
  var head = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (head.length > 2) {
    parts.insert(0, head.substring(head.length - 2));
    head = head.substring(0, head.length - 2);
  }
  if (head.isNotEmpty) parts.insert(0, head);
  return '${negative ? '-' : ''}${parts.join(',')},$last';
}

/// "₹11,800" from paise, keeping paise only when there are some: "₹588.82". The website's `rupees`.
String rupees(int paise, [String currency = 'INR']) {
  final whole = paise ~/ 100;
  final rest = paise % 100;
  final number = rest == 0 ? groupThousands(whole) : '${groupThousands(whole)}.${rest.toString().padLeft(2, '0')}';
  return currency == 'INR' ? '₹$number' : '$currency $number';
}

/// "5 ICR credits", "1 ICR credit".
String creditsLabel(int credits) => credits == 1 ? '1 ICR credit' : '$credits ICR credits';

/// "1 credit", "3 credits" (the short form on a button's second line).
String creditsShort(int credits) => credits == 1 ? '1 credit' : '$credits credits';

String plural(int n, String one, [String? many]) => n == 1 ? '$n $one' : '$n ${many ?? '${one}s'}';

/// "30 min", "1 h 30 min", "2 h".
String durationLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

/// "1 attempt", "3 attempts".
String attemptsLabel(int n) => plural(n, 'attempt');

/// "2 of 3 attempts used" for a paper with a limit, "2 attempts" without.
String attemptsUsedLabel(int used, int? limit) =>
    limit == null ? (used == 0 ? 'Unlimited attempts' : attemptsLabel(used)) : '$used of $limit attempts used';

/// What a paper is called when it is handed to the exam: "Capital Planning – Foundation", "AEE CBCP – Set 1".
/// The website's `paperName`: a paper's own title is only its rung or set, which says nothing on its own.
String paperName(AssessPaper paper, PaperGroup group) => '${group.title} – ${paper.title}';

/// "Set 01" label of the nth set (0-based).
String setNumber(int index) => 'SET ${(index + 1).toString().padLeft(2, '0')}';

/// A programme card's second line: its levels in the order a candidate climbs them.
String levelsLine(PaperGroup group) {
  final names = <String>[
    for (final p in group.ladder)
      if (p.levelName != null) p.levelName!,
  ];
  final unlevelled = group.papers.where((p) => p.levelName == null).length;
  if (names.isEmpty) return plural(group.papers.length, 'assessment');
  return [...names, if (unlevelled > 0) plural(unlevelled, 'other')].join(' · ');
}

/// A subject card's second line: "2 sets · 10 questions", "3 sets · 10–25 questions".
String setsLine(PaperGroup group) {
  final counts = group.papers.map((p) => p.questions).where((q) => q > 0).toList()..sort();
  final sets = plural(group.papers.length, 'set');
  if (counts.isEmpty) return sets;
  final range = counts.first == counts.last ? '${counts.first}' : '${counts.first}–${counts.last}';
  return '$sets · $range questions';
}

/// "Showing 3 of 31 certifications."
String showingLine(int visible, int total, String noun) => 'Showing $visible of $total $noun.';
