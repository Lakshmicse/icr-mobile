# Search (the whole app)

No design exists for this screen. It is built to LinkedIn's Android search, at the owner's request (27 Oct 2026: "as LinkedIn searches the whole thing, the search should search the whole app, relevant features or people"): Roboto, 90 % / 60 % black text, hairline rows, white page, ICR blue for the chip that is on and for links. Code: `lib/features/search/`; wiring: `lib/app_search.dart` and two lines in `lib/app.dart`. Tests: `test/search_features_test.dart`, `test/search_controller_test.dart`, `test/search_sources_test.dart`, `test/search_screen_test.dart`, `test/golden/search_golden_test.dart` (renders to `build/screens/search_*.png`), `test/live/search_live_test.dart` (the real API).

## How it opens

The Home header's search field (also on Learning and Mentorship, which mount the same header) calls `AppActions.openSearch?.call(context)` (`lib/core/util/app_actions.dart`). `lib/app.dart` sets that to `openGlobalSearch` and sets `SearchEnvironment.current = appSearchEnvironment(viewer: …)` where `SiteRoutes.resolver` is set. `openGlobalSearch(context, {query})` builds the sources **from the caller's context** (so the tab's repositories, and the providers a pushed screen reads, are in reach) and pushes `SearchScreen`. Every record then opens over the caller's context, the way that screen would open it, so the search page is still there under it when the person comes back.

## What it shows

- **Field**: back arrow, an autofocused field ("Search ICR"), a clear (x). The keyboard's search key keeps the query as a recent search.
- **Nothing typed**: *Recent searches* (kept on this device for this person, newest first, at most ten, each removable, "Clear all") and *Suggested for you* (six places: Jobs, Marketplace, Mock Exams, Find mentors, Events, Membership & plans).
- **Typing**: a chip row, **All · People · Jobs · Courses · Mentors · Companies & suppliers · Events · Discussions · Documents · App**, then on **All** a group per kind (four hits each, "See all people" to jump to that chip). A hit is the picture (a photo as a circle, a company or course as a rounded square, initials or a glyph without one), the name, one line of context, and what it is ("Person", "Job"…). A group that is still loading keeps its last hits, and a thin bar runs under the chips; a source with nothing to show has no group.
- **One chip**: every hit of that kind, paged on scrolling or "Show more results" (jobs, mentors, suppliers, discussions and documents page; people, courses and events do not).
- **Order of the groups**: the app's own places first when the query names one ("plans", "jobs", "mentor" — a strong match), otherwise after the records; then people, jobs, mentors, courses, suppliers, events, discussions, documents.
- **States**: nothing found (with the suggested places as chips), every source failing ("Can't reach ICR" with Try again), a chip with nothing in it ("Search everything"). 360 and 390 dp wide, text up to 1.3x, no overflow.

## Where the hits come from

There is **no search endpoint in the API**, and the backend does not change for this. So `repositorySources` (`repository_sources.dart`) asks the endpoint each existing screen already asks, through that screen's repository (the real one, or the demo's), and reads the answer with that screen's parser. One request per source per query, all in parallel, each failing alone (a failed source shows no group; only *all* failing is "offline").

| Kind | Endpoint (through) | Notes |
|---|---|---|
| People | `GET /messaging/recipients?search=` (`MessagingRepository.recipients`) | Active members with a public profile, plus colleagues and people the caller already writes to; 8 at most; ≥ 2 characters; never the caller. Opens `openMemberProfile`. |
| Jobs | `GET /jobs?search=` (`JobsRepository.search`, Easy Apply **off**) | Pages. Opens the job sheet with the job already read. |
| Mentors | `GET /mentorship/mentors?search=` (`MentorshipRepository.search`) | Pages. Opens the mentor's profile. |
| Courses | `GET /learning/courses` (`LearningRepository.courses`) | The endpoint takes no search term, so the catalogue is read once, kept a minute, and matched on the device (every word in the title, code, summary or provider; title counts most). Opens the course sheet. |
| Companies & suppliers | `GET /vendors?search=` (`MarketplaceRepository.suppliers`, any trust level) | Pages. Opens the supplier sheet. |
| Events | `GET /events?search=` (`EventsRepository.search`, upcoming) | Opens the event sheet by slug. |
| Discussions | `GET /forum/threads?search=` (`FeedRepository.load`) | Pages. Opens the thread page. |
| Documents | `GET /documents?search=` (`LibraryRepository.documents`) | Pages. Opens the document page. |
| App | no request: `feature_catalogue.dart` | See below. |

**Request budget** (the API allows 120 requests a minute per address): nothing is asked below two characters; typing waits 300 ms after the last key; an answer for older text is dropped; switching chips asks nothing the query already has; typing while on one chip asks that one source. A burst is therefore at most eight requests (seven sources and, once a minute, the course catalogue).

## The app's own places

`featureCatalogue` lists every place a person can go (about forty: the tabs, the Learning doors, jobs and career screens, the mentoring screens, requirements, events, councils, chapters, the library, profile, settings, plans, notifications, messages…), each with the words people use for it (`keywords`, mirroring the website's `ASSISTANT_TOPICS`). `matchFeatures` scores the name highest (exact 100, starts-with 85, a word of the name 75–90), then keywords (60 / 50), then the subtitle (25); every word of a longer query must match. The catalogue says what exists; **`lib/app_search.dart` says what the app can open**: each id has an opener there (a tab through `AppShell.goToTab`, a screen through `inAppSiteRoute` for the website paths the app already maps, or the screen's own `open…` function), and an id without one is never offered. A new screen is searchable by adding a catalogue entry and its opener.

Forums and Marketplace, which have no slot on the bottom bar, are reachable from here ("Forums", "Marketplace").

## Tokens

`search_styles.dart` (`SearchLook`, `SearchStyles`): the same values as the Home feed's LinkedIn look, copied so the feature does not import the feed. Roboto is the bundled variable font, so a weight above Regular is asked for on its `wght` axis. Icons are Flutter's `Icons.*` (never `material_symbols_icons` `_rounded` with `fill: 1`, which a release build draws blank).

## What it does not search

- **Chapters and councils**: their endpoints take `search`, but opening one needs the chapters/councils handoffs; both are in the app's places ("Regional Chapters", "Working Councils") instead.
- **Messages' text** (`GET /messaging/search`): a person's conversations are not mixed into a search over the whole app; the Messages screen has its own.
- **Products and services** of a supplier (`/products`, `/services`): the supplier's listing is found; its catalogue is inside its sheet.
- **Companies that hire but do not sell**: a company is found as a supplier only; there is no company-name endpoint without a listing.
- **Anything the caller may not read** is the API's call, not the app's: people with private profiles, drafts, other companies' data never come back.
