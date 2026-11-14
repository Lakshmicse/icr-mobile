# Source candidates — the employer's talent search

The website's `/talent` (`TalentInner`, "Source candidates" under Jobs), drawn by the app since 12 Nov 2026. The owner's
instruction: "take the reference of the Web and do as it is" — the search, the filters, the candidate results, the quick view
with notes and tags, the saved searches and the employer gate, in the app's look (white, hairlines, full-width rows).

## Files

`lib/features/talent/` — `talent_models.dart` (`TalentFilters`, `Candidate`, `CandidateDetail`, `NextRole`, `CandidateNote`,
`SavedSearch`, `TalentAccess`, `TalentViewer`, `ParsedQuery`, `JobOption`), `talent_labels.dart` (the shared label tables, the
seed industries and functions, `rupees`, the day formats), `talent_repository.dart` (`TalentRepository`, `ApiTalentRepository`,
`DemoTalentRepository` with a sample pool and a `sent` log), `talent_controller.dart` (`TalentController`,
`CandidateQuickViewController`), `talent_screen.dart` (`TalentScreen`), `candidate_row.dart` (`CandidateRow`, `CandidateAvatar`,
`NextRoleChip`, `MatchChip`), `talent_filter_sheet.dart` (`showTalentFilters`), `describe_sheet.dart` (`showDescribeSheet`,
`showBooleanHelp`), `candidate_quick_view.dart` (`showCandidateQuickView`).

```dart
class TalentScreen extends StatefulWidget {
  const TalentScreen({super.key, required this.onBack, this.onOpenMember, this.repository});
}
```

`onOpenMember(String userId)` is the lead's to connect to the member profile: the quick view's name (and its "View profile")
calls it for a candidate whose profile is public, as the website's `PersonLink` links only then. The screen builds its own
repository (`AppConfig.demo ? DemoTalentRepository() : ApiTalentRepository(api: context.read<ApiClient>())`); `repository` is the
seam for tests.

## What it shows

- **Who may source.** `GET /auth/me` (role, the acting company) and, for someone acting as themselves, `GET /me/companies` for
  how many they belong to. A hiring role acting for a company (`RECRUITER_TIER`: COMPANY_ADMIN, BRANCH_ADMIN, RECRUITER;
  SUPER_ADMIN with or without a company) gets the search. Anyone else sees the notice the job composer's `showHirersOnly` gives,
  in the website's `NoCompany` order, worded for sourcing: acting as themselves with companies → "You're using your personal
  account", switch to one; with none → "Candidates are sourced for a company", set one up or ask its admin; a non-hiring role at a
  company → "Candidates are sourced by the hiring team", ask its admin for the recruiter role. ICR staff with no company search
  but see the website's info sentence ("You can search candidates and save your searches, but matching them to jobs, saving
  them to projects, and inviting or contacting them need a company."), no Match mode, and a quick view that offers none of the
  company actions.
- **Browse / Match to a job** as two chips (the website's toggle), then the search box ("Search name, headline, skill,
  employer…"; free text applies 350 ms after typing, or on the search key — the website's debounce), then the actions, wrapping:
  **Filters (n)**, the **sort** (Recently updated / Most experienced / Soonest available, a sheet), **Describe who you want**,
  **Save search**. Saved searches follow as a row of chips scrolling sideways (a bell when alerts are on, the "new to you" count
  as a pill, the chip blue while its criteria are what the list shows; its ⋮ opens Turn off alerts / Alert me on new matches,
  Update to current filters, Delete). Under them the active-filter chips in the website's words (`“lease”`, `at CBRE`, `8+ yrs`,
  `≤ 30d notice`, `≤ ₹15.0L expected`, `Immediate joiners`, `Hiding viewed`…), each removable, and **Clear all**.
- **The Filters sheet** is the website's rail: Role & skills (Job titles, Skills, Current employer — comma-separated), Location
  (Locations, Work mode, Open to relocating), What they want (Job types, Industries, Job functions, Shift), Experience
  (Seniority, Min yrs / Max yrs), Availability & pay (Ready for their next role, Notice period, Expected salary up to), Activity
  (Profile updated, Hide profiles I've opened, Hide past applicants, Scope exclusions to a job when the company has jobs). Labels,
  helpers and options are the rail's; industries and functions come from `GET /masters`, else the shared seed lists.
- **The results**: "N candidates" (the API's reachable total), then one row per candidate the whole width with hairlines
  between — photo (ringed green when they tell everyone they are ready), name, Featured, headline, the "Ready for next role" chip
  (its summary on a long press), the first five skills and "+n", then the facts in the website's order: `9 yrs · Mumbai · JLL ·
  Expects ₹18,00,000 a year · 30d notice`, `Serving notice · free 15 Dec 2026`, `Immediate`. More pages load as the list is
  scrolled (the website pages with a control). Nothing found: "No candidates found — Try removing a filter or widening the
  notice-period range."
- **Describe who you want** (`POST /talent/parse`): a sheet with the website's placeholder and three example briefs; a brief that
  reads applies its filters and closes, and the screen says "Read as experience, notice period … — matched locally, no AI needed.
  Adjust anything in the filters."; one nothing can be read from, or the plan's refusal, is said in the sheet. Its "?" opens the
  Boolean search help (the six syntax rows).
- **Match to a job** (`GET /talent/match?jobId=`): pick one of the company's jobs (`GET /jobs/company`), then the website's rule
  sentence, the count and the rows with a "{n}% match" chip (green from 70, blue from 40, amber below). No job picked: "Pick a job
  — Select one of your jobs to rank matching candidates."
- **The quick view** (a sheet, the website's drawer): photo, name (a link to the profile when public), headline, next-role chip;
  the facts (`9 yrs experience · Mumbai · at JLL · …`); What they want (modes, types, industries, functions, shift, relocating —
  never a salary); Skills; Summary. Then, for a company: **Contact** — "Reveal contact" (`GET /talent/:id/contact`, which spends
  the allowance) shows email and phone, or the website's `LockedNotice` with its one step ("Verify your company to reveal
  candidate contact details." + Verify company; "Subscribe to reveal candidate contact details." + Upgrade for a company admin;
  "Your company's plan doesn't include candidate contact details. Ask your company admin to upgrade." + See plans for anyone
  else); **Invite to apply** — pick a job, `POST /job-invites`, "Invitation sent."; **Message** — the first message
  (`POST /talent/:id/message`, the pick's title as its job context), or the locked notice; **Notes & tags** — the team's private
  tags (`GET/POST/DELETE /talent/:id/tags`) and notes (`GET/POST /talent/:id/notes`, "author · 5 Nov"), never seen by the
  candidate.
- **The employer gate.** The API refuses in its own sentences and the app shows them as they arrive (a search the plan refuses —
  "Boolean search comes with Silver." — is the error state with Try again; a refused invitation, reveal, message, note or save
  is a snackbar). An unverified company's search is capped by the API (`talentResultCap`, 20): the app shows the capped total and
  rows exactly as the website does, with no sentence of its own, and the quick view's contact and message carry the verify
  notice. `GET /talent/access` says which (`verified`, `canRevealContact`, `canMessage`, `resultCap`).

## API calls

`GET /auth/me`, `GET /me/companies` · `GET /talent/access` · `GET /talent?q=&skills=&…&page=&limit=12&sort=` ·
`GET /talent/match?jobId=&…` · `GET /talent/:id` · `GET /talent/:id/contact` · `POST /talent/:id/message` · `POST /job-invites` ·
`GET|POST /talent/:id/notes` · `GET|POST /talent/:id/tags`, `DELETE /talent/:id/tags/:label` · `GET|POST /talent/searches`,
`PATCH|DELETE /talent/searches/:id` · `POST /talent/parse` · `GET /jobs/company?limit=50` · `GET /masters`.

## What the website does that the app leaves out, and why

- **Bulk selection and `TalentBulkBar`** (tick several cards → Save to project, Message up to 25 with `{{firstName}}` tokens).
  Projects (`/manage/projects`) are not in the app, so "Save to project" would have nowhere to go, and the bulk message is a desk
  workflow (a six-line template with token buttons) that does not fit a phone; a message is sent one candidate at a time from
  the quick view. Can be added later as a long-press selection.
- **Pagination control**: the website's page numbers are an infinite scroll here, as every list in the app.
- **`?savedSearch=` deep link** from the "New candidates match <search>" notification: the screen has no route parameter for it
  yet; the lead's notification opener can call `TalentController.applySaved` once the saved searches are read, or a `focusSearchId`
  can be added to the constructor.
- **After a message is sent** the website navigates to `/messaging?c=<id>`; the app shows "Message sent. The conversation is in
  your Messages." because the screen has no messaging callback in its constructor.
- **"Verify company" / "Upgrade" / "See plans"** open through `openSitePage` (`/company?tab=verification`, `/pricing/corporate`),
  which reaches the app's own screen when the resolver has one (plans do), else the app's web view — the company check has no
  native screen yet.
- Match results show the score chip, not the per-signal detail ("2 of 9 required skills…"), which the website also keeps off the
  card.
- Saved-search criteria are stored as the facets set (lists kept as lists, `sort` included) rather than the website's whole
  filter object with `page`/`limit`; the API reads either.

## Tests

`test/talent_test.dart` (24): the rows and facts; the search box, the debounce and the `“q”` chip; the sort; the empty state; the
Filters sheet (notice, skills + work mode, Clear all) and the chip words and query string for every facet; the quick view (what
they want, reveal, invite, message; tag and note saved and the tag removed; the profile link only when public); saved searches
(saved, listed, reopened, alerts toggled, deleted; one the API already holds with its new-match count); Describe who you want (a
brief read back, one that cannot be); Match to a job; the gate (the API's refusal of a search, the capped total with locked
contact and message, the plan notice for a recruiter, a refused invitation); who may source (the three notices and ICR staff
with no company).

## 13 Nov 2026: copy refined to the client's standard

Source Candidates: the search, the filter sheet, the quick view, the describe sheet and the gates (`lib/features/talent/`). Wording only: no layout, colour or behaviour changed. The rules are the client's marked-up manual of 13 Nov ("refine text and make it crisp for global standard"): Title Case for what is tapped or read as a label, sentence case with a full stop for sentences, plain international English, no dash inside a sentence, one term for one thing.

| Where | Was | Now |
|---|---|---|
| `candidate_quick_view.dart` | Pick a job | Select a Job |
| `candidate_quick_view.dart` | Contacting this candidate, inviting them to apply and keeping notes on them need a company. | A company is required to contact this candidate, invite them to apply or keep notes on them. |
| `candidate_quick_view.dart` | No jobs to invite to yet — post one first. | No jobs to invite candidates to yet. Post a job first. |
| `candidate_quick_view.dart` | See plans | View Plans |
| `describe_sheet.dart` | Couldn't read that as filters — try naming a role, city, or experience level. | Unable to read that as filters. Try naming a role, city or experience level. |
| `talent_filter_sheet.dart` | Matches their headline or desired roles | Matches their headline or desired roles. |
| `talent_filter_sheet.dart` | Where they are now, or want to be | Their current or preferred location. |
| `talent_filter_sheet.dart` | Includes anyone open to flexible shifts | Includes anyone open to flexible shifts. |
| `talent_filter_sheet.dart` | Derived from years of experience | Derived from years of experience. |
| `talent_filter_sheet.dart` | Min yrs | Min Years |
| `talent_filter_sheet.dart` | Max yrs | Max Years |
| `talent_filter_sheet.dart` | Their asking figure, per year | Their expected salary, per year. |
| `talent_filter_sheet.dart` | Hide profiles I've opened | Hide Viewed Profiles |
| `talent_filter_sheet.dart` | Also hides anyone already invited to it | Also hides anyone already invited to it. |
| `talent_models.dart` | — matched locally, no AI needed. Adjust anything in the filters. | . Matched locally without AI. Adjust anything in the filters. |
| `talent_screen.dart` | Set at least one filter first | Set at least one filter first. |
| `talent_screen.dart` | You can search candidates and save your searches, but matching them to jobs, saving them to | You can search candidates and save searches. Matching them to jobs, saving them to |
| `talent_screen.dart` | projects, and inviting or contacting them need a company. | projects, and inviting or contacting them require a company. |
| `talent_screen.dart` | No jobs to match against yet — post one first. | No jobs to match against yet. Post a job first. |
| `talent_screen.dart` | Your role at this company does not source candidates. Ask its admin to make you a recruiter, and you can | Your role at this company cannot source candidates. Ask its admin to make you a recruiter to |
| `talent_screen.dart` | search the talent pool, save searches and invite people to apply here. | search the talent pool, save searches and invite people to apply. |
| `talent_screen.dart` | You're using your personal account | You Are Using Your Personal Account |
| `talent_screen.dart` | Set up your company on ICR and you can search the talent pool, save searches and invite people to apply. | Create your company on ICR to search the talent pool, save searches and invite people to apply. |
| `talent_screen.dart` | If your company is already here, ask its admin to make you a recruiter. | If your company is already on ICR, ask its admin to make you a recruiter. |

**To Title Case, words unchanged (67 strings):** View profile → View Profile; What they want → What They Want; Reveal contact → Reveal Contact; Invite to apply → Invite to Apply; Send message → Send Message; Notes & tags → Notes & Tags; Save note → Save Note; Verify company → Verify Company; Ready for next role → Ready for Next Role; …% match → …% Match; Describe who you want → Describe Who You Want; Boolean search help → Boolean Search Help; Apply as filters → Apply as Filters; Boolean search → Boolean Search; Clear all → Clear All; Role & skills → Role & Skills; Job titles → Job Titles; Current employer → Current Employer; Work mode → Work Mode; Open to relocating → Open to Relocating; Job types → Job Types; Job functions → Job Functions; Availability & pay → Availability & Pay; Ready for their next role → Ready for Their Next Role; Notice period → Notice Period; Expected salary up to → Expected Salary Up To; Profile updated → Profile Updated; Any time → Any Time; Hide past applicants → Hide Past Applicants; Scope exclusions to a job → Scope Exclusions to a Job; All my jobs → All My Jobs; Show candidates → Show Candidates; Mid-level → Mid-Level; On-site → On-Site; Full-time → Full-Time; Part-time → Part-Time; Day shift → Day Shift; Night shift → Night Shift; Rotational shifts → Rotational Shifts; Flexible shifts → Flexible Shifts; 15 days or less → 15 Days or Less; 30 days or less → 30 Days or Less; 60 days or less → 60 Days or Less; 90 days or less → 90 Days or Less; Last 7 days → Last 7 Days; Last 30 days → Last 30 Days; Last 3 months → Last 3 Months; Recently updated → Recently Updated; Most experienced → Most Experienced; Soonest available → Soonest Available; Immediate joiners → Immediate Joiners; Hiding viewed → Hiding Viewed; Hiding past applicants → Hiding Past Applicants; Match candidates to this job → Match Candidates to This Job; Turn off alerts → Turn Off Alerts; Alert me on new matches → Alert Me on New Matches; Update to current filters → Update to Current Filters; Source candidates → Source Candidates; Match to a job → Match to a Job; Save search → Save Search; No matches yet → No Matches Yet; No candidates found → No Candidates Found; Candidates are sourced by the hiring team → Candidates Are Sourced by the Hiring Team; My companies, in your profile → My Companies, in your profile; Candidates are sourced for a company → Candidates Are Sourced for a Company; Save this search → Save This Search; Notify me when new candidates match → Notify Me When New Candidates Match.

**Left as they were.** The three example briefs and the Boolean examples (typed into a search over English data); the industry and job-function names (stored values); "Can start: Within 15 days" and the next-role statuses ("Ready to start now", "Open to the right offer"), which are read inside a line, not tapped; the compact filter facts ("8+ yrs", "≤ 30d notice", "at JLL"); the demo candidates and the demo refusals in `talent_repository.dart`; "Search name, headline, skill, employer…".
