/**
 * MENTORING (after the directory) fixtures for the ICR mobile app.
 *
 * Fills the LOCAL development database with what "My mentoring" and the
 * mentor's desk draw: pairings with sessions, goals, tasks and a certificate;
 * requests; 1:1 session requests and bookings; digital products; plan terms;
 * group sessions; a cohort programme; a mentor's storefront, incoming work and
 * earnings. `tool/seed/mentorship.ts` seeds the DIRECTORY (and its design
 * mentors); this script adds three more listed mentors of its own and never
 * touches theirs.
 *
 *   cd E:\ICR\irc-portal\backend
 *   $env:NODE_PATH = 'E:/ICR/irc-portal/node_modules'
 *   npx ts-node --transpile-only E:/ICR/icr-mobile/tool/seed/mentoring.ts            # seed (idempotent)
 *   npx ts-node --transpile-only E:/ICR/icr-mobile/tool/seed/mentoring.ts --remove   # delete exactly what it made
 *
 * MARKING. Row ids this script writes start with `dsgn-mentoring-`; accounts are
 * `mentoring.<key>@design.icr.test`; files copied into backend/uploads start with
 * `design-mentoring-`. `--remove` deletes by those, so it cannot reach anyone else's rows.
 * The two demo personas (Bharat Buyer, Pooja Professional) are only given rows
 * (pairings, purchases, ...) that carry the prefix; their own columns are not changed.
 *
 * PEOPLE (password `Password123!` unless SEED_PASSWORD):
 *   mentoring.anand   Anand Iyer, a listed mentor with a live paid storefront (the "mentor desk" persona)
 *   mentoring.divya   Divya Rao, a listed free mentor (the finished pairing)
 *   mentoring.neha    Neha Kapoor, a listed free mentor (open requests)
 *   mentoring.meera   Meera Nair, a mentee with a mentee profile (the live tests' mentee)
 *   mentoring.rohan   Rohan Das, a mentee with a profile and no pairings (the live tests' sender)
 *   mentoring.kiran   Kiran Shah, a member who has not applied to mentor (the "become a mentor" persona)
 *   mentoring.{tanvi,arjun,isha,vikram,sana,rahul}  members who give Anand reviews, requests and sales
 *
 * LOCAL ONLY. It refuses to write unless DATABASE_URL points at localhost.
 */
import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import * as shared from '@icr/shared';
import { copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'fs';
import { join } from 'path';

const DOMAIN = 'design.icr.test';
const PREFIX = 'dsgn-mentoring-';
const UP = 'design-mentoring-';

const DAY = 86_400_000;
const HOUR = 3_600_000;
const daysAgo = (n: number) => new Date(Date.now() - n * DAY);
/** `days` from now at an Indian-clock time: the time of day a mentor would name. */
function at(days: number, hour: number, minute = 0): Date {
  const d = new Date(Date.now() + days * DAY);
  d.setUTCHours(hour - 5, minute - 30, 0, 0);
  return d;
}
const idOf = (...parts: (string | number)[]) => PREFIX + parts.join('-');
const emailOf = (key: string) => `mentoring.${key}@${DOMAIN}`;

const TERMS_VERSION: string = (shared as any).MARKETPLACE_TERMS_VERSION ?? '2026.1';
const CONDUCT_VERSION: string | null = (shared as any).MENTOR_CODE_OF_CONDUCT_VERSION ?? null;
const MEET = 'https://meet.google.com/icr-mentoring-demo';

type Log = (message: string) => void;

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
  const u = new URL(url);
  const host = u.hostname.replace(/^\[|\]$/g, '');
  if (!['localhost', '127.0.0.1', '::1'].includes(host)) {
    throw new Error(`Refusing to write design fixtures to a database that is not local (host "${host}").`);
  }
  if (process.env.NODE_ENV === 'production') throw new Error('Refusing to run with NODE_ENV=production.');
  return `${host}:${u.port || '5432'}${u.pathname}`;
}

function assertBackendCwd() {
  if (!existsSync(join(process.cwd(), 'prisma', 'schema.prisma'))) {
    throw new Error(`Run this from the portal's backend folder (E:\\ICR\\irc-portal\\backend); cwd is ${process.cwd()}.`);
  }
}

const FACES_DIR = () => join(process.cwd(), 'prisma', 'seed-assets', 'avatars');
const UPLOADS = () => join(process.cwd(), 'uploads');
const faceUrl = (file: string) => `/uploads/${UP}face-${file}`;

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
  let out = '%PDF-1.4\n';
  const offsets: number[] = [];
  objs.forEach((o, i) => {
    offsets.push(out.length);
    out += `${i + 1} 0 obj\n${o}\nendobj\n`;
  });
  const xref = out.length;
  out += `xref\n0 ${objs.length + 1}\n0000000000 65535 f \n`;
  for (const o of offsets) out += `${String(o).padStart(10, '0')} 00000 n \n`;
  out += `trailer\n<< /Size ${objs.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return Buffer.from(out, 'latin1');
}

// ---------------------------------------------------------------------------
// People
// ---------------------------------------------------------------------------

interface Person {
  key: string;
  first: string;
  last: string;
  face?: string;
  designation?: string;
}

const MENTORS: Record<string, Person & { years: number; capacity: number; competencies: string[]; headline: string; bio: string }> = {
  anand: {
    key: 'anand', first: 'Anand', last: 'Iyer', face: 'male-02.jpg', designation: 'Head of Facilities Strategy', years: 9, capacity: 6,
    headline: 'Head of Facilities Strategy at Prestige Group',
    competencies: ['Career transitions', 'Interview preparation', 'Workplace leadership'],
    bio: '<p>Nine years running facilities for large campuses, now leading strategy for a property group. I help people move from running a site to owning a portfolio.</p>',
  },
  divya: {
    key: 'divya', first: 'Divya', last: 'Rao', face: 'female-01.jpg', designation: 'Sustainability Lead', years: 7, capacity: 4,
    headline: 'Sustainability Lead at Brigade Group',
    competencies: ['Career transitions', 'Green certification'],
    bio: '<p>Seven years in building sustainability and green certification. Happy to review a CV or a first ESG report.</p>',
  },
  neha: {
    key: 'neha', first: 'Neha', last: 'Kapoor', face: 'female-05.jpg', designation: 'Workplace Experience Manager', years: 6, capacity: 3,
    headline: 'Workplace Experience Manager at Wipro',
    competencies: ['Workplace leadership', 'Interview preparation'],
    bio: '<p>Six years shaping workplace experience for technology campuses.</p>',
  },
};

const MEMBERS: Person[] = [
  { key: 'meera', first: 'Meera', last: 'Nair', face: 'female-06.jpg' },
  { key: 'rohan', first: 'Rohan', last: 'Das', face: 'male-03.jpg' },
  { key: 'kiran', first: 'Kiran', last: 'Shah', face: 'male-04.jpg' },
  { key: 'tanvi', first: 'Tanvi', last: 'Joshi', face: 'female-07.jpg' },
  { key: 'arjun', first: 'Arjun', last: 'Mehta', face: 'male-06.jpg' },
  { key: 'isha', first: 'Isha', last: 'Verma', face: 'female-09.jpg' },
  { key: 'vikram', first: 'Vikram', last: 'Singh', face: 'male-07.jpg' },
  { key: 'sana', first: 'Sana', last: 'Qureshi', face: 'female-10.jpg' },
  { key: 'rahul', first: 'Rahul', last: 'Bose', face: 'male-08.jpg' },
];

interface Ctx {
  prisma: PrismaClient;
  log: Log;
  passwordHash: string;
  adminId: string | null;
  users: Map<string, string>;
}

async function upsertUser(c: Ctx, p: Person & { years?: number }) {
  const email = emailOf(p.key);
  const fields = {
    firstName: p.first,
    lastName: p.last,
    avatarUrl: p.face ? faceUrl(p.face) : null,
    designation: p.designation ?? null,
    yearsExperience: p.years ?? null,
  };
  const u = await c.prisma.user.upsert({
    where: { email },
    update: fields,
    create: { id: idOf('u', p.key), email, passwordHash: c.passwordHash, role: 'PROFESSIONAL' as never, emailVerifiedAt: new Date(), ...fields },
  });
  c.users.set(p.key, u.id);
  return u;
}

function copyFaces(log: Log) {
  mkdirSync(UPLOADS(), { recursive: true });
  const wanted = [...Object.values(MENTORS), ...MEMBERS].map((p) => p.face).filter(Boolean) as string[];
  for (const f of wanted) copyFileSync(join(FACES_DIR(), f), join(UPLOADS(), `${UP}face-${f}`));
  log(`  ${wanted.length} portraits copied to backend/uploads (${UP}face-*)`);
}

// ---------------------------------------------------------------------------
// Mentors, their storefronts
// ---------------------------------------------------------------------------

async function seedMentorProfile(c: Ctx, key: string, paid: boolean) {
  const m = MENTORS[key];
  const userId = c.users.get(key)!;
  const data = {
    headline: m.headline,
    bioHtml: m.bio,
    yearsExperience: m.years,
    competencies: m.competencies,
    expertiseKeys: [],
    certifications: [],
    languages: ['English', 'Hindi'],
    topics: ['Moving into strategy roles', 'Panel interviews'],
    targetRoles: ['Facility Manager', 'Workplace Lead'],
    targetAudiences: ['WORKING_PROFESSIONAL', 'EARLY_CAREER'] as never,
    preferredModes: ['VIDEO', 'PHONE'] as never,
    cadence: 'FORTNIGHTLY' as never,
    timezone: 'Asia/Kolkata',
    capacity: m.capacity,
    availabilityNote: 'Tuesday and Thursday evenings, Saturday mornings (IST).',
    meetingLink: MEET,
    status: 'APPROVED' as never,
    submittedAt: daysAgo(150),
    approvedAt: daysAgo(145),
    approvedById: c.adminId,
    approvalExpiresAt: new Date(Date.now() + 300 * DAY),
    conductAcceptedAt: daysAgo(145),
    conductVersion: CONDUCT_VERSION,
    trainingCompletedAt: daysAgo(146),
    screeningClearedAt: daysAgo(146),
    discoverable: true,
    deletedAt: null,
    rating: key === 'anand' ? 4.8 : 4.6,
    ratingCount: key === 'anand' ? 14 : 5,
    sessionsCompleted: key === 'anand' ? 22 : 9,
    menteesHelped: key === 'anand' ? 6 : 3,
    isPaid: paid,
    marketplaceTermsAcceptedAt: paid ? daysAgo(140) : null,
    marketplaceTermsVersion: paid ? TERMS_VERSION : null,
    marketplaceSuspendedAt: null,
    serviceRating: paid ? 4.7 : 0,
    serviceRatingCount: paid ? 9 : 0,
  };
  const id = idOf('mp', key);
  await c.prisma.mentorProfile.upsert({ where: { userId }, update: data as never, create: { id, userId, ...data } as never });
  await c.prisma.mentorAvailabilityBlock.deleteMany({ where: { mentorProfileId: id } });
  await c.prisma.mentorAvailabilityBlock.createMany({
    data: [
      [2, 18 * 60, 20 * 60 + 30],
      [4, 18 * 60, 20 * 60 + 30],
      [6, 10 * 60, 13 * 60],
    ].map(([weekday, startMin, endMin], i) => ({ id: idOf('avail', key, i), mentorProfileId: id, weekday, startMin, endMin })),
  });
  return id;
}

async function upsertService(
  c: Ctx,
  profileId: string,
  ownerId: string,
  s: { k: string; type: string; title: string; blurb: string; durationMin?: number; price: number; compareAt?: number; sales?: number; active?: boolean; file?: string; pdf?: string[] },
  sortOrder: number,
) {
  let upload: { uploadId: string; fileName: string; fileSize: number } | null = null;
  if (s.type === 'RESOURCE' && s.file && s.pdf) {
    const filename = `${UP}res-${s.file}.pdf`;
    const bytes = tinyPdf(s.pdf);
    writeFileSync(join(UPLOADS(), filename), bytes);
    await c.prisma.uploadedFile.upsert({
      where: { filename },
      update: { size: bytes.length, ownerId, name: s.file },
      create: { filename, visibility: 'PRIVATE' as never, purpose: 'mentor-resource', ownerId, name: s.file, mimeType: 'application/pdf', size: bytes.length },
    });
    upload = { uploadId: filename, fileName: s.file, fileSize: bytes.length };
  }
  const data = {
    mentorProfileId: profileId,
    type: s.type as never,
    title: s.title,
    blurb: s.blurb,
    durationMin: s.durationMin ?? null,
    pricePaisa: s.price,
    compareAtPaisa: s.compareAt ?? null,
    uploadId: upload?.uploadId ?? null,
    fileName: upload?.fileName ?? null,
    fileSize: upload?.fileSize ?? null,
    active: s.active ?? true,
    sortOrder,
    salesCount: s.sales ?? 0,
    deletedAt: null,
  };
  const id = idOf('svc', s.k);
  await c.prisma.mentorService.upsert({ where: { id }, update: data as never, create: { id, ...data } as never });
  return id;
}

async function upsertPlan(
  c: Ctx,
  profileId: string,
  pl: { k: string; kind: 'RECURRING' | 'CURRICULUM'; title: string; blurb: string; price: number; sessionsPerMonth: number; durationMin?: number; billingMonths?: number; totalSessions?: number; accessMonths?: number; inclusions: string[]; modules?: { title: string; outline: string }[]; active?: boolean },
  sortOrder: number,
) {
  const id = idOf('plan', pl.k);
  const data = {
    mentorProfileId: profileId,
    title: pl.title,
    blurb: pl.blurb,
    kind: pl.kind as never,
    pricePaisa: pl.price,
    billingPeriodMonths: pl.billingMonths ?? 1,
    sessionsPerMonth: pl.kind === 'CURRICULUM' ? 0 : pl.sessionsPerMonth,
    sessionDurationMin: pl.durationMin ?? 45,
    totalSessions: pl.totalSessions ?? null,
    accessMonths: pl.accessMonths ?? null,
    inclusions: pl.inclusions,
    active: pl.active ?? true,
    sortOrder,
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

interface Storefront {
  profileId: string;
  svc: Record<'discovery' | 'strategy' | 'review' | 'kit' | 'workbook' | 'draft', string>;
  plan: { coaching: string; programme: string };
}

async function seedAnandStorefront(c: Ctx): Promise<Storefront> {
  const userId = c.users.get('anand')!;
  const profileId = idOf('mp', 'anand');
  const svc = {
    discovery: await upsertService(c, profileId, userId, { k: 'discovery', type: 'ONE_ON_ONE', title: 'Career clarity call', blurb: 'A free 30-minute call to map where you are and what to do next.', durationMin: 30, price: 0, sales: 6 }, 10),
    strategy: await upsertService(c, profileId, userId, { k: 'strategy', type: 'ONE_ON_ONE', title: 'Facilities leadership strategy session', blurb: 'Forty-five minutes on your move from site to portfolio: scope, gaps and a 90-day plan.', durationMin: 45, price: 149900, compareAt: 199900, sales: 4 }, 20),
    review: await upsertService(c, profileId, userId, { k: 'review', type: 'ONE_ON_ONE', title: 'Portfolio and CV review call', blurb: 'Line-by-line feedback on your CV and portfolio, live.', durationMin: 60, price: 79900, sales: 2 }, 30),
    kit: await upsertService(c, profileId, userId, { k: 'kit', type: 'RESOURCE', title: 'FM interview question bank', blurb: 'Eighty questions with model answers for facilities leadership panels.', price: 49900, compareAt: 99900, sales: 5, file: 'interview-question-bank', pdf: ['FM interview question bank', 'Eighty questions with model answers', 'Sample resource for local development.'] }, 40),
    workbook: await upsertService(c, profileId, userId, { k: 'workbook', type: 'RESOURCE', title: '90-day plan workbook', blurb: 'A free workbook for planning your first ninety days in a new role.', price: 0, sales: 7, file: '90-day-plan-workbook', pdf: ['90-day plan workbook', 'Print it, fill it in.', 'Sample resource for local development.'] }, 50),
    draft: await upsertService(c, profileId, userId, { k: 'draft', type: 'ONE_ON_ONE', title: 'Salary negotiation clinic', blurb: 'A draft offering: not on the storefront yet.', durationMin: 45, price: 99900, active: false }, 60),
  };
  const plan = {
    coaching: await upsertPlan(c, profileId, { k: 'coaching', kind: 'RECURRING', title: 'Monthly leadership coaching', blurb: 'Two calls a month and chat support in between.', price: 299900, sessionsPerMonth: 2, durationMin: 45, inclusions: ['Two 45-minute 1:1 calls a month', 'Review of your site and portfolio plans', 'Chat support between calls'] }, 0),
    programme: await upsertPlan(c, profileId, {
      k: 'programme', kind: 'CURRICULUM', title: 'Site to portfolio: a 3-session programme', blurb: 'A fixed syllabus for the jump from running a site to owning a portfolio.', price: 599900, sessionsPerMonth: 0, durationMin: 60, totalSessions: 3, accessMonths: 3, billingMonths: 3, inclusions: ['Notes after every session'],
      modules: [
        { title: 'Where you are, where you want to be', outline: 'Role scope, gaps and a 90-day target.' },
        { title: 'Vendor and SLA governance', outline: 'Reading, scoring and renegotiating an SLA.' },
        { title: 'The portfolio business case', outline: 'Occupancy, cost and a case finance will sign.' },
      ],
    }, 1),
  };
  const keepS = Object.values(svc);
  const keepP = Object.values(plan);
  await c.prisma.mentorService.updateMany({ where: { mentorProfileId: profileId, id: { startsWith: PREFIX, notIn: keepS } }, data: { active: false, deletedAt: new Date() } as never });
  await c.prisma.mentorPlan.updateMany({ where: { mentorProfileId: profileId, id: { startsWith: PREFIX, notIn: keepP } }, data: { active: false, deletedAt: new Date() } as never });
  return { profileId, svc, plan };
}

// ---------------------------------------------------------------------------
// Pairings and what happens in them
// ---------------------------------------------------------------------------

async function upsertPairing(
  c: Ctx,
  id: string,
  mentorKey: string,
  menteeId: string,
  o: { status: 'ACTIVE' | 'COMPLETED' | 'PAUSED'; started: Date; completed?: Date; sessions: number; minutes: number; cadence?: string },
) {
  const mentorUserId = c.users.get(mentorKey)!;
  const profileId = idOf('mp', mentorKey);
  const reqId = `${id}-req`;
  await c.prisma.mentorshipRequest.upsert({
    where: { id: reqId },
    update: {},
    create: {
      id: reqId, mentorProfileId: profileId, menteeId, message: 'I would value your guidance on my next move into facilities strategy.',
      focusAreas: ['Career transitions'], matchScore: 78, status: 'ACCEPTED' as never, responseNote: 'Happy to help. Send me your current role scope before our first call.',
      respondedAt: new Date(o.started.getTime() + 4 * HOUR), createdAt: new Date(o.started.getTime() - DAY),
    },
  });
  const data = {
    mentorId: mentorUserId, menteeId, mentorProfileId: profileId, requestId: reqId,
    cadence: (o.cadence ?? 'FORTNIGHTLY') as never, status: o.status as never, startedAt: o.started,
    completedAt: o.completed ?? null, endedReason: null, sessionsCount: o.sessions, totalMinutes: o.minutes, deletedAt: null,
  };
  await c.prisma.mentorship.upsert({ where: { id }, update: data as never, create: { id, ...data } as never });
  await c.prisma.mentorshipEvent.deleteMany({ where: { mentorshipId: id, id: { startsWith: PREFIX } } });
  const events: [string, string, Date, string?][] = [
    ['STARTED', 'The pairing began.', o.started],
    ...(o.completed ? ([['COMPLETED', 'Marked complete by the mentor.', o.completed]] as [string, string, Date][]) : []),
  ];
  await c.prisma.mentorshipEvent.createMany({
    data: events.map(([type, note, createdAt], i) => ({ id: `${id}-ev${i}`, mentorshipId: id, type: type as never, note, visibility: 'SHARED' as never, actorId: mentorUserId, createdAt })),
  });
}

async function upsertSession(
  c: Ctx,
  id: string,
  mentorshipId: string,
  createdById: string,
  o: { when: Date; min: number; status: 'SCHEDULED' | 'COMPLETED' | 'CANCELLED' | 'REQUESTED'; agenda?: string; link?: string | null; cancelReason?: string; notes?: string },
) {
  const data = {
    mentorshipId, createdById, scheduledAt: o.when, durationMin: o.min, mode: 'VIDEO' as never, status: o.status as never,
    agenda: o.agenda ?? null, meetingLink: o.link ?? null,
    completedAt: o.status === 'COMPLETED' ? new Date(o.when.getTime() + o.min * 60_000) : null,
    cancelledAt: o.status === 'CANCELLED' ? daysAgo(1) : null, cancelReason: o.cancelReason ?? null, notes: o.notes ?? null,
  };
  await c.prisma.mentorshipSession.upsert({ where: { id }, update: data as never, create: { id, ...data } as never });
}

async function upsertGoal(c: Ctx, id: string, mentorshipId: string, createdById: string, g: { title: string; detail?: string; progress: number; status?: 'OPEN' | 'ACHIEVED'; target?: Date }) {
  const status = g.status ?? 'OPEN';
  const data = {
    mentorshipId, createdById, title: g.title, detail: g.detail ?? null, targetDate: g.target ?? null, status: status as never,
    progress: status === 'ACHIEVED' ? 100 : g.progress, achievedAt: status === 'ACHIEVED' ? daysAgo(6) : null,
  };
  await c.prisma.mentorshipGoal.upsert({ where: { id }, update: data as never, create: { id, ...data } as never });
}

async function upsertTask(c: Ctx, id: string, mentorshipId: string, createdById: string, t: { title: string; due?: Date; status?: 'OPEN' | 'DONE' }) {
  const status = t.status ?? 'OPEN';
  const data = { mentorshipId, createdById, title: t.title, dueAt: t.due ?? null, status: status as never, completedAt: status === 'DONE' ? daysAgo(3) : null };
  await c.prisma.mentorshipTask.upsert({ where: { id }, update: data as never, create: { id, ...data } as never });
}

/** What a mentee's "My mentoring" holds: two pairings (one live with Anand, one finished with Divya), requests, a certificate. */
async function seedMenteeStory(c: Ctx, key: string, menteeId: string) {
  const anand = c.users.get('anand')!;
  const divya = c.users.get('divya')!;
  const a = idOf('pair', key, 'anand');
  await upsertPairing(c, a, 'anand', menteeId, { status: 'ACTIVE', started: daysAgo(40), sessions: 2, minutes: 90 });
  await upsertSession(c, `${a}-s1`, a, anand, { when: daysAgo(30), min: 45, status: 'COMPLETED', agenda: 'Where you are and where you want to be', notes: 'Agreed a 90-day target.' });
  await upsertSession(c, `${a}-s2`, a, anand, { when: daysAgo(14), min: 45, status: 'COMPLETED', agenda: 'Vendor SLA governance' });
  await upsertSession(c, `${a}-s3`, a, menteeId, { when: at(3, 18, 30), min: 45, status: 'SCHEDULED', agenda: 'Reviewing the scorecard draft', link: MEET });
  await upsertSession(c, `${a}-s4`, a, menteeId, { when: at(9, 19, 0), min: 45, status: 'REQUESTED', agenda: 'Mock panel interview' });
  await upsertSession(c, `${a}-s5`, a, menteeId, { when: daysAgo(6), min: 30, status: 'CANCELLED', cancelReason: 'A site shutdown came up that week.' });
  await upsertGoal(c, `${a}-g1`, a, menteeId, { title: 'Lead my first site audit on my own', detail: 'Plan, run and report one audit without a senior alongside.', progress: 40, target: new Date(Date.now() + 60 * DAY) });
  await upsertGoal(c, `${a}-g2`, a, anand, { title: 'Build a vendor scorecard', progress: 10 });
  await upsertGoal(c, `${a}-g3`, a, menteeId, { title: 'Understand SLA reporting', progress: 100, status: 'ACHIEVED' });
  await upsertTask(c, `${a}-t1`, a, anand, { title: 'Draft the vendor scorecard template', due: daysAgo(2) });
  await upsertTask(c, `${a}-t2`, a, anand, { title: 'Read the energy audit checklist', due: at(5, 18) });
  await upsertTask(c, `${a}-t3`, a, menteeId, { title: 'Send Anand the current org chart', status: 'DONE' });

  const b = idOf('pair', key, 'divya');
  await upsertPairing(c, b, 'divya', menteeId, { status: 'COMPLETED', started: daysAgo(120), completed: daysAgo(10), sessions: 5, minutes: 225 });
  for (let i = 1; i <= 5; i++) {
    await upsertSession(c, `${b}-s${i}`, b, divya, { when: daysAgo(115 - i * 18), min: 45, status: 'COMPLETED', agenda: `Session ${i}` });
  }
  await upsertGoal(c, `${b}-g1`, b, menteeId, { title: 'Write my first ESG report', progress: 100, status: 'ACHIEVED' });
  await c.prisma.mentorshipCertificate.upsert({
    where: { certificateId: `ICR-MENTEE-2026-${key.toUpperCase().padEnd(8, 'X').slice(0, 8)}` },
    update: { title: 'Mentoring completion certificate' },
    create: {
      id: idOf('cert', key), certificateId: `ICR-MENTEE-2026-${key.toUpperCase().padEnd(8, 'X').slice(0, 8)}`, userId: menteeId, kind: 'MENTEE' as never,
      mentorshipId: b, title: 'Mentoring completion certificate', counterpartName: 'Divya Rao', sessionsCount: 5, hours: 3.75, goalsAchieved: 1,
      startedAt: daysAgo(120), completedAt: daysAgo(10), issuedAt: daysAgo(10),
    },
  });
  // The two requests that did not become pairings.
  const neha = idOf('mp', 'neha');
  const reqs: [string, string, Date, string | null][] = [
    ['pending', 'PENDING', daysAgo(2), null],
    ['declined', 'DECLINED', daysAgo(20), 'Thank you for asking. My cohort is full until the new year; please try again then.'],
  ];
  for (const [k, status, createdAt, note] of reqs) {
    const id = idOf('req', key, k);
    const data = {
      mentorProfileId: neha, menteeId, message: 'I would like to learn how you plan workplace experience programmes for a campus.',
      focusAreas: ['Workplace leadership'], matchScore: 61, status: status as never, responseNote: note,
      respondedAt: note ? new Date(createdAt.getTime() + 6 * HOUR) : null, expiresAt: new Date(createdAt.getTime() + 21 * DAY), createdAt,
    };
    await c.prisma.mentorshipRequest.upsert({ where: { id }, update: data as never, create: { id, ...data } as never });
  }
  return { pairingA: a, pairingB: b };
}

// ---------------------------------------------------------------------------
// Purchases, terms, group sessions, programme
// ---------------------------------------------------------------------------

interface PurchaseSpec {
  k: string;
  buyer: string;
  svc: keyof Storefront['svc'];
  status: string;
  price: number;
  type?: string;
  title: string;
  topic?: string;
  when?: Date;
  min?: number;
  payBy?: Date | null;
  decided?: boolean;
  declineReason?: string;
  booking?: { when: Date; status: 'SCHEDULED' | 'COMPLETED'; min: number };
  paidAt?: Date;
  fulfilledAt?: Date;
  provider?: string | null;
  review?: { rating: number; comment: string; name: string };
}

async function upsertPurchase(c: Ctx, sf: Storefront, p: PurchaseSpec) {
  const mentorUserId = c.users.get('anand')!;
  const buyerId = c.users.get(p.buyer)!;
  const id = idOf('buy', p.k);
  const type = p.type ?? 'ONE_ON_ONE';
  const fee = Math.round(p.price * 0.2);
  const data = {
    serviceId: sf.svc[p.svc], buyerId, mentorUserId, type: type as never, titleSnapshot: p.title, pricePaisa: p.price, feeBps: 2000, feePaisa: fee, netPaisa: p.price - fee,
    status: p.status as never, provider: p.provider ?? (p.paidAt ? (p.price === 0 ? 'free' : 'dev') : null), paidAt: p.paidAt ?? null, fulfilledAt: p.fulfilledAt ?? null,
    requestTopic: p.topic ?? null, bookingScheduledAt: p.when ?? p.booking?.when ?? null, bookingDurationMin: p.min ?? p.booking?.min ?? null, bookingMode: type === 'ONE_ON_ONE' ? ('VIDEO' as never) : null,
    decidedAt: p.decided ? daysAgo(1) : null, declineReason: p.declineReason ?? null, payBy: p.payBy ?? null,
  };
  await c.prisma.mentorServicePurchase.upsert({ where: { id }, update: data as never, create: { id, ...data } as never });
  if (p.booking) {
    const b = { mentorUserId, scheduledAt: p.booking.when, durationMin: p.booking.min, mode: 'VIDEO' as never, meetingLink: MEET, status: p.booking.status as never, completedAt: p.booking.status === 'COMPLETED' ? new Date(p.booking.when.getTime() + p.booking.min * 60_000) : null };
    await c.prisma.mentorServiceBooking.upsert({ where: { purchaseId: id }, update: b as never, create: { id: `${id}-bk`, purchaseId: id, ...b } as never });
  } else {
    await c.prisma.mentorServiceBooking.deleteMany({ where: { purchaseId: id } });
  }
  if (p.review) {
    const r = { serviceId: sf.svc[p.svc], mentorProfileId: sf.profileId, authorId: buyerId, authorName: p.review.name, rating: p.review.rating, comment: p.review.comment, anonymous: false };
    await c.prisma.mentorServiceReview.upsert({ where: { purchaseId: id }, update: r as never, create: { id: `${id}-rv`, purchaseId: id, ...r } as never });
  } else {
    await c.prisma.mentorServiceReview.deleteMany({ where: { purchaseId: id } });
  }
  if (p.paidAt && p.price > 0) {
    const lid = `${id}-led`;
    const settled = !!p.fulfilledAt && p.fulfilledAt.getTime() < Date.now() - 20 * DAY;
    const ledger = { mentorUserId, purchaseId: id, kind: 'EARNING', amountPaisa: p.price - fee, settledAt: settled ? daysAgo(5) : null, settlementRef: settled ? 'NEFT-DEMO-0042' : null, createdAt: p.fulfilledAt ?? p.paidAt };
    await c.prisma.mentorLedgerEntry.upsert({ where: { id: lid }, update: ledger as never, create: { id: lid, ...ledger } as never });
  }
  return id;
}

async function upsertTerm(
  c: Ctx,
  sf: Storefront,
  k: string,
  buyer: string,
  plan: 'coaching' | 'programme',
  o: { status: string; allowance: number; used: number; mentorshipId?: string; paidAt?: Date; periodEnd?: Date; total: number; steps?: { done: boolean }[] },
) {
  const planId = sf.plan[plan];
  const rec = plan === 'coaching';
  const id = idOf('term', k);
  const fee = Math.round(o.total * 0.2);
  const data = {
    planId, buyerId: c.users.get(buyer)!, mentorUserId: c.users.get('anand')!, mentorProfileId: sf.profileId,
    titleSnapshot: rec ? 'Monthly leadership coaching' : 'Site to portfolio: a 3-session programme', kind: (rec ? 'RECURRING' : 'CURRICULUM') as never,
    pricePaisa: o.total, taxBps: 0, taxPaisa: 0, feeBps: 2000, feePaisa: fee, netPaisa: o.total - fee, totalPaisa: o.total, billingPeriodMonths: rec ? 1 : 3,
    status: o.status as never, provider: o.paidAt ? 'dev' : null, paidAt: o.paidAt ?? null,
    currentPeriodStart: o.paidAt ?? null, currentPeriodEnd: o.periodEnd ?? null, sessionsAllowance: o.allowance, sessionsUsed: o.used,
    mentorshipId: o.mentorshipId ?? null,
  };
  await c.prisma.mentorPlanSubscription.upsert({ where: { id }, update: data as never, create: { id, ...data } as never });
  await c.prisma.mentorPlanSubscriptionStep.deleteMany({ where: { subscriptionId: id } });
  if (o.steps) {
    const titles = ['Where you are, where you want to be', 'Vendor and SLA governance', 'The portfolio business case'];
    await c.prisma.mentorPlanSubscriptionStep.createMany({
      data: o.steps.map((s, i) => ({ id: `${id}-st${i + 1}`, subscriptionId: id, position: i + 1, titleSnapshot: titles[i], durationMin: 60, completedAt: s.done ? daysAgo(8 - i) : null })),
    });
  }
  if (o.paidAt) {
    const lid = `${id}-led`;
    const ledger = { mentorUserId: c.users.get('anand')!, subscriptionId: id, kind: 'EARNING', amountPaisa: o.total - fee, settledAt: null, settlementRef: null, createdAt: o.paidAt };
    await c.prisma.mentorLedgerEntry.upsert({ where: { id: lid }, update: ledger as never, create: { id: lid, ...ledger } as never });
  }
}

async function upsertGroup(
  c: Ctx,
  k: string,
  o: { title: string; summary: string; when: Date; min: number; status: 'SCHEDULED' | 'DRAFT' | 'COMPLETED'; capacity?: number; price?: number | null; attendees?: { user: string; status: string }[]; mode?: string; location?: string },
) {
  const id = idOf('group', k);
  const host = c.users.get('anand')!;
  const data = {
    hostId: host, title: o.title, summary: o.summary, scheduledAt: o.when, durationMin: o.min, mode: (o.mode ?? 'VIDEO') as never, location: o.location ?? null,
    meetingLink: MEET, timezone: 'Asia/Kolkata', capacity: o.capacity ?? 25, waitlistEnabled: true, focusAreas: ['Career transitions'],
    competencies: ['Career transitions'], status: o.status as never, pricePaisa: o.price ?? null, completedAt: o.status === 'COMPLETED' ? new Date(o.when.getTime() + o.min * 60_000) : null, deletedAt: null,
  };
  await c.prisma.mentorshipGroupSession.upsert({ where: { id }, update: data as never, create: { id, ...data } as never });
  const occ = idOf('group', k, 'occ1');
  const od = { scheduledAt: o.when, durationMin: o.min, status: (o.status === 'COMPLETED' ? 'COMPLETED' : 'SCHEDULED') as never, completedAt: o.status === 'COMPLETED' ? o.when : null };
  await c.prisma.mentorshipGroupSessionOccurrence.upsert({ where: { id: occ }, update: od as never, create: { id: occ, sessionId: id, seq: 1, ...od } as never });
  await c.prisma.mentorshipGroupAttendee.deleteMany({ where: { sessionId: id, id: { startsWith: PREFIX } } });
  for (const [i, a] of (o.attendees ?? []).entries()) {
    const userId = c.users.get(a.user) ?? a.user;
    await c.prisma.mentorshipGroupAttendee.upsert({
      where: { sessionId_userId: { sessionId: id, userId } },
      update: { status: a.status as never, cancelledAt: null },
      create: { id: `${id}-a${i}`, sessionId: id, userId, status: a.status as never, question: i === 0 ? 'How do I present a portfolio case to finance?' : null },
    });
  }
  return id;
}

async function seedProgramme(c: Ctx, menteeIds: Record<string, string>) {
  const id = idOf('programme', 'circle');
  const data = {
    slug: 'early-career-mentoring-circle-design', name: 'Early-career mentoring circle', summary: 'Twelve weeks of group mentoring for people in their first five years in facilities.',
    detailHtml: '<p>A small cohort, a fixed monthly rhythm and one mentor per three mentees.</p>', status: 'OPEN' as never,
    applicationsOpenAt: daysAgo(10), applicationsCloseAt: new Date(Date.now() + 25 * DAY), startsAt: new Date(Date.now() + 30 * DAY), endsAt: new Date(Date.now() + 120 * DAY),
    menteeCapacity: 12, mentorCapacity: 4, focusAreas: ['Career transitions'], competencies: ['Career transitions'], createdById: c.users.get('anand')!, deletedAt: null,
  };
  await c.prisma.mentorshipProgram.upsert({ where: { id }, update: data as never, create: { id, ...data } as never });
  const rows: [string, string, string, string, string | null][] = [
    ['meera', 'meera', 'MENTEE', 'APPLIED', null],
    ['bharat', 'bharat', 'MENTEE', 'ACCEPTED', null],
    ['divya', 'divya', 'MENTOR', 'ACCEPTED', null],
  ];
  for (const [k, u, role, status] of rows) {
    const userId = menteeIds[u] ?? c.users.get(u);
    if (!userId) continue;
    const eid = idOf('enrol', 'circle', k);
    const d = { programId: id, userId, role: role as never, status: status as never, motivation: 'I want a steadier rhythm of mentoring than ad hoc calls.', decidedAt: status === 'ACCEPTED' ? daysAgo(1) : null, decidedById: status === 'ACCEPTED' ? c.users.get('anand')! : null };
    await c.prisma.mentorshipProgramEnrolment.upsert({ where: { programId_userId_role: { programId: id, userId, role: role as never } }, update: d as never, create: { id: eid, ...d } as never });
  }
  return id;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

export interface MentoringSummary {
  anandProfileId: string;
  people: Record<string, string>;
}

export async function seedMentoring(prisma: PrismaClient, log: Log = console.log, opts?: { remove?: boolean }): Promise<MentoringSummary | void> {
  assertBackendCwd();
  const where = assertLocalDatabase();
  if (opts?.remove) {
    log(`Removing the mentoring fixtures from ${where} ...`);
    await removeAll(prisma, log);
    return;
  }
  log(`Seeding the mentoring fixtures into ${where} ...`);
  copyFaces(log);
  const c: Ctx = {
    prisma, log, passwordHash: bcrypt.hashSync(seedPassword('Password123!'), 10), adminId: (await prisma.user.findFirst({ where: { role: 'SUPER_ADMIN' }, select: { id: true } }))?.id ?? null,
    users: new Map(),
  };
  for (const m of Object.values(MENTORS)) await upsertUser(c, m);
  for (const m of MEMBERS) await upsertUser(c, m);
  await seedMentorProfile(c, 'anand', true);
  await seedMentorProfile(c, 'divya', false);
  await seedMentorProfile(c, 'neha', false);
  const sf = await seedAnandStorefront(c);

  // Mentee profiles for the mentees who are people to log in as; the two demo personas get none (a profile changes
  // what the mentor directory's topic chips colour in, which the design fixes).
  const menteeProfiles: [string, string][] = [['meera', 'MID_CAREER'], ['rohan', 'EARLY_CAREER']];
  for (const [key, stage] of menteeProfiles) {
    const userId = c.users.get(key)!;
    const d = { careerStage: stage as never, focusAreas: ['Career transitions', 'Workplace leadership'], goalSummary: 'Move from running a site to owning a portfolio.', preferredModes: ['VIDEO', 'PHONE'] as never, cadence: 'FORTNIGHTLY' as never, timezone: 'Asia/Kolkata', discoverable: true };
    await prisma.menteeProfile.upsert({ where: { userId }, update: d as never, create: { id: idOf('mentee', key), userId, ...d } as never });
  }

  const demo = await prisma.user.findMany({ where: { email: { in: ['buyer@icr.dev', 'professional@icr.test'] } }, select: { id: true, email: true } });
  const bharat = demo.find((u) => u.email === 'buyer@icr.dev')?.id;
  const pooja = demo.find((u) => u.email === 'professional@icr.test')?.id;
  const menteeIds: Record<string, string> = { meera: c.users.get('meera')! };
  if (bharat) menteeIds.bharat = bharat;
  if (pooja) menteeIds.pooja = pooja;
  for (const [k, v] of Object.entries(menteeIds)) c.users.set(k, v);
  for (const [key, id] of Object.entries(menteeIds)) {
    // Pooja is left with her own history: the directory's live tests send requests as her.
    if (key === 'pooja') continue;
    await seedMenteeStory(c, key, id);
  }
  log(`  pairings, sessions, goals, tasks, requests and a certificate for: ${Object.keys(menteeIds).filter((k) => k !== 'pooja').join(', ')}`);

  // Anand's own mentees (reviews and a roster).
  for (const [key, rating, comment] of [
    ['tanvi', 5, 'Anand asked the questions I had been avoiding. My portfolio case went through at the first review.'],
    ['arjun', 4, 'Clear, practical and kind. I would have liked one more session.'],
  ] as const) {
    const id = idOf('pair', key, 'anand');
    await upsertPairing(c, id, 'anand', c.users.get(key)!, { status: 'COMPLETED', started: daysAgo(100), completed: daysAgo(20 + (key === 'arjun' ? 15 : 0)), sessions: 4, minutes: 180 });
    const fb = { mentorshipId: id, authorId: c.users.get(key)!, rating, wouldRecommend: true, comment, createdAt: daysAgo(18) };
    await prisma.mentorshipFeedback.upsert({ where: { mentorshipId_authorId: { mentorshipId: id, authorId: c.users.get(key)! } }, update: fb as never, create: { id: `${id}-fb`, ...fb } as never });
  }
  // The requests waiting on Anand (free mentoring).
  for (const [key, note] of [
    ['isha', 'I run two sites and want to move up to a regional role. Could you guide me?'],
    ['vikram', 'I am preparing for a head of facilities panel next month.'],
    ['sana', 'I would like help writing a business case for a smart-building retrofit.'],
    ['rahul', 'I am changing from operations to workplace strategy.'],
  ] as const) {
    const id = idOf('req', key, 'anand');
    const d = { mentorProfileId: sf.profileId, menteeId: c.users.get(key)!, message: note, focusAreas: ['Career transitions'], matchScore: 70, status: 'PENDING' as never, responseNote: null, respondedAt: null, expiresAt: new Date(Date.now() + 18 * DAY), createdAt: daysAgo(2) };
    await prisma.mentorshipRequest.upsert({ where: { id }, update: d as never, create: { id, ...d } as never });
  }

  // 1:1 sessions and products: bought by the two mentees and by Anand's other members.
  const price = (k: keyof Storefront['svc']) => ({ discovery: 0, strategy: 149900, review: 79900, kit: 49900, workbook: 0, draft: 99900 })[k];
  for (const key of Object.keys(menteeIds).filter((k) => k !== 'pooja')) {
    await upsertPurchase(c, sf, { k: `${key}-requested`, buyer: key, svc: 'strategy', status: 'REQUESTED', price: price('strategy'), title: 'Facilities leadership strategy session', topic: 'Preparing for a facilities head interview', min: 45 });
    await upsertPurchase(c, sf, { k: `${key}-accepted`, buyer: key, svc: 'review', status: 'ACCEPTED', price: price('review'), title: 'Portfolio and CV review call', topic: 'Review my portfolio before the panel', min: 60, when: at(4, 18, 30), payBy: at(3, 12), decided: true });
    await upsertPurchase(c, sf, { k: `${key}-booked`, buyer: key, svc: 'discovery', status: 'PAID', price: 0, title: 'Career clarity call', topic: 'Mapping my next two years', min: 30, paidAt: daysAgo(1), decided: true, booking: { when: at(2, 18, 30), status: 'SCHEDULED', min: 30 } });
    await upsertPurchase(c, sf, { k: `${key}-kit`, buyer: key, svc: 'kit', status: 'FULFILLED', price: price('kit'), type: 'RESOURCE', title: 'FM interview question bank', paidAt: daysAgo(30), fulfilledAt: daysAgo(30) });
    await upsertPurchase(c, sf, { k: `${key}-declined`, buyer: key, svc: 'strategy', status: 'DECLINED', price: price('strategy'), title: 'Facilities leadership strategy session', topic: 'An earlier ask', decided: true, declineReason: 'I am travelling that fortnight. Please ask again after the 20th.' });
    if (key === 'bharat') {
      // The states the member's Purchases tab draws that the rows above do not make: a payment due (the time was
      // accepted, nothing is paid yet), a move the mentor asked for on a booked call, and a held session whose review
      // is still to write. Only Bharat gets them (he is the person the emulator is signed in as).
      await upsertPurchase(c, sf, { k: `${key}-confirmed`, buyer: key, svc: 'review', status: 'CONFIRMED', price: price('review'), title: 'Portfolio and CV review call', topic: 'A second look at the portfolio', min: 60, decided: true, when: at(7, 18, 30), booking: { when: at(7, 18, 30), status: 'SCHEDULED', min: 60 } });
      await upsertPurchase(c, sf, { k: `${key}-move`, buyer: key, svc: 'discovery', status: 'PAID', price: 0, title: 'Career clarity call', topic: 'Where to take my next role', min: 30, paidAt: daysAgo(2), decided: true, booking: { when: at(5, 18, 30), status: 'SCHEDULED', min: 30 } });
      await c.prisma.mentorServiceBooking.update({
        where: { purchaseId: idOf('buy', `${key}-move`) },
        data: { proposedScheduledAt: at(6, 19, 0), proposedById: c.users.get('anand')!, proposedAt: new Date(), proposedNote: 'A site visit came up that evening.' } as never,
      });
      await upsertPurchase(c, sf, { k: `${key}-held`, buyer: key, svc: 'review', status: 'FULFILLED', price: price('review'), title: 'Portfolio and CV review call', topic: 'CV review before applying', min: 60, paidAt: daysAgo(9), fulfilledAt: daysAgo(8), booking: { when: daysAgo(8), status: 'COMPLETED', min: 60 } });
    }
    await upsertTerm(c, sf, `${key}-coaching`, key, 'coaching', { status: 'ACTIVE', allowance: 2, used: 1, mentorshipId: idOf('pair', key, 'anand'), paidAt: daysAgo(10), periodEnd: new Date(Date.now() + 20 * DAY), total: 299900 });
    await upsertTerm(c, sf, `${key}-programme`, key, 'programme', { status: 'PENDING_MENTOR', allowance: 3, used: 0, total: 599900 });
  }
  // Anand's storefront history: completed work behind the earnings and the reviews.
  await upsertPurchase(c, sf, { k: 'tanvi-session', buyer: 'tanvi', svc: 'strategy', status: 'FULFILLED', price: price('strategy'), title: 'Facilities leadership strategy session', topic: 'Portfolio case', min: 45, paidAt: daysAgo(40), fulfilledAt: daysAgo(39), booking: { when: daysAgo(39), status: 'COMPLETED', min: 45 }, review: { rating: 5, comment: 'Worth every rupee: a concrete 90-day plan.', name: 'Tanvi Joshi' } });
  await upsertPurchase(c, sf, { k: 'arjun-kit', buyer: 'arjun', svc: 'kit', status: 'FULFILLED', price: price('kit'), type: 'RESOURCE', title: 'FM interview question bank', paidAt: daysAgo(12), fulfilledAt: daysAgo(12), review: { rating: 4, comment: 'Good questions; the model answers are a little short.', name: 'Arjun Mehta' } });
  await upsertPurchase(c, sf, { k: 'isha-requested', buyer: 'isha', svc: 'strategy', status: 'REQUESTED', price: price('strategy'), title: 'Facilities leadership strategy session', topic: 'A move to a regional role', min: 45 });
  await upsertPurchase(c, sf, { k: 'vikram-requested', buyer: 'vikram', svc: 'discovery', status: 'REQUESTED', price: 0, title: 'Career clarity call', topic: 'A panel next month', min: 30 });
  await upsertPurchase(c, sf, { k: 'sana-accepted', buyer: 'sana', svc: 'review', status: 'ACCEPTED', price: price('review'), title: 'Portfolio and CV review call', topic: 'A smart-building retrofit case', min: 60, when: at(5, 18, 30), payBy: at(4, 12), decided: true });
  await upsertPurchase(c, sf, { k: 'rahul-paid', buyer: 'rahul', svc: 'strategy', status: 'PAID', price: price('strategy'), title: 'Facilities leadership strategy session', topic: 'Operations to workplace strategy', min: 45, paidAt: daysAgo(3), decided: true, booking: { when: at(6, 19, 0), status: 'SCHEDULED', min: 45 } });
  await upsertTerm(c, sf, 'vikram-programme', 'vikram', 'programme', { status: 'PENDING_MENTOR', allowance: 3, used: 0, total: 599900 });
  await upsertTerm(c, sf, 'tanvi-coaching', 'tanvi', 'coaching', { status: 'ACTIVE', allowance: 2, used: 0, paidAt: daysAgo(4), periodEnd: new Date(Date.now() + 26 * DAY), total: 299900 });
  log('  purchases (requested, accepted, booked, product, declined; for Bharat also a payment due, a mentor move, a held session to review), plan terms, a storefront with earnings and reviews');

  // Group sessions hosted by Anand.
  const attend: { user: string; status: string }[] = [{ user: 'meera', status: 'REGISTERED' }, { user: 'tanvi', status: 'REGISTERED' }];
  if (bharat) attend.push({ user: bharat, status: 'REGISTERED' });
  await upsertGroup(c, 'clinic', { title: 'From site to portfolio: an open clinic', summary: 'An hour on how to frame a portfolio case. Bring a real one.', when: at(6, 19, 0), min: 60, status: 'SCHEDULED', attendees: attend });
  await upsertGroup(c, 'paid', { title: 'Panel interview masterclass', summary: 'A mock panel with live scoring.', when: at(12, 18, 0), min: 90, status: 'SCHEDULED', price: 29900, capacity: 15 });
  await upsertGroup(c, 'draft', { title: 'Salary negotiation circle', summary: 'A draft: not published yet.', when: at(20, 18, 0), min: 60, status: 'DRAFT' });
  const done: { user: string; status: string }[] = [{ user: 'meera', status: 'ATTENDED' }];
  if (bharat) done.push({ user: bharat, status: 'ATTENDED' });
  await upsertGroup(c, 'past', { title: 'Reading an SLA in twenty minutes', summary: 'A short clinic on the clauses that matter.', when: daysAgo(12), min: 60, status: 'COMPLETED', attendees: done });
  await seedProgramme(c, menteeIds);
  log('  group sessions (open, paid, draft, held) and a cohort programme');

  log('Done.');
  log('  sign in as mentoring.anand@design.icr.test (mentor desk), mentoring.meera@ (mentee), mentoring.kiran@ (applicant); Password123!');
  return { anandProfileId: sf.profileId, people: Object.fromEntries(c.users) };
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
  const subs = await prisma.mentorPlanSubscription.findMany({ where: { OR: [{ id: startsWith }, { plan: { id: startsWith } }] }, select: { id: true } });
  await step('plan terms', async () => {
    const ids = subs.map((s) => s.id);
    await prisma.mentorLedgerEntry.deleteMany({ where: { subscriptionId: { in: ids } } });
    await prisma.mentorPlanSubscriptionStep.deleteMany({ where: { subscriptionId: { in: ids } } });
    return prisma.mentorPlanSubscription.deleteMany({ where: { id: { in: ids } } });
  });
  await step('purchases', async () => {
    const purchases = await prisma.mentorServicePurchase.findMany({ where: { OR: [{ id: startsWith }, { service: { id: startsWith } }] }, select: { id: true } });
    const ids = purchases.map((p) => p.id);
    await prisma.mentorLedgerEntry.deleteMany({ where: { purchaseId: { in: ids } } });
    await prisma.mentorServiceReview.deleteMany({ where: { purchaseId: { in: ids } } });
    await prisma.mentorServiceBooking.deleteMany({ where: { purchaseId: { in: ids } } });
    return prisma.mentorServicePurchase.deleteMany({ where: { id: { in: ids } } });
  });
  await step('ledger entries', () => prisma.mentorLedgerEntry.deleteMany({ where: { mentorUserId: startsWith } }));
  await step('programme (and its places)', () => prisma.mentorshipProgram.deleteMany({ where: { id: startsWith } }));
  await step('group sessions', () => prisma.mentorshipGroupSession.deleteMany({ where: { id: startsWith } }));
  await step('certificates', () => prisma.mentorshipCertificate.deleteMany({ where: { id: startsWith } }));
  await step('concerns raised on the fixture pairings', () => prisma.mentorshipConcern.deleteMany({ where: { mentorship: { id: startsWith } } }));
  await step('pairings (sessions, goals, tasks, reviews follow)', async () => {
    const ps = await prisma.mentorship.findMany({ where: { OR: [{ id: startsWith }, { mentorProfile: { id: startsWith } }] }, select: { id: true } });
    return prisma.mentorship.deleteMany({ where: { id: { in: ps.map((p) => p.id) } } });
  });
  await step('mentee profiles', () => prisma.menteeProfile.deleteMany({ where: { id: startsWith } }));
  await step('mentor profiles (services, plans, hours, requests follow)', () => prisma.mentorProfile.deleteMany({ where: { id: startsWith } }));
  // Another account's rows that hang on a fixture person (a request the demo persona sent to one of them).
  await step('requests to or from fixture accounts', () => prisma.mentorshipRequest.deleteMany({ where: { OR: [{ id: startsWith }, { menteeId: startsWith }] } }));
  await step('notifications for the fixture accounts', () => prisma.notification.deleteMany({ where: { userId: startsWith } }));
  await step('audit entries made by the fixture accounts', () => prisma.auditLog.deleteMany({ where: { actorId: startsWith } }));
  await step('accounts', () => prisma.user.deleteMany({ where: { id: startsWith } }));
  await step('upload records', () => prisma.uploadedFile.deleteMany({ where: { filename: { startsWith: UP } } }));
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

if (require.main === module) {
  const prisma = new PrismaClient();
  seedMentoring(prisma, (m) => console.log(m), { remove: process.argv.includes('--remove') })
    .catch((e) => {
      console.error(e);
      process.exitCode = 1;
    })
    .finally(() => prisma.$disconnect());
}
