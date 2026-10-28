import 'applicants_controller.dart' show stageMoves;
import 'hiring_models.dart';
import 'hiring_repository.dart';

/// The employer screens' sample content, bundled for design review and for tests that
/// must not touch the API. It keeps what a test changes (a job posted, an applicant
/// moved) in memory.
class DemoHiringRepository implements HiringRepository {
  DemoHiringRepository({DateTime? now, HiringAccess? access})
    : now = now ?? DateTime.now(),
      _access = access ?? const HiringAccess(userId: 'me', role: 'RECRUITER', companyId: 'northwind') {
    _jobs = _sampleJobs();
    _applicants = _sampleApplicants();
  }

  final DateTime now;
  final HiringAccess _access;

  /// What the calls were, for a test to read.
  final calls = <String>[];

  late List<PostedJob> _jobs;
  late List<Applicant> _applicants;
  final _interviews = <String, List<TeamInterview>>{};
  final _offers = <String, List<TeamOffer>>{};
  final _events = <String, List<ActivityEvent>>{};
  final _drafts = <String, JobDraft>{};
  final _questions = <String, List<ScreeningDraft>>{};
  var _nextId = 100;

  DateTime _ago(int days) => DateTime(now.year, now.month, now.day - days, 10);

  List<PostedJob> _sampleJobs() => [
    PostedJob(
      id: 'job-open',
      title: 'Facilities Operations Lead',
      status: PostingStatus.open,
      createdAt: _ago(14),
      publishedAt: _ago(14),
      city: 'Ahmedabad',
      cities: const ['Ahmedabad'],
      workMode: null,
      applyDeadline: DateTime(now.year, now.month, now.day + 2, 18),
      openings: 2,
      viewCount: 310,
      pipeline: const PipelineCounts(
        stages: {'APPLIED': 3, 'SCREENING': 2, 'INTERVIEW': 2, 'OFFER': 1, 'REJECTED': 1},
        unviewed: 2,
      ),
      screeningQuestions: 2,
      postedBy: 'Meera Iyer',
    ),
    PostedJob(
      id: 'job-quiet',
      title: 'Energy Manager',
      status: PostingStatus.open,
      createdAt: _ago(17),
      publishedAt: _ago(17),
      city: 'Delhi',
      cities: const ['Delhi'],
      postedBy: 'Rohit Rao',
    ),
    PostedJob(
      id: 'job-draft',
      title: 'Soft Services Supervisor',
      status: PostingStatus.draft,
      createdAt: _ago(3),
      city: 'Surat',
      cities: const ['Surat'],
      postedBy: 'Meera Iyer',
    ),
    PostedJob(
      id: 'job-returned',
      title: 'Security Operations Manager',
      status: PostingStatus.draft,
      createdAt: _ago(2),
      city: 'Ahmedabad',
      cities: const ['Ahmedabad'],
      reviewNote: 'Please add the salary range.',
      reviewedAt: _ago(1),
      postedBy: 'Meera Iyer',
    ),
    PostedJob(
      id: 'job-paused',
      title: 'Sustainability Analyst',
      status: PostingStatus.paused,
      createdAt: _ago(30),
      publishedAt: _ago(30),
      city: 'Bhopal',
      cities: const ['Bhopal'],
    ),
    PostedJob(
      id: 'job-closed',
      title: 'Soft Services Manager',
      status: PostingStatus.closed,
      createdAt: _ago(40),
      publishedAt: _ago(40),
      city: 'Chennai',
      cities: const ['Chennai'],
    ),
  ];

  List<Applicant> _sampleApplicants() => [
    Applicant(
      id: 'app-aarav',
      jobId: 'job-open',
      userId: 'u-aarav',
      name: 'Aarav Khanna',
      stage: 'APPLIED',
      appliedAt: _ago(2),
      headline: 'Facilities Manager - healthcare campuses',
      currentCompany: 'Apollo Hospitals',
      experienceYears: 11,
      skills: const ['HVAC Chillers', 'Statutory Audits', 'Vendor SLAs'],
      location: 'Ahmedabad',
      matchScore: 82,
      coverNote: 'I have run three healthcare campuses for eleven years.',
      email: 'aarav@example.test',
    ),
    Applicant(
      id: 'app-divya',
      jobId: 'job-open',
      userId: 'u-divya',
      name: 'Divya Menon',
      stage: 'APPLIED',
      appliedAt: _ago(3),
      viewedAt: _ago(2),
      headline: 'Senior Facilities Manager - Grade-A offices',
      currentCompany: 'Brigade Group',
      experienceYears: 9,
      matchScore: 76,
    ),
    Applicant(
      id: 'app-nisha',
      jobId: 'job-open',
      userId: 'u-nisha',
      name: 'Nisha Rao',
      stage: 'SCREENING',
      appliedAt: _ago(6),
      viewedAt: _ago(5),
      rating: 4,
      headline: 'Facilities operations with a statutory-audit streak',
      currentCompany: 'Cushman & Wakefield',
      experienceYears: 10,
      matchScore: 88,
    ),
    Applicant(
      id: 'app-sanjana',
      jobId: 'job-open',
      userId: 'u-sanjana',
      name: 'Sanjana Pillai',
      stage: 'INTERVIEW',
      appliedAt: _ago(9),
      viewedAt: _ago(8),
      rating: 5,
      headline: 'AVP Facilities - multi-site portfolio',
      currentCompany: 'Embassy Group',
      experienceYears: 14,
      matchScore: 91,
      nextInterviewAt: DateTime(now.year, now.month, now.day + 2, 15),
    ),
    Applicant(
      id: 'app-ishita',
      jobId: 'job-open',
      userId: 'u-ishita',
      name: 'Ishita Bose',
      stage: 'OFFER',
      appliedAt: _ago(14),
      viewedAt: _ago(13),
      rating: 5,
      headline: 'Regional facilities head - 40 sites',
      currentCompany: 'RPG Group',
      experienceYears: 15,
      matchScore: 93,
      offerStatus: 'SENT',
    ),
    Applicant(
      id: 'app-harsh',
      jobId: 'job-open',
      userId: 'u-harsh',
      name: 'Harsh Vora',
      stage: 'REJECTED',
      appliedAt: _ago(12),
      viewedAt: _ago(11),
      rating: 2,
      currentCompany: 'Regus',
      experienceYears: 4,
      matchScore: 38,
    ),
  ];

  // --- access and jobs ------------------------------------------------------------

  @override
  Future<HiringAccess> access() async => _access;

  @override
  Future<PostedJobsPage> jobs({
    PostingStatus? status,
    String? search,
    bool mine = false,
    String sort = 'recent',
    int page = 1,
  }) async {
    calls.add('jobs status=${status?.api} search=$search sort=$sort');
    final q = (search ?? '').trim().toLowerCase();
    final rows = [
      for (final j in _jobs)
        if ((status == null || j.status == status) && (q.isEmpty || j.title.toLowerCase().contains(q))) j,
    ];
    final counts = <PostingStatus, int>{};
    for (final j in _jobs) {
      counts[j.status] = (counts[j.status] ?? 0) + 1;
    }
    return PostedJobsPage(jobs: rows, hasMore: false, total: rows.length, statusCounts: counts);
  }

  @override
  Future<HiringOverview> overview() async => const HiringOverview(
    open: 2,
    closingSoon: 1,
    unviewed: 2,
    interviewing: 2,
    interviewingJobs: 1,
    hired: 0,
    attention: [AttentionItem(kind: 'noApplicants', jobId: 'job-quiet', title: 'Energy Manager', days: 17)],
  );

  @override
  Future<JobDraft> job(String id) async {
    final saved = _drafts[id];
    if (saved != null) return saved.copyWith(screening: _questions[id] ?? const []);
    final row = _jobs.firstWhere((j) => j.id == id);
    return JobDraft(
      id: id,
      title: row.title,
      description:
          'Lead day-to-day facilities operations across four logistics parks: rosters, statutory audits and the vendors who run them.\n\n## Key responsibilities\n- Own shift planning.\n- Hold vendors to their service levels.',
      cities: row.cities,
      skills: const ['Statutory Audits', 'Shift Planning'],
      experienceMin: 5,
      salaryMin: 1500000,
      salaryMax: 2100000,
      status: row.status,
      screening: _questions[id] ?? const [],
    );
  }

  @override
  Future<String> createJob(JobDraft draft, PostingStatus status) async {
    calls.add('createJob ${status.api}');
    final id = 'job-${_nextId++}';
    _drafts[id] = JobDraft.fromJson({...draft.toJson(status: status), 'id': id});
    _jobs = [
      PostedJob(
        id: id,
        title: draft.title,
        status: status,
        createdAt: now,
        publishedAt: status == PostingStatus.open ? now : null,
        city: draft.cities.isEmpty ? null : draft.cities.first,
        cities: draft.cities,
        postedBy: 'You',
      ),
      ..._jobs,
    ];
    return id;
  }

  @override
  Future<void> updateJob(String id, JobDraft draft, {PostingStatus? status}) async {
    calls.add('updateJob $id ${status?.api}');
    _drafts[id] = JobDraft.fromJson({...draft.toJson(status: status), 'id': id});
    _jobs = [
      for (final j in _jobs)
        j.id == id
            ? PostedJob(
                id: id,
                title: draft.title,
                status: status ?? j.status,
                createdAt: j.createdAt,
                publishedAt: j.publishedAt,
                city: draft.cities.isEmpty ? null : draft.cities.first,
                cities: draft.cities,
                pipeline: j.pipeline,
                postedBy: j.postedBy,
              )
            : j,
    ];
  }

  @override
  Future<void> setStatus(String id, PostingStatus status) async {
    calls.add('setStatus $id ${status.api}');
    _jobs = [for (final j in _jobs) j.id == id ? j.copyWith(status: status) : j];
  }

  @override
  Future<void> submitForReview(String id) async {
    calls.add('submitForReview $id');
    _jobs = [for (final j in _jobs) j.id == id ? j.copyWith(status: PostingStatus.inReview) : j];
  }

  @override
  Future<void> deleteJob(String id) async {
    calls.add('deleteJob $id');
    _jobs = _jobs.where((j) => j.id != id).toList();
  }

  @override
  Future<List<JobTitleOption>> jobTitles() async => const [
    JobTitleOption('Facilities Manager', 'FACILITIES_MGMT'),
    JobTitleOption('Facilities Operations Lead', 'FACILITIES_MGMT'),
    JobTitleOption('Facility Supervisor', 'FACILITIES_MGMT'),
    JobTitleOption('Energy Manager', 'ENERGY_SUSTAIN'),
    JobTitleOption('HSE Officer', 'HSE'),
    JobTitleOption('MEP Engineer'),
  ];

  @override
  Future<List<String>> skillSuggestions(String query) async => [
    for (final s in const ['Budgeting', 'Budget Control', 'Statutory Audits', 'Shift Planning', 'Fire Safety'])
      if (s.toLowerCase().contains(query.trim().toLowerCase())) s,
  ];

  @override
  Future<List<ScreeningDraft>> screeningQuestions(String jobId) async => [...?_questions[jobId]];

  @override
  Future<void> setScreeningQuestions(String jobId, List<ScreeningDraft> questions) async {
    calls.add('setScreeningQuestions $jobId ${questions.length}');
    _questions[jobId] = questions;
  }

  // --- applicants ---------------------------------------------------------------------

  @override
  Future<ApplicantsPage> applicants(
    String jobId, {
    String? stage,
    String sort = 'recent',
    int? minRating,
    bool qualifiedOnly = false,
  }) async {
    calls.add('applicants $jobId stage=$stage sort=$sort minRating=$minRating');
    final all = _applicants.where((a) => a.jobId == jobId).toList();
    final counts = <String, int>{};
    for (final a in all) {
      counts[a.stage] = (counts[a.stage] ?? 0) + 1;
    }
    final rows = [
      for (final a in all)
        if ((stage == null || a.stage == stage) && (minRating == null || (a.rating ?? 0) >= minRating)) a,
    ];
    if (sort == 'match') rows.sort((a, b) => (b.matchScore ?? 0).compareTo(a.matchScore ?? 0));
    if (sort == 'recent') rows.sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
    return ApplicantsPage(applicants: rows, stageCounts: counts);
  }

  @override
  Future<ApplicantDetail> applicant(String applicationId) async {
    calls.add('applicant $applicationId');
    final a = _applicants.firstWhere((x) => x.id == applicationId);
    return ApplicantDetail(
      applicant: a,
      jobTitle: 'Facilities Operations Lead',
      aiSummary: null,
      answers: const [
        GradedAnswer(
          prompt: 'How many years have you run site operations?',
          answer: '9',
          type: 'YEARS',
          meetsIdeal: true,
          mustHave: true,
        ),
        GradedAnswer(prompt: 'Can you work rotational shifts?', answer: 'true', type: 'YES_NO', meetsIdeal: true),
      ],
      interviews: [...?_interviews[applicationId]],
      offers: [
        ...?_offers[applicationId],
        if (a.offerStatus == 'SENT' && _offers[applicationId] == null)
          TeamOffer(
            id: 'offer-${a.id}',
            status: 'SENT',
            amount: 2100000,
            jobTitle: 'Facilities Operations Lead',
            sentAt: _ago(1),
          ),
      ],
      events: [
        ...?_events[applicationId],
        ActivityEvent(type: 'STAGE_CHANGE', at: a.appliedAt, toStage: 'APPLIED', actor: a.name),
      ],
    );
  }

  void _patch(String id, Applicant Function(Applicant) change) {
    _applicants = [for (final a in _applicants) a.id == id ? change(a) : a];
  }

  void _log(String id, ActivityEvent e) => _events[id] = [e, ...?_events[id]];

  @override
  Future<void> moveStage(String applicationId, String stage, {String? note}) async {
    calls.add('moveStage $applicationId $stage ${note ?? ''}'.trim());
    final from = _applicants.firstWhere((a) => a.id == applicationId).stage;
    _patch(applicationId, (a) => a.copyWith(stage: stage));
    _log(
      applicationId,
      ActivityEvent(type: 'STAGE_CHANGE', at: now, fromStage: from, toStage: stage, note: note, actor: 'You'),
    );
  }

  @override
  Future<void> addNote(String applicationId, {String? note, int? rating}) async {
    calls.add('addNote $applicationId note=${note ?? ''} rating=$rating');
    if (rating != null) _patch(applicationId, (a) => a.copyWith(rating: rating));
    if (note != null && note.trim().isNotEmpty) {
      _log(applicationId, ActivityEvent(type: 'NOTE', at: now, note: note, actor: 'You'));
    }
    if (rating != null) _log(applicationId, ActivityEvent(type: 'RATING', at: now, rating: rating, actor: 'You'));
  }

  @override
  Future<TeamInterview> scheduleInterview(String applicationId, InterviewDraft draft) async {
    calls.add('scheduleInterview $applicationId ${draft.mode}');
    final made = TeamInterview(
      id: 'iv-${_nextId++}',
      round: (_interviews[applicationId]?.length ?? 0) + 1,
      scheduledAt: draft.scheduledAt!,
      mode: draft.mode,
      status: 'SCHEDULED',
      title: draft.title.isEmpty ? null : draft.title,
      durationMins: draft.durationMins,
      meetingLink: draft.meetingLink.isEmpty ? null : draft.meetingLink,
      location: draft.location.isEmpty ? null : draft.location,
      panel: [for (final id in draft.interviewerIds) TeamMember(id: id, name: id, role: '')],
    );
    _interviews[applicationId] = [...?_interviews[applicationId], made];
    _patch(applicationId, (a) => a.copyWith(nextInterviewAt: draft.scheduledAt));
    _log(applicationId, ActivityEvent(type: 'INTERVIEW_SCHEDULED', at: now, note: made.name, actor: 'You'));
    return made;
  }

  @override
  Future<TeamInterview> updateInterview(String interviewId, {InterviewDraft? draft, String? status}) async {
    calls.add('updateInterview $interviewId status=$status');
    TeamInterview? out;
    _interviews.updateAll(
      (app, list) => [
        for (final i in list)
          if (i.id == interviewId)
            out = TeamInterview(
              id: i.id,
              round: i.round,
              scheduledAt: draft?.scheduledAt ?? i.scheduledAt,
              mode: draft?.mode ?? i.mode,
              status: status ?? (draft?.scheduledAt != null ? 'RESCHEDULED' : i.status),
              title: i.title,
              durationMins: draft?.durationMins ?? i.durationMins,
              meetingLink: draft?.meetingLink ?? i.meetingLink,
              location: draft?.location ?? i.location,
              panel: i.panel,
            )
          else
            i,
      ],
    );
    return out ?? (throw StateError('no interview $interviewId'));
  }

  @override
  Future<TeamOffer> makeOffer(String applicationId, OfferDraft draft, {bool send = true}) async {
    calls.add('makeOffer $applicationId send=$send');
    final made = TeamOffer(
      id: 'offer-${_nextId++}',
      status: send ? 'SENT' : 'DRAFT',
      amount: draft.amount!,
      currency: draft.currency,
      period: draft.period,
      jobTitle: draft.jobTitle.isEmpty ? null : draft.jobTitle,
      joiningDate: draft.joiningDate,
      expiresAt: draft.expiresAt,
      notes: draft.notes.isEmpty ? null : draft.notes,
      sentAt: send ? now : null,
    );
    _offers[applicationId] = [made, ...?_offers[applicationId]];
    if (send) {
      _patch(
        applicationId,
        (a) => a.copyWith(
          offerStatus: 'SENT',
          stage: (stageMoves[a.stage] ?? const []).contains('OFFER') ? 'OFFER' : a.stage,
        ),
      );
    }
    return made;
  }

  @override
  Future<TeamOffer> updateOffer(String offerId, OfferDraft draft) async {
    calls.add('updateOffer $offerId');
    TeamOffer? out;
    _offers.updateAll(
      (app, list) => [
        for (final o in list)
          if (o.id == offerId)
            out = TeamOffer(
              id: o.id,
              status: o.status,
              amount: draft.amount!,
              currency: draft.currency,
              period: draft.period,
              jobTitle: draft.jobTitle.isEmpty ? null : draft.jobTitle,
              joiningDate: draft.joiningDate,
              expiresAt: draft.expiresAt,
              notes: draft.notes.isEmpty ? null : draft.notes,
              sentAt: o.sentAt,
            )
          else
            o,
      ],
    );
    return out ?? (throw StateError('no offer $offerId'));
  }

  @override
  Future<TeamOffer> sendOffer(String offerId) async {
    calls.add('sendOffer $offerId');
    TeamOffer? out;
    String? appId;
    _offers.updateAll(
      (app, list) => [
        for (final o in list)
          if (o.id == offerId)
            () {
              appId = app;
              return out = TeamOffer(
                id: o.id,
                status: 'SENT',
                amount: o.amount,
                currency: o.currency,
                period: o.period,
                jobTitle: o.jobTitle,
                joiningDate: o.joiningDate,
                expiresAt: o.expiresAt,
                notes: o.notes,
                sentAt: now,
              );
            }()
          else
            o,
      ],
    );
    if (appId != null) {
      _patch(
        appId!,
        (a) => a.copyWith(
          offerStatus: 'SENT',
          stage: (stageMoves[a.stage] ?? const []).contains('OFFER') ? 'OFFER' : a.stage,
        ),
      );
    }
    return out ?? (throw StateError('no offer $offerId'));
  }

  @override
  Future<String?> messageApplicant(String applicationId) async {
    calls.add('messageApplicant $applicationId');
    return 'conv-1';
  }

  @override
  Future<List<TeamMember>> teamMembers() async => const [
    TeamMember(id: 'me', name: 'You', role: 'RECRUITER'),
    TeamMember(id: 'meera', name: 'Meera Iyer', role: 'COMPANY_ADMIN'),
    TeamMember(id: 'rohit', name: 'Rohit Rao', role: 'RECRUITER'),
  ];

  @override
  Future<int> unreadNotifications() async => 1;
}
