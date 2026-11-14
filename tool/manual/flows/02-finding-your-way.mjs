import { defineManual, flow } from '../kit.mjs';

export default defineManual('02-finding-your-way', 'Finding your way around', [
  flow(
    'tabs',
    'The six tabs',
    { who: 'Everyone', as: 'member', intro: 'The bar along the bottom is the same for every account. Each tab is one part of ICR.' },
    async (m) => {
      await m.tab('home');
      await m.shot('home', '**Home** is the feed: discussions, questions and polls from members, with the people you follow first.', { ring: { text: 'Home', last: true } });
      await m.tab('learning');
      await m.shot('learning', '**Learning** holds courses, practice papers, mock tests, flash cards and your certificates.', { ring: { text: 'Learning', last: true } });
      await m.tab('mentorship');
      await m.shot('mentorship', '**Mentorship** is where you find a mentor, book sessions and follow your mentoring.', { ring: { text: 'Mentorship', last: true } });
      await m.tab('marketplace');
      await m.shot('marketplace', '**Marketplace** lists suppliers of facility services and products, and the requirements buyers have posted.', { ring: { text: 'Marketplace', last: true } });
      await m.tab('jobs');
      await m.shot('jobs', '**Jobs** shows roles in facility management, the ones recommended for you first.', { ring: { text: 'Jobs', last: true } });
    },
  ),

  flow(
    'discover',
    'Discover: the rest of ICR',
    { who: 'Everyone', as: 'member', intro: 'Discover opens a sheet of doors to the parts of ICR that have no tab of their own.' },
    async (m) => {
      await m.tab('home');
      await m.tap({ text: 'Discover', last: true });
      await m.wait({ text: 'Chapters' });
      await m.shot(
        'sheet',
        'Select **Discover**. The first row opens **Chapters**, **Councils**, the **Digital Library** and **Events**. The second row starts something: hire, sell, post a requirement or advertise.',
      );
      await m.back();
    },
  ),

  flow(
    'profile-menu',
    'Your profile menu',
    { who: 'Everyone', as: 'member', intro: 'Your photo at the top left of Home opens your own menu: your pages, your account and Settings. This menu is the part of the app that changes with the kind of account you have.' },
    async (m) => {
      await m.tab('home');
      await m.tap('home-avatar');
      await m.wait('drawer-profile');
      await m.shot('menu', 'Select your photo. The top of the menu shows your name and headline; select it to open your profile.', { ring: 'drawer-profile' });
      await m.tap('workspace-jobs');
      await m.wait('workspace-jobs-0');
      await m.shot('row', 'Select a row to see its pages. **Jobs** opens **My applications**, **My saved jobs** and **Search jobs**.', { ring: 'workspace-jobs' });
      await m.tap('workspace-jobs');
      await m.scrollTo('account-settings', { at: [150, 600] });
      await m.shot('foot', 'Further down are the doors to do more on ICR, then **Saved Items** and **Settings**.', { ring: 'account-saved' });
      await m.back();
    },
  ),

  flow(
    'search',
    'Search everything',
    { who: 'Everyone', as: 'member', intro: 'One search covers people, jobs, courses, mentors, suppliers, events, discussions and documents.' },
    async (m) => {
      await m.tab('home');
      await m.shot('bar', 'On **Home**, select **Search** at the top.', { ring: 'home-search' });
      await m.tap('home-search');
      await m.wait('search.field');
      await m.enter('search.field', 'HVAC');
      await m.action('search');
      await m.pause(1500);
      await m.idle();
      await m.shot('results', 'Type what you are looking for. Results are grouped by kind; select a chip to keep one kind, and select a result to open it.');
      await m.home();
    },
  ),

  flow(
    'notifications',
    'Notifications',
    { who: 'Everyone', as: 'member', intro: 'The bell collects what happened while you were away: replies, application updates, session reminders, messages.' },
    async (m) => {
      await m.tab('home');
      await m.shot('bell', 'A red dot on the bell means there is something new. Select the bell.', { ring: 'home-bell' });
      await m.tap('home-bell');
      await m.wait('tab-all');
      await m.shot(
        'list',
        'Select a notification to open what it is about. **Unread** keeps only the new ones, and the chips keep one kind. **Mark all read** clears the red dot without opening each one.',
        { ring: 'mark-all-read' },
      );
      await m.home();
    },
  ),

  flow(
    'saathi',
    'Ask Saathi',
    { who: 'Everyone', as: 'member', intro: 'Saathi is ICR’s assistant. Ask it how to do something and it answers with the page to open.' },
    async (m) => {
      await m.tab('home');
      await m.shot('button', 'The round blue button at the bottom right of every tab opens **Saathi**.', { ring: 'saathi-launcher' });
      await m.tap('saathi-launcher');
      await m.wait('assistant-input');
      await m.shot('open', 'Select one of the suggestions, or type your own question.');
      await m.enter('assistant-input', 'How do I apply for a job?');
      await m.tap('assistant-send');
      await m.gone('assistant-typing', 60000);
      await m.pause(800);
      await m.shot('answer', 'Saathi answers in a few lines. The buttons under the answer open the pages it mentions.');
      await m.home();
    },
  ),
]);
