# Company — Projects

The website's `/manage/projects` (the list, `ProjectsInner` + `CreateProjectDialog`) and `/manage/projects/[id]` (the project page,
`ProjectInner` + `CandidateRow`), drawn by the app since 12 Nov 2026 as "Projects" under Jobs in the drawer. The owner's instruction:
"take the reference of the Web and do as it is" — the fields, the list, the flows and the empty states are the website's, in the
app's look (white, hairlines between full-width rows, nothing boxed).

Sourcing projects are a hiring team's talent pools: people shortlisted before they apply, outside any single job.

**The list reads in the owner's words, not the website's** (05-company-workspace.docx, screen 012-manage-projects, 12 Nov 2026 — "Use
Talent Sourcing Projects instead of just Sourcing Projects"):

| Where | Website (was) | Now |
|---|---|---|
| Heading (title bar) | Sourcing projects (app bar: "Projects") | **Talent Sourcing Projects** |
| Description | Talent pools that live outside any single job — shortlist people before they apply. | Build and manage talent pools beyond individual job openings. Identify, engage and shortlist candidates for current and future hiring needs. |
| CTA | + New project | **+ Create Project** |
| Search placeholder | Search projects… | Search projects by name or role… |
| Filters | Only mine · Show archived | **My Projects** · **Show Archived** |
| Empty state | No projects yet / Create a project to collect candidates for a role you're building a bench for. | **No Sourcing Projects Yet** / Create your first project to build a talent pool and shortlist candidates for upcoming or recurring hiring needs. + **Create Your First Project** |
| No-company note | Sourcing projects / Sourcing projects belong to a company. | Talent Sourcing Projects / Talent sourcing projects belong to a company. |

The whole heading is in the `TitleBar` (it fits a 360 dp bar; a test pins that it ends before the bell); inside a workspace tab the bar
draws no title, as everywhere, and the tab names the page. **The search placeholder promises more than the API does:** `GET /projects`
matches the project's *name* only (`ProjectsService.list`, `name contains`), so a role typed there finds a project only when its name
carries it. Matching the criteria' titles needs a portal change.

## What it shows

`lib/features/projects/` — `project_models.dart`, `projects_repository.dart` (`ApiProjectsRepository`, `DemoProjectsRepository`),
`projects_controller.dart` (`ProjectsController` for the list, `ProjectController` for one project), `projects_screen.dart`
(`ProjectsScreen`), `project_screen.dart` (`ProjectScreen`), `project_sheet.dart` (the create / edit form), `project_rows.dart`
(the rows, the tabs, the notice).

### The list (`ProjectsScreen`)

- `TitleBar` "Talent Sourcing Projects" (back, bell). Under it the description, full width, then **+ Create Project** (under it, not
  beside it: the description is too long to share a 360 dp row), the search ("Search projects by name or role…", settles 300 ms) and the
  website's two switches as toggle chips: **My Projects** (the API's `mine`), **Show Archived** (`includeArchived`).
- Reads `GET /projects?page=&limit=20&search=&mine=&includeArchived=` (by last change; the API shows the company's projects minus
  other people's PRIVATE ones, and an office-scoped role only its office's — the app sends nothing for that, the API decides). More
  pages load as the list is scrolled.
- One row per project, as the website's card: the name and a **Private** chip; "Sourcing for {job}"; the description (two lines);
  then the chips — "{n} candidates", each stage with people in it ("Sourced 2", "Contacted 1" …), **Archived**. An archived project is
  drawn at 65 % like the website's card.
- Empty: "No Sourcing Projects Yet" / "Create your first project to build a talent pool and shortlist candidates for upcoming or
  recurring hiring needs." with **Create Your First Project** (opens the same sheet). A search or My Projects that finds nothing is not
  that state (the company may have projects): it says "No projects match" / "Try another name, or clear the filters." and offers no
  first-project button. A failed read: the API's sentence with Try again.
- **Who reaches it.** The website gates the page on `RECRUITER_TIER` (Super Admin, Company Admin, Branch Admin, Recruiter) and, for
  anyone but ICR staff, on a company to act for (`lacksCompany` → `NoCompany`). The app's `ProjectsViewer` reads the signed-in session:
  acting for no company → the calm note "Talent sourcing projects belong to a company." with **Create a company** when the lead wires
  `onCreateCompany`; a role outside the tier → "This page is for your company's hiring team"; ICR staff reach the list with no company.

### + Create Project (`showProjectSheet`)

The website's "New sourcing project" dialog as an `EditSheet`, its fields in its order: **Project name** (required, 2–120), **Description
(optional)**, **Visibility** (Private — only me / Team — anyone with recruiter access; Team by default), **Sourcing for a job (optional)**
("Not tied to a job", else one of the company's jobs from `GET /jobs/company?limit=50`), then *Ideal candidate*: **Job titles**, **Skills**,
**Locations** (comma separated, split and trimmed as the website's `csv`) and **Minimum years**. Create is disabled until a name is typed.
Sends `POST /projects` with the website's body — blank optional fields left out, the three lists always sent. A refusal is shown in the
sheet and the form keeps what was typed; the new project heads the list.

### The project page (`ProjectScreen`)

- `TitleBar` "Project"; the heading is the project's name and the website's subtitle (the description, else "Sourcing for {job}", else
  "Sourcing project"); **Archive** / **Un-archive** (`PATCH /projects/:id { archived }`, the website's one button); a menu with **Edit
  project** and **Delete project**; then the chips — the visibility label, the job (opens the job through `onOpenJob` when the lead
  wires it), and each criterion ("Title: …", "Skill: …", "Location: …", "5+ yrs", the seniority, the work mode).
- Reads `GET /projects/:id` and `GET /projects/:id/candidates?limit=100` together.
- **Pipeline ({count})** tab: the roster by board stage — Sourced, Contacted, Replied, Shortlisted, each with its count ("Nobody here
  yet." when empty) — and **Archived** under them when anyone is there. A candidate row is the website's: photo, name, the
  "Applied to {job} · {stage}" chip when the row points at an application the reader may open (opens the job through `onOpenJob`), the
  company's tags, the headline, the grey line (company · location · "7 yrs" · "30d notice" / "Immediate"), the note. The arrow moves
  them to the next stage; the menu moves them to any other stage or removes them (`PATCH …/candidates/:candidateId { stage }`,
  `DELETE …/candidates/:candidateId`). Empty: "No candidates yet" / "Use “Find candidates” to add people who match this project's
  criteria, save them from talent search, or add applicants from a job's pipeline."
- **Find candidates** tab (read when first opened, `GET /projects/:id/matches?limit=12`): the website's note ("Candidates matching this
  project's criteria, excluding anyone already saved. These are rule-based filters, not an AI ranking."), one row per match (photo,
  name, headline · company · location) with **Save** (`POST /projects/:id/candidates { candidateId }`); a saved person leaves the
  matches and joins Sourced, every Save is disabled while one is on its way, and a refusal (the plan's saved-candidate number) sits
  above the matches as the website's warning, dismissable. Empty: "No matches" / "Loosen the project's criteria, or add candidates from
  talent search."
- Leaving the page tells the list what changed (`onChanged`): the row is replaced, dropped when archived with Show Archived off, or
  removed when deleted.

### Edit and Delete

The website has **no edit dialog and no delete button** for a project: its page only archives and un-archives (its `useDeleteProject`
hook exists and is used nowhere). The lead asked for both, and the API has them (`PATCH /projects/:id` takes every field of the form,
`DELETE /projects/:id` soft-deletes), so the app offers them in the page's menu: **Edit project** opens the same sheet over the project
and sends only the fields that changed (a cleared optional field goes as `null`); **Delete project** asks first ("Delete {name}?" —
the project and its saved candidates are removed; nobody's application is touched) and returns to the list. Both are one menu in
`project_screen.dart` and go if the owner wants the page kept to the website's archive-only flow.

## Left out, and why

- **Pagination controls**: the website pages 12 cards with a `Pagination`; the app loads more as the list is scrolled (the app's list
  idiom).
- **Links to the ATS pipeline**: the website's job chip and "Applied to" chip open `/manage/jobs/:id/pipeline`; the app has no
  pipeline screen, so both take an `onOpenJob` callback (the lead wires it to the job opener) and are plain when none is given. Nothing
  opens the website.
- **Seniority, work mode, employment type in the form**: the API accepts them, but the website's dialog does not ask them, so the app's
  form does not either; the page shows them as chips when set (as the website does).
- **Adding applicants from a job's pipeline** (`POST /projects/:id/applicants`, the ATS's `AddToProjectDialog`) and **saving from
  talent search** (`TalentBulkBar`): they live on the website's pipeline and talent-search pages, which the app does not draw.
- **The office picker** (`branchId`): the website's dialog has none; the API files a project under the creator's office itself.

## Tests

`test/projects_test.dart` (28, against `DemoProjectsRepository`): the owner's wording (heading, description, "+ Create Project", the
search placeholder, My Projects / Show Archived, none of the old words left) and the heading fitting a 360 dp title bar; the empty state's
words and its Create Your First Project creating a project, and a search with no hits not showing it; the rows with their counts and the archived row dimmed, Show
Archived and My Projects, the search and its empty state, a failed read, the no-company and no-access notes, ICR
staff; the sheet's fields and the exact body sent (blank optional fields left out), a refusal kept in the sheet; the page's heading,
chips and roster by stage, the job chips opening through `onOpenJob`, the arrow and menu moves and a removal with the count following,
Find candidates with Save (the match leaves, the count follows, the person appears in Sourced), a refused save as the warning, no
matches; Archive's patch and the list dropping the row; Edit sending only what changed (`jobId: null`, `minYears: null`); Delete asking
first (Cancel sends nothing) and returning to the list; a page that cannot be read; and the model (the API's project, a draft's
changes, the candidate's meta line and "Applied to" chip).

## 13 Nov 2026: copy refined to the client's standard

The list, the project page and the create/edit sheet (`lib/features/projects/`). Wording only: no layout, colour or behaviour changed. The rules are the client's marked-up manual of 13 Nov ("refine text and make it crisp for global standard"): Title Case for what is tapped or read as a label, sentence case with a full stop for sentences, plain international English, no dash inside a sentence, one term for one thing.

| Where | Was | Now |
|---|---|---|
| `project_models.dart` | Private — only me | Private (Only Me) |
| `project_models.dart` | Team — anyone with recruiter access | Team (Anyone with Recruiter Access) |
| `project_screen.dart` | Project un-archived. | Project unarchived. |
| `project_screen.dart` | are removed from | will be removed from |
| `project_screen.dart` | your company’s projects. Nobody’s application is touched. | your company’s projects. No applications are affected. |
| `project_screen.dart` | Could not load the project. | Unable to load the project. |
| `project_screen.dart` | Nobody here yet. | No candidates in this stage yet. |
| `project_screen.dart` | Loosen the project's criteria, or add candidates from talent search. | Broaden the project's criteria or add candidates from talent search. |
| `project_screen.dart` | Un-archive | Unarchive |
| `project_sheet.dart` | Not tied to a job | Not Linked to a Job |
| `project_sheet.dart` | Could not save the project. | Unable to save the project. |
| `project_sheet.dart` | Could not create the project. | Unable to create the project. |
| `project_sheet.dart` | Regional FM Managers — West | Regional FM Managers, West |
| `project_sheet.dart` | Choose | Select |
| `project_sheet.dart` | Comma separated | Separate with commas. |
| `projects_repository.dart` | Could not load projects. | Unable to load projects. |
| `projects_screen.dart` | Talent sourcing projects are run by company admins | Talent sourcing projects are managed by company admins |
| `projects_screen.dart` | No projects match | No Matching Projects |
| `projects_screen.dart` | Try another name, or clear the filters. | Try another name or clear the filters. |

**To Title Case, words unchanged (19 strings):** Mid-level → Mid-Level; On-site → On-Site; More actions → More Actions; Remove from project → Remove from Project; Find candidates → Find Candidates; No candidates yet → No Candidates Yet; Use “Find candidates” to add → Use “Find Candidates” to add; No matches → No Matches; Edit project → Edit Project; Delete project → Delete Project; Sourcing for a job → Sourcing for a Job; New sourcing project → New Sourcing Project; Project name → Project Name; Description (optional) → Description (Optional); Sourcing for a job (optional) → Sourcing for a Job (Optional); Job titles → Job Titles; Minimum years → Minimum Years; Create a company → Create a Company; This page is for your company’s hiring team → This Page Is for Your Company’s Hiring Team.

**Left as they were.** Everything in the owner's table of 12 Nov above ("Talent Sourcing Projects", the description, "Create Project", "Search projects by name or role…", "My Projects", "Show Archived", "No Sourcing Projects Yet" and its sentence, "Create Your First Project", "Talent sourcing projects belong to a company."); the stage names; "Try again"; the criteria chips ("Title: …", "Skill: …", "5+ yrs"); the demo projects and candidates in `projects_repository.dart` (so the demo project is still named "Regional FM Managers — West"; only the name field's example changed).
