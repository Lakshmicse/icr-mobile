# Learning

**The Learning tab is now the Learning Center hub ([learning_hub.md](learning_hub.md)); the course grid below is its "ICR Courses" door, pushed over the shell, and the course sheet is what a course card opens from the grid, from the hub's rail and from a partner institute's page.** The course sheet and the grid, built from `docs/designs/course-page.png` (the Course page: a 390 dp-wide frame exported at 378 px, 0.9692 px/dp). The tab's catalogue has no design of its own: it is a **grid of course cards** drawn on the Events agenda's frame, so the tabs read as one app (see "The catalogue grid" below).

## Screens

- **`LearningScreen({required VoidCallback onBack, String title = 'Learning', LearningRoutes routes})`** — the catalogue grid (the hub's ICR Courses door passes `title: 'ICR Courses'`; the constructor `LearningScreen({required onBack})` still works): `TitleBar` with the bell, the kit search field (it opens showing the controller's search, so the hub's "View All" can carry its search in), a row of chips (My courses, Mock exams, Certificates, Flash cards, Knowledge center), then every published course as a **card in a two-column grid** under its kind's heading ("Professional development" for `DEVELOPMENT` courses, "Certification programmes" for `ASSESSMENT`). A card shows the cover with the course's pill, the title (two lines), the awarding body with its logo, a meta line, and a footer with the price, the member's place and the CPD credits (see below). A section with a single course draws one half-width card at the left. The search narrows the loaded list **as you type** by title, summary, code and awarding body. "My courses" is a toggle: on (blue chip), the grid is only the courses the member holds a place on, headed "My courses", each card's meta line the run the place is on ("Aug 23 - 27, 2027 • Riyadh, KSA"). Pull to refresh. (The catalogue loads in one request, so there is no paging.)
- **`Future<void> showCourseSheet(BuildContext context, Course course)`** — the course over the tab through `showDetailSheet`: title, summary, cover with its pill, the tab strip (Face to Face On site Training | Live Virtual Training), "Select Date" with the "2027 Schedule" link, the 2 × n grid of runs with the "Suggest A Date & Location" tile last, "See More Dates →", ADD TO CART, DOWNLOAD BROCHURE, Course Overview (folded after four lines, "show more"), Key Takeaways (numbered timeline), Course Outline ("view full outline", module accordion), Who Should Attend (chips, two across), the enrolment specialist's block, About the Certificate, the reviews, and the pinned bar (brochure glyph + "add to cart").

## Wiring

```dart
ChangeNotifierProvider<LearningController>.value(
  value: hub.learning, // the controller the hub loaded
  child: LearningScreen(onBack: back, title: 'ICR Courses'),
)
```

The hub (`LearningHubScreen`, see [learning_hub.md](learning_hub.md)) makes the `LearningController` and gives the pushed grid the same one, so what it loaded is not read again. `app.dart`'s own `ChangeNotifierProvider<LearningController>` is no longer read by anything. The grid still reads `LearningController` from `Provider`, and so does the sheet: it reads `LearningController` from `Provider` (for the repository and to keep the list in step) and makes its own `CourseSheetController`. `LearningController.start()` runs on first build.

`LearningRepository` changed (nothing outside this feature implements it): `latestReview` became `reviews(course) → CourseReviews { items, total }`, and `enquire` takes an `EnquiryKind` (+ `company`, `headcount`).

## Endpoints

| Call | Used for |
| --- | --- |
| `GET /learning/courses` | the list (published courses; the payload carries each course's open runs, provider and seat figures). **It has no `search` parameter** (`CourseQueryDto` is `kind`, `level`, `providerId`; a `?search=` is silently dropped and every course comes back), so the search box narrows the loaded list. |
| `GET /learning/courses/:code` | the sheet (runs with their enrolment specialist, modules with topics, outcomes, audience, brochure, `certificateEnabled`, `cpdCredits`, `deliveryMode`) |
| `GET /learning/me/enrollments` | the member's places, with each place's run (`batch`: dates, location): "Enrolled" on rows, the CONFIRMED tile, the button's state, "My courses" |
| `GET /learning/courses/:code/reviews?page=1&limit=20` | the testimonial and the list behind "see all N reviews" (published only, newest first, `meta.total`) |
| `POST /learning/courses/:code/enroll { batchId? }` | ADD TO CART on a free course, or a waitlist place on a full run (both free) |
| `DELETE /learning/courses/:courseId/enroll` | withdraws a place (by course **id**). The app has no control for it; the live test uses it to undo what it took. |
| `POST /learning/courses/:code/enquire { name, email, message, kind?, company?, headcount? }` | "ask the institute", "Suggest A Date & Location" and "take this course as in-house" (a `CORPORATE` lead). Name and email come from `GET /auth/me`. Throttled to 5 a minute; refuses a course with no institute (`This course is run by ICR — use the contact page.`). |
| `GET /notifications/unread-count` | the bell |

A **paid place** is bought on the website: ADD TO CART opens `/learning/professional-development/<code>#enrol` (the site's enrolment panel, which quotes, applies codes and plan places and runs PayU — the app has no gateway leg). `EnrollmentService` refuses `enroll` on a paid course while payments are configured, which is what the button avoids; a full run's waitlist stays free and is taken in the app.

## Every control, and the test that proves it

Widget tests are in `test/learning_test.dart` (a recording fake repository; browser and mail hand-offs are caught on the `url_launcher` channel and asserted). Live tests are in `test/live/learning_live_test.dart` (`flutter test test/live/learning_live_test.dart`, API up).

| Control | What it does | Proved by |
| --- | --- | --- |
| Back | `onBack` (the hub pops the grid; with no hub, the shell goes Home) | *the Learning tab › Back goes back, the bell opens the notifications page* |
| Bell | opens `/notifications` on the website; the dot is `GET /notifications/unread-count` | same test; live *the bell reads the unread count* |
| Search | narrows the loaded list as you type (title, summary, code, awarding body); the clear button and "Clear search" restore it. The API cannot search | *the search narrows the list as you type…*; controller test *the search matches title, summary, code and awarding body…* (asserts no second API call); live *search: the API ignores a search parameter…* (proves `?search=` returns every course, then narrows the real catalogue) and *the search narrows the grid; the clear button gives it back* (cards on screen) |
| My courses chip | toggles the list to the member's own places, read afresh from `GET /learning/me/enrollments` as it goes on; the empty state offers "Browse courses" | *My courses shows the places the member holds…*, *My courses with no places says so…*, *My courses shows the places the member holds as cards, with their run*; live *My courses shows the member's places as cards…*, *Bharat's seeded place reads CONFIRMED…* and, as Pooja, the place she takes appears under My courses |
| Mock exams · Certificates · Flash cards · Knowledge center | open the Learning Center screens in the app (`MockTestsScreen`, `CertificatesScreen`, `FlashCardsScreen`, `KnowledgeCenterScreen`) over the shell, Learning lit; their Back returns to the grid. They were three website links (Mock tests, Certificates, Resources) until the Learning Center's screens existed; the chips are the hub's doors in a row | *the chips open the Learning Center screens in the app, not the website* (in `test/learning_test.dart`, with stand-in screens) |
| A card | opens the course sheet on that course (either column) | *a card opens the course sheet on that course*, *a card of the second column opens its own course*; live *a card opens the real course sheet* |
| The grid | one card per course in each section, two to a row on the Events frame, equal heights per row, a lone course half width at the left, no overflow on 320 dp or with very long text | *the catalogue grid* group (9 tests: frame numbers, section headings, what a card carries, every footer variant, initials and logo, long title/awarding body, a 320 dp phone, meta wrap and footer alignment); live *the grid has one card per course in each section of the real catalogue, two to a row* (counts per kind from `GET /learning/courses`, columns, the seeded card's contents) |
| Pull to refresh · Try again | re-reads the list | *pulling down reads the courses again*, *a failed load says why and Try again…* |
| The two tabs | filter the runs by delivery mode; each opens on its own first run; a tab with none says so and keeps the Suggest tile | *the two tabs filter the runs by mode…*, *a tab with no runs says so…*; live *the two tabs filter the real runs by mode…* (four face to face, two virtual) |
| A date tile | selects that run (ADD TO CART acts on it) | *a date tile selects its run…*; live same test |
| "2027 Schedule" | opens the course on the website (its full schedule) | same widget test |
| See More Dates | unfolds the runs behind the first three ("Show Fewer Dates" folds them); with nothing behind, opens the website | *See More Dates unfolds the fourth run*, *…with no further run opens the full schedule…*; live (Singapore is the fourth) |
| Suggest A Date & Location | the enquiry form (a date and location request, sent as "Date and location request: …"); ICR's own course (no institute) opens `/contact?subject=…` | *"Suggest A Date & Location" sends a date and location request…*, *ICR's own course has no institute…*; live *Suggest A Date, ask the institute and in-house reach the institute as leads, read back as staff*, and *ICR's own certification programmes have no institute: the API refuses…* |
| ADD TO CART (free) | `POST …/enroll` with the selected run; the list is told; reads "PLACE REQUESTED" | *ADD TO CART on a free course takes the selected run…*, *a refused place is put back…*; live *ADD TO CART on a free course takes the selected run as Pooja…* (reads it back through a fresh repository, checks My courses and a re-opened sheet, then withdraws it and checks the button is "ADD TO CART" again) |
| ADD TO CART (paid) | opens the website enrolment panel; takes nothing | *ADD TO CART on a paid course goes to the website…* |
| ADD TO CART (place already held) | a solid button with a check (not dimmed) that says where the place stands | *a held place reads CONFIRMED on its tile…*; live *holding two places on one course is refused by the API* |
| DOWNLOAD BROCHURE · the bar glyph | open the brochure URL; with none, a snackbar says so | *DOWNLOAD BROCHURE and the bar glyph open the brochure*, *a course with no brochure says so…*; live *DOWNLOAD BROCHURE opens a real PDF* (`%PDF-`, `application/pdf`) |
| show more / show less | unfolds the overview | *the overview folds after four lines…* |
| view full outline · module rows | opens every module / folds one | *"view full outline" opens every module; each module folds on its own* |
| Specialist email line | `mailto:` with the course in the subject: the specialist's own address on the demo, ICR's published `info@icr.org.in` live | *the specialist: the email line mails ICR…*, *on the demo the specialist's own email opens…* |
| Specialist third button | demo: WhatsApp (`wa.me`); live: "ask the institute", the enquiry form | same tests; live enquiry test |
| take this course as in-house | the enquiry form with company and "people to train", sent as a `CORPORATE` lead | *"take this course as in-house" is a corporate enquiry…*; live (the lead is read back as staff: `CORPORATE`, company, headcount 12) |
| see all N reviews | unfolds the remaining reviews; with more than the page holds, "read all N reviews on the website" | *the testimonial is the first review…*, *a course with more reviews than the page sends the rest to the website*, *one review has no list to open…*; live *the reviews are the real list…* |

Pure logic (pill rules, certificate paragraph, meta line, tile corner words, the API mapping of courses, places, reviews and enquiries, the controllers) is covered in the *formatting*, *the API source* and *the controllers* groups.

## The catalogue grid

There is no PNG for the catalogue. The user's instruction was to follow the grids they already approved, **Find Mentors** and the **Events agenda**; the card here is a cover-on-top card with pills over the cover, a two-line title and a footer, which is exactly the Events agenda card's anatomy, so it takes **that** grid's frame (the numbers are the Events screen's own: `tool/design/measure.py` on `events-home.jpg` gives a card row 371.8 dp across, which the Events code lays as two cards of 184.5 dp with 3 dp between and 9 / 9.5 dp margins, and its photo is 184.5 × 114 dp, 16:10). Find Mentors' frame (17 dp margins, 6 dp gap, 6 dp corners, 0.5 dp edge) belongs to cards with a tiny cover band and was not used.

| | |
| --- | --- |
| Row | 9 dp in on the left, 9.5 dp on the right, **3 dp between the columns**, 4 dp between rows; each row as tall as its taller card (`IntrinsicHeight`); the footer is pinned to the card's bottom so footers line up across a row |
| Card | 10 dp corners, a 1 dp `#EDEDED` edge, no shadow, white; 184.5 dp wide at 390 dp (149 dp at 320) |
| Cover | 16:10 (184.5 × 114 at 390 dp), clipped by the card's corners; the course's `imageUrl`, cropped 4 % at the foot (the seeded cover carries its own drop shadow there); with no image a navy plate with the course's initials ("CA" for "Certificate in Advanced Leadership Skills") |
| Pill | the sheet's pill text (`coverBadge`), compact: 20 dp tall, Plex 7.4 dp, tinted navy rather than white so it reads over a light cover, 8 dp from the left and 9.5 dp from the top of the cover, ellipsis rather than overflow |
| Title | Work Sans 11.6 dp bold on 15 dp lines (the Events card title), at most two lines, ellipsis |
| Awarding body | Work Sans 9.3 dp; its logo (14 dp, rounded) when the provider has one; "ICR Institute" for ICR's own courses |
| Meta line | Plex 9.1 dp, up to two lines (never cut: "Foundation • Certification programme" wraps at 390 dp); a clock with "5 days · 35 hours • In person" when the API gives a duration or delivery, a ribbon with "Foundation • Certification programme" when it does not, a calendar with the run ("Aug 23 - 27, 2027 • Riyadh, KSA") in My courses |
| Footer | wraps rather than overflows: the price — a mint **Free** pill, or the amount in blue (`₹11,800`) — then the member's place when they hold one (solid green with a tick for **Enrolled**/**Completed**, amber for **Place requested**/**On the waitlist**), then **N CPD** when the course carries credits |

Everything the old rows showed is on the card: cover, title, awarding body, meta line (with its glyph), the price and the place chip. The API has **no compare-at (struck-through) price** — `LearningCourse` carries `priceAmount` and `priceCurrency` only — so nothing is struck through; the card has no slot that would need inventing one.

Extra tests for the hub's use of it: *the title bar says what the hub called the screen*, *a controller that arrives narrowed shows its search in the box, and the grid is narrowed*. Goldens: `learning_list.png` (the demo course alone: one half-width card), `learning_grid.png` (a held course, a paid one with credits and a logo, programmes, one with no cover) and an export-only `learning_grid_320.png`. The old `CourseRow` is gone.

**Re-recorded when the tab became the hub:** `learning_list.png` and `learning_grid.png` differ from before only in the chip row (x 167–390, y 98–123 at 1x: the fourth chip, once "Resources", is now "Flash cards", and a fifth, "Knowledge center", scrolls in beside it). Everything else in them is pixel-identical.

## What the design shows that the API cannot give

| Design | API | Shown instead |
| --- | --- | --- |
| Video thumbnail with a play glyph | `imageUrl` is a still; no course holds a trailer | The cover. The seeded cover is the design's thumbnail without its label, so its baked-in play glyph shows; the app draws none (a play button that plays nothing would be a dead control). |
| "PREMIUM CERTIFICATION" pill | no marketing badge | Derived from the record (`coverBadge`): a certificate-issuing course (`certificateEnabled`) reads "PREMIUM CERTIFICATION" at Advanced, Leadership and Specialist and "CERTIFICATION" below; otherwise "<LEVEL> COURSE" (a certification programme: "<LEVEL> CERTIFICATION"). Drawn frosted over the cover, as the design's. |
| Both delivery tabs | `LearningBatch.mode` per run; the site hides a tab with no runs | Both tabs always, as the design; a tab with no runs says "No … dates are scheduled yet." over the Suggest tile. `ONLINE`/`HYBRID` fold into virtual/face-to-face as the site does. |
| "2024 Schedule" | nothing named; the public list carries only OPEN runs that start in the future | The year of the shown runs (`scheduleLabel`), so the seeded course reads **2027** (the design's 2024 is in the past and the API will not serve it). It is a link to the course on the website. |
| "CONFIRMED" on a run | no "confirmed to go ahead" fact about a run | **The member's own place**: the tile of the run they hold a confirmed (or completed) place on reads CONFIRMED in green; a requested place reads REQUESTED, a waitlist place WAITLISTED; every other run reads Open / Limited (≤ 20 % of the capacity left) / Full from the derived seats. The seed gives Bharat Buyer a CONFIRMED place on Riyadh, so the emulator reads as the design's first tile. |
| "Aug 23 - 27, 2024" | `startsAt`/`endsAt` ISO | `runDates`, in the design's wording. |
| "Suggest A Date & Location" | nothing schedules a cohort on request | An enquiry to the institute (a real lead the institute sees). |
| ADD TO CART | no cart | Free: takes the place (`POST …/enroll`). Paid: the website's enrolment panel. A place already held: a solid "ENROLLED" (or "PLACE REQUESTED", "ON THE WAITLIST") button that says where it stands. |
| DOWNLOAD BROCHURE | `brochureUrl` when the institute uploaded one | The button stays, dimmed, and says "This course has no brochure yet." without one. |
| Course Overview | `description`, else `summary`; may carry HTML | Tags stripped (`plainText`), folded after four lines. |
| Key Takeaways · Who Should Attend | `learningOutcomes`, `audience` | As drawn. Hidden when empty. |
| Course Outline lessons | `LearningCourseModule.topics` (and `summary`) | Topics as the lessons; a module with neither says "Detail for this module is on its way." |
| Specialist's photo, name, role | the run's `enrolmentSpecialist` (`PublicTrainer`) | From the first run that names one. The whole block is hidden when none does. |
| "contact@icrvinfraa.com" | a trainer's contact is never published | **ICR's own published enquiries address, `info@icr.org.in`** (the website's contact page and terms), in the same slot with the same envelope glyph, opening a `mailto:` with the course in the subject. |
| "let's talk on whatsapp" | no number anywhere (the website only has a share-by-WhatsApp link) | "ask the institute" in the same green outline button: the enquiry form (ICR's own course goes to `/contact`). The demo keeps WhatsApp. |
| "take this course as in-house" | no in-house product | A corporate enquiry (`kind: CORPORATE`, company, number of people) to the institute. |
| About the Certificate: two badges and a four-line paragraph | `provider` (name, logo, verified), `certificateEnabled`, `cpdCredits`, `deliveryMode` | The awarding body's logo as the one badge, and a paragraph worded only from those fields ("This programme is delivered through ICR as face to face and live virtual training and awarded by ICR Institute. Upon successful completion, participants receive a certificate recognizing their achievement.", plus the CPD it logs). The section is hidden for a course that issues no certificate and logs no CPD. |
| Testimonial | `GET …/reviews` (published only) | The latest review in quotes with its author and job title; a person glyph without a photo. More than one: "see all N reviews". None: nothing. |
| Bottom bar "add to cart" | — | The same action as the big button. |

Never invented: seats, ratings, dates, prices and contact details all come from the record or are left out. The one address shown that the record does not hold is ICR's own, taken from the website.

## What the seed gives the live app

`tool/seed/learning-jobs.ts` (the learning half): the course CALS (free, certificate-enabled, Leadership level, with a brochure PDF), its institute "ICR Institute" and specialist Bushra A., two modules, **six runs** (Riyadh, London, Dubai and Singapore face to face; two live virtual), **three reviews** (Charles, Anjali, Rohan) and Bharat Buyer's **CONFIRMED place on the Riyadh run**. `--no-enrol` seeds the course without his place (the sheet then reads "ADD TO CART" as the design does); re-running restores it.

- Pooja Professional is deliberately **not** enrolled: she is the persona the live tests enrol, and a person holds one place per course. (The API lets her move between runs but could not give a CONFIRMED place back: a free place taken through the API is PENDING, only the seed can write CONFIRMED.)
- With Bharat's place held, the big button reads "ENROLLED" (solid, with a check) rather than the design's "ADD TO CART": the honest state of someone who is already in.
- The API's login limit is 10 a minute per address and enquiries 5 a minute: the live file signs each persona in once, and its enquiry tests skip (with the reason) when the limit is hit. Each full run leaves three leads at the seeded institute (tagged "live test"; the API has no way to delete a lead; `--remove` deletes them with the institute).

## Demo content

`DemoLearningRepository` holds the design's course "Certificate in Advanced Leadership Skills" (code CALS): its summary, the four visible overview lines (plus one continuation paragraph so "show more" has something to show), the three runs (Riyadh Aug 23–27 flagged confirmed, London Sep 14–18 open, Dubai Oct 05–09 limited), the two modules with Module 1's three lessons, the three takeaways, the five audience chips, Bushra A. with the design's email (WhatsApp opens with no recipient), the two certificate badges and paragraph, and Charles Selasie Tuffour's review. It is free, so ADD TO CART enrols in place. Artwork cut from the design into `assets/images/demo/learning/` at the design's pixel scale: `course_cover_clean.png` (360 × 155: the thumbnail **without** its label, so the pill is drawn by the app and the demo golden checks it too), `specialist.png` (60 × 60), `badge_icr.png`, `badge_partner.png`.

## Goldens, measurements and deviations

`test/golden/learning_golden_test.dart` exports to `build/screens/` (all at 2x, with shadows drawn with real blur: `flutter_test` otherwise draws them hard-edged, which hides the pinned bar's, the selected tile's and the title bar's):

- `course_sheet.png` — demo content at the design's frame (390 × 2063.5 dp).
- `course_sheet_live.png` / `course_sheet_live_open.png` — **the sheet as the live API draws it**: built through `ApiLearningRepository` from recorded responses of the local API (`test/fixtures/learning/`: the seeded CALS, its reviews, Bharat's place), with bundled pictures standing in for the network ones. The first has Bharat's CONFIRMED place on Riyadh, the second no place ("ADD TO CART").
- `learning_list.png`, `learning_grid.png`, `learning_grid_320.png` — the tab with the demo course, with a fuller catalogue (every card variant), and at 320 dp (export only).

Compared with the flattened design at 780 px (`python tool/design/compare.py flat780.png build/screens/course_sheet.png`): every band starts within about 1.5 dp (most within 1); the bands' ends differ by up to 2 dp only because the design's face is taller than the width-fitted type. Measured from the design in this pass:

- **Cover pill:** frosted glass, 133 × 25.8 dp, 12.4 dp in from the cover's left edge and 15.2 dp above the bottom of its 160 dp frame, corners 3 dp; white 20 % over a blurred (σ 3) picture with a white 20 % hairline (fitted from the design's pixels over the dark jacket and the table); IBM Plex Sans 700 at 8.6 dp, no tracking (cap height 6.2 dp, about 109 dp of ink), 12.4 dp each side of the words. (It was a dark 23 dp pill in Plex 7.5 dp with 0.8 tracking.)
- **Date tiles:** 174 × 74 dp (were 175 × 75), 10.3 dp across and 8.5 dp down; text rows 11 / 6 / 7.5 dp apart (the corner row sat 3 dp low). Selected: white fill, 2 dp ring `#DCDFE0`, soft shadow below (was a tinted fill with a 1.5 dp edge); others a 1 dp `#E7ECF3` edge. CONFIRMED in `#006C49` bold.
- **Pinned bar:** 50.6 dp tall; the button 123 × 35 dp (was 129 × 39), 8.3 dp from the bar's top and 15.5 dp from the right edge, label Work Sans 700 at 12.1 dp (was 12.5); the brochure glyph centred 223 dp from the left in the ink colour (was grey); the shadow fades over 11 dp (alpha 0.10, blur 16), fitted to the design's rows.
- **Glyphs** are Material Symbols at the design's weight, not Lucide: `calendar_month` (13 dp, w700), `shopping_bag` (18 dp w600; 16 in the bar), `download` (18 dp w700), `keyboard_arrow_down` (18 dp w700 in a 12 dp box so it does not push "show more" taller). A closed module's ring is grey (`#656A75`), blue when open. "See More Dates" arrow 15 dp. The tab strip sits 1 dp lower, the Select Date row 1 dp lower.

Remaining differences: the kit's sheet handle (40 × 4 dp) is where the design has a 50 × 7 dp one; the quote's italic is synthesised (no italic Plex bundled); one certificate badge, not two, and a shorter paragraph on a live course (nothing true to fill the second); the live specialist's email line is ICR's, not the specialist's.

Also found on the way: the pinned bar's fixed 123 dp button overflowed by 3 dp for a longer word ("enrolment closed"), which every certification programme shows; it now keeps 123 × 35 dp for "add to cart" and widens for longer labels (*the pinned bar's button is the design's 123 × 35 dp…*). Certification programmes have no runs, so their sheet reads "ENROLMENT CLOSED" although the API would take a course-level place (`POST …/enroll` without a run): that behaviour predates the grid and is unchanged.
