/**
 * Gives the mobile app's EXAM flow (the brief, the exam window, the result, My attempts, My certificates) the
 * data its screens and live tests need, in the LOCAL portal database.
 *
 *   cd E:\ICR\irc-portal\backend          (cwd must be the backend folder)
 *   NODE_PATH=E:/ICR/irc-portal/node_modules npx ts-node --transpile-only E:/ICR/icr-mobile/tool/seed/learning-flows.ts
 *   ... same command with --remove        (deletes exactly what this script created and puts back what it changed)
 *
 * Idempotent. What it does:
 *
 *   1. Real questions on two papers. The local question banks are placeholders ("Practice question 3 for
 *      Foundation (placeholder...)", options "Option A".."Option D", no explanations, no topics, no multiple
 *      choice), which shows none of what the exam and the review screens draw. So two papers get ten real
 *      questions each, with an explanation and a topic apiece, and the placeholders on them are switched off
 *      (`active: false`; `--remove` switches them back on and deletes the real ones):
 *        capital-planning-foundation  (Bharat Buyer's, an assessment level that certifies)   10 single-choice
 *        ashrae-bemp-set-1            (Pooja Professional's, a mock set)                     8 single + 2 multiple-choice
 *      Both still serve 10 questions at 10 marks, so the lists and the landing screens read as before.
 *
 *   2. A history for Bharat Buyer (the person the emulator is signed in as), so My attempts and My certificates
 *      are not empty: three sittings of Capital Planning - Foundation (40 %, 60 %, then 90 %, which passed and
 *      earned the certificate ICR-CP-2026-DSGNLF01) and one failed sitting of Capital Planning - Advanced.
 *      Dates are relative to when the script last ran. If Bharat has sat those papers himself the history is
 *      left out (it would collide on the attempt numbers) and a line says so.
 *
 *   3. A sandbox person for the live tests, who can redeem credits and sit a paper from scratch:
 *        Exam Persona   exam.sitter@learning-flows.icr.test / Exam@12345   (a PROFESSIONAL)
 *      Her plan opens nothing, so every paper is locked to her until she redeems ICR credits for it (she gets
 *      the signup gift the first time the API asks). A run of the script RESETS her: it deletes her unlocks,
 *      attempts and certificates, so the redeem-and-pass live test can be run again from the start.
 *
 * Marker (what --remove finds): ids start `design-lf-`, certificate numbers start `ICR-CP-2026-DSGNLF`, the
 * persona's email ends @learning-flows.icr.test, and the Setting `design-seed:learning-flows` records which
 * placeholder questions were switched off. Local database only: refuses to run unless DATABASE_URL is on
 * localhost. Attempts cannot be deleted through the API, so a live test leaves its attempts behind (a few
 * per run, on papers with no attempt limit); running this script resets the Exam Persona's, and a
 * `--remove` followed by a run leaves the others in place but numbered on from the seeded ones.
 */
import type { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { existsSync, readFileSync } from 'fs';
import { join } from 'path';

const MARK = 'design-lf-';
const MANIFEST_KEY = 'design-seed:learning-flows';
const PERSONA_EMAIL = 'exam.sitter@learning-flows.icr.test';
const PERSONA_PASSWORD = 'Exam@12345';
const BHARAT = 'buyer@icr.dev';
const DAY = 24 * 3_600_000;

type Manifest = { deactivated: string[] };

// ---------------------------------------------------------------------------------------------------------
// The questions
// ---------------------------------------------------------------------------------------------------------

type Q = {
  prompt: string;
  options: string[];
  correct: number[];
  explanation: string;
  category: string;
};

const CAPITAL_PLANNING: Q[] = [
  {
    category: 'Capital planning basics',
    prompt: 'What is the main purpose of a capital plan for a facility portfolio?',
    options: [
      'To schedule routine cleaning',
      'To set out and fund major asset investments over several years',
      'To record daily energy readings',
      'To list tenant complaints',
    ],
    correct: [1],
    explanation:
      'A capital plan looks past the annual operating budget to the larger, less frequent investments (replacements, upgrades, new builds) and how they will be funded.',
  },
  {
    category: 'Budgeting',
    prompt: 'Which of these is normally treated as capital expenditure (CAPEX)?',
    options: ['Replacing a chiller plant', 'The monthly janitorial contract', 'Quarterly pest control', 'Electricity bills'],
    correct: [0],
    explanation:
      'CAPEX buys an asset or extends its life. Recurring running costs such as cleaning, pest control and utilities are operating expenditure (OPEX).',
  },
  {
    category: 'Asset lifecycle',
    prompt: 'Which stage comes first in a typical asset lifecycle?',
    options: ['Disposal', 'Planning and acquisition', 'Renewal', 'Day-to-day operation'],
    correct: [1],
    explanation: 'An asset is first planned for and acquired; operation, renewal and disposal follow.',
  },
  {
    category: 'Prioritisation',
    prompt: 'A project that must be done to meet a safety regulation is best ranked as:',
    options: [
      'Optional, if the budget allows',
      'Mandatory, ahead of discretionary work',
      'Deferred to next year',
      'Equal to a cosmetic upgrade',
    ],
    correct: [1],
    explanation: 'Statutory and safety work is not a choice, so it is funded first and the discretionary projects are ranked after it.',
  },
  {
    category: 'Budgeting',
    prompt: "What does 'whole-life cost' include?",
    options: [
      'Only the purchase price',
      'The purchase price, running costs, maintenance and disposal',
      'Only the maintenance',
      'Only the warranty',
    ],
    correct: [1],
    explanation:
      'Whole-life costing adds up everything an asset costs from purchase to disposal, so a cheap asset that is expensive to run is not mistaken for a bargain.',
  },
  {
    category: 'Asset lifecycle',
    prompt: 'A condition assessment of building systems is mainly used to:',
    options: [
      'Estimate when components will need replacing',
      'Set tenant rents',
      'Choose paint colours',
      'Name the building',
    ],
    correct: [0],
    explanation: 'Knowing the condition of each system lets the capital plan time replacements before failure, not after.',
  },
  {
    category: 'Governance',
    prompt: 'Who typically approves a major capital project?',
    options: [
      'The cleaning supervisor',
      'A governance body such as a capital committee or the board',
      'The security guard',
      'The tenant of one floor',
    ],
    correct: [1],
    explanation: 'Large commitments of funds are approved at the level that is accountable for them.',
  },
  {
    category: 'Prioritisation',
    prompt: 'When funds are limited, which approach to ranking projects is the most defensible?',
    options: [
      'Rank by whoever asks loudest',
      'Score each project against agreed criteria such as risk, cost and benefit',
      'Do the cheapest first, always',
      'Pick at random',
    ],
    correct: [1],
    explanation: 'Agreed, written criteria make the ranking fair, repeatable and easy to explain to those who miss out.',
  },
  {
    category: 'Budgeting',
    prompt: 'A contingency line in a capital budget is there to:',
    options: [
      'Cover unforeseen costs within the project',
      "Pay for the project manager's holiday",
      'Replace the need for estimates',
      'Fund unrelated projects',
    ],
    correct: [0],
    explanation: 'Contingency is held against risks that were not (or could not be) priced, so the project does not need to go back for more money at the first surprise.',
  },
  {
    category: 'Governance',
    prompt: 'After a capital project completes, a post-implementation review helps to:',
    options: ['Hide any overspend', 'Learn what worked and feed it into the next plan', 'Cancel the warranty', 'Skip the handover'],
    correct: [1],
    explanation: 'The review compares what was promised with what was delivered, and the lessons improve the next set of estimates.',
  },
];

const ENERGY_MODELLING: Q[] = [
  {
    category: 'Energy modelling',
    prompt: 'What is the main purpose of a building energy model?',
    options: [
      'To predict energy use under design or operating assumptions',
      'To replace commissioning',
      'To measure occupant satisfaction',
      'To set insurance premiums',
    ],
    correct: [0],
    explanation: 'A model estimates consumption and cost under stated assumptions, so options can be compared before they are built.',
  },
  {
    category: 'Weather and loads',
    prompt: 'Which input most directly drives the heating and cooling loads in a model?',
    options: ['The weather data for the site', "The owner's name", 'The colour of the lobby', 'The number of lifts'],
    correct: [0],
    explanation: 'Outdoor temperature, solar radiation and humidity, taken from a weather file, set the loads the systems must meet.',
  },
  {
    category: 'Envelope',
    prompt: 'Select all properties that affect conductive heat transfer through a wall.',
    options: [
      'Thermal conductivity of its layers',
      'Thickness of its layers',
      'The colour of the interior furniture',
      'The surface area of the wall',
    ],
    correct: [0, 1, 3],
    explanation:
      'Conduction through a wall depends on how well each layer conducts, how thick it is, and how much wall there is. Furniture colour has no part in it.',
  },
  {
    category: 'HVAC systems',
    prompt: 'A variable air volume (VAV) system varies:',
    options: [
      'The air volume delivered to each zone',
      "The building's orientation",
      'The window colour',
      'The lease term',
    ],
    correct: [0],
    explanation: 'VAV boxes modulate how much conditioned air each zone receives, which lets fan energy fall with the load.',
  },
  {
    category: 'Schedules',
    prompt: 'Occupancy and lighting schedules in a model should be based on:',
    options: [
      'The realistic expected use of the space',
      'One constant value for every hour',
      'Random numbers',
      "The architect's preference",
    ],
    correct: [0],
    explanation: 'Schedules decide when loads occur, so they should follow how the space will actually be used.',
  },
  {
    category: 'Calibration',
    prompt: 'Calibrating a model against metered data is done to:',
    options: [
      "Bring the model's results in line with observed consumption within an accepted tolerance",
      "Increase the model's file size",
      'Remove the need for utility bills',
      'Change the weather',
    ],
    correct: [0],
    explanation: 'A calibrated model reproduces what the building really uses, which makes its predictions about changes believable.',
  },
  {
    category: 'Outputs',
    prompt: 'Which of these are typical outputs of an energy model used for compliance? Select all that apply.',
    options: [
      'Annual energy use by end use',
      'Peak electric demand',
      'The number of parking spaces',
      'Estimated annual energy cost',
    ],
    correct: [0, 1, 3],
    explanation: 'Compliance reports show energy by end use, the demand peak and the cost. Parking provision is not something the model reports.',
  },
  {
    category: 'Metrics',
    prompt: 'Energy use intensity (EUI) is usually expressed as:',
    options: [
      'Energy per unit of floor area per year',
      'Energy per occupant per minute',
      'Cost per window',
      'Floor area per kilowatt',
    ],
    correct: [0],
    explanation: 'EUI divides annual energy by floor area (kWh/m2/year), so buildings of different sizes can be compared.',
  },
  {
    category: 'Controls',
    prompt: 'Setting back the temperature setpoint during unoccupied hours generally:',
    options: [
      'Reduces heating and cooling energy',
      'Doubles energy use',
      'Has no effect',
      'Only affects the lighting',
    ],
    correct: [0],
    explanation: 'Letting the space drift further from the occupied setpoint when nobody is there cuts the energy spent holding it.',
  },
  {
    category: 'Daylighting',
    prompt: 'Daylight harvesting saves energy by:',
    options: [
      'Dimming or switching off electric lighting when there is enough daylight',
      'Adding more luminaires',
      'Closing the blinds all day',
      'Heating the roof',
    ],
    correct: [0],
    explanation: 'Sensors reduce the electric light when daylight already lights the space, and the lighting load (and some cooling) falls.',
  },
];

const BANKS = [
  { slug: 'capital-planning-foundation', questions: CAPITAL_PLANNING },
  { slug: 'ashrae-bemp-set-1', questions: ENERGY_MODELLING },
];

// ---------------------------------------------------------------------------------------------------------
// Local-only guard
// ---------------------------------------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------------------------------------
// Seeding
// ---------------------------------------------------------------------------------------------------------

async function readManifest(prisma: PrismaClient): Promise<Manifest> {
  const row = await prisma.setting.findUnique({ where: { key: MANIFEST_KEY }, select: { value: true } });
  const m = (row?.value as Partial<Manifest> | null) ?? {};
  return { deactivated: m.deactivated ?? [] };
}

async function writeManifest(prisma: PrismaClient, manifest: Manifest): Promise<void> {
  await prisma.setting.upsert({
    where: { key: MANIFEST_KEY },
    update: { value: manifest as never },
    create: { key: MANIFEST_KEY, value: manifest as never },
  });
}

/** Ten real questions on a paper, in place of its placeholders. */
async function seedBank(prisma: PrismaClient, manifest: Manifest, slug: string, bank: Q[], log: (m: string) => void) {
  const paper = await prisma.learningPaper.findUnique({ where: { slug }, select: { id: true } });
  if (!paper) {
    log(`  ! paper ${slug} does not exist in this database; its questions were left out`);
    return;
  }
  const mine = bank.map((_, i) => `${MARK}q-${slug}-${i + 1}`);
  // Switch the placeholders off, remembering exactly which ones this script switched.
  const live = await prisma.learningQuestion.findMany({
    where: { paperId: paper.id, active: true, id: { notIn: mine } },
    select: { id: true },
  });
  for (const q of live) if (!manifest.deactivated.includes(q.id)) manifest.deactivated.push(q.id);
  await prisma.learningQuestion.updateMany({ where: { id: { in: live.map((q) => q.id) } }, data: { active: false } });

  for (const [i, q] of bank.entries()) {
    const data = {
      paperId: paper.id,
      type: (q.correct.length > 1 ? 'MULTIPLE' : 'SINGLE') as never,
      prompt: q.prompt,
      options: q.options as never,
      correctIndexes: q.correct,
      explanation: q.explanation,
      marks: 1,
      difficulty: 'MEDIUM' as never,
      category: q.category,
      sortOrder: i + 1,
      active: true,
    };
    await prisma.learningQuestion.upsert({ where: { id: mine[i] }, update: data, create: { id: mine[i], ...data } });
  }
  const multiple = bank.filter((q) => q.correct.length > 1).length;
  log(`  ${slug}: ${bank.length} real questions (${multiple} multiple-choice), ${live.length} placeholder(s) switched off`);
}

type Sitting = { right: number; skip?: number; days: number; minutes: number };

/** The answers of a sitting that gets `right` questions right, skips the last `skip`, and gets the rest wrong. */
function answersFor(
  questions: { id: string; correctIndexes: number[]; options: unknown; marks: number }[],
  s: Sitting,
) {
  const answers: Record<string, number[]> = {};
  let correct = 0;
  let wrong = 0;
  let unanswered = 0;
  let score = 0;
  let max = 0;
  questions.forEach((q, i) => {
    max += q.marks;
    if (i < s.right) {
      answers[q.id] = [...q.correctIndexes];
      correct++;
      score += q.marks;
    } else if (i >= questions.length - (s.skip ?? 0)) {
      answers[q.id] = [];
      unanswered++;
    } else {
      const count = Array.isArray(q.options) ? q.options.length : 4;
      const bad = [...Array(count).keys()].find((o) => !q.correctIndexes.includes(o)) ?? 0;
      answers[q.id] = [bad];
      wrong++;
    }
  });
  return { answers, correct, wrong, unanswered, score, max, percentage: max > 0 ? Math.round((score / max) * 100) : 0 };
}

async function seedHistory(prisma: PrismaClient, log: (m: string) => void): Promise<void> {
  const bharat = await prisma.user.findUnique({ where: { email: BHARAT }, select: { id: true } });
  if (!bharat) {
    log(`  ! ${BHARAT} does not exist in this database; the attempt history was left out`);
    return;
  }
  const now = Date.now();
  const plans: { slug: string; sittings: Sitting[]; certificate?: { id: string; number: string; code: string; title: string } }[] = [
    {
      slug: 'capital-planning-foundation',
      sittings: [
        { right: 4, skip: 1, days: 6, minutes: 8 },
        { right: 6, days: 4, minutes: 14 },
        { right: 9, days: 1, minutes: 21 },
      ],
      certificate: { id: `${MARK}cert-cp-foundation`, number: 'ICR-CP-2026-DSGNLF01', code: 'CP', title: 'Capital Planning' },
    },
    { slug: 'capital-planning-advanced', sittings: [{ right: 5, skip: 2, days: 3, minutes: 31 }] },
  ];
  for (const plan of plans) {
    const paper = await prisma.learningPaper.findUnique({
      where: { slug: plan.slug },
      select: { id: true, passPercentage: true, certificateMinPercentage: true, level: true, certificateTemplate: true },
    });
    if (!paper) {
      log(`  ! paper ${plan.slug} does not exist; its history was left out`);
      continue;
    }
    const others = await prisma.learningAttempt.count({
      where: { userId: bharat.id, paperId: paper.id, id: { not: { startsWith: MARK } } },
    });
    if (others > 0) {
      log(`  ! Bharat has sat ${plan.slug} himself (${others} attempt(s)); the seeded history for it was left out`);
      continue;
    }
    const questions = await prisma.learningQuestion.findMany({
      where: { paperId: paper.id, active: true },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
      select: { id: true, correctIndexes: true, options: true, marks: true },
    });
    let passedAt: { attempt: number; percentage: number; at: Date } | null = null;
    for (const [i, s] of plan.sittings.entries()) {
      const a = answersFor(questions, s);
      const submittedAt = new Date(now - s.days * DAY);
      const startedAt = new Date(submittedAt.getTime() - s.minutes * 60_000 - 17_000);
      const passed = a.percentage >= paper.passPercentage;
      const data = {
        userId: bharat.id,
        paperId: paper.id,
        attempt: i + 1,
        startedAt,
        submittedAt,
        timeTakenMs: submittedAt.getTime() - startedAt.getTime(),
        totalQuestions: questions.length,
        correct: a.correct,
        wrong: a.wrong,
        unanswered: a.unanswered,
        score: a.score,
        maxScore: a.max,
        percentage: a.percentage,
        passPercentage: paper.passPercentage,
        passed,
        answers: a.answers as never,
      };
      await prisma.learningAttempt.upsert({ where: { id: `${MARK}att-${plan.slug}-${i + 1}` }, update: data, create: { id: `${MARK}att-${plan.slug}-${i + 1}`, ...data } });
      if (passed && !passedAt) passedAt = { attempt: i + 1, percentage: a.percentage, at: submittedAt };
    }
    log(`  Bharat: ${plan.sittings.length} sitting(s) of ${plan.slug}`);
    if (plan.certificate && passedAt) {
      const c = plan.certificate;
      const existing = await prisma.learningCertificate.findUnique({ where: { userId_paperId: { userId: bharat.id, paperId: paper.id } } });
      if (existing && !existing.id.startsWith(MARK)) {
        log('  ! Bharat already holds a certificate for it that is not ours; left alone');
        continue;
      }
      const data = {
        certificateId: c.number,
        userId: bharat.id,
        paperId: paper.id,
        title: c.title,
        certificationCode: c.code,
        level: paper.level as never,
        providerName: null,
        providerLogoUrl: null,
        issuedAt: passedAt.at,
        attempt: passedAt.attempt,
        percentage: passedAt.percentage,
        passPercentage: paper.certificateMinPercentage ?? paper.passPercentage,
        template: paper.certificateTemplate,
        revokedAt: null,
      };
      await prisma.learningCertificate.upsert({ where: { id: c.id }, update: data, create: { id: c.id, ...data } });
      log(`  Bharat: certificate ${c.number}`);
    }
  }
}

async function seedPersona(prisma: PrismaClient, log: (m: string) => void): Promise<void> {
  const user = await prisma.user.upsert({
    where: { email: PERSONA_EMAIL },
    update: { passwordHash: bcrypt.hashSync(PERSONA_PASSWORD, 10), isActive: true },
    create: {
      id: `${MARK}u-sitter`,
      email: PERSONA_EMAIL,
      passwordHash: bcrypt.hashSync(PERSONA_PASSWORD, 10),
      firstName: 'Exam',
      lastName: 'Persona',
      role: 'PROFESSIONAL' as never,
      emailVerifiedAt: new Date(),
      designation: 'Facilities analyst (mobile exam seed)',
    },
  });
  // A reset: what the live tests did last time (papers redeemed, sittings, certificates) is undone, so the
  // redeem-and-pass test can run from the start again. Her credits come back with her unlocks.
  const unlocks = await prisma.learningPaperUnlock.deleteMany({ where: { userId: user.id } });
  const attempts = await prisma.learningAttempt.deleteMany({ where: { userId: user.id } });
  const certificates = await prisma.learningCertificate.deleteMany({ where: { userId: user.id } });
  log(
    `  ${PERSONA_EMAIL} / ${PERSONA_PASSWORD}: reset (${unlocks.count} unlock(s), ${attempts.count} attempt(s), ${certificates.count} certificate(s) cleared)`,
  );
}

export async function seedLearningFlows(
  prisma: PrismaClient,
  log: (m: string) => void,
  opts: { remove?: boolean } = {},
): Promise<void> {
  assertLocal();
  const manifest = await readManifest(prisma);

  if (opts.remove) {
    const touched = await prisma.learningAttempt.findMany({
      where: { id: { startsWith: MARK } },
      select: { userId: true, paperId: true },
      distinct: ['userId', 'paperId'],
    });
    const certs = await prisma.learningCertificate.deleteMany({ where: { id: { startsWith: MARK } } });
    const attempts = await prisma.learningAttempt.deleteMany({ where: { id: { startsWith: MARK } } });
    // What the member sat since stays, numbered on from 1 so the next sitting does not collide.
    for (const t of touched) {
      const rest = await prisma.learningAttempt.findMany({
        where: { userId: t.userId, paperId: t.paperId },
        orderBy: { attempt: 'asc' },
        select: { id: true, attempt: true },
      });
      for (const [i, r] of rest.entries()) {
        if (r.attempt !== i + 1) await prisma.learningAttempt.update({ where: { id: r.id }, data: { attempt: i + 1 } });
      }
    }
    const questions = await prisma.learningQuestion.deleteMany({ where: { id: { startsWith: MARK } } });
    const back = await prisma.learningQuestion.updateMany({ where: { id: { in: manifest.deactivated } }, data: { active: true } });
    // The persona's own trail (she logs in, redeems...) is audit rows that point at her and block her deletion.
    const mine = await prisma.user.findMany({ where: { email: { endsWith: '@learning-flows.icr.test' } }, select: { id: true } });
    const audit = await prisma.auditLog.deleteMany({ where: { actorId: { in: mine.map((u) => u.id) } } });
    const users = await prisma.user.deleteMany({ where: { id: { in: mine.map((u) => u.id) } } });
    log(`  deleted ${audit.count} audit row(s) of the persona`);
    await prisma.setting.deleteMany({ where: { key: MANIFEST_KEY } });
    log(
      `removed ${questions.count} question(s), ${attempts.count} attempt(s), ${certs.count} certificate(s) and ${users.count} persona(s); switched ${back.count} placeholder question(s) back on`,
    );
    return;
  }

  for (const b of BANKS) await seedBank(prisma, manifest, b.slug, b.questions, log);
  await writeManifest(prisma, manifest);
  await seedHistory(prisma, log);
  await seedPersona(prisma, log);
}

if (require.main === module) {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { PrismaClient: Client } = require('@prisma/client') as typeof import('@prisma/client');
  const prisma = new Client();
  seedLearningFlows(prisma, (m) => console.log(m), { remove: process.argv.includes('--remove') })
    .catch((e) => {
      console.error(e);
      process.exitCode = 1;
    })
    .finally(() => prisma.$disconnect());
}
