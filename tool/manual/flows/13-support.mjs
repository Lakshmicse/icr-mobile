import { defineManual, flow } from '../kit.mjs';

const settle = async (m, ms = 1500) => {
  await m.pause(ms);
  await m.idle();
};

export default defineManual('13-support', 'Help and support', [
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
]);
