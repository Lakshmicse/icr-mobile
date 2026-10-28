/**
 * Gives the mobile app's STUDY screens (Flash Cards, Knowledge Center) a person who can study.
 *
 *   cd E:\ICR\irc-portal\backend          (cwd must be the backend folder)
 *   NODE_PATH=E:/ICR/irc-portal/node_modules npx ts-node --transpile-only E:/ICR/icr-mobile/tool/seed/learning-study.ts
 *   ... same command with --remove               (deletes exactly what this script created)
 *   ... same command with --grant-bharat         (ALSO gives Bharat Buyer the same flash-card places: see below)
 *   ... same command with --grant <email> ...    (the same for any other existing account)
 *   ... add --places N to either grant flag      (N places instead of 3, e.g. --grant-bharat --places 12)
 *
 * Why it exists. The decks and formulas are already in the local database (31 flash-card decks of about 200
 * cards each, 4 formula shelves), but a flash-card deck counts against the member's plan
 * (`learning.assessmentCourses`, the number that opens Assess your knowledge courses AND as many decks), and
 * Bharat Buyer's and Pooja Professional's plans open 0, so the API answers every deck with 403 DECK_LOCKED
 * ("Flash-card decks are not included in your plan."). That refusal is real and the app shows it; it also
 * means neither persona can study a deck. This script makes the person who can:
 *
 *   Study Persona   study.cards@learning-study.icr.test / Study@12345   (a PROFESSIONAL)
 *     holds a benefit grant (BenefitGrant, an OVERRIDE of `learning.assessmentCourses`) of THREE places, so
 *     the first three decks they open (the live test opens the first three in catalogue order) are theirs and
 *     the fourth is refused with the API's own sentence ("Your plan opens 3 flash-card decks, and you have
 *     opened them all."): both halves of the plan lock are provable. Re-opening a deck already open takes no
 *     further place, so the live test can run again and again.
 *
 * `--grant-bharat` gives Bharat Buyer, the person the emulator is signed in as, the same grant so the owner can
 * study on the emulator. It is OFF by default because the same number also opens his Assess your knowledge
 * courses, which the assessment screens read (their locks change from "none included" to "pick one of 3"):
 * run it only when you want that. The script remembers whom it granted: a run without the flag takes the grant
 * back and forgets the decks that person opened, and so does `--remove`. The API caches a person's grants for a
 * minute.
 *
 * Marker (what --remove finds): ids start `design-study-`, the email ends @learning-study.icr.test, the grant's
 * reason starts "mobile study seed". Local database only: refuses to run unless DATABASE_URL is on localhost.
 */
import type { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { existsSync, readFileSync } from 'fs';
import { join } from 'path';

const MARK = 'design-study-';
const EMAIL = 'study.cards@learning-study.icr.test';
const PASSWORD = 'Study@12345';
const KEY = 'learning.assessmentCourses';
const PLACES = 3;
const REASON = 'mobile study seed (tool/seed/learning-study.ts): lets the persona open flash-card decks';
const MANIFEST_KEY = 'design-seed:learning-study';
const BHARAT = 'buyer@icr.dev';

/** The accounts other than the persona that this script gave places to. */
type Manifest = { granted?: string[] };

const grantId = (email: string) => `${MARK}grant-${email.replace(/[^a-z0-9]+/gi, '-').toLowerCase()}`;

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
    throw new Error(`Run this from E:\\ICR\\irc-portal\\backend (cwd is ${process.cwd()}).`);
  }
  if (process.env.NODE_ENV === 'production') throw new Error('Refusing to seed a development password into production.');
}

async function grantTo(prisma: PrismaClient, userId: string, id: string, places = PLACES): Promise<void> {
  const data = { userId, key: KEY, kind: 'OVERRIDE' as never, enabled: false, limitValue: places, reason: REASON };
  await prisma.benefitGrant.upsert({
    where: { id },
    update: { ...data, startsAt: new Date(Date.now() - 60_000), expiresAt: null, revokedAt: null },
    create: { id, ...data, startsAt: new Date(Date.now() - 60_000) },
  });
}

/** Takes the places away from [email] and forgets the decks they opened. */
async function revoke(prisma: PrismaClient, email: string, log: (m: string) => void): Promise<void> {
  await prisma.benefitGrant.deleteMany({ where: { id: grantId(email) } });
  const user = await prisma.user.findUnique({ where: { email }, select: { id: true } });
  if (!user) return;
  const opens = await prisma.learningPlanOpen.deleteMany({ where: { userId: user.id, kind: 'FLASH_CARD_DECK' } });
  log(`  ${email}: places taken back, ${opens.count} opened deck(s) forgotten`);
}

export async function seedLearningStudy(
  prisma: PrismaClient,
  log: (m: string) => void,
  opts: { remove?: boolean; grant?: string[]; places?: number } = {},
): Promise<void> {
  assertLocal();
  const settings = await prisma.setting.findUnique({ where: { key: MANIFEST_KEY }, select: { value: true } });
  const manifest: Manifest = (settings?.value as Manifest | null) ?? {};
  const before = manifest.granted ?? [];

  if (opts.remove) {
    for (const email of before) await revoke(prisma, email, log);
    const users = await prisma.user.findMany({ where: { email: { endsWith: '@learning-study.icr.test' } }, select: { id: true } });
    const grants = await prisma.benefitGrant.deleteMany({ where: { id: { startsWith: MARK } } });
    const ids = users.map((u) => u.id);
    // Signing in writes audit rows that point at the account; they are this persona's own, so they go with it.
    const audit = await prisma.auditLog.deleteMany({ where: { actorId: { in: ids } } });
    await prisma.user.deleteMany({ where: { id: { in: ids } } });
    await prisma.setting.deleteMany({ where: { key: MANIFEST_KEY } });
    log(`removed ${users.length} persona(s), ${grants.count} grant(s) and ${audit.count} audit row(s)`);
    return;
  }

  const user = await prisma.user.upsert({
    where: { email: EMAIL },
    update: { passwordHash: bcrypt.hashSync(PASSWORD, 10), isActive: true },
    create: {
      id: `${MARK}u-cards`,
      email: EMAIL,
      passwordHash: bcrypt.hashSync(PASSWORD, 10),
      firstName: 'Study',
      lastName: 'Persona',
      role: 'PROFESSIONAL' as never,
      emailVerifiedAt: new Date(),
      designation: 'Facilities analyst (mobile study seed)',
    },
  });
  await grantTo(prisma, user.id, `${MARK}grant-cards`);
  log(`  ${EMAIL} / ${PASSWORD}: ${PLACES} flash-card places (and as many Assess your knowledge courses)`);

  const wanted = [...new Set((opts.grant ?? []).map((e) => e.trim().toLowerCase()).filter(Boolean))];
  for (const email of wanted) {
    const person = await prisma.user.findUnique({ where: { email }, select: { id: true } });
    if (!person) throw new Error(`${email} does not exist in this database.`);
    await grantTo(prisma, person.id, grantId(email), opts.places ?? PLACES);
    log(`  ${email}: ${opts.places ?? PLACES} places too (the API caches grants for a minute)`);
  }
  // The flags are the single switch: whoever was granted before and is not named now loses the places.
  for (const email of before.filter((e) => !wanted.includes(e))) await revoke(prisma, email, log);

  await prisma.setting.upsert({
    where: { key: MANIFEST_KEY },
    update: { value: { granted: wanted } as never },
    create: { key: MANIFEST_KEY, value: { granted: wanted } as never },
  });
}

if (require.main === module) {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { PrismaClient: Client } = require('@prisma/client') as typeof import('@prisma/client');
  const prisma = new Client();
  const args = process.argv.slice(2);
  const grant: string[] = [];
  args.forEach((a, i) => {
    if (a === '--grant-bharat') grant.push(BHARAT);
    if (a === '--grant' && args[i + 1]) grant.push(args[i + 1]);
  });
  const at = args.indexOf('--places');
  const places = at >= 0 ? Number(args[at + 1]) : undefined;
  if (places !== undefined && !(Number.isInteger(places) && places > 0)) throw new Error('--places takes a whole number.');
  seedLearningStudy(prisma, (m) => console.log(m), { remove: args.includes('--remove'), grant, places })
    .catch((e) => {
      console.error(e);
      process.exitCode = 1;
    })
    .finally(() => prisma.$disconnect());
}
