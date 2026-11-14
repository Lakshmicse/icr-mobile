#!/usr/bin/env node
// What each kind of account's profile menu shows, read from the app itself:
//   node tool/manual/menus.mjs  →  build/manual/menus.json  (and a table on the screen)
import * as fs from 'node:fs';
import * as path from 'node:path';
import { OUT, connect } from './kit.mjs';

const WHO = (process.argv[2] ?? 'member,mentor,companyAdmin,recruiter,branchAdmin,hiringManager,seller,buyer,superAdmin').split(',');
const { link, m } = await connect();
const out = {};
try {
  for (const who of WHO) {
    if (!m.people[who]) continue;
    await m.become(who);
    const menu = await m.cmd({ do: 'menu' });
    out[who] = menu;
    console.log(`\n${who}  (${menu.role}${menu.companyId ? ', for a company' : ', as themselves'}${menu.mentorStatus ? `, mentor ${menu.mentorStatus}` : ''})`);
    for (const w of menu.workspaces) console.log(`  ${w.label}: ${w.sections.flatMap((s) => s.items.map((i) => i.label)).join(' · ')}`);
    if (menu.doors.length) console.log(`  doors: ${menu.doors.map((d) => d.label).join(' · ')}`);
  }
} finally {
  await link.close();
}
const file = path.join(OUT, 'menus.json');
const before = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : {};
fs.mkdirSync(OUT, { recursive: true });
fs.writeFileSync(file, JSON.stringify({ ...before, ...out }, null, 2));
