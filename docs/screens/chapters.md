# Regional Chapters

The Regional Chapters board (`ChaptersScreen`), a chapter's quick-look sheet (`ChapterPreviewSheet`) and a chapter's own page (`ChapterScreen`). There is **no design** for these: they are built in the language of the Councils and Events designs (cover cards, pill chips, 10 dp corners, Work Sans headings, IBM Plex Sans body in Medium), from the website's `/chapters` board and `/chapters/[slug]` page (`frontend/src/components/association/chapters/**` and `chapter/**`) and the portal's `association` module.

Status (26 Oct 2026): **audited against the live API; board, page, preview, join/leave and meetup RSVP built and proved** by `test/chapters_test.dart` (82 tests) and `test/live/chapters_live_test.dart` (13 live tests). Goldens are postponed (owner's call).

## Entry points (for the lead to wire)

```dart
// The board. Reads a ChaptersController from Provider (convention of the other tab screens).
ChangeNotifierProvider<ChaptersController>(
  create: (c) => ChaptersController(
    sample ? DemoChaptersRepository() : ApiChaptersRepository(api: c.read<ApiClient>()),
  ),
  child: ChaptersScreen(
    onBack: () => Navigator.of(ctx).pop(),
    onOpenEvent: (slugOrId) => ...,          // the Events sheet for that event
    onOpenVolunteer: (chapterName) => ...,   // GetInvolvedScreen(chapterName: chapterName); null from the board
    onBell: () => ...,                        // optional; the website's /notifications when null
    onOpenMember: (userId) => ...,            // optional; rows are not tappable without it
    onMessage: (userId) => ...,               // optional; no message glyph without it
  ),
)

// One chapter, by slug or id (a council's city tile, a notification, a card):
Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => chapterPage(
  repository: repo,                // ApiChaptersRepository(api: ...) or DemoChaptersRepository()
  idOrSlug: 'bengaluru',
  handoffs: ChapterHandoffs(onOpenEvent: ..., onOpenVolunteer: ..., onBell: ..., onOpenMember: ..., onMessage: ...),
)));
// or, from inside a screen that has a context: openChapterPage(context, repository:, idOrSlug:, handoffs:)
```

`ChapterScreen` itself reads a `ChapterController` from Provider; `chapterPage(...)` is the builder that creates it. `onOpenEvent` receives the event's **slug (else its id)**, what `GET /events/:slug` reads.

## Endpoints

| Call | Used for |
|---|---|
| `GET /chapters?limit=100` (every page) | the directory, the tiles (count, members, countries, upcoming events) |
| `GET /chapters/memberships/mine` | the member's seats and their role (`LEAD`/`MEMBER`); a 401 reads as none |
| `GET /events?when=upcoming` (every page, 3 at most) | the board's "Upcoming Meetups" (only events with a `chapter`) and each chapter's "Next:" |
| `GET /chapters/:slug` | the page and the preview sheet: about (`aboutHtml` as headings, paragraphs, bullets), gallery, stats, sponsors, committee (`leads`), next events. An **id** is looked up on the board first (the API reads by slug) |
| `GET /chapters/:slug/members?page&limit=12&search&role=LEAD&hasCompany=true` | the roster, its three filters (All / Corporate only / Committee), search, "Show more members" |
| `GET /events?chapterSlug=&when=upcoming|past&limit=12` + `GET /events/rsvps/mine` | the page's Events tab with the member's RSVP on each row |
| `GET /chapters/:slug/announcements` | Updates (pinned first, then newest) |
| `GET /chapters/:slug/resources` | Resources (tag from the kind: PPTX/PDF/XLSX/MP4/FILE) |
| `GET /chapters?country=` | "Other chapters in <country>" |
| `POST /chapters/:id/join`, `DELETE /chapters/:id/join` | Join Chapter / Leave |
| `POST /events/:id/rsvp`, `DELETE /events/:id/rsvp` | RSVP / Join waitlist / Cancel on a meetup |
| `GET /notifications/unread-count` | the bell's dot |

## What the audit found (and fixed)

Read against real calls on 26 Oct 2026 (Bharat Buyer): the previous builder's parsers matched every shape. What was wrong or missing:

1. **`GET /events/rsvps/mine` lists CANCELLED rows.** The API keeps a row after a member cancels; the old mapping showed "Cancelled" next to the event. A cancelled place is now no RSVP (`ApiChaptersRepository._rsvps`), tested with the API's own rows.
2. **A join never demotes and a leave takes the committee seat with it.** `POST /chapters/:id/join` is an upsert that keeps `LEAD`; `DELETE` deletes the row, title and LinkedIn link included. The website therefore shows a lead "Chapter lead" and **no Leave**. The app does the same (card, page and preview), so a lead cannot give their seat up by accident.
3. **Meetups had no RSVP.** The rows only opened the event. The page's Events tab now RSVPs through the events API (see below).
4. **The chapter page lists an invite-only event to anyone.** `GET /chapters/:slug` (`upcomingEvents`) does not apply the invite filter that `GET /events` does, so a closed event shows on the page and in the preview to a member who was not asked. The row says "INVITE ONLY", and an RSVP the API refuses ("This event is invite-only.") is shown as it is.
5. Board code used `DateTime.now()` for "New": it is now the controller's injectable clock (goldens and tests pin it).
6. Body text was Regular; paragraphs are Medium (w500) like the Councils and Events cards (`community_kit.dart`: `body`, `cardCopy`, `meta`, `personLine`).

## The board

Top to bottom: four tiles (Chapters, Members, Countries, Upcoming events), **Your Chapters** (a sideways rail of the member's seats, leads first), **Upcoming Meetups** (three rows), then the directory: search, the **scope chips** (All Chapters (n), Joined (n), Nearby (n)), the **country chips** (All Countries (n) + one per country), the result count with Clear filters, the chapter cards, and a "Lead or serve on a chapter" card (hidden without `onOpenVolunteer`).

- **Nearby** = chapters the member has not joined, in a *region or country* of one they have (the website's place-overlap recommendation; a shared region counts two, a country one). The app asks for no location permission. With no seat of their own the tab says so ("Nothing nearby yet") and offers "Show all chapters".
- The sliders glyph opens **Sort and filter**: Sort by (Recommended, Most members, Most active, Newest, A to Z), **Region** (states within the country chip), **City** (within region and country), Members (any, 1–2, 3–10, 10+), Activity (any, has upcoming events, new this quarter). Reset, Show chapters. A dot on the glyph shows a filter or a sort is on.
- A card: banner (photo or the website's slug-hashed two-tone gradient with the place's glyph), JOINED / Lead / Member pills or NEW (chartered within 60 days), name, place, two lines of copy, members and upcoming events, "Next: Nov 01"; **Join Chapter** or **Open Chapter**; **Preview Chapter** or **Leave** (a lead's reads Preview Chapter).
- **Preview Chapter** opens a bottom sheet read from `GET /chapters/:slug`: banner, name, place, member/event/founded pills, overview, the first three committee members, the next three events, Join / Joined + Leave, Share, "View full details". Joining in the sheet changes the card and the rail behind it.
- Pull to refresh reads everything again (the bell too). A failed read shows "Couldn't load chapters" + Try again.

## A chapter's page

Banner with the city's initial, name + official badge, region, place, "Est. 2014", copy; **Join Chapter** or the Joined pill + **Leave** (confirmation first; a lead sees "Chapter lead" and no Leave); Share (the phone's share sheet with the website link), Email the chapter (`mailto:` the chapter's contact address, only when it has one), "Volunteer with this chapter" (`onOpenVolunteer(name)`).

Four tiles (Active members + "n on committee", Member companies, Upcoming events + "RSVP open", Hosted sessions + "since 2014"); section chips scroll to **About**, Gallery (tap to enlarge), **Leadership** (tap = `onOpenMember(id)`, message glyph = `onMessage(id)`, link glyph = LinkedIn), **Events & meetups**, **Updates**, **Resources**, **Members**, Sponsors, "Other chapters in <country>". Each section loads on its own: one that fails shows its own sentence and Try again and leaves the page standing.

### Meetups and RSVP (the events API)

Each upcoming row on the page carries the member's place, drawn from `GET /events/rsvps/mine` and changed through `POST|DELETE /events/:id/rsvp`:

| State | Control |
|---|---|
| free, seats left | **RSVP** → GOING at once, the going count +1, kept or rolled back by the API's answer |
| full (`attendeeCount >= capacity`) | **Join waitlist** → WAITLISTED (a waitlisted place takes no seat, so the count does not move) |
| GOING / WAITLISTED | "You are going" / "On the waitlist" + **Cancel** (the API refuses a paid ticket: its sentence is shown and the place stays) |
| ticketed (`priceAmount > 0`) | **Get ticket** → `onOpenEvent`, the Events sheet sells it (a bare RSVP is refused by the API with "This event is ticketed…") |
| over | "Event ended" |
| Past tab | no control |

An invite-only event shows RSVP like any other; the API's refusal ("by invitation only") is shown in a snackbar and the row goes back as it was. A row tap opens the event sheet (`onOpenEvent`).

## Handoffs kept

| Handoff | Why |
|---|---|
| Notifications (when `onBell` is null) | the shell opens its own screen; the website page is only the fallback |
| Email the chapter, LinkedIn, a sponsor, a resource's file | an address, a profile or a file that lives outside ICR |

Nothing else leaves the app.

## Controls and the tests that prove them

`W` = `test/chapters_test.dart`, `L` = `test/live/chapters_live_test.dart`.

| Control | Proved by |
|---|---|
| Back, bell (own or website), bell dot | W "Back and the bell", "the bell wears its dot…" |
| tiles, rail, meetups, cards from the API | W "draws the numbers…"; L "the board is the API's…", "the board's meetups…" |
| meetup row → event by slug | W "a meetup opens through the callback…" |
| search, Clear filters | W "the search narrows the cards…"; L "search, country, scope, region and city…" |
| scope chips (All / Joined / Nearby), Nearby with no seat | W "the scope chips…", "Nearby with no chapter of my own…"; L the same live test |
| country chips | W "a country chip narrows…" |
| sort / region / city / size / activity sheet, Reset | W "the sliders glyph opens…", "the sheet filters by region and by city…", "a country chip drops a region…" |
| Join Chapter (optimistic, rolled back with the API's sentence), Leave (asks first) | W "Join Chapter takes the place…", "a refused join…", "Leave asks first…"; L "a chapter joined from the screen…", "a join with no session is refused…" |
| lead has no Leave; a join never demotes | W "a chapter lead has no Leave…", "a lead sees Chapter lead…"; L "joining a chapter I already lead keeps the lead role" |
| Preview Chapter, Join/Leave/Share in it, View full details, its failure | W the four "Preview" tests |
| card → page, page → board follows the place | W "a card opens the chapter's page", "a place the member takes on a chapter's page shows on the board behind it" |
| Get involved / Volunteer with this chapter | W the two "…is the shell's callback" tests |
| Share, Email, LinkedIn, resource, sponsor | W "Share hands the chapter…", "the committee's link, a resource and a sponsor open…" |
| committee row, message glyph, roster row | W "a committee row opens the member…", "a roster row opens the member too" |
| section chips scroll | W "the section chips scroll to their section" |
| Events Upcoming / Past | W "Events: Upcoming and Past…"; L "a chapter's events…" |
| RSVP, waitlist, refusal, paid cancel refused, ticket, ended | W the "a chapter's meetups" group; L "an RSVP from a chapter's page…", "an RSVP with no session…" |
| CANCELLED rows are no RSVP | W "the API's RSVP rows…" |
| Members: total, Show more, the three filters, search | W "Members: the total…"; L "the roster pages…" |
| a failing section: its own Try again | W "a section that fails says so itself…" |
| Other chapters card | W "an Other chapters card opens that chapter's own page" |
| pull to refresh (board, page) | W "pulling down reads…" |
| failed read / empty / loading | W "loading shows a spinner…", "an empty directory says so", "with no chapter joined…" |

## Seed

`tool/seed/chapters.ts` (see `tool/seed/README.md`) gives the four designed chapters (Bengaluru, Mumbai, Delhi NCR, Hyderabad) a cover photo, a local gallery (the portal's gallery links are external and do not load offline), a contact address, 8 to 11 more members each (16 shared people with a portrait and a current role, so the roster shows "title · company" and Corporate only works), two past events each (the Past tab), and upcoming ones that exercise every RSVP state: a free meetup in Bengaluru, Mumbai and Hyderabad, a **ticketed** workshop in Mumbai (Get ticket), a **full** one in Delhi NCR (capacity 12, twelve going: Join waitlist) and an **invite-only** roundtable in Hyderabad. Each chapter's four existing resources are pointed at real files (a whitepaper PDF, a deck, a scorecard workbook) instead of example.com. Dates move with the day the script runs. It never touches Bharat's or Pooja's seats.

## Demo content

`DemoChaptersRepository`: six city chapters (the member leads Bengaluru and belongs to Pune), their events, committees, rosters, dispatches and decks; joins and RSVPs are kept in memory.

## Left

- Goldens (postponed).
- The Discover sheet's "Regional Chapters" door, the profile drawer's "BLR" chip and the wiring of the callbacks above are the lead's.
- `GET /chapters/:slug` lists invite-only events to anyone (backend request 5 in `docs/backend-requests/community.md`).
