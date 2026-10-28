# Sign in

The Sign in card in light and in dark (`docs/designs/sign-in-light.png`, `sign-in-dark.png`), and the join screen that follows Google or LinkedIn for someone new, which wears the same card.

## What it is

A card on a plain page: "Sign in" and the ICR logo on one line; the LinkedIn and Google marks on their own, no boxes; a hairline "OR"; **Email** and **Password** with an icon inside each, "Forgot password?" opposite "Password", the show/hide eye; "Remember me"; the **Sign in** button; "New to ICR? Create an account".

- **Light or dark follows the phone's own setting** (`AuthPalette.of(context)` reads `MediaQuery.platformBrightness`). Every colour is in `lib/features/auth/auth_palette.dart`, measured from the two designs; the layout is the same in both. The logo swaps to `assets/images/brand/icr-logo-white.png` (the logo recoloured white, shading kept) on the dark card. The rest of the app is light for now; only the auth screens have a dark side.
- Built from `auth_widgets.dart` (`AuthScaffold`, `AuthHeader`, `AuthField`, `AuthEyeButton`, `AuthCheckbox`, `AuthPrimaryButton`, `AuthLink`, `AuthDivider`, `SocialIconButton`, `AuthErrorLine`, `AuthOutlinedButton`) and the type in `AuthType`; `social_signup_screen.dart` uses the same pieces, so the join step is on the card too.
- Everything is Work Sans, sized by the width of the designs' text: title 29.4 bold, labels 15.2 bold, input 19, "Forgot password?" 14.5 semibold, "Remember me" 16.7, button 17.9 bold, "New to ICR?" 16.5, "Create an account" 16.8 bold.
- Geometry (dp, from the 375-wide frames): card 360 wide with 15 either side, 18 radius, 1 border; content 308 wide (25 inside the border); fields 59 tall, 12 radius, 1 border, icon 18 in, text 53 in; button 54 tall, 12 radius; the marks 35 (LinkedIn) and 37 (Google) with their centres 99 apart. Vertical positions are within 1 dp of the designs in both modes (`python tool/design/cardcompare.py build/screens/sign_in_light.png docs/designs/sign-in-light.png out.png` lists every band's offset).

## What it does

| Control | Does |
|---|---|
| Email, Password | `POST /auth/login` with the trimmed address, the password and Remember me; refusals are the API's sentence ("Invalid email or password." for a bad pair), shown under the form. Empty and malformed values are refused before any call. |
| Eye | Shows or hides the typed password. |
| Remember me | Starts off, as in the design, and goes to the API as `rememberMe`. |
| LinkedIn, Google | The API's own OAuth round trip in a secure browser tab (`/auth/:provider/start?client=app…`). A provider the server has no keys for is drawn faded and says so; closing the tab changes nothing; someone new continues on the join screen. |
| Forgot password? / Create an account | Open the website's `/forgot-password` and `/register` (resetting and joining with an email happen on the website). |
| Keyboard | Next moves from email to password; Done submits; the card scrolls when the keyboard is up or the phone is small. |

## What changed from the first version

- The LinkedIn-style layout (logo above the title, "or Join ICR", "Continue with Google/LinkedIn" buttons, a "Show" word on the password) became the card.
- "Keep me signed in" (on) became "Remember me" (off), as drawn. The session is kept either way; the choice goes to the API as before.
- The "By signing in you agree to the ICR Terms and Privacy Policy" line is not in the design, so it is gone from this screen (the join step, which creates the account, still carries it).
- The provider buttons lost their words; each mark carries the label for screen readers ("Continue with Google").
- Placeholders are an addition: the designs show typed values only.

## Tests

- `test/sign_in_test.dart`: refusals before a call, the login request body, Remember me, an API refusal, the eye, the faded provider and the round trip, screen-reader names, a 320 × 568 phone with the keyboard up (this caught a real overflow in "New to ICR? Create an account", now a `Wrap`), light and dark palettes, and the join screen in both modes (confirming a name, the emailed code path, a link that will not load).
- `test/live/auth_live_test.dart` (the local API): sign in as a seeded person, resume the saved session, sign out; both Remember me choices; a wrong password; the provider list.
- `test/golden/screens_golden_test.dart`: `sign_in_light.png` and `sign_in_dark.png` at 390 × 844.
