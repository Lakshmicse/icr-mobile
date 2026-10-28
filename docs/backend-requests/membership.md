# Backend request: a GET that opens a membership checkout's gateway page

**From:** the Membership screen (`lib/features/membership/`, `docs/screens/membership.md`).

## What the app does today

`POST /subscriptions/checkout { priceId }` answers either `devActivated: true` (the term is live: test mode, ₹0) or the gateway's form — `action` (PayU's URL) and `fields` (the signed payload) — which the website posts from a hidden form (`postToGateway`). A phone's browser can only be sent to a URL, not handed a POST, so when the app gets a form it opens the website's plans page for that ladder in the browser and tells the member the payment continues there. The term row (`PENDING_PAYMENT`) the app's checkout created is re-used by the website's checkout within `MEMBERSHIP_CART_REUSE_MINUTES`, so nothing is lost — but the member pays on a page they did not start on.

## What would let the app finish the payment itself

One of:

1. **`GET /subscriptions/pay/:subscriptionId`** (bearer, the holder only): renders a minimal HTML page that auto-submits the same form (`action` + `fields`, computed fresh, as `reopenCart` does). The app opens it with `launchUrl`; PayU returns the browser to the existing `POST /subscriptions/payu/callback`, whose redirect could carry `?return=app` → `appReturnUrl` to `in.org.icr://membership?status=success|failure` (the social sign-in already uses that scheme, `MOBILE_AUTH_REDIRECT`).
2. Or, if PayU's hosted checkout can be opened by a signed GET URL for this merchant, return that URL as `paymentUrl` beside `action`/`fields`.

Additive either way: the website keeps posting the form. The app would then open `paymentUrl ?? /subscriptions/pay/:id` and read `?status=` on return to refresh `GET /subscriptions/me`.

## Also noticed

- `GET /subscriptions/me/all` is the only place `canBuy`/`reason` live; the per-ladder `GET /subscriptions/me` has neither, so the app reads both for one ladder. A `canBuy`/`reason` on `/me` would save a call.
