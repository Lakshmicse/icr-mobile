import { defineManual, flow } from '../kit.mjs';

const settle = async (m, ms = 1500) => {
  await m.pause(ms);
  await m.idle();
};

export default defineManual('20-buyers', 'Buyers', [
  flow(
    'menu',
    'Buying for your company',
    {
      who: 'Buyers, sellers and company admins',
      as: 'buyer',
      intro: 'A buyer posts what the company needs and chooses among the suppliers who answer. An **enquiry** is a quick way to get prices; an **RFQ** is a formal process with bids to compare.',
    },
    async (m) => {
      await m.tab('home');
      await m.tap('home-avatar');
      await m.wait('workspace-company');
      await m.tap('workspace-company');
      await m.wait('workspace-company-0');
      await m.shot('menu', 'Open your profile menu. **Company → View enquiries & RFQs** is what your company has posted. **Marketplace → Post a requirement** starts a new one.', { ring: { text: 'View enquiries & RFQs' } });
      await m.back();
    },
  ),

  flow(
    'post',
    'Post a requirement',
    { who: 'Buyers, sellers and company admins', as: 'buyer' },
    async (m) => {
      await m.open('/rfq/new');
      await m.wait('send');
      await settle(m);
      await m.enter('contact-phone', '9845098450');
      for (let i = 0; i < 2; i++) await m.swipe(600);
      await m.shot('kind', 'Select **Post a requirement**. **Posting for** shows the company. Choose **Enquiry** or **RFQ**, and check the contact details suppliers will reply to.');
      await m.scrollTo('facility-field', { align: 0.25 });
      await m.tapIn('facility-field', 0.5, 0.6);
      await m.pause(900);
      await m.tap({ text: 'IT & ITES' }, { ensure: false });
      await m.pause(600);
      await m.scrollTo('places-add', { align: 0.4 });
      await m.tap('places-add');
      await m.wait('place-search');
      await m.enter('place-search', 'Pune', { keep: true });
      await settle(m, 1500);
      await m.tap({ keyPrefix: 'place-option-', i: 0 }, { ensure: false });
      await m.pause(600);
      if (await m.exists('place-done')) await m.tap('place-done', { ensure: false });
      await m.pause(600);
      await m.scrollTo('category-field', { align: 0.45 });
      await m.tapIn('category-field', 0.5, 0.6);
      await m.pause(900);
      await m.tap({ text: 'Integrated Facility Management' }, { ensure: false });
      await m.pause(1200);
      if (await m.exists('subcategory-field')) {
        await m.scrollTo('subcategory-field', { align: 0.45 });
        await m.tapIn('subcategory-field', 0.5, 0.6);
        await m.pause(900);
        if (await m.exists({ contains: 'Housekeeping' })) await m.tap({ contains: 'Housekeeping', i: 0 }, { ensure: false });
        else await m.back();
        await m.pause(900);
      }
      await m.scrollTo('facility-field', { align: 0.2 });
      await m.shot('where', 'Say what kind of site it is and add every city the work covers. Then choose the service; suppliers are matched by it.');
      await m.scrollTo('text', { align: 0.3 });
      await m.enter('text', 'Daily housekeeping for our 1.2 lakh sq ft office in Baner, Pune: two shifts, six days a week, about 900 people on site. Includes washrooms, pantry, façade glass up to the second floor, and consumables. We want to start on 1 January.');
      await m.shot('describe', 'Describe what you need in your own words. The list under it shows what suppliers usually ask; covering it saves a round of questions. You can attach photos or a scope document.', { ring: 'send' });
      await m.tap('send');
      await settle(m, 1500);
      await m.shot('review', 'Select **Send enquiry**. The app shows a summary to check. Nothing is shared until you confirm.');
      if (await m.exists('review-confirm')) {
        await m.tap('review-confirm');
        await settle(m, 2500);
        await m.shot('posted', 'Confirm, and the requirement is posted. Matching suppliers are told at once, and their replies come to **My RFQ’s** and your notifications.');
      }
      await m.home();
    },
  ),

  flow(
    'replies',
    'Compare replies and choose a supplier',
    { who: 'Buyers, sellers and company admins', as: 'buyerDesign' },
    async (m) => {
      await m.open('/manage/requirements');
      await m.wait({ text: 'My RFQ’s' }, 8000).catch(() => {});
      await settle(m);
      await m.shot('mine', '**My RFQ’s** lists your company’s requirements with their replies. The chips keep live ones, drafts, awarded and ended.');
      await m.tap({ text: 'CCTV refresh: 48 cameras, Pune campus', i: 0 });
      await settle(m, 2000);
      await m.shot('requirement', 'Open a requirement to manage it and read its replies. Each reply shows the supplier, the price and the lead time. **Message** asks a question, **Shortlist** keeps the reply in the running, **Decline** turns it down, and **Select** chooses that supplier.');
      if (await m.exists({ keyPrefix: 'bid-more-' })) {
        await m.scrollTo({ keyPrefix: 'bid-more-', i: 0 }, { align: 0.4 });
        await m.shot('reply', 'Each reply shows the supplier, the price and the lead time. Message the supplier with a question, shortlist the reply, or choose it.', { ring: { keyPrefix: 'bid-more-', i: 0 } });
        await m.tap({ keyPrefix: 'bid-more-', i: 0 });
        await settle(m, 900);
        await m.shot('choose', 'The three dots on a reply open what you can do with it. Choosing a supplier closes the requirement to the others, who are told it has been decided.');
        await m.back();
      }
      await m.home();
      await m.open('/manage/requirements');
      await settle(m, 1500);
      await m.scrollTo({ text: 'Sunrise Facilities: Fire alarm upgrade RFQ' }, { align: 0.4 });
      await m.tap({ text: 'Sunrise Facilities: Fire alarm upgrade RFQ' });
      await settle(m, 2000);
      if (await m.exists('compare')) {
        await m.scrollTo('compare', { align: 0.5 });
        await m.tap('compare');
        await settle(m, 1500);
        await m.shot('compare', 'On an RFQ, **Compare** sets the bids side by side: price, lead time, and how each supplier meets your criteria.');
        await m.back();
      } else {
        await m.shot('rfq', 'An RFQ moves through stages, shown on its page: pre-qualification, shortlist, quotes, evaluation and award. Its bids are listed below with their prices, and can be sorted by price.');
      }
      await m.home();
    },
  ),

  flow(
    'rfq',
    'Post an RFQ',
    { who: 'Buyers, sellers and company admins', as: 'buyer', intro: 'An RFQ asks for the same things as an enquiry and adds what a formal comparison needs.' },
    async (m) => {
      await m.open('/rfq/new');
      await m.wait('send');
      await settle(m);
      await m.tap('kind-rfq');
      await settle(m, 1000);
      await m.shot('kind', 'On **Post your requirement**, choose **RFQ**. The form grows the parts a formal process needs.', { ring: 'kind-rfq' });
      await m.scrollTo('criteria-toggle', { align: 0.3 });
      await m.shot('criteria', 'Besides the place, the service and the description, an RFQ takes the items to be priced, a budget, the dates of each stage, and the criteria a supplier must meet to take part.');
      await m.back();
      await settle(m, 800);
      if (await m.exists({ text: 'Discard' })) await m.tap({ text: 'Discard' });
      await m.home();
    },
  ),

  flow(
    'invite',
    'Invite suppliers and select one',
    { who: 'Buyers, sellers and company admins', as: 'buyerDesign' },
    async (m) => {
      await m.open('/manage/requirements');
      await settle(m, 1500);
      await m.shot('invite-button', 'On a requirement in **My RFQ’s**, **Invite suppliers** asks particular suppliers to answer.', { ring: { text: 'Invite suppliers', i: 0 } });
      await m.tap({ text: 'Invite suppliers', i: 0 });
      await settle(m, 1500);
      await m.shot('invite', 'The requirement opens on **Suppliers**: who was invited and how each answered. **Invite companies** adds more; each one is told, and the requirement appears under **Invited** on their work board.');
      await m.back();
      await m.home();
      await m.open('/manage/requirements');
      await settle(m, 1500);
      await m.tap({ text: 'CCTV refresh: 48 cameras, Pune campus', i: 0 });
      await settle(m, 2000);
      await m.tap({ text: 'Select' }, { ensure: true });
      await settle(m, 1200);
      await m.shot('select', 'On a reply, **Select** chooses that supplier. The app asks you to confirm, because the other suppliers are then told the requirement has been decided.');
      await m.back();
      await m.home();
    },
  ),
]);
