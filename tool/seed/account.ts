/**
 * Seeds what the mobile app's ACCOUNT screens (the person's profile, member pages, companies, settings, saved
 * items, network) need into the LOCAL portal database, so they read like a finished account and the live tests
 * have a person they may change.
 *
 *   cd E:\ICR\irc-portal\backend          (cwd must be the backend folder)
 *   NODE_PATH=E:/ICR/irc-portal/node_modules npx ts-node --transpile-only E:/ICR/icr-mobile/tool/seed/account.ts
 *   ... same command with --remove        (deletes what this script created, puts back what it changed)
 *   ... also: --cleanup-live              (deletes what the live tests leave behind: see "Live tests" below)
 *
 * Idempotent. Run it after `home.ts` and `learning-jobs.ts` (it builds on Bharat's role, résumé and photo).
 *
 * What is seeded
 *   Companies  TechCorp (Bengaluru, facility management), Northwind Facilities (Pune) and Harbour Estates
 *              (Mumbai): ids `design-acct-co-*`, with no one yet acting for them.
 *   Bharat     Bharat Buyer (buyer@icr.dev, the emulator's person) gets what a finished profile has and the
 *              designs' header slots read: a member of TechCorp (an ACTIVE membership; he is NOT switched into
 *              it, so his role and every other screen's tests are unchanged), his current role linked to the
 *              TechCorp page, languages, a LinkedIn link, a second role and a degree, an about summary and a
 *              location in his résumé's `content` (the API's own profile reads those from there), and one
 *              self-declared credential. Everything he held before is kept in Setting `design-seed:account`.
 *   Anita      Anita Account, the person live tests CHANGE: acct.persona@account-design.icr.test / Account@12345,
 *              a PROFESSIONAL with a default résumé, two roles (one at TechCorp), a degree, a career break,
 *              skills, languages, a phone number that is not verified, a LinkedIn link, an ACTIVE place at
 *              Northwind and TechCorp (acting as herself), and a request to join Harbour Estates waiting.
 *              A run RESETS her: every row she owns is put back as written here, so the write tests can start
 *              from the same person.
 *
 * Live tests (test/live/account_live_test.dart) sign up a throwaway person (acctlive.tester+<time>@account-live.icr.test),
 * file a contact message and found a company; none can be deleted through the API, so `--cleanup-live` removes
 * them (users whose email ends @account-live.icr.test or whose profile slug starts `acctlive-tester`, the
 * companies named `Account Live Test Co`, and the contact messages from that domain). `--remove` does that too.
 *
 * Markers: ids `design-acct-*`, the persona's email ends @account-design.icr.test.
 * Local database only: refuses to run unless DATABASE_URL is on localhost.
 */
import type { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { existsSync, readFileSync } from 'fs';
import { join } from 'path';

const MARK = 'design-acct-';
const MANIFEST_KEY = 'design-seed:account';
const BHARAT_EMAIL = 'buyer@icr.dev';
const PERSONA_EMAIL = 'acct.persona@account-design.icr.test';
const PERSONA_PASSWORD = 'Account@12345';
const LIVE_DOMAIN = '@account-live.icr.test';
const LIVE_SLUG = 'acctlive-tester';
const LIVE_COMPANY = 'Account Live Test Co';

const COMPANIES = [
  {
    id: `${MARK}co-techcorp`,
    name: 'TechCorp',
    city: 'Bengaluru',
    state: 'Karnataka',
    industry: 'CORPORATE_OCCUPIER',
    size: '201-500',
    legalStructure: 'PRIVATE_LIMITED',
    description: 'Corporate occupier running Grade-A campuses across Bengaluru.',
    website: 'https://techcorp.example.com',
  },
  {
    id: `${MARK}co-northwind`,
    name: 'Northwind Facilities',
    city: 'Pune',
    state: 'Maharashtra',
    industry: 'FM_SERVICES',
    size: '51-200',
    legalStructure: 'LLP',
    description: 'Integrated facility management for offices and campuses in Pune.',
    website: 'https://northwind-facilities.example.com',
  },
  {
    id: `${MARK}co-harbour`,
    name: 'Harbour Estates',
    city: 'Mumbai',
    state: 'Maharashtra',
    industry: 'DEVELOPER',
    size: '11-50',
    legalStructure: 'PRIVATE_LIMITED',
    description: 'Commercial developer and asset manager in Mumbai.',
    website: 'https://harbour-estates.example.com',
  },
] as const;

type Manifest = {
  bharat?: {
    languages: string[];
    linkedinUrl: string | null;
    yearsExperience: number | null;
    resumeContent: unknown;
    resumeId: string | null;
    experienceCompanyId: string | null;
    experienceEmploymentType: string | null;
  };
};

// ---------------------------------------------------------------------------------------------------------
// Local-only guard
// ---------------------------------------------------------------------------------------------------------

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

async function readManifest(prisma: PrismaClient): Promise<Manifest> {
  const row = await prisma.setting.findUnique({ where: { key: MANIFEST_KEY }, select: { value: true } });
  return (row?.value as Manifest | null) ?? {};
}

async function writeManifest(prisma: PrismaClient, manifest: Manifest): Promise<void> {
  await prisma.setting.upsert({
    where: { key: MANIFEST_KEY },
    update: { value: manifest as never },
    create: { key: MANIFEST_KEY, value: manifest as never },
  });
}

// ---------------------------------------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------------------------------------

async function seedCompanies(prisma: PrismaClient, log: (m: string) => void): Promise<void> {
  for (const c of COMPANIES) {
    const data = {
      name: c.name,
      type: 'CORPORATE' as never,
      legalStructure: c.legalStructure as never,
      description: c.description,
      website: c.website,
      city: c.city,
      state: c.state,
      country: 'India',
      size: c.size,
      industry: c.industry,
      verificationStatus: 'VERIFIED' as never,
    };
    await prisma.company.upsert({ where: { id: c.id }, update: data, create: { id: c.id, ...data } });
  }
  log(`  ${COMPANIES.length} companies: ${COMPANIES.map((c) => c.name).join(', ')}`);
}

/** An ACTIVE place at a company that does not touch which company the person is acting for. */
async function seedMembership(prisma: PrismaClient, userId: string, companyId: string, role: string): Promise<void> {
  const mine = await prisma.companyMembership.findFirst({
    where: { userId, companyId, status: { in: ['ACTIVE', 'REQUESTED'] as never } },
    select: { id: true },
  });
  if (mine) {
    await prisma.companyMembership.update({
      where: { id: mine.id },
      data: { status: 'ACTIVE' as never, role: role as never, note: null },
    });
  } else {
    await prisma.companyMembership.create({
      data: { id: `${MARK}m-${userId.slice(-6)}-${companyId.slice(-8)}`, userId, companyId, role: role as never, status: 'ACTIVE' as never, source: 'ADDED' as never },
    });
  }
}

const ANITA = {
  id: `${MARK}u-anita`,
  firstName: 'Anita',
  lastName: 'Account',
  slug: 'anita-account',
  designation: 'Senior Facilities Analyst',
  years: 6,
  languages: ['English', 'Hindi', 'Kannada'],
  phone: '+919812340000',
  linkedin: 'https://linkedin.com/in/anita-account',
  summary:
    'Facilities analyst with six years in workplace operations: space planning, vendor SLAs and energy reporting for multi-tenant campuses.',
  skills: ['Space Planning', 'Vendor SLAs', 'Energy Reporting', 'Lease Administration'],
  location: 'Pune, Maharashtra',
};

async function seedAnita(prisma: PrismaClient, log: (m: string) => void): Promise<string> {
  const passwordHash = bcrypt.hashSync(PERSONA_PASSWORD, 10);
  const base = {
    firstName: ANITA.firstName,
    lastName: ANITA.lastName,
    role: 'PROFESSIONAL' as never,
    personalRole: 'PROFESSIONAL' as never,
    profileSlug: ANITA.slug,
    designation: ANITA.designation,
    yearsExperience: ANITA.years,
    languages: ANITA.languages,
    phone: ANITA.phone,
    phoneVerifiedAt: null,
    linkedinUrl: ANITA.linkedin,
    websiteUrl: null,
    twitterUrl: null,
    githubUrl: null,
    portfolioUrl: null,
    workEmail: null,
    altPhone: null,
    avatarUrl: null,
    coverImage: null,
    locale: null,
    companyId: null,
    branchId: null,
    isActive: true,
    emailVerifiedAt: new Date(),
  };
  const user = await prisma.user.upsert({
    where: { email: PERSONA_EMAIL },
    update: { ...base, passwordHash },
    create: { id: ANITA.id, email: PERSONA_EMAIL, passwordHash, ...base },
  });

  // A reset: everything the write tests touched goes back.
  await prisma.userExperience.deleteMany({ where: { userId: user.id } });
  await prisma.userEducation.deleteMany({ where: { userId: user.id } });
  await prisma.userCareerBreak.deleteMany({ where: { userId: user.id } });
  await prisma.userCredential.deleteMany({ where: { userId: user.id } });
  await prisma.notificationPreference.deleteMany({ where: { userId: user.id } });
  await prisma.companyMembership.deleteMany({ where: { userId: user.id } });

  const resumeData = {
    userId: user.id,
    title: ANITA.designation,
    content: { jobTitle: ANITA.designation, summary: ANITA.summary, skills: ANITA.skills, location: ANITA.location, yearsExperience: ANITA.years },
    isDefault: true,
    discoverable: false,
    headline: ANITA.designation,
    summary: ANITA.summary,
    skills: ANITA.skills,
    experienceYears: ANITA.years,
    currentLocation: ANITA.location,
  };
  await prisma.resume.upsert({
    where: { id: `${MARK}resume-anita` },
    update: resumeData,
    create: { id: `${MARK}resume-anita`, ...resumeData },
  });

  await prisma.userExperience.createMany({
    data: [
      {
        id: `${MARK}exp-anita-1`,
        userId: user.id,
        title: 'Senior Facilities Analyst',
        organisation: 'TechCorp',
        companyId: `${MARK}co-techcorp`,
        employmentType: 'FULL_TIME' as never,
        city: 'Pune',
        industryKeys: ['CORPORATE_OCCUPIER'],
        startYear: 2022,
        startMonth: 6,
        isCurrent: true,
        description: 'Runs space planning and vendor performance reviews across three campuses.',
        sortOrder: 0,
      },
      {
        id: `${MARK}exp-anita-2`,
        userId: user.id,
        title: 'Facilities Executive',
        organisation: 'Northwind Facilities',
        companyId: `${MARK}co-northwind`,
        employmentType: 'FULL_TIME' as never,
        city: 'Pune',
        industryKeys: ['FM_SERVICES'],
        startYear: 2019,
        startMonth: 7,
        endYear: 2022,
        endMonth: 5,
        isCurrent: false,
        sortOrder: 1,
      },
    ],
  });
  await prisma.userEducation.create({
    data: {
      id: `${MARK}edu-anita-1`,
      userId: user.id,
      institution: 'Savitribai Phule Pune University',
      degree: 'B.E.',
      fieldOfStudy: 'Civil Engineering',
      startYear: 2014,
      endYear: 2018,
      sortOrder: 0,
    },
  });
  await prisma.userCareerBreak.create({
    data: { id: `${MARK}brk-anita-1`, userId: user.id, reason: 'STUDY' as never, startYear: 2018, startMonth: 8, endYear: 2019, endMonth: 5, isCurrent: false, description: 'Facility management diploma.' },
  });
  await prisma.userCredential.create({
    data: {
      id: `${MARK}cred-anita-1`,
      userId: user.id,
      name: 'Certified Facility Manager',
      code: 'CFM',
      issuer: 'IFMA',
      issuedAt: new Date('2023-03-01T00:00:00.000Z'),
      status: 'SELF_DECLARED' as never,
    },
  });

  await seedMembership(prisma, user.id, `${MARK}co-northwind`, 'PROFESSIONAL');
  await seedMembership(prisma, user.id, `${MARK}co-techcorp`, 'PROFESSIONAL');
  await prisma.companyMembership.create({
    data: {
      id: `${MARK}m-anita-harbour`,
      userId: user.id,
      companyId: `${MARK}co-harbour`,
      role: 'PROFESSIONAL' as never,
      status: 'REQUESTED' as never,
      note: 'I work with Harbour on the Bandra campus.',
      source: 'REQUEST' as never,
    },
  });
  log(`  ${PERSONA_EMAIL} / ${PERSONA_PASSWORD}: reset (profile, 2 roles, degree, break, credential, 2 places, 1 request)`);
  return user.id;
}

async function seedBharat(prisma: PrismaClient, manifest: Manifest, log: (m: string) => void): Promise<void> {
  const bharat = await prisma.user.findUnique({
    where: { email: BHARAT_EMAIL },
    select: { id: true, languages: true, linkedinUrl: true, yearsExperience: true },
  });
  if (!bharat) {
    log(`  ! ${BHARAT_EMAIL} does not exist: run the portal's own seeds first`);
    return;
  }
  const resume = await prisma.resume.findFirst({
    where: { userId: bharat.id },
    orderBy: [{ isDefault: 'desc' }, { createdAt: 'asc' }],
    select: { id: true, content: true, summary: true },
  });
  const exp = await prisma.userExperience.findFirst({
    where: { userId: bharat.id, isCurrent: true },
    select: { id: true, companyId: true, employmentType: true },
  });
  if (!manifest.bharat) {
    manifest.bharat = {
      languages: bharat.languages,
      linkedinUrl: bharat.linkedinUrl,
      yearsExperience: bharat.yearsExperience,
      resumeContent: resume?.content ?? null,
      resumeId: resume?.id ?? null,
      experienceCompanyId: exp?.companyId ?? null,
      experienceEmploymentType: (exp?.employmentType as string | null) ?? null,
    };
    await writeManifest(prisma, manifest);
  }

  await prisma.user.update({
    where: { id: bharat.id },
    data: { languages: ['English', 'Hindi', 'Kannada'], linkedinUrl: 'https://linkedin.com/in/bharat-buyer', yearsExperience: 9 },
  });
  if (resume) {
    // The API's own profile reads the about text, the title and the place from `content`.
    const content = {
      ...((resume.content ?? {}) as Record<string, unknown>),
      jobTitle: 'Lead Operations Manager',
      summary: resume.summary ?? 'Facilities leader with 9+ years running Grade-A commercial campuses.',
      location: 'Bengaluru, Karnataka',
    };
    await prisma.resume.update({ where: { id: resume.id }, data: { content: content as never } });
  }
  if (exp) await prisma.userExperience.update({ where: { id: exp.id }, data: { companyId: `${MARK}co-techcorp`, employmentType: 'FULL_TIME' as never } });
  await seedMembership(prisma, bharat.id, `${MARK}co-techcorp`, 'PROFESSIONAL');

  // One earlier role and one credential, so the lists read as a career.
  await prisma.userExperience.upsert({
    where: { id: `${MARK}exp-bharat-2` },
    update: {},
    create: {
      id: `${MARK}exp-bharat-2`,
      userId: bharat.id,
      title: 'Senior Facilities Manager',
      organisation: 'Prestige Group',
      employmentType: 'FULL_TIME' as never,
      city: 'Bengaluru',
      industryKeys: ['DEVELOPER'],
      startYear: 2014,
      startMonth: 6,
      endYear: 2019,
      endMonth: 3,
      isCurrent: false,
      description: 'Ran hard services for two Grade-A office parks.',
      sortOrder: 1,
    },
  });
  await prisma.userCredential.upsert({
    where: { id: `${MARK}cred-bharat-1` },
    update: {},
    create: {
      id: `${MARK}cred-bharat-1`,
      userId: bharat.id,
      name: 'NEBOSH International General Certificate',
      code: 'NEBOSH-IGC',
      issuer: 'NEBOSH',
      issuedAt: new Date('2021-09-15T00:00:00.000Z'),
      status: 'SELF_DECLARED' as never,
    },
  });
  log('  Bharat: member of TechCorp (not switched), role linked to its page, languages, LinkedIn, an earlier role, a credential');
}

// ---------------------------------------------------------------------------------------------------------
// Removing
// ---------------------------------------------------------------------------------------------------------

async function cleanupLive(prisma: PrismaClient, log: (m: string) => void): Promise<void> {
  const users = await prisma.user.findMany({
    where: { OR: [{ email: { endsWith: LIVE_DOMAIN } }, { profileSlug: { startsWith: LIVE_SLUG } }] },
    select: { id: true },
  });
  const ids = users.map((u) => u.id);
  const companies = await prisma.company.findMany({ where: { name: { startsWith: LIVE_COMPANY } }, select: { id: true } });
  const companyIds = companies.map((c) => c.id);
  // Whoever founded a throwaway company is one of those users; their memberships and requests go with them.
  await prisma.companyMembership.deleteMany({ where: { OR: [{ userId: { in: ids } }, { companyId: { in: companyIds } }] } });
  await prisma.userExperience.updateMany({ where: { companyId: { in: companyIds } }, data: { companyId: null } });
  await prisma.user.updateMany({ where: { companyId: { in: companyIds } }, data: { companyId: null } });
  const contacts = await prisma.contactMessage.deleteMany({ where: { email: { endsWith: LIVE_DOMAIN } } }).catch(() => ({ count: 0 }));
  const audit = await prisma.auditLog.deleteMany({ where: { actorId: { in: ids } } }).catch(() => ({ count: 0 }));
  let removedCompanies = 0;
  for (const id of companyIds) {
    await prisma.company.delete({ where: { id } }).then(() => removedCompanies++).catch(() => undefined);
  }
  let removedUsers = 0;
  for (const id of ids) {
    await prisma.user.delete({ where: { id } }).then(() => removedUsers++).catch(() => undefined);
  }
  log(`  live-test leftovers: ${removedUsers}/${ids.length} user(s), ${removedCompanies}/${companyIds.length} company(ies), ${contacts.count} contact message(s), ${audit.count} audit row(s)`);
}

export async function seedAccount(
  prisma: PrismaClient,
  log: (m: string) => void,
  opts: { remove?: boolean; cleanupLive?: boolean } = {},
): Promise<void> {
  assertLocal();
  const manifest = await readManifest(prisma);

  if (opts.cleanupLive && !opts.remove) {
    await cleanupLive(prisma, log);
    return;
  }

  if (opts.remove) {
    await cleanupLive(prisma, log);
    const persona = await prisma.user.findUnique({ where: { email: PERSONA_EMAIL }, select: { id: true } });
    if (persona) {
      await prisma.auditLog.deleteMany({ where: { actorId: persona.id } }).catch(() => undefined);
      await prisma.notification.deleteMany({ where: { userId: persona.id } }).catch(() => undefined);
    }
    await prisma.companyMembership.deleteMany({ where: { id: { startsWith: MARK } } });
    // Bharat: what the script changed goes back.
    const before = manifest.bharat;
    const bharat = await prisma.user.findUnique({ where: { email: BHARAT_EMAIL }, select: { id: true } });
    if (bharat && before) {
      await prisma.user.update({
        where: { id: bharat.id },
        data: { languages: before.languages, linkedinUrl: before.linkedinUrl, yearsExperience: before.yearsExperience },
      });
      if (before.resumeId) {
        await prisma.resume.update({ where: { id: before.resumeId }, data: { content: (before.resumeContent ?? {}) as never } }).catch(() => undefined);
      }
      await prisma.userExperience.updateMany({
        where: { userId: bharat.id, isCurrent: true, companyId: `${MARK}co-techcorp` },
        data: { companyId: before.experienceCompanyId, employmentType: (before.experienceEmploymentType ?? null) as never },
      });
    }
    // Bharat's memberships were ACTIVE rows made here; any other row at these companies is someone else's.
    await prisma.userExperience.updateMany({ where: { companyId: { startsWith: MARK } }, data: { companyId: null } });
    await prisma.userExperience.deleteMany({ where: { id: { startsWith: MARK } } });
    await prisma.userEducation.deleteMany({ where: { id: { startsWith: MARK } } });
    await prisma.userCareerBreak.deleteMany({ where: { id: { startsWith: MARK } } });
    await prisma.userCredential.deleteMany({ where: { id: { startsWith: MARK } } });
    await prisma.resume.deleteMany({ where: { id: { startsWith: MARK } } });
    const users = await prisma.user.deleteMany({ where: { email: PERSONA_EMAIL } });
    const companies = await prisma.company.deleteMany({ where: { id: { startsWith: MARK } } });
    await prisma.setting.deleteMany({ where: { key: MANIFEST_KEY } });
    log(`removed ${users.count} persona(s) and ${companies.count} company(ies); Bharat put back`);
    return;
  }

  await seedCompanies(prisma, log);
  await seedBharat(prisma, manifest, log);
  await seedAnita(prisma, log);
  await cleanupLive(prisma, log);
}

if (require.main === module) {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { PrismaClient: Client } = require('@prisma/client') as typeof import('@prisma/client');
  const prisma = new Client();
  seedAccount(prisma, (m) => console.log(m), {
    remove: process.argv.includes('--remove'),
    cleanupLive: process.argv.includes('--cleanup-live'),
  })
    .catch((e) => {
      console.error(e);
      process.exitCode = 1;
    })
    .finally(() => prisma.$disconnect());
}
