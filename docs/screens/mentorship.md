# Mentorship: the landing and Find Mentors

Designs: `docs/designs/mentorship-landing.jpg` (281 x 1999, so each pixel is 1.45 dp; layout and content only, and blurry) and `docs/designs/find-mentors.jpg` (810 x 2000, measured to the pixel).
Code: `lib/features/mentorship/`. Tests: `test/mentorship_test.dart` (widget and API-table tests), `test/golden/mentorship_golden_test.dart`, `test/live/mentorship_live_test.dart` (the local API, signed in as Bharat).
Seed: `tool/seed/mentorship.ts` (the 48 listed mentors, the cohort, the storefront; nothing in it changed for this pass but the closing log lines).

## The screens

| Screen | Where | What it is |
| --- | --- | --- |
| `MentorshipScreen` | the Mentorship tab | The landing: the Home header, "Explore by Companies", the two mentor grids, "Explore by Expertise", the "Become an ICR Mentor" band, the next cohort, "Featured Advisory Sessions". |
| `FindMentorsScreen` | pushed over the tab, bottom bar kept | The directory: title bar with the search box, "Find Mentors" with its match count, category chips, filter chips, the 2-column mentor cards, "Showing 8 of 48", "Load more mentors". |

## Wiring

```dart
ChangeNotifierProvider<MentorshipController>(
  create: (c) => MentorshipController(
    AppConfig.demo ? DemoMentorshipRepository() : ApiMentorshipRepository(api: c.read<ApiClient>()),
  ),
  child: ...AppShell(
    mentorship: Builder(
      builder: (ctx) => MentorshipScreen(
        onBack: () => AppShell.selectHome(ctx),
        onOpenMentor: (context, mentorId) => openMentorProfile(context, mentorId),
        viewer: _viewer,
        onAccount: () => AppShell.openDrawer(ctx),
      ),
    ),
  ),
)
```

Unchanged from before, so `app.dart` needs nothing. This pass only **added optional parameters**:

* `MentorshipScreen({required onBack, required onOpenMentor, required viewer, required onAccount, OpenSite openSite = openSitePage})`. `openSite` is how the screen opens a page of the website ("Apply as Mentor", the cohort's "Know More", the bell); tests pass a recorder, the app takes the default.
* `FindMentorsScreen({required onBack, required onOpenMentor, category, search, company, companyOnAccount, controller, openSite})`.
* `openFindMentors(context, {category, search, company, companyOnAccount, required onOpenMentor, openSite})` pushes it. A pushed route sits above the shell's providers, so the helper re-provides the `MentorshipController`.
* `FindMentorsController(repository, {category, search, company, companyOnAccount, minExperience})` can start in any filter state; `clearCompany()` is new.
* `Mentor.userId` is new (what a follow is keyed on). `MentorFilters` gained `company` and `companyOnAccount`.
* `MentorshipScreen` reads `onBack` for symmetry only: the tab wears the Home header, which has no arrow.
* `onOpenMentor` is `openMentorProfile`; this feature imports nothing from `mentor_profile`.

## Endpoints used

| Call | For |
| --- | --- |
| `GET /mentorship/mentors` (`page`, `limit` 8 / 24 / 48, `sortBy`, `sortDir`, `competencies`, `minExperience`, `availableOnly`, `search`, `companies`) | The directory, the landing's two grids, Find Mentors, its `meta.total` ("48 matches") and `meta.hasNext` (whether "Load more" shows). |
| `GET /mentorship/mentors/facets` | The category chips (`competencies`: label and mentor count), the topics, and the count behind "50+ Domains". |
| `GET /mentorship/public-stats` | `listedMentors`, for the banner's "Join 60+ senior leaders". |
| `GET /mentorship/programmes?status=OPEN&limit=1` | The "UPCOMING COHORT" card: name, `enrolmentCount`, organiser, `coverUrl`, slug. |
| `GET /mentor-services/mentors/:mentorProfileId` | A mentor's public storefront, for "Featured Advisory Sessions". |
| `GET /mentorship/mentors/saved/ids` | Which mentors the member saved (part of "your network"). |
| `GET /members/me/following` | The members they follow (part of "your network"). A mentor is a member, matched on `user.id`. |
| `GET /mentorship/mentees/me` | The member's own `focusAreas`, which select their topics. Answers 200 with an empty body until a mentee profile exists; the app reads that as "none". |
| `GET /auth/me`, `GET /companies/:id` | The company the member acts for (part of "your network"). |
| `POST` / `DELETE /mentorship/mentors/:id/save` | Save and unsave (controllers only, see below). |
| `GET /notifications/unread-count` | The bell's dot. |

Each of the member-specific reads (following, mentee profile, company) is an aid: one that fails leaves that signal out and never the landing. The two mentor grids are not an aid: if either read fails the landing says "Couldn't load mentors" and "Try again" asks again, rather than drawing empty shelves. The landing costs about a dozen requests a load (the API allows 120 a minute per address).

Website pages opened where the app has no screen: `/notifications`, `/become-a-mentor`, `/mentorship/programmes` and `/mentorship/programmes/<slug>`.

## What the API cannot give, and what the screen shows

| Design element | What it shows instead |
| --- | --- |
| "Top Mentors in Your Network" (both grids) | ICR has no mentor network or connections. Both grids carry the design's title. The first is "your network": the mentors the member **saved**, **follows**, or who **work at the member's own company**, ahead of the rest, each group best rated first, then the best rated; with no ties it is simply the best rated (the design's eight, in its order, for Bharat). Councils are not used: the directory rows say nothing about a mentor's councils. The second grid is the most sessions delivered, without repeating a face from the first. Both are scoped to the lit domain. |
| "8+ Domains" | The count of domains a listed mentor has, **rounded down to the nearest 1, 5, 10, 50 or 500 with a plus** (`mentorship_format.dart`): 8 → "8+", 14 → "10+", 58 → "50+ Domains", 64 → "60+". Never rounded up, so it is never a claim the data does not carry. The pill is 83.5 x 20 dp at the design's place (the design's blurred edge reads 85 x 22). |
| Category chips: "Operations & FM" lit, "Sustainability & ESG", "Smart B..." | The most-listed domains from `facets`, eight on the landing and all of them on Find Mentors. The landing opens with the most-listed domain lit, as the design does; tapping the lit chip returns to it. Find Mentors opens on the landing's lit domain and brings its chip into view when it is out of the visible part of the row. Glyphs are picked by keyword (`domainGlyph`), since the API has no icons. |
| Company tiles: Microsoft, Amazon, JLL (red), CBRE (blue), CBRE, JLL, Google, Infosys | No endpoint. They are derived from the 48 top-rated mentors in the lit domain, as the website's landing does: the company on the mentor's account, else the organisation on their current role, most mentors first, eight at most. The design's second row repeats CBRE and JLL; real companies cannot repeat, so live it reads Google, Infosys, Cisco, SpaceX. A tile draws the company logo when the account has one (none do in the seed), else the name as a wordmark **coloured by a small palette keyed by name** (`MentorshipBrand`): JLL a deep red `#9B1D24`, CBRE a steel blue `#2A5C8C`, every other name in the design's ink `#111C2D`. Sampled from the design, which is darker than a brand red or green would be (its JLL strokes bottom out near `#742024`, its CBRE near `#21496C`; the values are set between that and what the eye reads). The tile has **no outline**: the design's edge measures 253 of 255, i.e. none. |
| Company tile, tapped | Find Mentors opens with a removable **"Company: SpaceX"** chip at the front of the filter row, the search box empty, in the landing's lit domain (the tiles are counted within it). The directory's `companies` filter matches only the company on a mentor's ICR account, so a company known only from a role is found by its words in a mentor's headline (`search`), behind its chip; typing other words replaces such a chip, a company on accounts stays beside the words. |
| Mentor card: seal | Drawn when `status == APPROVED` (every directory row is). |
| Mentor card: "VP Facility Ops @ Infosys" | `career.currentRole` as "Title @ Organisation", else the mentor's own `headline`. |
| Mentor card: cover photo | `coverImage`: an upload path is drawn as a photo; one of the website's eight ready-made cover ids is drawn as its gradient band; none gives the brand-blue band. |
| Mentor card: expertise chips | The first three `competencies`. |
| "Explore by Expertise" and "Learn from top topics" | The topics are the domains ranked ninth onward in `facets` (the API has no topic list); the block hides when there are none. **The design's red and blue chips** are worked out: **red = selected**, the topics among them that are in the member's own `focusAreas` (`GET /mentorship/mentees/me`), else the two most-listed; **blue = suggested**, the two most-listed others. Every other chip is neutral. A topic opens Find Mentors on that domain. The design's one grey-filled chip is a pressed state, so it is demo only. |
| Banner "Join 3,000+ senior leaders guiding emerging facility managers and corporate real estate professionals." | The design's sentence with the number the API gives, rounded down with a plus: "Join 60+ senior leaders ..." (`public-stats.listedMentors`, 64). The woman's photo is the design's own, **bundled** (`mentorBannerPhoto`, cut from the design at 83 x 108 px, so soft), drawn live as well as in the demo, since the API has no picture for the band. |
| "UPCOMING COHORT": "32 Leaders Registered" | The first open programme: its name and "32 Registered" from `enrolmentCount` (that counts mentors and mentees, so "Leaders" is not claimed). The API does not say who registered, so the three RK / AN / SJ circles become the organiser's photo (or initials) and one circle for everyone else ("+31"). Behind the card the programme's own `coverUrl`, blurred and washed out like the design's city photo (flat grey when there is none). Hidden when no programme is open. |
| "Featured Advisory Sessions" | There is no list of services across mentors. The app reads the public storefronts of the first six mentors of the first grid and shows the first three active offerings, the first in the featured style. The pill is built from the offering: kind, minutes or turnaround, "Free" or the price ("1:1 Session • 45 Mins • ₹1,499"). The design's third card is an "Async Query"; the API retired that type, so the seed's third offering is a free resource and reads "Resource • Free", with the button "Get Resource (Free)". The cards' buttons open the mentor's profile, where the offering sheet is; hidden when none is live. |
| "48 matches" | `meta.total`. (The API counts the pre-filter set when `availableOnly` or a price ceiling is on.) |
| "Filters (2)" | Counts the category chip, the minimum-experience filter, the company chip and the free-slot switch that are on. |
| "Sort: Top rated" | `sortBy`: Top rated, Most mentees helped, Most sessions, Most experienced, Newest. |
| "Exp: 10+ Yrs" | `minExperience`, chosen as 5+, 10+ or 15+ in the Filters sheet; the chip's cross clears it. |
| "Showing 8 of 48 mentors in this category" and the bar | Loaded count, `meta.total`, and the fraction between them; "in this category" only while a category chip is on. "Load more mentors" fetches the next page of eight (real page 2, 3 ... of the API). |
| Save / bookmark a mentor | The controllers (`toggleSave`) save optimistically and roll back with the API's message, but the designs draw no heart, so no screen calls them. (The save is live: it feeds "your network".) |

## Every control, and what proves it

W = `test/mentorship_test.dart` (what the API cannot change), L = `test/live/mentorship_live_test.dart` (the local API, Bharat).

| Control | What it does | Proved by |
| --- | --- | --- |
| Landing: header search | Submitting opens Find Mentors with those words in the box (an empty search opens nothing); not narrowed by the lit domain | W "the header search opens Find Mentors with the words", "an empty search opens nothing", "the header search is not narrowed..."; L "the search box finds a mentor by name" |
| Landing: category chips (both rows) | Re-scope both grids, the tiles and the topics to that domain; the lit chip again returns to the default | W "a category chip re-scopes the shelves..."; L "a category chip re-scopes both grids, live" |
| Landing: company tile | Opens Find Mentors with the "Company: X" chip in the lit domain, search box empty | W "a company tile opens Find Mentors on its chip...", "...after another domain was lit..."; L "a company tile narrows to that employer behind its chip" |
| Landing: topic chip | Opens Find Mentors on that domain | W "a topic chip opens Find Mentors on that domain"; L "a topic chip from the landing is a domain the directory filters on" |
| Landing: both "View More" links and the Domains pill | Open Find Mentors on the lit domain, bottom bar kept with Mentorship lit | W "View More opens...", "the second View More...", "the Domains pill opens Find Mentors" |
| Landing: mentor card | Opens that mentor's profile (`onOpenMentor`) | W "a mentor card opens that mentor's profile"; L "every card opens a mentor that exists" |
| Landing: "Apply as Mentor" | Opens `/become-a-mentor` on the website | W "Apply as Mentor opens the website's page" |
| Landing: cohort "Know More" | Opens the programme's page on the website | W "the cohort card's button opens its programme"; L (the programme and its slug exist) |
| Landing: advisory session buttons | Open the mentor, whose profile holds the offering | W "each advisory session's button opens its mentor"; L (the storefront is live and lists the offering) |
| Landing: bell | Opens `/notifications` | W "the bell opens the notifications on the website"; L "the bell's number is the API's unread count" |
| Landing: pull to refresh | Reads the landing again | W "pulling down reads the landing again"; L "pulling down reads the landing again and gets the same answer" |
| Landing: a failed load | Says why; "Try again" asks again | W "a refused load says why, and Try again asks again", "a mentor grid that cannot be read fails the landing" |
| "Your network" (saved, followed) | A saved or followed mentor leads the first grid; taking it back restores it | L "a saved mentor leads the first grid...", "a followed mentor leads the first grid too...", "the optimistic save through the controller..."; W "your network: saved, followed and same-company mentors lead...", "with no ties..." |
| Find Mentors: Back | Leaves the screen | W "Back leaves the screen" |
| Find Mentors: search box (and its cross) | Searches by the words; the cross brings everyone back | W "the search box searches by the words typed", "the clear cross..."; L "the search box finds a mentor by name, and clearing it brings every mentor back" |
| Find Mentors: category chips | Narrow to a domain; the lit chip again clears it; a chip far down the row is scrolled into view | W "a category chip narrows...", "opening on a domain far down the chips brings its chip into view"; L "a category chip narrows to that domain" |
| Find Mentors: Filters sheet, experience | 5+ / 10+ / 15+ years, shown as "Exp: n+ Yrs" with a cross | W "the Filters sheet sets the minimum experience...", "the cross on the Exp chip takes the filter off"; L "the minimum-experience filter keeps only mentors with that many years" |
| Find Mentors: Filters sheet, free slot | Only mentors with a free slot, shown as "Free slot" with a cross | W "the free-slot switch in the sheet..."; L "the free-slot switch asks for mentors with an open slot" |
| Find Mentors: "Clear all" | Takes off every filter "Filters (n)" counts (words and sort stay) | W "Clear all in the sheet takes off every filter the chip counts"; L "the Filters sheet's Clear all state is the whole directory" |
| Find Mentors: Sort | Orders by rating, mentees, sessions, experience or newest | W "the sort menu orders the directory by what is chosen"; L "every sort reaches the API and the cards come back in that order" |
| Find Mentors: "Company: X" chip | Stays out of the search box; its cross takes it off | W "the company chip stays out of the search box...", "a company chip leads the filter row..."; L "a company tile narrows to that employer..." (and the `companies` filter path: "a company on mentors' accounts goes to the directory's own filter") |
| Find Mentors: "Load more mentors" | Appends the next real page and moves the bar | W "Load more mentors appends the next page..."; L "Load more mentors reads the real next page, and the pages add up to the total", "a filter changed after Load more starts again from page one" |
| Find Mentors: card | Opens that mentor's profile | W "a card opens that mentor's profile" |
| Find Mentors: bell | Opens `/notifications` | W "the bell opens the notifications on the website" |
| Find Mentors: pull to refresh | Reads the directory again, filters kept | W "pulling down reads the directory again"; L "pulling down reads the directory again and keeps the filters" |
| The design's state | Operations & FM + 10+ years is "Filters (2)", "Exp: 10+ Yrs", "48 matches", "Showing 8 of 48 mentors in this category" | W "the design's state..."; L "the design's state: ... is 48 matches" |
| Counts promised with a plus | 8 / 14 / 58 / 64 / 3,120 round down; never up | W "counts promised with a plus" |
| Company wordmark colours | JLL red, CBRE blue, the rest ink | W "the company tiles' colours", "the company tiles are coloured by brand" |
| Topic tints | Red selected (own focus areas, else top two), blue suggested | W "topic tints...", "the member's mentee focus areas select their topics..."; L (the seeded topics read red, red, blue, blue) |

The live file signs in once and retries a request the API turns away with 429, because a landing load alone is a dozen requests and other people's tests share the address. What it writes (a save, a follow) it takes back in a `finally`; its last test checks Bharat's saves and follows are as it found them.

## Demo content

`DemoMentorshipRepository` (behind `AppConfig.demo`) reproduces both designs exactly: the eight cards with their names, roles and chips (Rajesh Sharma twice, Lisa Cheng, David Kim, Sophia Patel, Michael Johnson, Emma Thompson, James Rodriguez), the eight company tiles (coloured by the palette, as live), the nine topics with the design's own tints, the banner copy, the cohort ("FM Leadership & ESG Masterclass", "32 Leaders Registered"), the three advisory sessions, "8+ Domains" and "48 matches". A company filter matches the role's company. Cover and avatar photos are cut from the Find Mentors export at its 2x scale into `assets/images/demo/mentorship/` (`cover_<id>.jpg`, `avatar_<id>.jpg`; the banner photo comes from the landing and is low resolution). More pages repeat the eight cards under new ids up to 48.

## Verification

Goldens (`flutter test --tags golden test/golden/mentorship_golden_test.dart`, add `--update-goldens` to refresh) write to `build/screens/`:

* `mentorship_landing.png` (780 x 5658, the 390 x 2829 frame above the shell's bar) and `find_mentors.png` (780 x 1874): the designs' content, to compare;
* `mentorship_landing_live.png`: the landing as the live API fills it (the pill "50+ Domains", the eight real tiles, red and blue topics, the banner sentence, the cohort card with its cover and "+31"), a render to look at;
* `find_mentors_company.png`: Find Mentors on a company tile (chip first in the row, "Filters (3)").

Compare with:

```
python tool/design/measure.py docs/designs/find-mentors.jpg --flatten --frame 16,14,794,1994 --out fm.png
python tool/design/devcompare.py build/screens/find_mentors.png fm.png side.png
```

The landing design is 269 px wide inside its frame (crop 6,5,275,1994 and upscale to 780 wide) before it lines up with `devcompare.py`.

### Measured deviations

Method: ink bands (rows holding dark text, avatars, headings) are found in the design and in the render, paired in order, and compared by their top edge and by their ink-weighted centre (the centre is steadier against the landing's blur). Differences are in dp, render minus design.

**Landing** (blurry design): 86 bands paired. By top edge mean -0.06 dp, 84 within 2 dp and all 86 within 3; by centre mean +0.18, 83 within 2 and all 86 within 3. This pass fixed: the first grid's heading gap (-1.3 dp, given back below it), the row gap (+0.4 dp, given back below each grid), the "Learn from top leaders" line (+0.9 dp), the session cards' inner gaps (title to blurb -2.0, blurb to button +3.3, pill to title +1.0, the third card's top rule -4.4) and the gap under the "Featured Advisory Sessions" heading (-1.9). What is left over 2 dp: the second-row names of both grids (+2.1 to +2.6, a design that spaces its two-line cards 1.5 dp wider than its one-line ones). The pill, tiles, topic grid, banner, cohort card and sessions are within 2 dp.

**Find Mentors** (precise design): 32 bands, mean +0.08 dp, all within 2 dp (31 by centre, the last at +2.2). The search box and the bell sit where the design has them; "Showing 8 of 48 mentors in this category" and the bar are within 1 dp; "Load more mentors" within 2.5 dp.

Things drawn differently: the design's grey-filled first topic chip (a pressed state); the banner's photo is the soft low-resolution cut at the right where the design has a full-width tinted photo; the second tile row's CBRE and JLL (real companies cannot repeat); company wordmarks are Work Sans where the design's are logo faces; category glyphs are Lucide, the design's are Material; mentor-card corners are 6 dp.

## API behaviour worth knowing (the portal was not touched)

* **`sortBy=yearsExperience&sortDir=desc` lists a mentor with no years first** (Postgres sorts NULL first on a descending sort), so "Most experienced" can open on a card with no experience. The fix is `nulls: 'last'` in the portal's `orderBy`; the app cannot patch it without breaking the pages.
* **`companies` is an exact match on the company on a mentor's ICR account** (`User.company.name`), and no seeded mentor has one, so a company tile live can only filter by words (`search`, which matches a headline, a topic, a first or a last name). That works for the seed because its headlines read "Title @ Company"; a mentor whose headline does not name the employer would not be found by the tile.
* **`GET /mentorship/mentees/me` answers 200 with no body** for a member with no mentee profile.
* **120 requests a minute per address** (`ThrottlerModule`): the landing is about a dozen requests a load, so a burst of refreshes next to a test run can be answered 429, which now fails the landing visibly ("Couldn't load mentors") instead of emptying it.

## Left out

* The shell's bottom bar (the shell draws it).
* A "save mentor" control (no design for it).
* Any mentor ratings on the card, and the website's competency taxonomy beyond what `facets` returns.
* A direct "Book" deep link from a session card: `mentor_profile`'s `showOfferingSheet` takes that feature's own model, so a card opens the mentor and the offering is one tap further. Wiring one is a change to `app.dart`'s `onOpenMentor` (the lead's file).

## Shared kit

Reused unchanged: `HomeHeader`, `TitleBar`, `IcrSearchField`, `IcrChip`, `ChipRow`, `Hairline`. Own copies or additions inside this feature: `CategoryChipRow` (a scrolling row of its own now, so it can bring the lit chip into view), `MentorCard`, `LandingHeading`, the company tiles, topic grid, banner, cohort card and session cards (`widgets/`), `MentorshipNotice` (the Jobs screen's `_Notice` is private), `mentorship_format.dart` (the "+" rounding) and `MentorshipBrand` (the wordmark palette). `TitleBar` is given a custom `leading` and a padded `middle` so the search box starts and ends where the design's does.
