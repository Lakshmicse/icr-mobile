# Run 3 (26 Oct 2026): read this after `FULL_APP_BRIEF.md`, `REFINE_BRIEF.md` and `BUILD_BRIEF_RUN2.md`

Those briefs still apply. This page records the state after run 2 and the decisions made since.

## State on 26 Oct

- Runs 1 and 2 were both cut off (usage limit, then billing). What they left is **scaffolding, not finished work**: models, repositories, controllers, some screens, few tests. `flutter analyze` showed 11 errors, all in half-written files (career repository, `company_insights_screen.dart`, `inbox_screen.dart`, `conversation_screen.dart`).
- The API is running at `http://localhost:3001/api/v1` (Swagger `/api/docs`). Personas and seeds: `REFINE_BRIEF.md`, `tool/seed/README.md`.
- Designed and built, with tests: sign-in, home feed, profile drawer, Discover sheet, events (+ sheet), councils, learning (all doors), mentorship landing, find mentors, mentor profile (+ offering sheet), jobs board (+ job sheet).
- **Designed and NOT built:** Marketplace (phone 2 columns, tablet 3 columns), Supplier profile sheet (Overview, Products & services, Compliances & Proofs), the nested reply thread on the home feed and in Forums.
- Built but unproven (audit before reuse): requirements/RFQ, notifications, messaging, account, chapters, network, contact, career, mentoring desk.

## Decisions (owner's open questions, settled by the lead)

1. **Five tabs on the bar** (owner's call, 27 Oct 2026, replacing "seven tabs stay"): Home, Learning, Mentorship, Jobs, Discover, drawn as the 5-tab bar design with Mentorship in the slot where it shows Forums. Forums and Marketplace remain screens of the shell (`AppTab.forums` / `AppTab.marketplace`) but have no slot in `IcrBottomNav.tabs`; how they are reached is open.
2. **Supplier reviews stay anonymous**: the API does not expose a reviewer's company or role, and the app will not either. The Compliances & Proofs "Audited Enterprise Proofs" rows show the review's rating, its text and "Verified buyer", laid out exactly as the design lays out the company line.
3. **Tablet**: any screen whose design has a tablet variant uses 3 columns from 600 dp wide and 2 below (`LayoutBuilder`), never a separate widget tree.

## The rule that matters most: build in finished slices

You can be cut off again. After **every** slice the project must be green:

1. One screen or flow at a time: repository method, controller, screen, widget test, live test.
2. `flutter analyze lib/features/<yours> test` shows nothing of yours; fix only your own files. If another builder's file is red, tell the lead.
3. After each slice update `docs/screens/<feature>.md` (done and proved / left / what each control does). The next person starts from that file.
4. Do not leave a file that imports something you have not written yet.

## Designs

`docs/designs/hires/` (about 4x; a 390 dp frame is about 1560 px wide). Tall images are far taller than one Read shows: crop with Pillow into ~1400 px bands first (save under `build/`, never the repo's tracked folders), measure with `tool/design/measure.py`, compare a golden or a device capture with `tool/design/compare.py` / `devcompare.py`. `figma-layer-list.png` lists every designed screen.

## Ownership

Own only your folders (listed in your task). `lib/core`, `lib/app.dart`, `lib/app_screens.dart`, the shell and the Discover sheet are the lead's: expose **callbacks in constructors** and say in your report which one to call for which path. No emulator, adb, `flutter run`, `flutter build`; no commits. Never edit the portal: send the lead the additive diff in `docs/backend-requests/<feature>.md`.

## Report

Short: screens built (designed ones with their measured match), every control and the test that proves it, handoffs kept and why, constructors for the lead to wire, backend requests, seed script, what is left.

---

## Run 3b (26 Oct, 13:25): state after the first run-3 builders (their session ended at ~13:00)

**The lead is now the session that wrote this file (irc-portal "5d"/fork). Callbacks, wiring, the shell, `lib/core`, `pubspec.yaml`, `lib/app*.dart`, the Discover sheet and the profile drawer are still the lead's.** Three auditors are running inside `events`, `councils`, `mentorship`, `mentor_profile`, `learning*`: nobody else touches those folders.

What the 12:45-13:00 builders left (compiles: `flutter analyze` showed only 9 errors, all in `mentorship_my/my_mentoring_screen.dart`, which imports tabs that were never written). It is **unproven**: read before reuse, check each endpoint against the controller and a real call, add the missing tests.

| Folder | Left on disk | Missing |
|---|---|---|
| `marketplace` | models, repository (api + demo), controller, filters, links, navigation, styles (2.4k lines) | **every screen**, tests, seed, docs |
| `forum` | models, api + demo repository (1.4k) | controllers, **every screen**, tests; the nested reply look in `feed/` |
| `rfq` | 25 files, 7 screens, tests `rfq_*`, live test, `docs/screens/rfq.md` (status table inside) | proof of the frame screens |
| `notifications`, `messaging` | controllers, screens (notifications, inbox, conversation), fakes, `notifications_test` | messaging tests, live tests, docs |
| `account`, `auth`, `network`, `contact` | sign-up, recovery, verify-email, companies (list/create/join/leave), saved items, network, contact, tests `signup_test`, `recovery_test`, `saved_test`, `network_test`, `contact_test` | person profile page, member profile, settings, live tests, docs |
| `chapters` | directory + chapter screens, controllers, kit, `chapters_test` | library, get-involved/volunteer (new folders), live tests, docs |
| `jobs`, `career` | board/sheets/apply; career repository, insights, `career_insights_test`, live test | saved/applications/interviews/alerts screens, employer side, docs |
| `mentorship_my` | pairing detail screen, repositories, controllers, forms (5.7k) | the tabs `my_mentoring_screen.dart` imports; `mentor_desk`, `become_mentor` (new) |

## New findings every builder must use (details and tools: `docs/FIDELITY_AUDIT.md`)

- **Body text is IBM Plex Sans Medium (w500)**: the designs set 10 dp paragraphs and sub-lines one weight step heavier than Regular. Fit a style on its LINE WIDTHS against the design (`python tool/design/line_widths.py DESIGN.png RENDER.png "x0,y0,x1,y1"`; ratio 1.000 = right), never on a guess and never by shrinking the size. `python tool/design/strip_diff.py <design> <render> --top 8 --out build/audit/side_x` shows which bands differ most; look at the crops.
- **A golden must pin the clock** when its content is dated (the designs' sample events are dated Oct 24 2026 and read "Ended" from Oct 25). Use an injectable "now", never `DateTime.now()` in something a golden draws.
- The API is up on :3001 (pid in `netstat`); it stops only if someone kills it: tell the lead.
- `flutter test` may re-resolve dependencies when `pubspec.yaml` changes: use `--no-pub`.
