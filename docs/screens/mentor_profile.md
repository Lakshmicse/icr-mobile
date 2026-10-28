# Mentor Profile (Overview, Offerings, offering sheet)

Feature folder: `lib/features/mentor_profile/`. Designs: `docs/designs/mentor-profile-overview.png`, `mentor-profile-offerings.jpg`, `offering-sheet.jpg`.

## The screens

| Screen | Entry point |
|---|---|
| Mentor Profile, **Overview** tab (hero, stats, About, Career Journey, Education, Technical Mastery, Recommendations, flagship plan, pinned bar) | `MentorProfileScreen` |
| Mentor Profile, **Offerings** tab (filter chips, hint, one row per offering, flagship plan) | same screen, `ProfileTab.offerings` |
| **Recommendations** tab (not in the designs: the reviews list under the same hero) | same screen, `ProfileTab.recommendations` |
| **Offering sheet** (photo, details, programme tiles, curriculum roadmap with its term toggle, price bar) | `showOfferingSheet(context, offering)` |
| Request forms (not in the designs): free mentoring request, 1:1 session request, mobile number | `request_sheets.dart` |

## Wiring (what the shell does)

```dart
Navigator.push(context, MaterialPageRoute(builder: (c) => mentorProfileRoute(c, mentorProfileId)));
```

* `Widget mentorProfileRoute(BuildContext context, String mentorId)` creates a `MentorProfileController` over `ApiMentorProfileRepository(api: context.read<ApiClient>())`, or `DemoMentorProfileRepository()` when `AppConfig.demo` (`--dart-define=FEED_SOURCE=demo`), provides it, and returns `MentorProfileScreen(mentorId:, onBack: Navigator.maybePop)`.
* `mentorId` is the **mentor profile id** (`MentorProfile.id`: what `GET /mentorship/mentors` lists and what a member profile's `mentorProfileId` carries), not the user id.
* `MentorProfileScreen({required String mentorId, required VoidCallback onBack})` reads its `MentorProfileController` from `Provider` and calls `load()` once. A host that wants the controller itself (a test, a different shell) provides it and builds the screen directly, as the goldens do.
* `showOfferingSheet(BuildContext context, MentorOffering offering)` reads the page's `MentorProfileController` from `context` (for the mentor's featured plan, the programme's other terms, and to run the actions), like `showJobSheet` reads `JobsController`.
* Nothing in `lib/app.dart`, the shell or `pubspec.yaml` was touched, and no public constructor changed in the 23 Oct refinement. The profile is reached by pushing the route; no tab hosts it.

## Files

`mentor_profile_models.dart` (what the screens draw), `mentor_profile_repository.dart` (abstract), `api_mentor_profile_repository.dart`, `demo_mentor_profile_repository.dart` (the designs' sample content), `mentor_profile_controller.dart`, `mentor_profile_screen.dart` (screen, tabs, `mentorProfileRoute`), `offering_sheet.dart`, `request_sheets.dart`, `mentor_profile_actions.dart` (what each button does), `mentor_profile_format.dart` (₹, dates, next slot, tags and labels), `mentor_profile_styles.dart` (colours and type), `widgets/` (hero, ring, tabs, overview sections, offerings rows, plan card, bottom bar).

## Endpoints used (all `/api/v1`)

| Purpose | Call |
|---|---|
| The public profile: name, headline, bio, photo, cover key, years, city, modes, languages, competencies, topics, rating, counts, `isTopMentor`, `career.currentRole`, `experience`, `education`, `availabilityBlocks`, `timezone`, `openSlots`, `viewer` | `GET /mentorship/mentors/:id` |
| 1:1 sessions, resources, written consultations | `GET /mentor-services/mentors/:id` (the storefront; `live: false` sells nothing) |
| Ongoing plans and structured programmes (with syllabus) | `GET /mentor-plans/by-mentor/:id` |
| The viewer's own plan requests (marks a programme already asked for) | `GET /mentor-plans/subscriptions/mine` |
| The mentor's upcoming group sessions | `GET /mentorship/group-sessions?hostId=<user id>&limit=6&page=1` |
| Named testimonials (filtered to this mentor) | `GET /mentorship/testimonials` |
| Anonymous written feedback from mentees | `GET /mentorship/mentors/:id/feedback` |
| The bell | `GET /notifications/unread-count` |
| Whether a mobile number is on file | `GET /auth/me` |
| **Ask for free mentoring** | `POST /mentorship/requests` `{ mentorProfileId, message, phone? }` |
| **Ask for a 1:1 session** (the mentor sets the time) | `POST /mentor-services/:serviceId/request` `{ topic, mode, preferredTimes?, phone? }` |
| **Request a programme** | `POST /mentor-plans/:planId/request` `{ phone? }` |
| **Take a free plan** | `POST /mentor-plans/:planId/subscribe` `{ phone? }` |
| **Take a free resource** | `POST /mentor-services/:serviceId/checkout` `{}` |
| Open a live pairing's thread | `POST /mentorship/:mentorshipId/conversation` |

The app never withdraws anything: a request already in play reads "Requested" and opens the website's purchases. The live tests undo what they do through `POST /mentor-services/purchases/:id/withdraw`, `POST /mentor-plans/subscriptions/:id/cancel`, `POST /mentorship/requests/:id/withdraw` and `PATCH /users/me { phone: '' }`.

Everything that moves money stays on the website, which already runs PayU: a **paid** resource opens `/mentorship/mentors/:id?book=<serviceId>` (the profile's own `?book=` deep link opens that service's checkout), a paid plan opens the mentor's profile, a group seat opens `/mentorship/groups/:id`, an accepted programme is paid under `/mentorship/my?tab=purchases`. The messaging thread, the mentorship and the review list are also the website's (`openSitePage`).

## What the buttons do (precedence follows the website's `MentorProfile.tsx`)

Hero button and pinned bar (`heroActionsFor`): the mentor's own profile: "Edit My Profile" (website); the mentor lists a **free 1:1 session**: "Book Trial (₹0)" on the hero and "Book Free Trial" on the bar (both as the designs word them) opens the session request (then "Trial Requested", greyed); otherwise a live pairing: "Open Our Mentorship"; a request in play: "Request Pending" (greyed); no mentee profile: "Tell Us Your Goals First" (website `/mentorship/my?tab=goals`); plan limit: "See Plans"; at capacity: "At Capacity" (greyed); else "Request Mentoring" (the free request form).

"Send Message" (and the bar's chat icon): a live pairing: the thread is opened with `POST /mentorship/:id/conversation` and continues on the website's `/messaging?c=`; otherwise the mentoring request form (the website sends cold messages the same way: there is no ungated DM), or, when the API blocks the viewer, its own `blockedReason` verbatim. Hidden on the mentor's own profile.

"Verified Mentor" on the cover is a badge that explains itself on tap ("ICR has reviewed and approved <name>'s mentor profile"); it is drawn only while the profile is `APPROVED`.

**Offering buttons** (`runOfferingAction`): a single session ("Book Now") and a written consultation ("Ask Query") open the session request form; a programme ("Book Now") sends `POST /mentor-plans/:id/request` (a phone sheet first when the profile has no number) and the row then reads "Requested"; a **free** resource ("Get Guide") is taken in the app (`/checkout {}`); a **paid** resource ("Purchase Guide"), a paid plan ("Subscribe", "Apply for …") and a group seat ("Reserve Seat") open the website. A session or programme already asked for is never asked for twice: its button reads "Requested" and opens the website's purchases.

**A refusal is a refusal.** The controller reports an API refusal as `CheckoutState.refused` with the API's own sentence (it used to ride as `completed` plus a message, and a sheet closed behind it). When that sentence is "add a mobile number" (`isPhoneRefusal`: the number was cleared on the website since the profile loaded, or `/auth/me` could not be read), the session and mentoring forms reveal their phone field and the programme path opens the phone sheet and sends again.

**The offering sheet.** The photo, title, chips, tiles and roadmap are the offering's. A programme the mentor lists once per length (same title: "1 Month", "3 Months", "6 Months") is **one row**, its shortest term; its sheet toggles between the terms, and the roadmap, the tiles, the price on the bar and the button all follow the term on show (the request goes to that term's plan id). With one term there is no toggle. "Plans" opens the ongoing plan's own sheet. The bar says "Starts at ₹X /mo + applicable taxes" for a plan, "Price ₹X" for a programme or a session, "Trial: ₹0" beside a free session or free programme; the button reads "Book Trial (₹0)" when free, else the offering's word ("Book Now", "Subscribe", "Purchase Guide").

Optimistic actions roll back on an `ApiError` and show its message: the mentoring request (button goes to "Request Pending", restored on refusal) and the session request (the row says "Requested").

## Controls and what proves each

Widget tests are in `test/mentor_profile_test.dart`, live tests (the local API, seeded design mentor) in `test/live/mentor_profile_live_test.dart`.

| Control | What it does | Proved by |
|---|---|---|
| Back | `onBack`; the route pops the profile | widget: "Back leaves the page…", "the route helper: Back pops the profile" |
| Bell | the website's `/notifications`; the red dot is the API's unread count | widget: same; live: "the bell" |
| Verified Mentor | explains the badge; absent unless `APPROVED` | widget: "Back leaves the page…", "Verified Mentor is drawn only for a profile ICR approved"; live: profile reads as the design |
| Overview / Offerings / Recommendations | switch the content under the hero | widget: "the three tabs show their own content" |
| "…read more" | unfolds the bio | widget: "...read more unfolds the bio" |
| "View all 42 verified reviews" | the website's `/mentorship/mentors/:id#reviews`; 42 is the API's `ratingCount` | widget: "View all verified reviews…"; live: Recommendations |
| Pull to refresh, "Try again" | reload the profile | widget: "pull to refresh…", "a profile that could not load offers Try again…" |
| Offering filters (All, 1:1 Mentorship, Group Sessions, Resources) | narrow the rows; a filter with nothing behind it says so | widget: "the offering filters…"; live: Offerings |
| Book Trial (₹0) / Book Free Trial | session request form; `POST /mentor-services/:id/request`; row and buttons then read "Requested" | widget: "the trial button…", "the pinned bar and the hero ask the same thing"; live: "Book Trial (₹0): a session request is kept…" (as Pooja, then withdrawn) |
| Request form validation | topic ≥ 20, message ≥ 30 characters, number ≥ 8 digits when asked; the API's own limits | widget: "the trial button…", "the mentoring request: checks its length…"; live: "the request forms refuse a short message…" |
| Phone needed | the form asks for a number when the profile has none, and when the API says it is missing; the number is saved with the request | widget: "a session form without a number…", "an API that finds the number missing…", "a programme asked for with no number…"; live: "the session form needs a number…" (as Dev: refused, kept with a number, then withdrawn and the number cleared) |
| Send Message / chat glyph | mentoring request form; live pairing: the thread; blocked: the API's reason; owner: hidden | widget: "Send Message…", "the chat glyph…", "the mentoring request…"; live: "Send Message: a mentor you are paired with…" (as Yash), "the mentoring request…" (as Pooja, withdrawn) |
| Hero button by standing | Request Mentoring / Open Our Mentorship / Request Pending / At Capacity / See Plans / Tell Us Your Goals First / Edit My Profile | widget: "with no free session the main button follows where the viewer stands", "Send Message: …the owner has none" |
| Book Now (session) / Ask Query | the request form for that session | widget: "each offering button does its own job" |
| Book Now (programme) | `POST /mentor-plans/:id/request`; "Requested" and a follow-up on the website | widget: "a programme: Book Now sends the request…"; live: "a programme asked for is kept…" (the free and the 3-month term, then cancelled) |
| Get Guide (free resource) | `POST /mentor-services/:id/checkout {}`; "Added to your purchases" | widget: "a free guide is taken in the app…"; live: "Get Guide…" (**not undone**: the API has no way to give a purchase back; a repeat returns the same purchase) |
| Purchase Guide (paid), Apply for Pro Mentorship, Subscribe | the website; nothing is bought in the app | widget: "each offering button does its own job", "the preview link and the row open the sheet…"; live: "Purchase Guide (paid) and Apply for Pro Mentorship…" (counts of purchases and subscriptions unchanged) |
| Reserve Seat | the website, on that session's page | widget: "a group session's seat is reserved on the website…" |
| Inspect … preview / tap a row | opens the sheet | widget: "the preview link and the row open the sheet…" |
| Sheet: term toggle | roadmap, tiles, price and button follow the term | widget: "the sheet toggles between the terms…", "one term has no toggle"; live: "the sheet's roadmap…" |
| Sheet: Plans, Book Trial, dismiss | the plan's sheet; the session form; closes on a tap behind it | widget: "the preview link and the row open the sheet…", "the sheet's Book Trial…", "an open sheet closes…" |

## What the API cannot give, and what is shown instead

| Design element | What the app shows |
|---|---|
| "Top 5% Mentor" | `isTopMentor` as **"Top Mentor"** (rating ≥ 4.5 from ≥ 3 mentees and ≥ 10 sessions). The API has no percentile. |
| "26+ Sessions Conducted" | `sessionsCompleted`, as "26+" from ten sessions up ("at least", true of an exact count) and the plain number below. |
| "12 Active Mentees" | `menteesHelped` (completed mentorships) captioned **"Mentees Helped"**; the API has no count of live mentees, and calling the 12 "active" would be wrong. |
| "Across 4 countries" | No such data: a mentor's mentees are private, and the public profile has no country for them. Shows "N slot(s) open" or "At capacity" from `capacity − active`, in the same band and type. |
| Cover photo | `User.coverImage` is a preset key *or* an upload path. A path is drawn; a preset key (the mobile app has no preset art) falls back to the navy gradient. |
| Round photo with the MENTOR ring | The ring is drawn in code around `avatarUrl` (initials when there is none). |
| "✓ Verified Mentor", blue seal | Shown while the profile is `APPROVED`, which every listed mentor is. |
| "Supply Chain Leader at **Microsoft** • Ex-Tata Aerospace • BITS Pilani • IIT KGP" | The API derives `career.currentRole` from the first current role of the career history, which the design's Career Journey spends on a different title ("APAC Lead, Azure Planning & Execution"). The line is therefore **the mentor's own headline** when it already names the current employer (the seed's headline is exactly the design's line), with that employer set in bold; otherwise "title at **organisation** • headline", as the website draws it. Nothing is repeated. |
| "15+ Yrs Exp" | `yearsExperience` as "N+ Yrs Exp" (hidden when 0). |
| "Hyderabad (Hybrid)" | `city` with the mentor's meeting modes: **"Hybrid"** when they offer both a meeting in person and a remote one, otherwise the modes themselves ("Video / Phone", "In person"). |
| "Next Slot: Tomorrow, 7:00 PM" | The website's `nextSlot` over `availabilityBlocks` in the mentor's `timezone` (a window already running does not count). It does not subtract bookings (the exact bookable times are `GET /mentors/:id/slots`, unused here), takes the zones ICR mentors use at fixed offsets (no daylight saving) and falls back to the phone's clock for an unknown zone. Hidden when the mentor set no hours. |
| "Book Trial (₹0)" | There is no "trial" product. It is the mentor's **free 1:1 session** (a `ONE_ON_ONE` service priced ₹0) when they list one; otherwise "Request Mentoring". |
| "15+ Years Leadership" at Career Journey | **"N+ Years Experience"** from `yearsExperience`; the API has no "leadership" years. |
| Role length "2 yrs 4 mos", "10 Yrs" | Computed from the role's start and end dates. A past role's "10 Yrs" and "3 Yrs" match; the current role's length is true *today* ("4 yrs 4 mos" for a role begun in July 2022), where the design's "2 yrs 4 mos" is the day the mock was drawn. |
| "Aerospace & Defense CoE", "Global Operations Practice" (the line after the dates) | The role's `city` (the API has no unit or practice); the seed writes the design's words there. |
| Career dots | The two most recent roles get blue rings joined by a line segment each; older ones a faint disc with a pale core (a drawing choice, measured on the design; the API has no emphasis). |
| "Batch of 2009 - 2011 • Operations & Strategy" | Education years and `fieldOfStudy`. |
| "Domain Expertise" / "Softwares & Frameworks" | `competencies` / `topics`, captioned as the design. The API has no software list: for a mentor whose topics are not tools the second caption is the design's wording over their focus areas. |
| Reviewer "Dev Mangtani • Operations Analyst • 1 yr ago", five stars | A curated testimonial carries a name, title and photo but **no date and no rating** (`MentorTestimonial` has `createdAt`; the public `GET /mentorship/testimonials` select leaves it out). It reads with the **mentor's rating as stars** (5.0 draws five), and shows its age as soon as the API sends `createdAt` (the app already reads it; the seed backdates the testimonial by about a year). Mentee feedback carries rating and date but no author ("A mentee • 1 yr ago"). "View all 42 verified reviews" is `ratingCount` and opens the website's `#reviews`. |
| "FLAGSHIP COHORT / Pro Mentorship Tier / ₹12,500 /mo" | The mentor's cheapest **ongoing plan** (per-month price, title, `inclusions` in the mentor's words). Kicker reads "ONGOING PLAN" (a plan is not a cohort, and "flagship" would claim more than the data says). With no ongoing plan the card is not drawn. With no inclusions it lists what the plan data says (sessions a month, term, thread). |
| "Only 2 slots left" | Plans have no seat count. Shown from the mentor's open mentoring slots when 3 or fewer remain ("Only N slots left"); otherwise absent. |
| "Apply for Pro Mentorship →" | "Apply for {title}" without a closing "Tier" or "Plan" (`applyName`), as the design's button is worded: a free plan is taken in-app; a paid one opens the website's checkout. |
| Offering tags "BEST SELLER", "15 Min" | "BEST SELLER" is 5+ sales of a service or 5+ subscribers of a plan; beside it the length stands alone ("15 Min"), otherwise a session reads "15 Min • 1:1 Video". |
| Offering tags "Digital Guide", "Instant Download", "Curated Prompts", "PDF & Templates" | The mentor has no tag field. A resource is tagged from its **file** (`resourceTag`): a real extension names its kind ("PDF Guide", "Templates Pack", "Spreadsheet"…); a plain name the mentor wrote ("Curated Prompts", "PDF & Templates") is kept, as the website shows a resource by its file name; a slug (`linkedin-niche-bible`) reads "Digital Guide" and, since that says nothing about the file, is joined by the green "Instant Download". |
| "Async Query • 24h TAT" and "Ask Query" (SOP review) | **Not reachable.** Written consultations are retired (`RETIRED_MENTOR_SERVICE_TYPES`): the API refuses to list one, so the seed's SOP review is a free checklist, tagged "PDF Guide" with "Get Guide". (The `QUERY` mapping stays for a storefront that still serves one.) |
| "Inspect 4-week diagnostic preview ⌄" | Only a programme with a syllabus has a preview: "Inspect N-session syllabus preview" (about as wide as the design's). |
| Offering sheet's "DISCOVERY CALL" pill | Derived from the kind: "1:1 SESSION" / "FREE SESSION", "1:1 MENTORING" (a programme), "ONGOING PLAN", "RESOURCE", "GROUP SESSION", "WRITTEN CONSULTATION". |
| Sheet photo and "★ 4.96 (128 reviews)" | The offering's `coverUrl` (navy gradient without one); a service's own `rating` and `ratingCount` when it has ratings; a plan's photo carries the **mentor's** rating (plans have none of their own: "★ 5.00 (42 reviews)"). |
| Sheet title and copy | The offering's `title` and `blurb`. (The design's sheet title "What's going wrong?" differs from its row title "What's going wrong?" Discovery Call; only the demo has both.) |
| "👤 1:1 Live Call · 🕓 30 Minutes · 📅 Mon, Thu, Sat slots" | The mode ("1:1 Video call"), the session length and the weekdays of the mentor's availability blocks. |
| "Program Details" tiles ("2 Sessions / Week", "Unlimited support"…) | The API has no such tiles. Live tiles are derived from the data: a programme: session count, minutes per session, the window to finish in, private thread; a plan: sessions a month, minutes, term, thread; a session: "1 Session", minutes, mode, thread; a resource: instant download and the file; a group session: date and seats left. |
| "Curriculum Roadmap" (1 / 3 / 6 Months, "① Root Cause Analysis & Strategy — Month 1", four weeks) | The API has **no weekly curriculum** and no phases. A programme's roadmap is its syllabus (`modules`), one block per term: "N-session syllabus" with the term's span ("Month 1", "Months 1-3") and a line per session, "Session N: title" (a title the mentor numbered themselves, "Week 2: …", is left as written). The toggle is the programme's terms (plans sharing a title), shown only when there are two or more. Every other offering has no roadmap and the section is hidden. |
| "Starts at ₹12,500 /mo", "Trial: ₹0", "+ applicable taxes", "Plans" | "Starts at" is the mentor's ongoing plan per month; "Trial: ₹0" appears for a free session or free programme; "+ applicable taxes" for plans (they carry 18% GST, services none); "Plans" opens the plan's sheet. For a paid term the left side shows that term's own price and note. |
| The design's Offerings tab has no pagination, Share, Save, Similar mentors, Credentials | Not drawn (not in the designs). |

## Where the brief for this pass differed from the PNGs

Two wordings the brief quoted are not in the PNGs, so the PNGs were followed: the **pinned bar** reads "Book Free Trial" in both `mentor-profile-overview.png` and `mentor-profile-offerings.jpg` ("Book Trial (₹0)" is the hero button and the sheet's bar), and the plan button reads "Apply for Pro Mentorship →", not "… Tier →".

## The seed (Srikanth's rows in `tool/seed/mentorship.ts`)

`SRK` and the rows built from it: the headline is the design's hero line; the career history is exactly the design's three roles (first title "APAC Lead, Azure Planning & Execution" at the linked "Microsoft Corporation", hyphens as the design draws them) and three education rows (BITS twice); the storefront is the five rows after the first (a free 15-minute interview session, three resources whose file names give "Digital Guide", "Curated Prompts" and "PDF & Templates", a free SOP checklist); the first row is the **diagnostic programme in three terms** (1 month free, four weeks as the design; 3 months ₹14,999; 6 months ₹24,999; the 1-month term has six subscribers, so it reads BEST SELLER); the Pro Mentorship Tier at ₹12,500; four mentee reviews about a year old and the Dev Mangtani testimonial (backdated). `--remove` still undoes all of it (every id carries the `dsgn-mentorship-` prefix and cascades from the profile; a plan or service something was bought from is retired instead of deleted when the script changes).

## Demo content

`DemoMentorProfileRepository` holds the three designs' sample content exactly: Srikanth Sriramagiri, the three roles, three education rows, the four-plus-four chips, the review, the six offerings (prices ₹499 → ₹9, ₹399 → ₹9, ₹599 → ₹9, free sessions), the Pro Mentorship Tier at ₹12,500 with "Only 2 slots left", the sheet's roadmap (1 / 3 / 6 months; only the 1-month weeks are in the design, the longer terms add plausible modules) and the sheet's own title and copy. It goes through the same code paths as live data (the headline carries the hero line, the modes are "Video" and "In person" behind "Hybrid"); only its "Next Slot" is the design's fixed text and its "Active Mentees / Across 4 countries" and "15+ Years Leadership" are the design's own words. `--dart-define=FEED_SOURCE=demo`.

Artwork is cut from the design exports and stored under `assets/images/demo/mentorship/` (the registered directory), prefixed `profile_`: `profile_cover.jpg` (cover, with the baked-in avatar and "Verified Mentor" pill painted out), `profile_avatar.png` (photo, 99 px), `profile_reviewer.png` (30 px, as small as the design draws it), `profile_offering_cover.jpg` (the sheet's photo, with its baked-in pill and rating blurred; both are redrawn in code).

## Tests and goldens

* `test/mentor_profile_test.dart` (widget tests): formatting and labels (₹ grouping, role lengths, next slot across zones, bio paragraphs, `sessionsLabel`, `resourceTag`, `applyName`, `stepLabel`), the Hybrid label and the hero's role line, the API mapping through an `HttpClientAdapter` table (profile, offerings order and tags, hidden types dropped, reviews with stars and dates, request bodies, buy outcomes, the pairing thread, a pending programme), the controller (featured plan, a programme in several terms as one row, filters, rollback on refusal, a refused purchase), and a widget test per control (see the table above). The website is intercepted at the `url_launcher` channel, so a test says which page a button opens.
* `test/live/mentor_profile_live_test.dart` (live): the local API with the seeded mentor, as Bharat, Pooja, Dev and Yash. Run `flutter test test/live/mentor_profile_live_test.dart`. Writes are undone (a session request is withdrawn, a programme request cancelled, a mentoring request withdrawn, a number cleared) except taking a free resource, which the API cannot undo and which returns the same purchase on a repeat. The API limits sign-ins per minute, so the file waits out a 429 rather than failing on it.
* `test/golden/mentor_profile_golden_test.dart` (tag `golden`) renders the three screens from demo content and writes `build/screens/mentor_profile_overview.png` (390 × 2272 dp), `mentor_profile_offerings.png` (390 × 1595) and `offering_sheet.png` (390 × 951.6), plus Flutter goldens in `test/golden/goldens/`.

**Measured against the designs** (the design resized to 780 px; text-line centres and rules, 2 px = 1 dp): on the live-shaped Overview every text line from the hero to the plan card is within 1 dp of the design and nearly all within 0.5 dp (hairlines within 0.5 dp, the "View all" bar's top and the plan card's top within 0.5 dp); on Offerings every row, tag, title, blurb, button and rule is within 0.5 dp and the plan card's top is on the design's pixel; the sheet's photo, title, copy, chips, tiles, roadmap and bar are within about 1.5 dp. Measured on the design this pass: the timeline ring is 14.6 dp with a 4.2 dp ring, each line 2 dp wide starting 1.3 dp under its dot and stopping with the row's text, the oldest dot a 13 dp faint disc with a 6 dp core on the same axis; the "Present" pill hangs 2.5 dp below the title's centre; the Offerings info bar is 42 dp.

Remaining deviations: type is the bundled faces sized by width, so glyphs run about 1 px shorter than the mock's; the sheet's handle is the shared 40 × 4 dp bar (the design's is wider); the sheet's top corners are 16 dp (the design's are about 20); the avatar ring's thickness is measured to about 1 dp; Offerings' info-strip glyph is Material's "touch app", the nearest to the design's hand; the bio and role descriptions wrap at fixed widths (305 and 303 dp) tuned so lines break where the design's do.

## Left out

* In-app payment (PayU return leg): paid resources, plans and group seats continue on the website.
* Picking a time when requesting a 1:1 session (the mentor sets it on accepting, as on the website); `GET /mentors/:id/slots` is not used.
* Withdrawing or following up a request (pay, decline-time, reschedule), the review dialog, and a session's own page: the website's `/mentorship/my/sessions/:id`.
* Save, share and "similar mentors" on the profile, credentials and chapter rows: not in the designs.
