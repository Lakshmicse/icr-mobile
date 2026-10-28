# Run 2 (25 Oct 2026): read this after `FULL_APP_BRIEF.md` and `REFINE_BRIEF.md`

Those two briefs still apply. This page records what changed since they were written.

## What happened to run 1

Every builder of the 24 Oct run was cut off after about 25 minutes (weekly usage limit). What they left on disk is **partial**: mostly models, repositories and controllers, a few screens, almost no tests, no `docs/screens/<feature>.md`. Treat it as scaffolding to audit, not as finished work:

- Read the files in your folder before reusing them. Keep what is right, rewrite what is not. Check every endpoint against the real controller in `E:\ICR\irc-portal\backend\src\modules\*` and a real call to the running API.
- A model that parses a made-up shape is worse than none. Prove each parser against a real response (a live test).

## Build in finished slices

You can be cut off again. So never leave the project red:

1. One screen (or one flow) at a time: repository method, controller, screen, widget test, live test. Then the next.
2. `flutter analyze` on the whole project must stay clean after each slice. Another builder's file that fails is theirs: tell the lead, do not fix it.
3. After each slice, update `docs/screens/<feature>.md` with: what is done and proved, what is left, what each control does. If you are cut off, the next person starts from that file.

## The designs are now high resolution

`docs/designs/hires/` holds the owner's exports at roughly **4x** (a 390 dp frame is about 1560 px wide). Measure from these, not from the 2x files in `docs/designs/`.

| File | Screen |
|---|---|
| `marketplace.png`, `marketplace-3col.png` | Marketplace, phone (2 columns) and tablet (3 columns) |
| `supplier-overview.png`, `supplier-services.png`, `supplier-compliances.png` | Supplier profile sheet, its three tabs |
| `forums-new-home.png`, `forum-replies.png` | Home feed with the nested reply thread; a reply and the "+8 replies in this thread" row |
| `jobs-board.png`, `job-sheet.png` | Jobs board, job details sheet |
| `events-home.png`, `event-sheet.png` | Events, event details sheet |
| `councils.png` | Councils |
| `learning-centre.png`, `course-page.png` | Learning centre, course details sheet |
| `mentorship-landing.png`, `find-mentors.png`, `mentor-profile-overview.png`, `mentor-profile-offerings.png` | Mentorship |
| `profile-menu.png`, `discover-sheet.png` | Profile drawer, Discover sheet |
| `bottom-nav-7-tab.png`, `bottom-nav-5-tab.png`, `nav-forums-icon.png` | Bottom bar (the app keeps 7 tabs), the Forums icon |
| `figma-layer-list.png` | The owner's Figma layer names: the full list of designed screens |

The tall images are far taller than the Read tool shows at once (it shrinks them to 2000 px). **Crop before you look**: slice with Pillow into bands about 1400 px tall (`python -I -c "from PIL import Image; ..."`, save to a folder outside the repo or under `build/`), and read each band. Measure with `tool/design/measure.py`; compare a golden with the PNG with `tool/design/compare.py`.

## Backend

The portal is now merged with the latest `main`, migrated and running on `http://localhost:3001/api/v1`, Swagger at `/api/docs`. It carries the lead's uncommitted additive work for the app: Google and LinkedIn sign-in from the phone, and supplier saves (`GET /vendors/saved`, `GET /vendors/saved/ids`, `POST|DELETE /vendors/:id/save`).

- **Do not edit the portal.** If the app truly needs something the API lacks, write the exact additive diff (a field in a select, a new endpoint, a unit spec) to `docs/backend-requests/<feature>.md`, keep going with the nearest true behaviour, and say so in your report. The lead applies it and tells you. Every web response must stay byte-for-byte what it is today.
- The API's rate limit is 120 requests a minute per IP, shared with every other builder. Keep live tests lean and run only your own file with `--concurrency=1`.

## Rules that did not change

- Own only your folders (listed in your task). Shared kit (`lib/core`), `lib/app.dart`, `lib/app_screens.dart`, the shell and the Discover sheet are the lead's: screens other features open take **callbacks in their constructors**, and your report says which constructor to call for which path.
- No emulator, adb, `flutter run` or `flutter build`. No commits. `flutter test` shares a lock with the other builders: wait, never kill processes.
- Every screen has loading, error with Retry, empty, and pull-to-refresh where it lists. Forms validate as the API's DTO does, show the API's own refusal, and keep what was typed when a send fails.
- A handoff to the website is allowed only for a payment (PayU), the terms and privacy pages, and what the lead names. Everything else is a real screen. List each remaining handoff and its reason in `docs/screens/<feature>.md`.
- Seeds are your own `tool/seed/<feature>.ts`, idempotent and removable (`tool/seed/README.md`). Local database only.

## Report (keep it short)

Screens built and their measured match against the PNG; every control with the test that proves it; handoffs kept and why; constructors the lead must wire; backend requests; the seed script; what is left.
