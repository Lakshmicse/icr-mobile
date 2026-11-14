import { defineManual, flow } from '../kit.mjs';

const settle = async (m, ms = 1500) => {
  await m.pause(ms);
  await m.idle();
};

export default defineManual('12-membership', 'Membership, credits and referrals', [
  flow(
    'plans',
    'Plans and what they include',
    { who: 'Every member', as: 'member', intro: 'Everyone starts on the free plan. A paid plan raises the limits: more applications, more mentoring, courses and papers opened for you.' },
    async (m) => {
      await m.tab('home');
      await m.tap('home-avatar');
      await m.tap('workspace-account');
      await m.wait('workspace-account-0');
      await m.shot('menu', 'Open your profile menu and select **Account**. **Membership** shows the plans, **My membership** your receipts, and **What my plans include** your current limits.', { ring: 'workspace-account-0' });
      await m.tap('workspace-account-0');
      await m.wait({ text: 'Current plan' });
      await settle(m);
      await m.shot('plans', '**Membership** shows your plan first, then the others with their yearly price and what each adds.');
      await m.scrollTo({ text: 'Pro' }, { align: 0.15 });
      await m.shot('pro', 'To move up, select the button under the plan you want. Payment is made inside the app through PayU, and the plan starts at once.');
      await m.home();
      await m.open('/membership/benefits');
      await m.wait({ text: 'See plans' });
      await m.shot('benefits', '**What my plans include** lists every limit you have today and the plan it comes from.');
      await m.home();
    },
  ),

  flow(
    'refer',
    'Refer a colleague and earn credits',
    { who: 'Every member', as: 'member' },
    async (m) => {
      await m.open('/refer');
      await m.wait({ text: 'Share invitation' });
      await m.shot('refer', '**Refer a friend**, under **Account** in your profile menu, gives you a code and a link. **Share invitation** sends it; the screen shows what each of you gets and how many people have joined.', { ring: { text: 'Share invitation' } });
      await m.home();
      await m.open('/refer/credits');
      await m.wait({ text: 'ICR credits' });
      await settle(m);
      await m.shot('credits', '**Credits & redemptions** shows the ICR credits you earned, how you earned them, and what you spent them on. Credits open Assess your knowledge levels and mock exams.');
      await m.home();
    },
  ),
]);
