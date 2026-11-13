import { defineManual, flow } from '../kit.mjs';

export default defineManual('03-messages', 'Messages', [
  flow(
    'inbox',
    'Read your messages',
    { who: 'Everyone', as: 'member', intro: 'Every conversation you have on ICR is in one inbox: with members, mentors, recruiters, suppliers and companies.' },
    async (m) => {
      await m.tab('home');
      await m.shot('open', 'On **Home**, select the speech bubble at the top. A red dot means someone has written to you.', { ring: 'home-messages' });
      await m.tap('home-messages');
      await m.wait('compose');
      await m.shot(
        'list',
        'The inbox lists your conversations, the newest first. A blue number shows unread messages. The chips keep one kind: **Unread**, **Vendor RFQs**, **Mentorship** and more.',
        { ring: 'filter-unread' },
      );
      await m.cmd({ do: 'longPress', on: 'conversation-inbox-seed-conv-sarah' });
      await m.wait('menu-pin');
      await m.shot('pin', 'Press and hold a conversation to **pin** it to the top or **star** it.');
      await m.back();
      await m.home();
    },
  ),

  flow(
    'reply',
    'Reply, attach a file, share a record',
    { who: 'Everyone', as: 'member' },
    async (m) => {
      await m.tab('home');
      await m.tap('home-messages');
      await m.wait('conversation-inbox-seed-conv-sarah');
      await m.tap('conversation-inbox-seed-conv-sarah');
      await m.wait('composer');
      await m.shot('thread', 'Select a conversation to open it. The messages are in order, the newest at the bottom.');
      await m.enter('composer', 'Thursday at 4 pm works for me. I will send the site drawings before then.');
      await m.shot(
        'write',
        'Type your message at the bottom. The paper clip attaches a file from your phone, **RFQ** shares an ICR record such as a requirement or a job, and the face adds an emoji.',
        { ring: 'send' },
      );
      await m.tap('send');
      await m.pause(1500);
      await m.idle();
      await m.shot('sent', 'Select the send button. Your message appears at the bottom of the conversation.');
      await m.home();
    },
  ),

  flow(
    'new-message',
    'Start a new conversation',
    { who: 'Everyone', as: 'member' },
    async (m) => {
      await m.tab('home');
      await m.tap('home-messages');
      await m.wait('compose');
      await m.shot('compose', 'In the inbox, select the **New message** button at the top right.', { ring: 'compose' });
      await m.tap('compose');
      await m.wait('recipient-search');
      await m.enter('recipient-search', 'Pooja');
      await m.pause(1500);
      await m.idle();
      await m.shot('find', 'Type the name of a member or a supplier, then select them from the list. The conversation opens, ready for your first message.');
      await m.home();
    },
  ),
]);
