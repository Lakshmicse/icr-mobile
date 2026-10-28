import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../messaging/messaging_models.dart';

/// One notification (`NotificationDto`), as the reader's language renders it.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.type,
    required this.createdAt,
    this.body,
    this.link,
    this.company,
    this.count = 1,
    this.readAt,
    this.actor,
    this.actorCompany,
  });

  final String id;
  final String title;
  final String? body;

  /// Decides the category, its icon and the switch that controls it.
  final String type;

  /// The root-relative page it opens (`notificationHref`); null for none.
  final String? link;

  /// The company the reader was told this as a member of, while they still are one.
  final ChatCompany? company;

  /// How many events the row stands for ("sent you 3 messages").
  final int count;
  final DateTime? readAt;
  final DateTime createdAt;

  /// The person behind it; null for a platform notice.
  final ChatPerson? actor;

  /// The company they wrote as (a company inbox): its logo stands in for their photo.
  final ChatCompany? actorCompany;

  /// Whose name the title carries in bold: the company when it wrote, else the person.
  String get actorName => actorCompany?.name ?? actor?.fullName ?? '';

  bool get unread => readAt == null;

  NotificationCategory get category => notificationCategoryOf(type);

  AppNotification read(DateTime at) => AppNotification(
    id: id,
    title: title,
    body: body,
    type: type,
    link: link,
    company: company,
    count: count,
    readAt: readAt ?? at,
    createdAt: createdAt,
    actor: actor,
    actorCompany: actorCompany,
  );

  AppNotification unreadAgain() => AppNotification(
    id: id,
    title: title,
    body: body,
    type: type,
    link: link,
    company: company,
    count: count,
    createdAt: createdAt,
    actor: actor,
    actorCompany: actorCompany,
  );
}

class NotificationPage {
  const NotificationPage({required this.items, required this.total, required this.hasMore});

  final List<AppNotification> items;
  final int total;
  final bool hasMore;
}

/// Who is reading: what tells a row about another company from one about theirs.
class NotificationViewer {
  const NotificationViewer({required this.id, this.activeCompanyId, this.companyCount = 0});

  final String id;

  /// The company they are acting for now; null when acting as themselves.
  final String? activeCompanyId;

  /// How many companies they belong to: a row names its company only for someone with more than one.
  final int companyCount;
}

/// A preference category (`NOTIFICATION_CATEGORIES`), with the icon and tint
/// a row of it wears (the website's `NotificationRow`).
class NotificationCategory {
  const NotificationCategory({
    required this.id,
    required this.label,
    required this.hint,
    required this.icon,
    required this.tint,
    required this.ink,
    this.locked = false,
  });

  final String id;
  final String label;
  final String hint;
  final IconData icon;
  final Color tint;
  final Color ink;

  /// Always sent on every channel: the switches are shown on and disabled.
  final bool locked;
}

/// In the order the preferences list them: the ones a member can change first.
const notificationCategories = <NotificationCategory>[
  NotificationCategory(
    id: 'messages',
    label: 'Messages',
    hint: 'New direct messages.',
    icon: LucideIcons.messageCircle,
    tint: Color(0xFFF0EAFB),
    ink: Color(0xFF5B3FA0),
  ),
  NotificationCategory(
    id: 'jobs',
    label: 'Jobs and applications',
    hint: 'Applications, interviews, offers, job alerts and profile views.',
    icon: LucideIcons.briefcase,
    tint: Color(0xFFFFF4D6),
    ink: Color(0xFF8A5A00),
  ),
  NotificationCategory(
    id: 'procurement',
    label: 'Requirements and bids',
    hint: 'Requirements, enquiries, bids and shortlists.',
    icon: LucideIcons.fileText,
    tint: Color(0xFFFDF0E4),
    ink: Color(0xFF9A4A00),
  ),
  NotificationCategory(
    id: 'mentoring',
    label: 'Mentoring',
    hint: 'Requests, sessions, reminders, tasks and feedback.',
    icon: LucideIcons.calendarDays,
    tint: Color(0xFFE8F1F8),
    ink: Color(0xFF1F4E79),
  ),
  NotificationCategory(
    id: 'learning',
    label: 'Courses and assignments',
    hint: 'Assignments, grades and course enquiries.',
    icon: LucideIcons.graduationCap,
    tint: Color(0xFFE6F4F1),
    ink: Color(0xFF0F5E52),
  ),
  NotificationCategory(
    id: 'events',
    label: 'Events',
    hint: 'Invitations, talk proposals and sponsorships.',
    icon: LucideIcons.calendar,
    tint: Color(0xFFFCEFF6),
    ink: Color(0xFF8E2463),
  ),
  NotificationCategory(
    id: 'community',
    label: 'Community and articles',
    hint: 'Replies to your posts, accepted answers, followers and articles.',
    icon: LucideIcons.messagesSquare,
    tint: Color(0xFFE8F1F8),
    ink: Color(0xFF1F4E79),
  ),
  NotificationCategory(
    id: 'verification',
    label: 'Verification and credentials',
    hint: 'Verification reviews, certificates and credentials.',
    icon: LucideIcons.badgeCheck,
    tint: Color(0xFFE4F6EC),
    ink: Color(0xFF1B6B3A),
  ),
  NotificationCategory(
    id: 'team',
    label: 'Team and company',
    hint: 'Invitations and requests to join a company team.',
    icon: LucideIcons.users,
    tint: Color(0xFFEEF0FB),
    ink: Color(0xFF3A3F9A),
  ),
  NotificationCategory(
    id: 'membership',
    label: 'Membership and rewards',
    hint: 'Renewal reminders, expiry, price changes and referral rewards.',
    icon: LucideIcons.idCard,
    tint: Color(0xFFFFF4D6),
    ink: Color(0xFF8A5A00),
  ),
  NotificationCategory(
    id: 'onboarding',
    label: 'Getting started',
    hint: 'Reminders to finish setting up your account.',
    icon: LucideIcons.rocket,
    tint: Color(0x1F1D63A3),
    ink: Color(0xFF1D63A3),
  ),
  NotificationCategory(
    id: 'general',
    label: 'Other updates',
    hint: 'Anything else ICR tells you about.',
    icon: LucideIcons.bell,
    tint: Color(0xFFEEF0F3),
    ink: Color(0xFF4A5563),
  ),
  NotificationCategory(
    id: 'payments',
    label: 'Payments and receipts',
    hint: 'Receipts, purchases, refunds and payment problems.',
    icon: LucideIcons.receipt,
    tint: Color(0xFFE4F6EC),
    ink: Color(0xFF1B6B3A),
    locked: true,
  ),
  NotificationCategory(
    id: 'support',
    label: 'Support requests',
    hint: 'Replies and updates on your support requests.',
    icon: LucideIcons.headset,
    tint: Color(0xFFFDE8EC),
    ink: Color(0xFF9B1C31),
    locked: true,
  ),
  NotificationCategory(
    id: 'security',
    label: 'Account and security',
    hint: 'Sign-in codes, password resets and email verification.',
    icon: LucideIcons.shield,
    tint: Color(0xFFFDE8EC),
    ink: Color(0xFF9B1C31),
    locked: true,
  ),
];

NotificationCategory categoryById(String id) =>
    notificationCategories.firstWhere((c) => c.id == id, orElse: () => notificationCategories[11]);

/// Which types each category covers: `foo_` is a prefix, `foo` the exact type.
const _categoryTypes = <String, List<String>>{
  'messages': ['message'],
  'jobs': [
    'application_',
    'interview_',
    'offer_',
    'job_',
    'invited_to_apply',
    'talent_search_',
    'profile_viewed',
    'employer_content_moderated',
  ],
  'procurement': ['bid_', 'rfq_', 'enquiry_', 'prequal_', 'shortlisted'],
  'mentoring': ['mentorship_', 'mentor_', 'group_session_'],
  'learning': ['course_', 'assignment_', 'learning_'],
  'events': ['event_'],
  'community': ['forum_', 'article_', 'member_followed', 'followed_member_article', 'document_'],
  'verification': [
    'verification_',
    'employer_verification_',
    'cert_',
    'credential_',
    'mentor_profile_',
    'mentor_document_',
    'mentor_approval_',
    'mentor_renewal_',
  ],
  'team': ['team_'],
  'membership': ['subscription_', 'account_manager_assigned', 'referral_reward'],
  'onboarding': ['onboarding_'],
  'payments': [
    'payment_failed',
    'invoice_issued',
    'subscription_activated',
    'subscription_renewed',
    'subscription_cancelled',
    'course_purchase_confirmed',
    'course_place_sold',
    'mentor_service_purchase_confirmed',
    'mentor_service_sold',
    'mentor_service_refunded',
    'mentor_plan_refunded',
    'mentor_plan_payment_lapsed',
    'event_ticket_confirmed',
  ],
  'support': ['support_'],
  'security': [
    'employer_verification_revoked',
    'employer_verification_reverify_requested',
    'employer_verification_reverify_reminder',
    'company_suspended',
    'company_unsuspended',
  ],
};

final _exact = <String, String>{
  for (final e in _categoryTypes.entries)
    for (final t in e.value)
      if (!t.endsWith('_')) t: e.key,
};

final _prefixes = [
  for (final e in _categoryTypes.entries)
    for (final t in e.value)
      if (t.endsWith('_')) (t, e.key),
]..sort((a, b) => b.$1.length.compareTo(a.$1.length));

/// The category a notification `type` belongs to (`notificationCategoryOf`):
/// an exact name beats a prefix, a longer prefix a shorter one; `general` otherwise.
NotificationCategory notificationCategoryOf(String? type) {
  final t = (type ?? '').toLowerCase();
  final exact = _exact[t];
  if (exact != null) return categoryById(exact);
  for (final (prefix, id) in _prefixes) {
    if (t.startsWith(prefix)) return categoryById(id);
  }
  return categoryById('general');
}

/// One row of the preferences: a category with what is on.
class NotificationPreference {
  const NotificationPreference({required this.category, required this.inApp, required this.email, this.locked = false});

  final NotificationCategory category;
  final bool inApp;
  final bool email;
  final bool locked;

  NotificationPreference copyWith({bool? inApp, bool? email}) => NotificationPreference(
    category: category,
    inApp: inApp ?? this.inApp,
    email: email ?? this.email,
    locked: locked,
  );
}
