/**
 * Seeds what the app's Forums tab and a discussion's page need beyond the Home design's four posts (`home.ts`),
 * into the LOCAL portal database, so each state of those screens can be seen and used on the emulator.
 *
 *   cd E:\ICR\irc-portal\backend          (cwd must be the backend folder: `uploads` resolves from it)
 *   NODE_PATH=E:/ICR/irc-portal/node_modules npx ts-node --transpile-only E:/ICR/icr-mobile/tool/seed/forums.ts
 *   ... same command with --remove        (deletes what this script created, restores what it changed)
 *   ... also: --dry-run                   (plans, counts, writes nothing)
 *
 * Run it AFTER `home.ts` (it uses that script's people and its Home design threads stay as they are). Idempotent:
 * its own threads are made again from scratch each run, so a reply, a vote or a save made by hand on one of them goes
 * with the old row and the seeded state comes back.
 *
 * Markers (all removable): ids `design-forums-*`; thread slugs ending `-forums-design`; the file
 * /uploads/design-forums-hvac-spec.pdf.
 *
 * What is seeded (every thread is unpinned, so the Home feed's order, which leads with the four designed posts, is
 * untouched; each carries the ages shown, relative to the run)
 *   amc        a Procurement question with no reply: the Unanswered view, and "Be the first to share..." on its page
 *   answered   a question with three answers, one accepted: the "Answered" chip, the accepted answer first and tinted
 *   locked     a discussion that is LOCKED, two replies: its notice, and a reply box that says why it takes none
 *   spec       a discussion with a PDF attached ("HVAC retrofit spec.pdf"): the file tile
 *   rich       a discussion written in the website's editor (heading, bold, italic, a link, bullets, a numbered
 *              list, a quote): the body drawn with its shape, and "this post has formatting" on edit
 *   long       a discussion with 130 replies, 40 branches with answers under some: "Show more replies" (the app
 *              reads 100 a page), and a reply link that has to read page two to find its reply
 *   closedpoll a poll on a LOCKED discussion with votes: "Closed", and an option that takes no vote
 *   bharat-q   a question BHARAT asked (the emulator's person) with three answers: he can accept one, edit and delete
 *   pending    a discussion of Bharat's still waiting for a moderator: only he sees it (My posts), with its banner
 *   Saves: Bharat has saved "answered" and "rich"; Pooja has saved "spec" (the Saved view reads differently by person).
 *   Reactions and reply likes come from the portal's own accounts, as in home.ts.
 *
 * What it changes in existing rows (recorded in Setting `design-seed:forums`, undone by --remove)
 *   - Arvind Swamy (home.ts person): `designation` becomes the Reply design's "VP Sustainability at Brookfield
 *     Properties" so his reply's chip reads as the design's (home.ts writes "General Counsel at ..."; run order:
 *     home.ts, then this).
 * It refuses to run unless the database is on localhost.
 */
import type { Prisma, PrismaClient } from '@prisma/client';
import { existsSync, readFileSync, statSync, unlinkSync, writeFileSync, mkdirSync } from 'fs';
import { join } from 'path';

const ID = 'design-forums-';
const SUFFIX = '-forums-design';
const MANIFEST_KEY = 'design-seed:forums';
const HOME_ID = 'design-home-';
const BHARAT_EMAIL = 'buyer@icr.dev';
const POOJA_EMAIL = 'professional@icr.test';
const MIN = 60_000;
const PDF_FILE = `${ID}hvac-spec.pdf`;
const ARVIND_HEADLINE = 'VP Sustainability at Brookfield Properties';

interface Manifest {
  version: number;
  arvind?: { id: string; before: string | null };
}

type Who = 'sarah' | 'david' | 'marcus' | 'elena' | 'arvind' | 'priya' | 'bharat' | 'pooja' | string;

interface ReplySpec {
  key: string;
  parent?: string;
  by: Who;
  ageMin: number;
  text: string;
  likes?: number;
  accepted?: boolean;
}

interface ThreadSpec {
  key: string;
  title: string;
  /** Raw HTML (the forum stores sanitised HTML). */
  html: string;
  kind: 'QUESTION' | 'DISCUSSION';
  author: Who;
  categoryKey: string;
  tags: string[];
  ageMin: number;
  status?: 'OPEN' | 'LOCKED' | 'ARCHIVED';
  moderation?: 'APPROVED' | 'PENDING';
  views: number;
  reactions: number;
  replies: ReplySpec[];
  file?: { file: string; fileName: string };
  poll?: { options: { label: string; votes: number }[] };
}

const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const p = (s: string) => `<p>${esc(s)}</p>`;

const RICH_HTML =
  '<h2>What we measured</h2>' +
  '<p>Over twelve weeks we logged <strong>chiller kW per tonne</strong>, <em>return-air CO2</em> and the BMS set-points on ' +
  'two campuses. The full notes are on <a href="https://example.com/net-zero-notes">our wiki</a>.</p>' +
  '<ul><li>Pre-cooling before the 9 am ramp cut peak demand by 11%</li><li>Re-baselining sensors twice a year paid for itself</li>' +
  '<li>One campus never reached its target: the controls were fighting the schedule</li></ul>' +
  '<h3>What we would do again</h3>' +
  '<ol><li>Sub-meter by floor before anything else</li><li>Agree point names in writing</li><li>Trial for six weeks</li></ol>' +
  '<blockquote><p>The model is only as good as the sensor under it.</p></blockquote>' +
  '<p>Questions welcome, especially from anyone running a different BMS brand.</p>';

const THREADS: ThreadSpec[] = [
  {
    key: 'amc',
    title: 'Which AMC escalation clause survives multiple cities?',
    html: p('Our AMCs run on city-by-city contracts and the escalation terms are all over the place.') +
      p('Is there a sensible way to standardise a clause without losing the local wage differences?'),
    kind: 'QUESTION',
    author: 'mentor.rajesh@icr.dev',
    categoryKey: 'PROCUREMENT_SUPPLY_CHAIN',
    tags: ['amc', 'contracts'],
    ageMin: 26 * 60,
    views: 410,
    reactions: 4,
    replies: [],
  },
  {
    key: 'answered',
    title: 'How do we map legacy BACnet points into a new supervisor without re-commissioning?',
    html: p('We are moving a 15 year old campus onto a supervisor layer. The controllers stay.') +
      p('What did you do about point naming, and how long did the mapping take?'),
    kind: 'QUESTION',
    author: 'priya',
    categoryKey: 'TECHNOLOGY_INNOVATION',
    tags: ['bms', 'bacnet'],
    ageMin: 3 * 24 * 60,
    views: 640,
    reactions: 9,
    replies: [
      {
        key: 'a1',
        by: 'arvind',
        ageMin: 3 * 24 * 60 - 90,
        text: 'Agree the naming convention first, then map by device, not by point. We did 4,000 points in two weeks that way.',
        likes: 3,
        accepted: true,
      },
      { key: 'a2', by: 'mentor.vikram@icr.dev', ageMin: 3 * 24 * 60 - 140, text: 'Ask the supervisor vendor for a BACnet PICS per device type before you start.' },
      { key: 'a3', parent: 'a1', by: 'priya', ageMin: 3 * 24 * 60 - 200, text: 'That is what I needed. Thank you: marking this as the answer.' },
    ],
  },
  {
    key: 'locked',
    title: 'Archive: lessons from the 2025 chiller plant tender',
    html: p('Closing this thread for new replies. The tender is awarded and the lessons are collected in the document library.'),
    kind: 'DISCUSSION',
    author: 'marcus',
    categoryKey: 'TECHNOLOGY_INNOVATION',
    tags: ['tender'],
    ageMin: 9 * 24 * 60,
    status: 'LOCKED',
    views: 220,
    reactions: 2,
    replies: [
      { key: 'l1', by: 'mentor.sanjay@icr.dev', ageMin: 9 * 24 * 60 - 60, text: 'Useful summary. The scoring weights were the part I would copy.' },
      { key: 'l2', by: 'marcus', ageMin: 9 * 24 * 60 - 120, text: 'Thanks. Locking it now so the final notes stay in one place.' },
    ],
  },
  {
    key: 'spec',
    title: 'Our HVAC retrofit specification: feedback welcome',
    html: p('We have attached the specification we are sending to bidders for a 12 site HVAC retrofit.') +
      p('Please tell me what a vendor could read two ways.'),
    kind: 'DISCUSSION',
    author: 'sarah',
    categoryKey: 'TECHNOLOGY_INNOVATION',
    tags: ['hvac', 'specification'],
    ageMin: 40 * 60,
    views: 180,
    reactions: 6,
    file: { file: PDF_FILE, fileName: 'HVAC retrofit spec.pdf' },
    replies: [{ key: 's1', by: 'mentor.karthik@icr.dev', ageMin: 38 * 60, text: 'Section 4 leaves the commissioning data open. Say who owns it.' }],
  },
  {
    key: 'rich',
    title: 'Net-zero retrofit: twelve weeks of data from two campuses',
    html: RICH_HTML,
    kind: 'DISCUSSION',
    author: 'elena',
    categoryKey: 'SUSTAINABILITY_ESG',
    tags: ['esg', 'net-zero'],
    ageMin: 5 * 24 * 60,
    views: 520,
    reactions: 14,
    replies: [
      { key: 'r1', by: 'arvind', ageMin: 5 * 24 * 60 - 200, text: 'The sub-metering point is the one most teams skip. Good to see it first.', likes: 2 },
      { key: 'r2', by: 'mentor.fatima@icr.dev', ageMin: 5 * 24 * 60 - 300, text: 'Which BMS was the campus that never reached target running?' },
    ],
  },
  {
    key: 'long',
    title: 'What would you put in a BMS handover pack?',
    html: p('We are writing the handover checklist for new buildings. What do you insist on receiving, and in what format?'),
    kind: 'DISCUSSION',
    author: 'david',
    categoryKey: 'FACILITY_MANAGEMENT',
    tags: ['handover', 'bms'],
    ageMin: 6 * 24 * 60,
    views: 1900,
    reactions: 18,
    replies: [], // built below: 130
  },
  {
    key: 'closedpoll',
    title: 'Which BMS vendor did you shortlist last year?',
    html: p('Closed now: the shortlist is final. Thanks to everyone who voted.'),
    kind: 'DISCUSSION',
    author: 'marcus',
    categoryKey: 'TECHNOLOGY_INNOVATION',
    tags: [],
    ageMin: 12 * 24 * 60,
    status: 'LOCKED',
    views: 300,
    reactions: 3,
    poll: { options: [{ label: 'Vendor A', votes: 41 }, { label: 'Vendor B', votes: 27 }, { label: 'Vendor C', votes: 12 }] },
    replies: [],
  },
  {
    key: 'bharat-q',
    title: 'Which controllers can a Niagara supervisor take over without a rewrite?',
    html: p('We run a mix of three controller brands, all BACnet/IP. Which can a Niagara supervisor take over, and which need a gateway?'),
    kind: 'QUESTION',
    author: 'bharat',
    categoryKey: 'TECHNOLOGY_INNOVATION',
    tags: ['niagara', 'bacnet'],
    ageMin: 20 * 60,
    views: 75,
    reactions: 0,
    replies: [
      { key: 'b1', by: 'arvind', ageMin: 19 * 60, text: 'Anything that speaks BACnet/IP with a published PICS. The older MS/TP ones need a router, not a rewrite.' },
      { key: 'b2', by: 'mentor.vikram@icr.dev', ageMin: 18 * 60, text: 'Ask each vendor for their PICS and test one device before you commit the rest.' },
      { key: 'b3', parent: 'b1', by: 'mentor.sanjay@icr.dev', ageMin: 17 * 60, text: 'Put the router firmware versions in the handover pack too.' },
    ],
  },
  {
    key: 'pending',
    title: 'Looking for a partner to audit three data centre rooms',
    html: p('We have three rooms to audit before the end of the quarter and would like a partner with Tier III experience.'),
    kind: 'DISCUSSION',
    author: 'bharat',
    categoryKey: 'FACILITY_MANAGEMENT',
    tags: ['audit'],
    ageMin: 3 * 60,
    moderation: 'PENDING',
    views: 0,
    reactions: 0,
    replies: [],
  },
];

/** 130 replies: forty branches, one in three with answers under it. */
function longReplies(): ReplySpec[] {
  const lines = [
    'As-built drawings in DWG and PDF, not just PDF.',
    'The point list with names, units and ranges as a spreadsheet.',
    'Commissioning records per system, signed by the contractor.',
    'Operating and maintenance manuals indexed by asset tag.',
    'The control sequences in plain language, not only the code.',
    'A list of every default password changed, held by the owner.',
    'Warranty start dates by asset, with the supplier contact.',
    'The BACnet PICS for each device type.',
    'Training records for the operations team.',
    'Spare parts list with lead times.',
  ];
  const out: ReplySpec[] = [];
  let n = 0;
  for (let i = 0; i < 40 && out.length < 130; i++) {
    const rootKey = `m${i}`;
    out.push({ key: rootKey, by: `pool${i % 12}`, ageMin: 6 * 24 * 60 - 30 - i * 20, text: `${i + 1}. ${lines[i % lines.length]}`, likes: i % 7 === 0 ? 2 : 0 });
    if (i % 3 === 0) {
      for (let j = 0; j < 2 && out.length < 130; j++) {
        out.push({ key: `${rootKey}c${j}`, parent: rootKey, by: `pool${(i + j + 3) % 12}`, ageMin: 6 * 24 * 60 - 30 - i * 20 - 5 - j, text: `Agreed on ${i + 1}, and I would add the format it arrives in.` });
      }
    }
    n++;
  }
  // Fill the rest with short follow-ups at the top level until there are 130.
  for (let k = 0; out.length < 130; k++) {
    out.push({ key: `z${k}`, by: `pool${(k + 5) % 12}`, ageMin: 300 - k * 2, text: `One more for the pack: item ${k + 1} from our own checklist.` });
  }
  void n;
  return out;
}

// ---------------------------------------------------------------------------

function hash(s: string): number {
  let h = 2166136261;
  for (const c of s) {
    h ^= c.charCodeAt(0);
    h = Math.imul(h, 16777619) >>> 0;
  }
  return h >>> 0;
}

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
  log(`database "${rows[0]?.db}" on ${addr || 'a local socket'}: local`);
  if (!existsSync(join(process.cwd(), 'prisma', 'schema.prisma'))) {
    throw new Error(`Run this from E:\\ICR\\irc-portal\\backend (cwd is ${process.cwd()}): uploads resolve from it.`);
  }
}

/** A minimal one-page PDF, so the discussion has a real file to open. */
function pdfBytes(): Buffer {
  const objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 144] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
    '<< /Length 63 >>\nstream\nBT /F1 14 Tf 20 100 Td (HVAC retrofit specification - sample) Tj ET\nendstream',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  let out = '%PDF-1.4\n';
  const offsets: number[] = [];
  objects.forEach((o, i) => {
    offsets.push(out.length);
    out += `${i + 1} 0 obj\n${o}\nendobj\n`;
  });
  const xref = out.length;
  out += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  for (const o of offsets) out += `${String(o).padStart(10, '0')} 00000 n \n`;
  out += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return Buffer.from(out, 'latin1');
}

async function loadManifest(prisma: PrismaClient): Promise<Manifest> {
  const row = await prisma.setting.findUnique({ where: { key: MANIFEST_KEY }, select: { value: true } });
  return row ? { version: 1, ...(row.value as unknown as Manifest) } : { version: 1 };
}

async function saveManifest(prisma: PrismaClient, m: Manifest): Promise<void> {
  const value = m as unknown as Prisma.InputJsonValue;
  await prisma.setting.upsert({ where: { key: MANIFEST_KEY }, update: { value }, create: { key: MANIFEST_KEY, value } });
}

export interface SeedOptions {
  remove?: boolean;
  dryRun?: boolean;
  now?: Date;
}

export async function seedForums(prisma: PrismaClient, log: (m: string) => void, opts: SeedOptions = {}): Promise<void> {
  log(opts.remove ? 'forums: removing' : 'forums: seeding');
  await assertLocalDatabase(prisma, log);
  if (opts.remove) return removeAll(prisma, log);
  const now = opts.now ?? new Date();
  const at = (minutesAgo: number) => new Date(now.getTime() - Math.round(minutesAgo * MIN));
  const manifest = await loadManifest(prisma);

  // --- People ---------------------------------------------------------------------------------------------------
  const homeUser = async (k: string) =>
    (await prisma.user.findUnique({ where: { id: `${HOME_ID}user-${k}` }, select: { id: true, designation: true } })) ?? undefined;
  const sarah = await homeUser('sarah');
  if (!sarah) throw new Error('The Home design people are missing: run home.ts first.');
  const people = new Map<string, string>();
  for (const k of ['sarah', 'david', 'marcus', 'elena', 'arvind', 'priya']) {
    const u = await homeUser(k);
    if (!u) throw new Error(`Home design person ${k} is missing: run home.ts first.`);
    people.set(k, u.id);
  }
  const pool = await prisma.user.findMany({
    where: {
      isActive: true,
      OR: [{ email: { endsWith: '@icr.dev', mode: 'insensitive' } }, { email: { endsWith: '@icr.test', mode: 'insensitive' } }],
    },
    orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    select: { id: true, email: true },
  });
  const byEmail = new Map(pool.map((u) => [u.email.toLowerCase(), u.id]));
  const bharat = byEmail.get(BHARAT_EMAIL);
  const pooja = byEmail.get(POOJA_EMAIL);
  if (!bharat) throw new Error(`${BHARAT_EMAIL} not found: run the portal's db:seed first.`);
  people.set('bharat', bharat);
  if (pooja) people.set('pooja', pooja);
  const personas = new Set([bharat, pooja].filter(Boolean) as string[]);
  const electorate = pool.filter((u) => !personas.has(u.id));
  const repliers = pool.filter((u) => u.email.toLowerCase().startsWith('mentor.') || u.email.toLowerCase().startsWith('mentee.'));
  const resolve = (who: Who): string => {
    const direct = people.get(who) ?? byEmail.get(who.toLowerCase());
    if (direct) return direct;
    const m = /^pool(\d+)$/.exec(who);
    if (m && repliers.length) return repliers[Number(m[1]) % repliers.length].id;
    throw new Error(`Unknown person ${who}`);
  };

  if (opts.dryRun) {
    log('  dry run: nothing is written');
    for (const t of THREADS) log(`    ${t.key}: ${slugify(t.title)}${SUFFIX}`);
    return;
  }

  // --- Arvind's headline ----------------------------------------------------------------------------------------
  const arvindId = people.get('arvind')!;
  const arvind = await prisma.user.findUniqueOrThrow({ where: { id: arvindId }, select: { designation: true } });
  if (!manifest.arvind) manifest.arvind = { id: arvindId, before: arvind.designation };
  await prisma.user.update({ where: { id: arvindId }, data: { designation: ARVIND_HEADLINE } });

  // --- The PDF --------------------------------------------------------------------------------------------------
  const uploads = join(process.cwd(), 'uploads');
  if (!existsSync(uploads)) mkdirSync(uploads, { recursive: true });
  const bytes = pdfBytes();
  writeFileSync(join(uploads, PDF_FILE), bytes);
  await prisma.uploadedFile.deleteMany({ where: { filename: PDF_FILE } });
  await prisma.uploadedFile.create({
    data: {
      filename: PDF_FILE,
      visibility: 'PUBLIC',
      purpose: 'forum-attachment',
      ownerId: people.get('sarah'),
      name: 'HVAC retrofit spec.pdf',
      mimeType: 'application/pdf',
      size: statSync(join(uploads, PDF_FILE)).size,
    },
  });

  // --- The threads ----------------------------------------------------------------------------------------------
  await prisma.forumThread.deleteMany({ where: { id: { startsWith: `${ID}thread-` } } });
  const subOf = async (parentKey: string) =>
    (await prisma.category.findFirst({ where: { parent: { key: parentKey }, active: true, level: 2 }, orderBy: { sortOrder: 'asc' }, select: { id: true } }))?.id ?? null;
  const catId = async (key: string) => {
    const row = await prisma.category.findFirst({ where: { key, level: 1 }, select: { id: true } });
    if (!row) throw new Error(`Category ${key} not found: run the portal's db:seed:masters first.`);
    return row.id;
  };

  const summary: string[] = [];
  const saves: { user: string; thread: string }[] = [];
  for (const spec of THREADS) {
    const t = spec.key === 'long' ? { ...spec, replies: longReplies() } : spec;
    const threadId = `${ID}thread-${t.key}`;
    const authorId = resolve(t.author);
    const created = at(t.ageMin);
    const approvedReplies = t.replies.filter(() => true);
    const repliedAt = approvedReplies.length ? new Date(Math.max(...approvedReplies.map((r) => at(r.ageMin).getTime()))) : created;
    const voters = electorate
      .filter((u) => u.id !== authorId)
      .map((u) => [hash(`${t.key}:${u.id}`), u] as const)
      .sort((a, b) => a[0] - b[0])
      .map(([, u]) => u)
      .slice(0, t.reactions);

    await prisma.forumThread.create({
      data: {
        id: threadId,
        authorId,
        topicCategoryId: await catId(t.categoryKey),
        topicSubcategoryId: null,
        title: t.title,
        slug: `${slugify(t.title)}${SUFFIX}`,
        bodyHtml: t.html,
        kind: t.kind,
        tags: t.tags,
        status: t.status ?? 'OPEN',
        moderation: t.moderation ?? 'APPROVED',
        pinned: false,
        uploadId: t.file?.file ?? null,
        fileName: t.file?.fileName ?? null,
        fileSize: t.file ? statSync(join(uploads, t.file.file)).size : null,
        viewCount: t.views,
        replyCount: t.moderation === 'PENDING' ? 0 : t.replies.length,
        score: voters.length,
        likeCount: voters.length,
        lastActivityAt: repliedAt,
        createdAt: created,
      },
    });
    if (voters.length) {
      await prisma.forumThreadVote.createMany({
        data: voters.map((u) => ({ threadId, userId: u.id, value: 1, reaction: 'LIKE' as const, createdAt: new Date(created.getTime() + 10 * MIN) })),
      });
    }

    // Replies.
    const rows = t.replies.map((r) => ({
      id: `${threadId}-reply-${r.key}`,
      threadId,
      parentId: r.parent ? `${threadId}-reply-${r.parent}` : null,
      authorId: resolve(r.by),
      bodyHtml: p(r.text),
      moderation: 'APPROVED' as const,
      likeCount: r.likes ?? 0,
      score: r.likes ?? 0,
      createdAt: at(r.ageMin),
    }));
    if (rows.length) {
      // Parents before children (the table has a foreign key from a reply to its parent).
      const ordered = [...rows].sort((a, b) => (a.parentId ? 1 : 0) - (b.parentId ? 1 : 0));
      await prisma.forumReply.createMany({ data: ordered });
      const likes: Prisma.ForumReplyVoteCreateManyInput[] = [];
      for (const r of rows) {
        electorate
          .filter((u) => u.id !== r.authorId)
          .map((u) => [hash(`${r.id}:${u.id}`), u] as const)
          .sort((a, b) => a[0] - b[0])
          .slice(0, r.likeCount)
          .forEach(([, u]) => likes.push({ replyId: r.id, userId: u.id, value: 1, reaction: 'LIKE', createdAt: new Date(r.createdAt.getTime() + 2 * MIN) }));
      }
      if (likes.length) await prisma.forumReplyVote.createMany({ data: likes });
    }
    const accepted = t.replies.find((r) => r.accepted);
    if (accepted) await prisma.forumThread.update({ where: { id: threadId }, data: { acceptedReplyId: `${threadId}-reply-${accepted.key}` } });

    // A poll with votes (the people who voted are the electorate, one vote each).
    if (t.poll) {
      const poll = await prisma.forumPoll.create({ data: { threadId, totalVotes: 0 } });
      let cursor = 0;
      let total = 0;
      const shuffledVoters = [...electorate].sort((a, b) => hash(`${t.key}:${a.id}`) - hash(`${t.key}:${b.id}`));
      for (const [order, opt] of t.poll.options.entries()) {
        const row = await prisma.forumPollOption.create({ data: { pollId: poll.id, label: opt.label, order, voteCount: 0 } });
        const take = shuffledVoters.slice(cursor, cursor + opt.votes);
        cursor += take.length;
        total += take.length;
        if (take.length) await prisma.forumPollVote.createMany({ data: take.map((u) => ({ pollId: poll.id, userId: u.id, optionId: row.id })) });
        await prisma.forumPollOption.update({ where: { id: row.id }, data: { voteCount: take.length } });
      }
      await prisma.forumPoll.update({ where: { id: poll.id }, data: { totalVotes: total } });
    }
    summary.push(`${t.key}: ${t.replies.length} replies, ${voters.length} reactions`);
  }
  // Sub-topics: the first active sub-topic of Technology for the BMS threads (a card's topic word).
  const techSub = await subOf('TECHNOLOGY_INNOVATION');
  if (techSub) {
    await prisma.forumThread.updateMany({ where: { id: { in: [`${ID}thread-answered`, `${ID}thread-bharat-q`] } }, data: { topicSubcategoryId: techSub } });
  }

  // Saves: the Saved view reads differently by person.
  saves.push({ user: bharat, thread: `${ID}thread-answered` }, { user: bharat, thread: `${ID}thread-rich` });
  if (pooja) saves.push({ user: pooja, thread: `${ID}thread-spec` });
  await prisma.forumSave.createMany({ data: saves.map((s) => ({ userId: s.user, threadId: s.thread })), skipDuplicates: true });

  await saveManifest(prisma, manifest);
  log(`  threads: ${THREADS.length} (${summary.join('; ')})`);
  log('done');
}

async function removeAll(prisma: PrismaClient, log: (m: string) => void): Promise<void> {
  const manifest = await loadManifest(prisma);
  const step = async (name: string, fn: () => Promise<{ count: number }>) => log(`  ${name}: ${(await fn()).count}`);
  await step('threads', () => prisma.forumThread.deleteMany({ where: { OR: [{ id: { startsWith: ID } }, { slug: { endsWith: SUFFIX } }] } }));
  await step('files', async () => {
    const r = await prisma.uploadedFile.deleteMany({ where: { filename: PDF_FILE } });
    const file = join(process.cwd(), 'uploads', PDF_FILE);
    if (existsSync(file)) unlinkSync(file);
    return r;
  });
  if (manifest.arvind) {
    // Restore only what this script wrote: home.ts may have set it again since.
    await step('arvind', () =>
      prisma.user.updateMany({
        where: { id: manifest.arvind!.id, designation: ARVIND_HEADLINE },
        data: { designation: manifest.arvind!.before },
      }),
    );
  }
  await prisma.setting.deleteMany({ where: { key: MANIFEST_KEY } });
  log('removed');
}

// Run alone: `... forums.ts [--remove] [--dry-run]`
if (require.main === module) {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { PrismaClient: Client } = require('@prisma/client') as typeof import('@prisma/client');
  const prisma = new Client();
  const has = (f: string) => process.argv.includes(f);
  seedForums(prisma, (m) => console.log(m), { remove: has('--remove'), dryRun: has('--dry-run') })
    .catch((e) => {
      console.error(e);
      process.exitCode = 1;
    })
    .finally(() => prisma.$disconnect());
}
