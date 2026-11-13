import { defineManual, flow } from '../kit.mjs';

const JOB = 'design-lj-job-stp-1';
const INTERVIEWING = 'design-lj-app-bharat-extra-2';

/** The Jobs tab from its top: an earlier flow may have left the list scrolled, with the toolbar hidden. */
const jobsTab = async (m) => {
  await m.tab('jobs');
  // Several short swipes: one very long one is not taken as a scroll.
  for (let i = 0; i < 4; i++) await m.swipe(600);
};

export default defineManual('06-jobs', 'Jobs', [
  flow(
    'find',
    'Find a job',
    { who: 'Every member', as: 'member', intro: 'The Jobs tab lists open roles in facility management and corporate real estate. The roles that fit your résumé come first.' },
    async (m) => {
      await jobsTab(m);
      await m.wait('heading-foryou');
      await m.shot('board', 'Open the **Jobs** tab. **Recommended Jobs for You** are matched to the résumé on your profile. Search by title, skill or company in the box at the top.');
      await m.tap({ contains: 'Filters' });
      await m.pause(900);
      await m.idle();
      await m.shot('filters', 'Select **Filters** to narrow the list: place, work mode, experience, salary, type of role and more. Select the button at the bottom to see the matching jobs.');
      await m.back();
      await m.shot('row', 'Select a job to read it. The bookmark on a row saves the job for later.', { ring: `foryou-${JOB}` });
    },
  ),

  flow(
    'read',
    'Read a job',
    { who: 'Every member', as: 'member' },
    async (m) => {
      await jobsTab(m);
      await m.wait(`foryou-${JOB}`);
      await m.tap(`foryou-${JOB}`, { ensure: false });
      await m.wait({ text: 'Easy Apply', last: true });
      await m.shot(
        'sheet',
        'The job opens over the list: the company, place, pay, and how well your profile matches. At the top right you can **share** the job, **save** it, or open more.',
        { ring: { text: 'Easy Apply', last: true } },
      );
      await m.swipe(-520, { at: [200, 520] });
      await m.shot('more', 'Scroll for the responsibilities, the skills asked for, the company and the person hiring. **Message** writes to the hiring contact before you apply.');
      await m.home();
    },
  ),

  flow(
    'apply',
    'Apply',
    { who: 'Every member', as: 'member', intro: 'Applying sends your ICR résumé to the company’s hiring team. It takes a minute.' },
    async (m) => {
      // An earlier run of this flow applied already: take that application out so the job can be applied to again.
      const me = m.sql(`select id from "User" where email = '${m.person('member').email}'`);
      m.sql(`delete from "Application" where "jobId" = '${JOB}' and "applicantId" = '${me}'`);
      await m.become('member');
      await jobsTab(m);
      await m.wait(`foryou-${JOB}`);
      await m.tap(`foryou-${JOB}`, { ensure: false });
      await m.wait({ text: 'Easy Apply', last: true });
      await m.tap({ text: 'Easy Apply', last: true }, { ensure: false });
      await m.wait('apply-note');
      await m.enter('apply-salary', '2100000');
      await m.enter('apply-note', 'I have run STP and water-recycling plants on two campuses in Pune for six years, and held the consent-to-operate audits for both.');
      await m.shot(
        'form',
        'On the job, select **Easy Apply**. Choose the résumé to send. You may add your LinkedIn profile, the salary you expect and a note to the hiring team. If the company asks its own questions, they are on this form too.',
        { ring: { text: 'Submit application' }, note: 'The line at the top shows how many applications your plan has left this month.' },
      );
      await m.tap({ text: 'Submit application' }, { ensure: false });
      await m.gone('apply-note', 20000);
      await m.pause(1200);
      await m.idle();
      await m.shot('sent', 'Select **Submit application**. The app confirms it was sent, and the job now shows that you applied.');
      await m.home();
    },
  ),

  flow(
    'track',
    'Follow your applications',
    { who: 'Every member', as: 'member', intro: 'Every application has a page that shows where it stands, your interviews and any offer.' },
    async (m) => {
      await m.tab('home');
      await m.tap('home-avatar');
      await m.tap('workspace-jobs');
      await m.wait('workspace-jobs-0');
      await m.shot('menu', 'Open your profile menu, select **Jobs**, then **My applications**.', { ring: 'workspace-jobs-0' });
      await m.tap('workspace-jobs-0');
      await m.wait('summary');
      await m.shot('list', 'The tabs sort your applications by where they stand. **Up next** at the top is what needs you: an interview to confirm, or an offer to answer.');
      await m.open(`/career/applications/${INTERVIEWING}`);
      await m.wait('application-status');
      await m.shot(
        'detail',
        'Select an application to open it. **Message hiring team** writes to the recruiter, and **Withdraw** stops the application; the company is told.',
        { ring: 'withdraw' },
      );
      await m.scrollTo('interviews', { align: 0.2 });
      await m.shot('interview', 'The line of stages shows how far it has gone. Under **Interviews**, each round shows its date and how to join. Select **Confirm I will attend** to accept the time, or **Ask for another time**.');
      await m.home();
    },
  ),

  flow(
    'career',
    'Your career page',
    { who: 'Every member', as: 'member' },
    async (m) => {
      await m.open('/career');
      await m.wait('snapshot');
      await m.shot('hub', 'Your career page gathers it all: your next steps, where your applications stand, and how strong your résumé is. Open it from **My jobs** on the Jobs tab.');
      await m.scrollTo('shortcuts', { align: 0.25 });
      await m.shot('shortcuts', 'The shortcuts open your **saved jobs**, **job alerts**, **invitations** from recruiters and your **interviews**.');
      await m.home();
    },
  ),

  flow(
    'alerts',
    'Saved jobs, alerts and invitations',
    { who: 'Every member', as: 'member' },
    async (m) => {
      await m.open('/career/saved');
      await m.pause(1200);
      await m.idle();
      await m.shot('saved', '**Saved Items** in your profile menu keeps what you bookmarked: jobs, mentors, suppliers and more. Select the bookmark again to remove one.');
      await m.home();
      await m.open('/career');
      await m.wait('snapshot');
      await m.scrollTo({ text: 'Job alerts' }, { align: 0.5 });
      await m.tap({ text: 'Job alerts' });
      await m.wait('new-alert');
      await m.shot('alerts', 'On your career page, select **Job alerts**. An alert is a search ICR runs for you; new matches reach your bell and your email.', { ring: 'new-alert' });
      await m.tap('new-alert');
      await m.wait('alert-name');
      await m.enter('alert-name', 'Facility manager roles in Pune');
      await m.enter('alert-keywords', 'facility manager');
      await m.shot('new-alert', 'Select the **+** at the top right. Name the alert, add the words and cities to look for, choose **Daily** or **Weekly**, and select **Save alert**.', { ring: 'alert-save' });
      await m.back();
      await m.home();
      await m.open('/career/invitations');
      await m.pause(1200);
      await m.idle();
      await m.shot('invitations', '**Invitations**, also on your career page, are roles a recruiter asked you to look at. Select **View & apply** to read the job, or **Decline**. Turn on **Open to opportunities** to let recruiters find your résumé.');
      await m.home();
    },
  ),

  flow(
    'company',
    'Read about a company',
    { who: 'Every member', as: 'member', intro: 'Before you apply, see what the company is like to work for: its open jobs, its people, and what members have said about it.' },
    async (m) => {
      await m.open('/companies/design-lj-co-global-infra');
      await m.wait('tab-reviews');
      await m.pause(1200);
      await m.idle();
      await m.shot('page', 'On a job, select the company’s name to open its page. **Jobs** lists its open roles, and **People** the members who work there.', { ring: 'tab-reviews' });
      await m.tap('tab-reviews');
      await m.pause(1500);
      await m.idle();
      await m.shot('reviews', '**Reviews** shows what members who worked there wrote, with their ratings.');
      await m.tap('tab-salaries');
      await m.pause(1500);
      await m.idle();
      await m.shot('salaries', '**Salaries** shows the pay members reported for each role, and **Interviews** what the company’s interviews were like.');
      await m.home();
    },
  ),

  flow(
    'interviews',
    'Your interviews and hidden jobs',
    { who: 'Every member', as: 'member' },
    async (m) => {
      await m.open('/career');
      await m.wait('snapshot');
      await m.scrollTo({ text: 'Hidden jobs' }, { align: 0.5 });
      await m.tap({ text: 'Interviews', last: true });
      await m.pause(1500);
      await m.idle();
      await m.shot('interviews', 'On your career page, **Interviews** lists every round across all your applications. **Confirm** a time, **Ask for another time**, and join the call from here. **Past** holds the ones already held.');
      await m.back();
      await m.tap({ text: 'Hidden jobs' });
      await m.pause(1500);
      await m.idle();
      await m.shot('hidden', '**Hidden jobs** are the ones you chose not to see on your board. **Show again** brings one back.');
      await m.home();
    },
  ),
]);
