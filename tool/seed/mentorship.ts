/**
 * MENTORSHIP design fixtures for the ICR mobile app.
 *
 * Fills the LOCAL development database with the content the mobile designs
 * show (docs/designs/mentorship-landing.jpg, find-mentors.jpg,
 * mentor-profile-overview.png, mentor-profile-offerings.jpg,
 * offering-sheet.jpg), so the app, running on the portal's real API, reads
 * the same names, photos, shelves, tiles, chips, cohort and offerings that its
 * bundled demo content (`--dart-define=FEED_SOURCE=demo`) draws.
 *
 * Run from the portal's backend folder (cwd decides where `uploads` is):
 *
 *   cd E:\ICR\irc-portal\backend
 *   $env:NODE_PATH = 'E:/ICR/irc-portal/node_modules'
 *   npx ts-node --transpile-only E:/ICR/icr-mobile/tool/seed/mentorship.ts            # seed (idempotent)
 *   npx ts-node --transpile-only E:/ICR/icr-mobile/tool/seed/mentorship.ts --remove   # delete exactly what it made
 *
 * or call `seedMentorship(prisma, log, { remove })` from a master seed.
 *
 * MARKING. Nothing here is told apart by a guess:
 *   - every row id this script writes starts with `dsgn-mentorship-`
 *     (users, profiles, services, plans, pairings, programme, ...), so
 *     `--remove` deletes by that prefix and cannot touch anyone else's rows;
 *   - every invented account is `mentorship.<key>@design.icr.test`;
 *   - every file copied into backend/uploads starts with `design-mentorship-`;
 *   - the one company page it creates carries source = 'design-mentorship'.
 *
 * LOCAL ONLY. It refuses to write unless DATABASE_URL points at localhost, and
 * the invented accounts use the seeds' published dev password
 * (`Password123!`, or SEED_PASSWORD; refused outright under NODE_ENV=production).
 *
 * WHAT IT MAKES (and why it is shaped this way — read how the API derives
 * what the app draws, `api_mentorship_repository.dart`):
 *
 *  - 48 listed mentors who outrank every other mentor on rating (a rating a
 *    hair above 5.0 — it still reads "5.0" — because Karthik and Priya sit on
 *    exactly 5.0 and the shelf is a sort):
 *      * SET A, the design's eight cards in the design's order (Rajesh Sharma
 *        twice, Lisa Cheng, David Kim, Sophia Patel, Michael Johnson, Emma
 *        Thompson, James Rodriguez) = the top of "Top Rated Mentors" and of
 *        Find Mentors;
 *      * SET B, the same eight people again under their own accounts, with the
 *        most sessions delivered = "Most Sessions Delivered". The landing drops
 *        from the second shelf anyone already on the first, so the design's
 *        repeated grid can only appear this way;
 *      * 32 further mentors, spread over employers so that "Explore by
 *        Companies" comes out as Microsoft, Amazon, JLL, CBRE, Google, Infosys
 *        (then Cisco, SpaceX), counted over the top 48 by rating the way the
 *        app counts them.
 *  - The competency labels are shared out so the category chips come out as
 *    Operations & FM, Sustainability & ESG, Smart Buildings & IoT, Workplace
 *    Strategy, ... and the "Explore by Expertise" topics as Space Optimization,
 *    Sustainability, Workplace Safety, Budgeting & Costing, Vendor Management,
 *    Employee Wellbeing, Technology Integration, Energy Management, ... and so
 *    that "Operations & FM" with "10+ yrs" matches exactly 48 mentors.
 *  - An open cohort programme, "FM Leadership & ESG Masterclass", registered
 *    by 32 people, that sorts ahead of the programme already open.
 *  - Rajesh Sharma (the first card) has a live storefront whose first three
 *    services are the design's "Featured Advisory Sessions", plus a plan, a
 *    programme and an upcoming group session so every offering kind exists.
 *  - Srikanth Sriramagiri, the profile designs' mentor: career, education,
 *    skills, availability, a six-row Offerings tab, the "Pro Mentorship Tier"
 *    plan with "Only 2 slots left", pairings, reviews and a recommendation.
 *
 * WHAT THE API CANNOT SHOW is listed at the end of the run and in the report.
 */
import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import * as shared from '@icr/shared';
import { copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'fs';
import { join, resolve } from 'path';

// ---------------------------------------------------------------------------
// Markers and small helpers
// ---------------------------------------------------------------------------

const DOMAIN = 'design.icr.test';
const PREFIX = 'dsgn-mentorship-';
const UP = 'design-mentorship-';
const SOURCE = 'design-mentorship';

const DAY = 86_400_000;
const daysAgo = (n: number) => new Date(Date.now() - n * DAY);
const daysAhead = (n: number) => new Date(Date.now() + n * DAY);

const idOf = (...parts: (string | number)[]) => PREFIX + parts.join('-');
const emailOf = (key: string) => `mentorship.${key}@${DOMAIN}`;

const TERMS_VERSION: string = (shared as any).MARKETPLACE_TERMS_VERSION ?? '2026.1';
const BEST_SELLER: number = (shared as any).BEST_SELLER_MIN_SALES ?? 5;
const CONDUCT_VERSION: string | null = (shared as any).MENTOR_CODE_OF_CONDUCT_VERSION ?? null;

type Log = (message: string) => void;

/** The password rule of backend/prisma/seed-password.ts, kept here so the script stands alone. */
function seedPassword(devDefault: string): string {
  const override = process.env.SEED_PASSWORD?.trim();
  if (override) {
    if (override.length < 12) throw new Error('SEED_PASSWORD must be at least 12 characters.');
    return override;
  }
  if (process.env.NODE_ENV === 'production') {
    throw new Error('Refusing to seed a published development password into a production database.');
  }
  return devDefault;
}

/** Throws unless DATABASE_URL is a localhost database. Returns "host:port/db" for the log (never the password). */
function assertLocalDatabase(): string {
  let url = process.env.DATABASE_URL;
  if (!url) {
    const envFile = join(process.cwd(), '.env');
    if (existsSync(envFile)) {
      const line = readFileSync(envFile, 'utf8')
        .split(/\r?\n/)
        .find((l) => /^\s*DATABASE_URL\s*=/.test(l));
      url = line?.replace(/^\s*DATABASE_URL\s*=\s*/, '').replace(/^["']|["']$/g, '');
    }
  }
  if (!url) throw new Error('DATABASE_URL is not set (run from the portal backend folder, where .env is).');
  let host: string;
  let where: string;
  try {
    const u = new URL(url);
    host = u.hostname.replace(/^\[|\]$/g, '');
    where = `${host}:${u.port || '5432'}${u.pathname}`;
  } catch {
    throw new Error('DATABASE_URL is not a URL this script can read; refusing to write.');
  }
  if (!['localhost', '127.0.0.1', '::1'].includes(host)) {
    throw new Error(`Refusing to write design fixtures to a database that is not local (host "${host}").`);
  }
  if (process.env.NODE_ENV === 'production') throw new Error('Refusing to run with NODE_ENV=production.');
  return where;
}

function assertBackendCwd() {
  if (!existsSync(join(process.cwd(), 'prisma', 'schema.prisma'))) {
    throw new Error(
      `Run this from the portal's backend folder (E:\\ICR\\irc-portal\\backend) so that "uploads" resolves; cwd is ${process.cwd()}.`,
    );
  }
}

// ---------------------------------------------------------------------------
// Images: the mobile repo's demo art and the portal's AI portraits -> backend/uploads
// ---------------------------------------------------------------------------

const DESIGN_DIR = resolve(__dirname, '..', '..', 'assets', 'images', 'demo', 'mentorship');
const FACES_DIR = () => join(process.cwd(), 'prisma', 'seed-assets', 'avatars');
const UPLOADS = () => join(process.cwd(), 'uploads');

const designUrl = (file: string) => `/uploads/${UP}${file}`;
const faceUrl = (file: string) => `/uploads/${UP}face-${file}`;

/** The design art this script publishes (avatar_*, cover_*, profile_*). */
const DESIGN_FILES = [
  'avatar_rajesh.jpg',
  'avatar_rajesh2.jpg',
  'avatar_lisa.jpg',
  'avatar_david.jpg',
  'avatar_sophia.jpg',
  'avatar_michael.jpg',
  'avatar_emma.jpg',
  'avatar_james.jpg',
  'cover_rajesh.jpg',
  'cover_rajesh2.jpg',
  'cover_lisa.jpg',
  'cover_david.jpg',
  'cover_sophia.jpg',
  'cover_michael.jpg',
  'cover_emma.jpg',
  'cover_james.jpg',
  'profile_avatar.png',
  'profile_cover.jpg',
  'profile_offering_cover.jpg',
  'profile_reviewer.png',
];

function copyAssets(faces: string[], log: Log) {
  mkdirSync(UPLOADS(), { recursive: true });
  for (const f of DESIGN_FILES) {
    const src = join(DESIGN_DIR, f);
    if (!existsSync(src)) throw new Error(`Design image missing: ${src}`);
    copyFileSync(src, join(UPLOADS(), UP + f));
  }
  for (const f of faces) copyFileSync(join(FACES_DIR(), f), join(UPLOADS(), `${UP}face-${f}`));
  log(`  images: ${DESIGN_FILES.length} design images + ${faces.length} portraits copied to backend/uploads (design-mentorship-*)`);
}

/** A one-page PDF with a few lines of text: the file behind a sellable resource. ASCII only. */
function tinyPdf(lines: string[]): Buffer {
  const esc = (s: string) => s.replace(/[\\()]/g, '\\$&');
  const body = lines.map((l, i) => `${i ? '0 -28 Td ' : ''}(${esc(l)}) Tj`).join(' ');
  const stream = `BT /F1 20 Tf 72 700 Td ${body} ET`;
  const objs = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
    `<< /Length ${stream.length} >>\nstream\n${stream}\nendstream`,
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  let pdf = '%PDF-1.4\n';
  const offsets: number[] = [];
  objs.forEach((o, i) => {
    offsets.push(pdf.length);
    pdf += `${i + 1} 0 obj\n${o}\nendobj\n`;
  });
  const xref = pdf.length;
  pdf += `xref\n0 ${objs.length + 1}\n0000000000 65535 f \n`;
  pdf += offsets.map((o) => `${String(o).padStart(10, '0')} 00000 n \n`).join('');
  pdf += `trailer\n<< /Size ${objs.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return Buffer.from(pdf, 'latin1');
}

// ---------------------------------------------------------------------------
// The people
// ---------------------------------------------------------------------------

interface Persona {
  index: number; // 0..47 — rank on rating, A first, then B, then the rest
  group: 'A' | 'B' | 'F';
  key: string;
  first: string;
  last: string;
  title: string;
  company: string;
  years: number;
  chips: string[]; // what the directory card draws (the first competencies)
  languages: string[];
  bio: string;
  avatar: string;
  cover: string;
  rating: number;
  ratingCount: number;
  sessions: number;
  mentees: number;
  capacity: number;
  competencies: string[]; // filled by assignCompetencies()
}

/** The design's eight cards, in the design's order (demo_mentorship_repository.dart). */
const DESIGN_EIGHT = [
  { key: 'rajesh-1', first: 'Rajesh', last: 'Sharma', title: 'VP Facility Ops', company: 'Infosys', chips: ['Smart Campuses', 'Smart Campuses', 'BMS'], file: 'rajesh', languages: ['English', 'Hindi'], bio: 'Two decades running technology campuses: smart-building programmes, BMS integration and facility operations across thirty sites. I mentor facility managers who want to lead a portfolio rather than a building.' },
  { key: 'rajesh-2', first: 'Rajesh', last: 'Sharma', title: 'VP Facility Ops', company: 'Infosys', chips: ['Smart Campuses', 'Smart Campuses', 'BMS'], file: 'rajesh2', languages: ['English', 'Hindi'], bio: 'Campus operations, building management systems and the vendors behind them. I mentor people stepping up from site operations to regional ownership.' },
  { key: 'lisa', first: 'Lisa', last: 'Cheng', title: 'Director of Sustainability', company: 'Google', chips: ['Green Initiatives', 'Renewable Energy', 'Design'], file: 'lisa', languages: ['English', 'Mandarin'], bio: 'I lead sustainability for a global workplace portfolio: renewable energy procurement, green building certification and net-zero roadmaps for offices and data centres.' },
  { key: 'david', first: 'David', last: 'Kim', title: 'Chief Technology Officer', company: 'Cisco', chips: ['Smart Cities', 'IoT Solutions', 'Network Optimization'], file: 'david', languages: ['English', 'Korean'], bio: 'Technology leader focused on smart cities and connected buildings: IoT platforms, network optimisation and the vendor decisions behind them.' },
  { key: 'sophia', first: 'Sophia', last: 'Patel', title: 'Head of Innovation', company: 'Microsoft', chips: ['Digital Transformation', 'AI Integration', 'Cloud Solutions'], file: 'sophia', languages: ['English', 'Hindi', 'Gujarati'], bio: 'Head of innovation for workplace technology: digital transformation of facilities, AI-assisted operations and cloud-based building platforms.' },
  { key: 'michael', first: 'Michael', last: 'Johnson', title: 'Product Manager', company: 'Amazon', chips: ['E-Commerce', 'User Experience', 'Data Analytics'], file: 'michael', languages: ['English'], bio: 'Product leader building e-commerce and user-experience platforms. I mentor people moving from operations into product and data analytics.' },
  { key: 'emma', first: 'Emma', last: 'Thompson', title: 'Lead Architect', company: 'Tesla', chips: ['Electric Vehicles', 'Sustainable Engineering', 'FCM'], file: 'emma', languages: ['English', 'French'], bio: 'Lead architect for sustainable manufacturing and EV facilities, from site design through energy systems to commissioning.' },
  { key: 'james', first: 'James', last: 'Rodriguez', title: 'Operations Manager', company: 'SpaceX', chips: ['Aerospace', 'Launch Operations'], file: 'james', languages: ['English', 'Spanish'], bio: 'Operations manager for launch and aerospace facilities. I mentor on high-reliability operations, safety culture and launch-day logistics.' },
];

/** Filler mentors: who works where decides the tile order (see the header). [key, first, last, gender, company, title, years] */
const FILLERS: [string, string, string, 'f' | 'm', string, string, number][] = [
  // Microsoft x4
  ['aditi-menon', 'Aditi', 'Menon', 'f', 'Microsoft', 'Director, Workplace Strategy', 16],
  ['karan-malhotra', 'Karan', 'Malhotra', 'm', 'Microsoft', 'Head of Real Estate, India', 19],
  ['neha-bansal', 'Neha', 'Bansal', 'f', 'Microsoft', 'Senior Manager, Smart Buildings', 12],
  ['rohan-iyer', 'Rohan', 'Iyer', 'm', 'Microsoft', 'Principal Program Manager, Facilities', 14],
  // Amazon x3
  ['priyanka-shetty', 'Priyanka', 'Shetty', 'f', 'Amazon', 'Regional Head, Site Operations', 15],
  ['vikas-arora', 'Vikas', 'Arora', 'm', 'Amazon', 'Senior Manager, Facilities Engineering', 13],
  ['sana-qureshi', 'Sana', 'Qureshi', 'f', 'Amazon', 'Workplace Experience Lead', 11],
  // JLL x5
  ['arvind-pillai', 'Arvind', 'Pillai', 'm', 'JLL', 'Managing Director, Integrated FM', 22],
  ['meghna-kapoor', 'Meghna', 'Kapoor', 'f', 'JLL', 'VP, Occupier Strategy', 17],
  ['tushar-deshmukh', 'Tushar', 'Deshmukh', 'm', 'JLL', 'Head of Energy & Sustainability Services', 15],
  ['ritika-sen', 'Ritika', 'Sen', 'f', 'JLL', 'Director, Project & Development Services', 14],
  ['faisal-ahmed', 'Faisal', 'Ahmed', 'm', 'JLL', 'Associate Director, Technical Services', 12],
  // CBRE x4
  ['nandini-rao', 'Nandini', 'Rao', 'f', 'CBRE', 'Senior Director, Account Management', 18],
  ['siddharth-jain', 'Siddharth', 'Jain', 'm', 'CBRE', 'Head of Workplace Advisory', 16],
  ['pallavi-joshi', 'Pallavi', 'Joshi', 'f', 'CBRE', 'Director, Smart Building Solutions', 13],
  ['gaurav-mehta', 'Gaurav', 'Mehta', 'm', 'CBRE', 'VP, Facilities Operations', 20],
  // Google x2
  ['ishita-banerjee', 'Ishita', 'Banerjee', 'f', 'Google', 'Workplace Operations Manager', 11],
  ['harsh-vardhan', 'Harsh', 'Vardhan', 'm', 'Google', 'Sustainability Program Lead', 12],
  // one each, so no other employer climbs into the tiles
  ['anil-kumar', 'Anil', 'Kumar', 'm', 'Wipro', 'Head of Facilities', 21],
  ['shalini-nair', 'Shalini', 'Nair', 'f', 'TCS', 'Senior Manager, Real Estate', 14],
  ['manoj-gupta', 'Manoj', 'Gupta', 'm', 'Siemens', 'Director, Smart Infrastructure', 18],
  ['divya-krishnan', 'Divya', 'Krishnan', 'f', 'Honeywell', 'Building Technologies Lead', 12],
  ['pranav-kulkarni', 'Pranav', 'Kulkarni', 'm', 'Schneider Electric', 'Head of Energy Services', 16],
  ['lavanya-reddy', 'Lavanya', 'Reddy', 'f', 'Accenture', 'Workplace Experience Lead', 13],
  ['rahul-chatterjee', 'Rahul', 'Chatterjee', 'm', 'Deloitte', 'Director, Real Estate Advisory', 17],
  ['tanya-dsouza', 'Tanya', 'Dsouza', 'f', 'Sodexo', 'Regional Operations Director', 15],
  ['imtiaz-sheikh', 'Imtiaz', 'Sheikh', 'm', 'ISS Facility Services', 'Head of Integrated Services', 19],
  ['kavita-pandey', 'Kavita', 'Pandey', 'f', 'Cushman & Wakefield', 'Senior Director, Project Management', 16],
  ['mohit-saxena', 'Mohit', 'Saxena', 'm', 'Knight Frank', 'Associate Partner, Occupier Services', 14],
  ['bhavna-trivedi', 'Bhavna', 'Trivedi', 'f', 'Colliers', 'Director, Asset Services', 13],
  ['suresh-naidu', 'Suresh', 'Naidu', 'm', 'Tata Realty', 'VP, Facilities & Operations', 23],
  ['alka-verma', 'Alka', 'Verma', 'f', 'Brookfield', 'Senior Manager, Property Operations', 11],
];

/**
 * The competency labels the landing reads out of `facets`: ranks 1-8 are the
 * category chips, ranks 9-17 the "Explore by Expertise" topics. Totals count
 * every listed mentor, strictly falling, and rank 17 stays above anything else
 * on the platform (the design's own chips, e.g. "Smart Campuses", reach 8).
 * No label holds a comma: the directory's filter splits on commas.
 */
const FACET_PLAN: [label: string, total: number][] = [
  ['Operations & FM', 48],
  ['Sustainability & ESG', 40],
  ['Smart Buildings & IoT', 38],
  ['Workplace Strategy', 36],
  ['Facility Management', 34],
  ['Building Operations', 32],
  ['Corporate Real Estate', 30],
  ['Stakeholder Management', 28],
  // ranks 9-17: "Explore by Expertise". The design's grid ends "Technology
  // Integration, Energy Management, Energy Management"; a label can rank once,
  // so the 9th chip is a different one.
  ['Space Optimization', 26],
  ['Sustainability', 24],
  ['Workplace Safety', 22],
  ['Budgeting & Costing', 20],
  ['Vendor Management', 18],
  ['Employee Wellbeing', 16],
  ['Technology Integration', 14],
  ['Energy Management', 12],
  ['Asset Lifecycle Management', 10],
];

function buildRoster(portraits: { f: string[]; m: string[] }): Persona[] {
  const out: Persona[] = [];
  const make = (p: Omit<Persona, 'index' | 'rating' | 'ratingCount' | 'sessions' | 'mentees' | 'capacity' | 'competencies'>) => {
    const index = out.length;
    // Everyone is a hair above 5.0 so the shelf (a sort) puts all 48 above
    // Karthik and Priya, who sit on exactly 5.0; the app prints one decimal.
    const rating = Math.round((5 + (48 - index) * 0.001) * 1000) / 1000; // 5.048 .. 5.001
    const g = p.group;
    out.push({
      ...p,
      index,
      rating,
      ratingCount: g === 'F' ? 4 + (index % 9) : 12,
      // Set B carries the most sessions delivered, in the design's order.
      sessions: g === 'A' ? 62 - index * 2 : g === 'B' ? 160 - (index - 8) * 10 : 10 + ((index * 7) % 25),
      mentees: g === 'A' ? 18 - (index % 3) : g === 'B' ? 40 - (index - 8) * 2 : 3 + (index % 11),
      capacity: g === 'F' ? 3 + (index % 3) : 6,
      competencies: [],
    });
  };
  for (const g of ['A', 'B'] as const) {
    for (const d of DESIGN_EIGHT) {
      make({
        group: g,
        key: g === 'A' ? d.key : `b-${d.key}`,
        first: d.first,
        last: d.last,
        title: d.title,
        company: d.company,
        years: 14, // the demo's yearsExperience
        chips: d.chips,
        languages: d.languages,
        bio: d.bio,
        avatar: designUrl(`avatar_${d.file}.jpg`),
        cover: designUrl(`cover_${d.file}.jpg`),
      });
    }
  }
  const covers = DESIGN_EIGHT.map((d) => designUrl(`cover_${d.file}.jpg`));
  const used = { f: 0, m: 0 };
  FILLERS.forEach(([key, first, last, gender, company, title, years], i) => {
    const pool = portraits[gender];
    const file = pool[used[gender]++ % pool.length];
    make({
      group: 'F',
      key,
      first,
      last,
      title,
      company,
      years,
      chips: [],
      languages: ['English', 'Hindi'],
      bio: '',
      avatar: faceUrl(file),
      cover: covers[i % covers.length],
    });
  });
  return out;
}

/** Shares the FACET_PLAN labels out so the whole platform's tally comes out as planned. */
function assignCompetencies(roster: Persona[], others: Map<string, number>, log: Log) {
  const n = roster.length; // 48
  const labelsOf: string[][] = roster.map(() => []);
  FACET_PLAN.forEach(([label, total], j) => {
    const need = Math.max(0, Math.min(n, total - (others.get(label) ?? 0)));
    if (total - (others.get(label) ?? 0) > n) log(`  ! "${label}" cannot reach ${total}: only ${n} mentors to give it to`);
    if (total - (others.get(label) ?? 0) < 0) log(`  ! "${label}" is already above ${total} on the platform`);
    const chosen: number[] = [];
    if (j === 0) {
      for (let i = 0; i < n; i++) chosen.push(i);
    } else if (j < 8) {
      // categories: both design sets first, so tapping a chip still shows the design's cards on top
      for (let i = 0; i < 16 && chosen.length < need; i++) chosen.push(i);
      for (let k = 0; chosen.length < need && k < 32; k++) chosen.push(16 + ((j * 5 + k) % 32));
    } else {
      for (let k = 0; chosen.length < need && k < n; k++) chosen.push((j * 11 + k) % n);
    }
    for (const i of chosen) labelsOf[i].push(label);
  });
  for (const p of roster) {
    const mine = labelsOf[p.index];
    if (p.group === 'F') {
      // The card draws the first three: vary which three each mentor shows.
      const r = mine.length ? p.index % mine.length : 0;
      p.competencies = [...mine.slice(r), ...mine.slice(0, r)];
      p.chips = p.competencies.slice(0, 3);
    } else {
      p.competencies = [...p.chips, ...mine];
    }
  }
}

// ---------------------------------------------------------------------------
// Srikanth Sriramagiri — the profile designs' mentor
// ---------------------------------------------------------------------------

const SRK = {
  key: 'srikanth',
  first: 'Srikanth',
  last: 'Sriramagiri',
  // The line under the name. It names the employer, so the app draws it alone (organisation in bold)
  // instead of putting the current role's own title in front of it.
  headline: 'Supply Chain Leader at Microsoft • Ex-Tata Aerospace • BITS Pilani • IIT KGP',
  years: 15,
  languages: ['English', 'Telugu', 'Hindi', 'Kannada'],
  competencies: ['Supply Chain Optimization', 'Strategic Capacity Planning', 'Project Management', 'Executive Team Leadership'],
  topics: ['Azure Cloud Planning', 'Power BI & Analytics', 'Advanced Financial Modeling', 'SAP S/4HANA ERP'],
  bioHtml:
    '<p>Result-oriented professional with ~15 years of management experience in Technology and Aerospace &amp; Defense sectors with a proven track record across Operations, Supply Chain and Project Management.</p>' +
    '<p>Have been the founding member of Supply Planning at Microsoft and established the CoE for Aero Engines Manufacturing at Tata Advanced Systems, scaling a greenfield site into a full production line while building the supplier base behind it.</p>',
};

// The Career Journey's first row is the design's "APAC Lead, Azure Planning &
// Execution" at "Microsoft Corporation". The API derives the current role from
// that same row, so the hero's "Supply Chain Leader at Microsoft" cannot come
// from it: it is the mentor's own headline (see SRK.headline). The linked
// company page makes the organisation read "Microsoft Corporation" in blue on
// the journey, while the stored "Microsoft" is what the hero's bold word
// matches in the headline. The role's start (July 2022) is real; its length
// ("4 yrs 4 mos" today) is computed by the app from it, so it differs from the
// design's "2 yrs 4 mos", which was true on the day the mock was drawn.
const SRK_ROLES = [
  { k: 'microsoft', title: 'APAC Lead, Azure Planning & Execution', organisation: 'Microsoft', linked: true, city: 'Hyderabad', startYear: 2022, startMonth: 7, endYear: null as number | null, endMonth: null as number | null, isCurrent: true, description: 'Orchestrating hyperscale cloud capacity allocation, datacenter supply continuity, and cross-functional APAC infrastructure planning.' },
  { k: 'tasl', title: 'Head - Projects, PPC & Industrial Eng.', organisation: 'Tata Advanced Systems Ltd (TASL)', linked: false, city: 'Aerospace & Defense CoE', startYear: 2012, startMonth: 7, endYear: 2022, endMonth: 6, isCurrent: false, description: 'Pioneered aerostructures assembly facilities, strategic supplier ecosystems, and lean manufacturing processes for global defense partners.' },
  { k: 'infosys', title: 'Senior Consultant - Supply Chain', organisation: 'Infosys Consulting', linked: false, city: 'Global Operations Practice', startYear: 2009, startMonth: 7, endYear: 2012, endMonth: 6, isCurrent: false, description: 'Executed end-to-end procurement transformation, inventory turn optimization, and ERP integration for Fortune 100 industrial clients.' },
];

// The design shows the BITS row twice; so does this.
const SRK_EDU = [
  { k: 'iitkgp', institution: 'Vinod Gupta School of Management, IIT Kharagpur', degree: 'Master of Business Administration (MBA)', fieldOfStudy: 'Operations & Strategy', startYear: 2009, endYear: 2011 },
  { k: 'bits-1', institution: 'Birla Institute of Technology and Science (BITS), Pilani', degree: 'Bachelor of Engineering (B.E. Hons)', fieldOfStudy: 'Engineering Honors', startYear: 2005, endYear: 2009 },
  { k: 'bits-2', institution: 'Birla Institute of Technology and Science (BITS), Pilani', degree: 'Bachelor of Engineering (B.E. Hons)', fieldOfStudy: 'Engineering Honors', startYear: 2005, endYear: 2009 },
];

const SRK_MENTEES = [
  { k: 'dev', first: 'Dev', last: 'Mangtani' },
  { k: 'ananya', first: 'Ananya', last: 'Das' },
  { k: 'kunal', first: 'Kunal', last: 'Bhatia' },
  { k: 'shruti', first: 'Shruti', last: 'Menon' },
  { k: 'yash', first: 'Yash', last: 'Agarwal' },
  { k: 'pooja', first: 'Pooja', last: 'Rathod' },
];

const SRK_REVIEWS = [
  { rating: 5, comment: 'Srikanth mapped my aerospace background onto cloud capacity planning in a single session: which skills carry over, which gaps to close first, and how to talk about both in an interview.' },
  { rating: 5, comment: 'Every call ended with one deliverable. The supplier-risk dashboard we built together became the case study I took to my promotion panel.' },
  { rating: 5, comment: 'Direct, structured and generous with templates. He pushed me to quantify every line of my resume, and the recruiter callbacks tripled within a month.' },
  { rating: 5, comment: 'Helped me think through an S&OP rollout and, more importantly, how to bring a sceptical operations head along. Would recommend to anyone moving into planning roles.' },
];

/**
 * The Offerings design's rows after the first. The first, '"What's going wrong?" Discovery Call', is a
 * PROGRAMME (SRK_PROGRAMME below): the API only has a syllabus, a term toggle and a preview on a programme,
 * and ICR lists a single session beside its programme as one "1:1 mentoring" offering.
 *
 * `fileLabel` is the display name stored with the download (the app shows a resource's tag from it):
 * no extension and a plain name keeps that name ("Curated Prompts"), a slug reads "Digital Guide", a real
 * extension reads from its kind ("PDF Guide"). The design's "Async Query • 24h TAT" / "Ask Query" row cannot
 * exist: written consultations are retired (RETIRED_MENTOR_SERVICE_TYPES), so the SOP row is a free checklist.
 */
const SRK_SERVICES = [
  {
    k: 'interview', type: 'ONE_ON_ONE', title: 'Personal Interview & GD Preparation',
    blurb: 'Structured STAR framework drills, case interview frameworks & behavioral narrative refinement.',
    durationMin: 15, price: 0, compareAt: null as number | null, sales: 3, rating: 4.9, ratingCount: 31, cover: null as string | null,
  },
  {
    k: 'linkedin', type: 'RESOURCE', title: 'LinkedIn Niche Bible (Strategy Handbook)',
    blurb: 'Step-by-step executive profile playbook to attract global recruiters and Fortune 500 hiring managers.',
    price: 900, compareAt: 49900, sales: 2, rating: 4.8, ratingCount: 19, file: 'linkedin-niche-bible', fileLabel: 'linkedin-niche-bible',
    pdf: ['LinkedIn Niche Bible', 'Strategy Handbook', 'Sample resource for local development.'],
  },
  {
    k: 'prompts', type: 'RESOURCE', title: 'AI & ChatGPT Prompts for Resume Building',
    blurb: '50+ battle-tested prompts engineered for ATS parsing and impactful achievement metrics.',
    price: 900, compareAt: 39900, sales: 2, rating: 4.7, ratingCount: 14, file: 'resume-prompts', fileLabel: 'Curated Prompts',
    pdf: ['AI & ChatGPT Prompts for Resume Building', '50+ prompts', 'Sample resource for local development.'],
  },
  {
    k: 'sop', type: 'RESOURCE', title: 'Statement of Purpose (SOP) Review',
    blurb: "Line-by-line feedback on academic, master's or executive business school admissions essays.",
    price: 0, compareAt: null, sales: 1, rating: 0, ratingCount: 0, file: 'sop-review-checklist', fileLabel: 'sop-review-checklist.pdf',
    pdf: ['Statement of Purpose (SOP) Review', 'Reviewer checklist', 'Sample resource for local development.'],
  },
  {
    k: 'mba', type: 'RESOURCE', title: 'MBA Placements Bible (Summer & Finals)',
    blurb: 'Comprehensive consulting & supply chain placement prep kit with previous interview transcripts.',
    price: 900, compareAt: 59900, sales: 2, rating: 4.9, ratingCount: 22, file: 'mba-placements-bible', fileLabel: 'PDF & Templates',
    pdf: ['MBA Placements Bible', 'Summer & Finals', 'Sample resource for local development.'],
  },
];

/**
 * The design's first row and its sheet: one diagnostic programme listed in three terms (the sheet's
 * "1 Month / 3 Months / 6 Months" toggle is these three plans, one title). The 1-month term is the design's
 * four weeks; it is free and it is the trial. "BEST SELLER" is 5+ subscribers, as it is for a service.
 */
const SRK_PROGRAMME = {
  title: '"What\'s going wrong?" Discovery Call',
  blurb: 'Diagnostic session uncovering key blockers in your job hunt, supply chain switch, or promotion path.',
  cover: designUrl('profile_offering_cover.jpg'),
  terms: [
    {
      k: '1m', months: 1, price: 0, subscribers: 6, sessionsPerMonth: 4, durationMin: 15,
      modules: [
        'Week 1: Career Diagnostic & Gap Analysis',
        'Week 2: Strategic Positioning & Resume',
        'Week 3: Mock Case Studies & Leadership Drills',
        'Week 4: Action Plan & Referral Cadence',
      ],
    },
    {
      k: '3m', months: 3, price: 1499900, subscribers: 2, sessionsPerMonth: 4, durationMin: 30,
      modules: [
        'Week 1: Career Diagnostic & Gap Analysis',
        'Week 2: Strategic Positioning & Resume',
        'Week 3: Mock Case Studies & Leadership Drills',
        'Week 4: Action Plan & Referral Cadence',
        'Week 5: Target Company Mapping',
        'Week 6: Network Leverage & Warm Introductions',
        'Week 7: Interview Frameworks, Round One',
        'Week 8: Interview Frameworks, Round Two',
        'Week 9: Offer Strategy & Negotiation',
        'Week 10: Stakeholder Management Drills',
        'Week 11: The First 90 Days Plan',
        'Week 12: Review, Retro & Next Moves',
      ],
    },
    {
      k: '6m', months: 6, price: 2499900, subscribers: 1, sessionsPerMonth: 2, durationMin: 30,
      modules: [
        'Career diagnostic & gap analysis',
        'Strategic positioning & resume',
        'Mock case studies & leadership drills',
        'Action plan & referral cadence',
        'Target company mapping',
        'Network leverage & warm introductions',
        'Interview frameworks',
        'Offer strategy & negotiation',
        'Stakeholder management',
        'The first 90 days plan',
        'Mid-programme review',
        'Retro & next moves',
      ],
    },
  ],
};

// ---------------------------------------------------------------------------
// Writers
// ---------------------------------------------------------------------------

interface Ctx {
  prisma: PrismaClient;
  log: Log;
  passwordHash: string;
  adminId: string | null;
}

async function upsertUser(
  c: Ctx,
  u: { key: string; first: string; last: string; avatar?: string | null; cover?: string | null; designation?: string | null; years?: number | null; languages?: string[]; branchId?: string | null },
) {
  const email = emailOf(u.key);
  const fields = {
    firstName: u.first,
    lastName: u.last,
    avatarUrl: u.avatar ?? null,
    coverImage: u.cover ?? null,
    designation: u.designation ?? null,
    yearsExperience: u.years ?? null,
    languages: u.languages ?? [],
    ...(u.branchId !== undefined ? { branchId: u.branchId } : {}),
  };
  return c.prisma.user.upsert({
    where: { email },
    update: fields,
    create: {
      id: idOf('u', u.key),
      email,
      passwordHash: c.passwordHash,
      role: 'PROFESSIONAL' as never,
      emailVerifiedAt: new Date(),
      ...fields,
    },
  });
}

/** What every listed mentor row shares (the showcase seed's approval fields). */
function profileBase(c: Ctx, over: Record<string, unknown>) {
  const now = Date.now();
  return {
    expertiseKeys: [],
    certifications: [],
    targetRoles: [],
    targetAudiences: ['WORKING_PROFESSIONAL', 'PEOPLE_LEADER'] as never,
    preferredModes: ['VIDEO', 'PHONE'] as never,
    cadence: 'FORTNIGHTLY' as never,
    timezone: 'Asia/Kolkata',
    status: 'APPROVED' as never,
    submittedAt: daysAgo(240),
    approvedAt: daysAgo(235),
    approvedById: c.adminId,
    approvalExpiresAt: new Date(now + 300 * DAY),
    conductAcceptedAt: daysAgo(235),
    conductVersion: CONDUCT_VERSION,
    trainingCompletedAt: daysAgo(236),
    screeningClearedAt: daysAgo(236),
    discoverable: true,
    deletedAt: null,
    isPaid: false,
    marketplaceTermsAcceptedAt: null,
    marketplaceTermsVersion: null,
    marketplaceSuspendedAt: null,
    serviceRating: 0,
    serviceRatingCount: 0,
    ...over,
  };
}

async function upsertProfile(c: Ctx, key: string, userId: string, data: Record<string, unknown>) {
  return c.prisma.mentorProfile.upsert({
    where: { userId },
    update: data as never,
    create: { id: idOf('mp', key), userId, ...data } as never,
  });
}

async function replaceCareer(
  c: Ctx,
  userId: string,
  key: string,
  roles: { k: string; title: string; organisation: string; companyId?: string | null; city?: string | null; startYear: number; startMonth?: number | null; endYear?: number | null; endMonth?: number | null; isCurrent: boolean; description?: string | null }[],
  edu: { k: string; institution: string; degree?: string | null; fieldOfStudy?: string | null; startYear?: number | null; endYear?: number | null }[] = [],
) {
  await c.prisma.userExperience.deleteMany({ where: { userId } });
  await c.prisma.userExperience.createMany({
    data: roles.map((r, i) => ({
      id: idOf('exp', key, r.k),
      userId,
      title: r.title,
      organisation: r.organisation,
      companyId: r.companyId ?? null,
      city: r.city ?? null,
      startYear: r.startYear,
      startMonth: r.startMonth ?? null,
      endYear: r.endYear ?? null,
      endMonth: r.endMonth ?? null,
      isCurrent: r.isCurrent,
      description: r.description ?? null,
      sortOrder: i,
    })),
  });
  await c.prisma.userEducation.deleteMany({ where: { userId } });
  if (edu.length) {
    await c.prisma.userEducation.createMany({
      data: edu.map((e, i) => ({
        id: idOf('edu', key, e.k),
        userId,
        institution: e.institution,
        degree: e.degree ?? null,
        fieldOfStudy: e.fieldOfStudy ?? null,
        startYear: e.startYear ?? null,
        endYear: e.endYear ?? null,
        sortOrder: i,
      })),
    });
  }
}

/** A directory mentor: account, listed profile, one current role. */
async function seedPersona(c: Ctx, p: Persona) {
  const headline = `${p.title} @ ${p.company}`;
  const user = await upsertUser(c, {
    key: p.key, first: p.first, last: p.last, avatar: p.avatar, cover: p.cover,
    designation: headline, years: p.years, languages: p.languages,
  });
  const bio =
    p.bio ||
    `${p.first} has spent ${p.years} years in facilities, workplace and real estate operations and is now ${p.title} at ${p.company}. ` +
      `Mentors on ${p.chips.slice(0, 3).join(', ')}.`;
  await upsertProfile(
    c,
    p.key,
    user.id,
    profileBase(c, {
      headline,
      bioHtml: `<p>${bio.replace(/&/g, '&amp;')}</p>`,
      yearsExperience: p.years,
      competencies: p.competencies,
      languages: p.languages,
      topics: ['Career transitions', 'Stakeholder management'],
      capacity: p.capacity,
      availabilityNote: 'Weekday evenings IST.',
      rating: p.rating,
      ratingCount: p.ratingCount,
      sessionsCompleted: p.sessions,
      menteesHelped: p.mentees,
    }),
  );
  await replaceCareer(c, user.id, p.key, [
    {
      k: 'current', title: p.title, organisation: p.company, startYear: 2016 + (p.index % 6), startMonth: 4, isCurrent: true,
      description: `${p.title} at ${p.company}.`,
    },
  ]);
  return user.id;
}

// --- storefront rows ----------------------------------------------------------

async function upsertService(
  c: Ctx,
  profileId: string,
  ownerId: string,
  key: string,
  s: { k: string; type: string; title: string; blurb: string; durationMin?: number; price: number; compareAt?: number | null; sales: number; rating: number; ratingCount: number; cover?: string | null; file?: string; fileLabel?: string; pdf?: string[] },
  sortOrder: number,
) {
  let upload: { uploadId: string; fileName: string; fileSize: number } | null = null;
  if (s.type === 'RESOURCE' && s.file && s.pdf) {
    // The download: a small PDF behind a PRIVATE upload, owned by the mentor, as the storefront manager stores it.
    // The display name has no extension, so the app words the tag "Digital Guide" (the design's first resource).
    const filename = `${UP}res-${s.file}.pdf`;
    const bytes = tinyPdf(s.pdf);
    writeFileSync(join(UPLOADS(), filename), bytes);
    await c.prisma.uploadedFile.upsert({
      where: { filename },
      update: { size: bytes.length, ownerId, name: s.fileLabel ?? s.file },
      create: { filename, visibility: 'PRIVATE' as never, purpose: 'mentor-resource', ownerId, name: s.fileLabel ?? s.file, mimeType: 'application/pdf', size: bytes.length },
    });
    upload = { uploadId: filename, fileName: s.fileLabel ?? s.file, fileSize: bytes.length };
  }
  const data = {
    mentorProfileId: profileId,
    type: s.type as never,
    title: s.title,
    blurb: s.blurb,
    coverUrl: s.cover ?? null,
    durationMin: s.durationMin ?? null,
    pricePaisa: s.price,
    compareAtPaisa: s.compareAt ?? null,
    uploadId: upload?.uploadId ?? null,
    fileName: upload?.fileName ?? null,
    fileSize: upload?.fileSize ?? null,
    active: true,
    sortOrder,
    salesCount: s.sales,
    rating: s.rating,
    ratingCount: s.ratingCount,
    deletedAt: null,
  };
  const id = idOf('svc', key, s.k);
  await c.prisma.mentorService.upsert({ where: { id }, update: data as never, create: { id, ...data } as never });
  return id;
}

async function upsertPlan(
  c: Ctx,
  profileId: string,
  key: string,
  pl: { k: string; kind: 'RECURRING' | 'CURRICULUM'; title: string; blurb: string; price: number; sessionsPerMonth: number; durationMin?: number | null; billingMonths?: number; totalSessions?: number; accessMonths?: number; inclusions: string[]; subscribers: number; modules?: { title: string; outline: string }[]; cover?: string | null },
  sortOrder: number,
) {
  const id = idOf('plan', key, pl.k);
  const data = {
    mentorProfileId: profileId,
    title: pl.title,
    blurb: pl.blurb,
    coverUrl: pl.cover ?? null,
    kind: pl.kind as never,
    pricePaisa: pl.price,
    billingPeriodMonths: pl.billingMonths ?? 1,
    sessionsPerMonth: pl.sessionsPerMonth,
    sessionDurationMin: pl.durationMin ?? null,
    totalSessions: pl.totalSessions ?? null,
    accessMonths: pl.accessMonths ?? null,
    inclusions: pl.inclusions,
    active: true,
    sortOrder,
    subscribersCount: pl.subscribers,
    deletedAt: null,
  };
  await c.prisma.mentorPlan.upsert({ where: { id }, update: data as never, create: { id, ...data } as never });
  await c.prisma.mentorPlanModule.deleteMany({ where: { planId: id } });
  if (pl.modules?.length) {
    await c.prisma.mentorPlanModule.createMany({
      data: pl.modules.map((m, i) => ({ id: `${id}-m${i + 1}`, planId: id, position: i + 1, title: m.title, outline: m.outline, durationMin: pl.durationMin ?? 60 })),
    });
  }
  return id;
}

/**
 * Drops this script's own services/plans that the current list no longer names (a changed script, re-run).
 * One that a purchase or subscription still points at cannot be deleted: it is switched off and soft-deleted
 * instead, so the storefront stops listing it.
 */
async function pruneStorefront(c: Ctx, profileId: string, keepServices: string[], keepPlans: string[]) {
  const where = (keep: string[]) => ({ mentorProfileId: profileId, id: { startsWith: PREFIX, notIn: keep } });
  try {
    await c.prisma.mentorService.deleteMany({ where: where(keepServices) });
  } catch {
    await c.prisma.mentorService.updateMany({ where: where(keepServices), data: { active: false, deletedAt: new Date() } as never });
    c.log('  (a service something was bought from was retired instead of deleted)');
  }
  try {
    await c.prisma.mentorPlan.deleteMany({ where: where(keepPlans) });
  } catch {
    await c.prisma.mentorPlan.updateMany({ where: where(keepPlans), data: { active: false, deletedAt: new Date() } as never });
    c.log('  (a plan something was bought from was retired instead of deleted)');
  }
}

async function setAvailability(c: Ctx, profileId: string, key: string, blocks: [weekday: number, startMin: number, endMin: number][]) {
  await c.prisma.mentorAvailabilityBlock.deleteMany({ where: { mentorProfileId: profileId } });
  await c.prisma.mentorAvailabilityBlock.createMany({
    data: blocks.map(([weekday, startMin, endMin], i) => ({ id: idOf('avail', key, i), mentorProfileId: profileId, weekday, startMin, endMin })),
  });
}

// --- Rajesh Sharma: the landing's storefront ------------------------------------

async function seedRajeshStorefront(c: Ctx, profileId: string, userId: string) {
  // Gates for a live storefront: approved + seller terms accepted + not suspended.
  await c.prisma.mentorProfile.update({
    where: { id: profileId },
    data: { isPaid: true, marketplaceTermsAcceptedAt: daysAgo(200), marketplaceTermsVersion: TERMS_VERSION, marketplaceSuspendedAt: null, serviceRating: 4.9, serviceRatingCount: 24 },
  });
  // "Featured Advisory Sessions" reads the first three active services of the
  // first live storefront, in this order. The design's third card is an
  // "Async Query"; the API retired that service type (RETIRED_MENTOR_SERVICE_TYPES)
  // and never lists it, so a free resource with the design's words stands in.
  const services = [
    { k: 'diagnostic', type: 'ONE_ON_ONE', title: "What's going wrong? Discovery Call", blurb: "Stuck in your career trajectory or struggling with enterprise interviews? Let's diagnose the root cause.", durationMin: 30, price: 0, sales: BEST_SELLER + 20, rating: 4.9, ratingCount: 41 },
    { k: 'session', type: 'ONE_ON_ONE', title: 'Personal Interview & Leadership Strategy', blurb: 'Tailored mock interview frameworks, behavioral STAR storytelling, and executive salary negotiation.', durationMin: 45, price: 149900, sales: 9, rating: 4.8, ratingCount: 17 },
    { k: 'review', type: 'RESOURCE', title: 'Enterprise Resume & LinkedIn Niche Review', blurb: 'Detailed audit of your CV mapped to hiring criteria of JLL, CBRE, and Fortune 500 tech campuses.', price: 0, sales: 4, rating: 4.9, ratingCount: 12, file: 'enterprise-resume-review', pdf: ['Enterprise Resume & LinkedIn Niche Review', 'Audit checklist', 'Sample resource for local development.'] },
  ];
  const svcIds: string[] = [];
  for (const [i, s] of services.entries()) svcIds.push(await upsertService(c, profileId, userId, 'rajesh-1', s, i));

  const planIds = [
    await upsertPlan(c, profileId, 'rajesh-1', {
      k: 'coaching', kind: 'RECURRING', title: 'Monthly leadership coaching', blurb: 'Two calls a month and a standing review of your portfolio and site plans.',
      price: 999900, sessionsPerMonth: 2, durationMin: 45, inclusions: ['Two 45-minute 1:1 calls a month', 'Review of your site and portfolio plans', 'Chat support between calls'], subscribers: 4,
    }, 0),
    await upsertPlan(c, profileId, 'rajesh-1', {
      k: 'programme', kind: 'CURRICULUM', title: 'Site to portfolio: a 4-session programme', blurb: 'A fixed syllabus for making the jump from running a site to owning a portfolio.',
      price: 799900, sessionsPerMonth: 2, durationMin: 60, totalSessions: 4, accessMonths: 3, inclusions: ['Session notes after every call', 'Templates for each module'], subscribers: 2,
      modules: [
        { title: 'Where you are, where you want to be', outline: 'Role scope, gaps and a 90-day target.' },
        { title: 'Vendor and SLA governance', outline: 'Reading, scoring and renegotiating an SLA.' },
        { title: 'The portfolio business case', outline: 'Occupancy, cost and a case finance will sign.' },
        { title: 'Interview and panel readiness', outline: 'A full mock panel with written feedback.' },
      ],
    }, 1),
  ];
  await pruneStorefront(c, profileId, svcIds, planIds);
  await setAvailability(c, profileId, 'rajesh-1', [[2, 18 * 60, 20 * 60], [4, 18 * 60, 20 * 60]]);

  // An upcoming group session (a free clinic) so the Group Sessions filter has a row.
  const when = daysAhead(10);
  when.setUTCHours(13, 30, 0, 0); // 7:00 PM IST
  const sessionId = idOf('group', 'rajesh-1');
  const base = {
    hostId: userId,
    title: 'Running a smart campus: an open clinic',
    summary: 'An hour on BMS integration, vendor SLAs and the first ninety days of a smart-building programme. Bring your questions.',
    scheduledAt: when,
    durationMin: 60,
    mode: 'VIDEO' as never,
    timezone: 'Asia/Kolkata',
    capacity: 40,
    waitlistEnabled: true,
    focusAreas: ['Smart campuses'],
    competencies: ['Smart Buildings & IoT', 'Facility Management'],
    status: 'SCHEDULED' as never,
    deletedAt: null,
  };
  await c.prisma.mentorshipGroupSession.upsert({ where: { id: sessionId }, update: base as never, create: { id: sessionId, ...base } as never });
  const occId = idOf('group', 'rajesh-1', 'occ1');
  await c.prisma.mentorshipGroupSessionOccurrence.upsert({
    where: { id: occId },
    update: { scheduledAt: when, durationMin: 60, status: 'SCHEDULED' as never },
    create: { id: occId, sessionId, seq: 1, scheduledAt: when, durationMin: 60, status: 'SCHEDULED' as never },
  });
  c.log('  Rajesh Sharma: live storefront (3 services), a plan, a programme, an upcoming group session');
}

// --- Srikanth Sriramagiri ----------------------------------------------------------

async function seedSrikanth(c: Ctx, hydBranchId: string | null, linkedCompanyId: string) {
  const user = await upsertUser(c, {
    key: SRK.key, first: SRK.first, last: SRK.last,
    avatar: designUrl('profile_avatar.png'), cover: designUrl('profile_cover.jpg'),
    designation: SRK.headline, years: SRK.years, languages: SRK.languages,
    // "Hyderabad" on the hero comes from the person's office; no company is set on the account.
    branchId: hydBranchId,
  });
  const profile = await upsertProfile(
    c,
    SRK.key,
    user.id,
    profileBase(c, {
      headline: SRK.headline,
      bioHtml: SRK.bioHtml,
      yearsExperience: SRK.years,
      competencies: SRK.competencies,
      languages: SRK.languages,
      topics: SRK.topics,
      targetRoles: ['Supply Chain Manager', 'Planning Lead'],
      // open slots = capacity - live pairings = 4 - 2 = 2  ->  "Only 2 slots left"
      capacity: 4,
      preferredModes: ['VIDEO', 'IN_PERSON'] as never,
      availabilityNote: 'Mondays, Thursdays and Saturdays, 7 to 9 PM IST.',
      rating: 5,
      ratingCount: 42,
      sessionsCompleted: 26,
      menteesHelped: 12,
      isPaid: true,
      marketplaceTermsAcceptedAt: daysAgo(200),
      marketplaceTermsVersion: TERMS_VERSION,
      serviceRating: 4.9,
      serviceRatingCount: 18,
    }),
  );
  await replaceCareer(
    c, user.id, SRK.key,
    SRK_ROLES.map((r) => ({ ...r, companyId: r.linked ? linkedCompanyId : null })),
    SRK_EDU,
  );

  // Mondays, Thursdays and Saturdays, 7-9 PM: "Mon, Thu, Sat slots" and the Next Slot pill.
  await setAvailability(c, profile.id, SRK.key, [[1, 19 * 60, 21 * 60], [4, 19 * 60, 21 * 60], [6, 19 * 60, 21 * 60]]);

  // --- storefront: the six rows of the Offerings design, then the plan card ----------
  const svcIds: string[] = [];
  for (const [i, sv] of SRK_SERVICES.entries()) {
    svcIds.push(await upsertService(c, profile.id, user.id, SRK.key, sv, 10 + i * 10));
  }
  const planId = await upsertPlan(c, profile.id, SRK.key, {
    k: 'pro', kind: 'RECURRING', title: 'Pro Mentorship Tier', blurb: 'Two live strategy calls a month, with support in between.',
    price: 1250000, sessionsPerMonth: 2, durationMin: null,
    inclusions: ['2 dedicated live 1:1 strategy calls each month', 'Unlimited async Slack / WhatsApp query support', 'Direct resume & LinkedIn profile optimization'],
    subscribers: 6,
  }, 0);
  const planIds = [planId];
  for (const [i, t] of SRK_PROGRAMME.terms.entries()) {
    planIds.push(
      await upsertPlan(c, profile.id, SRK.key, {
        k: `discovery-${t.k}`, kind: 'CURRICULUM', title: SRK_PROGRAMME.title, blurb: SRK_PROGRAMME.blurb,
        price: t.price, sessionsPerMonth: t.sessionsPerMonth, durationMin: t.durationMin,
        totalSessions: t.modules.length, accessMonths: t.months, billingMonths: t.months,
        inclusions: [], subscribers: t.subscribers,
        modules: t.modules.map((title) => ({ title, outline: '' })),
        cover: SRK_PROGRAMME.cover,
      }, 1 + i),
    );
  }
  await pruneStorefront(c, profile.id, svcIds, planIds);

  // --- mentees, pairings (4 finished + 2 live), sessions and written reviews ---------
  const mentees: { id: string }[] = [];
  for (const m of SRK_MENTEES) mentees.push(await upsertUser(c, { key: `mentee-${m.k}`, first: m.first, last: m.last }));
  const replyHours = [3, 5, 2, 8, 4, 6];
  const pairs: { id: string }[] = [];
  for (const [i, mentee] of mentees.entries()) {
    const age = 170 - i * 25;
    const createdAt = daysAgo(age);
    const completed = i < SRK_REVIEWS.length;
    const requestId = idOf('req', SRK.key, i);
    await c.prisma.mentorshipRequest.upsert({
      where: { id: requestId },
      update: {},
      create: {
        id: requestId, mentorProfileId: profile.id, menteeId: mentee.id,
        message: 'I would value your guidance on moving into supply planning and capacity roles.',
        focusAreas: ['Career transitions'], matchScore: 80 + i, status: 'ACCEPTED' as never,
        responseNote: 'Happy to help. Bring your current role scope to our first call.',
        respondedAt: new Date(createdAt.getTime() + replyHours[i] * 3_600_000), createdAt,
      },
    });
    const pairId = idOf('pair', SRK.key, i);
    const count = i < 2 ? 6 : i < 4 ? 5 : 2;
    await c.prisma.mentorship.upsert({
      where: { id: pairId },
      update: {},
      create: {
        id: pairId, mentorId: user.id, menteeId: mentee.id, mentorProfileId: profile.id, requestId,
        cadence: 'FORTNIGHTLY' as never, status: (completed ? 'COMPLETED' : 'ACTIVE') as never,
        startedAt: daysAgo(age - 1), completedAt: completed ? daysAgo(Math.max(age - 90, 5)) : null,
        sessionsCount: count, totalMinutes: count * 45,
      },
    });
    pairs.push({ id: pairId });
  }
  // 26 completed 1:1 sessions behind the "26 sessions" figure.
  let n = 0;
  for (const [i, p] of pairs.entries()) {
    const count = i < 2 ? 6 : i < 4 ? 5 : 2;
    for (let k = 0; k < count; k++) {
      n += 1;
      const when = daysAgo(Math.max(160 - i * 25 - k * 12, 2));
      await c.prisma.mentorshipSession.upsert({
        where: { id: idOf('sess', SRK.key, n) },
        update: {},
        create: {
          id: idOf('sess', SRK.key, n), mentorshipId: p.id, createdById: user.id, agenda: `Session ${n}`,
          scheduledAt: when, durationMin: 45, mode: 'VIDEO' as never, status: 'COMPLETED' as never, completedAt: when,
        },
      });
    }
  }
  for (const [i, r] of SRK_REVIEWS.entries()) {
    const data = {
      mentorshipId: pairs[i].id, authorId: mentees[i].id, rating: r.rating, wouldRecommend: true, comment: r.comment,
      // about a year old, so they read "1 yr ago"
      createdAt: daysAgo(380 + i * 30),
    };
    await c.prisma.mentorshipFeedback.upsert({ where: { id: idOf('fb', SRK.key, i) }, update: data as never, create: { id: idOf('fb', SRK.key, i), ...data } as never });
  }

  // --- the recommendation on the Overview: a named testimonial with a photo ----------
  const tid = idOf('testimonial', SRK.key, 'dev');
  const t = {
    authorName: 'Dev Mangtani',
    authorTitle: 'Operations Analyst',
    avatarUrl: designUrl('profile_reviewer.png'),
    quote:
      'I really liked how the session provided comprehensive knowledge about upcoming corporate internship opportunities, clarifying my transition doubts from aerospace to cloud logistics. Srikanth sir is exceptionally structured!',
    mentorProfileId: profile.id,
    published: true,
    sortOrder: 0,
    // About a year old, so it reads "1 yr ago" once the public testimonials endpoint sends `createdAt`.
    createdAt: daysAgo(380),
  };
  await c.prisma.mentorTestimonial.upsert({ where: { id: tid }, update: t, create: { id: tid, ...t } });
  c.log(`  Srikanth Sriramagiri: profile, 3 roles, 3 degrees, hours (Mon/Thu/Sat), ${SRK_SERVICES.length} services + the diagnostic programme in ${SRK_PROGRAMME.terms.length} terms + the Pro Mentorship Tier, 6 pairings, ${n} sessions, ${SRK_REVIEWS.length} reviews, 1 testimonial`);
  return { profileId: profile.id, userId: user.id, menteeIds: mentees.map((m) => m.id) };
}

// --- the cohort card -----------------------------------------------------------------

async function seedCohort(c: Ctx, roster: Persona[], userIds: Map<string, string>, menteeIds: string[]) {
  const organiser = await upsertUser(c, { key: 'organiser-rk', first: 'Rohit', last: 'Khanna', designation: 'Programme Director' });
  const pid = idOf('cohort', 'fm-leadership-esg');
  const data = {
    slug: 'fm-leadership-esg-masterclass',
    name: 'FM Leadership & ESG Masterclass',
    summary: 'Six weeks for facility and real estate leaders on running ESG-ready operations: live sessions with ICR mentors, a peer cohort and a certificate on completion.',
    detailHtml:
      '<p>A cohort for senior facility and real estate leaders who own an ESG target and need an operating plan behind it.</p><h3>What you get</h3><ul><li>Six weekly live sessions with ICR mentors</li><li>A peer group of leaders from across the industry</li><li>CPD hours logged automatically</li><li>An ICR certificate on completion</li></ul>',
    coverUrl: designUrl('profile_offering_cover.jpg'),
    status: 'OPEN' as never,
    applicationsOpenAt: daysAgo(6),
    applicationsCloseAt: daysAhead(28),
    // later than the programme already open, so it is the one the landing lists first (startsAt, newest first)
    startsAt: daysAhead(60),
    endsAt: daysAhead(102),
    menteeCapacity: 60,
    mentorCapacity: 40,
    focusAreas: ['ESG strategy', 'Operations leadership'],
    competencies: ['Sustainability & ESG', 'Operations & FM'],
    createdById: organiser.id,
    deletedAt: null,
  };
  await c.prisma.mentorshipProgram.upsert({ where: { id: pid }, update: data as never, create: { id: pid, ...data } as never });

  // 32 registered: 26 mentors (Set B and the first filler mentors) and the 6 mentees.
  let enrolled = 0;
  const mentors = roster.slice(8, 34);
  for (const p of mentors) {
    const userId = userIds.get(p.key)!;
    const eid = idOf('enrol', 'fm-leadership-esg', p.key);
    await c.prisma.mentorshipProgramEnrolment.upsert({
      where: { id: eid },
      update: {},
      create: { id: eid, programId: pid, userId, role: 'MENTOR' as never, status: 'ACCEPTED' as never, motivation: 'Glad to lead a session on my own area.', decidedById: organiser.id, decidedAt: new Date() },
    });
    enrolled += 1;
  }
  for (const [i, userId] of menteeIds.entries()) {
    const eid = idOf('enrol', 'fm-leadership-esg', `mentee-${i}`);
    await c.prisma.mentorshipProgramEnrolment.upsert({
      where: { id: eid },
      update: {},
      create: {
        id: eid, programId: pid, userId, role: 'MENTEE' as never, status: (i < 3 ? 'ACCEPTED' : 'APPLIED') as never,
        motivation: 'I own an ESG target at my site and want an operating plan behind it.',
        ...(i < 3 ? { decidedById: organiser.id, decidedAt: new Date() } : {}),
      },
    });
    enrolled += 1;
  }
  c.log(`  cohort "${data.name}": open, ${enrolled} registered, organiser Rohit Khanna ("RK")`);
}

// ---------------------------------------------------------------------------
// Seed
// ---------------------------------------------------------------------------

export interface MentorshipSeedSummary {
  mentors: number;
  rajeshProfileId: string;
  srikanthProfileId: string;
  cohortSlug: string;
}

export async function seedMentorship(
  prisma: PrismaClient,
  log: (m: string) => void,
  opts?: { remove?: boolean },
): Promise<MentorshipSeedSummary | void> {
  assertBackendCwd();
  const where = assertLocalDatabase();
  if (opts?.remove) {
    log(`Removing the mentorship design fixtures from ${where} ...`);
    await removeAll(prisma, log);
    return;
  }
  log(`Seeding the mentorship design fixtures into ${where} ...`);

  const portraits = (() => {
    const all = readdirSync(FACES_DIR()).sort();
    return { f: all.filter((x) => x.startsWith('female-')), m: all.filter((x) => x.startsWith('male-')) };
  })();
  const roster = buildRoster(portraits);
  copyAssets([...roster.filter((p) => p.group === 'F').map((p) => p.avatar.replace(`/uploads/${UP}face-`, ''))], log);

  const c: Ctx = {
    prisma,
    log,
    passwordHash: bcrypt.hashSync(seedPassword('Password123!'), 10),
    adminId: (await prisma.user.findFirst({ where: { role: 'SUPER_ADMIN' }, select: { id: true } }))?.id ?? null,
  };

  // What the rest of the platform already contributes to each competency label.
  const others = new Map<string, number>();
  const existing = await prisma.mentorProfile.findMany({
    where: { deletedAt: null, discoverable: true, status: 'APPROVED' as never, NOT: { id: { startsWith: PREFIX } } },
    select: { competencies: true },
  });
  for (const m of existing) for (const l of m.competencies) others.set(l, (others.get(l) ?? 0) + 1);
  assignCompetencies(roster, others, log);

  // The page a role can link to (turns "Microsoft Corporation" blue on the Career Journey).
  const company = await prisma.company.upsert({
    where: { id: idOf('co', 'microsoft') },
    update: { name: 'Microsoft Corporation', deletedAt: null, suspendedAt: null },
    create: {
      id: idOf('co', 'microsoft'), name: 'Microsoft Corporation', type: 'CORPORATE' as never,
      description: 'Design fixture for the mobile app (see tool/seed/mentorship.ts).', city: 'Hyderabad', country: 'India',
      source: SOURCE, sourceId: 'microsoft-corporation',
    },
  });

  const userIds = new Map<string, string>();
  for (const p of roster) userIds.set(p.key, await seedPersona(c, p));
  log(`  ${roster.length} directory mentors (set A: the design's eight; set B: the same eight again; 32 more)`);

  const rajesh = roster[0];
  await seedRajeshStorefront(c, idOf('mp', rajesh.key), userIds.get(rajesh.key)!);

  const hyd = await prisma.branch.findFirst({ where: { city: 'Hyderabad', deletedAt: null }, orderBy: { createdAt: 'asc' }, select: { id: true } });
  if (!hyd) log('  ! no Hyderabad office on file: the profile will show no city');
  const srk = await seedSrikanth(c, hyd?.id ?? null, company.id);

  await seedCohort(c, roster, userIds, srk.menteeIds);

  // A check on the part that is arithmetic: how the platform's facets read now.
  const after = await prisma.mentorProfile.findMany({
    where: { deletedAt: null, discoverable: true, status: 'APPROVED' as never },
    select: { competencies: true },
  });
  const tally = new Map<string, number>();
  for (const m of after) for (const l of m.competencies) tally.set(l, (tally.get(l) ?? 0) + 1);
  const ranked = [...tally.entries()].sort((a, b) => b[1] - a[1]).slice(0, FACET_PLAN.length);
  const planned = FACET_PLAN.map(([l]) => l);
  const ok = ranked.every(([l], i) => l === planned[i]);
  log(`  facets: ${ok ? 'top 17 labels read in the planned order' : '! top 17 differ from the plan: ' + ranked.map(([l, k]) => `${l}(${k})`).join(', ')}`);

  log('Done.');
  log('  sign in as any account with Password123! (or SEED_PASSWORD), e.g. ' + emailOf('srikanth'));
  log('  NOT showable through the API (see docs/screens/mentorship.md): Async Query offerings (retired type), the three RK / AN / SJ cohort');
  log('  avatars (the API does not say who registered), review stars/age on a named recommendation. The app words the rest itself:');
  log('  both grids titled "Top Mentors in Your Network", "50+ Domains" (the count rounded down), the banner photo and "60+ senior leaders" copy,');
  log('  per-company wordmark colours (JLL red, CBRE blue), the topic tints (red = selected, blue = suggested).');
  return { mentors: roster.length, rajeshProfileId: idOf('mp', rajesh.key), srikanthProfileId: srk.profileId, cohortSlug: 'fm-leadership-esg-masterclass' };
}

// ---------------------------------------------------------------------------
// Remove
// ---------------------------------------------------------------------------

async function removeAll(prisma: PrismaClient, log: Log) {
  const startsWith = { startsWith: PREFIX };
  const step = async (label: string, fn: () => Promise<{ count: number } | void>) => {
    try {
      const r = await fn();
      log(`  ${label}${r && 'count' in r ? `: ${r.count}` : ''}`);
    } catch (e) {
      log(`  ! ${label} failed: ${(e as Error).message.split('\n').filter(Boolean).pop()}`);
    }
  };

  // Things hung on the fixtures by whoever tried the app against them.
  await step('plan subscriptions on the fixture plans', async () => {
    const subs = await prisma.mentorPlanSubscription.findMany({ where: { plan: { id: startsWith } }, select: { id: true } });
    if (subs.length) {
      await prisma.mentorPlanSubscriptionStep.deleteMany({ where: { subscriptionId: { in: subs.map((s) => s.id) } } });
    }
    return prisma.mentorPlanSubscription.deleteMany({ where: { plan: { id: startsWith } } });
  });
  await step('purchases of the fixture services', async () => {
    const purchases = await prisma.mentorServicePurchase.findMany({ where: { service: { id: startsWith } }, select: { id: true } });
    const ids = purchases.map((p) => p.id);
    if (ids.length) {
      await prisma.mentorServiceReview.deleteMany({ where: { purchaseId: { in: ids } } });
      await prisma.mentorServiceBooking.deleteMany({ where: { purchaseId: { in: ids } } });
    }
    return prisma.mentorServicePurchase.deleteMany({ where: { id: { in: ids } } });
  });

  await step('cohort programme (and its registrations)', () => prisma.mentorshipProgram.deleteMany({ where: { id: startsWith } }));
  await step('group sessions', () => prisma.mentorshipGroupSession.deleteMany({ where: { id: startsWith } }));
  await step('testimonials', () => prisma.mentorTestimonial.deleteMany({ where: { id: startsWith } }));
  await step('mentor profiles (services, plans, hours, requests, pairings, sessions, reviews follow)', () =>
    prisma.mentorProfile.deleteMany({ where: { id: startsWith } }),
  );
  // Signing in as a fixture account (a test, the app on a device) leaves audit entries that name it, and an
  // account with one cannot be deleted: they go first.
  await step('audit entries made by the fixture accounts', () => prisma.auditLog.deleteMany({ where: { actorId: startsWith } }));
  await step('accounts (career history goes with them)', () => prisma.user.deleteMany({ where: { id: startsWith } }));
  await step('company page', async () => {
    const co = await prisma.company.findMany({ where: { id: startsWith, source: SOURCE }, select: { id: true } });
    let removed = 0;
    for (const x of co) {
      const [jobs, members, branches] = await Promise.all([
        prisma.job.count({ where: { companyId: x.id } }),
        prisma.user.count({ where: { companyId: x.id } }),
        prisma.branch.count({ where: { companyId: x.id } }),
      ]);
      if (jobs || members || branches) {
        log(`  (company ${x.id} is used by someone else now; left in place)`);
        continue;
      }
      await prisma.company.delete({ where: { id: x.id } });
      removed += 1;
    }
    return { count: removed };
  });
  await step('upload records', () => prisma.uploadedFile.deleteMany({ where: { filename: { startsWith: UP } } }));

  // The copied files themselves.
  let files = 0;
  const dir = UPLOADS();
  if (existsSync(dir)) {
    for (const f of readdirSync(dir)) {
      if (f.startsWith(UP) && statSync(join(dir, f)).isFile()) {
        rmSync(join(dir, f));
        files += 1;
      }
    }
  }
  log(`  files in backend/uploads: ${files}`);
  log('Removed.');
}

// ---------------------------------------------------------------------------
// Alone
// ---------------------------------------------------------------------------

if (require.main === module) {
  const prisma = new PrismaClient();
  seedMentorship(prisma, (m) => console.log(m), { remove: process.argv.includes('--remove') })
    .catch((e) => {
      console.error(e);
      process.exitCode = 1;
    })
    .finally(() => prisma.$disconnect());
}
