# Career and hiring

Code: `lib/features/career/` (the member's search: company page, saved and hidden jobs, applications, interviews, alerts, invitations, the hub) and `lib/features/jobs/employer/` (the hiring team: post a job, jobs you posted, applicants). The Jobs board and its sheet are in `docs/screens/jobs.md`. Seeds: `tool/seed/learning-jobs.ts` (the jobs and the two personas' designed state), then `tool/seed/career.ts` (this flow's data; see "Seed"). Tests: `test/career_*`, `test/jobs_employer_*`, `test/jobs_post_test.dart`, `test/jobs_applicants_test.dart`, `test/live/career_*`, `test/live/jobs_employer_live_test.dart`. What the API lacks: `docs/backend-requests/jobs.md`.

This was built **flows first**: every control does the real thing against the API and is proved by a widget test and, where the API is involved, a live test. Pixel work (goldens, `strip_diff`) was deliberately not done for these screens; the board and the job sheet keep the looks they were finished with.

## How the lead wires it

Everything is opened through two route objects built from the Jobs tab's `JobsController` (the shell already holds it above its tabs), so a screen opened from anywhere reads the same source as the board:

```dart
careerRoutesOf(context).hub();                 // Your career
careerRoutesOf(context).applications(tab: ApplicationsTab.offers);
careerRoutesOf(context).application(app);      // one application's page
careerRoutesOf(context).interviews();
careerRoutesOf(context).savedJobs(tab: SavedTab.hidden);
careerRoutesOf(context).alerts(create: true, criteria: AlertCriteria(...));
careerRoutesOf(context).invitations();
hiringRoutesOf(context).jobs(status: PostingStatus.draft);
hiringRoutesOf(context).postJob();             // or .editJob(id)
hiringRoutesOf(context).applicants(jobId, title: ..., stage: 'INTERVIEW');
openCompanyInsightsById(context, companyId: id, jobs: jobsRepository);
```

**Entry points and constructors** (every one takes `links:` and `navigation:`; each has a website fallback until its callback is wired):

| Screen | Constructor |
|---|---|
| `SavedJobsScreen` | `(repository:, links:, navigation:, tab: SavedTab.saved, onBack:)` |
| `MyApplicationsScreen` | `(repository:, links:, navigation:, tab:, onBack:, clock:)` |
| `ApplicationDetailScreen` | `(repository:, application:, links:, navigation:, onChanged:, onBack:, clock:)` |
| `InterviewsScreen` | `(repository:, links:, navigation:, onBack:, clock:)` |
| `JobAlertsScreen` / `openJobAlerts(context, repository:, create:, criteria:, onChanged:)` | `(repository:, links:, navigation:, onBack:, onChanged:, startWithForm:, initialCriteria:)` |
| `InvitationsScreen` | `(repository:, links:, navigation:, onBack:)` |
| `CareerHubScreen` | `(repository:, links:, navigation:, onBack:, clock:, onChanged:, postedJobs:)` |
| `CompanyInsightsScreen` / `.forId` | `(repository:, company:, links:, navigation:, tab:, onBack:)` |
| `EmployerJobsScreen` | `(repository: HiringRepository, links:, navigation:, status:, onBack:, clock:)` |
| `PostJobScreen` | `(repository:, jobId:, initial:, links:, navigation:, onBack:, onSaved:, clock:)` |
| `ApplicantsScreen` | `(repository:, jobId:, jobTitle:, stage:, links:, navigation:, onBack:, clock:)` |
| `ApplicantDetailScreen` | `(repository:, applicant:, jobTitle:, links:, navigation:, onChanged:, onBack:, clock:)` |

The member's `repository` is `careerRepositoryFor(jobsRepository)` (the API's beside the API's jobs, the demo's beside the demo's); the hiring team's is `hiringRepositoryFor(jobsRepository)`.

**Hand-overs** (`JobsNavigation`, wired once in `lib/app.dart` and handed down by `JobsNavigationScope`; the Jobs tab's `JobsScreen(navigation:)` provides it). Callback -> what it opens -> the website page used until it is wired:

| Callback | Opens | Fallback |
|---|---|---|
| `onOpenCompany(id)` | the marketplace builder's company page | `/companies/:id` |
| `onOpenConversation(id)` (= "onMessage") | messaging's thread | `/messaging?c=:id` |
| `onOpenProfile(userId)` (= "onOpenMember") | a member's profile | `/members/:id` |
| `onBell()` | the app's notifications | `/notifications` |
| `onFindJobs(query?)` | the Jobs tab, search typed in | `/jobs?q=` |
| `onEditProfile()` | the member's own profile editor | `/profile` |
| `onCreateCompany()` | the account builder's "Create a company" | `/account/companies/new` |
| `onVerifyCompany()` | the company check (KYC) | `/company?tab=verification` |
| `onDemonstrateSkills()` | the Learning area's assessments | `/learning/assessment` |

The only other places these screens leave the app: **payment** (every locked-plan notice's "See plans" opens `/career/plans`), the job's own page on the website from the sheet's *More* menu and *Share*, an employer's own site ("Apply on company site"), and the "In my network" chip's `/network` (no app screen exists for it).

## Who sees what

A person's role decides whether the employer side exists for them. `JobsController.canHire` is true for `SUPER_ADMIN`, `COMPANY_ADMIN`, `BRANCH_ADMIN` and `RECRUITER` **with a company** (`HiringAccess.canManage`, from `GET /auth/me`; the same list as the API's `RECRUITER_TIER`). For everyone else:

- the board's **Post a job** chip stays (it is in the design) but explains that jobs are posted for a company and offers **Create a company** (`JobsNavigation.createCompany`);
- the My jobs sheet has no "Jobs you posted" row and the career hub has no shortcut to it (`CareerRoutes.postedJobs` is null);
- `EmployerJobsScreen`, opened anyway, says "Posting jobs is for hiring teams" instead of an error (the API would answer 403).

A company that is **not employer-verified** can draft and send for review but not publish: the composer shows the API's own sentence in a note with a **Verify** button (`onVerifyCompany`), and refuses Publish before asking.

## Audit of the first career code against the real API (26 Oct 2026)

What run 2 left (repository, models, insights controller and screen, three forms, application logic) was read against the portal's controllers and a real call to each endpoint. It compiled with no analyzer error and its parsers match the real payloads:

| Read | Endpoint | Finding |
|---|---|---|
| Applications | `GET /applications/mine`, `GET /applications/:id` | Shape matches `CareerApplication`. **The list carries only the rounds still on** (SCHEDULED / RESCHEDULED); the detail carries every round. The timeline (`events`) and the viewed receipt are empty with `visibilityLocked: true` on a plan without the *applicationVisibility* benefit; the match breakdown (`signals`) is `signalsLocked` without *aiInsights*. Bharat's Gold plan has both; the screens draw the locked state from the flags. |
| Invitations, alerts | `GET /job-invites/mine`, `GET /jobs/alerts` | Match. An alert's `newMatchCount` is per alert; the board's "N new" is their sum. |
| Company page | `GET /companies/:id/{rating-summary,reviews,reviews/mine,salaries,interview-reviews,people}` | Match. `reviews/mine` answers **200 with an empty body** when the member has none (the repository maps that to null). A salary role is withheld until 5 reports exist (`minSample`). |
| Interviews | `GET /interviews/mine` | **Not for candidates**: it is the interview panel's (RECRUITER_TIER and HIRING_MANAGER). A candidate reads their rounds from their applications. |
| Accept / decline an interview | none | The API has no candidate RSVP. The nearest true thing is a message to the hiring team (`POST /messaging/conversations/job`), which is what "Confirm" and "Ask for another time" do. Backend request 1 in `docs/backend-requests/jobs.md`. |

Fixed then: the live test wrote a salary report and an interview experience to Global Infra on every run (they cannot be deleted through the API); they now go to the empty *Insights Sandbox Co* and the seed sweeps the old rows. The tabs run **Jobs, People, Reviews, Salaries, Interviews** (the website's order). `ApiCareerRepository(pageSize:)` is injectable. The job sheet's company name, logo, "+ Follow" and faces open the company's careers page in the app.

## The company page (`CompanyInsightsScreen`)

Opened from the job sheet (company name, logo, + Follow, faces, "Reviews, salaries and interviews"), from any career row, or by id.

- Header: logo tile, name, "kind • size • city", the rating (average, stars, count) once there are approved reviews, and "See the company page" (`onOpenCompany`). Read from `GET /companies/:id` when the opener knew only the id.
- Tabs (each reads on first show, pages with "View More", pull to refresh reads the open tab again, a failure says why with "Try again", an empty tab says so): **Jobs** (the open jobs; a row opens the job sheet), **People** (members with a public profile; a row opens the member), **Reviews** (rating card, the member's own review's state, "Write a review" / "Update my review" — not offered to someone who works at the company, who reads "You work at …, so its reviews are written by others." instead (bug sheet #45, 9 Nov 2026; `viewerCompanyId`, else the session's active company), approved reviews), **Salaries** (each role with typical pay and the middle half as a bar, or "not enough reports yet"; "Share your salary"), **Interviews** (average difficulty and experience; "Share your interview").
- Forms (`insight_forms.dart`) validate exactly as the DTOs do (headline 140, texts 4000, job title 120, city 80, ratings 1-5, amount 0 or more), show the API's own refusal and keep what was typed.

Proved by: `test/career_insights_test.dart`, `test/live/career_live_test.dart`, `test/live/career_screens_live_test.dart`.

## Saved and hidden jobs (`SavedJobsScreen`)

Two tabs, **Saved** and **Hidden**, each read the first time they are shown. A row opens the job sheet; the bookmark takes a saved job off at once (`DELETE /jobs/:id/save`), with an **Undo** in the snackbar (`resave`) and a rollback with the API's sentence if refused. A job that has since closed still lists, says so, cannot be opened, and can be taken off or shown again. Hidden rows have **Show again** (`DELETE /jobs/:id/hide`) with Undo. Empty shelves say what goes in them and offer the board (`onFindJobs`); both shelves page with *View More*, refresh by pulling, and say why when they cannot load.

## My applications (`MyApplicationsScreen`) and one application's page

- **Figures** (Active, Viewed, Interviews, Offers) each open their tab; on a plan without viewed receipts the Viewed figure is a lock with the way to the plans, never a number.
- **Up next**: the rounds to come and the offers waiting, soonest first, each with **Join call** (the meeting) or the map, **Details**, **Review offer**.
- **Tabs** Active, Interviews, Offers, Archived, All with counts (opens on All when nothing is in play); **search** over job title, company and city; **sort** by recent activity, date applied or best match; empty states say what goes in each tab.
- **A row**: the status pill, the match, a progress strip (a dashed lock where the plan hides a step, with a notice and the way to the plans), the round to come (Join call / map), the offer strip with its terms and reply-by date (**Accept** asks first and takes a note; **Decline** asks first and archives it; a refusal is shown and the offer stays), and the menu: **View job**, **Message hiring team** (`POST /messaging/conversations/job`; a refusal says why and opens nothing), **Withdraw** (asks first; not offered on an archived application). A *Not selected* row offers similar jobs through the board. A job that closed under an early application says it is still with the employer.
- **The page** (`ApplicationDetailScreen`): the job and company, the status, the match with its breakdown (or the plan notice), the rounds (**Confirm** and **Ask for another time** message the hiring team with the round named; the proposal is required), the screening answers and what was sent, the offer with Accept / Decline, and the timeline in the member's words (or the locked notice). *Withdraw* and the offer answers tell the list so it follows.

## Interviews (`InterviewsScreen`)

**Upcoming** lists every round still to happen across the applications, soonest first: when, how long, how, which job and where. **Join call** opens the meeting, an in-person round opens the map, **Confirm** and **Ask for another time** message the hiring team (see the audit: the API has no RSVP), and a card opens its application. **Past** reads each application whole the first time it is opened and lists the finished rounds.

## Job alerts (`JobAlertsScreen`)

Each saved search with its filters in words, how often it speaks, and what is new. **The switch** turns alerts off at once (rolled back with the API's sentence if refused); the **frequency** chips (daily or weekly) change how often. **See the new ones** runs the search (`GET /jobs/alerts/:id/run`, which counts them as seen), tells the board so its "N new" goes, and lists the matches (bookmark, open the sheet, *View More*, *Hide matches*; another alert opens the first closed). **+** opens the form: a name of 1 to 80 characters is required, the filters are the board's (a form started from the board's filters suggests a name); the API's refusal (the plan's limit) is shown and nothing typed is lost. **Edit** opens the saved filters and keeps the ones the form does not edit; **Delete** asks first and is put back if refused. The board's *Alerts* chip with no saved search opens the form in the app; the filters sheet's **Save as alert** starts it from the filters in force.

## Invitations (`InvitationsScreen`)

Each invitation: the role, the company, who sent it and what they wrote. **View & apply** tells the recruiter it was seen (`PATCH /job-invites/:id` with `VIEWED`, once; an invitation already seen says *Viewed*) and opens the job; **Decline** asks first and removes it (`DECLINED`; rolled back if refused). The **Open to opportunities** switch (recruiters can find the member) tells the API and is put back if refused; with no résumé it waits and the page says how to get one, with *Profile* opening `onEditProfile`.

## Your career hub (`CareerHubScreen`)

The snapshot (Active with how many employers viewed, Interviews with the next one, Saved, Invitations), the month's application quota with the way to the plans, **Next steps** (what is waiting on the member, *Open tracker*), **How visible you are** (the last 30 days' search appearances and the résumé's strength with *Improve*), where each application stands, and a shortcut to every screen above (and **Jobs you posted** for a hiring team). A shortcut opens its screen in the app and the hub reads its figures again when it comes back.

## Jobs you posted (`EmployerJobsScreen`)

The company's postings from `GET /jobs/company` (statuses and their counts), with `GET /jobs/company/overview` above them.

- **Figures**: Open (and how many close soon, a tap opens the Open tab), Not viewed, Interviewing (across how many jobs), Hired. **Attention** lines ("No applicants yet after 17 days. Promote it or refresh the posting.") each open that job's applicants.
- **Tabs** All, Open, Drafts, In review, Paused, Closed with counts; **search** (submit), **sort** (newest, closing soonest, most applicants, title A to Z), *View More* paging, pull to refresh, a failure says why with *Try again*; a company that never posted is asked to post its first.
- **A row**: status, the deadline in words ("Closes in 2 days", "Closes today", "Deadline passed 25 Oct"; only while open), *Promoted*, the pipeline as a bar with "9 applicants • 2 not viewed" (those who withdrew are not counted), and **Applicants**. A draft shows **Continue editing**; a draft that ICR's review sent back shows the reviewer's note.
- **The menu**: **Edit job**, **Promote** (a live posting that is not promoted; buying a boost is a payment, so it opens the website's list, where each live posting has Promote), **Pause** / **Resume**, **Close** (asks first) / **Reopen**, **Duplicate as draft** (copies the questions and opens the copy in the composer), **Delete** (asks first). Each is applied and the counts follow; the API's refusal (the plan's live-post room, a job that no longer passes the checklist) is shown as worded and the posting stays as it was.
- The **+** in the title bar opens the composer; a posting saved there is on the list when it closes.

## Post a job and Edit job (`PostJobScreen`)

One scrolling form (all cards built, so the checklist can always jump to the one it names):

- **The role**: title (suggestions from `GET /job-titles`, **suggested, never enforced**: a free title is as good; a listed title also tags the posting with its function, `jobFunctions`, and any other title clears it, as the website's composer does), department, seniority (tap again to clear), job type, work mode.
- **Where**: country (the list), state, cities (added and removed one by one, each once, at most 10, 60 characters), and, with two or more cities, the seats in each (the total follows).
- **The description**: plain text with `- ` for bullets and `## ` for headings, stored as rich HTML; a live count against the 120 characters needed.
- **Skills and experience**: required skills (typing offers matches from `GET /jobs/skill-suggestions`; at most 30, 60 characters, none twice), nice-to-have skills, experience in whole years.
- **Pay** (optional): minimum, maximum, currency, period, *show the salary*, *negotiable*.
- **Applying**: openings, *On ICR* or *On your own site* (a full https link), an apply-by date, *ask for a résumé*, *show me as the contact*.
- **Questions for applicants**: up to ten, of the eight kinds (yes/no, years, number, pick one, pick several, rating 5 or 10, date, text), each with the answer that passes and *must have*; added in a dialog that checks them as the API does, reordered, removed; saved with the posting (`PUT /jobs/:id/screening-questions`, only when changed).
- **The checklist** is `jobPublishBlockers` from `packages/shared/src/job-rules.ts` ported to `job_rules.dart`: the same list, order and sentences the API refuses with on a move to OPEN, so what the phone shows is what the API would say (proved rule by rule against the API). A row jumps to its card. **Salary is never a blocker.** Two rules the API applies on **every save**, not only on publish, also stop a save on the phone with the same words: a maximum salary below the minimum and a maximum experience below the minimum.
- **Buttons**: *Save draft* (a title is enough; saving again changes that posting, it never makes another), *Publish* (saved first, so nothing typed is lost, then moved to OPEN; the API's refusal, such as the plan's limit, is shown and the posting stays a saved draft), *Send to ICR for review instead*. Editing a live posting reads *Save changes* / *Update posting*; a paused or closed one *Publish again*. Leaving with unsaved changes asks: keep editing, discard, or save as a draft.

## Applicants (`ApplicantsScreen`) and one application (`ApplicantDetailScreen`)

**The pipeline** (`GET /jobs/:id/applications`): the job and "9 applicants • 2 not viewed"; stage tabs with counts (All, Applied, In review, Interview, Offer, Hired, Not selected); **sort** (most recent, best match, most qualified); **rating filter** (3, 4, 5 stars and up); **Qualified** (met every must-have question and not archived automatically for missing one). A row: photo or initials, name, headline, company and years, the stage, the match, "2 of 3 met", the unviewed dot (a new application nobody on the team has opened), the stars (tap to rate; a refusal takes them back), the next interview or the offer's state, and a menu with **only the moves the API allows from that stage** (`ALLOWED_APPLICATION_TRANSITIONS`): review, interview, offer, hired, reject. A move shows at once and is put back with the API's sentence if refused; **Reject** asks for a reason first and sends it with the move.

**The application** (`GET /applications/:id` and `/events`; opening it is the team's "viewed" receipt): who applied (headline, company, place, years, skills, when and how, expected pay, notice), email / résumé / LinkedIn / profile links, the cover note, an AI summary when there is one, the **screening answers marked against your bar** (met, below your bar, misses a must-have, not graded), the **interviews** (when, mode, panel, notes, scorecards; **Reschedule**, **Cancel** (asks first), and for a round whose time has passed **Mark done** / **No-show**), the **offer** (amount, joining and reply-by dates, the candidate's note), your **notes and rating**, and the **activity** trail. **Next step** buttons: the move forward (filled) and the others, **Schedule interview**, **Make an offer**, **Message** (the thread with the applicant, in the app), **Reject**.

- *Schedule / Reschedule* (`InterviewSheet`; also "Schedule interview" in a pipeline row's ⋮ menu, as the website's row menu, at every stage the website allows — Applied, In review, Interview and Offer, `schedulableStages`): round name, date, time, 30 / 45 / 60 / 90 minutes, video (link) / in person (address, map link) / phone, notes for the panel, and the panel from `GET /team/members` (the booker is ticked); the sheet checks what the API checks (a future time, a panel, an address for an in-person round, https links) and keeps the API's refusal under the button with everything typed.
- *Make an offer* (`OfferSheet`): salary, per year / month / hour, job title, joining date, reply-by date, note; **Save draft** or **Send offer** (sending moves the application to Offer). A draft offer has **Send** and **Edit** on its card; a sent offer can be changed but not sent twice. One live offer at a time.
- *Hired* is final: the API allows no move out of it.

## Proved by

`W` = a widget test (the control tapped, `RecordingLinks` / `RecordingNavigation` show where it would have gone), `U` = pure logic, `L` = the real API through the app's own repositories, controllers and screens.

| Control | Proved by |
|---|---|
| Saved and Hidden shelves: bookmark off + Undo, refusal, Show again, closed job, paging, empty, error | W `test/career_saved_test.dart` |
| Applications: figures, Up next, tabs, search, sort, row, Join call, offer Accept / Decline, Withdraw, menu, locks, the page, the hub | W `test/career_applications_test.dart`; L `test/live/career_member_live_test.dart`, `career_screens_live_test.dart` |
| Interviews: upcoming, past, Join call, Confirm, Ask for another time | W `test/career_interviews_invites_test.dart`; L `career_member_live_test.dart` |
| Alerts: list, switch, frequency, matches, create, edit, delete, criteria mapping | W + U `test/career_alerts_test.dart`; L `career_member_live_test.dart` |
| Invitations: view & apply, decline, Open to opportunities, Profile | W `test/career_interviews_invites_test.dart`; L `career_member_live_test.dart` |
| Company page, forms | W `test/career_insights_test.dart`; L `career_live_test.dart`, `career_screens_live_test.dart` |
| Board: Post a job (composer for a hiring team, "Create a company" for anyone else, unreachable account), Demonstrate skills, My jobs "Jobs you posted", the hub's shortcut | W `test/jobs_screen_test.dart` ("the chips"); L `jobs_employer_live_test.dart` ("who may post") |
| The rules: JOB_LIMITS, `jobPublishBlockers` (every blocker), description <-> HTML, `JobDraft` (save rules, wire body), screening rules, interview and offer rules, the stage moves, the models | U `test/jobs_employer_rules_test.dart`; L `jobs_employer_live_test.dart` ("what the checklist names, the API refuses in the same words", "what a save may not hold") |
| Post a job / Edit job: every field, suggestions, cities and seats, skills, pay, apply, deadline, checklist, save, publish, the gate, review, leaving, questions | W `test/jobs_post_test.dart`; L the composer and publishing groups |
| Jobs you posted: figures, attention, tabs, search, sort, mine, paging, row states, the menu (pause, resume, close, reopen, duplicate, delete), refusals, non-hirers | W `test/jobs_employer_list_test.dart`; L the lifecycle, copy and list tests |
| Applicants and the application: stages, sort, filters, moves, reject with a reason, rating, links, answers, notes, interviews (book, move, cancel, done, no-show), offers (draft, edit, send, hired), message | W `test/jobs_applicants_test.dart`; L the pipeline group and "the screens over the API" |

## What the API does not give

- A candidate's answer to an interview (backend request 1): "Confirm" and "Ask for another time" message the hiring team.
- Withdrawing an offer (request 2): a recruiter can change it, not take it back, so the live offer test ends with the sandbox applicant *hired*.
- Taking a rating off (request 3), and the applicant's place and notice period on the pipeline row (request 4); the live-posting room before the plan says no (request 5).
- Job boosts and promotion are payment: they stay on the website.

## Seed (`tool/seed/career.ts`)

Run after `learning-jobs.ts`. Idempotent; `--remove` takes it all out and puts back what it changed (Bharat's second application). Every re-run also **resets what the live tests spend** (the sandbox applications, the offers, the invitations, the viewed receipts) and re-bases the dates, and sweeps the postings, reviews and reports earlier live runs left.

| Who | What |
|---|---|
| Employer | `meera.iyer@career.icr.test` (COMPANY_ADMIN) and `rohit.rao@career.icr.test` (RECRUITER), both `Career@12345`, at **Northwind Facilities** (employer-verified). 15 jobs in every status; a pipeline of 9 applicants on "Facilities Operations Lead" (every stage, ratings, a note, screening answers, an interview with feedback, an offer); the **hiring sandbox** job ("Facilities Coordinator (hiring sandbox)") with ten APPLIED applicants the employer live tests move, rate, message, book and offer. |
| Unverified employer | `tara.joshi@career.icr.test` (COMPANY_ADMIN, `Career@12345`) at **Harbor Soft Services**, whose employer verification has not been filed: she can draft and send for review, and the API refuses her publish with "Verify your company before publishing jobs...". |
| Pooja | Applications in every state (an interview with a round to come and an in-person one, an offer to answer, not selected, withdrawn, applied), a sandbox application and a sandbox offer, two saved searches, two invitations, bookmarks, one hidden job. A free plan, so her tracker reads the "timeline is locked" notice. She is the non-hirer in the role tests. |
| Bharat | The designed board is untouched ("My jobs 3", the Bengaluru alert, "2 new"): his second application moves to INTERVIEW (a round done, one to come), one application is withdrawn, two older saved searches, an invitation, bookmarks, one hidden job. |
| Insights | Approved reviews, salaries (two roles with 5+ reports) and interview experiences on Global Infra and on Northwind; an empty *Insights Sandbox Co* the live tests write to. |

**What the employer live tests cannot undo through the API, and what they do about it**: a posting is deleted at the end of its test; an application only moves forward (except *not selected*, which can come back to review), so the move test ends back in review; an interview round can be cancelled, not deleted; an offer cannot be withdrawn, so the offer test ends with the applicant hired and takes one of six spare applicants, **skipping with a message when all six are spent**: run `career.ts` again to reset them. Notes are marked "MOBILE-LIVE".

## Slices

1. Audit, company page, reviews: **done and proved**.
2. Saved and hidden jobs, My applications and the application page, Interviews: **done and proved**.
3. Job alerts, Invitations, the career hub, the apply flow's completeness (screening, diversity, gender, LinkedIn, phone) and the board's links into all of it: **done and proved**.
4. Post a job, Jobs you posted, role gating: **done and proved**.
5. Applicants, the application for the hiring team, interviews and offers: **done and proved**.

**Left (for the lead):** wire `JobsNavigation` in `lib/app.dart` (the table above); decide whether the demo should show the employer side (`hiringRepositoryFor(DemoJobsRepository)` returns a non-hirer so the board reads as designed; a showcase builds `DemoHiringRepository()` itself, which is a recruiter); the backend requests; pixel matching of the new screens, postponed as asked.

**6 Nov 2026 (owner's phone batch).** My applications' summary is no longer a boxed 2×2: four figures on one line (Active, Viewed — the lock when the plan hides it, still opening the plans — Interviews, Offers; keys `summary-*` unchanged), their notes on one line under them ("1 sent this week · Opened by a recruiter · None scheduled · 1 awaiting your reply"), and a hairline — the Career Hub's `_Snapshot` look ("these designs should not have the background colour and efficiently use the space"). `ApplicationProgress` top-aligns its step columns (`CrossAxisAlignment.start`): a step with no date under it (Offer, still to come) is shorter, and the default centring dropped its dot and line below the others' ("there is no line alignment"). The pull-to-refresh test pulls 600 px because `RefreshIndicator` arms at a quarter of its 1600 px test viewport.


## 13 Nov 2026: no "Only jobs I started"

The owner circled the chip under the search on Manage Jobs: "Remove this." The chip and the controller's `mine` filter are gone; the list is always the company's. The repository's `jobs(mine: true)` query stays, read by the live tests and available to a later screen.

## 13 Nov 2026: copy refined to the client's standard

The member's career screens (`lib/features/career/`) and the hiring team's (`lib/features/jobs/employer/`). Wording only: no layout, colour or behaviour changed. The rules are the client's marked-up manual of 13 Nov ("refine text and make it crisp for global standard"): Title Case for what is tapped or read as a label, sentence case with a full stop for sentences, plain international English, no dash inside a sentence, one term for one thing.

| Where | Was | Now |
|---|---|---|
| `applicant_detail_screen.dart` | Not selecting …? | Reject …? |
| `applicant_detail_screen.dart` | They are told their application was not selected. You can move them back later. | They will be notified that their application was not selected. You can move them back later. |
| `applicant_detail_screen.dart` | Why (only your team sees this) | Reason (visible only to your team) |
| `applicant_detail_screen.dart` | Write a note or give a rating. | Add a note or a rating. |
| `applicant_detail_screen.dart` | and the panel are told it is off. | and the panel will be notified. |
| `applicant_detail_screen.dart` | Keep it | Keep Interview |
| `applicant_detail_screen.dart` | Couldn't open this application | Unable to Open This Application |
| `applicant_detail_screen.dart` | Misses a must-have | Does not meet a must-have |
| `applicant_detail_screen.dart` | Below your bar | Does not meet your preferred answer |
| `applicant_detail_screen.dart` | No interview booked yet. | No interview scheduled yet. |
| `applicant_detail_screen.dart` | Open the meeting link | Open Meeting Link |
| `applicant_detail_screen.dart` | Mark done | Mark as Done |
| `applicant_detail_screen.dart` | Only your hiring team sees these. | Visible only to your hiring team. |
| `applicant_detail_screen.dart` | Nothing yet. | No activity yet. |
| `applicant_detail_screen.dart` | Interview booked… | Interview scheduled… |
| `applicants_screen.dart` | Interview booked with …. | Interview scheduled with …. |
| `applicants_screen.dart` | Couldn't load the applicants | Unable to Load Applicants |
| `applicants_screen.dart` | No one matches / No applicants yet | No Matching Applicants / No Applicants Yet |
| `applicants_screen.dart` | Try another stage, or clear the filters. | Try another stage or clear the filters. |
| `applicants_screen.dart` | People who apply show up here, best match first if you sort that way. | People who apply will appear here. |
| `applicants_screen.dart` | Show everyone | Show All Applicants |
| `employer_jobs_screen.dart` | It stops taking applications and leaves the job board. You can reopen it later. | The job will stop accepting applications and be removed from the job board. You can reopen it later. |
| `employer_jobs_screen.dart` | It leaves your list and the job board. Applications already sent are kept for your records. | The job will be removed from your list and the job board. Applications already received are kept for your records. |
| `employer_jobs_screen.dart` | A draft copy of “…” was made. | A draft copy of “…” was created. |
| `employer_jobs_screen.dart` | Posting jobs is for hiring teams | Job Posting Is for Hiring Teams |
| `employer_jobs_screen.dart` | Your account does not post jobs for a company. Ask your company's admin to make you a recruiter, or set up a company. | Your account cannot post jobs for a company. Ask your company admin to make you a recruiter, or create a company. |
| `employer_jobs_screen.dart` | Set up a company | Create a Company |
| `employer_jobs_screen.dart` | Couldn't load your jobs | Unable to Load Your Jobs |
| `employer_jobs_screen.dart` | Describe the role, add a few questions, and it goes live once your company is verified. | Describe the role and add screening questions. The job goes live once your company is verified. |
| `employer_jobs_screen.dart` | No jobs match / No jobs here | No Matching Jobs / No Jobs |
| `employer_jobs_screen.dart` | Try other words, or clear the filters. | Try different keywords or clear the filters. |
| `employer_jobs_screen.dart` | Postings in this status show up here. | Jobs with this status will appear here. |
| `employer_jobs_screen.dart` | Not viewed / Applicants nobody opened | Not Viewed / Applicants not yet viewed |
| `employer_jobs_screen.dart` | No rounds on | No active rounds |
| `employer_jobs_screen.dart` | ICR sent this back: … | Returned by ICR: … |
| `hiring_routes.dart` | Couldn't check your account. Try again in a moment. | Unable to check your account. Try again in a moment. |
| `hiring_routes.dart` | Your role at this company does not post jobs. Ask its admin to make you a recruiter, and you can post | Your role at this company cannot post jobs. Ask its admin to make you a recruiter to post |
| `hiring_routes.dart` | jobs, run applicants and make offers here. | jobs, manage applicants and make offers. |
| `hiring_routes.dart` | You're using your personal account | You Are Using Your Personal Account |
| `hiring_routes.dart` | Set up your company on ICR and you can post jobs, run applicants and make offers. | Create your company on ICR to post jobs, manage applicants and make offers. |
| `hiring_routes.dart` | If your company is already here, ask its admin to make you a recruiter. | If your company is already on ICR, ask its admin to make you a recruiter. |
| `hiring_sheets.dart` | Save the new time | Save New Time |
| `hiring_sheets.dart` | They are told by email and in the app, with the link or the address. | They will be notified by email and in the app, with the link or the address. |
| `hiring_sheets.dart` | When | Date and Time |
| `hiring_sheets.dart` | Pick a date | Select a Date |
| `hiring_sheets.dart` | Pick a time | Select a Time |
| `hiring_sheets.dart` | How long | Duration |
| `hiring_sheets.dart` | How | Interview Mode |
| `hiring_sheets.dart` | A change is sent to them. | Any change will be sent to them. |
| `hiring_sheets.dart` | Paid | Pay Period |
| `hiring_sheets.dart` | Clear the joining date | Clear Joining Date |
| `hiring_sheets.dart` | Clear the reply-by date | Clear Reply-By Date |
| `hiring_sheets.dart` | A note for your team (optional) | Note for your team (Optional) |
| `hiring_models.dart` | Needs a look. | Needs attention. |
| `hiring_models.dart` | A number | Number |
| `hiring_models.dart` | Pick one | Single Choice |
| `hiring_models.dart` | Pick several | Multiple Choice |
| `hiring_models.dart` | A rating | Rating |
| `hiring_models.dart` | A date | Date |
| `hiring_models.dart` | Give "…" at least two options. | Add at least two options to "…". |
| `hiring_models.dart` | Give the posting a title to save it. | Enter a job title to save the posting. |
| `hiring_models.dart` | Pick a date and time. | Select a date and time. |
| `hiring_models.dart` | Pick a time in the future. | Select a time in the future. |
| `hiring_models.dart` | An interview is at least 5 minutes. | An interview must be at least 5 minutes. |
| `hiring_models.dart` | Give the address for an in-person interview. | Enter the address for an in-person interview. |
| `hiring_models.dart` | Choose at least one person for the panel. | Select at least one panel member. |
| `interview_brief_controller.dart` | Could not load this interview. | Unable to load this interview. |
| `interview_brief_controller.dart` | Could not submit feedback. | Unable to submit feedback. |
| `interview_brief_models.dart` | No show | No-Show |
| `interview_brief_screen.dart` | Couldn't open this interview | Unable to Open This Interview |
| `interview_brief_screen.dart` | The rest of the panel | Rest of the Panel |
| `interview_brief_screen.dart` | This interview was cancelled — no scorecard needed. | This interview was cancelled. No scorecard is needed. |
| `post_job_controller.dart` | Verify your company before publishing jobs. Your drafts are saved — finish verification and publish them in one click. | Verify your company before publishing jobs. Your drafts are saved and can be published once verification is complete. |
| `post_job_controller.dart` | Finish … things before publishing. | Complete … items before publishing. |
| `post_job_controller.dart` | Finish … things before sending it to review. | Complete … items before sending for review. |
| `post_job_screen.dart` | What you changed on this posting is not saved yet. | Your changes to this posting have not been saved. |
| `post_job_screen.dart` | Couldn't open this posting | Unable to Open This Posting |
| `post_job_screen.dart` | The role | Role |
| `post_job_screen.dart` | Where | Location |
| `post_job_screen.dart` | Pick a country | Select a country |
| `post_job_screen.dart` | openings in all | openings in total |
| `post_job_screen.dart` | The description | Description |
| `post_job_screen.dart` | Nice-to-have skills (optional) | Preferred Skills (Optional) |
| `post_job_screen.dart` | Show the salary on the posting | Show Salary on the Posting |
| `post_job_screen.dart` | Link where candidates apply | Application Link |
| `post_job_screen.dart` | This posting is live: changes show at once. | This posting is live. Changes appear immediately. |
| `post_job_screen.dart` | Send to ICR for review instead | Send to ICR for Review |
| `job_rules.dart` | Pick the country this role is based in. | Select the country this role is based in. |
| `resume_viewer.dart` | Couldn't open the résumé. Try again. | Unable to open the résumé. Try again. |
| `resume_viewer.dart` | This résumé's file type can't be shown in the app. | This résumé's file type cannot be displayed in the app. |
| `screening_editor.dart` | Must have | Must-Have |
| `application_detail_screen.dart` | Offer accepted. Congratulations! | Offer accepted. |
| `application_detail_screen.dart` | Where it stands | Application Status |
| `application_detail_screen.dart` | What you told the employer when you applied. | The answers you gave the employer when you applied. |
| `application_detail_screen.dart` | Check back soon. | Check again later. |
| `application_detail_screen.dart` | The breakdown behind your match is part of Career Plus. | The match breakdown is part of Career Plus. |
| `application_detail_screen.dart` | See plans | View Plans |
| `application_detail_screen.dart` | Confirm I will attend | Confirm Attendance |
| `application_detail_screen.dart` | Nothing has happened to this application yet. | No activity on this application yet. |
| `application_dialogs.dart` | The employer is told straight away and the application moves to Hired. This cannot be undone here. | The employer is notified immediately and the application moves to Hired. This cannot be undone in the app. |
| `application_dialogs.dart` | The employer is told, and the application moves to Archived. This cannot be undone here. | The employer is notified and the application moves to Archived. This cannot be undone in the app. |
| `application_dialogs.dart` | A note for the employer (optional) | Note for the employer (Optional) |
| `application_dialogs.dart` | Why you are declining (optional) | Reason for declining (Optional) |
| `application_dialogs.dart` | Say when you could do instead. | Enter the times you are available. |
| `application_widgets.dart` | . The employer moved ahead with other candidates. | . The employer selected other candidates. |
| `career_hub_screen.dart` | Couldn't load your career hub | Unable to Load Your Career Hub |
| `career_hub_screen.dart` | Go unlimited | View Plans |
| `career_hub_screen.dart` | A fuller résumé gets more from recruiters. | A complete résumé attracts more recruiters. |
| `career_hub_screen.dart` | You're all caught up | No Pending Actions |
| `career_hub_screen.dart` | Nothing is waiting on you right now. | Nothing needs your attention right now. |
| `career_hub_screen.dart` | How visible you are | Your Visibility |
| `career_hub_screen.dart` | Nothing to show yet. | No data yet. |
| `career_hub_screen.dart` | Jobs you apply to show up here, with where each one stands. | Jobs you apply to will appear here with their status. |
| `company_insights_screen.dart` | Couldn't load this | Unable to Load This Section |
| `company_insights_screen.dart` | Be the first to say what it is like to work at …. | Share what it is like to work at …. |
| `company_insights_screen.dart` | Your review is waiting for ICR to read it. It shows once it is approved. | Your review is awaiting ICR approval. It will appear once approved. |
| `company_insights_screen.dart` | Pay shows once enough people report it. | Pay data will appear once enough people report it. |
| `company_insights_screen.dart` | A role shows once … people have reported it, so no one can be picked out. | A role appears once … people have reported it, so no individual can be identified. |
| `company_insights_screen.dart` | Sat an interview at …? Tell the next person how it went. | Interviewed at …? Share your experience to help other candidates. |
| `company_insights_screen.dart` | No one to show yet | No People to Show Yet |
| `insight_forms.dart` | Thanks. Your review is anonymous and appears once ICR has read it. | Thank you. Your review is anonymous and will appear once ICR has reviewed it. |
| `insight_forms.dart` | Thanks. Salaries are anonymous and only ever shown as an average. | Thank you. Salaries are anonymous and shown only as an average. |
| `insight_forms.dart` | Thanks. Your interview experience appears once ICR has read it. | Thank you. Your interview experience will appear once ICR has reviewed it. |
| `insight_forms.dart` | Reviews are published anonymously and are read by ICR before they show. | Reviews are published anonymously after ICR has reviewed them. |
| `insight_forms.dart` | Anonymous. It only ever shows as an average, once at least five people report the same role. | Anonymous. It is shown only as an average, once at least five people report the same role. |
| `insight_forms.dart` | Anonymous. It helps the next person who sits there. | Anonymous. It helps other candidates prepare. |
| `interviews_screen.dart` | Couldn't load your interviews | Unable to Load Your Interviews |
| `interviews_screen.dart` | Couldn't load your past interviews | Unable to Load Your Past Interviews |
| `interviews_screen.dart` | No interviews coming up | No Upcoming Interviews |
| `interviews_screen.dart` | When an employer schedules an interview, it appears here with the time and how to join. | When an employer schedules an interview, it will appear here with the time and joining details. |
| `interviews_screen.dart` | Rounds you have been to appear here. | Interviews you have attended will appear here. |
| `invitations_screen.dart` | will be told you are not interested in …. | will be notified that you are not interested in …. |
| `invitations_screen.dart` | Couldn't load your invitations | Unable to Load Your Invitations |
| `job_alerts_screen.dart` | Alert saved. We will tell you when new jobs match. | Alert saved. We will notify you when new jobs match. |
| `job_alerts_screen.dart` | You will stop hearing about new jobs for this search. You can make it again any time. | You will no longer be notified about new jobs for this search. You can create it again at any time. |
| `job_alerts_screen.dart` | Couldn't load your alerts | Unable to Load Your Alerts |
| `job_alerts_screen.dart` | Save a search and we will tell you when new jobs match it. | Save a search and we will notify you when new jobs match. |
| `job_alerts_screen.dart` | Your saved searches. We'll tell you when new jobs match. | Your saved searches. We will notify you when new jobs match. |
| `job_alerts_screen.dart` | Telling you weekly | Notifying you weekly |
| `job_alerts_screen.dart` | Telling you daily | Notifying you daily |
| `job_alerts_screen.dart` | See … new | View … New |
| `job_alerts_screen.dart` | See matches | View Matches |
| `job_alerts_screen.dart` | Save a search and we tell you when new jobs match it. | Save a search and we will notify you when new jobs match. |
| `job_alerts_screen.dart` | Minimum salary (a year, in rupees) | Minimum Salary (Yearly, in Rupees) |
| `job_alerts_screen.dart` | Tell me when new jobs match | Notify Me When New Jobs Match |
| `my_applications_screen.dart` | Offer accepted. Congratulations! It is now under Offers. | Offer accepted. It is now under Offers. |
| `my_applications_screen.dart` | Couldn't load your applications | Unable to Load Your Applications |
| `my_applications_screen.dart` | Start tracking your job search | Track Your Job Search |
| `my_applications_screen.dart` | Every job you apply to appears here with its status, interviews and offers. | Every job you apply to will appear here with its status, interviews and offers. |
| `my_applications_screen.dart` | Set up a job alert | Create a Job Alert |
| `my_applications_screen.dart` | Nothing in progress | No Applications in Progress |
| `my_applications_screen.dart` | Applications you send appear here until they close. | Applications you send will appear here until they close. |
| `my_applications_screen.dart` | Offers you receive appear here, ready to accept or decline. | Offers you receive will appear here for you to accept or decline. |
| `my_applications_screen.dart` | Nothing archived | No Archived Applications |
| `my_applications_screen.dart` | whose offers you declined appear here. | whose offers you declined will appear here. |
| `my_applications_screen.dart` | Find a job you like and apply. You can follow it here. | Find a job and apply. You can track it here. |
| `my_applications_screen.dart` | See plans to know when recruiters open yours | View plans to see when recruiters open your application |
| `my_applications_screen.dart` | Things waiting on you | Actions waiting for you |
| `saved_jobs_screen.dart` | Bookmark removed | Bookmark removed. |
| `saved_jobs_screen.dart` | Back on your board | Job restored to your board. |
| `saved_jobs_screen.dart` | Couldn't load your saved jobs | Unable to Load Your Saved Jobs |
| `saved_jobs_screen.dart` | Tap the bookmark on a job to keep it here. | Tap the bookmark on a job to save it here. |
| `saved_jobs_screen.dart` | Couldn't load your hidden jobs | Unable to Load Your Hidden Jobs |
| `saved_jobs_screen.dart` | A job you mark "Not interested" leaves your board and waits here, in case you change your mind. | Jobs you mark "Not Interested" are removed from your board and kept here. |

**To Title Case, words unchanged (218 strings):** Cancel interview → Cancel Interview; Cover note → Cover Note; …% match → …% Match; … of … met → … of … Met; Next step → Next Step; Schedule interview → Schedule Interview; Make an offer → Make an Offer; Screening answers → Screening Answers; No-show → No-Show; Send offer → Send Offer; Your notes and rating → Your Notes and Rating; Add note → Add Note; In review → In Review; Not selected → Not Selected; Move to review → Move to Review; Move to interview → Move to Interview; Move to offer → Move to Offer; Mark as hired → Mark as Hired; Move to … → Move to …; Most recent → Most Recent; Best match → Best Match; Most qualified → Most Qualified; Sort by → Sort By; Filter by rating → Filter by Rating; Any rating → Any Rating; … stars and up → … Stars and Up; …+ stars → …+ Stars; Newest first → Newest First; Closing soonest → Closing Soonest; Most applicants → Most Applicants; Keep open → Keep Open; Close job → Close Job; Jobs you posted → Jobs You Posted; Post a job → Post a Job; Post your first job → Post Your First Job; Clear search → Clear Search; Clear filters → Clear Filters; Edit job → Edit Job; Duplicate as draft → Duplicate as Draft; Continue editing → Continue Editing; Jobs are posted by the hiring team → Jobs Are Posted by the Hiring Team; Jobs are posted for a company → Jobs Are Posted for a Company; Not now → Not Now; Switch company → Switch Company; Create a company → Create a Company; Schedule an interview → Schedule an Interview; Round name (optional) → Round Name (Optional); Video call / In person / Phone call → Video Call / In Person / Phone Call; Meeting link (optional) → Meeting Link (Optional); Map link (optional) → Map Link (Optional); Notes for the panel (optional) → Notes for the Panel (Optional); … (you) → … (You); Add me to the panel → Add Me to the Panel; Company admin → Company Admin; Office admin → Office Admin; Hiring manager → Hiring Manager; Make an offer / Change the offer → Make an Offer / Change the Offer; Save changes → Save Changes; Save draft → Save Draft; Salary offered → Salary Offered; Per year / Per month / Per hour → Per Year / Per Month / Per Hour; Job title on the offer (optional) → Job Title on the Offer (Optional); Joining date (optional) → Joining Date (Optional); Reply by (optional) → Reply By (Optional); Note to the applicant (optional) → Note to the Applicant (Optional); Yes or no → Yes or No; Years of experience → Years of Experience; Free text → Free Text; In person → In Person; Phone call → Phone Call; Video call → Video Call; Strong yes → Strong Yes; Strong no → Strong No; This interview → This Interview; From screening → From Screening; Hiring team notes → Hiring Team Notes; Earlier rounds → Earlier Rounds; Your scorecard → Your Scorecard; Panel scorecards → Panel Scorecards; Feedback submitted → Feedback Submitted; Submit scorecard → Submit Scorecard; Open résumé → Open Résumé; Notes for the panel → Notes for the Panel; Join meeting → Join Meeting; AI screening → AI Screening; Employer questions → Employer Questions; Must-have → Must-Have; Not met → Not Met; Leave without saving? → Leave Without Saving?; Keep editing → Keep Editing; Job title → Job Title; Department (optional) → Department (Optional); Mid-level → Mid-Level; Job type → Job Type; Full-time → Full-Time; Part-time → Part-Time; Work mode → Work Mode; On-site → On-Site; State (optional) → State (Optional); Add city → Add City; Openings in each city → Openings in Each City; Required skills → Required Skills; Experience (years) → Experience (Years); Per year → Per Year; Per month → Per Month; Per hour → Per Hour; Salary is negotiable → Salary Is Negotiable; How candidates apply → How Candidates Apply; On your own site → On Your Own Site; Apply by (optional) → Apply By (Optional); No deadline → No Deadline; Ask for a résumé → Ask for a Résumé; Show me as the contact → Show Me as the Contact; Questions for applicants → Questions for Applicants; Add skill → Add Skill; Ready to publish → Ready to Publish; Before you publish → Before You Publish; Publish again → Publish Again; Update posting → Update Posting; Move up → Move Up; Remove question → Remove Question; Add a question → Add a Question; Edit question → Edit Question; Save question → Save Question; Your application → Your Application; View job → View Job; Message hiring team → Message Hiring Team; Your answers → Your Answers; Your match → Your Match; Ask for another time → Ask for Another Time; What you sent → What You Sent; Withdraw your application? → Withdraw Your Application?; Keep application → Keep Application; Accept this offer? → Accept This Offer?; Decline this offer? → Decline This Offer?; Not yet → Not Yet; Accept offer → Accept Offer; Decline offer → Decline Offer; Send message → Send Message; Offer declined → Offer Declined; Recent activity → Recent Activity; Date applied → Date Applied; Find similar jobs → Find Similar Jobs; View application → View Application; Withdraw application → Withdraw Application; Your career → Your Career; Next steps → Next Steps; Open tracker → Open Tracker; Search appearances → Search Appearances; Recruiter views → Recruiter Views; Recruiter actions → Recruiter Actions; Résumé strength → Résumé Strength; Your applications → Your Applications; My applications → My Applications; Hidden jobs → Hidden Jobs; Job alerts → Job Alerts; Join call → Join Call; No reviews yet → No Reviews Yet; Write a review → Write a Review; Update my review → Update My Review; Current employee → Current Employee; Former employee → Former Employee; Verified employee → Verified Employee; Not enough salary reports yet → Not Enough Salary Reports Yet; Share your salary → Share Your Salary; No interview experiences yet → No Interview Experiences Yet; Share your interview → Share Your Interview; No open jobs → No Open Jobs; Offer accepted → Offer Accepted; No offer → No Offer; Still in progress → Still in Progress; Update your review of … → Update Your Review of …; Submit review → Submit Review; Replace my review → Replace My Review; Overall rating → Overall Rating; Advice to management (optional) → Advice to Management (Optional); Your job title (optional) → Your Job Title (Optional); Employment status → Employment Status; Share a salary at … → Share a Salary at …; Share salary → Share Salary; City (optional) → City (Optional); Years of experience (optional) → Years of Experience (Optional); Your interview at … → Your Interview at …; Share interview → Share Interview; Role you interviewed for (optional) → Role You Interviewed For (Optional); Difficulty (1 easy, 5 hard) → Difficulty (1 Easy, 5 Hard); Overall experience → Overall Experience; Questions you were asked (optional) → Questions You Were Asked (Optional); Process length in days (optional) → Process Length in Days (Optional); Work-life balance → Work-Life Balance; Pay and benefits → Pay and Benefits; No past interviews → No Past Interviews; Decline this invitation? → Decline This Invitation?; No invitations yet → No Invitations Yet; Open to opportunities → Open to Opportunities; View & apply → View & Apply; New alert → New Alert; No job alerts yet → No Job Alerts Yet; Create an alert → Create an Alert; … new → … New; Edit search → Edit Search; Delete alert → Delete Alert; Hide matches → Hide Matches; New job alert → New Job Alert; Save alert → Save Alert; Find jobs → Find Jobs; No applications match “…” → No Applications Match “…”; No interviews yet → No Interviews Yet; No offers yet → No Offers Yet; No applications yet → No Applications Yet; View all applications → View All Applications; Up next → Up Next; Review offer → Review Offer; No saved jobs yet → No Saved Jobs Yet; Browse jobs → Browse Jobs; No longer accepting applications → No Longer Accepting Applications; No hidden jobs → No Hidden Jobs; Show again → Show Again.

**Left as they were.** "Try again"; the facts line of an interview experience ("Got an offer and accepted", "Negative experience", "Average difficulty"), which reads as the website words it and is pinned by `career_insights_test.dart`; the timeline and activity lines ("You applied", "Offer sent", "Opened by the hiring team"); the fact lines on rows ("12 applicants • 3 not viewed", "Offer sent, awaiting reply", "Closes today"); the messages Confirm and Ask for Another Time send to the hiring team (they are sent, so they are data); the "(copy)" suffix of a duplicated job (a stored title); the country and currency lists; placeholders that are examples ("Technical round", "FM manager, Bengaluru"); `demo_career_repository.dart` and `demo_hiring_repository.dart` (so the demo's review sub-ratings still read "Work-life balance" and "Pay and benefits" where the API's now read "Work-Life Balance" and "Pay and Benefits"). The sentence the API returns for an unverified company ("… Your drafts are saved — finish verification and publish them in one click.") is the portal's and still carries its dash; only the app's own fallback was reworded.
