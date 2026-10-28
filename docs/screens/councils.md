# Councils

The Councils screen (`docs/designs/councils.png`): one long page — the stat tiles, the member's joined councils, the upcoming roundtables, the searchable directory of council cards, and the In-Person Summits footer that leads to the city chapters.

## Screens and wiring

- `CouncilsScreen({required VoidCallback onBack, opener})` — `lib/features/councils/councils_screen.dart`. Reads a `CouncilsController` from Provider and calls `start()` on first build. `opener` hands a page to the browser (default `openUrl`); tests give their own to see which page a control asks for.
- The controller is provided where the route is built (`lib/app_screens.dart`, `'/councils'`):

  ```dart
  ChangeNotifierProvider<CouncilsController>(
    create: (c) => CouncilsController(
      sample ? DemoCouncilsRepository() : ApiCouncilsRepository(api: c.read<ApiClient>()),
    ),
    child: CouncilsScreen(onBack: () => Navigator.of(ctx).pop()),
  )
  ```

- `CouncilsRepository` (abstract) → `ApiCouncilsRepository({required ApiClient api, clock})` and `DemoCouncilsRepository()`. Besides `overview`/`join`/`leave`/`unreadNotifications` it hands out the pages a control opens: `link(council, {tab})`, `eventLink`, `calendarLink`, `chapterLink`. Models in `council_models.dart`, formatting and the small rules (peer label, lead line, roundtable mode, age tier, calendar entry, rail order) in `council_format.dart`, type and colours in `councils_styles.dart`, widgets under `widgets/`.
- Golden: `test/golden/councils_golden_test.dart` renders the demo screen at the design's frame, 390 × 2829.5 dp at 2x (`Size(780, 5659)`), writes `build/screens/councils.png` and matches `test/golden/goldens/councils.png`. Unit and control tests: `test/councils_test.dart` (formatting, the API mapping, the controller, every control on the screen) and `test/council_card_test.dart` (the cards, the row and the tiles). Live tests against the local API: `test/live/councils_live_test.dart` (`flutter test test/live/councils_live_test.dart`; it also writes `build/screens/councils_live.png`, the screen drawn from the live API, for `tool/design` comparisons).

## Design frame

The export is 283 × 2000 px, a phone frame drawn with a 1 px border at x = 5 and x = 281 and y = 4. The interior (x 6–280, y 5–1999; 275 px) is the 390 dp frame, so 0.705 px per dp and 2829.5 dp tall. For comparisons the interior is cropped and resampled to 780 px wide (`flat.png`).

## Endpoints

| Call | Used for |
|---|---|
| `GET /councils?limit=100` (every page) | the directory and the stats (count from `meta.total`, member sum, distinct segments, "+N Qn" from `createdAt` in the running quarter) |
| `GET /councils/memberships/mine` | the joined rail and the JOINED pills (`role` LEAD → "Executive Seat", MEMBER → "Member"); a 401 (signed out) reads as none |
| `GET /councils/:slug/announcements` | one read per council the member belongs to: the "N unread" pill (see below) |
| `GET /events?when=upcoming` (every page) | each council's "Next: Apr 18" (its soonest event of any kind) and each chapter's next date (events with a `chapter`) |
| `GET /events?when=upcoming&kind=ROUNDTABLE` | the three Upcoming Roundtables rows and the "Active Roundtables" tile (the council-hosted ones) |
| `GET /chapters?limit=50` | the footer's four city tiles, the ones with the soonest event first |
| `POST /councils/:id/join`, `DELETE /councils/:id/join` | Join Council; leave through a long press on "Open Member Lounge" |
| `GET /notifications/unread-count` | the bell's dot |

Pages the screen hands to the browser (`SITE_URL`): `/councils/<slug>` (Preview Chapter, a joined card's body), `/councils/<slug>?tab=events` (Room Link, Meeting link), `/councils/<slug>?tab=updates` (Open Member Lounge, the "N unread" pill; the website's Updates tab is the council's announcements), `/councils` (Manage →), `/events/<slug>` (a roundtable row), `/events` (the caption at the right of Upcoming Roundtables), `/chapters/<slug>` (a city tile), `/chapters` (View Regional Chapters Directory), `/notifications` (the bell). The calendar glyph on a row opens a Google Calendar "new event" page (`calendar.google.com/calendar/render?action=TEMPLATE…`) with the event's own title, start, end and venue and a link back to its page: the API has no .ics file for an event (the website builds one in the browser).

## What the API cannot give, and what is shown instead

| Design | Shown live |
|---|---|
| "Active Councils — 39" | the API's total (`meta.total`), under the design's label; it is the database's number, not 39 |
| "+3 Q1" | councils created since the first day of the running quarter, "+N Qn"; hidden when none. The seed creates three of the designed councils (CXO, Legal, Real Estate) in the running quarter, so it reads "+3 Q4" |
| "Peer Members — 2,530+" | the sum of `memberCount` (a person in three councils counts three times), rounded **down to ten** with the design's plus from a hundred up, grouped: 1,016 → "1,010+"; under a hundred, exact |
| "Domains Covered — 152" | the number of distinct `segments` across the councils (the website's "industries covered" KPI) |
| "Active Roundtables — 14" with a green dot | the number of upcoming council-hosted events of the roundtable kind (the rows' own set); the dot only while it is above zero |
| "3 unread" on a joined card | **"N unread" = the announcements the council posted in the last 30 days** (`GET /councils/:slug/announcements`). Nothing in the API says what a member has read: `CouncilAnnouncement` has no read state and posting one sends no notification. A council with nothing recent shows "Next Sync: Apr 18" (its next event) instead, as the design's second card does. The pill opens the council's Updates tab |
| "Room Link" / "Meeting link" | an executive seat gets the blue Room Link, a member the outlined Meeting link; the API has no room or meeting URL, so both open the council's Events tab on the website, where its sessions are |
| "Live Chatham-House" | "All events", opening `/events`; the API has no house rule |
| the roundtable rows | **council-hosted events of kind ROUNDTABLE, soonest first** (the website's own roundtable kind; the portal's other council events are workshops, webinars and a conference and are not rows). A row's "Next:" on the card above still counts any kind |
| "VIRTUAL" / "HYBRID BLR" / "CLOSED-DOOR" | from the event: `inviteOnly` → CLOSED-DOOR (grey); a venue naming "Hybrid" → "HYBRID" + the city's code taken from the venue ("Bengaluru (Hybrid)" → BLR, green, with the green date tile); a venue of "Online"/"Virtual" or a webinar → VIRTUAL (blue); anything else → IN-PERSON (green) |
| "Lead: Vikram Malhotra (DLF) • 82 seats claimed" | the hosting council's `chair` (its first titled lead) and the event's GOING count (`attendeeCount`): "Lead: <name> (<organisation>) • N seats claimed". The organisation is what follows the "@" in the chair's title, up to a line break ("Director ESG @ DLF" → DLF; "General Counsel @ Brookfield⏎India" → Brookfield); no "@", no brackets; no chair, the council's name instead |
| "OFFICIAL COUNCIL · Est. 2023" / "CHARTERED 2024" / bare "OFFICIAL COUNCIL" | the API has no tier, so the cover is dressed from the council's **age** (`councilTier`): three years or more, "OFFICIAL COUNCIL" + "Est. <year>"; chartered in the last three years, "CHARTERED <year>" alone; under a year, "OFFICIAL COUNCIL" alone. The year is the Indian-clock year of `createdAt` |
| "✓ JOINED · Executive" | from the membership: JOINED plus "Executive" (LEAD) or "Member" |
| the cover photo | `coverUrl`; without one, the website's two-tone gradient hashed from the slug with the industry glyph. The app darkens a photo mildly (alpha .10 at the top to .20 at the bottom, `CouncilsColors.coverScrim*`) |
| the glyph tile | chosen from the name and segments as the website's `industryIconKey` does, drawn as the design draws it: a bold Material symbol, filled except the leaf, the chip and the hand holding a house (`IndustryGlyph`, 26 dp box, ink about 20 dp). "Construction" is read before "legal", or "Project Governance" would give a construction council the gavel |
| "Chair: Vikram Malhotra, Director ESG @ DLF" | the council's `chair`: the name in bold and `title`; the line is left out when there is no chair |
| "#NetZero #Decarbonization #Scope3" | one hashtag per **topic**: a council's first segment is its category (the chip it is filed under), the rest are its topics, spaces and punctuation dropped ("Scope 3" → #Scope3). A council with one segment tags itself with it |
| "3 Working Groups" / "2 Live Groups" | **"N Upcoming Events"** from `upcomingEventCount` (hidden at zero), in the same place and type. Nothing in the API is a working group: councils have members, resources, announcements and events, and no sub-groups |
| "642 Members" | the exact `memberCount`; the database has 187 accounts, so the seeded councils read 99–187 |
| "Next: Apr 18" | the council's next upcoming event of any kind; hidden when none |
| "Preview Chapter" | the website's preview dialog is in-page; the app opens the council's page |
| city tiles "Bengaluru — Apr 26" | the chapter's `city` and its soonest upcoming event of any kind; "TBA" when it has none |
| "All Categories (39)" + category chips | the directory's total and each council's category, in the order the cards come, so the chips follow the cards; a chip narrows the list to the councils filed under it. The sliders glyph opens the sort choices (Recommended, Most members, Most active, Newest, A to Z) |
| search | client-side over name, focus, description, segments and chair, like the website's board (every council is read first, so it covers them all) |

Places the live screen reads differently from the design because the database says so, not because something is missing:

- The design's first directory card (Sustainability) is not joined while its rail card says the member belongs to it. Live shows what the API says: the council is joined, so its card reads "✓ JOINED · Member" and "Open Member Lounge".
- The design's "Next: Apr 22" (CXO) and "May 02" (Legal) are not the dates of its own roundtable rows (Apr 25, May 03); live shows each council's real next event.
- The portal's own seed holds Bengaluru and Mumbai chapter events in November, sooner than the designed 2027 summits, so those two tiles read "Nov 01" and "Nov 22" (the design: Apr 26, May 10). `events-councils.ts --isolate` hides the portal's generic events and brings the design dates back, at the price of hiding them from the Events screen too.
- The chapter's city comes from the API ("Delhi NCR"; the design writes "Delhi-NCR").
- The directory lists every council (44 in the local database), where the design shows six and then the footer.

## Order, categories and sorting

Rows in the controller, not a list of names: `CouncilsController` (tests in `councils_test.dart`).

- **Recommended** (the default) is the website's "recommended" sort, then what the card itself prints: councils sharing a segment with the member's *other* councils first (a seat does not lift its own council); then the larger communities (the website's size bands: more than ten members, three to ten, fewer); then the soonest next session (a council with none last); then the most members; then the API's order (by name). The design lists its six councils by their next date, and the six are the only large councils with sessions, so they come first in the design's order.
- **Categories**: each council's first segment, in the order the cards come, so the design's chips read "Net-Zero & ESG, CXO & Workplace, Smart Buildings, Legal & Procurement, Construction & MEP, Real Estate" and then the rest. Topics (a council's other segments) are not chips; search still reads them.
- **Most members**, **Most active** (upcoming events × 10 + members, the website's), **Newest**, **A to Z**: ties keep the API's order.
- The joined rail lists an executive seat first, then the soonest session, then by name; a join slots in where it belongs.

## Controls and the tests that prove them

`W` is a widget test (`test/councils_test.dart` unless noted); `L` is a live test (`test/live/councils_live_test.dart`, API up and seeded).

| Control | What it does | Proved by |
|---|---|---|
| Back arrow | `onBack` | W "Back and the bell" |
| Bell | opens `/notifications`; its dot is the unread count | W "Back and the bell"; L "the bell's count is the member's unread notifications" |
| Manage → | opens `/councils` | W "Manage and the roundtables' caption open the website" |
| a joined card | opens the council's page | W "a joined card opens its council…"; `council_card_test.dart` "the joined card" |
| Room Link / Meeting link | open the council's Events tab | W "a joined card opens its council…"; `council_card_test.dart` "an executive seat has Room Link, a member Meeting link, and each is its own tap" |
| "N unread" pill | opens the council's Updates tab; N is the last 30 days' announcements | W the same; W "maps the directory…"; L "the member's rail is their seats…" |
| roundtable row | opens the event's page | W "a roundtable row opens its event and its calendar glyph the calendar entry"; L "the links open pages the API knows…" |
| calendar glyph | opens a calendar entry with the event's own title, times and venue | W the same; L "the links open pages the API knows, and the calendar entry is the event's own" |
| "All events" / "Live Chatham-House" | opens `/events` | W "Manage and the roundtables' caption open the website" |
| search | narrows the cards as typed; "No councils match" + Clear filters; the x clears | W "the search narrows the cards as it is typed…"; W "the search reads names, copy, topics and the chair"; L "the search, the category chips and the sort choices work over the live directory" |
| category chips | narrow to a category; again, or All Categories, widens | W "a category chip narrows the cards…"; W "a category narrows to the councils filed under it…"; L the same live test |
| filters glyph + sort sheet | five choices, the current one ticked, a choice reorders | W "the filters glyph opens the sort choices and a choice reorders the cards"; W "the other sorts are the website's…"; L the same live test |
| Join Council | takes the seat at once (`POST /councils/:id/join`), keeps what the API answers, rolls back with the API's sentence on a refusal | W "Join Council takes a seat at once, and a refusal puts it back…"; W "a join shows at once, is busy until the API answers…"; L "a council joined is a seat the API keeps, and leaving gives it back" (Pooja); L "the controller takes a seat at once, keeps it across a refresh, and gives it up"; L "a refusal from the API rolls the seat back and says why" (signed out, 401; and an unknown council, 404) |
| Open Member Lounge | opens the council's Updates tab | W "Open Member Lounge opens the council's updates…" |
| long press on Open Member Lounge | offers "Leave <council>"; leaving is `DELETE /councils/:id/join`, rolled back on a refusal | W the same; W "a refused leave puts the seat back"; L "the controller takes a seat at once…" |
| Preview Chapter | opens the council's page | W "Preview Chapter opens the council's page" |
| city tile / View Regional Chapters Directory | open the chapter / `/chapters` | W "a city tile opens its chapter and the directory button the chapters page"; L "the In-Person Summits tiles are the four chapters…" |
| pull to refresh | reads everything again, the bell too | W "pulling down reads the councils again"; W "a refresh reads the councils again, and the bell with them"; L "pulling down reads what the server holds now" |
| a failed read | "Couldn't load councils" + Try again | W "a failed read offers Try again, which reads again" |

Content from the API, drawn as the design words it: W "the screen draws what the API gave, worded as the design words it"; L "the screen, drawn from the live API" (the top of the screen; narrowed to one category, the footer), L "the directory is the API's, with the designed councils first, in the design's order", L "the stat tiles are read from the data", L "the three roundtable rows are the design's…".

## Seed

`tool/seed/events-councils.ts` (see `tool/seed/README.md`) gives the local database the design's councils so the live screen reads like the PNG:

- the six councils, their chairs (name and "Title @ Organisation"), counts scaled to the people there are, one upcoming event each; a council's **first segment is its category** and the rest its hashtags; no shared "lift" tag any more;
- CXO, Legal and Real Estate created in the running quarter (the "+3 Q4" pill), Sustainability on 1 Mar 2023, Smart Buildings and Construction in January and February 2024 (so they wear "Est. 2023" and "CHARTERED 2024");
- three announcements on the CXO council from the last month ("3 unread"), re-based on every run;
- the three roundtables on the design's dates (18 Apr, 25 Apr, 3 May 2027), kind ROUNDTABLE (ESG Mandates held "Online", GCC Workplace Leadership at "Bengaluru (Hybrid)", Vendor RFP invite-only), plus the other three councils' "Next:" dates; only 2026 events move when the seed is re-run on a later day, these 2027 dates stay;
- covers uploaded as `design-councils-photo_*.png`: the design's photos with the app's own cover darkening taken back out, so the screen shows the design's tone (`tool/design/cut_council_covers.py` cuts them, keep its darkening constants in step with `councils_styles.dart`).

## Demo content

`DemoCouncilsRepository` holds the design's six councils, three memberships (the two cards the design shows plus one more for its "3 Active"), three roundtables, the four city chapters and the four stat tiles, word for word. Dates are fixed IST moments (18 Apr 15:30 and so on) so the tiles read as the design whatever today is. The directory's first title carries the design's stray space ("Net- Zero"); the rail card spells it "Net-Zero" so it breaks as the design's does. The card copy carries the design's own line breaks and "..." so the two-line clamp lands where the export has it. Each cover wears the pill the design gives it: "OFFICIAL COUNCIL · Est. 2023" (Sustainability), "CHARTERED 2024" (Smart Buildings, Construction), a bare "OFFICIAL COUNCIL" (Legal, Real Estate). Covers are cut from the export by `tool/design/cut_council_covers.py` (254 × 54–55 px at the design's 0.705 px/dp), with the baked-in glyph tile, pills and rounded corners painted out by inpainting, since the screen draws its own.

## Measurements (dp)

Title bar 0–56; stat tiles 176 × 56 at x 16 and 199, rows at 62 and 122; rule at 186; "Your Joined Councils" at 197 (18 tall); the rail at 224, cards 210 × 160, 8 apart; "Upcoming Roundtables" at 418; rule at 447.5; roundtable rows 81 tall with a 1 dp rule between (date tile 44 × 44 at x 11, text at x 69, calendar glyph ending at x 376); search 360 × 32 at 704.5; chips 31 tall at 747.5; council cards 362 wide from 790.5, cover 80, body padding 14, footer 32, 267 tall with a one-line chair and one tag row, 4 apart; cover tile 30 × 30 at (13, 11) with a 26 dp symbol (ink about 20 dp across, as the design's); the In-Person Summits footer 259.5 tall, 12 below the last card, with 173 × 39 tiles and a 40 dp white button.

## How it was checked

`compare.py` pairs bands by index, and the export's blurred frame border and shadow add bands at the top and between cards, so every row after the title bar reads as misaligned. The check that means something pairs the sharp ink rows (pixels darker than 200) of the design's interior (`flat.png`: the 275 px interior of the export, resampled to 780 px) with the render by nearest start row.

- The demo golden (`build/screens/councils.png`): 77 bands each; **72 start within 2 dp, the worst is 3.5 dp**, mean 0.8 dp. The five past 2 dp are not misplaced content: the third roundtable row's pill and time line starts 3 dp earlier in the design than in the render's threshold (its monospaced time digits and darker pill ink, the title below sits 1.5 dp apart); the meta rows of the fourth and fifth cards start 2.5–3.5 dp earlier in the design only because its zap glyph is taller than the text (the baselines line up), and the fifth card's Join button starts 3 dp earlier because the design draws it 23.5 dp tall against 21.5 here (the bottoms are 1 dp apart).
- The screen drawn from the live API (`build/screens/councils_live.png`, the first 2450 dp, before the design's footer): 76 bands each, **70 within 2 dp**, mean 0.9 dp; the one extra miss (+6 dp) is the first card's footer, a solid blue Join button in the design against the outlined "Open Member Lounge" a joined member gets.
- Cover tiles: the design's six glyphs against ours, drawn at the same scale, are the same shapes and weights (`IndustryGlyph`).

## Deviations that remain

- The design wraps a card's hashtags inside about 243 dp (its fifth and sixth cards run to two rows while the card's text runs to 334), so the tag row is constrained to that width; the copy and chair lines of the demo carry the design's own breaks.
- The design's search hint and chip words are set in a slightly narrower face; widths were matched, so glyphs are about a pixel shorter.
- `IcrSearchField` was not reused: this design's box is 32 dp with a 10.5 dp hint and a 15 dp glyph, so the feature carries its own `CouncilSearchField` (same shape, those sizes).
- The time "15:30 – 17:00 IST" is drawn in IBM Plex Sans; the design uses a monospaced cut the app does not bundle.
- The covers' photos are the design's (254 px wide, blurred by the export's own resolution) and the pill and tile areas are inpainted, so the area under them is smooth where the original photo has detail; the screen's own pill and tile sit over it. A council that is joined shows narrower pills than the design's baked "OFFICIAL COUNCIL · Est. 2023", so a little of the smooth area shows to their left (the Sustainability card for the member the emulator is signed in as).
- A joined card's long press to leave is not drawn as a control, as in the design; it is the way out of a seat and is tested.
