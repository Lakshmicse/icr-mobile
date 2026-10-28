import 'dart:async';

import '../../core/api/api_error.dart';
import 'account_models.dart';
import 'account_repository.dart';

/// The account screens with no API: the design's sample member (Nikhil
/// Majjagi, the profile menu's), kept in memory so edits stick for the session.
/// It behaves as the API does where the screens depend on it (a whole-list save
/// gives every row a new id; following counts; the only admin cannot leave).
///
/// Tests use it as their stand-in: every call is logged in [calls], a call can
/// be made to fail through [failures], and [gate] holds calls to show loading.
class DemoAccountRepository implements AccountRepository {
  DemoAccountRepository({MyProfile? profile, MyCompanies? companies, List<Experience>? experience})
    : profileNow = profile ?? demoProfile,
      companiesNow = companies ?? demoCompanies,
      experienceNow = experience ?? demoExperience;

  MyProfile profileNow;
  MyCompanies companiesNow;
  List<Experience> experienceNow;
  List<Education> educationNow = demoEducation;
  List<CareerBreak> breaksNow = const [];
  ProfileLinks linksNow = const ProfileLinks(linkedin: 'https://linkedin.com/in/nikhil-majjagi');
  List<Credential> credentialsNow = demoCredentials;
  List<NotificationPreference> preferencesNow = [
    for (final c in const ['messages', 'jobs', 'procurement', 'mentoring', 'learning', 'events', 'community'])
      NotificationPreference(category: c, inApp: true, email: true),
    for (final c in const ['payments', 'support', 'security'])
      NotificationPreference(category: c, inApp: true, email: true, locked: true),
  ];
  Map<String, MemberProfile> members = {for (final m in demoMembers) m.id: m};
  Map<String, List<ForumPost>> posts = {'m-arjun': demoPosts};
  List<String> titles = const ['Facilities Manager', 'Facility Executive', 'Energy Manager', 'Workplace Manager'];
  List<CityOption> cityList = const [
    CityOption(id: 'c-blr', name: 'Bengaluru', state: 'Karnataka'),
    CityOption(id: 'c-pune', name: 'Pune', state: 'Maharashtra'),
    CityOption(id: 'c-mum', name: 'Mumbai', state: 'Maharashtra'),
  ];
  List<CompanyHit> companyPages = const [
    CompanyHit(id: 'co-techcorp', name: 'TechCorp', city: 'Bengaluru'),
    CompanyHit(id: 'co-global', name: 'Global Infra Solutions', city: 'Bengaluru'),
  ];

  /// The code the phone and email checks hand back, as a non-production API does.
  String testCode = '246810';

  /// Calls wait on this when set.
  Future<void>? gate;

  final calls = <String>[];

  /// What a call (by name, or `name:arg`) throws.
  final failures = <String, Object>{};

  /// The last body each write was sent.
  final sent = <String, Object?>{};

  int _ids = 0;
  String _id(String prefix) => '$prefix-${++_ids}';

  Future<T> _run<T>(String name, T Function() body, [String? arg]) async {
    calls.add(arg == null ? name : '$name:$arg');
    if (gate != null) await gate;
    final failure = failures[arg == null ? name : '$name:$arg'] ?? failures[name];
    if (failure != null) throw failure;
    return body();
  }

  int count(String name) => calls.where((c) => c == name || c.startsWith('$name:')).length;

  // --- lookups -----------------------------------------------------------------------------------------------

  @override
  Future<List<String>> jobTitles() => _run('jobTitles', () => titles);

  @override
  Future<List<CompanyHit>> searchCompanies(String query) => _run(
    'searchCompanies',
    () => companyPages.where((c) => c.name.toLowerCase().contains(query.trim().toLowerCase())).toList(),
    query,
  );

  @override
  Future<List<CityOption>> cities() => _run('cities', () => cityList);

  // --- my profile --------------------------------------------------------------------------------------------

  @override
  Future<MyProfile> myProfile() => _run('myProfile', () => profileNow);

  @override
  Future<List<Experience>> experience() => _run('experience', () => experienceNow);

  @override
  Future<List<Education>> education() => _run('education', () => educationNow);

  @override
  Future<List<CareerBreak>> careerBreaks() => _run('careerBreaks', () => breaksNow);

  @override
  Future<ProfileLinks> links() => _run('links', () => linksNow);

  @override
  Future<List<Credential>> credentials() => _run('credentials', () => credentialsNow);

  @override
  Future<MyProfile> updateMe(Map<String, Object?> patch) => _run('updateMe', () {
    sent['updateMe'] = patch;
    final p = profileNow;
    if (patch.containsKey('locale')) localeNow = patch['locale'] as String?;
    String? s(String key, String? current) => patch.containsKey(key)
        ? ((patch[key] as String?)?.trim().isEmpty ?? true ? null : (patch[key] as String).trim())
        : current;
    profileNow = MyProfile(
      id: p.id,
      email: p.email,
      firstName: s('firstName', p.firstName) ?? '',
      lastName: s('lastName', p.lastName) ?? '',
      role: p.role,
      profileSlug: p.profileSlug,
      designation: s('designation', p.designation),
      yearsExperience: patch.containsKey('yearsExperience') ? patch['yearsExperience'] as int? : p.yearsExperience,
      languages: patch.containsKey('languages') ? (patch['languages'] as List).cast<String>() : p.languages,
      workEmail: s('workEmail', p.workEmail),
      phone: s('phone', p.phone),
      phoneVerified: patch.containsKey('phone') ? false : p.phoneVerified,
      altPhone: s('altPhone', p.altPhone),
      avatarUrl: s('avatarUrl', p.avatarUrl),
      coverImage: s('coverImage', p.coverImage),
      companyName: p.companyName,
      hasResume: p.hasResume,
      jobTitle: p.jobTitle,
      summary: p.summary,
      skills: p.skills,
      location: p.location,
      completeness: p.completeness,
    );
    return profileNow;
  });

  @override
  Future<MyProfile> updateResume(Map<String, Object?> patch) => _run('updateResume', () {
    sent['updateResume'] = patch;
    final p = profileNow;
    String? s(String key, String? current) => patch.containsKey(key)
        ? ((patch[key] as String?)?.trim().isEmpty ?? true ? null : (patch[key] as String).trim())
        : current;
    profileNow = MyProfile(
      id: p.id,
      email: p.email,
      firstName: p.firstName,
      lastName: p.lastName,
      role: p.role,
      profileSlug: p.profileSlug,
      designation: p.designation,
      yearsExperience: p.yearsExperience,
      languages: p.languages,
      workEmail: p.workEmail,
      phone: p.phone,
      phoneVerified: p.phoneVerified,
      altPhone: p.altPhone,
      avatarUrl: p.avatarUrl,
      coverImage: p.coverImage,
      companyName: p.companyName,
      hasResume: true,
      jobTitle: s('jobTitle', p.jobTitle),
      summary: s('summary', p.summary),
      skills: patch.containsKey('skills') ? (patch['skills'] as List).cast<String>() : p.skills,
      location: s('location', p.location),
      completeness: p.completeness,
    );
    return profileNow;
  });

  @override
  Future<List<Experience>> saveExperience(List<Experience> rows) => _run('saveExperience', () {
    sent['saveExperience'] = [for (final r in rows) r.toRow()];
    // The API recreates every row, so every id is new.
    return experienceNow = [for (final r in rows) r.copyWith(id: _id('exp'))];
  });

  @override
  Future<List<Education>> saveEducation(List<Education> rows) => _run('saveEducation', () {
    sent['saveEducation'] = [for (final r in rows) r.toRow()];
    return educationNow = [
      for (final r in rows)
        Education(
          id: _id('edu'),
          institution: r.institution,
          university: r.university,
          degree: r.degree,
          fieldOfStudy: r.fieldOfStudy,
          startYear: r.startYear,
          endYear: r.endYear,
          grade: r.grade,
        ),
    ];
  });

  @override
  Future<List<CareerBreak>> saveCareerBreaks(List<CareerBreak> rows) => _run('saveCareerBreaks', () {
    sent['saveCareerBreaks'] = [for (final r in rows) r.toRow()];
    return breaksNow = [
      for (final r in rows)
        CareerBreak(
          id: _id('brk'),
          reason: r.reason,
          startYear: r.startYear,
          startMonth: r.startMonth,
          endYear: r.endYear,
          endMonth: r.endMonth,
          isCurrent: r.isCurrent,
          description: r.description,
        ),
    ];
  });

  @override
  Future<ProfileLinks> saveLinks(Map<String, String> links) => _run('saveLinks', () {
    sent['saveLinks'] = links;
    return linksNow = ProfileLinks.fromJson({
      for (final e in links.entries) e.key: e.value.isEmpty ? null : e.value,
    });
  });

  @override
  Future<UploadedFile> upload(PickedPhoto file, {String? purpose}) =>
      _run('upload', () => UploadedFile(url: '/uploads/${_id('file')}-${file.name}', name: file.name), purpose);

  @override
  Future<String?> sendPhoneCode(String phone) => _run('sendPhoneCode', () => testCode, phone);

  @override
  Future<void> verifyPhoneCode(String phone, String code) => _run('verifyPhoneCode', () {
    if (code != testCode) throw ApiError('Invalid code. Please try again.', statusCode: 401);
    profileNow = MyProfile.fromJson({
      'user': {..._userJson(profileNow), 'phone': phone, 'phoneVerified': true},
      'resume': profileNow.hasResume ? _resumeJson(profileNow) : null,
    });
  }, phone);

  @override
  Future<void> addCredential(CredentialDraft draft) => _run('addCredential', () {
    sent['addCredential'] = draft.toJson();
    credentialsNow = [_credential(_id('cred-new'), draft), ...credentialsNow];
  });

  @override
  Future<void> updateCredential(String id, CredentialDraft draft) => _run('updateCredential', () {
    sent['updateCredential'] = draft.toJson();
    credentialsNow = [for (final c in credentialsNow) c.id == id ? _credential(id, draft) : c];
  }, id);

  @override
  Future<String?> deleteCredential(String id) => _run('deleteCredential', () {
    credentialsNow = credentialsNow.where((c) => c.id != id).toList();
    return null;
  }, id);

  Credential _credential(String id, CredentialDraft d) {
    final json = d.toJson();
    return Credential(
      id: id,
      source: 'EXTERNAL',
      name: json['name'] as String,
      code: json['code'] as String?,
      issuer: json['issuer'] as String?,
      issuedAt: json['issuedAt'] as String?,
      expiresAt: json['expiresAt'] as String?,
      credentialUrl: json['credentialUrl'] as String?,
      fileUrl: json['fileUrl'] as String?,
      fileName: json['fileName'] as String?,
      status: json['fileUrl'] != null ? 'PENDING' : 'SELF_DECLARED',
    );
  }

  // --- other members -----------------------------------------------------------------------------------------

  @override
  Future<MemberProfile> member(String idOrSlug) => _run('member', () {
    for (final m in members.values) {
      if (m.id == idOrSlug || m.profileSlug == idOrSlug.toLowerCase()) return m;
    }
    throw ApiError('Member not found', statusCode: 404);
  }, idOrSlug);

  @override
  Future<FollowState> follow(String memberId) => _run('follow', () => _setFollow(memberId, true), memberId);

  @override
  Future<FollowState> unfollow(String memberId) => _run('unfollow', () => _setFollow(memberId, false), memberId);

  FollowState _setFollow(String id, bool on) {
    final m = members[id];
    if (m == null) throw ApiError('Member not found', statusCode: 404);
    if (m.isOwner) throw ApiError('You cannot follow yourself.', statusCode: 400);
    final was = m.follow.viewerFollows;
    final next = m.follow.copyWith(
      viewerFollows: on,
      followers: m.follow.followers + (on == was ? 0 : (on ? 1 : -1)),
    );
    members[id] = m.withFollow(next);
    return next;
  }

  @override
  Future<List<ForumPost>> memberPosts(String userId, {int limit = 5}) =>
      _run('memberPosts', () => (posts[userId] ?? const <ForumPost>[]).take(limit).toList(), userId);

  @override
  Future<String> startConversation(String userId) => _run('startConversation', () => 'conv-$userId', userId);

  // --- companies ---------------------------------------------------------------------------------------------

  SessionTokens _session() => SessionTokens(accessToken: _id('access'), refreshToken: _id('refresh'));

  @override
  Future<MyCompanies> myCompanies() => _run('myCompanies', () => companiesNow);

  @override
  Future<SessionTokens> switchCompany(String? companyId) => _run('switchCompany', () {
    if (companyId != null && !companiesNow.companies.any((c) => c.companyId == companyId)) {
      throw ApiError('You are not a member of that company.', statusCode: 403);
    }
    companiesNow = companiesNow.copyWith(
      companies: [for (final c in companiesNow.companies) _withActive(c, c.companyId == companyId)],
    );
    return _session();
  }, companyId ?? 'personal');

  @override
  Future<SessionTokens> leaveCompany(String companyId) => _run('leaveCompany', () {
    final company = companiesNow.companies.where((c) => c.companyId == companyId).firstOrNull;
    if (company == null) throw ApiError('You are not a member of that company.', statusCode: 404);
    if (company.soleAdmin) {
      throw ApiError(
        'You are the only admin. Make someone else an admin from the team page before you leave.',
        statusCode: 400,
      );
    }
    companiesNow = companiesNow.copyWith(
      companies: companiesNow.companies.where((c) => c.companyId != companyId).toList(),
    );
    return _session();
  }, companyId);

  @override
  Future<MyCompanies> withdrawRequest(String companyId) => _run('withdrawRequest', () {
    if (!companiesNow.requests.any((r) => r.companyId == companyId)) {
      throw ApiError('That request is no longer waiting.', statusCode: 404);
    }
    return companiesNow = companiesNow.copyWith(
      requests: companiesNow.requests.where((r) => r.companyId != companyId).toList(),
    );
  }, companyId);

  @override
  Future<SessionTokens> createCompany(CompanyDraft draft) => _run('createCompany', () {
    sent['createCompany'] = draft.toJson();
    final created = MyCompany(
      companyId: _id('co'),
      name: draft.name.trim(),
      role: 'COMPANY_ADMIN',
      logoUrl: draft.logoUrl,
      active: true,
      city: draft.city,
      state: draft.state,
      industry: draft.industry,
      joinedAt: DateTime.now().toUtc().toIso8601String(),
      soleAdmin: true,
      pendingJoinRequests: 0,
    );
    companiesNow = companiesNow.copyWith(
      companies: [for (final c in companiesNow.companies) _withActive(c, false), created],
    );
    return _session();
  });

  @override
  Future<List<CompanyLookalike>> lookalikes({String? name, String? website}) => _run('lookalikes', () {
    final q = (name ?? '').trim().toLowerCase();
    if (q.length < 3) return const <CompanyLookalike>[];
    return [
      for (final c in companyPages)
        if (c.name.toLowerCase().contains(q)) CompanyLookalike(id: c.id, name: c.name, city: c.city, reason: 'name'),
    ];
  }, name);

  @override
  Future<void> requestToJoin(String companyId, {String? note}) => _run('requestToJoin', () {
    sent['requestToJoin'] = {'companyId': companyId, 'note': ?note};
    final page = companyPages.where((c) => c.id == companyId).firstOrNull;
    companiesNow = companiesNow.copyWith(
      requests: [
        JoinRequest(
          companyId: companyId,
          name: page?.name ?? companyId,
          role: 'PROFESSIONAL',
          note: note,
          requestedAt: DateTime.now().toUtc().toIso8601String(),
        ),
        ...companiesNow.requests,
      ],
    );
  }, companyId);

  MyCompany _withActive(MyCompany c, bool active) => MyCompany(
    companyId: c.companyId,
    name: c.name,
    role: c.role,
    logoUrl: c.logoUrl,
    branchName: c.branchName,
    active: active,
    hasSupplierListing: c.hasSupplierListing,
    city: c.city,
    state: c.state,
    industry: c.industry,
    verified: c.verified,
    joinedAt: c.joinedAt,
    memberCount: c.memberCount,
    soleAdmin: c.soleAdmin,
    pendingJoinRequests: c.pendingJoinRequests,
  );

  // --- settings ----------------------------------------------------------------------------------------------

  /// What `GET /auth/me` says the account's language is.
  String? localeNow;

  @override
  Future<String?> accountLocale() => _run('accountLocale', () => localeNow);

  @override
  Future<List<NotificationPreference>> notificationPreferences() =>
      _run('notificationPreferences', () => preferencesNow);

  @override
  Future<List<NotificationPreference>> saveNotificationPreferences(List<NotificationPreference> rows) =>
      _run('saveNotificationPreferences', () {
        sent['saveNotificationPreferences'] = [
          for (final r in rows) {'category': r.category, 'inApp': r.inApp, 'email': r.email},
        ];
        return preferencesNow = [
          for (final p in preferencesNow)
            p.locked ? p : rows.firstWhere((r) => r.category == p.category, orElse: () => p),
        ];
      });

  @override
  Future<Map<String, dynamic>> exportData() => _run(
    'exportData',
    () => {
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'account': {
        'id': profileNow.id,
        'firstName': profileNow.firstName,
        'lastName': profileNow.lastName,
        'email': profileNow.email,
        'role': profileNow.role,
      },
      'note': 'This is the personal data ICR holds for your account.',
    },
  );

  @override
  Future<void> deleteAccount() => _run('deleteAccount', () {});

  static Map<String, dynamic> _userJson(MyProfile p) => {
    'id': p.id,
    'email': p.email,
    'firstName': p.firstName,
    'lastName': p.lastName,
    'role': p.role,
    'profileSlug': p.profileSlug,
    'designation': p.designation,
    'yearsExperience': p.yearsExperience,
    'languages': p.languages,
    'workEmail': p.workEmail,
    'phone': p.phone,
    'phoneVerified': p.phoneVerified,
    'altPhone': p.altPhone,
    'avatarUrl': p.avatarUrl,
    'coverImage': p.coverImage,
  };

  static Map<String, dynamic> _resumeJson(MyProfile p) => {
    'jobTitle': p.jobTitle,
    'summary': p.summary,
    'skills': p.skills,
    'location': p.location,
  };
}

// --- the sample member -------------------------------------------------------------------------------------------

const demoProfile = MyProfile(
  id: 'me',
  email: 'nikhil@techcorp.example',
  firstName: 'Nikhil',
  lastName: 'Majjagi',
  role: 'PROFESSIONAL',
  profileSlug: 'nikhil-majjagi',
  designation: 'Lead Operations Manager',
  yearsExperience: 12,
  languages: ['English', 'Hindi', 'Kannada'],
  phone: '+919876543210',
  phoneVerified: true,
  avatarUrl: 'asset:assets/images/demo/avatar_me.jpg',
  coverImage: 'asset:assets/images/demo/cover_town.jpg',
  hasResume: true,
  jobTitle: 'Lead Operations Manager',
  summary:
      'Operations leader running Grade-A tech parks across Bengaluru: hard and soft services, vendor SLAs, '
      'energy and statutory compliance. I mentor young FM professionals through ICR.',
  skills: ['Facility operations', 'Vendor SLAs', 'BMS Automation', 'ESG reporting', 'Budgeting'],
  location: 'Bengaluru, Karnataka',
  completeness: Completeness(score: 85, missing: ['Add your education']),
);

const demoExperience = [
  Experience(
    id: 'exp-1',
    title: 'Lead Operations Manager',
    organisation: 'TechCorp',
    company: LinkedCompany(id: 'co-techcorp', name: 'TechCorp'),
    employmentType: 'FULL_TIME',
    city: 'Bengaluru',
    startYear: 2021,
    startMonth: 4,
    isCurrent: true,
    description: 'Runs operations for 3.2M sq ft across two campuses: 140 staff, 22 vendors.',
  ),
  Experience(
    id: 'exp-2',
    title: 'Facilities Manager',
    organisation: 'Global Infra Solutions',
    employmentType: 'FULL_TIME',
    city: 'Pune',
    startYear: 2016,
    startMonth: 7,
    endYear: 2021,
    endMonth: 3,
  ),
];

const demoEducation = [
  Education(
    id: 'edu-1',
    institution: 'RV College of Engineering',
    degree: 'B.E.',
    fieldOfStudy: 'Mechanical Engineering',
    startYear: 2008,
    endYear: 2012,
  ),
];

const demoCredentials = [
  Credential(
    id: 'cred-1',
    source: 'ICR_EXAM',
    name: 'Certified Facility Professional',
    code: 'CFP',
    issuer: 'Institute for Corporate Real Estate',
    issuedAt: '2025-03-12T00:00:00.000Z',
    status: 'VERIFIED',
  ),
  Credential(
    id: 'cred-2',
    source: 'EXTERNAL',
    name: 'IFMA Facility Management Professional',
    code: 'FMP',
    issuer: 'IFMA',
    issuedAt: '2022-08-01T00:00:00.000Z',
    status: 'SELF_DECLARED',
  ),
];

const demoCompanies = MyCompanies(
  personalRole: 'PROFESSIONAL',
  companies: [
    MyCompany(
      companyId: 'co-techcorp',
      name: 'TechCorp',
      role: 'COMPANY_ADMIN',
      city: 'Bengaluru',
      state: 'Karnataka',
      industry: 'CORPORATE_OCCUPIER',
      verified: true,
      joinedAt: '2026-09-02T10:00:00.000Z',
      memberCount: 14,
      soleAdmin: false,
      pendingJoinRequests: 2,
    ),
  ],
);

const demoMembers = [
  MemberProfile(
    id: 'm-arjun',
    firstName: 'Arjun',
    lastName: 'Mehta',
    profileSlug: 'arjun-mehta',
    headline: 'Head of Workplace · Global Infra Solutions',
    city: 'Pune',
    memberSince: '2026-05-10T00:00:00.000Z',
    about: 'Workplace strategist. Twenty years of campuses, fit-outs and the people who run them.',
    skills: ['Workplace strategy', 'Space planning', 'Change management'],
    languages: ['English', 'Marathi'],
    yearsExperience: 20,
    experience: [
      Experience(
        id: 'm-exp-1',
        title: 'Head of Workplace',
        organisation: 'Global Infra Solutions',
        company: LinkedCompany(id: 'co-global', name: 'Global Infra Solutions'),
        city: 'Pune',
        startYear: 2019,
        startMonth: 1,
        isCurrent: true,
      ),
    ],
    education: [Education(id: 'm-edu-1', institution: 'CEPT University', degree: 'M.Plan', startYear: 2002, endYear: 2004)],
    reputation: 320,
    threads: 4,
    replies: 18,
    acceptedAnswers: 3,
    chapters: [MemberGroup(slug: 'pune', name: 'ICR Pune Chapter', city: 'Pune')],
    councils: [MemberGroup(slug: 'workplace-experience', name: 'Workplace & Employee Experience Council')],
    follow: FollowState(followers: 41, following: 12, viewerFollows: false),
    signedIn: true,
  ),
];

const demoPosts = [
  ForumPost(
    id: 'post-1',
    slug: 'hybrid-occupancy-sensors',
    title: 'Which occupancy sensors held up in your hybrid floors?',
    excerpt: 'We trialled three vendors across two floors. Here is what the data said after six months…',
    category: 'Workplace strategy',
    replyCount: 12,
    viewCount: 486,
    createdAt: '2026-10-12T09:00:00.000Z',
  ),
];
