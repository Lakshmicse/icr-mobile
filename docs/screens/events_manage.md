# Manage Events — the staff Events console

The website's `/admin/community?tab=events` and `?tab=event-hosts`, for staff holding the permission key
`events:manage` (the Events Admin and Community Manager roles; a Super Admin holds every key), drawn by the app
(13 Nov 2026). Staff mode only: a company's own Hosted events page (`/manage/events`, the same website panel in
`partner` mode) is not part of this.

## Files

`lib/features/events_manage/`

| File | What it holds |
|---|---|
| `events_manage_models.dart` | `ManagedEvent` (`AdminEventRow`), `EventsQuery`, `Paged<T>`, `OrgRef`, `EventProgramme` with `EventInvite`, `EventProposal`, `SponsorPackage`, `SponsorshipRequest`; `TicketRow`; `RefundOutcome` (`RefundDone` / `RefundPending`, the website's `isApprovalPending`); `InviteResult`, `TierInviteResult`, `AttendanceResult`; `HostApplication`; the shared package's status words |
| `events_manage_rules.dart` | the DTOs' limits as constants; `EventDraft` and `PackageDraft` (`problems()` is what the API would refuse, `toJson()` the body); the description as fields (`eventDescriptionSections`, `parseAbout`, `composeAbout`, ported from `aboutSections.ts`); `slugify`; the Indian clock (`istWallToUtc`, `dayLabel`, `dayTimeLabel`); `splitEmails` / `inviteEmailsProblem`; `refundRefProblem`; the `ApprovalSentNotice` sentences |
| `events_manage_repository.dart` | `EventsManageRepository` (abstract) and `ApiEventsManageRepository({required ApiClient api})` |
| `events_manage_controllers.dart` | `ManageEventsController` (the list), `HostRequestsController` (Event Partners), `ManageEventController` (one event) — ChangeNotifiers; `start()` never notifies before its first answer |
| `events_manage_kit.dart` | `EmText`, `EmTabs`, `EmPill` / `EmPillRow`, `EmStatus`, `EmDetail`, `EmHeading`, `EmNote`, `EmEmpty` / `EmError` / `EmLoading`, `EmMore`, `EmSearch`, `EmSheet` |
| `manage_events_screen.dart` | `ManageEventsScreen` and its two tabs |
| `manage_event_screen.dart` | `ManageEventScreen` and its six tabs |
| `event_form_sheet.dart` | `showEventFormSheet` / `EventFormSheet`, `EventPickers` |
| `events_manage_sheets.dart` | invite by email, invite by tier, a proposal's decision, a package, a sponsorship's decision, a refund, attendance, a host request |

```dart
const ManageEventsScreen({super.key, required EventsManageRepository repository, required VoidCallback onBack,
  VoidCallback? onBell, int unread = 0, String? initialTab, String? focusHostApplicationId,
  Widget Function(Widget page)? pageWrap, EventPickers pickers = const EventPickers()});

const ManageEventScreen({super.key, required EventsManageRepository repository, required String eventId,
  required VoidCallback onBack, VoidCallback? onBell, int unread = 0, Widget Function(Widget page)? pageWrap,
  ManagedEvent? initial, EventPickers pickers = const EventPickers()});
```

`pickers` is the test seam for the day and time dialogs; `initial` is the list's row, drawn at once while the page
reads the event again. Neither screen draws a bottom bar. The one page pushed here (an event's manage page from
the list) goes through `AppShell.push(context, (_) => (pageWrap ?? (p) => p)(page))`. Every form and decision is a
sheet over everything (`showEditSheet`), so the keyboard never meets the bottom bar.

## Screens

### Manage Events (`ManageEventsScreen`)

Title bar "Manage Events" with the bell, then two tabs.

**Events** — the website's `EventsAdminPanel` (staff mode).

- The search box ("Search by title, place, host, chapter or council"), asked of the API 250 ms after typing stops.
- Filters, all asked of the API: All / Upcoming / Past, the type (All Types and the six kinds), the host
  (All Hosts / ICR Events / Partner Events).
- The count and **New Event** (the event sheet).
- A row per event, as the table's row: title (the typed words highlighted), type and partner company, day, time
  and "going / seats", and the one status (Published, Hidden, Ended). The row opens the event's manage page —
  the table's eye, pencil, bin and More menu all live there.
- "Show More" in place of the table's pages (20 to a page).
- **Other Matches**: with a search of two letters or more under a filter, up to six matches across every date,
  type and host that the filter leaves out — what the website's search suggestions are for.
- "No events match" / "No events yet", with "Clear Search and Filters".

**Event Partners** — `EventHostRequestsPanel`.

- The search ("Search company or contact") and the standings as pills: Waiting (with the number that waits,
  from `pending-count`), Approved, Rejected, Revoked, All.
- A row per request: company, kinds of event and how often, the day asked and the contact, the standing.
- The row opens the request in full (`RequestDialog`): what they plan, kinds, how often, website (opens the
  browser: it is the company's own site), contact, who asked and when, events hosted, the decision. Waiting:
  a note, **Reject** (needs the note) and **Approve**. Approved: a reason and **Revoke Hosting**.
- `initialTab: 'event-hosts'` opens on this tab. `focusHostApplicationId` opens it on All, reads up to five
  pages to find the request, tints its row, scrolls to it and opens it (the website's `focusId`).

### Manage Event (`ManageEventScreen`)

Title bar "Manage Event", then the event's type and host, its title and status, and six tabs that never come and
go.

| Tab | Website | What it does |
|---|---|---|
| Details | `EventDetails`, `EventDialog` | Date, time, location, host, attendance, price, who can join, call for speakers, visibility, public page, created, the description with its headings. **Edit Event** opens the event sheet; **Remove Event** asks first ("Cancel & remove "…" from the public calendar?"). The public page is a link only where the app has its own screen for it. |
| Guest List (n) | Programme → Guest list | The open-to-everyone note; **Invite by Email** (addresses split on spaces, commas and semicolons; unknown ones reported back); **Invite by Tier** (Silver, Gold or Enterprise and above); the result sentence; each guest with the bin to revoke (asked first). |
| Speakers (n to review) | Programme → Speakers | Each talk with its speaker, abstract and status. The row opens it in full with the note, **Decline** (needs the note) and **Accept**. |
| Sponsors (n to decide) | Programme → Sponsors | Packages with **Add a Package**; a package's row opens it to edit or remove. Requests with their status; a row opens it with the note, **Decline** (needs the note) and **Confirm**. |
| Tickets | `EventTicketsDialog` | Tickets sold, 50 to a page. A paid ticket's row opens **Refund Ticket**: the PayU sentence, the reference, **Mark Refunded**. Done at once it says "Refund recorded."; above the finance limit the tab shows the website's notice, "Sent for approval — ₹… is more than one person may move alone…", and nothing is recorded. |
| Attendance | none (API only) | Who is going and waiting; **Mark Attendance** once the event has started: tick the guest list and paid ticket holders who came, and the result says how many were marked and the CPD hours each. |

### The event sheet (`EventFormSheet`)

Every field of `EventDialog` in staff mode: Title, Slug (follows the title on a new event), Type, Capacity, Ticket
Price (₹), Host Chapter or Host Council (choosing one clears the other), Location with address suggestions
(`AddressSearchField`, `keepSuggestionText`), Starts, Ends, the Description as five fields (Overview, Agenda, Who
should attend, What you will take away, Good to know — stored as the HTML the event page renders; text outside
the fields is kept), Published, Invite only, Call for Speakers Open Until.

What it refuses before the API is asked (`CreateEventDto`): no title, a title over 160 characters, a slug over
160, a capacity that is not a whole number of 1 or more, a price below 0 or above ₹10,00,000 (100,000,000
paise), a location over 240 characters, no start, a description over 8,000 characters — and an end that is not
after the start, which the API does not check but every reader of the event assumes.

**Times are on the Indian clock.** The website's form reads and writes the browser's own zone; every Events
screen of the app shows IST (`ist` in `events/event_format.dart`), so the sheet writes what those screens read
back, and labels each time "IST".

## Endpoints

| Call | Used for |
|---|---|
| `GET /events/admin?page&limit&search&when&kind&host` | the list, Other Matches, and finding one event by id |
| `GET /events/:id` | the title of a listed event, to search the staff list with (see below) |
| `POST /events` · `PATCH /events/:id` · `DELETE /events/:id` | create, edit, remove |
| `GET /chapters/admin` · `GET /councils/admin` (else `GET /chapters`, `GET /councils`) | the host pickers |
| `GET /locations/addresses?q&session` | venue suggestions |
| `GET /events/:id/invites` · `/proposals` · `/sponsorships` · `/programme` | the programme, read together |
| `POST /events/:id/invites` · `POST /events/:id/invites/by-tier` · `DELETE /events/:id/invites/:userId` | the guest list |
| `PATCH /events/proposals/:proposalId` | accept or decline a talk |
| `POST /events/:id/packages` · `PATCH /events/packages/:packageId` · `DELETE /events/packages/:packageId` | packages |
| `PATCH /events/sponsorships/:sponsorshipId` | confirm or decline a sponsor |
| `GET /events/admin/tickets?eventId&page` | tickets sold |
| `POST /events/tickets/:ticketId/refund` | record a refund (executed, or `{ approvalRequired: true, approval }`) |
| `POST /events/:id/attendance` | mark who came |
| `GET /event-hosts/applications?status&search&page&limit` · `GET /event-hosts/applications/pending-count` | Event Partners |
| `POST /event-hosts/applications/:id/approve` · `/reject` · `/revoke` | the decision |

A refusal is shown in the API's own words, in the sheet that asked, with what was typed kept.

## Where the app differs from the website, and why

- **One event by id.** The API has no single-event staff read. `ApiEventsManageRepository.event(id)` reads the
  public `GET /events/:id` for the title (a listed event answers it), searches `GET /events/admin` by that title
  and picks the row by id; for a hidden event (the public read is a 404) it walks the staff list, 100 to a page,
  up to five pages. Opened from the list, the page already holds the row and draws it at once.
- **A cleared field is cleared.** Editing, the website leaves a blank Capacity, Location, Ends, Host Chapter and
  Host Council out of the request, so once set they cannot be removed there, and choosing a council leaves the old
  chapter on the event. The app sends `null` for them, which the API stores.
- **Host pickers for an Events Admin.** `GET /chapters/admin` and `/councils/admin` need `chapters:manage` and
  `councils:manage`, which the Events Admin role does not hold; the website's pickers are then empty. The app falls
  back to the public lists (published chapters and councils), up to 100 of each.
- **A package can be edited.** The website offers add and remove only; the API has `PATCH /events/packages/:id`
  and tells staff to "raise its slots first" when a full package is confirmed, so the package's row opens it for
  editing.
- **Attendance.** The website has no screen for `POST /events/:id/attendance`. The API lists an event's guest
  list and its tickets to staff, never its RSVPs, so those are the people who can be ticked; a member who took a
  free place uninvited cannot be marked from the app. The API marks only those who held a place and says how many.
- **Revoking an invite asks first.** The website revokes on the tap; on a phone the bin sits under a thumb.
- **Pages.** "Show More" replaces the tables' page numbers and rows-per-page.

## Not ported

- **"Open in Approvals"** on the sent-for-approval notice: the app has no Approvals console (`/admin/approvals`),
  and nothing is handed to the website. The notice's title and sentence are shown.
- **`TranslationsPanel`** (skipped by the brief).
- **A cover picture.** The website's event form has no cover field either (`coverUrl` is in the DTO but no form
  sets it); an event that has one shows it on Details.
- **Partner mode** of the panel (`HostEventsWorkspace`): staff mode only. The repository's `events`, `createEvent`,
  `updateEvent` and `deleteEvent` are what a host implementation over `/event-hosts/me/events` would replace.

## Tests

`test/events_manage_test.dart` (30 tests, a fake repository in memory): the rules (description fields, the clock,
the event's and package's limits, invites, refund references, the refund's two answers); the list, its search,
filters and Other Matches; a row opening the manage page inside `pageWrap`; the event sheet refusing what the DTO
refuses, keeping what was typed on an API refusal, editing and clearing, venue suggestions, removing; inviting by
email and by tier, revoking; a talk declined with a reason and accepted; a package added, held to its limits and
removed; a sponsorship confirmed; a refund recorded at once and one that waits for approval; attendance; a host
request rejected, approved and revoked; a notification's request opening on its own; every page and tab at 360 dp
and 840 dp.

`flutter test test/events_manage_test.dart --dart-define=FEED_SOURCE=live`

## Wording (13 Nov 2026, the leftover pass)

The client's rule for the whole app ("refine text and make it crisp for global standard"): Title Case for what a person taps or reads as a label, a short sentence with a full stop for everything else, plain international English, no dash inside a sentence. This feature was built the day of the app-wide pass and missed it. Wording only.

| What | Was | Now |
|---|---|---|
| Empty and missing states, as headings | No events yet · No events match · No requests waiting · No requests match · Event not found · No talk proposals yet · No packages yet · No sponsorship requests yet · No tickets sold yet · Nobody is on the guest list yet | No Events Yet · No Events Match · No Requests Waiting · No Requests Match · Event Not Found · No Talk Proposals Yet · No Packages Yet · No Sponsorship Requests Yet · No Tickets Sold Yet · No One on the Guest List Yet |
| Labels and kickers | Hosted by · Who can join · Call for speakers · Public page · What they plan · Kinds of event · How often · Asked by · Events hosted · Talk proposal · Sponsorship request · Request to host events · "… and above" · "N invited" · Sent for approval · Show More | Hosted By · Who Can Join · Call for Speakers · Public Page · What They Plan · Kinds of Event · How Often · Asked By · Events Hosted · Talk Proposal · Sponsorship Request · Request to Host Events · "… and Above" · "N Invited" · Sent for Approval · View More |
| Tick boxes | Published (listed publicly) / Unpublished (hidden) · Invite only — on the board and open to RSVP only for members on the guest list | Published (Listed Publicly) / Unpublished (Hidden) · Invite Only (Guest List Members Only) |
| Helpers | Blank = unlimited · Blank = free. GST is added at checkout. · Blank: no cap · Pick a suggestion, or type any place. · ICR members only; others are reported back. · Required to decline; they read it · Tick everyone who was present. | Leave blank for unlimited. · Leave blank for a free event. GST is added at checkout. · Leave blank for no limit. · Select a suggestion, or type any place. · ICR members only. Other addresses are reported back. · Required to decline. They will see it. · Select everyone who was present. |
| Failures | Could not invite. · Could not record the refund. · Could not mark attendance. · Write the reason first. · Give the company a reason — they will see it. | Unable to send the invite. · Unable to record the refund. · Unable to mark attendance. · Enter the reason first. · Give the company a reason. They will see it. |
| Sentences | "… has been told." · "… is taken off the guest list." · "Cancel & remove …" · the approval note ("is more than one person may move alone, so someone else who approves finance actions must approve it") · the attendance notes ("Record who actually turned up…", "Nobody to mark yet: …") · the page lead with a dash | "… has been notified." · "… will be removed from the guest list." · "Cancel and remove …" · "is above the limit one person can approve alone. Another finance approver must approve it." · "Record who attended. An RSVP is only an intention. Attendance earns CPD hours…", "No one to mark yet. People on the guest list and paid ticket holders can be marked here." · the lead with a colon |

Left as they were: the description's section headings (Overview, Agenda, Who should attend, What you will take away, Good to know) because they are written into the event's public description and read back by name, as the website does; hints inside empty fields; fact lines ("12 going · no seat limit", "2 invited · not members: …"); and the agenda example "10:00 — Registration and coffee", which shows the format.
