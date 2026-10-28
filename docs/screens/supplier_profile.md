# Supplier profile (the sheet a card opens)

Designs: `docs/designs/hires/supplier-overview.png`, `supplier-services.png`, `supplier-compliances.png` (the three tabs of one sheet). Code: `lib/features/marketplace/supplier_sheet.dart` (the sheet: frame, handle, save and share, header, tabs, the bar), `supplier_controller.dart` (its state), `widgets/supplier_overview_tab.dart`, `supplier_catalog_tab.dart`, `supplier_proofs_tab.dart`, `hubs_sheet.dart`, `rate_sheet.dart`, `clamped_text.dart`. Goldens: `build/screens/supplier_overview.png`, `supplier_services.png`, `supplier_compliances.png` (demo content, at the designs' frames 390 x 780 / 1095 / 898). Tests: `test/marketplace_sheet_test.dart` (every control tapped), `test/marketplace_test.dart` (the parsers, against the real API's captured answers), `test/live/marketplace_live_test.dart` ("a supplier's profile": the real API).

Notes for the tab it opens from: `docs/screens/marketplace.md`.

## How it opens

`showSupplierSheet(context, supplier, {tab})` (a card's tap calls it). It pushes a blurred, dimmed `BlurredSheetRoute` that keeps the screen's `MarketplaceController` and `MarketplaceScope` (the lead's callbacks), so the list behind follows what the member does here: a bookmark (`markSaved`), and the full listing read back (`updateSupplier`). Any other screen opens a profile with `showSupplierSheetById(context, vendorId)` or `showSupplierSheetForCompany(context, companyId)`, which read the listing and open this same sheet (see `marketplace.md`, "A profile from another screen"); a seed that knows only the id works too (the controller reads the listing before the tab, since the tab needs the company). The card seeds the sheet (name, rating, headline); `GET /vendors/:id` fills in offices, registration and ratings; each tab reads what it shows the first time it is opened (a glanced-at profile is one request).

## What is on it

- **Handle, bookmark, share** (top bar, 56 dp). The bookmark saves the supplier (`POST|DELETE /vendors/:id/save`, applied at once, taken back with the API's sentence if refused); a supplier already saved opens filled. Share hands "<name> on ICR Supplier Mart" and the supplier's page on the website (`/companies/:id`) to the system share sheet.
- **Header:** the logo (the company's own, else the design's flat blue-grey tile), the name with the blue seal (Verified and above), "Pvt Ltd • Reg. ..." (legal form and the one registration number the API publishes), the rating, "84 Enterprise Reviews", the tier ("Tier-1" for Elite, down to "Tier-4" for Verified; Registered has none), the supplier's one-line pitch.
  - *Call HQ* opens the dialler with the head office's number (`tel:`), *WhatsApp* a chat with it (`https://wa.me/<digits>`, 91 put in front of a bare Indian mobile, a first line prefilled), *Website* the supplier's own site. A supplier with no number or site draws them dimmed and says so in a snackbar when tapped.
- **Tabs:** Overview, Products & services, Compliances & Proofs (the open one is the blue pill).
  - *Overview:* "Enterprise Track Record" (up to four tiles of what the listing can back: projects executed, clients served, years of experience, hubs with their cities; a tile with no number is left out), "About Organization" (two lines, "Read full company charter" opens the rest and "Show less" closes it; the link shows only when there is more), the hubs band ("PAN-INDIA PRESENCE / 4 Operational Hubs / Bengaluru • Hyderabad • Pune • Chennai • replies within 4 hours", with *View Hubs*, shown for a supplier with at least two offices), then **Good to know**: founded, team size, how fast it replies, whether it takes new work, where it serves, certifications (only the facts the listing declares).
    - *View Hubs* opens the offices, head office first: name, place, address, a number to call, "Map" (Google Maps at the office's pin, else its address).
  - *Products & services:* chips ("All (n)", "Products", and one per service group; the groups are the services' sub-categories named by the category tree), the rows of the open group. A service row: 64 dp photo (or a tile with its first letter: the API has none, see the backend request), name, two lines (cut at a word, the ellipsis against it), how fast, and the button: **Get Quote** for a service with no price, **Book Service** for one with a rate. A product row: photo, name, "₹18,500 / piece • In stock", description, **Get Quote**. A row opens its service or product page; the button asks for a quote for that service or product (`onRequestQuote`).
  - *Compliances & Proofs:* "Compliances & Audited Proofs" with the seal, then each certification the company holds that ICR shows buyers (`GET /certifications/verified`): glyph by kind (licence, quality, safety, insurance...), title, the number in a typewriter face, the note or "Audited by <issuer>", and its status (Active, Certified, Insured, Member). Then "Audited Enterprise Proofs": every rating with its stars and what was said in italics. **A rating is anonymous** (owner's decision): where the design puts the reviewer's company the sheet says "Verified buyer", and where it puts their role, "ICR member • Oct 2026" (from when it was left). The demo content keeps the design's own reviewers. **Rate this supplier** (below).
- **The bar:** *Request for Quote (RFQ)* calls `MarketplaceNavigation.onRequestQuote(supplier)`; the message icon calls `onMessage(supplier)` (the screen's `onMessageSupplier(vendorId)`); with none wired the Marketplace opens the conversation itself (`POST /messaging/conversations/supplier`) and calls `onOpenConversation(id)`, else the website's `/messaging?c=<id>`; a supplier with nobody to receive a message shows the API's own sentence.

### Rate this supplier

One to five stars and an optional comment (up to 1000 characters). `POST /vendors/:id/ratings` keeps one rating per member and replaces it on the next, recounts the supplier's average from the ratings it holds, and refuses the supplier's own team ("You cannot rate your own listing"); its sentence is shown as it is, and what was typed stays. After a rating the listing is read again for the new average. It is shown without the member's name.

## Controls and the tests that prove them

`S` = `test/marketplace_sheet_test.dart`, `U` = `test/marketplace_test.dart`, `L` = `test/live/marketplace_live_test.dart`.

| Control | Proved by |
|---|---|
| A card opens its sheet; the full listing is read once | S opening; L the full listing |
| Header: name, seal, registration line, rating, tier, pitch; Registered (no seal, no tier); no ratings | S header x2; U registration line, tier |
| Call HQ, WhatsApp, Website (right URIs; nothing listed says so; cannot open says so) | S x3; U `whatsAppNumber`, `websiteUri` |
| Bookmark (saved, taken back, refused rolls back, opens filled); Share | S save and share x4; L the bookmark in the sheet |
| Tabs read on first open, once | S tabs; L the tabs read what they show |
| Track record tiles, hubs band, About clamp and expand, View Hubs (call, map, head office first), good to know, one office has no band, load failure and Try again | S Overview x6; U track record, dispatch band |
| Products & services: chips narrow, row content, Get Quote / Book Service, a row's button asks for its quote, a row opens, empty, failed | S x5; L tabs, products |
| Compliances (rows, statuses, glyph), anonymous ratings, the demo's own reviewers, empty, failed | S x5; U certifications; L tabs |
| Rate this supplier (stars required, posted with the comment, thanks, refusal keeps the text) | S rating x2; L a rating |
| Request for Quote (callback / the Marketplace's form), Message (callback with the listing id, started here, no one to receive) | S bar x5; L a supplier with nobody to receive |

## What the design shows that the API does not give

- **"Reg. CIN-U74999KA2019PTC1"**: see `marketplace.md` (the Udyam number stands in; request 2 in `docs/backend-requests/marketplace.md`).
- **"0 Safety Incidents (Zero Human Rigging Risk)" and "42+ Commercial Towers Under Active AMCs"**: no such fields. The live tiles are projects, clients served, years and hubs; a tile with no number is left out.
- **The service photos**: none in the API (request 3).
- **"PAN-INDIA FAST DISPATCH / 4 Operational Tech Hubs with Ready Fleets / BLR • HYD • PNQ • MAA with < 2hr SLA"**: marketing copy. The live band says "PAN-INDIA PRESENCE" (three or more cities) or "OPERATING HUBS", the number of offices, their cities and, if the supplier declares how fast it replies, "replies within 4 hours".
- **The reviewers' companies and roles** ("Embassy TechZone (Pune SEZ Campus)", "Facilities Director • 14 Towers Project"): ratings are anonymous. Demo content only.
- **"Book Inspection"** (a service button): demo wording; live it reads "Book Service" or "Get Quote".
- **Tab state:** the three PNGs draw "Overview" filled on all of them; the app fills the open tab.

## Measured against the designs

Goldens (2x of the frame, 4x measured by ink boxes with `--dart-define=GOLDEN_SCALE=4`; `tool/design/strip_diff.py`, `line_widths.py`):

- **Overview** (390 x 780 dp): mean strip difference 4.5 of 255. Header: the name, registration line, rating row, tagline and the three buttons land within 1 dp in x and y (name Work Sans Bold 16 dp, registration 10.4 dp, rating line 10.65 dp, tagline 10 dp Medium); the tab pills are 28.25 dp (open) and 29.5 dp (hairline) tall, text 9.9 dp Semibold; the tiles' digits, captions and icon circles within 0.5 dp, the About lines and "Read full company charter" within 0.5 dp; the hubs band 558 to 642 dp as the design's; the bar starts at 713.25 dp, the button 12 to 322 dp.
- **Products & services** (390 x 1095 dp): chips 24.25 dp, rows at the design's 108 dp pitch (rules at 417.75, 525.75, ... 957.75), the photos 64 dp at x 34, title Work Sans 12 dp, description 8.6 dp Medium kept to two thirds of the row, meta 10.6 dp Medium, buttons 10.5 dp Semibold in a 24 dp pill.
- **Compliances & Proofs** (390 x 898 dp): rows within 1 dp (rules at 360, 418, 476, 546 dp against 359.75, 417.75, 475.75, 545.75), titles Work Sans Semibold 10 dp wrapping where the design's do, the proofs' stars, names, roles and quotes within 1 dp. The licence number is set in `Courier` (on every phone); the golden has no such font and borrows IBM Plex Sans for it, so that one line is 5 dp taller there than the design's. A typewriter face bundled in `pubspec.yaml` (IBM Plex Mono or Courier Prime) would make it exact: a change for the lead.
- The remaining strip difference is the text's ink: the designs' text is about 1.1 times heavier than Flutter's at the same size and weight (their renderer), and the tab pills' state (above).

## Left

- Nothing in the sheet itself. *Request for Quote (RFQ)*, a service's *Get Quote* and a product's *Get Quote* open the Marketplace's own quote form (`POST /rfq`, private to the supplier) unless the lead wires `onRequestQuote`; a row opens the service or product page (`marketplace.md`, "Slice 4"). The tab-state difference (the PNGs fill "Overview" on all three) and the licence-number typewriter face are noted above.
