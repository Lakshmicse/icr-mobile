# Messaging (inbox and conversation)

No design exists for these screens. They are built in the language of the designed ones (Work Sans names, IBM Plex Sans body, hairline rows, pill chips, a 56 dp title bar with the back arrow) and hold what the website's `/messaging` workspace holds on a phone (`frontend/src/components/messaging/**`, `features/messaging*`, `backend/src/modules/messaging`, and the "Messaging" and "Company inbox" paragraphs of the portal's `CLAUDE.md`). Code: `lib/features/messaging/`. The bell and the notifications screen share its look and are in `docs/screens/notifications.md`.

Tests (every control below names the one that proves it): `test/messaging_inbox_test.dart` (the list), `test/messaging_conversation_test.dart` (an open thread), `test/messaging_files_test.dart` (files and shared records), `test/messaging_launcher_test.dart` (every way in, "New message", the notification router), `test/messaging_context_test.dart` (the rules, no widgets), `test/messaging_api_test.dart` (every call against answers shaped like the real API's) and `test/live/messaging_live_test.dart` (the real API). Stand-ins: `test/messaging_fakes.dart` (`FakeMessagingRepository`, `TableAdapter`). Seed: `tool/seed/inbox.ts`.

## What is built

### The inbox (`InboxScreen`)
- **Title bar:** back, "Messages", "Mark all as read" (`POST /messaging/conversations/read-all`), and a pencil for "New message".
- **Inbox switcher** (only for someone who answers for a company): "My messages" and a chip per company inbox (`GET /messaging/inboxes`), with the other inbox's unread count on its chip. Choosing one opens its **own first view with no filter carried over**; an inbox the person no longer answers for falls back to their own.
- **Search** across people, companies and message text (`?search=` on the list, and `GET /messaging/search` from two letters), a moment after the person pauses: "Messages" hits (each opens its thread **on that message**, paging back to it when it is older than the newest window) above the matching conversations.
- **Own inbox filters:** All · Unread (with the count) · Starred, and a kind chip each for Requirements and bids · Mentorship · Direct (the same kind again clears it). **Company inbox views:** Open · Unread · Mine · Done · Spam, and one chip per topic the inbox takes (Sales, Procurement…).
- **Pinned threads** are listed above the rest on the All tab (`GET /messaging/conversations?filter=pinned`, at most ten). Under a kind or a search they stay in the list instead, so a pinned thread of that kind never disappears (the website drops them).
- **A row** (`ConversationTile`): who it is with (a person's photo; a company's logo; a room's group glyph), why it exists (kind badge, then the requirement, consultation, job or topic beside it), the last word ("You:" for your side's, a colleague by first name in a company inbox, "Shared a record", the file's name, "Message deleted"), when ("2:25 pm", "Yesterday", "Thu", "19 Oct"), a dot, a bold name and a count when unread, a pin and a star. Read out as one sentence by a screen reader.
- **Press and hold** a row: Star / Remove star, Pin to top / Unpin from top (`PATCH …/preferences`, at once, put back with the API's sentence when refused).
- States: loading, error with Retry, empty (per filter), pull to refresh, "Show more conversations" and scrolling near the end append the next page without repeats. **Polling:** the list reads again quietly every 30 s while the screen is open and in front (stopped in the background, read at once on return).

### A conversation (`ConversationScreen`)
- **Header:** back, the other side's avatar and name (a person, a company or a room), "Direct · Global Infra · …" under it, a tap on it opens the member's or the company's page (through the router), and a menu: Star, Pin, and for someone answering in a company inbox: Mark done · Mark as spam · Move back to open · Assign to me · Unassign (`PATCH …/company`).
- **What the thread is about** (a strip under the header, a tap opens the record): a requirement ("Enquiry · Mumbai · Closes 4 Nov" or "They replied · ₹4,85,000"), a mentorship (its topics, the next session), a group session, a consultation, or a titled thread (a job: "Senior Facilities Manager · Global Infra"). Business events inside the thread (bid submitted, purchase order, mentorship started, session held…) draw as lines with "View bid" / "Open mentorship" links.
- **History:** the newest 50 messages (`GET …/:id?take=50`), a day separator, messages from one person within five minutes read as one block, mine on the right in blue and theirs on the left. "Load earlier messages" (and scrolling to the top) pages back with `GET …/messages?before=<id>&take=50`; a failed page leaves the thread as it was.
- **Send text** (`POST …/messages`, trimmed): the message appears at once as "Sending…", then as sent; a refusal **keeps it in the thread with its reason, Retry and Discard** (Discard puts the words, and the file, back in the box). At most 4000 characters (a count shows near the limit). A thread read from a company inbox writes **as the company** ("Replying as Acme FM", `asCompanyId`).
- **Attachments** (`file_picker` is in `pubspec.yaml`, so the paperclip is on by default): "Photo or File", read from the phone, refused by size (10 MB, before it is read into memory) and by kind (images, PDF, Office, text, zip) before anything is uploaded; uploaded as a `message-attachment` (`POST /uploads?purpose=message-attachment`), held in the box with its name and size (remove it with the cross), sent with or without words. A file in a thread is a row (name, size, download glyph) and a photo is drawn from its private bytes; a tap fetches the file **with the person's session** and hands it to the phone's share sheet (save it, or open it elsewhere).
- **Reply, copy, delete, report** (press and hold a message): Reply quotes it (a bar over the box, the quote in the thread; a tap on a quote scrolls to the original); Copy text; Delete your own (asks, withdraws it for everyone, the bubble reads "This message was deleted"; put back if refused); Report someone else's (a reason, an optional note; ICR reviews it).
- **Shared ICR records:** a line that is only a link to a job, requirement, company, product, mentor or event is drawn as a card read through the record's own public endpoint (title, owner, place, figure, date); a link in a sentence stays a link and gets its card too. A record the reader may not see says "This job isn't available to you" and leaks nothing. A tap opens the record **in the app** through `NotificationRouter` (the website when no screen takes it). The link icon beside the paperclip opens "Share an ICR record": the six kinds as chips, a search, tap a row and its link goes into the box on its own line.
- **"Seen":** under your newest message the other person has read, in a one-to-one thread (the API sends it for a 1:1 only).
- **New messages arrive by polling** every 4 s while the screen is open (`GET …/messages?after=<newest id>`: only what is new, plus the "seen" marker), and the thread is read again when something arrives. Stopped in the background, caught up on return.
- **An empty thread** says who it is with and offers openers by who the reader is (a supplier: "Is this still open for quotes?"; the buying team: "Could you share your quote?"; a mentee or mentor: their next session): a tap puts it in the box.

### "New message" (the pencil)
Search a person or a supplier (two letters, `GET /messaging/recipients`), tap a person (their plain thread is reused when the two already share one: `POST /messaging/conversations`) or a supplier (its sales inbox answers: `POST /messaging/conversations/supplier`); the thread opens. A refusal ("no one answers this supplier's sales inbox yet") stays in the sheet in the API's words.

## Constructors and calls the lead wires

```dart
// 1. Once, above the signed-in shell (also gives every bell its number and the notification router):
InboxHost(api: context.read<ApiClient>(), router: NotificationRouter(openers: {...}), child: AppShell(...))

// 2. Any screen's "Messages" entry (a drawer row, a Discover tile): the inbox.
MessagingLauncher.openInbox(context);                       // or inbox: <companyId>
// The Messages badge for that entry:
final unread = messagesUnread(context);                      // from UnreadCounts

// 3. A thread you already have the id of (a notification, a mentoring screen's conversationId):
MessagingLauncher.openConversation(context, conversationId, asCompanyId: ..., focusMessageId: ...);

// 4. Every "Message" button. Each opens the thread through the record's own endpoint, then pushes it.
//    All return Future<bool>; false = refused (the API's sentence is shown, nothing opens).
MessagingLauncher.withPerson(context, userId, message: ...);                  // a member (their profile, a forum author)
MessagingLauncher.withSupplier(context, vendorId: ..., rfqId: ...);           // "Send Message" on a supplier listing / a bidder, optionally about a requirement
MessagingLauncher.withSupplier(context, companyId: ...);                      // a supplier known only by its company: its sales inbox
MessagingLauncher.withCompany(context, companyId, topic: 'CAREERS');         // "Message" on a company page: SALES / CAREERS / PARTNERSHIP / GENERAL
MessagingLauncher.forJob(context, jobId);                                     // a job's hiring contact (the API picks the person)
MessagingLauncher.forMentorship(context, mentorshipId);                       // a pairing: Mentoring.forMentorship
MessagingLauncher.forPurchase(context, purchaseId);                           // a bought 1:1 or consultation
MessagingLauncher.forGroupSession(context, sessionId);                        // a group session's room (the person must hold a seat)
MessagingLauncher.forRfq(context, rfqId, supplierCompanyId: ...);             // a requirement's other side: a supplier opens its own, the buying team names the supplier (a bidder)
MessagingLauncher.forApplication(context, applicationId);                     // a recruiter's thread with an applicant

// 5. Attachments: nothing to do (the paperclip uses the phone's picker). To take it away: MessagingLauncher.attachmentPicker = null.
```

Every call takes the repository the app provided (`Provider<MessagingRepository>`), else the API with the signed-in session, and carries the app's `UnreadCounts` and `NotificationRouter` into the pushed route (a route pushed on the app navigator is outside the providers of the screen that pushed it; `NotificationScope` lays them back). The screens (`InboxScreen`, `ConversationScreen`) also take `repository:`, `clock:` and `poll:` for a test or a demo.

`mentoring_links.dart` (mentorship_my) already names `MessagingLauncher.openConversation`, `.forMentorship`, `.forPurchase` and `.forGroupSession` as the callbacks it wants; `JobsNavigation.onOpenConversation` takes `MessagingLauncher.openConversation` and the jobs "Message" button can call `MessagingLauncher.forJob` directly.

**The notification router opens conversations without any registration:** `/messaging?c=<id>&inbox=<company>&m=<message>` (kind `conversation`) opens the thread as that company, on that message; `/messaging?inbox=<company>` (kind `messaging`) opens that inbox. See `notifications.md` for the rest of the router and the bell.

## Controls and the tests that prove them

`W` widget test, `U` unit/mapping, `L` live (`test/live/messaging_live_test.dart`).

| Control | Proved by |
|---|---|
| Rows: name, kind, about line, last word, stamp, unread dot/count, pin/star, one-sentence semantics | W inbox "the rows", U context "the preview…", "how a conversation is named" |
| Filters All / Unread / Starred, kind chips, the unread count on the chip | W inbox "filters", L "pinned, starred and unread…", "a kind narrows…" |
| Search (people, companies, message text), debounce, clear, a hit opens its thread on the message | W inbox "search", W conversation "a message named by a search hit…", L "a name finds its thread…" |
| Pinned above the rest; kind/search keep them in the list | W inbox "the rows", "filters", U context "excluded-pinned flag", L "pinned…" |
| Star / pin by press and hold, refusal restores | W inbox "star and pin", L "star and pin on a thread" |
| Mark all as read, refusal restores, the badge follows | W inbox "mark all as read", L "Mark all as read…" |
| Pull to refresh, paging, polling (and background pause), failed poll silent | W inbox "states", "paging", "polling" |
| Company inboxes: switcher, views, topics, fallback, open as company | W inbox "the company inboxes", L "a seller answering for a company" |
| Open a thread: newest window, days, blocks, mine/theirs, quote, markRead, bell | W conversation "opening a conversation" |
| Header from the row before the thread loads; failure + Retry; can't open (403/404) | W conversation "opening a conversation" |
| History paging (take/before), auto page at the top, failed page, focus on an old message | W conversation "earlier messages", U controller "ensureLoaded", L "a thread pages back…" |
| Send, trimmed, Sending…, refusal keeps the words, Retry, Discard, 4000 limit, as a company | W conversation "sending", L "send, read, seen, reply, delete…", "an empty message…" |
| Reply, close the reply bar, jump to the quoted message, Copy, Delete (confirm/cancel/refusal), Report (reason, note, refusal), withdrawn has no menu | W conversation "a message's menu", L "a reply carries…", "a message is reported…" |
| "Seen" (1:1) and its move on a poll | W conversation "Seen", L "send, read, seen…", "an open thread catches up by polling" |
| Polling: new message arrives and is read, failure silent, background, leave stops | W conversation "new messages arrive by polling", L "an open thread catches up…" |
| Header tap (member/company), Star/Pin, company sorting (Done/Spam/Open/Assign/Unassign) | W conversation "the header", "a company inbox thread", L "Done, back to Open, Assign…" |
| Context strip, business events, openers, intro | U context (strip, openers, events), W conversation (empty thread) |
| Paperclip: hidden/shown, upload, bar, remove, send file alone, too big, wrong kind, upload refusal, offline, uploading state, cancel, Discard returns it | W files "the paperclip", L "a file: uploaded…", "a file the API would not take…" |
| A file in a thread: open with the session, failure, photo bytes, withdrawn | W files "a file in the thread", L "a file: …closed again when withdrawn" |
| The phone's picker: Photo / File sheet, source passed, over-limit never read, mime from the name | W files "the phone's picker" |
| Shared record cards (all kinds, in a sentence, blocked, offline, loading, other site, open in the app) | W files "shared records", L "each of the six kinds…", "a record shared in a message…" |
| "Share an ICR record": kinds, search, pick → link in the box, retry | W files "Share an ICR record", L "a search narrows a kind…" |
| Every entry point (user, supplier by listing/company/about a requirement, company, job, pairing, purchase, room, requirement, applicant) | W launcher "each Message button…", U api "starting a thread", L "starting a thread reuses the seeded ones" |
| Refusal shown, nothing opens, busy guard, left screen | W launcher "when the API refuses…", L "what the API refuses…" |
| "New message": two letters, people and suppliers, open, refusal, none, retry, from the inbox pencil | W launcher "New message", L "who New message can reach" |
| A pushed route keeps the counts, router and repository | W launcher "a pushed screen still reaches…" |
| Notification router: conversation (side, message), inbox, personal | W launcher "a notification that names a conversation…" |
| Every parser, every request body | U `messaging_api_test.dart`, L (the whole file) |
| The Messages badge = the API's number | L "the app-wide badge…", W notifications `UnreadCounts` tests |

## Seed (`tool/seed/inbox.ts`, idempotent and removable)

Run from `E:\ICR\irc-portal\backend` (Git Bash): `NODE_PATH=E:/ICR/irc-portal/node_modules npx ts-node --transpile-only E:/ICR/icr-mobile/tool/seed/inbox.ts [--remove]`. It needs `learning-jobs`, `events-councils` and `home` first (it reads Sarah, David, Global Infra, the design jobs and events). Add it to `run.ps1` after `home` (remove it first, before `home`).

Bharat Buyer gets **nine notifications** (four unread: a grouped "3 messages", an application moving stage, a company's message with its logo, a forum reply; read ones: an event reminder, a booked 1:1, a plan renewal, a referral reward, a support reply) and these threads: **sarah** (direct; a reply, a shared job link, two waiting), **company** (Global Infra's careers inbox: written as the company, one waiting), **david** (pinned and starred; a PDF, a withdrawn message, "Seen"), **rfq** (a requirement with its supplier, a seller's reply waiting), **enquiry** (a sales enquiry to the supplier), **friend** (a plain thread with the Inbox Persona), **room** (the group session he holds a seat at, when it has no thread yet) and, only when the pairing has none, **mentoring** (his pairing with Anand). Beside them: the two threads other screens' live runs made (a job's hiring contact, the e2e vendor).

**The Inbox Persona** `inbox.friend@inbox-seed.icr.test` / `Inbox@12345` (Anita Rao, a PROFESSIONAL nobody else uses) is who the live tests write as. Two threads **Bharat is not in** carry every write, so a live run never moves his inbox: **duo** (Anita and the supplier's seller, Vikram Vendor: send, read, reply, "seen", withdraw, files, report, mark all read) and **sandbox** (her enquiry to the supplier's inbox: the seller answers as the company, and the supplier's people get its bell rows). The only thing a run does to Bharat's own threads is star and pin the **friend** thread and put them back. Marker: ids `inbox-seed-…`, the persona's email domain, `/uploads/inbox-seed-site-checklist.pdf`. `--remove` deletes all of it (the persona's audit rows, the bell rows live runs left) and sets the pairing's and the session's thread back to none.

## Handoffs kept

None by choice. A record a message links to opens through the router: where no screen of the app has registered for its kind yet, the website's page opens (`NotificationRouter`'s fallback), so a card is never a dead tap.

## Not done, and why

- **No socket.** The website pushes `message:new`, `typing`, `message:deleted`, `conversation:read`, `conversation:changed` and `notifications:changed` over socket.io (`/api/socket.io`, handshake `auth.token`). `socket_io_client` is not in `pubspec.yaml` (the lead's), so the app **polls** (the open thread every 4 s, the list every 30 s, the bell every 60 s), and there is **no "typing" indicator** (it exists only as a socket event). Adding the package and connecting `UnreadCounts`, `InboxController` and `ConversationController` to those events replaces the timers without touching a screen.
- **A person who answers for two sides of one requirement** (buyer and supplier) and must choose which they write as (`replyAsOptions`): the thread opens as the first inbox they handle. Rare; not built.
- **Saving a received file** goes through the phone's share sheet ("Save to files", "Open in…"), not a download folder.
- **A message between two people writes no bell row** (a portal bug, `docs/backend-requests/messaging.md` item 1): the Messages badge is right, the Notifications list shows nothing for it until that fix.
