/**
 * Seeds the Events and Councils content of the mobile app's designs into the
 * LOCAL portal database, so the app reads it through the portal's real API.
 *
 *   cd E:\ICR\irc-portal\backend          (cwd must be the backend folder: `uploads` resolves from it)
 *   NODE_PATH=E:/ICR/irc-portal/node_modules npx ts-node --transpile-only E:/ICR/icr-mobile/tool/seed/events-councils.ts
 *   ... same command with --remove        (deletes what this script created, restores what it changed)
 *   ... same command with --isolate       (also hides the association seed's 9 generic events; see below)
 *   ... also: --dry-run
 *
 * Idempotent: every row has a stable id and slug and is upserted, and the
 * attendee and member lists are brought to exactly the designed set, so a
 * re-run restores the designed state (an RSVP or a join made by hand in the app
 * on a design event or council is undone). Re-running on a later day also
 * re-bases the design dates (see `shiftDays`).
 *
 * Markers (all removable): ids `design-ev-*`, `design-council-*`, `design-chapter-*`,
 * `design-user-*`; slugs ending `-design`; people with emails ending
 * @events-design.icr.test (the Mentorship seed uses @design.icr.test and the Learning/Jobs
 * seed @learning-jobs.icr.test: a domain of its own keeps the `--remove`s from deleting each
 * other's people); files /uploads/design-events-* and /uploads/design-councils-*.
 * The people the counts scale to are the portal's own accounts (@icr.dev, @icr.test only).
 *
 * What is seeded
 *   Events    16 design events: the spotlight summit (Oct 24), the AI webinar,
 *             the Future of Business & Innovation Summit (the Event Sheet design),
 *             the priced PropTech Summit (Nov 12-14), the invite-only GCC
 *             roundtable, the BMS workshop, 3 council roundtables, 3 council
 *             "next" dates (one a masterclass, the sixth event kind) and 4
 *             chapter dates (2027), with covers, attendees, invitations and
 *             accepted talks (the programme the sheet draws).
 *   Councils  the design's 6 councils (5 new; "Corporate & Commercial Real
 *             Estate Council" already exists, so that row is adopted in place),
 *             with chairs, covers, scaled member lists and one upcoming event each.
 *             A council's FIRST segment is its category (the chip the app files it
 *             under); the rest are its hashtag pills. Three of the six (CXO, Legal,
 *             Real Estate) are created in the running quarter, so the stat tile's
 *             "+N Qn" reads "+3 Q4"; the CXO council carries three announcements
 *             from the last month, which the app counts as its "3 unread".
 *   People    8 inactive, non-public people (the chairs and speakers) so the API
 *             can name them; no password, cannot sign in.
 *   Also      one unpublished chapter ("ICR Vinfraa & PropTech India Chapter",
 *             invisible in chapter lists) as the host the sheet names.
 *
 * What it changes in existing rows (all recorded in Setting `design-seed:events-councils`
 * and undone by --remove)
 *   - Bharat Buyer (buyer@icr.dev) and Pooja Professional (professional@icr.test):
 *     their existing council seats are removed and replaced by the design's three
 *     (CXO Executive Seat, Sustainability Member, Workplace & Employee Experience Member),
 *     so "Your Joined Councils" reads as the design; they hold two upcoming places.
 *   - the adopted Corporate & Commercial Real Estate Council row: copy, segments,
 *     cover, creation date and member list.
 *   - with --isolate: the 9 generic events are unpublished.
 *   - Bharat Buyer's CPD: three ledger entries (ids `design-cpd-*`, 8.5 hours) and his target for the
 *     year set to 15 hours (the board's "CPD Earned 8.5 / 15" tile); the target he had is put back.
 *   - Dates: the design's four board events and the sheet's event take `board` dates (Oct 24 to 27)
 *     while the generic events stay published, so they are the first cards by date; `--isolate` uses
 *     the design's own dates.
 *
 * Everything else existing is left alone. It refuses to run unless the database is on localhost.
 */
import type { Prisma, PrismaClient } from '@prisma/client';
import { copyFileSync, existsSync, mkdirSync, readFileSync, unlinkSync } from 'fs';
import { join, resolve } from 'path';

// ---------------------------------------------------------------------------
// Markers and constants
// ---------------------------------------------------------------------------

const SUFFIX = '-design';
const PERSON_DOMAIN = '@events-design.icr.test';
const MANIFEST_KEY = 'design-seed:events-councils';
const BHARAT_EMAIL = 'buyer@icr.dev';
const POOJA_EMAIL = 'professional@icr.test';
const HOUR = 3_600_000;
const DAY = 24 * HOUR;
const DEMO_ASSETS = resolve(__dirname, '..', '..', 'assets', 'images', 'demo');
const SEED_ASSETS = resolve(__dirname, 'assets');

/** The association seed's events (`prisma/seed-association.ts`); --isolate hides exactly these. */
const GENERIC_EVENT_SLUGS = [
  'bengaluru-monthly-meetup-aug',
  'procurement-rfq-masterclass',
  'esg-reporting-webinar',
  'mumbai-high-rise-roundtable',
  'delhi-ncr-summer-mixer',
  'workplace-experience-conclave',
  'data-centre-uptime-clinic',
  'bfsi-facilities-forum',
  'fm-leadership-benchmark-webinar',
];

/** The design's membership count for the biggest council: all member counts scale to it. */
const BIGGEST_COUNCIL = 642;

type Ymdhm = [number, number, number, number, number];
type EventKind = 'CHAPTER_MEET' | 'WEBINAR' | 'CONFERENCE' | 'WORKSHOP' | 'MASTERCLASS' | 'ROUNDTABLE';

/** Indian clock to a UTC moment. */
const ist = (t: Ymdhm): Date => new Date(Date.UTC(t[0], t[1] - 1, t[2], t[3], t[4]) - 5.5 * HOUR);

const up = (file: string) => `/uploads/${file}`;

// ---------------------------------------------------------------------------
// Files: assets/images/demo/<feature>/<file> -> uploads/design-<feature>-<file>
// ---------------------------------------------------------------------------

/** `base: 'seed'` files sit beside this script (`tool/seed/assets`), the rest in the app's demo images. */
const ASSETS: { from: string; to: string; base?: 'seed' }[] = [
  ...['card_ai.jpg', 'card_bms.jpg', 'card_gcc.jpg', 'card_summit.jpg', 'sheet_hero.jpg', 'spotlight.jpg'].map((f) => ({
    from: `events/${f}`,
    to: `design-events-${f}`,
  })),
  // The council covers are the design's photos with the app's own cover darkening taken back out
  // (`tool/design/cut_council_covers.py`): the app darkens the photo it is given, and the design's
  // covers are already dark, so the bundled `cover_*.png` would be darkened twice.
  ...['construction', 'cxo', 'legal', 'real_estate', 'smart_buildings', 'sustainability'].map((n) => ({
    from: `council_photo_${n}.png`,
    to: `design-councils-photo_${n}.png`,
    base: 'seed' as const,
  })),
];
/** Earlier names of the council covers: cleared from uploads (a new name also busts the app's image cache). */
const LEGACY_FILES = [
  'cover_construction.png',
  'cover_cxo.png',
  'cover_legal.png',
  'cover_real_estate.png',
  'cover_smart_buildings.png',
  'cover_sustainability.png',
].map((f) => `design-councils-${f}`);
const file = (feature: 'events' | 'councils', name: string) => `design-${feature}-${name}`;

// ---------------------------------------------------------------------------
// The people the API has to name: council chairs and event speakers
// ---------------------------------------------------------------------------

type PersonKey = 'vikram' | 'rajesh' | 'ananya' | 'arvind' | 'meenakshi' | 'pooja' | 'radhika' | 'priya';

const PEOPLE: Record<PersonKey, { first: string; last: string; designation: string }> = {
  vikram: { first: 'Vikram', last: 'Malhotra', designation: 'Director ESG' },
  rajesh: { first: 'Rajesh', last: 'Sharma', designation: 'VP Facilities' },
  ananya: { first: 'Ananya', last: 'Rao', designation: 'Workplace Head' },
  arvind: { first: 'Arvind', last: 'Swamy', designation: 'General Counsel' },
  meenakshi: { first: 'Meenakshi', last: 'Sundaram', designation: 'Head PMO' },
  pooja: { first: 'Pooja', last: 'Chhabra', designation: 'Global Portfolio Head' },
  // The design writes the title into the name ("Dr. Radhika Iyer").
  radhika: { first: 'Dr. Radhika', last: 'Iyer', designation: 'VP Sustainable PropTech' },
  priya: { first: 'Priya', last: 'Nambiar', designation: 'IGBC AP' },
};
const personId = (k: PersonKey) => `design-user-${k}`;
const personEmail = (k: PersonKey) =>
  `${PEOPLE[k].first.toLowerCase().replace(/[^a-z]/g, '')}.${PEOPLE[k].last.toLowerCase().replace(/[^a-z]/g, '')}${PERSON_DOMAIN}`;

// ---------------------------------------------------------------------------
// Chapters. The sheet's "Organised by ICR Vinfraa & PropTech India Chapter" is the
// host's name, and the API only knows a chapter or a council as a host.
// ---------------------------------------------------------------------------

const HOST_CHAPTER = {
  id: 'design-chapter-vinfraa',
  slug: `icr-vinfraa-proptech-india${SUFFIX}`,
  name: 'ICR Vinfraa & PropTech India Chapter',
  city: 'Mumbai',
};

// ---------------------------------------------------------------------------
// Councils: lib/features/councils/demo_councils_repository.dart, word for word
// ---------------------------------------------------------------------------

interface CouncilSpec {
  key: string;
  /** An existing council row the design's council is, by slug: it is adopted, not duplicated. */
  adopt?: string;
  slug: string;
  name: string;
  focus: string;
  description: string;
  /**
   * The first is the council's category (the app's chip); each one after it is a hashtag pill
   * (`hashtag()` in the app turns "Scope 3" into #Scope3). The six councils share none, so the
   * "Recommended" order is not lifted by a tag the cards would then have to show.
   */
  segments: string[];
  cover: string;
  /** A date, or `quarterDay`: that many days into the running quarter (never in the future). */
  created: [number, number, number] | { quarterDay: number };
  /** The design's member count; the seeded list is scaled to the people there are. */
  members: number;
  chair: { person: PersonKey; title: string };
  /** The seat Bharat and Pooja hold. */
  seat?: 'LEAD' | 'MEMBER';
}

const COUNCILS: CouncilSpec[] = [
  {
    key: 'sust',
    slug: 'sustainability-esg-net-zero',
    // The rail card's spelling (the directory card's "Net- Zero" is a stray space in the export).
    name: 'Sustainability, ESG & Net-Zero Council',
    focus: 'Scope 1-3 auditing benchmarks, green lease clauses, and BRSR core frameworks.',
    description: 'Setting technical decarbonization benchmarks,\nScope 1-3 auditing frameworks, and green...',
    // "NetZero" unspaced on purpose: "Net Zero" is also a segment of a generic council, and a
    // segment shared with a joined council lifts that council in the Recommended order.
    segments: ['Net-Zero & ESG', 'NetZero', 'Decarbonization', 'Scope 3'],
    cover: 'photo_sustainability.png',
    created: [2023, 3, 1],
    members: 642,
    chair: { person: 'vikram', title: 'Director ESG @ DLF' },
    seat: 'MEMBER',
  },
  {
    key: 'cxo',
    slug: 'cxo-workplace-strategy',
    name: 'CXO Workplace Strategy & FM Leadership',
    focus: 'Campus consolidation, hybrid occupancy calibrations & CapEx lifecycles.',
    description: 'Executive strategy table for regional campus\nconsolidation, post-pandemic occupancy...',
    segments: ['CXO & Workplace', 'WorkplaceStrategy', 'Campus Ops', 'CapEx'],
    cover: 'photo_cxo.png',
    // New this quarter: the stat tile's "+3 Q4" counts CXO, Legal and Real Estate (the design's "+3 Q1").
    created: { quarterDay: 2 },
    members: 580,
    chair: { person: 'rajesh', title: 'VP Facilities @ Infosys' },
    seat: 'LEAD',
  },
  {
    key: 'smart',
    slug: 'smart-buildings-bms-proptech',
    name: 'Smart Buildings, BMS & PropTech Council',
    focus: 'BACnet interoperability, smart metering and HVAC optimisation.',
    description: 'Interoperability standards for BACnet, smart metering\nprotocols, HVAC optimization...',
    segments: ['Smart Buildings', 'BMS', 'Digital Twins', 'PropTech', 'IoT'],
    cover: 'photo_smart_buildings.png',
    created: [2024, 1, 15],
    members: 415,
    chair: { person: 'ananya', title: 'Workplace Head @ Cisco GCC' },
  },
  {
    key: 'legal',
    slug: 'legal-compliance-procurement',
    name: 'Legal, Compliance & Procurement Council',
    focus: 'RFP standardization, anti-trust compliance and vendor SLA governance.',
    description: 'RFP standardization, anti-trust compliance frameworks,\nvendor SLA governance, and...',
    segments: ['Legal & Procurement', 'SLA Compliance', 'Procurement', 'Contracts'],
    cover: 'photo_legal.png',
    created: { quarterDay: 6 },
    members: 340,
    chair: { person: 'arvind', title: 'General Counsel @ Brookfield\nIndia' },
  },
  {
    key: 'construction',
    slug: 'construction-projects-mep',
    name: 'Construction, Projects & MEP Council',
    focus: 'Fit-out schedules, MEP commissioning standards and modular build.',
    description: 'Accelerated fit-out schedules, MEP commissioning\nstandards, modular...',
    segments: ['Construction & MEP', 'MEP Design', 'Project Governance', 'Modular Build'],
    cover: 'photo_construction.png',
    created: [2024, 2, 1],
    members: 395,
    chair: { person: 'meenakshi', title: 'Head PMO @ L&T Realty' },
  },
  {
    key: 'realestate',
    // The same council the association seed made: same name, same slug.
    adopt: 'corporate-commercial-real-estate',
    slug: 'corporate-commercial-real-estate',
    name: 'Corporate & Commercial Real Estate Council',
    focus: 'Lease restructuring, transaction benchmarking and SEZ policy.',
    description: 'Lease restructuring, commercial transaction benchmarking,\nSEZ policy shifts, and flexible...',
    segments: ['Real Estate', 'Transaction Mgmt', 'Portfolio Strategy', 'SEZ Regs'],
    cover: 'photo_real_estate.png',
    created: { quarterDay: 10 },
    members: 512,
    chair: { person: 'pooja', title: 'Global Portfolio Head @ Standard Chartered' },
  },
];

/** The third council Bharat and Pooja belong to (the design's "3 Active"): a generic one, so no
 *  design card changes state. The rail lists an executive seat first, then the soonest next session
 *  (this one has none), so it comes third as in the design. */
const THIRD_SEAT = 'workplace-experience';

// ---------------------------------------------------------------------------
// Announcements: what a joined council has posted lately. The app's "N unread" on a joined card is
// the number posted in the last 30 days (the API keeps no read state), so the CXO council has three
// inside the window and the Sustainability council none, whose card then reads "Next Sync: Apr 18".
// ---------------------------------------------------------------------------

const ANNOUNCEMENTS: { key: string; council: string; title: string; body: string; ageDays: number }[] = [
  {
    key: 'cxo-1',
    council: 'cxo',
    title: 'Campus consolidation playbook, version 2',
    body: 'The revised playbook for regional campus consolidation is in the Knowledge tab: occupancy thresholds, CapEx phasing and the exit checklist.',
    ageDays: 2,
  },
  {
    key: 'cxo-2',
    council: 'cxo',
    title: 'Pre-read for the GCC Workplace Leadership roundtable',
    body: 'A four-page pre-read on AI-assisted facility management for GCC campuses is out to all seat holders ahead of the April roundtable.',
    ageDays: 9,
  },
  {
    key: 'cxo-3',
    council: 'cxo',
    title: 'Nominations open for the occupancy benchmarking group',
    body: 'Executive seats may nominate one colleague each to the hybrid-occupancy benchmarking working group. Nominations close at month end.',
    ageDays: 21,
  },
];
const announcementId = (key: string) => `design-ann-${key}`;

// ---------------------------------------------------------------------------
// Events: lib/features/events/demo_events_repository.dart, word for word
// ---------------------------------------------------------------------------

interface Talk {
  person: PersonKey;
  title: string;
  abstract: string;
  /** "Name (bio)" on the sheet's programme. */
  bio: string;
}

interface EventSpec {
  key: string;
  slug: string;
  title: string;
  kind: EventKind;
  description: string;
  location: string;
  cover?: string;
  /** Indian clock. */
  start: Ymdhm;
  end: Ymdhm;
  /** The board's dates while the association seed's generic events (Nov 1 to Nov 22) stay on it: soon
   *  enough that the design's four cards, then the sheet's event, lead the agenda in the design's order
   *  (the app sorts by date and never reorders). `--isolate` hides the generic events and uses the
   *  design's own `start`/`end`, word for word. */
  board?: { start: Ymdhm; end: Ymdhm };
  capacity?: number;
  price?: number;
  inviteOnly?: boolean;
  /** An existing chapter's slug, or 'vinfraa' for the unpublished host chapter. */
  chapter?: string;
  council?: string;
  /** The design's attendee count; 'spotlight' is the most the people there are allow. */
  going?: number | 'spotlight';
  /** Bharat and Pooja hold a place (My Schedule). */
  held?: boolean;
  /** Pooja holds a PAID seat (a ticket row, as a PayU purchase leaves): the API refuses to cancel it, which
   *  the live test relies on to prove the refusal without anything to undo. Needs a `price`. */
  paidSeatForPooja?: boolean;
  talks?: Talk[];
}

const esc = (s: string) => s.replace(/&/g, '&amp;');

const EVENTS: EventSpec[] = [
  // --- The Events board ---------------------------------------------------
  {
    key: 'spotlight',
    slug: `global-cre-proptech-summit-2026-flagship${SUFFIX}`,
    title: 'Global CRE PropTech Summit 2026',
    kind: 'CONFERENCE',
    description:
      "<p>ICR's flagship global gathering for corporate real estate and PropTech leaders: keynotes on autonomous buildings, a live PropTech showcase and the year's benchmark report. Attend in person at the Mumbai Convention Centre or join the hybrid stream.</p>",
    location: 'Mumbai Convention Centre & Hybrid',
    cover: file('events', 'spotlight.jpg'),
    // The card's "15 CPD CREDITS" is the event's own length (the API gives no credit value),
    // so the flagship runs 15 hours, 8 AM to 11 PM.
    start: [2026, 10, 24, 8, 0],
    end: [2026, 10, 24, 23, 0],
    chapter: 'vinfraa',
    going: 'spotlight',
  },
  {
    key: 'ai',
    slug: `future-of-ai-in-facility-management${SUFFIX}`,
    title: 'Future of AI in Facility Management',
    kind: 'WEBINAR',
    description:
      '<p>Dr. Radhika Iyer, VP Sustainable PropTech, walks through where AI is already paying for itself in facility management: predictive maintenance, energy optimisation and service automation, and what to pilot first.</p>',
    location: 'Online',
    cover: file('events', 'card_ai.jpg'),
    start: [2026, 10, 24, 16, 0],
    end: [2026, 10, 24, 17, 30],
    going: 480,
    talks: [
      {
        person: 'radhika',
        title: 'Future of AI in Facility Management',
        abstract:
          'Where AI already pays for itself in facility management: predictive maintenance, energy optimisation and service automation, and what to pilot first.',
        bio: 'VP Sustainable PropTech',
      },
    ],
  },
  {
    key: 'summit',
    slug: `global-cre-proptech-summit-2026${SUFFIX}`,
    title: 'Global CRE PropTech Summit 2026',
    kind: 'CONFERENCE',
    description:
      '<p>Three days of keynotes, tracks and a PropTech expo for commercial real estate leaders. Early-bird passes are open; each pass includes every session, the expo floor and the networking evenings.</p>',
    location: 'Mumbai Convention Centre, Bandra Kurla Complex',
    cover: file('events', 'card_summit.jpg'),
    start: [2026, 11, 12, 9, 0],
    end: [2026, 11, 14, 17, 0],
    board: { start: [2026, 10, 25, 9, 0], end: [2026, 10, 27, 17, 0] },
    price: 1_500_000, // paise: ₹15,000
    chapter: 'vinfraa',
    going: 1420,
  },
  {
    key: 'gcc',
    slug: `sustainable-gcc-campus-net-zero-operations${SUFFIX}`,
    title: 'Sustainable GCC Campus & Net-Zero Operations',
    kind: 'ROUNDTABLE',
    description:
      '<p>A closed-door roundtable for Directors and Heads of CRE who run GCC campuses. Share net-zero operating data, vendor models and lessons from live retrofits. By invitation only: 25 executive seats.</p>',
    location: 'Bengaluru',
    cover: file('events', 'card_gcc.jpg'),
    start: [2026, 11, 25, 14, 30],
    end: [2026, 11, 25, 17, 0],
    board: { start: [2026, 10, 25, 14, 30], end: [2026, 10, 25, 17, 0] },
    capacity: 25,
    inviteOnly: true,
    going: 7,
  },
  {
    key: 'bms',
    slug: `smart-bms-predictive-maintenance-masterclass${SUFFIX}`,
    title: 'Smart BMS & Predictive Maintenance Masterclass',
    kind: 'WORKSHOP',
    description:
      '<p>A hands-on lab on smart building management systems and predictive maintenance: lab simulation and live sensor calibration on real BMS hardware, led by the ICR engineering team at Bangalore HQ.</p>',
    location: 'Bangalore HQ',
    cover: file('events', 'card_bms.jpg'),
    start: [2026, 12, 4, 10, 0],
    end: [2026, 12, 4, 16, 0],
    board: { start: [2026, 10, 26, 10, 0], end: [2026, 10, 26, 16, 0] },
    going: 36,
  },

  // --- The Event Sheet: "Future of Business & Innovation Summit 2024" ------
  {
    key: 'fbis',
    slug: `future-of-business-innovation-summit${SUFFIX}`,
    title: 'Future of Business & Innovation Summit 2024',
    kind: 'CONFERENCE',
    // The demo's description, then the sheet's two highlight cards as a list (a live sheet draws the
    // description's paragraphs; each list item is one).
    description:
      '<p>The ICR Future of Business &amp; Innovation Summit convenes commercial real estate directors, chief sustainability officers, and facility operations leaders to explore autonomous building technologies, predictive maintenance workflows, and net-zero portfolio decarbonization.</p>' +
      '<ul><li><strong>Smart IoT &amp; FM Automation</strong>: Deploying integrated digital twins across campus environments.</li>' +
      '<li><strong>ESG &amp; Decarbonization</strong>: Operational benchmarking for RICS and LEED zero-carbon audits.</li></ul>',
    location: 'Grand Auditorium, Hall 3 • Mumbai Convention Centre',
    cover: file('events', 'sheet_hero.jpg'),
    start: [2026, 10, 24, 10, 0],
    end: [2026, 10, 24, 16, 30],
    board: { start: [2026, 10, 27, 10, 0], end: [2026, 10, 27, 16, 30] },
    chapter: 'vinfraa',
    going: 642,
    held: true,
    talks: [
      {
        person: 'rajesh',
        title: 'The Autonomous Facility: 2025 Architecture',
        abstract:
          'Keynote on the architecture of the autonomous facility: sensing, digital twins and closed-loop operations across a global real estate portfolio.',
        bio: 'VP Global Real Estate, Infosys',
      },
      {
        person: 'priya',
        title: 'Retrofitting Commercial Towers with Smart Sensors',
        abstract: 'Panel on retrofitting commercial towers with smart sensors: cost, interoperability and green-rating outcomes.',
        bio: 'IGBC AP',
      },
    ],
  },

  // --- A paid workshop with a seat already bought (Pooja's), for the Events live tests ---
  // March 2027, after every other card of the board, so it changes nothing the designs show on top.
  {
    key: 'paid-workshop',
    slug: `advanced-lease-audit-workshop${SUFFIX}`,
    title: 'Advanced Lease Audit Workshop',
    kind: 'WORKSHOP',
    description:
      '<p>A one-day workshop on auditing commercial leases: escalations, CAM reconciliations and exit clauses, with worked examples from live portfolios. Seats are ticketed: ₹2,000 a pass.</p>',
    location: 'Mumbai',
    start: [2027, 3, 6, 10, 0],
    end: [2027, 3, 6, 16, 0],
    price: 200_000, // paise: ₹2,000
    capacity: 30,
    going: 12,
    paidSeatForPooja: true,
  },

  // --- Council roundtables: the Councils screen's "Upcoming Roundtables" ---
  // The design's dates (Apr 18, Apr 25, May 03 2027). The screen lists council events of the
  // roundtable kind, soonest first, so the generic events (workshops, webinars, a conference) that
  // fall sooner never push these off the top three.
  {
    key: 'rt-sust',
    slug: `esg-mandates-brsr-core-scope-3${SUFFIX}`,
    title: 'ESG Mandates: BRSR Core & Scope 3',
    // A roundtable held online: the Councils screen lists council events of the roundtable kind and
    // words a venue of "Online" as VIRTUAL.
    kind: 'ROUNDTABLE',
    description:
      '<p>Sustainability, ESG &amp; Net-Zero Council webinar on BRSR Core disclosures and Scope 3 data collection for corporate portfolios.</p>',
    location: 'Online',
    start: [2027, 4, 18, 15, 30],
    end: [2027, 4, 18, 17, 0],
    council: 'sust',
    going: 82,
  },
  {
    key: 'rt-cxo',
    slug: `gcc-workplace-leadership-ai-fm${SUFFIX}`,
    title: 'GCC Workplace Leadership & AI FM',
    kind: 'ROUNDTABLE',
    description:
      '<p>CXO Workplace Strategy &amp; FM Leadership roundtable on running GCC workplaces with AI-assisted facility management. Hybrid from Bengaluru.</p>',
    location: 'Bengaluru (Hybrid)',
    start: [2027, 4, 25, 16, 0],
    end: [2027, 4, 25, 17, 30],
    council: 'cxo',
    going: 120,
    held: true,
  },
  {
    key: 'rt-legal',
    slug: `vendor-rfp-standardization-amcs${SUFFIX}`,
    title: 'Vendor RFP Standardization & AMCs',
    kind: 'ROUNDTABLE',
    description:
      '<p>Closed-door session of the Legal, Compliance &amp; Procurement Council on standardising vendor RFPs and AMC contracts.</p>',
    location: 'Mumbai',
    start: [2027, 5, 3, 11, 0],
    end: [2027, 5, 3, 12, 30],
    inviteOnly: true, // the screen words it "CLOSED-DOOR"
    council: 'legal',
    going: 64,
  },
  // The other three cards' "Next: …" dates.
  {
    key: 'next-smart',
    slug: `bacnet-interoperability-smart-metering${SUFFIX}`,
    title: 'BACnet Interoperability & Smart Metering Working Session',
    kind: 'WORKSHOP',
    description:
      '<p>Smart Buildings council working session on BACnet interoperability, smart metering protocols and HVAC optimisation.</p>',
    location: 'Online',
    start: [2027, 4, 25, 16, 0],
    end: [2027, 4, 25, 17, 30],
    council: 'smart',
  },
  {
    key: 'next-construction',
    slug: `mep-commissioning-standards-masterclass${SUFFIX}`,
    title: 'MEP Commissioning Standards Masterclass',
    // The one masterclass: the board's "Explore by Category" tiles are the event kinds, and the
    // design shows six of them.
    kind: 'MASTERCLASS',
    description:
      '<p>Construction council masterclass on accelerated fit-out schedules and MEP commissioning standards.</p>',
    location: 'Online',
    start: [2027, 5, 8, 10, 0],
    end: [2027, 5, 8, 12, 0],
    council: 'construction',
  },
  {
    key: 'next-realestate',
    slug: `lease-restructuring-sez-policy-roundtable${SUFFIX}`,
    title: 'Lease Restructuring & SEZ Policy Roundtable',
    kind: 'ROUNDTABLE',
    description:
      '<p>Corporate &amp; Commercial Real Estate council roundtable on lease restructuring, transaction benchmarking and SEZ policy shifts.</p>',
    location: 'Online',
    start: [2027, 5, 15, 15, 0],
    end: [2027, 5, 15, 16, 30],
    council: 'realestate',
  },

  // --- Chapter dates: the Councils screen's In-Person Summits footer ---------
  ...(
    [
      ['bengaluru', 'Bengaluru', [2027, 4, 26, 10, 0]],
      ['mumbai', 'Mumbai', [2027, 5, 10, 10, 0]],
      ['delhi-ncr', 'Delhi NCR', [2027, 5, 17, 10, 0]],
      ['hyderabad', 'Hyderabad', [2027, 6, 5, 10, 0]],
    ] as [string, string, Ymdhm][]
  ).map(
    ([chapter, city, start]): EventSpec => ({
      key: `chapter-${chapter}`,
      slug: `${chapter}-chapter-summit${SUFFIX}`,
      title: `${city} Chapter Summit`,
      kind: 'CHAPTER_MEET',
      description: `<p>The ICR ${city} chapter's in-person summit: closed-door council roundtables and a peer networking evening.</p>`,
      location: city,
      start,
      end: [start[0], start[1], start[2], start[3] + 3, start[4]],
      chapter,
    }),
  ),
];

// ---------------------------------------------------------------------------
// Manifest: what existed before the seed changed it, kept in `Setting`
// ---------------------------------------------------------------------------

interface MemberRow {
  councilId: string;
  userId: string;
  role: 'LEAD' | 'MEMBER';
  title: string | null;
  linkedinUrl: string | null;
  joinedAt: string;
}

interface Manifest {
  version: 1;
  /** Existing councils the design's councils are. */
  adopted: {
    id: string;
    original: {
      focus: string | null;
      description: string | null;
      segments: string[];
      coverUrl: string | null;
      createdAt: string;
      updatedAt: string;
    };
    originalMembers: MemberRow[];
  }[];
  /** Council seats the two people had before, which the seed took away. */
  removedMemberships: MemberRow[];
  /** Seats the seed gave them in councils that are not the seed's own. */
  addedMemberships: { councilId: string; userId: string }[];
  /** Events --isolate hid, with their `updatedAt` so --remove restores them exactly. */
  unpublishedEvents: { id: string; updatedAt: string }[];
  /** The CPD targets the seed set, with what the person had before (null: no row). */
  cpdTargets: { userId: string; year: number; hours: number | null }[];
}

const emptyManifest = (): Manifest => ({
  version: 1,
  adopted: [],
  removedMemberships: [],
  addedMemberships: [],
  unpublishedEvents: [],
  cpdTargets: [],
});

async function loadManifest(prisma: PrismaClient): Promise<Manifest> {
  const row = await prisma.setting.findUnique({ where: { key: MANIFEST_KEY }, select: { value: true } });
  return row ? { ...emptyManifest(), ...(row.value as unknown as Manifest) } : emptyManifest();
}

async function saveManifest(prisma: PrismaClient, m: Manifest): Promise<void> {
  const value = m as unknown as Prisma.InputJsonValue;
  await prisma.setting.upsert({ where: { key: MANIFEST_KEY }, update: { value }, create: { key: MANIFEST_KEY, value } });
}

const rowOf = (m: {
  councilId: string;
  userId: string;
  role: string;
  title: string | null;
  linkedinUrl: string | null;
  joinedAt: Date;
}): MemberRow => ({
  councilId: m.councilId,
  userId: m.userId,
  role: m.role as 'LEAD' | 'MEMBER',
  title: m.title,
  linkedinUrl: m.linkedinUrl,
  joinedAt: m.joinedAt.toISOString(),
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** A council's creation moment: its date, or a day of the running quarter (never later than an hour ago). */
function createdAtOf(c: CouncilSpec, now: Date): Date {
  if (Array.isArray(c.created)) return new Date(Date.UTC(c.created[0], c.created[1] - 1, c.created[2]));
  const quarterStart = Date.UTC(now.getUTCFullYear(), Math.floor(now.getUTCMonth() / 3) * 3, 1);
  return new Date(Math.min(quarterStart + c.created.quarterDay * DAY, now.getTime() - HOUR));
}

/** A stable number from a string, to start each list at a different place in the people. */
function spread(key: string): number {
  let h = 0;
  for (const c of key) h = (h * 31 + c.charCodeAt(0)) >>> 0;
  return h;
}

/** `n` distinct items from `items`, starting at a place chosen by `key` and wrapping. */
function take<T>(items: T[], n: number, key: string): T[] {
  if (n <= 0 || items.length === 0) return [];
  if (n >= items.length) return items.slice();
  const start = spread(key) % items.length;
  return Array.from({ length: n }, (_, i) => items[(start + i) % items.length]);
}

/** DATABASE_URL from the environment, else from `.env` in the cwd (Prisma reads that file itself,
 *  so the variable is often not exported). Never logged: it holds the password. */
function databaseUrl(): string | undefined {
  if (process.env.DATABASE_URL) return process.env.DATABASE_URL;
  const envFile = join(process.cwd(), '.env');
  if (!existsSync(envFile)) return undefined;
  return readFileSync(envFile, 'utf8').match(/^\s*DATABASE_URL\s*=\s*"?([^"\r\n]+)"?/m)?.[1];
}

async function assertLocalDatabase(prisma: PrismaClient, log: (m: string) => void): Promise<void> {
  if (process.env.NODE_ENV === 'production') throw new Error('Refusing to seed design content with NODE_ENV=production.');
  // Two independent checks: where the URL points, and where the server says the connection landed.
  let hostOk = true;
  const url = databaseUrl();
  if (url) {
    try {
      const host = new URL(url).hostname.replace(/^\[|\]$/g, '');
      hostOk = ['localhost', '127.0.0.1', '::1'].includes(host);
    } catch {
      hostOk = false;
    }
  }
  const rows = (await prisma.$queryRawUnsafe(
    `select current_database() as db, inet_server_addr()::text as addr`,
  )) as { db: string; addr: string | null }[];
  const addr = String(rows[0]?.addr ?? '').split('/')[0];
  const loopback = addr === '' || addr === '127.0.0.1' || addr === '::1';
  if (!loopback || !hostOk) throw new Error('Refusing to run: the database is not on localhost.');
  log(`database "${rows[0]?.db}" on ${addr || 'a local socket'}: local${url ? ' (DATABASE_URL host checked)' : ''}`);
  if (!existsSync(join(process.cwd(), 'prisma', 'schema.prisma'))) {
    throw new Error(`Run this from E:\\ICR\\irc-portal\\backend (cwd is ${process.cwd()}): uploads resolve from it.`);
  }
}

function copyAssets(log: (m: string) => void): void {
  const uploads = join(process.cwd(), 'uploads');
  if (!existsSync(uploads)) mkdirSync(uploads, { recursive: true });
  for (const a of ASSETS) copyFileSync(join(a.base === 'seed' ? SEED_ASSETS : DEMO_ASSETS, a.from), join(uploads, a.to));
  for (const f of LEGACY_FILES) if (existsSync(join(uploads, f))) unlinkSync(join(uploads, f));
  log(`  files: ${ASSETS.length} copied to uploads/`);
}

// ---------------------------------------------------------------------------
// Seed
// ---------------------------------------------------------------------------

export interface SeedOptions {
  /** Delete what the seed created and restore what it changed. */
  remove?: boolean;
  /** Also unpublish the association seed's generic events, so the lists hold only design content. */
  isolate?: boolean;
  /** @deprecated No longer does anything: the councils carry no shared tag any more. */
  lift?: boolean;
  /** Plan only: read, count, log; write nothing. */
  dryRun?: boolean;
  /** For tests. */
  now?: Date;
}

export async function seedEventsCouncils(
  prisma: PrismaClient,
  log: (m: string) => void,
  opts: SeedOptions = {},
): Promise<void> {
  await assertLocalDatabase(prisma, log);
  if (opts.remove) {
    await removeAll(prisma, log);
    return;
  }
  await seedAll(prisma, log, opts);
}

async function seedAll(prisma: PrismaClient, log: (m: string) => void, opts: SeedOptions): Promise<void> {
  const now = opts.now ?? new Date();
  const isolate = !!opts.isolate;
  const dry = !!opts.dryRun;

  // The design's dates are written for Oct 24, 2026. Run on a later day, the whole set moves by
  // whole days (the Indian clock has no DST, so times of day hold) until its first event is ahead.
  const spotlightStart = ist(EVENTS[0].start).getTime();
  const shiftDays = spotlightStart >= now.getTime() + 2 * HOUR ? 0 : Math.ceil((now.getTime() + 2 * HOUR - spotlightStart) / DAY);
  // Only the 2026 dates move: the council roundtables, "Next:" dates and chapter summits are the
  // design's own 2027 dates and stay put.
  const FIXED_FROM = Date.UTC(2027, 0, 1);
  const when = (t: Ymdhm) => {
    const d = ist(t);
    return d.getTime() >= FIXED_FROM ? d : new Date(d.getTime() + shiftDays * DAY);
  };
  if (shiftDays > 0) log(`  dates: moved +${shiftDays} day(s) so the design's first event is still ahead`);

  // --- The people there are -------------------------------------------------
  // The portal's own accounts: its seeded and test users, on @icr.dev and @icr.test. A person on any
  // other domain is a persona some design seed made (this one's, Learning/Jobs, Mentorship), and
  // counting them would tie these counts to another seed's --remove.
  const pool = await prisma.user.findMany({
    where: {
      isActive: true,
      OR: [{ email: { endsWith: '@icr.dev', mode: 'insensitive' } }, { email: { endsWith: '@icr.test', mode: 'insensitive' } }],
    },
    orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    select: { id: true, email: true },
  });
  const bharat = pool.find((u) => u.email.toLowerCase() === BHARAT_EMAIL);
  const pooja = pool.find((u) => u.email.toLowerCase() === POOJA_EMAIL);
  if (!bharat) log(`  warning: ${BHARAT_EMAIL} not found: no joined state or schedule for the emulator's person`);
  if (!pooja) log(`  warning: ${POOJA_EMAIL} not found`);
  const two = [bharat, pooja].filter(Boolean) as { id: string; email: string }[];
  const twoIds = new Set(two.map((u) => u.id));
  const others = pool.filter((u) => !twoIds.has(u.id));
  const U = pool.length;
  const A = others.length;
  log(`  people: ${U} accounts (${A} besides Bharat and Pooja); scaling attendee and member counts to them`);

  // How many go. The spotlight takes everyone who is not one of the two (they hold two other places),
  // and everything else stays one below it, so the board's "most going" is always the spotlight.
  const cap = Math.max(0, A - 1);
  const going = (e: EventSpec): number => (e.going === 'spotlight' ? A : Math.min(e.going ?? 0, cap));
  const scale = U / BIGGEST_COUNCIL;
  const memberTarget = (c: CouncilSpec) => Math.max(2, Math.min(Math.round(c.members * scale), U + 1));

  if (dry) {
    log('  dry run: nothing is written');
    for (const e of EVENTS) {
      log(`    event ${e.slug}: ${going(e)} going, ${when(e.board && !isolate ? e.board.start : e.start).toISOString()}`);
    }
    for (const c of COUNCILS) log(`    council ${c.slug}: ${memberTarget(c)} members`);
    return;
  }

  // --- Files ------------------------------------------------------------------
  copyAssets(log);

  const manifest = await loadManifest(prisma);

  // --- People (chairs and speakers) -------------------------------------------
  for (const key of Object.keys(PEOPLE) as PersonKey[]) {
    const p = PEOPLE[key];
    const data = {
      firstName: p.first,
      lastName: p.last,
      designation: p.designation,
      isActive: false, // never listed, never signs in
      profilePublic: false,
    };
    await prisma.user.upsert({
      where: { email: personEmail(key) },
      update: data,
      create: { id: personId(key), email: personEmail(key), passwordHash: null, ...data },
      select: { id: true },
    });
  }
  // An existing row on that email keeps its own id, so read the ids back.
  const personIds = new Map<PersonKey, string>();
  for (const key of Object.keys(PEOPLE) as PersonKey[]) {
    const row = await prisma.user.findUnique({ where: { email: personEmail(key) }, select: { id: true } });
    personIds.set(key, row!.id);
  }
  log(`  people: ${personIds.size} chairs and speakers (inactive, not public, no password)`);

  // --- The unpublished host chapter ---------------------------------------------
  const hostData = { name: HOST_CHAPTER.name, city: HOST_CHAPTER.city, country: 'India', published: false, deletedAt: null };
  const host = await prisma.chapter.upsert({
    where: { slug: HOST_CHAPTER.slug },
    update: hostData,
    create: { id: HOST_CHAPTER.id, slug: HOST_CHAPTER.slug, ...hostData },
    select: { id: true },
  });
  const chapterRows = await prisma.chapter.findMany({
    where: { slug: { in: ['bengaluru', 'mumbai', 'delhi-ncr', 'hyderabad'] } },
    select: { id: true, slug: true },
  });
  const chapterIds = new Map<string, string>([['vinfraa', host.id], ...chapterRows.map((c) => [c.slug, c.id] as [string, string])]);

  // --- Councils -------------------------------------------------------------------
  const councilIds = new Map<string, string>();
  const councilAdopted = new Set<string>();
  for (const c of COUNCILS) {
    const segments = c.segments;
    const created = createdAtOf(c, now);
    const base = {
      focus: c.focus,
      description: c.description,
      segments,
      coverUrl: up(file('councils', c.cover)),
      createdAt: created,
      published: true,
      deletedAt: null,
    };
    const existing = c.adopt
      ? await prisma.council.findFirst({ where: { slug: c.adopt, deletedAt: null }, select: { id: true } })
      : null;
    if (existing) {
      // Keep what the row was before, once, before the first change.
      if (!manifest.adopted.some((a) => a.id === existing.id)) {
        const row = await prisma.council.findUniqueOrThrow({ where: { id: existing.id } });
        const members = await prisma.councilMember.findMany({ where: { councilId: existing.id } });
        manifest.adopted.push({
          id: existing.id,
          original: {
            focus: row.focus,
            description: row.description,
            segments: row.segments,
            coverUrl: row.coverUrl,
            createdAt: row.createdAt.toISOString(),
            updatedAt: row.updatedAt.toISOString(),
          },
          originalMembers: members.map(rowOf),
        });
        await saveManifest(prisma, manifest);
      }
      await prisma.council.update({ where: { id: existing.id }, data: base, select: { id: true } });
      councilIds.set(c.key, existing.id);
      councilAdopted.add(c.key);
    } else {
      const id = `design-council-${c.key}`;
      const slug = `${c.slug}${SUFFIX}`;
      const aboutHtml = `<h3>Focus</h3><p>${esc(c.focus)}</p>`;
      const row = await prisma.council.upsert({
        where: { id },
        update: { slug, name: c.name, ...base, aboutHtml },
        create: { id, slug, name: c.name, ...base, aboutHtml },
        select: { id: true },
      });
      councilIds.set(c.key, row.id);
    }
  }
  log(`  councils: ${COUNCILS.length - councilAdopted.size} of the seed's own, ${councilAdopted.size} adopted`);

  // --- Bharat's and Pooja's seats ---------------------------------------------------
  // What they held before is kept in the manifest, then taken away: "Your Joined Councils" lists
  // every seat a person holds, and the design shows three.
  // A seat is the seed's own when it is in a council the seed made, or one it added on an earlier run.
  const ownCouncilIds = new Set(COUNCILS.filter((c) => !councilAdopted.has(c.key)).map((c) => councilIds.get(c.key)!));
  const addedKey = (a: { councilId: string; userId: string }) => `${a.councilId}:${a.userId}`;
  const addedBefore = new Set(manifest.addedMemberships.map(addedKey));
  for (const u of two) {
    const seats = await prisma.councilMember.findMany({ where: { userId: u.id } });
    const theirs = seats.filter((s) => !ownCouncilIds.has(s.councilId) && !addedBefore.has(addedKey(s)));
    const kept = new Set(manifest.removedMemberships.map(addedKey));
    for (const s of theirs) if (!kept.has(addedKey(s))) manifest.removedMemberships.push(rowOf(s));
    if (theirs.length) {
      await saveManifest(prisma, manifest); // before the delete: never lose a seat unrecorded
      await prisma.councilMember.deleteMany({ where: { OR: theirs.map((s) => ({ councilId: s.councilId, userId: s.userId })) } });
      log(`  ${u.email}: ${theirs.length} earlier council seat(s) set aside`);
    }
  }

  // --- Council members ----------------------------------------------------------------
  for (const c of COUNCILS) {
    const councilId = councilIds.get(c.key)!;
    const adopted = councilAdopted.has(c.key);
    const created = createdAtOf(c, now);
    const chairId = personIds.get(c.chair.person)!;

    const want = new Map<string, { role: 'LEAD' | 'MEMBER'; title: string | null; joinedAt?: Date }>();
    want.set(chairId, { role: 'LEAD', title: c.chair.title, joinedAt: created });
    if (c.seat) {
      for (const u of two) {
        want.set(u.id, { role: c.seat, title: c.seat === 'LEAD' ? 'Executive Council Member' : null });
      }
    }
    const current = await prisma.councilMember.findMany({ where: { councilId } });
    // The list is exactly the designed one. An adopted council also keeps the members it had before
    // the seed (its manifest record), except Bharat and Pooja, whose seats are the design's own.
    const target = memberTarget(c);
    const original = adopted ? (manifest.adopted.find((a) => a.id === councilId)?.originalMembers ?? []) : [];
    const base = new Set([...original.map((m) => m.userId).filter((id) => !twoIds.has(id)), ...want.keys()]);
    const room = Math.max(0, target - base.size);
    const fill = take(
      others.filter((u) => !base.has(u.id)),
      room,
      `council:${c.key}`,
    );
    for (const u of fill) want.set(u.id, { role: 'MEMBER', title: null });
    const desired = new Set([...base, ...want.keys()]);

    const drop = current.filter((m) => !desired.has(m.userId)).map((m) => m.userId);
    if (drop.length) await prisma.councilMember.deleteMany({ where: { councilId, userId: { in: drop } } });
    const byUser = new Map(current.map((m) => [m.userId, m]));
    for (const [userId, w] of want) {
      const row = byUser.get(userId);
      const isChair = userId === chairId;
      if (!row) continue;
      if (row.role !== w.role || row.title !== w.title || (isChair && w.joinedAt && row.joinedAt.getTime() !== w.joinedAt.getTime())) {
        await prisma.councilMember.update({
          where: { councilId_userId: { councilId, userId } },
          data: { role: w.role, title: w.title, ...(isChair && w.joinedAt ? { joinedAt: w.joinedAt } : {}) },
          select: { userId: true },
        });
      }
    }
    const add = [...want].filter(([userId]) => !byUser.has(userId));
    if (add.length) {
      await prisma.councilMember.createMany({
        data: add.map(([userId, w]) => ({
          councilId,
          userId,
          role: w.role,
          title: w.title,
          ...(w.joinedAt ? { joinedAt: w.joinedAt } : {}),
        })),
        skipDuplicates: true,
      });
    }
    const total = await prisma.councilMember.count({ where: { councilId } });
    log(`  council ${c.name}: ${total} members (design ${c.members})`);
  }

  // The third seat, in a council that is not the seed's own.
  const third = await prisma.council.findFirst({ where: { slug: THIRD_SEAT, deletedAt: null }, select: { id: true, name: true } });
  if (third) {
    for (const u of two) {
      const had = await prisma.councilMember.findUnique({
        where: { councilId_userId: { councilId: third.id, userId: u.id } },
      });
      if (had && !addedBefore.has(addedKey({ councilId: third.id, userId: u.id }))) {
        // Not ours: keep it as it was, then replace it.
        if (!manifest.removedMemberships.some((r) => addedKey(r) === addedKey(had))) manifest.removedMemberships.push(rowOf(had));
        await saveManifest(prisma, manifest);
        await prisma.councilMember.delete({ where: { councilId_userId: { councilId: third.id, userId: u.id } } });
      }
      await prisma.councilMember.upsert({
        where: { councilId_userId: { councilId: third.id, userId: u.id } },
        update: { role: 'MEMBER', title: null },
        create: { councilId: third.id, userId: u.id, role: 'MEMBER' },
        select: { userId: true },
      });
      if (!manifest.addedMemberships.some((a) => addedKey(a) === addedKey({ councilId: third.id, userId: u.id }))) {
        manifest.addedMemberships.push({ councilId: third.id, userId: u.id });
      }
    }
    await saveManifest(prisma, manifest);
    log(`  third seat: ${third.name}`);
  } else {
    log(`  warning: council "${THIRD_SEAT}" not found: the joined rail will list two seats`);
  }

  // --- Announcements ---------------------------------------------------------------------------
  const wantedAnnouncements = new Set<string>();
  for (const a of ANNOUNCEMENTS) {
    const id = announcementId(a.key);
    wantedAnnouncements.add(id);
    const data = {
      councilId: councilIds.get(a.council)!,
      title: a.title,
      body: a.body,
      pinned: false,
      createdAt: new Date(now.getTime() - a.ageDays * DAY), // re-based on every run, so they stay recent
    };
    await prisma.councilAnnouncement.upsert({ where: { id }, update: data, create: { id, ...data }, select: { id: true } });
  }
  const staleAnnouncements = await prisma.councilAnnouncement.deleteMany({
    where: { id: { startsWith: 'design-ann-', notIn: [...wantedAnnouncements] } },
  });
  log(`  announcements: ${wantedAnnouncements.size} (${staleAnnouncements.count} stale removed)`);

  // --- Events -----------------------------------------------------------------------------
  const eventIds = new Map<string, string>();
  for (const e of EVENTS) {
    const dates = e.board && !isolate ? e.board : { start: e.start, end: e.end };
    const data = {
      title: e.title,
      description: e.description,
      location: e.location,
      kind: e.kind,
      coverUrl: e.cover ? up(e.cover) : null,
      capacity: e.capacity ?? null,
      priceAmount: e.price ?? null,
      priceCurrency: 'INR',
      inviteOnly: !!e.inviteOnly,
      published: true,
      deletedAt: null,
      callForSpeakersUntil: null,
      startsAt: when(dates.start),
      endsAt: when(dates.end),
      chapterId: e.chapter ? (chapterIds.get(e.chapter) ?? null) : null,
      councilId: e.council ? (councilIds.get(e.council) ?? null) : null,
    };
    const id = `design-ev-${e.key}`;
    const row = await prisma.event.upsert({
      where: { id },
      update: { slug: e.slug, ...data },
      create: { id, slug: e.slug, ...data },
      select: { id: true },
    });
    eventIds.set(e.key, row.id);
  }
  log(`  events: ${EVENTS.length} upserted`);

  // --- Who goes, who is asked, who speaks ---------------------------------------------------------
  const spotlightGoing = going(EVENTS[0]);
  for (const e of EVENTS) {
    const eventId = eventIds.get(e.key)!;
    const n = going(e);
    const heldIds = e.held ? two.map((u) => u.id) : e.paidSeatForPooja && pooja ? [pooja.id] : [];
    const users = [...heldIds, ...take(others, Math.max(0, n - heldIds.length), `event:${e.key}`).map((u) => u.id)];
    const wanted = new Set(users);

    const existing = await prisma.eventAttendee.findMany({ where: { eventId }, select: { userId: true, status: true } });
    const drop = existing.filter((a) => !wanted.has(a.userId)).map((a) => a.userId);
    if (drop.length) await prisma.eventAttendee.deleteMany({ where: { eventId, userId: { in: drop } } });
    const status = new Map(existing.map((a) => [a.userId, a.status]));
    const fix = users.filter((id) => status.has(id) && status.get(id) !== 'GOING');
    if (fix.length) await prisma.eventAttendee.updateMany({ where: { eventId, userId: { in: fix } }, data: { status: 'GOING' } });
    const create = users.filter((id) => !status.has(id));
    if (create.length) {
      await prisma.eventAttendee.createMany({
        data: create.map((userId) => ({ eventId, userId, status: 'GOING' as const })),
        skipDuplicates: true,
      });
    }

    // An invite-only event is on the board for the people asked to it.
    if (e.inviteOnly) {
      const asked = new Set([...two.map((u) => u.id), ...users]);
      const haveInvites = new Set((await prisma.eventInvite.findMany({ where: { eventId }, select: { userId: true } })).map((i) => i.userId));
      const staleInvites = [...haveInvites].filter((id) => !asked.has(id));
      if (staleInvites.length) await prisma.eventInvite.deleteMany({ where: { eventId, userId: { in: staleInvites } } });
      const newInvites = [...asked].filter((id) => !haveInvites.has(id));
      if (newInvites.length) {
        await prisma.eventInvite.createMany({
          data: newInvites.map((userId) => ({ eventId, userId, source: 'design-seed' })),
          skipDuplicates: true,
        });
      }
    }

    // A paid seat: the ticket a purchase leaves (the API's cancel refuses a seat that has one).
    if (e.paidSeatForPooja && pooja && e.price) {
      const providerTxnId = `design-seed-txn-${e.key}`;
      const ticket = {
        eventId,
        userId: pooja.id,
        status: 'PAID' as const,
        titleSnapshot: e.title,
        currency: 'INR',
        listPaisa: e.price,
        totalPaisa: e.price,
        provider: 'design-seed',
        paidAt: new Date(),
      };
      await prisma.eventTicket.upsert({
        where: { providerTxnId },
        update: ticket,
        create: { providerTxnId, ...ticket },
        select: { id: true },
      });
    }

    // Accepted talks are the programme the sheet draws.
    for (const [i, t] of (e.talks ?? []).entries()) {
      const userId = personIds.get(t.person)!;
      const data = {
        title: t.title,
        abstract: t.abstract,
        bio: t.bio,
        status: 'ACCEPTED' as const,
        reviewedAt: new Date(Date.UTC(2026, 9, 1, 9, i)), // the programme lists talks in review order
      };
      await prisma.eventSpeakerProposal.upsert({
        where: { eventId_userId: { eventId, userId } },
        update: data,
        create: { eventId, userId, ...data },
        select: { id: true },
      });
    }
  }
  const totalGoing = await prisma.eventAttendee.count({ where: { event: { slug: { endsWith: SUFFIX } } } });
  log(`  attendees: ${totalGoing} places across the design events (spotlight ${spotlightGoing}, one below it for the rest)`);

  // --- The CPD ledger behind the board's "CPD Earned 8.5 / 15" tile ---------------------------------
  if (bharat) await seedCpd(prisma, bharat.id, manifest, now.getUTCFullYear(), log);

  // --- --isolate: hide the generic events (and bring them back on a run without it) --------------------
  if (isolate) {
    const generic = await prisma.event.findMany({
      where: { slug: { in: GENERIC_EVENT_SLUGS }, published: true },
      select: { id: true, updatedAt: true },
    });
    for (const g of generic) {
      if (!manifest.unpublishedEvents.some((u) => u.id === g.id)) {
        manifest.unpublishedEvents.push({ id: g.id, updatedAt: g.updatedAt.toISOString() });
      }
    }
    await saveManifest(prisma, manifest); // before the unpublish
    if (generic.length) {
      await prisma.event.updateMany({ where: { id: { in: generic.map((g) => g.id) } }, data: { published: false } });
    }
    log(`  isolate: ${generic.length} generic event(s) hidden (${manifest.unpublishedEvents.length} in all)`);
  } else if (manifest.unpublishedEvents.length) {
    await restoreUnpublished(prisma, manifest);
    log('  isolate off: the generic events are published again');
  }

  await saveManifest(prisma, manifest);
  log('done');
}

// ---------------------------------------------------------------------------
// CPD: the Events board's tile reads the member's ledger and their yearly target
// ---------------------------------------------------------------------------

/** The design's tile: 8.5 hours logged against a 15-hour year. */
const CPD_TARGET_HOURS = 15;
const CPD_ENTRIES: { key: string; source: 'MENTORING' | 'EVENT' | 'COURSE'; hours: number; description: string; month: number; day: number }[] = [
  { key: '1', source: 'MENTORING', hours: 2, description: 'Mentoring session with Srikanth Sriramagiri', month: 3, day: 12 },
  { key: '2', source: 'EVENT', hours: 3.5, description: 'Event · Workplace Experience Conclave 2026', month: 6, day: 5 },
  { key: '3', source: 'COURSE', hours: 3, description: 'Course · Facility Management Essentials', month: 8, day: 20 },
];
/** What `--remove` finds: a ledger entry's reference. */
const CPD_REF = 'design-cpd-';

/** Bharat's year: three ledger entries that add to 8.5 hours, and a target of 15 (the default is 20). The
 *  target he had is kept in the manifest and put back by `--remove`. */
async function seedCpd(prisma: PrismaClient, userId: string, manifest: Manifest, year: number, log: (m: string) => void): Promise<void> {
  if (!manifest.cpdTargets.some((t) => t.userId === userId && t.year === year)) {
    const had = await prisma.cpdTarget.findUnique({ where: { userId_year: { userId, year } }, select: { targetHours: true } });
    manifest.cpdTargets.push({ userId, year, hours: had?.targetHours ?? null });
    await saveManifest(prisma, manifest); // before the change: never lose a target unrecorded
  }
  await prisma.cpdTarget.upsert({
    where: { userId_year: { userId, year } },
    update: { targetHours: CPD_TARGET_HOURS },
    create: { userId, year, targetHours: CPD_TARGET_HOURS },
    select: { id: true },
  });
  for (const c of CPD_ENTRIES) {
    const sourceRefId = `${CPD_REF}${c.key}`;
    const data = { hours: c.hours, description: c.description, awardedAt: new Date(Date.UTC(year, c.month - 1, c.day, 9, 0)) };
    const have = await prisma.cpdEntry.findFirst({ where: { userId, source: c.source, sourceRefId }, select: { id: true } });
    if (have) await prisma.cpdEntry.update({ where: { id: have.id }, data, select: { id: true } });
    else await prisma.cpdEntry.create({ data: { userId, source: c.source, sourceRefId, ...data }, select: { id: true } });
  }
  const total = CPD_ENTRIES.reduce((sum, c) => sum + c.hours, 0);
  log(`  cpd: ${CPD_ENTRIES.length} ledger entries (${total} hours) and a ${CPD_TARGET_HOURS}-hour target for ${year}`);
}

async function restoreUnpublished(prisma: PrismaClient, manifest: Manifest): Promise<void> {
  for (const u of manifest.unpublishedEvents) {
    await prisma.event.updateMany({ where: { id: u.id }, data: { published: true, updatedAt: new Date(u.updatedAt) } });
  }
  manifest.unpublishedEvents = [];
}

// ---------------------------------------------------------------------------
// Remove
// ---------------------------------------------------------------------------

async function removeAll(prisma: PrismaClient, log: (m: string) => void): Promise<void> {
  const manifest = await loadManifest(prisma);
  const hadManifest = !!(await prisma.setting.findUnique({ where: { key: MANIFEST_KEY }, select: { id: true } }));
  const step = async (label: string, fn: () => Promise<{ count: number } | unknown>) => {
    const r = (await fn()) as { count?: number } | undefined;
    log(`  ${label}${typeof r?.count === 'number' ? `: ${r.count}` : ''}`);
  };

  // Events: their attendees, invitations and talks go with them; a ticket does not (no cascade).
  await step('tickets on design events', () =>
    prisma.eventTicket.deleteMany({ where: { event: { OR: [{ slug: { endsWith: SUFFIX } }, { id: { startsWith: 'design-ev-' } }] } } }),
  );
  await step('events', () =>
    prisma.event.deleteMany({ where: { OR: [{ slug: { endsWith: SUFFIX } }, { id: { startsWith: 'design-ev-' } }] } }),
  );

  await step('council announcements', () =>
    prisma.councilAnnouncement.deleteMany({ where: { id: { startsWith: 'design-ann-' } } }),
  );

  // The CPD ledger entries the seed wrote, and the targets put back as they were.
  await step('cpd ledger entries', () => prisma.cpdEntry.deleteMany({ where: { sourceRefId: { startsWith: CPD_REF } } }));
  for (const t of manifest.cpdTargets) {
    if (t.hours === null) await prisma.cpdTarget.deleteMany({ where: { userId: t.userId, year: t.year } });
    else {
      await prisma.cpdTarget.updateMany({ where: { userId: t.userId, year: t.year }, data: { targetHours: t.hours } });
    }
  }
  if (manifest.cpdTargets.length) log(`  cpd targets put back: ${manifest.cpdTargets.length}`);

  // Councils the seed made (members, saves and announcements go with them).
  await step('councils', () =>
    prisma.council.deleteMany({ where: { OR: [{ slug: { endsWith: SUFFIX } }, { id: { startsWith: 'design-council-' } }] } }),
  );

  // The adopted council goes back to what it was.
  for (const a of manifest.adopted) {
    const exists = await prisma.council.findUnique({ where: { id: a.id }, select: { id: true } });
    if (!exists) continue;
    await prisma.council.update({
      where: { id: a.id },
      data: {
        focus: a.original.focus,
        description: a.original.description,
        segments: a.original.segments,
        coverUrl: a.original.coverUrl,
        createdAt: new Date(a.original.createdAt),
        updatedAt: new Date(a.original.updatedAt),
      },
      select: { id: true },
    });
    await prisma.councilMember.deleteMany({ where: { councilId: a.id } });
    const users = new Set((await prisma.user.findMany({ where: { id: { in: a.originalMembers.map((m) => m.userId) } }, select: { id: true } })).map((u) => u.id));
    await prisma.councilMember.createMany({
      data: a.originalMembers.filter((m) => users.has(m.userId)).map((m) => ({ ...m, joinedAt: new Date(m.joinedAt) })),
      skipDuplicates: true,
    });
    log(`  adopted council ${a.id}: restored (${a.originalMembers.length} original members)`);
  }

  // The two people's seats.
  for (const a of manifest.addedMemberships) {
    await prisma.councilMember.deleteMany({ where: { councilId: a.councilId, userId: a.userId } });
  }
  let written = 0;
  let already = 0;
  let gone = 0;
  for (const m of manifest.removedMemberships) {
    const [council, user] = await Promise.all([
      prisma.council.findUnique({ where: { id: m.councilId }, select: { id: true } }),
      prisma.user.findUnique({ where: { id: m.userId }, select: { id: true } }),
    ]);
    if (!council || !user) {
      gone++;
      continue;
    }
    const r = await prisma.councilMember.createMany({ data: [{ ...m, joinedAt: new Date(m.joinedAt) }], skipDuplicates: true });
    if (r.count) written++;
    else already++; // e.g. a seat in the adopted council, put back with the council's own members
  }
  log(
    `  council seats put back: ${written} written, ${already} already in place` +
      `${gone ? `, ${gone} skipped (council or person no longer exists)` : ''}; ` +
      `${manifest.addedMemberships.length} extra seat(s) removed`,
  );

  if (manifest.unpublishedEvents.length) {
    await restoreUnpublished(prisma, manifest);
    log('  generic events: published again');
  }

  await step('host chapters', () =>
    prisma.chapter.deleteMany({ where: { OR: [{ slug: { endsWith: SUFFIX } }, { id: { startsWith: 'design-chapter-' } }] } }),
  );

  // People: only this seed's domain (the Learning/Jobs seed's @design.icr.test people are not touched).
  const people = await prisma.user.findMany({ where: { email: { endsWith: PERSON_DOMAIN } }, select: { id: true, email: true } });
  let removedPeople = 0;
  for (const p of people) {
    try {
      await prisma.user.delete({ where: { id: p.id }, select: { id: true } });
      removedPeople++;
    } catch (e) {
      log(`  could not delete ${p.email}: ${(e as Error).message.split('\n').pop()}`);
    }
  }
  log(`  people: ${removedPeople}`);

  let unlinked = 0;
  for (const name of [...ASSETS.map((a) => a.to), ...LEGACY_FILES]) {
    const path = join(process.cwd(), 'uploads', name);
    if (existsSync(path)) {
      unlinkSync(path);
      unlinked++;
    }
  }
  log(`  files removed from uploads/: ${unlinked}`);

  await prisma.setting.deleteMany({ where: { key: MANIFEST_KEY } });
  if (!hadManifest) log('  note: no manifest was found, so nothing existing could be restored (only marked rows were removed)');
  log('removed');
}

// ---------------------------------------------------------------------------
// Run alone: `... events-councils.ts [--remove] [--isolate] [--dry-run]`
// ---------------------------------------------------------------------------

if (require.main === module) {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { PrismaClient: Client } = require('@prisma/client') as typeof import('@prisma/client');
  const prisma = new Client();
  const has = (f: string) => process.argv.includes(f);
  seedEventsCouncils(prisma, (m) => console.log(m), {
    remove: has('--remove'),
    isolate: has('--isolate'),
    dryRun: has('--dry-run'),
  })
    .catch((e) => {
      console.error(e);
      process.exitCode = 1;
    })
    .finally(() => prisma.$disconnect());
}
