/**
 * What the mentor desk's OFFERINGS live tests leave behind in the LOCAL database, swept out.
 *
 * `test/live/mentor_offerings_live_test.dart` makes its own rows and takes them away again:
 * services and plans are deleted (the API soft-deletes them, and `tool/seed/mentoring.ts --remove`
 * removes them with the mentor profile). Two things the API cannot take away:
 *
 *   - a GROUP SESSION has no delete route, so each run leaves one CANCELLED session hosted by
 *     Anand (a cuid id, not a `dsgn-mentoring-` one), which would stop `mentoring.ts --remove`
 *     deleting his account;
 *   - an UPLOAD has no delete route either: each run stores a few bytes for a resource file and a
 *     cover (purposes `mentor-resource` and `mentor-offering`) under random names.
 *
 *   cd E:\ICR\irc-portal\backend
 *   $env:NODE_PATH = 'E:/ICR/irc-portal/node_modules'
 *   npx ts-node --transpile-only E:/ICR/icr-mobile/tool/seed/mentoring_offerings.ts --remove
 *
 * Run it BEFORE `mentoring.ts --remove` (the seed has nothing of its own to add: the Offerings tests read
 * the rows `mentoring.ts` makes). It touches only what belongs to the fixture accounts
 * (`dsgn-mentoring-` ids) and never the seeded rows. LOCAL ONLY: it refuses to run against any other database.
 */
import { PrismaClient } from '@prisma/client';
import { existsSync, readFileSync, rmSync } from 'fs';
import { join } from 'path';

const PREFIX = 'dsgn-mentoring-';
const UP = 'design-mentoring-';

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
    throw new Error(`Refusing to touch a database that is not local (host "${host}").`);
  }
  if (process.env.NODE_ENV === 'production') throw new Error('Refusing to run with NODE_ENV=production.');
  return `${host}:${u.port || '5432'}${u.pathname}`;
}

function assertBackendCwd() {
  if (!existsSync(join(process.cwd(), 'prisma', 'schema.prisma'))) {
    throw new Error(`Run this from the portal's backend folder (E:\\ICR\\irc-portal\\backend); cwd is ${process.cwd()}.`);
  }
}

export async function removeOfferingsLeftovers(prisma: PrismaClient, log: (m: string) => void = console.log) {
  assertBackendCwd();
  const where = assertLocalDatabase();
  log(`Sweeping the Offerings live tests' leftovers from ${where} ...`);

  // Group sessions the fixture mentors host that this seed did not make (their ids are not prefixed).
  const sessions = await prisma.mentorshipGroupSession.findMany({
    where: { hostId: { startsWith: PREFIX }, NOT: { id: { startsWith: PREFIX } } },
    select: { id: true },
  });
  const ids = sessions.map((s) => s.id);
  if (ids.length) {
    // Rows that hang on a session, in the order the schema needs.
    await prisma.mentorshipGroupAttendee.deleteMany({ where: { sessionId: { in: ids } } });
    await prisma.mentorshipGroupSessionOccurrence.deleteMany({ where: { sessionId: { in: ids } } });
  }
  const gone = await prisma.mentorshipGroupSession.deleteMany({ where: { id: { in: ids } } });
  log(`  group sessions: ${gone.count}`);

  // Stored files of a resource or a cover made by a fixture account (the seed's own files start with design-mentoring-).
  const files = await prisma.uploadedFile.findMany({
    where: {
      ownerId: { startsWith: PREFIX },
      purpose: { in: ['mentor-resource', 'mentor-offering'] },
      NOT: { filename: { startsWith: UP } },
    },
    select: { filename: true },
  });
  let unlinked = 0;
  for (const f of files) {
    const abs = join(process.cwd(), 'uploads', f.filename);
    if (existsSync(abs)) {
      rmSync(abs);
      unlinked += 1;
    }
  }
  const records = await prisma.uploadedFile.deleteMany({ where: { filename: { in: files.map((f) => f.filename) } } });
  log(`  upload records: ${records.count}, files in backend/uploads: ${unlinked}`);
  log('Done.');
}

if (require.main === module) {
  const prisma = new PrismaClient();
  const remove = process.argv.includes('--remove');
  (remove
    ? removeOfferingsLeftovers(prisma)
    : Promise.resolve(
        console.log(
          'Nothing to seed: the Offerings tests read the rows tool/seed/mentoring.ts makes. Pass --remove to sweep what they left.',
        ),
      )
  )
    .catch((e) => {
      console.error(e);
      process.exitCode = 1;
    })
    .finally(() => prisma.$disconnect());
}
