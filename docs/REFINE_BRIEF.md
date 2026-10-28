# Refinement brief: make the LIVE app read like the PNGs, and prove every control works

The owner's words, 23 Oct 2026: "Designs not up to the mark; refine the designs, and working also needs to be tested." They judge the app running against the **local API** (not the bundled sample content) by looking at it beside the design PNGs on the emulator, and they expect each button to do its job for real.

So the job for each screen family is two things, done together:

1. **Visual:** the live screen must look like its PNG: the same elements in the same places, sizes, colours, type and spacing, with the local database's content (seeded by `tool/seed/`, see its README) filling the design's slots. Where the API truly has no field for a design element, the slot is filled with the nearest true thing, laid out exactly as the design lays its element out (same band, same type), never left out, never reshuffled, never a different widget shape. Say what you substituted in `docs/screens/<feature>.md`.
2. **Working:** every control on the screen (chips, filters, sort, search, tabs, bookmarks, buttons, "View More", pull-to-refresh, links, sheets, forms, Back) must do what it says, against the real API, and that must be **proved by a test**: a widget test for what the API cannot change, and a **live test** (see below) for anything that writes or reads through the API. A control that cannot work because the API has no endpoint for it is not drawn as if it worked: it does the nearest true thing (opens the website page, or explains in a snackbar) and that is tested too.

## Where things are

- App: `E:\ICR\icr-mobile` (Flutter 3.41, Dart 3.11). Your feature folder: `lib/features/<feature>/`; its tests `test/<feature>_test.dart`, goldens `test/golden/<feature>_golden_test.dart`, notes `docs/screens/<feature>.md`. Shared kit: `lib/core/widgets/` (title bar, search field, chips, section heading, buttons, `showDetailSheet`), theme `lib/core/theme/`.
- Designs: `docs/designs/*.png|jpg` (view them with Read). Method and tools: `docs/DESIGN_REPLICATION.md`, `tool/design/` (`measure.py`, `fitfont.py`, `compare.py`, and `devcompare.py <device.png> <design> <out.png>` which lays a device screenshot beside its design at the same scale).
- Live captures of your screens as they are now, taken on the emulator against the local API: `C:\Users\chetu\AppData\Local\Temp\claude\e--ICR-irc-portal\631d022a-6b7b-48c3-8d58-f1f2c4c99a60\scratchpad\live\<feature>\*.png` (1080 × 2400 at density 443 = 390 dp wide, the design's width). Compare them with the PNGs with `devcompare.py` and fix what differs.
- API: the portal at `E:\ICR\irc-portal` (NestJS + Prisma, `backend/src/modules/*`, schema `backend/prisma/schema.prisma`), running at `http://localhost:3001/api/v1`, Swagger at `http://localhost:3001/api/docs`. Read the controllers and services to find endpoints and fields; **do not change the portal** (it carries someone's uncommitted work) and do not restart it.
- Data: the local DB holds the designs' content (`tool/seed/README.md`). Personas: **Bharat Buyer `buyer@icr.dev` / `Buyer@123`** (the emulator's signed-in person) and **Pooja Professional `professional@icr.test` / `Test@12345`**. Mentor accounts: `mentorship.<key>@design.icr.test` / `Password123!` (e.g. `mentorship.srikanth@design.icr.test`, `mentorship.rajesh-1@…`). Reads are public for most lists. If a design element needs data the seed lacks, extend the seed script for your feature in `tool/seed/` (idempotent, marked, `--remove` must still undo it; run it from `E:\ICR\irc-portal\backend` with `NODE_PATH=E:/ICR/irc-portal/node_modules npx ts-node --transpile-only E:/ICR/icr-mobile/tool/seed/<script>.ts`), never by hand in the DB.

## Live tests (new, use them)

`test/live/live.dart` gives `liveTest(name, body)`, `liveClient([persona])` (an `ApiClient` signed in as Bharat by default, or `pooja`), `liveAnonymous()`, and the personas. A live test is tagged `live`, skips itself when the API is down, and must **undo what it did** where the API allows (cancel the RSVP, un-save, leave the council) so it can run again; where it cannot undo (an application, a mentoring request), use the second persona or a fresh seeded row and say so in the test. Put yours in `test/live/<feature>_live_test.dart`. Use the feature's own `Api…Repository`/controller through the client, the way the screen does, and assert the effect by reading it back through the API. Run: `flutter test test/live/<feature>_live_test.dart`. Example shape:

```dart
liveTest('a council joined from the screen is a seat the API keeps, and leaving gives it back', () async {
  final repo = ApiCouncilsRepository(api: await liveClient());
  final council = (await repo.overview()).councils.firstWhere((c) => !c.joined);
  await repo.join(council);
  expect((await repo.overview()).joined.map((c) => c.id), contains(council.id));
  await repo.leave(council);
  expect((await repo.overview()).joined.map((c) => c.id), isNot(contains(council.id)));
});
```
(Method names are those of your own repository; this is the shape, not a contract.)

## Rules

- Only touch your feature's files (lib, test, docs, seed script, demo assets). Shared kit changes: ask the lead (SendMessage) with the exact diff, don't edit `lib/core`, `lib/app.dart`, the shell or another feature.
- Keep the existing public constructors (`app.dart` wires them); if you must change one, say so in the report.
- `dart format lib test`, `flutter analyze` clean for the whole project, `flutter test` green (goldens re-recorded only after you eyeball the diff and it is the design), `flutter test test/live/<feature>_live_test.dart` green with the API up.
- Do not use the emulator or adb (the lead drives it) and do not run `flutter build`/`flutter run`. Do not commit.
- Report: what changed visually (with the measurements), every control and the test that proves it, what the API cannot do and what the control does instead, and anything you need from the lead.
