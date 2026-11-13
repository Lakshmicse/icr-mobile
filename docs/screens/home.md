# Home

The Home feed (`docs/designs/home.png`): the header (photo, search, bell), "Post a requirement or insight...", the chips, then the community's discussions: four kinds of card (a text post with tags, a post with one photo, a poll, a post with a grid of photos), the first one with its comments open, and ICR's placement after the second.

## Screens and wiring

- `HomeScreen({required FeedAuthor viewer, required VoidCallback onAccount})` — `lib/features/feed/home_screen.dart`. Reads a `FeedController` from Provider, which `lib/app.dart` builds above the shell:

  ```dart
  ChangeNotifierProvider<FeedController>(
    create: (c) => FeedController(
      AppConfig.demoFeed ? DemoFeedRepository() : ApiFeedRepository(api: c.read<ApiClient>(), viewerId: user?.id),
    )..start(),
  )
  ```

  `onAccount` opens the profile menu (`AppShell.openDrawer`); the constructors did not change.
- `FeedRepository` (abstract) → `ApiFeedRepository({required ApiClient api, required String? viewerId})` on the forum, and `DemoFeedRepository()` holding the design's sample content. Models in `feed_models.dart`, the controller in `feed_controller.dart`, the cards in `widgets/` (`post_card.dart`, `poll_view.dart`, `reply_thread.dart`, `home_header.dart`, `composer_and_filters.dart`, `feed_avatar.dart`).
- Goldens: `test/golden/screens_golden_test.dart`, "home (demo content)" at 390 × 1996 dp (`Size(780, 3992)` at 2x) → `build/screens/home_demo.png`, matched against `test/golden/goldens/home_demo.png`. The screen drawn from the live API is `build/screens/home_live.png` (written by `test/live/feed_live_test.dart`).
- Tests: `test/feed_test.dart` (the mapping, the controller, the replies' rules), `test/feed_screen_test.dart` (every control, on the real screen over the real repository, with the forum faked by `test/helpers/feed_fixtures.dart` and the browser, share sheet and clipboard channels listened to), `test/live/feed_live_test.dart` (the local API: `flutter test test/live/feed_live_test.dart`). `test/helpers/offline_feed.dart` swaps a source's network pictures for bundled ones, because a widget test has no network to fetch photos from.

## Design frame

390 × 1996 dp: the header 56 tall over the list; the composer 39.5 tall at 16 from each edge; chips 28 tall at 5 apart; cards on a 16 dp gutter, an avatar of 40 dp, names in Work Sans 12, everything else in IBM Plex Sans (`AppText`). The export is 780 px wide, so every figure below is px / 2.

## Endpoints

| Call | Used for |
|---|---|
| `GET /forum/threads?sort=newest&limit=20&page=N` (+ `search`, `tag`) | All Feed, the search and the topic chips; `meta.hasNext` pages it. The page is laid out newest first, pinned or not (owner's call, 30 Oct 2026) |
| `GET /forum/threads?sort=top` / `sort=unanswered` | Trending / Unanswered (the forum's own sorts: top is pinned first, then by score; unanswered is open questions with no reply) |
| `GET /forum/threads?limit=100` | Following and Polls: the forum has no such filter, so the latest 100 are read and the matching ones kept |
| `GET /members/me/following` (100 a page, up to five pages) | who the reader follows: a card shows "Follow" only for the others |
| `GET /notifications/unread-count` | the bell's dot |
| `GET /forum/threads/:slug` | the discussion's whole text, its attachment and the images in its body, for each card that comes on screen (see below) |
| `GET /forum/threads/:slug/replies?limit=100` | the replies of an open thread, as the forum nests them |
| `POST` / `DELETE /forum/threads/:id/vote` | Like (`{value: 1, reaction: 'LIKE'}`) and taking it back |
| `POST` / `DELETE /forum/threads/:id/save` | the bookmark |
| `POST /members/:id/follow` | Follow |
| `POST /forum/threads/:id/poll/vote` | choosing or moving a poll vote (`{optionId}`) |
| `POST /forum/threads/:id/replies` | a reply (`bodyHtml` made from the typed text, escaped; `parentId` when under a reply) |
| `DELETE /forum/replies/:id` | taking back one's own reply |
| `POST` / `DELETE /forum/replies/:id/vote` | liking a reply |

Pages the screen hands to the browser (`SITE_URL`): `/notifications` (the bell, until the shell wires `ForumCallbacks.onBell`), `/vendors` (the placement's button). **Since the forum flows (26 Oct 2026) a discussion opens in the app** (`docs/screens/forums.md`): the title or words, "View Discussion", a ⋮ menu's "Open discussion" and "Open the whole discussion" open its page (`/community/<slug>` is only a link that is copied); "Post a requirement or insight..." is the in-app composer; the ⋮ menus also Report. The reply thread is drawn as the Home design (`ReplyLook.home`).

## What the API cannot give, and what is shown instead

| Design | Shown live |
|---|---|
| "14 shares" | **how often the discussion was opened** (`viewCount`), in the same place and type: "52 comments · 4,210 views". The API counts no shares, and its list does not carry how many members saved a discussion (the card DTO has only the reader's own `saved`), so "N saves" was not possible; views is a number the API has. Hidden when it is zero |
| "842 votes • 2 days left" | "192 votes • Open", "• Closed" once the discussion is locked. A poll has no closing date in the API. The count is the number of voters, and a person votes once, so it is capped by the accounts there are (192 locally) in the design's split |
| "184 reactions" | the forum's `likes`; the three glyphs are the three kinds with the most reactions, most first (Like, Insightful, Celebrate here). Reaching 184 needs 184 accounts: the seed reaches it with the accounts there are (184 on three of the posts), and the numbers are the accounts' |
| "52 comments" | `replyCount` |
| the post's photos | the list has no attachments or images, so each card **reads its discussion's own page** when it comes on screen (the first six before the feed is drawn, so the first screen does not grow photo by photo; `GET /forum/threads/:slug`, once per card, again on a pull to refresh). The forum keeps one attachment per discussion: when it is a picture it is the first photo, and a file name that reads as words ("BIM Feasibility Lab.jpg") is the caption of a lone photo. The forum's own editor cannot put images in a body, but a body that has `<img>` tags is read: the first two pictures are drawn and the rest counted as "+3 photos" |
| the whole text | the list's `excerpt` is cut at 220 characters, so the text comes from the same page read (at most six lines are drawn) |
| the topic beside the time ("Sustainability") | the discussion's sub-category (else category) name, in the forum's own words — a label, never a hashtag (a typed `#tag` sits under the words). The design's tint is green for Sustainability and Site Audit, blue for Real Estate Tech and #POLL: live, green for the sustainability families (`SUSTAINABILITY_ESG`, `HEALTH_SAFETY_ENVIRONMENT`, `LANDSCAPE`, `CORPORATE_WELLNESS`), blue for the rest and for polls |
| "Reply to Priya Nambiar..." | the box continues **the newest reply by someone other than the reader**, and a reply sent from it is posted under that reply (`parentId`). Tapping Reply on a reply addresses that person instead. With nobody else in the thread the box answers the discussion's author at the top level. After a reply is sent the whole thread opens, so it is there to see |
| "+8 replies in this thread" | the replies of the first reply's thread that the preview (that reply and its first answer) leaves out; when that thread has none, every reply still out of sight, so the pill is always there to open the rest. It opens the whole discussion |
| the line under a reply's name ("42m ago • Brookfield Properties") | the time, then the organisation of the author's headline (the part after "at", "@" or "·"; a headline with none is shown whole) |
| the first post's comments open | the live feed opens the first post's comments by itself, once, on the first All Feed load (when it has replies and is not a poll); a person closes them like any other |
| "SPONSORED PARTNER / The Future of FM Operations / Learn More" | **not drawn** (owner, 6 Nov 2026: "Remove this"): the placement, its model and its background picture were removed; cards follow each other 8 dp apart |
| the title's line break after "HVAC" | the title wraps by width ("...HVAC efficiency: Best / practices?"): the break is typed into the design's export and cannot come from a title |
| "Follow" on the first two posts only | `showFollow` is true for every author who is not the reader and not followed; the live data has the reader follow Marcus and Elena, so only Sarah and David wear it |
| the repost glyph | the forum has no repost, so it says so in a snackbar ("Reposting isn't available in the app yet.") |
| a reply's three dots | the design draws them without a menu; they open "Copy link", "Open on the ICR website" and, on the reader's own reply, "Delete reply" (after a confirmation) |
| the search box ("Search jobs, courses, partners...") | filters the feed (the forum's `search`: title, body and tags); there is no site-wide search endpoint |
| the minutes, hours and days on the cards | relative to now: the seed writes them relative to when it ran, so run it again to bring "2h ago" back |

## Order, chips and the live feed

- All Feed is **the newest discussions first, pinned or not** (owner's call, 30 Oct 2026): the app asks the forum for `sort=newest` and lays the page out by `createdAt`, so a member's fresh post leads the pinned ones; until then it was the forum's `latest` order (pinned first, then by last activity). The seed pins the four design discussions so they lead (the portal's own "Welcome" thread is pinned too and would otherwise be first).
- Trending, Unanswered, Following and Polls are described above; a topic chip (#HVAC, #ESG) is the forum's `tag` filter, which is case-sensitive, so the seed stores the tags as the design writes them. Tapping a lit chip again goes back to All Feed.
- Paging: the list reads 20 at a time and the next page when the reader is within 600 dp of the end; "You're all caught up" ends it.

## Controls and the tests that prove them

`W` is a widget test (`test/feed_screen_test.dart` unless noted) on the real screen over the real repository, with the forum faked; `L` is a live test (`test/live/feed_live_test.dart`, API up and seeded). The live tests write as Pooja Professional and undo what they do; Bharat is only read. **No live test replies to a designed post** (see "What a live run leaves behind" below): the reply tests use the seed's sandbox discussion.

| Control | What it does | Proved by |
|---|---|---|
| header photo | `onAccount`, the profile menu | W "the header photo opens the profile menu"; W "inside the shell the header photo opens the real profile menu over the feed; Back closes it" |
| search box (submit, the x) | asks the forum for what was typed; the x brings the feed back; "No discussions match..." | W "the search asks the forum for what was typed, and the x brings the feed back"; L "each chip reads what it names, and the search and the topic chip narrow the live forum" |
| bell | opens `/notifications`; the dot is the unread count, absent at zero | W "the bell opens the notifications page..." and "without unread notifications the bell has no dot"; L "the bell's count is the member's unread notifications" |
| "Post a requirement or insight..." | opens `/community/new` | W "\"Post a requirement or insight...\" opens the website composer" |
| All Feed, Trending, Following, Unanswered, Polls | ask the forum for what they name; empty states say what they wait for | W "each chip asks the forum for what it names", "Following with nobody followed says so", "an empty chip says what it is waiting for"; L "each chip reads what it names..." |
| #HVAC, #ESG | the forum's tag filter; again goes back | W "a topic chip loads that tag, and tapping it again goes back to All Feed"; L the same live test |
| Like | reacts at once; again takes it back; a refusal puts it back with the API's sentence. **The reader's own post** is refused before anything is sent, with the website's sentence ("You cannot react to your own post.") — the API would refuse too, in other words | W "Like reacts at once, again takes it back, and a refusal puts it back with the forum's sentence"; L "a like is the API's: kept across a fresh read, counted, and taken back"; L "a refusal rolls the like back and says why" |
| speech bubble, "N comments" | opens and closes the replies (read once) | W "the speech bubble and the comment count open and close the replies"; L "the first post's comments open by themselves..." |
| repost glyph | explains, asks the forum nothing | W "the repost glyph says it is not in the app yet, and Share hands the discussion to the share sheet" |
| share glyph | the share sheet gets the title and the discussion's link | the same W |
| bookmark | saves, unsaves, and says so ("Saved" / "Removed from saved discussions", the website's toast); a refusal leaves it | W "the bookmark saves and unsaves, and a refusal leaves it as it was"; L "a bookmark is kept, listed among the reader's saves, and taken back" |
| Follow | follows, the link goes away for that author's cards; a refusal keeps it | W "Follow follows the author and goes away..."; L "Follow is kept: the author joins the reader's following and the link goes away, until it is undone" |
| the three dots on a post | Copy link (clipboard, "Link copied"), Open on the ICR website | W "the three dots copy the discussion's link or open it on the website"; L "the links open pages the API knows" |
| "N votes" under a poll | opens **Votes**: who voted and for what (`GET /forum/threads/:id/poll/voters`, the website's voters dialog), open to the poll's voters, its author and staff and to everyone once the discussion is closed; the API's sentence otherwise ("Vote in the poll to see who voted.") | W "the votes count opens who voted…" |
| a poll option | votes or moves the vote, the bars and the tick follow; the same option asks nothing; a refusal keeps the vote; a closed poll takes none. The shares show only once the reader has voted, to the poll's author, or once it is closed (before that the options are plain, as the website's); the author sees the results and cannot vote | W "it shows its bars, the reader's vote and what it knows of its end; an option moves the vote", "a closed poll takes no vote and says Closed"; L "a poll vote moves, the counts follow, and it is put back where it was" |
| View Discussion | opens the poll's comments | W "View Discussion opens the poll's comments" |
| the reply box and its send arrow | posts under the newest reply (or the one picked), escaped; keeps the text on a refusal; an empty box sends nothing; the whole thread opens | W "the box continues the newest reply...", "Reply on a reply addresses that person and sends under that reply", "a reply is plain text...", "a refused reply keeps what was typed and says why"; L "a reply is sent under the newest reply, shown, liked by the reader, and taken back"; L "a refused reply says why..." |
| Like on a reply | likes at once, takes back, refusal restores the count | W "a reply is liked and unliked, and a refusal puts the count back"; L the reply test above (also the refusal on one's own reply) |
| Reply on a reply | addresses that person | W "Reply on a reply addresses that person..." |
| the three dots on a reply | Copy link / Open (with `#reply-<id>`); Delete on the reader's own, after a confirmation, and not by accident | W "a reply's three dots copy its link or open it on the website, and offer Delete on the reader's own only", "the reader can take back their own reply after confirming, and not by accident"; L the reply test (the delete) |
| "+N replies in this thread" | opens the rest of the discussion | W '"+8 replies in this thread" opens the rest of the discussion'; test/feed_test.dart "the replies of a thread" (the count's rule) |
| pull to refresh | reads the list, the bell and the discussions again; open threads keep their replies meanwhile | W "pulling down reads the forum, the bell and the discussions again"; L "pulling down reads what the server holds now" |
| load more | reads page 2 at the end; "You're all caught up" | W "scrolling to the end reads the next page, and the end says you're all caught up" (the local forum has fewer than 20 discussions, so there is no second page to read live) |
| no placement between posts | nothing is drawn after the second post | W "no sponsored placement sits between the posts (owner, 6 Nov 2026)" |
| a failed read | "Couldn't load the feed" + Try again | W "a failed read says so, and Try again reads again" |

Content from the API, drawn as the design words it: L "the feed is the API's, with the designed posts first and in the design's order, worded as the design words them" (titles, authors, headlines, topics and tints, tags, reaction kinds, the Follow links, the poll's split and the reader's vote, the photos and caption, the whole text); L "the top of the feed reads as the design, with the local database's content" (the screen, drawn).

## Seed

`tool/seed/home.ts` (see `tool/seed/README.md`) gives the local database the design's posts so the live screen reads like the PNG: Sarah Jenkins, David Chen, Marcus Reed and Elena Rostova as invented, active, public members with the design's avatars and headlines (`User.designation`); their four discussions, pinned, newest first, with the design's bodies, tags and topics (three inactive sub-categories), 184 / 184 / 96 / 184 reactions in a 104 / 50 / 30 mix, 52 / 52 / 12 / 52 replies (Sarah's: Arvind Swamy's reply and its nested answer, eight more in that thread, the newest Priya Nambiar's), the poll with 192 votes in the design's split (Bharat has voted Archibus; Pooja has voted too, because the API cannot take a vote away and the live test moves hers and puts it back), David's photo and Elena's five; three discussions of Bharat's own; and a **sandbox** discussion for the live tests (below). Timestamps are relative to the run.

### What a live run leaves behind

The feed is ordered pinned first, then by `lastActivityAt`, and the forum sets `lastActivityAt` to now on **every reply** (only a reply, a new thread and a moderator's approval write it; likes, saves, follows, votes and views do not) and does not put it back when the reply is deleted. A live test that replied to Sarah's thread therefore dropped it below the other three designed posts, and "the top of the feed reads as the design" then found a third "Follow" link. So:

* The four designed posts carry a `lastActivityAt` up to 60 days ahead, in the design's order (Sarah, David, Marcus, Elena), so the portal's own pinned Welcome thread is below them and a member's reply (which sets it to now) cannot move one out of place.
* **No live test writes a reply to a designed post.** The reply tests ("a reply is sent under the newest reply, shown, liked by the reader, and taken back", "a refused reply says why...") use the **sandbox** discussion, `handing-bim-data-over-to-the-fm-team-without-rekeying-it-home-design`: by Marcus Reed (whom Bharat follows, so it has no "Follow" link), unpinned, three replies (Arvind Swamy's with two likes and Priya Nambiar's answer under it, then Priya's newest), no reactions and no views (so it adds no "reactions" or "views" text beside the designed cards). It is seeded as the newest unpinned thread, so a reply to it leaves the order as the seed made it. The tests derive their numbers from it (3 replies, 2 likes) and check after the reply and again after the delete that the first four slugs are still Sarah, David, Marcus, Elena.
* The designed posts are only read, liked and unliked, saved and unsaved, followed and unfollowed (Sarah's author), and voted on and put back (Marcus's poll). None of those writes `lastActivityAt`, and each is undone.
* Left behind by a run, all harmless: Pooja follows the sandbox thread (the forum subscribes a replier), its `lastActivityAt` is a little later than the seed's, and the people it replied to may have a reply notification. `home.ts` again resets all of it. The whole live suite was run twice in a row (`flutter test --tags live --concurrency=1`): both times green, and `GET /forum/threads?limit=5&sort=latest` still reads Sarah, David, Marcus, Elena, Welcome.

## Demo content

`DemoFeedRepository` holds the design's four posts and the placement word for word, with "14 shares", "842 votes • 2 days left" and "Reply to Priya Nambiar..." as the design has them. The first post's comments start open (`initiallyOpen`) with "+8 replies in this thread" set by hand.

## Measurements (dp)

Header 56; composer 39.5 at 5.5 below; chips 28; a card's avatar 40 (5.2 or 1.2 below the header's top), name line, headline, time line, title, body 18 pitch, tags 32 tall, photos 358 × 208 (one) or two 175 × 176, the summary row 20.5, a divider, the action bar 37. The design spaces each kind of card a little differently, so `_Rhythm` in `post_card.dart` keeps the measured tops of each kind's lines (dp from the header's top):

| Card | name | headline | time | title | title to body | body to photos | photos to summary |
|---|---|---|---|---|---|---|---|
| text with tags (Sarah) | 1 | 16 | 31 | 48 | 6.5 | | |
| one photo (David) | 2 | 15.5 | 29.5 | 52 | 6 | 5 | 15.5 |
| poll (Marcus) | 2 | 13.5 | 26.5 | 46 | | | |
| photo grid (Elena) | 2.5 | 16 | 26.5 | 42.5 | 5 | 0.5 | 11 |

(The two cards after the placement start 2 and 2.5 dp lower than the text card's rule, `topExtra`.)

## How it was checked

`python tool/design/devcompare.py build/screens/home_live.png docs/designs/home.png out.png` lays the screen drawn from the live API beside the design; the check that means something pairs the ink rows (darker than 235) of the design's text column with the render by nearest start row.

- Before the per-kind rhythm: 63 design bands, **48 within 2 dp**, mean 1.68 dp, the title and body of David's card 3.5 to 5 dp high and Elena's card 2.5 to 6 dp low.
- Now (the demo golden and the live render give the same numbers): **60 of 63 within 2 dp**, mean 0.7 dp. The text lines of all four cards, the thread, the photos and the placement are on the design's rows to within 1 dp (David's card: name, headline, time, title and the three body lines on the same px as the design's; avatars within 1 dp).
- The three that remain: the poll's name row merges with its icons in the band test (13 dp is the merge, the text itself is on the design's row), and the design's own bottom edge cuts the last card.

## Deviations that remain

- The first card's title breaks after "Best", not after "HVAC" (above).
- David's card: its reactions row and action glyphs sit 2.5 dp higher than the design's, because the design lets the glyphs sit lower in the bar while the placement below starts on the same row; Sarah's tags text is 1 dp low.
- The photos are the design's export resolution (350 px for a 175 dp tile, 80 px avatars): a 2.77-density screen shows them soft, as the demo does.
- The reply tiles' three dots now open a menu; the design draws them as a bare glyph.
- The thread's reply box can be answered by a person who has not read the reply it names (it is the newest, behind "+N replies"): the hint says whose it is, and the whole thread opens after sending.

## Tester batch, 7–8 Nov 2026 (owner's WhatsApp reports)

* **A poll shows a radio before each option while the reader may vote** (`poll-radio:<option>`), the check on their own vote as before; a closed poll or one already voted shows the shares alone. Owner: "enable radio button for user to click if it's a poll".
* **A member may like their own post.** The app's refusal ("You cannot react to your own post.") is gone from Home and Forums; the API allows the reaction (`forum-votes.service.ts`). Owner: "remove this restriction".
* The sponsored placement was removed on 6 Nov (above).

## 9 Nov 2026 (bug sheet)

* **#5 Follow state agrees with the profile.** `FollowEvents` (`features/forum/follow_events.dart`) carries every follow and unfollow made anywhere — the member profile's button (`ApiAccountRepository`), a card's Follow (`ApiForumRepository.setFollowing`) — to the forum repository's copy of who the member follows, and that copy is read again after 45 s (`followingTtl`). Before, the feed kept a list read once per session, so a profile's "Following" and the feed's "Follow" disagreed.
* **#19 A repost carries the original's picture.** The forum attaches only a file its poster uploaded, so `copyRepostImage` (`repost.dart`) reads the original's first picture and stores it again as the reposter's own `forum-attachment`, which both "Repost" and "Repost with your thoughts" (the composer's `initialAttachment`) then carry. A copy that fails still reposts, with the quote and the link. Links in a post were already tappable (`LinkSpans`).
* **#3 The Tags field's "@" list** shows from the first letter after the "@" (it waited for two).
* **#1, #4, #9, #25, #27** — the feed is newest-first since 30 Oct; a tapped "@" tag opens the person since 3 Nov; #9 is the website's (it shows a picture as a file name); #25 (9 views, 2 readers) is the API counting a view per open — the portal branch `fix/forum-views-per-reader` ("a discussion's views are its readers") fixes it and awaits a PR and a deploy; #27 (poll radio buttons) shipped on 8 Nov.

## 9 Nov 2026: one launch logo

The owner: "the app loads two logos — first the eagle alone, then ICR with the logo; remove the first." The eagle was Android 12+'s own splash, which draws the launcher icon until the app's first frame; the second is the app's `_Splash` (`lib/app.dart`, the ICR wordmark with the logo). `android/app/src/main/res/values-v31/styles.xml` (and `values-night-v31/`) now give `LaunchTheme` a white `windowSplashScreenBackground` and a transparent `windowSplashScreenAnimatedIcon` (`drawable/splash_icon_empty.xml`), so the system splash is a blank white screen and the ICR splash is the only logo. Phones below Android 12 never drew the icon; their `launch_background` was already plain white.

## 11 Nov 2026: a repost shows the original

The owner: "reposted post sharing the link rather than images, and poll not coming". The forum has no repost record, so a repost is a discussion whose words open with the quote `repost.dart` writes ("↻ Reposted from <author>", the title in quotes, the link). `RepostQuote.of(body)` (`feed/repost_quote.dart`) reads those lines back, and `PostCard` then draws the original inside the repost (`_QuotedPost`, key `quoted:<slug>`): a hairline box with the original's author, title, words, photos and poll — read through `quotedLoader` (`FeedController.quoted` → `FeedRepository.quoted(slug)` = `GET /forum/threads/:slug` whole; `ForumsController.quoted` → `repository.thread`), kept per slug and cleared by pull-to-refresh. A tap opens the original; a vote on its poll is cast on the original (`voteQuoted`) and shows in every repost of it. The reposter's own words stay above the box; the raw link line is not drawn; a repost's own photo is not drawn when the box is (the original carries it). The 9 Nov copy of the original's picture onto the repost is gone — the box shows the original's. Tests: `test/repost_quote_test.dart`, `feed_screen_test` "a repost draws the original inside it…".

## 11 Nov 2026: videos on a card

A post's videos (`FeedPost.videos`, read from the body's `<video>` tags with its photos) are tiles like the photos: one alone fills the card's width, more sit two across with "+N more"; a video tile is dark with a play glyph and opens `VideoPlayerScreen`. A quoted original shows its media the same way. See `docs/screens/forums.md` → 11 Nov 2026.

## 13 Nov 2026: copy refined to the client's standard

The client marked up the user manual with the wording wanted on a dozen screens and asked for the rest of the app to read the same way: Title Case for what a person taps or reads as a label, a short sentence with a full stop for everything else, plain international English, no dash inside a sentence. Wording only: no layout, colour or behaviour changed. Semantics-only labels (what a screen reader says for an icon) were left as they were. By the lead's ruling the title of an empty, locked or error state is a heading (Title Case, no full stop) with a sentence under it, and the retry button reads **Try Again** everywhere.

| Where | Old | New |
|---|---|---|
| A reply's menu | Open discussion · Copy link · Delete reply | Open Discussion · Copy Link · Delete Reply |
| Snackbars | Link copied · Saved · Removed from saved discussions | Link copied. · Saved. · Removed from saved discussions. |
| After a report | Thanks. A moderator will take a look. | Thank you. A moderator will review it. |
| Delete a reply | Delete your reply? / It is taken out of the discussion for everyone. | Delete Your Reply? / It will be removed from the discussion for everyone. |
| The feed did not load | Couldn't load the feed / Try again | Unable to Load the Feed / Try Again |
| Nothing found | No discussions match "x" · No discussions tagged #x yet | No Discussions Match "x" · No Discussions Tagged #x Yet |
| The end of the list | You're all caught up | No more discussions. |
| Empty: Following | Nothing from people you follow yet | No Posts from People You Follow Yet |
| Empty: Unanswered | Every question has an answer / New questions without replies will show up here. | No Unanswered Questions / New questions without replies will appear here. |
| Empty: Polls | No polls right now / Polls members start in the community will show up here. | No Polls Yet / Polls started by members will appear here. |
| Empty: all | No discussions yet / Start one with the + at the top. | No Discussions Yet / Select + at the top to start one. |

Kept: the chips (**All Feed, Trending Discussions, Following, Unanswered, Polls**, the client's 12 Nov words), "Start a post" and "Search" (prompts inside a pill, written as hints), "…more", "View Discussion". The comments sheet built the same day (`widgets/comments_sheet.dart`, `comment_widgets.dart`: "No comments yet", "Be the first to comment.", "Most relevant", "Most recent") was still being written and is not part of this pass.


## 13 Nov 2026: comments open in a sheet, drawn as LinkedIn's

The owner, with LinkedIn's comment sheet beside it: "Redesign the Comment like this not the way its showing."

- The speech bubble (and its count) no longer opens a thread inside the card. It opens **`CommentsSheet`**
  (`widgets/comments_sheet.dart`, `showCommentsSheet`) over the feed: a grabber, the order ("Most relevant" /
  "Most recent", `CommentSort`), every comment with its answers, and the box pinned at the foot ("Add a comment...").
- A comment is a **`CommentTile`** (`widgets/comment_widgets.dart`): no bubble. Photo, then the name with the age
  ("3d"), **Follow** and the three dots at the row's end; the headline on one line; the words; the like and reply
  glyphs with their counts, and a small blue thumb at the end once it has likes.
- Answers sit **one step in** off a thin line under the comment's photo (`CommentReplies`), however deep the forum
  nests them, each opening on the name of the person it answers in blue (`commentRows`). There is no
  "+N replies in this thread" pill: the sheet shows the whole discussion.
- The box adds a comment **to the post**; Reply on a comment aims it at that person ("Replying to …", with an x).
  A refusal shows above the box. Messages and menus raised from the sheet show over it (`_over(at)` in
  `home_screen.dart`); opening a profile or the discussion's page closes the sheet first.
- **Follow** beside a comment comes from `FollowBook`: shown only once the forum has said the reader does not
  follow that author, never on one's own comment, gone the moment it is tapped.
- `FeedController.readReplies(post)` reads the comments when the sheet opens; the first post's are still read ahead.
- Gone: `widgets/reply_thread.dart`, and from `reply_widgets.dart` the bubble tile, the branch line and the pill.
  `ReplyBox` and `ReplyAction` remain. Tests: `feed_screen_test.dart` ("the replies"), golden `feed_comments.png`.


## 13 Nov 2026: the Like button is the reaction picked

The owner: "The like button long press shows the options same to same should show the button selected by the user not the blue colored icon." Once the reader has reacted, the Like button draws that reaction's round badge (`ReactionBadge`, the same widget the long-press picker shows) with the count in `reactionInk(kind)`; unreacted it is the grey outlined thumb. The discussion page's Like does the same. Tests: `forum_home_test.dart` and `forum_thread_test.dart` (the long-press picks).
