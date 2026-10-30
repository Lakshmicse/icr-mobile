# Events (`lib/features/events/`)

Two screens: the **Events board** (design `docs/designs/events-home.jpg`) and an **event's sheet** (design `docs/designs/event-sheet.jpg`). Built to `docs/DESIGN_REPLICATION.md`, in the shape of `lib/features/jobs/`. Refined on 23 Oct 2026 to the brief in `docs/REFINE_BRIEF.md`: the live screen, fed by the local API and the seed in `tool/seed/events-councils.ts`, reads like the PNGs, and every control is proved by a test.

## Wiring

```dart
// lib/app.dart, inside _Home (not edited by this feature)
ChangeNotifierProvider<EventsController>(
  create: (c) => EventsController(
    AppConfig.demo ? DemoEventsRepository() : ApiEventsRepository(api: c.read<ApiClient>()),
  ),
  child: ...,
)

// the tab / route that shows it
EventsScreen(
  onBack: () => AppShell.selectHome(ctx),      // goes back to Home
  viewer: _viewer,                              // the FeedAuthor the Home header already uses
  onAccount: () => AppShell.openDrawer(ctx),    // the header's photo opens the account menu
)
```

* `EventsScreen({required VoidCallback onBack, required FeedAuthor viewer, required VoidCallback onAccount})` reads an `EventsController` from Provider and starts it on first build. **No public constructor changed in this pass.**
* `Future<void> showEventSheet(BuildContext context, EventSummary event)` opens the sheet over the board with `showDetailSheet`. The sheet builds its own `EventDetailController` from `EventsController.repository` and reports every RSVP and bookmark change back to the board (`EventsController.update`), so it must be opened from a context under the `EventsController` provider.
* `EventsRepository` (abstract) · `ApiEventsRepository({required ApiClient api})` · `DemoEventsRepository()`. The abstract class gained three methods (`speakers`, `schedule`, `passFor`); both implementations have them. `EventCard` gained an optional `onDetails`.
* The design's header has no back arrow (the reader's photo is at the left), so `onBack` is used only by the error state's "Back to Home"; the shell's own `PopScope` already returns to Home on the hardware back. The screen deliberately has no `PopScope` of its own: the shell keeps every tab mounted, and a `PopScope(canPop: false)` here would stop the app exiting from Home.
* `HomeHeader` was not reused (it puts a search box where this design has the title): `EventsHeader` is its own copy. `IcrSearchField` was not reused either (its glyph and hint are larger than the design's): `_SearchBox` is a copy with the design's sizes.

## Files

| File | What |
|---|---|
| `event_models.dart` | `EventSummary`, `EventDetail`, `EventsOverview`, `EventQuery`, `EventTrack`, `EventTalk`, `EventSession`, `EventPass`, tags/footers, `RsvpState`, `EventKind`, `EventFormat` (demo-only fields are marked) |
| `events_repository.dart` | the abstract source |
| `api_events_repository.dart` | the live source |
| `demo_events_repository.dart` | the designs' sample content |
| `events_controller.dart` | board state: chips, tiles, search, filters, speaker lines, RSVP and bookmarks with rollback, "My Schedule" that follows the places |
| `event_detail_controller.dart` | one sheet's state, register/cancel with rollback, the pass |
| `event_format.dart` | IST dates, date lines, formats, tags, footers, tracks, host circles, description → paragraphs and highlight cards, talk slots and tags, pass reference, calendar link |
| `events_styles.dart` | `EventsColors`, `EventsText` (sized by measured width) |
| `events_screen.dart` | the board, the search box, the member tiles, the category row, the host card, the filter sheet |
| `event_sheet.dart` | the sheet and its bar |
| `event_pass.dart` | the pass dialog ("Show Pass", "View Pass & QR") |
| `widgets/` | `events_header`, `spotlight_card`, `event_card`, `pills` (tag pill, date badge, avatar stack, cover), `qr_code` (the QR encoder and its painter) |

## Endpoints used

| Call | For |
|---|---|
| `GET /events?when=upcoming\|past&kind=&search=&limit=100` | the board, the chips, search, the Past window (one page of 100, as the website's board reads it) |
| `GET /events/:slug` (slug or id) | the sheet |
| `GET /events/:id/programme` | the sheet's agenda (accepted talks), whether the member is invited, **and each of the first 12 cards' speaker line** (read after the board is drawn, once per event, never again on a refresh) |
| `GET /events/rsvps/mine` | each card's place, "My Schedule" |
| `POST /events/:id/rsvp` · `DELETE /events/:id/rsvp` | **Register Free / Reserve Pass / Register Now / Join Waitlist** and **Cancel**. The API answers GOING or WAITLISTED (full event). A priced event refuses the RSVP (400, "This event is ticketed…", payments being configured); a paid seat refuses to cancel (403, "Your ticket is paid for…"). Both put the card back and show the API's sentence. |
| `GET /events/:id/ticket/quote` | only for a priced event: says whether tickets are sold online right now |
| `GET /mentorship/cpd/target` (fallback `GET /mentorship/cpd/summary`) | "CPD Earned" |
| `GET /notifications/unread-count` | the bell's red dot |
| `GET /auth/me`, `GET /companies/:id` | the name and company on the pass card |

Opened on the website (`openSitePage` / `openUrl`): `/notifications` (bell), `/contact` ("Submit Topic"), `/network` ("View Network"), Google Calendar ("Add to calendar"). A priced event's **Get Tickets** opens its page **with the phone** (`openExternal`): a payment, and the app's own screen for that address is the sheet. Since 29 Oct 2026 nothing on the board or the sheet links to the event's page itself ("Overview", "Event page", the pass dialog's "Event page" are gone), and "Manage & View" opens the next booked event's sheet.

## What the design shows that the API cannot give

| Design element | The API | What the app shows |
|---|---|---|
| "● SPOTLIGHT EVENT" | no featured flag | the upcoming event with the most members going (picked in the repository). It has its own card and is **not repeated in the agenda** (it is in the design neither); a search shows its results alone, flagship included. |
| "FLAGSHIP GLOBAL GATHERING" | none | **demo only**; live: one short line, the kind and how it is attended ("CONFERENCE • HYBRID"). |
| "✓ RICS Accredited" (spotlight) and "RICS CERTIFIED" (the hero) | no accreditation field | **demo only**; live: the same slot, same type, says what the seat costs: "Free for members", "₹15,000 per pass", "Invite only" (upper case in the hero). The text is the dark grey of the design's, the tick the green one. |
| "15 CPD CREDITS" pill, "4.5 CPD Credits" | events carry no credit value | the hours the CPD ledger would credit for attending: the event's own length, or 1 hour with no end (`EventsService.markAttendance`). A three-day conference therefore reads as its whole span (56 hours for Oct 25 09:00 to Oct 27 17:00): true to the ledger, odd to read. |
| "Upcoming (24)" | not a count | events of the agenda starting in the next 30 days (the flagship, shown above, is not counted) |
| "Conferences / Webinars / Ro…" chips | kinds | one chip per kind the agenda has events of, in the design's order; each filters the agenda |
| three overlapping avatars before "1,420 Attendees Registered" | a count (`attendeeCount`, GOING only), never names (no endpoint lists attendees to a member) | three circles with the initials of the hosting chapter or council's words ("ICR Vinfraa & PropTech India Chapter" is I, V, P; "ICR" hosting alone is I, C, R), in the design's three tints. **Demo only:** the design's AI / SI / VN. |
| "My Schedule (2) — Next: AI in FM • Oct 24, 4 PM" | `rsvps/mine` | the member's GOING/WAITLISTED places still ahead; the next event's title, cut with "…" when long so **the day and hour after it always show**; it **moves at once** when a place is taken or given back, from the board or the sheet. The design's short "AI in FM" is demo only. |
| "CPD Earned 8.5 / 15 — 6.5 credits needed by Dec 31" | the member's annual target (20 h unless they set one) and hours logged this year | those two numbers, the bar filled to their ratio. "needed by Dec 31" because the target is for the calendar year; "Target for 2026 reached" past it; without a target route: "N hours logged in 2026". The seed gives Bharat the design's 8.5 of 15. |
| "Explore by Category — 6 Tracks" (Commercial Offices, Smart Tech & BMS…) | events have a kind and a **council** (the API's `council` block), no industry | **the industry tracks the agenda's councils stand for**, most events first: the council's name without "Council", cut at its first comma ("Smart Buildings, BMS & PropTech Council" is "Smart Buildings"), or at " & " when what comes first is more than one word ("Data Centre & Digital Infrastructure" is "Data Centre"), a short name in brackets winning ("(BFSI)"). The glyph is chosen by what the label talks about (`trackIconFor`). The count is the events a tap shows. "N Tracks" is the number of tiles. With fewer than two councils among the events the tiles are the event kinds (what the website's "Browse by type" does). *Why councils:* they are the one vertical the data has ("Sustainability", "Legal", "Procurement", "BFSI"…), so the tiles read like the design's, not like a second row of chips; the kind chips already filter by kind. |
| "4 Ready" | none | events of the agenda open to register (not full, not invite-only, not past) |
| "LIVE VIRTUAL" / "HYBRID" | no format field | read from the kind and venue text as the website does: a webinar or a venue naming Zoom/Teams/online is LIVE VIRTUAL, "hybrid" is HYBRID, else IN PERSON |
| "HANDS-ON LAB", "CLOSED-DOOR" | none | **demo only**; live: an invite-only event gets a red "INVITE ONLY" in CLOSED-DOOR's place, others IN PERSON / HYBRID / LIVE VIRTUAL |
| the speaker line ("Dr. Radhika Iyer, VP…") | the list carries no speakers | **live: the first accepted talk's speaker from the event's programme, "Name, bio"**, exactly where the design puts it (speaker glyph, 2 lines); an event without talks shows its venue; "By invitation only" for an invite-only one; else "Hosted by <chapter>" |
| "Early Bird Passes Open · Details · Get Tickets" | a price in paise | "₹X per pass", **Details opens the sheet**, **Get Tickets opens the event's page on the website** (tickets are bought through PayU there; the app has no checkout) |
| "18 / 25 Executive Seats Left · Request Invite" | no invite request | an invite-only event shows "N / M Seats Left" and a **Details** button (invitations are given by ICR staff) |
| "6 CPD Points · Reserve Pass" | as above | a workshop or masterclass shows its hours as "CPD Points"; Reserve Pass is a free RSVP |
| bookmark glyphs | no saved-events list | kept on the device for the session; share opens the share sheet with the title and the event's page |
| "Host or Propose an Event — Engage 18,000+ …" | none | the sentence is demo; live reads "Engage ICR's community of CRE & PropTech leaders"; "Submit Topic" opens `/contact` |
| sheet: "Pass #ICR-EVT-8849", "General Delegate" | members get no pass number | live: **"Pass #ICR-EVT-" + the event's code** (the last four letters or digits of its id, `passReference`: "FBIS" for the seeded event), "Member • <Name> (<Company>)" from `/auth/me`; an "Active Pass" pill, or "Waitlisted" with no pass to show |
| sheet: the QR, "Show Pass", "View Pass & QR" | no QR | both open **the pass dialog**: the event, its time, **a QR of the event's page** drawn by `widgets/qr_code.dart`, the pass reference, the holder, "Event page" and "Done". A waitlisted place has no pass, so its button is "Event page". |
| sheet: "Synced to Calendar" | nothing syncs | "Add to calendar" in the same place and type (green, calendar glyph): opens Google Calendar's add-event page, filled in |
| sheet: "642 Attendees Registered — 19 colleagues from TechCorp attending" | the count only | the count, the three host circles and a "+N" circle (the rest going, "+1.4k" past a thousand), then "N seats in total" or "Open to every ICR member" |
| sheet: "Smart IoT & FM Automation…" highlight cards | an event has one description | **live: the items of a bold-led list in the description** (`<li><strong>Title</strong>: text</li>` is a card with its tick, as the design draws them; the paragraphs above it stay About). A list whose items are not all titled stays text. |
| sheet: "SUMMIT AGENDA — Full Day Track • Oct 24", times, KEYNOTE / PANEL | the programme lists accepted talks (title, abstract, speaker, bio) with no slot or session type | **a card per talk with a time and a tag**: slots are laid out from the event's start, 75 minutes a talk with 15 between (the design's 10:00–11:15 and 11:30–12:45), squeezed to fit the first day, a lone talk at a short event taking it all; the tag is KEYNOTE, PANEL (green, "& Panelists" added), FIRESIDE, WORKSHOP when the talk's own words say so, else TALK. **Because ICR stores no running order the pill says "Indicative times • Oct 24"** where the design says "Full Day Track". The heading is "SUMMIT AGENDA" for a summit, else "WEBINAR AGENDA" and so on. |
| sheet: "1 delegate seat confirmed" | no seat count | the same words when the member is going (one RSVP is one seat); other states say waitlisted, invite-only, full, ended or seats left |
| sheet: "Organised by ICR Vinfraa & PropTech India Chapter" | the hosting chapter/council | its name, else "ICR" |
| sheet: "Overview" (beside About) | none | not drawn: it opened the event's page, which is this sheet (29 Oct 2026) |

All dates are shown on the Indian clock (`event_format.dart`), as ICR's notifications are.

## The seed (`tool/seed/events-councils.ts`, events half)

* **Order.** The app sorts by date and never reorders, so the seed fixes what leads: while the association seed's generic events (Nov 1 to Nov 22) stay published, the design's four board events and the sheet's event take `board` dates (Oct 24 to 27: AI webinar Oct 24 16:00, the summit Oct 25, the roundtable Oct 25 14:30, the masterclass Oct 26, the sheet's event Oct 27 10:00; times of day as designed). The agenda then reads **AI webinar, Summit, GCC roundtable, BMS masterclass, then the sheet's event**, the design's first two rows. `--isolate` hides the generic events and uses the design's own dates (Nov 12-14, Nov 25, Dec 04, Oct 24). Re-running on a later day moves the 2026 dates by whole days as before.
* **CPD.** Bharat gets three ledger entries of 2026 (ids `design-cpd-*`: a mentoring session 2 h, an event 3.5 h, a course 3 h = 8.5 h) and a target of 15 h for the year; the target he had is recorded in the manifest and put back by `--remove`.
* **A paid seat.** "Advanced Lease Audit Workshop" (₹2,000, Mar 6 2027, after every other card) holds Pooja with a PAID `EventTicket` (`design-seed-txn-paid-workshop`), so the API refuses her cancel: the live test proves that control against the real API without anything to undo. Pooja therefore holds three places (two designed, one paid). `--remove` deletes the ticket with the event.

## Controls, and the test that proves each

Widget tests (`test/events_screen_test.dart`) press the real screens over the real repository with only the API faked (`test/helpers/events_fixtures.dart`) and the browser and share-sheet channels listened to; live tests (`test/live/events_live_test.dart`) do the same against the local API and read the effect back. "—" means the control has no API effect to read back.

| Control | Widget test | Live test |
|---|---|---|
| Header photo → account menu · bell → `/notifications` · red dot = unread count | `the header` (2) | the unread count is read (`shows the member's places…`) |
| Search (keyboard Search), the ✕ in the field, "Clear", no match | `search and the filter glyph` (3) | `a search goes to the API, "Clear" comes back` |
| Filter glyph → sheet: Upcoming/Past, Anywhere/Online/In person, Show events, Clear all | `…the filter glyph opens the filters; Past…`, `Online keeps…` | `the filter glyph's Past window reads the past events; Online keeps the online ones` |
| Chips: All Events, Upcoming (N), Conferences, Webinars, Roundtables, Workshops, Chapter meetups | `each chip narrows the agenda…`, `"Upcoming (6)"…` | `a kind chip shows that kind's events only…`, `"Upcoming (N)" is the events of the next 30 days` |
| Category tiles: narrow, tap again lifts, work with a chip, Clear | `a tile narrows…`, `a tile and a chip work together` | `a category tile narrows the agenda to its track…` |
| Spotlight: bookmark · RSVP Free (+ refusal) · the card opens the sheet | `the flagship card` (4) | RSVP is the card flow below, on the same `register` |
| Card: **Register Free**, **Reserve Pass**, **Join Waitlist** (+ a refusal) | `the cards of the agenda` (Register, Reserve, refused, full) | `Register Free / Reserve Pass: the API keeps the place, My Schedule counts it, Cancel gives it back`; `an invitation is a place…` |
| Card: **Get Tickets** → the event's page; **Details** → sheet (priced too); invite-only **Details**; **View** on a held place; the card itself | `Get Tickets opens…`, `Details opens the sheet…`, `an invite-only event's button…`, `View…`, `the card itself…` | — |
| Card: share (the title and the page) · bookmark (its own card only) | `share hands the share sheet…`, `the bookmark glyph toggles…` | `a bookmark stays on the device…` |
| "Manage & View" → the next booked event's sheet (hidden with nothing booked) · "Submit Topic" → `/contact` · pull to refresh · the error state's Try again / Back to Home | `the tiles and the host card` (3), `the error state…` | — |
| Sheet: pills, pass card, booking line, programme with times and tags | `a held place: the confirmed pill…` | `reads the seeded event: organiser, pass, highlights and the programme…` |
| Sheet: **Register Now** (+ refusal) · **Cancel** (the pill, the pass card, the counts and the board's tile follow) · re-register brings the pass back | `Cancel gives the place back…`, `Register Now takes the place again…`, `an open event: Register Now registers, and a refusal says why` | `the sheet registers and cancels through the same routes, and tells the board` |
| A **priced seat refuses the RSVP**, a **paid seat refuses Cancel**: the API's sentence is shown, the card goes back | `a paid seat refuses to cancel…`, controller tests | `a priced seat is refused as a free place…`, `a paid seat refuses to cancel…` |
| **Show Pass** and **View Pass & QR** → the pass dialog (reference, holder, QR of the page, Done, ✕); a place with no pass yet has no button | `Show Pass and View Pass & QR open the pass…` | — |
| **Add to calendar** → Google Calendar · **View Network** → `/network` | `Add to calendar…`, `View Network opens the network…` | — |
| Sheet share · bookmark (the board agrees) · ✕ · the system Back | `share and bookmark…`, `the cross and the back button close the sheet` | — |
| Sheet states: Get Tickets (priced), By invitation (not asked), waitlisted, ended | `a priced event…`, `an invite-only event the member was not asked to…`, `a waitlisted place…`, `a past event…` | `an invite-only event is on the board for the people asked to it, and for nobody else` |

`test/events_qr_test.dart` proves the QR: sizes and capacity by version, the finder, timing, alignment and dark-module structure, both copies of the format information and the version information, and **module-for-module equality with the Python `qrcode` library** for four codes (versions 1, 5, 9, 10; SHA-256 of the rows). When it was written every code (all eight masks, versions 1 to 10, UTF-8) matched that library, and **OpenCV's QR detector read the painted dialog back to the event's address** with both of its detectors at three scales.

## Tests and goldens

* `test/events_test.dart` (logic): formatting, the description's highlight cards, tracks and their glyphs, host circles, talk slots and tags, the pass reference, the calendar link, the API mapping through the fake API (board, spotlight apart, tracks by council or by kind, schedule, CPD year, query parameters, format filter, the sheet with programme and company, waitlisted pass, speaker lookups capped at 12, RSVP routes, refusals), the controllers (chips, tiles, search, filters, speakers read once, register/cancel with rollback, the schedule following, waitlist, priced refusal, paid-seat refusal, bookmarks, a board that cannot load) and the demo content.
* `test/events_screen_test.dart`, `test/events_qr_test.dart`: above. `test/helpers/events_fixtures.dart`: the fake API and the small world they share.
* `test/golden/events_golden_test.dart`: four goldens at 2x. `events_home.png` (390 × 2154.5 dp) and `event_sheet.png` (390 × 1130.5 dp) are **the design's own content** (demo source) and the ones to compare with the PNGs; `events_home_api.png` and `event_sheet_api.png` are **what the API gives** through the real repository (a fake API with fixed dates in 2099, so the render is the same every day; no cover pictures). All four export to `build/screens/`.
* `test/live/events_live_test.dart` (tag `live`, skipped when the API is down; 22 tests): the table above, plus renders of the live screens to `build/screens/events_home_live.png` and `event_sheet_*_live.png` (the covers read from the bundle, since a widget test cannot fetch `/uploads`). Every write is Pooja's, on events she holds no place at, given back by a tear-down even when the test fails; Bharat's two designed places are never touched. The API answers 120 requests a minute per address and other agents' tests share it, so the suite signs in once per person, loads each board once and waits out a 429.
* Compare: `python tool/design/compare.py <flat design> build/screens/events_home.png --out side.png`, or `devcompare.py`. The designs are small JPEGs (362 and 690 px wide) scaled to 780, so edges are soft and glyph offsets under about 2 dp are noise; solid shapes (buttons, pills, cards) are measured by colour.

Measured against the designs (dp, design vs render; 2x pixels / 2):

* Home, demo render: avatar and title rows 39–59 vs 40–59 px; "All Events" chip 220–269 vs 220–271; flagship photo top 287 vs 286; **RSVP button 76.5 × 31 vs 76.5 × 31** (it was 83 × 36 before this pass, with 16 dp padding); "SPOTLIGHT EVENT" pill 103.5 × 28 vs 104 × 28 and "15 CPD CREDITS" 79 × 28.5 vs 79.5 × 28; "Explore by Category" heading 955–976 vs 956–976; "Upcoming Agenda" heading 1109–1130 vs 1109–1129; "4 Ready" pill 42 × 16 vs 42 × 16.5; host card 369 × 71 at (10.5, 1480.5) vs 370 × 71 at (10, 1480.5); card pills' fill sizes within 1 dp apart from the two whose text the design's narrower face sets 4–6 dp narrower (LIVE VIRTUAL, CLOSED-DOOR); the filter glyph moved 3 dp right (it was 4.5 dp off); the card pills moved 1.5 dp down and are 28 dp high.
* The API-shaped board has the same anchors (header, chips, flagship photo, section headings and the first card within 1 px at 2x).
* Sheet: pills, hero, pass card, panel, About, highlight cards, agenda and bar within 1.5 dp (as before); link texts and icons are now the design's navy; "View Network" 4 dp further right as in the design.

## Remaining deviations

* **Type.** The designs are set in a narrower face than IBM Plex Sans, so text is sized by measured width and its glyphs read about 1 dp shorter than the design's; caps pills are width-fitted with no tracking, the kickers use tracking with a smaller size. The two-line "19 colleagues from TechCorp attenc…" clip is not reproduced.
* **Glyphs** are Lucide / Material Symbols, not the design's: the QR, "Synced", the CPD medal, the host card's icon, the speaker and group glyphs, the bookmark (10 dp ink wide against the design's 8) differ in drawing, not in place.
* **The handle rule.** `DetailSheetFrame` draws a 1 dp #F1F5F9 rule under the grab handle that this design lacks.
* **The bar's right margin.** The design's bar buttons end 35.5 dp from the right edge (16 on the left); the sheet reproduces that while there is a Cancel button, and uses 16 dp both sides when there is only one button.
* **Shadows** on cards, tiles and the sheet's bar are a little lighter than the export's; the highlight and session cards have a faint border the design draws as shadow only.
* **Clipped footers** ("Request Invite", "Get Tickets") run past the card's padding and are cut at the card's edge, as the design draws them; the left end of "Get Tickets" is still tappable.
* **Dates.** With the generic events published, four of the design's cards and the sheet's event carry dates Oct 24 to 27 instead of Nov 12-14, Nov 25, Dec 04 and Oct 24 (see the seed); `--isolate` restores the design's. The "Next:" tile reads the sheet's event ("Oct 27, 10 AM"), because Bharat holds that place, not the AI webinar.
* **Not drawn by the API:** attendee names, pass numbers, accreditation, a real running order. The tiles, circles and times that stand in for them are described above and say so where a member could mistake them ("Indicative times").

## Left out

* The industry and price filters (events have neither), a calendar view, a saved-events list, ticket checkout (website), proposing a talk and sponsoring (website), pagination beyond the first 100 events of a window, a live buy-then-cancel proof of a paid seat (it cannot be undone by a member; the seeded ticket proves the refusal instead).
