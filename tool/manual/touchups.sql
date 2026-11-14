-- What the private copy needs after the seeds, so no picture shows a test-looking name or address.
-- Run with:  psql -v ON_ERROR_STOP=1 -d icr_mobilemanual -f tool/manual/touchups.sql
-- (it checks the database's name first; never run it on a shared database)
DO $$ BEGIN
  IF current_database() !~ 'manual' THEN RAISE EXCEPTION 'not a manual database: %', current_database(); END IF;
END $$;

-- The member the manual follows: a plain member (a self-serve sign-up is always PROFESSIONAL) with a real-looking address.
UPDATE "User" SET role = 'PROFESSIONAL', "personalRole" = 'PROFESSIONAL' WHERE email IN ('buyer@icr.dev', 'bharat.joshi@techcorp.example');
UPDATE "User" SET email = 'bharat.joshi@techcorp.example' WHERE email = 'buyer@icr.dev';
UPDATE "User" SET "linkedinUrl" = replace("linkedinUrl", 'bharat-buyer', 'bharat-joshi') WHERE email = 'bharat.joshi@techcorp.example' AND "linkedinUrl" LIKE '%bharat-buyer%';

-- The résumé the apply form offers.
UPDATE "Resume" SET title = 'Bharat Joshi – Operations' WHERE id = 'design-lj-resume-bharat';

-- Names the seeds gave their test fixtures.
UPDATE "Job" SET title = 'Estate Manager' WHERE id = 'design-career-job-sandbox';
UPDATE "Job" SET title = 'Facilities Planner' WHERE id = 'design-career-job-sandbox2';
UPDATE "Job" SET title = 'Facilities Coordinator' WHERE id = 'design-career-job-hiringbox';
UPDATE "Company" SET name = 'Sunbird Facility Services' WHERE id = 'design-mkt-co-sandbox';
UPDATE "Company" SET name = 'Harbourline Estates' WHERE id = 'design-career-co-sandbox';
UPDATE "User" SET "firstName" = 'Sneha', "lastName" = 'Kulkarni', designation = 'Facilities analyst' WHERE email = 'study.cards@learning-study.icr.test';
UPDATE "User" SET "firstName" = 'Esha', "lastName" = 'Pillai', designation = 'Facilities analyst' WHERE email = 'exam.sitter@learning-flows.icr.test';
UPDATE "User" SET "lastName" = 'Acharya' WHERE email = 'acct.persona@account-design.icr.test';
UPDATE "User" SET "lastName" = 'Bhatt' WHERE email = 'rfq.buyer@rfq-design.icr.test';

-- Paper prices a developer typed while testing (₹2, ₹5): real-looking ones, and a Foundation level the
-- member's 10 sign-up credits open (1 credit = ₹100).
UPDATE "LearningPaper" SET "priceAmount" = 150000 WHERE "priceAmount" > 0 AND "priceAmount" < 10000;
UPDATE "LearningPaper" SET "priceAmount" = 100000 WHERE slug = 'capital-planning-foundation';
UPDATE "LearningPaper" SET "priceAmount" = 250000 WHERE slug = 'capital-planning-advanced';

-- Meeting links and a payout reference that say "demo".
UPDATE "MentorProfile" SET "meetingLink" = 'https://meet.google.com/kqz-wfbn-rxd' WHERE "meetingLink" LIKE '%demo%';
UPDATE "MentorshipSession" SET "meetingLink" = 'https://meet.google.com/kqz-wfbn-rxd' WHERE "meetingLink" LIKE '%demo%';
UPDATE "MentorServiceBooking" SET "meetingLink" = 'https://meet.google.com/kqz-wfbn-rxd' WHERE "meetingLink" LIKE '%demo%';
UPDATE "MentorLedgerEntry" SET "settlementRef" = replace("settlementRef", 'NEFT-DEMO-', 'NEFT-2026-') WHERE "settlementRef" LIKE '%DEMO%';

-- The buyer persona acts for Meridian as a Buyer (the seeds leave her with no company). Meridian is the
-- company its admin persona works in: more than one company on the copy carries that name.
INSERT INTO "CompanyMembership" (id, "userId", "companyId", role, status, source, "updatedAt")
SELECT 'manual-buyer-at-meridian', u.id, a."companyId", 'BUYER', 'ACTIVE', 'ADDED', now()
FROM "User" u, "User" a
WHERE u.email IN ('buyer@icr.test', 'bhavna.kapoor@meridianfs.example') AND a.email IN ('companyadmin@icr.test', 'chetan.rao@meridianfs.example')
  AND NOT EXISTS (SELECT 1 FROM "CompanyMembership" m WHERE m."userId" = u.id AND m."companyId" = a."companyId");
UPDATE "User" u SET "companyId" = a."companyId", role = 'BUYER'
FROM "User" a WHERE u.email IN ('buyer@icr.test', 'bhavna.kapoor@meridianfs.example') AND a.email IN ('companyadmin@icr.test', 'chetan.rao@meridianfs.example');

-- A filler supplier the marketplace seed gave the same name as the manual's company.
UPDATE "Company" SET name = 'Meridian Workplace Solutions' WHERE id = 'design-mkt-co-fill-002';

-- Addresses that read like real ones for the people whose email a screen shows (team lists, settings).
-- tool/manual/people.json signs in with these and takes each password from the fixture it names.
UPDATE "User" SET email = 'chetan.rao@meridianfs.example' WHERE email = 'companyadmin@icr.test';
UPDATE "User" SET email = 'rahul.verma@meridianfs.example' WHERE email = 'recruiter@icr.test';
UPDATE "User" SET email = 'bina.thomas@meridianfs.example' WHERE email = 'branchadmin@icr.test';
UPDATE "User" SET email = 'hema.iyer@meridianfs.example' WHERE email = 'hiringmanager@icr.test';
UPDATE "User" SET email = 'vivek.menon@meridianfs.example' WHERE email = 'vendor@icr.test';
UPDATE "User" SET email = 'bhavna.kapoor@meridianfs.example' WHERE email = 'buyer@icr.test';
UPDATE "User" SET email = 'farah.khan@meridianfs.example' WHERE email = 'founder.professional@icr.test';
UPDATE "User" SET email = 'gita.nair@northgatecare.example' WHERE email = 'guest@icr.test';
UPDATE "User" SET email = 'pooja.sharma@prestigeparks.example' WHERE email = 'professional@icr.test';
UPDATE "User" SET email = 'sana.qureshi@icr.example' WHERE email = 'superadmin@icr.test';

-- A partner institute with a company behind it, its admin, and three enquiries waiting for it.
UPDATE "Company" SET name = 'Harbor Institute of Facility Management' WHERE id = 'design-career-co-harbor';
INSERT INTO "LearningProvider" (id, name, slug, summary, "companyId", verified, active, status, "updatedAt")
SELECT 'manual-provider-harbor', 'Harbor Institute of Facility Management', 'harbor-institute-fm',
       'Short courses in hard services, fire safety and site leadership for working facility teams.', 'design-career-co-harbor', true, true, 'ACTIVE', now()
WHERE NOT EXISTS (SELECT 1 FROM "LearningProvider" WHERE id = 'manual-provider-harbor');
UPDATE "User" SET "firstName" = 'Tara', "lastName" = 'Joshi', designation = 'Director, Harbor Institute of Facility Management' WHERE email = 'tara.joshi@career.icr.test';
INSERT INTO "LearningLead" (id, "providerId", kind, status, name, email, phone, company, headcount, message, source, "createdAt", "updatedAt") VALUES
  ('manual-lead-1', 'manual-provider-harbor', 'INDIVIDUAL', 'NEW', 'Bharat Joshi', 'bharat.joshi@techcorp.example', '+919845012345', 'TechCorp', NULL,
   'Is the fire safety refresher run on weekends? I manage a campus in Bengaluru and can only attend on Saturdays.', 'INSTITUTE_PAGE', now() - interval '3 hours', now()),
  ('manual-lead-2', 'manual-provider-harbor', 'CORPORATE', 'NEW', 'Chetan Rao', 'chetan.rao@meridianfs.example', '+919845098450', 'Meridian Facility Services', 24,
   'We would like the hard services supervisor course run in-house for 24 supervisors across Bengaluru and Hyderabad, in January.', 'IN_HOUSE_REQUEST', now() - interval '1 day', now()),
  ('manual-lead-3', 'manual-provider-harbor', 'INDIVIDUAL', 'CONTACTED', 'Pooja Sharma', 'pooja.sharma@prestigeparks.example', NULL, NULL, NULL,
   'Does the site leadership certificate count towards ICR CPD hours?', 'INSTITUTE_PAGE', now() - interval '4 days', now())
ON CONFLICT (id) DO NOTHING;

-- ICR staff personas the seeds do not make: a Learning Admin, and a Partner Admin of the same institute.
UPDATE "User" SET role = 'LEARNING_ADMIN', "personalRole" = 'LEARNING_ADMIN', email = 'nadia.fernandes@icr.example' WHERE email IN ('contentadmin@icr.test', 'nadia.fernandes@icr.example');
UPDATE "User" SET role = 'PARTNER_ADMIN', "personalRole" = 'PARTNER_ADMIN', "learningProviderId" = 'manual-provider-harbor', email = 'sameer.kulkarni@harborinstitute.example', "firstName" = 'Sameer', "lastName" = 'Kulkarni'
WHERE email IN ('supportagent@icr.test', 'sameer.kulkarni@harborinstitute.example');
