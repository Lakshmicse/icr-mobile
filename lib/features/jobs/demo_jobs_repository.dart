import '../../core/config.dart';
import 'job_models.dart';
import 'jobs_repository.dart';

/// The Jobs designs' sample content, bundled for design review.
class DemoJobsRepository implements JobsRepository {
  DemoJobsRepository();

  static const _cbre = JobCompany(id: 'cbre', name: 'CBRE South Asia', city: 'Mumbai', verified: true);

  static const globalInfra = JobCompany(
    id: 'global-infra',
    name: 'Global Infra Solutions',
    logo: FeedPicture.asset('assets/images/demo/jobs/company_logo.png'),
    cover: FeedPicture.asset('assets/images/demo/jobs/company_photo.png'),
    city: 'Bengaluru',
    verified: true,
    tagline: 'Enterprise Workplace & Asset Management',
    kind: 'Real Estate Facilities',
    size: '8,400+ employees',
    legalName: 'Global Infra Solutions Ltd.',
    description:
        'Leading Indian commercial real estate management operator handling 42M+ sq.ft. of prime institutional tech parks and industrial hubs.',
  );

  static Job _row(int n, FeedPicture logo) => Job(
    id: 'demo-$n',
    title: 'Senior Facilities Manager for STP Plant',
    company: JobCompany(id: _cbre.id, name: _cbre.name, city: _cbre.city, verified: true, logo: logo),
    city: 'Mumbai',
    country: 'India',
    workMode: WorkMode.onsite,
    employmentType: EmploymentType.fullTime,
    postedAt: DateTime.now().subtract(const Duration(days: 2)),
  );

  static const _green = FeedPicture.asset('assets/images/demo/jobs/logo_green.png');
  static const _blueDot = FeedPicture.asset('assets/images/demo/jobs/logo_bluedot.png');

  /// The saved search behind the design's scope bar: two filters, so with
  /// Easy Apply the chip reads "Filters (3)".
  static const _scope = JobContext(
    label: 'Facilities & Real Estate',
    place: 'Bengaluru, IN',
    alertId: 'demo-alert',
    criteria: {'city': 'Bengaluru', 'country': 'India'},
  );

  final _saved = <String>{};
  final _applied = <String>{};

  /// The job every row opens: the Job Details design.
  Job get detailJob => Job(
    id: 'demo-detail',
    title: 'Senior Facilities Manager',
    company: globalInfra,
    city: 'Bengaluru',
    state: 'Karnataka',
    country: 'India',
    workMode: WorkMode.onsite,
    employmentType: EmploymentType.fullTime,
    salaryMin: 1800000,
    salaryMax: 2500000,
    postedAt: DateTime.now().subtract(const Duration(days: 3)),
    applicants: 142,
    matchScore: 92,
    statusLine: 'Actively reviewing applicants',
    highlight: 'Commercial Grade-A Towers • 2.4M+ sq.ft.',
    skills: const ['BMS Automation', 'HVAC Chillers', 'EHS Auditing', 'Vendor SLAs', 'OpEx Planning'],
    experienceMin: 8,
    descriptionHtml:
        '<p>We are seeking an authoritative and strategic Senior Facilities Manager to spearhead campus operations '
        'across our marquee 2.4M+ sq.ft. Grade-A commercial tech park in Outer Ring Road, Bengaluru. You will orchestrate '
        'end-to- end hard MEP systems, workplace hospitality, client relations, and sustainability goals.</p>'
        '<h3>Key Responsibilities</h3><ul>'
        '<li>Direct operational leadership across 4 interconnected Grade-A towers housing Fortune 500 tech clients.</li>'
        '<li>Spearhead IoT automated energy telemetry deployment resulting in verified sub-system energy reduction targets.</li>'
        '<li>Lead statutory audit readiness for National Building Code (NBC), OHSAS 18001, and Pollution Control Board approvals.</li>'
        '<li>Contract management, procurement governance, and SLA dispute resolution for soft &amp; hard engineering vendor teams.</li>'
        '</ul>',
    contact: const JobContact(
      name: 'Priya Sharma',
      role: 'Job poster',
      designation: 'Lead Talent Partner @ Global Infra',
      photo: FeedPicture.asset('assets/images/demo/jobs/avatar_priya.png'),
      memberId: 'priya',
      degree: '2nd',
      activity: 'Active today',
    ),
    saved: _saved.contains('demo-detail'),
    applied: _applied.contains('demo-detail'),
  );

  List<Job> _rows() {
    final rows = [_row(1, _green), _row(2, _green), _row(3, _blueDot)];
    return [for (final j in rows) j.copyWith(saved: _saved.contains(j.id))];
  }

  @override
  Future<JobsOverview> overview({bool scoped = true}) async {
    return JobsOverview(
      sections: [
        for (final key in const ['foryou', 'preferences', 'alert'])
          JobSection(key: key, title: 'Recommended Jobs for You', jobs: _rows(), hasMore: true),
      ],
      myJobs: 3,
      newAlerts: 2,
      alert: _scope,
    );
  }

  @override
  Future<JobPage> search(JobFilters filters, {int page = 1, JobContext? scope}) async {
    final all = _rows();
    final q = filters.search.toLowerCase();
    return JobPage(jobs: all.where((j) => q.isEmpty || j.title.toLowerCase().contains(q)).toList(), hasMore: false);
  }

  @override
  Future<JobPage> latest({int page = 1}) async => JobPage(jobs: _rows(), hasMore: false);

  @override
  Future<JobPage> more(JobSection section, int page) async => const JobPage(jobs: [], hasMore: false);

  @override
  Future<JobPage> runAlert(JobContext alert) async => JobPage(jobs: _rows(), hasMore: true);

  @override
  Future<int> newAlertMatches() async => 0;

  @override
  Future<MyJobs> myJobs() async => MyJobs(
    applications: [
      for (final (i, job) in _rows().indexed)
        JobApplication(
          id: 'demo-app-$i',
          job: job.copyWith(),
          stage: i == 0 ? 'INTERVIEW' : 'APPLIED',
          appliedAt: DateTime.now().subtract(Duration(days: 3 + i)),
        ),
    ],
    saved: [for (final j in _rows().where((j) => j.saved)) j],
  );

  @override
  Future<Job> detail(String id) async => detailJob;

  @override
  Future<JobMatch?> match(Job job) async => const JobMatch(
    score: 92,
    summary: 'Your profile matches 4 of 5 requirements',
    checks: [
      MatchCheck(
        label: '8+ years Facility & MEP Management',
        detail: 'Your resume lists 9.4 years of verified engineering experience.',
        met: true,
      ),
      MatchCheck(
        label: 'Large Tech Campus Operations (1M+ sq.ft.)',
        detail: 'Matched from Embassy TechZone portfolio role.',
        met: true,
      ),
      MatchCheck(
        label: 'B.Tech / B.E. in Mechanical or Electrical',
        detail: 'Degree accredited and verified via National Registry.',
        met: true,
      ),
      MatchCheck(
        label: 'RICS or IFMA Facility Management Charter',
        detail: 'Preferred credential. Complete Vinfraa micro-track to qualify.',
        met: false,
      ),
    ],
  );

  @override
  Future<CompanyPeople?> peopleAt(JobCompany company) async => const CompanyPeople(
    names: ['Nikhil M.', 'Anita R.'],
    total: 5,
    note: 'Nikhil M. and 4 other RICS alumni from your network work at this organization.',
  );

  @override
  Future<void> setSaved(Job job, bool saved) async => saved ? _saved.add(job.id) : _saved.remove(job.id);

  @override
  Future<bool> hasPhone() async => true;

  @override
  Future<void> apply(
    Job job, {
    String? phone,
    String? coverNote,
    String? resumeId,
    num? expectedSalary,
    Map<String, String>? answers,
    String? linkedinUrl,
    List<String>? diversityIdentities,
    String? gender,
  }) async => _applied.add(job.id);

  @override
  Future<List<ResumeChoice>> resumes() async => const [
    ResumeChoice(id: 'demo-resume', title: 'Senior Facilities Manager résumé', isDefault: true),
    ResumeChoice(id: 'demo-resume-pdf', title: 'Facilities CV (PDF)', hasFile: true),
  ];

  @override
  Future<SeekerQuota?> quota() async => const SeekerQuota(used: 3, limit: 10, tier: 'FREE');

  final hidden = <String>{};

  @override
  Future<void> setHidden(Job job, bool hide) async => hide ? hidden.add(job.id) : hidden.remove(job.id);

  @override
  Future<String?> messageContact(Job job, {String? message}) async => null;

  @override
  Future<int> unreadNotifications() async => 1;

  @override
  Uri link(Job job) => AppConfig.sitePage('/jobs');
}
