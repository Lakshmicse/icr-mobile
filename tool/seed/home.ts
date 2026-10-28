/**
 * Seeds the Home feed and the profile menu of the mobile app's designs into the
 * LOCAL portal database, so the app reads them through the portal's real API.
 *
 *   cd E:\ICR\irc-portal\backend          (cwd must be the backend folder: `uploads` resolves from it)
 *   NODE_PATH=E:/ICR/irc-portal/node_modules npx ts-node --transpile-only E:/ICR/icr-mobile/tool/seed/home.ts
 *   ... same command with --remove        (deletes what this script created, restores what it changed)
 *   ... also: --dry-run                   (plans, counts, writes nothing)
 *   ... also: --keep-earlier              (leaves the earlier ad hoc "-home-demo" threads visible; see below)
 *
 * Idempotent: every row has a stable id and is brought to exactly the designed state, so a re-run puts back
 * what a hand-made like, reply, vote or save on a design thread changed, and re-bases the timestamps to
 * "now" ("2h ago", "5h ago", "10h ago", "8h ago", "42m ago" read as the design says right after a run).
 *
 * Markers (all removable): ids `design-home-*`; thread slugs ending `-home-design`; people with emails ending
 * @home-design.icr.test (the other design seeds use @design.icr.test, @events-design.icr.test and
 * @learning-jobs.icr.test: a domain of its own keeps the `--remove`s from deleting each other's people);
 * files /uploads/design-home-*.
 *
 * What is seeded
 *   Posts     the Home design's four discussions as forum threads, newest first, pinned so they lead the
 *             All Feed (the forum sorts pinned threads first, and the portal's own "Welcome" thread is pinned):
 *               Sarah Jenkins   "Implementing IoT sensors for HVAC efficiency: Best practices?" (#SUSTAINABILITY,
 *                               tags HVAC / PropTech / SmartBMS, 2h ago, 52 replies; the first reply is Arvind
 *                               Swamy's, with a nested reply, 8 more in that thread, the latest is Priya Nambiar's)
 *               David Chen      "The impact of AI on preliminary site feasibility analysis" (#REALESTATETECH, 5h ago,
 *                               one photo, "BIM Feasibility Lab")
 *               Marcus Reed     the FM software poll (#POLL, 10h ago; Bharat has voted Archibus)
 *               Elena Rostova   "Site Audit: Implementing Sustainable Net-Zero Solutions" (#SITEAUDIT, 8h ago,
 *                               five photos: the attachment and four <img> tags in the body)
 *             with reactions (LIKE / INSIGHTFUL / CELEBRATE rows), replies, reply likes, a poll with votes and the
 *             design's photos and avatars as uploads. The feed order is pinned first, then by `lastActivityAt`: the four
 *             carry an activity time up to 60 days ahead, in the design's order, so a member's reply (which sets it
 *             to "now") cannot move one out of place.
 *   Sandbox   one more unpinned discussion by Marcus Reed ("Handing BIM data over to the FM team without rekeying
 *             it": three replies, one nested, no reactions, no views) that the live tests reply to instead of a
 *             designed post. The forum sets `lastActivityAt` to now on every reply and deleting the reply does not
 *             put it back, so it is seeded as the newest unpinned thread: a reply keeps it there. The counts are the design's as far as the number of accounts
 *             allows (a person reacts or votes once): 184 reactions are reachable, the poll's 842 votes are not
 *             (one vote per account: it holds as many as there are accounts, in the design's 28 / 14 / 46 / 12 split).
 *   People    six invented, active, public members with no password (they cannot sign in): the four authors,
 *             Arvind Swamy (Brookfield Properties) and Priya Nambiar. Their headline is `User.designation`.
 *   Topics    three inactive level-2 categories ("Sustainability", "Real Estate Tech", "Site Audit") under the
 *             portal's own "ESG & Sustainability" and "Technology", so a card's topic word reads as the design's
 *             (#SUSTAINABILITY, #REALESTATETECH, #SITEAUDIT). Inactive: no picker lists them.
 *   Bharat    Bharat Buyer (buyer@icr.dev), the person the emulator is signed in as, gets what the profile menu
 *             draws: the headline "Lead Operations Manager at TechCorp" (designation and a current role),
 *             "Bengaluru, Karnataka", the banner photo, every other account as a follower and a dozen followed
 *             (Marcus and Elena among them, so only Sarah and David wear "Follow"), 42 profile views from
 *             recruiters and company admins, three discussions of his own whose views add to 1,204 post
 *             impressions, and a 3.5-hour CPD entry last year (the Events seed gives him 8.5 hours this year, so
 *             the menu's "+12 CPD" lifetime total reads as the design's and the Events board's own "8.5 / 15"
 *             year is untouched).
 *
 * What it changes in existing rows (all recorded in Setting `design-seed:home` and undone by --remove)
 *   - Bharat Buyer: `designation` and `coverImage`.
 *   - The earlier ad hoc seed's six "-home-demo" threads (the same titles, by the portal's mentors) are hidden
 *     (soft-deleted) so the feed does not repeat itself; --keep-earlier leaves them, --remove brings them back.
 *   Everything else existing is left alone. It refuses to run unless the database is on localhost.
 */
import type { Prisma, PrismaClient } from '@prisma/client';
import { copyFileSync, existsSync, mkdirSync, readFileSync, statSync, unlinkSync } from 'fs';
import { join, resolve } from 'path';

// ---------------------------------------------------------------------------
// Markers and constants
// ---------------------------------------------------------------------------

const ID = 'design-home-';
const SUFFIX = '-home-design';
const EARLIER_SUFFIX = '-home-demo';
const PERSON_DOMAIN = '@home-design.icr.test';
const MANIFEST_KEY = 'design-seed:home';
const BHARAT_EMAIL = 'buyer@icr.dev';
const POOJA_EMAIL = 'professional@icr.test';
const MIN = 60_000;
const HOUR = 60 * MIN;
const DAY = 24 * HOUR;
const DEMO_ASSETS = resolve(__dirname, '..', '..', 'assets', 'images', 'demo');
const SEED_ASSETS = resolve(__dirname, 'assets');

/** The design's profile menu: "Lead Operations Manager at TechCorp", "Bengaluru, Karnataka". */
const BHARAT = {
  designation: 'Lead Operations Manager at TechCorp',
  title: 'Lead Operations Manager',
  organisation: 'TechCorp',
  city: 'Bengaluru, Karnataka',
  cover: `/uploads/${ID}cover_town.jpg`,
  profileViews: 42,
  /** Lifetime CPD hours the menu's pill shows (the design's "+12 CPD"). */
  cpdLifetimeHours: 12,
};

/** The portal's own mentors and mentees: real names, so a reply reads as a person's. */
const REPLIER_EMAILS = [
  'mentor.vikram@icr.dev',
  'mentor.fatima@icr.dev',
  'mentor.rajesh@icr.dev',
  'mentor.sanjay@icr.dev',
  'mentor.anita@icr.dev',
  'mentor.karthik@icr.dev',
  'mentor.arjun@icr.dev',
  'mentor.deepa@icr.dev',
  'mentor.lakshmi@icr.dev',
  'mentor.priya@icr.dev',
  'mentor.tarun@icr.dev',
  'mentor.grace@icr.dev',
  'mentor.imran@icr.dev',
  'mentee.aisha@icr.dev',
  'mentee.neha@icr.dev',
  'mentee.rohan@icr.dev',
  'mentee.suresh@icr.dev',
];
/** Whom Bharat follows besides Marcus and Elena. */
const BHARAT_FOLLOWS = REPLIER_EMAILS.slice(0, 10);

// ---------------------------------------------------------------------------
// Files: assets/images/demo/<file> -> uploads/design-home-<file>
// ---------------------------------------------------------------------------

/** `base: 'seed'` files sit beside this script (`tool/seed/assets`), the rest in the app's demo images. */
const FILES: { from: string; to: string; base?: 'seed' }[] = [
  ...['sarah', 'david', 'marcus', 'elena', 'arvind'].map((n) => ({ from: `avatar_${n}.jpg`, to: `${ID}avatar_${n}.jpg` })),
  { from: 'post_control_room.jpg', to: `${ID}post_control_room.jpg` },
  { from: 'post_green_tower.jpg', to: `${ID}post_green_tower.jpg` },
  { from: 'post_rooftop_hvac.jpg', to: `${ID}post_rooftop_hvac.jpg` },
  // Three more site photos (crops of the two above) so Elena's post carries the design's "+3 photos".
  { from: 'home_site_a.jpg', to: `${ID}site_a.jpg`, base: 'seed' },
  { from: 'home_site_b.jpg', to: `${ID}site_b.jpg`, base: 'seed' },
  { from: 'home_site_c.jpg', to: `${ID}site_c.jpg`, base: 'seed' },
  { from: 'cover_town.jpg', to: `${ID}cover_town.jpg` },
];
const up = (file: string) => `/uploads/${file}`;

// ---------------------------------------------------------------------------
// The people the API has to name
// ---------------------------------------------------------------------------

type PersonKey = 'sarah' | 'david' | 'marcus' | 'elena' | 'arvind' | 'priya';

const PEOPLE: Record<PersonKey, { first: string; last: string; headline: string; avatar?: string }> = {
  sarah: { first: 'Sarah', last: 'Jenkins', headline: 'Senior Facilities Manager at Google', avatar: 'avatar_sarah.jpg' },
  david: { first: 'David', last: 'Chen', headline: 'Project Director at BuildCo', avatar: 'avatar_david.jpg' },
  marcus: { first: 'Marcus', last: 'Reed', headline: 'Lead Architect at DesignCo', avatar: 'avatar_marcus.jpg' },
  elena: { first: 'Elena', last: 'Rostova', headline: 'Civil & Sustainability Engineer', avatar: 'avatar_elena.jpg' },
  // The reply line reads "42m ago • Brookfield Properties": the organisation after "at".
  arvind: { first: 'Arvind', last: 'Swamy', headline: 'General Counsel at Brookfield Properties', avatar: 'avatar_arvind.jpg' },
  priya: { first: 'Priya', last: 'Nambiar', headline: 'Facilities Lead at Infosys' },
};
const PERSON_KEYS = Object.keys(PEOPLE) as PersonKey[];
const personId = (k: PersonKey) => `${ID}user-${k}`;
const personEmail = (k: PersonKey) => `${PEOPLE[k].first.toLowerCase()}.${PEOPLE[k].last.toLowerCase()}${PERSON_DOMAIN}`;

// ---------------------------------------------------------------------------
// Topics: the word beside the time ("#SUSTAINABILITY") is the discussion's sub-category
// ---------------------------------------------------------------------------

const TOPICS = {
  sustainability: { parent: 'SUSTAINABILITY_ESG', name: 'Sustainability' },
  realEstateTech: { parent: 'TECHNOLOGY_INNOVATION', name: 'Real Estate Tech' },
  siteAudit: { parent: 'SUSTAINABILITY_ESG', name: 'Site Audit' },
} as const;
type TopicKey = keyof typeof TOPICS;
const topicId = (k: TopicKey) => `${ID}cat-${k}`;
const topicKey = (k: TopicKey) => `HOME_DESIGN_${k.replace(/([A-Z])/g, '_$1').toUpperCase()}`;
const topicSlug = (k: TopicKey) => `home-design-${k.replace(/([A-Z])/g, '-$1').toLowerCase()}`;

// ---------------------------------------------------------------------------
// Threads
// ---------------------------------------------------------------------------

/** A person of this seed, or the email of one of the portal's own accounts. */
type Who = PersonKey | string;

interface ReplySpec {
  key: string;
  parent?: string;
  by: Who;
  /** Minutes before now. */
  ageMin: number;
  text: string;
  likes?: number;
}

interface ThreadSpec {
  key: string;
  title: string;
  /** Paragraphs; each becomes a <p>. */
  paragraphs: string[];
  /** Raw HTML appended after the paragraphs (seed-only shapes: `<img>` tags the forum's own sanitiser would strip). */
  extraHtml?: string;
  kind: 'QUESTION' | 'DISCUSSION';
  author: PersonKey | 'bharat';
  categoryKey: string;
  topic?: TopicKey;
  tags: string[];
  ageMin: number;
  pinned: boolean;
  reactions: { LIKE: number; INSIGHTFUL: number; CELEBRATE: number };
  views: number;
  photo?: { file: string; fileName: string };
  poll?: { options: { label: string; share: number }[]; bharat: string; pooja: string };
  replies: ReplySpec[];
  /**
   * A discussion the live tests may reply to. A reply makes the forum set the thread's `lastActivityAt` to now, and
   * deleting it does not set it back, so a test must never write to a designed (pinned) post: it would fall out of
   * the design's order. This one is unpinned and starts as the newest unpinned thread, so a reply to it leaves the
   * feed's order as the seed made it.
   */
  sandbox?: boolean;
}

const A_TEXT =
  'Spot on Priya. Niagara framework BACnet/IP telemetry cut vendor lock-in completely across our commercial assets.';

/** Sarah's thread: the design's first reply and its nested answer, eight more in that thread, the latest Priya's. */
const SARAH_REPLIES: ReplySpec[] = [
  { key: 'r1', by: 'arvind', ageMin: 42.2, text: A_TEXT, likes: 3 },
  // The design draws the same words again as the nested reply.
  { key: 'r2', parent: 'r1', by: 'arvind', ageMin: 41.7, text: A_TEXT, likes: 3 },
  { key: 'r3', parent: 'r2', by: 'priya', ageMin: 33, text: 'Thanks Arvind. Did you keep the legacy controllers or replace them?' },
  {
    key: 'r4',
    parent: 'r3',
    by: 'arvind',
    ageMin: 29,
    text: 'Kept them. Niagara supervises the old controllers and maps their points over BACnet/IP, so nothing had to be ripped out.',
  },
  {
    key: 'r5',
    parent: 'r2',
    by: 'mentor.vikram@icr.dev',
    ageMin: 26,
    text: 'Same approach on our retrofit. Point mapping took longer than the sensors did.',
  },
  {
    key: 'r6',
    parent: 'r1',
    by: 'mentor.rajesh@icr.dev',
    ageMin: 22,
    text: 'Ask each vendor for their BACnet PICS before you shortlist. It saves a lot of arguing later.',
  },
  {
    key: 'r7',
    parent: 'r1',
    by: 'mentor.fatima@icr.dev',
    ageMin: 18,
    text: 'And budget for sensor re-baselining. We recalibrated twice in the first year.',
  },
  {
    key: 'r8',
    parent: 'r1',
    by: 'mentor.sanjay@icr.dev',
    ageMin: 13,
    text: 'Put data ownership in the contract, not just the integration scope.',
  },
  {
    key: 'r9',
    parent: 'r1',
    by: 'mentor.karthik@icr.dev',
    ageMin: 9,
    text: 'Phase it: one AHU zone first, prove the savings, then roll out.',
  },
  // The latest reply in the thread: the reply box under it reads "Reply to Priya Nambiar...".
  {
    key: 'r10',
    parent: 'r1',
    by: 'priya',
    ageMin: 6,
    text: 'Great tips everyone. The PICS point is going straight into our RFP.',
  },
];

const SARAH_SUBSTANTIVE = [
  'We went with wireless LoRaWAN sensors on the return air path. No cabling into a 15-year-old ceiling void, and the payback was under two years.',
  'Check whether your BMS exposes BACnet/IP or only MS/TP. That decides whether you need a gateway or can integrate directly.',
  "Don't skip the commissioning data. Without a clean baseline you can't prove the peak-load saving afterwards.",
  "Vendor-neutral protocols first, dashboards second. We've been burned by a pretty UI on a closed stack.",
  'Pilot on one floor for a month. The sensor placement you plan is rarely the placement that works.',
  'Our chiller plant data was the real prize, more than the zone sensors. Start there if load management is the goal.',
  'Ask who owns the data and where it lives. Several of the cheaper vendors keep it in their own cloud.',
  'We used differential pressure and CO2 sensors to trim fan speeds at peak. Roughly 9% off the HVAC bill.',
  'Legacy BMS integration is mostly about point naming. Agree a convention before anyone installs anything.',
  'Cybersecurity matters more than people think: put the sensor network on its own VLAN.',
  'A shortlist of two or three integrators who have done your BMS brand before is worth more than any feature list.',
  'Peak-hour control needs demand forecasting, not just sensors. Ask vendors how they handle pre-cooling.',
  'Battery life is the hidden cost with wireless sensors. Get a replacement schedule in writing.',
  'We ran a six-week trial before committing. The vendors who agreed to it were the ones worth hiring.',
  'If the building has VAV boxes, start there. The control logic gives you the quickest visible win.',
  'Happy to share our specification sheet if it helps. Send me a message.',
];

const DAVID_SUBSTANTIVE = [
  "The municipal data gap is real. We now cross-check every AI output against the planning office's records before it reaches a client.",
  "Speed is the headline, but I'd still trust a junior analyst's checklist over a model on zoning.",
  'Which tools did you try? We found the results varied a lot between cities with digital land records and those without.',
  "Treat it as a screening tool. It rules sites out quickly; it shouldn't rule them in.",
  "Outdated records are only half the problem. Many of these tools can't read setback rules from scanned PDFs reliably.",
  'We pair the model with a site visit checklist. The AI narrows 40 plots to 6 and we do the rest the old way.',
  'The BIM link is interesting. Feeding massing studies back into feasibility saved us a full review cycle.',
  "Make the model show its sources. If it can't cite the record it used, don't rely on it.",
  'In our experience flood and drainage layers are the least current. Always verify those on the ground.',
  "Useful for yield studies, less so for approvals risk. The politics of a ward don't show up in the data.",
  'We keep a log of every place the tool was wrong. After three months it was a good training set for the team.',
  'Which regions were worst for you? We saw the biggest gaps in tier-2 cities.',
  'Licensing is worth reading. Some vendors reserve the right to train on the plans you upload.',
  'Combine it with satellite imagery refreshed monthly and a lot of the stale-records problem goes away.',
  'I would love to see a benchmark of these tools against a human feasibility study on the same ten plots.',
  "Good thread. We're evaluating two of these tools next quarter, so please keep posting what you find.",
];

const ELENA_SUBSTANTIVE = [
  'Great to see rooftop solar and smart climate control working together. What was the payback period?',
  'The green terraces on the tower look fantastic. How did you handle irrigation and maintenance?',
  'Net-zero retrofits live or die on the metering. Did you sub-meter by floor?',
  'How did the tenants respond to the changes? Occupant comfort is usually the hardest part.',
  'We did a similar audit last year and found that scheduling alone gave us 12% savings.',
  'Did the audit cover embodied carbon or only operational? Scope 3 is where most of our gap is.',
  'The HVAC plant on that roof looks well kept. Was it replaced or refurbished?',
  'Could you share the checklist you used for the site visit? It would help our audit team.',
  'Renewable PPAs are good, but on-site generation changes the conversation with the board.',
  'What certification are you targeting, IGBC or LEED? We found the documentation load very different.',
  'Smart climate control is only as good as the sensor calibration. Did you re-baseline after commissioning?',
  'Impressive. Which vendors supplied the building management layer?',
  'I would be interested in the energy intensity numbers before and after, in kWh per square metre.',
  'Thanks for posting the photos. It helps to see what a net-zero retrofit actually looks like on site.',
  'Did the structure need reinforcing for the rooftop equipment? We had a long delay on that.',
  'Following this one closely. We start a similar audit in January.',
];

const MARCUS_SUBSTANTIVE = [
  'We moved from Archibus to Planon last year. The migration was painful but the mobile work-order flow was worth it.',
  'TRIRIGA is powerful but needs a dedicated admin. Factor that headcount into the comparison.',
  'In-house spreadsheets still run more portfolios than anyone admits. The question is what it costs when the owner leaves.',
  'Archibus for space and lease, something lighter for maintenance. Two tools, one integration.',
  'Ask for a reference customer of your own size. The big names behave very differently at 5 sites and at 500.',
  "The poll is missing 'Facilio'. Several of our GCC peers have moved there.",
  'Whatever you pick, check the API first. Reporting into the ESG pack is where most tools fall short.',
  'Licensing per user versus per square foot changes the answer completely.',
];

const GENERIC_REPLIES = [
  'Following this thread, thanks for raising it.',
  'Really useful, thanks for sharing.',
  'Agree with the points above.',
  'Same experience on our side.',
  'This is exactly what we were discussing internally last week.',
  'Bookmarked, will report back after our trial.',
  'Interesting. Would love to hear how it turns out.',
  'Thanks all, this thread is gold.',
  '+1 to the above.',
  'Good question, looking forward to the answers.',
  'Sharing this with our facilities team.',
  'Well put.',
];
const FOLLOW_UPS = ['Thanks, that helps a lot.', 'Good point, I had not thought of that.', 'Appreciate the detail.', 'That makes sense, thank you.'];

const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const p = (text: string) => `<p>${esc(text)}</p>`;

const THREADS: ThreadSpec[] = [
  {
    key: 'sarah',
    title: 'Implementing IoT sensors for HVAC efficiency: Best practices?',
    paragraphs: [
      'We are currently looking to retrofit a 15- year-old commercial building with modern IoT sensors to better manage our HVAC load during peak hours. Has anyone successfully implemented a system that integrates smoothly with legacy BMS? Looking for recommendations on vendors that balance cost with reliability.',
    ],
    kind: 'QUESTION',
    author: 'sarah',
    categoryKey: 'SUSTAINABILITY_ESG',
    topic: 'sustainability',
    tags: ['HVAC', 'PropTech', 'SmartBMS'],
    ageMin: 122,
    pinned: true,
    reactions: { LIKE: 104, INSIGHTFUL: 50, CELEBRATE: 30 },
    views: 4210,
    replies: [],
  },
  {
    key: 'david',
    title: 'The impact of AI on preliminary site feasibility analysis',
    paragraphs: [
      "I've been experimenting with several new AI tools aimed at automating preliminary site feasibility studies. While the speed is impressive, I'm finding the data heavily relies on outdated municipal records in certain regions.",
    ],
    kind: 'DISCUSSION',
    author: 'david',
    categoryKey: 'TECHNOLOGY_INNOVATION',
    topic: 'realEstateTech',
    tags: [],
    ageMin: 302,
    pinned: true,
    reactions: { LIKE: 104, INSIGHTFUL: 50, CELEBRATE: 30 },
    views: 3180,
    photo: { file: `${ID}post_control_room.jpg`, fileName: 'BIM Feasibility Lab.jpg' },
    replies: [],
  },
  {
    key: 'marcus',
    title: 'What is your primary FM Software in 2026?',
    paragraphs: ['Select the ecosystem your team relies on for facility workflows.'],
    kind: 'DISCUSSION',
    author: 'marcus',
    categoryKey: 'TECHNOLOGY_INNOVATION',
    tags: [],
    ageMin: 602,
    pinned: true,
    reactions: { LIKE: 60, INSIGHTFUL: 24, CELEBRATE: 12 },
    views: 2640,
    poll: {
      options: [
        { label: 'IBM TRIRIGA', share: 28 },
        { label: 'Planon', share: 14 },
        { label: 'Archibus', share: 46 },
        { label: 'Other / Custom In-House', share: 12 },
      ],
      bharat: 'Archibus',
      pooja: 'Planon',
    },
    replies: [],
  },
  {
    key: 'elena',
    title: 'Site Audit: Implementing Sustainable Net-Zero Solutions',
    paragraphs: [
      "Just wrapped up an incredible site visit. It's fascinating to see how the integration of smart climate control systems and renewable energy sources can transform an existing structure into a beacon of sustainability.",
    ],
    // The forum keeps one attachment per discussion (the tower, below); the other four photos travel as <img>
    // tags in the body, which the website's sanitiser strips and the app reads for the "+3 photos" tile.
    extraHtml: [
      `<img src="${up(`${ID}post_rooftop_hvac.jpg`)}" alt="Rooftop HVAC plant">`,
      `<img src="${up(`${ID}site_a.jpg`)}" alt="The tower's upper terraces">`,
      `<img src="${up(`${ID}site_b.jpg`)}" alt="The rooftop array">`,
      `<img src="${up(`${ID}site_c.jpg`)}" alt="The tower's lower floors">`,
    ].join(''),
    kind: 'DISCUSSION',
    author: 'elena',
    categoryKey: 'SUSTAINABILITY_ESG',
    topic: 'siteAudit',
    tags: [],
    ageMin: 482,
    pinned: true,
    reactions: { LIKE: 104, INSIGHTFUL: 50, CELEBRATE: 30 },
    views: 2905,
    photo: { file: `${ID}post_green_tower.jpg`, fileName: 'Green tower.jpg' },
    replies: [],
  },
  // --- Bharat's own discussions: their views are the menu's "Post Impressions" (640 + 410 + 154 = 1,204) ---
  {
    key: 'bharat-1',
    title: 'Shortlisting a BMS retrofit partner for a 12-site campus portfolio',
    paragraphs: [
      'We are about to retrofit the BMS across twelve campuses, most of them on different legacy controllers. Before we go to RFP I would like to hear how others scored integrators.',
      'Did you weight past work on your BMS brand above price, and how long did the pilot run before you committed?',
    ],
    kind: 'QUESTION',
    author: 'bharat',
    categoryKey: 'TECHNOLOGY_INNOVATION',
    tags: ['BMS', 'Retrofit'],
    ageMin: 3 * 24 * 60,
    pinned: false,
    reactions: { LIKE: 9, INSIGHTFUL: 4, CELEBRATE: 0 },
    views: 640,
    replies: [
      { key: 'b1', by: 'mentor.vikram@icr.dev', ageMin: 3 * 24 * 60 - 90, text: 'Weight past work on your exact BMS brand highest. Price is the smallest part of the lifetime cost.' },
      { key: 'b2', by: 'mentor.karthik@icr.dev', ageMin: 3 * 24 * 60 - 200, text: 'A four to six week pilot on the worst-behaved site tells you more than any scorecard.' },
      { key: 'b3', by: 'mentor.sanjay@icr.dev', ageMin: 2 * 24 * 60 + 600, text: 'Score the integrator on documentation and handover, not just commissioning.' },
    ],
  },
  {
    key: 'bharat-2',
    title: 'What does a fair AMC escalation clause look like across multiple cities?',
    paragraphs: [
      'Our AMCs run on city-by-city contracts and the escalation terms are all over the place. Is there a sensible way to standardise a clause without losing the local wage differences?',
    ],
    kind: 'QUESTION',
    author: 'bharat',
    categoryKey: 'PROCUREMENT_SUPPLY_CHAIN',
    tags: ['AMC', 'Contracts'],
    ageMin: 5 * 24 * 60,
    pinned: false,
    reactions: { LIKE: 6, INSIGHTFUL: 2, CELEBRATE: 0 },
    views: 410,
    replies: [
      { key: 'b1', by: 'mentor.sanjay@icr.dev', ageMin: 5 * 24 * 60 - 120, text: 'Index it to a published wage notification plus a fixed cap, and the city differences take care of themselves.' },
      { key: 'b2', by: 'mentor.rajesh@icr.dev', ageMin: 4 * 24 * 60 + 700, text: 'Cap the annual movement and review it at a fixed date, rather than letting it float.' },
    ],
  },
  {
    key: 'bharat-3',
    title: 'Lessons from our first Scope 3 supplier data round',
    paragraphs: [
      'We asked forty suppliers for activity data this quarter and got usable numbers from nine. Writing down what worked and what did not in case it helps someone starting the same exercise.',
    ],
    kind: 'DISCUSSION',
    author: 'bharat',
    categoryKey: 'SUSTAINABILITY_ESG',
    tags: ['Scope3', 'ESG'],
    ageMin: 9 * 24 * 60,
    pinned: false,
    reactions: { LIKE: 4, INSIGHTFUL: 1, CELEBRATE: 0 },
    views: 154,
    replies: [
      { key: 'b1', by: 'mentor.fatima@icr.dev', ageMin: 9 * 24 * 60 - 300, text: 'Ask for activity data in the contract schedule, with a template. Free-text requests get free-text answers.' },
      { key: 'b2', by: 'mentee.neha@icr.dev', ageMin: 8 * 24 * 60 + 400, text: 'Thanks for posting the response rate. That alone is useful to know before we start.' },
    ],
  },
  // --- The live tests' sandbox: they reply to, like and take back replies on this one, never on a designed post ---
  // By Marcus, whom Bharat follows (so no "Follow" link), with no reactions and no views (so it adds no "reactions" or
  // "views" text beside the designed cards), a nested answer, and a newest reply by someone other than Pooja.
  {
    key: 'sandbox',
    title: 'Handing BIM data over to the FM team without rekeying it',
    paragraphs: [
      'Our design model is handed over as a pile of IFC files and a spreadsheet, and the FM team ends up rekeying the asset register by hand. Has anyone got a handover that loads straight into the CAFM?',
      'What did you ask the contractor to deliver, and who owned the data after practical completion?',
    ],
    kind: 'QUESTION',
    author: 'marcus',
    categoryKey: 'TECHNOLOGY_INNOVATION',
    tags: [],
    ageMin: 20 * 60,
    pinned: false,
    sandbox: true,
    reactions: { LIKE: 0, INSIGHTFUL: 0, CELEBRATE: 0 },
    views: 0,
    replies: [
      { key: 's1', by: 'arvind', ageMin: 18 * 60, text: 'Put COBie in the contract as a deliverable with a named owner, and check it at each stage rather than at the end.', likes: 2 },
      { key: 's2', parent: 's1', by: 'priya', ageMin: 17 * 60, text: 'Agreed. We also asked for the asset tags to match what is on the plant, not the model.' },
      { key: 's3', by: 'priya', ageMin: 6 * 60, text: 'Whoever runs the CAFM should own the data from practical completion. Ours did, and the rekeying stopped.' },
    ],
  },
];

// ---------------------------------------------------------------------------
// Manifest: what existed before the seed changed it, kept in `Setting`
// ---------------------------------------------------------------------------

interface Manifest {
  version: 1;
  /** Bharat's columns before the seed (null: the column was empty). */
  bharat?: { id: string; designation: string | null; coverImage: string | null };
  /** The earlier ad hoc threads the seed hid, with their `updatedAt` so --remove restores them exactly. */
  hidden: { id: string; updatedAt: string }[];
}
const emptyManifest = (): Manifest => ({ version: 1, hidden: [] });

async function loadManifest(prisma: PrismaClient): Promise<Manifest> {
  const row = await prisma.setting.findUnique({ where: { key: MANIFEST_KEY }, select: { value: true } });
  return row ? { ...emptyManifest(), ...(row.value as unknown as Manifest) } : emptyManifest();
}

async function saveManifest(prisma: PrismaClient, m: Manifest): Promise<void> {
  const value = m as unknown as Prisma.InputJsonValue;
  await prisma.setting.upsert({ where: { key: MANIFEST_KEY }, update: { value }, create: { key: MANIFEST_KEY, value } });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** A stable number from a string. */
function hash(s: string): number {
  let h = 2166136261;
  for (const c of s) {
    h ^= c.charCodeAt(0);
    h = Math.imul(h, 16777619) >>> 0;
  }
  return h >>> 0;
}

/** The items in an order that depends on `salt` only. */
function shuffled<T extends { id: string }>(items: T[], salt: string): T[] {
  return items
    .map((item) => [hash(`${salt}:${item.id}`), item] as const)
    .sort((a, b) => a[0] - b[0])
    .map(([, item]) => item);
}

/** `bold` is a plain slug of a title, for the thread slug. */
function slugify(input: string): string {
  return input
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 70)
    .replace(/-+$/g, '');
}

/** DATABASE_URL from the environment, else from `.env` in the cwd. Never logged: it holds the password. */
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
  const rows = (await prisma.$queryRawUnsafe(`select current_database() as db, inet_server_addr()::text as addr`)) as {
    db: string;
    addr: string | null;
  }[];
  const addr = String(rows[0]?.addr ?? '').split('/')[0];
  const loopback = addr === '' || addr === '127.0.0.1' || addr === '::1';
  if (!loopback || !hostOk) throw new Error('Refusing to run: the database is not on localhost.');
  log(`database "${rows[0]?.db}" on ${addr || 'a local socket'}: local${url ? ' (DATABASE_URL host checked)' : ''}`);
  if (!existsSync(join(process.cwd(), 'prisma', 'schema.prisma'))) {
    throw new Error(`Run this from E:\\ICR\\irc-portal\\backend (cwd is ${process.cwd()}): uploads resolve from it.`);
  }
}

function copyFiles(log: (m: string) => void): void {
  const uploads = join(process.cwd(), 'uploads');
  if (!existsSync(uploads)) mkdirSync(uploads, { recursive: true });
  for (const f of FILES) copyFileSync(join(f.base === 'seed' ? SEED_ASSETS : DEMO_ASSETS, f.from), join(uploads, f.to));
  log(`  files: ${FILES.length} copied to uploads/`);
}

const fileSize = (name: string) => statSync(join(process.cwd(), 'uploads', name)).size;

// ---------------------------------------------------------------------------
// Seed
// ---------------------------------------------------------------------------

export interface SeedOptions {
  /** Delete what the seed created and restore what it changed. */
  remove?: boolean;
  /** Plan only: read, count, log; write nothing. */
  dryRun?: boolean;
  /** Leave the earlier ad hoc "-home-demo" threads visible. */
  keepEarlier?: boolean;
  /** For tests. */
  now?: Date;
}

export async function seedHome(prisma: PrismaClient, log: (m: string) => void, opts: SeedOptions = {}): Promise<void> {
  await assertLocalDatabase(prisma, log);
  if (opts.remove) {
    await removeAll(prisma, log);
    return;
  }
  await seedAll(prisma, log, opts);
}

type Account = { id: string; email: string };

/** One reply, resolved to rows. */
interface ReplyRow {
  id: string;
  threadId: string;
  parentId: string | null;
  authorId: string;
  bodyHtml: string;
  createdAt: Date;
  likeCount: number;
  score: number;
}

async function seedAll(prisma: PrismaClient, log: (m: string) => void, opts: SeedOptions): Promise<void> {
  const now = opts.now ?? new Date();
  const dry = !!opts.dryRun;
  const at = (minutesAgo: number) => new Date(now.getTime() - Math.round(minutesAgo * MIN));

  // --- The people there are --------------------------------------------------------------------------------------
  // The portal's own accounts (@icr.dev, @icr.test): they react, vote and reply. A person on any other domain is a
  // persona another design seed made; reactions from them would drift when that seed is removed.
  const pool: Account[] = await prisma.user.findMany({
    where: {
      isActive: true,
      OR: [{ email: { endsWith: '@icr.dev', mode: 'insensitive' } }, { email: { endsWith: '@icr.test', mode: 'insensitive' } }],
    },
    orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    select: { id: true, email: true },
  });
  const bharat = pool.find((u) => u.email.toLowerCase() === BHARAT_EMAIL);
  const pooja = pool.find((u) => u.email.toLowerCase() === POOJA_EMAIL);
  if (!bharat) throw new Error(`${BHARAT_EMAIL} not found: run the portal's db:seed first.`);
  if (!pooja) log(`  warning: ${POOJA_EMAIL} not found: the poll has no vote for the second persona`);
  const personaIds = new Set([bharat.id, pooja?.id].filter(Boolean) as string[]);
  log(`  people: ${pool.length} portal accounts`);

  if (dry) {
    log('  dry run: nothing is written');
    for (const t of THREADS) {
      log(`    thread ${slugify(t.title)}${SUFFIX}: ${t.reactions.LIKE + t.reactions.INSIGHTFUL + t.reactions.CELEBRATE} reactions, ${t.ageMin} min old`);
    }
    return;
  }

  copyFiles(log);
  const manifest = await loadManifest(prisma);

  // --- Topics -----------------------------------------------------------------------------------------------------
  const parents = new Map(
    (
      await prisma.category.findMany({
        where: { key: { in: [...new Set(Object.values(TOPICS).map((t) => t.parent))] } },
        select: { id: true, key: true },
      })
    ).map((c) => [c.key as string, c.id]),
  );
  for (const k of Object.keys(TOPICS) as TopicKey[]) {
    const parentId = parents.get(TOPICS[k].parent);
    if (!parentId) throw new Error(`Category ${TOPICS[k].parent} not found: run the portal's db:seed:masters first.`);
    const data = {
      name: TOPICS[k].name,
      slug: topicSlug(k),
      key: topicKey(k),
      active: false, // no picker lists it; the thread cards still read its name
      sortOrder: 900,
      level: 2,
      parentId,
    };
    await prisma.category.upsert({ where: { id: topicId(k) }, update: data, create: { id: topicId(k), ...data } });
  }
  log(`  topics: ${Object.keys(TOPICS).length} inactive sub-categories`);

  // --- The invented members ----------------------------------------------------------------------------------------
  for (const key of PERSON_KEYS) {
    const person = PEOPLE[key];
    const data = {
      firstName: person.first,
      lastName: person.last,
      designation: person.headline,
      avatarUrl: person.avatar ? up(`${ID}${person.avatar}`) : null,
      isActive: true,
      profilePublic: true,
    };
    await prisma.user.upsert({
      where: { email: personEmail(key) },
      update: data,
      create: { id: personId(key), email: personEmail(key), passwordHash: null, ...data },
      select: { id: true },
    });
  }
  const mine = new Map<PersonKey, string>();
  for (const key of PERSON_KEYS) {
    mine.set(key, (await prisma.user.findUniqueOrThrow({ where: { email: personEmail(key) }, select: { id: true } })).id);
  }
  const mineAccounts: Account[] = PERSON_KEYS.map((k) => ({ id: mine.get(k)!, email: personEmail(k) }));
  log(`  people: ${mineAccounts.length} invented members (active, public, no password)`);

  // Everyone who may react or vote: the portal's accounts and the invented members.
  const electorate: Account[] = [...pool, ...mineAccounts];
  // Everyone who follows Bharat: every active account, whichever seed made it (a follow is a row with no counter).
  const everyone = await prisma.user.findMany({ where: { isActive: true }, select: { id: true, email: true } });

  // Repliers with real names: the portal's mentors and mentees that exist here.
  const byEmail = new Map(pool.map((u) => [u.email.toLowerCase(), u]));
  const known = new Set(electorate.map((u) => u.id));
  const resolveWho = (who: Who, fallbackIndex: number): string => {
    if ((PERSON_KEYS as string[]).includes(who)) return mine.get(who as PersonKey)!;
    if (known.has(who)) return who; // already an account id (the filler's repliers)
    const found = byEmail.get(who.toLowerCase());
    if (found) return found.id;
    const spare = pool.filter((u) => !personaIds.has(u.id));
    return spare[fallbackIndex % spare.length].id;
  };
  const replierAccounts = REPLIER_EMAILS.map((e) => byEmail.get(e))
    .filter(Boolean)
    .map((u) => u!.id);
  const replierPool: string[] = [...replierAccounts, ...mineAccounts.map((a) => a.id)];

  // --- The earlier ad hoc threads -----------------------------------------------------------------------------------
  const earlier = await prisma.forumThread.findMany({
    where: { slug: { endsWith: EARLIER_SUFFIX }, deletedAt: null },
    select: { id: true, updatedAt: true },
  });
  if (!opts.keepEarlier) {
    for (const t of earlier) {
      if (!manifest.hidden.some((h) => h.id === t.id)) manifest.hidden.push({ id: t.id, updatedAt: t.updatedAt.toISOString() });
    }
    await saveManifest(prisma, manifest); // before the hide: never lose one unrecorded
    if (earlier.length) {
      await prisma.forumThread.updateMany({ where: { id: { in: earlier.map((t) => t.id) } }, data: { deletedAt: now } });
    }
    log(`  earlier threads: ${earlier.length} hidden (${manifest.hidden.length} in all)`);
  } else if (manifest.hidden.length) {
    await restoreHidden(prisma, manifest);
    log('  earlier threads: visible again (--keep-earlier)');
  }

  // --- Threads, replies, votes ---------------------------------------------------------------------------------------
  // The seed's own threads are made again from scratch each run: their replies, votes, polls and any state a person
  // added by hand go with the old rows, and the designed state comes back.
  await prisma.forumThread.deleteMany({ where: { id: { startsWith: `${ID}thread-` } } });

  const slugs = new Set<string>();
  const summary: string[] = [];
  // The design's order on the screen, which is not the order of their ages.
  const DESIGN_ORDER = ['sarah', 'david', 'marcus', 'elena'];
  for (const t of THREADS) {
    const threadId = `${ID}thread-${t.key}`;
    const authorId = t.author === 'bharat' ? bharat.id : mine.get(t.author)!;
    const created = at(t.ageMin);
    const slug = `${slugify(t.title)}${t.author === 'bharat' ? `-${t.key}` : ''}${SUFFIX}`;
    if (slugs.has(slug)) throw new Error(`duplicate slug ${slug}`);
    slugs.add(slug);

    // Replies: the explicit ones, then filler in the thread's own voice up to the design's count.
    const replySpecs = buildReplies(t, replierPool, authorId);
    const repliedAt = replySpecs.length ? new Date(Math.max(...replySpecs.map((r) => at(r.ageMin).getTime()))) : created;
    // The forum lists pinned threads by last activity, and any reply (a test's, a member's) bumps that to "now": so the
    // four designed posts carry an activity time ahead of any "now" for the next two months, in the design's order, and
    // keep leading the feed ahead of the portal's own pinned "Welcome" thread. Nothing shows this time on a card.
    const lastActivity = t.pinned
      ? new Date(now.getTime() + (60 - Math.max(0, DESIGN_ORDER.indexOf(t.key))) * 24 * 60 * 60 * 1000)
      : t.sandbox
        ? now // the newest unpinned thread: a test's reply makes it "now" again and moves nothing
        : repliedAt;

    // Reactions: each account once, the design's mix as far as the accounts reach.
    const voters = shuffled(
      electorate.filter((u) => u.id !== authorId && !personaIds.has(u.id)),
      `thread:${t.key}`,
    );
    const want = t.reactions;
    const total = want.LIKE + want.INSIGHTFUL + want.CELEBRATE;
    const factor = total > voters.length ? voters.length / total : 1;
    const counts = {
      LIKE: Math.floor(want.LIKE * factor),
      INSIGHTFUL: Math.floor(want.INSIGHTFUL * factor),
      CELEBRATE: Math.floor(want.CELEBRATE * factor),
    };
    const reacted = counts.LIKE + counts.INSIGHTFUL + counts.CELEBRATE;

    const body =
      t.paragraphs.map(p).join('') +
      (t.extraHtml ?? '');
    await prisma.forumThread.create({
      data: {
        id: threadId,
        authorId,
        topicCategoryId: (await categoryId(prisma, t.categoryKey))!,
        topicSubcategoryId: t.topic ? topicId(t.topic) : null,
        title: t.title,
        slug,
        bodyHtml: body,
        kind: t.kind,
        tags: t.tags,
        status: 'OPEN',
        moderation: 'APPROVED',
        pinned: t.pinned,
        uploadId: t.photo?.file ?? null,
        fileName: t.photo?.fileName ?? null,
        fileSize: t.photo ? fileSize(t.photo.file) : null,
        viewCount: t.views,
        replyCount: replySpecs.length,
        score: reacted,
        likeCount: reacted,
        lastActivityAt: lastActivity,
        createdAt: created,
      },
    });

    // Thread reactions.
    let cursor = 0;
    const voteRows: Prisma.ForumThreadVoteCreateManyInput[] = [];
    for (const kind of ['LIKE', 'INSIGHTFUL', 'CELEBRATE'] as const) {
      for (const voter of voters.slice(cursor, cursor + counts[kind])) {
        voteRows.push({
          threadId,
          userId: voter.id,
          value: 1,
          reaction: kind,
          createdAt: new Date(created.getTime() + (hash(`${t.key}:${voter.id}`) % Math.max(1, now.getTime() - created.getTime()))),
        });
      }
      cursor += counts[kind];
    }
    if (voteRows.length) await prisma.forumThreadVote.createMany({ data: voteRows });

    // Poll.
    if (t.poll) await seedPoll(prisma, t, threadId, authorId, electorate, personaIds, bharat.id, pooja?.id, created);

    // Replies.
    const rows = replyRows(t, threadId, replySpecs, resolveWho, at, now);
    if (rows.length) {
      const key = (r: ReplyRow) => r.id;
      await prisma.forumReply.createMany({
        data: rows.map((r) => ({
          id: key(r),
          threadId: r.threadId,
          parentId: r.parentId,
          authorId: r.authorId,
          bodyHtml: r.bodyHtml,
          moderation: 'APPROVED' as const,
          likeCount: r.likeCount,
          score: r.score,
          createdAt: r.createdAt,
        })),
      });
      const replyVotes: Prisma.ForumReplyVoteCreateManyInput[] = [];
      for (const r of rows) {
        const liked = shuffled(
          electorate.filter((u) => u.id !== r.authorId && !personaIds.has(u.id)),
          `reply:${r.id}`,
        ).slice(0, r.likeCount);
        for (const v of liked) {
          replyVotes.push({ replyId: r.id, userId: v.id, value: 1, reaction: 'LIKE', createdAt: new Date(r.createdAt.getTime() + 2 * MIN) });
        }
      }
      if (replyVotes.length) await prisma.forumReplyVote.createMany({ data: replyVotes });
    }
    summary.push(`${t.key}: ${reacted} reactions, ${replySpecs.length} replies${t.poll ? ', a poll' : ''}`);
  }
  log(`  threads: ${THREADS.length} (${summary.join('; ')})`);

  // --- Bharat: the profile menu --------------------------------------------------------------------------------------
  // Bharat follows Marcus and Elena (so only Sarah and David wear "Follow") and the portal's first ten mentors.
  const followedIds = [
    mine.get('marcus')!,
    mine.get('elena')!,
    ...BHARAT_FOLLOWS.map((e) => byEmail.get(e)?.id).filter(Boolean),
  ] as string[];
  await seedBharat(prisma, log, manifest, bharat.id, everyone, followedIds, now);

  await saveManifest(prisma, manifest);
  log('done');
}

const categoryCache = new Map<string, string>();
async function categoryId(prisma: PrismaClient, key: string): Promise<string | undefined> {
  if (!categoryCache.has(key)) {
    const row = await prisma.category.findFirst({ where: { key }, select: { id: true } });
    if (!row) throw new Error(`Category ${key} not found: run the portal's db:seed:masters first.`);
    categoryCache.set(key, row.id);
  }
  return categoryCache.get(key);
}

/** The replies a thread carries: the design's own, then filler up to the count the card shows. */
function buildReplies(t: ThreadSpec, replierPool: string[], authorId: string): ReplySpec[] {
  const explicit = t.replies.length ? t.replies : t.key === 'sarah' ? SARAH_REPLIES : [];
  const target =
    t.key === 'sarah' || t.key === 'david' || t.key === 'elena' ? 52 : t.key === 'marcus' ? 12 : explicit.length;
  const substantive =
    t.key === 'sarah'
      ? SARAH_SUBSTANTIVE
      : t.key === 'david'
        ? DAVID_SUBSTANTIVE
        : t.key === 'elena'
          ? ELENA_SUBSTANTIVE
          : t.key === 'marcus'
            ? MARCUS_SUBSTANTIVE
            : [];
  const out = [...explicit];
  const need = target - out.length;
  if (need <= 0) return out;

  // Filler fits between the thread's birth and the newest explicit reply (or a fixed floor, for the rest).
  const newestExplicit = explicit.length ? Math.max(...explicit.map((r) => r.ageMin)) : 0;
  const floor = t.key === 'sarah' ? 47 : t.key === 'david' ? 35 : t.key === 'marcus' ? 80 : t.key === 'elena' ? 125 : newestExplicit;
  const ceiling = t.ageMin - 3;
  const authors = replierPool.filter((id) => id !== authorId);
  let author = hash(t.key) % authors.length;
  const roots: string[] = [];
  for (let i = 0; i < need; i++) {
    const ageMin = ceiling - ((ceiling - floor) * (i + 1)) / need;
    // Rotate through the repliers, never the thread's own author, except for the thank-you follow-ups.
    const key = `f${i + 1}`;
    const byIndex = () => {
      author = (author + 1) % authors.length;
      return authors[author];
    };
    if (i < substantive.length) {
      out.push({ key, by: byIndex(), ageMin, text: substantive[i], likes: i % 7 === 3 ? 2 : i % 5 === 1 ? 1 : 0 });
      roots.push(key);
    } else if ((i - substantive.length) % 3 === 2 && roots.length) {
      // A thank-you from the author under the previous root.
      out.push({
        key,
        parent: roots[roots.length - 1],
        by: t.author === 'bharat' ? byIndex() : t.author,
        ageMin: Math.max(floor, ageMin - 4),
        text: FOLLOW_UPS[i % FOLLOW_UPS.length],
      });
    } else {
      out.push({ key, by: byIndex(), ageMin, text: GENERIC_REPLIES[(i + hash(t.key)) % GENERIC_REPLIES.length], likes: i % 9 === 4 ? 1 : 0 });
      roots.push(key);
    }
  }
  return out;
}

function replyRows(
  t: ThreadSpec,
  threadId: string,
  specs: ReplySpec[],
  resolveWho: (who: Who, i: number) => string,
  at: (m: number) => Date,
  now: Date,
): ReplyRow[] {
  const idOf = (key: string) => `${ID}reply-${t.key}-${key}`;
  // A parent is always made before its child: an earlier-aged (older) reply goes first.
  const ordered = specs.slice().sort((a, b) => b.ageMin - a.ageMin);
  const known = new Set<string>();
  const rows: ReplyRow[] = [];
  for (const [i, s] of ordered.entries()) {
    if (s.parent && !known.has(s.parent)) throw new Error(`reply ${t.key}/${s.key}: its parent ${s.parent} is not older`);
    known.add(s.key);
    rows.push({
      id: idOf(s.key),
      threadId,
      parentId: s.parent ? idOf(s.parent) : null,
      authorId: resolveWho(s.by, i),
      bodyHtml: p(s.text),
      createdAt: new Date(Math.min(at(s.ageMin).getTime(), now.getTime())),
      likeCount: s.likes ?? 0,
      score: s.likes ?? 0,
    });
  }
  return rows;
}

async function seedPoll(
  prisma: PrismaClient,
  t: ThreadSpec,
  threadId: string,
  authorId: string,
  electorate: Account[],
  personaIds: Set<string>,
  bharatId: string,
  poojaId: string | undefined,
  created: Date,
): Promise<void> {
  const poll = t.poll!;
  // Everyone but the author votes once, the two personas included: Bharat has voted already (the design's "Your
  // vote"), and Pooja has, so a test can move her vote and put it back (the API has no way to take a vote away).
  const voters = shuffled(
    electorate.filter((u) => u.id !== authorId),
    `poll:${t.key}`,
  );
  const n = voters.length;
  const raw = poll.options.map((o) => (o.share * n) / 100);
  const counts = raw.map((r) => Math.floor(r));
  let left = n - counts.reduce((a, b) => a + b, 0);
  for (const i of raw.map((r, i) => i).sort((a, b) => raw[b] - Math.floor(raw[b]) - (raw[a] - Math.floor(raw[a])))) {
    if (left <= 0) break;
    counts[i]++;
    left--;
  }
  const pollId = `${ID}poll-${t.key}`;
  const optionIds = poll.options.map((_, i) => `${ID}poll-${t.key}-opt${i + 1}`);
  await prisma.forumPoll.create({
    data: {
      id: pollId,
      threadId,
      totalVotes: n,
      createdAt: created,
      options: {
        create: poll.options.map((o, i) => ({ id: optionIds[i], label: o.label, order: i, voteCount: counts[i] })),
      },
    },
  });

  // Who picked what: the shuffled voters in blocks, then the personas moved to the option they hold by design.
  const choice = new Map<string, number>();
  let cursor = 0;
  counts.forEach((c, i) => {
    for (const v of voters.slice(cursor, cursor + c)) choice.set(v.id, i);
    cursor += c;
  });
  const swap = (personaId: string | undefined, label: string) => {
    if (!personaId || !choice.has(personaId)) return;
    const want = poll.options.findIndex((o) => o.label === label);
    const have = choice.get(personaId)!;
    if (have === want) return;
    const other = [...choice].find(([id, i]) => i === want && !personaIds.has(id));
    if (other) choice.set(other[0], have);
    choice.set(personaId, want);
  };
  swap(bharatId, poll.bharat);
  swap(poojaId, poll.pooja);
  await prisma.forumPollVote.createMany({
    data: voters.map((v) => ({
      pollId,
      userId: v.id,
      optionId: optionIds[choice.get(v.id)!],
      createdAt: new Date(created.getTime() + (hash(`poll:${v.id}`) % Math.max(1, Date.now() - created.getTime()))),
    })),
  });
}

async function seedBharat(
  prisma: PrismaClient,
  log: (m: string) => void,
  manifest: Manifest,
  bharatId: string,
  everyone: Account[],
  followedIds: string[],
  now: Date,
): Promise<void> {
  // What he had before: once, never our own values.
  const row = await prisma.user.findUniqueOrThrow({ where: { id: bharatId }, select: { designation: true, coverImage: true } });
  if (!manifest.bharat) {
    manifest.bharat = {
      id: bharatId,
      designation: row.designation === BHARAT.designation ? null : row.designation,
      coverImage: row.coverImage === BHARAT.cover ? null : row.coverImage,
    };
    await saveManifest(prisma, manifest); // before the change
  }
  await prisma.user.update({
    where: { id: bharatId },
    data: { designation: BHARAT.designation, coverImage: BHARAT.cover },
    select: { id: true },
  });

  // His current role: the menu's headline and city come from it.
  const expId = `${ID}exp-bharat`;
  const exp = {
    userId: bharatId,
    title: BHARAT.title,
    organisation: BHARAT.organisation,
    city: BHARAT.city,
    startYear: 2019,
    startMonth: 4,
    isCurrent: true,
    sortOrder: 0,
  };
  await prisma.userExperience.upsert({ where: { id: expId }, update: exp, create: { id: expId, ...exp } });

  // Connections: every other account follows him; he follows Marcus, Elena and ten of the portal's mentors.
  await prisma.memberFollow.deleteMany({ where: { id: { startsWith: `${ID}follow-` } } });
  const existingIn = new Set((await prisma.memberFollow.findMany({ where: { followingId: bharatId }, select: { followerId: true } })).map((f) => f.followerId));
  const followers = everyone.filter((u) => u.id !== bharatId && !existingIn.has(u.id));
  const existingOut = new Set((await prisma.memberFollow.findMany({ where: { followerId: bharatId }, select: { followingId: true } })).map((f) => f.followingId));
  const followed = followedIds.filter((id) => !existingOut.has(id)).map((id) => ({ id }));
  const spread = (i: number) => new Date(now.getTime() - (1 + (hash(`follow:${i}`) % 300)) * DAY);
  await prisma.memberFollow.createMany({
    data: [
      ...followers.map((u, i) => ({ id: `${ID}follow-in-${i}`, followerId: u.id, followingId: bharatId, createdAt: spread(i) })),
      ...followed.map((u, i) => ({ id: `${ID}follow-out-${i}`, followerId: bharatId, followingId: u.id, createdAt: spread(1000 + i) })),
    ],
    skipDuplicates: true,
  });
  const connections =
    (await prisma.memberFollow.count({ where: { followingId: bharatId } })) +
    (await prisma.memberFollow.count({ where: { followerId: bharatId } }));

  // Profile views: recruiters and company admins first, then anyone, one receipt each (the pair is unique).
  await prisma.profileView.deleteMany({ where: { id: { startsWith: `${ID}pv-` } } });
  const already = new Set((await prisma.profileView.findMany({ where: { candidateId: bharatId }, select: { viewerId: true } })).map((v) => v.viewerId));
  const missing = Math.max(0, BHARAT.profileViews - already.size);
  const viewers = await prisma.user.findMany({
    where: { isActive: true, id: { not: bharatId, notIn: [...already] } },
    select: { id: true, role: true },
  });
  const rank = (role: string) => (role === 'RECRUITER' ? 0 : role === 'HIRING_MANAGER' ? 1 : role === 'COMPANY_ADMIN' ? 2 : 3);
  const chosen = viewers
    .map((v) => [rank(v.role as string), hash(`view:${v.id}`), v] as const)
    .sort((a, b) => a[0] - b[0] || a[1] - b[1])
    .slice(0, missing)
    .map(([, , v]) => v);
  await prisma.profileView.createMany({
    data: chosen.map((v, i) => {
      const seen = new Date(now.getTime() - (1 + (hash(`seen:${v.id}`) % 28)) * DAY);
      return { id: `${ID}pv-${i}`, candidateId: bharatId, viewerId: v.id, createdAt: seen, updatedAt: seen };
    }),
  });

  // His own discussions (their views are the post impressions) are made with the threads above.

  // CPD: last year's hours, so the menu's lifetime total reaches the design's 12 with the Events seed's 8.5 this year.
  const year = now.getUTCFullYear() - 1;
  await prisma.cpdEntry.deleteMany({ where: { userId: bharatId, sourceRefId: { startsWith: `${ID}cpd-` } } });
  const ledger = await prisma.cpdEntry.aggregate({ where: { userId: bharatId }, _sum: { hours: true } });
  const hours = Math.max(0, Number((BHARAT.cpdLifetimeHours - (ledger._sum.hours ?? 0)).toFixed(2)));
  if (hours > 0) {
    await prisma.cpdEntry.create({
      data: {
        userId: bharatId,
        source: 'COURSE',
        sourceRefId: `${ID}cpd-1`,
        hours,
        description: 'Course · Facility Management Foundations',
        awardedAt: new Date(Date.UTC(year, 10, 18, 9, 0)),
      },
    });
  }
  const impressions = await prisma.forumThread.aggregate({ where: { authorId: bharatId, deletedAt: null }, _sum: { viewCount: true } });
  log(
    `  bharat: headline and cover set, ${connections} connections, ${already.size + chosen.length} profile views, ` +
      `${impressions._sum.viewCount ?? 0} post impressions, ${hours} CPD hours added for ${year}`,
  );
}

async function restoreHidden(prisma: PrismaClient, manifest: Manifest): Promise<void> {
  for (const h of manifest.hidden) {
    await prisma.forumThread.updateMany({ where: { id: h.id }, data: { deletedAt: null, updatedAt: new Date(h.updatedAt) } });
  }
  manifest.hidden = [];
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

  // Threads first (replies, votes and polls go with them): the people who wrote them cannot be deleted before.
  await step('threads', () =>
    prisma.forumThread.deleteMany({ where: { OR: [{ id: { startsWith: ID } }, { slug: { endsWith: SUFFIX } }] } }),
  );
  if (manifest.hidden.length) {
    await restoreHidden(prisma, manifest);
    log('  earlier threads: visible again');
  }
  await step('topics', () => prisma.category.deleteMany({ where: { id: { startsWith: `${ID}cat-` } } }));
  await step('follows', () => prisma.memberFollow.deleteMany({ where: { id: { startsWith: `${ID}follow-` } } }));
  await step('profile views', () => prisma.profileView.deleteMany({ where: { id: { startsWith: `${ID}pv-` } } }));
  await step('cpd entries', () => prisma.cpdEntry.deleteMany({ where: { sourceRefId: { startsWith: `${ID}cpd-` } } }));
  await step('experience', () => prisma.userExperience.deleteMany({ where: { id: { startsWith: `${ID}exp-` } } }));

  if (manifest.bharat) {
    await prisma.user.updateMany({
      where: { id: manifest.bharat.id },
      data: { designation: manifest.bharat.designation, coverImage: manifest.bharat.coverImage },
    });
    log('  bharat: designation and cover put back');
  }

  // People: only this seed's domain.
  const people = await prisma.user.findMany({ where: { email: { endsWith: PERSON_DOMAIN } }, select: { id: true, email: true } });
  let removed = 0;
  for (const person of people) {
    try {
      await prisma.user.delete({ where: { id: person.id }, select: { id: true } });
      removed++;
    } catch (e) {
      log(`  could not delete ${person.email}: ${(e as Error).message.split('\n').pop()}`);
    }
  }
  log(`  people: ${removed}`);

  let unlinked = 0;
  for (const f of FILES) {
    const path = join(process.cwd(), 'uploads', f.to);
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
// Run alone: `... home.ts [--remove] [--dry-run] [--keep-earlier]`
// ---------------------------------------------------------------------------

if (require.main === module) {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { PrismaClient: Client } = require('@prisma/client') as typeof import('@prisma/client');
  const prisma = new Client();
  const has = (f: string) => process.argv.includes(f);
  seedHome(prisma, (m) => console.log(m), {
    remove: has('--remove'),
    dryRun: has('--dry-run'),
    keepEarlier: has('--keep-earlier'),
  })
    .catch((e) => {
      console.error(e);
      process.exitCode = 1;
    })
    .finally(() => prisma.$disconnect());
}
