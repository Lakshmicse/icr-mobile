/**
 * Gives the demo personas the header photo the designs show (the "me" photo in
 * assets/images/demo/avatar_me.jpg), so the app's header, profile menu and
 * posts read like the PNGs instead of showing initials.
 *
 *   cd E:\ICR\irc-portal\backend          (cwd must be the backend folder: `uploads` resolves from it)
 *   NODE_PATH=E:/ICR/irc-portal/node_modules npx ts-node --transpile-only E:/ICR/icr-mobile/tool/seed/persona.ts
 *   ... same command with --remove        (puts back the photos they had before)
 *
 * Idempotent. Changes one column on two existing accounts, Bharat Buyer
 * (buyer@icr.dev) and Pooja Professional (professional@icr.test): the photo
 * they had is kept in Setting `design-seed:persona` and `--remove` restores it.
 * The file is /uploads/design-persona-me.jpg. Refuses to run unless the
 * database is on localhost.
 */
import type { PrismaClient } from '@prisma/client';
import { copyFileSync, existsSync, mkdirSync, readFileSync, unlinkSync } from 'fs';
import { join, resolve } from 'path';

const KEY = 'design-seed:persona';
const EMAILS = ['buyer@icr.dev', 'professional@icr.test'];
const FILE = 'design-persona-me.jpg';
const SOURCE = resolve(__dirname, '..', '..', 'assets', 'images', 'demo', 'avatar_me.jpg');

type Manifest = { before: Record<string, string | null> };

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

export async function seedPersona(
  prisma: PrismaClient,
  log: (m: string) => void,
  opts: { remove?: boolean } = {},
): Promise<void> {
  assertLocal();
  const row = await prisma.setting.findUnique({ where: { key: KEY }, select: { value: true } });
  const manifest: Manifest = (row?.value as Manifest | null) ?? { before: {} };
  const target = join(process.cwd(), 'uploads', FILE);

  if (opts.remove) {
    for (const [email, avatarUrl] of Object.entries(manifest.before)) {
      await prisma.user.updateMany({ where: { email }, data: { avatarUrl } });
      log(`  restored the photo of ${email}`);
    }
    if (existsSync(target)) unlinkSync(target);
    await prisma.setting.deleteMany({ where: { key: KEY } });
    log('removed the persona photos');
    return;
  }

  if (!existsSync(SOURCE)) throw new Error(`Missing ${SOURCE}`);
  mkdirSync(join(process.cwd(), 'uploads'), { recursive: true });
  copyFileSync(SOURCE, target);

  const users = await prisma.user.findMany({ where: { email: { in: EMAILS } }, select: { email: true, avatarUrl: true } });
  for (const u of users) {
    // Remember what was there the first time only, never our own photo.
    if (!(u.email in manifest.before)) manifest.before[u.email] = u.avatarUrl === `/uploads/${FILE}` ? null : u.avatarUrl;
    await prisma.user.updateMany({ where: { email: u.email }, data: { avatarUrl: `/uploads/${FILE}` } });
    log(`  ${u.email}: header photo set`);
  }
  await prisma.setting.upsert({
    where: { key: KEY },
    update: { value: manifest as never },
    create: { key: KEY, value: manifest as never },
  });
  if (users.length === 0) log('  none of the personas exist in this database');
}

if (require.main === module) {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { PrismaClient: Client } = require('@prisma/client') as typeof import('@prisma/client');
  const prisma = new Client();
  seedPersona(prisma, (m) => console.log(m), { remove: process.argv.includes('--remove') })
    .catch((e) => {
      console.error(e);
      process.exitCode = 1;
    })
    .finally(() => prisma.$disconnect());
}
