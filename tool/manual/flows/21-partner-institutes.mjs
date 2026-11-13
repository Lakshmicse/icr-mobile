import { defineManual, flow } from '../kit.mjs';

const settle = async (m, ms = 1500) => {
  await m.pause(ms);
  await m.idle();
};

export default defineManual('21-partner-institutes', 'Partner institutes', [
  flow(
    'menu',
    'Your institute in the app',
    {
      who: 'Admins and staff of a partner institute',
      as: 'instituteAdmin',
      intro: 'A partner institute teaches its courses on ICR. In the app its staff answer enquiries and build the team; courses and batches are published on the website.',
    },
    async (m) => {
      await m.tab('home');
      await m.tap('home-avatar');
      await m.scrollTo('workspace-partner', { at: [150, 600] });
      await m.tap('workspace-partner');
      await m.wait('workspace-partner-0');
      await m.shot('menu', 'Open your profile menu and select **Partner Institute**: **Enquiries**, and adding a team member, a trainer or a programme specialist.', { ring: 'workspace-partner' });
      await m.back();
    },
  ),

  flow(
    'enquiries',
    'Answer enquiries',
    { who: 'Admins and staff of a partner institute', as: 'instituteAdmin' },
    async (m) => {
      // An earlier run moved the first enquiry on: it is new again.
      m.sql(`update "LearningLead" set status = 'NEW', "handledAt" = null, "handledById" = null where id in ('manual-lead-1', 'manual-lead-2')`);
      await m.open('/admin/learning/enquiries');
      await m.wait({ keyPrefix: 'enquiry-' });
      await settle(m);
      await m.shot('list', '**Enquiries** lists the questions and requests members sent your institute: a place on a course, a brochure, or a course run in-house for a team. The chips keep one status.');
      await m.tap({ keyPrefix: 'status-', i: 0 });
      await settle(m, 900);
      await m.shot('status', 'Once you have written or called, set the enquiry’s status: **Contacted**, **Converted** when they enrol, or **Closed**. A note records what was agreed.');
      await m.back();
      await m.home();
    },
  ),

  flow(
    'team',
    'Add a trainer',
    { who: 'Admins of a partner institute', as: 'instituteAdmin' },
    async (m) => {
      await m.open('/manage/team?invite=TRAINER');
      await settle(m, 2000);
      await m.shot('trainer', '**Add a trainer** opens your **Team** page. Select **Invite by email** and choose the learning role. A member of the institute’s team can hold one or more of them: course admin, batch admin, enrolment admin, trainer and finance.');
      await m.back();
      await m.home();
    },
  ),
]);
