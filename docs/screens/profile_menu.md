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
| YOUR COMPANIES (up to 3 of `GET /me/companies`, the company acted for first with an Active pill) | tap the active one: its page in the app (`ProfileDrawer.onOpenCompany`, app.dart → `openCompanyInsightsById`); tap another: it becomes the one acted for (`POST /me/companies/switch`, fresh session adopted through `CompaniesController`), the menu closes and "Now working as X." shows; "See all" (only with more than 3) opens My companies; no company: only "Create a company" → `CreateCompanyScreen`; a failed read, a staff account, or no account repository draws nothing; the last list shows at once on reopening (`ProfileDrawerController.cachedCompanies`) while it is read again | W group "Your companies" |
| Regional Chapters | `/chapters` on the website (the app has no chapters screen) | W the same test |
| Working Councils | the app's own Councils screen; with no screen it falls back to `/councils` | W "a row the app has a screen for opens it, and the others still open the website"; W the rows test |
| Get Involved & Volunteer | `/get-involved` on the website | W rows test |
| Saved Items & Jobs | `/career/saved` | W rows test |
| My RFQ Requirements | `/manage/requirements` | W rows test |
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

### Measurements

Text and icon bands in `build/screens/profile_drawer.png` against the design at 2x: **13 of 13 within 2 dp** (worst 2.0 dp, mean 1.23 dp). The live render has the same positions. The banner, the photo, the two counts and the three rows are at the design's coordinates (header 282.75 tall; cover 296 × 52 at 12 from the top; photo at 20, 26; rows 4 dp apart).

Deviation that remains: the design's drawer shows a different photo from its Home header photo; the app uses the member's one profile photo in both.

## The Discover sheet

Eight doors in four rows, the design's order, with a "For Business" rule between the pairs; each door is its whole box.

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
| eight doors in order, the For Business rule | "the sheet has the eight doors in the design's order..." |
| each door's artwork is bundled | "each door's artwork is a bundled picture" |
| Councils, Events (in-app, Back returns, nothing to the browser) | "Councils and Events open the app's own screens; Back brings the shell back each time"; "a door with an in-app screen opens it, and Back returns to the shell" |
| Regional Chapters, Digital Library, Hire, Sell, Post requirement, Advertise (website URL, query and all, sheet closes) | "every other door opens its page on the website, query and all, and closes the sheet"; "each door names the page it opens on the website" |
| a door's whole box | "a door's whole box is the target, not only its words" |
| long drag closes, short drag springs back | "dragging the sheet down closes it, and a short drag settles back open" |
| a screen a door opened can open the profile menu | "a screen a door opened can open the profile menu, which leaves it first" |

The Discover sheet reads no API, so it has no live test; the website paths it opens are the ones the profile menu's live test and the other screens already use.

Band check against `docs/designs/discover-sheet.png`: **6 of 6 within 1 dp** (mean 0.17 dp). The sheet did not need to change.
