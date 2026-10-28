/**
 * Seeds the Digital Library of the mobile app into the LOCAL portal database: thirty-one documents in every
 * format the library takes, with real files that preview and download, so the app reads the portal's real API
 * (`GET /documents`, `/documents/:id/download`) with something to show. The database has no library at all
 * until this runs.
 *
 *   cd E:\ICR\irc-portal\backend          (cwd must be the backend folder: `uploads` resolves from it)
 *   NODE_PATH=E:/ICR/irc-portal/node_modules npx ts-node --transpile-only E:/ICR/icr-mobile/tool/seed/library.ts
 *   ... same command with --remove        (deletes what this script created)
 *   ... also: --dry-run
 *
 * The files are made by `make_seed_files.py` (committed under `tool/seed/assets/library/`): multi-page PDFs, a
 * Word checklist and template, Excel workbooks, CSV, text, a PowerPoint, a ZIP pack and two images.
 *
 * Idempotent: every row has a stable id and is upserted; a re-run brings the counts (views, downloads), the
 * files and the reports back to the designed state, so what a live test downloaded is counted again from there.
 *
 * Markers (all removable): documents `design-doc-*`, their files `design-docf-*`, uploads
 * `/uploads/design-library-*` (and their `UploadedFile` rows), reports `design-docrep-*`, and the sixteen
 * people shared with chapters.ts (`design-chu-*`, `@chapters-design.icr.test`).
 *
 * What is seeded
 *   Documents   31: PDF by far the most, then Word, Excel, CSV, PowerPoint, text, ZIP and two images;
 *               six packs of two or three files; filed under the platform's own categories (and one
 *               category an uploader typed, "Board packs"); titles and descriptions that name the ten
 *               library kinds (Insights, Best Practices, SOPs, Checklists, Policies, Processes, Templates,
 *               Standards, Research, Case Studies) so the app's quick searches find them; created over the
 *               last five months with views and downloads that make every sort differ.
 *   Uploaders   Bharat Buyer (buyer@icr.dev) shared 3, one of them a 3-file pack; Pooja Professional
 *               (professional@icr.test) shared 2; the other 26 are by the sixteen shared people.
 *   Reports     two PENDING reports on documents that belong to neither persona (an admin queue).
 *
 * Nothing existing is changed. It refuses to run unless the database is on localhost.
 */
import type { PrismaClient } from '@prisma/client';
import { join } from 'path';
import {
  DAY,
  SEED_ASSETS,
  assertLocalDatabase,
  classifyFile,
  copyToUploads,
  hasManifest,
  mimeOf,
  removeUpload,
  loadManifest,
  saveManifest,
  up,
} from './seed-common';
import { PERSON_KEYS, PersonKey, ensurePeople, removePeopleIfUnused } from './seed-people';

const MANIFEST_KEY = 'design-seed:library';
const CHAPTERS_KEY = 'design-seed:chapters';
const BHARAT_EMAIL = 'buyer@icr.dev';
const POOJA_EMAIL = 'professional@icr.test';

type Uploader = 'bharat' | 'pooja' | PersonKey;

interface FileSpec {
  /** The file under assets/library/. */
  asset: string;
  /** The name the document shows for it (the uploader's own filename). */
  name?: string;
}

interface DocSpec {
  key: string;
  title: string;
  description: string;
  category: string;
  sub?: string;
  spec?: string;
  files: (string | FileSpec)[];
  by: Uploader;
  days: number;
  views: number;
  downloads: number;
}

const DOCS: DocSpec[] = [
  { key: 'handover-checklist', title: 'FM Handover Checklist: New Building Takeover', description: 'A 60-point checklist for taking a new or refurbished building from the project team into operations: documents, walk-down, systems, contracts and sign-off rules.', category: 'Integrated Facility Management', files: ['fm-handover-checklist.pdf'], by: 'divya', days: 12, views: 1290, downloads: 482 },
  { key: 'fire-sop', title: 'Fire & Life Safety SOP: Alarm Response and Evacuation', description: 'Standard operating procedure for a fire alarm activation: who does what in the first five minutes, evacuation, roll call, and the drill records auditors ask for.', category: 'Fire & Life Safety', sub: 'Fire Alarm Systems', files: ['fire-life-safety-sop.pdf'], by: 'meera', days: 30, views: 980, downloads: 371 },
  { key: 'vendor-sla-guide', title: 'Vendor SLA Management: A Practical Guide (Best Practices)', description: 'Best practices for writing, measuring and enforcing service levels with hard and soft service vendors, with a scorecard to adapt.', category: 'Integrated Facility Management', files: ['vendor-sla-management-guide.pdf'], by: 'rohan', days: 41, views: 870, downloads: 296 },
  { key: 'brsr-standards', title: 'BRSR Core for Facilities Teams: Standards Summary', description: 'What facilities has to collect for the BRSR Core energy, water and waste indicators, where the numbers come from and how to evidence them.', category: 'ESG & Sustainability', files: ['brsr-core-esg-reporting-guide.pdf'], by: 'nisha', days: 48, views: 700, downloads: 233 },
  { key: 'mep-standard', title: 'MEP Commissioning Standard (Summary)', description: 'The commissioning stages, witness points and acceptance criteria for MEP systems in office buildings, as a short standard.', category: 'Engineering Services', files: ['mep-commissioning-standard.pdf'], by: 'imran', days: 73, views: 420, downloads: 150 },
  { key: 'gcc-benchmark', title: 'GCC Workplace Benchmark 2026 (Research)', description: 'Research summary of seat ratios, cost per seat and service levels at global capability centres, from ICR member submissions.', category: 'Workplace Experience', files: ['gcc-workplace-benchmark-2026.pdf'], by: 'ananya', days: 9, views: 1510, downloads: 402 },
  { key: 'lease-playbook', title: 'Lease Audit Playbook', description: 'A step-by-step method for auditing a commercial lease against what is billed: measurement, escalation, CAM, parking and restoration.', category: 'Corporate Real Estate', sub: 'Real Estate Advisory', files: ['lease-audit-playbook.pdf'], by: 'lakshmi', days: 21, views: 860, downloads: 318 },
  { key: 'hvac-policy', title: 'HVAC Preventive Maintenance Policy', description: 'A policy for planned maintenance of chillers, AHUs and cooling towers: frequencies, inspection standards, records and exceptions.', category: 'Integrated Facility Management', sub: 'HVAC', files: ['hvac-ppm-policy.pdf'], by: 'karthik', days: 55, views: 530, downloads: 187 },
  { key: 'energy-case', title: 'Case Study: 22% Energy Reduction in a 1.2 Mn Sq Ft Campus', description: 'How one campus cut energy use by 22%: the measures, the meters, the costs and what did not work. Includes the dashboard the team used.', category: 'ESG & Sustainability', files: ['energy-retrofit-case-study.pdf', { asset: 'energy-dashboard.png', name: 'energy-intensity-dashboard.png' }], by: 'vivek', days: 95, views: 640, downloads: 205 },
  { key: 'housekeeping-sop', title: 'Housekeeping Service Levels and Inspection SOP', description: 'Standard operating procedure for housekeeping service levels, inspection scoring and corrective action, for offices and campuses.', category: 'Integrated Facility Management', sub: 'Housekeeping', files: ['housekeeping-sla-sop.pdf'], by: 'divya', days: 66, views: 440, downloads: 139 },
  { key: 'contractor-onboarding', title: 'Contractor Onboarding Process', description: 'The process for onboarding a contractor: documents, induction, permits, access and the first-week checks. The induction pack is attached.', category: 'Integrated Facility Management', files: ['contractor-onboarding-process.pdf', { asset: 'contractor-induction-pack.zip', name: 'induction-pack.zip' }], by: 'abhishek', days: 64, views: 320, downloads: 127 },
  { key: 'cmms-insights', title: 'Choosing a CMMS: What Operators Wish They Had Asked (Insights)', description: 'Insights from operators on selecting a maintenance management system: integrations, mobile use, data ownership and the questions vendors avoid.', category: 'Technology', sub: 'Building Management Systems', files: ['cmms-selection-insights.pdf'], by: 'kavita', days: 38, views: 480, downloads: 164 },
  { key: 'dc-uptime', title: 'Data Centre Uptime: Operating Practices', description: 'Operating practices that keep a data centre up: change control, maintenance windows, spares and the drills that matter.', category: 'Utilities & Infrastructure', files: ['data-centre-uptime-practices.pdf'], by: 'harish', days: 110, views: 390, downloads: 112 },
  { key: 'occupancy-research', title: 'Hybrid Occupancy Research Summary', description: 'A research summary of how hybrid occupancy has settled across member campuses: peaks, troughs and what operators changed.', category: 'Workplace Experience', files: ['occupancy-research-summary.pdf'], by: 'shreya', days: 17, views: 710, downloads: 208 },
  { key: 'rfp-template', title: 'RFP Evaluation Framework for IFM Contracts (Template)', description: 'A template for scoring IFM bids on scope, service levels, people, price and exit, with a contract review checklist to use alongside.', category: 'Procurement & Supply Chain', files: ['rfp-evaluation-framework.pdf', { asset: 'service-contract-review-checklist.docx', name: 'contract-review-checklist.docx' }], by: 'gaurav', days: 27, views: 560, downloads: 243 },
  { key: 'security-policy', title: 'Security Incident Reporting Policy', description: 'A policy for reporting, escalating and reviewing security incidents, with the incident report template as a Word file.', category: 'Security Services', files: ['security-incident-policy.pdf', { asset: 'incident-report-template.docx', name: 'incident-report-form.docx' }], by: 'pallavi', days: 83, views: 340, downloads: 101 },
  // Bharat Buyer's own three.
  { key: 'sla-scorecard', title: 'Vendor SLA Scorecard Template', description: 'A monthly scorecard for hard and soft service vendors: response, resolution, quality and cost, weighted into one score and a rating.', category: 'Integrated Facility Management', files: ['vendor-sla-scorecard.xlsx'], by: 'bharat', days: 5, views: 1410, downloads: 604 },
  { key: 'lease-workbook', title: 'Lease Audit Workbook: Template and Worked Example', description: 'A workbook, its filled-in example and a one-page method note for auditing a commercial lease.', category: 'Corporate Real Estate', sub: 'Property Services', files: ['lease-audit-template.xlsx', { asset: 'lease-audit-worked-example.xlsx', name: 'lease-audit-worked-example.xlsx' }, { asset: 'lease-audit-playbook.pdf', name: 'lease-audit-method.pdf' }], by: 'bharat', days: 21, views: 860, downloads: 318 },
  { key: 'plant-walkdown', title: 'Chiller Plant Room Walk-down', description: 'The checklist photo set used on a chiller plant room walk-down: readings, leaks and corrosion.', category: 'Integrated Facility Management', sub: 'HVAC', files: ['plant-room-walkdown.png'], by: 'bharat', days: 3, views: 133, downloads: 41 },
  // Pooja Professional's two.
  { key: 'visitor-policy', title: 'Visitor Management Policy', description: 'A short policy for registering, badging and escorting visitors at multi-tenant buildings.', category: 'Security Services', files: ['visitor-management-policy.txt'], by: 'pooja', days: 120, views: 188, downloads: 62 },
  { key: 'ppm-calendar', title: 'Preventive Maintenance Calendar (CSV and Workbook)', description: 'A year of PPM tasks by asset class, as a CSV ready to import into a CMMS and as a workbook.', category: 'Integrated Facility Management', files: ['ppm-calendar.csv', { asset: 'ppm-schedule.xlsx', name: 'ppm-schedule.xlsx' }], by: 'pooja', days: 150, views: 310, downloads: 120 },
  // The rest.
  { key: 'gcc-briefing', title: 'GCC Workplace Leadership: Quarterly Briefing', description: 'Slides from the Council briefing on hybrid occupancy, seat ratios and campus consolidation.', category: 'Workplace Experience', files: ['gcc-workplace-briefing.pptx'], by: 'ananya', days: 9, views: 260, downloads: 94 },
  { key: 'asset-register', title: 'Asset Register Template (Template)', description: 'A CSV template for an asset register: tag, description, location, make, model, installation and warranty dates, criticality.', category: 'Asset Management', files: ['asset-register-template.csv'], by: 'vivek', days: 100, views: 150, downloads: 58 },
  { key: 'induction-pack', title: 'Contractor Induction Pack', description: 'Visitor policy, sign-in sheet and the induction reference in one archive.', category: 'Integrated Facility Management', files: ['contractor-induction-pack.zip'], by: 'meera', days: 140, views: 201, downloads: 77 },
  { key: 'incident-template', title: 'Incident Report Template (Process)', description: 'The process and the form for reporting an incident within 24 hours: what happened, immediate actions, cause and follow-up.', category: 'Health, Safety & Environment', files: ['incident-report-template.docx'], by: 'pallavi', days: 59, views: 230, downloads: 84 },
  { key: 'contract-checklist', title: 'Service Contract Review Checklist', description: 'A checklist to review a facility services contract before signing or renewing it: scope, service levels, price, people and exit.', category: 'Procurement & Supply Chain', files: ['service-contract-review-checklist.docx'], by: 'gaurav', days: 33, views: 390, downloads: 142 },
  { key: 'energy-dashboard', title: 'Energy Intensity Dashboard (Insights)', description: 'An at-a-glance view of energy intensity over three years against the target, as an image you can drop into a board pack.', category: 'ESG & Sustainability', files: ['energy-dashboard.png'], by: 'nisha', days: 14, views: 101, downloads: 47 },
  { key: 'ppm-workbook', title: 'PPM Schedule Workbook', description: 'A planned-preventive-maintenance schedule workbook by asset class and month.', category: 'Engineering Services', files: ['ppm-schedule.xlsx'], by: 'karthik', days: 88, views: 275, downloads: 91 },
  { key: 'board-pack-template', title: 'Board Pack Minutes Template', description: 'A template for the facilities section of a board pack: decisions, risks, spend against budget and next quarter.', category: 'Board packs', files: [{ asset: 'service-contract-review-checklist.docx', name: 'board-pack-minutes-template.docx' }], by: 'lakshmi', days: 130, views: 88, downloads: 30 },
  { key: 'sla-spreadsheet', title: 'Housekeeping and Security SLA Scorecard (Template)', description: 'A scorecard template for housekeeping and security vendors, with weights and ratings.', category: 'Security Services', files: [{ asset: 'vendor-sla-scorecard.xlsx', name: 'housekeeping-security-scorecard.xlsx' }], by: 'meera', days: 52, views: 205, downloads: 73 },
  { key: 'lease-method-note', title: 'Lease Audit: One-page Method Note (Standards)', description: 'A one-page method note setting out the standard steps of a lease audit.', category: 'Corporate Real Estate', files: [{ asset: 'lease-audit-playbook.pdf', name: 'lease-audit-method-note.pdf' }], by: 'shreya', days: 75, views: 160, downloads: 52 },
];

/** Two pending reports on documents that are neither persona's. */
const REPORTS = [
  { id: 'design-docrep-1', doc: 'brsr-standards', by: 'imran' as PersonKey, reason: 'MISLEADING', note: 'The thresholds quoted for water intensity look out of date.', days: 2 },
  { id: 'design-docrep-2', doc: 'dc-uptime', by: 'harish' as PersonKey, reason: 'OTHER', note: 'Page 3 repeats the previous section.', days: 1 },
];

const docId = (key: string) => `design-doc-${key}`;
const fileId = (key: string, i: number) => `design-docf-${key}-${i}`;
const uploadName = (key: string, i: number, shown: string) => `design-library-${key}-${i}.${shown.split('.').pop()!.toLowerCase()}`;
const norm = (f: string | FileSpec): Required<FileSpec> => (typeof f === 'string' ? { asset: f, name: f } : { asset: f.asset, name: f.name ?? f.asset });

interface Manifest {
  uploads: string[];
}
const emptyManifest = (): Manifest => ({ uploads: [] });

export interface SeedOptions {
  remove?: boolean;
  dryRun?: boolean;
  /** For tests. */
  now?: Date;
}

export async function seedLibrary(prisma: PrismaClient, log: (m: string) => void, opts: SeedOptions = {}): Promise<void> {
  await assertLocalDatabase(prisma, log);
  if (opts.remove) return removeAll(prisma, log);
  return seedAll(prisma, log, opts);
}

async function seedAll(prisma: PrismaClient, log: (m: string) => void, opts: SeedOptions): Promise<void> {
  const now = opts.now ?? new Date();
  if (opts.dryRun) {
    log('  dry run: nothing is written');
    for (const d of DOCS) log(`    ${docId(d.key)}: ${d.files.length} file(s) by ${d.by}, ${d.days} days ago`);
    return;
  }
  const bharat = await prisma.user.findUnique({ where: { email: BHARAT_EMAIL }, select: { id: true } });
  const pooja = await prisma.user.findUnique({ where: { email: POOJA_EMAIL }, select: { id: true } });
  if (!bharat) throw new Error(`${BHARAT_EMAIL} not found: run the portal's db:seed:test-users first.`);
  if (!pooja) throw new Error(`${POOJA_EMAIL} not found: run the portal's db:seed:test-users first.`);

  const people = await ensurePeople(prisma, log);
  const who = (u: Uploader): string => (u === 'bharat' ? bharat.id : u === 'pooja' ? pooja.id : people.get(u)!);

  const manifest = emptyManifest();
  let files = 0;
  let bytes = 0;
  for (const d of DOCS) {
    const uploaderId = who(d.by);
    const specs = d.files.map(norm);
    const rows = specs.map((f, i) => {
      const filename = uploadName(d.key, i, f.name);
      const size = copyToUploads(join(SEED_ASSETS, 'library', f.asset), filename);
      manifest.uploads.push(filename);
      const mimeType = mimeOf(f.name);
      return { f, i, filename, size, mimeType };
    });
    const createdAt = new Date(now.getTime() - d.days * DAY);
    const total = rows.reduce((n, r) => n + r.size, 0);
    const data = {
      title: d.title,
      description: d.description,
      category: d.category,
      subcategory: d.sub ?? null,
      specialization: d.sub && d.spec ? d.spec : null,
      uploaderId,
      fileCount: rows.length,
      totalSizeBytes: total,
      downloadCount: d.downloads,
      viewCount: d.views,
      createdAt,
      deletedAt: null,
    };
    await prisma.sharedDocument.upsert({ where: { id: docId(d.key) }, update: data, create: { id: docId(d.key), ...data }, select: { id: true } });
    // The files are brought to exactly the designed set, so a file added or dropped by hand is undone.
    await prisma.sharedDocumentFile.deleteMany({ where: { documentId: docId(d.key) } });
    for (const r of rows) {
      await prisma.uploadedFile.upsert({
        where: { filename: r.filename },
        update: { ownerId: uploaderId, name: r.f.name, mimeType: r.mimeType, size: r.size, visibility: 'PRIVATE', purpose: 'document-hub' },
        create: { filename: r.filename, ownerId: uploaderId, name: r.f.name, mimeType: r.mimeType, size: r.size, visibility: 'PRIVATE', purpose: 'document-hub' },
        select: { id: true },
      });
      await prisma.sharedDocumentFile.create({
        data: {
          id: fileId(d.key, r.i),
          documentId: docId(d.key),
          fileUrl: up(r.filename),
          fileName: r.f.name,
          mimeType: r.mimeType,
          fileType: classifyFile(r.mimeType, r.f.name),
          sizeBytes: r.size,
          sortOrder: r.i,
          downloadCount: Math.round(d.downloads / rows.length),
          createdAt,
        },
        select: { id: true },
      });
      files++;
      bytes += r.size;
    }
  }
  await saveManifest(prisma, MANIFEST_KEY, manifest);

  // Reports: two pending ones, re-created each run.
  await prisma.documentReport.deleteMany({ where: { id: { startsWith: 'design-docrep-' } } });
  for (const r of REPORTS) {
    await prisma.documentReport.create({
      data: {
        id: r.id,
        documentId: docId(r.doc),
        reporterId: people.get(r.by)!,
        reason: r.reason as never,
        note: r.note,
        status: 'PENDING' as never,
        createdAt: new Date(now.getTime() - r.days * DAY),
      },
      select: { id: true },
    });
  }
  const packs = DOCS.filter((d) => d.files.length > 1).length;
  log(`  library: ${DOCS.length} documents (${packs} packs), ${files} files, ${Math.round(bytes / 1024)} KB; ${REPORTS.length} pending reports`);
  log(`  uploaders: Bharat ${DOCS.filter((d) => d.by === 'bharat').length}, Pooja ${DOCS.filter((d) => d.by === 'pooja').length}, people ${DOCS.filter((d) => d.by !== 'bharat' && d.by !== 'pooja').length}`);
  log('done');
}

async function removeAll(prisma: PrismaClient, log: (m: string) => void): Promise<void> {
  const hadManifest = await hasManifest(prisma, MANIFEST_KEY);
  const manifest = await loadManifest(prisma, MANIFEST_KEY, emptyManifest);
  const reports = await prisma.documentReport.deleteMany({ where: { id: { startsWith: 'design-docrep-' } } });
  log(`  reports: ${reports.count}`);
  // Reports a person made on a seeded document go with it (cascade).
  const docs = await prisma.sharedDocument.deleteMany({ where: { id: { startsWith: 'design-doc-' } } });
  log(`  documents (and their files and reports): ${docs.count}`);
  const rows = await prisma.uploadedFile.deleteMany({ where: { filename: { startsWith: 'design-library-' } } });
  log(`  upload rows: ${rows.count}`);
  let unlinked = 0;
  const names = new Set<string>(manifest.uploads);
  for (const d of DOCS) d.files.map(norm).forEach((f, i) => names.add(uploadName(d.key, i, f.name)));
  for (const n of names) if (removeUpload(n)) unlinked++;
  log(`  files removed from uploads/: ${unlinked}`);
  await removePeopleIfUnused(prisma, log, [CHAPTERS_KEY]);
  await prisma.setting.deleteMany({ where: { key: MANIFEST_KEY } });
  if (!hadManifest) log('  note: no manifest was found (only marked rows were removed)');
  log('removed');
}

if (require.main === module) {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { PrismaClient: Client } = require('@prisma/client') as typeof import('@prisma/client');
  const prisma = new Client();
  const has = (f: string) => process.argv.includes(f);
  seedLibrary(prisma, (m) => console.log(m), { remove: has('--remove'), dryRun: has('--dry-run') })
    .catch((e) => {
      console.error(e);
      process.exitCode = 1;
    })
    .finally(() => prisma.$disconnect());
}
