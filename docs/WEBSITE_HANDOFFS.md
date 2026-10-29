# Website hand-offs: what a tap on a "website" row opens

Owner's rule (27 Oct 2026): *"more options redirect to the website; it should not happen — show it in the app as much as possible"*, then: *"the app redirects to the website pages, and before that there is one black screen — the app should render everything in itself, not the website."*

Every link from the app to a page of the ICR website goes through **one seam**, `SiteRoutes.inApp(uri)` (`lib/core/util/links.dart`), and is tried in this order:

1. **Native** — the app has a screen for the page (`inAppSiteRoute` in `lib/app_screens.dart`, filled into `SiteRoutes.resolver` by `lib/app.dart`).
2. **In-app web view** — only what nobody mapped (see the table): `InAppWebScreen` (`lib/features/web/`), signed in as the person (`SiteRoutes.webView`), on white.
3. **Phone** — only what a web view should not do: another site, `mailto:` / `tel:`, a payment, a file to download (`SitePolicy`, `lib/core/util/site_policy.dart`).

Every call site (`openSitePage`, `openUrl`, `JobLinks` / `MarketplaceLinks` / `RfqLinks` `.openUri`, `LibraryDevice.openPage`, the screens' `opener` parameters, `ExamServices.openUrl`, the repositories' `link(...)`/`plansLink()`) reaches the seam, so a new row anywhere benefits without editing it. `grep -rn "launchUrl(" lib` finds only the four `System*Links.open` implementations, `LibraryDevice.open`, `openUrl`'s last step and the web view's own external hand-off. With no resolver set (a screen mounted alone in a test) a link still reaches the browser, as before.

## The in-app web view (`lib/features/web/`)

- **App bar**: back (through the page's history first, then leaves the screen), the page's own title, close. A 2 dp progress line under it, "This page didn't load" with *Try again*. Hardware Back does the same as the arrow.
- **Links inside the page**: a page of the website (`SitePolicy.isSite`: same scheme, host and port as `SITE_URL`) stays in the view; another host, `mailto:`, `tel:`, `intent:`, a payment return (`/api/`, `/payments/`), `/uploads/…` and file extensions (`pdf ics zip doc(x) xls(x) ppt(x) csv apk vcf`) go to the phone. A frame inside the page (video, map) is the page's business.
- **Signed in**: the website keeps its session in `localStorage` (`icr.accessToken`, `icr.refreshToken`; `frontend/src/lib/api.ts`). The view loads `/robots.txt` of the same origin, writes the ACCESS token there, then loads the page. **Only the access token goes across**: the API's refresh tokens are single use and rotated (`AuthService.refresh`), so a web view that held the app's would spend it and sign the app out. The page gets a fresh 15-minute token (renewed through the app's own session first when under 3 minutes are left) and a new one every 9 minutes while the screen is open (`WebSessionBridge`); the session is removed from the page's storage when the screen closes. A page of another site never gets it.
- **Verified** against the local site (headless Chromium, the same mechanism: access token only, from `/robots.txt`): `/profile` and `/dashboard` render signed in as the persona, the same page without it does not. Not run inside an Android WebView, and not against production.
- A website page that opens a **payment** (PayU is another host) hands over to the browser; the app is not told when it ends (as before).

## Destinations

`NATIVE` = the app's own screen, `WEB` = the in-app web view, `EXT` = stays with the phone. Where each is wired: the doors and
records in `inAppSiteRoute` (`lib/app_screens.dart`), everything else in `appSitePage` (`lib/app_site_pages.dart`); a record read
by its id goes through `lib/app_records.dart` (the same code the notification openers use).

| Destination | Triggered from | Now |
|---|---|---|
| `/notifications` | every bell fallback | NATIVE: Notifications |
| `/pricing`, `/pricing/<audience>`, `/career/plans`, `/membership`, `/membership/history` | "See plans" in Learning locks, mentor plans, career and RFQ quotas, notifications | NATIVE: Membership |
| checkout of a plan (`/pricing/<slug>` with `inApp: false`) | Membership "Choose" | EXT: a payment |
| `/chapters`, `/councils`, `/events`, `/documents`, `/get-involved` | Discover doors, profile menu, banners | NATIVE |
| `/chapters/<slug>` | chapter cards' page link, share | **NATIVE (round 2)**: the chapter page (`openChapterPage`) |
| `/councils/<slug>[?tab=]` | council cards' page link | **NATIVE (round 2)**: the councils directory (the app has no page per council) |
| `/events/<slug>` | event cards, share, roundtables | NATIVE: the event sheet. **Get Tickets** (a priced event) is a payment: it opens the page with the phone (`openExternal`), never the sheet again (round 3) |
| `/mentorship/mentors/<id>`, `…#reviews` | mentor cards, mentoring links | NATIVE: the mentor profile (Recommendations tab) |
| `/mentorship/mentors` | mentorship banners | **NATIVE (round 2)**: Find Mentors |
| `/mentorship/my[?tab=]`, `/mentorship/mentor-desk` | notifications, links | **NATIVE (round 2)**: My mentoring, the mentor desk |
| `/mentorship/cpd` | the CPD notification | **NATIVE (round 2)**: Get Involved & Volunteer, where the CPD credits are |
| `/members/<slug-or-id>` | public member links, notifications | NATIVE: the member profile |
| `/network`, `/contact[?subject=]`, `/quote`, `/messaging[?c=]` | links, Events "Host an event", course enquiry | NATIVE |
| `/vendors/<id>` | supplier links | NATIVE: the supplier sheet |
| `/become-a-mentor`, `/mentorship/become-a-mentor`, `/mentorship/programmes` | mentorship banners and cohorts | NATIVE |
| `/mentorship/programmes/<slug>`, `/mentorship/groups/<id>`, `/mentorship/my/<id>` | a cohort card's "Know More", links in messages | **NATIVE (round 3)**: the programme, the group session, the pairing — the screens the notification router already opened |
| `/account/companies/new[?role=]`, `/rfq/new`, `/manage/requirements`, `/profile[?tab=security]`, `/career/saved`, `/learning/certificates` | Discover doors, profile menu, Settings | NATIVE |
| `/account/companies` | the companies notification, links | **NATIVE (round 2)**: My companies |
| `/jobs`, `/jobs?q=` | job links, "Find jobs" | **NATIVE (round 2)**: the Jobs tab (with the search typed) |
| `/jobs/<id>` | job links, shares, notifications | **NATIVE (round 2)**: the job sheet, read by id |
| `/manage/jobs`, `/manage/jobs/new`, `/manage/jobs/<id>[/edit\|/applicants]` | employer "post a job" | **NATIVE (round 2)**: the hiring screens. **Promote** is a payment: it opens `/manage/jobs` with the phone (round 3) |
| `/companies/<id>[?tab=reviews\|people\|salaries\|interviews]` | company links, share | **NATIVE (round 2)**: the company page, on that tab |
| `/products/<id>` | product links, share | **NATIVE (round 2)**: the product page |
| `/vendors`, `/services`, `/products`, `/rfq` | links, fallback tab | **NATIVE (round 2)**: the Marketplace tab |
| `/rfq/<id>`, `/manage/requirements/<id>` | requirement links | **NATIVE (round 2)**: the supplier's page / the buyer's page |
| `/community`, `/community/<slug>[?reply=]` | Forums fallback, post link, notifications | **NATIVE (round 2)**: the Forums tab; the thread page by slug, at the reply |
| `/learning`, `/learning/professional-development` | "Coming to the app" fallback, links | **NATIVE (round 2)**: the Learning tab |
| `/learning/professional-development/<code>` | course links, partner link | **NATIVE (round 2)**: the course sheet, read by code. `#enrol` (a paid place) is a payment: the website's enrolment panel, opened with the phone (round 3) |
| `/learning/assessment[/<key>]` | assessment links | **NATIVE (round 2)**: Assess Your Knowledge |
| `/learning/verify[?id=]`, `/learning/certificates/<id>` | certificate page and verify | **NATIVE (round 2)**: the verify sheet; the certificate sheet |
| `/privacy`, `/terms` | Settings, sign-up legal line | **NATIVE (round 2)**: the legal page, drawn from the website's own words bundled as `assets/legal/*.json` (`tool/legal/extract.cjs` regenerates them). Signed out too, since round 3 (`signedOutSiteRoute`: before a session the resolver only knows these two) |
| `/blogs`, `/blogs/<slug>` | blog notifications, links | **NATIVE (round 2)**: the blog list and post, from `GET /cms/blogs` |
| `/refer`, `/refer/credits` | Assess group "Earn more", notifications | **NATIVE (round 2)**: Invite (`GET /referrals/me`) |
| `/advertise` | Discover "Advertise", notifications | **NATIVE (round 2)**: Advertise: the placements, the person's price, their placements; "Talk to us" opens the contact form (buying one is a payment) |
| `/learning/partners/apply`, `/learning/partners?apply=1` | Partner courses "Apply" | **NATIVE (round 2)**: the application form (`POST /learning/partners/applications`) |
| `/company[?tab=verification\|details\|certifications]` | Jobs gates, Marketplace, Settings | WEB: the company workspace is the KYC dossier with document uploads plus offices and team admin |
| `/manage/team`, `/manage/articles`, `/manage/interviews/<id>`, `/talent`, `/invite/<token>` | team, articles, hiring-manager and talent notifications | WEB: staff-of-a-company consoles the app does not have |
| `/support`, `/support/<id>` | the support notifications | WEB: the support desk (tickets with messages, attachments, rating, reopening) is a build of its own; the API has it |
| a path nobody mapped, and `/events/<slug>/extra`, `/community/category/<x>` | a notification's `path`, an old link | WEB, on white with the app's loading state |
| `/uploads/…`, `*.pdf` / `*.ics` / `*.zip` / Office files, `/api/…`, `/payments/…` | attachments, brochures, certificates, calendar files, a payment's return leg | EXT |
| `/auth/callback` | where Google / LinkedIn sign-in returns | EXT, on purpose: the secure browser tab that started the sign-in hands it back to the app through the manifest's https intent filter, so neither the routing nor the web view takes it (`SitePolicy.externalPrefixes`). The sign-in buttons open that tab, never the web view: Google blocks embedded web views |
| Zoom / Google Meet / Teams session links | every "Join" | EXT: another site |
| employer apply links, an institute's own website, flash-card and formula resource links | Jobs, Learning | EXT: another site |
| WhatsApp, `mailto:` (course enquiry, the legal pages' contact), `tel:` | contact rows | EXT |
| LinkedIn share and "Add to LinkedIn", Google Calendar "add" | certificates, events | EXT: another site |

Counts (one row = one destination group): **NATIVE 34 rows**, **WEB 4 rows** (the company workspace, the company-side consoles, the support desk, and a path nobody mapped), **EXT 7 rows**.

## Round 3 (29 Oct 2026): payments reach the website, and nothing links to the screen it sits on

An inventory of every hand-off (194 call sites) found two faults that `SiteRoutes` had hidden:

1. **Payments that never reached checkout.** A page the app has a screen for resolves to that screen, so a payment
   button that called plain `openUrl` opened the member's own sheet again: the course sheet's "add to cart" for a paid
   place, "Get Tickets", a mentor's "Purchase Guide" / "Subscribe", the mentoring "Pay ₹… on the website" (a session or
   a programme term), the exam brief's "Pay on the website", the employer's "Promote", and the certificate's
   "Download PDF on the website". Each now leaves the app with the phone: `openExternal` (`core/util/links.dart`),
   `ExamServices.openExternal`, `JobLinks.openExternal`, `MentorshipLinks.openPayment`. PayU runs on the website and
   its return leg is the website's, so these stay there by design.
2. **Links that only opened the screen they sat on.** Removed: the job sheet's "Open on the ICR website" and "Show
   comparative applicant insights"; the course sheet's schedule link, its "See More Dates" with nothing more to show,
   and "read all N reviews on the website" (the sheet says "Showing the newest N of M."); the event sheet's "Overview"
   and its "Event page" buttons (ended, invite-only, waitlisted, a place with no pass) and the pass dialog's "Event
   page"; the certificate register's "Open the register on the website". "Manage & View" on the Events board opens the
   next booked event's sheet, where its pass and Cancel are. A product with an unreadable supplier opens the quote form.

Still the web view, each a build of its own: the company verification dossier (`/company?tab=verification`, from the
post-job gate), "Write an article" (`/manage/articles`), and a council's own page (`/councils/<slug>`, which opens the
directory; eight taps on the councils screen, a saved council and a profile's council row all land there).

## No black frame

Three things used to put a dark frame before a page, all fixed (`test/web_test.dart`):

1. The in-app web view showed the platform's black before its first paint, and, with a session to carry across, a plain static page of the site
   (`/robots.txt`) that the session is written from. It now sits under an opaque white loading state (`Key('web.loading')`, a spinner) until the page
   the person asked for has finished; the web view itself is painted white too.
2. The spinner that covers a record being read by its id (`openRecord`, `lib/app_records.dart`) had a dark 15 % scrim; it is a white veil now.
3. Pages that were the web view are native screens (above), which have no loading frame of their own to flash.

## Left alone, and why

- `lib/features/feed/home_screen.dart` hands the promoted card's link to `openSitePage` as a *path*; a full external URL there would be glued onto the site address.
- The `UpcomingTab` "coming to the app" screens in `AppShell` are defaults for a tab the shell is not given a screen for; the app gives every tab one, so they are unreachable (tests build a bare shell).
- Payments stay on the website, as before: the app cannot finish a PayU checkout (`docs/backend-requests/membership.md`).
- The council pages: the app has the councils directory, not a page per council, so `/councils/<slug>` opens the directory (a page per council is the next thing to build: updates, events, the Member Lounge).
- The legal pages are the words the website had at the last build; run `node tool/legal/extract.cjs` from the portal when they change.

## API gap

`docs/backend-requests/web-session.md`: a short-lived, web-only session for the in-app web view (so a page can renew its own token), instead of the 15-minute access token the app can hand over today.
