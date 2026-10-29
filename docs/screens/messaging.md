# Messaging (inbox and conversation)

**Designed since 29 Oct 2026:** `docs/designs/messaging-inbox.png` and `messaging-thread.png` (390 dp frames at 2x), measured with `tool/design/measure.py`; the styles are `InboxColors`/`InboxText`/`ThreadColors` beside `ChatColors`/`ChatText` in `messaging_styles.dart`, and the demo content (`DemoMessagingRepository`) carries the designs' threads newest-first (Dr. Radhika Iyer, Srikanth Sriramagiri, Vikasha Aero Tech, Rajesh Sharma, Marcus Reed) with the designs' photos in `assets/images/demo/messaging/`. Goldens: `test/golden/messaging_golden_test.dart` (the inbox) and `messaging_thread_golden_test.dart` (the thread), both on the demo content with the clock pinned to the design's day. The screens hold what the website's `/messaging` workspace holds on a phone (`frontend/src/components/messaging/**`, `features/messaging*`, `backend/src/modules/messaging`, and the "Messaging" and "Company inbox" paragraphs of the portal's `CLAUDE.md`). Code: `lib/features/messaging/`. The bell and the notifications screen share its look and are in `docs/screens/notifications.md`.

Tests (every control below names the one that proves it): `test/messaging_inbox_test.dart` (the list), `test/messaging_conversation_test.dart` (an open thread), `test/messaging_files_test.dart` (files and shared records), `test/messaging_launcher_test.dart` (every way in, "New message", the notification router), `test/messaging_context_test.dart` (the rules, no widgets), `test/messaging_api_test.dart` (every call against answers shaped like the real API's) and `test/live/messaging_live_test.dart` (the real API). Stand-ins: `test/messaging_fakes.dart` (`FakeMessagingRepository`, `TableAdapter`). Seed: `tool/seed/inbox.ts`.

## What is built

### The inbox (`InboxScreen`)
- **Header:** "Messaging" with an "N Active" pill (the view's total; in a company inbox "Acme FM · N Active"), a sliders button (key `inbox-options`) and a navy pencil square (key `compose`, "New message"). The sliders menu holds **"Mark all as read"** (`POST /messaging/conversations/read-all`, key `mark-all-read`) and, for someone who answers for a company, the **inbox switcher**: "My messages" and each company inbox (`GET /messaging/inboxes`, keys `inbox-<id>`) with the other inbox's unread count; the sliders carry a red dot while another inbox has unread. Choosing an inbox opens its own first view with no filter carried over; an inbox the person no longer answers for falls back to their own. A back arrow appears only when the screen was pushed.
- **Search** (a grey box, "Search messages, contacts, RFQs...") across people, companies and message text (`?search=` on the list, and `GET /messaging/search` from two letters), a moment after the person pauses: "Messages" hits (each opens its thread **on that message**, paging back to it when it is older than the newest window) above the matching conversations.
- **Filter chips**, one row scrolling sideways, the chosen one navy: **Focused (N)** is the whole inbox (the old "All"), **Unread (N)**, **Vendor RFQs (N)** (requirements and bids), **Mentorship (N)**, **Starred**, **Direct (N)**; a kind's count shows while it is known (the kind's total when selected, or the list count while the list is the whole inbox). The same kind chip again clears it. **Company inbox views** Open · Unread · Mine · Done · Spam, and one chip per topic the inbox takes (Sales, Procurement…), in the same pills.
- **Pinned threads** are listed above the rest on Focused (`GET /messaging/conversations?filter=pinned`, at most ten). Under a kind or a search they stay in the list instead, so a pinned thread of that kind never disappears (the website drops them).
- **A row** (`ConversationTile`): a 45 dp avatar (a person's photo; a company's first two initials on mint; a room's group glyph) with a presence dot when the source says (`ChatPerson.online`: green / grey; the API sends none, so a real person has no dot); the name in bold with, after it, a building glyph for a company, a green shield for a mentorship or consultation with a person, and a verified check when `Conversation.verified` (set by the demo from its context; the list endpoint does not say); the time at the right ("10:42 AM" today, "Yesterday", "Apr 14"), with the pin and star marks before it; a headline line (`ChatPerson.headline`, else the kind); **one context chip** — the `contextLabel` (a council, a group, "RFQ #2026-084"), else the old "why it exists" line, else the kind — amber with an edge for a requirement, grey for mentorship/group/consultation, blue for a council, chapter or company-inbox topic; the last word ("You:" for your side's, a colleague by first name in a company inbox, "Shared a record", the file's name with a paperclip, "Message deleted" in italics) on two lines when the row is emphasised, else one; and the unread count as a small circle (navy; green for a requirement). An unread row that is not a requirement is **emphasised**: tinted, a 4 dp bar down its left edge and a bold navy time; a requirement's unread is its green count alone, as the design draws it. Rows are separated by a hairline and read out as one sentence by a screen reader.
- **Press and hold** a row: Star / Remove star, Pin to top / Unpin from top (`PATCH …/preferences`, at once, put back with the API's sentence when refused).
- States: loading, error with Retry, empty (per filter), pull to refresh, "Show more conversations" and scrolling near the end append the next page without repeats. **Polling:** the list reads again quietly every 30 s while the screen is open and in front (stopped in the background, read at once on return).
- **Not in the design's words:** the row for a group room is named by the room's title with the group glyph (the design draws a member's photo and headline for "CXO Workplace Group"; the model has no host). The design's "5 Active"/"Focused (4)" are its sample; the number is the view's total.

### A conversation (`ConversationScreen`)
- **Title bar:** back, "Messages", the bell with its unread dot — painted over the contact card so its shadow falls on it.
- **Contact card:** a rounded-square avatar with a verified badge overlay (when the context's company is verified), the name with a filled verified seal, and "Chair, Net-Zero Council • Bengaluru" (the context company's role or industry • city; the old "Direct · Global Infra · …" line when there is no company). A tap opens the member's or the company's page (through the router); a **chevron** opens today's "what the thread is about" strip beneath the card (a requirement "Enquiry · Mumbai · Closes 4 Nov" or "They replied · ₹4,85,000", a mentorship's topics and next session, a group session, a consultation, a titled thread; hidden when the thread has nothing to say); a ⋮ after it holds the menu: Star, Pin, and for someone answering in a company inbox: Mark done · Mark as spam · Move back to open · Assign to me · Unassign (`PATCH …/company`). The design's "18 mutuals" has no source in the API and is left out. Business events inside the thread (bid submitted, purchase order, mentorship started, session held…) still draw as lines with "View bid" / "Open mentorship" links.
- **History:** the newest 50 messages (`GET …/:id?take=50`) on the grey page; a **day pill** (white, calendar glyph, lower case: "today, april 16", "yesterday, …", "friday, 23 october"); messages from one person within five minutes read as one block under one "Name  10:14 AM" header with the avatar at the left; theirs in a white hairline bubble, **mine in a blue bubble at the right with the time and a tick under it** — a green double tick ("Seen", key `tick-seen`) for everything of mine up to the message the API says was read (1:1 only), a single grey tick otherwise (`tick-sent`). "Load earlier messages" (and scrolling to the top) pages back with `GET …/messages?before=<id>&take=50`; a failed page leaves the thread as it was.
- **Send text** (`POST …/messages`, trimmed): the message appears at once as "Sending…", then as sent; a refusal **keeps it in the thread with its reason, Retry and Discard** (Discard puts the words, and the file, back in the box). At most 4000 characters (near the limit the count replaces "Draft Saved"). A thread read from a company inbox writes **as the company** ("Replying as Acme FM", `asCompanyId`).
- **Composer:** a row of pills — the paperclip ("Photo or File", the phone's picker, refused by size (10 MB) and kind before upload, uploaded as a `message-attachment`, held in the box with its name and size), **RFQ** (opens "Share an ICR record" on the Requirements kind), **Meet** (opens the thread's own record where a session is booked — the pairing, the group session, the purchase; hidden when the thread has none), and a smiley (a sheet of 24 common emoji that inserts at the cursor); "Draft Saved" at the right while a draft is kept; then the grey input pill ("Write a message or attach RFP...") and the send arrow (slate when empty, blue when there is something to send). No microphone: the API has no voice messages. **Drafts** (`DraftStore`, in memory for the session): the box's words are kept per conversation a second after typing stops and on leaving, restored on reopening, cleared on send.
- **A file in a thread** is a white card under the bubble: a deep-blue tile, the name, "680 KB • DOCX", **Preview** and a download glyph — both fetch the file **with the person's session** and hand it to the phone's share sheet (save it, or open it elsewhere); a photo is drawn from its private bytes.
- **The meeting card**, after the last message when the context has a consultation, a pairing's next session or a group session still to come (20 minutes assumed): a video tile, the title, the topic or kind, a panel "Tomorrow, 4:00 PM – 4:20 PM IST", **Add to Cal** (a Google Calendar link, as Events) and **Join Meeting** (the join link when the context carries one — it does not yet, see below — else the record through the existing openers). The design's "Google Meet Bridge • Encrypted ICR Room" line draws only with a join link.
- **Reply, copy, delete, report** (press and hold a message): Reply quotes it (a bar over the box, the quote in the thread; a tap on a quote scrolls to the original); Copy text; Delete your own (asks, withdraws it for everyone, the bubble reads "This message was deleted"; put back if refused); Report someone else's (a reason, an optional note; ICR reviews it).
- **Shared ICR records:** a line that is only a link to a job, requirement, company, product, mentor or event is drawn as a white hairline card read through the record's own public endpoint (title, owner, place, figure, date); a link in a sentence stays a link and gets its card too. A record the reader may not see says "This job isn't available to you" and leaks nothing. A tap opens the record **in the app** through `NotificationRouter` (the website when no screen takes it).
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

- **The meeting card's join link and end time.** `ConversationContext` carries a consultation's `scheduledAt`, a pairing's `nextSessionAt` and a room's `nextAt`, no join URL and no end: the card assumes 20 minutes and Join opens the record. A `joinUrl`/`endsAt` on the context would finish it.
- **"18 mutuals"** on the contact card and **presence dots** on the rows: nothing in the API says either. `ChatPerson.online` exists for the demo and is null from the API.
- **A verified check on a row** (`Conversation.verified`) is set by the demo from its context; the list endpoint sends no such flag, so a real inbox shows none until it does.

- **No socket.** The website pushes `message:new`, `typing`, `message:deleted`, `conversation:read`, `conversation:changed` and `notifications:changed` over socket.io (`/api/socket.io`, handshake `auth.token`). `socket_io_client` is not in `pubspec.yaml` (the lead's), so the app **polls** (the open thread every 4 s, the list every 30 s, the bell every 60 s), and there is **no "typing" indicator** (it exists only as a socket event). Adding the package and connecting `UnreadCounts`, `InboxController` and `ConversationController` to those events replaces the timers without touching a screen.
- **A person who answers for two sides of one requirement** (buyer and supplier) and must choose which they write as (`replyAsOptions`): the thread opens as the first inbox they handle. Rare; not built.
- **Saving a received file** goes through the phone's share sheet ("Save to files", "Open in…"), not a download folder.
- **A message between two people writes no bell row** (a portal bug, `docs/backend-requests/messaging.md` item 1): the Messages badge is right, the Notifications list shows nothing for it until that fix.
