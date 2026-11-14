import { defineManual, flow } from '../kit.mjs';

/** The Marketplace tab from its top. */
const marketTab = async (m) => {
  await m.tab('marketplace');
  for (let i = 0; i < 3; i++) await m.swipe(600);
  await m.idle();
};

/** Opens Vikasha Aero Tech's page from the Marketplace search: a supplier with services, offices and certificates. */
const openSupplier = async (m) => {
  await marketTab(m);
  await m.tap('market-search');
  await m.pause(900);
  await m.enter({ type: 'TextField', i: 0 }, 'Vikasha', { keep: true });
  await m.pause(1500);
  await m.idle();
  await m.tap({ contains: 'Vikasha Aero Tech', i: 0 }, { ensure: false });
  await m.wait('request-quote');
};

export default defineManual('09-marketplace', 'Marketplace', [
  flow(
    'browse',
    'Find a supplier',
    { who: 'Every member', as: 'member', intro: 'The Marketplace lists companies that sell facility services and products. A tick beside a name means ICR has verified the company.' },
    async (m) => {
      await marketTab(m);
      await m.shot('tab', 'Open the **Marketplace** tab. Search for a supplier, a service or a requirement at the top. **Filters**, **Sort** and **Verified only** narrow the list.', { ring: 'market-search' });
      await m.tap('market-search');
      await m.pause(900);
      await m.enter({ type: 'TextField', i: 0 }, 'housekeeping', { keep: true });
      await m.pause(1500);
      await m.idle();
      await m.shot('search', 'As you type, the app suggests categories and suppliers. Select one, or search for the words as typed.', { keyboard: true });
      await m.home();
      await marketTab(m);
      await m.tap({ contains: 'Filters' });
      await m.pause(900);
      await m.idle();
      await m.shot('filters', '**Filters** keep suppliers by trust level, from **Verified** up to **Elite**, and by category. Select **Show suppliers**.');
      await m.back();
    },
  ),

  flow(
    'supplier',
    'Read a supplier’s page',
    { who: 'Every member', as: 'member' },
    async (m) => {
      await openSupplier(m);
      await m.shot('overview', 'Select a supplier to open its page. **Overview** shows what the company does, its offices and its ratings. At the top you can save the supplier or share its page.', { ring: 'supplier-save' });
      await m.tap({ keyPrefix: 'tab-', i: 1 });
      await m.pause(1200);
      await m.idle();
      await m.shot('offerings', '**Products & services** lists what it sells. Select an item for its details and price.');
      await m.tap({ keyPrefix: 'tab-', i: 2 });
      await m.pause(1200);
      await m.idle();
      await m.shot('proofs', '**Compliances & Proofs** shows the certificates and registrations the company has given ICR.');
      await m.home();
    },
  ),

  flow(
    'quote',
    'Ask a supplier for a quote',
    { who: 'Every member', as: 'member', intro: 'A request for a quote goes straight to that one supplier. To ask several suppliers at once, post a requirement instead.' },
    async (m) => {
      await openSupplier(m);
      await m.shot('button', 'On the supplier’s page, select **Request for Quote (RFQ)**. The speech bubble beside it writes to the supplier without a formal request.', { ring: 'request-quote' });
      await m.tap('request-quote');
      await m.pause(1500);
      await m.idle();
      await m.enter('quote-scope', 'Daily housekeeping, 60,000 sq ft office, Whitefield');
      await m.enter('quote-notes', 'Two shifts, six days a week, consumables included. Site visit possible any weekday morning.');
      await m.shot('form', 'Describe the **project scope**, choose a **target timeline** and add notes, then select **Submit quote request**. The request goes privately to this supplier, who answers in your messages.', { ring: { text: 'Submit quote request' } });
      await m.home();
    },
  ),

  flow(
    'categories',
    'Browse by category',
    { who: 'Every member', as: 'member' },
    async (m) => {
      await marketTab(m);
      await m.tap({ contains: 'Filters' });
      await m.wait({ text: 'Browse all' });
      await m.shot('open', 'In **Filters** on the Marketplace tab, select **Browse all** beside **Category**.', { ring: { text: 'Browse all' } });
      await m.tap({ text: 'Browse all' }, { ensure: false });
      await m.pause(1500);
      await m.idle();
      await m.shot('categories', 'The category browser groups everything sold on ICR. Select a category for its sub-categories, then the suppliers, products and services in it.');
      await m.home();
    },
  ),

  flow(
    'requirements',
    'Requirements',
    {
      who: 'Every member',
      as: 'member',
      intro: 'A requirement is a need a buyer posts for suppliers to answer: an enquiry for a quick price, or an RFQ with formal bids. Requirements are posted for a company.',
    },
    async (m) => {
      await m.open('/rfq');
      await m.pause(1500);
      await m.idle();
      await m.shot('board', 'The **Requirements** board lists what buyers are looking for. Select one to read it.');
      await m.home();
      await marketTab(m);
      await m.tap({ contains: 'Post RFQ' });
      await m.pause(1800);
      await m.idle();
      await m.shot('post', 'On the Marketplace tab, select **Post RFQ** to post a requirement of your own. A requirement is posted for a company you belong to: **Posting for** shows which. Choose **Enquiry** for a quick price or **RFQ** for formal bids. The Buyers chapter walks through the whole form.');
      await m.home();
    },
  ),
]);
