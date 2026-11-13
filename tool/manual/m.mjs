#!/usr/bin/env node
// Talks to the app by hand, for writing a flow: each argument is one command, done in order.
//
//   node tool/manual/m.mjs 'become:member' 'open:/career' dump 'peek:/tmp/x.jpg'
//   node tool/manual/m.mjs '{"do":"tap","on":{"text":"Apply"}}' 'dump:apply'
//
// Shorthands: become:<person>  open:<path>  tab:<name>  tap:<key>  taptext:<text>  wait:<key>
//             dump[:filter]  peek:<file>  back  home  drawer  signOut  ping  idle  sleep:<ms>
// Anything starting with { is sent as it is.
import { connect } from './kit.mjs';

const { link, m } = await connect();
let failed = false;
try {
  for (const arg of process.argv.slice(2)) {
    const [head, ...restParts] = arg.split(':');
    const rest = restParts.join(':');
    let out;
    if (arg.startsWith('{')) out = await m.cmd(JSON.parse(arg), { timeout: 120_000 });
    else if (head === 'become') out = await m.become(rest);
    else if (head === 'open') out = await m.open(rest);
    else if (head === 'tab') out = await m.tab(rest);
    else if (head === 'tap') out = await m.tap(rest);
    else if (head === 'taptext') out = await m.tap({ text: rest });
    else if (head === 'tapleft') out = await m.tapIn(rest, 0.05, 0.5);
    else if (head === 'enter') out = await m.enter(rest.split('=')[0], rest.split('=').slice(1).join('='));
    else if (head === 'wait') out = await m.wait(rest.startsWith('{') ? JSON.parse(rest) : rest);
    else if (head === 'dump') out = await m.dump(rest || undefined);
    else if (head === 'peek') out = await m.peek(rest);
    else if (head === 'menu') out = await m.cmd({ do: 'menu' });
    else if (head === 'quit') out = await m.cmd({ do: 'quit' });
    else if (head === 'sleep') out = await m.pause(Number(rest));
    else if (['back', 'home', 'drawer', 'signOut', 'ping', 'idle', 'unfocus'].includes(head)) out = await m[head]();
    else throw new Error(`unknown command ${arg}`);
    if (out !== null && out !== undefined) console.log(typeof out === 'string' ? out : JSON.stringify(out));
  }
} catch (e) {
  failed = true;
  console.error(`FAILED: ${e.message}`);
} finally {
  await link.close();
}
process.exit(failed ? 1 : 0);
