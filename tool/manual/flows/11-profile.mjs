import { defineManual, flow } from '../kit.mjs';

const settle = async (m, ms = 1500) => {
  await m.pause(ms);
  await m.idle();
};

export default defineManual('11-profile', 'Your profile and network', [
  flow(
    'profile',
    'Your profile',
    { who: 'Every member', as: 'member', intro: 'Your profile is what recruiters, mentors and other members see about you. It is yours alone and stays the same whichever company you act for.' },
    async (m) => {
      await m.tab('home');
      await m.tap('home-avatar');
      await m.wait('drawer-profile');
      await m.tap('drawer-profile');
      await m.wait({ text: 'Add section' });
      await settle(m);
      await m.shot('profile', 'Open your profile menu and select your name. Each part of your profile has a pencil to edit it. The camera on the banner changes your photo and cover.', { ring: { text: 'Add section' } });
      await m.tap({ text: 'Add section' });
      await settle(m, 1000);
      await m.shot('sections', '**Add section** adds what is not there yet: experience, education, skills, languages, credentials and more.');
      await m.back();
      await m.scrollTo({ text: 'Experience' }, { align: 0.3 });
      await m.shot('experience', 'Under **Experience**, the **+** adds a role and the pencil edits one. A role can be linked to a company’s page on ICR.');
      await m.home();
    },
  ),

  flow(
    'public',
    'How others see you',
    { who: 'Every member', as: 'member' },
    async (m) => {
      await m.open('/profile');
      await m.wait({ text: 'View public profile' });
      await m.tap({ text: 'View public profile' });
      await settle(m, 1800);
      await m.shot('public', '**View public profile** shows your profile as other members see it. On anyone else’s profile, **Message** starts a conversation and **Follow** adds their posts to your feed.');
      await m.home();
    },
  ),

  flow(
    'network',
    'Your network',
    { who: 'Every member', as: 'member' },
    async (m) => {
      await m.open('/network');
      await m.wait({ text: 'Your network' });
      await settle(m);
      await m.shot('network', '**Network** shows the people you follow and who follows you, with their recent posts. Reach it from the **Connections** line in your profile menu.');
      await m.tap({ text: 'People to follow' });
      await settle(m);
      await m.shot('suggestions', '**People to follow** suggests members in your field. Select **Follow** beside a name.');
      await m.home();
    },
  ),
]);
