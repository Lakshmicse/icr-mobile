# Role test: the company accounts (27 Oct 2026)

Plan and rules: `docs/TEST_PLAN_ROLES.md`. This page is the matrix for the **company side**: the people who work for a company that buys, sells and hires. Every cell below was run against the local portal API (`http://localhost:3001/api/v1`) through the app's own repositories, controllers and screens; the file that proves it is in the "Tests" table at the end.

## The accounts

The e2e passwords are read from `irc-portal/e2e/fixtures/users.json` when a test runs (`ICR_USERS_JSON` moves the file); a run without the file skips these tests. No password from that file is written into the repository; the other seeds' own (`Market@12345`, `Rfq@12345`, `Inbox@12345`) are the ones their seed docs already print.

| Short | Account | Role at the company | Notes |
|---|---|---|---|
| CA | `companyadmin@icr.test` Chetan | COMPANY_ADMIN | E2E Test Vendor Co: buys, sells and hires; employer-verified; Gold plan; phone on file (+44) |
| FP | `founder.professional@icr.test` Farah | COMPANY_ADMIN (personally PROFESSIONAL) | same company, the second admin; no phone |
| BA | `branchadmin@icr.test` Bina | BRANCH_ADMIN, placed at **Head Office** | office-scoped; no phone |
| RC | `recruiter@icr.test` Rahul | RECRUITER, placed at Head Office | office-scoped; no phone |
| HM | `hiringmanager@icr.test` Hema | HIRING_MANAGER | interview feedback only: the narrow surface |
| MB | `marketplace.buyer@marketplace-design.icr.test` Maya | COMPANY_ADMIN of Meridian Corporate Estates | phone on file; the company never filed its company check and never started selling; its **only admin** |
| MN | `marketplace.nophone@marketplace-design.icr.test` Nikhil | BUYER at Meridian | no phone (a run takes it off, as the Marketplace seed leaves it; it had one from an earlier run) |

Others that act in the tests: Bluepeak (`rfq.bluedot@`) and Innova (`rfq.innowork@`) bid on the company's requirements; the Inbox Persona (Anita Rao) writes to the company; throwaway people (`@account-live.icr.test`) apply to its jobs and found a company.

## Summary

- **58 live tests** (RFQ 16, hiring and companies 19, inbox 5, drawn screens 18) and **15 offline tests** pinning the bugs fixed, all green on the last run.
- Every flow in the brief was run for every account that can do it; the accounts that cannot get the API's refusal as a sentence, shown by the screen (no thrown exception, no error state, no raw guard text).
- **6 bugs fixed** (F1-F6 below), **0 open in the app**, 3 observations about the portal, **13 website screens the company roles have and the app has not** (gaps).

## Matrix: flow x account

`W` works (the effect read back through the API, then undone) · `R` refused correctly (the API's sentence, shown by the screen, with the right fix or none) · `F` a bug was found and fixed here · `G` gap (website route; not built) · blank: not applicable to the role, or not run for it (the API behaves the same as for the account beside it).

### Requirements as the BUYING company

| Flow | CA | FP | BA | RC | HM | MB | MN |
|---|---|---|---|---|---|---|---|
| Post RFQ composer: filled from the account (company, contact, phone, email); every rule refuses what the API refuses; enquiry, staged RFQ, items, places, a file, draft, invite-only | W | W (draft, edit, publish, copy, cancel, delete) | R, F1 | R, F1 | R, F1 | W | W (asked for the contact number) |
| The service list of the composer | F5 | | | | | | |
| My RFQ's: counts, views, search, a card; a passed deadline reads once | W, F4 | W | R, F2 | R, F2 | R, F2 | W (empty) | W (empty; sees the company's) |
| Requirement page: replies, best price, sort | W | W (runs the other admin's) | R, F3 | R, F3 | R, F3 | W | W (runs Maya's) |
| Shortlist / decline / restore | W (screen and controller) | | | | | | W |
| Select, close; a staged RFQ to a purchase order | W | | | | | | W (select, close) |
| Files: the requirement's public, a bid's private, fetched with the session | W | | | | | | |
| Alerts: a bid is announced, read when the page opens | W | (the portal tells only the poster) | | | | | |
| Messages to bidders: one thread per requirement and supplier | W | | | | | | |

### Marketplace as a company

| Flow | CA | FP | BA | RC | HM | MB | MN |
|---|---|---|---|---|---|---|---|
| Request for Quote succeeds (a service, a product) with a phone on file; it is the company's, private to the supplier | W | | | | | W | |
| Asked for a mobile number when the profile has none: refused without, saved with the request | | | | | | | W |
| Ask the company's own supplier listing | F6 | | | | | | |
| A role that does not post | | | R, F6 | R, F6 | R, F6 | | |
| Find work and My bids (the company as a seller) | W | W | R | R | R | "Start selling" offered | R |

### Company inbox (Messaging)

| Flow | CA | FP | BA | RC | HM | MB | MN |
|---|---|---|---|---|---|---|---|
| Switcher: own messages and the company's, with the topics the role answers | all 5 | all 5 | Careers | Careers | none | all 5 | Procurement |
| Reads the threads of its topics, not the others | W | W | W (Careers; Sales hidden) | W | R | | W |
| Reply as the company ("Replying as ..."); the member sees the company | W | | | W | R | | W |
| Assign / Done / Spam / back to Open (kept, put back) | W | | W (Done) | | R | | |
| A bidder's message reaches the buying team (Procurement topic) | W | W | not shown | not shown | R | | W |

### Hiring

| Flow | CA | FP | BA | RC | HM | MB | MN |
|---|---|---|---|---|---|---|---|
| Who is on a hiring team; the board's "Post a job" | W | W | W | W | R ("Posting jobs is for hiring teams") | W | R |
| Jobs you posted: figures, tabs, search, office scope | W (12) | W (12) | W (office, 8) | W (office, 8) | R | W (empty) | R |
| Post a job: shared publish rules, blockers shown, salary optional; typed and published through the screen | W | | W | W | | R (company check, the API's sentence) | |
| Publish, edit, pause, close, reopen, delete | W | W (the other admin's) | W | W | | | |
| An admin's posting has no office; a recruiter's or office admin's lands in Head Office and the other office role sees it | W | | W | W | | | |
| A posting outside the office: pipeline, edit, close, delete refused ("This belongs to a different office.") | | | R | R | | | |
| Applicants: pipeline, an application read whole (the viewed receipt), move, rating, note | W | | W (office job) | W (office job) | R | | |
| Interviews: schedule, reschedule, call off, with the hiring manager on the panel | W | | | | reads his own panel (API) | | |
| Interview feedback by the hiring manager | | | | | **G**; the API: only assigned panels, only after the interview starts | | |
| Message the applicant (the same thread each time) | W | | | | | | |
| Job invites (send), talent search | **G** | **G** | **G** | **G** | | | |
| Offers | not repeated here (`jobs_employer_live_test.dart`) | | | | | | |
| The person's own career reads (applications, saved, alerts, invitations, quota), the bell | W | W | W | W | W | W | W |

### Companies screens

| Flow | CA | FP | BA | RC | HM | MB | MN |
|---|---|---|---|---|---|---|---|
| My companies: role, office, Active, members; "Leave" offered | W | W | W (Office Admin, Head Office) | W | W | W | W (Buyer) |
| The only admin cannot leave (the API's refusal; the row says so; no Leave button) | | | | | | R | |
| Switch to yourself and back (a fresh token pair, the office kept) | | | | | W | | |
| Ask to join another company, its admin is told, take the request back | | | | | W | (told) | |
| Create a company (a new person; sole admin; found by the company search) | W (throwaway) | | | | | | |

## Bugs found and fixed

| # | Bug | Fix | Proof (fails without it) |
|---|---|---|---|
| F1 | An office admin, a recruiter or a hiring manager opening **Post RFQ** was given the whole form, filled it in, and was refused with the guard's "Insufficient role permissions" | `Poster.roleCannotPost` / `cannotPostMessage`; the composer says "Requirements aren't part of your role" in place of the form and draws no Send (`lib/features/rfq`) | `test/role_company_fixes_test.dart`; live `... are refused in sentences the screens can show`, screens `... are told the limit of their role` |
| F2 | **My RFQ's** told those same members to "Create a company page", though they have one | the list reads who was refused (`MyRfqsController.poster`) and says what their role may do, with no button; a person with no company keeps the old notice | same |
| F3 | The **requirement page** said a requirement of the person's *own company* "belongs to another company or person" | `RfqDetailController._notOwnerWords`: "This is a requirement of E2E Test Vendor Co ... as an office admin you can read the brief only"; the old sentence stays for another company's | `role_company_fixes_test.dart`; live `who may run requirements`; screens `the requirement page` |
| F4 | A passed deadline read **"Pre-qual closes closed 8 days ago"** and "Quotes due closed 2 days ago" (seen on a card of the e2e RFQ) | `deadlineOf`: "Pre-qual closed 8 days ago", "Quotes closed 2 days ago", "Replies closed today" (`rfq_format.dart`) | `role_company_fixes_test.dart` `a deadline that has passed` (checked: it fails on the old wording); screens `My RFQ's for the company admin` |
| F5 | The service picker of **Post RFQ** said "The list of services could not load." for about a second while the list was still loading, on every open | `PostRfqController.categoriesLoading`; "Loading the list of services..." then the picker; the error only after a refusal | `role_company_fixes_test.dart` `the list of services`; screens `Post RFQ opens for the admin and the buyer` |
| F6 | **Request for Quote** from the company's own supplier profile showed "No valid companies to invite."; for a member of a company whose role does not post it showed the guard's "Insufficient role permissions" and (after another agent's button) offered "Create a company" | `QuoteController` asks who the person is once (`MarketplaceRepository.myCompanyId()`, an additive method with a default, the API reads `/auth/me`): own listing, "This is your own company's listing: a company cannot ask itself for a quote."; a member of a company, "Only a company can ask suppliers for quotes. Create a company page on ICR first, or ask your company's admin to send this one." with no button; a person with no company keeps the button (`lib/features/marketplace`) | `role_company_fixes_test.dart` `Request for Quote ...`; live `a company that sells and buys cannot ask its own listing`, `... are refused a quote request in a sentence`; screens `... are told, in the form, who can send it` |

F1-F3 are one root cause: the screens knew "no company" and "company, wrong role" only as one case.

## Bugs open

None in the app. Three observations about the portal, none needed by the app (`docs/backend-requests/`: no new file):

1. `PATCH /users/me { "phone": null }` answers **500**; `{ "phone": "" }` clears the number (what the app's "Remove number" sends). A caller sending null gets an internal error, not a 400.
2. A bid alert (`bid_received`) is sent to the person who **posted** the requirement, not to the company's other admins: Farah is not told of a bid on Chetan's requirement, though she can open and run it. The website behaves the same.
3. The guard answers every role refusal with the same words ("Insufficient role permissions"), whether the person has no company or has a company and the wrong role. The app words the two apart by asking who the person is.

## Gaps: the website's company workspace has it, the app has not (not built)

| What | Website route | Who has it there |
|---|---|---|
| Team: members, invites, role changes, **approving or declining join requests**, inbox topics | `/manage/team` | CA, FP, BA |
| Offices; and the **office of a job** (the website's composer has an office field, the app's does not: an admin's posting has no office, so the office roles cannot see it) | `/manage/locations` | CA, FP |
| Company profile, supplier listing, the **company check (KYC)** | `/company`, `/company?tab=verification` | CA, FP, MB, MN (profile) |
| Plans, billing and payments; promoting a job | `/membership`, `/pricing/corporate`, `/pricing/supplier`, `/manage/jobs` (Promote) | everyone |
| Dashboards (company, hiring, supplier) | `/dashboard` | everyone |
| Certifications | `/manage/certifications` | CA, FP, MB |
| Hiring drives (campaigns) | `/manage/campaigns` | CA, FP, BA, RC |
| Hiring reports | `/manage/reports` | CA, FP, BA, RC |
| Product and service catalogue | `/manage/products`, `/manage/services` | CA, FP, MB |
| Projects | `/manage/projects` | CA, FP, BA, RC |
| Talent search and talent intelligence; **sending a job invite** | `/talent`, `/manage/intelligence` | CA, FP, BA, RC |
| **Interview panel**: the list of interviews a person sits on and the scorecard | `/manage/interviews` | HM (his whole workspace), and RC, BA, CA, FP |
| Integrations (API keys, webhooks) | `/manage/integrations` | CA, FP |

The gap that leaves a role with almost nothing to do is the **hiring manager**: the API lets Hema read the interviews she sits on (`GET /interviews/mine`, `GET /interviews/:id`) and send a scorecard once the interview has started (`POST /interviews/:id/feedback`); the app has no screen for either. What she has in the app is the Jobs board as a candidate, Messages (her own), My companies, the bell, and the "added to the panel" notification, which opens the website.

## Tests

`flutter test --no-pub --timeout=100s <file> --concurrency=1` with the stack up and the RFQ, inbox and Marketplace seeds already run. The drawn-screens file takes about three and a half minutes (it waits in real time for the screens to load, and the sign-in throttle is shared with other runs); the rest take under two.

| File | Tests | Covers |
|---|---|---|
| `test/live/role_company_rfq_live_test.dart` | 16 | who may run requirements; the composer (rules against the API, enquiry, draft/edit/copy/cancel/delete, invite-only, a BUYER with no phone); the replies (alerts, shortlist/decline, files, thread, select, close); a staged RFQ to a purchase order; the Marketplace quote (with a phone, without, own listing, refused roles) |
| `test/live/role_company_live_test.dart` | 19 | hiring team per account; the Jobs board, career reads and the bell; the office scope (list, per id); the composer's shared rules; lifecycle by role; the pipeline and interviews with the hiring manager; the companies calls |
| `test/live/role_company_inbox_live_test.dart` | 5 | the switchers; who reads which topic; reply as the company and sort; a bidder's thread; the BUYER's procurement |
| `test/live/role_company_screens_live_test.dart` | 18 | the drawn screens for each account: My RFQ's, Post RFQ, requirement page, alerts, Find work, My bids, the quote form, Jobs you posted, Post a job (typed and published through the screen), applicants and an application, inbox, conversation as the company, My companies |
| `test/role_company_fixes_test.dart` | 15 | offline: F1-F6 |
| `test/live/role_company_support.dart` | | the accounts, a throwaway applicant, a text dump of a screen |

What the live tests leave behind: nothing in the company's data (every posting and requirement is deleted, every interview round called off, the join request withdrawn, Nikhil's phone taken off, Hema ends acting for her company). Left on purpose: the throwaway people and companies (`@account-live.icr.test`, `Account Live Test Co role-company ...`; `tool/seed/account.ts --cleanup-live` sweeps both), read notifications, and the company-inbox threads between Anita Rao and the company (one per topic, reused by every run; the messages in them are withdrawn).

## Could not test

- Interview **feedback** as the hiring manager, the positive path: the API opens a scorecard only after the interview has started and refuses to schedule one in the past, so it cannot be reached live without scoring someone else's seeded interview (Hema's "Operations panel, Round 1" of 20 Oct is already past; her scorecard cannot be taken back). The refusals (before it starts, not on the panel, not the hiring team) are proved.
- **Offers** and the candidate's answer: the role changes nothing there; covered by `jobs_employer_live_test.dart`.
- A device: no emulator was used.
