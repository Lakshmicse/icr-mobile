import { defineManual, flow } from '../kit.mjs';

const SARAH = 'design-home-thread-sarah';
const MARCUS = 'design-home-thread-marcus';

export default defineManual('05-home-and-forums', 'Home feed and forums', [
  flow(
    'read',
    'Read the feed',
    { who: 'Every member', as: 'member', intro: 'Home is where members ask each other questions and share what worked. A discussion shows who wrote it, its topic, and the replies under it.' },
    async (m) => {
      await m.tab('home');
      await m.shot('chips', 'The chips above the feed choose what you see: **All Feed**, **Trending**, the people you are **Following**, **Unanswered** questions, **Polls**, and topics.', { ring: { text: 'Trending' } });
      await m.shot('card', 'Select a discussion’s title to open it with all its replies. Select **…more** to read the whole post in place.', { ring: `open:${SARAH}` });
      await m.tap(`open:${SARAH}`);
      await m.pause(1200);
      await m.idle();
      await m.shot('page', 'The discussion’s own page shows the full post, then every reply, with replies to replies indented under them.');
      await m.home();
    },
  ),

  flow(
    'react',
    'Like, reply, save and follow',
    { who: 'Every member', as: 'member' },
    async (m) => {
      // An earlier run's like and reply are taken back, so the counts and the thread read the same every time.
      const me = m.sql(`select id from "User" where email = '${m.person('member').email}'`);
      m.sql(`delete from "ForumThreadVote" where "threadId" = '${SARAH}' and "userId" = '${me}'`);
      m.sql(`update "ForumReply" set "deletedAt" = now() where "threadId" = '${SARAH}' and "authorId" = '${me}' and "deletedAt" is null and "bodyHtml" like '%sub-metering per floor%'`);
      await m.tab('learning');
      await m.tab('home');
      await m.scrollTo(`like:${SARAH}`, { step: 200, align: 0.55 });
      await m.shot('actions', 'Under each post: **like**, **reply**, **repost** to your own followers, and **share** a link. The bookmark at the top right of a post saves it to **Saved Items** in your profile menu.', { ring: `like:${SARAH}` });
      await m.tap(`open:${SARAH}`);
      await m.wait('thread-like');
      await m.shot('page', 'Open the discussion. The same actions are under the post, with **Notify me** to hear about new replies. **Follow** next to a name puts that person’s posts in your **Following** feed.', { ring: 'thread-like' });
      await m.tap('thread-menu');
      await m.wait('menu-report');
      await m.shot('more', 'The three dots beside the author open more: copy the link, or report a post that breaks the rules to ICR’s moderators.');
      await m.back();
      await m.tap('thread-like');
      await m.enter('reply-input', 'We saw the same on a 2009 building: start with sub-metering per floor before touching the chillers.');
      await m.shot('reply', 'To answer, type in **Write a reply** at the bottom and select the send arrow.', { ring: 'reply-send' });
      await m.tap('reply-send');
      await m.pause(1500);
      await m.idle();
      await m.back();
      await m.home();
    },
  ),

  flow(
    'poll',
    'Vote in a poll',
    { who: 'Every member', as: 'member' },
    async (m) => {
      await m.tab('home');
      await m.tap({ text: 'Polls' });
      await m.pause(1200);
      await m.idle();
      await m.wait({ keyPrefix: 'poll-option:' });
      await m.shot('poll', 'Select **Polls** to see only polls. Select an answer to vote. The bars show how members voted, and a tick marks your own answer.', { ring: { keyPrefix: 'poll-option:', i: 0 } });
      await m.cmd({ do: 'swipe', dx: 500, dy: 0, at: [150, 140] });
      await m.tap({ text: 'All Feed' });
      await m.idle();
    },
  ),

  flow(
    'post',
    'Start a discussion',
    { who: 'Every member', as: 'member', intro: 'Ask a question or share something. A clear title and a category bring answers.' },
    async (m) => {
      // Earlier runs of this flow posted the same discussion: take those out of the feed.
      m.sql(`update "ForumThread" set "deletedAt" = now() where title like 'Chiller plant on night setback%' and "deletedAt" is null`);
      await m.tab('learning');
      await m.tab('home');
      await m.shot('plus', 'On **Home**, select the **+** button at the top.', { ring: 'home-compose' });
      await m.tap('home-compose');
      await m.wait('composer-title');
      await m.shot('kind', 'Choose **Discussion** to ask or share, or **Poll** to let people vote. Then select **Category**.', { ring: 'composer-topic' });
      await m.tap('composer-topic');
      await m.wait('topic-search');
      await m.enter('topic-search', 'HVAC');
      await m.pause(800);
      await m.shot('category', 'Search for the category that fits, or browse the list, and select it.');
      await m.tap({ keyPrefix: 'topic-hit:', i: 0 });
      await m.wait('composer-title');
      await m.enter('composer-title', 'Chiller plant on night setback: how low do you let the chilled water go?');
      await m.enter('composer-body', 'We run a 900 TR plant for a 1.2 million sq ft office park in Pune. Night load is under 15%. We are trying a 9°C chilled water setpoint after 10 pm and want to hear what others run, and what it did to humidity by morning.');
      await m.shot('write', 'Give it a specific **Title** and enough **Details** for someone to help. Further down you can add tags and attach a file.', { ring: 'composer-bar-send' });
      await m.tap('composer-bar-send');
      await m.gone('composer-title', 20000);
      await m.pause(1200);
      await m.idle();
      await m.shot('posted', 'Select **Post**. Your discussion opens, and members who follow the category see it in their feed.');
      await m.home();
    },
  ),

  flow(
    'forums',
    'Browse the forums by topic',
    { who: 'Every member', as: 'member', intro: 'The Forums screen is the whole community by topic, with search and sorting. Open it from a topic on any post, or from a link to the community.' },
    async (m) => {
      await m.open('/community');
      await m.wait('forum-topics');
      await m.shot('forums', 'The chips under the search box choose a view, as on Home. The **Topics** row keeps one topic.', { ring: 'forum-topics' });
      await m.tap({ keyPrefix: 'topic:', i: 1 });
      await m.pause(1200);
      await m.idle();
      await m.shot('topic', 'Select a topic to see only its discussions; its sub-topics appear underneath to narrow it further.');
      await m.home();
    },
  ),
]);
