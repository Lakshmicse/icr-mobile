# Manage Chapters and Manage Councils

The staff console for chapters and councils, native in the app (13 Nov 2026). On the website this is
`/admin/community` — the **Chapters**, **Councils** and **Applications** tabs — for staff holding
`chapters:manage` or `councils:manage`: a Super Admin, or anyone given the Chapters Admin, Councils Admin or
Community Manager role. Nothing here opens the website.

Code: `lib/features/community_manage/`. Tests: `test/community_manage_test.dart` (40 tests, a memory repository
and the `FakeApi` harness). Events management is a separate feature (`lib/features/events_manage/`).

## Entry points (what the lead wires)

```dart
ManageChaptersScreen({
  super.key,
  required CommunityManageRepository repository,
  required bool everywhere,            // the key is held over every chapter (hasPermissionEverywhere)
  required VoidCallback onBack,
  VoidCallback? onBell,                 // the app's notifications when null
  int unread = 0,
  String? initialSearch,                // the website's ?search=
  String? initialTab,                   // 'applications' opens that tab
  String? focusApplicationId,           // ?application=<id>: opens the tab, tints the row, scrolls to it
  Widget Function(Widget page)? pageWrap,
  ManagePickers pickers = const ManagePickers(),                    // tests
  Duration searchDelay = const Duration(milliseconds: 350),         // tests
})

ManageCouncilsScreen({ ...the same, with focusProposalId; initialTab 'proposals' (or the website's 'applications') })

ManageChapterScreen({
  super.key,
  required CommunityManageRepository repository,
  required String chapterId,
  required bool everywhere,
  required VoidCallback onBack,
  VoidCallback? onBell,
  int unread = 0,
  Widget Function(Widget page)? pageWrap,   // carried only: the page pushes none, its forms are sheets
  AdminChapter? initial,                    // the row the list already read, drawn at once
  ManagePickers pickers, Duration searchDelay, DateTime Function() now,     // tests
})

ManageCouncilScreen({ ...the same, with councilId and AdminCouncil? initial })

ApiCommunityManageRepository({required ApiClient api})   // implements CommunityManageRepository
repository.mayManageChapter(id) / mayManageCouncil(id)   // 200 on GET /:kind/:id/content → true; 401/403/404 → false
MemoryCommunityManageRepository()                        // sample data kept in memory: the demo build and tests
```

The list screens push a record's manage page with `AppShell.push(context, (_) => pageWrap(page))`. Every form
(create, edit, add, decide) is a sheet over everything (`showEditSheet` / `EditSheet`, the app's own), so the
keyboard never meets the bottom bar.

## Screens and what they port

| App | Website | Notes |
|---|---|---|
| `ManageChaptersScreen` → **Chapters** tab (`OrgListTab`, `OrgRow`) | `admin/community/page.tsx` `ChaptersTab` | Search by name or city (asked of the API once typing rests), 20 to a page with Previous/Next, each row: name, "Regional chapter · City · Region · Country", "128 members · 3 upcoming events", Published / Hidden. The whole row opens the chapter's manage page — the website's three row icons (Manage content, Edit, Retire) live there. "New Chapter" only when `everywhere`. |
| `ManageChaptersScreen` → **Applications** tab (`RequestsTab`) | `ApplicationsTab.tsx` `ChapterApplications` + `DecideDialog` | The state filter (To review · Approved · Declined · Withdrawn), each application in full (kind, who, where, when, LinkedIn, "Why, and what the chapter would do", "Experience"), the outcome with its reason and "Result: … Find It" (opens the Chapters tab searched by that name), Decline and Approve on the ones waiting. |
| `ManageCouncilsScreen` → **Councils** tab | `page.tsx` `CouncilsTab` | Search by name or focus; row: name, segments, members, Published / Hidden. "New Council" only when `everywhere`. |
| `ManageCouncilsScreen` → **Proposals** tab | `ApplicationsTab.tsx` `CouncilProposals` + `DecideDialog` | Focus, Objectives, segments, "Why ICR needs it"; Decline and Approve. |
| `ManageChapterScreen` (`OrgRecordPage`) | the row's `ChapterDialog`, `ChapterContentDrawer` and Retire | Details with **Edit**; then **Sponsors**, **Resources**, **Updates**, **Leadership**, **Members**; **Retire Chapter** at the foot (asked first; only when `everywhere`). |
| `ManageCouncilScreen` (`OrgRecordPage`) | `CouncilDialog`, `CouncilContentDrawer` and Retire | The same without Sponsors and without Add Leader (the API has neither for a council). |
| `ChapterSheet` (`org_sheets.dart`) | `OrgUnitDialogs.tsx` `ChapterDialog`, `ChapterPlaceFields`, `AboutFields`, `aboutSections.ts`, `GalleryUploadField`; `ChapterImageDialog` | Name, Chapter Type (Country-wise / Regional), City (search: ICR's cities, then anywhere; the pick fills state and country) or Country, Founded Year, Short Description, About as five fields (Mission, Vision, What we do, Membership benefits, Industries served; text outside them is kept), Banner, Chapter Picture, Gallery Images (up to 8), Contact Email, Published. No slug: the API makes it from the name. |
| `CouncilSheet` | `CouncilDialog` | Name, Slug (follows the name on a new council until typed), Member Segments (chips), Focus Line (defaults to the segments), Description, About (Mission, Vision, Objectives, Member benefits, Industries covered), Cover, Gallery Images, Contact Email, Published. |
| `showSponsorSheet` | drawer `SponsorsTab` | Name, Logo URL (or a picture uploaded from the phone), Tier, Website URL. |
| `showResourceSheet` | drawer `ResourcesTab` | Title, Kind (Presentation, Whitepaper, Recording, Template, Resource), Size Label, URL. |
| `showAnnouncementSheet` | drawer `AnnouncementsTab` ("Updates") | Title, Body, Pinned. |
| `showAddLeaderSheet` | `AddLeaderForm` | People by name or email (2 letters or more), the "not a member yet… joins them" note, Title, LinkedIn URL. Chapters only, and only when `everywhere`. |
| `showLeadSheet` | `LeadershipEditor` (a lead's card) | Title, LinkedIn URL, Term Starts, Term Ends ("Leave empty for an open term"), Save; **Step Down** (asked first). A run-out term shows "Term ended" on the row. |
| `showMakeLeadSheet` | `LeadershipEditor` "Make a member a lead" | Member, Term Starts (today), Term Ends. |
| `showDecideSheet` | `DecideDialog` | The website's sentences; "Reason (required)" to decline, "Note to the Member (optional)" to approve. |

State is repository → controller (`ChangeNotifier`) → screen: `OrgListController<T>`, `RequestsController<T>`,
`OrgRecordController` (`community_manage_controllers.dart`). A controller's `start()` (called from `initState`)
notifies no one until its first answer.

## Endpoints

| Call | Used for | Scoped grant? |
|---|---|---|
| `GET /chapters/admin?page&limit=20&search` | the Chapters list; `limit=100` pages to find one chapter by id (there is no staff read of one) | yes: the holder's chapters |
| `GET /councils/admin?page&limit=20&search` | the Councils list; one council by id | yes |
| `POST /chapters` · `POST /councils` | New Chapter / New Council | **everywhere only** |
| `PATCH /chapters/:id` · `PATCH /councils/:id` | Edit | yes |
| `DELETE /chapters/:id` · `DELETE /councils/:id` | Retire (soft delete) | **everywhere only** |
| `GET /chapters/:id/content` · `GET /councils/:id/content` | sponsors, resources, updates, leads, members; also `mayManageChapter` / `mayManageCouncil` | yes |
| `POST /chapters/:id/sponsors` · `DELETE /chapters/:id/sponsors/:sponsorId` | Sponsors | yes |
| `POST /:kind/:id/resources` · `DELETE /:kind/:id/resources/:resourceId` | Resources | yes |
| `POST /:kind/:id/announcements` · `DELETE /:kind/:id/announcements/:announcementId` | Updates | yes |
| `GET /chapters/:id/lead-candidates?search` | Add a Leader's search | **everywhere only** |
| `POST /chapters/:id/leads` | Add a Leader | **everywhere only** |
| `PATCH /:kind/:id/members/:userId` | a lead's title, LinkedIn and term; Step Down (`role: MEMBER`); Make Lead (`role: LEAD` + term) | yes |
| `GET /admin/chapter-applications?status&page&limit=20` · `POST /admin/chapter-applications/:id/decide` | Applications | **everywhere only** |
| `GET /admin/council-proposals?status&page&limit=20` · `POST /admin/council-proposals/:id/decide` | Proposals | **everywhere only** |
| `POST /uploads?purpose=chapter-cover \| chapter-logo \| chapter-gallery \| council-cover \| council-gallery \| chapter-sponsor` | pictures (stored publicly; the same multipart path as the partner console's `UploadField`) | — |
| `GET /locations/cities` · `GET /locations/search?q=` | the chapter's city search | — |

"Everywhere only" is the API's own rule: those routes carry no `@ScopedBy`, so a key held over some records counts
for nothing there (403, "Your role doesn't reach this record…"). The app follows it: no New, no Retire and no Add
Leader without `everywhere`; the Applications / Proposals tab stays (a tab does not come and go) and shows the
API's sentence.

## Rules the forms hold to (from the DTOs)

`community_manage_rules.dart`, pinned by the `rules` tests.

- Chapter (`CreateChapterDto`): name required, ≤120; a regional chapter needs its city and a country-wise one its
  country (≤80 each); founded year a whole number ≥1900; description ≤4,000; About HTML ≤20,000; contact email a
  valid address.
- Council (`CreateCouncilDto`): name and slug required, ≤120; focus ≤160; description ≤4,000; contact email valid.
- Sponsor: name required ≤120, tier ≤40. Resource: title required ≤160, URL required, size label ≤40, kind one of
  the five. Update: title required ≤160, body required ≤4,000.
- Lead: title ≤120, LinkedIn ≤300, and a term cannot end before it starts (the API's "A term can't end before it
  starts.").
- Decision: declining needs a reason; either ≤1,000.
- Pictures: PNG, JPG or WEBP; the banner, picture and cover ≤5 MB, a gallery image ≤10 MB, 8 gallery images.

Anything the API still refuses is shown in its own `message`, in the sheet, with what was typed kept.

## Where the app differs from the website, and why

- **One manage page per record** instead of three row icons: a phone row has one action area (the owner's rule),
  so the row opens the page and Edit, the content sections and Retire are on it.
- **Banner, chapter picture and council cover are in the edit form.** On the website the banner and picture are
  edited from the public chapter page's hero (`ChapterImageDialog`), not the console dialog; the council cover has
  no website editor at all, though `CreateCouncilDto.coverUrl` takes one. A picture is sent only when it changed;
  `''` removes it.
- **Clearing a field clears it.** The website sends `undefined` for a blank description, contact email or founded
  year, so an edit cannot empty them; the app sends `null` for a field that held a value and is now blank (the DTO's
  `@IsOptional` lets it through and Prisma stores null).
- **Removing a sponsor, resource or update asks first** (the website removes on the click).
- **A sponsor's logo can be uploaded** from the phone as well as pasted as a link.
- **Country picker**: ICR's thirteen markets, and any other country by typing its name (the website lists every
  country from `libphonenumber-js`, which the app does not carry).
- **The council's slug** is slugified on Save, not on every keystroke (the website's field cannot hold a trailing
  hyphen while typing).

## Not ported

- **`TranslationsPanel`** (the staff translation console inside the two dialogs) — out of scope by the brief; the
  staff consoles are English.
- **Image cropping** (`useImageCrop`: 4:3 for the gallery, 4:1 for the banner, round for the picture; "Adjust
  crop"). The app has no crop tool; a picture is sent whole, shrunk only when it is over the size limit
  (`fitForUpload`). The public pages crop with `object-fit: cover`, so nothing breaks, but the framing is not
  chosen.
- **Country flags** in the country list (flagcdn images on the website).
- **Several gallery images in one pick**: the phone's picker returns one picture at a time, so "Add Image" adds one.

## API behaviour worth knowing

- **A council's About is never saved.** `CreateCouncilDto` / `UpdateCouncilDto` have no `aboutHtml`, and the API's
  validation pipe strips what a DTO lacks, so the website's council dialog — and this sheet, which sends the same
  body — loses the five About fields silently. The staff list still returns `aboutHtml`, so the fix is one field on
  the DTO; the app needs no change when it lands.
- **Add a Leader needs the key everywhere** (`lead-candidates` and `POST leads` are not `@ScopedBy`), though a
  scoped Chapters Admin may still make a member a lead (`PATCH members/:userId` is scoped).
- **Applications and proposals need the key everywhere**, lists and decisions alike.
- There is **no staff read of one chapter or council** (`GET /chapters/:slug` is the public page: published only,
  by slug). The manage page reads the staff list a hundred at a time until the id turns up.
- `PATCH /councils/:id/members/:userId` writes `title` and `linkedinUrl` even when they are not sent (the chapter
  twin guards on `undefined`); Step Down and Make Lead on a council therefore send only `role` and the term, as the
  website does, and rely on Prisma ignoring `undefined`.
