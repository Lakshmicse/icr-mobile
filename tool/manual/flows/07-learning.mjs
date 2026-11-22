import { defineManual, flow } from '../kit.mjs';

const FOUNDATION = 'cmwd1qjcc00lfitpvzieyyz7f'; // Capital Planning, Foundation level
const COURSE = 'design-lj-course-cals';

/** Puts the member back to before they opened and sat the Foundation paper in an earlier run. */
function resetPaper(m) {
  const me = m.sql(`select id from "User" where email = '${m.person('member').email}'`);
  m.sql(`delete from "LearningCertificate" where "userId" = '${me}' and "certificateId" not like 'ICR-CP-2026-DSGNLF%'`);
  m.sql(`delete from "LearningAttempt" where "userId" = '${me}' and id not like 'design-lf-%'`);
  m.sql(`delete from "LearningPaperUnlock" where "userId" = '${me}'`);
}

export default defineManual('07-learning', 'Learning', [
  flow(
    'hub',
    'The Learning tab',
    { who: 'Every member', as: 'member', intro: 'Learning brings together courses from ICR and its partner institutes, papers that test what you know, and study aids.' },
    async (m) => {
      await m.tab('learning');
      await m.swipe(600);
      await m.wait('catalogue-assessment');
      await m.shot(
        'tab',
        'Open the **Learning** tab. The **Catalogue** row opens **Assess your knowledge**, **Mock Exams**, **Flash Cards** and the **Knowledge Centre**. **My courses** is what you are enrolled in or have started.',
      );
    },
  ),

  flow(
    'course',
    'Read a course and take a place',
    { who: 'Every member', as: 'member' },
    async (m) => {
      await m.open('/learning/courses');
      await m.wait({ contains: 'Certificate in Advanced' });
      await m.shot('mine', 'Open your profile menu, select **Learning**, then **My courses**. The chips along the top switch between your courses, mock exams and certificates.', { ring: { contains: 'Certificate in Advanced' } });
      await m.tap({ contains: 'Certificate in Advanced' });
      await m.wait('place-status');
      await m.shot(
        'course',
        'Select a course to open it. Choose how it is taught, then a date and place. Your place shows as **Confirmed** once ICR or the institute has accepted it; **Withdraw** gives it back.',
      );
      await m.swipe(-600, { at: [200, 500] });
      await m.swipe(-560, { at: [200, 500] });
      await m.shot('more', 'Further down are the overview, the outline and who should attend. **Download brochure** saves the brochure, **Ask the institute** sends a question, and **Take this course as in-house** asks for a run for your own team.');
      await m.home();
    },
  ),

  flow(
    'assess',
    'Open a paper and sit it',
    {
      who: 'Every member',
      as: 'member',
      intro: 'Assess your knowledge papers come in levels. A level opens with your plan, with ICR credits, or by paying for it. Passing earns a certificate.',
    },
    async (m) => {
      resetPaper(m);
      await m.become('member');
      await m.open('/learning/assessment');
      await m.wait({ text: 'Capital Planning' });
      await m.shot('list', 'On the Learning tab, select **Assess your knowledge**, then a subject.', { ring: { text: 'Capital Planning' } });
      await m.tap({ text: 'Capital Planning' });
      await m.wait(`paper-${FOUNDATION}`);
      await m.scrollTo(`paper-${FOUNDATION}`, { align: 0.3 });
      await m.shot(
        'levels',
        'Each level shows its questions, time and pass mark, and your best score so far. A locked level opens with **Pay now** or, if you have enough ICR credits, **Redeem**.',
        { ring: { text: 'Redeem', i: 0 } },
      );
      await m.tap({ text: 'Redeem', i: 0 }, { ensure: false });
      await m.wait({ contains: 'ICR credits for' });
      await m.shot('redeem', 'The app tells you how many credits the level takes and how many you will have left. Confirm, and the level is yours for good.');
      await m.tap({ contains: 'Redeem 10 credits' }, { ensure: false });
      await m.wait({ text: 'Retake' });
      await m.tap({ text: 'Retake' }, { ensure: false });
      await m.pause(1500);
      await m.idle();
      // A sitting an earlier run left unfinished is kept on the phone: start afresh.
      if (await m.exists({ text: 'Discard it and start over' })) {
        await m.tap({ text: 'Discard it and start over' }, { ensure: false });
        await m.pause(800);
        if (await m.exists({ text: 'Discard' })) await m.tap({ text: 'Discard' }, { ensure: false });
      }
      await m.wait({ text: 'Take test' });
      await m.shot('brief', 'Select **Start** on the level (**Retake** if you have sat it before). Read the rules, then select **Take test**. The timer starts at once.', { ring: { text: 'Take test' } });
      await m.tap({ text: 'Take test' }, { ensure: false });
      await m.wait('question-0');
      const answers = JSON.parse(
        m.sql(`select json_agg(json_build_object('q', prompt, 'a', options->>(("correctIndexes")[1]))) from "LearningQuestion" where "paperId" = '${FOUNDATION}' and active`),
      );
      for (let i = 0; i < 10; i++) {
        let hit = null;
        for (const qa of answers) {
          if (await m.exists({ text: qa.q })) {
            hit = qa;
            break;
          }
        }
        if (!hit) throw new Error(`question ${i + 1}: not one of the paper's questions`);
        // The ninth is left wrong on purpose: a result of 90% reads like a real sitting.
        const wrong = i === 8;
        if (!wrong) await m.tap({ text: hit.a }, { ensure: false });
        if (i === 0) {
          await m.shot('question', 'Select your answer. **Next** moves on, **Review** marks a question to come back to, and the numbers at the top jump to any question. The time left is at the top.');
        }
        if (i < 9) await m.tap({ text: 'Next' }, { ensure: false, idle: false, after: 350 });
      }
      await m.tap({ text: 'Finish' }, { ensure: false });
      await m.pause(1000);
      await m.shot('finish', 'When you are done, select **Finish**. The overview shows what you answered, skipped and flagged, and lets you go back to any question. Select **Submit test** to hand it in.');
      await m.tap({ contains: 'Submit' }, { ensure: false });
      await m.pause(2500);
      await m.idle();
      await m.shot('result', 'Your result appears at once: your score, the number right and wrong, and the time you took. A pass issues the certificate. **Review answers** shows each question with the right answer and why.');
      m.state.sat = true;
    },
  ),

  flow(
    'results',
    'Your attempts and certificates',
    { who: 'Every member', as: 'member' },
    async (m) => {
      await m.open('/learning/attempts');
      await m.pause(1200);
      await m.idle();
      await m.shot('attempts', 'Open your profile menu, select **Learning**, then **My attempts**. Every sitting is listed with its score. Select one to see which answers were right.');
      await m.home();
      await m.open('/learning/certificates');
      await m.pause(1200);
      await m.idle();
      await m.shot('certificates', '**My certificates** holds each certificate you earned. **View certificate** opens it to download, **Share** sends its link, and anyone can check its number against ICR’s register.');
      await m.home();
    },
  ),

  flow(
    'mock-tests',
    'Mock exams',
    { who: 'Every member', as: 'member' },
    async (m) => {
      await m.open('/learning/mock-tests');
      await m.pause(1200);
      await m.idle();
      await m.shot('mocks', '**Mock Exams** are practice sets for industry certifications. They open and are sat the same way as the papers above.');
      await m.home();
    },
  ),

  flow(
    'study',
    'Flash cards and the Knowledge Centre',
    { who: 'Every member', as: 'studyCards', intro: 'Flash cards are short question-and-answer cards for revising a subject. The Knowledge Centre is a reference of formulas.' },
    async (m) => {
      await m.tab('learning');
      await m.swipe(600);
      await m.tap('catalogue-flashCards');
      await m.pause(1500);
      await m.idle();
      await m.shot('decks', 'On the Learning tab, select **Flash Cards**. Each deck belongs to a subject. A deck that goes with a course opens when the course is open to you.');
      await m.tap({ text: 'Study', i: 0 });
      await m.pause(1500);
      await m.idle();
      await m.shot('card', 'Open a deck and select the card to turn it over. Mark it **Got it** or **Still learning**, star the ones to come back to, and shuffle for a different order.');
      await m.home();
      await m.tab('learning');
      await m.swipe(600);
      await m.tap('catalogue-knowledgeCenter');
      await m.pause(1500);
      await m.idle();
      await m.shot('formulas', 'The **Knowledge Centre** lists formulas by subject. Open one for what each term means and a worked example.');
      await m.home();
    },
  ),

  flow(
    'partners',
    'Partner institutes',
    { who: 'Every member', as: 'member' },
    async (m) => {
      await m.open('/learning/partners');
      await m.wait({ keyPrefix: 'institute-' });
      await m.shot('institutes', '**Partner Courses** lists the institutes that teach on ICR. Select one for its courses.', { ring: { keyPrefix: 'institute-', i: 0 } });
      await m.tap({ keyPrefix: 'institute-', i: 0 });
      await m.pause(1500);
      await m.idle();
      await m.shot('institute', 'An institute’s page shows its courses. **Ask the institute** sends it a question; the answer comes to your messages.');
      await m.home();
    },
  ),

  flow(
    'review',
    'Review your answers and open a certificate',
    { who: 'Every member', as: 'member' },
    async (m) => {
      await m.open('/learning/attempts');
      await m.pause(1200);
      await m.idle();
      await m.tap({ contains: 'Capital Planning', i: 0 });
      await m.wait({ text: 'Review answers' });
      await m.shot('result', 'In **My attempts**, select a sitting to see its result again. **Retake test** starts a new sitting.', { ring: { text: 'Review answers' } });
      await m.tap({ text: 'Review answers' });
      await m.pause(1800);
      await m.idle();
      await m.shot('answers', '**Review answers** goes through the paper question by question: your answer, the right one, and why.');
      await m.home();
      await m.open('/learning/certificates');
      await m.wait({ text: 'View certificate' });
      await m.tap({ text: 'View certificate' });
      await m.pause(2500);
      await m.idle();
      await m.shot('certificate', 'In **My certificates**, **View certificate** opens the certificate itself, with its credential number. Pinch to read it closely, **Share** its link, or download it as a PDF further down.');
      await m.home();
    },
  ),

  flow(
    'mock-set',
    'Open a mock exam',
    { who: 'Every member', as: 'member' },
    async (m) => {
      await m.open('/learning/mock-tests');
      await m.wait({ text: 'AEE CBCP' });
      await m.tap({ text: 'AEE CBCP' });
      await m.pause(1800);
      await m.idle();
      await m.shot('sets', 'Select a mock exam to see its sets. Each set opens with your plan, with ICR credits or by paying, and is sat like any other paper.');
      await m.home();
    },
  ),
]);
