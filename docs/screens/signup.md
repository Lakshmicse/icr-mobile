# Sign-up, password recovery and email confirmation

The way in: three short screens, as the website's `/register` (`components/auth/register/RegisterForm.tsx`), then the two emailed-link flows the website finishes on its own pages, taken in the app. **Sign-in itself is `docs/screens/sign_in.md`** (its look is fixed by the sign-in designs and is not touched here); this page is what Sign In opens: `Join Now` and `Forgot Password?`. The words on every screen here are the client's standard since 13 Nov 2026 (the last section has the old → new table). The screens wear the same card as Sign in (`AuthScaffold`, `AuthPalette`, light and dark follow the phone).

Files: `lib/features/auth/` (`sign_up_screen.dart`, `signup_widgets.dart`, `signup_rules.dart`, `your_work_step.dart`, `forgot_password_screen.dart`, `reset_password_screen.dart`, `verify_email_screen.dart`, `recovery_repository.dart`). Tests: `test/signup_test.dart`, `test/recovery_test.dart`, live `test/live/account_live_test.dart` (group "sign-up and recovery").

## The three screens

1. **Join ICR.** **Email** and **Password** and the tick that accepts the Terms and Privacy Policy, or, under a hairline below **Join**, **Sign Up Using** Google or LinkedIn (two outlined pills side by side, mark and name; round trip in `AuthController.signInWith`, see sign_in.md). **Join** emails a 6-digit code (`POST /auth/email/send-code`); nothing is made yet. Eight characters is the only blocking password rule (`@MinLength(8)`); the four-segment strength meter and its rules are advice. A password holding the address's name is refused as the website refuses it.
2. **About You.** **First Name**, **Last Name**, **Mobile Number** (see 9 Nov) and **Email Verification Code**, with "Code sent to {email}. It expires in 10 minutes." under it. **Continue** checks the code (`POST /auth/email/verify-code`), then makes the account (`POST /auth/register`, no phone and no account type: a self-serve sign-up is a PROFESSIONAL) and signs in. On a non-production API the send answers with the code, so the screen shows **"Test mode: your code is 123456"** with **Use Code** (the website's `DevCodeNote`). "No email? Check your spam folder. **Resend in 60s**" waits out the API's own per-address wait, then reads **Resend Code**. **Change Email** goes back with the address and password still typed. Someone back from Google or LinkedIn starts here with the provider's name filled in, sees "Continuing with Google as …", asks the code only when the provider would not vouch for the address, and the button reads **Agree & Join**.
3. **Your Work.** *I'm Working*: **Job Title** (suggestions from `GET /job-titles`), **Company** (a company already on ICR is picked from `GET /companies?search=`, which links the role to its page and offers **Ask to join {company}'s team**), **Since** (the year started) and **City**. *Between Roles*: **Most Recent Job Title (Optional)**, **City** and **Let recruiters know I'm ready for my next role.** **The city is required in both** since 13 Nov 2026 (the client's note "Mandatory" on the manual's City field): Continue with none shows "Select your city." under the field, as the other required fields show theirs. It writes where the profile keeps it (`saveYourWork`): a current role (`PUT /profile/experience`), the headline (`PATCH /users/me {designation}`), the résumé's title and place (`PATCH /users/me/resume`), and for a picked company a join request (`POST /team/companies/:id/join-requests`). **Skip for Now** saves nothing, asks for no city, and leaves the account made. After the last screen the app opens signed in (`popUntil first`); the session gate swaps the screen.

Back from screen 3 finishes rather than returning to a screen that would make the account twice. A taken address is a 409: "That email already has an ICR account." with **Sign In Instead**, which returns the address typed so far to the Sign In page.

## Recovery

| Screen | Does |
|---|---|
| **Reset Your Password** (`ForgotPasswordScreen`) | the address (cleaned and checked before any call), then `POST /auth/forgot-password`, answered the same for any address. **Check Your Inbox**, **I have the Link**, **Back to Sign In**, **Resend Link**. A local API with no mail provider hands the link back: "Test mode: no email was sent. **Use the Link**". Opened from Settings → Sign-In & Security with `email:` it is fixed to the account's own address (**Change Password**, "Changed your mind? **Go Back**"), which is the only way the API changes a password (it also sets one for an account that signed up with Google or LinkedIn). The page is one plain colour, white in light (`AuthScaffold(flat: true)`). |
| **Create a New Password** (`ResetPasswordScreen`) | with a `token` (a deep link, or Use the Link) straight to the two fields; without one, **Enter Your Reset Link**: paste the link from the email (`tokenFromLink` takes the whole link, its query, or the bare token), with **Resend Reset Link** back to the request. `POST /auth/reset-password` sets the password and ends every session, so a signed-in person is signed out here (without a second call to the API) and goes back to Sign in. A refused link (used, expired) keeps what was typed and offers **Request a New Link**. The same plain page as the request. |
| **Verify Your Email** (`VerifyEmailScreen`) | for an older account that never verified: with a token it verifies at once (`POST /auth/verify-email`), the session is read again so the "Not Verified" chip goes; otherwise paste the link or **Resend Link** (`POST /auth/resend-verification`, signed in; "This email is already verified." when there is nothing to do). Without a session the way to a new link is signing in. |

## Every control and the test that proves it

`S` = `test/signup_test.dart`, `R` = `test/recovery_test.dart`, `L` = `test/live/account_live_test.dart`.

| Control | Proved by |
|---|---|
| Join with an empty form, a bad address (a reason for each), a password holding the address, no tick | S "screen 1, Join" (asks for…, says what is wrong…, refuses a password…) |
| Join sends the code to the cleaned address and moves on; double tap sends one | S "Join sends the code…", "double tapping Join…" |
| A 409, a dead connection, the eye, the meter, the Terms and Privacy links, the provider pills under Join | S "an address that already has an account…", "a dead connection…", "the eye…", "the password meter…", "the Terms and Privacy names…", "the Google and LinkedIn pills sit under Join…" |
| About You: names and code before any call; the client's labels and "Code sent to …"; test code and **Use Code**; Continue checks the code then registers with no phone and no role; an expired code; a retry after a failed register does not check the code again; a 409 on register; resend cooldown; a refused resend; Change Email | S "screen 2, About You" |
| Your Work: title, company, year and city (the city asked for when everything else is filled in, and in Between Roles too); saves role, headline and résumé with the city; picks and links a company and asks to join; unticking sends no request; between roles; Skip for Now asks for nothing | S "screen 3, Your Work" (8 tests); L "three screens…" and "between roles…" (the function the screen calls, against the API: role, headline, résumé, the request waiting, then withdrawn) |
| Sign In returns the typed address | S "leaving" |
| Every screen fits 320 x 568 with the keyboard up | S "a small phone" |
| The code, a wrong code, the account made, a second sign-up with the same address refused | L "three screens…" (also proves `POST /auth/register` refuses a code not yet verified) |
| Reset Your Password: refusals before any call, the client's words on the form, on Check Your Inbox and on the screen Settings opens, the plain page in light and in dark, the cleaned address sent, the same answer for any address, the test link, **I have the Link**, **Resend Link**, **Back to Sign In** (**Go Back** from Settings), a double tap sends one | R "Forgot password" |
| Reset: the client's words on Enter Your Reset Link, the pasted link or the token, **Resend Reset Link**, the eye, eight characters and a matching second field, Update sends token and password, a signed-in person is signed out without a logout call, an expired link keeps the passwords and offers a new one, a dead connection keeps them, a double tap sends one, 320 x 568 | R "Create a New Password" (+ `tokenFromLink`) |
| Verify: a link confirms and refreshes the person, already confirmed, a refused link offers a new one, no session, the pasted link, a resend for a verified address | R "Verify Your Email" |
| The reset link end to end: forgot → link → new password → the old one is refused → the new one signs in → the link is spent | L "forgot password, the reset link…" |
| An unknown address gets the same answer; verify-email with a bad token; resend says "already confirmed" for a new account | L "an unknown address…", "verify-email…" |

## Handoffs kept

Only **Terms of Service** and **Privacy Policy** (the names in the sign-up consent line) open the website, as the brief allows.

## What the lead wires

- Sign in already pushes `SignUpScreen()` and `ForgotPasswordScreen(initialEmail:)`; nothing to add. A new person back from Google or LinkedIn: `SocialSignupScreen(signup:, provider:)`.
- Deep links (optional): `ResetPasswordScreen(token: …)` and `VerifyEmailScreen(token: …)` for `https://icr.org.in/reset-password?token=` and `/verify-email?token=` when app links exist. Without them the pasted-link path works.

## Left

Nothing in the flow. Not exercised on a device: the platform autofill of the emailed code (`AutofillHints.oneTimeCode` is set).

## 9 Nov 2026: the mobile number at sign-up

The API has required a mobile number at registration since 29 Oct 2026 (`enterYourMobileNumber`; a +91 number needs its OTP proof), and the app sent none — every sign-up from the app, email or Google/LinkedIn, was refused ("Signup is not working", owner, 9 Nov). The About you screen now asks **Mobile number** between the names and the email code (`signup.phone`): an Indian number gets **Send OTP** (`POST /auth/phone/send-otp`; off production the code comes back and `DevCodeNote` shows it) and **Enter Mobile OTP** (`signup.phoneCode`), checked with `POST /auth/phone/verify-otp` when Continue is pressed, before the email code; any other country's number passes its format check and is saved as typed (the website's `PhoneVerifyInline acceptUntextable`). `register` and `completeSocialSignup` send `phone` (E.164). Rules: `phoneProblem`, `otpProblem` in `signup_rules.dart`.

## 12 Nov 2026: the owner's atlas review (02, sign in and sign up)

- **Join ICR:** "The LinkedIn and Google logo has to go down with comment up sign up using". The two bare marks and the "OR" rule at the top of the card are gone; under **Join** a hairline, the heading **Sign up using**, and **LinkedIn** and **Google** as outlined pills side by side, each a 28 dp mark and the provider's name (`SocialProvidersBlock` / `SocialPillButton` in `auth_widgets.dart`, shared with Sign in). They stack on a card under 280 dp wide (a 320 dp phone). Same behaviour as before: hidden keys fade a pill, a tap says so, the spinner replaces the mark during the round trip.
- **Forgot password:** the title reads **Forgot Password**, the line under it "Enter your email to receive a link to reset your password.", the button **Submit**, and "Remembered it? Sign in" is now one larger **Back to Login** link. "Check your inbox" says **Back to Login** too, as does the expired Google/LinkedIn sign-up link. Opened from Settings to change a password it still reads "Change your password" and "Changed your mind? Go back", since that goes back to Settings, not to Sign in.
- Not applied, because the app has no such screen: the website's "Link is missing its token" page (the app's reset screen asks for the pasted link instead), the newsletter "Link expired or invalid" page, `/reminders/stop`, and the supplier set-up wizard and SELL menu notes (another screen's work).

## 13 Nov 2026: copy refined to the client's standard

The client marked up the app's user manual (sections 1.1 and 1.4) with the words they want, and asked for the rest to follow the same style: Title Case for titles, labels, buttons and links; a plain sentence with a full stop for helpers and errors; "Sign In", "Email", "Mobile Number", "Verify" used throughout. Where their note differs from the owner's wording of 12 Nov (the Forgot Password page), the newer note wins. Layouts are unchanged except where said.

**Join ICR, About You, Your Work**

| Where | Old | New |
|---|---|---|
| Step 1 email field (client) | Work Email | Email |
| Step 1 password field (client) | Create Password | Password |
| Step 1 helper | We'll email you a code to confirm it. | We will email you a verification code. |
| Heading over the pills | Sign up using | Sign Up Using |
| Foot | Already have an account? Sign in | Already have an account? Sign In |
| Screen titles | About you · Your work | About You · Your Work |
| Step 2 fields | First name · Last name · Mobile number | First Name · Last Name · Mobile Number |
| Step 2 code field (client) | Code from your email | Email Verification Code |
| Under the code (client) | We sent a code to {email}. It expires in 10 minutes. | Code sent to {email}. It expires in 10 minutes. |
| Beside the code field | Change email | Change Email |
| Resend line | No email? Check spam, or send a new one (in 40s) | No email? Check your spam folder. Resend Code (Resend in 40s) |
| Mobile helpers | We can text an OTP only to Indian (+91) numbers for now; this one is saved as typed. · Indian (+91) numbers get a texted OTP; any other is saved as typed. | An OTP can be sent only to Indian (+91) numbers. This number is saved as entered. · Indian (+91) numbers receive an OTP by text. Other numbers are saved as entered. |
| Social sign-up | Agree & join · By selecting Agree & join, … | Agree & Join · By selecting Agree & Join, … |
| Step 3 switch | I'm working · Between roles | I'm Working · Between Roles |
| Step 3 fields | Job title · Most recent job title (optional) · City (optional) | Job Title · Most Recent Job Title (Optional) · **City** (required, see below) |
| Step 3 helper | Pick it from the list if it is already on ICR. | Select it from the list if it is already on ICR. |
| Picker sheets | Year you started · Where you are based · Nothing matches "x". | Select Start Year · Select City · No results for "x". |
| Step 3 foot | Skip for now | Skip for Now |
| Partly saved step | Your profile is saved, but the request to join {company} did not go through: {reason} | Your profile is saved. The request to join {company} was not sent. {reason} |
| Password meter note | A guide, not a gate — only 8 characters are required. | This is guidance. Only 8 characters are required. |
| Buttons while they work | Sending your code… · Creating your account… | Sending Code… · Creating Account… |
| Expired social sign-up | That sign-in has expired. Please start again from the sign-in page. · Try again · Back to Login | That sign-in has expired. Start again from the Sign In page. · Try Again · Back to Sign In |
| A taken address | Sign in instead | Sign In Instead |
| Test-mode note | Use code | Use Code |
| Field problems (17 sentences) | Enter your email · At least 8 characters · Don't reuse your email address as your password · Enter your first name · Enter the 6-digit code from the email · Enter the 6-digit OTP we texted you · Enter where you work · Choose the year you started · Please agree to the Terms… | each ends with a full stop and drops "please": Enter your email. · Use at least 8 characters. · Do not use your email address as your password. · Enter your first name. · Enter the 6-digit code from your email. · Enter the 6-digit OTP sent to your mobile number. · Enter your company. · Select the year you started. · Agree to the Terms… |

**City is required on Your Work.** The client's note "Mandatory" sits on the City field, which read "City (optional)". `workProblems` takes `hasCity` and returns a `city` problem ("Select your city."), shown under the field in the error colour like the year's; picking a city clears it. It is asked in both *I'm Working* and *Between Roles* (one screen, one City field), and **Skip for Now** still leaves without asking. Nothing changed at the API: the city was already sent (`PUT /profile/experience` `city`, `PATCH /users/me/resume` `location`), and both stay optional there. If the list of cities cannot be read, the person cannot pick one and Skip for Now is the way on.

**Reset Your Password, Check Your Inbox, Enter Your Reset Link** (all the client's words)

| Where | Old | New |
|---|---|---|
| Title | Forgot Password | Reset Your Password |
| Line | Enter your email to receive a link to reset your password. | Enter your email address to receive a password reset link. |
| Field | Work email | Email |
| Button | Submit | Send Reset Link |
| Foot | Back to Login (one link) | Remember your password? Sign In |
| Note | Signed in with Google or LinkedIn and never set a password? This sets one. | Signed in with Google or LinkedIn? You can sign in directly without setting a password. |
| Sent: title | Check your inbox | Check Your Inbox |
| Sent: body | If that address has an ICR account, we've sent a link to reset your password. It expires in an hour. | If an ICR account exists for this email, we've sent a password reset link. The link expires in 1 hour. |
| Sent: notice | Open the email on this phone, copy its link, and choose your new password here. | Open your email, copy the reset link and paste it here to create a new password. |
| Sent: buttons and link | I have my link · Back to Login · Send it again | I have the Link · Back to Sign In · Resend Link |
| Sent: note | (the same note as the form) | Registered with Google or LinkedIn? Sign in directly using the same account. |
| Paste: title | Use your reset link | Enter Your Reset Link |
| Paste: line | Paste the link from the password reset email, then choose your new password here. | Paste the link from your password reset email to create a new password. |
| Paste: field and link | Reset link · Send me a new link | Reset Link · Resend Reset Link |
| Opened from Settings | Change your password · (the form's line) · Work email · Submit · Changed your mind? Go back · (the form's note) | Change Password · Enter your work email to receive a password reset link. · Work Email · Send Reset Link · Changed your mind? Go Back · Registered with Google or LinkedIn? Sign in using the same account. |

"1 hour" is the API's own figure (`RESET_TTL_HOURS = 1` in the portal's `auth.service.ts`). Opened from Settings, the sent state's button reads **Go Back**, not "Back to Sign In", because it returns to Sign-In & Security.

**Background fully white.** These screens drew the white card on the warm grey page (`#F4F2EE`). `AuthScaffold` has a `flat` flag: the page takes the card's own colour, so the form sits on one plain background edge to edge (white in light, the card's `#111827` in dark; the status and navigation bars follow). `ForgotPasswordScreen` (the form, Check Your Inbox, and Change Password from Settings) and `ResetPasswordScreen` (Enter Your Reset Link, and its two later states so the page does not change colour between steps) use it. The three sign-up screens and Verify Your Email keep the card on the grey page.

**The rest of the flow, in the same voice**

| Where | Old | New |
|---|---|---|
| New password | Choose a new password · New password · Confirm new password · Update password · At least 8 characters. | Create a New Password · New Password · Confirm New Password · Update Password · Use at least 8 characters. |
| New password problems | Enter a new password · Re-enter your new password · The two passwords do not match. · That does not look like a reset link. Paste the whole link from the email. | Enter a new password. · Re-enter your new password. · The passwords do not match. · This is not a valid reset link. Paste the full link from the email. |
| Done | Password updated · Your password has been changed and every device was signed out. Sign in with your new password. · Sign in | Password Updated · Your password has been changed. All devices have been signed out. Sign in with your new password. · Sign In |
| Refused link | Request a new link | Request a New Link |
| Verify email: titles | Confirm your email · Confirming your email · Email confirmed · Already confirmed · That link did not work | Verify Your Email · Verifying Your Email · Email Verified · Already Verified · This Link Did Not Work |
| Verify email: body | Your address is confirmed. Thanks for keeping your account safe. · Paste the link from the confirmation email, or have a new one sent. · This confirmation link is not valid. | Your email address is verified. · Paste the link from the verification email, or request a new link. · This verification link is not valid. |
| Verify email: controls | Confirmation link · Confirm my email · Send me a new link · Sign in to get a new link · A new link is on its way. Check your inbox. · This email is already confirmed. | Verification Link · Verify Email · Resend Link · Sign In to Get a New Link · A new link has been sent. Check your inbox. · This email is already verified. |

"Confirm" became "Verify" on these screens because the client's Sign-In & Security note names the email's state **Verified**.

Kept as they were: **Join ICR**, **STEP 1 OF 3**, **Join**, **Continue**, **Company**, **Since**, **Enter Mobile OTP**, **Send OTP** / **Resend OTP**, "Number verified.", "OTP sent to …", the four meter rules (At least 8 characters, 12 or more characters, Upper and lower case, A number or symbol) and its Weak / Fair / Good / Strong, "I agree to ICR's Terms of Service and Privacy Policy.", the field hints (name@company.com, e.g. Facilities Manager, Where you work now, Year you started, Where you are based), "Ask to join {company}'s team on ICR. Its admins decide.", "Continuing with Google as …", the test-mode notes, and every sentence the API sends. The mobile number's own format problems come from `account_rules.dart` (`phoneError`), another folder.


## 14 Nov 2026: light only, whatever the phone's setting

The owner: "the sign in page and Sign up page still the dark theme is coming i didn't built the app for the dark mode yet keep all pages light mode only." `AuthPalette.of` and `LiColors.of` now always return their light set, so sign-in, the three sign-up screens, forgot and reset password and verify email stay white on a phone in dark mode (the splash was made white on 13 Nov). The dark sets stay in the code, unused, for when a dark theme is built. No other screen reads the phone's brightness. Tests: `sign_in_test.dart` ("light only"), `recovery_test.dart`; golden `sign_in_dark.png` is now identical to `sign_in_light.png`.
