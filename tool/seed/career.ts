/**
 * Seeds the CAREER and HIRING flows of the mobile app into the LOCAL portal
 * database: what a member's applications, interviews, offers, saved and hidden
 * jobs, alerts and invitations look like, what a company's reviews, salaries and
 * interviews say, and an employer who can sign in with a pipeline of applicants.
 *
 *   cd E:\ICR\irc-portal\backend          (cwd must be the backend folder)
 *   NODE_PATH=E:/ICR/irc-portal/node_modules npx ts-node --transpile-only E:/ICR/icr-mobile/tool/seed/career.ts
 *   ... same command with --remove        (deletes exactly what this script created, and puts back what it changed)
 *
 * Idempotent: every row has a stable id and is upserted, so a re-run re-bases the dates ("applied 3 days ago", the
 * interview "in 3 days") and RESETS what the live tests spend (the sandbox application they withdraw, the offer
 * they decline, the invitations they answer). Run it AFTER learning-jobs.ts: that seed owns the jobs and the two
 * personas' résumé, and a re-run of it puts Bharat's applications back to their designed stages.
 *
 * What it seeds (marker in brackets: ids start `design-career-`, emails end `@career.icr.test`, companies have
 * source `design-seed-career`, Setting `design-seed:career` remembers what it changed):
 *
 *   Employer  Northwind Facilities (company), Meera Iyer (COMPANY_ADMIN) and Rohit Rao (RECRUITER), both
 *             `Career@12345`; the company's employer verification (VERIFIED, so publishing is not refused for want
 *             of it); 12 jobs in every status (open, draft, paused, closed, in review) in cities and with skills the
 *             two personas' boards never show; a pipeline of 9 applicants on one job (every stage, ratings, notes,
 *             screening answers, an interview with feedback, an offer); and a "hiring sandbox" job with ten applicants
 *             (all APPLIED, unseen) that the employer live tests move, rate, message, book and offer.
 *   Harbor    Harbor Soft Services, a second company whose employer verification has NOT been filed, and Tara Joshi
 *             (COMPANY_ADMIN, `Career@12345`): the account whose publish the API refuses until the company is verified.
 *   Pooja     applications in every state a tracker draws (an interview round to come, an offer to answer, not
 *             selected, withdrawn, a plain applied one), a sandbox application and a sandbox offer the live tests
 *             spend, two saved searches (2 new), two invitations, saved and hidden jobs. Her plan is the free one, so
 *             her tracker reads the "timeline is locked" notice.
 *   Bharat    his designed board is untouched ("My jobs 3", the Bengaluru alert and "2 new"). His second application
 *             moves to INTERVIEW with a round done and one to come (the count stays 3), one more is withdrawn, two
 *             older saved searches (created before the designed one, so the board's scope bar still reads it), an
 *             invitation, saved and hidden jobs.
 *   Insights  approved reviews, salaries (two roles with at least five reports) and interview experiences on Global
 *             Infra Solutions and on Northwind, and an empty "Insights Sandbox" company the live tests write to.
 *
 * Nothing existing is changed or deleted except: Bharat's second application (stage, events, interviews: restored on
 * --remove), and the leftovers of earlier live runs (reviews titled "MOBILE-LIVE …", salary and interview reports
 * titled "MOBILE-LIVE tester"), which are swept at every run.
 *
 * It refuses to run unless DATABASE_URL points at localhost.
 */
import type { Prisma, PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { existsSync, readFileSync } from 'fs';
import { join } from 'path';

// ---------------------------------------------------------------------------
// Markers and constants
// ---------------------------------------------------------------------------

const MARK = 'design-career-';
const SOURCE = 'design-seed-career';
const EMAIL_DOMAIN = '@career.icr.test';
const MANIFEST_KEY = 'design-seed:career';
const PASSWORD = 'Career@12345';
const HOUR = 3_600_000;
const DAY = 24 * HOUR;

/** learning-jobs.ts's ids, which this seed builds on. */
const GLOBAL_INFRA = 'design-lj-co-global-infra';
const BHARAT_EXTRA_2 = 'design-lj-app-bharat-extra-2';
const BHARAT_EXTRA_2_JOB = 'design-lj-job-extra-2';
const BHARAT_ALERT = 'design-lj-alert-bharat';

const BHARAT = 'buyer@icr.dev';
const POOJA = 'professional@icr.test';

/** What earlier live runs wrote and cannot delete through the API. */
const LIVE_REVIEW_TITLE = 'MOBILE-LIVE';
const LIVE_TITLE = 'MOBILE-LIVE tester';
/** What the employer live tests title the postings they make (they delete them; a run that died leaves one). */
const LIVE_JOB_TITLE = 'MOBILE-LIVE employer';

type Manifest = { bharatExtra2Stage?: string };

// ---------------------------------------------------------------------------
// Companies
// ---------------------------------------------------------------------------

const COMPANIES = {
  northwind: {
    id: `${MARK}co-northwind`,
    sourceId: 'northwind',
    name: 'Northwind Facilities',
    legalName: 'Northwind Facilities Pvt. Ltd.',
    city: 'Ahmedabad',
    state: 'Gujarat',
    industry: 'FM_SERVICES',
    verified: true,
    description:
      'Integrated facilities management for hospitals, campuses and logistics parks across western India: hard and soft services, energy and statutory compliance under one contract.',
  },
  harbor: {
    id: `${MARK}co-harbor`,
    sourceId: 'harbor',
    name: 'Harbor Soft Services',
    legalName: 'Harbor Soft Services Pvt. Ltd.',
    city: 'Pune',
    state: 'Maharashtra',
    industry: 'FM_SERVICES',
    verified: false,
    description: 'Housekeeping and soft services for offices in Pune. Its company check has not been filed yet, so it can draft jobs but not publish them.',
  },
  sandbox: {
    id: `${MARK}co-sandbox`,
    sourceId: 'sandbox',
    name: 'Insights Sandbox Co',
    legalName: 'Insights Sandbox Co Pvt. Ltd.',
    city: 'Jaipur',
    state: 'Rajasthan',
    industry: 'FM_SERVICES',
    verified: true,
    description: 'A company with no jobs and no reviews, where the mobile live tests write a review, a salary and an interview.',
  },
} as const;
type CompanyKey = keyof typeof COMPANIES;

// ---------------------------------------------------------------------------
// People
// ---------------------------------------------------------------------------

type PersonSeed = {
  first: string;
  last: string;
  designation: string;
  /** The company they work for as a hiring-team member (they can sign in). */
  team?: { company: CompanyKey; role: 'COMPANY_ADMIN' | 'RECRUITER' };
  /** A résumé: headline, years, skills, where, employer. Applicants have one. */
  resume?: { headline: string; years: number; skills: string[]; location: string; employer: string; notice?: number };
};

const PEOPLE: Record<string, PersonSeed> = {
  meera: { first: 'Meera', last: 'Iyer', designation: 'Head of Talent, Northwind Facilities', team: { company: 'northwind', role: 'COMPANY_ADMIN' } },
  rohit: { first: 'Rohit', last: 'Rao', designation: 'Senior Recruiter, Northwind Facilities', team: { company: 'northwind', role: 'RECRUITER' } },
  tara: { first: 'Tara', last: 'Joshi', designation: 'HR Manager, Harbor Soft Services', team: { company: 'harbor', role: 'COMPANY_ADMIN' } },
  aarav: {
    first: 'Aarav', last: 'Khanna', designation: 'Facilities Manager',
    resume: { headline: 'Facilities Manager - healthcare campuses', years: 11, skills: ['HVAC Chillers', 'Statutory Audits', 'Vendor SLAs', 'Budget Control'], location: 'Ahmedabad', employer: 'Apollo Hospitals', notice: 60 },
  },
  divya: {
    first: 'Divya', last: 'Menon', designation: 'Senior Facilities Manager',
    resume: { headline: 'Senior Facilities Manager - Grade-A offices', years: 9, skills: ['Soft Services', 'Space Planning', 'EHS Auditing', 'Vendor SLAs'], location: 'Surat', employer: 'Brigade Group', notice: 30 },
  },
  kabir: {
    first: 'Kabir', last: 'Sethi', designation: 'Operations Lead',
    resume: { headline: 'Operations Lead - logistics parks', years: 8, skills: ['Fire Safety', 'Shift Planning', 'Manpower Planning', 'Statutory Audits'], location: 'Vadodara', employer: 'JLL', notice: 45 },
  },
  nisha: {
    first: 'Nisha', last: 'Rao', designation: 'Facilities Operations Manager',
    resume: { headline: 'Facilities operations with a statutory-audit streak', years: 10, skills: ['Statutory Audits', 'Vendor SLAs', 'Preventive Maintenance Planning', 'Budget Control'], location: 'Ahmedabad', employer: 'Cushman & Wakefield', notice: 90 },
  },
  vikram: {
    first: 'Vikram', last: 'Desai', designation: 'Site Manager',
    resume: { headline: 'Site manager - industrial parks', years: 7, skills: ['Shift Planning', 'Fire Safety', 'Manpower Planning'], location: 'Rajkot', employer: 'Adani Logistics', notice: 30 },
  },
  sanjana: {
    first: 'Sanjana', last: 'Pillai', designation: 'Assistant Vice President - Facilities',
    resume: { headline: 'AVP Facilities - multi-site portfolio', years: 14, skills: ['Portfolio Operations', 'Vendor SLAs', 'Statutory Audits', 'Budget Control', 'EHS Auditing'], location: 'Mumbai', employer: 'Embassy Group', notice: 90 },
  },
  tejas: {
    first: 'Tejas', last: 'Kulkarni', designation: 'Deputy General Manager',
    resume: { headline: 'DGM Operations - hospitality and campuses', years: 13, skills: ['Soft Services', 'Vendor SLAs', 'Manpower Planning', 'Budget Control'], location: 'Pune', employer: 'Taj Hotels', notice: 60 },
  },
  ishita: {
    first: 'Ishita', last: 'Bose', designation: 'Regional Facilities Head',
    resume: { headline: 'Regional facilities head - 40 sites', years: 15, skills: ['Portfolio Operations', 'Statutory Audits', 'Vendor SLAs', 'EHS Auditing'], location: 'Kolkata', employer: 'RPG Group', notice: 90 },
  },
  harsh: {
    first: 'Harsh', last: 'Vora', designation: 'Facilities Executive',
    resume: { headline: 'Facilities executive, 4 years', years: 4, skills: ['Housekeeping Audits', 'Helpdesk Operations'], location: 'Ahmedabad', employer: 'Regus', notice: 15 },
  },
  // Wrote reviews and salary reports; no résumé.
  leela: { first: 'Leela', last: 'Nambiar', designation: 'Procurement Manager' },
  manav: { first: 'Manav', last: 'Joshi', designation: 'Electrical Engineer' },
  rhea: { first: 'Rhea', last: 'Kapoor', designation: 'HSE Officer' },
  yash: { first: 'Yash', last: 'Malhotra', designation: 'Energy Analyst' },
  zoya: { first: 'Zoya', last: 'Ansari', designation: 'Facility Supervisor' },
  omar: { first: 'Omar', last: 'Sheikh', designation: 'MEP Supervisor' },
  // Spare applicants of the hiring sandbox, so the employer live tests that cannot be undone (an offer sent, someone
  // hired) can run several times before the seed is re-run.
  asha: { first: 'Asha', last: 'Verma', designation: 'Facilities Coordinator' },
  bilal: { first: 'Bilal', last: 'Khan', designation: 'Helpdesk Lead' },
  chitra: { first: 'Chitra', last: 'Nair', designation: 'Site Supervisor' },
  dev: { first: 'Dev', last: 'Patel', designation: 'Maintenance Planner' },
};

const emailOf = (key: string) => `${PEOPLE[key].first}.${PEOPLE[key].last}`.toLowerCase().replace(/\s+/g, '-') + EMAIL_DOMAIN;
const userId = (key: string) => `${MARK}u-${key}`;

// ---------------------------------------------------------------------------
// Jobs
// ---------------------------------------------------------------------------

const body = (intro: string, duties: string[]) =>
  `<p>${intro}</p><h3>Key Responsibilities</h3><ul>${duties.map((d) => `<li>${d}</li>`).join('')}</ul>`;

type JobSeed = {
  key: string;
  title: string;
  status: 'OPEN' | 'DRAFT' | 'PAUSED' | 'CLOSED' | 'IN_REVIEW';
  city: string;
  state: string;
  /** Days since it went live; older than the board's own jobs so it never leads a section. */
  ageDays: number;
  skills: string[];
  html?: string;
  salary?: [number, number];
  experienceMin?: number;
  openings?: number;
  seniority?: 'MID' | 'SENIOR' | 'LEAD';
  workMode?: 'ONSITE' | 'HYBRID' | 'REMOTE';
  department?: string;
  screening?: { type: 'YEARS' | 'YES_NO' | 'SINGLE_SELECT'; prompt: string; options?: string[]; ideal?: string; mustHave?: boolean }[];
  deadlineInDays?: number;
  /** A posting for one gender (`JobGenderPreference`). */
  gender?: 'MALE' | 'FEMALE' | 'OTHER';
  /** The groups it is opened to, and whether it takes applications from nobody else. */
  diversity?: string[];
  diversityOnly?: boolean;
};

const JOBS: JobSeed[] = [
  {
    key: 'pipeline', title: 'Facilities Operations Lead', status: 'OPEN', city: 'Ahmedabad', state: 'Gujarat', ageDays: 14,
    skills: ['Statutory Audits', 'Manpower Planning', 'Shift Planning', 'Fire Safety'], salary: [1_500_000, 2_100_000], experienceMin: 7, openings: 2,
    seniority: 'LEAD', department: 'Operations', deadlineInDays: 20,
    html: body('Lead day-to-day facilities operations across four logistics parks in Gujarat: rosters, statutory audits and the vendors who run them.', [
      'Own shift planning and manpower for the parks, and keep every statutory record current.',
      'Hold hard and soft services vendors to their service levels and report weekly to the regional head.',
      'Run fire-safety drills and audits, and close every observation within its date.',
    ]),
    screening: [
      { type: 'YEARS', prompt: 'How many years have you run site operations?', ideal: '6', mustHave: true },
      { type: 'YES_NO', prompt: 'Can you work rotational shifts?', ideal: 'true' },
    ],
  },
  {
    key: 'hard', title: 'Senior Manager - Hard Services', status: 'OPEN', city: 'Pune', state: 'Maharashtra', ageDays: 16,
    skills: ['Chiller Plant', 'DG Sets', 'Fire Safety', 'Contract Management'], salary: [2_200_000, 3_000_000], experienceMin: 10, seniority: 'LEAD',
    html: body('Run the hard services for a 1.8M sq.ft. campus in Pune: chillers, DG sets, electrical and fire systems.', [
      'Plan preventive maintenance and critical spares so the plant never stops without warning.',
      'Manage O&M contractors against service levels and approve their invoices.',
      'Keep the campus audit-ready for statutory inspections.',
    ]),
  },
  {
    key: 'energy', title: 'Energy Manager', status: 'OPEN', city: 'Delhi', state: 'Delhi', ageDays: 17,
    skills: ['Energy Audits', 'ISO 50001', 'Solar PV', 'Demand Forecasting'], salary: [2_000_000, 2_800_000], experienceMin: 8, seniority: 'SENIOR',
    html: body('Own the energy programme for a portfolio of commercial towers in Delhi NCR.', [
      'Audit consumption monthly and track every site against its ISO 50001 target.',
      'Deliver solar PV and efficiency retrofits on budget.',
      'Report the portfolio carbon footprint to the board each quarter.',
    ]),
  },
  {
    key: 'soft', title: 'Soft Services Manager', status: 'CLOSED', city: 'Chennai', state: 'Tamil Nadu', ageDays: 40,
    skills: ['Housekeeping Audits', 'Pantry Operations', 'Client Reporting'], salary: [900_000, 1_300_000], experienceMin: 5, seniority: 'SENIOR',
    html: body('Manage housekeeping, pantry and front-of-house teams for a Grade-A office campus in Chennai.', [
      'Plan manpower and shifts for the soft services teams.',
      'Audit housekeeping and pantry standards every week.',
      'Report consumables, quality and client feedback to the site head.',
    ]),
  },
  {
    key: 'hse', title: 'HSE Officer', status: 'OPEN', city: 'Kolkata', state: 'West Bengal', ageDays: 18,
    skills: ['HSE Audits', 'Incident Investigation', 'ISO 45001'], salary: [800_000, 1_200_000], experienceMin: 4, seniority: 'MID',
    html: body('Keep a Kolkata logistics park safe: inspections, incident investigation and the safety culture that prevents the next one.', [
      'Run weekly safety inspections and close observations within their dates.',
      'Investigate every incident and near miss, and report the root cause.',
      'Train contractor staff on site rules before they start work.',
    ]),
  },
  {
    key: 'sandbox', title: 'Estate Manager (sandbox)', status: 'OPEN', city: 'Jaipur', state: 'Rajasthan', ageDays: 19,
    skills: ['Estate Management', 'Lease Administration'], salary: [1_000_000, 1_400_000], experienceMin: 5, seniority: 'SENIOR',
    html: body('A sandbox posting the mobile live tests apply to and withdraw from: estate management for a Jaipur retail portfolio.', [
      'Administer leases and renewals across the portfolio.',
      'Keep property tax and statutory filings current.',
      'Hold the tenant relations desk to its response targets.',
    ]),
  },
  {
    key: 'sandbox2', title: 'Facilities Planner (sandbox)', status: 'OPEN', city: 'Lucknow', state: 'Uttar Pradesh', ageDays: 20,
    skills: ['Space Planning', 'Capex Planning'], salary: [1_100_000, 1_500_000], experienceMin: 5, seniority: 'SENIOR',
    html: body('A sandbox posting the mobile live tests decline an offer on: facilities and space planning for a Lucknow office park.', [
      'Plan space and moves for the park, and brief the vendors who carry them out.',
      'Prepare the annual capex plan with the finance team.',
      'Track every project against its budget and date.',
    ]),
  },
  {
    key: 'hiringbox', title: 'Facilities Coordinator (hiring sandbox)', status: 'OPEN', city: 'Nashik', state: 'Maharashtra', ageDays: 24,
    skills: ['Facilities Coordination', 'Vendor Follow-up'], salary: [500_000, 800_000], experienceMin: 2, seniority: 'MID',
    html: body('A sandbox posting the mobile live tests run a hiring team on: they move, rate, message, book and offer its ten applicants.', [
      'Coordinate daily work orders between the helpdesk and the vendors.',
      'Chase every open ticket to closure and report the ones that slip.',
      'Keep the site registers and permits current.',
    ]),
  },
  {
    key: 'invite', title: 'Facility Operations Head', status: 'OPEN', city: 'Nagpur', state: 'Maharashtra', ageDays: 15,
    skills: ['Portfolio Operations', 'P&L Ownership', 'Client Management'], salary: [3_000_000, 4_000_000], experienceMin: 12, seniority: 'LEAD',
    html: body('Head facility operations for a five-site hospital group in central India, with the P&L for the function.', [
      'Own the operating budget and report variances monthly.',
      'Lead the site heads and the vendors who work under them.',
      'Bring every site to NABH facility standards.',
    ]),
  },
  {
    key: 'invite2', title: 'Procurement Lead - Facilities', status: 'OPEN', city: 'Indore', state: 'Madhya Pradesh', ageDays: 21,
    skills: ['Vendor Onboarding', 'Contract Negotiation', 'Rate Contracts'], salary: [1_800_000, 2_400_000], experienceMin: 8, seniority: 'SENIOR',
    html: body('Lead facilities procurement for a retail chain: rate contracts, vendor onboarding and spend control.', [
      'Run rate contracts for housekeeping, security and maintenance.',
      'Onboard and score vendors, and retire the ones who do not deliver.',
      'Report spend against budget every month.',
    ]),
  },
  // Two postings the apply form asks extra of: the live tests are refused on them (nothing is written).
  {
    key: 'womenonly', title: 'Facilities Supervisor (women returning to work)', status: 'OPEN', city: 'Surat', state: 'Gujarat', ageDays: 22,
    skills: ['Soft Services', 'Team Supervision'], salary: [600_000, 900_000], experienceMin: 2, seniority: 'MID',
    diversity: ['WOMEN_RETURNING'], diversityOnly: true,
    html: body('A returnship for women resuming work after a career break: supervise a soft services team at a Surat business park.', [
      'Run the daily roster for housekeeping and pantry staff.',
      'Report quality and consumables to the site manager each week.',
      'Train new joiners on site rules and safety.',
    ]),
  },
  {
    key: 'femaleonly', title: 'Hostel Warden (women only)', status: 'OPEN', city: 'Mysuru', state: 'Karnataka', ageDays: 23,
    skills: ['Hostel Operations', 'Resident Welfare'], salary: [500_000, 700_000], experienceMin: 3, seniority: 'MID', gender: 'FEMALE',
    html: body('Look after a women\'s residence for working professionals in Mysuru: safety, welfare and day-to-day running.', [
      'Be the first point of contact for residents, day and night on a rota.',
      'Keep the visitor, safety and maintenance registers current.',
      'Report incidents to the property manager the same day.',
    ]),
  },
  {
    key: 'draft', title: 'Soft Services Supervisor', status: 'DRAFT', city: 'Surat', state: 'Gujarat', ageDays: 3, skills: [],
  },
  {
    key: 'ready', title: 'Security Operations Manager', status: 'DRAFT', city: 'Ahmedabad', state: 'Gujarat', ageDays: 2,
    skills: ['Security Operations', 'Access Control', 'Vendor SLAs'], salary: [1_200_000, 1_700_000], experienceMin: 6, seniority: 'SENIOR',
    html: body('Run security for Northwind\'s hospital portfolio: guarding, access control, CCTV and the response plan when something goes wrong.', [
      'Plan guard rosters and post orders for every site.',
      'Audit access control and CCTV coverage quarterly.',
      'Run the incident response plan and report every incident within a day.',
    ]),
  },
  {
    key: 'paused', title: 'Sustainability Analyst', status: 'PAUSED', city: 'Bhopal', state: 'Madhya Pradesh', ageDays: 30,
    skills: ['Carbon Reporting', 'ESG Disclosures', 'Energy Audits'], salary: [700_000, 1_000_000], experienceMin: 2, seniority: 'MID',
    html: body('Support the sustainability programme: carbon reporting, ESG disclosures and the energy audits behind them.', [
      'Collect consumption data from every site each month.',
      'Prepare the carbon and ESG disclosures for the annual report.',
      'Track the portfolio against its reduction targets.',
    ]),
  },
];
const jobId = (key: string) => `${MARK}job-${key}`;

// ---------------------------------------------------------------------------
// Applications
// ---------------------------------------------------------------------------

type Stage = 'APPLIED' | 'SCREENING' | 'INTERVIEW' | 'OFFER' | 'HIRED' | 'REJECTED' | 'WITHDRAWN';

type InterviewSeed = {
  round: number;
  title: string;
  /** Days from now (negative: it happened). */
  inDays: number;
  hour: number;
  mode: 'VIDEO' | 'IN_PERSON' | 'PHONE';
  status?: 'SCHEDULED' | 'COMPLETED' | 'CANCELLED';
  mins?: number;
  link?: string;
  location?: string;
  mapLink?: string;
  notes?: string;
  feedback?: { rating: number; recommendation: 'STRONG_YES' | 'YES' | 'NO' | 'STRONG_NO'; strengths: string; concerns: string };
};

type OfferSeed = { status: 'SENT' | 'ACCEPTED' | 'DECLINED'; salary: number; title: string; joinInDays: number; expiresInDays: number; sentDaysAgo: number; notes?: string };

type AppSeed = {
  key: string;
  who: string; // PEOPLE key, or 'bharat' / 'pooja'
  job: string; // JOBS key, or an existing job id
  stage: Stage;
  /** Days since they applied. */
  ago: number;
  viewedAgo?: number;
  rating?: number;
  matchScore?: number;
  note?: string;
  cover?: string;
  salaryExpected?: number;
  answers?: string[];
  interviews?: InterviewSeed[];
  offer?: OfferSeed;
  withdrawnAgo?: number;
  rejectedAgo?: number;
  /** An existing application this seed only dresses (events, interviews). */
  existing?: string;
  signals?: { key: string; label: string; score: number; detail: string }[];
};

const APPS: AppSeed[] = [
  // Northwind's pipeline: the employer's live-test job.
  { key: 'aarav', who: 'aarav', job: 'pipeline', stage: 'APPLIED', ago: 2, matchScore: 82, answers: ['11', 'true'], cover: 'I have run three healthcare campuses for eleven years and would like to lead your logistics parks.' },
  { key: 'divya', who: 'divya', job: 'pipeline', stage: 'APPLIED', ago: 3, viewedAgo: 2, matchScore: 76, answers: ['9', 'true'] },
  { key: 'kabir', who: 'kabir', job: 'pipeline', stage: 'APPLIED', ago: 5, matchScore: 71, answers: ['8', 'false'] },
  { key: 'nisha', who: 'nisha', job: 'pipeline', stage: 'SCREENING', ago: 6, viewedAgo: 5, rating: 4, matchScore: 88, answers: ['10', 'true'], note: 'Strong on statutory audits; ask about her notice period.' },
  { key: 'vikram', who: 'vikram', job: 'pipeline', stage: 'SCREENING', ago: 7, viewedAgo: 6, rating: 3, matchScore: 64, answers: ['7', 'true'] },
  {
    key: 'sanjana', who: 'sanjana', job: 'pipeline', stage: 'INTERVIEW', ago: 9, viewedAgo: 8, rating: 5, matchScore: 91, answers: ['14', 'true'],
    interviews: [{ round: 1, title: 'Operations round', inDays: 2, hour: 15, mode: 'VIDEO', mins: 45, link: 'https://meet.example.com/northwind-ops-1', notes: 'Probe the multi-site rota she ran at Embassy.' }],
  },
  {
    key: 'tejas', who: 'tejas', job: 'pipeline', stage: 'INTERVIEW', ago: 10, viewedAgo: 9, rating: 4, matchScore: 85, answers: ['13', 'true'],
    interviews: [
      {
        round: 1, title: 'Screening call', inDays: -3, hour: 11, mode: 'PHONE', status: 'COMPLETED', mins: 30,
        feedback: { rating: 4, recommendation: 'YES', strengths: 'Clear about vendor management; has run hospitality estates.', concerns: 'Shorter on statutory audit depth.' },
      },
    ],
  },
  { key: 'ishita', who: 'ishita', job: 'pipeline', stage: 'OFFER', ago: 14, viewedAgo: 13, rating: 5, matchScore: 93, answers: ['15', 'true'], offer: { status: 'SENT', salary: 2_100_000, title: 'Facilities Operations Lead', joinInDays: 45, expiresInDays: 6, sentDaysAgo: 1, notes: 'Joining bonus of one month on completing probation.' } },
  { key: 'harsh', who: 'harsh', job: 'pipeline', stage: 'REJECTED', ago: 12, viewedAgo: 11, rating: 2, matchScore: 38, answers: ['4', 'true'], rejectedAgo: 8 },

  // The hiring sandbox: ten applicants the employer live tests spend (a re-run puts them back to APPLIED, unseen).
  { key: 'box-leela', who: 'leela', job: 'hiringbox', stage: 'APPLIED', ago: 4, matchScore: 61 },
  { key: 'box-manav', who: 'manav', job: 'hiringbox', stage: 'APPLIED', ago: 4, matchScore: 62 },
  { key: 'box-rhea', who: 'rhea', job: 'hiringbox', stage: 'APPLIED', ago: 3, matchScore: 63 },
  { key: 'box-yash', who: 'yash', job: 'hiringbox', stage: 'APPLIED', ago: 3, matchScore: 64 },
  { key: 'box-zoya', who: 'zoya', job: 'hiringbox', stage: 'APPLIED', ago: 2, matchScore: 65 },
  { key: 'box-omar', who: 'omar', job: 'hiringbox', stage: 'APPLIED', ago: 2, matchScore: 66 },
  { key: 'box-asha', who: 'asha', job: 'hiringbox', stage: 'APPLIED', ago: 2, matchScore: 67 },
  { key: 'box-bilal', who: 'bilal', job: 'hiringbox', stage: 'APPLIED', ago: 1, matchScore: 68 },
  { key: 'box-chitra', who: 'chitra', job: 'hiringbox', stage: 'APPLIED', ago: 1, matchScore: 69 },
  { key: 'box-dev', who: 'dev', job: 'hiringbox', stage: 'APPLIED', ago: 1, matchScore: 70 },

  // Pooja's tracker, one of each state, on Northwind's other jobs.
  {
    key: 'pooja-interview', who: 'pooja', job: 'hard', stage: 'INTERVIEW', ago: 12, viewedAgo: 11, matchScore: 87, salaryExpected: 2_600_000,
    cover: 'I have run chillers and DG sets for a 2M sq.ft. campus and would like to lead yours.',
    interviews: [
      { round: 1, title: 'Technical round', inDays: -4, hour: 11, mode: 'VIDEO', status: 'COMPLETED', mins: 45, link: 'https://meet.example.com/northwind-hard-1' },
      { round: 2, title: 'Site head round', inDays: 3, hour: 11, mode: 'VIDEO', mins: 45, link: 'https://meet.example.com/northwind-hard-2' },
      {
        round: 3, title: 'Campus walk and HR', inDays: 6, hour: 10, mode: 'IN_PERSON', mins: 90, location: 'Northwind Facilities, 4th Floor, Tech Park, Hinjewadi, Pune 411057',
        mapLink: 'https://maps.example.com/northwind-pune',
      },
    ],
  },
  {
    key: 'pooja-offer', who: 'pooja', job: 'energy', stage: 'OFFER', ago: 24, viewedAgo: 23, matchScore: 90, salaryExpected: 2_500_000,
    offer: { status: 'SENT', salary: 2_400_000, title: 'Energy Manager', joinInDays: 40, expiresInDays: 5, sentDaysAgo: 1, notes: 'Joining bonus of one month on completing probation.' },
    interviews: [{ round: 1, title: 'Panel interview', inDays: -9, hour: 15, mode: 'VIDEO', status: 'COMPLETED', mins: 60, link: 'https://meet.example.com/northwind-energy-1' }],
  },
  { key: 'pooja-rejected', who: 'pooja', job: 'soft', stage: 'REJECTED', ago: 34, viewedAgo: 33, matchScore: 52, rejectedAgo: 20 },
  { key: 'pooja-withdrawn', who: 'pooja', job: 'hse', stage: 'WITHDRAWN', ago: 15, matchScore: 60, withdrawnAgo: 10 },
  { key: 'pooja-applied', who: 'pooja', job: 'invite2', stage: 'APPLIED', ago: 2, matchScore: 69 },
  { key: 'pooja-sandbox', who: 'pooja', job: 'sandbox', stage: 'APPLIED', ago: 1, viewedAgo: 1, matchScore: 66 },
  {
    key: 'pooja-sandbox-offer', who: 'pooja', job: 'sandbox2', stage: 'OFFER', ago: 20, viewedAgo: 19, matchScore: 80,
    offer: { status: 'SENT', salary: 1_500_000, title: 'Facilities Planner', joinInDays: 35, expiresInDays: 12, sentDaysAgo: 2, notes: 'Offer for the live test to decline.' },
  },

  // Bharat: his designed second application moves on (count unchanged); one more is withdrawn.
  {
    key: 'bharat-interview', who: 'bharat', job: BHARAT_EXTRA_2_JOB, existing: BHARAT_EXTRA_2, stage: 'INTERVIEW', ago: 19, viewedAgo: 17, matchScore: 91,
    interviews: [
      { round: 1, title: 'HR screening', inDays: -5, hour: 10, mode: 'PHONE', status: 'COMPLETED', mins: 30 },
      { round: 2, title: 'Technical round', inDays: 3, hour: 15, mode: 'VIDEO', mins: 45, link: 'https://meet.example.com/globalinfra-energy-2' },
    ],
    signals: [
      { key: 'skillFit', label: 'Skills', score: 0.9, detail: '4 of 5 required skills are on your résumé.' },
      { key: 'experienceFit', label: 'Experience', score: 0.85, detail: '9.4 years against 8 asked.' },
      { key: 'locationFit', label: 'Location', score: 0.4, detail: 'The role is in Pune; your résumé says Bengaluru.' },
    ],
  },
  { key: 'bharat-withdrawn', who: 'bharat', job: 'hse', stage: 'WITHDRAWN', ago: 22, matchScore: 55, withdrawnAgo: 18 },
];

// ---------------------------------------------------------------------------
// Insights, alerts, invitations, bookmarks
// ---------------------------------------------------------------------------

type ReviewSeed = {
  author: string;
  rating: number;
  subs: [number, number, number, number, number];
  title: string;
  pros: string;
  cons: string;
  advice?: string;
  jobTitle?: string;
  status: 'CURRENT' | 'FORMER';
  verified?: boolean;
  daysAgo: number;
};

const REVIEWS: Record<'global' | 'northwind', ReviewSeed[]> = {
  global: [
    { author: 'leela', rating: 5, subs: [4, 4, 5, 5, 5], title: 'A place that lets facilities people lead', pros: 'Real ownership of the campus, a strong safety culture and leadership that listens.', cons: 'Shift changes can be sudden during audits.', advice: 'Keep investing in the engineers on the floor.', jobTitle: 'Facilities Manager', status: 'CURRENT', verified: true, daysAgo: 40 },
    { author: 'manav', rating: 4, subs: [3, 3, 4, 4, 5], title: 'Solid, with room to grow', pros: 'Learning on large Grade-A towers and good mentors.', cons: 'Pay reviews are once a year.', jobTitle: 'MEP Engineer', status: 'FORMER', daysAgo: 75 },
    { author: 'rhea', rating: 4, subs: [4, 3, 4, 4, 4], title: 'Safety is taken seriously', pros: 'Near-miss reporting is encouraged and acted on.', cons: 'Paperwork heavy.', jobTitle: 'HSE Officer', status: 'CURRENT', daysAgo: 20 },
    { author: 'yash', rating: 3, subs: [3, 3, 3, 3, 3], title: 'Good start, slow promotions', pros: 'Exposure to energy projects early.', cons: 'Promotion cycles are long.', jobTitle: 'Energy Analyst', status: 'FORMER', daysAgo: 120 },
  ],
  northwind: [
    { author: 'zoya', rating: 5, subs: [5, 4, 5, 5, 4], title: 'Hospitals taught me everything', pros: 'Real responsibility from the first month and a team that backs you.', cons: 'On-call weeks are tiring.', jobTitle: 'Facility Supervisor', status: 'CURRENT', verified: true, daysAgo: 30 },
    { author: 'omar', rating: 4, subs: [3, 4, 4, 4, 4], title: 'Good for MEP people', pros: 'You learn the whole plant, not just your trade.', cons: 'Travel between sites.', jobTitle: 'MEP Supervisor', status: 'CURRENT', daysAgo: 55 },
    { author: 'aarav', rating: 4, subs: [4, 4, 4, 4, 3], title: 'Decent employer, honest managers', pros: 'Targets are clear and fair.', cons: 'Growth paths could be clearer.', jobTitle: 'Facilities Manager', status: 'FORMER', daysAgo: 90 },
  ],
};

const SALARIES: Record<'global' | 'northwind', { title: string; city: string; years: number; amounts: number[] }[]> = {
  global: [
    { title: 'Facilities Manager', city: 'Bengaluru', years: 8, amounts: [1_400_000, 1_600_000, 1_800_000, 1_900_000, 2_200_000, 2_300_000] },
    { title: 'MEP Engineer', city: 'Bengaluru', years: 4.5, amounts: [600_000, 700_000, 800_000, 850_000, 950_000] },
  ],
  northwind: [{ title: 'Facilities Operations Lead', city: 'Ahmedabad', years: 9, amounts: [1_500_000, 1_650_000, 1_800_000, 1_950_000, 2_100_000] }],
};

const INTERVIEWS: Record<'global' | 'northwind', { author: string; title: string; difficulty: number; experience: number; outcome: string; process: string; questions?: string; days: number }[]> = {
  global: [
    { author: 'leela', title: 'Senior Facilities Manager', difficulty: 3, experience: 4, outcome: 'OFFER_ACCEPTED', process: 'A screening call, a technical round with the head of operations, then a site walk and HR.', questions: 'How would you bring a chiller plant back after a trip? Walk me through an audit you led.', days: 21 },
    { author: 'manav', title: 'MEP Engineer', difficulty: 4, experience: 3, outcome: 'NO_OFFER', process: 'Two technical rounds back to back, mostly on electrical systems and fault-finding.', questions: 'Explain how you would size a DG set for a new tower.', days: 14 },
    { author: 'rhea', title: 'HSE Officer', difficulty: 2, experience: 5, outcome: 'OFFER_ACCEPTED', process: 'One panel round and a short written case on an incident.', days: 10 },
  ],
  northwind: [
    { author: 'zoya', title: 'Facility Supervisor', difficulty: 3, experience: 4, outcome: 'OFFER_ACCEPTED', process: 'Phone screen, a site visit and a rota exercise.', days: 28 },
    { author: 'omar', title: 'MEP Supervisor', difficulty: 3, experience: 3, outcome: 'IN_PROGRESS', process: 'Technical round done; waiting to hear on the second.', days: 6 },
  ],
};

/** Saved searches (criteria as `GET /jobs` names them). `createdDaysAgo` older than the designed alert keeps Bharat's scope bar. */
const ALERTS: { id: string; owner: 'bharat' | 'pooja'; name: string; criteria: Record<string, unknown>; frequency: 'DAILY' | 'WEEKLY'; createdDaysAgo: number; lastRunDaysAgo: number }[] = [
  { id: `${MARK}alert-bharat-mep`, owner: 'bharat', name: 'Remote MEP roles', criteria: { search: 'MEP', workMode: 'REMOTE' }, frequency: 'WEEKLY', createdDaysAgo: 45, lastRunDaysAgo: 0 },
  { id: `${MARK}alert-bharat-energy`, owner: 'bharat', name: 'Energy roles in Pune', criteria: { search: 'energy', city: 'Pune' }, frequency: 'DAILY', createdDaysAgo: 40, lastRunDaysAgo: 0 },
  { id: `${MARK}alert-pooja-west`, owner: 'pooja', name: 'Facilities in Pune and Ahmedabad', criteria: { city: 'Pune,Ahmedabad', country: 'India' }, frequency: 'DAILY', createdDaysAgo: 30, lastRunDaysAgo: 30 },
  { id: `${MARK}alert-pooja-remote`, owner: 'pooja', name: 'Remote roles', criteria: { workMode: 'REMOTE' }, frequency: 'WEEKLY', createdDaysAgo: 25, lastRunDaysAgo: 0 },
];

const INVITES: { id: string; candidate: 'bharat' | 'pooja'; job: string; status: 'SENT' | 'VIEWED'; message: string; daysAgo: number }[] = [
  { id: `${MARK}invite-bharat-head`, candidate: 'bharat', job: 'invite', status: 'SENT', message: 'Your résumé is a strong fit for this role. We would like you to apply.', daysAgo: 1 },
  { id: `${MARK}invite-pooja-head`, candidate: 'pooja', job: 'invite', status: 'SENT', message: 'We saw your résumé and think you would do well leading our hospital group.', daysAgo: 2 },
  { id: `${MARK}invite-pooja-viewed`, candidate: 'pooja', job: 'invite2', status: 'VIEWED', message: 'Procurement for facilities is a step on from your current role. Interested?', daysAgo: 5 },
];

/** Bookmarks and "not interested", per person. */
const ACTIONS: { who: 'bharat' | 'pooja'; job: string; action: 'SAVED' | 'HIDDEN' }[] = [
  { who: 'bharat', job: 'hard', action: 'SAVED' },
  { who: 'bharat', job: 'energy', action: 'SAVED' },
  { who: 'bharat', job: 'sandbox', action: 'SAVED' },
  { who: 'bharat', job: 'invite2', action: 'HIDDEN' },
  { who: 'pooja', job: 'pipeline', action: 'SAVED' },
  { who: 'pooja', job: 'invite', action: 'SAVED' },
  { who: 'pooja', job: 'sandbox2', action: 'HIDDEN' },
];

// ---------------------------------------------------------------------------
// Guards (the same as the other seeds')
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
  if (process.env.NODE_ENV === 'production') throw new Error('Refusing to seed a development password into production.');
}

function assertBackendCwd(): void {
  if (!existsSync(join(process.cwd(), 'prisma', 'schema.prisma'))) {
    throw new Error(`Run this from the portal's backend folder (E:\\ICR\\irc-portal\\backend); cwd is ${process.cwd()}.`);
  }
}

// ---------------------------------------------------------------------------
// The seed
// ---------------------------------------------------------------------------

type Ctx = {
  prisma: PrismaClient;
  log: (m: string) => void;
  now: Date;
  /** key -> user id, for the seeded people and the two personas. */
  users: Record<string, string>;
  /** Application id by AppSeed key. */
  apps: Record<string, string>;
};

const ago = (now: Date, days: number, hour?: number) => {
  const d = new Date(now.getTime() - days * DAY);
  if (hour !== undefined) d.setHours(hour, 0, 0, 0);
  return d;
};
const inDays = (now: Date, days: number, hour: number) => {
  const d = new Date(now.getTime() + days * DAY);
  d.setHours(hour, 0, 0, 0);
  return d;
};

export async function seedCareer(
  prisma: PrismaClient,
  log: (m: string) => void,
  opts: { remove?: boolean } = {},
): Promise<void> {
  assertLocalDatabase();
  assertBackendCwd();
  if (opts.remove) {
    await removeAll(prisma, log);
    return;
  }
  const now = new Date();
  log('Seeding the career and hiring flows into the local database.');

  const personas = await prisma.user.findMany({ where: { email: { in: [BHARAT, POOJA] } }, select: { id: true, email: true } });
  const bharat = personas.find((u) => u.email === BHARAT);
  const pooja = personas.find((u) => u.email === POOJA);
  if (!bharat || !pooja) throw new Error('Bharat Buyer and Pooja Professional must exist (db:seed:test-users).');
  if (!(await prisma.company.findUnique({ where: { id: GLOBAL_INFRA }, select: { id: true } }))) {
    throw new Error('Run learning-jobs.ts first: the Global Infra company and the personas\' applications come from it.');
  }
  const ctx: Ctx = { prisma, log, now, users: { bharat: bharat.id, pooja: pooja.id }, apps: {} };

  await sweepLiveLeftovers(ctx);
  await seedCompanies(ctx);
  await seedPeople(ctx);
  await seedJobs(ctx);
  await seedApplications(ctx);
  await seedInsights(ctx);
  await seedAlertsInvitesActions(ctx);

  const [jobs, apps, people] = await Promise.all([
    prisma.job.count({ where: { id: { startsWith: MARK } } }),
    prisma.application.count({ where: { OR: [{ id: { startsWith: MARK } }, { jobId: { startsWith: MARK } }] } }),
    prisma.user.count({ where: { email: { endsWith: EMAIL_DOMAIN } } }),
  ]);
  log(`Done. ${jobs} jobs, ${apps} applications, ${people} people. Employer: ${emailOf('meera')} / ${PASSWORD} (COMPANY_ADMIN), ${emailOf('rohit')} / ${PASSWORD} (RECRUITER); unverified company: ${emailOf('tara')} / ${PASSWORD}.`);
}

/** Reviews, salaries and interview experiences earlier live runs wrote: the API cannot delete them. */
async function sweepLiveLeftovers({ prisma, log }: Ctx): Promise<void> {
  const reviews = await prisma.employerReview.deleteMany({ where: { title: { startsWith: LIVE_REVIEW_TITLE } } });
  const salaries = await prisma.salaryReport.deleteMany({ where: { jobTitle: LIVE_TITLE } });
  const interviews = await prisma.interviewReview.deleteMany({ where: { jobTitle: LIVE_TITLE } });
  const stray = await prisma.job.findMany({
    where: { title: { startsWith: LIVE_JOB_TITLE }, companyId: { in: [COMPANIES.northwind.id, COMPANIES.harbor.id] } },
    select: { id: true },
  });
  if (stray.length) {
    const ids = stray.map((j) => j.id);
    await prisma.jobScreeningQuestion.deleteMany({ where: { jobId: { in: ids } } });
    await prisma.job.deleteMany({ where: { id: { in: ids } } });
  }
  if (reviews.count + salaries.count + interviews.count + stray.length > 0) {
    log(`  swept the leftovers of earlier live runs: ${reviews.count} review(s), ${salaries.count} salary report(s), ${interviews.count} interview experience(s), ${stray.length} posting(s)`);
  }
}

async function seedCompanies({ prisma, log }: Ctx): Promise<void> {
  for (const c of Object.values(COMPANIES)) {
    const data = {
      name: c.name,
      legalName: c.legalName,
      type: 'REAL_ESTATE' as const,
      size: '201-500',
      city: c.city,
      state: c.state,
      country: 'India',
      description: c.description,
      industry: c.industry,
      verificationStatus: (c.verified ? 'VERIFIED' : 'PENDING') as never,
      verificationLevel: (c.verified ? 'VERIFIED' : 'REGISTERED') as never,
      verifiedAt: c.verified ? new Date() : null,
      source: SOURCE,
      sourceId: c.sourceId,
    };
    await prisma.company.upsert({ where: { id: c.id }, create: { id: c.id, ...data }, update: { ...data, verifiedAt: c.verified ? undefined : null } });
  }
  log(`  companies: ${Object.keys(COMPANIES).length} (source '${SOURCE}')`);
}

async function seedPeople(ctx: Ctx): Promise<void> {
  const { prisma, log, now } = ctx;
  const hash = bcrypt.hashSync(PASSWORD, 10);
  for (const [key, p] of Object.entries(PEOPLE)) {
    const id = userId(key);
    const company = p.team ? COMPANIES[p.team.company].id : null;
    const data = {
      firstName: p.first,
      lastName: p.last,
      designation: p.designation,
      role: (p.team?.role ?? 'PROFESSIONAL') as never,
      personalRole: 'PROFESSIONAL' as never,
      companyId: company,
      isActive: true,
      emailVerifiedAt: new Date(),
      // Only the hiring team signs in.
      passwordHash: p.team ? hash : null,
    };
    const email = emailOf(key);
    const user = await prisma.user.upsert({ where: { email }, create: { id, email, ...data }, update: data });
    ctx.users[key] = user.id;

    if (p.team) {
      const found = await prisma.companyMembership.findFirst({ where: { userId: user.id, companyId: company!, status: 'ACTIVE' } });
      if (found) {
        if (found.role !== p.team.role) await prisma.companyMembership.update({ where: { id: found.id }, data: { role: p.team.role as never } });
      } else {
        await prisma.companyMembership.create({
          data: { userId: user.id, companyId: company!, role: p.team.role as never, status: 'ACTIVE', source: (p.team.role === 'COMPANY_ADMIN' ? 'FOUNDER' : 'ADDED') as never },
        });
      }
    }

    if (p.resume) {
      const r = p.resume;
      const data = {
        userId: user.id,
        title: `${p.first}'s résumé`,
        content: { headline: r.headline, skills: r.skills, yearsExperience: r.years },
        isDefault: true,
        discoverable: false,
        headline: r.headline,
        skills: r.skills,
        experienceYears: r.years,
        currentLocation: r.location,
        currentCompany: r.employer,
        noticePeriodDays: r.notice ?? null,
        summary: `${r.headline}. ${r.years} years, last at ${r.employer}.`,
      };
      const resumeId = `${MARK}resume-${key}`;
      await prisma.resume.upsert({ where: { id: resumeId }, create: { id: resumeId, ...data }, update: data });
    }
  }

  // Northwind's employer verification: without it every publish is refused for want of a verified company.
  const meera = ctx.users.meera;
  const verification = {
    companyId: COMPANIES.northwind.id,
    status: 'VERIFIED' as never,
    legalName: COMPANIES.northwind.legalName,
    panNumber: 'AAACN1234C',
    gstNumber: '24AAACN1234C1ZX',
    addressLine: '12 Science City Road, Sola',
    city: 'Ahmedabad',
    state: 'Gujarat',
    country: 'India',
    postalCode: '380060',
    contactEmail: 'hr@northwind-facilities.example',
    submittedById: meera,
    reviewedAt: now,
  };
  await prisma.employerVerification.upsert({
    where: { companyId: COMPANIES.northwind.id },
    create: { id: `${MARK}ev-northwind`, ...verification },
    update: verification,
  });
  log(`  people: ${Object.keys(PEOPLE).length} (${EMAIL_DOMAIN}); the hiring team signs in with ${PASSWORD}; Northwind is employer-verified`);
}

async function seedJobs(ctx: Ctx): Promise<void> {
  const { prisma, log, now } = ctx;
  const company = COMPANIES.northwind.id;
  for (const j of JOBS) {
    const live = j.status === 'OPEN' || j.status === 'PAUSED' || j.status === 'CLOSED';
    const at = ago(now, j.ageDays);
    const poster = ctx.users[j.key === 'hse' || j.key === 'paused' ? 'rohit' : 'meera'];
    const data: Prisma.JobUncheckedCreateInput = {
      title: j.title,
      description: j.html ?? null,
      location: `${j.city}, ${j.state}, India`,
      city: j.city,
      cities: [j.city],
      state: j.state,
      country: 'India',
      status: j.status as never,
      companyId: company,
      postedById: poster,
      publishedById: live ? poster : null,
      recruiterId: ctx.users.meera,
      publishedAt: live ? at : null,
      createdAt: at,
      salaryMin: j.salary?.[0] ?? null,
      salaryMax: j.salary?.[1] ?? null,
      salaryCurrency: 'INR',
      salaryPeriod: 'YEARLY',
      salaryVisible: true,
      showHiringContact: true,
      employmentType: 'FULL_TIME',
      workMode: (j.workMode ?? 'ONSITE') as never,
      experienceMin: j.experienceMin ?? null,
      department: j.department ?? null,
      seniority: (j.seniority ?? null) as never,
      skills: j.skills,
      qualifications: [],
      educationQualifications: [],
      preferredQualifications: [],
      preferredSkills: [],
      openings: j.openings ?? 1,
      applyMethod: 'ON_PLATFORM',
      requireResume: false,
      applyDeadline: j.deadlineInDays ? inDays(now, j.deadlineInDays, 18) : null,
      jobFunctions: ['FACILITIES_OPS'],
      industries: ['CRE_SERVICES'],
      genderPreference: (j.gender ?? 'ANY') as never,
      diversityCategories: (j.diversity ?? []) as never,
      diversityOnly: j.diversityOnly ?? false,
      deletedAt: null,
    };
    const id = jobId(j.key);
    await prisma.job.upsert({ where: { id }, create: { id, ...data }, update: data });

    // Screening questions: replaced, so the ids stay stable and the answers point at them.
    await prisma.jobScreeningQuestion.deleteMany({ where: { jobId: id, id: { not: { startsWith: `${MARK}q-${j.key}-` } } } });
    for (const [i, q] of (j.screening ?? []).entries()) {
      const qid = `${MARK}q-${j.key}-${i + 1}`;
      const qdata = {
        jobId: id,
        order: i,
        type: q.type as never,
        prompt: q.prompt,
        options: q.options ?? [],
        idealAnswer: q.ideal ?? null,
        mustHave: q.mustHave ?? false,
      };
      await prisma.jobScreeningQuestion.upsert({ where: { id: qid }, create: { id: qid, ...qdata }, update: qdata });
    }
  }
  log(`  jobs: ${JOBS.length} at Northwind (${JOBS.filter((j) => j.status === 'OPEN').length} open, ${JOBS.filter((j) => j.status === 'DRAFT').length} drafts, one paused, one closed)`);
}

/** The events a candidate's timeline and the recruiter's activity tab read, from the stage the application is at. */
function eventsFor(a: AppSeed, now: Date): { type: string; from?: Stage; to?: Stage; note?: string; rating?: number; visibility: 'CANDIDATE' | 'INTERNAL'; at: Date }[] {
  const events: ReturnType<typeof eventsFor> = [];
  events.push({ type: 'STAGE_CHANGE', to: 'APPLIED', visibility: 'CANDIDATE', at: ago(now, a.ago) });
  if (a.viewedAgo !== undefined) events.push({ type: 'VIEWED', visibility: 'CANDIDATE', at: ago(now, a.viewedAgo) });

  // Where the application got to before it ended, if it ended.
  const path: Stage[] = ['APPLIED', 'SCREENING', 'INTERVIEW', 'OFFER', 'HIRED'];
  const reached =
    a.stage === 'REJECTED' || a.stage === 'WITHDRAWN'
      ? a.interviews?.length ? 2 : a.viewedAgo !== undefined ? 1 : 0
      : path.indexOf(a.stage);
  // Each stage change lands between the first look and today, evenly, never before the one that came first.
  const start = a.viewedAgo ?? a.ago;
  const daysAgo: number[] = [a.ago];
  for (let i = 1; i <= reached; i++) {
    let d = Math.max(start - (i * Math.max(start - 0.5, 0.5)) / (reached + 1), 0.3);
    if (a.offer && path[i] === 'OFFER') d = a.offer.sentDaysAgo + 0.05;
    daysAgo[i] = Math.min(d, daysAgo[i - 1] - 0.05);
    events.push({ type: 'STAGE_CHANGE', from: path[i - 1], to: path[i], visibility: 'CANDIDATE', at: ago(now, Math.max(daysAgo[i], 0.05)) });
  }
  const interviewDay = daysAgo[2] ?? start;
  if (a.note) events.push({ type: 'NOTE', note: a.note, visibility: 'INTERNAL', at: ago(now, Math.max(start - 1, 0.2)) });
  if (a.rating) events.push({ type: 'RATING', rating: a.rating, visibility: 'INTERNAL', at: ago(now, Math.max(start - 1, 0.2)) });
  for (const iv of a.interviews ?? []) {
    events.push({ type: 'INTERVIEW_SCHEDULED', note: iv.title, visibility: 'CANDIDATE', at: ago(now, Math.max(interviewDay - 0.02, 0.04)) });
  }
  if (a.offer) events.push({ type: 'OFFER_SENT', visibility: 'CANDIDATE', at: ago(now, a.offer.sentDaysAgo) });
  if (a.stage === 'REJECTED') {
    events.push({ type: 'STAGE_CHANGE', from: path[reached], to: 'REJECTED', visibility: 'CANDIDATE', at: ago(now, a.rejectedAgo ?? 1) });
  }
  if (a.stage === 'WITHDRAWN') {
    events.push({ type: 'WITHDRAWN', from: path[reached], to: 'WITHDRAWN', visibility: 'CANDIDATE', at: ago(now, a.withdrawnAgo ?? 1) });
  }
  return events.sort((x, y) => x.at.getTime() - y.at.getTime());
}

async function seedApplications(ctx: Ctx): Promise<void> {
  const { prisma, log, now } = ctx;
  const manifest = await readManifest(prisma);
  let interviews = 0;
  let offers = 0;
  for (const a of APPS) {
    const jid = JOBS.some((j) => j.key === a.job) ? jobId(a.job) : a.job;
    const uid = ctx.users[a.who];
    const resumeId = PEOPLE[a.who]?.resume
      ? `${MARK}resume-${a.who}`
      : (await prisma.resume.findFirst({ where: { userId: uid, isDefault: true }, select: { id: true } }))?.id ?? null;
    const id = a.existing ?? `${MARK}app-${a.key}`;
    const data = {
      jobId: jid,
      applicantId: uid,
      resumeId,
      stage: a.stage as never,
      source: 'DIRECT' as never,
      coverNote: a.cover ?? null,
      expectedSalary: a.salaryExpected ?? null,
      viewedAt: a.viewedAgo !== undefined ? ago(now, a.viewedAgo) : null,
      withdrawnAt: a.stage === 'WITHDRAWN' ? ago(now, a.withdrawnAgo ?? 1) : null,
      matchScore: a.matchScore ?? null,
      rating: a.rating ?? null,
      screeningSignals: (a.signals ?? null) as never,
      screenedAt: a.matchScore ? ago(now, a.ago) : null,
    };
    if (a.existing) {
      // Bharat's designed application: remember its designed stage, then dress it.
      if (!manifest.bharatExtra2Stage) {
        const was = await prisma.application.findUnique({ where: { id }, select: { stage: true } });
        if (!was) throw new Error(`${id} not found: run learning-jobs.ts first.`);
        manifest.bharatExtra2Stage = was.stage;
        await writeManifest(prisma, manifest);
      }
      await prisma.application.update({ where: { id }, data: { stage: data.stage, viewedAt: data.viewedAt, matchScore: data.matchScore, screeningSignals: data.screeningSignals, screenedAt: data.screenedAt } });
    } else {
      await prisma.application.upsert({ where: { id }, create: { id, ...data, createdAt: ago(now, a.ago) }, update: { ...data, createdAt: ago(now, a.ago) } });
    }
    ctx.apps[a.key] = id;

    // Screening answers.
    const questions = JOBS.find((j) => j.key === a.job)?.screening ?? [];
    await prisma.applicationAnswer.deleteMany({ where: { applicationId: id } });
    for (const [i, q] of questions.entries()) {
      const answer = a.answers?.[i];
      if (answer === undefined) continue;
      await prisma.applicationAnswer.create({
        data: { applicationId: id, questionId: `${MARK}q-${a.job}-${i + 1}`, answer, meetsIdeal: q.ideal ? (q.type === 'YES_NO' ? answer === q.ideal : Number(answer) >= Number(q.ideal)) : false },
      });
    }

    // Timeline, interviews and offers are replaced so a re-run re-bases them and drops what tests added.
    await prisma.applicationEvent.deleteMany({ where: { applicationId: id } });
    const actor = ctx.users.meera;
    for (const e of eventsFor(a, now)) {
      await prisma.applicationEvent.create({
        data: {
          applicationId: id,
          type: e.type as never,
          fromStage: (e.from ?? null) as never,
          toStage: (e.to ?? null) as never,
          note: e.note ?? null,
          rating: e.rating ?? null,
          visibility: e.visibility as never,
          actorId: e.type === 'STAGE_CHANGE' && e.to === 'APPLIED' ? uid : actor,
          createdAt: e.at,
        },
      });
    }

    await prisma.interview.deleteMany({ where: { applicationId: id } });
    for (const iv of a.interviews ?? []) {
      const ivId = `${MARK}iv-${a.key}-${iv.round}`;
      const created = await prisma.interview.create({
        data: {
          id: ivId,
          applicationId: id,
          round: iv.round,
          title: iv.title,
          scheduledAt: inDays(now, iv.inDays, iv.hour),
          durationMins: iv.mins ?? 60,
          mode: iv.mode as never,
          location: iv.location ?? null,
          meetingLink: iv.link ?? null,
          mapLink: iv.mapLink ?? null,
          status: (iv.status ?? 'SCHEDULED') as never,
          notes: iv.notes ?? null,
          createdById: ctx.users.meera,
          interviewers: { connect: [{ id: ctx.users.meera }] },
        },
      });
      if (iv.feedback) {
        await prisma.interviewFeedback.create({
          data: {
            interviewId: created.id,
            interviewerId: ctx.users.meera,
            overallRating: iv.feedback.rating,
            recommendation: iv.feedback.recommendation as never,
            strengths: iv.feedback.strengths,
            concerns: iv.feedback.concerns,
          },
        });
      }
      interviews++;
    }

    await prisma.offer.deleteMany({ where: { applicationId: id } });
    if (a.offer) {
      await prisma.offer.create({
        data: {
          id: `${MARK}offer-${a.key}`,
          applicationId: id,
          status: a.offer.status as never,
          salaryAmount: a.offer.salary,
          salaryCurrency: 'INR',
          salaryPeriod: 'YEARLY',
          jobTitle: a.offer.title,
          joiningDate: inDays(now, a.offer.joinInDays, 9),
          expiresAt: inDays(now, a.offer.expiresInDays, 18),
          notes: a.offer.notes ?? null,
          sentAt: ago(now, a.offer.sentDaysAgo),
          createdById: ctx.users.meera,
        },
      });
      offers++;
    }
  }
  log(`  applications: ${APPS.length} (${interviews} interview rounds, ${offers} offers); Bharat's second application is at INTERVIEW (his count stays 3)`);
}

async function seedInsights(ctx: Ctx): Promise<void> {
  const { prisma, log, now } = ctx;
  const places: Record<'global' | 'northwind', string> = { global: GLOBAL_INFRA, northwind: COMPANIES.northwind.id };
  let reviews = 0;
  let salaries = 0;
  let talks = 0;
  for (const place of ['global', 'northwind'] as const) {
    const companyId = places[place];
    for (const r of REVIEWS[place]) {
      const id = `${MARK}review-${place}-${r.author}`;
      const data = {
        companyId,
        authorId: ctx.users[r.author],
        overallRating: r.rating,
        ratingWorkLife: r.subs[0],
        ratingCompensation: r.subs[1],
        ratingCulture: r.subs[2],
        ratingManagement: r.subs[3],
        ratingGrowth: r.subs[4],
        title: r.title,
        pros: r.pros,
        cons: r.cons,
        advice: r.advice ?? null,
        jobTitle: r.jobTitle ?? null,
        employmentStatus: r.status,
        isVerifiedEmployee: r.verified ?? false,
        status: 'APPROVED' as never,
        createdAt: ago(now, r.daysAgo),
      };
      await prisma.employerReview.upsert({ where: { id }, create: { id, ...data }, update: data });
      reviews++;
    }
    for (const s of SALARIES[place]) {
      const authors = ['leela', 'manav', 'rhea', 'yash', 'zoya', 'omar'];
      for (const [i, amount] of s.amounts.entries()) {
        const id = `${MARK}salary-${place}-${s.title.replace(/\W+/g, '-').toLowerCase()}-${i}`;
        const data = {
          companyId,
          authorId: ctx.users[authors[i % authors.length]],
          jobTitle: s.title,
          city: s.city,
          salaryAmount: amount,
          salaryCurrency: 'INR',
          salaryPeriod: 'YEARLY' as never,
          yearsExperience: s.years,
          employmentStatus: i % 2 === 0 ? 'CURRENT' : 'FORMER',
          status: 'APPROVED' as never,
        };
        await prisma.salaryReport.upsert({ where: { id }, create: { id, ...data }, update: data });
        salaries++;
      }
    }
    for (const t of INTERVIEWS[place]) {
      const id = `${MARK}interview-${place}-${t.author}`;
      const data = {
        companyId,
        authorId: ctx.users[t.author],
        jobTitle: t.title,
        difficulty: t.difficulty,
        experienceRating: t.experience,
        outcome: t.outcome,
        processDescription: t.process,
        questionsAsked: t.questions ?? null,
        durationDays: t.days,
        status: 'APPROVED' as never,
        createdAt: ago(now, t.days),
      };
      await prisma.interviewReview.upsert({ where: { id }, create: { id, ...data }, update: data });
      talks++;
    }
  }
  log(`  insights: ${reviews} approved reviews, ${salaries} salary reports, ${talks} interview experiences (Global Infra and Northwind); the sandbox company is empty`);
}

async function seedAlertsInvitesActions(ctx: Ctx): Promise<void> {
  const { prisma, log, now } = ctx;
  for (const a of ALERTS) {
    const owner = ctx.users[a.owner];
    const clash = await prisma.savedJobSearch.findUnique({ where: { userId_name: { userId: owner, name: a.name } } });
    if (clash && clash.id !== a.id) {
      log(`  ! ${a.owner} already has a saved search named "${a.name}": left alone`);
      continue;
    }
    const data = {
      userId: owner,
      name: a.name,
      criteria: a.criteria as never,
      // Off: the daily sweep would email a digest.
      alertsEnabled: false,
      frequency: a.frequency as never,
      lastRunAt: ago(now, a.lastRunDaysAgo),
      lastNotifiedAt: ago(now, a.lastRunDaysAgo),
      lastMatchCount: 0,
      createdAt: ago(now, a.createdDaysAgo),
    };
    await prisma.savedJobSearch.upsert({ where: { id: a.id }, create: { id: a.id, ...data }, update: data });
  }
  // Bharat's designed alert must stay his newest, or the board's scope bar would read another search.
  const designed = await prisma.savedJobSearch.findUnique({ where: { id: BHARAT_ALERT }, select: { createdAt: true } });
  if (designed) {
    const newestMine = Math.max(...ALERTS.filter((a) => a.owner === 'bharat').map((a) => ago(now, a.createdDaysAgo).getTime()));
    if (designed.createdAt.getTime() < newestMine) {
      await prisma.savedJobSearch.update({ where: { id: BHARAT_ALERT }, data: { createdAt: now } });
      log('  moved Bharat\'s designed alert to the newest, so the board\'s scope bar still reads it');
    }
  }

  for (const inv of INVITES) {
    const data = {
      jobId: jobId(inv.job),
      candidateId: ctx.users[inv.candidate],
      invitedById: ctx.users.meera,
      message: inv.message,
      status: inv.status as never,
      respondedAt: null,
      createdAt: ago(now, inv.daysAgo),
    };
    await prisma.jobInvite.upsert({ where: { id: inv.id }, create: { id: inv.id, ...data }, update: data });
  }

  for (const act of ACTIONS) {
    const id = `${MARK}act-${act.who}-${act.job}-${act.action.toLowerCase()}`;
    const data = { userId: ctx.users[act.who], jobId: jobId(act.job), action: act.action as never };
    // By what makes a bookmark unique, not by id: the app's own taps write rows of their own for the same job.
    await prisma.jobUserAction.upsert({
      where: { userId_jobId_action: { userId: data.userId, jobId: data.jobId, action: data.action } },
      create: { id, ...data },
      update: {},
    });
  }
  log(`  alerts: ${ALERTS.length}; invitations: ${INVITES.length}; bookmarks and hidden jobs: ${ACTIONS.length}`);
}

// ---------------------------------------------------------------------------
// Manifest and removal
// ---------------------------------------------------------------------------

async function readManifest(prisma: PrismaClient): Promise<Manifest> {
  const row = await prisma.setting.findUnique({ where: { key: MANIFEST_KEY }, select: { value: true } });
  return (row?.value as Manifest | null) ?? {};
}

async function writeManifest(prisma: PrismaClient, manifest: Manifest): Promise<void> {
  await prisma.setting.upsert({ where: { key: MANIFEST_KEY }, update: { value: manifest as never }, create: { key: MANIFEST_KEY, value: manifest as never } });
}

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
  log('Removing everything this seed created (ids design-career-, emails @career.icr.test, source design-seed-career).');

  const manifest = await readManifest(prisma);
  // Bharat's designed application goes back to what learning-jobs made it, bare.
  const dressed = await prisma.application.findUnique({ where: { id: BHARAT_EXTRA_2 }, select: { id: true } });
  if (dressed) {
    await prisma.applicationEvent.deleteMany({ where: { applicationId: BHARAT_EXTRA_2 } });
    await prisma.interview.deleteMany({ where: { applicationId: BHARAT_EXTRA_2 } });
    await prisma.application.update({
      where: { id: BHARAT_EXTRA_2 },
      data: { stage: (manifest.bharatExtra2Stage ?? 'SCREENING') as never, viewedAt: null, matchScore: null, screeningSignals: null as never, screenedAt: null },
    });
    log(`  restored Bharat's second application to ${manifest.bharatExtra2Stage ?? 'SCREENING'}`);
  }

  const people = (await prisma.user.findMany({ where: { email: { endsWith: EMAIL_DOMAIN } }, select: { id: true, email: true } }));
  const ids = people.map((p) => p.id);

  await step('applications', () =>
    prisma.application.deleteMany({ where: { OR: [{ id: { startsWith: MARK } }, { jobId: { startsWith: MARK } }, { applicantId: { in: ids } }] } }),
  );
  await step('invitations', () => prisma.jobInvite.deleteMany({ where: { OR: [{ id: { startsWith: MARK } }, { jobId: { startsWith: MARK } }] } }));
  await step('bookmarks and hidden jobs', () => prisma.jobUserAction.deleteMany({ where: { OR: [{ id: { startsWith: MARK } }, { jobId: { startsWith: MARK } }] } }));
  await step('saved searches', () => prisma.savedJobSearch.deleteMany({ where: { id: { startsWith: MARK } } }));
  await step('reviews', () => prisma.employerReview.deleteMany({ where: { OR: [{ id: { startsWith: MARK } }, { authorId: { in: ids } }, { companyId: { startsWith: MARK } }, { title: { startsWith: LIVE_REVIEW_TITLE } }] } }));
  await step('salary reports', () => prisma.salaryReport.deleteMany({ where: { OR: [{ id: { startsWith: MARK } }, { authorId: { in: ids } }, { companyId: { startsWith: MARK } }, { jobTitle: LIVE_TITLE }] } }));
  await step('interview experiences', () => prisma.interviewReview.deleteMany({ where: { OR: [{ id: { startsWith: MARK } }, { authorId: { in: ids } }, { companyId: { startsWith: MARK } }, { jobTitle: LIVE_TITLE }] } }));
  await step('screening questions', () => prisma.jobScreeningQuestion.deleteMany({ where: { jobId: { startsWith: MARK } } }));
  await step('jobs', () => prisma.job.deleteMany({ where: { id: { startsWith: MARK } } }));
  await step('resumes', () => prisma.resume.deleteMany({ where: { id: { startsWith: MARK } } }));
  await step('conversations with seeded people', () =>
    prisma.conversation.deleteMany({ where: { participants: { some: { email: { endsWith: EMAIL_DOMAIN } } } } }),
  );
  await step('employer verifications', () => prisma.employerVerification.deleteMany({ where: { id: { startsWith: MARK } } }));
  await step('memberships', () => prisma.companyMembership.deleteMany({ where: { userId: { in: ids } } }));
  await step('notifications', () => prisma.notification.deleteMany({ where: { userId: { in: ids } } }));
  await step('audit rows', () => prisma.auditLog.deleteMany({ where: { actorId: { in: ids } } }));
  await step('people', () => prisma.user.deleteMany({ where: { id: { in: ids } } }));
  await step('companies', () => prisma.company.deleteMany({ where: { source: SOURCE } }));
  await prisma.setting.deleteMany({ where: { key: MANIFEST_KEY } });
  if (problems.length) throw new Error(`Removal left ${problems.length} thing(s) in place: ${problems.join('; ')}.`);
}

// ---------------------------------------------------------------------------
// Run alone: `... career.ts [--remove]`
// ---------------------------------------------------------------------------

if (require.main === module) {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { PrismaClient: Client } = require('@prisma/client') as typeof import('@prisma/client');
  const prisma = new Client();
  seedCareer(prisma, (m) => console.log(m), { remove: process.argv.includes('--remove') })
    .catch((e) => {
      console.error(e);
      process.exitCode = 1;
    })
    .finally(() => prisma.$disconnect());
}
