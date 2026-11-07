import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_500.dart';

import '../../core/auth/session_user.dart';
import 'workspaces.dart';

/// The profile menu's rows for [user], as the owner's drawer design draws them (6 Nov 2026): Company, Marketplace,
/// Mentorship, Learning and Jobs, each opening its pages as tabs. What each row holds follows the website's sidebar for
/// the role (`personasFor` in `personas.ts`, overrides included; owner, 5 Nov 2026: "as per the user access"):
///
/// * **Company** — the company's own pages (My Company, its products, services, offices and certifications, Team, the
///   operations consoles) for the roles that run them, and "My companies" for every member, where they switch,
///   join or create one.
/// * **Marketplace** — the website's Buy, Sell and Find companies: My Requirements for a company that buys, Find Work
///   & Bid and Advertise for one that sells, and the public boards for everyone.
/// * **Mentorship**, **Learning** — the member's own.
/// * **Jobs** — the hiring team's pages for the roles that hire (Interviews alone for a hiring manager), the job board,
///   and the member's own career pages.
/// * **Account** (6 Nov 2026) — the member's membership pages, Refer & Earn and My companies, the website's
///   Account workspace.
///
/// The Company row is only for someone acting for a company; a member acting as themselves gets the website's
/// "Do more on ICR" doors instead ([startDoorsFor]).
///
/// ICR staff get their consoles instead of the member's rows (Engage, Learn, Content, Admin; the website leaves the
/// member's workspaces out for them). Only pages the app shows as its own screens are listed ([opens]): a page that
/// would hand the member to the website is left out (owner: no website redirects), and a row left with no page goes.
List<Workspace> workspacesFor(SessionUser user, {required bool Function(String path) opens}) {
  final role = user.role;
  final staff = isStaff(user);
  final out = <Workspace>[];

  void add(String key, String label, IconData icon, String blurb, Color tint, List<WorkspaceItem> items) {
    final seen = <String>{};
    final kept = [
      for (final i in items)
        if (opens(i.path) && seen.add(i.path)) i,
    ];
    if (kept.isEmpty) return;
    out.add(
      Workspace(
        key: key,
        label: label,
        icon: icon,
        blurb: blurb,
        sections: [WorkspaceSection(key: key, title: label, icon: icon, tint: tint, items: kept)],
      ),
    );
  }

  // What the member does with the company they act for: nothing when acting as themselves.
  final forCompany = user.companyId != null;
  final hires = forCompany && const ['RECRUITER', 'BRANCH_ADMIN', 'COMPANY_ADMIN'].contains(role);
  final sells = forCompany && const ['VENDOR', 'COMPANY_ADMIN'].contains(role);
  final buys = forCompany && const ['BUYER', 'VENDOR', 'COMPANY_ADMIN'].contains(role);
  final runsCompany =
      forCompany && const ['COMPANY_ADMIN', 'VENDOR', 'BUYER', 'RECRUITER', 'BRANCH_ADMIN'].contains(role);
  // Staff of a partner institute: anyone given a learning role there, and the admin of a company ICR approved as a
  // learning partner (`UserDto.learningPartner`; the API sends an admin no learning roles of their own).
  final partnerStaff =
      forCompany && (user.learningRoles.isNotEmpty || (role == 'COMPANY_ADMIN' && user.learningPartner));

  // The member's rows, as the owner's table lays them out (6 Nov 2026): what every user has, what a mentor adds,
  // and what a company and a partner institute add — each row only with what the role may do.
  if (!staff) {
    add('jobs', 'Jobs', LucideIcons500.briefcase, 'Your applications, saved jobs and the board', _orange, [
      // The company's hiring, for the roles that hire: post, edit and delete jobs; the team; projects.
      if (hires) ...const [
        WorkspaceItem('Post & manage jobs', Icons.work_outline, '/manage/jobs'),
        WorkspaceItem('Assign team & add members', Icons.groups_outlined, '/manage/team'),
        WorkspaceItem('Create a project', Icons.folder_special_outlined, '/manage/projects'),
      ],
      if (role == 'HIRING_MANAGER' && forCompany) _interviews,
      const WorkspaceItem('My applications', Icons.assignment_ind_outlined, '/career/applications'),
      const WorkspaceItem('My saved jobs', Icons.bookmark_border, '/career/saved'),
      const WorkspaceItem('Search jobs', Icons.search, '/jobs'),
    ]);

    add(
      'learning',
      'Learning',
      LucideIcons500.graduationCap,
      'Your courses, attempts and certificates',
      _violet,
      const [
        WorkspaceItem('My courses', Icons.school_outlined, '/learning?mine=1'),
        WorkspaceItem('My attempts', Icons.history, '/learning/attempts'),
        WorkspaceItem('My certificates', Icons.workspace_premium_outlined, '/learning/certificates'),
      ],
    );

    add('mentorship', 'Mentorship', LucideIcons500.users, 'Your sessions and mentors', _blue, [
      const WorkspaceItem('My sessions', Icons.event_note_outlined, '/mentorship/my?tab=calendar'),
      const WorkspaceItem('Search mentors', Icons.travel_explore, '/mentorship/mentors'),
      // A mentor's own desk and offerings; an applicant's profile while it is reviewed.
      if (actsAsMentor(user)) ...const [
        WorkspaceItem('Mentor dashboard', Icons.volunteer_activism_outlined, '/mentorship/mentor'),
        WorkspaceItem('Mentor offerings', Icons.storefront_outlined, '/mentorship/mentor?tab=services'),
      ] else if (user.mentorStatus != null)
        const WorkspaceItem('My mentor profile', Icons.how_to_reg_outlined, '/mentorship/become-a-mentor')
      // The website's sidebar offers "Become a mentor" to anyone who may apply (`canOfferToMentor`); someone
      // acting for a company has no "Do more on ICR" door for it, so it sits here for them.
      else if (forCompany && canOfferToMentor(user))
        const WorkspaceItem('Become a mentor', Icons.volunteer_activism_outlined, '/mentorship/become-a-mentor'),
    ]);

    add('marketplace', 'Marketplace', LucideIcons500.shoppingBag, 'Requirements and suppliers', _teal, const [
      WorkspaceItem('Post a requirement', Icons.request_quote_outlined, '/rfq/new'),
      WorkspaceItem('Search suppliers', Icons.storefront_outlined, '/vendors'),
    ]);

    // The Company row only for someone acting for a company they run (owner, 6 Nov 2026); a member acting as
    // themselves gets the doors a company opens instead ([startDoorsFor]), and reaches My companies under Account.
    if (runsCompany) {
      add('company', 'Company', LucideIcons500.building, 'Your company: team, catalogue, enquiries', _blue, [
        if (role == 'BUYER') _myOrganisation,
        const WorkspaceItem('Add members', Icons.group_add_outlined, '/manage/team'),
        if (role == 'RECRUITER' || role == 'BRANCH_ADMIN') _myLocations,
        if (sells) ...const [
          WorkspaceItem('Add services', Icons.handyman_outlined, '/manage/services'),
          WorkspaceItem('Add products', Icons.inventory_2_outlined, '/manage/products'),
        ],
        if (buys) const WorkspaceItem('View enquiries & RFQs', Icons.request_quote_outlined, '/manage/requirements'),
        if (sells) const WorkspaceItem('Bid for enquiries & RFQs', Icons.gavel_outlined, '/manage/bids'),
      ]);
    }

    if (partnerStaff) {
      add(
        'partner',
        'Partner Institute',
        LucideIcons500.school,
        'Courses, batches and the teaching team',
        _violet,
        const [
          WorkspaceItem('Publish a course', Icons.menu_book_outlined, '/admin/learning/courses'),
          WorkspaceItem('Publish a batch', Icons.event_outlined, '/admin/learning/batches'),
          // The enquiries from its course pages and its own page (the website's Enquiries console), native.
          WorkspaceItem('Enquiries', Icons.mark_email_unread_outlined, '/admin/learning/enquiries'),
          WorkspaceItem('Add a team member', Icons.group_add_outlined, '/manage/team'),
          // The team page's invite, opened with the learning role ticked (a trainer; a programme specialist is a
          // Course Admin on the website's list of learning roles).
          WorkspaceItem('Add a trainer', Icons.co_present_outlined, '/manage/team?invite=TRAINER'),
          WorkspaceItem(
            'Add a programme specialist',
            Icons.person_add_alt_outlined,
            '/manage/team?invite=COURSE_ADMIN',
          ),
        ],
      );
    }

    // Account among the main rows (owner, 6 Nov 2026): the member's membership pages and Refer & Earn as its tabs,
    // and where a member switches to, joins or creates a company, whichever hat they wear.
    add('account', 'Account', LucideIcons500.user, 'Your membership, Refer & Earn, and your companies', _blue, [
      ...myAccountSection.items,
      ...referralsSection.items,
      _yourCompanies,
    ]);
  }

  // ICR's own operator keeps the company and market consoles.
  if (role == 'SUPER_ADMIN') {
    add('company', 'Company', LucideIcons500.building, 'Companies, catalogues and operations', _blue, [
      ..._myBusiness,
      _team,
      ..._operations,
    ]);
    add('marketplace', 'Marketplace', LucideIcons500.shoppingBag, 'Requirements, suppliers and products', _teal, const [
      WorkspaceItem('My Requirements', Icons.request_quote_outlined, '/manage/requirements'),
      WorkspaceItem('Browse RFQs', Icons.request_quote_outlined, '/rfq'),
      WorkspaceItem('Tenders', Icons.gavel_outlined, '/tenders'),
      WorkspaceItem('Find Work & Bid', Icons.gavel_outlined, '/manage/bids'),
      WorkspaceItem('Advertise', Icons.campaign_outlined, '/advertise'),
      WorkspaceItem('Supplier Mart', Icons.storefront_outlined, '/vendors'),
      _companies,
      WorkspaceItem('Products', Icons.inventory_2_outlined, '/products'),
      WorkspaceItem('Categories', Icons.category_outlined, '/categories'),
    ]);
    add('jobs', 'Jobs', LucideIcons500.briefcase, 'Hiring across ICR', _orange, [
      ..._hiring,
      const WorkspaceItem('Jobs', Icons.work_outline, '/jobs'),
    ]);
  }

  // ICR's own consoles.
  if (role == 'SUPER_ADMIN') {
    add('engage', 'Engage', LucideIcons500.messagesSquare, 'Messages, community and mentorship', _violet, _engage);
  }
  if (staff) {
    add(
      'learn',
      'Learn',
      LucideIcons500.bookOpen,
      'Mock exams, assessments, courses and the question banks',
      _violet,
      role == 'PARTNER_ADMIN' ? _partnerLearning : _learningCenter,
    );
  }
  if (role == 'SUPER_ADMIN') {
    add('content', 'Content', LucideIcons500.fileText, 'Community, publishing and growth', _blue, _content);
    add('admin', 'Admin', LucideIcons500.shieldCheck, 'Access, trust queues and master data', _slate, _admin);
  }
  return out;
}

/// The menu's Account rows for [user]: My Account (the member's plans), Saved Items, Referrals and Settings. ICR staff
/// hold no membership, bookmarks or referrals, so theirs is Settings alone.
class AccountMenu {
  const AccountMenu({this.myAccount = myAccountSection, this.savedItems = true, this.referrals = referralsSection});

  const AccountMenu.staff() : myAccount = null, savedItems = false, referrals = null;

  /// Null: no My Account row.
  final WorkspaceSection? myAccount;
  final bool savedItems;

  /// Null: no Referrals row.
  final WorkspaceSection? referrals;
}

AccountMenu accountMenuFor(SessionUser user) => isStaff(user) ? const AccountMenu.staff() : const AccountMenu();

/// A door on the menu for a person acting as themselves: what they can become on ICR, and how.
class StartDoor {
  const StartDoor(this.key, this.label, this.caption, this.icon, this.path);

  final String key;
  final String label;

  /// One line under the name, as the website's nudge explains each door.
  final String caption;
  final IconData icon;

  /// The website page the door opens (the app's own screen for it).
  final String path;
}

/// The website's "Do more on ICR" (`DIRECTION_INTENTS`, `ExploreServicesCard`) as menu rows for a member acting
/// as themselves — buying, selling and hiring all begin with a company page, so those doors open the create-company
/// screen as the website's `/account/companies/new?role=` links do — plus becoming a mentor for someone who may
/// (`canOfferToMentor`). Nothing for a member acting for a company (its workspace is their doors) or for ICR staff:
/// the website's `isUndecidedPerson` (`!PLATFORM_ROLES.includes(role) && !companyId`).
///
/// The captions are the website's own words (`WelcomeCard`'s intent bodies, `home.WelcomeCard.intents.*`). Its other
/// three doors — Find work, Learn and get certified, Find a mentor — are the menu's Jobs, Learning and Mentorship
/// rows, which every member has above these, so they are not listed twice. "Create a company" is the app's own first
/// door (the website's intents say the same: buying, selling and hiring all begin with a company page); "Become a
/// mentor" is the website's mentorship card (`SidebarMentorCard`, "Share your expertise with the next generation."),
/// which it shows only to a member who may apply. Being a recruiter, hiring manager, office admin or partner
/// administrator is no door: those roles come only from a company admin's team invite (`INVITE_ONLY_ROLES`,
/// `INVITABLE_ROLES`), so nothing here offers to register for one.
List<StartDoor> startDoorsFor(SessionUser user) {
  if (isStaff(user) || user.companyId != null) return const [];
  return [
    const StartDoor(
      'create-company',
      'Create a company',
      'Buying, selling and hiring start with a company page',
      LucideIcons500.building2,
      '/account/companies/new',
    ),
    const StartDoor(
      'hire',
      'Hire people',
      'Create your company page, then post a job.',
      LucideIcons500.userPlus,
      '/account/companies/new?role=COMPANY_ADMIN',
    ),
    const StartDoor(
      'sell',
      'Sell to FM buyers',
      'Create your company page, then list your services.',
      LucideIcons500.store,
      '/account/companies/new?role=VENDOR',
    ),
    const StartDoor(
      'source',
      'Find suppliers',
      'Search verified suppliers and ask for quotes.',
      LucideIcons500.search,
      '/vendors',
    ),
    if (canOfferToMentor(user))
      const StartDoor(
        'mentor',
        'Become a mentor',
        'Share your expertise with the next generation.',
        LucideIcons500.handshake,
        '/mentorship/become-a-mentor',
      ),
  ];
}

// --- The website's rows (`NAV_ITEM` in `nav.ts`) ---------------------------------------------------------------------

const _blue = Color(0xFF1D63A3);
const _teal = Color(0xFF0E7490);
const _violet = Color(0xFF7C3AED);
const _slate = Color(0xFF475569);
const _orange = Color(0xFFEA580C);

const _myLocations = WorkspaceItem('My Locations', Icons.place_outlined, '/manage/locations');
const _team = WorkspaceItem('Team', Icons.groups_outlined, '/manage/team');
const _companies = WorkspaceItem('Companies', Icons.business_outlined, '/companies');
const _yourCompanies = WorkspaceItem('My companies', Icons.apartment_outlined, '/account/companies');
const _myOrganisation = WorkspaceItem('My Organization', Icons.business_outlined, '/company');
const _interviews = WorkspaceItem('Interviews', Icons.event_note_outlined, '/manage/interviews');

const _myBusiness = [
  WorkspaceItem('My Company', Icons.storefront_outlined, '/company'),
  WorkspaceItem('My Products', Icons.inventory_2_outlined, '/manage/products'),
  WorkspaceItem('My Services', Icons.handyman_outlined, '/manage/services'),
  _myLocations,
  WorkspaceItem('My Certifications', Icons.workspace_premium_outlined, '/manage/certifications'),
];

const _operations = [
  WorkspaceItem('CRM', Icons.contact_phone_outlined, '/crm'),
  WorkspaceItem('Payments', Icons.payments_outlined, '/payments'),
  WorkspaceItem('Marketing', Icons.campaign_outlined, '/marketing'),
  WorkspaceItem('CMS', Icons.article_outlined, '/cms'),
];

const _hiring = [
  WorkspaceItem('My Jobs', Icons.work_outline, '/manage/jobs'),
  WorkspaceItem('Source Candidates', Icons.person_search_outlined, '/talent'),
  WorkspaceItem('Projects', Icons.folder_special_outlined, '/manage/projects'),
  _interviews,
  WorkspaceItem('Hiring Reports', Icons.insights_outlined, '/manage/reports'),
];

const _engage = [
  WorkspaceItem('Messages', Icons.chat_outlined, '/messaging'),
  WorkspaceItem('Community', Icons.forum_outlined, '/community'),
  WorkspaceItem('Chapters', Icons.groups_outlined, '/chapters'),
  WorkspaceItem('Councils', Icons.diversity_3_outlined, '/councils'),
  WorkspaceItem('Events', Icons.event_note_outlined, '/events'),
  WorkspaceItem('Mentor directory', Icons.travel_explore, '/mentorship/mentors'),
  WorkspaceItem('Reviews', Icons.star_outline, '/reviews'),
];

/// The Learning Center console's sections (`LEARNING_SECTIONS`), then its public pages.
const _learningCenter = [
  WorkspaceItem('Mock exams', Icons.assignment_outlined, '/admin/learning/mock-exams'),
  WorkspaceItem('Assessments', Icons.quiz_outlined, '/admin/learning/assessments'),
  WorkspaceItem('ICR courses', Icons.school_outlined, '/admin/learning/icr-courses'),
  WorkspaceItem('Batches', Icons.co_present_outlined, '/admin/learning/batches'),
  WorkspaceItem('Team', Icons.groups_outlined, '/admin/learning/team'),
  WorkspaceItem('Enrolments', Icons.how_to_reg_outlined, '/admin/learning/enrolments'),
  WorkspaceItem('Enquiries', Icons.mark_email_unread_outlined, '/admin/learning/enquiries'),
  WorkspaceItem('Flash cards', Icons.style_outlined, '/admin/learning/flash-cards'),
  WorkspaceItem('Knowledge Center', Icons.functions, '/admin/learning/knowledge-center'),
  WorkspaceItem('Attempts', Icons.history, '/admin/learning/attempts'),
  WorkspaceItem('Learner reviews', Icons.reviews_outlined, '/admin/learning/learner-reviews'),
  WorkspaceItem('Course review', Icons.fact_check_outlined, '/admin/learning/course-review'),
  WorkspaceItem('Learning', Icons.menu_book_outlined, '/learning'),
  WorkspaceItem('Get Involved', Icons.emoji_events_outlined, '/get-involved'),
];

/// A partner institute's own pages.
const _partnerLearning = [
  WorkspaceItem('Courses', Icons.co_present_outlined, '/admin/learning'),
  WorkspaceItem('Batches', Icons.co_present_outlined, '/admin/learning/batches'),
  WorkspaceItem('Team', Icons.groups_outlined, '/admin/learning/team'),
  WorkspaceItem('Enrolments', Icons.how_to_reg_outlined, '/admin/learning/enrolments'),
  WorkspaceItem('Enquiries', Icons.mark_email_unread_outlined, '/admin/learning/enquiries'),
];

const _content = [
  WorkspaceItem('Community Manager', Icons.diversity_3_outlined, '/admin/community'),
  WorkspaceItem('Forum Moderation', Icons.gavel_outlined, '/admin/forum'),
  WorkspaceItem('Mentorship', Icons.handshake_outlined, '/admin/mentorship'),
  WorkspaceItem('Blog Manager', Icons.article_outlined, '/admin/blogs'),
  WorkspaceItem('CMS', Icons.article_outlined, '/cms'),
  WorkspaceItem('Contact Inbox', Icons.mark_email_unread_outlined, '/admin/contact'),
  WorkspaceItem('Homepage Content', Icons.web_outlined, '/admin/homepage'),
  WorkspaceItem('Ads & Featured', Icons.star_outline, '/admin/promotions'),
  WorkspaceItem('Marketing', Icons.campaign_outlined, '/marketing'),
];

const _admin = [
  WorkspaceItem('Admin Portal', Icons.admin_panel_settings_outlined, '/admin'),
  WorkspaceItem('Users', Icons.groups_outlined, '/admin/users'),
  WorkspaceItem('Companies', Icons.business_outlined, '/admin/companies'),
  WorkspaceItem('Roles & Permissions', Icons.admin_panel_settings_outlined, '/admin/roles'),
  WorkspaceItem('Support Desk', Icons.headset_mic_outlined, '/admin/support'),
  WorkspaceItem('Verification', Icons.verified_user_outlined, '/admin/verification'),
  WorkspaceItem('Moderation', Icons.gavel_outlined, '/admin/moderation'),
  WorkspaceItem('Job review', Icons.work_outline, '/admin/jobs/review'),
  WorkspaceItem('Subscriptions', Icons.workspace_premium_outlined, '/admin/subscriptions'),
  WorkspaceItem('Discount codes', Icons.local_offer_outlined, '/admin/coupons'),
  WorkspaceItem('Referrals', Icons.card_giftcard_outlined, '/admin/referrals'),
  WorkspaceItem('Credits', Icons.toll_outlined, '/admin/credits'),
  WorkspaceItem('Onboarding', Icons.rocket_launch_outlined, '/admin/onboarding'),
  WorkspaceItem('Categories', Icons.category_outlined, '/admin/categories'),
  WorkspaceItem('Locations', Icons.place_outlined, '/admin/locations'),
  WorkspaceItem('Certifications', Icons.workspace_premium_outlined, '/admin/certifications'),
];
