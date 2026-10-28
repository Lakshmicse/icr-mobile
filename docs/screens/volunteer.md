# Get Involved & Volunteer

`GetInvolvedScreen` (the opportunities, what they earn, the member's CPD) and `VolunteerApplyScreen` (the application). There is **no design**: it is built in the language of the Councils and Events designs from the website's `/get-involved` page (`components/marketing/get-involved/GetInvolvedLanding.tsx`) and the portal's mentorship (CPD) and marketing (contact) modules. The profile drawer's row ("Get Involved & Volunteer", "Earn certified CPD credits", "+12 CPD") and a chapter's "Volunteer with this chapter" open it.

Status (26 Oct 2026): **built and proved**: `test/volunteer_test.dart` (37 tests) and `test/live/volunteer_live_test.dart` (6 live tests). Goldens postponed.

## Entry points (for the lead to wire)

```dart
ChangeNotifierProvider<VolunteerController>(
  create: (c) => VolunteerController(
    sample ? DemoVolunteerRepository() : ApiVolunteerRepository(api: c.read<ApiClient>()),
  ),
  child: GetInvolvedScreen(
    onBack: () => Navigator.of(ctx).pop(),
    onBell: () => ...,            // optional; the website's /notifications page when null
    onBecomeMentor: () => ...,    // optional; the button is left out when null (the mentor application)
    onOpenChapters: () => ...,    // optional; the button is left out when null (Regional Chapters)
    intent: VolunteerIntent.chapter('ICR Bengaluru Chapter'),  // optional: opens the form at once
  ),
)
```

From `ChaptersScreen`/`ChapterScreen`, `onOpenVolunteer` is `ValueChanged<String?>`: the board gives `null` (open Get Involved as it is), a chapter's page gives the chapter's name (open it with `intent: VolunteerIntent.chapter(name)`: a committee seat at that chapter, the form open on arrival).

`openVolunteerForm(context, volunteer: controller, role:, chapterName:)` opens the application over any screen and returns true when the ICR team has it.

## Endpoints

| Call | Used for |
|---|---|
| `GET /mentorship/cpd/summary` | the CPD card: total hours, hours this year, hours by source, the ten latest entries (401 signed out reads as none) |
| `GET /mentorship/cpd/target` | the year's target, the year's hours and how far along (`isDefault` = the API's suggested 20 hours, not the member's own) |
| `GET /auth/me` | the form's name, email and phone |
| `GET /chapters?limit=100` | "Which chapter?" |
| `POST /contact` `{name, email, phone?, topic: "VOLUNTEER", message}` | the application |
| `GET /notifications/unread-count` | the bell's dot |

## What the API cannot do, and what is shown instead

1. **There is no volunteer endpoint.** The website's volunteer roles and benefits are constants in the frontend (`features/learning/data/volunteering.ts`) and "Apply" is a link to the contact form pre-filled with `topic=VOLUNTEER` (its source comment: "swap `applyHref` when a volunteer application endpoint exists"). The app does the same in-app: the 20 roles and 7 benefits are the same copy (`volunteer_data.dart`), and an application is `POST /contact` with topic VOLUNTEER, which the API files as a contact message and a CRM lead and tells the ICR inbox about. It is the website's own flow, not a handoff to the website.
2. **The application text is composed.** The contact form has one message box, so the application is: "Volunteer application: <role>", "Commitment: <time>", "Chapter: <name>", a blank line, then the person's own words. The 4,000-character limit is for the whole text, so the box allows what is left after those lines (`VolunteerApplication.messageRoom`).
3. **No list of applications.** The API gives no way to read back what a member sent, so a role says "INTEREST SENT" (and Apply becomes "Apply again") only for this visit.
4. **CPD credits are the API's ledger, not a schedule.** `CpdSource` is MENTORING, EVENT, COURSE, CERTIFICATION or MANUAL: there is no VOLUNTEER source, and volunteer hours are recorded by ICR as MANUAL entries ("Manually recorded"). The card shows what the member has (hours earned, this year against the target, by source, the latest entries). The website's three chips ("Mentoring: 12 credits", "Volunteering: 10 credits", "Committee: 12 credits") are ICR-authored copy and stay as copy, labelled as such in `volunteerCreditCopy`.
5. `POST /contact` is public and throttled to 5 a minute per IP: a refusal shows the app's "Too many requests. Wait a minute and try again." with everything typed kept.

## The screen

The headline ("Volunteer, lead, shape the profession") with **Volunteer with ICR** (the form with no role), **Become a mentor** and **Find your chapter** (the shell's callbacks); **Your CPD** (signed in: Hours earned and the year's hours against the target with a progress bar, "57% of your 15-hour target" or "of the suggested 15 hours", the hours by source, three latest entries; signed out: "Sign in to see the CPD hours you have earned."; a failed read: its sentence and Try again); **Volunteer Opportunities** (20, searchable by title, description or duty, "No role matches" + Clear search); each **role card**: glyph, title, description, **Responsibilities** (opens to four duties), the time asked, **Apply**; **Volunteer Benefits** (7) with **Raise your hand**; and "Volunteering earns CPD credits" with the three credit chips. Pull to refresh reads the ledger, the person and the bell again.

## The application

Role (optional, a sheet of the 20 roles with "Not sure yet: any role" first; the role's time shows under it), chapter (optional, a sheet of the published chapters with "No chapter in particular" first; a chapter name from a chapter's page is kept even if it is not in the list), name, email (filled from the account; the API's `@IsEmail` rule, line for line, from the contact feature), phone (optional, 30 characters), and what you bring (required). Send says what is wrong per field after a first try; the API's refusal is shown and everything stays. On success: "Thank you, <first name>", what reached the team and the address they will write to; Done returns to the screen with a snackbar and the role marked.

## Controls and the tests that prove them

`W` = `test/volunteer_test.dart`, `L` = `test/live/volunteer_live_test.dart`.

| Control | Proved by |
|---|---|
| the twenty roles, seven benefits, glyphs; search matching | W "there are the website's twenty roles…", "a role matches a search…" |
| headline, CPD card from the API, roles, benefits, credit chips | W "draws the headline…"; L "the CPD card is the member's own ledger…" |
| Back, bell (the shell's or the website's), bell dot | W "Back and the bell…", "the bell wears its dot…" |
| Become a mentor / Find your chapter | W "…are the shell's callbacks and are left out without one" |
| CPD signed out / failed read + Try again / the default target | W the three CPD tests; L "signed out there is no ledger…" |
| role search, Clear search | W "the search narrows the roles…"; W controller "the search narrows the roles, a role opens…" |
| Responsibilities open and close | W "Responsibilities open to the four duties…" |
| Apply on a role → form with the role and its time → send → thanks → INTEREST SENT | W "Apply opens the form on that role…" |
| Volunteer with ICR, Raise your hand (no role) | W "the hero button and 'Raise your hand'…" |
| a chapter's page opens the form on a committee seat there | W "a chapter's page opens the form…" (the member is read once, not twice) |
| pull to refresh | W "pulling down reads the ledger and the bell again" |
| the pickers (role, chapter) | W "the role and chapter pickers…" |
| validation per field after a first try; message room; refusal keeps the form | W "a send with nothing written…", "a refusal is shown under the form…", "the message box allows…"; W form controller tests |
| Back from the form sends nothing; the form's bell | W "Back from the form…", "the form's bell…" |
| the composed text; the API body (no honeypot, phone only when typed); refusals | W "the interest goes to the team as…", "an application is the website's contact form…", "a refusal is the API's own words…" |
| the application reaches the ICR inbox as a VOLUNTEER message and a lead; undone by the admin | L "an application is a contact message…" (the admin reads it, deletes the lead, sets the message to SPAM) |
| the API's own refusals (bad email, name over 120) | L "the API refuses what the form should have caught…" |
| the form starts from `GET /auth/me` and offers every chapter; the controller reads once | W "the screen's controller reads…"; L "the form starts from the signed-in person…", "the controller reads the ledger…" |

## Seed

None needed: the roles are constants and the CPD comes from `events-councils.ts` (Bharat's 8.5 hours and target) plus `home.ts` (the 3.5 lifetime hours that make "+12 CPD"). The live application test cleans up after itself.

## Demo content

`DemoVolunteerRepository`: a member with 12 hours (8.5 this year of a 15-hour target; 6.5 course, 3.5 event, 2 mentoring), four chapters, an application kept in memory.

## Handoffs kept

Notifications (when `onBell` is null; the shell opens its own screen). Nothing else leaves the app.
