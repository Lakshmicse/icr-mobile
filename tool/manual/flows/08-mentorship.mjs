import { defineManual, flow } from '../kit.mjs';

export default defineManual('08-mentorship', 'Mentorship', [
  flow(
    'find',
    'Find a mentor',
    { who: 'Every member', as: 'member', intro: 'Mentors on ICR are senior people in facility management and corporate real estate whom ICR has reviewed and approved.' },
    async (m) => {
      await m.tab('mentorship');
      await m.swipe(600);
      await m.idle();
      await m.shot('tab', 'Open the **Mentorship** tab. Browse by area or by the company a mentor works at, or select **View More** for the whole directory.');
      await m.open('/mentorship/mentors');
      await m.wait({ text: 'Find Mentors' });
      await m.shot('directory', '**Find Mentors** lists every mentor. Search by name, company or skill, choose an area, or select **Filters**. **Sort** changes the order.', { ring: { text: 'Filters' } });
      await m.tap({ text: 'Filters' });
      await m.pause(900);
      await m.idle();
      await m.shot('filters', 'Filters keep the mentors with the years of experience you want, and those with a free slot. Select **Show mentors**.');
      await m.back();
      await m.home();
    },
  ),

  flow(
    'profile',
    'Read a mentor’s profile',
    { who: 'Every member', as: 'member' },
    async (m) => {
      await m.open('/mentorship/mentors');
      await m.wait({ text: 'Find Mentors' });
      await m.enter({ type: 'TextField', i: 0 }, 'Srikanth', { keep: true });
      await m.action('search');
      await m.pause(1500);
      await m.idle();
      await m.tap({ contains: 'Srikanth', i: 0 });
      await m.wait({ text: 'Book Free Trial' });
      await m.shot('profile', 'Select a mentor to open their profile: rating, experience, the next free slot, and what they are known for. **Send Message** writes to them.', { ring: { text: 'Send Message' } });
      await m.tap({ text: 'Offerings' });
      await m.pause(1200);
      await m.idle();
      await m.shot('offerings', '**Offerings** lists what the mentor offers: one-to-one sessions, resources to download, longer plans and programmes, each with its price.');
      await m.tap({ text: 'Recommendations' });
      await m.pause(1200);
      await m.idle();
      await m.shot('reviews', '**Recommendations** shows what earlier mentees wrote.');
      await m.home();
    },
  ),

  flow(
    'request',
    'Ask for a session',
    { who: 'Every member', as: 'member', intro: 'You ask; the mentor accepts and sets the time. A free session costs nothing. A paid one is paid for after the mentor accepts.' },
    async (m) => {
      // An earlier run's request to the same mentor is withdrawn first.
      const me = m.sql(`select id from "User" where email = '${m.person('member').email}'`);
      m.sql(`delete from "MentorServicePurchase" where "buyerId" = '${me}' and id not like 'dsgn-%' and "requestTopic" like '%retrofit programme%'`);
      await m.open('/mentorship/mentors');
      await m.wait({ text: 'Find Mentors' });
      await m.enter({ type: 'TextField', i: 0 }, 'Srikanth', { keep: true });
      await m.action('search');
      await m.pause(1500);
      await m.idle();
      await m.tap({ contains: 'Srikanth', i: 0 });
      await m.wait({ text: 'Book Free Trial' });
      await m.tap({ text: 'Book Free Trial' }, { ensure: false });
      await m.wait({ text: 'Send request' });
      await m.enter({ type: 'TextField', i: 0 }, 'I am moving from running one campus to a 12-site retrofit programme and want help planning the first 90 days.');
      await m.enter({ type: 'TextField', i: 1 }, 'Weekday evenings after 7 pm, IST');
      await m.shot('form', 'On the mentor’s profile, select the booking button. Say what you want to discuss, choose a video call or meeting in person, and say when suits you.', { ring: { text: 'Send request' } });
      await m.tap({ text: 'Send request' }, { ensure: false });
      await m.pause(2500);
      await m.idle();
      await m.shot('sent', 'Select **Send request**. The mentor is told, and you hear back in your notifications when they accept or suggest another time.');
      await m.home();
    },
  ),

  flow(
    'my-mentoring',
    'My mentoring',
    { who: 'Every member', as: 'member', intro: 'My mentoring is the one place for everything you have with your mentors: requests, sessions, goals and what you bought.' },
    async (m) => {
      await m.tab('home');
      await m.tap('home-avatar');
      await m.tap('workspace-mentorship');
      await m.wait('workspace-mentorship-0');
      await m.shot('menu', 'Open your profile menu, select **Mentorship**, then **My sessions**.', { ring: 'workspace-mentorship-0' });
      await m.back();
      await m.open('/mentorship/my');
      await m.wait({ text: 'At a glance' });
      await m.shot('overview', 'The first tab is the overview: your mentors, sessions held, goals reached and your next session. **Needs you** lists what is waiting for your answer.');
      await m.tap({ contains: 'Requests' });
      await m.pause(1200);
      await m.idle();
      await m.shot('requests', '**Requests** shows each session you asked for and where it stands: waiting for the mentor, accepted, or waiting for your payment or your answer to a new time.');
      await m.tap({ text: 'Calendar' });
      await m.pause(1200);
      await m.idle();
      await m.shot('calendar', '**Calendar** shows your sessions by day. Dots mark the days with something on; select a day to see it.');
      await m.tap({ text: 'Purchases' });
      await m.pause(1200);
      await m.idle();
      await m.shot('purchases', '**Purchases** lists the sessions and resources you bought, with the receipt for each.');
      await m.home();
    },
  ),

  flow(
    'pairing',
    'Work with your mentor',
    { who: 'Every member', as: 'member', intro: 'Once a mentor has taken you on, the two of you share a page: sessions, goals, tasks and notes.' },
    async (m) => {
      await m.open('/mentorship/my');
      await m.wait({ text: 'At a glance' });
      await m.scrollTo({ text: 'Open' }, { align: 0.6 });
      await m.shot('open', 'In **My mentoring**, under **My mentors**, select **Open**. **Message** writes to your mentor.', { ring: { text: 'Open' } });
      await m.tap({ text: 'Open' });
      await m.pause(1800);
      await m.idle();
      await m.shot('page', 'The page shows what is waiting on your mentor, then your sessions. A session has **Join** when it is time, **Move** to ask for another time, and **Cancel**. **Ask for a time** proposes a new session.');
      await m.swipe(-560);
      await m.shot('goals', 'Below are your plan with this mentor and your goals. **Add goal** sets a new one; mark a goal **Achieved**, update its **Progress**, or drop it.');
      await m.home();
    },
  ),

  flow(
    'groups',
    'Group sessions and programmes',
    { who: 'Every member', as: 'member' },
    async (m) => {
      await m.tab('home');
      await m.tap('home-search');
      await m.wait('search.field');
      await m.enter('search.field', 'Group sessions', { keep: true });
      await m.action('search');
      await m.pause(1500);
      await m.idle();
      await m.shot('search', '**Group sessions** are sessions a mentor holds for several people at once. To find them, search for **Group sessions** from Home and select the result under **In the app**.', { ring: { text: 'Group sessions', last: true } });
      await m.tap({ text: 'Group sessions', last: true });
      await m.pause(1800);
      await m.idle();
      await m.shot('all-groups', 'Each group session shows its mentor, its date and how many seats are left. Open one to read it and take a seat. **My seats** lists the ones you hold.');
      await m.home();
      await m.open('/mentorship/programmes');
      await m.wait({ text: 'Programmes' });
      await m.shot('programmes', '**Programmes** run for several weeks with a group and a set of mentors. Select one to read it and apply while applications are open.');
      await m.home();
    },
  ),
]);
