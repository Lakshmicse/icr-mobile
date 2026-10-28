/**
 * Seeds the Learning and Jobs content of the mobile app's designs into the
 * LOCAL portal database, so the app reads it through the portal's real API.
 *
 *   cd E:\ICR\irc-portal\backend          (cwd must be the backend folder: `uploads` resolves from it)
 *   NODE_PATH=E:/ICR/irc-portal/node_modules npx ts-node --transpile-only E:/ICR/icr-mobile/tool/seed/learning-jobs.ts
 *   ... same command with --remove        (deletes exactly what this script created)
 *   ... same command with --no-resume     (seeds everything except the personas' resume: see below)
 *   ... same command with --no-enrol      (seeds the course without Bharat's place on it; removes the one seeded)
 *
 * Idempotent: every row has a stable key and is upserted, so a re-run updates in
 * place (and re-bases the "posted N days ago" dates and the alert's "new" badge).
 *
 * What is seeded (marker in brackets):
 *   Learning  one DEVELOPMENT course, "Certificate in Advanced Leadership Skills"
 *             (CALS), its institute + enrolment specialist, 2 modules, 6 runs (the design's
 *             three face-to-face runs, a fourth behind "See More Dates", and two live
 *             virtual ones for the second tab), 3 published reviews, and Bharat Buyer's
 *             CONFIRMED place on the Riyadh run (what makes its tile read CONFIRMED, as the
 *             design; --no-enrol leaves him without one).      [ids start `design-lj-`]
 *   Jobs      3 companies (with an industry, the sheet's tagline), 7 people, 8 open jobs
 *             (one of them takes applications on the employer's own site), and for the two
 *             personas below a default resume with job preferences (years of experience
 *             included), an alert and applications; Bharat also gets one education entry,
 *             which the sheet's "Your profile matches N of M requirements" card reads.
 *                                  [ids start `design-lj-`; companies have source
 *                                   'design-seed-lj'; people have emails ending
 *                                   @learning-jobs.icr.test]
 *   Files     /uploads/design-lj-* (copied from assets/images/demo/*, plus a generated
 *             brochure PDF), each registered in UploadedFile.
 *
 * The markers are this script's own: other seeds in the same database use `design-`
 * and `@design.icr.test` (mentorship), so --remove never matches on those. Rows another
 * seed attaches to these people with a cascading key (event attendance, say) go with
 * them on --remove; a person or company something else still depends on is left in
 * place, logged, and the run exits non-zero.
 *
 * Nothing existing is changed or deleted: the personas' resume is created only
 * when they have no default one (otherwise they are left alone and a warning is
 * logged), and --remove touches only rows carrying the markers above.
 *
 * The resume is what fills the board's "Recommended Jobs for You" section (and
 * orders "Matching your preferences"). It has one side effect worth knowing: the
 * local database has no pgvector, and GET /jobs/:id/match-preview runs raw SQL on
 * the missing `embedding` columns once a person HAS a resume, so that call answers
 * 500 for them (it answers 200 "noResume" without one). --no-resume seeds
 * everything else and removes the personas' design resumes.
 *
 * It refuses to run unless DATABASE_URL points at localhost.
 */
import type { Prisma, PrismaClient } from '@prisma/client';
import { existsSync, mkdirSync, readFileSync, unlinkSync, writeFileSync } from 'fs';
import { extname, join, resolve } from 'path';

// ---------------------------------------------------------------------------
// Markers and constants
// ---------------------------------------------------------------------------

const MARK = 'design-lj-';
const SOURCE = 'design-seed-lj';
const EMAIL_DOMAIN = '@learning-jobs.icr.test';
const HOUR = 3_600_000;
const DAY = 24 * HOUR;
const DEMO_ASSETS = resolve(__dirname, '..', '..', 'assets', 'images', 'demo');

const up = (file: string) => `/uploads/${file}`;

/**
 * The people the board is personalised for. `alert` adds the saved search the
 * board's scope bar ("Facilities & Real Estate • Bengaluru, IN") is built from,
 * which replaces the "Latest jobs" section by the search's own results; `apps`
 * adds the three applications behind the "My jobs 3" chip; `education` adds the B.Tech
 * the job sheet's requirements card finds. Pooja, the e2e persona, gets none: her profile
 * completeness is something the e2e suite reads.
 *  - Bharat Buyer is the Android emulator's signed-in person.
 *  - Pooja Professional is the e2e persona; she keeps the plain "Latest jobs" board.
 */
const PERSONAS = [
  { key: 'bharat', email: 'buyer@icr.dev', alert: true, apps: true, education: true },
  { key: 'pooja', email: 'professional@icr.test', alert: false, apps: false, education: false },
] as const;

// ---------------------------------------------------------------------------
// Files
// ---------------------------------------------------------------------------

const ASSETS: { from: string; to: string }[] = [
  // The design's thumbnail without its baked-in "PREMIUM CERTIFICATION" pill (the app draws its own pill
  // from the course's level); the play glyph stays. `../../../tool/seed/assets` is relative to DEMO_ASSETS.
  { from: '../../../tool/seed/assets/course_cover_clean.png', to: 'design-lj-course-cover-clean.png' },
  { from: 'learning/badge_icr.png', to: 'design-lj-badge-icr.png' },
  { from: 'learning/specialist.png', to: 'design-lj-specialist-bushra.png' },
  { from: 'jobs/logo_green.png', to: 'design-lj-logo-green.png' },
  { from: 'jobs/logo_bluedot.png', to: 'design-lj-logo-bluedot.png' },
  { from: 'jobs/company_logo.png', to: 'design-lj-company-logo.png' },
  { from: 'jobs/company_photo.png', to: 'design-lj-company-photo.png' },
  { from: 'jobs/avatar_priya.png', to: 'design-lj-avatar-priya.png' },
];
const BROCHURE = 'design-lj-cals-brochure.pdf';

const MIME: Record<string, string> = { '.png': 'image/png', '.pdf': 'application/pdf' };

/** A one-page, text-only PDF (Helvetica, ASCII), enough to give DOWNLOAD BROCHURE something real to open. */
function brochurePdf(title: string, lines: string[]): Buffer {
  const esc = (s: string) => s.replace(/\\/g, '\\\\').replace(/\(/g, '\\(').replace(/\)/g, '\\)');
  const wrap = (s: string, max = 82): string[] => {
    const out: string[] = [];
    let row = '';
    for (const word of s.split(/\s+/)) {
      if ((row + ' ' + word).trim().length > max) {
        out.push(row);
        row = word;
      } else row = (row + ' ' + word).trim();
    }
    if (row) out.push(row);
    return out;
  };
  const ops = ['BT', '/F1 20 Tf', `1 0 0 1 56 780 Tm (${esc(title)}) Tj`, '/F1 11 Tf'];
  let y = 748;
  for (const line of lines.flatMap((l) => (l === '' ? [''] : wrap(l)))) {
    ops.push(`1 0 0 1 56 ${y} Tm (${esc(line)}) Tj`);
    y -= 17;
  }
  ops.push('ET');
  const stream = ops.join('\n');
  const objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    `<< /Length ${Buffer.byteLength(stream, 'latin1')} >>\nstream\n${stream}\nendstream`,
  ];
  let pdf = '%PDF-1.4\n';
  const offsets: number[] = [];
  objects.forEach((body, i) => {
    offsets.push(Buffer.byteLength(pdf, 'latin1'));
    pdf += `${i + 1} 0 obj\n${body}\nendobj\n`;
  });
  const xref = Buffer.byteLength(pdf, 'latin1');
  pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  pdf += offsets.map((o) => `${String(o).padStart(10, '0')} 00000 n \n`).join('');
  pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return Buffer.from(pdf, 'latin1');
}

// ---------------------------------------------------------------------------
// Learning content (demo_learning_repository.dart)
// ---------------------------------------------------------------------------

const L = {
  provider: 'design-lj-provider-icr-institute',
  trainer: 'design-lj-trainer-bushra',
  course: 'design-lj-course-cals',
  modules: ['design-lj-cals-module-1', 'design-lj-cals-module-2'],
  batches: [
    'design-lj-cals-run-1',
    'design-lj-cals-run-2',
    'design-lj-cals-run-3',
    'design-lj-cals-run-4',
    'design-lj-cals-run-5',
    'design-lj-cals-run-6',
  ],
  review: 'design-lj-cals-review-1',
  moreReviews: ['design-lj-cals-review-2', 'design-lj-cals-review-3'],
  // Bharat Buyer's place on the first run.
  enrolment: 'design-lj-cals-enrolment-bharat',
};

const COURSE = {
  code: 'CALS',
  slug: 'certificate-in-advanced-leadership-skills',
  title: 'Certificate in Advanced Leadership Skills',
  summary:
    'Future-ready Insights, Models and Practices to elevate your strategic decision-making and drive organizational transformation.',
  description: [
    'Leadership is not something people are just born with; leadership can be learnt. All around the world ' +
      'businesses are realizing the power of great leadership. They realize the value it brings to the business ' +
      'and to individuals and they are recognizing the significant costs of poor leadership too!',
    'This certificate programme gives senior managers the frameworks and the personal insight to lead through ' +
      'disruption, delivered face to face over five days by ICR Institute.',
  ].join('\n\n'),
  outcomes: [
    'Self-evaluate your personal leadership style and effectiveness, be able to identify your priorities for ' +
      'people management and leadership development.',
    'Design and implement high-performance team strategies by understanding team dynamics including ' +
      'teamworking, conflict resolution and collaboration.',
    'Diagnose organizational culture to identify strengths, weaknesses and required change to drive successful ' +
      'transformation.',
  ],
  audience: [
    'Executive Management',
    'Senior Project Directors',
    'Facility & Asset Leaders',
    'VP Operations',
    'High-Potential Talent',
  ],
};

const MODULES = [
  {
    title: 'Leadership Intelligence',
    topics: [
      'Leadership in a Disruptive World',
      'The Evolution of Leadership Paradigms',
      'Assessing Personal Leadership Competencies',
    ],
  },
  { title: 'Personal Mastery', topics: [] as string[] },
];

/**
 * The design's three face-to-face runs, then the ones it cannot show. The public API
 * lists only OPEN runs that start in the future, so the design's 2024 cannot be served:
 * the dates keep the design's month and day and take the next year they are still ahead
 * of us.
 *
 * "Limited" is the app's word for <= 20 % of the places left. Dubai holds one public
 * place (5 seats, 4 reserved for partners), so it reads Limited with no enrolments to
 * invent; the others read Open. Riyadh reads CONFIRMED to Bharat Buyer, who holds a
 * place on it (see seedLearning).
 *
 * The fourth face-to-face run sits behind "See More Dates" (the grid shows three and
 * the "Suggest A Date & Location" tile); the two VIRTUAL runs fill the "Live Virtual
 * Training" tab. They are on the record so those controls have something to do; the
 * design draws neither.
 */
const RUNS = [
  { location: 'Riyadh, KSA', title: 'Riyadh - August', mode: 'IN_PERSON', start: [7, 23], end: [7, 27], maxSeats: 20, reservedSeats: 0 },
  { location: 'London, UK', title: 'London - September', mode: 'IN_PERSON', start: [8, 14], end: [8, 18], maxSeats: 20, reservedSeats: 0 },
  { location: 'Dubai, UAE', title: 'Dubai - October', mode: 'IN_PERSON', start: [9, 5], end: [9, 9], maxSeats: 5, reservedSeats: 4 },
  { location: 'Singapore, SG', title: 'Singapore - November', mode: 'IN_PERSON', start: [10, 15], end: [10, 19], maxSeats: 20, reservedSeats: 0 },
  { location: 'Live online', title: 'Live Virtual - November', mode: 'VIRTUAL', start: [10, 2], end: [10, 6], maxSeats: 30, reservedSeats: 0 },
  { location: 'Live online', title: 'Live Virtual - December', mode: 'VIRTUAL', start: [11, 7], end: [11, 11], maxSeats: 30, reservedSeats: 0 },
] as const;

const REVIEW = {
  author: 'charles',
  rating: 5,
  roleLabel: 'Facilities Manager',
  // Stored bare: the app adds the quotation marks.
  body:
    'The staffs are very professional and helpful since we started corresponding before eventually coming to Dubai ' +
    'to do the course. Am going back very confident, well fulfilled and my knowledge in facility management has ' +
    'been enlightening. Thank you!',
};

/** Two more published reviews, older than the design's, so "see all reviews" has a list to open. */
const MORE_REVIEWS = [
  {
    author: 'anjali',
    rating: 4,
    roleLabel: 'Talent Acquisition Lead',
    daysAgo: 45,
    body:
      'Well structured over the five days. The leadership self-assessment on day one set the tone for everything ' +
      'that followed, and the group work was the most useful part.',
  },
  {
    author: 'rohan',
    rating: 5,
    roleLabel: 'Procurement Lead',
    daysAgo: 60,
    body:
      'Practical case work, not slides. I took the team-dynamics exercises straight back to my own procurement team.',
  },
] as const;

/** The next year in which the earliest run (Aug 23) is still at least 45 days away. */
function scheduleYear(now: Date): number {
  let year = now.getUTCFullYear();
  while (Date.UTC(year, 7, 23, 12) < now.getTime() + 45 * DAY) year++;
  return year;
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

// ---------------------------------------------------------------------------
// Jobs content (demo_jobs_repository.dart)
// ---------------------------------------------------------------------------

type Role = 'COMPANY_ADMIN' | 'HIRING_MANAGER' | 'RECRUITER' | 'BUYER' | 'PROFESSIONAL';
type CompanyKey = 'green' | 'bluedot' | 'global';

const COMPANIES: Record<
  CompanyKey,
  {
    id: string;
    sourceId: string;
    name: string;
    legalName: string;
    city: string;
    state: string;
    logo: string;
    gallery: string[];
    description: string;
    /** A JOB_INDUSTRIES key: the app words it as the line under the company's name on the job sheet. */
    industry: string;
  }
> = {
  // The board's rows carry CBRE South Asia with two different logos (Green, BlueDot). A company has one logo, so
  // the second row's company is a second company of the same name; only the legal name tells them apart.
  green: {
    id: 'design-lj-co-cbre-green',
    sourceId: 'cbre-green',
    name: 'CBRE South Asia',
    legalName: 'CBRE South Asia Pvt. Ltd.',
    city: 'Mumbai',
    state: 'Maharashtra',
    logo: 'design-lj-logo-green.png',
    industry: 'FM_SERVICES',
    gallery: [],
    description:
      'Integrated real estate services across South Asia: occupier outsourcing, facilities management and project management for institutional campuses.',
  },
  bluedot: {
    id: 'design-lj-co-cbre-bluedot',
    sourceId: 'cbre-bluedot',
    name: 'CBRE South Asia',
    legalName: 'CBRE South Asia (Facilities) Pvt. Ltd.',
    city: 'Mumbai',
    state: 'Maharashtra',
    logo: 'design-lj-logo-bluedot.png',
    industry: 'FM_SERVICES',
    gallery: [],
    description:
      'Integrated real estate services across South Asia: occupier outsourcing, facilities management and project management for institutional campuses.',
  },
  global: {
    id: 'design-lj-co-global-infra',
    sourceId: 'global-infra',
    name: 'Global Infra Solutions',
    legalName: 'Global Infra Solutions Ltd.',
    city: 'Bengaluru',
    state: 'Karnataka',
    logo: 'design-lj-company-logo.png',
    industry: 'CRE_SERVICES',
    // The sheet's "About" photo. GET /companies/:id carries it as `gallery`.
    gallery: ['design-lj-company-photo.png'],
    description:
      'Leading Indian commercial real estate management operator handling 42M+ sq.ft. of prime institutional tech parks and industrial hubs.',
  },
};

/**
 * People. Global Infra's five are what "Nikhil M. and 4 others ... work at this
 * organization" counts: the API lists a company's public members by first name,
 * so Nikhil sorts first. Priya Sharma is the sheet's hiring contact.
 */
const PEOPLE: Record<
  string,
  {
    first: string;
    last: string;
    designation: string;
    companies: CompanyKey[];
    role: Role;
    avatar?: string;
    founder?: boolean;
  }
> = {
  nikhil: { first: 'Nikhil', last: 'Menon', designation: 'Head of Facilities Operations', companies: ['global'], role: 'COMPANY_ADMIN', founder: true },
  omkar: { first: 'Omkar', last: 'Patil', designation: 'Senior Manager - MEP', companies: ['global'], role: 'HIRING_MANAGER' },
  priya: {
    first: 'Priya',
    last: 'Sharma',
    designation: 'Lead Talent Partner @ Global Infra',
    companies: ['global'],
    role: 'RECRUITER',
    avatar: 'design-lj-avatar-priya.png',
  },
  rohan: { first: 'Rohan', last: 'Kulkarni', designation: 'Procurement Lead', companies: ['global'], role: 'BUYER' },
  tarun: { first: 'Tarun', last: 'Verma', designation: 'Energy and Sustainability Manager', companies: ['global'], role: 'BUYER' },
  anjali: {
    first: 'Anjali',
    last: 'Bhatt',
    designation: 'Talent Acquisition Lead @ CBRE South Asia',
    companies: ['green', 'bluedot'],
    role: 'RECRUITER',
  },
  // Wrote the course review; belongs to no company.
  charles: { first: 'Charles', last: 'Selasie Tuffour', designation: 'Facilities Manager', companies: [], role: 'PROFESSIONAL' },
};

const emailOf = (key: string) => `${PEOPLE[key].first}.${PEOPLE[key].last}`.toLowerCase().replace(/\s+/g, '-') + EMAIL_DOMAIN;

/** The skills of the sheet's job (design) and of the STP rows. The personas' resume lists all but "OpEx Planning". */
const SHEET_SKILLS = ['BMS Automation', 'HVAC Chillers', 'EHS Auditing', 'Vendor SLAs', 'OpEx Planning'];
const STP_SKILLS = ['STP Operations', 'Water Treatment', 'EHS Auditing', 'Vendor SLAs', 'Preventive Maintenance Planning'];

const SHEET_HTML =
  '<p>We are seeking an authoritative and strategic Senior Facilities Manager to spearhead campus operations ' +
  'across our marquee 2.4M+ sq.ft. Grade-A commercial tech park in Outer Ring Road, Bengaluru. You will orchestrate ' +
  'end-to- end hard MEP systems, workplace hospitality, client relations, and sustainability goals.</p>' +
  '<h3>Key Responsibilities</h3><ul>' +
  '<li>Direct operational leadership across 4 interconnected Grade-A towers housing Fortune 500 tech clients.</li>' +
  '<li>Spearhead IoT automated energy telemetry deployment resulting in verified sub-system energy reduction targets.</li>' +
  '<li>Lead statutory audit readiness for National Building Code (NBC), OHSAS 18001, and Pollution Control Board approvals.</li>' +
  '<li>Contract management, procurement governance, and SLA dispute resolution for soft &amp; hard engineering vendor teams.</li>' +
  '</ul>';

const STP_HTML =
  '<p>CBRE South Asia is looking for a Senior Facilities Manager to run the sewage treatment plant (STP) and ' +
  'water-recycling systems across a large institutional campus in Mumbai. You will own plant uptime, statutory ' +
  'compliance and the contractors who keep it running.</p>' +
  '<h3>Key Responsibilities</h3><ul>' +
  '<li>Operate and maintain the STP, ETP and water-recycling systems within consent-to-operate limits.</li>' +
  '<li>Lead the plant operations team and manage O&amp;M vendors against agreed service levels.</li>' +
  '<li>Keep statutory records and stay audit-ready for the Maharashtra Pollution Control Board.</li>' +
  '<li>Plan preventive maintenance and critical spares so the plant never stops without warning.</li>' +
  '</ul>';

const extraHtml = (intro: string, duties: string[]) =>
  `<p>${intro}</p><h3>Key Responsibilities</h3><ul>${duties.map((d) => `<li>${d}</li>`).join('')}</ul>`;

type JobSeed = {
  id: string;
  company: CompanyKey;
  contact: string; // a PEOPLE key
  /** true: the job names them as its recruiter ("Recruiter"); false: only as who posted it ("Job poster"). */
  recruiter: boolean;
  title: string;
  html: string;
  city: string;
  state: string;
  ageHours: number;
  salary: [number, number];
  experienceMin: number;
  skills: string[];
  seniority: 'MID' | 'SENIOR' | 'LEAD';
  department: string | null;
  openings: number;
  /** One of the three jobs the Bharat persona has applied to ("My jobs 3"). */
  appliedBy?: { stage: 'APPLIED' | 'SCREENING' | 'INTERVIEW'; daysAgo: number };
  /** Degrees it accepts (education taxonomy keys); the card's "B.Tech / B.E. in Mechanical or Electrical" row. */
  education?: string[];
  /** Credentials it would like; the card's "Preferred credential" row. */
  preferred?: string[];
  /** Takes applications on the employer's own site: Easy Apply gives way to "Apply on company site". */
  external?: string;
};

const JOBS: JobSeed[] = [
  // The board's rows, newest first (the design's three rows: Green, Green, BlueDot). "Matching your preferences"
  // and the saved search order by how recently a job went live, so the three are an hour apart: no ties.
  {
    id: 'design-lj-job-stp-1', company: 'green', contact: 'anjali', recruiter: true,
    title: 'Senior Facilities Manager for STP Plant', html: STP_HTML, city: 'Mumbai', state: 'Maharashtra',
    ageHours: 48, salary: [1_600_000, 2_200_000], experienceMin: 8, skills: STP_SKILLS, seniority: 'LEAD', department: null, openings: 1,
  },
  {
    id: 'design-lj-job-stp-2', company: 'green', contact: 'anjali', recruiter: true,
    title: 'Senior Facilities Manager for STP Plant', html: STP_HTML, city: 'Mumbai', state: 'Maharashtra',
    ageHours: 49, salary: [1_600_000, 2_200_000], experienceMin: 8, skills: STP_SKILLS, seniority: 'LEAD', department: null, openings: 1,
  },
  {
    id: 'design-lj-job-stp-3', company: 'bluedot', contact: 'anjali', recruiter: true,
    title: 'Senior Facilities Manager for STP Plant', html: STP_HTML, city: 'Mumbai', state: 'Maharashtra',
    ageHours: 50, salary: [1_600_000, 2_200_000], experienceMin: 8, skills: STP_SKILLS, seniority: 'LEAD', department: null, openings: 1,
  },
  // The job the sheet design draws. The blue line under its title is category + department in the app; the
  // category stays empty so the line reads exactly as designed.
  {
    id: 'design-lj-job-global-infra', company: 'global', contact: 'priya', recruiter: false,
    title: 'Senior Facilities Manager', html: SHEET_HTML, city: 'Bengaluru', state: 'Karnataka',
    ageHours: 72, salary: [1_800_000, 2_500_000], experienceMin: 8, skills: SHEET_SKILLS, seniority: 'LEAD',
    department: 'Commercial Grade-A Towers • 2.4M+ sq.ft.', openings: 2,
    // Three of the card's four rows come from these (the years from `experienceMin`, the degree from the persona's
    // education, the credential nobody holds): the design's "matches 4 of 5 requirements" card, from real fields.
    education: ['UG_BTECH_MECHANICAL', 'UG_BTECH_ELECTRICAL'],
    preferred: ['RICS or IFMA Facility Management Charter'],
  },
  // Three more postings, in cities and with skills the personas' preferences do not touch: they stay out of the
  // recommended and preferences sections, and are the three applications behind "My jobs 3".
  {
    id: 'design-lj-job-extra-1', company: 'global', contact: 'priya', recruiter: false,
    title: 'Facilities Manager - Technology Campus', city: 'Hyderabad', state: 'Telangana',
    html: extraHtml('Run day-to-day facilities for a 1.1M sq.ft. technology campus: occupant services, vendors and budgets.', [
      'Own the campus helpdesk, soft services and space-planning requests end to end.',
      'Hold service vendors to their SLAs and report monthly to the client.',
      'Control the operating budget and flag variances early.',
    ]),
    ageHours: 96, salary: [1_400_000, 1_900_000], experienceMin: 6,
    skills: ['Space Planning', 'Occupant Services', 'Soft Services Management', 'Helpdesk Operations', 'Budget Control'],
    seniority: 'SENIOR', department: null, openings: 1, appliedBy: { stage: 'APPLIED', daysAgo: 3 },
  },
  {
    id: 'design-lj-job-extra-2', company: 'global', contact: 'priya', recruiter: false,
    title: 'Energy and Sustainability Lead', city: 'Pune', state: 'Maharashtra',
    html: extraHtml('Lead the energy and sustainability programme across our Pune tech parks.', [
      'Run energy audits and track consumption against ISO 50001 targets.',
      'Plan and report the portfolio carbon footprint.',
      'Deliver solar PV and efficiency retrofits on budget.',
    ]),
    ageHours: 120, salary: [2_000_000, 2_800_000], experienceMin: 8,
    skills: ['Energy Audits', 'ISO 50001', 'Carbon Reporting', 'Solar PV', 'Net Zero Planning'],
    seniority: 'LEAD', department: null, openings: 1, appliedBy: { stage: 'SCREENING', daysAgo: 4 },
  },
  {
    id: 'design-lj-job-extra-3', company: 'green', contact: 'anjali', recruiter: true,
    title: 'Assistant Manager - Soft Services', city: 'Chennai', state: 'Tamil Nadu',
    html: extraHtml('Manage housekeeping, pantry and front-of-house teams for a Grade-A office campus in Chennai.', [
      'Plan manpower and shifts for the soft services teams.',
      'Audit housekeeping and pantry standards every week.',
      'Report consumables, quality and client feedback.',
    ]),
    ageHours: 144, salary: [700_000, 1_000_000], experienceMin: 3,
    skills: ['Housekeeping Audits', 'Pantry Operations', 'Manpower Planning', 'Consumables Control', 'Client Reporting'],
    seniority: 'MID', department: null, openings: 1, appliedBy: { stage: 'APPLIED', daysAgo: 5 },
  },
  // A posting that sends people to the employer's own site (the sheet's "Apply on company site" path). Kolkata and
  // skills the personas' preferences do not touch, so it stays off their boards' recommended sections; nobody applies.
  {
    id: 'design-lj-job-external-1', company: 'global', contact: 'priya', recruiter: false,
    title: 'Estate Operations Manager', city: 'Kolkata', state: 'West Bengal',
    html: extraHtml('Run estate operations for a commercial portfolio in Kolkata: leases, property tax and tenant relations.', [
      'Administer leases and renewals across the portfolio.',
      'Keep property tax and statutory filings current.',
      'Hold the tenant relations desk to its response targets.',
    ]),
    ageHours: 168, salary: [1_500_000, 2_000_000], experienceMin: 5,
    skills: ['Estate Management', 'Lease Administration', 'Property Tax', 'Facility Audits', 'Tenant Relations'],
    seniority: 'SENIOR', department: null, openings: 1,
    external: 'https://careers.globalinfra.example/jobs/estate-operations-manager',
  },
];

/** What the board is personalised from: "Recommended" reads the skills, "Matching your preferences" the rest. */
const RESUME = {
  title: 'Design preview resume',
  headline: 'Senior Facilities Manager - Grade-A campus operations',
  summary:
    'Facilities leader with 9+ years running Grade-A commercial campuses: hard MEP, water treatment, vendor SLAs and statutory audits.',
  skills: [
    'BMS Automation',
    'HVAC Chillers',
    'EHS Auditing',
    'Vendor SLAs',
    'STP Operations',
    'Water Treatment',
    'Preventive Maintenance Planning',
  ],
  experienceYears: 9.4,
  currentLocation: 'Bengaluru',
  desiredRoles: ['Senior Facilities Manager', 'Facilities Manager'],
  desiredLocations: ['Bengaluru', 'Mumbai'],
  desiredWorkModes: ['ONSITE', 'HYBRID'] as ('ONSITE' | 'HYBRID')[],
  desiredEmploymentTypes: ['FULL_TIME'] as 'FULL_TIME'[],
  desiredSalaryMin: 1_800_000,
  desiredIndustries: ['CRE_SERVICES'],
  desiredFunctions: ['FACILITIES_OPS', 'HARD_SERVICES'],
};

const ALERT = {
  name: 'Facilities & Real Estate',
  // The app reads the first city and the country for "Bengaluru, IN"; the API filters on every city listed.
  criteria: { city: 'Bengaluru,Mumbai', country: 'India' },
};

// ---------------------------------------------------------------------------
// Guards
// ---------------------------------------------------------------------------

function databaseHost(): string {
  let url = process.env.DATABASE_URL;
  if (!url) {
    const env = join(process.cwd(), '.env');
    if (existsSync(env)) url = /^\s*DATABASE_URL\s*=\s*"?([^"\r\n]+)"?/m.exec(readFileSync(env, 'utf8'))?.[1];
  }
  if (!url) throw new Error('DATABASE_URL is not set (checked the environment and ./.env): refusing to write anywhere unknown.');
  try {
    return new URL(url).hostname; // the password is never printed
  } catch {
    throw new Error('DATABASE_URL does not parse: refusing to write.');
  }
}

function assertLocalDatabase(): void {
  const host = databaseHost();
  if (!['localhost', '127.0.0.1', '::1', '[::1]'].includes(host)) {
    throw new Error(`DATABASE_URL points at "${host}", not localhost: this seed only writes to a local database.`);
  }
}

function assertBackendCwd(): void {
  if (!existsSync(join(process.cwd(), 'prisma', 'schema.prisma'))) {
    throw new Error(`Run this from the portal's backend folder (E:\\ICR\\irc-portal\\backend); cwd is ${process.cwd()}.`);
  }
}

// ---------------------------------------------------------------------------
// The seed
// ---------------------------------------------------------------------------

export async function seedLearningJobs(
  prisma: PrismaClient,
  log: (m: string) => void,
  opts: { remove?: boolean; resume?: boolean; enrol?: boolean } = {},
): Promise<void> {
  assertLocalDatabase();
  assertBackendCwd();
  if (opts.remove) {
    await removeAll(prisma, log);
    return;
  }

  const now = new Date();
  const year = scheduleYear(now);
  log(`Seeding the Learning and Jobs designs into the local database (runs in ${year}).`);

  await seedFiles(prisma, log, year);
  const people = await seedPeopleAndCompanies(prisma, log);
  const jobs = await seedJobs(prisma, log, people, now);
  await seedPersonas(prisma, log, jobs, now, opts.resume !== false);
  await seedLearning(prisma, log, people, now, year, opts.enrol !== false);

  const [courses, runs, jobCount, companies, persons, files] = await Promise.all([
    prisma.learningCourse.count({ where: { id: { startsWith: MARK } } }),
    prisma.learningBatch.count({ where: { id: { startsWith: MARK } } }),
    prisma.job.count({ where: { id: { startsWith: MARK } } }),
    prisma.company.count({ where: { source: SOURCE } }),
    prisma.user.count({ where: { email: { endsWith: EMAIL_DOMAIN } } }),
    prisma.uploadedFile.count({ where: { filename: { startsWith: MARK } } }),
  ]);
  log(`Done. Design rows now in the database: ${courses} course, ${runs} runs, ${jobCount} jobs, ${companies} companies, ${persons} people, ${files} files.`);
}

async function seedFiles(prisma: PrismaClient, log: (m: string) => void, year: number): Promise<void> {
  const uploads = join(process.cwd(), 'uploads');
  mkdirSync(uploads, { recursive: true });

  const files: { name: string; bytes: Buffer }[] = ASSETS.map((a) => ({
    name: a.to,
    bytes: readFileSync(join(DEMO_ASSETS, a.from)),
  }));
  const dates = RUNS.map(
    (r) =>
      `${r.location} (${r.mode === 'VIRTUAL' ? 'live virtual' : 'face to face'}) - ${MONTHS[r.start[0]]} ${String(r.start[1]).padStart(2, '0')}-${String(r.end[1]).padStart(2, '0')}, ${year}`,
  );
  files.push({
    name: BROCHURE,
    bytes: brochurePdf(COURSE.title, [
      'ICR Institute - professional development programme (code CALS).',
      '',
      COURSE.summary,
      '',
      'Format: face to face or live virtual over 5 days (35 hours), led by ICR Institute.',
      'Upcoming runs:',
      ...dates.map((d) => `  - ${d}`),
      '',
      'Key takeaways:',
      ...COURSE.outcomes.map((o, i) => `  ${i + 1}. ${o}`),
      '',
      'Enquiries: use "ask the institute" on the course page in the ICR app.',
      '(Design preview brochure: placeholder content seeded for the mobile app.)',
    ]),
  });

  for (const f of files) {
    writeFileSync(join(uploads, f.name), f.bytes);
    const data = {
      visibility: 'PUBLIC' as const,
      purpose: SOURCE,
      name: f.name,
      mimeType: MIME[extname(f.name)] ?? 'application/octet-stream',
      size: f.bytes.length,
    };
    await prisma.uploadedFile.upsert({ where: { filename: f.name }, create: { filename: f.name, ...data }, update: data });
  }
  log(`  files: ${files.length} written to uploads/ and registered as public (${files.map((f) => f.name).join(', ')})`);
}

type People = Record<string, string>; // key -> user id
type Companies = Record<CompanyKey, string>;

async function seedPeopleAndCompanies(
  prisma: PrismaClient,
  log: (m: string) => void,
): Promise<{ users: People; companies: Companies }> {
  const companies = {} as Companies;
  for (const [key, c] of Object.entries(COMPANIES) as [CompanyKey, (typeof COMPANIES)[CompanyKey]][]) {
    const data = {
      name: c.name,
      legalName: c.legalName,
      type: 'REAL_ESTATE' as const,
      size: '500+',
      city: c.city,
      state: c.state,
      country: 'India',
      logoUrl: up(c.logo),
      gallery: c.gallery.map(up),
      description: c.description,
      industry: c.industry,
      verificationStatus: 'VERIFIED' as const,
      verificationLevel: 'VERIFIED' as const,
      verifiedAt: new Date(),
      source: SOURCE,
      sourceId: c.sourceId,
    };
    await prisma.company.upsert({ where: { id: c.id }, create: { id: c.id, ...data }, update: { ...data, verifiedAt: undefined } });
    companies[key] = c.id;
  }

  const users: People = {};
  for (const [key, p] of Object.entries(PEOPLE)) {
    const active = p.companies[0] ? companies[p.companies[0]] : null;
    const data = {
      firstName: p.first,
      lastName: p.last,
      designation: p.designation,
      avatarUrl: p.avatar ? up(p.avatar) : null,
      role: p.role,
      personalRole: 'PROFESSIONAL' as const,
      companyId: active,
      isActive: true,
      profilePublic: true,
    };
    const email = emailOf(key);
    const user = await prisma.user.upsert({ where: { email }, create: { email, ...data }, update: data });
    users[key] = user.id;

    for (const c of p.companies) {
      const found = await prisma.companyMembership.findFirst({
        where: { userId: user.id, companyId: companies[c], status: 'ACTIVE' },
      });
      if (found) {
        if (found.role !== p.role) await prisma.companyMembership.update({ where: { id: found.id }, data: { role: p.role } });
      } else {
        await prisma.companyMembership.create({
          data: { userId: user.id, companyId: companies[c], role: p.role, status: 'ACTIVE', source: p.founder ? 'FOUNDER' : 'ADDED' },
        });
      }
    }
  }
  log(
    `  companies: ${Object.keys(companies).length} (source '${SOURCE}'); people: ${Object.keys(users).length} (${EMAIL_DOMAIN}), ` +
      `Global Infra Solutions has ${Object.values(PEOPLE).filter((p) => p.companies.includes('global')).length} public members`,
  );
  return { users, companies };
}

async function seedJobs(
  prisma: PrismaClient,
  log: (m: string) => void,
  who: { users: People; companies: Companies },
  now: Date,
): Promise<Record<string, string>> {
  const ids: Record<string, string> = {};
  for (const j of JOBS) {
    const at = new Date(now.getTime() - j.ageHours * HOUR);
    const contact = who.users[j.contact];
    const data: Prisma.JobUncheckedCreateInput = {
      title: j.title,
      description: j.html,
      location: `${j.city}, ${j.state}, India`,
      city: j.city,
      cities: [j.city],
      state: j.state,
      country: 'India',
      status: 'OPEN',
      companyId: who.companies[j.company],
      postedById: contact,
      publishedById: contact,
      recruiterId: j.recruiter ? contact : null,
      publishedAt: at,
      createdAt: at,
      salaryMin: j.salary[0],
      salaryMax: j.salary[1],
      salaryCurrency: 'INR',
      salaryPeriod: 'YEARLY',
      salaryVisible: true,
      showHiringContact: true,
      employmentType: 'FULL_TIME',
      workMode: 'ONSITE',
      experienceMin: j.experienceMin,
      experienceMax: null,
      department: j.department,
      category: null,
      seniority: j.seniority,
      skills: j.skills,
      qualifications: [],
      educationQualifications: j.education ?? [],
      preferredQualifications: j.preferred ?? [],
      preferredSkills: [],
      openings: j.openings,
      applyMethod: j.external ? 'EXTERNAL_URL' : 'ON_PLATFORM',
      applyUrl: j.external ?? null,
      requireResume: false,
      applyDeadline: null,
      jobFunctions: ['FACILITIES_OPS'],
      industries: ['CRE_SERVICES'],
      deletedAt: null,
    };
    await prisma.job.upsert({ where: { id: j.id }, create: { id: j.id, ...data }, update: data });
    ids[j.id] = j.id;
  }
  log(
    `  jobs: ${JOBS.length} open (${JOBS.filter((j) => !j.appliedBy && !j.external).length} on the board, ` +
      `${JOBS.filter((j) => j.appliedBy).length} for "My jobs", ${JOBS.filter((j) => j.external).length} on the employer's own site)`,
  );
  return ids;
}

async function seedPersonas(
  prisma: PrismaClient,
  log: (m: string) => void,
  jobs: Record<string, string>,
  now: Date,
  withResume: boolean,
): Promise<void> {
  // The alert's "new" badge counts the jobs it matches that went live after its watermark: put it between the
  // second and third STP rows, so the chip reads "2 new" until the member taps Alerts (which runs the search and
  // counts them as seen; opening the board only reads its results, it never marks them).
  const second = JOBS.find((j) => j.id === 'design-lj-job-stp-2')!;
  const third = JOBS.find((j) => j.id === 'design-lj-job-stp-3')!;
  const watermark = new Date(now.getTime() - ((second.ageHours + third.ageHours) / 2) * HOUR);

  for (const p of PERSONAS) {
    const user = await prisma.user.findUnique({ where: { email: p.email }, select: { id: true, firstName: true, lastName: true } });
    if (!user) {
      log(`  ! ${p.email} not found: skipped`);
      continue;
    }
    const who = `${user.firstName} ${user.lastName} <${p.email}>`;

    // The resume (skills + preferences) is what fills "Recommended" and "Matching your preferences".
    const resumeId = `${MARK}resume-${p.key}`;
    const own = await prisma.resume.findFirst({ where: { userId: user.id, isDefault: true }, select: { id: true } });
    let useResume: string | null = resumeId;
    if (!withResume) {
      const gone = await prisma.resume.deleteMany({ where: { id: resumeId } });
      useResume = null;
      log(`  resume: none for ${who} (--no-resume${gone.count ? '; removed the one seeded earlier' : ''})`);
    } else if (own && own.id !== resumeId) {
      log(`  ! ${who} already has a default resume (${own.id}): left alone, so their board follows that resume`);
      useResume = null;
    } else {
      const data = {
        userId: user.id,
        title: RESUME.title,
        // `yearsExperience` is what GET /users/me/profile reads (the Resume.experienceYears column is not served).
        content: { headline: RESUME.headline, skills: RESUME.skills, yearsExperience: RESUME.experienceYears },
        isDefault: true,
        // Never in the recruiters' talent search.
        discoverable: false,
        headline: RESUME.headline,
        summary: RESUME.summary,
        skills: RESUME.skills,
        experienceYears: RESUME.experienceYears,
        currentLocation: RESUME.currentLocation,
        desiredRoles: RESUME.desiredRoles,
        desiredLocations: RESUME.desiredLocations,
        desiredWorkModes: RESUME.desiredWorkModes,
        desiredEmploymentTypes: RESUME.desiredEmploymentTypes,
        desiredSalaryMin: RESUME.desiredSalaryMin,
        desiredIndustries: RESUME.desiredIndustries,
        desiredFunctions: RESUME.desiredFunctions,
        willingToRelocate: false,
      };
      await prisma.resume.upsert({ where: { id: resumeId }, create: { id: resumeId, ...data }, update: data });
      log(`  resume: ${who} has the preferences resume`);
    }

    if (p.alert) {
      const alertId = `${MARK}alert-${p.key}`;
      const clash = await prisma.savedJobSearch.findUnique({ where: { userId_name: { userId: user.id, name: ALERT.name } } });
      if (clash && clash.id !== alertId) {
        log(`  ! ${who} already has a saved search named "${ALERT.name}": left alone`);
      } else {
        const matching = await prisma.job.count({
          where: { status: 'OPEN', deletedAt: null, city: { in: ['Bengaluru', 'Mumbai'] } },
        });
        // Alerts stay off: the daily sweep would email the person a digest of "new" jobs.
        const data = {
          userId: user.id,
          name: ALERT.name,
          criteria: ALERT.criteria,
          alertsEnabled: false,
          frequency: 'DAILY' as const,
          lastRunAt: watermark,
          lastNotifiedAt: watermark,
          lastMatchCount: matching,
        };
        await prisma.savedJobSearch.upsert({ where: { id: alertId }, create: { id: alertId, ...data }, update: data });
        log(`  alert: ${who} has the saved search "${ALERT.name}" (scope bar "Bengaluru, IN", badge counts jobs after ${watermark.toISOString()})`);
      }
    }

    if (p.education) {
      const data = {
        userId: user.id,
        institution: 'Visvesvaraya Technological University',
        degree: 'B.Tech',
        fieldOfStudy: 'Mechanical Engineering',
        startYear: 2008,
        endYear: 2012,
        sortOrder: 0,
      };
      const eduId = `${MARK}edu-${p.key}`;
      await prisma.userEducation.upsert({ where: { id: eduId }, create: { id: eduId, ...data }, update: data });
      log(`  education: ${who} has B.Tech, Mechanical Engineering`);
    }

    if (p.apps) {
      let n = 0;
      for (const j of JOBS.filter((x) => x.appliedBy)) {
        const at = new Date(now.getTime() - j.appliedBy!.daysAgo * DAY);
        const data = {
          jobId: jobs[j.id],
          applicantId: user.id,
          resumeId: useResume,
          stage: j.appliedBy!.stage,
          source: 'DIRECT' as const,
          createdAt: at,
        };
        await prisma.application.upsert({
          where: { jobId_applicantId: { jobId: jobs[j.id], applicantId: user.id } },
          create: { id: `${MARK}app-${p.key}-${j.id.replace(MARK + 'job-', '')}`, ...data },
          update: { stage: data.stage, resumeId: useResume },
        });
        n++;
      }
      log(`  applications: ${who} has ${n} (the "My jobs" chip)`);
    }
  }
}

async function seedLearning(
  prisma: PrismaClient,
  log: (m: string) => void,
  who: { users: People; companies: Companies },
  now: Date,
  year: number,
  enrol: boolean,
): Promise<void> {
  const taken = await prisma.learningCourse.findUnique({ where: { code: COURSE.code }, select: { id: true } });
  if (taken && taken.id !== L.course) {
    throw new Error(`A course with code ${COURSE.code} that this seed did not create already exists (${taken.id}); not touching it.`);
  }

  // The institute: the enrolment specialist is a member of an institute's team, so the course needs one. It is
  // named ICR Institute, the awarding body the design's certificate text names, and not marked as a partner.
  const providerData = {
    name: 'ICR Institute',
    slug: 'icr-institute-design',
    summary: "ICR's own institute for professional development and certification.",
    logoUrl: up('design-lj-badge-icr.png'),
    website: 'https://icr.org.in',
    verified: false,
    active: true,
    sortOrder: -10,
  };
  await prisma.learningProvider.upsert({ where: { id: L.provider }, create: { id: L.provider, ...providerData }, update: providerData });

  const trainerData = {
    providerId: L.provider,
    role: 'ENROLMENT_SPECIALIST' as const,
    name: 'Bushra A.',
    title: 'specialist – program enrollment',
    photoUrl: up('design-lj-specialist-bushra.png'),
    // Operational contact: the API never publishes it.
    email: 'contact@icrvinfraa.com',
    active: true,
  };
  await prisma.learningTrainer.upsert({ where: { id: L.trainer }, create: { id: L.trainer, ...trainerData }, update: trainerData });

  const courseData = {
    kind: 'DEVELOPMENT' as const,
    providerId: L.provider,
    code: COURSE.code,
    slug: COURSE.slug,
    title: COURSE.title,
    summary: COURSE.summary,
    description: COURSE.description,
    level: 'LEADERSHIP' as const,
    // Free, as the demo is: ADD TO CART enrols in place.
    access: 'FREE' as const,
    priceAmount: null,
    priceCurrency: 'INR',
    status: 'PUBLISHED' as const,
    enrollmentOpen: true,
    durationLabel: '5 days · 35 hours',
    durationWeeks: 1,
    durationHours: 35,
    cpdCredits: 0,
    certificateEnabled: true,
    certificateTitle: COURSE.title,
    waitlistEnabled: true,
    deliveryMode: 'Face to face and live virtual training',
    language: 'English',
    audience: COURSE.audience,
    learningOutcomes: COURSE.outcomes,
    imageUrl: up('design-lj-course-cover-clean.png'),
    brochureUrl: up(BROCHURE),
    // The catalogue orders by featuredUntil, then sortOrder, then title; everything else is 0.
    sortOrder: -10,
    deletedAt: null,
  };
  await prisma.learningCourse.upsert({ where: { id: L.course }, create: { id: L.course, ...courseData }, update: courseData });

  for (const [i, m] of MODULES.entries()) {
    const data = { courseId: L.course, title: m.title, topics: m.topics, sortOrder: i };
    await prisma.learningCourseModule.upsert({ where: { id: L.modules[i] }, create: { id: L.modules[i], ...data }, update: data });
  }

  // Noon UTC: the app shows dates in the device's zone, and noon keeps the calendar day for every zone from UTC-11 to UTC+11.
  const at = (m: number, d: number) => new Date(Date.UTC(year, m, d, 12));
  for (const [i, r] of RUNS.entries()) {
    const data = {
      courseId: L.course,
      title: r.title,
      code: `CALS-${year}${String(r.start[0] + 1).padStart(2, '0')}-${i + 1}`,
      mode: r.mode,
      status: 'OPEN' as const,
      startsAt: at(r.start[0], r.start[1]),
      endsAt: at(r.end[0], r.end[1]),
      durationLabel: '5 days',
      durationHours: 35,
      location: r.location,
      enrolmentSpecialistId: L.trainer,
      maxSeats: r.maxSeats,
      reservedSeats: r.reservedSeats,
      waitlistEnabled: true,
      sortOrder: i,
      deletedAt: null,
    };
    await prisma.learningBatch.upsert({ where: { id: L.batches[i] }, create: { id: L.batches[i], ...data }, update: data });
  }

  const reviews = [
    { id: L.review, ...REVIEW, daysAgo: 30 },
    ...MORE_REVIEWS.map((r, i) => ({ id: L.moreReviews[i], ...r })),
  ];
  for (const r of reviews) {
    const data = {
      courseId: L.course,
      authorId: who.users[r.author],
      rating: r.rating,
      body: r.body,
      roleLabel: r.roleLabel,
      status: 'PUBLISHED' as const,
      reviewedAt: now,
      deletedAt: null,
    };
    await prisma.learningCourseReview.upsert({
      where: { id: r.id },
      create: { id: r.id, ...data, createdAt: new Date(now.getTime() - r.daysAgo * DAY) },
      update: data,
    });
  }

  // Bharat Buyer, the emulator's person, holds a CONFIRMED place on the first (Riyadh) run: the app reads that
  // as the design's green CONFIRMED tile. Free courses enrol as PENDING through the API, so only this write
  // can make it CONFIRMED; withdrawing it in the app (it ends CANCELLED) is put back by the next run of the seed.
  // Pooja Professional is left without a place on purpose: she is the persona the live tests enrol, and a person
  // holds one place per course.
  const bharat = await prisma.user.findUnique({ where: { email: PERSONAS[0].email }, select: { id: true } });
  let placed = 'no place for Bharat (--no-enrol)';
  if (!enrol) {
    await prisma.learningEnrollment.deleteMany({ where: { id: L.enrolment } });
  } else if (!bharat) {
    placed = `! ${PERSONAS[0].email} not found: no place seeded`;
  } else {
    const first = RUNS[0];
    const startsAt = at(first.start[0], first.start[1]);
    const data = {
      courseId: L.course,
      batchId: L.batches[0],
      userId: bharat.id,
      status: 'CONFIRMED' as const,
      batchStartsAt: startsAt,
      decidedAt: now,
      completedAt: null,
    };
    await prisma.learningEnrollment.upsert({
      where: { courseId_userId: { courseId: L.course, userId: bharat.id } },
      create: { id: L.enrolment, ...data },
      update: data,
    });
    placed = `Bharat Buyer CONFIRMED on ${first.location}`;
  }

  log(
    `  learning: course ${COURSE.code} "${COURSE.title}" (published, free, first in its list), institute ICR Institute, ` +
      `specialist Bushra A., ${MODULES.length} modules, ${RUNS.length} runs in ${year} (` +
      `${RUNS.filter((r) => r.mode === 'IN_PERSON').length} face to face, ${RUNS.filter((r) => r.mode === 'VIRTUAL').length} virtual), ` +
      `${reviews.length} reviews (${reviews.map((r) => PEOPLE[r.author].first).join(', ')}); ${placed}`,
  );
}

// ---------------------------------------------------------------------------
// Removal
// ---------------------------------------------------------------------------

/**
 * Every step is tried on its own, and a person or company something else now depends on (another seed linked
 * them, a restrictive foreign key) is left in place with a line saying so, instead of aborting the removal.
 * Rows that merely point at ours with a cascading key (enrolments, applications, event attendance by a seeded
 * person...) go with them. Throws at the end if anything was left.
 */
async function removeAll(prisma: PrismaClient, log: (m: string) => void): Promise<void> {
  const problems: string[] = [];
  const why = (e: unknown) => String((e as Error)?.message ?? e).split('\n').filter(Boolean).pop()?.trim().slice(0, 140) ?? 'error';
  const step = async (label: string, run: () => Promise<{ count: number }>) => {
    try {
      log(`  removed ${(await run()).count} ${label}`);
    } catch (e) {
      problems.push(label);
      log(`  ! could not remove ${label}: ${why(e)}`);
    }
  };
  // One row at a time, so the one that is still in use does not keep the rest.
  const each = async (label: string, rows: { id: string; name: string }[], del: (id: string) => Promise<unknown>) => {
    let n = 0;
    for (const r of rows) {
      try {
        await del(r.id);
        n++;
      } catch (e) {
        problems.push(`${label} ${r.name}`);
        log(`  ! ${label} ${r.name} is still in use elsewhere, left in place: ${why(e)}`);
      }
    }
    log(`  removed ${n} ${label}`);
  };
  log('Removing everything this seed created (rows marked design-lj-, @learning-jobs.icr.test, source design-seed-lj).');

  // Learning: the course takes its modules, runs, reviews and any enrolments with it; then the institute and its team.
  await step('courses', () => prisma.learningCourse.deleteMany({ where: { id: { startsWith: MARK } } }));
  await step('institutes', () => prisma.learningProvider.deleteMany({ where: { id: { startsWith: MARK } } }));

  // Jobs: personas' extras first, then the jobs (applications go with them), the conversations a "Message" tap
  // opened with a seeded person, the companies, and the people.
  await step('applications', () =>
    prisma.application.deleteMany({ where: { OR: [{ id: { startsWith: MARK } }, { jobId: { startsWith: MARK } }] } }),
  );
  await step('saved job searches', () => prisma.savedJobSearch.deleteMany({ where: { id: { startsWith: MARK } } }));
  await step('education entries', () => prisma.userEducation.deleteMany({ where: { id: { startsWith: MARK } } }));
  await step('resumes', () => prisma.resume.deleteMany({ where: { id: { startsWith: MARK } } }));
  await step('jobs', () => prisma.job.deleteMany({ where: { id: { startsWith: MARK } } }));
  await step('conversations with seeded people', () =>
    prisma.conversation.deleteMany({ where: { participants: { some: { email: { endsWith: EMAIL_DOMAIN } } } } }),
  );
  await each(
    'companies',
    (await prisma.company.findMany({ where: { source: SOURCE }, select: { id: true, name: true } })),
    (id) => prisma.company.delete({ where: { id } }),
  );
  await each(
    'people',
    (await prisma.user.findMany({ where: { email: { endsWith: EMAIL_DOMAIN } }, select: { id: true, email: true } })).map((u) => ({ id: u.id, name: u.email })),
    (id) => prisma.user.delete({ where: { id } }),
  );

  // Files: the rows, then the files themselves.
  const files = await prisma.uploadedFile.findMany({ where: { filename: { startsWith: MARK } }, select: { filename: true } });
  await step('upload records', () => prisma.uploadedFile.deleteMany({ where: { filename: { startsWith: MARK } } }));
  let unlinked = 0;
  for (const f of files) {
    const path = join(process.cwd(), 'uploads', f.filename);
    if (existsSync(path)) {
      unlinkSync(path);
      unlinked++;
    }
  }
  log(`  removed ${unlinked} files from uploads/`);
  if (problems.length) throw new Error(`Removal left ${problems.length} thing(s) in place: ${problems.join('; ')}.`);
}

// ---------------------------------------------------------------------------
// Run alone: `... learning-jobs.ts [--remove] [--no-resume] [--no-enrol]`
// ---------------------------------------------------------------------------

if (require.main === module) {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { PrismaClient: Client } = require('@prisma/client') as typeof import('@prisma/client');
  const prisma = new Client();
  seedLearningJobs(prisma, (m) => console.log(m), {
    remove: process.argv.includes('--remove'),
    resume: !process.argv.includes('--no-resume'),
    enrol: !process.argv.includes('--no-enrol'),
  })
    .catch((e) => {
      console.error(e);
      process.exitCode = 1;
    })
    .finally(() => prisma.$disconnect());
}
