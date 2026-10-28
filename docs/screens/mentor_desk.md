# The mentor's desk (core)

Code: `lib/features/mentor_desk/` (everything except `offerings/`, which is built by the offerings fork and mounted as one tab). Tests: `test/mentor_desk_test.dart` (gates, Overview, Requests, Mentees, Calendar, Offerings mount), `test/mentor_desk_work_test.dart` (the desk's own rules, Work, Hours, Settings, Earnings, Reviews), `test/mentor_desk_fakes.dart` (a stateful fake API in the real shapes: a write changes the next read), `test/live/mentor_desk_live_test.dart` (the local API as Anand). No seed change: `tool/seed/mentoring.ts` already holds what the desk draws (Anand, his storefront, four requests, six sold sessions, programme requests, earnings, reviews).

## Entry point for the lead

```dart
MentorDeskScreen(
  initialTab: DeskTab.overview,
  onBack: ...,
  links: links,                 // or the four named callbacks below
  onOpenConversation: (context, conversationId) => ...,   // messaging builder's chat screen ("Message" through the record)
  onOpenMentor: (context, mentorProfileId) => ...,
  onBell: (context) => ...,
  onOpenWebsite: (context, path) => ...,                  // only /profile ("Finish my profile"), /terms
  onBecomeMentor: (context) => ...,                       // the lead wires it to BecomeMentorScreen
);
openMentorDesk(context, tab: DeskTab.requests, links: links, onBecomeMentor: ...);
```

`MentorshipLinks` (`lib/features/mentorship_my/mentoring_links.dart`) carries the same callbacks; the named ones win when both are given. Nothing in `lib/app.dart` or the shell was touched. The tab keys follow the enum names (`DeskTab.fromKey('requests')`).

## Who may open it

The desk is **hidden without a mentor profile** and until ICR approves it. The first read is `GET /mentorship/mentors/me/dashboard` (`hasProfile`, `profile.status`):

| State | What the screen shows |
| --- | --- |
| no profile | "You're not a mentor yet" and "Become a mentor" (`onBecomeMentor`); no tabs |
| DRAFT | "Finish your application", "Continue your application" |
| PENDING | "Your application is in review", "See my application", the status pill |
| REJECTED | "Your application was not approved" with the reviewer's `reviewNote` verbatim, "Change my application" |
| APPROVED or PAUSED | the desk. A paused profile (ICR's pause or a renewal) keeps the desk, says it is out of the directory, disables the directory switch and offers "Review my profile" (`onBecomeMentor`) |

Proved by `test/mentor_desk_test.dart` "the desk is for a mentor with an approved profile" (five states, the failed load with Try again, the tab list with its counts, the bell) and live "the dashboard reads for a listed mentor, and says there is no profile…" (Anand ready, Bharat no profile, Kiran not usable) and the unit test "the gate tells no profile from a profile in review from the desk".

## Tabs, controls and what proves each

W = widget test, L = live test. Every tab has loading, error with "Try again", empty state and pull-to-refresh. The strip scrolls and shows a count on **Requests** (what waits on the mentor) and **Work**.

| Tab | Reads | Controls | Proved by |
| --- | --- | --- | --- |
| **Overview** | `GET mentors/me/dashboard`, `requests/incoming`, `sessions/upcoming`, sold purchases, sold terms | Stat strips (mentees, places open, to answer, rating, helped, accepted this month); "Needs you" lines, each opens the tab or pairing that answers it; Up next card (Join, opens the pairing); **directory switch** (`PATCH mentors/me/visibility {discoverable}`, optimistic, goes back and says why on a refusal; disabled while paused); completeness bar with what is missing and "Finish my profile" (the website's `/profile`, the one handoff); "all places taken" notice with "Open Settings"; recent activity | W Overview ×9 ("shows how the mentor stands…", the Work and pairing lines, Up next, the switch with a refusal, completeness, capacity, paused, activity); L "every tab reads…", "the directory switch hides the profile and lists it again" |
| **Requests** | `requests/incoming`, `mentor-services/purchases/mine?side=SELLER&scope=open`, `mentor-plans/subscriptions/sold` | **Free requests**: Accept (rhythm, note: `POST requests/:id/accept {responseNote, cadence}`) and Decline (note) through the My-mentoring sheets and `RequestCard`; **sessions asked for**: "Accept and set time" (`POST purchases/:id/accept {scheduledAt}`) with the suggested times (`GET purchases/:id/suggested-times`, a star on the mentee's own pick), "See all free times" (`GET mentors/:id/slots`), or any future time from the pickers; free sessions are booked at once, paid ones are held until the mentee pays; Message (through the purchase); Decline (reason 5-500, `POST purchases/:id/decline`); a time the mentee sent back is shown on the card and in the sheet; **waiting on the mentee**: "Withdraw this time" (asks first: `POST purchases/:id/withdraw` **cancels the whole request**, it does not reopen it); **programme and plan requests**: Accept (`POST mentor-plans/subscriptions/:id/decide {decision: ACCEPT}`, nothing is charged until the buyer pays) and Decline (reason 5-400); accepted programmes waiting for payment; answered requests lately | W Requests ×14; L "a free session request…", "a paid session request…", "a programme request…", "a free mentoring request is declined from the desk…" |
| **Mentees** | `GET mentors/me/roster`, `mentorship/mine`, `sessions/upcoming` | Live mentees and finished ones as pairing cards; tap opens the pairing (`PairingScreen`, the same page as My mentoring); Message opens the pairing's thread (`MentorshipLinks.messagePairing`) | W Mentees ×3; L "every tab reads…" |
| **Calendar** | `sessions?from&to`, `mentor-services/bookings/range`, `group-sessions/mine/upcoming` | The member-side month grid and entry sheet reused as they are (dots per kind, a day's agenda, Join, arrows to the next month); an entry opens its mentorship (a paid call opens Work, a clinic opens Offerings) | W Calendar ×2; L "the calendar reads across…" |
| **Work** | the same sold purchases and terms | **Needs you**: a buyer's problem ("Reply", 10-2000 characters, `POST purchases/:id/respond-issue`); a call whose hour has passed ("Mark held" `POST purchases/:id/complete`, "Cancel call" reason 5-500); a move the mentee asked for ("Accept new time" `reschedule/accept`, "Keep the booked time" `reschedule/decline`, "Offer another time"). **Calls ahead**: Join, "Meeting link" (validated as the API's `IsMeetingLink`, `PATCH purchases/:id/meeting-link`), "Offer another time" (free hours or the pickers, note up to 300, `POST purchases/:id/reschedule`), Cancel, Message. **Waiting on others**: "Withdraw the offer" for a move the mentor proposed, a time held, a payment due. **Programmes and plans running**: sessions left and programme progress, opens the mentorship | W Work ×13 (including the sorting and the pinned clock); L "a free session request is accepted… a move offered and accepted, a call that has not started (the API says so), and cancelled", "a problem a buyer reports…" |
| **Offerings** | (the offerings fork) | `OfferingsPanel(api, links, onChanged)`, handed the desk's own `ApiClient` | W "the tab mounts the offerings panel…" |
| **Hours** | `GET mentors/me` (`availabilityBlocks`, `timezone`) | The week, Monday first (the API's 0 is Sunday); "Add a window" on one or several days (start and end from the time pickers); remove a window; Discard; "Save hours" replaces the whole week (`PUT mentors/me/availability {blocks}`), enabled only when something changed. Checked before sending exactly as the API checks: end after start, no overlap on a day, at most 21 windows (`hoursProblem`); an API refusal is shown and the edit kept | W Hours ×6 and the unit test on `hoursProblem`; L "weekly hours: read, changed, read back and put back; the API's own refusals" (the API's sentences match the form's) |
| **Earnings** | `GET mentor-services/mine/earnings`, all sold purchases, sold terms | **Read only**: awaiting payout and paid out, each ledger line with what it was for and who bought it, "awaiting payout" or "paid out 21 Oct (NEFT-DEMO-0042)"; no control moves money | W Earnings ×3 (it has no buttons); L "every tab reads…" |
| **Reviews** | `GET mentors/:id/feedback`, `GET mentor-services/mine`, `GET mentor-services/:id/reviews` | **Read only**: rating, anonymous ratings from mentees ("A mentee"), reviews of each service with the buyer's name | W Reviews ×2; L "every tab reads…" |
| **Settings** | `GET mentors/me` | Modes (at least one), rhythm, places 1-10 (stepper), timezone (up to 64), the standing meeting link (validated, empty clears it), availability note (up to 280), bio. **Only what changed is sent** (`PUT mentors/me`), so an untouched rich bio keeps its formatting; an edited bio is plain paragraphs sent as escaped `<p>` (`bioToHtml`). A refusal keeps what was typed | W Settings ×6 and the unit test on `bioToHtml`; L "settings: only what changed is sent, read back and put back; a bad link is refused" |

## What the audit found

* Every response shape was read from the live API as Anand (dashboard, roster, settings, sold purchases, terms, earnings, feedback, service reviews, suggested times) before the parsers were written. The roster is the same pairing shape as `mentorship/mine`, so the member-side parser is reused.
* **`POST purchases/:id/withdraw` by the seller cancels the request** ("Withdrawn by the mentor before payment"); it does not return it to the queue. The desk says so, asks first, and the live test proves it. (An earlier reading of the website suggested otherwise.)
* **Completing a call needs it to have started** (`This call has not started yet.`), so "Mark held" is offered only for calls whose hour has passed, as the website does.
* A decline of a programme request without a reason is refused with the API's own sentence (`Tell them why - a bare refusal is what stops people asking.`); the form requires five characters first.
* `scope=open` on the sold list includes a resource with an unresolved problem, which is how an issue reaches Work.
* A service's `ratingCount` on the storefront reads 0 while reviews exist, so Reviews reads each service's reviews (one call per service).

## Reused from My mentoring (read only, nothing in `mentorship_my` was edited)

`RequestCard` and the accept and decline sheets (`respondToRequest`), `MonthGrid` and `CalendarTab`, `PairingCard`, `PairingScreen`, the kit (`MentoringCard`, `Callout`, `StatStrip`, `SegmentTabs`, forms, `SlotPicker`, `pickDateTime`), `MentoringRepository` (free requests, calendar, slots, reschedule, cancel), `MentorshipLinks` and the pinned clock `mentoringNow`. The desk borrows one `MyMentoringController` for the free requests, pairings, what is next and the calendar.

## Handoffs kept

* "Finish my profile" opens the website's `/profile`: the missing items (certifications, work history, education) belong to the person's own profile, which another screen owns.
* A buyer pays on the website's PayU page; the desk only shows "payment due".
* Payouts are ICR's: the Earnings tab is read-only by design.

## Left

* Group sessions and the offerings create, edit and pause screens are the offerings fork's (the Offerings tab).
* The bio editor is plain text (the website's is rich text); an unedited rich bio is never rewritten.
* Withdrawing a held time cancels the request; the API has no "give the time back and keep the request" call.
* Late answers to written consultations are not handled: the API retired that service type.
