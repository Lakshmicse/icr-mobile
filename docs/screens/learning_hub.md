# Learning hub

The Learning tab, built to the owner's **Learning hub** export of 30 Oct 2026 (`docs/designs/learning-hub-v2.png`: a 390 × 2194 dp frame at 1x in a 504 × 2224 file, with the rule *"a single view — most of the data should be visible without scrolling"*). Before it the hub was built to the Learning Centre design (`docs/designs/hires/learning-centre.png`, 390 × 2815 at 4x; the owner, 27 Oct 2026: *"Learning design is not met"*). The sub-screens the hub opens (the assessment and mock exam catalogues, a programme's levels, Flash Cards, Knowledge Center, the course grid, the institute directory and an institute's page) keep their own `← title` bars; only their bells changed (they open the app's notifications now).

## Screens

Code: `lib/features/learning_hub/`.

| Screen | What it is |
| --- | --- |
| **`LearningHubScreen({required onBack, viewer, onAccount, onMasterclasses, controller, routes})`** | The tab (mounted in `lib/app.dart`'s `learning:` slot). The design's page, below. `viewer` is the reader for the header's photo, `onAccount` the profile menu, `onMasterclasses` the banner's "Know more" (the app's Events screen; the website's without it). `onBack` stays for the shell's Back, which goes Home — the header has no arrow. |
| **`PartnerCoursesScreen({required onBack, hub?})`** | The institute directory (`/learning/partners`): unchanged. |
| **`PartnerScreen({required institute, required onBack, hub?})`** | One institute: unchanged. |
| `LearningScreen` (in `lib/features/learning/`) | The course grid, titled "ICR Courses": unchanged. |

`controller` and `routes` are for tests. The app mounts the hub with its callbacks and nothing else: it builds its own controller when given none (`createHubController`: the API's repositories for the courses, the institutes, the papers and the decks, or the sample content under `FEED_SOURCE=demo`), because a pushed route sits above the tab's providers.

### The page, top to bottom (dp, measured from the 1x export; y is under the header)

The owner's second export (`docs/designs/learning-hub-v2.png`, 504 × 2224 with a shadow margin; the frame is 390 × 2194 at 1x, its bottom bar included; 30 Oct 2026) with one rule: **a single view — most of the data visible without scrolling.** The page is 2142 dp tall with its header (2815 before); a 844 dp fold now holds the header, the Catalogue rail, all six Assess Your Knowledge cards and the Mock Exams heading with its first row (before, the fold ended just under the Assess grid).

The rhythm is one rule: **every section is a 36 dp heading row with its content directly under it** (the row is the thumb's target; the heading's cap line sits 12 dp under its top, which is where the export has it). A section ends 10.2 dp under its last card, then a 1 dp `#E1E3E4` hairline, then 5.9 dp, then the next heading row. There is **no hairline between Mock Exams and Flash Cards** in the export (16 dp of white instead) and none before the banner (10 dp). `LearningHubScreen._content` assembles it from a list of sections, so a section that is absent (no decks, no partner courses) leaves no gap or stray hairline.

1. **The header** — `HomeHeader`, shared with Home and Mentorship (see *Departures* below).
2. **Catalogue · View More** — View More opens the **Catalogue** page: the six doors as tiles, two to a row (`CatalogueScreen`, `DoorTile`), the categories rather than the ICR Courses list, which is one door of the six (owner's call, 2 Nov 2026). The heading row at the header's foot; 1 dp under it the rail of four photo tiles (`CatalogueRail`; the website's artwork, `hub_*.jpg`): 109 × 80, 8 dp corners, 4 apart from 15.25 in, the fourth running off the edge. Under each photo a 41.6 dp pane holding the caption (Work Sans 12.7 semibold `#414750`, lines 16 apart) centred in it. **The first tile is drawn lifted** — white card, soft shadow (`HubColors.tileShadow`) round photo and caption — as the export has it. A tile opens its door; View More opens the course grid. Hairline 5.1 dp under the rail.
3. **Assess Your Knowledge · View More** — six cards in two columns (`AssessRepository.groups(assessment)`, first six). `LearnCard`: **171 × 120**, 8 dp corners, a 1 dp `#E9EAEB` edge and a soft lift (`HubColors.cardShadow`, 6 dp blur, 2 down); the photo 171 × 80 with a **19 dp** white share disc (1 dp edge, glyph `#111C2D`, 12.5 dp) at **right 21, top 10**; a 40 dp pane with the title (Work Sans 12.7 bold `#1D63A3`, two lines of 14.7 dp) 11 in beside a **27 dp** disc with a 1 dp `#E7E9E9` ring holding a heavy black arrow (`LucideIcons600.arrowRight`, 18 dp, 9 from the right). Cards 16 in and 16 apart, rows **7.5** apart. A card opens the programme's levels; View More the assessment catalogue.
4. **Mock Exams · View More** — the same grid from `groups(mock)`; no hairline under it.
5. **Flash Cards · View More** — `FlashTile`s, **107.5 × 70**, 6.25 apart from 16 in; the deck's name (IBM Plex 13.9 bold, white) and "45 Cards" (10.8) at the bottom left, the arrow (14 dp) at the right of the count's line. A tile opens the deck's study screen.
6. **ICR Certifications · View More** — the grid from the courses ICR awards: **only a course with no awarding body** (`isIcr`: `provider == null`, the website's "ICR certified programs"); an institute's course is a partner's even when the institute is ICR's own, as the website files it (owner's report, 2 Nov 2026: production has one such programme and the grid showed the institute's catalogue); each card wears the white **ICR** tab hanging from the top edge, **10 in from the left, 68 × 31**, rounded where it meets the photo, "ICR" in Work Sans 18.3 bold blue.
7. **Partner Courses · View More** — the institutes as cards (`InstituteCard`: logo, name, "N courses" / "Courses coming soon"), ICR's own institute among them, each opening the institute's own course list (`PartnerScreen`) — the website's "Partner institutes" rail (owner's call, 2 Nov 2026; the grid listed the institutes' courses mixed together until then); View More opens the directory.
8. **Upskill with Masterclasses** — `MasterclassBanner`, 10 dp under the last card, **92 dp** tall, the width of the screen, a horizontal gradient `#EFF7FF` → `#EDF2FE` (the faces' own background runs the same way) with `#DBEAFE` edges; the title (Work Sans 15.9 bold, "Masterclasses" blue; `#0F172A`), "Webinars by the best in the industry!" (`#475569`, may wrap on a narrow phone), "Know more ›" (`#154B7C`) and the three faces (`masterclass_faces.png`, 92.5 dp, centred on the band, 18 dp from the right). Opens the Events screen. Nothing under it: the shell's bar follows directly, as in the export.

**Covers.** A record's own cover is drawn when it has one; a record without one gets the design's photo for that position (`designCardCovers`: `hub_card_capital.jpg`, `hub_card_collaboration.jpg`, `hub_card_communication.jpg`, `hub_card_compliance.jpg`, 342 × 160 px = 171 × 80 dp at 2x). They are the windows the export frames, cut by template matching from the earlier covers (which carried their own share disc; it is painted out — the card draws its own). The flash tiles use the same four, darkened. The design's own flash-tile photos (HVAC, Fire Safety, Leasing, Energy Audits) are not bundled; only a 1x export of them exists, with the words on top.

**Departures from the export, and why.**

| The export | The app | Why |
| --- | --- | --- |
| Header: 34 dp photo, a 282 × 40 pill reading "Search jobs, courses, partners…", a bell; 57 dp tall | `HomeHeader` as Home and Mentorship mount it: 32 dp photo, "Search", **+** and Messages and the bell; 52 dp | One bar on the three tabs is the app's decision (`HomeHeader`'s own doc); it is a shared widget outside this feature. The page's content is placed from the header's foot, so a different header moves nothing under it (the app page is 5 dp shorter than the export's). |
| Text in Work Sans / IBM Plex at the design's sizes (12.7, 13.9, 14.9, 15.8…) | Roboto on the app's steps (`AppText.sp`: 12.7 → 13, 13.9 → 14, 14.9 and 15.8 → 16) | The owner's call of 27 Oct 2026. Every line sits within 1 dp of the export's; "View More" is 16 sp against the export's ~15 and sits 2 dp above the heading's baseline as there. |
| The four Catalogue photos are brighter, differently cropped edits | The website's tile artwork (`hub_assess.jpg` …, 279 × 283), centre-cropped | The same files serve the doors elsewhere in the app; only a 1x cut of the export exists (and the fourth tile is mostly off the frame). Send the four at 2x to swap them. |
| Flash-tile photos specific to each deck | The four card covers, darkened | See *Covers*. |
| Cards read "Capital Planning, Collaboration, Communication, Compliance Standards ×3" | The same in the golden (the test fixture); the live screen shows what the API returns | The design's sample content is held by the golden test (`_DesignAssess`, `_DesignCourses`, `_DesignStudy`), not by the demo repositories other builders edit. |
| At 320 dp a long single word ("Communication") does not fit beside the arrow | It breaks inside the word, as the old cards did | Two 13 sp lines are the most a 120 dp card holds; the floor keeps the text from shrinking. |

**Not on the design, so not on the screen any more:** the "My learning" counts (My courses · My attempts · Certificates) and the six "Choose your training programme" doors. *My attempts* and *My certificates* lost their entry points on this tab (the certificates screen still answers the `/learning/certificates` door and a notification; attempts only the result screens); *My courses* is the course grid's "My courses" filter. The controller still reads the counts (`myLearning`) for whoever places them next.

**States.** Each section loads on its own (grey card boxes, 171 × 120, while it does), says why it failed with Try again, and is left out when it has nothing. A search (`LearningHubController.setSearch`; the header's pill opens the global search instead) hides the catalogue and the banner and narrows the grids and the rail; no match anywhere shows "No matches" with Clear search. Pull to refresh reads everything again.

## Wiring

```dart
learning: Builder(
  builder: (ctx) => LearningHubScreen(
    viewer: _viewer,
    onBack: () => AppShell.selectHome(ctx),
    onAccount: () => AppShell.openDrawer(ctx),
    onMasterclasses: () => AppShell.push<void>(ctx, screens['/events']!),
  ),
),
```

(`lib/app.dart`.) `LearningHubController` (`hub_controller.dart`) holds a `LearningController` (the courses: both grids, the course sheet, the places), a `LearningHubRepository` (institutes, counts, the institute enquiry), an `AssessRepository` (the programmes and the subjects) and a `StudyRepository` (the decks). One `ApiLearningRepository` is shared, so the places it caches are read once. Every pushed Learning screen goes through `pushLearningPage`, which lays the notification scope (`UnreadCounts`, `NotificationRouter`) over the route so its bell opens the app's notifications with the dot Home shows.

## Endpoints

| Call | Used for |
| --- | --- |
| `GET /learning/courses` | ICR Certifications and Partner Courses, the grid, a partner's page (one request, shared) |
| `GET /learning/courses?kind=ASSESSMENT`, `/learning/papers`, `/learning/topics` … | the assessment programmes and the mock exam subjects (`ApiAssessRepository.groups`) |
| `GET /learning/resources` | the decks (`ApiStudyRepository.topics`, the question shelves only) |
| `GET /learning/me/enrollments` | the places held (the "Enrolled" pill, the grid's My courses) |
| `GET /learning/providers` | the institutes (the directory, a partner's page) |
| `GET /learning/me/attempts` · `GET /learning/me/certificates` | the counts the controller still reads (nothing on this tab shows them now) |
| `GET /notifications/unread-count` | the bell's count, beside the app-wide one |
| `POST /learning/providers/:slug/enquire { name, email, message }` | "Ask the institute" |

## Every control, and the test that proves it

Widget tests are in `test/learning_hub_test.dart` (fakes for the four repositories; a recording stub stands in for the other builders' screens; browser hand-offs are caught on the `url_launcher` channel). Goldens: `test/golden/learning_golden_test.dart` → `build/screens/learning_hub.png` (the first fold at 390 × 844), `learning_hub_full.png` (the whole page at 390 × 2143: header and content, no bar; the design's frame less its bottom bar and 5 dp of header, for `compare.py` / `strip_diff.py` — cut the export's frame with `measure.py --flatten --frame 38,13,428,2207` and drop its top 5 rows) and `learning_hub_320.png` (export only). They draw the design's sample content from fixtures held in the golden file (six cards a grid, four decks), so they do not move when the demo repositories change. Live tests are in `test/live/learning_hub_live_test.dart`.

| Control | Test |
| --- | --- |
| The page opens on the design's sections, nothing of the old hub | *opens on the design: the header, Catalogue, the grids, the decks rail and the banner* |
| A catalogue tile opens its door with the Learning tab lit | *a catalogue tile opens its door with the Learning tab lit* |
| Six programmes, View More, a card opens its programme | *Assess Your Knowledge holds the first six programmes…* |
| The subjects and their View More | *Mock Exams holds the subjects…* |
| A tile per deck with its count, never a formula shelf; View More; a tile opens the deck | *Flash Cards: a tile per deck…* |
| ICR's courses with the ICR tab, the institutes' apart; a card opens the sheet; both View Mores | *ICR Certifications shows ICR's courses…*, *View More on ICR Certifications…* |
| A failed section says why and Try again reads it; an empty section is left out | *a section whose read failed…* |
| The header's search pill is a button for the global search; the sections stay | *the header search is a button that opens the global search…* |
| Pull to refresh | *pulling down reads every section again* |
| The bell opens the app's notifications with the dot | *the bell opens the app's notifications…* |
| Know more opens the Events screen, else the website | *Know more opens the Events screen…* |
| The measures: 36 dp heading rows, 109 × 80 rail tiles, 171 × 120 cards 16 apart in rows 127.5 apart, 107.5 × 70 flash tiles, the 92 dp banner 10 dp under the last card, section to section 428 / 427 / 123 / 428 dp | *the rail, the grids, the decks and the banner sit where the export draws them* |
| Four hairlines (none after Mock Exams, none before the banner), 16 dp of white in their place | *four hairlines…* |
| A search takes the Catalogue and the banner away; the first section starts at the header | *a search takes the Catalogue and the banner away…* |
| No overflow and no clipped text at 390, 360 and 320 dp, at 100 % and 130 % text | *widths: the hub draws without overflow or clipped text at …* |
| In the shell: a door screen keeps the bar lit on Learning; the phone's Back goes Home; the hub builds its own controller from the API; the sample content | *built into the app* |


## Partner application: who may apply, and what it asks (6 Nov 2026, owner: "check the web who can ... be a Learning Partner ... and do it in the app accordingly, and validations also")

Checked against the website's `PartnerApplyDialog.tsx`, `PartnerInstitutesHero.tsx`, `learning-partner.service.ts` (`myCompanies`, `apply`, `companyIRun`) and `ApplyAsPartnerDto`. A learning partner is **a company**, never a person: the applicant must be an ACTIVE `COMPANY_ADMIN` of the company (`GET /learning/partners/companies` lists only those; `POST /learning/partners/applications` answers 403 to anyone else), a company that already has a partner institute is refused (409), and so is one with an application PENDING or UNDER_REVIEW; only INFO_REQUESTED takes new answers on the same row, and a REJECTED company may apply again.

* **`PartnerApplyScreen`** (`lib/features/site/partner_apply_screen.dart`, route `/learning/partners/apply` and `/learning/partners?apply=1`) now asks what the website's dialog asks and nothing more: the company to apply as, and one optional box, "What courses would you like to offer? (optional)" ("Subjects, accreditations, the courses you run today…", cut at 4,000 characters like the website's box). It used to ask course areas, a proposal and accreditation; the API accepts `courseAreas` and `accreditation` but the website sends neither, so the app no longer does. The request is `{ companyId, proposalNotes? }` (notes trimmed, left out when blank). `PartnerApplyWords` holds the website's sentences (title, introduction, "Apply as", "Only companies you are an admin of are listed.", the chips Partner / With ICR / More info requested / Declined, "Could not send the application.", "Could not load your companies. Try again in a moment.").
* **Who is offered**: every company the member is an admin of, listed with the website's chip; a partner and a company with its application with ICR (PENDING, UNDER_REVIEW) are faded and cannot be picked; a declined company or one ICR asked more of can be picked again, and ICR's `reviewNote` shows under the list (the website's dashboard card shows it for both). The form opens on the company being acted for when it can apply, else the first that can. With no eligible company the notes box still shows and Submit stays off, as in the website. A member who administers no company reads "You are not an admin of any company on ICR yet. Register your company to apply." and "Register a new company" (the app's create-company screen); when it returns the list is read again so the new company is there to apply as.
* **After sending**: "Application sent", "{company}'s application is with ICR.", "Our team reviews every application by hand. Once it is approved, your dashboard opens the partner console, where you add and publish courses.", with Close and Go to dashboard (the Home tab). Back on Partner Courses the member's standing is read again (`PartnerCoursesScreen._apply`), so the Apply banner turns into "{company}'s learning partner application is with ICR" at once.
* **Where Apply is offered**: the website's directory heading carries "Apply to become Partner Institute: [Apply]" whether or not it lists institutes. The app's banner (same words) now ends the list in every state (institutes listed, none yet, a failed load, a search with no match); it is replaced by the company's standing only when every company the member administers is already a partner or with ICR (the website would show Apply and then disable every company; the dashboard card there shows the same standing). Banners are flat white rows between hairlines.
* **Not done in the app** (needs other files): the website's "Register a new company" goes to `/account/companies/new?partner=1`, which carries an "Apply to add partner courses" tick that sends the application the moment the company exists; the app's create-company screen has no such tick, so a new company is applied for from this screen afterwards. And an admin of an approved partner company gets no "Partner Institute" menu row: the API sends `learningPartner: true` for them and an empty `learningRoles` (an admin needs none), but `SessionUser` reads only `learningRoles`.

Tests: the "Become a partner" group in `test/site_pages_test.dart` and the "Partner Courses" group in `test/learning_hub_test.dart` (the request body, the banner's words and states, the standing read again).
