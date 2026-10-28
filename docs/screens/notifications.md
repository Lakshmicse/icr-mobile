# Notifications (the bell)

No Figma design exists for this screen. Since 27 Oct 2026 it is drawn like **the Android LinkedIn Notifications tab** (owner's request: "the list should work like Android, and a tap should go to the concerned page or data in the app"): Roboto, white rows with hairline rules, 14 sp sentences with the name in bold, 12 sp detail and age at 60 % black, an unread row on a pale-blue tint with a dot. Its colours and type are Home's (`HomeLook`, `roboto` in `features/feed/feed_styles.dart`), kept for this screen in `notification_styles.dart` (`NoteLook`, `NoteType`). It holds what the website's `/notifications` page and its bell tray hold (`frontend/src/components/notifications/**`, `features/notifications*`, `backend/src/modules/notifications`, `docs/NOTIFICATIONS.md`). **Where every kind of notification opens: `docs/NOTIFICATION_TARGETS.md`.** Code: `lib/features/notifications/`. Tests: `test/notifications_test.dart` (mapping, routing table, controller, counts), `test/notifications_screen_test.dart` (every control tapped), `test/notifications_router_test.dart` (the router alone), `test/messaging_launcher_test.dart` (a conversation target opens the thread in the app), `test/live/notifications_live_test.dart` (the real API). Seed: `tool/seed/inbox.ts`. The Messages screens that share its look are in `docs/screens/messaging.md`.

## What is built

- **`NotificationsScreen`**: title bar (back, "Notifications", "Mark all read", a gear for the preferences), then the filter chips and the list:
  - **Chips** (LinkedIn's): **All**, **Unread (n)**, then one short chip for each kind of notification that has a row among those loaded (Messages, Jobs, Requirements, Mentoring, Learning, Events, Community, Membership… `chipLabelOf`, in the preferences' order). The API has no category filter, so a kind's chip filters what is loaded and reads further pages while fewer than 8 of its rows are in view (`NotificationsController.selectCategory`). Unread asks `unread=true`.
  - **Rows** grouped **Today · This week · Earlier** (sentence case, 16 sp) by the reader's own midnight, newest first, a page of 20 at a time (`GET /notifications?page&limit=20[&unread=true]`), more by scrolling near the end or "Show older notifications". Pull to refresh reads the list and the count again.
  - **A row** (`NotificationRow`): a **48 dp** photo (initials without one) with the category's glyph on its corner when a person is behind it; the company's **logo** when the message was sent as a company's inbox (`actorCompany`); the category's tinted glyph alone for a platform notice. The sentence at 14 sp with the person or company in bold (the API stores the sentence with the name already in it, so the bold is the name found inside it), the body under it (12 sp, two lines), "For <Company>" only for someone who works for more than one; at the right the **short age** (`compactAge`: now, 42m, 3h, 2d, 1w, 4mo) with a blue dot while unread, and a **⋮**.
  - **The ⋮ sheet**: **Mark as read** (only on an unread row; the API has no "unread" and no delete, so neither is offered), **Turn off <kind> notifications** (that kind's in-app switch through `PUT /notifications/preferences`, one category; not offered for the always-sent kinds: payments, support, security), and **Notification settings**.
  - **The gear** (and "Notification settings") opens the **Preferences** view: every category with an in-app and an e-mail switch; a switch moves at once and saves alone, a refusal puts it back and shows why with Dismiss. Payments, Support and Security are "Always sent": on, disabled, never sent to the API. The gear again goes back to the list.
  - **Grouped by the API**: a thread with several unread messages is one row, "Sarah Jenkins sent you 3 messages" (`count`); the app shows the sentence the API worded.
  - **Preferences** tab: every category (`GET /notifications/preferences`), an in-app and an e-mail switch each; a switch moves at once and saves alone (`PUT /notifications/preferences`, one category), a refusal puts it back and shows why with Dismiss. Payments, Support and Security are "Always sent": on, disabled, never sent to the API.
  - States: loading, error with Retry, empty ("No notifications yet"), empty Unread ("Nothing unread"), an empty kind ("Nothing under Jobs and applications yet").
- **What a tap does** (`_open`): the row is read at once (the dot, the count and the bell move before the API answers; a refusal puts them back and the API's sentence is shown), then:
  1. A row about **another company** (`company`) switches the person to it first (`POST /me/companies/switch`, which returns a fresh token pair that the app stores), says "Now working as <Company>", and tells the app through `NotificationRouter.onCompanySwitched`. A company the person has left refuses the switch ("You're no longer part of X, so this can't open as it."): nothing opens.
  2. The row's `link` (a root-relative page, what `notificationHref` stored) is read back into its **target** (`NotificationTarget.parse`: the API's kind and the ids the page needs, for every kind in `notification-targets.ts`), and opened by `onOpenTarget` when the screen was given one, else by the app's `NotificationRouter`: the opener registered for that kind (`lib/app_notifications.dart`: the app's own screen, the record read by id), else the router's own (a conversation, the inbox, this list), else, for a staff console, a calm note and nothing, else **the website's page in the app's web view, signed in** (never the phone's browser). A record that cannot be read says "This is no longer available." See `docs/NOTIFICATION_TARGETS.md` for every kind.
  3. A row with no page is only read.
- **The bell on every title bar**: `UnreadCounts` (a small `ChangeNotifier`) holds the two numbers the app's badges show: unread notifications (`GET /notifications/unread-count`) and unread messages (`GET /messaging/unread-count`). Two light reads on start, every 60 s while the app is in front, and again when it returns from the background; the notifications and messages screens set the numbers themselves the moment something is read, so the dot moves at once. `InboxHost` provides it (and the router) above the shell. A title bar needs one line: `TitleBar(unread: bellUnread(context), onBell: () => openNotifications(context))`.
- **`markNotificationsSeen(context, kind, id)`**: what the website's `useMarkSeen` does. A record page calls it when it opens (`PATCH /notifications/seen`): whatever told the person about that record is read, however they got there, and the bell reads again.

## The calls the lead wires

```dart
// 1. Once, above the signed-in shell (it needs the ApiClient the app already provides):
InboxHost(
  api: context.read<ApiClient>(),
  router: NotificationRouter(
    onCompanySwitched: (context, companyId) { /* reload what the old company held */ },
    openers: {
      NotificationKinds.job: (context, t) { openJob(context, t['jobId']!); return true; },
      NotificationKinds.event: (context, t) { openEvent(context, t['eventId']!); return true; },
      // …one per kind the app has a screen for; return false to let the website take it.
    },
  ),
  child: AppShell(...),
)

// 2. Every title bar's bell:
TitleBar(title: 'Jobs', unread: bellUnread(context), onBell: () => openNotifications(context))

// 3. A record page, once it is open (in initState or a post-frame callback):
markNotificationsSeen(context, NotificationKinds.rfqSupplier, rfqId);

// 4. Opening the screen with its own opener (instead of the router):
openNotifications(context, onOpenTarget: (context, target) async { ... });
NotificationsScreen(onOpenTarget: ..., initialTab: NotificationsTab.unread)
```

`NotificationKinds` lists every kind with the page it comes from and the params it carries (`t['jobId']`, `t.recordId`). A row the app has no screen for opens the website, so a missing opener is never a dead tap.

## Controls and the tests that prove them

`W` = `test/notifications_screen_test.dart`, `U` = `test/notifications_test.dart`, `L` = `test/live/notifications_live_test.dart`.

| Control | What it does | Proved by |
|---|---|---|
| Rows, groups, headings, the Unread chip's count | Today / This week / Earlier by the reader's midnight; the count is the API's | W "groups rows…", U "grouping by when" |
| Short age | now, 42m, 3h, 2d, 1w | W "a row shows its age short…" |
| Kind chips | One per kind that has a row; a chip filters what is loaded, All brings the rest back | W "after All and Unread…", "a kind's chip shows only its rows…" |
| The ⋮ sheet | Mark as read (that row only, never opens it), Turn off a kind (saves `in=false` for that category), none for an always-sent kind, a way to the settings | W "the ⋮ opens a sheet…", "a read row has no…", "an always-sent kind…" |
| The gear | Opens the preferences; again goes back | W "the gear opens the preferences…" |
| Unread dot, bold name, person or glyph | Per row | W "an unread row has the dot…", "a person on the row…" |
| Tap a row | Reads it at once; a refusal restores it and shows the API's sentence | W "tapping a row reads it…", "a refusal puts the dot…", U controller, L "reading" |
| Tap → the app's own screen | The opener registered for the kind, with the ids the page names | W "a record the app has a screen for…", "a forum reply opens its thread…" |
| Tap → the web view | A page no screen takes opens as stored, in the app's web view; an opener that returns false passes | W "a page no screen of the app takes…", "an opener that declines…" |
| Tap → each kind's screen | Every registered kind is reached from a row of that kind; every kind the API can send is placed (screen, staff, web view); a job opens its sheet from outside the shell's providers; a job that cannot be read says so; a thread opens on its reply | `notification_openers_test.dart` (9 tests), L "every kind of notification in the list opens in the app…" |
| `onOpenTarget` | Replaces the router for the screen | W "onOpenTarget replaces the router…" |
| Row with no page | Read only | W "a row with no page…" |
| Another company's row | Switch first, say so, tell the app; refusal opens nothing; one company is never named | W "a row about another company…", "a company the person has left…", "a person in one company…", L "switching to a company" |
| Every page a notification can name | The route table, every kind the API sends, odd input never throws | U "every page a notification can name", L "every link the API stored…" |
| The router | A registered opener takes its kind with the ids; one that returns false, an unregistered kind and a full link fall to the website as stored; no page opens nothing; register/registerAll/unregister; the app's router is the one a screen finds | `notifications_router_test.dart` |
| A conversation target | `/messaging?c=&inbox=&m=` opens the thread as that company on that message, `/messaging?inbox=` the inbox, with no opener registered | `messaging_launcher_test.dart` "a notification that names a conversation…" |
| Mark all read | Reads every row, clears the bell; disabled at 0; a refusal restores | W "Mark all read…", "a refused Mark all read…", L "reading" |
| All / Unread tabs | Unread asks `unread=true`; reading all empties it | W "the Unread tab…", "opening on the Unread tab…", L "the unread count…" |
| Show older / scrolling | Next page appended without repeats | W "Show older notifications…", U "pages are appended…" |
| Pull to refresh | Reads the list and count again | W "pull to refresh…" |
| Loading / error / Retry / empty | Each state | W "an empty account…", "a failed first load…" |
| Preferences: switches, locks, refusal, retry | Moves at once, saves one category, locks never sent | W "preferences…" (5 tests), L "preferences: the 15 categories…" |
| The bell | Dot while anything is unread, live; opens the screen; no host = no dot | W "the bell on every title bar…" (3), "InboxHost…" (2), U "the app-wide counts", L "the app-wide counts…" |
| `markNotificationsSeen` | Names kind and id, refreshes the bell only when rows were read, swallows failure | W "a record page clears…" (2), L "reading…" (the `seen` step) |
| Every parser | Real response shapes: list, count, read, read-all, preferences, viewer, switch | U "the API mapping", L "the list…", "the viewer…" |

**Live runs leave** read notification rows for the supplier's sellers (one per message the Inbox Persona sends to the supplier's inbox in the test); Bharat's own rows are only read. `tool/seed/inbox.ts` clears them on its next run.

## Handoffs kept

None to the phone's browser. An ICR page the app has no screen for (13 kinds: the hiring manager's interview panel, the employer's talent search, team admin, invitations, the companies list, the company workspace, the CPD log, articles, the support desk, referral credits, placements) opens in the app's **web view**, signed in; the staff consoles (14 kinds) open nothing. Each moves to a native screen when its owner registers an opener (`docs/NOTIFICATION_TARGETS.md` → Adding a kind).

## Not done, and why

- **No push.** The website's bell is pushed `notifications:changed` over a socket; the app has no socket.io client (not in `pubspec.yaml`, which is the lead's), so the bell is read every 60 s and after any read. A phone push (FCM) needs a Firebase project and server side: not built.
- **The list sends only the page**, not the target's kind and id; the app reads them back from the page (`NotificationTarget.parse`, tested against every kind the API can send). If the API ever adds `target` to `NotificationDto` the parse can go.
