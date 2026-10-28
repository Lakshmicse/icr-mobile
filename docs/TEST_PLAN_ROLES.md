# Role-by-role test plan (27 Oct 2026)

The owner's order: **every flow must work for every kind of account** (buyer, company, vendor, admin), "I need a fully working app". The 8 flows were built and wired on 26 Oct; this is the proof pass. Read `docs/BUILD_BRIEF_RUN3.md`, `docs/REFINE_BRIEF.md` ("Live tests"), `docs/FIDELITY_AUDIT.md` and the `docs/screens/*.md` of the flows you test first.

## What "works" means

For your persona, for each flow in `docs/screens/`:

1. **It opens and shows real content** (or a proper empty state), never an error, a raw exception text, a red screen or an endless spinner.
2. **Every control does what it says** against the live API: a write is read back through the API and undone where the API allows.
3. **The role's limits are shown, not crashed on.** What the account is not allowed to do comes back from the API as a sentence ("Requirements are posted for a company…"); the screen shows that sentence and, where there is a fix (create a company, add a phone number), offers it.
4. **Nothing the role can do is hidden from it**: e.g. a company admin sees the company-side screens, a supplier the supplier side. If the app has no screen for something the website offers that role, list it as a **gap** (do not build it).

## The accounts (local database only)

Passwords are in `E:\ICR\irc-portal\e2e\fixtures\users.json` (read them from there; never write them into a file you create). Seeds' own personas are in `tool/seed/README.md`. Login is throttled (30 per minute per IP) and every API call 120 per minute per IP, shared with other agents: `liveClient` waits and retries on 429, use it, and keep tests lean.

| Role | Accounts |
|---|---|
| Buyer / professional (no company) | `buyer@icr.test`, `buyer@icr.dev` (Bharat, the emulator's person), `professional@icr.test` (Pooja), `guest@icr.test` |
| Company side | `companyadmin@icr.test` (COMPANY_ADMIN), `branchadmin@icr.test` (BRANCH_ADMIN, office-scoped), `recruiter@icr.test`, `hiringmanager@icr.test` (interview feedback only), `founder.professional@icr.test`, `marketplace.buyer@marketplace-design.icr.test` / `Market@12345` (COMPANY_ADMIN with a phone) and `marketplace.nophone@marketplace-design.icr.test` (BUYER, no phone) |
| Vendor / supplier | `vendor@icr.test` (VENDOR) and the supplier companies `tool/seed/marketplace.ts` seeds |
| Staff and mentor | `superadmin@icr.test` (SUPER_ADMIN, no company), `contentadmin@icr.test`, `supportagent@icr.test`, mentor `mentorship.srikanth@design.icr.test` / `Password123!` |

## Method (do both, in this order)

1. **Role matrix, live.** `test/live/role_<yourrole>_live_test.dart` (new files only). For each account and each flow: use the flow's own `Api…Repository` and controller through `liveClient(person)`, assert the effect by reading it back, undo it. Also **pump the real screen** with the live repository (look at how `test/in_app_screens_test.dart` builds providers and `test/live/*_live_test.dart` use `liveClient`) and assert: no thrown exception (`tester.takeException()`), the screen's loaded state or its proper empty/refusal state is showing, not its error state.
2. **Fix what is broken**, inside the flow's own folder, minimally; add a test that fails without the fix. Re-read a file immediately before editing it (other agents work in the same tree). Never edit `lib/core`, `lib/app.dart`, `lib/app_screens.dart`, the shell, the Discover sheet, the profile drawer, `pubspec.yaml`, or the portal: write the exact diff in your report. A backend change the app needs goes to `docs/backend-requests/<flow>.md`.
3. **Write `docs/ROLE_TEST_<yourrole>.md`**: a table flow x account with `works` / `refused correctly` / `bug fixed (what)` / `bug open (what)` / `gap (website has it, app has not)`, and the test that proves each `works`.

## Rules

- No emulator, adb, `flutter run`, `flutter build` (the lead drives the device). No commits.
- `flutter test --no-pub --timeout=60s <your files> --concurrency=1`; analyze only what you touch (`flutter analyze --no-pub <paths>`); never wait over 2 minutes on one command.
- Undo your writes. If something cannot be undone (an application, a sent message), do it on a row you created, and say so. Do not run the other seeds. Local database only.
- Do not tune pixels. Do not rewrite flows that work.
- Report (short): the matrix summary (counts), the bugs found and fixed, bugs open, gaps, every diff the lead must apply to a lead-owned file, and anything you could not test and why.
