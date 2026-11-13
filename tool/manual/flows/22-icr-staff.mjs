import { defineManual, flow } from '../kit.mjs';

const settle = async (m, ms = 1500) => {
  await m.pause(ms);
  await m.idle();
};

export default defineManual('22-icr-staff', 'ICR staff', [
  flow(
    'super-admin',
    'Super Admin',
    {
      who: 'ICR staff',
      as: 'superAdmin',
      intro: 'ICR’s admin consoles are on the website. In the app a staff account can read what members see and answer enquiries, which is useful when helping a member by phone.',
    },
    async (m) => {
      await m.tab('home');
      await m.tap('home-avatar');
      await m.wait('workspace-marketplace');
      await m.shot('menu', 'A Super Admin’s profile menu lists the member-facing pages by area: **Company**, **Marketplace**, **Jobs**, **Engage** and **Learn**. There is no Admin row: reviews, approvals, plans and roles are done at icr.org.in.');
      await m.tap('workspace-marketplace');
      await m.wait('workspace-marketplace-0');
      await m.shot('row', 'Each row opens the pages a member would use, so you can see exactly what they see.');
      await m.back();
      await m.open('/account/companies');
      await settle(m);
      await m.shot('companies', 'A staff account is personal. It cannot join or create a company, and **My companies** says so.');
      await m.home();
    },
  ),

  flow(
    'learning-admin',
    'Learning Admin',
    { who: 'ICR staff who run the Learning Center', as: 'learningAdmin' },
    async (m) => {
      await m.tab('home');
      await m.tap('home-avatar');
      await m.wait('workspace-learn');
      await m.tap('workspace-learn');
      await m.wait('workspace-learn-0');
      await m.shot('menu', 'A Learning Admin’s menu has one row, **Learn**: the course **Enquiries** from every institute, the **Learning** tab, and **Get Involved**. Courses, papers and institutes are managed on the website.');
      await m.back();
    },
  ),

  flow(
    'partner-admin',
    'Partner Admin',
    { who: 'The person who runs one partner institute’s catalogue for ICR', as: 'partnerAdmin' },
    async (m) => {
      await m.tab('home');
      await m.tap('home-avatar');
      await m.wait('workspace-learn');
      await m.tap('workspace-learn');
      await m.wait('workspace-learn-0');
      await m.shot('menu', 'A Partner Admin sees **Learn → Enquiries** only.', { ring: 'workspace-learn-0' });
      await m.tap('workspace-learn-0');
      await m.wait({ keyPrefix: 'enquiry-' });
      await settle(m);
      await m.shot('enquiries', 'The list holds the enquiries for your own institute and no other. Answer them and set their status as in the Partner institutes chapter.');
      await m.home();
    },
  ),
]);
