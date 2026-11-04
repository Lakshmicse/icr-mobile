import '../../../core/config.dart';
import '../../career/career_format.dart';
import '../../career/career_models.dart' show MatchSignal;

/// An interview as its panel reads it (`GET /interviews/:id`, the website's `/manage/interviews/:id`): the
/// candidate, what screening found, the hiring team's notes, the rounds before this one, and the scorecards.
/// A panelist sees the rest of this round's scorecards only once their own is in (the API holds them back).
class InterviewBrief {
  const InterviewBrief({
    required this.id,
    required this.round,
    required this.scheduledAt,
    required this.durationMins,
    required this.mode,
    required this.status,
    required this.application,
    this.title,
    this.location,
    this.meetingLink,
    this.mapLink,
    this.notes,
    this.panel = const [],
    this.isPanelist = false,
    this.myScorecard,
    this.panelScorecards = const [],
    this.panelSubmittedCount = 0,
    this.earlierRounds = const [],
    this.teamNotes = const [],
  });

  factory InterviewBrief.fromJson(Map<String, dynamic> json, {String? apiBase}) {
    final mine = json['myScorecard'];
    return InterviewBrief(
      id: '${json['id']}',
      round: (json['round'] as num?)?.toInt() ?? 1,
      title: _text(json['title']),
      scheduledAt: _date(json['scheduledAt']) ?? DateTime.now(),
      durationMins: (json['durationMins'] as num?)?.toInt() ?? 60,
      mode: json['mode'] as String? ?? 'VIDEO',
      location: _text(json['location']),
      meetingLink: _text(json['meetingLink']),
      mapLink: _text(json['mapLink']),
      status: json['status'] as String? ?? 'SCHEDULED',
      notes: _text(json['notes']),
      panel: _names(json['interviewers']),
      application: BriefApplication.fromJson(_map(json['application']), apiBase: apiBase),
      isPanelist: json['isPanelist'] == true,
      myScorecard: mine is Map ? Scorecard.fromJson(Map<String, dynamic>.from(mine)) : null,
      panelScorecards: [for (final s in _maps(json['panelScorecards'])) Scorecard.fromJson(s)],
      panelSubmittedCount: (json['panelSubmittedCount'] as num?)?.toInt() ?? 0,
      earlierRounds: [for (final r in _maps(json['earlierRounds'])) BriefRound.fromJson(r)],
      teamNotes: [for (final n in _maps(json['teamNotes'])) BriefNote.fromJson(n)],
    );
  }

  final String id;
  final int round;
  final String? title;
  final DateTime scheduledAt;
  final int durationMins;

  /// VIDEO, IN_PERSON or PHONE.
  final String mode;
  final String? location;
  final String? meetingLink;
  final String? mapLink;

  /// SCHEDULED, RESCHEDULED, COMPLETED, CANCELLED or NO_SHOW.
  final String status;

  /// The recruiter's notes for the panel.
  final String? notes;
  final List<String> panel;
  final BriefApplication application;

  /// The viewer sits on this round's panel (they score it); otherwise they are the hiring team reading it.
  final bool isPanelist;
  final Scorecard? myScorecard;
  final List<Scorecard> panelScorecards;

  /// How many of the rest of the panel have scored, shown while their scorecards stay hidden.
  final int panelSubmittedCount;
  final List<BriefRound> earlierRounds;
  final List<BriefNote> teamNotes;

  bool get cancelled => status == 'CANCELLED';

  /// "Round 2 · Operations panel".
  String get roundLabel => roundName(round, title);

  /// The office address of an in-person interview, else null.
  String? get address => mode == 'IN_PERSON' ? location : null;

  /// Where "Open in Google Maps" goes: the link the recruiter pasted, else a search for the address.
  Uri? get mapUri {
    if (mode != 'IN_PERSON') return null;
    if (mapLink != null) return Uri.tryParse(mapLink!);
    final a = address;
    return a == null ? null : Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': a});
  }

  InterviewBrief withMyScorecard(Scorecard card) => InterviewBrief(
    id: id,
    round: round,
    title: title,
    scheduledAt: scheduledAt,
    durationMins: durationMins,
    mode: mode,
    location: location,
    meetingLink: meetingLink,
    mapLink: mapLink,
    status: status,
    notes: notes,
    panel: panel,
    application: application,
    isPanelist: isPanelist,
    myScorecard: card,
    panelScorecards: panelScorecards,
    panelSubmittedCount: panelSubmittedCount,
    earlierRounds: earlierRounds,
    teamNotes: teamNotes,
  );
}

/// The application behind the interview, as the panel needs it.
class BriefApplication {
  const BriefApplication({
    required this.id,
    required this.stage,
    required this.appliedAt,
    required this.applicantName,
    required this.jobTitle,
    this.applicantId,
    this.photoUrl,
    this.jobId,
    this.coverNote,
    this.linkedinUrl,
    this.resumeUrl,
    this.headline,
    this.skills = const [],
    this.experienceYears,
    this.currentLocation,
    this.answers = const [],
    this.qualificationMet,
    this.qualificationTotal,
    this.qualified = true,
    this.matchScore,
    this.signals = const [],
    this.aiSummary,
    this.screenedAt,
  });

  factory BriefApplication.fromJson(Map<String, dynamic> json, {String? apiBase}) {
    final person = _map(json['applicant']);
    final resume = json['resume'] is Map ? _map(json['resume']) : null;
    final job = _map(json['job']);
    final qual = json['qualification'] is Map ? _map(json['qualification']) : null;
    return BriefApplication(
      id: '${json['id']}',
      stage: json['stage'] as String? ?? 'INTERVIEW',
      appliedAt: _date(json['appliedAt']) ?? DateTime.now(),
      applicantId: person['id']?.toString(),
      applicantName: _name(person) ?? '',
      photoUrl: AppConfig.absoluteUrl(person['avatarUrl'] as String?, apiBase: apiBase),
      jobId: job['id']?.toString(),
      jobTitle: '${job['title'] ?? ''}',
      coverNote: _text(json['coverNote']),
      linkedinUrl: _text(json['linkedinUrl']),
      resumeUrl: _text(json['resumeUrl']),
      headline: _text(resume?['headline']),
      skills: [for (final s in (resume?['skills'] as List? ?? const [])) '$s'],
      experienceYears: (resume?['experienceYears'] as num?)?.toDouble(),
      currentLocation: _text(resume?['currentLocation']),
      answers: [for (final a in _maps(json['answers'])) BriefAnswer.fromJson(a)],
      qualificationMet: (qual?['met'] as num?)?.toInt(),
      qualificationTotal: (qual?['total'] as num?)?.toInt(),
      qualified: qual?['qualified'] != false,
      matchScore: (json['matchScore'] as num?)?.round(),
      signals: [
        for (final s in _maps(json['screeningSignals']))
          MatchSignal(label: '${s['label'] ?? ''}', score: (s['score'] as num?)?.toDouble() ?? 0, detail: _text(s['detail'])),
      ],
      aiSummary: _text(json['aiSummary']),
      screenedAt: _date(json['screenedAt']),
    );
  }

  final String id;

  /// APPLIED, SCREENING, INTERVIEW, OFFER, HIRED, REJECTED or WITHDRAWN.
  final String stage;
  final DateTime appliedAt;
  final String? applicantId;
  final String applicantName;
  final String? photoUrl;
  final String? jobId;
  final String jobTitle;
  final String? coverNote;
  final String? linkedinUrl;

  /// The file sent with the application, else the profile résumé's: a PRIVATE upload, read with the session.
  final String? resumeUrl;
  final String? headline;
  final List<String> skills;
  final double? experienceYears;
  final String? currentLocation;
  final List<BriefAnswer> answers;
  final int? qualificationMet;
  final int? qualificationTotal;
  final bool qualified;
  final int? matchScore;
  final List<MatchSignal> signals;
  final String? aiSummary;
  final DateTime? screenedAt;

  bool get hasQualification => qualificationTotal != null;

  /// Screening ran and found nothing to compare (the website's "Not enough information to score").
  bool get unscorable => matchScore == null && screenedAt != null;

  /// Nothing came from screening at all: no cover note, no answers, no score, screening not run.
  bool get nothingFromScreening => coverNote == null && answers.isEmpty && matchScore == null && screenedAt == null;

  /// "Operations head · 9 yrs exp · Pune".
  List<String> get facts => [
    ?headline,
    if (experienceYears != null) '${_years(experienceYears!)} yrs exp',
    ?currentLocation,
  ];

  static String _years(double y) => y == y.roundToDouble() ? y.toInt().toString() : y.toStringAsFixed(1);
}

/// One answer to the employer's screening questions, with its verdict when the question is graded.
class BriefAnswer {
  const BriefAnswer({
    required this.prompt,
    required this.type,
    required this.answer,
    this.scaleMax,
    this.graded = false,
    this.meetsIdeal = false,
    this.mustHave = false,
    this.ideal,
  });

  factory BriefAnswer.fromJson(Map<String, dynamic> json) => BriefAnswer(
    prompt: '${json['prompt'] ?? ''}',
    type: json['type'] as String? ?? 'TEXT',
    answer: '${json['answer'] ?? ''}',
    scaleMax: (json['scaleMax'] as num?)?.toInt(),
    graded: json['graded'] == true,
    meetsIdeal: json['meetsIdeal'] == true,
    mustHave: json['mustHave'] == true,
    ideal: _text(json['idealAnswer']),
  );

  final String prompt;

  /// YES_NO, NUMERIC, YEARS, RATING, DATE, SINGLE_SELECT, MULTI_SELECT or TEXT.
  final String type;
  final String answer;
  final int? scaleMax;

  /// False for free text and for a question with no ideal answer: "not met" means nothing then.
  final bool graded;
  final bool meetsIdeal;
  final bool mustHave;
  final String? ideal;

  /// The answer in words, as the website writes it (`formatScreeningAnswer`): "Yes", "4 / 5", "15+ years".
  String get display => wordsFor(answer);

  /// What the question needed (`formatScreeningIdeal`): "at least 4 / 5", "on or before 1 Oct 2026", "Yes".
  String? get needed {
    final i = ideal?.trim();
    if (i == null || i.isEmpty) return null;
    return switch (type) {
      'NUMERIC' => 'at least $i',
      'RATING' || 'YEARS' => 'at least ${wordsFor(i)}',
      'DATE' => 'on or before ${wordsFor(i)}',
      'TEXT' => null,
      _ => wordsFor(i),
    };
  }

  String wordsFor(String raw) {
    final a = raw.trim();
    switch (type) {
      case 'YES_NO':
        final n = a.toLowerCase();
        return n == 'true' ? 'Yes' : (n == 'false' ? 'No' : a);
      case 'RATING':
        return '$a / ${scaleMax == 10 ? 10 : 5}';
      case 'YEARS':
        final n = num.tryParse(a);
        if (n == null) return a;
        if (n <= 0) return 'Less than a year';
        if (n >= 15) return '15+ years';
        return '$a ${n == 1 ? 'year' : 'years'}';
      case 'DATE':
        final d = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(a);
        if (d == null) return a;
        return formatDay(DateTime(int.parse(d[1]!), int.parse(d[2]!), int.parse(d[3]!)), year: true);
      case 'MULTI_SELECT':
        return a.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).join(', ');
      default:
        return a;
    }
  }
}

/// One panelist's scorecard (`InterviewScorecardDto`).
class Scorecard {
  const Scorecard({
    required this.id,
    required this.rating,
    required this.recommendation,
    required this.submittedAt,
    this.interviewer,
    this.strengths,
    this.concerns,
  });

  factory Scorecard.fromJson(Map<String, dynamic> json) => Scorecard(
    id: '${json['id']}',
    interviewer: json['interviewer'] is Map ? _name(_map(json['interviewer'])) : null,
    rating: (json['overallRating'] as num?)?.toInt() ?? 0,
    recommendation: json['recommendation'] as String? ?? 'NEUTRAL',
    strengths: _text(json['strengths']),
    concerns: _text(json['concerns']),
    submittedAt: _date(json['submittedAt']) ?? DateTime.now(),
  );

  final String id;

  /// Null when the panelist is no longer on ICR ("Former panelist").
  final String? interviewer;

  /// 1 to 5.
  final int rating;

  /// STRONG_YES, YES, NEUTRAL, NO or STRONG_NO.
  final String recommendation;
  final String? strengths;
  final String? concerns;
  final DateTime submittedAt;
}

/// A round held before the one being read, with what its panel said.
class BriefRound {
  const BriefRound({
    required this.id,
    required this.round,
    required this.scheduledAt,
    required this.status,
    this.title,
    this.mode = 'VIDEO',
    this.panel = const [],
    this.scorecards = const [],
  });

  factory BriefRound.fromJson(Map<String, dynamic> json) => BriefRound(
    id: '${json['id']}',
    round: (json['round'] as num?)?.toInt() ?? 1,
    title: _text(json['title']),
    scheduledAt: _date(json['scheduledAt']) ?? DateTime.now(),
    mode: json['mode'] as String? ?? 'VIDEO',
    status: json['status'] as String? ?? 'SCHEDULED',
    panel: _names(json['interviewers']),
    scorecards: [for (final s in _maps(json['scorecards'])) Scorecard.fromJson(s)],
  );

  final String id;
  final int round;
  final String? title;
  final DateTime scheduledAt;
  final String mode;
  final String status;
  final List<String> panel;
  final List<Scorecard> scorecards;

  String get roundLabel => roundName(round, title);
}

/// A hiring-team note on the application: a note, a rating, or a stage change's note.
class BriefNote {
  const BriefNote({required this.id, required this.type, required this.at, this.note, this.rating, this.toStage, this.author});

  factory BriefNote.fromJson(Map<String, dynamic> json) => BriefNote(
    id: '${json['id']}',
    type: json['type'] as String? ?? 'NOTE',
    note: _text(json['note']),
    rating: (json['rating'] as num?)?.toInt(),
    toStage: json['toStage'] as String?,
    author: json['author'] is Map ? _name(_map(json['author'])) : null,
    at: _date(json['createdAt']) ?? DateTime.now(),
  );

  final String id;
  final String type;
  final String? note;
  final int? rating;
  final String? toStage;

  /// Null when the note's author has gone ("Hiring team").
  final String? author;
  final DateTime at;

  bool get isStageChange => type == 'STAGE_CHANGE' && toStage != null;
}

/// What "Submit scorecard" sends (`SubmitFeedbackDto`): an overall rating and a recommendation are required.
class ScorecardDraft {
  const ScorecardDraft({this.rating = 0, this.recommendation, this.strengths = '', this.concerns = ''});

  final int rating;
  final String? recommendation;
  final String strengths;
  final String concerns;

  bool get ready => rating >= 1 && rating <= 5 && recommendation != null;

  Map<String, dynamic> toJson() => {
    'overallRating': rating,
    'recommendation': recommendation,
    if (strengths.trim().isNotEmpty) 'strengths': strengths.trim(),
    if (concerns.trim().isNotEmpty) 'concerns': concerns.trim(),
  };
}

/// The recommendations in the website's order (`FeedbackRecommendation`).
const scorecardRecommendations = ['STRONG_YES', 'YES', 'NEUTRAL', 'NO', 'STRONG_NO'];

/// "Strong yes".
String recommendationWord(String r) => switch (r) {
  'STRONG_YES' => 'Strong yes',
  'YES' => 'Yes',
  'NEUTRAL' => 'Neutral',
  'NO' => 'No',
  'STRONG_NO' => 'Strong no',
  _ => r,
};

/// "Round 2" or "Round 2 · Operations panel".
String roundName(int round, String? title) => title == null ? 'Round $round' : 'Round $round · $title';

/// "Video", "In person", "Phone": the website's mode words on the interview page.
String interviewModeWord(String mode) => switch (mode) {
  'IN_PERSON' => 'In person',
  'PHONE' => 'Phone',
  _ => 'Video',
};

/// "Scheduled", "Done"… for an interview's status pill.
String interviewStatusWord(String s) => switch (s) {
  'SCHEDULED' => 'Scheduled',
  'RESCHEDULED' => 'Rescheduled',
  'COMPLETED' => 'Completed',
  'CANCELLED' => 'Cancelled',
  'NO_SHOW' => 'No show',
  _ => s,
};

Map<String, dynamic> _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> _maps(Object? v) =>
    (v as List? ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

String? _text(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

String? _name(Map<String, dynamic> p) {
  final n = '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim();
  return n.isEmpty ? null : n;
}

List<String> _names(Object? v) => [
  for (final p in _maps(v)) ?_name(p),
];
