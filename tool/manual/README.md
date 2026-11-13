# The mobile app's user manual

One Word book for every kind of account, with a picture of every step:
`docs/manual/ICR-Mobile-App-User-Manual.docx`.

The book is a build product: it is written by `build.mjs` from what the flows captured, and is not kept in the repository.

A manual's steps are not written by hand and illustrated afterwards. A flow **carries each
step out** in the real app on a simulator and photographs it, so the manual cannot print a
step nobody could do. It follows the website manuals' kit (the portal's `e2e/manual`) and
writes the same contract.

```
integration_test/manual_driver_test.dart   the app, taking commands (sign in, open, tap, type)
tool/manual/kit.mjs                        the kit a flow gets: become, open, tap, enter, shot, say, api
tool/manual/flows/NN-chapter.mjs           one chapter's flows, in order (default export: defineManual)
tool/manual/run.mjs                        runs flows       → build/manual/<chapter>/…
tool/manual/build.mjs                      builds the book  → docs/manual/*.docx
tool/manual/m.mjs                          talks to the app by hand while a flow is written
tool/manual/people.json                    the seeded accounts flows sign in as
tool/manual/touchups.sql                   what the private copy needs after the seeds (real-looking names, the personas the seeds lack)
tool/manual/menus.mjs, words.py            each account's profile menu, read from the app, into the role chapters' tables
tool/manual/retext.py                      changes one step's sentence without a new run
tool/manual/sheet.mjs, look.sh             contact sheets and a quick look at the simulator, for checking a run
docs/manual/src/book.json                  the book: parts, chapters, appendices
docs/manual/src/NN-chapter.json            the words round a chapter's steps
```

## Running

The flows write (they sign up, post, apply, pay in test mode). Use a **private** database
and API, never a shared one: a copy of the local database, the portal API on a spare port,
and the seeds in `tool/seed` run on that copy.

```
# once: the private copy's content (after the portal's and tool/seed's seeds)
psql -v ON_ERROR_STOP=1 -d icr_mobilemanual -f tool/manual/touchups.sql

# once: an iPhone, a clean status bar. In the simulator's Settings → General → AutoFill & Passwords,
# switch "AutoFill Passwords and Passkeys" off, or iOS draws "Save Password?" over the app after a sign-in.
xcrun simctl create "ICR Manual" com.apple.CoreSimulator.SimDeviceType.iPhone-17 com.apple.CoreSimulator.SimRuntime.iOS-26-3
xcrun simctl boot "ICR Manual"
xcrun simctl status_bar "ICR Manual" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3

# the app with the driver (stays running; leave it in its own terminal)
flutter test integration_test/manual_driver_test.dart -d "ICR Manual" \
  --dart-define=API_BASE_URL=http://localhost:3051/api/v1 --dart-define=SITE_URL=http://localhost:3050

# the flows, then the book
cd tool/manual && npm install
MANUAL_API=http://localhost:3051/api/v1 node run.mjs --only 01-getting-started
node menus.mjs && python3 words.py          # the role chapters' menu tables
node build.mjs --as-of "12 November 2026"
```

The API must be started with the copy's `DATABASE_URL` in its environment: a backend folder whose
`dist` is a link to another checkout still reads that checkout's `.env`. Check through the API (a
row only the copy has) before the first flow runs.

Opening another app on the simulator (Settings, the browser) leaves a "◀ back" pill in the status
bar until the driver is started again: `node m.mjs quit`, then `flutter test …` once more.

`run.mjs --only <chapter> --grep <flow>` runs one flow. A flow that fails still writes what
it photographed, plus `.<flow>-failed.jpg` and `.<flow>-failed.txt` (what was on screen).

## Writing a flow

```js
import { defineManual, flow } from '../kit.mjs';

export default defineManual('03-jobs', 'Jobs', [
  flow('apply', 'Apply for a job', { who: 'Every member', as: 'member', intro: '…' }, async (m) => {
    await m.tab('jobs');
    await m.shot('board', 'Open the **Jobs** tab.', { ring: { text: 'Jobs' } });
    await m.tap({ key: 'job-card:abc' });
    …
  }),
]);
```

- `as` signs the app in before the flow (`public` is signed out). `m.become('recruiter')` switches person mid-flow.
- `m.open('/career')` opens a screen by its website path, the way a link in the app does. Use it to get to a starting point; the steps a reader follows should be taps.
- A finder is a key (`'signIn.email'`) or `{ key | text | contains | tooltip | type | keyPrefix }`, optionally with `in`, `i`, `last`.
- `m.shot(id, text, { ring, hide, note })` is one step: `text` is the sentence the manual prints, the picture is the phone as it is now. `ring` draws a red ring round the control the step uses. `m.say(id, text)` is a step with no picture.
- `m.api(person, method, route, data)` calls the API for what the manual does not show: the other side of a request, or data a flow needs first.
- Find what is on screen with `node tool/manual/m.mjs dump` (keys, texts, fields, with positions) and `peek:<file>`.
- Take the picture **before** the tap the step describes when the step is "select X" (ring X), and after it when the step is "the screen now shows Y".
- `m.shot` refuses to photograph a screen that is still loading.

### The sentences

- Written to the reader, in order, as instructions: "Select **Apply**." Bold exactly the words on the screen.
- Say where things are by the tab or menu, never by a path: "Open your **profile menu** and select **My applications**".
- Plain words. No role enum names (`COMPANY_ADMIN`), no route names, no internal terms.
- One step, one action (or one small group: "Fill in the title, place and pay").
- Sample data reads like real work in facility management in India. Never "test", "lorem", a timestamp in a title.

### What a test stack shows that production does not

`m.shot` paints over the on-screen one-time code ("Test mode: your code is …") and the
"Test mode" payment note. The sentence describes production: the code arrives by email or
SMS, payment goes to PayU.

## Keeping a flow repeatable

A flow that changes something starts by putting it back, with `m.sql(...)` on the private copy
(it refuses a database whose name does not say "manual"): the like and the reply it left, the
application it sent, the paper it opened. Run the chapters in order the first time; some feed
later ones (the newcomer's request to join is what the company admin approves).

## What the pictures cannot show

- Google and LinkedIn sign-in: the provider's own page is not ICR's to photograph.
- Payments leave for PayU, in the app or the browser.
- The website's pages opened inside the app need the website running at `SITE_URL`.
