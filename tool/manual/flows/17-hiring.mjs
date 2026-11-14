import { defineManual, flow } from '../kit.mjs';

const JOB = 'design-career-job-pipeline'; // Facilities Operations Lead, nine applicants across every stage

const settle = async (m, ms = 1400) => {
  await m.pause(ms);
  await m.idle();
};

const myJobs = async (m) => {
  await m.open('/manage/jobs');
  await m.wait('jobs-search');
  await settle(m);
};

export default defineManual('17-hiring', 'Recruiters and office admins', [
  flow(
    'jobs',
    'The jobs you posted',
    {
      who: 'Recruiters, office admins and company admins',
      as: 'pipelineRecruiter',
      intro: 'Hiring is done for a company. A recruiter posts jobs and works the applicants; an office admin does the same for their office and the offices under it.',
    },
    async (m) => {
      await m.tab('home');
      await m.tap('home-avatar');
      await m.tap('workspace-jobs');
      await m.wait('workspace-jobs-0');
      await m.shot('menu', 'Open your profile menu and select **Jobs**, then **Post & manage jobs**.', { ring: 'workspace-jobs-0' });
      await m.back();
      await myJobs(m);
      await m.shot('list', '**Jobs you posted** shows every job with its status and applicants. The figures at the top count what needs attention, and the tabs keep one status. The **+** at the top posts a new job.');
      await m.tap({ keyPrefix: 'job-menu-', i: 0 });
      await settle(m, 900);
      await m.shot('actions', 'The three dots on a job open its actions: edit it, duplicate it as a draft, pause or close a live job, or delete a draft. **Promote**, which pays for a boost, opens the website.');
      await m.back();
      await m.home();
    },
  ),

  flow(
    'post',
    'Post a job',
    { who: 'Recruiters, office admins and company admins', as: 'pipelineRecruiter' },
    async (m) => {
      await m.open('/manage/jobs/new');
      await m.wait('job-title');
      await settle(m);
      await m.enter('job-title', 'Assistant Facility Manager');
      await m.shot('title', 'Select the **+** on **Jobs you posted**. Start with the job title; the app suggests titles as you type.');
      await m.scrollTo('job-description', { align: 0.3 });
      await m.enter(
        'job-description',
        'You will run day-to-day soft and hard services for a 400,000 sq ft office campus in Nagpur: helpdesk, housekeeping and security vendors, monthly PPM and the client’s audits. You report to the Facility Operations Head and lead a team of six supervisors.',
      );
      await m.shot('description', 'Describe the role. A clear description of at least a few lines is needed before the job can go live.');
      await m.scrollTo('checklist', { align: 0.3 });
      await m.shot('checklist', 'Further down you add the places and openings, the skills, the pay and up to ten screening questions. The checklist shows what is still missing. **Save draft** keeps it for later; **Publish** puts it on the Jobs tab.');
      await m.back();
      await settle(m, 800);
      if (await m.exists('leave-discard')) await m.tap('leave-discard');
      await m.home();
    },
  ),

  flow(
    'applicants',
    'Work the applicants',
    { who: 'Recruiters, office admins and company admins', as: 'pipelineRecruiter' },
    async (m) => {
      await myJobs(m);
      await m.scrollTo(`open-applicants-${JOB}`, { align: 0.5 });
      await m.shot('open', 'On a job, select **Applicants**.', { ring: `open-applicants-${JOB}` });
      await m.tap(`open-applicants-${JOB}`);
      await m.wait({ keyPrefix: 'applicant-menu-' });
      await settle(m, 1800);
      await settle(m);
      await m.shot('pipeline', 'The chips show how many applicants are at each stage; select one to keep that stage. **Sort**, **Rating** and **Qualified** narrow the list further. Select an applicant to open them.');
      await m.tap({ keyPrefix: 'applicant-menu-', i: 0 });
      await settle(m, 900);
      await m.shot('move', 'The three dots on an applicant move them to the next stage, or reject them.');
      await m.back();
      await m.tap({ keyPrefix: 'applicant-design-career-app-', i: 0 });
      await m.wait('detail-header');
      await settle(m);
      await m.shot('detail', 'An applicant’s page shows their résumé, their answers to your questions, the notes your team wrote, and what has happened so far. **Message** writes to them.');
      await m.scrollTo('detail-actions', { align: 0.6 });
      await m.shot('actions', 'Under **Next step**: move the applicant to review or to interview, **Schedule interview**, **Message** them, or **Reject**. Once they have reached the interview stage, **Make offer** appears here too.', { ring: 'detail-actions' });
      await m.home();
    },
  ),

  flow(
    'interview',
    'Schedule an interview and make an offer',
    { who: 'Recruiters, office admins and company admins', as: 'pipelineRecruiter' },
    async (m) => {
      await myJobs(m);
      await m.scrollTo(`open-applicants-${JOB}`, { align: 0.5 });
      await m.tap(`open-applicants-${JOB}`);
      await m.wait({ keyPrefix: 'applicant-menu-' });
      await settle(m, 1800);
      await m.tap({ keyPrefix: 'applicant-design-career-app-', i: 0 });
      await m.wait('detail-header');
      await m.scrollTo('detail-schedule', { align: 0.6 });
      await m.tap('detail-schedule');
      await m.wait('interview-title');
      await settle(m, 800);
      await m.shot('schedule', 'Select **Schedule interview**. Name the round, set the date and time, choose a video call, phone or a place, and pick the panel. The candidate and the panel are told, and each can add it to their calendar.');
      await m.back();
      await m.back();
      await m.wait({ keyPrefix: 'applicant-menu-' });
      // An offer is made to someone who has reached the interview stage.
      await m.scrollTo({ text: 'Sanjana Pillai' }, { align: 0.4 });
      await m.tap({ text: 'Sanjana Pillai' });
      await m.wait('detail-header');
      await m.scrollTo('detail-offer', { align: 0.6 });
      await m.tap('detail-offer');
      await m.wait('offer-title');
      await settle(m, 800);
      await m.shot('offer', 'For an applicant at the interview stage, select **Make an offer**. Enter the salary, the title, the joining date and the date to reply by. **Save draft** keeps it; **Send offer** sends it, and the candidate accepts or declines from their application.');
      await m.back();
      await m.home();
    },
  ),
]);
