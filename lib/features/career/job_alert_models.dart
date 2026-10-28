/// A saved search as the member edits it. The API stores `criteria` as the board's
/// own query (`GET /jobs`), so a search saved on the website can hold more than this
/// form edits (a shift, a seniority, skills...): those travel through untouched.
library;

import '../jobs/job_models.dart';

/// The longest name a saved search may have (`SaveJobSearchDto.name`).
const alertNameMax = 80;

/// The filters the form edits.
class AlertCriteria {
  const AlertCriteria({
    this.search = '',
    this.cities = const [],
    this.workModes = const {},
    this.employmentTypes = const {},
    this.salaryMin,
    this.postedWithinDays,
    this.other = const {},
  });

  /// Reads the stored query.
  factory AlertCriteria.fromMap(Map<String, String> map) {
    List<String> list(String? v) => (v ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    const known = {'search', 'city', 'workMode', 'employmentType', 'salaryMin', 'postedWithinDays'};
    return AlertCriteria(
      search: map['search'] ?? '',
      cities: list(map['city']),
      workModes: {
        for (final m in list(map['workMode']))
          if (WorkMode.fromApi(m) != null) WorkMode.fromApi(m)!,
      },
      employmentTypes: {
        for (final t in list(map['employmentType']))
          if (EmploymentType.fromApi(t) != null) EmploymentType.fromApi(t)!,
      },
      salaryMin: num.tryParse(map['salaryMin'] ?? ''),
      postedWithinDays: int.tryParse(map['postedWithinDays'] ?? ''),
      other: {
        for (final e in map.entries)
          if (!known.contains(e.key)) e.key: e.value,
      },
    );
  }

  final String search;
  final List<String> cities;
  final Set<WorkMode> workModes;
  final Set<EmploymentType> employmentTypes;
  final num? salaryMin;
  final int? postedWithinDays;

  /// Whatever else the saved search holds (`country`, `skills`, `shift`...).
  final Map<String, String> other;

  /// The query to save: blanks left out.
  Map<String, String> toMap() => {
    ...other,
    if (search.trim().isNotEmpty) 'search': search.trim(),
    if (cities.isNotEmpty) 'city': cities.join(','),
    if (workModes.isNotEmpty) 'workMode': workModes.map((m) => m.name.toUpperCase()).join(','),
    if (employmentTypes.isNotEmpty) 'employmentType': employmentTypes.map(employmentKey).join(','),
    if (salaryMin != null) 'salaryMin': '${salaryMin!.round()}',
    if (postedWithinDays != null) 'postedWithinDays': '$postedWithinDays',
  };

  bool get isEmpty => toMap().isEmpty;

  static String employmentKey(EmploymentType t) => switch (t) {
    EmploymentType.fullTime => 'FULL_TIME',
    EmploymentType.partTime => 'PART_TIME',
    _ => t.name.toUpperCase(),
  };

  /// A name for a search that has none: "Mumbai • MEP".
  String suggestedName() {
    final parts = [
      if (search.trim().isNotEmpty) search.trim(),
      if (cities.isNotEmpty) cities.first,
      if (workModes.length == 1) workModes.first.label,
    ];
    final name = parts.join(' • ');
    return name.length > alertNameMax ? name.substring(0, alertNameMax) : name;
  }
}

/// What "Save alert" sends (`POST` / `PATCH /jobs/alerts`).
class AlertDraft {
  const AlertDraft({required this.name, required this.criteria, this.alertsEnabled = true, this.frequency = 'DAILY'});

  final String name;
  final AlertCriteria criteria;
  final bool alertsEnabled;

  /// DAILY or WEEKLY.
  final String frequency;

  /// Why the form cannot be sent, in the API's terms.
  String? get problem {
    final n = name.trim();
    if (n.isEmpty) return 'Give the search a name.';
    if (n.length > alertNameMax) return 'Keep the name to $alertNameMax characters.';
    if (criteria.salaryMin != null && criteria.salaryMin! < 0) return 'Enter a minimum salary of 0 or more.';
    return null;
  }
}

/// The matches an open alert lists.
class AlertMatches {
  const AlertMatches({
    this.jobs = const [],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = false,
    this.page = 0,
    this.error,
  });

  final List<Job> jobs;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final int page;
  final String? error;

  AlertMatches copyWith({
    List<Job>? jobs,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    int? page,
    String? error,
    bool clearError = false,
  }) => AlertMatches(
    jobs: jobs ?? this.jobs,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    hasMore: hasMore ?? this.hasMore,
    page: page ?? this.page,
    error: clearError ? null : error ?? this.error,
  );
}

/// The saved filters as words: `["“MEP”", "Pune", "Remote", "Full-time", "From ₹12,00,000"]`.
List<String> criteriaWords(Map<String, String> criteria, {String Function(num)? money}) {
  final c = AlertCriteria.fromMap(criteria);
  String pretty(String v) {
    final s = v.replaceAll('_', ' ').toLowerCase();
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }

  return [
    if (c.search.trim().isNotEmpty) '“${c.search.trim()}”',
    ...c.cities,
    for (final m in c.workModes) m.label,
    for (final t in c.employmentTypes) t.label,
    if (c.salaryMin != null) 'From ${money?.call(c.salaryMin!) ?? c.salaryMin}',
    if (c.postedWithinDays != null) 'Posted in ${c.postedWithinDays} days',
    // Filters the form does not edit, as the website's chips read them.
    for (final key in const [
      'state',
      'country',
      'shift',
      'seniority',
      'skills',
      'category',
      'jobFunctions',
      'industries',
    ])
      if (c.other[key] != null)
        ...c.other[key]!.split(',').where((p) => p.trim().isNotEmpty).map((p) => pretty(p.trim())),
  ];
}
