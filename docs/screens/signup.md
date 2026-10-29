# Sign-up, password recovery and email confirmation

The way in: three short screens, as the website's `/register` (`components/auth/register/RegisterForm.tsx`), then the two emailed-link flows the website finishes on its own pages, taken in the app. **Sign-in itself is `docs/screens/sign_in.md`** (its look is fixed by the sign-in designs and is not touched here); this page is what Sign in opens: `Join now` and `Forgot password?`. The screens wear the same card as Sign in (`AuthScaffold`, `AuthPalette`, light and dark follow the phone).

Files: `lib/features/auth/` (`sign_up_screen.dart`, `signup_widgets.dart`, `signup_rules.dart`, `your_work_step.dart`, `forgot_password_screen.dart`, `reset_password_screen.dart`, `verify_email_screen.dart`, `recovery_repository.dart`). Tests: `test/signup_test.dart`, `test/recovery_test.dart`, live `test/live/account_live_test.dart` (group "sign-up and recovery").

## The three screens

1. **Join ICR.** Google or LinkedIn (round trip in `AuthController.signInWith`, see sign_in.md), or **Work Email** and **Create Password** and the tick that accepts the Terms and Privacy Policy. **Join** emails a 6-digit code (`POST /auth/email/send-code`); nothing is made yet. Eight characters is the only blocking password rule (`@MinLength(8)`); the four-segment strength meter and its rules are advice. A password holding the address's name is refused as the website refuses it.
2. **About you.** First and last name and **Code from your email**. **Continue** checks the code (`POST /auth/email/verify-code`), then makes the account (`POST /auth/register`, no phone and no account type: a self-serve sign-up is a PROFESSIONAL) and signs in. On a non-production API the send answers with the code, so the screen shows **"Test mode: your code is 123456"** with **Use code** (the website's `DevCodeNote`). "send a new one in 60s" waits out the API's own per-address wait. **Change email** goes back with the address and password still typed. Someone back from Google or LinkedIn starts here with the provider's name filled in, sees "Continuing with Google as …", asks the code only when the provider would not vouch for the address, and the button reads **Agree & join**.
3. **Your work.** *I'm working*: job title (suggestions from `GET /job-titles`), company (a company already on ICR is picked from `GET /companies?search=`, which links the role to its page and offers **Ask to join {company}'s team**), the year started, the city (optional). *Between roles*: an optional last title, a city and **Let recruiters know I'm ready for my next role**. It writes where the profile keeps it (`saveYourWork`): a current role (`PUT /profile/experience`), the headline (`PATCH /users/me {designation}`), the résumé's title and place (`PATCH /users/me/resume`), and for a picked company a join request (`POST /team/companies/:id/join-requests`). **Skip for now** saves nothing and leaves the account made. After the last screen the app opens signed in (`popUntil first`); the session gate swaps the screen.

Back from screen 3 finishes rather than returning to a screen that would make the account twice. A taken address is a 409: "That email already has an ICR account" with **Sign in instead**, which returns the address typed so far to the Sign in card.

## Recovery

| Screen | Does |
|---|---|
| **Forgot password** (`ForgotPasswordScreen`) | the address (cleaned, checked in the website's words), then `POST /auth/forgot-password`, answered the same for any address. "Check your inbox", **I have my link**, **Send it again**, **Back to sign in**. A local API with no mail provider hands the link back: "Test mode: no email was sent. **Use the link**". Opened from Settings → Sign-in & security with `email:` it is fixed to the account's own address ("Change your password"), which is the only way the API changes a password (it also sets one for an account that signed up with Google or LinkedIn). |
| **Choose a new password** (`ResetPasswordScreen`) | with a `token` (a deep link, or Use the link) straight to the two fields; without one, **paste the link from the email** (`tokenFromLink` takes the whole link, its query, or the bare token). `POST /auth/reset-password` sets the password and ends every session, so a signed-in person is signed out here (without a second call to the API) and goes back to Sign in. A refused link (used, expired) keeps what was typed and offers **Request a new link**. |
| **Confirm your email** (`VerifyEmailScreen`) | for an older account that never confirmed: with a token it confirms at once (`POST /auth/verify-email`), the session is read again so the "not confirmed" notice goes; otherwise paste the link or **Send me a new link** (`POST /auth/resend-verification`, signed in; "This email is already confirmed." when there is nothing to do). Without a session the way to a new link is signing in. |

## Every control and the test that proves it

`S` = `test/signup_test.dart`, `R` = `test/recovery_test.dart`, `L` = `test/live/account_live_test.dart`.

| Control | Proved by |
|---|---|
| Join with an empty form, a bad address (each reason in the website's words), a password holding the address, no tick | S "screen 1, Join" (asks for…, says what is wrong…, refuses a password…) |
| Join sends the code to the cleaned address and moves on; double tap sends one | S "Join sends the code…", "double tapping Join…" |
| A 409, a dead connection, the eye, the meter, the Terms and Privacy links, the provider marks | S "an address that already has an account…", "a dead connection…", "the eye…", "the password meter…", "the Terms and Privacy names…", "the Google and LinkedIn marks…" |
| About you: names and code before any call; test code and **Use code**; Continue checks the code then registers with no phone and no role; an expired code; a retry after a failed register does not check the code again; a 409 on register; resend cooldown; a refused resend; Change email | S "screen 2, About you" (11 tests) |
| Your work: title, company and year; saves role, headline and résumé; picks and links a company and asks to join; unticking sends no request; between roles; Skip | S "screen 3, Your work" (6 tests); L "three screens…" and "between roles…" (the function the screen calls, against the API: role, headline, résumé, the request waiting, then withdrawn) |
| Sign in instead returns the typed address | S "leaving" |
| Every screen fits 320 x 568 with the keyboard up | S "a small phone" |
| The code, a wrong code, the account made, a second sign-up with the same address refused | L "three screens…" (also proves `POST /auth/register` refuses a code not yet verified) |
| Forgot password: refusals before any call, the cleaned address sent, the same answer for any address, the test link, **I have my link**, **Send it again**, **Back to sign in**, a double tap sends one | R "Forgot password" |
| Reset: the pasted link or the token, the eye, eight characters and a matching second field, Update sends token and password, a signed-in person is signed out without a logout call, an expired link keeps the passwords and offers a new one, a dead connection keeps them, a double tap sends one, 320 x 568 | R "Choose a new password" (+ `tokenFromLink`) |
| Verify: a link confirms and refreshes the person, already confirmed, a refused link offers a new one, no session, the pasted link, a resend for a confirmed address | R "Confirm your email" |
| The reset link end to end: forgot → link → new password → the old one is refused → the new one signs in → the link is spent | L "forgot password, the reset link…" |
| An unknown address gets the same answer; verify-email with a bad token; resend says "already confirmed" for a new account | L "an unknown address…", "verify-email…" |

## Handoffs kept

Only **Terms of Service** and **Privacy Policy** (the names in the sign-up consent line) open the website, as the brief allows.

## What the lead wires

- Sign in already pushes `SignUpScreen()` and `ForgotPasswordScreen(initialEmail:)`; nothing to add. A new person back from Google or LinkedIn: `SocialSignupScreen(signup:, provider:)`.
- Deep links (optional): `ResetPasswordScreen(token: …)` and `VerifyEmailScreen(token: …)` for `https://icr.org.in/reset-password?token=` and `/verify-email?token=` when app links exist. Without them the pasted-link path works.

## Left

Nothing in the flow. Not exercised on a device: the platform autofill of the emailed code (`AutofillHints.oneTimeCode` is set).
