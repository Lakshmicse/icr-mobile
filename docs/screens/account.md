# Account: the person's profile, member pages, settings, companies, saved items, network, contact

Everything the website's `/profile`, `/members/[id]`, `/account/companies`, `/network`, `/contact` and the profile menu's Settings do, in the app, against the real API, with no handoff to the website except the Terms and Privacy pages (Settings). Built as flows first (26 Oct 2026): the layout follows the app's own language (Work Sans headings, Plex Sans body, 12 dp hairline cards, pill buttons, the profile menu's header: cover, photo across its edge, name with the confirmed-email tick, headline, place); **pixel matching to a design is postponed** (no design exists for these screens except the profile menu, `docs/screens/profile_menu.md`).

Files: `lib/features/account/` (profile, members, settings, phone, companies, saved), `lib/features/network/`, `lib/features/contact/`; sign-up and recovery are `docs/screens/signup.md`.
Tests: `test/account_profile_test.dart`, `account_career_test.dart`, `account_member_test.dart`, `account_settings_test.dart`, `account_phone_test.dart`, `account_companies_test.dart`, `saved_test.dart`, `network_test.dart`, `contact_test.dart` (widget, against `DemoAccountRepository`, the in-memory stand-in that behaves as the API does and logs every call, or `FakeApi` in `test/helpers/account_harness.dart`), and `test/live/account_live_test.dart` (the local API; `flutter test --concurrency=1 test/live/account_live_test.dart`).
Seed: `tool/seed/account.ts` (see the end). Backend requests: none (`docs/backend-requests/account.md`).

## What each screen is

### The person's profile: `MyProfileScreen` (`profile/my_profile_screen.dart`)

One page of read-only section cards (LinkedIn's layout, the website's `ProfileWorkspace`); nothing on the page is a form: each section is edited in a sheet (`showEditSheet`, the website's `SectionDialog`: title, form, Cancel/Save, "Discard your changes?" when leaving with edits, the API's own refusal above the buttons with what was typed kept, Save with nothing changed closes without a call). Each section **reads and fails on its own** (a list that cannot be read says "Couldn't load your education" with its own Try again; the rest of the page stays), and a pull reads everything again.

Header (`ProfileHeader`): cover, photo, name, the blue tick when the sign-in email is confirmed, the role chip, headline, "place · organisation", "12 years in the profession", **Add section**, **View public profile**. The camera on the cover opens the covers; the photo opens the photo sheet; the pencil opens the intro. A **Profile strength** card lists what is missing and each item opens the sheet that finishes it (`resolvePersonalTask`).

| Section | Sheet |
|---|---|
| Intro | first name (required), last name, **headline** (suggestions from the staff's job-title list), years 0–60, location (a city from the list); writes `PATCH /users/me` and, for anyone with a résumé, `PATCH /users/me/resume` (title and place) |
| Photo | Upload / Change photo (picker + 5 MB check, uploaded then set as the avatar at once), Remove photo (asks first) |
| Cover | the eight ready-made covers (one tap saves), Upload your own, Remove cover |
| About | the summary, 2,000 characters with a counter; "See more / See less" on the card |
| Experience | roles and career breaks in date order, newest first, with **gaps** of six months or more shown to the person only ("A gap of 1 yr 5 mos · Add a career break · Add a role"); a role: title (suggestions), employment type, organisation (search ICR's companies: a pick links the role to the page and offers **Ask to join {company}'s team**, sent before the role is saved so a refusal saves nothing; typing anything else unlinks), city, "I work here now", start and end month and year, description |
| Education | institution, degree, field, university, start and end year, grade |
| Career break | reason, dates, "I'm on this break now", description (also opened from a gap with its dates filled in) |
| Licenses & certifications | the ones ICR issued are read-only and open their certificate; an external one: name, short code (capitals), issuer, issue and expiry date, verification link, **certificate** (PDF or picture, 10 MB, uploaded private) |
| Skills / Languages | chips: one tap on a suggestion, type and Enter, remove with the ×; 50 skills of 80 characters, 8 languages of 40 |

The three list sections (experience, education, career breaks) are saved **whole** by the API (`PUT` replaces every row and returns new ids): a sheet edits one item and `MyProfileController` merges it into the list it holds; the buttons wait for the list to load. Below the sections: **Your public profile** (the address, **Copy link**, **View**) and the **Sign-in & security** row.

### A member's page: `MemberProfileScreen(userId)` (`members/member_profile_screen.dart`)

`GET /members/:id` (the id or the slug). Header with followers, following, "Member since", **Mentor** / **Ready for a new role** chips; **Follow / Following** (at once, rolled back with the API's sentence when refused), **Message** (`POST /messaging/conversations` reuses the plain thread), **Mentor profile**, **Share**. Sections only when there is something to show: About, Experience (a role at a company on ICR opens the company), Education, Licenses & certifications (verified chip, opens the issuer's link), Skills, Languages, Links (the member's own LinkedIn etc. open in the browser), Chapters & councils, Community activity (reputation, discussions, replies, answers, and their latest discussions). A page that is private or gone says "This profile is not available". On the person's own page there is no Follow or Message, a note "This is how other members see your profile", and **Edit profile**.

### Settings: `SettingsScreen` (`settings/settings_screen.dart`)

The person, then **Account** (Sign-in & security, Your companies with "Acting for {company}" or "Acting as yourself", Saved items), **Preferences** (Language, Notifications), **Privacy & data** (Download my data, Delete my account), **About ICR** (Contact us, Terms of Service, Privacy Policy), **Sign out**.

- **Sign-in & security** (`SignInSecurityScreen`): the sign-in email with Confirmed / Not confirmed (**Confirm** opens the confirmation), **Change password** (sends the reset link to the account's own address), the **mobile number** with Verified / Not verified (only a number a code can reach is ever "not verified") and its sheet, **Edit contact info** (work email, a second number, the five links; the links go first because the API judges a web address, a refusal there writes nothing else; LinkedIn must be on LinkedIn only when it is being changed).
- **The mobile number sheet** (`showPhoneSheet`): a +91 number is confirmed (**Send code**, the six digits, **Verify**; a non-production API hands the code back and the sheet shows "Test mode: your code is 123456" with **Use code**); any other country's number is kept as typed (**Save number**: codes only go to Indian numbers); **Remove number**. The field is two parts (country and the digits, like the website: pasting `+44 7700 900123` switches the country, a trunk 0 is dropped, "Other country" takes the number with its code).
- **Language**: English, Hindi, Kannada, saved on the account (`PATCH /users/me {locale}`; English clears it). It sets the language of ICR's emails, notifications and replies; **the app's own screens stay in English for now**, and the sheet says so.
- **Notifications** (`NotificationPreferencesScreen`): every kind of update with an In app and an Email switch, saved the moment it is touched (only that row is sent), rolled back with the API's sentence when refused; receipts, support and security notices are always sent, their switches are drawn on and disabled.
- **Download my data**: `GET /users/me/export` shown as JSON with **Copy** and **Share**. **Delete my account**: says what happens, asks for the word DELETE, `DELETE /users/me` (anonymises and closes the account, ends every session), then the phone is signed out without a logout call.

### Companies (`companies/`): `MyCompaniesScreen`, `CreateCompanyScreen`

The list of companies the person belongs to with their role, place, size and what waits ("2 awaiting approval"), the **personal account** that is always there, **Awaiting approval** (requests with their note and **Withdraw**), **Create a company**, **Ask to join a company**. **Switch** and **Leave** and **Create** each return a **fresh token pair** (the role rides in the token): the screen adopts it through `AuthController.adoptSession`, calls `onSessionChanged` so the app drops what it cached for the previous company, and reads the list again. The only admin cannot leave (the row says so, no Leave button); a refused leave stays inside its dialog. **Create a company page** is one screen like LinkedIn's: name, industry, head-office city, size, organisation type and the tick that the person may act for it, with website, logo, tagline and a different registered legal name optional; no tax ID, document or address; companies that look alike are offered with **Ask to join** (a suggestion, never a block); it ends on a welcome page (team, verify, sell, details) whose steps call `onNextStep`.

### Saved items (`saved/`): `SavedItemsScreen`

One chip per kind (Jobs, Mentors, Suppliers, Councils, Discussions) each with its count, read at once and failing alone; a card per kind; the bookmark un-saves at once with **Undo**; a closed job shows as closed; "Show more" pages; every empty state points to where to save one.

### Network (`network/`): `networkRoute`; Contact (`contact/`): `contactRoute`

The website's `/network` (the feed of the people the member follows, who to follow with the API's reason, Following, Followers, Follow / Following with an "Unfollow?" question) and `/contact` (the form with the seven topics, filled from the signed-in person, validated as `CreateContactDto` and refused with the API's sentences, "Message sent", Send another). Both were audited and proved here (see below).

## Every control and the test that proves it

`P` = `test/account_profile_test.dart`, `C` = `account_career_test.dart`, `M` = `account_member_test.dart`, `T` = `account_settings_test.dart`, `H` = `account_phone_test.dart`, `K` = `account_companies_test.dart`, `V` = `saved_test.dart`, `N` = `network_test.dart`, `X` = `contact_test.dart`, `L` = `test/live/account_live_test.dart`.

| Control | Does | Proved by |
|---|---|---|
| Profile: every section, loading, a failed section with its own Try again, pull to refresh, 320 x 568 | | P "the page" |
| Share profile, Copy link, View public profile, the gear, the Sign-in & security row | the share sheet gets the public link; the link is copied; the lead's callbacks | P "Share profile…", "View public profile…" |
| Intro pencil | the sheet with what the profile says; saves name, headline, years, then the résumé; refusals before any call; the headline's suggestions; the API's refusal kept above the buttons; Cancel asks to discard; no change closes without a call; the city | P "the intro" (7 tests); L "the intro…" |
| Photo / cover | upload then set; Remove asks first; a picture over 5 MB or a refused upload; a ready-made cover; your own; remove; the colour band stands in when the art cannot be fetched | P "the photo and the cover" (6 tests); L "the photo is uploaded and set, served back, then removed; the cover too" |
| About, Skills, Languages | empty prompts, See more, add by suggestion / typing / Enter, once whatever the case, at most eight languages, save through the right endpoint | P "about, skills and languages" (7 tests); L "About, Skills and Languages" |
| The checklist, Add section | each missing item opens its sheet; the picker lists what can be added | P "the checklist and Add section" |
| Experience | list in date order with how long; add (typed, whole-list save); every validation message; end before start and a future start; edit and delete (asks first); a company picked from ICR is linked and **Ask to join** goes first; unticking; a refused request saves nothing; a company already joined is not offered; the API's refusal keeps what was typed; "I work here now" | C "experience" (13 tests); L "a role is added, edited and deleted…" |
| Career breaks and gaps | add, validate, edit, delete; a gap of six months or more with Add a career break (dates filled in); a shorter one is not a gap | C "career breaks and gaps" (5 tests); L "a qualification and a career break…" |
| Education | list, add (blanks left out), validate, edit, delete | C "education" (4 tests); L same |
| Credentials | ICR's are read-only and open the certificate; add with name, code in capitals, issuer, date and certificate; validation; edit and remove the file; delete asks first and says when a claim was taken off the mentor profile; a file over 10 MB | C "credentials" (6 tests); L "a credential is added with its certificate…" |
| Member page | the header, every section, nothing for an empty one, id or slug, loading / not available / a failure with Try again, the discussions failing alone, pull to refresh | M "what the page shows" (8 tests); L "Anita's page as Bharat sees it", "a member who does not exist" |
| Follow, Message, Mentor profile, Share | Follow flips at once and counts; a refused follow goes back with the sentence; Message opens the thread and hands its id to the app; a refused one; the mentor button | M "Follow and Message"; L "Follow and Unfollow…", "Message finds or opens the one plain thread…" |
| A role's company, a chapter, a council, a discussion, the member's links and credential link, Share | each calls the lead's callback with its id or slug, or opens in the browser | M "the pages it opens" |
| The person's own member page | no Follow / Message, the note, Edit profile | M "the person's own page" |
| Settings rows | the person and every group; "Acting for…"; View profile, Your companies, Saved items, Contact us call out; Terms and Privacy are the only rows that open the website | T "settings" (6 tests) |
| Sign out | asks first, ends the session on the phone and at the API | T "Sign out asks first…" |
| Language | Hindi saves `locale`; English clears it; the same language closes without a call; a refusal stays open | T "language" (3 tests); L "the language is saved…" |
| Notifications | every kind with its words; a switch sends only its own row; locked ones cannot change; a refusal rolls back and says why; a failed read; pull to refresh | T "notification preferences" (5 tests); L "notification preferences…" (also proves a locked kind refuses) |
| Download my data, Delete my account | the export reads, shows, copies and shares; a refused export; DELETE must be typed, then the account closes and the phone signs out without a logout call; a refused deletion keeps the session | T "privacy and data" (4 tests); L "Download my data…", "Delete my account anonymises it…" |
| Sign-in & security | the email with its confirmation, the verified number, the links; Confirm; Change password to the fixed address; a number no code can reach is never "not verified"; a failed read | T "sign-in & security" (5 tests) |
| The mobile number | add an Indian number: Send code, the test code and Use code, Verify; a wrong code under the field; a short code waits; Send a new code; changing the number goes back to Send code; a mistyped number refused in the website's words; another country's number: Save number; Remove number; a verified number | T "the mobile number" (7 tests); L "another country's number is kept…" (a code cannot be sent to it; the Indian one is confirmed with the code the API hands back; a wrong code is refused) |
| Contact info | work email, second number and links together (https:// added); a blank field clears it; refusals before any call; the API's refusal of a link above the buttons, nothing else written | T "contact info" (4 tests); L "contact info…" |
| The phone-needed sheet (`askForPhone`) | never asked of someone with a number (returns `''`); with none the sheet says who needs it and returns the number to send as `phone`; refusals; backing out returns null; an unreadable profile asks anyway; the two-part field (country, digits, paste, Other) | H (15 tests); L "PhoneNeededController…" |
| My companies | rows, Active, counts; loading / failed / pull; no company; staff; search from six; View page | K "the list" (6 tests); L "my companies…" |
| Switch / personal / Leave | the fresh pair adopted, the app told, the row Active; a refusal; one action at a time; Leave asks first and says what is lost; the only admin cannot leave; the refusal stays in the dialog | K "acting for…", "leaving" (7 tests); L "found a company, a second person asks to join, the admin approves, they switch and leave", "Anita: switch into TechCorp and back…" |
| Requests to join | Withdraw; an already decided request; Ask to join with a note | K "requests to join", "the ask-to-join sheet on its own" (7 tests); L "found a company…" |
| Create a company page | sends exactly what was chosen, adopts the new session, welcome steps call out; every missing detail named and fixed one by one; the legal name and website rules; a refusal keeps the answers; lookalikes with Ask to join; the logo (size, type, Remove); Cancel asks to discard | K "create a company page" (9 tests); L "found a company…", "the create form is refused with the API's own sentences" |
| Saved items | the mapping of every kind from the real answers, every state, chips, un-save with Undo | V (23 tests); L "saved items" (every kind: read, saved, read back, un-saved) |
| Network | the lists, Follow / Following, the website fallbacks, small phones | N (77 tests); L "network" |
| Contact | every validation, refusal, the sent card, pull to refresh (a pull only starts at offset 0: the test drags to the top first), the sample source | X (69 tests); L "contact" |

## Audit findings (26 Oct), fixed

- `organisationLogoUrl` (not `logoUrl`) is the role's logo field; credentials carry an `href`.
- `GET /councils` pages as `{ data }`; a wrong email code is a **401** with "That code is not right. Check the email and try again."; joining a company moves someone acting for none into it; `GET /users/me/profile` reads the about text, title and place from the résumé's `content` JSON, so a résumé written only to its columns (some seeds) shows no About on the person's own page while `/members/:id` shows it.
- A double tap sent two requests on Forgot password and Reset password: both now ignore a tap while one is on its way.
- Saved jobs in another currency are written in thousands and millions, only rupees in lakh and crore.
- The tests that sign in inside `testWidgets` hung (the HTTP stack needs real turns of the event loop): `AccountHarness.signIn(tester)` does it inside `runAsync`.

## Constructors the lead wires

All screens take their repository from the app's `ApiClient` in `Provider` when none is passed (the sample member in demo mode), so each needs no arguments; the callbacks below are for paths into the rest of the app, and each falls back to the website's page (or to this feature's own screen) when left out.

```dart
// lib/app_screens.dart (profile menu rows), keyed by the website path they replace
'/profile':        (ctx) => MyProfileScreen(                      // "View Full Profile", and Settings' "View profile"
                      onBack: () => Navigator.of(ctx).pop(),
                      onOpenPublicProfile: (userId) => push(ctx, MemberProfileScreen(userId: userId, /* callbacks below */)),
                      onOpenSettings: () => push(ctx, const SettingsScreen()),
                      onOpenSecurity: () => push(ctx, const SignInSecurityScreen()),
                      onOpenCertificate: (credential) => /* the learning / mentoring certificate for credential.href */),
'/profile?tab=security': (ctx) => const SettingsScreen(),         // the drawer's "Settings"  (or SignInSecurityScreen())
'/career/saved':   (ctx) => SavedItemsScreen(onOpenJob: …, onOpenMentor: …, onOpenSupplier: …, onOpenCouncil: …, onOpenThread: …, onOpenCompany: …),
'/account/companies':     (ctx) => MyCompaniesScreen(onSessionChanged: …, onOpenCompany: …, onNextStep: …),
'/account/companies/new': (ctx) => CreateCompanyScreen(onSessionChanged: …, onNextStep: …),
'/network':        (ctx) => networkRoute(ctx, onOpenProfile: (id) => push(ctx, MemberProfileScreen(userId: id))),
'/contact':        (ctx) => contactRoute(ctx),
// "Certificates & badges": MyProfileScreen(initialSection: ProfileSection.credentials) scrolls to the credentials.
```

- **`MemberProfileScreen(userId: …)`** (id or slug): `onMessage(conversationId, member)`, `onOpenMentor(mentorProfileId)`, `onOpenCompany(companyId)`, `onOpenChapter(slug)`, `onOpenCouncil(slug)`, `onOpenThread(slug)`, `onEditProfile`. Use it for every person's name or photo in the app (the feed, replies, mentors' lists): `NetworkScreen.onOpenProfile` and the profile menu's `/members/<slug>` rows should open it.
- **The sign-up route from sign-in** is already wired by `SignInScreen` (`const SignUpScreen()`, `ForgotPasswordScreen`), see `signup.md`.
- **The phone-needed sheet** other features call before an action that needs a mobile number (applying for a job, asking a mentor, a supplier enquiry, a plan checkout):

```dart
final phone = await askForPhone(context, repository: accountRepositoryOf(context), reason: 'So the employer can call you.');
if (phone == null) return;                       // backed out: do not run the action
await api.post('/jobs/$id/apply', data: {..., if (phone.isNotEmpty) 'phone': phone});   // '' = the profile has one already
```

  or, inside a form, `PhoneNeededController(lookup: …)` + `PhoneNeededField(controller:, reason:)`, `controller.check()` before sending and `controller.payload` (a `{'phone': …}` map or nothing) in the body. The API saves the number with the action and refuses the action when there is still none (`PHONE_NEEDED.*`). Everything is in `lib/features/account/phone/phone_sheets.dart`.
- **Company switching** is `MyCompaniesScreen` (above); a quick switcher elsewhere would call `AccountRepository.switchCompany` and `AuthController.adoptSession`, exactly as `CompaniesController` does.
- **Picker for photos** is `file_picker` (already in `pubspec`); screens take a `PhotoPicker` so a test hands in a file.

## Handoffs kept

Terms of Service and Privacy Policy (Settings). A ready-made cover's picture is fetched as a static image from the website (`/images/profile-covers/*`, over its colour band) and falls back to the band: no page is opened.

## Dependencies on other builders' files (tell the lead)

`lib/features/network/*` and `lib/features/contact/*` import `../chapters/community_api.dart` and `../chapters/community_kit.dart` (the chapters builder's shared kit: `CommunityApi`, `ApiPage`, `FeedPicture`, `CommunityPage`). They compile today; if the chapters builder renames or moves them, those two features break. Moving the kit to `lib/core/widgets` would settle it.

## Seed: `tool/seed/account.ts`

Idempotent, marked, removable (`--remove`, `--cleanup-live`). Run after `home.ts` and `learning-jobs.ts` (add `account` after `home` in `run.ps1`). It gives **Bharat Buyer** a member place at **TechCorp** (an ACTIVE membership he is *not* switched into, so his role and every other screen's tests are unchanged), his current role linked to its page, languages, a LinkedIn link, an earlier role, a self-declared credential and an about text and place in his résumé's `content`; and creates **Anita Account** (`acct.persona@account-design.icr.test` / `Account@12345`, a PROFESSIONAL), the person the write tests change: two roles, a degree, a career break, skills, languages, an unverified +91 number, a LinkedIn link, places at Northwind and TechCorp, a request waiting at Harbour Estates. Each run resets her. `--cleanup-live` removes what the live tests leave (throwaway people, companies, contact messages). What it changed in Bharat is kept in Setting `design-seed:account` and put back by `--remove` (verified: his links, languages, companies and role link return to what they were).

## Left

- Pixel matching of these screens (postponed by the owner). The profile menu is the only designed one.
- Not built on the person's profile: the résumé library, the profile analytics card, "Open to / ready for my next role" and job preferences, the diversity declaration, the mentors card. (The sign-up's "ready for my next role" tick is written; nothing reads or edits it afterwards.)
- No app translation yet: Language only sets what ICR's server sends.
- Not exercised on a device: the platform pickers (`file_picker`), the share sheet (`share_plus`), the clipboard.
