import { defineManual, flow } from '../kit.mjs';

const NEW_COMPANY = 'Northgate Property Care';

const settle = async (m, ms = 1500) => {
  await m.pause(ms);
  await m.idle();
};

/** The newcomer back to having no company: an earlier run joined one and created another. */
function resetNewcomer(m) {
  const id = m.sql(`select id from "User" where email = '${m.person('newcomer').email}'`);
  m.sql(`delete from "CompanyMembership" where "userId" = '${id}'`);
  m.sql(`update "User" set "companyId" = null, "branchId" = null, role = 'PROFESSIONAL' where id = '${id}'`);
  m.sql(`update "Company" set "deletedAt" = now(), name = name || ' (earlier run ' || id || ')' where name = '${NEW_COMPANY}'`);
}

export default defineManual('14-companies', 'Companies', [
  flow(
    'my-companies',
    'My companies',
    {
      who: 'Every member',
      as: 'newcomer',
      intro: 'Hiring, buying and selling on ICR are done for a company. You can belong to several companies and act for one at a time, or act as yourself.',
    },
    async (m) => {
      resetNewcomer(m);
      await m.become('newcomer');
      await m.tab('home');
      await m.tap('home-avatar');
      await m.tap('workspace-account');
      await m.scrollTo({ text: 'My companies' }, { at: [150, 600] });
      await m.shot('menu', 'Open your profile menu, select **Account**, then **My companies**.', { ring: { text: 'My companies' } });
      await m.tap({ text: 'My companies' });
      await m.wait('companies.create');
      await settle(m);
      await m.shot('list', '**My companies** lists the companies you belong to. With none yet, you can **Create a company** or **Ask to join a company** that is already on ICR.');
    },
  ),

  flow(
    'join',
    'Ask to join a company',
    { who: 'Every member', as: 'newcomer', intro: 'If your employer already has a page on ICR, ask its admins to add you. They decide.' },
    async (m) => {
      await m.open('/account/companies');
      await m.wait('companies.join');
      await m.tap('companies.join');
      await m.wait('join.search');
      await m.enter('join.search', 'Meridian Facility', { keep: true });
      await settle(m);
      await m.shot('search', 'Select **Ask to join a company** and search for it by name. Select the company.', { keyboard: true });
      await m.tap({ keyPrefix: 'join.hit.', i: 0 }, { ensure: false });
      await m.wait('join.note');
      await m.enter('join.note', 'I joined the Bengaluru operations team this month as an assistant facility manager.');
      await m.shot('note', 'Add a short note so the admins know who you are, and send the request.');
      await m.tap({ contains: 'Send' }, { ensure: false });
      await settle(m, 2000);
      await m.shot('waiting', 'The company shows as waiting for its admins. You are told in your notifications when they decide.');
      await m.home();
    },
  ),

  flow(
    'create',
    'Create a company page',
    { who: 'Every member', as: 'newcomer', intro: 'A company page takes about a minute. Documents are not needed now; ICR asks for them the first time you post a job, bid or sell.' },
    async (m) => {
      await m.open('/account/companies');
      await m.wait('companies.create');
      await m.tap('companies.create');
      await m.wait('create.name');
      await m.enter('create.name', NEW_COMPANY);
      await m.enter('create.website', 'northgatecare.example');
      await m.shot('identity', 'Select **Create a company**. Enter the company’s name as buyers and candidates know it, and its website if it has one.');
      await m.tapIn('create.industry', 0.5, 0.6);
      await m.wait({ text: 'Facility management services' });
      await m.tap({ text: 'Facility management services' }, { ensure: false });
      await m.pause(600);
      await m.tapIn('create.city', 0.5, 0.6);
      await m.pause(900);
      if (await m.exists('accountPicker.search')) await m.enter('accountPicker.search', 'Bengaluru', { keep: true });
      await m.pause(1200);
      await m.tap({ contains: 'Bengaluru', last: true }, { ensure: false });
      await m.pause(600);
      await m.scrollTo('create.size.51-200', { align: 0.4 });
      await m.tap('create.size.51-200');
      await m.tapIn('create.structure', 0.5, 0.5);
      await m.pause(900);
      await m.tap({ contains: 'Private limited', i: 0 }, { ensure: false });
      await m.pause(600);
      await m.scrollTo('create.size.51-200', { align: 0.25 });
      await m.shot('details', 'Choose the industry, the head-office city, the size and how the company is set up.');
      await m.scrollTo('create.authorised', { align: 0.5 });
      await m.tapIn('create.authorised', 0.06, 0.5);
      await m.scrollTo('create.submit', { align: 0.8 });
      await m.shot('confirm', 'Tick the box to confirm you may act for the company, then create the page.', { ring: 'create.submit' });
      await m.tap('create.submit');
      await m.wait('create.welcome', 30000);
      await settle(m);
      await m.shot('welcome', 'The page exists and you are its admin. The app offers the next steps: add your team, verify the company, and start selling.');
      await m.home();
    },
  ),

  flow(
    'switch',
    'Switch between companies and yourself',
    { who: 'Every member', as: 'newcomer' },
    async (m) => {
      await m.open('/account/companies');
      await m.wait('companies.workspaces');
      await settle(m);
      await m.shot('switch', 'In **My companies**, **Switch to this company** makes you act for it: your profile menu, jobs and requirements become that company’s. **Personal account** takes you back to acting as yourself. **Leave** ends your place at a company.');
      await m.home();
    },
  ),
]);
