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
`test/forum_thread_test.dart` (52 W), `test/forums_tab_test.dart` (28 W), `test/forum_composer_test.dart` (32: 5 U, 27 W), `test/forum_rich_text_test.dart` (27: 26 U, 1 W), `test/golden/composer_golden_test.dart` (4 goldens),
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

The website's "Create a post" form (`ThreadComposer`), on a phone, in the website's words and order (owner's order, 28 Oct
2026: "the same form should be added here"). One Post in the title bar (Save on an edit) is the only posting control:
the website's Cancel and "Post to the community" under the form are the bar's X and Post. Fields carry their words as
floating labels (no TOPIC / YOUR POST headers); the website's helper lines sit under them in grey; a missing field is
drawn with a red border, never a red line of words, and ONE message under the form names what is first missing after
Post. A post and a poll are one form in one type (Roboto 16 for fields and the editor, 14 for "Details" and "Options",
12 for helpers).

| Control | Does | Proved by |
|---|---|---|
| Discussion / Poll | the two kinds of a new post as two tiles **side by side** (icon, name, "Ask or share" / "Let people vote"; the owner asked for this layout back on 28 Oct 2026); an edit keeps its own kind (an older post may be a question) | W; U |
| Category * / Sub-category (optional) | both always on the form; a list of the taxonomy (`GET /categories/tree?kind=SERVICE&depth=2`, sent as `topicCategory` / `topicSubcategory`) that **searches the whole tree like the website's Category box**: empty it lists the categories, typing matches every word anywhere in a node's path (category › sub-category), the sub-category hits grouped under their category's name, and picking one fills both boxes ("No matching categories" when nothing matches); the sub-category is greyed until there is a category **with sub-categories** (the website enables it as soon as there is a category and then lists nothing); the page the composer was opened from presets its category | W (3) |
| Title / Poll question | 8 to 160 characters, wraps up to three lines; helper "Specific titles get answered. "Pricing question" does not." / "One clear question. Members pick one option."; an edit of a question reads "Your question" | W (4); U (5) |
| poll options | "Options  2 of 4", rows with a ring, "Option 1".., add and remove, 80 characters each, duplicates (any case) refused, hint "Members pick one; results show once they have voted."; sent as `pollOptions`; fixed once posted (an edit never sends them) | W; U; L |
| Details (optional on a poll) | **the website's rich-text editor** (below); required except on a poll; 20,000 characters, counted as the website does (the words, not newlines or list markers) | W; U |
| tags | up to 5, 32 characters, lower case, spaces to dashes, "#" dropped (the forum's own `normaliseTags`); a comma adds; chips with an x; a tag typed and not added is sent; "Add up to 5" and the website's helper | W (2); U |
| Attach a file | a photo or PDF from the phone (`file_picker`; a test hands in a picker), uploaded as `forum-attachment` **with its real media type**, shown as a tile, removable before sending; "Replace attachment" when there is one; an edit can only replace one (the forum cannot clear it: `docs/backend-requests/forums.md` 3) | W (3); L |
| Post / Save | validated first, then sent as the website's DTO; `bodyHtml` is the editor's HTML (below); an edit sends **no body** unless the details changed, and **no topic** unless it changed (a retired sub-topic would refuse a title edit), and no file unless replaced | W; U; L "an edit of the title alone keeps its body and topic" |
| a quote or code from the website, on edit | the editor shows them as paragraphs; "This post has a quote or code from the website that this editor cannot show..." appears once the words change (bold, italic, headings, lists and links are held, so they carry no warning) | W (2) |
| leaving | asks before discarding typed work, not on a blank form | W (2) |
| moderation notice | shown to a reader whose posts are reviewed first | W |
| categories failed | message with Try again | W |

**The editor** (`widgets/rich_editor.dart`, `rich_text_controller.dart`, `rich_document.dart`): a frame with the website's
toolbar (Bold, Italic, Heading, Bulleted list, Numbered list, Link), the writing area and "0 / 20,000". It is a plain
Flutter `TextField` over a controller that keeps a mark per character (bold, italic, heading, a link), so it adds no
package, needs no rich-text plugin and draws as written (bold is bold, a heading is larger, a link is blue). A list
item is a line that starts "• " or "1. " (real text, as the website's input rules treat "- " and "1. "): Enter carries the
list on, Enter on an empty item ends it, Backspace after a marker takes it whole, "- " at the start of a line becomes a
bullet, numbers count on from 1 in each run. Bold and italic chosen with nothing selected apply to what is typed next; a
heading is a whole line; the Link button needs selected words (or the caret on a link), asks for an address in a sheet and
adds `https://` to one without a scheme (only http, https and mailto are attached). Words that replace others (a
keyboard's correction) keep the look of the ones they replace. The HTML sent is `<p>`, `<h3>`, `<ul>`/`<ol>` with `<li>`,
`<strong>`, `<em>` and `<a href>`: every character escaped, empty lines dropped, one paragraph per line; the API's
sanitiser (`sanitizeRichText`) keeps all of it (`L` "formatted details reach the forum"), and the discussion page draws it
(`ForumRichText`: W). An edit loads the stored HTML into the editor; if the details are unchanged nothing is sent for them.

### The Home feed card (`HomeScreen`, `PostCard`, `ReplyThread`)

Open thread in place under the first card with the speech bubble: the first reply and its first answer, "+N replies in
this thread" (opens the rest in place), then "Open the whole discussion" to the page; Like and Reply on each reply (Reply
addresses that person and sends under it), the three dots (open at that reply, copy link, report, delete one's own), the
reply box (Enter sends). New this slice: the title or words open the discussion, "View Discussion" on a poll opens it,
"N reactions" lists who reacted, holding Like picks a reaction, the three dots report and open (no website page is opened
any more), "Post a requirement or insight..." is the composer. Proved by `test/feed_screen_test.dart` (69 W, the existing
tests updated where the behaviour moved) and `test/forum_home_test.dart` (7 W). A bug fixed on the way:
`FeedController.toggleReplyLike` rebuilt every other reply without its role, parent, accepted and pending flags.

## Tagging people ("@") and tags (3 Nov 2026)

- **Typing "@"** in the new-discussion details, in a comment on a Home card and in the discussion page's reply bar lists people
  (`lib/features/forum/mentions/`): the caret right after an "@" (not inside an address) and the letters since, up to two
  words ("@ra sh"); a second space in a row, the caret moving off, Escape or losing focus closes it. Up to 8 people
  (photo, name, headline), asked for after a 250 ms pause through `GET /members/mentionable?search=&limit=8`; a loading row, "No
  one found", "Type a name to tag someone." under two letters. A pick puts `@First Last ` in the words and records the person.
- **What is sent:** the words stay `@First Last` while writing; on send each recorded person whose `@First Last` is still in the
  words becomes `<a href="/members/{id}">@First Last</a>` (`mentionedHtml`; the composer's rich text does the same through
  `RichDoc.withMentions`); everything else is escaped as before. A mention deleted from the words is not sent. Editing a reply
  or a post keeps the people already tagged in it (their anchors are read back).
- **What shows as a link:** the discussion page (its words, through `ForumRichText`: a root-relative `/members/{id}` link is the
  one link without a scheme the parser keeps, made absolute and opened in the app's member profile), each comment (page and
  Home), and a Home card's words once its discussion was read (the cards read it as they come on screen). **Forums-tab cards
  are plain**: the list sends a 220-character plain excerpt, not the HTML, so there is no id to link; they link once the
  discussion is opened.
- **Tags:** a tag on a Home card opens the Forums tab already filtered by it (`openForumsTag`, `ForumsController.showTag`: the
  plain list for that tag, search dropped), as a tag on a Forums-tab card filters that tab. The tab's controller is held above the
  tabs (`InheritedProvider<ForumsController>`) so Home can reach it.
- **Repost** sends `repostOfId` (the original's id) with the quote it always filed, from "Repost" and "Repost with your thoughts".
- **Notifications** for a reaction, a repost or a tag all open this discussion (`forum.thread`), see `docs/NOTIFICATION_TARGETS.md`.

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
| the website editor's formatting | shown as written, and the composer's editor holds it (bold, italic, a level-3 heading, lists, links); a quote, code or other heading level from the website is read as a paragraph (h1, h2 and h4 as the level-3 heading), with a note when its words are changed |
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
  thread (David's) sits 1 to 2.5 dp off the design as before this work (the sponsored card was removed on 6 Nov 2026).
* **Section look vs `forum-replies.png`**: name, chip, meta and body rows within 0.25 dp; the design's last body line
  ("assets.") is 1 dp lower than a uniform 20 dp pitch gives (cannot be matched with one line height).
* **No design exists** for the Forums tab, the discussion's page, the composer or the sheets: they should be reviewed by
  eye on a device and their sizes retuned in `lib/features/forum/forum_styles.dart` (`ForumDesign`). The one picture of
  the page is `test/golden/goldens/forum_thread.png` (from the sample content).

## Left

* The reply composer sends text only (a reply can carry a file on the website; the app shows one but does not attach).
* Following and Polls are not paged until the portal gains the filters (request 1).
* Tablet layout: the tab and the page are one column at any width.

**6 Nov 2026 (owner's phone).** A reply's role pill (the section look, `ReplyTile._section`) overflowed the row by 16 px with a long role ("Workplace experience and employee wellbeing" — a headline split at "at"): the name may now take up to three fifths of the row and the pill two, each ellipsised past that; short ones take only their own width.

## 11 Nov 2026: several photos and videos on a discussion, played in the app

The owner: "not able to add multiple images and videos, and playing functionalities". The forum keeps its one file attachment (`uploadId`), so photos and videos go **inline in the body**: the composer's **Add photos or videos** (key `composer-media`, `pickForumMedia` — several at once; a photo up to 10 MB, a video up to 50 MB, `forum_file_picker.dart`) uploads each as a `forum-attachment` and holds it in `ComposerController.media` (`ForumMediaItem`: a 72 dp thumbnail with an ×, key `media-remove-<i>`); `bodyHtml` ends with `<p><img src="/uploads/<id>" alt=""></p>` / `<p><video src="/uploads/<id>" controls></video></p>` per item, and an edit reads the body's media back so they stay (or can be taken off). The server side (portal branch `feat/forum-inline-media`): the sanitiser and the website's `RichText` allow `<img>`/`<video>` whose `src` is an own `/uploads/` path, and forum uploads take mp4/webm/mov. **Until that is deployed, production strips the tags and a post shows no inline media.** Reading: `ForumJson.videoSources` beside `imageSources`; `FeedPost.videos` / `ForumThread.videos`; the feed card draws a video as a dark tile with a play glyph (`post-video:<url>`) and the thread page one per video (`thread-video:<i>`); a tap opens `VideoPlayerScreen` (`features/media/`, `video_player` + `chewie`: play, seek, full screen; a video that will not play says so). Tests: `forum_composer_test` "photos and videos are picked several at once…", "…over the forum's cap is refused…"; `feed_test` "a discussion's videos are read from its body…".

## 13 Nov 2026: copy refined to the client's standard

The client marked up the user manual with the wording wanted on a dozen screens and asked for the rest of the app to read the same way: Title Case for what a person taps or reads as a label, a short sentence with a full stop for everything else, plain international English, no dash inside a sentence. Wording only: no layout, colour or behaviour changed. Semantics-only labels (what a screen reader says for an icon) were left as they were. By the lead's ruling the title of an empty, locked or error state is a heading (Title Case, no full stop) with a sentence under it, and the retry button reads **Try Again** everywhere.

**The list (`forums_screen.dart`, `forum_models.dart`, `widgets/forum_filters_sheet.dart`)**

| Where | Old | New |
|---|---|---|
| A card's menu, snackbars, the report thanks | as on Home | as on Home (`home.md`) |
| The list did not load | Couldn't load the discussions · Couldn't load the topics | Unable to Load Discussions (with **Try Again**) · Unable to load topics. (a line beside its Try Again link) |
| Buttons, chips and headings to Title Case (11) | Clear filters · Clear all · All topics · Filter discussions · Show results · Most upvoted · Unanswered questions · Any type | Clear Filters · Clear All · All Topics · Filter Discussions · Show Results · Most Upvoted · Unanswered Questions · Any Type |
| The tag box's hint | A tag, like hvac | Enter a tag, e.g. hvac |
| The end of the list | You're all caught up | No more discussions. |
| Empty: a search | No discussions match "x" / Try different words, or start the discussion yourself. | No Discussions Match "x" / Try different words, or start a discussion. |
| Empty: a tag, filters | No discussions tagged #x yet · No discussions match these filters | No Discussions Tagged #x Yet · No Discussions Match These Filters |
| Empty: Following, Unanswered, Polls | as on Home | as on Home |
| Empty: Saved | Nothing saved yet / Bookmark a discussion and it will show up here. | No Saved Discussions Yet / Bookmark a discussion and it will appear here. |
| Empty: My Contributions | You haven't posted yet / Questions and discussions you start show up here, including any still awaiting approval. | No Posts Yet / Questions and discussions you start appear here, including those awaiting approval. |
| Empty: all | No discussions yet / Start one with "Start a discussion...". | No Discussions Yet / Select "Start a discussion..." to begin. |
| The first-posts note (list and composer) | Your first few posts are read by a moderator before they go public. Once a couple are approved, everything you write publishes straight away. | A moderator reviews your first few posts before they are published. After a few are approved, your posts are published immediately. |
| Reputation levels | Community leader · New member | Community Leader · New Member |
| Report reasons | Abuse or harassment · Off topic · Undisclosed self-promotion · Misleading or incorrect · Something else | Abuse or Harassment · Off Topic · Undisclosed Self-Promotion · Misleading or Incorrect · Something Else |

**The composer (`new_thread_screen.dart`, `composer_controller.dart`, `forum_flows.dart`, `repost.dart`)**

| Where | Old | New |
|---|---|---|
| Titles | New poll · New discussion | New Poll · New Discussion |
| Leaving | Discard your changes? / What you changed will not be saved. · Discard this draft? / What you wrote will be lost. | Discard Your Changes? / Your changes will not be saved. · Discard This Draft? / Your draft will be lost. |
| A failed save | It couldn't be saved | Unable to Save |
| Labels and buttons | Your question · Add photos or videos · Add more photos or videos · Replace attachment | Your Question · Add Photos or Videos · Add More Photos or Videos · Replace Attachment |
| A title's example | e.g. What actually moved the needle on your energy numbers? | e.g. Which measures reduced your energy use the most? |
| The rich-text note | …Changing its words turns them into plain paragraphs. | …Editing the text converts them to plain paragraphs. |
| Categories | Couldn't load the categories: … · No matching categories · Nothing matches that. | Unable to load categories: … · No matching categories. · No matches found. |
| The tag limit | That is the most a discussion can carry (5). | Tag limit reached (5). |
| Refusals | x is too big: a photo can be up to N MB. · Two options read the same: make each one different. · Add some details so people know what you mean. · Choose the topic this belongs to. | x is too large. A photo can be up to N MB. · Two options are the same. Make each option different. · Add details to explain your post. · Select a category. |
| After posting | Posted. A moderator will read it before it goes public. · Reposted. A moderator will read it before it goes public. | Posted. A moderator will review it before it is published. · Reposted. A moderator will review it before it is published. |
| The repost sheet | Repost with your thoughts · Instantly bring this post to your feed. | Repost with Your Thoughts · Share this post to your feed immediately. |

**A discussion (`thread_screen.dart`, `thread_controller.dart`, `widgets/thread_header.dart`, `reply_section.dart`, `forum_sheets.dart`, `mentions/`)**

| Where | Old | New |
|---|---|---|
| The menus | Copy link · Who viewed | Copy Link · Who Viewed |
| Deleting | Delete this discussion? / It is taken down for everyone, replies included. · Delete your reply? / It is taken out of the discussion for everyone. | Delete This Discussion? / It will be removed for everyone, including its replies. · Delete Your Reply? / It will be removed from the discussion for everyone. |
| Not found, not loaded | This discussion isn't here / It may have been taken down, or the link is wrong. · Couldn't load this discussion | Discussion Not Found / It may have been removed, or the link is incorrect. · Unable to Load This Discussion |
| Notices | Waiting for review · This discussion is not taking new replies, and its poll takes no votes. | Awaiting Review · This discussion does not accept new replies or poll votes. |
| The facts line, the actions | · Still unanswered · Notify me | · Unanswered · Notify Me |
| Replies | Accept answer · Accepted answer · Awaiting review · Couldn't load the replies · Replies will show up here. · Couldn't load more. Try again · Show more replies | Accept Answer · Accepted Answer · Awaiting Review · Unable to Load Replies · Replies will appear here. · Unable to load more. Try again. · View More |
| Refusals | This discussion is locked, so it is not taking new replies. · This discussion is closed, and so is its poll. · Write something before posting. · The reply cannot be emptied. Delete it instead. | This discussion is locked and does not accept new replies. · This discussion and its poll are closed. · Enter a reply before posting. · A reply cannot be empty. Delete it instead. |
| The report sheet | Report this reply · Report this discussion / A moderator will look at it. Choose what is wrong. / Anything else the moderator should know (optional) / Send report | Report This Reply · Report This Discussion / A moderator will review it. Select the reason. / Additional details for the moderator (Optional) / Send Report |
| Votes and viewers | Nobody has voted yet. · Who viewed · No members you can see have read this yet. · N other members read it with a private profile. · Couldn't load this | No votes yet. · Who Viewed · No members visible to you have viewed this yet. · N other members viewed it with a private profile. · Unable to Load |
| Tagging | Couldn't search people just now. · Couldn't search just now. · No one found | Unable to search people. Try again. · Unable to search. Try again. · No one found. |

Kept: **My Contributions**, **All Feed**, **Trending Discussions**, **Recent Activity**, **Last Activity:**, the composer's labels (Your Poll Question, Discussion Title, Additional Context (Optional), Answer Options, Add Option, Add Tags, Attach File) and **Start the Conversation** / "Be the first to share your thoughts or insights." (the client's 12 Nov words); the reactions sheet (its "All N" tabs and "Nobody has reacted yet.", drawn on 13 Nov to the client's reference); the repost's stored lines ("↻ Reposted from …", "Repost: …"), which are data the feed reads back.

**Network (`lib/features/network/`, which has no screen doc of its own)**

| Where | Old | New |
|---|---|---|
| Tabs, headings, buttons to Title Case (7) | People to follow · Your network · Who to follow · Find people · Follow back | People to Follow · Your Network · Who to Follow · Find People · Follow Back |
| More of a list | See all · Show more | View More |
| Unfollow | Their articles and discussions leave your feed. They aren't told. | Their articles and discussions will no longer appear in your feed. They will not be notified. |
| Not loaded | Couldn't load your network / Retry | Unable to Load Your Network / Try Again |
| The writer's card | Be worth following / Members who follow you hear when you publish something new. | Publish for Your Followers / Members who follow you are notified when you publish something new. |
| Empty: feed, following nobody | Follow someone to start your feed / When you follow a member, what they publish shows up here. / People worth following | Follow Members to Start Your Feed / When you follow a member, what they publish will appear here. / Who to Follow |
| Empty: feed | Nothing new yet | No New Posts Yet |
| Empty: suggestions | No suggestions right now / As you follow people, the people they follow show up here. | No Suggestions Yet / As you follow people, the people they follow will appear here. |
| Empty: following, followers | You don't follow anyone yet · No followers yet / Members who follow you show up here. | Not Following Anyone Yet · No Followers Yet / Members who follow you will appear here. |


## 13 Nov 2026: replies drawn as LinkedIn's comments

The discussion page's replies use the same `CommentTile` rows as the Home feed's comments sheet (see `home.md`,
same date): plain rows, answers one step in off a thin line and opening on the name they answer, Follow beside a
comment by someone the reader does not follow (`FollowBook`, made by `ThreadScreen`). Accept answer, the Accepted
answer and Awaiting review chips, a reply's file and the tint on the reply a link named are kept. The box reads
"Add a comment...". The Forums tab's speech bubble still opens this page at its replies.


## 13 Nov 2026: photos go as the forum's own list

The portal's `main` keeps a post's photos in `imageIds` (ten at most) and returns them as `images` on every card. The composer now sends its photos there (`ForumDraft.imageIds`, `ComposerController.photoIds`; an edit sends the list only when it changed) and no longer writes `<img>` into the body; videos are still written inline. Reading goes through `ForumJson.photoPaths`: the forum's list, a pictured attachment, then any picture in the body, once each. `forumMaxPhotos` caps the composer at ten.
