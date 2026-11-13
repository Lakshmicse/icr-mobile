# Sign in

Sign in, laid out as LinkedIn's own sign-in page is, in ICR's colours, in light and in dark. The join screens that follow it (Google or LinkedIn for someone new, and the three sign-up screens) still wear the card from the Sign in designs (`docs/designs/sign-in-light.png`, `sign-in-dark.png`).

**Owner's call, 28 Oct 2026:** "build me android sign in page as it is LinkedIn". This replaces the card layout the sign-in designs drew for this one screen; the card layout stays on the other auth screens.

## What it is

A plain page, no card: the ICR logo at the top left; **Sign In** (32, semibold) with "Stay connected with the CRE & FM community." under it; **Email Address** and **Password** as outlined fields whose label floats up to the border, with **Show** / **Hide** as a word inside the password field; **Forgot Password?** under the fields; **Remember Me**; one pill **Sign In** button; a hairline; **Sign In Using** over **LinkedIn** and **Google** as two outlined pills side by side, each the provider's mark (28 dp) and its name (they stack on a page under 280 dp wide, a 320 dp phone); and **New to ICR? Join Now** pinned to the bottom of the screen. The words are the client's (the marked-up manual, 13 Nov 2026; see the last section).

- **Light or dark follows the phone's own setting** (`LiColors.of(context)` reads `MediaQuery.platformBrightness`). Every colour is in `lib/features/auth/linkedin_style.dart`: a white page and a near-black ink in light, `#1B1F23` and a light ink in dark; the accent is ICR's blue (`#32629E`) for the pill and the focus ring, and links use a lighter tint of it in dark so they read. The logo swaps to `assets/images/brand/icr-logo-white.png` in dark.
- Built from `linkedin_style.dart` (`LiScaffold`, `LiTextField`, `LiShowButton`, `LiLink`, `LiPrimaryButton`, with colours in `LiColors` and type in `LiType`). "Remember Me" and the error line are the card screens' `AuthCheckbox` and `AuthErrorLine`; the providers are `SocialProvidersBlock` / `SocialPillButton` (`auth_widgets.dart`, shared with the join screen), coloured from `LiColors`.
- Everything is Work Sans: title 32, subtitle, labels and "Sign In Using" 16, input 17, links 16 semibold, buttons 17 semibold, a provider's name 16 semibold.
- Geometry (dp): 24 either side, 440 wide at most; fields 56 tall with a 6 radius and a 1 border (2 in the accent when focused); the pill the full width; the provider pills 52 tall, fully rounded, half the width each with 12 between.
- The label on the email field is "Email Address", not LinkedIn's "Email or phone": `POST /auth/login` takes an address only.

## What it does

| Control | Does |
|---|---|
| Email Address, Password | `POST /auth/login` with the trimmed address, the password and Remember Me; refusals are the API's sentence ("Invalid email or password." for a bad pair), shown under the form. Empty and malformed values are refused before any call, in red under the field. |
| Show / Hide | Shows or hides the typed password. Its tooltip and screen-reader name are "Show Password" / "Hide Password". |
| Remember Me | Starts off and goes to the API as `rememberMe`. |
| LinkedIn / Google (under "Sign In Using"; read out "Continue with …") | The API's own OAuth round trip in a secure browser tab (`/auth/:provider/start?client=app…`). A provider the server has no keys for is drawn faded and says so when tapped; closing the tab changes nothing; someone new continues on the join screen. |
| Forgot Password? | Opens the in-app reset screen with the typed address, still editable. |
| Join Now | Opens the three sign-up screens; coming back with an address (an account that already exists) fills it in here. |
| Keyboard | Next moves from email to password; Done submits; the page scrolls when the keyboard is up or the phone is small. |

## Tests

- `test/sign_in_test.dart`: refusals before a call, the login request body, Remember Me, an API refusal, Show / Hide, the faded provider and the round trip, screen-reader names, the LinkedIn layout itself (heading, labelled fields, no "or", "Sign In Using" under the Sign In button over the two provider pills side by side with 28 dp marks, "Join Now" below them at the foot of a 390 × 844 screen), a 320 × 568 phone with the keyboard up (the pills stack), light and dark colours (and no card), and the join screen in both modes.
- `test/live/auth_live_test.dart` (the local API): sign in as a seeded person, resume the saved session, sign out; both Remember Me choices; a wrong password; the provider list.
- `test/golden/screens_golden_test.dart`: `sign_in_light.png` and `sign_in_dark.png` at 390 × 844.

## 12 Nov 2026: Google and LinkedIn under the form, "Sign in using"

The owner's review of the screen atlas (`02-sign-in-sign-up`): "move the google and LinkedIn logo down with the headline sign in using then followed by icons and increase the size of the icons", with a reference that draws "Sign in or create your account using" over a row of outlined pills, each a logo and its name. The "or" rule and the two full-width "Continue with …" buttons gave way to a hairline under **Sign in**, the heading **Sign in using**, and **LinkedIn** and **Google** side by side, marks 28 dp (were 22). Behaviour is unchanged: the pills still wait for `GET /auth/social/providers`, a provider with no keys is faded and says so, the spinner takes the mark's place during the round trip, and screen readers still hear "Continue with LinkedIn / Google". The goldens were regenerated.

## 13 Nov 2026: copy refined to the client's standard

The client marked up the app's user manual with the words they want on this screen (manual section 1.1, the first box). The layout is unchanged: no "or" rule and no "Continue with …" buttons came back; the box's "or / Continue with LinkedIn / Continue with Google" lines describe the older screenshot, so only its capitalisation was taken, for the heading over the two pills.

| Where | Old | New |
|---|---|---|
| Title and button | Sign in | Sign In |
| Line under the title | Stay updated on your professional world. | Stay connected with the CRE & FM community. |
| Email field | Email | Email Address |
| Link under the fields | Forgot password? | Forgot Password? |
| Tick | Remember me | Remember Me |
| Heading over the pills | Sign in using | Sign In Using |
| Foot | New to ICR? Join now | New to ICR? Join Now |
| Button while it works | Signing in… | Signing In… |
| Tooltips of Show / Hide and of the eye | Show password / Hide password | Show Password / Hide Password |
| Empty email | Please enter your email address. | Enter your email address. |
| Malformed email | Please enter a valid email address. | Enter a valid email address. |
| Empty password | Please enter your password. | Enter your password. |
| A provider with no keys (snackbar) | LinkedIn sign-in is not available yet | LinkedIn sign-in is not available yet. |

Kept as they were: **Password**, **Show** / **Hide**, "Your session has ended. Sign in again to continue.", the API's own refusals, and the screen-reader name "Continue with LinkedIn / Google" of the two pills (heard, not drawn). The goldens `sign_in_light.png` and `sign_in_dark.png` were re-recorded: their diffs were these words and nothing else.
