/**
 * What the chapters and library seeds share: the localhost guard, the uploads folder, the Setting-held
 * manifest each seed keeps (so `--remove` restores what it changed).
 *
 * Not run on its own; `chapters.ts`, `library.ts` and `seed-people.ts` import it.
 */
import type { Prisma, PrismaClient } from '@prisma/client';
import { copyFileSync, existsSync, mkdirSync, readFileSync, statSync, unlinkSync } from 'fs';
import { join, resolve } from 'path';

export const HOUR = 3_600_000;
export const DAY = 24 * HOUR;
export const SEED_ASSETS = resolve(__dirname, 'assets');
export const DEMO_IMAGES = resolve(__dirname, '..', '..', 'assets', 'images', 'demo');
export const PORTAL_AVATARS = resolve(__dirname, '..', '..', '..', 'irc-portal', 'backend', 'prisma', 'seed-assets', 'avatars');

export const up = (file: string) => `/uploads/${file}`;

/** DATABASE_URL from the environment, else from `.env` in the cwd. Never logged: it holds the password. */
function databaseUrl(): string | undefined {
  if (process.env.DATABASE_URL) return process.env.DATABASE_URL;
  const envFile = join(process.cwd(), '.env');
  if (!existsSync(envFile)) return undefined;
  return readFileSync(envFile, 'utf8').match(/^\s*DATABASE_URL\s*=\s*"?([^"\r\n]+)"?/m)?.[1];
}

export async function assertLocalDatabase(prisma: PrismaClient, log: (m: string) => void): Promise<void> {
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
  log(`database "${rows[0]?.db}" on ${addr || 'a local socket'}: local${url ? ' (DATABASE_URL host checked)' : ''}`);
  if (!existsSync(join(process.cwd(), 'prisma', 'schema.prisma'))) {
    throw new Error(`Run this from E:\\ICR\\irc-portal\\backend (cwd is ${process.cwd()}): uploads resolve from it.`);
  }
}

// ---------------------------------------------------------------------------
// Files
// ---------------------------------------------------------------------------

export const uploadsDir = () => {
  const dir = join(process.cwd(), 'uploads');
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
  return dir;
};

/** Copies `from` into uploads/ as `to`; the size in bytes. */
export function copyToUploads(from: string, to: string): number {
  if (!existsSync(from)) throw new Error(`Missing seed file: ${from}`);
  copyFileSync(from, join(uploadsDir(), to));
  return statSync(from).size;
}

export function removeUpload(name: string): boolean {
  const path = join(uploadsDir(), name);
  if (!existsSync(path)) return false;
  unlinkSync(path);
  return true;
}

const MIME: Record<string, string> = {
  pdf: 'application/pdf',
  doc: 'application/msword',
  docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  xls: 'application/vnd.ms-excel',
  xlsx: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  ppt: 'application/vnd.ms-powerpoint',
  pptx: 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  csv: 'text/csv',
  txt: 'text/plain',
  zip: 'application/zip',
  png: 'image/png',
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  webp: 'image/webp',
};
export const mimeOf = (name: string): string => MIME[name.split('.').pop()!.toLowerCase()] ?? 'application/octet-stream';

/** `classifyDocumentFile` of `@icr/shared` (packages/shared/src/documents.ts): MIME first, extension second. */
export function classifyFile(mimeType: string, fileName: string): string {
  const byMime: Record<string, string> = {
    'application/pdf': 'PDF',
    'application/msword': 'WORD',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'WORD',
    'application/vnd.ms-excel': 'SPREADSHEET',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'SPREADSHEET',
    'text/csv': 'SPREADSHEET',
    'application/vnd.ms-powerpoint': 'PRESENTATION',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation': 'PRESENTATION',
    'application/zip': 'ARCHIVE',
    'application/x-zip-compressed': 'ARCHIVE',
    'text/plain': 'TEXT',
  };
  const byExt: Record<string, string> = {
    pdf: 'PDF', doc: 'WORD', docx: 'WORD', xls: 'SPREADSHEET', xlsx: 'SPREADSHEET', csv: 'SPREADSHEET',
    ppt: 'PRESENTATION', pptx: 'PRESENTATION', zip: 'ARCHIVE', txt: 'TEXT',
    png: 'IMAGE', jpg: 'IMAGE', jpeg: 'IMAGE', webp: 'IMAGE', gif: 'IMAGE',
  };
  const mime = (mimeType || '').toLowerCase();
  if (byMime[mime]) return byMime[mime];
  if (mime.startsWith('image/')) return 'IMAGE';
  const ext = fileName.includes('.') ? fileName.split('.').pop()!.toLowerCase() : undefined;
  if (ext && byExt[ext]) return byExt[ext];
  return 'OTHER';
}

/** "2.4 MB" / "48 KB", as a chapter resource's size label. */
export function sizeLabel(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

// ---------------------------------------------------------------------------
// Manifest (a Setting row)
// ---------------------------------------------------------------------------

export async function loadManifest<T>(prisma: PrismaClient, key: string, empty: () => T): Promise<T> {
  const row = await prisma.setting.findUnique({ where: { key }, select: { value: true } });
  return row ? { ...empty(), ...(row.value as unknown as T) } : empty();
}

export async function saveManifest(prisma: PrismaClient, key: string, m: unknown): Promise<void> {
  const value = m as Prisma.InputJsonValue;
  await prisma.setting.upsert({ where: { key }, update: { value }, create: { key, value } });
}

export async function hasManifest(prisma: PrismaClient, key: string): Promise<boolean> {
  return !!(await prisma.setting.findUnique({ where: { key }, select: { id: true } }));
}

/** An Indian-clock moment `days` from `now` at `hour:minute`, as a UTC Date. */
export function istAt(now: Date, days: number, hour = 11, minute = 0): Date {
  const ist = new Date(now.getTime() + 5.5 * HOUR + days * DAY);
  return new Date(Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate(), hour, minute) - 5.5 * HOUR);
}

/** A stable number from a string, for varied-but-repeatable counts. */
export function spread(key: string): number {
  let h = 0;
  for (const c of key) h = (h * 31 + c.charCodeAt(0)) >>> 0;
  return h;
}
