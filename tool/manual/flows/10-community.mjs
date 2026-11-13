import { defineManual, flow } from '../kit.mjs';

const settle = async (m, ms = 1500) => {
  await m.pause(ms);
  await m.idle();
};

export default defineManual('10-community', 'Chapters, councils, events and the library', [
  flow(
    'chapters',
    'Regional chapters',
    { who: 'Every member', as: 'member', intro: 'A chapter is ICR in your city: local members, meetups and a committee. Open it from **Discover**.' },
    async (m) => {
      await m.tab('home');
      await m.tap({ text: 'Discover', last: true });
      await m.wait({ text: 'Chapters' });
      await m.tap({ text: 'Chapters' }, { ensure: false });
      await m.wait({ text: 'Regional Chapters' });
      await settle(m);
      await m.shot('list', 'Select **Discover**, then **Chapters**. **Your Chapters** are the ones you joined; below are the coming meetups and every chapter, with search.');
      await m.tap({ text: 'Open chapter', i: 0 });
      await settle(m, 1800);
      await m.shot('chapter', 'A chapter’s page shows what it does, its leadership, members, events and resources; the row of tabs jumps to each part. Join the chapter from this page. The badge under its name shows your place in it.');
      await m.swipe(-600);
      await m.swipe(-300);
      await m.idle();
      await m.shot('meetups', 'Under **Events & meetups**, select **RSVP** to reserve your place at a meetup. A full meetup offers the waiting list.');
      await m.home();
    },
  ),

  flow(
    'councils',
    'Councils',
    { who: 'Every member', as: 'member', intro: 'A council is a standing group of peers on one subject, such as workplace strategy or sustainability, that meets in roundtables.' },
    async (m) => {
      await m.open('/councils');
      await m.wait({ text: 'Councils' });
      await settle(m);
      await m.shot('list', 'Select **Discover**, then **Councils**. **Your Joined Councils** come first, then the coming roundtables, then every council by subject.');
      await m.scrollTo({ text: 'Open Member Lounge', i: 0 }, { align: 0.6 });
      await m.shot('card', 'Each council’s card shows its chair, its subject and its next roundtable. A council you belong to is marked **Joined**; on any other, take a seat to join.', { ring: { text: 'Open Member Lounge', i: 0 } });
      await m.tap({ text: 'Open Member Lounge', i: 0 });
      await settle(m, 1800);
      await m.shot('council', '**Open Member Lounge** shows who else has a seat, the council’s shared documents and its news.');
      await m.home();
    },
  ),

  flow(
    'events',
    'Events',
    { who: 'Every member', as: 'member' },
    async (m) => {
      await m.open('/events');
      await m.wait({ text: 'All Events' });
      await settle(m);
      await m.shot('board', 'Select **Discover**, then **Events**. The chips keep one kind: conferences, webinars and more. **My Schedule** is what you have a place at, and **CPD Earned** counts the credits your events gave you.');
      await m.tap({ text: 'Future of AI in Facility Management', i: 0 });
      await settle(m, 1800);
      await m.shot('event', 'Select an event to read it: when and where, who speaks, and what it costs. **Register Now** takes your place, and **Add to calendar** puts it in your phone’s calendar. Your pass, with its QR code, appears on the event once you have a place.');
      await m.home();
    },
  ),

  flow(
    'library',
    'The Digital Library',
    { who: 'Every member', as: 'member', intro: 'The library is where members share working documents: SOPs, checklists, templates, reports.' },
    async (m) => {
      await m.open('/documents');
      await m.wait({ text: 'Digital Library' });
      await settle(m);
      await m.shot('list', 'Select **Discover**, then **Digital Library**. Search, or narrow by kind, category and format.', { ring: 'library-upload' });
      await m.tap({ text: 'Lift rescue drill SOP' });
      await settle(m, 2500);
      await m.shot('document', 'Select a document to open its page. **Preview** reads it in the app, **Download** saves the file to your phone, **Share** sends its link, and **Report** tells ICR about a document that should not be there.', { allowBusy: true });
      await m.home();
      await m.open('/documents');
      await m.wait('library-upload');
      await m.tap('library-upload');
      await m.wait('upload-title');
      await m.enter('upload-title', 'Monthly DG set load-test checklist');
      await m.enter('upload-description', 'A one-page checklist for the monthly load test of standby diesel generators, with the readings to record.');
      await m.shot('upload', 'To share a document of your own, select **Upload**. Give it a title and a description, choose its category, and pick the file from your phone.');
      await m.home();
    },
  ),

  flow(
    'get-involved',
    'Get involved',
    { who: 'Every member', as: 'member' },
    async (m) => {
      await m.open('/get-involved');
      await m.wait({ text: 'Get Involved' });
      await settle(m);
      await m.shot('page', '**Get Involved** lists the ways to give time to ICR: chapter committees, mentoring, speaking, reviewing standards. **Your CPD** shows the hours you have earned.', { ring: { text: 'Volunteer with ICR' } });
      await m.tap({ text: 'Volunteer with ICR' });
      await settle(m, 1500);
      await m.shot('apply', 'Select **Volunteer with ICR**, choose what you would like to do, say a little about yourself, and send. ICR’s team writes back.');
      await m.home();
    },
  ),
]);
