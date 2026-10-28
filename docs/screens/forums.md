# Forums: the Forums tab, a discussion's page, the reply thread, the composer

State (26 Oct 2026): **the flows are built and proved** against the real API and the website's own rules: a discussion's
page with its nested replies, every reply / like / reaction / save / follow / report / accept / edit / delete flow, the
Forums tab (views, topics, sub-topics, sorts, filters, search, paging, bookmarks, the moderation notice), the new/edit
composer with poll options and a file, poll voting, and the Home feed card opening all of it. By the owner's order
the pixel-to-pixel pass on the undesigned screens is postponed: see "Pixel pass later".

## Designs, and what has none

| Screen | Design |
|---|---|
| Home feed's open reply thread | `docs/designs/hires/forums-new-home.png` ("Forums / New home"): matched (see below) |
| Reply thread as its own component | `docs/designs/hires/forum-replies.png` ("Branching Nested Replies Section"): matched |
| Forums tab icon | `docs/designs/hires/nav-forums-icon.png`: the shell draws `Symbols.forum_rounded` filled, which is that glyph |
| The Forums tab, a discussion's page, the composer, every sheet | **no design**: built in the Home feed's visual language (Work Sans names and headings, IBM Plex Sans body, the same chips, card edges, rules; the same `PostCard` on the tab) |

The two reply designs disagree: the Home screen draws grey bubbles with 10 dp text, no role chip and a connector whose
last elbow turns the corner; the section component draws pale-blue bubbles with 12.5 dp text, the author's role in a chip,
a blue pill with a dot and an arrow, and a connector that runs past its last elbow. The app draws both, selected by one
argument (`ReplyLook`, `lib/features/feed/feed_styles.dart`): **`ReplyLook.home`** on the Home feed (matched to
`forums-new-home.png`), **`ReplyLook.section`** on the discussion page (matched to `forum-replies.png`). To make the Home
feed wear the section look: `ReplyThread(look: ReplyLook.section)` in `home_screen.dart`.

## Constructors and callbacks for the lead to wire

```dart
// Forums tab. Reads the forum from the Home feed's controller (Provider<FeedController>), so one widget is all the wiring:
AppShell(forums: Builder(builder: (ctx) => ForumsScreen(
  viewer: _viewer,                                   // FeedAuthor, as HomeScreen takes it
  onBack: () => AppShell.selectHome(ctx),
  callbacks: ForumCallbacks(onOpenMember: (id) => ..., onBell: () => ...),   // all optional
)));

// Home feed: the same optional callbacks (a card opens its discussion by itself, nothing else to wire):
HomeScreen(viewer: _viewer, onAccount: ..., callbacks: ForumCallbacks(onOpenMember: (id) => ..., onBell: ...))

// Opening a discussion from anywhere (a notification's target, a deep link):
final result = await openThreadPage(context,
  repository: feed.repository.forum,        // ForumRepository: ApiFeedRepository.forum / DemoFeedRepository.forum
  viewer: viewer, slug: slug,
  focusReplyId: replyId,                    // optional: a notification about one reply
  unread: unreadCount, callbacks: callbacks);
// ThreadResult? { FeedPost? post, bool deleted }: what the reader did there, for the caller's own list.

// Starting a discussion from anywhere (a "Post" button elsewhere):
await startDiscussion(context, repository: repo, viewer: viewer, topicSlug: 'technology');
```

* `ForumCallbacks.onOpenMember(String userId)`: a member's photo or name (a card, a reply, a reactor, the discussion's
  author). Absent, those taps do nothing.
* `ForumCallbacks.onBell`: the bell in a title bar. Absent, it opens the website's `/notifications` (as every other screen
  does until the shell wires it).
* `ForumCallbacks.onOpenTag(tag)` / `onOpenTopic(ForumTopicRef)`: a tag chip or the topic chip on a discussion's page.
  The Forums tab handles them itself (it filters and leaves the page); elsewhere they are optional.
* The Forums tab keeps its state while the shell switches tabs (the shell's `IndexedStack`); pull to refresh reads again.
* Demo mode (`FEED_SOURCE=demo`) works on all of it: `DemoFeedRepository.forum` is the in-memory forum.

## Screens and what each control does (and the test that proves it)

`W` widget test, `U` unit test, `L` live test (`test/live/forum_live_test.dart`, API up and seeded). Files:
`test/forum_thread_test.dart` (52 W), `test/forums_tab_test.dart` (28 W), `test/forum_composer_test.dart` (26: 5 U, 21 W),
`test/forum_home_test.dart` (7 W), `test/forum_demo_test.dart` (4 W), `test/forum_test.dart` (33 U), live: 21.

### A discussion's page (`ThreadScreen`, `thread_screen.dart`)

| Control | Does | Proved by |
|---|---|---|
| the page itself | the discussion (filing chips, title, "Started .. last activity .. N replies, N views", author, **the whole body drawn as the website's editor wrote it** (headings, bold, italic, links, bullet and numbered lists, quotes, code), photos, a file tile, the poll, tags, reactions, actions) and its replies | W "it draws what the forum holds"; U "a body written in the website's editor" (3); L "reading" (5) |
| loading / not found / failed | the list's card shows at once; 404 says "isn't here" with no retry; a failed read says why with Try again | W (3) |
| pull to refresh | reads the discussion and its replies again; the view is counted once per opening | W "the read is counted once"; L |
| locked, archived, waiting for review | notice; the reply box becomes the reason; a moderator may still reply | W (4); U "whether a discussion takes replies"; L "forums.ts" |
| replies | nested, three steps at most, role chip + company from the headline, accepted answer first and green, pending marked, a file under a reply | W "they hang off one line", "a pending reply..."; L |
| "Show more replies" | reads the next page of 100 and merges it under its parents (the forum cuts pages flat and promotes an answer whose parent is on another page) | W (2); U "the reply tree" (6); L "merged equal the replies read whole", "130 replies" |
| a link to one reply (`focusReplyId`) | reads pages until it is there (ten at most) and scrolls to it, ringed | W; L |
| Like | reacts at once, again takes it back, a refusal puts it back with the forum's sentence; one's own is refused by the page without asking, in the API's words | W (3); U; L "a reaction is kept, changed and taken back", "what the page refuses..." |
| holding Like | the five reactions (Like, Celebrate, Support, Insightful, Sustainable); the same again takes it back | W |
| "N reactions" / the views count | sheets: who reacted (signed in), who viewed (+ "N others read it with a private profile") | W; L |
| Reply | focuses the box; the box is pinned under the page, Enter writes a new line, the arrow sends | W |
| reply to a reply | "Replying to X" with an x; sent under that reply, stepped in | W; L |
| sending | escaped paragraphs; empty or over 20,000 characters refused before asking; a refusal reads above the box and **what was typed stays**; a reply waiting for a moderator is marked and not counted | W (3); U (3); L |
| Notify me | follows the discussion | W; L |
| Follow (author) | follows / unfollows; a refusal keeps it; absent on one's own | W; L |
| Save | bookmarks / unbookmarks | W; L |
| Share, Copy link | share sheet with the title and link; clipboard (reply: `#reply-<id>`) | W |
| poll option | votes or moves the vote, the bars follow the forum's totals; same option asks nothing; closed takes none and says Closed | W (3); L "a poll vote is kept, moves..." |
| a reply's three dots | Edit and Delete on one's own (a moderator's too), Copy link, Report on others' | W |
| edit a reply | the words come back to the box ("Editing your reply", an x), a save changes the tile and marks it edited; unchanged words send nothing | W (2); U; L |
| delete a reply | asks first; its answers stay in the thread at the top; the accepted mark goes with it | W; L |
| Like a reply | at once, refusal restores; one's own refused | W; L |
| Accept answer | only the asker (or a moderator) on a question; marks it, tints it, lifts it first, moves the mark; a refusal puts it back | W (3); U; L |
| Report (discussion or reply) | the forum's six reasons and a note up to 1,000 characters; a refusal shows in the sheet and keeps the note | W (3) |
| the discussion's three dots | Edit (author), Delete after asking (author), Copy link, Who viewed, Report (others') | W (4) |
| a member / the bell / a tag / a topic | `ForumCallbacks`; leaving hands back `ThreadResult` | W |

### The Forums tab (`ForumsScreen`, `forums_screen.dart`, `ForumsController`)

| Control | Does | Proved by |
|---|---|---|
| the tab | bar (Back, bell with the unread count), search with a filter button, "Start a discussion...", the views, the topics with counts, the discussions as `PostCard`s, the total, "You're all caught up" | W "it draws the bar..."; L |
| view chips | All Feed, Trending (`sort=top`), Following, Unanswered (`sort=unanswered`), Polls, Saved (`savedOnly`), My posts (`mineOnly`); each empty view says what it waits for | W (3); L |
| search | submitted words are the forum's `search`; a pill with an x brings the list back; "No discussions match..." | W (2); L |
| topic chip | the forum's `categorySlug`; its sub-topics appear (from the taxonomy) and filter further (`subcategorySlug`); the lit chip again goes back | W; L |
| filter sheet | order (Recent activity, Newest, Most upvoted; the view's own order in Trending and Unanswered), type (Any, Questions, Discussions), topic, sub-topic, a tag; "Show results", "Clear all"; the button counts what is set | W (3); L |
| a tag on a card | filters by it (the forum's tag filter is case-sensitive: sent as typed); a pill takes it off; a second pill clears everything | W (3); L |
| paging, pull to refresh | 20 a page, the next page near the end; refresh reads the list, topics, standing and bell again | W (2); L |
| a card | the Home card exactly: Like (hold for reactions), the bookmark (on Saved, a card let go leaves), Follow, poll vote, Share, the three dots (open, copy link, report), "N reactions", the author's photo, the title opens the page, the speech bubble opens it at its replies | W (6) |
| after a page | what the reader did there (reaction, save, vote, reply count) shows on the card; a deleted discussion leaves the list | W (3) |
| moderation notice | "Your first few posts are read by a moderator..." when `GET /forum/me` says `requiresApproval` (the community has no posting quota: owner's call 14 Oct 2026) | W |
| failed read / topics failed | message with Try again; the topics have their own retry | W |
| "Start a discussion..." | the composer in the topic being browsed; the new discussion opens on its page and joins the top of the list; one waiting for a moderator says so and does not open | W (3) |

### The composer (`NewThreadScreen`, `ComposerController`)

| Control | Does | Proved by |
|---|---|---|
| Discussion / Poll | the two kinds of a new post (the website's, since 19 Oct 2026); an edit keeps its own kind (an older post may be a question) | W; U |
| topic, sub-topic | a searchable list of the taxonomy (`GET /categories/tree?kind=SERVICE&depth=2`); a sub-topic row appears when the topic has some; the page the composer was opened from presets its topic | W (3) |
| title / details | 8 to 160 characters; details required (20,000 at most) except on a poll; hints show once typing starts, the whole list after Post; a refusal from the API reads at the top and **every field stays** | W (4); U (5) |
| poll options | 2 to 4 rows, add and remove, 80 characters each, duplicates (any case) refused; sent as `pollOptions`; fixed once posted (an edit never sends them) | W; U; L |
| tags | up to 5, 32 characters, lower case, spaces to dashes, "#" dropped (the forum's own `normaliseTags`); a comma adds; chips with an x; a tag typed and not added is sent | W (2); U |
| file | a photo or PDF from the phone (`file_picker`; a test hands in a picker), uploaded as `forum-attachment` **with its real media type** (the forum takes a file by it), shown as a tile, removable before sending; an edit can only replace one (the forum cannot clear it: `docs/backend-requests/forums.md` 3) | W (3); L |
| Post / Save | validated first, then sent as the website's DTO; a new post's `bodyHtml` is escaped paragraphs; an edit sends **no body** unless its words changed, and **no topic** unless it changed (a retired sub-topic would refuse a title edit), and no file unless replaced | W (5); U; L "an edit of the title alone keeps its body and topic" |
| website formatting on edit | "This post has formatting from the website... Changing its words here replaces the formatting." shown when it applies | W |
| leaving | asks before discarding typed work, not on a blank form | W (2) |
| moderation notice | shown to a reader whose posts are reviewed first | W |
| topics failed | message with Try again | W |

### The Home feed card (`HomeScreen`, `PostCard`, `ReplyThread`)

Open thread in place under the first card with the speech bubble: the first reply and its first answer, "+N replies in
this thread" (opens the rest in place), then "Open the whole discussion" to the page; Like and Reply on each reply (Reply
addresses that person and sends under it), the three dots (open at that reply, copy link, report, delete one's own), the
reply box (Enter sends). New this slice: the title or words open the discussion, "View Discussion" on a poll opens it,
"N reactions" lists who reacted, holding Like picks a reaction, the three dots report and open (no website page is opened
any more), "Post a requirement or insight..." is the composer. Proved by `test/feed_screen_test.dart` (69 W, the existing
tests updated where the behaviour moved) and `test/forum_home_test.dart` (7 W). A bug fixed on the way:
`FeedController.toggleReplyLike` rebuilt every other reply without its role, parent, accepted and pending flags.

## Endpoints (all read from `backend/src/modules/forum`; each proved by a live test)

`GET /forum/threads` (`page, limit, sort, search, tag, categorySlug, subcategorySlug, kind, savedOnly, mineOnly`),
`GET /forum/threads/:slug`, `GET /forum/threads/:slug/replies?page&limit=100`, `POST /forum/threads/:id/view`,
`POST /forum/threads` and `PATCH|DELETE /forum/threads/:id`, `POST|DELETE /forum/threads/:id/vote` (`{value:1, reaction}`),
`POST|DELETE /forum/threads/:id/save`, `POST|DELETE /forum/threads/:id/subscribe`, `POST /forum/threads/:id/poll/vote`,
`GET /forum/threads/:id/reactions`, `GET /forum/threads/:id/viewers`, `POST /forum/threads/:id/replies`,
`PATCH|DELETE /forum/replies/:id`, `POST|DELETE /forum/replies/:id/vote`, `POST /forum/threads/:id/accept/:replyId`,
`POST /forum/reports`, `GET /forum/categories`, `GET /categories/tree?kind=SERVICE&depth=2`, `GET /forum/me`,
`POST /uploads?purpose=forum-attachment` (multipart; the type must be sent: pdf, png, jpeg, webp),
`POST|DELETE /members/:id/follow`, `GET /members/me/following`, `GET /notifications/unread-count`.

The parsers were audited against **real responses**: `test/fixtures/forum/*.json` is what the running API sent
(`build/fm/capture_forum.py`), and `test/forum_test.dart` runs every parser over it. The audit found and fixed: a
reply's `updatedAt` moves on every like (so "edited" cannot come from it); the sanitiser writes `<br />`; `GET
/uploads/..` is served outside `/api/v1`; an upload without its media type is refused (`application/octet-stream`); a
sub-topic since retired refuses an edit that re-sends the topic; a pending discussion answers a vote with "not found".

## What the API cannot give, and what the app does instead

| Website / design | In the app |
|---|---|
| "VP Sustainability" role chip | the part of the author's headline before " at "/"@"/"·"; `forums.ts` sets Arvind Swamy's designation to the design's |
| a headline that names no company | the whole headline is the line under the name, no chip |
| "(edited)" on a reply | no edit time exists (`docs/backend-requests/forums.md` 2): only a reply edited in this session says so |
| the website editor's formatting | shown as written; the app's editor is plain text, so an edit that does not change the words sends no body, and changing them replaces the formatting (the composer says so) |
| Following / Polls views | the forum has no such filters (`docs/backend-requests/forums.md` 1): the app reads the latest 100 and keeps the matching ones (no paging in those two views) |
| quota banner | none exists (the community is free of posting limits); the one notice is the moderation one |
| a poll's "2 days left" | the poll has no closing time: "Open" / "Closed" |
| taking a file off a discussion | the forum cannot clear it: an edit can replace it |
| repost | the forum has none: its glyph says so (as on Home) |

## Handoffs to the website (kept, and why)

None to a website *page*. Two things open the system browser because there is nothing in the app to show them: **a file
attached to a discussion or reply** (its upload address) and **a link inside a post's text** (only http, https and
mailto; anything else is not a link).

## Seed

`tool/seed/forums.ts` (run after `home.ts`; `--remove`, `--dry-run`; idempotent; local database only) adds nine
discussions for the states above (an unanswered question, a question with an accepted answer, a locked discussion, a PDF,
a website-written body, **130 replies** to exercise paging, a closed poll, a question **Bharat** asked with three
answers (he can accept, edit, delete), a discussion of Bharat's **waiting for a moderator**), Bharat's and Pooja's saves,
and Arvind Swamy's headline. Details in its header and `tool/seed/README.md`. The 9 threads are unpinned: the Home feed's
order (the four designed posts first) is unchanged. One existing live test needed a one-line change (the Home live test
that picks "a discussion of Bharat's" now picks one from `home.ts`; a pending one cannot be reacted to).

## Pixel pass later (recorded, not done, by the owner's order)

* **Home look vs `forums-new-home.png`** (done to within about 0.5 dp: every text line has the design's width and sits
  within 1 px of its row): left to tune are the bubble's bottom padding (the tile is 0.5 dp taller than the design's
  102 dp), the elbow radius (8 dp now; the design's fillet reads slightly larger), the send arrow's glyph (the design's is
  wider and slate), the vertical dots' spacing, and the soft shadow (a golden draws it without blur). The card below the
  thread (David's) and the sponsored card sit 1 to 2.5 dp off the design as before this work.
* **Section look vs `forum-replies.png`**: name, chip, meta and body rows within 0.25 dp; the design's last body line
  ("assets.") is 1 dp lower than a uniform 20 dp pitch gives (cannot be matched with one line height).
* **No design exists** for the Forums tab, the discussion's page, the composer or the sheets: they should be reviewed by
  eye on a device and their sizes retuned in `lib/features/forum/forum_styles.dart` (`ForumDesign`). The one picture of
  the page is `test/golden/goldens/forum_thread.png` (from the sample content).

## Left

* The reply composer sends text only (a reply can carry a file on the website; the app shows one but does not attach).
* Following and Polls are not paged until the portal gains the filters (request 1).
* Tablet layout: the tab and the page are one column at any width.
