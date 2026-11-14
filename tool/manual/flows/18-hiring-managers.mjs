import { defineManual, flow } from '../kit.mjs';

const INTERVIEW = 'cmwd8521707n5itw5ge9z0h88'; // Facility Manager – IT Park Operations, Hema on the panel

const settle = async (m, ms = 1500) => {
  await m.pause(ms);
  await m.idle();
};

export default defineManual('18-hiring-managers', 'Hiring managers', [
  flow(
    'brief',
    'Prepare for an interview',
    {
      who: 'Hiring managers',
      as: 'hiringManager',
      intro: 'A hiring manager sits on interview panels and gives feedback. You see only the interviews you are on the panel for; the recruiter does the rest.',
    },
    async (m) => {
      // The round is in two days, as when the recruiter has just booked it.
      m.sql(`update "Interview" set "scheduledAt" = (now() at time zone 'utc') + interval '2 days', status = 'SCHEDULED' where id = '${INTERVIEW}'`);
      m.sql(`delete from "InterviewFeedback" where "interviewId" = '${INTERVIEW}'`);
      await m.tab('home');
      await m.tap('home-bell');
      await m.wait('tab-all');
      await settle(m);
      await m.shot('bell', 'When a recruiter puts you on a panel, ICR tells you in your notifications and by email. Select the notification to open the interview.');
      await m.home();
      await m.open(`/manage/interviews/${INTERVIEW}`);
      await m.wait('brief-candidate');
      await settle(m);
      await m.shot('brief', 'The interview’s page shows when and how it is held, the candidate, and the job. **Join** opens the call when it is time.');
      await m.scrollTo('brief-scorecard', { align: 0.75 });
      await m.shot('candidate', 'Before you meet them, read the candidate’s cover note, their answers to your company’s questions, how their résumé fits the job, your team’s notes and what earlier rounds found. Your scorecard opens when the interview starts.');
      await m.home();
    },
  ),

  flow(
    'feedback',
    'Give your feedback',
    { who: 'Hiring managers', as: 'hiringManager' },
    async (m) => {
      // The round has been held: the scorecard opens once its time has come.
      m.sql(`update "Interview" set "scheduledAt" = (now() at time zone 'utc') - interval '3 hours' where id = '${INTERVIEW}'`);
      await m.become('hiringManager');
      await m.open(`/manage/interviews/${INTERVIEW}`);
      await m.wait('brief-candidate');
      await settle(m);
      await m.scrollTo('brief-scorecard', { align: 0.25 });
      await m.shot('scorecard', 'After the interview, open it again and scroll to **Your scorecard**. Give an overall rating, choose a recommendation from **Strong yes** to **Strong no**, write the strengths and concerns you saw, and select **Submit scorecard**. Your feedback goes to the recruiter; the candidate does not see it.');
      await m.home();
    },
  ),
]);
