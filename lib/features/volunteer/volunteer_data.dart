/// The volunteer opportunities and benefits the Get Involved screen lists: ICR-authored copy, the same
/// as the website's `features/learning/data/volunteering.ts` (the portal has no endpoint for them: the
/// website serves them from the same constants). Role names come from the stakeholder document "ICR
/// Learning & Volunteering tabs v1.0"; the descriptions, responsibilities and time commitments are ICR's.
library;

import 'volunteer_models.dart';

const volunteerRoles = <VolunteerRole>[
  VolunteerRole(
    key: 'chapter-committee-member',
    title: 'Chapter Committee Member',
    description:
        'Help run your local ICR chapter — shaping its programme, growing membership and representing members in your city.',
    responsibilities: [
      'Attend and contribute to chapter committee meetings',
      'Help plan the local events and knowledge calendar',
      'Recruit and welcome new members in your city',
      'Represent member interests to the chapter leadership',
    ],
    commitment: '4–6 hours per month',
    icon: 'Groups',
  ),
  VolunteerRole(
    key: 'chapter-leader',
    title: 'Chapter Leader',
    description: 'Lead a chapter end to end — its strategy, committee, partnerships and standing in the local market.',
    responsibilities: [
      'Set the chapter’s annual plan and objectives',
      'Chair the committee and develop its members',
      'Build local corporate and partner relationships',
      'Report chapter performance to the ICR national council',
    ],
    commitment: '8–10 hours per month',
    icon: 'EmojiEvents',
  ),
  VolunteerRole(
    key: 'industry-council-member',
    title: 'Industry Council Member',
    description: 'Shape ICR’s position on a sector or discipline through a national industry council.',
    responsibilities: [
      'Contribute sector expertise to council agendas',
      'Help produce position papers and industry guidance',
      'Review emerging practice, regulation and technology',
      'Represent the council at ICR forums',
    ],
    commitment: '4 hours per month',
    icon: 'Diversity3',
  ),
  VolunteerRole(
    key: 'subject-matter-expert',
    title: 'Subject Matter Expert (SME)',
    description:
        'Lend deep expertise to certification content, standards work and member questions in your specialism.',
    responsibilities: [
      'Review and contribute to certification curricula',
      'Answer complex member queries in your domain',
      'Advise on standards and best-practice publications',
      'Support research and benchmarking work',
    ],
    commitment: 'Project-based, 3–5 hours per project',
    icon: 'Psychology',
  ),
  VolunteerRole(
    key: 'mentor',
    title: 'Mentor or Coach',
    description: 'Guide an early-career or transitioning professional through a structured ICR mentoring cycle.',
    responsibilities: [
      'Meet your mentee regularly through the cycle',
      'Set development goals and review progress',
      'Share practical career and technical guidance',
      'Provide feedback to the mentoring programme team',
    ],
    commitment: '2 hours per month for 6 months',
    icon: 'Handshake',
  ),
  VolunteerRole(
    key: 'trainer',
    title: 'Trainer / Faculty',
    description: 'Teach on ICR certification programmes, masterclasses and bootcamps as accredited faculty.',
    responsibilities: [
      'Deliver sessions against the approved curriculum',
      'Maintain and update your module content',
      'Assess participant work where applicable',
      'Meet ICR faculty quality standards',
    ],
    commitment: 'Per cohort — typically 8–16 hours',
    icon: 'School',
  ),
  VolunteerRole(
    key: 'speaker',
    title: 'Speaker or Panelist',
    description: 'Share practice and insight at ICR conferences, chapter events and webinars.',
    responsibilities: [
      'Prepare and deliver a session or panel contribution',
      'Work with the events team on content and timing',
      'Engage with attendee questions',
      'Share supporting material for the knowledge library',
    ],
    commitment: 'Per event — 3–5 hours including preparation',
    icon: 'RecordVoiceOver',
  ),
  VolunteerRole(
    key: 'event-volunteer',
    title: 'Conference & Event Volunteer',
    description: 'Support ICR conferences and summits on the ground — registration, sessions, speakers and delegates.',
    responsibilities: [
      'Support registration and delegate services',
      'Assist speakers and session chairs',
      'Help run the event schedule on the day',
      'Gather delegate feedback',
    ],
    commitment: 'Per event — 1–2 days',
    icon: 'EventNote',
  ),
  VolunteerRole(
    key: 'research-contributor',
    title: 'Research Contributor',
    description: 'Contribute to ICR benchmarking studies, surveys and industry research.',
    responsibilities: [
      'Contribute data or case material to studies',
      'Review research methodology and findings',
      'Co-author sections of published research',
      'Present findings to members',
    ],
    commitment: 'Project-based, 5–10 hours per study',
    icon: 'Science',
  ),
  VolunteerRole(
    key: 'knowledge-author',
    title: 'Content & Knowledge Author',
    description: 'Write the guides, templates and case studies that make up the ICR knowledge library.',
    responsibilities: [
      'Author practical guidance for practitioners',
      'Develop templates and checklists members can use',
      'Keep published content current',
      'Work with editors through review cycles',
    ],
    commitment: 'Project-based, 4–8 hours per piece',
    icon: 'Article',
  ),
  VolunteerRole(
    key: 'certification-reviewer',
    title: 'Certification Assessor / Reviewer',
    description: 'Assess candidate work and review certification content to keep ICR credentials rigorous.',
    responsibilities: [
      'Assess capstone projects and candidate submissions',
      'Review examination items for accuracy and fairness',
      'Contribute to standard-setting for pass marks',
      'Maintain assessor calibration',
    ],
    commitment: '4–6 hours per assessment window',
    icon: 'FactCheck',
  ),
  VolunteerRole(
    key: 'awards-jury',
    title: 'Awards Jury Member',
    description: 'Judge ICR industry awards, recognising excellence across the profession.',
    responsibilities: [
      'Review and score award submissions',
      'Participate in jury deliberation',
      'Uphold judging criteria and impartiality',
      'Provide feedback for finalists where requested',
    ],
    commitment: 'Annual — 8–10 hours per cycle',
    icon: 'Star',
  ),
  VolunteerRole(
    key: 'standards-committee',
    title: 'Standards & Best Practices Committee Member',
    description: 'Develop the standards and best-practice guidance ICR publishes for the profession.',
    responsibilities: [
      'Draft and review standards documents',
      'Consult members and industry on drafts',
      'Track regulatory and international standards developments',
      'Approve final publications',
    ],
    commitment: '4 hours per month',
    icon: 'Balance',
  ),
  VolunteerRole(
    key: 'student-chapter-mentor',
    title: 'Student Chapter Mentor',
    description: 'Support a student chapter and bring the next generation into the profession.',
    responsibilities: [
      'Guide student chapter activity and leadership',
      'Arrange site visits and industry exposure',
      'Advise students on career pathways',
      'Connect students to ICR opportunities',
    ],
    commitment: '3–4 hours per month',
    icon: 'MenuBook',
  ),
  VolunteerRole(
    key: 'community-ambassador',
    title: 'Community Ambassador',
    description: 'Grow and energise the ICR community online and in your local market.',
    responsibilities: [
      'Welcome and orient new members',
      'Spark and moderate community discussion',
      'Surface member needs to the ICR team',
      'Champion ICR at industry gatherings',
    ],
    commitment: '2–4 hours per month',
    icon: 'Forum',
  ),
  VolunteerRole(
    key: 'innovation-advisor',
    title: 'Innovation & Technology Advisor',
    description: 'Advise ICR on emerging workplace technology, PropTech and AI in corporate real estate.',
    responsibilities: [
      'Track emerging technology relevant to members',
      'Advise on technology content and curricula',
      'Evaluate PropTech developments for the community',
      'Contribute to innovation forums',
    ],
    commitment: '3 hours per month',
    icon: 'SmartToy',
  ),
  VolunteerRole(
    key: 'esg-champion',
    title: 'ESG & Sustainability Champion',
    description: 'Drive the sustainability agenda across ICR programmes, chapters and content.',
    responsibilities: [
      'Champion ESG practice within your chapter',
      'Contribute to sustainability content and events',
      'Share decarbonisation case studies',
      'Support ICR sustainability commitments',
    ],
    commitment: '3–4 hours per month',
    icon: 'EnergySavingsLeaf',
  ),
  VolunteerRole(
    key: 'membership-ambassador',
    title: 'Membership Ambassador',
    description: 'Help grow ICR membership and make sure new members get value quickly.',
    responsibilities: [
      'Introduce ICR to prospective members',
      'Onboard and check in with new members',
      'Gather membership feedback',
      'Represent ICR at professional networks',
    ],
    commitment: '2–3 hours per month',
    icon: 'Handshake',
  ),
  VolunteerRole(
    key: 'corporate-partnership-volunteer',
    title: 'Corporate Partnership Volunteer',
    description: 'Build relationships between ICR and corporate organisations, sponsors and partners.',
    responsibilities: [
      'Identify and open corporate partnership opportunities',
      'Support partner engagement and events',
      'Coordinate corporate membership conversations',
      'Maintain partner relationships over time',
    ],
    commitment: '3–5 hours per month',
    icon: 'Business',
  ),
  VolunteerRole(
    key: 'young-professionals-committee',
    title: 'Young Professionals Committee Member',
    description: 'Shape ICR’s programme for early-career professionals entering CRE and FM.',
    responsibilities: [
      'Plan events and content for young professionals',
      'Build peer networks across chapters',
      'Advocate early-career member needs',
      'Support entry pathways into the profession',
    ],
    commitment: '3 hours per month',
    icon: 'Groups',
  ),
];

const volunteerBenefits = <VolunteerBenefit>[
  VolunteerBenefit(
    title: 'Leadership experience',
    description: 'Chair committees and lead programmes — experience that transfers straight into your career.',
    icon: 'EmojiEvents',
  ),
  VolunteerBenefit(
    title: 'Professional recognition',
    description: 'Recognition across the ICR network for the contribution you make to the profession.',
    icon: 'Star',
  ),
  VolunteerBenefit(
    title: 'Expanded industry network',
    description: 'Work alongside senior practitioners across chapters, councils and corporate members.',
    icon: 'Diversity3',
  ),
  VolunteerBenefit(
    title: 'Speaking and publishing opportunities',
    description: 'A platform for your practice through ICR events, webinars and the knowledge library.',
    icon: 'RecordVoiceOver',
  ),
  VolunteerBenefit(
    title: 'Career development',
    description: 'Build capability outside your day role, with mentoring and exposure to new disciplines.',
    icon: 'TrendingUp',
  ),
  VolunteerBenefit(
    title: 'Contribution to industry advancement',
    description: 'Shape the standards, research and certifications the profession runs on.',
    icon: 'Balance',
  ),
  VolunteerBenefit(
    title: 'Volunteer recognition and awards',
    description: 'Exclusive volunteer recognition, awards and CPD credits toward your certification.',
    icon: 'WorkspacePremium',
  ),
];
