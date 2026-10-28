# Role test: VENDOR / SUPPLIER (27 Oct 2026)

The supplier side of the app, proved account by account against the local API (`docs/TEST_PLAN_ROLES.md`). Everything below is run by one file, `test/live/role_vendor_live_test.dart` (37 tests that run, 1 kept skipped for an open bug; about 5 minutes with the API shared; T18 ends skipped, with its reason, while the hour's budget of `POST /rfq/:id/conversation` is spent), plus 8 widget and unit tests added or strengthened in the rfq folder's own test files for the three bugs fixed.

```
flutter test --no-pub test/live/role_vendor_live_test.dart --concurrency=1
```

## The accounts

| Short name | Account | What it is |
|---|---|---|
| **Vivek** | `vendor@icr.test` | VENDOR of E2E Test Vendor Co, Gold, verified, unlimited bids, **no phone on file**. Password read from `irc-portal/e2e/fixtures/users.json` at run time; this file and the test hold none of it |
| **Vikram** | `vendor@icr.dev` | VENDOR of Bengaluru Care 101 (the inbox seed's seller), Gold, verified |
| **Bluepeak / Innova** | `rfq.bluedot@` / `rfq.innowork@rfq-design.icr.test` | the rfq seed's Gold suppliers |
| **SecureNet** | `rfq.securetech@…` | verified, **free plan: 3 RFQ quotes a month** |
| **GreenShield** | `rfq.greenguard@…` | listing **not verified** |
| **Sunrise / Meridian** | `rfq.buyer@…` / `marketplace.buyer@marketplace-design.icr.test` | COMPANY_ADMIN of a company with **no supplier listing** |
| **Bharat** | `buyer@icr.dev` | a buyer with no company: not a supplier at all |

`tool/seed/marketplace.ts` gives its supplier companies **no owner logins** (only the two buyer personas), so "the owner sees their own listing" is proved with Vivek's and Vikram's own listings; the sandbox supplier (`design-mkt-v-sandbox`) is used for the bookmark. A VENDOR-role account with a company and no listing does not exist locally: that case is a COMPANY_ADMIN (Sunrise, Meridian), who gets the same gate. The buyer that posts what the suppliers answer is Sunrise.

## Result

| | |
|---|---|
| Matrix cells | 15 flows x 7 kinds of account; **0 cells broken** after the fixes, 2 carry an open bug |
| `works` / `refused correctly` | every cell the account can reach (table below) |
| Bugs fixed | **3** (each with tests that fail without the fix) |
| Bugs open | **3** (one is the lead's wiring; one cosmetic; one portal) |
| Gaps (website has it, the app has not) | **15** (list below) |

## Matrix: flow x account

`W` works, `R` refused correctly (the API's sentence, or the gate, is shown), `F` bug fixed, `O` bug open, `G` gap, `n/a` the account has no such thing. The letters after a cell name the tests (list at the end).

| Flow | Vivek | Vikram | Bluepeak, Innova | SecureNet | GreenShield | Sunrise, Meridian (no listing) | Bharat |
|---|---|---|---|---|---|---|---|
| **Access, plan, limits** (`/vendors/me/access`) | W T1 | W T1 | W T1 | W T1, P1 (3 a month) | R T1, P2 (cannot bid) | R T2, S2 (gate "Start selling") | R T2, S2 ("for supplier accounts") |
| **Find work: Recommended** | W T4, T5, S1 | W T4 | W T4 | W S2 | W S2 (an unverified listing may read) | R S2, S8 (gate) | R S2 |
| **Find work: All open, search, sort, Closing soon, Verified buyers, city, budget** | W T5, T6, S1 (**F** Verified buyers paging) | W T4 | W T4 | n/a | n/a | n/a | n/a |
| **Find work: Invited** | W T8 | n/a | W (`rfq_live_test`) | n/a | n/a | n/a | n/a |
| **Early-access release** | not testable live: the local plans release at once (a free supplier reads a just-posted requirement); the window's sentence is proved by widget tests with a fake | | | | | | |
| **Opportunity page** | W S1, S4, T7 | n/a | W S5, S10 | n/a | W S6 | R T2 (state "no listing") | R (`rfq_live_test`, "for supplier accounts") |
| **Place a bid, every field and file** | W T9 (price, lead time, 4,000-char message, two files, 120-char title), T11 (staged RFQ: pre-qualification, shortlist, priced quote, files, PO), S4 | n/a | W S5 (typed into the real form, file attached), T12 (largest valid reply: 12-digit price, 36,500 days, 4,000 chars, 10 files), T10 (Innova) | W P1 (a quote spends one) | R P2, S6 | R T2 | R T2 |
| **The rules of the DTO** | W T12: eight refusals the API gives (negative price, 4,001 chars, negative and fractional lead time, 11 files, 121-char title, blank title, nothing) are each said by the form first | | | | | | |
| **Edit / withdraw a bid** | **F** T9, T13, S4, W1-W4 (the portal has no call; the page now says so) | | **F** T13 | | | | |
| **My Bids: Submitted / Shortlisted / Won / Archived** | W T9 (all three moves), S3 (counts and cards match, every tab) | n/a | W T10 (Archived, Not selected) | n/a | n/a | R T2 (gate) | R |
| **Decline an invitation** | W T8, S7 (asks first, kept by the API, leaves Invited, goes to Archived) | n/a | W (`rfq_live_test`) | n/a | n/a | n/a | n/a |
| **Bid limits and plan gates, in the API's own words** | W T11 ("Your plan includes unlimited bids.") | | | W P1 ("0 of 3 bids used this month."; exhausting it: `rfq_live_test`) | R P2, S6 ("Your company must be verified to bid.", form keeps what was typed) | | |
| **Own listing: Marketplace and the supplier sheet** | W T19, T20, S14 (finds it by name, same profile as a buyer, 42 reviews anonymous, bookmark another supplier and take it back); **O 2** | n/a | n/a | n/a | n/a | n/a | n/a |
| **Enquiries and messages from buyers (company inbox, Sales topic)** | W T16, S13 | W T16, S13 (a thread opens "Replying as Bengaluru Care 101") | W T16, T17 (buyer message lands in Sales; answered as the company; Done and back to Open), T18 (a bid opens the thread), S13 | n/a | n/a | n/a | n/a |
| **Notifications: new requirement, invitation, shortlisted, quotes open, awarded, not selected** | W T14, T11 (prequal result, shortlisted, quotes open, awarded: each names the supplier page; quotes open lands on the quote form), S12 | W T14 | W T14, T15, S10, S11 (a tap on each opens the supplier page; Alerts screen likewise) | n/a | n/a | n/a | n/a |
| **No listing: what the app shows, and "Start selling"** | n/a | n/a | n/a | n/a | n/a | W S2, S8, S9: the gate says "Start selling to find work" with a button; one call makes the listing from the company profile, the gate lifts, staff take it away again. **O 1**: no door to these screens | R |

## Bugs fixed

1. **"Verified buyers" hid requirements.** The API applies `verifiedBuyer` after it has cut the page, so a page of 20 can come back with 3 rows (or none) while more wait behind it. The board took a short page for the last page, so with the chip on it stopped early, and when every buyer on the first page was unverified it said "No requirements match" over a board that had verified buyers on page two. `SupplierBoardController` now asks for whole pages without the filter, keeps the verified buyers itself, walks on (up to five pages) until a screenful is gathered, and decides "more" from the API's pages. Tests that fail without it: `test/rfq_board_test.dart` "Verified buyers, where the API filters after it has cut the page" (2). Live: `paging the open board in small pages` (parity with one big read, with and without the chip).
2. **Two buttons that were missing without a word.** The portal has no `PATCH|DELETE /rfq/:id/bids/mine` (checked: `rfq.controller.ts`; `PATCH /rfq/:id/bids/:bidId` is the buyer's triage and answers a supplier 403), so "Edit bid" and "Withdraw" are not drawn, and the sent-reply card said nothing. A bid still being weighed on a live requirement now reads "A sent reply cannot be changed or withdrawn on ICR yet. To correct it, message the buyer." (`bid-changes-note`, `OpportunityController.bidChangesNeedBuyer`); a settled bid or a closed requirement shows no line. Tests that fail without it: `test/rfq_opportunity_test.dart` (2 added and 2 strengthened: the note, no excuse where changes are supported, no promise on a closed requirement, the controller rule) and live `a requirement Vivek answered is read back by its page`.

3. **Alerts hid a supplier's older requirement notices.** `GET /notifications` filters by read state only, and the Alerts list (and the Marketplace chip's "n new") read the latest 100 notices of any kind and kept the requirement ones. A supplier is told about every requirement that matches, so a busy one (Bluepeak holds well over a hundred after the live runs) loses an invitation or an award a few days old behind newer promotions and matches; the Alerts screen showed none. `ApiRfqRepository.alerts` now reads on, a hundred at a time, until the API says there is no next page or five pages are read. Tests that fail without it: `test/rfq_alerts_test.dart` "a supplier who holds hundreds of notices" (2). It also repaired `rfq_live_test` "the supplier's alerts open the supplier's page", which had started failing because the vendor runs pushed Bluepeak's seeded alerts past the latest 100.

## Bugs open

1. **Find work and My Bids have no door.** `pushBoard` and `pushMyBids` are called only from inside `lib/features/rfq` (the board's chip, an empty My Bids tab, an Opportunity page's "See all your bids"). Nothing in the shell, the Discover sheet or the profile drawer opens them, so a supplier with no notification to follow cannot reach the board at all, and the Discover "Sell" door opens *Create a company* even for a company that already sells. Lead-owned files; the diff is in the report and in this file's last section. The skipped test `Open bugs, kept visible` flips to a pass when `/manage/bids` and `/manage/bids/mine` are in `inAppScreens`.
2. **The owner's own profile offers what the API refuses** (cosmetic, honest): *Rate this supplier*, *Request for Quote (RFQ)* and the message icon are drawn on a listing the viewer owns. Each is refused in the API's words (`You cannot rate your own listing.`, `This is your own listing.`, and for the quote `No valid companies to invite.`, the cryptic one), and what was typed stays. Hiding them needs the viewer's company in the sheet (`GET /vendors/:id` carries no `isOwner`): `docs/backend-requests/marketplace.md` item 5.
3. **Portal: a bid of 1,000,000,000,000 or more is a 500** (`Quote.totalAmount` is `Decimal(14,2)` and the DTO has no `@Max`). The app never sends it (its form stops at 999,999,999,999, which the live test stores). `docs/backend-requests/rfq.md` item 2.

## Gaps: what the website's seller workspace offers and the app has no screen for

Website routes, from `frontend/src/lib/nav.ts` / `personas.ts` (the VENDOR "Company" workspace):

1. **Dashboard** `/dashboard` (stats strip, bids and open-requirement tables, charts, tasks, profile strength, plan lock notices)
2. **My Company** `/company`: identity, listing details, offices (`/manage/locations`), the company check and the supplier levels (`/company?tab=verification`), certifications tab
3. **My Products** `/manage/products`
4. **My Services** `/manage/services`
5. **My Locations** `/manage/locations`
6. **My Certifications** `/manage/certifications`
7. **Team** `/manage/team` (join requests, invites, inbox topics; the `team_join_request` notice falls to the website)
8. **Verification levels and their request** (`RequestVerificationCard`, `/company?tab=verification`)
9. **Plans and membership**: `/pricing/supplier`, `/membership`, `/membership/history`, referral credits (the app's "See plans" opens the website)
10. **Advertise** `/advertise` (paid placements; the `promotion` notice falls to the website)
11. **Buyer Directory** `/buyers` (supplier-only)
12. **Browse RFQs / Tenders** `/rfq`, `/tenders` (the app has the open board instead)
13. **Operations**: CRM `/crm`, Payments `/payments`, Marketing `/marketing`, CMS `/cms`
14. **Reports and integrations** `/manage/reports`, `/manage/integrations`
15. **The supplier's own storefront editing** (headline, description, hubs, services as buyers see them): only reading exists in the app

Editing or withdrawing a sent reply is not on this list: the website has no such control either (a portal gap, above).

"Start selling" **does exist** in the app: on Find work, My Bids and every Opportunity page of a company with no listing (`POST /vendors`, tested live). What does not exist is a route to those screens (open bug 1) and a "Sell" door that points at them.

## What the tests leave behind (and why)

- A bid opens a thread between the supplier and the buyer's company, and a conversation outlives its requirement; notifications cannot be deleted. The requirements the tests post are filed under Landscape, which none of the personas serve, so a run adds notices to Bluepeak's, Innova's and Vivek's bells only in the two tests that are about being told (`enquiry_match`, `rfq_invite`, `bid_awarded`, `bid_rejected`). Bluepeak's and the other seed suppliers' rows are swept by `tool/seed/rfq.ts`. **Vivek's** company inbox (`E2E Test Vendor Co`, the portal's e2e vendor) keeps the threads titled `zz live vendor …` (3 per full run, empty or withdrawn); `tearDownAll` puts them in *Done*, out of his Open view. Vivek's bell holds the read `enquiry_match`/`bid_awarded`/invitation rows of the runs.
- Starting to sell for Meridian is undone with the staff delete (`DELETE /vendors/:id`, a soft delete the next "Start selling" revives). The test skips (never deletes) if Meridian already sells, because other roles' runs use the same account.
- Requirements are posted by Sunrise and deleted by the test (bids, invitations and responses go with them). Uploads stay in `uploads/` (private `bid-attachment` files).

## Throttles to know about

- `POST /rfq/:id/conversation` ("Message the buyer"; the buyer's "Message" on a bid) is capped at **30 an hour per client address, shared by every role's run**. The limiter counts IPv4 and IPv6 callers apart (`curl -4` and `curl -6` show separate `X-RateLimit-Remaining`). This file makes one call a run (T18) and waits 25 s at most, then ends skipped with the reason; `rfq_live_test` "a thread is opened with a bidder…" makes three and has no such guard: while the budget is spent its client waits out the 429 and the test times out at 2 minutes (it did at the end of this pass: the route answered 429, `Retry-After` about 3,000 s, for 127.0.0.1 while the IPv6 key still had room, and a few of the calls that spent it were this pass's own probes). It passes again when the hour's window resets. Read `X-RateLimit-Remaining` on that route before a full pass of every role.
- Sign-ins (30 a minute) and 120 requests a minute are shared too; `liveClient` waits and retries, which is why a busy machine makes a test slow rather than red.

## Could not be tested, and why

- **Early-access release** live (above).
- **Exhausting the free plan's quotes** in this file: it costs four staged RFQs a run; `test/live/rfq_live_test.dart` does it ("the free plan's monthly quotes run out…") and this file proves the allowance line and one quote spent.
- **A tap on a Vivek notice** (it would read his notices, which nothing can unread); the taps run as Bluepeak, Vivek's notices are parsed and routed.
- **A VENDOR-role account with no listing**: none exists locally.
- **Rating another supplier as a vendor**: a rating cannot be deleted; the sandbox supplier is rated by the Marketplace's own live tests, and a supplier's rating takes the same code path as a buyer's.

## Notes for whoever reruns it

- In a widget test, a request the screen made while the test clock is faked can leave that client's connection stuck for the next real read (20 s receive timeout). The file reads back through another client (the buyer's, or a fresh sign-in) after a screen has written, and waits for content with `pumpUntilFound` rather than trusting `settleLive`, which takes the moment between a screen's two reads for the end.
- A screen swapped for another of the same type keeps its state: every `pumpLive` here gives its screen a `UniqueKey`.

## The tests

Live and screen tests, all in `test/live/role_vendor_live_test.dart`:

| ID | Test |
|---|---|
| T1 | the supplier accounts have a listing, are verified and bid; the plans differ as seeded |
| T2 | an account with no supplier listing is told so by the gate, with the way in; a buyer is told it is not a supplier |
| T3 | a supplier's company can post: the composer opens on the company's name and a list of their own requirements loads |
| T4 | Recommended is the matched part of All open, best match first; both parse for every supplier account |
| T5 | search, sort, Closing soon, Verified buyers, city and budget keep to what they say |
| T6 | paging the open board in small pages, with or without "Verified buyers", reaches the same rows as one big read |
| T7 | a requirement posted for suppliers reaches Recommended for the one whose services match, and the page reads it |
| T8 | Invited: a private enquiry reaches only the invited supplier, waiting ones lead, a declined one leaves the tab |
| T9 | an enquiry reply with price, lead time, a 4,000-character message and two files is kept as sent, private to its two sides, and travels Submitted, Shortlisted, Won |
| T10 | the other bidder on that enquiry is told it was not chosen: Not selected, in Archived |
| T11 | an RFQ is answered in stages: pre-qualification, shortlist, then a priced quote with files that wins a purchase order |
| T12 | every refusal the API gives is said by the form before it is sent, and the largest valid reply goes through |
| T13 | the portal has no call to change or withdraw a bid, and a supplier cannot triage or award their own |
| T14 | every notice a supplier holds names a page the app can read, and the requirement ones name their supplier page |
| T15 | a new requirement, a private quote request and the buyer's choice each reach the supplier, and opening the page reads them |
| T16 | every supplier account answers for its company inbox, which takes Sales and Procurement |
| T17 | a buyer's message to a supplier lands in its sales inbox; the seller answers as the company and sorts the thread; the buyer reads the answer |
| T18 | a bid opens the requirement thread in the supplier's inbox, with the reply as its first word |
| T19 | the owner finds the listing by name and reads what any buyer reads; ratings carry no reviewer |
| T20 | a supplier bookmarks another supplier and takes it back; their own listing refuses a rating, a message and a quote in the API's words |
| T21 | a supplier asking another supplier for a quote with no mobile number on file is asked for one, in the API's words |
| S1 | Find work draws Vivek's board: tabs, the My Bids chip, real cards; a card opens its page; All open lists more |
| S2 | Find work for the others: a free plan shows its allowance, an unverified listing is told so, an account with no listing is offered Start selling, a buyer is told it is for supplier accounts |
| S3 | My Bids draws every tab for Vivek: the counts and the cards match the controller |
| S4 | a requirement Vivek answered is read back by its page: price, lead time, message, files; and it says plainly that the bid cannot be changed here |
| S5 | a reply typed into the real form with a file goes to the API and is read back (Bluepeak) |
| S6 | an unverified supplier sees the API's refusal in the form, and the form keeps what was typed (GreenShield) |
| S7 | an invitation is read in the form, declined from the page, and the page keeps the decline (Vivek) |
| S8 | a company with no supplier listing is offered Start selling, with the sentence that says what it does (Meridian) |
| S9 | "Start selling" makes the company's listing from its profile in one call, the gate lifts, and staff take it away again (Meridian) |
| S10 | a supplier taps each requirement notice and is taken to that requirement's supplier page (Bluepeak) |
| S11 | Alerts draws a supplier's requirement alerts, and a tap opens the supplier's page of that requirement, never the buyer's (Bluepeak) |
| S12 | a notice with no page of its own in the app (an advertising placement, a team request) is read and left to the website (Vivek) |
| S13 | the company inbox of each supplier draws its views and topics, and a thread opens as the company |
| S14 | the owner opens their own listing as buyers see it; rating it is refused in the API's words and the sheet keeps the stars |
| P1 | the free plan counts its monthly quotes on the quote page, and a quote spends one (SecureNet) |
| P2 | an unverified listing is refused a reply in the API's words, which the form shows (GreenShield) |
| B1 | (skipped) a supplier can reach Find work and My Bids from the app: open bug 1 |

Widget tests added to the rfq folder's files, for the two fixes: `test/rfq_board_test.dart` "Verified buyers, where the API filters after it has cut the page" (W5, W6) and `test/rfq_opportunity_test.dart` "where the API has no call to change a bid the buttons are not drawn, and the page says why", "where a bid can be changed the page offers the buttons and no excuse", "a requirement that has closed takes no changes, and does not promise a way to make them", "with no API call to change a bid, only a bid still being weighed is sent to the buyer" (W1-W4). All 214 rfq widget tests and the rfq goldens pass.

## The diff the lead must apply (lead-owned files)

`lib/app_screens.dart`. Imports: `core/auth/auth_controller.dart`, `features/rfq/open_requirements_screen.dart`, `features/rfq/my_bids_screen.dart`. At top level, beside `appRfqHooks`:

```dart
/// Find work: the supplier's open board. `pushBoard`/`pushMyBids` were called only from inside the rfq folder, so a
/// supplier with no notification to follow had no way to it.
Widget findWorkScreen(BuildContext ctx) {
  final hooks = appRfqHooks(ctx);
  return OpenRequirementsScreen(
    repository: hooks.repository,
    links: hooks.links,
    onOpenConversation: hooks.onOpenConversation,
    onOpenSupplier: hooks.onOpenSupplier,
  );
}
```

In `inAppScreens(...)`, beside `'/manage/requirements'`; the third entry **replaces** the existing `'/account/companies/new?role=VENDOR'` one (the Discover "Sell" door):

```dart
    '/manage/bids': findWorkScreen,
    '/manage/bids/mine': (ctx) {
      final hooks = appRfqHooks(ctx);
      return MyBidsScreen(
        repository: hooks.repository,
        links: hooks.links,
        onOpenConversation: hooks.onOpenConversation,
        onOpenSupplier: hooks.onOpenSupplier,
      );
    },
    '/account/companies/new?role=VENDOR': (ctx) {
      final role = ctx.read<AuthController>().user?.role;
      // A company that exists sells from Find work ("Start selling" is on that screen); only someone with no
      // company founds one first.
      final sells = role == 'VENDOR' || role == 'COMPANY_ADMIN' || role == 'SUPER_ADMIN';
      return sells ? findWorkScreen(ctx) : CreateCompanyScreen();
    },
```

`lib/features/profile/profile_drawer.dart`, under "MY ACTIVITY" after "My RFQ Requirements", shown when `context.read<AuthController>().user?.role` is VENDOR, COMPANY_ADMIN or SUPER_ADMIN:

```dart
const SizedBox(height: 2),
_ActivityLink(
  icon: const Icon(LucideIcons.gavel, size: 14, color: AppColors.slate500),
  label: 'Find Work & Bid',
  onTap: () => _open('/manage/bids'),
),
const SizedBox(height: 2),
_ActivityLink(
  icon: const Icon(LucideIcons.send, size: 14, color: AppColors.slate500),
  label: 'My Bids',
  onTap: () => _open('/manage/bids/mine'),
),
```

With those in, the skipped test `Open bugs, kept visible` loses its `skip:` and passes. No change is needed to `lib/core`, the shell or `pubspec.yaml`.
