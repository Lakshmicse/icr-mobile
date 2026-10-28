# Requirements (RFQ): screens, flows and status

Owner: the requirements builder. Folder: `lib/features/rfq/**`. The Marketplace design's chips "Post RFQ", "My RFQ's (3)" and "Alerts (2 new)" open these screens. There is no design for the screens themselves: they are built in the language of the Marketplace, Supplier Overview and Jobs designs (Work Sans headings, IBM Plex Sans body, slate ink, 12-radius hairline cards, pill chips). Pixel matching is postponed by the owner's call; the four list screens have recorded goldens (`test/golden/rfq_golden_test.dart`, green) and nothing more was done to them.

## Status

| Screen | File | Widget tests | Live tests |
|---|---|---|---|
| Alerts | `rfq_alerts_screen.dart` | 9 (`test/rfq_alerts_test.dart`) | reading + marking read |
| My RFQ's | `my_rfqs_screen.dart` | 27 (`test/rfq_my_rfqs_test.dart`) | reading + the write flows below |
| Post RFQ (composer) | `post_rfq_screen.dart` | 49 (`test/rfq_post_test.dart`) | post, draft, edit, files, no-company refusal |
| Requirement (buyer's page) | `rfq_detail_screen.dart` | 46 (`test/rfq_detail_test.dart`) | triage, award, PO, thread, invites, close |
| Open requirements (supplier board, "Find work") | `open_requirements_screen.dart` | 22 (`test/rfq_board_test.dart`) | reading |
| Opportunity (supplier's page, reply / bid) | `opportunity_screen.dart` | 43 (`test/rfq_opportunity_test.dart`) | reply, plan gate, pre-qualification, decline |
| My Bids | `my_bids_screen.dart` | 13 (`test/rfq_my_bids_test.dart`) | reading |

Totals: 209 widget tests, 4 golden tests, 45 live tests (`test/live/rfq_live_test.dart`, 29 reading + 16 writing). `flutter analyze --no-pub lib/features/rfq` and every rfq test file are clean. Every live write is undone: each requirement the tests post is deleted in `addTearDown` (which takes its bids, invitations and responses with it); a check after the last run found 0 leftover requirements and 0 leftover bids.

Not drawn, because the API has no call for it: **edit or withdraw a placed bid** (see "Backend request" below). Everything else in the brief is built.

## What each control does, and the test that proves it

### Alerts

| Control | Does | Proved by |
|---|---|---|
| Back arrow | pops (or `onBack`) | `the arrow goes back` |
| Bell | reads the alerts again (or `onBell`) | same call as pull to refresh |
| All / Unread pills | filters the list; Unread carries the count of new alerts | `the Unread tab keeps...` |
| Mark all read | marks every unread alert read; any the API refuses go back to unread and the API's sentence is shown | `an alert the API refuses...` |
| An alert | marks it read, then opens the owner page for an alert about the buyer's requirement, the supplier page for a supplier's, with the section and the bid it names (`RfqAlert.section`, `bidId`) | `a tap reads the alert...`, `a tap on an invitation...`; live: `an alert about the bid reaches the buyer, names its bid...` |
| Pull down, failed load, empty | as the other lists | `pulling the list down...`, `a failed load says so...`, `the Unread tab keeps...` |

The API filters notifications by read state only, so the screen reads them a hundred at a time, newest first, until the API has no next page or five pages are read, and keeps those about requirements (`RfqAlert.isAbout`); a supplier is told about every requirement that matches, and one page hid an invitation behind newer notices of other kinds (27 Oct, vendor role pass). There is no "mark unread" in the API.

### My RFQ's

27 widget tests: views (Live / Drafts / Awarded / Closed with counts), search, status filter, a card opens the buyer's page, Post RFQ, the account with no company is offered `onCreateCompany`, paging, pull down, failed load, empty states. Live: `an enquiry posted through the composer's controller reads back as it was typed` (the row and `summary()` counts), `a draft is saved, edited ... and published`.

### Post RFQ (the composer)

One scrolling form with a review step. Every rule below is the API's own (`CreateRfqDto`), held in `rfq_rules.dart` (`RequirementDraft`, `RfqLimits`), so the form refuses what the API would.

| Control | Does | Proved by |
|---|---|---|
| Kind: Enquiry / RFQ | RFQ adds criteria and the two deadlines; switching keeps what was typed | `opens on an enquiry...`, `choosing RFQ adds its criteria...` |
| Company and contact | filled from the account; phone shape and name length checked | `a phone of the wrong shape and a long contact name are refused...` |
| Places | type-ahead on `GET /locations/search`; a tap adds a place with its state and country; the typed text can be added as it stands; a cross removes; at most 10; a failed search says so and still lets the typed name in. Places in two countries send no single country or state | `a search finds places...`, `what was typed can be added...`, `a failed search says so...`, `at most ten places`, `places in two countries...` |
| Category, sub-category, specialisation | each opens the next level | `a category opens its sub-categories...` |
| Title | follows the service until the buyer types their own | `the title follows the service...` |
| Description + checklist | the checklist ticks what the text already says and adds a labelled line for the rest; a prompt nobody answered is not sent; the 20-character minimum is shown with the count | `the checklist ticks...`, `a prompt line nobody answered...`, `too short a description...` |
| Budget | a rupee amount | `a budget is a rupee amount` |
| Items | add / change / remove in a sheet; a nameless item or a non-whole quantity is refused in the sheet | `an item is added, changed and removed`, `a nameless item and a quantity...` |
| Files | picked, uploaded at once (`POST /uploads?purpose=rfq-attachment`, public), each with a title; wrong type and over 10 MB turned away with the reason before any trip; a refused upload stays with its sentence and Retry; a bin removes; at most 10; the post waits while one is going up; sent as titled uploads | `a file goes up as it is chosen...`, `the title is the buyer's own words...`, `a wrong type and a file over 10 MB...`, `a refused upload stays...`, `a file is removed...`, `the files are sent with the post...`, `while a file is still going up the post waits`; live: `files: a requirement's is public...` |
| RFQ criteria | years in business (>= 1, whole), turnover, compliance items toggle; counted when closed | `its criteria open, are counted...`, `the last 3 years cannot be less than one year...` |
| Deadlines | picked from the calendar (a day means the whole Indian day); the quote deadline must follow the pre-qualification one | `the two deadlines are picked from the calendar...`, `a complete RFQ is sent...` |
| Audience: Everyone / Invite only | invite-only needs suppliers (picked by name or suggested), goes out at once as a private requirement, never a draft; an RFQ offers no invite-only choice | `an invite-only enquiry needs suppliers...`, `a chosen supplier is taken off...`, `an invite-only enquiry goes out at once...`; live: `an invite-only enquiry is seen only by the invited...` |
| Review | lists what suppliers will read; Edit goes back to that section | `the review lists what suppliers will read...` |
| Post | sends as the API takes it and says how many suppliers it reached (`alertedNow`) | `confirming sends the enquiry...`; live: `an enquiry posted through the composer's controller...` |
| Save draft | held only to the fields' own limits; still refuses what the API refuses at any status | `Save draft sends it as a draft...`, `a draft still refuses...` |
| A refusal | shows the API's sentence, keeps everything typed, the next send goes through | `a refusal shows the API's own sentence...` |
| Edit a draft / a live requirement | starts from it; a draft offers Publish, a live one only Save changes and cannot change its kind; the file list is sent whole only when it changed | `editing a draft starts from it...`, `editing a live requirement...`, `a changed file list is sent whole...`; live: `a draft is saved, edited ... and published` |
| Post a similar one | starts from the old one with its dates and files left out | `"Post a similar requirement" starts from the old one...` |
| Leave | a form with something typed asks first; Keep editing stays; Leave pops with no result; an untouched form goes straight back | `a form with something typed asks first...`, `Leave goes back with no result...` |
| After a post | "View requirement" opens it in place of the composer; "Post another" is a blank form of the same kind | `"View requirement" opens it...`, `"Post another" is a blank form...` |
| Account with no company | told so before the form, with `onCreateCompany` (else the website's `/account/companies/new`); a failed load says so with Try again | `an account with no company is told so...`, `with no callback wired...`, `a failed load says so...`; live: `a person with no company reads and manages requirements but is refused posting...` |

The app is stricter than the website in one place: every place must name its state and country, because `locations`, `state` and `country` are derived from `serviceLocations`. A facility type retired from the list (Corporate Offices) is still accepted on an older requirement (`legacyFacilityTypes`).

### Requirement (the buyer's page)

Tabs: Bids (or Responses on a staged RFQ), Suppliers (enquiries; a staged RFQ chooses suppliers by screening instead), Messages, Brief.

| Control | Does | Proved by |
|---|---|---|
| Header | status, stage, counts; a link opened with `focusBid` rings that bid and opens on the bids, `section=invited` opens the suppliers | `says where it stands...`, `a bid in the link is ringed...`, `section=invited opens the suppliers` |
| Bids list | shortlisted first, then by price; best price and top rating marked; reading it tells the API (`markSeen`) | `says where it stands, and lists the replies...`, `marks the best price...` |
| Sort | what the replies are weighed on | `the sort picks what the replies are weighed on` |
| Compare | lays live bids side by side, best in each row marked, a name opens that bid; declined bids left out; not offered for one bid | `Compare lays the live bids...`, `Compare leaves out a declined bid...` |
| Shortlist / Decline / Restore | shows at once, goes to the API, can be taken back; a refusal puts the bid back and shows the API's words | `Shortlist shows at once...`, `Decline and Restore`, `a refusal puts the bid back...`; live: `shortlist and decline are taken back, and what the buyer decided reads the same for the supplier` |
| Select (award) | asks first; Keep it changes nothing; confirming closes the enquiry with that supplier (others declined and told) or, for an RFQ, awards and says the purchase order; a refused award changes nothing | `Select asks first...`, `an RFQ is awarded, and the purchase order comes back...`, `a refused award changes nothing...`; live: `selecting a reply closes the enquiry for the others...`, `a staged RFQ runs from pre-qualification to a purchase order...` |
| Long message | cut, "Show more" reads it all | `a long message is cut...` |
| Message (a bid) | opens the thread through `onOpenConversation`; with no thread the API opens one naming the supplier's company; with no chat wired the website's inbox opens on it; a thread that cannot be opened says why | `Message on a bid that has a thread...`, `on a bid with no thread yet...`, `with no chat wired...`, `a thread that cannot be opened...`; live: `a thread is opened with a bidder, the supplier finds the same one...` |
| A bid's file | private upload: fetched with the session and handed to the phone (`share_plus`); one the phone cannot take or fetch is said so | `a bid's file is a private upload...`, `a file the phone cannot take...`; live: `files: ... a bid's is private to the buyer and its supplier` |
| Suppliers tab | who was invited and what they did, message them; "Invite companies" suggests the ones that fit (the invited are left out) or finds by name; a refusal stays in the sheet with the choice kept; a closed requirement offers none | `lists who was invited...`, `Invite companies suggests...`, `a supplier is found by name...`, `a closed requirement offers no invitations` |
| Messages tab | each supplier's thread with the last words and what is unread, opens in the chat | `each supplier's thread shows the last words...`, `a requirement nobody has written about says so` |
| Brief | the owner sees the brief with the contact; files open outside the app | `shows the brief to the owner...` |
| Close / Cancel / Publish / Delete draft | Close asks first and says it is closed; Cancel says it cannot be undone; a refused close puts the page back with the API's sentence; a draft offers Publish, Edit, Cancel and Delete (Delete asks, then leaves the page); a live one never Publish or Delete | `a live requirement offers Edit, Close, Cancel...`, `Close asks first...`, `Cancel says it cannot be undone...`, `a refused close puts the page back...`, `a draft offers Publish...`, `Delete draft asks first...`; live: `a draft is deleted for good, and a closed requirement is closed for suppliers` |
| Edit / Post a similar one | opens the composer (the page reads again when it comes back) | `Edit opens the composer on this requirement...`, `"Post a similar one" opens the composer...` |
| Staged RFQ | five stages shown, the button moves it on, a refused move shows the sentence; each pre-qualification response is read against the criteria with the unmet ones named; Qualify / Not qualified screen it (Shortlist waits for the shortlisting stage); a refused screening goes back | `shows its five stages...`, `a refused move shows the sentence...`, `each pre-qualification response is read against the criteria...`, `Qualify and Not qualified screen a response...`, `a refused screening goes back...`, `Message on a response opens the thread...` |
| Not the caller's | shows the brief and says so | `a requirement that is not the caller's shows the brief and says so` |
| Failed load, pull down, empty | as the other pages | `a failed load says so...`, `pulling the page down reads it again`, `an enquiry with no replies says so` |

### Find work (the open board)

| Control | Does | Proved by |
|---|---|---|
| Tabs Recommended / All open / Invited | Recommended is `matchedOnly=true`; All open is every public requirement; Invited is `GET /rfq/invited` (declined left out, waiting ones first) with the number waiting on the tab | `Recommended lists...`, `All open adds...`, `Invited shows...` |
| Search box | `search=`; "Clear search and filters" in the empty state | `searching narrows...` |
| Sort chip | Best match, Newest, Closing soon, Highest budget | `Sort puts the highest budget first` |
| Closing soon | `closingInDays=7` on and off | `Closing soon keeps...` |
| Verified buyers | keeps the verified buyers' requirements. The API applies `verifiedBuyer` after it has cut the page (a page can come back short or empty with more behind it), so the board asks for whole pages without it, keeps the verified ones itself and walks on (up to five pages) until a screenful is gathered; "more" follows the API's pages, not the kept rows (27 Oct, vendor role pass) | `Verified buyers drops...`, `the verified buyers on later pages are found...`, `the chip shows them instead of "No requirements match"`; live: `paging the open board in small pages...` |
| Filters (n) | sheet: city and budget from/to validated as rupee amounts; the chip counts what is on; Clear | `Filters narrows...`, `Filters refuses...` |
| My Bids chip | opens My Bids with the count | `the My Bids chip opens...` |
| A card | opens the Opportunity page | `a card opens...` |
| Scroll to the end | next page until one comes back short | `more is read as...` |
| Not verified / plan limit | banner "not verified yet"; "2 of 5 quotes used this month" | `an unverified listing...`, `a plan with a limit...` |
| No listing / not a supplier | "Start selling" (`POST /vendors`) / "This is for supplier accounts" | `with no listing...`, `a buyer account...` |
| Early access | a requirement published inside the early-access window is released to plans in order; the board reads only what the API released | live reading group |
| Pull down, failed load, empty | each tab has its own empty sentence | `a failed load...`, `with nothing matched...` |

### Opportunity (the supplier's page)

The page reads `GET /rfq/:id`, `GET /rfq/:id/opportunity`, `GET /vendors/me/access` and the unread count. `ResponseState` picks the card: `form`, `sent`, `preQual`, `screening`, `evaluation`, `declined`, `closed`, `own`, `notSupplier`, `noListing`.

| Control | Does | Proved by |
|---|---|---|
| Header | names the buyer, how well the requirement fits and what the supplier can do | `names the buyer, how well the requirement fits...` |
| Back, bell, failed load, pull down, private/missing | as the other pages; a private or missing requirement is "not available" | `the arrow goes back and the bell opens the alerts`, `a failed load...`, `pulling the page down...`, `a private or missing requirement...` |
| Early-access window | shows the API's sentence and the way to the plans (`onSeePlans`, else the website's `/pricing/supplier`) | `the early-access window shows the API's sentence...`, `with no plans screen wired, "See plans" opens the website's pricing page` |
| Reply form | message, price, lead time; an empty reply is refused before it is sent; a price only or a message only is enough on an enquiry; price (above 0, at most the API's ceiling) and lead time (whole days) held to the API's rules; a quote on an RFQ needs a price | `an empty reply is refused...`, `a reply is sent as the API takes it and read back...`, `a reply with a price only is enough...`, `the price and lead time are held to the rules the API holds...`; live: `the board lists it, a supplier replies from the page's controller, and a second reply is refused` |
| Quote files | upload as `bid-attachment` (private) with a title; a file with no title is refused; a send waits while one is going up | `files go up as bid attachments...`, `a file with no title is refused...`; live: `files: ... a bid's is private...` |
| Plan gate | a used-up plan is said up front but the send still goes, so the **server's own sentence** shows in the form (`mentionsPlan` then offers "See plans"); an unverified listing is told so and the API's refusal is shown; a passed deadline is the API's refusal, shown in place | `a used-up plan is said up front, still lets the send go...`, `an unverified listing is told so...`, `a deadline that has passed...`; live: `the free plan's monthly quotes run out, and the refusal names the plan in the API's own words`, `who may not reply is refused in the API's words...` |
| No listing | "Start selling" in one tap, then the form; a verified company is told it can quote right away | `a company with no supplier listing starts selling...`, `a verified company with no listing...` |
| Not a supplier / own requirement | a buyer's account is told the page is for suppliers; a company's own requirement is not bid on: the page says so and opens it as its owner | `a buyer's account is told...`, `a company's own requirement is not bid on...` |
| Invitation | said at the top of the form; Decline asks first; a refused decline leaves the invitation open with the API's sentence; an ordinary requirement carries no invitation | `is said at the top of the form, and Decline asks first`, `a refused decline leaves the invitation open...`, `an ordinary requirement carries no invitation`; live: `an invite-only enquiry is seen only by the invited, who may decline it...` |
| Pre-qualification | an RFQ in pre-qualification asks for the criteria answers, validated as the API does; the card then says it is being screened; a refusal stays in the form | `an RFQ in pre-qualification asks for the criteria answers...`, `the answers go as the API takes them...`, `a refusal is shown in the form...`; live: the staged RFQ test |
| Quote stage | a shortlisted supplier at the quote stage is told so, needs a price and sees the allowance; stages show as a timeline with no owner button | `a shortlisted supplier at the quote stage...`, `the stages show to the supplier as a timeline...` |
| Your bid | read back with price, lead time, message and files; the bar says "View your reply"; "See all your bids" opens My Bids; a quotation file is opened through the session | `is read back with its price...`, `"See all your bids" opens My Bids`, `a quotation the supplier sent is opened through their session` |
| Edit bid / Withdraw | built (prefilled form, a refusal keeps the form as typed; Withdraw asks first and re-opens the form) but **drawn only where `supportsBidChanges` is true**; a closed requirement, an awarded, declined or past-deadline bid take no changes. Where the API has no call (today), a bid still being weighed shows the line "A sent reply cannot be changed or withdrawn on ICR yet. To correct it, message the buyer." (`bid-changes-note`, `OpportunityController.bidChangesNeedBuyer`, added 27 Oct by the vendor role pass) instead of two missing buttons; a settled bid or a closed requirement shows no line | `Edit bid opens the form with what was sent...`, `leaving an edit keeps the bid as it was`, `a refused change shows the API's sentence...`, `Withdraw asks first...`, `where the API has no call to change a bid the buttons are not drawn, and the page says why`, `where a bid can be changed the page offers the buttons and no excuse`, `a requirement that has closed takes no changes, and does not promise a way to make them`, `with no API call to change a bid, only a bid still being weighed is sent to the buyer`, `a requirement that has closed takes no changes`, `a bid awarded, declined or past its deadline cannot be changed`; live: `the portal has no call yet to change or withdraw a bid...` |
| Message the buyer | opens the thread through `onOpenConversation`; one that cannot be opened is said in the card | `Message the buyer opens the thread...`, `a thread that cannot be opened...`; live: the thread test |
| Buyer's contact | refused before a bid in the API's words, shown after; a plan that does not include it offers the plans | `the contact details are refused before a bid...`, `a plan that does not include the contact offers the plans` |
| Buyer's files | open in the phone's viewer (public uploads), not the website | `files of the buyer's open in the phone's viewer...` |

### My Bids

| Control | Does | Proved by |
|---|---|---|
| Tabs Submitted / Shortlisted / Won / Archived | each bid is on exactly one (a pending bid on a closed requirement is Archived; a declined invitation too) | `opens on Submitted...`; live: `shortlist and decline are taken back...` |
| A card, "View requirement" | opens the Opportunity page | `a card opens the requirement...` |
| "Message buyer" | `POST /rfq/:id/conversation`, then `onOpenConversation(threadId)` | `Message buyer opens the thread...` |
| "Find work" (empty Submitted) | opens the open board | `Find work from the empty...` |
| Not a supplier / no listing | "This is for supplier accounts" / "Start selling" | `a buyer account is told...`, `with no listing...` |
| Pull down, failed load | as above | `pulling down...`, `a failed load...` |
| Edit / withdraw | not drawn (API has no call) | n/a |

## Company roles that do not post (27 Oct, `docs/ROLE_TEST_company.md`)

An office admin, a recruiter and a hiring manager belong to a company, but the API's `POST|GET /rfq` roles are `BUYER`, `COMPANY_ADMIN`, `VENDOR` and staff, so every requirements call is a 403 "Insufficient role permissions" for them (and the supplier side too). `Poster.roleCannotPost` (a company, and a role outside that list) is what the screens read: **Post RFQ** shows "Requirements aren't part of your role" in place of the form (no Send, no draft), **My RFQ's** says the same with the company's name and no "Create a company page" button, and **the requirement page** (the brief still reads for them) says it is their company's and that its replies are for the company's admins and buyers. A person with no company keeps the older notices. Proved by `test/role_company_fixes_test.dart` and `test/live/role_company_*`. Two smaller fixes from the same pass: a passed deadline reads "Pre-qual closed 8 days ago" (it said "closes closed"), and the service picker says "Loading the list of services..." until the list is in (it said "could not load" while loading).

## Handoffs kept

| Thing | Where it goes |
|---|---|
| A requirement's files (public `rfq-attachment` uploads) | the phone's viewer, via `RfqLinks.openUri` |
| A bid's files (private `bid-attachment`) | fetched with the bearer token, saved, and handed to the phone's share sheet (`RfqLinks.shareFile`, `share_plus`) |
| Picking files | `RfqLinks.pickFiles` (`file_picker` 13.2) |
| A thread | `onOpenConversation(id)`; fallback the website's `/messaging?c=<id>` |
| A supplier's profile | `onOpenSupplier(vendorId)`; fallback `/vendors/<id>` |
| Founding a company | `onCreateCompany`; fallback `/account/companies/new` |
| The supplier plans | `onSeePlans`; fallback `/pricing/supplier` |

## Wiring (for the lead)

`rfq_navigation.dart` is the one place screens open each other. Signatures kept: `rfq_navigation.dart` and `rfq_scope.dart` (the Marketplace chips "Post RFQ", "My RFQ's (n)", "Alerts (n new)" need nothing else).

Build the hooks once:

```dart
final hooks = rfqHooksFor(
  context,
  onOpenConversation: (threadId) => ...,   // the app's chat on that thread
  onOpenSupplier: (vendorId) => ...,       // the supplier's profile
  onCreateCompany: () => ...,              // the account screens' "create a company"
  onSeePlans: () => ...,                   // the supplier plans
);
```

`RfqHooks(repository, links, onOpenConversation, onOpenSupplier, onCreateCompany, onSeePlans)`; the repository defaults to `rfqRepositoryOf(context)` (a `Provider<RfqRepository?>` above, else an `ApiRfqRepository` per `ApiClient`, else the demo repository when `AppConfig.demo`).

| Chip / path | Call |
|---|---|
| Post RFQ | `pushComposer(context, hooks, {editId, copyFromId, kind})` (answers a `PostResult?`) |
| My RFQ's (3) | `pushMyRfqs(context, hooks)`; the count comes from `readRfqCounts(context)` |
| Alerts (2 new) | `pushAlerts(context, hooks)`; the count from the same call |
| Supplier's board | `pushBoard(context, hooks)` |
| Supplier's bids | `pushMyBids(context, hooks)` |
| A notification about a requirement | `pushRfqDetail(context, hooks, id, {section, focusBid})` (owner) or `pushOpportunity(context, hooks, id, {section})` (supplier); `RfqAlert.side` says which |

Every screen widget also takes the same optional constructor arguments (`repository`, `links`, `onBack`, `onBell`, `onOpenConversation`, `onOpenSupplier`, and `onCreateCompany` / `onSeePlans` where they apply).

## Backend request

`docs/backend-requests/rfq.md` section 1: `PATCH|DELETE /rfq/:id/bids/mine` so a supplier can change or take back a placed bid. The app side is already built behind `RfqRepository.supportsBidChanges` (`ApiRfqRepository` defaults to false). When the portal ships the calls, change the one line that builds the repository to `ApiRfqRepository(api: ..., supportsBidChanges: true)`; the Edit bid and Withdraw buttons appear on the Opportunity page's "Your bid" card, and the live test `the portal has no call yet...` will say the calls now answer 200 (flip its expectations then).

Found while testing live: `GET /rfq/:id` does not carry the caller's `inviteStatus` (only `GET /rfq/invited` does), so a private requirement's page reads the invitation list once to know whether the supplier declined. No change needed in the portal.

## Seed and personas

`tool/seed/rfq.ts` (run from `E:\ICR\irc-portal\backend`, local database only):

```
NODE_PATH=E:/ICR/irc-portal/node_modules npx ts-node --transpile-only E:/ICR/icr-mobile/tool/seed/rfq.ts
... same with --remove      (deletes what it created and what the live tests left)
```

Password for every persona below: `Rfq@12345`. Markers: ids start `design-rfq-`, emails end `@rfq-design.icr.test`.

| Persona | Who | Use |
|---|---|---|
| `buyer@icr.dev` | Bharat Buyer, no company | the emulator's person; reads and manages 5 requirements, cannot post |
| `rfq.buyer@` | Bhavya Buyer, admin of Sunrise Facilities Pvt Ltd | the persona the live tests post, triage and award as (11 requirements) |
| `rfq.bluedot@` | Bluepeak Security, VERIFIED, Gold | main supplier persona |
| `rfq.innowork@` | Innova Facility Services, CERTIFIED, Gold | second bidder |
| `rfq.securetech@` | SecureNet Systems, VERIFIED, free plan (3 RFQ quotes a month) | the plan-gate persona |
| `rfq.greenguard@` | GreenShield Services, REGISTERED | not verified: the API refuses its bids |

`tool/seed/run.ps1` and `tool/seed/README.md` (the lead's files) do not list `rfq.ts` yet.

## Left

- Edit / withdraw a bid goes live when the portal ships the two endpoints above.
- A quote-request sheet for supplier pages (`QuoteRequest`, `QuoteTarget`): the controller exists, there is no screen.
- Goldens and pixel matching for the screens built in this run (composer, buyer's page, opportunity page) are postponed by the owner's call.
