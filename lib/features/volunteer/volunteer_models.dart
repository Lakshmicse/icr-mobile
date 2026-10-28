/// What the Get Involved screen draws: the website's `/get-involved` page (the volunteer opportunities
/// and benefits, ICR-authored copy) with the member's own CPD ledger from the portal's mentorship module
/// (`GET /mentorship/cpd/summary`, `/cpd/target`) and the application, which goes to the ICR team through
/// the website's contact endpoint (`POST /contact`, topic `VOLUNTEER`; the portal has no volunteer
/// endpoint of its own).
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../contact/contact_models.dart' show ContactLimits;

/// One way to give time to ICR (`VolunteerRole` on the website).
class VolunteerRole {
  const VolunteerRole({
    required this.key,
    required this.title,
    required this.description,
    required this.responsibilities,
    required this.commitment,
    required this.icon,
  });

  final String key;
  final String title;
  final String description;
  final List<String> responsibilities;

  /// "4–6 hours per month".
  final String commitment;

  /// The website's glyph name (a MUI icon); [volunteerIcon] draws it.
  final String icon;

  /// A role matches the search when its title, description or any responsibility does.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) ||
        description.toLowerCase().contains(q) ||
        responsibilities.any((r) => r.toLowerCase().contains(q));
  }
}

class VolunteerBenefit {
  const VolunteerBenefit({required this.title, required this.description, required this.icon});

  final String title;
  final String description;
  final String icon;
}

/// The website's glyph names as Lucide glyphs.
IconData volunteerIcon(String name) => switch (name) {
  'Groups' => LucideIcons.users,
  'EmojiEvents' => LucideIcons.trophy,
  'Diversity3' => LucideIcons.network,
  'Psychology' => LucideIcons.brain,
  'Handshake' => LucideIcons.handshake,
  'School' => LucideIcons.graduationCap,
  'RecordVoiceOver' => LucideIcons.mic,
  'EventNote' => LucideIcons.calendarDays,
  'Science' => LucideIcons.flaskConical,
  'Article' => LucideIcons.penLine,
  'FactCheck' => LucideIcons.clipboardCheck,
  'Star' => LucideIcons.star,
  'Balance' => LucideIcons.scale,
  'MenuBook' => LucideIcons.bookOpen,
  'Forum' => LucideIcons.messagesSquare,
  'SmartToy' => LucideIcons.bot,
  'EnergySavingsLeaf' => LucideIcons.leaf,
  'Business' => LucideIcons.building2,
  'WorkspacePremium' => LucideIcons.award,
  'TrendingUp' => LucideIcons.trendingUp,
  _ => LucideIcons.heartHandshake,
};

/// What volunteering earns, as the website words it ("Mentoring 12 credits"): ICR-authored copy, not
/// something the API holds. The member's real ledger is [CpdSummary].
const volunteerCreditCopy = <(String, String)>[
  ('Mentoring', '12 credits'),
  ('Volunteering', '10 credits'),
  ('Committee', '12 credits'),
];

// ---------------------------------------------------------------------------
// CPD
// ---------------------------------------------------------------------------

/// One row of the CPD ledger (`CpdEntryDto`).
class CpdEntry {
  const CpdEntry({required this.id, required this.hours, required this.source, this.description, this.awardedAt});

  final String id;
  final double hours;

  /// `MENTORING`, `EVENT`, `COURSE`, `CERTIFICATION` or `MANUAL`.
  final String source;
  final String? description;
  final DateTime? awardedAt;
}

/// The member's CPD as the API gives it (`GET /mentorship/cpd/summary` and `/cpd/target`).
class CpdSummary {
  const CpdSummary({
    required this.totalHours,
    required this.hoursThisYear,
    this.bySource = const [],
    this.recent = const [],
    this.year,
    this.targetHours,
    this.progress,
    this.targetIsDefault = true,
  });

  final double totalHours;
  final double hoursThisYear;

  /// Hours per source, most first.
  final List<({String source, double hours})> bySource;

  /// The latest ten entries, newest first.
  final List<CpdEntry> recent;

  /// The target's year and hours (the API falls back to its default of 20 and says so), and how far the
  /// year's hours are along it (0 to 1, null when the target is zero).
  final int? year;
  final double? targetHours;
  final double? progress;
  final bool targetIsDefault;

  static const sourceLabels = <String, String>{
    'MENTORING': 'Mentoring',
    'EVENT': 'Event',
    'COURSE': 'Course',
    'CERTIFICATION': 'Certification',
    'MANUAL': 'Manually recorded',
  };

  static String sourceLabel(String source) => sourceLabels[source] ?? source;

  /// 12 → "12", 8.5 → "8.5", 3.25 → "3.25".
  static String hoursLabel(double h) =>
      h == h.roundToDouble() ? h.round().toString() : h.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
}

// ---------------------------------------------------------------------------
// Applying
// ---------------------------------------------------------------------------

/// What a visit to the screen may carry in: a role to open the form on and a chapter to serve (from a
/// chapter's page, "Volunteer with this chapter").
class VolunteerIntent {
  const VolunteerIntent({this.roleKey, this.chapterName});

  final String? roleKey;
  final String? chapterName;

  /// What a chapter's page asks for: a committee seat at that chapter.
  const VolunteerIntent.chapter(String name) : roleKey = 'chapter-committee-member', chapterName = name;
}

/// A chapter the form offers ("Which chapter?").
class ChapterChoice {
  const ChapterChoice({required this.id, required this.name, this.city});

  final String id;
  final String name;
  final String? city;
}

/// An expression of interest, as the form fills it. The ICR team reads it as a contact message.
class VolunteerApplication {
  const VolunteerApplication({
    required this.name,
    required this.email,
    required this.message,
    this.phone,
    this.role,
    this.chapter,
  });

  final String name;
  final String email;
  final String? phone;
  final String message;
  final VolunteerRole? role;

  /// The chapter's name, when the person named one.
  final String? chapter;

  /// The text the API receives: what the person wants to give, where, then their own words. The
  /// message limit is the API's 4,000 characters (`ContactLimits.message`).
  String get composed {
    final lines = <String>[
      role == null ? 'Volunteer interest (no particular role)' : 'Volunteer application: ${role!.title}',
      if (role != null) 'Commitment: ${role!.commitment}',
      if (chapter != null && chapter!.trim().isNotEmpty) 'Chapter: ${chapter!.trim()}',
      '',
      message.trim(),
    ];
    return lines.join('\n');
  }

  /// How many of the message's characters the person may write: what is left of 4,000 after the lines
  /// above (the longest a role's header can be, plus a chapter name, is bounded here).
  static int messageRoom({VolunteerRole? role, String? chapter}) {
    final head = VolunteerApplication(name: '', email: '', message: '', role: role, chapter: chapter).composed.length;
    return ContactLimits.message - head;
  }
}
