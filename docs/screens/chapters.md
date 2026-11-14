# Chapters

The Chapters board (`ChaptersScreen`), a chapter's quick-look sheet (`ChapterPreviewSheet`) and a chapter's own page (`ChapterScreen`). There is **no design** for these: they are built in the language of the Councils and Events designs (cover cards, pill chips, 10 dp corners, Work Sans headings, IBM Plex Sans body in Medium), from the website's `/chapters` board and `/chapters/[slug]` page (`frontend/src/components/association/chapters/**` and `chapter/**`) and the portal's `association` module.

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
| `GET /chapters?limit=100` (every page) | the directory (the counts it once fed the four tiles are no longer drawn) |
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

Top to bottom: **Your Chapters** (a sideways rail of the member's seats, leads first), **Upcoming Meetups** (three rows), then the directory: search, the **scope chips** (All Chapters (n), Joined (n), Nearby (n)), the **country chips** (All Countries (n) + one per country), the result count with Clear filters, the chapter cards, and a "Lead or serve on a chapter" card (hidden without `onOpenVolunteer`).

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
| rail, meetups, cards from the API | W "draws the numbers…"; L "the board is the API's…", "the board's meetups…" |
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
- The Discover sheet's "Chapters" door, the profile drawer's "BLR" chip and the wiring of the callbacks above are the lead's.
- `GET /chapters/:slug` lists invite-only events to anyone (backend request 5 in `docs/backend-requests/community.md`).


## 12 Nov 2026: no count tiles over the hub

The owner, shown the Digital Library's four count tiles: "like these 4 titles in Chapter, councils, Events remove it". The Chapters hub no longer opens with the Chapters / Members / Countries / Upcoming events tiles and the rule under them: it opens on **Your Chapters**. `ChaptersStats` is still read from the API (`ChaptersController.stats`) and still drawn nowhere. `CommunityStatGrid` stays for the chapter page's own figures and the library's document page.

## 13 Nov 2026: copy refined to the client's standard

The client marked up the user manual with the wording wanted on a dozen screens and asked for the rest of the app to read the same way: Title Case for what a person taps or reads as a label, a short sentence with a full stop for everything else, plain international English, no dash inside a sentence. Wording only: no layout, colour or behaviour changed. Semantics-only labels (what a screen reader says for an icon) were left as they were. By the lead's ruling the title of an empty, locked or error state is a heading (Title Case, no full stop) with a sentence under it, and the retry button reads **Try Again** everywhere.

| Where | Old | New |
|---|---|---|
| Filters and sorts to Title Case (12) | Any size · 1–2 members · 3–10 members · 10+ members · Any activity · Has upcoming events · New this quarter · Most members · Most active · All members · Corporate only · Any region · Any city | Any Size · 1–2 Members · 3–10 Members · 10+ Members · Any Activity · Has Upcoming Events · New This Quarter · Most Members · Most Active · All Members · Corporate Only · Any Region · Any City |
| Headings, buttons, pills to Title Case (19) | Chapter events · Clear filters · Sort and filter · Sort by · Show chapters · Show all chapters · Lead or serve on a chapter · Get involved · Chapter lead · Open chapter · Active members · Member companies · Upcoming events · Hosted sessions · Events & meetups · Other chapters in India · Volunteer with this chapter · View full details · Official ICR chapter | Chapter Events · Clear Filters · Sort and Filter · Sort By · Show Chapters · Show All Chapters · Lead or Serve on a Chapter · Get Involved · Chapter Lead · Open Chapter · Active Members · Member Companies · Upcoming Events · Hosted Sessions · Events & Meetups · Other Chapters in India · Volunteer with This Chapter · View Full Details · Official ICR Chapter |
| A meetup's row | You attended · You are going · On the waitlist · Event ended · Get ticket · Join waitlist | You Attended · You Are Going · On the Waitlist · Event Ended · Get Ticket · Join Waitlist |
| More of the roster | Show more members | View More |
| Not loaded | Couldn't load chapters · Couldn't load this chapter | Unable to Load Chapters · Unable to Load This Chapter (with **Try Again**) |
| Empty board | No chapters match · No chapters yet | No Chapters Match · No Chapters Yet |
| Empty: Nearby | Nothing nearby yet / Nearby shows chapters in the regions and countries of the ones you join. Join your own city first. | No Nearby Chapters Yet / Nearby shows chapters in the regions and countries of chapters you join. Join your city's chapter first. |
| The preview's events, the page's About | Nothing scheduled yet. Check back soon. · This chapter has not written its About text yet. | No events scheduled yet. Check back soon. · This chapter has not added a description yet. |
| A resource that will not download | "x" has no real file yet: its address is only a placeholder. · That address sent nothing back. · That file came back empty. · That file is too large… · That file isn't at its address any more (host says 404). · host won't let the app download that file (403). · Couldn't make a secure connection to host. · Couldn't reach host. … · Couldn't download that file. Try again. · Couldn't download "x". Try again. | "x" has no file yet. Its address is a placeholder. · No response from that address. · The file is empty. · The file is too large… · The file is no longer available (host returned 404). · host does not allow the app to download this file (403). · Unable to make a secure connection to host. · Unable to reach host. … · Unable to download the file. Try again. · Unable to download "x". Try again. |
| A resource that is a page | Open page | Open Page |
| Clear the search (tooltip, shared `CommunitySearchField`) | Clear search | Clear Search |

## Managing (13 Nov 2026)

For the staff who hold `chapters:manage` (a Super Admin, or a member given the Chapters Admin or Community Manager role on the website),
a pencil left of the bell on the board opens Manage Chapters, and on a chapter's page that chapter's manage page. Nobody else sees a pencil. The pages stand over the app's bottom bar, as Home does. See
`docs/screens/community_manage.md` and `docs/FLOW_PARITY.md` → "Managing Chapters, Councils and Events from the app".


## 13 Nov 2026: "Chapters", not "Regional Chapters"

The owner: "change the name Regional Chapters ----> Chapters." The board's title, the drawer's row, the search catalogue's entry and the Councils footer's button ("View Chapters Directory") all say Chapters. Left as they are: the chapter kinds in the manage console ("Regional chapter" against "Country chapter") and the Councils footer's heading "Regional In-Person Chapters".
