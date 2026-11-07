# Profile menu and Discover sheet

Two overlays that open over the shell: the **profile menu** (the drawer the header photo opens; design `docs/designs/profile-menu.png`) and the **Discover sheet** (the bottom sheet the Discover tab opens; design `docs/designs/discover-sheet.png`). Refined on 23 Oct 2026 to `docs/REFINE_BRIEF.md`.

## Wiring

```dart
// lib/app.dart (not edited by this feature)
AppShell(
  drawer: ProfileDrawer(screens: screens, onOpenCompany: …),  // screens: {'/councils': ..., '/events': ...}
  home: Builder(builder: (ctx) => HomeScreen(viewer: _viewer, onAccount: () => AppShell.openDrawer(ctx))),
  ...
  doors: screens,                              // the Discover sheet's in-app screens
)
```

* `ProfileDrawer({Map<String, WidgetBuilder> screens = const {}})` reads a `ProfileDrawerController` and the `AuthController` from Provider; `ProfileDrawerController.live({api, userId, seed})` / `.demo()`. `ensureLoaded()` runs on first build; `refresh()` reads again. **No public constructor changed.** One field was renamed, `ProfileDrawerData.chapterNames` to `chapterCities` (it holds the chapters' cities; nothing outside the feature read it).
* `DiscoverSheet({required ValueChanged<DiscoverDoor> onOpen})` (unchanged); the door's `sitePath` is the page it opens, `AppShell` decides in-app screen or website (`doors` map, else `openSitePage`).
* Goldens in `test/golden/screens_golden_test.dart`: "profile_drawer" (307 wide, the design's size) and "discover_sheet" → `build/screens/profile_drawer.png`, `discover_sheet.png`; the drawer drawn from the live API is `build/screens/profile_menu_live.png`.
* Tests: `test/profile_drawer_test.dart`, `test/discover_test.dart` (widget), `test/live/profile_menu_live_test.dart` (live, `flutter test test/live/profile_menu_live_test.dart`). The shell test that the header photo opens this menu is in `test/feed_screen_test.dart` ("inside the shell").

## The profile menu

### Endpoints

Every read fails on its own: the drawer keeps what the others returned, and a line whose read failed is simply not drawn (or shows the design's words, below), never a made-up number.

| Call | Gives |
|---|---|
| `GET /users/me/profile` | name, photo, cover (`coverImage`), `designation` (the headline under the name), verified, profile slug |
| `GET /members/:id` | the place (the city of the current role), follow counts (connections = followers + following, "500+" from 500), chapters (cities and the first one's code), councils |
| `GET /users/me/profile-performance` | "Profile Views" (`profileViewsTotal`) |
| `GET /forum/threads?authorId=<me>&limit=100` | "Post Impressions": the sum of `viewCount` over the member's discussions |
| `GET /mentorship/cpd/summary` | the "+12 CPD" pill (lifetime `totalHours`) |
| `POST /auth/logout` | Sign Out (sends the saved refresh token) |

### What the API cannot give, and what is shown instead

| Design | Shown |
|---|---|
| "500+ Connections" | the real count: followers plus following. The local database has 267 accounts that follow Bharat or that he follows, so the line reads "Bengaluru, Karnataka · 267 Connections"; at 500 or more it would read "500+" |
| "Post Impressions" | a discussion's views (the API counts no impressions) |
| "+12 CPD" | lifetime hours (`totalHours`), not this year's (`hoursThisYear`, which the Events board shows as 8.5 of 15). A member with none sees a chevron where the pill would be |
| the chapter badge "BLR" | the first chapter's city as an airport-style code (a known city) or its first three letters |
| the subtitles | "Bengaluru, Pune, New Jersey" (the chapters' cities, three at most and "& more" after), "Sustainability, ESG & Net-Zero +2" (the first council by its short name and how many more). A member with no chapter or council reads the design's own sentences ("Bengaluru, Mumbai, Delhi & more", "Sustainability, ESG & Smart PropTech") |
| the banner photo | Bharat's `coverImage`; a member with none sees the app's own banner |
| the headline and place of a member who has none | not drawn (no placeholders) |

### Seed

`tool/seed/home.ts` gives **Bharat Buyer** (the emulator's persona) the design's data: `designation` "Lead Operations Manager at TechCorp", `coverImage` `/uploads/design-home-cover_town.jpg` (the design's banner, copied into `uploads/`), a current role in Bengaluru (so the place reads "Bengaluru, Karnataka"), every active account following him and him following Marcus, Elena and ten mentors (267 connections), 42 profile-view rows, a CPD entry of 3.5 hours last year (lifetime 12 with the Events seed's 8.5), and three discussions of his own (1,204 views between them). His chapters and councils come from `events-councils.ts` (run first). What the seed changed in Bharat's row is recorded in `Setting` `design-seed:home`, so `powershell -File tool\seed\run.ps1 -Remove` (or `npx ts-node --transpile-only <path>\tool\seed\home.ts --remove` from `E:\ICR\irc-portal\backend`) puts his headline and cover back exactly as they were (verified: columns null again, follows 4, views 5, CPD 3).

### Controls and the tests that prove them

`W` = `test/profile_drawer_test.dart` (or the shell test named), `L` = `test/live/profile_menu_live_test.dart`.

| Control | What it does | Proved by |
|---|---|---|
| header photo (Home) | opens this menu | W (feed_screen_test) "inside the shell the header photo opens the real profile menu over the feed; Back closes it" |
| the photo, name, headline and place (one block; there is no "View Full Profile" button since 27 Oct 2026) | the member's own profile: the app's `/profile` screen, else the website's `/members/<slug>`; the menu closes behind it | W "there is no View Full Profile button; the photo and the name open…", "the line … under the name opens the profile too", "the photo opens the profile too", "the two counts … are plain" |
| YOUR COMPANIES (up to 3 of `GET /me/companies`, the company acted for first with an Active pill) | tap the active one: its page in the app (`ProfileDrawer.onOpenCompany`, app.dart → `openCompanyInsightsById`); tap another: it becomes the one acted for (`POST /me/companies/switch`, fresh session adopted through `CompaniesController`), the menu closes and "Now working as X." shows; "See all" (only with more than 3) opens My companies; no company: the whole block is left out, with no "Create a company" row (owner's call, 28 Oct 2026; a company is created from the account screens); a failed read, a staff account, or no account repository draws nothing; the last list shows at once on reopening (`ProfileDrawerController.cachedCompanies`) while it is read again | W group "My companies" |
| Regional Chapters | `/chapters` on the website (the app has no chapters screen) | W the same test |
| Working Councils | the app's own Councils screen; with no screen it falls back to `/councils` | W "a row the app has a screen for opens it, and the others still open the website"; W the rows test |
| Get Involved & Volunteer | `/get-involved` on the website | W rows test |
| Saved Jobs ("Saved Items & Jobs" until 5 Nov 2026, the owner's rename) | `/career/saved` | W rows test |
| Requirements (was "My RFQ Requirements" until 3 Nov 2026) | `/rfq`: the app's Requirements board, everything posted on ICR, with the member's own list (My RFQ's), Post RFQ and Find work as chips on it (owner: "whatever is posted needs to be seen"; `docs/screens/rfq.md`) | W rows test; W `test/rfq_requirements_board_test.dart` |
| Find Work & Bid | `/manage/bids`: the supplier board | W rows test |
| Certificates & Badges | `/learning/certificates` | W rows test |
| Settings | `/profile?tab=security` (the website's security settings) | W rows test |
| Sign Out | closes the menu, signs out: the saved tokens go and `POST /auth/logout` carries the saved refresh token | W "Sign Out ends the session..." (the request's body is `{refreshToken: 'refresh'}`); L "Sign Out really ends the session..." (a throwaway Pooja sign-in, then `/auth/refresh` with the old token answers 401); L "Sign Out in the menu signs a throwaway Pooja session out, and the API then refuses its token" (the same through the drawer's button) |
| every row, the menu | the menu closes before the page opens (the browser is intercepted in the tests) | W rows test (`find.byType(ProfileDrawer)` is gone after each) |
| Back | closes the menu, nothing else happens | W "Back closes the menu and nothing else happens" |
| the lines | the API's, worded as the design words them | W "the member's lines are the API's, worded as the design words them"; L "every line of the menu is read from the API..." (each compared with the raw endpoint's answer) |
| a member with nothing | the design's words and dashes, no misleading zeros | W "a member with nothing yet reads the design's own words and dashes, never zeros that mislead" |
| a failed read | the rest still fills in | W "each read fails on its own..."; L "the menu's endpoints fail on their own..." |
| a wider pill | the row's title is scaled, never cut | W "a wider pill does not cut the row's title short" |
| the data rules | connections, chapters line, councils line, CPD label, badge code, initials | W "the data" group (six tests) |

The live drawer drawn from the API: L "the menu reads as the design, with the local database's content" (writes `build/screens/profile_menu_live.png`).

### The menu for every account (the owner's drawer design, 6 Nov 2026)

Every signed-in account gets the owner's drawer design under the same header (`ProfileDrawer.workspaces` from `workspacesFor`, `lib/features/workspaces/role_workspaces.dart`): five rows — **Company**, **Marketplace**, **Mentorship**, **Learning**, **Jobs** — each its icon on a grey tile (`#F2F4F6`, Lucide at weight 500 in `#004B83`), its name (14 sp semibold) and, on the right, what is live or a chevron; the row of the bottom bar's tab on screen is filled in ICR blue with white text (`AppShell.currentTab`; none on Home). Then **Account**: My Account, Saved Items, Referrals, Settings (13 sp, plain grey icons). Sign Out stays in Settings.

What a row holds is the website's sidebar for the role (owner, 5 Nov 2026), only the pages the app shows itself (`workspaceOpens`): Company = the company's own pages for the roles that run it (My Company, products, services, offices, certifications, Team, operations) plus "My companies" for every member (where they switch, join or create one); Marketplace = My Requirements for a buyer, Find Work & Bid and Advertise for a seller, and the public boards (Browse RFQs, Supplier Mart, Companies, Products, Categories); Jobs = the hiring pages for the roles that hire (Interviews alone for a hiring manager), the job board and the member's career pages; Mentorship and Learning as before. ICR staff get their consoles (Engage, Learn, Content, Admin) and Settings alone. A row opens its pages as tabs (`WorkspaceScreen`).

What is live beside a row (`ProfileDrawerData`, each read failing on its own, nothing drawn while unread): Marketplace shows **LIVE RFQS** while `GET /rfq` has a total above zero; Mentorship shows **● Available** for a listed mentor (`mentorStatus` APPROVED) or **● Paused**; Jobs shows the board's total (`GET /jobs?limit=1&page=100000` — a page past the end, so no promoted job is served and no impression counted); Saved Items shows every kind the member bookmarked added up (`/jobs/saved`, `/mentorship/mentors/saved`, `/vendors/saved`, `/councils/saves/mine`, `/forum/saves/mine`; a kind the account cannot hold counts nothing). Referrals reads **Earn credits** — a referral earns ICR credits; the design's "Earn CPD" would promise CPD hours the programme does not give. Proved by `test/workspaces_test.dart` ("the menu", "the counts beside the rows") and `test/role_workspaces_test.dart`; drawn at the design's size by the golden "profile menu (owner's drawer design)" (`build/screens/profile_menu.png`), laid over `3.png` on 6 Nov 2026.

### A personal member's menu (4–5 Nov 2026; superseded above)

A Professional acting for no company (`isPersonalMember`) gets the website's workspace menu under the same header (`ProfileDrawer.workspaces`, `lib/features/workspaces/workspaces.dart`): **Career**, **Engage** and **Account**, each a row with its icon, its name (18 sp bold) and a chevron. A tap opens it in place — one at a time, so Mentorship, which is in both Career and Engage, is never listed twice; tapping the open one closes it; the one open is kept while the app runs (`chosenWorkspace`) — to its options on a pale `#F0F5FB` panel: a 44 dp tile in the option's colour and its name (16 sp semibold), no chevrons (Career: Mentorship, Mentor Workspace for someone who mentors, My Career, Find Work; Engage: Mentorship, Inbox, Community, Reputation; Account: Membership, Referrals). An option opens its pages as tabs (`WorkspaceScreen`), or its one page. Under a hairline, **ACCOUNT**: My Account, **Saved Jobs**, Certificates & Badges, Settings (14 sp), then Sign Out alone in the foot at 16 sp. Saved Jobs opens My Career on its Saved Jobs tab — the website's `/career/saved` is saved jobs only — not the every-kind Saved items screen the old menu's row opens. Proved by `test/workspaces_test.dart` group "the menu"; drawn on the emulator as Pooja (`professional@icr.test`) against the design on 5 Nov 2026. The design's type reads a size larger on the owner's phone, whose font setting is larger; sizes were matched to the header the design shares with the app (the name, 16 sp).

### Measurements

Text and icon bands in `build/screens/profile_drawer.png` against the design at 2x: **13 of 13 within 2 dp** (worst 2.0 dp, mean 1.23 dp). The live render has the same positions. The banner, the photo, the two counts and the three rows are at the design's coordinates (header 282.75 tall; cover 296 × 52 at 12 from the top; photo at 20, 26; rows 4 dp apart).

Deviation that remains: the design's drawer shows a different photo from its Home header photo; the app uses the member's one profile photo in both.

## The Discover sheet

The design's four association doors in two rows (each door its whole box), then — since 3 Nov 2026, the owner's call that the website's menu should show in the app — **the website's Discover menu**: its "Create a Company Page +" link, the "For Business" rule, the five actions of its "Explore more for business" list in its order and words with their captions (Hire Facility Managers → `/talent`, the talent search, the one page the app opens in its web view; Post a Job → the app's job composer; Sell on Supplier Mart → the Marketplace; Post RFQ / Requirement → the app's requirement form; Advertise Commercial Space → the app's Advertise screen), and its Enterprise spotlight card, whose "Get Premium Access →" opens the plans. The sheet is 590 dp tall and scrolls inside that on a short phone.

| Door | Opens |
|---|---|
| Regional Chapters | `/chapters` on the website |
| Working Councils | the app's Councils screen (`/councils` in `doors`) |
| Digital Library | `/documents` on the website |
| Events | the app's Events board (`/events` in `doors`) |
| Hire | `/account/companies/new?role=COMPANY_ADMIN` |
| Sell | `/account/companies/new?role=VENDOR` |
| Post requirement | `/rfq/new` |
| Advertise | `/advertise` |

Tapping a door closes the sheet first; Back from an in-app screen returns to the shell. The sheet closes on a tap on the page behind it, on a long drag down (a short one springs back), on the Discover tab again or another tab, and on Back.

| Control | Proved by (`test/discover_test.dart`) |
|---|---|
| Discover tab opens, Back closes | "Discover opens the sheet over the tab, and Back closes it" |
| tab toggles, another tab closes | "the Discover tab toggles the sheet and another tab closes it" |
| tap behind closes; with the sheet closed the tab gets every tap | "tapping the page behind the sheet closes it", "with the sheet closed the tab gets every tap" |
| the four doors, the company link, the For Business rule, the five actions with captions, the spotlight | "the sheet has the design's four doors, then the website's business menu, in its order" |
| each door's artwork is bundled | "each door's artwork is a bundled picture" |
| Councils, Events (in-app, Back returns, nothing to the browser) | "Councils and Events open the app's own screens; Back brings the shell back each time"; "a door with an in-app screen opens it, and Back returns to the shell" |
| every door's target is the website's own path, query and all (the app resolves each to its screen; the sheet closes) | "every other door opens its page on the website, query and all, and closes the sheet" |
| a door's whole box | "a door's whole box is the target, not only its words" |
| long drag closes, short drag springs back | "dragging the sheet down closes it, and a short drag settles back open" |
| a screen a door opened can open the profile menu | "a screen a door opened can open the profile menu, which leaves it first" |

The Discover sheet reads no API, so it has no live test; the website paths it opens are the ones the profile menu's live test and the other screens already use.

Band check against `docs/designs/discover-sheet.png`: **6 of 6 within 1 dp** (mean 0.17 dp). The sheet did not need to change.

**6 Nov 2026 (evening):** the Company row shows only for a member acting for a company (`user.companyId != null`) or staff; a member acting as themselves gets the website's "Do more on ICR" block instead (`startDoorsFor`: Create a company, Hire people, Sell to FM buyers, Find suppliers, Become a mentor — the last only for someone who may, `canOfferToMentor`), and "My companies" is the last tab of the Account row for everyone. Account is a main row (Membership, My membership, What my plans include, Refer a friend, Credits & redemptions, My companies). The menu is drawn LinkedIn-like: white, plain icons, no tiles, no fill on the current row (its words in ICR blue), a thin line between rows and a small-caps heading over each block; the two counts under the name have no box.

**6 Nov 2026 (night):** each row is a dropdown: its tap lists its pages under it (one row open at a time, chevron down), and a page opens the module on that tab (`onOpenSection(section, index)`). Under the rows only Saved Items and Settings remain; the plans and Refer & Earn are the Account row's pages (its pill reads "Earn credits"). Learning lists the hub, My courses (the hub on its My-courses chip, `/learning?mine=1`), My attempts, Certificates & Badges, then the catalogues; Mentorship adds, for a mentor, the website's Mentor workspace rows (Mentor dashboard, Offerings, Engagements, Availability) or, for an applicant, My mentor profile.

**6 Nov 2026 (late) — the owner's role table.** The rows and their pages now follow the table the owner sent, in its order, instead of the website's sidebar (`workspacesFor` in `lib/features/workspaces/role_workspaces.dart`; `test/role_workspaces_test.dart`):

| Who | Row | Pages (in order) |
|---|---|---|
| every member | Jobs | My applications, My saved jobs, Search jobs |
| | Learning | My courses (`/learning?mine=1`), My attempts, My certificates |
| | Mentorship | My sessions (`/mentorship/my?tab=calendar`), Search mentors |
| | Marketplace | Post a requirement (`/rfq/new`), Search suppliers (`/vendors`) |
| + a mentor (approved or paused) | Mentorship adds | Mentor dashboard, Mentor offerings (`/mentorship/mentor?tab=services`); an applicant sees My mentor profile instead |
| + acting for a company, hiring role (company admin, recruiter, office admin) | Jobs adds, first | Post & manage jobs, Assign team & add members (`/manage/team`), Create a project |
| + acting for a company, a role that runs it | Company | Add members; seller (admin, VENDOR): Add services, Add products, Bid for enquiries & RFQs (`/manage/bids`); buyer (admin, VENDOR, BUYER): View enquiries & RFQs (`/manage/requirements`); BUYER also My Organization, recruiter/office admin also My Locations |
| + a partner institute's staff (`SessionUser.learningRoles` non-empty — `UserDto.learningRoles`, given only while the company is a partner) | Partner Institute | Publish a course, Publish a batch, Enquiries, Add a team member, Add a trainer, Add a programme specialist |
| every member | Account | Membership, My membership, What my plans include, Refer a friend, Credits & redemptions, My companies |

A hiring manager keeps Interviews alone under Jobs and no Company row; a plain PROFESSIONAL at a company gets no Company row. Rows list only pages the app has a screen for (`workspaceOpens`), so today **Add services, Add products, Create a project and every Partner Institute page but Enquiries (native since 7 Nov 2026, `partner_enquiries.md`) and the team rows are hidden** until their native screens exist (they would open the website otherwise). Staff rows (SUPER_ADMIN, LEARNING_ADMIN, PARTNER_ADMIN) are unchanged. Saathi's chips on a page without a module follow the same role (`suggestionsFor`, `AssistantContext.mentor`): a mentor's Mentor dashboard + My offerings, Post a job for a hirer, Enquiries & RFQs for a seller, Post a requirement for a buyer; a member whose role brings nothing gets Dashboard, so there are always at least four.

**Learning › My courses is the page alone** (owner, 6 Nov 2026: "My courses means only the courses which are enrolled, not the Learning page"): `/learning?mine=1` opens `MyCoursesScreen` (`lib/features/learning_hub/my_courses_screen.dart`) — the course grid with its My courses chip on, what the member holds under the website's headings (Mock Exams, Assess Your Knowledge, Flash Cards, ICR Courses, Partner Courses) — with no hub, Catalogue or rows around it; it is the same page the hub's "My courses · View More" opens. `LearningHubScreen` no longer takes `mineOnly`.


**6 Nov 2026 (the doors against the website):** checked the drawer's "Do more on ICR" block, the Discover sheet's business doors and Saathi's chips against `DIRECTION_INTENTS` / `isUndecidedPerson` (`features/onboarding/intents.ts`), `WelcomeCard` / `ExploreServicesCard`, `DISCOVER_BUSINESS` (`lib/nav.ts`) and `UNDECIDED_MEMBER_SUGGESTIONS` (`packages/shared/src/assistant.ts`). Who sees the doors already matched (`startDoorsFor`: no staff role, no company in use; a member acting for a company has its workspace instead); what changed is the words: each door's caption is now the website's own line (Hire people "Create your company page, then post a job.", Sell to FM buyers "Create your company page, then list your services.", Find suppliers "Search verified suppliers and ask for quotes.", Become a mentor "Share your expertise with the next generation."). The set stays Create a company (the app's own first door), Hire, Sell, Find suppliers and Become a mentor (only when `canOfferToMentor`: never applied, mentors no one, not SUPER_ADMIN); the website's other three doors (Find work, Learn and get certified, Find a mentor) are the menu's Jobs, Learning and Mentorship rows. Hire and Sell open the create-company screen (`?role=COMPANY_ADMIN` / `?role=VENDOR`, a query the website's page itself ignores), Find suppliers the Supplier Mart. Nothing offers to register for a role only a team invite gives (recruiter, hiring manager, office admin, partner administrator; `INVITE_ONLY_ROLES`): the job composer's gate already says "ask its admin to make you a recruiter". The Discover sheet gates nothing itself, as the website's menu does: Hire = Post a Job (`/manage/jobs/new`), Sell = Sell on Supplier Mart (`/vendors`), Post requirement (`/rfq/new`), Advertise (`/advertise`); each page asks for a company or a role itself. Saathi's chips for a member with no company already ask the website's four questions. Open: an admin of an approved partner company sees no Partner Institute row until `SessionUser` carries `learningPartner` (see `learning_hub.md`, "Partner application").
