# Company catalogue — My Products, My Services

The website's `/manage/products` (`ProductsWorkspace`, `ProductSlideOver`, `ProductCard`, `ProductPhotoField`) and
`/manage/services` (`ServicesWorkspace`, `ServiceSlideOver`, `ServiceCard`), drawn by the app since 12 Nov 2026 for the
drawer's "My Products" and "My Services". The owner's instruction was to take the website as the reference and do as it
is: the same fields, lists, add/edit/delete flows and empty states, in the app's look (white, hairlines between rows, grey
text, nothing boxed, nothing left to the website).

The page subtitles, header buttons, empty states and the services figures carry the owner's recommended wording from
`07-supplier-mart.docx` (12 Nov 2026) where the website's words differ; see *The owner's wording* below for each change and
each recommendation left out.

## What it shows

`lib/features/catalog/` — `catalog_models.dart` (the rows, drafts, scores and request bodies), `catalog_repository.dart`
(`CatalogRepository`: `ApiCatalogRepository`, `DemoCatalogRepository`), `catalog_controller.dart` (`ProductsController`,
`ServicesController` over one `CatalogController<T>`), `catalog_words.dart` (the website's sentences), `catalog_parts.dart`
(the notes, the head, chips, search, rows, the category pair, the bulk bar), `catalog_scaffold.dart` (the frame and the
page's states), `catalog_photo_picker.dart` (the phone's photo chooser behind a seam), `product_sheet.dart`,
`service_sheet.dart`, `products_screen.dart` (`ProductsScreen`), `services_screen.dart` (`ServicesScreen`).

Both screens take `({required onBack, repository, viewer, onCreateCompany})`; `ProductsScreen` also takes `photoPicker`.
A screen builds `AppConfig.demo ? DemoCatalogRepository() : ApiCatalogRepository(api: context.read<ApiClient>())` and reads
who is looking from the signed-in session (`maybeAuth`).

### The page

- **Who sees what.** The website's `RequireRole` (VENDOR, COMPANY_ADMIN, SUPER_ADMIN) and `lacksCompany`: someone acting for
  no company sees the website's `NoCompany` ("Your account isn't linked to a company" with its sentence; "Create a company"
  only when the lead passes `onCreateCompany`); a role that does not manage the catalogue is told the page is for the
  company's admins and sellers; otherwise the list.
- **The supplier-listing notice.** `GET /vendors/me/access`; while `vendorId` is null the website's
  `SupplierListingNotice as="notice"` sits above the list — "Your company doesn't sell on ICR yet. Start selling to appear in
  the Supplier Mart and answer buyers' requirements." — with **Start selling**, which sends `POST /vendors { companyId }`
  exactly as `StartSellingButton` does (the API fills the listing from the company) and takes the notice away. The API's
  refusal (a company that already sells) shows under the button. The catalogue itself stays usable either way, as on the
  website: products and services belong to the company.
- **The head.** The page's subtitle, the add button ("Add Product" / "Add Service"), the website's tiles as one line
  ("3 products · 2 categories · 1/3 with a photo · Listing strength 67% average across your products";
  "Services Listed: 3 · Service Categories: 2 · Average Starting Price: ₹50,000 · Listing Quality: 76% · With Turnaround:
  2/3 · Best-Completed Listing: Daily Office Housekeeping"), the plan's listing
  places when the plan sets a number (`GET /subscriptions/entitlements` → `benefits['listing.items'].limit`: "6 of 10 listing
  places used", "3 products and 3 services — your plan counts them together.", the full sentence and **See plans** when
  full), and on products the "Worth finishing:" chips (n without a photo / price / category) that narrow the list.
- **The toolbar.** The search box ("Search products…" / "Search Services"; name, description, category, unit), the
  filter chip (products: All products, Complete, Missing a photo, Missing a price, Missing a category, Anything missing;
  services: All Statuses, Optimized, Needs details, No price), the sort chip (Most recent — "Recently Added" on services —,
  Name A–Z, Price low→high, Price high→low, Needs work first), **Select** (Done),
  then the category chips with counts ("All (3)", "Housekeeping (2)"; products group by the joined category, services by
  the sub-category else the category) and, in select mode, "Select all n" / "Clear selection". Nothing left says "No
  products match" / "No services match your filters" with **Clear filters**.
- **A product row** (the website's card): the photo (or an inventory glyph), name, category or "No category", the price
  as the supplier profile prints it ("₹18,500 / piece") or "Price on request", two lines of the description or "No
  description yet — buyers compare on specifications and pack size.", the one status chip (`statusOf`: No photo → Price on
  request → Complete → "Add unit" / "Add 2 details"), and the listing strength (score over the six signals photo, name,
  category, description, price, unit; "Add: Photo, Price" under it). Tap opens the editor; ⋮ opens Edit · View as buyer
  (`openSitePage('/products/<id>')`, the app's own product page through the lead's resolver) · Duplicate (`POST /products`
  with "<name> (copy)" and what the original holds) · Delete.
- **A service row**: its initial on the blue tint, name, the sub-category's (else category's) name from the taxonomy or
  "Uncategorized", the description or "No description yet — add one to help buyers understand this service.", chips for
  the price ("₹85,000 per month" or "No price set") and the turnaround, the status chip ("Optimized", or the gap — "Add
  pricing model" / "Add 2 details" — which opens the editor on that field), and the score over seven signals, labelled
  "Listing Quality" as the page's figure is (a service filed only at category level scores 6/7, as on the website). ⋮ opens Edit · Duplicate · Delete.
- **Deleting asks first** with the website's `ConfirmDeleteDialog` words ("Delete “Visitor Badge Printer”?", "It comes off
  your supplier listing and the marketplace straight away…"), for one row and for a selection ("Delete 3 products?"); each
  row is deleted on its own, and "2 of 3 could not be deleted." / "Some services could not be deleted." reports the rest.
- **Empty states.** Products: "No products listed yet", "Showcase the products you offer to help buyers discover your
  offerings and request quotations.", the three numbered steps (Product image — "Add a clear, high-quality photo." ·
  Product category — "Select the right category for easy discovery." · Unit price — "Or leave it blank for “Price on
  request”.") and "Add Your First Product". Services: "No services listed yet", "Add your company's services to showcase
  your expertise, improve discoverability and receive relevant buyer enquiries." and "Add Your First Service".
- Toasts as the website's: "Product published." / "Product updated." / "Product deleted." / "Duplicated — edit the copy to
  make it its own." / "n products deleted."; "Service published." / "Service updated." / "Service deleted." /
  "Duplicated." / "n services deleted.".

### The editors (bottom sheets, `EditSheet`: Cancel / Save, "Discard your changes?" when left dirty)

**Add a product / Edit product** (`ProductSlideOver`), in its order:

1. *Photo* — "The first thing buyers see…". The frame is the upload button; with a picture, Replace and Remove under it.
   PNG/JPG/WEBP up to 2 MB ("Use a PNG, JPG or WEBP image.", "That image is over 2MB…"); the file goes up at once through
   `POST /uploads?purpose=catalog` (the PUBLIC purpose the website uses, since product pages are read logged out) and the
   returned `/uploads/...` path is what the product stores as `imageUrl`. Save waits while an upload is on its way.
2. *Basic details* — Product name (required, "Give the product a name", the Taski example as helper), the category pair
   (Category → Sub-category from `GET /categories/tree?kind=PRODUCT&depth=2`, clearable; "Filed under “X”. Pick a category
   to move it." for a stored key the tree no longer shows, which is kept unless another is picked), Description.
3. *Pricing* — "Leave the price blank and buyers see “Price on request”." Price (₹) (digits and a point; "A price above
   ₹0, with at most two decimals"; "Before GST."), Sold per with the website's unit suggestions as chips (piece, pack, box…;
   anything typed is kept).
4. *Stock & terms* — "Optional. Say only what you will honour…". Availability (Not stated / In stock / Made to order /
   Out of stock), Warranty (months), Returns within (days), Free delivery over (₹), Bulk pricing from (in the unit). Each
   term is held to `PRODUCT_TERM_LIMITS` ("Whole numbers only", "Between 2 and 10,00,000") and, once valid, says what
   buyers will read ("Buyers see “1-year warranty”.", "Buyers see “Bulk pricing from 50 piece”.").
5. *Listing strength* — the score and the six signals ticked, live from the draft (the website's `StrengthChecklist`).

The body is the website's `payloadFrom`: a new product sends `name` plus only the fields that hold something, `categoryKey`
for the most specific level picked, and `companyId`; an edit sends every field (blank → `null`, so clearing clears) and
`categoryKey` only when the category was changed. Save reads "Publish product" / "Save changes".

**Add a service / Edit service** (`ServiceSlideOver`): Basic details (Service name — required; Category — required — and
an optional Sub-category from `kind=SERVICE`; Description with "Describe scope, inclusions…"), Pricing ("Shown to buyers as
the starting price."; Starting price (₹); Pricing model with per visit / per sqft / per hour… as chips), Service delivery
(Turnaround time, "e.g. 24 hours, 2–3 days"), Marketplace visibility (on a new service the switch "Add sub-category to my
public listing" / "Add category to my public listing", on by default, sent as `addToListing`; then the "Featured
placement, media galleries and per-service analytics are rolling out soon…" note). The body is the website's `handleSave`:
`name`, `category`, and the optional fields left out when blank on a create, `null` on an edit; `companyId` and
`addToListing` on a create. Save reads "Publish service" / "Save changes".

### API calls

`GET /vendors/me/access` · `GET /products?companyId=&limit=100` · `GET /services?companyId=&limit=100` ·
`GET /categories/tree?kind=PRODUCT|SERVICE&depth=2` · `GET /subscriptions/entitlements` · `POST /products` ·
`PATCH /products/:id` · `DELETE /products/:id` · `POST /services` · `PATCH /services/:id` · `DELETE /services/:id` ·
`POST /uploads?purpose=catalog` · `POST /vendors { companyId }`. Every write is followed by a fresh read of the list (the
website invalidates its whole query the same way). A refusal (an unknown category, a sub-category under the wrong
category, the plan's listing limit) is the API's own sentence, shown in the sheet with what was typed kept.

## The owner's wording (`07-supplier-mart.docx`, 12 Nov 2026)

Applied (website's words → owner's):

| Where | Was | Now |
|---|---|---|
| My Products subtitle | The products your company sells — on your supplier listing and the marketplace product grid. | Manage the products your company offers. Add them to your ICR supplier profile and make them discoverable to buyers across the marketplace. |
| My Products header button | Add product | Add Product |
| Products empty heading | No products yet | No products listed yet |
| Products empty sentence | Add what you sell and it shows on your supplier listing and in the marketplace product grid, where buyers can ask you for a quote. | Showcase the products you offer to help buyers discover your offerings and request quotations. |
| Step 1 | A clear photo — It is the first thing on every product card. | Product image — Add a clear, high-quality photo. |
| Step 2 | A category — Buyers filter the product grid by it. | Product category — Select the right category for easy discovery. |
| Step 3 title | A price per unit | Unit price |
| Products empty button | Add your first product | Add Your First Product |
| My Services subtitle | Manage the services your company offers and optimize them for better marketplace visibility. | Manage and showcase your company's services to improve marketplace visibility and attract buyer enquiries. |
| Services figures | 3 services · 2 categories · Avg starting price ₹50,000 · Listing strength 76% · 2/3 with turnaround | Services Listed: 3 · Service Categories: 2 · Average Starting Price: ₹50,000 · Listing Quality: 76% · With Turnaround: 2/3 · Best-Completed Listing: … |
| Service row score | Listing strength | Listing Quality (the same measure the page figure averages) |
| Services search | Search services… | Search Services |
| Services status filter | All statuses | All Statuses |
| Services sort (newest first) | Most recent | Recently Added |
| Services empty heading | No services added yet. | No services listed yet |
| Services empty sentence | Create your first service and start receiving buyer enquiries. | Add your company's services to showcase your expertise, improve discoverability and receive relevant buyer enquiries. |
| Services empty button | Add Service | Add Your First Service |

"Best-Completed Listing" (the website's "Most Complete" tile: the highest-scoring service) was not on the app's line before
and is added with the owner's name for it.

Left out, and why:

- **Step 3's "Add a price or select “Price on Request”."** The editor has no "Price on Request" choice to select; a blank
  price is what buyers read as "Price on request", so the step keeps "Or leave it blank for “Price on request”.". Adding a
  "Price on request" choice to the pricing section would make the owner's sentence true.
- **"With Turnaround" → "On-Time Delivery".** The figure counts services that state a turnaround time; nothing measures
  deliveries, so the new name would claim something the number does not hold.
- **"Profile Views" → "Service Views" and "Quote Requests".** These are "Soon" on the website with no figure behind them,
  and the app does not show them.
- **"Export Products", "Import Services", "Export Services", "Grid View" / "List View".** The app has no export, import or
  grid view (below).
- **The profile completion banner** ("Your profile is 30% complete…"). It is the person's profile-completeness banner of
  the website's console frame, not part of these pages; it belongs to the app's shell if anywhere.
- Products keeps "Most recent" for its sort and "Listing strength" for its score: the owner's notes rename them on My
  Services only.

## What the website does that the app leaves out, and why

- **Export (CSV download) and Import ("coming soon", disabled).** A phone has no download; an export through the share
  sheet can follow if asked. Import is disabled on the website too.
- **Grid / list toggle.** A phone has one column; every row is the website's list card.
- **The buyer preview panels** (the marketplace card and the service's preview beside the form). The website hides the
  service preview on a phone itself; the product's listing-strength checklist is kept, since it is what the rows score by.
- **Cropping the photo to 4:3 before upload.** The app has no cropper; the photo goes up as chosen and the frame shows it
  cover-fitted, as the product card does.
- **Deleting a service without asking.** The website deletes a service at once and asks only for products; the app asks
  for both, since a slip of the thumb on a phone is likelier than a mis-click.
- **Remembering grid/list per person** (`localStorage`) — nothing to remember with one column.
- **The desktop-only "View as buyer" in the editor's header** — the row's menu has it.

## Tests

`test/catalog_test.dart` (27, against `DemoCatalogRepository` and a fake photo chooser; the owner's wording is asserted in
the list and empty-state tests): the products list and its figures,
adding (what is sent, the term sentences and limits, the disabled save), the photo (refused types and sizes, the upload,
the path in the body), editing (every field, nulls, the category only when changed), discard on leaving, the row menu
(delete asks first, Cancel sends nothing, duplicate's body), bulk select and delete, search/filter/category chips and
"nothing matches", the no-listing notice and Start selling, the no-company note, the role note, the empty state, the
plan's places line, a failed read, a refused save kept in the sheet; the services list, adding (name and category needed,
the body), editing (nulls, no switch), the "Add …" chip opening the editor, delete asking first, the notice, no company,
empty; and the models' scores, prices, term rules and sorts.

## 13 Nov 2026: copy refined to the client's standard

The client's marked-up manual (13 Nov 2026) asks for crisp, international wording: Title Case for the names of things
a person taps or reads as a label, plain sentences with a full stop, no dash used as punctuation, "Select" and "Enter"
for "Pick" and "Type", "Unable to load" for "Could not load", and "Marketplace", never "Supplier Mart". The owner's
12 Nov words above are kept; only their capitalisation was brought into line. Wording only: no layout or behaviour
changed.

The lead's rulings of the same day are applied too: an empty-state, locked-state or error *title* is a heading (Title Case, no full stop) and the line under it a sentence; the retry button reads "Try Again".

| Where | Was | Now |
|---|---|---|
| Buttons, headings, labels, chips and menu rows to Title Case (77 strings) | Add a product · Edit product · Publish product · Save changes · Basic details · Product name · Sub-category · Sold per · Stock & terms · Returns within · Free delivery over · Bulk pricing from · How buyers see it · Upload product photo · Add a service · Service name · Starting price · Pricing model · Service delivery · Turnaround time · Marketplace visibility · Add category to my public listing · View as buyer · Select all 3 · Clear selection · Clear filters · See plans · Start selling · Create a company · Listing strength · Sort by | Add a Product · Edit Product · Publish Product · Save Changes · Basic Details · Product Name · Sub-Category · Sold Per · Stock & Terms · Returns Within · Free Delivery Over · Bulk Pricing From · How Buyers See It · Upload Product Photo · Add a Service · Service Name · Starting Price · Pricing Model · Service Delivery · Turnaround Time · Marketplace Visibility · Add Category to My Public Listing · View as Buyer · Select All 3 · Clear Selection · Clear Filters · See Plans · Start Selling · Create a Company · Listing Strength · Sort By |
| The owner's step titles (case only) | Product image · Product category · Unit price | Product Image · Product Category · Unit Price |
| Status chips and filters | No photo · Price on request · Add photo · Add 2 details · Needs details · No price · In stock · Made to order · Out of stock · All products · Missing a photo · Anything missing · No category | No Photo · Price on Request · Add Photo · Add 2 Details · Needs Details · No Price · In Stock · Made to Order · Out of Stock · All Products · Missing a Photo · Anything Missing · No Category |
| Sorts | Most recent · Price (low → high) · Price (high → low) · Needs work first | Most Recent · Price (Low → High) · Price (High → Low) · Least Complete First |
| Products search | Search products… | Search Products |
| A failed read | Your products could not be loaded. · Could not load the services. | Unable to load your products. · Unable to load your services. |
| The "finish these" line | Worth finishing: | Needs attention: |
| Plan places | 3 products and 3 services — your plan counts them together. Remove one you no longer sell, or move to a larger plan, to add another. | 3 products and 3 services. Your plan counts them together. To add another, remove one you no longer sell or move to a larger plan. |
| Duplicate toasts | Duplicated — edit the copy to make it its own. · Duplicated. | Product duplicated. Edit the copy to make it a separate product. · Service duplicated. |
| Delete dialog titles | Delete 3 products? · Delete 3 services? | Delete 3 Products? · Delete 3 Services? |
| Delete dialog body | It comes off your supplier listing and the marketplace straight away. Buyers with a link to it will find it gone. | It will be removed from your supplier listing and the marketplace immediately. Links to it will stop working. |
| A row with no description | No description yet — buyers compare on specifications and pack size. · No description yet — add one to help buyers understand this service. | No description yet. Buyers compare on specifications and pack size. · No description yet. Add one to help buyers understand this service. |
| Step 3 body | Or leave it blank for “Price on request”. | Or leave it blank for “Price on Request”. |
| No company | …invite this email address: accepting the invite links your account. If it isn't on ICR yet, create it: you become its admin. | …invite this email address. Accepting the invite links your account. If it is not on ICR yet, create it and you become its admin. |
| No listing | Your company doesn’t sell on ICR yet. Start selling to appear in the Supplier Mart and answer buyers’ requirements. | Your company does not sell on ICR yet. Start selling to appear in the Marketplace and respond to buyers’ requirements. |
| Start selling failed | Could not start selling. Please try again. | Unable to start selling. Try again. |
| Product editor subtitles | It goes on your supplier listing and the marketplace product grid. · Changes show on your listing and the marketplace as soon as you save. | It will appear on your supplier listing and the marketplace product grid. · Changes appear on your listing and the marketplace when you save. |
| Name helper and error | Brand, model and size read best — e.g. “Taski R3 Cleaner 5L”. · Give the product a name | Include the brand, model and size, e.g. “Taski R3 Cleaner 5L”. · Enter a product name. |
| Category pickers | Pick a category · Pick a sub-category · Pick a category, then a sub-category. · Filed under “X”. Pick a category to move it. · Choose a category | Select a category · Select a sub-category · Select a category, then a sub-category. · Filed under “X”. Select a category to move it. · Select a category. |
| Description helper | What it is, what it is for, pack size and specifications buyers compare on. | Describe the product, its use, the pack size and the specifications buyers compare. |
| Pricing | Leave the price blank and buyers see “Price on request”. · A price above ₹0, with at most two decimals | Leave the price blank to show buyers “Price on Request”. · Enter a price above ₹0 with up to two decimals. |
| Terms | Optional. Say only what you will honour: buyers see a line for each term you fill in, and nothing for one you leave blank. · Leave blank to say nothing. · Whole numbers only · Between 2 and 10,00,000 | Optional. Enter only what you will honour. Buyers see a line for each term you enter and nothing for one you leave blank. · Leave blank to show nothing. · Enter a whole number. · Enter a value between 2 and 10,00,000. |
| Photo | …A plain background reads best on the card. · That image is over 2MB. Compress it or choose a smaller one. | …A plain background works best on the card. · This image is over 2MB. Compress it or select a smaller one. |
| Service editor | Service name is required · Control how this service surfaces in discovery. · …are rolling out soon — they’ll appear here without any change… | Enter a service name. · Control how this service appears in discovery. · …are coming soon. They will appear here without any change… |
| Empty, locked and error titles (the lead's ruling; the owner's two empty headings keep their words) | No products listed yet · No services listed yet · No products match · No services match your filters · Your account isn't linked to a company · This page is for your company’s admins and sellers | No Products Listed Yet · No Services Listed Yet · No Products Match · No Services Match Your Filters · Your Account Isn't Linked to a Company · This Page Is for Your Company’s Admins and Sellers |
| Retry | Retry | Try Again |

Left as they were: the owner's 12 Nov sentences (subtitles, empty states, the services figures, "Recently Added",
"Search Services", "All Statuses"), apart from the two empty headings above; the pricing models ("per visit"…), units and the buyer-facing term lines
("1-year warranty", "Free delivery over ₹5,000", "Bulk pricing from 50 box"), which are stored or mirror the website's
product page; "Select", "Done", "Delete", "Cancel"; tooltips ("Dismiss", "Clear search", "Product actions").
