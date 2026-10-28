/**
 * Seeds the Marketplace content of the mobile app's designs into the LOCAL
 * portal database, so the app reads it through the portal's real API.
 *
 *   cd E:\ICR\irc-portal\backend          (cwd must be the backend folder: `uploads` resolves from it)
 *   NODE_PATH=E:/ICR/irc-portal/node_modules npx ts-node --transpile-only E:/ICR/icr-mobile/tool/seed/marketplace.ts
 *   ... same command with --remove        (deletes what this script created)
 *   ... also: --no-fill (leave out the filler suppliers), --dry-run
 *
 * Idempotent: every row has a stable id and is upserted, so a re-run restores
 * the designed state.
 *
 * Markers (all removable): company ids `design-mkt-co-*`, listing ids
 * `design-mkt-v-*`, office ids `design-mkt-br-*`, service ids `design-mkt-sv-*`,
 * product ids `design-mkt-pr-*`, certification types with slugs `design-mkt-*`,
 * people with ids `design-mkt-u-*` (emails `*@marketplace-design.icr.test`),
 * files /uploads/design-mkt-*. Nothing existing is changed.
 *
 * What is seeded
 *   The ten cards of the Marketplace design (BlueDot, six InnoWork, GreenGuard,
 *   SecureTech, SafeHome), each a verified supplier listing with the mark of its
 *   logo (cut from the design by tool/design/cut_marketplace_logos.py), its
 *   title (`headline`), its two lines (the company's description), its rating
 *   and review count. All ten are paid placements at the top rung, so they lead
 *   the "Top rated" order ahead of the portal's own demo suppliers (which top out
 *   at 4.4 on that rung), in the order of their ratings. The six InnoWorks are six
 *   companies of one name, as the design repeats it.
 *   Vikasha Aero Tech, the supplier of the profile designs: Pvt Ltd, a registration
 *   line, 4.9 from 84 ratings, Tier-1 (Elite), four offices (Bengaluru HQ with its
 *   phone, Hyderabad, Pune, Chennai), six services, four certifications, two audited
 *   proofs (ratings with the design's comments, by two of the portal's own test
 *   accounts). It is not a paid placement, so it sits below the ten cards:
 *   search "Vikasha" to find it.
 *   Three products of SecureTech, so a product page has something to open.
 *   Filler: enough plain verified suppliers (ids `design-mkt-co-fill-*`) that the
 *   directory reads "Showing 10 of 180+ verified enterprise suppliers" as the design does.
 *
 * Things the API cannot carry, and what the seed does about them
 *   - The profile's "Reg. CIN-U74999KA2019PTC1": the portal stores no CIN (nor does it
 *     publish a GSTIN or PAN). The only registration number a listing publishes is
 *     `Vendor.msmeNumber`, so the seed puts the design's string there. A real
 *     supplier's line reads "Reg. UDYAM-...". See docs/backend-requests/marketplace.md.
 *   - The services' photos: `Service` has no image column (same request).
 *   - "0 Safety Incidents" and "42+ Commercial Towers Under Active AMCs": no such fields;
 *     the live tiles read projects, clients served, years and offices.
 *
 * It refuses to run unless the database is on localhost.
 */
import type { Prisma, PrismaClient } from '@prisma/client';
import { copyFileSync, existsSync, mkdirSync, readFileSync, unlinkSync } from 'fs';
import * as bcrypt from 'bcryptjs';
import { join, resolve } from 'path';

const PREFIX = 'design-mkt-';
const SEED_ASSETS = resolve(__dirname, 'assets');
/** The design's "180+": the verified suppliers the directory should hold in all. */
const VERIFIED_TARGET = 184;
const DAY = 24 * 3_600_000;

const co = (key: string) => `${PREFIX}co-${key}`;
const vid = (key: string) => `${PREFIX}v-${key}`;
const up = (file: string) => `/uploads/${PREFIX}${file}`;

type Level = 'VERIFIED' | 'CERTIFIED' | 'PREFERRED' | 'ELITE';

interface CardSpec {
  key: string;
  name: string;
  logo: 'bluedot' | 'innowork' | 'innowork_dark' | 'securetech';
  headline: string;
  description: string;
  rating: number;
  ratingCount: number;
  categories: string[];
  city: string;
  state: string;
  yearsExperience: number;
  projects: number;
}

const BIOMETRIC = 'Biometric systems, CCTV & Manpower';

/** The design's cards, in the order of their ratings (the API sorts "Top rated" by rating). The
 *  decimals past the first are what keep the order stable: the design prints one. */
const CARDS: CardSpec[] = [
  { key: 'bluedot', name: 'BlueDot', logo: 'bluedot', headline: 'Corporate Security', description: BIOMETRIC, rating: 4.84, ratingCount: 124, categories: ['PHYSICAL_SECURITY', 'ELECTRONIC_SECURITY'], city: 'Bengaluru', state: 'Karnataka', yearsExperience: 12, projects: 210 },
  { key: 'innowork-1', name: 'InnoWork', logo: 'innowork', headline: 'Corporate Security', description: BIOMETRIC, rating: 4.83, ratingCount: 124, categories: ['PHYSICAL_SECURITY'], city: 'Mumbai', state: 'Maharashtra', yearsExperience: 9, projects: 150 },
  { key: 'innowork-2', name: 'InnoWork', logo: 'innowork', headline: 'Corporate Security', description: BIOMETRIC, rating: 4.82, ratingCount: 124, categories: ['PHYSICAL_SECURITY'], city: 'Pune', state: 'Maharashtra', yearsExperience: 8, projects: 120 },
  { key: 'innowork-dark', name: 'InnoWork', logo: 'innowork_dark', headline: 'Corporate Security', description: BIOMETRIC, rating: 4.81, ratingCount: 124, categories: ['PHYSICAL_SECURITY'], city: 'Hyderabad', state: 'Telangana', yearsExperience: 10, projects: 175 },
  { key: 'innowork-3', name: 'InnoWork', logo: 'innowork', headline: 'Corporate Security', description: BIOMETRIC, rating: 4.8, ratingCount: 124, categories: ['PHYSICAL_SECURITY'], city: 'Chennai', state: 'Tamil Nadu', yearsExperience: 7, projects: 96 },
  { key: 'innowork-4', name: 'InnoWork', logo: 'innowork', headline: 'Corporate Security', description: BIOMETRIC, rating: 4.79, ratingCount: 124, categories: ['PHYSICAL_SECURITY'], city: 'Delhi', state: 'Delhi', yearsExperience: 11, projects: 188 },
  { key: 'innowork-5', name: 'InnoWork', logo: 'innowork', headline: 'Corporate Security', description: BIOMETRIC, rating: 4.78, ratingCount: 124, categories: ['PHYSICAL_SECURITY'], city: 'Bengaluru', state: 'Karnataka', yearsExperience: 6, projects: 84 },
  { key: 'securetech', name: 'SecureTech', logo: 'securetech', headline: 'Network Security', description: 'Firewalls, VPNs & Threat Detection', rating: 4.7, ratingCount: 150, categories: ['ELECTRONIC_SECURITY'], city: 'Hyderabad', state: 'Telangana', yearsExperience: 14, projects: 260 },
  { key: 'safehome', name: 'SafeHome', logo: 'bluedot', headline: 'Residential Security', description: 'Smart locks, Home automation & Motion', rating: 4.6, ratingCount: 85, categories: ['ELECTRONIC_SECURITY'], city: 'Pune', state: 'Maharashtra', yearsExperience: 5, projects: 64 },
  { key: 'greenguard', name: 'GreenGuard', logo: 'bluedot', headline: 'Home Security', description: 'Alarm system, Surveillance cameras & Monitoring', rating: 4.5, ratingCount: 98, categories: ['ELECTRONIC_SECURITY'], city: 'Chennai', state: 'Tamil Nadu', yearsExperience: 8, projects: 110 },
];

/** Vikasha Aero Tech: the supplier on the profile designs. */
const VIKASHA = {
  key: 'vikasha',
  name: 'Vikasha Aero Tech',
  headline:
    'AI-Guided Robotic High-Rise Maintenance & Drone Facade Engineering Solutions for Tier-1 Commercial Campuses.',
  description:
    'Revolutionizing commercial facility maintenance through DGCA-licensed robotic and drone-based cleaning solutions, ' +
    'completely eliminating human rigging risk on high-rise glass facades. Our certified pilots and robotics engineers ' +
    'deliver audited, insured and fully documented service across four operational hubs.\n\n' +
    'Since 2019 we have maintained more than 150 commercial towers across the technology parks of Bengaluru, Hyderabad, ' +
    'Pune and Chennai, with a two-hour dispatch commitment from each hub.',
  website: 'https://vikasha.example.in',
  /** The design's CIN, in the one column a listing publishes (see the header). */
  registration: 'CIN-U74999KA2019PTC1',
  rating: 4.9,
  ratingCount: 84,
  projects: 150,
  clients: 42,
  years: 7,
};

/**
 * The supplier the app's live tests act on (`test/live/marketplace_live_test.dart`): they save it, rate it and
 * send it quote requests. Every run of the seed puts it back as it was (no ratings, the same numbers), so a
 * test's rating cannot change what the designed suppliers show.
 */
const SANDBOX = {
  key: 'sandbox',
  name: 'Sandbox Facility Services',
  headline: 'Test supplier for the mobile app',
  description: 'A supplier the mobile app tests save, rate and ask for quotes. It is reset whenever the seed runs.',
  rating: 3.9,
  ratingCount: 11,
};

/**
 * The two people the live tests ask for quotes as (`test/live/marketplace_live_test.dart`). The portal's own demo
 * buyer (Bharat) has no active company on this database any more, and a requirement is a company's, so the tests
 * bring their own: a company with an admin who has a mobile number on file and a buyer who has none (his number is
 * taken off again on every run, so the "a number is asked for" path can be proved again).
 */
const BUYER_PASSWORD = 'Market@12345';
const BUYER_COMPANY = { key: 'buyer', name: 'Meridian Corporate Estates' };
const BUYERS = [
  { key: 'buyer', email: 'marketplace.buyer@marketplace-design.icr.test', first: 'Maya', last: 'Mehta', role: 'COMPANY_ADMIN', phone: '+919800000011' as string | null },
  { key: 'nophone', email: 'marketplace.nophone@marketplace-design.icr.test', first: 'Nikhil', last: 'Nair', role: 'BUYER', phone: null as string | null },
];

const HUBS = [
  { key: 'blr', name: 'Bengaluru HQ', city: 'Bengaluru', state: 'Karnataka', phone: '+91 80 4000 1100', head: true, lat: 12.9716, lng: 77.5946 },
  { key: 'hyd', name: 'Hyderabad Hub', city: 'Hyderabad', state: 'Telangana', phone: '+91 40 4000 1200', head: false, lat: 17.385, lng: 78.4867 },
  { key: 'pnq', name: 'Pune Hub', city: 'Pune', state: 'Maharashtra', phone: '+91 20 4000 1300', head: false, lat: 18.5204, lng: 73.8567 },
  { key: 'maa', name: 'Chennai Hub', city: 'Chennai', state: 'Tamil Nadu', phone: '+91 44 4000 1400', head: false, lat: 13.0827, lng: 80.2707 },
];

/** The design's six services. A rate makes a service "bookable" in the app ("Book Service"). */
const SERVICES = [
  { key: '1', name: 'Drone Facade Cleaning', sub: 'HOUSEKEEPING', description: 'AI-guided dual-rotor precision wash for high-rise glass commercial towers up to 150m.', turnaround: 'SLA: 24h Setup • BLR / HYD', rate: null as number | null, unit: null as string | null },
  { key: '2', name: 'Robotic HVAC Inspection', sub: 'HVAC', description: 'Remote camera crawler with HEPA extraction, rotary brush modules, and sanitisation.', turnaround: 'Video Report Included', rate: 18000, unit: 'per inspection' },
  { key: '3', name: 'High-Rise Cobweb Vacuuming', sub: 'HOUSEKEEPING', description: 'Cleanrooms, industrial logistics parks & 20m atrium ceiling dust extraction systems.', turnaround: 'Night Shifts Available', rate: null, unit: null },
  { key: '4', name: 'Specialized Industrial Cleaning', sub: 'HOUSEKEEPING', description: 'Degreasing, epoxy floor treatment & mechanical plant room deep sanitation drives.', turnaround: 'Industrial Grade', rate: null, unit: null },
  { key: '5', name: 'Comprehensive HVAC Duct Care', sub: 'HVAC', description: 'Airflow volume balancing, motorized damper servicing, and IAQ particulate monitoring.', turnaround: 'IAQ Certified', rate: 45000, unit: 'per visit' },
  { key: '6', name: 'Commercial Pest Barrier', sub: 'PEST_CONTROL', description: 'Targeted gel baited and ultrasonic termite barriers for commercial food courts.', turnaround: 'Odorless Formula', rate: null, unit: null },
];

/** The design's four compliances: a type each (the type's name is the row's title). */
const CERT_TYPES = [
  { key: 'dgca', name: 'DGCA Commercial Drone License', category: 'GOVERNMENT', issuer: 'Directorate General of Civil Aviation', number: 'DGCA-KA-2024-UAV-781', note: null as string | null },
  { key: 'iso9001', name: 'ISO 9001:2015 Quality Management', category: 'ISO', issuer: 'TUV Rheinland', number: null, note: null },
  { key: 'iso45001', name: 'ISO 45001 Occupational Safety', category: 'ISO', issuer: 'TUV Rheinland', number: null, note: 'Zero-Elevation Worker Hazard Compliant' },
  { key: 'escrow', name: 'Escrow & Trade Assurance Policy', category: 'OTHER', issuer: 'ICR Trade Assurance', number: null, note: '₹10 Crore Comprehensive Aviation Risk Coverage' },
];

/** The design's two audited proofs. The API publishes ratings with no name, so the app shows the score and the
 *  comment; the design's reviewer lines live only in the app's demo content. */
const REVIEWS = [
  { score: 5, comment: 'Transitioned our 14-tower glass facade cleaning to Vikasha Aero Tech drones..', ageDays: 21 },
  {
    score: 5,
    comment:
      'Their robotic duct inspection system uncovered and resolved microbial build-ups that manual inspection teams missed completely..',
    ageDays: 40,
  },
];

const PRODUCTS = [
  { key: '1', name: 'Biometric Access Terminal', description: 'Fingerprint and card access terminal with a 7-inch display, door relay and an audit log of every entry.', price: 18500, unit: 'piece', availability: 'IN_STOCK', warranty: 24, returns: 7, freeOver: 25000, bulk: 10, category: 'ELECTRONIC_SECURITY_ACCESS_CONTROL' },
  { key: '2', name: 'IP CCTV Dome Camera, 4 MP', description: 'Day and night dome camera with 30 m infrared range, PoE power and onboard motion detection.', price: 4200, unit: 'piece', availability: 'IN_STOCK', warranty: 36, returns: 7, freeOver: 0, bulk: 20, category: 'ELECTRONIC_SECURITY_CCTV' },
  { key: '3', name: 'Command Centre Video Wall Controller', description: 'Eight-input controller for a campus control room, with layouts saved per shift.', price: 285000, unit: 'set', availability: 'MADE_TO_ORDER', warranty: 12, returns: null, freeOver: null, bulk: null, category: 'ELECTRONIC_SECURITY_COMMAND_CENTERS' },
];

// ---------------------------------------------------------------------------
// Filler suppliers, so the directory is as long as the design's "180+"
// ---------------------------------------------------------------------------

const FILL_PREFIXES = ['Apex', 'Meridian', 'Zenith', 'Orion', 'Vertex', 'Nimbus', 'Solace', 'Pinnacle', 'Cardinal', 'Atlas', 'Crestline', 'Helix', 'Ironwood', 'Lumen', 'Northwind', 'Quorum', 'Redwood', 'Summit'];
const FILL_SUFFIXES = ['Facility Services', 'Integrated Services', 'Security Solutions', 'Engineering', 'Housekeeping Co', 'MEP Works', 'Clean Tech', 'Guarding Services', 'Technical Services', 'Workplace Partners'];
const FILL_CATEGORIES = ['HOUSEKEEPING', 'PEST_CONTROL', 'PHYSICAL_SECURITY', 'ELECTRONIC_SECURITY', 'HVAC', 'ELECTRICAL', 'PLUMBING', 'AMC', 'COMMISSIONING', 'WASTE_MANAGEMENT', 'HORTICULTURE', 'CIVIL'];
const FILL_CITIES: [string, string][] = [['Bengaluru', 'Karnataka'], ['Mumbai', 'Maharashtra'], ['Pune', 'Maharashtra'], ['Hyderabad', 'Telangana'], ['Chennai', 'Tamil Nadu'], ['Delhi', 'Delhi']];
const FILL_SIZES = ['11-50', '51-200', '201-500', '500+'];
const FILL_LEVELS: Level[] = ['VERIFIED', 'CERTIFIED', 'PREFERRED', 'ELITE'];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** DATABASE_URL from the environment, else from `.env` in the cwd. Never logged: it holds the password. */
function databaseUrl(): string | undefined {
  if (process.env.DATABASE_URL) return process.env.DATABASE_URL;
  const envFile = join(process.cwd(), '.env');
  if (!existsSync(envFile)) return undefined;
  return readFileSync(envFile, 'utf8').match(/^\s*DATABASE_URL\s*=\s*"?([^"\r\n]+)"?/m)?.[1];
}

async function assertLocalDatabase(prisma: PrismaClient, log: (m: string) => void): Promise<void> {
  if (process.env.NODE_ENV === 'production') throw new Error('Refusing to seed design content with NODE_ENV=production.');
  let hostOk = true;
  const url = databaseUrl();
  if (url) {
    try {
      hostOk = ['localhost', '127.0.0.1', '::1'].includes(new URL(url).hostname.replace(/^\[|\]$/g, ''));
    } catch {
      hostOk = false;
    }
  }
  const rows = (await prisma.$queryRawUnsafe(`select current_database() as db, inet_server_addr()::text as addr`)) as {
    db: string;
    addr: string | null;
  }[];
  const addr = String(rows[0]?.addr ?? '').split('/')[0];
  const loopback = addr === '' || addr === '127.0.0.1' || addr === '::1';
  if (!loopback || !hostOk) throw new Error('Refusing to run: the database is not on localhost.');
  log(`database "${rows[0]?.db}" on ${addr || 'a local socket'}: local`);
  if (!existsSync(join(process.cwd(), 'prisma', 'schema.prisma'))) {
    throw new Error(`Run this from E:\\ICR\\irc-portal\\backend (cwd is ${process.cwd()}): uploads resolve from it.`);
  }
}

const LOGO_FILES = ['bluedot', 'innowork', 'innowork_dark', 'securetech'].map((n) => ({
  from: `marketplace_logo_${n}.png`,
  to: `${PREFIX}logo_${n}.png`,
}));

function copyAssets(log: (m: string) => void): void {
  const uploads = join(process.cwd(), 'uploads');
  if (!existsSync(uploads)) mkdirSync(uploads, { recursive: true });
  for (const a of LOGO_FILES) copyFileSync(join(SEED_ASSETS, a.from), join(uploads, a.to));
  log(`  files: ${LOGO_FILES.length} copied to uploads/`);
}

function removeAssets(): void {
  const uploads = join(process.cwd(), 'uploads');
  for (const a of LOGO_FILES) {
    const path = join(uploads, a.to);
    if (existsSync(path)) unlinkSync(path);
  }
}

const VERIFIED_LEVELS: Level[] = ['VERIFIED', 'CERTIFIED', 'PREFERRED', 'ELITE'];

// ---------------------------------------------------------------------------
// Seed
// ---------------------------------------------------------------------------

export interface SeedOptions {
  /** Delete what the seed created. */
  remove?: boolean;
  /** Leave out the filler suppliers. */
  noFill?: boolean;
  dryRun?: boolean;
}

export async function seedMarketplace(
  prisma: PrismaClient,
  log: (m: string) => void = console.log,
  options: SeedOptions = {},
): Promise<void> {
  await assertLocalDatabase(prisma, log);
  if (options.dryRun) {
    log('dry run: nothing written');
    return;
  }
  if (options.remove) {
    await remove(prisma, log);
    return;
  }

  copyAssets(log);
  const now = new Date();

  // ---- The ten cards -----------------------------------------------------------------------
  for (const c of CARDS) {
    const company: Prisma.CompanyUncheckedCreateInput = {
      id: co(c.key),
      name: c.name,
      type: 'SUPPLIER',
      legalStructure: 'PRIVATE_LIMITED',
      description: c.description,
      logoUrl: up(`logo_${c.logo}.png`),
      website: `https://${c.name.toLowerCase()}.example.in`,
      city: c.city,
      state: c.state,
      country: 'India',
      size: '201-500',
      gstNumber: `DESIGN-GST-${c.key.toUpperCase()}`,
      verificationStatus: 'VERIFIED',
      verificationLevel: 'ELITE',
      verifiedAt: now,
      foundedYear: 2026 - c.yearsExperience,
    };
    await prisma.company.upsert({ where: { id: company.id! }, update: company, create: company });
    const vendor: Prisma.VendorUncheckedCreateInput = {
      id: vid(c.key),
      companyId: co(c.key),
      headline: c.headline,
      categories: c.categories,
      serviceAreas: [c.city],
      yearsExperience: c.yearsExperience,
      projectsCompleted: c.projects,
      rating: c.rating,
      ratingCount: c.ratingCount,
      isPremium: true,
      planPriority: true,
      verificationStatus: 'VERIFIED',
      verificationLevel: 'ELITE',
      verifiedAt: now,
      responseTime: 'WITHIN_24H',
      acceptingWork: true,
    };
    await prisma.vendor.upsert({ where: { id: vendor.id! }, update: vendor, create: vendor });
    await prisma.branch.upsert({
      where: { id: `${PREFIX}br-${c.key}` },
      update: {},
      create: {
        id: `${PREFIX}br-${c.key}`,
        companyId: co(c.key),
        name: `${c.city} Head Office`,
        type: 'CITY',
        city: c.city,
        state: c.state,
        isHeadOffice: true,
      },
    });
  }
  log(`  cards: ${CARDS.length} suppliers`);

  // ---- Vikasha Aero Tech -------------------------------------------------------------------
  const v = VIKASHA;
  const vikashaCompany: Prisma.CompanyUncheckedCreateInput = {
    id: co(v.key),
    name: v.name,
    type: 'SUPPLIER',
    legalStructure: 'PRIVATE_LIMITED',
    description: v.description,
    website: v.website,
    city: 'Bengaluru',
    state: 'Karnataka',
    country: 'India',
    size: '51-200',
    gstNumber: 'DESIGN-GST-VIKASHA',
    verificationStatus: 'VERIFIED',
    verificationLevel: 'ELITE',
    verifiedAt: now,
    foundedYear: 2019,
  };
  await prisma.company.upsert({ where: { id: vikashaCompany.id! }, update: vikashaCompany, create: vikashaCompany });
  const vikashaVendor: Prisma.VendorUncheckedCreateInput = {
    id: vid(v.key),
    companyId: co(v.key),
    headline: v.headline,
    categories: ['HOUSEKEEPING', 'HVAC'],
    serviceAreas: HUBS.map((h) => h.city),
    yearsExperience: v.years,
    projectsCompleted: v.projects,
    rating: v.rating,
    ratingCount: v.ratingCount,
    isPremium: false,
    planPriority: true,
    verificationStatus: 'VERIFIED',
    verificationLevel: 'ELITE',
    verifiedAt: now,
    responseTime: 'WITHIN_4H',
    acceptingWork: true,
    msmeNumber: v.registration,
    priceRange: 'PREMIUM',
    latitude: 12.9716,
    longitude: 77.5946,
  };
  await prisma.vendor.upsert({ where: { id: vikashaVendor.id! }, update: vikashaVendor, create: vikashaVendor });
  for (const h of HUBS) {
    const branch: Prisma.BranchUncheckedCreateInput = {
      id: `${PREFIX}br-${v.key}-${h.key}`,
      companyId: co(v.key),
      name: h.name,
      type: 'CITY',
      city: h.city,
      state: h.state,
      phone: h.phone,
      latitude: h.lat,
      longitude: h.lng,
      isHeadOffice: h.head,
    };
    await prisma.branch.upsert({ where: { id: branch.id! }, update: branch, create: branch });
  }
  // The API lists a company's services newest first, so the design's first service is the newest.
  for (const [i, s] of SERVICES.entries()) {
    const service: Prisma.ServiceUncheckedCreateInput = {
      id: `${PREFIX}sv-${s.key}`,
      companyId: co(v.key),
      name: s.name,
      category: 'FACILITY_MANAGEMENT',
      subcategory: s.sub,
      description: s.description,
      turnaroundTime: s.turnaround,
      rate: s.rate,
      rateUnit: s.unit,
      createdAt: new Date(now.getTime() - i * 60_000),
    };
    await prisma.service.upsert({ where: { id: service.id! }, update: service, create: service });
  }
  // Certification types of the design's own wording, then the company's records of them.
  for (const [i, t] of CERT_TYPES.entries()) {
    const type = await prisma.certificationType.upsert({
      where: { slug: `${PREFIX}${t.key}` },
      update: { name: t.name, category: t.category, issuers: [t.issuer] },
      create: {
        slug: `${PREFIX}${t.key}`,
        code: `DESIGN-MKT-${t.key.toUpperCase()}`,
        name: t.name,
        category: t.category,
        issuers: [t.issuer],
        sortOrder: 900 + i,
      },
    });
    const id = `${PREFIX}cert-${t.key}`;
    const record: Prisma.CompanyCertificationUncheckedCreateInput = {
      id,
      companyId: co(v.key),
      certificationTypeId: type.id,
      status: 'VERIFIED',
      issuer: t.issuer,
      certificateNumber: t.number,
      note: t.note,
      issuedOn: new Date(now.getTime() - 400 * DAY),
      validFrom: new Date(now.getTime() - 400 * DAY),
      expiresAt: new Date(now.getTime() + 700 * DAY),
    };
    await prisma.companyCertification.upsert({ where: { id }, update: record, create: record });
  }
  // The audited proofs: two of the portal's own test accounts rated it.
  const authors = await prisma.user.findMany({
    where: { email: { endsWith: '@icr.test' }, NOT: { email: 'professional@icr.test' } },
    select: { id: true },
    orderBy: { email: 'asc' },
    take: REVIEWS.length,
  });
  for (const [i, author] of authors.entries()) {
    const r = REVIEWS[i];
    await prisma.vendorRating.upsert({
      where: { vendorId_authorId: { vendorId: vid(v.key), authorId: author.id } },
      update: { score: r.score, comment: r.comment },
      create: {
        vendorId: vid(v.key),
        authorId: author.id,
        score: r.score,
        comment: r.comment,
        createdAt: new Date(now.getTime() - r.ageDays * DAY),
      },
    });
  }
  log(`  vikasha: ${HUBS.length} offices, ${SERVICES.length} services, ${CERT_TYPES.length} certifications, ${authors.length} ratings`);

  // ---- The sandbox ----------------------------------------------------------------------------
  const sandboxCompany: Prisma.CompanyUncheckedCreateInput = {
    id: co(SANDBOX.key),
    name: SANDBOX.name,
    type: 'SUPPLIER',
    legalStructure: 'PRIVATE_LIMITED',
    description: SANDBOX.description,
    city: 'Pune',
    state: 'Maharashtra',
    country: 'India',
    size: '11-50',
    verificationStatus: 'VERIFIED',
    verificationLevel: 'VERIFIED',
    verifiedAt: now,
  };
  await prisma.company.upsert({ where: { id: sandboxCompany.id! }, update: sandboxCompany, create: sandboxCompany });
  const sandboxVendor: Prisma.VendorUncheckedCreateInput = {
    id: vid(SANDBOX.key),
    companyId: co(SANDBOX.key),
    headline: SANDBOX.headline,
    categories: ['HOUSEKEEPING'],
    serviceAreas: ['Pune'],
    rating: SANDBOX.rating,
    ratingCount: SANDBOX.ratingCount,
    isPremium: false,
    planPriority: true,
    verificationStatus: 'VERIFIED',
    verificationLevel: 'VERIFIED',
    verifiedAt: now,
  };
  await prisma.vendor.upsert({ where: { id: sandboxVendor.id! }, update: sandboxVendor, create: sandboxVendor });
  await prisma.vendorRating.deleteMany({ where: { vendorId: vid(SANDBOX.key) } });
  await prisma.vendorSave.deleteMany({ where: { vendorId: vid(SANDBOX.key) } });
  await prisma.service.upsert({
    where: { id: `${PREFIX}sv-sandbox` },
    update: {},
    create: {
      id: `${PREFIX}sv-sandbox`,
      companyId: co(SANDBOX.key),
      name: 'Housekeeping contract',
      category: 'FACILITY_MANAGEMENT',
      subcategory: 'HOUSEKEEPING',
      description: 'Daily housekeeping for offices.',
      rate: 12000,
      rateUnit: 'per month',
    },
  });
  log('  sandbox: reset');

  // ---- The people who ask for quotes ---------------------------------------------------------------
  const buyerCompany: Prisma.CompanyUncheckedCreateInput = {
    id: co(BUYER_COMPANY.key),
    name: BUYER_COMPANY.name,
    type: 'CORPORATE',
    legalStructure: 'PRIVATE_LIMITED',
    city: 'Mumbai',
    state: 'Maharashtra',
    country: 'India',
    size: '201-500',
    verificationStatus: 'VERIFIED',
    verificationLevel: 'VERIFIED',
    verifiedAt: now,
  };
  await prisma.company.upsert({ where: { id: buyerCompany.id! }, update: buyerCompany, create: buyerCompany });
  const hash = bcrypt.hashSync(BUYER_PASSWORD, 10);
  for (const b of BUYERS) {
    const user = await prisma.user.upsert({
      where: { email: b.email },
      update: { passwordHash: hash, isActive: true, phone: b.phone, role: b.role as never, companyId: co(BUYER_COMPANY.key) },
      create: {
        id: `${PREFIX}u-${b.key}`,
        email: b.email,
        passwordHash: hash,
        firstName: b.first,
        lastName: b.last,
        role: b.role as never,
        companyId: co(BUYER_COMPANY.key),
        phone: b.phone,
        emailVerifiedAt: new Date(),
        designation: 'Facilities buyer (mobile marketplace seed)',
      },
    });
    const place = await prisma.companyMembership.findFirst({
      where: { userId: user.id, companyId: co(BUYER_COMPANY.key) },
      select: { id: true },
    });
    if (place) {
      await prisma.companyMembership.update({ where: { id: place.id }, data: { role: b.role as never, status: 'ACTIVE' as never } });
    } else {
      await prisma.companyMembership.create({
        data: {
          id: `${PREFIX}m-${b.key}`,
          userId: user.id,
          companyId: co(BUYER_COMPANY.key),
          role: b.role as never,
          status: 'ACTIVE' as never,
          source: 'ADDED' as never,
        },
      });
    }
  }
  // What the tests asked for last time is gone: their requirements are deleted (an enquiry sent as a test has no other life).
  const stale = await prisma.rfq.deleteMany({ where: { buyerId: { in: BUYERS.map((b) => `${PREFIX}u-${b.key}`) } } });
  log(`  buyers: ${BUYERS.length} people at ${BUYER_COMPANY.name} (${BUYER_PASSWORD}), ${stale.count} earlier requirement(s) cleared`);

  // ---- SecureTech's products ----------------------------------------------------------------------
  for (const [i, p] of PRODUCTS.entries()) {
    const category = await prisma.category.findFirst({ where: { key: p.category }, select: { id: true } });
    const product: Prisma.ProductUncheckedCreateInput = {
      id: `${PREFIX}pr-${p.key}`,
      companyId: co('securetech'),
      name: p.name,
      description: p.description,
      price: p.price,
      unit: p.unit,
      availability: p.availability as 'IN_STOCK' | 'MADE_TO_ORDER',
      warrantyMonths: p.warranty,
      returnDays: p.returns,
      freeDeliveryOver: p.freeOver,
      bulkPricingMinQty: p.bulk,
      categoryId: category?.id ?? null,
      createdAt: new Date(now.getTime() - i * 60_000),
    };
    await prisma.product.upsert({ where: { id: product.id! }, update: product, create: product });
  }
  log(`  products: ${PRODUCTS.length}`);

  // ---- Filler -------------------------------------------------------------------------------------
  if (!options.noFill) {
    const others = await prisma.vendor.count({
      where: {
        deletedAt: null,
        id: { not: { startsWith: PREFIX } },
        verificationLevel: { in: VERIFIED_LEVELS },
        company: { deletedAt: null, suspendedAt: null },
      },
    });
    const designed = CARDS.length + 2; // the ten cards, Vikasha and the sandbox (the buyers' company is no supplier)
    const need = Math.max(0, VERIFIED_TARGET - others - designed);
    const companies: Prisma.CompanyCreateManyInput[] = [];
    const vendors: Prisma.VendorCreateManyInput[] = [];
    for (let i = 0; i < need; i++) {
      const prefix = FILL_PREFIXES[i % FILL_PREFIXES.length];
      const suffix = FILL_SUFFIXES[Math.floor(i / FILL_PREFIXES.length) % FILL_SUFFIXES.length];
      const [city, state] = FILL_CITIES[(i * 5) % FILL_CITIES.length];
      const level = FILL_LEVELS[i % FILL_LEVELS.length];
      const a = FILL_CATEGORIES[i % FILL_CATEGORIES.length];
      const b = FILL_CATEGORIES[(i * 7 + 3) % FILL_CATEGORIES.length];
      const key = `fill-${String(i + 1).padStart(3, '0')}`;
      companies.push({
        id: co(key),
        name: `${prefix} ${suffix}`,
        type: 'SUPPLIER',
        legalStructure: i % 3 === 0 ? 'LLP' : 'PRIVATE_LIMITED',
        description: `${suffix} for corporate campuses in ${city} and the cities around it.`,
        city,
        state,
        country: 'India',
        size: FILL_SIZES[i % FILL_SIZES.length],
        gstNumber: i % 4 === 0 ? null : `DESIGN-GST-${key.toUpperCase()}`,
        verificationStatus: 'VERIFIED',
        verificationLevel: level,
      });
      vendors.push({
        id: vid(key),
        companyId: co(key),
        headline: `${suffix} for corporate campuses`,
        categories: a === b ? [a] : [a, b],
        serviceAreas: [city],
        yearsExperience: 2 + ((i * 3) % 18),
        projectsCompleted: 8 + ((i * 11) % 240),
        rating: Math.round((3.2 + ((i * 37) % 15) / 10 + (i % 7) / 100) * 100) / 100,
        ratingCount: 6 + ((i * 13) % 140),
        isPremium: false,
        planPriority: true,
        verificationStatus: 'VERIFIED',
        verificationLevel: level,
        responseTime: ['WITHIN_1H', 'WITHIN_4H', 'WITHIN_24H', 'WITHIN_48H'][i % 4],
        acceptingWork: true,
        msmeNumber: i % 3 === 0 ? `UDYAM-XX-00-${String(1000000 + i * 7)}` : null,
      });
    }
    await prisma.company.createMany({ data: companies, skipDuplicates: true });
    await prisma.vendor.createMany({ data: vendors, skipDuplicates: true });
    log(`  filler: ${need} plain suppliers (${others} verified ones of the portal's own, ${designed} designed)`);
  }
  log('done');
}

async function remove(prisma: PrismaClient, log: (m: string) => void): Promise<void> {
  const people = await prisma.user.findMany({ where: { id: { startsWith: `${PREFIX}u-` } }, select: { id: true } });
  const ids = people.map((p) => p.id);
  await prisma.rfq.deleteMany({ where: { buyerId: { in: ids } } });
  await prisma.companyMembership.deleteMany({ where: { userId: { in: ids } } });
  await prisma.user.deleteMany({ where: { id: { in: ids } } });
  // A company's delete takes its listing, offices, services, products, certifications and ratings with it.
  const gone = await prisma.company.deleteMany({ where: { id: { startsWith: `${PREFIX}co-` } } });
  const types = await prisma.certificationType.deleteMany({ where: { slug: { startsWith: PREFIX } } });
  removeAssets();
  log(`removed ${gone.count} companies, ${types.count} certification types, the logos`);
}

// ---------------------------------------------------------------------------
// Run alone
// ---------------------------------------------------------------------------

if (require.main === module) {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { PrismaClient: Client } = require('@prisma/client') as typeof import('@prisma/client');
  const prisma = new Client();
  const has = (f: string) => process.argv.includes(f);
  seedMarketplace(prisma, (m) => console.log(m), {
    remove: has('--remove'),
    noFill: has('--no-fill'),
    dryRun: has('--dry-run'),
  })
    .catch((e) => {
      console.error(e);
      process.exitCode = 1;
    })
    .finally(() => prisma.$disconnect());
}
