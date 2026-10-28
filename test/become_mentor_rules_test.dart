import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/become_mentor/become_mentor_models.dart';
import 'package:icr_mobile/features/become_mentor/become_mentor_rules.dart';

/// Every sentence here is the one `packages/shared/src/i18n/locales/en/validation.json` holds for the website's
/// `mentorProfileProblems` / `mentorPersonProblems` (pinned, like the website's mentor-rules.spec).
void main() {
  List<String> profile(MentorProfileFacts p, {bool forSubmit = false}) => [
    for (final x in mentorProfileProblems(p, forSubmit: forSubmit)) x.message,
  ];
  List<String> person(MentorPersonFacts p, {bool forSubmit = false}) => [
    for (final x in mentorPersonProblems(p, forSubmit: forSubmit)) x.message,
  ];
  String bio(int chars) => '<p>${'a' * chars}</p>';

  group('the mentoring half', () {
    test('a draft saves with nothing at all', () {
      expect(profile(const MentorProfileFacts()), isEmpty);
    });

    test('everything a submit needs, in the order the form asks for it', () {
      expect(profile(const MentorProfileFacts(), forSubmit: true), [
        'Tell mentees how you mentor — at least 100 characters.',
        'Add at least one area of expertise — it is how mentees find you.',
        'Choose who you want to mentor.',
      ]);
    });

    test('bioNeeded / bioMore name how many characters there are', () {
      expect(
        profile(MentorProfileFacts(bioHtml: bio(0)), forSubmit: true).first,
        'Tell mentees how you mentor — at least 100 characters.',
      );
      expect(
        profile(MentorProfileFacts(bioHtml: bio(6)), forSubmit: true).first,
        'Say a little more about how you mentor — at least 100 characters (6 so far).',
      );
      expect(profile(MentorProfileFacts(bioHtml: bio(99)), forSubmit: true).first, contains('(99 so far)'));
      expect(
        profile(
          MentorProfileFacts(bioHtml: bio(100), competencies: const ['x'], targetAudiences: const ['EARLY_CAREER']),
          forSubmit: true,
        ),
        isEmpty,
      );
    });

    test('markup is not counted: 100 characters of text, not of HTML', () {
      expect(
        profile(
          MentorProfileFacts(bioHtml: '<p><strong>${'a' * 50}</strong></p><p>${'b' * 48}</p>'),
          forSubmit: true,
        ).first,
        contains('(99 so far)'),
      );
      expect(htmlToPlainText('<p>A&nbsp;&amp;&nbsp;B &lt;ok&gt;</p>'), 'A & B <ok>');
      expect(htmlToPlainText(null), '');
    });

    test('bioTooLong applies to a draft too, and is judged on the stored HTML', () {
      final huge = 'a' * 20001;
      expect(profile(MentorProfileFacts(bioHtml: huge)), [
        '“How you mentor” is too long — keep it under 20,000 characters.',
      ]);
      expect(profile(MentorProfileFacts(bioHtml: 'a' * 20000)), isEmpty);
    });

    test('competenciesMax, competenciesNeeded (either list satisfies it)', () {
      expect(profile(MentorProfileFacts(competencies: List.filled(13, 'x'))), [
        'Choose at most 12 areas of expertise.',
      ]);
      expect(profile(MentorProfileFacts(competencies: List.filled(12, 'x'))), isEmpty);
      final needsArea = profile(const MentorProfileFacts(bioHtml: null), forSubmit: true);
      expect(needsArea, contains('Add at least one area of expertise — it is how mentees find you.'));
      expect(
        profile(const MentorProfileFacts(expertiseKeys: ['facilities']), forSubmit: true),
        isNot(contains('Add at least one area of expertise — it is how mentees find you.')),
      );
    });

    test('topicsMax', () {
      expect(profile(MentorProfileFacts(topics: List.filled(13, 't'))), ['Keep “Happy to talk about” to 12 topics.']);
      expect(profile(MentorProfileFacts(topics: List.filled(12, 't'))), isEmpty);
    });

    test('audienceNeeded only at submit', () {
      expect(profile(const MentorProfileFacts(targetAudiences: [])), isEmpty);
      expect(profile(const MentorProfileFacts(), forSubmit: true), contains('Choose who you want to mentor.'));
    });

    test('targetRolesMax', () {
      expect(profile(MentorProfileFacts(targetRoles: List.filled(9, 'r'))), [
        'Choose at most 8 roles you can help people reach.',
      ]);
      expect(profile(MentorProfileFacts(targetRoles: List.filled(8, 'r'))), isEmpty);
    });

    test('availabilityNoteMax', () {
      expect(profile(MentorProfileFacts(availabilityNote: 'a' * 281)), ['Keep “When you\'re free” to 280 characters.']);
      expect(profile(MentorProfileFacts(availabilityNote: 'a' * 280)), isEmpty);
    });

    test('each problem names the field its message belongs under', () {
      final fields = mentorProfileProblems(const MentorProfileFacts(), forSubmit: true).map((p) => p.field).toList();
      expect(fields, [MentorProfileField.bioHtml, MentorProfileField.competencies, MentorProfileField.targetAudiences]);
    });
  });

  group('the person behind it', () {
    test('a draft saves with nothing at all', () {
      expect(person(const MentorPersonFacts()), isEmpty);
    });

    test('everything a submit needs, in the order the section asks for it', () {
      expect(person(const MentorPersonFacts(), forSubmit: true), [
        'Add a profile photo — it is the first thing a mentee sees.',
        'Add your current role.',
        'Add your years in the profession.',
        'Add at least one language you mentor in.',
        'Add at least one role to your career history.',
      ]);
    });

    test('avatarNeeded: an empty address is no photo either', () {
      expect(
        person(const MentorPersonFacts(avatarUrl: ''), forSubmit: true).first,
        'Add a profile photo — it is the first thing a mentee sees.',
      );
      expect(
        person(const MentorPersonFacts(avatarUrl: '/uploads/a.jpg'), forSubmit: true),
        isNot(contains('Add a profile photo — it is the first thing a mentee sees.')),
      );
    });

    test('roleMax, roleMin, roleNeeded', () {
      expect(person(MentorPersonFacts(designation: 'a' * 101)), [
        'Keep your current role to 100 characters — just the job title.',
      ]);
      expect(person(const MentorPersonFacts(designation: 'a')), ['Your current role needs at least 2 characters.']);
      expect(
        person(const MentorPersonFacts(designation: '  ')),
        isEmpty,
        reason: 'blank is "no role", which only a submit refuses',
      );
      expect(person(const MentorPersonFacts(designation: '  '), forSubmit: true), contains('Add your current role.'));
      expect(person(MentorPersonFacts(designation: 'a' * 100)), isEmpty);
    });

    test('yearsRange, yearsNeeded', () {
      const msg = 'Years in the profession must be a whole number from 0 to 60.';
      expect(person(const MentorPersonFacts(yearsExperience: -1)), [msg]);
      expect(person(const MentorPersonFacts(yearsExperience: 61)), [msg]);
      expect(person(const MentorPersonFacts(yearsExperience: 0)), isEmpty);
      expect(person(const MentorPersonFacts(yearsExperience: 60)), isEmpty);
      expect(person(const MentorPersonFacts(), forSubmit: true), contains('Add your years in the profession.'));
    });

    test('languagesMax, languagesNeeded', () {
      expect(person(MentorPersonFacts(languages: List.filled(9, 'l'))), ['Choose at most 8 languages.']);
      expect(person(MentorPersonFacts(languages: List.filled(8, 'l'))), isEmpty);
      expect(
        person(const MentorPersonFacts(languages: []), forSubmit: true),
        contains('Add at least one language you mentor in.'),
      );
    });

    test('experienceNeeded counts the career history', () {
      expect(
        person(const MentorPersonFacts(experienceCount: 0), forSubmit: true),
        contains('Add at least one role to your career history.'),
      );
      expect(
        person(const MentorPersonFacts(experienceCount: 1), forSubmit: true),
        isNot(contains('Add at least one role to your career history.')),
      );
    });

    test('each problem names the field its message belongs under', () {
      final fields = mentorPersonProblems(const MentorPersonFacts(), forSubmit: true).map((p) => p.field).toList();
      expect(fields, [
        MentorPersonField.avatarUrl,
        MentorPersonField.designation,
        MentorPersonField.yearsExperience,
        MentorPersonField.languages,
        MentorPersonField.experience,
      ]);
    });
  });

  group('the sheets\' own checks', () {
    test('yearsProblem: whole years 0 to 60, blank is fine', () {
      expect(yearsProblem(''), isNull);
      expect(yearsProblem(' 12 '), isNull);
      expect(yearsProblem('0'), isNull);
      expect(yearsProblem('60'), isNull);
      expect(yearsProblem('61'), 'Whole years, 0–60.');
      expect(yearsProblem('-3'), 'Whole years, 0–60.');
      expect(yearsProblem('1.5'), 'Whole years, 0–60.');
      expect(yearsProblem('ten'), 'Whole years, 0–60.');
    });

    test('designationProblem: 2 to 100 characters, blank is fine (it clears the role)', () {
      expect(designationProblem(''), isNull);
      expect(designationProblem('A'), 'A headline needs at least 2 characters.');
      expect(designationProblem('AB'), isNull);
      expect(designationProblem('a' * 101), 'Keep your current role to 100 characters — just the job title.');
    });

    test('a bio round-trips between the paragraphs people type and the HTML the API stores', () {
      expect(bioToHtml(''), '');
      expect(bioToHtml('   '), '');
      expect(bioToHtml('One.\n\nTwo & <three>.'), '<p>One.</p><p>Two &amp; &lt;three&gt;.</p>');
      expect(bioToText('<p>One.</p><p>Two &amp; &lt;three&gt;.</p>'), 'One.\n\nTwo & <three>.');
      expect(bioToText(null), '');
      // A single line break stays inside its paragraph.
      expect(bioToHtml('a\nb'), '<p>a\nb</p>');
    });
  });

  group('a role of the career history', () {
    final now = DateTime.utc(2026, 10, 26, 6);
    List<String> xp(ExperienceFacts f) => [for (final p in experienceProblems(f, now: now)) p.message];
    const ok = ExperienceFacts(title: 'Facility Manager', organisation: 'Prestige', startYear: 2019, isCurrent: true);

    test('a complete role has no problem', () {
      expect(xp(ok), isEmpty);
    });

    test('titleMissing, titleShort, organisationMissing, organisationShort', () {
      expect(xp(const ExperienceFacts(startYear: 2019, isCurrent: true, organisation: 'Prestige')), ['Add your role.']);
      expect(xp(const ExperienceFacts(title: 'A', startYear: 2019, isCurrent: true, organisation: 'Prestige')), [
        'A role needs at least 2 characters.',
      ]);
      expect(xp(const ExperienceFacts(title: 'FM', startYear: 2019, isCurrent: true)), ['Add the organisation.']);
      expect(xp(const ExperienceFacts(title: 'FM', organisation: 'P', startYear: 2019, isCurrent: true)), [
        'An organisation needs at least 2 characters.',
      ]);
    });

    test('cityMax and descriptionMax', () {
      expect(
        xp(ExperienceFacts(title: 'FM', organisation: 'Prestige', startYear: 2019, isCurrent: true, city: 'c' * 121)),
        ['Keep the city under 120 characters.'],
      );
      expect(
        xp(
          ExperienceFacts(
            title: 'FM',
            organisation: 'Prestige',
            startYear: 2019,
            isCurrent: true,
            description: 'd' * 2001,
          ),
        ),
        ['Keep the description under 2,000 characters.'],
      );
    });

    test('startMissing, startFuture (by year, and by month this year, on the Indian clock)', () {
      expect(xp(const ExperienceFacts(title: 'FM', organisation: 'Prestige', isCurrent: true)), [
        'Add the year you started.',
      ]);
      expect(xp(const ExperienceFacts(title: 'FM', organisation: 'Prestige', startYear: 2027, isCurrent: true)), [
        'The start date can’t be in the future.',
      ]);
      expect(
        xp(
          const ExperienceFacts(
            title: 'FM',
            organisation: 'Prestige',
            startYear: 2026,
            startMonth: 11,
            isCurrent: true,
          ),
        ),
        ['The start date can’t be in the future.'],
      );
      expect(
        xp(
          const ExperienceFacts(
            title: 'FM',
            organisation: 'Prestige',
            startYear: 2026,
            startMonth: 10,
            isCurrent: true,
          ),
        ),
        isEmpty,
      );
      expect(xp(const ExperienceFacts(title: 'FM', organisation: 'Prestige', startYear: 1949, isCurrent: true)), [
        'Choose a year from 1950 on.',
      ]);
    });

    test('a role that ended: endMissing, endMonthWithoutYear, endFuture, endBeforeStart', () {
      const base = ExperienceFacts(title: 'FM', organisation: 'Prestige', startYear: 2019, startMonth: 6);
      expect(xp(base), ['Add when this role ended, or tick “I work here now”.']);
      expect(xp(const ExperienceFacts(title: 'FM', organisation: 'Prestige', startYear: 2019, endMonth: 3)), [
        'Add the end year too.',
      ]);
      expect(xp(const ExperienceFacts(title: 'FM', organisation: 'Prestige', startYear: 2019, endYear: 2027)), [
        'The end date can’t be in the future. If you still work here, tick “I work here now”.',
      ]);
      expect(xp(const ExperienceFacts(title: 'FM', organisation: 'Prestige', startYear: 2019, endYear: 2018)), [
        'The end date is before the start date.',
      ]);
      expect(
        xp(
          const ExperienceFacts(
            title: 'FM',
            organisation: 'Prestige',
            startYear: 2019,
            startMonth: 6,
            endYear: 2019,
            endMonth: 3,
          ),
        ),
        ['The end date is before the start date.'],
      );
      expect(
        xp(
          const ExperienceFacts(
            title: 'FM',
            organisation: 'Prestige',
            startYear: 2019,
            startMonth: 6,
            endYear: 2019,
            endMonth: 6,
          ),
        ),
        isEmpty,
      );
    });

    test('a current role needs no end', () {
      expect(
        xp(const ExperienceFacts(title: 'FM', organisation: 'Prestige', startYear: 2019, isCurrent: true, endMonth: 3)),
        isEmpty,
      );
    });
  });

  group('what the API sends', () {
    test('the draft a first save creates (a real answer as Kiran)', () {
      final p = MyMentorProfile.fromJson({
        'id': 'cmvpei96501xvmyi0nu9fsrhi',
        'user': {
          'id': 'dsgn-mentoring-u-kiran',
          'firstName': 'Kiran',
          'lastName': 'Shah',
          'avatarUrl': '/uploads/design-mentoring-face-male-04.jpg',
        },
        'headline': '',
        'yearsExperience': null,
        'competencies': ['Career transitions'],
        'expertiseKeys': [],
        'certifications': [],
        'languages': [],
        'targetRoles': [],
        'targetAudiences': [],
        'preferredModes': ['VIDEO'],
        'cadence': null,
        'openSlots': 2,
        'capacity': 2,
        'status': 'DRAFT',
        'bioHtml': '<p>Short.</p>',
        'topics': [],
        'availabilityNote': null,
        'availabilityBlocks': [
          {'weekday': 2, 'startMin': 1080, 'endMin': 1230},
        ],
        'timezone': 'Asia/Kolkata',
        'reviewNote': null,
        'discoverable': false,
        'meetingLink': null,
      });
      expect(p.status, MentorStatus.draft);
      expect(p.status.canSubmit, isTrue);
      expect(p.competencies, ['Career transitions']);
      expect(p.capacity, 2);
      expect(p.availability.single, const AvailabilityBlock(weekday: 2, startMin: 1080, endMin: 1230));
      expect(p.discoverable, isFalse);
      expect(p.headline, isNull, reason: 'an empty headline is none');
    });

    test('each status is read, and only a draft or a rejected profile may submit', () {
      expect(
        {for (final s in MentorStatus.values) s.api: (s.canSubmit, s.listed)},
        {
          'DRAFT': (true, false),
          'PENDING': (false, false),
          'APPROVED': (false, true),
          'PAUSED': (false, true),
          'REJECTED': (true, false),
        },
      );
      expect(
        [for (final s in MentorStatus.values) s.label],
        ['Draft', 'Awaiting review', 'Listed', 'Paused', 'Not approved'],
      );
      expect(MentorStatus.fromApi('nonsense'), MentorStatus.draft);
    });

    test('readiness and training as the API answers (as Kiran, with a course added)', () {
      final r = MentorReadiness.fromJson({
        'profileComplete': false,
        'conductAccepted': true,
        'conductVersion': '2026.1',
        'trainingComplete': false,
        'training': {
          'required': [
            {
              'courseId': 'c1',
              'code': 'MT-101',
              'title': 'Mentoring basics',
              'slug': 'mentoring-basics',
              'durationLabel': '2 hours',
              'status': 'NOT_ENROLLED',
              'completed': false,
            },
            {
              'courseId': 'c2',
              'code': 'MT-102',
              'title': 'Boundaries',
              'slug': 'boundaries',
              'durationLabel': null,
              'status': 'CONFIRMED',
              'completed': false,
            },
            {
              'courseId': 'c3',
              'code': 'MT-103',
              'title': 'Feedback',
              'slug': 'feedback',
              'durationLabel': null,
              'status': 'COMPLETED',
              'completed': true,
            },
          ],
          'completedCount': 1,
          'requiredCount': 3,
          'allComplete': false,
          'completedAt': null,
        },
        'documentsUploaded': 1,
        'documentsVerified': 0,
        'canSubmit': false,
        'blockers': ['Add your current role.', 'Finish mentor training (1 of 3 modules).'],
        'approvalExpiresAt': '2028-10-26T00:00:00.000Z',
        'renewalDue': true,
      });
      expect(r.conductAccepted, isTrue);
      expect(r.conductVersion, '2026.1');
      expect(r.training.required.map((c) => c.statusLabel), ['Not started', 'Enrolment confirmed', 'Complete']);
      expect(r.training.required.first.notEnrolled, isTrue);
      expect(r.training.completedCount, 1);
      expect(r.blockers, hasLength(2));
      expect(r.renewalDue, isTrue);
      expect(r.approvalExpiresAt, isNotNull);
    });

    test('the readiness of a member with no profile (the real answer)', () {
      final r = MentorReadiness.fromJson({
        'profileComplete': false,
        'conductAccepted': false,
        'conductVersion': null,
        'trainingComplete': true,
        'training': {'required': [], 'completedCount': 0, 'requiredCount': 0, 'allComplete': true, 'completedAt': null},
        'documentsUploaded': 0,
        'documentsVerified': 0,
        'canSubmit': false,
        'blockers': ['Create your mentor profile.', 'Agree to the mentor code of conduct.'],
        'approvalExpiresAt': null,
        'renewalDue': false,
      });
      expect(r.training.requiredCount, 0);
      expect(r.trainingComplete, isTrue);
      expect(r.blockers.first, 'Create your mentor profile.');
    });

    test('a document, and what can be done with it', () {
      final d = MentorDocument.fromJson({
        'id': 'd1',
        'kind': 'CERTIFICATION',
        'label': 'CFMP certificate, 2021',
        'fileUrl': '/uploads/x.pdf',
        'fileName': 'cfmp.pdf',
        'fileSize': 2048,
        'status': 'REJECTED',
        'reviewNote': 'The scan is cut off.',
        'reviewedAt': '2026-10-20T00:00:00.000Z',
        'createdAt': '2026-10-19T00:00:00.000Z',
      });
      expect(d.kindLabel, 'Certificate');
      expect(d.statusLabel, 'Not accepted');
      expect(d.removable, isFalse, reason: 'only an unreviewed document can be taken back');
      expect(d.reviewNote, 'The scan is cut off.');
      expect(
        MentorDocument.fromJson({
          'id': 'd2',
          'kind': 'OTHER',
          'status': 'PENDING',
          'createdAt': '2026-10-19T00:00:00.000Z',
        }).removable,
        isTrue,
      );
    });

    test('the person, from GET /users/me/profile (a real answer as Kiran)', () {
      final p = PersonProfile.fromJson({
        'user': {
          'id': 'dsgn-mentoring-u-kiran',
          'firstName': 'Kiran',
          'lastName': 'Shah',
          'designation': null,
          'yearsExperience': null,
          'languages': [],
          'avatarUrl': '/uploads/design-mentoring-face-male-04.jpg',
        },
        'company': null,
      });
      expect(p.name, 'Kiran Shah');
      expect(p.avatarUrl, '/uploads/design-mentoring-face-male-04.jpg');
      expect(p.designation, isNull);
      expect(p.yearsExperience, isNull);
      expect(p.languages, isEmpty);
    });

    test('a role keeps what it came with when the list is saved again', () {
      final row = ExperienceRow.fromJson({
        'id': 'xp1',
        'title': 'Head of Facilities',
        'organisation': 'Prestige Group',
        'company': {'id': 'co-1', 'name': 'Prestige Group'},
        'employmentType': 'FULL_TIME',
        'city': 'Bengaluru',
        'industryKeys': ['real-estate'],
        'startYear': 2019,
        'startMonth': 4,
        'endYear': null,
        'endMonth': null,
        'isCurrent': true,
        'description': '  Ran the campus.  ',
        'sortOrder': 0,
      });
      expect(row.toJson(), {
        'title': 'Head of Facilities',
        'organisation': 'Prestige Group',
        'companyId': 'co-1',
        'employmentType': 'FULL_TIME',
        'city': 'Bengaluru',
        'industryKeys': ['real-estate'],
        'startYear': 2019,
        'startMonth': 4,
        'isCurrent': true,
        'description': 'Ran the campus.',
      });
      expect(row.span, 'Apr 2019 - Present');
      const ended = ExperienceRow(title: 'FM', organisation: 'ACME', startYear: 2015, endYear: 2018, endMonth: 12);
      expect(ended.span, '2015 - Dec 2018');
      expect(ended.toJson().containsKey('startMonth'), isFalse);
      expect(ended.toJson()['endYear'], 2018);
    });

    test('a current role sends no end, even one it was holding', () {
      const row = ExperienceRow(title: 'FM', organisation: 'ACME', startYear: 2015, endYear: 2018, isCurrent: true);
      expect(row.toJson().containsKey('endYear'), isFalse);
    });

    test('the code of conduct', () {
      final c = CodeOfConduct.fromJson({
        'version': '2026.1',
        'clauses': [
          {'key': 'volunteer', 'title': 'I am volunteering', 'body': 'I offer my time freely.'},
        ],
      });
      expect(c.version, '2026.1');
      expect(c.clauses.single.title, 'I am volunteering');
    });

    test('the lists the pickers offer are the website\'s', () {
      expect(competencyDomains, hasLength(24));
      expect(competencyDomains.first, 'Corporate Real Estate');
      expect(competencyDomains, contains('Sustainability & ESG'));
      expect(spokenLanguages, hasLength(14));
      expect(mentorModes.keys, ['VIDEO', 'PHONE', 'IN_PERSON', 'CHAT']);
      expect(mentorCadences.keys, ['WEEKLY', 'FORTNIGHTLY', 'MONTHLY', 'ADHOC']);
      expect(MentorAudience.values.map((a) => a.api), [
        'EARLY_CAREER',
        'WORKING_PROFESSIONAL',
        'CAREER_SWITCHER',
        'PEOPLE_LEADER',
        'RETURNER',
      ]);
      expect(mentorDocumentKinds.containsKey('ID_PROOF'), isFalse, reason: 'a photo ID is no longer collected');
    });
  });
}
