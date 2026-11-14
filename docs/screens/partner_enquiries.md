# Partner institute — Enquiries

The website's `/admin/learning/enquiries` (`LeadsPanel`), drawn by the app since 7 Nov 2026. The owner tapped the production
notification "New enquiry about CSF from Bindhya S" and was told "That one is for ICR's staff tools, which aren't in the app":
the learning console's kind (`admin.learning`) was wholly staff-only, though its enquiries are the institute's own.

## What it shows

`lib/features/partner_enquiries/` — `enquiry_models.dart`, `enquiries_repository.dart` (`ApiEnquiriesRepository`,
`DemoEnquiriesRepository`), `enquiries_controller.dart`, `enquiries_screen.dart` (`PartnerEnquiriesScreen`).

- Reads `GET /learning/admin/leads?status=&page=&limit=25` (newest first; the institute's own through `providerScopeOf`, every
  institute for Learning Center staff) and `PATCH /learning/admin/leads/:id` for a status or the note. The API's guard is the
  learning console's (`@ConsoleArea('enrolments')`): the partner company's admin, an Enrolment Admin, and ICR's learning staff.
- The website's Status filter as chips (All, New, Contacted, Converted, Closed), then the plan banner when the plan sets a monthly
  number ("2 of 3 enquiries this month came with contact details — your plan includes 2 a month. The rest are here, with the
  details masked."; a lock when over).
- One row per enquiry, the whole width with hairlines between (owner's rules): the name; the company and "~40 people" for a
  corporate one; the kind (Individual / Corporate training) and the course code as chips; the email and phone — open, or greyed with
  a lock and the website's sentence ("Past this month's number on your plan. The details open with a larger plan, or next month.")
  when `revealed` is false; when it arrived; the message; a Status chip that opens a sheet of the four statuses; the note field,
  saved when the field is left (or Done), "Note saved." confirming.
- A "New enquiry" notification (`/admin/learning/enquiries?lead=<id>`) opens the list on that enquiry, scrolled into view and
  tinted (`focusId`). The drawer's Partner Institute row lists Enquiries (`role_workspaces.dart`), and a workspace tab builds it
  (`workspaceBuiltPaths`).
- The console's other sections (`/admin/learning/courses`, `batches`, …) are still the website's staff pages, which the app does
  not draw: the opener answers them with `NotificationRouter.staffOnly`.

## Tests

`test/partner_enquiries_test.dart` (the rows, the masked contact and banner, the status sheet and the note, the filter, the
focused row, the error and empty states), `test/notification_openers_test.dart` (the opener: enquiries open the screen on `lead`,
another section says staff tools), `test/role_workspaces_test.dart` (the drawer row).

## 13 Nov 2026: copy refined to the client's standard

Wording only; three sentences changed.

| Where | Old | New |
| --- | --- | --- |
| No enquiries | No enquiries yet. The form is on every course page of yours and on your institute page. | No enquiries yet. The enquiry form is on each of your course pages and on your institute page. |
| A masked contact | Past this month's number on your plan. The details open with a larger plan, or next month. | Over your plan's monthly limit. The details open with a larger plan, or next month. |
| The plan banner | 4 of 9 enquiries this month came with contact details — your plan includes 5 a month. | 4 of 9 enquiries this month came with contact details. Your plan includes 5 a month. |

Left as they were: Enquiries, Status, the status chips (All, New, Contacted, Converted, Closed), "Corporate training" /
"Individual", "Note saved.", "Your note", and "Try again" on the error state, which is `site_kit.dart`'s.

## Save Note and replying (14 Nov 2026)

Owner, with a screenshot of Learning Partner → Enquiries: "no submit button visible while responding to enquiries". The note field is several lines, so the keyboard's action key is a new line and the note saved only when the field was left, which nothing on screen said. Now:

- **Save Note** appears beside the field as soon as the note differs from what is saved, with a spinner while it saves, and goes once saved. Leaving the field still saves, as on the website; the two never send twice. The field scrolls far enough for the button to clear the keyboard.
- Under the field: "Only your team sees this note. To reply, email or call the enquirer." The note is the institute's own record (`PATCH /learning/admin/leads/:id`, stored on the lead; the portal sends nothing to the enquirer), and the owner's screenshot was typed as a reply ("please share your contact details to discuss").
- **Reply by Email** (the phone's mail app, to the enquirer, subject "Your enquiry about <course>") and **Call** (when there is a number) under the message, for an enquiry whose details the plan reveals; a masked one offers neither.

Tests: `test/partner_enquiries_test.dart` ("Save Note shows once the note is typed in…", "an enquiry with open details offers Reply by Email and Call…").
