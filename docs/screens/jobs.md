# Jobs

Designs: `docs/designs/jobs-board.png` (the tab) and `docs/designs/job-sheet.png` (a job over it). Code: `lib/features/jobs/`. Goldens: `build/screens/jobs_board.png`, `build/screens/job_sheet.png` (demo content, at the designs' frames). Tests: `test/jobs_test.dart` (logic and mapping), `test/jobs_screen_test.dart` (every control tapped), `test/live/jobs_live_test.dart` (the same controls against the local API). Everything the board hands on to (saved and hidden jobs, applications, interviews, alerts, invitations, the career hub, the company page, and the hiring team's screens) is in `docs/screens/career.md`.

The live app reads the portal's API; the database holds the designs' content through `tool/seed/learning-jobs.ts` (see "Seed" below). Everything the design draws that the API has no field for is filled with the nearest true thing, in the design's slot, and listed under "What the design shows that the API does not give".

## The board (`JobsScreen`)

- **Title bar:** Back (to Home), "Jobs", the bell (`GET /notifications/unread-count` for its dot; opens the app's notifications through `JobsNavigation.onBell`, else `/notifications` on the website).
- **Search:** `GET /jobs?search=` (the API matches title, description and skills, not company names). While the board is scoped to a saved search (below) a search is made inside it.
- **Chips, first row:**
  - *Post a job* opens the composer **in the app** for a member on a company's hiring team (owner, admin or recruiter with a company: `JobsController.canHire`, from `GET /auth/me`). For anyone else it explains that jobs are posted for a company and offers **Create a company** (`JobsNavigation.onCreateCompany`, else `/account/companies/new`); if the account cannot be checked it says so and opens nothing. The composer and everything after it are in `docs/screens/career.md`.
  - *My jobs 3* is a sheet in the app: the member's open applications with where each stands ("Interview • Applied 3d ago", from `GET /applications/mine`, withdrawn ones left out, so its count is the chip's) and, in a second tab, the jobs they bookmarked (`GET /jobs/saved`). A row opens the job. The footer opens, **in the app**, the whole tracker ("See all applications"), the saved jobs ("See all saved jobs") or "Your career hub", and, for a hiring team only, a third row **Jobs you posted**.
  - *Alerts 2 new* **runs the saved search** (`GET /jobs/alerts/:id/run`, which is what counts its new matches as seen), puts its results on the board, open, scrolls to them and re-reads the badge (so "2 new" goes). It also brings the scope back if the member dropped it. A member with no saved search gets the **new-alert form in the app** (the Job alerts screen), and the board reads the badge again when it closes.
  - *Demonstrate skills* opens the Learning area's assessments through `JobsNavigation.onDemonstrateSkills`, else `/learning/assessment` on the website.
- **Scope bar** ("Facilities & Real Estate • Bengaluru, IN ⊗"): the member's first saved search (`GET /jobs/alerts`: its name, the first city of its criteria). The third section is that search's results, read from the board (`GET /jobs` with the search's own filters), **not run**, so opening the board never uses up the "2 new". The cross drops the scope: the board reloads with the latest jobs as its third section, and a search typed afterwards covers every job. A member with no saved search sees no bar.
- **Filter chips:**
  - *Filters (n)* counts every filter in force: Easy Apply, the date, each work mode and type picked, the city, and, while the scope is on, each filter the saved search holds (a city the member picks takes the search's city's place). With the seeded search that is Easy Apply + city + country = **3**, as the design reads; the cross takes the search's two away. It opens a sheet for work mode, employment type and city (`workMode`, `employmentType`, `city` on `GET /jobs`), with **Save as alert**, which opens the new-alert form filled from the filters in force.
  - *Easy Apply* is **on to begin with**, filled and ticked as the design draws it, and is a real filter: it keeps the jobs that take applications on ICR (`applyMethod` other than `EXTERNAL_URL`; the API has no such filter, so it trims what is loaded, sections and search results alike, with no reload). Off shows every job. When it hides every job there is, the empty state says so and offers "Show all jobs".
  - *Date posted* opens a menu (any time, 24 hours, week, month) and sets `postedWithinDays`; the chip then reads what it is set to.
  - *In my network* has no source (no connections, and no job filter that follows people), so it does not pretend: it says so in a snackbar with an "Open network" action (`/network` on the website).
- **Sections:** "Recommended Jobs for You" (`GET /jobs/recommended?mode=foryou`, which carries `matchScore`), "Matching your preferences" (`mode=preferences`), then the saved search (its name as the title) or "Latest jobs". **Each shows exactly three rows and "View More"** when there are more; View More shows what is loaded, then pages: the saved search and the latest jobs by `page` of `GET /jobs`, the recommended ones by a larger `limit` (the API's cap is 24, and the for-you feed has no pages). When everything is on show the words become "Show Less". A search or a filter narrows the board to one list of results, which pages as it scrolls.
- **Rows:** the company's logo on a light tile (57 × 61 dp; the logo drawn at half its pixel size and shrunk only to fit, initials when there is none), title, company, "city, country • work mode", and the bookmark (`POST`/`DELETE /jobs/:id/save`, applied at once and rolled back with the API's sentence if refused; the initial state from `GET /jobs/actions`, read again on every refresh).
- **Pull to refresh** reads the board, the counts and the bookmarks again.

## The sheet (`showJobSheet`)

Opens over the board, blurred and dimmed, from `GET /jobs/:id` plus `GET /companies/:id`. Every slot of the design is filled; where the API has nothing, the slot has the nearest true thing:

| Design | Live |
|---|---|
| "JOB DETAILS", share, bookmark, more | Share hands the title and link to the system share sheet; the bookmark is the board's (the row behind the sheet follows); More offers "Copy link" and "Open on the ICR website". |
| Company name with the seal | `verificationLevel` above REGISTERED draws the seal. |
| "Enterprise Workplace & Asset Management" under the name | The API has no tagline: the company's **industry** ("Commercial Real Estate Services", from `Company.industry`), else the first sentence of its description if short (up to 56 characters), else its kind ("Real Estate"). |
| Blue line under the title | `department`, after the category when the job has one. |
| "Actively reviewing applicants • Posted 3d ago • 142 applicants" | "Accepting applications • Posted 3d ago • 2 openings". The API gives a candidate neither the applicant count nor the views (`_count.applications` and `viewCount` are the job's team's); when it does give them to a team member they take the slot ("142 applicants", else "310 views"), before the openings. |
| "92% Profile Match" | The API's score (95% from the for-you feed); the AI preview's when that answers. |
| "Your profile matches 4 of 5 requirements" | See below. |
| "Meet the hiring team" | The job's `hiringContact` (one person, never a team). The design's "• 2nd" and "Active today" are left out: no connection model, and no last-seen for a person. "Message" opens a conversation (`POST /messaging/conversations/job`) and then its thread on the website (`/messaging?c=<id>`). The strip of faces is the company's people (`GET /companies/:id/people`): photos where they have one, initials otherwise; "Nikhil M. and 4 others from ICR work at this organization." and "+4" for the rest; it opens the company's People tab on the website. |
| "About Global Infra Solutions" | The first photo of the company's gallery in the tile, the company's name (the legal name is private to the company and ICR staff, so "Ltd." is not there), "Real Estate • 500+ employees", its description. **"+ Follow"**: the API has no company follow (members follow members), so the button is drawn as the design has it and says "Following a company is on the website." while it opens the company's page there. |
| Easy Apply | See below. |

**The match card.** With Career Pro the rows are the AI preview's signals (`GET /jobs/:id/match-preview`). Without it, or when the scorer is down (the local database has no pgvector, so it answers 500), the rows are built from what the job asks for, held against the member's profile (`job_requirements.dart`):

1. *Years*: "8+ years of experience" against the profile's years of experience (`GET /users/me/profile`), "Your résumé lists 9.4 years of experience." (a profile with none says "Add your years of experience to your profile.").
2. *Degrees*: the job's `educationQualifications` keys, worded as the composer words them ("B.Tech / B.E. in Mechanical or Electrical"; a degree with no specialisation takes any), against the member's education (`GET /profile/education`): the degree by what it is called (B.Tech, B.E., Bachelor of Engineering) and the specialisation by the field of study.
3. *Qualifications* the employer wrote (`qualifications`, then the preferred ones with "Preferred credential."), found in the member's credentials (`GET /credentials/me`) and education by acronym (RICS, IFMA) or as the whole phrase.
4. *Skills*, one row each, against the résumé's.

Each row has the design's circle (filled when met, empty when not) and the detail line under it, and the title counts them ("matches 6 of 8"). "Show comparative applicant insights ›" opens the job on the website, where the preview and the applicants' comparison are.

**Easy Apply** (bottom bar, with the bookmark beside it) `POST /jobs/:id/apply`, one form (`apply_sheet.dart`, rules in `apply_rules.dart`, ported from `@icr/shared`):
- an optional **note**, an optional **expected salary**, the **résumé** to send (`GET /users/me/resumes`, the default first), and a **mobile number** field when the profile has none (`GET /auth/me`), refused locally under 8 characters. If the API refuses for want of a number anyway (`400`, "Add a mobile number so the employer can reach you.") the field appears with that sentence, and the number is saved by the API with the application;
- a job's **screening questions** are asked in the form, by kind (yes/no, years, number, pick one, pick several, rating, date, text), and every question must be answered in the format it asks for (the shared screening rule's reason shows under the field, and "Answer the 2 questions above in the format they ask for." under the button); the answers are sent with the application, and whether one meets the employer's bar is the employer's to mark, never the form's to refuse;
- an optional **LinkedIn link**, checked as the API checks it (a scheme is optional; a bare host or another site is not a profile) and sent normalised;
- a role open only to some groups (`diversityOnly`) asks which group applies (checkboxes, at least one) and says it is kept private to the hiring team; a role for one gender asks for it (chips) and says it is kept with the profile once given. The API locks a profile's gender for good, so the live tests never send one: they prove the refusals instead;
- the month's application allowance, when the plan has one ("3 of 10 applications left this month", or all used), with **See plans**;
- a job that takes applications on the employer's own site reads "Apply on company site" and opens that link (the API refuses an application for it); no form;
- once sent the bar reads "Applied" and the board's "My jobs" count grows; an application the API refuses (already applied, plan quota, own company's job…) shows its sentence in the form.

## Controls and the tests that prove them

`W` = `test/jobs_screen_test.dart` (the control tapped in a widget test; `RecordingLinks` shows where it would have gone), `U` = `test/jobs_test.dart` (controller, mapping, pure logic), `L` = `test/live/jobs_live_test.dart` (the real API through the app's own repository and controllers, undone afterwards).

| Control | Proved by |
|---|---|
| Back; bell (dot and count, opens `/notifications`) | W title bar; L bell count |
| Search (`?search=`, inside the scope) | W "a search is made inside the scope"; U search query; L search, scope |
| Post a job (composer for a hiring team; "Create a company" for anyone else; account unreachable) / Demonstrate skills (the app's assessments, else the website) | W chips (`test/jobs_screen_test.dart`, "the chips"); L `test/live/jobs_employer_live_test.dart` "who may post" |
| My jobs (sheet, tabs, row opens the job; footer: all applications, all saved jobs, the career hub, "Jobs you posted" for a hiring team) | W My jobs ×4; U My jobs mapping; L My jobs |
| Alerts (runs the search, badge gone, scrolls; none: the new-alert form in the app) | W Alerts ×3; U Alerts, mapping of the run; L Alerts: reading does not mark, running does (a temporary alert, deleted) |
| Scope cross (drops the scope, count falls, search widens) | W scope bar; U cross, count; L scope |
| Filters sheet (work mode, type, city, Clear all) | W filters ×2; U query; L search and filters |
| Filters sheet: Save as alert | W filters; `test/career_alerts_test.dart` (the form from the board's filters) |
| Easy Apply chip (default on, trims, "Show all jobs") | W Easy Apply ×2; U Easy Apply; L Easy Apply and the external job |
| Date posted (`postedWithinDays`) | W Date posted; U date; L search and filters |
| In my network (says so, offers `/network`) | W In my network |
| View More / Show Less (rest, then real pages) | W sections ×2; U View More ×2; L View More (`pageSize` 3: every page, each job once), latest and results paging |
| Row bookmark (applied, rolled back) | W bookmark ×2; U bookmarks; L bookmarks (saved, read back, refresh, undone; refused one rolls back) |
| Row tap, pull to refresh, load failure | W row opens its job, pull to refresh, "cannot load" |
| Sheet: share, bookmark, More (copy, website) | W sheet ×3 |
| Sheet slots (tagline, status, count, chips, About tile) | W slots, counts; U company mapping, counts; L sheet |
| Match card and its link | W match card; U requirements ×8, match mapping ×4; L match card |
| Message (thread opens; refusal says why) | W Message ×2; U Message; L Message (same thread again) |
| The faces (open the company's people), + Follow, About | W faces, + Follow, About; U people mapping; L strip |
| Easy Apply: note, phone asked, refusal asks for the phone, other refusals, external, screening questions, already applied | W Easy Apply ×7; U phone refusal, apply; L no phone (refused, nothing written), real application and withdrawal, external refused by the API |
| Easy Apply: LinkedIn link, diversity groups, gender, expected salary, résumé choice | W Easy Apply (diversity, gender, LinkedIn); U apply rules; L LinkedIn refusal, the women-only and female-only postings refuse an unqualified application (nothing is written) |
| Company name, logo, + Follow and the faces open the company's page in the app | W faces, + Follow; `test/career_insights_test.dart`; L `career_screens_live_test.dart` |

## What the design shows that the API does not give

- Applicant counts ("142 applicants") and views: private to a job's team. The slot shows the openings.
- "Actively reviewing applicants": nothing says a recruiter is looking. The slot says "Accepting applications" (or "You have applied").
- Connection degree ("2nd"), "Active today", "RICS alumni from your network": no connection model, no last-seen. Left out; the strip says who works there, not who you know.
- The company's legal name ("Global Infra Solutions Ltd."), its tagline ("Enterprise Workplace & Asset Management") and its employee count in the design's number ("8,400+"): the legal name is private, there is no tagline field (the industry stands in), and size is a bucket ("500+ employees").
- "+ Follow": members follow members, not companies. See above.
- "In my network": nothing to filter on. See above.
- The match card's "Matched from Embassy TechZone portfolio role", "Degree accredited and verified via National Registry", "Complete Vinfraa micro-track to qualify": the AI's wording about verified data ICR does not hold. The fallback words each row from the profile ("Your profile lists B.Tech, Mechanical Engineering.").
- A for-you feed with more than 24 jobs: the API's cap.

## Measured against the design

Compared band by band with `tool/design/measure.py` on the golden and the design (both 2x, the frame cut at 16,14 / 780 px wide): every chip, the scope bar, the headings and the rows land within 1 dp of the design in x and y.

- Chip row 1: *Post a job* x 10→99.5 (design 99), *My jobs* 104→203 (202.5), *Alerts* 208→321.5 (321), icons 14.4 / 11.5 / 12 / 12.5 dp (their ink matches the design's 13.5 / 7.5 × 10 / 11 / 11.5 dp), the *2 new* pill 35.5 × 16 dp as designed. *My jobs* is **outlined with a pale circle badge** (`#F2F4F6`, blue digit, 16.5 dp), not a grey chip with a white one.
- Scope bar: 28 dp tall (not 29), with the design's soft shadow (`0 1px 2px rgba(0,0,0,.05)`); the cross is 9 dp of ink centred 13 dp from the bar's right end; label 10 dp w600, place 10.5 dp w500, the 3 dp dot with 7 dp before and 4 after.
- Filter chips: **25 dp tall** with the same soft shadow (they were 26 with none), text 10.5 dp w600 (the row above is 10 dp), *Filters (3)* x 10→94, *Easy Apply* 99→204.5, *Date posted* 209.5→303 with its small solid caret (5.5 × 3 dp).
- Sections: 257 dp from heading to heading (it was 271): the gap between sections is 10.5 dp; a row's bookmark is 12 × 15 dp of ink (it was 13.5 × 17).
- Logos: an API logo is drawn at half its pixel size and only shrunk to fit, so the seeded logos (the design's crops at 2x) fill their tile as the design's do (they were shrunk by an 8 dp inset, to about 70%).
- Row text: the company name is Work Sans **Bold** (the design's is 24% heavier in ink than SemiBold's).
- The sheet, line by line against the 1x design (every band within 1 dp, and the text of each line within 0.5% of the design's width):
  - **Running text is IBM Plex Sans Medium, not Regular.** The design's lines are 2.5% wider than Regular's and fit Medium at 10 dp exactly; body, bullets, the About description, its meta line, the contact's title line and the match card's detail lines are Medium. With it the paragraphs and bullets break where the design's do.
  - Bullets: 15 dp line pitch with 8 dp between items (it was 16 and 6), the words stop 23 dp short of the right margin (the design wraps "…Grade-A / towers housing…"), and the tick is Material's "task alt" in the primary blue, 15 dp of ink (it was a thin Lucide ring in a lighter blue).
  - Header lines: the dots are 3.5 dp with the design's uneven room (meta: 9 | • | 17.5, 17.5 | • | 10; status: 17.5 | • | 10, 27.5 | • | 10), the pin 10 × 12 dp of ink; "Profile Match" has the design's filled star badge.
  - Match card: 174 dp tall as the design; the title of each row is centred on its circle (5.5 dp below the row's top), where it sat 5.5 dp high; rows still 40 dp apart.
  - Hiring team: the photo sits 3 dp below the top of the name (it was 3.5 dp above), 15 dp between the lines of the title and "Job poster", the strip 42 dp tall at 1156 dp.
  - About: the tile is 46 × 48 dp with its hairline over the photo (a border around it made it 48 × 50); the name's line and the "+ Follow" sit where the design's do, and the name and its line keep to 160 dp (the design wraps "8,400+ / employees"); "+ Follow" ends 33 dp from the right edge.

## Seed (`tool/seed/learning-jobs.ts`, the jobs half)

What the sheet and the board read, beyond the three companies, seven people, the three STP rows and the Global Infra job: `industry` on each company (the tagline); the sheet's job names the degrees it accepts (`UG_BTECH_MECHANICAL`, `UG_BTECH_ELECTRICAL`) and one preferred credential ("RICS or IFMA Facility Management Charter"); the personas' résumé carries `yearsExperience: 9.4` in its content (the field the profile endpoint serves); Bharat has one education entry (B.Tech, Mechanical Engineering; not Pooja, whose profile completeness the e2e suite reads); and `design-lj-job-external-1` ("Estate Operations Manager", Kolkata) takes applications on `careers.globalinfra.example`, for the "Apply on company site" path. `--remove` takes all of it out.

The alert's "2 new" stays until Alerts is tapped (opening the board only reads the search). Running the seed again re-bases it.

## Demo content

`DemoJobsRepository` holds the designs' sample rows (three sections of "Senior Facilities Manager for STP Plant" at CBRE South Asia with the Green and BlueDot logos) and the Global Infra Solutions job with every line of the sheet. Run with `--dart-define=FEED_SOURCE=demo`.

## Wiring

`ChangeNotifierProvider<JobsController>` above `AppShell` (see `lib/app.dart`), `JobsScreen(onBack: ..., navigation: ...)` as the shell's `jobs` tab. The controller starts loading when the tab is first shown, and reads who the member is to the hiring side (`hiringAccess()`, once). `JobsController(repository, {links, hiring})` takes where a tap leaves the app (`JobLinks`: the website and the share sheet; a test passes a recorder), which the sheet's controller inherits, and the employer source (`hiringRepositoryFor(repository)` unless given).

`JobsNavigation` is the one place the lead wires the hand-overs these screens need from the rest of the app (company page, conversation, member profile, notifications, the Jobs tab, the profile editor, Create a company, Verify the company, assessments). Each has a website fallback, so a tap is never dead before it is wired; the table is in `docs/screens/career.md`.
