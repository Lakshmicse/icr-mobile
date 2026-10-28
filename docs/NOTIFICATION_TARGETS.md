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
| The app's own screen | **42** (39 registered openers + 3 built into the router) |
| Nothing (staff consoles) | **14** |
| The website's page in the app's web view | **8**, plus the catch-all `path` |
| No page | `none`: only read |

## Opens in the app (42)

| Kind | The page it stands for | What opens in the app |
|---|---|---|
| `job` | `/jobs/:jobId` | The job's sheet, read with `GET /jobs/:id`, over the list |
| `job.edit` | `/manage/jobs/:id/edit` | The job composer on that job |
| `application.employer` | `/manage/jobs/:id/pipeline?applicant=` | The job's applicants |
| `application.candidate` | `/career/applications/:id` | The application's page, read by id |
| `jobAlert` | `/career/alerts?search=` | Job alerts |
| `career` | `/career` | Your career hub |
| `company.page` | `/companies/:id` | The company's page (insights, reviews, jobs, people) |
| `rfq.owner` | `/manage/requirements/:id?bid=&section=` | The requirement's page, on the bid or section |
| `rfq.supplier`, `rfq.public` | `/manage/bids/:id`, `/rfq/:id` | The requirement as a supplier sees it |
| `product` | `/products/:id` | The product page |
| `mentorship.pairing` | `/mentorship/my/:id?session=&task=` | The pairing |
| `mentorship.groupSession` | `/mentorship/groups/:id` | The group session |
| `mentorship.programme` | `/mentorship/programmes/:slug` | The programme |
| `mentorship.mine` | `/mentorship/my?tab=` | My mentoring, on the tab it names (requests, purchases, reports) |
| `mentorship.certificate` | `/mentorship/certificates/:id` | My mentoring › Certificates |
| `mentor.purchase` | `/mentorship/my/sessions/:id` | A bought 1:1: My mentoring › Purchases. One sold (`side: seller`): the Mentor desk |
| `mentor.desk` | `/mentorship/mentor?tab=&focus=` | The Mentor desk |
| `mentor.application` | `/mentorship/become-a-mentor` | Become a mentor |
| `mentor.profile` | `/mentorship/mentors/:id` | The mentor's profile |
| `mentor.directory` | `/mentorship/mentors` | Find mentors |
| `learning.assessment` | `/learning/assessment/:code/:slug` | Assess Your Knowledge (the catalogue, not the one paper) |
| `learning.course` | `/learning/professional-development/:code` | The course's sheet, found by its code |
| `learning.workspace` | `/learning/courses/:code` | The same sheet (the learner's workspace is a website page) |
| `learning.partners` | `/learning/partners` | The Learning tab |
| `event` | `/events/:slug` | The event's sheet |
| `forum.thread` | `/community/:slug#reply-:id` | The discussion's page, scrolled to the reply |
| `forum` | `/community` | The Forums tab |
| `member` | `/members/:id` | The member's public profile |
| `documents` | `/documents` | The Digital Library |
| `profile` | `/profile?tab=credentials` | My profile, on Credentials |
| `membership.plans` | `/pricing/:slug`, `/career/plans` | The plans screen, on the audience it names |
| `membership.history` | `/membership/history` | Plan history and receipts |
| `dashboard` | `/dashboard` | The Home tab |
| `account.companies` | `/account/companies` | My companies (switch, leave, create), `MyCompaniesScreen` |
| `mentorship.cpd` | `/mentorship/cpd` | Get Involved & Volunteer, where the member's CPD credits are |
| `blog` | `/blogs/:slug` | The post, drawn by the app from `GET /cms/blogs/:slug` (`BlogPostScreen`); the blog list without a slug |
| `refer` | `/refer`, `/refer/credits` | Invite: the member's code and link, rewards and counts (`ReferScreen`, `GET /referrals/me`) |
| `advertise` | `/advertise?placement=` | Advertise: the two placements, the member's price, their placements (`AdvertiseScreen`) |
| `conversation` *(router)* | `/messaging?c=&m=&inbox=` | The thread, as that company, on that message |
| `messaging` *(router)* | `/messaging?inbox=` | The inbox |
| `notifications` *(router)* | `/notifications?tab=` | This list |

## The website's page in the app's web view (8 + `path`)

These are ICR pages that have **no screen in the app**; they open signed in, inside the app, on the app's own white
loading state (never a dark frame), with a close button and back through the page's history. Five kinds that used to be
here have screens now (below).

| Kind | Page | Why it is not a native screen |
|---|---|---|
| `interview.panel` | `/manage/interviews/:id` | The hiring manager's feedback form; the app has the candidate side of interviews only |
| `talentSearch` | `/talent?savedSearch=` | The employer's talent search is not in the app |
| `team` | `/manage/team?tab=` | Team admin (members, join requests, roles) |
| `team.invite` | `/invite/:token` | Accepting an invitation is the website's page |
| `company.workspace` | `/company?tab=` | The company's workspace: details, verification, certifications |
| `articles.mine` | `/manage/articles` | A member's own articles |
| `support.ticket`, `support` | `/support/:id`, `/support` | The support desk: tickets with messages, attachments, rating and reopening is a build of its own (the API has it: `GET/POST /support/tickets`, `/messages`, `/reopen`, `/rate`) |
| `path` | any other page | An older row, an onboarding step; `SiteRoutes.inApp` still maps what the app has a screen for |

## Nothing opens (staff only, 14)

`admin.jobReview`, `admin.verification.supplier`, `admin.verification.company`, `admin.company`,
`admin.mentorship.concern`, `admin.learning`, `admin.forum`, `admin.blogs`, `admin.documentReports`,
`admin.messageReports`, `admin.supportTicket`, `admin.subscriptions`, `admin.marketing`, `admin.contact`.

These are the consoles ICR's staff work in on the website. The app has no console, so a tap reads the row and says
"That one is for ICR's staff tools, which aren't in the app."

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
