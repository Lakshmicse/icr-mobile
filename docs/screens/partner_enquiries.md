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
