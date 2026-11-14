// The mobile manual's kit: drives the app on the simulator and photographs each step.
//
// The app (integration_test/manual_driver_test.dart) asks this process for commands over
// HTTP and carries them out; the pictures are the simulator's own screen (`xcrun simctl io`),
// so they hold the status bar and any web view. The contract it writes is the website
// manuals' (ICR e2e/manual): <out>/<module>/<flow>/<nn>-<step>.jpg, <module>/<flow>.json,
// <module>/manual.json. See README.md.
import { execFileSync } from 'node:child_process';
import * as fs from 'node:fs';
import * as http from 'node:http';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const HERE = path.dirname(fileURLToPath(import.meta.url));
export const ROOT = path.join(HERE, '..', '..');
export const OUT = process.env.MANUAL_OUT ? path.resolve(process.env.MANUAL_OUT) : path.join(ROOT, 'build', 'manual');
export const API = process.env.MANUAL_API ?? 'http://localhost:3051/api/v1';
const PORT = Number(process.env.MANUAL_PORT ?? 3059);
const DEVICE = process.env.MANUAL_DEVICE ?? 'ICR Manual';
const PICTURE_WIDTH = 804; // twice the phone's 402 points: sharp in print at phone size
const RING = '#E11D2E';

// --- The simulator -----------------------------------------------------------

let udidCache = null;
export function udid() {
  if (udidCache) return udidCache;
  if (process.env.MANUAL_UDID) return (udidCache = process.env.MANUAL_UDID);
  const all = JSON.parse(execFileSync('xcrun', ['simctl', 'list', 'devices', '-j'], { encoding: 'utf8' })).devices;
  for (const list of Object.values(all)) {
    const hit = list.find((d) => d.name === DEVICE && d.state === 'Booted');
    if (hit) return (udidCache = hit.udid);
  }
  throw new Error(`No booted simulator named "${DEVICE}". Boot it (tool/manual/README.md) or set MANUAL_UDID.`);
}

function photograph(file) {
  execFileSync('xcrun', ['simctl', 'io', udid(), 'screenshot', '--type=png', file], { stdio: 'pipe' });
}

// --- The link to the app -----------------------------------------------------

class Link {
  constructor() {
    this.queue = [];
    this.waiting = null; // the app's open poll
    this.pending = new Map();
    this.seq = 0;
    this.seen = false;
    this.server = http.createServer((req, res) => this.handle(req, res));
  }

  listen() {
    return new Promise((resolve, reject) => {
      this.server.once('error', reject);
      this.server.listen(PORT, '127.0.0.1', resolve);
    });
  }

  handle(req, res) {
    if (req.method === 'GET' && req.url === '/next') {
      this.seen = true;
      const next = this.queue.shift();
      if (next) return this.send(res, next);
      const timer = setTimeout(() => {
        if (this.waiting?.res === res) this.waiting = null;
        this.send(res, {});
      }, 25_000);
      this.waiting = { res, timer };
      return;
    }
    if (req.method === 'POST' && req.url === '/result') {
      let body = '';
      req.on('data', (c) => (body += c));
      req.on('end', () => {
        this.send(res, {});
        try {
          const r = JSON.parse(body);
          const p = this.pending.get(r.id);
          if (p) {
            this.pending.delete(r.id);
            p(r);
          }
        } catch {
          /* a malformed answer resolves nothing; the command times out */
        }
      });
      return;
    }
    res.writeHead(404).end();
  }

  send(res, obj) {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify(obj));
  }

  cmd(command, { timeout = 60_000 } = {}) {
    const id = ++this.seq;
    const msg = { id, ...command };
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`${command.do}: the app did not answer in ${timeout / 1000}s (is the driver running?)`));
      }, timeout);
      this.pending.set(id, (r) => {
        clearTimeout(timer);
        if (r.flutterError && !/HTTP request failed|Unable to load asset|overflowed|ListTile background/.test(r.flutterError)) console.warn(`    (the app reported: ${r.flutterError.slice(0, 220)})`);
        if (r.ok) resolve(r.data ?? null);
        else reject(new Error(`${command.do} ${JSON.stringify(command.on ?? command.path ?? command.email ?? '')}: ${r.error}`));
      });
      if (this.waiting) {
        const { res, timer: t } = this.waiting;
        clearTimeout(t);
        this.waiting = null;
        this.send(res, msg);
      } else {
        this.queue.push(msg);
      }
    });
  }

  close() {
    if (this.waiting) {
      clearTimeout(this.waiting.timer);
      this.send(this.waiting.res, {});
      this.waiting = null;
    }
    return new Promise((resolve) => {
      this.server.close(() => resolve());
      this.server.closeAllConnections?.();
    });
  }
}

// --- People ------------------------------------------------------------------

/** The seeded accounts a flow signs in as. Passwords are the local seeds' published defaults. */
export function loadPeople() {
  const file = process.env.ICR_USERS_JSON ?? path.join(ROOT, '..', 'irc-portal', 'e2e', 'fixtures', 'users.json');
  const people = JSON.parse(fs.readFileSync(path.join(HERE, 'people.json'), 'utf8'));
  if (fs.existsSync(file)) {
    for (const u of JSON.parse(fs.readFileSync(file, 'utf8'))) {
      // A person renamed on the copy (touchups.sql) names the fixture account whose password they kept.
      for (const key of Object.keys(people)) {
        if ((people[key].fixture ?? people[key].email) === u.email && !people[key].password) people[key].password = u.password;
      }
    }
  }
  return people;
}

// --- The kit a flow gets -----------------------------------------------------

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const READ_ONLY = new Set(['ping', 'frame', 'dump', 'rect', 'exists', 'wait', 'gone', 'idle', 'menu', 'unfocus']);
const slug = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

export class Manual {
  constructor(link, { module = null, flow = null } = {}) {
    this.link = link;
    this.module = module;
    this.flow = flow;
    this.steps = [];
    this.state = {};
    this.people = loadPeople();
    this.tokens = new Map();
  }

  // The app
  async cmd(command, opts) {
    try {
      return await this.link.cmd(command, opts);
    } catch (e) {
      // A lost answer to a command that changes nothing is asked again, once.
      if (/did not answer/.test(e.message) && READ_ONLY.has(command.do)) return this.link.cmd(command, opts);
      throw e;
    }
  }
  ping() {
    return this.cmd({ do: 'ping' });
  }
  person(who) {
    const p = this.people[who];
    if (!p) throw new Error(`No person "${who}" in tool/manual/people.json`);
    if (!p.password) throw new Error(`No password for "${who}" (${p.email}): users.json was not found`);
    return p;
  }
  /** Signs the app in as a person from people.json (or `{ email, password }`). */
  async become(who) {
    const p = typeof who === 'string' ? this.person(who) : who;
    for (let attempt = 0; ; attempt++) {
      try {
        return await this.cmd({ do: 'become', email: p.email, password: p.password }, { timeout: 90_000 });
      } catch (e) {
        // The sign-in route has its own, tighter limit; wait it out rather than fail a long run.
        if (attempt < 4 && /too many|429|rate/i.test(String(e.message))) {
          await sleep(20_000);
          continue;
        }
        throw e;
      }
    }
  }
  signOut() {
    return this.cmd({ do: 'signOut' });
  }
  open(p) {
    return this.cmd({ do: 'open', path: p });
  }
  tab(name) {
    return this.cmd({ do: 'tab', name });
  }
  drawer() {
    return this.cmd({ do: 'drawer' });
  }
  back() {
    return this.cmd({ do: 'back' });
  }
  home() {
    return this.cmd({ do: 'home' });
  }
  tap(on, opts = {}) {
    return this.cmd({ do: 'tap', on, ...opts });
  }
  tapAt(x, y, opts = {}) {
    return this.cmd({ do: 'tapAt', x, y, ...opts });
  }
  /** Taps a point inside a control, as fractions of its box: the tick of a consent line whose middle is a link. */
  async tapIn(on, fx = 0.5, fy = 0.5, opts = {}) {
    const { rects } = await this.cmd({ do: 'rect', on });
    if (!rects.length) throw new Error(`tapIn: nothing matches ${JSON.stringify(on)}`);
    const [x, y, w, h] = rects[0];
    return this.tapAt(x + w * fx, y + h * fy, opts);
  }
  async rect(on) {
    return (await this.cmd({ do: 'rect', on })).rects[0] ?? null;
  }
  /** Types into a field, then puts the keyboard away so the next tap and the next picture see the whole screen. */
  async enter(on, text, { keep = false } = {}) {
    await this.cmd({ do: 'enter', on, text });
    if (!keep) await this.unfocus();
  }
  action(name = 'done') {
    return this.cmd({ do: 'action', name });
  }
  unfocus() {
    return this.cmd({ do: 'unfocus' });
  }
  swipe(dy, opts = {}) {
    return this.cmd({ do: 'swipe', dy, ...opts });
  }
  scrollTo(on, opts = {}) {
    return this.cmd({ do: 'scrollTo', on, ...opts }, { timeout: 120_000 });
  }
  wait(on, ms = 15_000) {
    return this.cmd({ do: 'wait', on, ms }, { timeout: ms + 30_000 });
  }
  gone(on, ms = 15_000) {
    return this.cmd({ do: 'gone', on, ms }, { timeout: ms + 30_000 });
  }
  idle(ms = 12_000) {
    return this.cmd({ do: 'idle', ms }, { timeout: ms + 30_000 });
  }
  pause(ms) {
    return this.cmd({ do: 'sleep', ms }, { timeout: ms + 30_000 });
  }
  async exists(on) {
    return (await this.cmd({ do: 'exists', on })).n > 0;
  }
  async dump(filter) {
    const d = await this.cmd({ do: 'dump', ...(filter ? { filter } : {}) });
    return d.rows
      // An icon is a glyph from a private-use block: not text anyone reads.
      .filter((r) => r.k || r.field !== undefined || r.input || r.tip || (r.t && !/^[\u{E000}-\u{F8FF}\u{F0000}-\u{10FFFF}]*$/u.test(r.t)))
      .sort((a, b) => a.r[1] - b.r[1] || a.r[0] - b.r[0])
      .map((r) => {
        const bits = [];
        if (r.k) bits.push(`K ${r.k} <${r.type}>`);
        if (r.t) bits.push(`T ${JSON.stringify(r.t)}`);
        if (r.field !== undefined) bits.push(`FIELD ${JSON.stringify(r.field)}`);
        if (r.input) bits.push(`INPUT ${JSON.stringify(r.input)}`);
        if (r.tip) bits.push(`TIP ${JSON.stringify(r.tip)}`);
        return `${String(r.r[1]).padStart(4)} ${String(r.r[0]).padStart(4)} ${String(r.r[2]).padStart(3)}x${String(r.r[3]).padEnd(3)} ${bits.join('  ')}`;
      })
      .join('\n');
  }

  // The API, for what the manual does not show: the other side of a request, or data a flow needs first.
  async token(who) {
    const p = typeof who === 'string' ? this.person(who) : who;
    if (this.tokens.has(p.email)) return this.tokens.get(p.email);
    const res = await fetch(`${API}/auth/login`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: p.email, password: p.password }),
    });
    if (!res.ok) throw new Error(`sign-in as ${p.email} failed: ${res.status} ${await res.text()}`);
    const { accessToken } = await res.json();
    this.tokens.set(p.email, accessToken);
    return accessToken;
  }
  async api(who, method, route, data) {
    const headers = { 'content-type': 'application/json' };
    if (who) headers.authorization = `Bearer ${await this.token(who)}`;
    const res = await fetch(`${API}${route}`, { method, headers, body: data === undefined ? undefined : JSON.stringify(data) });
    const text = await res.text();
    if (!res.ok) throw new Error(`${method} ${route} as ${typeof who === 'string' ? who : who?.email}: ${res.status} ${text.slice(0, 300)}`);
    return text ? JSON.parse(text) : null;
  }

  /**
   * SQL on the private copy, for putting back what an earlier run of the same flow changed
   * (a number already added, an application already sent). It refuses any database whose
   * name does not say it is a manual's.
   */
  sql(statement) {
    const db = process.env.MANUAL_DB ?? 'icr_mobilemanual';
    if (!/manual/.test(db)) throw new Error(`sql(): "${db}" is not a manual database`);
    return execFileSync('psql', ['-v', 'ON_ERROR_STOP=1', '-d', db, '-Atc', statement], { encoding: 'utf8' }).trim();
  }

  remember(key, value) {
    this.state[key] = value;
  }

  // The pictures
  /** A picture for looking at while a flow is written: not a step, nothing recorded. */
  async peek(file, { settle = true } = {}) {
    if (settle) await this.cmd({ do: 'frame' }, { timeout: 40_000 });
    fs.mkdirSync(path.dirname(file), { recursive: true });
    const raw = `${file}.raw.png`;
    photograph(raw);
    await sharp(raw).resize({ width: PICTURE_WIDTH }).jpeg({ quality: 82 }).toFile(file);
    fs.rmSync(raw);
    return file;
  }

  /**
   * One step: `text` is the sentence the manual prints, the picture is the phone as it is now.
   * `ring` circles the control the step uses (a finder, or several); `hide` paints over
   * something a test stack shows and production does not; `note` prints a muted line under it.
   */
  async shot(id, text, { ring = null, hide = null, note = null, allowBusy = false, keyboard = false } = {}) {
    if (!this.module || !this.flow) throw new Error('shot() outside a flow');
    const rings = ring ? (Array.isArray(ring) ? ring : [ring]) : [];
    const hides = [...(hide ? (Array.isArray(hide) ? hide : [hide]) : []), ...ALWAYS_HIDDEN];
    const rects = {};
    rings.forEach((f, i) => (rects[`ring${i}`] = f));
    hides.forEach((f, i) => (rects[`hide${i}`] = f));
    if (!keyboard) await this.unfocus();
    const frame = await this.cmd({ do: 'frame', rects }, { timeout: 40_000 });
    if (frame.busy && !allowBusy) throw new Error(`step "${id}": the screen is still loading; a manual never photographs a spinner`);
    rings.forEach((f, i) => {
      const r = frame.rects[`ring${i}`]?.[0];
      if (!r) throw new Error(`step "${id}": nothing on screen to ring for ${JSON.stringify(f)}`);
      // Its middle has to be on the screen, below the status bar: a ring nobody can see marks nothing.
      const cy = r[1] + r[3] / 2;
      const cx = r[0] + r[2] / 2;
      if (cy < 50 || cy > 874 || cx < 0 || cx > 402) throw new Error(`step "${id}": ${JSON.stringify(f)} is off the screen (at ${r.join(',')}); scroll to it first`);
    });

    const n = this.steps.length + 1;
    const dir = path.join(OUT, this.module, this.flow);
    fs.mkdirSync(dir, { recursive: true });
    const name = `${String(n).padStart(2, '0')}-${slug(id)}.jpg`;
    const raw = path.join(dir, `.${name}.png`);
    photograph(raw);

    const meta = await sharp(raw).metadata();
    const dpr = frame.dpr;
    const overlays = [];
    for (let i = 0; i < hides.length; i++) {
      for (const [x, y, w, h] of frame.rects[`hide${i}`] ?? []) {
        // Painted in the colour just beside it, so the note is gone and the card looks whole.
        const px = Math.max(0, Math.round((x - 3) * dpr));
        const py = Math.min(meta.height - 1, Math.max(0, Math.round((y + h / 2) * dpr)));
        const { data } = await sharp(raw).extract({ left: px, top: py, width: 1, height: 1 }).raw().toBuffer({ resolveWithObject: true });
        overlays.push(`<rect x="${(x - 1) * dpr}" y="${(y - 1) * dpr}" width="${(w + 2) * dpr}" height="${(h + 2) * dpr}" fill="rgb(${data[0]},${data[1]},${data[2]})"/>`);
      }
    }
    for (let i = 0; i < rings.length; i++) {
      const [x, y, w, h] = frame.rects[`ring${i}`][0];
      const pad = 5;
      const left = Math.max(2, x - pad);
      const top = Math.max(2, y - pad);
      const right = Math.min(meta.width / dpr - 2, x + w + pad);
      const bottom = Math.min(meta.height / dpr - 2, y + h + pad);
      overlays.push(
        `<rect x="${left * dpr}" y="${top * dpr}" width="${(right - left) * dpr}" height="${(bottom - top) * dpr}" rx="${10 * dpr}" fill="none" stroke="${RING}" stroke-width="${3 * dpr}"/>`,
      );
    }
    let img = sharp(raw);
    if (overlays.length) {
      const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${meta.width}" height="${meta.height}">${overlays.join('')}</svg>`;
      img = sharp(await img.composite([{ input: Buffer.from(svg) }]).png().toBuffer());
    }
    await img.resize({ width: PICTURE_WIDTH }).jpeg({ quality: 86, mozjpeg: true }).toFile(path.join(dir, name));
    fs.rmSync(raw);

    this.steps.push({ n, id: slug(id), text, ...(note ? { note } : {}), file: `${this.flow}/${name}` });
    console.log(`    ${String(n).padStart(2, '0')} ${id}`);
  }

  /** A step with no picture: something that happens off the phone (an email arrives). */
  say(id, text, { note = null } = {}) {
    this.steps.push({ n: this.steps.length + 1, id: slug(id), text, ...(note ? { note } : {}) });
    console.log(`    ${String(this.steps.length).padStart(2, '0')} ${id} (no picture)`);
  }
}

/** What a test stack shows that production does not: the on-screen one-time code and the test-payment note. */
const ALWAYS_HIDDEN = [{ key: 'signup.phoneDevCode' }, { contains: 'icr.test' }, { contains: 'http://localhost' }, { key: 'signup.devCode' }, { key: 'testCode' }, { key: 'forgot.testLink' }, { contains: 'Test mode' }];

// --- Defining and running manuals ---------------------------------------------

export const flow = (id, title, meta, run) => ({ id, title, ...meta, run });
export const defineManual = (id, title, flows) => ({ id, title, flows });

export async function connect() {
  const link = new Link();
  await link.listen();
  const m = new Manual(link);
  // The app polls every second or so while no host is listening.
  const until = Date.now() + 20_000;
  while (!link.seen && Date.now() < until) await sleep(200);
  if (!link.seen) {
    await link.close();
    throw new Error('The app is not asking for commands. Start the driver first (tool/manual/README.md).');
  }
  return { link, m };
}

/** Runs one manual's flows (all, or those whose id matches `grep`) and writes what they photographed. */
export async function runManual(manual, { grep = null } = {}) {
  const { link } = await connect();
  const dir = path.join(OUT, manual.id);
  fs.mkdirSync(dir, { recursive: true });
  const state = {};
  const stateFile = path.join(dir, '.state.json');
  if (fs.existsSync(stateFile)) Object.assign(state, JSON.parse(fs.readFileSync(stateFile, 'utf8')));
  const failed = [];
  try {
    for (const f of manual.flows) {
      if (grep && !f.id.includes(grep)) continue;
      console.log(`  ${manual.id} / ${f.id}`);
      fs.rmSync(path.join(dir, f.id), { recursive: true, force: true });
      for (const ext of ['jpg', 'txt']) fs.rmSync(path.join(dir, `.${f.id}-failed.${ext}`), { force: true });
      const m = new Manual(link, { module: manual.id, flow: f.id });
      m.state = state;
      let error = null;
      try {
        await m.home().catch(() => {});
        if (f.as === 'public') await m.signOut();
        else if (f.as) await m.become(f.as);
        await f.run(m);
      } catch (e) {
        error = e;
        failed.push(f.id);
        console.error(`    FAILED: ${e.message}`);
        try {
          await m.peek(path.join(dir, `.${f.id}-failed.jpg`), { settle: false });
          fs.writeFileSync(path.join(dir, `.${f.id}-failed.txt`), await m.dump());
        } catch {
          /* the app may be gone */
        }
      }
      const { run, ...meta } = f;
      fs.writeFileSync(
        path.join(dir, `${f.id}.json`),
        JSON.stringify({ ...meta, steps: m.steps, ...(error ? { failed: error.message } : {}) }, null, 2),
      );
      fs.writeFileSync(stateFile, JSON.stringify(state, null, 2));
    }
  } finally {
    await link.close();
  }
  fs.writeFileSync(
    path.join(dir, 'manual.json'),
    JSON.stringify({ id: manual.id, title: manual.title, flows: manual.flows.map((f) => f.id) }, null, 2),
  );
  return failed;
}
