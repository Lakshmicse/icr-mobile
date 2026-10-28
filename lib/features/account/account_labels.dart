/// The words the website shows for the API's codes, copied from `@icr/shared`
/// (`USER_ROLE_LABELS`, `JOB_INDUSTRIES`, `EMPLOYMENT_TYPE_LABELS`,
/// `CAREER_BREAK_REASON_LABELS`, `COMPANY_SIZES`, the organisation types) and
/// the notification preferences' rows (`messages/en/notifications.json`).
library;

const userRoleLabels = {
  'SUPER_ADMIN': 'Super Admin',
  'COMPANY_ADMIN': 'Company Admin',
  'BRANCH_ADMIN': 'Office Admin',
  'VENDOR': 'Seller',
  'BUYER': 'Buyer',
  'PROFESSIONAL': 'Professional',
  'RECRUITER': 'Recruiter',
  'HIRING_MANAGER': 'Hiring Manager',
  'LEARNING_ADMIN': 'Learning Administrator',
  'PARTNER_ADMIN': 'Partner Administrator',
  'GUEST': 'Guest',
};

String roleLabel(String? role) => userRoleLabels[role] ?? (role ?? '');

/// `JOB_INDUSTRIES`, in the website's order.
const industries = <(String, String)>[
  ('CRE_SERVICES', 'Commercial real estate services'),
  ('FM_SERVICES', 'Facility management services'),
  ('CORPORATE_OCCUPIER', 'Corporate occupier'),
  ('DEVELOPER', 'Developer & builder'),
  ('REIT_INVESTOR', 'REIT & investor'),
  ('COWORKING', 'Coworking & flexible space'),
  ('RETAIL_MALL', 'Retail & malls'),
  ('HOSPITALITY', 'Hospitality'),
  ('HEALTHCARE', 'Healthcare'),
  ('DATA_CENTRE', 'Data centres'),
  ('MANUFACTURING', 'Manufacturing & industrial'),
  ('LOGISTICS', 'Logistics & warehousing'),
  ('EDUCATION', 'Education'),
  ('BFSI', 'Banking & financial services'),
  ('TECHNOLOGY', 'Technology'),
  ('PUBLIC_SECTOR', 'Government & public sector'),
];

String? industryLabel(String? key) {
  for (final (k, label) in industries) {
    if (k == key) return label;
  }
  return key;
}

/// `COMPANY_SIZES`, written with an en dash as the website shows them.
const companySizes = <(String, String)>[
  ('1-10', '1–10'),
  ('11-50', '11–50'),
  ('51-200', '51–200'),
  ('201-500', '201–500'),
  ('500+', '500+'),
];

/// `LegalStructure`: the organisation types.
const legalStructures = <(String, String)>[
  ('PRIVATE_LIMITED', 'Private limited'),
  ('PUBLIC_LIMITED', 'Public limited'),
  ('LLP', 'LLP'),
  ('PARTNERSHIP', 'Partnership'),
  ('SOLE_PROPRIETORSHIP', 'Sole proprietorship'),
  ('GOVERNMENT', 'Government / PSU'),
  ('TRUST_NGO', 'Trust / NGO / Society'),
  ('OTHER', 'Other'),
];

const employmentTypes = <(String, String)>[
  ('FULL_TIME', 'Full-time'),
  ('PART_TIME', 'Part-time'),
  ('CONTRACT', 'Contract'),
  ('INTERNSHIP', 'Internship'),
  ('TEMPORARY', 'Temporary'),
  ('FREELANCE', 'Freelance / Consultant'),
  ('VOLUNTEER', 'Volunteer'),
  ('OTHER', 'Other'),
];

String? employmentTypeLabel(String? key) {
  for (final (k, label) in employmentTypes) {
    if (k == key) return label;
  }
  return null;
}

const careerBreakReasons = <(String, String)>[
  ('CAREGIVING', 'Caring for family'),
  ('PARENTING', 'Raising children'),
  ('HEALTH', 'Health and recovery'),
  ('BEREAVEMENT', 'Bereavement'),
  ('RELOCATION', 'Moving cities'),
  ('TRAVEL', 'Travel'),
  ('STUDY', 'Study or upskilling'),
  ('CAREER_CHANGE', 'Changing careers'),
  ('REDUNDANCY', 'Role made redundant'),
  ('VOLUNTEERING', 'Volunteering'),
  ('PERSONAL_PROJECT', 'Personal project'),
  ('GAP_YEAR', 'Gap year'),
  ('RETIREMENT', 'Retirement'),
  ('OTHER', 'Other'),
];

String careerBreakLabel(String? key) {
  for (final (k, label) in careerBreakReasons) {
    if (k == key) return label;
  }
  return key ?? 'Career break';
}

/// The notification preferences' rows: label and hint, by category id.
const notificationCategories = <String, (String, String)>{
  'messages': ('Messages', 'New direct messages.'),
  'jobs': ('Jobs and applications', 'Applications, interviews, offers, job alerts and profile views.'),
  'procurement': ('Requirements and bids', 'Requirements, enquiries, bids and shortlists.'),
  'mentoring': ('Mentoring', 'Requests, sessions, reminders, tasks and feedback.'),
  'learning': ('Courses and assignments', 'Assignments, grades and course enquiries.'),
  'events': ('Events', 'Invitations, talk proposals and sponsorships.'),
  'community': ('Community and articles', 'Replies to your posts, accepted answers, followers and articles.'),
  'verification': ('Verification and credentials', 'Verification reviews, certificates and credentials.'),
  'team': ('Team and company', 'Invitations and requests to join a company team.'),
  'membership': ('Membership and rewards', 'Renewal reminders, expiry, price changes and referral rewards.'),
  'onboarding': ('Getting started', 'Reminders to finish setting up your account.'),
  'general': ('Other updates', 'Anything else ICR tells you about.'),
  'payments': ('Payments and receipts', 'Receipts, purchases, refunds and payment problems.'),
  'support': ('Support requests', 'Replies and updates on your support requests.'),
  'security': ('Account and security', 'Sign-in codes, password resets and email verification.'),
};

/// Languages the website suggests for a profile (`LANGUAGE_SUGGESTIONS`).
const languageSuggestions = [
  'English',
  'Hindi',
  'Bengali',
  'Marathi',
  'Telugu',
  'Tamil',
  'Gujarati',
  'Kannada',
  'Malayalam',
  'Punjabi',
  'Odia',
  'Urdu',
  'Assamese',
  'Konkani',
];

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String monthName(int month) => _months[(month - 1).clamp(0, 11)];

/// "Mar 2019" or "2019".
String careerDate(int year, int? month) => month == null ? '$year' : '${monthName(month)} $year';

/// "Mar 2019 — Present · 3 yrs 2 mos", as the website's role rows read.
String careerRange({
  required int startYear,
  int? startMonth,
  int? endYear,
  int? endMonth,
  required bool current,
  DateTime? now,
}) {
  final start = careerDate(startYear, startMonth);
  final end = current || endYear == null ? 'Present' : careerDate(endYear, endMonth);
  final today = now ?? DateTime.now();
  final toYear = current || endYear == null ? today.year : endYear;
  final toMonth = current || endYear == null ? today.month : (endMonth ?? 12);
  final months = (toYear * 12 + toMonth) - (startYear * 12 + (startMonth ?? 1));
  return '$start — $end · ${careerDuration(months)}';
}

/// "3 yrs 2 mos", "1 yr", "Less than a month".
String careerDuration(int months) {
  if (months < 1) return 'Less than a month';
  final y = months ~/ 12;
  final m = months % 12;
  final parts = [
    if (y > 0) '$y ${y == 1 ? 'yr' : 'yrs'}',
    if (m > 0) '$m ${m == 1 ? 'mo' : 'mos'}',
  ];
  return parts.join(' ');
}

/// "Sep 2026" from an ISO date.
String monthYear(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  return d == null ? '' : '${monthName(d.month)} ${d.year}';
}

/// The skills the website's sign-up offers (`ONBOARDING_SKILL_GROUPS`); anything else may be typed.
const skillSuggestions = [
  'HVAC',
  'Electrical systems',
  'Fire & life safety',
  'Preventive maintenance',
  'BMS / building automation',
  'Lease administration',
  'Budgeting & cost control',
  'Vendor management',
  'SLA & KPI management',
  'Space planning',
  'Team leadership',
  'Energy management',
  'Sustainability & green buildings',
  'EHS compliance',
  'Client relationship management',
];

/// The ready-made covers' ids, in the order the website offers them.
const coverIds = ['blueprint', 'skyline', 'campus', 'brand', 'teal', 'waves', 'marble', 'ink'];

/// The most rows each career list holds (`MAX_EXPERIENCE_ROWS` and its kin).
const maxExperienceRows = 20;
const maxEducationRows = 10;
const maxCareerBreakRows = 10;

/// `PROFILE_LIMITS`: what the API refuses beyond these.
const maxSkills = 50;
const maxSkillLength = 80;
const maxLanguages = 8;
const maxLanguageLength = 40;
const maxAboutLength = 2000;
