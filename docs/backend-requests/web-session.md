# Backend request: a web session for the app's in-app web view

**Why.** Pages of the website the app has no screen for open in an in-app web view (`docs/WEBSITE_HANDOFFS.md`). The website reads its session from `localStorage` (`icr.accessToken`, `icr.refreshToken`). The app can only hand the page its 15-minute ACCESS token: the API's refresh tokens are single use and rotated (`AuthService.refresh` revokes the one it is given), so a web view that held the app's refresh token would spend it and the app's next refresh would fail. The app therefore renews the page's access token itself every 9 minutes while the screen is open; a page left open longer, or a tab the person leaves in the background for a while, signs itself out at the first 401.

**Ask (additive, web responses unchanged).** `POST /auth/web-session` (signed in, access token in the header) returning a NEW refresh/access pair belonging to its own `RefreshToken` row (`tokenHash`, same `userId`, shorter `expiresAt`, e.g. 12 h, no "remember"), so the web view can renew itself without touching the app's family. Revoked on `POST /auth/logout` of the app session and when the person signs out of all devices.

**App side.** `WebSessionBridge.script()` would write both keys instead of removing the refresh one, and the 9-minute timer would go away.

Until then nothing is broken: the access-token-only session is what `docs/WEBSITE_HANDOFFS.md` describes.
