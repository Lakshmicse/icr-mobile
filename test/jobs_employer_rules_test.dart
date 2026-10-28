import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/jobs/employer/applicant_detail_screen.dart' show activityWords;
import 'package:icr_mobile/features/jobs/employer/applicants_controller.dart';
import 'package:icr_mobile/features/jobs/employer/hiring_models.dart';
import 'package:icr_mobile/features/jobs/employer/job_rules.dart';

/// The rules the composer and the pipeline run before anything reaches the API: the same lists and
/// sentences as `@icr/shared` (`job-rules.ts`, `ALLOWED_APPLICATION_TRANSITIONS`), so a checklist the
/// phone shows is the refusal the API would give. What the API does with them is proved in
/// `test/live/jobs_employer_live_test.dart`.

final _description = 'Lead day-to-day facilities operations across four logistics parks. ' * 3;

JobFacts _ready({
  String title = 'Facility Supervisor',
  String? description,
  List<String> skills = const ['HVAC'],
  String? country = 'India',
  List<String> cities = const ['Pune'],
  Map<String, int> cityOpenings = const {},
  bool externalApply = false,
  String? applyUrl,
  num? openings = 1,
  num? salaryMin,
  num? salaryMax,
  num? experienceMin,
  num? experienceMax,
}) => JobFacts(
  title: title,
  description: description ?? _description,
  skills: skills,
  country: country,
  cities: cities,
  cityOpenings: cityOpenings,
  externalApply: externalApply,
  applyUrl: applyUrl,
  openings: openings,
  salaryMin: salaryMin,
  salaryMax: salaryMax,
  experienceMin: experienceMin,
  experienceMax: experienceMax,
);

List<String> _keys(JobFacts f) => [for (final b in jobPublishBlockers(f)) b.key];

void main() {
  group('the limits', () {
    test('are the shared JOB_LIMITS', () {
      expect(JobLimits.titleMin, 3);
      expect(JobLimits.titleMax, 120);
      expect(JobLimits.descriptionMin, 120);
      expect(JobLimits.descriptionMax, 20000);
      expect(JobLimits.descriptionHtmlMax, 60000);
      expect(JobLimits.skillMax, 60);
      expect(JobLimits.cityMax, 60);
      expect(JobLimits.openingsMin, 1);
      expect(JobLimits.openingsMax, 999);
      expect(JobLimits.salaryMax, 999999999);
      expect(JobLimits.screeningPromptMin, 3);
      expect(JobLimits.screeningPromptMax, 300);
      expect(JobLimits.screeningOptionMax, 100);
      expect(JobLimits.screeningOptionsMax, 10);
      expect(JobLimits.interviewNotesMax, 2000);
    });

    test('the countries are the shared COUNTRIES, India first', () {
      expect(jobCountries.first, 'India');
      expect(jobCountries, hasLength(13));
      expect(jobCountries, containsAll(['United Arab Emirates', 'Saudi Arabia', 'Hong Kong', 'USA', 'UK']));
    });
  });

  group('what a posting needs to go live', () {
    test('a complete posting has nothing in its way', () {
      expect(jobPublishBlockers(_ready()), isEmpty);
    });

    test('an empty posting lists everything, in the order the composer shows it', () {
      expect(_keys(const JobFacts()), ['title', 'description', 'skills', 'country']);
    });

    test('the title needs three characters', () {
      expect(_keys(_ready(title: 'HR')), ['title']);
      expect(_keys(_ready(title: '   ')), ['title']);
      expect(_keys(_ready(title: 'HRM')), isEmpty);
      expect(
        jobPublishBlockers(_ready(title: 'x')).single.message,
        'Give the role a clear, specific title (at least 3 characters).',
      );
    });

    test('the description counts what a reader sees: tags do not count', () {
      final tagged = '<p><strong>${'a ' * 30}</strong></p>';
      expect(_keys(_ready(description: tagged)), ['description'], reason: '59 characters of text, however much markup');
      expect(_keys(_ready(description: '<p>${'word ' * 30}</p>')), isEmpty);
      expect(
        jobPublishBlockers(_ready(description: 'short')).single.message,
        'Write a description of at least 120 characters.',
      );
    });

    test('the description may not pass 20,000 characters', () {
      final blockers = jobPublishBlockers(_ready(description: 'a' * 20001));
      expect(blockers.single.key, 'description');
      expect(blockers.single.message, 'Keep the description under 20,000 characters.');
      expect(_keys(_ready(description: 'a' * 20000)), isEmpty);
    });

    test('a required skill is needed, blanks do not count, and a long one is named', () {
      expect(_keys(_ready(skills: const [])), ['skills']);
      expect(_keys(_ready(skills: const ['  ', ''])), ['skills']);
      expect(
        jobPublishBlockers(_ready(skills: const [])).single.message,
        'Add at least one required skill so the right candidates find this role.',
      );
      final long = 'S' * 61;
      final blockers = jobPublishBlockers(_ready(skills: ['HVAC', long]));
      expect(blockers.single.key, 'skills');
      expect(blockers.single.message, 'Shorten the skill “${'S' * 24}…” to 60 characters or fewer.');
      expect(_keys(_ready(skills: ['S' * 60])), isEmpty);
    });

    test('the country must be one of the list', () {
      expect(_keys(_ready(country: null)), ['country']);
      expect(_keys(_ready(country: 'Narnia')), ['country']);
      expect(_keys(_ready(country: 'Qatar')), isEmpty);
      expect(jobPublishBlockers(_ready(country: null)).single.message, 'Pick the country this role is based in.');
    });

    test('salary is optional, but a maximum below the minimum is refused', () {
      expect(_keys(_ready()), isEmpty, reason: 'no salary at all is fine');
      expect(_keys(_ready(salaryMin: 500000)), isEmpty);
      expect(_keys(_ready(salaryMin: 900000, salaryMax: 500000)), ['salaryOrder']);
      expect(_keys(_ready(salaryMin: 0, salaryMax: 500000)), isEmpty, reason: 'zero is "not set"');
      expect(_keys(_ready(salaryMin: 500000, salaryMax: 500000)), isEmpty);
      expect(
        jobPublishBlockers(_ready(salaryMin: 9, salaryMax: 1)).single.message,
        'Maximum salary must be at least the minimum.',
      );
    });

    test('minimum experience cannot exceed the maximum', () {
      expect(_keys(_ready(experienceMin: 8, experienceMax: 3)), ['experienceOrder']);
      expect(_keys(_ready(experienceMin: 3, experienceMax: 3)), isEmpty);
      expect(_keys(_ready(experienceMin: 5)), isEmpty);
      expect(
        jobPublishBlockers(_ready(experienceMin: 8, experienceMax: 3)).single.message,
        'Minimum experience cannot exceed the maximum.',
      );
    });

    test('two or more cities each need their seats; one city does not', () {
      expect(_keys(_ready(cities: const ['Pune', 'Mumbai'])), ['cityOpenings']);
      final blocker = jobPublishBlockers(
        _ready(cities: const ['Pune', 'Mumbai'], cityOpenings: const {'Pune': 2}),
      ).single;
      expect(blocker.message, 'Enter the number of openings for each city (Mumbai is missing).');
      expect(blocker.cityIndex, 1);
      expect(_keys(_ready(cities: const ['Pune', 'Mumbai'], cityOpenings: const {'Pune': 2, 'Mumbai': 1})), isEmpty);
      expect(_keys(_ready(cities: const ['Pune', 'Mumbai'], cityOpenings: const {'pune': 2, 'MUMBAI': 1})), isEmpty);
      expect(_keys(_ready(cities: const ['Pune', 'Mumbai'], cityOpenings: const {'Pune': 2, 'Mumbai': 0})), [
        'cityOpenings',
      ]);
      expect(_keys(_ready(cities: const ['Pune', ' '])), isEmpty, reason: 'a blank is not a city');
    });

    test('an external apply needs a link a candidate can open', () {
      expect(_keys(_ready(externalApply: true)), ['applyUrl']);
      expect(_keys(_ready(externalApply: true, applyUrl: 'careers.example.com')), ['applyUrl']);
      expect(_keys(_ready(externalApply: true, applyUrl: 'ftp://example.com')), ['applyUrl']);
      expect(_keys(_ready(externalApply: true, applyUrl: 'https://careers.example.com/jobs/1')), isEmpty);
      expect(_keys(_ready(applyUrl: 'nonsense')), isEmpty, reason: 'ignored when applying on ICR');
      expect(
        jobPublishBlockers(_ready(externalApply: true)).single.message,
        'Add the link where candidates apply (starting with https://).',
      );
    });

    test('openings are a whole number from 1 to 999', () {
      expect(_keys(_ready(openings: 0)), ['openings']);
      expect(_keys(_ready(openings: 1000)), ['openings']);
      expect(_keys(_ready(openings: 2.5)), ['openings']);
      expect(_keys(_ready(openings: 999)), isEmpty);
      expect(_keys(_ready(openings: null)), isEmpty);
      expect(jobPublishBlockers(_ready(openings: 0)).single.message, 'Openings must be a whole number from 1 to 999.');
    });

    test('isApplyUrl takes http and https links with a dotted host', () {
      expect(isApplyUrl('https://a.example.com/x?y=1'), isTrue);
      expect(isApplyUrl(' http://a.example.com '), isTrue);
      expect(isApplyUrl('https://localhost'), isFalse);
      expect(isApplyUrl('mailto:a@b.co'), isFalse);
      expect(isApplyUrl(''), isFalse);
      expect(isApplyUrl(null), isFalse);
    });
  });

  group('the description as typed and as stored', () {
    test('blank-line paragraphs, ## headings and - bullets become HTML', () {
      const text =
          'Run the sites.\nEvery day.\n\n## What you will do\n- Own shifts\n- Hold vendors to SLAs\n\nClosing line.';
      expect(
        descriptionToHtml(text),
        '<p>Run the sites.<br>Every day.</p><h3>What you will do</h3><ul><li>Own shifts</li><li>Hold vendors to SLAs</li></ul><p>Closing line.</p>',
      );
    });

    test('what is typed is escaped, never trusted as markup', () {
      expect(descriptionToHtml('Use <b>care</b> & speed'), '<p>Use &lt;b&gt;care&lt;/b&gt; &amp; speed</p>');
    });

    test('the stored HTML reads back as the composer wrote it', () {
      const text = 'Run the sites.\n\n## What you will do\n\n- Own shifts\n- Hold vendors to SLAs\n\nClosing line.';
      expect(htmlToDescription(descriptionToHtml(text)), text);
      expect(htmlToDescription(null), '');
      expect(htmlToDescription('  '), '');
      expect(htmlToDescription('<p>Fish &amp; chips</p>'), 'Fish & chips');
    });
  });

  group('the draft', () {
    test('a new draft is a full-time, on-site, Indian posting for one opening, with nothing to publish', () {
      const d = JobDraft();
      expect(d.isNew, isTrue);
      expect(d.employmentType, 'FULL_TIME');
      expect(d.workMode, 'ONSITE');
      expect(d.country, 'India');
      expect(d.openings, 1);
      expect(d.status, PostingStatus.draft);
      expect([for (final b in d.blockers) b.key], ['title', 'description', 'skills']);
    });

    test('a draft may be saved half-filled, but not without a title or over the limits', () {
      expect(const JobDraft().saveProblem, 'Give the posting a title to save it.');
      expect(const JobDraft(title: 'Supervisor').saveProblem, isNull);
      expect(JobDraft(title: 'x' * 121).saveProblem, 'Keep the title under 120 characters.');
      expect(JobDraft(title: 'Supervisor', skills: List.filled(31, 'a')).saveProblem, 'List at most 30 skills.');
      expect(JobDraft(title: 'Supervisor', cities: List.filled(11, 'Pune')).saveProblem, 'List at most 10 cities.');
      expect(const JobDraft(title: 'Supervisor', salaryMax: 1000000000).saveProblem, 'Enter a salary up to 999999999.');
      expect(
        const JobDraft(title: 'Supervisor', experienceMax: 61).saveProblem,
        'Experience is whole years from 0 to 60.',
      );
      expect(
        const JobDraft(title: 'Supervisor', externalApply: true, applyUrl: 'example.com').saveProblem,
        'The apply link must be a full URL including https://',
      );
      expect(
        JobDraft(title: 'Supervisor', description: 'a' * 70000).saveProblem,
        'The description is too long to save.',
      );
      expect(
        const JobDraft(title: 'Supervisor', salaryMin: 900000, salaryMax: 500000).saveProblem,
        'Maximum salary must be at least the minimum.',
        reason: 'the API refuses it on every save',
      );
      expect(const JobDraft(title: 'Supervisor', salaryMin: 0, salaryMax: 500000).saveProblem, isNull);
      expect(
        const JobDraft(title: 'Supervisor', experienceMin: 8, experienceMax: 3).saveProblem,
        'Minimum experience cannot exceed the maximum.',
      );
      expect(const JobDraft(title: 'Supervisor', experienceMin: 3, experienceMax: 3).saveProblem, isNull);
    });

    test('the body the API gets carries the status, trimmed words, and no salary of zero', () {
      final json = JobDraft(
        title: '  Facility Supervisor ',
        description: 'Run the sites.',
        department: ' ',
        cities: const ['Pune', ' '],
        skills: const ['HVAC', ' '],
        salaryMin: 0,
        salaryMax: 900000,
        experienceMin: 3,
      ).toJson(status: PostingStatus.open);
      expect(json['title'], 'Facility Supervisor');
      expect(json['description'], '<p>Run the sites.</p>');
      expect(json['department'], isNull);
      expect(json['cities'], ['Pune']);
      expect(json['skills'], ['HVAC']);
      expect(json['salaryMin'], isNull);
      expect(json['salaryMax'], 900000);
      expect(json['experienceMin'], 3);
      expect(json['status'], 'OPEN');
      expect(json['applyMethod'], 'ON_PLATFORM');
      expect(json['applyUrl'], isNull);
      expect(json['cityOpenings'], isEmpty);
    });

    test('with several cities the total is the sum of their seats, and each count is sent', () {
      final d = JobDraft(
        title: 'x',
        cities: const ['Pune', 'Mumbai'],
        cityOpenings: const {'Pune': 2, 'Mumbai': 3},
        openings: 9,
      );
      expect(d.totalOpenings, 5);
      final json = d.toJson();
      expect(json['openings'], 5);
      expect(json['cityOpenings'], [
        {'city': 'Pune', 'openings': 2},
        {'city': 'Mumbai', 'openings': 3},
      ]);
      expect(d.facts.openings, isNull, reason: 'a multi-city total is derived, never typed');
    });

    test('several cities with no seats counted yet are still one opening to a draft', () {
      final json = const JobDraft(title: 'x', cities: ['Pune', 'Mumbai']).toJson();
      expect(json['openings'], 1);
      expect(json['cityOpenings'], isEmpty);
      final partly = const JobDraft(title: 'x', cities: ['Pune', 'Mumbai'], cityOpenings: {'Pune': 2}).toJson();
      expect(partly['openings'], 2);
      expect(partly['cityOpenings'], [
        {'city': 'Pune', 'openings': 2},
      ]);
    });

    test('an external apply sends its link; an on-ICR one drops it', () {
      final ext = const JobDraft(title: 'x', externalApply: true, applyUrl: ' https://a.example.com ').toJson();
      expect(ext['applyMethod'], 'EXTERNAL_URL');
      expect(ext['applyUrl'], 'https://a.example.com');
      final onSite = const JobDraft(title: 'x', applyUrl: 'https://a.example.com').toJson();
      expect(onSite['applyMethod'], 'ON_PLATFORM');
      expect(onSite['applyUrl'], isNull);
    });

    test('a stored posting reads back into the draft', () {
      final d = JobDraft.fromJson({
        'id': 'J1',
        'title': 'Facility Supervisor',
        'description': '<p>Run the sites.</p><ul><li>Own shifts</li></ul>',
        'seniority': 'MID',
        'employmentType': 'CONTRACT',
        'workMode': 'HYBRID',
        'country': 'Qatar',
        'city': 'Doha',
        'skills': ['HVAC'],
        'salaryMin': '900000.00',
        'experienceMin': 3,
        'openings': 4,
        'applyMethod': 'EXTERNAL_URL',
        'applyUrl': 'https://a.example.com',
        'applyDeadline': '2026-12-01T12:30:00.000Z',
        'status': 'PAUSED',
        'cityOpenings': [
          {'city': 'Doha', 'openings': 4},
        ],
      });
      expect(d.id, 'J1');
      expect(d.cities, ['Doha']);
      expect(d.cityOpenings, {'Doha': 4});
      expect(d.salaryMin, 900000);
      expect(d.externalApply, isTrue);
      expect(d.status, PostingStatus.paused);
      expect(d.description, 'Run the sites.\n\n- Own shifts');
      expect(d.applyDeadline, isNotNull);
      expect(d.workMode, 'HYBRID');
      expect(d.salaryVisible, isTrue);
      expect(d.jobFunctions, isEmpty);
      expect(
        JobDraft.fromJson({
          'jobFunctions': ['HSE'],
        }).jobFunctions,
        ['HSE'],
      );
    });

    test('two titles are the same title when they read the same', () {
      expect(jobTitleKey('  Facility   Supervisor '), jobTitleKey('facility supervisor'));
      expect(jobTitleKey('Facility Supervisor'), isNot(jobTitleKey('Facility Supervisors')));
    });
  });

  group('the questions a job asks', () {
    test('a question needs 3 to 300 characters of words', () {
      expect(const ScreeningDraft(prompt: 'ab').problem, 'Write each question in at least 3 characters.');
      expect(ScreeningDraft(prompt: 'a' * 301).problem, 'Keep each question under 300 characters.');
      expect(const ScreeningDraft(prompt: 'How many years?').problem, isNull);
    });

    test('a pick-one question needs two different options, at most ten', () {
      expect(
        const ScreeningDraft(type: 'SINGLE_SELECT', prompt: 'Which shift?', options: ['Day']).problem,
        'Give "Which shift?" at least two options.',
      );
      expect(
        const ScreeningDraft(type: 'SINGLE_SELECT', prompt: 'Which shift?', options: ['Day', 'day']).problem,
        'Each option must be different.',
      );
      expect(
        ScreeningDraft(
          type: 'MULTI_SELECT',
          prompt: 'Which shift?',
          options: [for (var i = 0; i < 11; i++) 'o$i'],
        ).problem,
        'Keep to 10 options.',
      );
      expect(
        ScreeningDraft(type: 'SINGLE_SELECT', prompt: 'Which shift?', options: ['a', 'b' * 101]).problem,
        'Keep each option under 100 characters.',
      );
      expect(
        const ScreeningDraft(type: 'SINGLE_SELECT', prompt: 'Which shift?', options: ['Day', 'Night']).problem,
        isNull,
      );
    });

    test('the API gets only what the type uses', () {
      expect(const ScreeningDraft(type: 'YEARS', prompt: ' Years in FM? ', idealAnswer: '5', mustHave: true).toJson(), {
        'type': 'YEARS',
        'prompt': 'Years in FM?',
        'idealAnswer': '5',
        'mustHave': true,
      });
      expect(
        const ScreeningDraft(type: 'SINGLE_SELECT', prompt: 'Which shift?', options: ['Day', ' ', 'Night']).toJson(),
        {
          'type': 'SINGLE_SELECT',
          'prompt': 'Which shift?',
          'options': ['Day', 'Night'],
          'mustHave': false,
        },
      );
      expect(const ScreeningDraft(type: 'RATING', prompt: 'Rate yourself', scaleMax: 10).toJson()['scaleMax'], 10);
      expect(const ScreeningDraft(type: 'RATING', prompt: 'Rate yourself').toJson()['scaleMax'], 5);
    });
  });

  group('an interview and an offer', () {
    final now = DateTime(2026, 10, 26, 9);
    InterviewDraft interview({
      DateTime? at,
      String mode = 'VIDEO',
      String link = '',
      String location = '',
      String map = '',
      int mins = 60,
      List<String> panel = const ['me'],
      String notes = '',
    }) => InterviewDraft(
      scheduledAt: at,
      mode: mode,
      meetingLink: link,
      location: location,
      mapLink: map,
      durationMins: mins,
      interviewerIds: panel,
      notes: notes,
    );

    test('needs a future time, a panel, and a place for an in-person round', () {
      expect(interview().problem(now), 'Pick a date and time.');
      expect(interview(at: now).problem(now), 'Pick a time in the future.');
      expect(
        interview(at: DateTime(2026, 10, 27, 10), panel: const []).problem(now),
        'Choose at least one person for the panel.',
      );
      expect(interview(at: DateTime(2026, 10, 27, 10), mins: 4).problem(now), 'An interview is at least 5 minutes.');
      expect(
        interview(at: DateTime(2026, 10, 27, 10), mode: 'IN_PERSON').problem(now),
        'Give the address for an in-person interview.',
      );
      expect(interview(at: DateTime(2026, 10, 27, 10), mode: 'IN_PERSON', location: 'Floor 3').problem(now), isNull);
      expect(
        interview(at: DateTime(2026, 10, 27, 10)).problem(now),
        isNull,
        reason: 'a video call need not have a link yet',
      );
    });

    test('a meeting link and a map link must be full links', () {
      expect(
        interview(at: DateTime(2026, 10, 27, 10), link: 'meet.google.com/abc').problem(now),
        'The meeting link must be a full URL starting with https://',
      );
      expect(
        interview(at: DateTime(2026, 10, 27, 10), map: 'maps').problem(now),
        'The map link must be a full URL starting with https://',
      );
      expect(
        interview(at: DateTime(2026, 10, 27, 10), link: 'https://meet.google.com/abc-defg-hij').problem(now),
        isNull,
      );
      expect(
        interview(at: DateTime(2026, 10, 27, 10), notes: 'n' * 2001).problem(now),
        'Keep the notes under 2000 characters.',
      );
    });

    test('the booking the API gets', () {
      final json = InterviewDraft(
        scheduledAt: DateTime.utc(2026, 10, 27, 4, 30),
        title: ' Technical round ',
        mode: 'IN_PERSON',
        location: ' Floor 3 ',
        interviewerIds: const ['a', 'b'],
      ).toJson();
      expect(json, {
        'title': 'Technical round',
        'scheduledAt': '2026-10-27T04:30:00.000Z',
        'durationMins': 60,
        'mode': 'IN_PERSON',
        'location': 'Floor 3',
        'interviewerIds': ['a', 'b'],
      });
    });

    test('an offer needs a salary, and a reply-by date in the future', () {
      expect(const OfferDraft(amount: null).problem(now), 'Enter the salary you are offering.');
      expect(const OfferDraft(amount: 0).problem(now), 'Enter the salary you are offering.');
      expect(const OfferDraft(amount: 1000000000).problem(now), 'Enter an amount up to 999999999.');
      expect(OfferDraft(amount: 650000, expiresAt: now).problem(now), 'The reply-by date must be in the future.');
      expect(OfferDraft(amount: 650000, expiresAt: DateTime(2026, 11, 5)).problem(now), isNull);
      expect(
        OfferDraft(
          amount: 650000,
          jobTitle: ' Supervisor ',
          notes: ' hi ',
          joiningDate: DateTime.utc(2026, 12, 1),
        ).toJson(),
        {
          'salaryAmount': 650000,
          'salaryCurrency': 'INR',
          'salaryPeriod': 'YEARLY',
          'jobTitle': 'Supervisor',
          'joiningDate': '2026-12-01T00:00:00.000Z',
          'notes': 'hi',
        },
      );
    });
  });

  group('the pipeline', () {
    test('an application moves only where the API lets it (ALLOWED_APPLICATION_TRANSITIONS)', () {
      expect(stageMoves['APPLIED'], ['SCREENING', 'INTERVIEW', 'REJECTED']);
      expect(stageMoves['SCREENING'], ['INTERVIEW', 'REJECTED']);
      expect(stageMoves['INTERVIEW'], ['OFFER', 'REJECTED']);
      expect(stageMoves['OFFER'], ['HIRED', 'REJECTED']);
      expect(stageMoves['HIRED'], isEmpty);
      expect(stageMoves['REJECTED'], ['SCREENING', 'INTERVIEW']);
      expect(stageMoves['WITHDRAWN'], isEmpty);
    });

    test('the stages and moves are worded for the hiring team', () {
      expect(stageWord('SCREENING'), 'In review');
      expect(stageWord('REJECTED'), 'Not selected');
      expect(moveVerb('HIRED'), 'Mark as hired');
      expect(moveVerb('REJECTED'), 'Reject');
      expect(moveVerb('SCREENING'), 'Move to review');
      expect(pipelineStages, ['APPLIED', 'SCREENING', 'INTERVIEW', 'OFFER', 'HIRED', 'REJECTED']);
    });

    test('an applicant reads from the API and keeps their photo as an absolute link', () {
      final a = Applicant.fromJson({
        'id': 'A1',
        'jobId': 'J1',
        'applicantId': 'U1',
        'stage': 'INTERVIEW',
        'createdAt': '2026-10-20T10:00:00.000Z',
        'viewedAt': '2026-10-21T10:00:00.000Z',
        'rating': 4,
        'matchScore': 81.6,
        'expectedSalary': '1200000.00',
        'nextInterview': {'scheduledAt': '2026-10-30T10:00:00.000Z'},
        'latestOffer': {'status': 'SENT'},
        'qualification': {'met': 2, 'total': 3},
        'applicant': {
          'id': 'U1',
          'firstName': 'Aarav',
          'lastName': 'Khanna',
          'email': 'aarav@example.test',
          'avatarUrl': '/uploads/avatar/a.png',
          'profilePublic': true,
        },
        'resume': {
          'headline': 'Facilities Manager',
          'experienceYears': 11,
          'skills': ['HVAC'],
          'noticePeriodDays': 30,
          'fileUrl': '/uploads/resume/a.pdf',
        },
      }, apiBase: 'https://api.example.test/api/v1');
      expect(a.name, 'Aarav Khanna');
      expect(a.initials, 'AK');
      expect(a.userId, 'U1');
      expect(a.stage, 'INTERVIEW');
      expect(a.viewed, isTrue);
      expect(a.rating, 4);
      expect(a.matchScore, 82);
      expect(a.photoUrl, 'https://api.example.test/uploads/avatar/a.png');
      expect(a.resumeFileUrl, 'https://api.example.test/uploads/resume/a.pdf');
      expect(a.qualificationsMet, 2);
      expect(a.qualificationsTotal, 3);
      expect(a.offerStatus, 'SENT');
      expect(a.nextInterviewAt, isNotNull);
      expect(a.expectedSalary, 1200000);
      expect(a.noticePeriodDays, 30);
      expect(a.profilePublic, isTrue);
    });

    test('the activity trail is worded for people', () {
      ActivityEvent e(String type, {String? from, String? to, String? note, int? rating}) => ActivityEvent(
        type: type,
        at: DateTime(2026, 10, 26),
        fromStage: from,
        toStage: to,
        note: note,
        rating: rating,
      );
      expect(activityWords(e('STAGE_CHANGE', from: 'APPLIED', to: 'SCREENING')), 'Moved from applied to in review');
      expect(
        activityWords(e('STAGE_CHANGE', from: 'REJECTED', to: 'INTERVIEW', note: 'Second look')),
        'Moved from not selected to interview: Second look',
      );
      expect(activityWords(e('STAGE_CHANGE', to: 'APPLIED')), 'Applied');
      expect(activityWords(e('NOTE', note: 'Strong on audits')), 'Note: Strong on audits');
      expect(activityWords(e('RATING', rating: 1)), 'Rated 1 star');
      expect(activityWords(e('RATING', rating: 4)), 'Rated 4 stars');
      expect(activityWords(e('OFFER_SENT')), 'Offer sent');
      expect(activityWords(e('AUTO_ARCHIVED')), 'Not selected automatically: a must-have answer was missed');
      expect(activityWords(e('WITHDRAWN')), 'The applicant withdrew');
    });
  });

  group('the company\'s list', () {
    test('a posting counts its applicants without those who withdrew', () {
      final p = PostedJob.fromJson({
        'id': 'J1',
        'title': 'Facility Supervisor',
        'status': 'OPEN',
        'createdAt': '2026-10-01T10:00:00.000Z',
        'cities': ['Pune', 'Mumbai'],
        'pipeline': {
          'stages': {'APPLIED': 3, 'INTERVIEW': 1, 'WITHDRAWN': 2},
          'unviewed': 2,
        },
        'postedBy': {'firstName': 'Meera', 'lastName': 'Iyer'},
        '_count': {'screeningQuestions': 2},
      });
      expect(p.pipeline.total, 4);
      expect(p.pipeline.unviewed, 2);
      expect(p.pipeline.count('INTERVIEW'), 1);
      expect(p.place, 'Pune, Mumbai');
      expect(p.postedBy, 'Meera Iyer');
      expect(p.screeningQuestions, 2);
      expect(p.status, PostingStatus.open);
    });

    test('a draft that review sent back keeps the reviewer\'s note', () {
      final back = PostedJob.fromJson({
        'id': 'J2',
        'title': 'x',
        'status': 'DRAFT',
        'createdAt': '2026-10-01T10:00:00.000Z',
        'reviewNote': 'Add the salary range.',
        'reviewedAt': '2026-10-02T10:00:00.000Z',
      });
      expect(back.returned, isTrue);
      expect(back.copyWith(status: PostingStatus.open).returned, isFalse);
      expect(
        PostedJob.fromJson({
          'id': 'J3',
          'title': 'x',
          'status': 'DRAFT',
          'createdAt': '2026-10-01T10:00:00.000Z',
        }).returned,
        isFalse,
      );
    });

    test('what needs attention is worded', () {
      expect(
        const AttentionItem(kind: 'noApplicants', jobId: 'J', title: 'x', days: 17).words,
        startsWith('No applicants yet after 17 days.'),
      );
      expect(const AttentionItem(kind: 'closing', jobId: 'J', title: 'x', days: 0).words, 'Closes today.');
      expect(const AttentionItem(kind: 'closing', jobId: 'J', title: 'x', days: 3).words, 'Closes in 3 days.');
      expect(const AttentionItem(kind: 'other', jobId: 'J', title: 'x').words, 'Needs a look.');
    });

    test('only the hiring roles, with a company, may post', () {
      for (final role in ['SUPER_ADMIN', 'COMPANY_ADMIN', 'BRANCH_ADMIN', 'RECRUITER']) {
        expect(canHireWithRole(role), isTrue, reason: role);
      }
      for (final role in [
        'PROFESSIONAL',
        'VENDOR',
        'BUYER',
        'HIRING_MANAGER',
        'LEARNING_ADMIN',
        'PARTNER_ADMIN',
        null,
      ]) {
        expect(canHireWithRole(role), isFalse, reason: '$role');
      }
      expect(const HiringAccess(userId: 'u', role: 'RECRUITER', companyId: 'c').canManage, isTrue);
      expect(
        const HiringAccess(userId: 'u', role: 'RECRUITER').canManage,
        isFalse,
        reason: 'no company to post for',
      );
      expect(const HiringAccess(userId: 'u', role: 'PROFESSIONAL', companyId: 'c').canManage, isFalse);
      expect(const HiringAccess(userId: 'u', role: 'SUPER_ADMIN').canManage, isTrue);
    });
  });
}
