# Account: the person's profile, member pages, settings, companies, saved items, network, contact

Everything the website's `/profile`, `/members/[id]`, `/account/companies`, `/network`, `/contact` and the profile menu's Settings do, in the app, against the real API, with no handoff to the website except the Terms and Privacy pages (Settings). Built as flows first (26 Oct 2026): the layout follows the app's own language (Work Sans headings, Plex Sans body, 12 dp hairline cards, pill buttons, the profile menu's header: cover, photo across its edge, name with the confirmed-email tick, headline, place); **pixel matching to a design is postponed** (no design exists for these screens except the profile menu, `docs/screens/profile_menu.md`).

Files: `lib/features/account/` (profile, members, settings, phone, companies, saved), `lib/features/network/`, `lib/features/contact/`; sign-up and recovery are `docs/screens/signup.md`.
Tests: `test/account_profile_test.dart`, `account_career_test.dart`, `account_member_test.dart`, `account_settings_test.dart`, `account_phone_test.dart`, `account_companies_test.dart`, `saved_test.dart`, `network_test.dart`, `contact_test.dart` (widget, against `DemoAccountRepository`, the in-memory stand-in that behaves as the API does and logs every call, or `FakeApi` in `test/helpers/account_harness.dart`), and `test/live/account_live_test.dart` (the local API; `flutter test --concurrency=1 test/live/account_live_test.dart`).
Seed: `tool/seed/account.ts` (see the end). Backend requests: none (`docs/backend-requests/account.md`).

## What each screen is

### The person's profile: `MyProfileScreen` (`profile/my_profile_screen.dart`)

One page of read-only section cards (LinkedIn's layout, the website's `ProfileWorkspace`); nothing on the page is a form: each section is edited in a sheet (`showEditSheet`, the website's `SectionDialog`: title, form, Cancel/Save, "Discard your changes?" when leaving with edits, the API's own refusal above the buttons with what was typed kept, Save with nothing changed closes without a call). Each section **reads and fails on its own** (a list that cannot be read says "Couldn't load your education" with its own Try again; the rest of the page stays), and a pull reads everything again.

Header (`ProfileHeader`): cover, photo, name, the blue tick when the sign-in email is confirmed, the role chip, headline, then **LinkedIn's line "Company · School"** (`affiliation`, since 14 Nov 2026, owner: "the Company name and education gets displayed in profile from the selection they have made"), then "place · **Contact Information**" (since 14 Nov 2026), "12 years in the profession", **Add section**, **View public profile**. The line comes from `introLine` (`profile/intro_line.dart`): the current role that started last (the API's `personCompanyLabel` order) and the newest qualification, or what Edit Intro's Organisation and Education chose; with no current role it names the company the person acts for, and "Please Select" leaves that half out. A member's page (`MemberProfileScreen`) draws the same line from their experience and education with the default rule. The camera on the cover opens the covers; the photo opens the photo sheet; the pencil opens the intro. A **Profile strength** card lists what is missing and each item opens the sheet that finishes it (`resolvePersonalTask`).

| Section | Sheet |
|---|---|
| Intro | first name (required), last name, **headline** (suggestions from the staff's job-title list), years 0–60, location (a city from the list); writes `PATCH /users/me` and, for anyone with a résumé, `PATCH /users/me/resume` (title and place). Then, as LinkedIn's Edit intro (owner, 14 Nov 2026): **Organisation** (a list of the current roles, each with its title under it, and "Please Select"), **+ Add New Position**, **Education** (the qualifications, each with its degree, and "Please Select"), **+ Add New Education** (both open their own sheet over the intro), and **Contact Information** with **Edit Contact Information** (the contact sheet). A list with nothing to offer is off and says what to add. The two choices are kept **on the phone, per account** (`SecureIntroChoiceStore`, key `icr.profile.intro.v1.<userId>`): the API has no field for them (`PATCH /users/me` strips unknown keys, and `PUT /profile/experience` stores rows in date order whatever order is sent), so other members and the website see the default line. A save that only changes them makes no API call. The website's intro has neither list. |
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

The person, then **Account** (Sign-In & Security, My Companies — a plain row since 13 Nov 2026, with no "Acting for {company}" / "Acting as yourself" line under it — and Saved Items), **Preferences** (Language — English, Hindi, Kannada, and since 9 Nov 2026 Spanish, Arabic and Chinese, the six the website offers; Notifications; and since 9 Nov 2026 **Background Activity & Permissions**, which opens the phone's own page for ICR — App info — where battery → unrestricted lets it keep running in the background and notifications and location are allowed; `Geolocator.openAppSettings()`, with a sentence saying where to find it when the page cannot open), **Privacy & Data** (Download My Data, Delete Account), **About ICR** (About ICR — the website's About page drawn by the app, `AboutScreen`, since 7 Nov 2026 — Contact Us, Terms of Service, Privacy Policy), **Sign Out** ("Sign Out of ICR?" asks first). The words are the client's standard since 13 Nov 2026 (the last section).

- **Sign-In & Security** (`SignInSecurityScreen`): under **Sign-In**, the **Email** with Verified / Not Verified (**Verify** opens the verification) and **Password** with **Change** ("Reset your password using a secure email link."; it sends the reset link to the account's own address); under **Contact Information**, the **Mobile Number** with Verified / Not Verified (only a number a code can reach is ever "Not Verified") or "Not added" with **Add**, and its sheet, then **Work Email**, **Alternate Mobile Number** and the links when the profile has them; the pencil, **Edit Contact Information** (work email, a second number, the five links; the links go first because the API judges a web address, a refusal there writes nothing else; LinkedIn must be on LinkedIn only when it is being changed).
- **The mobile number sheet** (`showPhoneSheet`): a +91 number is confirmed (**Send code**, the six digits, **Verify**; a non-production API hands the code back and the sheet shows "Test mode: your code is 123456" with **Use code**); any other country's number is kept as typed (**Save number**: codes only go to Indian numbers); **Remove number**. The field is two parts (country and the digits, like the website: pasting `+44 7700 900123` switches the country, a trunk 0 is dropped, "Other country" takes the number with its code).
- **Language**: English, Hindi, Kannada, saved on the account (`PATCH /users/me {locale}`; English clears it). It sets the language of ICR's emails, notifications and replies; **the app's own screens stay in English for now**, and the sheet says so.
- **Notifications** (`NotificationPreferencesScreen`): every kind of update with an In app and an Email switch, saved the moment it is touched (only that row is sent), rolled back with the API's sentence when refused; receipts, support and security notices are always sent, their switches are drawn on and disabled.
- **Download My Data**: `GET /users/me/export` shown as JSON with **Copy** and **Share**. **Delete Account**: says what happens, asks for the word DELETE, `DELETE /users/me` (anonymises and closes the account, ends every session), then the phone is signed out without a logout call.

### Companies (`companies/`): `MyCompaniesScreen`, `CreateCompanyScreen`

The list of companies the person belongs to with their role, place, size and what waits ("2 awaiting approval"), the **personal account** that is always there, **Awaiting approval** (requests with their note and **Withdraw**), **Create a company**, **Ask to join a company**. **Switch** and **Leave** and **Create** each return a **fresh token pair** (the role rides in the token): the screen adopts it through `AuthController.adoptSession`, calls `onSessionChanged` so the app drops what it cached for the previous company, and reads the list again. The only admin cannot leave (the row says so, no Leave button); a refused leave stays inside its dialog. **Create a company page** is one screen like LinkedIn's: name, industry, head-office city, size, organisation type and the tick that the person may act for it, with website, logo, tagline and a different registered legal name optional; no tax ID, document or address; companies that look alike are offered with **Ask to join** (a suggestion, never a block); it ends on a welcome page (team, verify, sell, details) whose steps call `onNextStep`.

**Create a company page, matched to the website (6 Nov 2026).** Read against `frontend/src/app/(app)/account/companies/new/page.tsx`, `components/companies/new/*`, `CreateMyCompanyDto` and `AccountCompaniesService.create`; the form's fields, order, required marks, limits and sentences already matched, and these did not:

- **Who may open it.** Anyone signed in except ICR staff (`PLATFORM_ROLES`: SUPER_ADMIN, LEARNING_ADMIN, PARTNER_ADMIN), whose accounts are personal. The page reads `GET /me/companies` on opening; with `canJoinCompanies: false` it shows the website's card ("Staff accounts don’t create companies" / "ICR staff accounts are personal: they do not create or join companies.") instead of the form (`key create.staff`); the API refuses the same people with a 403 in its own sentence. A member already acting for a company may found another (the new one becomes the active one). `POST /me/companies` allows five an hour from one address.
- **`?role=`** (`COMPANY_ADMIN`, `VENDOR`, `BUYER` on the marketing links) changes nothing on the website's page: it is never read (the creator is always COMPANY_ADMIN of the new company, and they land on the same welcome). The app reads none either. The only query the page reads is `?partner=1`, not built here (see below).
- **Website** is judged by the website's `isWebsiteUrl` rule for rule (`isWebsiteUrl` / `websiteProblem` in `create_company_controller.dart`): http, https or ftp only, no whitespace, at most 2,084 characters, two or more dot-separated labels of letters, digits and inner hyphens, a letters-only top level (or `xn--`), an IPv4 address allowed, no underscore, no port above 65535. The looser `_isWebsite` in `account_rules.dart` is no longer asked for the website (that file is not this screen's; delete it when convenient).
- **Documents** (new): once an organisation type is chosen, its optional documents open under it (`CompanyDocumentsPanel`): the registration certificate (only for private/public limited, LLP, partnership, trust/NGO, named for the type), the PAN card and the GST certificate, each a PDF or picture up to 10 MB uploaded PRIVATE (`purpose=employer-kyc`) and sent as `incorporationDoc*`, `panDoc*`, `gstDoc*`; a type with no certificate says so; only the documents the final type is offered are sent. `FoundingDraft` (in the controller file) carries them on top of `CompanyDraft`.
- **Head office beyond ICR's cities.** The picker is now ICR's own city list plus, from two letters, any place in the world from `GET /locations/search` (a place ICR already lists is left out; only an Indian place passes its state on), as the website's "Elsewhere" search does. "No city by that name yet" when nothing matches.
- **Logo** sentences are the website's: "That is not an image. Choose a PNG, JPG or WEBP file.", "GIF files are not accepted. Use PNG, JPG or WEBP.", "That image is over 2MB. Compress it or choose a smaller one.", "Upload failed. Please try again.". The logo row is always offered (the phone's own picture chooser when the lead hands none in; it was hidden before).
- **A refused Create** shows the API's sentence (a validation list joined with a space, as the website joins it), else "Could not create the company page."; the 429 keeps the app's own line (the website would print the limiter's "Too Many Requests").
- **Ask to join** on a suggestion shows "Request sent" for a company the person had already asked before opening the page, not only for one asked from here.
- Not built, deliberately: the website's side rail (live page preview, "Ready to create" tick list, "After you create it" notes) on a phone's single column; the square-crop dialog before a logo uploads; opening an uploaded private document from its chip; the `?partner=1` tick ("Apply to add partner courses", then to the dashboard), because the app's partner application is its own screen (`PartnerApplyScreen`, which pushes a bare `CreateCompanyScreen`).
- To wire (other files): `LookalikesCard` has no "Accept from Your companies" chip for a company that has already added the person (the website's `standing.invited`); every `CreateCompanyScreen()` push in `app.dart`, `app_screens.dart`, `app_search.dart`, `app_site_pages.dart`, `app_notifications.dart` and `marketplace_navigation.dart` passes no `onNextStep`/`onViewCompany`, so the welcome steps are plain notes and a suggestion has no View page; `MyCompaniesScreen` does pass them.

**The owner's wording (12 Nov 2026, the annotated atlas "04-profile-account", pages 5–6).** On **My Companies** (the title, title case): the intro sentence and the three tips ("How it works": one company at a time, your profile stays yours, every company keeps an admin) are gone; "All workspaces" reads **All Companies** and its line **Switch between companies**. The website's "Currently acting as" card has no counterpart here (the active company wears **Active** in the list). On **Create a company page**: the intro reads "Create a company page to post your services, products, participate in RFQ’s, post jobs or courses."; the first block is **Company Details** with no subtitle (the second block keeps "Company details", without its "Used to match it…" line); **Company Name** with the helper **Company Brand Name / Legal Name**; **Company Size · No. of Employees**; **Organisation Type**; a new optional **Year Founded** (`CreateMyCompanyDto.foundedYear`, refused outside 1800 to this year with the shared rule's "Enter a year between 1800 and {year}.", its range said under the field) at the foot of Company details; **Logo and Tagline**, the tagline with no placeholder, helper or counter; the tick reads "I agree to the terms and policies of ICR and I am an authorised representative of {company} to create and manage this page on ICR." with no line under it; and the "You become the page’s admin…" line above the buttons is gone. Still as before, and why: the industry list is Master Data's (`GET /masters`), so staff already add and retire industries; company sizes (`COMPANY_SIZES`) and organisation types (`LegalStructure`) are fixed lists the API validates, so making them staff-managed is a portal change; the head office is a type-to-search over ICR's cities and `/locations/search`, not Google's suggestions; the website's side rail ("After you create it", the preview and its note) is not drawn on a phone, and the welcome page after creating carries the steps.

### Saved items (`saved/`): `SavedItemsScreen`

One chip per kind (Jobs, Mentors, Suppliers, Councils, Discussions) each with its count, read at once and failing alone; a card per kind; the bookmark un-saves at once with **Undo**; a closed job shows as closed; "Show more" pages; every empty state points to where to save one.

### Network (`network/`): `networkRoute`; Contact (`contact/`): `contactRoute`

The website's `/network` (the feed of the people the member follows, who to follow with the API's reason, Following, Followers, Follow / Following with an "Unfollow?" question) and `/contact` (the form with the seven topics, filled from the signed-in person, validated as `CreateContactDto` and refused with the API's sentences, "Message sent", Send another). Both were audited and proved here (see below).

## Every control and the test that proves it

`P` = `test/account_profile_test.dart`, `C` = `account_career_test.dart`, `M` = `account_member_test.dart`, `T` = `account_settings_test.dart`, `H` = `account_phone_test.dart`, `K` = `account_companies_test.dart`, `V` = `saved_test.dart`, `N` = `network_test.dart`, `X` = `contact_test.dart`, `L` = `test/live/account_live_test.dart`.

| Control | Does | Proved by |
|---|---|---|
| Profile: every section, loading, a failed section with its own Try again, pull to refresh, 320 x 568 | | P "the page" |
| Share profile, Copy link, View public profile, the gear (the profile's own Sign-in & security row was removed on 12 Nov 2026, the owner's call: it is in Settings, behind the gear) | the share sheet gets the public link; the link is copied; the lead's callbacks | P "Share profile…", "View public profile…" |
| Intro pencil | the sheet with what the profile says; saves name, headline, years, then the résumé; refusals before any call; the headline's suggestions; the API's refusal kept above the buttons; Cancel asks to discard; no change closes without a call; the city | P "the intro" (7 tests); L "the intro…" |
| Company · School line, Organisation and Education | the rule (current roles only, newest first, one per company; the choice; "Please Select"; a chosen company that ended; the acting company); the choice kept per account; the line under the headline and the place on its own; each list with its subtitle; a pick saves with no API call and the sheet reopens on it; Cancel after a pick asks to discard; empty lists off with what to add; Add New Position / Education; Edit Contact Information; 320 x 568 | `account_profile_intro_test.dart` (14 tests); M "the header…" |
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
| Settings rows | the person and every group; "Acting for…"; View profile, My companies, Saved items, Contact us call out; About ICR, Terms and Privacy go through the opener, which finds the app's own screens for their pages | T "settings" (6 tests) |
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
| Create a company page | sends exactly what was chosen, adopts the new session, welcome steps call out; every missing detail named and fixed one by one; the legal name and website rules; a refusal keeps the answers; lookalikes with Ask to join; the logo (size, type, Remove); Cancel asks to discard; (6 Nov) staff get the personal-account card; a second company for a member in one; requests already sent; the documents (per type, 10 MB, private upload, dropped with the type, Remove); a head office abroad; the website's website rule case by case; the logo and refusal sentences; `POST /me/companies` body | K "create a company page" (9 tests); L "found a company…", "the create form is refused with the API's own sentences" |
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

## 7 Nov 2026

A new company's "View page" (and a company picked in the companies directory) opens the company's page **in the app** (`openCompanyInsightsById` with the shell's jobs source), not the website's, where its own member was offered a review of it.

## 9 Nov 2026

**Background activity & permissions** (owner: "background running permissions also need to be enabled for the app"): a Settings row (key `settings.background`) under Preferences opens Android's App info page for ICR, where the person sets battery to unrestricted and allows notifications and location; `POST_NOTIFICATIONS` is in the manifest for Android 13+. The app still sends no push notifications (no FCM project yet), so "running in the background" today means the socket, the bell polling and the TTS reader keep going when the phone lets them; a real background notification needs push, which is a separate piece of work.

**Languages** (bug sheet, 9 Nov 2026): the Language sheet offers the six the website has live (`ENABLED_LOCALES` on prod: en, hi, kn, es, ar, zh); the app's own screens stay English, as the sheet says.

## 13 Nov 2026: copy refined to the client's standard

The client marked up the app's user manual (sections 1.5, 2.2, 4.1 and 4.2) with the words they want in Settings, on Sign-In & Security, in the sign-out confirmation and on the Discover sheet, and asked for the rest to follow the same style. Files: `settings/settings_screen.dart`, `security_screen.dart`, `contact_sheet.dart`, `settings_sheets.dart`, `notification_preferences_screen.dart`, and one label in `discover/discover_sheet.dart`. Layouts are unchanged; one row lost its second line.

| Where | Old | New |
|---|---|---|
| Settings: the companies row (client) | My Companies, with "Acting as yourself" / "Acting for {company}" under it | My Companies, with no line under it (the screen no longer reads `GET /me/companies`) |
| Settings rows (client) | Saved items · Delete my account · Sign out | Saved Items · Delete Account · Sign Out |
| Settings: the security row and that screen's title (client) | Sign-In and Security | Sign-In & Security |
| Settings: other rows and a group, to Title Case (6) | View profile · Background activity & permissions · Privacy & data · Download my data · Help & support · Contact us | View Profile · Background Activity & Permissions · Privacy & Data · Download My Data · Help & Support · Contact Us |
| Settings: line under Background Activity | Let ICR run in the background; location and notifications | Background running, location and notifications |
| Sign-out confirmation (client) | Sign out of ICR? · You will need to sign in again on this phone. · Cancel / Sign out | Sign Out of ICR? · You will need to sign in again to access your account on this device. · Cancel / Sign Out |
| Security: sections (client) | Sign in · Contact Info | Sign-In · Contact Information |
| Security: email state (client) | Confirmed · Not confirmed · Confirm | Verified · Not Verified · Verify |
| Security: under Password (client) | Change it with a link sent to {email} | Reset your password using a secure email link. |
| Security: labels (client) | Mobile number · Work email · Alternative number | Mobile Number · Work Email · Alternate Mobile Number |
| Security: the mobile chip, pencil tooltip, snackbar | Not verified · Edit contact info · Contact info saved. | Not Verified · Edit Contact Information · Contact information saved. |
| Security → Change (client) | Change your password | Change Password (the rest of that screen is in `signup.md`) |
| Contact sheet | Contact Info · Work email · Alternative contact number · Your sign-in. Contact support to change it. · Optional. A second number; your main one is confirmed separately. | Contact Information · Work Email · Alternate Mobile Number · Your sign-in email. Contact support to change it. · Optional. A second number. Your main number is verified separately. |
| Download sheet | Download my data · Get my data | Download My Data · Get My Data |
| Delete sheet | Delete my account (title and button) · Type DELETE to confirm · This removes your name, photo, phone number and what you told ICR about your career, closes your account and signs you out everywhere. What you posted for others (discussions, reviews) stays, without your name. It cannot be undone. | Delete Account · Type DELETE to Confirm · This removes your name, photo, mobile number and career details. It closes your account and signs you out on all devices. Your discussions and reviews stay, without your name. This cannot be undone. |
| Notification preferences | In app · Choose how ICR tells you about each kind of update: in the app, and by email. | In App · Select how ICR notifies you of each type of update, in the app and by email. |
| Discover sheet (client) | Post requirement | Post Requirement |

The Security screen only relabels what it already had. "Alternate Mobile Number" is the existing second number (`altPhone`), and it and Work Email still show only when the profile has them. The client's box shows **Verified** under Work Email: the app holds no verified state for a work email (`MyProfile` has only `workEmail`), so no chip was added there.

Kept as they were: the group names Account, Preferences and About ICR, **Language**, **Notifications** ("In the app and by email"), "Email, mobile number, password, links", **Terms of Service**, **Privacy Policy**, **Add** / **Edit** / **Change**, "Not added", "Mobile number saved.", "Language saved.", the Language sheet's line, "Always sent", and the share subject "My ICR data" (it becomes the file's name). The mobile number's own sheet (`phone/phone_sheets.dart`) and the links' names (`ProfileLinks.labels`) belong to other folders and were not touched here.

## 13 Nov 2026: copy refined to the client's standard (profile, mobile number, member page, Saved Items, companies)

Wording only (the client's 13 Nov marked-up manual: Title Case for names, sentences with a full stop, plain verbs, no
dash inside a sentence, "Unable to …" for a failure). Keys, layout and behaviour are unchanged. Settings and
Sign-In & Security (`settings/`) were refined separately. **The 12 Nov wording is kept word for word**; where one of
those strings is a title, button or label, only its capitals were brought into line (Create a company page →
Create a Company Page).

**Profile** (`profile/`, `widgets/account_kit.dart`)

| Where | Old | New |
|---|---|---|
| Buttons, sheet titles, field labels, tooltips (about 75 strings, case only) | Add section · View public profile · Add profile section · Career break · Profile strength 85% · Finish your profile · Add a summary · Add education · Add credential · Add skills · Add languages · Your public profile · Copy link · Add a career break · Add a role · Edit intro · First name · Last name · Years of experience · Profile photo · Upload photo · Change photo · Remove photo · Remove cover · Upload your own · Replace your picture · Edit about · Edit skills · Edit languages · Add/Edit experience · Employment type · Start date · End date · Add/Edit education · School or institution · Field of study · Start year · End year · Add/Edit career break · Add/Edit credential · Short code · Issued by · Issue date · Expiry date · Verification link · Attach certificate · Share profile · Change cover · "Start date: month" | Add Section · View Public Profile · Add Profile Section · Career Break · Profile Strength 85% · Finish Your Profile · Add a Summary · Add Education · Add Credential · Add Skills · Add Languages · Your Public Profile · Copy Link · Add a Career Break · Add a Role · Edit Intro · First Name · Last Name · Years of Experience · Profile Photo · Upload Photo · Change Photo · Remove Photo · Remove Cover · Upload Your Own · Replace Your Picture · Edit About · Edit Skills · Edit Languages · Add/Edit Experience · Employment Type · Start Date · End Date · Add/Edit Education · School or Institution · Field of Study · Start Year · End Year · Add/Edit Career Break · Add/Edit Credential · Short Code · Issued By · Issue Date · Expiry Date · Verification Link · Attach Certificate · Share Profile · Change Cover · "Start Date: Month" |
| Questions before a delete or a discard (case only) | Delete this role? · Delete this qualification? · Delete this career break? · Delete this credential? · Remove your profile photo? · Discard your changes? · Removed from your mentor profile | Delete This Role? · Delete This Qualification? · Delete This Career Break? · Delete This Credential? · Remove Your Profile Photo? · Discard Your Changes? · Removed from Your Mentor Profile |
| A section that cannot be read | Couldn't load your education. / Try again | Unable to Load Your Education / Try Again |
| The page that cannot be read | Something went wrong / Try again | Something Went Wrong / Try Again |
| About, long text | See more · See less | View More · View Less |
| Experience, full | That is the most roles a profile holds. | You have added the maximum number of roles. |
| Chips field, full | That is the most you can add | Maximum number added |
| Delete questions' line | … will be taken off your profile. · Its certificate is deleted with it. | … will be removed from your profile. · Its certificate will also be deleted. |
| After a credential is deleted | … was also taken off your mentor profile, since it is no longer on your credentials. | … was also removed from your mentor profile because it is no longer in your credentials. |
| Discard question | What you changed here has not been saved. | Your changes have not been saved. |
| Photo | Couldn't open your photos. Check that ICR may read them and try again. · Your initials will show instead. · That file is too big. Choose one under 5 MB. | Unable to open your photos. Allow ICR to access them and try again. · Your initials will appear instead. · The file is too large. Choose one under 5 MB. |
| Credential file | Couldn't open your files. Check that ICR may read them and try again. | Unable to open your files. Allow ICR to access them and try again. |
| Credential sheet, lead | A certificate or licence you hold. ICR’s own are added for you. | A certificate or licence you hold. ICR certificates are added automatically. |
| Intro, headline helper | Your current role. It shows under your name. | Your current role. It appears under your name. |
| Placeholders | Choose a date · Choose a city · Choose one · Choose why you took this break | Select a date · Select a city · Select one · Select why you took this break |
| Organisation helper | Pick it from the list if it is already on ICR. | Select it from the list if it is already on ICR. |
| The sheets' refusals | Choose when you started. · Choose when the break started. · Choose why you took this break. · Choose a year from 1950 on. · Give the credential a name. · … or tick “I work here now”. · … or tick “I’m on this break now”. | Select when you started. · Select when the break started. · Select why you took this break. · Select a year from 1950 onwards. · Enter the credential name. · … or select “I work here now”. · … or select “I’m on this break now”. |
| Cities | Couldn't load the cities. Check your connection and try again. | Unable to load the cities. Check your connection and try again. |
| A picker's search with no match | Nothing matches “x”. | No results for “x”. |
| A role's employment type | Full-time · Part-time | Full-Time · Part-Time (as the Jobs screens say it) |

**Mobile number** (`phone/`, opened from Settings and from the actions that need a number)

| Old | New |
|---|---|
| Mobile number · Add your mobile number · Remove your number? · Remove number · Save number · Send code · Send a new code · Use code · 6-digit code · Other country | Mobile Number · Add Your Mobile Number · Remove Your Number? · Remove Number · Save Number · Send Code · Send a New Code · Use Code · 6-Digit Code · Other Country |
| We can only text codes to +91 numbers, so this one is saved as typed. | Codes can be sent only to +91 numbers, so this number is saved as entered. |

**A member's page** (`members/`)

| Old | New |
|---|---|
| Edit profile · Mentor profile · Share profile · Ready for a new role · Chapters & councils · Community activity | Edit Profile · Mentor Profile · Share Profile · Ready for a New Role · Chapters & Councils · Community Activity |
| This profile is not available · Something went wrong | This Profile Is Not Available · Something Went Wrong |
| Couldn't load their discussions. | Unable to load their discussions. |

**Saved Items** (`saved/`)

| Old | New |
|---|---|
| Saved items (title) · Show more · Try again · No longer open · Top mentor · Browse jobs · Find mentors · Open the Marketplace · See councils | Saved Items · View More · Try Again · No Longer Open · Top Mentor · Browse Jobs · Find Mentors · Open Marketplace · View Councils |
| No saved jobs yet (and mentors, suppliers, councils, discussions) | No Saved Jobs Yet |
| Tap the bookmark on a job on the Jobs board to keep it here. · Save a mentor from Find mentors to come back to them. · Save a supplier from the Marketplace to keep it here. · Bookmark a council on the Councils screen to find it here. | Tap the bookmark on a job to save it here. · Save a mentor from Find Mentors to view them here. · Save a supplier from the Marketplace to view it here. · Save a council from Councils to view it here. |
| Removed “Title” from saved | Removed “Title” from Saved Items. |
| Saving is not available here · Could not load saved jobs | Saving Is Not Available · Unable to Load Saved Jobs |
| This job has closed. See what else Acme is hiring for, or remove it. | This job has closed. View other jobs at Acme, or remove it. |
| On-site · Full-time · Part-time (a saved job's facts) | On-Site · Full-Time · Part-Time (as the Jobs screens say it) |

**My Companies and Create a Company Page** (`companies/`; the 12 Nov words kept)

| Where | Old | New |
|---|---|---|
| Buttons, headings, labels (case only) | Create a company page (title) · Create a company · Ask to join a company · Find your company · Personal account · Awaiting approval · Waiting for you · Switch to this company · Switch to personal account · View page · Leave company · Ask to join · Send request · Request sent · Company name · Registered legal name · Company website · Create page · Add logo · Start selling · Head office · Discard this company page? | Create a Company Page · Create a Company · Ask to Join a Company · Find Your Company · Personal Account · Awaiting Approval · Waiting for You · Switch to This Company · Switch to Personal Account · View Page · Leave Company · Ask to Join · Send Request · Request Sent · Company Name · Registered Legal Name · Company Website · Create Page · Add Logo · Start Selling · Head Office · Discard This Company Page? |
| Documents (case only) | PAN card · GST certificate · Registration certificate · Partnership deed or registration certificate · Documents for a private limited company (and the six other headings) | PAN Card · GST Certificate · Registration Certificate · Partnership Deed or Registration Certificate · Documents for a Private Limited Company |
| List, failed | Could not load your companies. (title and line) | Unable to Load Your Companies / "Unable to load your companies." |
| List, empty | You are not part of a company yet / "… or find your organisation in the directory and request to join." | You Are Not Part of a Company Yet / "… or find your company in the directory and request to join." |
| Staff, and a city search with no match | Staff accounts don’t create companies · No city by that name yet | Staff Accounts Don’t Create Companies · No city found with that name. |
| Ask to join, lead | Find your organisation on ICR. An admin there decides; until then nothing changes for you… | Find your company on ICR. An admin there decides. Until then nothing changes for you… |
| Ask to join, the note | Anything they should know (optional) | Note for the Admins (Optional) |
| Invitations | Could not accept that invitation. · Could not decline that invitation. | Unable to accept that invitation. · Unable to decline that invitation. |
| Leave, last point | You carry on as your next company, or as yourself if you have none. | You continue as your next company, or as yourself if you have none. |
| A look-alike | Not yours? Carry on below. This is only a suggestion. | Not your company? Continue below. This is only a suggestion. |
| Website helper | Optional — acme.com or https://acme.com | Optional. For example, acme.com or https://acme.com |
| Logo | PNG, JPG or WEBP — up to 2MB · Upload failed. Please try again. | PNG, JPG or WEBP, up to 2MB. · Upload failed. Try again. |
| Placeholders and helper | Choose a city · Choose how it is set up · Decides which documents verification asks for. | Select a city · Select how it is set up · Determines which documents verification requires. |
| Refusals | Choose the industry it works in. · Choose where the head office is. · Choose how many people work there. · Choose how the organisation is set up. · Enter the registered legal name — it needs at least one letter. | Select the industry it works in. · Select where the head office is. · Select how many people work there. · Select how the organisation is set up. · Enter the registered legal name. It needs at least one letter. |
| Create, failed | Could not create the company page. · … Try again a little later. | Unable to create the company page. · … Try again later. |
| Discard question | What you entered has not been saved. | Your entries have not been saved. |
| Welcome, Sell on ICR | Start selling to appear in Supplier Mart and answer buyers’ requirements. … | Start selling to appear in the Marketplace and answer buyers’ requirements. … |

Kept as the client gave them on 12 Nov: My Companies, All Companies, "Switch between companies", the Create page's
intro, Company Details, Company Name, "Company Brand Name / Legal Name", "Company Size · No. of Employees", Organisation
Type, Year Founded, Logo and Tagline, the agreement sentence, the profile's empty-section sentences ("You can write about
your years of professional experience…", "Add your work experience including career break if applicable.", "Your
Education, field of study and year of passing.", "Add your professional certifications and licenses."), Add Experience,
Licenses and Certifications and the four Profile Strength items. The second block's heading stays "Company details"
(the client kept it; in Title Case it would repeat the first block's heading word for word).

## 14 Nov 2026: Contact Information on the profile

Owner, with a phone screenshot of the profile: "Contact info button is missing". The website has had a "Contact Info" link after the location since its LinkedIn redesign (`ProfileHero.tsx`, which opens `ContactInfoDialog`). The app now has one too, called **Contact Information** because that is the client's one term for it (Settings, Sign-In & Security, 13 Nov).

- `ProfileHeader.onContactInfo` draws the link, blue and bold, after the location (the company and school moved to their own `affiliation` line the same day). It shows even when there is no place. Only the person's own profile passes it; a member's page is unchanged.
- `profile/sheets/contact_info_sheet.dart` (`showContactInfoSheet`) is read-only, like the website's dialog. It lists the profile address (opens the public page), Email (mailto), Work Email with Verified / Not Verified or **Add Your Work Email**, Mobile Number with its chip and **Edit** / **Verify** or **Add Your Mobile Number** (the number's own sheet), Alternate Mobile Number (tel), Birthday ("26 October", when set) and the links (open in the browser). The pencil, **Edit Contact Information**, closes it and opens the existing `ContactSheet`. The website's "Member since" row is left out because `GET /users/me/profile` does not return `createdAt`.
- `MyProfile` reads `workEmailVerified`, `birthMonth` and `birthDay`, which the API already sent.
- Tests: P "contact info" (6 tests).

