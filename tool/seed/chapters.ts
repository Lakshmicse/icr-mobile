/**
 * Seeds the Regional Chapters content of the mobile app (Bengaluru, Mumbai, Delhi NCR and Hyderabad, the four
 * chapters of the Discover, profile-menu and Councils designs) into the LOCAL portal database, so the app
 * reads them through the portal's real API with believable people, pictures, past and upcoming meetups and
 * files that open.
 *
 *   cd E:\ICR\irc-portal\backend          (cwd must be the backend folder: `uploads` resolves from it)
 *   NODE_PATH=E:/ICR/irc-portal/node_modules npx ts-node --transpile-only E:/ICR/icr-mobile/tool/seed/chapters.ts
 *   ... same command with --remove        (deletes what this script created, restores what it changed)
 *   ... also: --dry-run
 *
 * Idempotent: every row has a stable id and is upserted; the dates move with the day the script runs
 * (upcoming ones stay ahead, past ones stay behind), and the attendee lists are brought to exactly the
 * designed set. Run it any time after the portal's own `db:seed:association` (which makes the chapters).
 *
 * Markers (all removable): people `design-chu-*` (emails `@chapters-design.icr.test`, shared with library.ts),
 * events `design-chev-*` (slugs ending `-chapters-design`), announcements `design-chann-*`, files
 * `/uploads/design-chapters-*`. The chapter rows, their leads and their original seats are the portal's own.
 *
 * What is seeded, per chapter
 *   Members       8 to 11 people (title and company on the roster, a portrait each) added as MEMBERs; the
 *                 existing committee and members are untouched.
 *   Events        two PAST ones (the page's Past tab); and upcoming: a free meetup in Bengaluru, Mumbai and
 *                 Hyderabad (RSVP works), a TICKETED workshop in Mumbai (the app offers "Get ticket"), a FULL
 *                 one in Delhi NCR (capacity 12, twelve going: "Join waitlist") and an INVITE-ONLY roundtable
 *                 in Hyderabad (on the chapter's page, refused to anyone not invited).
 *   Updates       two dated dispatches each, beside the portal's pinned welcome.
 *
 * What it changes in existing rows (all recorded in Setting `design-seed:chapters` and undone by --remove)
 *   - the four chapters: a cover photo, a local photo gallery in place of the external picsum links (they do
 *     not load offline), and a contact address.
 *   - their existing resources: each is pointed at a real file (a whitepaper PDF, a deck, a scorecard
 *     workbook) instead of example.com.
 *
 * Bharat Buyer's and Pooja Professional's chapter seats and RSVPs are never touched.
 * It refuses to run unless the database is on localhost.
 */
import type { PrismaClient } from '@prisma/client';
import { existsSync, statSync } from 'fs';
import { join } from 'path';
import {
  DAY,
  DEMO_IMAGES,
  SEED_ASSETS,
  assertLocalDatabase,
  copyToUploads,
  hasManifest,
  istAt,
  loadManifest,
  removeUpload,
  saveManifest,
  sizeLabel,
  spread,
  up,
} from './seed-common';
import { PERSON_KEYS, PersonKey, ensurePeople, personId, removePeopleIfUnused } from './seed-people';

const MANIFEST_KEY = 'design-seed:chapters';
const LIBRARY_KEY = 'design-seed:library';
const SLUGS = ['bengaluru', 'mumbai', 'delhi-ncr', 'hyderabad'] as const;
type Slug = (typeof SLUGS)[number];

// ---------------------------------------------------------------------------
// What each chapter gets
// ---------------------------------------------------------------------------

interface ChapterSpec {
  name: string;
  contact: string;
  cover: string;
  gallery: string[];
  members: PersonKey[];
}

/** Images are the app's own demo photos (assets/images/demo) and this folder's `home_site_*`. */
const CHAPTERS: Record<Slug, ChapterSpec> = {
  bengaluru: {
    name: 'Bengaluru',
    contact: 'bengaluru@icr.network',
    cover: 'events/card_gcc.jpg',
    gallery: ['post_control_room.jpg', 'seed:home_site_a.jpg', 'events/card_bms.jpg', 'post_rooftop_hvac.jpg', 'events/card_ai.jpg'],
    members: ['meera', 'ananya', 'divya', 'karthik', 'vivek', 'rohan', 'sandeep', 'kavita', 'abhishek'],
  },
  mumbai: {
    name: 'Mumbai',
    contact: 'mumbai@icr.network',
    cover: 'post_green_tower.jpg',
    gallery: ['events/card_summit.jpg', 'seed:home_site_b.jpg', 'post_control_room.jpg', 'events/sheet_hero.jpg'],
    members: ['shreya', 'lakshmi', 'nisha', 'rohan', 'meera', 'gaurav', 'imran', 'pallavi', 'vivek', 'divya'],
  },
  'delhi-ncr': {
    name: 'Delhi NCR',
    contact: 'delhi-ncr@icr.network',
    cover: 'seed:home_site_c.jpg',
    gallery: ['post_rooftop_hvac.jpg', 'events/card_gcc.jpg', 'seed:home_site_a.jpg', 'post_green_tower.jpg'],
    members: ['sandeep', 'gaurav', 'pallavi', 'nisha', 'harish', 'lakshmi', 'karthik', 'ananya', 'rohan', 'shreya', 'imran'],
  },
  hyderabad: {
    name: 'Hyderabad',
    contact: 'hyderabad@icr.network',
    cover: 'events/card_bms.jpg',
    gallery: ['events/card_ai.jpg', 'seed:home_site_b.jpg', 'events/spotlight.jpg', 'post_control_room.jpg'],
    members: ['kavita', 'imran', 'harish', 'abhishek', 'divya', 'karthik', 'meera', 'vivek'],
  },
};

const assetPath = (ref: string) => (ref.startsWith('seed:') ? join(SEED_ASSETS, ref.slice(5)) : join(DEMO_IMAGES, ref));
const coverFile = (s: Slug) => `design-chapters-cover-${s}.jpg`;
const galleryFile = (s: Slug, i: number) => `design-chapters-gallery-${s}-${i + 1}.jpg`;

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

type EventKind = 'CHAPTER_MEET' | 'WEBINAR' | 'CONFERENCE' | 'WORKSHOP' | 'MASTERCLASS' | 'ROUNDTABLE';

interface EventSpec {
  key: string;
  chapter: Slug;
  title: string;
  kind: EventKind;
  body: string;
  location: string;
  /** Days from the day the script runs (negative: past). */
  days: number;
  hours?: number;
  capacity?: number;
  price?: number;
  inviteOnly?: boolean;
  going: number;
}

const EVENTS: EventSpec[] = [
  // Past: the page's Past tab.
  { key: 'blr-vendor-slas', chapter: 'bengaluru', title: 'Q3 Meetup: Vendor SLAs That Hold', kind: 'CHAPTER_MEET', location: 'Indiranagar, Bengaluru', days: -18, capacity: 80, going: 12, body: 'Members compared service-level clauses that held up in practice and the ones that never did, with a template scorecard shared afterwards.' },
  { key: 'blr-net-zero-tour', chapter: 'bengaluru', title: 'Site Tour: Net-Zero Campus in Whitefield', kind: 'WORKSHOP', location: 'Whitefield, Bengaluru', days: -70, capacity: 40, going: 9, body: 'A walk through a net-zero campus: metering, on-site solar, STP reuse and the operations team behind them.' },
  { key: 'mum-facade-walk', chapter: 'mumbai', title: 'High-rise Façade Inspection Walk', kind: 'WORKSHOP', location: 'BKC, Mumbai', days: -18, capacity: 30, going: 10, body: 'Rope-access inspection methods, what a good façade maintenance plan holds, and how to price it.' },
  { key: 'mum-bfsi-forum', chapter: 'mumbai', title: 'BFSI Facilities Forum: Resilience and Continuity', kind: 'ROUNDTABLE', location: 'Nariman Point, Mumbai', days: -70, capacity: 35, going: 11, body: 'Branch and back-office facilities leaders on continuity drills, vendor surge capacity and incident reporting.' },
  { key: 'del-air-roundtable', chapter: 'delhi-ncr', title: 'Winter Air Quality and HVAC Roundtable', kind: 'ROUNDTABLE', location: 'Gurugram', days: -18, capacity: 40, going: 10, body: 'Filtration upgrades, CO2-based ventilation control and what the winter season did to energy budgets.' },
  { key: 'del-open-house', chapter: 'delhi-ncr', title: 'Corporate Park Open House, Noida', kind: 'CHAPTER_MEET', location: 'Noida', days: -70, capacity: 60, going: 8, body: 'An open house at a multi-tenant corporate park: shuttle, security and landscape services at campus scale.' },
  { key: 'hyd-data-clinic', chapter: 'hyderabad', title: 'Smart Building Data Clinic', kind: 'WORKSHOP', location: 'HITEC City, Hyderabad', days: -18, capacity: 30, going: 8, body: 'Bring a messy BMS export: members clean it up and agree what a useful dashboard asks for.' },
  { key: 'hyd-gcc-breakfast', chapter: 'hyderabad', title: 'GCC Facilities Leaders Breakfast', kind: 'CHAPTER_MEET', location: 'Gachibowli, Hyderabad', days: -70, capacity: 50, going: 7, body: 'Breakfast and peer exchange for facilities heads at global capability centres.' },
  // Upcoming.
  { key: 'blr-fm-clinic', chapter: 'bengaluru', title: 'Campus FM Clinic: Service Levels in Practice', kind: 'CHAPTER_MEET', location: 'Koramangala, Bengaluru', days: 16, hours: 3, capacity: 50, going: 7, body: 'Bring a contract clause and a question. Peers and two vendors walk through how service levels are measured and enforced.' },
  { key: 'mum-mixer', chapter: 'mumbai', title: 'Mumbai Chapter Mixer: Facilities Leaders Evening', kind: 'CHAPTER_MEET', location: 'BKC, Mumbai', days: 12, hours: 3, capacity: 60, going: 9, body: 'An evening for facilities, procurement and real-estate leaders in Mumbai: short talks, then open networking.' },
  { key: 'mum-lease-workshop', chapter: 'mumbai', title: 'Lease Audit Workshop (hands-on)', kind: 'WORKSHOP', location: 'Lower Parel, Mumbai', days: 26, hours: 5, capacity: 40, price: 150000, going: 5, body: 'A hands-on workshop on auditing a commercial lease: rent, escalation, CAM and restoration, with a worked example. Ticketed.' },
  { key: 'del-site-tour', chapter: 'delhi-ncr', title: 'Net-zero Campus Site Tour, Gurugram', kind: 'WORKSHOP', location: 'Gurugram', days: 9, hours: 4, capacity: 12, going: 12, body: 'A small-group site tour of a net-zero campus. Places are limited to twelve; the waitlist moves up as people cancel.' },
  { key: 'hyd-site-walk', chapter: 'hyderabad', title: 'Hyderabad Smart Building Site Walk', kind: 'CHAPTER_MEET', location: 'HITEC City, Hyderabad', days: 19, hours: 3, capacity: 40, going: 6, body: 'A walk through a smart building: sensors, BMS integration and the control room, led by its operations team.' },
  { key: 'hyd-invite-roundtable', chapter: 'hyderabad', title: 'GCC Leaders Roundtable (invitation only)', kind: 'ROUNDTABLE', location: 'Gachibowli, Hyderabad', days: 33, hours: 3, capacity: 25, inviteOnly: true, going: 0, body: 'A closed-door roundtable for heads of facilities at global capability centres. By invitation of the committee.' },
];

const eventId = (key: string) => `design-chev-${key}`;
const eventSlug = (key: string) => `${key}-chapters-design`;

// ---------------------------------------------------------------------------
// Announcements
// ---------------------------------------------------------------------------

const ANNOUNCEMENTS = (c: ChapterSpec): { n: number; days: number; title: string; body: string }[] => [
  {
    n: 1,
    days: -4,
    title: `${c.name} committee nominations open for 2027`,
    body: `Nominations for the 2027 ${c.name} chapter committee are open until the end of next month. If you would like to serve as president, secretary or programme lead, write to the committee or apply through Get Involved.`,
  },
  {
    n: 2,
    days: -11,
    title: `Site visit sign-ups: a ${c.name} campus tour`,
    body: `We are arranging a campus tour for members in ${c.name}. Tell the committee which kind of site you would like to see (a net-zero campus, a data centre or a multi-tenant tower) and we will plan around the most requests.`,
  },
];

// ---------------------------------------------------------------------------
// Manifest
// ---------------------------------------------------------------------------

interface Manifest {
  chapters: Record<string, { coverUrl: string | null; galleryUrls: string[]; contactEmail: string | null }>;
  resources: Record<string, { title: string; url: string; sizeLabel: string | null }>;
  members: { chapterId: string; userId: string }[];
}

const emptyManifest = (): Manifest => ({ chapters: {}, resources: {}, members: [] });

export interface SeedOptions {
  remove?: boolean;
  dryRun?: boolean;
  /** For tests. */
  now?: Date;
}

export async function seedChapters(prisma: PrismaClient, log: (m: string) => void, opts: SeedOptions = {}): Promise<void> {
  await assertLocalDatabase(prisma, log);
  if (opts.remove) return removeAll(prisma, log);
  return seedAll(prisma, log, opts);
}

async function seedAll(prisma: PrismaClient, log: (m: string) => void, opts: SeedOptions): Promise<void> {
  const now = opts.now ?? new Date();
  const rows = await prisma.chapter.findMany({ where: { slug: { in: [...SLUGS] }, deletedAt: null } });
  const chapter = new Map(rows.map((r) => [r.slug, r]));
  const missing = SLUGS.filter((s) => !chapter.has(s));
  if (missing.length) throw new Error(`Chapters not found: ${missing.join(', ')}. Run the portal's db:seed:association first.`);
  if (opts.dryRun) {
    log('  dry run: nothing is written');
    for (const e of EVENTS) log(`    event ${eventSlug(e.key)}: ${e.days >= 0 ? '+' : ''}${e.days} days, ${e.going} going`);
    for (const s of SLUGS) log(`    chapter ${s}: ${CHAPTERS[s].members.length} members added`);
    return;
  }
  const manifest = await loadManifest(prisma, MANIFEST_KEY, emptyManifest);

  // --- Files ------------------------------------------------------------------
  let files = 0;
  for (const s of SLUGS) {
    const spec = CHAPTERS[s];
    copyToUploads(assetPath(spec.cover), coverFile(s));
    spec.gallery.forEach((g, i) => copyToUploads(assetPath(g), galleryFile(s, i)));
    files += 1 + spec.gallery.length;
    for (const [from, to] of [
      [`chapters/workplace-benchmark-${s}.pdf`, `design-chapters-workplace-benchmark-${s}.pdf`],
      [`chapters/chapter-meetup-deck-${s}.pptx`, `design-chapters-chapter-meetup-deck-${s}.pptx`],
    ]) {
      copyToUploads(join(SEED_ASSETS, from), to);
      files++;
    }
  }
  copyToUploads(join(SEED_ASSETS, 'chapters', 'vendor-sla-scorecard-template.xlsx'), 'design-chapters-vendor-sla-scorecard-template.xlsx');
  files++;
  log(`  files: ${files} copied to uploads/`);

  // --- People and their seats -----------------------------------------------------
  const people = await ensurePeople(prisma, log);

  // --- The four chapters ----------------------------------------------------------
  for (const s of SLUGS) {
    const c = chapter.get(s)!;
    const spec = CHAPTERS[s];
    if (!manifest.chapters[c.id]) {
      manifest.chapters[c.id] = { coverUrl: c.coverUrl, galleryUrls: c.galleryUrls, contactEmail: c.contactEmail };
    }
    await prisma.chapter.update({
      where: { id: c.id },
      data: {
        coverUrl: up(coverFile(s)),
        galleryUrls: spec.gallery.map((_, i) => up(galleryFile(s, i))),
        contactEmail: spec.contact,
      },
      select: { id: true },
    });
  }
  await saveManifest(prisma, MANIFEST_KEY, manifest);
  log('  chapters: cover, gallery and contact address set');

  // --- Existing resources: point them at real files ---------------------------------------
  // Resources: the first of each kind goes to a real file; a recording stays a link, to a real site.
  const resourceTarget = (slug: Slug, kind: string): { title?: string; url: string; size: string | null } | null => {
    const city = CHAPTERS[slug].name;
    switch (kind) {
      case 'WHITEPAPER':
        return { title: `${city} Workplace Experience Benchmark 2026`, url: up(`design-chapters-workplace-benchmark-${slug}.pdf`), size: sizeLabel(fileSize(`chapters/workplace-benchmark-${slug}.pdf`)) };
      case 'PRESENTATION':
        return { title: `${city} Chapter Meetup: Deck`, url: up(`design-chapters-chapter-meetup-deck-${slug}.pptx`), size: sizeLabel(fileSize(`chapters/chapter-meetup-deck-${slug}.pptx`)) };
      case 'TEMPLATE':
        return { url: up('design-chapters-vendor-sla-scorecard-template.xlsx'), size: sizeLabel(fileSize('chapters/vendor-sla-scorecard-template.xlsx')) };
      case 'RECORDING':
        return { url: 'https://www.youtube.com/', size: null };
      default:
        return null;
    }
  };
  let repointed = 0;
  for (const s of SLUGS) {
    const seen = new Set<string>();
    const list = await prisma.chapterResource.findMany({ where: { chapterId: chapter.get(s)!.id }, orderBy: { createdAt: 'asc' } });
    for (const r of list) {
      if (seen.has(r.kind)) continue;
      seen.add(r.kind);
      const t = resourceTarget(s, r.kind);
      if (!t) continue;
      manifest.resources[r.id] ??= { title: r.title, url: r.url, sizeLabel: r.sizeLabel };
      await prisma.chapterResource.update({
        where: { id: r.id },
        data: { title: t.title ?? manifest.resources[r.id].title, url: t.url, ...(t.size ? { sizeLabel: t.size } : {}) },
        select: { id: true },
      });
      repointed++;
    }
  }
  log(`  resources: ${repointed} pointed at real files`);

  // --- Members ---------------------------------------------------------------------------
  for (const s of SLUGS) {
    const c = chapter.get(s)!;
    for (const key of CHAPTERS[s].members) {
      const userId = people.get(key)!;
      const had = await prisma.chapterMember.findUnique({ where: { chapterId_userId: { chapterId: c.id, userId } }, select: { userId: true } });
      if (!had) {
        await prisma.chapterMember.create({ data: { chapterId: c.id, userId, role: 'MEMBER' as never, joinedAt: new Date(now.getTime() - (20 + (spread(key + s) % 200)) * DAY) } });
      }
      if (!manifest.members.some((m) => m.chapterId === c.id && m.userId === userId)) manifest.members.push({ chapterId: c.id, userId });
    }
  }
  log(`  members: ${manifest.members.length} seats on the four chapters (the portal's own members and committee untouched)`);

  // --- Announcements -----------------------------------------------------------------------
  let announcements = 0;
  for (const s of SLUGS) {
    const c = chapter.get(s)!;
    for (const a of ANNOUNCEMENTS(CHAPTERS[s])) {
      const id = `design-chann-${s}-${a.n}`;
      const data = { chapterId: c.id, title: a.title, body: a.body, pinned: false, createdAt: new Date(now.getTime() + a.days * DAY) };
      await prisma.chapterAnnouncement.upsert({ where: { id }, update: data, create: { id, ...data }, select: { id: true } });
      announcements++;
    }
  }

  // --- Events -----------------------------------------------------------------------------------
  const pool = PERSON_KEYS;
  let attendees = 0;
  for (const e of EVENTS) {
    const c = chapter.get(e.chapter)!;
    const id = eventId(e.key);
    const startsAt = istAt(now, e.days, 11, 0);
    const data = {
      title: e.title,
      slug: eventSlug(e.key),
      description: `<p>${e.body}</p>`,
      location: e.location,
      kind: e.kind as never,
      chapterId: c.id,
      capacity: e.capacity ?? null,
      priceAmount: e.price ?? null,
      inviteOnly: e.inviteOnly ?? false,
      published: true,
      deletedAt: null,
      startsAt,
      endsAt: new Date(startsAt.getTime() + (e.hours ?? 3) * 3_600_000),
    };
    await prisma.event.upsert({ where: { id }, update: data, create: { id, ...data }, select: { id: true } });
    // The attendee list is exactly the designed one: people rotate through the sixteen from a place chosen by the key.
    const start = spread(e.key) % pool.length;
    const going = Array.from({ length: Math.min(e.going, pool.length) }, (_, i) => personId(pool[(start + i) % pool.length]));
    await prisma.eventAttendee.deleteMany({ where: { eventId: id, userId: { notIn: going } } });
    for (const userId of going) {
      await prisma.eventAttendee.upsert({
        where: { eventId_userId: { eventId: id, userId } },
        update: { status: 'GOING' as never },
        create: { eventId: id, userId, status: 'GOING' as never },
        select: { userId: true },
      });
    }
    attendees += going.length;
  }
  log(`  events: ${EVENTS.length} (${EVENTS.filter((e) => e.days < 0).length} past), ${attendees} attendees; announcements: ${announcements}`);
  await saveManifest(prisma, MANIFEST_KEY, manifest);
  log('done');
}

function fileSize(rel: string): number {
  const path = join(SEED_ASSETS, rel);
  if (!existsSync(path)) throw new Error(`Missing seed file: ${path}`);
  return statSync(path).size;
}

async function removeAll(prisma: PrismaClient, log: (m: string) => void): Promise<void> {
  const hadManifest = await hasManifest(prisma, MANIFEST_KEY);
  const manifest = await loadManifest(prisma, MANIFEST_KEY, emptyManifest);
  const step = async (label: string, fn: () => Promise<{ count: number } | unknown>) => {
    const r = (await fn()) as { count?: number } | undefined;
    log(`  ${label}${typeof r?.count === 'number' ? `: ${r.count}` : ''}`);
  };

  await step('events (their attendees go with them)', () => prisma.event.deleteMany({ where: { id: { startsWith: 'design-chev-' } } }));
  await step('announcements', () => prisma.chapterAnnouncement.deleteMany({ where: { id: { startsWith: 'design-chann-' } } }));
  let seats = 0;
  for (const m of manifest.members) {
    const r = await prisma.chapterMember.deleteMany({ where: { chapterId: m.chapterId, userId: m.userId, role: 'MEMBER' as never } });
    seats += r.count;
  }
  log(`  member seats: ${seats}`);

  for (const [id, o] of Object.entries(manifest.resources)) {
    await prisma.chapterResource.updateMany({ where: { id }, data: { title: o.title, url: o.url, sizeLabel: o.sizeLabel } });
  }
  for (const [id, o] of Object.entries(manifest.chapters)) {
    await prisma.chapter.updateMany({ where: { id }, data: { coverUrl: o.coverUrl, galleryUrls: o.galleryUrls, contactEmail: o.contactEmail } });
  }
  log(`  restored: ${Object.keys(manifest.chapters).length} chapters, ${Object.keys(manifest.resources).length} resources`);

  let unlinked = 0;
  for (const s of SLUGS) {
    const names = [coverFile(s), ...CHAPTERS[s].gallery.map((_, i) => galleryFile(s, i)), `design-chapters-workplace-benchmark-${s}.pdf`, `design-chapters-chapter-meetup-deck-${s}.pptx`];
    for (const n of names) if (removeUpload(n)) unlinked++;
  }
  if (removeUpload('design-chapters-vendor-sla-scorecard-template.xlsx')) unlinked++;
  log(`  files removed from uploads/: ${unlinked}`);

  await removePeopleIfUnused(prisma, log, [LIBRARY_KEY]);
  await prisma.setting.deleteMany({ where: { key: MANIFEST_KEY } });
  if (!hadManifest) log('  note: no manifest was found, so nothing existing could be restored (only marked rows were removed)');
  log('removed');
}

if (require.main === module) {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { PrismaClient: Client } = require('@prisma/client') as typeof import('@prisma/client');
  const prisma = new Client();
  const has = (f: string) => process.argv.includes(f);
  seedChapters(prisma, (m) => console.log(m), { remove: has('--remove'), dryRun: has('--dry-run') })
    .catch((e) => {
      console.error(e);
      process.exitCode = 1;
    })
    .finally(() => prisma.$disconnect());
}
