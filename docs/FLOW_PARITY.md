# Flow parity: the website's journeys, in the Android app (29 Oct 2026)

The owner's order: *every flow the website has should work in the app the same way*. This is the record of the
proof pass that followed — what was run, what it found, what was fixed, and what the app still leaves to the website.

## How it was proved

The app has a **live suite** (`test/live/`, 60 files, ~800 tests) that drives every screen against the **local portal
API** as each seeded persona, reads every effect back through the API and undoes it. It was run three times in a row
on 29 Oct 2026, the database reseeded (`tool/seed/run.ps1`) before each:

| Run | Result | What it showed |
|---|---|---|
| 1 | 224 passed · 535 skipped · 37 failed | The harness's "is the API up?" probe took the rate limiter's 429 for "down" and skipped every file after the twelfth. Fixed in `test/live/live.dart`: the probe waits out a 429 (and, since run 3, a restart of the dev server). |
| 2 | 728 passed · 3 skipped · 65 failed | The real picture. Of the 65: **37 were data drift** (Bharat Buyer had been switched into TechCorp by an earlier run and never switched back, so every "buyer with no company" test was refused with 403; the design mentor Srikanth had been left paused by a test that timed out); **~20 were stale expectations** written against screens redesigned since (the Learning hub of 27 Oct, the forum's category label, the study note under the "decks follow their course" rule, the notifications gear, the new inbox); **3 were today's redesign** (the inbox's switcher moved into its menu; the assess bundle's payment goes through the phone now); **2 were harness** (plugins with no test double); **3 were seed or backend** (below). |
| 3 | 748 passed · 3 skipped · 45 failed (30 Oct, after the learning redesigns) | None of the 45 was a flow the app does differently by accident. **12 lagged the portal**: on 27 Oct the portal dropped the limit on how many mentees a mentor takes (`discoverable` alone stops requests), so every test on capacity (become a mentor, the desk's places, the profile's "2 slots open", the directory's `openSlots`) was asserting a rule that no longer exists — and the app still drew it (below). **~18 lagged the day's redesigns**: the newest-first feed, the hub's rail (no `door-*` keys, no My Learning strip), the programme page (the plan card now under the cards), the study screen's "Opens with" lock, the bare counts on a post card, the bell's settings in a row menu, a staff probe for a "Forums" tab the bar has not had. **~8 were data drift** (a chapter event the portal seeds for 8 Nov, Bharat's own forum post among the designed four, a bid left shortlisted, the impressions sum). **4 were the harness** (a fake context with no `mounted`, two scratch files). The rest are re-checked in run 4 (below). |
| 4 | 289 passed · 25 failed (the 16 files run 3 failed in, after the fixes; 30 Oct) | 20 of run 3's 45 held. Of the 25: **5 more were the portal's no-limit change** (a test helper still cast the dashboard's `capacity`, a tile the app no longer draws); **~9 lagged the redesigns** (the hub test built its controller without the assess catalogue the 27 Oct hub reads, so its headings never appeared; the drawer has no "View Full Profile" line; a held place reads in the bar's lower case; the poll sits further down a newest-first feed; the deck's plan sentence depends on the places held); **2 contradicted the app's own rule** — the moderation tests expected a staff console link to open the website, the router has refused those since the first commit ("for ICR's staff tools, which aren't in the app"); **3 were data** (Rohan Das carried 50+ cancelled asks from earlier runs, so a fresh purchase fell off the first page the app reads — the mentoring seed now sweeps unprefixed leftovers); **2 harness** (a refused local socket in one staff test, the pause test's five-minute timeout, both under investigation). Run 5 re-checks the ten files. |
| 5 | 218 passed · 16 failed (the ten files run 4 failed in; 30 Oct) | Nine more held. Of the 16: **the mentoring 400s finally say why** — Anand's accept is refused with "You set that time for another request that is waiting for the mentee's answer", a portal rule the test's slot picker did not know (it now skips the times he has already offered); **the redesigned cards' covers go through `cached_network_image`**, whose file-system plugins a widget test lacks, so the hub and the catalogue screens failed to draw in the hub and buyer tests until the career support's fakes were installed there too; **the hub has no Partner Courses section when only ICR's own institute has courses** (the local database), which the hub, journeys and buyer tests assumed was always drawn; a study test picked a deck at the Limited level, which opens to everyone; the company inbox's menu was tapped before its animation had settled; the desk's Settings tab no longer says "Mentees at a time". Still open after run 5: the assess journey's Take test (the brief draws it enabled, the paper answers with ten questions and open access, yet the exam does not open under the test — a diagnostic now prints the brief's state), and the staff pause test's five-minute hang, which every desk endpoint answering in under 40 ms while paused says is not the API's. Run 6 re-checks the seven files. |
| 6 | 131 passed · 12 failed (the seven files; 30 Oct) | The five-minute hang is explained: the pause test called the desk's visibility switch inside the widget test's zone, where the network never answers; moved to the async zone it answers at once, and the answer is that **the portal accepts a paused mentor's "list me"** (the pause is ICR's; the directory keeps him out regardless, and the app's own switch is disabled while paused). The accept refusals are an **overlap** rule, not an exact clash: the test offered 18:00 for 45 minutes against a seeded 18:30 session. The study test's fallback pick landed on a course-linked deck, whose refusal names the course. A lone run of the assess journey went all the way to its last check and found **an app bug**: after a retake the programme card still read "Best score 0% · Not passed yet · 1 attempt", because the retake ran as a flow of its own and the page behind refreshed after the first result only (fixed in `open_paper.dart`, unit-tested). |
| 7 | 131 passed · 12 failed (the same seven files, after those fixes) | The same count, a different twelve: six moved further (the assess journey past its first sitting to the retake's exam; the pause test to a later wording; the inbox test to a later step) and three company tests that passed in run 6 failed on what run 6 left behind (a bid left shortlisted when its test failed mid-way, a role label, a people search). Every remaining cause is a test expectation or test data; none is a member-visible flow the app does differently from the website. Left for the next session: the assess journey's second sitting under the full file (it passes alone), the hub test's cache-cleanup timer, the mentoring slot picker's overlap window, and a seed sweep for bid status. |

Nothing in the three runs was a flow the website has that the app does differently **by accident**. The app bugs the
pass turned up are listed next; everything else was either the test harness, test data, or a screen the app does not
have at all (the gaps).

## App bugs found and fixed in this pass

Run 3 added these (30 Oct 2026):

| Where | What a member saw | Fix |
|---|---|---|
| Mentor Profile (live) | "At capacity" under the mentee count for every mentor, because the portal no longer sends `openSlots` (no mentee limit since 27 Oct 2026) | "Taking new mentees" when the API sends no count (`api_mentor_profile_repository.dart`) |
| Mentor desk | "Places open: 0", an "all your places are taken" notice and a "Mentees at a time" stepper, all on a rule the portal dropped | The tile counts completed pairings; the notices and the stepper are gone (`desk_overview_tab.dart`, `desk_requests_tab.dart`, `desk_setup_tabs.dart`) |
| Become a mentor | A "Mentees at a time" slider and card line the website's form no longer has; the API ignored the value | Removed (`become_mentor_forms.dart`, `become_mentor_screen.dart`) |
| Learning | The redesigned hub dropped the My Learning strip, and with it the only way to the member's attempts list | A "My attempts" chip on ICR Courses, beside Certificates (`learning_screen.dart`) |
| Course sheet, Download brochure (owner's report, 30 Oct) | The link opened the PDF in the browser tab, which downloaded it at once; a Samsung phone offered "Open in Notes / Download", no way to read it | A lead form first (name, email, phone, company — the institute's lead, or ICR's contact desk for its own course), then **View brochure** in the app's own PDF viewer or **Download** on the phone (`brochure_sheet.dart`, `CourseSheetBody.openBrochure`). The website still hands the file out behind no form. |
| Assess programme page after a retake (found by the live journey, 30 Oct) | A level just passed on a retake still read "Best score 0% · Not passed yet · 1 attempt" until a pull to refresh: the retake ran as a flow of its own, so the page read its attempts after the first result and never again | `openPaper` completes only when the whole flow, retake included, is closed (`open_paper.dart`) |


| Where | What a member saw | Fix |
|---|---|---|
| Mentorship landing, "15+ Domains" pill | Opened Find Mentors on whichever chip was already lit, showing "4 of 4 mentors"; the fifteen domains were never listed | The pill opens **All domains**, every domain with its mentor count; a pick opens Find Mentors on it (`showDomainsSheet`, `MentorshipOverview.domains`) |
| Mentorship landing, "Learn from top topics" | A fixed three-column grid shrank "Communication & Stakeholder Management" to a third of its neighbours' size | Chips as wide as their words, wrapping (`TopicGrid`) |
| Mentor Profile, Career Journey | A long role description was cut with an ellipsis after four lines | Folds with "...read more", opens in place (`_RoleTile`) |
| Mock Test and Test Results | Type too large to see a whole question with its options | Prompt and options at 14 sp, headings 16–18, figures 18–22 (`ExamText`) |
| Messaging inbox | The personal inbox lost the key the company-side tests (and screen readers' order) knew it by | `inbox-personal` restored on the "My messages" item |
| RFQ composer | A date the picker offered was refused as "already passed" from the next morning (the validation read the real clock, the picker the test's) | Validation on `RfqClock.now()` |
| Assess programme page (30 Oct, on the emulator against the live API) | Capital Planning's 25 knowledge areas, one long chip to a row, filled the whole first screen; the level cards, the point of the page, sat below it, and on a mock exam the plan card and the bundle sat above the set cards | The topics fold by rows (eight, the design's eighteen at the app's type size) with **Show all N**; the level and set cards come first, the bundle and plan card after them (`KnowledgeAreas.fitting`, `GroupScreen._content`) |
| Home feed | The newest post sat under the pinned ones (the forum's `latest` order) | All Feed asks for `newest` and lays the page out by date, pinned or not |

## Data and seeds (fixed so they do not recur)

- **Bharat acts as himself.** `tool/seed/account.ts` now resets his acting company (`companyId`, `branchId`, `role`)
  every run; a live run that switches him and fails before switching back no longer poisons the next.
- **Srikanth is reseeded** by `mentorship.ts` (approved, listed); the test that pauses him through the SUPER_ADMIN
  timed out at five minutes in run 2 and left him paused — it is re-checked in run 3.
- **Profile views read 38, the design says 42.** `home.ts` seeds 42 views by recruiters and company admins; another
  seed's sweep takes four of those viewers away. The live test now compares the drawer with the API's own count.
- **The hub's study note** is absent when every flash-card deck belongs with a course (the owner's rule of 27 Oct:
  such a deck opens with its course and takes no place); the tests assumed unlinked decks.

## The owner's second batch (2 Nov 2026, tested on a phone against production)

Nine reports in one sitting, each checked against the website on main (pulled to 4205b710 first, as asked) before
the app was changed. What the website does is what the app now does; where the website has nothing, the note says.

| # | Report | Website | App now |
|---|---|---|---|
| 1 | The certificate's "Download PDF on the website" | builds the PDF in the browser (`certificatePdf.ts`) — there is no file to fetch | **Download PDF** builds the same document in the app (`certificate_pdf.dart`: A4 landscape, base-14 fonts, vector QR, the marks embedded) and saves it through the phone's "Save as" sheet (`file_picker`). The level word is the website's certificate's ("INTERMEDIATE LEVEL"), the name is Roboto bold italic (the website rasterises a script face the app does not bundle) |
| 2 | "Become an ICR Mentor" shown to a mentor | hidden unless `canOfferToMentor` (never applied, mentors nobody, not staff) | the band and the empty state's "Apply as Mentor" follow the same rule; `SessionUser` carries `mentorStatus` and `mentorsSomeone` |
| 3a | No notification for a like or a poll vote | none exists on the website either (the forum's notification kinds: replied, answer accepted, approved, removed, reported…) | nothing to mirror; a portal change if wanted (see Backend notes) |
| 3b | "Cannot vote on own post" | refused client-side: "You cannot react to your own post."; a poll's author sees results and cannot vote | the same, before anything is sent; results hidden until voted / author / closed, as the website |
| 4 | Saving a post gives no confirmation | toasts "Saved" / "Removed from saved discussions" | the same |
| 5 | Councils: Meeting link, Manage and Member all open the same page | no such controls: the sidebar's "Your councils" lists each council → its page; a seat is left where it is shown | the real cause was round 2's routing of `/councils/<slug>` to the app's councils directory. Now: a card opens the council's own page in the app (row 14, native since the same day); Meeting link / Room Link open the council's next session, or say there is none; Manage → and the seat pill open the Your councils sheet with Leave |
| 6 | Divya can Easy Apply to Moon Studio's job, which she posts | no Apply, "You post jobs for {company}…" (`postsForCompany`); the API refuses `ownCompanyJob` | the same sentence in the bar, no match card; read from every membership (`GET /me/companies`) |
| 7 | No way to schedule an interview; the pipeline went straight to Hired | the row menu offers "Schedule interview" at Applied / In review / Interview / Offer | the row's ⋮ menu offers it too (the application's page always had it, at three stages; now four) |
| 8 | A supplier (Ride Bob) cannot browse RFQs | Find Work & Bid in the Company workspace; the public `/rfq` board | a "Find work" chip on the Marketplace and on My RFQ's opens the supplier board; `/manage/bids` and its tabs open the board and My bids in the app |
| 9 | The Paytm receipt shows "Icr" and no logo | not the website's: PayU's merchant profile | not the app's either — see Backend notes |
| 10 | My courses is empty though levels are open and mock exams sat | `/learning/courses` has four shelves: Mock Exams and Assess Your Knowledge (opened with the plan, credits or bought), ICR Courses and Partner Courses (enrolments) | the same four shelves, the opened ones from `me/paper-unlocks` (`opened_learning.dart`), a card opening the programme or subject |
| 11 | Catalogue's View More opened every course | (the hub has no such page) | opens the six doors as tiles — the categories (`CatalogueScreen`) |
| 13 | Partner Courses showed the institutes' courses mixed; the website shows the institutes, each opening its course list | "Partner institutes": a card per institute (logo, course count, Explore courses) | the hub's section lists the institutes as cards (`InstituteCard`), a card opening the institute's page (`PartnerScreen`) |
| 14 | Council buttons "redirecting the same page" | the council's own page with six tabs | a native council page (`council_screen.dart`), every council control on the board opens it |
| 15 | "Can't we pay in the app?" — every Pay handed the website to the phone's browser | the website posts the rail's `{ action, fields }` to PayU itself | the same form is posted inside the app's own payment view (`lib/features/payments/`); wired for levels, sets, bundles, the exam brief and membership plans; the UPI app is opened by the phone and the API's return page ends the payment |
| 16 | "Who voted?" like the reactions list | the votes count opens a voters dialog (`GET /forum/threads/:id/poll/voters`: voters, the author, staff, or anyone once closed) | the same sheet in the app, the option each person picked under their name |
| — | Main pulled on 3 Nov 2026 (aea2e6d7, then 42d7ad4b) | the certificate was redesigned (border bars and legs, the name in Playfair Display, a new signature) and My courses gained a Flash Cards shelf | both ported the same day: `certificate_pdf.dart` / `certificate_view.dart` (Playfair Display bundled at 600), and `opened_learning.dart` reads the plan's deck places and the decks |
| 17 | "Hire, sell, advertise as working on the website should reflect in the app" | the Discover menu: an apps list with "Create a Company Page", then "Explore more for business" — Hire Facility Managers (`/talent`), Post a Job, Sell on Supplier Mart, Post RFQ / Requirement (`/quote`), Advertise — and an Enterprise spotlight (`/pricing`) | the Discover sheet carries the same list, words and captions, each to the app's own screen (talent search in the web view); it had the design's four business doors, two of which opened the create-company page |
| 12 | ICR Certifications showed many courses; the website's "ICR certified programs" shows one | only a course with no awarding body is ICR's; an institute's is filed under the institute | `isIcr` is `provider == null`; ICR Institute's courses are Partner Courses, as on the website |

## Backend notes (not the app's to fix)

- **No notification for a like or a poll vote** (owner, 2 Nov 2026): the forum sends none on the website either —
  `notifications.forum.*` has replied, replyToReply, answerAccepted, the moderation outcomes and reported, and
  nothing for a reaction or a vote. Adding one is a portal change (`forum-votes.service.ts` → `notifications.notify`,
  a `notifications.forum.reacted` key, folded per thread like chat), and the app's bell would then show it unchanged.
- **The Paytm receipt's payee "Icr" with no logo** (owner, 2 Nov 2026): what a UPI app prints for the payee is PayU's
  merchant record (the business display name behind `icr.payu@mairtel` and the logo on the PayU merchant profile),
  not anything ICR's code sends — the checkout form carries key, amount, product, the person and the hashes only.
  It is set in the PayU dashboard (business profile / branding) or by PayU support; the same name shows on PayU's
  hosted checkout page.
- **A mock set with credits but no money option** (owner, 3 Nov 2026, AEE CEM / AEE CBCP on production): those sets
  have no price of their own (`priceAmount` null, access FREE), so the API quotes no money (`payable` false) and the
  credits figure is the Credits page's *default level credits* (`levelCreditCost`). The website shows the same. A
  price set in Admin → Learning → Mock exams → the set's dialog makes it Paid and the app offers "Pay now"; a default
  rupee price for unpriced papers (as credits have) would be a portal change.
- **The ICR logo on PayU's checkout page** (owner, 3 Nov 2026, from the payment now running inside the app): the
  page is PayU's; its logo comes from the PayU dashboard — Settings → Brand Settings → Company Logo, a 90 × 90 PNG
  (docs.payu.in, "Configure Checkout Settings") — and the "Icr" beside it is the registered business display name,
  changed through PayU. The checkout form has no logo or name field; nothing in ICR's code can set either.

- `GET /chapters` answers no `nextEventAt`; the app computes a chapter's next date from `/events?when=upcoming`
  (and gets it right: Delhi NCR's is 7 Nov 2026). The councils live test read only the first page and expected May.
- `PATCH /users/me { "phone": null }` answers 500 (`""` clears it) — from `docs/ROLE_TEST_company.md`.
- A bid alert goes to the person who posted the requirement, not to the company's other admins.
- Every role refusal reads "Insufficient role permissions", whether the person has no company or the wrong role.
- Since 27 Oct 2026 the portal keeps no limit on how many mentees a mentor takes: the directory and the desk dashboard send no open-slot or capacity figures, and the old capacity column is kept but never read (the API accepts any value and changes nothing). The app followed on 30 Oct.

## The website's journeys, step by step (`docs/USER_JOURNEYS.md` in the portal)

`works` — proved live by the named suite · `web` — the website has it, the app has no screen (a gap by design or not
yet built) · `read` — the app shows it, the action itself is the website's (payments) · `—` not verified in this pass.

### BUYER — post a requirement, award a supplier

| Web step | In the app | Status |
|---|---|---|
| 1 Complete your buyer profile `/profile` | My profile (`account`) | works — `account_live`, `role_buyer_account` |
| 1b Complete your organization profile `/company` | — | **web**: the company workspace (identity, offices, documents) |
| 2 Post your first requirement `/rfq/new` | Post RFQ | works — `rfq_live`, `role_company_rfq`; a person with no company is told so and offered "Create a company" |
| 3 Publish it `/manage/requirements` | My RFQ's | works |
| 4 Compare incoming bids | the requirement page: bids sorted, best price marked, shortlist / decline / restore | works |
| 5 Award a supplier | select, close, a staged RFQ to a purchase order | works — `role_company_rfq` |
| 6 Explore membership `/membership` | Membership (plans, what you hold) | **read**; checkout is the website's (PayU) |

### VENDOR — build a listing, get verified, win work

| Web step | In the app | Status |
|---|---|---|
| 1 Finish business setup `/onboarding` | "Start selling" creates the listing from the company page | works for the listing itself; the wizard's offices, services and products are **web** (`ROLE_TEST_vendor` gaps 2–5) |
| 2 Strengthen your listing `/company?tab=listing` | the listing is read in the app, not edited | **web** (gap 15) |
| 3 Get verified `/company?tab=verification` | — | **web** (gap 8) |
| 4 Add a product or service `/manage/products` | — | **web** (gaps 3, 4) |
| 5 Place your first bid `/manage/bids` | Find work (Recommended, All open, Invited), the opportunity page, a bid with files, My Bids | works — `role_vendor_live` (15 flows × 7 accounts) |
| 6 Go SILVER `/membership` | Membership | **read**; checkout on the website |

### PROFESSIONAL — complete résumé, get hired, mentoring both ways

| Web step | In the app | Status |
|---|---|---|
| 1 Complete your résumé `/profile` | My profile: career, education, skills, languages, links | works — `account_live`, `role_buyer_account` |
| 2 Turn on discoverability | — | — (not exercised by a live test) |
| 3 Apply to your first job `/jobs` | Jobs board, the job sheet, Apply (with the phone asked when needed) | works — `jobs_live`, `role_buyer_jobs` |
| 4 Land an interview `/career/applications` | My applications, the application page (rounds, match, answers, timeline), Interviews | works — `career_member_live`, `career_screens_live` |
| 5 Check recruiter invitations `/career/invitations` | Invitations | works — `career_live` |
| 6 Set your mentoring goals `/mentorship/my?tab=goals` | My Mentoring › Goals | works — `mentoring_live` |
| 7 Find a mentor `/mentorship` | Mentorship, Find Mentors, a mentor's profile, the request | works — `mentorship_live`, `mentor_profile_live` |
| 8 Offer to mentor `/mentorship/become-a-mentor` | Become a mentor (every section, the application's states) | works — `become_mentor_live` |
| 9 Explore Career plans `/career/plans` | Membership › Professional | **read**; checkout on the website |

### RECRUITER — post a job, run the pipeline, hire

| Web step | In the app | Status |
|---|---|---|
| 1 Post your first job `/manage/jobs/new` | Post a job (the shared publish rules, blockers shown) | works — `jobs_employer_live`, `role_company_live` |
| 2 Review incoming applicants `/manage/jobs` | the pipeline, an application read whole, move, rate, note, message | works |
| 3 Schedule an interview | Interviews (schedule, reschedule, call off, the panel) | works |
| 4 Source candidates in Talent `/talent` | — | **web** (`ROLE_TEST_company`: job invites and talent search) |
| 5 Make your first offer | Offers | works — `jobs_employer_live` |

### COMPANY_ADMIN — set up the org, then everything

| Web step | In the app | Status |
|---|---|---|
| 1 Complete your company profile `/company` | Create a company page (name, industry, size, type, city) | the page itself works; everything after it is **web** |
| 2 Get verified | — | **web** |
| 3 List products & services `/manage/products` | — | **web** |
| 4 Invite your team `/manage/team` | Team (`TeamScreen`): invite by email, add someone on ICR, approve or decline join requests | works since 5 Nov 2026 (widget tests, `test/live/team_live_test.dart` reads it); the inbox-topic and learning-role editors are **web** |
| 5 Post a job or requirement | Post a job / Post RFQ | works — `role_company_live` |
| 6 Pick a membership plan | Membership | **read** |

### BRANCH_ADMIN and HIRING_MANAGER

| Web step | In the app | Status |
|---|---|---|
| Post a job for your office; review applicants; schedule interviews | the same hiring screens, scoped to the office (a posting outside it is refused) | works — `role_company_live` |
| Review your office team `/manage/team` | Team: the office's members, requests and pending adds (an office admin invites recruiters and hiring managers; edit and remove stay with company admins) | works since 5 Nov 2026 |
| Source candidates `/talent` | — | **web** |
| A hiring manager's assigned interviews | Interviews (the panel) | works |
| Submit interview feedback `/manage/interviews/<id>` | the interview's page (`InterviewBriefScreen`): the scorecard opens when the round starts | works — `interview_brief_live_test` reads the seeded rounds as panelist, recruiter and stranger, and proves the body through the API's refusals; an accepted submit is covered only by widget tests (the API cannot delete a scorecard) |

### GUEST and staff

- **Browsing before sign-in** is the website's: the app opens on sign-in (Google, LinkedIn, email) and is for
  members. A business `/get-started?role=` link lands on the website.
- **Staff** use the website's consoles (verification, moderation queues, subscriptions, translations). What the app
  gives a staff account is the member screens plus the forum moderation and mentor-application decisions its live
  tests cover (`role_staff_moderation`, `role_staff_mentor`); the "every tab opens" test for staff accounts is
  re-checked in run 3 after a finder change.

## Gaps, in one list (the website has it, the app has not)

From `docs/ROLE_TEST_vendor.md`, `docs/ROLE_TEST_company.md` and `docs/WEBSITE_HANDOFFS.md`: the company workspace
(identity, listing details, offices, documents, the company check and supplier levels, certifications), My Products,
My Services, My Locations, My Certifications, Team (join requests, invites, inbox topics), the supplier dashboard,
the Buyer Directory, Advertise, CRM / Payments / Marketing / CMS, reports and integrations, talent search and job
invites, article writing (`/manage/articles`), every payment
(PayU runs on the website; the app opens its page with the phone), and the staff consoles.

The first two to build, by how often a member meets them: company verification (the post-job gate sends people
there) and the team page.

## What the tests leave behind

As the role records say: threads a bid or a message opened outlive the test; uploads stay in `uploads/`; a sitting
the exam journey starts is reset by `learning-flows.ts`; Bharat's acting company by `account.ts`. Run the seeds
before a live run.

## Tablets (6 Nov 2026)

The owner asked for the app to be checked on a tablet too ("for Tab view also, create an emulator and show it"), and then for every screen to view correctly on both. A 10-inch AVD (`ICR_Tablet`, 2560×1600 @ 320 dpi = 1280×800 dp, landscape, hand-written under `~/.android/avd/` because the SDK has no `cmdline-tools`) showed every phone layout stretched edge to edge sideways: a feed line 1,250 dp long, a saved job's bookmark 1,000 dp from its title. The fix is one widget, `TabletFrame` (`lib/core/widgets/tablet_frame.dart`), set as `MaterialApp.builder` in `app.dart`: from Material's "expanded" width (840 dp) the whole app — navigator, dialogs and sheets included — sits in a centred 840 dp column, white at the sides with a hairline at each edge, the website's centred page frame; `MediaQuery` inside reports the column's width. A phone, or a tablet held upright (800 dp), is left alone, and the portrait tablet already reads well (two-column grids and rails). `test/tablet_frame_test.dart` pins both. Driving the tablet with `adb input tap` needs fresh coordinates after the drawer header's counts load (the rows move).

## Learning roles on the team page (6 Nov 2026)

The owner asked for the website's "who can be what" to hold in the app ("who can register for a company, who can be a mentor, who can be a Learning Partner — like these roles"). One gap was the team page: on the website a company admin at a company ICR approved as a learning partner (`UserDto.learningPartner`) invites or adds people with **learning roles** (Course Admin, Batch Admin, Enrolment Admin, Trainer, Finance — `LearningStaffRole`) on top of their main role, may invite a **Member** (PROFESSIONAL, "Member (learning roles only)" in the invite select) who joins only for those, and edits a member's learning roles; the API refuses a Member without one and keeps one on a member who joined for them. The app's `TeamViewer` now carries `learningPartner` (`SessionUser.learningPartner`), `givesLearningRoles` gates a `LearningRolesField` (ticks, the website's words) on the invite, add and edit sheets, Member joins the invite/add/edit role lists only there, a Member picks no office, and the repository sends `learningRoles` with an invite, an add and a member edit. The website's add dialog lists Member but sends no learning roles (the API then refuses); the app sends them, so its add works. `test/team_test.dart` › "learning roles" pins it.

## Who can be what — the website's gates in the app (6 Nov 2026, evening)

The owner: "check the web who can register for a company, who can be a mentor, who can be a Learning Partner — like these roles; check the web and do it in the app accordingly, and validations also." Three audits ran against `main`, each a table of web rule → app → fix; the notes sit with each screen's doc (`docs/screens/account.md`, `become_mentor.md`, `learning_hub.md`, `profile_menu.md`). In short:
- **Company page** (`CreateCompanyScreen`): any signed-in member but ICR staff (who see the website's card instead of the form), several companies per person, the website's `isWebsiteUrl` rule, the optional documents under the organisation type, a head office anywhere in the world (`/locations/search`), the logo and refusal sentences, "Request sent" on a look-alike already asked. `?role=` changes nothing on the web either. Every entry point now pushes `CreateCompanyScreen.routed(ctx)`, so the welcome steps open their pages (`companyNextStepPath`) and a look-alike's "View page" opens the company — nine pushes had passed nothing.
- **Become a mentor**: `canOfferToMentor` already matched; the page now refuses SUPER_ADMIN with the website's sentence, the conduct declaration is one tick beside Submit sent as `{conductVersion}` (the sheet's "I Agree" ticks it; its words are the website's `ConductDialog`), the session is refreshed after save/submit/withdraw so the drawer follows, and the renewal and certification sentences match. The search catalogue offers "Become a mentor" only to someone who may apply (`featureOfferedTo`), and someone acting for a company gets the row under Mentorship (the undecided member has the door).
- **Learning partner**: applies as a company from the partner directory — admins' companies only, Partner/With ICR blocked, "Apply to become a learning partner" with one optional notes box (`{companyId, proposalNotes?}`), the sent state, Apply offered in every state of the directory. A partner company's admin now gets the Partner Institute row (`SessionUser.learningPartner`), whose "Add a trainer" / "Add a programme specialist" open the team invite with that learning role ticked (`/manage/team?invite=TRAINER|COURSE_ADMIN`).
- **Role doors**: `startDoorsFor` matched `isUndecidedPerson`; captions are the website's WelcomeCard words; nothing offers an invite-only role to register for.

Also that evening: ICR's own notifications (no person or company behind them) carry the ICR mark, as LinkedIn's carry its logo; a post's or reply's Like is a filled glyph once reacted; the duplicated career rows the owner saw on `buyer@icr.dev` were data — 16 rows, eight copies of two roles, written in one whole-list `PUT /profile/experience` on 4 Nov 12:07 (the API replaces the list with whatever a client sends; neither the app's `saveRole` nor the website's `mergeItem` doubles it) — deduplicated locally with SQL; production would need the same if it shows there.
