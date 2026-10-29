# Mentoring after the first request: My mentoring, a pairing, purchases, group sessions, programmes

Code: `lib/features/mentorship_my/`. The mentor's side lives in two sibling folders with their own notes: [`become_mentor.md`](become_mentor.md) (`lib/features/become_mentor/`) and [`mentor_desk.md`](mentor_desk.md) + [`mentor_offerings.md`](mentor_offerings.md) (`lib/features/mentor_desk/`).

Tests (widget tests run against a fake API in the real response shapes; each fixture was checked against a live call):

| File | What it proves |
| --- | --- |
| `test/mentoring_test.dart` | what the API sends (parsers), the price rules (`PriceQuote`), the shell of My mentoring |
| `test/mentoring_tabs_test.dart` | one widget test per control of the Requests, Calendar, Goals, Saved, Certificates, Reports tabs |
| `test/mentoring_pairing_test.dart` + `test/mentoring_pairing_world.dart` | the pairing page: sessions, goals, tasks, notes, shared links, plan, review, concern, support (stateful fake) |
| `test/mentoring_purchases_test.dart` + `test/mentoring_purchases_world.dart` | the Purchases tab, every payment sheet and every handoff |
| `test/mentoring_groups_test.dart` | the group sessions browser and page, programmes (browse, detail, apply) |
| `test/mentoring_fakes.dart` | `FakeApi`, fixtures, the harness (`pumpMyMentoring`, `LinkRecorder`) |
| `test/live/mentoring_live_test.dart` | the local API, as Bharat, Anand, Rohan, Meera, Neha, Kiran |
| `test/golden/mentoring_golden_test.dart` | renders to `build/screens/mentoring_*.png` for looking at (no pixel work yet, by instruction) |

Run: `flutter test --no-pub --timeout=60s test/mentoring_test.dart test/mentoring_tabs_test.dart test/mentoring_pairing_test.dart test/mentoring_purchases_test.dart test/mentoring_groups_test.dart` (129 tests), and with the API up `flutter test --no-pub test/live/mentoring_live_test.dart --concurrency=1` (29 tests; run it twice: it leaves the fixtures as it found them).

## Entry points for the lead

```dart
// My mentoring (the website's /mentorship/my), optionally on one tab
openMyMentoring(context, tab: MyTab.purchases, links: links, onBack: ...);
MyMentoringScreen(initialTab: MyTab.mentoring, onBack: ..., links: links, onOpenConversation: ..., onOpenMentor: ..., onBell: ..., onOpenWebsite: ...);

// One pairing (the website's /mentorship/my/<id>): the target of every "Open" and of a pairing notification
openPairing(context, id, links: links);
PairingScreen(id: id, onBack: ..., links: links, onOpenConversation: ..., onOpenMentor: ..., onBell: ..., onOpenWebsite: ...);

// Group sessions and programmes
openGroupSessions(context, links: links, registeredOnly: false);   GroupSessionsScreen(...)
openGroupSession(context, id, links: links);                       GroupSessionScreen(id: id, ...)
openProgrammes(context, links: links, onBecomeMentor: (context) => ...);   ProgrammesScreen(...)
openProgramme(context, slug, links: links, onBecomeMentor: ...);           ProgrammeScreen(slug: slug, ...)
```

Every screen takes the same four named callbacks (all optional; every one has a working default) and a `MentorshipLinks links` that carries them and more:

| Callback | Called for | Default |
| --- | --- | --- |
| `onOpenConversation(context, conversationId)` | "Message" on a pairing, a bought session, a group room, once the API gave the thread id (the messaging builder's chat screen) | the website's `/messaging?c=<id>` |
| `onOpenMentor(context, mentorProfileId)` | a mentor's name or "View profile" | `mentorProfileRoute` (the in-app profile) |
| `onBell(context)` | the bell | the website's `/notifications` |
| `onOpenWebsite(context, path)` | a page of the website: the public certificate check | the app's screen when it has one, else the web view |
| `openPayment(context, path)` (on `MentorshipLinks`) | a PayU payment page (`/mentorship/my?tab=purchases&purchase=<id>`, a seat, a programme term) | the phone's browser, never the app's own screen for that address (29 Oct 2026) |
| `MentorshipLinks.openPairingThread / openPurchaseThread / openGroupThread(context, recordId)` | preferred over `onOpenConversation` when wired (`MessagingLauncher.forMentorship` etc.) | the API opens the thread, then `onOpenConversation` |
| `MentorshipLinks.openDirectory(context)` | "Find a mentor" | pop |
| `MentorshipLinks.shareFile(context, name, bytes)` | a downloaded private file (shared link or purchased guide) | the share sheet (`share_plus`) |
| `onBecomeMentor(context)` (programme screens) | "Set up my mentor profile" after the API refuses a mentor's application | the website's `/mentorship/become-a-mentor` |

Provide the links once above the shell (`Provider<MentorshipLinks>.value`) or pass them to each screen. Nothing in `lib/app.dart` or the shell was touched; the mentor profile's route helper `mentorProfileRoute` is imported (read-only) for the default of `onOpenMentor`.

## The tabs of My mentoring

Tab keys follow the website (`?tab=`): `active` (Mentoring), `requests`, `calendar`, `purchases`, `goals`, `saved`, `certificates`, `reports`. Saved, Purchases and Goals show for a member who is a mentee (`actsAsMentee`, the website's `useMentoringSides`); Reports shows once a concern was raised; the tab the member is on or was sent to always stays. The tab strip scrolls sideways and brings the open tab into view.

| Tab | Reads | What each control does | Proved by |
| --- | --- | --- | --- |
| Mentoring | `GET /mentorship/summary`, `/mine`, `/requests/mine`, `/requests/incoming`, `/sessions/upcoming`, `/mentees/me/access` | Stat strip; "Needs you" lines open the Requests or Calendar tab; "Up next" opens the pairing, Join opens the meeting link; each pairing card opens the pairing, Message opens its thread (callback); "Find a mentor" (callback) | `mentoring_test.dart` "opens on the member's mentors…", "a member with no mentor yet…", "a load that fails…", "the bell…"; live "the reads behind every tab…" |
| Requests | same | Mentee: "Sent by you" with the plan's allowance, View profile, Withdraw (confirm), Find similar mentors. Mentor: "Asked of you" with Accept (rhythm and note) and Decline (note); the sheet stays open with what was typed on a refusal | `mentoring_tabs_test.dart` Requests ×4; live "a request sent can be withdrawn…", "a mentor declines…", "a mentor accepts…" |
| Calendar | `GET /mentorship/sessions?from&to`, `/mentor-services/bookings/range`, `/mentorship/group-sessions/mine/upcoming` | Month grid (Monday first) with a dot per kind; a day shows its agenda; an entry opens in full with Join and the way to its mentorship, booking or group session; the arrows read the neighbouring month | `mentoring_tabs_test.dart` Calendar ×3; live "the calendar reads a month…" |
| Purchases | `GET /mentor-services/purchases/mine`, `/mentor-plans/subscriptions/mine`, `/mentorship/group-sessions/mine/upcoming`, `/mentorship/programmes/mine` | See [Purchases](#purchases) | `mentoring_purchases_test.dart` (29), live ×7 |
| Goals | `GET /mentorship/mentees/me`, `/goals/mine`, `/mentors/facets` | "What you want from mentoring" (`PUT /mentorship/mentees/me`: career stage required, at most 12 focus areas, 2,000 characters), the goals of every pairing, a goal opens its pairing | `mentoring_tabs_test.dart` Goals ×2; live "what a mentee wants from mentoring is saved…" |
| Saved | `GET /mentorship/mentors/saved` | View profile (callback), Remove | `mentoring_tabs_test.dart` Saved ×2; live "saving a mentor puts them on the Saved tab…" |
| Certificates | `GET /mentorship/mine/certificates` | A certificate opens in full; "Verify online" opens `/mentorship/certificates/<number>` on the website (the public check) | `mentoring_tabs_test.dart` Certificates ×2 |
| Reports | `GET /mentorship/concerns/mine` | Status, urgency and what ICR told the reporter | `mentoring_tabs_test.dart` Reports |

Every tab has a loading state, an error state with "Try again", an empty state, and pull-to-refresh.

## A pairing

`PairingScreen(id)`, from either side. Reads `GET /mentorship/:id`, `/sessions`, `/goals`, `/tasks`, `/timeline`, `/feedback/mine` (once complete), `GET /mentorship/resources?mentorshipId=`, `GET /mentor-plans/subscriptions/mine` and `/sold` (the plan behind it), `GET /mentorship/mine/certificates` (once complete). The first four fail the page; the rest read quietly, so a failing extra never blanks the page.

Order: header, "Needs you" band (the session that slipped, else an unanswered ask, else the next one), sessions, the plan (allowance and syllabus), goals, tasks, shared resources, the review and certificate (once complete), the timeline, "This mentorship".

| Control | What it does (the API's rules) | Proved by |
| --- | --- | --- |
| Message | the pairing's thread through the record (`POST /mentorship/:id/conversation`), then the chat callback | W "Message opens…"; L "Message opens (or reuses) the pairing's thread" |
| Mentor profile (mentee side) | the in-app mentor profile callback | W "Mentor profile opens the mentor" |
| Ask for a time / Book a session | Length (30/45/60/90, or Other 15 to 480), how (only the modes the mentor offers), a free time from the mentor's weekly hours (`GET /mentorship/mentors/:id/slots`) or any time from the phone's pickers, an agenda; a mentee's session is REQUESTED (the mentor confirms), a mentor's is SCHEDULED; a programme books against one of its open steps (`planStepId`). The API's refusals (past time, a mode the mentor does not offer, a clash, a used-up plan, a paused pairing) show in the sheet with what was typed | W "a mentee asks…", "the form checks…", "a time of the phone's own…", "a mentor books straight…", "a programme lists its sessions…"; L "sessions: asked, approved, moved…" |
| Move / Offer another time | either side moves a booked session; only the mentor answers a REQUESTED one (the API says "Your mentor answers this") | W "either person moves…", "a mentor answers a request with another time"; L (same) |
| Approve / Decline (mentor) | approve puts it on both calendars; decline asks a reason (3 to 500) | W "a mentor approves…", "a mentor declines…" |
| Withdraw (mentee) | cancels the ask | W "a mentee withdraws…" |
| Cancel | reason 3 to 500; a cancelled session gives its plan place back | W "cancelling asks for a reason…"; L |
| Mark held (mentor) | the minutes it actually ran (15 to 480: what CPD and the counters claim) and a note; offered once the session has started (the API itself does not require it) | W "a mentor closes a session…"; L |
| Meeting link (mentor) | `PATCH …/meeting-link`; checked as the API checks it (http(s), a host with a dot, 500 characters; blank clears) | W "the mentor sets a meeting link…"; L |
| Join | opens the meeting link | W "Join opens the meeting link" |
| Notes on a held session | notes (8,000), the pair's own recording link; "Summarise these notes" only when saved and 200+ characters, and only on request; editing the notes clears the summary | W "the notes of a held session…", "a summary the site cannot make says so"; L |
| Goals | add (3+ characters), progress, achieved, drop, reopen, remove | W "a goal is added…"; L "goals and tasks…" |
| Tasks | add (2+), tick, untick, delete (only the author) | W "a task is added…"; L |
| Shared resources | share a **link** (title, kind, note, https link) or a **file** (the phone's chooser: a PDF or an image, 10 MB; uploaded with `POST /uploads?purpose=mentorship-resource`, then shared by its stored name); open a link; download a file (read with the session's token, handed to the share sheet); remove (the author, or the mentor who owns the pairing) | W "a link is shared…", "a file is shared from the phone…", "a file that is not a PDF or an image is refused…", "a shared file is read with the session's token…", "a file the API refuses says why…"; L "notes and shared links…", "a PDF is uploaded and shared…" |
| Timeline | add a note, shared or private to its author (a private note is invisible to the other person: proved live); four entries and "All n entries" | W "a note goes on the timeline…", "the timeline shows four entries…"; L |
| The plan | allowance as segments ("1 of 2 sessions left"), the syllabus with its steps in order, "Do not renew" for the buyer of an ongoing plan | W "the plan behind it" ×3; L "the page reads what the API holds…" |
| Pause / Resume / rhythm | `PATCH /mentorship/:id`; a paused pairing offers no booking | W "pause, resume and the rhythm…", "a paused pairing offers no booking…"; L "pause stops booking…" |
| Mark complete | asks first, closes it for both and cancels what is booked; opens the review and the certificate | W "completing it asks first…"; L |
| Rate the mentorship | one to five stars, a comment, "I would recommend" (a mentee's is shown on the mentor's profile without a name; a mentor's is for ICR); once | W "a completed mentorship is rated once…"; L |
| End early | a reason both read; the API also accepts none, the app asks for 3+ | W "ending early asks for a reason…"; L |
| Report a concern | category, 10+ characters, urgent (always for Safety); private to ICR | W "a concern needs ten characters…"; L |
| Contact ICR support | `POST /support/tickets` (subject 5+, body 10+, context MENTORSHIP) | W "support is an ordinary request…"; L (the checks; no ticket is written, support tickets cannot be removed) |

## Purchases

One list in three groups: **Needs you** (a time to accept, a payment due, a move to answer, a programme to pay for, a held session to review), **Active** (an ask waiting, a booked call, a term running or waiting on the mentor, a group seat, a cohort application), **Past** (behind a toggle). `bucketOf` and `termBucket` decide.

| Item and state | Controls (and the API call) | Proved by |
| --- | --- | --- |
| 1:1 asked (REQUESTED) | Withdraw (`POST purchases/:id/withdraw`) | W "a request is withdrawn"; L |
| 1:1 with a time set (ACCEPTED) | **Accept this time** (quote shown: list price, session credit, member discount; `POST accept-time {useCredit}`: a free session or a credit that covers it books at once, a paid one becomes "payment due"); **Ask another time** (note 5 to 500, `POST decline-time`); Withdraw | W "accepting the time…" ×2, "a time that does not suit…"; L "a time that does not suit…", "a paid 1:1 session…" |
| Payment due (CONFIRMED / PENDING_PAYMENT) | **Pay** (see Money), Cancel (reason 5 to 500) | W "paying" ×5; L "a paid 1:1 session…" |
| Booked call (PAID) | Join, **Ask to move** (a time from the mentor's hours, a note 300; `POST reschedule`), a move the mentor proposed: **Accept new time** / **Keep booked time** (`reschedule/accept`, `reschedule/decline`), withdraw your own ask, Cancel, Message (through the record) | W "a booked call" ×7; L "a free 1:1 session…" |
| A guide (FULFILLED resource) | **Download** (the private file read with the session's token, shared), Leave a review (rating, 10+ characters if written, hide my name), Report a problem (10+; `report-issue`, `withdraw-issue`) | W "a guide and after" ×4; L "a free guide…", "a bought guide downloads as the real file" |
| Declined / cancelled / refunded | the reason as the API words it | W "the tab sorts…" |
| Programme or plan term | pending: waiting on the mentor, Withdraw; accepted: **Pay** with the API's own quote (price, member discount, tax, total); running: sessions left, next step, Schedule a session / Open mentorship (pairing), Do not renew | W "programmes, plans, seats and cohort places" ×4, "paying" (term) ×2; L "a programme asked for…" |
| Cohort application | Open programme, Withdraw | W; L "programmes: …" |
| Group seat | Open session, Give up seat (free seats) | W; L "group sessions: …" |

### Money

* **The quote first.** A 1:1 session: `PriceQuote.session` from `GET /mentor-services/member-discounts` (member discount for services, and a session credit that pays up to its cap and **replaces** the discount, never both: the website's and the API's rule). A seat or a guide: `PriceQuote.service` (discount only). A programme or plan: the term's own `pricePaisa / discountPaisa / taxPaisa / totalPaisa` from the API. The sheet names the plan behind a discount or a credit and shows the list price struck through when something came off.
* **Completed in the app** when nothing is left to pay (free, or a credit that covers it) or the gateway is simulated (`GET /payments/mode`); the API is called with `useCredit` as chosen.
* **Real money goes to the website.** When payments are live and an amount is left, the sheet says so, shows the total, and its button opens `/mentorship/my?tab=purchases&purchase=<id>` (a seat: `/mentorship/groups/<id>`; a programme: `/mentorship/my?tab=purchases`), where PayU's page runs. **No API call is made first**, so no gateway order is begun that the app cannot finish. The payments mode on this machine is `live`.
* Every API refusal is shown in the sheet and the sheet stays.

## Group sessions

`GroupSessionsScreen`: segmented "Open sessions" / "My seats" (`registered=true`), search, mode chips (`mode`), "Seats free" (`availableOnly`), pages of 12 with "Load more sessions" (`page`, `meta.hasNext`). `GroupSessionScreen(id)`: host, when (a series lists its days), mode and venue, seats and price, about, agenda (the sanitised HTML as plain text), topics, the roster the API lets this member see (`rosterScope`), and one thing to do:

| State (the API's `myStatus`, `canRegister`, `seatForSale`, `blockedReason`) | Control | Proved by |
| --- | --- | --- |
| Free seat open | a question for the host (1,000) and **Reserve my seat** (`POST register`) | W "a free seat is taken…"; L "group sessions: …" |
| Full, waitlist on | **Join the waitlist**, then **Leave the waitlist** | W "a full session offers the waitlist…" |
| Holds a seat | **Join the session** (the call link appears only once registered), **Room chat** (`POST conversation`, through the record), **Give up my seat** (free seats) | W; L |
| Paid seat for sale | the quote (member discount), **Reserve a seat · ₹X** → a sheet with a question → the app buys it when the gateway is simulated, else the website's payment page | W "a paid seat shows the quote…", "with a simulated gateway…", "a refused seat purchase…"; L "a paid seat shows its quote…" |
| The API says no | its `blockedReason` verbatim | W "when the API says no…" |
| Held, attended | **Rate this session** (rating, 10+ characters if written, hide my name; a paid seat is reviewed through its purchase) | W "a held session is rated once…", "a paid seat is reviewed through its purchase"; L "a held session is rated once (Meera)…" |
| Attended or holds a seat | **Report a concern** (private to ICR) | W "a concern about a session…" |
| Host | a note that it is managed from the mentor desk | |

## Programmes

`ProgrammesScreen`: "Open for applications" (`status=OPEN`, the default), "Under way" (`RUNNING`), "All"; a card shows the member's own application status. `ProgrammeScreen(slug)`: dates, who it has room for (mentees and mentors taken of capacity), the detail, "Your place" (applications, status, the organiser's note, **Withdraw**), the group sessions inside it (`groupSessions(programId)`), and **Apply to join** (open programmes): side (Mentee/Mentor), why (2,000). The API's eligibility refusals are read **by `code`**, not by wording: `PROGRAMME_NEEDS_MENTEE_PROFILE` offers "Tell us what you are after" (the same intent sheet as the Goals tab, saved with `PUT /mentorship/mentees/me`, then the application can go), `PROGRAMME_NEEDS_MENTOR_PROFILE` offers "Set up my mentor profile" (`onBecomeMentor`, else the website). A full side is said so and the button is off. Proved by `mentoring_groups_test.dart` "programmes" ×8 and live "programmes: …".

## What the audit found (API behaviour worth knowing)

* `GET /mentorship/mentees/me` answers **200 with an empty body** for a member with no mentee profile.
* A session the mentor sets the time on is **booked at once when it is free** (PAID with a booking); only a paid one waits as ACCEPTED for the mentee to accept (then CONFIRMED, payment due).
* A cancelled group seat reads back as `myStatus: CANCELLED`, not null; programme detail keeps a member's withdrawn places in `myEnrolments`.
* The group-session rating reads back with `authorName: null` when the member hid their name (there is no `anonymous` field).
* A private upload answers a refusal as **bytes** when read as bytes: the repository reads the JSON sentence out of them (found by a widget test), so "Sign in to view this file." reaches the person.
* `POST /mentor-plans/:planId/request` answers `{ ok, subscriptionId, status }`. A second ask while one is open is refused ("You have already asked for this program").
* The API lets a second move be proposed over the first and lets a pairing that ended take a goal: the app offers neither (it hides the buttons).
* A mentor owns the pairing's shared resources and may remove anyone's; a mentee removes only their own.
* Bug found by the first widget test: the Mentoring tab sorted an unmodifiable empty list while loading. Fixed.

## Seed and what a live run leaves

`tool/seed/mentoring.ts`. This pass added three rows for Bharat only, so every state of the Purchases tab can be looked at on the emulator: `buy-bharat-confirmed` (a time accepted, ₹799 due), `buy-bharat-move` (a booked call with a move the mentor asked for) and `buy-bharat-held` (a held session whose review is still to write). Re-run the script (idempotent) to get them. People (password `Password123!`): `mentoring.anand` (mentor desk, a paid storefront), `divya`, `neha` (free mentors), `meera` (mentee with a profile), `rohan` (the live tests' sender: a profile, no pairings, no phone), `kiran` (no mentee profile; the become-a-mentor persona), `tanvi/arjun/isha/vikram/sana/rahul`. Bharat and Pooja get rows that carry the `dsgn-mentoring-` prefix.

Live tests undo what the API allows: a request is withdrawn, a booked call cancelled, a programme application withdrawn, a seat given up, a saved mentor un-saved, Rohan's phone cleared. What the API cannot undo stays on fixture accounts and `--remove` sweeps it: an answered request, an ended-early pairing (created fresh for each test that needs one: Rohan asks Neha, Neha accepts), a timeline note, a review, a concern, a group-session rating (Meera, once), uploaded guide downloads (none are written). The seeded rows other screens read (Bharat's pairings, purchases, terms) are never changed.

## Clock and mentoring-wide helpers

`mentoringNow` (`mentoring_clock.dart`) is the module's clock: everything dated reads it, and goldens and tests pin it. `mentoring_format.dart` (₹ in Indian grouping, dates, `plainText` for the API's sanitised HTML, `linkProblem` for the API's link rule, `sessionsLeft`), `widgets/kit.dart` (the module's own type and widgets: it does not import the Mentor Profile's styles, which are being audited).

## Handoffs kept

| Handoff | Why |
| --- | --- |
| PayU's payment page (`/mentorship/my?tab=purchases&purchase=<id>`, `/mentorship/groups/<id>`, `/mentorship/my?tab=purchases`) | real money; the gateway's return leg is the website's. The quote is shown in the app first |
| `/mentorship/certificates/<number>` | the public check of a certificate by its number; the certificate itself is drawn in the app (a PDF/print is the website's) |
| `/mentorship/become-a-mentor` (only when `onBecomeMentor` is not wired) | the in-app flow is `BecomeMentorScreen`; the lead wires it |
| `/notifications`, `/messaging?c=` (only when the callbacks are not wired) | other builders' screens |

## Left

* The seed has no programme term waiting on payment (a programme's payment sheet is proved with fixtures only): the two programme terms every mentee gets are `PENDING_MENTOR`, and changing one would disturb the mentor desk's tests that answer them.
* The website's reschedule of a purchase takes the buyer's note only up to 300 characters: validated; the mentor's side of a purchase is the mentor desk.
* Pixel matching, goldens as assertions and tablet layouts: postponed by instruction.
