import '../jobs/demo_jobs_repository.dart';
import '../jobs/jobs_repository.dart';
import 'career_models.dart';
import 'career_repository.dart';

/// The career screens' sample content, bundled for design review and for
/// tests that must not touch the API. It keeps what a test changes
/// (a withdrawn application, a deleted alert, a review sent) in memory.
class DemoCareerRepository implements CareerRepository {
  DemoCareerRepository({JobsRepository? jobs, DateTime? now})
    : _jobs = jobs ?? DemoJobsRepository(),
      _now = now ?? DateTime.now() {
    _apps = _sampleApplications();
    _alerts = [
      const JobAlert(
        id: 'alert-1',
        name: 'Facilities & Real Estate',
        criteria: {'city': 'Bengaluru', 'country': 'India'},
        newMatches: 2,
      ),
      const JobAlert(
        id: 'alert-2',
        name: 'Remote MEP roles',
        criteria: {'search': 'MEP', 'workMode': 'REMOTE'},
        frequency: 'WEEKLY',
      ),
    ];
  }

  final JobsRepository _jobs;
  final DateTime _now;
  late List<CareerApplication> _apps;
  late List<JobAlert> _alerts;
  bool? _discoverable = true;

  /// What the calls were, for a test to read.
  final calls = <String>[];

  /// The review the member sent (null until they do).
  EmployerReview? sentReview;
  final salaryReports = <SalaryDraft>[];
  final interviewReports = <InterviewReviewDraft>[];

  @override
  JobsRepository get jobs => _jobs;

  List<CareerApplication> _sampleApplications() {
    DateTime ago(int days, [int hour = 10]) => DateTime(_now.year, _now.month, _now.day - days, hour);
    final soon = DateTime(_now.year, _now.month, _now.day + 3, 11, 30);
    return [
      CareerApplication(
        id: 'app-1',
        jobId: 'demo-1',
        jobTitle: 'Senior Facilities Manager for STP Plant',
        companyId: 'cbre',
        companyName: 'CBRE South Asia',
        city: 'Mumbai',
        stage: 'INTERVIEW',
        createdAt: ago(9),
        viewedAt: ago(8),
        resumeTitle: 'Senior Facilities Manager résumé',
        coverNote: 'I have run three campuses of this size.',
        expectedSalary: 2200000,
        matchScore: 88,
        events: [
          CareerEvent(type: 'STAGE_CHANGE', at: ago(9), toStage: 'APPLIED'),
          CareerEvent(type: 'VIEWED', at: ago(8)),
          CareerEvent(type: 'STAGE_CHANGE', at: ago(6), fromStage: 'APPLIED', toStage: 'SCREENING'),
          CareerEvent(type: 'STAGE_CHANGE', at: ago(2), fromStage: 'SCREENING', toStage: 'INTERVIEW'),
        ],
        interviews: [
          CareerInterview(
            id: 'iv-1',
            round: 1,
            title: 'Technical round',
            scheduledAt: soon,
            durationMins: 45,
            meetingLink: 'https://meet.example.com/icr-demo',
          ),
        ],
        answers: const [
          SentAnswer(prompt: 'Years running a campus?', answer: '9', type: ScreeningType.years),
          SentAnswer(prompt: 'Can you work night shifts?', answer: 'true', type: ScreeningType.yesNo),
        ],
        signals: const [
          MatchSignal(label: 'Skills', score: 0.9, detail: '4 of 5 skills match your résumé.'),
          MatchSignal(label: 'Experience', score: 0.8, detail: '9 years against 8 asked.'),
        ],
      ),
      CareerApplication(
        id: 'app-2',
        jobId: 'demo-2',
        jobTitle: 'Facilities Operations Lead',
        companyId: 'cbre',
        companyName: 'CBRE South Asia',
        city: 'Pune',
        stage: 'APPLIED',
        createdAt: ago(3),
        viewedAt: ago(2),
        matchScore: 74,
        events: [
          CareerEvent(type: 'STAGE_CHANGE', at: ago(3), toStage: 'APPLIED'),
          CareerEvent(type: 'VIEWED', at: ago(2)),
        ],
      ),
      CareerApplication(
        id: 'app-3',
        jobId: 'demo-3',
        jobTitle: 'Energy Manager',
        companyId: 'global-infra',
        companyName: 'Global Infra Solutions',
        city: 'Bengaluru',
        stage: 'OFFER',
        createdAt: ago(21),
        viewedAt: ago(20),
        matchScore: 91,
        offers: [
          CareerOffer(
            id: 'offer-1',
            status: 'SENT',
            salaryAmount: 2400000,
            jobTitle: 'Energy Manager',
            joiningDate: DateTime(_now.year, _now.month + 1, 1),
            expiresAt: DateTime(_now.year, _now.month, _now.day + 5),
            sentAt: ago(1),
            notes: 'Joining bonus of one month on completing probation.',
          ),
        ],
        events: [
          CareerEvent(type: 'STAGE_CHANGE', at: ago(21), toStage: 'APPLIED'),
          CareerEvent(type: 'STAGE_CHANGE', at: ago(1), fromStage: 'INTERVIEW', toStage: 'OFFER'),
        ],
      ),
      CareerApplication(
        id: 'app-4',
        jobId: 'demo-4',
        jobTitle: 'Soft Services Manager',
        companyId: 'global-infra',
        companyName: 'Global Infra Solutions',
        city: 'Chennai',
        stage: 'REJECTED',
        createdAt: ago(30),
        events: [
          CareerEvent(type: 'STAGE_CHANGE', at: ago(30), toStage: 'APPLIED'),
          CareerEvent(type: 'STAGE_CHANGE', at: ago(12), fromStage: 'SCREENING', toStage: 'REJECTED'),
        ],
      ),
    ];
  }

  @override
  Future<List<CareerApplication>> applications() async => [..._apps];

  @override
  Future<CareerApplication> application(String id) async => _apps.firstWhere((a) => a.id == id);

  @override
  Future<CareerApplication> withdraw(String id) async {
    calls.add('withdraw $id');
    final done = _apps.firstWhere((a) => a.id == id).copyWith(stage: 'WITHDRAWN', withdrawnAt: _now);
    _apps = [for (final a in _apps) a.id == id ? done : a];
    return done;
  }

  @override
  Future<void> respondToOffer(String offerId, {required bool accept, String? note}) async {
    calls.add('offer $offerId ${accept ? 'accept' : 'decline'}');
    _apps = [
      for (final a in _apps)
        a.offers.any((o) => o.id == offerId)
            ? a.copyWith(
                stage: accept ? 'HIRED' : a.stage,
                offers: [
                  for (final o in a.offers)
                    o.id == offerId
                        ? CareerOffer(
                            id: o.id,
                            status: accept ? 'ACCEPTED' : 'DECLINED',
                            salaryAmount: o.salaryAmount,
                            jobTitle: o.jobTitle,
                            joiningDate: o.joiningDate,
                            expiresAt: o.expiresAt,
                            sentAt: o.sentAt,
                            respondedAt: _now,
                            notes: o.notes,
                          )
                        : o,
                ],
              )
            : a,
    ];
  }

  @override
  Future<String?> messageHiringTeam(String jobId, {String? message}) async {
    calls.add('message $jobId ${message ?? ''}');
    return 'conv-1';
  }

  final _invites = [
    JobInvite(
      id: 'inv-1',
      jobId: 'demo-1',
      jobTitle: 'Senior Facilities Manager for STP Plant',
      status: 'SENT',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      companyName: 'CBRE South Asia',
      city: 'Mumbai',
      workMode: WorkMode.onsite,
      message: 'Your résumé is a strong fit. We would like you to apply.',
      invitedBy: 'Priya Sharma',
    ),
  ];

  @override
  Future<List<JobInvite>> invites() async => [..._invites];

  @override
  Future<void> respondToInvite(String id, {required bool decline}) async {
    calls.add('invite $id ${decline ? 'decline' : 'view'}');
    if (decline) _invites.removeWhere((i) => i.id == id);
  }

  @override
  Future<bool?> discoverable() async => _discoverable;

  @override
  Future<void> setDiscoverable(bool on) async {
    calls.add('discoverable $on');
    _discoverable = on;
  }

  @override
  Future<List<JobAlert>> alerts() async => [..._alerts];

  @override
  Future<JobAlert> createAlert({
    required String name,
    required Map<String, String> criteria,
    bool alertsEnabled = true,
    String frequency = 'DAILY',
  }) async {
    calls.add('createAlert $name');
    final made = JobAlert(
      id: 'alert-${_alerts.length + 10}',
      name: name,
      criteria: criteria,
      alertsEnabled: alertsEnabled,
      frequency: frequency,
    );
    _alerts = [made, ..._alerts];
    return made;
  }

  @override
  Future<JobAlert> updateAlert(
    String id, {
    String? name,
    Map<String, String>? criteria,
    bool? alertsEnabled,
    String? frequency,
  }) async {
    calls.add('updateAlert $id');
    final old = _alerts.firstWhere((a) => a.id == id);
    final next = JobAlert(
      id: id,
      name: name ?? old.name,
      criteria: criteria ?? old.criteria,
      alertsEnabled: alertsEnabled ?? old.alertsEnabled,
      frequency: frequency ?? old.frequency,
      newMatches: old.newMatches,
    );
    _alerts = [for (final a in _alerts) a.id == id ? next : a];
    return next;
  }

  @override
  Future<void> deleteAlert(String id) async {
    calls.add('deleteAlert $id');
    _alerts = [..._alerts.where((a) => a.id != id)];
  }

  @override
  Future<JobPage> runAlert(String id, {int page = 1}) async {
    _alerts = [for (final a in _alerts) a.id == id ? a.copyWith(newMatches: 0) : a];
    return _jobs.latest(page: page);
  }

  @override
  Future<JobPage> savedJobs({int page = 1}) async {
    final page = await _jobs.latest();
    return JobPage(jobs: [for (final j in page.jobs.take(2)) j.copyWith(saved: true)], hasMore: false);
  }

  final _hidden = <Job>[
    Job(
      id: 'demo-hidden-1',
      title: 'Soft Services Manager',
      company: const JobCompany(id: 'global-infra', name: 'Global Infra Solutions'),
      city: 'Chennai',
    ),
  ];

  @override
  Future<List<Job>> hiddenJobs() async => [..._hidden];

  @override
  Future<SeekerQuota?> quota() => _jobs.quota();

  @override
  Future<({int saved, int hidden})> shelfCounts() async => (saved: 2, hidden: _hidden.length);

  @override
  Future<ResumeInsights?> resumeInsights() async =>
      const ResumeInsights(score: 67, missing: ['Upload your resume PDF', 'Add your current company']);

  @override
  Future<ProfilePerformance?> profilePerformance() async =>
      const ProfilePerformance(searchAppearances30d: 12, profileViews30d: 40, invites: 1, applicationsViewed: 2);

  @override
  Future<int> unreadNotifications() => _jobs.unreadNotifications();

  // --- a company's insights ----------------------------------------------------

  static final _reviews = [
    EmployerReview(
      id: 'r1',
      rating: 5,
      createdAt: DateTime(2026, 9, 14),
      title: 'A place that lets facilities people lead',
      pros: 'Real ownership of the campus, good safety culture, and the leadership listens.',
      cons: 'Shift changes can be sudden during audits.',
      advice: 'Keep investing in the engineers on the floor.',
      jobTitle: 'Facilities Manager',
      employmentStatus: 'CURRENT',
      verifiedEmployee: true,
    ),
    EmployerReview(
      id: 'r2',
      rating: 4,
      createdAt: DateTime(2026, 8, 2),
      title: 'Solid, with room to grow',
      pros: 'Learning on large Grade-A towers.',
      cons: 'Pay reviews are once a year.',
      jobTitle: 'MEP Engineer',
      employmentStatus: 'FORMER',
    ),
  ];

  @override
  Future<JobCompany?> company(String companyId) async => JobCompany(
    id: companyId,
    name: 'Global Infra Solutions',
    city: 'Bengaluru',
    kind: 'Real Estate',
    size: '500+ employees',
    tagline: 'Commercial Real Estate Services',
  );

  @override
  Future<RatingSummary> ratingSummary(String companyId) async => const RatingSummary(
    count: 2,
    average: 4.5,
    distribution: {1: 0, 2: 0, 3: 0, 4: 1, 5: 1},
    subRatings: {'Work-life balance': 4.0, 'Pay and benefits': 3.5, 'Culture': 4.5},
  );

  @override
  Future<InsightPage<EmployerReview>> reviews(String companyId, {int page = 1}) async =>
      InsightPage(items: page == 1 ? _reviews : const [], hasMore: false, total: _reviews.length);

  @override
  Future<EmployerReview?> myReview(String companyId) async => sentReview;

  @override
  Future<void> submitReview(String companyId, ReviewDraft draft) async {
    calls.add('submitReview');
    sentReview = EmployerReview(
      id: 'mine',
      rating: draft.overall,
      createdAt: _now,
      title: draft.title,
      pros: draft.pros,
      cons: draft.cons,
      advice: draft.advice,
      jobTitle: draft.jobTitle,
      employmentStatus: draft.employmentStatus,
      status: 'PENDING',
      subRatings: draft.subRatings,
    );
  }

  @override
  Future<SalaryInsights> salaries(String companyId) async => const SalaryInsights(
    totalReports: 11,
    roles: [
      SalaryRole(
        jobTitle: 'Facilities Manager',
        count: 6,
        p25: 1400000,
        median: 1800000,
        p75: 2300000,
        avgExperience: 8.2,
      ),
      SalaryRole(jobTitle: 'MEP Engineer', count: 5, p25: 600000, median: 800000, p75: 950000, avgExperience: 4.6),
    ],
  );

  @override
  Future<void> submitSalary(String companyId, SalaryDraft draft) async {
    calls.add('submitSalary');
    salaryReports.add(draft);
  }

  static final _interviews = [
    InterviewReview(
      id: 'i1',
      createdAt: DateTime(2026, 9, 1),
      jobTitle: 'Senior Facilities Manager',
      difficulty: 3,
      experienceRating: 4,
      outcome: 'OFFER_ACCEPTED',
      process: 'A screening call, a technical round with the head of operations, then a site walk and HR.',
      questions: 'How would you bring a chiller plant back after a trip? Walk me through an audit you led.',
      durationDays: 21,
    ),
  ];

  @override
  Future<InsightPage<InterviewReview>> interviewReviews(String companyId, {int page = 1}) async => InsightPage(
    items: page == 1 ? _interviews : const [],
    hasMore: false,
    total: _interviews.length,
    averages: const {'difficulty': 3.0, 'experience': 4.0},
  );

  @override
  Future<void> submitInterviewReview(String companyId, InterviewReviewDraft draft) async {
    calls.add('submitInterview');
    interviewReports.add(draft);
  }

  @override
  Future<InsightPage<CompanyPerson>> people(String companyId, {int page = 1}) async => InsightPage(
    items: page == 1
        ? const [
            CompanyPerson(id: 'priya', name: 'Priya Sharma', headline: 'Lead Talent Partner @ Global Infra'),
            CompanyPerson(id: 'nikhil', name: 'Nikhil Menon', headline: 'Head of Facilities Operations'),
          ]
        : const [],
    hasMore: false,
    total: 2,
  );

  @override
  Future<JobPage> companyJobs(String companyId, {int page = 1}) => _jobs.latest(page: page);
}
