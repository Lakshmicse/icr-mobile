# Become a mentor (and "My mentor profile")

Code: `lib/features/become_mentor/`. Tests: `test/become_mentor_rules_test.dart` (the ported shared rules, one pinned sentence per rule, and the API's shapes), `test/become_mentor_test.dart` (a widget test per control, over `test/become_mentor_fakes.dart`, a stateful fake in the real shapes), `test/live/become_mentor_live_test.dart` (the local API, as Kiran). Doc written 26 Oct 2026. No design PNG exists for these screens: they are built in the visual language of the mentoring screens (`lib/features/mentorship_my/widgets/kit.dart`), flows first.

## The screen

`BecomeMentorScreen` is the website's `/mentorship/become-a-mentor`: titled "Become a mentor" until the member has a profile, "My mentor profile" after. It is one scrolling page of read-only cards, each edited in a bottom sheet from its button, with the application on top.

Two halves, as the website says out loud. The **person's** half (photo, current role, years, languages, career history) is the member's own ICR profile, so a change here shows on their profile too; the **mentoring** half is the mentor profile (`PUT /mentorship/mentors/me`, a partial patch: only what a sheet sends is written, and the first save creates the DRAFT).

| Block | Holds | Sheet |
| --- | --- | --- |
| Banner | Where the application stands, one line (see "Statuses") | none |
| Your application | Progress bar and steps, "Still needed to submit" (each line opens the sheet that fixes it), the code of conduct agreement, Submit | the code of conduct |
| Profile photo | The member's photo | `PhotoSheet` |
| Role and experience | Current role, years in the profession | `IntroForm` |
| Languages | Up to 8 | `LanguagesForm` |
| Career history | Roles, newest first | `ExperienceForm` (add, edit, remove) |
| How you mentor | The bio, plain paragraphs stored as HTML | `BioForm` |
| Expertise | Areas (the 24 competency domains) and topics | `ExpertiseForm` |
| Certifications on your card | Picked from the credentials the member holds | `CertificationsForm` |
| Who you mentor | Audiences and the roles you can help people reach | `AudienceForm` |
| Availability | Capacity, how you meet, cadence, "when you're free" | `AvailabilityForm` |
| Weekly hours | The windows a mentee can book from | `WeeklyHoursForm` |
| Mentor training | Required modules, shown only when the API has some | none (website handoff) |
| Supporting documents | Evidence for the review team (a profile must exist) | `DocumentForm` |
| Your listing | "Accepting new requests", View public profile, Withdraw | confirm dialog |

## Wiring (for the lead)

```dart
// Pushed from "Apply as Mentor" / the profile drawer / the Mentorship tab's Become a mentor band
openBecomeMentor(context, onOpenMentor: ..., onBell: ..., onOpenWebsite: ..., onOpenConversation: ...);

BecomeMentorScreen({
  onBack, links, repository,                 // repository is a test seam
  onOpenConversation, onOpenMentor, onBell, onOpenWebsite,   // each optional, each has a working default
  pickPhoto = pickPhotoFromDevice, pickDocument = pickEvidenceFromDevice,   // test seams (file_picker by default)
})
```

`links` is the `MentorshipLinks` of `lib/features/mentorship_my/mentoring_links.dart`; the four named callbacks are folded over it with `MentorshipLinks.resolve`. Used here: `onOpenMentor(context, mentorProfileId)` ("View public profile" of a listed mentor; default: the in-app profile route), `onBell(context)` (default: the website's `/notifications`), `onOpenWebsite(context, path)` (the training modules and the credentials page, below; default `openSitePage`). `onOpenConversation` is accepted for the family of screens but nothing on this screen opens a thread. Nothing in `lib/app.dart`, the shell or `pubspec.yaml` was touched.

## Endpoints used

| Call | For |
| --- | --- |
| `GET /mentorship/mentors/me` | The profile. **200 with an empty body** when the member has none: read as "no profile" |
| `PUT /mentorship/mentors/me` | Every mentoring sheet; the first one creates the DRAFT. `null` clears a scalar, `[]` a list |
| `POST /mentorship/mentors/me/submit` | Submit / resubmit |
| `DELETE /mentorship/mentors/me` | Withdraw (a soft delete: a later save revives it as a DRAFT, never as the status it left with) |
| `PATCH /mentorship/mentors/me/visibility` | "Accepting new requests" on its own |
| `PUT /mentorship/mentors/me/availability` | Weekly hours, replace-all (`blocks: []` clears) |
| `GET /mentorship/mentors/me/readiness` | The gates: code of conduct, training, renewal |
| `GET /mentorship/code-of-conduct`, `POST /mentorship/mentors/me/code-of-conduct {version}` | Read and agree (the API refuses a version that is not current) |
| `GET/POST/DELETE /mentorship/mentors/me/documents[/:id]`, `POST /uploads?purpose=mentor-screening` | Evidence |
| `GET /users/me/profile`, `PATCH /users/me` | The person: role, years, languages, photo (`avatarUrl`, `''` clears it) |
| `POST /uploads?purpose=avatar` | The photo's file |
| `GET /profile/experience`, `PUT /profile/experience {rows}` | Career history; the whole list is saved |
| `GET /credentials/me` | The credentials a card may show (never a rejected one, never one with no short code) |
| `GET /job-titles` | ICR's job titles, offered as suggestions for a role (any text is accepted) |

Every shape was checked against a real call as Kiran (and Anand for a listed profile) before the models were written; the fixtures in `test/become_mentor_fakes.dart` are those shapes.

## The rules: ported, and proved against the API

`become_mentor_rules.dart` is a port of `packages/shared/src/mentor-rules.ts` (`mentorProfileProblems`, `mentorPersonProblems`, `htmlToPlainText`) with each sentence taken from the shared catalogue's `validation.mentor.*`, and of the profile rules a role and the intro use (`experienceProblems`, `yearsProblem`, `designationProblem`). Saving a draft applies only the limits; `forSubmit` adds what review needs. `test/become_mentor_rules_test.dart` pins every sentence (bioNeeded, bioMore with its count, bioTooLong, competenciesMax, competenciesNeeded, topicsMax, audienceNeeded, targetRolesMax, availabilityNoteMax, avatarNeeded, roleMax, roleMin, roleNeeded, yearsRange, yearsNeeded, languagesMax, languagesNeeded, experienceNeeded, and the role rules), the boundary of each limit, and the field each problem names.

**The live test proves the port is right, not just self-consistent:** it walks a draft through every state and asserts `controller.needed` equals the API's own `readiness.blockers` (less the two gates), line for line and in order, after the first save, after the person's half, after the bio, after expertise and audience (empty list: ready), and after removing the photo. It also asserts the API's submit refusal contains every line the checklist names.

## What each control does, and what proves it

W = `test/become_mentor_test.dart` (widget), R = `test/become_mentor_rules_test.dart`, L = `test/live/become_mentor_live_test.dart` (the local API as Kiran; every write undone).

| Control | What it does | Proved by |
| --- | --- | --- |
| First view (no profile) | Draft banner, "0 of 3 steps done", one line per thing needed, Submit disabled with its reason, no documents or listing card, nothing read that needs a profile | W "sees where to start…", "a missing photo is the first thing needed"; L "the reads parse…" |
| A checklist line | Opens the sheet that fixes it (photo, role/years, languages, role, bio, expertise, audience, availability, certifications; training goes to the module) | W "a line of the checklist opens the sheet…", "unfinished training…", "a module opens in the learning centre…" |
| Load failure, Try again, pull to refresh, bell | Says why and asks again; re-reads everything; opens notifications | W "a load that fails…", "pulling down reads it all again", "the bell…" |
| How you mentor | Plain paragraphs to `<p>` HTML (`&`, `<`, `>` escaped); "N of the 100 characters needed"; over 20,000 refused before sending; emptied sends `null`; a refusal keeps the sheet and what was typed | W "How you mentor" ×5; R bio and limit tests; L "each section saves…", "the limits are the API's too…" |
| Expertise | Search and choose from the 24 domains, at most 12 (the 13th does nothing); topics typed, duplicates ignored, at most 12, removable | W "Expertise" ×3; L "each section saves…" |
| Who you mentor | Audience boxes kept in enum order; roles from ICR's titles or typed, at most 8 | W "Who you mentor" ×2; L "each section saves…" |
| Availability | Capacity 1 to 10, modes, cadence (tap again to clear: sent as `null`), note ≤ 280 (refused with the API's sentence) | W "Availability" ×3; L "each section saves…", "the limits…" |
| Weekly hours | Windows per weekday as 30-minute steps to minutes after midnight; Monday-first list; end after start and no overlap on a day (the API's own sentences, checked first); at most 21; not available before a profile exists | W "Weekly hours" ×4; L "weekly hours…" |
| Certifications | Picked from held credentials (verified marked), never typed; a code no longer held stays visible, blocks the save and is removed first; "Manage my credentials" opens `/profile?tab=credentials&code=1` | W "Certifications" ×3; L "the limits…" (`NOTMINE` refused) |
| Role and years | `PATCH /users/me`; 2 to 100 characters, whole years 0 to 60; blank role and years clear them; title suggestions | W "Role and experience" ×4; R; L "the person's own half…" |
| Languages | Suggestions or typed, ≤ 40 characters each, at most 8 | W "Languages" ×2; L "the person's own half…" |
| Career history | Add, edit, remove a role; every rule's sentence under the form; the whole list is saved; an edited role keeps its linked company page, employment type and industries (the page's company link is dropped when the organisation changes) | W "Career history" ×5; R role rules; L "the person's own half…" |
| Photo | Pick, upload (`purpose=avatar`), save as the photo; remove; > 5 MB refused before sending; backing out sends nothing; an upload the API refuses says why | W "The photo" ×5; L "a photo is uploaded…" |
| Code of conduct | The checkbox agrees to the current version (creating the empty draft first when there is none); the whole code can be read and agreed in the sheet; a stale version is refused in the API's words; the box waits for the code to load | W "The code of conduct" ×4; L "the code of conduct…" |
| Submit | Enabled only when nothing is needed and the code is agreed; goes to review (banner changes, button goes); the API's refusal is shown and the draft stays | W "Submitting" ×3; L "submitting…" |
| Statuses | See below | W "Where the application stands" ×5; R `MentorStatus` |
| Training | Progress and each module, Enrol / Open on the website, blocks the submit until done | W "Mentor training" ×4; R readiness shapes |
| Documents | Pick a PDF or picture ≤ 10 MB, upload (`purpose=mentor-screening`, private), attach with a kind and label; only a pending one can be removed; a rejected one shows the reviewer's note; 12 at most | W "Supporting documents" ×5; L "supporting documents…" |
| Accepting new requests | Switch, on its own (`PATCH …/visibility`) | W "Your listing"; L "accepting new requests…" |
| Withdraw | Confirm, then the profile is gone and the page starts again; the API's refusal while mentorships are under way is shown | W "Your listing" ×2; L "submitting…" (withdraw and revive), "a mentor with mentorships under way…" (Anand: refused, nothing changed) |

## Statuses

Draft: "Draft - not yet visible" with Submit. Pending (awaiting review): the vetting line, no Submit. Approved (Listed): "Members can find you in the directory…", "View public profile" (`onOpenMentor`), no Submit; when `renewalDue`, a callout with the expiry date. Paused (by ICR): hidden from the directory, mentorships unaffected. Rejected (Not approved): the reviewer's `reviewNote` **verbatim** (or "The review team asked for changes."), and "Resubmit for review".

## What the API cannot do, and what the screen does

* **Documents are not on the website's composer** (only the review console reads them), but the API takes them from the mentor (`POST me/documents`), so the app offers them as optional evidence, uploaded through `file_picker`.
* **Training enrolment** has no endpoint here: a module is opened in the learning centre (below).
* **The code of conduct agreement is kept on the profile row** and cannot be taken back: a withdrawn-and-revived profile still carries it, and the live tests read the state rather than assume it.
* **A withdrawn profile keeps its old fields** (the revive only resets status and review note), so the live tests empty every field before withdrawing.
* **A file that was uploaded cannot be deleted** (no endpoint): the live tests leave two tiny files per run in `backend/uploads` (one picture, one PDF) and say so.

## Handoffs to the website, and why

* **Mentor training modules** (`/learning/professional-development/<code>`): the Learning Center's own screens belong to the learning feature.
* **Manage my credentials** (`/profile?tab=credentials&code=1`): the credentials editor belongs to the profile feature (not built in the app yet).

Nothing is paid here; there is no other handoff.

## Backend requests

None. Everything the flow needs exists and was exercised.

## Seed

No change: `tool/seed/mentoring.ts` already makes `mentoring.kiran@design.icr.test` ("has not applied to mentor", with a seeded photo, no role, years, languages or history) and Anand (a listed mentor with live pairings, for the withdrawal refusal and the parser check). The live tests leave Kiran as the seed does: no profile, no role or years or languages, no history, the seeded photo.

## Left

* The weekly-hours editor is also where the mentor desk edits hours; this screen's copy is for applicants and for reaching the same editor from the application. The desk (a separate folder) has its own.
* Credentials, education, links and career breaks are the profile feature's, not edited here (only the career history a mentor card needs).
* No pixel matching (the owner postponed it): sizes follow the mentoring screens' scale.
