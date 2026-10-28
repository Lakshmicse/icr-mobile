# ICR mobile

The ICR (Institute for Corporate Real Estate) app for Android and iOS, in Flutter. It talks to the same API as the website (`irc-portal`, NestJS, `/api/v1`).

**Screens so far**

- **Sign in**: a card, built to the Sign in designs in light and dark (it follows the phone's setting): the LinkedIn and Google marks, then email and password against `POST /auth/login` with a show/hide eye, "Forgot password?" and "Remember me". Tokens are kept in the platform keystore and refreshed automatically. Joining with an email and resetting a password open the website. Notes and measurements: `docs/screens/sign_in.md`.
- **LinkedIn / Google sign-in**: the API's own OAuth flow (the website's), run in a secure browser tab. Someone with an ICR account comes back signed in. Someone new confirms their name, plus the emailed 6-digit code if the provider didn't vouch for the address, and taps "Agree & join" (on the same card, light or dark). The app sends the API only the hash of a secret it keeps, and the API's answer can only be redeemed with that secret, so another app that catches the `in.org.icr://auth` redirect can't use it. A provider this server has no keys for shows its mark faded, as on the website.
- **Home**: the community feed from `GET /forum/threads`, built to the Home design and its Figma spec ("Forums / New home"): every font size, weight and colour comes from the spec. It has the chips (All Feed, Trending, Following, Unanswered, Polls, and the topic chips #HVAC and #ESG, which filter by forum tag), likes, bookmarks, follow, poll voting, threaded replies, replying, sharing and search.
- **Profile menu**: tap your photo in the Home header. Built to the "Profile Menu" spec: banner and photo, name with the verified seal, headline, location and connections, profile views and post impressions, Regional Chapters / Working Councils / Get Involved (with your chapter code and CPD hours when you have them), My activity, and Settings / Sign out. Each line comes from the API where it has one (`/users/me/profile`, `/members/:id`, `/users/me/profile-performance`, your discussions' views, `/mentorship/cpd/summary`); the rows open the matching website pages for now.
- **Jobs**: the board from the Jobs design and a job's sheet over it. Recommended jobs with the member's match score, jobs matching their preferences, their saved search or the latest jobs (`GET /jobs/recommended`, `GET /jobs`, `GET /jobs/alerts/:id/run`), search and filters, bookmarks, the member's open applications and new alert matches on the chips. A job opens as a blurred-backdrop sheet: company, title, place and terms, salary, the match against the member's profile, the description with its responsibilities, skills, the hiring contact (with Message), who else from ICR works there, the company, and Easy Apply (`POST /jobs/:id/apply`, asking for a mobile number first when the profile has none). Details and what the API cannot give: `docs/screens/jobs.md`.
- **Learning**: the course catalogue and a course's sheet (`GET /learning/courses`, `/learning/courses/:code`, `/learning/me/enrollments`), with the member's enrolments, reviews, enrolment and enquiry. A paid course sends the member to the website to pay. Details and what the API cannot give: `docs/screens/learning.md`.
- **Mentorship**: the Mentorship tab, then Find Mentors and a mentor's profile. The tab shows the programme banner, the top-rated and most-active mentors, companies, topics, the open programme cohort and featured advisory sessions (`GET /mentorship/mentors`, `/mentorship/mentors/facets`, `/mentorship/public-stats`, `/mentorship/programmes`, `/mentor-services/mentors/:id`). Find Mentors is the directory with its category chips and "Load more mentors". A profile has Overview, Offerings and Recommendations, with the next free slot computed from the mentor's hours, and an offering opens as a sheet. Requesting mentoring, a 1:1 session or a programme, and taking a free plan or resource, are done in the app (`POST /mentorship/requests`, `/mentor-services/:id/request`, `/mentor-plans/:id/request`, `/mentor-plans/:id/subscribe`); a paid item continues on the website, where PayU runs. `docs/screens/mentorship.md`, `docs/screens/mentor_profile.md`.
- **Working Councils**: reached from the Discover sheet or the profile menu. The councils directory with the member's own councils, upcoming roundtables, search and join/leave (`GET /councils`, `/councils/memberships/mine`, `POST/DELETE /councils/:id/join`). `docs/screens/councils.md`.
- **Events**: reached from the Discover sheet. The spotlight, the agenda with its filters and category tiles, the member's schedule and CPD hours, and an event's sheet with register / cancel (`GET /events`, `/events/:slug`, `POST/DELETE /events/:id/rsvp`). Tickets, which are bought through PayU, open the website. `docs/screens/events.md`.
- **Bottom navigation**: five tabs — Home, Learning, Mentorship, Jobs, Discover — in the 5-tab design's slots (Mentorship sits where the design draws Forums; Forums and Marketplace are still shell screens but have no slot on the bar), drawn like LinkedIn's Android bar: 24 dp filled Material Icons glyphs, 12 sp Roboto labels, near-black for the open tab and 60% black for the rest, a rule under the open label. Each tab keeps its place while you switch, and Back returns to Home. A screen pushed over the tabs that its design draws with the bar (Events, Find Mentors) keeps the bar under it, and tapping a tab leaves the screen for that tab. Tabs without screens yet show a "coming to the app" screen that opens the same part of the website.
- **Discover**: not a screen but a sheet, built to its design, that slides up over the open tab while the page behind blurs and dims. Its doors are Regional Chapters, Working Councils, Digital Library and Events, then, for business, Hire, Sell, Post requirement and Advertise. Working Councils and Events open in the app; the rest open the matching website page for now. Tap the page, the Discover tab again or Back, or drag the sheet down, to close it.

## Run it against the local backend

1. Start the backend from `irc-portal` with `npm run dev`. The API runs on `http://localhost:3001`.
2. Seed the test accounts once: `npm run db:seed:test-users --workspace backend`. Every password is `Test@12345`, for example `professional@icr.test`.
3. Start an emulator, then run `flutter run`.

The app picks the API address on its own. On the Android emulator it uses `http://10.0.2.2:3001/api/v1`, the emulator's name for your computer. Everywhere else it uses `http://localhost:3001/api/v1`.

A phone on the same Wi-Fi needs your computer's address:

```
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3001/api/v1
```

Debug builds allow plain HTTP, so the local API works. Release builds are HTTPS-only.

### Trying Google / LinkedIn sign-in locally

This needs the backend change from `irc-portal` branch `feat/mobile-social-sign-in` (migration `20261031090000_mobile_social_sign_in`).

1. Put `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET` (or the LinkedIn pair) in `irc-portal/backend/.env`, with `http://localhost:3001/api/v1/auth/google/callback` registered in that provider's console. Then restart the API.
2. The provider sends the browser back to `localhost:3001`, which on the emulator is the emulator itself. Forward it to your computer with `adb reverse tcp:3001 tcp:3001`, and run the app against the same address: `flutter run --dart-define=API_BASE_URL=http://localhost:3001/api/v1`.

Against production (`API_BASE_URL=https://icr.org.in/api/v1`) both providers already have keys. It works once that backend change is deployed.

## Build options (`--dart-define`)

| Name | Default | What it does |
|---|---|---|
| `API_BASE_URL` | local backend (see above) | The API, `/api/v1` included. Production: `https://icr.org.in/api/v1`. |
| `SITE_URL` | `https://icr.org.in` | Where "Join ICR", "Forgot password?", notifications and other website pages open. |
| `FEED_SOURCE` | `live` | Set it to `demo` to show the designs' sample content (the Home posts, the profile menu, and every section screen), bundled with the app, instead of the API's. Useful for design review, because a fresh local database has little in it. |

To compare a screen with its PNG on the Android emulator, give it the designs' 390 dp width: `adb shell wm density 443` on the 1080 x 2400 `Medium_Phone_API_36.0` (put it back with `adb shell wm density reset`). At the default density the screen is 411 dp wide and everything sits about 5% wider than the PNGs.

### Seeing the designs exactly, or the real API

The app has two content sources, picked at launch:

- **Live** (default): the real API, so what shows is what the local database holds.
- **The designs' sample content** (`--dart-define=FEED_SOURCE=demo`): every screen's content, photos and numbers as in the PNGs, bundled with the app. In VS Code, pick "ICR (the designs' sample content)" in Run and Debug (`.vscode/launch.json`). This is the way to check a screen against its PNG, because a fresh local database has none of the designs' people, events and photos.

To make the live app show the designs' content too, `tool/seed/` has scripts that fill the **local** database with it (local only, idempotent, removable); see `tool/seed/README.md`.

## Tests

```
flutter analyze
flutter test                                # unit tests and the screen goldens
flutter test --update-goldens --tags golden # re-record the goldens after a deliberate UI change
flutter test --tags live                    # the tests that use the local API (test/live/); skipped when it is not running
flutter test --exclude-tags live            # everything else
```

The live tests do the real thing (sign in, RSVP, bookmark, apply…) as the seeded personas (see `tool/seed/README.md`) and read the effect back through the API, undoing it where the API allows.

The golden tests also write each screen at 2x to `build/screens/`, the scale of the design exports, so a render can be laid over its design. The designs themselves are in `docs/designs/`, the measuring and comparing tools in `tool/design/` (Python with Pillow and numpy), and the method in `docs/DESIGN_REPLICATION.md`; `docs/SCREEN_BUILD_CHECKLIST.md` is the recipe for adding a screen family, and `docs/screens/` says, per feature, which endpoints feed it and where the design asks for something the API does not have.

## Layout

```
lib/
  core/        config, API client (token refresh), session, theme (colours and type fitted to the design), utils,
               widgets (the title bar, search field, chips, section headings, buttons and the blurred detail sheet the section screens share)
  features/
    auth/            sign-in screen
    councils/        the councils directory
    discover/        the Discover sheet
    events/          the events home and an event's sheet
    feed/            Home: models, API and demo sources, controller, widgets
    jobs/            the Jobs board, the job sheet, Easy Apply
    learning/        the course catalogue and a course's sheet
    mentor_profile/  a mentor's profile and an offering's sheet
    mentorship/      the Mentorship tab and Find Mentors
    profile/         the profile menu
    shell/           bottom bar and the tab shell
assets/        fonts (Work Sans, IBM Plex Sans), ICR logos, demo images per feature, app icon
docs/          the designs, the replication method, per-screen notes
tool/design/   measure.py, fitfont.py, compare.py, devcompare.py (a device screenshot beside its design)
```

## Not built yet

- **The Forums and Marketplace screens, the pages behind the Digital Library, Regional Chapters, Hire, Sell, Post requirement and Advertise doors; notifications, posting a discussion, profile, messaging.** These open the website for now.
- **Share counts and photos on feed cards.** The forum API has neither yet, so live posts leave them out. The demo source shows them.
- **App icon.** It is the ICR mark. Regenerate it with `dart run flutter_launcher_icons` after changing `assets/icon/`.
