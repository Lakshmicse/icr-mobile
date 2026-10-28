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
- Tabs (each reads on first show, pages with "View More", pull to refresh reads the open tab again, a failure says why with "Try again", an empty tab says so): **Jobs** (the open jobs; a row opens the job sheet), **People** (members with a public profile; a row opens the member), **Reviews** (rating card, the member's own review's state, "Write a review" / "Update my review", approved reviews), **Salaries** (each role with typical pay and the middle half as a bar, or "not enough reports yet"; "Share your salary"), **Interviews** (average difficulty and experience; "Share your interview").
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
- **Tabs** All, Open, Drafts, In review, Paused, Closed with counts; **search** (submit), **sort** (newest, closing soonest, most applicants, title A to Z), **Only jobs I started**, *View More* paging, pull to refresh, a failure says why with *Try again*; a company that never posted is asked to post its first.
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

- *Schedule / Reschedule* (`InterviewSheet`): round name, date, time, 30 / 45 / 60 / 90 minutes, video (link) / in person (address, map link) / phone, notes for the panel, and the panel from `GET /team/members` (the booker is ticked); the sheet checks what the API checks (a future time, a panel, an address for an in-person round, https links) and keeps the API's refusal under the button with everything typed.
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
