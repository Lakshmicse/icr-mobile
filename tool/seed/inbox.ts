/**
 * Seeds what the Notifications and Messages screens read, into the LOCAL portal
 * database, so the app's bell and inbox have real rows to show.
 *
 *   cd E:\ICR\irc-portal\backend          (cwd must be the backend folder: `uploads` resolves from it)
 *   NODE_PATH=E:/ICR/irc-portal/node_modules npx ts-node --transpile-only E:/ICR/icr-mobile/tool/seed/inbox.ts
 *   ... same command with --remove        (deletes exactly what this script created)
 *
 * Idempotent: every row has a stable id, and a re-run deletes and recreates the
 * conversations (so their "2 hours ago" and unread counts start again).
 *
 * Bharat Buyer (buyer@icr.dev, the emulator's person) gets:
 *   Notifications  nine rows across Today / This week / Earlier, four of them
 *                  unread (a grouped "3 messages", an application moving stage,
 *                  a company's message with its logo, a forum reply), pointing
 *                  at records the app opens (a conversation, an application, an
 *                  event, a purchase, the plans page) and one at a page the app
 *                  does not have (a support ticket), which opens the website.
 *   Conversations  on top of the two the Jobs builder's "Message" button made:
 *     sarah    a direct thread with Sarah Jenkins: a reply, a shared job link
 *              (drawn as a card), two messages waiting (unread 2);
 *     company  Global Infra Solutions' careers inbox: messages sent AS the
 *              company, one waiting (unread 1); the thread's kind is COMPANY;
 *     david    pinned and starred; a PDF attachment, a withdrawn message, and
 *              Bharat's last message already read ("Seen");
 *     rfq      a requirement thread: Bharat's own requirement with the supplier
 *              Bengaluru Care 101, whose seller has replied (unread 1);
 *     enquiry  a sales enquiry to the same supplier (no requirement behind it):
 *              "Send Message" on its listing reuses it;
 *     friend   a plain thread with Anita Rao, the Inbox Persona (below);
 *     room     the group session Bharat holds a seat at (made only while the
 *              session has no thread), unread 1;
 *     mentoring his pairing with Anand (made only while the pairing has no thread:
 *              the mentoring screens' own live runs may have made one, then it is left alone).
 *   Bharat is NOT in the two threads the live tests write in, so a run never moves his inbox:
 *     duo      Anita and the supplier's seller (a plain thread between two people);
 *     sandbox  Anita's enquiry to the supplier's inbox (the seller answers as the company;
 *              the supplier's people get a bell row for each message she sends).
 *
 * The Inbox Persona (Anita Rao, inbox.friend@inbox-seed.icr.test / Inbox@12345) is a
 * PROFESSIONAL nobody else uses: the live tests write as her. Each run resets her.
 *
 * Marker: ids start `inbox-seed-`; the PDF is /uploads/inbox-seed-site-checklist.pdf.
 * The people, company, requirement and jobs are the other seeds' and the portal's:
 * nothing of theirs is changed. Run it after `learning-jobs`, `events-councils` and
 * `home` (it reads Sarah, David, Global Infra, the design jobs and events).
 *
 * Refuses to run unless DATABASE_URL points at localhost.
 */
import type { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { existsSync, mkdirSync, readFileSync, unlinkSync, writeFileSync } from 'fs';
import { join } from 'path';

const MARK = 'inbox-seed-';
const FILE = 'inbox-seed-site-checklist.pdf';
const MIN = 60_000;
const HOUR = 60 * MIN;
const DAY = 24 * HOUR;

const BHARAT = 'buyer@icr.dev';

/** The person the live tests write as: a PROFESSIONAL nobody else uses. Reset by every run. */
export const PERSONA_EMAIL = 'inbox.friend@inbox-seed.icr.test';
export const PERSONA_PASSWORD = 'Inbox@12345';
const PERSONA_ID = `${MARK}u-anita`;
const SELLER = 'vendor@icr.dev';

/** DATABASE_URL from the environment, else from `.env` in the cwd. */
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
  if (!existsSync(join(process.cwd(), 'prisma', 'schema.prisma'))) {
    throw new Error(`Run this from E:\\ICR\\irc-portal\\backend (cwd is ${process.cwd()}): uploads resolve from it.`);
  }
}

/** A one-page, text-only PDF (Helvetica, ASCII): something real for a message's attachment to open. */
function checklistPdf(): Buffer {
  const lines = [
    'Site feasibility checklist',
    '',
    '1. Access and frontage: road width, turning circle, service entry.',
    '2. Utilities: power load, chilled water, fire water, telecom risers.',
    '3. Compliance: zoning, fire NOC, environmental clearance.',
    '4. Operations: loading dock, waste yard, security posture.',
    '5. Cost: capex against a 10 year maintenance forecast.',
  ];
  const esc = (s: string) => s.replace(/\\/g, '\\\\').replace(/\(/g, '\\(').replace(/\)/g, '\\)');
  const ops = ['BT', '/F1 18 Tf', '1 0 0 1 56 780 Tm', `(${esc(lines[0])}) Tj`, '/F1 11 Tf'];
  let y = 748;
  for (const line of lines.slice(1)) {
    ops.push(`1 0 0 1 56 ${y} Tm (${esc(line)}) Tj`);
    y -= 18;
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

type Msg = {
  /** Short key, becomes `inbox-seed-m-<conv>-<key>`. */
  key: string;
  from: string;
  body: string;
  /** Minutes before now. */
  ago: number;
  read?: boolean;
  /** Sent as this company (its inbox). */
  asCompanyId?: string;
  replyTo?: string;
  attachment?: { url: string; name: string; size: number; mime: string };
  deleted?: boolean;
};

export async function seedInbox(
  prisma: PrismaClient,
  log: (m: string) => void,
  opts: { remove?: boolean } = {},
): Promise<void> {
  assertLocal();
  const target = join(process.cwd(), 'uploads', FILE);

  // --- take out what a previous run left -----------------------------------
  const oldConversations = await prisma.conversation.findMany({ where: { id: { startsWith: MARK } }, select: { id: true } });
  await prisma.conversation.deleteMany({ where: { id: { startsWith: MARK } } });
  await prisma.notification.deleteMany({ where: { id: { startsWith: MARK } } });
  // What the live runs left: a seller's bell row for each message the persona sent to the supplier's inbox
  // (they link to a seeded thread), and the persona's own rows.
  const left = await prisma.notification.deleteMany({ where: { link: { contains: `c=${MARK}conv-` } } });
  const persona = await prisma.user.findUnique({ where: { email: PERSONA_EMAIL }, select: { id: true } });
  if (persona) await prisma.notification.deleteMany({ where: { userId: persona.id } });
  if (left.count) log(`  cleared ${left.count} notification(s) the live runs left`);
  await prisma.uploadedFile.deleteMany({ where: { filename: FILE } });
  if (existsSync(target)) unlinkSync(target);
  if (oldConversations.length) log(`  removed ${oldConversations.length} earlier seeded conversations`);
  if (opts.remove) {
    if (persona) {
      await prisma.auditLog.deleteMany({ where: { actorId: persona.id } });
      await prisma.user.deleteMany({ where: { id: persona.id } });
      log('removed the Inbox Persona');
    }
    log('removed the seeded notifications and conversations');
    return;
  }

  const email = (e: string) => prisma.user.findUnique({ where: { email: e }, select: { id: true, firstName: true, lastName: true } });
  const byId = (id: string) => prisma.user.findUnique({ where: { id }, select: { id: true, firstName: true, lastName: true } });
  const anita = await prisma.user.upsert({
    where: { email: PERSONA_EMAIL },
    update: { passwordHash: bcrypt.hashSync(PERSONA_PASSWORD, 10), isActive: true },
    create: {
      id: PERSONA_ID,
      email: PERSONA_EMAIL,
      passwordHash: bcrypt.hashSync(PERSONA_PASSWORD, 10),
      firstName: 'Anita',
      lastName: 'Rao',
      role: 'PROFESSIONAL' as never,
      emailVerifiedAt: new Date(),
      designation: 'Facilities analyst (mobile inbox seed)',
    },
    select: { id: true, firstName: true, lastName: true },
  });
  log(`  ${PERSONA_EMAIL} / ${PERSONA_PASSWORD}: the Inbox Persona (live tests write as her)`);
  const [bharat, seller, sarah, david, priya, marcus] = await Promise.all([
    email(BHARAT),
    email(SELLER),
    byId('design-home-user-sarah'),
    byId('design-home-user-david'),
    byId('cmvkf54xx000imyp0vsbzy33b'),
    byId('design-home-user-marcus'),
  ]);
  if (!bharat) throw new Error(`${BHARAT} does not exist in this database: run the portal's seeds first.`);

  const company = await prisma.company.findFirst({ where: { id: 'design-lj-co-global-infra' }, select: { id: true, name: true } });
  const supplier = await prisma.company.findFirst({ where: { vendor: { isNot: null }, name: 'Bengaluru Care 101' }, select: { id: true, name: true } });
  const rfq = await prisma.rfq.findFirst({
    where: { buyerId: bharat.id, status: 'PUBLISHED' },
    orderBy: { createdAt: 'asc' },
    select: { id: true, title: true },
  });
  const now = Date.now();
  const at = (agoMin: number) => new Date(now - agoMin * MIN);

  // --- the attachment --------------------------------------------------------
  mkdirSync(join(process.cwd(), 'uploads'), { recursive: true });
  const pdf = checklistPdf();
  writeFileSync(target, pdf);
  if (david) {
    await prisma.uploadedFile.create({
      data: {
        filename: FILE,
        visibility: 'PRIVATE',
        purpose: 'message-attachment',
        ownerId: david.id,
        name: 'Site feasibility checklist.pdf',
        mimeType: 'application/pdf',
        size: pdf.length,
      },
    });
  }

  // --- conversations ---------------------------------------------------------
  async function conversation(
    key: string,
    people: (string | undefined)[],
    messages: Msg[],
    extra: {
      title?: string;
      rfqId?: string;
      parties?: { companyId: string; topic: 'SALES' | 'PROCUREMENT' | 'CAREERS' | 'PARTNERSHIP' | 'GENERAL' }[];
      pinned?: boolean;
      starred?: boolean;
      /** A thread Bharat is not in (the live tests' sandbox). */
      outsider?: boolean;
    } = {},
  ): Promise<string | null> {
    const ids = people.filter((p): p is string => !!p);
    if (ids.length < (extra.parties?.length ? 1 : 2) || (!extra.outsider && !ids.includes(bharat!.id))) {
      log(`  skipped "${key}": one of its people is not in this database`);
      return null;
    }
    const id = `${MARK}conv-${key}`;
    const last = messages.reduce((m, x) => Math.min(m, x.ago), Infinity);
    await prisma.conversation.create({
      data: {
        id,
        title: extra.title,
        rfqId: extra.rfqId,
        createdAt: at(Math.max(...messages.map((m) => m.ago)) + 5),
        updatedAt: at(last),
        participants: { connect: ids.map((p) => ({ id: p })) },
        companies: extra.parties ? { create: extra.parties } : undefined,
        messages: {
          create: messages.map((m) => ({
            id: `${MARK}m-${key}-${m.key}`,
            senderId: m.from,
            senderCompanyId: m.asCompanyId ?? null,
            body: m.deleted ? '' : m.body,
            createdAt: at(m.ago),
            readAt: m.read ? at(Math.max(m.ago - 3, 1)) : null,
            replyToId: m.replyTo ? `${MARK}m-${key}-${m.replyTo}` : null,
            attachmentUrl: m.attachment?.url ?? null,
            attachmentName: m.attachment?.name ?? null,
            attachmentSize: m.attachment?.size ?? null,
            attachmentMime: m.attachment?.mime ?? null,
            deletedAt: m.deleted ? at(Math.max(m.ago - 20, 1)) : null,
          })),
        },
      },
    });
    if (extra.pinned || extra.starred) {
      await prisma.conversationPreference.create({
        data: {
          conversationId: id,
          userId: bharat!.id,
          starredAt: extra.starred ? at(60) : null,
          pinnedAt: extra.pinned ? at(60) : null,
        },
      });
    }
    log(`  conversation ${key}: ${messages.length} messages`);
    return id;
  }

  const B = bharat.id;
  const convSarah = sarah
    ? await conversation('sarah', [B, sarah.id], [
        { key: '1', from: B, ago: 2 * 24 * 60 + 95, read: true, body: 'Hi Sarah, your post on AI in site feasibility was a great read. Do you have the checklist you mentioned?' },
        { key: '2', from: sarah.id, ago: 2 * 24 * 60 + 60, read: true, replyTo: '1', body: 'Thanks Bharat! Yes, I will send it across today.' },
        { key: '3', from: sarah.id, ago: 26 * 60, read: true, body: 'One more thing: this role might suit someone in your network.\nhttps://icr.org.in/jobs/design-lj-job-extra-1' },
        { key: '4', from: sarah.id, ago: 35, body: 'Did you get a chance to look at it?' },
        { key: '5', from: sarah.id, ago: 34, body: 'Happy to jump on a quick call this week if that helps.' },
      ])
    : null;

  const convCompany = company && priya
    ? await conversation(
        'company',
        [B],
        [
          { key: '1', from: B, ago: 3 * 24 * 60, read: true, body: 'Hello, is the Facilities Manager role open to candidates relocating from Pune?' },
          { key: '2', from: priya.id, asCompanyId: company.id, ago: 3 * 24 * 60 - 70, read: true, body: 'Hi Bharat, yes. Relocation support is available for this role, and we are happy to talk through the details.' },
          { key: '3', from: priya.id, asCompanyId: company.id, ago: 5 * 60, body: 'We would like to set up an introductory call on Thursday. Does 11 am work for you?' },
        ],
        { parties: [{ companyId: company.id, topic: 'CAREERS' }] },
      )
    : null;

  const convDavid = david
    ? await conversation(
        'david',
        [B, david.id],
        [
          {
            key: '1',
            from: david.id,
            ago: 4 * 24 * 60 + 30,
            read: true,
            body: 'Here is the checklist we use for new campus sites.',
            attachment: { url: `/uploads/${FILE}`, name: 'Site feasibility checklist.pdf', size: pdf.length, mime: 'application/pdf' },
          },
          { key: '2', from: B, ago: 4 * 24 * 60 + 10, read: true, body: 'Thanks David, this is very useful.' },
          { key: '3', from: david.id, ago: 4 * 24 * 60, read: true, body: 'Ignore my earlier note about the budget.', deleted: true },
          { key: '4', from: B, ago: 3 * 24 * 60, read: true, body: "Let's talk next week once the shortlist is in." },
        ],
        { pinned: true, starred: true },
      )
    : null;

  const sellerUser = seller;
  const convRfq = rfq && supplier && sellerUser
    ? await conversation(
        'rfq',
        [B],
        [
          { key: '1', from: B, ago: 24 * 60, read: true, body: 'Can you confirm your monthly rate for 40 housekeeping staff at our Mumbai HQ?' },
          { key: '2', from: sellerUser.id, asCompanyId: supplier.id, ago: 20 * 60, body: 'Yes. Our rate is ₹18,500 per person per month, including supervision and consumables.' },
        ],
        { title: rfq.title, rfqId: rfq.id, parties: [{ companyId: supplier.id, topic: 'SALES' }] },
      )
    : null;

  const convFriend = await conversation('friend', [B, anita.id], [
    { key: '1', from: B, ago: 6 * 24 * 60, read: true, body: 'Hi Anita, welcome to ICR!' },
    { key: '2', from: anita.id, ago: 6 * 24 * 60 - 30, read: true, body: 'Thank you Bharat, glad to be here.' },
  ]);

  // A plain thread between the persona and the supplier's seller (Bharat is not in it): the live tests send,
  // read, reply to and withdraw messages here, so Bharat's own inbox is never moved by a run.
  const convDuo = sellerUser
    ? await conversation(
        'duo',
        [anita.id, sellerUser.id],
        [
          { key: '1', from: sellerUser.id, ago: 9 * 24 * 60, read: true, body: 'Hi Anita, thanks for your enquiry.' },
          { key: '2', from: anita.id, ago: 9 * 24 * 60 - 20, read: true, body: 'Thank you, I will send the site details.' },
        ],
        { outsider: true },
      )
    : null;

  // The persona's enquiry to the supplier (the thread the live tests write in: it is not in Bharat's inbox, and
  // the supplier's people are the ones who get a bell row for it).
  const convSandbox = supplier
    ? await conversation(
        'sandbox',
        [anita.id],
        [{ key: '1', from: anita.id, ago: 8 * 24 * 60, read: true, body: 'Hello, do you cover facilities in Chennai?' }],
        { title: `Enquiry · ${supplier.name}`, parties: [{ companyId: supplier.id, topic: 'SALES' }], outsider: true },
      )
    : null;

  // Bharat's enquiry to the supplier (a sales thread with no requirement behind it): "Send Message" on a supplier
  // listing reuses it, so the live tests never make one each run.
  const convEnquiry =
    supplier && sellerUser
      ? await conversation(
          'enquiry',
          [B],
          [
            { key: '1', from: B, ago: 6 * 24 * 60, read: true, body: 'Do you also cover facilities in Chennai?' },
            { key: '2', from: sellerUser.id, asCompanyId: supplier.id, ago: 6 * 24 * 60 - 90, read: true, body: 'Yes, from our Chennai office. Tell us the site and we will send a quote.' },
          ],
          { title: `Enquiry · ${supplier.name}`, parties: [{ companyId: supplier.id, topic: 'SALES' }] },
        )
      : null;

  // Mentoring and a group room: the threads Message on a pairing / a group session opens. They are made only when
  // the pairing or the session has none yet (the mentoring screens' own live runs may have made one), and the
  // pairing or session is pointed at ours; deleting ours (a re-run, --remove) sets that pointer back to nothing.
  let convMentoring: string | null = null;
  const pairing = await prisma.mentorship.findUnique({ where: { id: 'dsgn-mentoring-pair-bharat-anand' }, select: { id: true, mentorId: true, conversationId: true } });
  if (pairing && !pairing.conversationId) {
    convMentoring = await conversation(
      'mentoring',
      [B, pairing.mentorId],
      [
        { key: '1', from: pairing.mentorId, ago: 5 * 24 * 60, read: true, body: 'Great first session. Please send me the CV draft before we meet again.' },
        { key: '2', from: B, ago: 4 * 24 * 60, read: true, body: 'Will do, sending it tonight.' },
      ],
      { title: 'Mentoring · Bharat & Anand' },
    );
    if (convMentoring) await prisma.mentorship.update({ where: { id: pairing.id }, data: { conversationId: convMentoring } });
  } else if (pairing) {
    log('  mentoring: the pairing already has a thread (not ours): left alone');
  }
  let convRoom: string | null = null;
  const session = await prisma.mentorshipGroupSession.findUnique({ where: { id: 'dsgn-mentoring-group-clinic' }, select: { id: true, hostId: true, title: true, conversationId: true } });
  if (session && !session.conversationId) {
    convRoom = await conversation(
      'room',
      [B, session.hostId],
      [
        { key: '1', from: session.hostId, ago: 2 * 24 * 60, read: true, body: 'Slides for the clinic are up on the session page.' },
        { key: '2', from: session.hostId, ago: 3 * 60, body: 'Bring a question about your own portfolio: we will take them live.' },
      ],
      { title: `Group session · ${session.title}` },
    );
    if (convRoom) await prisma.mentorshipGroupSession.update({ where: { id: session.id }, data: { conversationId: convRoom } });
  } else if (session) {
    log('  room: the session already has a thread (not ours): left alone');
  }

  // --- notifications ----------------------------------------------------------
  type Note = {
    key: string;
    ago: number;
    type: string;
    title: string;
    body?: string;
    link?: string;
    kind?: string;
    ref?: string;
    actor?: string;
    actorCompany?: string;
    count?: number;
    group?: string;
    read?: boolean;
  };
  const notes: Note[] = [];
  if (sarah && convSarah) {
    notes.push({
      key: 'msg-sarah', ago: 12, type: 'message', title: 'Sarah Jenkins sent you 3 messages', actor: sarah.id, count: 3,
      link: `/messaging?c=${convSarah}`, kind: 'conversation', ref: convSarah, group: `conversation:${convSarah}`,
    });
  }
  notes.push({
    key: 'app-stage', ago: 3 * 60, type: 'application_stage_changed', title: 'Your application for Energy and Sustainability Lead moved to Screening',
    body: 'Global Infra Solutions will be in touch about the next step.', link: '/career/applications/design-lj-app-bharat-extra-2',
    kind: 'application.candidate', ref: 'design-lj-app-bharat-extra-2',
  });
  if (company && priya && convCompany) {
    notes.push({
      key: 'msg-company', ago: 5 * 60 + 5, type: 'message', title: 'Global Infra Solutions sent you a message', actor: priya.id, actorCompany: company.id,
      link: `/messaging?c=${convCompany}`, kind: 'conversation', ref: convCompany, group: `conversation:${convCompany}`,
    });
  }
  notes.push({
    key: 'event', ago: 26 * 60, type: 'event_reminder', title: 'Reminder: Future of AI in Facility Management starts tomorrow',
    body: 'Doors open at 9:00 am. Your place is confirmed.', link: '/events/future-of-ai-in-facility-management-design', kind: 'event',
    ref: 'design-ev-ai', read: true,
  });
  if (marcus) {
    notes.push({
      key: 'forum', ago: 2 * 24 * 60 + 40, type: 'forum_reply', title: 'Marcus Reed replied to your discussion',
      body: 'We ran a similar retrofit last year and the phasing mattered more than the vendor.',
      link: '/community/shortlisting-a-bms-retrofit-partner-for-a-12-site-campus-portfolio-bharat-1-home-design', kind: 'forum.thread',
      ref: 'design-home-thread-bharat-1', actor: marcus.id,
    });
  }
  notes.push({
    key: 'purchase', ago: 4 * 24 * 60, type: 'mentor_service_purchase_confirmed', title: 'Your 1:1 session is booked',
    body: 'Open the session to see the time and the meeting link.', link: '/mentorship/my?tab=purchases&purchase=cmvkxoda601anmyx4y7j9f8d6',
    kind: 'mentorship.mine', ref: 'cmvkxoda601anmyx4y7j9f8d6', read: true,
  });
  notes.push({
    key: 'plan', ago: 9 * 24 * 60, type: 'subscription_expiring', title: 'Your Professional plan ends in 7 days',
    body: 'Renew to keep your member discounts and mentor session credits.', link: '/career/plans', kind: 'membership.plans', read: true,
  });
  notes.push({
    key: 'reward', ago: 15 * 24 * 60, type: 'referral_reward', title: 'ICR gave you 100 ICR credits', body: 'Referral reward', link: '/refer/credits',
    kind: 'refer', read: true,
  });
  notes.push({
    key: 'ticket', ago: 20 * 24 * 60, type: 'support_reply', title: 'Support replied to your request',
    body: 'We have fixed the invoice address. Tell us if anything still looks wrong.', link: '/support/inbox-seed-ticket', kind: 'support.ticket',
    ref: 'inbox-seed-ticket', read: true,
  });
  for (const n of notes) {
    await prisma.notification.create({
      data: {
        id: `${MARK}n-${n.key}`,
        userId: bharat.id,
        actorId: n.actor ?? null,
        actorCompanyId: n.actorCompany ?? null,
        title: n.title,
        body: n.body ?? null,
        type: n.type,
        link: n.link ?? null,
        targetKind: n.kind ?? null,
        targetId: n.ref ?? null,
        groupKey: n.group ?? null,
        count: n.count ?? 1,
        readAt: n.read ? at(n.ago - 5) : null,
        createdAt: at(n.ago),
      },
    });
  }
  log(`  ${notes.length} notifications (${notes.filter((n) => !n.read).length} unread)`);
  log(`  conversations: ${[convSarah, convCompany, convDavid, convRfq, convFriend, convDuo, convSandbox, convEnquiry, convMentoring, convRoom].filter(Boolean).length} made`);
}

if (require.main === module) {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { PrismaClient: Client } = require('@prisma/client') as typeof import('@prisma/client');
  const prisma = new Client();
  seedInbox(prisma, (m) => console.log(m), { remove: process.argv.includes('--remove') })
    .catch((e) => {
      console.error(e);
      process.exitCode = 1;
    })
    .finally(() => prisma.$disconnect());
}
