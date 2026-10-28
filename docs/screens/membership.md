# Membership (the plans)

The website's plans pages — `/pricing/<audience>`, `/career/plans`, `/membership`, `/membership/history` — as one screen in the app, so a "See plans" in Learning, a mentor profile, an application or a requirement, and a membership notification, never leave the app. Code: `lib/features/membership/`. Tests: `test/membership_test.dart` (models, controller, every control of the screen over a fake repository).

**No design exists for this screen.** It is drawn in the language of the designed ones (Work Sans titles, IBM Plex Sans body, the `TitleBar` with back arrow and bell, 12 dp cards with a hairline edge, the pill chips), like the notifications screen.

## What is built

- **`MembershipScreen({audience, onBack, repository, controller})`** — title bar "Membership" (back, bell with the app-wide unread dot), a row of chips, one per ladder in the website's order (Professional, Mentor, Market Place, Job Portal, Learning, Partner Institution — `MembershipAudience`, the app's copy of `MEMBERSHIP_AUDIENCE_META`: label, slug, tagline, description), the ladder's tagline and line, then:
  - **Your plan** (`membership-your-plan`): the plan held or "Free", when it ends ("Ends 11 Mar 2027"; "Renews" only once auto-renew exists), a paid next term, a change scheduled for the renewal, a retired plan, a price that changed since it was bought; **Renew for ₹…** (today's price, from the API's `renewal` quote) and **Plan history & receipts**.
  - A **card per plan** on sale (`plan-<id>`): name, "YOURS" on the one held (the free rung when nothing is), the price as the website words it — the annual term's price with "/year + GST", a struck-through compare-at price, "From ₹…" on a plan sold by conversation, "Custom pricing" with no price at all, "Price valid till" / "Available until" when staff set an end — the description, then **what the plan includes**, every line from the plan's own `benefits` (`PlanBenefitValueDto`: only `shown` ones; service terms such as an account manager listed apart under SERVICE TERMS with a handshake glyph). Nothing on a card is typed into the app.
  - The card's button (`plan-choose-<id>`): **Choose <plan>** (starts the checkout), **Current plan** / **Free** (quiet, disabled), **Talk to us** on a plan sold by conversation (the app's contact form, topic Membership, subject "<Ladder> <Plan> plan" — the website's `talkToUsHref`). A member who cannot buy on a ladder (no company, not an approved mentor…) reads the API's `reason` in a notice and gets no buttons.
  - States: loading boxes, "Couldn't load the plans" with Try again, "No plans on sale yet".
- **Choosing a plan** (`MembershipController.choose` → `POST /subscriptions/checkout { priceId }`):
  - `devActivated` (test mode, ₹0): "You're on <plan>." and the plan is marked at once (`/subscriptions/me` is read again).
  - a gateway form (`action` + `fields`): the app has no gateway leg, so the payment **continues on the website's plans page** for that ladder (`openUrl(…, inApp: false)`, never the app's own screen for it) and the notice says so. See the API gap below.
  - a refusal (a term already paid for, a plan that must wait for the renewal, 503 with no PayU on the server): the API's sentence, in the notice, the card unchanged.
- **`MembershipHistoryScreen({audience, repository})`** (`/membership/history?audience=`): the member's terms newest first — plan, "Running" or why it stopped (Renewed, Changed plan, Cancelled, Ended), the dates, the amount ("Complimentary", "Free", or ₹). Receipts are not fetched (the website prints them).
- **Not built, on purpose:** switching at renewal (`schedule-change`), stopping reminders (`cancel`/`resume`), auto-renew, coupons and custom offers (`/pricing/offer/<code>`), receipts. The API refuses the cases that need them with a sentence the screen shows.

## Where it opens from

Every hand-off to the website goes through `openUrl` (`core/util/links.dart`) or a feature's `openUri` (jobs, marketplace, requirements), and each asks `SiteRoutes.resolver` first — set once in `lib/app.dart` to `inAppSiteRoute` (`lib/app_screens.dart`). So:

| Website page | Opens |
| --- | --- |
| `/pricing`, `/pricing/<slug>`, `/career/plans`, `/membership` | `MembershipScreen` on that ladder (`MembershipAudience.fromSitePath`) |
| `/membership/history?audience=` | `MembershipHistoryScreen` |
| `/notifications` | the app's notifications |
| `/chapters`, `/councils`, `/events`, `/documents`, `/profile`, `/career/saved`, … | the screen the Discover doors and the profile menu already had (`inAppScreens`) |
| anything else | the browser, as before |

Nothing at the call sites changed: the Learning locks (`plansLink()` in `learning_assess`/`learning_study`, the exam brief's "See the … plan"), the mentor profile's "See Plans", the application timeline's and quota's "See plans" (`JobLinks.openSite('/career/plans')`), a requirement's "See plans" (`/pricing/supplier`) all reach the screen through the resolver. The notification router registers `membership.plans` and `membership.history` openers too (`?audience=`, or the slug). Tests leave the resolver unset, so a screen's own test still sees the website URL it asks for.

## Endpoints

| Call | Used for |
| --- | --- |
| `GET /subscriptions/catalogue?audience=` | the cards (`MembershipPlanDto`: prices, `benefits`, `contactSales`, `availableUntil`). Public. |
| `GET /subscriptions/me?audience=` | Your plan: the subscription held, `tier`, `renewal`, `nextTerm`, `scheduledChange`, `planRetired` |
| `GET /subscriptions/me/all` | `canBuy` and `reason` for the ladder (a failed read leaves "may buy": the checkout's own refusal then says why) |
| `GET /subscriptions/me/history?audience=` | the history screen (`MembershipHistoryDto.terms`) |
| `POST /subscriptions/checkout { priceId }` | Choose and Renew (`MembershipCheckoutDto`: `devActivated`, or `action` + `fields`) |

`FEED_SOURCE=demo` uses `DemoMembershipRepository`: four plans a ladder, Silver held on Professional, every checkout activated on the spot.

## API gap (for the lead)

`POST /subscriptions/checkout` answers a PayU **form** (`action`, `fields`) meant for a browser to POST. A phone cannot be handed a POST from a URL, so a gateway checkout started in the app is finished on the website's plans page. A `GET /subscriptions/pay/:subscriptionId` that renders and auto-submits that form (or a hosted-page URL from PayU) would let the app open the phone's browser straight at the gateway and return through `in.org.icr://`. Written up in `docs/backend-requests/membership.md`.
