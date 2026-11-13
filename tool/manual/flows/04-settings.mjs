import { defineManual, flow } from '../kit.mjs';

const openSettings = async (m) => {
  await m.open('/profile?tab=security');
  await m.wait('settings.security');
};

export default defineManual('04-settings', 'Settings and your account', [
  flow(
    'settings',
    'Open Settings',
    { who: 'Everyone', as: 'member', intro: 'Settings holds what belongs to your account rather than to any one part of ICR.' },
    async (m) => {
      await m.tab('home');
      await m.tap('home-avatar');
      await m.scrollTo('account-settings', { at: [150, 600] });
      await m.tap('account-settings');
      await m.wait('settings.security');
      await m.shot('top', 'Open your profile menu and select **Settings**. The first group is your account: your profile, sign-in and security, your companies and saved items.');
      await m.scrollTo('settings.signOut');
      await m.shot('rest', 'Below are your preferences, your data, and help: **About ICR**, **Help & support**, **Contact us**, the **Terms of Service** and the **Privacy Policy**.');
      await m.home();
    },
  ),

  flow(
    'password',
    'Change your password',
    { who: 'Everyone', as: 'member' },
    async (m) => {
      await openSettings(m);
      await m.shot('row', 'In **Settings**, select **Sign-in & security**.', { ring: 'settings.security' });
      await m.tap('settings.security');
      await m.wait('security.changePassword');
      await m.shot('security', 'This screen shows the email you sign in with, your password and your contact details. Next to **Password**, select **Change**.', { ring: 'security.changePassword' });
      await m.tap('security.changePassword');
      await m.idle();
      await m.shot(
        'form',
        'ICR changes a password through a link sent to your email, so nobody holding your phone can change it. Select **Send reset link**, open the email and choose the new password. Use it the next time you sign in, here and on icr.org.in.',
      );
      await m.home();
    },
  ),

  flow(
    'mobile-number',
    'Add and confirm your mobile number',
    {
      who: 'Everyone',
      as: 'member',
      intro: 'ICR asks for a mobile number the first time you do something an employer, mentor or supplier may need to call you about, such as applying for a job. You can add it beforehand here.',
    },
    async (m) => {
      // An earlier run added the number: take it off so the screen reads "Not added" again.
      m.sql(`update "User" set phone = null, "phoneVerifiedAt" = null where email = '${m.person('member').email}'`);
      await m.cmd({ do: 'refreshUser' });
      await openSettings(m);
      await m.tap('settings.security');
      await m.wait('security.phone');
      await m.shot('row', 'In **Sign-in & security**, under **Contact info**, select **Add** next to **Mobile number**.', { ring: 'security.phone' });
      await m.tap('security.phone');
      await m.wait('phone.number');
      await m.enter('phone.number', '9845012345');
      await m.shot('number', 'Choose your country and enter your number, then select **Send code**.', { ring: { text: 'Send code' } });
      await m.tap({ text: 'Send code' });
      await m.wait('phone.code');
      await m.tap('testCode.use');
      await m.shot(
        'code',
        'ICR texts a 6-digit code to the number. Enter it and select **Verify**.',
        { ring: 'sheet.save', note: 'Codes reach Indian (+91) mobiles. A number from another country is saved without a code.' },
      );
      await m.tap('sheet.save');
      await m.gone('phone.code');
      await m.idle();
      await m.shot('done', 'Your number now shows as verified. Employers, mentors and suppliers you contact on ICR can reach you on it.');
      await m.home();
    },
  ),

  flow(
    'language',
    'Choose your language',
    { who: 'Everyone', as: 'member', intro: 'The language you choose is the one ICR writes to you in: its emails and its notifications. The app’s own screens are in English.' },
    async (m) => {
      await openSettings(m);
      await m.scrollTo('settings.language');
      await m.shot('row', 'In **Settings**, select **Language**.', { ring: 'settings.language' });
      await m.tap('settings.language');
      await m.wait('language.hi');
      await m.shot('choose', 'Select a language. ICR’s emails and notifications reach you in it from then on.');
      await m.back();
      await m.home();
    },
  ),

  flow(
    'notification-preferences',
    'Choose what ICR tells you about',
    { who: 'Everyone', as: 'member' },
    async (m) => {
      await openSettings(m);
      await m.scrollTo('settings.notifications');
      await m.shot('row', 'In **Settings**, select **Notifications**.', { ring: 'settings.notifications' });
      await m.tap('settings.notifications');
      await m.pause(1200);
      await m.idle();
      await m.shot('switches', 'Each kind of notification has two switches: one for the bell in the app and one for email. Turn off the ones you do not want.');
      await m.home();
    },
  ),

  flow(
    'your-data',
    'Download your data or delete your account',
    { who: 'Everyone', as: 'member' },
    async (m) => {
      await openSettings(m);
      await m.scrollTo('settings.delete');
      await m.shot('rows', 'Under **Privacy & data**, **Download my data** gives you a copy of what ICR holds about you.', { ring: 'settings.export' });
      await m.tap('settings.export');
      await m.pause(1500);
      await m.idle();
      await m.shot('export', 'Select **Get my data**. When it is ready you can read it on the phone, copy it, or share it to another app.');
      await m.back();
      await m.tap('settings.delete');
      await m.wait('delete.word');
      await m.shot(
        'delete',
        '**Delete my account** closes your account for good. The app asks you to type a word to confirm, so it cannot happen by accident.',
        { note: 'Deleting cannot be undone. If you only want a break, sign out instead.' },
      );
      await m.back();
      await m.home();
    },
  ),
]);
