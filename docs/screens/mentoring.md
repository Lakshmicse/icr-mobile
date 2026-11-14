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

Tab keys follow the website (`?tab=`): `active` (Mentoring), `requests`, `calendar`, `purchases`, `goals`, `saved`, `certificates`, `reports`. Saved and Goals show for a member who is a mentee (`actsAsMentee`, the website's `useMentoringSides`); **Purchases always shows** (owner, 9 Nov 2026: it appeared only when a notification opened it and vanished otherwise, so it "should be intact"); Reports shows once a concern was raised; the tab the member is on or was sent to always stays. The tab strip scrolls sideways and brings the open tab into view.

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

## 7 Nov 2026

* **Withdraw asks first** (`withdraw-confirm`) on a requested or accepted purchase.
* Report a problem reads "ICR reviews your report and asks the mentor to respond." — no first name (owner: "where is this text coming that Rashmmi will look into issue?").
* **A mentor who bought a session is a mentee too** (`hasPurchases`): the purchases load with the first screenful, the Purchases tab shows for them, and what waits on them (a time to accept, a payment, a move, a review) is listed under **Needs you** on the overview — a mentor could not find the time set for the session he had bought.

## 9 Nov 2026

* **The Purchases tab is always there** (`_visible`: `MyTab.purchases => true`). Before, it showed only for a mentee or someone with purchases, so a member sent to it by a notification saw it vanish on their next visit.
* **No page title inside a tab**: see `docs/screens/learning_exam.md` → 9 Nov 2026; the rule is the workspace's, and holds here too.

* **Bug sheet #18:** a programme in `OPEN` whose applications closed reads **Applications closed** (`statusLabel` follows `open`), where the badge said "Applications open" over "Applications closed 1 Oct".
* **Bug sheet #12, #28, #31–#33, #38** were done on 3–8 Nov: hairline cards instead of boxes, no RFQ pill in mentoring threads, Withdraw asks first, the session texts, the Purchases tab for a mentor who bought a session.

## 13 Nov 2026: copy refined to the client's standard

The client asked for the on-screen text to be refined "crisp, for global standard", in the style of the wording they marked up for sign-in and Settings. Wording only: no layout, colour or behaviour changed. Names of things a person taps or reads as a label are in Title Case; sentences are in sentence case with a full stop; no dash is used as punctuation; "pick" and "tick" read "select", "is told" reads "is notified", "show up / land here" reads "will appear here", and a load that fails reads "Unable to Load …". The title of an empty state or an error block is a heading (Title Case, no full stop: "No Purchases Yet", "Unable to Load Mentors"); the line under it is a sentence. The retry button reads **Try Again**.

* "Needs you" reads **Action Needed** everywhere (the overview, a pairing, Purchases, and the overline on the attention card), which is the name the overview already used for the group on Engagements.
* Form labels that were questions are now names: "How often?" → "Meeting Frequency", "Where are you in your career?" → "Career Stage", "What is it about?" → "Concern Type", "When?" → "Date and Time".
* Left as they are: the report sentence "ICR reviews your report and asks the mentor to respond." (owner, 7 Nov), the reason sent to the API when a mentee withdraws a session request ("Withdrawn by the mentee."), example hints that show what to type ("Lead a site audit on my own", "Weekday evenings after 7 pm"), the tab names (single words), "FROM ICR", and counts and date lines ("3 sessions held · 2 hr in all").

| Old | New |
| --- | --- |
| {…} a seat | {…} per seat |
| Couldn't load the sessions | Unable to Load Sessions |
| No sessions match | No Matching Sessions |
| Reserve a seat at an open session and it shows up here. | Reserve a seat at an open session and it will appear here. |
| Try another filter, or look again later: hosts add sessions all the time. | Try another filter, or check again later. Hosts add sessions regularly. |
| Load more sessions | View More |
| Couldn't load this session | Unable to Load This Session |
| The days | Session Days |
| Who is going ( | Attendees ( |
| Sent to ICR. Someone will look into it and reply to you. | Sent to ICR. The team will review it and reply to you. |
| Join the session | Join Session |
| You are on the waitlist. You get a seat if one frees up, and the host tells you. | You are on the waitlist. If a seat becomes available, you get it and the host notifies you. |
| Leave the waitlist | Leave Waitlist |
| It is full, but you can join the waitlist. | This session is full. You can join the waitlist. |
| A free seat. Tell the host what you want out of it. | This seat is free. Tell the host what you want from the session. |
| A question for the host (optional) | Question for the Host (Optional) |
| Join the waitlist | Join Waitlist |
| How was it? Your rating helps others choose. | Your rating helps others choose. |
| Hide my name on the rating | Hide My Name |
| What you want out of it | What you want from the session |
| You pay on ICR's secure PayU page, here in the app. | You pay on ICR's secure PayU page in the app. |
| Tell ICR what happened: at least 10 characters. | Describe what happened in at least 10 characters. |
| Goes to ICR's safeguarding team, not to the host. | This goes to ICR's safeguarding team, not to the host. |
| What is it about? | Concern Type |
| This is urgent | Mark as Urgent |
| Couldn't open the conversation. Try again. | Unable to open the conversation. Try again. |
| Awaiting the mentor | Awaiting Mentor |
| The other person has gone quiet. | The other person has stopped responding. |
| Contact outside what you agreed, or asks that made you uneasy. | Contact beyond what you agreed, or requests that made you uncomfortable. |
| ICR is looking into it | Under Review |
| Acted on | Action Taken |
| Couldn't load your mentoring | Unable to Load Your Mentoring |
| No sessions yet. Book your first session | No sessions yet. Book your first session. |
| Needs you | Action Needed |
| {mentor} set a time for {…}: accept it, or ask another | {mentor} set a time for {…}. Accept it or ask for another. |
| No agenda yet — add one so your mentor can prepare | No agenda yet. Add one so your mentor can prepare. |
| Your objective, in your own words | Your Objective |
| Phone number | Mobile Number |
| Every signal mentors match on is filled in. | All mentor matching criteria are complete. |
| See purchases | View Purchases |
| See all saved | View All Saved |
| Requests asked of you — to mentor someone, for a session or for a programme — are on Engagements, | Requests to mentor someone, for a session or for a programme are on Engagements, |
| — {about} | · {about} |
| Declined. {…} has been told. | Declined. {…} has been notified. |
| Asked of you | Requests Received |
| When a member asks you to mentor them, it lands here. | When a member asks you to mentor them, the request will appear here. |
| Sent by you | Requests Sent |
| You have not asked anyone yet | No Requests Sent Yet |
| Couldn't load your requests | Unable to Load Your Requests |
| Could not refresh this month: | Unable to refresh this month: |
| Nothing on this day. | No events on this day. |
| Couldn't load your calendar | Unable to Load Your Calendar |
| No goals yet. Open a mentorship and add one: a goal is what the two of you are working towards. | No goals yet. Open a mentorship and add one. A goal is what you both work towards. |
| Couldn't load your goals | Unable to Load Your Goals |
| Tell mentors what you want out of mentoring. A request needs your career stage first, and a few | Tell mentors what you want from mentoring. A request needs your career stage first. A few |
| lines about the next step you want to take help it get answered. | lines about your next step help it get answered. |
| Set it up | Set Up |
| Nothing saved yet | No Saved Mentors Yet |
| Save a mentor from their profile to keep a shortlist before you ask anyone. Only you see it. | Save a mentor from their profile to build a shortlist before you send a request. Only you can see it. |
| saved. Only you see this list. | saved. Only you can see this list. |
| Couldn't load your saved mentors | Unable to Load Your Saved Mentors |
| Couldn't load your certificates | Unable to Load Your Certificates |
| You have not raised a concern. You can from any mentorship: it goes to ICR, not to the other person. | You have not raised a concern. You can raise one from any mentorship. It goes to ICR, not to the other person. |
| Couldn't load your reports | Unable to Load Your Reports |
| Pick a time first. | Select a time first. |
| Pick a time in the future. | Select a time in the future. |
| Ask for a time | Request a Time |
| is told, and the session is booked at the time you pick. | is notified, and the session is booked at the time you select. |
| The other person is told. It stays booked at the new time. | The other person is notified. The session stays booked at the new time. |
| It goes straight on both calendars. | It is added to both calendars immediately. |
| Which session of the programme? | Programme Session |
| Length | Duration |
| How | Meeting Mode |
| When? / Free times in your/their hours | Date and Time / Free Times in Your/Their Hours |
| No open times in the next two weeks; pick a day and time. | No open times in the next two weeks. Select a day and time. |
| On your phone's clock. The API refuses a time outside the mentor's hours or on top of another session. | Times are shown in your phone's time zone. A time outside the mentor's hours or overlapping another session is not accepted. |
| Pick a day and time | Select a Day and Time |
| Enter the minutes it ran: {minSessionMinutes} to {maxSessionMinutes}. | Enter the minutes it ran, from {minSessionMinutes} to {maxSessionMinutes}. |
| Mark the session held | Mark Session as Held |
| This is what gets counted: {…} was booked. | This duration is counted. {…} was booked. |
| Mark held | Mark as Held |
| Minutes it actually ran | Actual Minutes |
| A note for the timeline (optional) | Timeline Note (Optional) |
| Summaries are not switched on here yet. | Summaries are not available yet. |
| Either of you can write these up. They are private to the two of you. | Either of you can write these notes. They are private to you both. |
| Summarise these notes | Summarise Notes |
| Save your changes first: a summary is made from the saved notes. | Save your changes first. A summary is made from the saved notes. |
| Asked for only when you press it: the notes go to a model to be summarised. | Runs only when you select it. The notes are sent to an AI model to be summarised. |
| is told when it changes. | is notified when it changes. |
| Name the goal: at least 3 characters. | Enter a goal of at least 3 characters. |
| Something the two of you agree to work towards. Both of you can update it. | A goal you both agree to work towards. Either of you can update it. |
| Detail (optional) | Details (Optional) |
| What done looks like | What success looks like |
| Pick a date | Select a Date |
| Name the task: at least 2 characters. | Enter a task of at least 2 characters. |
| Due (optional) | Due Date (Optional) |
| How far along is it? 100% marks it achieved. | Set the progress. 100% marks the goal as achieved. |
| Write the note first. | Enter a note first. |
| A line on the timeline: what happened, what is next. | A timeline entry. Describe what happened and what is next. |
| Private: only you can see it | Private. Only you can see it. |
| That file is over 10 MB. | The file is larger than 10 MB. |
| Give it a title: at least 2 characters. | Enter a title of at least 2 characters. |
| A link or a file | Link or File |
| What it is | Resource Type |
| Why it is worth opening (optional) | Why It Is Useful (Optional) |
| Goes to ICR's safeguarding team, not to the other person. | This goes to ICR's safeguarding team, not to the other person. |
| Give it a subject: at least 5 characters. | Enter a subject of at least 5 characters. |
| Tell us what went wrong: at least 10 characters. | Describe what went wrong in at least 10 characters. |
| Couldn't load this mentorship | Unable to Load This Mentorship |
| How often you meet | Meeting Frequency |
| Rhythm changed. | Meeting frequency updated. |
| A concern is private to ICR: {other} is not told and nothing is shown to them. | A concern is private to ICR. {other} is not notified and nothing is shown to them. |
| It closes the pairing for both of you and cancels anything still booked. | This closes the mentorship for you both and cancels any booked sessions. |
| is told, and you can both leave a review. | is notified, and you can both leave a review. |
| Both of you see the reason. Anything still booked is cancelled. | You both see the reason. Any booked sessions are cancelled. |
| Our schedules no longer line up | Our schedules no longer match |
| Nothing booked. Book a time from your hours. | No sessions booked. Book a time from your hours. |
| Nothing booked yet. Ask for a time; your mentor confirms it. | No sessions booked yet. Request a time and your mentor confirms it. |
| No sessions ahead. | No upcoming sessions. |
| Needs you: a session to close | Action needed: close a session |
| Waiting on {…} to confirm | Waiting for {…} to confirm |
| Needs you: a time to answer | Action needed: respond to a time |
| Waiting on {…} | Waiting for {…} |
| Moved. {…} has been told. | Moved. {…} has been notified. |
| Booked. {…} has been told. | Booked. {…} has been notified. |
| Asked. Your mentor confirms the time. | Request sent. Your mentor confirms the time. |
| confirms a session once it has happened. If it did not, move it to a new time. | confirms a session after it takes place. If it did not take place, move it to a new time. |
| is told, with your reason. | is notified, with your reason. |
| The request is taken back, and the mentor is told. | The request is withdrawn, and the mentor is notified. |
| The programme | Programme |
| A cancelled session gives its place back; a no-show does not. | A cancelled session is returned to your allowance. A no-show is not. |
| It will not renew: it ends at the close of this term. | It will not renew. It ends at the close of this term. |
| No goals yet. A goal is what the two of you are working towards. | No goals yet. A goal is what you both work towards. |
| Nothing on the list. Agree the next steps after a session. | No tasks yet. Agree the next steps after a session. |
| Nothing shared yet. Links and files you share show up for both of you. | Nothing shared yet. Links and files you share are visible to you both. |
| Nothing recorded yet. Notes you add, and what happens, show up here. | Nothing recorded yet. Notes you add and mentorship events will appear here. |
| All {…} entries | View All {…} Entries |
| This mentorship is complete. How did it go? Your rating helps other members choose. | This mentorship is complete. Your rating helps other members choose. |
| Couldn't load the programmes | Unable to Load Programmes |
| No programmes here | No Programmes Found |
| Cohort programmes open for applications from time to time. Look again soon. | Cohort programmes open for applications periodically. Check again soon. |
| Couldn't load this programme | Unable to Load This Programme |
| The detail | Details |
| Your place in the programme is given up, and the mentor is told. | Your place in the programme is released, and the mentor is notified. |
| Apply on the other side | Apply in the Other Role |
| Which side are you applying on? | Applying As |
| The {…} side is full. | All {…} places are taken. |
| What you want out of it | What you want from the programme |
| Tell us what you are after | Add My Mentoring Goals |
| ; you pay {…}. | . You pay {…}. |
| The payment didn't go through. Nothing was charged. | The payment failed. Nothing was charged. |
| The payment wasn't completed. If you did pay, it shows under My mentoring within a minute. | The payment was not completed. If you paid, it will appear under My Mentoring within a minute. |
| It is booked on both calendars at once. | It is booked on both calendars immediately. |
| It is free: nothing to pay. | It is free. There is nothing to pay. |
| after, to confirm it. | afterwards to confirm it. |
| Start it | Start |
| Say which times would, and {name} sets another. | Enter the times that suit you, and {name} sets another. |
| Which times would work for you? | Times That Suit You |
| The other person is told, with your reason. Whether you are refunded follows ICR's cancellation rules. | The other person is notified, with your reason. Refunds follow ICR's cancellation rules. |
| Hide my name on the review | Hide My Name |
| Pick a new time first. | Select a new time first. |
| A note (optional) | Note (Optional) |
| is told, with your reason if you give one. | is notified, with your reason if you give one. |
| A note back (optional) | Reply Note (Optional) |
| is told and the request is closed. You can ask again later. | is notified and the request is closed. You can ask again later. |
| Sessions, guides, programmes and plans you ask for or buy from a mentor show up here, with group sessions and cohorts. | Sessions, guides, programmes and plans you request or buy from a mentor will appear here, with group sessions and cohorts. |
| {mentor} can't take it | {mentor} is unable to take it |
| Withdraw the request | Withdraw Request |
| Ask another time | Ask for Another Time |
| Thanks. Your review is on | Thank you. Your review is on |
| Sent. ICR will look into it. | Sent. ICR will review it. |
| The plan is not taken up, and the mentor is told. | The plan request is withdrawn, and the mentor is notified. |
| A cohort programme | Cohort Programme |
| You are all caught up. | Nothing needs your attention. |
| NEEDS YOU | ACTION NEEDED |
| Lapses {…} if nobody answers | Expires {…} if not answered |
| Write at least {…} characters. | Enter at least {…} characters. |
| Choose a rating from one to five stars. | Select a rating from one to five stars. |
| Write at least {…} characters, or leave the comment empty. | Enter at least {…} characters, or leave the comment empty. |
| What was it like? (optional) | Comment (Optional) |
| When? / Free times | Date and Time / Free Times |
| No open times are listed for the next two weeks; pick a day and time. | No open times are listed for the next two weeks. Select a day and time. |
| On your phone's clock. | Times are shown in your phone's time zone. |
| Tell us where you are in your career first. | Select your career stage first. |
| Where are you in your career? | Career Stage |
| What do you want help with? | Mentoring Goals |
| That is the most you can pick ({_maxFocus}). | You have selected the maximum ({_maxFocus}). |
| Pick up to {_maxFocus}. | Select up to {_maxFocus}. |
| In your words (optional) | Your Objective (Optional) |
| How would you like to meet? | Meeting Mode |
| How often? | Meeting Frequency |
| Couldn't load this | Unable to Load This |
| s mentor and they are told. You can pause or end it later. | s mentor and they are notified. You can pause or end it later. |
| How often will you meet? | Meeting Frequency |
| Optional. It is a rhythm to aim for, not a rule. | Optional. This is a guide, not a rule. |
| They are told, with your note. A kind line helps: they may look for someone else. | They are notified, with your note. A kind note helps, as they may look for another mentor. |
| Couldn't load your purchases | Unable to Load Your Purchases |
| About {subject}. For conduct, use "Report a concern": that stays private. | About {subject}. For conduct issues, use "Report a Concern". It stays private. |
| Buttons, headings, tabs, chips, field labels and status names to Title Case: 215 strings | e.g. "Valid ICR mentoring certificate" → "Valid ICR Mentoring Certificate"; "Certificate not found" → "Certificate Not Found"; "This certificate is no longer valid" → "This Certificate Is No Longer Valid" |
