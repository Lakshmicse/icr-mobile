# Sign in

Sign in, laid out as LinkedIn's own sign-in page is, in ICR's colours, in light and in dark. The join screens that follow it (Google or LinkedIn for someone new, and the three sign-up screens) still wear the card from the Sign in designs (`docs/designs/sign-in-light.png`, `sign-in-dark.png`).

**Owner's call, 28 Oct 2026:** "build me android sign in page as it is LinkedIn". This replaces the card layout the sign-in designs drew for this one screen; the card layout stays on the other auth screens.

## What it is

A plain page, no card: the ICR logo at the top left; **Sign in** (32, semibold) with "Stay updated on your professional world." under it; **Email** and **Password** as outlined fields whose label floats up to the border, with **Show** / **Hide** as a word inside the password field; **Forgot password?** under the fields; "Remember me"; one pill **Sign in** button; a hairline **or**; **Continue with LinkedIn** and **Continue with Google** as full-width outlined pills with the provider's mark at the left; and **New to ICR? Join now** pinned to the bottom of the screen.

- **Light or dark follows the phone's own setting** (`LiColors.of(context)` reads `MediaQuery.platformBrightness`). Every colour is in `lib/features/auth/linkedin_style.dart`: a white page and a near-black ink in light, `#1B1F23` and a light ink in dark; the accent is ICR's blue (`#32629E`) for the pill and the focus ring, and links use a lighter tint of it in dark so they read. The logo swaps to `assets/images/brand/icr-logo-white.png` in dark.
- Built from `linkedin_style.dart` (`LiScaffold`, `LiTextField`, `LiShowButton`, `LiLink`, `LiPrimaryButton`, `LiSocialButton`, `LiOrDivider`, with colours in `LiColors` and type in `LiType`). "Remember me" and the error line are the card screens' `AuthCheckbox` and `AuthErrorLine`.
- Everything is Work Sans: title 32, subtitle and labels 16, input 17, links 16 semibold, buttons 17 semibold, "or" 14.
- Geometry (dp): 24 either side, 440 wide at most; fields 56 tall with a 6 radius and a 1 border (2 in the accent when focused); the pill and both provider buttons 52 tall and the full width, fully rounded; 12 between the provider buttons.
- The label on the email field is "Email", not LinkedIn's "Email or phone": `POST /auth/login` takes an address only.

## What it does

| Control | Does |
|---|---|
| Email, Password | `POST /auth/login` with the trimmed address, the password and Remember me; refusals are the API's sentence ("Invalid email or password." for a bad pair), shown under the form. Empty and malformed values are refused before any call, in red under the field. |
| Show / Hide | Shows or hides the typed password. Its tooltip and screen-reader name are "Show password" / "Hide password". |
| Remember me | Starts off and goes to the API as `rememberMe`. |
| Continue with LinkedIn / Google | The API's own OAuth round trip in a secure browser tab (`/auth/:provider/start?client=app…`). A provider the server has no keys for is drawn faded and says so when tapped; closing the tab changes nothing; someone new continues on the join screen. |
| Forgot password? | Opens the in-app reset screen with the typed address, still editable. |
| Join now | Opens the three sign-up screens; coming back with an address (an account that already exists) fills it in here. |
| Keyboard | Next moves from email to password; Done submits; the page scrolls when the keyboard is up or the phone is small. |

## Tests

- `test/sign_in_test.dart`: refusals before a call, the login request body, Remember me, an API refusal, Show / Hide, the faded provider and the round trip, screen-reader names, the LinkedIn layout itself (heading, labelled fields, "or", full-width provider buttons one under the other, "Join now" at the foot of a 390 × 844 screen), a 320 × 568 phone with the keyboard up, light and dark colours (and no card), and the join screen in both modes.
- `test/live/auth_live_test.dart` (the local API): sign in as a seeded person, resume the saved session, sign out; both Remember me choices; a wrong password; the provider list.
- `test/golden/screens_golden_test.dart`: `sign_in_light.png` and `sign_in_dark.png` at 390 × 844.
