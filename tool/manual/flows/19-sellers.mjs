import { defineManual, flow } from '../kit.mjs';

const settle = async (m, ms = 1500) => {
  await m.pause(ms);
  await m.idle();
};

export default defineManual('19-sellers', 'Sellers', [
  flow(
    'menu',
    'Selling for your company',
    {
      who: 'Sellers and company admins of a company that sells',
      as: 'seller',
      intro: 'A seller answers what buyers ask for: enquiries, RFQs and requests for a quote sent to the company. The company needs a supplier listing first; its admin creates one with **Start selling**.',
    },
    async (m) => {
      await m.tab('home');
      await m.tap('home-avatar');
      await m.wait('workspace-company');
      await m.tap('workspace-company');
      await m.wait('workspace-company-0');
      await m.shot('menu', 'Open your profile menu and select **Company**. **Bid for enquiries & RFQs** opens the work you can answer; **View enquiries & RFQs** is what your own company has posted.', { ring: { text: 'Bid for enquiries & RFQs' } });
      await m.back();
    },
  ),

  flow(
    'find-work',
    'Find work',
    { who: 'Sellers', as: 'seller' },
    async (m) => {
      await m.open('/manage/bids');
      await m.wait({ text: 'Find work' });
      await settle(m);
      await m.shot('board', '**Find work** lists open requirements. **Recommended** are the ones that match what your company sells, with a match score; **Invited** are the ones a buyer asked you to answer. **Sort** and **Closing soon** order the list.');
      await m.tap({ text: 'Access control upgrade: head office' });
      await settle(m, 1800);
      await m.shot('opportunity', 'Select a requirement to read it: what the buyer needs, where, the budget if they gave one, and the date replies are due.');
      if (await m.exists('respond-now')) {
        await m.scrollTo('respond-now', { align: 0.7 });
        await m.shot('respond', 'The reply form is on the same page; **Reply now** jumps to it. An enquiry takes a reply; an RFQ takes a formal bid with your price and how you meet its criteria.', { ring: 'respond-now' });
        await m.tap('respond-now');
        await settle(m, 1200);
      }
      if (await m.exists('reply-amount')) {
        await m.enter('reply-amount', '785000');
        await m.enter('reply-message', 'We can start within ten days with a trained crew of eight and a site supervisor. The price covers manpower, machines and consumables; glass above 12 m is done by rope access with our own certified team.');
        await m.shot('reply', 'Say how you would do the work, add an indicative price and a lead time, attach photos or documents if they help, and select **Send reply**. A reply to an enquiry does not use your plan’s monthly bids; a bid on an RFQ does.', { ring: 'reply-send' });
      }
      await m.home();
    },
  ),

  flow(
    'my-bids',
    'Follow your replies',
    { who: 'Sellers', as: 'seller' },
    async (m) => {
      await m.open('/manage/bids');
      await m.wait({ text: 'Find work' });
      await settle(m);
      await m.tap({ contains: 'My Bids' });
      await settle(m, 1500);
      await m.tap({ contains: 'Won' });
      await settle(m, 1200);
      await m.shot('bids', '**My Bids** sorts every reply and bid you sent by where it stands: **Submitted**, **Shortlisted**, **Won** and **Archived**. Open one to read it, change or withdraw it while it is still open, or message the buyer.');
      await m.home();
    },
  ),

  flow(
    'start-selling',
    'If your company does not sell yet',
    { who: 'Company admins', as: 'newcomer' },
    async (m) => {
      await m.open('/manage/bids');
      await settle(m, 2000);
      await m.shot('gate', 'A company with no supplier listing sees this instead of the work board. Its admin selects **Start selling**: the listing is made from the company’s details in one step, and the company appears in the Marketplace.');
      await m.home();
    },
  ),

  flow(
    'rfq-bid',
    'Answer an RFQ',
    { who: 'Sellers', as: 'seller', intro: 'An RFQ is a formal process. The buyer may first check that suppliers qualify, then ask the shortlisted ones for a detailed bid.' },
    async (m) => {
      await m.open('/manage/bids');
      await m.wait({ text: 'Find work' });
      await settle(m);
      await m.scrollTo({ text: 'Sunrise Facilities: Integrated FM RFQ' }, { align: 0.4 });
      await m.tap({ text: 'Sunrise Facilities: Integrated FM RFQ' });
      await settle(m, 2000);
      await m.shot('rfq', 'An RFQ’s page shows its stages and their dates, the items the buyer wants priced, and the criteria suppliers must meet.');
      await m.swipe(-600);
      await m.swipe(-400);
      await m.idle();
      await m.shot('respond', 'Further down is what the buyer asks of you at this stage: your company’s years in business, turnover, team size and compliances for pre-qualification, then your prices once you are shortlisted.');
      await m.home();
    },
  ),
]);
