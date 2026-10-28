import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/features/jobs/apply_rules.dart';
import 'package:icr_mobile/features/jobs/api_jobs_repository.dart';
import 'package:icr_mobile/features/jobs/demo_jobs_repository.dart';
import 'package:icr_mobile/features/jobs/job_detail_controller.dart';
import 'package:icr_mobile/features/jobs/job_format.dart';
import 'package:icr_mobile/features/jobs/job_models.dart';
import 'package:icr_mobile/features/jobs/job_requirements.dart';
import 'package:icr_mobile/features/jobs/jobs_controller.dart';

import 'jobs_fakes.dart';

class _NoTokens extends TokenStore {
  @override
  Future<String?> accessToken() async => 'token';
  @override
  Future<String?> refreshToken() async => null;
}

/// Answers each route from a table and records the calls.
class _Api implements HttpClientAdapter {
  _Api(this.routes);

  final Map<String, Object Function(RequestOptions options)> routes;
  final List<String> calls = [];
  final List<RequestOptions> requests = [];

  /// The query of the last call to [path] (`GET /jobs` → its `queryParameters`).
  Map<String, dynamic> queryOf(String route) => requests
      .lastWhere((o) => '${o.method} ${o.path}' == route, orElse: () => throw StateError('no call to $route'))
      .queryParameters;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    calls.add(key);
    requests.add(options);
    final handler = routes[key];
    if (handler == null) return ResponseBody.fromString('{"message":"Not found"}', 404, headers: _json);
    final result = handler(options);
    if (result is (int, String)) return ResponseBody.fromString(result.$2, result.$1, headers: _json);
    return ResponseBody.fromString(jsonEncode(result), 200, headers: _json);
  }

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}

const _jobRow = {
  'id': 'j1',
  'title': 'Senior Facilities Manager',
  'city': 'Mumbai',
  'state': 'Maharashtra',
  'country': 'India',
  'workMode': 'ONSITE',
  'employmentType': 'FULL_TIME',
  'salaryMin': '1800000',
  'salaryMax': '2500000.00',
  'salaryPeriod': 'YEARLY',
  'salaryVisible': true,
  'publishedAt': '2026-10-19T08:00:00.000Z',
  'applyMethod': 'ON_PLATFORM',
  'skills': ['HVAC', 'BMS'],
  'category': 'FACILITY_MANAGEMENT',
  'department': 'Operations',
  'company': {'id': 'c1', 'name': 'CBRE South Asia', 'logoUrl': '/uploads/cbre.png', 'verificationLevel': 'VERIFIED'},
};

ApiJobsRepository _repo(_Api api, {int pageSize = 20}) {
  final client = ApiClient(tokens: _NoTokens(), baseUrl: 'http://api.test/api/v1');
  client.dio.httpClientAdapter = api;
  return ApiJobsRepository(api: client, pageSize: pageSize);
}

/// The routes every board read goes through, for a member with nothing special.
Map<String, Object Function(RequestOptions)> _board({
  List<Map<String, dynamic>> alerts = const [],
  List<Object> recommended = const [],
  Map<String, dynamic>? preferences,
}) => {
  'GET /jobs/actions': (_) => {'savedIds': [], 'hiddenIds': []},
  'GET /applications/mine': (_) => [],
  'GET /jobs/recommended': (o) => o.queryParameters['mode'] == 'foryou'
      ? {
          'data': recommended,
          'meta': {'total': recommended.length},
        }
      : preferences ??
            {
              'data': [],
              'meta': {'total': 0, 'hasNext': false},
            },
  'GET /jobs/alerts': (_) => alerts,
  'GET /jobs': (_) => {
    'data': [_jobRow],
    'meta': {'hasNext': false},
  },
};

const _alertRow = {
  'id': 'a1',
  'name': 'Facilities & Real Estate',
  'criteria': {'city': 'Bengaluru,Mumbai', 'country': 'India', 'page': 3, 'sortBy': 'createdAt', 'search': ''},
  'newMatchCount': 2,
};

void main() {
  group('formatting', () {
    test('a salary reads as the design writes it', () {
      final yearly = Job(
        id: 'a',
        title: 't',
        company: const JobCompany(id: 'c', name: 'C'),
        salaryMin: 1800000,
        salaryMax: 2500000,
      );
      expect(salaryLabel(yearly), '₹18L - ₹25L / yr');
      final monthly = Job(
        id: 'a',
        title: 't',
        company: const JobCompany(id: 'c', name: 'C'),
        salaryMin: 45000,
        salaryMax: 60000,
        salaryPeriod: 'MONTHLY',
      );
      expect(salaryLabel(monthly), '₹45K - ₹60K / mo');
      final hidden = Job(
        id: 'a',
        title: 't',
        company: const JobCompany(id: 'c', name: 'C'),
        salaryMin: 1,
        salaryVisible: false,
      );
      expect(salaryLabel(hidden), isNull);
    });

    test('posted ago counts days, then months', () {
      final now = DateTime(2026, 10, 22);
      expect(postedAgo(now.subtract(const Duration(days: 3)), now), 'Posted 3d ago');
      expect(postedAgo(now, now), 'Posted today');
      expect(postedAgo(now.subtract(const Duration(days: 45)), now), 'Posted 1mo ago');
    });

    test('a description becomes paragraphs, headings and items', () {
      final blocks = descriptionBlocks(DemoJobsRepository().detailJob.descriptionHtml);
      expect(blocks.first.kind, BlockKind.paragraph);
      expect(blocks.first.text, startsWith('We are seeking'));
      expect(blocks[1].kind, BlockKind.heading);
      expect(blocks[1].text, 'Key Responsibilities');
      expect(blocks.where((b) => b.kind == BlockKind.item).length, 4);
      expect(blocks.last.text, contains('soft & hard'));

      final plain = descriptionBlocks('First paragraph.\n\nSecond one.');
      expect(plain.map((b) => b.text), ['First paragraph.', 'Second one.']);
    });

    test('the count after "Posted 3d ago" is applicants, else views, else openings', () {
      Job job({int? applicants, int? views, int? openings}) => Job(
        id: 'a',
        title: 't',
        company: const JobCompany(id: 'c', name: 'C'),
        applicants: applicants,
        views: views,
        openings: openings,
      );
      expect(applicantsOrOpenings(job(applicants: 142, views: 900, openings: 2)), '142 applicants');
      expect(applicantsOrOpenings(job(applicants: 1)), '1 applicant');
      expect(applicantsOrOpenings(job(views: 310, openings: 2)), '310 views');
      expect(applicantsOrOpenings(job(openings: 2)), '2 openings');
      expect(applicantsOrOpenings(job(openings: 1)), '1 opening');
      expect(applicantsOrOpenings(job()), isNull);
    });

    test('a tagline is the industry, else a short first sentence', () {
      expect(companyIndustryLabel('CRE_SERVICES'), 'Commercial Real Estate Services');
      expect(companyIndustryLabel('FM_SERVICES'), 'Facility Management Services');
      expect(companyIndustryLabel('nothing'), isNull);
      expect(companyKindLabel('REAL_ESTATE'), 'Real Estate');
      expect(shortFirstSentence('Workplace and asset management. Founded in 1999.'), 'Workplace and asset management');
      expect(
        shortFirstSentence('Leading Indian commercial real estate management operator handling 42M+ sq.ft. of parks.'),
        isNull,
        reason: 'too long for the line under the name',
      );
      expect(shortFirstSentence('  '), isNull);
      expect(shortFirstSentence(null), isNull);
    });
  });

  group('what a job asks for, held against the profile', () {
    final job = Job(
      id: 'j',
      title: 't',
      company: const JobCompany(id: 'c', name: 'C'),
      experienceMin: 8,
      educationQualifications: const ['UG_BTECH_MECHANICAL', 'UG_BTECH_ELECTRICAL'],
      preferredQualifications: const ['RICS or IFMA Facility Management Charter'],
      skills: const ['HVAC', 'BMS'],
    );
    const btech = EducationEntry(degree: 'B.Tech', field: 'Mechanical Engineering');

    test('builds the design\'s rows: years, degree, credentials, then skills', () {
      final checks = requirementChecks(job, const MemberFacts(years: 9.4, skills: {'hvac'}, education: [btech]));
      expect(checks.map((c) => c.label), [
        '8+ years of experience',
        'B.Tech / B.E. in Mechanical or Electrical',
        'RICS or IFMA Facility Management Charter',
        'HVAC',
        'BMS',
      ]);
      expect(checks.map((c) => c.met), [true, true, false, true, false]);
      expect(checks[0].detail, 'Your résumé lists 9.4 years of experience.');
      expect(checks[1].detail, 'Your profile lists B.Tech, Mechanical Engineering.');
      expect(checks[2].detail, 'Preferred credential. Not on your profile yet.');
      expect(checks[3].detail, 'Listed on your résumé.');
      expect(checks[4].detail, 'Not on your résumé yet.');
    });

    test('years the profile does not say, or too few, are not met', () {
      expect(requirementChecks(job, const MemberFacts()).first.met, isFalse);
      expect(requirementChecks(job, const MemberFacts()).first.detail, 'Add your years of experience to your profile.');
      final few = requirementChecks(job, const MemberFacts(years: 4)).first;
      expect(few.met, isFalse);
      expect(few.detail, 'Your résumé lists 4 years of experience.');
      expect(
        requirementChecks(job, const MemberFacts(years: 1)).first.detail,
        'Your résumé lists 1 year of experience.',
      );
      expect(requirementChecks(job, const MemberFacts(years: 8)).first.met, isTrue, reason: '8 meets 8+');
    });

    test('a job asking for no years has no years row', () {
      final open = Job(
        id: 'j',
        title: 't',
        company: const JobCompany(id: 'c', name: 'C'),
        experienceMin: 0,
      );
      expect(requirementChecks(open, const MemberFacts(years: 3)), isEmpty);
    });

    test('a degree is found by what it is called, and by its specialisation', () {
      bool met(EducationEntry e) => requirementChecks(job, MemberFacts(education: [e]))[1].met;
      expect(met(btech), isTrue);
      expect(met(const EducationEntry(degree: 'B.E.', field: 'Electrical and Electronics')), isTrue);
      expect(met(const EducationEntry(degree: 'Bachelor of Engineering', field: 'Mechanical')), isTrue);
      expect(met(const EducationEntry(degree: 'B.Tech / B.E.', field: 'Electrical')), isTrue);
      expect(
        met(const EducationEntry(degree: 'B.Tech', field: 'Civil Engineering')),
        isFalse,
        reason: 'wrong stream',
      );
      expect(
        met(const EducationEntry(degree: 'B.Sc', field: 'Mechanical')),
        isFalse,
        reason: 'wrong degree',
      );
      expect(met(const EducationEntry(degree: 'MBA')), isFalse);
      expect(met(const EducationEntry(institution: 'Somewhere')), isFalse, reason: 'no degree named');
    });

    test('a degree key with no specialisation takes any, and "any graduate" any graduate degree', () {
      Job needing(List<String> keys) => Job(
        id: 'j',
        title: 't',
        company: const JobCompany(id: 'c', name: 'C'),
        educationQualifications: keys,
      );
      bool met(List<String> keys, EducationEntry e) =>
          requirementChecks(needing(keys), MemberFacts(education: [e])).single.met;
      expect(met(['UG_BTECH'], const EducationEntry(degree: 'B.Tech', field: 'Civil')), isTrue);
      expect(met(['UG_ANY'], const EducationEntry(degree: 'B.Sc')), isTrue);
      expect(met(['UG_ANY'], const EducationEntry(degree: 'MBA')), isFalse);
      expect(met(['PG_ANY'], const EducationEntry(degree: 'MBA')), isTrue);
      expect(met(['PG_MBA_FINANCE'], const EducationEntry(degree: 'MBA', field: 'Finance & Accounting')), isTrue);
      expect(
        met(['PG_DIPLOMA'], const EducationEntry(degree: 'Diploma in Civil')),
        isFalse,
        reason: 'that is a UG diploma',
      );
    });

    test('with no education on the profile the row says to add it; "not required" makes no row', () {
      expect(requirementChecks(job, const MemberFacts())[1].detail, 'Add your education to your profile.');
      final none = Job(
        id: 'j',
        title: 't',
        company: const JobCompany(id: 'c', name: 'C'),
        educationQualifications: const ['NOT_REQUIRED'],
      );
      expect(requirementChecks(none, const MemberFacts()), isEmpty);
    });

    test('degrees are worded as the composer words them', () {
      expect(degreesLabel(['UG_BTECH']), 'B.Tech / B.E.');
      expect(degreesLabel(['UG_BTECH', 'UG_BTECH_CIVIL']), 'B.Tech / B.E.');
      expect(degreesLabel(['UG_BTECH_MECHANICAL', 'UG_BTECH_ELECTRICAL']), 'B.Tech / B.E. in Mechanical or Electrical');
      expect(
        degreesLabel(['PG_MBA_FINANCE', 'PG_MBA_MARKETING', 'PG_MBA_HR']),
        'MBA / PGDM in Finance, Marketing or HR',
      );
      expect(degreesLabel(['UG_ANY']), 'A graduate degree');
      expect(degreesLabel(['UG_BCOM', 'PG_MCOM']), 'B.Com or M.Com');
      expect(degreesLabel(['NOT_REQUIRED', 'garbage']), '');
    });

    test('a qualification the employer wrote is found by its acronym or as a whole', () {
      final asks = Job(
        id: 'j',
        title: 't',
        company: const JobCompany(id: 'c', name: 'C'),
        qualifications: const ['NEBOSH International General Certificate'],
        preferredQualifications: const ['RICS or IFMA Facility Management Charter'],
      );
      final held = requirementChecks(asks, const MemberFacts(credentials: ['RICS Chartered Surveyor']));
      expect(held.map((c) => c.met), [false, true]);
      expect(held[1].detail, 'Preferred credential. Listed on your profile.');
      final whole = requirementChecks(
        asks,
        const MemberFacts(credentials: ['NEBOSH International General Certificate (2021)']),
      );
      expect(whole.map((c) => c.met), [true, false]);
    });
  });

  group('the search query', () {
    const scope = JobContext(
      label: 'Facilities & Real Estate',
      criteria: {'city': 'Bengaluru,Mumbai', 'country': 'India'},
    );

    test('carries the filters under the API\'s names', () {
      final query = jobsQuery(
        const JobFilters(
          search: 'stp',
          postedWithinDays: 7,
          workModes: {WorkMode.onsite, WorkMode.hybrid},
          employmentTypes: {EmploymentType.fullTime, EmploymentType.contract},
          city: 'Pune',
        ),
        page: 2,
        limit: 20,
      );
      expect(query, {
        'page': 2,
        'limit': 20,
        'search': 'stp',
        'postedWithinDays': 7,
        'workMode': 'ONSITE,HYBRID',
        'employmentType': 'FULL_TIME,CONTRACT',
        'city': 'Pune',
      });
    });

    test('asks for nothing the member did not set; Easy Apply is not a query', () {
      expect(jobsQuery(const JobFilters()), {'page': 1, 'limit': 20});
    });

    test('lays the saved search under it, and the member\'s own city takes the search\'s place', () {
      expect(jobsQuery(const JobFilters(search: 'stp'), scope: scope), {
        'city': 'Bengaluru,Mumbai',
        'country': 'India',
        'page': 1,
        'limit': 20,
        'search': 'stp',
      });
      expect(jobsQuery(const JobFilters(city: 'Pune'), scope: scope)['city'], 'Pune');
    });
  });

  group('the API source', () {
    test('maps a board row, with the bookmark from the actions list', () async {
      final api = _Api({
        ..._board(
          recommended: [
            {..._jobRow, 'matchScore': 88},
          ],
        ),
        'GET /jobs/actions': (_) => {
          'savedIds': ['j1'],
          'hiddenIds': [],
        },
        'GET /jobs': (_) => {
          'data': [_jobRow],
          'meta': {'hasNext': true},
        },
      });
      final overview = await _repo(api).overview();
      final recommended = overview.sections.firstWhere((s) => s.key == 'foryou');
      final job = recommended.jobs.single;
      expect(job.title, 'Senior Facilities Manager');
      expect(job.company.name, 'CBRE South Asia');
      expect(job.company.logo?.url, 'http://api.test/uploads/cbre.png');
      expect(job.company.verified, isTrue);
      expect(job.salaryMin, 1800000);
      expect(job.salaryMax, 2500000);
      expect(job.workMode, WorkMode.onsite);
      expect(job.employmentType, EmploymentType.fullTime);
      expect(job.place, 'Mumbai, India');
      expect(job.matchScore, 88);
      expect(job.saved, isTrue);
      expect(job.easyApply, isTrue);
      expect(job.highlight, 'Facility management • Operations');
      final latest = overview.sections.firstWhere((s) => s.key == 'latest');
      expect(latest.hasMore, isTrue);
    });

    test('the saved search is the third section, read without being run', () async {
      final api = _Api({
        ..._board(alerts: [_alertRow], recommended: [_jobRow]),
        'GET /jobs': (_) => {
          'data': [_jobRow],
          'meta': {'hasNext': true},
        },
      });
      final overview = await _repo(api).overview();
      final alert = overview.alert!;
      expect(alert.label, 'Facilities & Real Estate');
      expect(alert.place, 'Bengaluru, IN');
      expect(alert.alertId, 'a1');
      expect(alert.criteria, {
        'city': 'Bengaluru,Mumbai',
        'country': 'India',
      }, reason: 'paging and empty filters left out');
      expect(overview.newAlerts, 2);
      final section = overview.sections.last;
      expect(section.key, 'alert');
      expect(section.title, 'Facilities & Real Estate');
      expect(section.hasMore, isTrue);
      expect(api.queryOf('GET /jobs'), {'city': 'Bengaluru,Mumbai', 'country': 'India', 'page': 1, 'limit': 20});
      expect(
        api.calls,
        isNot(contains('GET /jobs/alerts/a1/run')),
        reason: 'opening the board must not mark them seen',
      );
    });

    test('without the scope the third section is the latest jobs, and the search is still there to run', () async {
      final api = _Api(_board(alerts: [_alertRow]));
      final overview = await _repo(api).overview(scoped: false);
      expect(overview.sections.last.key, 'latest');
      expect(overview.alert, isNotNull);
      expect(api.queryOf('GET /jobs').containsKey('city'), isFalse);
    });

    test('a saved search the board cannot read falls back to the latest jobs', () async {
      final api = _Api({
        ..._board(alerts: [_alertRow]),
        'GET /jobs': (o) => o.queryParameters.containsKey('city')
            ? (400, '{"message":"Invalid filter"}')
            : {
                'data': [_jobRow],
                'meta': {'hasNext': false},
              },
      });
      final overview = await _repo(api).overview();
      expect(overview.sections.last.key, 'latest');
      expect(overview.sections.last.jobs, hasLength(1));
    });

    test('running the saved search marks it seen, and the badge is read again', () async {
      var fresh = 2;
      final api = _Api({
        ..._board(alerts: [_alertRow]),
        'GET /jobs/alerts': (_) => [
          {..._alertRow, 'newMatchCount': fresh},
        ],
        'GET /jobs/alerts/a1/run': (_) {
          fresh = 0;
          return {
            'data': [_jobRow],
            'meta': {'hasNext': false},
          };
        },
      });
      final repo = _repo(api);
      final overview = await repo.overview();
      final page = await repo.runAlert(overview.alert!);
      expect(page.jobs, hasLength(1));
      expect(await repo.newAlertMatches(), 0);
    });

    test('View More pages the saved search, the latest jobs and the recommended sections', () async {
      final api = _Api({
        ..._board(
          alerts: [_alertRow],
          recommended: [
            for (var i = 0; i < 12; i++) {..._jobRow, 'id': 'r$i'},
          ],
        ),
        'GET /jobs/recommended': (o) {
          final limit = o.queryParameters['limit'] as int;
          return {
            'data': [
              for (var i = 0; i < limit; i++) {..._jobRow, 'id': 'r$i'},
            ],
            'meta': {'total': limit},
          };
        },
      });
      final repo = _repo(api, pageSize: 5);
      final overview = await repo.overview();
      final foryou = overview.sections.firstWhere((s) => s.key == 'foryou');
      expect(foryou.jobs, hasLength(12));
      expect(foryou.hasMore, isTrue, reason: 'a full 12 may have more');

      final alert = overview.sections.firstWhere((s) => s.key == 'alert');
      await repo.more(alert, 2);
      expect(api.queryOf('GET /jobs'), {'city': 'Bengaluru,Mumbai', 'country': 'India', 'page': 2, 'limit': 5});

      final extra = await repo.more(foryou, 2);
      expect(api.queryOf('GET /jobs/recommended')['limit'], 24);
      expect(extra.jobs.map((j) => j.id), [
        for (var i = 12; i < 24; i++) 'r$i',
      ], reason: 'only the rows after the first 12');
      expect(extra.hasMore, isFalse, reason: '24 is the most the API gives');

      await repo.latest(page: 3);
      expect(api.queryOf('GET /jobs'), {'page': 3, 'limit': 5});
    });

    test('preferences know how many there are, so View More shows only when there are more', () async {
      final api = _Api(
        _board(
          preferences: {
            'data': [_jobRow],
            'meta': {'total': 30, 'hasNext': true},
          },
        ),
      );
      final overview = await _repo(api).overview();
      expect(overview.sections.firstWhere((s) => s.key == 'preferences').hasMore, isTrue);
    });

    test('an employer that takes applications on its own site is not Easy Apply', () async {
      final api = _Api({
        'GET /jobs/actions': (_) => {'savedIds': [], 'hiddenIds': []},
        'GET /applications/mine': (_) => [
          {'jobId': 'j1', 'stage': 'APPLIED'},
          {'jobId': 'j9', 'stage': 'WITHDRAWN'},
        ],
        'GET /jobs/j1': (_) => {..._jobRow, 'applyMethod': 'EXTERNAL_URL', 'applyUrl': 'https://jobs.cbre.com/1'},
        'GET /companies/c1': (_) => {
          'id': 'c1',
          'name': 'CBRE South Asia',
          'tagline': 'Real estate services',
          'size': '500+',
        },
      });
      final job = await _repo(api).detail('j1');
      expect(job.easyApply, isFalse);
      expect(job.externalApply, isTrue);
      expect(job.applied, isTrue);
      expect(job.company.tagline, 'Real estate services');
      expect(job.company.size, '500+ employees');
    });

    test('the company\'s industry is its tagline, its first photo the About tile, and its type the kind', () async {
      final api = _Api({
        'GET /jobs/actions': (_) => {'savedIds': [], 'hiddenIds': []},
        'GET /applications/mine': (_) => [],
        'GET /jobs/j1': (_) => _jobRow,
        'GET /companies/c1': (_) => {
          'id': 'c1',
          'name': 'Global Infra Solutions',
          'type': 'REAL_ESTATE',
          'industry': 'CRE_SERVICES',
          'size': '500+',
          'description': 'Leading Indian commercial real estate management operator handling 42M+ sq.ft. of parks.',
          'gallery': ['/uploads/photo.png', '/uploads/other.png'],
        },
      });
      final company = (await _repo(api).detail('j1')).company;
      expect(company.tagline, 'Commercial Real Estate Services');
      expect(company.kind, 'Real Estate');
      expect(company.size, '500+ employees');
      expect(company.cover?.url, 'http://api.test/uploads/photo.png');
      expect(company.legalName, isNull, reason: 'the API keeps it private to the company');
    });

    test('with no industry a short first sentence stands in; a long one does not', () async {
      Future<JobCompany> companyWith(String description) async {
        final api = _Api({
          'GET /jobs/actions': (_) => {'savedIds': [], 'hiddenIds': []},
          'GET /applications/mine': (_) => [],
          'GET /jobs/j1': (_) => _jobRow,
          'GET /companies/c1': (_) => {'id': 'c1', 'name': 'C', 'type': 'REAL_ESTATE', 'description': description},
        });
        return (await _repo(api).detail('j1')).company;
      }

      expect(
        (await companyWith('Workplace and asset management. More text here.')).tagline,
        'Workplace and asset management',
      );
      // Too long: the sheet falls back to the company's kind under the name.
      expect(
        (await companyWith(
          'A very long first sentence that goes on and on about what the business does for people.',
        )).tagline,
        isNull,
      );
    });

    test('a candidate\'s read has no counts; a team member\'s has them', () async {
      Future<Job> read(Map<String, dynamic> extra) async {
        final api = _Api({
          'GET /jobs/actions': (_) => {'savedIds': [], 'hiddenIds': []},
          'GET /applications/mine': (_) => [],
          'GET /jobs/j1': (_) => {..._jobRow, 'openings': 2, ...extra},
          'GET /companies/c1': (_) => {'id': 'c1', 'name': 'C'},
        });
        return _repo(api).detail('j1');
      }

      final candidate = await read({});
      expect(candidate.applicants, isNull);
      expect(candidate.views, isNull);
      expect(applicantsOrOpenings(candidate), '2 openings');
      final team = await read({
        'viewCount': 310,
        '_count': {'applications': 12},
      });
      expect(applicantsOrOpenings(team), '12 applicants');
    });

    test('maps what a job asks for: degrees, credentials and the hiring contact', () async {
      final api = _Api({
        'GET /jobs/actions': (_) => {'savedIds': [], 'hiddenIds': []},
        'GET /applications/mine': (_) => [],
        'GET /jobs/j1': (_) => {
          ..._jobRow,
          'experienceMin': 8,
          'educationQualifications': ['UG_BTECH_MECHANICAL'],
          'preferredQualifications': ['RICS or IFMA Facility Management Charter'],
          'hiringContact': {
            'name': 'Priya Sharma',
            'role': 'POSTER',
            'designation': 'Lead Talent Partner',
            'avatarUrl': '/uploads/p.png',
          },
        },
        'GET /companies/c1': (_) => {'id': 'c1', 'name': 'C'},
      });
      final job = await _repo(api).detail('j1');
      expect(job.experienceMin, 8);
      expect(job.educationQualifications, ['UG_BTECH_MECHANICAL']);
      expect(job.preferredQualifications, ['RICS or IFMA Facility Management Charter']);
      expect(job.contact?.name, 'Priya Sharma');
      expect(job.contact?.role, 'Job poster');
      expect(job.contact?.degree, isNull, reason: 'no connection model');
      expect(job.contact?.activity, isNull, reason: 'no last-seen for a person');
    });

    test('the people strip carries their photos and the count', () async {
      final api = _Api({
        'GET /companies/c1/people': (_) => {
          'data': [
            {'id': 'p1', 'firstName': 'Nikhil', 'lastName': 'Menon', 'avatarUrl': null},
            {'id': 'p2', 'firstName': 'Priya', 'lastName': 'Sharma', 'avatarUrl': '/uploads/priya.png'},
          ],
          'meta': {'total': 5},
        },
      });
      final people = await _repo(api).peopleAt(const JobCompany(id: 'c1', name: 'C'));
      expect(people!.names, ['Nikhil M.', 'Priya S.']);
      expect(people.photos[0], isNull);
      expect(people.photos[1]?.url, 'http://api.test/uploads/priya.png');
      expect(people.total, 5);
      expect(people.others, 4);
      expect(people.text, 'Nikhil M. and 4 others from ICR work at this organization.');
      expect(people.initials, ['NM', 'PS']);
    });

    test('My jobs lists the open applications and the saved jobs', () async {
      final api = _Api({
        'GET /jobs/actions': (_) => {
          'savedIds': ['j1'],
          'hiddenIds': [],
        },
        'GET /applications/mine': (_) => [
          {
            'id': 'app1',
            'jobId': 'j2',
            'stage': 'INTERVIEW',
            'createdAt': '2026-10-20T08:00:00.000Z',
            'job': {
              'id': 'j2',
              'title': 'Energy Lead',
              'companyId': 'c2',
              'city': 'Pune',
              'company': {'name': 'Global Infra', 'logoUrl': '/uploads/g.png'},
            },
          },
          {
            'id': 'app2',
            'jobId': 'j3',
            'stage': 'WITHDRAWN',
            'job': {
              'id': 'j3',
              'title': 'Old',
              'companyId': 'c2',
              'company': {'name': 'Global Infra'},
            },
          },
        ],
        'GET /jobs/saved': (_) => {
          'data': [_jobRow],
          'meta': {'hasNext': false},
        },
      });
      final mine = await _repo(api).myJobs();
      expect(mine.applications, hasLength(1), reason: 'a withdrawn application is not one of "My jobs"');
      final app = mine.applications.single;
      expect(app.id, 'app1');
      expect(app.job.title, 'Energy Lead');
      expect(app.job.company.name, 'Global Infra');
      expect(app.job.place, 'Pune, India');
      expect(app.stageLabel, 'Interview');
      expect(app.appliedAt, DateTime.utc(2026, 10, 20, 8));
      expect(mine.saved.single.id, 'j1');
      expect(mine.saved.single.saved, isTrue);
    });

    test('without Career Pro the match is what the job asks for, held against the profile', () async {
      final api = _Api({
        'GET /jobs/j1/match-preview': (_) => (403, '{"statusCode":403,"message":"Upgrade to Career Pro"}'),
        'GET /users/me/profile': (_) => {
          'resume': {
            'yearsExperience': 9.4,
            'skills': ['hvac', 'Energy'],
          },
        },
        'GET /profile/education': (_) => [
          {'institution': 'VTU', 'degree': 'B.Tech', 'fieldOfStudy': 'Mechanical Engineering'},
        ],
        'GET /credentials/me': (_) => {'credentials': []},
      });
      final job = Job(
        id: 'j1',
        title: 't',
        company: const JobCompany(id: 'c', name: 'C'),
        experienceMin: 8,
        educationQualifications: const ['UG_BTECH_MECHANICAL'],
        skills: const ['HVAC', 'BMS'],
      );
      final match = await _repo(api).match(job);
      expect(match!.locked, isTrue);
      expect(match.checks.map((c) => c.label), [
        '8+ years of experience',
        'B.Tech / B.E. in Mechanical',
        'HVAC',
        'BMS',
      ]);
      expect(match.checks.map((c) => c.met), [true, true, true, false]);
      expect(match.met, 3);
    });

    test('a profile that cannot be read counts as empty, and the card still has its rows', () async {
      final api = _Api({'GET /jobs/j1/match-preview': (_) => (403, '{"message":"Upgrade"}')});
      final job = Job(
        id: 'j1',
        title: 't',
        company: const JobCompany(id: 'c', name: 'C'),
        experienceMin: 8,
        skills: const ['HVAC'],
      );
      final match = await _repo(api).match(job);
      expect(match!.checks.map((c) => c.met), [false, false]);
    });

    test('the AI preview, when it answers, gives the rows', () async {
      final api = _Api({
        'GET /jobs/j1/match-preview': (_) => {
          'matchScore': 91,
          'signals': [
            {'label': '8+ years Facility & MEP', 'detail': 'Your resume lists 9.4 years.', 'score': 0.9},
            {'label': 'RICS charter', 'detail': 'Preferred.', 'score': 0.2},
          ],
        },
      });
      final job = Job(
        id: 'j1',
        title: 't',
        company: const JobCompany(id: 'c', name: 'C'),
      );
      final match = await _repo(api).match(job);
      expect(match!.locked, isFalse);
      expect(match.score, 91);
      expect(match.checks.map((c) => c.met), [true, false]);
    });

    test('a job with nothing to compare has no card', () async {
      final api = _Api({'GET /jobs/j1/match-preview': (_) => (403, '{"message":"Upgrade"}')});
      final job = Job(
        id: 'j1',
        title: 't',
        company: const JobCompany(id: 'c', name: 'C'),
      );
      expect(await _repo(api).match(job), isNull);
    });

    test('an application sends the note and the phone, and counts toward My jobs', () async {
      final api = _Api({
        'GET /jobs/actions': (_) => {'savedIds': [], 'hiddenIds': []},
        'GET /applications/mine': (_) => [],
        'POST /jobs/j1/apply': (o) => {'id': 'app1', 'data': o.data},
        'GET /jobs/j1': (_) => _jobRow,
        'GET /companies/c1': (_) => {'id': 'c1', 'name': 'C'},
      });
      final repo = _repo(api);
      final job = await repo.detail('j1');
      await repo.apply(job, phone: ' +91 98765 43210 ', coverNote: ' Keen. ');
      final sent = api.requests.lastWhere((o) => o.method == 'POST').data as Map;
      expect(sent, {'phone': '+91 98765 43210', 'coverNote': 'Keen.'});
      await repo.apply(job);
      expect(api.requests.last.data, <String, dynamic>{});
    });
  });

  group('a scorer that is down', () {
    final job = Job(
      id: 'j1',
      title: 't',
      company: const JobCompany(id: 'c', name: 'C'),
      skills: const ['HVAC', 'BMS'],
    );

    test('still gives the comparison', () async {
      final api = _Api({
        'GET /jobs/j1/match-preview': (_) => (500, '{"statusCode":500,"message":"Internal server error"}'),
        'GET /users/me/profile': (_) => {
          'resume': {
            'skills': ['hvac'],
          },
        },
      });
      final match = await _repo(api).match(job);
      expect(match!.locked, isTrue);
      expect(match.checks.map((c) => c.met), [true, false]);
    });

    test('does not take the people strip, or the board score, with it', () async {
      final demo = DemoJobsRepository();
      final seed = (await demo.overview()).sections.first.jobs.first.copyWith(matchScore: 92);
      final controller = JobDetailController(repository: _ScorerDown(), seed: seed);

      await controller.load();

      expect(controller.error, isNull);
      expect(controller.match, isNull);
      expect(controller.people, isNotNull);
      expect(controller.job.matchScore, 92);
    });
  });

  group('the board', () {
    test('shows three rows a section until View More, and rolls a refused bookmark back', () async {
      final repo = SpyJobsRepository()..setSavedError = ApiError('No bookmarks today.', statusCode: 403);
      final jobs = JobsController(repo);
      await jobs.start();
      final section = jobs.sections.first;
      expect(jobs.visible(section).length, 3);
      expect(jobs.showsMore(section), isTrue);
      await jobs.expand(section);
      expect(jobs.isExpanded(section), isTrue);

      final job = section.jobs.first;
      final message = await jobs.toggleSave(job);
      expect(message, 'No bookmarks today.');
      expect(jobs.find(job.id)!.saved, isFalse);
    });

    test('a bookmark that goes through stays, and is undone by the same control', () async {
      final repo = SpyJobsRepository();
      final jobs = JobsController(repo);
      await jobs.start();
      final job = jobs.sections.first.jobs.first;
      expect(await jobs.toggleSave(job), isNull);
      expect(jobs.find(job.id)!.saved, isTrue);
      expect(await jobs.toggleSave(jobs.find(job.id)!), isNull);
      expect(jobs.find(job.id)!.saved, isFalse);
      expect(repo.saves.map((s) => s.saved), [true, false]);
    });

    test('a search narrows the board to one list', () async {
      final jobs = JobsController(DemoJobsRepository());
      await jobs.start();
      expect(jobs.sections.length, 3);
      await jobs.setSearch('STP');
      expect(jobs.narrowed, isTrue);
      expect(jobs.sections.single.jobs, isNotEmpty);
      await jobs.setSearch('');
      expect(jobs.sections.length, 3);
    });

    test('View More shows the rest, then the next page, and Show Less folds it back', () async {
      final repo = SpyJobsRepository()
        ..overviewAnswer = ((_) => JobsOverview(
          sections: [
            JobSection(
              key: 'alert',
              title: 'Facilities & Real Estate',
              jobs: [for (var i = 0; i < 5; i++) fakeJob('a$i')],
              hasMore: true,
            ),
          ],
        ))
        ..moreAnswer = (section, page) =>
            JobPage(jobs: [fakeJob('p${page}a'), fakeJob('p${page}b')], hasMore: page < 2);
      final jobs = JobsController(repo);
      await jobs.start();
      var section = jobs.sections.single;
      expect(jobs.visible(section), hasLength(3));
      expect(jobs.actionLabel(section), 'View More');

      await jobs.act(section);
      section = jobs.sections.single;
      expect(jobs.visible(section), hasLength(5), reason: 'the five loaded, with no fetch');
      expect(repo.calls.where((c) => c.startsWith('more')), isEmpty);
      expect(jobs.actionLabel(section), 'View More', reason: 'the API has another page');

      await jobs.act(section);
      section = jobs.sections.single;
      expect(repo.calls.where((c) => c.startsWith('more')), ['more alert 2']);
      expect(jobs.visible(section), hasLength(7));
      expect(jobs.actionLabel(section), 'Show Less', reason: 'everything is on show');

      await jobs.act(section);
      section = jobs.sections.single;
      expect(jobs.visible(section), hasLength(3));
      expect(jobs.actionLabel(section), 'View More');
    });

    test('a section of three has no View More, one of four has', () async {
      Future<JobsController> board(int rows) async {
        final repo = SpyJobsRepository()
          ..overviewAnswer = ((_) => JobsOverview(
            sections: [
              JobSection(
                key: 'foryou',
                title: 'Recommended Jobs for You',
                jobs: [for (var i = 0; i < rows; i++) fakeJob('a$i')],
              ),
            ],
          ));
        final jobs = JobsController(repo);
        await jobs.start();
        return jobs;
      }

      final three = await board(3);
      expect(three.actionLabel(three.sections.single), isNull);
      final four = await board(4);
      expect(four.actionLabel(four.sections.single), 'View More');
    });

    test('Easy Apply is on to begin with, and trims the jobs that send people to the employer\'s site', () async {
      final repo = SpyJobsRepository()
        ..overviewAnswer = ((_) => JobsOverview(
          sections: [
            JobSection(
              key: 'foryou',
              title: 'Recommended Jobs for You',
              jobs: [
                fakeJob('a'),
                fakeJob('b', easyApply: false, applyUrl: 'https://x.test/b'),
                fakeJob('c'),
              ],
            ),
          ],
        ));
      final jobs = JobsController(repo);
      await jobs.start();
      final section = jobs.sections.single;
      expect(jobs.filters.easyApply, isTrue);
      expect(jobs.jobsOf(section).map((j) => j.id), ['a', 'c']);

      jobs.toggleEasyApply();
      expect(jobs.filters.easyApply, isFalse);
      expect(jobs.jobsOf(section).map((j) => j.id), ['a', 'b', 'c']);
      expect(repo.calls.where((c) => c.startsWith('overview')), hasLength(1), reason: 'no reload for a toggle');
    });

    test(
      '"Filters (n)" counts every filter in force, the saved search\'s included while it scopes the board',
      () async {
        final jobs = JobsController(SpyJobsRepository());
        await jobs.start();
        expect(jobs.context?.criteria, {'city': 'Bengaluru', 'country': 'India'});
        expect(jobs.filterCount, 3, reason: 'Easy Apply, and the saved search\'s city and country');

        await jobs.setPostedWithin(7);
        expect(jobs.filterCount, 4);
        await jobs.setFilters(jobs.filters.copyWith(city: 'Pune', workModes: {WorkMode.remote}));
        expect(
          jobs.filterCount,
          5,
          reason: 'Easy Apply, the date, remote, Pune (in place of the saved search\'s city) and its country',
        );

        await jobs.clearContext();
        expect(jobs.filterCount, 4, reason: 'the saved search\'s country goes with its scope');
        jobs.toggleEasyApply();
        expect(jobs.filterCount, 3);
      },
    );

    test('the cross drops the saved search: the board reloads unscoped, and so does a search over it', () async {
      final repo = SpyJobsRepository();
      final jobs = JobsController(repo);
      await jobs.start();
      expect(jobs.context, isNotNull);

      await jobs.clearContext();
      expect(jobs.context, isNull);
      expect(repo.calls.last, 'overview scoped=false');
      expect(jobs.hasAlert, isTrue, reason: 'the saved search is still there to run');

      await jobs.setSearch('stp');
      expect(repo.searches.last.scope, isNull);
    });

    test('a search typed over the scope is made inside it', () async {
      final repo = SpyJobsRepository();
      final jobs = JobsController(repo);
      await jobs.start();
      await jobs.setSearch('stp');
      expect(repo.searches.last.scope?.label, 'Facilities & Real Estate');
      expect(repo.searches.last.filters.search, 'stp');
    });

    test('the date goes to the search as days, and "any time" takes it away', () async {
      final repo = SpyJobsRepository();
      final jobs = JobsController(repo);
      await jobs.start();
      await jobs.setPostedWithin(7);
      expect(repo.searches.last.filters.postedWithinDays, 7);
      expect(jobs.narrowed, isTrue);
      await jobs.setPostedWithin(null);
      expect(jobs.narrowed, isFalse);
      expect(jobs.filters.postedWithinDays, isNull);
    });

    test(
      'Alerts runs the saved search, shows its results open, clears the badge and restores a dropped scope',
      () async {
        final repo = SpyJobsRepository();
        final jobs = JobsController(repo);
        await jobs.start();
        expect(jobs.newAlerts, 2);
        await jobs.clearContext();
        await jobs.setSearch('stp');

        expect(await jobs.runAlert(), isNull);

        expect(repo.calls, contains('runAlert'));
        expect(jobs.newAlerts, 0);
        expect(jobs.context, isNotNull, reason: 'the scope is back');
        expect(jobs.narrowed, isFalse, reason: 'a search laid over the board would hide the section');
        final section = jobs.sections.firstWhere((s) => s.key == 'alert');
        expect(jobs.isExpanded(section), isTrue);
      },
    );

    test('Alerts with no saved search does nothing here (the screen opens the website to make one)', () async {
      final repo = SpyJobsRepository()
        ..overviewAnswer = ((_) => JobsOverview(
          sections: [
            JobSection(key: 'latest', title: 'Latest jobs', jobs: [fakeJob('a')]),
          ],
        ));
      final jobs = JobsController(repo);
      await jobs.start();
      expect(jobs.hasAlert, isFalse);
      expect(await jobs.runAlert(), isNull);
      expect(repo.calls, isNot(contains('runAlert')));
    });

    test('a refresh reloads the board and keeps what the member dropped dropped', () async {
      final repo = SpyJobsRepository();
      final jobs = JobsController(repo);
      await jobs.start();
      await jobs.clearContext();
      await jobs.refresh();
      expect(repo.calls.where((c) => c == 'overview scoped=false'), hasLength(2));
    });

    test('an application sent from a sheet adds to My jobs', () async {
      final repo = SpyJobsRepository();
      final jobs = JobsController(repo);
      await jobs.start();
      expect(jobs.myJobs, 3);
      final controller = JobDetailController(
        repository: repo,
        seed: jobs.sections.first.jobs.first,
        onChanged: jobs.update,
        onApplied: jobs.applied,
      );
      final result = await controller.apply(coverNote: 'Keen to lead this.');
      expect(result.ok, isTrue);
      expect(jobs.myJobs, 4);
      expect(jobs.find(controller.job.id)!.applied, isTrue);
      expect(repo.applications.single.note, 'Keen to lead this.');
    });
  });

  group('the job sheet\'s actions', () {
    test('an application the API refuses for want of a phone number says so, so the form can ask', () async {
      final repo = SpyJobsRepository()
        ..phoneOnFile = false
        ..applyError = ApiError('Add a mobile number so the employer can reach you.', statusCode: 400);
      final controller = JobDetailController(repository: repo, seed: fakeJob('j'));
      expect(await controller.needsPhone(), isTrue);
      final result = await controller.apply();
      expect(result.ok, isFalse);
      expect(result.needsPhone, isTrue);
      expect(result.message, 'Add a mobile number so the employer can reach you.');
      expect(controller.job.applied, isFalse);
    });

    test('other refusals are only shown', () async {
      final repo = SpyJobsRepository()..applyError = ApiError('You have already applied to this job.', statusCode: 409);
      final controller = JobDetailController(repository: repo, seed: fakeJob('j'));
      final result = await controller.apply();
      expect(result.message, 'You have already applied to this job.');
      expect(result.needsPhone, isFalse);
    });

    test('what counts as the phone refusal', () {
      expect(isPhoneRefusal(ApiError('Add a mobile number so the employer can reach you.', statusCode: 400)), isTrue);
      expect(isPhoneRefusal(ApiError('Enter a valid mobile number.', statusCode: 400)), isTrue);
      expect(isPhoneRefusal(ApiError('Add a mobile number.', statusCode: 403)), isFalse);
      expect(isPhoneRefusal(ApiError('This job is not accepting applications.', statusCode: 400)), isFalse);
    });

    test('Message opens the thread on the website, or says why it could not', () async {
      final repo = SpyJobsRepository();
      final controller = JobDetailController(repository: repo, seed: fakeJob('j'));
      final ok = await controller.messageContact();
      expect(ok.error, isNull);
      expect(ok.thread.toString(), 'https://icr.org.in/messaging?c=conv-1');

      repo.messageError = ApiError('This job has no one to message.', statusCode: 400);
      final refused = await controller.messageContact();
      expect(refused.thread, isNull);
      expect(refused.error, 'This job has no one to message.');
    });

    test('the sheet\'s bookmark is the board\'s, and rolls back with it', () async {
      final repo = SpyJobsRepository()..setSavedError = ApiError('Nope.', statusCode: 500);
      final jobs = JobsController(repo);
      await jobs.start();
      final seed = jobs.sections.first.jobs.first;
      final controller = JobDetailController(repository: repo, seed: seed, onChanged: jobs.update);
      expect(await controller.toggleSave(), 'Nope.');
      expect(controller.job.saved, isFalse);
      expect(jobs.find(seed.id)!.saved, isFalse);
    });
  });

  group('apply rules, as @icr/shared words them', () {
    test('a LinkedIn link: a scheme is optional, a bare host or another site is not a profile', () {
      expect(normalizeLinkedIn('linkedin.com/in/me/'), 'https://linkedin.com/in/me');
      expect(normalizeLinkedIn('http://in.linkedin.com/in/me?utm=1'), 'https://in.linkedin.com/in/me');
      expect(normalizeLinkedIn('https://lnkd.in/abc'), 'https://lnkd.in/abc');
      expect(normalizeLinkedIn('https://www.linkedin.com'), isNull);
      expect(normalizeLinkedIn('https://evil.example/linkedin.com/in/me'), isNull);
      expect(normalizeLinkedIn('javascript:alert(1)'), isNull);
      expect(normalizeLinkedIn('   '), isNull);
      expect(linkedinProblem(''), isNull, reason: 'no link is not an error');
      expect(linkedinProblem('example.com/in/me'), isNotNull);
      expect(linkedinProblem('linkedin.com/in/me'), isNull);
    });

    test('who a posting is for, in words', () {
      expect(diversityAudienceSentence(['WOMEN', 'EX_DEFENCE']), 'women or ex-defence candidates');
      expect(diversityAudienceSentence(const []), 'these candidates');
      expect(genderRequiredBy('FEMALE'), 'WOMAN');
      expect(genderRequiredBy('MALE'), 'MAN');
      expect(genderRequiredBy('OTHER'), 'NON_BINARY');
      expect(genderRequiredBy('ANY'), isNull);
      expect(genderOnlySentence('MALE'), 'This role accepts applications only from men.');
      expect(genderOnlySentence(null), isNull);
    });

    test('the apply body carries the link, the declaration and the gender only when given', () {
      expect(ApiJobsRepository.applyBody(), isEmpty);
      expect(
        ApiJobsRepository.applyBody(
          linkedinUrl: ' linkedin.com/in/me ',
          diversityIdentities: ['WOMEN'],
          gender: 'WOMAN',
        ),
        {
          'linkedinUrl': 'linkedin.com/in/me',
          'diversityIdentities': ['WOMEN'],
          'gender': 'WOMAN',
        },
      );
      expect(ApiJobsRepository.applyBody(linkedinUrl: ' ', diversityIdentities: const [], gender: ''), isEmpty);
    });

    test('a job reads its gender preference and diversity rules from the API', () {
      final repo = _repo(_Api({}));
      final job = repo.job({
        'id': 'j',
        'title': 'T',
        'company': {'id': 'c', 'name': 'C'},
        'genderPreference': 'FEMALE',
        'diversityOnly': true,
        'diversityCategories': ['WOMEN', 'LGBTQ'],
      });
      expect((job.genderPreference, job.diversityOnly), ('FEMALE', true));
      expect(job.diversityCategories, ['WOMEN', 'LGBTQ']);
      final open = repo.job({
        'id': 'j',
        'title': 'T',
        'company': {'id': 'c', 'name': 'C'},
      });
      expect((open.genderPreference, open.diversityOnly), ('ANY', false));
      expect(open.diversityCategories, isEmpty);
    });
  });
}

/// The demo source, except that the match scorer fails, as it does on a
/// database without the vector extension.
class _ScorerDown extends SpyJobsRepository {
  @override
  Future<JobMatch?> match(Job job) async => throw ApiError('Internal server error', statusCode: 500);
}
