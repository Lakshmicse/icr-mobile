/**
 * Seeds the Requirements (RFQ) module of the mobile app into the LOCAL portal database: what the buyer's
 * My RFQ's, the requirement page, the supplier's board, Opportunity, My Bids and Alerts read, and the
 * personas the live tests post, bid and award as.
 *
 *   cd E:\ICR\irc-portal\backend          (cwd must be the backend folder: `uploads` resolves from it)
 *   NODE_PATH=E:/ICR/irc-portal/node_modules npx ts-node --transpile-only E:/ICR/icr-mobile/tool/seed/rfq.ts
 *   ... same command with --remove        (deletes exactly what this script created, and what the live tests
 *                                          made as its personas: requirements, bids, threads, uploads)
 *
 * Idempotent: every row has a stable id and is upserted, so a re-run puts the seeded state back (a bid the
 * buyer awarded in a live run is pending again) and re-bases every date on "now".
 *
 * WHAT IS SEEDED
 *
 *   Bharat Buyer (buyer@icr.dev, the emulator's person; no company, so the API lets him read and manage but not
 *   post). Five requirements posted by him as himself, the shape his one older requirement already has:
 *     security   live enquiry, three bids (new / shortlisted / new), four invitations, one file
 *     ifm        live staged RFQ in pre-qualification, two responses to screen
 *     home       a draft enquiry
 *     lifts      an awarded RFQ (purchase order to Innova)
 *     hvac       a closed enquiry
 *   plus three alerts (two unread) so the Alerts chip and the bell have something to say.
 *
 *   Sunrise Facilities Pvt Ltd, a buying company, and its admin Bhavya Buyer (rfq.buyer@rfq-design.icr.test):
 *   the persona the live tests post as. Eleven requirements on the supplier board: a recommended CCTV enquiry,
 *   a staged RFQ at the quote stage with two shortlisted suppliers, an invite-only enquiry, an RFQ in
 *   pre-qualification, one published an hour ago (inside the early-access window), and the ones Bluepeak
 *   bid on (shortlisted, submitted, awarded, lost, closed) or was invited to and declined.
 *
 *   Four supplier companies with a listing each, and a VENDOR person apiece (Rfq@12345):
 *     rfq.bluedot@      Bluepeak Security            VERIFIED, Gold plan (unlimited bids): the main supplier persona
 *     rfq.innowork@     Innova Facility Services     CERTIFIED, Gold plan
 *     rfq.securetech@   SecureNet Systems            VERIFIED, free plan (3 RFQ quotes a month)
 *     rfq.greenguard@   GreenShield Services         REGISTERED, not verified: the API refuses its bids
 *   (The persona keys keep the design's names: the Supplier Mart's seeded BlueDot and InnoWork are other rows.)
 *
 * MARKERS (what --remove finds): ids start `design-rfq-`, company source 'design-seed-rfq', emails end
 * @rfq-design.icr.test, files `design-rfq-*`. Live tests post as Bhavya, so --remove also deletes every
 * requirement posted by her company or by Bharat that is not an older one (see EXISTING) and the threads about
 * them. Nothing that existed before is changed: the seed only adds rows (and Bharat's alerts).
 *
 * Local database only: it refuses to run unless DATABASE_URL points at localhost.
 */
import type { Prisma, PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { existsSync, mkdirSync, readFileSync, unlinkSync, writeFileSync } from 'fs';
import { join } from 'path';

const MARK = 'design-rfq-';
const SOURCE = 'design-seed-rfq';
const DOMAIN = '@rfq-design.icr.test';
const PASSWORD = 'Rfq@12345';
const BHARAT = 'buyer@icr.dev';
const PLAN_FILE = 'design-rfq-site-plan.pdf';

const HOUR = 3_600_000;
const DAY = 24 * HOUR;
const ago = (hours: number) => new Date(Date.now() - hours * HOUR);
/** A deadline picked as a day means the whole of that day in India: 18:29:59 UTC (see `deadlineIso` in the app). */
const dayEnd = (daysAhead: number) => {
  const t = new Date(Date.now() + daysAhead * DAY);
  return new Date(Date.UTC(t.getUTCFullYear(), t.getUTCMonth(), t.getUTCDate(), 18, 29, 59, 999));
};

type Log = (message: string) => void;

// ---------------------------------------------------------------------------
// Local-only guard
// ---------------------------------------------------------------------------

function databaseUrl(): string | undefined {
  if (process.env.DATABASE_URL) return process.env.DATABASE_URL;
  const envFile = join(process.cwd(), '.env');
  if (!existsSync(envFile)) return undefined;
  return readFileSync(envFile, 'utf8').match(/^\s*DATABASE_URL\s*=\s*"?([^"\r\n]+)"?/m)?.[1];
}

function assertLocal(): void {
  const host = databaseUrl()?.match(/@(\[[^\]]+\]|[^:/?#]+)/)?.[1]?.replace(/[[\]]/g, '');
  if (!host || !['localhost', '127.0.0.1', '::1'].includes(host)) {
    throw new Error('Refusing to run: the database is not on localhost.');
  }
  if (process.env.NODE_ENV === 'production') throw new Error('Refusing to run with NODE_ENV=production.');
  if (!existsSync(join(process.cwd(), 'prisma', 'schema.prisma'))) {
    throw new Error(`Run this from E:\\ICR\\irc-portal\\backend (cwd is ${process.cwd()}): uploads resolve from it.`);
  }
}

// ---------------------------------------------------------------------------
// The people and companies
// ---------------------------------------------------------------------------

type CompanyKey = 'sunrise' | 'bluedot' | 'innowork' | 'securetech' | 'greenguard';
type Plan = 'gold' | 'free';

const COMPANIES: Record<
  CompanyKey,
  {
    name: string;
    legal: string;
    type: 'CORPORATE' | 'SUPPLIER';
    city: string;
    state: string;
    level: 'REGISTERED' | 'VERIFIED' | 'CERTIFIED';
    plan: Plan;
    headline?: string;
    categories?: string[];
    areas?: string[];
    rating?: number;
    reviews?: number;
    person: { first: string; last: string; role: 'COMPANY_ADMIN' | 'VENDOR'; phone: string };
  }
> = {
  sunrise: {
    name: 'Sunrise Facilities Pvt Ltd',
    legal: 'Sunrise Facilities Private Limited',
    type: 'CORPORATE',
    city: 'Pune',
    state: 'Maharashtra',
    level: 'VERIFIED',
    plan: 'free',
    person: { first: 'Bhavya', last: 'Buyer', role: 'COMPANY_ADMIN', phone: '+919810011001' },
  },
  bluedot: {
    name: 'Bluepeak Security',
    legal: 'Bluepeak Security Services Private Limited',
    type: 'SUPPLIER',
    city: 'Mumbai',
    state: 'Maharashtra',
    level: 'VERIFIED',
    plan: 'gold',
    headline: 'Corporate Security: biometric systems, CCTV and manpower',
    categories: ['SECURITY', 'PHYSICAL_SECURITY', 'ELECTRONIC_SECURITY', 'HOUSEKEEPING'],
    areas: ['Mumbai', 'Pune'],
    rating: 4.8,
    reviews: 124,
    person: { first: 'Bela', last: 'Dot', role: 'VENDOR', phone: '+919810011002' },
  },
  innowork: {
    name: 'Innova Facility Services',
    legal: 'Innova Facility Services Private Limited',
    type: 'SUPPLIER',
    city: 'Pune',
    state: 'Maharashtra',
    level: 'CERTIFIED',
    plan: 'gold',
    headline: 'Integrated facility management, housekeeping and MEP',
    categories: ['FACILITY_MANAGEMENT', 'HOUSEKEEPING', 'SECURITY'],
    areas: ['Pune', 'Mumbai', 'Bengaluru'],
    rating: 4.8,
    reviews: 124,
    person: { first: 'Ivan', last: 'Innes', role: 'VENDOR', phone: '+919810011003' },
  },
  securetech: {
    name: 'SecureNet Systems',
    legal: 'SecureNet Systems Private Limited',
    type: 'SUPPLIER',
    city: 'Bengaluru',
    state: 'Karnataka',
    level: 'VERIFIED',
    plan: 'free',
    headline: 'Network and electronic security: firewalls, access control, CCTV',
    categories: ['SECURITY', 'ELECTRONIC_SECURITY'],
    areas: ['Bengaluru', 'Pune'],
    rating: 4.7,
    reviews: 150,
    person: { first: 'Sana', last: 'Secure', role: 'VENDOR', phone: '+919810011004' },
  },
  greenguard: {
    name: 'GreenShield Services',
    legal: 'GreenShield Services Private Limited',
    type: 'SUPPLIER',
    city: 'Hyderabad',
    state: 'Telangana',
    level: 'REGISTERED',
    plan: 'free',
    headline: 'Home security: alarm systems, surveillance cameras and monitoring',
    categories: ['SECURITY', 'ELECTRONIC_SECURITY'],
    areas: ['Hyderabad'],
    rating: 4.5,
    reviews: 98,
    person: { first: 'Gita', last: 'Green', role: 'VENDOR', phone: '+919810011005' },
  },
};
const KEYS = Object.keys(COMPANIES) as CompanyKey[];
const SUPPLIERS = KEYS.filter((k) => k !== 'sunrise');

const companyId = (k: CompanyKey) => `${MARK}co-${k}`;
const userId = (k: CompanyKey) => `${MARK}u-${k}`;
const vendorId = (k: CompanyKey) => `${MARK}v-${k}`;
const emailOf = (k: CompanyKey) => `rfq.${k === 'sunrise' ? 'buyer' : k}${DOMAIN}`;

// ---------------------------------------------------------------------------
// The requirements
// ---------------------------------------------------------------------------

type Place = { label: string; city: string; state: string; country: string; countryCode: string };
const place = (city: string, state: string): Place => ({ label: city, city, state, country: 'India', countryCode: 'IN' });

type Quote = {
  by: CompanyKey;
  status: 'PENDING' | 'SHORTLISTED' | 'AWARDED' | 'REJECTED';
  amount: number | null;
  lead?: number;
  message: string;
  ageHours: number;
  po?: string;
};
type Invite = { by: CompanyKey; status: 'INVITED' | 'RESPONDED' | 'DECLINED' };
type Response = {
  by: CompanyKey;
  status: 'PENDING' | 'QUALIFIED' | 'REJECTED';
  shortlisted?: boolean;
  years: number;
  turnover: number;
  employees: string;
  presence: 'LOCAL' | 'PAN_INDIA' | 'GLOBAL';
  compliance: string[];
  ageHours: number;
};

type Req = {
  key: string;
  owner: 'bharat' | 'sunrise';
  kind: 'ENQUIRY' | 'RFQ';
  status: 'DRAFT' | 'PUBLISHED' | 'AWARDED' | 'CLOSED' | 'CANCELLED';
  stage?: 'PREQUALIFICATION' | 'SHORTLISTING' | 'QUOTATION' | 'EVALUATION' | 'COMPLETED';
  visibility?: 'PUBLIC' | 'TARGETED';
  title: string;
  text: string;
  category: string;
  subcategory?: string;
  facility: string;
  places: Place[];
  budget?: number;
  due?: number;
  preQual?: number;
  criteria?: {
    years?: number;
    turnover?: number;
    last3?: number;
    employees?: string;
    presence?: 'LOCAL' | 'PAN_INDIA' | 'GLOBAL';
    compliance?: string[];
  };
  items?: { name: string; quantity: number; unit?: string; spec?: string }[];
  file?: boolean;
  /** Hours since it was posted; it is published at the same moment unless it is a draft. */
  ageHours: number;
  closedBy?: 'BUYER' | 'EXPIRED';
  quotes?: Quote[];
  invites?: Invite[];
  responses?: Response[];
};

const REQS: Req[] = [
  // ---- Bharat's, posted as himself ----
  {
    key: 'security',
    owner: 'bharat',
    kind: 'ENQUIRY',
    status: 'PUBLISHED',
    title: 'Corporate Security: Biometric systems, CCTV & Manpower',
    text: 'Round-the-clock guarding for our Mumbai HQ (3 floors, 600 staff), biometric access at two entrances and a CCTV refresh of 48 cameras with 30-day retention.',
    category: 'SECURITY',
    subcategory: 'PHYSICAL_SECURITY',
    facility: 'IT & ITES',
    places: [place('Mumbai', 'Maharashtra')],
    budget: 1200000,
    due: 9,
    ageHours: 96,
    file: true,
    items: [
      { name: 'Security guards (24x7)', quantity: 12, unit: 'guards' },
      { name: 'Biometric access readers', quantity: 4, unit: 'units', spec: 'Fingerprint and card, with a year of AMC' },
      { name: 'CCTV cameras, 4 MP', quantity: 48, unit: 'cameras' },
    ],
    quotes: [
      {
        by: 'bluedot',
        status: 'PENDING',
        amount: 1140000,
        lead: 10,
        ageHours: 24,
        message: 'Twelve PSARA-licensed guards across three shifts, four biometric readers with a year of AMC, and 48 cameras installed in two weekends.',
      },
      {
        by: 'innowork',
        status: 'SHORTLISTED',
        amount: 1250000,
        lead: 7,
        ageHours: 48,
        message: 'Manpower and systems from one team, with a supervisor on site every day.',
      },
      {
        by: 'securetech',
        status: 'PENDING',
        amount: 1080000,
        lead: 14,
        ageHours: 72,
        message: 'We can start with the CCTV refresh and add guarding from the first of next month.',
      },
    ],
    invites: [
      { by: 'bluedot', status: 'RESPONDED' },
      { by: 'innowork', status: 'RESPONDED' },
      { by: 'securetech', status: 'RESPONDED' },
      { by: 'greenguard', status: 'INVITED' },
    ],
  },
  {
    key: 'ifm',
    owner: 'bharat',
    kind: 'RFQ',
    status: 'PUBLISHED',
    stage: 'PREQUALIFICATION',
    title: 'Bharat Facilities: Integrated Facility Management RFQ',
    text: 'Integrated facility management for a 12-acre tech park in Bengaluru: housekeeping, MEP operations, landscaping and helpdesk, with monthly SLA reporting.',
    category: 'FACILITY_MANAGEMENT',
    subcategory: 'HOUSEKEEPING',
    facility: 'IT & ITES',
    places: [place('Bengaluru', 'Karnataka')],
    budget: 25000000,
    preQual: 5,
    due: 19,
    criteria: { years: 5, turnover: 50000000, employees: '201-500', presence: 'PAN_INDIA', compliance: ['GST', 'PF', 'ESI'] },
    ageHours: 140,
    responses: [
      {
        by: 'greenguard',
        status: 'PENDING',
        years: 11,
        turnover: 82000000,
        employees: '500+',
        presence: 'PAN_INDIA',
        compliance: ['GST', 'PF', 'ESI', 'PT'],
        ageHours: 48,
      },
      {
        by: 'securetech',
        status: 'PENDING',
        years: 6,
        turnover: 31000000,
        employees: '201-500',
        presence: 'LOCAL',
        compliance: ['GST', 'PF'],
        ageHours: 30,
      },
    ],
  },
  {
    key: 'home',
    owner: 'bharat',
    kind: 'ENQUIRY',
    status: 'DRAFT',
    title: 'Residential Communities: Home Security',
    text: 'Alarm systems, surveillance cameras and 24x7 monitoring for a 320-flat gated community in Pune.',
    category: 'SECURITY',
    subcategory: 'ELECTRONIC_SECURITY',
    facility: 'Residential Communities',
    places: [place('Pune', 'Maharashtra')],
    ageHours: 20,
  },
  {
    key: 'lifts',
    owner: 'bharat',
    kind: 'RFQ',
    status: 'AWARDED',
    stage: 'COMPLETED',
    title: 'Bharat Facilities: Lift modernisation RFQ',
    text: 'Modernisation of two passenger lifts at the Mumbai HQ: controllers, doors and a two-year maintenance contract.',
    category: 'MEP',
    facility: 'Corporate Offices',
    places: [place('Mumbai', 'Maharashtra')],
    budget: 900000,
    preQual: -20,
    due: -8,
    ageHours: 24 * 30,
    quotes: [
      { by: 'innowork', status: 'AWARDED', amount: 860000, lead: 21, ageHours: 24 * 12, message: 'Both lifts in three weeks, one at a time.', po: 'PO-DSGNRFQ1' },
      { by: 'bluedot', status: 'REJECTED', amount: 940000, lead: 28, ageHours: 24 * 11, message: 'Four weeks with a one-year warranty.' },
    ],
  },
  {
    key: 'hvac',
    owner: 'bharat',
    kind: 'ENQUIRY',
    status: 'CLOSED',
    closedBy: 'BUYER',
    title: 'Annual HVAC AMC: Mumbai HQ',
    text: 'Quarterly preventive maintenance of the HVAC plant at the Mumbai HQ, with breakdown cover.',
    category: 'FACILITY_MANAGEMENT',
    subcategory: 'HVAC',
    facility: 'Corporate Offices',
    places: [place('Mumbai', 'Maharashtra')],
    ageHours: 24 * 40,
    quotes: [{ by: 'innowork', status: 'REJECTED', amount: 410000, lead: 5, ageHours: 24 * 38, message: 'Quarterly visits and a 4-hour breakdown response.' }],
  },

  // ---- Sunrise Facilities': the supplier's board ----
  {
    key: 's-cctv',
    owner: 'sunrise',
    kind: 'ENQUIRY',
    status: 'PUBLISHED',
    title: 'CCTV refresh: 48 cameras, Pune campus',
    text: 'Replace 48 analogue cameras with 4 MP IP cameras across two buildings, with a new NVR and 30-day retention. Site visit can be arranged this week.',
    category: 'SECURITY',
    subcategory: 'ELECTRONIC_SECURITY',
    facility: 'IT & ITES',
    places: [place('Pune', 'Maharashtra')],
    budget: 650000,
    due: 9,
    ageHours: 72,
    quotes: [{ by: 'innowork', status: 'PENDING', amount: 610000, lead: 12, ageHours: 20, message: 'IP cameras, an NVR and a site audit first.' }],
  },
  {
    key: 's-guarding',
    owner: 'sunrise',
    kind: 'RFQ',
    status: 'PUBLISHED',
    stage: 'QUOTATION',
    title: 'Sunrise Facilities: Manned guarding RFQ',
    text: 'Manned guarding for a tech park in Mumbai: 24 guards across three shifts, a control room and quarterly audits.',
    category: 'SECURITY',
    subcategory: 'PHYSICAL_SECURITY',
    facility: 'IT & ITES',
    places: [place('Mumbai', 'Maharashtra')],
    budget: 4200000,
    preQual: -6,
    due: 12,
    criteria: { years: 3, employees: '51-200', compliance: ['PSARA', 'PF'] },
    ageHours: 24 * 9,
    items: [{ name: 'Security guards', quantity: 24, unit: 'guards' }, { name: 'Control room supervisor', quantity: 3, unit: 'shifts' }],
    responses: [
      { by: 'bluedot', status: 'QUALIFIED', shortlisted: true, years: 9, turnover: 90000000, employees: '201-500', presence: 'PAN_INDIA', compliance: ['PSARA', 'PF', 'GST'], ageHours: 24 * 7 },
      { by: 'securetech', status: 'QUALIFIED', shortlisted: true, years: 6, turnover: 45000000, employees: '51-200', presence: 'LOCAL', compliance: ['PSARA', 'PF'], ageHours: 24 * 7 },
    ],
  },
  {
    key: 's-facade',
    owner: 'sunrise',
    kind: 'ENQUIRY',
    status: 'PUBLISHED',
    visibility: 'TARGETED',
    title: 'Drone facade cleaning: four towers',
    text: 'Facade cleaning of four 22-storey towers by drone, twice a year, with a safety plan and insurance cover.',
    category: 'FACILITY_MANAGEMENT',
    subcategory: 'HOUSEKEEPING',
    facility: 'Corporate Offices',
    places: [place('Pune', 'Maharashtra')],
    due: 12,
    ageHours: 30,
    invites: [
      { by: 'bluedot', status: 'INVITED' },
      { by: 'innowork', status: 'INVITED' },
    ],
  },
  {
    key: 's-ifm',
    owner: 'sunrise',
    kind: 'RFQ',
    status: 'PUBLISHED',
    stage: 'PREQUALIFICATION',
    title: 'Sunrise Facilities: Integrated FM RFQ',
    text: 'Integrated facility management for an IT campus in Pune: housekeeping, MEP operations and a helpdesk, with monthly SLA reporting.',
    category: 'FACILITY_MANAGEMENT',
    subcategory: 'HOUSEKEEPING',
    facility: 'IT & ITES',
    places: [place('Pune', 'Maharashtra')],
    budget: 9600000,
    preQual: 4,
    due: 16,
    criteria: { years: 5, turnover: 30000000, employees: '201-500', presence: 'PAN_INDIA', compliance: ['GST', 'PF', 'ESI'] },
    ageHours: 24 * 4,
  },
  {
    key: 's-access',
    owner: 'sunrise',
    kind: 'ENQUIRY',
    status: 'PUBLISHED',
    title: 'Access control upgrade: head office',
    text: 'Card and face access at four entrances and a visitor management desk, integrated with the HR system.',
    category: 'SECURITY',
    subcategory: 'ELECTRONIC_SECURITY',
    facility: 'Corporate Offices',
    places: [place('Pune', 'Maharashtra')],
    budget: 800000,
    due: 14,
    ageHours: 1,
  },
  {
    key: 's-cafeteria',
    owner: 'sunrise',
    kind: 'ENQUIRY',
    status: 'PUBLISHED',
    title: 'Corporate Offices: Cafeteria deep cleaning',
    text: 'Weekly deep cleaning of a 400-seat cafeteria and its kitchen, with our own chemicals and a hygiene report.',
    category: 'FACILITY_MANAGEMENT',
    subcategory: 'HOUSEKEEPING',
    facility: 'Corporate Offices',
    places: [place('Pune', 'Maharashtra')],
    due: 4,
    ageHours: 24 * 6,
    quotes: [{ by: 'bluedot', status: 'SHORTLISTED', amount: 420000, lead: 5, ageHours: 72, message: 'Cafeteria deep cleaning every Sunday, our own chemicals.' }],
  },
  {
    key: 's-pest',
    owner: 'sunrise',
    kind: 'ENQUIRY',
    status: 'PUBLISHED',
    title: 'Retail: Pest control for 14 stores',
    text: 'Monthly pest control across 14 stores in Pune and Mumbai, with a service report after every visit.',
    category: 'FACILITY_MANAGEMENT',
    subcategory: 'PEST_CONTROL',
    facility: 'Retail',
    places: [place('Pune', 'Maharashtra'), place('Mumbai', 'Maharashtra')],
    ageHours: 24 * 5,
    quotes: [{ by: 'bluedot', status: 'PENDING', amount: null, ageHours: 40, message: 'We can cover all fourteen stores from our Pune and Mumbai teams.' }],
  },
  {
    key: 's-lifts',
    owner: 'sunrise',
    kind: 'RFQ',
    status: 'AWARDED',
    stage: 'COMPLETED',
    title: 'Sunrise Facilities: Chiller replacement RFQ',
    text: 'Replace two 300 TR chillers at the Pune campus, with commissioning and a two-year warranty.',
    category: 'MEP',
    facility: 'IT & ITES',
    places: [place('Pune', 'Maharashtra')],
    budget: 3500000,
    preQual: -30,
    due: -14,
    ageHours: 24 * 40,
    quotes: [
      { by: 'bluedot', status: 'AWARDED', amount: 3280000, lead: 35, ageHours: 24 * 18, message: 'Both chillers in five weeks.', po: 'PO-DSGNRFQ2' },
      { by: 'innowork', status: 'REJECTED', amount: 3400000, lead: 40, ageHours: 24 * 17, message: 'Six weeks with a three-year warranty.' },
    ],
  },
  {
    key: 's-old',
    owner: 'sunrise',
    kind: 'ENQUIRY',
    status: 'CLOSED',
    closedBy: 'BUYER',
    title: 'Landscape maintenance: Pune campus',
    text: 'Weekly landscape maintenance of a 6-acre campus, including seasonal planting.',
    category: 'LANDSCAPE',
    facility: 'IT & ITES',
    places: [place('Pune', 'Maharashtra')],
    ageHours: 24 * 35,
    quotes: [{ by: 'bluedot', status: 'PENDING', amount: 180000, lead: 7, ageHours: 24 * 30, message: 'Weekly visits with a crew of four.' }],
  },
  {
    key: 's-lost',
    owner: 'sunrise',
    kind: 'RFQ',
    status: 'AWARDED',
    stage: 'COMPLETED',
    title: 'Sunrise Facilities: Fire alarm upgrade RFQ',
    text: 'Addressable fire alarm upgrade across four floors, with a tested evacuation plan.',
    category: 'FIRE_SAFETY',
    subcategory: 'FIRE_ALARM_SYSTEMS',
    facility: 'Corporate Offices',
    places: [place('Pune', 'Maharashtra')],
    budget: 1500000,
    preQual: -40,
    due: -22,
    ageHours: 24 * 50,
    quotes: [
      { by: 'innowork', status: 'AWARDED', amount: 1380000, lead: 20, ageHours: 24 * 30, message: 'Certified installers, a tested plan and a two-year warranty.', po: 'PO-DSGNRFQ3' },
      { by: 'bluedot', status: 'REJECTED', amount: 1460000, lead: 24, ageHours: 24 * 29, message: 'Four floors in three weeks.' },
    ],
  },
  {
    key: 's-declined',
    owner: 'sunrise',
    kind: 'ENQUIRY',
    status: 'PUBLISHED',
    visibility: 'TARGETED',
    title: 'Executive guest house: Housekeeping',
    text: 'Daily housekeeping and laundry for a 12-room executive guest house.',
    category: 'FACILITY_MANAGEMENT',
    subcategory: 'HOUSEKEEPING',
    facility: 'Hospitality',
    places: [place('Mumbai', 'Maharashtra')],
    due: 10,
    ageHours: 24 * 3,
    invites: [{ by: 'bluedot', status: 'DECLINED' }],
  },
];

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

type Note = {
  key: string;
  to: 'bharat' | CompanyKey;
  type: string;
  title: string;
  body?: string;
  req: string;
  side: 'owner' | 'supplier';
  query?: string;
  ageHours: number;
  read?: boolean;
  quote?: string;
};

const NOTES: Note[] = [
  { key: 'n1', to: 'bharat', type: 'bid_received', title: 'New bid on "Corporate Security: Biometric systems, CCTV & Manpower"', body: 'Bluepeak quoted ₹11,40,000 with a 10-day lead time.', req: 'security', side: 'owner', ageHours: 24, quote: 'security-bluedot' },
  { key: 'n2', to: 'bharat', type: 'prequal_submitted', title: 'SecureNet sent a pre-qualification response', body: 'Bharat Facilities: Integrated Facility Management RFQ', req: 'ifm', side: 'owner', query: '?section=prequal', ageHours: 30 },
  { key: 'n3', to: 'bharat', type: 'bid_received', title: 'New bid on "Corporate Security: Biometric systems, CCTV & Manpower"', body: 'Innova quoted ₹12,50,000 with a 7-day lead time.', req: 'security', side: 'owner', ageHours: 48, read: true, quote: 'security-innowork' },
  { key: 'n4', to: 'bluedot', type: 'rfq_invite', title: 'You were invited to quote', body: 'Drone facade cleaning: four towers', req: 's-facade', side: 'supplier', ageHours: 30 },
  { key: 'n5', to: 'bluedot', type: 'enquiry_match', title: 'A new enquiry matches your services', body: 'CCTV refresh: 48 cameras, Pune campus', req: 's-cctv', side: 'supplier', ageHours: 70 },
  { key: 'n6', to: 'bluedot', type: 'rfq_quotes_open', title: 'Detailed quotes are open', body: 'Sunrise Facilities: Manned guarding RFQ', req: 's-guarding', side: 'supplier', query: '?section=response', ageHours: 24 * 2 },
  { key: 'n7', to: 'bluedot', type: 'bid_awarded', title: 'The buyer chose you', body: 'Sunrise Facilities: Chiller replacement RFQ', req: 's-lifts', side: 'supplier', ageHours: 24 * 14, read: true },
  { key: 'n8', to: 'bluedot', type: 'bid_rejected', title: 'The buyer chose another supplier', body: 'Sunrise Facilities: Fire alarm upgrade RFQ', req: 's-lost', side: 'supplier', ageHours: 24 * 20, read: true },
  { key: 'n9', to: 'sunrise', type: 'bid_received', title: 'New bid on "Corporate Offices: Cafeteria deep cleaning"', body: 'Bluepeak quoted ₹4,20,000.', req: 's-cafeteria', side: 'owner', ageHours: 72 },
];

// ---------------------------------------------------------------------------
// The file the security requirement carries
// ---------------------------------------------------------------------------

/** A one-page, text-only PDF (Helvetica, ASCII): enough to give "Site plan" something real to open. */
function planPdf(): Buffer {
  const lines = [
    'Mumbai HQ: site plan (sample)',
    'Floors 1 to 3. Entrances: North lobby and basement car park.',
    'Biometric readers at both entrances; 48 cameras across 3 floors.',
  ];
  const esc = (s: string) => s.replace(/\\/g, '\\\\').replace(/\(/g, '\\(').replace(/\)/g, '\\)');
  const ops = ['BT', '/F1 18 Tf', '1 0 0 1 56 780 Tm', `(${esc(lines[0])}) Tj`, '/F1 11 Tf'];
  lines.slice(1).forEach((l, i) => ops.push(`1 0 0 1 56 ${750 - i * 18} Tm (${esc(l)}) Tj`));
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
  for (const o of offsets) pdf += `${String(o).padStart(10, '0')} 00000 n \n`;
  pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return Buffer.from(pdf, 'latin1');
}

// ---------------------------------------------------------------------------
// Seeding
// ---------------------------------------------------------------------------

const rfqId = (key: string) => `${MARK}${key}`;
const quoteId = (req: string, by: CompanyKey) => `${MARK}q-${req}-${by}`;

async function seedCompanies(prisma: PrismaClient, log: Log): Promise<void> {
  const hash = bcrypt.hashSync(PASSWORD, 10);
  const goldPlan = await prisma.membershipPlan.findUnique({ where: { tier_audience: { tier: 'GOLD', audience: 'SUPPLIER' } } });
  if (!goldPlan) log('  (no Gold supplier plan in this database: the Gold suppliers will be on the free plan)');
  for (const k of KEYS) {
    const c = COMPANIES[k];
    const verified = c.level !== 'REGISTERED';
    const data = {
      name: c.name,
      legalName: c.legal,
      type: c.type,
      city: c.city,
      state: c.state,
      country: 'India',
      size: '201-500',
      email: `ops@${k}-rfq-design.icr.test`,
      verificationStatus: verified ? ('VERIFIED' as const) : ('PENDING' as const),
      verificationLevel: c.level,
      verifiedAt: verified ? new Date() : null,
      membershipTier: c.plan === 'gold' && goldPlan ? ('GOLD' as const) : ('FREE' as const),
      source: SOURCE,
    };
    await prisma.company.upsert({ where: { id: companyId(k) }, create: { id: companyId(k), ...data }, update: data });

    const user = {
      firstName: c.person.first,
      lastName: c.person.last,
      role: c.person.role,
      personalRole: 'PROFESSIONAL' as const,
      companyId: companyId(k),
      phone: c.person.phone,
      emailVerifiedAt: new Date(),
      isActive: true,
      passwordHash: hash,
    };
    await prisma.user.upsert({ where: { email: emailOf(k) }, create: { id: userId(k), email: emailOf(k), ...user }, update: user });
    const uid = (await prisma.user.findUniqueOrThrow({ where: { email: emailOf(k) }, select: { id: true } })).id;
    const member = await prisma.companyMembership.findFirst({ where: { userId: uid, companyId: companyId(k), status: 'ACTIVE' } });
    if (!member) {
      await prisma.companyMembership.create({
        data: { userId: uid, companyId: companyId(k), role: c.person.role, status: 'ACTIVE', source: c.person.role === 'COMPANY_ADMIN' ? 'FOUNDER' : 'ADDED' },
      });
    }

    if (k === 'sunrise') continue;
    const vendor = {
      companyId: companyId(k),
      headline: c.headline,
      categories: c.categories ?? [],
      serviceAreas: c.areas ?? [],
      yearsExperience: 9,
      rating: c.rating ?? 0,
      ratingCount: c.reviews ?? 0,
      verificationStatus: verified ? ('VERIFIED' as const) : ('PENDING' as const),
      verificationLevel: c.level,
      verifiedAt: verified ? new Date() : null,
      acceptingWork: true,
    };
    await prisma.vendor.upsert({ where: { id: vendorId(k) }, create: { id: vendorId(k), ...vendor }, update: vendor });

    if (c.plan === 'gold' && goldPlan) {
      await prisma.subscription.upsert({
        where: { id: `${MARK}sub-${k}` },
        create: {
          id: `${MARK}sub-${k}`,
          companyId: companyId(k),
          planId: goldPlan.id,
          status: 'ACTIVE',
          provider: 'dev',
          currentPeriodStart: new Date(),
          currentPeriodEnd: null,
        },
        update: { status: 'ACTIVE', currentPeriodEnd: null },
      });
    }
  }
  log(`  ${KEYS.length} companies (source '${SOURCE}') with ${KEYS.length} people and ${SUPPLIERS.length} supplier listings (${DOMAIN}, password ${PASSWORD})`);
}

async function seedFile(prisma: PrismaClient, ownerId: string): Promise<void> {
  const dir = join(process.cwd(), 'uploads');
  mkdirSync(dir, { recursive: true });
  const bytes = planPdf();
  writeFileSync(join(dir, PLAN_FILE), bytes);
  const data = {
    visibility: 'PUBLIC' as const,
    purpose: 'rfq-attachment',
    ownerId,
    name: 'site-plan.pdf',
    mimeType: 'application/pdf',
    size: bytes.length,
  };
  await prisma.uploadedFile.upsert({ where: { filename: PLAN_FILE }, create: { filename: PLAN_FILE, ...data }, update: data });
}

async function seedRequirements(prisma: PrismaClient, log: Log, bharat: string): Promise<void> {
  for (const r of REQS) {
    const id = rfqId(r.key);
    const posted = ago(r.ageHours);
    const live = r.status !== 'DRAFT';
    const poster = r.owner === 'bharat' ? bharat : (await prisma.user.findUniqueOrThrow({ where: { email: emailOf('sunrise') }, select: { id: true } })).id;
    const owner = r.owner === 'bharat';
    const first = r.places[0];
    const company = owner ? 'Bharat Facilities' : COMPANIES.sunrise.name;
    const data: Prisma.RfqUncheckedCreateInput = {
      title: r.title,
      description: r.kind === 'ENQUIRY' ? r.text : r.text,
      kind: r.kind,
      status: r.status,
      stage: r.stage ?? null,
      visibility: r.visibility ?? 'PUBLIC',
      buyerId: poster,
      companyId: owner ? null : companyId('sunrise'),
      category: r.category,
      subcategory: r.subcategory ?? null,
      service: null,
      facilityType: r.facility,
      locations: r.places.map((p) => p.city),
      serviceLocations: r.places as unknown as Prisma.InputJsonValue,
      city: first.city,
      state: first.state,
      country: 'India',
      scope: r.kind === 'RFQ' ? r.text : null,
      budget: r.budget ?? null,
      dueDate: r.due == null ? null : dayEnd(r.due),
      preQualEndDate: r.preQual == null ? null : dayEnd(r.preQual),
      minYearsInBusiness: r.criteria?.years ?? null,
      minAnnualTurnover: r.criteria?.turnover ?? null,
      minLast3YrTurnover: r.criteria?.last3 ?? null,
      minEmployees: r.criteria?.employees ?? null,
      requiredPresence: r.criteria?.presence ?? null,
      statutoryCompliance: r.criteria?.compliance ?? [],
      contactName: owner ? 'Bharat Buyer' : 'Bhavya Buyer',
      contactEmail: owner ? BHARAT : emailOf('sunrise'),
      contactPhone: owner ? '+91 98798 79898' : '+91 98100 11001',
      companyName: company,
      publishedAt: live ? posted : null,
      publishedById: live ? poster : null,
      closedReason: r.status === 'CLOSED' ? (r.closedBy ?? 'BUYER') : null,
      lateAlertsSentAt: live ? new Date() : null,
      createdAt: posted,
    };
    await prisma.rfq.upsert({ where: { id }, create: { id, ...data }, update: data });

    // Children: replaced whole, so a re-run puts the seeded set back.
    await prisma.rfqItem.deleteMany({ where: { rfqId: id } });
    if (r.items?.length) {
      await prisma.rfqItem.createMany({
        data: r.items.map((i) => ({ rfqId: id, name: i.name, quantity: i.quantity, unit: i.unit ?? null, specification: i.spec ?? null })),
      });
    }
    await prisma.rfqAttachment.deleteMany({ where: { rfqId: id } });
    if (r.file) {
      await prisma.rfqAttachment.create({
        data: { rfqId: id, title: 'Site plan: Mumbai HQ', url: `/uploads/${PLAN_FILE}`, name: 'site-plan.pdf', mimeType: 'application/pdf', size: planPdf().length },
      });
    }

    for (const i of r.invites ?? []) {
      const state = { status: i.status, respondedAt: i.status === 'INVITED' ? null : ago(12) };
      await prisma.rfqInvite.upsert({
        where: { rfqId_vendorId: { rfqId: id, vendorId: vendorId(i.by) } },
        create: { rfqId: id, vendorId: vendorId(i.by), createdAt: posted, ...state },
        update: state,
      });
    }

    for (const q of r.quotes ?? []) {
      const qid = quoteId(r.key, q.by);
      const state = {
        totalAmount: q.amount,
        message: q.message,
        leadTimeDays: q.lead ?? null,
        status: q.status,
        isAwarded: q.status === 'AWARDED',
        createdAt: ago(q.ageHours),
      };
      await prisma.quote.upsert({
        where: { rfqId_vendorId: { rfqId: id, vendorId: vendorId(q.by) } },
        create: { id: qid, rfqId: id, vendorId: vendorId(q.by), ...state },
        update: state,
      });
      const stored = await prisma.quote.findUniqueOrThrow({ where: { rfqId_vendorId: { rfqId: id, vendorId: vendorId(q.by) } }, select: { id: true } });
      if (q.po && q.amount != null) {
        await prisma.purchaseOrder.upsert({
          where: { quoteId: stored.id },
          create: { quoteId: stored.id, poNumber: q.po, amount: q.amount },
          update: { poNumber: q.po, amount: q.amount },
        });
      }
    }

    for (const p of r.responses ?? []) {
      const quote = r.quotes?.find((q) => q.by === p.by);
      const state = {
        yearsInBusiness: p.years,
        annualTurnover: p.turnover,
        employeeCount: p.employees,
        presence: p.presence,
        statutoryCompliance: p.compliance,
        preQualStatus: p.status,
        shortlisted: p.shortlisted ?? false,
        submittedAt: ago(p.ageHours),
        screenedAt: p.status === 'PENDING' ? null : ago(p.ageHours - 1),
        quoteId: quote ? (await prisma.quote.findUnique({ where: { rfqId_vendorId: { rfqId: id, vendorId: vendorId(p.by) } }, select: { id: true } }))?.id ?? null : null,
      };
      await prisma.rfqSupplierResponse.upsert({
        where: { rfqId_vendorId: { rfqId: id, vendorId: vendorId(p.by) } },
        create: { id: `${MARK}pq-${r.key}-${p.by}`, rfqId: id, vendorId: vendorId(p.by), ...state },
        update: state,
      });
    }
  }
  log(`  ${REQS.length} requirements (${REQS.filter((r) => r.owner === 'bharat').length} Bharat's, ${REQS.filter((r) => r.owner === 'sunrise').length} Sunrise's), ${REQS.reduce((n, r) => n + (r.quotes?.length ?? 0), 0)} bids, ${REQS.reduce((n, r) => n + (r.invites?.length ?? 0), 0)} invitations, ${REQS.reduce((n, r) => n + (r.responses?.length ?? 0), 0)} pre-qualification responses`);
}

async function seedNotes(prisma: PrismaClient, log: Log, bharat: string): Promise<void> {
  for (const n of NOTES) {
    const to = n.to === 'bharat' ? bharat : (await prisma.user.findUniqueOrThrow({ where: { email: emailOf(n.to) }, select: { id: true } })).id;
    const cid = n.to === 'bharat' ? null : companyId(n.to);
    const q = n.quote ? `?bid=${quoteId(...(n.quote.split('-') as [string, CompanyKey]))}` : (n.query ?? '');
    const link = `/manage/${n.side === 'owner' ? 'requirements' : 'bids'}/${rfqId(n.req)}${q}`;
    const data = {
      userId: to,
      title: n.title,
      body: n.body ?? null,
      type: n.type,
      link,
      targetKind: `rfq.${n.side}`,
      targetId: rfqId(n.req),
      companyId: cid,
      readAt: n.read ? ago(n.ageHours - 1) : null,
      createdAt: ago(n.ageHours),
    };
    await prisma.notification.upsert({ where: { id: `${MARK}${n.key}` }, create: { id: `${MARK}${n.key}`, ...data }, update: data });
  }
  log(`  ${NOTES.length} alerts (${NOTES.filter((n) => !n.read).length} unread)`);
}

export async function seedRfq(prisma: PrismaClient, log: Log, opts: { remove?: boolean } = {}): Promise<void> {
  assertLocal();
  if (opts.remove) return removeAll(prisma, log);

  const bharat = await prisma.user.findUnique({ where: { email: BHARAT }, select: { id: true } });
  if (!bharat) throw new Error(`${BHARAT} does not exist in this database: run the portal's seeds first.`);
  log('Seeding the requirements fixtures ...');
  await seedCompanies(prisma, log);
  await seedFile(prisma, bharat.id);
  await seedRequirements(prisma, log, bharat.id);
  await seedNotes(prisma, log, bharat.id);
  log('Done. Sign in as buyer@icr.dev for My RFQ\'s, or as rfq.bluedot@rfq-design.icr.test (Rfq@12345) for the supplier side.');
}

// ---------------------------------------------------------------------------
// Removing
// ---------------------------------------------------------------------------

async function removeAll(prisma: PrismaClient, log: Log): Promise<void> {
  const people = await prisma.user.findMany({ where: { email: { endsWith: DOMAIN } }, select: { id: true } });
  const personIds = people.map((p) => p.id);
  const companies = [...KEYS.map(companyId)];

  // Requirements: the seeded ones, and whatever the live tests posted as the personas.
  const rfqs = await prisma.rfq.findMany({
    where: {
      OR: [{ id: { startsWith: MARK } }, { companyId: { in: companies } }, { buyerId: { in: personIds } }],
    },
    select: { id: true },
  });
  const rfqIds = rfqs.map((r) => r.id);
  // A thread outlives its requirement (the link is set null), so find them by who is in them too.
  const threads = await prisma.conversation.deleteMany({
    where: { OR: [{ rfqId: { in: rfqIds } }, { companies: { some: { companyId: { in: companies } } } }] },
  });
  const removed = await prisma.rfq.deleteMany({ where: { id: { in: rfqIds } } });
  const notes = await prisma.notification.deleteMany({ where: { OR: [{ id: { startsWith: MARK } }, { userId: { in: personIds } }, { targetId: { in: rfqIds } }] } });

  // What the personas uploaded (a live test attaches files): the rows and the files.
  const files = await prisma.uploadedFile.findMany({
    where: { OR: [{ filename: { startsWith: MARK } }, { ownerId: { in: personIds } }] },
    select: { filename: true },
  });
  await prisma.uploadedFile.deleteMany({ where: { filename: { in: files.map((f) => f.filename) } } });
  for (const f of files) {
    const path = join(process.cwd(), 'uploads', f.filename);
    if (existsSync(path)) unlinkSync(path);
  }

  const audit = await prisma.auditLog.deleteMany({ where: { actorId: { in: personIds } } });
  await prisma.subscription.deleteMany({ where: { id: { startsWith: MARK } } });
  await prisma.vendor.deleteMany({ where: { id: { startsWith: MARK } } });
  await prisma.companyMembership.deleteMany({ where: { companyId: { in: companies } } });
  const users = await prisma.user.deleteMany({ where: { id: { in: personIds } } });
  const gone = await prisma.company.deleteMany({ where: { id: { in: companies } } });
  log(
    `removed ${removed.count} requirement(s), ${threads.count} thread(s), ${notes.count} alert(s), ${files.length} file(s), ${audit.count} audit row(s), ` +
      `${users.count} people and ${gone.count} companies`,
  );
}

if (require.main === module) {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { PrismaClient: Client } = require('@prisma/client') as typeof import('@prisma/client');
  const prisma = new Client();
  seedRfq(prisma, (m) => console.log(m), { remove: process.argv.includes('--remove') })
    .catch((e) => {
      console.error(e);
      process.exitCode = 1;
    })
    .finally(() => prisma.$disconnect());
}
