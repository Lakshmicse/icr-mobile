import 'package:flutter/material.dart';

import '../../core/auth/session_user.dart';

/// One page of a menu row: a tab of its screen. [path] is the website's page (`/mentorship/my?tab=calendar`), which is
/// also what the app opens it as.
class WorkspaceItem {
  const WorkspaceItem(this.label, this.icon, this.path);

  final String label;
  final IconData icon;
  final String path;
}

/// What a menu row opens: [WorkspaceScreen] under [title], with [items] as its tabs.
class WorkspaceSection {
  const WorkspaceSection({
    required this.key,
    required this.title,
    required this.icon,
    required this.tint,
    required this.items,
  });

  final String key;
  final String title;
  final IconData icon;

  /// The section's colour, where a screen draws it.
  final Color tint;
  final List<WorkspaceItem> items;
}

/// A row of the profile menu (Company, Marketplace, Mentorship, Learning, Jobs…): its icon and name, opening its
/// [sections] — one, whose pages are tabs.
class Workspace {
  const Workspace({
    required this.key,
    required this.label,
    required this.icon,
    required this.blurb,
    required this.sections,
  });

  final String key;
  final String label;
  final IconData icon;
  final String blurb;
  final List<WorkspaceSection> sections;
}

/// The website's `PLATFORM_ROLES`: ICR's own staff, who hold no membership, take no mentoring and join no company.
const platformRoles = ['SUPER_ADMIN', 'LEARNING_ADMIN', 'PARTNER_ADMIN'];

bool isStaff(SessionUser user) => platformRoles.contains(user.role);

/// The website's `actsAsMentor`: a listed mentor (approved, or paused), or one with a live mentee whatever their
/// profile's state.
bool actsAsMentor(SessionUser user) =>
    user.mentorStatus == 'APPROVED' || user.mentorStatus == 'PAUSED' || user.mentorsSomeone;

/// The website's `hasMentorApplication`: a mentor profile in draft, under review or turned down.
bool hasMentorApplication(SessionUser user) =>
    user.mentorStatus == 'DRAFT' || user.mentorStatus == 'PENDING' || user.mentorStatus == 'REJECTED';

const _blue = Color(0xFF1D63A3);

/// The member's mentoring (the website's `MENTORSHIP_ITEMS`), then — for someone who mentors — the website's Mentor
/// workspace (`MENTOR_SECTION`: dashboard, Offerings, Engagements, Availability), or their mentor profile while it
/// is an application. Role-led (owner, 6 Nov 2026: "Mentorship should include Offerings and the other role-related
/// options, as per the role").
WorkspaceSection mentorshipSection(SessionUser user) => WorkspaceSection(
  key: 'mentorship',
  title: 'Mentorship',
  icon: Icons.handshake_outlined,
  tint: _blue,
  items: [
    const WorkspaceItem('My mentoring', Icons.handshake_outlined, '/mentorship/my'),
    const WorkspaceItem('Sessions', Icons.event_note_outlined, '/mentorship/my?tab=calendar'),
    const WorkspaceItem('Goals', Icons.flag_outlined, '/mentorship/my?tab=goals'),
    const WorkspaceItem('Find a mentor', Icons.travel_explore, '/mentorship/mentors'),
    const WorkspaceItem('Group sessions', Icons.co_present_outlined, '/mentorship/groups'),
    const WorkspaceItem('Cohort programmes', Icons.hub_outlined, '/mentorship/programmes'),
    const WorkspaceItem('CPD record', Icons.fact_check_outlined, '/mentorship/cpd'),
    if (actsAsMentor(user)) ...const [
      WorkspaceItem('Mentor dashboard', Icons.volunteer_activism_outlined, '/mentorship/mentor'),
      WorkspaceItem('Offerings', Icons.storefront_outlined, '/mentorship/mentor?tab=services'),
      WorkspaceItem('Engagements', Icons.assignment_outlined, '/mentorship/mentor?tab=work'),
      WorkspaceItem('Availability', Icons.event_available_outlined, '/mentorship/mentor?tab=settings'),
    ] else if (user.mentorStatus != null)
      const WorkspaceItem('My mentor profile', Icons.how_to_reg_outlined, '/mentorship/become-a-mentor'),
  ],
);

/// The learning centre's member pages: the hub, then the member's own (My courses, My attempts, Certificates &
/// Badges — owner, 6 Nov 2026), then the catalogues.
const learningSection = WorkspaceSection(
  key: 'learning',
  title: 'Learning',
  icon: Icons.menu_book_outlined,
  tint: Color(0xFF7C3AED),
  items: [
    WorkspaceItem('Learning', Icons.menu_book_outlined, '/learning'),
    // The hub with its "My courses" chip on: what the member holds a place on or opened.
    WorkspaceItem('My courses', Icons.school_outlined, '/learning?mine=1'),
    WorkspaceItem('My attempts', Icons.history, '/learning/attempts'),
    WorkspaceItem('Certificates & Badges', Icons.workspace_premium_outlined, '/learning/certificates'),
    WorkspaceItem('Assess your knowledge', Icons.quiz_outlined, '/learning/assessment'),
    WorkspaceItem('Mock exams', Icons.assignment_outlined, '/learning/mock-tests'),
    WorkspaceItem('Flash cards', Icons.style_outlined, '/learning/flash-cards'),
    WorkspaceItem('Knowledge Center', Icons.functions, '/learning/formulas'),
  ],
);

/// "My Account": the member's plans, the Membership half of the website's Account workspace.
const myAccountSection = WorkspaceSection(
  key: 'my-account',
  title: 'My Account',
  icon: Icons.workspace_premium_outlined,
  tint: _blue,
  items: [
    WorkspaceItem('Membership', Icons.workspace_premium_outlined, '/membership'),
    WorkspaceItem('My membership', Icons.description_outlined, '/membership/history'),
    WorkspaceItem('What my plans include', Icons.checklist_rtl, '/membership/benefits'),
  ],
);

/// "Referrals": the Referrals half of the website's Account workspace.
const referralsSection = WorkspaceSection(
  key: 'referrals',
  title: 'Referrals',
  icon: Icons.card_giftcard_outlined,
  tint: Color(0xFF059669),
  items: [
    WorkspaceItem('Refer a friend', Icons.card_giftcard_outlined, '/refer'),
    WorkspaceItem('Credits & redemptions', Icons.savings_outlined, '/refer/credits'),
  ],
);

/// The website's "My career" pages (its Career workspace), under the Jobs row; Learning has its own row.
const careerItems = [
  WorkspaceItem('Career Hub', Icons.home_outlined, '/career'),
  WorkspaceItem('My Applications', Icons.assignment_ind_outlined, '/career/applications'),
  WorkspaceItem('Invitations', Icons.mark_email_unread_outlined, '/career/invitations'),
  WorkspaceItem('Saved Jobs', Icons.bookmark_border, '/career/saved'),
  WorkspaceItem('My Resume', Icons.description_outlined, '/profile?tab=profile'),
  WorkspaceItem('Career Plans', Icons.workspace_premium_outlined, '/career/plans'),
];
