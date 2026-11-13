import { defineManual, flow } from '../kit.mjs';

const settle = async (m, ms = 1400) => {
  await m.pause(ms);
  await m.idle();
};

/** Gita's request to join is waiting again, and nobody is half-added: what an earlier run decided is undone. */
function resetTeam(m) {
  const company = m.sql(`select "companyId" from "User" where email = '${m.person('companyAdmin').email}'`);
  const gita = m.sql(`select id from "User" where email = '${m.person('newcomer').email}'`);
  const pooja = m.sql(`select id from "User" where email = '${m.person('second').email}'`);
  m.sql(`update "CompanyMembership" set status = 'REQUESTED', role = 'PROFESSIONAL', "decidedAt" = null, "decidedById" = null where "userId" = '${gita}' and "companyId" = '${company}'`);
  m.sql(`delete from "CompanyMembership" where "userId" = '${pooja}' and "companyId" = '${company}'`);
}

export default defineManual('16-company-admins', 'Company admins', [
  flow(
    'menu',
    'Acting for your company',
    {
      who: 'Company admins',
      as: 'companyAdmin',
      intro: 'A company admin runs the company’s page: its team, and through them its jobs, its requirements and its bids. While you act for the company, your profile menu shows the company’s rows.',
    },
    async (m) => {
      await m.tab('home');
      await m.tap('home-avatar');
      await m.wait('workspace-company');
      await m.tap('workspace-company');
      await m.wait('workspace-company-0');
      await m.shot('menu', 'Open your profile menu. The company you are acting for is at the top. **Company** opens the team, the requirements you posted and the work you can bid for; **Jobs** adds posting and managing jobs.', { ring: 'workspace-company' });
      await m.back();
    },
  ),

  flow(
    'team',
    'Your team',
    { who: 'Company admins', as: 'companyAdmin' },
    async (m) => {
      resetTeam(m);
      await m.open('/manage/team');
      await m.wait('team.members');
      await settle(m);
      await m.shot('members', 'In your profile menu, select **Company**, then **Add members**. **Members** lists everyone with their role, their office and the company messages they can read. **Edit** changes these; **Remove** ends someone’s place.', { ring: { keyPrefix: 'team.edit.', i: 0 } });
      await m.tap({ keyPrefix: 'team.edit.', i: 0 });
      await settle(m, 1000);
      await m.shot('edit', 'Choose the person’s role and the office they cover, then select **Save**.');
      await m.back();
      await m.home();
    },
  ),

  flow(
    'requests',
    'Approve someone who asked to join',
    { who: 'Company admins', as: 'companyAdmin' },
    async (m) => {
      resetTeam(m);
      await m.open('/manage/team?tab=requests');
      await m.wait({ keyPrefix: 'team.approve.' });
      await settle(m);
      await m.shot('request', '**Requests** shows who asked to join, with their note. Select **Approve** to take them on, or **Decline**.', { ring: { keyPrefix: 'team.approve.', i: 0 } });
      await m.tap({ keyPrefix: 'team.approve.', i: 0 });
      await settle(m, 1000);
      await m.shot('approve', 'Choose the role and office they join with, and confirm. They are told, and the company appears in their **My companies**.');
      await m.back();
      await m.home();
    },
  ),

  flow(
    'add',
    'Add or invite a colleague',
    { who: 'Company admins', as: 'companyAdmin' },
    async (m) => {
      resetTeam(m);
      await m.open('/manage/team');
      await m.wait('team.add');
      await m.tap('team.add');
      await m.wait('add.search');
      await m.enter('add.search', 'Pooja', { keep: true });
      await settle(m);
      await m.shot('search', '**Add someone on ICR** finds a colleague who already has an ICR account. Search by name and select them.', { keyboard: true });
      await m.tap({ keyPrefix: 'add.hit.', i: 0 }, { ensure: false });
      await settle(m, 1000);
      await m.shot('add', 'Choose their role and office and select **Ask them to join**. Nothing changes for them until they accept: the request waits under **Pending**, where you can cancel it.');
      await m.back();
      await m.home();
      await m.open('/manage/team');
      await m.wait('team.invite');
      await m.tap('team.invite');
      await m.wait('invite.email');
      await m.enter('invite.email', 'kiran.desai@meridianfs.example');
      await settle(m, 1500);
      await m.shot('invite', '**Invite by email** is for someone who is not on ICR yet, and the only way to make someone an admin. Enter their work email, choose the role, and send. The invitation holds one of your plan’s seats until they answer.');
      await m.back();
      await m.home();
    },
  ),

  flow(
    'inbox',
    'The company’s messages',
    { who: 'Company admins and team members', as: 'companyAdmin' },
    async (m) => {
      await m.tab('home');
      await m.tap('home-messages');
      await m.wait('compose');
      await settle(m);
      await m.shot('inbox', 'Messages sent to the company arrive in its inbox, which every team member with that topic can read and answer. Select **Inbox options** at the top to switch between your own messages and the company’s.', { ring: 'inbox-options' });
      await m.tap('inbox-options');
      await settle(m, 900);
      await m.shot('switch', 'Choose the inbox to read. A reply sent from the company’s inbox goes out in the company’s name.');
      await m.back();
      await m.home();
    },
  ),
]);
