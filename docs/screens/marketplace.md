# Marketplace

Designs: `docs/designs/hires/marketplace.png` (phone, two columns) and `marketplace-3col.png` (the tablet comp, three). Code: `lib/features/marketplace/`. Goldens: `build/screens/marketplace.png` and `marketplace_3col.png` (demo content, at the designs' frames). Tests: `test/marketplace_test.dart` (what the API sends and what the controller does with it), `test/marketplace_screen_test.dart` (every control tapped), `test/marketplace_suggest_test.dart` (the search box's suggestions), `test/marketplace_quote_test.dart` (the quote form), `test/marketplace_catalog_test.dart` (service and product pages, the category browser and the boards), `test/marketplace_entry_test.dart` (a profile opened from another screen), `test/marketplace_sheet_test.dart` (the profile sheet), `test/live/marketplace_live_test.dart` (the controls against the local API). The supplier profile sheet has its own notes: `docs/screens/supplier_profile.md`.

The live app reads the portal's API; the local database holds the designs' suppliers through `tool/seed/marketplace.ts` (see "Seed"). Everything the design draws that the API has no field for is filled with the nearest true thing, in the design's slot, and listed under "What the design shows that the API does not give".

## Status (slice by slice)

| Slice | What | State |
|---|---|---|
| 1 | Audit of the models and the repository against the real API; the grid screen with search, sort, load more | done, proved (unit + widget + live) |
| 2 | Filters sheet, rating and verified chips, saves (the saved list), the chip numbers, search extras | done, proved |
| 3 | Supplier profile sheet, its three tabs | done, proved, measured: `supplier_profile.md` |
| 4 | Request a quote (`POST /rfq`), service and product pages, the category browser and the product and service boards, search suggestions, a profile opened from another screen | done, proved (widget + live): below |
| 5 | Goldens against the PNGs, line widths | phone and the three sheet tabs measured (below); the tablet comp is approximate |

## The tab (`MarketplaceScreen`)

- **Title bar:** Back, "Marketplace", the bell (`GET /notifications/unread-count` for its dot).
- **Search** ("Search suppliers, services, RFQs..."): `GET /vendors?search=` (it matches the company name, the headline, a service area equal to the words, and a category key equal to them upper-cased). While a search is on, the services and the requirements the words also match (`GET /services?search=`, `GET /rfq?search=`, `GET /rfq/mine?search=`, three of each at most) are listed above the suppliers.
- **Suggestions** (the box has focus; `widgets/search_suggestions.dart`): with nothing typed, the searches made this session (newest first, six at most; they are kept in the app's memory only) and three worth trying ("Housekeeping in Bangalore", "Fire safety companies", "Facility management Mumbai"). From two characters, after a 350 ms pause: *Search for "..."*, up to five **suppliers** whose name matches (`GET /vendors?search=`, within the trust level the list is on; a tap opens the profile) and up to four **categories** whose name matches (from the category tree, top level and sub-levels, the parent named; a tap filters the Marketplace to it). The suggestions take the place of the list while the box has focus; submitting, tapping a row or the cross puts the list back. An answer for words no longer in the box is dropped; a failed read says nothing and keeps the last suggestions.
- **Quick chips:** *Post RFQ*, *My RFQ's (n)* (the member's live and draft requirements, `GET /rfq/mine/summary`), *Alerts (n new)* (unread notifications about requirements). All three are constructor callbacks (below); with none wired each opens its website page.
- **Filter chips:**
  - *Filters (n)* counts what the sheet sets (categories, city, sizes, GST, MSME, a trust level above Verified, saved only); the rating and "Verified only" have chips of their own. The sheet holds: trust level (Any, Verified, Certified & up, Preferred & up, Elite & up), the category tree (top level and sub-level, searchable, with the number of verified suppliers under each), city (`GET /vendors/cities`), company size, GST registered, MSME / Udyam, only my saved suppliers. "Show suppliers" applies; "Clear all" empties the sheet's choices and keeps the search, the order, the rating and "Verified only".
  - *Sort Top rated* opens Recommended, Top rated, Most reviewed, Most projects, Most experienced, Newest (`sortBy` rating, ratingCount, projectsCompleted, yearsExperience, createdAt; the API always puts paid placement and higher trust first, then this).
  - *By ratings* sets `minRating` (4.5, 4, 3.5, 3 and up, or any); the chip then reads what it is set to.
  - *Verified only* is **on to begin with** (the mart opens on verified suppliers: `minVerificationLevel=VERIFIED`) and drawn as the design draws it; a tap widens to every supplier and the green seal greys.
- **Cards:** logo and name, a rule, the rating and the review count, the title (the supplier's `headline`, else its main category) and two lines (the company's description, first paragraph). Every card is the same height; a tap opens the supplier.
- **Foot:** "Showing 10 of 180+ verified enterprise suppliers" (`meta.total` rounded down to tens from 100), a bar that fills as more load (never less than 14%, so it reads as a bar), "Load more suppliers" (`page` + 1 of `GET /vendors`; the button goes when `meta.hasNext` is false).
- **Columns:** two below 600 dp wide, three from 600 (`LayoutBuilder`, the same widget tree). A cell narrower than the phone design's 179.75 dp draws the card at the same shape, smaller, so a three-column grid on a phone's width still reads.
- **Browse all:** the filters sheet's *Browse all* opens the category browser (below).
- **States:** loading (placeholder cards), error with "Try again", empty ("No suppliers match" with "Clear filters", "No suppliers listed yet", "No saved suppliers yet" with "Show all suppliers"), pull to refresh (the list, the bookmarks, the chip numbers, the bell).

## Slice 4: the pages the tab leads to

- **Request a quote** (`widgets/request_quote_sheet.dart`, `quote_controller.dart`, `quote_models.dart`): the website's profile card and quote dialog as a sheet. It creates the same **private requirement** they do (`POST /rfq`: `kind ENQUIRY`, `status PUBLISHED`, `visibility TARGETED`, `vendorIds [the supplier]`). Fields: the service asked about (a picker over the supplier's services, preselected from a service row's *Get Quote*), what is needed (up to 300 characters), the timeline (Immediate, Within 30 days, AMC contract), notes (up to 3,000), and for a product the **quantity** (a whole number, 1 to 1,000,000) with its unit. The title is "<service or product> — quote request" (English: it is stored and the supplier reads it); the scope, the timeline and the notes go in the description. A mobile number is asked **only when the profile has none** (`GET /auth/me`; the API saves it to the profile), and a refusal for a number brings the field up. A member who may not post requirements (no active company: `403 "Requirements are posted for a company"`) is told what to do and **keeps what they typed**; any other refusal is shown as the API worded it; the button cannot be tapped twice while it sends. The form asks `MarketplaceRepository.myCompanyId()` (`/auth/me`) once, to word two refusals for a person who has a company (27 Oct, `docs/ROLE_TEST_company.md`): a company asking **its own listing** ("No valid companies to invite.") is told "This is your own company's listing: a company cannot ask itself for a quote."; a member whose role does not post (office admin, recruiter, hiring manager: "Insufficient role permissions") is told to ask the company's admin, with no "Create a company" button (that stays for a person with no company). After it is sent: "Request sent", **View my request** (`onOpenRfq(id)`, else `/rfq/<id>` on the website) and Done. `onRequestQuote` replaces the form with the lead's own composer.
- **A service's page and a product's page** (`catalog_pages.dart`, `catalog_item_controller.dart`): opened from a service or product row (profile tab, search extras, the boards). Photo (a tile with the first letter when there is none), name, price or "Price on request", how fast, the facts, the supplier's terms (warranty, returns, delivery, bulk pricing: only those it states), the description, **Sold by** (opens the supplier's profile over the page) and the bar: *Request a quote* and share. The row that was tapped seeds the page (its name shows at once); the page reads `GET /services/:id` or `GET /products/:id`, and the listing it names. A failed read says why and *Try again* reads it. Share hands the item and its page on the website to the system share sheet. `onOpenService(id)` / `onOpenProduct(id)` replace the pages.
- **The category browser** (`categories_screen.dart`): `showCategories(context)` (the filters sheet's *Browse all*): quick cards to all products and all services, then each top category with its blurb, its number of verified suppliers and its sub-categories, and a search over their names (`GET /categories/tree?depth=3`). A category's page: *Show N suppliers* goes back to the Marketplace **filtered to the category** (`showSuppliersOf`), a sub-category shows its own suppliers, and the page lists its **products** and, on the next pill, its **services** (read when asked for). A category with nothing listed says so.
- **The boards** (`CatalogBoardScreen`, `widgets/catalog_board.dart`): *All products* and *All services*: the count, a search, rows (photo, name, price or rate, "by <supplier>" with the seal), *Load more products*; a row opens its page. A search that finds nothing says so; a failed read says why with *Try again*.

## A profile from another screen (the doors)

`showSupplierSheet(context, supplier)` needs the Marketplace's controller above it. Any other screen uses:

```dart
showSupplierSheetById(context, vendorId, {tab, navigation, links, repository});        // a listing id
showSupplierSheetForCompany(context, companyId, {tab, navigation, links, repository}); // a company id
```

(`lib/features/marketplace/supplier_sheet.dart`.) They read the listing (and which suppliers the member bookmarked) and then open the same sheet, with the same save, share, quote and message controls. The repository is the app's (`marketplaceRepositoryOf(context)` in `marketplace_entry.dart`: a `MarketplaceController` or `Provider<MarketplaceRepository>` above, else the `ApiClient`'s, else the demo's in a demo build). A listing that cannot be read shows the API's sentence in a snackbar; a company that does not sell on ICR says "This company has no supplier listing."; nothing opens. Wire them in `lib/app.dart`, for example:

```dart
RfqHooks(onOpenSupplier: (vendorId) => showSupplierSheetById(navigatorContext, vendorId), ...)
JobsNavigation(onOpenCompany: (companyId) => showSupplierSheetForCompany(navigatorContext, companyId), ...)
```

Pass `navigation:` (the same `MarketplaceNavigation` the tab gets) so the sheet's *Message* and *Request for Quote* reach the app's screens from there too. `navigatorContext` is any context under the app's `Navigator` and `ScaffoldMessenger`.

## Constructor (for the lead to wire)

```dart
MarketplaceScreen(
  onBack: () => AppShell.selectHome(ctx),
  onPostRfq: ...,      // the requirement composer
  onMyRfqs: ...,       // the member's requirements
  onRfqAlerts: ...,    // the requirement alerts
  onBell: ...,         // the notifications
  onMessageSupplier: (vendorId) { ... },   // "Message" on a supplier's profile
  counts: () async => MarketplaceCounts(myRfqs: n, newAlerts: m),  // optional: the chips' numbers
  navigation: MarketplaceNavigation(...),  // optional: the other hand-overs (see below)
)
```

wrapped in `ChangeNotifierProvider<MarketplaceController>(create: (_) => MarketplaceController(AppConfig.demo ? DemoMarketplaceRepository() : ApiMarketplaceRepository(api: c.read<ApiClient>())))`, the way `app.dart` wires Jobs. A callback left out falls back to the same page on the website, so no tap is dead. `counts` is optional: left out, the Marketplace reads the numbers itself (`GET /rfq/mine/summary`, the unread requirement notifications).

`onMessageSupplier` is called with the supplier's **listing id** (`Vendor.id`, the id `POST /messaging/conversations/supplier { vendorId }` takes). Left out, the Marketplace opens the conversation itself through that endpoint and calls `navigation.onOpenConversation(conversationId)`, else opens the website inbox.

`MarketplaceNavigation` also takes, for a screen that has its own page for these, `onRequestQuote(supplier, {service, product})` (the app's requirement composer in place of the Marketplace's quote form), `onOpenProduct(id)`, `onOpenService(id)`, `onOpenRfq(id)` (a requirement: "View my request", a search hit), `onOpenSupplier(id)` and `onOpenConversation(conversationId)`. Every one has an in-app default (the quote form, the service and product pages) or a page on the website (`/rfq/<id>`, `/messaging?c=<id>`, `/manage/requirements`, `/quote`, `/notifications`), so no tap is dead. The website is opened only as that fallback and for the payment, terms and privacy pages.

## Controls and the tests that prove them

`W` = `test/marketplace_screen_test.dart` (the control tapped), `S` = `test/marketplace_suggest_test.dart`, `Q` = `test/marketplace_quote_test.dart`, `C` = `test/marketplace_catalog_test.dart`, `E` = `test/marketplace_entry_test.dart`, `U` = `test/marketplace_test.dart` (the mapping of the real API's answers, controller, pure logic), `L` = `test/live/marketplace_live_test.dart` (the real API through the app's own repository and controller).

| Control | Proved by |
|---|---|
| Back; bell (dot and count, callback or `/notifications`) | W title bar ×4 |
| Search (`?search=`), the cross, "Clear filters" empties the box | W search; U search; L search by name, headline, category, no match |
| Services and requirements the words also match | W extras; U extras dropped on clear; L searchExtras |
| Post RFQ / My RFQ's / Alerts (callback, website fallback, "cannot open") | W quick chips ×4 |
| The numbers on the chips (API, own source, zero) | W numbers ×3; U counts, Alerts types, no rights; L chips |
| Sort sheet (six orders, closes without a pick) | W order ×2; U query; L every order accepted and in order |
| By ratings (set, "Any rating") | W ×2; U query; L minRating |
| Verified only (on by default, off, on) | W; U toggle; L level filters |
| Filters sheet: category (open, pick, search), city, size, GST, trust level, Clear all, saved only | W Filters ×8; U filters, counts on the chip; L each filter narrows |
| Saved suppliers (`GET /vendors/saved`, empty state, show all) | W; U saved list, un-save drops the card; L bookmarks |
| Cards (content, same height, live logo and tile, long text, one review) | W cards ×6 |
| Load more (next page, line follows, button gone, failure keeps the list, duplicates dropped) | W foot ×2; U load more ×2; L pages through a whole result, each supplier once |
| Loading, error with Try again, empty, pull to refresh | W states ×5 |
| Two columns, three from 600 dp, shrunk three on a phone | W columns ×3 |
| Search suggestions (recent, examples, live suppliers and categories, "Search for", a stale answer dropped, the cross) | S x14 |
| Request a quote: the body sent (general, service, product), quantity, mobile, refusals keep the text, no double send, View my request, Done | Q x19; L quote requests with the seeded buyers |
| Service and product pages (price, terms, Sold by, quote, share, failure and Try again) | C x13; L a product's and a service's own read |
| Category browser, a category's page, the product and service boards | C x10; L the category tree, the boards, paging a whole category |
| A profile from another screen (by listing id, by company id, tab, bookmark, hand-overs, refusals) | E x15 |
| Parsers: list row, detail, services, products, certifications, tree, counts, cities, odd shapes | U (real captures in `test/fixtures/marketplace/`) |

## What the design shows that the API does not give

- **"Reg. CIN-U74999KA2019PTC1"** under the supplier's name: the portal stores no CIN. The line reads the company's legal form and the one registration number a listing publishes, the Udyam number (`Vendor.msmeNumber`): "Pvt Ltd • Reg. UDYAM-...". The local seed writes the design's CIN there so the golden-live match reads as designed. Request in `docs/backend-requests/marketplace.md` (1).
- **A brand colour for a supplier's name** (InnoWork's blue, SecureTech's green): the design bakes each name into its logo picture. A live card sets the name in the app's one brand blue beside the logo.
- **A photo on a service**: none in the API. Request (3). A live service row draws a tile with the service's first letter.
- **Product and service pages, the quote form, the category browser, the boards and the suggestions** have no design: they follow the website's mobile pages in the Marketplace's own type and colours (`marketplace_styles.dart`). Their regression is the widget tests; there is no golden against a PNG for them.
- **"Showing 6 of 180+"** beside ten cards: the design's own number does not match its cards; the app counts what is on screen ("Showing 10 of 180+").
- **The card order** of the design (4.8, 4.8, 4.8, 4.5, 4.7, ...) is not a rating order; the API sorts by paid placement, trust, then rating, so the seeded cards come in rating order.
- **The 180+**: the local database holds the 12 designed suppliers, 157 plain filler suppliers (seed) and the portal's own demo ones, 185 verified in all.

## Measured against the design

The phone golden against the 4x design (cut to the 390 dp frame; `tool/design/strip_diff.py`, `line_widths.py`, and a 4x render of the golden with `--dart-define=GOLDEN_SCALE=4` measured by ink boxes):

- Whole page: mean strip difference 4.7 of 255 (it was 15.6 before the fits), card rows start at 177, 346, 515, 684, 853 dp as the design's do (to the half dp), the card is 179.75 x 160 dp with a 1.5 dp slate border and 12 dp radius.
- Chips: every icon and word within 1 dp in x and y (row one at 12 dp Plex w600, row two at 12.3), the count circle and the "2 new" pill 16 dp tall as designed.
- Search: 14 dp Plex w500 hint (the shared 12 dp field is for Jobs), Material search glyph 13.25 dp of ink.
- Card text: every line width within 1.000 ± 0.01 of the design's: title 15.8 dp Plex **Bold** (the design's ink is 21% heavier than SemiBold's), body 12 dp **Medium**, "(124 reviews)" 12 dp Medium, rating 14.6 dp Bold amber; the star is 20.25 dp of ink as the design's.
- Foot: "Showing" line, the 240 x 6.5 dp bar and "Load more suppliers" within 1 dp.
- **The tablet comp** (`marketplace-3col.png`) is not the phone design scaled: its cards are 119 x 120 dp with a 1 dp border, its chip text is about 0.84 of the phone's and its first card starts 10 dp higher. The app draws three columns at the phone card's shape (smaller in a narrow cell, full size from 600 dp wide, where a cell is wider than 179.75 dp), so the comp is matched in structure, not pixel for pixel (`marketplace_3col.png` is a regression golden; what a faithful build needs is listed under "Pixel pass later").

The profile sheet's three tabs are measured in `supplier_profile.md` (strip difference 4.5 on the overview).

Two choices where the designs disagree: the phone design draws *Post RFQ* and *Filters* white, the tablet comp grey (Jobs' *Post a job* is grey); the app follows the phone design.

## Pixel pass later

Flows first (owner's order): the pixel work stopped here and is to be picked up in one later pass. What is known, with the numbers measured so far (`tool/design/strip_diff.py` on the 2x render against the 4x cut of the design; `build/mk/*.py` scratch scripts compared ink boxes, not kept).

**Frames.** The designs include the shell's bottom bar: the phone frame is 390 x 1204 dp, of which the bar is the last 61.5 dp, and the tablet comp 390 x 1590 with the bar at 1530. The goldens are the screen alone: 390 x 1143 and 390 x 1530. The phone content ends at 1141.5 dp against the design's 1142.5, so "the render is 94 dp shorter" is the bar (61.5) plus the golden being cut at 1110 until this pass; the screen's own bottom spacing (28 dp under "Load more") is right. The bar itself is the shell's (the design draws six tabs, `IcrBottomNav` seven).

**Phone** (`marketplace.png`): mean strip difference 4.50 of 255 over the 1143 dp; the worst strips are ink weight (the design's text is about 1.1x heavier) at 1020 dp (the last row's card text and "Showing" line, 17.6), 600 dp, 270 dp and 930 dp. Card edges at 177/346/515/684/853 dp, widths within +-1%.

**Tablet comp** (`marketplace-3col.png`): mean strip difference 21.5 (27 cards now; it was 19.2 with 9). The comp is not the phone design scaled, and the structure to build, measured from the PNG at 4x (dp):

- *Grid:* 3 columns, 27 cards (nine rows; the same nine kinds in turn: BlueDot, InnoWork, InnoWork / GreenGuard, SecureTech, InnoWork dark / SafeHome, InnoWork, InnoWork), card **119 x 120** with a 1 dp `E2E8F0` border, left margin 12.5, 5 between columns, right margin 10.5, **10 between rows**, first card top at **167** (the phone's is 177: 11 dp under the filter chips, not 21). The third body line of a card is cut by its bottom edge.
- *Inside a card* (offsets from the card's top edge): logo and name lockup 15.75 to 40.25 (24.5 tall, the same size as the app's scaled card draws it), rule at 49, star 58.75, title ink 78.5, body lines 93.25 and 105.25, bottom edge at 119. The app's scaled card has the logo at 6.5, the rule at 31.5 and the star 41: so +9.25 above the logo, +8.75 between logo and rule, and from the rule down everything is within 0.5 dp. The title is 11 dp (the scaled 10.46 is 4.9% too narrow); the other lines' widths match to 0.5%.
- *Toolbar:* the search hint is 10.15 dp (0.725 of the phone's 14); quick chip text 10 dp (0.838 of 12), filter chip text 10.5 (0.85 of 12.3, "Filters (3)" 0.87: it is bold in the comp). Chip outlines (x of the left and right edge): row 1 `[10, 96.25] [101.25, 207] [212, 325.25]`, row 2 `[10, 94] [99, 202.25] [207.25, 290.5] [295.5, ...]`, both 25 dp tall at y 96 and 130; the app's are `[10, 103] [108, 221.25] [226.25, 354.5]` and `[10, 102.75] [107.75, 224]`. *Post RFQ* and *Filters* are filled `F2F4F6` in the comp (white in the phone design). Icons keep their size (13.5 dp ink for the circle-plus); "2 new" is a 35.75 dp pill (the app's 44.5), the count digit 0.92 of the phone's. The comp's toolbar is a compact variant: the cleanest build is a `compact` flag on the toolbar and the card, set when three columns have to fit under 500 dp wide, with the numbers above.

**Profile sheets** (`supplier-*.png`): overview 4.47; the services and compliances rows are within 1 dp (108 dp pitch). The band at about 240 dp that the strip diff flags on the services and compliances tabs (strips 75 to 79) was not examined in this pass.

## Seed (`tool/seed/marketplace.ts`)

Idempotent, marked (`design-mkt-*`), removable (`--remove`), local database only (it refuses any `DATABASE_URL` that is not localhost). It seeds:

- the ten cards of the design (BlueDot, six InnoWork, GreenGuard, SecureTech, SafeHome; paid placements at the top rung so they lead "Top rated");
- Vikasha Aero Tech (profile: see `supplier_profile.md`): four offices, six services, four certifications, two ratings, the design's CIN in `msmeNumber`;
- a **sandbox supplier** (`design-mkt-v-sandbox`) the live tests save, rate and send requests to, reset on every run;
- three SecureTech products with staggered creation times;
- a **buyer company** with two personas the live quote tests sign in as: `marketBuyer` (has a mobile number) and `marketNoPhone` (none, so the "asked when the profile has none" path is proved; the test skips if a number has since been saved, and every seed run clears it). Bharat Buyer has no active company, so the API refuses his requirements: that is why the personas exist;
- 157 filler suppliers so the directory reads "180+" (`--no-fill` leaves them out).

Run: `powershell -File tool\seed\run.ps1` (once the lead adds `marketplace` to it, after `mentorship`, and a row for it to `tool/seed/README.md`), or alone from `E:\ICR\irc-portal\backend`: `NODE_PATH=E:/ICR/irc-portal/node_modules npx ts-node --transpile-only E:/ICR/icr-mobile/tool/seed/marketplace.ts [--remove] [--no-fill] [--dry-run]`. Logos are cut from the design by `tool/design/cut_marketplace_logos.py` (marks only, at 2x). `python tool/seed/marketplace_fixtures.py` re-captures the unit tests' fixtures.

## Demo content

`DemoMarketplaceRepository` (`--dart-define=FEED_SOURCE=demo`): the design's ten cards (`phoneCards`) or nine (`tabletCards`), each drawn from its lockup picture (`assets/images/demo/marketplace/lockup_*.png`), counts 3 and 2 new, Vikasha Aero Tech's profile with its six services, four compliances and two audited proofs.
