# Learning hub

The Learning tab, built to the **Learning Centre** design (`docs/designs/hires/learning-centre.png`, a 390 × 2815 dp frame exported at 4x; the owner, 27 Oct 2026: *"Learning design is not met"* — the earlier hub was a different screen). The sub-screens the hub opens (the assessment and mock exam catalogues, a programme's levels, Flash Cards, Knowledge Center, the course grid, the institute directory and an institute's page) keep their own `← title` bars; only their bells changed (they open the app's notifications now).

## Screens

Code: `lib/features/learning_hub/`.

| Screen | What it is |
| --- | --- |
| **`LearningHubScreen({required onBack, viewer, onAccount, onMasterclasses, controller, routes})`** | The tab (mounted in `lib/app.dart`'s `learning:` slot). The design's page, below. `viewer` is the reader for the header's photo, `onAccount` the profile menu, `onMasterclasses` the banner's "Know more" (the app's Events screen; the website's without it). `onBack` stays for the shell's Back, which goes Home — the header has no arrow. |
| **`PartnerCoursesScreen({required onBack, hub?})`** | The institute directory (`/learning/partners`): unchanged. |
| **`PartnerScreen({required institute, required onBack, hub?})`** | One institute: unchanged. |
| `LearningScreen` (in `lib/features/learning/`) | The course grid, titled "ICR Courses": unchanged. |

`controller` and `routes` are for tests. The app mounts the hub with its callbacks and nothing else: it builds its own controller when given none (`createHubController`: the API's repositories for the courses, the institutes, the papers and the decks, or the sample content under `FEED_SOURCE=demo`), because a pushed route sits above the tab's providers.

### The page, top to bottom (dp, measured from the export at 4x)

1. **The Home header** — `HomeHeader` as Home and Mentorship mount it (photo, "Search jobs, courses, partners…", bell), pinned at `HomeHeader.height`. The bell opens the app's notifications with the app-wide unread dot (or the catalogue's count, whichever is larger); the search narrows every section below on submit.
2. **Catalogue · View More** — the heading line at 71 (Work Sans 15.6 bold, 16 in; "View More" Plex 14.5 semibold `#334C65` ending 27.75 from the right; the row itself is 36 tall so the action is a thumb's target), then the rail at 101: four 109 × 80.75 photo tiles with 8 dp corners, 4 apart from 15.25 in — *Assess your knowledge*, *Mock Exams*, *Flash Cards*, *Knowledge Centre* (`CatalogueRail`; the website's artwork, `hub_*.jpg`), each with a two-line caption (Work Sans 11.9 bold `#414750`) 3 under its photo; the fourth runs off the edge. A tile opens its door (`LearningRoutes`); View More opens the course grid. A 1 dp `#E1E3E4` rule 7 under.
3. **Assess Your Knowledge · View More** — the heading 13 under the rule, then a two-column grid of the first six assessment programmes (`AssessRepository.groups(assessment)`): `LearnCard`, 172.5 wide from 15.5 in, 14.25 apart, rows 11.25 apart, 12 dp corners and a soft `#E6E8EA` edge; a 130.75-tall photo with a 22 dp white share disc at its top right (right 9, top 8.5), then the title in ICR blue (Work Sans 13.8 bold, two lines allowed) 12.75 in beside a 25 dp ringed disc with the black arrow (right 9.75), in a pane at least 40.75 tall. A card opens the programme's levels (`GroupScreen`, with a `CatalogueController` of its own); View More the assessment catalogue. The rule 2.25 under the last row.
4. **Mock Exams · View More** — the same grid from the mock exam subjects (`groups(mock)`); a card opens the subject's sets.
5. **Flash Cards · View More** — a rail of `FlashTile`s, one per deck (`StudyRepository.topics()`, never a formula shelf): 107.75 × 62 photo tiles with 8 dp corners, 6.25 apart from 16 in, darkened towards the foot, the deck's name (Work Sans 14.5 bold, white) and "45 Cards" (Plex 10.5) at the bottom left, an arrow at the bottom right. A tile opens the deck's study screen; the decks are read again after (a read takes one of the plan's places). The rule 10 under.
6. **ICR Certifications · View More** — the grid again from the courses ICR itself awards (`LearningHubController.isIcr`: no awarding body, or ICR's institute), each card with the white **ICR** tab in its top-left corner (76 × 32, Work Sans 19 bold blue, rounded where it meets the photo). A card opens the course sheet; View More the course grid.
7. **Partner Courses · View More** — the grid from the institutes' courses (the design draws the ICR tab here too; a card shows it only when the institute has no logo of its own). View More opens the institute directory.
8. **Upskill with Masterclasses** — `MasterclassBanner`, 8 under the last grid: a band at least 90.75 tall, the width of the screen, on `#EFF7FF` with `#DBEAFE` edges; "Upskill with **Masterclasses**" (Work Sans 15.9 bold, the second word in blue), "Webinars by the best in the industry!" (Plex 11.9), "Know more ›" (Plex 14.8 medium, blue), the design's three overlapping faces at the right (`masterclass_faces.png`, cut from the export). Opens the Events screen.

**Covers.** A record's own cover is drawn when it has one; a record without one gets the design's photo for that position (`designCardCovers`: `card_capital.jpg`, `card_collaboration.jpg`, `card_communication.jpg`, `card_compliance.jpg`, cut from the export at 2x), so the live screen reads like the design. The flash tiles use the same four, darkened. The design's own flash-tile photos carry their words baked in and did not survive painting them out, so they are not bundled.

**Not on the design, so not on the screen any more:** the "My learning" counts (My courses · My attempts · Certificates) and the six "Choose your training programme" doors. *My attempts* and *My certificates* lost their entry points on this tab (the certificates screen still answers the `/learning/certificates` door and a notification; attempts only the result screens); *My courses* is the course grid's "My courses" filter. The controller still reads the counts (`myLearning`) for whoever places them next.

**States.** Each section loads on its own (grey card boxes while it does), says why it failed with Try again, and is left out when it has nothing. The header's search hides the catalogue and the banner and narrows the grids and the rail; no match anywhere shows "No matches" with Clear search. Pull to refresh reads everything again.

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

Widget tests are in `test/learning_hub_test.dart` (fakes for the four repositories; a recording stub stands in for the other builders' screens; browser hand-offs are caught on the `url_launcher` channel). Goldens: `test/golden/learning_golden_test.dart` → `build/screens/learning_hub.png` (the first fold at 390 × 844) and `learning_hub_full.png` (the whole page at 390 × 2815, the design's frame, for `tool/design/compare.py`). Live tests are in `test/live/learning_hub_live_test.dart`.

| Control | Test |
| --- | --- |
| The page opens on the design's sections, nothing of the old hub | *opens on the design: the header, Catalogue, the grids, the decks rail and the banner* |
| A catalogue tile opens its door with the Learning tab lit | *a catalogue tile opens its door with the Learning tab lit* |
| Six programmes, View More, a card opens its programme | *Assess Your Knowledge holds the first six programmes…* |
| The subjects and their View More | *Mock Exams holds the subjects…* |
| A tile per deck with its count, never a formula shelf; View More; a tile opens the deck | *Flash Cards: a tile per deck…* |
| ICR's courses with the ICR tab, the institutes' apart; a card opens the sheet; both View Mores | *ICR Certifications shows ICR's courses…*, *View More on ICR Certifications…* |
| A failed section says why and Try again reads it; an empty section is left out | *a section whose read failed…* |
| The header's search narrows, no match, Clear search | *the header search narrows every section…* |
| Pull to refresh | *pulling down reads every section again* |
| The bell opens the app's notifications with the dot | *the bell opens the app's notifications…* |
| Know more opens the Events screen, else the website | *Know more opens the Events screen…* |
| In the shell: a door screen keeps the bar lit on Learning; the phone's Back goes Home; the hub builds its own controller from the API; the sample content | *built into the app* |
