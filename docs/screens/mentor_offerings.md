# The mentor desk's Offerings: gates, services, plans and programmes, group sessions

Code: `lib/features/mentor_desk/offerings/`. Tests: `test/mentor_offerings_test.dart` (the rules, what the API sends, the gates, services), `test/mentor_offerings_groups_test.dart` (plans and programmes, group sessions), `test/mentor_offerings_fakes.dart` (a stateful fake of the API in the real shapes), `test/live/mentor_offerings_live_test.dart` (the local API, as Anand). Seed: none to add (`tool/seed/mentoring.ts` makes the rows); `tool/seed/mentoring_offerings.ts --remove` sweeps what the live tests cannot take away. Backend request: `docs/backend-requests/mentor_offerings.md`.

Run: `flutter test --no-pub --timeout=60s test/mentor_offerings_test.dart test/mentor_offerings_groups_test.dart` (70 tests), `flutter test --no-pub test/live/mentor_offerings_live_test.dart --concurrency=1` (11 tests, API up).

## Entry point (the desk mounts it as its Offerings tab)

```dart
OfferingsPanel(
  api: apiClient,            // the signed-in ApiClient
  links: mentorshipLinks,    // MentorshipLinks: only openSite is used ("Read the terms" -> /terms)
  onChanged: () => ...,      // called after any write, so the desk's overview can read again
  pickFile: pickOfferingFile // optional: the phone's file chooser (a test stands in for it)
)
```

It draws inside a scrolling tab body (no Scaffold), owns loading, error with "Try again", empty states and pull-to-refresh (a `RefreshIndicator` over its own `ListView`), and reads three things independently (`GET /mentor-services/mine`, `GET /mentor-plans/mine`, `GET /mentorship/group-sessions?mine=true&limit=50`), so one failing leaves the others on screen. The desk is hidden without a mentor profile; the panel itself shows the API's refusal if it is ever mounted without one.

## What it holds

| Section | What it is | Controls |
| --- | --- | --- |
| **Storefront** (gates card) | What must be true before anything sells, exactly as the API reports it: not suspended, paid selling on, seller terms of the current version accepted, "Live" or "Not open", the API's own `blockedReason` verbatim, and "N of 10 service listings used" | **Accept seller terms (2026.1)** (only when the API's sentence says the terms are the one thing missing): a confirm dialog with a summary, "Read the full terms" (`/terms` on the website, a legal page) and a tick box; `POST /mentor-services/mine/terms {version}` only after the tick. Suspended or not approved: no button, the sentence only |
| **1:1 mentoring** | 1:1 sessions (a `ONE_ON_ONE` service) and programmes (a `CURRICULUM` plan), one offering to a mentee, two lists to a mentor | Add a 1:1 session, Add a programme, then per row Edit, Pause or Resume, Delete |
| **Resources** | A downloadable file (PDF or image, 10 MB), paid or free as a lead magnet | Add a resource (file picker, upload), per row Edit, Pause or Resume, Delete |
| **Ongoing plans** | A prepaid term with sessions every month | Add an ongoing plan, per row Edit, Pause or Resume, Delete |
| **Older listings** | Legacy group-seat services and a retired written consultation: shown, never created | Edit, Pause, Delete (a retired type cannot be switched back on: no Resume) |
| **Group sessions** | Sessions the mentor hosts (draft, open, held, cancelled) | Host a group session; per row Details (roster and actions) and, for a draft, Publish |

While the storefront is closed the Add buttons for services, programmes, resources and plans say why in the API's words and open nothing (the API would answer the same 403). Group sessions only need an approved mentor, so Host a group session always opens.

## Every control, and the test that proves it

W = `mentor_offerings_test.dart` / `mentor_offerings_groups_test.dart` (widget, the fake API), L = `mentor_offerings_live_test.dart` (the local API).

### Gates

| Control | What it does | Proved by |
| --- | --- | --- |
| Gates card | Shows the lines, the status pill, the API's sentence, the listing count | W "a live storefront reads as live…", "a suspended storefront says so…"; L "the storefront, the plans and the group sessions parse…" |
| Accept seller terms | Dialog; nothing is sent until the terms are ticked as read; `POST mine/terms {version: current}`; the storefront opens; `onChanged` fires | W "when the seller terms are the one thing missing…", "Not now sends nothing", "a refused acceptance shows the API's sentence…"; L "a mentor with no seller terms sees the API's own gate, and cannot open the storefront with a wrong version" (the real acceptance is not exercised: it cannot be undone) |
| Read the terms | `/terms` on the website (legal page: a kept handoff) | W (same test) |
| Add while closed | The API's `blockedReason`, no request, no form | W "while the storefront is closed, adding a service or a plan says why…" |
| A failed read | "Couldn't load your storefront/plans/group sessions" and Try again; the rest still shows | W three tests; pull to refresh: W "pulling down reads all three lists again" |

### Services (1:1 session, resource, older seat)

| Control | What it does | Proved by |
| --- | --- | --- |
| Add / Edit form | Title 4 to 120, description up to 600, length 15 to 480 minutes (1:1 and seats), seats 2 to 500 (older seats), Free switch, price in rupees (free, or ₹499 to ₹50,000), strikethrough price (above the price, price at least half of it), cover image, Live switch; refuses as the DTO and the catalog gatekeeper do, keeps the sheet open with what was typed on a refusal | W "adding a 1:1 session checks every field…", "a free session sends price 0…", "a refusal keeps the form open…", "editing starts from what is held…", "an older group seat keeps its seats field…"; the rules: W "the rules, as the API holds them" (9 tests); L "a 1:1 session is created, edited, paused, resumed and deleted; the API's rules answer in its own words" (each sentence checked against the real API) |
| Resource file | Choose a PDF or image (checked before sending: extension, 10 MB), `POST /uploads?purpose=mentor-resource`, saved by its stored name (`uploadId`), `fileName`, `fileSize`; a resource cannot be live without it | W "a resource needs its file…", "a resource saved paused needs no file yet", "a refused upload says why…"; L "a resource needs its file…" |
| Cover image | `POST /uploads?purpose=mentor-offering`; the edit sends `coverUrl` only when changed (an edit that does not name it keeps it), Remove sends null | W "a cover is uploaded… and can be taken off again"; L "a cover is uploaded for mentor-offering, shown on the service, and taken off again" |
| Pause / Resume | The API takes the whole shape: the row goes back with only `active` changed | W "pausing sends the whole row back…", "a refused pause says why…"; L (same 1:1 test) |
| Resume a resource | The API refuses a resource's `active: true` without the file in the same call (see below); the app opens the edit form with Live on so the file is chosen again | W "resuming a resource the API will not publish without its file opens the form…"; L "a resource needs its file… resuming it wants the file again" |
| Delete | Confirm ("Keep it" sends nothing); `DELETE mine/:id` (soft: purchases keep their snapshots) | W "deleting asks first…"; L (1:1 test) |
| The listing cap | The API counts every service not deleted, drafts included, against 10 | L "the listing cap is the API's: ten services, drafts included" |

### Plans and programmes

| Control | What it does | Proved by |
| --- | --- | --- |
| Add / Edit an ongoing plan | Title 3 to 80, description up to 400, price (free, or ₹500 to ₹5,00,000 a term), strikethrough above it, term 1/3/6/12 months, 1 to 12 sessions a month, usual length, up to 8 inclusions of 80 characters, cover, Live | W "adding an ongoing plan: each field is checked…", "a free plan sends price 0…", "editing an ongoing plan sends its cadence…"; L "an ongoing plan: the API's price and shape rules in its words, then created, edited, paused and deleted" |
| Add / Edit a programme | Price free or at least ₹499 (discount cap as a session), 1 to 24 months to use the sessions, a syllabus of 2 to 24 sessions (title 3 to 120, outline up to 600, minutes 15 to 480) with Add a session and Remove, inclusions, cover, Live; the kind is fixed once saved | W "adding a programme: a syllabus of 2 to 24 sessions…", "a programme's discount is capped…", "switching the kind in the form switches its fields", "editing a programme starts from its syllabus…"; L "a programme: its syllabus (2 to 24 sessions), the ₹499 floor and the discount cap…" |
| Pause / Resume | A partial patch of `active` alone | W "pausing and resuming a plan patch active alone"; L (both plan tests) |
| Delete | Confirm, then `DELETE /mentor-plans/:id` | W "deleting a plan asks first"; L (both plan tests) |

### Group sessions

| Control | What it does | Proved by |
| --- | --- | --- |
| The list | Draft, open for registration, held, cancelled; seats taken of capacity, waitlist, price, a series as "first day and N more days" | W "a draft, an open session, a held one and a cancelled one…", "a series reads as…", "an empty list says what a clinic is…" |
| Host a group session | Title 5 to 160, summary up to 500, agenda (plain paragraphs sent as simple HTML), how it meets (video, phone, in person, chat), a venue (in person) or a joining link (else; blank is the API's to judge: the mentor's standing link stands in), one or up to 10 days (date and time pickers, minutes 15 to 480, no overlap, in the future), seats 2 to 50 or empty for no limit, a seat price (free, or at least ₹499 and then seats are required and the waitlist is off), a waitlist switch, "Open for registration now" | W "each field is checked as the API checks it, then the session is sent as a draft", "open for registration now publishes in the same call", "an in-person session needs a venue and sends no link…", "a seat price needs seats, turns the waitlist off, and is sent in paisa", "no seat limit is sent as null, and a series of days must not overlap", "a day can be removed from a series while there are two"; L "a session is hosted as a draft, edited…, priced, published, and cancelled" |
| Details | Reads the session's detail (the list has no roster): days, seats, the roster with each person's question, the waitlist; a failed read says why and Try again reads it again | W "opening a row reads the session and shows the roster…", "a session that cannot be read says why…"; L "a session's detail carries the host's roster, with each person's question" |
| Edit | Starts from the session; the API replaces what is not sent, so the form sends back the days (with ids), cover, time zone and venue pin; days that have run are shown locked and sent back verbatim; a published session has no publish switch and keeps its waitlist; a draft can "Save and publish" | W "editing keeps what the API would otherwise blank…", "a day that has run is shown and sent back untouched", "a refused save keeps the form…", "a draft edited with the publish switch on goes live in the same save" |
| Publish | From a draft's row (no confirm), or from its sheet (confirm); `POST :id/publish` | W "a draft is published from its row, or from its sheet after a confirm; editing a draft can publish too"; L (session test) |
| Cancel session | Reason 3 to 500 characters; everyone registered is told it as written; paid seats are refunded by the API | W "cancelling needs a reason of at least three characters…"; L (session test) |
| Record who came | Only once a day has started: tick who was there (default: all who hold a seat), the rest are marked no-shows; optional minutes (15 to 480) and a note; `POST :id/complete {attendedIds (the roster rows' ids), durationMin?, note?}` | W "recording attendance appears once a day has started…", "a refused attendance keeps the form and says why"; L the not-started refusal ("This session hasn’t started yet…"): attendance itself cannot be undone, so the live test proves the wire up to the API's own refusal |

## What the audit against the real API found

* **A resource that already has its file cannot be resumed, or saved while live, without uploading the file again.** `PATCH mine/:id` reads only the body's `uploadId` for its "publish needs a file" check, and `MentorServiceDto` does not expose `uploadId`. Proved live (pause works, resume answers 400). The website has the same limit. The app opens the edit form so the file is chosen again; the additive fix is in `docs/backend-requests/mentor_offerings.md`.
* **A service PATCH replaces what it does not send** (`blurb`, `compareAtPaisa`), a plan PATCH is partial, a group session PATCH replaces title, summary, agenda, cover, link, venue, seats and price and keeps only `waitlistEnabled`, time zone, focus areas and competencies when they are omitted. The forms send back what the row holds.
* The listing cap counts every service that is not deleted, drafts included (the constant is called `maxActiveServices`).
* A group session has **no delete**: a cancelled session stays in the list. A cancelled session can still be saved and cancelled again (the API only refuses one that has run); the app offers neither.
* A paid group session's price is refused once seats are sold ("Seats are already sold at the current price — run this one and schedule another."); the form keeps what was typed and shows that sentence (W "a refused save keeps the form…").

## Handoffs kept

* **The seller terms** (`/terms`): a legal page. Accepting them is done in the app, only after a tick.
* Nothing else leaves the app: no payment happens here (a seat is sold from the session's own page to members; earnings are the desk's own Earnings tab).

## Left out

* "Repeat as separate sessions" (`POST group-sessions/batch`, up to 12 dated drafts at once): a series of up to 10 days in one session is built; the batch repeat is not.
* Cancelling one day of a series (`POST :id/occurrences/:occ/cancel`) and closing one day (`…/complete`): the session is cancelled or closed as a whole.
* Seat-by-seat registration management, the room's thread and the host's feedback card (the group session's attendee view belongs to the group sessions screen).
* Rich text for the agenda: plain paragraphs, stored as simple escaped HTML.
* Reordering listings (the website does not offer it either), and a waitlist switch on an existing session (it is set when the session is hosted and kept as it is on every edit).
* Pixel matching: no design exists for these screens; they use the mentoring kit (`lib/features/mentorship_my/widgets`).

## Seed and what the live tests leave

`tool/seed/mentoring.ts` already makes Anand's storefront (six services, a coaching plan and a programme, four group sessions); the tests only read those rows and make their own. Services and plans are deleted by the test that made them (soft delete). Each run leaves **one cancelled group session** (no delete route) and **two stored files** (a resource's PDF and a cover). `tool/seed/mentoring_offerings.ts --remove` (run from `E:\ICR\irc-portal\backend`, before `mentoring.ts --remove`) deletes the sessions the fixture mentors host that the seed did not make, and the upload records and files they own under the purposes `mentor-resource` and `mentor-offering`; it refuses any database that is not local and never touches a `dsgn-mentoring-` row.

## 7 Nov 2026: tabs, no storefront card, plainer forms

* The Offerings panel is three tabs — **1:1 mentoring** (sessions, programmes, ongoing plans) · **Group mentoring** · **Resources** (and older listings) — `offerings-tabs`.
* The **Storefront card is gone** (owner, 7 and 9 Nov 2026: "Store front has to be completely removed here"): while something still stops the mentor selling, only the API's sentence shows (key `gate-reason`) with **Accept seller terms** when the terms are the one thing missing; a live desk shows nothing. The title, the Live / Not open pill, the three checklist lines and "N of 10 service listings used" are no longer drawn.
* Forms: "Duration (minutes)" (was Length); no price criteria text and no ₹499 pre-check of the app's own (`servicePriceProblem`, `programmePriceProblem` — the API still holds `ONE_TO_ONE_MIN_PRICE_PAISA`, so its answer shows if it refuses); no "Live on your storefront" switch (Pause / Resume on the list once posted); a group session's **Mode** is Virtual | In person (phone and chat removed; an older phone/chat session edits as virtual).

## 9 Nov 2026 (bug sheet #40–#44)

* **#41** The **strikethrough price** field is gone from every offering form (`PriceBlock` no longer asks `compareAtPaisa`; the owner: "why is the strikethrough price, what is the purpose?"). A listing that already carries one keeps it; the rule (`compareAtProblem`) stays for the API's sake.
* **#44** The Storefront card is removed entirely (above). **#42** Duration (minutes), no "Live on your storefront" switch, Pause / Resume on the listing row (the pill reads Live or Paused), no ₹499 text — done 8 Nov. **#43** Group sessions meet Virtual | In person under "Mode" — done 8 Nov. **#40** one Edit My Profile on the mentor's own profile — done 8 Nov.

## 13 Nov 2026: copy refined to the client's standard

The client asked for the on-screen text to be refined "crisp, for global standard", in the style of the wording they marked up for sign-in and Settings. Wording only: no layout, colour or behaviour changed. Names of things a person taps or reads as a label are in Title Case; sentences are in sentence case with a full stop; no dash is used as punctuation; "pick" and "tick" read "select", "is told" reads "is notified", "show up / land here" reads "will appear here", and a load that fails reads "Unable to Load …". The title of an empty state or an error block is a heading (Title Case, no full stop: "No Purchases Yet", "Unable to Load Mentors"); the line under it is a sentence. The retry button reads **Try Again**.

* A form's title now takes the kind's name as it is ("Edit 1:1 Session", "Add a Resource") where it was lower-cased.
* Left as they are: the seller-terms tick ("I have read and accept the seller terms", a declaration), example hints, the price lines, and the status words already a single word ("Live", "Paused", "Draft").

| Old | New |
| --- | --- |
| Pick a date and time for every day. | Select a date and time for every day. |
| Pick a time in the future. | Select a time in the future. |
| People who registered are told when the time moves. Days that already ran cannot change. | Registered members are notified when the time changes. Past days cannot be changed. |
| Free sessions keep a waitlist; a seat price turns it off. | Free sessions keep a waitlist. A seat price turns it off. |
| Plain text; a blank line starts a new paragraph. | Plain text. A blank line starts a new paragraph. |
| When / Days | Date and Time / Days |
| Seats ({minGroupSeats} to {maxGroupSeats}; empty for no limit) | Seats ({minGroupSeats} to {maxGroupSeats}, empty for no limit) |
| Keep a waitlist when it fills | Keep a Waitlist When Full |
| Off keeps it a draft: nobody can register. | When off, it stays a draft and nobody can register. |
| Off saves a draft you can publish later. | When off, a draft is saved that you can publish later. |
| Pick a date and time | Select a Date and Time |
| Replace the file | Replace File |
| Couldn't open your files. Try again. | Unable to open your files. Try again. |
| That file is over 10 MB. | The file is larger than 10 MB. |
| Couldn't load your storefront | Unable to Load Your Storefront |
| A platform fee is taken on each sale; | A platform fee is taken on each sale. |
| Nothing listed yet. A session is booked in one go; a programme is a fixed run of sessions. | Nothing listed yet. A session is a single booking. A programme is a fixed series of sessions. |
| No resources. A guide or a template, paid or free as a lead magnet. | No resources yet. Add a guide or a template, paid or free. |
| Couldn't load your plans | Unable to Load Your Plans |
| No ongoing plans. A prepaid term with sessions every month. | No ongoing plans. A plan is a prepaid term with sessions every month. |
| Couldn't load your group sessions | Unable to Load Your Group Sessions |
| No group sessions yet. A clinic is an hour with a room of members; free ones keep a waitlist. | No group sessions yet. A clinic is an hour with a group of members. Free sessions keep a waitlist. |
| It comes off your storefront. Members who already bought it keep what they bought. | It is removed from your storefront. Members who already bought it keep their purchase. |
| Give it a title: at least {minServiceTitle} characters. | Enter a title of at least {minServiceTitle} characters. |
| Give it a title: at least {minPlanTitle} characters. | Enter a title of at least {minPlanTitle} characters. |
| Give it a title: at least {minGroupTitle} characters. | Enter a title of at least {minGroupTitle} characters. |
| Enter the price in rupees, or switch on Free. | Enter the price in rupees, or turn on Free. |
| %: the price must be at least half of the compare-at price. | %. The price must be at least half of the compare-at price. |
| Seats: a number from {min} to {max}. | Enter seats as a number from {min} to {max}. |
| The strikethrough price has to be higher than the price you are charging. | The strikethrough price must be higher than the price you charge. |
| Session {n}: a title of at least {minModuleTitle} characters. | Session {n}: enter a title of at least {minModuleTitle} characters. |
| A structured program runs between | A structured programme runs between |
| Add the joining link people will use to get in. | Add the joining link people will use. |
| Give the session at least one day. | Add at least one day to the session. |
| days: a longer run is a programme. | days. A longer series is a programme. |
| Seats: a number from {minGroupSeats} to {maxGroupSeats}, or leave it empty for no limit. | Enter seats as a number from {minGroupSeats} to {maxGroupSeats}, or leave it empty for no limit. |
| Write at least {minCancelReason} characters. | Enter at least {minCancelReason} characters. |
| Say how many sessions a month the plan includes: {minSessionsPerMonth} to {maxSessionsPerMonth}. | Enter how many sessions a month the plan includes, from {minSessionsPerMonth} to {maxSessionsPerMonth}. |
| A fixed run of sessions. | A fixed series of sessions. |
| Nothing is debited automatically: a renewal is a new purchase. | Nothing is charged automatically. A renewal is a new purchase. |
| What are you offering? | Offering Type |
| How long is a term? | Term Length |
| Sessions a month ( | Sessions per Month ( |
| Usual session length (minutes, optional) | Usual Session Length in Minutes (Optional) |
| What it includes (one line each, up to {maxInclusions}) | Inclusions (one per line, up to {maxInclusions}) |
| Replace the image | Replace Image |
| What it covers (optional) | Outline (Optional) |
| Members ask for a time; you set it. A free session is booked at once, a paid one when they pay. | Members ask for a time and you set it. A free session is booked immediately, a paid one when they pay. |
| A file members download: a guide, a template, a checklist. Free works as a lead magnet. | A file members download, such as a guide, a template or a checklist. A free resource helps attract members. |
| You can switch this one off or delete it. | You can turn this one off or delete it. |
| The file | File |
| A PDF or an image, up to 10 MB. It is needed before the resource can be live. | A PDF or an image, up to 10 MB. It is required before the resource can go live. |
| Couldn't open this session | Unable to Open This Session |
| {…} a seat | {…} per seat |
| Who is coming ( | Attendees ( |
| A draft: nobody can register until you publish it. | This is a draft. Nobody can register until you publish it. |
| Record who came | Record Attendance |
| Everyone registered is told, with your reason. | Everyone registered is notified, with your reason. |
| It opens for registration now. Check the date, the place and the seats first. | It opens for registration now. Check the date, the venue and the seats first. |
| Minutes it ran: {minSessionMinutes} to {maxSessionMinutes}, or leave it empty. | Enter the minutes it ran, from {minSessionMinutes} to {maxSessionMinutes}, or leave it empty. |
| Who came? | Who Attended? |
| Tick everyone who was there. Anyone left unticked is marked a no-show. | Select everyone who attended. Anyone not selected is marked as a no-show. |
| Minutes it actually ran (optional) | Actual Minutes (Optional) |
| A note (optional) | Note (Optional) |
| Buttons, headings, tabs, chips, field labels and status names to Title Case: 54 strings | e.g. "In person" → "In Person"; "Edit group session" → "Edit Group Session"; "Host a group session" → "Host a Group Session" |
