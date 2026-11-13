import { defineManual, flow } from '../kit.mjs';

const settle = async (m, ms = 1400) => {
  await m.pause(ms);
  await m.idle();
};

const desk = async (m, tab) => {
  await m.open('/mentorship/mentor');
  await m.wait({ text: 'Mentor desk' });
  await settle(m);
  if (tab) {
    await m.tap({ text: tab, i: 0 });
    await settle(m);
  }
};

export default defineManual('15-mentors', 'Mentors', [
  flow(
    'apply',
    'Apply to be a mentor',
    {
      who: 'Any member with experience to share',
      as: 'member',
      intro: 'Mentors are approved by ICR. You fill in a mentor profile, accept the code of conduct, and send it for review.',
    },
    async (m) => {
      await m.tab('home');
      await m.tap('home-avatar');
      await m.scrollTo('door-mentor', { at: [150, 600] });
      await m.shot('door', 'Open your profile menu and select **Become a mentor**.', { ring: 'door-mentor' });
      await m.tap('door-mentor');
      await m.wait({ text: 'Become a mentor' });
      await settle(m);
      await m.shot('application', 'The application has three parts: **Your profile**, the **Code of conduct**, and ICR’s review. The list under **Still needed to submit** shows what is missing.');
      await m.tap({ text: 'Your profile' });
      await settle(m);
      await m.shot('profile', 'In **Your profile**, say how you mentor, add your areas of expertise, and choose who you want to mentor. Save, tick the confirmation, and select **Submit for review**. ICR usually answers in a couple of days.');
      await m.home();
    },
  ),

  flow(
    'desk',
    'The mentor desk',
    { who: 'Mentors', as: 'mentor', intro: 'Once ICR approves you, your profile menu gains the mentor desk: everything you do as a mentor, in one place.' },
    async (m) => {
      await m.tab('home');
      await m.tap('home-avatar');
      await m.tap('workspace-mentorship');
      await m.wait('workspace-mentorship-0');
      await m.shot('menu', 'Open your profile menu and select **Mentorship**. **Mentor dashboard** opens the desk and **Mentor offerings** what you sell. The pill on the row shows whether members can find you.', { ring: { text: 'Mentor dashboard' } });
      await m.tap({ text: 'Mentor dashboard' });
      await m.wait({ text: 'Mentor desk' });
      await settle(m);
      await m.shot('overview', '**Overview** shows your mentees, your rating and what **needs you**: requests to answer. **Let members find me** takes you out of the directory when you need a pause.');
      await m.home();
    },
  ),

  flow(
    'requests',
    'Answer requests',
    { who: 'Mentors', as: 'mentor' },
    async (m) => {
      await desk(m, 'Requests');
      await m.shot('requests', '**Requests** lists who asked for mentoring, a session or a place on a programme, with what they wrote. **Accept** takes the person on; **Decline** says no, with a reason they will see.', { ring: { text: 'Accept', i: 0 } });
      await m.tap({ text: 'Accept', i: 0 });
      await settle(m, 1200);
      await m.shot('accept', 'When you accept, choose how often you will meet and add a note back, then select **Accept and start**. For a session request you also set the time, and the mentee confirms it.');
      await m.back();
      await m.home();
    },
  ),

  flow(
    'mentees',
    'Your mentees and sessions',
    { who: 'Mentors', as: 'mentor' },
    async (m) => {
      await desk(m, 'Mentees');
      await m.shot('mentees', '**Mentees** lists the people you mentor now and those who finished. **Open** shows a mentee’s page: sessions, goals, tasks and notes. **Message** writes to them.', { ring: { text: 'Open', i: 0 } });
      await m.tap({ text: 'Open', i: 0 });
      await settle(m, 1800);
      await m.shot('pairing', 'On a mentee’s page, a time they asked for waits under **Needs you**: **Approve** it, **Offer another time** or **Decline**. **Book a session** sets the next one, and each session has **Join**, **Move** and **Cancel**. Further down are their goals, tasks and your notes.');
      await m.home();
      await desk(m, 'Work');
      await m.shot('work', '**Work** is your queue of paid and free calls. **Join** opens the call when it is time, **Offer another time** asks the mentee to move it, and **Cancel** calls it off.');
      await m.home();
      await desk(m, 'Calendar');
      await m.shot('calendar', '**Calendar** shows every session and call by day.');
      await m.home();
    },
  ),

  flow(
    'offerings',
    'What you offer, and when',
    { who: 'Mentors', as: 'mentor' },
    async (m) => {
      await desk(m, 'Offerings');
      await m.shot('offerings', '**Offerings** is your storefront: one-to-one sessions, resources, plans, programmes and group sessions. **Edit**, **Pause** or **Delete** a listing, or add a new one.', { ring: { text: 'Add a 1:1 session' } });
      await m.tap({ text: 'Add a 1:1 session' });
      await settle(m, 1200);
      await m.shot('new', 'A new session needs a title, what the mentee gets, its length and its price. A free session costs the mentee nothing.');
      await m.back();
      await m.home();
      await desk(m, 'Hours');
      await m.shot('hours', '**Hours** are the windows members can book you in. Add a window to a day, remove one with the **x**, and select **Save hours**.');
      await m.home();
    },
  ),

  flow(
    'earnings',
    'Earnings, reviews and settings',
    { who: 'Mentors', as: 'mentor' },
    async (m) => {
      await desk(m, 'Earnings');
      await m.shot('earnings', '**Earnings** shows what you earned after ICR’s fee: what is waiting to be paid out and what has been paid, with the bank reference.');
      await m.tap({ text: 'Reviews', i: 0 });
      await settle(m);
      await m.shot('reviews', '**Reviews** shows what mentees said about you and about what you sell.');
      await m.tap({ text: 'Settings', i: 0 });
      await settle(m);
      await m.shot('settings', '**Settings** holds how you meet, how often, your timezone, your standing meeting link and a note on your availability.');
      await m.home();
    },
  ),
]);
