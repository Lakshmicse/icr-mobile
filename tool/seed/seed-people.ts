/**
 * The sixteen people the chapters and the library seeds share: the members a chapter's roster shows and the
 * people who shared the library's documents. Both seeds call `ensurePeople` (idempotent), so either can run
 * first; each `--remove` calls `removePeopleIfUnused`, which deletes them only when the OTHER seed's manifest
 * is gone too (so removing one seed never strands the other's rows, and removing both leaves nobody behind).
 *
 * Markers: ids `design-chu-<key>` (user) and `design-chux-<key>` (current role), emails ending
 * `@chapters-design.icr.test`, avatars `/uploads/design-chapters-avatar-<key>.jpg` (the portal's own AI
 * portraits in backend/prisma/seed-assets/avatars). No password: nobody can sign in as them.
 */
import type { PrismaClient } from '@prisma/client';
import { join } from 'path';
import { PORTAL_AVATARS, copyToUploads, hasManifest, removeUpload, up } from './seed-common';

export const PERSON_DOMAIN = '@chapters-design.icr.test';

export type PersonKey =
  | 'meera' | 'ananya' | 'divya' | 'shreya' | 'kavita' | 'lakshmi' | 'nisha' | 'pallavi'
  | 'rohan' | 'karthik' | 'sandeep' | 'imran' | 'harish' | 'vivek' | 'abhishek' | 'gaurav';

interface PersonSpec {
  first: string;
  last: string;
  title: string;
  org: string;
  city: string;
  avatar: string;
  startYear: number;
}

export const PEOPLE: Record<PersonKey, PersonSpec> = {
  meera: { first: 'Meera', last: 'Krishnan', title: 'Head of Security Operations', org: 'Prestige Group', city: 'Bengaluru', avatar: 'female-01.jpg', startYear: 2019 },
  ananya: { first: 'Ananya', last: 'Iyer', title: 'Workplace Experience Lead', org: 'Cisco GCC', city: 'Bengaluru', avatar: 'female-05.jpg', startYear: 2020 },
  divya: { first: 'Divya', last: 'Menon', title: 'Senior Manager, Facilities', org: 'Infosys', city: 'Bengaluru', avatar: 'female-06.jpg', startYear: 2018 },
  shreya: { first: 'Shreya', last: 'Kulkarni', title: 'Portfolio Manager', org: 'JLL', city: 'Mumbai', avatar: 'female-07.jpg', startYear: 2021 },
  kavita: { first: 'Kavita', last: 'Reddy', title: 'Director, Smart Buildings', org: 'Schneider Electric', city: 'Hyderabad', avatar: 'female-09.jpg', startYear: 2017 },
  lakshmi: { first: 'Lakshmi', last: 'Narayanan', title: 'VP, Corporate Real Estate', org: 'Tata Consultancy Services', city: 'Mumbai', avatar: 'female-10.jpg', startYear: 2016 },
  nisha: { first: 'Nisha', last: 'Kapoor', title: 'Head of Sustainability', org: 'Godrej Properties', city: 'Mumbai', avatar: 'female-11.jpg', startYear: 2022 },
  pallavi: { first: 'Pallavi', last: 'Deshmukh', title: 'Facility Head', org: 'Accenture', city: 'Gurugram', avatar: 'female-12.jpg', startYear: 2019 },
  rohan: { first: 'Rohan', last: 'Mehta', title: 'General Manager, IFM', org: 'Sodexo India', city: 'Mumbai', avatar: 'male-02.jpg', startYear: 2015 },
  karthik: { first: 'Karthik', last: 'Subramanian', title: 'Director, Campus Operations', org: 'Wipro', city: 'Bengaluru', avatar: 'male-03.jpg', startYear: 2017 },
  sandeep: { first: 'Sandeep', last: 'Verma', title: 'Regional Head, Facilities', org: 'CBRE', city: 'Gurugram', avatar: 'male-04.jpg', startYear: 2014 },
  imran: { first: 'Imran', last: 'Qureshi', title: 'Associate Director, Projects', org: 'Colliers', city: 'Hyderabad', avatar: 'male-06.jpg', startYear: 2020 },
  harish: { first: 'Harish', last: 'Rao', title: 'Head of Workplace', org: 'Microsoft India', city: 'Hyderabad', avatar: 'male-07.jpg', startYear: 2018 },
  vivek: { first: 'Vivek', last: 'Chandra', title: 'Vice President, Assets', org: 'Embassy Office Parks', city: 'Bengaluru', avatar: 'male-08.jpg', startYear: 2016 },
  abhishek: { first: 'Abhishek', last: 'Nair', title: 'Facilities Lead, GCC', org: 'Deloitte', city: 'Hyderabad', avatar: 'male-09.jpg', startYear: 2021 },
  gaurav: { first: 'Gaurav', last: 'Malhotra', title: 'Head, Real Estate Services', org: 'Cushman & Wakefield', city: 'Gurugram', avatar: 'male-11.jpg', startYear: 2015 },
};

export const PERSON_KEYS = Object.keys(PEOPLE) as PersonKey[];
export const personId = (k: PersonKey) => `design-chu-${k}`;
export const personEmail = (k: PersonKey) => `${PEOPLE[k].first.toLowerCase()}.${PEOPLE[k].last.toLowerCase()}${PERSON_DOMAIN}`;
const avatarFile = (k: PersonKey) => `design-chapters-avatar-${k}.jpg`;

/** Creates (or brings back to the designed state) the sixteen people; their ids by key. */
export async function ensurePeople(prisma: PrismaClient, log: (m: string) => void): Promise<Map<PersonKey, string>> {
  const ids = new Map<PersonKey, string>();
  for (const key of PERSON_KEYS) {
    const p = PEOPLE[key];
    copyToUploads(join(PORTAL_AVATARS, p.avatar), avatarFile(key));
    const data = {
      firstName: p.first,
      lastName: p.last,
      designation: `${p.title} at ${p.org}`,
      isActive: true,
      profilePublic: true,
      avatarUrl: up(avatarFile(key)),
    };
    const user = await prisma.user.upsert({
      where: { email: personEmail(key) },
      update: data,
      create: {
        id: personId(key),
        email: personEmail(key),
        passwordHash: null,
        profileSlug: `${p.first}-${p.last}-cdesign`.toLowerCase(),
        ...data,
      },
      select: { id: true },
    });
    ids.set(key, user.id);
    await prisma.userExperience.upsert({
      where: { id: `design-chux-${key}` },
      update: { userId: user.id, title: p.title, organisation: p.org, city: p.city, isCurrent: true, startYear: p.startYear, endYear: null },
      create: {
        id: `design-chux-${key}`,
        userId: user.id,
        title: p.title,
        organisation: p.org,
        city: p.city,
        isCurrent: true,
        startYear: p.startYear,
        sortOrder: 0,
      },
      select: { id: true },
    });
  }
  log(`  people: ${ids.size} members (${PERSON_DOMAIN}, no password), each with a current role and a portrait`);
  return ids;
}

/** Deletes the people unless one of the [others] manifests (the other seeds that use them) is still there. */
export async function removePeopleIfUnused(prisma: PrismaClient, log: (m: string) => void, others: string[]): Promise<void> {
  for (const key of others) {
    if (await hasManifest(prisma, key)) {
      log(`  people kept: the ${key} seed still uses them (remove that seed too to take them out)`);
      return;
    }
  }
  const users = await prisma.user.findMany({ where: { email: { endsWith: PERSON_DOMAIN } }, select: { id: true, email: true } });
  let removed = 0;
  for (const u of users) {
    try {
      await prisma.user.delete({ where: { id: u.id }, select: { id: true } });
      removed++;
    } catch (e) {
      log(`  could not delete ${u.email}: ${(e as Error).message.split('\n').pop()}`);
    }
  }
  let files = 0;
  for (const key of PERSON_KEYS) if (removeUpload(avatarFile(key))) files++;
  log(`  people removed: ${removed} (${files} portraits)`);
}
