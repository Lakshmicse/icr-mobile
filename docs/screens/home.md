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
- `FeedRepository` (abstract) → `ApiFeedRepository({required ApiClient api, required String? viewerId})` on the forum, and `DemoFeedRepository()` holding the design's sample content. Models in `feed_models.dart`, the controller in `feed_controller.dart`, the cards in `widgets/` (`post_card.dart`, `poll_view.dart`, `reply_thread.dart`, `sponsored_card.dart`, `home_header.dart`, `composer_and_filters.dart`, `feed_avatar.dart`).
- Goldens: `test/golden/screens_golden_test.dart`, "home (demo content)" at 390 × 1996 dp (`Size(780, 3992)` at 2x) → `build/screens/home_demo.png`, matched against `test/golden/goldens/home_demo.png`. The screen drawn from the live API is `build/screens/home_live.png` (written by `test/live/feed_live_test.dart`).
- Tests: `test/feed_test.dart` (the mapping, the controller, the replies' rules), `test/feed_screen_test.dart` (every control, on the real screen over the real repository, with the forum faked by `test/helpers/feed_fixtures.dart` and the browser, share sheet and clipboard channels listened to), `test/live/feed_live_test.dart` (the local API: `flutter test test/live/feed_live_test.dart`). `test/helpers/offline_feed.dart` swaps a source's network pictures for bundled ones, because a widget test has no network to fetch photos from.

## Design frame

390 × 1996 dp: the header 56 tall over the list; the composer 39.5 tall at 16 from each edge; chips 28 tall at 5 apart; cards on a 16 dp gutter, an avatar of 40 dp, names in Work Sans 12, everything else in IBM Plex Sans (`AppText`). The export is 780 px wide, so every figure below is px / 2.

## Endpoints

| Call | Used for |
|---|---|
| `GET /forum/threads?sort=latest&limit=20&page=N` (+ `search`, `tag`) | All Feed, the search and the topic chips; `meta.hasNext` pages it |
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
| the topic beside the time ("#SUSTAINABILITY") | the discussion's sub-category (else category) name, upper-cased with punctuation dropped. The design's tint is green for Sustainability and Site Audit, blue for Real Estate Tech and #POLL: live, green for the sustainability families (`SUSTAINABILITY_ESG`, `HEALTH_SAFETY_ENVIRONMENT`, `LANDSCAPE`, `CORPORATE_WELLNESS`), blue for the rest and for polls |
| "Reply to Priya Nambiar..." | the box continues **the newest reply by someone other than the reader**, and a reply sent from it is posted under that reply (`parentId`). Tapping Reply on a reply addresses that person instead. With nobody else in the thread the box answers the discussion's author at the top level. After a reply is sent the whole thread opens, so it is there to see |
| "+8 replies in this thread" | the replies of the first reply's thread that the preview (that reply and its first answer) leaves out; when that thread has none, every reply still out of sight, so the pill is always there to open the rest. It opens the whole discussion |
| the line under a reply's name ("42m ago • Brookfield Properties") | the time, then the organisation of the author's headline (the part after "at", "@" or "·"; a headline with none is shown whole) |
| the first post's comments open | the live feed opens the first post's comments by itself, once, on the first All Feed load (when it has replies and is not a poll); a person closes them like any other |
| "SPONSORED PARTNER / The Future of FM Operations / Learn More" | the app's own placement carrying the design's copy; **there is no feed of placements to read**, so the band is a constant in `ApiFeedRepository.sponsored` (button to `/vendors`). Swap it for a real placement when one exists |
| the title's line break after "HVAC" | the title wraps by width ("...HVAC efficiency: Best / practices?"): the break is typed into the design's export and cannot come from a title |
| "Follow" on the first two posts only | `showFollow` is true for every author who is not the reader and not followed; the live data has the reader follow Marcus and Elena, so only Sarah and David wear it |
| the repost glyph | the forum has no repost, so it says so in a snackbar ("Reposting isn't available in the app yet.") |
| a reply's three dots | the design draws them without a menu; they open "Copy link", "Open on the ICR website" and, on the reader's own reply, "Delete reply" (after a confirmation) |
| the search box ("Search jobs, courses, partners...") | filters the feed (the forum's `search`: title, body and tags); there is no site-wide search endpoint |
| the minutes, hours and days on the cards | relative to now: the seed writes them relative to when it ran, so run it again to bring "2h ago" back |

## Order, chips and the live feed

- All Feed is the forum's `latest` order (pinned first, then by last activity). The seed pins the four design discussions so they lead (the portal's own "Welcome" thread is pinned too and would otherwise be first).
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
| Like | reacts at once; again takes it back; a refusal puts it back with the API's sentence | W "Like reacts at once, again takes it back, and a refusal puts it back with the forum's sentence"; L "a like is the API's: kept across a fresh read, counted, and taken back"; L "a refusal rolls the like back and says why" |
| speech bubble, "N comments" | opens and closes the replies (read once) | W "the speech bubble and the comment count open and close the replies"; L "the first post's comments open by themselves..." |
| repost glyph | explains, asks the forum nothing | W "the repost glyph says it is not in the app yet, and Share hands the discussion to the share sheet" |
| share glyph | the share sheet gets the title and the discussion's link | the same W |
| bookmark | saves, unsaves; a refusal leaves it | W "the bookmark saves and unsaves, and a refusal leaves it as it was"; L "a bookmark is kept, listed among the reader's saves, and taken back" |
| Follow | follows, the link goes away for that author's cards; a refusal keeps it | W "Follow follows the author and goes away..."; L "Follow is kept: the author joins the reader's following and the link goes away, until it is undone" |
| the three dots on a post | Copy link (clipboard, "Link copied"), Open on the ICR website | W "the three dots copy the discussion's link or open it on the website"; L "the links open pages the API knows" |
| a poll option | votes or moves the vote, the bars and the tick follow; the same option asks nothing; a refusal keeps the vote; a closed poll takes none | W "it shows its bars, the reader's vote and what it knows of its end; an option moves the vote", "a closed poll takes no vote and says Closed"; L "a poll vote moves, the counts follow, and it is put back where it was" |
| View Discussion | opens the poll's comments | W "View Discussion opens the poll's comments" |
| the reply box and its send arrow | posts under the newest reply (or the one picked), escaped; keeps the text on a refusal; an empty box sends nothing; the whole thread opens | W "the box continues the newest reply...", "Reply on a reply addresses that person and sends under that reply", "a reply is plain text...", "a refused reply keeps what was typed and says why"; L "a reply is sent under the newest reply, shown, liked by the reader, and taken back"; L "a refused reply says why..." |
| Like on a reply | likes at once, takes back, refusal restores the count | W "a reply is liked and unliked, and a refusal puts the count back"; L the reply test above (also the refusal on one's own reply) |
| Reply on a reply | addresses that person | W "Reply on a reply addresses that person..." |
| the three dots on a reply | Copy link / Open (with `#reply-<id>`); Delete on the reader's own, after a confirmation, and not by accident | W "a reply's three dots copy its link or open it on the website, and offer Delete on the reader's own only", "the reader can take back their own reply after confirming, and not by accident"; L the reply test (the delete) |
| "+N replies in this thread" | opens the rest of the discussion | W '"+8 replies in this thread" opens the rest of the discussion'; test/feed_test.dart "the replies of a thread" (the count's rule) |
| pull to refresh | reads the list, the bell and the discussions again; open threads keep their replies meanwhile | W "pulling down reads the forum, the bell and the discussions again"; L "pulling down reads what the server holds now" |
| load more | reads page 2 at the end; "You're all caught up" | W "scrolling to the end reads the next page, and the end says you're all caught up" (the local forum has fewer than 20 discussions, so there is no second page to read live) |
| the placement's button and i | opens `/vendors`; the i explains | W "the sponsored card opens its page, and its i says what it is"; "the sponsored card sits after the second post" |
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
