# Where a notification opens

A tap on a notification reads it and opens **its record in the app**. The API names what a row is about
(`backend/src/modules/notifications/notification-targets.ts`) and stores the page that stands for it; the app reads
the page back into a kind and its ids (`NotificationTarget.parse`) and hands it to the `NotificationRouter`.

The router asks, in this order:

1. **An opener the app registered for the kind** (`lib/app_notifications.dart`, `appNotificationOpeners`): the app's own
   screen, with the record read by id through the app's own repositories.
2. **The router's own** (a conversation, the inbox, the notifications): `NotificationRouter.builtInKinds`.
3. **Staff-only** (`NotificationRouter.staffKinds`): the admin consoles. The app has none, so the row is read, nothing
   opens, and a calm note says so.
4. **Everything else**: the website's page as the API stored it, opened by `openSitePage`, which asks the app for a
   screen first (`SiteRoutes.inApp`: events, members, vendors, plans…) and otherwise shows the page **in the app's web
   view, signed in**. A tap on an ICR page never ends in the phone's browser.

A record that cannot be read (deleted, no longer the person's, offline) shows **"This is no longer available."** and
opens nothing; the spinner that covered the wait is gone. An opener that throws says the same.

`test/notification_openers_test.dart` places every kind in exactly one of the groups below and fails when a kind is
added to `NotificationKinds` and not placed here; `test/live/notifications_live_test.dart` does the same for the kinds
in a real person's list.

## Counts

| Where a tap goes | Kinds |
|---|---|
| The app's own screen | **47** (44 registered openers + 3 built into the router) |
| Nothing (staff consoles) | **13** |
| The website's page in the app's web view | **5**, plus the catch-all `path` |
| No page | `none`: only read |

## Opens in the app (47)

| Kind | The page it stands for | What opens in the app |
|---|---|---|
| `job` | `/jobs/:jobId` | The job's sheet, read with `GET /jobs/:id`, over the list |
| `job.edit` | `/manage/jobs/:id/edit` | The job composer on that job |
| `application.employer` | `/manage/jobs/:id/pipeline?applicant=` | The applicant's page (`ApplicantDetailScreen`, read by `GET /applications/:id`) over the job's applicants, so Back lands on the pipeline, as the website's drawer sits on it; a link naming no applicant (`job.pipeline`) opens the applicants alone. Opening the applicant reads every notification about the application. Until 5 Nov 2026 it opened the applicants list and left the person to find the applicant |
| `interview.panel` | `/manage/interviews/:id` | The interview's page for its panel (`InterviewBriefScreen`, `GET /interviews/:id`): the candidate and résumé, notes for the panel, the round, screening, team notes, earlier rounds, and the scorecard (`POST /interviews/:id/feedback`). Opening it reads the round's notifications. In the web view until 4 Nov 2026 |
| `application.candidate` | `/career/applications/:id` | The application's page, read by id |
| `jobAlert` | `/career/alerts?search=` | Job alerts |
| `career` | `/career` | Your career hub |
| `company.page` | `/companies/:id?tab=` | The company's page, on the tab it names (`reviews`, `interviews`, `people`, `jobs`; Overview and anything else on the first, `insightsTabOf`). The tab was ignored until 5 Nov 2026 |
| `rfq.owner` | `/manage/requirements/:id?bid=&section=` | The requirement's page, on the bid or section |
| `rfq.supplier`, `rfq.public` | `/manage/bids/:id`, `/rfq/:id` | The requirement as a supplier sees it |
| `product` | `/products/:id` | The product page |
| `mentorship.pairing` | `/mentorship/my/:id?session=&task=` | The pairing. The session and task it names are not scrolled to (the pairing screen has no focus), and opening it reads the pairing's notifications |
| `mentorship.groupSession` | `/mentorship/groups/:id` | The group session; opening it reads its notifications |
| `mentorship.programme` | `/mentorship/programmes/:slug` | The programme |
| `mentorship.mine` | `/mentorship/my?tab=` | My mentoring, on the tab it names (requests, purchases, reports) |
| `mentorship.certificate` | `/mentorship/certificates/:id` | The certificate's own page, the sheet that checks it by its printed number (`showMentoringCertificateCheck`), as the website's public page does. My mentoring › Certificates when the link names none. It was that tab until 5 Nov 2026 |
| `mentor.purchase` | `/mentorship/my/sessions/:id` | A bought 1:1: My mentoring › Purchases. One sold (`side: seller`): the Mentor desk's Work tab. Opening it reads the purchase's notifications |
| `mentor.desk` | `/mentorship/mentor?tab=&lane=&focus=` | The Mentor desk, on the tab the link names (`work`→Work, `sales`→Earnings, `services`/`plans`/`cohorts`→Offerings, `mentoring`→Mentees, `settings`; `deskTabOf`). The `focus` row and the `lane` are not scrolled to (the desk has no focus). The tab was ignored until 5 Nov 2026 |
| `mentor.application` | `/mentorship/become-a-mentor` | Become a mentor |
| `mentor.profile` | `/mentorship/mentors/:id` | The mentor's profile |
| `mentor.directory` | `/mentorship/mentors` | Find mentors |
| `learning.assessment` | `/learning/assessment/:code/:slug` | Assess Your Knowledge (the catalogue, not the one paper) |
| `learning.course` | `/learning/professional-development/:code` | The course's sheet, found by its code |
| `learning.workspace` | `/learning/courses/:code` | The same sheet (the learner's workspace is a website page) |
| `learning.partners` | `/learning/partners?apply=` | The Learning tab; `apply` opens the institute application form |
| `admin.learning` | `/admin/learning/enquiries?lead=` | The partner institute's Enquiries (`PartnerEnquiriesScreen`, the app's own since 7 Nov 2026: the owner's tap on "New enquiry about CSF from Bindhya S" was told "staff tools"), opened on the enquiry the row names and tinted. Since 12 Nov 2026 the rest of the partner institute's console is the app's too, for the institute's staff: no section (a course's review decision) and `courses` open Manage Courses, `batches` and `enrolments` open theirs narrowed to `?course=` (`lib/features/partner_console/`). ICR staff, and the Learning Center's own sections (`icr-courses`, `partner-applications`, `course-review`), still get the staff-tools note (`NotificationRouter.staffOnly`) |
| `event` | `/events/:slug` | The event's sheet |
| `admin.community`, `admin.eventHosts` | `/admin/community?tab=applications&application=` / `&proposal=`, `?tab=event-hosts&application=` | Since 13 Nov 2026 the app's own manage pages, for the staff who hold the section's key: a chapter application opens Manage Chapters on Applications, a council proposal Manage Councils on Proposals, a company asking to host events Manage Events on Event Partners, each on the request named. Without the key: "This page is for the ICR staff who run chapters, councils or events." |
| `forum.thread` | `/community/:slug#reply-:id` | The discussion's page, scrolled to the reply. One target for every discussion notification: a comment (`forum.replied`), a reaction to a post or a comment (`forum.reacted`, `forum.reactedToReply`), a repost (`forum.reposted`) and a tag in a post or a comment (`forum.mentioned`, `forum.mentionedInReply`). The row wears the actor's photo, sits under Community and articles (a `forum_` type, or any type that links to `/community/...`), and `#reply-:id` brings the comment into view |
| `forum` | `/community` | The Forums tab |
| `member` | `/members/:id` | The member's public profile |
| `documents` | `/documents` | The Digital Library |
| `profile` | `/profile?tab=credentials` | My profile, on Credentials |
| `membership.plans` | `/pricing/:slug`, `/career/plans` | The plans screen, on the audience it names |
| `membership.history` | `/membership/history` | Plan history and receipts |
| `dashboard` | `/dashboard` | The Home tab |
| `account.companies` | `/account/companies?focus=` | My companies (switch, leave, create), `MyCompaniesScreen`. `focus=invitations` ("X added you to a company", `team.addPending`) scrolls to the **Waiting for you** card and washes it in blue for a moment; each place there is accepted (`POST /me/companies/invitations/:id/accept`, which hands back a fresh session, adopted like a switch) or declined (`…/decline`). The card did not exist in the app until 5 Nov 2026, so a member could not answer the invitation at all |
| `team` | `/manage/team?tab=` | The company's Team (`TeamScreen`): Members, Requests and Pending. `tab=requests` ("someone asked to join your team") opens on Requests, where an admin approves with a role and office or declines. In the web view until 5 Nov 2026 |
| `support.ticket` | `/support/:id` | The request's thread (`TicketScreen`, `GET /support/tickets/:id`): messages, attachments, history, reply, reopen, rating. Opening it reads the notifications about the request (`PATCH /notifications/seen`, as the website's `useMarkSeen('support.ticket')`). Tickets staff raise from a member's contact message open the same way. In the web view until 5 Nov 2026 |
| `support` | `/support` | Help & support (`SupportScreen`): the member's requests, the common questions, the ICR account manager when one is named. In the web view until 5 Nov 2026 |
| `mentorship.cpd` | `/mentorship/cpd` | Get Involved & Volunteer, where the member's CPD credits are |
| `blog` | `/blogs/:slug` | The post, drawn by the app from `GET /cms/blogs/:slug` (`BlogPostScreen`); the blog list without a slug |
| `refer` | `/refer`, `/refer/credits` | Invite: the member's code and link, rewards and counts (`ReferScreen`, `GET /referrals/me`) |
| `advertise` | `/advertise?placement=` | Advertise: the two placements, the member's price, their placements (`AdvertiseScreen`) |
| `conversation` *(router)* | `/messaging?c=&m=&inbox=` | The thread, as that company, on that message |
| `messaging` *(router)* | `/messaging?inbox=` | The inbox |
| `notifications` *(router)* | `/notifications?tab=` | This list |

## The website's page in the app's web view (5 + `path`)

These are ICR pages that have **no screen in the app**; they open signed in, inside the app, on the app's own white
loading state (never a dark frame), with a close button and back through the page's history. Nine kinds that used to be
here have screens now (above), `team`, `support.ticket` and `support` the latest (5 Nov 2026). The session is written from `/robots.txt`
first, which the page then replaces in the history, so Back never lands on it; should it ever come back, the screen
closes.

| Kind | Page | Why it is not a native screen |
|---|---|---|
| `talentSearch` | `/talent?savedSearch=` | The employer's talent search is not in the app |
| `learning.teaching` | `/learning/teaching?batch=` | A trainer's teaching desk (batches, invitations to teach) is a partner institute's console. A kind the API has always had; the app had no name for it before 5 Nov 2026 and opened it as a `path` |
| `team.invite` | `/invite/:token` | Accepting an **email** invitation by its token is the website's page (the account is made or signed into there, with the invited address). An admin **adding someone already on ICR** is the in-app invitation above (`account.companies`) |
| `company.workspace` | `/company?tab=` | The company's workspace: details, verification, certifications |
| `articles.mine` | `/manage/articles` | A member's own articles |
| `path` | any other page | An older row, an onboarding step; `SiteRoutes.inApp` still maps what the app has a screen for |

## Nothing opens (staff only, 13)

`admin.jobReview`, `admin.verification.supplier`, `admin.verification.company`, `admin.company`,
`admin.mentorship.concern`, `admin.forum`, `admin.blogs`, `admin.documentReports`,
`admin.messageReports`, `admin.supportTicket`, `admin.subscriptions`, `admin.marketing`, `admin.contact`.

These are the consoles ICR's staff work in on the website. The app has no console, so a tap reads the row and says
"That one is for ICR's staff tools, which aren't in the app." (`NotificationRouter.staffOnlyMessage`). `admin.learning` left this list on
7 Nov 2026: its enquiries section is a partner institute's, not staff's, and opens in the app (above); its opener gives the other sections this
same answer.

## Checked against real rows (5 Nov 2026)

All 1,407 rows of the ten e2e personas on the local API (a throwaway live test parsed, categorised and placed every one):
**1,179 opened an app screen**, 192 are staff consoles (a calm note), **18 were web-view rows** (16 `team`, 2
`support.ticket`; they open the app's Team and ticket screens since 5 Nov 2026, so by kind 1,197 now open an app
screen and none opens the web view; the live pass was not repeated) and 18 are `path` rows (course and mock-exam purchases at `/learning/mock-tests/...`) that the app
maps to its own Assess Your Knowledge screen. The reads each opener makes (`GET /applications/:id`, `/interviews/:id`,
`/rfq/:id`, `/mentorship/:id`, `/mentor-services/purchases/:id`, `/mentorship/group-sessions/:id`, `/members/:id`,
`/learning/courses`, `/messaging/conversations/:id`) answered 200 for a row of each kind; a discussion row whose thread
was deleted by an e2e run answers 404, which the app shows as "This is no longer available.", and a requirement
invitation to a recruiter, hiring manager or branch admin answers 403 (their role has no supplier workspace) on the
website as well.

## What a tap does besides opening (the website's `useOpenNotification`, `useMarkSeen`)

- **It reads the row** at once (the dot and the count move before the API answers, put back if it refuses).
- **It switches the acting company first** when the row carries `companyId` and the person is acting for another
  (`POST /me/companies/switch`), says "Now working as …", and then re-reads who the person is
  (`AuthController.refreshUser`). That builds the signed-in app again for the company, as the companies screen's switch
  does, and the record opens through the **rebuilt app's router** (`NotificationRouter.current`), not the one whose
  controllers belonged to the old company. Until 5 Nov 2026 only the token was swapped: the tabs, menu and role in the
  app stayed on the old company. A company the person has left is refused with its reason and nothing opens.
- **It reads the record's other rows.** A record page calls `PATCH /notifications/seen` on the website
  (`useMarkSeen`); the app does it where it opens the record: the candidate's application, an applicant, the interview
  brief, a pairing, a group session, a purchase, and (in their own controllers) the buyer's and supplier's requirement
  pages. Not done for a discussion: the API keys its rows by thread id and the link carries only the slug.
- **The list follows the bell.** When the app-wide count moves without the list (a record read its other rows, a new
  notification arrived on the minute poll or on resume) the open list reads again, as the website invalidates every
  notification query. The website pushes over a socket; the app polls every 60 s.
- **Times read on the phone's clock.** `GET /notifications` carries `?tz=` (`viewerTimeZone`, the phone's zone as best
  Dart can name it from its offset: Asia/Kolkata, Dubai, Singapore…, else `Etc/GMT±N`), as the website sends the browser's;
  without it the API words a session's time on the Indian clock.

## What the website notifies a member about, and what it does not (checked 5 Nov 2026)

- **A contact message's status** (`NEW`, `IN_PROGRESS`, `RESOLVED`, `SPAM`; the staff Contact Inbox, `PATCH
  /contact/:id/status`) **notifies nobody.** `ContactService.updateStatus` only writes the column, and a contact
  message has no user (name, email and phone as typed), so the API has no one to tell. Checked against the local API:
  moving a volunteer application through IN_PROGRESS and RESOLVED left the sender's notifications unchanged. A
  volunteer application is a contact message with topic `VOLUNTEER` ("Volunteer application: Chapter Committee
  Member…" is the app's own subject line), so the same holds. The owner's screen showed statuses a member never hears
  about; that is the portal's behaviour, not an app fault.
- The one member-facing step is **"Convert to ticket"** in the staff inbox: when the sender's email matches an account
  the API sends `support_ticket_raised` ("raisedFromMessage", target `support.ticket`) and sets the message IN_PROGRESS;
  from then on a ticket reply, "awaiting you" and "resolved" notify the sender (`support.replied`,
  `support.awaitingUser`, `support.resolved`, target `support.ticket`, locked category Support). The app lists and
  reads all of those like any row; **a tap opens the request's thread in the app** (`TicketScreen`, since 5 Nov 2026;
  it was the web view before the app had a help desk).
- To tell a member that staff moved their message, the portal would need to match `ContactMessage.email` to a user in
  `updateStatus` and send a notification (a new target or `support`); the app would show it with no change.

## Where the app still has no screen for what a notification is about

Kinds a member can receive that open the website's page in the app's web view (the list above has the pages). The
three that were ranked first here (`team`, `support.ticket` / `support`, and the **Invitations** card behind
`team.addPending`) have screens since 5 Nov 2026. What is left:

- `company.workspace` (the company's details, verification dossier, certifications), `talentSearch`, `articles.mine`,
  `team.invite` (an emailed invitation's accept page), `learning.teaching` (a trainer's desk).

Not in the app's Team screen either (admin tuning, not what a notification asks for): the company-inbox card, the
inbox-topic and learning-role editors, and the seat history.

Opens the right screen but not the exact row (the app's screen has no focus to give): a pairing's `?session=` /
`?task=`, the mentor desk's `focus=` row and `lane=plans`, My mentoring's `purchase=`, an advertise `placement=`, a
mentor profile's `#reviews`, a job alert's `search=`.

## How the openers reach their data

The notifications list is a **pushed route**: it sits above the signed-in app's providers (`JobsController`,
`FeedController`, `MarketplaceController`…), so a screen opened from it cannot read them. The app builds the router
inside a `Builder` that sits **below** the providers (`lib/app.dart`) and gives `appNotificationOpeners` that context
(`shell`): an opener reads its repositories from `shell` and pushes over the context it was handed. The list itself is
pushed through `AppShell.push`, so a record opened from it can still reach the shell's menu and tabs
(`AppShell.goToTab`), and `NotificationRouter.current` (set by `InboxHost`) is the router a screen finds when it has
no provider above it.

Before this, the openers for `career`, `jobAlert` and `company.page` read `JobsController` from the list's own context,
which would have failed on a real tap; the three now go through `shell`.

## Adding a kind

1. The API adds it to `notification-targets.ts`; add it to `NotificationKinds`, `NotificationTarget.parse` and `all`
   (`notification_target.dart`).
2. Register an opener in `appNotificationOpeners` and add the kind to `appNotificationKinds` (or, with no screen, to
   `notificationKindsInWebView`; a staff page, to `NotificationRouter.staffKinds`).
3. Add its page to `hrefs` in `test/notification_openers_test.dart` and a row above.
