# Brief: a fully working app, with the new designs matched pixel for pixel

The owner's words, 24 Oct 2026: the mobile designs do not cover every flow, so build the **complete flow** of each module the way the website's mobile-friendly pages do it, so the Android and iOS app is a fully fledged, clean app. Match the designed screens **pixel to pixel**. The backend may change where the app needs it, but **the website must not be disturbed**.

Read `docs/REFINE_BRIEF.md` first. Its sections "Where things are", "Live tests" and "Rules" still apply, with the changes below.

## What "complete flow" means

On your module, everything a signed-in member can do on the website's mobile layout, they can do in the app, against the real API, without leaving it. The only things that may still open the website are a **payment** (PayU checkout), the **legal pages** (terms, privacy) and anything this brief or the lead names. Every handoff you remove is replaced by a real screen, and every remaining one is listed in your `docs/screens/<feature>.md` with the reason.

- **Designed screens** (`docs/designs/`) must match their PNG: the same elements in the same places, sizes, colours, type and spacing, filled from the API (seed the design's content into the local DB, see `tool/seed/README.md`). Measure with `tool/design/` and compare a golden against the PNG.
- **Undesigned screens** (most of the flow) are built in the same visual language: reuse `lib/core/widgets` and `lib/core/theme`, Work Sans headings, IBM Plex Sans body text, the same card radii, borders, chip and button styles as the designed screens beside them. The website's own mobile layout is the reference for *what* each screen holds. Screenshots of it are in `E:\ICR\irc-portal\e2e\results\screenshots\*mobile*.png`, and the pages themselves are in `E:\ICR\irc-portal\frontend\src`.
- Every screen has a loading state, an error state with Retry, an empty state, and pull-to-refresh where it lists things.
- Forms validate the way the API does (read the DTO), show the API's own refusal message, and keep what the person typed when a send fails.

## Changes to the rules

- **Portal backend:** it is a live working tree with uncommitted mobile sign-in work. Do not edit it yourself. If the app truly needs something the API lacks, send the lead the exact diff, which must be additive (a new field in a select, a new endpoint), keep every web response unchanged, and come with a unit spec. The lead applies it. Prefer what already exists. Read the controllers, services and DTOs under `backend/src/modules/*`, and Swagger at `http://localhost:3001/api/docs`.
- **Seeds:** your own script `tool/seed/<feature>.ts`, following the existing ones. Tell the lead to add it to `run.ps1`.
- **Integration:** you own only your folders, listed in your task. Screens other features open take **callbacks** in their constructors (for example `onRequestQuote`, `onMessage`, `onOpenProfile`); the lead wires them in `lib/app.dart`, `lib/app_screens.dart`, the shell and the Discover sheet. Say in your report which constructor to call for which path or button.
- **The API's rate limit** is 120 requests a minute per IP, shared with the other builders running now. Keep live tests lean, run only your own live file with `--concurrency=1`, and let `liveClient`'s 429 retry do its job.
- `flutter test` contends for a lock with the other builders. That is normal: wait, don't kill processes.
- No emulator, adb, `flutter run` or `flutter build`: the lead drives the device. No commits.

## Report

Send the lead the following:

- the screens you built (the designed ones with their measurements against the PNG);
- every control and the test that proves it;
- the handoffs you removed and the ones you kept, with the reason;
- the constructors and callbacks to wire;
- any backend diff you need;
- the seed script.
