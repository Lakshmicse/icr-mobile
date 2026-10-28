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
