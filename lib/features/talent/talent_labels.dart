/// The words the talent search shares with the website: the shared label tables (`SENIORITY_LABELS`,
/// `WORK_MODE_LABELS`, `EMPLOYMENT_TYPE_LABELS`, `SHIFT_PREFERENCE_LABELS`, `NOTICE_PERIOD_LABELS`,
/// `NEXT_ROLE_STATUS_LABELS`, `JOB_INDUSTRIES`, `JOB_FUNCTIONS`), the filter rail's option words, and the money and
/// day formats the candidate cards print. English, as the API's own sentences arrive.
library;

/// `SENIORITY_LABELS`, in the website's order.
const seniorityLabels = <String, String>{
  'INTERN': 'Intern',
  'JUNIOR': 'Junior',
  'MID': 'Mid-Level',
  'SENIOR': 'Senior',
  'LEAD': 'Lead',
  'DIRECTOR': 'Director',
  'EXECUTIVE': 'Executive',
};

/// `WORK_MODE_LABELS`.
const workModeLabels = <String, String>{'ONSITE': 'On-Site', 'REMOTE': 'Remote', 'HYBRID': 'Hybrid'};

/// `EMPLOYMENT_TYPE_LABELS`.
const employmentTypeLabels = <String, String>{
  'FULL_TIME': 'Full-Time',
  'PART_TIME': 'Part-Time',
  'CONTRACT': 'Contract',
  'INTERNSHIP': 'Internship',
  'TEMPORARY': 'Temporary',
  'FREELANCE': 'Freelance / Consultant',
  'VOLUNTEER': 'Volunteer',
  'OTHER': 'Other',
};

/// `SHIFT_PREFERENCE_LABELS`. The filter rail offers every shift but FLEXIBLE (which fits any).
const shiftLabels = <String, String>{
  'DAY': 'Day Shift',
  'NIGHT': 'Night Shift',
  'ROTATIONAL': 'Rotational Shifts',
  'FLEXIBLE': 'Flexible Shifts',
};

/// `NOTICE_PERIOD_LABELS`: how a candidate's "can start" reads.
const noticePeriodLabels = <String, String>{
  '0': 'Immediately',
  '15': 'Within 15 days',
  '30': 'Within 30 days',
  '60': 'Within 60 days',
  '90': 'Within 90 days',
};

/// `NEXT_ROLE_STATUS_LABELS`.
const nextRoleStatusLabels = <String, String>{
  'READY_NOW': 'Ready to start now',
  'OPEN_TO_OFFERS': 'Open to the right offer',
};

/// The filter rail's notice-period buckets (`hiring.TalentFilterRail.notice.<days>`).
const noticeFilterOptions = <(int, String)>[
  (0, 'Immediate'),
  (15, '15 Days or Less'),
  (30, '30 Days or Less'),
  (60, '60 Days or Less'),
  (90, '90 Days or Less'),
];

/// The filter rail's "Profile updated" windows (`recency.<days>`).
const recencyFilterOptions = <(int, String)>[(7, 'Last 7 Days'), (30, 'Last 30 Days'), (90, 'Last 3 Months')];

/// One key and its words, from `GET /masters` or the shared seed list.
class MasterOption {
  const MasterOption(this.key, this.label);

  final String key;
  final String label;
}

/// `JOB_INDUSTRIES`, the seed list the website falls back to while `GET /masters` is unread.
const seedIndustries = <MasterOption>[
  MasterOption('CRE_SERVICES', 'Commercial real estate services'),
  MasterOption('FM_SERVICES', 'Facility management services'),
  MasterOption('CORPORATE_OCCUPIER', 'Corporate occupier'),
  MasterOption('DEVELOPER', 'Developer & builder'),
  MasterOption('REIT_INVESTOR', 'REIT & investor'),
  MasterOption('COWORKING', 'Coworking & flexible space'),
  MasterOption('RETAIL_MALL', 'Retail & malls'),
  MasterOption('HOSPITALITY', 'Hospitality'),
  MasterOption('HEALTHCARE', 'Healthcare'),
  MasterOption('DATA_CENTRE', 'Data centres'),
  MasterOption('MANUFACTURING', 'Manufacturing & industrial'),
  MasterOption('LOGISTICS', 'Logistics & warehousing'),
  MasterOption('EDUCATION', 'Education'),
  MasterOption('BFSI', 'Banking & financial services'),
  MasterOption('TECHNOLOGY', 'Technology'),
  MasterOption('PUBLIC_SECTOR', 'Government & public sector'),
];

/// `JOB_FUNCTIONS`.
const seedJobFunctions = <MasterOption>[
  MasterOption('FACILITIES_OPS', 'Facilities operations'),
  MasterOption('HARD_SERVICES', 'Hard services / engineering'),
  MasterOption('SOFT_SERVICES', 'Soft services'),
  MasterOption('PROJECT_MGMT', 'Project & fit-out management'),
  MasterOption('TRANSACTIONS', 'Transactions & leasing'),
  MasterOption('PORTFOLIO_ASSET', 'Portfolio & asset management'),
  MasterOption('WORKPLACE_EXP', 'Workplace experience'),
  MasterOption('HSE_COMPLIANCE', 'Health, safety & compliance'),
  MasterOption('ENERGY_SUSTAIN', 'Energy & sustainability'),
  MasterOption('PROCUREMENT', 'Procurement & vendor management'),
  MasterOption('FINANCE_LEASE_ADMIN', 'Finance & lease administration'),
  MasterOption('TECH_SYSTEMS', 'Technology & building systems'),
  MasterOption('SECURITY', 'Security'),
  MasterOption('HR_ADMIN', 'People & administration'),
  MasterOption('SALES_BD', 'Sales & business development'),
];

/// The industries and job functions a picker offers (`GET /masters`, else the seed lists).
class TalentMasters {
  const TalentMasters({this.industries = seedIndustries, this.functions = seedJobFunctions});

  final List<MasterOption> industries;
  final List<MasterOption> functions;

  String industryLabel(String key) => _label(industries, key);
  String functionLabel(String key) => _label(functions, key);

  static String _label(List<MasterOption> options, String key) {
    for (final o in options) {
      if (o.key == key) return o.label;
    }
    return key;
  }

  factory TalentMasters.fromJson(Map<String, dynamic> json) {
    List<MasterOption> read(Object? raw) => [
      for (final o in raw is List ? raw : const [])
        if (o is Map && o['key'] != null && (o['active'] ?? true) != false)
          MasterOption('${o['key']}', '${o['name'] ?? o['key']}'),
    ];
    final industries = read(json['industries']);
    final functions = read(json['jobFunctions']);
    return TalentMasters(
      industries: industries.isEmpty ? seedIndustries : industries,
      functions: functions.isEmpty ? seedJobFunctions : functions,
    );
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "₹18,00,000", the Indian grouping the website's `formatMoney(…, { unit: 'rupees' })` prints.
String rupees(num amount) {
  final whole = amount.round().abs().toString();
  if (whole.length <= 3) return '₹${amount < 0 ? '-' : ''}$whole';
  final last3 = whole.substring(whole.length - 3);
  var rest = whole.substring(0, whole.length - 3);
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);
  return '₹${amount < 0 ? '-' : ''}${groups.join(',')},$last3';
}

/// "18.0", a salary ceiling in lakh as the filter chips write it (`(n / 100000).toFixed(1)`).
String lakh(num amount) => (amount / 100000).toStringAsFixed(1);

/// "15 Dec 2026" from a `YYYY-MM-DD` day key; the key itself when it cannot be read.
String dayKeyLabel(String dayKey) {
  final d = DateTime.tryParse(dayKey);
  if (d == null) return dayKey;
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// "5 Nov", when a note was written (`formatDate(…, { day: 'numeric', month: 'short' })`).
String dayMonthLabel(DateTime at) {
  final l = at.toLocal();
  return '${l.day} ${_months[l.month - 1]}';
}
