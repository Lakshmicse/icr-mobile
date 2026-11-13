import { defineManual, flow } from '../kit.mjs';

export default defineManual('01-getting-started', 'Signing in and out', [
  flow(
    'sign-up',
    'Create your account',
    { who: 'Anyone new to ICR', as: 'public', intro: 'Joining takes three short screens: your email and a password, a little about you, and your work. Have your phone and your email at hand: ICR sends a code to each.' },
    async (m) => {
      const email = 'kavya.reddy@northgatecare.example';
      // An earlier run made this account: move it aside so the address is free again.
      m.sql(`update "User" set email = 'earlier-run-' || id || '@northgatecare.example', phone = null where email = '${email}'`);
      m.sql(`update "User" set phone = null where phone = '+919886012345'`);
      await m.wait('signIn.create');
      await m.shot('start', 'On **Sign in**, select **Join now**.', { ring: 'signIn.create' });
      await m.tap('signIn.create');
      await m.wait('signup.email');
      await m.enter('signup.email', email);
      await m.enter('signup.password', 'Monsoon#Campus26');
      await m.tapIn('signup.agree', 0.05, 0.5);
      await m.shot(
        'join',
        '**Join ICR**, the first of three screens. Enter your work email and create a password; the bar shows how strong it is. Tick the box to accept the Terms of Service and Privacy Policy, and select **Join**.',
        { ring: 'signup.join', note: 'The LinkedIn and Google buttons at the top join with that account instead: you skip the password, and the rest is the same.' },
      );
      await m.tap('signup.join');
      await m.wait('signup.firstName');
      await m.enter('signup.firstName', 'Kavya');
      await m.enter('signup.lastName', 'Reddy');
      await m.enter('signup.phone', '9886012345');
      await m.shot('about', '**About you**, the second screen. Enter your first and last name and your mobile number, then select **Send code**. ICR texts a code to an Indian (+91) mobile; a number from another country is accepted without one.', { ring: 'signup.phoneSend' });
      await m.tap('signup.phoneSend');
      await m.wait('signup.phoneCode');
      await m.tap('signup.phoneUseCode', { ensure: false });
      await m.pause(600);
      if (await m.exists('signup.phoneVerify')) await m.tap('signup.phoneVerify');
      await m.wait('signup.phoneVerified');
      await m.scrollTo('signup.code', { align: 0.45 });
      await m.tap({ key: 'signup.useCode', i: 0 }, { ensure: false });
      await m.shot('codes', 'Enter the code from the text and select **Verify**; a green tick confirms your number. Then enter the 6-digit code ICR emailed you, and select **Continue**. Your account now exists.', { ring: 'signup.continue' });
      await m.tap('signup.continue');
      await m.wait('work.title', 30000);
      await m.enter('work.title', 'Assistant Facility Manager');
      await m.enter('work.company', 'Northgate Property Care');
      await m.shot('work', '**Your work**, the third screen. Say where you work: your job title, your company and the year you started. If the company has a page on ICR, pick it from the list and you can ask to join its team. Between roles? Select **Between roles** instead. Select **Continue**, or **Skip for now**.', { ring: 'work.save' });
      await m.tap('work.skip');
      await m.wait('home-avatar', 30000);
      await m.shot('home', 'You are signed in, on **Home**. Your profile menu, at the top left, is where to add your photo and the rest of your profile.');
    },
  ),

  flow(
    'sign-in',
    'Sign in',
    { who: 'Everyone', as: 'public', intro: 'You sign in to the app with the same email and password you use on icr.org.in.' },
    async (m) => {
      const me = m.person('member');
      await m.wait('signIn.email');
      await m.shot('open', 'Open the **ICR** app. It opens on **Sign in**.');
      await m.enter('signIn.email', me.email);
      await m.enter('signIn.password', me.password);
      await m.tapIn('signIn.remember', 0.08, 0.5);
      await m.shot(
        'details',
        'Enter your **Email** and **Password**. Select **Show** to check the password you typed. Tick **Remember me** to stay signed in on this phone.',
        { ring: 'signIn.submit', note: 'To use your LinkedIn or Google account instead, select **Continue with LinkedIn** or **Continue with Google** and follow that account’s own sign-in page.' },
      );
      await m.tap('signIn.submit');
      await m.wait('home-avatar');
      await m.shot('home', 'Select **Sign in**. The app opens on **Home**, with your photo at the top left and the six tabs along the bottom.');
    },
  ),

  flow(
    'wrong-password',
    'If the app does not let you in',
    { who: 'Everyone', as: 'public', intro: 'The app tells you when the email or password does not match an account.' },
    async (m) => {
      const me = m.person('member');
      await m.wait('signIn.email');
      await m.enter('signIn.email', me.email);
      await m.enter('signIn.password', 'not-my-password');
      await m.tap('signIn.submit');
      await m.wait({ contains: 'Invalid email or password' });
      await m.shot(
        'refused',
        'When the email or password is wrong, the app says **Invalid email or password.** Check the email for typing mistakes, then type the password again. If you have forgotten it, select **Forgot password?**',
        { ring: 'signIn.forgot' },
      );
    },
  ),

  flow(
    'forgot-password',
    'Reset a forgotten password',
    { who: 'Everyone', as: 'public', intro: 'ICR emails you a link. You open the link and choose a new password.' },
    async (m) => {
      const me = m.person('member');
      await m.wait('signIn.email');
      await m.enter('signIn.email', me.email);
      await m.tap('signIn.forgot');
      await m.wait('forgot.email');
      await m.shot('ask', 'On **Sign in**, select **Forgot password?** Enter the email of your account and select the button to send the link.', { ring: 'forgot.send' });
      await m.tap('forgot.send');
      await m.wait('forgot.sent');
      await m.shot(
        'sent',
        'The app confirms the email is on its way. Open the email from ICR on this phone and copy the link in it.',
        { hide: ['forgot.testLink', 'forgot.useLink'], note: 'No email after a few minutes? Check your spam folder, then select **Send it again**.' },
      );
      await m.tap('forgot.haveLink');
      await m.idle();
      await m.shot('new-password', 'Select **I have my link**, paste the link from the email, then enter your new password twice and save it. Sign in with the new password.');
    },
  ),

  flow(
    'sign-out',
    'Sign out',
    { who: 'Everyone', as: 'member', intro: 'Sign out when you share the phone with someone else. Your account and everything in it stay as they are.' },
    async (m) => {
      await m.wait('home-avatar');
      await m.shot('photo', 'On **Home**, select your photo at the top left to open your profile menu.', { ring: 'home-avatar' });
      await m.tap('home-avatar');
      await m.scrollTo('account-settings', { at: [150, 600] });
      await m.shot('menu', 'Scroll to the bottom of the menu and select **Settings**.', { ring: 'account-settings' });
      await m.tap('account-settings');
      await m.scrollTo('settings.signOut');
      await m.shot('settings', 'Scroll to the bottom of **Settings** and select **Sign out**.', { ring: 'settings.signOut' });
      await m.tap('settings.signOut');
      await m.wait({ contains: 'Sign out of ICR' });
      await m.shot('confirm', 'Confirm. The app returns to **Sign in**.');
      await m.back();
    },
  ),
]);
