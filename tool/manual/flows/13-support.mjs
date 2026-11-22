import { defineManual, flow } from '../kit.mjs';

const settle = async (m, ms = 1500) => {
  await m.pause(ms);
  await m.idle();
};

export default defineManual('13-support', 'Help, support and about ICR', [
  flow(
    'request',
    'Ask ICR for help',
    { who: 'Everyone', as: 'member', intro: 'A support request reaches ICR’s team. You follow it and reply to it in the app.' },
    async (m) => {
      await m.open('/profile?tab=security');
      await m.scrollTo('settings.support');
      await m.shot('row', 'Open **Settings** and select **Help & support**.', { ring: 'settings.support' });
      await m.tap('settings.support');
      await m.wait({ text: 'New request', i: 0 });
      await settle(m);
      await m.shot('desk', '**Common questions** may already have your answer. Your own requests are listed below by where they stand. Select **New request**.', { ring: { text: 'New request', i: 0 } });
      await m.tap({ text: 'New request', i: 0 });
      await settle(m, 1200);
      await m.shot('form', 'Choose what the request is about, give it a subject, and describe what happened. You can attach a screenshot. Send it, and ICR’s team replies here and by email.');
      await m.home();
    },
  ),

  flow(
    'contact',
    'Contact ICR',
    { who: 'Everyone', as: 'member' },
    async (m) => {
      await m.open('/profile?tab=security');
      await m.scrollTo('settings.contact');
      await m.tap('settings.contact');
      await settle(m, 1500);
      await m.shot('contact', '**Contact us**, in **Settings**, writes to ICR’s team about anything that is not a problem with your account: a partnership, the press, a question before you buy. Your name and email are filled in for you.');
      await m.home();
    },
  ),

  flow(
    'about',
    'About ICR, the blog and the small print',
    { who: 'Everyone', as: 'member' },
    async (m) => {
      await m.open('/profile?tab=security');
      await m.scrollTo('settings.about');
      await m.tap('settings.about');
      await m.wait('about-page');
      await settle(m);
      await m.shot('about', '**About ICR**, in **Settings**, says what ICR is and opens each part of it.');
      await m.home();
      await m.open('/blogs');
      await settle(m, 1800);
      await m.shot('blogs', 'The **blog** carries articles from ICR and its members. Select one to read it. Saathi and search both find it under **Blogs**.');
      await m.home();
      await m.open('/profile?tab=security');
      await m.scrollTo('settings.terms');
      await m.tap('settings.terms');
      await m.wait('legal.body');
      await settle(m);
      await m.shot('terms', 'The **Terms of Service** and the **Privacy Policy** are in **Settings** too, and can be read in the app.');
      await m.home();
    },
  ),

  flow(
    'advertise',
    'Advertise and reviews',
    { who: 'Everyone', as: 'member' },
    async (m) => {
      await m.tab('home');
      await m.tap({ text: 'Discover', last: true });
      await m.wait({ text: 'Advertise' });
      await m.tap({ text: 'Advertise' }, { ensure: false });
      await settle(m, 1800);
      await m.shot('advertise', '**Advertise**, on the **Discover** sheet, explains the placements a company, an institute or a mentor can buy to be featured. Buying one is done on the website.');
      await m.home();
      await m.open('/reviews');
      await settle(m, 1800);
      await m.shot('reviews', '**Reviews** gathers the reviews you wrote and the ones written about your company or your mentoring.');
      await m.home();
    },
  ),
]);
