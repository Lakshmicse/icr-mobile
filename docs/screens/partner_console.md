# Partner institute — Manage Courses, Manage Batches, Enrolment

The website's Learning console as a partner institute sees it — `/admin/learning/courses` (`DevelopmentPanel` with
`CoursesTable` and `CourseStatusCell`), `/admin/learning/batches` (`BatchesPanel`, `BatchDialog`, `BatchViewDialog`)
and `/admin/learning/enrolments` (`EnrollmentsTable`) — drawn by the app (12 Nov 2026). The three rows under
"Learning Partner" in the drawer. The fourth part of the console, Enquiries, was already native
(`docs/screens/partner_enquiries.md`); these screens follow its pattern and its guard.

## Files

`lib/features/partner_console/`

| File | What it holds |
|---|---|
| `partner_console_models.dart` | `ConsoleContext` (`GET /learning/admin/me`), `ConsoleCourse`, `ConsoleBatch`, `TrainerPlace`, `FacultyMember`, `ConsoleEnrolment`, `EnrolmentsPage`, `CourseCategory`, `UploadFile`; the drafts the sheets send (`CourseDraft`, `BatchDraft`); the website's status, mode and answer words |
| `partner_console_rules.dart` | `PartnerConsoleViewer` (the website's `LEARNING_STAFF_ACCESS` table and `learningCan`), the batch-schedule rules ported from `packages/shared/src/batch-schedule.ts` (`batchStatusFor`, `weekdaysBetween`, `batchScheduleLabel`, `classTimesError`, `countClassDates`, `batchLength`, the Indian calendar day), the offer maths (`clampAssessmentDiscount`, `offerPaisa`, `offerEndDateInPast`) and `rupees` |
| `partner_console_repository.dart` | `PartnerConsoleRepository` (abstract), `ApiPartnerConsoleRepository`, `DemoPartnerConsoleRepository` (two courses, three batches, a team of four, three enrolments, a `sent` log; `failList`, `refuse`, `lockEnrolments` for tests) |
| `partner_console_controllers.dart` | `CoursesController`, `BatchesController`, `EnrolmentsController` (ChangeNotifiers; `can(area)` combines the member's learning roles with the institute's agreement, as `useLearningCan`) |
| `partner_console_kit.dart` | the not-partner notice, status chips in the website's colours, section labels and facts, `ListEditor`, `UploadField`, `ConsolePickers` (the phone's day, time, picture and PDF pickers behind one seam) |
| `courses_screen.dart` | `ManageCoursesScreen` |
| `course_sheet.dart` | the course sheet (`CourseDialog`) |
| `batches_screen.dart` | `ManageBatchesScreen` |
| `batch_sheet.dart` | the batch sheet (`BatchDialog`) |
| `batch_view_sheet.dart` | the batch in full (`BatchViewDialog`) |
| `enrolments_screen.dart` | `EnrolmentsScreen` |
| `enrolment_sheet.dart` | one enrolment and the decision (`EnrolmentDialog`) |

```dart
const ManageCoursesScreen({super.key, required this.onBack, this.repository, this.viewer, this.pickers = const ConsolePickers(), this.now});
const ManageBatchesScreen({super.key, required this.onBack, this.courseId, this.repository, this.viewer, this.pickers = const ConsolePickers(), this.now});
const EnrolmentsScreen({super.key, required this.onBack, this.repository, this.courseId, this.viewer});
```

`PartnerCoursesScreen` already exists (`learning_hub/partner_courses_screen.dart`, the public partner directory), so
the courses screen is `ManageCoursesScreen`. Each screen builds its repository as
`AppConfig.demo ? DemoPartnerConsoleRepository() : ApiPartnerConsoleRepository(api: context.read<ApiClient>())`
(`partnerConsoleRepositoryOf`). `viewer` is read from the session (`SessionUser.role`, `learningRoles`,
`learningPartner`, `companyId`) when not given. `pickers` and `now` are test seams.

## Who sees what

- **Not the institute's staff** (no company, or a company that is not a learning partner, and no learning role): the
  three screens show one notice, "This console is the partner institute's" and why, and read nothing. The rule is
  the drawer's own (`role_workspaces.dart`): a learning role at the company the member acts for, or the admin of a
  company ICR approved as a learning partner.
- **Inside**, the buttons follow `LEARNING_STAFF_ACCESS`, as the website's `useLearningCan` hides them. The company
  admin keeps every area. A Course Admin creates, edits and publishes courses and sees batches and enrolments. A
  Batch Admin runs batches and decides enrolments. An Enrolment Admin decides enrolments. Trainer and Finance read.
  On top of that, for a change, the institute's agreement (`partnerMayChange`): a suspended institute, or one whose
  agreement has ended, is read-only, and an area its agreement does not cover cannot be changed. The API's
  `LearningConsoleGuard` checks the same tables, so a hidden button is only a refusal spared.

## Manage Courses

- The counts line ("2 courses · 3 batches") and **New course** for those who may edit courses. When any course is not
  published, the website's note explains that a draft is visible only here until it is published.
- One row per course, full width with hairlines between. The code, then the name. The status chip: **Live**,
  **Draft**, **With ICR for review**, **Changes requested** or **Archived**, in the website's colours, with ICR's
  note under the row when it asked for changes. Then the website's columns run as one line: format, duration, next
  batch (the soonest still ahead, else "Not scheduled"), batch count and CPD.
- The status action is the website's `CourseStatusCell`, shown to those who may publish:
  - **Unpublish** on a live course.
  - **Withdraw** on one waiting for ICR.
  - "Add a batch to publish" on a course with no batch still going ahead (scheduled, open or running).
  - **Submit for review** when ICR reviews this institute's courses (`partner.courseReviewRequired`).
  - **Publish** otherwise.
- Row tools: **Batches** (Manage Batches narrowed to the course, the website's `?course=`), **Enrolments**
  (Enrolment narrowed to it), and **Edit** and **Delete** for course editors. Delete asks first.
- **The course sheet** has the website's fields for a partner's taught course, in its order:
  - Course name (its code and URL are generated from it) and Summary (one line).
  - Category and Sub-category, from `GET /categories/tree?kind=SERVICE&depth=2`. Save waits for a name and a
    category, as the website's button does.
  - Cover image (PNG, JPG or WEBP up to 2 MB, shrunk with the app's `fitForUpload` when the phone's picture is
    heavier) and Brochure (PDF up to 10 MB). Both go to `POST /uploads?purpose=learning`, the website's public
    purpose.
  - Course overview.
  - COURSE CONTENT: Key takeaways (numbered, moved up and down) and Who should attend (bulleted), through the
    website's `ListEditor`; blank rows are dropped when saved.
  - PUBLICATION: Access, Free or Paid.
  - A partner's course has no status field. A new course is saved as a draft, and the website's caption says so.
    **Save and publish** appears on an existing course once it has a batch still going ahead, unless ICR reviews
    the institute. A live course under ICR's review carries the website's warning that changing what learners are
    told sends it back for review.
  - A new course sends the website's `blank()` with what was typed. An edit sends `fromCourse` with the changes, so
    nothing the sheet does not ask for is lost.

## Manage Batches

- The course filter as a chip ("All courses", or the course's code), the count ("3 batches") and **New batch** for
  Batch Admins and the company admin. With one course in view the new batch is for it; otherwise the website's
  "Which course is it for?" list opens.
- One row per batch, soonest first: the name (or its code when it has none), then course · start day · seats ("9/25
  seats", "Uncapped"; red when full), and the status chip. The status is worked out from the dates as of today, as
  the website's `shownBatchStatus` does: Open for enrolment until enrolment closes, Scheduled until the batch
  starts, Running through its last day, Completed after it, and Cancelled when someone cancelled it.
- A row opens **the batch in full** (`BatchViewDialog`):
  - the status, mode and length chips;
  - SCHEDULE: starts, ends, enrolment closes, classes, time zone, venue, joining link;
  - SEATS AND PRICE: enrolled, seats held back, waitlist, price, offer;
  - TEAM: each trainer with their answer, or the mentor on ICR's own courses, and the enrolment specialist;
  - NOTES.

  For those who may change batches, the foot has **Delete** (asks first) and **Edit batch**.
- **The batch sheet** has the website's fields:
  - Batch name ("Blank = named after the start month"), and "Cancel this batch" once the batch exists. No status
    is ever picked: the dates set it.
  - SCHEDULE: Batch starts and Batch ends, as days stored at their UTC midnight. The start must be today or later,
    unless an existing batch keeps the start it already has. The end must be after the start. Enrolment closes is
    a day and a time; blank keeps enrolment open until the batch starts.
  - Class days: a tick per weekday, all ticked to begin with. Only the weekdays the dates reach can be ticked.
  - Class starts and Class ends, on the phone's clock picker; the class length shows under the end time.
  - The website's line under them, worked out as you go: "Mon–Fri, 10:00–13:00 · 20 classes · 60 hours", or the
    class-time problem.
  - DELIVERY: Mode (Virtual — live online, or In person; a batch already on a retired mode keeps it, marked),
    Timezone, and Venue for an in-person batch.
  - TEAM (an institute's course): Trainers, ticked from the institute's team, where one with no linked ICR account
    cannot be asked. Each picked trainer's answer shows under the field ("Asked when you save", "Waiting for their
    answer", "Accepted", "Declined" with **Ask again**, which is `POST …/batches/:id/trainers/:trainerId/invite`).
    Then Specialist – Program Enrollment.
  - BATCH SIZE & PRICE: Batch size, blank for no limit. A paid course adds the Live Virtual or Face 2 Face price
    (₹ per place, before GST), Discount (%) from 0 to 90, Offer valid till, and the website's sentence "Learners
    pay ₹16,200 + GST instead of ₹18,000 (10% off, till 15 Feb 2027)." A free course says to set its Access to Paid
    to price its batches.
  - Save with fields missing names them all, as the website does ("Fill in the required fields: Batch starts, …")
    and turns them red.
  - A new batch sends the website's `blank()` defaults (waitlist on, no seats reserved). An edit sends `fromBatch`,
    so the mentor fields, joining link, notes and reserved seats it does not ask for go back unchanged.

## Enrolment

- The course filter chip (or, opened from a course row, that course's code and name) and the count ("3
  enrolments"), then the website's Status select as chips: All statuses, Pending, Confirmed, Waitlisted, Cancelled,
  Completed.
- One row per enrolment, newest first, 25 to a page with more loaded on scroll. Each shows the name, the course code
  and the day they applied, and the status chip.
- A row opens the enrolment in full (`EnrolmentDialog`): name and email, status, course, batch (or "Single cohort"),
  mode, start, applied, decided, and the candidate's note. For those who may decide, the foot has **Cancel
  enrolment** (not on a cancelled one) and **Confirm place** (not on a confirmed one).
- A decision is `PATCH /learning/admin/enrollments/:id { status }`, and the row takes the new status. The API's
  refusal (for example "That batch is full. Increase the seat count before confirming more candidates.") shows
  above the list, as the website shows it, and the row keeps its status.
- An institute whose plan leaves participant management out (the API's 403) sees "Participant management" and the
  plan's sentence in place of the list (the website's `PlanLockNotice`).

## API calls

All under `/api/v1/learning/admin`; the institute's own rows through `providerScopeOf`.

| Call | Where |
|---|---|
| `GET me` | every screen: partner state, capabilities, `courseReviewRequired` |
| `GET courses?kind=DEVELOPMENT` | Manage Courses; the course lists of the other two |
| `POST courses`, `PATCH courses/:id`, `DELETE courses/:id` | the course sheet, Publish, Unpublish, Delete |
| `POST courses/:id/submit`, `POST courses/:id/withdraw` | Submit for review, Withdraw |
| `GET batches` | Manage Batches |
| `POST courses/:courseId/batches`, `PATCH batches/:id`, `DELETE batches/:id` | the batch sheet, Delete |
| `POST batches/:id/trainers/:trainerId/invite` | Ask again |
| `GET trainers` | the batch sheet's trainer and specialist pickers |
| `GET enrollments?courseId=&status=&page=&limit=25`, `PATCH enrollments/:id` | Enrolment |
| `GET /categories/tree?kind=SERVICE&depth=2` | the course sheet's category |
| `POST /uploads?purpose=learning` | cover image and brochure |

Each body was replayed with curl against the local API as `partner.demo.1103072713@learning.icr.test` on 12 Nov 2026,
and the API accepted all of them:

- creating a course with the new-course body;
- creating a batch with the new-batch body, which the API named "May 2027" and scheduled as "Mon–Fri, 10:00–13:00",
  "20 classes · 60 hours", the same line the sheet works out;
- editing that batch with the edit body (in person, venue, three days);
- editing the course with the `fromCourse`-style body;
- submit (Pending review) and withdraw (Draft).

The probe rows were deleted afterwards. The institute has no enrolments, so the enrolment PATCH was checked only for
its refusal shape (404 "Enrolment not found").

## What the website does that the app leaves out, and why

- **Modules and materials** (the syllabus book on a course row, `SyllabusDialog`) and **Assignments**
  (`AssignmentsDialog`). These are the `materials` and `assessments` areas, separate pages of the console with their
  own editors (rich text, file materials, grading). They are not part of Manage Courses, Manage Batches or Enrolment
  as the drawer names them.
- **Timetable, register and attendance** (`BatchOperationsDialog`: sessions, taking a register, attendance rates).
  This is the `attendance` area, a tool of its own and not the batch list. It is the next screen to build.
- **The batch group chat** (`BatchGroupMembers`). The batch's conversation opens in the app's own messaging when a
  member is in it, so the console does not duplicate it.
- **ICR's own-course fields** on a batch (mentor name, designation, email, photo). A partner's course always has an
  institute (`providerId`), so its team comes from the trainer pickers. The sheet carries those fields through
  unchanged and says ICR's courses name their mentor on the website's console.
- **The cover image crop dialog.** The website crops to 16:9 before upload. The app shrinks a heavy picture to the
  2 MB limit (`fitForUpload`) and uploads it uncropped; the card crops it on display.
- **Brochure Preview.** The website opens the PDF in a tab. The sheet shows that a brochure is attached; the course
  page's brochure viewer already reads it in the app.
- **Remove on a cover or brochure** sends `null` on an edit and clears the file. The website's Remove leaves the
  field out of its PATCH, which keeps the old file, so the app does what the button says rather than what the
  website's request does.
- **The status select and Awarding body picker.** The website hides both from a partner too (a partner's course has
  no status field, and the institute is always its own).
- **Pagination buttons** on enrolments: the app loads the next page on scroll instead of Previous / Next.
- **The trainers' typed time** on the class-time fields. The website types or picks on a clock face in 5-minute
  steps; the app uses the phone's time picker, which takes any minute. The API accepts any `HH:mm`.
- **Timezone list.** The website's `TimezoneField` lists every IANA zone. The sheet offers the 22 zones ICR's
  markets use, searchable, and keeps a batch's own zone when it is another one.

## Tests

`test/partner_console_test.dart`: 16 widget tests against `DemoPartnerConsoleRepository`, all green on 12 Nov 2026.

- **Manage Courses**
  - the rows (code, name, status, the facts line, the unpublished note, Publish and Unpublish), with no cards;
  - a course created with every website field, and the exact body sent;
  - back on the list, the new draft reads "Add a batch to publish";
  - under ICR's review, Submit for review sent, then "With ICR for review" and Withdraw;
  - Publish sent, and Edit reopening the course's fields;
  - a Trainer seeing no buttons;
  - the list's error and retry.
- **Manage Batches**
  - soonest first, the status from the dates, and the course filter;
  - a batch created for a course: the missing fields named, then days, class days, times and size, and the exact
    body sent; the new row is named after its start month;
  - the batch in full (schedule, seats, price, offer, trainers' answers, specialist, notes), then Edit opening the
    sheet on its price sentence and trainers;
  - a Trainer able to read but not add or edit.
- **Enrolment**
  - the rows, the enrolment in full, Confirm place sent and the row following, and the status filter;
  - the API's refusal shown above the list with the row unchanged;
  - the plan lock;
  - a Trainer able to read but not decide;
  - opened narrowed to one course.
- **Not partner staff:** all three screens show the notice and read nothing.

Not done here: the drawer rows and the `admin.learning` notification opener for `courses`, `batches` and
`enrolments`. They are the lead's to wire (`lib/features/workspaces/`, `lib/app_notifications.dart`), in place of
`NotificationRouter.staffOnly` for those three sections.

## 13 Nov 2026: copy refined to the client's standard

Wording only. Manage Courses, Manage Batches and Enrolment keep their names.

State titles are headings (the lead's decision the same day): an empty-state, locked-state or error title is in Title Case with no full stop, and the line under it stays a sentence.

| Where | Old | New |
| --- | --- | --- |
| Field labels, picker titles and section headings to Title Case: 24 strings | Course name · Cover image · Course overview · Course content · Key takeaways · Who should attend · Batch name · Batch starts · Class days · Enrolment closes · Batch size & price · Seats and price · Joining link · Seats held back · Note from the candidate … | Course Name · Cover Image · Course Overview · Course Content · Key Takeaways · Who Should Attend · Batch Name · Batch Starts · Class Days · Enrolment Closes · Batch Size & Price · Seats and Price · Joining Link · Seats Held Back · Note from the Candidate … |
| Buttons, chips and sheet titles to Title Case: 20 strings | New course · Edit course · Save and publish · Submit for review · New batch · Edit batch · Cancel this batch · Cancel enrolment · Confirm place · All courses · All statuses · Add another takeaway · Upload image · Ask again · Move up … | New Course · Edit Course · Save and Publish · Submit for Review · New Batch · Edit Batch · Cancel This Batch · Cancel Enrolment · Confirm Place · All Courses · All Statuses · Add Another Takeaway · Upload Image · Ask Again · Move Up … |
| A list's first Add button | Add key takeaways · Add who should attend | Add Key Takeaways · Add Who Should Attend |
| One name for the field | Timezone (form) · Time zone (view) | Time Zone |
| "Pick", "tick" and "choose" read "select": 14 strings | Pick a day · Pick a time. · Tick at least one day classes meet. · Classes run on the ticked days … · Choose a mode · Choose a zone · Choose trainers · Choose a category · … to pick them here. | Select a day · Select a time. · Select at least one class day. · Classes run on the selected days … · Select a mode · Select a time zone · Select trainers · Select a category · … to select them here. |
| "Blank = …" helpers: 6 strings | Blank = named after the start month · Blank = open until the batch starts · Most candidates it takes. Blank = no limit · Blank for no offer. · Blank runs it until removed | Leave blank to name it after the start month. · Leave blank to stay open until the batch starts · Maximum number of candidates. Leave blank for no limit. · Leave blank for no offer. · Leave blank to run it until removed |
| Batch form, the clock helper and its error | The class time is on this clock · Pick the zone the class time is on. | The class time is in this time zone. · Select the time zone for the class time. |
| Batch form, questions as errors | Where do the classes meet? · What does a place cost? | Enter where the classes meet. · Enter the price of a place. |
| Batch form, trainers helper | Who trains its candidates — add one or more. Each one is asked and teaches the batch once they accept; the course page then shows their profile. | Add one or more trainers for this batch. Each trainer receives a request and teaches the batch once they accept. The course page then shows their profile. |
| Batch form, price labels | Face 2 Face price (₹) · Live Virtual price (₹) · Offer valid till · (10% off, till 15 Feb 2027) | Face 2 Face Price (₹) · Live Virtual Price (₹) · Offer Valid Until · (10% off, until 15 Feb 2027) |
| Delivery modes | Virtual — live online · Online — self-paced · … — no longer offered | Virtual (live online) · Online (self-paced) · …, no longer offered |
| Picking a batch's course | Which course is it for? | Select a Course |
| Delete a batch | Delete the batch "March 2027"? · Its timetable and registers go too. Candidates already enrolled lose the place. | Delete the Batch "March 2027"? · Its timetable and registers are deleted too. Enrolled candidates lose their place. |
| Delete a course | The course and its batches leave the console and the public catalogue. | The course and its batches are removed from the console and the public catalogue. |
| Course form, uploads | That file is over 2MB. Pick a smaller image and try again. · The brochure has to be a PDF. · That file is over 10MB. … | This file is over 2MB. Select a smaller image and try again. · The brochure must be a PDF. · This file is over 10MB. … |
| Course form, a new course's caption | Saved as a draft — add a batch from the list, then publish it. | Saved as a draft. Add a batch from the list, then publish it. |
| Course form, the review note | Changing what learners are told — the title, summary, description, price, duration, outcomes or who it is for — sends this course back for review, and it leaves the catalogue until ICR approves it. | Changing the title, summary, description, price, duration, outcomes or audience sends this course back for review. It leaves the catalogue until ICR approves it. |
| Manage Courses, unpublished note | A draft is only visible here — it reaches the public catalogue and your institute page when you press Publish beside its status. | A draft is only visible here. It reaches the public catalogue and your institute page when you select Publish beside its status. |
| Manage Courses, no courses | Create one — Facility Management Fundamentals, and the rest of the catalogue — then schedule its batches. | Create a course, such as Facility Management Fundamentals, then schedule its batches. |
| Not a partner (title) | This console is the partner institute's | This Console Is for Partner Institutes |
| Enrolment, the plan notice | Participant management | Participant Management |

The list fields' keys are built from their labels, so they changed with them: `list-Key Takeaways-add`,
`list-Who Should Attend-0`, `upload-Cover Image`.

Left as they were: "Specialist – Program Enrollment", the website's name for the role; the status words on chips (Live,
With ICR for review, Changes requested, Open for enrolment, Asked when you save, Waiting for their answer); "CODE —
Title" in the pickers and the delete title, where the dash joins a code to its name; the example hints (March 2026 —
weekend, ICR Bengaluru campus); the demo repository's content and its "Could not load …" errors; "Try again" on the
error state, which is `site_kit.dart`'s.

Tests: `test/partner_console_test.dart` uses the new keys and the new required-fields sentence ("Fill in the required
fields: Batch Starts, Batch Ends, Class Starts, Class Ends.").
